<#
SETUP HP Image Assistant
    Version 1.0.1
    Date: 10/20/2022
    Root node: $json.JOBREQUEST.HPIA
    node type: boolean
    True: Require install
    False: Do not install

Main Info
https://ftp.ext.hp.com/pub/caps-softpaq/cmit/HPIA.html
Current version:
    5.1.6	
Release date:
    9/8/2022	
Supported OS:
    Windows (10, 11)	
SP Number:
    sp142446

Source path:
    <componentspath>\HP_Image_Assistant\hp-hpia-<version>

This application does't require setup, registry or kind of.
just require to place on folder and start to use.
plus, create a shotcut to Applications

WinPE Module will just mount share and copy files into OS drive
Windows Module will create shotcut of app into Start menu

#>

#Confirm if module is required
if (($null -ne $json.JOBREQUEST.HPIA) -AND ($json.JOBREQUEST.HPIA)) {
    WriteLog -Message "HP Image Assistant Module required, checking current status" -Verbose
    #check if expected EXE is present
    $strHPIA_Path=(Join-Path $OSDrive "\SWSETUP\hp-hpia")
    $strHPIA_File="HPImageAssistant.exe"
    if (Test-Path -Path (Join-Path $strHPIA_Path $strHPIA_File)) {
        WriteLog -Message "Image already contains HP Image Assistant, no action pending by this module, next step during Windows stage" -Verbose
    } else {
        #Not copied yet 
        ##Mount Share drive
        $DriveComponents = Invoke-MountServer "/componentspath"
        if ($null -eq $DriveComponents) {
            WriteLog -Message "Not possible mount Component share" -MessageType Error -Verbose
            $global:MessageResults="Not possible mount Component share"
            $global:CodeResults=101
            Out-WinPE -Backuplogs -RemoveJob
        } else {
            WriteLog -Message "Components share was mounted successfully on drive: $($DriveComponents)\ Checking component folder" -Verbose
            if (-Not(Test-Path -Path (Join-Path $DriveComponents "HP_Image_Assistant") -PathType Container)) {
                WriteLog -Message "It was not possible to detect folder: $((Join-Path $DriveComponents "HP_Image_Assistant"))" -MessageType Error -Verbose
                $global:MessageResults="It was not possible to detect folder: $((Join-Path $DriveComponents "HP_Image_Assistant"))"
                $global:CodeResults=404
                Out-WinPE -Backuplogs -RemoveJob
            }
            if ($null -eq (Get-ChildItem -Path (Join-Path $DriveComponents "HP_Image_Assistant") -Directory)) {
                WriteLog -Message "There are no version available to install HP Image Assintant" -MessageType Error -Verbose
                $global:MessageResults="There are no version available to install HP Image Assintant"
                $global:CodeResults=405
                Out-WinPE -Backuplogs -RemoveJob
            }
            foreach ($ver in (Get-ChildItem -Path (Join-Path $DriveComponents "HP_Image_Assistant") -Directory | Sort-Object -Property Name -Descending)) {
                WriteLog -Message "Version available: $($ver.Name)" -Verbose
            }
            $LatestVersion=(Get-ChildItem -Path (Join-Path $DriveComponents "HP_Image_Assistant") -Directory | Sort-Object -Property Name -Descending)[0]
            WriteLog -Message "It will install version: $($LatestVersion.Name)" -Verbose
            $CopyFolder=Invoke-RunPower -file "cmd.exe" -Params "/c XCopy /sehiyk ""$($LatestVersion.FullName)\*"" $($strHPIA_Path)\" -WorkDir $PSScriptRoot -OutFile "$($logs)\CopyHPIA.log" -Verbose
            if ($CopyFolder -ne 0) {
                WriteLog -Message "There was not possible to copy HP Image Assistant folder into OS Drive" -MessageType Error -Verbose
                $global:MessageResults="There was not possible to copy HP Image Assistant folder into OS Drive"
                $global:CodeResults=406
                Out-WinPE -Backuplogs -RemoveJob
            }
            #validate 
            if (-Not(Test-Path -Path (Join-Path $strHPIA_Path $strHPIA_File))) {
                WriteLog -Message "Somenthing fail during copying HP Image Assistant folder into OS Drive, not possible locate expected Executable" -MessageType Error -Verbose
                $global:MessageResults="Somenthing fail during copying HP Image Assistant folder into OS Drive, not possible locate expected Executable"
                $global:CodeResults=407
                Out-WinPE -Backuplogs -RemoveJob
            }
            WriteLog -Message "Successfully installed HP Image Assistant, next step, create shortcut during Windows stage" -Verbose
        }
    }
} else {
    WriteLog -Message "This module is not required" -Verbose
}

if ($null -ne (Get-Variable -Name strHPIA_Path -ErrorAction SilentlyContinue)) { Remove-Variable -Name strHPIA_Path -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name strHPIA_File -ErrorAction SilentlyContinue)) { Remove-Variable -Name strHPIA_File -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name DriveComponents -ErrorAction SilentlyContinue)) { Remove-Variable -Name DriveComponents -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name LatestVersion -ErrorAction SilentlyContinue)) { Remove-Variable -Name LatestVersion -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name CopyFolder -ErrorAction SilentlyContinue)) { Remove-Variable -Name CopyFolder -Force -ErrorAction SilentlyContinue }