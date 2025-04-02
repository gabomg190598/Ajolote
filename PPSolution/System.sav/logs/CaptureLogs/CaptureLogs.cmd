@echo off

set CaptureDir=%1
set WinDrive=%2

if not defined CaptureDir (
    set CaptureDir=%~d0
)

if not exist "%CaptureDir%" (
    echo.
    echo ***ERROR*** "%CaptureDir%" doesn't exist!
    echo.
    goto lbl_Usage
)

copy nul "%CaptureDir%\LOG" >nul 2>&1
if errorlevel 1 (
    echo.
    echo ***ERROR*** "%CaptureDir%" is not write-accessible!
    echo.
    goto lbl_Usage
)

if exist "%CaptureDir%\LOG" del "%CaptureDir%\LOG" >nul 2>&1

if defined WinDrive goto WinDriveFound

for %%i in (c d e f g h i j k l m n o p q r s t u v w) do (
    vol %%i: >nul 2>&1
    if not errorlevel 1 (
        if exist %%i:\System.sav\CTO.txt (
            set WinDrive=%%i:
        ) else if exist %%i:\System.sav\FLAGS (
            set WinDrive=%%i:
        )
    )
)


:WinDriveFound

if not exist "%WinDrive%\system.sav\logs" (
    echo.
    echo ***ERROR*** The specified Windows drive doesn't exist!
    echo.
    goto lbl_Usage
)

if not exist "%WinDrive%\Windows" (
    echo.
    echo ***ERROR*** The specified Windows drive doesn't exist!
    echo.
    goto lbl_Usage
)

set CptLogFile=%WinDrive%\system.sav\flags\FactoryLogsRSLT.flg

echo. >> "%CptLogFile%"
echo ^>^> %~f0 >> "%CptLogFile%"
echo ^>^> %date% %time% >> "%CptLogFile%"
echo. >> "%CptLogFile%"

rem
rem The intended command is
rem     CaptureLogs.cmd %CaptureDir% %WinDrive%
rem

echo CmdLine=%~f0 %CaptureDir% %WinDrive% >> "%CptLogFile%"
echo. >> "%CptLogFile%"

rem
rem <Serial>_UTC<YYYYMMDDhhmmss>_System.Sav_<Pass/Fail>.7z
rem

rem
rem Get unit serial #
rem
for /f "tokens=2 delims==" %%i IN ('wmic csproduct get identifyingnumber /value') do set UNITSN=%%i

rem LS modify 20210504
rem
rem Identify the running environment, full OS or WinPE
rem
set OSENV=PE
if /i [%windir%]==[C:\Windows] (
    set OSENV=OS
) else (
	xcopy /fhsrkyiv %~dp0wmitimep\*.* x:\windows\system32\wbem\*.*
	regsvr32.exe /s x:\windows\system32\wbem\wmitimep.dll
	mofcomp x:\windows\system32\wbem\wmitimep.mof
)

rem
rem Get UTC date and time
rem
for /f %%i in ('wmic path Win32_UTCTime get Year^,Month^,Day^,Hour^,Minute^,Second /format:list ^| find /i "="') do (set %%i)
set Second=0%Second%
set Second=%Second:~-2%
set Minute=0%Minute%
set Minute=%Minute:~-2%
set Hour=0%Hour%
set Hour=%Hour:~-2%
set Day=0%Day%
set Day=%Day:~-2%
set Month=0%Month%
set Month=%Month:~-2%
set UTCTimestamp=%Year%%Month%%Day%%Hour%%Minute%%Second%

rem
rem LS modify 20210505 adding DASH mode
rem
IF EXIST %WinDrive%\System.Sav\FLAGS\MLGM2.flg (
	SET IMGMODE=MLGM2
) ELSE IF EXIST %WinDrive%\System.Sav\FLAGS\HWD-GMPP.flg (
	SET IMGMODE=GMPPHWD
) ELSE (
	SET IMGMODE=DirectDASH
)

set FNPrefix=%UNITSN%_UTC%UTCTimestamp%_%OSENV%_%IMGMODE%

echo FNPrefix=%FNPrefix% >> "%CptLogFile%"
echo. >> "%CptLogFile%"

echo OSENV=%OSENV% >> "%CptLogFile%"
echo. >> "%CptLogFile%"

if exist "%WinDrive%\system.sav\*_system.sav.7z" (
    echo ***INFO*** Not the first capture! >> "%CptLogFile%"
    echo. >> "%CptLogFile%"
    echo *dir /a "%WinDrive%\system.sav\*_system.sav.7z" >> "%CptLogFile%"
    dir /a "%WinDrive%\system.sav\*_system.sav.7z" >> "%CptLogFile%" 2>&1

    goto lbl_captureSysinfo
)

rem
rem Back up Windows log files
rem
xcopy /fhsrkyiv %WinDrive%\$SysReset\*.*                       %WinDrive%\system.sav\logs\WINDRIVE\$SysReset\

xcopy /fhsrkyiv %WinDrive%\ProgramData\HP\*.etl                %WinDrive%\system.sav\logs\WINDRIVE\ProgramData\HP\
xcopy /fhsrkyiv %WinDrive%\ProgramData\HP\*.ini                %WinDrive%\system.sav\logs\WINDRIVE\ProgramData\HP\
xcopy /fhsrkyiv %WinDrive%\ProgramData\HP\*.log                %WinDrive%\system.sav\logs\WINDRIVE\ProgramData\HP\

xcopy /fhsrkyiv %WinDrive%\Windows\INF\setupapi*.log           %WinDrive%\system.sav\logs\WINDRIVE\Windows\INF\
xcopy /fhsrkyiv %WinDrive%\Windows\Logs\*.*                    %WinDrive%\system.sav\logs\WINDRIVE\Windows\Logs\
xcopy /fhsrkyiv %WinDrive%\Windows\Panther\*.etl               %WinDrive%\system.sav\logs\WINDRIVE\Windows\Panther\
xcopy /fhsrkyiv %WinDrive%\Windows\Panther\*.log               %WinDrive%\system.sav\logs\WINDRIVE\Windows\Panther\
xcopy /fhsrkyiv %WinDrive%\Windows\Panther\*.uaq               %WinDrive%\system.sav\logs\WINDRIVE\Windows\Panther\
xcopy /fhsrkyiv %WinDrive%\Windows\Panther\*.xml               %WinDrive%\system.sav\logs\WINDRIVE\Windows\Panther\
IF EXIST "%WinDrive%\Windows\Panther\UnattendGC" (
	xcopy /fhsrkyiv %WinDrive%\Windows\Panther\UnattendGC\*.etl               %WinDrive%\system.sav\logs\WINDRIVE\Windows\Panther\UnattendGC\
	xcopy /fhsrkyiv %WinDrive%\Windows\Panther\UnattendGC\*.log               %WinDrive%\system.sav\logs\WINDRIVE\Windows\Panther\UnattendGC\
	xcopy /fhsrkyiv %WinDrive%\Windows\Panther\UnattendGC\*.uaq               %WinDrive%\system.sav\logs\WINDRIVE\Windows\Panther\UnattendGC\
	xcopy /fhsrkyiv %WinDrive%\Windows\Panther\UnattendGC\*.xml               %WinDrive%\system.sav\logs\WINDRIVE\Windows\Panther\UnattendGC\
)
xcopy /fhsrkyiv %WinDrive%\Windows\PBR\*.*                     %WinDrive%\system.sav\logs\WINDRIVE\Windows\PBR\
xcopy /fhsrkyiv %WinDrive%\Windows\Performance\WinSAT\*.log    %WinDrive%\system.sav\logs\WINDRIVE\Windows\Performance\WinSAT\
xcopy /fhsrkyiv %WinDrive%\Windows\Setup\*.*                   %WinDrive%\system.sav\logs\WINDRIVE\Windows\Setup\
xcopy /fhsrkyiv %WinDrive%\Windows\System32\drivers\*.MRK      %WinDrive%\system.sav\logs\WINDRIVE\Windows\System32\drivers\
xcopy /fhsrkyiv %WinDrive%\Windows\System32\sysprep\*.etl      %WinDrive%\system.sav\logs\WINDRIVE\Windows\System32\sysprep\
xcopy /fhsrkyiv %WinDrive%\Windows\System32\sysprep\*.log      %WinDrive%\system.sav\logs\WINDRIVE\Windows\System32\sysprep\
xcopy /fhsrkyiv %WinDrive%\Windows\System32\sysprep\*.uaq      %WinDrive%\system.sav\logs\WINDRIVE\Windows\System32\sysprep\
xcopy /fhsrkyiv %WinDrive%\Windows\System32\sysprep\*.xml      %WinDrive%\system.sav\logs\WINDRIVE\Windows\System32\sysprep\
xcopy /fhsrkyiv %WinDrive%\Windows\System32\winevt\Logs\*.evtx %WinDrive%\system.sav\logs\WINDRIVE\Windows\System32\winevt\Logs\
xcopy /fhsrkyiv %WinDrive%\Windows\Setup\Scripts\*.xml         %WinDrive%\system.sav\logs\WINDRIVE\Windows\Setup\Scripts\
xcopy /fhsrkyiv %WinDrive%\Windows\Setup\Scripts\*.log         %WinDrive%\system.sav\logs\WINDRIVE\Windows\Setup\Scripts\
xcopy /fhsrkyiv %WinDrive%\Windows\Setup\Scripts\*.txt         %WinDrive%\system.sav\logs\WINDRIVE\Windows\Setup\Scripts\
xcopy /fhsrkyiv %WinDrive%\Windows\Setup\Scripts\*.dat         %WinDrive%\system.sav\logs\WINDRIVE\Windows\Setup\Scripts\
xcopy /fhsrkyiv %WinDrive%\Windows\Setup\Scripts\*.ini         %WinDrive%\system.sav\logs\WINDRIVE\Windows\Setup\Scripts\


IF NOT EXIST %WinDrive%\HP\CSSETUP GOTO SkipCS
xcopy /fhsrkyiv %WinDrive%\HP\CSSETUP\*.log                    %WinDrive%\system.sav\logs\CSSETUP\
xcopy /fhsrkyiv %WinDrive%\HP\CSSETUP\*.txt                    %WinDrive%\system.sav\logs\CSSETUP\
xcopy /fhsrkyiv %WinDrive%\HP\CSSETUP\*.ini                    %WinDrive%\system.sav\logs\CSSETUP\
xcopy /fhsrkyiv %WinDrive%\HP\CSSETUP\*.dat                    %WinDrive%\system.sav\logs\CSSETUP\
xcopy /fhsrkyiv %WinDrive%\HP\CSSETUP\CSAuditMode\*.log                    %WinDrive%\system.sav\logs\CSSETUP\CSAuditMode\
xcopy /fhsrkyiv %WinDrive%\HP\CSSETUP\CSAuditMode\*.txt                    %WinDrive%\system.sav\logs\CSSETUP\CSAuditMode\
xcopy /fhsrkyiv %WinDrive%\HP\CSSETUP\CSAuditMode\*.ini                    %WinDrive%\system.sav\logs\CSSETUP\CSAuditMode\
xcopy /fhsrkyiv %WinDrive%\HP\CSSETUP\CSAuditMode\*.dat                    %WinDrive%\system.sav\logs\CSSETUP\CSAuditMode\
:SkipCS

rem
rem Back up BP log files
rem
set BPDriveLetter=
for %%i in (D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z) do (
    vol %%i: >nul 2>&1
    if not errorlevel 1 (
        if exist %%i:\SystemRecovery if exist %%i:\Maestro (
            set BPDriveLetter=%%i:
        )
    )
)

if defined BPDriveLetter (
    xcopy /exclude:.\xcopyexc.ini /fhsrkyiv %BPDriveLetter%\*.log %WinDrive%\system.sav\logs\BPDRIVE\
)


:lbl_captureSysinfo

if exist "%WinDrive%\system.sav\UnitInfo" rd /s /q "%WinDrive%\system.sav\UnitInfo"
md "%WinDrive%\system.sav\UnitInfo"

echo *diskpart.exe -s "%~dp07z\dpinfo.txt" ^>^> "%WinDrive%\system.sav\UnitInfo\%FNPrefix%_Disk.log" >> "%CptLogFile%"
diskpart.exe -s "%~dp07z\dpinfo.txt" >> "%WinDrive%\system.sav\UnitInfo\%FNPrefix%_Disk.log" 2>&1
echo. >> "%CptLogFile%"

echo *"%~dp07z\%PROCESSOR_ARCHITECTURE%\BiosConfigUtility.exe" /get:"%WinDrive%\system.sav\UnitInfo\%FNPrefix%_BCU.log" >> "%CptLogFile%"
"%~dp07z\%PROCESSOR_ARCHITECTURE%\BiosConfigUtility.exe" /get:"%WinDrive%\system.sav\UnitInfo\%FNPrefix%_BCU.log" >> "%CptLogFile%" 2>&1
echo. >> "%CptLogFile%"

echo *"%~dp07z\%PROCESSOR_ARCHITECTURE%\devcon.exe" findall * ^>^> "%WinDrive%\system.sav\UnitInfo\%FNPrefix%_device_all.log" >> "%CptLogFile%"
"%~dp07z\%PROCESSOR_ARCHITECTURE%\devcon.exe" findall * >> "%WinDrive%\system.sav\UnitInfo\%FNPrefix%_device_all.log" 2>&1
echo errorlevel=%errorlevel% >> "%CptLogFile%"
echo. >> "%CptLogFile%"

echo *"%~dp07z\%PROCESSOR_ARCHITECTURE%\devcon.exe" drivernodes * ^>^> "%WinDrive%\system.sav\UnitInfo\%FNPrefix%_device_drv.log" >> "%CptLogFile%"
"%~dp07z\%PROCESSOR_ARCHITECTURE%\devcon.exe" drivernodes * >> "%WinDrive%\system.sav\UnitInfo\%FNPrefix%_device_drv.log" 2>&1
echo errorlevel=%errorlevel% >> "%CptLogFile%"
echo. >> "%CptLogFile%"

echo *"%~dp07z\%PROCESSOR_ARCHITECTURE%\devcon.exe" status * ^>^> "%WinDrive%\system.sav\UnitInfo\%FNPrefix%_device_drv.log" >> "%CptLogFile%"
"%~dp07z\%PROCESSOR_ARCHITECTURE%\devcon.exe" status * >> "%WinDrive%\system.sav\UnitInfo\%FNPrefix%_device_drv.log" 2>&1
echo errorlevel=%errorlevel% >> "%CptLogFile%"
echo. >> "%CptLogFile%"

echo *wmic CPU list full ^>^> "%WinDrive%\system.sav\UnitInfo\%FNPrefix%_wmic_CPU.log" >> "%CptLogFile%"
wmic CPU list full >> "%WinDrive%\system.sav\UnitInfo\%FNPrefix%_wmic_CPU.log" 2>&1
echo errorlevel=%errorlevel% >> "%CptLogFile%"
echo. >> "%CptLogFile%"

echo *wmic MemoryChip list full ^>^> "%WinDrive%\system.sav\UnitInfo\%FNPrefix%_wmic_MemoryChip.log" >> "%CptLogFile%"
wmic MemoryChip list full >> "%WinDrive%\system.sav\UnitInfo\%FNPrefix%_wmic_MemoryChip.log" 2>&1
echo errorlevel=%errorlevel% >> "%CptLogFile%"
echo. >> "%CptLogFile%"

echo *wmic DiskDrive list full ^>^> "%WinDrive%\system.sav\UnitInfo\%FNPrefix%_wmic_DiskDrive.log" >> "%CptLogFile%"
wmic DiskDrive list full >> "%WinDrive%\system.sav\UnitInfo\%FNPrefix%_wmic_DiskDrive.log" 2>&1
echo errorlevel=%errorlevel% >> "%CptLogFile%"
echo. >> "%CptLogFile%"

if /i [%OSENV%]==[OS] (
    echo *start /min /wait MSINFO32.EXE /report %WinDrive%\system.sav\UnitInfo\msinfo32.log >> "%CptLogFile%"
    start /min /wait MSINFO32.EXE /report %WinDrive%\system.sav\UnitInfo\msinfo32.log
    echo. >> "%CptLogFile%"
) else if exist x:\ (
    xcopy /fhrkyiv  x:\*.log            %WinDrive%\system.sav\logs\XDRIVE\
    xcopy /fhsrkyiv x:\$SysReset\*.*    %WinDrive%\system.sav\logs\XDRIVE\$SysReset\
    xcopy /fhsrkyiv x:\Windows\Logs\*.* %WinDrive%\system.sav\logs\XDRIVE\Windows\Logs\
)

echo. >> "%CptLogFile%"
echo ^<^< %~f0 >> "%CptLogFile%"
echo ^<^< %date% %time% >> "%CptLogFile%"
echo. >> "%CptLogFile%"


if exist "%WinDrive%\system.sav\*_system.sav.7z" goto lbl_NotFirstCapture

pushd %~dp07z
%PROCESSOR_ARCHITECTURE%\7z.exe a "%CaptureDir%\%FNPrefix%_system.sav.7z" -ssw -ir!%WinDrive%\SYSTEM.SAV -xr@logexc.ini -xr!WINDRIVE -xr!XDRIVE -xr!BPDRIVE
%PROCESSOR_ARCHITECTURE%\7z.exe a "%CaptureDir%\%FNPrefix%_system.sav.7z" -ssw -ir!%WinDrive%\SYSTEM.SAV\logs\WINDRIVE\$SysReset -ir!%WinDrive%\SYSTEM.SAV\logs\WINDRIVE\ProgramData -ir!%WinDrive%\SYSTEM.SAV\logs\WINDRIVE\Windows -ir!%WinDrive%\SYSTEM.SAV\logs\XDRIVE -ir!%WinDrive%\SYSTEM.SAV\logs\BPDRIVE
popd
goto lbl_BackupCapture

:lbl_NotFirstCapture

pushd %WinDrive%\SYSTEM.SAV
%~dp07z\%PROCESSOR_ARCHITECTURE%\7z.exe a "%CaptureDir%\%FNPrefix%_system.sav.7z" -ssw .\UnitInfo .\*_system.sav.7z
popd

:lbl_BackupCapture
if not exist "%WinDrive%\%FNPrefix%_system.sav.7z" xcopy /fhrkyiv "%CaptureDir%\%FNPrefix%_system.sav.7z" "%WinDrive%\%FNPrefix%_system.sav.7z"
  
goto :eof


:lbl_Usage

echo         CS MODIFIED SCRIPT
echo Usage:  CaptureLogs.cmd  ^<capturedir^>  ^<windrive^>
echo Ex:     CaptureLogs.cmd f: c:
echo.
