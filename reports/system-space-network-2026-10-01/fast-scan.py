import os,sys,json,time,heapq,shutil
from collections import defaultdict
root='C:\\';out=sys.argv[1];os.makedirs(out,exist_ok=True)
folders=defaultdict(lambda:[0,0]);errors=[];skipped=[];big=[];files=0;logical=0;start=time.time();before=shutil.disk_usage(root)._asdict();stack=[root]
while stack:
    directory=stack.pop()
    try:
        with os.scandir(directory) as it:
            for entry in it:
                try:
                    st=entry.stat(follow_symlinks=False);tag=getattr(st,'st_reparse_tag',0)
                    if tag & 0x20000000:skipped.append({'path':entry.path,'tag':hex(tag)});continue
                    if entry.is_dir(follow_symlinks=False):stack.append(entry.path);continue
                    files+=1;logical+=st.st_size
                    rel=os.path.relpath(entry.path,root).split(os.sep)
                    keys=[os.path.join(root,*rel[:d]) for d in range(1,min(6,len(rel)))]
                    if len(rel)==1:keys=[entry.path]
                    for key in keys:folders[key][0]+=1;folders[key][1]+=st.st_size
                    item=(st.st_size,entry.path,getattr(st,'st_file_attributes',0))
                    if len(big)<100:heapq.heappush(big,item)
                    elif item[0]>big[0][0]:heapq.heapreplace(big,item)
                    if files%100000==0:
                        with open(os.path.join(out,'fast-progress.json'),'w',encoding='utf-8') as f:json.dump({'files':files,'logical_bytes':logical,'elapsed_seconds':round(time.time()-start),'directory':directory},f,ensure_ascii=False)
                        print('ENUMERATED',files,flush=True)
                except OSError as ex:errors.append({'path':entry.path,'error':str(ex)})
    except OSError as ex:errors.append({'path':directory,'error':str(ex)})
result={'mode':'logical_file_sizes_not_physical_allocation','elapsed_seconds':round(time.time()-start),'files':files,'logical_bytes':logical,'disk_before':before,'disk_after':shutil.disk_usage(root)._asdict(),'folders':[{'path':p,'files':v[0],'logical_bytes':v[1]} for p,v in sorted(folders.items(),key=lambda kv:kv[1][1],reverse=True)],'largest_files':[{'path':p,'logical_bytes':s,'attributes':a} for s,p,a in sorted(big,reverse=True)],'errors':errors,'skipped':skipped}
with open(os.path.join(out,'logical-file-scan.json'),'w',encoding='utf-8') as f:json.dump(result,f,ensure_ascii=False,indent=2)
print(json.dumps({k:v for k,v in result.items() if k not in ('folders','largest_files','errors','skipped')},ensure_ascii=False),flush=True)
