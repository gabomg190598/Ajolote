function Exit-FSCode($exitcode) {
    WriteLog -Message "`t <------------- FSPostProcessingMode exit code: [$($exitcode)]" -Verbose
    try {        
        if ($null -ne $global:OnScreenProcess) {
            WriteLog -Message "`t----Checking if splash screen is running..." -Verbose
            $CheckSplashProcess = Get-Process -Id $global:OnScreenProcess.Id -ErrorAction SilentlyContinue
            if ($null -ne $CheckSplashProcess) {
                WriteLog -Message "Closing OnScreen gui process, selected by ID: $($global:OnScreenProcess.Id)" -Verbose
                Stop-Process -Id $global:OnScreenProcess.Id -Force -ErrorAction SilentlyContinue
            }            
        } elseif ($null -ne (Get-Process -Name $global:OnScreenName -ErrorAction SilentlyContinue)) {
            WriteLog -Message "`t----Detected splash screen running..." -Verbose
            foreach ($proc in (Get-Process -Name $global:OnScreenName)) {
                WriteLog -Message "Closing OnScreen gui process, found by ID: $($proc.Id)" -Verbose
                Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            }
        }     
    }
    catch {
        Write-Warning "Failed Exit FS function"
    }
    Push-Location -Path (Get-Item -Path '.\' -Verbose).FullName
    Exit-PostProcessing $exitcode;;
    #$host.SetShouldExit($exitcode)
    #exit $exitcode
}