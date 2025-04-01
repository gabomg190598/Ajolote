<##############################################################################################################################
WinPE 
Install Microsoft Updates 2.4
Note: this requires kbupdate module 
Last update: February, 20 2025
###############################################################################################################################>

if ($null -ne $json.JOBREQUEST.CheckMSUpdates) { 
    WriteLog -Message "Check MS Updates was requested..." -Verbose
    if (([string]::IsNullOrEmpty($json.JOBREQUEST.CheckMSUpdates.status)) -OR ($json.JOBREQUEST.CheckMSUpdates.status.ToLower() -eq "new")) { 
        WriteLog -Message "Prepare Unit for Install MicrosoftS Updates" -Verbose
        if (-Not(Test-Path (Join-Path $AjoloteDrive "/system.sav/temp"))) { New-Item -Path (Join-Path $AjoloteDrive "/system.sav/temp") -ItemType Directory -Force; }
        $env:TEMP=(Join-Path $AjoloteDrive "/system.sav/temp")
        WriteLog -Message "Set temp folder to $($env:TEMP)" -Verbose
      #---Copy WSUS CAB
        WriteLog -Message "Copying WSUS cab into HDD" -Verbose
        $days=30
        $getinfo = Get-ChildItem -Path "$($AjoloteDrive)\TOOLS" -File -Filter $WSUS_CAB
        WriteLog -Message "$($WSUS_CAB) has $((New-TimeSpan -Start $getinfo[0].LastWriteTime.ToString("yyyy-M-dd") -End (Get-Date).ToString("yyyy-M-dd")).Days) Days" -Verbose 
        if ((New-TimeSpan -Start $getinfo[0].LastWriteTime.ToString("yyyy-M-dd") -End (Get-Date).ToString("yyyy-M-dd")).Days -le $days) {
            WriteLog -Message "Current WSUSCAB was download less than $($days) days, it is safe to use" -Verbose 
        } else {
            WriteLog -Message "It is high recommended to update WSUSCAB and use latest updates" -Messagetype Warning -Verbose
            Write-Host "*************************** *************** ***********************************" -BackgroundColor Yellow -ForegroundColor Red 
            Write-Host "*********************** UPDATE WSUSCAB REQUIRED *******************************" -BackgroundColor Yellow -ForegroundColor Red 
            Write-Host "*************************** *************** ***********************************" -BackgroundColor Yellow -ForegroundColor Red 
            Start-Sleep -Seconds 3
        }
        $CopyWSUS = Copy-Item -Path "$($AjoloteDrive)\TOOLS\$($WSUS_CAB)" -Destination "$($OSDrive)\system.sav\util\MSUpdates\$($WSUS_CAB)" -Force -PassThru
        $CopyMOSVer = Copy-Item -Path "$($AjoloteDrive)\TOOLS\MinimumOSRevision.json" -Destination "$($OSDrive)\system.sav\util\MSUpdates\MinimumOSRevision.json" -Force -PassThru
        if (!(Test-Path $CopyWSUS.FullName)) {
            WriteLog -Message "It was not possible copy wsusscn2.cab to image" -MessageType Error -Verbose
            $global:MessageResults="It was not possible copy wsusscn2.cab to image"
            $global:CodeResults=216
            Update-JobStatus $jobfile $json $json.JOBREQUEST.CheckMSUpdates "fail" $global:MessageResults
            Out-WinPE -Backuplogs -RemoveJob
            $global:CodeResults | Out-Null
        }
        $getkbmodule = Get-ChildItem -Path "$($AjoloteDrive)\TOOLS" -Directory -Filter "kbupdate_*"
        if ($null -eq $getkbmodule) {
            WriteLog -Message "It was not possible locate kbupdate module folder" -MessageType Error -Verbose
            $global:MessageResults="It was not possible locate kbupdate module folder"
            $global:CodeResults=404
            Update-JobStatus $jobfile $json $json.JOBREQUEST.CheckMSUpdates "fail" $global:MessageResults
            Out-WinPE -Backuplogs -RemoveJob
        } 
        WriteLog -Message "Minimum OS version file: $($CopyMOSVer.FullName)" -Verbose
        #move folders directly to PS Modules
        #$null = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /sehiyk ""$($getkbmodule.FullName)\*"" ""$($OSDrive)\Program Files\WindowsPowerShell\Modules\""" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\CopyKBUpdate.log"
        #move for manually import
        $null = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /sehiyk ""$($getkbmodule.FullName)\*"" ""$($OSDrive)\system.sav\util\MSUpdates\kbupdateModule\""" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\CopyKBUpdate.log"
        #create reference file for remove later.
        Get-ChildItem -Path $getkbmodule.FullName -Directory | ConvertTo-Json | Out-File -FilePath "$($OSDrive)\system.sav\util\MSUpdates\kbupdateModuleFolder.json" -Encoding ascii -Force
        #
        #copy nuget
        $null = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /sehiyk ""$($AjoloteDrive)\TOOLS\nuget\*"" ""$($OSDrive)\Program Files\PackageManagement\ProviderAssemblies\""" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\CopyNuget.log"
        Get-ChildItem -Path $getkbmodule.FullName -Directory | ConvertTo-Json | Out-File -FilePath "$($OSDrive)\system.sav\util\MSUpdates\kbupdateModuleFolder.json" -Encoding ascii -Force
        #Copy Files
        if (Test-Path "$($AjoloteDrive)\UPDATES") {
            WriteLog -Message "Moving Updates files into HDD" -Verbose
            $null = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /sehiy ""$($AjoloteDrive)\UPDATES\*"" $($OSDrive)\system.sav\util\MSUpdates\" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\CopyUpdates.log"
            if ($null -ne (Get-ChildItem -Path "$($OSDrive)\system.sav\util\MSUpdates" -Filter "ExcludeKB*.ini")) {
                $null = Invoke-RunPower -File "cmd.exe" -Params "/c del /F $($OSDrive)\system.sav\util\MSUpdates\ExcludeKB*.ini" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\CopyUpdates.log"
            }
            if ($null -ne (Get-ChildItem -Path "$($OSDrive)\system.sav\util\MSUpdates" -Filter "IncludeKB*.json")) {
                $null = Invoke-RunPower -File "cmd.exe" -Params "/c del /F $($OSDrive)\system.sav\util\MSUpdates\IncludeKB*.json" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\CopyUpdates.log"
            }
            
            if (Test-Path -Path (Join-Path $AjoloteDrive "\UPDATES\ExcludeKB$($WinVersion).ini")) {
                WriteLog -Message "Detected ExcludeKB file for version $($WinVersion), moving to OS to use during Windows setup" -Verbose
                Copy-Item -Path (Join-Path $AjoloteDrive "\UPDATES\ExcludeKB$($WinVersion).ini") -Destination (Join-Path $OSDrive "\system.sav\util\MSUpdates\ExcludeKB.ini") -Force | Out-Host
            }
            #below file is only used during OS setup, and no reboot are supported, used on exception cases
            if (Test-Path -Path (Join-Path $AjoloteDrive "\UPDATES\IncludeKB$($WinVersion).json")) {
                WriteLog -Message "Detected Include file for version $($WinVersion), moving to OS to use during Windows setup" -Verbose
                Copy-Item -Path (Join-Path $AjoloteDrive "\UPDATES\IncludeKB$($WinVersion).json") -Destination (Join-Path $OSDrive "\system.sav\util\MSUpdates\IncludeKB.json") -Force | Out-Host
            }
            
            $FilesForUpdate=Get-ChildItem -Path "$($OSDrive)\system.sav\util\MSUpdates" -File | Where-Object { $_.Name -ne $WSUS_CAB }
            if ($FilesForUpdate) { 
                WriteLog -Message "It were copied $($FilesForUpdate.Length) files" -Verbose
                $UpdatesFile="Win$($WinVersion).json"
                if (-Not(Test-Path -Path "$($AjoloteDrive)\UPDATES\$($UpdatesFile)")) {
                    WriteLog -Message "It was not possible locate Updates file: $($UpdatesFile)" -MessageType Error -Verbose
                    $global:MessageResults="It was not possible locate Updates file: $($UpdatesFile)"
                    $global:CodeResults=204
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.CheckMSUpdates "fail" $global:MessageResults
                    Out-WinPE -Backuplogs -RemoveJob
                }
                $UpdatesJson=Get-Content -Path "$($AjoloteDrive)\UPDATES\$($UpdatesFile)" -Raw | ConvertFrom-Json
                $UpdatesRepo="$($AjoloteDrive)\UPDATES"
                if (Test-Path -Path (Join-Path $AjoloteDrive "\UPDATES\ExcludeKB$($WinVersion).ini")) {
                    [string[]]$IgnoreKBs=(Get-Content (Join-Path $AjoloteDrive "\UPDATES\ExcludeKB$($WinVersion).ini") | Where-Object {$_.Trim() -ne ""}).ToUpper()
                    foreach ($kb in $UpdatesJson) {
                        if ($IgnoreKBs.Contains($kb.KBUpdate)) {
                            WriteLog -Message "[$($kb.KBUpdate)] $($kb.Title), was detected on Exclude file, it will be ignored" -Verbose
                            $UpdatesJson = ($UpdatesJson | Where-Object {$_.KBUpdate -ne $kb.KBUpdate})
                        }
                    }
                }

                #######################################################################################################################
                ##########################################     ADDING UPDATES TO OS      ##############################################
                #######################################################################################################################
                if (($null -eq $json.JOBREQUEST.CheckMSUpdates.AppliedOS) -OR ($json.JOBREQUEST.CheckMSUpdates.AppliedOS -ne "done")) {
                    WriteLog -Message "Adding updates to OS" -Verbose
                    foreach ($update in $UpdatesJson) {
                        foreach ($uplink in $update.Link) {
                            $filetoinject=Split-Path $uplink -Leaf
                            $patch=(Join-Path $UpdatesRepo $filetoinject)
                            WriteLog -Message "Required File $($filetoinject)" -Verbose
                            WriteLog -Message "Update: $($update.Title)" -Verbose
                            $extensionfile=([System.IO.Path]::GetExtension($filetoinject)).ToString().ToLower()
                            WriteLog -Message "Searching instalation for extension: $($extensionfile)" -Verbose
                            switch ($extensionfile) {
                                {($_ -eq ".cab") -OR ($_ -eq ".msu")} {
                                    WriteLog -Message "Installing $($update.KBUpdate)" -Verbose
                                    WriteLog -Message "Severity of this update [$($update.MSRCSeverity)]" -Verbose
                                    $InjectUp = RunDism -Params "/image:$($OSDrive)\ /ScratchDir:$($OSDrive)\ /Add-Package /PackagePath:""$($patch)""" -WorkDir $Path -TimeOut 7200 -OutFile "$($Logs)\DismUpdate_$($update.KBUpdate).log" -ShowProgress $true
                                    if (($InjectUp -ne 0) -AND ($InjectUp -ne 3010)) { 
                                        WriteLog -Message "Failed to Inject MS Update: $($update.Title), code: $($InjectUp), stop process to review" -MessageType Error -Verbose; 
                                        Write-Host "Failed to Inject MS Update: $($update.Title)" -ForegroundColor Yellow -BackgroundColor Red; 
                                        if (Test-Path -Path $JobFIle -PathType Leaf) { Move-Item -Path $JobFile -Destination "$($logs)\Job.err" -Force -ErrorAction SilentlyContinue }
                                        $global:MessageResults="Failed to Inject MS Update: $($update.Title)"
                                        $global:CodeResults=217
                                        Copy-Item -Path "X:\windows\Logs\DISM\dism.log" -Destination (Join-Path $Logs "Dism.log") -Force
                                        Update-JobStatus $jobfile $json $json.JOBREQUEST.CheckMSUpdates "fail" $global:MessageResults
                                        Out-WinPE -Backuplogs -RemoveJob
                                    } else {
                                        WriteLog -Message "Successfully installed: $($update.Title)" -Verbose
                                    }
                                    break;
                                }                
                                Default {
                                    WriteLog -Message "Format not supported for inject updates: $($_)" -Verbose
                                }
                            }
                        }#end foreach Link object
                        
                    }#end foreach of Json file

                    if ($null -eq $json.JOBREQUEST.CheckMSUpdates.AppliedOS) {
                        $json.JOBREQUEST.CheckMSUpdates | Add-Member -Name "AppliedOS" -MemberType NoteProperty -Value "done"
                    } else {
                        $json.JOBREQUEST.CheckMSUpdates.AppliedOS="done"
                    }
                    #Save job
                    try {
                        $json | ConvertTo-Json -Depth 16 | Out-File -FilePath $jobfile -Encoding ascii -Force
                    }
                    catch {
                        $ErrorMessage = $_.Exception.Message
                        WriteLog -Message "Failed updating JOB file: $($ErrorMessage)" -MessageType Error -Verbose
                        $global:MessageResults="Failed updating JOB file: $($ErrorMessage)"
                        $global:CodeResults=209
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                    $lockUpdate=RunDism -Params "/Cleanup-Image /Image:$($OSDrive)\ /StartComponentCleanup /ScratchDir:$($OSDrive)\" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\LockMSUpdates.log" -Verbose
                    if ($lockUpdate -ne 0) {WriteLog -Message "Not successfully lock updates, but process will continue" -Messagetype Warning -Verbose}
                    Get-WindowsPackage -Path "$($OSDrive)\" -ScratchDirectory "$($OSDrive)\"| Out-File -FilePath "$($logs)\WindowsPackages_$($WinVersion).log" -Encoding ascii -Force
                    $global:MessageResults="Reboot unit after successfully adding updates to OS, remain on WinPE"
                    $global:CodeResults=3010
                    Set-BCDEnvironment -Environment "WinPE" -OSDrive $OSDrive -Verbose
                    Out-WinPE
                }
                

                ######################################################################################################
                ################    Add updates to WINRE
                ######################################################################################################
                
                if (($null -eq $json.JOBREQUEST.CheckMSUpdates.AppliedWinRE) -OR ($json.JOBREQUEST.CheckMSUpdates.AppliedWinRE -ne "done")) { 
                    $Path_WinPEupdates="$($OSDrive)\system.sav\util\MSUpdates"
                    $tempath=(Join-Path $OSDrive "mntwinre")
                    #--Create temp folder to mount WinRe
                    if (-Not(Test-Path -Path $tempath -PathType Container)){ New-Item -Path $tempath -ItemType Directory  -Force }
                   
                    ##--Use new format file: MinimumOSRevision.json
                    $CumulativeOSPackage=[System.Collections.ArrayList]::new()
                    $ValidateKB=$null
                    if (Test-Path (Join-Path $AjoloteDrive "\TOOLS\MinimumOSRevision.json")) {
                        WriteLog -Message "Detected $( (Join-Path $AjoloteDrive "\TOOLS\MinimumOSRevision.json")), checking version..." -Verbose
                        $GetMinRevFile=Get-Content -Path (Join-Path $AjoloteDrive "\TOOLS\MinimumOSRevision.json") -Raw | ConvertFrom-Json 
                        if ($null -ne $GetMinRevFile.KBUpdate) {
                            [string[]]$RequiredKB=$GetMinRevFile.KBUpdate.$WinVersion
                            [string[]]$ValidateKB=$RequiredKB                            
                            if ([string]::IsNullOrEmpty($RequiredKB) -OR ($RequiredKB.Count -eq 0)) {
                                WriteLog -Message "Not possible retrieve Cumulative KB number from MinimumOSRevision.json file" -MessageType Error -Verbose;
                                $global:MessageResults="Not possible retrieve Cumulative KB number from MinimumOSRevision.json file"
                                $global:CodeResults=505
                                Update-JobStatus $jobfile $json $json.JOBREQUEST.CheckMSUpdates "fail" $global:MessageResults
                                if (Test-Path -Path $JobFIle -PathType Leaf) { Move-Item -Path $JobFile -Destination "$($logs)\Job.err" -Force -ErrorAction SilentlyContinue }       
                                Out-WinPE -Backuplogs -RemoveJob
                            }
                            foreach ($kb in $RequiredKB) {
                                WriteLog -Message "It is detected that this version of OS requires below update number: $($kb)" -Verbose
                                $foundkb=$false;
                                #checking WinRe required
                                if (Test-Path (Join-Path $AjoloteDrive "\UPDATES\WinRE$($WinVersion).json")) {
                                    WriteLog -Message "Checking on WinRequired File: WinRE$($WinVersion).json" -Verbose
                                    $GetFileInclude=Get-Content -Path (Join-Path $AjoloteDrive "\UPDATES\WinRE$($WinVersion).json") -Raw | ConvertFrom-Json
                                    foreach ($update in $GetFileInclude) {
                                        if ($update.ID -eq $kb) {
                                            if (Test-Path (Join-Path $Path_WinPEupdates $update.FileName)) {
                                                [void]$CumulativeOSPackage.Add((Join-Path $Path_WinPEupdates $update.FileName))
                                                WriteLog -Message "Detected and located update file: $($CumulativeOSPackage[$CumulativeOSPackage.Count-1])" -Verbose
                                                $foundkb=$true;
                                                Continue;
                                            } else {
                                                WriteLog -Message "Not possible to locate update: $((Join-Path $Path_WinPEupdates $update.FileName))" -MessageType Error -Verbose
                                                $global:MessageResults="Not possible to locate update: $((Join-Path $Path_WinPEupdates $update.FileName))"
                                                $global:CodeResults=404
                                                Update-JobStatus $jobfile $json $json.JOBREQUEST.CheckMSUpdates "fail" $global:MessageResults
                                                if (Test-Path -Path $JobFIle -PathType Leaf) { Move-Item -Path $JobFile -Destination "$($logs)\Job.err" -Force -ErrorAction SilentlyContinue }            
                                                Out-WinPE -Backuplogs -RemoveJob
                                            }
                                            
                                        }
                                    }                                    
                                }
                                if ($foundkb) {Continue;}
                                #checking IncludeKB
                                if (Test-Path (Join-Path $AjoloteDrive "\UPDATES\IncludeKB$($WinVersion).json")) {
                                    WriteLog -Message "Checking on Include File: IncludeKB$($WinVersion).json" -Verbose
                                    $GetFileInclude=Get-Content -Path (Join-Path $AjoloteDrive "\UPDATES\IncludeKB$($WinVersion).json") -Raw | ConvertFrom-Json
                                    foreach ($update in $GetFileInclude) {
                                        if ($update.ID -eq $kb) {
                                            if (Test-Path (Join-Path $Path_WinPEupdates $update.FileName)) {
                                                [void]$CumulativeOSPackage.Add((Join-Path $Path_WinPEupdates $update.FileName))
                                                WriteLog -Message "Detected and located update file: $($CumulativeOSPackage[$CumulativeOSPackage.Count-1])" -Verbose
                                                $foundkb=$true;
                                                Continue;
                                            } else {
                                                WriteLog -Message "Not possible to locate update: $((Join-Path $Path_WinPEupdates $update.FileName))" -MessageType Error -Verbose
                                                $global:MessageResults="Not possible to locate update: $((Join-Path $Path_WinPEupdates $update.FileName))"
                                                $global:CodeResults=404
                                                Update-JobStatus $jobfile $json $json.JOBREQUEST.CheckMSUpdates "fail" $global:MessageResults
                                                if (Test-Path -Path $JobFIle -PathType Leaf) { Move-Item -Path $JobFile -Destination "$($logs)\Job.err" -Force -ErrorAction SilentlyContinue }            
                                                Out-WinPE -Backuplogs -RemoveJob
                                            }
                                            
                                        }
                                    }                                    
                                }
                                if ($foundkb) {Continue;}
                                #Checking on report
                                if (Test-Path (Join-Path $AjoloteDrive "\UPDATES\Win$($WinVersion).json")) {
                                    WriteLog -Message "Checking on Report File: Win$($WinVersion).json" -Verbose
                                    $GetFileReport=Get-Content -Path (Join-Path $AjoloteDrive "\UPDATES\Win$($WinVersion).json") -Raw | ConvertFrom-Json
                                    foreach ($update in $GetFileReport) {
                                        if ($update.KBUpdate -eq $kb) {
                                            if ($update.Link.Count -gt 1) {
                                                WriteLog -Message "There are more than one file to install, it is not possible to install multiple files for WinRE image" -MessageType Error -Verbose
                                                $global:MessageResults="There are more than one file to install, it is not possible to install multiple files for WinRE image"
                                                $global:CodeResults=409
                                                Update-JobStatus $jobfile $json $json.JOBREQUEST.CheckMSUpdates "fail" $global:MessageResults
                                                if (Test-Path -Path $JobFIle -PathType Leaf) { Move-Item -Path $JobFile -Destination "$($logs)\Job.err" -Force -ErrorAction SilentlyContinue }            
                                                Out-WinPE -Backuplogs -RemoveJob
                                            }
                                            $FileName=(Split-Path $update.Link -Leaf)
                                            if (Test-Path (Join-Path $Path_WinPEupdates $FileName)) {
                                                [void]$CumulativeOSPackage.Add((Join-Path $Path_WinPEupdates $FileName))
                                                WriteLog -Message "Detected and located update file: $($CumulativeOSPackage[$CumulativeOSPackage.Count-1])" -Verbose
                                                $foundkb=$true;
                                                Continue;
                                            } else {
                                                WriteLog -Message "Not possible to locate update: $((Join-Path $Path_WinPEupdates $FileName))" -MessageType Error -Verbose
                                                $global:MessageResults="Not possible to locate update: $((Join-Path $Path_WinPEupdates $FileName))"
                                                $global:CodeResults=404
                                                Update-JobStatus $jobfile $json $json.JOBREQUEST.CheckMSUpdates "fail" $global:MessageResults
                                                if (Test-Path -Path $JobFIle -PathType Leaf) { Move-Item -Path $JobFile -Destination "$($logs)\Job.err" -Force -ErrorAction SilentlyContinue }            
                                                Out-WinPE -Backuplogs -RemoveJob -RemoveJob
                                            }
                                            
                                        }
                                    }
                                }

                            }                            
                            
                        } else {
                           WriteLog -Message "Version of MinimumOSRevision.json it's older thatn expected and cannot be used for validate WinRE update" -MessageType Warning -Verbose 
                        }
                    }
                    if ($CumulativeOSPackage.Count -gt 0) {
                        #--Cleanup Mountpoints
                        $null=RunDism -Params "/Cleanup-Mountpoints" -WorkDir "$($PSScriptRoot)\" -OutFile "$($Logs)\CleanupMountpoints.log" -Verbose
                        #--Mount winRe
                        $MountWinRE=RunDism -Params "/Mount-Image /ImageFile:""$($OSDrive)\Windows\System32\Recovery\winre.wim"" /index:1 /MountDir:""$($tempath)"" /ScratchDir:$($OSDrive)\" -ShowProgress $true -WorkDir "$($PSScriptRoot)\" -OutFile (Join-Path $Logs "WinREUpdates.log")
                        if ($MountWinRE -ne 0) {
                            WriteLog -Message "Not possible mount WinRE image to perform changes" -MessageType Error -Verbose;                         
                            Copy-Item -Path "X:\windows\Logs\DISM\dism.log" -Destination (Join-Path $Logs "Dism.log") -Force
                            $global:MessageResults="Not possible mount WinRE image to perform changes"
                            $global:CodeResults=$MountWinRE                    
                            Update-JobStatus $jobfile $json $json.JOBREQUEST.CheckMSUpdates "fail" $global:MessageResults
                            if (Test-Path -Path $JobFIle -PathType Leaf) { Move-Item -Path $JobFile -Destination "$($logs)\Job.err" -Force -ErrorAction SilentlyContinue }
                            Out-WinPE -Backuplogs -RemoveJob
                        }
                        WriteLog -Message "Get Scratch Space for WinPE" -Verbose
                        $null=RunDism -Params "/image:""$($tempath)"" /ScratchDir:$($OSDrive)\ /Get-ScratchSpace" -WorkDir "$($PSScriptRoot)\" -OutFile (Join-Path $Logs "WinREUpdates.log") -Verbose
                        
                        foreach ($up in $CumulativeOSPackage) {                            
                            WriteLog -Message "Adding update file: $($up)" -Verbose
                            $InjectUpWinRe = RunDism -Params "/image:$($tempath)\ /ScratchDir:$($OSDrive)\ /Add-Package /PackagePath:""$($up)""" -WorkDir $Path_WinPEupdates -TimeOut 7200 -OutFile "$($Logs)\DismUpdate_WinRE.log" -ShowProgress $true	
                            if (($InjectUpWinRe -ne 0) -AND ($InjectUpWinRe -ne 3010)) { 
                                WriteLog -Message "Failed to Inject MS Update to WinRE: $((Split-Path $up -Leaf)), code: $($InjectUpWinRe), stop process to review" -MessageType Error -Verbose; 
                                Write-Host "Failed to WinRE Inject MS Update: $((Split-Path $up -Leaf))" -ForegroundColor Yellow -BackgroundColor Red; 
                                if (Test-Path -Path $JobFIle -PathType Leaf) { Move-Item -Path $JobFile -Destination "$($logs)\Job.err" -Force -ErrorAction SilentlyContinue }
                                Copy-Item -Path "X:\windows\Logs\DISM\dism.log" -Destination (Join-Path $Logs "Dism.log") -Force
                                $global:MessageResults="Failed to WinRE Inject MS Update: $((Split-Path $up -Leaf))"
                                $global:CodeResults=$InjectUpWinRe
                                Update-JobStatus $jobfile $json $json.JOBREQUEST.CheckMSUpdates "fail" $global:MessageResults
                                Out-WinPE -Backuplogs -RemoveJob
                            } else {
                                WriteLog -Message "Successfully installed on WinRE: $((Split-Path $up -Leaf))" -Verbose
                            }                            
                        }
                        #Lock updates
                        $lockUpdates=RunDism -Params "/image:""$($tempath)"" /ScratchDir:$($OSDrive)\ /Cleanup-Image /StartComponentCleanup /ResetBase " -WorkDir "$($PSScriptRoot)\" -OutFile (Join-Path $Logs "DismUpdate_WinRE.log") -Verbose
                        if ($lockUpdates -ne 0) {WriteLog -Message "Not successfully lock updates for WinRE, but process will continue" -Messagetype Warning -Verbose}
                        $GetFeatures=RunDism -Params "/Image:""$($tempath)"" /Get-Packages /ScratchDir:$($OSDrive)\" -WorkDir "$($PSScriptRoot)\" -OutFile "$($Logs)\GetPackagesWinPE.log" -Verbose
                        $GetFeatures=RunDism -Params "/Image:""$($tempath)"" /Get-Features /ScratchDir:$($OSDrive)\" -WorkDir "$($PSScriptRoot)\" -OutFile "$($Logs)\GetFeatureWinPE.log" -Verbose
                        if ($GetFeatures -ne 0) {
                            WriteLog -Message "Not possible access to image" -MessageType Warning -Verbose
                        } else {
                            WriteLog -Message "You can check WinRe features on file: $($Logs)\GetFeatureWinPE.log" -Verbose
                        }
                        
                        #Unmount WinRE and save changes
                        $UnMountWinRE=RunDism -Params "/UnMount-Image /MountDir:""$($tempath)"" /Commit /ScratchDir:$($OSDrive)\" -WorkDir "$($PSScriptRoot)\" -OutFile (Join-Path $Logs "WinREUpdates.log") -Verbose
                        if ($UnMountWinRE -ne 0) {
                            WriteLog -Message "Not possible Save changes on WinRE image" -MessageType Error -Verbose; 
                            $global:MessageResults="Not possible Save changes on WinRE image"
                            $global:CodeResults=$UnMountWinRE
                            Copy-Item -Path "X:\windows\Logs\DISM\dism.log" -Destination (Join-Path $Logs "Dism.log") -Force
                            Update-JobStatus $jobfile $json $json.JOBREQUEST.CheckMSUpdates "fail" $global:MessageResults
                            if (Test-Path -Path $JobFIle -PathType Leaf) { Move-Item -Path $JobFile -Destination "$($logs)\Job.err" -Force -ErrorAction SilentlyContinue }
                            #Start-Process powershell -WorkingDirectory "$($AjoloteDrive)\system.sav\logs\CSBuilt\" -Wait                
                            Out-WinPE -Backuplogs -RemoveJob
                        }
                    } else {
                        if ($null -ne $UpdatesJson) {
                            foreach ($update in $UpdatesJson) {
                                if (($null -eq $update.MSRCSeverity) -OR ([string]::IsNullOrEmpty($update.MSRCSeverity))) {
                                    WriteLog -Message "Update: $($update.Title) doesn't have severity, it cannot be apply for WinRe" -Verbose
                                } else {                                    
                                    $severity=$update.MSRCSeverity.ToString().ToLower()
                                    WriteLog -Message "Update Name: $($update.Title)" -Verbose
                                    WriteLog -Message "`tUpdate Severity [$($severity)]" -Verbose
                                    $patchwinre=(Join-Path $Path_WinPEupdates (Split-Path $update.Link -Leaf))
                                    switch ($severity) {
                                        "critical" {
                                            #--Cleanup Mountpoints
                                            $null=RunDism -Params "/Cleanup-Mountpoints" -WorkDir "$($PSScriptRoot)\" -OutFile "$($Logs)\CleanupMountpoints.log" -Verbose
                                            #--Mount winRe
                                            $MountWinRE=RunDism -Params "/Mount-Image /ImageFile:""$($OSDrive)\Windows\System32\Recovery\winre.wim"" /index:1 /MountDir:""$($tempath)"" /ScratchDir:$($OSDrive)\" -ShowProgress $true -WorkDir "$($PSScriptRoot)\" -OutFile (Join-Path $Logs "WinREUpdates.log")
                                            if ($MountWinRE -ne 0) {
                                                WriteLog -Message "Not possible mount WinRE image to perform changes" -MessageType Error -Verbose;                         
                                                Copy-Item -Path "X:\windows\Logs\DISM\dism.log" -Destination (Join-Path $Logs "Dism.log") -Force
                                                $global:MessageResults="Not possible mount WinRE image to perform changes"
                                                $global:CodeResults=$MountWinRE                    
                                                Update-JobStatus $jobfile $json $json.JOBREQUEST.CheckMSUpdates "fail" $global:MessageResults
                                                if (Test-Path -Path $JobFIle -PathType Leaf) { Move-Item -Path $JobFile -Destination "$($logs)\Job.err" -Force -ErrorAction SilentlyContinue }
                                                Out-WinPE -Backuplogs -RemoveJob
                                            }
                                            WriteLog -Message "Get Scratch Space for WinPE" -Verbose
                                            $null=RunDism -Params "/image:""$($tempath)"" /ScratchDir:$($OSDrive)\ /Get-ScratchSpace" -WorkDir "$($PSScriptRoot)\" -OutFile (Join-Path $Logs "WinREUpdates.log") -Verbose
                                            #Install update
                                            WriteLog -Message "`tInjecting package $($patchwinre)" -Verbose
                                            $InjectUpWinRe = RunDism -Params "/image:$($tempath)\ /ScratchDir:$($OSDrive)\ /Add-Package /PackagePath:""$($patchwinre)""" -WorkDir $Path_WinPEupdates -TimeOut 7200 -OutFile "$($Logs)\DismUpdate_$($update.KBUpdate).log" -ShowProgress $true	
                                            if (($InjectUpWinRe -ne 0) -AND ($InjectUpWinRe -ne 3010)) { 
                                                WriteLog -Message "Failed to Inject MS Update to WinRE: $($update.Title), code: $($InjectUpWinRe), stop process to review" -MessageType Error -Verbose; 
                                                Write-Host "Failed to WinRE Inject MS Update: $($update.Title)" -ForegroundColor Yellow -BackgroundColor Red; 
                                                if (Test-Path -Path $JobFIle -PathType Leaf) { Move-Item -Path $JobFile -Destination "$($logs)\Job.err" -Force -ErrorAction SilentlyContinue }
                                                Copy-Item -Path "X:\windows\Logs\DISM\dism.log" -Destination (Join-Path $Logs "Dism.log") -Force
                                                $global:MessageResults="Failed to WinRE Inject MS Update: $($update.Title)"
                                                $global:CodeResults=217
                                                Update-JobStatus $jobfile $json $json.JOBREQUEST.CheckMSUpdates "fail" $global:MessageResults
                                                Out-WinPE -Backuplogs -RemoveJob
                                            } else {
                                                WriteLog -Message "Successfully WinRE injected: $($update.Title)" -Verbose
                                                [void]$CumulativeOSPackage.Add($patchwinre)
                                            }
                                            #Lock updates
                                            $lockUpdates=RunDism -Params "/image:""$($tempath)"" /ScratchDir:$($OSDrive)\ /Cleanup-Image /StartComponentCleanup /ResetBase " -WorkDir "$($PSScriptRoot)\" -OutFile (Join-Path $Logs "DismUpdate_WinRE.log") -Verbose
                                            if ($lockUpdates -ne 0) {WriteLog -Message "Not successfully lock updates for WinRE, but process will continue" -Messagetype Warning -Verbose}
                                            
                                            $GetFeatures=RunDism -Params "/Image:""$($tempath)"" /Get-Features /ScratchDir:$($OSDrive)\" -WorkDir "$($PSScriptRoot)\" -OutFile "$($Logs)\GetFeatureWinPE.log" -Verbose
                                            if ($GetFeatures -ne 0) {
                                                WriteLog -Message "Not possible access to image" -MessageType Warning -Verbose
                                            } else {
                                                WriteLog -Message "You can check WinRe features on file: $($Logs)\GetFeatureWinPE.log" -Verbose
                                            }
                                            
                                            #Unmount WinRE and save changes
                                            $UnMountWinRE=RunDism -Params "/UnMount-Image /MountDir:""$($tempath)"" /Commit /ScratchDir:$($OSDrive)\" -WorkDir "$($PSScriptRoot)\" -OutFile (Join-Path $Logs "WinREUpdates.log") -Verbose
                                            if ($UnMountWinRE -ne 0) {
                                                WriteLog -Message "Not possible Save changes on WinRE image" -MessageType Error -Verbose; 
                                                $global:MessageResults="Not possible Save changes on WinRE image"
                                                $global:CodeResults=$UnMountWinRE
                                                Copy-Item -Path "X:\windows\Logs\DISM\dism.log" -Destination (Join-Path $Logs "Dism.log") -Force
                                                Update-JobStatus $jobfile $json $json.JOBREQUEST.CheckMSUpdates "fail" $global:MessageResults
                                                if (Test-Path -Path $JobFIle -PathType Leaf) { Move-Item -Path $JobFile -Destination "$($logs)\Job.err" -Force -ErrorAction SilentlyContinue }
                                                #Start-Process powershell -WorkingDirectory "$($AjoloteDrive)\system.sav\logs\CSBuilt\" -Wait                
                                                Out-WinPE -Backuplogs -RemoveJob
                                            }
                                            break;
                                        }
                                        "important" { WriteLog -Message "No actions defined for ""Important"" severity, skip update" -Verbose; break;}
                                        Default { WriteLog -Message "Not defined severity: [$($_)]" -MessageType Warning -Verbose; break;}
                                    } #switch end
                                }
                                
                            } #End Foreach
                        }
                    }
                    <#
                    
                    #>    

                    
                    #validate WinRe update, in Win10 appears as [Migration.DeferredServices], it must change to [Migration.Services.Deferred]
                     #--Cleanup Mountpoints
                     $null=RunDism -Params "/Cleanup-Mountpoints" -WorkDir "$($PSScriptRoot)\" -OutFile "$($Logs)\CleanupMountpoints.log" -Verbose
                     #--Mount winRe
                     $MountWinRE=RunDism -Params "/Mount-Image /ImageFile:""$($OSDrive)\Windows\System32\Recovery\winre.wim"" /index:1 /MountDir:""$($tempath)"" /ScratchDir:$($OSDrive)\" -ShowProgress $true -WorkDir "$($PSScriptRoot)\" -OutFile (Join-Path $Logs "WinREUpdates.log")
                     if ($MountWinRE -ne 0) {
                         WriteLog -Message "Not possible mount WinRE image to perform changes" -MessageType Error -Verbose;                         
                         Copy-Item -Path "X:\windows\Logs\DISM\dism.log" -Destination (Join-Path $Logs "Dism.log") -Force
                         $global:MessageResults="Not possible mount WinRE image to perform changes"
                         $global:CodeResults=$MountWinRE                    
                         Update-JobStatus $jobfile $json $json.JOBREQUEST.CheckMSUpdates "fail" $global:MessageResults
                         if (Test-Path -Path $JobFIle -PathType Leaf) { Move-Item -Path $JobFile -Destination "$($logs)\Job.err" -Force -ErrorAction SilentlyContinue }
                         Out-WinPE -Backuplogs -RemoveJob
                     }
                     WriteLog -Message "Get Scratch Space for WinPE" -Verbose
                     $null=RunDism -Params "/image:""$($tempath)"" /ScratchDir:$($OSDrive)\ /Get-ScratchSpace" -WorkDir "$($PSScriptRoot)\" -OutFile (Join-Path $Logs "WinREUpdates.log") -Verbose
                     
                    if (Test-Path -Path "$($tempath)\windows\system32\setupplatform.cfg" -PathType Leaf) {
                        if ($null -eq (Get-Content -Path "$($tempath)\windows\system32\setupplatform.cfg" | Select-String -Pattern "Migration.Services.Deferred")) {
                            WriteLog -Message "This WinRe was incorrectly patched, cannot locate [Migration.Services.Deferred] on setupplatform.cfg file" -MessageType Error -Verbose; 
                            $global:MessageResults="This WinRe was incorrectly patched, cannot locate [Migration.Services.Deferred] on setupplatform.cfg file"
                            $global:CodeResults=$UnMountWinRE
                            Update-JobStatus $jobfile $json $json.JOBREQUEST.CheckMSUpdates "fail" $global:MessageResults
                            if (Test-Path -Path $JobFIle -PathType Leaf) { Move-Item -Path $JobFile -Destination "$($logs)\Job.err" -Force -ErrorAction SilentlyContinue }            
                            Out-WinPE -Backuplogs -RemoveJob
                        }
                    }
                    $null=RunDism -Params "/UnMount-Image /MountDir:""$($tempath)"" /Discard /ScratchDir:$($OSDrive)\" -WorkDir "$($PSScriptRoot)\" -OutFile (Join-Path $Logs "WinREUpdates.log") -Verbose
                    #Cleanup unused files and reduce the size of winre.wim
                    #$lockUpdates=RunDism -Params "/image:""$($tempath)"" /Cleanup-Image /StartComponentCleanup /ScratchDir:$($OSDrive)\" -WorkDir "$($PSScriptRoot)\" -OutFile (Join-Path $Logs "WinREUpdates.log") -Verbose
                    #if ($lockUpdates -ne 0) {WriteLog -Message "Not successfully lock updates for WinRE, but process will continue" -Messagetype Warning -Verbose}
                    
                    if (Test-Path "$($tempath)") { Remove-Item "$($tempath)" -Force -Recurse }            
                    #optimize space on WinRE.wim
                    $ExportWinRE=RunDism -Params "/export-image /sourceimagefile:""$($OSDrive)\windows\system32\recovery\winre.wim"" /sourceindex:1 /DestinationImageFile:""$($OSDrive)\windows\system32\recovery\winre_opt.wim""" -WorkDir "$($PSScriptRoot)\" -OutFile "$($Logs)\ExportWinRE.log" -Verbose
                    if ($ExportWinRE -ne 0) {
                        WriteLog -Message "Not possible Export WinRE file" -MessageType Error -Verbose; 
                        $global:MessageResults="Not possible Export WinRE file"
                        $global:CodeResults=$ExportWinRE
                        Copy-Item -Path "X:\windows\Logs\DISM\dism.log" -Destination (Join-Path $Logs "Dism.log") -Force
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.CheckMSUpdates "fail" $global:MessageResults
                        if (Test-Path -Path $JobFIle -PathType Leaf) { Move-Item -Path $JobFile -Destination "$($logs)\Job.err" -Force -ErrorAction SilentlyContinue }
                        #Start-Process powershell -WorkingDirectory "$($AjoloteDrive)\system.sav\logs\CSBuilt\" -Wait                
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                    Remove-Item -Path "$($OSDrive)\windows\system32\recovery\winre.wim" -Force 
                    Rename-Item -Path "$($OSDrive)\windows\system32\recovery\winre_opt.wim" -NewName "winre.wim" -Force
                    if (-Not(Test-Path -Path "$($OSDrive)\windows\system32\recovery\winre.wim" -PathType Leaf)) {
                        WriteLog -Message "Not possible locate WinRE file" -MessageType Error -Verbose; 
                        $global:MessageResults="Not possible locate WinRE file"
                        $global:CodeResults=224
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.CheckMSUpdates "fail" $global:MessageResults
                        if (Test-Path -Path $JobFIle -PathType Leaf) { Move-Item -Path $JobFile -Destination "$($logs)\Job.err" -Force -ErrorAction SilentlyContinue }
                        #Start-Process powershell -WorkingDirectory "$($AjoloteDrive)\system.sav\logs\CSBuilt\" -Wait
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                    if ($CumulativeOSPackage.Count -gt 0) {
                        #adding file names to job file
                        $CumulativeOSPackageFiles=[System.Collections.ArrayList]::new()
                        foreach ($filename in $CumulativeOSPackage) {
                            [void]$CumulativeOSPackageFiles.Add((Split-Path $filename -Leaf))
                        }
                        if ($null -eq $json.JOBREQUEST.CheckMSUpdates.AppliedWinREFiles) {
                            $json.JOBREQUEST.CheckMSUpdates | Add-Member -Name "AppliedWinREFiles" -MemberType NoteProperty -Value $CumulativeOSPackageFiles
                        } else {
                            $json.JOBREQUEST.CheckMSUpdates.AppliedWinREFiles=$CumulativeOSPackageFiles
                        }
                    }
                    

                    if ($null -eq $json.JOBREQUEST.CheckMSUpdates.AppliedWinRE) {
                        $json.JOBREQUEST.CheckMSUpdates | Add-Member -Name "AppliedWinRE" -MemberType NoteProperty -Value "done"
                    } else {
                        $json.JOBREQUEST.CheckMSUpdates.AppliedWinRE="done"
                    }
                    #Save job
                    try {
                        $json | ConvertTo-Json -Depth 16 | Out-File -FilePath $jobfile -Encoding ascii -Force
                    }
                    catch {
                        $ErrorMessage = $_.Exception.Message
                        WriteLog -Message "Failed updating JOB file: $($ErrorMessage)" -MessageType Error -Verbose
                        $global:MessageResults="Failed updating JOB file: $($ErrorMessage)"
                        $global:CodeResults=209
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                }# end adding winre updates
                
            } else {
                WriteLog -Message "It was not possible to detect updates in local folder" -MessageType Error -Verbose
                Update-JobStatus $jobfile $json $json.JOBREQUEST.CheckMSUpdates "fail" "Missing updates files"
                $global:MessageResults="It was not possible to detect updates in local folder"
                $global:CodeResults=404
                Out-WinPE -Backuplogs -RemoveJob
            }
        } else {
            WriteLog -Message "It was not possible to detect folder Microsoft Updates: $($AjoloteDrive)\UPDATES" -MessageType Warning -Verbose
            Update-JobStatus $jobfile $json $json.JOBREQUEST.CheckMSUpdates "fail" "Missing folder updates: ""$($AjoloteDrive)\UPDATES"""
            $global:MessageResults="Missing folder updates: ""$($AjoloteDrive)\UPDATES"""
            $global:CodeResults=404
            Out-WinPE -Backuplogs -RemoveJob
        }
        Update-JobStatus $jobfile $json $json.JOBREQUEST.CheckMSUpdates "processing" "Reboot for 1st phase to complete updates install"

    } elseif ($json.JOBREQUEST.CheckMSUpdates.status.ToLower() -eq "pass") { 
        WriteLog -Message "MS Updates requested were already performed, continue" -Verbose
    } elseif ($json.JOBREQUEST.CheckMSUpdates.status.ToLower() -eq "missing") { 
        WriteLog -Message "MS Updates requested require more updates, please check $($UpdatesFile)" -MessageType Warning -Verbose
        Copy-Item "$($OSDrive)\system.sav\logs\$($UpdatesFile)" "$($logs)\$($UpdatesFile)" -Force
        if ($null -ne $json.JOBREQUEST.Job) { 
            WriteLog -Message "$($UpdatesFile) was copied to logs $($logs)" -Verbose
            $global:MessageResults="Found Microsoft Updates Report, please review report on $($logs)\$($UpdatesFile)"
            $global:CodeResults=1   
            Update-JobStatus $jobfile $json $json.JOBREQUEST.Job "fail" $global:MessageResults
        } elseif ($null -ne $json.JOBREQUEST.Control) {
            WriteLog -Message "Found MS Updates Report, please review report on $($OSDrive)\system.sav\logs\$($UpdatesFile)" -Verbose 
            $global:MessageResults="Found MS Updates Report, please review report on $($OSDrive)\system.sav\logs\$($UpdatesFile)"
            $global:CodeResults=1      
            Update-JobStatus $jobfile $json $json.JOBREQUEST.Control "fail" $global:MessageResults   
        }
        Out-WinPE -Backuplogs -RemoveJob
    } elseif ($json.JOBREQUEST.CheckMSUpdates.status.ToLower() -eq "fail") { 
        WriteLog -Message "MS Updates request was failed" -MessageType Error -Verbose
        $global:MessageResults="MS Updates request was failed"
        $global:CodeResults=1 
        if ($null -ne $json.JOBREQUEST.Job) {               
            Update-JobStatus $jobfile $json $json.JOBREQUEST.Job "fail" $global:MessageResults
        } elseif ($null -ne $json.JOBREQUEST.Control) {
            Update-JobStatus $jobfile $json $json.JOBREQUEST.Control "fail" $global:MessageResults   
        }
        Out-WinPE -Backuplogs -RemoveJob
    } elseif ($json.JOBREQUEST.CheckMSUpdates.status.ToLower() -eq "processing") { 
        WriteLog -Message "MS Updates requires Windows stage to completes, allow to continue" -Verbose
        <#$global:MessageResults="MS Updates request was unchanged"
        $global:CodeResults=1 
        if ($null -ne $json.JOBREQUEST.Job) {               
            Update-JobStatus $jobfile $json $json.JOBREQUEST.Job "fail" $global:MessageResults
        } elseif ($null -ne $json.JOBREQUEST.Control) {
            Update-JobStatus $jobfile $json $json.JOBREQUEST.Control "fail" $global:MessageResults   
        }
        Out-WinPE -Backuplogs -RemoveJob
        #>
    } else {
        WriteLog -Message "Microsoft Updates request was not expected to receive with status $($json.JOBREQUEST.CheckMSUpdates.status)" -MessageType Error -Verbose
    }

    
} else {
    WriteLog -Message "Module not required, continue" -Verbose
}