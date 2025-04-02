<#
.SYNOPSIS
    HP FS Audit Mode Configuration
.DESCRIPTION
	Configure FS Images
	This version only support Windows 10 minimum version 1909 and Windwos 11
.NOTES
	Script version:		2.0.1 | Update $ScriptVersion variable
	   Script Date: 	Sep.26.2024
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
$ScriptVersion = "2.0.2"
$FSVersion = "$($ScriptVersion) - PPv2.$((Get-Date).ToString("yyyy"))"
$FSVersionFile = (Join-Path $Env:SystemDrive "\system.sav\DPSImageVersion.txt")

if ((-Not(Test-Path $FSVersionFile)) -OR ((Get-Item -Path $FSVersionFile).Length -lt 1)) {
    "HP FS Post-Processing version $($FSVersion)" | Out-File -FilePath $FSVersionFile -Encoding default -Force
}
"`tScript: $($ScriptName) V.$($ScriptVersion)" | Out-File -FilePath $FSVersionFile -Encoding default -Force -Append


##############################################################################
############################# LOAD GLOBAL SCRIPT ####################################
##############################################################################
$GetPS1=Get-ChildItem -Path (Join-Path (Split-Path $PSScriptRoot -Parent) "FSScripts") -Filter "*.ps1" -File | Sort-Object -Property Name
Push-Location $PSScriptRoot 
$counterps1=0
foreach ($script in $GetPS1) {
    try {
        $nameofpiceloaded=$script.Name.substring($script.Name.IndexOf("_")+1,$script.Name.Length-($script.Name.IndexOf("_")+5))
        $counterps1++
        Write-Host "<---------------------------------------- Loading: $($nameofpiceloaded) [$([math]::round($counterps1*100/($GetPS1 | Measure-Object).Count))%] -------------------------------------------------> "
        . $script.FullName
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        [string]$ExceptionText = ($_ | Out-String).Trim()
        Write-Error "`t[FAIL] Not possible load System Script Modules: $($ErrorMessage)"
        Write-Host $ExceptionText
        Exit-FSCode(100)
    }
}
Write-Host "<------------------------------------------------ [Done] -------------------------------------------------------------> "


<######################################################################################################################
#------------------------------------> SPECIFIC STEP                 
#######################################################################################################################>


try {
            <#############################################################################################################
            #                           EXTRACT BCU INFORMATION
            ##############################################################################################################>
        WriteLog -Message "--->Extracting BCU information" -Verbose
        "[info]Extracting BCU information" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
        Get-HPBIOSSettingsList -Format JSON | Out-File -FilePath (Join-Path $logs "$(((Get-WmiObject Win32_Computersystem).Model)).json") -Encoding utf8 -Force


        <###############################################################################################################
        #                                 SW FOLDER DETECTION
        #################################################################################################################>
    if (Test-Path -Path (Join-Path $Env:SystemDrive "SW")) {
        WriteLog -Message "--->Found SW folder at OS root, moving content to correct location" -Verbose
        "[info]Found SW folder at OS root, moving content to correct location" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
        $SW = Get-ChildItem -Path (Join-Path $Env:SystemDrive "SW") -Attributes Directory
        foreach ($f in $SW) {
            if (($f.Name.ToString().ToUpper() -eq "M17383.00A") -OR ($f.Name.ToString().ToUpper() -eq "GBUCSAUDITMODE.00A")) {
                WriteLog -Message "Found GBU Tweak: $($f.Name), Ignoring for this process" -Verbose
            }
            else {
                WriteLog -Message "Moving $($f.Name) to $($Env:SystemDrive)\" -Verbose
                $null = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /sehiy $($f.FullName)\* $($Env:SystemDrive)\" -WorkDir $PSScriptRoot -OutFile "$($logs)\MoveSWComponent.log";
                WriteLog -Message "Remove Source $($f.FullName)" -Verbose
                $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($f.FullName)" -WorkDir $PSScriptRoot -OutFile "$($logs)\RemoveSWComponent.log";
            }		
        }
        WriteLog -Message "Remove Top $($Env:SystemDrive)\SW" -Verbose
        $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($Env:SystemDrive)\SW" -WorkDir $PSScriptRoot -OutFile "$($logs)\RemoveSW.log";
    }
            <#############################################################################################################
            #                           HP DOCUMENTATION - SETUP
            ##############################################################################################################>
    $SW_Title="HP Documentation"
    $DeviceProduct=(Get-WmiObject Win32_BaseBoard).Product
    #Check if application is installed
    WriteLog -Message "----->Checking $($SW_Title) status" -Verbose
    "[loading]Checking $($SW_Title) current status..." | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
    
    if (Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\HP_Documentation") {
        WriteLog -Message "Detected $($SW_Title) installed on this system, checking details" -Verbose
        $GetApp=@{}
            $GetApp.Name=(Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\HP_Documentation" -Name "DisplayName")."DisplayName"
            $GetApp.Version=(Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\HP_Documentation" -Name "DisplayVersion")."DisplayVersion"
    }
    if ($null -eq $GetApp) { 
        WriteLog -Message "It was not possible to detect $($SW_Title), check if installer was included on this deployment for System product=$($DeviceProduct)" -Verbose
        $foundSetup=$false
        $arrayCVA = [system.collections.arraylist]@()
        if (Test-Path (Join-Path $Env:SystemDrive "HPDrivers")) {
            $SourcePath=(Join-Path $Env:SystemDrive "HPDrivers")
            foreach ($cva in (Get-ChildItem -Path $SourcePath -Recurse -Filter "*.cva" -File)) {
                if ($null -ne (Get-Variable -Name objCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name objCVA -Force -ErrorAction SilentlyContinue }
                $objCVA=Get-CVAObject -PathFile $cva.FullName
                if ($objCVA.Title -like "*$($SW_Title)*") {                    
                    WriteLog -Message "Found: $($objCVA.Title), version $($objCVA.Version), checking sysid" -Verbose
                    foreach ($id in $objCVA.SysIds) {
                        WriteLog -Message "Required: [$($DeviceProduct)] <::> Detected: [$($id)]" -Verbose
                        if ($id -eq $DeviceProduct) {
                            WriteLog -Message "Found: $($objCVA.Title), Version $($objCVA.Version), Part Number $($objCVA.PN), checking if is valid" -Verbose
                            if ($objCVA.Valid) {
                                WriteLog -Message "This setup can be used: $($objCVA.Path)\$($objCVA.Name)" -Verbose                        
                                [void]$arrayCVA.Add($objCVA);
                                $foundSetup=$true
                                break;
                            }
                        }
                    }                    
                }
            }
        } 
        if ((Test-Path (Join-Path $Env:SystemDrive "\HP\Drivers")) -AND (-Not($foundSetup))) {
            $SourcePath=(Join-Path $Env:SystemDrive "\HP\Drivers")
            foreach ($cva in (Get-ChildItem -Path $SourcePath -Recurse -Filter "*.cva" -File)) {
                if ($null -ne (Get-Variable -Name objCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name objCVA -Force -ErrorAction SilentlyContinue }
                $objCVA=Get-CVAObject -PathFile $cva.FullName
                if ($objCVA.Title -like "*$($SW_Title)*") {                    
                    WriteLog -Message "Found: $($objCVA.Title), version $($objCVA.Version), checking sysid" -Verbose
                    foreach ($id in $objCVA.SysIds) {
                        WriteLog -Message "Required: [$($DeviceProduct)] <::> Detected: [$($id)]" -Verbose
                        if ($id -eq $DeviceProduct) {
                            WriteLog -Message "Found: $($objCVA.Title), Version $($objCVA.Version), Part Number $($objCVA.PN), checking if is valid" -Verbose
                            if ($objCVA.Valid) {
                                WriteLog -Message "This setup can be used: $($objCVA.Path)\$($objCVA.Name)" -Verbose                        
                                [void]$arrayCVA.Add($objCVA);
                                $foundSetup=$true
                                break;
                            }
                        }
                    }                    
                }
            }
        } 
        if ((Test-Path (Join-Path $Env:SystemDrive "SWSETUP")) -AND (-Not($foundSetup))) {
            $SourcePath=(Join-Path $Env:SystemDrive "SWSETUP")
            foreach ($cva in (Get-ChildItem -Path $SourcePath -Recurse -Filter "*.cva" -File)) {
                if ($null -ne (Get-Variable -Name objCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name objCVA -Force -ErrorAction SilentlyContinue }
                $objCVA=Get-CVAObject -PathFile $cva.FullName
                if ($objCVA.Title -like "*$($SW_Title)*") {                    
                    WriteLog -Message "Found: $($objCVA.Title), version $($objCVA.Version), checking sysid" -Verbose
                    foreach ($id in $objCVA.SysIds) {
                        WriteLog -Message "Required ThisPC: [$($DeviceProduct)] <::> Detected Support: [$($id)]" -Verbose
                        if ($id -eq $DeviceProduct) {
                            WriteLog -Message "Found: $($objCVA.Title), Version $($objCVA.Version), Part Number $($objCVA.PN), checking if is valid" -Verbose
                            if ($objCVA.Valid) {
                                WriteLog -Message "This setup can be used: $($objCVA.Path)\$($objCVA.Name)" -Verbose                        
                                [void]$arrayCVA.Add($objCVA);
                                $foundSetup=$true
                                break;
                            }
                        }
                    }                    
                }
            }
        } 
        if (!(Test-Path (Join-Path $Env:SystemDrive "HPDrivers")) -AND !(Test-Path (Join-Path $Env:SystemDrive "\HP\Drivers")) -AND !(Test-Path (Join-Path $Env:SystemDrive "SWSETUP"))) {
            WriteLog -Message "It was not possible to detect source folder" -Verbose
        }
        if ($foundSetup) {
            "[loading]Trying to install $($SW_Title)..." | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
            if (($arrayCVA | Measure-Object).Count -gt 1) { WriteLog -Message "There are more than 1 coincidence for $($SW_Title), it will be use first" -MessageType Warning -Verbose;}
            WriteLog -Message "Installing $($SW_Title): *cmd.exe /c ""$($arrayCVA[0].SilentFile)"" $($arrayCVA[0].SilentParameters)" -Verbose
            $RunSetup = Invoke-RunPower -file "cmd.exe" -Params "/c ""$($arrayCVA[0].SilentFile)"" $($arrayCVA[0].SilentParameters)" -WorkDir $arrayCVA[0].Path -OutFile (Join-Path $logs "Setup_$($SW_Title.Replace(" ","_")).log") -Verbose
            $NotLocatedCode=$true
            foreach ($err in $arrayCVA[0].ReturnCode) {
                WriteLog -Message "Comparing CVA Return code line: $($err)" -Verbose
                if ($err.Contains("=") -AND $err.Contains(":")) {
                    $objReturn = @{}
                    if ($null -ne $err.Split("=")[0]) { $objReturn.Codes = $err.Split("=")[0] } else { $objReturn.Codes = "" }
                    if ($null -ne $err.Split("=")[1]) { $objReturn.Mess = $err.Split("=")[1] } else { $objReturn.Mess = "" }
                    if ($null -ne $objReturn.Codes.Split(":")[0]) { $objReturn.code = $objReturn.Codes.Split(":")[0] } else { $objReturn.code = "0" }
                    if ($null -ne $objReturn.Codes.Split(":")[1]) { $objReturn.status = $objReturn.Codes.Split(":")[1] } else { $objReturn.status = "" }
                    if ($null -ne $objReturn.Codes.Split(":")[2]) { $objReturn.reboot = $objReturn.Codes.Split(":")[2] } else { $objReturn.reboot = "" }                        
                    if ([int]$objReturn.code -eq $RunSetup) {
                        WriteLog -Message "Return Code $($RunSetup) was located on CVA, Status: $($objReturn.status), Reboot: $($objReturn.reboot) and message $($objReturn.Mess)" -Verbose
                        $NotLocatedCode=$false
                        if ($objReturn.status.ToUpper().Trim() -eq "SUCCESS") {
                            WriteLog -Message "$($arrayCVA[0].Title) was successfully installed, validation required..." -Verbose
                            if ($objReturn.reboot -eq "REBOOT") {
                                WriteLog -Message "This result require reboot unit before to continue." -MessageType Warning -Verbose
                                $Reboot=$true
                            }
                            "[info]Successfully installed $($SW_Title), validating..." | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline                      
                        } else { 
                            WriteLog -Message "Not expected code $($RunSetup), try to validate $($arrayCVA[0].Title)" -MessageType Warning -Verbose 
                        }
                        #Vaidate installed software
                        if (Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\HP_Documentation") {
                            WriteLog -Message "Detected $($SW_Title) installed on this system, checking details" -Verbose
                            $GetApp=@{}
                                $GetApp.Name=(Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\HP_Documentation" -Name "DisplayName")."DisplayName"
                                $GetApp.Version=(Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\HP_Documentation" -Name "DisplayVersion")."DisplayVersion"
                        }
                        if ($null -eq $GetApp) {
                            WriteLog -Message "$($SW_Title) not found on Software and Features" -MessageType Error -Verbose
                            "error installing $($SW_Title), after setup cannot validate it" | Out-File -FilePath $errorflg -Encoding default -Force;
                            "[error]error installing $($SW_Title), after setup cannot validate it" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline
                            $null = Invoke-RunPower -File $OSChanger -Params "/WDT /ABO /ABONP /ErrorNumber:714 /Message:""***FAIL*** The CS Post Processing fail $($SW_Title) setup, cannot possible to validate as installed""" -WorkDir $WDT -OutFile "$($logs)\OSChangerError.log" -Verbose
                            Exit-FSCode(714);
                        }
                        WriteLog -Message "It is detected $($GetApp.Name) with version $($GetApp.Version), on this system" -Verbose  
                        "[info]It is detected $($GetApp.Name) with version $($GetApp.Version), on this system" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline  
                        break;
                    }
                }
            }
            if ($NotLocatedCode) {
                WriteLog -Message "It was not possible detect code $($RunSetup) on CVA" -MessageType Error -Verbose
                "error installing $($SW_Title), it was not possible detect code $($RunSetup) on CVA" | Out-File -FilePath $errorflg -Encoding default -Force;
                "[error]error installing $($SW_Title), it was not possible detect code $($RunSetup) on CVA" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline
                $null = Invoke-RunPower -File $OSChanger -Params "/WDT /ABO /ABONP /ErrorNumber:714 /Message:""***FAIL*** The CS Post Processing fail $($SW_Title) setup, it was not possible detect code $($RunSetup) on CVA""" -WorkDir $WDT -OutFile "$($logs)\OSChangerError.log" -Verbose
                Exit-FSCode(714);
            }
            #remove main directory in case that multiplatform was included
            if (Test-Path -Path (Join-Path $Env:SystemDrive "\SWSETUP\APP\Documentation")) {
                WriteLog -Message "Removing main directory for $($SW_Title) app" -Verbose
                $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($Env:SystemDrive)\SWSETUP\APP\Documentation" -OutFile "$($logs)\RemoveHPDocPath.log";
            }
        } else {
            WriteLog -Message "It was not possible to locate $($SW_Title) setup, process continue" -Verbose
        }
    } else {
        WriteLog -Message "It is detected $($GetApp.Name) with version $($GetApp.Version), on this system" -Verbose
        "[info]It is detected $($GetApp.Name) with version $($GetApp.Version), on this system" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
    }


    $Reboot=$false
            <#############################################################################################################
            #                           INTELLIGENT DRIVER - HPIA
            ##############################################################################################################>
    #HPIA
    $HPIA_SourceFolder=(Join-Path $ParentStagePath "HPIA")
    $HPIA_Folder=(Join-Path $Env:SystemDrive "\HP\HPIA")
    $HPIA_FileName="HPImageAssistant.exe"
    $HPIA_OfflineRepo=(Join-Path $Env:SystemDrive "\HP\Drivers")
    $HPIA_DownloadPath=(Join-Path $Env:SystemDrive "\HP\SWSetup")
    $HPIA_ExtractPath=(Join-Path $Env:SystemDrive "\SWSetup")
    $HPIA_ReportPath=(Join-Path $logs "HPIAReport")
    $HPIA_LogsPath=(Join-Path (Join-Path $logs "HPIAReport") "Logs")
    if ((-Not(Test-Path (Join-Path $Env:SystemDrive "HPDrivers"))) -AND (Test-Path $HPIA_OfflineRepo)) {
        WriteLog -Message "------->Installing Drivers" -Verbose
        "[loading]Checking current status for Intelligent Driver Installation" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
        if ((-Not(Test-Path -Path (Join-Path $HPIA_SourceFolder $HPIA_FileName))) -AND (-Not(Test-Path -Path (Join-Path $HPIA_Folder $HPIA_FileName)))) {
            $null = Invoke-RunPower -File $OSChanger -Params "/WDT /ABO /ABONP /ErrorNumber:714 /Message:""***FAIL*** The CS Post Processing fail HP Image Assistant tool missing""" -WorkDir $WDT -OutFile "$($logs)\OSChangerError.log" -Verbose
            Exit-FSCode(714);
        }
        if (-Not(Test-Path -Path $HPIA_Folder -PathType Container)) { New-Item -Path $HPIA_Folder -ItemType Directory -Force }
        if (-Not(Test-Path -Path $HPIA_DownloadPath -PathType Container)) { New-Item -Path $HPIA_DownloadPath -ItemType Directory -Force }
        if (-Not(Test-Path -Path $HPIA_ExtractPath -PathType Container)) { New-Item -Path $HPIA_ExtractPath -ItemType Directory -Force }
        if (-Not(Test-Path -Path $HPIA_ReportPath -PathType Container)) { New-Item -Path $HPIA_ReportPath -ItemType Directory -Force }
        if (-Not(Test-Path -Path $HPIA_LogsPath -PathType Container)) { New-Item -Path $HPIA_LogsPath -ItemType Directory -Force }
        if ((Get-ChildItem -Path "$($Env:SystemDrive)\" -Filter "HP" -Directory -Force).Attributes -band [System.IO.FileAttributes]::Hidden) {
            WriteLog -Message "folder $((Join-Path $Env:SystemDrive "\HP")) Hidden attributes" -Verbose
        } else {
            WriteLog -Message "Set  $((Join-Path $Env:SystemDrive "\HP")) attributes as Hidden"
            $null = Invoke-RunPower -File "cmd.exe" -Params "/c attrib $((Join-Path $Env:SystemDrive "\HP")) +H" -OutFile "$($logs)\hp_attrib.log"; 
        }

        #Copy HPIA from PPSolution to local unit
        if (-Not(Test-Path -Path (Join-Path $HPIA_Folder $HPIA_FileName))) {
            WriteLog -Message "Copying HPIA to local device" -Verbose
            $null = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /sehiyk $($HPIA_SourceFolder)\* $($HPIA_Folder)\" -WorkDir $ParentStagePath -OutFile "$($logs)\CopyHPIA.log" -Verbose
        }
        WriteLog -Message "Checking Internet access" -Verbose
        "[waiting]Checking Internet access" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
        $InternetAccess=Get-InternetAccess
        "[loading]Intelligent Driver Installation" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force        
        if ($InternetAccess) {
            WriteLog -Message "Internet access detected, try to install from HP.com" -Verbose
            "`r`n(Online) Analyze and install from Internet" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
            $parameters="/Operation:Analyze /Category:All /selection:All /action:Install /silent /SoftPaqdownloadfolder:$($HPIA_DownloadPath) /SoftPaqExtractFolder:$($HPIA_ExtractPath) /Reportfilepath:$((Join-Path $HPIA_LogsPath 'FS_HPIA_report.log')) /Noninteractive /LogFolder:$($HPIA_LogsPath)"
        } else {
            WriteLog -Message "Not possible detect Internet access, try to install from local repository" -Verbose
            "(`r`nOffline) Analyze and install from local repository" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
            #build reference file name
            #<sysid>_<bits>_<Win>.0.<build>.xml
            switch ($env:PROCESSOR_ARCHITECTURE) {
                "AMD64" { $Bitness="64"; break; }
                "x86" { $Bitness="32"; break; }
                "IA64" { $Bitness="arm"; break; }
                Default { $Bitness="64"; break; }
            }
            $Referencefile="$((Get-WmiObject Win32_BaseBoard).Product)_$($Bitness)_$(($OS.Name -replace '[a-zA-Z]','').Trim()).0.$($OS.DisplayVersion).xml"
            WriteLog -Message "Searching reference file name: $($Referencefile)" -Verbose
            $GetReference = Get-ChildItem -Path $HPIA_OfflineRepo -Recurse -Filter $Referencefile
            if ($null -ne $GetReference) {
                foreach ($ref in $GetReference) {
                    WriteLog -Message "`tFound reference file: $($ref.FullName)" -Verbose
                    "`r`nReference file: $($ref.Name)" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
                }
            }            
            $parameters="/Operation:Analyze /Category:All /action:Install /silent /selection:All /Offlinemode:""$($HPIA_OfflineRepo)"" /SoftpaqDownloadFolder:""$($HPIA_DownloadPath)"" /SoftPaqExtractFolder:$($HPIA_ExtractPath) /ReportFolder:$($HPIA_ReportPath) /Noninteractive /LogFolder:$($HPIA_LogsPath) /Debug /Force"
        }
        WriteLog -Message "Instaling drivers using HPIA, this could take some time" -Verbose
        #include a timer for GUI
        $CallTimer=Start-Process -FilePath "Powershell.exe" -ArgumentList "-Executionpolicy Bypass -File ""$($ConfigPath)\GenerateClockTimer.ps1"" ""$($FSscreenStatusFile)""" -WindowStyle Hidden -WorkingDirectory $PSScriptRoot -PassThru
        "`r`nInstalling drivers, please wait..." | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
        $IntelligentDriver=Invoke-RunPower -File (Join-Path $HPIA_Folder $HPIA_FileName) -Params $parameters -WorkDir $WDT -OutFile "$($logs)\HPIA_installing.log" -Verbose
        #Stop Timer before to continue
        if ($null -ne (Get-Process -Id $CallTimer.Id -ErrorAction SilentlyContinue)) {Stop-Process -Id $CallTimer.Id -Force;}
        $IntelligentMessage="Drivers installation has not definition for current result"
        switch ($IntelligentDriver) {
            0 { $IntelligentMessage="Successfully installed Drivers"; break; }
            256 { $IntelligentMessage="The analysis returned no recommendations."; break;}
            257 { $IntelligentMessage="There were no recommendations selected for the analysis."; break;}
            3010 { $IntelligentMessage="Install Reboot Required - SoftPaq installations are successful, and at least one requires a reboot."; break;}
            3020 { $IntelligentMessage="Install failed - One or more SoftPaq installations failed."; break;}
            4096 { $IntelligentMessage="The platform is not supported."; break;}
            4097 { $IntelligentMessage="The parameters are invalid."; break;}
            4098 { $IntelligentMessage="There is no Internet connection."; break;}
            4098 { $IntelligentMessage="There is no Internet connection."; break;}
            4099 { $IntelligentMessage="Invalid SoftPaq number in SPList file."; break;}
            4100 { $IntelligentMessage="SoftPaq My Product List is empty, so no data was processed."; break;}
            4101 { $IntelligentMessage="The parameter is no longer supported."; break;}
            8192 { $IntelligentMessage="The operation failed"; break;}
            8194 { $IntelligentMessage="The output folder was not created."; break;}
            8195 { $IntelligentMessage="The download folder was not created."; break;}
            8196 { $IntelligentMessage="The supported platforms list download failed."; break;}
            8197 { $IntelligentMessage="The KB download failed."; break;}
            8198 { $IntelligentMessage="The extract folder was not created."; break;}
            8199 { $IntelligentMessage="The SoftPaq download failed."; break;}
            8200 { $IntelligentMessage="The SoftPaq extraction failed."; break;}
            Default {$IntelligentMessage="Not defined code: $($IntelligentDriver)"; break;}
        }
        WriteLog -Message $IntelligentMessage -Verbose
        $Reboot=$true
        #It was detected that HP Drivers folder was captured as part of state, here is removed to reduce size of image.
        if (Test-Path -Path $HPIA_OfflineRepo) {
            WriteLog -Message "Removing Offline repository folder" -Verbose
            $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($HPIA_OfflineRepo)" -OutFile "$($logs)\RemoveOfflineRepo.log"; 
        }
        if (Test-Path -Path $HPIA_DownloadPath) {
            WriteLog -Message "Removing Offline repository folder" -Verbose
            $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($HPIA_DownloadPath)" -OutFile "$($logs)\RemoveOfflineRepo.log"; 
        }
    }

            <###########################################################################################
            ########						HP COMPLETE PROCESS
            ############################################################################################>
    if (Test-Path (Join-Path $Env:SystemDrive "HPDrivers")) {
        "[waiting]Installing Drivers" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
        WriteLog -Message "--->Install Drivers using HPComplete" -Verbose
        $DriversPath=(Join-Path $Env:SystemDrive "HPDrivers")
        $HPComplete="C:\Windows\Setup\Scripts\HPComplete.exe"
        if (-Not(Test-Path $HPComplete)) {
            WriteLog -Message "Missing HPComplete.exe on $(Split-Path $HPComplete -Parent)" -MessageType Error -Verbose;
            "error installing HP drivers, missing HPComplete.exe on $(Split-Path $HPComplete -Parent)" | Out-File -FilePath $errorflg -Encoding default -Force;
            "[error]error installing HP drivers, missing HPComplete.exe on $(Split-Path $HPComplete -Parent)" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline
            $null = Invoke-RunPower -File $OSChanger -Params "/WDT /ABO /ABONP /ErrorNumber:714 /Message:""***FAIL*** The CS Post Processing fail HPComplete tool missing""" -WorkDir $WDT -OutFile "$($logs)\OSChangerError.log" -Verbose
            Exit-FSCode(714);
        }
        if ((Test-Path $DriversPath) -AND (Test-Path $HPComplete)){
            $SeachXML=(Get-ChildItem -Path $DriversPath -Filter "*.xml" -Force)
            if ($SeachXML.Count -gt 0) {
                $SeachXML | ForEach-Object { WriteLog -Message "Moving $($_.Name)" -Verbose; Move-Item -Path $_.FullName -Destination "C:\Windows\Setup\Scripts\$($_.Name)" -Force; }
            } else {
                WriteLog -Message "Not detected any XML on Drivers folder, assume that Scripts folder already have required XML file" -MessageType Warning -Verbose;
            }	
            $RunHPComplete = Invoke-RunPower -File $HPComplete -Params "/full" -WorkDir $PSScriptRoot -OutFile "$($logs)\hpcomplete_execution.log" -Verbose
            if ($null -eq $RunHPComplete) {WriteLog -Message "HPComplete.exe was not executed" -MessageType Error -Verbose;}
            if ($RunHPComplete -ne 0) {             
                "HP Complete return unexpected error, HP FS Post-Processing Mode can't continue" | Out-File -FilePath $errorflg -Encoding default -Force;
                "[error]HP Complete return unexpected error, HP FS Post-Processing Mode can't continue" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline
                WriteLog -Message "HP Complete return unexpected error=$($RunHPComplete), HP FS Post-Processing Mode can't continue" -MessageType Error -Verbose
                foreach ($item in (Get-ChildItem -Path (Split-Path $HPComplete -Parent) -File -Recurse -Exclude "*.exe")) {
                    Copy-Item -Path $item.FullName -Destination (Join-Path $logs $item.Name) -Force
                }
                $null = Invoke-RunPower -File $OSChanger -Params "/WDT /ABO /ABONP /ErrorNumber:712 /Message:""***FAIL*** The CS Post Processing fail HP Complete installation""" -WorkDir $WDT -OutFile "$($logs)\OSChangerError.log" -Verbose
                Exit-FSCode(712);
            }
            if (Test-Path $DriversPath) {
                foreach ($item in (Get-ChildItem -Path (Split-Path $HPComplete -Parent) -File -Recurse -Exclude "*.exe")) {
                    Copy-Item -Path $item.FullName -Destination (Join-Path $logs $item.Name) -Force
                }
                if ((Get-ChildItem $DriversPath -Recurse -Directory | Measure-Object).Count -eq 0) { 
                    WriteLog -Message "$($DriversPath) seems to be empty, try to remove and continue" -Verbose
                } else {
                    WriteLog -Message "Drivers are not successfully installed, HPDrivers folder still present, create flag to stop and review: $($errorflg)" -MessageType Error -Verbose;
                    "error installing drivers, HPDrivers folder remain, review logs on C:\Windows\Setup\Scripts\" | Out-File -FilePath $errorflg -Encoding default -Force;
                    "[error]error installing drivers, HPDrivers folder remains, review log on C:\Windows\Setup\Scripts" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline
                    $null = Invoke-RunPower -File $OSChanger -Params "/WDT /ABO /ABONP /ErrorNumber:713 /Message:""***FAIL*** The CS Post Processing fail HP Complete HPDrivers folder persit""" -WorkDir $WDT -OutFile "$($logs)\OSChangerError.log" -Verbose
                    Exit-FSCode(713);
                }
                
            }
        }
        WriteLog -Message "HP Drivers by setup completed" -Verbose;
        $Reboot=$true
    }
  

            <###########################################################################################
            ########						IF NEED REBOOT UNIT TO APPLY CHANGES
            ############################################################################################>

    WriteLog -Message "Post-Processing Stage: $($CurrentStageFolder), completed" -Verbose
}
catch {
    $ErrorMessage = $_.Exception.Message                
    [string]$ExceptionText = ($_ | Out-String).Trim()
    Write-Host "[ERROR] exception detected on $($CurrentStageFolder), script $($MyInvocation.MyCommand.Name): $($ErrorMessage)"
    Write-Host "[ERROR TEXT]: $($ExceptionText)"
    $null = Invoke-RunPower -File $OSChanger -Params "/WDT /ABO /ABONP /ErrorNumber:999 /Message:""***FAIL***The CS Post Processing fail unamanaged exception""" -WorkDir $WDT -OutFile "$($logs)\OSChangerError.log" -Verbose
    Exit-FSCode(999)
}
if ($Reboot) {
    Exit-FSCode(3010);
} else {
    Exit-FSCode(0);
}
