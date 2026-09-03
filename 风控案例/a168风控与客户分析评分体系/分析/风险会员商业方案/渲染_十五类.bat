@echo off
chcp 65001 >nul
cd /d "%~dp0"
set "QUARTO="
where quarto >nul 2>nul && set "QUARTO=quarto"
if not defined QUARTO if exist "C:\Program Files\RStudio\resources\app\bin\quarto\bin\quarto.exe" set "QUARTO=C:\Program Files\RStudio\resources\app\bin\quarto\bin\quarto.exe"
if not defined QUARTO ( echo [ERR] quarto not found & pause & exit /b 1 )
"%QUARTO%" render "T-01_同桌聚集_商业方案_v1.8.0.qmd" --to html || echo [FAIL] T-01_同桌聚集_商业方案_v1.8.0.qmd
"%QUARTO%" render "T-02_荷官_玩家串谋_商业方案_v1.8.0.qmd" --to html || echo [FAIL] T-02_荷官_玩家串谋_商业方案_v1.8.0.qmd
"%QUARTO%" render "T-03_尾投／靴尾下注_商业方案_v1.8.0.qmd" --to html || echo [FAIL] T-03_尾投／靴尾下注_商业方案_v1.8.0.qmd
"%QUARTO%" render "T-04_跨账户对打／对冲_商业方案_v1.8.0.qmd" --to html || echo [FAIL] T-04_跨账户对打／对冲_商业方案_v1.8.0.qmd
"%QUARTO%" render "T-05_自我对冲／打水_商业方案_v1.8.0.qmd" --to html || echo [FAIL] T-05_自我对冲／打水_商业方案_v1.8.0.qmd
"%QUARTO%" render "T-06_异常 IP 聚集_商业方案_v1.8.0.qmd" --to html || echo [FAIL] T-06_异常 IP 聚集_商业方案_v1.8.0.qmd
"%QUARTO%" render "T-07_技术型玩家_优势打法__商业方案_v1.8.0.qmd" --to html || echo [FAIL] T-07_技术型玩家_优势打法__商业方案_v1.8.0.qmd
"%QUARTO%" render "T-08_退水／占成套利_商业方案_v1.8.0.qmd" --to html || echo [FAIL] T-08_退水／占成套利_商业方案_v1.8.0.qmd
"%QUARTO%" render "T-09_代理线自打／养号_商业方案_v1.8.0.qmd" --to html || echo [FAIL] T-09_代理线自打／养号_商业方案_v1.8.0.qmd
"%QUARTO%" render "T-10_账务恒等式残差_内控对账／内部舞弊侦测__商业方案_v1.8.0.qmd" --to html || echo [FAIL] T-10_账务恒等式残差_内控对账／内部舞弊侦测__商业方案_v1.8.0.qmd
"%QUARTO%" render "T-11_多账户／共享设备_商业方案_v1.8.0.qmd" --to html || echo [FAIL] T-11_多账户／共享设备_商业方案_v1.8.0.qmd
"%QUARTO%" render "T-12_机器人／脚本下注_商业方案_v1.8.0.qmd" --to html || echo [FAIL] T-12_机器人／脚本下注_商业方案_v1.8.0.qmd
"%QUARTO%" render "T-13_夜间异常活动_商业方案_v1.8.0.qmd" --to html || echo [FAIL] T-13_夜间异常活动_商业方案_v1.8.0.qmd
"%QUARTO%" render "T-14_限红试探_商业方案_v1.8.0.qmd" --to html || echo [FAIL] T-14_限红试探_商业方案_v1.8.0.qmd
"%QUARTO%" render "T-15_静默复活／账户接管_商业方案_v1.8.0.qmd" --to html || echo [FAIL] T-15_静默复活／账户接管_商业方案_v1.8.0.qmd
echo DONE
pause
