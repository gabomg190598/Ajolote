#################################################################
    ####      Initialize Logs
    ##################################################################
    WriteLog -Message "----------------- HP FS Post-Processing Mode Setup ------------------" -Path $logs -Name "_FSPostProcessingMode.log" -Verbose
    WriteLog -Message "##############################################################################################################" -Verbose
    WriteLog -Message "#########`t`tPost-Processing Stage: $($CurrentStageFolder)" -Verbose
    if (Test-Path (Join-Path (Get-Item -Path '.\' -Verbose).FullName "z_StepDescription.txt")) {
       $GetTXT=Get-Content -Path (Join-Path (Get-Item -Path '.\' -Verbose).FullName "z_StepDescription.txt")
        for ($i = 5; $i -lt $GetTXT.Count; $i++) {
            WriteLog -Message "#########`t$($GetTXT[$i])" -Verbose
        } 
    }    
    WriteLog -Message "##############################################################################################################" -Verbose
    #Hide current script window
    Get-Process -Id $PID -ErrorAction SilentlyContinue | Set-WindowStyle -Style HIDE;
    #################################################################
    ####      KeepAlive Script
    ##################################################################
    "`$WShell = New-Object -Com Wscript.Shell" | Out-File -FilePath "$((Get-Item -Path '.\' -Verbose).FullName)\KeepAlive.ps1" -Append -Encoding default
    "while (1) {`$WShell.SendKeys(""{SCROLLLOCK}""); Get-Process | Where-Object {`$_.Name -like ""*teams*""} | Stop-Process -Force; Get-Process | Where-Object { $_.ProcessName -like ""*sysprep*""} | Stop-Process -Force; Start-Sleep -Seconds 60}" | Out-File -FilePath "$((Get-Item -Path '.\' -Verbose).FullName)\KeepAlive.ps1" -Append -Encoding default
    $keepalive = Start-Process -FilePath "PowerShell.exe" -ArgumentList "-ExecutionPolicy bypass -File ""$((Get-Item -Path '.\' -Verbose).FullName)\KeepAlive.ps1"" -NoProfile -WindowStyle Maximized"  -WindowStyle Hidden -PassThru
    WriteLog -Message "Keep alive script is running $($keepalive.Id)" -Verbose

    #################################################################
    ####      Initialize SplashScreen
    ##################################################################
    "[info]HP FS POST-PROCESSING MODE" | Out-File -FilePath $FSscreenStatusFile -Encoding ascii -NoNewline -Force; 
    $global:OnScreenProcess = Start-Process -FilePath $FSscreen -ArgumentList "/full" -PassThru
