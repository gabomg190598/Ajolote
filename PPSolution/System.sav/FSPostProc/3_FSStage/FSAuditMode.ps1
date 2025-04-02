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

    <###################################################################################################
    ############# 							VALIDATE DEVICE MANAGER
    ####################################################################################################>
    "[loading]Validating Device Manager" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
    WriteLog -Message "--->Validate if all devices on Device Manager are installed correctly" -Verbose
    WriteLog -Message "Waiting for rescan devices..." -Verbose
    Start-Sleep -Seconds 20
    $null = Invoke-RunPower -File "pnputil.exe" -Params "/scan-devices" -WorkDir $PSScriptRoot -OutFile "$($logs)\pnputiltemp.log" -Verbose
    WriteLog -Message "Refreshing Device Mamager to extract report..." -Verbose
    Start-Sleep -Seconds 60
    "[loading]Creating Device Manager Report" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
    $DevFailed = @()
    $DevFailed = DeviceReport -ReportName "$($logs)\ReportDevices.xml"
    if (-Not(Test-Path -Path $CSDrvNoVal -PathType Leaf)) {
        if ($DevFailed.Count -gt 0) { 
            WriteLog -Message "Error found checking Device Manager, check $($logs)\ReportDevices.xml" -MessageType Error -Verbose; 
            "Error found checking Device Manager" | Out-File -FilePath $errorflg -Encoding default -Force;
            "[error]Error found checking Device Manager" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline
            $null = Invoke-RunPower -File $OSChanger -Params "/WDT /ABO /ABONP /ErrorNumber:715 /Message:""***FAIL*** The CS Post Processing fail Device Manager has errors""" -WorkDir $WDT -OutFile "$($logs)\OSChangerError.log" -Verbose
            Exit-FSCode(715);
        }
        "<No> YBs detected" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
        #Specific Validation for Display when appears Basic Driver
        #Microsoft Basic Display Driver
        $GetDisplayDev = Get-CimInstance -ClassName Win32_PNPEntity | Where-Object { $_.PNPClass -eq "Display" }
        if (($null -ne $GetDisplayDev) -AND (($GetDisplayDev | Measure-Object).Count -gt 0)) {
            WriteLog -Message "Detected display device(s), checking if no basic driver is used" -Verbose
            foreach ($disdev in $GetDisplayDev) {
                WriteLog -Message "Display detected: $($disdev.Name)" -Verbose
                if ($disdev.Name -like "*Microsoft Basic*") {
                    WriteLog -Message "Microsoft Basic Device is marked as invalid driver, check $($logs)\ReportDevices.xml" -MessageType Error -Verbose; 
                    "Error found checking Device Manager - Basic Display Driver" | Out-File -FilePath $errorflg -Encoding default -Force;
                    "[error]Error found checking Device Manager - Basic Display Driver" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline
                    $null = Invoke-RunPower -File $OSChanger -Params "/WDT /ABO /ABONP /ErrorNumber:715 /Message:""***FAIL*** The CS Post Processing fail Device Manager has display generic driver""" -WorkDir $WDT -OutFile "$($logs)\OSChangerError.log" -Verbose
                    Exit-FSCode(715);
                }
            }
        }
        "<No> Dislay generic driver" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
    } else {
        WriteLog -Message "Skip Device Manager validation due found $($CSDrvNoVal)" -MessageType Warning -Verbose
    }
    WriteLog -Message "No YB found on Device Manager" -Verbose;
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

Exit-FSCode(0);