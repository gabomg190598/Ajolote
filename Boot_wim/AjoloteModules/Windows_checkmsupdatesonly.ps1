<###################################################
            APPLY MS UPDATES
####################################################>
if (($null -ne $json.JOBREQUEST.TestUpdates) -OR ($null -ne $json.JOBREQUEST.CheckMSUpdates)) { 
    $ContinueProcess=$false
#---Check status of test updates
    if ($null -ne $json.JOBREQUEST.TestUpdates) {
        WriteLog -Message "TEST MS Updates detected node" -Verbose
        WriteLog -Message "Current status of job is $($json.JOBREQUEST.TestUpdates.status)" -Verbose
        if ($json.JOBREQUEST.TestUpdates.status.ToLower() -eq "processing") {
            WriteLog -Message "Status expected, processing..." -Verbose
            $ContinueProcess=$true
        } else {
            WriteLog -Message "Status not expected, return to WinPE environment without changes" -Verbose
            $global:MessageResults="Status not expected, return to WinPE environment without changes"
            $global:CodeResults=2
            Out-Windows
        }
    }
#---Check status of Check updates
    if ($null -ne $json.JOBREQUEST.CheckMSUpdates) {
        WriteLog -Message "CHECK MS Updates detected node" -Verbose
        WriteLog -Message "Current status of job is [$($json.JOBREQUEST.CheckMSUpdates.status)]" -Verbose
        if ($json.JOBREQUEST.CheckMSUpdates.status.ToLower() -eq "processing") {
            WriteLog -Message "Check MS Updates" -Verbose
            $ContinueProcess=$true
        } elseif ($json.JOBREQUEST.CheckMSUpdates.status.ToLower() -eq "pass") {
            WriteLog -Message "Updates was already applied, continue process" -Verbose
        } elseif ($json.JOBREQUEST.CheckMSUpdates.status.ToLower() -eq "fail") {
            WriteLog -Message "Updates was already applied and failed, this must return to WinPE and discard current image" -MessageType Error -Verbose
            $global:MessageResults="Not expected to reach Windows configuration without job file"
            $global:CodeResults=3
            Out-Windows
        } elseif ($json.JOBREQUEST.CheckMSUpdates.status.ToLower() -eq "new") {
            WriteLog -Message "For unknown reason request CheckMSUpdates was ignored or not completed on WinPE environment, return as error" -MessageType Error -Verbose
            $global:MessageResults="For unknown reason request CheckMSUpdates was ignored or not completed on WinPE environment, return as error"
            $global:CodeResults=4
            Out-Windows
        } else {
            WriteLog -Message "Check MS Updates was not expected to recibe status: $($json.JOBREQUEST.CheckMSUpdates.status)" -MessageType Warning -Verbose
        }
    }
    if ($ContinueProcess) {
        #Install pending updates
        WriteLog -Message "Validating available updates to install" -Verbose
        $ResulUpdates= MSUpdates -Path "$($env:SystemDrive)\system.sav\util\MSUpdates" -WSUS2 "$($env:SystemDrive)\system.sav\util\MSUpdates\wsusscn2.cab" -Logs $logs -RemoveSuccess $true -Verbose
        if ($ResulUpdates -eq 3010) {
            WriteLog -Message "It is required reboot the unit before to continue" -MessageType Warning -Verbose
            $global:MessageResults="It require reboot to continue on Windows"
            $global:CodeResults=3010
            Out-Windows
        }
        if ($ResulUpdates -ne 0) {
            WriteLog -Message "Unexpected Microsoft update result, back to WinPE" -MessageType Error -Verbose
            $global:MessageResults="Unexpected error during Microsoft updates installation - Windows"
            $global:CodeResults=$ResulUpdates
            if ($null -ne $json.JOBREQUEST.TestUpdates) {                
                Update-JobStatus $jobfile $json $json.JOBREQUEST.TestUpdates "fail" $global:MessageResults
            }
            if ($null -ne $json.JOBREQUEST.CheckMSUpdates) {                
                Update-JobStatus $jobfile $json $json.JOBREQUEST.CheckMSUpdates "fail" $global:MessageResults
            }
            Out-Windows
        }
        WriteLog -Message "Create report of KBs required" -Verbose
        $ReqUpdates = OfflineWsus -WSUS2 "$($env:SystemDrive)\system.sav\util\MSUpdates\wsusscn2.cab" -Report "$($env:SystemDrive)\system.sav\logs\wsusreport.ini" -Verbose
        if ($ReqUpdates -gt 0) {
            WriteLog -Message "It require $($ReqUpdates) updates" -MessageType Warning -Verbose
            $global:MessageResults="It require $($ReqUpdates) updates"
            $global:CodeResults=0
            if ($null -ne $json.JOBREQUEST.TestUpdates) {                
                Update-JobStatus $jobfile $json $json.JOBREQUEST.TestUpdates "fail" $global:MessageResults
            }
            if ($null -ne $json.JOBREQUEST.CheckMSUpdates) {
                Update-JobStatus $jobfile $json $json.JOBREQUEST.CheckMSUpdates "fail" $global:MessageResults
            }
            WriteLog -Message "Swap OS and go to WinPE" -Verbose
            Out-Windows
        } else {
            WriteLog -Message "MS Updates applied are correctly for this OS" -Verbose
            if ($null -ne $json.JOBREQUEST.TestUpdates) {                
                Update-JobStatus $jobfile $json $json.JOBREQUEST.TestUpdates "pass" "MS Updates applied are correctly"
            }
            if ($null -ne $json.JOBREQUEST.CheckMSUpdates) {
                Update-JobStatus $jobfile $json $json.JOBREQUEST.CheckMSUpdates "pass" "MS Updates applied are correctly"
            }
            if ($null -ne $json.JOBREQUEST.TestUpdates) {
                WriteLog -Message "Test MS Updates require to back WinPE at this point" -Verbose
                $global:MessageResults="Updates applied are correctly for this OS"
                $global:CodeResults=0
                Out-Windows
            }
        }
    }
} else {
    WriteLog -Message "Not required this module, continue" -Verbose
}
