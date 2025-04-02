@echo off
set errcode=0

if not defined SPDriveLetter set SPDriveLetter=s:
if not defined UPDriveLetter set UPDriveLetter=%~d0
if not defined BPDriveLetter set BPDriveLetter=z:
set logfile=%UPDriveLetter%\system.sav\logs\install_FPP.log

if not exist "%UPDriveLetter%\system.sav\logs" md "%UPDriveLetter%\system.sav\logs"

echo. >> "%logfile%"
echo ^>^> %~f0 >> "%logfile%"
echo ^>^> %date% %time% >> "%logfile%"
echo. >> "%logfile%"

if exist "c:\system.sav\tweaks\scripts\DmaSecurity_AllowedBuses.cmd" (
    echo *call "c:\system.sav\tweaks\scripts\DmaSecurity_AllowedBuses.cmd" >> "%logfile%"
    call "c:\system.sav\tweaks\scripts\DmaSecurity_AllowedBuses.cmd" >> "%logfile%" 2>&1
)

::echo *reg load hklm\sys %UPDriveLetter%\Windows\System32\Config\SYSTEM >> "%logfile%"
::reg load hklm\sys %UPDriveLetter%\Windows\System32\Config\SYSTEM >> "%logfile%" 2>&1

echo *reg query hklm\SYSTEM\CurrentControlSet\Control\DmaSecurity /s >> "%logfile%"
reg query hklm\SYSTEM\CurrentControlSet\Control\DmaSecurity /s >> "%logfile%" 2>&1

echo *reg export hklm\SYSTEM\CurrentControlSet\Control\DmaSecurity\AllowedBuses "%UPDriveLetter%\system.sav\logs\DMA_AllowedBuses.reg" >> "%logfile%"
reg export hklm\SYSTEM\CurrentControlSet\Control\DmaSecurity\AllowedBuses "%UPDriveLetter%\system.sav\logs\DMA_AllowedBuses.reg" >> "%logfile%" 2>&1

::echo *reg unload hklm\sys >> "%logfile%"
::reg unload hklm\sys >> "%logfile%" 2>&1

echo *xcopy /fhrkyiv "%UPDriveLetter%\system.sav\logs\DMA_AllowedBuses.reg" "%UPDriveLetter%\system.sav\tweaks\Recovery\OEM\Point_B\" >> "%logfile%"
xcopy /fhrkyiv "%UPDriveLetter%\system.sav\logs\DMA_AllowedBuses.reg" "%UPDriveLetter%\system.sav\tweaks\Recovery\OEM\Point_B\" >> "%logfile%" 2>&1
echo *xcopy /fhrkyiv "%UPDriveLetter%\system.sav\tweaks\DMASecurity\Restore_DMA_Whitelist.cmd" "%UPDriveLetter%\system.sav\tweaks\Recovery\OEM\Point_B\" >> "%logfile%"
xcopy /fhrkyiv "%UPDriveLetter%\system.sav\tweaks\DMASecurity\Restore_DMA_Whitelist.cmd" "%UPDriveLetter%\system.sav\tweaks\Recovery\OEM\Point_B\" >> "%logfile%" 2>&1

echo *xcopy /fhrkyiv "%UPDriveLetter%\system.sav\logs\DMA_AllowedBuses.reg" "%UPDriveLetter%\system.sav\tweaks\Recovery\OEM\Point_D\" >> "%logfile%"
xcopy /fhrkyiv "%UPDriveLetter%\system.sav\logs\DMA_AllowedBuses.reg" "%UPDriveLetter%\system.sav\tweaks\Recovery\OEM\Point_D\" >> "%logfile%" 2>&1
echo *xcopy /fhrkyiv "%UPDriveLetter%\system.sav\tweaks\DMASecurity\Restore_DMA_Whitelist.cmd" "%UPDriveLetter%\system.sav\tweaks\Recovery\OEM\Point_D\" >> "%logfile%"
xcopy /fhrkyiv "%UPDriveLetter%\system.sav\tweaks\DMASecurity\Restore_DMA_Whitelist.cmd" "%UPDriveLetter%\system.sav\tweaks\Recovery\OEM\Point_D\" >> "%logfile%" 2>&1


:exit_Clear_DMA_Blacklist

echo. >> "%logfile%"
echo *exit /b %errcode% >> "%logfile%"
echo. >> "%logfile%"
echo ^<^< %~f0 >> "%logfile%"
echo ^<^< %date% %time% >> "%logfile%"
echo. >> "%logfile%"

exit /b %errcode%
