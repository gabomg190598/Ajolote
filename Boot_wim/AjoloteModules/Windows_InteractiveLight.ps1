<#
    SETUP HP Interactive Light
    Version 1.0.1
    Date: 10/20/2022
    Root node: $json.JOBREQUEST.InteractiveLight
    value: status
        "new" "fail" "pass"
        "new" means process is running or required, not completed yet
        "fail" process already fail
        "pass" process run successfully
    Value: error
        Out message
    Value: retries
        Integer to control reboots, maximum 5
    
#>

#Check if module is required. 
if ($null -ne $json.JOBREQUEST.InteractiveLight) {
    if ($null -ne $json.JOBREQUEST.InteractiveLight.status) {
        if ($json.JOBREQUEST.InteractiveLight.status.ToLower() -eq "new") {
            WriteLog -Message "Module HP Interactive Light is required, detection started" -Verbose
            #Validate if application is installed
            $GetAppxs=Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*HPInteractiveLight*"} #This will return a value if is present
            if ($null -eq $GetAppxs) {
                #Validate if Drivers are requested
                if ($null -eq $json.JOBREQUEST.Drivers.sysid) {
                    #missing means that was not requested
                    WriteLog -Message "Drivers folder was not requested by job, not possible continue with this module" -MessageType Error -Verbose
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.InteractiveLight "fail" "Drivers folder was not requested by job, not possible continue with this module"    
                    $global:MessageResults="Drivers folder was not requested by job, not possible continue with this module"
                    $global:CodeResults=404
                    Out-Windows;
                }
                #Validate if folder is present, this folder shoul be:
                $HPN_Drivers=$(Join-Path (Join-Path $AjoloteDrive "DRIVERS") $json.JOBREQUEST.Drivers.sysdid) 
                if (-Not(Test-Path -Path $HPN_Drivers -PathType Container)) {
                    #missing drivers folder
                    WriteLog -Message "Drivers folder [$($HPN_Drivers)] is missing, process cannot continue" -MessageType Error -Verbose
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.InteractiveLight "fail" "Drivers folder [$($HPN_Drivers)] is missing, process cannot continue"
                    $global:MessageResults="Drivers folder [$($HPN_Drivers)] is missing, process cannot continue"
                    $global:CodeResults=405;
                    Out-Windows;
                }
                #seaarch all CVAs
                $CVAs=Get-ChildItem -Path $HPN_Drivers -Filter "*.cva" -File -Recurse
                $arrayHPCVAinfo=[System.Collections.ArrayList]@()
                foreach ($cva in $CVAs) {
                    $objCVA=Get-CVAObject -PathFile $cva.FullName
                    if ($objCVA.Title.Trim().ToLower() -like "*hp interactive light*") {
                        WriteLog -Message "Found $($objCVA.Title) with version $($objCVA.Version)" -Verbose
                        [void]$arrayHPCVAinfo.Add($objCVA)
                    }
                }
                #now check if something was detected
                if ($null -ne (Get-Variable -Name GetCVA -ErrorAction SilentlyContinue)) {Remove-Variable -Name GetCVA -Force -ErrorAction SilentlyContinue }
                if ($arrayHPCVAinfo.Count -gt 0) {
                    $GetCVA=($arrayHPCVAinfo | Sort-Object -Property Version -Descending | Sort-Object -Property Length)[0]
                } else {
                    #no one was detected
                    WriteLog -Message "Not possible locate CVA for HP Interactive Light, abort process" -MessageType Error -Verbose
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.InteractiveLight "fail" "Not possible locate CVA for HP Interactive Light, abort process"
                    $global:MessageResults="Not possible locate CVA for HP Interactive Light, abort process"
                    $global:CodeResults=406;
                    Out-Windows;
                }
                if ($null -ne $GetCVA) {
                    $GetCVA | Out-Host
                    $objResult = @{}
                    $objResult.read = $GetCVA.Silent
                    if ($GetCVA.Silent.StartsWith("""")) {
                        $sub = $GetCVA.Silent.Substring(1, $GetCVA.Silent.Length - 1)
                        $rem = $sub.indexOf("""")
                        $sub2 = $sub.Substring(0, $rem)
                        if ($sub.length -gt $rem + 1) {
                            $sub3 = $sub.Substring($rem + 1, ($sub.Length - $sub2.Length - 1))  
                        } else {
                            $sub3 = ""
                        }                        
                    } else {
                        if ($GetCVA.Silent.Trim().IndexOf(" ") -gt 0) {
                            $sub2 = $GetCVA.Silent.Split(" ")[0]
                            $sub3 = $GetCVA.Silent.Replace($sub2, "").Trim()
                        } else {
                            $sub2 = $GetCVA.Silent.Trim()
                            $sub3 = ""
                        }                        
                    }
                    $objResult.file = $sub2
                    $objResult.parameters = $sub3
                    $objResult.silent = $sub2 + $sub3
                    WriteLog -Message "Silent command detected: $($objResult.read)" -Verbose
                    WriteLog -Message "Silent command required: $($objResult.silent)" -Verbose
                    #verify if not tried to install previously
                    if (($null -ne $json.JOBREQUEST.InteractiveLight.installed) -AND ($json.JOBREQUEST.InteractiveLight.installed)) {                        
                        WriteLog -Message "After run setup, process cannot detect HP Interactive Light installed, aborting" -MessageType Error -Verbose
                        if ($null -ne $json.JOBREQUEST.InteractiveLight.error) {
                            $global:MessageResults=$json.JOBREQUEST.InteractiveLight.error
                        } else {
                            $global:MessageResults="After run setup, process cannot detect HP Interactive Light installed, aborting"
                        }
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.InteractiveLight "fail" $global:MessageResults
                        $global:CodeResults=410                     
                        Out-Windows 
                    }
                    $RunSetup = Invoke-RunPower -File "cmd.exe" -Params "/c $($GetCVA.Path)\$($objResult.silent)" -WorkDir $GetCVA.Path -OutFile (Join-Path $logs "SetupInteractiveLight.log")
                    if ($null -eq $json.JOBREQUEST.InteractiveLight.installed) {
                        $json.JOBREQUEST.InteractiveLight | Add-Member -Name "installed" -MemberType NoteProperty -Value $true
                    }
                    else {
                        $json.JOBREQUEST.InteractiveLight.installed = $true
                    }
                    #now rememeber that many codes are mentioned on CVA, to avoid set fix values we'll use those values
                    $NotLocatedCode=$true
                    foreach ($err in $GetCVA.ReturnCode) {
                        WriteLog -Message "Comparing CVA Return code line: $($err)" -Verbose
                        if ($err.Contains("=") -AND $err.Contains(":")) {
                            $objReturn = @{}
                            if ($null-ne $err.Split("=")[0]) { $objReturn.Codes = $err.Split("=")[0] } else { $objReturn.Codes = ""}
                            if ($null-ne $err.Split("=")[1]) { $objReturn.Mess = $err.Split("=")[1] } else { $objReturn.Mess = ""}
                            if ($null -ne $objReturn.Codes.Split(":")[0]) { $objReturn.code = $objReturn.Codes.Split(":")[0]} else { $objReturn.code = "0"}
                            if ($null -ne $objReturn.Codes.Split(":")[1]) { $objReturn.status = $objReturn.Codes.Split(":")[1]} else { $objReturn.status = ""}
                            if ($null -ne $objReturn.Codes.Split(":")[2]) { $objReturn.reboot = $objReturn.Codes.Split(":")[2]} else { $objReturn.reboot = ""}
                            #now just need to compare any of these code vs RunSetup value
                            if ([int]$objReturn.code -eq $RunSetup ) {
                                #now confirm if status is SUCCESS and if REBOOT is required apply it
                                WriteLog -Message "Return Code $($RunSetup) was located on CVA Expected codes, status: $($objReturn.status), reboot label: $($objReturn.reboot) and message: $($objReturn.Mess)" -Verbose
                                $NotLocatedCode=$false
                                if ($objReturn.status.ToUpper().Trim() -eq "SUCCESS") {
                                    WriteLog -Message "HP Interactive Light was successfully installed, validation required..." -Verbose
                                    #now just need to confirm if reboot is required
                                    if ($objReturn.reboot.ToUpper().Trim() -eq "REBOOT") {
                                        WriteLog -Message "This result require reboot unit to apply changes, status will not change to allow validate on next reboot" -MessageType Warning -Verbose
                                        $global:MessageResults="This result require reboot unit to apply changes, status will not change to allow validate on next reboot"
                                        $global:CodeResults=3010; #this code is the magic word, this allows to reboot and try again
                                        Out-Windows;
                                    }
                                    #lets validate now
                                    $GetAppxs=Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*HPInteractiveLight*"} #This will return a value if is present
                                    if ($null -eq $GetAppxs) {
                                        WriteLog -Message "It was not possible to detect HP Interactive Light on this unit, it require review of logs" -MessageType Error -Verbose
                                        Update-JobStatus $jobfile $json $json.JOBREQUEST.InteractiveLight "fail" "It was not possible to detect HP Interactive Light on this unit, it require review of logs"
                                        $global:MessageResults="It was not possible to detect HP Interactive Light on this unit, it require review of logs"
                                        $global:CodeResults=409
                                    }
                                    #successfully installation 
                                    WriteLog -Message "HP Interactive Light was successfully installed on this system" -Verbose
                                    Update-JobStatus $jobfile $json $json.JOBREQUEST.InteractiveLight "pass" "HP Interactive Light was successfully installed on this system"
                                } else {
                                    WriteLog -Message "Setup complete but status for code $($objReturn.code) is not Successfully, $($objReturn.Mess)" -MessageType Error -Verbose
                                    Update-JobStatus $jobfile $json $json.JOBREQUEST.InteractiveLight "fail" "Setup complete but status for code $($objReturn.code) is not Successfully, $($objReturn.Mess)"
                                    $global:MessageResults="Setup complete but status for code $($objReturn.code) is not Successfully, $($objReturn.Mess)"
                                    $global:CodeResults=408;
                                    Out-Windows;
                                }
                            }

                        }
                    }
                    if ($NotLocatedCode) {
                        WriteLog -Message "It was not possible detect code $($RunSetup) on CVA" -Message Error -Verbose
                        $global:MessageResults = "It was not possible detect code $($RunSetup) on CVA" 
                        $global:CodeResults = $RunSetup
                        if ($null -eq $json.JOBREQUEST.InteractiveLight.installed) {
                            $json.JOBREQUEST.InteractiveLight | Add-Member -Name "installed" -MemberType NoteProperty -Value $true
                        } else {
                            $json.JOBREQUEST.InteractiveLight.installed = $true
                        }
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.InteractiveLight "fail" $global:MessageResults                        
                        Out-Windows 
                    }
                } else {
                    WriteLog -Message "Not possible read CVA for HP Interactive Light, abort process" -MessageType Error -Verbose
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.InteractiveLight "fail" "Not possible read CVA for HP Interactive Light, abort process"
                    $global:MessageResults="Not possible read CVA for HP Interactive Light, abort process"
                    $global:CodeResults=407;
                    Out-Windows;
                }
            } else {
                WriteLog -Message "HP Interactive Light was detected on this system, with Name: $($GetAppxs[0].Name) and version: $($GetAppxs[0].Version), marking as completed this module" -Verbose
                if ($null -eq $json.JOBREQUEST.InteractiveLight.installed) {
                    $json.JOBREQUEST.InteractiveLight | Add-Member -Name "installed" -MemberType NoteProperty -Value $true
                }
                else {
                    $json.JOBREQUEST.InteractiveLight.installed = $true
                }
                Update-JobStatus $jobfile $json $json.JOBREQUEST.InteractiveLight "pass" "Package already detected: $($GetAppxs[0].PackageFullName)"
            }
        } elseif ($json.JOBREQUEST.InteractiveLight.status.ToLower() -eq "pass") {
            WriteLog -Message "This module was already executed and marked as successfully" -Verbose
        } elseif ($json.JOBREQUEST.InteractiveLight.status.ToLower() -eq "fail") {
            WriteLog -Message "Detected failure status for this module, abort process" -MessageType Error -Verbose 
            $global:MessageResults="Detected failure status for this module, abort process";
            $global:CodeResults=3; 
            Out-Windows;
        } else {
            WriteLog -Message "Unexpected message was detected on this module status: $($json.JOBREQUEST.InteractiveLight.status), abort process" -MessageType Error -Verbose
            $global:MessageResults="Unexpected message was detected on this module status: $($json.JOBREQUEST.InteractiveLight.status), abort process"
            $global:CodeResults=4;
            Out-Windows;
        }

    } else {
        WriteLog -Message "For Setting Interactive Light it is expected to receive tag status, missing on current job" -MessageType Error -Verbose
        $global:MessageResults="For Setting Interactive Light it is expected to receive tag status, missing on current job";
        $global:CodeResults=2;
        Out-Windows;
    }
} else {
    WriteLog -Message "This module is not required" -Verbose
}

if ($null -ne (Get-Variable -Name HPN_Drivers -ErrorAction SilentlyContinue)) { Remove-Variable -Name HPN_Drivers -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name CVAs -ErrorAction SilentlyContinue)) { Remove-Variable -Name CVAs -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name NotLocatedCode -ErrorAction SilentlyContinue)) { Remove-Variable -Name NotLocatedCode -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name GetCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetCVA -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name objReturn -ErrorAction SilentlyContinue)) { Remove-Variable -Name objReturn -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name rem -ErrorAction SilentlyContinue)) { Remove-Variable -Name rem -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name sub -ErrorAction SilentlyContinue)) { Remove-Variable -Name sub -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name sub2 -ErrorAction SilentlyContinue)) { Remove-Variable -Name sub2 -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name sub3 -ErrorAction SilentlyContinue)) { Remove-Variable -Name sub3 -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name RunSetup -ErrorAction SilentlyContinue)) { Remove-Variable -Name RunSetup -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name Codes -ErrorAction SilentlyContinue)) { Remove-Variable -Name Codes -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name Mess -ErrorAction SilentlyContinue)) { Remove-Variable -Name Mess -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name code -ErrorAction SilentlyContinue)) { Remove-Variable -Name code -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name status -ErrorAction SilentlyContinue)) { Remove-Variable -Name status -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name reboot -ErrorAction SilentlyContinue)) { Remove-Variable -Name reboot -Force -ErrorAction SilentlyContinue } 
if ($null -ne (Get-Variable -Name GetAppxs -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetAppxs -Force -ErrorAction SilentlyContinue } 
if ($null -ne (Get-Variable -Name arrayHPCVAinfo -ErrorAction SilentlyContinue)) { Remove-Variable -Name arrayHPCVAinfo -Force -ErrorAction SilentlyContinue } 
