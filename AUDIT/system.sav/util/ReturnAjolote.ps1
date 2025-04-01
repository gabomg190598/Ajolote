$ModulesFolder="$($PSScriptRoot)\CSModules"
[string[]] $CSModules = @(
		"WriteLog",
		"RunPower",
		"RunDism",
		"GetDrive",
		"CreateF11",
		"WDTFunctions",
		"GetDevice",
		"AssLetterAll",
		"MSUpdates",
		"WindowStyle",
		"HPControl",
		"AED_Support",
		"WinPESave"
	)
foreach ($module in $CSModules) {
    if(!(Get-Module $module)) {
        $FindModule = Get-ChildItem -Path $ModulesFolder -Filter "$($module).psm1" -Recurse -file;
        if ($null -ne $FindModule) {
            try { Import-Module $FindModule[0].FullName; Write-Host "<---Loading Module $($module)" -ForegroundColor DarkGray; } catch { $MissingModule+="$($module)," }
        } else {
            Write-Warning "Missing Module: $($module)";
        }
    } else {
        Write-Host "<---Loaded Module $($module)" -ForegroundColor DarkGray;
    }
}
foreach ($module in $CSModules) { if(!(Get-Module $module)) {Write-Host "Not possible found/load required module for $($MyInvocation.MyCommand.Name): $($module)" -ForegroundColor Yellow -BackgroundColor Red;  }}
if ($MissingModule) { Write-Warning "ABORT PROCESS: Missing Modules: $($MissingModule)"; $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown"); exit 104; }
$AjoloteDrive=(Get-Volume | Where-Object {$_.FileSystemLabel -eq "AJOLOTE" }).DriveLetter
if (($null -eq $AjoloteDrive) -OR ($AjoloteDrive.Length -ne 1)) {
    WriteLog -Message "No AJOLOTE partition found" -MessageType Error -Verbose -Name "_ReturnAjolote.log"
    Exit 404
} else {
    $AjoloteDrive="$($AjoloteDrive):"
}

WriteLog -Message "---------------Returning to Ajolote--------------------------------" -Path "$($AjoloteDrive)\" -Name "_ReturnAjolote.log" -Verbose
SwaptOSBoot
<#if (Test-Path "$($AjoloteDrive)\step.stp") {
    WriteLog -Message "Set step.stp to ChangeOS" -Verbose
    "ChangeOS" | Out-File -FilePath "$($AjoloteDrive)\step.stp" -Encoding default -Force
}#>
WriteLog -Message "Reboot Unit" -Verbose
Restart-Computer -Force
