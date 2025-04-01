<#
Java
    Version 1.0.0
    Date: 10/11/2022
    Root node: $json.JOBREQUEST.Java
    value: status
        "new", "fail", "pass", "verify"
        "new" means process is running or required, not completed yet
        "fail" process already fail
        "pass" process run successfully
        "verify" files where copied and require install
    Value: error
        Out message

Main Info
https://www.java.com/en/download/manual.jsp
https://www.java.com/en/download/windows_offline.jsp
Current version:
    8u341
Download date:
    10/12/2022
Supported OS:
    Windows (10, 11) x64

Source path:
    <componentspath>\Java\<version>

Silent command
    jre-8u341-windows-x64.exe /s REBOOT=Suppress

Should be installed after browsers (Chrome and Firefox)

#>

$Java_SilentParameters="/s REBOOT=Suppress"
$strSW_Path=(Join-Path $Env:SystemDrive "\SWSETUP\Java")
$SW_Title="Java"
$strLogfile="Setup_Java.log"

if ($null -ne $json.JOBREQUEST.Java) { 
    if ($null -ne $json.JOBREQUEST.Java.status) {
        WriteLog -Message "$($SW_Title) Module required, checking current status" -Verbose
        if ($json.JOBREQUEST.Java.status.ToLower().Trim() -eq "verify") {
            WriteLog -Message "Status for $($SW_Title) is verify, means that require validaton and/or installation, checking" -Verbose
            if ($null -ne (Get-Variable -Name GetApp -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetApp -Force -ErrorAction SilentlyContinue }
            $GetApp=Get-CimInstance -ClassName Win32_Product | Where-Object {$_.Name -like "*Java*Update *"}            
            if ($null -eq $GetApp) {
                WriteLog -Message "$($SW_Title) requested for this system, checking source files" -Verbose
                if (-Not(Test-Path -Path $strSW_Path -PathType Container)) {
                    WriteLog -Message "Not possible locate expected forlder $($strSW_Path), abort process" -MessageType Error -Verbose
                    $global:MessageResults="Not possible locate expected forlder $($strSW_Path), abort process"
                    $global:CodeResults=404
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.Java "fail" $global:MessageResults
                    Out-Windows 
                }
                $Files=Get-ChildItem -Path $strSW_Path -Filter "*.exe" -File
                $Files | ForEach-Object {WriteLog -Message "Detected present file: $($_.Name)" -Verbose; }
                if (($Files | Measure-Object).Count -eq 1) {
                    WriteLog -Message "Found Setup file: $($Files[0].Name)" -Verbose
                } elseif (($Files | Measure-Object).Count -gt 1) {
                    WriteLog -Message "It was not expected to have more than one setup file, it only possible to use one, first detected: $($Files[0].Name)" -MessageType Warning -Verbose
                } else {
                    WriteLog -Message "Not possible locate expected executable file, abort process" -MessageType Error -Verbose
                    $global:MessageResults="Not possible locate expected executable file, abort process"
                    $global:CodeResults=405
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.Java "fail" $global:MessageResults
                    Out-Windows 
                }
                $RunSetup = Invoke-RunPower -file "cmd.exe" -Params "/c ""$($Files[0].FullName)"" $($Java_SilentParameters)" -WorkDir $strSW_Path -OutFile (Join-Path $logs $strLogfile) -Verbose
                if ($RunSetup -ne 0) {
                    WriteLog -Message "$($SW_Title) failed with error code $($RunSetup), abort process" -MessageType Error -Verbose
                    $global:MessageResults="$($SW_Title) failed with error code $($RunSetup), abort process"
                    $global:CodeResults=$RunSetup
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.Java "fail" $global:MessageResults
                    Out-Windows
                }
                WriteLog -Message "$($SW_Title) successfully installed, validation required..." -Verbose
                $GetApp=Get-CimInstance -ClassName Win32_Product | Where-Object {$_.Name -like "*Java*Update *"}  
                if ($null -eq $GetApp) {
                    WriteLog -Message "$($SW_Title) not found on Software and Features" -MessageType Error -Verbose
                    Get-CimInstance -ClassName Win32_Product | Select-Object -Property Name,Caption,Vendor,Version | Out-Host
                    $global:MessageResults="$($SW_Title) not found on Software and Features"
                    $global:CodeResults=$RunSetup
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.Java "fail" $global:MessageResults
                    Out-Windows
                }
                WriteLog -Message "It is detected $($GetApp[0].Name) with version $($GetApp[0].Version), on this system" -Verbose
                if (Test-Path -Path $strSW_Path -PathType Container) { Remove-Item -Path $strSW_Path -Recurse -Force -ErrorAction SilentlyContinue}
                Update-JobStatus $jobfile $json $json.JOBREQUEST.Java "pass" "It is detected $($GetApp[0].Name) with version $($GetApp[0].Version), on this system"
            } else {                
                WriteLog -Message "It is detected $($GetApp[0].Name) with version $($GetApp[0].Version), on this system" -Verbose
                if (Test-Path -Path $strSW_Path -PathType Container) { Remove-Item -Path $strSW_Path -Recurse -Force -ErrorAction SilentlyContinue}
                Update-JobStatus $jobfile $json $json.JOBREQUEST.Java "pass" "It is detected $($GetApp[0].Name) with version $($GetApp[0].Version), on this system"
            }
        } elseif ($json.JOBREQUEST.Java.status.ToLower().Trim() -eq "pass") {
            WriteLog -Message "This module already executed successfully, continue" -Verbose
        } elseif ($json.JOBREQUEST.Java.status.ToLower().Trim() -eq "new") {
            WriteLog -Message "Status [new] only apply for WinPE stage, something was not executed as expected, abort process" -MessageType Error -Verbose
            $global:MessageResults="Status [new] only apply for WinPE stage, something was not executed as expected, abort process"
            $global:CodeResults=502
            Out-Windows
        } elseif ($json.JOBREQUEST.Java.status.ToLower().Trim() -eq "fail") {
            WriteLog -Message "Module $($SW_Title) status as fail, abort process" -MessageType Error -Verbose
            $global:MessageResults="Module $($SW_Title) status as fail, abort process"
            $global:CodeResults=500
            Out-Windows
        } else {
            WriteLog -Message "Module $($SW_Title) unknown status [$($json.JOBREQUEST.Java.status)], abort process" -MessageType Error -Verbose
            $global:MessageResults="Module $($SW_Title) unknown status [$($json.JOBREQUEST.Java.status)], abort process" 
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

if ($null -ne (Get-Variable -Name GoogleChrome_SilentParameters -ErrorAction SilentlyContinue)) { Remove-Variable -Name GoogleChrome_SilentParameters -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name strSW_Path -ErrorAction SilentlyContinue)) { Remove-Variable -Name strSW_Path -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name SW_Title -ErrorAction SilentlyContinue)) { Remove-Variable -Name SW_Title -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name GetApp -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetApp -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name Files -ErrorAction SilentlyContinue)) { Remove-Variable -Name Files -Force -ErrorAction SilentlyContinue }
