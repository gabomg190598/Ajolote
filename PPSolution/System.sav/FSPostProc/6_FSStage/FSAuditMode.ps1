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
            ############# 					SEARCH AND INSTALL STANDARD PPKG
            ####################################################################################################>
    #Define where can locate PPKG
    $PPKG_Path=(Join-Path $Env:SystemDrive "\System.sav\PPKG")
    WriteLog -Message "--->Get PPKGs on $($PPKG_Path)..." -Component $MyInvocation.MyCommand.Name -Verbose
    $GetPPKGs=Get-ChildItem -Path $PPKG_Path -Filter "*.ppkg" -ErrorAction SilentlyContinue
    if ($null -ne $GetPPKGs) {
        "[loading]PPKG detected, try to install it" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
        #Get Current Provisioned packages installed
        $ActualPPKG=Get-ProvisioningPackage
        $Counter=0
		$TimeWaitSecs=3600 #1Hour
        $failppkg=$false
		$timeoutreached=$false
        foreach ($ppkg in $GetPPKGs) {
            "PPKG file: $($ppkg.Name)" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
            WriteLog -Message "Detected $($ppkg.FullName) try to install" -Verbose
            #Remove previous key on registry
            $RegPath="HKLM:\SOFTWARE\HP\installedProducts\ProvisioningPackage";
            $RegKey="PPKG";
            $SearchKey=(Get-ItemProperty $RegPath -Name $RegKey -ErrorAction SilentlyContinue).$RegKey
            if ($null -ne $SearchKey) { 
                WriteLog -Message "Removing previous key" -MessageType Warning -Verbose
                Remove-ItemProperty -Path $RegPath -Name $RegKey -Force
                Remove-Item -Path $RegPath -Force
            }
            try {
                #INSTALLING STANDARD PPKG
                Install-ProvisioningPackage -PackagePath $ppkg.FullName -QuietInstall -ForceInstall -ErrorAction Stop
            } catch [Microsoft.Windows.Provisioning.ProvCommon.CmdletException]{
                WriteLog -Message "Known exception PSCmdlet took longer than '180000' milli-sec" -Verbose
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                $ErrorType = $_.Exception.GetType().Name
                WriteLog -Message "Exception detected wait for install regkey, check and wait for complete, timeout set to $([math]::round($TimeWaitSecs/60)) minutes " -Verbose
                Write-Host "Error type: $($ErrorType), Error Message: $($ErrorMessage)"
            }   
            $SearchKey=(Get-ItemProperty $RegPath -Name $RegKey -ErrorAction SilentlyContinue).$RegKey
            if ($null -eq $SearchKey) { 
                WriteLog -Message "installing $($ppkg.Name) Waiting for registry key to continue" -Verbose
                "waiting for registry flag...." | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
                $mins=[math]::Floor($Counter/60)
				$secs=$Counter % 60
                While ($null -eq (Get-RegKeyValue -Path $RegPath -Key $RegKey)) {
                    Start-Sleep -Seconds 1
                    $Counter++							
                    $mins=[math]::Floor($Counter/60)
                    $secs=$Counter % 60
                    "[loading]Installing $($ppkg.Name)`r`nElapsed time $($mins.ToString().PadLeft(2,'0')):$($secs.ToString().PadLeft(2,'0'))" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
                    if ($Counter -gt $TimeWaitSecs) {
                        if ($null -eq (Get-Process -Name provtool)) { #Reach timeout but provtool is not longer runnig, it breaks or didn't create expected registry
                            WriteLog -Message "`tTimeout reached after $([math]::round($TimeWaitSecs/60)) minutes, provtool is not runnig but registry was not created, return error 745" -Verbose
                        } else {
                            WriteLog -Message "`tTimeout reached, abort process after $([math]::round($TimeWaitSecs/60)) minutes, return error 745" -Verbose
                        }                        
                        "[error]PPKG has exceed expected time, aborting and mark as incomplete [$($ppkg.Name)]" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append						
                        $failppkg=$true
                        $timeoutreached=$true
                        if (-Not(Test-Path -Path $RegPath)) { New-Item -Path $RegPath -ItemType Directory -Force }
                        New-ItemProperty -Path $RegPath -PropertyType String -Name $RegKey -Value "TimeOut" -Force
                    }
                } #End while
                
            } else {
                WriteLog -Message "Provisioned Package $($ppkg.Name) installed, checking status..." -Verbose
            }
            if (-Not($failppkg)) {
                $ResultRegistry = Get-RegKeyValue -Path $RegPath -Key $RegKey
                WriteLog -Message "Registry Key exist and value stored is [$($ResultRegistry)]" -Verbose
                switch ($ResultRegistry.ToLower()) {
                    "installed" { 
                        WriteLog -Message "PPKG was installed successfully" -Verbose
                        Break;
                    }
                    "failed" {
                        $failppkg=$true
                        WriteLog -Message "PPKG return an error, not fully installed" -Verbose
                        Break
                    }
                    Default {
                        $failppkg=$true
                        WriteLog -Message "Not expected this result: $($ResultRegistry)" -Verbose
                        Break;
                    }
                }
            }

        }
        $AfterPPKG=Get-ProvisioningPackage
        if ($null -eq $ActualPPKG) {
            WriteLog -Message "No previous Provisioned package installed" -Verbose
        } else {
            WriteLog -Message "Previous provisioned package report can be found at $((Join-Path $logs "ProvisionedPackage_Pre.log"))" -Verbose
            $ActualPPKG | Out-File -FilePath (Join-Path $logs "ProvisionedPackage_Pre.log") -Encoding ascii -Force
        }
        if ($null -eq $AfterPPKG) {
            WriteLog -Message "There are no current Provisioned package installed" -Verbose
        } else {
            WriteLog -Message "Post provisioned package report can be found at $((Join-Path $logs "ProvisionedPackage_Pos.log"))" -Verbose
            $AfterPPKG | Out-File -FilePath (Join-Path $logs "ProvisionedPackage_Pos.log") -Encoding ascii -Force
        }
        if (($null -ne $ActualPPKG) -AND ($null -ne $AfterPPKG)) {
            WriteLog -Message "Comparing results using Current Provisionned package" -Verbose
            $NewPPKGs = [system.collections.arraylist]@()
            foreach ($pack in $AfterPPKG) {
                $found=$false
                foreach ($comp in $ActualPPKG) {
                    if ($comp.PackageName -eq $pack.PackageName) {
                        WriteLog -Message "Package $($pack.PackageName) reamain" -Verbose
                        $found=$true
                    }
                }
                if (-Not($found)) {
                    WriteLog -Message "New package detected $($pack.PackageName)" -Verbose
                    [void]$NewPPKGs.Add($pack)
                }                
            }

            if (($null -ne $NewPPKGs) -AND (($NewPPKGs | Measure-Object).Count -gt 0)) {
                foreach ($package in $NewPPKGs) {
                    WriteLog -Message "New package has been detected $($package.PackageName)" -Verbose
                    #HERE I REMOVE PPKG, require a new rule to prevent
                    $ProvisionedPackage=(Get-ProvisioningPackage | Where-Object {$_.PackageName -eq $package.PackageName})
                    WriteLog -Message "Removing ""$($package.PackageName)"" package to prevent reinstalling on system reset" -Verbose
                    WriteLog -Message "     Package path: ""$($package.PackagePath)""" -Verbose
                    WriteLog -Message "       Package ID: $($package.PackageID)" -Verbose
                    WriteLog -Message "Package Installed: $($package.IsInstalled)" -Verbose
                    $ProvisionedPackage | Remove-ProvisioningPackage -Verbose | Out-Host
                }
            } else {
                WriteLog -Message "There are no new provisioned packages detected on this unit" -MessageType Warning -Verbose
            }
        } elseif (($null -eq $ActualPPKG) -AND ($null -ne $AfterPPKG)) {
            foreach ($ppkg in $AfterPPKG) {
                WriteLog -Message "Removing package name: $($ppkg.PackageName)" -Verbose
                WriteLog -Message "         package path: $($ppkg.PackagePath)" -Verbose
                WriteLog -Message "           package ID: $($ppkg.PackageID)" -Verbose
                WriteLog -Message "    package Installed: $($ppkg.IsInstalled)" -Verbose
                $ppkg | Remove-ProvisioningPackage -Verbose | Out-Host
            }            
        }        
        if ($failppkg) {
            WriteLog -Message "Preparing to return with error" -MessageType Error -Verbose
            if ($timeoutreached) {
                $null = RunPower -File $OSChanger -Params "/WDT /ABO /ABONP /ErrorNumber:747 /Message:""***FAIL*** The CS Audit Mode fail, Timeout reached""" -WorkDir $WDT -OutFile "$($logs)\OSChanger_error.log"	
                Exit-FSCode(747);
            } else {
                $null = RunPower -File $OSChanger -Params "/WDT /ABO /ABONP /ErrorNumber:745 /Message:""***FAIL*** The CS Audit Mode fail, unexpected error installing PPKG""" -WorkDir $WDT -OutFile "$($logs)\OSChanger_error.log"
                Exit-FSCode(745);
            }
        }
        foreach ($ppkg in $GetPPKGs) {
            WriteLog -Message "Removing PPKG file: $($ppkg.Name)" -Verbose
            Remove-Item -Path $ppkg.FullName -Force
        }  
    } else {
        WriteLog -Message "No PPKGs detected, continue" -Verbose
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