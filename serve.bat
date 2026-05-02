@echo off
chcp 65001 >nul
cd /d "%~dp0"

set "ROJO_EXE=%~dp0tools\rojo\rojo.exe"
if exist "%ROJO_EXE%" (
  "%ROJO_EXE%" serve
  exit /b %ERRORLEVEL%
)

where rojo >nul 2>&1
if %ERRORLEVEL%==0 (
  rojo serve
  exit /b %ERRORLEVEL%
)

echo.
echo Rojo не найден в PATH и нет файла:
echo   %ROJO_EXE%
echo.
echo Сделайте ОДИН из вариантов:
echo   A^) winget install -e --id Rojo.Rojo
echo      затем ЗАКРОЙТЕ и снова откройте cmd/PowerShell
echo.
echo   B^) Скачайте Windows-бинарник:
echo      https://github.com/rojo-rbx/rojo/releases/latest
echo      Положите rojo.exe сюда: tools\rojo\rojo.exe
echo      и снова запустите serve.bat
echo.
pause
exit /b 1
