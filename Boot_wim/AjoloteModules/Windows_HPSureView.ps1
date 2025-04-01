<#
SETUP HP SURE VIEW
-Dependency on HP Privacy Settings
example:
https://ftp.ext.hp.com/pub/softpaq/sp103501-104000/sp103939.cva
HP Privacy Settings                                        Software - Solutions
setup example:
https://ftp.ext.hp.com/pub/softpaq/sp105501-106000/sp105732.cva


Version 1.0.2
    Date: 4/23/2024
    Root node: $json.JOBREQUEST.HPSureView
    value: status
        "new", "fail", "pass"
        "new" means process is running or required, not completed yet
        "fail" process already fail
        "pass" process run successfully
    Value: retries
        Integer to control reboots, maximum 5
    value: hpprivatesettings
        boolean, True for detected installed or setup for HP Privacy Settings completed successfully
    Value: error
        Out message
#>
#"$($env:SystemDrive)\SWSETUP\APP\PreInstallTools\HP\SetupTools"
if ($null -ne $json.JOBREQUEST.HPSureView){
    if (($null -eq $json.JOBREQUEST.HPSureView.status) -OR ($json.JOBREQUEST.HPSureView.status.ToLower() -eq "new")) {
        WriteLog -Message "Module HP SURE VIEW required, detection started" -Verbose
        #check if drivers was requested on job
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

        WriteLog -Message "Application HP SURE VIEW require presence of HP PRIVACY SETTINGS, checking current status" -Verbose
        #Cofnirm if HP PRIVACY SETTINGS is installed
        $GetPrivacy = Get-AppxPackage -AllUsers | Where-Object {$_.Name -like "*hpprivacy*"}
        #####################################################################################################################################
        #############           TRY TO INSTALL HP PRIVACY SETTINGS
        #####################################################################################################################################
        if ($null -eq $GetPrivacy) {
            WriteLog -Message "It was not possible detect HP Privacy Setting installed on this unit, checking if can be installed" -MessageType Warning -Verbose
            #Search for HP Privacy Settings CVA
            $arrHPPrivacy = [system.collections.arraylist]@()
            foreach ($cva in $CVAs) {
                if ($null -ne (Get-Variable -Name objCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name objCVA -Force -ErrorAction SilentlyContinue }
                $objCVA = get-CVAobject -pathfile $cva.fullName
                if ($objCVA.Title.Trim().ToLower() -like "*hp privacy*")
                {
                    WriteLog -Message "Found $($objCVA.Title) V.$($objCVA.version)" -Verbose 
                    [void]$arrHPPrivacy.add($objCVA);        
                }
            }
            if ($null -ne (Get-Variable -Name GetCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetCVA -Force -ErrorAction SilentlyContinue }
            if ($arrHPPrivacy.Count -gt 0 ) { 
                $GetCVA = ($arrHPPrivacy | Sort-Object -property Version -Descending | Sort-Object -Property Length)[0]
            }
            else {
                WriteLog -Message "Not possible locate CVA for HP Privacy Settings, abort process" -MessageType Error -Verbose
                Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSureView "fail" "Not possible locate CVA for HP Privacy Settings, abort process"
                $global:MessageResults="Not possible locate CVA for HP Privacy Settings, abort process"
                $global:CodeResults=406
                Out-Windows 
            }
            if ($null -ne $GetCVA) {
                $GetCVA | Out-Host
                $objResult=@{}
                    $objResult.read=$GetCVA.Silent
                if ($GetCVA.Silent.StartsWith("""")) {
                    $sub = $GetCVA.Silent.Substring(1,$GetCVA.Silent.Length -1)
                    $rem = $sub.indexOf("""")
                    $sub2 = $sub.Substring(0,$rem)
                    if($sub.length -gt $rem +1) {
                        $sub3 = $sub.Substring($rem +1, ($sub.Length - $sub2.Length -1))  
                    } else {
                        $sub3=""
                    }
                    
                } else {
                    if ($GetCVA.Silent.Trim().IndexOf(" ") -gt 0) {
                        $sub2=$GetCVA.Silent.Split(" ")[0]
                        $sub3=$GetCVA.Silent.Replace($sub2,"").Trim()
                    } else {
                        $sub2=$GetCVA.Silent.Trim()
                        $sub3=""
                    }
                    
                }
                    $objResult.file=$sub2
                    $objResult.parameters=$sub3
                    $objResult.silent=$sub2 + $sub3
                WriteLog -Message "Silent command detected: $($objResult.read)" -Verbose                
                WriteLog -Message "Silent command required: $($objResult.silent)" -Verbose
                if (($null -ne $json.JOBREQUEST.HPSureView.hpprivatesettings) -AND ($json.JOBREQUEST.HPSureView.hpprivatesettings)) {                        
                    WriteLog -Message "After setup, $($GetCVA.Title) still cannot be detected, abort process to review logs" -Verbose
                    $global:MessageResults="After setup, $($GetCVA.Title) still cannot be detected, abort process to review logs"
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSureView "fail" $global:MessageResults
                    $global:CodeResults=409                     
                    Out-Windows 
                }
                #Run setup
                $RunSetup = Invoke-RunPower -file "cmd.exe" -Params "/c $($GetCVA.Path)\$($objResult.silent)" -WorkDir $GetCVA.Path -OutFile "$($logs)\SetupHPPrivacySettings.log" 
                if ($null -eq $json.JOBREQUEST.HPSureView.hpprivatesettings) {
                    $json.JOBREQUEST.HPSureView | Add-Member -Name "hpprivatesettings" -MemberType NoteProperty -Value $true
                } else {
                    $json.JOBREQUEST.HPSureView.hpprivatesettings=$true
                }
                Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSureView "new" "Setup completed with exit code $($RunSetup)"
                #Get status, action and message
                $NotLocatedCode=$true
                foreach ($err in $GetCVA.ReturnCode) {
                    WriteLog -Message "Comparing CVA Return code line: $($err)" -Verbose
                    if ($err.Contains("=") -AND $err.Contains(":")) {
                        $objReturn=@{}
                            if ($null -ne $err.Split("=")[0]) {$objReturn.Codes=$err.Split("=")[0]} else {$objReturn.Codes=""}
                            if ($null -ne $err.Split("=")[1]) {$objReturn.Mess=$err.Split("=")[1]} else {$objReturn.Mess=""}
                            if ($null -ne $objReturn.Codes.Split(":")[0]) {$objReturn.code=$objReturn.Codes.Split(":")[0]} else {$objReturn.code="0"}
                            if ($null -ne $objReturn.Codes.Split(":")[1]) {$objReturn.status=$objReturn.Codes.Split(":")[1]} else {$objReturn.status=""}
                            if ($null -ne $objReturn.Codes.Split(":")[2]) {$objReturn.reboot=$objReturn.Codes.Split(":")[2]} else {$objReturn.reboot=""}                        
                        if ([int]$objReturn.code -eq $RunSetup) {
                            WriteLog -Message "Return Code $($RunSetup) was located on CVA, Status: $($objReturn.status), Reboot: $($objReturn.reboot) and message $($objReturn.Mess)" -Verbose
                            $NotLocatedCode=$false
                            if ($objReturn.status.ToUpper().Trim() -eq "SUCCESS") {
                                WriteLog -Message "$($GetCVA.Title) was successfully installed, validation required..." -Verbose
                                if ($objReturn.reboot -eq "REBOOT") {
                                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSureView "new" $objReturn.Mess
                                    WriteLog -Message "This result require reboot unit before to continue." -MessageType Warning -Verbose
                                    $global:MessageResults="This result require reboot unit before to continue."
                                    $global:CodeResults=3010
                                    Out-Windows 
                                }
                                #Vaidate setup
                                $GetPrivacy = Get-AppxPackage -AllUsers | Where-Object {$_.Name -like "*hpprivacy*"}
                                if ($null -eq $GetPrivacy) {
                                    WriteLog -Message "It was not possible detect HP Privacy Setting installed on this unit, checking if can be installed" -MessageType Error -Verbose
                                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSureView "fail" "It was not possible detect HP Privacy Setting installed on this unit, checking if can be installed"
                                    $global:MessageResults="It was not possible detect HP Privacy Setting installed on this unit, checking if can be installed"
                                    $global:CodeResults=404
                                    Out-Windows
                                }                           
                                WriteLog -Message "HP Privacy Settings was detected with name: $($GetPrivacy[0].Name) and version $($GetPrivacy[0].Version)" -Verbose
                            } else {
                                if ($null -eq $json.JOBREQUEST.HPSureView.hpprivatesettings) {
                                    $json.JOBREQUEST.HPSureView | Add-Member -Name "hpprivatesettings" -MemberType NoteProperty -Value $true
                                } else {
                                    $json.JOBREQUEST.HPSureView.hpprivatesettings=$true
                                }
                                Update-JobStatus $jobfile $json $json.JOBREQUEST.HPPrivacySettings "fail" "$($GetCVA.Title) error code $($objReturn.code) marked as $($objReturn.status)"
                                WriteLog -Message "Nothing can do to fix this issue it require to look on log for $($GetCVA.Title)" -MessageType Warning -Verbose
                                $global:MessageResults="Nothing can do to fix this issue it require to look on log for $($GetCVA.Title)" 
                                $global:CodeResults=410
                                Out-Windows 
                            }
                        }
                    }
                }
                if ($NotLocatedCode) {
                    WriteLog -Message "It was not possible detect code $($RunSetup) on CVA" -Message Error -Verbose
                    $global:MessageResults = "It was not possible detect code $($RunSetup) on CVA" 
                    $global:CodeResults = $RunSetup
                    if ($null -eq $json.JOBREQUEST.HPSureView.hpprivatesettings) {
                        $json.JOBREQUEST.HPSureView | Add-Member -Name "hpprivatesettings" -MemberType NoteProperty -Value $true
                    } else {
                        $json.JOBREQUEST.HPSureView.hpprivatesettings = $true
                    }
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSureView "fail" $global:MessageResults                        
                    Out-Windows 
                }
            } else {
                WriteLog -Message "Not possible read CVA Object for HP Privacy Settings, abort process" -MessageType Error -Verbose
                $global:MessageResults="Not possible read CVA Object for HP Privacy Settings, abort process"
                $global:CodeResults=407
                Out-Windows
            }
            

        } else {
            WriteLog -Message "HP Privacy Settings was detected with name: $($GetPrivacy[0].Name) and version $($GetPrivacy[0].Version)" -Verbose
            if ($null -eq $json.JOBREQUEST.HPSureView.hpprivatesettings) {
                $json.JOBREQUEST.HPSureView | Add-Member -Name "hpprivatesettings" -MemberType NoteProperty -Value $true
            } else {
                $json.JOBREQUEST.HPSureView.hpprivatesettings=$true
            }
            Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSureView "new" $GetPrivacy[0].PackageFullName
        }
        ##################################################################################################################
        ###########               END HP PRIVACY SETTINGS
        ##################################################################################################################
        $GetPrivacy | Out-Host
        WriteLog -Message "HP Privacy Settings was detected on this system under package name: $($GetPrivacy[0].Name) with version: $($GetPrivacy[0].Version)" -Verbose
        WriteLog -Message "Checking setup for HP Sure View" -Verbose
        if ($null -ne (Get-Variable -Name GetCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetCVA -Force -ErrorAction SilentlyContinue }
        ######################################################################################################
        ###########  HP SURE VIEW SETUP  #####################################################################
        ######################################################################################################
        $GetSureView = Get-AppxPackage -AllUsers | Where-Object {$_.Name -like "*hpsureview*"}
        if ($null -eq $GetSureView) {
            WriteLog -Message "It was not possible detect HP Sure View installed on this unit, trying to install" -MessageType Warning -Verbose
            #Search for HP Sure View CVA
            $arrHPSureView = [system.collections.arraylist]@()
            foreach ($cva in $CVAs) {
                if ($null -ne (Get-Variable -Name objCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name objCVA -Force -ErrorAction SilentlyContinue }
                $objCVA = get-CVAobject -pathfile $cva.fullName
                if ($objCVA.Title.Trim().ToLower() -like "*hp sure*view*")
                {
                    WriteLog -Message "Found $($objCVA.Title) V.$($objCVA.version)" -Verbose 
                    [void]$arrHPSureView.add($objCVA);        
                }
            }
            if ($null -ne (Get-Variable -Name GetCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetCVA -Force -ErrorAction SilentlyContinue }
            if ($arrHPSureView.Count -gt 0 ) { 
                $GetCVA = ($arrHPSureView | Sort-Object -property Version -Descending | Sort-Object -Property Length)[0]
            }
            else {
                WriteLog -Message "Not possible locate CVA for HP Sure View, abort process" -MessageType Error -Verbose
                Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSureView "fail" "Not possible locate CVA for HP Sure View, abort process"
                $global:MessageResults="Not possible locate CVA for HP Sure View, abort process"
                $global:CodeResults=406
                Out-Windows 
            }
            if ($null -ne $GetCVA) {
                $GetCVA | Out-Host
                $objResult=@{}
                    $objResult.read=$GetCVA.Silent
                if ($GetCVA.Silent.StartsWith("""")) {
                    $sub = $GetCVA.Silent.Substring(1,$GetCVA.Silent.Length -1)
                    $rem = $sub.indexOf("""")
                    $sub2 = $sub.Substring(0,$rem)
                    if($sub.length -gt $rem +1) {
                        $sub3 = $sub.Substring($rem +1, ($sub.Length - $sub2.Length -1))  
                    } else {
                        $sub3=""
                    }
                    
                } else {
                    if ($GetCVA.Silent.Trim().IndexOf(" ") -gt 0) {
                        $sub2=$GetCVA.Silent.Split(" ")[0]
                        $sub3=$GetCVA.Silent.Replace($sub2,"").Trim()
                    } else {
                        $sub2=$GetCVA.Silent.Trim()
                        $sub3=""
                    }
                    
                }
                    $objResult.file=$sub2
                    $objResult.parameters=$sub3
                    $objResult.silent=$sub2 + $sub3
                WriteLog -Message "Silent command detected: $($objResult.read)" -Verbose                
                WriteLog -Message "Silent command required: $($objResult.silent)" -Verbose
                if (($null -ne $json.JOBREQUEST.HPSureView.retries) -AND ($json.JOBREQUEST.HPSureView.retries -gt 5)) {                        
                    WriteLog -Message "$($GetCVA.Title) has tried for more than 5 times, somenthing is not working, abort process" -Verbose
                    if ($null -ne $json.JOBREQUEST.HPSureView.error) {
                        $global:MessageResults=$json.JOBREQUEST.HPSureView.error
                    } else {
                        $global:MessageResults="$($GetCVA.Title) has tried for more than 5 times, somenthing is not working, abort process"
                    }
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSureView "fail" $global:MessageResults
                    $global:CodeResults=409                        
                    Out-Windows 
                }
                #Run setup
                $RunSetup = Invoke-RunPower -file "cmd.exe" -Params "/c $($GetCVA.Path)\$($objResult.silent)" -WorkDir $GetCVA.Path -OutFile "$($logs)\SetupHPSureView.log" -Verbose
                Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSureView "new" "Setup completed with exit code $($RunSetup)"
                #This application will remove after Generalize image, it require to install using PPSolution
                #copy setup folder
                WriteLog -Message "Preparing for setup during Post-Processing..." -Verbose    
                $NameREG=(Split-Path $GetCVA.Path -Leaf).Replace(" ","_")            
                #create CMD in case that PPSolution is not present
                "@echo off" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force
                "SET log=$($env:SystemDrive)\system.sav\logs\$($NameREG).log" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                "echo  =============  INSTALLING APPX, PLEASE WAIT...   ==================" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                "pushd $($env:SystemDrive)\SWSETUP\HP\$($NameREG)" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                "dir /b /s $($env:SystemDrive)\SWSETUP\HP\$($NameREG) >> %log% 2>&1" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                "start /wait /MIN %~dp0$($objResult.silent) >> %log% 2>&1" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                "echo *exit /b %ERRORLEVEL% >> %log% 2>&1" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                "exit /b %ERRORLEVEL%" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                #copy source                
                $CopySetup = Invoke-RunPower -file "cmd.exe" -Params "/c Xcopy /sehiyk $($GetCVA.Path)\* $($env:SystemDrive)\SWSETUP\HP\$($NameREG)\" -WorkDir $GetCVA.Path -OutFile "$($logs)\Copy$($NameREG).log" 
                if ($CopySetup -ne 0) {
                    WriteLog -Message "Fail copying $($GetCVA.Title) installation for Post-Processing" -MessageType Error -Verbose
                    $global:MessageResults="Fail copying $($GetCVA.Title) installation for Post-Processing"
                    $global:CodeResults=$CopySetup
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSureView "fail" $global:MessageResults
                    Out-Windows
                }                
                #Get status, action and message
                $NotLocatedCode=$true
                foreach ($err in $GetCVA.ReturnCode) {
                    WriteLog -Message "Comparing CVA Return code line: $($err)" -Verbose
                    if ($err.Contains("=") -AND $err.Contains(":")) {
                            $objReturn=@{}
                            if ($null -ne $err.Split("=")[0]) {$objReturn.Codes=$err.Split("=")[0]} else {$objReturn.Codes=""}
                            if ($null -ne $err.Split("=")[1]) {$objReturn.Mess=$err.Split("=")[1]} else {$objReturn.Mess=""}
                            if ($null -ne $objReturn.Codes.Split(":")[0]) {$objReturn.code=$objReturn.Codes.Split(":")[0]} else {$objReturn.code="0"}
                            if ($null -ne $objReturn.Codes.Split(":")[1]) {$objReturn.status=$objReturn.Codes.Split(":")[1]} else {$objReturn.status=""}
                            if ($null -ne $objReturn.Codes.Split(":")[2]) {$objReturn.reboot=$objReturn.Codes.Split(":")[2]} else {$objReturn.reboot=""} 
                        if ([int]$objReturn.code -eq $RunSetup) {
                            WriteLog -Message "Return Code $($RunSetup) was located on CVA, Status: $($objReturn.status), Reboot: $($objReturn.reboot) and message $($objReturn.Mess)" -Verbose
                            $NotLocatedCode=$false
                            if ($objReturn.status.ToUpper().Trim() -eq "SUCCESS") {
                                WriteLog -Message "$($GetCVA.Title) was successfully installed, validation required..." -Verbose
                                $NotLocatedCode=$false
                                if ($objReturn.reboot -eq "REBOOT") {
                                    if ($null -eq $json.JOBREQUEST.HPNotifications.retries) {
                                        $json.JOBREQUEST.HPNotifications | Add-Member -Name "retries" -MemberType NoteProperty -Value 1
                                    } else {
                                        $json.JOBREQUEST.HPNotifications.retries++
                                    }
                                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSureView "new" $objReturn.Mess
                                    WriteLog -Message "This result require reboot unit before to continue." -MessageType Warning -Verbose
                                    $global:MessageResults="This result require reboot unit before to continue."
                                    $global:CodeResults=3010
                                    Out-Windows 
                                }
                                #Vaidate setup
                                $GetSureView = Get-AppxPackage -AllUsers | Where-Object {$_.Name -like "*hpsureview*"}
                                if ($null -eq $GetSureView) {
                                    WriteLog -Message "It was not possible detect HP Sure View installed on this unit, checking if can be installed" -MessageType Error -Verbose
                                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSureView "fail" "It was not possible detect HP Sure View installed on this unit, checking if can be installed"
                                    $global:MessageResults="It was not possible detect HP Sure View installed on this unit, checking if can be installed"
                                    $global:CodeResults=404
                                    Out-Windows
                                }
                                
                                WriteLog -Message "HP Sure View was detected with name: $($GetSureView[0].Name) and version $($GetSureView[0].Version)" -Verbose
                            } else {
                                WriteLog -Message "$($GetCVA.Title) failed during setup, error code: $($RunSetup)" -MessageType Warning -Verbose
                                if ($null -eq $json.JOBREQUEST.HPSureView.retries) {
                                    $json.JOBREQUEST.HPSureView | Add-Member -Name "retries" -MemberType NoteProperty -Value 1
                                } else {
                                    $json.JOBREQUEST.HPSureView.retries++
                                }
                                #NOt detected codes that can fixed with reboot, direct to error message              
                                Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSureView "fail" $objReturn.Mess
                                $global:MessageResults="$($GetCVA.Title) failed during setup" 
                                $global:CodeResults=410
                                Out-Windows                                
                            }
                        }
                    }
                }
                if ($NotLocatedCode) {
                    WriteLog -Message "It was not possible detect code $($RunSetup) on CVA" -Message Error -Verbose
                    $global:MessageResults = "It was not possible detect code $($RunSetup) on CVA" 
                    $global:CodeResults = $RunSetup
                    if ($null -eq $json.JOBREQUEST.HPSureView.retries) {
                        $json.JOBREQUEST.HPSureView | Add-Member -Name "retries" -MemberType NoteProperty -Value 1
                    } else {
                        $json.JOBREQUEST.HPSureView.retries++
                    }
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSureView "fail" $global:MessageResults                        
                    Out-Windows 
                }
            } else {
                WriteLog -Message "Not possible read CVA Object for HP Privacy Settings, abort process" -MessageType Error -Verbose
                Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSureView "fail" "Not possible read CVA Object for HP Privacy Settings, abort process"
                $global:MessageResults="Not possible read CVA Object for HP Privacy Settings, abort process"
                $global:CodeResults=407
                Out-Windows
            }
            

        } else {
            WriteLog -Message "HP Sure View was detected on this system under name: $($GetSureView[0].Name) and version: $($GetSureView[0].Version)" -Verbose
            Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSureView "pass" $GetSureView[0].PackageFullName
        }

        ########### HP SURE VIEW SETUP #######################################################################
        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSureView "pass" "$($GetCVA.Title) was successfully installed"
    } elseif ($json.JOBREQUEST.HPSureView.status.ToLower() -eq "pass") {
        WriteLog -Message "This module already completed" -Verbose
    } elseif ($json.JOBREQUEST.HPSureView.status.ToLower() -eq "fail") {
        WriteLog -Message "HP SureView process already run and failed, need to stop now" -MessageType Error -Verbose
        $global:MessageResults="HP SureView process already run and failed, need to stop now"
        $global:CodeResults=2
        Out-Windows
    } else {
        #value on status is not exppected
        WriteLog -Message "It is not expected to detect status [$($json.JOBREQUEST.HPPrivacySettings.status)], abort process" -Message Error -Verbose
        $global:MessageResults = "It is not expected to detect status [$($json.JOBREQUEST.HPPrivacySettings.status)], abort process"
        $global:CodeResults = 5
        Out-Windows
    }


} else {
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
if ($null -ne (Get-Variable -Name GetSureView -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetSureView -Force -ErrorAction SilentlyContinue } 
if ($null -ne (Get-Variable -Name CopySetup -ErrorAction SilentlyContinue)) { Remove-Variable -Name CopySetup -Force -ErrorAction SilentlyContinue } 
if ($null -ne (Get-Variable -Name NameREG -ErrorAction SilentlyContinue)) { Remove-Variable -Name NameREG -Force -ErrorAction SilentlyContinue } 