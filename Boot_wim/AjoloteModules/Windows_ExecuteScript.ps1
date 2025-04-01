<#
.SYNOPSIS
    Execute Scripts
.DESCRIPTION
    This Module will execute a list of scripts in specific order and specific environment
.PARAMETER VERSION
    1.0.0
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
    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSupportAssistant "fail" $global:MessageResult
    Out-Windows 
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
            $global:MessageResults="It is not expected that Execute Script id#[$($script.id)] reach Windows with status=$($script.status), abort process"
            $global:CodeResults=500
            WriteLog -Message $global:MessageResults -MessageType Error -Verbose
            Update-JobStatus $jobfile $json $script "fail" $global:MessageResult
            Out-Windows 
        }        
    }
    #Running script if status is ready, yes I know that can be run on same previous step but this is more human readeable 
    #it is expected that status already exist at this point
    foreach ($script in ($json.JOBREQUEST.ExecuteScript | Sort-Object -Property id)) { 
        if (($script.status.Trim().ToLower() -eq "ready") -AND (($null -ne $script.Environment) -AND ($script.Environment.Tolower() -eq "windows"))) { 
            $RemotePath=(Split-Path $script.FullName -Parent)
            $ScriptName=(Split-Path $script.FullName -Leaf)
            $DirectoryName=(Split-Path -Path $RemotePath -Leaf)
            $LocalPath=(Join-Path $OSDrive "\system.sav\Util\CustomScripts\$($DirectoryName)")
            WriteLog -Message "Preparing script id#$($script.id), $($ScriptName)" -Verbose
            $ExecuteScript=Invoke-RunPower -file $script.Tool -Params "$($script.Parameters) $((Join-Path $LocalPath $ScriptName))" -WorkDir $LocalPath -OutFile "$($logs)\ExecuteScript_$($script.id).log" -Verbose
            $ExecutedSuccessfully=$false
            foreach ($valid in $script.ErrorCodes) {
                if ([int]$valid -eq [int]$ExecuteScript) {WriteLog -Message "Error code [$($ExecuteScript)] seems to be expected for script id#[$($script.id)]" -Verbose; $ExecutedSuccessfully=$true;}
            }
            if (-Not($ExecutedSuccessfully)) {
                WriteLog -Message "Error code retuned [$($ExecuteScript)] for script id#$($script.id) file: $($ScriptName) is not expected, abort process" -MessageType Error -Verbose
                $global:MessageResults="Error code retuned [$($ExecuteScript)] for script id#$($script.id) file: $($ScriptName) is not expected, abort process"
                $global:CodeResults=$ExecuteScript
                Update-JobStatus $jobfile $json $script "fail" $global:MessageResult
                Out-Windows 
            }
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
            Update-JobStatus $jobfile $json $script "fail" $global:MessageResult
            Out-Windows 
        } 
    }

} else {
    WriteLog -Message "This module is not required" -Verbose
}
