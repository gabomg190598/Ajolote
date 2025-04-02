
<##########################################################
    ADD SYSTEM SCRIPTS - FUNCTIONS
###########################################################>
[string[]]$ScriptFunction = @(
    "CSBuiltimage.Functions.ps1"
)
foreach ($script in $ScriptFunction) {
    try {
        if (-Not(Test-Path -Path "$($ParentStagePath)\CSModules\$($script)" -PathType Leaf)) {
            Write-Error "Missing Module file: $($script)"
        }
        else {
            Import-Module "$($ParentStagePath)\CSModules\$($script)"
            Write-Host "<---Loaded Script: $($script)" -BackgroundColor Black -ForegroundColor Green   
        }             
    }
    catch {
        Write-Error "Not possible load System Script Modules"
    }
}
<##########################################################
                    LOAD MODULES
###########################################################>
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
    if (!(Get-Module $module)) {
        $FindModule = Get-ChildItem -Path (Join-Path $ParentStagePath "CSModules") -Filter "$($module).psm1" -Recurse -file;
        if ($null -ne $FindModule) {
            try { Import-Module $FindModule[0].FullName; Write-Host "<---Loading Module $($module)" -ForegroundColor DarkGray; } catch { $MissingModule += "$($module)," }            
        }
        else {
            Write-Warning "Missing Module: $($module)";
        }
    }
    else {
        Write-Host "<---Loaded Module $($module)" -ForegroundColor DarkGray;
    }
}
foreach ($module in $CSModules) { if (-Not(Get-Module $module)) { Write-Host "Not possible found/load required module for $($MyInvocation.MyCommand.Name): $($module)" -ForegroundColor Yellow -BackgroundColor Red; } }


<##########################################################
                    LOAD HP MODULES
###########################################################>
$ModulesPath=(Join-Path $Env:SystemDrive "\system.sav\Util\HP.PowershellModules\Modules")
[string[]] $HPModules = @(
    "\HP.Private\HP.Private.psm1",
    "\HP.ClientManagement\HP.ClientManagement.psm1"
)
foreach ($hpmod in $HPModules) {
    if (Test-Path (Join-Path $ModulesPath $hpmod)) {
        try { 
            Import-Module (Join-Path $ModulesPath $hpmod); 
            Write-Host "<---Loading HP Module $((Join-Path $ModulesPath $hpmod))" -ForegroundColor DarkGray; 
        } catch { 
            $MissingModule += "$($module)," 
        }            
    } else {
        Write-Warning "Missing Module: $((Join-Path $ModulesPath $hpmod))";
    }
}

#abort if single module is missing
if ($MissingModule.Length -gt 0) { Write-Warning "ABORT PROCESS: Missing Modules: $($MissingModule)"; Exit-FSCode(104); }