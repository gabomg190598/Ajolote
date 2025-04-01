<#
.SYNOPSIS
    CS Build Image - Windows Phase
.DESCRIPTION
    System to prepare Images
.NOTES
	AJOLOTE 2.0
	Script Date Jan.6.2022
    Version 2.0.2
        Updated function to prevent an issue updating job file make fail all module.
    Version 2.0.3
        Try to unmount job share before to sysprep image
    Version 2.0.4
        throw JOB to logs
    Version 2.0.5
        Adding closing start menu for any Windows 11 version

.EXAMPLE 

#>

[cultureinfo]::CurrentCulture = 'en-US'
# Load Modules
$ModulesFolder="$($PSScriptRoot)\CSModules"
[string[]] $CSModules = @(
		"WriteLog",
		"RunPower",
		"RunDism",
		"GetDrive",
		"CreateF11",
		"WDTFunctions",
		"GetDevice",
		"AssLetterAll",
		"MSUpdates",
		"WindowStyle",
		"HPControl",
		"AED_Support",
		"WinPESave"
	)
foreach ($module in $CSModules) {
    if(!(Get-Module $module)) {
        $FindModule = Get-ChildItem -Path $ModulesFolder -Filter "$($module).psm1" -Recurse -file;
        if ($null -ne $FindModule) {
            try { Import-Module $FindModule[0].FullName; Write-Host "<---Loading Module $($module)" -ForegroundColor DarkGray; } catch { $MissingModule+="$($module)," }
        } else {
            Write-Warning "Missing Module: $($module)";
        }
    } else {
        Write-Host "<---Loaded Module $($module)" -ForegroundColor DarkGray;
    }
}
foreach ($module in $CSModules) { if(!(Get-Module $module)) {Write-Host "Not possible found/load required module for $($MyInvocation.MyCommand.Name): $($module)" -ForegroundColor Yellow -BackgroundColor Red;  }}
if ($MissingModule) { Write-Warning "ABORT PROCESS: Missing Modules: $($MissingModule)"; . "$($PSScriptRoot)\ReturnAjolote.ps1"; exit 104; }

<##########################################################
    ADD SYSTEM SCRIPTS - FUNCTIONS
###########################################################>
[string[]]$ScriptFunction = @(
    "CSBuiltimage.Functions.ps1"
)
foreach ($script in $ScriptFunction) {
    try {
        if (!(Test-Path -Path "$($PSScriptRoot)\$($script)" -PathType Leaf)){
            Write-Error "Missing Module file: $($script)"
        }
        Import-Module "$($PSScriptRoot)\$($script)"
        Write-Host "Module loaded: $($script)" -BackgroundColor Black -ForegroundColor Green        
    }
    catch {
        Write-Error "Not possible load Script Modules"
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}



<#################### VARIABLES #>
$global:ScriptVer="2.0.5"
$global:MessageResults=""
$global:CodeResults=0
$global:envDrive=""
$global:JobShareDrive=""
$global:DebugMode=$false


##### CREATE AND SET LOGS FOLDER
#[string]$UniqueFolder=Get-Date -Format "MMddyyyy_hhmmss"
$AjoloteDrive=(Get-Volume | Where-Object {$_.FileSystemLabel -eq "AJOLOTE" }).DriveLetter
$global:envDrive="$($AjoloteDrive):"
if (($null -eq $AjoloteDrive) -OR ($AjoloteDrive.Length -ne 1)) {
    $LocalDrive=$env:SystemDrive
} else {
    $AjoloteDrive="$($AjoloteDrive):"
    $LocalDrive=$AjoloteDrive
}


if (!(Test-Path "$($LocalDrive)\system.sav")) {
    New-Item -Path "$($LocalDrive)\system.sav" -ItemType Directory -Force 
    attrib +h $($LocalDrive)\system.sav /d 
}
if (!(Test-Path "$($LocalDrive)\system.sav\logs\CSBuilt")) {
    New-Item -Path "$($LocalDrive)\system.sav\logs\CSBuilt" -ItemType Directory -Force 
}
$UniqueFolder="HPLOGS_"
$GetDirsLogs=Get-ChildItem -Path "$($LocalDrive)\system.sav\logs\CSBuilt" -Directory -Filter "$($UniqueFolder)*" | Sort-Object -Property Name -Descending

if ($null -eq $GetDirsLogs) {
	$UniqueFolder="HPLOGS_0"
} else {
    $UniqueFolder=$GetDirsLogs[0].Name
}
if (!(Test-Path "$($LocalDrive)\system.sav\logs\CSBuilt\$($UniqueFolder)")) {
    New-Item -Path "$($LocalDrive)\system.sav\logs\CSBuilt\$($UniqueFolder)" -ItemType Directory -Force 
}

$logs="$($LocalDrive)\system.sav\logs\CSBuilt\$($UniqueFolder)"
$Global:logs="$($LocalDrive)\system.sav\logs\CSBuilt\$($UniqueFolder)"
$CSBuildErrorFlag="$($env:SystemDrive)\system.sav\flags\csbuilderror.flg"
$FSAutoJobFlag="$($env:SystemDrive)\system.sav\flags\fsbackwinpe.flg"


try {
    if (Test-Path -Path "$($logs)\WindowsTranscription.log" -PathType Leaf ) {
        Start-Transcript -Path "$($logs)\WindowsTranscription.log" -Append | Out-Null
    } else {
        Start-Transcript -Path "$($logs)\WindowsTranscription.log" -Append | Out-Null
    }
    
}
catch {
    Stop-Transcript -Force
    if (Test-Path -Path "$($logs)\WindowsTranscription.log" -PathType Leaf ) {
        Start-Transcript -Path "$($logs)\WindowsTranscription.log" -Append | Out-Null
    } else {
        Start-Transcript -Path "$($logs)\WindowsTranscription.log" -Append | Out-Null
    }
}

Clear-Host
WriteLog -Message "--------------------  BUILD IMAGE TOOL -----------------------" -Verbose -Path $logs -Name "_BuildImage.log" 
WriteLog -Message "------------------------  WINDOWS ----------------------------" -Verbose
WriteLog -Message "------------------------  $($global:ScriptVer) ----------------------------" -Verbose
Get-Process -Id $PID -ErrorAction SilentlyContinue | Set-WindowStyle -Style MAXIMIZE

#--Create Keep-a-live script
"`$WShell = New-Object -Com Wscript.Shell" | Out-File -FilePath "$($PSScriptRoot)\KeepAlive.ps1" -Append -Encoding default
"while (1) {`$WShell.SendKeys(""{SCROLLLOCK}""); Get-Process | Where-Object {`$_.Name -like ""*teams*""} | Stop-Process -Force; sleep 60}" | Out-File -FilePath "$($PSScriptRoot)\KeepAlive.ps1" -Append -Encoding default
$keepalive = Start-Process -FilePath "PowerShell.exe" -ArgumentList "-ExecutionPolicy bypass -File ""$($PSScriptRoot)\KeepAlive.ps1"" -NoProfile -WindowStyle Maximized"  -WindowStyle Hidden -PassThru
WriteLog -Message "Keep alive script runing under ID: $($keepalive.Id)" -Verbose
Start-Sleep -Seconds 5
#--Close sysprep
while ((Get-Process | Where-Object { $_.ProcessName -like "*sysprep*"}).Count -gt 0) {
	$sysp = Get-Process | Where-Object { $_.ProcessName -like "*sysprep*"}
	if ($sysp) { WriteLog -Message "Sysprep tool is open, closing for now"; Stop-Process -Id $sysp.Id; Start-Sleep -Seconds 3; }
}

if (Test-Path -Path "$($LocalDrive)\config.xml" -PathType Leaf) {
    Try {
        $ConfigXML="$($LocalDrive)\config.xml"
        $computername = (Select-Xml -Path $ConfigXML -XPath "/AJOLOTE/computername").Node.'#text'
    } catch {
        $computername=(Get-WmiObject Win32_OperatingSystem).CSName
    }
} else {
    $computername=(Get-WmiObject Win32_OperatingSystem).CSName
}

<#############################################
##   COPY RESOURCES
###############################################>
$utilpath="C:\system.sav\util"
if (Test-Path -Path (Join-Path $LocalDrive "config.xml") -PathType Leaf) {Copy-Item -Path (Join-Path $LocalDrive "config.xml") -Destination (Join-Path $utilpath "config.xml") -Force}
if (Test-Path -Path (Join-Path $LocalDrive "cred.xml") -PathType Leaf) {Copy-Item -Path (Join-Path $LocalDrive "cred.xml") -Destination (Join-Path $utilpath "cred.xml") -Force}


<###############################################
##  GET OS INFORMATION
################################################>
$OS=@{}
    $OS.ProductName = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').ProductName
    $OS.Architecture = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
    $OS.Version = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').ReleaseId
    $OS.Branch = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').BuildBranch
	$OS.Build = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuildNumber
	$OS.Revision = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').UBR
    $OS.DisplayVersion = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DisplayVersion
    switch ($OS.Build) {
        "22000" {$OS.Name = $OS.ProductName.Replace(" 10 "," 11 ");  }
        "22621" {$OS.Name = $OS.ProductName.Replace(" 10 "," 11 ");  }
        Default {$OS.Name = $OS.ProductName;}
    }
    $WinVersion=$OS.Build
    $WinVersion | Out-Null
    $SKU=(Get-CimInstance -Namespace ROOT\HP\InstrumentedBIOS -ClassName HP_BIOSSetting | Where-Object {$_.Name -eq "SKU Number"}).Value


WriteLog -Message " Checking PowerShell Version: $($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor).$($PSVersionTable.PSVersion.Build).$($PSVersionTable.PSVersion.Revision)" -Verbose
WriteLog -Message "             Script version : $($global:ScriptVer)" -Verbose
WriteLog -Message "      Executing script from : $((Get-Item -Path '.\' -Verbose).FullName)" -Verbose
WriteLog -Message "           Current User Name: $($env:USERNAME)" -Verbose
WriteLog -Message "                  Current OS: $((Get-WmiObject Win32_OperatingSystem).Name)" -Verbose
WriteLog -Message "            Current OS Drive: $($env:HOMEDRIVE)" -Verbose
WriteLog -Message "     Current OS Architecture: $($env:PROCESSOR_ARCHITECTURE)" -Verbose
WriteLog -Message "     Current OS Architecture: $((Get-WmiObject Win32_OperatingSystem).OSArchitecture)" -Verbose
WriteLog -Message "             Current PC Name: $($computername)" -Verbose
WriteLog -Message "              Computer Model: $((Get-WmiObject Win32_Computersystem).Model) [$((Get-WmiObject Win32_BaseBoard).Product)]" -Verbose 
WriteLog -Message "               Serial Number: $((Get-WmiObject Win32_Bios).SerialNumber)" -Verbose
WriteLog -Message "                  SKU Number: $($SKU)" -Verbose
if ($SKU.Contains('@')) { $SKU = $SKU.Substring(0,$SKU.IndexOf('@')) }
if ($SKU.Contains('#')) { 
    $AV=$SKU.Split('#')[0]
    $LOC=$SKU.Split('#')[1]
    WriteLog -Message "                      SKU AV: $($AV)" -Verbose				
    WriteLog -Message "            SKU Localization: $($LOC)" -Verbose	
}							
WriteLog -Message "                Windows Name: $($OS.Name)" -Verbose
WriteLog -Message "         Windows ProductName: $($OS.ProductName)" -Verbose
WriteLog -Message "             Windows Version: $($OS.Version)" -Verbose
WriteLog -Message "       Windows Build Version: $($OS.Build)" -Verbose
WriteLog -Message "      Windows Build Revision: $($OS.Revision)" -Verbose
WriteLog -Message "      Windows DisplayVersion: $($OS.DisplayVersion)" -Verbose
WriteLog -Message "              Windows Branch: $($OS.Branch)" -Verbose
WriteLog -Message "              Logs Unique ID: $($UniqueFolder)" -Verbose
WriteLog -Message "------------------------------------------------------------------------------" -Verbose

$JobFile="$($AjoloteDrive)\job.json"
if (Test-Path -Path $jobfile -PathType Leaf) {
    WriteLog -Message "Detected JOB file, continue process" -Verbose
} else {
    WriteLog -Message "There are no JOB file, Not expected to reach this point without job file" -MessageType Error -Verbose
    $global:MessageResults="Not expected to reach Windows configuration without job file"
    $global:CodeResults=404
    . "$($PSScriptRoot)\ReturnAjolote.ps1"
    Out-Windows
}
if (Test-Path HKLM:\SYSTEM\Setup) { 
    $regkey = Get-ItemProperty -Path HKLM:\SYSTEM\Setup -Name SystemSetupInProgress;
    WriteLog -Message "HKLM:\SYSTEM\Setup SystemSetupInProgress=[$($regkey.SystemSetupInProgress)]" -Verbose
}
<##############################################################
#   For Windows 11, first boot, Start menu its open, close it 
###############################################################>
if ([int]$OS.Build -ge 22000){
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.SendKeys]::SendWait('^{ESC}')
    [System.Windows.Forms.SendKeys]::SendWait('{ESC}')
}

<##########################################
##        TEST AND WORK WITH JOB.json
##########################################>

WriteLog -Message "Load current JOB" -Verbose
try {
    $json = Get-Content $jobfile -Raw | ConvertFrom-Json
    if ($null -eq $json.JOBREQUEST) {
        throw [System.Exception] "JOB file has unexpected format, root node incorrect"
    }
    WriteLog -Message "Tested successfully JOB.json file" -Verbose
    if (-Not([string]::IsNullOrEmpty($json.JOBREQUEST.Job.status))) {
        WriteLog -Message "Current Job Status: [$($json.JOBREQUEST.Job.status)]" -Verbose
    } elseif (-Not([string]::IsNullOrEmpty($json.JOBREQUEST.Control.status))) {
        WriteLog -Message "Current Control Status: [$($json.JOBREQUEST.Control.status)]" -Verbose
    }
}
catch {
    $ErrorMessage = $_.Exception.Message
    WriteLog -Message "Not possible load JOB.json: $($ErrorMessage)" -Verbose
    $global:MessageResults=$ErrorMessage
    $global:CodeResults=205
    Out-Windows
}

WriteLog -Message "JOB detected:`r`n"
$json | ConvertTo-Json -Depth 16 | Out-File -FilePath (Join-Path $logs "_BuildImage.log") -Encoding ascii -Append -Force
$json | ConvertTo-Json -Depth 16 | Out-Host


################################################
#  pause flag
################################################
if (Test-Path -Path $CSBuildErrorFlag -PathType Leaf){
    $TimerError = [Diagnostics.Stopwatch]::StartNew()
    WriteLog -Message "Error flag found, fix issue and remove to perform retry" -MessageType Warning -Verbose
    while (Test-Path -Path $CSBuildErrorFlag -PathType Leaf) {
        Start-Sleep -Seconds 5
        if (($TimerError.Elapsed.TotalSeconds -gt 600) -AND ($TimerError.Elapsed.TotalSeconds -lt 608)) {
            if ($null -ne $json.JOBREQUEST.Job) {
                WriteLog -Message "Job in progress detected, unit will reboot and back to Ajolote WinPE environment" -Verbose
                WriteLog -Message "To continue with debug and prevent return, delete: $($FSAutoJobFlag)" -Verbose                
                "Back to WinPE" | Out-File -FilePath $FSAutoJobFlag -Encoding ascii -Force
                $contError=Get-Content -Path $CSBuildErrorFlag 
                if ($contError.Length -gt 0) {
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.Job "fail" $contError.Trim()
                } else {
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.Job "fail" "Error flg detected"
                }                
            }
        }
        if ($TimerError.Elapsed.TotalMinutes -gt 12) {
            if (Test-Path -Path $FSAutoJobFlag) {
                $global:MessageResults="Error flag detected but job is running, return to WinPE"
                $global:CodeResults=920
                . "$($PSScriptRoot)\ReturnAjolote.ps1"
                Out-Windows
            }
        }
    }

}



<########################################################
##  LOAD NETWORK DRIVERS FOR AJOLOTE UNIT
This allows unit to connect to server to update job
#########################################################>
if ($null -eq $json.JOBREQUEST.PNP) {
    $json.JOBREQUEST | Add-Member -Name "PNP" -MemberType NoteProperty -Value "get"
    ### Save JOB file
    try {
        $json | ConvertTo-Json -Depth 16 | Out-File -FilePath $jobfile -Encoding ascii -Force
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        WriteLog -Message "Failed updating JOB file: $($ErrorMessage)" -MessageType Error -Verbose
        $global:MessageResults="Failed updating JOB file: $($ErrorMessage)"
        $global:CodeResults=209
        Out-Windows
    }
    WriteLog -Message "Extract online Drivers" -Verbose
    Get-WindowsDriver -Online -All  | Export-CSV -Path (Join-Path $logs "PSDrivers_list.csv") -NoTypeInformation
    if ($null -ne $json.JOBREQUEST.Drivers.sysid) {
        if (!(Test-Path -Path "C:\system.sav\logs" -PathType Container)) {New-Item -Path "C:\system.sav\logs" -ItemType Directory -Force}
        Copy-Item -Path (Join-Path $logs "PSDrivers_list.csv") -Destination "C:\system.sav\logs\PSDrivers_list.csv" -Force
    }
    
    $PathINF = (Join-Path (Join-Path (Join-Path $AjoloteDrive "TOOLS") "WindowsDrivers") "$((Get-WmiObject Win32_BaseBoard).Product)")
    $PNPrebootflag=$false
    if (Test-Path -Path $PathINF -PathType Container) {
        WriteLog -Message "Detected a folder of drivers for this Ajolote platform, try to added" -Verbose
        $INFs=Get-ChildItem -Path $PathINF -Recurse -Filter "*.inf" -File
        foreach ($inf in $INFs) {
            $InstallPNP = Invoke-RunPower -File "cmd.exe" -Params "/c pnputil /add-driver ""$($inf.FullName)"" /install >> $((Join-Path $logs "OEMs.log"))" -WorkDir $PSScriptRoot -OutFile "$($logs)\HPNetOEMDrivers.log" -Verbose 
            if ($InstallPNP -ne 0) {
                WriteLog -Message "There was an error installing driver: $($inf.FullName)" -MessageType Error -Verbose
            } elseif ($InstallPNP -ne 3010) {
                $PNPrebootflag=$true
            }
        } 
    }
    #If Exist OEMs.log it need to convert into CSV
    $filePath=(Join-Path $logs "OEMs.log")
    if (Test-Path $filePath -PathType Leaf) {
        WriteLog -Message "Export Driver:OEM list to be used later on process, extract values..." -Verbose
        $CNT=Get-Content $filePath
        $DRVlabel="Adding driver package:"
        $OEMlabel="Published Name:"
        $Found=$false
        $OEMname=""
        $DRVname=""
        $OEMDic = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        foreach ($line in $CNT) {
            if ($Found) {
                if ($line.StartsWith($OEMlabel)) {
                    $OEMname=$line.Replace($OEMlabel,"").Trim()
                    WriteLog -Message "Add new value $($DRVname):$($OEMname)" -Verbose
                    $OEMDic.Add($DRVname,$OEMname)
                    $OEMname=""
                    $DRVname=""
                    $Found=$false
                } elseif ($line.StartsWith($DRVlabel)) {
                    WriteLog -Message "Unexpected start of line, not located OEM driver" -MessageType Error -Verbose
                    $DRVname=$line.Replace($DRVlabel,"").Trim()
                    $OEMname=""
                    $Found=$true
                }
            } else {
                if ($line.StartsWith($DRVlabel)) {
                    $DRVname=$line.Replace($DRVlabel,"").Trim()
                    $Found=$true
                } 
            }
        }
        WriteLog -Message "Exporting extracted values" -Verbose
        $OEMDic.GetEnumerator() | ForEach-Object {
            $key=$_.key;$value=$_.value
            New-Object -Type psobject -Property $_.Values |
            Select-Object @{n='Driver';e={$key}},@{n='OEM';e={$value}}
        } |	Export-Csv (Join-Path $logs "OEM.csv") -Notype
    }
  
    if ($PNPrebootflag) {
        if ($null -ne $json.JOBREQUEST.Job) {
            Update-JobStatus $jobfile $json $json.JOBREQUEST.Job "processing" "Ajolote network drivers was added, building image"
        }        
        if ($null -ne $json.JOBREQUEST.Control) {
            Update-JobStatus $jobfile $json $json.JOBREQUEST.Control "processing" "Ajolote network drivers was added, building image"
        }
        WriteLog -Message "It is required reboot unit to drivers take effect" -MessageType Warning -Verbose
        $global:MessageResults="Reboot to apply Network drivers installed by pnputil"
        $global:CodeResults=3010
        Out-Windows
    }
}


#Mound Jobpath to keep update job after each module
if ($null -ne (Get-Variable -Name MountPoint -ErrorAction SilentlyContinue)) { Remove-Variable -Name MountPoint -Force -ErrorAction SilentlyContinue }
[string]$MountPoint=Invoke-MountServer "/jobpath"
$global:JobShareDrive=$MountPoint                  
if (($null -eq $MountPoint) -OR ($MountPoint.Length -ne 2)) {    
    WriteLog -Message "Not possible mount Jobs share" -MessageType Error -Verbose
    Remove-Variable -Name MountPoint -Force -ErrorAction SilentlyContinue
    $global:JobShareDrive=""
} else {
    if ($MountPoint.Length -ne 2) {
        WriteLog -Message "Invalid format for Drive Mount point: [$($MountPoint)]" -Messagetype Error -Verbose
        Remove-Variable -Name MountPoint -Force -ErrorAction SilentlyContinue
        $global:JobShareDrive=""
    } else {
        WriteLog -Message "Drive assigned for JobPath: [$($MountPoint)]" -Verbose        
    }
}
$AjoloteModulesFile="$($PSScriptRoot)\AjoloteModules.json"
$AjoloteModulesPath="$($PSScriptRoot)\AjoloteModules"
if (Test-Path -Path $AjoloteModulesFile -PathType Leaf) {
    $ObjModules=Get-Content $AjoloteModulesFile | ConvertFrom-Json | Sort-Object -Property id
    $ObjModules | ForEach-Object {if (($_.enabled) -AND ($_.environment.ToLower() -eq "windows")) { WriteLog -Message "Ajolote Module required: $($_.name)" -Verbose} }
    ##Start loop for each module on json file
    foreach ($module in $ObjModules) {
        if (($module.enabled) -AND ($module.environment.ToLower() -eq "windows")) {
            if (Test-Path -Path "$($AjoloteModulesPath)\$($module.filename)" -PathType Leaf) {
                #################################################################################################################
                ######################## STEP THREE: Process load each module in order, single one failed and full process stop##
                #################################################################################################################
                WriteLog -Message "----> Loading Ajolote Module: $($module.name.ToUpper())" -Verbose
                ### Update Job
                Update-JobStage $jobfile $json $json.JOBREQUEST $module.name.ToUpper()
                ### if Job, upload file, error could be detected but is not reason to break process
                if ($null -ne $json.JOBREQUEST.Job.namejob) { Update-ServerJob -Sourcejobfile $jobfile -Destinationjobfile "$($json.JOBREQUEST.Job.namejob).job" }
                #### End Update Job  
                WriteLog -Message "--------------------MODULE START---------------------" -Verbose                   
                try {                    
                    $Error.Clear()
                    . "$($AjoloteModulesPath)\$($module.filename)"
                }
                catch {
                    $ErrorMessage = $_.Exception.Message
                    [string]$ExceptionText = ($_ | Out-String).Trim()
                    WriteLog -Message "Failed loading  Ajolote Module, error: $($ErrorMessage)" -MessageType Error -Verbose
                    WriteLog -Message $Error -MessageType Error -Verbose
                    WriteLog -Message $ExceptionText -MessageType Error -Verbose
                    $global:MessageResults="Failed loading  Ajolote Module, error:  $($ErrorMessage)"
                    $global:CodeResults=221
                    if ($null -ne $json.JOBREQUEST.Job) { 
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.Job "fail" $global:MessageResults
                    } elseif ($null -ne $json.JOBREQUEST.Control) {
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.Control "fail" $global:MessageResults
                    }
                    Out-Windows
                }
            } else {
                WriteLog -Message "Not possible locate Ajolote Module file: $($AjoloteModulesPath)\$($module.filename)" -MessageType Error -Verbose
                #Start-Process powershell -WorkingDirectory "$($AjoloteDrive)\system.sav\logs\CSBuilt\" -Wait
                $global:MessageResults="Not possible locate Ajolote Module file: $($AjoloteModulesPath)\$($module.filename)"
                $global:CodeResults=220
                if ($null -ne $json.JOBREQUEST.Job) { 
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.Job "fail" $global:MessageResults
                } elseif ($null -ne $json.JOBREQUEST.Control) {
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.Control "fail" $global:MessageResults
                }
                Out-Windows
            }
        }
    }

} else {
    WriteLog -Message "It was not detected Modules file: $($AjoloteModulesFile)" -MessageType Warning -Verbose
}



##############################################################################################################################################################################
##############################################################################################################################################################################
##############################################################################################################################################################################
##############################################################################################################################################################################
##############################################################################################################################################################################
##############################################################################################################################################################################
##############################################################################################################################################################################
##############################################################################################################################################################################


#Process flow is controlled by Job request or Control
if ($null -ne $json.JOBREQUEST.Job) { 
    WriteLog -Message "Detected JOB in progress, reach this point process is ready to reboot and save"
    $global:MessageResults="Detected JOB in progress, reach this point process is ready to reboot and save"
    $global:CodeResults=0
    Update-JobStatus $jobfile $json $json.JOBREQUEST.Job "save" $global:MessageResults
    Out-Windows    
} elseif ($null -ne $json.JOBREQUEST.Control) {
    WriteLog -Message "Detected Control in progress, reach this point process is ready to reboot and save"
    $global:MessageResults="Detected Control in progress, reach this point process is ready to reboot and save"
    $global:CodeResults=0
    Update-JobStatus $jobfile $json $json.JOBREQUEST.Control "save" $global:MessageResults
    Out-Windows
} else {
    WriteLog -Message "Seems like job has no control process, no actions to continue, reboot unit" -MessageType Error -Verbose
    $global:MessageResults="Seems like job has no control process, no actions to continue, reboot unit"
    $global:CodeResults=1
    Out-Windows
}


<#

WriteLog -Message "---> Verify Windows setup state" -Verbose
if (Test-Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State) { 
    $regkey = Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State -Name ImageState;
    WriteLog -Message "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State ImageState=[$($regkey.ImageState)]" -Verbose
}



#>