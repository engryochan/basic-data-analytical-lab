import os, sys, json, ctypes, time, heapq, shutil
from ctypes import wintypes as w
from collections import defaultdict
root = 'C:\\'
out = sys.argv[1]
os.makedirs(out, exist_ok=True)
k = ctypes.WinDLL('kernel32', use_last_error=True)
class Info(ctypes.Structure):
    _fields_=[('attrs',w.DWORD),('ct',w.FILETIME),('at',w.FILETIME),('wt',w.FILETIME),('vol',w.DWORD),('size_hi',w.DWORD),('size_lo',w.DWORD),('links',w.DWORD),('id_hi',w.DWORD),('id_lo',w.DWORD)]
class Standard(ctypes.Structure):
    _fields_=[('alloc',ctypes.c_longlong),('end',ctypes.c_longlong),('links',w.DWORD),('delete',ctypes.c_ubyte),('directory',ctypes.c_ubyte)]
k.CreateFileW.argtypes=[w.LPCWSTR,w.DWORD,w.DWORD,ctypes.c_void_p,w.DWORD,w.DWORD,w.HANDLE];k.CreateFileW.restype=w.HANDLE
k.GetFileInformationByHandle.argtypes=[w.HANDLE,ctypes.POINTER(Info)];k.GetFileInformationByHandle.restype=w.BOOL
k.GetFileInformationByHandleEx.argtypes=[w.HANDLE,ctypes.c_int,ctypes.c_void_p,w.DWORD];k.GetFileInformationByHandleEx.restype=w.BOOL
k.CloseHandle.argtypes=[w.HANDLE]
invalid=ctypes.c_void_p(-1).value
seen=set(); folders=defaultdict(lambda:[0,0,0,0]); errors=[]; skipped=[]; big=[]
counts={'files':0,'logical_bytes':0,'allocated_path_bytes':0,'allocated_unique_bytes':0,'hardlink_duplicate_bytes':0,'allocation_unknown_files':0,'allocation_unknown_logical_bytes':0}
start=time.time(); before=shutil.disk_usage(root)._asdict()
def allocation(path):
    h=k.CreateFileW('\\\\?\\'+path,0x80,7,None,3,0x00200000,None)
    if h==invalid: raise ctypes.WinError(ctypes.get_last_error())
    try:
        info=Info();std=Standard()
        if not k.GetFileInformationByHandle(h,ctypes.byref(info)):raise ctypes.WinError(ctypes.get_last_error())
        if not k.GetFileInformationByHandleEx(h,1,ctypes.byref(std),ctypes.sizeof(std)):raise ctypes.WinError(ctypes.get_last_error())
        key=(info.vol,info.id_hi,info.id_lo)
        duplicate=False
        if info.links>1:
            duplicate=key in seen;seen.add(key)
        return std.alloc,duplicate
    finally:k.CloseHandle(h)
stack=[root]
while stack:
    directory=stack.pop()
    try:
        with os.scandir(directory) as it:
            for entry in it:
                try:
                    st=entry.stat(follow_symlinks=False)
                    tag=getattr(st,'st_reparse_tag',0)
                    if tag & 0x20000000:
                        skipped.append({'path':entry.path,'tag':hex(tag)});continue
                    if entry.is_dir(follow_symlinks=False):stack.append(entry.path);continue
                    size=st.st_size;allocated=0;duplicate=False;unknown=False
                    try:allocated,duplicate=allocation(entry.path)
                    except OSError as ex:
                        unknown=True;errors.append({'path':entry.path,'operation':'allocation','error':str(ex)})
                    counts['files']+=1;counts['logical_bytes']+=size
                    if unknown:
                        counts['allocation_unknown_files']+=1;counts['allocation_unknown_logical_bytes']+=size
                    else:
                        counts['allocated_path_bytes']+=allocated
                        if duplicate:counts['hardlink_duplicate_bytes']+=allocated
                        else:counts['allocated_unique_bytes']+=allocated
                    rel=os.path.relpath(entry.path,root).split(os.sep)
                    for depth in range(1,min(4,len(rel))):
                        key=os.path.join(root,*rel[:depth]); row=folders[key]
                        row[0]+=1;row[1]+=size;row[2]+=allocated;row[3]+=0 if duplicate else allocated
                    if len(rel)==1:
                        row=folders[entry.path];row[0]+=1;row[1]+=size;row[2]+=allocated;row[3]+=0 if duplicate else allocated
                    item=(size,entry.path,allocated,unknown)
                    if len(big)<100:heapq.heappush(big,item)
                    elif size>big[0][0]:heapq.heapreplace(big,item)
                    if counts['files']%20000==0:
                        progress={'elapsed_seconds':round(time.time()-start),'directory':directory,**counts}
                        with open(os.path.join(out,'scan-progress.json'),'w',encoding='utf-8') as f:json.dump(progress,f,ensure_ascii=False)
                        print('SCANNED',counts['files'],flush=True)
                except OSError as ex:errors.append({'path':entry.path,'operation':'stat','error':str(ex)})
    except OSError as ex:errors.append({'path':directory,'operation':'enumerate','error':str(ex)})
after=shutil.disk_usage(root)._asdict()
result={'elapsed_seconds':round(time.time()-start),'disk_before':before,'disk_after':after,**counts,'error_count':len(errors),'skipped_count':len(skipped),'folders':[{'path':p,'files':v[0],'logical_bytes':v[1],'allocated_path_bytes':v[2],'allocated_unique_bytes':v[3]} for p,v in sorted(folders.items(),key=lambda kv:kv[1][3],reverse=True)],'largest_files':[{'path':p,'logical_bytes':s,'allocated_bytes':a,'allocation_unknown':u} for s,p,a,u in sorted(big,reverse=True)],'errors':errors,'skipped':skipped}
with open(os.path.join(out,'c-drive-scan.json'),'w',encoding='utf-8') as f:json.dump(result,f,ensure_ascii=False,indent=2)
print(json.dumps({k:v for k,v in result.items() if k not in ('folders','largest_files','errors','skipped')},ensure_ascii=False),flush=True)
