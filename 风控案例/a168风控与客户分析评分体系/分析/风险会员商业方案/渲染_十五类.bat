@echo off
chcp 65001 >nul
cd /d "%~dp0"
set "QUARTO="
where quarto >nul 2>nul && set "QUARTO=quarto"
if not defined QUARTO if exist "C:\Program Files\RStudio\resources\app\bin\quarto\bin\quarto.exe" set "QUARTO=C:\Program Files\RStudio\resources\app\bin\quarto\bin\quarto.exe"
if not defined QUARTO ( echo [ERR] quarto not found & pause & exit /b 1 )
"%QUARTO%" render "T-01_同桌聚集_商业方案_v1.4.1.qmd" --to html || echo [FAIL] T-01_同桌聚集_商业方案_v1.4.1.qmd
"%QUARTO%" render "T-03_尾投／靴尾下注_商业方案_v1.4.1.qmd" --to html || echo [FAIL] T-03_尾投／靴尾下注_商业方案_v1.4.1.qmd
echo DONE
pause
