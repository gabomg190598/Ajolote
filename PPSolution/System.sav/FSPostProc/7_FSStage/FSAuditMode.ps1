<#
.SYNOPSIS
    HP FS Audit Mode Configuration
.DESCRIPTION
	Configure FS Images
	This version only support Windows 10 minimum version 1909 and Windwos 11
.NOTES
	Script version:		2.0.2 | Update $ScriptVersion variable
	   Script Date: 	Sep.26.2024
	Script support: 	jocisneros@hp.com - HP Inc.
.EXAMPLE
    FSAuditMode.ps1
.OUTPUTCODES
	404 - Missing Module
	405 - Failed import Module
	401 - Missing OSChangerXXX.exe
	/ErrorNumber:700 /Message:"***FAIL*** The CS Post Processing fail unexpected on 1PP phase"
	/ErrorNumber:710 /Message:"***FAIL*** The CS Post Processing fail detecting correct OEM PK"
	/ErrorNumber:711 /Message:"***FAIL*** The CS Post Processing fail installing OEM PK"
	/ErrorNumber:712 /Message:"***FAIL*** The CS Post Processing fail HP Complete installation"
	/ErrorNumber:713 /Message:"***FAIL*** The CS Post Processing fail HP Complete HPDrivers folder persit
	/ErrorNumber:714 /Message:"***FAIL*** The CS Post Processing fail HPComplete tools missing"
	/ErrorNumber:715 /Message:"***FAIL*** The CS Post Processing fail Device Manager has errors"
	/ErrorNumber:716 /Message:"***FAIL*** The CS Post Processing fail missing USMT tool"
	/ErrorNumber:717 /Message:"***FAIL*** The CS Post Processing fail capturing image state"
	/ErrorNumber:718 /Message:"***FAIL*** The CS Post Processing fail sysprep to 2nd PP phase"
	/ErrorNumber:719 /Message:"***FAIL*** The CS Post Processing fail missing Unattend file require for 2nd PP phase"
	/ErrorNumber:720 /Message:"***FAIL*** The CS Post Processing fail sysprep closing 1st PP phase"
	/ErrorNumber:721 /Message:"***FAIL*** The CS Post Processing fail Language install by localization due missing dictionary"
	/ErrorNumber:722 /Message:"***FAIL*** The CS Post Processing fail Language install due missing LP file"
	/ErrorNumber:723 /Message:"***FAIL*** The CS Post Processing fail Language install return error"
	/ErrorNumber:724 /Message:"***FAIL*** The CS Post Processing fail MS Updates return error"
	/ErrorNumber:725 /Message:"***FAIL*** The CS Post Processing fail MS Office structure unexpected"
	/ErrorNumber:726 /Message:"***FAIL*** The CS Post Processing fail MS Office setup"
	/ErrorNumber:727 /Message:"***FAIL*** The CS Post Processing fail MS Updates missing"
	/ErrorNumber:728 /Message:"***FAIL*** The CS Post Processing fail SetupTools missing install.cmd"
	/ErrorNumber:729 /Message:"***FAIL*** The CS Post Processing fail SetupTools error on execution"
	/ErrorNumber:730 /Message:"***FAIL*** The CS Post Processing fail Preconfig Office CS File is missing"
	/ErrorNumber:731 /Message:"***FAIL*** The CS Post Processing fail Preconfig Office fail package setup error"
	/ErrorNumber:732 /Message:"***FAIL*** The CS Post Processing fail Preconfig Office fail missing install.cmd"
	/ErrorNumber:733 /Message:"***FAIL*** The CS Post Processing fail WinRE is disabled"
	/ErrorNumber:734 /Message:"***FAIL*** The CS Post Processing fail not possible validate WinRE"
	/ErrorNumber:735 /Message:"***FAIL*** The CS Post Processing fail not possible switch OS and Capture Image"
	/ErrorNumber:736 /Message:"***FAIL*** The CS Post Processing fail not found WinPE capture package"
	/ErrorNumber:737 /Message:"***FAIL*** The CS Post Processing fail unexpected during capture phase"
	/ErrorNumber:738 /Message:"***FAIL*** The CS Post Processing fail preparinng capture environment"
	/ErrorNumber:739 /Message:"***FAIL*** The CS Post Processing fail copiying XML for 2PP"
	/ErrorNumber:740 /Message:"***FAIL*** The CS Post Processing fail not possible to insert RunOnce Registry"
	/ErrorNumber:741 /Message:"***FAIL*** The CS Post Processing fail not possible Configure PBR"
	/ErrorNumber:742 /Message:"***FAIL*** The CS Post Processing fail not updated image detected"
	/ErrorNumber:743 /Message:"***FAIL*** The CS Post Processing fail applying actions for BlackLotus"

	/ErrorNumber:0 /Message:"***PASS*** The CS Audit Mode has been completed successfully"
.FLAGS
	cserror.flg - Stop process at beginning
	cspause.flg - Stop process when image is ready to be captured
	CSDrvNoVal.flg - Ignore Driver verification
	CSCustMode.flg - Prevent to use factory process
	CSDebug.flg - Prevent reboot unit and debug process
	CSAuditMode.flg - PPKG flag, 2phase of PP
	lanngflag.flg - Install all LP.cab found - Not used annymore
	CaptureFactory.flg - Capture an image when is ready, for customer use, it will be captured at C:\sources
	CapturePP.flg - Capture an image for PP, used for production. image will be captured at C:\sources
	CSPK.flg - Flag to install custom Product Key, align with Ajolote process.
	NoUSMT.flg - Flag to prevent capture state.
#>
#Encoding Script
[cultureinfo]::CurrentCulture = 'en-US'

#Version
$ScriptVersion = "2.0.2"
$FSVersion = "$($ScriptVersion) - PPv2.2024"
$FSVersionFile = (Join-Path $Env:SystemDrive "\system.sav\DPSImageVersion.txt")

if ((-Not(Test-Path $FSVersionFile)) -OR ((Get-Item -Path $FSVersionFile).Length -lt 1)) {
    "HP FS Post-Processing version $($FSVersion)" | Out-File -FilePath $FSVersionFile -Encoding default -Force
}
"`tScript: $($ScriptName) V.$($ScriptVersion)" | Out-File -FilePath $FSVersionFile -Encoding default -Force -Append
##############################################################################
############################# LOAD GLOBAL SCRIPT ####################################
##############################################################################
$GetPS1=Get-ChildItem -Path (Join-Path (Split-Path $PSScriptRoot -Parent) "FSScripts") -Filter "*.ps1" -File | Sort-Object -Property Name
Push-Location $PSScriptRoot 
$counterps1=0
foreach ($script in $GetPS1) {
    try {
        $nameofpiceloaded=$script.Name.substring($script.Name.IndexOf("_")+1,$script.Name.Length-($script.Name.IndexOf("_")+5))
        $counterps1++
        Write-Host "<---------------------------------------- Loading: $($nameofpiceloaded) [$([math]::round($counterps1*100/($GetPS1 | Measure-Object).Count))%] -------------------------------------------------> "
        . $script.FullName
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        [string]$ExceptionText = ($_ | Out-String).Trim()
        Write-Error "`t[FAIL] Not possible load System Script Modules: $($ErrorMessage)"
        Write-Host $ExceptionText
        Exit-FSCode(100)
    }
}
Write-Host "<------------------------------------------------ [Done] -------------------------------------------------------------> "



<######################################################################################################################
#------------------------------------> SPECIFIC STEP                 
#######################################################################################################################>

try {
    		<########################################################################################################
			##########					 CLEAN PROCESS PHASE 1 - After this step it cannot reboot unit
		    ##########################################################################################################>

	"[waiting]Cleanup stage 1 start" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
	WriteLog -Message "--->Remove Unattend file from Panther and Sysprep" -Verbose
	##Ensure that there are no unattends
	if (Test-Path "C:\Windows\Panther\Unattend\Unattend.xml") {$null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q C:\Windows\Panther\Unattend";}
	if (Test-Path "C:\Windows\System32\sysprep\Unattend.xml") {$null = Invoke-RunPower -File "cmd.exe" -Params "/c del /F C:\Windows\System32\sysprep\Unattend.xml";}

	WriteLog -Message "--->Search and remove from Registry Logon commands" -Verbose
	#Clean up registry
	#Remove Run from registry that Unattend Audit created
	$regkey = (Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run)
	$regkey.PSObject.Properties | ForEach-Object {
		if ($_.Value -like "*FSAuditMode.*") { 
			WriteLog -Message "Found RUN on registry for cs audit, removing: $($_.Name)" -Verbose 
			Remove-ItemProperty -Name $_.Name -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
		} 
	}
    WriteLog -Message "--->Search and remove from known and not required paths" -Verbose
    if (Test-Path "$($env:SystemDrive)\system.sav\dpsimages") { WriteLog -Message "Delete DPSIMAGES folder" -Verbose; $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($env:SystemDrive)\system.sav\dpsimages" -OutFile "$($logs)\delfolders.log"; }
    if (Test-Path "$($env:SystemDrive)\system.sav\util\Drivers") { WriteLog -Message "Delete Drivers folder" -Verbose; $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($env:SystemDrive)\system.sav\util\Drivers" -OutFile "$($logs)\delfolders.log"; } 
    if (Test-Path "$($env:SystemDrive)\system.sav\util\MSUpdates") { WriteLog -Message "Delete MSUpdates folder" -Verbose; $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($env:SystemDrive)\system.sav\util\MSUpdates" -OutFile "$($logs)\delfolders.log"; }
    if (Test-Path "$($env:SystemDrive)\system.sav\util\WindowsLP") { WriteLog -Message "Delete LanguagePack folder" -Verbose; $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($env:SystemDrive)\system.sav\util\WindowsLP" -OutFile "$($logs)\delfolders.log"; }
    if (Test-Path "$($env:SystemDrive)\system.sav\tweaks") { WriteLog -Message "Delete tweaks folder" -Verbose; $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($env:SystemDrive)\system.sav\tweaks" -OutFile "$($logs)\delfolders.log"; }
    if (Test-Path "$($env:SystemDrive)\system.sav\PPKG") { WriteLog -Message "Delete PPKG folder" -Verbose; $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($env:SystemDrive)\system.sav\PPKG" -OutFile "$($logs)\delfolders.log"; }
    if (Test-Path "$($env:SystemDrive)\SWSETUP\AdobeReader") { WriteLog -Message "Delete AdobeReader folder" -Verbose; $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($env:SystemDrive)\SWSETUP\AdobeReader" -OutFile "$($logs)\delfolders.log"; }
    if (Test-Path "$($env:SystemDrive)\SWSETUP\APP\Applications") { WriteLog -Message "Delete Applications folder" -Verbose; $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($env:SystemDrive)\SWSETUP\APP\Applications" -OutFile "$($logs)\delfolders.log"; }
    if (Test-Path "$($env:SystemDrive)\SWSETUP\APP\PreReq2") { WriteLog -Message "Delete PreReq2 folder" -Verbose; $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($env:SystemDrive)\SWSETUP\APP\PreReq2" -OutFile "$($logs)\delfolders.log"; }
    if (Test-Path "$($env:SystemDrive)\SWSETUP\APP\PreReq1") { WriteLog -Message "Delete PreReq1 folder" -Verbose; $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($env:SystemDrive)\SWSETUP\APP\PreReq1" -OutFile "$($logs)\delfolders.log"; }
    if (Test-Path "$($env:SystemDrive)\SWSETUP\APP\PreInstallTools") { WriteLog -Message "Delete PreInstallTools folder" -Verbose; $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($env:SystemDrive)\SWSETUP\APP\PreInstallTools" -OutFile "$($logs)\delfolders.log"; }
    if (Test-Path "$($env:SystemDrive)\HP\Drivers") { WriteLog -Message "Delete HPIA Drivers folder" -Verbose; $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($env:SystemDrive)\HP\Drivers" -OutFile "$($logs)\delfolders.log"; }
    if (Test-Path "$($env:SystemDrive)\HP\SWSetup") { WriteLog -Message "Delete HPIA Extract Drivers folder" -Verbose; $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($env:SystemDrive)\HP\SWSetup" -OutFile "$($logs)\delfolders.log"; }
    if ((Test-Path "$($env:SystemDrive)\SWSETUP\APP") -AND ($null -eq (Get-ChildItem -Path Test-Path "$($env:SystemDrive)\SWSETUP\APP" -Recurse))) {WriteLog -Message "Delete PreInstallTools folder" -Verbose; $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($env:SystemDrive)\SWSETUP\APP" -OutFile "$($logs)\delfolders.log"; }
    if ((Test-Path "$($env:SystemDrive)\SWSETUP")) {
        foreach ($folder in (Get-ChildItem -Path (Join-Path $env:SystemDrive "SWSETUP") -Directory | Where-Object {($_.Name -notlike "HP*") -AND ($_.Name -notlike "SP*")})) {
            WriteLog -Message "Removing path: $($folder.FullName)" -Verbose
            $null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($folder.FullName)" -OutFile "$($logs)\delfolders.log";
        }
    }
    



        <###################################################################################################
        #####                               CREATE REPORT OF SOFTWARE INSTALLED
        ####################################################################################################>
        WriteLog -Message "--->Create final image report..." -Component $MyInvocation.MyCommand.Name
    "[loading]Creating Report" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
    WriteLog -Message "You can check all applications reported on clas Win32_Product, APPXPackages and Unistall registry on file: ImagePostProcessingReport.html" -Component $MyInvocation.MyCommand.Name
    #CSS codes
$header = @"
<style>
    h1 {
        font-family: Arial, Helvetica, sans-serif;
        color: #e68a00;
        font-size: 28px;
    }
    
    h2 {
        font-family: Arial, Helvetica, sans-serif;
        color: #000099;
        font-size: 16px;
    }
    
    table {
        font-size: 12px;
        border: 0px; 
        font-family: Arial, Helvetica, sans-serif;
    } 
    
    td {
        padding: 4px;
        margin: 0px;
        border: 0;
    }
    
    th {
        background: #395870;
        background: linear-gradient(#49708f, #293f50);
        color: #fff;
        font-size: 11px;
        text-transform: uppercase;
        padding: 10px 15px;
        vertical-align: middle;
    }

    tbody tr:nth-child(even) {
        background: #f0f0f2;
    }

    #CreationDate {

        font-family: Arial, Helvetica, sans-serif;
        color: #ff3300;
        font-size: 12px;
    }
</style>
"@


    $OSObject = [PSCustomObject]@{
        Version="$((Get-CimInstance -Class Win32_OperatingSystem).Version).$((Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").UBR)"
        Caption=(Get-CimInstance -Class Win32_OperatingSystem).Caption
        BuildNumber=(Get-CimInstance -Class Win32_OperatingSystem).BuildNumber
    }

    $OSinfo = $OSObject | ConvertTo-Html -As List -Property Version,Caption,BuildNumber -Fragment -PreContent "<h2>Operating System Information</h2>"
    "<OS Info>: Done" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
    $UpdateOS = Get-HotFix | ConvertTo-Html -As List -Property HotFixID,Description,InstalledOn -Fragment -PreContent "<h2>Hotfixes Installed</h2>"
    "<Hotfix>: Done" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
    $ProcessInfo = Get-CimInstance -ClassName Win32_Processor | ConvertTo-Html -As List -Property DeviceID,Name,Caption,MaxClockSpeed,SocketDesignation,Manufacturer -Fragment -PreContent "<h2>Processor Information</h2>"
    "<Processor>: Done" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
    $lps = @"
<h2>Installed Langages</h2>
"@
    $installedLanguages= Get-InstalledLanguage
    $LangInfo=$installedLanguages | ConvertTo-Html -As Table -Property LanguageId,LanguagePacks,LanguageFeatures -Fragment
    $lps+=$LangInfo

$clp = @"
<h2>Curent System Locale</h2>
"@
    $locale=Get-WinSystemLocale | ConvertTo-Html -as Table -Property Name,DisplayName,LCID,KeyboardLayoutId -Fragment
    $clp+=$locale

$gtz = @"
<h2>Time Zone</h2>
"@
    $tz=Get-TimeZone | ConvertTo-Html -As Table -Property Id,DisplayName,StandardName,BaseUtcOffset,SupportsDaylightSavingTime -Fragment
    $gtz+=$tz
    
$ctry=@"
<h2>Country</h2>
"@
    $gctry=Get-WinHomeLocation | ConvertTo-Html -As Table -Property GeoId,HomeLocation -Fragment
    $ctry+=$gctry
    "<Languages>: Done" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append

$rsat = @"
<h2>Remote server administration tools (RSAT)</h2>
"@
    $rsatfod=Get-WindowsCapability -Name RSAT* -Online | ConvertTo-Html -As Table -Property DisplayName,State -Fragment
    $rsat+=$rsatfod
    "<RSAT>: Done" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
    
    $BiosObject = [PSCustomObject]@{
        Name=(Get-CimInstance -Namespace ROOT\HP\InstrumentedBIOS -ClassName HP_BIOSString | Where-Object{$_.Name -eq "Product Name"}).Value
        Version=(Get-CimInstance -Namespace ROOT\HP\InstrumentedBIOS -ClassName HP_BIOSString | Where-Object{$_.Name -eq "System BIOS Version"}).Value
        SysID=(Get-CimInstance -Namespace ROOT\HP\InstrumentedBIOS -ClassName HP_BIOSString | Where-Object{$_.Name -eq "System Board ID"}).Value
        SerialNumber=(Get-CimInstance -Namespace ROOT\HP\InstrumentedBIOS -ClassName HP_BIOSString | Where-Object{$_.Name -eq "Serial Number"}).Value
        BuildID=(Get-CimInstance -Namespace ROOT\HP\InstrumentedBIOS -ClassName HP_BIOSString | Where-Object{$_.Name -eq "Build ID"}).Value
        FeatureByte=(Get-CimInstance -Namespace ROOT\HP\InstrumentedBIOS -ClassName HP_BIOSString | Where-Object{$_.Name -eq "Feature Byte"}).Value
    }
    $BiosInfo = $BiosObject | ConvertTo-Html -As List -Property Version,Name,SerialNumber,SysID,BuildID,FeatureByte -Fragment -PreContent "<h2>BIOS Information</h2>"
    "<Bios Info>: Done" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append

$DiscInfo=@"
<h2>Disk Information</h2>
"@
    Get-Disk | Get-Partition | ForEach-Object {
        if ($null -eq ($_ | Get-Volume)) {
            $FreeSpace=0
            $Label=""
            $Drive=""
        } else {
            $FreeSpace=(($_ | Get-Volume).SizeRemaining)
            $Label=(($_ | Get-Volume).FileSystemLabel)
            $Drive=$_.DriveLetter
        }
        $DiskObject= [PSCustomObject]@{
            Disk = $_.DiskNumber
            Partition = $_.PartitionNumber
            GptType = $_.GptType
            Type = $_.Type
            DriveLetter = $Drive
            Size = $_.Size
            FreeSpace = $FreeSpace
            Label = $Label
            ___________ = "" 
        }
        $DiscInfo += $DiskObject | ConvertTo-Html -As List -Property GptType,Type,Disk,Partition,DriveLetter,Label,Size,FreeSpace,___________ -Fragment
    }
    "<Hard Disk>: Done" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
    $product=Get-CimInstance -ClassName Win32_Product | Select-Object -Property Name,Vendor,Version,IdentifyingNumber | ConvertTo-Html -As List -Fragment -PreContent "<h2>Sofware Installed</h2>"
    "<Product>: Done" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
    $appxs=Get-AppxPackage -AllUsers | Select-Object -Property Name,PublisherId,Version,PackageFullName| ConvertTo-Html -As List -Fragment -PreContent "<h2>Applications APPX Installed</h2>"
    "<Appx>: Done" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
$registry = @"
<h2>Registry Key Unistall Options</h2>
<table>
<colgroup><col/><col/><col/><col/></colgroup>
<tr><th>Name</th><th>Poperties</th></tr>
"@
    Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\ | ForEach-Object {
    $list=""
    foreach ($item in $_.Property) { 
        $list+="$($item) : $((Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$((Split-Path -Path $_.Name -Leaf))" -Name $item)."$($item)")</BR>" 
    }
    $line="<tr><td>$((split-path $_.Name -Leaf))</td><td>$($list)</td></tr>"

$registry+=@"
$($line)
"@
}

$registry+=@"
</table>
"@
    "<Software>: Done" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
$registry2 = @"
<h2>Registry Key Unistall Options &lpar;WOW6432Node&rpar;</h2>
<table>
<colgroup><col/><col/><col/><col/></colgroup>
<tr><th>Name</th><th>Poperties</th></tr>
"@
    Get-ChildItem -Path HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\ | ForEach-Object {
    $list=""
    foreach ($item in $_.Property) { 
        $list+="$($item) : $((Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$((Split-Path -Path $_.Name -Leaf))" -Name $item)."$($item)")</BR>" 
    }
    $line="<tr><td>$((split-path $_.Name -Leaf))</td><td>$($list)</td></tr>"

$registry2+=@"
$($line)
"@
}
$registry2+=@"
</table>
"@
    "<Applications>: Done" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append

    $Report = ConvertTo-HTML -Body "$OSinfo $UpdateOS $lps $clp $gtz $ctry $rsat $ProcessInfo $BiosInfo $DiscInfo $product $appxs $registry $registry2" -Head $header -Title "Corporate Ready Image" -PostContent "<p id='CreationDate'>Creation Date: $(Get-Date)</p>"

    #$Report | Out-File (Join-Path $logs "ImagePostProcessingReport.html") -Encoding ascii
    if (Test-Path "$($env:SystemDrive)\System.sav\logs" -PathType Container) {
        WriteLog -Message "Report will be saved on OS System.sav\logs" -Verbose
        $Report | Out-File "$($env:SystemDrive)\System.sav\logs\ImagePostProcessingReport.html" -Encoding ascii
    } else {
        WriteLog -Message "Report will be leave at C:\Windows\Temp" -Verbose
        $Report | Out-File "$($env:SystemDrive)\Windows\Temp\ImagePostProcessingReport.html" -Encoding ascii
    }    

    

		<#####################################################################################################
		############								USMT - STATE CAPTURE
		######################################################################################################>
    WriteLog -Message "--->Start to capture state" -Verbose
    if (-Not(Test-Path $NoUSMT)) {
        if ($null -ne $OS.DisplayVersion -AND $OS.DisplayVersion.Length -gt 2) {
            "[waiting]Capturing current state, please wait...`r`n $($OS.Name) $($OS.Architecture) Ver.$($OS.DisplayVersion)" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
            $msgCapture="$($OS.Name) $($OS.Architecture) Ver.$($OS.DisplayVersion)"
        } else {
            "[waiting]Capturing current state, please wait...`r`n $($OS.Name) $($OS.Architecture) Ver.$($OS.Version)" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
            $msgCapture="$($OS.Name) $($OS.Architecture) Ver.$($OS.Version)"
        }	
        
        if (-Not(Test-Path -Path $USMT -PathType Container)) {
            WriteLog -Message "No found USMT tool folder ($($USMT)), not possible capture image state" -MessageType Error -Verbose
            "No found USMT tool folder ($($USMT)), not possible capture image state" | Out-File -FilePath $errorflg -Encoding default -Force;
            "[error]No found USMT tool folder ($($USMT)), not possible capture image state" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline
            $null = Invoke-RunPower -File $OSChanger -Params "/WDT /ABO /ABONP /ErrorNumber:716 /Message:""***FAIL*** The CS Post Processing fail missing USMT tool""" -WorkDir $WDT -OutFile "$($logs)\OSChangerError.log" -Verbose
            Exit-FSCode(716);
        }
        if (Test-Path "$($USMT)\scanstate.exe") {
            if (-Not(Test-Path (Join-Path $Env:SystemDrive "\Recovery\Customizations"))) { 
                mkdir (Join-Path $Env:SystemDrive "\Recovery\Customizations") -Force; 
                WriteLog -Message "Creating $((Join-Path $Env:SystemDrive "\Recovery\Customizations"))" -MessageType Warning -Verbose;
                $null = Invoke-RunPower -File "cmd.exe" -Params "/c attrib +H $(Join-Path $Env:SystemDrive "Recovery")" -WorkDir $PSScriptRoot -OutFile "$($logs)\AttributesChange.log" -Verbose
            }
            ## Visual progress for GUI interface
            #  Prepare support script for reading and transcript visual progress
            #########################################################################
            $MiniScript="$($logs)\ReaderScript.ps1"
            "`$fiel2Scan=""$($FSscreenProgressFile)""" | Out-File -FilePath $MiniScript -Encoding default -Force
            "`$percent=0" | Out-File -FilePath $MiniScript -Encoding default -Append -Force
            "`$FirstMessage=""Capturing $($msgCapture)""" | Out-File -FilePath $MiniScript -Encoding default -Append -Force
            "`$SecondMessage=""""" | Out-File -FilePath $MiniScript -Encoding default -Append -Force
            "`$outfile=""$($FSscreenStatusFile)""" | Out-File -FilePath $MiniScript -Encoding default -Append -Force
            "while (`$percent -lt 100) {" | Out-File -FilePath $MiniScript -Encoding default -Append -Force
            "`tif (Test-Path `$fiel2Scan) {" | Out-File -FilePath $MiniScript -Encoding default -Append -Force
            "`t`t[System.IO.FileStream]`$fileStream = [System.IO.File]::Open(`$fiel2Scan, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)" | Out-File -FilePath $MiniScript -Encoding default -Append -Force
            "`t`t`$byteArray = New-Object byte[] `$fileStream.Length" | Out-File -FilePath $MiniScript -Encoding default -Append -Force
            "`t`t`$encoding = New-Object System.Text.UTF8Encoding `$true" | Out-File -FilePath $MiniScript -Encoding default -Append -Force
            "`t`twhile (`$fileStream.Read(`$byteArray, 0 , `$byteArray.Length)) {" | Out-File -FilePath $MiniScript -Encoding default -Append -Force
            "`t`t`t`$Lines=`$encoding.GetString(`$byteArray).Split(""``r``n"")" | Out-File -FilePath $MiniScript -Encoding default -Append -Force
            "`t`t`tfor (`$i = 0; `$i -lt `$Lines.Count; `$i++) {" | Out-File -FilePath $MiniScript -Encoding default -Append -Force
            "`t`t`t`tif (`$Lines[`$i].Trim().length -gt 0){" | Out-File -FilePath $MiniScript -Encoding default -Append -Force
            "`t`t`t`t`tif (`$Lines[`$i].Contains(""totalPercentageCompleted,"")) {" | Out-File -FilePath $MiniScript -Encoding default -Append -Force
            "`t`t`t`t`t`t`$readlog=`$Lines[`$i].Split("","")" | Out-File -FilePath $MiniScript -Encoding default -Append -Force
            "`t`t`t`t`t`t[int]`$percent=`$readlog[`$readlog.Count-1]" | Out-File -FilePath $MiniScript -Encoding default -Append -Force
            "`t`t`t`t`t} elseif (`$Lines[`$i].Contains(""PHASE,"")) {" | Out-File -FilePath $MiniScript -Encoding default -Append -Force
            "`t`t`t`t`t`t`$readlog=`$Lines[`$i].Split("","")" | Out-File -FilePath $MiniScript -Encoding default -Append -Force
            "`t`t`t`t`t`t`$SecondMessage=`$readlog[`$readlog.Count-1]" | Out-File -FilePath $MiniScript -Encoding default -Append -Force
            "`t`t`t`t`t} elseif (`$Lines[`$i].Contains(""error,"")) {" | Out-File -FilePath $MiniScript -Encoding default -Append -Force
            "`t`t`t`t`t`t#message ignored" | Out-File -FilePath $MiniScript -Encoding default -Append -Force
            "`t`t`t`t`t} else {" | Out-File -FilePath $MiniScript -Encoding default -Append -Force
            "`t`t`t`t`t`t`$readlog=`$Lines[`$i].Split("","")" | Out-File -FilePath $MiniScript -Encoding default -Append -Force
            "`t`t`t`t`t`t`$SecondMessage=""Step: `$(`$readlog[`$readlog.Count-2]) - Mode: `$(`$readlog[`$readlog.Count-1])""" | Out-File -FilePath $MiniScript -Encoding default -Append -Force
            "`t`t`t`t`t}" | Out-File -FilePath $MiniScript -Encoding default -Append -Force
            "`t`t`t`t}" | Out-File -FilePath $MiniScript -Encoding default -Append -Force
            "`t`t`t}" | Out-File -FilePath $MiniScript -Encoding default -Append -Force
            "`t`t}" | Out-File -FilePath $MiniScript -Encoding default -Append -Force
            "`t`$fileStream.Dispose()" | Out-File -FilePath $MiniScript -Encoding default -Append -Force
            "`t`$WriteText=""`$(`$FirstMessage)``r``n `$(`$SecondMessage)``r``n[progress]`$(`$percent)%""" | Out-File -FilePath $MiniScript -Encoding default -Append -Force
            "`tif (`$WriteText -ne (Get-Content `$outfile)) {`$WriteText | Out-File -FilePath `$outfile -Encoding default -Force}" | Out-File -FilePath $MiniScript -Encoding default -Append -Force
            "`tStart-Sleep -Milliseconds 300" | Out-File -FilePath $MiniScript -Encoding default -Append -Force
            "`t}" | Out-File -FilePath $MiniScript -Encoding default -Append -Force
            "}" | Out-File -FilePath $MiniScript -Encoding default -Append -Force
            $RunScript =Start-Process -FilePath "Powershell.exe" -ArgumentList "-Executionpolicy bypass -WindowStyle Hidden -File $($MiniScript)" -WorkingDirectory $PSScriptRoot -PassThru
            WriteLog -Message "Help script was lauched with ID: $($RunScript.Id)" -Verbose
            #########################################################################
            $RunUSMT = Invoke-RunPower -File "$($USMT)\scanstate.exe" -Params " /apps /config:""$($USMT)\Config_AppsAndSettings.xml"" /ppkg ""c:\Recovery\Customizations\FactoryApps_CS.ppkg"" /o /c /v:13 /l:""$($logs)\USMT_FactoryApps_CS.log"" /i:""$($USMT)\USMT_Exclude.xml"" /progress:""$($FSscreenProgressFile)""" -WorkDir "$($USMT)" -OutFile "$($logs)\ExecuteUSMT.log" -Verbose
            Move-Item -Path $FSscreenProgressFile -Destination "$($logs)\USMT_progress.log" -Force
            if (Test-Path $FSscreenProgressFile) { Remove-Item $FSscreenProgressFile -Force;}
            Get-Process -Id $RunScript.Id -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            if ($RunUSMT -ne 0) { 
                WriteLog -Message "Capture image state return unexpected code=$($RunUSMT)" -MessageType Error -Verbose
                "Capture image state return unexpected code=$($RunUSMT)" | Out-File -FilePath $errorflg -Encoding default -Force;
                "[error]Capture image state return unexpected code" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline
                $null = Invoke-RunPower -File $OSChanger -Params "/WDT /ABO /ABONP /ErrorNumber:717 /Message:""***FAIL*** The CS Post Processing fail capturing image state""" -WorkDir $WDT -OutFile "$($logs)\OSChangerError.log" -Verbose
                Exit-FSCode(717);
            }      
            
        } else {
            WriteLog -Message "No found USMT tool ($($USMT)\scanstate.exe), not possible capture image state" -MessageType Error -Verbose
            "No found USMT tool ($($USMT)\scanstate.exe), not possible capture image state" | Out-File -FilePath $errorflg -Encoding default -Force;
            "[error]No found USMT tool ($($USMT)\scanstate.exe), not possible capture image state" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline
            $null = Invoke-RunPower -File $OSChanger -Params "/WDT /ABO /ABONP /ErrorNumber:716 /Message:""***FAIL*** The CS Post Processing fail missing USMT tool""" -WorkDir $WDT -OutFile "$($logs)\OSChangerError.log" -Verbose
            Exit-FSCode(716);
        }
    } else {
        WriteLog -Message "No USMT flag detect, current state is not captured" -MessageType warning -Verbose       
    }
	

}
catch {
    $ErrorMessage = $_.Exception.Message                
    [string]$ExceptionText = ($_ | Out-String).Trim()
    Write-Host "[ERROR] exception detected on $($CurrentStageFolder), script $($MyInvocation.MyCommand.Name): $($ErrorMessage)"
    Write-Host "[ERROR TEXT]: $($ExceptionText)"
    $null = Invoke-RunPower -File $OSChanger -Params "/WDT /ABO /ABONP /ErrorNumber:999 /Message:""***FAIL***The CS Post Processing fail unamanaged exception""" -WorkDir $WDT -OutFile "$($logs)\OSChangerError.log" -Verbose
    Exit-FSCode(999)
}

Exit-FSCode(0);