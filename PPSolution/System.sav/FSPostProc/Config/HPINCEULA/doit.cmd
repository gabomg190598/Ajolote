echo off

if not defined UPDriveLetter set UPDriveLetter=%~d0 
set Eula_logfile=%UPDriveLetter%\system.sav\logs\OSIT\EULA\HP_EULA.log 
set EULA_DIR=%UPDriveLetter%\WINDOWS\SYSTEM32\OOBE\INFO\DEFAULT

if not exist %UPDriveLetter%\system.sav\logs\OSIT\EULA ( 
    MD %UPDriveLetter%\system.sav\logs\OSIT\EULA 
)

@REM Follow EULA_SOURCES parameter from install.cmd 
if exist %UPDriveLetter%\system.sav\FLAGS\HPINC.flg set EULA_SOURCE=HPINC
if exist %UPDriveLetter%\system.sav\FLAGS\HPEULA2021_HP_wolf_security.flg set EULA_SOURCE=HPEULA2021_HP_wolf_security


if not exist %UPDriveLetter%\SYSTEM.SAV\FLAGS\LANGPACKS\AVAILABLE_LANGUAGES\%3.FLG (
    ECHO Not support Localization,Not exist %UPDriveLetter%\SYSTEM.SAV\FLAGS\LANGPACKS\AVAILABLE_LANGUAGES\%3.FLG >> %Eula_logfile% 
    goto END 
) else (
    ECHO. >> %Eula_logfile% 
    ECHO Exist %UPDriveLetter%\SYSTEM.SAV\FLAGS\LANGPACKS\AVAILABLE_LANGUAGES\%3.FLG >> %Eula_logfile% 
    ECHO Will copy files....... >> %Eula_logfile% 
    ECHO. >> %Eula_logfile% 
)


if not exist %EULA_DIR%\%1 mkdir %EULA_DIR%\%1
echo xcopy /y src\%EULA_SOURCE%\??????-%2?.rtf %EULA_DIR%\%1\OEMEULA.RTF* >> %Eula_logfile%
xcopy /y src\%EULA_SOURCE%\??????-%2?.rtf %EULA_DIR%\%1\OEMEULA.RTF* >> %Eula_logfile%
echo xcopy /y src\%EULA_SOURCE%\??????-%2?.html %EULA_DIR%\%1\OEMEULA.HTML* >> %Eula_logfile%
xcopy /y src\%EULA_SOURCE%\??????-%2?.html %EULA_DIR%\%1\OEMEULA.HTML* >> %Eula_logfile% 
Echo copy /y nul %EULA_DIR%\%1\%4 >> %Eula_logfile% 
copy /y nul %EULA_DIR%\%1\%4
ECHO. >> %Eula_logfile%
:END 



@REM if not exist C:\SYSTEM.SAV\FLAGS\LANGPACKS\AVAILABLE_LANGUAGES\%3.FLG goto END 
@REM if not exist C:\WINDOWS\SYSTEM32\OOBE\INFO\DEFAULT\%1 mkdir C:\WINDOWS\SYSTEM32\OOBE\INFO\DEFAULT\%1 
@REM xcopy /y src\HPEULA2021_HP_wolf_security\??????-%2?.rtf C:\WINDOWS\SYSTEM32\OOBE\INFO\DEFAULT\%1\OEMEULA.RTF* 
@REM xcopy /y src\HPEULA2021_HP_wolf_security\??????-%2?.html C:\WINDOWS\SYSTEM32\OOBE\INFO\DEFAULT\%1\OEMEULA.HTML* 
@REM copy /y nul C:\WINDOWS\SYSTEM32\OOBE\INFO\DEFAULT\%1\%4 
@REM :END 
