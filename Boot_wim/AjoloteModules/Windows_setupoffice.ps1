<#
Update date: 4/10/2024
Update required for new structure of office detected on versions
#Win10 = 16.0.15128.20246
#Win11 = 16.0.16327.20264
#>
if ($null -ne $json.JOBREQUEST.ConfigureOffice.RemoveOffice) { 
    if (!($json.JOBREQUEST.ConfigureOffice.RemoveOffice)) {
        if (([string]::IsNullOrEmpty($json.JOBREQUEST.ConfigureOffice.status)) -OR ($json.JOBREQUEST.ConfigureOffice.status.ToLower() -eq "new") -OR ($json.JOBREQUEST.ConfigureOffice.status.ToLower() -eq "ready")) { 
            WriteLog -Message "ConfigureOffice require to install Office, validating" -Verbose
            Get-ChildItem -Path (Join-Path $env:SystemDrive "SWSETUP") -Attributes D,H,R -Recurse | Out-File -FilePath (Join-Path $logs "ContentSWSETUP.log") -Encoding ascii -Force
            #this path it's used by GBU installer
            #Checking if PreReq1 exis
            if (Test-Path -Path (Join-Path $env:SystemDrive "\SWSETUP\APP\PreReq1\Microsoft")) {
                WriteLog -Message "PreReq1 folder detected, searching for language components" -Verbose
                $FolderComponent=(Get-ChildItem -Path (Join-Path $env:SystemDrive "\SWSETUP\APP\PreReq1\Microsoft") -Attributes Directory)
                if ($null -ne $FolderComponent) {
                    WriteLog -Message "Detected $(($FolderComponent | Measure-Object).Count) folders. installing" -Verbose                 
                    foreach ($folder in $FolderComponent) {
                        WriteLog -Message "`tComponent Name Folder: $($folder.Name)" -Verbose
                        $FolderCompRoot=(Get-ChildItem -Path $folder.FullName -Attributes Directory)
                        WriteLog -Message "`tComponent Version Folder: $($FolderCompRoot.Name)" -Verbose
                        #$FolderCompRev=(Get-ChildItem -Path $FolderCompRoot.FullName -Attributes Directory)                        
                        $FolderCVA=(Get-ChildItem -Path $FolderCompRoot.FullName -Filter "*.cva" -ErrorAction SilentlyContinue)
                        if (Test-Path (Join-Path $FolderCompRoot.FullName "install.cmd")) {
                            $FolderInstaller=(Join-Path $FolderCompRoot.FullName "install.cmd")
                        } 
                        if ($null -ne $FolderCVA) {
                            $Foldersilent = (Get-Content $FolderCVA[0].FullName | Select-String -Pattern "SilentInstall=").ToString().Trim().Replace("SilentInstall=","").Replace("`"","")
                            if ($null -ne $Foldersilent) {
                                $FolderInstaller=(Join-Path $FolderCompRoot.FullName $Foldersilent)
                            } 
                        } 
                        if ($null -eq $FolderInstaller) {
                            WriteLog -Message "Not possible detect an installer for component $($folder.Name)" -MessageType Error -Verbose; 
                            $global:MessageResults="Not possible detect an installer for component $($folder.Name)"
                            $global:CodeResults=405
                            Update-JobStatus $jobfile $json $json.JOBREQUEST.ConfigureOffice "fail" $global:MessageResults
                            Out-Windows
                        }
                        $InstallOfficeLang = Invoke-RunPower -File "cmd.exe" -Params "/c ""$($FolderInstaller)""" -WorkDir "$($FolderCompRoot.FullName)\" -OutFile "$($logs)\InstallOfficeLangs.log"
                        if ($InstallOfficeLang -ne 0) {
                            WriteLog -Message "Something fail instaling Office language component $($folder.Name), review logs. Return to WinPE" -MessageType Error -Verbose 
                            $global:MessageResults="Fail instaling Office language component $($folder.Name)"
                            $global:CodeResults=$InstallOfficeLang
                            Update-JobStatus $jobfile $json $json.JOBREQUEST.ConfigureOffice "fail" $global:MessageResults
                            Out-Windows
                        }
                        WriteLog -Message "Successfully installed $($folder.Name)=[$($InstallOfficeLang)]" -Verbose
                    }
                }
            }
            #Office Commond installer
            #require to define installer path, it could change from component to component, first approach use Office language dic 
            if (Test-Path (Join-Path $AjoloteDrive "\TOOLS\OfficeLanguageDic.json")) {
                WriteLog -Message "Detected OfficeLanguageDic.json, getting office installer path" -Verbose
                #Search for CVA
                $OfficeName="MS Office*Common"
                $CVAs=Get-ChildItem -Path (Join-Path $Env:SystemDrive "\SWSETUP\APP") -Filter "*.cva" -File -Recurse | Where-Object {$_.Length -gt 0}
                $arrFilterCVAs = [system.collections.arraylist]@()
                foreach ($cva in $CVAs) {
                    if ($null -ne (Get-Variable -Name objCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name objCVA -Force -ErrorAction SilentlyContinue }
                    $objCVA = Get-CVAObject -pathfile $cva.fullName
                    if ($objCVA.Title.Trim().ToLower() -like "*$($OfficeName)*") {
                        WriteLog -Message "Found $($objCVA.Title) V.$($objCVA.version)" -Verbose 
                        [void]$arrFilterCVAs.add($objCVA);        
                    }
                }
                if ($arrFilterCVAs.Count -lt 1) {
                    WriteLog -Message "Not possble detect Office CVA for common installation" -MessageType Error -Verbose
                    $global:MessageResults="Not possble detect Office CVA for common installation"
                    $global:CodeResults=404
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.ConfigureOffice "fail" $global:MessageResults
                    Out-Windows
                }
                WriteLog -Message "Detected $($arrFilterCVAs[0].Title), version $($arrFilterCVAs[0].version)" -Verbose
                $OfficeVAVer=$arrFilterCVAs[0].version
                WriteLog -Message "Convert CVA version: $($OfficeVAVer) into 365 Apps version" -Verbose
                $OfficeVersion=(Get-Content -Path (Join-Path $AjoloteDrive "\TOOLS\OfficeLanguageDic.json") -Raw | ConvertFrom-Json).OfficeLanguage.ConfigPaths.VendorVersion.$OfficeVAVer
                WriteLog -Message "365 Apps version retrieved: $($OfficeVersion), getting source path" -Verbose
                $OfficeSRCPath=(Get-Content -Path (Join-Path $AjoloteDrive "\TOOLS\OfficeLanguageDic.json") -Raw | ConvertFrom-Json).OfficeLanguage.ConfigPaths.$OfficeVersion.OfficeConfig
                WriteLog -Message "365 Apps source path: $($OfficeSRCPath)" -Verbose
                
                if ($null -eq $OfficeVersion -OR $null -eq $OfficeSRCPath) {
                    WriteLog -Message "Not possible detect Office Path, abort process" -MessageType Error -Verbose
                    $global:MessageResults="Not possible detect Office Path, abort process"
                    $global:CodeResults=506
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.ConfigureOffice "fail" $global:MessageResults
                    Out-Windows
                }
                $OfficRelativeePath=(Split-Path (Split-Path (Split-Path $OfficeSRCPath -Parent) -Parent) -Parent)
            } else {
                WriteLog -Message "It was not possible to detect OfficeLanguageDic.json, default Office path installation will be used" -MessageType Warning -Verbose
                $OfficRelativeePath="\SWSETUP\APP\PreReq2\Microsoft"              
            }
            $Officepath=(Join-Path $env:SystemDrive $OfficRelativeePath)
            WriteLog -Message "Office installer path required will found at $($OfficePath)" -Verbose

            if (Test-Path -Path $Officepath -PathType Container) {
                WriteLog -Message "Detected folder structure for install Office" -Verbose
                $getComp=Get-ChildItem -Path $Officepath -Attributes Directory
                if ($null -eq $getComp) {
                    WriteLog -Message "It seems like unexpected folder structure found on GBU Office installer. Missing [Component] folder in $($Officepath)" -MessageType Error -Verbose; 
                    $global:MessageResults="Office installation fails, folder not found: Component"
                    $global:CodeResults=404
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.ConfigureOffice "fail" $global:MessageResults
                    Out-Windows
                }
                $officecomp=$getComp[0].FullName
                $getVer=Get-ChildItem -Path $officecomp -Attributes Directory
                if ($null -eq $getVer) {
                    WriteLog -Message "It seems like unexpected folder structure found on GBU Office installer. Missing [Version] folder in $($officecomp)" -MessageType Error -Verbose; 
                    $global:MessageResults="Office installation fails, folder not found: Version"
                    $global:CodeResults=404
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.ConfigureOffice "fail" $global:MessageResults
                    Out-Windows
                }
                $srtPathOffice=$getVer[0].FullName
                if (Test-Path $srtPathOffice) {
                    Push-Location $srtPathOffice
                    WriteLog -Message "Installing Office package" -Verbose
                    $officeCVA=Get-ChildItem -Path $srtPathOffice -Filter "*.cva"
                    if ($null -eq $officeCVA) {
                        WriteLog -Message "No CVA found, using default values" -MessageType Warning -Verbose
                        $cmdOffice="$($srtPathOffice)\install.cmd"
                        $SWTitle="Microsoft 360"
                    } else {
                        WriteLog -Message "Build installer path based on CVA found" -Verbose
                        $silent = (Get-Content $officeCVA[0].FullName | Select-String -Pattern "SilentInstall=").ToString().Trim().Replace("SilentInstall=","").Replace("`"","")
                        $OfficeVer = (Get-Content $officeCVA[0].FullName | Select-String -Pattern "VendorVersion=").ToString().Trim().Replace("VendorVersion=","").Replace("`"","")
                        WriteLog -Message "Office version = $($OfficeVer)" -Verbose
                        $cmdOffice="$($srtPathOffice)\$($silent)"
                        if (!(Test-Path $cmdOffice)) {WriteLog -Message "Not possible locate file: $($cmdOffice), use default value" -MessageType Warning -Verbose; $cmdOffice="$($srtPathOffice)\install.cmd"}
                        $GetCVA = Get-CVAObject -pathfile $officeCVA[0].FullName
                        $SWTitle=$GetCVA.Title
                    }
                    
                    $InstallOffice = Invoke-RunPower -File "cmd.exe" -Params "/c $($cmdOffice)" -WorkDir "$($srtPathOffice)\" -OutFile "$($logs)\InstallOffice.log"
                    if ($InstallOffice -ne 0) {
                        WriteLog -Message "Something fail instaling Office, review logs. Return to WinPE" -MessageType Error -Verbose 
                        $global:MessageResults="Office installation fails"
                        $global:CodeResults=$InstallOffice
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.ConfigureOffice "fail" $global:MessageResults
                        Out-Windows
                    }
                    Pop-Location
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.ConfigureOffice "pass" "Successfully installed Officie"
                    WriteLog -Message "Successfully installed $($SWTitle)=[$($InstallOffice)]" -Verbose
                    #cleaning path
                    Start-Sleep -Seconds 10   
                    #Removing office language path
                    if (Test-Path -Path (Join-Path $env:SystemDrive "\SWSETUP\APP\PreReq1")) {
                        WriteLog -Message "Cleaning path: $((Join-Path $env:SystemDrive "\SWSETUP\APP\PreReq1"))" -Verbose
                        Remove-Item -Path (Join-Path $env:SystemDrive "\SWSETUP\APP\PreReq1") -Force -Recurse
                        if (Test-Path -Path (Join-Path $env:SystemDrive "\SWSETUP\APP\PreReq1")) { 
                            WriteLog -Message "It was not possible to remove  $((Join-Path $env:SystemDrive "\SWSETUP\APP\PreReq1"))" -MessageType Warning -Verbose
                        }
                    }
                    $GetTypeSW=(Split-Path $Officepath -Parent)
                    if (Test-Path -Path $GetTypeSW) {
                        WriteLog -Message "Cleaning path: $($GetTypeSW)" -Verbose
                        Remove-Item -Path $GetTypeSW -Force -Recurse
                        if (Test-Path -Path $GetTypeSW) { 
                            WriteLog -Message "It was not possible to remove  $($GetTypeSW)" -MessageType Warning -Verbose
                        }
                    }
                    Start-Sleep -Seconds 5
                    if ((Get-ChildItem -Path (Join-Path $env:SystemDrive "\SWSETUP\APP") -Directory | Measure-Object).Count -eq 0) {
                        WriteLog -Message "Cleaning path: $((Join-Path $env:SystemDrive "\SWSETUP\APP"))" -Verbose
                        Remove-Item -Path (Join-Path $env:SystemDrive "\SWSETUP\APP") -Force -Recurse
                        if (Test-Path -Path (Join-Path $env:SystemDrive "\SWSETUP\APP")) { 
                            WriteLog -Message "It was not possible to remove  $((Join-Path $env:SystemDrive "\SWSETUP\APP"))" -MessageType Warning -Verbose
                        }
                    }
                    Start-Sleep -Seconds 5
                    if ((Get-ChildItem -Path (Join-Path $env:SystemDrive "SWSETUP") -Directory | Measure-Object).Count -eq 0) {
                        WriteLog -Message "Cleaning path: $((Join-Path $env:SystemDrive "SWSETUP"))" -Verbose
                        Remove-Item -Path (Join-Path $env:SystemDrive "SWSETUP") -Force -Recurse
                        if (Test-Path -Path (Join-Path $env:SystemDrive "SWSETUP")) { 
                            WriteLog -Message "It was not possible to remove  $((Join-Path $env:SystemDrive "SWSETUP"))" -MessageType Warning -Verbose
                        }
                    }
                }

            } else {
                WriteLog -Message "Not found Office installer on path $($Officepath), stop process." -Verbose
                $global:MessageResults="Not found Office installer on path $($Officepath), stop process."
                $global:CodeResults=404
                Update-JobStatus $jobfile $json $json.JOBREQUEST.ConfigureOffice "fail" $global:MessageResults
                Out-Windows
            }
        } else {
            WriteLog -Message "Office setup was already processed with result: $($json.JOBREQUEST.ConfigureOffice.status)" -Verbose
        }
    } else {
        WriteLog -Message "Since Office was requested to remove, there are no action at this point." -Verbose
    }
    
} else {
    WriteLog -Message "Module not required, continue" -Verbose
}

