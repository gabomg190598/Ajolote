@echo off
set errcode=0

if not defined SPDriveLetter set SPDriveLetter=s:
if not defined UPDriveLetter set UPDriveLetter=%~d0
if not defined BPDriveLetter set BPDriveLetter=z:
if not defined logfile set logfile=%UPDriveLetter%\system.sav\logs\install_FPP.log

if not exist "%UPDriveLetter%\system.sav\logs" md "%UPDriveLetter%\system.sav\logs"

echo. >> "%logfile%"
echo ^>^> %~f0 >> "%logfile%"
echo ^>^> %date% %time% >> "%logfile%"
echo. >> "%logfile%"

echo *reg load hklm\sys %UPDriveLetter%\Windows\System32\Config\SYSTEM >> "%logfile%"
reg load hklm\sys %UPDriveLetter%\Windows\System32\Config\SYSTEM >> "%logfile%" 2>&1

echo *reg query hklm\sys\ControlSet001\Control\DmaSecurity /s >> "%logfile%"
reg query hklm\sys\ControlSet001\Control\DmaSecurity /s >> "%logfile%" 2>&1

echo *reg import "%~dp0DMA_AllowedBuses.reg" >> "%logfile%"
reg import "%~dp0DMA_AllowedBuses.reg" >> "%logfile%" 2>&1

echo *reg query hklm\sys\ControlSet001\Control\DmaSecurity /s >> "%logfile%"
reg query hklm\sys\ControlSet001\Control\DmaSecurity /s >> "%logfile%" 2>&1

echo *reg unload hklm\sys >> "%logfile%"
reg unload hklm\sys >> "%logfile%" 2>&1


:exit_Clear_DMA_Blacklist

echo. >> "%logfile%"
echo *exit /b %errcode% >> "%logfile%"
echo. >> "%logfile%"
echo ^<^< %~f0 >> "%logfile%"
echo ^<^< %date% %time% >> "%logfile%"
echo. >> "%logfile%"

exit /b %errcode%
