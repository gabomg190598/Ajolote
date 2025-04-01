<#
HP Documentation
Version 1.0.5
    Date: 4/23/2024
    Root node: $json.JOBREQUEST.HPDocumentation
    value: status
        "new", "fail", "pass", "validate"
        "new" means process is running or required, not completed yet
        "fail" process already fail
        "pass" process run successfully
        "validate" process already copied or confirmed that app is present on Drivers folder
    Value: installed
        boolean to control reboot
    Value: error
        Out message

.NOTES FOR DEVELOP
    Need to add an option to specify component part number like: P013Y9-B2B, this will be used only when go to find into local repository due some sysID are shared and could use different component, i.e. 
SysID: 8B41 was located on component: P013Y9-B2B
Component [P013Y9-B2B] Supports: 14 inch Mobile Workstation PC
Component [P013Y9-B2B] Supports: 16  inch Mobile Workstation PC
Component [P013Y9-B2B] Supports: 830 Notebook PC
Component [P013Y9-B2B] Supports: 840 Notebook PC
Component [P013Y9-B2B] Supports: 860 Notebook PC
Component [P013Y9-B2B] Supports: HP Elite x360 830 13 inch G10 2-in-1 Notebook PC
Component [P013Y9-B2B] Supports: HP EliteBook 830 13 inch G10 Notebook PC
Component [P013Y9-B2B] Supports: HP EliteBook 840 14 inch G10 Notebook PC
Component [P013Y9-B2B] Supports: HP EliteBook 860 16 inch G10 Notebook PC
Component [P013Y9-B2B] Supports: HP ZBook Firefly 14 inch G10 Mobile Workstation PC
Component [P013Y9-B2B] Supports: HP ZBook Firefly 16 inch G10 Mobile Workstation PC

SysID: 8B41 was located on component: P01401-B2B
Component [P01401-B2B] Supports: 1040 Notebook PC
Component [P01401-B2B] Supports: HP Elite x360 1040 14 inch G10 2-in-1 Notebook PC
Component [P01401-B2B] Supports: HP EliteBook 1040 14 inch G10 Notebook PC
#>
$SW_Title="HP Documentation"
$LocalFound=$false
$RemoteFound=$false
#This path is only for GUAD site


if ($null -ne $json.JOBREQUEST.HPDocumentation) {
    WriteLog -Message "$($SW_Title) module, checking status" -Verbose
    if ($json.JOBREQUEST.HPDocumentation.status.Tolower() -eq "new") {
        WriteLog -Message "new status detected, checking if $($SW_Title) is present on drivers" -Verbose
        if (($null -ne $json.JOBREQUEST.Drivers.sysid) -OR ($null -ne $json.JOBREQUEST.HPIADrivers)) {
            if ($null -ne $json.JOBREQUEST.Drivers.sysid) {
                $LocalDriverPath=(Join-Path (Join-Path $AjoloteDrive "DRIVERS") $json.JOBREQUEST.Drivers.sysid.Trim()) 
            }
            if ($null -ne $json.JOBREQUEST.HPIADrivers) {
                $LocalDriverPath=(Join-Path $OSDrive "\HP\Drivers") 
            }     
            if (Test-Path -Path $LocalDriverPath) {
                if ($null -ne (Get-Variable -Name arrayCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name arrayCVA -Force -ErrorAction SilentlyContinue }
                $arrayCVA = [system.collections.arraylist]@()
                WriteLog -Message "Local Drivers folder located, searching for $($SW_Title)" -Verbose                
                foreach ($cva in (Get-ChildItem -Path $LocalDriverPath -Recurse -Filter "*.cva" -File | Where-Object {$_.Length -gt 0})) {
                    if ($null -ne (Get-Variable -Name objCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name objCVA -Force -ErrorAction SilentlyContinue }
                    $objCVA=Get-CVAObject -PathFile $cva.FullName
                    if ($objCVA.Title -like "*$($SW_Title)*") {
                        WriteLog -Message "Found: $($objCVA.Title), version $($objCVA.Version), checking if is valid" -Verbose
                        if ($objCVA.Valid) {
                            WriteLog -Message "This setup can be used: $($objCVA.Path)\$($objCVA.Name)" -Verbose
                            [void]$arrayCVA.Add($objCVA);
                            $LocalFound=$true
                        }
                    }
                }
                if ($LocalFound) {
                    WriteLog -Message "$($SW_Title) was located on local device, process can continue" -Verbose
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPDocumentation "validate" "$($SW_Title) with version $($arrayCVA[0].Version) is ready to be installed"
                } else {
                    WriteLog -Message "It was not possible to locate $($SW_Title) on local device, let's try to search on server repository" -MessageType Warning -Verbose
                    $RemoteDrive = Invoke-MountServer "/localhpdocspath"
                    if ($null -eq $RemoteDrive) {
                        WriteLog -Message "Not possible mount share, or doesn't exist path for local HP Documentation" -MessageType Error -Verbose
                        $global:MessageResults="Not possible mount share, or doesn't exist path for local HP Documentation"
                        $global:CodeResults=101
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPDocumentation "fail" $global:MessageResults
                        Out-WinPE -Backuplogs -RemoveJob
                    } else {
                        if ($null -ne $json.JOBREQUEST.HPDocumentation.sysid) { 
                            $searchid=$json.JOBREQUEST.HPDocumentation.sysid.ToString().Trim()
                        } else {
                            if ($null -ne $json.JOBREQUEST.Drivers.sysid) {
                                $searchid=$json.JOBREQUEST.Drivers.sysid.ToString().Trim()
                            }
                        }
                        if ($null -ne $json.JOBREQUEST.HPDocumentation.pn) { 
                            WriteLog -Message "Share was mounted successfully on drive: $($RemoteDrive)\ searching for Part Number: $($json.JOBREQUEST.HPDocumentation.pn)" -Verbose;
                        } else {
                            if ($null -ne $searchid) {
                                WriteLog -Message "Share was mounted successfully on drive: $($RemoteDrive)\ searching for SysID: $($searchid)" -Verbose
                            } else {
                                WriteLog -Message "Not possible search $($SW_Title) without minimum sysid value" -MessageType Error -Verbose
                                $global:MessageResults="Not possible search $($SW_Title) without minimum sysid value"
                                $global:CodeResults=504
                                Update-JobStatus $jobfile $json $json.JOBREQUEST.HPDocumentation "fail" $global:MessageResults
                                Out-WinPE -Backuplogs -RemoveJob
                            }
                            
                        }
                        foreach ($cva in (Get-ChildItem -Path $RemoteDrive -Recurse -Filter "*.cva" -File)) {
                            $objCVA=Get-CVAObject -PathFile $cva.FullName
                            if ($null -ne $json.JOBREQUEST.HPDocumentation.pn) { 
                                if ((-Not([string]::IsNullOrEmpty($objCVA.PN))) -AND ($objCVA.PN.ToString().ToUpper() -eq $json.JOBREQUEST.HPDocumentation.pn.ToString().Trim().ToUpper())) {
                                    if ($null -ne $json.JOBREQUEST.HPDocumentation.sysid) {
                                        WriteLog -Message "Checking: Part number = $($objCVA.PN) was located but also requires to confirm that supports SysID = $($searchid)" -Verbose
                                        foreach ($id in $objCVA.SysIds) {
                                            if ($id -eq $searchid) {
                                                WriteLog -Message "Found: $($objCVA.Title), version $($objCVA.Version), checking if is valid" -Verbose
                                                if ($objCVA.Valid) {
                                                    WriteLog -Message "This setup can be used: $($objCVA.Path)\$($objCVA.Name)" -Verbose                                            
                                                    [void]$arrayCVA.Add($objCVA);
                                                    $RemoteFound=$true
                                                    break
                                                }
                                            }
                                        }
                                    } else {
                                        WriteLog -Message "Found: $($objCVA.Title), version $($objCVA.Version), checking if is valid" -Verbose
                                        if ($objCVA.Valid) {
                                            WriteLog -Message "This setup can be used: $($objCVA.Path)\$($objCVA.Name)" -Verbose
                                            [void]$arrayCVA.Add($objCVA);                                        
                                            $RemoteFound=$true
                                        }
                                    }                                    
                                }
                            } else {
                                foreach ($id in $objCVA.SysIds) {
                                    if ($id -eq $searchid) {
                                        WriteLog -Message "Found: $($objCVA.Title), version $($objCVA.Version), checking if is valid" -Verbose
                                        if ($objCVA.Valid) {
                                            WriteLog -Message "This setup can be used: $($objCVA.Path)\$($objCVA.Name)" -Verbose                                            
                                            [void]$arrayCVA.Add($objCVA);
                                            $RemoteFound=$true
                                            break
                                        }
                                    }
                                }
                            }                            
                            #if ($RemoteFound) {break;}
                        }
                        if ($RemoteFound) {
                            if ($arrayCVA.Count -ne 1) { 
                                WriteLog -Message "It is not expected that locate more than one component, here detected: $($arrayCVA.Count) ocurrences, not possible select just one" -MessageType Error -Verbose
                                $arrayCVA | ForEach-Object {
                                    WriteLog -Message "Found component Part Number: $($_.PN)" -Verbose 
                                    if ($null -ne $json.JOBREQUEST.HPDocumentation.sysid) {
                                        WriteLog -Message "`tSysID = $($json.JOBREQUEST.HPDocumentation.sysid.ToString()) suports: $($_.Platforms[$json.JOBREQUEST.HPDocumentation.sysid.ToString().Trim()])" -Verbose
                                    }
                                }
                                WriteLog -Message "It is recommended to add specific Part Number to avoid this error or remove additional component" -MessageType Error -Verbose
                                $global:MessageResults="It was detect more than one coinsidences for $($SW_Title) improve query or remove not required folders"
                                $global:CodeResults=501
                                Update-JobStatus $jobfile $json $json.JOBREQUEST.HPDocumentation "fail" $global:MessageResults
                                Out-WinPE -Backuplogs -RemoveJob
                            }
                            WriteLog -Message "Copying from: $($arrayCVA[0].Path)\" -Verbose
                            $CopyFolder=Invoke-RunPower -file "cmd.exe" -Params "/c XCopy /sehiyk ""$($arrayCVA[0].Path)\*"" $($LocalDriverPath)\$($SW_Title.Replace(' ',''))\" -WorkDir $PSScriptRoot -OutFile "$($logs)\Copy$($SW_Title.Replace(' ','_')).log" -Verbose
                            if ($CopyFolder -ne 0) {
                                WriteLog -Message "There was not possible to copy $($SW_Title) folder into Drivers" -MessageType Error -Verbose
                                $global:MessageResults="There was not possible to copy $($SW_Title) folder into Drivers"
                                $global:CodeResults=$CopyFolder
                                Update-JobStatus $jobfile $json $json.JOBREQUEST.HPDocumentation "fail" $global:MessageResults
                                Out-WinPE -Backuplogs -RemoveJob
                            }
                            WriteLog -Message "$($SW_Title) copied to local device, process can continue" -Verbose
                            Update-JobStatus $jobfile $json $json.JOBREQUEST.HPDocumentation "validate" "$($SW_Title) with version $($arrayCVA[0].Version) is ready to be installed"
                        } else {
                            WriteLog -Message "Not possible locate $($SW_Title) in local HP Documentation, also was not located on local folder" -MessageType Error -Verbose
                            $global:MessageResults="Not possible locate $($SW_Title) in local HP Documentation), also was not located on local folder"
                            $global:CodeResults=102
                            Update-JobStatus $jobfile $json $json.JOBREQUEST.HPDocumentation "fail" $global:MessageResults
                            Out-WinPE -Backuplogs -RemoveJob
                        }
                    }
                }

            } else {
                WriteLog -Message "Driver folder required $($json.JOBREQUEST.Drivers.sysid.Trim()) is not present on local paths" -MessageType Error -Verbose
                $global:MessageResults="Driver folder required $($json.JOBREQUEST.Drivers.sysid.Trim()) is not present on local paths"
                $global:CodeResults=405
                Update-JobStatus $jobfile $json $json.JOBREQUEST.HPDocumentation "fail" $global:MessageResults
                Out-WinPE -Backuplogs -RemoveJob
            }

        } else {
            WriteLog -Message "Drivers are not requested on JOB" -MessageType Error -Verbose
            $global:MessageResults="Drivers are not requested on JOB"
            $global:CodeResults=404
            Update-JobStatus $jobfile $json $json.JOBREQUEST.HPDocumentation "fail" $global:MessageResults
            Out-WinPE -Backuplogs -RemoveJob
        }

    } elseif  ($json.JOBREQUEST.HPDocumentation.status.Tolower() -eq "pass")  {
        WriteLog -Message "Module $($SW_Title) already executed successfully, continue" -Verbose
    } elseif  ($json.JOBREQUEST.HPDocumentation.status.Tolower() -eq "validate")  {
        WriteLog -Message "Module $($SW_Title) status as validate require to move to Windows stage, nothing else to do here" -Verbose
    } elseif  ($json.JOBREQUEST.HPDocumentation.status.Tolower() -eq "fail")  {
        WriteLog -Message "Module $($SW_Title) status as fail, abort process" -MessageType Error -Verbose
        $global:MessageResults="Module $($SW_Title) status as fail, abort process"
        $global:CodeResults=500
        Out-WinPE -Backuplogs -RemoveJob
    } else  {
        WriteLog -Message "Module $($SW_Title) unknown status [$($json.JOBREQUEST.HPDocumentation.status)], abort process" -MessageType Error -Verbose
        $global:MessageResults="Module $($SW_Title) unknown status [$($json.JOBREQUEST.HPDocumentation.status)], abort process" 
        $global:CodeResults=501
        Out-WinPE -Backuplogs -RemoveJob
    }
} else {
    WriteLog -Message "This module is not required" -Verbose
}

if ($null -ne (Get-Variable -Name LocalFound -ErrorAction SilentlyContinue)) { Remove-Variable -Name LocalFound -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name RemoteFound -ErrorAction SilentlyContinue)) { Remove-Variable -Name RemoteFound -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name SW_Title -ErrorAction SilentlyContinue)) { Remove-Variable -Name SW_Title -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name LocalDriverPath -ErrorAction SilentlyContinue)) { Remove-Variable -Name LocalDriverPath -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name arrayCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name arrayCVA -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name objCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name objCVA -Force -ErrorAction SilentlyContinue }