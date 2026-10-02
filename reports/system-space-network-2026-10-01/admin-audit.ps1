param([string]$OutputDirectory,[string]$PythonPath)
$ErrorActionPreference='Continue'
$principal=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) | Out-File -LiteralPath (Join-Path $OutputDirectory 'administrator-token.txt')
& fsutil volume diskfree C: 2>&1 | Out-File -LiteralPath (Join-Path $OutputDirectory 'diskfree-admin.txt') -Encoding utf8
& fsutil fsinfo ntfsinfo C: 2>&1 | Out-File -LiteralPath (Join-Path $OutputDirectory 'ntfsinfo-admin.txt') -Encoding utf8
& vssadmin list shadowstorage 2>&1 | Out-File -LiteralPath (Join-Path $OutputDirectory 'shadowstorage-admin.txt') -Encoding utf8
& fsutil volume allocationreport C: 2>&1 | Out-File -LiteralPath (Join-Path $OutputDirectory 'allocationreport-admin.txt') -Encoding utf8
Get-SmbConnection | Select-Object ServerName,ShareName,Dialect,NumOpens | ConvertTo-Json | Out-File -LiteralPath (Join-Path $OutputDirectory 'smb-admin.json') -Encoding utf8
Get-CimInstance Win32_PageFileUsage | Select-Object Name,AllocatedBaseSize,CurrentUsage,PeakUsage | ConvertTo-Json | Out-File -LiteralPath (Join-Path $OutputDirectory 'pagefile.json') -Encoding utf8
& $PythonPath (Join-Path $OutputDirectory 'scan.py') $OutputDirectory 2>&1 | Out-File -LiteralPath (Join-Path $OutputDirectory 'scan-console.txt') -Encoding utf8
$LASTEXITCODE | Out-File -LiteralPath (Join-Path $OutputDirectory 'scan-exit-code.txt')
