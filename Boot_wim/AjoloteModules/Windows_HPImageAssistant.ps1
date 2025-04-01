<#
SETUP HP Image Assistant
    Version 1.0.0
    Date: 10/05/2022
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
    #check if expected EXE is present
    $strHPIA_Path=(Join-Path $env:HOMEDRIVE "\SWSETUP\hp-hpia")
    $strHPIA_File="HPImageAssistant.exe"
    $strHPIA_short=(Join-Path $env:PROGRAMDATA "\Microsoft\Windows\Start Menu\Programs\HPImageAssistant.lnk")

    if (Test-Path -Path (Join-Path $strHPIA_Path $strHPIA_File)) {
        WriteLog -Message "Found HP Image Assistant folder, checking shortcut on Programs path" -Verbose
        if (Test-Path -Path $strHPIA_short -PathType Leaf) {
            WriteLog -Message "Already created Shortcut for HP Image Assistant" -Verbose
        } else {
            #Require to create lnk
            WriteLog -Message "Creating shortcut for HP Image Assistant" -Verbose
            $Shell = New-Object -ComObject ("WScript.Shell")
            $ShortCut = $Shell.CreateShortcut($strHPIA_short)
            $ShortCut.TargetPath=$strHPIA_File
            $ShortCut.Arguments="/launch"
            $ShortCut.WorkingDirectory = $strHPIA_Path;
            $ShortCut.WindowStyle = 1;
            $ShortCut.Hotkey = "CTRL+SHIFT+H";
            $ShortCut.IconLocation = "$((Join-Path $strHPIA_Path $strHPIA_File)), 0";
            $ShortCut.Description = "HP Image Assistant";
            $ShortCut.Save();
            #Validate
            if (Test-Path -Path $strHPIA_short -PathType Leaf) {
                WriteLog -Message "Shortcut for HP Image Assistant was created successfuly" -Verbose
            } else {
                WriteLog -Message "Something fail creating shortcut at $($strHPIA_short), review process log" -MessageType Warning -Verbose
                $global:MessageResults="Something fail creating shortcut at $($strHPIA_short), review process log"
                $global:CodeResults=502
                Out-Windows  
            }
        }
    } else {
        WriteLog -Message "Not possible detect $((Join-Path $strHPIA_Path $strHPIA_File)), somenthing fail from WinPE module" -MessageType Warning -Verbose
        $global:MessageResults="Not possible detect $((Join-Path $strHPIA_Path $strHPIA_File)), somenthing fail from WinPE module"
        $global:CodeResults=501
        Out-Windows 
    }
} else {
    WriteLog -Message "This module is not required" -Verbose
}