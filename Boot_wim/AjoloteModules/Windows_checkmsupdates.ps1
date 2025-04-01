<#########################################################################################################
Windows
APPLY Microsoft UPDATES
Last update: 8/20/2023

stages:
    processing
    pass
    fail
    missing
    bl01
    bl02
    bl03
    bl04

##########################################################################################################>
if (($null -ne $json.JOBREQUEST.TestUpdates) -OR ($null -ne $json.JOBREQUEST.CheckMSUpdates)) { 
    $ContinueProcess = $false
    $BlackLotusMitigation = $false
    $scanfile = "$($env:SystemDrive)\system.sav\util\MSUpdates\wsusscn2.cab"
    $UpdatesFile = "Win$($WinVersion).json"
    $UpdatesRepo = "$($env:SystemDrive)\system.sav\util\MSUpdates"
    $UpdatesJson = "$($env:SystemDrive)\system.sav\logs\$($UpdatesFile)"
    $ModulePath = "$($OSDrive)\system.sav\util\MSUpdates\kbupdateModule"
    $KBUpdateModules = "$($env:SystemDrive)\system.sav\util\MSUpdates\kbupdateModuleFolder.json"
    #more variables appears on module installation

    if (Test-Path -Path "$($env:SystemDrive)\system.sav\util\MSUpdates\ExcludeKB.ini" -PathType Leaf) {
        Copy-Item -Path "$($env:SystemDrive)\system.sav\util\MSUpdates\ExcludeKB.ini" -Destination "$($env:SystemDrive)\system.sav\util\ExcludeKB.ini" -Force
        WriteLog -Message "Exclude KBs located and copy to $($env:SystemDrive)\system.sav\util\ExcludeKB.ini" -Verbose
    }
    #---Check status of test updates
    if ($null -ne $json.JOBREQUEST.TestUpdates) {
        WriteLog -Message "TEST MS Updates detected node" -Verbose
        WriteLog -Message "Current status of job is $($json.JOBREQUEST.TestUpdates.status)" -Verbose
        if (($json.JOBREQUEST.TestUpdates.status.ToLower() -eq "processing") -OR ($json.JOBREQUEST.TestUpdates.status.ToLower() -eq "reboot")) {
            WriteLog -Message "Status expected to continue, processing..." -Verbose
            $ContinueProcess = $true
        }
        elseif (
            ($json.JOBREQUEST.TestUpdates.status.ToLower() -eq "bl00") -OR 
            ($json.JOBREQUEST.TestUpdates.status.ToLower() -eq "bl01") -OR 
            ($json.JOBREQUEST.TestUpdates.status.ToLower() -eq "bl02") -OR
            ($json.JOBREQUEST.TestUpdates.status.ToLower() -eq "bl03") -OR
            ($json.JOBREQUEST.TestUpdates.status.ToLower() -eq "bl04")
        ) {
            WriteLog -Message "BlackLotus Mitigation in porgress..." -Verbose
            $BlackLotusMitigation = $true
        }
        elseif ($json.JOBREQUEST.TestUpdates.status.ToLower() -eq "pass") {
            WriteLog -Message "Updates was already applied task marked as pass should be return to WinPE" -Verbose
            $global:MessageResults = "Updates was already applied task marked as pass should be return to WinPE"
            $global:CodeResults = 0
            Out-Windows
        }
        elseif ($json.JOBREQUEST.TestUpdates.status.ToLower() -eq "fail") {
            WriteLog -Message "Updates was already applied, task marked as fail, returning to WinPE" -MessageType Error -Verbose
            $global:MessageResults = "Updates was already applied, task marked as fail, returning to WinPE"
            $global:CodeResults = 1
        }
        elseif ($json.JOBREQUEST.TestUpdates.status.ToLower() -eq "new") {
            WriteLog -Message "Somenthing goes wrong with WinPE, updates was not applied or module was skip" -MessageType Error -Verbose
            $global:MessageResults = "Somenthing goes wrong with WinPE, updates was not applied or module was skip"
            $global:CodeResults = 3
        }
        else {
            WriteLog -Message "Status not expected, return to WinPE environment without changes" -MessageType Error -Verbose
            $global:MessageResults = "Status not expected, return to WinPE environment without changes"
            $global:CodeResults = 2
            Out-Windows
        }
        if (!(Test-Path -Path "$($env:SystemDrive)\system.sav\util\MSUpdates\wsusscn2.cab" -PathType Leaf)) {
            WriteLog -Message "Not located WSUSscn2.cab, cannot validate MSUPdates" -MessageType Error -Verbose
            $global:MessageResults = "Not located WSUSscn2.cab, cannot validate MSUPdates"
            $global:CodeResults = 404
            if ($null -ne $json.JOBREQUEST.TestUpdates) {                
                Update-JobStatus $jobfile $json $json.JOBREQUEST.TestUpdates "fail" $global:MessageResults
            }
            Out-Windows
        }
        else {
            Copy-Item -Path "$($env:SystemDrive)\system.sav\util\MSUpdates\wsusscn2.cab"  -Destination "$($env:SystemDrive)\system.sav\util\wsusscn2.cab" -Force
        }
    }
    #---Check status of Check updates
    if ($null -ne $json.JOBREQUEST.CheckMSUpdates) {
        WriteLog -Message "CHECK MS Updates detected node" -Verbose
        WriteLog -Message "Current status of job is [$($json.JOBREQUEST.CheckMSUpdates.status)]" -Verbose
        if (($json.JOBREQUEST.CheckMSUpdates.status.ToLower() -eq "processing") -OR ($json.JOBREQUEST.CheckMSUpdates.status.ToLower() -eq "reboot")) {
            WriteLog -Message "Checking MS Updates" -Verbose
            $ContinueProcess = $true
            if ((-Not(Test-Path -Path "$($env:SystemDrive)\system.sav\util\MSUpdates\wsusscn2.cab" -PathType Leaf)) -AND (-Not(Test-Path -Path "$($env:SystemDrive)\system.sav\util\wsusscn2.cab" -PathType Leaf))) {
                WriteLog -Message "Not located WSUSscn2.cab, cannot validate MSUPdates" -MessageType Error -Verbose
                $global:MessageResults = "Not located WSUSscn2.cab, cannot validate MSUPdates"
                $global:CodeResults = 404
                if ($null -ne $json.JOBREQUEST.CheckMSUpdates) {                
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.CheckMSUpdates "fail" $global:MessageResults
                }
                Out-Windows            
            }
            elseif ((-Not(Test-Path -Path "$($env:SystemDrive)\system.sav\util\MSUpdates\wsusscn2.cab" -PathType Leaf)) -AND (Test-Path -Path "$($env:SystemDrive)\system.sav\util\wsusscn2.cab" -PathType Leaf)) {
                WriteLog -Message "restoring wsusscn2.cab copy " -Verbose  
                if (-Not(Test-Path -Path "$($env:SystemDrive)\system.sav\util\MSUpdates" -PathType Container)) { New-Item -Path "$($env:SystemDrive)\system.sav\util\MSUpdates" -ItemType Directory -Force | Out-Null }              
                Copy-Item -Path "$($env:SystemDrive)\system.sav\util\wsusscn2.cab"  -Destination "$($env:SystemDrive)\system.sav\util\MSUpdates\wsusscn2.cab" -Force
                if (-Not (Test-Path -Path "$($env:SystemDrive)\system.sav\util\MSUpdates\wsusscn2.cab" -PathType Leaf) ) {
                    WriteLog -Message "Not possible restore wsusscn2.cab to folder: $($env:SystemDrive)\system.sav\util\MSUpdates" -MessageType Error -Verbose
                    $global:MessageResults = "Not possible restore wsusscn2.cab to folder: $($env:SystemDrive)\system.sav\util\MSUpdates"
                    $global:CodeResults = 406
                    Out-Windows
                }
            }
            else {
                WriteLog -Message "wsusscn2.cab detected, creating copy" -Verbose                
                Copy-Item -Path "$($env:SystemDrive)\system.sav\util\MSUpdates\wsusscn2.cab"  -Destination "$($env:SystemDrive)\system.sav\util\wsusscn2.cab" -Force
                if (-Not (Test-Path -Path "$($env:SystemDrive)\system.sav\util\wsusscn2.cab" -PathType Leaf) ) {
                    WriteLog -Message "Not possible to copy wsusscn2.cab to backup folder: $($env:SystemDrive)\system.sav\util\" -MessageType Error -Verbose
                    $global:MessageResults = "Not possible to copy wsusscn2.cab to backup folder: $($env:SystemDrive)\system.sav\util\"
                    $global:CodeResults = 405
                    Out-Windows
                }
            }
                        
        }
        elseif ($json.JOBREQUEST.CheckMSUpdates.status.ToLower() -eq "pass") {
            WriteLog -Message "Updates was already applied, continue process" -Verbose
        }
        elseif ($json.JOBREQUEST.CheckMSUpdates.status.ToLower() -eq "fail") {
            WriteLog -Message "Updates was already applied and failed, this must return to WinPE and discard current image" -MessageType Error -Verbose
            $global:MessageResults = "Not expected to reach Windows configuration without job file"
            $global:CodeResults = 3
            Out-Windows
        }
        elseif ($json.JOBREQUEST.CheckMSUpdates.status.ToLower() -eq "new") {
            WriteLog -Message "For unknown reason request CheckMSUpdates was ignored or not completed on WinPE environment, return as error" -MessageType Error -Verbose
            $global:MessageResults = "For unknown reason request CheckMSUpdates was ignored or not completed on WinPE environment, return as error"
            $global:CodeResults = 4
            Out-Windows
        }
        elseif (
            ($json.JOBREQUEST.CheckMSUpdates.status.ToLower() -eq "bl00") -OR 
            ($json.JOBREQUEST.CheckMSUpdates.status.ToLower() -eq "bl01") -OR 
            ($json.JOBREQUEST.CheckMSUpdates.status.ToLower() -eq "bl02") -OR
            ($json.JOBREQUEST.CheckMSUpdates.status.ToLower() -eq "bl03") -OR
            ($json.JOBREQUEST.CheckMSUpdates.status.ToLower() -eq "bl04")
        ) {
            WriteLog -Message "BlackLotus Mitigation in porgress..." -Verbose
            $BlackLotusMitigation = $true
        }
        else {
            WriteLog -Message "Check MS Updates was not expected to recibe status: $($json.JOBREQUEST.CheckMSUpdates.status)" -MessageType Warning -Verbose
        }
    }

    if ($ContinueProcess) {
        $ModuleName = "kbupdate"
        $PSRepoName = "localkb"
        WriteLog -Message "Validating available updates to install..." -Verbose
        WriteLog -Message "Checking if $($ModuleName) Module is installed..." -Verbose
        #Validate if module is present 
        if (Get-Module -Name "kbupdate*" -ListAvailable) {
            WriteLog -Message "KBUpdate module detected `r`n$(Get-Module -Name "kbupdate*" -ListAvailable)" -Verbose
            Get-Module -Name "kbupdate*" -ListAvailable | Out-Host
        }
        else {
            WriteLog -Message "$($ModuleName) module not detected, try to install" -Verbose
            #validate if PSRepository exist
            if (-Not(Test-Path $ModulePath)) {
                WriteLog -Message "Not possible detect $($ModuleName) module path($($ModulePath)) on this system, abort process" -MessageType Error -Verbose
                $global:MessageResults = "Not possible detect $($ModuleName) module path($($ModulePath)) installed on this system, abort process"
                $global:CodeResults = 404
                Out-Windows
            }            
            WriteLog -Message "Register local repository: $($ModulePath)" -Verbose            
            #Ensure that script policy will allow execution of script module        
            Set-ExecutionPolicy Bypass -Force -Verbose | Out-Host
            #Save current PSModulePath in environment 
            $PSModulePath = $Env:PSModulePath
            WriteLog -Message "Registering new PSModulePath on environment variable: $($PSModulePath)" -Verbose
            $Env:PSModulePath += "$([IO.Path]::PathSeparator)$(Resolve-Path $ModulePath)" 
            WriteLog -Message "Registered: $($Env:PSModulePath)" -Verbose
            if ($null -eq (Get-Module -Name $ModuleName -ListAvailable -Refresh)) {
                WriteLog -Message "local PSRepository doesn't contain required module $($ModuleName)" -MessageType Error -Verbose
                $global:MessageResults = "local PSRepository doesn't contain required module $($ModuleName)"
                $global:CodeResults = 406
                Out-Windows
            }
            #Registering Local PSRepository
            Register-PSRepository -Name $PSRepoName -SourceLocation $ModulePath -PublishLocation $ModulePath -InstallationPolicy Trusted -Verbose | Out-Host
            Get-PSRepository | Out-Host
            if ($null -eq (Get-PSRepository | Where-Object { $_.Name -eq $PSRepoName })) {
                WriteLog -Message "It seems like PSRepository $($PSRepoName) was not registered" -MessageType Error -Verbose
                $global:MessageResults = "It seems like PSRepository $($PSRepoName) was not registered"
                $global:CodeResults = 403
                Out-Windows
            }
            
            WriteLog -Message "Search Module on on registered repository ""$($PSRepoName)""" -Verbose
            $ModulesFound = Find-Module -Repository $PSRepoName
            $RequiredModuleFound = $false
            foreach ($mod in $ModulesFound) {
                WriteLog -Message "Moddule detected: $($mod.Name)" -Verbose
                if ($mod.Name.ToString().ToLower() -eq $ModuleName.ToLower()) {
                    $RequiredModuleFound = $true;
                    WriteLog -Message "`t*This Module is required" -Verbose
                }
            }
            if ($RequiredModuleFound) {
                WriteLog -Message "Installing $($ModuleName)" -Verbose
                Find-Module -Repository $PSRepoName -Name $ModuleName | Install-Module -Verbose
            }
            else {
                WriteLog -Message "Not possible detect $($ModuleName) module on local psrepository" -MessageType Error -Verbose
                $global:MessageResults = "Not possible detect $($ModuleName) module on local psrepository"
                $global:CodeResults = 404
                Out-Windows
            }
            if ($null -eq (Get-Module -Name $ModuleName -ListAvailable -Refresh)) {
                WriteLog -Message "Not possible install $($ModuleName) module from local psrespository" -MessageType Error -Verbose
                $global:MessageResults = "Not possible detect $($ModuleName) module from local psrespository"
                $global:CodeResults = 405
                Out-Windows
            }            
        }
        WriteLog -Message "Searching updates to install from repository: $($UpdatesRepo)" -Verbose
        $exclude = ("*.txt", "*.log", "*.csv", "*.xlsx", "*.ps1", "*.xml", "*.lnk", "wsusscn2.cab", "*.zip", "*.json")
        $validfiles = ("*.msu", "*.cab", "*.exe")

        Push-Location -Path $UpdatesRepo
        if ((Get-ChildItem -Path "$($UpdatesRepo)\*" -File -Include $validfiles -Exclude $exclude | Measure-Object).Count -eq 0) {
            WriteLog -Message "There are no files to install, entering retrieve updates mode" -MessageType Warning -Verbose
            Get-KbNeededUpdate -ScanFilePath $scanfile | ConvertTo-Json | Out-File -FilePath $UpdatesJson -Encoding ascii -Force
            $GetUpdates = Get-Content -Path $UpdatesJson -Raw | ConvertFrom-Json 
            $global:MessageResults = "It require $(($GetUpdates | Measure-Object).Count) more updates"
            $global:CodeResults = 0
            if ($null -ne $json.JOBREQUEST.TestUpdates) {                
                Update-JobStatus $jobfile $json $json.JOBREQUEST.TestUpdates "missing" $global:MessageResults
            }
            if ($null -ne $json.JOBREQUEST.CheckMSUpdates) {
                Update-JobStatus $jobfile $json $json.JOBREQUEST.CheckMSUpdates "missing" $global:MessageResults
            }
            WriteLog -Message "Swap OS and go to back to WinPE" -Verbose
            Out-Windows
        }
        else {
            WriteLog -Message "checking if one of $((Get-ChildItem -Path "$($UpdatesRepo)\*" -File -Include $validfiles -Exclude $exclude | Measure-Object).Count) updates detected work for this OS" -Verbose
            #$JustInstall = @();
            if (Test-Path -Path "$($env:SystemDrive)\system.sav\util\MSUpdates\ExcludeKB.ini" -PathType Leaf) {
                [string[]]$IgnoreKBs = (Get-Content "$($env:SystemDrive)\system.sav\util\MSUpdates\ExcludeKB.ini" | Where-Object { $_.Trim() -ne "" }).ToUpper()
                $ScanUpdates = Get-KbNeededUpdate -ScanFilePath $scanfile                
                $SimplifyObject=@();
                if ($ScanUpdates.Count -gt 0) {
                    $ScanUpdates | ConvertTo-Json -Depth 32 | Out-File -FilePath (Join-Path $logs "KbNeededUpdate_ScanUpdates.json") -Encoding ascii -Force
                    foreach ($item in $ScanUpdates) {
                        if ($IgnoreKBs.Contains($item.KBUpdate)) {
                            WriteLog -Message "Update $($item.KBUpdate) is required but marked as ignored, skip by now" -Verbose                        
                        }
                        else {
                            if ([string]::IsNullOrEmpty($item.Title) -AND ($item.KBUpdate.length -le 2)) {
                                WriteLog -Message "Empty information for update detected, ignored" -MessageType Warning -Verbose
                            } else { 
                                WriteLog -Message "Adding to install $($item.Title)" -Verbose
                                #$Installedkb = $kb | Install-KbUpdate -RepositoryPath $UpdatesRepo
                                #$JustInstall += $Installedkb
                                $arrFiles=@();
                                foreach ($url in $item.Link) { if (-Not([string]::IsNullOrEmpty($url))) { $arrFiles+=(Split-Path $url -Leaf) }; }
                                $addupdate=@{
                                    "ComputerName"=$item.ComputerName
                                    "Title"=$item.Title
                                    "ID"=$item.KBUpdate
                                    "UpdateId"=$item.UpdateId
                                    "MSRCSeverity"=$item.MSRCSeverity
                                    "FileName"=$arrFiles
                                    "Status"= "Required"
                                    "PSComputerName"="localhost"
                                    "PSShowComputerName"= $false
                                }
                                $SimplifyObject+=$addupdate
                            }                           
                        }                        
                    }
                    WriteLog -Message "Updates detected in object: $($SimplifyObject.Count)" -Verbose
                    if ($SimplifyObject.Count -gt 0) {
                        Install-FSUpdate -UpdatesObject $SimplifyObject -RepositoryPath $UpdatesRepo -logs $logs
                        $SimplifyObject | ConvertTo-Json -Depth 32 | Out-File -FilePath (Join-Path $logs "KbNeededUpdate_InstalledKBs.json") -Encoding ascii -Force
                    } else {
                        WriteLog -Message "No Updates required to be installed" -Verbose
                    }
                }
                <#$JustInstall = @();
                foreach ($kb in $ScanUpdates) {
                    if ($IgnoreKBs.Contains($kb.KBUpdate)) {
                        WriteLog -Message "Update $($kb.KBUpdate) is required but marked as ignored, skip by now" -Verbose                        
                    }
                    else {
                        WriteLog -Message "Installing $($kb.Title)" -Verbose
                        $Installedkb = $kb | Install-KbUpdate -RepositoryPath $UpdatesRepo
                        $JustInstall += $Installedkb
                    }
                }
                #>
            }
            else {
                $GetInstall = Get-KbNeededUpdate -ScanFilePath $scanfile #| Install-KbUpdate -RepositoryPath $UpdatesRepo #| Out-File -FilePath (Join-Path $logs "WindowsMSUpdatesAdded.log") -Encoding ascii -Append
                $SimplifyObject=@();
                if ($GetInstall.Count -gt 0) {
                    $GetInstall | ConvertTo-Json -Depth 32 | Out-File -FilePath (Join-Path $logs "KBNeededUpdate_GetInstall.json") -Encoding ascii -Force
                    foreach ($item in $GetInstall) {
                        if ([string]::IsNullOrEmpty($item.Title) -AND ($item.KBUpdate.length -le 2)) {
                            WriteLog -Message "Empty information for update detected, ignored" -MessageType Warning -Verbose
                        } else {
                            WriteLog -Message "Adding for installation: $($item.Title)" -Verbose
                            #$Installedkb = $kb | Install-KbUpdate -RepositoryPath $UpdatesRepo
                            #$JustInstall += $Installedkb
                            ## Here is cimplify object used to install updates
                            $arrFiles=@();
                            foreach ($url in $item.Link) { if (-Not([string]::IsNullOrEmpty($url))) { $arrFiles+=(Split-Path $url -Leaf) }; }
                            $addupdate=@{
                                "ComputerName"=$item.ComputerName
                                "Title"=$item.Title
                                "ID"=$item.KBUpdate
                                "UpdateId"=$item.UpdateId
                                "MSRCSeverity"=$item.MSRCSeverity
                                "FileName"=$arrFiles
                                "Status"= "Required"
                                "PSComputerName"="localhost"
                                "PSShowComputerName"= $false
                            }
                            $SimplifyObject+=$addupdate
                        }                       
                                              
                    }
                    WriteLog -Message "Updates detected in object: $($SimplifyObject.Count)" -Verbose
                    if ($SimplifyObject.Count -gt 0) {
                        Install-FSUpdate -UpdatesObject $SimplifyObject -RepositoryPath $UpdatesRepo -logs $logs
                        $SimplifyObject | ConvertTo-Json -Depth 32 | Out-File -FilePath (Join-Path $logs "KBNeededUpdate_InstalledKBs.json") -Encoding ascii -Force
                    } else {
                        WriteLog -Message "No Updates required to be installed" -Verbose
                    }
                }




                <#
                if ($null -ne $GetInstall) {
                    foreach ($Installedkb in $GetInstall) {
                        $JustInstall += $Installedkb
                    }
                }
                $GetInstall | ConvertTo-Json -Depth 32 | Out-File -FilePath (Join-Path $logs "InstalledKBs.json") -Encoding ascii -Force
                #>
            }
            if (Test-Path -Path (Join-Path $env:SystemDrive "\system.sav\util\MSUpdates\IncludeKB.json")) {
                WriteLog -Message "Detected Include KBs file, merging file" -Verbose
                $ReadIncludeKB = Get-Content -Path (Join-Path $env:SystemDrive "\system.sav\util\MSUpdates\IncludeKB.json") -Raw | ConvertFrom-Json
                WriteLog -Message "Updates detected in object: $($ReadIncludeKB.Count)" -Verbose
                if ($ReadIncludeKB.Count -gt 0) {
                    Install-FSUpdate -UpdatesObject $ReadIncludeKB -RepositoryPath $UpdatesRepo -logs $logs
                    $ReadIncludeKB | ConvertTo-Json -Depth 32 | Out-File -FilePath (Join-Path $logs "KBNeededUpdate_InstalledKBs_Included.json") -Encoding ascii -Force
                } else {
                    WriteLog -Message "No Updates required to be installed" -Verbose
                }
                <#
                if ($null -eq $JustInstall) { $JustInstall = @(); }
                foreach ($addkb in $ReadIncludeKB) {
                    WriteLog -Message "Additional update detected: $($addkb.Title)" -Verbose
                    if (Test-Path -Path (Join-Path $UpdatesRepo $addkb.FileName)) {
                        WriteLog -Message "Adding KB ID: $($addkb.ID)" -Verbose
                        $JustInstall += $addkb;
                    }
                    else {
                        WriteLog -Message "Not possible locate additional update: $((Join-Path $UpdatesRepo $addkb.FileName))" -MessageType Error -Verbose
                        $global:MessageResults = "Not possible locate additional update: $((Join-Path $UpdatesRepo $addkb.FileName))"
                        $global:CodeResults = 404
                        Out-Windows
                    }
                }
                #>
            }
        }
        Pop-Location
        #Get-KbNeededUpdate -ScanFilePath $scanfile 

        <#
        if ($null -ne $JustInstall) {
            foreach ($package in $JustInstall) {
                $extensionfile = ([System.IO.Path]::GetExtension($package.FileName)).ToString().ToLower()
                WriteLog -Message "Installed package: $($package.Title)" -Verbose
                WriteLog -Message "Installed package ID: $($package.ID)" -Verbose
                WriteLog -Message "Installed package file: $($package.FileName)" -Verbose
                WriteLog -Message "Installed package status: $($package.Status)" -Verbose
                $CurrentHotFix = Get-HotFix
                switch ($extensionfile) {
                    ".cab" {
                        WriteLog -Message "Confirming $($package.ID) is installed" -Verbose
                        if ($null -eq ($CurrentHotFix | Where-Object { $_.HotFixID -eq $package.ID })) {
                            WriteLog -Message "Not detected as installed, reinstalling..." -Verbose
                            $InjectUp = RunDism -Params "/online /ScratchDir:$($env:SystemDrive)\ /Add-Package /PackagePath:""$((Join-Path $UpdatesRepo $package.FileName))""" -WorkDir $UpdatesRepo -OutFile "$($Logs)\WinUpdate_$($package.ID).log" -ShowProgress $false	
                            if (($InjectUp -ne 0) -AND ($InjectUp -ne 3010)) { 
                                WriteLog -Message "Failed to install MS Update: $($package.Title), code: $($InjectUp), stop process to review" -MessageType Error -Verbose;                             
                                $global:MessageResults = "Failed to install MS Update: $($package.Title), code: $($InjectUp)"
                                $global:CodeResults = $InjectUp
                                Out-Windows
                            }
                            else {
                                WriteLog -Message "Successfully installed: $($package.Title)" -Verbose
                            }
                        }
                        else {
                            WriteLog -Message "Successfully detected: $($package.Title)" -Verbose
                        }                        
                        break;
                    }
                    ".msu" {
                        WriteLog -Message "Confirming $($package.ID) is installed" -Verbose
                        if ($null -eq ($CurrentHotFix | Where-Object { $_.HotFixID -eq $package.ID })) {
                            WriteLog -Message "Not detected as installed, reinstalling..." -Verbose
                            $InjectUp = Invoke-RunPower -File "wusa.exe" -Params """$((Join-Path $UpdatesRepo $package.FileName))"" /quiet /norestart" -WorkDir $UpdatesRepo -OutFile (Join-Path $logs "WinUpdate_$($package.ID).log")	
                            if (($InjectUp -ne 0) -AND ($InjectUp -ne 3010)) { 
                                WriteLog -Message "Failed to install MS Update: $($package.Title), code: $($InjectUp), stop process to review" -MessageType Error -Verbose;                             
                                $global:MessageResults = "Failed to install MS Update: $($package.Title), code: $($InjectUp)"
                                $global:CodeResults = $InjectUp
                                Out-Windows
                            }
                            else {
                                WriteLog -Message "Successfully installed: $($package.Title)" -Verbose
                            }
                        }
                        else {
                            WriteLog -Message "Successfully detected: $($package.Title)" -Verbose
                        }                        
                        break;
                    }
                    ".exe" {
                        #Checking MRT installed
                        if (($package.Title -like "*Windows Malicious Software Removal Tool*") -OR ($package.ID -eq "KB890830")) {
                            WriteLog -Message """Windows Malicious Software Removal Tool"" just installed, validating application..." -Verbose
                            if (Test-Path -Path "$($env:SystemDrive)\Windows\System32\MRT.exe" -PathType Leaf) {
                                WriteLog -Message "Found MRT.exe, try to execute..." -Verbose
                                $mrt = Start-Process -FilePath "$($env:SystemDrive)\Windows\System32\MRT.exe" -PassThru -ErrorAction SilentlyContinue
                                Start-Sleep -Seconds 10
                                if ($null -eq $mrt) {
                                    WriteLog -Message "It cannot start MRT, install manually: $((Join-Path $UpdatesRepo $package.FileName))" -MessageType Warning -Verbose
                                    $applyMRT = Invoke-RunPower -File "cmd.exe" -Params "/c $((Join-Path $UpdatesRepo $package.FileName)) /Q" -WorkDir $UpdatesRepo -OutFile (Join-Path $logs "WinUpdateMRT.log")
                                    if ($applyMRT -ne 0) {
                                        WriteLog -Message "Not possible install Microsoft Malicious Software Removal Tool" -MessageType Error -Verbose
                                        $global:MessageResults = "Not possible install Microsoft Malicious Software Removal Tool"
                                        $global:CodeResults = $applyMRT
                                        Out-Windows
                                    }
                                }
                                if ($null -ne (Get-Process -Id $mrt.Id -ErrorAction SilentlyContinue)) { Stop-Process -Id $mrt.Id -Force -ErrorAction SilentlyContinue}
                            }
                            else {
                                WriteLog -Message "It cannot detect MRT, install manually: $((Join-Path $UpdatesRepo $package.FileName))" -MessageType Warning -Verbose
                                $applyMRT = Invoke-RunPower -File "cmd.exe" -Params "/c $((Join-Path $UpdatesRepo $package.FileName)) /Q" -WorkDir $UpdatesRepo -OutFile (Join-Path $logs "WinUpdateMRT.log")
                                if ($applyMRT -ne 0) {
                                    WriteLog -Message "Not possible install Microsoft Malicious Software Removal Tool" -MessageType Error -Verbose
                                    $global:MessageResults = "Not possible install Microsoft Malicious Software Removal Tool"
                                    $global:CodeResults = $applyMRT
                                    Out-Windows
                                }
                            }
                        }
                        else {
                            WriteLog -Message "There are no validation for ""$($package.Title )""" -MessageType Warning -Verbose 
                        }
                        break;
                    }
                    Default {
                        WriteLog -Message "Format not supported for install updates: $($_)" -Verbose
                    }
                }
                
            }
        }
        #>
        WriteLog -Message "Check if more updates are required..." -Verbose
        $MoreNeeded = @()
        if (Test-Path -Path "$($env:SystemDrive)\system.sav\util\MSUpdates\ExcludeKB.ini" -PathType Leaf) {
            [string[]]$IgnoreKBs = (Get-Content "$($env:SystemDrive)\system.sav\util\MSUpdates\ExcludeKB.ini" | Where-Object { $_.Trim() -ne "" }).ToUpper()            
            $ScanAgain = Get-KbNeededUpdate -ScanFilePath $scanfile
            if ($ScanAgain.Count -gt 0) {
                $ScanAgain | ConvertTo-Json -Depth 32 | Out-File -FilePath (Join-Path $logs "KBNeededUpdate_ScanAgain.json") -Encoding ascii -Force
                foreach ($kb in $ScanAgain) {
                    if ($IgnoreKBs.Contains($kb.KBUpdate) -OR ([string]::IsNullOrEmpty($kb.KBUpdate)) -OR ($kb.KBUpdate.length -le 2) ) {
                        WriteLog -Message "Update $($kb.Title) will be ignored since appears on ExcludeKBs file or is empty request" -MessageType Warning -Verbose
                    }
                    else {
                        $MoreNeeded += $kb
                    }
                }
            }
            
        }
        else {
            $ScanAgain = Get-KbNeededUpdate -ScanFilePath $scanfile
            if ($ScanAgain.Count -gt 0) {
                $ScanAgain | ConvertTo-Json -Depth 32 | Out-File -FilePath (Join-Path $logs "KBNeededUpdate_ScanAgain.json") -Encoding ascii -Force
                foreach ($kb in $ScanAgain) {
                    if ([string]::IsNullOrEmpty($kb.KBUpdate) -Or ($kb.KBUpdate.length -le 2)) {
                        WriteLog -Message "An empty Update detected, ignore as request" -MessageType Warning -Verbose
                    }
                    else {
                        $MoreNeeded += $kb
                    }
                }
            }
            
            #$MoreNeeded = Get-KbNeededUpdate -ScanFilePath $scanfile
        }
        

        if (($MoreNeeded | Measure-Object).Count -gt 0) {
            #Compare update required vs hotfix due an issue detected when languages are used and wsus didn't report as installed.
            $CurrentHotFix = Get-HotFix
            foreach ($missing in $MoreNeeded) {
                if ($null -ne ($CurrentHotFix | Where-Object { $_.HotFixID -eq $missing.KBUpdate })) {
                    WriteLog -Message "Reported missing update $($missing.KBUpdate) was detected in this image, removing from kbs needed report" -Verbose
                    $MoreNeeded = $MoreNeeded | Where-Object { $_.KBUpdate -ne $missing.KBUpdate }
                }
            }
            if (($MoreNeeded | Measure-Object).Count -gt 0) {                
                WriteLog -Message "It require [$(($MoreNeeded | Measure-Object).Count)] updates" -MessageType Warning -Verbose
                foreach ($missing in $MoreNeeded) {
                    WriteLog -Message "Missing update: $($missing.Title)" -Verbose
                    WriteLog -Message "`t`tMissing KB: $($missing.KBUpdate)" -Verbose
                    foreach ($misslink in $MoreNeeded.Link) {
                        WriteLog -Message "`t`t`tMissing File: $($misslink)" -Verbose
                    }                    
                }
                $global:MessageResults = "It require $(($MoreNeeded | Measure-Object).Count) more updates"
                if ((($null -ne $json.JOBREQUEST.TestUpdates.status -AND $json.JOBREQUEST.TestUpdates.status.ToLower() -eq "reboot")) -OR (($null -ne $json.JOBREQUEST.CheckMSUpdates.status -AND $json.JOBREQUEST.CheckMSUpdates.status.ToLower() -eq "reboot"))) { 
                    $MoreNeeded | ConvertTo-Json | Out-File -FilePath $UpdatesJson -Encoding ascii -Force
                    Copy-Item -Path $UpdatesJson -Destination (Join-Path $Logs $UpdatesFile) -Force
                    $global:CodeResults = 0
                    if ($null -ne $json.JOBREQUEST.TestUpdates) {                
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.TestUpdates "missing" $global:MessageResults
                    }
                    if ($null -ne $json.JOBREQUEST.CheckMSUpdates) {
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.CheckMSUpdates "missing" $global:MessageResults
                    }
                    WriteLog -Message "Swap OS and go to back to WinPE" -Verbose
                }
                else { 
                    $global:CodeResults = 3010
                    if ($null -ne $json.JOBREQUEST.TestUpdates) {                
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.TestUpdates "reboot" $global:MessageResults
                    }
                    if ($null -ne $json.JOBREQUEST.CheckMSUpdates) {
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.CheckMSUpdates "reboot" $global:MessageResults
                    }
                    WriteLog -Message "Reboot and try again" -Verbose
                }                
                Out-Windows
            }                
        }
        ###### Retrieve Installed KBs
        WriteLog -Message "MS Updates applied are correctly for this OS, retrieve current Hot fixes to include on job" -Verbose
        $hotfix = [System.Collections.ArrayList]@()
        foreach ($hot in Get-HotFix) { $hotfix.Add($hot.HotFixID) | out-null }
        #Remove kbupdate module
        Get-InstalledModule -Name $ModuleName -ErrorAction SilentlyContinue | Uninstall-Module -Force -ErrorAction SilentlyContinue
        WriteLog -Message "Remove local repository" -Verbose
        Unregister-PSRepository -Name $PSRepoName
        $Env:PSModulePath = $PSModulePath
        if ($null -ne $json.JOBREQUEST.TestUpdates) {       
            if ($null -eq $json.JOBREQUEST.TestUpdates.HotFixID) {
                $json.JOBREQUEST.TestUpdates | Add-Member -Name "HotFixID" -MemberType NoteProperty -Value $hotfix
            }
            else {
                $json.JOBREQUEST.TestUpdates.HotFixID = $hotfix
            }
            if ($null -eq $json.JOBREQUEST.TestUpdates.BuildVer) {
                $json.JOBREQUEST.TestUpdates | Add-Member -Name "BuildVer" -MemberType NoteProperty -Value "$($OS.Build).$($OS.Revision)"
            }
            else {
                $json.JOBREQUEST.TestUpdates.BuildVer = "$($OS.Build).$($OS.Revision)"
            }                  
        }
        if ($null -ne $json.JOBREQUEST.CheckMSUpdates) {
            if ($null -eq $json.JOBREQUEST.CheckMSUpdates.HotFixID) {
                $json.JOBREQUEST.CheckMSUpdates | Add-Member -Name "HotFixID" -MemberType NoteProperty -Value $hotfix
            }
            else {
                $json.JOBREQUEST.CheckMSUpdates.HotFixID = $hotfix
            }
            if ($null -eq $json.JOBREQUEST.CheckMSUpdates.BuildVer) {
                $json.JOBREQUEST.CheckMSUpdates | Add-Member -Name "BuildVer" -MemberType NoteProperty -Value "$($OS.Build).$($OS.Revision)"
            }
            else {
                $json.JOBREQUEST.CheckMSUpdates.BuildVer = "$($OS.Build).$($OS.Revision)"
            }
            
        }
        ###### Validate minimum version of

        ###### Trigger Reboot for BlackLotus revocations
        WriteLog -Message "Reboot for minimum version validation" -Verbose
        $global:MessageResults = "Reboot for minimum version validation"
        if ($null -ne $json.JOBREQUEST.TestUpdates) {                
            Update-JobStatus $jobfile $json $json.JOBREQUEST.TestUpdates "bl00" $global:MessageResults
        }
        if ($null -ne $json.JOBREQUEST.CheckMSUpdates) {
            Update-JobStatus $jobfile $json $json.JOBREQUEST.CheckMSUpdates "bl00" $global:MessageResults
        }
        $global:CodeResults = 3010
        Out-Windows
    }

    if ($BlackLotusMitigation) {
        ## Used to validate minimum version of Windows, it is not possible to release an old Windows
        if (
            (($null -ne $json.JOBREQUEST.TestUpdates.status -AND $json.JOBREQUEST.TestUpdates.status.ToLower() -eq "bl00")) -OR 
            (($null -ne $json.JOBREQUEST.CheckMSUpdates.status -AND $json.JOBREQUEST.CheckMSUpdates.status.ToLower() -eq "bl00"))
        ) {
            if (Test-Path -Path (Join-Path $UpdatesRepo "MinimumOSRevision.json")) {
                $CurrentBuildTable = @{}
                $OSTablejson = Get-Content -Path (Join-Path $UpdatesRepo "MinimumOSRevision.json") -Raw | ConvertFrom-Json | Select-Object -ExpandProperty WindowsBuild
                $OSTablejson.psobject.properties | ForEach-Object { $CurrentBuildTable[$_.Name] = $_.Value }
            }
            else {
                $CurrentBuildTable = @{
                    "22631" = "2715" # W11 23H2, KB5032190
                    "22621" = "1992" # W11 22H2, KB5028185
                    "22000" = "2176" # W11 21H2, KB5028182
                    "19045" = "3208" # W10 22H2, KB5028166
                    "19044" = "3208" # W10 21H2, KB5028166
                    "17763" = "4645" # W10 1809 LTSC, KB5028168
                    "14393" = "6085" # W10 1607 LTSC, KB5028169
                    "10240" = "20048" # W10 1507 LTSC, KB5028186
                }
            }
            
            $ValidOS = $true
            if ($CurrentBuildTable.Contains("$($OS.Build)")) {
                WriteLog -Message "Minimum revision for Windows version $($OS.Build) is [$($CurrentBuildTable[$OS.Build])]" -Verbose
                WriteLog -Message "Current revision is [$($OS.Revision)]" -Verbose
                If ($OS.Revision -lt $CurrentBuildTable[$OS.Build]) { 
                    WriteLog -Message "This OS has not meet minimum updates required to be released." -MessageType Error -Verbose; 
                    $ValidOS = $false 
                }
            }
            else {
                WriteLog -Message "This OS is not currenlty supported: $($OS.Build)." -MessageType Error -Verbose; 
                $ValidOS = $false
            }

            if ($ValidOS) {
                WriteLog -Message "Operating System meets with minimum version to be released: $($OS.Build).$($OS.Revision), BlackLotus mitigation step 3a-1" -Verbose
            }
            else {
                WriteLog -Message "Not possible release this version of OS:  $($OS.Build).$($OS.Revision), please check updates and reason why is old one" -MessageType Error -Verbose
                $global:MessageResults = "Not possible release this version of OS:  $($OS.Build).$($OS.Revision), please check updates and reason why is old one"
                $global:CodeResults = -2
                Out-Windows
            }
        } #end of bl00

        ### Removed on Oct.2023
        ## BlackLotus Revocations step 3a and 3b
        if (
            (($null -ne $json.JOBREQUEST.TestUpdates.status -AND $json.JOBREQUEST.TestUpdates.status.ToLower() -eq "bl01")) -OR 
            (($null -ne $json.JOBREQUEST.CheckMSUpdates.status -AND $json.JOBREQUEST.CheckMSUpdates.status.ToLower() -eq "bl01"))
        ) {
            if (Test-Path -Path (Join-Path $UpdatesRepo "MinimumOSRevision.json")) {
                $CurrentBuildTable = @{}
                $OSTablejson = Get-Content -Path (Join-Path $UpdatesRepo "MinimumOSRevision.json") -Raw | ConvertFrom-Json | Select-Object -ExpandProperty WindowsBuild
                $OSTablejson.psobject.properties | ForEach-Object { $CurrentBuildTable[$_.Name] = $_.Value }
            }
            else {
                $CurrentBuildTable = @{
                    "22631" = "2715" # W11 23H2, KB5032190
                    "22621" = "1992" # W11 22H2, KB5028185
                    "22000" = "2176" # W11 21H2, KB5028182
                    "19045" = "3208" # W10 22H2, KB5028166
                    "19044" = "3208" # W10 21H2, KB5028166
                    "17763" = "4645" # W10 1809 LTSC, KB5028168
                    "14393" = "6085" # W10 1607 LTSC, KB5028169
                    "10240" = "20048" # W10 1507 LTSC, KB5028186
                }
            }
            
            $ValidOS = $true
            if ($CurrentBuildTable.Contains("$($OS.Build)")) {
                WriteLog -Message "Minimum revision for Windows version $($OS.Build) is [$($CurrentBuildTable[$OS.Build])]" -Verbose
                WriteLog -Message "Current revision is [$($OS.Revision)]" -Verbose
                If ($OS.Revision -lt $CurrentBuildTable[$OS.Build]) { 
                    WriteLog -Message "This OS has not meet minimum updates required to be released." -MessageType Error -Verbose; 
                    $ValidOS = $false 
                }
            }
            else {
                WriteLog -Message "This OS is not currenlty supported: $($OS.Build)." -MessageType Error -Verbose; 
                $ValidOS = $false
            }
            <#switch ($OS.Build) {
                22621 { If ($OS.Revision -lt $CurrentBuildTable["$OS.Build"]){ WriteLog -Message "This OS has not meet minimum updates required to be released." -MessageType Error -Verbose; $ValidOS=$false } }
                22000 { If ($OS.Revision -lt $CurrentBuildTable["$OS.Build"]){ WriteLog -Message "This OS has not meet minimum updates required to be released." -MessageType Error -Verbose; $ValidOS=$false } }
                19045 { If ($OS.Revision -lt $CurrentBuildTable["$OS.Build"]){ WriteLog -Message "This OS has not meet minimum updates required to be released." -MessageType Error -Verbose; $ValidOS=$false } }
                19044 { If ($OS.Revision -lt $CurrentBuildTable["$OS.Build"]){ WriteLog -Message "This OS has not meet minimum updates required to be released." -MessageType Error -Verbose; $ValidOS=$false } }
                17763 { If ($OS.Revision -lt $CurrentBuildTable["$OS.Build"]){ WriteLog -Message "This OS has not meet minimum updates required to be released." -MessageType Error -Verbose; $ValidOS=$false } }
                14393 { If ($OS.Revision -lt $CurrentBuildTable["$OS.Build"]){ WriteLog -Message "This OS has not meet minimum updates required to be released." -MessageType Error -Verbose; $ValidOS=$false } }
                10240 { If ($OS.Revision -lt $CurrentBuildTable["$OS.Build"]){ WriteLog -Message "This OS has not meet minimum updates required to be released." -MessageType Error -Verbose; $ValidOS=$false } }
                Default { WriteLog -Message "This OS is not supported: $($OS.Build)." -MessageType Error -Verbose; $ValidOS=$false } 
            }#>
            
            if ($ValidOS) {
                WriteLog -Message "Operating System meets with minimum version to be released: $($OS.Build).$($OS.Revision), BlackLotus mitigation step 3a-1" -Verbose
            }
            else {
                WriteLog -Message "Not possible release this version of OS:  $($OS.Build).$($OS.Revision), please check updates and reason why is old one" -MessageType Error -Verbose
                $global:MessageResults = "Not possible release this version of OS:  $($OS.Build).$($OS.Revision), please check updates and reason why is old one"
                $global:CodeResults = -2
                Out-Windows
            }
            $Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Secureboot\"
            $ValueName = "AvailableUpdates"
            $Value = 48
            if (-Not(Test-Path -Path $Path)) { New-Item -Path $Path -ItemType Directory -Force }
            $CurrentValue = Get-ItemProperty -Path $Path -Name $ValueName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $ValueName
            WriteLog -Message "Current value for $($ValueName) = [$($CurrentValue)]" -Verbose
            if ($CurrentValue -ne $Value) {
                WriteLog -Message "Updating value as required for Blacklotus 2nd phase mitigation, for $($ValueName) = [$($Value)]" -MessageType Warning -Verbose
                Set-ItemProperty -Path $Path -Name $ValueName -Value $Value -Force
            }
            $NewValue = Get-ItemProperty -Path $Path -Name $ValueName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $ValueName
            if ($NewValue -ne $Value) {
                WriteLog -Message "Not possible update registry value for Blacklotus mitigation actions" -MessageType Error -Verbose
                $global:MessageResults = "Not possible update registry value for Blacklotus mitigation actions"
                $global:CodeResults = -3
                Out-Windows
            }
            else {
                WriteLog -Message "Successfully applied registry trigger for BlackLotus mitigation step 3a-2" -Verbose
                WriteLog -Message "Perform reboot to enable revocation protections, BlackLotus mitigation 3b" -MessageType Warning -Verbose
                $global:MessageResults = "Perform reboot to enable revocation protections, BlackLotus mitigation 3b"
                $global:CodeResults = 3010
                if ($null -ne $json.JOBREQUEST.TestUpdates) {                
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.TestUpdates "bl02" $global:MessageResults
                }
                if ($null -ne $json.JOBREQUEST.CheckMSUpdates) {                
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.CheckMSUpdates "bl02" $global:MessageResults
                }            
                Out-Windows
            }
        } #end of bl01
        ## BlackLotus Revocations step 3c
        if (
            (($null -ne $json.JOBREQUEST.TestUpdates.status -AND $json.JOBREQUEST.TestUpdates.status.ToLower() -eq "bl02")) -OR 
            (($null -ne $json.JOBREQUEST.CheckMSUpdates.status -AND $json.JOBREQUEST.CheckMSUpdates.status.ToLower() -eq "bl02"))
        ) {
            WriteLog -Message "BlackLotus pause for 5 minutes, please wait" -Verbose
            Start-Sleep -Seconds 300
            WriteLog -Message "Perform reboot for BlackLotus revocations step 3c" -MessageType Warning -Verbose
            $global:MessageResults = "Perform reboot for BlackLotus revocations step 3c"
            $global:CodeResults = 3010
            if ($null -ne $json.JOBREQUEST.TestUpdates) {                
                Update-JobStatus $jobfile $json $json.JOBREQUEST.TestUpdates "bl03" $global:MessageResults
            }
            if ($null -ne $json.JOBREQUEST.CheckMSUpdates) {                
                Update-JobStatus $jobfile $json $json.JOBREQUEST.CheckMSUpdates "bl03" $global:MessageResults
            }            
            Out-Windows
        } #end of bl02
        ## BlackLotus Revocations step 3c2
        if (
            (($null -ne $json.JOBREQUEST.TestUpdates.status -AND $json.JOBREQUEST.TestUpdates.status.ToLower() -eq "bl03")) -OR 
            (($null -ne $json.JOBREQUEST.CheckMSUpdates.status -AND $json.JOBREQUEST.CheckMSUpdates.status.ToLower() -eq "bl03"))
        ) {
            WriteLog -Message "Perform additional reboot for BlackLotus revocations step 3c" -MessageType Warning -Verbose
            Start-Sleep -Seconds 60
            $global:MessageResults = "Perform additional reboot for BlackLotus revocations step 3c"
            $global:CodeResults = 3010
            if ($null -ne $json.JOBREQUEST.TestUpdates) {                
                Update-JobStatus $jobfile $json $json.JOBREQUEST.TestUpdates "bl04" $global:MessageResults
            }
            if ($null -ne $json.JOBREQUEST.CheckMSUpdates) {                
                Update-JobStatus $jobfile $json $json.JOBREQUEST.CheckMSUpdates "bl04" $global:MessageResults
            }            
            Out-Windows
        }
        ## BlackLotus Revocations step 3d
        if (
            (($null -ne $json.JOBREQUEST.TestUpdates.status -AND $json.JOBREQUEST.TestUpdates.status.ToLower() -eq "bl04")) -OR 
            (($null -ne $json.JOBREQUEST.CheckMSUpdates.status -AND $json.JOBREQUEST.CheckMSUpdates.status.ToLower() -eq "bl04"))
        ) {
            WriteLog -Message "Validating BlackLotus revocations, checking Event Logs, saved in ValidateEventLog.log" -Verbose
            #Get-EventLog -List | Select-Object -Property Log | Out-File -FilePath (Join-Path $logs "ValidateEventLog.log") -Append
            Get-EventLog -Newest 50 -LogName System | Out-File -FilePath (Join-Path $logs "ValidateEventLog.log") -Append
            Get-WinEvent -LogName Microsoft-Windows-Kernel-Boot/Operational -MaxEvents 50 | Out-File -FilePath (Join-Path $logs "ValidateEventLog.log") -Append
            if ($null -ne (Get-EventLog -LogName System | Where-Object { $_.InstanceID -eq 1035 })) {
                WriteLog -Message "Event Log System ID 1035 found" -Verbose
                (Get-EventLog -LogName System -ErrorAction SilentlyContinue | Where-Object { $_.EventID -eq 1035 }) | Out-File -FilePath (Join-Path $logs "ValidateEventLog.log") -Append
            }
            if ($null -ne (Get-WinEvent -LogName Microsoft-Windows-Kernel-Boot/Operational | Where-Object { $_.Id -eq 276 })) {
                WriteLog -Message "Event Log Microsoft-Windows-Kernel-Boot/Operational ID 276 found" -Verbose
                (Get-WinEvent -LogName Microsoft-Windows-Kernel-Boot/Operational | Where-Object { $_.Id -eq 276 }) | Out-File -FilePath (Join-Path $logs "ValidateEventLog.log") -Append
            }


        }
    }

    $global:MessageResults = "Microsoft Updates has been applied successfully"
    if ($null -ne $json.JOBREQUEST.TestUpdates) {                
        Update-JobStatus $jobfile $json $json.JOBREQUEST.TestUpdates "pass" $global:MessageResults
    }
    if ($null -ne $json.JOBREQUEST.CheckMSUpdates) {                
        Update-JobStatus $jobfile $json $json.JOBREQUEST.CheckMSUpdates "pass" $global:MessageResults
    }   
    ### Cleanup
    WriteLog -Message "Removing wsusscn2.cab since is not longer required" -Verbose
    if (Test-Path -Path "$($env:SystemDrive)\system.sav\util\wsusscn2.cab" -PathType Leaf) {
        Remove-Item -Path "$($env:SystemDrive)\system.sav\util\wsusscn2.cab" -Force 
    }
    if (Test-Path -Path "$($env:SystemDrive)\system.sav\util\MSUpdates\wsusscn2.cab" -PathType Leaf) { 
        Remove-Item -Path "$($env:SystemDrive)\system.sav\util\MSUpdates\wsusscn2.cab" -Force 
    }
    #remove KBUpdate Modules
    if (Test-Path $KBUpdateModules -PathType Leaf) {
        $Getmods = Get-Content -Path $KBUpdateModules -Raw | ConvertFrom-Json
        Copy-Item -Path $KBUpdateModules -Destination (Join-Path $logs "kbupdateModuleFolder.json") -Force
        #this file will be required on WinPE_PreSaveImage Module to known which folders remove
        Copy-Item -Path $KBUpdateModules -Destination (Join-Path "$($env:SystemDrive)\system.sav\Logs" "kbupdateModuleFolder.json") -Force
        try {
            foreach ($modname in $Getmods) {
                WriteLog -Message "Removing module ""$($modname.Name)""..." -Verbose
                Remove-Module -Name $modname.Name -Force -ErrorAction SilentlyContinue
            }   
        }
        catch {
            WriteLog -Message "Not possible uninstall modules added for KBUPDATE support" -MessageType Warning -Verbose
        }                    
    }                

    if ($null -ne $json.JOBREQUEST.TestUpdates) {
        WriteLog -Message "Test MS Updates require to back WinPE at this point" -Verbose
        $global:MessageResults = "Updates applied are correctly for this OS"
        $global:CodeResults = 0
        Out-Windows
    }
    
}
else {
    WriteLog -Message "Not required this module, continue" -Verbose
}
