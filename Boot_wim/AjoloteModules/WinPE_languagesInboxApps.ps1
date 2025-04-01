<#
.VERSION
    1.0.2 = Fix code error for Windows 10 detection
    1.0.1 = Adding "Microsoft.NET.Native*" as part of defautl reinstall appx
    1.0.0 = Initial Release
.DATE
    1/16/2024
.DEVELOPER
    Cisneros Jorge
#>

if ($null -ne $json.JOBREQUEST.Localization) { 
    WriteLog -Message "Checking Inbox Apps are needed" -Verbose
    if ((![string]::IsNullOrEmpty($json.JOBREQUEST.Localization.status)) -AND ($json.JOBREQUEST.Localization.status.ToLower() -eq "pass")) { 
        ##---Default language / internationalization configuration status
        if (![string]::IsNullOrEmpty($json.JOBREQUEST.Localization.defaultlanguage)) { 
            if (([string]::IsNullOrEmpty($json.JOBREQUEST.Localization.installapps)) -AND ($json.JOBREQUEST.Localization.defaultlanguage.Trim().ToLower() -ne 'en-us')) { 
                WriteLog -Message "Detected default language required, reinstall Inbox Apps" -Verbose
                WriteLog -Message "Checking if this version of Windows has source installers, mounting components folder" -Verbose
                $DriveComponents = Invoke-MountServer "/componentspath"
                if ($null -eq $DriveComponents) {
                    WriteLog -Message "Not possible mount Component share" -MessageType Error -Verbose
                    $global:MessageResults="Not possible mount Component share"
                    $global:CodeResults=101
                    Out-WinPE -Backuplogs -RemoveJob
                } else {
                    WriteLog -Message "Components share was mounted successfully on drive: $($DriveComponents)\ Checking component folder" -Verbose

                    if (-Not(Test-Path -Path (Join-Path $DriveComponents "InboxApps") -PathType Container)) {
                        WriteLog -Message "It was not possible to detect folder: $((Join-Path $DriveComponents "InboxApps"))" -MessageType Error -Verbose
                        $global:MessageResults="It was not possible to detect folder: $((Join-Path $DriveComponents "InboxApps"))"
                        $global:CodeResults=404
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                    Switch ($WinVersion) {
                        {($_ -eq "19041") -OR ($_ -eq "19042") -OR ($_ -eq "19043") -OR ($_ -eq "19044") -OR ($_ -eq "19045") } { 
                            WriteLog -Message "Build $($WinVersion) detected, there are not support for Windows 10" -MessageType Warning -Verbose;
                            $InboxAppRepository=$null;
                            break;
                        }
                        {($_ -eq "22000") -OR ($_ -eq "22621") -OR ($_ -eq "22631")} { 
                            $InboxAppRepository="$($DriveComponents)\InboxApps\$($WinVersion)\packages"
                            if (-Not(Test-Path -Path $InboxAppRepository)) {
                                WriteLog -Message "It was not possible to detect folder: $($InboxAppRepository)" -MessageType Error -Verbose
                                $global:MessageResults="It was not possible to detect folder: $($InboxAppRepository)"
                                $global:CodeResults=404
                                Out-WinPE -Backuplogs -RemoveJob
                            }
                            break; 
                        }
                        default { 
                            WriteLog -Message "invalid or unsupported version $($WinVersion) detected in module WinPE_languagesInboxApps" -MessageType Error -Verbose;
                            $global:MessageResults="invalid or unsupported version $($WinVersion) detected in module WinPE_languagesInboxApps" 
                            $global:CodeResults=405
                            Out-WinPE -Backuplogs -RemoveJob
                        }
                    }
                    if ($null -ne $InboxAppRepository) {
                        if (-Not(Test-Path -Path (Join-Path $DriveComponents "\InboxApps\$($WinVersion)\packages") -PathType Container)) {
                            WriteLog -Message "It was not possible to detect folder: $((Join-Path $DriveComponents "\InboxApps\$($WinVersion)\packages"))" -MessageType Error -Verbose
                            $global:MessageResults="It was not possible to detect folder: $((Join-Path $DriveComponents "\InboxApps\$($WinVersion)\packages"))"
                            $global:CodeResults=404
                            Out-WinPE -Backuplogs -RemoveJob
                        }
                        WriteLog -Message "Reinstalling Inbox Apps..." -Verbose
                        $excludepkg=("*.xml","*.msix")                        
                        Get-AppxProvisionedPackage -Path "$($OSDrive)\" | ForEach-Object {
                            WriteLog -Message "Searching package [$($_.DisplayName)*.appx*]"
                            $SearchPackage=(Get-ChildItem -Path "$($InboxAppRepository)\*" -Include "$($_.DisplayName)*" -Exclude $excludepkg)
                            if ($null -ne $SearchPackage) {
                                foreach ($package in $SearchPackage) {
                                    WriteLog -Message "Reinstalling package file: $($package.Name)" -Verbose
                                    $License=$package.Name.Replace($package.Extension,".xml")
                                    if (Test-Path (Join-Path $InboxAppRepository $License)) {
                                        WriteLog -Message "License file detected: $($License)" -Verbose
                                        $ReinstallInboxApp = RunDism -Params "/image:$($OSDrive)\ /ScratchDir:$($OSDrive)\ /Add-ProvisionedAppxPackage /PackagePath:""$($package.FullName)"" /LicensePath:""$((Join-Path $InboxAppRepository $License))"" /Region:""all""" -WorkDir $PSScriptRoot -OutFile "$($Logs)\DismReinstallAppx_$($package.Name).log"
                                    } else {
                                        $ReinstallInboxApp = RunDism -Params "/image:$($OSDrive)\ /ScratchDir:$($OSDrive)\ /Add-ProvisionedAppxPackage /PackagePath:""$($package.FullName)"" /SkipLicense /Region:""all""" -WorkDir $PSScriptRoot -OutFile "$($Logs)\DismReinstallAppx_$($package.Name).log"
                                    }
                                    if ($ReinstallInboxApp -ne 0) { 
                                        WriteLog -Message "Failed to Reinstall Inbox Package: $($package.Name), code: $($ReinstallInboxApp), stop process to review" -MessageType Error -Verbose;
                                        $global:MessageResults="Failed to Reinstall Inbox Package: $($package.Name), code: $($ReinstallInboxApp), stop process to review"
                                        $global:CodeResults=$ReinstallInboxApp
                                        Copy-Item -Path "X:\windows\Logs\DISM\dism.log" -Destination (Join-Path $Logs "Dism.log") -Force
                                        Out-WinPE -Backuplogs -RemoveJob
                                    } else {
                                        WriteLog -Message "`tSuccessfully installed: $($package.Name)" -Verbose
                                    }
                                } #End foreach package detected
                            } else {
                                WriteLog -Message "It was not possible to detect a single package for $($_.DisplayName)" -MessageType Warning -Verbose
                            }
                        } #foreach current installed appx 
                        #reinstall specific packages
                        $AppxNamesNoLicense=@("Microsoft.UI.Xaml","Microsoft.VCLibs","Microsoft.NET.Native") #specific packages
                        WriteLog "Searching additional packages marked as mandatory" -Verbose
                        foreach ($appxname in $AppxNamesNoLicense) {
                            $SearchAppx = (Get-ChildItem -Path "$($InboxAppRepository)\*" -Include "$($appxname)*" -Exclude $excludepkg | Sort-Object -Property Name)
                            if ($null -eq $SearchAppx) { WriteLog -Message "It was not possible to detect single package for required appx: $($appxname)" -Verbose; }
                            foreach ($appx in $SearchAppx) {
                                WriteLog -Message "Reinstalling package file: $($appx.Name)" -Verbose
                                $ReinstallInboxApp = RunDism -Params "/image:$($OSDrive)\ /ScratchDir:$($OSDrive)\ /Add-ProvisionedAppxPackage /PackagePath:""$($appx.FullName)"" /SkipLicense /Region:""all""" -WorkDir $PSScriptRoot -OutFile "$($Logs)\DismReinstallAppx_$($appx.Name).log"
                                if ($ReinstallInboxApp -ne 0) { 
                                    WriteLog -Message "Failed to Reinstall Inbox Package: $($appx.Name), code: $($ReinstallInboxApp), stop process to review" -MessageType Error -Verbose;
                                    $global:MessageResults="Failed to Reinstall Inbox Package: $($appx.Name), code: $($ReinstallInboxApp), stop process to review"
                                    $global:CodeResults=$ReinstallInboxApp
                                    Copy-Item -Path "X:\windows\Logs\DISM\dism.log" -Destination (Join-Path $Logs "Dism.log") -Force
                                    Out-WinPE -Backuplogs -RemoveJob
                                } else {
                                    WriteLog -Message "`tSuccessfully installed: $($appx.Name)" -Verbose
                                }
                            }
                        } #end install specific packages
                        #Copy packages for installation just before to save image
                        $PostAppxs=@("UD_Microsoft.VCLibs","UD_Microsoft.UI.Xaml.2.8","UD_Microsoft.WindowsTerminal_3001.18")
                        WriteLog -Message "Search for post appx installers" -Verbose
                        if (-Not(Test-Path -Path (Join-Path $OSDrive "\system.sav\appxpackages"))) { New-Item -Path (Join-Path $OSDrive "\system.sav\appxpackages") -ItemType Directory -Force }
                        foreach ($appxfile in $PostAppxs) {
                            $SearchAppx = (Get-ChildItem -Path "$($InboxAppRepository)\*" -Include "$($appxfile)*" -Exclude $excludepkg | Sort-Object -Property Name)
                            if ($null -ne $SearchAppx) {
                                foreach ($file in $SearchAppx) {
                                    WriteLog -Message "Moving package $($file.Name) to $((Join-Path $OSDrive "\system.sav\appxpackages\"))" -Verbose
                                    Copy-Item -Path $file.FullName -Destination (Join-Path $OSDrive "\system.sav\appxpackages\$($file.Name)") -Force
                                }
                            } else {
                                WriteLog -Message "It was not possible to locate package like ""$($appxfile)*""" -MessageType Warning -Verbose
                            }
                        }
                        
                    } else {
                        WriteLog -Message "There are no files to support reinstall of Inbox Apps for Windows build $($WinVersion), process will marked as sucess and continue" -MessageType Warning -Verbose
                    }
                }


               

                if ($null -eq $json.JOBREQUEST.Localization.installapps) {
                    $json.JOBREQUEST.Localization | Add-Member -Name "installapps" -MemberType NoteProperty -Value "done"
                } else {
                    $json.JOBREQUEST.Localization.installapps="done"
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



            } else {
                WriteLog -Message "Inbox appx was already installed or default en-us was selected, skip for now" -Verbose
            }

        } else {
            WriteLog -Message "No change on main language, this module doesn't apply" -Verbose
        }
    } else {
        WriteLog -Message "Resinstall Inbox App requested but not possible with localization status $($json.JOBREQUEST.Localization.status)" -MessageType Warning -Verbose
    }
    
} else {
    WriteLog -Message "Module not required, continue" -Verbose
}