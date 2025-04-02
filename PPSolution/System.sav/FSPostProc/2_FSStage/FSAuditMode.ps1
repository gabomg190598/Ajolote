<#
.SYNOPSIS
    HP FS Audit Mode Configuration
.DESCRIPTION
	Configure FS Images
	This version only support Windows 10 minimum version 1909 and Windwos 11
.NOTES
	Script version:		2.0.5 | Update $ScriptVersion variable
	   Script Date: 	Nov.21.2024
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
$ScriptVersion = "2.0.5"
$FSVersion = "$($ScriptVersion) - PPv2.2024"
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
            <###################################################################################################
            ############# 							DRV COMPONENT INSTALLATION
            ####################################################################################################>
            ## Action folder is \SWSETUP\DRV
    $RootDRVpath=(Join-Path $Env:SystemDrive "\SWSETUP\DRV")
    if ((Test-Path -Path $RootDRVpath) -AND ((Get-ChildItem -Path $RootDRVpath | Measure-Object).Count -gt 0)) {
        "[waiting]Detected DRV folder, installing Driver components" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
        WriteLog -Message "Detected path $($RootDRVpath)" -Verbose
        $NeedReboot=$false
        #Warn about single files on root
        if ((Get-ChildItem -Path $RootDRVpath -File | Measure-Object).Count -gt 0) {
            WriteLog -Message "It is not expected to detect files on DRV folder, list those files since will be ignored" -MessageType Warning -Verbose
            Get-ChildItem -Path $RootDRVpath -File | ForEach-Object {
                WriteLog -Message "`tIgnored file: $($_.FullName)" -Verbose
            }
        }
        #List Category
        $CategoryFolderName=(Get-ChildItem -Path $RootDRVpath -Directory)
        foreach ($CatFolder in $CategoryFolderName) {
            WriteLog -Message ">>>>Category folder name detected: $($CatFolder.Name)" -Verbose
            #List Vendor
            $VendorFolderName=(Get-ChildItem -Path $CatFolder.FullName)
            foreach ($VendorFolder in $VendorFolderName) {
                WriteLog -Message ">>>Vendor folder name detected: $($VendorFolder.Name)" -Verbose
                #Get Driver
                $DriverFolderName=(Get-ChildItem -Path $VendorFolder.FullName)
                foreach ($DriverFolder in $DriverFolderName) {
                    WriteLog -Message ">>Driver folder name detected: $($DriverFolder.Name)" -Verbose
                    #Get Version
                    $VersionFolderName=(Get-ChildItem -Path $DriverFolder.FullName)
                    WriteLog -Message ">Version folder name detected: $($VersionFolderName.Name)" -Verbose
                    #Get CVA
                    $DriverCVA=(Get-ChildItem -Path $VersionFolderName.FullName -Filter "*.cva" | Where-Object {$_.Length -gt 0})
                    if ($null -eq $DriverCVA) {
                        WriteLog -Message "No CVA located for this driver, try with default install.cmd" -Verbose
                        "[loading]Installing $($DriverFolder.Name) v.$($VersionFolderName.Name)" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
                        if (Test-Path -Path (Join-Path $VersionFolderName.FullName "install.cmd")) {
                            $InstallDRV=Invoke-RunPower -File "cmd.exe" -Params "/c ""$((Join-Path $VersionFolderName.FullName "install.cmd"))""" -WorkDir $VersionFolderName.FullName -OutFile (Join-Path $logs "$($DriverFolder.Name).log")
                            if (($InstallDRV -eq 0) -OR ($InstallDRV -eq 3010)) {
                                if ($InstallDRV -eq 3010) {$NeedReboot=$true}
                                WriteLog -Message "Successfully installed driver $($VersionFolderName.Name)" -Verbose
                                #try to remove folder
                                WriteLog -Message "Removing folder $($DriverFolderName.FullName)" -Verbose
                                Remove-Item -Path $DriverFolderName.FullName -Force -Recurse
                                if ((Get-ChildItem -Path $VendorFolderName.FullName | Measure-Object).Count -eq 0) {
                                    WriteLog -Message "Removing folder $($VendorFolderName.FullName)" -Verbose
                                    Remove-Item -Path $VendorFolderName.FullName -Force -Recurse
                                } elseif ((Get-ChildItem -Path $CategoryFolderName.FullName | Measure-Object).Count -eq 0) {
                                    WriteLog -Message "Removing folder $($CategoryFolderName.FullName)" -Verbose
                                    Remove-Item -Path $CategoryFolderName.FullName -Force -Recurse
                                } elseif ((Get-ChildItem -Path $RootDRVpath | Measure-Object).Count -eq 0) { 
                                    WriteLog -Message "Removing folder $($RootDRVpath)" -Verbose
                                    Remove-Item -Path $RootDRVpath -Force -Recurse
                                }
                            } else {
                                WriteLog -Message "Failure installing driver $($VersionFolderName.Name)" -MessageType Error -Verbose
                            }                            
                        } else {
                            WriteLog -Message "Not possible to locate install.cmd on $($VersionFolderName.FullName)" -MessageType Error -Verbose
                        }                       
                    } else {
                        $CVAFile=$null
                        if (($DriverCVA | Measure-Object).Count -gt 1) {                             
                            foreach ($cva in $DriverCVA) {
                                if ($null -eq $CVAFile) {
                                    Continue;
                                } else {
                                    if ((Get-Item -Path $cva.FullName).Length -gt 0) {
                                        $CVAFile=$cva
                                    }
                                }                                
                            }                        
                            WriteLog -Message "Not expected to locate more than one CVA, using $($CVAFile.FullName)" -MessageType Warning -Verbose; 
                        } else {
                            $CVAFile=$DriverCVA
                        }
                        if ((Get-Item -Path $CVAFile.FullName).Length -lt 1) {
                            WriteLog -Message "Detected CVA seems to be empty, ignore and continue" -MessageType Warning -Verbose
                        } else {
                            $DRVInstaller=Get-CVAObject -PathFile $CVAFile.FullName
                            WriteLog -Message "Installing $($DRVInstaller.Title) ver.$($DRVInstaller.Version)" -Verbose
                            "[loading]Installing $($DRVInstaller.Title) ver.$($DRVInstaller.Version)" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
                            ###### update code to try to install only if HW is present.
                            if ($null -ne $DRVInstaller.HWId) {
                                foreach ($cvahw in $DRVInstaller.HWId) {
                                    WriteLog -Message "Checking if Hardware ID $($cvahw) is present" -Verbose
                                    $SearchWH=Get-HardwareDevice -HWID $cvahw -logpath $logs
                                    if ($null -ne $SearchWH) {
                                        WriteLog -Message "Hardware ID $($cvahw) is present, continue with installation" -Verbose
                                        break;
                                    }
                                }
                                if ($null -ne $SearchWH) {
                                    WriteLog -Message "Installing driver for $($SearchWH.Name), category $($SearchWH.PNPClass)" -Verbose
                                    $InstallDRV=Invoke-RunPower -File "cmd.exe" -Params "/c ""$((Join-Path $VersionFolderName.FullName $DRVInstaller.SilentFile))"" $($DRVInstaller.SilentParameters)" -WorkDir $VersionFolderName.FullName -OutFile (Join-Path $logs "$($DriverFolder.Name).log")
                                    if ($DRVInstaller.PassCodes -contains $InstallDRV) {
                                        #check if need reboot
                                        WriteLog -Message "Successfully installed driver $($VersionFolderName.Name)" -Verbose
                                        "[waiting]Successfully Installed $($DRVInstaller.Title) ver.$($DRVInstaller.Version)" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
                                        $GetPassString=$DRVInstaller.ReturnCode | Where-Object {$_ -like "$($InstallDRV):*"}
                                        if ($null -ne $GetPassString ) {
                                            WriteLog -Message "Return code found: $($GetPassString)" -Verbose
                                            $RebootString=$GetPassString.Split('=')[0].Split(':')[2].ToUpper()                                  
                                            if (($null -ne $RebootString) -AND ($RebootString -eq "REBOOT")) {
                                                $NeedReboot=$true
                                            }
                                        } else {
                                            WriteLog -Message "Failure installing driver $($VersionFolderName.Name) - Code $($InstallDRV)" -MessageType Error -Verbose
                                        }
                                        #Rule to pause actions for 5 minutes before to continue and allowing setup for WWAN 5G complete firmware upgrade
                                        if ($DRVInstaller.Title -like "HP 5G Mobile*") {
                                            WriteLog -Message "Pause actions for 5 minutes to allow WWAN 5G firmware upgrade" -Verbose
                                            "[waiting]WWAN 5G detected, allowing firmware upgrade, please wait..." | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
                                            Start-Sleep -Seconds 300
                                            WriteLog -Message "Trying to get WWAN information" -Verbose
                                            $null=Invoke-RunPower -File "cmd.exe" -Params "/c netsh m s i" -WorkDir $PSScriptRoot -TimeOut 300 -OutFile (Join-Path $logs "WWAN_HP5G_info.log")
                                        }
                                    } else {
                                        WriteLog -Message "Failure installing driver $($VersionFolderName.Name) - Failure $($InstallDRV)" -MessageType Error -Verbose
                                    }
                                } else {
                                    WriteLog -Message "Not matching hardware detected, ignore installation and continue." -MessageType Warning -Verbose
                                }
                            } else {
                                WriteLog -Message "Not possible locate Hardware ID on CVA, trying to install software...." -Verbose
                                $InstallDRV=Invoke-RunPower -File "cmd.exe" -Params "/c ""$((Join-Path $VersionFolderName.FullName $DRVInstaller.SilentFile))"" $($DRVInstaller.SilentParameters)" -WorkDir $VersionFolderName.FullName -OutFile (Join-Path $logs "$($DriverFolder.Name).log")
                                if ($DRVInstaller.PassCodes -contains $InstallDRV) {
                                    #check if need reboot
                                    WriteLog -Message "Successfully installed driver $($VersionFolderName.Name)" -Verbose
                                    "[waiting]Successfully Installed $($DRVInstaller.Title) ver.$($DRVInstaller.Version)" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
                                    $GetPassString=$DRVInstaller.ReturnCode | Where-Object {$_ -like "$($InstallDRV):*"}
                                    if ($null -ne $GetPassString ) {
                                        WriteLog -Message "Return code found: $($GetPassString)" -Verbose
                                        $RebootString=$GetPassString.Split('=')[0].Split(':')[2].ToUpper()                                       
                                        if (($null -ne $RebootString) -AND ($RebootString -eq "REBOOT")) {
                                            $NeedReboot=$true
                                        }
                                    } else {
                                        WriteLog -Message "Failure installing driver $($VersionFolderName.Name) - Code $($InstallDRV)" -MessageType Error -Verbose
                                    }
                                    #Rule to pause actions for 5 minutes before to continue and allowing setup for WWAN 5G complete firmware upgrade
                                    if ($DRVInstaller.Title -like "HP 5G Mobile*") {
                                        WriteLog -Message "Pause actions for 5 minutes to allow WWAN 5G firmware upgrade" -Verbose
                                        "[waiting]WWAN 5G detected, allowing firmware upgrade, please wait..." | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
                                        Start-Sleep -Seconds 300
                                        WriteLog -Message "Trying to get WWAN information" -Verbose
                                        $null=Invoke-RunPower -File "cmd.exe" -Params "/c netsh m s i" -WorkDir $PSScriptRoot -TimeOut 300 -OutFile (Join-Path $logs "WWAN_HP5G_info.log")
                                    }
                                } else {
                                    WriteLog -Message "Failure installing driver $($VersionFolderName.Name) - Failure $($InstallDRV)" -MessageType Error -Verbose
                                }  
                            }
                            
                        }
                        
                       
                    }
                    
                }
            }
        }
        #Before to complete, give 5 minutes in idle mode to lauch any pending update
        "[info]DRV component installation completed, prepare for rescan devices" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
        WriteLog -Message "<--DRV component installation completed, preparing for rescan devices" -Verbose
        if ($NeedReboot) {
            WriteLog -Message "Reboot required to apply driver installation" -MessageType Warning -Verbose
            Exit-FSCode(3010);
        }
    }


    		<###################################################################################################
            ############# 							PNP RE-SCAN
            ####################################################################################################>

    if ([int]$OS.Build  -gt 18363) {
        "[waiting]Re-scan Devices with PNPUtil" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
        WriteLog -Message "--->Rescan Devices with PNPUtil" -Verbose
        $intRescan = RescanDevices -logpath $logs #This function only suport on Windows 2004 and later
        if ($null -ne $intRescan -AND $intRescan -gt 0) {
            WriteLog -Message "After rescan, it remain some devices, during validation it will retrieve more details" -MessageType Warning -Verbose
        }
        WriteLog -Message "Device Manager rescan using PNPUtil completed" -Verbose;
    } else {
        WriteLog -Message "PNPRescan is not supported on Windows 10 1909 or previous versions" -Messagetype Warning -Verbose
        "[loading]Rescan Devices with PNPUtil it's not supported" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
    }

            <###################################################################################################
            ############					RESET FINGERPRINT <BETA VERSION 0.2>
            ####################################################################################################>
    "[loading]PreCheck Device Manager" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
    WriteLog -Message "--->Validate if Fingerprint exists and has previous information" -Verbose
    WriteLog -Message "Check and enabling available tools" -Verbose
    $ResetFPflag=(Join-Path (Join-Path (Join-Path $env:SystemDrive "system.sav") "flags") "CScleanFP.flg")
    $HPModules=(Join-Path (Join-Path (Join-Path (Join-Path $env:SystemDrive "system.sav") "util") "HP.PowershellModules") "Modules")
    $BCU=(Join-Path (Join-Path (Join-Path (Join-Path $PSScriptRoot "Tools") "BCU") $env:PROCESSOR_ARCHITECTURE) "BiosConfigUtility.exe")
    #Enable detection of 2 tools: HP library and BCU
    $EnableHPLibrary=$false
    $EnableBCUTool=$false
    $ResetSetting=$false
    $ResetCodes=@(43,10,28)
    if (-Not(Test-Path -Path $ResetFPflag)) { 
        if (Test-Path -Path $HPModules -PathType Container ) {
            if ((Test-Path (Join-Path (Join-Path $HPModules "HP.Private") "HP.Private.psd1")) -AND (Test-Path (Join-Path (Join-Path $HPModules "HP.ClientManagement") "HP.ClientManagement.psd1"))) {
                WriteLog -Message "Module library detected, enabling HP Library option" -Verbose
                $EnableHPLibrary=$true
            } 
        }   
        if (Test-Path -Path $BCU) {
            WriteLog -Message "BCU tool detected, enabling BCU option" -Verbose
            $EnableBCUTool=$true
        }
        if (-Not($ResetSetting)){
            WriteLog -Message "Trying to detect Fingerprint device" -Verbose
            $DM_fingerprint=Get-CimInstance -ClassName Win32_PNPEntity | Where-Object { $_.Name -like "*fingerprint*"}	
            if ($null -ne $DM_fingerprint) { 
                WriteLog -Message "Fingerprint device detected, checking status" -Verbose
                $FPHWErorCode=0
                foreach ($dev in $DM_fingerprint) {
                    WriteLog -Message "Name: $($dev.Name) [$($dev.ConfigManagerErrorCode)]" -Verbose
                    WriteLog -Message "HW ID: $($dev.HardwareID[0])" -Verbose
                    WriteLog -Message "Error Code: $($dev.ConfigManagerErrorCode)" -Verbose
                    $FPHWErorCode=$dev.ConfigManagerErrorCode;
                }
                WriteLog -Message "Scan for Bios Reset option" -Verbose
                if ($ResetCodes -contains $FPHWErorCode) {
                    WriteLog -Message "Error $($FPHWErorCode) detected on Fingerprint, searching Bios setting" -Verbose
                    if (-Not($ResetSetting) -AND $EnableHPLibrary) {
                        WriteLog -Message "Loading HP Library Script Modules" -Verbose
                        try {
                            Import-Module (Join-Path (Join-Path $HPModules "HP.Private") "HP.Private.psd1") -Force
                            Import-Module (Join-Path (Join-Path $HPModules "HP.ClientManagement") "HP.ClientManagement.psd1") -Force 
                        }
                        catch {
                            WriteLog -Message "Error loading HP Library Script Modules" -MessageType Warning -Verbose
                            $ResetSetting=$false
                        }
                        WriteLog -Message "Scan for BiosSetting Reset option" -Verbose
                        Get-HPBIOSSettingsList -Format brief | Out-File -FilePath (Join-Path $logs "GetBiosSettingsList.log") -Encoding ascii -Force
                        $FP_SettingName=Get-HPBIOSSettingsList -Format brief | Where-Object {$_ -like "*fingerprint*reset*"}
                        if ($null -eq $FP_SettingName) { $FP_SettingName=(Get-Content -Path (Join-Path $logs "GetBiosSettingsList.log")) | Where-Object {$_ -like "*fingerprint*reset*"} }
                        if ($null -ne $FP_SettingName) {
                            WriteLog -Message "Fingerprint Reset option located on Bios settings: $($FP_SettingName), trying to reset..." -Verbose
                            Set-HPBIOSSettingValue -Name $FP_SettingName -Value "Enable" | Out-File -FilePath "$($logs)\ResetFingerprint.log" -Encoding ascii -Force
                            "Reset Fingerprint using HP Library" | Out-File -FilePath $ResetFPflag -Encoding default -Force -Append
                            $ResetSetting=$true
                            $RebootRequired=$true
                        } else {
                            WriteLog -Message "Not possible locate Fingerprint reset option on BiosSettings" -MessageType Warning -Verbose
                        }                        
                    } 
                    if (-Not($ResetSetting) -AND $EnableBCUTool) {
                        WriteLog -Message "Trying to reset Fingerprint using BCD, getting dump..." -Verbose
                        $null=Invoke-RunPower -File $BCU -Params "/getconfig:$((Join-Path $logs "BCUDump.txt"))" -WorkDir $logs -OutFile (Join-Path $logs "GetSetBCU.log")
                        $ReadBCU=Get-Content -Path (Join-Path $logs "BCUDump.txt")
                        $FindStr=($ReadBCU | Select-String -Pattern "Fingerprint Reset")
                        if ($null -ne $FindStr) {
                            WriteLog -Message "build and run BCU set file" -Verbose
                            "English" | Out-File -FilePath (Join-Path $logs "setfp.txt") -Encoding utf8 -Force
                             $FindStr[0].Line | Out-File -FilePath (Join-Path $logs "setfp.txt") -Encoding utf8 -Force -Append
                            "`tDisable" | Out-File -FilePath (Join-Path $logs "setfp.txt") -Encoding utf8 -Force -Append
                            "`t*Enable" | Out-File -FilePath (Join-Path $logs "setfp.txt") -Encoding utf8 -Force -Append
                            $CallBCU=Invoke-RunPower -File $BCU -Params "/setconfig:$((Join-Path $logs "setfp.txt"))" -WorkDir $logs -OutFile (Join-Path $logs "GetSetBCU.log")
                            WriteLog -Message "Reset Fingerprint using BCU returns code $($CallBCU)" -Verbose
                            if ($CallBCU -eq 0) {
                                WriteLog -Message "Successfully reset Fingerprint using BCU Tool" -Verbose                            
                                "Reset Fingerprint using BCU Tool" | Out-File -FilePath $ResetFPflag -Encoding default -Force -Append
                                $ResetSetting=$true
                                $RebootRequired=$true
                            } else {
                                WriteLog -Message "Failed applying reset using BCU tool" -MessageType Error -Verbose
                            } 
                        } else {
                            WriteLog -Message "Not possible detect setting on current BCU dump" -MessageType Error -Verbose
                        }
                    } 
                    if (-Not($ResetSetting)) {
                        WriteLog -Message "None of available tools works for Fingerprint reset, trying to request manual intervention" -MessageType Warning -Verbose
                        "[eof]SHOW USER PROMPT" | Out-File -FilePath $FSscreenStatusFile -Encoding ascii -NoNewline -Force; 
                        if ($null -ne (Get-Process -Id $global:OnScreenProcess.Id)) {Stop-Process -Id $global:OnScreenProcess.Id -Force}

                        $UserChoice = Show-MessageBoxWithTimeout -Message "Fingerprint seems to had old information and require cleanup from BIOS but not able to trigger from Windows, this unit is about to reboot, try to do it before device manager validation"
                        
                        if ($UserChoice -eq "OK") {
                            WriteLog -Message "User reply form to reset Fingerprint manually" -Verbose
                            "User request to reset Fingerprint manually" | Out-File -FilePath $ResetFPflag -Encoding default -Force -Append                                                                                   
                        } 
                        "[info]HP FS POST-PROCESSING MODE - FINGERPRINT RESET" | Out-File -FilePath $FSscreenStatusFile -Encoding ascii -NoNewline -Force;
                    }
                } else {
                    WriteLog -Message "Fingerprint error code [$($FPHWErorCode)] doesn't require reset" -Verbose
                }
            }
        }
        if ($RebootRequired) {
            WriteLog -Message "Reboot required to apply reset of device" -MessageType Warning -Verbose
            #Exit-FSCode(3010);
        }
    } else {
        WriteLog -Message "Reset Fingerprint flag detected, skip this process" -MessageType Warning -Verbose
    }

    <###########################################################################################
    ########						REBOOT UNIT TO ALLOW NEXT STAGE RUNS
    ############################################################################################>

    WriteLog -Message "Post-Processing Stage: $($CurrentStageFolder), completed, rebooting" -Verbose 
}
catch {
    $ErrorMessage = $_.Exception.Message                
    [string]$ExceptionText = ($_ | Out-String).Trim()
    Write-Host "[ERROR] exception detected on $($CurrentStageFolder), script $($MyInvocation.MyCommand.Name): $($ErrorMessage)"
    Write-Host "[ERROR TEXT]: $($ExceptionText)"
    $null = Invoke-RunPower -File $OSChanger -Params "/WDT /ABO /ABONP /ErrorNumber:999 /Message:""***FAIL***The CS Post Processing fail unamanaged exception""" -WorkDir $WDT -OutFile "$($logs)\OSChangerError.log" -Verbose
    Exit-FSCode(999)
}
      
Exit-FSCode(3010);