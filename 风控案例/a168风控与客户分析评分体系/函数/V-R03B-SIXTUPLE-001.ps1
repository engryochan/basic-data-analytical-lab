#Requires -Version 5.1
<#
================================================================================
 VALIDATOR PASSPORT
================================================================================
 VALIDATOR-ID        V-R03B-SIXTUPLE-001
 VERSION             1.0.0
 PURPOSE             实测档案六元组：档名 / 行数 / 字节 / MD5 / 行尾 / 编码
 INPUT               目录路径（含待验档案）
 OUTPUT              PASS / FAIL / INCONCLUSIVE  逐档

 NOT-CAPABLE-OF      本器【不能】回答：
                       · 档案来源是否真实、合法
                       · 档案是否曾被替换
                       · 内容业务语义是否正确
                       · 档案是否为某次查询之产物
                     本器仅能回答：两个字节流是否同一，及其结构属性。

 NEG-CONTROL         NC-01  三行 CRLF 小档 → CR 字节数须 = 3
                     NC-02  三行 LF 小档   → CR 字节数须 = 0
                     NC-03  加 BOM 之档     → BOM 侦测须 = TRUE
                     NC-04  非法 UTF-8 位元组 → 编码校验须 = FAIL
                     ★ 四项任一不过，本器【无资格】执行，立即 exit 1

 POS-CONTROL         PC-01  同一档取两次 MD5 须相同
                     PC-02  已知 3 行 / 已知字节数之档，读数须吻合

 SC-LINKED-DEFECTS   SC-002  行尾探针 `$` 锚点假阴性
                             → 本器改【直数 \r 位元组】，NC-01/02 即为其回归测试
                     SC-029  Get-ChildItem -Recurse 通配降级致计数器零验证力
                             → 本器改用 -LiteralPath 逐档指名，不用通配
                     SC-026  try/catch 不捕原生指令非零退出码
                             → 本器不呼叫原生指令；全程 .NET API
                     SC-003  输出被 max.print 截断
                             → 本器输出一律 Format-List，禁 Format-Table（v3 §一）

 STOP-ANCHOR         A1（位元组差 = 行数 之恒等式）
                     A2（机械可复算：任何人跑本脚本得同一读数）

 EVIDENCE-DEPENDENCY 檔案系統 → 位元組讀取(.NET File.ReadAllBytes)
                              → MD5(.NET CryptoServiceProvider)
                              → 位元組計數(純算術, 不依賴 parser)
                     ⚠ 與 certutil / Get-FileHash 共模：同一 I/O 堆疊
                     ⚠ 與 WSL md5sum  非共模：不同讀取路徑
                     → 若需 pairwise 獨立，須另跑 WSL 版交叉

 CERTIFICATION       UNCERTIFIED —— 首次執行且四項 NC 全過後，方可標 CERTIFIED
================================================================================
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$TargetDir,

    [string]$ExpectedCsv = "",     # 選填：期望六元組對照表 CSV
    [string]$ReportPath  = ""      # 選填：輸出報告路徑
)

$ErrorActionPreference = 'Stop'
$script:RunId = "SIXTUPLE-" + (Get-Date -Format "yyyyMMdd_HHmmss")

# ==============================================================================
# 核心量測函式（不依賴任何 parser，純位元組）
# ==============================================================================
function Measure-SixTuple {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [pscustomobject]@{ File=$Path; Status='MISSING' }
    }

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $len   = $bytes.Length

    # 行數 = LF (0x0A) 位元組數 —— 與 GNU wc -l 同慣例
    # 行尾 = CR (0x0D) 位元組數 —— SC-002：直數位元組，禁用 $ 錨點
    $lf = 0; $cr = 0
    for ($i = 0; $i -lt $len; $i++) {
        if     ($bytes[$i] -eq 0x0A) { $lf++ }
        elseif ($bytes[$i] -eq 0x0D) { $cr++ }
    }

    if     ($cr -eq 0)   { $lineEnd = 'LF' }
    elseif ($cr -eq $lf) { $lineEnd = 'CRLF' }
    else                 { $lineEnd = "MIXED(cr=$cr,lf=$lf)" }

    # 末行是否有換行
    $tailNL = ($len -gt 0 -and $bytes[$len-1] -eq 0x0A)

    # BOM
    $hasBom = ($len -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)

    # UTF-8 合法性（嚴格模式，遇非法位元組即擲例外）
    $utf8ok = $true
    try {
        $enc = New-Object System.Text.UTF8Encoding($false, $true)
        [void]$enc.GetString($bytes)
    } catch { $utf8ok = $false }

    # MD5
    $md5p = [System.Security.Cryptography.MD5]::Create()
    $md5  = ([BitConverter]::ToString($md5p.ComputeHash($bytes))).Replace('-','').ToLower()
    $md5p.Dispose()

    # SHA-256（第二演算法，非獨立證據，僅供對外交付用）
    $shp  = [System.Security.Cryptography.SHA256]::Create()
    $sha  = ([BitConverter]::ToString($shp.ComputeHash($bytes))).Replace('-','').ToLower()
    $shp.Dispose()

    $fi = Get-Item -LiteralPath $Path

    [pscustomobject]@{
        File          = $fi.Name
        FullPath      = $fi.FullName
        Lines         = $lf
        Bytes         = $len
        MD5           = $md5
        SHA256        = $sha
        LineEnding    = $lineEnd
        CRBytes       = $cr
        TrailingNL    = $tailNL
        Encoding      = $(if ($utf8ok) { if ($hasBom) {'UTF-8+BOM'} else {'UTF-8 無BOM'} } else {'非合法UTF-8'})
        BytesMinusLines = $len - $lf     # A1 恆等式用：CRLF→LF 歸一之位元組差
        LastWriteTime = $fi.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
        Status        = 'MEASURED'
    }
}

# ==============================================================================
# 負控制 —— 不過即 exit 1，本器無資格執行
# ==============================================================================
function Invoke-NegativeControl {
    Write-Host "`n===== NEGATIVE CONTROL（本器自身之驗證）=====" -ForegroundColor Cyan
    $tmp = Join-Path $env:TEMP "vsix_nc_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -LiteralPath $tmp | Out-Null
    $pass = $true
    $results = @()

    try {
        # NC-01 三行 CRLF → CR 須 = 3
        $f1 = Join-Path $tmp 'nc01_crlf.txt'
        [System.IO.File]::WriteAllBytes($f1, [System.Text.Encoding]::ASCII.GetBytes("a`r`nb`r`nc`r`n"))
        $r1 = Measure-SixTuple $f1
        $ok1 = ($r1.CRBytes -eq 3 -and $r1.Lines -eq 3 -and $r1.LineEnding -eq 'CRLF')
        $results += [pscustomobject]@{ Test='NC-01 三行CRLF'; Expect='CR=3, Lines=3, CRLF'
                                       Actual="CR=$($r1.CRBytes), Lines=$($r1.Lines), $($r1.LineEnding)"
                                       Result=$(if($ok1){'PASS'}else{'FAIL'}) }
        $pass = $pass -and $ok1

        # NC-02 三行 LF → CR 須 = 0
        $f2 = Join-Path $tmp 'nc02_lf.txt'
        [System.IO.File]::WriteAllBytes($f2, [System.Text.Encoding]::ASCII.GetBytes("a`nb`nc`n"))
        $r2 = Measure-SixTuple $f2
        $ok2 = ($r2.CRBytes -eq 0 -and $r2.Lines -eq 3 -and $r2.LineEnding -eq 'LF')
        $results += [pscustomobject]@{ Test='NC-02 三行LF'; Expect='CR=0, Lines=3, LF'
                                       Actual="CR=$($r2.CRBytes), Lines=$($r2.Lines), $($r2.LineEnding)"
                                       Result=$(if($ok2){'PASS'}else{'FAIL'}) }
        $pass = $pass -and $ok2

        # NC-03 BOM 檔 → 須偵出
        $f3 = Join-Path $tmp 'nc03_bom.txt'
        $b3 = [byte[]](0xEF,0xBB,0xBF) + [System.Text.Encoding]::ASCII.GetBytes("a`n")
        [System.IO.File]::WriteAllBytes($f3, $b3)
        $r3 = Measure-SixTuple $f3
        $ok3 = ($r3.Encoding -eq 'UTF-8+BOM')
        $results += [pscustomobject]@{ Test='NC-03 BOM偵測'; Expect='UTF-8+BOM'
                                       Actual=$r3.Encoding; Result=$(if($ok3){'PASS'}else{'FAIL'}) }
        $pass = $pass -and $ok3

        # NC-04 非法 UTF-8 → 編碼校驗須 FAIL
        $f4 = Join-Path $tmp 'nc04_bad.txt'
        [System.IO.File]::WriteAllBytes($f4, [byte[]](0x41,0xFF,0xFE,0x0A))
        $r4 = Measure-SixTuple $f4
        $ok4 = ($r4.Encoding -eq '非合法UTF-8')
        $results += [pscustomobject]@{ Test='NC-04 非法UTF-8'; Expect='非合法UTF-8'
                                       Actual=$r4.Encoding; Result=$(if($ok4){'PASS'}else{'FAIL'}) }
        $pass = $pass -and $ok4

        # PC-01 同檔兩次 MD5 須相同
        $ok5 = ((Measure-SixTuple $f2).MD5 -eq (Measure-SixTuple $f2).MD5)
        $results += [pscustomobject]@{ Test='PC-01 MD5可重現'; Expect='兩次相同'
                                       Actual=$(if($ok5){'相同'}else{'不同'}); Result=$(if($ok5){'PASS'}else{'FAIL'}) }
        $pass = $pass -and $ok5

        # PC-02 已知位元組數
        $ok6 = ($r2.Bytes -eq 6)
        $results += [pscustomobject]@{ Test='PC-02 已知位元組數'; Expect='6'
                                       Actual="$($r2.Bytes)"; Result=$(if($ok6){'PASS'}else{'FAIL'}) }
        $pass = $pass -and $ok6

    } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }

    $results | Format-List | Out-String | Write-Host

    if (-not $pass) {
        Write-Host "⛔ NEGATIVE CONTROL 未過 —— 本驗證器【無資格】執行。" -ForegroundColor Red
        Write-Host "   依 EAV-QMS Gate-2：未通過正負控制之驗證器不具備 GREEN 資格。" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ NEGATIVE / POSITIVE CONTROL 全過 —— 本器具備執行資格。`n" -ForegroundColor Green
    return $results
}

# ==============================================================================
# 主流程
# ==============================================================================
Write-Host "================================================================"
Write-Host " V-R03B-SIXTUPLE-001  v1.0.0"
Write-Host " RUN-ID : $script:RunId"
Write-Host " 目錄   : $TargetDir"
Write-Host " 時間   : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss K')"
Write-Host "================================================================"

$ncResults = Invoke-NegativeControl

if (-not (Test-Path -LiteralPath $TargetDir -PathType Container)) {
    Write-Host "⛔ 目錄不存在：$TargetDir" -ForegroundColor Red
    exit 1
}

# SC-029：不用通配 -Recurse，逐檔指名；此處僅列頂層，且明示未遞迴
$files = [System.IO.Directory]::GetFiles($TargetDir) |
         Where-Object { $_ -match '\.(qmd|sql|md|tsv|csv|R|ps1)$' } |
         Sort-Object

Write-Host "===== 掃描結果（頂層，未遞迴）=====" -ForegroundColor Cyan
Write-Host "檔案數：$($files.Count)`n"

$measured = @()
foreach ($f in $files) { $measured += Measure-SixTuple $f }

# 輸出：一律 Format-List（v3 §一 禁 Format-Table —— 曾兩度截斷 Path）
$measured | Format-List | Out-String | Write-Host

# ==============================================================================
# A1 恆等式檢查
# ==============================================================================
Write-Host "===== A1 恆等式：位元組差 = 行數 ？=====" -ForegroundColor Cyan
foreach ($m in $measured) {
    if ($m.Status -ne 'MEASURED') { continue }
    $note = if ($m.LineEnding -eq 'CRLF' -and $m.CRBytes -eq $m.Lines) {
                "CRLF 每行皆有；LF 歸一後位元組 = $($m.BytesMinusLines)"
            } elseif ($m.LineEnding -eq 'LF') {
                "LF 原生；無歸一差"
            } else { "⚠ MIXED —— 須人工判讀" }
    Write-Host ("  {0,-56} {1}" -f $m.File, $note)
}

# ==============================================================================
# 對照期望表（選填）
# ==============================================================================
if ($ExpectedCsv -ne "" -and (Test-Path -LiteralPath $ExpectedCsv)) {
    Write-Host "`n===== 與期望六元組對照 =====" -ForegroundColor Cyan
    Write-Host "（期望表格式：File,Lines,Bytes,MD5Prefix,LineEnding）`n"
    $exp = Import-Csv -LiteralPath $ExpectedCsv
    foreach ($e in $exp) {
        $a = $measured | Where-Object { $_.File -eq $e.File } | Select-Object -First 1
        if ($null -eq $a) {
            Write-Host ("  ⚪ {0,-56} 未到齊（宣告有，磁碟無）" -f $e.File) -ForegroundColor Yellow
            continue
        }
        $okL = ([int]$e.Lines -eq $a.Lines)
        $okB = ([int]$e.Bytes -eq $a.Bytes)
        $okM = ($a.MD5.StartsWith(($e.MD5Prefix -replace '…','').Trim()))
        $okE = ($e.LineEnding -eq $a.LineEnding)
        $all = $okL -and $okB -and $okM -and $okE
        $mark = if ($all) { '🟢 過' } else { '🔴 不符' }
        Write-Host ("  {0} {1,-52} 行{2} 位元組{3} MD5{4} 行尾{5}" -f `
            $mark, $e.File, $(if($okL){'✓'}else{"✗($($a.Lines))"}),
            $(if($okB){'✓'}else{"✗($($a.Bytes))"}),
            $(if($okM){'✓'}else{"✗($($a.MD5.Substring(0,12)))"}),
            $(if($okE){'✓'}else{"✗($($a.LineEnding))"}))

        if (-not $okM -and -not $okB) {
            $diff = [math]::Abs($a.Bytes - [int]$e.Bytes)
            if ($diff -eq $a.Lines) {
                Write-Host "       ↳ 位元組差 $diff = 行數 $($a.Lines) → CRLF/LF 歸一，非版本衝突" -ForegroundColor Yellow
            }
        }
    }
}

# ==============================================================================
# 報告落檔
# ==============================================================================
if ($ReportPath -eq "") {
    $ReportPath = Join-Path $TargetDir "SIXTUPLE_REPORT_$($script:RunId).csv"
}
$measured | Export-Csv -LiteralPath $ReportPath -NoTypeInformation -Encoding UTF8
Write-Host "`n報告已落檔：$ReportPath" -ForegroundColor Green

Write-Host @"

================================================================
 執行完畢。接手方須知：
   · 本器僅回答【字節同一性與結構屬性】，不回答來源。
   · 本次讀數之停機錨為 A1 / A2。
   · 若需 pairwise 獨立交叉，另於 WSL 執行：
       md5sum <檔>  ；  tr -cd '\r' < <檔> | wc -c
     WSL 與本器讀取路徑不同，對【路徑類失效】非共模。
   · 本次 NC 全過，本器可標 CERTIFIED，版本鎖 1.0.0。
     任何修改須重跑 NC-01~04 並比對本次結果（回歸測試）。
================================================================
"@ -ForegroundColor Cyan
