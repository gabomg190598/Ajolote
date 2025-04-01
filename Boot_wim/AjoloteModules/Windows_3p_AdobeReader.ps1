<#
Adobe Acrobat Reader DC
    Version 1.0.0
    Date: 10/05/2022
    Root node: $json.JOBREQUEST.AdobeReader
    value: status
        "new", "fail", "pass", "verify"
        "new" means process is running or required, not completed yet
        "fail" process already fail
        "pass" process run successfully
        "verify" files where copied and require install
    Value: error
        Out message

Main Info
http://get.adobe.com/reader/enterprise/
Current version:
    MUI_DC2022.002.20191x64
    22.002.20191
Download date:
    10/7/2022
Supported OS:
    Windows (10, 11)

Source path:
    <componentspath>\Adobe_Reader\MUI_<version>
    version is the one that appears on programs installed

Silent command
    AcroRdrDCx642200220191_MUI.exe -sfx_nu /sALL /msi EULA_ACCEPT=YES

Available Tools to customize setup, it requires apply for Distributor

#>

$AdobeReader_SilentParameters="-sfx_nu /sALL /msi EULA_ACCEPT=YES"
$strSW_Path=(Join-Path $Env:SystemDrive "\SWSETUP\AdobeReader")
$SW_Title="Adobe Acrobat Reader DC"
$strLogfile="Setup_AdobeReader.log"

if ($null -ne $json.JOBREQUEST.AdobeReader) { 
    if ($null -ne $json.JOBREQUEST.AdobeReader.status) {
        WriteLog -Message "$($SW_Title) Module required, checking current status" -Verbose
        if ($json.JOBREQUEST.AdobeReader.status.ToLower().Trim() -eq "verify") {
            WriteLog -Message "Status for $($SW_Title) is verify, means that require validaton and/or installation, checking" -Verbose
            $GetApp=Get-CimInstance -ClassName Win32_Product | Where-Object {$_.Name -like "*Adobe*Acrobat*"}
            if ($null -eq $GetApp) {
                WriteLog -Message "$($SW_Title) requested for this system, checking source files" -Verbose
                if (-Not(Test-Path -Path $strSW_Path -PathType Container)) {
                    WriteLog -Message "Not possible locate expected forlder $($strSW_Path), abort process" -MessageType Error -Verbose
                    $global:MessageResults="Not possible locate expected forlder $($strSW_Path), abort process"
                    $global:CodeResults=404
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.AdobeReader "fail" $global:MessageResults
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
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.AdobeReader "fail" $global:MessageResults
                    Out-Windows 
                }
                $RunSetup = Invoke-RunPower -file "cmd.exe" -Params "/c ""$($Files[0].FullName)"" $($AdobeReader_SilentParameters)" -WorkDir $strSW_Path -OutFile (Join-Path $logs $strLogfile) -Verbose
                if ($RunSetup -ne 0) {
                    WriteLog -Message "$($SW_Title) failed with error code $($RunSetup), abort process" -MessageType Error -Verbose
                    $global:MessageResults="$($SW_Title) failed with error code $($RunSetup), abort process"
                    $global:CodeResults=$RunSetup
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.AdobeReader "fail" $global:MessageResults
                    Out-Windows
                }
                WriteLog -Message "$($SW_Title) successfully installed, validation required..." -Verbose
                $GetApp=Get-CimInstance -ClassName Win32_Product | Where-Object {$_.Name -like "*Adobe*Acrobat*"}
                if ($null -eq $GetApp) {
                    WriteLog -Message "$($SW_Title) not found on Software and Features" -MessageType Error -Verbose
                    Get-CimInstance -ClassName Win32_Product | Select-Object -Property Name,Caption,Vendor,Version | Out-Host
                    $global:MessageResults="$($SW_Title) not found on Software and Features"
                    $global:CodeResults=$RunSetup
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.AdobeReader "fail" $global:MessageResults
                    Out-Windows
                }            
                foreach ($app in $GetApp) {
                    WriteLog -Message "It is detected $($app.Name)[$($app.Caption)] with version $($app.Version), under Software and Features of this system" -Verbose
                }
                if (Test-Path -Path $SW_Title -PathType Container) { Remove-Item -Path $SW_Title -Recurse -Force -ErrorAction SilentlyContinue}
                Update-JobStatus $jobfile $json $json.JOBREQUEST.AdobeReader "pass" "It is detected $($GetApp[0].Name) with version $($GetApp[0].Version), under Software and Features of this system"
            } else {
                foreach ($app in $GetApp) {
                    WriteLog -Message "It is detected $($app.Name) with version $($app.Version), under Software and Features of this system" -Verbose
                }
                Update-JobStatus $jobfile $json $json.JOBREQUEST.AdobeReader "pass" "It is detected $($GetApp[0].Name) with version $($GetApp[0].Version), under Software and Features of this system"
            }
        } elseif ($json.JOBREQUEST.AdobeReader.status.ToLower().Trim() -eq "pass") {
            WriteLog -Message "This module already executed successfully, continue" -Verbose
        } elseif ($json.JOBREQUEST.AdobeReader.status.ToLower().Trim() -eq "new") {
            WriteLog -Message "Status [new] only apply for WinPE stage, something was not executed as expected, abort process" -MessageType Error -Verbose
            $global:MessageResults="Status [new] only apply for WinPE stage, something was not executed as expected, abort process"
            $global:CodeResults=502
            Out-Windows
        } elseif ($json.JOBREQUEST.AdobeReader.status.ToLower().Trim() -eq "fail") {
            WriteLog -Message "Module $($SW_Title) status as fail, abort process" -MessageType Error -Verbose
            $global:MessageResults="Module $($SW_Title) status as fail, abort process"
            $global:CodeResults=500
            Out-Windows
        } else {
            WriteLog -Message "Module $($SW_Title) unknown status [$($json.JOBREQUEST.AdobeReader.status)], abort process" -MessageType Error -Verbose
            $global:MessageResults="Module $($SW_Title) unknown status [$($json.JOBREQUEST.AdobeReader.status)], abort process" 
            $global:CodeResults=501
            Out-Windows
        }
    } else {
        WriteLog -Message "Module Adobe Acrobat Reader DC missing status tag" -MessageType Error -Verbose
        $global:MessageResults="Module Adobe Acrobat Reader DC missing status tags" 
        $global:CodeResults=2
        Out-Windows
    }
} else {
    WriteLog -Message "This module is not required or status tag is missing" -Verbose
}