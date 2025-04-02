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
    		<########################################################################################################
                                                   CLEAN PROCESS phase 2
                      IT IS IMPORTANT TO NOT TOUCH PATH OF CURRENT SCRIPT, LAST STEP WILL REMOVE IT
            ##########################################################################################################>

    "[waiting]Cleanup stage 2 start" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
    WriteLog -Message "--->Final cleanup process start" -Verbose

    if (Test-Path "$($ParentStagePath)\WDT") { WriteLog -Message "Delete WDT folder" -Verbose; $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($ParentStagePath)\WDT" -OutFile "$($logs)\delfolders.log"; }
    if (Test-Path "$($ParentStagePath)\USMT*") {         
        foreach ($usmtfolder in (Get-ChildItem -Path $ParentStagePath -Filter "USMT*")) {
            WriteLog -Message "Delete $($usmtfolder.Name) folder" -Verbose; 
            $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q ""$($usmtfolder.FullName)""" -OutFile "$($logs)\delfolders.log";
        }
    }
    if (Test-Path "$($env:SystemDrive)\system.sav\dpsimages") { WriteLog -Message "Delete DPSIMAGES folder" -Verbose; $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($env:SystemDrive)\system.sav\dpsimages" -OutFile "$($logs)\delfolders.log"; }
    if (Test-Path "$($env:SystemDrive)\system.sav\util\Drivers") { WriteLog -Message "Delete Drivers folder" -Verbose; $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($env:SystemDrive)\system.sav\util\Drivers" -OutFile "$($logs)\delfolders.log"; } 
    if (Test-Path "$($env:SystemDrive)\system.sav\util\MSUpdates") { WriteLog -Message "Delete MSUpdates folder" -Verbose; $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($env:SystemDrive)\system.sav\util\MSUpdates" -OutFile "$($logs)\delfolders.log"; }
    if (Test-Path "$($env:SystemDrive)\system.sav\util\WindowsLP") { WriteLog -Message "Delete LanguagePack folder" -Verbose; $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($env:SystemDrive)\system.sav\util\WindowsLP" -OutFile "$($logs)\delfolders.log"; }
    if (Test-Path "$($env:SystemDrive)\system.sav\util") { WriteLog -Message "Delete Util folder" -Verbose; $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($env:SystemDrive)\system.sav\util" -OutFile "$($logs)\delfolders.log"; }
    if (Test-Path "$($env:SystemDrive)\system.sav\tweaks") { WriteLog -Message "Delete tweaks folder" -Verbose; $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($env:SystemDrive)\system.sav\tweaks" -OutFile "$($logs)\delfolders.log"; }
    if (Test-Path "$($env:SystemDrive)\system.sav\PPKG") { WriteLog -Message "Delete PPKG folder" -Verbose; $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($env:SystemDrive)\system.sav\PPKG" -OutFile "$($logs)\delfolders.log"; }
    if (Test-Path "$($env:SystemDrive)\SWSETUP\AdobeReader") { WriteLog -Message "Delete AdobeReader folder" -Verbose; $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($env:SystemDrive)\SWSETUP\AdobeReader" -OutFile "$($logs)\delfolders.log"; }
    if (Test-Path "$($env:SystemDrive)\SWSETUP\APP\Applications") { WriteLog -Message "Delete Applications folder" -Verbose; $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($env:SystemDrive)\SWSETUP\APP\Applications" -OutFile "$($logs)\delfolders.log"; }
    if (Test-Path "$($env:SystemDrive)\SWSETUP\APP\PreReq2") { WriteLog -Message "Delete PreReq2 folder" -Verbose; $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($env:SystemDrive)\SWSETUP\APP\PreReq2" -OutFile "$($logs)\delfolders.log"; }
    if (Test-Path "$($env:SystemDrive)\SWSETUP\APP\PreReq1") { WriteLog -Message "Delete PreReq1 folder" -Verbose; $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($env:SystemDrive)\SWSETUP\APP\PreReq1" -OutFile "$($logs)\delfolders.log"; }
    if (Test-Path "$($env:SystemDrive)\SWSETUP\APP\PreInstallTools") { WriteLog -Message "Delete PreInstallTools folder" -Verbose; $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($env:SystemDrive)\SWSETUP\APP\PreInstallTools" -OutFile "$($logs)\delfolders.log"; }
    if (Test-Path "$($env:SystemDrive)\HP\Drivers") { WriteLog -Message "Delete HPIA Drivers folder" -Verbose; $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($env:SystemDrive)\HP\Drivers" -OutFile "$($logs)\delfolders.log"; }
    if (Test-Path "$($env:SystemDrive)\HP\SWSetup") { WriteLog -Message "Delete HPIA Extract Drivers folder" -Verbose; $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($env:SystemDrive)\HP\SWSetup" -OutFile "$($logs)\delfolders.log"; }
    if ((Test-Path "$($env:SystemDrive)\SWSETUP\APP") -AND ($null -eq (Get-ChildItem -Path Test-Path "$($env:SystemDrive)\SWSETUP\APP" -Recurse))) {WriteLog -Message "Delete PreInstallTools folder" -Verbose; $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($env:SystemDrive)\SWSETUP\APP" -OutFile "$($logs)\delfolders.log"; }
    if ((Test-Path "$($env:SystemDrive)\SWSETUP")) {
        foreach ($folder in (Get-ChildItem -Path (Join-Path $env:SystemDrive "SWSETUP") -Directory | Where-Object {($_.Name -notlike "HP*") -AND ($_.Name -notlike "SP*")})) {
            WriteLog -Message "Removing path: $($folder.FullName)" -Verbose
            $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($folder.FullName)" -OutFile "$($logs)\delfolders.log";
        }
    }
    if (Test-Path "$($env:SystemDrive)\mntwinre") { WriteLog -Message "Delete mntwinre folder" -Verbose; $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($env:SystemDrive)\mntwinre" -OutFile "$($logs)\delfolders.log"; }
    
    #Change System.sav control access
    #$UserAdmin = Get-LocalUser | Where-Object {($_.SID.ToString().substring($_.SID.ToString().length - 4, 4) -like "-500") -and ($_.SID.ToString().substring(0,8) -like "S-1-5-21") }
    $GroupAdmin = Get-LocalGroup -SID "S-1-5-32-544"
    WriteLog -Message "--->Change System.sav access control, only SYSTEM can open" -Verbose
    $null = Invoke-RunPower -File "cmd.exe" -Params "/c icacls C:\system.sav /setowner ""NT AUTHORITY\SYSTEM""" -OutFile "$($logs)\system.sav_Owner_icacls.log"; 
    if (Test-Path "$($ConfigPath)\aclsystemsav" ) {
        $null = Invoke-RunPower -File "cmd.exe" -Params "/c icacls C:\ /restore $($ConfigPath)\aclsystemsav" -OutFile "$($logs)\system.sav_Access_icacls.log"; 
    } else {
        $null = Invoke-RunPower -File "cmd.exe" -Params "/c icacls C:\system.sav /grant $($GroupAdmin.Name):(F)" -OutFile "$($logs)\system.sav_Access1_icacls.log"; 
        $null = Invoke-RunPower -File "cmd.exe" -Params "/c icacls C:\system.sav /grant $($GroupAdmin.Name):(OI)(CI)(IO)(F)" -OutFile "$($logs)\system.sav_Access2_icacls.log"; 
        $null = Invoke-RunPower -File "cmd.exe" -Params "/c icacls C:\system.sav /grant ""NT AUTHORITY\SYSTEM"":(F)" -OutFile "$($logs)\system.sav_Access3_icacls.log"; 
        $null = Invoke-RunPower -File "cmd.exe" -Params "/c icacls C:\system.sav /grant ""NT AUTHORITY\SYSTEM"":(OI)(CI)(IO)(F)" -OutFile "$($logs)\system.sav_Access4_icacls.log"; 
    }
    $null = Invoke-RunPower -File "cmd.exe" -Params "/c attrib C:\system.sav -A +S +H +R " -OutFile "$($logs)\system.sav_attrib.log"; 

    
    		<########################################################################################################
                                        CHECK IF AY709AV SERVICE FILES WERE DROP
                                                PREAPARE Sysprep Image
            ##########################################################################################################>
    "[info]Checking next step, preparing for seal image" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
    WriteLog -Message "--->Resealing image" -Verbose       
    #It require 2 validations: CSAuditMode Flag and CSAuditMode Unattend
    #CS Audit Files
    $CSAuditFlag=(Join-Path $flags "CSAuditMode.flg")
    $CSAuditUnattend=(Join-Path $Env:SystemDrive "\HP\CSSetup\CSAuditMode\Unattend.xml")
    #Customer unattend
    $CustomerImageUnattend=(Join-Path $Env:SystemDrive "\System.sav\CustomUnattend")
    #Reseal unattends
    $UnattendGen=(Join-Path $PSScriptRoot "UnattendGen.xml")
    $UnattendGenAudit=(Join-Path $PSScriptRoot "UnattendGen_Audit.xml")
    $UnattendNoGen=(Join-Path $PSScriptRoot "UnattendNoGen.xml")
    $UnattendNoGenAudit=(Join-Path $PSScriptRoot "UnattendNoGen_Audit.xml")
    ###### if Flag and unattend exist, let 2nd Audit work on final seal
    if ((Test-Path -Path $CSAuditFlag) -AND (Test-Path -Path $CSAuditUnattend)) {
        "[info]2nd Post processing detected, reaseal and rebot to Audit Mode" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
        WriteLog -Message "FS Audit Mode for PPKG installation was detected, use for next reseal" -Verbose
        $OSChanger_Parameters="/ABO /ABONP"
        $null = Invoke-RunPower -File $OSChanger -Params "$($OSChanger_Parameters) /ErrorNumber:0 /Message:""***PASS*** 1st phase of CS Audit Mode has been completed successfully""" -WorkDir $WDT -OutFile "$($logs)\OSChangerSuccess.log" -Verbose
    
        if (-Not(Test-Path -Path (Join-Path $Env:SystemDrive "\Windows\Panther\Unattend"))) {
            WriteLog -Message "Creating Panther\Unattend Folder" -Verbose
            New-Item -Path (Join-Path $Env:SystemDrive "\Windows\Panther\Unattend") -ItemType Directory -Force
        }
        Copy-Item -Path $CSAuditUnattend -Destination (Join-Path $Env:SystemDrive "\Windows\Panther\Unattend\Unattend.xml") -Force
        if ($null -ne (Get-ChildItem -Path $CustomerImageUnattend -Filter "*.xml")) {
            if (-Not(Test-Path -Path (Join-Path $Env:SystemDrive "\HP\CSSetup\CSAuditMode\CustomerFiles"))) {
                WriteLog -Message "Creating CSAuditMode\CustomerFiles Folder" -Verbose
                New-Item -Path (Join-Path $Env:SystemDrive "\HP\CSSetup\CSAuditMode\CustomerFiles") -ItemType Directory -Force 
            }
            foreach ($file in (Get-ChildItem -Path $CustomerImageUnattend -Filter "*.xml")) {
                WriteLog -Message "Copying $($file.Name) to CustomerFiles PPKG setup" -Verbose
                Copy-Item -Path $file.FullName -Destination (Join-Path $Env:SystemDrive "\HP\CSSetup\CSAuditMode\CustomerFiles\$($file.Name)") -Force
            }
            
        }
        Exit-FSCode(0)
    }
    "[info]Searching registry for GeneralizePostInstall Value" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
    WriteLog -Message "Searching on registry for GeneralizePostInstall" -Verbose
    #Use registry to evaluate sealing
    $gKeyValue = "false"
    $rKeyValue = "false"
    $gValue=$false
    $rValue=$false
    if (Test-Path "HKLM:\SOFTWARE\HP\installedProducts\ProvisioningPackage") {
		WriteLog -Message "Found path on Registry: HKEY_LOCAL_MACHINE\SOFTWARE\HP\installedProducts\ProvisioningPackage, searching key[GeneralizePostInstall]..." -Verbose
		try {
			$gKeyValue = (Get-ItemProperty HKLM:\SOFTWARE\HP\installedProducts\ProvisioningPackage -Name "GeneralizePostInstall" -ErrorAction SilentlyContinue).GeneralizePostInstall
            if ($null -ne  $gKeyValue) {
                WriteLog -Message "Detected registry key, value: [$($gKeyValue)]" -Verbose
            } else {
                $gKeyValue = "false"
            }
		}
		catch {
			WriteLog -Message "Not detected key, using default value: [$($gKeyValue)]" -MessageType Warning -Verbose
		}
		switch ($gKeyValue.ToString().Tolower()) {
            "true" { $gValue=$true; break; }
            "false" { $gValue=$false; break; }
            Default { $gValue=$false; break; }
        }
	} else {
        WriteLog -Message "Not possible detect registry path, using default value"
    }
    "[info]Searching registry for ResealPostInstall Value" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
    WriteLog -Message "Searching on registry for ResealPostInstall" -Verbose
    if (Test-Path "HKLM:\SOFTWARE\HP\installedProducts\ProvisioningPackage") {
		WriteLog -Message "Found path on Registry: HKEY_LOCAL_MACHINE\SOFTWARE\HP\installedProducts\ProvisioningPackage, searching key[ResealPostInstall]..." -Verbose
		try {
			$rKeyValue = (Get-ItemProperty HKLM:\SOFTWARE\HP\installedProducts\ProvisioningPackage -Name "ResealPostInstall" -ErrorAction SilentlyContinue).ResealPostInstall
            if ($null -ne  $rKeyValue) {
                WriteLog -Message "Detected registry key, value: [$($rKeyValue)]" -Verbose
            } else {
                $rKeyValue = "false"
            }           
		}
		catch {
			WriteLog -Message "Not detected key, using default value: [$($rKeyValue)]" -MessageType Warning -Verbose
		}
		switch ($rKeyValue.ToString().Tolower()) {
            "true" { $rValue=$true; break; }
            "false" { $rValue=$false; break; }
            Default { $rValue=$false; break; }
        }
	} else {
        WriteLog -Message "Not possible detect registry path, using default value" -Verbose
    }

    if (-Not(Test-Path -Path (Join-Path $Env:SystemDrive "\Windows\Panther\Unattend"))) {
        WriteLog -Message "Creating Panther\Unattend Folder" -Verbose
        New-Item -Path (Join-Path $Env:SystemDrive "\Windows\Panther\Unattend") -ItemType Directory -Force
    }   
    if ($gValue) {
        "[info]Generalize mode will be used" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
        WriteLog -Message "Image resealing require Generalize, preparing for final stage" -Verbose
        if ($rValue) {
            "Reseal mode to Audit will be used" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
            WriteLog -Message "Image resealing to Audit mode required, selecting $($UnattendGenAudit)" -Verbose
            Copy-Item -Path $UnattendGenAudit -Destination (Join-Path $Env:SystemDrive "\Windows\Panther\Unattend\Unattend.xml") -Force
        } else {
            WriteLog -Message "Selecting $($UnattendGen)" -Verbose
            Copy-Item -Path $UnattendGen -Destination (Join-Path $Env:SystemDrive "\Windows\Panther\Unattend\Unattend.xml") -Force
        }        
    } else {
        "[info]Default mode will be used, Not Generalized" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
        WriteLog -Message "Image doesn't require Generalize parameter" -Verbose       
        if ($rValue) {
            "Reseal mode to Audit will be used" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
            WriteLog -Message "Image resealing to Audit mode required, selecting $($UnattendNoGenAudit)" -Verbose
            Copy-Item -Path $UnattendNoGenAudit -Destination (Join-Path $Env:SystemDrive "\Windows\Panther\Unattend\Unattend.xml") -Force
        } else {
            WriteLog -Message "Image resealing to OOBE, preparing for final stage" -Verbose
            WriteLog -Message "Selecting $($UnattendNoGen)" -Verbose
            Copy-Item -Path $UnattendNoGen -Destination (Join-Path $Env:SystemDrive "\Windows\Panther\Unattend\Unattend.xml") -Force
        }       
    }
    if (Test-Path -Path (Join-Path $PSScriptRoot "FSAuditMode.cmd")) {
        WriteLog -Message "Moving final script..." -Verbose
        $null = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /hiy ""$(Join-Path $PSScriptRoot 'FSAuditMode.cmd')"" ""$($Env:SystemDrive)\Windows\Temp\""" -WorkDir $PSScriptRoot -OutFile "$($logs)\CopyFinalScript.log" -Verbose
    }
    Exit-FSCode(0)


}
catch {
    $ErrorMessage = $_.Exception.Message                
    [string]$ExceptionText = ($_ | Out-String).Trim()
    Write-Host "[ERROR] exception detected on $($CurrentStageFolder), script $($MyInvocation.MyCommand.Name): $($ErrorMessage)"
    Write-Host "[ERROR TEXT]: $($ExceptionText)"
    $null = Invoke-RunPower -File $OSChanger -Params "/WDT /ABO /ABONP /ErrorNumber:999 /Message:""***FAIL***The CS Post Processing fail unamanaged exception""" -WorkDir $WDT -OutFile "$($logs)\OSChangerError.log" -Verbose
    Exit-FSCode(999)
}