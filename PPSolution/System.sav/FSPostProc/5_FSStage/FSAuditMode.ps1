<#
.SYNOPSIS
    HP FS Audit Mode Configuration
.DESCRIPTION
	Configure FS Images
	This version only support Windows 10 minimum version 1909 and Windwos 11
.NOTES
	Script version:		2.0.4 | Update $ScriptVersion variable
	   Script Date: 	Dec.4.2024
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
$ScriptVersion = "2.0.4"
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
## This script contains critical changes for first boot, if reboot is to back error to WDT

try {  
    <########################################################################################################
                                        PROCESSING POST AUDIT MODE SCRIPT
            ##########################################################################################################>
    WriteLog -Message "--->Checkig if Post Audit mode script exist" -Verbose
    "[waiting]Checkig if Post Audit mode script exist" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
    if (Test-Path (Join-Path $Env:SystemDrive "\system.sav\tweaks\FSScripts\Post_FSAuditMode.cmd")) { 
        WriteLog -Message "Post FS audit mode script found, moving on" -Verbose
        $null = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy $((Join-Path $Env:SystemDrive "\system.sav\tweaks\FSScripts\Post_FSAuditMode.cmd")) $((Join-Path $env:SystemDrive "\Recovery\OEM\Point_B"))\" -WorkDir (Join-Path $Env:SystemDrive "\Windows\system32") -OutFile "$($logs)\MovePostFSScript.log"
        $null = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy $((Join-Path $Env:SystemDrive "\system.sav\tweaks\FSScripts\Post_FSAuditMode.cmd")) $((Join-Path $env:SystemDrive "\Recovery\OEM\Point_D"))\" -WorkDir (Join-Path $Env:SystemDrive "\Windows\system32") -OutFile "$($logs)\MovePostFSScript.log"
        $null = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy $((Join-Path $Env:SystemDrive "\system.sav\tweaks\FSScripts\Post_FSAuditMode.cmd")) $((Join-Path $env:SystemDrive "\Windows\Temp"))\" -WorkDir (Join-Path $Env:SystemDrive "\Windows\system32") -OutFile "$($logs)\MovePostFSScript.log"
    }


    <########################################################################################################
                                        CHECK WINRE STATUS
            ##########################################################################################################>
    WriteLog -Message "--->Check WinRE Status" -Verbose
    "[waiting]Checking WinRE status" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
    $ReagentInfo = "$($logs)\ReagentInfo.log"
    $BCDEnumAll = (Join-Path $logs "BCDEnumAll.log")
    $null = Invoke-RunPower -File "cmd.exe" -Params "/c bcdedit.exe /enum all > $($BCDEnumAll)" -WorkDir (Join-Path $Env:SystemDrive "\Windows\system32") -OutFile "$($logs)\BCDCheck.log"
    $null = Invoke-RunPower -File "cmd.exe" -Params "/c ReAgentc.exe /info > $($ReagentInfo)" -WorkDir (Join-Path $Env:SystemDrive "\Windows\system32") -OutFile "$($logs)\RunReagentC.log"
    if (Test-Path $ReagentInfo) {
        WriteLog -Message "Reading ReagentC results" -Verbose
        $ValidateWinRE = $false
        $stateWinRE = Get-Content $ReagentInfo | Select-String -Pattern ":*Enabled" | ForEach-Object { $_.ToString().Split(":")[1].Trim() }
        $stateWinREFail = Get-Content $ReagentInfo | Select-String -Pattern ":*Disabled" | ForEach-Object { $_.ToString().Split(":")[1].Trim() }
        $BCDGUID = Get-Content $ReagentInfo | Select-String -Pattern "-*-*-*-" | ForEach-Object { $_.ToString().Split(":")[1].Trim() }
        [string[]]$BCUIdentifier = Get-Content $ReagentInfo | Select-String -Pattern "\\\\`?\\" | ForEach-Object { $_.ToString().split(":")[1].Trim().Replace("\\?\", "").Split("\\") }
        <#
            [0] = GLOBALROOT  <-- Root on physical unit
            [1] = device      <-- Source attached
            [2] = harddisk0   <-- disk number
            [3] = partition4  <-- partition number
            [4] = Recovery    <-- Root folder nae
            [5] = WindowsRE   <-- Folder path where are Recovery files
        #>
        $ResetwinREPath = (Join-Path $Env:SystemDrive "\Windows\System32\Recovery")
        $RecoveryGUID = "{de94bba4-06d1-4d40-a16a-bfd50179d6ac}"
        $system32Path = [System.Environment]::SystemDirectory
        Push-Location -Path $system32Path
        if ($null -ne $stateWinRE) {
            if ($stateWinRE -ieq "Enabled") {
                WriteLog -Message "WinRE is enabled on this system" -Verbose
                "[info]WinRE is enabled on this system" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
                $ValidateWinRE = $true
            }
        }
        if ($null -ne $BCDGUID) {
            $null = Invoke-RunPower -File "cmd.exe" -Params "/c bcdedit.exe /enum ""{$($BCDGUID)}"" > $($logs)\BCDRecovery.log" -WorkDir "C:\Windows\system32" -OutFile "$($logs)\BCDCheck.log"
            $Description = Get-Content "$($logs)\BCDRecovery.log" | Select-String -Pattern "description" | ForEach-Object { $_.ToString().Replace("description", "").Trim() }
            if ($null -ne $Description) {
                "[info]WinRE is enabled on this system by BCD" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
                WriteLog -Message "WinRE was validated using BCD, description found: $($Description)" -Verbose
                $ValidateWinRE = $true
            }
        }
        if (($null -ne $BCUIdentifier) -AND ($BCUIdentifier.Count -eq 6)) {
            if (($BCUIdentifier[0].ToUpper() -eq "GLOBALROOT") -AND ($BCUIdentifier[1].ToLower() -eq "device") ) {
                WriteLog -Message "Winre files has been identified on [$($BCUIdentifier[2]):$($BCUIdentifier[3])]\$($BCUIdentifier[4])\$($BCUIdentifier[5])" -Verbose
                [int]$disk = $BCUIdentifier[2] -replace ("harddisk", "")
                [int]$part = $BCUIdentifier[3] -replace ("partition", "")
                $GptType = (Get-Disk -Number $disk | Get-Partition -PartitionNumber $part).GptType
                if ($GptType -eq "`{de94bba4-06d1-4d40-a16a-bfd50179d6ac`}") {
                    WriteLog -Message "Sucess - Winre has been installed on Recovery partition" -Verbose
                }
                else {
                    WriteLog -Message "Winre was not installed on best partition" -MessageType Warning -Verbose
                }
            }
        }
        if ($null -ne $stateWinREFail) {
            if ($stateWinREFail -ieq "Disabled") {
                #try to enable
                #locate winre.wim
                "[warning]Windows REset has been detected as disabled" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
                "Trying to enable, checking required files" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
                WriteLog -Message "Windows REset has been detected as disabled, trying to enable" -MessageType Warning -Verbose
                if (-Not(Test-Path (Join-Path $ResetwinREPath "winre.wim"))) {
                    "Searching winre.wim since not appears on default location" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
                    WriteLog -Message "WinRE.wim is not present on default location, seaching" -Verbose
                    $GetRecoveryPartitions = (Get-Partition | Where-Object { $_.GptType -eq $RecoveryGUID } | Get-Volume)
                    if ($null -eq $GetRecoveryPartitions) {
                        "Not detected Recovery partition on this system" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
                        WriteLog -Message "This system has not Recovery partition" -Verbose
                        if (-Not(Test-Path -Path (Join-Path $Env:SystemDrive "Recovery"))) {
                            WriteLog -Message "Not possible locate Recovery on System drive, not possible enable Windows Reset Feature" -MessageType Error -Verbose
                            "[error]WinRe is disabled and cannot locate winre.wim" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
                            $null = Invoke-RunPower -File $OSChanger -Params "/WDT /ABO /ABONP /ErrorNumber:733 /Message:""***FAIL*** The CS Post Processing fail WinRE is disabled""" -WorkDir $WDT -OutFile "$($logs)\OSChangerError.log" -Verbose
                            Exit-FSCode(733);
                        }
                        else {
                            $isWinreonC = Get-ChildItem -Path (Join-Path $Env:SystemDrive "Recovery") -Filter "winre.wim" -Recurse -Attributes Hidden, Archive
                            if ($null -eq $isWinreonC) {
                                WriteLog -Message "Not possible locate Winre.wim on System drive, not possible enable Windows Reset Feature" -MessageType Error -Verbose
                                "[error]WinRe is disabled and cannot locate winre.wim" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
                                $null = Invoke-RunPower -File $OSChanger -Params "/WDT /ABO /ABONP /ErrorNumber:733 /Message:""***FAIL*** The CS Post Processing fail WinRE is disabled""" -WorkDir $WDT -OutFile "$($logs)\OSChangerError.log" -Verbose
                                Exit-FSCode(733);
                            } else {
                                "Winre.wim is located on system drive" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
                                WriteLog -Message "Winre.wim is located on system drive" -Verbose
                            }
                        }

                    }
                    else {
                        WriteLog -Message "Recovery Partition detected" -Verbose
                        "Recovery partition detected" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
                        $foundwinre = $false
                        foreach ($part in $GetRecoveryPartitions) {
                            if (Test-Path (Join-Path $part.UniqueId "Recovery")) {
                                WriteLog -Message "Recovery folder located on partition #$(($part | Get-Partition).PartitionNumber)" -Verbose
                                $isWinRE = Get-ChildItem -Path (Join-Path $part.UniqueId "Recovery") -Filter "winre.wim" -Recurse -Attributes Hidden, Archive
                                if ($null -eq $isWinRE) {
                                    WriteLog -Message "Not possible locate winre.wim on this partition" -Verbose
                                }
                                else {
                                    WriteLog -Message "winre.wim is present on this partition" -Verbose
                                    $foundwinre = $true
                                }
                            }
                        }
                        if (-Not($foundwinre)) {
                            "Not possible locate winre.wim on Recovery partition" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
                            WriteLog -Message "Not possible locate winre.wim on detected partitions" -Message Warning -Verbose
                            if (-Not(Test-Path -Path (Join-Path $Env:SystemDrive "Recovery"))) {
                                WriteLog -Message "Not possible locate Recovery on System drive, not possible enable Windows Reset Feature" -MessageType Error -Verbose
                                "[error]WinRe is disabled and cannot locate winre.wim on Recovery partition neither system drive" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
                                $null = Invoke-RunPower -File $OSChanger -Params "/WDT /ABO /ABONP /ErrorNumber:733 /Message:""***FAIL*** The CS Post Processing fail WinRE is disabled""" -WorkDir $WDT -OutFile "$($logs)\OSChangerError.log" -Verbose
                                Exit-FSCode(733);
                            }
                            else {
                                $isWinreonC = Get-ChildItem -Path (Join-Path $Env:SystemDrive "Recovery") -Filter "winre.wim" -Recurse -Attributes Hidden, Archive
                                if ($null -eq $isWinreonC) {                                    
                                    WriteLog -Message "Not possible locate Winre.wim on System drive, not possible enable Windows Reset Feature" -MessageType Error -Verbose
                                    "[error]WinRe is disabled and cannot locate winre.wim on Recovery neither system drive" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
                                    $null = Invoke-RunPower -File $OSChanger -Params "/WDT /ABO /ABONP /ErrorNumber:733 /Message:""***FAIL*** The CS Post Processing fail WinRE is disabled""" -WorkDir $WDT -OutFile "$($logs)\OSChangerError.log" -Verbose
                                    Exit-FSCode(733);
                                }
                            }
                            "Winre.wim was located on System drive" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
                            WriteLog -Message "winre.wim is present on Windows drive" -MessageType Warning -Verbose
                        } else { #not located winre on recovery
                            "Winre.wim was located on Recovery partition" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
                            WriteLog -Message "Winre.wim was located on Recovery partition" -Verbose
                        }
                    } #exist at least one recovery partition
                } #winre.wim is not on reset 
                "Reseting configuration" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
                $ReAgentXmlPath = (Join-Path $ResetwinREPath "ReAgent.xml")
                if (-Not(Test-Path $ReAgentXmlPath)) {
                    WriteLog -Message "Not possible locate ReAgent.xml, stop process with error" -MessageType Error -Verbose
                    "[error]WinRe is disabled and Reagent.xml is not present on system path" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
                    $null = Invoke-RunPower -File $OSChanger -Params "/WDT /ABO /ABONP /ErrorNumber:733 /Message:""***FAIL*** The CS Post Processing fail WinRE is disabled""" -WorkDir $WDT -OutFile "$($logs)\OSChangerError.log" -Verbose
                    Exit-FSCode(733);
                }
                $xml = [xml](Get-Content -Path $ReAgentXmlPath)
                $node = $xml.WindowsRE.ImageLocation
                if (($node.path -eq "") -And ($node.guid -eq "{00000000-0000-0000-0000-000000000000}") -And ($node.offset -eq "0") -And ($node.id -eq "0")) {
                    WriteLog -Message "Stage location info is empty" -Verbose
                }
                else {
                    WriteLog -Message "Clearing stage location info..." -Verbose
                    $node.path = ""
                    $node.offset = "0"
                    $node.guid = "{00000000-0000-0000-0000-000000000000}"
                    $node.id = "0"
                    # Save the change
                    WriteLog -Message "Saving changes to [$($ReAgentXmlPath)]..." -Verbose
                    $xml.Save($ReAgentXmlPath)
                }
                "Getting OSLOADER guid" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
                $null = Invoke-RunPower -File "cmd.exe" -Params "/c bcdedit.exe /enum OSLOADER /v > $($logs)\BCDOSloader.log" -WorkDir "C:\Windows\system32" -OutFile "$($logs)\BCDCheck.log"
                $BCDlines=Get-Content (Join-Path $logs "BCDOSloader.log") | Select-String -Pattern "^device" -Context 1,0
                foreach ($line in $BCDlines) {
                    if ($line.Line -notmatch "\[") {
                        $OSGUID=$line.Context.Precontext[0].Substring($line.Context.Precontext[0].IndexOf(" "),$line.Context.Precontext[0].Length - $line.Context.Precontext[0].IndexOf(" ")).Trim()
                    }
                }
                if ($null -ne $OSGUID) {
                    "Found OS Loader: $($OSGUID)" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
                    WriteLog -Message "Trying to enable Windows Reset using OSBOOTLOADER [$($OSGUID)]" -Verbose
                    #reagentc /enable /osguid "$($OSGUID)"
                    $ReagentC = Invoke-RunPower -File "cmd.exe" -Params "/c reagentc.exe /enable /auditmode /osguid $($OSGUID)" -WorkDir $system32Path -OutFile "$($logs)\ReagentC.log"
                    if (!($ReagentC -eq 0))
                    {
                        WriteLog -Message "Encountered an error when enabling WinRE: $($ReagentC)" -MessageType Warning -Verbose
                    }
                } else {
                    WriteLog -Message "Not possible locate OS BOOT LOADER GUID, trying to enable Windows Reset withut parameters" -MessageType Warning -Verbose
                    #reagentc /enable
                    $ReagentC = Invoke-RunPower -File "cmd.exe" -Params "/c reagentc.exe /enable /auditmode" -WorkDir $system32Path -OutFile "$($logs)\ReagentC.log"
                    if (!($ReagentC -eq 0))
                    {
                        WriteLog -Message "Encountered an error when enabling WinRE: $($ReagentC)" -MessageType Warning -Verbose
                    }
                }
                "Verify current status of Windows Reset" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
                WriteLog -Message "Verify current status of Windows Reset" -Verbose
                $null = Invoke-RunPower -File "cmd.exe" -Params "/c ReAgentc.exe /info > $($ReagentInfo)" -WorkDir "C:\Windows\system32" -OutFile "$($logs)\RunReagentC.log"
                $RefreshWinREStatus = DisplayWinREStatus
                $WinREStatus = $RefreshWinREStatus[0]
                $WinRELocation = $RefreshWinREStatus[1]
                if (!$WinREStatus)
                {
                    WriteLog -Message "WinRE can't enable, stop process" -MessageType Error -Verbose
                    "[error]WinRe can't enabled" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
                    $null = Invoke-RunPower -File $OSChanger -Params "/WDT /ABO /ABONP /ErrorNumber:733 /Message:""***FAIL*** The CS Post Processing fail WinRE is disabled""" -WorkDir $WDT -OutFile "$($logs)\OSChangerError.log" -Verbose
                    Exit-FSCode(733);
                } else {
                    "[info]Windows Reset is Enabled" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
                    WriteLog -Message "Windows Reset is Enabled" -Verbose
                    $ValidateWinRE=$true
                    $OSPartition = Get-Partition -DriveLetter ($Env:SystemDrive).Substring(0,1)
                    $WinRELocationItems = $WinRELocation.Split('\\')
                    foreach ($item in $WinRELocationItems)
                    {
                        if ($item -like "harddisk*")
                        {
                            $OSDiskIndex = ExtractNumbers($item)
                        }
                        if ($item -like "partition*")
                        {
                            $WinREPartitionIndex = ExtractNumbers($item)
                        }
                    }
                    "OS Disk: $($OSDiskIndex)" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
					"OS Partition: $($OSPartition.PartitionNumber)" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
					"WinRE Partition: $($WinREPartitionIndex)" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
					
                    WriteLog -Message "OS Disk: $($OSDiskIndex)" -Verbose
                    WriteLog -Message "OS Partition: $($OSPartition.PartitionNumber)" -Verbose
                    WriteLog -Message "WinRE Partition: $($WinREPartitionIndex)" -Verbose
                }

                
            }
        }		
        if (!($ValidateWinRE)) {
            "[error]not possible detect state of WinRE" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
            WriteLog -Message "Not possible found state string on result file neither on BCD" -MessageType Error -Verbose
            WriteLog -Message "$(Get-Content $ReagentInfo)" -Verbose
            $null = Invoke-RunPower -File $OSChanger -Params "/WDT /ABO /ABONP /ErrorNumber:734 /Message:""***FAIL*** The CS Post Processing fail not possible validate WinRE""" -WorkDir $WDT -OutFile "$($logs)\OSChangerError.log" -Verbose
            Exit-FSCode(734);
        }
        Pop-Location
    }
    else {
        WriteLog -Message "Not possible retrive information from this unit, missing result file" -MessageType Error -Verbose
        "[error]not possible detect state of WinRE" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
        $null = Invoke-RunPower -File $OSChanger -Params "/WDT /ABO /ABONP /ErrorNumber:734 /Message:""***FAIL*** The CS Post Processing fail not possible validate WinRE""" -WorkDir $WDT -OutFile "$($logs)\OSChangerError.log" -Verbose
        Exit-FSCode(734);
    }
            


    <######################################################################################################################
                                        TCO config
            ########################################################################################################################>
    #Fisrt draf of this configuration, all units include on this PP will contains this link
    if (Test-Path -Path (Join-Path $flags "PreventTCO.flg")) {
        WriteLog -Message "Prevent TCO flag detected, continue without modification" -Verbose
    } else {
        if (Test-Path -Path "$($ConfigPath)\TCO" -PathType Container) {
            WriteLog -Message "TCO folder was detected, copy content into System Drive" -Verbose
            "[info]Platform marked as TCO certified, adding link and direct access on desktop" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
            $null = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /sehiy $($ConfigPath)\TCO\* $($env:SystemDrive)\" -WorkDir $WDT -OutFile "$($logs)\CopyTCO.log" -Verbose
        }
        else {
            WriteLog -Message "Not possible detect TCO folder, nothing to copy"  -Verbose
        }
    }
    



    <######################################################################################################################
                                        CREATE RUNONCE
            ########################################################################################################################>
    WriteLog -Message "--->Creating RunOnce keys like CSInstall.cmd on SWSETUP\HP or initial scripts" -Verbose
    "[info]Searching for required HP Apps" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
    $HPAppxPath = "$($env:SystemDrive)\SWSETUP\HP"
    if (Test-Path -Path $HPAppxPath -PathType Container) {
        $HPAppx = Get-ChildItem -Path $HPAppxPath -Attributes Directory
        if (-Not(Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce")) {
            WriteLog -Message "Creating RunOnce folder registry..." -Verbose
            try {
                New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" -ItemType Directory -Force
            }
            catch {
                WriteLog -Message "It was not possible to create registry folder RUNONCE" -Verbose
                "It was not possible to create registry folder RUNONCE" | Out-File -FilePath $errorflg -Encoding default -Force;
                "[error]It was not possible to create registry folder RUNONCE" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline
                $null = Invoke-RunPower -File $OSChanger -Params "/WDT /ABO /ABONP /ErrorNumber:740 /Message:""***FAIL*** The CS Post Processing fail not possible to insert RunOnce Registry""" -WorkDir $WDT -OutFile "$($logs)\OSChangerError.log" -Verbose
                Exit-FSCode(740);
            }			
        }
        foreach ($folder in $HPAppx) {
            if (Test-Path -Path (Join-Path $folder.FullName "CSInstall.cmd")) {
                WriteLog -Message "Found $((Join-Path $folder.FullName "CSinstall.cmd")), inset into Registry" -Verbose
                try {					
                    New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" -Name "!$($folder.Name)" -Value "cmd.exe /c $($folder.FullName)\CSInstall.cmd" -PropertyType "String" -Force 	
                    WriteLog -Message "`tInserted: !$($folder.Name)" -Verbose
                }
                catch {
                    WriteLog -Message "It was not possible to insert into registry, fail $($folder.Name)" -Verbose
                    "It was not possible to insert into registry, fail $($folder.Name)" | Out-File -FilePath $errorflg -Encoding default -Force;
                    "[error]It was not possible to insert into registry, fail $($folder.Name)" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline
                    $null = Invoke-RunPower -File $OSChanger -Params "/WDT /ABO /ABONP /ErrorNumber:740 /Message:""***FAIL*** The CS Post Processing fail not possible to insert RunOnce Registry""" -WorkDir $WDT -OutFile "$($logs)\OSChangerError.log" -Verbose
                    Exit-FSCode(740);
                }
            }
        }
        Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce | Out-Host
        #validate
        foreach ($folder in $HPAppx) {
            if (Test-Path -Path (Join-Path $folder.FullName "CSInstall.cmd")) {
                WriteLog -Message "Validate $($folder.FullName), into Registry" -Verbose
                try {
                    if ($null -eq ((Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce -Name "!$($folder.Name)" -ErrorAction SilentlyContinue)."!$($folder.Name)")) {
                        WriteLog -Message "Not possible locate key named: [!$($folder.Name)]" -MessageType Error -Verbose
                        "It was not possible to detect registry key named: [!$($folder.Name)]" | Out-File -FilePath $errorflg -Encoding default -Force;
                        "[error]It was not possible to detect registry key named: [!$($folder.Name)]" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline
                        $null = Invoke-RunPower -File $OSChanger -Params "/WDT /ABO /ABONP /ErrorNumber:740 /Message:""***FAIL*** The CS Post Processing fail not possible to insert RunOnce Registry""" -WorkDir $WDT -OutFile "$($logs)\OSChangerError.log" -Verbose
                        Exit-FSCode(740);
                    }
                    else {
                        WriteLog -Message "Successfully added registry key: [!$($folder.Name)] = [$(((Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce -Name "!$($folder.Name)" -ErrorAction SilentlyContinue)."!$($folder.Name)"))]" -Verbose
                    }
                }
                catch {
                    WriteLog -Message "It was not possible to detect registry, fail $($folder.Name)" -Verbose
                    "It was not possible to detect registry, fail $($folder.Name)" | Out-File -FilePath $errorflg -Encoding default -Force;
                    "[error]It was not possible to detect registry, fail $($folder.Name)" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline
                    $null = Invoke-RunPower -File $OSChanger -Params "/WDT /ABO /ABONP /ErrorNumber:740 /Message:""***FAIL*** The CS Post Processing fail not possible to insert RunOnce Registry""" -WorkDir $WDT -OutFile "$($logs)\OSChangerError.log" -Verbose
                    Exit-FSCode(740);
                }
            }
        }
    }
    else {
        WriteLog -Message "Not found \SWSETUP\HP folder, nothing to do" -Verbose
    }

        
    <###################################################################################################
                                    STAMP IMAGE INFORMATION ON REGISTRY
                This process is part of factory procees where regsitry fail mounting 
            ####################################################################################################>
    WriteLog -Message "--->Tatoo image info on registry(when CG500IMG fails)" -Verbose;
    $InfoFile = "C:\system.sav\HPCSCorporateReadyImage.ini"
    $HPModel = (Get-WmiObject Win32_Computersystem).Model
    $RegPath = "HKLM:\SOFTWARE\HPInc"
    if (Test-Path $InfoFile) {
        "[info]Write values about this image on registry" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
        WriteLog -Message "Detected file with information about this image $($InfoFile)" -Verbose        
        if (!(Test-Path $RegPath)) { New-Item -Path $RegPath -ItemType Directory; WriteLog -Message "Path in registry was created: $($RegPath)" -Verbose; }
        WriteLog -Message "Reading Info file" -Verbose
        foreach ($line in (Get-Content $InfoFile)) {
            WriteLog -Message "Line content: $($line)" -Verbose
            if ($line.Contains("=")) {
                $aReg = $line.Split('=')
                if (($null -ne $aReg[0]) -OR ($null -ne $aReg[1])) {
                    WriteLog -Message "Save on registry Key=$($aReg[0]) & Value=$($aReg[1])" -Verbose
                    New-ItemProperty -Path $RegPath -Name $aReg[0] -PropertyType String -Value $aReg[1] -Force
                }
                else {
                    WriteLog -Message "Key or Value are empty" -MessageType Warning -Verbose
                }
            }
        }
        
    }
    else {
        if (-Not(Test-Path -Path $RegPath)) { 
            $SaveDate = Get-Date -format "[MM-dd-yy : hh:mm:ss]"
            WriteLog -Message "It is not possible to detect pending registry values and registry is empty, this is not a factory image. adding standard values" -Verbose
            New-Item -Path $RegPath -ItemType Directory; 
            WriteLog -Message "Path in registry was created: $($RegPath)" -Verbose; 
            WriteLog -Message "Save on registry Key=Product & Value=$($HPModel)" -Verbose
            New-ItemProperty -Path $RegPath -Name "Product" -PropertyType String -Value $HPModel -Force
            WriteLog -Message "Save on registry Key=ImgBorn & Value=$($SaveDate)" -Verbose
            New-ItemProperty -Path $RegPath -Name "ImgBorn" -PropertyType String -Value $SaveDate -Force
            WriteLog -Message "Save on registry Key=Service & Value=HP FS Image Service" -Verbose
            New-ItemProperty -Path $RegPath -Name "Service" -PropertyType String -Value "HP FS Image Service" -Force
        }
    }
    WriteLog -Message "Adding model to registry for system identification" -Verbose
    New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation -Name Model -PropertyType String -Value $HPModel -Force



    <###################################################################################################
            ############# 					GET MICROSOFT UPDATES - REPORT FOR LOGS
            ####################################################################################################>
    "[waiting]Checking Microsoft Updates installed" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
    WriteLog -Message "--->Get HotFixes installed..." -Component $MyInvocation.MyCommand.Name
    $Fixes = Get-HotFix
    Foreach ($hot in $Fixes) {
        WriteLog -Message "Update KB: $($hot.HotFixID) | Description: $($hot.Description) | Installed: $($hot.InstalledOn) | By: $($hot.InstalledBy)" -Component $MyInvocation.MyCommand.Name
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

Exit-FSCode(0);
