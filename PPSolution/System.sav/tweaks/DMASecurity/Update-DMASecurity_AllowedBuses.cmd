@echo off

set UPDriveLetter=%~d0
set logfile=%UPDriveLetter%\system.sav\logs\install_FPP.log
set errfile=%UPDriveLetter%\system.sav\logs\install_FPP.err

echo. >> "%logfile%"
echo ^>^> %~f0 >> "%logfile%"
echo ^>^> %date% %time% >> "%logfile%"
echo. >> "%logfile%"

rem
rem Take ownership of the registry value that needs to be updated and then provides permissions so
rem Administrators can add to the registry value (HKLM\SYSTEM\CurrentControlSet\Control\DmaSecurity\AllowedBuses)
rem
echo *powershell.exe -executionpolicy unrestricted -windowstyle hidden -file "%~dp0takeownership_before.ps1" >> "%logfile%"
powershell.exe -executionpolicy unrestricted -windowstyle hidden -file "%~dp0takeownership_before.ps1" >> "%logfile%" 2>&1

rem
rem Update the AllowedBuses registry key
rem
echo *cscript //nologo "%~dp0dmasecurity.vbs" >> "%logfile%"
cscript //nologo "%~dp0dmasecurity.vbs" >> "%logfile%" 2>&1

if exist "c:\system.sav\tweaks\scripts\DmaSecurity_AllowedBuses.cmd" (
    echo. >> "%logfile%"
    echo --- "c:\system.sav\tweaks\scripts\DmaSecurity_AllowedBuses.cmd" --- >> "%logfile%"
    type "c:\system.sav\tweaks\scripts\DmaSecurity_AllowedBuses.cmd" >> "%logfile%" 2>&1
    echo --------------------- >> "%logfile%"
    echo. >> "%logfile%"
)

echo. >> "%logfile%"
echo ^<^< %~f0 >> "%logfile%"
echo ^<^< %date% %time% >> "%logfile%"
echo. >> "%logfile%"
