#$CSBuildErrorFlag="$($env:SystemDrive)\system.sav\flags\csbuilderror.flg"
#Check and run HPComplete
$DriversPath="C:\HPDrivers"
$HPComplete="C:\Windows\Setup\Scripts\HPComplete.exe"
#$CounterFile="$($PSScriptRoot)\counter.ini"
if ((Test-Path -Path $DriversPath -PathType Container) -AND (Test-Path -Path $HPComplete -PathType Leaf)){ 
    #Check new option to prevent that setup runs instead on first boot
    if (($null -ne $json.JOBREQUEST.Drivers.preventsetup) -AND ($json.JOBREQUEST.Drivers.preventsetup)) {
        WriteLog -Message "Prevent Setup was detected on current job, skip HPComplete execution" -Verbose
    } else {
        WriteLog -Message "Driver path detected, check if need to move XML" -Verbose
        if (Get-ChildItem -Path $DriversPath -File -Filter "*.xml") {        
            Get-ChildItem -Path $DriversPath -File -Filter "*.xml" | ForEach-Object {WriteLog -Message "Moving $($_.Name)" -Verbose; Copy-Item -Path $_.FullName -Destination "C:\Windows\Setup\Scripts\$($_.Name)" -Force }
        }
        if ($null -eq (Get-ChildItem -Path "C:\Windows\Setup\Scripts" -File -Filter "*.xml")) {
            WriteLog -Message "Not detected any XML on HPComplete folder, cannot continue" -MessageType Error -Verbose
            $global:MessageResults="Not detected any XML on HPComplete folder, cannot continue"
            $global:CodeResults=404
            Out-Windows
        }
        WriteLog -Message "Driver path detected, try to run HPComplete.exe" -Verbose
        ##check counter
        if ($null -ne $json.JOBREQUEST.Job) { 
            if ($null -ne $json.JOBREQUEST.Job.setupcounter) {
                [int]$MyCounter=$json.JOBREQUEST.Job.setupcounter;
                $MyCounter++;
                $json.JOBREQUEST.Job.setupcounter=$MyCounter
            } else {
                [int]$MyCounter=1
                $json.JOBREQUEST.Job | Add-Member -Name "setupcounter" -MemberType NoteProperty -Value $MyCounter       
        }
        } elseif ($null -ne $json.JOBREQUEST.Control) {
            if ($null -ne $json.JOBREQUEST.Control.setupcounter) {
                [int]$MyCounter=$json.JOBREQUEST.Control.setupcounter;
                $MyCounter++;
                $json.JOBREQUEST.Control.setupcounter=$MyCounter
            } else {
                [int]$MyCounter=1
                $json.JOBREQUEST.Control | Add-Member -Name "setupcounter" -MemberType NoteProperty -Value $MyCounter       
        }
        }
        ### Save JOB file
        try {
            $json | ConvertTo-Json -Depth 16 | Out-File -FilePath $jobfile -Encoding ascii -Force
        } catch {
            $ErrorMessage = $_.Exception.Message
            WriteLog -Message "Failed updating JOB file: $($ErrorMessage)" -MessageType Error -Verbose
            $global:MessageResults="Failed updating JOB file: $($ErrorMessage)"
            $global:CodeResults=209
            Out-Windows
        }

        WriteLog -Message "Trying to run HPComplete $($MyCounter)/5" -Verbose
        #timeout of 30 minutes, it is not expected that install all setups take more than 30 minutes
        $RunHPComplete = Invoke-RunPower -File $HPComplete -Params "/full" -WorkDir $PSScriptRoot -TimeOut 1800 -OutFile "$($logs)\hpcomplete_execution.log" -Verbose
        if ($RunHPComplete -ne 0) {
            WriteLog -Message "HP Complete return unexpected error=$($RunHPComplete), HP CS Post-Processing Mode can't continue" -MessageType Error -Verbose
            $global:MessageResults="HPComplete return unexpected code, prrocess cancelled"
            $global:CodeResults=$RunHPComplete
            foreach ($item in (Get-ChildItem -Path "C:\Windows\Setup\Scripts" -File -Recurse -Exclude "*.exe")) {
                Copy-Item -Path $item.FullName -Destination (Join-Path $logs $item.Name) -Force
            }
            Out-Windows
        }
        if (Test-Path -Path $DriversPath -PathType Container) {
            if ($MyCounter -gt 4) {
                WriteLog -Message "Somenthing is not working as expected, After several retries HPDrivers still exist, stop process to let user review issue" -MessageType Error -Verbose
                $global:MessageResults="Somenthing is not working as expected, After several retries HPDrivers still exist, stop process to let user review issue"
                $global:CodeResults=1
                foreach ($item in (Get-ChildItem -Path "C:\Windows\Setup\Scripts" -File -Recurse -Exclude "*.exe")) {
                    Copy-Item -Path $item.FullName -Destination (Join-Path $logs $item.Name) -Force
                }
                Out-Windows
            } else {
                WriteLog -Message "Drivers are not successfully installed, HPDrivers folder still exist, reboot and retry" -MessageType Warning -Verbose;
                $global:MessageResults="Drivers are not successfully installed, HPDrivers folder still exist, reboot and retry"
                $global:CodeResults=3010
                Out-Windows
            }
        }
        #Double check Drivers path and contents
        if (Test-Path -Path $DriversPath -PathType Container) {
            if ((Get-ChildItem $DriversPath -Recurse -Directory | Measure-Object).Count -gt 0) {
                WriteLog -Message "HPDrivers folder remain with some directories inside, process cannot continue" -MessageType Error -Verbose;
                $global:MessageResults="HPDrivers folder remain with some directories inside, process cannot continue"
                $global:CodeResults=1
                foreach ($item in (Get-ChildItem -Path "C:\Windows\Setup\Scripts" -File -Recurse -Exclude "*.exe")) {
                    Copy-Item -Path $item.FullName -Destination (Join-Path $logs $item.Name) -Force
                }
                Out-Windows
            }
        }
        WriteLog -Message "If exist, move log files" -Verbose
        $null = RunPower -File "cmd.exe" -Params "/c xcopy /hiyk C:\Windows\Setup\Scripts\*.log $($logs)\" -WorkDir $PSScriptRoot -OutFile "$($logs)\copyhpcomplete_logs.log" -Verbose
        $null = RunPower -File "cmd.exe" -Params "/c xcopy /hiyk C:\Windows\Setup\Scripts\*.txt $($logs)\" -WorkDir $PSScriptRoot -OutFile "$($logs)\copyhpcomplete_txts.log" -Verbose
        $null = RunPower -File "cmd.exe" -Params "/c xcopy /hiyk C:\Windows\Setup\Scripts\*.xml $($logs)\" -WorkDir $PSScriptRoot -OutFile "$($logs)\copyhpcomplete_xmls.log" -Verbose
        $null = RunPower -File "cmd.exe" -Params "/c xcopy /hiyk C:\Windows\Setup\Scripts\*.ini $($logs)\" -WorkDir $PSScriptRoot -OutFile "$($logs)\copyhpcomplete_inis.log" -Verbose
        foreach ($item in (Get-ChildItem -Path "C:\Windows\Setup\Scripts\*" -Recurse -Include *.log,*.txt,*.xml,*.ini,*.exe)) {
            WriteLog -Message "Removing: $($item.Name)" -Verbose
            Remove-Item -Path $item.FullName -Force 
        }
        
    }
    

} elseif ((Test-Path -Path $DriversPath -PathType Container) -AND (!(Test-Path -Path $HPComplete -PathType Leaf))) {
    WriteLog -Message "Drivers path is present however HPComplete is missing, nothing to do here" -MessageType Warning -Verbose
}

<########################################################################################################################
    INSTALLING SWSETUP FOLDER CONTENT
Each folder inside it's considered GBU component, must contain CVA file
instruction on that CVA will used to execute process, if return code is not one of the CVA it fails
"preventsetup" has not effect on this option since PP has not fully support

########################################################################################################################>
$SWSetupPath="C:\HPSETUP"
$GBUDriversFlag="C:\system.sav\flags\gbudriversdone.flg"
$InstallGBUDriversFlag="C:\system.sav\flags\gbudrivers.flg"
if ((Test-Path -Path $SWSetupPath -PathType Container) -AND (Test-Path -Path $InstallGBUDriversFlag -PathFile Leaf) -AND (-Not(Test-Path -Path $GBUDriversFlag -PathType Leaf))) {
    if (-Not(Test-Path -Path (Split-Path $GBUDriversFlag -Parent) -PathType Container)) { New-Item -Path (Split-Path $GBUDriversFlag -Parent) -ItemType Directory -Force | Out-Null }
    WriteLog -Message "$($SWSetupPath) was detected, trying to use to install drivers or apps as part of Drivers Setup module" -Verbose
    $TopDirs=Get-ChildItem -Path $SWSetupPath -Directory 
    $errors=0
    foreach ($dir in $TopDirs) {
        WriteLog -Message "Scaning directory: $($dir.Name)" -Verbose
        $CVAs=Get-ChildItem -Path $dir.FullName -Recurse -File -Filter "*.cva"
        if (($null -eq $CVAs) -OR ($CVAs | Measure-Object).Count -eq 0) {
            WriteLog -Message "Component $($dir.Name) has no CVA file" -MessageType Error -Verbose
            $errors++;
            continue
        } else {
            $cva = Get-CVAObject -PathFile $CVAs[0].FullName -Verbose
            WriteLog -Message "CVA detected: $($CVAs[0].FullName)"
            WriteLog -Message "Name: $($cva.Title) [V.$($cva.Version)]" -Verbose
            if ($cva.Silent.Trim().StartsWith('"')) { $SilentFile="""$($cva.Path)\$($cva.Silent.Trim().Substring(1,$cva.Silent.Trim().Length-1))" } else { $SilentFile="$($cva.Path)\$($cva.Silent.Trim())" }
            WriteLog -Message "Silent command: $($SilentFile)" -Verbose
            WriteLog -Message "Sucsseffuly codes: $($cva.PassCodes)" -Verbose
            Push-Location -Path $cva.Path
            $ExecuteGBU = RunPower -File "cmd.exe" -Params "/c $($SilentFile)" -WorkDir $cva.Path -OutFile "$($logs)\Setup_$($dir.Name).log" -Verbose
            Pop-Location
            if ($cva.PassCodes.Contains($ExecuteGBU)) {
                WriteLog -Message "Setup complete successfully, removing folder" -Verbose
                Remove-Item -Path $dir.FullName -Recurse -Force
            } else {
                WriteLog -Message "Incorrect code was retrieved: $($ExecuteGBU)" -MessageType Error -Verbose
                $errors++;
            }           
        }
        
    } #end foreach
    
    WriteLog -Message "Detected $(((Get-ChildItem -Path $SWSetupPath | Measure-Object).Count)) objects on $($SWSetupPath)" -Verbose
    if ($errors -gt 0) {
        WriteLog -Message "Detected $($errors) error(s) during GBU Setup drivers/apps" -MessageType Error -Verbose
        $global:MessageResults="GBU Setup drivers/apps with $($errors) errors"
        $global:CodeResults=1
        Out-Windows
    } else {
        WriteLog -Message "Successfully installed GBU drivers" -Verbose
        "pass" | Out-File -FilePath $GBUDriversFlag -Encoding ascii -Force
        Remove-Item -Path $InstallGBUDriversFlag -Force
        Remove-Item -Path $SWSetupPath -Recurse -Force 
    }
} elseif ((Test-Path -Path $InstallGBUDriversFlag -PathType Leaf) -AND (-Not(Test-Path -Path $SWSetupPath -PathType Container))) {
    WriteLog -Message "Flag to indicate that GBU drivers must be installed, however missing folder $($SWSetupPath)" -MessageType Warning -Verbose

} elseif (Test-Path -Path $GBUDriversFlag -PathType Leaf) {
    WriteLog -Message "GBU drivers/apps was already executed" -Verbose
}
