<#
HP Documentation
Version 1.0.4
    Date: 04/23/2024
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

#>

$SW_Title="HP Documentation"
$LocalFound=$false
if ($null -ne $json.JOBREQUEST.HPDocumentation) {
    if ($json.JOBREQUEST.HPDocumentation.status.Tolower() -eq "validate") {
        WriteLog -Message "validate status detected, checking if $($SW_Title) is installed or present on drivers" -Verbose
        if ($null -ne (Get-Variable -Name GetApp -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetApp -Force -ErrorAction SilentlyContinue }
        if (Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\HP_Documentation") {
            WriteLog -Message "Detected $($SW_Title) installed on this system, checking details" -Verbose
            $GetApp=@{}
                $GetApp.Name=(Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\HP_Documentation" -Name "DisplayName")."DisplayName"
                $GetApp.Version=(Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\HP_Documentation" -Name "DisplayVersion")."DisplayVersion"
        }
        if ($null -eq $GetApp) { 
            if (($null -ne $json.JOBREQUEST.Drivers.sysid) -OR ($null -ne $json.JOBREQUEST.HPIADrivers)) {
                if ($null -ne $json.JOBREQUEST.Drivers.sysid) { $LocalDriverPath=(Join-Path (Join-Path $AjoloteDrive "DRIVERS") $json.JOBREQUEST.Drivers.sysid.Trim()) }
                if ($null -ne $json.JOBREQUEST.HPIADrivers) { $LocalDriverPath=(Join-Path $Env:SystemDrive "\HP\Drivers") }                            
                if (Test-Path -Path $LocalDriverPath) { 
                    if ($null -ne (Get-Variable -Name arrayCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name arrayCVA -Force -ErrorAction SilentlyContinue }
                    $arrayCVA = [system.collections.arraylist]@()
                    WriteLog -Message "Drivers folder located on local device, searching for $($SW_Title)" -Verbose
                    foreach ($cva in (Get-ChildItem -Path $LocalDriverPath -Recurse -Filter "*.cva" -File | Where-Object {$_.Length -gt 0})) {
                        if ($null -ne (Get-Variable -Name objCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name objCVA -Force -ErrorAction SilentlyContinue }
                        $objCVA=Get-CVAObject -PathFile $cva.FullName
                        if ($objCVA.Title -like "*$($SW_Title)*") {
                            WriteLog -Message "Found: $($objCVA.Title), version $($objCVA.Version), checking if is valid" -Verbose
                            if (-Not(Test-Path -Path "$($Env:SystemDrive)\System.sav\SW_CVA" -PathType Container)) {New-Item -Path "$($Env:SystemDrive)\System.sav\SW_CVA" -ItemType Directory -Force }
                            Copy-Item -Path $cva.FullName -Destination "$($Env:SystemDrive)\System.sav\SW_CVA\$($cva.Name)" -Force
                            if ($objCVA.Valid) {
                                WriteLog -Message "This setup can be used: $($objCVA.Path)\$($objCVA.Name)" -Verbose
                                [void]$arrayCVA.Add($objCVA);
                                $LocalFound=$true
                                break;
                            }
                        }
                    }
                    if ($LocalFound) {
                        WriteLog -Message "installing $($SW_Title): *cmd.exe /c ""$($arrayCVA[0].SilentFile)"" $($arrayCVA[0].SilentParameters)" -Verbose
                        $RunSetup = Invoke-RunPower -file "cmd.exe" -Params "/c ""$($arrayCVA[0].SilentFile)"" $($arrayCVA[0].SilentParameters)" -WorkDir $arrayCVA[0].Path -OutFile (Join-Path $logs "Setup_$($SW_Title.Replace(" ","_")).log") -Verbose
                        $NotLocatedCode=$true
                        foreach ($err in $arrayCVA[0].ReturnCode) {
                            WriteLog -Message "Comparing CVA Return code line: $($err)" -Verbose
                            if ($err.Contains("=") -AND $err.Contains(":")) {
                                $objReturn = @{}
                                if ($null -ne $err.Split("=")[0]) { $objReturn.Codes = $err.Split("=")[0] } else { $objReturn.Codes = "" }
                                if ($null -ne $err.Split("=")[1]) { $objReturn.Mess = $err.Split("=")[1] } else { $objReturn.Mess = "" }
                                if ($null -ne $objReturn.Codes.Split(":")[0]) { $objReturn.code = $objReturn.Codes.Split(":")[0] } else { $objReturn.code = "0" }
                                if ($null -ne $objReturn.Codes.Split(":")[1]) { $objReturn.status = $objReturn.Codes.Split(":")[1] } else { $objReturn.status = "" }
                                if ($null -ne $objReturn.Codes.Split(":")[2]) { $objReturn.reboot = $objReturn.Codes.Split(":")[2] } else { $objReturn.reboot = "" }                        
                                if ([int]$objReturn.code -eq $RunSetup) {
                                    WriteLog -Message "Return Code $($RunSetup) was located on CVA, Status: $($objReturn.status), Reboot: $($objReturn.reboot) and message $($objReturn.Mess)" -Verbose
                                    $NotLocatedCode=$false
                                    if ($objReturn.status.ToUpper().Trim() -eq "SUCCESS") {
                                        WriteLog -Message "$($arrayCVA[0].Title) was successfully installed, validation required..." -Verbose
                                        if ($objReturn.reboot -eq "REBOOT") {
                                            Update-JobStatus $jobfile $json $json.JOBREQUEST.HPDocumentation "validate" $objReturn.Mess
                                            WriteLog -Message "This result require reboot unit before to continue." -MessageType Warning -Verbose
                                            $global:MessageResults = "This result require reboot unit before to continue."
                                            $global:CodeResults = 3010
                                            Out-Windows 
                                        }
                                        #Vaidate installed software
                                        if (Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\HP_Documentation") {
                                            WriteLog -Message "Detected $($SW_Title) installed on this system, checking details" -Verbose
                                            $GetApp=@{}
                                                $GetApp.Name=(Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\HP_Documentation" -Name "DisplayName")."DisplayName"
                                                $GetApp.Version=(Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\HP_Documentation" -Name "DisplayVersion")."DisplayVersion"
                                        }
                                        if ($null -eq $GetApp) {
                                            WriteLog -Message "$($SW_Title) not found on Software and Features" -MessageType Error -Verbose
                                            $global:MessageResults="$($SW_Title) not found on Software and Features"
                                            $global:CodeResults=$RunSetup
                                            Update-JobStatus $jobfile $json $json.JOBREQUEST.HPDocumentation "fail" $global:MessageResults
                                            Out-Windows
                                        }
                                        WriteLog -Message "It is detected $($GetApp.Name) with version $($GetApp.Version), on this system" -Verbose
                                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPDocumentation "pass" "It is detected $($GetApp.Name) with version $($GetApp.Version), on this system"
                                    } else { 
                                        #Code values is not for SUCCESS, save key, update job and finish process with error
                                        #here can implement switch case when depending on code some workarrounds required.
                                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPDocumentation "fail" "$($arrayCVA[0].Title) error code $($objReturn.code) marked as $($objReturn.status)"
                                        WriteLog -Message "Nothing can do to fix this issue it require to look on log for $($arrayCVA[0].Title)" -MessageType Warning -Verbose
                                        $global:MessageResults = "Nothing can do to fix this issue it require to look on log for $($arrayCVA[0].Title)" 
                                        $global:CodeResults = 410
                                        Out-Windows 
                                    }
                                    break;
                                }
                            }
                        }
                        if ($NotLocatedCode) {
                            WriteLog -Message "It was not possible detect code $($RunSetup) on CVA" -MessageType Error -Verbose
                            $global:MessageResults = "It was not possible detect code $($RunSetup) on CVA" 
                            $global:CodeResults = $RunSetup
                            Update-JobStatus $jobfile $json $json.JOBREQUEST.HPDocumentation "fail" $global:MessageResults                        
                            Out-Windows 
                        }
                    }
                } else {
                    WriteLog -Message "Driver folder required $($LocalDriverPath) is not present on local Drive" -MessageType Error -Verbose
                    $global:MessageResults="Driver folder required $($LocalDriverPath) is not present on local drive"
                    $global:CodeResults=405
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPDocumentation "fail" $global:MessageResults
                    Out-WinPE -Backuplogs -RemoveJob
                }
            } else {
                WriteLog -Message "Drivers are not requested on JOB, not possible to install $($SW_Title)" -MessageType Error -Verbose
                $global:MessageResults="Drivers are not requested on JOB, not possible to install $($SW_Title)"
                $global:CodeResults=404
                Update-JobStatus $jobfile $json $json.JOBREQUEST.HPDocumentation "fail" $global:MessageResults
                Out-WinPE -Backuplogs -RemoveJob
            }
        } else {
            WriteLog -Message "It is detected $($GetApp.Name) with version $($GetApp.Version), on this system" -Verbose
            Update-JobStatus $jobfile $json $json.JOBREQUEST.HPDocumentation "pass" "It is detected $($GetApp.Name) with version $($GetApp.Version), on this system"
        } 
    } elseif  ($json.JOBREQUEST.HPDocumentation.status.Tolower() -eq "pass")  {
        WriteLog -Message "Module $($SW_Title) already executed successfully, continue" -Verbose
    } elseif  ($json.JOBREQUEST.HPDocumentation.status.Tolower() -eq "new")  {
        WriteLog -Message "Module $($SW_Title) status as new not expected at this point, abort process" -MessageType Error -Verbose
        $global:MessageResults="Module $($SW_Title) status as new not expected at this point, abort process" 
        $global:CodeResults=501
        Out-WinPE -Backuplogs -RemoveJob
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
if ($null -ne (Get-Variable -Name GetApp -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetApp -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name SW_Title -ErrorAction SilentlyContinue)) { Remove-Variable -Name SW_Title -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name objCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name objCVA -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name LocalDriverPath -ErrorAction SilentlyContinue)) { Remove-Variable -Name LocalDriverPath -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name arrayCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name arrayCVA -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name NotLocatedCode -ErrorAction SilentlyContinue)) { Remove-Variable -Name NotLocatedCode -Force -ErrorAction SilentlyContinue }