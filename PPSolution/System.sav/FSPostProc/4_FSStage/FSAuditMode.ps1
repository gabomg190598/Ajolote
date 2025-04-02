<#
.SYNOPSIS
    HP FS Audit Mode Configuration
.DESCRIPTION
	Configure FS Images
	This version only support Windows 10 minimum version 1909 and Windwos 11
.NOTES
	Script version:		2.0.1 | Update $ScriptVersion variable
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
$ScriptVersion = "2.0.1"
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
                                    GBU COMPONENT & TWEAKS 
                                adapted components to PP process
                P00W65-B2E - Tweak - Update DMASecurity_AllowedBuses
    ####################################################################################################>
    WriteLog -Message "--->GBU Tweaks" -Verbose;
    "[info]Creating Registries - Tweak: P00W65-B2E" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline
    WriteLog -Message "Executing Update DMASecurity_AllowedBuses P00W65-B2E" -Verbose;
    if (Test-Path "C:\system.sav\tweaks\DMASecurity\Update-DMASecurity_AllowedBuses.cmd") {
        WriteLog -Message "Taking ownershipt of registry path before to add devices" -Verbose
        [bool]$Privilege=$false
        [bool]$Privilege=Enable-Privilege SeTakeOwnershipPrivilege 
        if ($Privilege) { WriteLog -Message "Ownership granted" -Verbose; } else { WriteLog -Message "Refuse Ownership" -MessageType warning -Verbose;}
        # Find "BUILTIN\Administrators" in current language
        $objSID = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")
        $objUser = $objSID.Translate( [System.Security.Principal.NTAccount])
        $objUser.Value
        if (Test-Path "HKLM:SYSTEM\CurrentControlSet\Control\DmaSecurity\AllowedBuses") {
            WriteLog -Message "DMA Registry path exists" -Verbose
        } else {
            WriteLog -Message "DMA Registry path does not exist" -MessageType Warning -Verbose
        }

        #implementing retry logic
        $NotOwner = $true
        $MaxRety = 20
        $Retry = 0
        $RetryPause = 10
        while ($NotOwner) {
            $Retry++
            if ($Retry -ge $MaxRety) {
                if (Test-Path $RetryDMA) {
                    WriteLog -Message "Cannot take ownership of registry path" -MessageType Error -Verbose
                    Exit-FSCode(989)
                } else {
                    WriteLog -Message "Cannot take ownership of registry path after $($Retry) retries, reboot unit and try again" -MessageType Error -Verbose
                    "Cannot take ownership of DMA registry path after $($Retry) retries, reboot unit and try again" | Out-File -FilePath $RetryDMA -Encoding default -Force
                    Exit-FSCode(2)
                }                
            } elseif (($Retry -gt ($MaxRety/2)) -AND ($Retry -le $MaxRety)) {
                try {
                    WriteLog -Message "Trying to change permissions of registry" -Verbose
                    # Change Owner to the local Administrators group
                    $LMPath = "SYSTEM\CurrentControlSet\Control\DmaSecurity\AllowedBuses"
                    $SubKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($LMPath, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::ChangePermissions)
                    $Acl = $SubKey.GetAccessControl()
                    $RemoveAcl = $Acl.Access | Where-Object {$_.AccessControlType -eq "Deny"}
                    $Acl.RemoveAccessRule($RemoveAcl)
                    $SubKey.SetAccessControl($Acl)
                    $SubKey.Close()

                     ### Step 2 - get ownerships of key - it works only for current key
                    $regKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($LMPath,[Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,[System.Security.AccessControl.RegistryRights]::TakeOwnership)
                    $acl = New-Object System.Security.AccessControl.RegistrySecurity
                    $acl.SetOwner([System.Security.Principal.NTAccount]$objUser.Value)
                    $regKey.SetAccessControl($acl)

                    ### Step 3 - enable inheritance of permissions (not ownership) for current key from parent
                    $acl.SetAccessRuleProtection($false, $false)
                    $regKey.SetAccessControl($acl)

                    ### Step 4 - only for top-level key, change permissions for current key and propagate it for subkeys
                    # to enable propagations for subkeys, it needs to execute Steps 2-3 for each subkey (Step 5)        
                    $regKey = $regKey.OpenSubKey('', [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,[System.Security.AccessControl.RegistryRights]::ChangePermissions)
                    $rule = New-Object System.Security.AccessControl.RegistryAccessRule($objUser.Value, 'FullControl', 'ContainerInherit', 'None', 'Allow')
                    $acl.ResetAccessRule($rule)
                    $regKey.SetAccessControl($acl)
                    $NotOwner = $false
                }
                catch {
                    $ErrorMessage = $_.Exception.Message
                    WriteLog -Message "Error taking ownership of registry path: $($ErrorMessage)`r`n, retry in $($RetryPause) secs." -MessageType Warning -Verbose
                    Start-Sleep -Seconds $RetryPause
                }                
            } else {                
                try {
                    WriteLog -Message "Trying to Take ownership of registry" -Verbose
                    # Change Owner to the local Administrators group
                    $LMPath = "SYSTEM\CurrentControlSet\Control\DmaSecurity\AllowedBuses"
                    $regKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($LMPath,[Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,[System.Security.AccessControl.RegistryRights]::TakeOwnership)
                    $regACL = $regKey.GetAccessControl()
                    $regACL.SetOwner([System.Security.Principal.NTAccount]$objUser.Value)
                    $regKey.SetAccessControl($regACL)
                    # Change Permissions for the local Administrators group
                    $regKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($LMPath,[Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,[System.Security.AccessControl.RegistryRights]::ChangePermissions)
                    $regACL = $regKey.GetAccessControl()
                    $regRule = New-Object System.Security.AccessControl.RegistryAccessRule ($objUser.Value,"FullControl","None","None","Allow")
                    $regACL.SetAccessRule($regRule)
                    $regKey.SetAccessControl($regACL)
                    $NotOwner = $false
                }
                catch {
                    $ErrorMessage = $_.Exception.Message
                    WriteLog -Message "Error taking ownership of registry path: $($ErrorMessage)`r`n, retry in $($RetryPause) secs." -MessageType Warning -Verbose
                    Start-Sleep -Seconds $RetryPause
                }
            }

        }
        if ($NotOwner) {
            WriteLog -Message "Cannot take ownership of registry path" -MessageType Error -Verbose
            Exit-FSCode(989)
        }
        while (-Not(Test-Path -Path "C:\system.sav\logs\install_FPP.log")) {
            WriteLog -Message "*cmd.exe /c ""c:\system.sav\tweaks\DMASecurity\Update-DMASecurity_AllowedBuses.cmd"""
            $TW1 = Start-Process -FilePath "cmd.exe" -ArgumentList "/c ""c:\system.sav\tweaks\DMASecurity\Update-DMASecurity_AllowedBuses.cmd""" -WorkingDirectory "c:\system.sav\tweaks\DMASecurity" -PassThru -Wait
            $TW1 | Out-Host
        }    
        WriteLog -Message "Completed with return code: $($TW1.ExitCode)" -Verbose
        if (Test-Path -Path "c:\system.sav\tweaks\scripts\DmaSecurity_AllowedBuses.cmd") {
            $getcmd = Get-Content -Path "c:\system.sav\tweaks\scripts\DmaSecurity_AllowedBuses.cmd"
            $getcmd | ForEach-Object { $_ -replace "sys\\ControlSet001\\Control", "SYSTEM\CurrentControlSet\Control" } | Set-Content -Path "c:\system.sav\tweaks\scripts\DmaSecurity_AllowedBuses.cmd" -Force
        }
        
        WriteLog -Message "Capturing DMASecurity_AllowedBuses P00W65-B2E" -Verbose;
        "[info]Importing registries - Tweak: P00W65-B2E" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline
        if (Test-Path "C:\system.sav\tweaks\PreFBIFixups.POS\Capture_DMA_Whitelist.cmd") { 
            $TW1 = Start-Process -FilePath "cmd.exe" -ArgumentList "/c ""C:\system.sav\tweaks\PreFBIFixups.POS\Capture_DMA_Whitelist.cmd""" -WorkingDirectory "c:\system.sav\tweaks\DMASecurity" -PassThru -Wait
            WriteLog -Message "Completed with return code: $($TW1.ExitCode)" -Verbose
            foreach ($reg in (Get-ChildItem -Path "C:\system.sav\tweaks\Recovery" -Filter "*.reg" -Recurse)) {
                $getreg = Get-Content -Path $reg.FullName
                $getreg | ForEach-Object { $_ -replace "SYSTEM\\CurrentControlSet\\Control", "sys\ControlSet001\Control" } | Set-Content -Path $reg.FullName -Force
            }
            $null = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /sehiyk C:\system.sav\tweaks\Recovery\* C:\Recovery\" -WorkDir $PSScriptRoot -OutFile "$($logs)\TWP00W65B2E.log" -Verbose
        }
        else {
            WriteLog -Message "Cannot locate script: C:\system.sav\tweaks\PreFBIFixups.POS\Capture_DMA_Whitelist.cmd" -MessageType Warning -Verbose
        }
    }
    else {
        WriteLog -Message "Cannot locate script: C:\system.sav\tweaks\DMASecurity\Update-DMASecurity_AllowedBuses.cmd" -MessageType Warning -Verbose
    }

       <###############################################################################################################
        #                                 Install MS Updates
        #################################################################################################################>
    WriteLog -Message "Checking Internet access..." -Verbose
    "[waiting]Microsoft Windows Updates`r`nChecking if has internet access..." | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
    $InternetAccess=Get-InternetAccess
    if ($InternetAccess) {
        WriteLog -Message "Internet detected, trying to retrieve latest updates..." -Verbose
        #Variables
        $Session = new-object -com "Microsoft.Update.Session"
        $UpdateCollection = New-Object -ComObject Microsoft.Update.UpdateColl
        $Downloader = $Session.CreateUpdateDownloader()
        $Installer = New-Object -ComObject Microsoft.Update.Installer
        $ctr = "(IsInstalled=0 and DeploymentAction=*) or (IsHidden=1 and DeploymentAction=*)"
        $MSUpdates=@()
        WriteLog -Message "Searching for latest updates..." -Verbose
        "[loading]Searching for latest Windows Updates..." | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline
        #Search for updates
        $Result = $Session.CreateupdateSearcher().Search($ctr).Updates
        if ($null -ne $Result) {
            "'r'n<Search>::Complete. $($Result.Count) updated detected" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline -Append
            #Print on screen
            $Result | Select-Object Title,Identity,IsHidden,IsMandatory,IsInstalled,LastDeploymentChangeTime,KBArticleIDs | Format-List -Property Title,@{l='UpdateID';e={$_.Identity.UpdateID}},@{l='PublishedDate';e={$_.LastDeploymentChangeTime.ToString('yyyy-MM-dd')}},@{l='KBArticle';e={$_.KBArticleIDs}},IsHidden,IsInstalled,IsMandatory | Out-Host
            $Result | Select-Object Title,Identity,IsHidden,IsMandatory,IsInstalled,LastDeploymentChangeTime,KBArticleIDs | ForEach-Object { $MSUpdates += New-Object -TypeName psobject -Property @{Title=$_.Title;UpdateID=$_.Identity.UpdateID;PublishedDate=$_.LastDeploymentChangeTime.ToString('yyyy-MM-dd');KBArticle=$_.KBArticleIDs;IsHidden=$_.IsHidden;IsInstalled=$_.IsInstalled;IsMandatory=$_.IsMandatory}}
            $Result | ForEach-Object {$UpdateCollection.Add($_) | Out-Null}
            #Download updates
            $Downloader.Updates = $UpdateCollection
            WriteLog -Message "Downloading updates, please wait" -Verbose
            "`r`'Downloading $($Result.Count) Updates..." | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline -Append
            $DWResult=$Downloader.Download()
            <#
                Return Value(ResultCode)	Meaning
                0                           Not Started
                1                           In Progress
                2                           Succeeded
                3                           Succeeded With Errors
                4                           Failed
                5                           Aborted        
            #>
            switch ($DWResult.ResultCode) {
                0 { $DWMessage="[$($DWResult.ResultCode)] Not Started"; break; }
                1 { $DWMessage="[$($DWResult.ResultCode)] In Progress"; break; }
                2 { $DWMessage="[$($DWResult.ResultCode)] Succeeded"; break; }
                3 { $DWMessage="[$($DWResult.ResultCode)] Succeeded With Errors"; break; }
                4 { $DWMessage="[$($DWResult.ResultCode)] Failed"; break; }
                5 { $DWMessage="[$($DWResult.ResultCode)] Aborted"; break; }
                Default {$DWMessage="[$($DWResult.ResultCode)] Unsopported return code"; break;}
            }
            $HEXCode="{0:X}" -f $DWResult.HResult
            WriteLog -Message $DWMessage -Verbose
            WriteLog -Message "Error code 0X$($HEXCode)" -Verbose
            "`r`n<Download>::$($DWMessage) - 0X$($HEXCode)" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline -Append

            #Install Updates
            $Installer.Updates = $UpdateCollection
            WriteLog -Message "Installing updates, please wait" -Verbose
            "`r`nInstalling $($Result.Count) Updates..." | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline -Append
            $INResult=$Installer.Install()
            switch ($INResult.ResultCode) {
                0 { $INMessage="[$($INResult.ResultCode)] Not Started"; break; }
                1 { $INMessage="[$($INResult.ResultCode)] In Progress"; break; }
                2 { $INMessage="[$($INResult.ResultCode)] Succeeded"; break; }
                3 { $INMessage="[$($INResult.ResultCode)] Succeeded With Errors"; break; }
                4 { $INMessage="[$($INResult.ResultCode)] Failed"; break; }
                5 { $INMessage="[$($INResult.ResultCode)] Aborted"; break; }
                Default {$INMessage="[$($INResult.ResultCode)] Unsopported return code"; break;}
            }
            $HEXCode="{0:X}" -f $INResult.HResult
            WriteLog -Message $INMessage -Verbose
            WriteLog -Message "Error code 0X$($HEXCode)" -Verbose
            "`r`n<Install>::$($INMessage) - 0X$($HEXCode)" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline -Append
            #Get Even Logs        
            WriteLog -Message "Getting Event log report..." -Verbose
            "`r`n<Report>::Gettig Event Log report" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline -Append
            Get-EventLog -Newest (2*$Result.Count) -LogName System -Source Microsoft-Windows-WindowsUpdateClient -ErrorAction SilentlyContinue | Out-File -FilePath (Join-Path $logs "EventLogMSUpdates.log") -Append
            Exit-FSCode(3010);
        } else {
            WriteLog -Message "Not new updates detected, reboot" -Verbose
        }
        

    } else {
        if (Test-Path "C:\system.sav\util\MSUpdates") {
            WriteLog -Message "MSUpdates folder detected" -Verbose
            "[info]Local MS Updates detected, installing..." | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
            $WSUS_CAB="wsusscn2.cab"
            if (Test-Path "C:\system.sav\util\MSUpdates\$($WSUS_CAB)") {
                $WSUSCAB = Get-ChildItem -Path "C:\system.sav\util\MSUpdates" -Filter $WSUS_CAB -File
                $WSUSOLD_days = (New-TimeSpan -Start $WSUSCAB[0].LastWriteTime.ToString("yyyy-M-dd") -End (Get-Date).ToString("yyyy-M-dd")).Days
                WriteLog -Message "$($WSUS_CAB) file was detected, it's $($WSUSOLD_days) days old" -Verbose
            }
            $Some2Work= Get-ChildItem -Path "C:\system.sav\util\MSUpdates" -Recurse -file
            if ($null -ne $Some2Work) {
                WriteLog -Message "Installing MS Updates" -Verbose
                "[loading]Install MS Updates" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
                $InjectUp = MSUpdates -Path "C:\system.sav\util\MSUpdates" -RemoveSuccess $true -Logs $logs -Verbose
                WriteLog -Message "Return Code from Install Updates: $($InjectUp)" -Verbose
                if ($InjectUp -eq 3010) {
                    "[warning]MS Updates require reboot unit" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
                    WriteLog -Message "Reboot required to apply MS updates." -MessageType Warning -Verbose; 
                    Exit-FSCode(3010);	
                }
                if ($InjectUp -ne 0) {
                    "MSUpdates return unexpected error, HP CS Post-Processing Mode can't continue" | Out-File -FilePath $errorflg -Encoding default -Force;
                    "[error]MSUpdates return error, HP CS Post-Processing Mode can't continue" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline
                    WriteLog -Message "Error Installing MS updates, stop process." -MessageType Error -Verbose; 
                    $null = Invoke-RunPower -File $OSChanger -Params "/WDT /ABO /ABONP /ErrorNumber:724 /Message:""***FAIL*** The CS Post Processing fail MS Updates return error""" -WorkDir $WDT -OutFile "$($logs)\OSChangerError.log" -Verbose	
                    Exit-FSCode(724);
                }
            } else {
                WriteLog -Message "It was not detected MSUpdates files to try to install however folder exist" -MessageType Warning -Verbose;
            }
            WriteLog -Message "Validating MS Updates installed" -Verbose
            "[waiting]Validating MS Updates installed" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
            $exclude = ("*.ini","*.txt","*.log","*.csv","*.xlsx","*.ps1","*.xml","*.lnk", "wsusscn2.cab", "*.zip")
            $ValidateUpdates= Get-ChildItem -Path "C:\system.sav\util\MSUpdates" -Recurse -file -Exclude $exclude -ErrorAction SilentlyContinue
            if ($null -ne $ValidateUpdates) { 
                "MSUpdates validation found error o missing updates applied, HP CS Post-Processing Mode can't continue" | Out-File -FilePath $errorflg -Encoding default -Force;
                "[error]MSUpdates validation found error o missing updates applied, HP CS Post-Processing Mode can't continue" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline
                WriteLog -Message "Error Validating MS updates, stop process." -MessageType Error -Verbose; 
                $null = Invoke-RunPower -File $OSChanger -Params "/WDT /ABO /ABONP /ErrorNumber:727 /Message:""***FAIL*** The CS Post Processing fail MS Updates missing""" -WorkDir $WDT -OutFile "$($logs)\OSChangerError.log" -Verbose	
                Exit-FSCode(727);    
            } else {
                WriteLog -Message "Nothing to Update, Operating System version $($OS.Build)" -Verbose
            }
            #remove folder only 
            $null = MSUpdates -Path "C:\system.sav\util\MSUpdates" -RemoveSuccess $true -Logs $logs -Verbose
        } else {
            WriteLog -Message "No MS updates to apply" -Verbose
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


Exit-FSCode(0);
