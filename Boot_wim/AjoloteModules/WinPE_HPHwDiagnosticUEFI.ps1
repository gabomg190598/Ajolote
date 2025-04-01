<#
HP PC Hardware Diagnostics UEFI
Version 1.0.1
    Date: 4/23/2024
    Root node: $json.JOBREQUEST.HPDiagnosticUEFI
    value: 
        boolean, Tru install, false ignore
#>

$SW_Name="HP PC Hardware Diagnostics UEFI"
$LogFile=$SW_Name.Replace(" ","").Replace("(","").Replace(")","")+".log"

if (($null -ne $json.JOBREQUEST.HPDiagnosticUEFI) -AND ($json.JOBREQUEST.HPDiagnosticUEFI)) {
    WriteLog -Message "This module $($SW_Name) is required, checking conditions..." -Verbose
    if ((($null -ne $json.JOBREQUEST.Control) -AND ($json.JOBREQUEST.Control.status -eq "save")) -OR (($null -ne $json.JOBREQUEST.Job) -AND ($json.JOBREQUEST.Job.status -eq "save"))) {
        WriteLog -Message "Image is ready to save, now can be executed" -Verbose
        #check if drivers was requested on job
        if ($null -eq $json.JOBREQUEST.Drivers.sysid) { 
            WriteLog -Message "Drivers folder was not requested by job, not possible to continue with this module" -MessageType Error -Verbose                
            $global:MessageResults = "Drivers folder was not requested by job, not possible to continue with this module: $($SW_Name)"
            $global:CodeResults = 404
            Out-WinPE -Backuplogs -RemoveJob
        }
        #Confirm that drivers folder exist
        $HPN_Drivers = (Join-Path (Join-Path $AjoloteDrive "DRIVERS") $json.JOBREQUEST.Drivers.sysid) 
        if (-Not(Test-Path -Path $HPN_Drivers -PathType Container)) {
            WriteLog -Message "Drivers folder [$($HPN_Drivers)] doesn't exist, not possible to continue with this module" -MessageType Error -Verbose                
            $global:MessageResults = "Drivers folder [$($HPN_Drivers)] doesn't exist, not possible to continue with this module: $($SW_Name)"
            $global:CodeResults = 405
            Out-WinPE -Backuplogs -RemoveJob
        }        
        #Get list of CVA files on drivers folder
        $CVAs = Get-ChildItem -Path $HPN_Drivers -Filter "*.cva" -File -Recurse | Where-Object {$_.Length -gt 0}
        $arrFilterCVAs = [system.collections.arraylist]@()
        foreach ($cva in $CVAs) {
            if ($null -ne (Get-Variable -Name objCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name objCVA -Force -ErrorAction SilentlyContinue }
            $objCVA = Get-CVAObject -pathfile $cva.fullName
            if ($objCVA.Title.Trim().ToLower() -like "*$($SW_Name)*") {
                WriteLog -Message "Found $($objCVA.Title) V.$($objCVA.version)" -Verbose 
                [void]$arrFilterCVAs.add($objCVA);        
            }
        }
        if ($null -ne (Get-Variable -Name GetCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetCVA -Force -ErrorAction SilentlyContinue }
        if ($arrFilterCVAs.Count -gt 0 ) {
            #retrive only latest version
            $GetCVA = ($arrFilterCVAs | Sort-Object -property Version -Descending | Sort-Object -Property Length)[0]
        } else {
            WriteLog -Message "Not possible locate CVA for $($SW_Name), abort process" -MessageType Error -Verbose
            $global:MessageResults = "Not possible locate CVA for $($SW_Name), abort process"
            $global:CodeResults = 406
            Out-WinPE -Backuplogs -RemoveJob 
        }
        WriteLog -Message "Silent command detected: $($GetCVA.Silent)" -Verbose   
        $SilentCommand=""
        if ([string]::IsNullOrEmpty($GetCVA.SilentParameters)) {
            $SilentCommand=$GetCVA.SilentFile
        } else {
            $SilentCommand="$($GetCVA.SilentFile) $($GetCVA.SilentParameters)"
        }
        WriteLog -Message "Silent command required: $($SilentCommand)" -Verbose
        ##########################
        #####Check if this prcess already run, it is not expected that folder of app is present on HPDrivers, this is the way is detected status
        ##########################S
        if (Test-Path -Path (Join-Path (Join-Path $OSDrive "HPDrivers") (Split-Path $GetCVA.Path -Leaf)) -PathType Container) {
            WriteLog -Message "It is detected the folder require for $($SW_Name), this means that process already prepare for this setup, skip now" -MessageType Warning -Verbose

        } else {
            Write-Host "Copying files to OS partition" -Verbose
            $Copyapp = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /sehiyk ""$($GetCVA.Path)\*"" $($OSDrive)\HPDrivers\$(Split-Path $GetCVA.Path -Leaf)\" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\$($LogFile)"
            if ($Copyapp -ne 0) {
                WriteLog -Message "Not possible copy $($SW_Name) to local partition" -MessageType Error -Verbose
                $global:MessageResults="Not possible copy H$($SW_Name) to local partition"
                $global:CodeResults=$Copyapp
                Out-WinPE -Backuplogs -RemoveJob
            }
            #Not expected to have files on this path but it should exist path itself 
            if (Test-Path -Path "$($OSDrive)\Windows\Setup\Scripts" -PathType Container) { 
                WriteLog -Message "Backup logs from scripts folder" -Verbose
                $null = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /hiyk $($OSDrive)\Windows\Setup\Scripts\*.log $($OSDrive)\system.sav\logs\" -OutFile "$($logs)\backupscripts.log";
                $null = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /hiyk $($OSDrive)\Windows\Setup\Scripts\*.txt $($OSDrive)\system.sav\logs\" -OutFile "$($logs)\backupscripts.log";
                $null = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /hiyk $($OSDrive)\Windows\Setup\Scripts\*.xml $($OSDrive)\system.sav\logs\" -OutFile "$($logs)\backupscripts.log";
                WriteLog -Message "Remove logs from scripts folder" -Verbose                    
                Remove-Item -Path "$($OSDrive)\Windows\Setup\Scripts\*" -Include ("*.log","*.txt","*.xml") -Force
                $remscripts = Get-ChildItem -Path "$($OSDrive)\Windows\Setup\Scripts\*" -file -Include ("*.log","*.txt","*.xml")
                if ($null -ne $remscripts)
                {
                    WriteLog -Message "Not possible remove logs and files from \scripts folder" -MessageType Error -Verbose
                    $global:MessageResults="Not possible remove logs and files from \scripts folder"
                    $global:CodeResults=2
                    Out-WinPE -Backuplogs -RemoveJob
                }
            }
            WriteLog -Message "Creating HPComplete.xml" -Verbose
            WriteLog -Message "Silent Command: $($SilentCommand)" -Verbose
            WriteLog -Message "Pass codes: $($GetCVA.PassCodes -join " ")" -Verbose    
            if (-Not(Test-Path (Join-Path $OSDrive "HPDrivers") -PathType Container)) { New-Item -Path (Join-Path $OSDrive "HPDrivers") -ItemType Directory -Force; WriteLog -Message "HPDrivers created due not present at this point" -Verbose; }
            try {
                Invoke-XMLBuild -XMLFileName (Join-Path (Join-Path $OSDrive "HPDrivers") "hpcomplete.xml") -spnumber $SW_Name.Replace(" ","").Replace("(","").Replace(")","") -spname $SW_Name -spsilent "$($SilentCommand)" -spversion $GetCVA.Version -spfolder (Split-Path $GetCVA.Path -Leaf) -spcodes ($GetCVA.PassCodes -join " ") -spenable "yes"
            }
            catch {
                WriteLog -Message "Not possible create HPComplete for $($SW_Name) in local partition" -MessageType Error -Verbose
                $global:MessageResults="Not possible create HPComplete for  $($SW_Name) in local partition"
                $global:CodeResults=100
                Out-WinPE -Backuplogs -RemoveJob
            }            

            #check PPSolution requirement is not present, then add for RUN in regkey
            if (($null -eq $json.JOBREQUEST.AddPPSolution) -OR (-Not($json.JOBREQUEST.AddPPSolution))) {
                WriteLog -Message "PPSolution is not detected for this job, prepare for RUN registry" -MessageType Warning -Verbose                
                #Confirm that HPComplete.exe is present on C:\Windows\Setup\Scripts\
                if (-Not(Test-Path (Join-Path $OSDrive "\Windows\Setup\Scripts\HPComplete.exe") -PathType Leaf)) {
                    WriteLog -Message "Copying HPComplete.exe to OS drive" -Verbose
                    Copy-Item -Path (Join-Path $AjoloteDrive "\AUDIT\Windows\Setup\Scripts\HPComplete.exe") -Destination (Join-Path $OSDrive "\Windows\Setup\Scripts\HPComplete.exe") -Force
                }
            
                #create CMD
                WriteLog -Message "Creating CMD for RUN registry" -Verbose
                $NameREG=(Split-Path $GetCVA.Path -Leaf).Replace(" ","_").Replace("(","").Replace(")","")
                "@echo off" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force
                "SET log=%SystemDrive%\system.sav\logs\$($NameREG).log" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                "SET code=1" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                "echo  =============  INSTALLING APP, PLEASE WAIT...   ==================" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                "echo Script path: %~dp0 >> %log%" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append                
                "dir /b /s %SystemDrive%\SWSETUP\HP\$($NameREG) >> %log% 2>&1" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append       
                "IF NOT EXIST %SystemDrive%\HPDrivers echo HPDrivers folder doesn't exist >> %log% & GOTO outscript" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                "IF NOT EXIST %SystemDrive%\Windows\Setup\Scripts echo Scripts folder doesn't exist >> %log% & GOTO outscript" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                "IF NOT EXIST %SystemDrive%\Windows\Setup\Scripts\hpcomplete.exe echo hpcomplete.exe doesn't exist >> %log% & GOTO outscript" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                "IF NOT EXIST %SystemDrive%\System.sav\logs md %SystemDrive%\System.sav\logs" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                "ATTRIB +H %SystemDrive%\System.sav" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append                
                "tasklist /fi ""ImageName eq hpcomplete.exe"" /fo csv 2>NUL | find /I ""hpcomplete.exe"">NUL" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                "if ""%ERRORLEVEL%""==""0"" echo HPComplete is running, go to end >> %log% & GOTO outscript" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                "pushd %SystemDrive%\SWSETUP\HP" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                "echo moving xml from HPDrivers >> %log%" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                "move /Y %SystemDrive%\HPDrivers\*.xml %SystemDrive%\Windows\Setup\Scripts\ >> %log% 2>&1" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                "echo *start /MIN %SystemDrive%\Windows\Setup\Scripts\hpcomplete.exe /hide >> %log%" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                "start /MIN %SystemDrive%\Windows\Setup\Scripts\hpcomplete.exe /hide >> %log% 2>&1" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append                
                "set code=0" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                "echo removing script folder >> %log%" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                "popd >> %log%" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                ":outscript" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                "cd / >> %log%" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                "echo *exit /b %code%" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                "start cmd.exe /c ""ping -n 3 127.0.0.1 >nul & rd /s /q %~dp0""" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append
                "exit /b %code%" | Out-File -FilePath "$($GetCVA.Path)\CSInstall.cmd" -Encoding ascii -Force -Append

                #copy source, this trigger process to add in RUN regkey
                WriteLog -Message "Moving trigger files to OS drive"                 
                $CopySetup = Invoke-RunPower -file "cmd.exe" -Params "/c Xcopy /hiyk $($GetCVA.Path)\CSInstall.cmd $($OSDrive)\SWSETUP\HP\$($NameREG)\" -WorkDir $GetCVA.Path -OutFile "$($logs)\Copy$($NameREG).log" 
                if ($CopySetup -ne 0) {
                    WriteLog -Message "Fail copying ""$($AppName)""\CSInstall.cmd installation for Post-Processing" -MessageType Error -Verbose
                    $global:MessageResults="Fail copying ""$($AppName)""\CSInstall.cmd installation for Post-Processing"
                    $global:CodeResults=$CopySetup
                    Out-Windows
                }
                
            }

            WriteLog -Message "$($SW_Name) has been prepared for post processing." -Verbose
        }        
        
    } else {
        WriteLog -Message "This image is not ready to save yet, skip module for now" -Verbose
    }
} else {
    WriteLog -Message "This module is not required" -Verbose
}
if ($null -ne (Get-Variable -Name SW_Name -ErrorAction SilentlyContinue)) { Remove-Variable -Name SW_Name -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name LogFile -ErrorAction SilentlyContinue)) { Remove-Variable -Name LogFile -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name HPN_Drivers -ErrorAction SilentlyContinue)) { Remove-Variable -Name HPN_Drivers -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name CVAs -ErrorAction SilentlyContinue)) { Remove-Variable -Name CVAs -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name arrFilterCVAs -ErrorAction SilentlyContinue)) { Remove-Variable -Name arrFilterCVAs -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name GetCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetCVA -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name Copyapp -ErrorAction SilentlyContinue)) { Remove-Variable -Name Copyapp -Force -ErrorAction SilentlyContinue }
if ($null -ne (Get-Variable -Name SilentCommand -ErrorAction SilentlyContinue)) { Remove-Variable -Name SilentCommand -Force -ErrorAction SilentlyContinue }
