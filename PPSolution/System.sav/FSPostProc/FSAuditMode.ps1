<#
.SYNOPSIS
    HP FS Audit Mode Configuration
.DESCRIPTION
	Configure FS Images
	This version only support Windows 10 minimum version 1909 and Windwos 11
.NOTES
	Script version:		2.0.0 | Update $ScriptVersion variable
	   Script Date: 	Feb.2.2024
	Script support: 	jocisneros@hp.com - HP Inc.
.EXAMPLE
    FSAuditMode.ps1
.OUTPUTCODES
	404 - Missing Module
	405 - Failed import Module
	401 - Missing OSChangerXXX.exe
	/ErrorNumber:700 /Message:"***FAIL*** The CS Post Processing fail unexpected on 1PP phase"
	/ErrorNumber:710 /Message:"***FAIL*** The CS Post Processing fail detecting correct OEM PK"
	/ErrorNumber:711 /Message:"***FAIL*** The CS Post Processing fail installing OEM PK"
	/ErrorNumber:712 /Message:"***FAIL*** The CS Post Processing fail HP Complete installation"
	/ErrorNumber:713 /Message:"***FAIL*** The CS Post Processing fail HP Complete HPDrivers folder persit
	/ErrorNumber:714 /Message:"***FAIL*** The CS Post Processing fail HPComplete tools missing"
	/ErrorNumber:715 /Message:"***FAIL*** The CS Post Processing fail Device Manager has errors"
	/ErrorNumber:716 /Message:"***FAIL*** The CS Post Processing fail missing USMT tool"
	/ErrorNumber:717 /Message:"***FAIL*** The CS Post Processing fail capturing image state"
	/ErrorNumber:718 /Message:"***FAIL*** The CS Post Processing fail sysprep to 2nd PP phase"
	/ErrorNumber:719 /Message:"***FAIL*** The CS Post Processing fail missing Unattend file require for 2nd PP phase"
	/ErrorNumber:720 /Message:"***FAIL*** The CS Post Processing fail sysprep closing 1st PP phase"
	/ErrorNumber:721 /Message:"***FAIL*** The CS Post Processing fail Language install by localization due missing dictionary"
	/ErrorNumber:722 /Message:"***FAIL*** The CS Post Processing fail Language install due missing LP file"
	/ErrorNumber:723 /Message:"***FAIL*** The CS Post Processing fail Language install return error"
	/ErrorNumber:724 /Message:"***FAIL*** The CS Post Processing fail MS Updates return error"
	/ErrorNumber:725 /Message:"***FAIL*** The CS Post Processing fail MS Office structure unexpected"
	/ErrorNumber:726 /Message:"***FAIL*** The CS Post Processing fail MS Office setup"
	/ErrorNumber:727 /Message:"***FAIL*** The CS Post Processing fail MS Updates missing"
	/ErrorNumber:728 /Message:"***FAIL*** The CS Post Processing fail SetupTools missing install.cmd"
	/ErrorNumber:729 /Message:"***FAIL*** The CS Post Processing fail SetupTools error on execution"
	/ErrorNumber:730 /Message:"***FAIL*** The CS Post Processing fail Preconfig Office CS File is missing"
	/ErrorNumber:731 /Message:"***FAIL*** The CS Post Processing fail Preconfig Office fail package setup error"
	/ErrorNumber:732 /Message:"***FAIL*** The CS Post Processing fail Preconfig Office fail missing install.cmd"
	/ErrorNumber:733 /Message:"***FAIL*** The CS Post Processing fail WinRE is disabled"
	/ErrorNumber:734 /Message:"***FAIL*** The CS Post Processing fail not possible validate WinRE"
	/ErrorNumber:735 /Message:"***FAIL*** The CS Post Processing fail not possible switch OS and Capture Image"
	/ErrorNumber:736 /Message:"***FAIL*** The CS Post Processing fail not found WinPE capture package"
	/ErrorNumber:737 /Message:"***FAIL*** The CS Post Processing fail unexpected during capture phase"
	/ErrorNumber:738 /Message:"***FAIL*** The CS Post Processing fail preparinng capture environment"
	/ErrorNumber:739 /Message:"***FAIL*** The CS Post Processing fail copiying XML for 2PP"
	/ErrorNumber:740 /Message:"***FAIL*** The CS Post Processing fail not possible to insert RunOnce Registry"
	/ErrorNumber:741 /Message:"***FAIL*** The CS Post Processing fail not possible Configure PBR"
	/ErrorNumber:742 /Message:"***FAIL*** The CS Post Processing fail not updated image detected"
	/ErrorNumber:743 /Message:"***FAIL*** The CS Post Processing fail applying actions for BlackLotus"

	/ErrorNumber:0 /Message:"***PASS*** The CS Audit Mode has been completed successfully"
.FLAGS
	cserror.flg - Stop process at beginning
	cspause.flg - Stop process when image is ready to be captured
	CSDrvNoVal.flg - Ignore Driver verification
	CSCustMode.flg - Prevent to use factory process
	CSDebug.flg - Prevent reboot unit and debug process
	CSAuditMode.flg - PPKG flag, 2phase of PP
	lanngflag.flg - Install all LP.cab found - Not used annymore
	CaptureFactory.flg - Capture an image when is ready, for customer use, it will be captured at C:\sources
	CapturePP.flg - Capture an image for PP, used for production. image will be captured at C:\sources
	CSPK.flg - Flag to install custom Product Key, align with Ajolote process.
#>
#Encoding Script
[cultureinfo]::CurrentCulture = 'en-US'

#Version
$ScriptVersion = "2.0.0"
$FSVersion = "$($ScriptVersion) - PPv2.2.2024"
$FSVersionFile = "C:\system.sav\DPSImageVersion.txt"

#Phats
$CurrentStageFolder = (Split-Path -Path $PSScriptRoot -Leaf)
$ParentStagePath = (Split-Path -Path $PSScriptRoot -Parent)
#$ScriptName = "$(($MyInvocation.MyCommand.Name).ToString().Substring(0,$MyInvocation.MyCommand.Name.ToString().Length-4)).log"

#System.sav paths
$flags = (Join-Path $Env:SystemDrive "\System.sav\flags")
$logs = (Join-Path $Env:SystemDrive "\system.sav\logs")
$ConfigPath = (Join-Path $ParentStagePath "Config")

#WDT paths
$WDT = (Join-Path $Env:SystemDrive "\System.sav\WDT")
$OSChanger = "$($WDT)\OSChanger64.exe"
$CustomOSChanger = "CustomOSchange.exe"
$LocalWDT = (Join-Path $ParentStagePath "WDT")
$Result = (Join-Path $WDT "Result.ini")

#USMT 
$USMT = (Join-Path $ParentStagePath "USMT_XXXXX")


#SplashScreen
$FSscreenFile = "FSLockScreen.exe"
$FSscreenStatusFile = (Join-Path $ParentStagePath "status.ini")
$FSscreen = (Join-Path $ParentStagePath $FSscreenFile)
$global:OnScreenProcess=$null
$global:OnScreenName=$FSscreenFile.Substring(0,$FSscreenFile.LastIndexOf("."))

#Flags
$errorflg = (Join-Path $flags "cserror.flg")
$pauseflg = (Join-Path $flags "cspause.flg")
$CSDrvNoVal = (Join-Path $flags "CSDrvNoVal.flg")
$CSCustMode = (Join-Path $flags "CSCustMode.flg")
$CSDebug = (Join-Path $flags "CSDebug.flg")
$CSPK = (Join-Path $flags "CSPK.flg")
$ICFactoryflag = (Join-Path $flags "CaptureFactory.flg")
$ICPostProcflag = (Join-Path $flags "CapturePP.flg")

##############################################################################
########################## LOCAL FUNCTIONS ###################################
##############################################################################

function Exit-FSCode($exitcode) {
    WriteLog -Message "`t <------------- FSPostProcessingMode exit code: [$($exitcode)]" -Verbose
    try {        
        if ($null -ne $global:OnScreenProcess) {
            WriteLog -Message "`t----Checking if splash screen is running..." -Verbose
            $CheckSplashProcess = Get-Process -Id $global:OnScreenProcess.Id -ErrorAction SilentlyContinue
            if ($null -ne $CheckSplashProcess) {
                WriteLog -Message "Closing OnScreen gui process, selected by ID: $($global:OnScreenProcess.Id)" -Verbose
                Stop-Process -Id $global:OnScreenProcess.Id -Force -ErrorAction SilentlyContinue
            }            
        } elseif ($null -ne (Get-Process -Name $global:OnScreenName -ErrorAction SilentlyContinue)) {
            WriteLog -Message "`t----Detected splash screen running..." -Verbose
            foreach ($proc in (Get-Process -Name $global:OnScreenName)) {
                WriteLog -Message "Closing OnScreen gui process, found by ID: $($proc.Id)" -Verbose
                Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            }
        }     
    }
    catch {
        Write-Warning "Failed Exit FS function"
    }
    Exit-PostProcessing $exitcode
    #$host.SetShouldExit($exitcode)
    #exit $exitcode
}

##############################################################################
##############################################################################

#Create basic Structure
if (-Not(Test-Path -Path (Join-Path $Env:SystemDrive "System.sav"))) { New-Item -Path $Env:SystemDrive -ItemType Directory -Name "System.sav" -Force | Out-Null }
if (-Not(Test-Path $logs)) { New-Item -Path (Join-Path $Env:SystemDrive "System.sav") -ItemType Directory -Name "logs" -Force | Out-Null }
if (-Not(Test-Path $flags)) { New-Item -Path (Join-Path $Env:SystemDrive "System.sav") -ItemType Directory -Name "flags" -Force | Out-Null }

#Capture console
$TrascriptFileName = (Join-Path $logs "Transcript_$($env:COMPUTERNAME).log")
try {
    if (Test-Path -Path $TrascriptFileName) {
        Start-Transcript -Path $TrascriptFileName -Append -Force | Out-Null
    }
    else {
        Start-Transcript -Path $TrascriptFileName -Force | Out-Null
    }	
}
catch {
    Stop-Transcript
    if (Test-Path -Path $TrascriptFileName) {
        Start-Transcript -Path $TrascriptFileName -Append -Force | Out-Null
    }
    else {
        Start-Transcript -Path $TrascriptFileName -Force | Out-Null
    }
}

"HP FS Post-Processing version $($FSVersion)" | Out-File -FilePath $FSVersionFile -Encoding default -Force -NoNewline

<##########################################################
    ADD SYSTEM SCRIPTS - FUNCTIONS
###########################################################>
[string[]]$ScriptFunction = @(
    "CSBuiltimage.Functions.ps1"
)
foreach ($script in $ScriptFunction) {
    try {
        if (-Not(Test-Path -Path "$($ParentStagePath)\CSModules\$($script)" -PathType Leaf)) {
            Write-Error "Missing Module file: $($script)"
        }
        else {
            Import-Module "$($ParentStagePath)\CSModules\$($script)"
            Write-Host "Module loaded: $($script)" -BackgroundColor Black -ForegroundColor Green   
        }             
    }
    catch {
        Write-Error "Not possible load System Script Modules"
    }
}
<##########################################################
                    LOAD MODULES
###########################################################>
[string[]] $CSModules = @(
    "WriteLog",
    "RunPower",
    "RunDism",
    "GetDrive",
    "CreateF11",
    "WDTFunctions",
    "GetDevice",
    "AssLetterAll",
    "MSUpdates",
    "WindowStyle",
    "HPControl",
    "AED_Support",
    "WinPESave"
)
foreach ($module in $CSModules) {
    if (!(Get-Module $module)) {
        $FindModule = Get-ChildItem -Path (Join-Path $ParentStagePath "CSModules") -Filter "$($module).psm1" -Recurse -file;
        if ($null -ne $FindModule) {
            try { Import-Module $FindModule[0].FullName; Write-Host "<---Loading Module $($module)" -ForegroundColor DarkGray; } catch { $MissingModule += "$($module)," }            
        }
        else {
            Write-Warning "Missing Module: $($module)";
        }
    }
    else {
        Write-Host "<---Loaded Module $($module)" -ForegroundColor DarkGray;
    }
}
foreach ($module in $CSModules) { if (-Not(Get-Module $module)) { Write-Host "Not possible found/load required module for $($MyInvocation.MyCommand.Name): $($module)" -ForegroundColor Yellow -BackgroundColor Red; } }
if ($MissingModule) { Write-Warning "ABORT PROCESS: Missing Modules: $($MissingModule)"; Exit-FSCode(104); }

try {
    #################################################################
    ####      Initialize Logs
    ##################################################################
    WriteLog -Message "----------------- HP FS Post-Processing Mode Setup ------------------" -Path $logs -Name "_FSPostProcessingMode.log" -Verbose
    WriteLog -Message "##############################################################################################################" -Verbose
    WriteLog -Message "#########`t`tPost-Processing Stage: $($CurrentStageFolder)" -Verbose
    WriteLog -Message "##############################################################################################################" -Verbose
    #Hide current script window
    Get-Process -Id $PID -ErrorAction SilentlyContinue | Set-WindowStyle -Style HIDE;
    #################################################################
    ####      KeepAlive Script
    ##################################################################
    "`$WShell = New-Object -Com Wscript.Shell" | Out-File -FilePath "$($PSScriptRoot)\KeepAlive.ps1" -Append -Encoding default
    "while (1) {`$WShell.SendKeys(""{SCROLLLOCK}""); Get-Process | Where-Object {`$_.Name -like ""*teams*""} | Stop-Process -Force; Get-Process | Where-Object { $_.ProcessName -like ""*sysprep*""} | Stop-Process -Force; Start-Sleep -Seconds 60}" | Out-File -FilePath "$($PSScriptRoot)\KeepAlive.ps1" -Append -Encoding default
    $keepalive = Start-Process -FilePath "PowerShell.exe" -ArgumentList "-ExecutionPolicy bypass -File ""$($PSScriptRoot)\KeepAlive.ps1"" -NoProfile -WindowStyle Maximized"  -WindowStyle Hidden -PassThru
    WriteLog -Message "Keep alive script is running $($keepalive.Id)" -Verbose

    #################################################################
    ####      Initialize SplashScreen
    ##################################################################
    "[info]HP FS POST-PROCESSING MODE" | Out-File -FilePath $FSscreenStatusFile -Encoding ascii -NoNewline -Force; 
    $global:OnScreenProcess=Start-Process -FilePath $FSscreen -ArgumentList "/full" -PassThru

    #################################################################
    ####      OSChanger Preparation
    ##################################################################
    switch ($env:PROCESSOR_ARCHITECTURE) {
        "AMD64" { $OSChanger = (Join-Path $WDT "OSChanger64.exe"); break; }
        "x86" { $OSChanger = (Join-Path $WDT "OSChanger32.exe"); break; }
        "IA64" { $OSChanger = (Join-Path $WDT "OSChangerARM.exe"); break; }
        Default { $OSChanger = (Join-Path $WDT "OSChanger64.exe"); break; }
    }
    WriteLog -Message "---> OSChanger required: $($OSChanger)" -Verbose

    #-Create WDT folde if not exist
    if (-Not(Test-Path $WDT)) { New-Item -Path $WDT -ItemType Directory -Force }

    if (-Not(Test-Path -Path $OSChanger)) {
        #----- Check if 1st partition has WDT folder
        $DriveID = (Get-Partition -DiskNumber (Get-Partition -DriveLetter C).DiskNumber -PartitionNumber 1 | Get-Volume).UniqueId
        if ($null -ne $DriveID) {
            if (Test-Path "$($DriveID)system.sav\WDT") {
                WriteLog -Message "Foud WDT folder on 1st partition" -Verbose
                $CopyEFI = Copy-Item "$($DriveID)system.sav\WDT\*" -Destination "$($WDT)\" -Recurse  -Force -PassThr
                if (($null -eq $CopyEFI) -OR ($CopyEFI.Count -lt 1)) { WriteLog -Message "It seems like was not possible copy handshare files from 1st prtition" -MessageType Warning -Verbose } else { $CopyEFI | Out-File -FilePath "$($logs)\CopyWDTfromEFI.log" -Encoding default -Force }
            }
        }
        #---- If WDT is not present, use the one in component
        if (-Not(Test-Path -Path $OSChanger)) { 
            $null = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /sehiy $($LocalWDT)\* $($WDT)\" -WorkDir $PSScriptRoot -OutFile "$($logs)\CopyWDTfromComponent.log"; 
        }
    }

    if (-Not(Test-Path -Path $Result)) { 
        "[Results]" | Out-File -FilePath $Result -Encoding default -Force;
        "Version=1.00" | Out-File -FilePath $Result -Encoding default -Force -Append;	
    }

    if (-Not(Test-Path $OSChanger) -OR !(Test-Path $Result)) { 
        WriteLog -Message "Something fail preparing WDT folder" -MessageType Error -Verbose; 
        "error in HandShake files, review content on $($WDT)" | Out-File -FilePath $errorflg -Encoding default -Force; 
        "[error]HP FS Post-Processing Mode for failed. Missing OSChanger." | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline
        Exit-FSCode(401);
    }
    ##----Flag to prevent use factory process
    if (Test-Path -Path $CSCustMode -PathType Leaf) {
        WriteLog -Message "CSCustMode.flg was detected, prevent process return to factory process"
        $OSChanger = (Join-Path $WDT $CustomOSChanger)
        WriteLog -Message "--->New OSChanger required: $($OSChanger)" -Verbose
        if (-Not(Test-Path -Path $OSChanger -PathType Leaf)) {
            Copy-Item -Path (Join-Path $LocalWDT $CustomOSChanger) -Destination "$($WDT)\" -Force
        }
        [string[]]$MyExclude = @($CustomOSChanger, "result.ini")
        foreach ($item in (Get-ChildItem -Path $WDT -Recurse -File -Exclude $MyExclude)) {
            WriteLog -Message "Remove unecesary file: $($item.Name)" -Verbose;
            Remove-Item -Path $item.FullName -Force
        }
    }
    #################################################################
    # Initialize OSChanger - FROM THIS POINT ERRORS CAN RETURN TO WDT
    ##################################################################
    WriteLog -Message "Write Error meessage on result.ini in case of unexpected return to WDT" -Verbose
    $null = Invoke-RunPower -File $OSChanger -Params "/ErrorNumber:700 /Message:""***FAIL*** The CS Post Processing fail unexpected on 1PP phase""" -WorkDir $WDT -OutFile "$($logs)\OSChangerError.log" -Verbose

    #--Close sysprep
    while ((Get-Process | Where-Object { $_.ProcessName -like "*sysprep*" }).Count -gt 0) {
        $sysp = Get-Process | Where-Object { $_.ProcessName -like "*sysprep*" }
        if ($sysp) { WriteLog -Message "Sysprep tool is open, closing for now"; Stop-Process -Id $sysp.Id; Start-Sleep -Seconds 3; }
    }

    <#################################################################
    ###     RETRIEVE SYSTEM INFORMATION
    ##################################################################>
    WriteLog -Message "-----------------------------------------Record Main Information----------------------------------------------------" -Verbose 
    $OS = @{}
    $OS.ProductName = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').ProductName
    $OS.Architecture = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
    $OS.Version = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').ReleaseId
    $OS.Build = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuildNumber
    switch ($OS.Build) {
        "19041" { $OS.Name = $OS.ProductName; $USMT = (Join-Path $ParentStagePath "USMT_19041"); break; }
        "19042" { $OS.Name = $OS.ProductName; $USMT = (Join-Path $ParentStagePath "USMT_19041"); break; }
        "19043" { $OS.Name = $OS.ProductName; $USMT = (Join-Path $ParentStagePath "USMT_19041"); break; }
        "19044" { $OS.Name = $OS.ProductName; $USMT = (Join-Path $ParentStagePath "USMT_19041"); break; }
        "19045" { $OS.Name = $OS.ProductName; $USMT = (Join-Path $ParentStagePath "USMT_19041"); break; }
        "22000" { $OS.Name = $OS.ProductName.Replace(" 10 ", " 11 "); $USMT = (Join-Path $ParentStagePath "USMT_22000"); break; }
        "22621" { $OS.Name = $OS.ProductName.Replace(" 10 ", " 11 "); $USMT = (Join-Path $ParentStagePath "USMT_22621"); break; }
        "22631" { $OS.Name = $OS.ProductName.Replace(" 10 ", " 11 "); $USMT = (Join-Path $ParentStagePath "USMT_22621"); break; }
        Default { if ([int]$OS.Build -ge 22000) { $OS.Name = $OS.ProductName.Replace(" 10 ", " 11 ") } else { $OS.Name = $OS.ProductName }; $USMT = (Join-Path $ParentStagePath "USMT_$($OS.Build)"); break; }
    }
    $OS.Revision = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').UBR
    $OS.DisplayVersion = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DisplayVersion
    $OS.Branch = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').BuildBranch
    $SKU = (Get-CimInstance -Namespace ROOT\HP\InstrumentedBIOS -ClassName HP_BIOSSetting | Where-Object { $_.Name -eq "SKU Number" }).Value
    $BuildID = (Get-CimInstance -Namespace ROOT\HP\InstrumentedBIOS -ClassName HP_BIOSSetting | Where-Object { $_.Name -eq "Build ID" }).Value
    $FeatureByte = (Get-CimInstance -Namespace ROOT\HP\InstrumentedBIOS -ClassName HP_BIOSSetting | Where-Object { $_.Name -eq "Feature Byte" }).Value

    if (!([string]::IsNullOrWhiteSpace($BuildID))) {
        try {
            $LOC = $BuildID.ToString().Split("#")[2].Substring(1, 3).ToUpper()
        }
        catch {
            $LOC = "ABA"
        }
    }

    if (!([string]::IsNullOrWhiteSpace($SKU))) {
        try {
            $AV = $SKU.Substring(0, $SKU.IndexOf("#"))
        }
        catch {
            $AV = "12345AV"
        }
    }
    else {
        WriteLog -Message "Missing SKU value on bios, it will be used default #ABA" -MessageType Error -Verbose
        $AV = "12345AV"
    } 

    WriteLog -Message " Checking PowerShell Version: $($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor).$($PSVersionTable.PSVersion.Build).$($PSVersionTable.PSVersion.Revision)" -Verbose
    WriteLog -Message "      Executing script from : $((Get-Item -Path '.\' -Verbose).FullName)" -Verbose
    WriteLog -Message "             Script Version : $($ScriptVersion)" -Verbose
    WriteLog -Message "         Windows ProductName: $($OS.ProductName)" -Verbose
    WriteLog -Message "                Windows Name: $($OS.Name)" -Verbose
    WriteLog -Message "             Windows Version: $($OS.Version)" -Verbose
    WriteLog -Message "     Windows Display Version: $($OS.DisplayVersion)" -Verbose
    WriteLog -Message "       Windows Build Version: $($OS.Build)" -Verbose
    WriteLog -Message "      Windows Build Revision: $($OS.Revision)" -Verbose
    WriteLog -Message "              Windows Branch: $($OS.Branch)" -Verbose
    WriteLog -Message "           Language Detected: $((GET-WinSystemLocale).Name)" -Verbose
    WriteLog -Message "           Current User Name: $($env:USERNAME)" -Verbose
    WriteLog -Message "                  Current OS: $((Get-WmiObject Win32_OperatingSystem).Name)" -Verbose
    WriteLog -Message "            Current OS Drive: $($env:HOMEDRIVE)" -Verbose
    WriteLog -Message "     Current OS Architecture: $($env:PROCESSOR_ARCHITECTURE)" -Verbose
    WriteLog -Message "     Current OS Architecture: $((Get-WmiObject Win32_OperatingSystem).OSArchitecture)" -Verbose
    WriteLog -Message "             Current PC Name: $((Get-WmiObject Win32_OperatingSystem).CSName)" -Verbose
    WriteLog -Message "              Computer Model: $((Get-WmiObject Win32_Computersystem).Model) [$((Get-WmiObject Win32_BaseBoard).Product)]" -Verbose
    WriteLog -Message "               Serial Number: $((Get-WmiObject Win32_Bios).SerialNumber)" -Verbose	
    WriteLog -Message "                  SKU Number: $($SKU)" -Verbose
    WriteLog -Message "                     Buil ID: $($BuildID)" -Verbose
    WriteLog -Message "                Feature Byte: $($FeatureByte)" -Verbose
    WriteLog -Message "                      SKU AV: $($AV)" -Verbose				
    WriteLog -Message "            SKU Localization: $($LOC)" -Verbose		

    if (Test-Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State) { 
        $regkey = Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State -Name ImageState;
        WriteLog -Message "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State ImageState=[$($regkey.ImageState)]" -Verbose
    }
    if (Test-Path HKLM:\SYSTEM\Setup) { 
        $regkey = Get-ItemProperty -Path HKLM:\SYSTEM\Setup -Name SystemSetupInProgress;
        WriteLog -Message "HKLM:\SYSTEM\Setup SystemSetupInProgress=[$($regkey.SystemSetupInProgress)]" -Verbose
    }
    WriteLog -Message "-----------------------------------------------Process start----------------------------------------------------------" -Verbose

    if ($null -ne $OS.DisplayVersion -AND $OS.DisplayVersion.Length -gt 2) {
        "[info]HP CS Post-Processing for $($OS.Name) $($OS.Architecture) Ver.$($OS.DisplayVersion)" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline
    }
    else {
        "[info]HP CS Post-Processing for $($OS.Name) $($OS.Architecture) Ver.$($OS.Version)" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline
    }

    ###############################################################################################################
    #--------------------------------------Error flag found and Stop
    #################################################################################################################
    if (Test-Path $errorflg) {
        WriteLog -Message "A cserror.flg was found: $(Get-Content $errorflg)" -MessageType Warning -Verbose
        WriteLog -Message "While this flag exist, this process can't continue" -MessageType Warning -Verbose
        "[warning]Stop process due Error Flag: $(Get-Content $errorflg)" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
        "This prompt will be closed in 30sec, use terminal to debug, once is closed a reboot will be perfomed to return Windows Error" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
        Start-Sleep -Seconds 30        
        if ($null -ne $global:OnScreenProcess) {
            WriteLog -Message "Checking if gui is running using saved Id..." -Verbose
            $CheckSplashProcess = Get-Process -Id $global:OnScreenProcess.Id -ErrorAction SilentlyContinue
            if ($null -ne $CheckSplashProcess) {
                WriteLog -Message "Closing Splash window for debug using saved Id" -Verbose
                Stop-Process -Id $global:OnScreenProcess.Id -Force -ErrorAction SilentlyContinue
            }            
        } elseif ($null -ne (Get-Process -Name $global:OnScreenName -ErrorAction SilentlyContinue)) {
            WriteLog -Message "Checking if gui is running using Name..." -Verbose
            foreach ($proc in (Get-Process -Name $global:OnScreenName)) {
                WriteLog -Message "Closing OnScreen gui process, found: $($proc.Id)" -Verbose
                Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            }
        } 
        Start-Process -FilePath "Powershell.exe" -WorkingDirectory (Join-Path $Env:SystemDrive "\Windows\System32") -WindowStyle Normal -Wait
        Exit-FSCode(25031981)
        #below code never execute
        while (Test-Path $errorflg) { Start-Sleep -Seconds 5 }
        #Stop and restart hta in case that was closed by user
        if ($null -ne $OS.DisplayVersion -AND $OS.DisplayVersion.Length -gt 2) {
            "[info]HP CS Post-Processing Mode for $($OS.Name) $($OS.Architecture) Ver.$($OS.DisplayVersion)" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline
        }
        else {
            "[info]HP CS Post-Processing Mode for $($OS.Name) $($OS.Architecture) Ver.$($OS.Version)" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline
        }
    }

}
catch {
    $ErrorMessage = $_.Exception.Message                
    [string]$ExceptionText = ($_ | Out-String).Trim()
    Write-Host "[ERROR] exception detected on $($CurrentStageFolder), script $($MyInvocation.MyCommand.Name): $($ErrorMessage)"
    Write-Host "[ERROR TEXT]: $($ExceptionText)"
    $null = Invoke-RunPower -File $OSChanger -Params "/WDT /ABO /ABONP /ErrorNumber:999 /Message:""***FAIL***The CS Post Processing fail unamanaged exception""" -WorkDir $WDT -OutFile "$($logs)\OSChangerError.log" -Verbose
    Exit-FSCode(999)
}

<######################################################################################################################
#------------------------------------> SPECIFIC STEP                 
#######################################################################################################################>

try {
    
}
catch {
    $ErrorMessage = $_.Exception.Message                
    [string]$ExceptionText = ($_ | Out-String).Trim()
    Write-Host "[ERROR] exception detected on $($CurrentStageFolder), script $($MyInvocation.MyCommand.Name): $($ErrorMessage)"
    Write-Host "[ERROR TEXT]: $($ExceptionText)"
    $null = Invoke-RunPower -File $OSChanger -Params "/WDT /ABO /ABONP /ErrorNumber:999 /Message:""***FAIL***The CS Post Processing fail unamanaged exception""" -WorkDir $WDT -OutFile "$($logs)\OSChangerError.log" -Verbose
    Exit-FSCode(999)
}