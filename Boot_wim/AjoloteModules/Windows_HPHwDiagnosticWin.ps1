<#
HP PC HARDWARE DIAGNOSTICS WINDOWS
Version 1.0.3
    Date: 04/23/2024
    Root node: $json.JOBREQUEST.HPDiagnosticWindows
    value: status
        "new", "fail", "pass"
        "new" means process is running or required, not completed yet
        "fail" process already fail
        "pass" process run successfully
    Value: retries
        Integer to control reboots, maximum 5
    Value: error
        Out message
#>

if ($null -ne $json.JOBREQUEST.HPDiagnosticWindows) {
    if ($null -ne $json.JOBREQUEST.HPDiagnosticWindows.status) {
        if ($json.JOBREQUEST.HPDiagnosticWindows.status.ToLower() -eq "new") {
            <########################################################################
                        NEW SETUP FOR HP HARDWARE DIAGNOSTIC WINDOWS
            ##########################################################################>
            #check if drivers was requested on job
            if ($null -eq $json.JOBREQUEST.Drivers.sysid) { 
                WriteLog -Message "Drivers folder was not requested by job, not possible to continue with this module" -MessageType Error -Verbose
                Update-JobStatus $jobfile $json $json.JOBREQUEST.HPDiagnosticWindows "fail" "Drivers folder was not requested by job, not possible to continue with this module"
                $global:MessageResults = "Drivers folder was not requested by job, not possible to continue with this module"
                $global:CodeResults = 404
                Out-Windows
            }
            #Confirm that drivers folder exist
            $HPN_Drivers = (Join-Path (Join-Path $AjoloteDrive "DRIVERS") $json.JOBREQUEST.Drivers.sysid) 
            if (-Not(Test-Path -Path $HPN_Drivers -PathType Container)) {
                WriteLog -Message "Drivers folder [$($HPN_Drivers)] doesn't exist, not possible to continue with this module" -MessageType Error -Verbose
                Update-JobStatus $jobfile $json $json.JOBREQUEST.HPDiagnosticWindows "fail" "Drivers folder [$($HPN_Drivers)] doesn't exist, not possible to continue with this module"
                $global:MessageResults = "Drivers folder [$($HPN_Drivers)] doesn't exist, not possible to continue with this module"
                $global:CodeResults = 405
                Out-Windows
            }
            #Get list of CVA files on drivers folder
            $CVAs = Get-ChildItem -Path $HPN_Drivers -Filter "*.cva" -File -Recurse | Where-Object {$_.Length -gt 0}

            #Cofnirm if HP PC Hardware Diagnostics WindowsS is installed
            $GetHWDiagsWindows = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*hppchardwarediagnosticswindows*" }

            if ($null -eq $GetHWDiagsWindows) {
                WriteLog -Message "It was not possible detect HP PC Hardware Diagnostics Windows installed on this unit, checking if can be installed" -MessageType Warning -Verbose
                #Search for HP PC Hardware Diagnostics Windowss CVA
                $arrHPHWDiagWin = [system.collections.arraylist]@()
                foreach ($cva in $CVAs) {
                    if ($null -ne (Get-Variable -Name objCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name objCVA -Force -ErrorAction SilentlyContinue }
                    $objCVA = get-CVAobject -pathfile $cva.fullName
                    if ($objCVA.Title.Trim().ToLower() -like "*pc hardware diagnostics windows*") {
                        WriteLog -Message "Found $($objCVA.Title) V.$($objCVA.version)" -Verbose 
                        [void]$arrHPHWDiagWin.add($objCVA);        
                    }
                }
                if ($null -ne (Get-Variable -Name GetCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetCVA -Force -ErrorAction SilentlyContinue }
                if ($arrHPHWDiagWin.Count -gt 0 ) {
                    #retrive only latest version
                    $GetCVA = ($arrHPHWDiagWin | Sort-Object -property Version -Descending | Sort-Object -Property Length)[0]
                }
                else {
                    WriteLog -Message "Not possible locate CVA for HP PC Hardware Diagnostics Windows, abort process" -MessageType Error -Verbose
                    $global:MessageResults = "Not possible locate CVA for HP PC Hardware Diagnostics Windows, abort process"
                    $global:CodeResults = 406
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPDiagnosticWindows "fail" $global:MessageResults
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
                    if (($null -ne $json.JOBREQUEST.HPDiagnosticWindows.reboot) -AND ($json.JOBREQUEST.HPDiagnosticWindows.reboot)) {                        
                        WriteLog -Message "After setup, $($GetCVA.Title) still cannot be detected, abort process to review logs" -Verbose
                        $global:MessageResults = "After setup, $($GetCVA.Title) still cannot be detected, abort process to review logs"
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPDiagnosticWindows "fail" $global:MessageResults
                        $global:CodeResults = 409
                        Out-Windows 
                    }
                    #Run setup
                    $RunSetup = Invoke-RunPower -file "cmd.exe" -Params "/c $($GetCVA.Path)\$($objResult.silent)" -WorkDir $GetCVA.Path -OutFile "$($logs)\SetupHPPCHardwareDiagsWindows.log" 
                    if ($null -eq $json.JOBREQUEST.HPDiagnosticWindows.reboot) {
                        $json.JOBREQUEST.HPDiagnosticWindows | Add-Member -Name "reboot" -MemberType NoteProperty -Value $true
                    }
                    else {
                        $json.JOBREQUEST.HPDiagnosticWindows.reboot = $true
                    }
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPDiagnosticWindows "new" "Setup completed with exit code $($RunSetup)"
                    #This application will remove after Generalize image, it require to install using PPSolution

                    #copy setup folder
                    WriteLog -Message "Preparing for setup during Post-Processing..." -Verbose                
                    #create CMD in case that PPSolution is not present
                    $NameREG=(Split-Path $GetCVA.Path -Leaf).Replace(" ","_")
                    "@echo off" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force
                    "SET log=$($env:SystemDrive)\system.sav\logs\$($NameREG).log" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                    "SET code=0" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                    "echo  =============  INSTALLING APPX, PLEASE WAIT...   ==================" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                    "pushd $($env:SystemDrive)\SWSETUP\HP\$($NameREG)" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                    "dir /b /s $($env:SystemDrive)\SWSETUP\HP\$($NameREG) >> %log% 2>&1" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                    "IF NOT EXIST %SystemDrive%\System.sav\logs md %SystemDrive%\System.sav\logs >> %log% 2>&1" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                    "ATTRIB +H %SystemDrive%\System.sav >> %log% 2>&1" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append                    
                    "start /wait /MIN %~dp0$($objResult.silent) >> %log% 2>&1" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                    "set code=%ERRORLEVEL%" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                    "echo *exit /b %code% >> %log%" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                    "echo Remove installer folder >> %log%" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                    "start cmd.exe /c ""ping -n 3 127.0.0.1 >nul & rd /s /q %~dp0""" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                    "exit /b %code%" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                    #copy source                    
                    $CopySetup = Invoke-RunPower -file "cmd.exe" -Params "/c Xcopy /sehiyk $($GetCVA.Path)\* $($env:SystemDrive)\SWSETUP\HP\$($NameREG)\" -WorkDir $GetCVA.Path -OutFile "$($logs)\Copy$($NameREG).log" 
                    if ($CopySetup -ne 0) {
                        WriteLog -Message "Fail copying HP PC Hardware Diagnostics Windows installation for Post-Processing" -MessageType Error -Verbose
                        $global:MessageResults="Fail copying HP PC Hardware Diagnostics Windows installation for Post-Processing"
                        $global:CodeResults=$CopySetup
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPDiagnosticWindows "fail" $global:MessageResults
                        Out-Windows
                    } else {
                        WriteLog -Message "Files copied successfully" -Verbose
                    }
                     
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
                                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPDiagnosticWindows "new" $objReturn.Mess
                                        WriteLog -Message "This result require reboot unit before to continue." -MessageType Warning -Verbose
                                        $global:MessageResults = "This result require reboot unit before to continue."
                                        $global:CodeResults = 3010
                                        Out-Windows 
                                    }
                                    #Vaidate setup
                                    $GetHWDiagsWindows = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*hppchardwarediagnosticswindows*" }
                                    if ($null -eq $GetHWDiagsWindows) {
                                        WriteLog -Message "It was not possible detect HP PC Hardware Diagnostics Windows installed on this unit, checking if can be installed" -MessageType Error -Verbose
                                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPDiagnosticWindows "fail" "It was not possible detect HP PC Hardware Diagnostics Windows installed on this unit, checking if can be installed"
                                        $global:MessageResults = "It was not possible detect HP PC Hardware Diagnostics Windows installed on this unit, checking if can be installed"
                                        $global:CodeResults = 404
                                        Out-Windows
                                    }                           
                                    WriteLog -Message "HP PC Hardware Diagnostics Windowss was detected with name: $($GetHWDiagsWindows[0].Name) and version $($GetHWDiagsWindows[0].Version)" -Verbose
                                    if ($null -eq $json.JOBREQUEST.HPDiagnosticWindows.reboot) {
                                        $json.JOBREQUEST.HPDiagnosticWindows | Add-Member -Name "reboot" -MemberType NoteProperty -Value $true
                                    }
                                    else {
                                        $json.JOBREQUEST.HPDiagnosticWindows.reboot = $true
                                    }
                                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPDiagnosticWindows "pass" "HP PC Hardware Diagnostics Windowss was detected with package full name: $($GetHWDiagsWindows[0].PackageFullName) and version $($GetHWDiagsWindows[0].Version)"
                                }
                                else {
                                    if ($null -eq $json.JOBREQUEST.HPDiagnosticWindows.reboot) {
                                        $json.JOBREQUEST.HPDiagnosticWindows | Add-Member -Name "reboot" -MemberType NoteProperty -Value $true
                                    }
                                    else {
                                        $json.JOBREQUEST.HPDiagnosticWindows.reboot = $true
                                    }
                                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPDiagnosticWindows "fail" "$($GetCVA.Title) error code $($objReturn.code) marked as $($objReturn.status)"
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
                        if ($null -eq $json.JOBREQUEST.HPDiagnosticWindows.reboot) {
                            $json.JOBREQUEST.HPDiagnosticWindows | Add-Member -Name "reboot" -MemberType NoteProperty -Value $true
                        } else {
                            $json.JOBREQUEST.HPDiagnosticWindows.reboot = $true
                        }
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPDiagnosticWindows "fail" $global:MessageResults                        
                        Out-Windows 
                    }
                }
                else {
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPDiagnosticWindows "fail" "Not possible read CVA Object for HP PC Hardware Diagnostics Windowss, abort process"
                    WriteLog -Message "Not possible read CVA Object for HP PC Hardware Diagnostics Windowss, abort process" -MessageType Error -Verbose
                    $global:MessageResults = "Not possible read CVA Object for HP PC Hardware Diagnostics Windowss, abort process"
                    $global:CodeResults = 407
                    Out-Windows
                }            

            } else {
                WriteLog -Message "HP PC Hardware Diagnostics Windowss was detected with name: $($GetHWDiagsWindows[0].Name) and version $($GetHWDiagsWindows[0].Version)" -Verbose
                if ($null -eq $json.JOBREQUEST.HPDiagnosticWindows.reboot) {
                    $json.JOBREQUEST.HPDiagnosticWindows | Add-Member -Name "reboot" -MemberType NoteProperty -Value $true
                }
                else {
                    $json.JOBREQUEST.HPDiagnosticWindows.reboot = $true
                }
                Update-JobStatus $jobfile $json $json.JOBREQUEST.HPDiagnosticWindows "pass" "Detected package installed: $($GetHWDiagsWindows[0].PackageFullName)"
            }

            <########################## END NEW SETUP ################################>
        } elseif ($json.JOBREQUEST.HPDiagnosticWindows.status.ToLower() -eq "pass") { 
            WriteLog -Message "HP PC Hardware Diagnostics Windows already installed as successfully, status [$($json.JOBREQUEST.HPDiagnosticWindows.status)]" -Verbose
        } elseif ($json.JOBREQUEST.HPDiagnosticWindows.status.ToLower() -eq "fail") {
            WriteLog -Message "HP PC Hardware Diagnostics Windows detected status [$($json.JOBREQUEST.HPDiagnosticWindows.status)] as fail, abort process" -Message Error -Verbose
            $global:MessageResults = "HP PC Hardware Diagnostics Windows detected status [$($json.JOBREQUEST.HPDiagnosticWindows.status)] as fail, abort process"
            $global:CodeResults = 6
            Out-Windows
        } else {
            WriteLog -Message "It is not expected to detect status [$($json.JOBREQUEST.HPDiagnosticWindows.status)], abort process" -Message Error -Verbose
            $global:MessageResults = "It is not expected to detect status [$($json.JOBREQUEST.HPDiagnosticWindows.status)], abort process"
            $global:CodeResults = 5
            Out-Windows
        }
    } else {
        WriteLog -Message "HP PC Hardware Diagnostics Windows module is required in job, however status value is missing" -MessageType Error -Verbose
        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPDiagnosticWindows "fail" "HP PC Hardware Diagnostics Windows module is required in job, however status value is missing"
        $global:MessageResults = "HP PC Hardware Diagnostics Windows module is required in job, however status value is missing"
        $global:CodeResults = 4
        Out-Windows
    }
} else {
    WriteLog -Message "This module is not required" -Verbose
}

if ($null -ne (Get-Variable -Name GetApps -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetApps -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name arrayHP -ErrorAction SilentlyContinue)) { Remove-Variable -Name arrayHP -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name GetHWDiagsWindows -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetHWDiagsWindows -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name NameREG -ErrorAction SilentlyContinue)) { Remove-Variable -Name NameREG -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name CopySetup -ErrorAction SilentlyContinue)) { Remove-Variable -Name CopySetup -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name HPN_Drivers -ErrorAction SilentlyContinue)) { Remove-Variable -Name HPN_Drivers -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name CVAs -ErrorAction SilentlyContinue)) { Remove-Variable -Name CVAs -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name GetCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetCVA -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name objResult -ErrorAction SilentlyContinue)) { Remove-Variable -Name objResult -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name objCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name objCVA -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name RunSetup -ErrorAction SilentlyContinue)) { Remove-Variable -Name RunSetup -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name NotLocatedCode -ErrorAction SilentlyContinue)) { Remove-Variable -Name NotLocatedCode -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name objReturn -ErrorAction SilentlyContinue)) { Remove-Variable -Name objReturn -Force -ErrorAction SilentlyContinue }