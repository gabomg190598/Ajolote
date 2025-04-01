if ($null -ne $json.JOBREQUEST.Control) { 
    WriteLog -Message "Control process detected, sending last reboot" -Verbose    
    if ($null -eq $json.JOBREQUEST.Control.lastreboot) {
        $json.JOBREQUEST.Control | Add-Member -Name "lastreboot" -MemberType NoteProperty -Value $true
        ### Save JOB file
        try {
            $json | ConvertTo-Json -Depth 16 | Out-File -FilePath $jobfile -Encoding ascii -Force
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            WriteLog -Message "Failed updating JOB file: $($ErrorMessage)" -MessageType Error -Verbose
            $global:MessageResults="Failed updating JOB file: $($ErrorMessage)"
            $global:CodeResults=209
            Out-Windows
        }
        #confirm Product Key and install it
        if (!([string]::IsNullOrEmpty($json.JOBREQUEST.IPK))) { 
            WriteLog -Message "Windows Product Key install was requested" -Verbose
            
            WriteLog -Message "Installing Product Key: $($json.JOBREQUEST.IPK)" -Verbose
            $RunSlmgr = Invoke-RunPower -File "cmd.exe" -Params "/c cscript C:\Windows\System32\slmgr.vbs /ipk $($json.JOBREQUEST.IPK)" -WorkDir "C:\Windows\System32" -OutFile "$($logs)\Slmgr_ipk.log" -Verbose
            if ($RunSlmgr -ne 0) {
                WriteLog -Message "Slmgr return unexpected error=$($RunSlmgr), HP CS Post-Processing Mode can't continue" -MessageType Error -Verbose
                $global:MessageResults="Slmgr return unexpected error=$($RunSlmgr), HP CS Post-Processing Mode can't continue"
                $global:CodeResults=$RunSlmgr
                Out-Windows
            }
            WriteLog -Message "Product Key was installed successfully" -Verbose
            WriteLog -Message "Creating CSPK flag for installing during PP" -Verbose
            try {
                $json.JOBREQUEST.IPK | Out-File -FilePath "C:\System.sav\flags\CSPK.flg" -Encoding ascii -NoNewline -Force -ErrorAction Stop 
                if (Test-Path -Path "C:\System.sav\flags\CSPK.flg" -PathType Leaf) {
                    WriteLog -Message "CSPK flag created successfully [$(Get-Content -Path 'C:\System.sav\flags\CSPK.flg' -Raw -Encoding ascii)]" -Verbose
                } else {
                    WriteLog -Message "Was not possible add Product Key to CSPK.flg" -MessageType Error -Verbose
                }
            }
            catch {
                WriteLog -Message "Was not possible add Product Key to CSPK.flg" -MessageType Error -Verbose
            }
                
        }
        WriteLog -Message "Last reboot to apply changes" -MessageType Error -Verbose
        $global:MessageResults="Last reboot to apply changes"
        $global:CodeResults=3010
        Out-Windows
    } else {
        WriteLog -Message "Already reboot unit, continue process" -Verbose
    }
    
} elseif ($null -ne $json.JOBREQUEST.Job) {
    WriteLog -Message "Job process detected, sending last reboot" -Verbose
    if ($null -eq $json.JOBREQUEST.Job.lastreboot) {
        $json.JOBREQUEST.Job | Add-Member -Name "lastreboot" -MemberType NoteProperty -Value $true
        ### Save JOB file
        try {
            $json | ConvertTo-Json -Depth 16 | Out-File -FilePath $jobfile -Encoding ascii -Force
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            WriteLog -Message "Failed updating JOB file: $($ErrorMessage)" -MessageType Error -Verbose
            $global:MessageResults="Failed updating JOB file: $($ErrorMessage)"
            $global:CodeResults=209
            Out-Windows
        }
        #confirm Product Key and install it
        if (!([string]::IsNullOrEmpty($json.JOBREQUEST.IPK))) { 
            WriteLog -Message "Windows Product Key install was requested" -Verbose
            
            WriteLog -Message "Installing Product Key: $($json.JOBREQUEST.IPK)" -Verbose
            $RunSlmgr = Invoke-RunPower -File "cmd.exe" -Params "/c cscript C:\Windows\System32\slmgr.vbs /ipk $($json.JOBREQUEST.IPK)" -WorkDir "C:\Windows\System32" -OutFile "$($logs)\Slmgr_ipk.log" -Verbose
            if ($RunSlmgr -ne 0) {
                WriteLog -Message "Slmgr return unexpected error=$($RunSlmgr), HP CS Post-Processing Mode can't continue" -MessageType Error -Verbose
                $global:MessageResults="Slmgr return unexpected error=$($RunSlmgr), HP CS Post-Processing Mode can't continue"
                $global:CodeResults=$RunSlmgr
                Out-Windows
            }
            WriteLog -Message "Product Key was installed successfully" -Verbose
                
        }
        WriteLog -Message "Last reboot to apply changes in progress" -Verbose
        $global:MessageResults="Last reboot to apply changes"
        $global:CodeResults=3010
        Out-Windows
    } else {
        WriteLog -Message "Already reboot unit, continue process" -Verbose
    }
}

