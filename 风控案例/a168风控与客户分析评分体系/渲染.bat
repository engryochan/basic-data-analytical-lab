@echo off
rem 渲染.bat  v1.2.46（GBK 编码；单件合一，两级自动降级）
rem 用法：与 qmd 同目录双击即可。无须判断跑哪个、无须改档。
rem 第一级：依 YAML 出【单文件自包含 HTML】（推荐规格，分发无须携目录）。
rem 第二级：第一级若因内存不足失败，自动降为轻装版（HTML + _files 目录）并回显。
cd /d "%~dp0"
set "QMD=尾段投注基础分析的评估_v1_2_46_REDTEAM_去外部模型版.qmd"

if not exist "%QMD%" (
  echo [错误] 同目录未见 %QMD%
  echo        请确认本脚本与 qmd 同处一处，且档名版本号一致。
  pause
  exit /b 1
)

set "QUARTO="
where quarto >nul 2>nul && set "QUARTO=quarto"
if not defined QUARTO if exist "C:\Program Files\RStudio\resources\app\bin\quarto\bin\quarto.exe" set "QUARTO=C:\Program Files\RStudio\resources\app\bin\quarto\bin\quarto.exe"
if not defined QUARTO if exist "%LOCALAPPDATA%\Programs\Quarto\bin\quarto.exe" set "QUARTO=%LOCALAPPDATA%\Programs\Quarto\bin\quarto.exe"
if not defined QUARTO (
  echo [错误] 未寻得 quarto。请安装 Quarto，或编辑本脚本填入 QUARTO 路径。
  pause
  exit /b 1
)

echo ===============================================================
echo  第一级：单文件自包含渲染（embed-resources 依 YAML = true）
echo ===============================================================
"%QUARTO%" render "%QMD%" --to html
if not errorlevel 1 goto OK1

echo.
echo [第一级未过] 多因内嵌总装内存峰值超出余量，自动转入第二级……
echo.
echo ===============================================================
echo  第二级：轻装渲染（自动覆写 embed-resources:false，不改档）
echo ===============================================================
"%QUARTO%" render "%QMD%" --to html -M embed-resources:false
if not errorlevel 1 goto OK2
goto FAIL

:OK1
echo.
echo [成功·单文件] 已产出自包含 HTML —— 单档即可分发，无须携带任何目录。
pause
exit /b 0

:OK2
echo.
echo [成功·轻装] 已产出 HTML 与同名 _files 目录 —— 分发时二者必须同行传递。
echo        欲得单文件版：关闭占内存大户（浏览器、IDE 等）后重跑本脚本即可。
pause
exit /b 0

:FAIL
echo.
echo [两级俱败] 若报 error 1455（页面文件太小），依次核办：
echo   其一 性能选项 - 高级 - 虚拟内存[更改]：取消自动管理，选 C 盘，
echo        自定义 初始 8192 / 最大 8192 MB，先点[设置]再点[确定]，然后重启。
echo   其二 重启后先跑本脚本，再开其他程序。
echo   其三 若报其它错，请将本窗口内容整份回传（重定向落盘：渲染.bat ^> 渲染日志.txt 2^>^&1）。
pause
exit /b 1
