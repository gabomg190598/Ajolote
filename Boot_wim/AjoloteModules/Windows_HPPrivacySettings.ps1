<#
HP PRIVACY SETTINGS
Version 1.0.3
    Date: 4/23/2024
    Root node: $json.JOBREQUEST.HPPrivacySettings
    value: status
        "new", "fail", "pass"
        "new" means process is running or required, not completed yet
        "fail" process already fail
        "pass" process run successfully
    value: reboot
        boolean, True for detected installed or setup for HP Privacy Settings completed successfully
    Value: error
        Out message
#>

if ($null -ne $json.JOBREQUEST.HPPrivacySettings) {
    #Node exist on JOB
    if ($null -ne $json.JOBREQUEST.HPPrivacySettings.status) {
        #mandatory status value
        if ($json.JOBREQUEST.HPPrivacySettings.status.ToLower() -eq "new") {
            #only NEW is marked as setup process
            #check if drivers was requested on job
            WriteLog -Message "Module HP PRIVACY SETTING required, start detection.." -Verbose
            if ($null -eq $json.JOBREQUEST.Drivers.sysid) { 
                WriteLog -Message "Drivers folder was not requested by job, not possible to continue with this module" -MessageType Error -Verbose
                Update-JobStatus $jobfile $json $json.JOBREQUEST.HPPrivacySettings "fail" "Drivers folder was not requested by job, not possible to continue with this module"
                $global:MessageResults = "Drivers folder was not requested by job, not possible to continue with this module"
                $global:CodeResults = 404
                Out-Windows
            }
            #Confirm that drivers folder exist
            $HPN_Drivers = (Join-Path (Join-Path $AjoloteDrive "DRIVERS") $json.JOBREQUEST.Drivers.sysid) 
            if (-Not(Test-Path -Path $HPN_Drivers -PathType Container)) {
                WriteLog -Message "Drivers folder [$($HPN_Drivers)] doesn't exist, not possible to continue with this module" -MessageType Error -Verbose
                Update-JobStatus $jobfile $json $json.JOBREQUEST.HPPrivacySettings "fail" "Drivers folder [$($HPN_Drivers)] doesn't exist, not possible to continue with this module"
                $global:MessageResults = "Drivers folder [$($HPN_Drivers)] doesn't exist, not possible to continue with this module"
                $global:CodeResults = 405
                Out-Windows
            }
            #Get list of CVA files on drivers folder
            $CVAs = Get-ChildItem -Path $HPN_Drivers -Filter "*.cva" -File -Recurse | Where-Object {$_.Length -gt 0}
            #Cofnirm if HP PRIVACY SETTINGS is installed
            $GetPrivacy = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*hpprivacy*" }

            if ($null -eq $GetPrivacy) {
                WriteLog -Message "It was not possible detect HP Privacy Setting installed on this unit, checking if can be installed" -MessageType Warning -Verbose
                #Search for HP Privacy Settings CVA
                $arrHPPrivacy = [system.collections.arraylist]@()
                foreach ($cva in $CVAs) {
                    if ($null -ne (Get-Variable -Name objCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name objCVA -Force -ErrorAction SilentlyContinue }
                    $objCVA = get-CVAobject -pathfile $cva.fullName
                    if ($objCVA.Title.Trim().ToLower() -like "*hp privacy*") {
                        WriteLog -Message "Found $($objCVA.Title) V.$($objCVA.version)" -Verbose 
                        [void]$arrHPPrivacy.add($objCVA);        
                    }
                }
                if ($null -ne (Get-Variable -Name GetCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetCVA -Force -ErrorAction SilentlyContinue }
                if ($arrHPPrivacy.Count -gt 0 ) {
                    #retrive only latest version
                    $GetCVA = ($arrHPPrivacy | Sort-Object -property Version -Descending | Sort-Object -Property Length)[0]
                } else {
                    WriteLog -Message "Not possible locate CVA for HP Privacy Settings, abort process" -MessageType Error -Verbose
                    $global:MessageResults = "Not possible locate CVA for HP Privacy Settings, abort process"
                    $global:CodeResults = 406
                    Out-Windows 
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
                        }
                        else {
                            $sub3 = ""
                        }
                        
                    }
                    else {
                        if ($GetCVA.Silent.Trim().IndexOf(" ") -gt 0) {
                            $sub2 = $GetCVA.Silent.Split(" ")[0]
                            $sub3 = $GetCVA.Silent.Replace($sub2, "").Trim()
                        }
                        else {
                            $sub2 = $GetCVA.Silent.Trim()
                            $sub3 = ""
                        }
                        
                    }
                    $objResult.file = $sub2
                    $objResult.parameters = $sub3
                    $objResult.silent = $sub2 + $sub3
                    WriteLog -Message "Silent command detected: $($objResult.read)" -Verbose                
                    WriteLog -Message "Silent command required: $($objResult.silent)" -Verbose
                    if (($null -ne $json.JOBREQUEST.HPPrivacySettings.reboot) -AND ($json.JOBREQUEST.HPPrivacySettings.reboot)) {                        
                        WriteLog -Message "After setup, $($GetCVA.Title) still cannot be detected, abort process to review logs" -Verbose
                        $global:MessageResults = "After setup, $($GetCVA.Title) still cannot be detected, abort process to review logs"
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPPrivacySettings "fail" $global:MessageResults
                        $global:CodeResults = 409                     
                        Out-Windows 
                    }
                    #Run setup
                    $RunSetup = Invoke-RunPower -file "cmd.exe" -Params "/c $($GetCVA.Path)\$($objResult.silent)" -WorkDir $GetCVA.Path -OutFile "$($logs)\SetupHPPrivacySettings.log" 
                    if ($null -eq $json.JOBREQUEST.HPPrivacySettings.reboot) {
                        $json.JOBREQUEST.HPPrivacySettings | Add-Member -Name "reboot" -MemberType NoteProperty -Value $true
                    }
                    else {
                        $json.JOBREQUEST.HPPrivacySettings.reboot = $true
                    }
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPPrivacySettings "new" "Setup completed with exit code $($RunSetup)"
                    #Get status, action and message
                    $NotLocatedCode=$true
                    foreach ($err in $GetCVA.ReturnCode) {
                        WriteLog -Message "Comparing CVA Return code line: $($err)" -Verbose
                        if ($err.Contains("=") -AND $err.Contains(":")) {
                            $objReturn = @{}
                            if ($null -ne $err.Split("=")[0]) { $objReturn.Codes = $err.Split("=")[0] } else { $objReturn.Codes = "" }
                            if ($null -ne $err.Split("=")[1]) { $objReturn.Mess = $err.Split("=")[1] } else { $objReturn.Mess = "" }
                            if ($null -ne $objReturn.Codes.Split(":")[0]) { $objReturn.code = $objReturn.Codes.Split(":")[0] } else { $objReturn.code = "0" }
                            if ($null -ne $objReturn.Codes.Split(":")[1]) { $objReturn.status = $objReturn.Codes.Split(":")[1] } else { $objReturn.status = "" }
                            if ($null -ne $objReturn.Codes.Split(":")[2]) { $objReturn.reboot = $objReturn.Codes.Split(":")[2] } else { $objReturn.reboot = "" }                        
                            if ([int]$objReturn.code -eq $RunSetup) {
                                $NotLocatedCode=$false
                                WriteLog -Message "Return Code $($RunSetup) was located on CVA, Status: $($objReturn.status), Reboot: $($objReturn.reboot) and message $($objReturn.Mess)" -Verbose
                                if ($objReturn.status.ToUpper().Trim() -eq "SUCCESS") {
                                    WriteLog -Message "$($GetCVA.Title) was successfully installed, validation required..." -Verbose
                                    if ($objReturn.reboot -eq "REBOOT") {
                                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPPrivacySettings "new" $objReturn.Mess
                                        WriteLog -Message "This result require reboot unit before to continue." -MessageType Warning -Verbose
                                        $global:MessageResults = "This result require reboot unit before to continue."
                                        $global:CodeResults = 3010
                                        Out-Windows 
                                    }
                                    #Vaidate setup
                                    $GetPrivacy = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*hpprivacy*" }
                                    if ($null -eq $GetPrivacy) {
                                        WriteLog -Message "It was not possible detect HP Privacy Setting installed on this unit, checking if can be installed" -MessageType Error -Verbose
                                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPPrivacySettings "fail" "It was not possible detect HP Privacy Setting installed on this unit, checking if can be installed"
                                        $global:MessageResults = "It was not possible detect HP Privacy Setting installed on this unit, checking if can be installed"
                                        $global:CodeResults = 404
                                        Out-Windows
                                    }                           
                                    WriteLog -Message "HP Privacy Settings was detected with name: $($GetPrivacy[0].Name) and version $($GetPrivacy[0].Version)" -Verbose
                                    if ($null -eq $json.JOBREQUEST.HPPrivacySettings.reboot) {
                                        $json.JOBREQUEST.HPPrivacySettings | Add-Member -Name "reboot" -MemberType NoteProperty -Value $true
                                    }
                                    else {
                                        $json.JOBREQUEST.HPPrivacySettings.reboot = $true
                                    }
                                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPPrivacySettings "pass" "HP Privacy Settings was detected with package full name: $($GetPrivacy[0].PackageFullName) and version $($GetPrivacy[0].Version)"
                                } else {
                                    if ($null -eq $json.JOBREQUEST.HPPrivacySettings.reboot) {
                                        $json.JOBREQUEST.HPPrivacySettings | Add-Member -Name "reboot" -MemberType NoteProperty -Value $true
                                    } else {
                                        $json.JOBREQUEST.HPPrivacySettings.reboot = $true
                                    }
                                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPPrivacySettings "fail" "$($GetCVA.Title) error code $($objReturn.code) marked as $($objReturn.status)"
                                    WriteLog -Message "Nothing can do to fix this issue it require to look on log for $($GetCVA.Title)" -MessageType Warning -Verbose
                                    $global:MessageResults = "Nothing can do to fix this issue it require to look on log for $($GetCVA.Title)" 
                                    $global:CodeResults = 410
                                    Out-Windows 
                                }
                            }
                        }
                    }
                    if ($NotLocatedCode) {
                        WriteLog -Message "It was not possible detect code $($RunSetup) on CVA" -MessageType Error -Verbose
                        $global:MessageResults = "It was not possible detect code $($RunSetup) on CVA" 
                        $global:CodeResults = $RunSetup
                        if ($null -eq $json.JOBREQUEST.HPPrivacySettings.reboot) {
                            $json.JOBREQUEST.HPPrivacySettings | Add-Member -Name "reboot" -MemberType NoteProperty -Value $true
                        } else {
                            $json.JOBREQUEST.HPPrivacySettings.reboot = $true
                        }
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPPrivacySettings "fail" $global:MessageResults                        
                        Out-Windows 
                    }
                }
                else {
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPPrivacySettings "fail" "Not possible read CVA Object for HP Privacy Settings, abort process"
                    WriteLog -Message "Not possible read CVA Object for HP Privacy Settings, abort process" -MessageType Error -Verbose
                    $global:MessageResults = "Not possible read CVA Object for HP Privacy Settings, abort process"
                    $global:CodeResults = 407
                    Out-Windows
                }            

            } else {
                WriteLog -Message "HP Privacy Settings was detected with name: $($GetPrivacy[0].Name) and version $($GetPrivacy[0].Version)" -Verbose
                if ($null -eq $json.JOBREQUEST.HPPrivacySettings.reboot) {
                    $json.JOBREQUEST.HPPrivacySettings | Add-Member -Name "reboot" -MemberType NoteProperty -Value $true
                }
                else {
                    $json.JOBREQUEST.HPPrivacySettings.reboot = $true
                }
                Update-JobStatus $jobfile $json $json.JOBREQUEST.HPPrivacySettings "pass" "Detected package installed: $($GetPrivacy[0].PackageFullName)"
            }
        
        }
        elseif ($json.JOBREQUEST.HPPrivacySettings.status.ToLower() -eq "fail") {
            WriteLog -Message "HP Privacy Settings detected status [$($json.JOBREQUEST.HPPrivacySettings.status)] as fail, abort process" -Message Error -Verbose
            $global:MessageResults = "HP Privacy Settings detected status [$($json.JOBREQUEST.HPPrivacySettings.status)] as fail, abort process"
            $global:CodeResults = 6
            Out-Windows
        }
        elseif ($json.JOBREQUEST.HPPrivacySettings.status.ToLower() -eq "pass") {
            WriteLog -Message "HP Privacy settings already installed as successfully, status [$($json.JOBREQUEST.HPPrivacySettings.status)]" -Verbose
        }
        else {
            #value on status is not exppected
            WriteLog -Message "It is not expected to detect status [$($json.JOBREQUEST.HPPrivacySettings.status)], abort process" -Message Error -Verbose
            $global:MessageResults = "It is not expected to detect status [$($json.JOBREQUEST.HPPrivacySettings.status)], abort process"
            $global:CodeResults = 5
            Out-Windows
        }
    }
    else {
        #not found status on JOB
        WriteLog -Message "HP Privacy Settings module is required in job, however status value is missing" -MessageType Error -Verbose
        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPPrivacySettings "fail" "HP Privacy Settings module is required in job, however status value is missing"
        $global:MessageResults = "HP Privacy Settings module is required in job, however status value is missing"
        $global:CodeResults = 4
        Out-Windows
    }
}
else {
    #node not exit on JOB
    WriteLog -Message "This module is not required" -Verbose
}

if ($null -ne (Get-Variable -Name HPN_Drivers -ErrorAction SilentlyContinue)) { Remove-Variable -Name HPN_Drivers -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name CVAs -ErrorAction SilentlyContinue)) { Remove-Variable -Name CVAs -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name GetPrivacy -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetPrivacy -Force -ErrorAction SilentlyContinue }
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
