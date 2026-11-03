@echo off
setlocal
title Ryzom Core4 - Server Update
echo.
echo Ryzom Core4 Server Update
echo Server herunterfahren, dann dieses Fenster benutzen.
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Server-Update.ps1" %*
set "RESULT=%ERRORLEVEL%"
echo.
if not "%RESULT%"=="0" (
  echo Update NICHT erfolgreich. Fehlercode: %RESULT%
) else (
  echo Update erfolgreich. Server kann jetzt wieder gestartet werden.
)
echo.
pause
exit /b %RESULT%
