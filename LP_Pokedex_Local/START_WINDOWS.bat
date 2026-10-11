@echo off
cd /d "%~dp0"
where py >nul 2>nul
if %errorlevel% equ 0 (
  py -3 server.py
) else (
  where python >nul 2>nul
  if %errorlevel% equ 0 (
    python server.py
  ) else (
    echo Can cai Python 3 truoc khi chay. Xem HUONG_DAN.txt.
    pause
    exit /b 1
  )
)
if errorlevel 1 pause
