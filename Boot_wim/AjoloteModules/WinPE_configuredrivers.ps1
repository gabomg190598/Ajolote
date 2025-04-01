<#
Version 1.0.0.9
Configure Updates allows to connect unit to share mentioned on Config.xml, download a folder that match with SysID mentioned on JOB.json.
Adding beta option: inyect Storage drivers to WinRE

Expected structure
XXXX
    _INF
    _HPDrivers
    _GBU

XXXX = SYS ID
_INF or _GBU, at least one of those is mandatory


#>
if ($null -ne $json.JOBREQUEST.Drivers) { 
    WriteLog -Message "Driver install was requested" -Verbose
    if (([string]::IsNullOrEmpty($json.JOBREQUEST.Drivers.status)) -OR ($json.JOBREQUEST.Drivers.status.ToLower() -eq "new")) { 
        WriteLog -Message "New Drivers request detected, validating" -Verbose
        if ($null -ne $json.JOBREQUEST.Drivers.sysid) {
            $DriverFolderRoot="$($AjoloteDrive)\DRIVERS\$($json.JOBREQUEST.Drivers.sysid.Trim())"
            ## mount share with drivers
            $MountDriverPoint = Invoke-MountServer "/driverpath"
            if ($null -eq $MountDriverPoint) {
                WriteLog -Message "Not possible mount Driver share" -MessageType Error -Verbose
                $global:MessageResults="Not possible mount Driver share"
                $global:CodeResults=227
                Update-JobStatus $jobfile $json $json.JOBREQUEST.Drivers "fail" $global:MessageResults
                Out-WinPE -Backuplogs -RemoveJob
            } else {
                if (Test-Path -Path "$($MountDriverPoint)\$($json.JOBREQUEST.Drivers.sysid.Trim())" -PathType Container) {
                    WriteLog -Message "Folder $($json.JOBREQUEST.Drivers.sysid.Trim()) was detected on share" -Verbose
                    WriteLog -Message "Cleanup other folder present on local path" -Verbose
                    Get-ChildItem -Path "$($AjoloteDrive)\DRIVERS" -Directory -ErrorAction SilentlyContinue  | Where-Object {$_.Name -ne "$($json.JOBREQUEST.Drivers.sysid.Trim())"} | ForEach-Object { WriteLog -Message "Deleting folder $($_.Name)" -Verbose; Remove-Item -Force -Recurse $_.FullName }  
                    if (-Not(Test-Path -Path $DriverFolderRoot -PathType Container)) {
                        WriteLog -Message "SysID folder doesn't exist on local device, creating" -Verbose
                        New-Item -Path $DriverFolderRoot -ItemType Directory -Force | Out-Host
                    }
                    WriteLog -Message "Copying and updating local folder" -Verbose
                    $UpdateSYSID = Invoke-RunPower -File "cmd.exe" -Params "/c Robocopy ""$($MountDriverPoint)\$($json.JOBREQUEST.Drivers.sysid.Trim())"" $($DriverFolderRoot) /MIR" -WorkDir $PSScriptRoot -OutFile "$($logs)\CopyDrivers_$($json.JOBREQUEST.Drivers.sysid.Trim()).log" -Verbose
                    if (($UpdateSYSID -eq 0) -OR ($UpdateSYSID -eq 1) -OR ($UpdateSYSID -eq 2) -OR ($UpdateSYSID -eq 3) -OR ($UpdateSYSID -eq 5) -OR ($UpdateSYSID -eq 6)) {
                        WriteLog -Message "Successfully updated folder" -Verbose
                    } else {
                        WriteLog -Message "Driver folder $($json.JOBREQUEST.Drivers.sysid.Trim()) was not able to update on local device, check logs" -MessageType Error -Verbose
                        $global:MessageResults="Driver folder $($json.JOBREQUEST.Drivers.sysid.Trim()) was not able to update on local device, check logs"
                        $global:CodeResults=$UpdateSYSID
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.Drivers "fail" $global:MessageResults
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                    #Collect CVA files for Driver Pack report
                    foreach ($cva in (Get-ChildItem -Path $DriverFolderRoot -Filter "*.cva" -File -Recurse)) {
                        if (-Not(Test-Path "$($OSDrive)\system.sav\SW_CVA" -PathType Container)) { New-Item -Path "$($OSDrive)\system.sav\SW_CVA" -ItemType Directory -Force | Out-Host }
                        Copy-Item -Path $cva.FullName -Destination "$($OSDrive)\system.sav\SW_CVA\$($cva.Name)" -Force
                    }
                
                } else {
                    WriteLog -Message "It was not possible detect folder $($MountDriverPoint)\$($json.JOBREQUEST.Drivers.sysid.Trim()) on Drivers share, confirm if already exist on local device" -MessageType Warning -Verbose
                    if (Test-Path -Path $DriverFolderRoot -PathType Container) {
                        WriteLog -Message "Driver folder is already present on local device, using to install drivers" -Verbose
                    } else {
                        WriteLog -Message "Driver folder required $($json.JOBREQUEST.Drivers.sysid.Trim()) is not present on Share neither local paths" -MessageType Error -Verbose
                        $global:MessageResults="Driver folder required $($json.JOBREQUEST.Drivers.sysid.Trim()) is not present on Share neither local paths"
                        $global:CodeResults=228
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.Drivers "fail" $global:MessageResults
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                }
            }
            
            
            if (!(Test-Path "$($DriverFolderRoot)\_INF") -AND !(Test-Path "$($DriverFolderRoot)\_GBU")){
                WriteLog -Message "There was not located any folder to inject in $($json.JOBREQUEST.Drivers.sysid), missing _INF or _GBU folder" -MessageType Warning -Verbose
            }
            
                        
            if (![string]::IsNullOrEmpty($json.JOBREQUEST.Drivers.leavepath)) { #Just copy drivers on specific location
                $RelativePath=$json.JOBREQUEST.Drivers.leavepath.Trim()
                while ($RelativePath.StartsWith("\")) {
                    $RelativePath=$RelativePath.Substring(1,$RelativePath.Length-1)
                }
                while ($RelativePath.EndsWith("\")) {
                    $RelativePath=$RelativePath.Substring(0,$RelativePath.Length-1)
                }
                WriteLog -Message "Drivers will be only placed at $($OSDrive)\$($RelativePath)" -Verbose
                if (Test-Path -Path "$($DriverFolderRoot)\_HPDrivers" -PathType Container) {
                    WriteLog -Message "Moving _HPDrivers\* " -Verbose
                    $MoveDrivers = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /sehiyk $($DriverFolderRoot)\_HPDrivers\* $($OSDrive)\$($RelativePath)\" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\CopySetupdrivers.log" -Verbose
                    
                    if ($MoveDrivers -ne 0) {
                        WriteLog -Message "Failed Copy _HPDrivers Drivers to $($OSDrive)\$($RelativePath)\ - $($MoveDrivers)" -MessageType Error -Verbose
                        $global:MessageResults="Failed Copy _HPDrivers Drivers to $($OSDrive)\$($RelativePath)\ - $($MoveDrivers)"
                        $global:CodeResults=$MoveDrivers
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.Drivers "fail" $global:MessageResults
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                }
                if (Test-Path -Path "$($DriverFolderRoot)\_INF" -PathType Container) {
                    WriteLog -Message "Moving _INF\* " -Verbose
                    $MoveDrivers = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /sehiyk $($DriverFolderRoot)\_INF\* $($OSDrive)\$($RelativePath)\" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\CopyInfdrivers.log" -Verbose
                    if ($MoveDrivers -ne 0) {
                        WriteLog -Message "Failed Copy _INF Drivers to $($OSDrive)\$($RelativePath)\ - $($MoveDrivers)" -MessageType Error -Verbose
                        $global:MessageResults="Failed Copy _INF Drivers to $($OSDrive)\$($RelativePath)\ - $($MoveDrivers)"
                        $global:CodeResults=$MoveDrivers
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.Drivers "fail" $global:MessageResults
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                }
                if (Test-Path -Path "$($DriverFolderRoot)\_GBU" -PathType Container) {
                    WriteLog -Message "Moving _GBU\* " -Verbose
                    $MoveDrivers = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /sehiyk $($DriverFolderRoot)\_GBU\* $($OSDrive)\$($RelativePath)\" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\CopyInfdrivers.log" -Verbose
                    if ($MoveDrivers -ne 0) {
                        WriteLog -Message "Failed Copy _GBU Drivers to $($OSDrive)\$($RelativePath)\ - $($MoveDrivers)" -MessageType Error -Verbose
                        $global:MessageResults="Failed Copy _GBU Drivers to $($OSDrive)\$($RelativePath)\ - $($MoveDrivers)"
                        $global:CodeResults=$MoveDrivers
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.Drivers "fail" $global:MessageResults
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                    
                }
            } else {
                if (Test-Path "$($DriverFolderRoot)\_INF") {
    #####  CUSTOM RULES ###############                               
                    #Base on "Progressive" customer scalation, need to identify 5G fibocom driver to be installed during pp
                    #search HP 5G Mobile Broadband Wireless
                    WriteLog -Message "Searching for HP 5G Mobile Broadband Wireless Driver" -Verbose
                    $CVAs = Get-ChildItem -Path $DriverFolderRoot -Filter "*.cva" -File -Recurse | Where-Object {$_.Length -gt 0}
                    $arrayDRV = [system.collections.arraylist]@()
                    foreach ($cva in $CVAs) {
                        if ($null -ne (Get-Variable -Name objCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name objCVA -Force -ErrorAction SilentlyContinue }
                        $objCVA = get-CVAobject -pathfile $cva.fullName
                        if ($objCVA.Title.Trim().ToLower() -like "*hp 5g mobile broadband wireless*")
                        {
                            WriteLog -Message "[FOUND] $($objCVA.Title) V.$($objCVA.version)" -Verbose 
                            [void]$arrayDRV.add($objCVA);        
                        }
                    }
                    if ($arrayDRV.Count -gt 0) {
                        if ($arrayDRV.Count -gt 1) { WriteLog -Message "Searching HP 5G Mobile Broadband Wireless in CVAs returned more than one match, all will be implemented for PP or RunOnce" -Verbose }
                        foreach ($drv in $arrayDRV) {
                            if (($null -ne $json.JOBREQUEST.AddPPSolution) -AND ($json.JOBREQUEST.AddPPSolution)) { 
                                #For PP is required move as GBU component structure
                                #SW\Name.cva\SWSETUP\DRV\DriverOther\<VendorName>\<Title>[10]\<Version>
                                WriteLog -Message "Preparing $($drv.Title) setup during Post-Processing..." -Verbose
                                #build path
                                $BP_root=(Join-Path $OSDrive "SW")
                                $BP_comp=(Join-Path $BP_root $drv.Name.ToUpper().replace(" ","").Replace(".CVA",".00A"))
                                $BP_stnd=(Join-Path $BP_comp "\SWSETUP\DRV\DriverOther")
                                #Vendor
                                if (-Not([string]::IsNullOrEmpty($drv.Vendor))) {
                                    $BP_vend=(Join-Path $BP_stnd $drv.Vendor.Trim().Replace(" ",""))
                                } else {
                                    $BP_vend=(Join-Path $BP_stnd "FIBOCOM")
                                }
                                #Name
                                if (-Not([string]::IsNullOrEmpty($drv.Title))) {
                                    if ($drv.Title.length -ge 10) {
                                        $BP_Name=(Join-Path $BP_vend $drv.Title.Trim().Replace(" ","").Substring(0,10))
                                    } else {
                                        $BP_Name=(Join-Path $BP_vend $drv.Title.Trim().Replace(" ",""))
                                    }                                    
                                } else {
                                    $BP_Name=(Join-Path $BP_vend "HP5GMOBIL_WWAN")
                                }
                                #Version
                                if (-Not([string]::IsNullOrEmpty($drv.Version))) {
                                    $BP_vers=(Join-Path $BP_Name $drv.Version.Trim().Replace(" ",""))
                                } else {
                                    $BP_vers=(Join-Path $BP_Name "1.0.0")
                                }
                                WriteLog -Message "Ready to copy component to $($BP_vers)" -Verbose

                            } else {
                                WriteLog -Message "Preparing $($drv.Title) setup during RunOnce..." -Verbose
                                $NameREG=(Split-Path $drv.Path -Leaf).Replace(" ","_")
                                #create CMD in case that PPSolution is not present
                                "@echo off" | Out-File -FilePath "$($drv.Path)\CSInstall.cmd" -Encoding ascii -Force
                                "SET log=$($OSDrive)\system.sav\logs\$($NameREG).log" | Out-File -FilePath "$($drv.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                                "echo  =============  INSTALLING $($drv.Title), PLEASE WAIT...   ==================" | Out-File -FilePath "$($drv.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                                "pushd $($OSDrive)\SWSETUP\HP\$($NameREG)" | Out-File -FilePath "$($drv.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                                "dir /b /s $($OSDrive)\SWSETUP\HP\$($NameREG) >> %log% 2>&1" | Out-File -FilePath "$($drv.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                                "start /wait /MIN %~dp0$($drv.silent) >> %log% 2>&1" | Out-File -FilePath "$($drv.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                                "echo *exit /b %ERRORLEVEL% >> %log% 2>&1" | Out-File -FilePath "$($drv.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                                "exit /b %ERRORLEVEL%" | Out-File -FilePath "$($drv.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                                $BP_vers="$($OSDrive)\SWSETUP\HP\$($NameREG)"
                                WriteLog -Message "Ready to copy component to $($BP_vers)" -Verbose
                            }
                            WriteLog -Message "Moving source files" -Verbose
                            WriteLog -Message "*cmd.exe /c xcopy /sehiyk $($drv.Path)\* $($BP_vers)\" -Verbose
                            $MoveDrivers = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /sehiyk $($drv.Path)\* $($BP_vers)\" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\CopyPostSetup.log" -Verbose
                            if ($MoveDrivers -ne 0) {
                                WriteLog -Message "Failed Copy Source Drivers to $($drv.Path)\ -> $($BP_vers)\" -MessageType Error -Verbose
                                $global:MessageResults="Failed Copy Source Drivers to $($drv.Path)\ -> $($BP_vers)\"
                                $global:CodeResults=$MoveDrivers
                                Update-JobStatus $jobfile $json $json.JOBREQUEST.Drivers "fail" $global:MessageResults
                                Out-WinPE -Backuplogs -RemoveJob
                            }
                            if (-Not(Test-Path "$($DriverFolderRoot)\_DRV\$(Split-Path -Path $drv.Path -Leaf)")) {
                                New-Item -Path "$($DriverFolderRoot)\_DRV\$(Split-Path -Path $drv.Path -Leaf)" -ItemType Directory -Force
                            }
                            WriteLog -Message "Moving $($drv.Path) -> $($DriverFolderRoot)\_DRV\$((Split-Path -Path $drv.Path -Leaf))" -Verbose
                            Move-Item -Path $drv.Path -Destination "$($DriverFolderRoot)\_DRV\$((Split-Path -Path $drv.Path -Leaf))" -Force -PassThru | Out-Host
                            #if (Test-Path $drv.Path) { $null = Invoke-RunPower -File "cmd.exe" -Params "/c move $($drv.Path) " -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\RemoveTempfolder.log" -Verbose }
                        }
                    } else {
                        WriteLog -Message "Searching HP 5G Mobile Broadband Wireless in CVAs didn't return a single match, continue" -Verbose
                    }

                    ########### Searching "AMD IPU Driver" and update job, allowing new module run setup to install libraries
                    $SW_Title="AMD*IPU*Driver"
                    $arrayAMD = [system.collections.arraylist]@()
                    $CVAs = Get-ChildItem -Path $DriverFolderRoot -Filter "*.cva" -File -Recurse | Where-Object {$_.Length -gt 0}
                    foreach ($cva in $CVAs) {
                        if ($null -ne (Get-Variable -Name objCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name objCVA -Force -ErrorAction SilentlyContinue }
                        $objCVA = get-CVAobject -pathfile $cva.fullName
                        if ($objCVA.Title.Trim().ToLower() -like "*$($SW_Title)*")
                        {
                            WriteLog -Message "[FOUND] $($objCVA.Title) V.$($objCVA.version)" -Verbose 
                            [void]$arrayAMD.add($objCVA);        
                        }
                    }
                    if ($arrayAMD.Count -gt 0) { 
                        WriteLog -Message "Searching $($SW_Title.Replace('*',' ')) in CVAs returned at least one match, Adding job rule" -Verbose 
                        $AMDRuleupdate = @{
                                "status" = "new"
                        }
                        if ($null -eq $json.JOBREQUEST.HPAMDipu) {
                            $json.JOBREQUEST | Add-Member -Name "HPAMDipu" -MemberType NoteProperty -Value $AMDRuleupdate
                        } else {
                            $json.JOBREQUEST.HPAMDipu=$AMDRuleupdate
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
                        WriteLog -Message "Job updated with AMD IPU Driver rule" -Verbose
                        $json | ConvertTo-Json -Depth 16 | Out-Host
                    }
                        
    ################# CUSTOM RULES END ########################## 
                    WriteLog -Message "Injecting INF drivers" -Verbose
                    $InjectDrivers = RunDism -Params "/image:$($OSDrive)\ /scratchdir:$($OSDrive)\ /add-driver /recurse /driver:$($DriverFolderRoot)\_INF" -ShowProgress $true -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\DismINFdrivers.log"
                    WriteLog -Message "Inject drivers return code $($InjectDrivers)" -Verbose
                    #try to inject storage drivers to  WinRE, to do that folder that contains should be name *storage*
                    #search winre file
                    WriteLog -Message "Trying to inject Storage Drivers to WinRE" -Verbose
                    if (Test-Path -Path (Join-Path $OSDrive "/Windows/System32/Recovery/winre.wim") -PathType Leaf) {
                        #mount winre
                        WriteLog -Message "Mounting WinRE" -Verbose
                        New-Item -Path (Join-Path $OSDrive "mntwinre") -ItemType Directory -Force
                        if (Test-Path (Join-Path $OSDrive "mntwinre") -PathType Container) {
                            $MountWinRE=RunDism -Params "/Mount-Image /ImageFile:""$($OSDrive)\Windows\System32\Recovery\winre.wim"" /index:1 /MountDir:""$($OSDrive)\mntwinre""" -ShowProgress $true -WorkDir "$($PSScriptRoot)\" -OutFile (Join-Path $Logs "WinREUpdates.log")
                            if ($MountWinRE -ne 0) {
                                WriteLog -Message "Not possible mount WinRE image to perform changes, Injecting Storage Drivers" -MessageType Error -Verbose; 
                                $global:MessageResults="Not possible mount WinRE image to perform changes, Injecting Storage Drivers"
                                $global:CodeResults=$MountWinRE
                                Out-WinPE -Backuplogs -RemoveJob
                            }
                            #Search Storage Drivers
                            foreach ($folder in (Get-ChildItem -Path "$($DriverFolderRoot)\_INF" -Directory)) {
                                if ($folder.Name.ToString().ToLower() -like "*storage*") {
                                    WriteLog -Message "Folder detected with Storage driver: $($folder.Name), injecting" -Verbose
                                    $InjectStorageWinRE = RunDism -Params "/image:$($OSDrive)\mntwinre /scratchdir:$($OSDrive)\ /add-driver /recurse /driver:$($folder.FullName)" -ShowProgress $true -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\DismINFdriversWinRE.log"
                                    WriteLog -Message "Inject drivers in WinRE return code: $($InjectStorageWinRE)" -Verbose
                                } else {
                                    WriteLog -Message "Folder detected but not used: $($folder.Name)" -Verbose
                                }                                
                            }
                            WriteLog -Message "Saving changes and unmounting WinRE image" -Verbose
                            #Cleanup unused files and reduce the size of winre.wim
                            $null=RunDism -Params "/image:""$($OSDrive)\mntwinre"" /Cleanup-Image /StartComponentCleanup" -WorkDir "$($PSScriptRoot)\" -OutFile (Join-Path $Logs "WinREDrivers.log") -Verbose
                            #Unmount WinRE and save changes
                            $UnMountWinRE=RunDism -Params "/UnMount-Image /MountDir:""$($OSDrive)\mntwinre"" /Commit" -WorkDir "$($PSScriptRoot)\" -OutFile (Join-Path $Logs "WinREDrivers.log") -Verbose
                            if ($UnMountWinRE -ne 0) {
                                WriteLog -Message "Not possible Save changes on WinRE image, injecting Storage drivers" -MessageType Error -Verbose; 
                                $global:MessageResults="Not possible Save changes on WinRE image, injecting Storage drivers"
                                $global:CodeResults=$UnMountWinRE
                                Out-WinPE -Backuplogs -RemoveJob
                            }
                            Remove-Item -Path (Join-Path $OSDrive "mntwinre") -Force
                        }
                    }                    
                }
                if (Test-Path "$($DriverFolderRoot)\_GBU") {
                    #Inject All drivers
                    WriteLog -Message "Injecting INF(GBU) drivers" -Verbose
                    $InjectDrivers = RunDism -Params "/image:$($OSDrive)\ /scratchdir:$($OSDrive)\ /add-driver /recurse /driver:$($DriverFolderRoot)\_GBU" -ShowProgress $true -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\DismINFdrivers.log"
                    WriteLog -Message "Inject drivers return code $($InjectDrivers)" -Verbose
                    #Copy same folder to C:\ for Setup during Windows phase
                    WriteLog -Message "Copying GBU drivers to HPSETUP" -Verbose
                    $CopyDrivers = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /sehiyk $($DriverFolderRoot)\_GBU\* $($OSDrive)\HPSETUP\" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\CopyGBUdrivers.log" -Verbose
                    ##Create flag
                    $InstallGBUDriversFlag="C:\system.sav\flags\gbudrivers.flg"
                    if (-Not(Test-Path -Path (Split-Path $InstallGBUDriversFlag -Parent) -PathType Container)) { New-Item -Path (Split-Path $InstallGBUDriversFlag -Parent) -ItemType Directory -Force | Out-Null }
                    $json.JOBREQUEST.Drivers.sysid.Trim() | Out-File -FilePath $InstallGBUDriversFlag -Encoding ascii -Force
                    WriteLog -Message "Copy GBU drivers return code $($CopyDrivers)" -Verbose
                }  
                if (Test-Path "$($DriverFolderRoot)\_HPDrivers") {
                    WriteLog -Message "Copying EXE drivers to HPDrivers\" -Verbose
                    $CopyDrivers = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /sehiyk $($DriverFolderRoot)\_HPDrivers\* $($OSDrive)\HPDrivers\" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\CopySetupdrivers.log" -Verbose
                    if ($CopyDrivers -ne 0) {
                        WriteLog -Message "Copy Drivers for HPComplete failed - $($CopyDrivers)" -MessageType Error -Verbose
                        $global:MessageResults="Copy Drivers for HPComplete failed - $($CopyDrivers)"
                        $global:CodeResults=$CopyDrivers
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.Drivers "fail" $global:MessageResults
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                    $XMLs = Get-ChildItem -Path "$($OSDrive)\HPDrivers" -Filter "*.xml" -File
                    if ($null -ne $XMLs){
                        $validid=$false
                        foreach ($xml in $XMLs) {
                            WriteLog -Message "Found file $($xml.Name), check if is valid" -Verbose
                            $hpcomplete = Select-Xml -Path $xml.FullName -XPath "/HPDRIVERS"
                            if ($null -ne $hpcomplete){
                                WriteLog -Message "Detected valid file, retrive Model support" -Verbose
                                $model=$hpcomplete.Node.model
                                if ($model.Contains(",")) {
                                    WriteLog -Message "It include several SysIDs" -Verbose
                                    $Models=$model.Split(",")                            
                                    $Models | ForEach-Object {
                                        WriteLog -Message "found sysID: [$($_)]" -Verbose
                                        if ($_ -eq $SysID) {
                                            $validid=$true
                                            WriteLog -Message "This XML is supported on this unit: [$($validid)]" -Verbose                                   
                                        }
                                    }
                                } else {
                                    WriteLog -Message "Found sysID: [$($model)]"
                                    if ($model -eq $SysID) {
                                        WriteLog -Message "This XML is supported on this unit" -Verbose
                                        $validid=$true
                                    }
                                }
                            }
                        }
                        if ($validid) {
                            WriteLog -Message "At least one XML on contains SysID for this unit, no need to change it" -Verbose
                        } else {
                            foreach ($xml in $XMLs) {
                                WriteLog -Message "Open XML file $($xml.Name) to modify Model allowing to run on any sysID" -MessageType Warning -Verbose
                                $xmlfile = [xml](Get-Content $xml.FullName)
                                $xmlfile.HPDRIVERS.model=""
                                $xmlfile.Save($xml.FullName)
                            }
                        }
                    } else {
                        WriteLog -Message "No XML found on _HPdrivers folder, imminent error" -MessageType Error -Verbose
                        $global:MessageResults="No XML found on _HPdrivers folder, imminent error"
                        $global:CodeResults=225
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.Drivers "fail" $global:MessageResults
                        Out-WinPE -Backuplogs -RemoveJob
                    }
    
                }
            }
             
        } else {
            WriteLog -Message "No sysid provided to install drivers, check configuration file" -MessageType Error -Verbose
            $global:MessageResults="Error no SysID provided on configuration file"
            $global:CodeResults=1
            Update-JobStatus $jobfile $json $json.JOBREQUEST.Drivers "fail" $global:MessageResults
            Out-WinPE -Backuplogs -RemoveJob
        }
        #Write Pass result
        Update-JobStatus $jobfile $json $json.JOBREQUEST.Drivers "pass" "Successfully configured drivers"
        
    } elseif (!([string]::IsNullOrEmpty($json.JOBREQUEST.Drivers.status)) -AND ($json.JOBREQUEST.Drivers.status.Trim().ToLower() -eq "pass")) {
        WriteLog -Message "Drivers request was already completed, continue" -Verbose
    } elseif (!([string]::IsNullOrEmpty($json.JOBREQUEST.Drivers.status)) -AND ($json.JOBREQUEST.Drivers.status.Trim().ToLower() -eq "fail")) {
        WriteLog -Message "Drivers request marked as fail, return to report" -MessageType Error -Verbose
        $global:MessageResults="Drivers request marked as fail, return to report"
        $global:CodeResults=1
        Out-WinPE -Backuplogs -RemoveJob
    } else {
        WriteLog -Message "Drivers request was not expected to receive with status $($json.JOBREQUEST.Drivers.status)" -MessageType Error -Verbose
    }
} else {
    WriteLog -Message "Module not required, continue" -Verbose
}















