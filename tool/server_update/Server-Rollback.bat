@echo off
setlocal
title Ryzom Core4 - Server Rollback
echo.
echo Ryzom Core4 - letzte Serveraktualisierung zuruecknehmen
echo Serverdienste vorher herunterfahren!
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Server-Rollback.ps1" %*
set "RESULT=%ERRORLEVEL%"
echo.
if not "%RESULT%"=="0" (
  echo Rollback NICHT erfolgreich. Fehlercode: %RESULT%
) else (
  echo Vorherige Server-EXEs wiederhergestellt.
)
echo.
pause
exit /b %RESULT%
