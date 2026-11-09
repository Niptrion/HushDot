@echo off
rem Builds TrayMute.Sensors.exe (camera activity helper) next to TrayMute.ahk, using the
rem C# compiler that ships with Windows (.NET Framework 4.x). Nothing needs to be installed.
rem Usage: helper\build-helper.cmd [output folder]
setlocal
set "CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" set "CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"
if not exist "%CSC%" (
  echo The .NET Framework 4 C# compiler was not found.
  exit /b 1
)
set "HERE=%~dp0"
set "OUT=%~1"
if "%OUT%"=="" set "OUT=%HERE%.."
"%CSC%" /nologo /target:winexe /optimize+ /platform:anycpu ^
  /win32icon:"%HERE%..\icons\app.ico" ^
  /out:"%OUT%\TrayMute.Sensors.exe" "%HERE%TrayMute.Sensors.cs"
exit /b %ERRORLEVEL%
