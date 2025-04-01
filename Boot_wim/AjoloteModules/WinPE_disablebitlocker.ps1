if (($null -ne $json.JOBREQUEST.DisableBitlocker) -AND ($json.JOBREQUEST.DisableBitlocker)) { 
    WriteLog -Message "Disable Auto Drive Encryption Bitlocker" -Verbose
    WriteLog -Message "Mounting Hive" -Verbose
    $MountHive=Invoke-RunPower -File "cmd.exe" -Params "/c reg load HKLM\HPSystem ""$($OSDrive)\Windows\System32\config\SYSTEM""" -WorkDir $PSScriptRoot -OutFile "$($CGLOGS)\MountReg.log";
    if ($MountHive -ne 0) {
        WriteLog -Message "Not possible mount Hive registry, updating BitLocker request fail" -MessageType Error -Verbose
        $global:MessageResults="Not possible mount Hive registry, updating BitLocker request fail"
        $global:CodeResults=$MountHive
        if ($null -ne $json.JOBREQUEST.Job) { 
            Update-JobStatus $jobfile $json $json.JOBREQUEST.Job "fail" $global:MessageResults
        } elseif ($null -ne $json.JOBREQUEST.Control) {
            Update-JobStatus $jobfile $json $json.JOBREQUEST.Control "fail" $global:MessageResults
        }  
        Out-WinPE -Backuplogs -RemoveJob
    }
    try {
        WriteLog -Message "Creating registry key" -Verbose
        New-ItemProperty -Path HKLM:\HPSystem\ControlSet001\Control\BitLocker -Name PreventDeviceEncryption -PropertyType DWord -Value 1 -Force | Out-File -FilePath (Join-Path $logs "_BuildImage.log") -Encoding ascii -Append -Force
        WriteLog -Message "key created: ControlSet001\Control\BitLocker\PreventDeviceEncryption = 1" -Verbose
    }
    catch {
        WriteLog -Message "Not possible update registry key with value for ADE Bitlocker: $($_.Exception.Message)" -MessageType Error -Value
        $global:MessageResults="Not possible update registry key with value for ADE Bitlocker: $($_.Exception.Message)"
        $global:CodeResults=101
        if ($null -ne $json.JOBREQUEST.Job) { 
            Update-JobStatus $jobfile $json $json.JOBREQUEST.Job "fail" $global:MessageResults
        } elseif ($null -ne $json.JOBREQUEST.Control) {
            Update-JobStatus $jobfile $json $json.JOBREQUEST.Control "fail" $global:MessageResults
        }  
        Out-WinPE -Backuplogs -RemoveJob

    }
    WriteLog -Message "Unmounting registry hive" -Verbose
    $maxretry=10
    $retrycount=0
    $SuccessUnmount=$false
    [gc]::Collect()
    Start-Sleep 2
    While (!($SuccessUnmount)) {
        $retrycount++
        $UnMountReg = Invoke-RunPower -File "cmd.exe" -Params "/c reg unload HKLM\HPSystem" -WorkDir $PSScriptRoot -OutFile "$($CGLOGS)\UnMountReg.log";
        if ($UnMountReg -ne 0) { 
            WriteLog -Message "Not successfully unmount registry[$($UnMountReg)], start sleep 6 secs and try again" -MessageType Warning -Verbose;
            Start-Sleep -Seconds 6
        } else {
            $SuccessUnmount=$true
            WriteLog -Message "Successfully unmounted registry" -Verbose
        }
        if ($retrycount -gt $maxretry) {
            WriteLog -Message "Not successfully unmount registry[$($UnMountReg) after several retries" -MessageType Error -Verbose;
            $SuccessUnmount=$true
            $global:MessageResults="Not successfully unmount registry[$($UnMountReg) after several retries"
            $global:CodeResults=$MountHive
            if ($null -ne $json.JOBREQUEST.Job) { 
                Update-JobStatus $jobfile $json $json.JOBREQUEST.Job "fail" $global:MessageResults
            } elseif ($null -ne $json.JOBREQUEST.Control) {
                Update-JobStatus $jobfile $json $json.JOBREQUEST.Control "fail" $global:MessageResults
            }  
            Out-WinPE -Backuplogs -RemoveJob
        }
    }
    WriteLog -Message "DisableBitlocker request was completed successfully" -Verbose
} else {
    WriteLog -Message "Module not required, continue" -Verbose
}