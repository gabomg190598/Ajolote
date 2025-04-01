<#
HP Power Manager - CMIT
Version 1.0.2
    Date: 04/23/2024
    Root node: $json.JOBREQUEST.HPPowerManager
    value: status
        "new", "fail", "pass"
        "new" means process is running or required, not completed yet
        "fail" process already fail
        "pass" process run successfully
    Value: error
        Out message
    Value: reboot
        boolean to mark that at least one time has been executed and prevent infinity loops
#>
$SW_Title="HP Power Manager"
$SearchAppx="hppowermanager" 
if ($null -ne $json.JOBREQUEST.HPPowerManager) {
    if ($null -ne $json.JOBREQUEST.HPPowerManager.status) {
        if ($json.JOBREQUEST.HPPowerManager.status.ToLower() -eq "new") {
            <########################################################################
                        NEW SETUP
            ##########################################################################>
            #check if drivers was requested on job
            if ($null -eq $json.JOBREQUEST.Drivers.sysid) { 
                WriteLog -Message "Drivers folder was not requested by job, not possible to continue with this module" -MessageType Error -Verbose
                Update-JobStatus $jobfile $json $json.JOBREQUEST.HPPowerManager "fail" "Drivers folder was not requested by job, not possible to continue with this module"
                $global:MessageResults = "Drivers folder was not requested by job, not possible to continue with this module"
                $global:CodeResults = 404
                Out-Windows
            }
            #Confirm that drivers folder exist
            $HPN_Drivers = (Join-Path (Join-Path $AjoloteDrive "DRIVERS") $json.JOBREQUEST.Drivers.sysid) 
            if (-Not(Test-Path -Path $HPN_Drivers -PathType Container)) {
                WriteLog -Message "Drivers folder [$($HPN_Drivers)] doesn't exist, not possible to continue with this module" -MessageType Error -Verbose
                $global:MessageResults = "Drivers folder [$($HPN_Drivers)] doesn't exist, not possible to continue with this module"
                $global:CodeResults = 405
                Update-JobStatus $jobfile $json $json.JOBREQUEST.HPPowerManager "fail" $global:MessageResults
                Out-Windows
            }
            #Get list of CVA files on drivers folder
            $CVAs = Get-ChildItem -Path $HPN_Drivers -Filter "*.cva" -File -Recurse | Where-Object {$_.Length -gt 0}

            #Cofnirm if $($SW_Title) is installed*
            $GetInstalledAppx = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*$($SearchAppx)*" }

            if ($null -eq $GetInstalledAppx) {
                WriteLog -Message "It was not possible detect $($SW_Title) installed on this unit, checking if can be installed" -MessageType Warning -Verbose
                #Search for $($SW_Title) CVA
                $arrHPAppx = [system.collections.arraylist]@()
                foreach ($cva in $CVAs) {
                    if ($null -ne (Get-Variable -Name objCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name objCVA -Force -ErrorAction SilentlyContinue }
                    $objCVA = get-CVAobject -pathfile $cva.fullName
                    if ($objCVA.Title.Trim().ToLower() -like "*$($SW_Title.ToLower())*") {
                        WriteLog -Message "Found $($objCVA.Title) V.$($objCVA.version), checking if can be used..." -Verbose 
                        if ($objCVA.Valid) {
                            [void]$arrHPAppx.add($objCVA);
                            WriteLog -Message "`t$($objCVA.Title) can use for setup" -Verbose 
                        } else {
                            WriteLog -Message "`tNot possible to use $($objCVA.Title), CVA information and/or files present not allow to execute silent command" -MessageType Error -Verbose
                        }
                                
                    }
                }
                if ($null -ne (Get-Variable -Name GetCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetCVA -Force -ErrorAction SilentlyContinue }
                if ($arrHPAppx.Count -gt 0 ) {
                    #retrive only latest version
                    $GetCVA = ($arrHPAppx | Sort-Object -property Version -Descending | Sort-Object -Property Length)[0]
                }
                else {
                    WriteLog -Message "Not possible locate CVA for $($SW_Title), abort process" -MessageType Error -Verbose
                    $global:MessageResults = "Not possible locate CVA for $($SW_Title), abort process"
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPPowerManager "fail" $global:MessageResults
                    $global:CodeResults = 406
                    Out-Windows 
                }
                if ($null -ne $GetCVA) {
                    $GetCVA | Out-Host
                                        
                    WriteLog -Message "Silent command detected: $($GetCVA.Silent)" -Verbose                
                    WriteLog -Message "Silent command required: $($GetCVA.SilentFile) $($GetCVA.SilentParameters)" -Verbose

                    if (($null -ne $json.JOBREQUEST.HPPowerManager.reboot) -AND ($json.JOBREQUEST.HPPowerManager.reboot)) {                        
                        WriteLog -Message "After setup, $($GetCVA.Title) still cannot be detected, abort process to review logs" -Verbose
                        $global:MessageResults = "After setup, $($GetCVA.Title) still cannot be detected, abort process to review logs"
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPPowerManager "fail" $global:MessageResults
                        $global:CodeResults = 409
                        Out-Windows 
                    }
                    #Run setup
                    $RunSetup = Invoke-RunPower -file "cmd.exe" -Params "/c $($GetCVA.Path)\$($GetCVA.SilentFile) $($GetCVA.SilentParameters)" -WorkDir $GetCVA.Path -OutFile "$($logs)\Setup$($SW_Title.Replace(' ','')).log" 
                    if ($null -eq $json.JOBREQUEST.HPPowerManager.reboot) {
                        $json.JOBREQUEST.HPPowerManager | Add-Member -Name "reboot" -MemberType NoteProperty -Value $true
                    }
                    else {
                        $json.JOBREQUEST.HPPowerManager.reboot = $true
                    }
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPPowerManager "new" "Setup completed with exit code $($RunSetup)"
                                         
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
                                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPPowerManager "new" $objReturn.Mess
                                        WriteLog -Message "This result require reboot unit before to continue." -MessageType Warning -Verbose
                                        $global:MessageResults = "This result require reboot unit before to continue."
                                        $global:CodeResults = 3010
                                        Out-Windows 
                                    }
                                    #Vaidate setup
                                    $GetInstalledAppx = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*$($SearchAppx)*" }
                                    if ($null -eq $GetInstalledAppx) {
                                        WriteLog -Message "It was not possible detect $($SW_Title) installed on this unit, please review logs" -MessageType Error -Verbose
                                        $global:MessageResults = "It was not possible detect $($SW_Title) installed on this unit, please review logs"
                                        $global:CodeResults = 404
                                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPPowerManager "fail" $global:MessageResults
                                        Out-Windows
                                    }                           
                                    WriteLog -Message "$($SW_Title) was detected with name: $($GetInstalledAppx[0].Name) and version $($GetInstalledAppx[0].Version)" -Verbose                                    
                                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPPowerManager "pass" "$($SW_Title) was detected with package full name: $($GetInstalledAppx[0].PackageFullName) and version $($GetInstalledAppx[0].Version)"
                                }
                                else {
                                    WriteLog -Message "Nothing can do to fix this issue it require to look on log for $($GetCVA.Title)" -MessageType Warning -Verbose
                                    $global:MessageResults = "$($GetCVA.Title) error code $($objReturn.code) marked as $($objReturn.status)"
                                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPPowerManager "fail" $global:MessageResults
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
                        if ($null -eq $json.JOBREQUEST.HPPowerManager.reboot) {
                            $json.JOBREQUEST.HPPowerManager | Add-Member -Name "reboot" -MemberType NoteProperty -Value $true
                        } else {
                            $json.JOBREQUEST.HPPowerManager.reboot = $true
                        }
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPPowerManager "fail" $global:MessageResults                        
                        Out-Windows 
                    }
                }
                else {
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPPowerManager "fail" "Not possible read CVA Object for $($SW_Title), abort process"
                    WriteLog -Message "Not possible read CVA Object for $($SW_Title), abort process" -MessageType Error -Verbose
                    $global:MessageResults = "Not possible read CVA Object for $($SW_Title), abort process"
                    $global:CodeResults = 407
                    Out-Windows
                }            

            } else {
                WriteLog -Message "$($SW_Title) was detected with name: $($GetInstalledAppx[0].Name) and version $($GetInstalledAppx[0].Version)" -Verbose
                if ($null -eq $json.JOBREQUEST.HPPowerManager.reboot) {
                    $json.JOBREQUEST.HPPowerManager | Add-Member -Name "reboot" -MemberType NoteProperty -Value $true
                }
                else {
                    $json.JOBREQUEST.HPPowerManager.reboot = $true
                }
                Update-JobStatus $jobfile $json $json.JOBREQUEST.HPPowerManager "pass" "Detected package installed: $($GetInstalledAppx[0].PackageFullName)"
            }

            <########################## END NEW SETUP ################################>
        } elseif ($json.JOBREQUEST.HPPowerManager.status.ToLower() -eq "pass") { 
            WriteLog -Message "$($SW_Title) already installed as successfully, status [$($json.JOBREQUEST.HPPowerManager.status)]" -Verbose
        } elseif ($json.JOBREQUEST.HPPowerManager.status.ToLower() -eq "fail") {
            WriteLog -Message "$($SW_Title) detected status [$($json.JOBREQUEST.HPPowerManager.status)] as fail, abort process" -Message Error -Verbose
            $global:MessageResults = "$($SW_Title) detected status [$($json.JOBREQUEST.HPPowerManager.status)] as fail, abort process"
            $global:CodeResults = 6
            Out-Windows
        } else {
            WriteLog -Message "It is not expected to detect status [$($json.JOBREQUEST.HPPowerManager.status)], abort process" -Message Error -Verbose
            $global:MessageResults = "It is not expected to detect status [$($json.JOBREQUEST.HPPowerManager.status)], abort process"
            $global:CodeResults = 5
            Out-Windows
        }
    } else {
        WriteLog -Message "$($SW_Title) module is required in job, however status value is missing" -MessageType Error -Verbose
        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPPowerManager "fail" "$($SW_Title) module is required in job, however status value is missing"
        $global:MessageResults = "$($SW_Title) module is required in job, however status value is missing"
        $global:CodeResults = 4
        Out-Windows
    }
} else {
    WriteLog -Message "This module is not required" -Verbose
}

if ($null -ne (Get-Variable -Name SearchAppx -ErrorAction SilentlyContinue)) { Remove-Variable -Name SearchAppx -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name HPN_Drivers -ErrorAction SilentlyContinue)) { Remove-Variable -Name HPN_Drivers -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name SW_Title -ErrorAction SilentlyContinue)) { Remove-Variable -Name SW_Title -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name CVAs -ErrorAction SilentlyContinue)) { Remove-Variable -Name CVAs -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name GetInstalledApp -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetInstalledApp -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name arrHPAppx -ErrorAction SilentlyContinue)) { Remove-Variable -Name arrHPAppx -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name objCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name objCVA -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name GetCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetCVA -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name RunSetup -ErrorAction SilentlyContinue)) { Remove-Variable -Name RunSetup -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name NotLocatedCode -ErrorAction SilentlyContinue)) { Remove-Variable -Name NotLocatedCode -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name objReturn -ErrorAction SilentlyContinue)) { Remove-Variable -Name objReturn -Force -ErrorAction SilentlyContinue }