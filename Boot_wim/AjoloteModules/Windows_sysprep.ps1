<####################################################################
.Notes
Windows
Sysprep module
Last update Mar/25/2024
#####################################################################>



#Clean up registry, Remove Run from registry that Unattend Audit created
WriteLog -Message "Check Registry to cleaunp"
$regkey = (Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run)
$regkey.PSObject.Properties | ForEach-Object {
    if ($_.Value -like "*csbuiltimage.ps1") { 
        WriteLog -Message "Found RUN on registry for this script, removing: $($_.Name)" -Verbose 
        Remove-ItemProperty -Name $_.Name -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
    } 
}
#Remove Unattend
if ($null -ne $json.JOBREQUEST.InstallPPKG) {
    WriteLog -Message "It is detected PPKG installation, not possible remove unattend from this image" -Verbose 
} else {
    WriteLog -Message "Checking Unattends" -Verbose
    if (Test-Path -Path "$($env:HOMEDRIVE)\Windows\System32\Sysprep\Unattend.xml" -PathType Leaf) {
        Remove-Item "$($env:HOMEDRIVE)\Windows\System32\Sysprep\Unattend.xml" -Force
        WriteLog -Message "Removing $($env:HOMEDRIVE)\Windows\System32\Sysprep\Unattend.xml" -Verbose
    }
    if (Test-Path -Path "$($env:HOMEDRIVE)\Windows\Panther\Unattend\Unattend.xml" -PathType Leaf) {
        Remove-Item "$($env:HOMEDRIVE)\Windows\Panther\Unattend\Unattend.xml" -Force
        WriteLog -Message "Removing $($env:HOMEDRIVE)\Windows\Panther\Unattend\Unattend.xml" -Verbose
    }
    
}
if (Test-Path -Path "$($env:HOMEDRIVE)\system.sav\util\MSUpdates" -PathType Leaf) {
    Remove-Item "$($env:HOMEDRIVE)\system.sav\util\MSUpdates" -Force -Recurse
    WriteLog -Message "Removing $($env:HOMEDRIVE)\system.sav\util\MSUpdates" -Verbose
}
######################################################################################################
# Get Apps and report
######################################################################################################
WriteLog -Message "You can check all applications reported on clas Win32_Product, APPXPackages and Unistall registry on file: ImageBuilderReport.html" -Verbose
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

    h3 {
        font-family: verdana, tahoma, arial, sans-serif;
        font-weight: bolder;
        color: #4DA6FF;
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
    
    .note {
        font-family: verdana, tahoma, arial, sans-serif;
        font-weight: bolder;
        color: #4DA6FF;
        font-size: 12px;
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

$UpdateOS = Get-HotFix | ConvertTo-Html -As List -Property HotFixID,Description,InstalledOn -Fragment -PreContent "<h2>Hotfixes Installed</h2>"

$lps = @"
<h2>Installed Langages</h2>
"@
    Get-InstalledLanguage -ErrorAction SilentlyContinue
    $installedLanguagesReport=Get-InstalledLanguage
    $LangInfo=($installedLanguagesReport | ConvertTo-Html -As Table -Property LanguageId,LanguagePacks,LanguageFeatures -Fragment)
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

$rsat = @"
<h2>Remote server administration tools (RSAT)</h2>
"@
$rsatfod=Get-WindowsCapability -Name RSAT* -Online | ConvertTo-Html -As Table -Property DisplayName,State -Fragment
$rsat+=$rsatfod

$arrFilterCVAs = [system.collections.arraylist]@()
if (($null -ne $json.JOBREQUEST.Drivers.sysid) -OR ($null -ne $json.JOBREQUEST.HPIADrivers)) { 
    if ($null -ne $json.JOBREQUEST.Drivers.sysid) {
        $DriverFolderRoot="$($AjoloteDrive)\DRIVERS\$($json.JOBREQUEST.Drivers.sysid.Trim())"
    }
    if ($null -ne $json.JOBREQUEST.HPIADrivers) {
        $DriverFolderRoot="$($OSDrive)\HP\Drivers"
    }
    $CVA_repo="$($OSDrive)\system.sav\SW_CVA"
    foreach ($upCVA in (Get-ChildItem -Path $DriverFolderRoot -Filter "*.cva" -File -Recurse)) {
        if (-Not(Test-Path "$($OSDrive)\system.sav\SW_CVA" -PathType Container)) { New-Item -Path "$($OSDrive)\system.sav\SW_CVA" -ItemType Directory -Force | Out-Host }
        Copy-Item -Path $upCVA.FullName -Destination "$($CVA_repo)\$($upCVA.Name)" -Force
    }
    WriteLog -Message "Extract Driver details" -Verbose
    $CVAs = Get-ChildItem -Path $CVA_repo -Filter "*.cva" -File -Recurse
    
    foreach ($cva in $CVAs) {
        if ($null -ne (Get-Variable -Name objCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name objCVA -Force -ErrorAction SilentlyContinue }
        $objCVA = Get-CVAObject -pathfile $cva.fullName
        [void]$arrFilterCVAs.add($objCVA); 
    }
    #$arrFilterCVAs | ForEach-Object { $_.Path = $_.Path.Replace("$($AjoloteDrive)\DRIVERS",".\") }
    $DriversList=$arrFilterCVAs | ConvertTo-Html -As Table -Property Title,Version,Vendor,PN -Fragment -PreContent "<h2>Driver Pack created</h2>" -PostContent "<div class=""note"">Note:</div> Above list is the information extracted from CVAs found in created driver pack and not necessary reflect drivers added to current image, review installed apps/software and Windows Drivers list PSDrivers_list.csv for exact used drivers.<br>"
} else {
    $DriversList=@"
<h2>Drivers installed</h2>
"@
}

$Disclaimer=@"
<h3>INFORMATION ABOUT BUILDER SYSTEM</h3>
"@

$ProcessInfo = Get-CimInstance -ClassName Win32_Processor | ConvertTo-Html -As List -Property DeviceID,Name,Caption,MaxClockSpeed,SocketDesignation,Manufacturer -Fragment -PreContent "<h2>Processor Information</h2>"

$BiosObject = [PSCustomObject]@{
	Name=(Get-CimInstance -Namespace ROOT\HP\InstrumentedBIOS -ClassName HP_BIOSString | Where-Object{$_.Name -eq "Product Name"}).Value
	Version=(Get-CimInstance -Namespace ROOT\HP\InstrumentedBIOS -ClassName HP_BIOSString | Where-Object{$_.Name -eq "System BIOS Version"}).Value
	SysID=(Get-CimInstance -Namespace ROOT\HP\InstrumentedBIOS -ClassName HP_BIOSString | Where-Object{$_.Name -eq "System Board ID"}).Value
	SerialNumber=(Get-CimInstance -Namespace ROOT\HP\InstrumentedBIOS -ClassName HP_BIOSString | Where-Object{$_.Name -eq "Serial Number"}).Value
	BuildID=(Get-CimInstance -Namespace ROOT\HP\InstrumentedBIOS -ClassName HP_BIOSString | Where-Object{$_.Name -eq "Build ID"}).Value
	FeatureByte=(Get-CimInstance -Namespace ROOT\HP\InstrumentedBIOS -ClassName HP_BIOSString | Where-Object{$_.Name -eq "Feature Byte"}).Value
}

$BiosInfo = $BiosObject | ConvertTo-Html -As List -Property Version,Name,SerialNumber,SysID,BuildID,FeatureByte -Fragment -PreContent "<h2>BIOS Information</h2>"


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

$product=Get-CimInstance -ClassName Win32_Product | Select-Object -Property Name,Vendor,Version,IdentifyingNumber | ConvertTo-Html -As List -Fragment -PreContent "<h2>Sofware Installed</h2>"

$appxs=Get-AppxPackage -AllUsers | Select-Object -Property Name,PublisherId,Version,PackageFullName| ConvertTo-Html -As List -Fragment -PreContent "<h2>Applications APPX Installed</h2>"

$LocalUserInfo=@"
<h2>Local Users</h2>
"@
Get-LocalUser | Select-Object -Property Name,FullName,PasswordExpires,Enabled,LastLogon | ForEach-Object {
    $LocalUserObject=[PSCustomObject]@{
        Name = $_.Name
        FullName=$_.FullName
        PasswordExpires=$_.PasswordExpires
        Enabled=$_.Enabled
        LastLogon=$_.LastLogon
    }
    $LocalUserInfo += $LocalUserObject | ConvertTo-Html -As List -Property Name,FullName,PasswordExpires,Enabled,LastLogon -Fragment
}


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



$Report = ConvertTo-HTML -Body "$OSinfo $UpdateOS $lps $clp $gtz $ctry $rsat $DriversList $LocalUserInfo $product $appxs $registry $registry2 $Disclaimer $ProcessInfo $BiosInfo $DiscInfo" -Head $header -Title "HP FS Corporate Ready Image" -PostContent "<p id='CreationDate'>Creation Date: $(Get-Date)</p>"

$Report | Out-File (Join-Path $logs "ImageBuilderReport.html") -Encoding ascii
if (Test-Path "$($env:SystemDrive)\System.sav\logs" -PathType Container) {
    WriteLog -Message "Report will be saved on OS drive logs" -Verbose
    $Report | Out-File "$($env:SystemDrive)\System.sav\logs\ImageBuilderReport.html" -Encoding ascii
}
<#
Get-CimInstance -ClassName Win32_Product | Select-Object -Property Name,Caption,Vendor,Version | Out-Host
Get-AppxPackage -AllUsers | Select-Object -Property Name,Publisher,Version,PackageFullName | Out-Host
[string[]]$arrayRegPaths=@("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall","HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall")
foreach ($pt in $arrayRegPaths) {
    if (Test-Path -Path $pt ) {
        Get-ChildItem -Path $pt | Out-Host
    }
}
#>
####################################################################################################
####################################################################################################


#Remove Job share drive
try {
    if (-Not([string]::IsNullOrEmpty($global:JobShareDrive))) {
        WriteLog -Message "Trying to unmount job share drive, after this point network connection is not possible" -Verbose
        $null=Invoke-RunPower -File "cmd.exe" -Params "/c net use /Delete $($global:JobShareDrive)" -WorkDir "C:\Windows\System32" -OutFile "$($logs)\DismountDrive.log" -Verbose
    }    
}
catch {
    WriteLog -Message "Not possible to remove Job Share drive" -MEssageType Error -Verbose
}


<#Clear TPM was requested, not confirmed if works as expected leave for now
try {
    WriteLog -Message "Clear TPM and get status" -Verbose
    Get-Tpm -ErrorAction SilentlyContinue | Out-File -FilePath  "$($logs)\TMP_status_pre.log" -Encoding ascii -Force
    Clear-Tpm -ErrorAction SilentlyContinue | Out-File -FilePath  "$($logs)\TMP_Clear.log" -Encoding ascii -Force
    Get-Tpm -ErrorAction SilentlyContinue | Out-File -FilePath  "$($logs)\TMP_status_pos.log" -Encoding ascii -Force
}
catch {
    [string]$ExceptionText = ($_ | Out-String).Trim()
    WriteLog -Message $ExceptionText -MessageType Error -Verbose
}#>


WriteLog -Message "Verify Windows setup state, before sysprep" -Verbose
if (Test-Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State) { 
    $regkey = Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State -Name ImageState -ErrorAction SilentlyContinue;
    WriteLog -Message "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State ImageState=[$($regkey.ImageState)]" -Verbose
}
if (Test-Path HKLM:\SYSTEM\Setup) { 
    $regkey = Get-ItemProperty -Path HKLM:\SYSTEM\Setup -Name SystemSetupInProgress;
    WriteLog -Message "HKLM:\SYSTEM\Setup SystemSetupInProgress=[$($regkey.SystemSetupInProgress)]" -Verbose
}
if (Test-Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\OOBE) { 
    $regkey = Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\OOBE -Name SetupDisplayedEula -ErrorAction SilentlyContinue;
    WriteLog -Message "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\OOBE SetupDisplayedEula=[$($regkey.SetupDisplayedEula)]" -Verbose
}
if (Test-Path "REGISTRY::HKEY_USERS\.DEFAULT\Software\Microsoft\IdentityCRL\DeviceIdentities") {
    Get-Childitem -Path "REGISTRY::HKEY_USERS\.DEFAULT\Software\Microsoft\IdentityCRL\DeviceIdentities" -Recurse | Out-File -FilePath "$($logs)\Registry_Users.log" -Force
    WriteLog -Message "Review elements on HKEY_USERS\.DEFAULT\Software\Microsoft\IdentityCRL\DeviceIdentities on log $($logs)\Registry_Users.log" -Verbose
}
if (Test-Path HKLM:\SYSTEM\CurrentControlSet\Control\Cryptography\Ngc) {
    Get-Childitem -Path HKLM:\SYSTEM\CurrentControlSet\Control\Cryptography\Ngc -Recurse | Out-File -FilePath "$($logs)\Registry_Ngc.log" -Force
    WriteLog -Message "Review elements on HKLM:\SYSTEM\CurrentControlSet\Control\Cryptograhy\Ngc on log $($logs)\Registry_Ngc.log" -Verbose
}

<#
An issue was detecte with updates of February 13, 2024—KB5034763 (OS Builds 19044.4046 and 19045.4046), sysprep fails:
SYSPRP Package Microsoft.MicrosoftEdge_44.19041.1266.0_neutral__8wekyb3d8bbwe was installed for a user, but not provisioned for all users. This package will not function properly in the sysprep image.
This rule applies especifically for 19044.4046
Same issue detected on March updates, removing restriction to specific revision
#>
if ($OS.Build -eq "19044") {
    WriteLog -Message "An exception rule added to this module has been detected, require to validate a package that not fully install latest update and remove to prevent sysprep fails" -Verbose
    WriteLog -Message "      OS Build: $($OS.Build)" -Verbose
    WriteLog -Message "   OS Revision: $($OS.Revision)" -Verbose
    WriteLog -Message "Remove Package: Microsoft.MicrosoftEdge_44.19041.1266.0_neutral__8wekyb3d8bbwe" -Verbose
    Get-AppxPackage -AllUsers | Where-Object {$_.PackageFullName -eq "Microsoft.MicrosoftEdge_44.19041.1266.0_neutral__8wekyb3d8bbwe"} | Remove-AppxPackage -ErrorAction SilentlyContinue
    Get-AppxPackage -AllUsers | Select-Object -Property * | Out-File -FilePath (Join-Path $logs "getAppxPackagePost.log") -Encoding ascii -Force
}

WriteLog -Message "----->Sysprep Image [Reseal]" -Verbose
Push-Location "$($env:SystemDrive)\Windows\System32\Sysprep"
$SysprepUnit = Invoke-RunPower -File "$($env:SystemDrive)\Windows\System32\Sysprep\sysprep.exe" -Params "/oobe /quit /generalize" -WorkDir "$($env:SystemDrive)\Windows\System32\Sysprep" -OutFile "$($logs)\Sysprep.log"
if ($SysprepUnit -ne 0) {
    WriteLog -Message "it was detected an error during sysprep image $($SysprepUnit)" -MessageType Error -Verbose
    $global:MessageResults="it was detected an error during sysprep image $($SysprepUnit)"
    $global:CodeResults=$SysprepUnit
    Out-Windows
}
WriteLog -Message "Sysprep completed, reboot required to save image" -Verbose
$global:MessageResults="Sysprep completed, reboot required to save image"
$global:CodeResults=0