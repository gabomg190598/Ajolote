#Adding first draft for language install
if ($null -ne $json.JOBREQUEST.ConfigureOffice) { 
    WriteLog -Message "Configure Office was detected" -Verbose
    if (([string]::IsNullOrEmpty($json.JOBREQUEST.ConfigureOffice.status)) -OR ($json.JOBREQUEST.ConfigureOffice.status.ToLower() -eq "new")) { 
        #Must exist RemoveOffice or default is false
        if (($null -eq $json.JOBREQUEST.ConfigureOffice.RemoveOffice) -OR !($json.JOBREQUEST.ConfigureOffice.RemoveOffice)) {
            #Install Office
            if (Test-Path "$($AjoloteDrive)\OFFICE") {
                WriteLog -Message "Copying files to install Office" -Verbose
                #office is provided using 2 packages based on Windows (10 or 11) 
                if ([int]$OS.Build -ge 22000) {
                    WriteLog -Message "Windows build version detected is for Windows 11" -Verbose 
                    $intCopyOffice = RunPower -File "cmd.exe" -Params "/c xcopy /sehiy ""$($AjoloteDrive)\OFFICE\WIN11\*"" $($OSDrive)\" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\CopyOffice.log"
                    $officeCVA=Get-ChildItem -Path "$($AjoloteDrive)\OFFICE\WIN11" -Filter "*.cva" -Recurse                    
                } else {
                    WriteLog -Message "Windows build version detected is for Windows 10" -Verbose 
                    $intCopyOffice = RunPower -File "cmd.exe" -Params "/c xcopy /sehiy ""$($AjoloteDrive)\OFFICE\WIN10\*"" $($OSDrive)\" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\CopyOffice.log"
                    $officeCVA=Get-ChildItem -Path "$($AjoloteDrive)\OFFICE\WIN10" -Filter "*.cva" -Recurse
                }            
                if ($intCopyOffice -ne 0) {
                    WriteLog -Message "Not possible copy Office bits to local partition" -MessageType Error -Verbose
                    $global:MessageResults="Not possible copy Office bits to local partition"
                    $global:CodeResults=$intCopyOffice
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.ConfigureOffice "fail" $global:MessageResults
                    Out-WinPE -Backuplogs -RemoveJob
                }
                ########################### ADDING LANGUAGE COMPONENTS
                #Version supported Win11 = 16.0.16327.20264
                #Version supported Win10 = 16.0.15128.20246
                #Office language are installed based on LPs added, LIPs are ignored
                #For new office packages review:
                #install.cmd includes
                #set CEPS_LanguageCode=ABA
                #Set OOBEKey=OEMTA
                #OfficeConfig.ini exist
                #Variables on SetVariables helps to identify 
                if (-Not([string]::IsNullOrEmpty($json.JOBREQUEST.Localization.lpinstalled))) { 
                    [string[]]$InstalledLPs=$json.JOBREQUEST.Localization.lpinstalled                    
                    if ($InstalledLPs.Count -gt 0) {
                        WriteLog -Message "Detected $($InstalledLPs.Count) languages, checking Office language package required" -Verbose
                        $OfficeVendorVersion = (Get-Content $officeCVA[0].FullName | Select-String -Pattern "VendorVersion=").ToString().Trim().Replace("VendorVersion=","").Replace("`"","")
                        
                        WriteLog -Message "Office Vendor version detected: $($OfficeVendorVersion)" -Verbose
                        if (-Not(Test-Path -Path (Join-Path $AjoloteDrive "\TOOLS\OfficeLanguageDic.json"))) {
                            WriteLog -Message "Not possble locate dictionary file: $((Join-Path $AjoloteDrive "\TOOLS\OfficeLanguageDic.json"))" -MessageType Error -Verbose
                            $global:MessageResults="Not possble locate dictionary file: $((Join-Path $AjoloteDrive "\TOOLS\OfficeLanguageDic.json"))"
                            $global:CodeResults=404
                            Out-WinPE -Backuplogs -RemoveJob
                        }
                        $OfficeVersion=(Get-Content -Path (Join-Path $AjoloteDrive "\TOOLS\OfficeLanguageDic.json") -Raw | ConvertFrom-Json).OfficeLanguage.ConfigPaths.VendorVersion.$OfficeVendorVersion
                        $OfficeLangs=(Get-Content -Path (Join-Path $AjoloteDrive "\TOOLS\OfficeLanguageDic.json") -Raw | ConvertFrom-Json).OfficeLanguage.$OfficeVersion
                        $hashDic = @{}
                        $ComponentArray = [System.Collections.ArrayList]::new()
                        $LanguagesArray = [System.Collections.ArrayList]::new()
                        foreach ($property in $OfficeLangs.PSObject.Properties) {
                            $hashDic[$property.Name] = $property.Value
                        }
                        foreach ($tag in $InstalledLPs) {
                            if ([string]::IsNullOrEmpty($hashDic[$tag])) {
                                WriteLog -Message "Cannot locate a reference for tag $($tag) on Office language dictionary" -MessageType Error -Verbose
                                $global:MessageResults="Cannot locate a reference for tag $($tag) on Office language dictionary"
                                $global:CodeResults=406
                                Out-WinPE -Backuplogs -RemoveJob
                            }
                            WriteLog -Message "Language tag $($tag) will require component $($hashDic[$tag])" -Verbose
                            if (-Not($ComponentArray.Contains($hashDic[$tag]))) {
                                [void]$ComponentArray.Add($hashDic[$tag])
                            }                            
                        }
                        #adding component list to JOB
                        WriteLog -Message "Updating Job Office language components" -Verbose
                        if ($null -eq $json.JOBREQUEST.ConfigureOffice.lpcomponents) {
                            $json.JOBREQUEST.ConfigureOffice | Add-Member -Name "lpcomponents" -MemberType NoteProperty -Value $ComponentArray
                        } else {
                            $json.JOBREQUEST.ConfigureOffice.lpcomponents=$ComponentArray
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
                        #Connect components share to retrieve packages
                        $DriveComponents = Invoke-MountServer "/componentspath"
                        if ($null -eq $DriveComponents) {
                            WriteLog -Message "Not possible mount Component share" -MessageType Error -Verbose
                            $global:MessageResults="Not possible mount Component share"
                            $global:CodeResults=101
                            Out-WinPE -Backuplogs -RemoveJob
                        }
                        if (-Not(Test-Path -Path (Join-Path $DriveComponents "\OfficeLanguage\$($OfficeVersion)") -PathType Container)) {
                            WriteLog -Message "It was not possible to detect component folder: $((Join-Path $DriveComponents "\OfficeLanguage\$($OfficeVersion)"))" -MessageType Error -Verbose
                            $global:MessageResults="It was not possible to detect component folder: $((Join-Path $DriveComponents "\OfficeLanguage\$($OfficeVersion)"))"
                            $global:CodeResults=404
                            Out-WinPE -Backuplogs -RemoveJob
                        }
                        foreach ($component in $ComponentArray) {
                            if (-Not(Test-Path -Path (Join-Path $DriveComponents "\OfficeLanguage\$($OfficeVersion)\$($component)"))) {
                                WriteLog -Message "Cannot located Office language component folder: $((Join-Path $DriveComponents "\OfficeLanguage\$($OfficeVersion)\$($component)"))" -MessageType Error -Verbose
                                $global:MessageResults="Cannot located Office language component folder: $((Join-Path $DriveComponents "\OfficeLanguage\$($OfficeVersion)\$($component)"))"
                                $global:CodeResults=404
                                Out-WinPE -Backuplogs -RemoveJob
                            }
                            $CompVer=(Join-Path $DriveComponents "\OfficeLanguage\$($OfficeVersion)\$($component)\SW\$($component.Replace("-","."))" )
                            WriteLog -Message "Moving Component folder to HDD: $($CompVer)" -Verbose
                            $intCopyOfficeLang = RunPower -File "cmd.exe" -Params "/c xcopy /sehiy ""$($CompVer)\*"" $($OSDrive)\" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\CopyOffice.log"
                            if ($intCopyOfficeLang -ne 0) {
                                WriteLog -Message "Not possible copy Office language component $($component) to local partition" -MessageType Error -Verbose
                                $global:MessageResults="Not possible copy Office language component $($component) to local partition"
                                $global:CodeResults=$intCopyOfficeLang
                                Update-JobStatus $jobfile $json $json.JOBREQUEST.ConfigureOffice "fail" $global:MessageResults
                                Out-WinPE -Backuplogs -RemoveJob
                            }
                            #Get packages of component
                            #determinate full path 
                            $SourceFolder=(Get-ChildItem -Path $CompVer -Recurse -Attributes Directory | Where-Object {$_.Name -eq "src"})
                            WriteLog -Message "Component ""src"" detected: $($SourceFolder[0].FullName), seraching included packages" -Verbose
                            foreach ($pkg in (Get-ChildItem -Path $SourceFolder[0].FullName -Attributes Directory)) {
                                WriteLog -Message "Detected and adding package: $($pkg.Name)" -Verbose
                                if (-Not($LanguagesArray.Contains($pkg.Name.ToString().ToLower()))) {
                                    [void]$LanguagesArray.Add($pkg.Name.ToString().ToLower())
                                }
                            }
                        }
                        #Modify Config files                        
                        $OfficeFilesPath=(Get-Content -Path (Join-Path $AjoloteDrive "\TOOLS\OfficeLanguageDic.json") -Raw | ConvertFrom-Json).OfficeLanguage.ConfigPaths.$OfficeVersion
                        $OfficeConfigFile=(Join-Path (Join-Path $OSDrive $OfficeFilesPath.OfficeConfig) "OfficeConfig.ini")
                        $OfficeInstallFile=(Join-Path (Join-Path $OSDrive $OfficeFilesPath.OfficeConfig) "Install.cmd")
                        WriteLog -Message "Modifying OfficeConfig.ini [$($OfficeConfigFile)]" -Verbose
                        if (($null -eq $json.JOBREQUEST.Localization.removeus)-OR (-Not($json.JOBREQUEST.Localization.removeus))) {
                            WriteLog -Message "`tLanguageID=en-us, $(([string]$LanguagesArray).Replace(" ",", "))" -Verbose
                        } else {
                            WriteLog -Message "`tLanguageID=$(([string]$LanguagesArray).Replace(" ",", "))" -Verbose
                        }
                        if (-Not(Test-Path -Path $OfficeConfigFile)) {
                            WriteLog -Message "Not possible locate OfficeConfig.ini [$($OfficeConfigFile)]" -MessageType Error -Verbose
                            $global:MessageResults="Not possible locate OfficeConfig.ini [$($OfficeConfigFile)]"
                            $global:CodeResults=404
                            Update-JobStatus $jobfile $json $json.JOBREQUEST.ConfigureOffice "fail" $global:MessageResults
                            Out-WinPE -Backuplogs -RemoveJob
                        }
                        if (($null -eq $json.JOBREQUEST.Localization.removeus)-OR (-Not($json.JOBREQUEST.Localization.removeus))) {
                            "`r`n;FS IMAGE CONFIG`r`n[FSL]`r`nLanguageID=en-us, $(([string]$LanguagesArray).Replace(" ",", "))" | Out-File -FilePath $OfficeConfigFile -Encoding ascii -Append -Force 
                        } else {
                            "`r`n;FS IMAGE CONFIG`r`n[FSL]`r`nLanguageID=$(([string]$LanguagesArray).Replace(" ",", "))" | Out-File -FilePath $OfficeConfigFile -Encoding ascii -Append -Force
                        }                        
                        Copy-Item -Path $OfficeConfigFile -Destination (Join-Path $logs "OfficeConfig.ini") -Force
                        $OfficeSetVars=(Join-Path (Join-Path $OSDrive $OfficeFilesPath.SetVariables) "SetVariables.cmd")
                        WriteLog -Message "Modifying SetVariables.cmd [$($OfficeSetVars)]" -Verbose
                        if (-Not(Test-Path -Path $OfficeSetVars)) {
                            WriteLog -Message "Not possible locate SetVariables.cmd [$($OfficeSetVars)]" -MessageType Error -Verbose
                            $global:MessageResults="Not possible locate SetVariables.cmd [$($OfficeCOfficeSetVarsonfigFile)]"
                            $global:CodeResults=404
                            Update-JobStatus $jobfile $json $json.JOBREQUEST.ConfigureOffice "fail" $global:MessageResults
                            Out-WinPE -Backuplogs -RemoveJob
                        }
                        $ReadCMD=Get-Content -Path $OfficeSetVars
                        $ReadCMD.Replace("set languagecode=ABA","set languagecode=FSL") | Out-File -FilePath $OfficeSetVars -Force -Encoding ascii
                        Copy-Item -Path $OfficeSetVars -Destination (Join-Path $logs "SetVariables.cmd.log") -Force
                        
                        $ReadInstall=Get-Content -Path $OfficeInstallFile
                        $ReadInstall.Replace("set CEPS_LanguageCode=ABA","set CEPS_LanguageCode=FSL") | Out-File -FilePath $OfficeInstallFile -Force -Encoding ascii
                        Copy-Item -Path $OfficeInstallFile -Destination (Join-Path $logs "OfficeCommon_install.cmd.log") -Force

                        #This falg doesn't affect process but was detected on current office install.cmd
                        "FS Image Service" | Out-File -FilePath (Join-Path (Join-Path $OSDrive $OfficeFilesPath.OfficeConfig) "Office1904MMD.flg") -Encoding ascii -Force
                    } else {
                        WriteLog -Message "LPs installed: $($InstalledLPs.Count), no actions required for Office language" -MessageType Warning -Verbose
                    }

                }
                ################################ END OFFICE LANGUAGE CONFIGURATION
            } else {
                WriteLog -Message "OFFICE folder was not found" -MessageType Error -Verbose
                $global:MessageResults="OFFICE folder was not found"
                $global:CodeResults=231
                Update-JobStatus $jobfile $json $json.JOBREQUEST.ConfigureOffice "fail" $global:MessageResults
                Out-WinPE -Backuplogs -RemoveJob
            }
        } else {
            WriteLog -Message "Office Remove was requested, preventing Office installation" -Verbose
        }
       Update-JobStatus $jobfile $json $json.JOBREQUEST.ConfigureOffice "ready" "Successfully prepared Office"
    } elseif (!([string]::IsNullOrEmpty($json.JOBREQUEST.ConfigureOffice.status)) -AND ($json.JOBREQUEST.ConfigureOffice.status.Trim().ToLower() -eq "ready")) {
        WriteLog -Message "ConfigureOffice prepared successfully for setup, continue" -Verbose
    } elseif (!([string]::IsNullOrEmpty($json.JOBREQUEST.ConfigureOffice.status)) -AND ($json.JOBREQUEST.ConfigureOffice.status.Trim().ToLower() -eq "pass")) {
        WriteLog -Message "ConfigureOffice request was already completed, continue" -Verbose
    } elseif (!([string]::IsNullOrEmpty($json.JOBREQUEST.ConfigureOffice.status)) -AND ($json.JOBREQUEST.ConfigureOffice.status.Trim().ToLower() -eq "fail")) {
        WriteLog -Message "ConfigureOffice request marked as fail, return to report" -MessageType Error -Verbose
        $global:MessageResults="ConfigureOffice request marked as fail, return to report"
        $global:CodeResults=1
        Out-WinPE -Backuplogs -RemoveJob
    } else {
        WriteLog -Message "ConfigureOffice request was not expected to receive with status $($json.JOBREQUEST.ConfigureOffice.status)" -MessageType Error -Verbose
    }

    
} else {
    WriteLog -Message "Module not required, continue" -Verbose
}