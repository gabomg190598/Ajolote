
if ($null -ne $json.JOBREQUEST.CustomizeAudit) {
    if ($null -ne $json.JOBREQUEST.CustomizeAudit.status) {
        WriteLog -Message "Read Status in order to continue: $()" -Verbose
        switch ($json.JOBREQUEST.CustomizeAudit.status) {
            "new" {
                    WriteLog -Message "new status detected, prepare unit for stop in Audit Mode" -Verbose
                    WriteLog -Message "Check Registry to cleaunp"
                    $regkey = (Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run)
                    $regkey.PSObject.Properties | ForEach-Object {
                        if ($_.Value -like "*csbuiltimage.ps1") { 
                            WriteLog -Message "Found RUN on registry for this script, removing: $($_.Name)" -Verbose 
                            Remove-ItemProperty -Name $_.Name -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
                        } 
                    }
                    WriteLog -Message "Create return button" -Verbose
                    "Powershell.exe -ExecutionPolicy bypass -WindowStyle Maximized -File C:\system.sav\util\CSBuiltImage.ps1" | Out-File -FilePath (Join-Path (Join-Path $env:USERPROFILE "Desktop") "ContinueAndSaveImg.cmd") -Encoding ascii -Force
                    $json.JOBREQUEST.CustomizeAudit.status="audit"
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
                    if ($null -ne $json.JOBREQUEST.Job.error) {
                        $json.JOBREQUEST.Job.error="Image Stop in Audit Mode, please customize"
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
                        WriteLog -Message "Update Job on server" -Verbose
                        Invoke-UpdateJob -Verbose
                    } 
                    WriteLog -Message "Close interface" -Verbose
                    Restart-Computer -Force
                    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    Read-Host "Wait while reboot"
                    Exit 
                    break
                }
            "audit" {
                    WriteLog -Message "audit status detected, allow process to continue, remove cmd button" -Verbose
                    if (Test-Path  (Join-Path (Join-Path $env:USERPROFILE "Desktop") "ContinueAndSaveImg.cmd")) {
                        Remove-Item -Path  (Join-Path (Join-Path $env:USERPROFILE "Desktop") "ContinueAndSaveImg.cmd") -Force
                    }
                    $json.JOBREQUEST.CustomizeAudit.status="done"
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
                    if ($null -ne $json.JOBREQUEST.Job.error) {
                        $json.JOBREQUEST.Job.error="Image Now continue to sysprep"
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
                        WriteLog -Message "Update Job on server" -Verbose
                        Invoke-UpdateJob -Verbose
                    }
                    break
                }
            "done" {
                    WriteLog -Message "Process already complete" -Verbose
                    break
                }
            Default {
                WriteLog -Message "Invalid state: $($json.JOBREQUEST.CustomizeAudit.status)" -MessageType Error -Verbose
                break
            }
        }
    
    } else {
        WriteLog -Message "There are no status, incorrect value provided on Job, continue" -MessageType Error -Verbose
    }

} else {
    WriteLog -Message "Module not required" -Verbose 
}
