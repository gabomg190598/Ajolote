<#
    SETUP HP Collaboration Keyboard Software
    Version 1.0.2
    Date: 4/23/2024
    Root node: $json.JOBREQUEST.HPCollaborationKey
    value: status
        "new" "fail" "pass"
        "new" means process is running or required, not completed yet
        "fail" process already fail
        "pass" process run successfully
    Value: installed
        boolean indicate that software was detected
    Value: error
        Out message

#>

#Check if module is required using tag on job
if ($null -ne $json.JOBREQUEST.HPCollaborationKey) {
    #using status to control setup process
    if ($null -ne $json.JOBREQUEST.HPCollaborationKey.status) {
        #Check values
        if ($json.JOBREQUEST.HPCollaborationKey.status.ToLower() -eq "new") {
            WriteLog -Message "Module HP Collaboration Keyboard Software is required, validation started" -Verbose
            #Check if software is installed, this require testing, information was not provided on table too many missing data
            $GetApps=Get-CimInstance -ClassName Win32_Product | Where-Object {$_.Name -like "*Collaboration Keyboard*"}
            if ($null -eq $GetApps) {
                #Software is not installed.
                #This sofware will be provided as part of Drivers, first step is validat that drivers will be provided
                if ($null -eq $json.JOBREQUEST.Drivers.sysid) { 
                    WriteLog -Message "Drivers folder was not requested by job, not possible to continue with this module" -MessageType Error -Verbose
                    $global:MessageResults="Drivers folder was not requested by job, not possible to continue with this module"
                    $global:CodeResults=404
                    Out-Windows
                }
                #Confirm that drivers folder exist
                $HPN_Drivers=(Join-Path (Join-Path $AjoloteDrive "DRIVERS") $json.JOBREQUEST.Drivers.sysid) 
                if (-Not(Test-Path -Path $HPN_Drivers -PathType Container)) {
                    WriteLog -Message "Drivers folder [$($HPN_Drivers)] doesn't exist, not possible to continue with this module" -MessageType Error -Verbose
                    $global:MessageResults="Drivers folder [$($HPN_Drivers)] doesn't exist, not possible to continue with this module"
                    $global:CodeResults=405
                    Out-Windows
                }
                #Get list of CVA files on drivers folder
                $CVAs = Get-ChildItem -Path $HPN_Drivers -Filter "*.cva" -File -Recurse | Where-Object {$_.Length -gt 0}
                #Search for HP Privacy Settings CVA
                $arrayHP = [system.collections.arraylist]@()
                foreach ($cva in $CVAs) {
                    if ($null -ne (Get-Variable -Name objCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name objCVA -Force -ErrorAction SilentlyContinue }
                    $objCVA = get-CVAobject -pathfile $cva.fullName
                    if ($objCVA.Title.Trim().ToLower() -like "*hp collaboration keyboard*")
                    {
                        WriteLog -Message "Found $($objCVA.Title) V.$($objCVA.version)" -Verbose 
                        [void]$arrayHP.add($objCVA);        
                    }
                }
                if ($null -ne (Get-Variable -Name GetCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetCVA -Force -ErrorAction SilentlyContinue }
                if ($arrayHP.Count -gt 0 ) { 
                    $GetCVA = ($arrayHP | Sort-Object -property Version -Descending | Sort-Object -Property Length)[0]
                }
                else {
                    WriteLog -Message "Not possible locate CVA for HP Collaboration Keyboard Software, abort process" -MessageType Error -Verbose
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPCollaborationKey "fail" "Not possible locate CVA for HP Collaboration Keyboard Software, abort process"
                    $global:MessageResults="Not possible locate CVA for HP Collaboration Keyboard Software, abort process"
                    $global:CodeResults=404
                    Out-Windows 
                }
                #Check if previous filter obtains CVA information              
                if ($null -ne $GetCVA) {
                    $GetCVA | Out-Host #Print on Trascript logs
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
                    if (($null -ne $json.JOBREQUEST.HPCollaborationKey.installed) -AND ($json.JOBREQUEST.HPCollaborationKey.installed)) {                        
                        WriteLog -Message "After setup, $($GetCVA.Title) still cannot be detected, abort process to review logs" -Verbose
                        $global:MessageResults = "After setup, $($GetCVA.Title) still cannot be detected, abort process to review logs"
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPCollaborationKey "fail" $global:MessageResults
                        $global:CodeResults = 409                   
                        Out-Windows 
                    }
                    #Run setup
                    $RunSetup = Invoke-RunPower -file "cmd.exe" -Params "/c $($GetCVA.Path)\$($objResult.silent)" -WorkDir $GetCVA.Path -OutFile "$($logs)\SetupHPCollaborationKeyboard.log" 
                    if ($null -eq $json.JOBREQUEST.HPCollaborationKey.installed) {
                        $json.JOBREQUEST.HPCollaborationKey | Add-Member -Name "installed" -MemberType NoteProperty -Value $true
                    }
                    else {
                        $json.JOBREQUEST.HPCollaborationKey.installed = $true
                    }
                    #next line is just to save previous information.
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPCollaborationKey "new" "Setup completed with exit code $($RunSetup)"
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
                                WriteLog -Message "Return Code $($RunSetup) was located on CVA, Status: $($objReturn.status), Reboot: $($objReturn.reboot) and message $($objReturn.Mess)" -Verbose
                                $NotLocatedCode=$false
                                if ($objReturn.status.ToUpper().Trim() -eq "SUCCESS") {
                                    WriteLog -Message "$($GetCVA.Title) was successfully installed, validation required..." -Verbose
                                    if ($objReturn.reboot -eq "REBOOT") {
                                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPCollaborationKey "new" $objReturn.Mess
                                        WriteLog -Message "This result require reboot unit before to continue." -MessageType Warning -Verbose
                                        $global:MessageResults = "This result require reboot unit before to continue."
                                        $global:CodeResults = 3010
                                        Out-Windows 
                                    }
                                    #Vaidate installed software
                                    $GetApps=Get-CimInstance -ClassName Win32_Product | Where-Object {$_.Name -like "*Collaboration Keyboard*"}
                                    if ($null -eq $GetApps) {
                                        WriteLog -Message "It was not possible detect HP Collaboration Keyboard Software installed on this unit" -MessageType Error -Verbose
                                        if ($null -eq $json.JOBREQUEST.HPCollaborationKey.installed) {
                                            $json.JOBREQUEST.HPCollaborationKey | Add-Member -Name "installed" -MemberType NoteProperty -Value $false
                                        }
                                        else {
                                            $json.JOBREQUEST.HPCollaborationKey.installed = $false
                                        }
                                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPCollaborationKey "fail" "It was not possible detect HP Collaboration Keyboard Software installed on this unit, checking if can be installed"
                                        $global:MessageResults = "It was not possible detect HP Collaboration Keyboard Software installed on this unit"
                                        $global:CodeResults = 404
                                        Out-Windows
                                    }
                                    #details of installed software detected
                                    foreach ($app in $GetApps) {
                                        WriteLog -Message "Detected $($app.Name) version $($app.Version) installed as part of Software and features" -Verbose
                                    }
                                    #Create key and update job
                                    if ($null -eq $json.JOBREQUEST.HPCollaborationKey.installed) {
                                        $json.JOBREQUEST.HPCollaborationKey | Add-Member -Name "installed" -MemberType NoteProperty -Value $true
                                    }
                                    else {
                                        $json.JOBREQUEST.HPCollaborationKey.installed = $true
                                    }
                                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPCollaborationKey "pass" "HP Collaboration Keyboard Softwares was installed on this system"
                                } else { 
                                    #Code values is not for SUCCESS, save key, update job and finish process with error
                                    if ($null -eq $json.JOBREQUEST.HPCollaborationKey.installed) {
                                        $json.JOBREQUEST.HPCollaborationKey | Add-Member -Name "installed" -MemberType NoteProperty -Value $false
                                    }
                                    else {
                                        $json.JOBREQUEST.HPCollaborationKey.installed = $false
                                    }
                                    #here can implement switch case when depending on code some workarrounds required.
                                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPCollaborationKey "fail" "$($GetCVA.Title) error code $($objReturn.code) marked as $($objReturn.status)"
                                    WriteLog -Message "Nothing can do to fix this issue it require to look on log for $($GetCVA.Title)" -MessageType Warning -Verbose
                                    $global:MessageResults = "Nothing can do to fix this issue it require to look on log for $($GetCVA.Title)" 
                                    $global:CodeResults = 410
                                    Out-Windows 
                                }
                            }
                        }
                    }
                    if ($NotLocatedCode) {
                        WriteLog -Message "It was not possible detect code $($RunSetup) on CVA" -Message Error -Verbose
                        $global:MessageResults = "It was not possible detect code $($RunSetup) on CVA" 
                        $global:CodeResults = $RunSetup
                        if ($null -eq $json.JOBREQUEST.HPCollaborationKey.installed) {
                            $json.JOBREQUEST.HPCollaborationKey | Add-Member -Name "installed" -MemberType NoteProperty -Value $true
                        } else {
                            $json.JOBREQUEST.HPCollaborationKey.installed = $true
                        }
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPCollaborationKey "fail" $global:MessageResults                        
                        Out-Windows 
                    }
                } else {
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPCollaborationKey "fail" "Not possible read CVA Object for HP Collaboration Keyboard Softwares, abort process"
                    WriteLog -Message "Not possible read CVA Object for HP Collaboration Keyboard Softwares, abort process" -MessageType Error -Verbose
                    $global:MessageResults = "Not possible read CVA Object for HP Collaboration Keyboard Softwares, abort process"
                    $global:CodeResults = 407
                    Out-Windows
                }
  
            } else {
                foreach ($app in $GetApps) {
                    WriteLog -Message "Detected $($app.Name) version $($app.Version) installed as part of Software and features" -Verbose
                }
                if ($null -eq $json.JOBREQUEST.HPCollaborationKey.installed) {
                    $json.JOBREQUEST.HPCollaborationKey | Add-Member -Name "installed" -MemberType NoteProperty -Value $true
                } else {
                    $json.JOBREQUEST.HPCollaborationKey.installed=$true
                }
                Update-JobStatus $jobfile $json $json.JOBREQUEST.HPCollaborationKey "pass" "HP Collaboration Keyboard Software was detected on this system"
            }
        } elseif ($json.JOBREQUEST.HPCollaborationKey.status.ToLower() -eq "pass") {
            WriteLog -Message "Module status marked as pass, continue" -Verbose
        } elseif ($json.JOBREQUEST.HPCollaborationKey.status.ToLower() -eq "fail") {
            WriteLog -Message "Module status marked as fail, abort process" -Verbose
            $global:MessageResults="Module status marked as fail, abort process"
            $global:CodeResults=1
            Out-Windows
        } else {
            WriteLog -Message "This status was not expected on JOB: $($json.JOBREQUEST.HPCollaborationKey.status)" -Verbose
            $global:MessageResults="This status was not expected on JOB: $($json.JOBREQUEST.HPCollaborationKey.status)"
            $global:CodeResults=2
            Out-Windows
        }
    }  
} else {
    WriteLog -Message "This module is not required" -Verbose
}

if ($null -ne (Get-Variable -Name GetApps -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetApps -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name HPN_Drivers -ErrorAction SilentlyContinue)) { Remove-Variable -Name HPN_Drivers -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name CVAs -ErrorAction SilentlyContinue)) { Remove-Variable -Name CVAs -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name arrayHP -ErrorAction SilentlyContinue)) { Remove-Variable -Name arrayHP -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name GetCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetCVA -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name objResult -ErrorAction SilentlyContinue)) { Remove-Variable -Name objResult -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name objCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name objCVA -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name RunSetup -ErrorAction SilentlyContinue)) { Remove-Variable -Name RunSetup -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name NotLocatedCode -ErrorAction SilentlyContinue)) { Remove-Variable -Name NotLocatedCode -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name objReturn -ErrorAction SilentlyContinue)) { Remove-Variable -Name objReturn -Force -ErrorAction SilentlyContinue }