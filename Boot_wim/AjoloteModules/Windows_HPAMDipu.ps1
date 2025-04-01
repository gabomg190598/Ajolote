<#
AMD IPU Driver 2024
Version 1.0.3
    Date: 03/14/2025
    Root node: $json.JOBREQUEST.HPAMDipu
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
$SW_Title="AMD*IPU*Driver"

if ($null -ne $json.JOBREQUEST.HPAMDipu) {
    #introduce a Windows version validation
    #Supported versions Windows 11:
    if ([int]$OS.Build -gt 22000) {
        if ($null -ne $json.JOBREQUEST.HPAMDipu.status) {
            if ($json.JOBREQUEST.HPAMDipu.status.ToLower() -eq "new") {
                <########################################################################
                            NEW SETUP
                ##########################################################################>
                #check if drivers was requested on job
                if ($null -eq $json.JOBREQUEST.Drivers.sysid) { 
                    WriteLog -Message "Drivers folder was not requested by job, not possible to continue with this module" -MessageType Error -Verbose
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPAMDipu "fail" "Drivers folder was not requested by job, not possible to continue with this module"
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
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPAMDipu "fail" $global:MessageResults
                    Out-Windows
                }
                
                #Get list of CVA files on drivers folder
                $CVAs = Get-ChildItem -Path $HPN_Drivers -Filter "*.cva" -File -Recurse | Where-Object {$_.Length -gt 0}
            
                WriteLog -Message "Checking if $($SW_Title.Replace('*',' ')) can be installed" -Verbose
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
                    WriteLog -Message "Not possible locate CVA for $($SW_Title.Replace('*',' ')), abort process" -MessageType Error -Verbose
                    $global:MessageResults = "Not possible locate CVA for $($SW_Title.Replace('*',' ')), abort process"
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPAMDipu "fail" $global:MessageResults
                    $global:CodeResults = 406
                    Out-Windows 
                }
                if ($null -ne $GetCVA) {
                    $GetCVA | Out-Host
                                        
                    WriteLog -Message "Silent command detected: $($GetCVA.Silent)" -Verbose                
                    WriteLog -Message "Silent command required: $($GetCVA.SilentFile) $($GetCVA.SilentParameters)" -Verbose
                    
                    #Run setup
                    $RunSetup = Invoke-RunPower -file "cmd.exe" -Params "/c $($GetCVA.Path)\$($GetCVA.SilentFile) $($GetCVA.SilentParameters)" -WorkDir $GetCVA.Path -OutFile "$($logs)\Setup$($SW_Title.Replace('*','')).log" 
                    
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPAMDipu "new" "Setup completed with exit code $($RunSetup)"
                                            
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
                                    WriteLog -Message "$($GetCVA.Title) was successfully installed" -Verbose
                                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPAMDipu "pass" $objReturn.Mess
                                    if ($objReturn.reboot -eq "REBOOT") {
                                        if ($null -eq $json.JOBREQUEST.HPAMDipu.reboot) {
                                            $json.JOBREQUEST.HPAMDipu | Add-Member -Name "reboot" -MemberType NoteProperty -Value $true
                                        }
                                        else {
                                            $json.JOBREQUEST.HPAMDipu.reboot = $true
                                        }
                                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPAMDipu "pass" $objReturn.Mess
                                        WriteLog -Message "This result require reboot unit before to continue." -MessageType Warning -Verbose
                                        $global:MessageResults = "This result require reboot unit before to continue."
                                        $global:CodeResults = 3010
                                        Out-Windows 
                                    }
                                    <#Vaidate setup - removed for now
                                    #intention for this setup is confirm if C++ Redistributable was installed
                                    $RegPath = "HKLM:\SOFTWARE\Classes\Installer\Dependencies\"
                                    $RegWord = "redist."
                                    $Version =  $null
                                    $Name = $null
                                    WriteLog -Message "Checking if $($SW_Title.Replace('*',' ')) was detected in registry: $($RegPath)" -Verbose
                                    $GetDependencies = Get-ChildItem -Path $RegPath | Where-Object { $_ -like "*$($RegWord)*" }
                                    if ($null -ne $GetDependencies) {
                                        foreach ($dep in $GetDependencies) {
                                            $Name = ($dep | Get-ItemProperty).DisplayName
                                            $Version = ($dep | Get-ItemProperty).Version
                                            WriteLog -Message "Found $($Name) with version $($Version)" -Verbose
                                        }
                                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPAMDipu "pass" "$($SW_Title.Replace('*',' ')) was detected in registry as: $($Name) and version $($Version)"
                                    } else {
                                        WriteLog -Message "$($SW_Title.Replace('*',' ')) was not detected in registry" -MessageType Warning -Verbose
                                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPAMDipu "fail" "$($SW_Title.Replace('*',' ')) was not detected in registry"
                                        $global:MessageResults = "$($SW_Title.Replace('*',' ')) was not detected in registry"
                                        $global:CodeResults = 404
                                        Out-Windows
                                    }
                                    #>
                                }
                                else {
                                    WriteLog -Message "Nothing can do to fix this issue it require to look on log for $($GetCVA.Title)" -MessageType Warning -Verbose
                                    $global:MessageResults = "$($GetCVA.Title) error code $($objReturn.code) marked as $($objReturn.status)"
                                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPAMDipu "fail" $global:MessageResults
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
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPAMDipu "fail" $global:MessageResults                        
                        Out-Windows 
                    }
                }
                else {
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPAMDipu "fail" "Not possible read CVA Object for $($SW_Title.Replace('*',' ')), abort process"
                    WriteLog -Message "Not possible read CVA Object for $($SW_Title.Replace('*',' ')), abort process" -MessageType Error -Verbose
                    $global:MessageResults = "Not possible read CVA Object for $($SW_Title.Replace('*',' ')), abort process"
                    $global:CodeResults = 407
                    Out-Windows
                }            
           

                <########################## END NEW SETUP ################################>
            } elseif ($json.JOBREQUEST.HPAMDipu.status.ToLower() -eq "reboot") {
                #intention for this setup is confirm if C++ Redistributable was installed
                $RegPath = "HKLM:\SOFTWARE\Classes\Installer\Dependencies\"
                $RegWord = "redist."
                $Version =  $null
                $Name = $null
                WriteLog -Message "Checking if $($SW_Title.Replace('*',' ')) was detected in registry: $($RegPath)" -Verbose
                $GetDependencies = Get-ChildItem -Path $RegPath | Where-Object { $_ -like "*$($RegWord)*" }
                if ($null -ne $GetDependencies) {
                    foreach ($dep in $GetDependencies) {
                        $Name = ($dep | Get-ItemProperty).DisplayName
                        $Version = ($dep | Get-ItemProperty).Version
                        WriteLog -Message "Found $($Name) with version $($Version)" -Verbose
                    }
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPAMDipu "pass" "$($SW_Title.Replace('*',' ')) was detected in registry as: $($Name) and version $($Version)"
                } else {
                    WriteLog -Message "$($SW_Title.Replace('*',' ')) was not detected in registry" -MessageType Warning -Verbose
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPAMDipu "fail" "$($SW_Title.Replace('*',' ')) was not detected in registry"
                    $global:MessageResults = "$($SW_Title.Replace('*',' ')) was not detected in registry"
                    $global:CodeResults = 404
                    Out-Windows
                }
            } elseif ($json.JOBREQUEST.HPAMDipu.status.ToLower() -eq "pass") { 
                WriteLog -Message "$($SW_Title.Replace('*',' ')) already installed as successfully, status [$($json.JOBREQUEST.HPAMDipu.status)]" -Verbose
            } elseif ($json.JOBREQUEST.HPAMDipu.status.ToLower() -eq "fail") {
                WriteLog -Message "$($SW_Title.Replace('*',' ')) detected status [$($json.JOBREQUEST.HPAMDipu.status)] as fail, abort process" -Message Error -Verbose
                $global:MessageResults = "$($SW_Title.Replace('*',' ')) detected status [$($json.JOBREQUEST.HPAMDipu.status)] as fail, abort process"
                $global:CodeResults = 6
                Out-Windows
            } else {
                WriteLog -Message "It is not expected to detect status [$($json.JOBREQUEST.HPAMDipu.status)], abort process" -Message Error -Verbose
                $global:MessageResults = "It is not expected to detect status [$($json.JOBREQUEST.HPAMDipu.status)], abort process"
                $global:CodeResults = 5
                Out-Windows
            }
        } else {
            WriteLog -Message "$($SW_Title.Replace('*',' ')) module is required in job, however status value is missing" -MessageType Error -Verbose
            Update-JobStatus $jobfile $json $json.JOBREQUEST.HPAMDipu "fail" "$($SW_Title.Replace('*',' ')) module is required in job, however status value is missing"
            $global:MessageResults = "$($SW_Title.Replace('*',' ')) module is required in job, however status value is missing"
            $global:CodeResults = 4
            Out-Windows
        }
    } else {
        WriteLog -Message "This module is not designed for this OS version: $($OS.Build), no error just continue" -MessageType Warning -Verbose
        $global:MessageResults = "This module is not supported on this OS version: $($OS.Build), continue"
        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPAMDipu "pass" $global:MessageResults
    }
    
} else {
    WriteLog -Message "This module is not required" -Verbose
}

if ($null -ne (Get-Variable -Name HPN_Drivers -ErrorAction SilentlyContinue)) { Remove-Variable -Name HPN_Drivers -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name SW_Title -ErrorAction SilentlyContinue)) { Remove-Variable -Name SW_Title -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name CVAs -ErrorAction SilentlyContinue)) { Remove-Variable -Name CVAs -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name GetDependencies -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetDependencies -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name arrHPAppx -ErrorAction SilentlyContinue)) { Remove-Variable -Name arrHPAppx -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name objCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name objCVA -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name GetCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetCVA -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name RunSetup -ErrorAction SilentlyContinue)) { Remove-Variable -Name RunSetup -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name NotLocatedCode -ErrorAction SilentlyContinue)) { Remove-Variable -Name NotLocatedCode -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name objReturn -ErrorAction SilentlyContinue)) { Remove-Variable -Name objReturn -Force -ErrorAction SilentlyContinue }

