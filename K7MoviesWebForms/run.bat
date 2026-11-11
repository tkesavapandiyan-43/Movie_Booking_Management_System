@echo off
REM ============================================================
REM  K7 Movies - ASP.NET Web Forms (.aspx) - double-click to run
REM ============================================================
set "IISX=%ProgramFiles%\IIS Express\iisexpress.exe"
if not exist "%IISX%" set "IISX=%ProgramFiles(x86)%\IIS Express\iisexpress.exe"
if not exist "%IISX%" (
    echo IIS Express was not found.
    echo Install Visual Studio 2022 with "ASP.NET and web development", or
    echo download IIS Express from Microsoft, then run this file again.
    pause
    exit /b 1
)
pushd "%~dp0"
set "SITE=%CD%"
echo Starting K7 Movies from: %SITE%
echo Address: http://localhost:5080/Default.aspx
start "K7 Movies server" "%IISX%" /path:"%SITE%" /port:5080
timeout /t 4 /nobreak >nul
start "" http://localhost:5080/Default.aspx
echo.
echo The site is running. Close the "K7 Movies server" window to stop it.
echo Database check: http://localhost:5080/Health.aspx
echo Admin login: Kesavan / Kesavan@43     Customer: demo / User@123
popd
pause
