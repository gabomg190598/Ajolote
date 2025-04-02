@echo off
set errcode=0

set UPDriveLetter=%~d0
set logfile=%UPDriveLetter%\system.sav\logs\_FSPostProcessingMode.log
set errfile=%UPDriveLetter%\system.sav\logs\_FSPostProcessingMode.err
set fserror=%UPDriveLetter%\system.sav\flags\cserror.flg
set fspath=%UPDriveLetter%\system.sav\FSPostProc
set capturelogpath=%UPDriveLetter%\system.sav\logs\CaptureLogs

set custuna=%UPDriveLetter%\System.sav\CustomUnattend


echo. >> "%logfile%"
echo ^>^> %~f0 >> "%logfile%"
echo ^>^> %date% %time% >> "%logfile%"
echo. >> "%logfile%"


IF EXIST %fserror% GOTO error_flg
IF EXIST %custuna% GOTO copy_unattend
IF EXIST %UPDriveLetter%\Windows\Panther\Unattend GOTO remove_unattend
GOTO go_wdt0


:go_wdt0
IF EXIST %UPDriveLetter%\System.sav\WDT\OSChanger64.exe (
	cd %UPDriveLetter%\System.sav\WDT
	echo List files on current dir: >> "%logfile%"
	dir /b >> "%logfile%"
	echo back to WDT on success >> "%logfile%"
	echo *start /wait %UPDriveLetter%\System.sav\WDT\OSChanger64.exe /WDT /ABO /ABON /ErrorNumber:0 /Message:"***PASS*** The CS Audit Mode has been completed successfully" >> "%logfile%"
	start /wait %UPDriveLetter%\System.sav\WDT\OSChanger64.exe /WDT /ABO /ABON /ErrorNumber:0 /Message:"***PASS*** The CS Audit Mode has been completed successfully"
)
GOTO go_exit


:go_wdt1
IF EXIST %UPDriveLetter%\System.sav\WDT\OSChanger64.exe (
	cd %UPDriveLetter%\System.sav\WDT
	echo List files on current dir: >> "%logfile%"
	dir /b >> "%logfile%"
	echo back to WDT on error >> "%logfile%"
	echo *start /wait %UPDriveLetter%\System.sav\WDT\OSChanger64.exe /WDT /ABO /ABON /ErrorNumber:999 /Message:"***FAIL***The CS Post Processing fail unamanaged exception" >> "%logfile%"
	start /wait %UPDriveLetter%\System.sav\WDT\OSChanger64.exe /WDT /ABO /ABON /ErrorNumber:999 /Message:"***FAIL***The CS Post Processing fail unamanaged exception"
)
GOTO go_exit

 
:copy_unattend
echo Custom unattend folder detected, if exist unattend.xml will be used otherwise all contained files will moved to Panther\Unattend >> "%logfile%"
IF EXIST %custuna%\unattend.xml xcopy /hiy %custuna%\unattend.xml %UPDriveLetter%\Windows\Panther\Unattend\
IF NOT EXIST %custuna%\unattend.xml xcopy /hiy %custuna%\* %UPDriveLetter%\Windows\Panther\Unattend\
GOTO go_wdt0

:remove_unattend
echo Removing Panther\Unattend folder >> "%logfile%"
rd /s /q %UPDriveLetter%\Windows\Panther\Unattend
GOTO go_wdt0


GOTO go_exit
:error_flg
echo FS ERROR FLAG DETECTED RETURN FAIL PROCESS >> "%logfile%"
set errcode=25031981
GOTO go_wdt1


:go_exit
ping -n 5 127.0.0.1 >null
cd /
IF NOT EXIST %fserror% IF EXIST "%fspath%" (
	echo Removing "%fspath%" >> "%logfile%"
	rd /s /q "%fspath%"
)
IF EXIST %capturelogpath% (
	echo Removing "%capturelogpath%" >> "%logfile%"
	rd /s /q "%capturelogpath%"
)

echo. >> "%logfile%"
echo *exit /b %errcode% >> "%logfile%"
echo. >> "%logfile%"
echo ^<^< %~f0 >> "%logfile%"
echo ^<^< %date% %time% >> "%logfile%"
echo. >> "%logfile%"
exit /b %errcode%