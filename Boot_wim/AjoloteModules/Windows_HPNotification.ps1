<#
    SETUP HP NOTIFICATIONS
    Version 1.0.5
    Date: 4/23/2024
    Root node: $json.JOBREQUEST.HPNotifications
    value: status
        "new" "fail" "pass"
        "new" means process is running or required, not completed yet
        "fail" process already fail
        "pass" process run successfully
    Value: retries
        Integer to control reboots, maximum 5
    Value: error
        Out message
#>
if ($null -ne $json.JOBREQUEST.HPNotifications) {
    if ($null -ne $json.JOBREQUEST.HPNotifications.status) {
        if ($json.JOBREQUEST.HPNotifications.status.ToLower() -eq "new") {
            WriteLog -Message "Module HP Notifications is required, validation starting" -Verbose
            if ($null -ne (Get-Variable -Name GetApp -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetApp -Force -ErrorAction SilentlyContinue }
            $GetApp=Get-CimInstance -ClassName Win32_Product | Where-Object {$_.Name -like "*HP Notifications*"}
            if ($null -eq $GetApp) {
                if ($null -ne $json.JOBREQUEST.Drivers.sysid) {
                    $HPN_Drivers=(Join-Path (Join-Path $AjoloteDrive "DRIVERS") $json.JOBREQUEST.Drivers.sysid) 
                    if (Test-Path -Path $HPN_Drivers -PathType Container) {
                        $cvasFile = Get-ChildItem -path $HPN_Drivers -filter "*.cva" -file -recurse | Where-Object {$_.Length -gt 0}
                        $arrayHPNot = [system.collections.arraylist]@()
                        foreach ($cva in $cvasFile) {
                            if ($null -ne (Get-Variable -Name curreCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name curreCVA -Force -ErrorAction SilentlyContinue }
                            $curreCVA = get-CVAobject -pathfile $cva.fullName
                            if ($curreCVA.Title.Trim().ToLower() -like "*hp notifications*") {
                                WriteLog -Message "Found $($curreCVA.Title) Ver.$($curreCVA.version)" -Verbose 
                                [void]$arrayHPNot.add($curreCVA);        
                            }
                        }
                        if ($null -ne (Get-Variable -Name GetCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetCVA -Force -ErrorAction SilentlyContinue }
                        if ($arrayHPNot.Count -gt 0 ) {              
                            #$arrayHPNot | Sort-Object -property Version -Descending 
                            $GetCVA = ($arrayHPNot | Sort-Object -property Version -Descending | Sort-Object -Property Length)[0]
                        } else {
                            WriteLog -Message "Not possible locate CVA for HP Notifications, abort process" -MessageType Error -Verbose
                            $global:MessageResults="Not possible locate CVA for HP Notifications, abort process"
                            $global:CodeResults=406
                            Out-Windows 
                        }
                        if ($null -ne $GetCVA) {
                            $GetCVA | Out-Host
                            $stringsilent = $GetCVA.Silent
                            WriteLog -Message "Silent command detected: $($stringsilent)" -Verbose
                            If($stringsilent.StartsWith("""")) {
                                $rem = $stringsilent.Substring(1, $stringsilent.length -1).indexOf("""")
                                $sub = $stringsilent.Substring(1,$stringsilent.Length -1)
                                $Sub2 = $sub.Substring(0,$rem)
                                if ($sub.length -gt ($rem + 1)) {
                                    $sub3 = $sub.Substring($rem + 1, ($sub.Length - $sub2.Length -1))
                                } else {
                                    $sub3=""
                                }
                                
                                $VarSilent = $sub2 + $sub3
                            }  else {
                                $VarSilent=$stringsilent
                            }
                            WriteLog -Message "Silent command required: $($VarSilent)" -Verbose
                            if (([string]::IsNullOrEmpty($VarSilent)) -OR ($VarSilent.ToLower().Trim() -eq "n/a")) {
                                WriteLog -Message "CVA doesn't contain Silent command or N/A found" -MessageType Error -Verbose
                                $global:MessageResults="CVA doesn't contain Silent command or N/A found"
                                $global:CodeResults=408
                                Out-Windows 
                            } else {
                                if (($null -ne $json.JOBREQUEST.HPNotifications.retries) -AND ($json.JOBREQUEST.HPNotifications.retries -gt 5)) {                        
                                    WriteLog -Message "$($GetCVA.Title) has tried for more than 5 times, somenthing is not working, abort process" -Verbose
                                    if ($null -ne $json.JOBREQUEST.HPNotifications.error) {
                                        $global:MessageResults=$json.JOBREQUEST.HPNotifications.error
                                    } else {
                                        $global:MessageResults="$($GetCVA.Title) has tried for more than 5 times, somenthing is not working, abort process"
                                    }
                                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPNotifications "fail" $global:MessageResults
                                    $global:CodeResults=409                        
                                    Out-Windows 
                                }
                                $RunSetup = Invoke-RunPower -file "cmd.exe" -Params "/c $($GetCVA.Path)\$($VarSilent)" -WorkDir $GetCVA.Path -OutFile "$($logs)\SetupHPNotifications.log" -Verbose
                                if ($null -eq $json.JOBREQUEST.HPNotifications.retries) {
                                    $json.JOBREQUEST.HPNotifications | Add-Member -Name "retries" -MemberType NoteProperty -Value 1
                                } else {
                                    $json.JOBREQUEST.HPNotifications.retries++
                                } 
                                Update-JobStatus $jobfile $json $json.JOBREQUEST.HPNotifications "new" "HP Notifications was installed and return code is $($RunSetup)"
                                #Get status, action and message
                                $NotLocatedCode=$true
                                foreach ($err in $GetCVA.ReturnCode) { 
                                    WriteLog -Message "Comparing CVA Return code line: $($err)" -Verbose
                                    if ($err.Contains("=") -AND $err.Contains(":")) {
                                        if ($null -ne $err.Split("=")[0]) {$Codes=$err.Split("=")[0]} else {$Codes=""}
                                        if ($null -ne $err.Split("=")[1]) {$Mess=$err.Split("=")[1]} else {$Mess=""}
                                        if ($null -ne $Codes.Split(":")[0]) {[int]$code=$Codes.Split(":")[0]} else {[int]$code=0}
                                        if ($null -ne $Codes.Split(":")[1]) {$status=$Codes.Split(":")[1]} else {$status=""}
                                        if ($null -ne $Codes.Split(":")[2]) {$reboot=$Codes.Split(":")[2]} else {$reboot=""}                        
                                        if ($code -eq $RunSetup) {
                                            WriteLog -Message "Return Code $($RunSetup) was located on CVA, Status: $($status), Reboot: $($reboot) and message $($Mess)" -Verbose
                                            $NotLocatedCode=$false
                                            if ($status.ToUpper().Trim() -eq "SUCCESS") {
                                                WriteLog -Message "$($GetCVA.Title) was successfully installed, validation required..." -Verbose
                                                if ($reboot -eq "REBOOT") {
                                                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPNotifications "new" $Mess
                                                    WriteLog -Message "This result require reboot unit before to continue." -MessageType Warning -Verbose
                                                    $global:MessageResults="This result require reboot unit before to continue."
                                                    $global:CodeResults=3010
                                                    Out-Windows 
                                                }
                                                #Vaidate setup
                                                WriteLog -Message "Validate if package name: [$($GetCVA.Title)] is present on this system" -Verbose
                                                Start-Sleep -Seconds 10
                                                Get-CimInstance -ClassName Win32_Product | Select-Object -Property Name,Version,InstallState,Description,PackageName | Format-Table | Out-Host
                                                Get-CimInstance -ClassName Win32_Product | Select-Object -Property * | Out-File -FilePath (Join-Path $logs "Win32_Product.log")                                                                                           
                                                if ($null -ne (Get-Variable -Name GetApp -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetApp -Force -ErrorAction SilentlyContinue }
                                                $GetApp=Get-CimInstance -ClassName Win32_Product | Where-Object {$_.Name -like "*$($GetCVA.Title)*"}
                                                WriteLog -Message "For trascript, out variable value:" -Verbose
                                                $GetApp | Out-Host
                                                WriteLog -Message "---------------End variable output" -Verbose
                                                if ($null -eq $GetApp) {
                                                    WriteLog -Message "Not possible detect $($GetCVA.Title) installed on this system, review Win32_Product.log to check installed applications" -MessageType Warning -Verbose
                                                    $global:MessageResults="Not possible detect $($GetCVA.Title) installed on this system, review Win32_Product.log to check installed applications"
                                                    $global:CodeResults=411
                                                    Out-Windows 
                                                }
                                                if (($GetApp | Measure-Object).Count -gt 1) {
                                                    WriteLog -Message "Not expected but there are more than one result found" -MessageType Warning -Verbose
                                                }
                                                foreach ($app in $GetApp) {
                                                    WriteLog -Message "$($app.Name) detected as part of Software and Features on this system, with version $($app.Version),  Vendor: $($app.Vendor)" -Verbose
                                                }                                
                                                Update-JobStatus $jobfile $json $json.JOBREQUEST.HPNotifications "pass" "$($GetCVA.Title) was successfully installed"
                                            } else {
                                                WriteLog -Message "$($GetCVA.Title) failed during setup, checking if code $($code) has actions that can be applied to fix issue" -MessageType Warning -Verbose                                                          
                                                Update-JobStatus $jobfile $json $json.JOBREQUEST.HPNotifications "new" $Mess
                                                switch ($code) {
                                                    {($_ -eq 1618) -OR ($_ -eq 1603) -OR ($_ -eq 1619) -OR ($_ -eq 1620)} { 
                                                        WriteLog -Message "Reboot unit and retry $($GetCVA.Title)" -MessageType Warning -Verbose
                                                        $global:MessageResults="Reboot unit and retry $($GetCVA.Title)"
                                                        $global:CodeResults=3010
                                                        Out-Windows 
                                                    }
                                                    Default {
                                                        WriteLog -Message "$($GetCVA.Title), Nothing can do to fix this issue: $($Mess)" -MessageType Warning -Verbose
                                                        $global:MessageResults="$($GetCVA.Title), Nothing can do to fix this issue: $($Mess)" 
                                                        $global:CodeResults=$code
                                                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPNotifications "fail" $Mess
                                                        Out-Windows 
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                if ($NotLocatedCode) {
                                    WriteLog -Message "It was not possible detect code $($RunSetup) on CVA" -MessageType Error -Verbose
                                    $global:MessageResults = "It was not possible detect code $($RunSetup) on CVA" 
                                    $global:CodeResults = $RunSetup
                                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPNotifications "fail" $global:MessageResults                        
                                    Out-Windows 
                                }
                            }
                        } else {
                            WriteLog -Message "Not possible CVA Object for HP Notifications, abort process" -MessageType Error -Verbose
                            $global:MessageResults="Not possible CVA Object for HP Notifications, abort process"
                            $global:CodeResults=407
                            Out-Windows
                        }
                        
                    } else {
                        WriteLog -Message "Drivers folder [$($HPN_Drivers)] doesn't exist, not possible to continue with this module" -MessageType Error -Verbose
                        $global:MessageResults="Drivers folder [$($HPN_Drivers)] doesn't exist, not possible to continue with this module"
                        $global:CodeResults=405
                        Out-Windows
                    }
                } else {
                    WriteLog -Message "Drivers folder was not requested by job, not possible to continue with this module" -MessageType Error -Verbose
                    $global:MessageResults="Drivers folder was not requested by job, not possible to continue with this module"
                    $global:CodeResults=404
                    Out-Windows
                }
            } else {
                if (($GetApp | Measure-Object).Count -gt 1) {
                    WriteLog -Message "Not expected but there are more than one result found" -MessageType Warning -Verbose
                }
                foreach ($app in $GetApp) {
                    WriteLog -Message "$($app.Name) detected as part of Software and Features on this system, with version $($app.Version),  Vendor: $($app.Vendor)" -Verbose
                }                                
                Update-JobStatus $jobfile $json $json.JOBREQUEST.HPNotifications "pass" "$($app.Name) was successfully installed, version $($app.Version) detected on Programs and Features"
            }
            
        
        } elseif ($json.JOBREQUEST.HPNotifications.status.ToLower() -eq "pass") {
            WriteLog -Message "Process already run and successfully completed" -Verbose
        } elseif ($json.JOBREQUEST.HPNotifications.status.ToLower() -eq "fail") {
            WriteLog -Message "HP Notification process already run and failed, need to stop now" -MessageType Error -Verbose
            $global:MessageResults="HP Notifications process already run and failed, need to stop now"
            $global:CodeResults=4
            Out-Windows
        } else {
            WriteLog -Message "HP Notification process unexpected status: [$($json.JOBREQUEST.HPNotifications.status)]" -MessageType Error -Verbose
            $global:MessageResults="HP Notifications process already run and failed, need to stop now"
            $global:CodeResults=3
            Out-Windows
        }
    } else {
        WriteLog -Message "Status is a mandatory value and not detected on job during Module HP Notifications" -MessageType Error -Verbose
        $global:MessageResults="Status is a mandatory value and not detected on job during Module HP Notifications"
        $global:CodeResults=2
        Out-Windows
    }
} else {
    WriteLog -Message "This module is not required, continue" -Verbose
}

if ($null -ne (Get-Variable -Name HPN_Drivers -ErrorAction SilentlyContinue)) { Remove-Variable -Name HPN_Drivers -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name cvasFile -ErrorAction SilentlyContinue)) { Remove-Variable -Name cvasFile -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name arrayHPNot -ErrorAction SilentlyContinue)) { Remove-Variable -Name arrayHPNot -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name GetCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetCVA -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name stringsilent -ErrorAction SilentlyContinue)) { Remove-Variable -Name stringsilent -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name rem -ErrorAction SilentlyContinue)) { Remove-Variable -Name rem -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name sub -ErrorAction SilentlyContinue)) { Remove-Variable -Name sub -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name sub2 -ErrorAction SilentlyContinue)) { Remove-Variable -Name sub2 -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name sub3 -ErrorAction SilentlyContinue)) { Remove-Variable -Name sub3 -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name VarSilent -ErrorAction SilentlyContinue)) { Remove-Variable -Name VarSilent -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name RunSetup -ErrorAction SilentlyContinue)) { Remove-Variable -Name RunSetup -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name Codes -ErrorAction SilentlyContinue)) { Remove-Variable -Name Codes -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name Mess -ErrorAction SilentlyContinue)) { Remove-Variable -Name Mess -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name code -ErrorAction SilentlyContinue)) { Remove-Variable -Name code -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name status -ErrorAction SilentlyContinue)) { Remove-Variable -Name status -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name reboot -ErrorAction SilentlyContinue)) { Remove-Variable -Name reboot -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name GetApp -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetApp -Force -ErrorAction SilentlyContinue }