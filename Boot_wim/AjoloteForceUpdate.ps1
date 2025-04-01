Write-Host "      [][][][][]==   AJOLOTE FORCE SYNC PROCESS   ==[][][][][]" 
Write-Host "This will sync server respository with current solution removing and overwriting current Ajolote drive"
Write-Host ""
if ($null -eq $global:envDrive) {
    $AjoloteDrive=(Get-Volume | Where-Object {$_.FileSystemLabel -eq "AJOLOTE" }).DriveLetter
    $AjoloteDrive="$($AjoloteDrive):"
    $global:envDrive = $AjoloteDrive
    $global:envPath = $PSScriptRoot
}
[int]$ConfCode = Get-Random -Minimum 100 -Maximum 999
[int]$ValCode = Read-Host -Prompt "Please type confirmation code[$($ConfCode)]"
if ($ConfCode -eq $ValCode) {
    [xml]$con = Get-Content (Join-Path $PSScriptRoot "config.xml")
    Write-Host "Trying to mount version path: \\$($con.AJOLOTE.servername)$($con.AJOLOTE.versionpath)"
    if ($null -ne (Get-Variable -Name MounVer -ErrorAction SilentlyContinue)) { Remove-Variable -Name MounVer -Force -ErrorAction SilentlyContinue }
    [string]$MounVer = (Invoke-MountServer -MounParameter "/versionpath")
    Write-Host "Drive for Version Path: [$($MounVer)]"
    if (($null -ne $MounVer) -AND ($MounVer.Length -eq 2)) {
        Write-Host "Updating Solution, please wait"
        $UpdateSolution = Start-Process -FilePath "Robocopy.exe" -ArgumentList "$($MounVer) $($AjoloteDrive) /MIR" -WorkingDirectory $PSScriptRoot -NoNewWindow -Wait -PassThru
        if (($UpdateSolution.ExitCode -eq 0) -OR ($UpdateSolution.ExitCode -eq 1) -OR ($UpdateSolution.ExitCode -eq 2) -OR ($UpdateSolution.ExitCode -eq 3) -OR ($UpdateSolution.ExitCode -eq 4) -OR ($UpdateSolution.ExitCode -eq 5)) {
            Write-Host "Restoring Config and Cred files"
            Copy-Item -Path (Join-Path $PSScriptRoot "config.xml") -Destination (Join-Path $AjoloteDrive "config.xml") -Force | Out-Host
            Copy-Item -Path (Join-Path $PSScriptRoot "cred.xml") -Destination (Join-Path $AjoloteDrive "cred.xml") -Force | Out-Host
            Write-Host "[WARNING] Unit require reboot"
            Restart-Computer -Force
            Start-Sleep -Seconds 60
            wpeutil reboot
            Exit 3010
        }
        else {
            Write-Host "[ERROR] Somenthing failed during update, robocopy return unexpected code: $($UpdateSolution.ExitCode)"
            Start-Sleep -Seconds 30
        }
    }
    else {
        Write-Host "Mounted drive seems to be incorrect, try again later"
        Start-Sleep -Seconds 20
    }    
} else {
    Write-Host "[WARNING]Confirmation code is incorrect, abort process"
    Start-Sleep -Seconds 15
}