#also same code is used on Last Reboot script, in case of change something here please update Last Reboot script as well
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
    
        
} else {
    WriteLog -Message "Module not required, continue" -Verbose
}