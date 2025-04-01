<#
.SYNOPSIS
    CS Image Builder - AJOLOTE 2.0
.DESCRIPTION
    System solution  to build Images
.NOTES
    version 2.0.0 - Feb.5.2022
        First draft
    version 2.0.1 - Aug.5.2022
        Fix issue Mounting path, all drive letter assigned
        Fix issues detected incorrectly as module when is conflict to upload job, adding retries to JOB update and JOB upload (new function) functions
    version 2.0.2 - Sep.6.2022
        Include Culture Info
    Version 2.0.3 - Oct.11.2022
        Adding an option to kill and reboot process
    Version 2.0.4 - Oct.30.2022
        Copying Config.xml to logs
    Version 2.0.5 - Jun.28.2023
        Creating auto-update process, when detect a newer version it will try to update once idle for more than hour.
    Version 2.0.6 - Dec.21.2023
        Adding cleanup temp directory, moving to HDD to prevent no space on X: error
    Version 2.0.7 - Jan.26.2024
        Support for new feature on AjoloteMonitor.exe where Config.xml has changed
    Version 2.0.8 - May.07.2024
        Remove all screenshots on new job
    Version 2.0.9 - Jun.03.2024
        Getting and set time from server computer
    Version 2.0.10 - Sep.06.2024
        Reorder assignation of global drive.
    version 2.0.11 - Jan.31.2025
        Adding API conectivity to report status.
        Improve timeout for dayle reboot
.EXAMPLE


#>
[cultureinfo]::CurrentCulture = 'en-US'
<##########################################################
    INITIAL AND TEMPORARY TRANSCRIPT CAPTURE
###########################################################>
[string]$temptime=(Get-Date -Format "ddMMyyyyHHmmss")
try {
    Start-Transcript -Path "$($PSScriptRoot)\HP_temptranscript$($temptime).log" -Force
}
catch {
    Stop-Transcript
    Start-Transcript -Path "$($PSScriptRoot)\HP_temptranscript$($temptime).log" -Force
}
<##########################################################
    ADD SYSTEM SCRIPTS - FUNCTIONS
###########################################################>
[string[]]$ScriptFunction = @(
    "CSImageBuilder.Functions.ps1"
)
$ProfileScript="$($Env:windir)\System32\WindowsPowerShell\v1.0\Profile.ps1"
$ProfilePath="$($Env:windir)\System32\WindowsPowerShell\v1.0"
foreach ($script in $ScriptFunction) {
    try {
        if (!(Test-Path -Path "$($PSScriptRoot)\$($script)" -PathType Leaf)){
            Write-Error "Missing Module file: $($script)"
        }
        Import-Module "$($PSScriptRoot)\$($script)"
        Write-Host "Module loaded: $($script)" -BackgroundColor Black -ForegroundColor Green
        #Add to profile, this allows to use by any prompt
        Copy-Item "$($PSScriptRoot)\$($script)" "$($ProfilePath)\$($script)" -Force
        "Import-Module ""$($ProfilePath)\$($script)""" | Out-File -FilePath $ProfileScript -Encoding ascii -Append -Force
    }
    catch {
        Write-Error "Not possible load Script Modules"
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}


<##########################################################
    GLOBAL VARIABLES
###########################################################>
$global:ScriptVer="2.0.11"
$global:MessageResults=""
$global:CodeResults=0
$global:envLogs=""
$global:envDrive=""
$global:WinDrive=""
$global:envPath=""
$global:logs=""
$global:DebugMode=$false
$global:MainID=$PID

<##########################################################
    LOCAL VARIABLES
###########################################################>
#$XmlSetupOut="osoptions.xml"
#$XmlSetupIn="ajolotesetup.xml"
#$XML="$($PSScriptRoot)\$($XmlSetupIn)"
$SecureMountDrive = "MountDrive.exe"
$WSUS_CAB="wsusscn2.cab"
$Exlude4WinPE="ExcludeFromWinPE.ini"
$CleanImage=$false
$AjoloteModulesPath="$($PSScriptRoot)\AjoloteModules"
$host.UI.RawUI.WindowTitle = "AJOLOTE - Ver.$($global:ScriptVer)"
$SolutionRequireUpdate=$false
##Files required, just out null to not marked as never used variables
$SecureMountDrive | Out-Null
$WSUS_CAB | Out-Null
$Exlude4WinPE | Out-Null
<##########################################################
    LOCATE AJOLOTE PARTITION
###########################################################>
$AjoloteDrive=(Get-Volume | Where-Object {$_.FileSystemLabel -eq "AJOLOTE" }).DriveLetter
$AjoloteDrive="$($AjoloteDrive):"
if (($null -eq $AjoloteDrive) -OR ($AjoloteDrive.Length -lt 2)) 
{
    Write-Host "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" -ForegroundColor Red -BackgroundColor Yellow
    Write-Host "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" -ForegroundColor Red -BackgroundColor Yellow
    Write-Host "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" -ForegroundColor Red -BackgroundColor Yellow
    Write-Host "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" -ForegroundColor Red -BackgroundColor Yellow
    Write-Host "                                                                                  " -ForegroundColor Red -BackgroundColor Black
    Write-Host "X This Solution was designed to work from AJOLOTE partition, but was not located X" -ForegroundColor Red -BackgroundColor Black
    Write-Host "                                                                                  " -ForegroundColor Red -BackgroundColor Black
    Write-Host "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" -ForegroundColor Red -BackgroundColor Yellow
    Write-Host "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" -ForegroundColor Red -BackgroundColor Yellow
    Write-Host "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" -ForegroundColor Red -BackgroundColor Yellow
    Write-Host "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" -ForegroundColor Red -BackgroundColor Yellow
    $null = Read-Host "Press ENTER to open terminal and check issue, close it to reboot"
    Start-Process -FilePath "Powershell.exe" -Wait
    exit 9
}
$global:envDrive = $AjoloteDrive
$global:envPath = $PSScriptRoot
#-----| Logs folder detection
if (!(Test-Path -Path (Join-Path $AjoloteDrive "system.sav") -PathType Container)) 
{ 
    New-Item -Path (Join-Path $AjoloteDrive "system.sav") -ItemType Container -Force | Out-Null
    (Get-Item (Join-Path $AjoloteDrive "system.sav") -Force).Attributes += "Hidden";
}
$BuiltLogs=(Join-Path (Join-Path (Join-Path $AjoloteDrive "system.sav") "logs") "CSBuilt")
if (!(Test-Path -Path $BuiltLogs -PathType Container)) { New-Item -Path $BuiltLogs -ItemType Container -Force | Out-Null }
$UniqueFolder="HPLOGS_"
$GetDirsLogs=Get-ChildItem -Path $BuiltLogs -Directory -Filter "$($UniqueFolder)*" | Sort-Object -Property Name -Descending

if ($null -eq $GetDirsLogs) {
	$UniqueFolder="HPLOGS_0"
} else {
    $UniqueFolder=$GetDirsLogs[0].Name
}
<#
$GetDirsLogs=Get-ChildItem -Path $BuiltLogs -Directory
if ($null -eq $GetDirsLogs) {
    $UniqueFolder="HPLOGS_0"
} else {
	$IncrementalDir=($GetDirsLogs | Measure-Object )
	$UniqueFolder="HPLOGS_$($IncrementalDir.Count)"
}#>
if (!(Test-Path (Join-Path $BuiltLogs $UniqueFolder))) { New-Item -Path (Join-Path $BuiltLogs $UniqueFolder) -ItemType Container -Force | Out-Null }
$global:logs=(Join-Path $BuiltLogs $UniqueFolder)
$logs=(Join-Path $BuiltLogs $UniqueFolder)
if (!(Test-Path $logs)) { Write-Error "Not possible create LOGS folder"; $null=Read-Host "Press ENTER to open terminal and check issue, close it to reboot";Start-Process -FilePath "Powershell.exe" -Wait; exit 8; }
Stop-Transcript -ErrorAction SilentlyContinue
Copy-Item -Path "$($PSScriptRoot)\HP_temptranscript$($temptime).log" -Destination "$($logs)\InitialTranscript.log"
try {
    if (Test-Path -Path (Join-Path $logs "WinPetranscription.log") -PathType Leaf) {
        Start-Transcript -Path "$($logs)\WinPetranscription.log" -Append | Out-Null
    } else {
        Start-Transcript -Path "$($logs)\WinPetranscription.log"  | Out-Null
    }
    
}
catch {
    Stop-Transcript;
    if (Test-Path -Path (Join-Path $logs "WinPetranscription.log") -PathType Leaf) {
        Start-Transcript -Path "$($logs)\WinPetranscription.log" -Append | Out-Null
    } else {
        Start-Transcript -Path "$($logs)\WinPetranscription.log"  | Out-Null
    }
}
$helpcmd = Start-Process "Powershell.exe" -WindowStyle Minimized -PassThru

Write-Host "Loading interface..."
Get-Process -Id $PID -ErrorAction SilentlyContinue | Set-WindowStyle -Style MAXIMIZE
Write-Host "Getting TEMP folder=[$($env:TEMP)]"
if (-Not(Test-Path (Join-Path $AjoloteDrive "system.sav\TEMP"))) { 
    New-Item -Path (Join-Path $AjoloteDrive "system.sav\TEMP") -ItemType Directory -Force; 
} else {
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c del /F /Q ""$(Join-Path $AjoloteDrive "system.sav\TEMP")\*""" -Wait -NoNewWindow
    foreach ($folder in (Get-ChildItem -Path (Join-Path $AjoloteDrive "system.sav\TEMP") -Directory)) {
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c rd /s /q ""$($folder.FullName)""" -Wait -NoNewWindow
    }
}
$env:TEMP="$(Join-Path $AjoloteDrive "system.sav\TEMP")"
Write-Host "New TEMP folder=[$($env:TEMP)]"
start-sleep -Seconds 3
Clear-Host

while ($null -eq (Get-Process -Id $helpcmd.Id -ErrorAction SilentlyContinue)) {
    Start-Sleep -Seconds 5
    $helpcmd = Start-Process "Powershell.exe" -WindowStyle Minimized -PassThru
}

$sizeofprompt=$Host.UI.RawUI.MaxWindowSize.Width
[string[]]$TopMessage=@(
    "@",
    "@",
    "  CS IMAGE BUILDER  ",
    "  $($global:ScriptVer)  "
    "@",
    "@",
    "# Welcome!                                                                             #",
    "#        To second edition of AJOLOTE, an image builder for OEM standards              #",
    "#  Initially was designed to support AY153AV services but now more options are added   #",
    "#  More options will be added to scripting, each option will docummented               #",
    "#  run manual process not exactly contains all options, you can get more using jobs    #",
    "#                                                                                      #",
    "#  Please send any report or feedback to cs.dps.support@hp.com                         #",
    "#                                                                                      #",
    "#  help console is open with Id: $($helpcmd.Id.ToString().PadRight(54,' '))#",
    "########################################################################################"
)
$TopMessage | ForEach-Object {
    $sizeofstring=$_.Length
    $calculateleft=(($sizeofprompt/2)-($sizeofstring/2) + $sizeofstring)
    $padleft=[math]::Floor($calculateleft)
    Write-Host $_.PadLeft($padleft,"@").PadRight($sizeofprompt,"@") -ForegroundColor Green -BackgroundColor Black
}
WriteLog -Message "========================= CS IMAGE BUILDER ===============================" -Path $logs -Name "_BuildImage.log" -Verbose
WriteLog -Message "============================== WINPE =====================================" -Verbose

<##########################################################
#       Detect OS and preparation
###########################################################>
$OSDrive=Get_DriveByPath -Path "/Windows/System32/Sysprep"
if (($null -eq $OSDrive) -OR ($OSDrive.length -lt 2)) {
    WriteLog -Message "Not possible detect OS drive, load OS" -MessageType Error -Verbose
    $global:MessageResults="Not possible detect OS drive, load OS"
    $global:CodeResults=201
    Out-WinPE -Backuplogs
}
$global:WinDrive=$OSDrive

if (!(Test-Path -Path (Join-Path $OSDrive "system.sav") -PathType Container)) {
    New-Item -Path (Join-Path $OSDrive "system.sav") -ItemType Container -Force | Out-Null
    (Get-Item (Join-Path $OSDrive "system.sav") -Force).Attributes += "Hidden";
    $CleanImage=$true
}
if (!(Test-Path -Path (Join-Path (Join-Path (Join-Path $($OSDrive) "system.sav") "util") "MSUpdates") -PathType Container)) {
    New-Item -Path (Join-Path (Join-Path (Join-Path $($OSDrive) "system.sav") "util") "MSUpdates") -ItemType Container -Force | Out-Null
}
if (!(Test-Path -Path (Join-Path (Join-Path $OSDrive "system.sav") "logs") -PathType Container)) {
    New-Item -Path (Join-Path (Join-Path $($OSDrive) "system.sav") "logs") -ItemType Container -Force | Out-Null
}
<##########################################################
    DETECT EFI PARTITION
###########################################################>
WriteLog -Message "Detect and prepare EFI partition" -Verbose

#Assign letter to EFI
$EFI=(Get-Disk | Get-Partition | Where-Object {$_.GptType -eq "{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}"})
$EFIDrive="S:"
[string[]] $DPcommands = @(
    "select disk $($EFI.DiskNumber)",
    "select partition $($EFI.PartitionNumber)",
    "assign letter $($EFIDrive) noerr",
    "detail disk"
    )
$DPfile = "$($logs)\DiskPart_EFI$($EFI.DiskNumber).txt"
$DPcommands | ForEach-Object { Add-Content $DPfile -Value $_ }
WriteLog -Message "Assign EFI letter $($EFIDrive) to partition [$($EFI.DiskNumber):$($EFI.PartitionNumber)]" -Verbose
$intDiskpart = Invoke-RunPower -File "Diskpart.exe" -Params "/s $($DPfile)" -WorkDir $PSScriptRoot -OutFile "$($logs)\Diskpart_EFI$($EFI.DiskNumber).log"
if ($intDiskpart -ne 0) {
    WriteLog -Message "Not possible assign letter to EFI partition"-MessageType Error -Verbose
    $global:MessageResults="Not possible assign letter to EFI partition"
    $global:CodeResults=203
    Out-WinPE -Backuplogs
}

<##########################################################
    MOVE CONFIGURATIONS TO RAM DRIVE
###########################################################>

#if Exist cred.xml move to system
if (Test-Path "$($AjoloteDrive)\cred.xml") { Copy-Item -Path "$($AjoloteDrive)\cred.xml" -Destination "$($PSScriptRoot)\cred.xml" -Force; WriteLog -Message "CRED.xml file was located on ajolote drive, moving to use" -Verbose;}
#if Exist config.xml move to system
if (Test-Path "$($AjoloteDrive)\config.xml") { Copy-Item -Path "$($AjoloteDrive)\config.xml" -Destination "$($PSScriptRoot)\config.xml" -Force; Copy-Item -Path "$($AjoloteDrive)\config.xml" -Destination "$($logs)\config.xml" -Force; WriteLog -Message "CONFIG.xml file was located on ajolote drive, moving to use" -Verbose;}
#if Exist Version.ini move to system
if (Test-Path "$($AjoloteDrive)\Version.ini") { Copy-Item -Path "$($AjoloteDrive)\Version.ini" -Destination "$($PSScriptRoot)\Version.ini" -Force; WriteLog -Message "Version.ini file was located on ajolote drive, moving to System" -Verbose;}
#if Exist job.json move and overwrite to logs
if (Test-Path "$($AjoloteDrive)\job.json") { Copy-Item -Path "$($AjoloteDrive)\job.json" -Destination "$($logs)\get.job.json" -Force; WriteLog -Message "JOB.json file was located on ajolote drive, moving to Logs" -Verbose;}
if (Test-Path "$($AjoloteDrive)\AjoloteModules.json") { Copy-Item -Path "$($AjoloteDrive)\AjoloteModules.json" -Destination "$($PSScriptRoot)\AjoloteModules.json" -Force; WriteLog -Message "AjoloteModules.json file was located on ajolote drive, moving to use" -Verbose;}
if ($null -ne (Get-ChildItem -Path "$($AjoloteDrive)\AjoloteModules" -File -ErrorAction SilentlyContinue)) {
    WriteLog -Message "Modules detect on Ajolote drive, move for use" -Verbose
    if (!(Test-Path -Path $AjoloteModulesPath)) { New-Item -Path $AjoloteModulesPath -ItemType Directory -Force }
    foreach ($file in (Get-ChildItem -Path "$($AjoloteDrive)\AjoloteModules" -File)) {
        WriteLog -Message "Copy $($file.Name) into $($AjoloteModulesPath)"
        Copy-Item -Path $file.FullName -Destination "$($AjoloteModulesPath)\$($file.Name)" -Force
    }
}


<##########################################################
    LOAD DRIVERS FOR WINPE
###########################################################>
if (Test-Path -Path (Join-Path (Join-Path (Join-Path $AjoloteDrive "TOOLS") "WindowsDrivers") (Get-WmiObject Win32_BaseBoard).Product.ToString()) -PathType Container) {
    $DriverPath=(Join-Path (Join-Path (Join-Path $AjoloteDrive "TOOLS") "WindowsDrivers") (Get-WmiObject Win32_BaseBoard).Product.ToString())
    WriteLog -Message "Adding discovered drivers: $($DriverPath)" -Verbose
    Get-ChildItem -Path $DriverPath -Recurse -Filter "*.inf" -File | ForEach-Object { 
        Start-Process -FilePath "Drvload.exe" -ArgumentList "$($_.FullName)" -WorkingDirectory $DriverPath -NoNewWindow -Wait -ErrorAction SilentlyContinue
    }
}


<##########################################################
    EXTRACT OS INFORMATION
###########################################################>

if (Test-Path -Path "$($OSDrive)\Windows\System32\config\SOFTWARE" -PathType Leaf) {
    reg load HKLM\HPload "$($OSDrive)\Windows\System32\config\SOFTWARE" | Out-Null
    $OS=@{}
        $OS.Name = (Get-ItemProperty 'HKLM:\HPload\Microsoft\Windows NT\CurrentVersion').ProductName
        $OS.Architecture = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
        $OS.Version = (Get-ItemProperty 'HKLM:\HPload\Microsoft\Windows NT\CurrentVersion').ReleaseId
        $OS.DisplayVersion = (Get-ItemProperty 'HKLM:\HPload\Microsoft\Windows NT\CurrentVersion').DisplayVersion
        $OS.Build = (Get-ItemProperty 'HKLM:\HPload\Microsoft\Windows NT\CurrentVersion').CurrentBuildNumber
        $OS.Revision = (Get-ItemProperty 'HKLM:\HPload\Microsoft\Windows NT\CurrentVersion').UBR
        $OS.Branch = (Get-ItemProperty 'HKLM:\HPload\Microsoft\Windows NT\CurrentVersion').BuildBranch
    reg unload HKLM\HPload | Out-Null

} else {
    WriteLog -Message "Not possible detect Registry hive, load OS" -MessageType Error -Verbose
    $global:MessageResults="Not possible detect Registry hive, load OS"
    $global:CodeResults=202
    Out-WinPE -Backuplogs
}
$OS_State= (Get-Content -Path "$($OSDrive)\Windows\Setup\State\State.ini" | Select-String -Pattern "ImageState=")[0].ToString().Trim().Split("=")[1]
$SKU = (Get-WmiObject win32_computersystem).SystemSKUNumber

$BuildID=(Get-CimInstance -ClassName HP_BIOSSetting -Namespace root\HP\InstrumentedBIOS -ErrorAction SilentlyContinue | Where-Object {$_.Name -eq "Build ID"} -ErrorAction SilentlyContinue).Value
if ($null -eq $BuildID) {
    $BuildID = "NOTCONFIG#SABA#DABA"
    $LOC="ABA"
} else {
	try {
		$LOC = $BuildID.ToString().Split("#")[2].Substring(1,3).ToUpper()
	}
	catch {
		$LOC = "ABA"
	}
}
#$FeatureByte=(Get-HPBIOSSetting -Name "Feature Byte" -ErrorAction SilentlyContinue).Value
$FeatureByte=(Get-CimInstance -Namespace root\HP\InstrumentedBIOS -ClassName HP_BIOSSetting | Where-Object {$_.Name -like "*Feature Byte*"}).Value
if ($null -eq $FeatureByte) { $FeatureByte="NOTAVAILABLE"}
#$BuildID=(Get-HPBIOSSetting -Name "Build ID").Value
$WinVersion=$OS.Build


if (Test-Path -Path "$($PSScriptRoot)\config.xml" -PathType Leaf) {
    Try {
        $ConfigXML="$($PSScriptRoot)\config.xml"
        $computername = (Select-Xml -Path $ConfigXML -XPath "/AJOLOTE/computername").Node.'#text'
        $Changehostname= Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\ -Name "Hostname" -Value $computername -PassThru -Force
        if ($Changehostname.Hostname -ne $computername) {
            WriteLog -Message "Not possible set computer name as $($computername) - Host" -MessageType Error -Verbose
        } 
        $Changenvhostname= Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\ -Name "NV Hostname" -Value $computername -PassThru -Force
        if ($Changenvhostname.'NV Hostname' -ne $computername) {
            WriteLog -Message "Not possible set computer name as $($computername) - NV Host" -MessageType Error -Verbose
        }
        $Env:COMPUTERNAME=$computername
    } catch {
        $computername=(Get-WmiObject Win32_OperatingSystem).CSName
    }
} else {
    $computername=(Get-WmiObject Win32_OperatingSystem).CSName
}

<##########################################################
    EXTRACT XML FILE FOR AJOLOTE MONITOR
###########################################################>
$XmlSetupOut="osoptions.xml"
$XmlWriter = New-Object System.XMl.XmlTextWriter("$($PSScriptRoot)\$($XmlSetupOut)",$Null)   
$xmlWriter.Formatting = "Indented"
$xmlWriter.Indentation = "4"
$xmlWriter.WriteStartDocument()
$xmlWriter.WriteStartElement("AJOLOTE")
    $xmlWriter.WriteElementString("CURRENT",$WinVersion)
    #if ($CleanImage) {$xmlWriter.WriteElementString("STATE","$($OS_State)[Clean]")} else {$xmlWriter.WriteElementString("STATE","$($OS_State)[Used]")}
    $xmlWriter.WriteElementString("SYSID",(Get-WmiObject Win32_BaseBoard).Product)
    ### OS NODES
    $WimsFiles=Get-ChildItem -Path "$($AjoloteDrive)\WIMS" -File -Filter "*.wim" | Where-Object {$_.Name.ToLower() -ne "drivers.wim" }
    foreach ($wim in $WimsFiles) {
        $xmlWriter.WriteStartElement("OS")  
        $XmlWriter.WriteAttributeString("id", $wim.Name)
            if (!(Test-Path "$($AjoloteDrive)\WIMS\WIMinfo.$($wim.Name).xml")){
                WriteLog -Message "Creating WIM Info file" -Verbose
                $null = Invoke-RunPower -File "cmd.exe" -Params "/c Imagex.exe /info ""$($wim.FullName)"" /xml > $($AjoloteDrive)\WIMS\WIMinfo.$($wim.Name).xml" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\WIMinfo.$($wim.Name).log"
                Copy-Item -Path "$($AjoloteDrive)\WIMS\WIMinfo.$($wim.Name).xml" -Destination "$($logs)\WIMinfo.$($wim.Name).xml" -Force               
            }
            [xml]$GetWimInfo = Get-Content "$($AjoloteDrive)\WIMS\WIMinfo.$($wim.Name).xml"
            [int]$CountImage=$GetWimInfo.WIM.IMAGECOUNT
            WriteLog -Message "WIM: $($wim.Name) contains $($CountImage) indexes" -Verbose
            foreach ($ind in $GetWimInfo.WIM.IMAGE) { 
                $xmlWriter.WriteStartElement("INDEX");
                $xmlWriter.WriteAttributeString("id", $ind.INDEX);
                $xmlWriter.WriteString($ind.DISPLAYNAME);
                $xmlWriter.WriteEndElement();
            }
        $XmlWriter.WriteEndElement() #end OS nodes
    }
    ### END OS NODES
    ## Drivers
    if (Test-Path "$($AjoloteDrive)\DRIVERS") {
        WriteLog -Message "Detected DRIVERS folder, search IDs" -Verbose
        $DriversFolders=Get-ChildItem -Path "$($AjoloteDrive)\DRIVERS" -Directory | Where-Object {$_.Name.Length -eq 4 }
        if ($null -ne $DriversFolders) {
            foreach ($driver in $DriversFolders) {
                WriteLog -Message "Driver folder found $($driver.Name)" -Verbose
                $xmlWriter.WriteElementString("DRIVER",$driver.Name)
            }
        } ## End Drivers
    }
    
    ###LANGUAGES
    $GetLaguagesDirs = Get-ChildItem -Path "$($AjoloteDrive)\LANGUAGES" -Directory 
    if ($null -ne $GetLaguagesDirs) {
        foreach ($dir in $GetLaguagesDirs) {
            $xmlWriter.WriteStartElement("LANGUAGE")  
            $XmlWriter.WriteAttributeString("id", $dir.Name)
                $LPs="$($dir.FullName)\LanguagePack"                    
                $CABS = Get-ChildItem -Path $LPs -File -Filter "*.cab" | Where-Object {($_.Name -like "*Windows-Client-Language*") -AND ($_.Name -notlike "*en-us*")}
                foreach ($cab in $CABS) {
                    $locs=$cab.Name.ToString().ToLower().Split("_")[2].Replace(".cab","")
                    $xmlWriter.WriteElementString("CODE",$locs)
                }
            $XmlWriter.WriteEndElement() #end Labguages node
        }
    }
$xmlWriter.WriteEndElement()
$xmlWriter.WriteEndDocument()  
$xmlWriter.Flush()  
$xmlWriter.Close()




<##########################################################
    TRY TO CHECK SYSTEM UPDATES
###########################################################>
if ((Test-Path -Path (Join-Path $PSScriptRoot "cred.xml") -PathType Leaf) -AND (Test-Path -Path (Join-Path $PSScriptRoot "config.xml") -PathType Leaf) -AND (Test-Path -Path (Join-Path $PSScriptRoot "Version.ini") -PathType Leaf)) {
    #Test Network 
    WriteLog -Message "Test Network..."
    $timeoutretries=10
    $continue=$false
    $foundNet=$false
    While (!($continue)) {
        $network=get-wmiobject win32_networkadapter -filter "netconnectionstatus = 2" 
        if ($null -ne $network) {
            $network |Select-Object netconnectionid, name, InterfaceIndex, netconnectionstatus | Out-File -FilePath (Join-Path $logs "NetAdapterStatus.log") -Encoding ascii -Append -Force
            $foundNet=$true;
            $continue=$true;
            WriteLog -Message "Network detected, continue" -Verbose
        } else {
            $timeoutretries--;
            if ($timeoutretries -lt 1) {
                WriteLog -Message "Network sems to be disabled" -MessageType Error -Verbose
                $continue=$true;
            } else {
                Start-Sleep -Seconds 5
            }
        }
        
        
    }
    
    if (Test-Path -Path (Join-Path $PSScriptRoot "Version.ini") -Pathtype Leaf) {
        $LocVersion = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot "Version.ini"))
        $LocVersion = $LocVersion.Trim()
    } else {
        $LocVersion = "0.0.0.0"
    }
    #only if network is detected
    if ($foundNet) {
        [xml]$con = Get-Content (Join-Path $PSScriptRoot "config.xml")
        WriteLog -Message "Trying to mount version path: \\$($con.AJOLOTE.servername)$($con.AJOLOTE.versionpath)" -Verbose
        if ($null -ne (Get-Variable -Name MounVer -ErrorAction SilentlyContinue)) { Remove-Variable -Name MounVer -Force -ErrorAction SilentlyContinue }
        [string]$MounVer=(Invoke-MountServer -MounParameter "/versionpath")
        WriteLog -Message "Drive for VersionPath: [$($MounVer)]" -Verbose
        if (($null -ne $MounVer) -AND ($MounVer.Length -eq 2)) {
            WriteLog -Message "Checking Version file: $($MounVer)\Version.ini" -Verbose
            if (Test-Path -Path "$($MounVer)\Version.ini" -PathType Leaf) {
                $SerVersion = [System.IO.File]::ReadAllText("$($MounVer)\Version.ini")
                $SerVersion = $SerVersion.Trim()
                #[System.IO.File]::WriteAllText("$($MounVer)\Version.ini", $SerVersion)

                $LocVersion = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot "Version.ini"))
                $LocVersion = $LocVersion.Trim()
                #[System.IO.File]::WriteAllText((Join-Path $PSScriptRoot "Version.ini"), $LocVersion)

                WriteLog -Message "Detected Server version: $($SerVersion)" -Verbose
                WriteLog -Message "Detected Local version: $($LocVersion)" -Verbose
                if ([System.Version]::Parse($SerVersion) -gt [System.Version]::Parse($LocVersion)) {
                    WriteLog -Message "It require update solution" -MessageType Error -Verbose
                    $SolutionRequireUpdate=$true
                    $sizeofprompt=$Host.UI.RawUI.MaxWindowSize.Width
                    [string[]]$RedMessage=@(
                        "X",
                        "X",
                        "           THERE ARE CHANGES ON SERVER           ",
                        "  PLEASE UPDATE THIS SOLUTION BEFORE TO CONTINUE "
                        "       REQUIRE UPDATE TO VERSION: $($SerVersion)       ",
                        "X",
                        "X"
                    )
                    $RedMessage | ForEach-Object {
                        $sizeofstring=$_.Length
                        $calculateleft=(($sizeofprompt/2)-($sizeofstring/2) + $sizeofstring)
                        $padleft=[math]::Floor($calculateleft)
                        Write-Host $_.PadLeft($padleft,"X").PadRight($sizeofprompt,"X") -ForegroundColor Red -BackgroundColor Black
                    }
                    $counter=20
                    Write-Host "Consider update this Solution, " -ForegroundColor White -BackgroundColor Black -NoNewline                
                    While ($counter -gt 0) {
                        Write-Host "continue in $($counter) sec..." -ForegroundColor White -BackgroundColor Black
                        $counter--;
                        Start-Sleep -Seconds 1                    
                    }
                } else {
                    WriteLog -Message "Current Solution version it's ok" -Verbose
                }
            
            } else {
                WriteLog -Message "Not possible locate Version,ini on server, please check that exist" -MessageType Error -Verbose
            }
            <##########################################################
                TRY TO CHECK SERVER TIME
            ###########################################################>
            if (Test-Path -Path (Join-Path $PSScriptRoot "config.xml")) {
                [xml]$config = Get-Content (Join-Path $PSScriptRoot "config.xml")
                WriteLog -Message "Server name detected: \\$($config.AJOLOTE.servername) checking if its reacheable..." -Verbose
                [bool]$ReacehableServer=$false
                $stopwatch =  [system.diagnostics.stopwatch]::StartNew()
                while ($stopwatch.Elapsed.TotalMinutes -lt 5 -AND -Not($ReacehableServer)) {
                    $ReacehableServer=Test-Connection -ComputerName $config.AJOLOTE.servername -Count 5 -Quiet
                    if (-Not($ReacehableServer)) {
                        Start-Sleep -Seconds 5
                        Wpeutil InitializeNetwork | Out-Null
                    }        
                }
                $stopwatch.Stop()
                if ($ReacehableServer) {
                    WriteLog -Message "*cmd.exe /c net TIME \\$($config.AJOLOTE.servername) > $($logs)\ServerTime.txt 2>&1" -Verbose
                    Start-Process -FilePath "cmd.exe" -ArgumentList "/c net TIME \\$($config.AJOLOTE.servername) > ""$($logs)\ServerTime.txt"" 2>&1" -NoNewWindow -Wait
                    #$null = Invoke-RunPower -File "cmd.exe" -Params "/c net TIME \\$($config.AJOLOTE.servername) > $($logs)\ServerTime.txt" -WorkDir $PSScriptRoot -OutFile "$($logs)\ServerTime.log"
                    if (Test-Path (Join-Path $logs "ServerTime.txt")) {
                        [string[]]$GetTime=Get-Content -path "$($logs)\ServerTime.txt"
                        if ($GetTime.Count -gt 0) {
                            foreach ($line in $GetTime) {
                                if (-not([string]::IsNullOrEmpty($line))) {
                                    WriteLog -Message $line -Verbose
                                }                                
                            }
                            $strLine=$null
                            if ($null -ne ($GetTime | select-string -Pattern "Local time" -ErrorAction SilentlyContinue).Line) {
                                $strLine=($GetTime | select-string -Pattern "Local time" -ErrorAction SilentlyContinue)[0].Line
                            } else {
                                if ($null -ne ($GetTime | select-string -Pattern "Current time" -ErrorAction SilentlyContinue).Line) { 
                                    $strLine=($GetTime | select-string -Pattern "Current time" -ErrorAction SilentlyContinue)[0].Line
                                }
                            }
                            if (-not( [string]::IsNullOrEmpty($strLine) )) {                                
                                [string]$strDate=$strLine.Substring($strLine.IndexOf(" is ")+4,$strLine.Length-$strLine.IndexOf(" is ")-4)
                                $ServerDate=[datetime]$strDate;
                                WriteLog -Message "Time extracted from server: $($ServerDate.ToString("MM/dd/yyyy hh:mm:ss tt")), current time in this unit is: $((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt"))" -Verbose
                                Set-Date -Date $ServerDate
                            }
                        }
                    } else {
                        WriteLog -Message "Not possible get current time from server" -MessageType Warning -Verbose
                    }
                } else {
                    WriteLog -Message "Not possible to reach server: $($config.AJOLOTE.servername)" -MessageType Warning -Verbose
                }
                
                
            }
            #############
            #unmount share
            ############
            $null = Invoke-RunPower -File "cmd.exe" -Params "/c net use $($MounVer) /delete" -WorkDir $PSScriptRoot -OutFile "$($logs)\unmountVersionPath.log"
            Remove-Variable -Name MounVer -Force -ErrorAction SilentlyContinue
        } else {
            WriteLog -Message "Not possible mount Version share" -MessageType Error -Verbose
        }
    } else {
        WriteLog -Message "No network detected, continue without very version" -MessageType Warning -Verbose
    }
    
}

<##########################################
#       REPORT ACTIVITY TO API SERVER
###########################################>
Set-APIUnitStatus -computername $computername -LocVersion $LocVersion

<##########################################
#       Get Network information
##########################################>
$Networkinfo = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object {$null -ne $_.MACAddress}

<###########################################################################################################>
WriteLog -Message "------------------------------------------------------------------------------" -Verbose
WriteLog -Message " Checking PowerShell Version: $($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor).$($PSVersionTable.PSVersion.Build).$($PSVersionTable.PSVersion.Revision)" -Verbose
WriteLog -Message "             Script version : $($global:ScriptVer)" -Verbose
WriteLog -Message "      Executing script from : $((Get-Item -Path '.\' -Verbose).FullName)" -Verbose
WriteLog -Message "           Solution version : $($LocVersion)" -Verbose
WriteLog -Message "           Current User Name: $($env:USERNAME)" -Verbose
WriteLog -Message "                  Current OS: $((Get-WmiObject Win32_OperatingSystem).Name)" -Verbose
WriteLog -Message "            Current OS Drive: $($env:SystemDrive)" -Verbose
WriteLog -Message "            Windows OS Drive: $($OSDrive)" -Verbose
WriteLog -Message "               AJOLOTE Drive: $($AjoloteDrive)" -Verbose
WriteLog -Message "                   EFI Drive: $($EFIDrive)" -Verbose
WriteLog -Message "     Current OS Architecture: $($env:PROCESSOR_ARCHITECTURE)" -Verbose
#WriteLog -Message "     Current OS Architecture: $((Get-WmiObject Win32_OperatingSystem).OSArchitecture)" -Verbose
WriteLog -Message "             Current PC Name: $($computername)" -Verbose
WriteLog -Message "              Computer Model: $((Get-WmiObject Win32_Computersystem).Model) [$((Get-WmiObject Win32_BaseBoard).Product)]" -Verbose 
WriteLog -Message "               Serial Number: $((Get-WmiObject Win32_Bios).SerialNumber)" -Verbose					
WriteLog -Message "                  SKU Number: $($SKU)" -Verbose
WriteLog -Message "                Feature Byte: $($FeatureByte)" -Verbose
WriteLog -Message "                    Build ID: $($BuildID)" -Verbose
WriteLog -Message "           Unit Localization: $($LOC)" -Verbose
foreach ($net in $Networkinfo) {
    WriteLog -Message "        Network Adapter Name: $($net.Description) [$($net.Index)]" -Verbose
    if ($null -ne $net.IPAddress) {
        WriteLog -Message "        Network Adapter IPv4: $($net.IPAddress[0])" -Verbose 
        if ($null -ne $net.IPAddress[1]) {
            WriteLog -Message "        Network Adapter IPv6: $($net.IPAddress[1])" -Verbose
        }
    }     
    WriteLog -Message "         Network Adapter MAC: $($net.MACAddress)" -Verbose
}
WriteLog -Message "                Windows Name: $($OS.Name)" -Verbose
WriteLog -Message "       Windows Build Version: $($OS.Build)" -Verbose
WriteLog -Message "      Windows Build Revision: $($OS.Revision)" -Verbose
WriteLog -Message "              Windows Branch: $($OS.Branch)" -Verbose
WriteLog -Message "      Windows DisplayVersion: $($OS.DisplayVersion)" -Verbose
WriteLog -Message "              WindowsVersion: $($OS.Version)" -Verbose
WriteLog -Message "        Windows Code Version: $($WinVersion)" -Verbose
WriteLog -Message "         Windows Setup State: $($OS_State)" -Verbose
WriteLog -Message "        Clean Image Detected: $($CleanImage)" -Verbose
WriteLog -Message "                   Logs path: $($logs)" -Verbose
WriteLog -Message "         Current System Time: $(Get-Date -Format 'MM/dd/yyyy HH:mm:ss')" -Verbose
WriteLog -Message "------------------------------------------------------------------------------" -Verbose

<#########################################################
    LIST ALL FILES ON MODULES FOLDER
##########################################################>
foreach ($mod in (Get-ChildItem -Path $AjoloteModulesPath -File -ErrorAction SilentlyContinue)) {
    WriteLog -Message "`tDefault Module detected: $($mod.Name)" -Verbose
}
WriteLog -Message "------------------------------------------------------------------------------" -Verbose

#Initialize Step.stp  - CONFIRM THAT CAN BE REMOVED
#if (!(Test-Path -Path "$($AjoloteDrive)\step.stp" -PathType Leaf)){ HPControl -Path "$($AjoloteDrive)\" -Name "step.stp" -Set "PreConfigure"; WriteLog -Message "Initialize step.stp" -Verbose; }

<##########################################################
    READ JOB FILE
###########################################################>
#If job file is located it need to be processed otherwise allow user or step.stp configure and continue
#adding a counter to reboot unit every idle of 8 hours
$IdleCounter=0
$MaxIdleHours=6
$Time = [System.Diagnostics.Stopwatch]::StartNew()
$jobfile="$($AjoloteDrive)\job.json"
if (Test-Path -Path $jobfile -PathType Leaf) {
    WriteLog -Message "Detected JOB file, continue process" -Verbose
} else {
    WriteLog -Message "There are no JOB file, open UI Form" -Verbose
    $IdleCounter++;
    ################# UI FORM TO CREATE BASIC OPTION AND DROP JOB.XML
    while (!(Test-Path -Path $jobfile -PathType Leaf)) {
        WriteLog -Message "Checking current system time: $(Get-Date -Format 'MM/dd/yyyy HH:mm:ss')" -Verbose
        $null = Invoke-RunPower -File "$($PSScriptRoot)\AjoloteMonitor.exe" -WorkDir $PSScriptRoot -OutFile "$($logs)\RunAjoloteMonitor.log"
        #compare config.xml in WinPE vs AjoloteDrive and update
        if ((Get-FileHash -Path (Join-Path $PSScriptRoot "Config.xml") -Algorithm SHA1).Hash -ne  (Get-FileHash -Path (Join-Path $AjoloteDrive "Config.xml") -Algorithm SHA1).Hash) {
            WriteLog -Message "Config.xml has been updated, syncronize with Ajolote Drive..." -Verbose
            Copy-Item -Path (Join-Path $PSScriptRoot "Config.xml") -Destination (Join-Path $AjoloteDrive "Config.xml") -Force
        }
        #Move Job to Ajolote Drive
        if (Test-Path -Path (Join-Path $PSScriptRoot "job.json") -PathType Leaf) {
            WriteLog -Message "JOB file created, moving to Ajolote drive" -Verbose
            Copy-Item -Path (Join-Path $PSScriptRoot "job.json") -Destination $jobfile -Force
            #Clean logs
            $null = Invoke-RunPower -File "cmd.exe" -Params "/c del $($logs)\screenshot*.png" -WorkDir $PSScriptRoot -OutFile "$($logs)\PreCleanLogs.log" -Verbose 
        }
        #Move Job to logs as initial reference and start process
        if (Test-Path -Path $jobfile -PathType Leaf) { 
            Copy-Item -Path $jobfile -Destination "$($logs)\new.job.json" -Force;
            WriteLog -Message "JOB file detected, continue" -Verbose 
        } else {
            if ($SolutionRequireUpdate) {
                WriteLog "It is required to update solution, trying..." -Verbose
                [xml]$con = Get-Content (Join-Path $PSScriptRoot "config.xml")
                WriteLog -Message "Trying to mount version path: \\$($con.AJOLOTE.servername)$($con.AJOLOTE.versionpath)" -Verbose
                if ($null -ne (Get-Variable -Name MounVer -ErrorAction SilentlyContinue)) { Remove-Variable -Name MounVer -Force -ErrorAction SilentlyContinue }
                [string]$MounVer=(Invoke-MountServer -MounParameter "/versionpath")
                WriteLog -Message "Drive for VersionPath: [$($MounVer)]" -Verbose
                if (($null -ne $MounVer) -AND ($MounVer.Length -eq 2)) {
                    WriteLog -Message "Updating Solution, please wait" -Verbose
                    $UpdateSolution = Invoke-RunPower -File "Robocopy.exe" -Params "$($MounVer) $($AjoloteDrive) /MIR" -WorkDir $PSScriptRoot -OutFile "$($logs)\UpdatingAjolote.log" -Verbose
                    if (($UpdateSolution -eq 0) -OR ($UpdateSolution -eq 1) -OR ($UpdateSolution -eq 2) -OR ($UpdateSolution -eq 3) -OR ($UpdateSolution -eq 4) -OR ($UpdateSolution -eq 5)) {
                        WriteLog -Message "Restoring Config and Cred files" -Verbose
                        Copy-Item -Path (Join-Path $PSScriptRoot "config.xml") -Destination (Join-Path $AjoloteDrive "config.xml") -Force | Out-Host
                        Copy-Item -Path (Join-Path $PSScriptRoot "cred.xml") -Destination (Join-Path $AjoloteDrive "cred.xml") -Force | Out-Host
                        WriteLog -Message "Unit require reboot" -MessageType Warning
                        $global:MessageResults="Reboot required to apply updates to solution"
                        $global:CodeResults=3010
                        Out-WinPE -Backuplogs
                    } else {
                        WriteLog -Message "Somenthing failed during update, robocopy return unexpected code: $($UpdateSolution)" -MessageType Error -Verbose
                    }
                } else {
                    WriteLog -Message "Mounted drive seems to be incorrect, try again later" -MessageType Error -Verbose
                }
            }
            if ((Get-ChildItem -Path (Join-Path (Join-Path $AjoloteDrive "system.sav") "logs") -Filter "*.zip" | Measure-Object).Count -gt 10) {
                WriteLog -Message "Cleaning some old logs from Ajolote drive" -Verbose
                $currentlogsfiles=Get-ChildItem -Path (Join-Path (Join-Path $AjoloteDrive "system.sav") "logs") -Filter "*.zip" | Sort-Object -Descending -Property LastWriteTime
                for ($i = 10; $i -lt $currentlogsfiles.Length; $i++) {
                    WriteLog -Message "`tRemoving $($currentlogsfiles[$i].FullName)" -Verbose
                    Remove-Item -Path $currentlogsfiles[$i].FullName -Force
                }
            }
            Set-APIUnitStatus -computername $computername -LocVersion $LocVersion
            if ([math]::Round($Time.Elapsed.TotalHours) -ge $MaxIdleHours) {
                WriteLog -Message "Unit has been reach  $($MaxIdleHours) hours in idle, refresh unit by reboot" -Verbose
                $global:MessageResults="Unit has been reach  $($MaxIdleHours) hours in idle, refresh unit by reboot"
                $global:CodeResults=3010
                Out-WinPE -Backuplogs
            }
            WriteLog -Message "There are no JOB file, open UI Form again" -Verbose
        }
    }
    <#
    Write-Host " PRESS ANY KEY TO OPEN PROMPT, UNIT WILL REBOOT ONCE YOU CLOSE THAT PROMPT "
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Start-Process powershell  -Wait
    #>
}
#---- Somenthing fail and JOB.json was not created
if (!(Test-Path -Path $jobfile -PathType Leaf)) {
    WriteLog -Message "JOB.JSON doesn't exist process cannot continue, please review logs since somenthing unexpected fail" -MessageType Error -Verbose;
    $global:MessageResults="JOB.JSON doesn't exist process cannot continue, please review logs since somenthing unexpected fail"
    $global:CodeResults=204
    Out-WinPE -Backuplogs
}

<##########################################
         TEST AND WORK WITH JOB.json
##########################################>

WriteLog -Message "Loading current JOB" -Verbose
try {
    $json = Get-Content $jobfile -Raw | ConvertFrom-Json
    if ($null -eq $json.JOBREQUEST) {
        throw [System.Exception] "JOB file has unexpected format, root node incorrect"
    }
    WriteLog -Message "Tested successfully JOB.json file" -Verbose
}
catch {
    $ErrorMessage = $_.Exception.Message
    WriteLog -Message "Not possible load JOB.json: $($ErrorMessage)" -Verbose
    if (Test-Path -Path $JobFIle -PathType Leaf) { Copy-Item -Path $JobFile -Destination "$($logs)\Job.err" -Force -ErrorAction SilentlyContinue }
    $global:MessageResults=$ErrorMessage
    $global:CodeResults=205
    Out-WinPE -Backuplogs -RemoveJob
}
#only if monitor didn't change
if ($null -ne $json.JOBREQUEST.Job) { 
    #Add Computer Name to Job file
    if ($null -eq $json.JOBREQUEST.Job.computername) {
        $json.JOBREQUEST.Job | Add-Member -Name "computername" -MemberType NoteProperty -Value $computername
    } else {
        $json.JOBREQUEST.Job.computername=$computername
    }
    ### Save JOB file
    try {
        $json | ConvertTo-Json -Depth 16 | Out-File -FilePath $jobfile -Encoding ascii -Force
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        WriteLog -Message "Failed updating JOB file: $($ErrorMessage)" -MessageType Error -Verbose
        $global:MessageResults="Failed updating JOB file: $($ErrorMessage)"
        $global:CodeResults=209
        Out-WinPE -Backuplogs
    }
} else { #### Not detected Job, add Control
    if ($null -eq $json.JOBREQUEST.Control) {
        #Control doesn exist
        WriteLog -Message "New Control process detected, preapre Job file" -Verbose
        $blockControl = @"
            {                        
                "status":"new",
                "computername":"$($computername)",
                "startdate":"$(Get-Date -Format "MM-dd-yy HH:mm:ss")",
                "error":"initial status"
            }
"@
        $json.JOBREQUEST | Add-Member -Name "Control" -MemberType NoteProperty -Value (ConvertFrom-Json -InputObject $blockControl)
        ### Save JOB file
        try {
            $json | ConvertTo-Json -Depth 16 | Out-File -FilePath $jobfile -Encoding ascii -Force
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            WriteLog -Message "Failed updating JOB file: $($ErrorMessage)" -MessageType Error -Verbose
            $global:MessageResults="Failed updating JOB file: $($ErrorMessage)"
            $global:CodeResults=209
            Out-WinPE -Backuplogs
        }
    }
}
WriteLog -Message "JOB detected:`r`n"
$json | ConvertTo-Json -Depth 16 | Out-File -FilePath (Join-Path $logs "_BuildImage.log") -Encoding ascii -Append -Force
$json | ConvertTo-Json -Depth 16 | Out-Host

<###########################################
        SHOW STATUS VALUES [allows to prevent execute any else when status is fail]
###########################################>
if ($null -ne $json.JOBREQUEST.Job.status) { 
    WriteLog -Message "Current JOB status: $($json.JOBREQUEST.Job.status)" -Verbose
    if ($json.JOBREQUEST.Job.status.ToLower().Trim() -eq "fail") {
        if ($null -ne $json.JOBREQUEST.Job.error) {
            WriteLog -Message "Job process has fail report: $($json.JOBREQUEST.Job.error)" -MessageType Error -Verbose
            $global:MessageResults=$json.JOBREQUEST.Job.error
        } else {
            WriteLog -Message "Job process return fail status" -MessageType Error -Verbose
            $global:MessageResults="Job process return fail status"
        }
        $global:CodeResults=1
        Out-WinPE -Backuplogs -RemoveJob
    }
} elseif ($null -ne $json.JOBREQUEST.Control.status) {
    WriteLog -Message "Current Control status: $($json.JOBREQUEST.Control.status)" -Verbose
    if ($json.JOBREQUEST.Control.status.ToLower().Trim() -eq "fail") {
        if ($null -ne $json.JOBREQUEST.Control.error) {
            WriteLog -Message "Control process has fail report: $($json.JOBREQUEST.Control.error)" -MessageType Error -Verbose
            $global:MessageResults=$json.JOBREQUEST.Control.error
        } else {
            WriteLog -Message "Control process return fail status" -MessageType Error -Verbose
            $global:MessageResults="Control process return fail status"
        }
        $global:CodeResults=1
        Out-WinPE -Backuplogs -RemoveJob
    }
}

<###########################################
            REBOOT FUNCTION
############################################>
if (($null -ne $json.JOBREQUEST.KillAndReboot) -AND ($json.JOBREQUEST.KillAndReboot)) {    
    WriteLog -Message "REQUESTED TO KILL CURRENT PROCESS AND RESTART UNIT" -Verbose
    $global:MessageResults="Kill current process and reboot unit"
    $global:CodeResults=0
    Out-WinPE -Backuplogs -RemoveJob
}

<###########################################
        OPERATING SYSTEM SELECTION
###########################################>
#Check if OSFile exist
if ($null -ne $json.JOBREQUEST.OperatingSystem) {
    WriteLog -Message "Operating System Node"
    #Check status of node
    if (($null -eq $json.JOBREQUEST.OperatingSystem.status) -OR ($json.JOBREQUEST.OperatingSystem.status.ToLower() -eq "new")){
        WriteLog -Message "Apply new Operating System detected" -Verbose
        #check if file and index was alaredy declared
        if (($null -eq $json.JOBREQUEST.OperatingSystem.osfile) -OR ($null -eq $json.JOBREQUEST.OperatingSystem.osfileindex)) {
            WriteLog -Message "File or index was not detected, run detection" -Verbose
            if (([string]::IsNullOrEmpty($json.JOBREQUEST.OperatingSystem.osbuild)) -OR ([string]::IsNullOrEmpty($json.JOBREQUEST.OperatingSystem.osbuild))) {
                WriteLog -Message "It's not possible detect build or version requested, abort process" -MessageType Error -Verbose
                if (Test-Path -Path $JobFIle -PathType Leaf) { Copy-Item -Path $JobFile -Destination "$($logs)\Job.err" -Force -ErrorAction SilentlyContinue }
                $global:MessageResults="It's not possible detect build or version requested, abort process"
                $global:CodeResults=208
                Out-WinPE -Backuplogs -RemoveJob
            }
            $OSVersion=$json.JOBREQUEST.OperatingSystem.osbuild
            $OSindex=$json.JOBREQUEST.OperatingSystem.osindex
            $File2Apply=""
            $Index2Apply=""
            WriteLog -Message "Require Operating System Version: $($OSVersion)" -Verbose
            WriteLog -Message "  Require Operating System Index: $($OSindex)" -Verbose
            $WimsFiles=Get-ChildItem -Path "$($AjoloteDrive)\WIMS" -File -Filter "*$($OSVersion.Trim())*.wim" | Where-Object {$_.Name.ToLower() -ne "drivers.wim" }
            if ($null -ne $WimsFiles) {
                foreach ($wim in $WimsFiles) {
                    WriteLog -Message "                   Checking file: $($wim.Name)" -Verbose
                    if (!(Test-Path -Path "$($AjoloteDrive)\WIMS\$($wim.Name)")) {
                        $null = Invoke-RunPower -File "Imagex.exe" -Params "/info ""$($AjoloteDrive)\WIMS\$($wim.Name)"" /xml" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\WIMinfo.$($wim.Name).xml"
                    }             
                    [xml]$GetWimInfo=Get-Content "$($AjoloteDrive)\WIMS\WIMinfo.$($wim.Name).xml"
                    [int]$CountImage=$GetWimInfo.WIM.IMAGECOUNT
                    WriteLog -Message "Search Operating System Name: $($OSindex)" -Verbose
                    WriteLog -Message "WIM $($wim.Name) contains $($CountImage) indexes" -Verbose
                    foreach ($ind in $GetWimInfo.WIM.IMAGE) 
                    { 
                        WriteLog -Message "`tIndex: $($ind.INDEX) - Name: $($ind.DISPLAYNAME)" -Verbose
                        if ($ind.DISPLAYNAME.ToString().Trim().ToUpper() -eq $OSindex.ToString().Trim().ToUpper()) {
                            $Index2Apply=$ind.INDEX
                            $File2Apply=$wim.Name
                            WriteLog -Message "Found Image: [$($File2Apply)] - Index: [$($Index2Apply)]" -Verbose
                            if ($null -eq $json.JOBREQUEST.OperatingSystem.osfile) {
                                $json.JOBREQUEST.OperatingSystem | Add-Member -Name "osfile" -MemberType NoteProperty -Value $File2Apply
                            } else {
                                $json.JOBREQUEST.OperatingSystem.osfile=$File2Apply
                            }
                            if ($null -eq $json.JOBREQUEST.OperatingSystem.osfileindex) {
                                $json.JOBREQUEST.OperatingSystem | Add-Member -Name "osfileindex" -MemberType NoteProperty -Value $Index2Apply
                            } else {
                                $json.JOBREQUEST.OperatingSystem.osfileindex=$Index2Apply
                            }
                            if ($null -eq $json.JOBREQUEST.OperatingSystem.status) {
                                $json.JOBREQUEST.OperatingSystem | Add-Member -Name "status" -MemberType NoteProperty -Value "new"
                            } else {
                                $json.JOBREQUEST.OperatingSystem.status="new"
                            }
                            ### Save JOB file
                            try {
                                $json | ConvertTo-Json -Depth 16 | Out-File -FilePath $jobfile -Encoding ascii -Force
                            }
                            catch {
                                $ErrorMessage = $_.Exception.Message
                                WriteLog -Message "Failed updating JOB file: $($ErrorMessage)" -MessageType Error -Verbose
                                $global:MessageResults="Failed updating JOB file: $($ErrorMessage)"
                                $global:CodeResults=209
                                Out-WinPE -Backuplogs
                            }
                        }
                    } #end loop of each index on WIM file
                } #End loop of each wim on search by build
            } #End if when search WIM by build was detected
        } #End detection of file and index
        $File2Apply=$json.JOBREQUEST.OperatingSystem.osfile
        $Index2Apply=$json.JOBREQUEST.OperatingSystem.osfileindex
        #Valiadte file2Apply
        if ([string]::IsNullOrEmpty($File2Apply) -OR ([string]::IsNullOrEmpty($Index2Apply))) { 
            WriteLog -Message "Not possible locate a WIM to meet query" -MessageType Error -Verbose
            if (Test-Path -Path $JobFIle -PathType Leaf) { Copy-Item -Path $JobFile -Destination "$($logs)\Job.err" -Force -ErrorAction SilentlyContinue }
            $global:MessageResults="Not possible locate a WIM to meet query"
            $global:CodeResults=210
            Out-WinPE -Backuplogs -RemoveJob
        }
    }# end detection that process is new on OperatingSystem
    if ($json.JOBREQUEST.OperatingSystem.status.ToLower() -eq "fail") {
        WriteLog -Message "Operating System status shows as failed, abort process" -MessageType Error -Verbose
        Move-Item -Path $JobFile -Destination "$($logs)\Job.err" -Force -ErrorAction SilentlyContinue
        $global:MessageResults="Operating System status shows as failed, abort process"
        $global:CodeResults=206
        Out-WinPE -Backuplogs
    }


##############      APPLY NEW OS      ##################
#if variables exist it require to apply new image
    if (!([string]::IsNullOrEmpty($File2Apply)) -OR !([string]::IsNullOrEmpty($Index2Apply))) {
        WriteLog -Message "Applying new OS" -Verbose
        [string[]] $DPcommands = @(
            "select Vol $($OSDrive)",
            "format quick fs=ntfs label='Windows' OVERRIDE",
            "detail disk"
        )
        $DPfile = "$($logs)\DiskPart_Format.txt"
        $DPcommands | ForEach-Object {
            Add-Content $DPfile -Value $_
        }
        WriteLog -Message "`tFormating OS partition: $($OSDrive)" -Verbose
        $intDiskpart = Invoke-RunPower -File "Diskpart.exe" -Params "/s $($DPfile) " -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\Diskpart_Format.log"
        if ($intDiskpart -ne 0) {
            WriteLog -Message "Not possible format Partition $($OSDrive)"-MessageType Error -Verbose
            if (Test-Path -Path $JobFIle -PathType Leaf) { Copy-Item -Path $JobFile -Destination "$($logs)\Job.err" -Force -ErrorAction SilentlyContinue }
            $global:MessageResults="Not possible format Partition $($OSDrive)"
            $global:CodeResults=$intDiskpart
            Update-JobStatus $jobfile $json $json.JOBREQUEST.OperatingSystem "fail" $global:MessageResults
            Out-WinPE -Backuplogs -RemoveJob
        }
        WriteLog -Message "Applying Image $($File2Apply), index $($Index2Apply)" -Verbose
        $ApplyWIM = RunDism -Params "/Apply-Image /ImageFile:""$($AjoloteDrive)\WIMS\$($File2Apply)"" /ScratchDir:$($OSDrive)\ /ApplyDir:$($OSDrive)\ /Index:$($Index2Apply) /Verify" -ShowProgress $true -WorkDir $PSScriptRoot -OutFile "$($logs)\DismApplyImage.log"
        if ($ApplyWIM -ne 0) {
            WriteLog -Message "It fail trying to apply image $($File2Apply)" -MessageType Error -Verbose
            if (Test-Path -Path $JobFIle -PathType Leaf) { Copy-Item -Path $JobFile -Destination "$($logs)\Job.err" -Force -ErrorAction SilentlyContinue }
            $global:MessageResults="It fail trying to apply image $($File2Apply)"
            $global:CodeResults=$ApplyWIM
            Update-JobStatus $jobfile $json $json.JOBREQUEST.OperatingSystem "fail" $global:MessageResults
            Out-WinPE -Backuplogs -RemoveJob
        }
        Update-JobStatus $jobfile $json $json.JOBREQUEST.OperatingSystem "pass" "Operating System was applied successfully"
        #Create boot file
        Set-BCDEnvironment -Environment "WinPE" -Force -Verbose

        #####   RELOAD OS INFORMATION  #########
        WriteLog -Message "Reload Registry values using new OS" -Verbose
        if (Test-Path -Path "$($OSDrive)\Windows\System32\config\SOFTWARE" -PathType Leaf) {
            reg load HKLM\HPload "$($OSDrive)\Windows\System32\config\SOFTWARE" | Out-Null
            $OS=@{}
                $OS.Name = (Get-ItemProperty 'HKLM:\HPload\Microsoft\Windows NT\CurrentVersion').ProductName
                $OS.Architecture = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
                $OS.Version = (Get-ItemProperty 'HKLM:\HPload\Microsoft\Windows NT\CurrentVersion').ReleaseId
                $OS.DisplayVersion = (Get-ItemProperty 'HKLM:\HPload\Microsoft\Windows NT\CurrentVersion').DisplayVersion
                $OS.Build = (Get-ItemProperty 'HKLM:\HPload\Microsoft\Windows NT\CurrentVersion').CurrentBuildNumber
                $OS.Revision = (Get-ItemProperty 'HKLM:\HPload\Microsoft\Windows NT\CurrentVersion').UBR
                $OS.Branch = (Get-ItemProperty 'HKLM:\HPload\Microsoft\Windows NT\CurrentVersion').BuildBranch
            reg unload HKLM\HPload | Out-Null
        } else {
            WriteLog -Message "Not possible detect Registry hive, Re-load OS" -MessageType Error -Verbose
            if (Test-Path -Path $JobFIle -PathType Leaf) { Copy-Item -Path $JobFile -Destination "$($logs)\Job.err" -Force -ErrorAction SilentlyContinue }
            $global:MessageResults="Not possible detect Registry hive, Re-load OS"
            $global:CodeResults=202
            Update-JobStatus $jobfile $json $json.JOBREQUEST.OperatingSystem "fail" $global:MessageResults
            Out-WinPE -Backuplogs -RemoveJob
        }
        $OS_State= (Get-Content -Path "$($OSDrive)\Windows\Setup\State\State.ini" | Select-String -Pattern "ImageState=")[0].ToString().Trim().Split("=")[1]
        $SKU = (Get-WmiObject win32_computersystem).SystemSKUNumber
        $WinVersion=$OS.Build
        ########    PREPARE OS PARTITION WITH STANDARD FOLDERS      ###################
        WriteLog -Message "Prepare OS partition" -Verbose
        if (!(Test-Path -Path (Join-Path $OSDrive "system.sav") -PathType Container)) {
            New-Item -Path (Join-Path $OSDrive "system.sav") -ItemType Container -Force | Out-Null
            (Get-Item (Join-Path $OSDrive "system.sav") -Force).Attributes += "Hidden";
            $CleanImage=$true
        }
        if (!(Test-Path -Path (Join-Path (Join-Path (Join-Path $($OSDrive) "system.sav") "util") "MSUpdates") -PathType Container)) {
            New-Item -Path (Join-Path (Join-Path (Join-Path $($OSDrive) "system.sav") "util") "MSUpdates") -ItemType Container -Force | Out-Null
        }
        if (!(Test-Path -Path (Join-Path (Join-Path $OSDrive "system.sav") "logs") -PathType Container)) {
            New-Item -Path (Join-Path (Join-Path $($OSDrive) "system.sav") "logs") -ItemType Container -Force | Out-Null
        }
    } else {
        WriteLog -Message "No new file to apply, continue process" -Verbose
    }

}
#Mound Jobpath to keep update job after each module
if ($null -ne (Get-Variable -Name MountPointJobs -ErrorAction SilentlyContinue)) { Remove-Variable -Name MountPointJobs -Force -ErrorAction SilentlyContinue }
[string]$MountPointJobs=Invoke-MountServer "/jobpath"                        
if (($null -eq $MountPointJobs) -OR ($MountPointJobs.Length -ne 2)) {    
    WriteLog -Message "Not possible mount Jobs share" -MessageType Error -Verbose
    Remove-Variable -Name MountPointJobs -Force -ErrorAction SilentlyContinue
} else {
    if ($MountPointJobs.length -ne 2) {
        WriteLog -Message "Invalid format for Drive Mount point: [$($MountPointJobs)]" -Messagetype Error -Verbose
        Remove-Variable -Name MountPointJobs -Force -ErrorAction SilentlyContinue 
    } else {
        WriteLog -Message "Drive assigned for JobPath: [$($MountPointJobs)]" -Verbose
    }
}
##################################################################################################
######################## STEP ONE: Add module to AjoloteModules.json##
# AjoloteModules.json located on Ajolote drive will overwrite included on WinPE media
##################################################################################################
$AjoloteModulesFile="$($PSScriptRoot)\AjoloteModules.json"
if (Test-Path -Path $AjoloteModulesFile -PathType Leaf) {
    $ObjModules=Get-Content $AjoloteModulesFile | ConvertFrom-Json | Sort-Object -Property id
    $ObjModules | ForEach-Object {if (($_.enabled) -AND ($_.environment.ToLower() -eq "winpe")) { WriteLog -Message "Ajolote Module required: $($_.name)" -Verbose} }
    ##Start loop for each module on json file
    foreach ($module in $ObjModules) {
        if (($module.enabled) -AND ($module.environment.ToLower() -eq "winpe")) {
            if (Test-Path -Path "$($AjoloteModulesPath)\$($module.filename)" -PathType Leaf) {
                WriteLog -Message "<C> Cleanup temp folder" -Verbose
                Remove-Item -Path "X:\Windows\TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item -Path "$($env:TEMP)\*" -Recurse -Force -ErrorAction SilentlyContinue
                #################################################################################################################
                ######################## STEP TWO: Process load each module in order, single one failed and full process stop##
                # Adding modules on ajolote drive in a folder named "AjoloteModules" will overwrite any on WinPE media
                #################################################################################################################
                WriteLog -Message "----> Loading Ajolote Module: $($module.name.ToUpper())" -Verbose 
                ### Update Job
                Update-JobStage $jobfile $json $json.JOBREQUEST $module.name.ToUpper()
                ##### if is Job, upload file, error could be detected but is not reason to break process
                if ($null -ne $json.JOBREQUEST.Job.namejob) { Update-ServerJob -Sourcejobfile $jobfile -Destinationjobfile "$($json.JOBREQUEST.Job.namejob).job" }
                ###LOAD MODULE, ANY EXCEPTION THROW IS CONSIDERED AN ERROR, process stop.
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
                    Out-WinPE -Backuplogs -RemoveJob
                }
            } else {
                WriteLog -Message "Not possible locate Ajolote Module file: $($AjoloteModulesPath)\$($module.filename)" -MessageType Error -Verbose
                if (Test-Path -Path $JobFIle -PathType Leaf) { Copy-Item -Path $JobFile -Destination "$($logs)\Job.err" -Force -ErrorAction SilentlyContinue }                
                $global:MessageResults="Not possible locate Ajolote Module file: $($AjoloteModulesPath)\$($module.filename)"
                $global:CodeResults=220
                if ($null -ne $json.JOBREQUEST.Job) { 
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.Job "fail" $global:MessageResults
                } elseif ($null -ne $json.JOBREQUEST.Control) {
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.Control "fail" $global:MessageResults
                    Start-Process powershell -WorkingDirectory "$($AjoloteDrive)\system.sav\logs\CSBuilt\" -Wait
                }
                Out-WinPE -Backuplogs -RemoveJob
            }
        }    
    }

} else {
    WriteLog -Message "It was not detected Modules definition file: $($AjoloteModulesFile)" -MessageType Warning -Verbose
    $global:MessageResults="It was not detected Modules definition file: $($AjoloteModulesFile)"
    $global:CodeResults=404
    Out-WinPE -Backuplogs -RemoveJob
}

<###############################################
        COPY RESOURCES 
################################################>
if (($json.JOBREQUEST.Control.status -eq "progress") -OR ($json.JOBREQUEST.Job.status -eq "progress")) {
    if ($null -ne $json.JOBREQUEST.Job) { 
        WriteLog -Message "Job process has return without changes, not expected" -MessageType Error -Verbose
        $global:MessageResults="Job process has return without changes, not expected"
    } elseif ($null -ne $json.JOBREQUEST.Control) {
        WriteLog -Message "Control process has return without changes, not expected" -MessageType Error -Verbose
        $global:MessageResults="Control process has return without changes, not expected"
    }  
    $global:CodeResults=1
    Out-WinPE -Backuplogs -RemoveJob
} 

if (($json.JOBREQUEST.Control.status -eq "fail") -OR ($json.JOBREQUEST.Job.status -eq "fail")) {
    if ($null -ne $json.JOBREQUEST.Job) { 
        WriteLog -Message "Job process has fail report: $($json.JOBREQUEST.Job.error)" -MessageType Error -Verbose
        $global:MessageResults="Job process has fail report: $($json.JOBREQUEST.Control.error)"
    } elseif ($null -ne $json.JOBREQUEST.Control) {
        WriteLog -Message "Control process has fail report: $($json.JOBREQUEST.Control.error)" -MessageType Error -Verbose
        $global:MessageResults="Control process has fail report: $($json.JOBREQUEST.Control.error)"
    }    
    $global:CodeResults=1
    Set-BCDEnvironment -Environment "WinPE" -OSDrive $OSDrive -Verbose
    Out-WinPE -Backuplogs -RemoveJob
}  

if (($json.JOBREQUEST.Control.status -eq "new") -OR ($json.JOBREQUEST.Job.status -eq "new")) {
    
    WriteLog -Message "Copy resources required to execute 2nd phase of post processing in Windows environment" -Verbose
    #Copy scripts
    $null = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /sehiy ""$($AjoloteDrive)\AUDIT\system.sav\*"" $($OSDrive)\system.sav\" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\Copyfiles.log"
    $null = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /hiy ""$($AjoloteDrive)\TOOLS\wsusscn2.cab"" $($OSDrive)\system.sav\util\MSUpdates\" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\CopyWSUS.log"
    $null = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /sehiy ""$($AjoloteDrive)\AUDIT\Windows\*"" $($OSDrive)\Windows\" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\CopyHPComplete.log"
    $null = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /sehiy ""$($AjoloteModulesPath)\*"" $($OSDrive)\system.sav\util\AjoloteModules\" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\CopyAjoloteModules.log"
    $null = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /hiy ""$($AjoloteModulesFile)"" $($OSDrive)\system.sav\util\" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\CopyAjoloteModulesFile.log"
    $null = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /hiy ""$($env:SystemDrive)\Windows\System32\MountDrive.exe"" $($OSDrive)\system.sav\util\" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\CopyMountDriveFile.log"

    #Copy logo
    Copy-Item -Path "$($AjoloteDrive)\AUDIT\Unattends\hp.bmp" -Destination "$($OSDrive)\Windows\System32\hp.bmp" -Force | Out-Null
    #Copy Unattend
    if (Test-Path -Path "$($AjoloteDrive)\AUDIT\Unattends\Unattend_$($WinVersion).xml" -PathType Leaf) {
        Copy-Item -Path "$($AjoloteDrive)\AUDIT\Unattends\Unattend_$($WinVersion).xml" -Destination "$($OSDrive)\Windows\System32\sysprep\Unattend.xml" -Force | Out-Null
    } else {
        Copy-Item -Path "$($AjoloteDrive)\AUDIT\Unattends\Unattend.xml" -Destination "$($OSDrive)\Windows\System32\sysprep\Unattend.xml" -Force | Out-Null
    }

    $global:MessageResults="In progress, moving to 2nd phase of post processing"
    if ($json.JOBREQUEST.Control.status -eq "new") {
        Update-JobStatus $jobfile $json $json.JOBREQUEST.Control "progress" $global:MessageResults
    } elseif ($json.JOBREQUEST.Job.status -eq "new") {
        Update-JobStatus $jobfile $json $json.JOBREQUEST.Job "progress" $global:MessageResults
    }
    
    #### REBOOT UNIT AND CONTINUE ON WINDOWS######
    <#if (Test-Path "$($EFIDrive)\EFI") {
        $null = RunPower -File "cmd.exe" -Params "/c rd /s /q $($EFIDrive)\EFI" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\DeleteEFI.log" 
    }#>
    Set-BCDEnvironment -Environment "Windows" -OSDrive $OSDrive -Verbose
    #bcdboot "$($OSDrive)\Windows"
    
       
    $global:CodeResults=0
    Out-WinPE
        
}

if (($json.JOBREQUEST.Control.status -eq "pass") -OR ($json.JOBREQUEST.Job.status -eq "pass")) {
    WriteLog -Message "Control process has completed image creation." -Verbose
    if ($json.JOBREQUEST.Control.status -eq "pass") {
        WriteLog -Message "Press any key to prompt a new PS window to copy your image" -Verbose
        WriteLog -Message "To reset process just close that prompt" -Verbose
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Start-Process Powershell -WindowStyle Maximized -WorkingDirectory "$($OSDrive)\" -Wait
    }
    $global:MessageResults="Process complete successfully"
    $global:CodeResults=0
    Set-BCDEnvironment -Environment "WinPE" -OSDrive $OSDrive -Verbose
    Out-WinPE  -Backuplogs -RemoveJob

} 




####################################################################################################
########################EEEEEEEE#######OOOO#######FFFFFFF###########################################
########################EE###########OO####OO#####FF################################################
########################EEEEE#######OO######OO####FFFFF#############################################
########################EE###########OO####hOO####FF################################################
########################EEEEEEEE########OOOO######FF################################################
####################################################################################################





WriteLog -Message "----->Stop process due reach EOF, reach this point means somenthig was wrong" -MessageType Error -Verbose
if ($null -ne $json.JOBREQUEST.Job) { 
    WriteLog -Message "Clean process and report logs" -MessageType Error -Verbose
} elseif ($null -ne $json.JOBREQUEST.Control) {
    WriteLog -Message "Press any key to open a terminal to review online" -MessageType Error -Verbose
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Start-Process -Wait -FilePath "Powershell.exe"
}
Write-Host "@".PadLeft(([math]::Floor(($sizeofprompt/2)-0.5 + 1)),"@").PadRight($sizeofprompt,"@") -ForegroundColor Green -BackgroundColor Black
Write-Host "@".PadLeft(([math]::Floor(($sizeofprompt/2)-0.5 + 1)),"@").PadRight($sizeofprompt,"@") -ForegroundColor Green -BackgroundColor Black
Write-Host "@".PadLeft(([math]::Floor(($sizeofprompt/2)-0.5 + 1)),"@").PadRight($sizeofprompt,"@") -ForegroundColor Green -BackgroundColor Black

$global:MessageResults="Process reach EOF, clear process"
$global:CodeResults=900
Out-WinPE  -Backuplogs -RemoveJob

##Dispose Variables
$global:CodeResults | Out-Null
$global:envLogs | Out-Null
$global:envDrive | Out-Null
$global:WinDrive | Out-Null
$global:envPath | Out-Null
$global:logs | Out-Null
$global:DebugMode | Out-Null
$global:MainID | Out-Null