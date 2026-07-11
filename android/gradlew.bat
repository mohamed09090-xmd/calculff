@echo off
setlocal
set APP_HOME=%~dp0
for /f "tokens=2 delims==" %%A in ('findstr /b distributionUrl "%APP_HOME%gradle\wrapper\gradle-wrapper.properties"') do set URL=%%A
set URL=%URL:\:=%
for /f "tokens=2 delims=-" %%A in ("%URL%") do set VERSION=%%A
set CACHE=%USERPROFILE%\.gradle\wrapper\manual\gradle-%VERSION%
set BIN=%CACHE%\gradle-%VERSION%\bin\gradle.bat
if not exist "%BIN%" (
  if not exist "%CACHE%" mkdir "%CACHE%"
  powershell -NoProfile -Command "Invoke-WebRequest -Uri '%URL%' -OutFile '%CACHE%\gradle.zip'; Expand-Archive -Path '%CACHE%\gradle.zip' -DestinationPath '%CACHE%' -Force; Remove-Item '%CACHE%\gradle.zip'"
)
call "%BIN%" %*
