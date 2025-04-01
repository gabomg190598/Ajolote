<#
PRE SAVE IMAGE MODULE
Version 1.0.3
    Date: 11/30/2023
Description:
    This module must run only when image is ready to be saved.
    -Adding a scenario to insert RunOnce for SWSETUP\HP applications without PPSolution
    -Adding cleanup KBUpdate folders of modules
    -Adding Set Layered Driver support
    -Remove Recovery folder when just include old reagent xml
#>


if (($null -ne $json.JOBREQUEST.Control) -OR ($null -ne $json.JOBREQUEST.Job)) { 
    if (($json.JOBREQUEST.Control.status -eq "save") -OR ($json.JOBREQUEST.Job.status -eq "save")) {
        WriteLog -Message "Image is ready to save, let's check if there any scenario for this module" -Verbose
        
        #Scenario when PPSolution will not added
        if (($null -eq $json.JOBREQUEST.AddPPSolution) -OR (-Not($json.JOBREQUEST.AddPPSolution))) {
            WriteLog -Message "PPSolution will not added, let's keep checking for scenario" -Verbose
            #Add CSInstall.cmd into registry for applications on C:\SWSETUP\HP
            $HPAppxPath="$($OSDrive)\SWSETUP\HP"
            $REGRunOncePath="Microsoft\Windows\CurrentVersion\RunOnce"
            if(Test-Path -Path $HPAppxPath -PathType Container) {
                WriteLog -Message "It was detected path: $($HPAppxPath), this scenario was created to insert into RunOnce each CSInstall.cmd present on C:\SWSETUP\HP\FOLDERAPP\" -Verbose
                $HPAppx=Get-ChildItem -Path $HPAppxPath -Attributes Directory
                try {
                    #$null = Invoke-RunPower -File "cmd.exe" -Params "/c reg load  HKLM\HPApp $($OSDrive)\Users\Default\NTUSER.DAT" -WorkDir $PSScriptRoot -OutFile "$($logs)\MountReg.log";    
                    $null = Invoke-RunPower -File "cmd.exe" -Params "/c reg load  HKLM\HPApp $($OSDrive)\Windows\System32\config\SOFTWARE" -WorkDir $PSScriptRoot -OutFile "$($logs)\MountReg.log";    
                }
                catch {
                    WriteLog -Message "Not possible mount registry" -MessageType Error -Verbose
                    $global:MessageResults="Not possible mount registry"
                    $global:CodeResults=320
                    Out-WinPE -Backuplogs -RemoveJob
                }
                if (-Not(Test-Path -Path "HKLM:\HPApp\$($REGRunOncePath)")) {
                    WriteLog -Message "Creating RunOnce folder registry" -Verbose
                    try {
                        New-Item -Path "HKLM:\HPApp\$($REGRunOncePath)" -ItemType Directory -Force
                    }
                    catch {
                        WriteLog -Message "It was nos possible to create registry folder RunOnce" -Verbose
                        $global:MessageResults="It was nos possible to create registry folder RunOnce"
                        $global:CodeResults=322
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                    
                }
                WriteLog -Message "Searching for APP folder to insert into registry: HKLM:\SOFTWARE\$($REGRunOncePath)" -Verbose
                foreach ($folder in $HPAppx) {
                    if (Test-Path -Path (Join-Path $folder.FullName "CSInstall.cmd")) {
                        WriteLog -Message "Found $((Join-Path $folder.FullName "CSinstall.cmd")), inset into Registry" -Verbose
                        try {
                            New-ItemProperty -Path "HKLM:\HPApp\$($REGRunOncePath)" -Name "!$($folder.Name)" -Value "cmd.exe /c C:\SWSETUP\HP\$($folder.Name)\CSInstall.cmd" -PropertyType "String" -Force 
                            WriteLog -Message "`tInserted successfully: !$($folder.Name)" -Verbose
                            WriteLog -Message "`tValue: cmd.exe /c C:\SWSETUP\HP\$($folder.Name)\CSInstall.cmd" -Verbose
                        }
                        catch {
                            WriteLog -Message "It was nos possible to insert into registry, fail $($folder.Name)" -Verbose
                            $global:MessageResults="It was nos possible to insert into registry, fail $($folder.Name)"
                            $global:CodeResults=321
                            Out-WinPE -Backuplogs -RemoveJob
                        }
                    }
                }

                try {
                    $maxretry=10
                    $retrycount=0
                    $SuccessUnmount=$false
                    [gc]::Collect()
                    Start-Sleep 2
                    While (!($SuccessUnmount)) {
                        $retrycount++
                        $UnMountReg = Invoke-RunPower -File "cmd.exe" -Params "/c reg unload HKLM\HPApp" -WorkDir $PSScriptRoot -OutFile "$($logs)\UnMountReg.log";
                        if ($UnMountReg -ne 0) { 
                            WriteLog -Message "Not successfully unmount registry[$($UnMountReg)], start sleep 6 secs and try again" -MessageType Warning -Verbose;
                            Start-Sleep -Seconds 6
                        } else {
                            $SuccessUnmount=$true
                            WriteLog -Message "Successfully unmounted registry" -Verbose
                        }
                        if ($retrycount -gt $maxretry) {
                            WriteLog -Message "Not successfully unmount registry[$($UnMountReg) after several retries" -MessageType Error -Verbose;
                            $SuccessUnmount=$true
                            WriteLog -Message "Not possible unmount registry" -MessageType Error -Verbose
                            $global:MessageResults="Not possible unmount registry"
                            $global:CodeResults=322
                            Out-WinPE -Backuplogs -RemoveJob
                        }
                    }
                }
                catch {
                    WriteLog -Message "Not possible unmount registry" -MessageType Error -Verbose
                    $global:MessageResults="Not possible unmount registry"
                    $global:CodeResults=322
                    Out-WinPE -Backuplogs -RemoveJob
                }
            }
            
        }        
        #For any case, removing KBupdate module folders
        $KBUpdateModules="$($OSDrive)\system.sav\Logs\kbupdateModuleFolder.json"
        if (Test-Path -Path $KBUpdateModules -PathType Leaf) {
            WriteLog -Message "Removing folders from KBupdate modules..." -Verbose
            $remove=Get-Content -Path $KBUpdateModules -Raw | ConvertFrom-Json
            foreach ($mod in $remove) {
                if (Test-Path "$($OSDrive)\Windows\System32\WindowsPowerShell\v1.0\Modules\$($mod.Name)" -PathType Container) {
                    WriteLog -Message "Removing module folder ""$($mod.Name)""..." -Verbose
                    Remove-Item -Path "$($OSDrive)\Windows\System32\WindowsPowerShell\v1.0\Modules\$($mod.Name)" -Recurse -Force
                }  
            }
        }
        if (Test-Path -Path "$($OSDrive)\system.sav\util\MSUpdates" -PathType Container) { 
            Remove-Item -Path "$($OSDrive)\system.sav\util\MSUpdates" -Force -Recurse
        }
        #Set-LayeredDriver
        if ($null -ne $json.JOBREQUEST.SetLayeredDriver) {
            WriteLog -Message "SetLayeredDriver found on job, updating image for value: $($json.JOBREQUEST.SetLayeredDriver)" -Verbose
            $ValidOption=$false;
            switch ($json.JOBREQUEST.SetLayeredDriver) {
                1 { WriteLog -Message "Value: $($json.JOBREQUEST.SetLayeredDriver) - ""Specifies the PC/AT Enhanced keyboard (101/102-key).""" -Verbose; $ValidOption=$true; break; }
                2 { WriteLog -Message "Value: $($json.JOBREQUEST.SetLayeredDriver) - ""Specifies the Korean PC/AT 101-Key Compatible keyboard or the Microsoft Natural keyboard (type 1).""" -Verbose; $ValidOption=$true; break; }
                3 { WriteLog -Message "Value: $($json.JOBREQUEST.SetLayeredDriver) - ""Specifies the Korean PC/AT 101-Key Compatible keyboard or the Microsoft Natural keyboard (type 2).""" -Verbose; $ValidOption=$true; break; }
                4 { WriteLog -Message "Value: $($json.JOBREQUEST.SetLayeredDriver) - ""Specifies the Korean PC/AT 101-Key Compatible keyboard or the Microsoft Natural keyboard (type 3).""" -Verbose; $ValidOption=$true; break; }
                5 { WriteLog -Message "Value: $($json.JOBREQUEST.SetLayeredDriver) - ""Specifies the Korean keyboard (103/106-key).""" -Verbose; $ValidOption=$true; break; }
                6 { WriteLog -Message "Value: $($json.JOBREQUEST.SetLayeredDriver) - ""Specifies the Japanese keyboard (106/109-key).""" -Verbose; $ValidOption=$true; break; }
                Default {
                    WriteLog -Message "Invalid Layered Driver option $($json.JOBREQUEST.SetLayeredDriver), not possible to configure" -MessageType Error -Verbose; 
                }
            }
            if (-Not($ValidOption)) {
                $global:MessageResults="Invalid Layered Driver option $($json.JOBREQUEST.SetLayeredDriver), not possible to configure"
                $global:CodeResults=323
                Out-WinPE -Backuplogs -RemoveJob
            }
            $SetLD = Invoke-RunPower -File "dism.exe" -Params "/image:$($OSDrive)\ /Set-LayeredDriver:$($json.JOBREQUEST.SetLayeredDriver)" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\SetLayeredDriver.log"
            if ($SetLD -ne 0) {
                WriteLog -Message "Dism returns unexpected code: $($SetLD)" -MessageType Error -Verbose
                $global:MessageResults="Dism returns unexpected code: $($SetLD), requested value $($json.JOBREQUEST.SetLayeredDriver)"
                $global:CodeResults=324
                Out-WinPE -Backuplogs -RemoveJob
            }
        }

        #Remove Recovery folder when just include old reagent xml
        $GetContentRecovery=(Get-ChildItem -Path (Join-Path $OSDrive "Recovery") -Recurse -Attributes Archive,Hidden -ErrorAction SilentlyContinue)
        if ($null -ne $GetContentRecovery) {
            WriteLog -Message "Detected $(($GetContentRecovery | Measure-Object).Count) files on $((Join-Path $OSDrive "Recovery"))" -Verbose
            if (($GetContentRecovery | Measure-Object).Count -eq 1 -AND $GetContentRecovery[0].Name.ToLower() -eq "reagentold.xml") {
                WriteLog -Message "Only $($GetContentRecovery[0].Name) detected, removing Recovery folder to prevent Windows Setup errors" -Verbose
                Remove-Item -Path $GetContentRecovery[0].FullName -Force
                Remove-Item -Path (Join-Path $OSDrive "Recovery") -Recurse -Force
            }
        }
        #TIMEZONE
        if (![string]::IsNullOrEmpty($json.JOBREQUEST.Localization.timezone)) { 
            $TimeZone=$json.JOBREQUEST.Localization.timezone.Trim()
            WriteLog -Message "Checking TimeZone $($TimeZone) in registry" -Verbose
            try { 
                $null = Invoke-RunPower -File "cmd.exe" -Params "/c reg load  HKLM\HPTZ $($OSDrive)\Windows\System32\config\SYSTEM" -WorkDir $PSScriptRoot -OutFile "$($logs)\MountReg.log";    
            }
            catch {
                WriteLog -Message "Not possible mount registry" -MessageType Error -Verbose
                $global:MessageResults="Not possible mount registry"
                $global:CodeResults=320
                Out-WinPE -Backuplogs -RemoveJob
            }
            if (Test-Path "HKLM:\HPTZ\ControlSet001\Control\TimeZoneInformation") {
                WriteLog -Message "Registry path exist, validate if key exist and has value..." -Verbose
                try {
                    $FoundKeyValue=(Get-ItemProperty -Path "HKLM:\HPTZ\ControlSet001\Control\TimeZoneInformation" -Name "TimeZoneKeyName" -ErrorAction SilentlyContinue)."TimeZoneKeyName"
                    WriteLog -Message "Current Time Zone configuration is $($FoundKeyValue)" -Verbose
                    if ($FoundKeyValue -ne $TimeZone) {
                        WriteLog -Message "Per validation TimeZone is incorrect, updating to $($TimeZone)" -MessageType Warning -Verbose
                        Set-ItemProperty -Path "HKLM:\HPTZ\ControlSet001\Control\TimeZoneInformation" -Name "TimeZoneKeyName" -Value $TimeZone -Force -PassThru
                        $FoundKeyValue=(Get-ItemProperty -Path "HKLM:\HPTZ\ControlSet001\Control\TimeZoneInformation" -Name "TimeZoneKeyName" -ErrorAction SilentlyContinue)."TimeZoneKeyName"
                        WriteLog -Message "Reconfigured Time Zone in registry to $($FoundKeyValue)" -Verbose
                    } else {
                        WriteLog -Message "TimeZone in registry seems to be correct" -Verbose
                    }
                }
                catch {
                    WriteLog -Message "Nos possible locate registry key for TimeZone" -MessageType Error -Verbose
                }
                
            } else {
                WriteLog -Message "Not possible locate registry path, somenthing was incorrectly configured" -MessageType Error -Verbose
            }
            try {
                $maxretry=10
                $retrycount=0
                $SuccessUnmount=$false
                [gc]::Collect()
                Start-Sleep 2
                While (!($SuccessUnmount)) {
                    $retrycount++
                    $UnMountReg = Invoke-RunPower -File "cmd.exe" -Params "/c reg unload HKLM\HPTZ" -WorkDir $PSScriptRoot -OutFile "$($logs)\UnMountReg.log";
                    if ($UnMountReg -ne 0) { 
                        WriteLog -Message "Not successfully unmount registry[$($UnMountReg)], start sleep 6 secs and try again" -MessageType Warning -Verbose;
                        Start-Sleep -Seconds 6
                    } else {
                        $SuccessUnmount=$true
                        WriteLog -Message "Successfully unmounted registry" -Verbose
                    }
                    if ($retrycount -gt $maxretry) {
                        WriteLog -Message "Not successfully unmount registry[$($UnMountReg) after several retries" -MessageType Error -Verbose;
                        $SuccessUnmount=$true
                        WriteLog -Message "Not possible unmount registry" -MessageType Error -Verbose
                        $global:MessageResults="Not possible unmount registry"
                        $global:CodeResults=322
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                }
            }
            catch {
                WriteLog -Message "Not possible unmount registry" -MessageType Error -Verbose
                $global:MessageResults="Not possible unmount registry"
                $global:CodeResults=322
                Out-WinPE -Backuplogs -RemoveJob
            }
        }
        #More scenarios
    } else {
        if ($null -ne $json.JOBREQUEST.Control) {
            WriteLog -Message "No actions required by now for Control in status $($json.JOBREQUEST.Control.status)" -MessageType Warning -Verbose
        } elseif ($null -ne $json.JOBREQUEST.Job) {
            WriteLog -Message "No actions required by now for Job in status $($json.JOBREQUEST.Job.status)" -MessageType Warning -Verbose
        }
    }
} else {
    WriteLog -Message "Module not required, continue" -Verbose
}