<#
.SYNOPSIS
    Execute Scripts
.DESCRIPTION
    This Module will execute a list of scripts in specific order and specific environment
.PARAMETER VERSION
    1.0.1
.PARAMETER DATE
    August/15/2023
.PARAMETER STATUS
    "new","ready", "pass","fail"
.NOTES
    Script must be placed on isolated folder due content of that folder is moved to local path

#>

<#  GLOBAL VARIABLES
    $logs = Path to logs
    $OSDrive = OS Drive i.e. C:
    $AjoloteDrive = Ajolote Drive i.e D:

#>

<#  GENERIC PROCESS
ABORT CURRENT

    WriteLog -Message "Not possible mount Component share" -MessageType Error -Verbose
    $global:MessageResults="Not possible mount Component share"
    $global:CodeResults=101
    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSupportAssistant "fail" $global:MessageResults
    Out-WinPE -Backuplogs -RemoveJob
#>


#Clean and declare your unique variables here.
<#
        VARIABLES
#>
$Mod_title="Execute Scripts"
$Mod_Ver="1.0.0"



if ($null -ne $json.JOBREQUEST.ExecuteScript) { #Module node name found on Job
    WriteLog -Message "Running $($Mod_title), version $($Mod_Ver), checking status" -Verbose
    #list and sort every script.
    #for new: copy folder to local path C:\system.sav\util\customscripts\
    foreach ($script in ($json.JOBREQUEST.ExecuteScript | Sort-Object -Property id)) {
        if (($null -eq $script.status) -OR (($null -ne $script.status) -AND ($script.status.Trim().ToLower() -eq "new"))) {
            ###############     Validate all mandatory keys   ######################
            if (($null -eq $script.Tool) -OR ($null -eq $script.Parameters) -OR ($null -eq $script.FullName) -OR ($null -eq $script.Environment) -OR ($null -eq $script.ErrorCodes)) {
                $global:MessageResults="Mandatory key [Tool, Parameters, FullName, Environment, ErrorCodes] for ExecuteScript id#$($script.id) doesn't appears on job, abort process"
                $global:CodeResults=804
                WriteLog -Message $global:MessageResults -MessageType Error -Verbose; 
                Update-JobStatus $jobfile $json $script "fail" $global:MessageResults
                Out-WinPE -Backuplogs -RemoveJob
            }
            WriteLog -Message "Moving Script id $($script.id): $((Split-Path $script.FullName -Leaf)) To local path" -Verbose
            $RemotePath=(Split-Path $script.FullName -Parent)
            $DirectoryName=(Split-Path -Path $RemotePath -Leaf)
            $LocalPath=(Join-Path $OSDrive "\system.sav\Util\CustomScripts\$($DirectoryName)")
            $DriveScript = Invoke-MountServer $RemotePath
            if ($null -eq $DriveScript) {
                WriteLog -Message "Not possible mount Script path $($RemotePath)" -MessageType Error -Verbose
                $global:MessageResults="Not possible mount Script path $($RemotePath)"
                $global:CodeResults=101
                Update-JobStatus $jobfile $json $script "fail" $global:MessageResults
                Out-WinPE -Backuplogs -RemoveJob
            }
            #$CopyFolder=Invoke-RunPower -file "cmd.exe" -Params "/c XCopy /sehiyk ""$($DriveScript)\*"" $($LocalPath)\" -WorkDir $PSScriptRoot -OutFile "$($logs)\Copy$($Mod_title.Replace(' ','_')).log" -Verbose
            if (-Not(Test-Path $LocalPath)) { New-Item -Path $LocalPath -ItemType Directory -Force }
            $CopyFolder=Invoke-RunPower -file "cmd.exe" -Params "/c XCopy /sehiyk ""$($RemotePath)\*"" $($LocalPath)\" -WorkDir $PSScriptRoot -OutFile "$($logs)\Copy$($Mod_title.Replace(' ','_')).log" -Verbose
            if ($CopyFolder -ne 0) {
                WriteLog -Message "There was not possible to copy $($Mod_title), script folder id: $($script.id), name: $($DirectoryName) into OS Drive" -MessageType Error -Verbose
                $global:MessageResults="There was not possible to copy $($Mod_title), script folder id: $($script.id), name: $($DirectoryName) into OS Drive"
                $global:CodeResults=$CopyFolder
                Update-JobStatus $jobfile $json $script "fail" $global:MessageResults
                Out-WinPE -Backuplogs -RemoveJob
            } 
            $global:MessageResults="Script folder id: $($script.id), name: $($DirectoryName) was successfully copied to OS Drive"
            $global:CodeResults=$CopyFolder
            Update-JobStatus $jobfile $json $script "ready" $global:MessageResults
        }        
    }
    #Running script if status is ready, yes I know that can be run on same previous step but this is more human readeable 
    #it is expected that status already exist at this point
    foreach ($script in ($json.JOBREQUEST.ExecuteScript | Sort-Object -Property id)) { 
        if (($script.status.Trim().ToLower() -eq "ready") -AND (($null -ne $script.Environment) -AND ($script.Environment.Tolower() -eq "winpe"))) { 
            $RemotePath=(Split-Path $script.FullName -Parent)
            $ScriptName=(Split-Path $script.FullName -Leaf)
            $DirectoryName=(Split-Path -Path $RemotePath -Leaf)
            $LocalPath=(Join-Path $OSDrive "\system.sav\Util\CustomScripts\$($DirectoryName)")
            WriteLog -Message "Preparing script id#$($script.id), $($ScriptName)" -Verbose
            $ExecuteScript=Invoke-RunPower -file $script.Tool -Params "$($script.Parameters) $((Join-Path $LocalPath $ScriptName))" -WorkDir $LocalPath -OutFile "$($logs)\ExecuteScript_$($script.id).log" -Verbose
            $ExecutedSuccessfully=$false
            foreach ($valid in $script.ErrorCodes) {
                if ([int]$valid -eq [int]$ExecuteScript) {WriteLog -Message "Error code [$($ExecuteScript)] seems to be expected" -Verbose; $ExecutedSuccessfully=$true;}
            }
            if (-Not($ExecutedSuccessfully)) {
                WriteLog -Message "Error code retuned [$($ExecuteScript)] for script id#$($script.id) file: $($ScriptName) is not expected, abort process" -MessageType Error -Verbose
                $global:MessageResults="Error code retuned [$($ExecuteScript)] for script id#$($script.id) file: $($ScriptName) is not expected, abort process"
                $global:CodeResults=$ExecuteScript
                Update-JobStatus $jobfile $json $script "fail" $global:MessageResults
                Out-WinPE -Backuplogs -RemoveJob
            }
            $null = Invoke-RunPower -file "cmd.exe" -Params "/c xcopy $($LocalPath)\*.log" -WorkDir $LocalPath -OutFile "$($logs)\ExecuteScript_CopyLogs_$($script.id).log" -Verbose
            $null = Invoke-RunPower -file "cmd.exe" -Params "/c xcopy $($LocalPath)\*.txt" -WorkDir $LocalPath -OutFile "$($logs)\ExecuteScript_CopyLogs_$($script.id).log" -Verbose
        }
    }
    #Check other status
    foreach ($script in ($json.JOBREQUEST.ExecuteScript | Sort-Object -Property id)) { 
        if ($script.status.Trim().ToLower() -eq "pass") {            
            WriteLog -Message "This script id#[$($script.id)] already complete successfully"
        } elseif ($script.status.Trim().ToLower() -eq "fail") {
            $global:MessageResults="Error detected on Execute Script id#[$($script.id)], abort process"
            $global:CodeResults=$ExecuteScript
            WriteLog -Message $global:MessageResults -MessageType Error -Verbose
            Update-JobStatus $jobfile $json $script "fail" $global:MessageResults
            Out-WinPE -Backuplogs -RemoveJob
        } 
    }

} else {
    WriteLog -Message "This module is not required" -Verbose
}
