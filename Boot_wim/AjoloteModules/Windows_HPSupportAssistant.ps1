<#
HP Support Assistant
    Version 1.0.0
    Date: 10/11/2022
    Root node: $json.JOBREQUEST.HPSupportAssistant
    value: status
        "new", "fail", "pass", "verify"
        "new" means process is running or required, not completed yet
        "fail" process already fail
        "pass" process run successfully
        "verify" files where copied and require install
    Value: error
        Out message
    value: reboot
        boolean used to mark when setup runs


Main Info
https://support.hp.com/mx-es/help/hp-support-assistant
Current version:
    9.20.22.0
Download date:
    10/25/2022
Supported OS:
    Windows (10, 11) x64

Source path:
    <componentspath>\HP_Support_Assistant\<version>

Silent command
    Setup.exe /s


#>

$Setup_SilentParameters="/s"
$Setup_Silent="Setup.exe"
$strSW_Path=(Join-Path $Env:SystemDrive "\SWSETUP\HP_Support_Assistant")
$SW_Title="HP Support Assistant"
$strLogfile="Setup_$($SW_Title.Replace(" ","_")).log"
$SearchApp="HPSupportAssistant"

if ($null -ne $json.JOBREQUEST.HPSupportAssistant) { 
    if ($null -ne $json.JOBREQUEST.HPSupportAssistant.status) {
        WriteLog -Message "$($SW_Title) Module required, checking current status" -Verbose
        if ($json.JOBREQUEST.HPSupportAssistant.status.ToLower().Trim() -eq "verify") {
            WriteLog -Message "Status for $($SW_Title) is verify, means that require validaton and/or installation, checking" -Verbose
            if ($null -ne (Get-Variable -Name GetApp -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetApp -Force -ErrorAction SilentlyContinue }
            $GetApp = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*$($SearchApp)*" }  
            if ($null -eq $GetApp) {
                WriteLog -Message "$($SW_Title) requested for this system, checking source files" -Verbose
                if (-Not(Test-Path -Path $strSW_Path -PathType Container)) {
                    WriteLog -Message "Not possible locate expected forlder $($strSW_Path), abort process" -MessageType Error -Verbose
                    $global:MessageResults="Not possible locate expected forlder $($strSW_Path), abort process"
                    $global:CodeResults=404
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSupportAssistant "fail" $global:MessageResults
                    Out-Windows 
                }
                if (-Not(Test-Path -Path (Join-Path $strSW_Path $Setup_Silent))) {
                    WriteLog -Message "Not possible locate executable file, abort process" -MessageType Error -Verbose
                    $global:MessageResults="Not possible locate executable file, abort process"
                    $global:CodeResults=405
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSupportAssistant "fail" $global:MessageResults
                    Out-Windows 
                }
                if (($null -ne $json.JOBREQUEST.HPSupportAssistant.reboot) -AND ($json.JOBREQUEST.HPSupportAssistant.reboot)) {                        
                    WriteLog -Message "After setup, $($SW_Title) still cannot be detected, abort process to review logs" -Verbose
                    $global:MessageResults = "After setup, $($SW_Title) still cannot be detected, abort process to review logs"
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPPrivacySettings "fail" $global:MessageResults
                    $global:CodeResults = 409                     
                    Out-Windows 
                }
                $RunSetup = Invoke-RunPower -file "cmd.exe" -Params "/c ""$((Join-Path $strSW_Path $Setup_Silent))"" $($Setup_SilentParameters)" -WorkDir $strSW_Path -OutFile (Join-Path $logs $strLogfile) -Verbose
                if ($null -eq $json.JOBREQUEST.HPSupportAssistant.reboot) {
                    $json.JOBREQUEST.HPSupportAssistant | Add-Member -Name "reboot" -MemberType NoteProperty -Value $true
                }
                else {
                    $json.JOBREQUEST.HPSupportAssistant.reboot = $true
                }
                if ($RunSetup -eq 3010) {
                    WriteLog -Message "$($SW_Title) for code $($RunSetup) require reboot" -MessageType Error -Verbose
                    $global:MessageResults="$($SW_Title) for code $($RunSetup) require reboot"
                    $global:CodeResults=$RunSetup 
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSupportAssistant "verify" $global:MessageResults
                    Out-Windows
                }
                if ($RunSetup -ne 0) {
                    WriteLog -Message "$($SW_Title) failed with error code $($RunSetup), abort process" -MessageType Error -Verbose
                    $global:MessageResults="$($SW_Title) failed with error code $($RunSetup), abort process"
                    $global:CodeResults=$RunSetup
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSupportAssistant "fail" $global:MessageResults
                    Out-Windows
                }
                WriteLog -Message "$($SW_Title) successfully installed, validation required..." -Verbose
                $GetApp = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*$($SearchApp)*" }  
                if ($null -eq $GetApp) {
                    WriteLog -Message "$($SW_Title) not found Installed on this system" -MessageType Error -Verbose
                    $global:MessageResults="$($SW_Title) not found on Software and Features"
                    $global:CodeResults=101
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSupportAssistant "fail" $global:MessageResults
                    Out-Windows
                }
                WriteLog -Message "It is detected $($GetApp[0].Name) with version $($GetApp[0].Version), on this system" -Verbose
                if (Test-Path -Path $strSW_Path -PathType Container) { Remove-Item -Path $strSW_Path -Recurse -Force -ErrorAction SilentlyContinue}
                Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSupportAssistant "pass" "It is detected $($GetApp[0].Name) with version $($GetApp[0].Version), on this system"
            } else {                
                WriteLog -Message "It is detected $($GetApp[0].Name) with version $($GetApp[0].Version), on this system" -Verbose
                if (Test-Path -Path $strSW_Path -PathType Container) { Remove-Item -Path $strSW_Path -Recurse -Force -ErrorAction SilentlyContinue}
                Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSupportAssistant "pass" "It is detected $($GetApp[0].Name) with version $($GetApp[0].Version), on this system"
            }
        } elseif ($json.JOBREQUEST.HPSupportAssistant.status.ToLower().Trim() -eq "pass") {
            WriteLog -Message "This module was already executed successfully, continue" -Verbose
        } elseif ($json.JOBREQUEST.HPSupportAssistant.status.ToLower().Trim() -eq "new") {
            WriteLog -Message "Status [new] only apply for WinPE stage, something was not executed as expected, abort process" -MessageType Error -Verbose
            $global:MessageResults="Status [new] only apply for WinPE stage, something was not executed as expected, abort process"
            $global:CodeResults=502
            Out-Windows
        } elseif ($json.JOBREQUEST.HPSupportAssistant.status.ToLower().Trim() -eq "fail") {
            WriteLog -Message "Module $($SW_Title) status as fail, abort process" -MessageType Error -Verbose
            $global:MessageResults="Module $($SW_Title) status as fail, abort process"
            $global:CodeResults=500
            Out-Windows
        } else {
            WriteLog -Message "Module $($SW_Title) unknown status [$($json.JOBREQUEST.HPSupportAssistant.status)], abort process" -MessageType Error -Verbose
            $global:MessageResults="Module $($SW_Title) unknown status [$($json.JOBREQUEST.HPSupportAssistant.status)], abort process" 
            $global:CodeResults=501
            Out-Windows
        }
    } else {
        WriteLog -Message "Module $($SW_Title) missing status tag" -MessageType Error -Verbose
        $global:MessageResults="Module $($SW_Title) missing status tags" 
        $global:CodeResults=2
        Out-Windows
    }
} else {
    WriteLog -Message "This module is not required or status tag is missing" -Verbose
}

if ($null -ne (Get-Variable -Name Setup_SilentParameters -ErrorAction SilentlyContinue)) { Remove-Variable -Name Setup_SilentParameters -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name Setup_Silent -ErrorAction SilentlyContinue)) { Remove-Variable -Name Setup_Silent -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name strSW_Path -ErrorAction SilentlyContinue)) { Remove-Variable -Name strSW_Path -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name SW_Title -ErrorAction SilentlyContinue)) { Remove-Variable -Name SW_Title -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name strLogfile -ErrorAction SilentlyContinue)) { Remove-Variable -Name strLogfile -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name GetApp -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetApp -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name SearchApp -ErrorAction SilentlyContinue)) { Remove-Variable -Name SearchApp -Force -ErrorAction SilentlyContinue }
