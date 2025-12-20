@ECHO OFF

set INSTALLPATH=

if exist "%programfiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" (
  for /F "tokens=* USEBACKQ" %%F in (`"%programfiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -version 16.0 -property installationPath`) do set INSTALLPATH=%%F
)


call "%INSTALLPATH%\Common7\Tools\VsDevCmd.bat"


msbuild "Z:\Dropbox\Guy\SourceTree_repo\Skalp\Skalp_external_application\Skalp_external_application.sln"  /t:rebuild
msbuild "Z:\Dropbox\Guy\SourceTree_repo\Skalp\SUEX_Skalp\SkalpC_2.7.sln" /t:rebuild
pause