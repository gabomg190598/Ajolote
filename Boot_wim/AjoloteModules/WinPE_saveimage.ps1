if (($null -ne $json.JOBREQUEST.Control) -OR ($null -ne $json.JOBREQUEST.Job)) { 
    if (($json.JOBREQUEST.Control.status -eq "save") -OR ($json.JOBREQUEST.Job.status -eq "save")) {
        WriteLog -Message "Image is ready to be Saved" -Verbose
        $MaximumWinREsizeMB=600;
        <# According to Microsoft documentation, WinRe partition should have at least 200Mb of free sapce, 
           considering only winre.wim and curret CRI partition scheme, maximum size of wim should be 800 - 200 = 600
           https://learn.microsoft.com/en-us/troubleshoot/windows-client/windows-security/disk-partition-requirement-use-windows-re-tool
        #>
        #Clean unecesary files if exists
        if (Test-Path -Path "$($OSDrive)\System.sav\util" -PathType Container) {
            WriteLog -Message "Remove util folder" -Verbose
            $DelUpdates = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($OSDrive)\System.sav\util" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\DeleteUtil.log" 
            if ($DelUpdates -ne 0) {
                $global:MessageResults="It was not possible remove Util folder from OS drive"
                $global:CodeResults=$DelUpdates
                if ($null -ne $json.JOBREQUEST.Job) { 
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.Job "fail" $global:MessageResults
                } elseif ($null -ne $json.JOBREQUEST.Control) {
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.Control "fail" $global:MessageResults
                }  
                Out-WinPE -Backuplogs -RemoveJob
            }
        }
        
        if (($null -ne $json.JOBREQUEST.RemoveDirSWSETUP) -AND ($json.JOBREQUEST.RemoveDirSWSETUP)) { 
            if (($null -ne $json.JOBREQUEST.HPIA) -AND ($json.JOBREQUEST.HPIA)) {
                WriteLog -Message "Module HP Image Assistant was detected and require SWSETUP folder, it cannot be removed as part of SaveImage, please check configuration" -Verbose
                $global:MessageResults="Module HP Image Assistant was detected and require SWSETUP folder, it cannot be removed as part of SaveImage, please check configuration"
                $global:CodeResults=484
                if ($null -ne $json.JOBREQUEST.Job) { 
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.Job "fail" $global:MessageResults
                } elseif ($null -ne $json.JOBREQUEST.Control) {
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.Control "fail" $global:MessageResults
                }  
                Out-WinPE -Backuplogs -RemoveJob
            }
            if ( ($null -ne $json.JOBREQUEST.HPDiagnosticWindows) -OR ($null -ne $json.JOBREQUEST.HPSureView) ){
                WriteLog -Message "Module HP PC DIAGNOSTICS WINDOWS was detected and require SWSETUP folder, it cannot be removed as part of SaveImage, please check configuration" -Verbose
                $global:MessageResults="Module HP PC DIAGNOSTICS WINDOWS was detected and require SWSETUP folder, it cannot be removed as part of SaveImage, please check configuration"
                $global:CodeResults=484
                if ($null -ne $json.JOBREQUEST.Job) { 
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.Job "fail" $global:MessageResults
                } elseif ($null -ne $json.JOBREQUEST.Control) {
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.Control "fail" $global:MessageResults
                }  
                Out-WinPE -Backuplogs -RemoveJob
            }            
            if (Test-Path -Path "$($OSDrive)\SWSETUP" -PathType Container) {
                WriteLog -Message "Removing SWSETUP folder" -Verbose
                $DelSWSETUP = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($OSDrive)\SWSETUP" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\DeleteSWSETUP.log" 
                if ($DelSWSETUP -ne 0) {
                    $global:MessageResults="It was not possible remove SWSETUP folder from OS drive"
                    $global:CodeResults=$DelSWSETUP
                    if ($null -ne $json.JOBREQUEST.Job) { 
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.Job "fail" $global:MessageResults
                    } elseif ($null -ne $json.JOBREQUEST.Control) {
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.Control "fail" $global:MessageResults
                    }  
                    Out-WinPE -Backuplogs -RemoveJob
                }
            }
        } else {
            WriteLog -Message "Remove entire SWSETUP folder was not requested on JOB, keep folder" -Verbose
        }

        if (Test-Path -Path "$($OSDrive)\SWSETUP\APP" -PathType Container) {
            WriteLog -Message "Removing  SWSETUP\APP" -Verbose
            $DelUpdates = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($OSDrive)\SWSETUP\APP" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\DeleteAPPfolder.log" 
            if ($DelUpdates -ne 0) {
                $global:MessageResults="It was not possible remove SWSETUP\APP folder from OS drive"
                $global:CodeResults=$DelUpdates
                if ($null -ne $json.JOBREQUEST.Job) { 
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.Job "fail" $global:MessageResults
                } elseif ($null -ne $json.JOBREQUEST.Control) {
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.Control "fail" $global:MessageResults
                }  
                Out-WinPE -Backuplogs -RemoveJob
            }
        }
        if (Test-Path -Path "$($OSDrive)\tmp" -PathType Container) {
            WriteLog -Message "Remove tmp folder" -Verbose
            $DelUpdates = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($OSDrive)\tmp" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\DeleteTMP.log" 
            if ($DelUpdates -ne 0) {
                $global:MessageResults="It was not possible remove TMP folder from OS drive"
                $global:CodeResults=$DelUpdates
                if ($null -ne $json.JOBREQUEST.Job) { 
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.Job "fail" $global:MessageResults
                } elseif ($null -ne $json.JOBREQUEST.Control) {
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.Control "fail" $global:MessageResults
                }  
                Out-WinPE -Backuplogs -RemoveJob
            }
        }

        #Validate if WinRE exists
        if (!(Test-Path -Path "$($OSDrive)\Windows\System32\Recovery\Winre.wim" -PathType Leaf)) {
            WriteLog -Message "This image has not prepared for Windows Recovery process, missing Winre.wim" -MessageType Error -Verbose
            $global:MessageResults="This image has not prepared for Windows Recovery process, missing Winre.wim"
            $global:CodeResults=404
            if ($null -ne $json.JOBREQUEST.Job) { 
                Update-JobStatus $jobfile $json $json.JOBREQUEST.Job "fail" $global:MessageResults
            } elseif ($null -ne $json.JOBREQUEST.Control) {
                Update-JobStatus $jobfile $json $json.JOBREQUEST.Control "fail" $global:MessageResults
            }  
            Out-WinPE -Backuplogs -RemoveJob
        } else {
            $WinRESize=[string]::Format("{0:0.00} MB",(Get-Item -Path "$($OSDrive)\Windows\System32\Recovery\Winre.wim" -Force).Length/1MB)
            WriteLog -Message "WinRE.wim was detected correctly and size is $($WinRESize)" -Verbose
            if ($null -ne $json.JOBREQUEST.Control) {
                if ($null -eq $json.JOBREQUEST.Control.WinREsize) {
                    $json.JOBREQUEST.Control | Add-Member -Name "WinREsize" -MemberType NoteProperty -Value $WinRESize
                } else {
                    $json.JOBREQUEST.Control.WinREsize=$WinRESize
                } 
            } elseif ($null -ne $json.JOBREQUEST.Job) {
                if ($null -eq $json.JOBREQUEST.Job.WinREsize) {
                    $json.JOBREQUEST.Job | Add-Member -Name "WinREsize" -MemberType NoteProperty -Value $WinRESize
                } else {
                    $json.JOBREQUEST.Job.WinREsize=$WinRESize
                }
            }
            ### Save JOB file
            try {
                $json | ConvertTo-Json -Depth 16 | Out-File -FilePath $jobfile -Encoding ascii -Force
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                WriteLog -Message "Failed updating JOB file: $($ErrorMessage)" -MessageType Error -Verbose
                $global:MessageResults="Failed updating JOB file: $($ErrorMessage)"
                $global:CodeResults=209
                Out-WinPE -Backuplogs
            }
            if ([math]::round((Get-Item -Path "$($OSDrive)\Windows\System32\Recovery\Winre.wim" -Force).Length/1MB,0) -gt $MaximumWinREsizeMB) {
                WriteLog -Message "WinRE.wim SIZE EXCEED EXPECTED SIZE of $($MaximumWinREsizeMB)Mb, PLEASE REVIEW IT" -MessageType Warning -Verbose
                Write-Host "WinRE.wim SIZE EXCEED $($MaximumWinREsizeMB)Mb SIZE, PLEASE REVIEW IT" -BackgroundColor Yellow -ForegroundColor Red
                if (-Not(Test-Path (Join-Path $OSDrive "\System.sav\flags"))) { New-Item -Path (Join-Path $OSDrive "\System.sav\flags") -ItemType Directory -Force }
                "$([math]::round((Get-Item -Path "$($OSDrive)\Windows\System32\Recovery\Winre.wim" -Force).Length/1MB,0))" | Out-File -FilePath (Join-Path $OSDrive "\System.sav\flags\WinRE_BIGGER_SIZE.flg") -Encoding ascii -Force -NoNewline
                start-sleep -seconds 5
            }
        }
        #Check if need PPSolution folder
        if ($null -ne $json.JOBREQUEST.AddPPSolution) { 
            if ($json.JOBREQUEST.AddPPSolution){
                WriteLog -Message "PPSolution folder is requested, check if exist" -Verbose
                #Copy PPSolution
                if (Test-Path "$($AjoloteDrive)\PPSOLUTION") {
                    WriteLog -Message "Copyng PPSolution folder" -Verbose
                    $intCopyPPSolution = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /sehiy ""$($AjoloteDrive)\PPSOLUTION\*"" $($OSDrive)\" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\CopyPPSolution.log"
                    if ($intCopyPPSolution -ne 0) {
                        WriteLog -Message "Not possible copy PPSolution to local partition" -MessageType Error -Verbose
                        $global:MessageResults="Not possible copy PPSolution to local partition"
                        $global:CodeResults=$intCopyPPSolution
                        if ($null -ne $json.JOBREQUEST.Job) { 
                            Update-JobStatus $jobfile $json $json.JOBREQUEST.Job "fail" $global:MessageResults
                        } elseif ($null -ne $json.JOBREQUEST.Control) {
                            Update-JobStatus $jobfile $json $json.JOBREQUEST.Control "fail" $global:MessageResults
                        }  
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                    #Adding REBOOT.ME flag
                    if ($json.JOBREQUEST.RebootFlag){ 
                        WriteLog -Message "REBOOT.ME flag is requested and PPSolution was added, creating PostProcessing flag" -Verbose
                        "FS REBOOT FLAG FOR POST PROCESSING" | Out-File -FilePath (Join-Path $OSDrive "\system.sav\REBOOT.ME") -Encoding ascii -Force -NoNewline
                        if (Test-Path -Path (Join-Path $OSDrive "\system.sav\REBOOT.ME") -PathType Leaf ) {
                            WriteLog -Message "REBOOT.ME flag has been created: $((Join-Path $OSDrive "\system.sav\REBOOT.ME"))" -Verbose
                        }
                    }
                    #Adding custom PPSolution flags
                    if ($null -ne $json.JOBREQUEST.AddPPSolutionFlags) { 
                        [string[]]$PPSolutionFlags=$json.JOBREQUEST.AddPPSolutionFlags
                        if (-Not(Test-Path (Join-Path $OSDrive "\System.sav\flags"))) { New-Item -Path (Join-Path $OSDrive "\System.sav\flags") -ItemType Directory -Force }
                        foreach ($flag in $PPSolutionFlags) {
                            WriteLog -Message "Creating PPSolution flag: $($flag)" -Verbose
                            "FS Flag" | Out-File -FilePath (Join-Path $OSDrive "\System.sav\flags\$($flag)") -Encoding ascii -Force -NoNewline
                        }
                    }
                } else {
                    WriteLog -Message "PPSOLUTION folder was not found" -MessageType Error -Verbose
                    $global:MessageResults="PPSOLUTION folder was not found"
                    $global:CodeResults=404
                    if ($null -ne $json.JOBREQUEST.Job) { 
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.Job "fail" $global:MessageResults
                    } elseif ($null -ne $json.JOBREQUEST.Control) {
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.Control "fail" $global:MessageResults
                    }  
                    Out-WinPE -Backuplogs -RemoveJob
                }
            } else {
                WriteLog -Message "PPSolution folder is NOT required" -Verbose
                #Adding REBOOT.ME flag
                if ($json.JOBREQUEST.RebootFlag){ 
                    WriteLog -Message "REBOOT.ME flag is requested but PPSolution, reporting issue on coniguration file" -Verbose
                    $global:MessageResults="Not possible add REBOOT.ME flag when PPSOLUTION is not required"
                    $global:CodeResults=405
                    if ($null -ne $json.JOBREQUEST.Job) { 
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.Job "fail" $global:MessageResults
                    } elseif ($null -ne $json.JOBREQUEST.Control) {
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.Control "fail" $global:MessageResults
                    }  
                    Out-WinPE -Backuplogs -RemoveJob
                }
            }
        }
        ###################################################################################################
        #Prevent TCO it's installed as part of postprocessing
        ###################################################################################################
        if (($null -ne $json.JOBREQUEST.PreventTCO) -AND ($json.JOBREQUEST.PreventTCO)) { 
            WriteLog -Message "It is required to prevent TCO installed on image, remove from PPSolution" -Verbose
            #Flag detection its emplemented on PPSolution 2.0
            "Remove TCO" | Out-File -FilePath (Join-Path $OSDrive "\System.sav\flags\PreventTCO.flg") -Encoding ascii -Force
            #Search for TCO instaler folder
            WriteLog -Message "Detecting PPSolution version" -Verbose
            if (Test-Path (Join-Path  $OSDrive "\system.sav\CSImage")) {
                WriteLog -Message "Detected PPSolution 1.0" -Verbose
                $TCOInstallPath=(Join-Path  $OSDrive "\System.sav\CSImage\Config\TCO")
            } elseif (Test-Path (Join-Path  $OSDrive "\System.sav\FSPostProc")) {
                WriteLog -Message "Detected PPSolution 2.0" -Verbose
                $TCOInstallPath=(Join-Path  $OSDrive "\System.sav\FSPostProc\Config\TCO")
            } else {
                WriteLog -Message "Not detected PPSolution" -Verbose
                $TCOInstallPath=$null
            }
            if ($null -eq $TCOInstallPath) {
                WriteLog -Message "No PPSolution folder detected, Proceed" -Verbose
            } else {
                if (Test-Path -Path $TCOInstallPath -PathType Container) {
                    WriteLog -Message "TCO folder detected, removing" -Verbose
                    $DelTCO = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($TCOInstallPath)" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\DeleteTCO.log" 
                    if ($DelTCO -ne 0) {
                        $global:MessageResults="It was not possible remove TCO folder from PPSolution"
                        $global:CodeResults=$DelTCO
                        if ($null -ne $json.JOBREQUEST.Job) { 
                            Update-JobStatus $jobfile $json $json.JOBREQUEST.Job "fail" $global:MessageResults
                        } elseif ($null -ne $json.JOBREQUEST.Control) {
                            Update-JobStatus $jobfile $json $json.JOBREQUEST.Control "fail" $global:MessageResults
                        }  
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                } else {
                    WriteLog -Message "TCO was not detected at: $((Join-Path (Join-Path (Join-Path (Join-Path  $OSDrive "system.sav") "CSImage") "Config") "TCO")), skip for now" -MessageType Warning -Verbose
                }
            }
            
        } elseif ((($null -ne $json.JOBREQUEST.AddPPSolution) -and (-Not($json.JOBREQUEST.AddPPSolution))) -AND ((($null -ne $json.JOBREQUEST.PreventTCO) -AND (-Not($json.JOBREQUEST.PreventTCO))))) { 
            #############################################################################
            #PPSolution is not requested, but TCO
            #############################################################################
            $TCOSource=$null
            if (Test-Path (Join-Path $AjoloteDrive "\PPSOLUTION\system.sav\CSImage")) {
                $TCOSource=(Join-Path $AjoloteDrive "\PPSOLUTION\system.sav\CSImage\Config\TCO")
            } elseif (Test-Path (Join-Path $AjoloteDrive "\PPSOLUTION\system.sav\FSPostProc")) {
                $TCOSource=(Join-Path $AjoloteDrive "\PPSOLUTION\system.sav\FSPostProc\Config\TCO")
            }

            if ($null -ne $TCOSource) {
                $intCopyTCO = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /sehiy ""$($TCOSource)\*"" $($OSDrive)\" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\CopyTCO.log"
                if ($intCopyTCO -ne 0) {
                    WriteLog -Message "Not possible copy PPSolution to local partition" -MessageType Error -Verbose
                    $global:MessageResults="Not possible copy PPSolution to local partition"
                    $global:CodeResults=$intCopyTCO
                    if ($null -ne $json.JOBREQUEST.Job) { 
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.Job "fail" $global:MessageResults
                    } elseif ($null -ne $json.JOBREQUEST.Control) {
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.Control "fail" $global:MessageResults
                    }  
                    Out-WinPE -Backuplogs -RemoveJob
                }
            } else {
                WriteLog -Message "It was not possible to detect TCO source path" -MessageType Error -Verbose
                $global:MessageResults="It was not possible to detect TCO source path"
                $global:CodeResults=404
                if ($null -ne $json.JOBREQUEST.Job) { 
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.Job "fail" $global:MessageResults
                } elseif ($null -ne $json.JOBREQUEST.Control) {
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.Control "fail" $global:MessageResults
                }  
                Out-WinPE -Backuplogs -RemoveJob
            }

            
        }
        
        #Adding WIMs info
        Get-ChildItem -Path (Join-Path $AjoloteDrive "WIMS") -Filter "*.xml" -File | ForEach-Object { Copy-Item -Path $_.FullName -Destination (Join-Path $logs $_.Name) -Force }

        #In case that preventsetup is enabled it require to run hpcomplete on first boot
        if (($null -ne $json.JOBREQUEST.Drivers.preventsetup) -AND ($json.JOBREQUEST.Drivers.preventsetup)) {
            WriteLog -Message "Prevent Setup was detected on current Job, check options" -Verbose
            #this scenario has 2 options: use PPSolution or RunOnce
            if (($null -ne $json.JOBREQUEST.AddPPSolution) -AND ($json.JOBREQUEST.AddPPSolution)) {
                WriteLog -Message "It is required to use PPSolution, setup will use that option, no changes are required" -Verbose
            } else {
                #Validate HPComplete.exe exist
                if (-Not(Test-Path -Path "$($OSDrive)\Windows\Setup\Scripts\HPComplete.exe" -PathType Leaf)) {
                    WriteLog -Message "It was not detected HPComplete.exe, copying from Ajolote drive" -Verbose
                    Copy-Item -Path "$($AjoloteDrive)\AUDIT\Windows\Setup\Scripts\HPComplete.exe" -Destination "$($OSDrive)\Windows\Setup\Scripts\HPComplete.exe" -Force
                }
                #Validate that HPDrivers exist
                if (-Not(Test-Path -Path "$($OSDrive)\HPDrivers")) {
                    WriteLog -Message "Somentig was wrong, there not exist $($OSDrive)\HPDrivers" -MessageType Error -Verbose
                    $global:MessageResults="Somentig was wrong, there not exist $($OSDrive)\HPDrivers"
                    $global:CodeResults=-1
                    Out-WinPE -Backuplogs -RemoveJob
                }
                #Move XML to Scripts folder
                Get-ChildItem -Path "$($OSDrive)\HPDrivers" -File -Filter "*.xml" | ForEach-Object {Copy-Item -Path $_.FullName -Destination "$($OSDrive)\Windows\Setup\Scripts\$($_.Name)" -Force }

                #Mount Registry
                $null = Invoke-RunPower -File "cmd.exe" -Params "/c reg load  HKLM\HPImg $($OSDrive)\Windows\System32\Config\SOFTWARE" -WorkDir $PSScriptRoot -OutFile "$($logs)\MountReg.log"
                ##Check if path exist
                if (-Not(Test-Path 'HKLM:\HPImg\Microsoft\Windows\CurrentVersion\RunOnce')) {
                    New-Item -Path 'HKLM:\HPImg\Microsoft\Windows\CurrentVersion\RunOnce' -ItemType Directory -Force | Out-Host
                }
                #Add Registry to RunOnce
                New-ItemProperty -Path 'HKLM:\HPImg\Microsoft\Windows\CurrentVersion\RunOnce' -Name "!HPComplete" -PropertyType String -Value "C:\Windows\Setup\Scripts\HPComplete.exe /hide" -Force

                #Unmount registry        
                $maxretry=10
                $retrycount=0
                $SuccessUnmount=$false
                [gc]::Collect()
                Start-Sleep 2
                While (!($SuccessUnmount)) {
                    $retrycount++
                    $UnMountReg = Invoke-RunPower -File "cmd.exe" -Params "/c reg unload HKLM\HPImg" -WorkDir $PSScriptRoot -OutFile "$($logs)\UnMountReg.log";
                    if ($UnMountReg -ne 0) { 
                        WriteLog -Message "Not successfully unmount registry[$($UnMountReg)], start sleep 6 secs and try again" -MessageType Warning -Verbose;
                        Start-Sleep -Seconds 6
                    } else {
                        $SuccessUnmount=$true
                        WriteLog -Message "Successfully unmounted registry" -Verbose
                    }
                    if ($retrycount -gt $maxretry) {
                        WriteLog -Message "Not successfully unmount registry[$($UnMountReg) after several retries" -MessageType Error -Verbose;
                        $global:MessageResults="Not successfully unmount registry[$($UnMountReg) after several retries, PreventSetup in SaveImage"
                        $global:CodeResults=-1
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                }
            }
            
        }
        #Create image info file
        WriteLog -Message "Creating CSUP.txt file..." -Verbose
        get-date -Format "MM-dd-yyyy" | Out-file -FilePath "$($OSDrive)\Windows\csup.txt" -Encoding ascii -Force
        
        #remove some temporal folder created when InboxApps are reinstalled
        #reinstall post appx files
        if (-Not([string]::IsNullOrEmpty($json.JOBREQUEST.Localization.defaultlanguage)) -AND ($json.JOBREQUEST.Localization.defaultlanguage.Trim().ToLower() -ne 'en-us')) { 
            if (Test-Path -Path (Join-Path $OSDrive "\system.sav\appxpackages")) {
                $GetPostAppxs = (Get-ChildItem -Path (Join-Path $OSDrive "\system.sav\appxpackages") -File)
                if ($null -ne $GetPostAppxs) {
                    foreach ($appx in $GetPostAppxs) {
                        WriteLog -Message "Post Install package file: $($appx.Name)" -Verbose
                        $ReinstallInboxApp = RunDism -Params "/image:$($OSDrive)\ /ScratchDir:$($OSDrive)\ /Add-ProvisionedAppxPackage /PackagePath:""$($appx.FullName)"" /SkipLicense /Region:""all""" -WorkDir $PSScriptRoot -OutFile "$($Logs)\DismPostinstallAppx.log"
                        if ($ReinstallInboxApp -ne 0) { 
                            WriteLog -Message "Failed to Post Reinstall Inbox Package: $($appx.Name), code: $($ReinstallInboxApp), stop process to review" -MessageType Error -Verbose;
                            $global:MessageResults="Failed to Post Reinstall Inbox Package: $($appx.Name), code: $($ReinstallInboxApp), stop process to review"
                            $global:CodeResults=$ReinstallInboxApp
                            Copy-Item -Path "X:\windows\Logs\DISM\dism.log" -Destination (Join-Path $Logs "Dism.log") -Force
                            Out-WinPE -Backuplogs -RemoveJob
                        } else {
                            WriteLog -Message "`tSuccessfully installed: $($appx.Name)" -Verbose
                        }
                    }
                } else {
                    WriteLog -Message "No files located for post appx reinstall"
                }
                Remove-Item -Path (Join-Path $OSDrive "\system.sav\appxpackages") -Recurse -Force
            }
            Get-ChildItem -Path "$($OSDrive)\" -Directory -Filter "appxStage-*" | ForEach-Object {
                WriteLog -Message "Removing temporal folder: $($_.FullName)" -Verbose
                $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q ""$($_.FullName)""" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\DeleteInApFolder.log" 
            }
        }

        #Get list of files or directories on root
        Get-ChildItem -Path "$($OSDrive)\" -Attributes D,H,R,S | Out-File -FilePath (Join-Path $logs "ContentOfC.log") -Encoding ascii -Force

        #Clean Up the WinSxS Folder and cleanup image
        $null=RunDism -Params "/Image:$($OSDrive)\ /Cleanup-Image /StartComponentCleanup /ScratchDir:$($OSDrive)\" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\CleaunpImageWIM.log"
        #Save Image
        if (-Not([string]::IsNullOrEmpty($json.JOBREQUEST.WIMName))) {
            $strNameWim="$($json.JOBREQUEST.WIMName.ToString().Replace("" "",""_"")).wim"
            $strNamesha="$($json.JOBREQUEST.WIMName.ToString().Replace("" "",""_"")).sha256"
        } else {
            $strNameWim="hpfactory_$($OS.Build.ToString().Replace("" "","""")).$($OS.Revision.ToString().Replace("" "",""""))$($NameCodes).wim"
            $strNamesha="hpfactory_$($OS.Build.ToString().Replace("" "","""")).$($OS.Revision.ToString().Replace("" "",""""))$($NameCodes).sha256"
        }        
        $strDescription="HP FS Corporate Ready Image $($OS.Name) Build Ver.$($WinVersion).$($OS.Revision) - $(Get-Date -Format ""MM-dd-yyyy"")"
        WriteLog -Message "Saving Image: $($OSDrive)\$($strNameWim)" -Verbose
        $SaveImage = RunDism -Params "/Capture-Image /ImageFile:$($OSDrive)\$($strNameWim) /ScratchDir:$($OSDrive)\ /CaptureDir:$($OSDrive)\ /Name:$($WinVersion) /Description:""$($strDescription)"" /verify" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\CaptureWIM.log"
        if ($SaveImage -ne 0) {
            WriteLog -Message "Error Capturing Image" -MessageType Error -Verbose
            $global:MessageResults="Error Capturing Image"
            $global:CodeResults=$SaveImage
            if ($null -ne $json.JOBREQUEST.Job) { 
                Update-JobStatus $jobfile $json $json.JOBREQUEST.Job "fail" $global:MessageResults
            } elseif ($null -ne $json.JOBREQUEST.Control) {
                Update-JobStatus $jobfile $json $json.JOBREQUEST.Control "fail" $global:MessageResults
            }  
            Out-WinPE -Backuplogs -RemoveJob
        }
        WriteLog -Message "Image captured successfully: $($OSDrive)\$($strNameWim)" -Verbose
        WriteLog -Message "Calculating image size..." -Verbose 
        $WinPEImageSize=[string]::Format("{0:000,000} bytes",(Get-Item -Path "$($OSDrive)\Windows\System32\Recovery\Winre.wim" -Force).Length)
        $SaveImageSize=[string]::Format("{0:000,000} bytes",(Get-Item -Path (Join-Path $OSDrive $strNameWim) -Force).Length)
        WriteLog -Message "Calculating checksum hash, SHA256 for documentation and SHA1 for FXs..." -Verbose    
        $hash_SHA1=(Get-FileHash -Path "$($OSDrive)\$($strNameWim)" -Algorithm SHA1).Hash
        $hash_SHA256=(Get-FileHash -Path "$($OSDrive)\$($strNameWim)" -Algorithm SHA256).Hash
        "#SAH256" | Out-File -FilePath "$($OSDrive)\$($strNamesha)" -Encoding default -Force
        "$($hash_SHA256) *$($strNameWim)" | Out-File -FilePath "$($OSDrive)\$($strNamesha)" -Encoding default -Append -Force
        "#SAH1" | Out-File -FilePath "$($OSDrive)\$($strNamesha)" -Encoding default -Append -Force
        "$($hash_SHA1) *$($strNameWim)" | Out-File -FilePath "$($OSDrive)\$($strNamesha)" -Encoding default -Append -Force
        WriteLog -Message "    SHA256: $($hash_SHA256)" -Verbose
        WriteLog -Message "      SHA1: $($hash_SHA1)" -Verbose
        WriteLog -Message "Image Size: $($SaveImageSize)" -Verbose
        WriteLog -Message "WinRE Size: $($WinPEImageSize)" -Verbose

        Write-Host "#####################################################################" -ForegroundColor Green -BackgroundColor White
        Write-Host "Image captured successfully: $($OSDrive)\$($strNameWim)" -ForegroundColor Green -BackgroundColor White
        Write-Host "        Checksum calculated: $($OSDrive)\$($strNamesha)" -ForegroundColor Green -BackgroundColor White
        Write-Host "#####################################################################" -ForegroundColor Green -BackgroundColor White

        #Completed successfully
        if ($null -ne $json.JOBREQUEST.Control) {
            if ($null -eq $json.JOBREQUEST.Control.sha256) {
                $json.JOBREQUEST.Control | Add-Member -Name "sha256" -MemberType NoteProperty -Value $hash_SHA256
            } else {
                $json.JOBREQUEST.Control.sha256=$hash_SHA256
            }
            if ($null -eq $json.JOBREQUEST.Control.sha1) {
                $json.JOBREQUEST.Control | Add-Member -Name "sha1" -MemberType NoteProperty -Value $hash_SHA1
            } else {
                $json.JOBREQUEST.Control.sha1=$hash_SHA1
            }
            if ($null -eq $json.JOBREQUEST.Control.filename) {
                $json.JOBREQUEST.Control | Add-Member -Name "filename" -MemberType NoteProperty -Value $strNameWim
            } else {
                $json.JOBREQUEST.Control.filename=$strNameWim
            }
            if ($null -eq $json.JOBREQUEST.Control.imagesize) {
                $json.JOBREQUEST.Control | Add-Member -Name "imagesize" -MemberType NoteProperty -Value $SaveImageSize
            } else {
                $json.JOBREQUEST.Control.imagesize=$SaveImageSize
            }
            ### Save JOB file
            Update-JobStatus $jobfile $json $json.JOBREQUEST.Control "pass" "Image captured successfully"
        } elseif ($null -ne $json.JOBREQUEST.Job) {
            if ($null -eq $json.JOBREQUEST.Job.sha256) {
                $json.JOBREQUEST.Job | Add-Member -Name "sha256" -MemberType NoteProperty -Value $hash_SHA256
            } else {
                $json.JOBREQUEST.Job.sha256=$hash_SHA256
            }
            if ($null -eq $json.JOBREQUEST.Job.sha1) {
                $json.JOBREQUEST.Job | Add-Member -Name "sha1" -MemberType NoteProperty -Value $hash_SHA1
            } else {
                $json.JOBREQUEST.Job.sha1=$hash_SHA1
            }
            if ($null -eq $json.JOBREQUEST.Job.filename) {
                $json.JOBREQUEST.Job | Add-Member -Name "filename" -MemberType NoteProperty -Value $strNameWim
            } else {
                $json.JOBREQUEST.Job.filename=$strNameWim
            }
            if ($null -eq $json.JOBREQUEST.Job.imagesize) {
                $json.JOBREQUEST.Job | Add-Member -Name "imagesize" -MemberType NoteProperty -Value $SaveImageSize
            } else {
                $json.JOBREQUEST.Job.imagesize=$SaveImageSize
            }
            #((New-TimeSpan -Start $getinfo[0].LastWriteTime.ToString("yyyy-M-dd") -End (Get-Date).ToString("yyyy-M-dd")).Days -le $days)
            $currentdate=(Get-Date).ToString("MM-dd-yy HH:mm:ss")
            if ($null -eq $json.JOBREQUEST.Job.enddate) {
                $json.JOBREQUEST.Job | Add-Member -Name "enddate" -MemberType NoteProperty -Value $currentdate
            } else {
                $json.JOBREQUEST.Job.enddate=$currentdate
            }
            Update-JobStatus $jobfile $json $json.JOBREQUEST.Job "pass" "Image captured and copied successfully"
        }

        if ($null -ne $json.JOBREQUEST.Job) {
            if (!([string]::IsNullOrEmpty($json.JOBREQUEST.AV))) {
                $FolderName=$json.JOBREQUEST.AV
            } else {
                $FolderName=$json.JOBREQUEST.Job.namejob.ToString().Replace(" ","_")
            }
            $configfile="$($AjoloteDrive)\config.xml"
            [xml]$config = Get-Content $configfile
            $SharePath="\\$($config.AJOLOTE.servername)$($config.AJOLOTE.imagepath)\$($FolderName)"
            if ($null -eq $json.JOBREQUEST.Job.filepath) {
                $json.JOBREQUEST.Job | Add-Member -Name "filepath" -MemberType NoteProperty -Value $SharePath
            } else {
                $json.JOBREQUEST.Job.filepath=$SharePath
            }
            ### Save JOB file
            try {
                $json | ConvertTo-Json -Depth 16 | Out-File -FilePath $jobfile -Encoding ascii -Force
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                WriteLog -Message "Failed updating JOB file: $($ErrorMessage)" -MessageType Error -Verbose
                $global:MessageResults="Failed updating JOB file: $($ErrorMessage)"
                $global:CodeResults=209
                Out-WinPE -Backuplogs
            }
            $ShareImage=Invoke-MountServer "/imagepath"
            if ($null -ne $ShareImage) {
                if (-Not(Test-Path (Join-Path $ShareImage $FolderName))) {
                    New-Item -Path (Join-Path $ShareImage $FolderName) -ItemType Container -Force | Out-Host
                }
                if (-Not(Test-Path (Join-Path $ShareImage $FolderName))) {
                    WriteLog -Message "Fail creating Images folder to save WIM or SHA256 files" -MessageType Error -Verbose
                    $global:MessageResults="Fail creating Images folder to save WIM or SHA256 files"
                    $global:CodeResults=-2
                    if ($null -ne $json.JOBREQUEST.Job) {                         
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.Job "fail" $global:MessageResults
                    } elseif ($null -ne $json.JOBREQUEST.Control) {
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.Control "fail" $global:MessageResults
                    }  
                    Out-WinPE -Backuplogs -RemoveJob 
                }                
                WriteLog -Message "Copying image file to Server...  $($OSDrive)\$($strNameWim) --> $($ShareImage)\$($FolderName)\" -Verbose 
                $copywim=Copy-Item -Path (Join-Path $OSDrive $strNameWim) -Destination (Join-Path (Join-Path $ShareImage $FolderName) $strNameWim) -Force -PassThru
                $copysha=Copy-Item -Path (Join-Path $OSDrive $strNamesha) -Destination (Join-Path (Join-Path $ShareImage $FolderName) $strNamesha) -Force -PassThru
                if (!($copywim.Exists) -OR (!($copysha.Exists))) {
                    WriteLog -Message "Fail copying WIM or SHA256 files" -MessageType Error -Verbose
                    $global:MessageResults="Fail copying WIM or SHA256 files"
                    $global:CodeResults=-1
                    if ($null -ne $json.JOBREQUEST.Job) {                         
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.Job "fail" $global:MessageResults
                    } elseif ($null -ne $json.JOBREQUEST.Control) {
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.Control "fail" $global:MessageResults
                    }  
                    Out-WinPE -Backuplogs -RemoveJob 
                }
                if (Test-Path -Path (Join-Path $OSDrive "\System.sav\flags\WinRE_BIGGER_SIZE.flg")) {
                    Copy-Item -Path (Join-Path $OSDrive "\System.sav\flags\WinRE_BIGGER_SIZE.flg") -Destination (Join-Path (Join-Path $ShareImage $FolderName) "WinRE_BIGGER_SIZE.flg") -Force
                }
            } else {
                WriteLog -Message "Not possible mount Images share" -MessageType Error -Verbose
                $global:MessageResults="Not possible mount Images share"
                $global:CodeResults=3
                if ($null -ne $json.JOBREQUEST.Job) { 
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.Job "fail" $global:MessageResults
                } elseif ($null -ne $json.JOBREQUEST.Control) {
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.Control "fail" $global:MessageResults
                }  
                Out-WinPE -Backuplogs -RemoveJob                
            }
        }
    } else {
        if ($null -ne $json.JOBREQUEST.Control) {
            WriteLog -Message "No actions required in save image by Control for status $($json.JOBREQUEST.Control.status)" -MessageType Warning -Verbose
        } elseif ($null -ne $json.JOBREQUEST.Job) {
            WriteLog -Message "No actions required in save image by Job for status $($json.JOBREQUEST.Job.status)" -MessageType Warning -Verbose
        }
    }

} else {
    WriteLog -Message "Module not required, continue" -Verbose
}
