<#
.SYNOPSIS
    HP FS Audit Mode Configuration
.DESCRIPTION
	Configure FS Images
	This version only support Windows 10 minimum version 1909 and Windwos 11
.NOTES
	Script version:		2.0.1 | Update $ScriptVersion variable
	   Script Date: 	Apr.26.2024
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
                <######################################################################################################################
                #############                            PREPARE PBR - RESET FUNCTION
                ########################################################################################################################>

    "[info]Preapring image for Windows Push Button Reset" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
    WriteLog -Message "--->Preaparing for Windows PBR" -Verbose
    $RecoveryOEMPath="$($env:SystemDrive)\Recovery\OEM"
    #Change System.sav control access after reset
    $GroupAdmin = Get-LocalGroup -SID "S-1-5-32-544"
    WriteLog -Message "Create systemreset.cmd" -Verbose
    if (-Not(Test-Path (Join-Path $RecoveryOEMPath "Point_B"))) {New-Item -Path (Join-Path $RecoveryOEMPath "Point_B") -ItemType Directory -Force }
    if (-Not(Test-Path (Join-Path $RecoveryOEMPath "Point_D"))) {New-Item -Path (Join-Path $RecoveryOEMPath "Point_D") -ItemType Directory -Force }
    $ResetPointB=(Join-Path $RecoveryOEMPath "Point_B")
    $ResetPointD=(Join-Path $RecoveryOEMPath "Point_D")
    "icacls $($env:SystemDrive)\system.sav /setowner ""NT AUTHORITY\SYSTEM""" | Out-File -FilePath (Join-Path $ResetPointB "systemreset.cmd") -Encoding ascii -Append -Force
    "icacls $($env:SystemDrive)\system.sav /setowner ""NT AUTHORITY\SYSTEM""" | Out-File -FilePath (Join-Path $ResetPointD "systemreset.cmd") -Encoding ascii -Append -Force
    if (Test-Path "$($ConfigPath)\aclsystemsav" ) {
        Copy-Item -Path "$($ConfigPath)\aclsystemsav" -Destination  (Join-Path $ResetPointB "aclsystemsav") -Force
        Copy-Item -Path "$($ConfigPath)\aclsystemsav" -Destination  (Join-Path $ResetPointD "aclsystemsav") -Force

        "icacls $($env:SystemDrive)\ /restore %~dp0aclsystemsav" | Out-File -FilePath (Join-Path $ResetPointB "systemreset.cmd") -Encoding ascii -Append -Force
        "icacls $($env:SystemDrive)\ /restore %~dp0aclsystemsav" | Out-File -FilePath (Join-Path $ResetPointD "systemreset.cmd") -Encoding ascii -Append -Force
    } else {
        "icacls $($env:SystemDrive)\system.sav /grant $($GroupAdmin.Name):(F)" | Out-File -FilePath (Join-Path $ResetPointB "systemreset.cmd") -Encoding ascii -Append -Force
        "icacls $($env:SystemDrive)\system.sav /grant $($GroupAdmin.Name):(F)" | Out-File -FilePath (Join-Path $ResetPointD "systemreset.cmd") -Encoding ascii -Append -Force
        "icacls $($env:SystemDrive)\system.sav /grant $($GroupAdmin.Name):(OI)(CI)(IO)(F)" | Out-File -FilePath (Join-Path $ResetPointB "systemreset.cmd") -Encoding ascii -Append -Force 
        "icacls $($env:SystemDrive)\system.sav /grant $($GroupAdmin.Name):(OI)(CI)(IO)(F)" | Out-File -FilePath (Join-Path $ResetPointD "systemreset.cmd") -Encoding ascii -Append -Force 
        "icacls $($env:SystemDrive)\system.sav /grant ""NT AUTHORITY\SYSTEM"":(F)" | Out-File -FilePath (Join-Path $ResetPointB "systemreset.cmd") -Encoding ascii -Append -Force 
        "icacls $($env:SystemDrive)\system.sav /grant ""NT AUTHORITY\SYSTEM"":(F)" | Out-File -FilePath (Join-Path $ResetPointD "systemreset.cmd") -Encoding ascii -Append -Force 
        "icacls $($env:SystemDrive)\system.sav /grant ""NT AUTHORITY\SYSTEM"":(OI)(CI)(IO)(F)" | Out-File -FilePath (Join-Path $ResetPointB "systemreset.cmd") -Encoding ascii -Append -Force 
        "icacls $($env:SystemDrive)\system.sav /grant ""NT AUTHORITY\SYSTEM"":(OI)(CI)(IO)(F)" | Out-File -FilePath (Join-Path $ResetPointD "systemreset.cmd") -Encoding ascii -Append -Force 
    }
    "attrib $($env:SystemDrive)\system.sav -A +S +H +R " | Out-File -FilePath (Join-Path $ResetPointB "systemreset.cmd") -Encoding ascii -Append -Force 
    "attrib $($env:SystemDrive)\system.sav -A +S +H +R " | Out-File -FilePath (Join-Path $ResetPointD "systemreset.cmd") -Encoding ascii -Append -Force 

    $GetPointFolder = Get-ChildItem -Path $RecoveryOEMPath -Directory -Filter "Point_*" -ErrorAction SilentlyContinue
    WriteLog -Message "Scanning OEM folder at $($RecoveryOEMPath)" -Verbose
    if ($null -ne $GetPointFolder) {
        WriteLog -Message "Detected Point_X folders, creating support files" -Verbose
        $enc = New-Object System.Text.UTF8Encoding( $false )
        $XmlWriter = New-Object System.XMl.XmlTextWriter("$($RecoveryOEMPath)\ResetConfig.xml",$enc)
        $xmlWriter.Formatting = "Indented"
        $xmlWriter.Indentation = "4"
        $xmlWriter.WriteStartDocument()
        $XmlWriter.WriteStartElement("Reset")
        foreach ($point in $GetPointFolder) {				
            foreach ($cmd in (Get-ChildItem -Path $point.FullName -Filter "*.cmd")) {
                WriteLog -Message "`tAdding $($cmd.Name) to $((Join-Path $cmd.DirectoryName "CommondReset.cmd"))" -Verbose
                "call %~dp0$($cmd.Name)" | Out-File -FilePath (Join-Path $cmd.DirectoryName "CommondReset.cmd") -Encoding ascii -Append -Force					
            }
            if (Test-Path -Path (Join-Path $point.FullName "CommondReset.cmd")) {
                switch ($point.Name.ToString().ToLower()) {
                    "point_a" { 
                        WriteLog -Message "Found Point_A folder, adding Run entry on XML" -Verbose
                        $xmlWriter.WriteStartElement("Run")
                        $XmlWriter.WriteAttributeString("Phase","BasicReset_BeforeImageApply")
                        $xmlWriter.WriteElementString("Path","$($point.Name)\CommondReset.cmd")
                        $xmlWriter.WriteElementString("Duration","5")
                        $XmlWriter.WriteEndElement()
                    }
                    "point_b" { 
                        WriteLog -Message "Found Point_B folder, adding Run entry on XML" -Verbose
                        $xmlWriter.WriteStartElement("Run")
                        $XmlWriter.WriteAttributeString("Phase","BasicReset_AfterImageApply")
                        $xmlWriter.WriteElementString("Path","$($point.Name)\CommondReset.cmd")
                        $xmlWriter.WriteElementString("Duration","5")
                        $XmlWriter.WriteEndElement()
                    }
                    "point_c" { 
                        WriteLog -Message "Found Point_C folder, adding Run entry on XML" -Verbose
                        $xmlWriter.WriteStartElement("Run")
                        $XmlWriter.WriteAttributeString("Phase","FactoryReset_AfterDiskFormat")
                        $xmlWriter.WriteElementString("Path","$($point.Name)\CommondReset.cmd")
                        $xmlWriter.WriteElementString("Duration","5")
                        $XmlWriter.WriteEndElement()
                    }
                    "point_d" { 
                        WriteLog -Message "Found Point_D folder, adding Run entry on XML" -Verbose
                        $xmlWriter.WriteStartElement("Run")
                        $XmlWriter.WriteAttributeString("Phase","FactoryReset_AfterImageApply")
                        $xmlWriter.WriteElementString("Path","$($point.Name)\CommondReset.cmd")
                        $xmlWriter.WriteElementString("Duration","5")
                        $XmlWriter.WriteEndElement()
                    }
                    Default {}
                }
            }
        }
        $XmlWriter.WriteEndElement()
        $xmlWriter.WriteEndDocument()
        $xmlWriter.Flush()
        $xmlWriter.Close()
    }
    if (Test-Path -Path "$($RecoveryOEMPath)\ResetConfig.xml") {
        WriteLog -Message "ResetConfig.xml created" -Verbose
        Get-Content -Path "$($RecoveryOEMPath)\ResetConfig.xml" | Out-Host
    }
                <######################################################################################################################
                #############                            RETRIVE TPM INFORMATION
                ########################################################################################################################>
    WriteLog -Message "---->Getting TMP information" -Verbose
    "[info]Getting TPM information" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
    WriteLog -Message "`tGet TPM: TPM.log" -Verbose
    Get-Tpm | Out-File -FilePath (Join-Path $logs "TPM.log") -Encoding ascii -Force
    WriteLog -Message "`tGet TPM Endorsement key: TMPEndorsement.log" -Verbose
    Get-TpmEndorsementKeyInfo -HashAlgorithm sha256 -ErrorAction SilentlyContinue | Out-File -FilePath (Join-Path $logs "TMPEndorsement.log") -Encoding ascii -Force

                <######################################################################################################################
                #############                            RETRIVE BITLOCKER AED INFO
                ########################################################################################################################>
    WriteLog -Message "---->Getting Bitlocker AED status" -Verbose
    "[info]Getting BitLocker AED status" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
    if (Test-Path HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker) {
        WriteLog -Message "Searching for Prevent ADE" -Verbose
        $ADE=(Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker -Name PreventDeviceEncryption -ErrorAction SilentlyContinue).PreventDeviceEncryption
        if ($null -eq $ADE) {
            WriteLog -Message "This image will try to activate BitLocker in Automatic mode" -Verbose
        } else {
            WriteLog -Message "This image prevent automatic driver encryption [BitLocker]" -Verbose
            WriteLog -Message "PreventDeviceEncryption=[$($ADE)]" -Verbose
        }
    }

                <######################################################################################################################
                #############                            RETRIVE UNIT INFO
                ########################################################################################################################>
    WriteLog -Message "---->Getting Unit information" -Verbose
    "[info]Getting Unit Information" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
    $null = Invoke-RunPower -File "cmd.exe" -Params "/c MSINFO32.EXE /report $((Join-Path $logs "msinfo32.log"))" -WorkDir $PSScriptRoot -OutFile "$($logs)\UnitInfo.log" -Verbose
}
catch {
    $ErrorMessage = $_.Exception.Message                
    [string]$ExceptionText = ($_ | Out-String).Trim()
    Write-Host "[ERROR] It was not possible Configure PBR on $($CurrentStageFolder) step, script $($MyInvocation.MyCommand.Name): $($ErrorMessage)"
    Write-Host "[ERROR TEXT]: $($ExceptionText)"
    $null = Invoke-RunPower -File $OSChanger -Params "/WDT /ABO /ABONP /ErrorNumber:741 /Message:""***FAIL***The CS Post Processing fail not possible Configure PBR""" -WorkDir $WDT -OutFile "$($logs)\OSChangerError.log" -Verbose
    Exit-FSCode(741);
}

Exit-FSCode(0);