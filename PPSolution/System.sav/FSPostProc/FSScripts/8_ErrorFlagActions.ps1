###############################################################################################################
    #--------------------------------------Error flag found and Stop
    #################################################################################################################
    if (Test-Path $errorflg) {
        WriteLog -Message "A cserror.flg was found: $(Get-Content $errorflg)" -MessageType Warning -Verbose
        WriteLog -Message "While this flag exist, this process can't continue" -MessageType Warning -Verbose
        "[warning]Stop process due Error Flag: $(Get-Content $errorflg)" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force
        "This prompt will be closed in 30sec, use terminal to debug, once is closed a reboot will be perfomed to return Windows Error" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -Append
        Start-Sleep -Seconds 30        
        if ($null -ne $global:OnScreenProcess) {
            WriteLog -Message "Checking if gui is running using saved Id..." -Verbose
            $CheckSplashProcess = Get-Process -Id $global:OnScreenProcess.Id -ErrorAction SilentlyContinue
            if ($null -ne $CheckSplashProcess) {
                WriteLog -Message "Closing Splash window for debug using saved Id" -Verbose
                Stop-Process -Id $global:OnScreenProcess.Id -Force -ErrorAction SilentlyContinue
            }            
        } elseif ($null -ne (Get-Process -Name $global:OnScreenName -ErrorAction SilentlyContinue)) {
            WriteLog -Message "Checking if gui is running using Name..." -Verbose
            foreach ($proc in (Get-Process -Name $global:OnScreenName)) {
                WriteLog -Message "Closing OnScreen gui process, found: $($proc.Id)" -Verbose
                Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            }
        } 
        Start-Process -FilePath "Powershell.exe" -WorkingDirectory (Join-Path $Env:SystemDrive "\System.sav\logs") -WindowStyle Normal -Wait
        Exit-FSCode(25031981)
        #below code never execute
        while (Test-Path $errorflg) { Start-Sleep -Seconds 5 }
        #Stop and restart hta in case that was closed by user
        if ($null -ne $OS.DisplayVersion -AND $OS.DisplayVersion.Length -gt 2) {
            "[info]HP CS Post-Processing Mode for $($OS.Name) $($OS.Architecture) Ver.$($OS.DisplayVersion)" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline
        }
        else {
            "[info]HP CS Post-Processing Mode for $($OS.Name) $($OS.Architecture) Ver.$($OS.Version)" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline
        }
    }