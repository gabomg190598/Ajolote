#<----Some Functions require run under administrator permits
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{   
	$arguments = "& '" + $myinvocation.mycommand.definition + "'"
	Write-Warning "Open Coomand line as Administrator..."
	Start-Process powershell -Verb runAs -ArgumentList $arguments
	Break
}
$ScriptName=$MyInvocation.MyCommand.Name

function Show-Notification {
    [cmdletbinding()]
    Param (
        [Parameter(Mandatory=$true,ValueFromPipeline,Position=0)]
        [string]$Title,
        [Parameter(Mandatory=$true,ValueFromPipeline,Position=1)]
        [string]$Text,
        [Parameter(Mandatory=$false,Position=3)]
        [string]$ToastTitle="FS Image Security"
    )

    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
    $Template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)

    $RawXml = [xml] $Template.GetXml()
    ($RawXml.toast.visual.binding.text|Where-Object {$_.id -eq "1"}).AppendChild($RawXml.CreateTextNode($Title)) > $null
    ($RawXml.toast.visual.binding.text|Where-Object {$_.id -eq "2"}).AppendChild($RawXml.CreateTextNode($Text)) > $null

    $SerializedXml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $SerializedXml.LoadXml($RawXml.OuterXml)

    $Toast = [Windows.UI.Notifications.ToastNotification]::new($SerializedXml)
    $Toast.Tag = $ToastTitle
    $Toast.Group = $ToastTitle
    $Toast.ExpirationTime = [DateTimeOffset]::Now.AddMinutes(1)
    Write-Host "Creating Toast Notification [$($ToastTitle)]"
    Write-Host "`t$($Title)"
    Write-Host "`t$($Text)"
    $Notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("$($ToastTitle)")
    $Notifier.Show($Toast);
}
function Add-RunOnce {
    #Adding self script for next reboot
    $regPath="HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce"
    $regName="fsblklts"
    $BLScriptName=$ScriptName
    try {
        if (-Not(Test-Path $regPath)) { New-Item -Path $regPath -ItemType Directory -Force | Out-Host }
        $regVal="Powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File ""$((Join-Path $PSScriptRoot $BLScriptName))"""
        if ($null -ne (Get-ItemPropertyValue -Path $regPath -Name $regName -ErrorAction SilentlyContinue)) {
            Write-Host "RunOnce already exist, value: $(Get-ItemPropertyValue -Path $regPath -Name $regName -ErrorAction SilentlyContinue)"
        }
        while ($null -eq (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue)) {
            Write-Host "Adding RunOnce current script: $($regVal)"
            New-ItemProperty -Path $regPath -Name $regName -Value $regVal -PropertyType "String" -Force | Out-Null
            Start-Sleep -Seconds 15
        }
    }
    catch {
        Write-Error "Not possible change registry, check permisions"
        Stop-Transcript
        exit 5
    }
    
}

function Remove-RunOnce {
    $regPath="HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce"
    $regName="fsblklts"
    try {
        while ($null -ne (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue)) {
            Remove-ItemProperty -Path $regPath -Name $regName -Force | Out-Null
            Start-Sleep -Seconds 15
        }
    }
    catch {
        Write-Error "Not possible change registry, check permisions"
        Stop-Transcript
        exit 5
    }
    
}
#working path
$WorkPath=$PSScriptRoot
#Registry applied flag
$BLFlag=(Join-Path $PSScriptRoot "FSblapplied.flg")
try {
    if (Test-Path "$($WorkPath)\_FSSetup.log") {
        Start-Transcript -Path "$($WorkPath)\_FSSetup.log" -Append | Out-Null
    } else {
        Start-Transcript -Path "$($WorkPath)\_FSSetup.log" | Out-Null
    }
}
catch {
    Stop-Transcript | Out-Null
    Start-Transcript -Path "$($WorkPath)\_FSSetup.log"  -Force | Out-Null
}

Write-Host "Initialize for user [$($env:USERNAME)]"
Add-RunOnce

#Prevent Run in Audit Mode
$CurrentWindowsState=(Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State -Name ImageState).ImageState
if ($CurrentWindowsState -ne "IMAGE_STATE_COMPLETE") { Write-Host "[Warning]This Script is not allowed to run under Windows state: $($CurrentWindowsState)"; Stop-Transcript; exit 5;}

#at this point this script is running fine, removing shortcut support
$scPath="$($env:SystemDrive)\Users\Public\Desktop\WindowsBootManagerValidation.lnk"
if (Test-Path -Path $scPath) { Remove-Item -Path $scPath -Force } 

#1) Check Event logs
Write-Host "Validating BlackLotus revocations, checking Event Logs"
Get-EventLog -Newest 50 -LogName System -ErrorAction SilentlyContinue | Out-File -FilePath (Join-Path $PSScriptRoot "ValidateEventLog.log") -Append
Get-WinEvent -LogName Microsoft-Windows-Kernel-Boot/Operational -MaxEvents 50 -ErrorAction SilentlyContinue | Out-File -FilePath (Join-Path $PSScriptRoot "ValidateEventLog.log") -Append
$InitialStepVal1=$false
$InitialStepVal2=$false
if ($null -ne (Get-EventLog -LogName System -ErrorAction SilentlyContinue | Where-Object {$_.InstanceID -eq 1035})) {
    Write-Host "Event Log System ID 1035 found"
    $retrieve=(Get-EventLog -LogName System | Where-Object {$_.InstanceID -eq 1035})
    Write-Host "Event Log(1035): [$($retrieve[0].TimeWritten)] - $($retrieve[0].Message)"
    $InitialStepVal1=$true
}
if ($null -ne (Get-WinEvent -LogName Microsoft-Windows-Kernel-Boot/Operational -ErrorAction SilentlyContinue | Where-Object {$_.Id -eq 276})) {
    Write-Host "Event Log Microsoft-Windows-Kernel-Boot/Operational ID 276 found"
    $readlog=(Get-WinEvent -LogName Microsoft-Windows-Kernel-Boot/Operational | Where-Object {$_.Id -eq 276})
    Write-Host "Event Log(276): [$($readlog[0].TimeCreated)] - $($readlog[0].Message)"
    $InitialStepVal2=$true
}
if ($InitialStepVal1 -AND $InitialStepVal2) {
    Start-Sleep -Seconds 30
    Write-Host "Secure Boot revocation for Phase 2 completed"
    Show-Notification -Title "Secure Boot Manager" -Text "Revocation has been applied and validated, Secure Boot updated."
    if (Test-Path -Path $scPath) { Remove-Item -Path $scPath -Force } 
    Remove-RunOnce
    Stop-Transcript
    exit 0
}

if (Test-Path $BLFlag) {
    Write-Host "Revocation protection already applied, wait at least 5 minutes"
    if (Test-Path -Path $scPath) { 
        Show-Notification -Title "Secure Boot Manager" -Text "By process is required to wait at least 5 minutes and then reboot again to enable revocations, please wait"
    } 
    Start-Sleep -Seconds 300
    Show-Notification -Title "Reboot required" -Text "Secure Boot Manager: Please reboot unit to complete the revocation protections"
    Add-RunOnce
    Remove-Item $BLFlag -Force
    Stop-Transcript;
    exit 2;
} else {
	Write-Host "===> Perfoming Secure Boot Manager Revocations 3a"
    ################# GET OS #############################
    $OS=@{}
    $OS.ProductName = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').ProductName
    $OS.Architecture = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
    $OS.Version = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').ReleaseId
    $OS.Build = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuildNumber
	switch ($OS.Build) {
		"19041" { $OS.Name=$OS.ProductName; break; }
		"19042" { $OS.Name=$OS.ProductName; break; }
		"19043" { $OS.Name=$OS.ProductName; break; }
		"19044" { $OS.Name=$OS.ProductName; break; }
		"19045" { $OS.Name=$OS.ProductName; break; }
		"22000" { $OS.Name=$OS.ProductName.Replace(" 10 "," 11 "); break;}
		"22621" { $OS.Name=$OS.ProductName.Replace(" 10 "," 11 "); break;}
		Default { if ([int]$OS.Build -ge 22000) { $OS.Name=$OS.ProductName.Replace(" 10 "," 11 ") } else { $OS.Name=$OS.ProductName}; break; }
	}
    $OS.Revision = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').UBR
    $OS.DisplayVersion = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DisplayVersion
    $OS.Branch = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').BuildBranch
	
    ######################################################
	$CurrentBuildTable = @{
		"22621" = "1992" # W11 22H2, KB5028185
		"22000" = "2176" # W11 21H2, KB5028182
		"19045" = "3208" # W10 22H2, KB5028166
		"19044" = "3208" # W10 21H2, KB5028166
		"17763" = "4645" # W10 1809 LTSC, KB5028168
		"14393" = "6085" # W10 1607 LTSC, KB5028169
		"10240" = "20048" # W10 1507 LTSC, KB5028186
	}
	$ValidOS=$true
	switch ($OS.Build) {
		22621 { If ($OS.Revision -lt $CurrentBuildTable["$OS.Build"]){ Write-Host "[ERROR] This OS has not meet minimum updates required to be released."; $ValidOS=$false } }
		22000 { If ($OS.Revision -lt $CurrentBuildTable["$OS.Build"]){ Write-Host "[ERROR] This OS has not meet minimum updates required to be released."; $ValidOS=$false } }
		19045 { If ($OS.Revision -lt $CurrentBuildTable["$OS.Build"]){ Write-Host "[ERROR] This OS has not meet minimum updates required to be released."; $ValidOS=$false } }
		19044 { If ($OS.Revision -lt $CurrentBuildTable["$OS.Build"]){ Write-Host "[ERROR] This OS has not meet minimum updates required to be released."; $ValidOS=$false } }
		17763 { If ($OS.Revision -lt $CurrentBuildTable["$OS.Build"]){ Write-Host "[ERROR] This OS has not meet minimum updates required to be released."; $ValidOS=$false } }
		14393 { If ($OS.Revision -lt $CurrentBuildTable["$OS.Build"]){ Write-Host "[ERROR] This OS has not meet minimum updates required to be released."; $ValidOS=$false } }
		10240 { If ($OS.Revision -lt $CurrentBuildTable["$OS.Build"]){ Write-Host "[ERROR] This OS has not meet minimum updates required to be released."; $ValidOS=$false } }
		Default { Write-Host "[ERROR] This OS is not supported: $($OS.Build)."; $ValidOS=$false } 
	}
	
	if ($ValidOS) {
		Write-Host "Operating System meets with minimum version to be released: $($OS.Build).$($OS.Revision), BlackLotus mitigation step 3a-1"
	} else {
		Write-Error "Not possible validate this OS, Blacklotus mitigations can't continue"
        Show-Notification -Title "[ERROR] Invalid OS" -Text "This OS doesn't meet with minimal version for Secure Boot revocations"
        Remove-RunOnce
        Stop-Transcript;
        exit -1
	}
    Start-Sleep -Seconds 60
	$Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Secureboot\"
	$ValueName = "AvailableUpdates"
	$Value = 48
    #Create Path
	if (-Not(Test-Path -Path $Path)) { New-Item -Path $Path -ItemType Directory -Force }
	$CurrentValue = Get-ItemProperty -Path $Path -Name $ValueName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $ValueName
	Write-Host "Current value for $($ValueName) = [$($CurrentValue)]"
	if ($CurrentValue -ne $Value) {
		Write-Host "Updating value as required for Blacklotus 2nd phase mitigation, for $($ValueName) = [$($Value)]"
		Set-ItemProperty -Path $Path -Name $ValueName -Value $Value -Force
	}
	$NewValue = Get-ItemProperty -Path $Path -Name $ValueName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $ValueName
	if ($NewValue -ne $Value) {
		Write-Error "Not possible update registry value for Blacklotus mitigation actions"
        Add-RunOnce
		Stop-Transcript;
		exit 1;
	} else {
        "Registry was created" | Out-File -FilePath $BLFlag -Encoding ascii -Force
        Show-Notification -Title "Reboot required" -Text "Please reboot unit to enable the revocation protections - Boot Manager"
		Add-RunOnce
        Stop-Transcript;
		exit 2;
	}
}