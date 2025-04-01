<#
Module: PPKG Installation
Description: This module installs PPKGs from C:\system.sav\PPKG\
Version: 1.0.4
Date: 04/4/2024
#>
if ($null -ne $json.JOBREQUEST.InstallPPKG) {
    if (($null -eq $json.JOBREQUEST.InstallPPKG.status) -OR (($null -ne $json.JOBREQUEST.InstallPPKG.status) -AND ($json.JOBREQUEST.InstallPPKG.status.ToLower() -eq "new"))) {
        WriteLog -Message "This module reach Windows stage but no changes expected from WinPE, mark as error" -MessageType Error -Verbose
        Update-JobStatus $jobfile $json $json.JOBREQUEST.InstallPPKG "fail" "This module reach Windows stage but no changes expected from WinPE, mark as error" 
        $global:MessageResults="This module reach Windows stage but no changes expected from WinPE, mark as error" 
        $global:CodeResults=906
        Out-Windows
    } elseif (($null -ne $json.JOBREQUEST.InstallPPKG.status) -AND ($json.JOBREQUEST.InstallPPKG.status.ToLower() -eq "ready")) {
        WriteLog -Message "Install PPKG module detected, searching files" -Verbose
        $PPKGSource=(Join-Path $Env:SystemDrive "\System.sav\PPKG")
        if (-Not(Test-Path $PPKGSource)) {
            WriteLog -Message "Not possible locate PPKG path: $($PPKGSource)" -MessageType Error -Verbose
            Update-JobStatus $jobfile $json $json.JOBREQUEST.InstallPPKG "fail" "Not possible locate PPKG path: $($PPKGSource)"
            $global:MessageResults="Not possible locate PPKG path: $($PPKGSource)"
            $global:CodeResults=404
            Out-Windows
        }
        $GetPPKGs=Get-ChildItem -Path $PPKGSource -Filter "*.ppkg" -Recurse
        if ($null -eq $GetPPKGs) {
            WriteLog -Message "Not possible locate single PPKG file" -MessageType Error -Verbose
            Update-JobStatus $jobfile $json $json.JOBREQUEST.InstallPPKG "fail" "Not possible locate single PPKG file"
            $global:MessageResults="Not possible locate single PPKG file"
            $global:CodeResults=404
            Out-Windows
        }
        foreach ($file in $json.JOBREQUEST.InstallPPKG.files) {
            if (-Not(Test-Path (Join-Path $PPKGSource $file))) {
                WriteLog -Message "Requested file ""$($file)"" wasn't found on local drive, mark as error" -MessageType Error -Verbose
                Update-JobStatus $jobfile $json $json.JOBREQUEST.InstallPPKG "fail" "Requested file $($file) wasn't found on local drive, mark as error"
                $global:MessageResults="Requested file $($file) wasn't found on local drive, mark as error"
                $global:CodeResults=404
                Out-Windows
            }
        }
        if ($null -ne $json.JOBREQUEST.InstallPPKG.removepackage) {
            [bool]$RemovePackage=$json.JOBREQUEST.InstallPPKG.removepackage
        } else {
            [bool]$RemovePackage=$false
        }
        #Remove unattend files prio to execute PPKG
        foreach ($xml in (Get-ChildItem -Path (Join-Path $Env:SystemDrive "\Windows\System32\Sysprep") -Filter "*.xml" -ErrorAction SilentlyContinue)) {
            WriteLog -Message "Found unattend file: $($xml.FullName), removing before PPKG installation..." -Verbose
            Remove-Item -Path $xml.FullName -Force
        }
        foreach ($xml in (Get-ChildItem -Path (Join-Path $Env:SystemDrive "\Windows\Panther\Unattend") -Filter "*.xml" -ErrorAction SilentlyContinue)) {
            WriteLog -Message "Found unattend file: $($xml.FullName), removing before PPKG installation..." -Verbose
            Remove-Item -Path $xml.FullName -Force
        }
        $RegPath="HKLM:\SOFTWARE\HP\installedProducts\ProvisioningPackage";
        $RegKey="PPKG";
        $RegSysprep="GeneralizePostInstall"
        $ActualPPKG=Get-ProvisioningPackage
        foreach ($ppkg in $GetPPKGs) {
            WriteLog -Message "PPKG detected: $($ppkg.Name)" -Verbose            
            $SearchKey=(Get-ItemProperty $RegPath -Name $RegKey -ErrorAction SilentlyContinue).$RegKey
            if ($null -ne $SearchKey) { 
                WriteLog -Message "Removing previous key [$SearchKey]" -MessageType Warning -Verbose
                Remove-ItemProperty -Path $RegPath -Name $RegKey -Force
                Remove-Item -Path $RegPath -Force
            }
            WriteLog -Message "Checking pre pvtool status.." -Verbose
            if ($null -eq (Get-Process -Name provtool -ErrorAction SilentlyContinue)) {
                WriteLog -Message "PROVTOOL is not running, process can continue" -Verbose
            } else {
                WriteLog -Message "It is not expected to detect PROVTOOL running before to execute PPKG, waiting to stop" -MessageType Warning -Verbose
                $RunningTool=$true
                $counter=0
                while ($RunningTool) {
                    if ($null -eq (Get-Process -Name provtool -ErrorAction SilentlyContinue)) {
                        $RunningTool=$false
                    } else {
                        if ($counter -ge 300) {
                            WriteLog -Message "After 5 minutes, PROVTOOL still running, cannot continue" -MessageType Error -Verbose
                            Get-ProvisioningPackage | Out-Host
                            Update-JobStatus $jobfile $json $json.JOBREQUEST.InstallPPKG "fail" "PROVTOOL is running which prevent launch new installation for $($ppkg.Name)" 
                            $global:MessageResults="PROVTOOL is running which prevent launch new installation for $($ppkg.Name)"
                            $global:CodeResults=200
                            Out-Windows                         
                        } else {
                            Start-Sleep -Seconds 1
                        }
                    }                    
                }
            }
            try {
                #INSTALLING STANDARD PPKG
                WriteLog -Message "Installing: *Install-ProvisioningPackage -PackagePath $($ppkg.FullName) -QuietInstall -ForceInstall -ErrorAction Stop" -Verbose
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
                      
            #If provtool is running, PPKG still runnig
            #if registry key exist a result indicates to proceed
            #timeout could break any as error
            $SetTimeout=60 #minutes
            $failppkg=$false
            $PROVTOOL=(Get-Process -Name provtool -ErrorAction SilentlyContinue)
            WriteLog -Message "Checking pvtool status.." -Verbose
            if ($null -ne $PROVTOOL) {
                WriteLog -Message "PROVTOOL is running, check if registry exist" -Verbose
                $SearchKey=(Get-ItemProperty $RegPath -Name $RegKey -ErrorAction SilentlyContinue).$RegKey
                if ($null -eq $SearchKey) {
                    WriteLog -Message "Not located registry key, start timer waiting for close PROVTOOL or Registry appears" -Verbose
                    $clock = [Diagnostics.Stopwatch]::StartNew()
                    $WaitForSignal=$true
                    while ($WaitForSignal) {
                        $SearchKey=(Get-ItemProperty $RegPath -Name $RegKey -ErrorAction SilentlyContinue).$RegKey
                        if ($null -ne $SearchKey) {
                            WriteLog -Message "Registry has been detected: $($SearchKey), proceed to validation" -Verbose
                            $WaitForSignal=$false
                            Continue;
                        }
                        $PROVTOOL=(Get-Process -Name provtool -ErrorAction SilentlyContinue)
                        if ($null -eq $PROVTOOL) {
                            WriteLog -Message "PROVTOOL is now closed, proceed to validation" -Verbose
                            $WaitForSignal=$false
                            Continue;
                        }
                        if ([Math]::round($clock.Elapsed.TotalMinutes) -ge $SetTimeout) {
                            if ($WaitForSignal) {
                                WriteLog -Message "Timeout reached and can't complete $($ppkg.Name) installation" -MessageType Error -Verbose
                                Update-JobStatus $jobfile $json $json.JOBREQUEST.InstallPPKG "fail" "Timeout reached and can't complete $($ppkg.Name) installation" 
                                $global:MessageResults="Timeout reached and can't complete $($ppkg.Name) installation"
                                $global:CodeResults=100
                                Out-Windows          
                            }              
                        }
                        
                        if (([math]::Ceiling($clock.Elapsed.TotalSeconds) % 300) -eq 0) {
                            Write-Host "[$(Get-Date -Format 'MM/dd/yyyy HH:mm:ss')] Waiting to complete instalation $($ppkg.Name)"
                        }
                        if (([math]::Ceiling($clock.Elapsed.TotalSeconds) % 240) -eq 0) {
                            if (Test-Path $RegPath) {
                                if ($null -eq $SearchKey) {
                                    Write-Host "[$(Get-Date -Format 'MM/dd/yyyy HH:mm:ss')] Registry path detected but key, waiting for completion $($ppkg.Name)"
                                    Get-Item -Path $RegPath | Out-Host
                                } else {
                                    Write-Host "[$(Get-Date -Format 'MM/dd/yyyy HH:mm:ss')] Registry path and key [$($SearchKey)] detected, ready to validate $($ppkg.Name)"
                                    Get-Item -Path $RegPath | Out-Host
                                    $WaitForSignal=$false
                                }                                
                            } else {
                                Write-Host "[$(Get-Date -Format 'MM/dd/yyyy HH:mm:ss')] Registry path is not present, waiting for completion $($ppkg.Name)"
                            }
                            
                        }
                        if (([math]::Ceiling($clock.Elapsed.TotalSeconds) % 360) -eq 0) {
                            if ($null -ne $PROVTOOL) {
                                Write-Host "[$(Get-Date -Format 'MM/dd/yyyy HH:mm:ss')] PROVTOOL still running, waiting for completion $($ppkg.Name)"
                                Get-Process -Name provtool -ErrorAction SilentlyContinue | Out-Host
                            } else {
                                Write-Host "[$(Get-Date -Format 'MM/dd/yyyy HH:mm:ss')] PROVTOOL is not detected, ready for validate $($ppkg.Name)"
                                $WaitForSignal=$false
                            }                            
                        }
                        Start-Sleep -Seconds 1
                    }                 
                    
                }
            }
            WriteLog -Message "Start validation, checking registry key value" -Verbose
            $SearchKey=(Get-ItemProperty $RegPath -Name $RegKey -ErrorAction SilentlyContinue).$RegKey
            if ($null -ne $SearchKey) {
                WriteLog -Message "Registry key detected checking value [$($SearchKey)]" -Verbose
                switch ($SearchKey.ToLower()) {
                    "installed" { 
                        WriteLog -Message "PPKG was installed successfully" -Verbose
                        Break;
                    }
                    "failed" {
                        $failppkg=$true
                        WriteLog -Message "PPKG return an error, not fully installed flag[$($failppkg)]" -MessageType Error -Verbose
                        Break;
                    }
                    Default {
                        $failppkg=$true
                        WriteLog -Message "Not expected this result: $($SearchKey)" -Verbose
                        Break;
                    }
                }
            } else {
                WriteLog -Message "There are no registry, checking PROVTOL again...." -Verbose
                if ($null -ne (Get-Process -Name provtool -ErrorAction SilentlyContinue)) {
                    WriteLog -Message "PROVTOOL is still running, not expected scenario at this point" -MessageType Error -Verbose                    
                } 
                $failppkg=$true
            }                       
        }
        WriteLog -Message "Get current PPKGs installed..." -Verbose
        Get-ProvisioningPackage | Select-Object -Property * | Out-Host
        #Validation
        if ($failppkg) {
            WriteLog -Message "PPKG installation failed, check logs" -MessageType Error -Verbose
            Update-JobStatus $jobfile $json $json.JOBREQUEST.InstallPPKG "fail" "PPKG installation Failed, check logs" 
            $global:MessageResults="PPKG installation failed, check logs of PPKG" 
            $global:CodeResults=100
            Out-Windows
        }
        $AfterPPKG=Get-ProvisioningPackage
        if ($null -eq $ActualPPKG) {
            WriteLog -Message "No previous Provisioned packages installed" -Verbose
        } else {
            WriteLog -Message "Previous provisioned package report can be found at logs: PPKG_Pre.log" -Verbose
            $ActualPPKG | Out-File -FilePath (Join-Path $logs "PPKG_Pre.log") -Encoding ascii -Force
        }
        if ($null -eq $AfterPPKG) {
            WriteLog -Message "There are no current Provisioned packages installed" -Message Error -Verbose
            Update-JobStatus $jobfile $json $json.JOBREQUEST.InstallPPKG "fail" "There are no current Provisioned packages installed"
            $global:MessageResults="There are no current Provisioned packages installed"
            $global:CodeResults=500
            Out-Windows
        } else {
            WriteLog -Message "Post provisioned package report can be found at logs: PPKG_Pos.log" -Verbose
            $AfterPPKG | Out-File -FilePath (Join-Path $logs "PPKG_Pos.log") -Encoding ascii -Force
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
                    if ($RemovePackage) {
                        #Remove ppkg to not affect in case of generalize sysprep
                        if ($null -ne $ProvisionedPackage) {
                            WriteLog -Message "Removing ""$($package.PackageName)"" package to prevent reinstalling on system reset" -Verbose
                            WriteLog -Message "     Package path: ""$($package.PackagePath)""" -Verbose
                            WriteLog -Message "       Package ID: $($package.PackageID)" -Verbose
                            WriteLog -Message "Package Installed: $($package.IsInstalled)" -Verbose
                            $ProvisionedPackage | Remove-ProvisioningPackage -Verbose | Out-Host
                        } 
                    } else {
                        if ($null -ne $ProvisionedPackage) {
                            WriteLog -Message " Detected package: ""$($package.PackageName)""" -Verbose
                            WriteLog -Message "     Package path: ""$($package.PackagePath)""" -Verbose
                            WriteLog -Message "       Package ID: $($package.PackageID)" -Verbose
                            WriteLog -Message "Package Installed: $($package.IsInstalled)" -Verbose
                        } 
                    }
                }
            } else {
                WriteLog -Message "Installation complete There are no new provisioned packages detected on this unit" -MessageType Error -Verbose
                foreach ($ppkg in $AfterPPKG) {
                    WriteLog -Message "Detected package name: $($ppkg.PackageName)" -Verbose
                    WriteLog -Message "         package path: $($ppkg.PackagePath)" -Verbose
                    WriteLog -Message "           package ID: $($ppkg.PackageID)" -Verbose
                    WriteLog -Message "    package Installed: $($ppkg.IsInstalled)" -Verbose
                }
                Update-JobStatus $jobfile $json $json.JOBREQUEST.InstallPPKG "fail" "There are no new Provisioned packages installed"
                $global:MessageResults="There are no new Provisioned packages installed"
                $global:CodeResults=500
                Out-Windows
            }
        } elseif (($null -eq $ActualPPKG) -AND ($null -ne $AfterPPKG)) {
            foreach ($ppkg in $AfterPPKG) {
                if ($RemovePackage) {
                    WriteLog -Message "Removing package name: $($ppkg.PackageName)" -Verbose
                    WriteLog -Message "         package path: $($ppkg.PackagePath)" -Verbose
                    WriteLog -Message "           package ID: $($ppkg.PackageID)" -Verbose
                    WriteLog -Message "    package Installed: $($ppkg.IsInstalled)" -Verbose
                    $ppkg | Remove-ProvisioningPackage -Verbose | Out-Host
                } else {
                    WriteLog -Message "Detected package name: $($ppkg.PackageName)" -Verbose
                    WriteLog -Message "         package path: $($ppkg.PackagePath)" -Verbose
                    WriteLog -Message "           package ID: $($ppkg.PackageID)" -Verbose
                    WriteLog -Message "    package Installed: $($ppkg.IsInstalled)" -Verbose
                }
            }            
        }
        $SearchSysprep=(Get-ItemProperty $RegPath -Name $RegSysprep -ErrorAction SilentlyContinue).$RegSysprep
        if (($null -ne $SearchSysprep) -AND ($SearchSysprep.ToLower() -eq "false")) {
            WriteLog -Message "It was detected Registry key for Generalize option and request to NOT generalize [$($SearchSysprep)], not possible to deliver an image without sysprep, please check if PPSolution could help on this request" -MessageType Error -Verbose
            Update-JobStatus $jobfile $json $json.JOBREQUEST.InstallPPKG "fail" "After install PPKG it was detected $($RegSysprep) as $($SearchSysprep), build image doesn't support"
            $global:MessageResults="After install PPKG it was detected $($RegSysprep) as $($SearchSysprep), built image doesn't support"
            $global:CodeResults=600
            Out-Windows
        }
        foreach ($xml in (Get-ChildItem -Path (Join-Path $Env:SystemDrive "\Windows\System32\Sysprep") -Filter "*.xml" -ErrorAction SilentlyContinue)) {
            WriteLog -Message "Found unattend file: $($xml.FullName)" -Verbose
        }
        foreach ($xml in (Get-ChildItem -Path (Join-Path $Env:SystemDrive "\Windows\Panther\Unattend") -Filter "*.xml" -ErrorAction SilentlyContinue)) {
            WriteLog -Message "Found unattend file: $($xml.FullName)" -Verbose
        }
        WriteLog -Message "Successfully installation of PPKGs, removing source path" -Verbose
        Remove-Item -Path $PPKGSource -Force -Recurse -ErrorAction SilentlyContinue
        Update-JobStatus $jobfile $json $json.JOBREQUEST.InstallPPKG "pass" "PPKG was successfully installed"
    } elseif (($null -ne $json.JOBREQUEST.InstallPPKG.status) -AND ($json.JOBREQUEST.InstallPPKG.status.ToLower() -eq "pass")) {
        WriteLog -Message "This module was already processed" -Verbose
    } elseif (($null -ne $json.JOBREQUEST.InstallPPKG.status) -AND ($json.JOBREQUEST.InstallPPKG.status.ToLower() -eq "fail")) { 
        WriteLog -Message "This module was already processed, but error detected. Abort process" -MessageType Error -Verbose
        Update-JobStatus $jobfile $json $json.JOBREQUEST.InstallPPKG "fail" "previous failure detected"
        $global:MessageResults="Previous failure detected"
        $global:CodeResults=905
        Out-Windows
    } else {
        WriteLog -Message "Not expected status ""$($json.JOBREQUEST.InstallPPKG.status)"" for this module" -MessageType Warning -Verbose
    }
} else {
    WriteLog -Message "This module is not required" -Verbose
}