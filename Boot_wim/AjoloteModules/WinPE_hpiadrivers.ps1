<#
Version 1.1
Apr.12.2024

Find on remote server a repository and place for PPSolution 2.0
#>
$OSRepoPath=(Join-Path $OSDrive "\HP\Drivers")
if ($null -ne $json.JOBREQUEST.HPIADrivers) { 
    if (([string]::IsNullOrEmpty($json.JOBREQUEST.HPIADrivers.status)) -OR ($json.JOBREQUEST.HPIADrivers.status.ToLower() -eq "new")) { 
        WriteLog -Message "New request for HPIA drivers aka HP local Repository has detected" -Verbose
        if (-Not([string]::IsNullOrEmpty($json.JOBREQUEST.HPIADrivers.foldername)) -OR -Not([string]::IsNullOrEmpty($json.JOBREQUEST.HPIADrivers.platforms))) {
            ## mount share with drivers
            $MountDriverPoint = Invoke-MountServer "/driverpath"
            if ($null -eq $MountDriverPoint) {
                WriteLog -Message "Not possible mount Driver share" -MessageType Error -Verbose
                $global:MessageResults="Not possible mount Driver share"
                $global:CodeResults=227
                Update-JobStatus $jobfile $json $json.JOBREQUEST.HPIADrivers "fail" $global:MessageResults
                Out-WinPE -Backuplogs -RemoveJob
            }
            #IF folder name exist
            if (-Not([string]::IsNullOrEmpty($json.JOBREQUEST.HPIADrivers.foldername))) {
                WriteLog -Message "Searching folder name [$($json.JOBREQUEST.HPIADrivers.foldername)]..." -Verbose
                $GetHPIAfolder=(Get-ChildItem -Path $MountDriverPoint -Filter $json.JOBREQUEST.HPIADrivers.foldername.ToString() -Recurse -Directory)
                if (($null -eq $GetHPIAfolder) -AND ([string]::IsNullOrEmpty($json.JOBREQUEST.HPIADrivers.platforms))) {
                    WriteLog -Message "Not possible locate repository folder name $($json.JOBREQUEST.HPIADrivers.foldername), no more option available" -MessageType Error -Verbose
                    $global:MessageResults="Not possible locate repository folder name $($json.JOBREQUEST.HPIADrivers.foldername), no more option available"
                    $global:CodeResults=242
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPIADrivers "fail" $global:MessageResults
                    Out-WinPE -Backuplogs -RemoveJob
                } 
                if ($null -eq $GetHPIAfolder) {
                    WriteLog -Message "Not possible locate repository folder name $($json.JOBREQUEST.HPIADrivers.foldername)" -MessageType Error -Verbose
                    #found invalid folder name, then Work to request repository to online server
                } else {
                    if (($GetHPIAfolder | Measure-Object).Count -gt 1) {
                        WriteLog -Message "There are more than one folder with same name, only one will be used" -MessageType Warning -Verbose
                        $GetHPIAfolder | ForEach-Object {WriteLog -Message "Path: $($_.FullName)" -Verbose}
                    }
                    WriteLog -Message "Located repository folder path: $($GetHPIAfolder[0].FullName)" -Verbose
                    if (-Not(Test-Path (Join-Path $GetHPIAfolder[0].FullName ".repository"))) {
                        WriteLog -Message "Invalid repository structure detected on $($GetHPIAfolder[0].FullName)" -MessageType Error -Verbose
                        $global:MessageResults="Invalid repository structure detected on $($GetHPIAfolder[0].FullName)"
                        $global:CodeResults=244
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPIADrivers "fail" $global:MessageResults
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                    WriteLog -Message "Moving to path: $($OSRepoPath)" -Verbose
                    $CopyDrivers = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /sehiyk $($GetHPIAfolder[0].FullName)\* $($OSRepoPath)\" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\CopyHPIAdrivers.log" -Verbose
                    WriteLog -Message "Copy HPIA drivers repo return code $($CopyDrivers)" -Verbose
                    if ($CopyDrivers -ne 0) {
                        WriteLog -Message "Not possible move HPIA drivers repo to OS partition, return code $($CopyDrivers)" -MessageType Error -Verbose; 
                        $global:MessageResults="Not possible move HPIA drivers repo to OS partition, return code $($CopyDrivers)"
                        $global:CodeResults=$CopyDrivers
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPIADrivers "fail" $global:MessageResults
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPIADrivers "copy" "Copy HPIA drivers repo return code $($CopyDrivers)"
                    Set-ItemProperty -Path (Split-Path $OSRepoPath -Parent) -Name Attributes -Value ((Get-ItemProperty (Split-Path $OSRepoPath -Parent)).Attributes -BOR [io.fileattributes]::Hidden) -ErrorAction SilentlyContinue
                    WriteLog -Message "Scannig CVAs on repository, storage driver must be added to current image..." -Verbose
                    $GetCVas=Get-ChildItem -Path $OSRepoPath -Recurse -Filter "*.cva"
                    $arrCVAs = [system.collections.arraylist]@()
                    $TempDir = (Join-Path $Env:SystemDrive "\Windows\Temp\HPStorageINF")
                    if ($null -eq $GetCVas) {
                        WriteLog -Message "There are no CVAs on local repository, cannot mark as issue, it continue" -MessageType Warning -Verbose
                    } else {                        
                        foreach ($cva in $GetCVas) {
                            $objCVA = Get-CVAObject -PathFile $cva.FullName
                            $foundmark=$false
                            if ($objCVA.Category.Trim().ToLower() -like "*driver*storage*") {
                                WriteLog -Message "Found $($objCVA.Title) V.$($objCVA.version)" -Verbose
                                if (-Not($foundmark)) {
                                    [void]$arrCVAs.add($objCVA); 
                                }
                                $foundmark=$true
                            } elseif ($objCVA.Title.Trim().ToLower() -like "*intel rapid storage*") {
                                WriteLog -Message "Found $($objCVA.Title) V.$($objCVA.version)" -Verbose
                                if (-Not($foundmark)) {
                                    [void]$arrCVAs.add($objCVA); 
                                }
                                $foundmark=$true
                            } elseif ($objCVA.Title.Trim().ToLower() -like "*raid driver*") {
                                WriteLog -Message "Found $($objCVA.Title) V.$($objCVA.version)" -Verbose
                                if (-Not($foundmark)) {
                                    [void]$arrCVAs.add($objCVA); 
                                }
                                $foundmark=$true       
                            }
                        }
                        if ($null -ne $arrCVAs) {
                            #create temp directory
                            if (-Not(Test-Path $TempDir)) { New-Item -Path $TempDir -ItemType Directory -Force;}
                            #extract all SPs
                            foreach ($obj in $arrCVAs) {
                                WriteLog -Message "Search and extract $($obj.Name.Replace(".cva",".exe"))" -Verbose
                                if (Test-Path (Join-Path $obj.Path $obj.Name.Replace(".cva",".exe"))) {
                                    $null =Invoke-RunPower -File "cmd.exe" -Params "/c $((Join-Path $obj.Path $obj.Name.Replace(".cva",".exe"))) /s /e /f ""$((Join-Path $TempDir $obj.Name.Replace('.cva','')))""" -WorkDir $OSRepoPath -OutFile "$($logs)\ExtractSPs.log" -Verbose
                                }
                            }
                            #inject driver extracted
                            WriteLog -Message "Injecting storage drivers" -Verbose
                            $InjectDrivers = RunDism -Params "/image:$($OSDrive)\ /scratchdir:$($OSDrive)\ /add-driver /recurse /driver:$($TempDir)\" -ShowProgress $true -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\DismINFdrivers.log"
                            WriteLog -Message "Inject drivers return code $($InjectDrivers)" -Verbose
                            
                            ###### inject to WinRe
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
                                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPIADrivers "fail" $global:MessageResults
                                        Out-WinPE -Backuplogs -RemoveJob
                                    }
                                    $InjectStorageWinRE = RunDism -Params "/image:$($OSDrive)\mntwinre /scratchdir:$($OSDrive)\ /add-driver /recurse /driver:$($TempDir)" -ShowProgress $true -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\DismINFdriversWinRE.log"
                                    WriteLog -Message "Inject drivers in WinRE return code: $($InjectStorageWinRE)" -Verbose
                                    WriteLog -Message "Saving changes and unmounting WinRE image" -Verbose
                                    #Cleanup unused files and reduce the size of winre.wim
                                    $null=RunDism -Params "/image:""$($OSDrive)\mntwinre"" /Cleanup-Image /StartComponentCleanup" -WorkDir "$($PSScriptRoot)\" -OutFile (Join-Path $Logs "WinREDrivers.log") -Verbose
                                    #Unmount WinRE and save changes
                                    $UnMountWinRE=RunDism -Params "/UnMount-Image /MountDir:""$($OSDrive)\mntwinre"" /Commit" -WorkDir "$($PSScriptRoot)\" -OutFile (Join-Path $Logs "WinREDrivers.log") -Verbose
                                    if ($UnMountWinRE -ne 0) {
                                        WriteLog -Message "Not possible Save changes on WinRE image, injecting Storage drivers" -MessageType Error -Verbose; 
                                        $global:MessageResults="Not possible Save changes on WinRE image, injecting Storage drivers"
                                        $global:CodeResults=$UnMountWinRE
                                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPIADrivers "fail" $global:MessageResults
                                        Out-WinPE -Backuplogs -RemoveJob
                                    }
                                    Remove-Item -Path (Join-Path $OSDrive "mntwinre") -Force                                    
                                }
                            }
                            WriteLog -Message "Removing temporal folder..." -Verbose
                            Remove-Item -Path $TempDir -Recurse -Force
                        } else {
                            WriteLog -Message "No Storage drivers detected" -MessageType Warning -Verbose
                        }
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPIADrivers "pass" "Drivers placed on OS drive for HPIA installation"
                    }
                }

            }
            #IF platform name exist
            if (-Not([string]::IsNullOrEmpty($json.JOBREQUEST.HPIADrivers.platforms))) {
                $RequestPlatforms=$json.JOBREQUEST.HPIADrivers.platforms;
                WriteLog -Message "Requesting repository for $(($RequestPlatforms | Measure-Object).Count) platforms" -Verbose
                WriteLog -Message "This option is not complete yet, it will marked as error... for now" -Verbose
                $global:MessageResults="HPIA repository request is not enabled yet, please provide folder name"
                $global:CodeResults=505
                Update-JobStatus $jobfile $json $json.JOBREQUEST.HPIADrivers "fail" $global:MessageResults
                Out-WinPE -Backuplogs -RemoveJob
            }            

        } else {
            WriteLog -Message "Invalid request submit, only options including: folder name or searching by platform array" -MessageType Error -Verbose
            $global:MessageResults="Invalid request submit, only options including: folder name or searching by platform array"
            $global:CodeResults=240
            Update-JobStatus $jobfile $json $json.JOBREQUEST.HPIADrivers "fail" $global:MessageResults
            Out-WinPE -Backuplogs -RemoveJob
        }
    } elseif (-Not([string]::IsNullOrEmpty($json.JOBREQUEST.HPIADrivers.status)) -AND ($json.JOBREQUEST.HPIADrivers.status.ToLower() -eq "copy")) { 
        WriteLog -Message "First phase of module pass successfully, something break during WinRE storaga driver injection. aborting" -MessageType Error -Verbose
        $global:MessageResults="First phase of module pass successfully, something break during WinRE storaga driver injection. aborting"
        $global:CodeResults=101
        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPIADrivers "fail" $global:MessageResults
        Out-WinPE -Backuplogs -RemoveJob
    } elseif (-Not([string]::IsNullOrEmpty($json.JOBREQUEST.HPIADrivers.status)) -AND ($json.JOBREQUEST.HPIADrivers.status.ToLower() -eq "fail")) { 
        if (-Not([string]::IsNullOrEmpty($json.JOBREQUEST.HPIADrivers.error))) {
            $global:MessageResults=$json.JOBREQUEST.HPIADrivers.error
        } else {
            $global:MessageResults="This module already marked as failed, abort process"
        }
        WriteLog -Message "This module already marked as failed, abort process" -MessageType Error -Verbose
        $global:CodeResults=100
        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPIADrivers "fail" $global:MessageResults
        Out-WinPE -Backuplogs -RemoveJob
    } else {
        WriteLog -Message "This module has not definition for status: $($json.JOBREQUEST.HPIADrivers.status)"
    }
} else {
    WriteLog -Message "This module is not required" -Verbose
}