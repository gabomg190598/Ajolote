<#
.DESCRIPTION
    Additional functions for WINDOWS  environment

#>

function Update-JobStatus { 
    param (
        [Parameter(Mandatory = $true, Position=0)]
        [string]$Path,
        [Parameter(Mandatory = $true, Position=1)]
        $JsonObject,
        [Parameter(Mandatory = $true, Position=2)]
        $JsonPath,
        [Parameter(Mandatory = $true, Position=3)]
        [string]$status,
        [Parameter(Mandatory = $true, Position=4)]
        [string]$errormessage
    )
    if ($null -ne $JsonPath) {
        if ($null -eq $JsonPath.status) {
            $JsonPath | Add-Member -Name "status" -MemberType NoteProperty -Value $status
        } else {
            $JsonPath.status=$status
        }
        if ($null -eq $JsonPath.error) {
            $JsonPath | Add-Member -Name "error" -MemberType NoteProperty -Value $errormessage
        } else {
            $JsonPath.error=$errormessage
        }
        ### Save JOB file
        try {
            $JsonObject | ConvertTo-Json -Depth 16 | Out-File -FilePath $Path -Encoding ascii -Force
        } catch {
            $ErrorMessage = $_.Exception.Message
            WriteLog -Message "Failed updating JOB file: $($ErrorMessage)" -MessageType Error -Verbose
            $global:MessageResults="Failed updating JOB file: $($ErrorMessage)"
            $global:CodeResults=209
            Out-Windows
            $global:MessageResults | Out-Null
            $global:CodeResults | Out-Null
        }
    } else {
        WriteLog -Message "JSON path doesn't exist, check object $($JsonPath)" -MessageType Error -Verbose
    }
   
}
function Update-JobStage { 
    #Update-JobStage $jobfile $json $json.JOBREQUEST "WINPE_MODULENAME"
    param (
        [Parameter(Mandatory = $true, Position=0)]
        [string]$Path,
        [Parameter(Mandatory = $true, Position=1)]
        $JsonObject,
        [Parameter(Mandatory = $true, Position=2)]
        $JsonPath,
        [Parameter(Mandatory = $true, Position=3)]
        [string]$Stage
    )
    if ($null -ne $JsonPath) {
        if ($null -ne $JsonPath.Job) {
            if ($null -eq $JsonPath.Job.stage) {
                $JsonPath.Job | Add-Member -Name "stage" -MemberType NoteProperty -Value $Stage
            } else {
                $JsonPath.Job.stage=$Stage
            }
        } elseif ($null -ne $JsonPath.Control) {
            if ($null -eq $JsonPath.Control.stage) {
                $JsonPath.Control | Add-Member -Name "stage" -MemberType NoteProperty -Value $Stage
            } else {
                $JsonPath.Control.stage=$Stage
            }
        }        
        ### Save JOB file
        try {
            $JsonObject | ConvertTo-Json -Depth 16 | Out-File -FilePath $Path -Encoding ascii -Force
        } catch {
            $ErrorMessage = $_.Exception.Message
            WriteLog -Message "Failed updating Stage JOB file: $($ErrorMessage)" -MessageType Error -Verbose
            $global:MessageResults="Failed updating Stage JOB file: $($ErrorMessage)"
            $global:CodeResults=210
            Out-Windows
            $global:MessageResults | Out-Null
            $global:CodeResults | Out-Null
        }
    } else {
        WriteLog -Message "JSON path doesn't exist, check object $($JsonPath)" -MessageType Error -Verbose
    }
   
}
function Import-BCD {
    param (
    )
    Process {
        Try {
            #detect Ajolote partition
            $AjoloteDrive=(Get-Volume | Where-Object {$_.FileSystemLabel -eq "AJOLOTE" }).DriveLetter            
            if (($null -eq $AjoloteDrive) -OR ($AjoloteDrive.Length -ne 1)) {
                WriteLog -Message "It was not possible to detect Ajolote drive, select D: as default"
                $AjoloteDrive="D:"
            } else {
                $AjoloteDrive="$($AjoloteDrive):"
            }
            $logs=$Global:logs
            $importbcd=Invoke-RunPower -File "cmd.exe" -Params "/c bcdedit /import ""$($AjoloteDrive)\EFI\Microsoft\Boot\BCD"" /clean" -WorkDir "C:\Windows\System32" -OutFile "$($logs)\ImportBCD.log" -Verbose
            if ($importbcd -ne 0) {
                WriteLog -Message "Fail importing BCD from WinPE to current environment" -MessageType Error -Verbose
                exit 101
            }
            [string[]]$bcd=@(
                "bcdedit -set {default} device ramdisk=[$($AjoloteDrive)]\sources\boot.wim,{0f84e3b8-bab2-4209-bf1e-7e351ad25f6f}",
                "bcdedit -set {default} osdevice ramdisk=[$($AjoloteDrive)]\sources\boot.wim,{0f84e3b8-bab2-4209-bf1e-7e351ad25f6f}",
                "bcdedit -set {0f84e3b8-bab2-4209-bf1e-7e351ad25f6f} ramdisksdidevice partition=$($AjoloteDrive)",
                "bcdedit  -set {memdiag} device partition=$($AjoloteDrive)"
            )
            foreach ($item in $bcd) {
                WriteLog -Message "*$($item)" -Verbose
                $modbcd=Invoke-RunPower -File "cmd.exe" -Params "/c $($item)" -WorkDir "C:\Windows\System32" -OutFile "$($logs)\ModBCD.log" -Verbose
                if ($modbcd -ne 0) {
                    WriteLog -Message "Fail modifying BCD on current environment" -MessageType Error -Verbose
                    exit 101
                }
            }
            WriteLog -Message "BCD updated, ready to return to WinPE" -Verbose
        } Catch {

        }
    }
}

<#################### OUT FUCTION #>
function Out-Windows {
    param (
        [Parameter(Mandatory = $False)]
        [switch] $NoAction
    )
    #Begin { }
    Process {
        try {
            WriteLog -Message "----------------------------- CLOSE WINDOWS --------------------------" -Verbose
            WriteLog -Message "        Exit Message: $($Global:MessageResults)" -Verbose
            WriteLog -Message "           Exit Code: $($Global:CodeResults)" -Verbose
            WriteLog -Message "           Logs Path: $($Global:logs)" -Verbose
            #Error Flag
            if (!(Test-Path "$($env:SystemDrive)\system.sav\flags")) {
                New-Item -Path "$($env:SystemDrive)\system.sav\flags" -ItemType Directory -Force 
            }
            $CSBuildErrorFlag="$($env:SystemDrive)\system.sav\flags\csbuilderror.flg"
            $JobFile="$($global:envDrive)\job.json"
            $json = Get-Content $jobfile -Raw | ConvertFrom-Json
            if ($null -ne $json.JOBREQUEST.Job) { 
                $currentstatus=$json.JOBREQUEST.Job.status
            } elseif ($null -ne $json.JOBREQUEST.Control) {
                $currentstatus=$json.JOBREQUEST.Control.status
            }  
            switch ($Global:CodeResults) {
                0 { 
                    WriteLog -Message "             Actions: Swap OS and Reboot, No errors" -Verbose
                }
                3010 {
                    WriteLog -Message "             Actions: Reboot unit" -Verbose
                    $currentstatus="reboot"
                }
                Default { 
                    WriteLog -Message "             Actions: Swap OS and Reboot, error detected" -Verbose
                    New-Screenshot
                    $currentstatus="fail"
                }
            }
            
                      
            if ($null -ne $json.JOBREQUEST.Job) { 
                Update-JobStatus $jobfile $json $json.JOBREQUEST.Job $currentstatus $global:MessageResults
                try {
                    $MountPoint=Invoke-MountServer "/jobpath"
                    if ($null -ne $MountPoint) {
                        WriteLog -Message "Copying Job.json file to Server" -Verbose
                        Copy-Item -Path $JobFile -Destination "$($MountPoint)\$($json.JOBREQUEST.Job.namejob).job" -Force
                        $null=Invoke-RunPower -File "cmd.exe" -Params "/c net use /Delete $($MountPoint)" -WorkDir "C:\Windows\System32" -OutFile "$($logs)\DismountDrive.log" -Verbose
                    } else {
                        WriteLog -Message "Not possible mount Jobs share" -MessageType Error -Verbose
                    }
                } Catch {
                    $ErrorMessage = $_.Exception.Message
                    WriteLog -Message "Exception mounting share: $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
                }
                
            } elseif ($null -ne $json.JOBREQUEST.Control) {
                Update-JobStatus $jobfile $json $json.JOBREQUEST.Control $currentstatus $global:MessageResults
            }
            
            Start-Process -FilePath "cmd.exe" -ArgumentList "/c bcdedit /timeout 0" -Wait -NoNewWindow
            Start-Process -FilePath "cmd.exe" -ArgumentList "/c bcdedit /enum all > $($Global:logs)\BCD_Windows.log" -Wait -NoNewWindow
            
            if (-Not($NoAction)) {
                #Only if Job exist, process must stop when error code is not 0

                switch ($Global:CodeResults) {
                    0 { 
                        #Import-BCD
                        #Enable-WinPE
                        Set-BCDEnvironment -Environment WinPE -OSDrive "C:"
                        Restart-Computer -Force
                        Start-Sleep -Seconds 10
                        exit $Global:CodeResults
                        break; 
                    }
                    3010 {
                        Restart-Computer -Force
                        Start-Sleep -Seconds 10
                        exit $Global:CodeResults
                        break;
                    }
                    Default { 
                        $Global:MessageResults | Out-File -FilePath $CSBuildErrorFlag -Encoding ascii -Force;
                        #Import-BCD
                        #Enable-WinPE
                        Set-BCDEnvironment -Environment WinPE -OSDrive "C:"
                        Restart-Computer -Force
                        Start-Sleep -Seconds 10
                        exit $Global:MessageResults
                        break;
                    }
                }
            } else {
                if ($Global:CodeResults -eq 0) {
                    WriteLog -Message "No action required, just switch WinPE" -Verbose
                    Set-BCDEnvironment -Environment WinPE -OSDrive "C:"
                }
                if ($Global:CodeResults -eq 3010) {
                    WriteLog -Message "Reboot required, Remain on Windows" -Verbose
                    Set-BCDEnvironment -Environment Windows -OSDrive "C:"
                }
            }
            

        }
        catch {
            $ErrorMessage = $_.Exception.Message
            WriteLog -Message "Exception on Out-Windows: $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
			throw [System.Exception]  "Exception on Out-Windows: $($ErrorMessage)"
        }
    }
    #End { }
}

function Invoke-UpdateJob {
    param (
    )
    try {
        $JobFile=(Join-Path $global:envDrive "job.json")
        if (!(Test-Path -Path $JobFile -PathType Leaf)) {WriteLog -Message "Not possible detect job file at $($JobFile)" -MessageType Error -Verbose; return; }
        $json = Get-Content $jobfile -Raw | ConvertFrom-Json           
        if ($null -ne $json.JOBREQUEST.Job.namejob) { 
            try {
                $MountPoint=Invoke-MountServer "/jobpath"
                if ($null -ne $MountPoint) {
                    WriteLog -Message "Copying Job.json file to Server" -Component $MyInvocation.MyCommand.Name -Verbose
                    Copy-Item -Path $JobFile -Destination "$($MountPoint)\$($json.JOBREQUEST.Job.namejob).job" -Force
                    $null=Invoke-RunPower -File "cmd.exe" -Params "/c net use /Delete $($MountPoint)" -WorkDir "C:\Windows\System32" -OutFile "$($logs)\UnMountDriveJob.log" -Verbose
                } else {
                    WriteLog -Message "Not possible mount Jobs share" -MessageType Error -Component $MyInvocation.MyCommand.Name -Verbose
                }
            } Catch {
                $ErrorMessage = $_.Exception.Message
                WriteLog -Message "Exception mounting share: $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name -Verbose
            }
        }
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        WriteLog -Message "Exception on Invoke-UpdateJob: $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name -Verbose
        throw [System.Exception]  "Exception on Invoke-UpdateJob: $($ErrorMessage)"
    }
}


function Invoke-MountServer {
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true,Position=0)]
        [string] $MounParameter
    )
    $SecureMountDrive = "$($env:SystemDrive)\system.sav\util\MountDrive.exe"
    
    if ($null -ne $MounParameter) {
        try {
            WriteLog -Message "Mount driver parameter detected: $($MounParameter)" -Verbose
            if ($MounParameter.StartsWith("/")) {
                [xml]$con = Get-Content "$($global:envDrive)\config.xml"
                $MountOption = $MounParameter.Substring(1,$MounParameter.Length - 1);
                $MountPath="\\$($con.AJOLOTE.servername)$($con.AJOLOTE.$MountOption)";
            } else {
                $MountPath=$MounParameter;
            }           
        } catch {
            WriteLog -Message "Mount option $($MountOption) is incorrect and cannot continue" -Verbose; 
            return $null;
        }
        #Verify free letters
        $drvlist=(Get-PSDrive -PSProvider filesystem).Name
        $freedrv=[System.Collections.ArrayList]@()
        Foreach ($drvletter in "CDEFGHIJKLMNOPQRSTUVWYZ".ToCharArray()) {
            If ($drvlist -notcontains $drvletter) {
                [void]$freedrv.Add($drvletter)
            } else {
                #Add to logs
                Get-PSDrive -PSProvider filesystem | Where-Object { $_.Name -eq "$($drvletter)" } | ForEach-Object {
                    <#
                    WriteLog -Message "--------------------IN-USE DRIVE INFORMATION---------------------" -Component $MyInvocation.MyCommand.Name
                    WriteLog -Message "       Name: $($_.Name)" -Component $MyInvocation.MyCommand.Name
                    WriteLog -Message "Description: $($_.Description)" -Component $MyInvocation.MyCommand.Name
                    WriteLog -Message "   Provider: $($_.Provider)" -Component $MyInvocation.MyCommand.Name
                    WriteLog -Message "       Root: $($_.Root)" -Component $MyInvocation.MyCommand.Name
                    WriteLog -Message "       Free: $([math]::Round($_.Free / 1Gb))GB" -Component $MyInvocation.MyCommand.Name
                    WriteLog -Message "       Used: $([math]::Round($_.Used / 1Gb))GB" -Component $MyInvocation.MyCommand.Name
                    #>
                    Write-Host "--------------------IN-USE DRIVE INFORMATION---------------------" 
                    Write-Host "       Name: $($_.Name)" 
                    Write-Host "Description: $($_.Description)" 
                    Write-Host "   Provider: $($_.Provider)" 
                    Write-Host "       Root: $($_.Root)" 
                    Write-Host "       Free: $([math]::Round($_.Free / 1Gb))GB" 
                    Write-Host "       Used: $([math]::Round($_.Used / 1Gb))GB"
                } 
                #Show on prompt
                #Get-PSDrive -PSProvider filesystem | Where-Object { $_.Name -eq "$($drvletter)" } | Select-Object -Property Name,Description,Provider,Root,Free,Used | Format-List | Out-Host
            }
        }
        if ($freedrv.Count -eq 0) {
            WriteLog -Message "There are not free drive letter to assign, abort process" -MessageType Error -Component $MyInvocation.MyCommand.Name; 
            return $null;
        }
        $objMap = Get-SmbMapping | Where-Object {$_.RemotePath -eq $MountPath}
        $intMap = (Get-SmbMapping | Where-Object {$_.RemotePath -eq $MountPath} | Measure-Object).Count
        if ($intMap -gt 1) {
            WriteLog -Message "It seems like mount point [$($MountPath)] appears more than once, try to remove additionals" -Verbose; 
            Get-SmbMapping | Where-Object {$_.RemotePath -eq $MountPath} | Out-Host
            for ($i = 1; $i -lt $intMap; $i++) {
                $securedelete = Invoke-RunPower -File "cmd.exe" -Params "/c net use $($objMap[$i].LocalPath) /delete" -WorkDir $PSScriptRoot -OutFile "$($global:logs)\Securedelete.log"
                if ($securedelete -ne 0) {
                    WriteLog -Message "It's not possible remove additional mounted drive [$($objMap[$i].LocalPath)]" -MessageType Error -Verbose; 
                }
            }
            WriteLog -Message "Rescan current Mount points" -Verbose; 
            $objMap = Get-SmbMapping | Where-Object {$_.RemotePath -eq $MountPath}
        }
        if ($null -eq $objMap) {
            $secureconnect = Invoke-RunPower -File "cmd.exe" -Params "/c $($SecureMountDrive) $($MounParameter)" -WorkDir $PSScriptRoot -OutFile "$($global:logs)\Secureconnect.log"
            if ($secureconnect -ne 0) {
                WriteLog -Message "It's not possible contact or connect server share" -MessageType Error -Verbose; 
                return $null
            }
            $objMap = Get-SmbMapping | Where-Object {$_.RemotePath -eq $MountPath}
            if ($null -eq $objMap)
            {
                WriteLog -Message "It's not possible mount server share" -MessageType Error -Verbose; 
                return $null; 
            }
        }
        if ($objMap[0].Status.ToString().Trim().ToUpper() -ne "OK") {
            WriteLog -Message "Status for drive is $($objMap[0].Status.ToString()), require to wakeup" -MessageType Warning -Verbose;
            $securedelete = Invoke-RunPower -File "cmd.exe" -Params "/c net use $($objMap[0].LocalPath) /delete" -WorkDir $PSScriptRoot -OutFile "$($global:logs)\Securedelete.log"
            if ($securedelete -ne 0) {
                WriteLog -Message "It's not possible remove mounted drive [$($objMap[0].LocalPath)]" -MessageType Error -Verbose; 
                return $null; 
            }
            $secureconnect = Invoke-RunPower -File "cmd.exe" -Params "/c $($SecureMountDrive) $($MounParameter)" -WorkDir $PSScriptRoot -OutFile "$($global:logs)\Secureconnect.log"
            if ($secureconnect -ne 0) {
                WriteLog -Message "It's not possible contact or connect server share" -MessageType Error -Verbose; 
                return $null
            }
            $objMap = Get-SmbMapping | Where-Object {$_.RemotePath -eq $MountPath}
            if ($null -eq $objMap) {
                WriteLog -Message "It's not possible mount server share" -MessageType Error -Verbose; 
                return $null; 
            }
        }
        if ($objMap[0].LocalPath.ToString().Trim().Length -ne 2) {
            WriteLog -Message "Not expecteded this value for drive assigned: [$($objMap[0].LocalPath)]" -MessageType Warning -Verbose;
            return $null;
        }
        
        WriteLog -Message "$($MyInvocation.MyCommand.Name) return drive: [$($objMap[0].LocalPath)]" -Verbose
        return $objMap[0].LocalPath
    }  else {
        WriteLog -Message "This function is not designed to work without parameter, you can use tool directly" -MessageType Error -Verbose; 
        return $null
    }
        
}


<#
Get-CVAObject return follow properties (when exist):
.Name
    Name of CVA
.Path
    Where is located CVA, path
.Title
    Title of software in en-US
.Version
    Vendor version 
.PN
    Part Number
.Vendor
    Vendor name
.Type
    Type of software
.Category
    Category of software
.Silent
    Silent command
.SilentFile
    Cleanup silent command extracting just file
.SilentParameters
    Cleanup silent command extracting only parameters
.SysIds
    Array list of all sysids supported
.Platforms
    Dictionary with SysID = Supported Platforms names separated by coma
.PassCodes
    Array list of all codes marked as SUCCESS
.ReturnCode
    Array with full string from CVA per code 
.Valid
    boolean to define if CVA can be used, it is expected to be found on sam level as silent executable file
.Length
    Int with length of path where CVA is located
#>
function Get-CVAObject { 
    param (
        [Parameter(Mandatory = $true, Position=0)]
        [string]$PathFile
    )
    
    try {
        if ((Test-Path -Path $PathFile -PathType Leaf) -AND ((Get-Item -Path $PathFile).Length -gt 0)){
            #Write-Host "Extract information from $($PathFile)"
            WriteLog -Message "`tExtracting information from $($PathFile)" -Verbose
            if ($null -ne (Get-Variable -Name File -ErrorAction SilentlyContinue)) { Remove-Variable -Name File -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name Path -ErrorAction SilentlyContinue)) { Remove-Variable -Name Path -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name retObj -ErrorAction SilentlyContinue)) { Remove-Variable -Name retObj -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name GetCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetCVA -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name Title -ErrorAction SilentlyContinue)) { Remove-Variable -Name Title -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name Version -ErrorAction SilentlyContinue)) { Remove-Variable -Name Version -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name Vendor -ErrorAction SilentlyContinue)) { Remove-Variable -Name Vendor -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name Type -ErrorAction SilentlyContinue)) { Remove-Variable -Name Type -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name Category -ErrorAction SilentlyContinue)) { Remove-Variable -Name Category -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name Silent -ErrorAction SilentlyContinue)) { Remove-Variable -Name Silent -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name objResult -ErrorAction SilentlyContinue)) { Remove-Variable -Name objResult -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name sub -ErrorAction SilentlyContinue)) { Remove-Variable -Name sub -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name sub2 -ErrorAction SilentlyContinue)) { Remove-Variable -Name sub2 -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name sub3 -ErrorAction SilentlyContinue)) { Remove-Variable -Name sub3 -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name rem -ErrorAction SilentlyContinue)) { Remove-Variable -Name rem -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name exefile -ErrorAction SilentlyContinue)) { Remove-Variable -Name exefile -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name flagread -ErrorAction SilentlyContinue)) { Remove-Variable -Name flagread -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name AllSysIDs -ErrorAction SilentlyContinue)) { Remove-Variable -Name AllSysIDs -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name SysID -ErrorAction SilentlyContinue)) { Remove-Variable -Name SysID -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name AllPass -ErrorAction SilentlyContinue)) { Remove-Variable -Name AllPass -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name ReturnCode -ErrorAction SilentlyContinue)) { Remove-Variable -Name ReturnCode -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name code -ErrorAction SilentlyContinue)) { Remove-Variable -Name code -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name PN -ErrorAction SilentlyContinue)) { Remove-Variable -Name PN -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name Platforms -ErrorAction SilentlyContinue)) { Remove-Variable -Name Platforms -Force -ErrorAction SilentlyContinue }
            $File=(Split-Path $PathFile -Leaf)
            $Path=(Split-Path $PathFile -Parent)
            $retObj = New-Object PSObject
            $retObj | Add-Member NoteProperty Name $File
            $retObj | Add-Member NoteProperty Path $Path
            $retObj | Add-Member NoteProperty Length $Path.Length
            $GetCVA = Get-Content $PathFile -Encoding Ascii
            
            if (($null -ne ($GetCVA | Select-String -Pattern "Software Title")) -AND (($GetCVA | Select-String -Pattern "Software Title").line.Trim().StartsWith('['))) {
                if ($null -ne ($GetCVA | Select-String -Pattern "US=")) {
                    $Title=(($GetCVA | Select-String -Pattern "US=")[0].Line).Split("=")[1].Trim()
                    $retObj | Add-Member Noteproperty Title $Title
                } else {
                    WriteLog -Message "`tTitle doesn't exist" -MessageType Error -Verbose
                }
            } else {
                #Write-Host "Software Title section doesn't exist"
                WriteLog -Message "`tSoftware Title section doesn't exist" -MessageType Error -Verbose
            }
            
            if (($null -ne ($GetCVA | Select-String -Pattern "General")) -AND (($GetCVA | Select-String -Pattern "General").line.Trim().StartsWith('['))) {
                if ($null -ne ($GetCVA | Select-String -Pattern "VendorVersion=")) {
                    foreach ($ln in ($GetCVA | Select-String -Pattern "VendorVersion=")) {
                        if ($ln.Line.Trim().StartsWith("VendorVersion=")) {
                            $Version=($ln.Line).Split("=")[1].Trim()
                        }
                    }
                    
                    if ([string]::IsNullOrEmpty($Version)) {
                        foreach ($line in ($GetCVA | Select-String -Pattern "Version=")) {
                            if ($line.Line.StartsWith("Version=")) {
                                $Version=$line.Line.Split("=")[1].Trim()
                            }
                        }
                        #$Version=(($GetCVA | Select-String -Pattern "Version=")[0].Line).Split("=")[1].Trim()
                        if ([string]::IsNullOrEmpty($Version)) { 
                            WriteLog -Message "`tVersion doesn't exist" -MessageType Warning -Verbose 
                            $retObj | Add-Member Noteproperty Version "0.0.0"
                        } else {
                            $retObj | Add-Member Noteproperty Version $Version
                        }
                    } else {
                        $retObj | Add-Member Noteproperty Version $Version
                    }
                    
                } else {
                    WriteLog -Message "`tVersion doesn't exist" -MessageType Warning -Verbose
                }
                #<<<<---- PN
                if ($null -ne ($GetCVA | Select-String -Pattern "PN=")) {
                    foreach ($ln in ($GetCVA | Select-String -Pattern "PN=")) {
                        if ($ln.Line.Trim().StartsWith("PN=")) {
                            $PN=($ln.Line).Split("=")[1].Trim()
                        }
                    }
                    if (($PN -eq "000000-000") -OR ($PN -eq "")) {
                        if ($null -ne ($GetCVA | Select-String -Pattern "SoftpaqNumber=")) {
                            foreach ($ln in ($GetCVA | Select-String -Pattern "SoftpaqNumber=")) {
                                if ($ln.Line.Trim().StartsWith("SoftpaqNumber=")) {
                                    $PN=($ln.Line).Split("=")[1].Trim()
                                }
                            }
                        }
                    }
                    $retObj | Add-Member Noteproperty PN $PN
                    
                } else {
                    WriteLog -Message "`tPN doesn't exist" -MessageType Warning -Verbose
                    $PN="000000-000"
                    if ($null -ne ($GetCVA | Select-String -Pattern "SoftpaqNumber=")) {
                        foreach ($ln in ($GetCVA | Select-String -Pattern "SoftpaqNumber=")) {
                            if ($ln.Line.Trim().StartsWith("SoftpaqNumber=")) {
                                WriteLog -Message "`ttrying to use SoftpaqNumber" -MessageType Warning -Verbose
                                $PN=($ln.Line).Split("=")[1].Trim()
                            }
                        }
                    }
                    $retObj | Add-Member Noteproperty PN $PN
                }
                #<<<---- VendorName
                if ($null -ne ($GetCVA | Select-String -Pattern "VendorName=")) {
                    $Vendor=(($GetCVA | Select-String -Pattern "VendorName=")[0].Line).Split("=")[1].Trim()
                    $retObj | Add-Member Noteproperty Vendor $Vendor
                } else {
                    WriteLog -Message "`tVendor doesn't exist" -MessageType Warning -Verbose
                }
                if ($null -ne ($GetCVA | Select-String -Pattern "Type=")) {
                    $Type=(($GetCVA | Select-String -Pattern "Type=")[0].Line).Split("=")[1].Trim()
                    $retObj | Add-Member Noteproperty Type $Type
                } else {
                    WriteLog -Message "`tType doesn't exist" -MessageType Warning -Verbose
                }
                if ($null -ne ($GetCVA | Select-String -Pattern "Category=")) {
                    $Category=(($GetCVA | Select-String -Pattern "Category=")[0].Line).Split("=")[1].Trim()
                    $retObj | Add-Member Noteproperty Category $Category
                } else {
                    WriteLog -Message "`tCategory doesn't exist" -MessageType Warning -Verbose
                }                
            } else {
                #Write-Host "General section doesn't exist"
                WriteLog -Message "`tGeneral section doesn't exist" -MessageType Warning -Verbose
            }
            
            if (($null -ne ($GetCVA | Select-String -Pattern "Install Execution")) -AND (($GetCVA | Select-String -Pattern "Install Execution").line.Trim().StartsWith('['))) {
                if ($null -ne ($GetCVA | Select-String -Pattern "SilentInstall=")) {
                    $Silent=(($GetCVA | Select-String -Pattern "SilentInstall=")[0].Line).Replace("$((($GetCVA | Select-String -Pattern "SilentInstall=")[0].Line).Split("=")[0])=","").Trim()
                    $retObj | Add-Member Noteproperty Silent $Silent
                    #Clean Command to just call 
                    $objResult = @{}
					foreach ($line in ($GetCVA | Select-String -Pattern "SilentInstall=")) {
						if ($line.Line.ToString().Trim().StartsWith("SilentInstall")) {
							$objResult.read = $line.Line.ToString().Trim().Substring(14,($line.Line.ToString().Trim().Length -14))
						}
					}
                    if (($null -eq $objResult.read) -OR ($objResult.read.ToLower() -eq "n/a")) {
                        WriteLog -Message "Not valid Silent command" -MessageType Warning -Verbose
                        $sub2="notfoundsilent.exe"
                        $sub3 = ""
                    } else {
                        if ($objResult.read.StartsWith("""")) {
                            $sub = $objResult.read.Substring(1, $objResult.read.Length - 1)
                            $rem = $sub.indexOf("""")
                            $sub2 = $sub.Substring(0, $rem)
                            if ($sub.length -gt $rem + 1) {
                                $sub3 = $sub.Substring($rem + 1, ($sub.Length - $sub2.Length - 1))  
                            } else {
                                $sub3 = ""
                            }                        
                        } else {
                            if ($objResult.read.Trim().IndexOf(" ") -gt 0) {
                                $sub2 = $objResult.read.Split(" ")[0]
                                $sub3 = $objResult.read.Replace($sub2, "").Trim()
                            } else {
                                $sub2 = $objResult.read.Trim()
                                $sub3 = ""
                            }                        
                        }
                    }                    
                    $objResult.file = $sub2
                    $objResult.parameters = $sub3
                    $objResult.silent = $sub2 + $sub3
					$retObj | Add-Member Noteproperty SilentFile $objResult.file
					$retObj | Add-Member Noteproperty SilentParameters $objResult.parameters
                } else { WriteLog -Message "`tSilent Install doesn't exist" -MessageType Warning -Verbose }
            } else {
                #Write-Host "Install Execution section doesn't exist"
                WriteLog -Message "`tInstall Execution section doesn't exist" -MessageType Warning -Verbose
            }
            ### Based on silent comannd define if CVA is valid, file mentioned should be present or command should be valid
            #N/A is not a valid command
            #use msiexec is valid
            if ($null -ne $retObj.Silent) {
                #Value for SilentInstall was detected
                if ($retObj.Silent.ToLower() -eq "n/a") {
                    $retObj | Add-Member Noteproperty Valid $false
                } else {
                    #Detect executable file
                    if ($retObj.Silent.StartsWith("""")) {
                        $sub = $retObj.Silent.Substring(1, $retObj.Silent.Length - 1)
                        $rem = $sub.indexOf("""")
                        $sub2 = $sub.Substring(0, $rem)
                        if ($sub.length -gt $rem + 1) {
                            $sub3 = $sub.Substring($rem + 1, ($sub.Length - $sub2.Length - 1))  
                        } else {
                            $sub3 = ""
                        }                        
                    } else {
                        if ($retObj.Silent.Trim().IndexOf(" ") -gt 0) {
                            $sub2 = $retObj.Silent.Split(" ")[0]
                            $sub3 = $retObj.Silent.Replace($sub2, "").Trim()
                        } else {
                            $sub2 = $retObj.Silent.Trim()
                            $sub3 = ""
                        }                        
                    }
                    $exefile = $sub2
                    $null = $sub3
                    #msiexec is valid executable, more executables need to be added
                    if ($exefile.ToLower().StartsWith("msiexec")) {
                        $retObj | Add-Member Noteproperty Valid $true
                    } elseif (Test-Path -Path (Join-Path $retObj.Path $exefile) -PathType Leaf) {
                        $retObj | Add-Member Noteproperty Valid $true
                    } else {
                        $retObj | Add-Member Noteproperty Valid $false
                    }
                }
            }
            
            if (($null -ne ($GetCVA | Select-String -Pattern "System Information")) -AND (($GetCVA | Select-String -Pattern "System Information").line.Trim().StartsWith('['))) {
                $flagread=$false
                $AllSysIDs = [System.Collections.ArrayList]@()
                $AllPlatformsbyID = New-Object  System.Collections.Generic.Dictionary"[string,string]"
                foreach ($cvaline in $GetCVA) {
                    if ($flagread) {
                        #reading line by line
                        if (($cvaline.Trim().Length -eq 0) -OR ($cvaline.StartsWith("["))) { 
                            $flagread=$false
                        } else {
                            if ($cvaline.StartsWith("SysId")) {
                                $SysID=$cvaline.Split("=")[1].Replace("0x","")
                                [void]$AllSysIDs.Add($SysID)
                            }
                            if ($cvaline.StartsWith("SysName")) {
                                $numbgroup=$cvaline.Split("=")[0].Replace("SysName","")
                                $Id=($GetCVA | Select-String -Pattern "SysId$($numbgroup)")[0].Line.Split("=")[1].Replace("0x","")
                                $Plats=$cvaline.Split("=")[1].Trim()
                                $AllPlatformsbyID.Add($Id,$Plats)                                
                            }
                        }
                    } else {
                        if ($cvaline.Contains("System Information")) {$flagread=$true}
                    }

                }
                $retObj | Add-Member Noteproperty SysIds $AllSysIDs
                $retObj | Add-Member Noteproperty Platforms $AllPlatformsbyID
                if ($AllSysIDs.Count -eq 0) {
                    WriteLog -Message "`tSystem IDs missing" -MessageType Warning -Verbose
                }           
            } else {
                #Write-Host "System Information section doesn't exist"
                WriteLog -Message "`tSystem Information section doesn't exist" -MessageType Warning -Verbose
            }

            $AllPass = [System.Collections.ArrayList]@()
            $ReturnCode = [System.Collections.ArrayList]@()
            if (($null -ne ($GetCVA | Select-String -Pattern "ReturnCode")) -AND (($GetCVA | Select-String -Pattern "ReturnCode").line.Trim().StartsWith('['))) {
                $flagread=$false                
                foreach ($cvaline in $GetCVA) {
                    if ($flagread) {
                        #reading line by line
                        if (($cvaline.Trim().Length -eq 0) -OR ($cvaline.StartsWith("["))) { 
                            $flagread=$false
                        } else {
                            if ($cvaline.Contains(":")) {
                                [void]$ReturnCode.Add($cvaline)
                                if ($cvaline.Split(":")[1] -like "SUCCESS") {
                                    try {
                                        [int]$code=$cvaline.Split(":")[0]
                                        [void]$AllPass.Add($code)
                                    } catch {
                                        #Write-Host "[ERROR] Parsing $($cvaline.Split(':')[0]) -> INT Message: $($_.Exception.Message)"
                                        WriteLog -Message "`t[ERROR] Parsing $($cvaline.Split(':')[0]) -> INT Message: $($_.Exception.Message)" -MessageType Error -Verbose
                                    } 
                                }                                
                            }
                        }
                    } else {
                        if ($cvaline -contains "[ReturnCode]") {$flagread=$true}
                    }

                }
            } else {
                #Write-Host "ReturnCode doesn't exist, using defaults 0 and 3010"
                WriteLog -Message "`tReturnCode doesn't exist, using defaults 0 and 3010" -MessageType Warning -Verbose
                [void]$AllPass.Add(0)
                [void]$ReturnCode.Add("0:SUCCESS:NOREBOOT=The action completed successfully.")
                [void]$AllPass.Add(3010)
                [void]$ReturnCode.Add("3010:SUCCESS:REBOOT=A restart is required to complete the install. This message is indicative of a success.")
            }
            if (-Not($AllPass.Contains(0))) { 
                #Write-Host "Universal code 0 is mandatory, adding"
                WriteLog -Message "`tUniversal code 0 is mandatory, adding" -MessageType Warning -Verbose
                [void]$AllPass.Add(0)
                [void]$ReturnCode.Add("0:SUCCESS:NOREBOOT=The action completed successfully.")
            }
            if ($AllPass.Count -gt 0) {
                $retObj | Add-Member Noteproperty PassCodes $AllPass
                $retObj | Add-Member NoteProperty ReturnCode $ReturnCode
            } else {
                WriteLog -Message "`tReturnCode doesn't detected, using defaults 0 and 3010" -MessageType Warning -Verbose
                [void]$AllPass.Add(0)
                [void]$ReturnCode.Add("0:SUCCESS:NOREBOOT=The action completed successfully.")
                [void]$AllPass.Add(3010)
                [void]$ReturnCode.Add("3010:SUCCESS:REBOOT=A restart is required to complete the install. This message is indicative of a success.")
                $retObj | Add-Member Noteproperty PassCodes $AllPass
                $retObj | Add-Member Noteproperty ReturnCode $ReturnCode
            }
            
            ##########################################
            ######<---Return object pupulated#########
            ##########################################
            return $retObj

        } else {
            #Write-Error "File $($PathFile) doesn't exist"
            if (-Not(Test-Path -Path $PathFile)) {
                WriteLog -Message "`tFile $($PathFile) doesn't exist" -MessageType Error -Verbose
            } else {
                WriteLog -Message "`tFile $($PathFile) its empty" -MessageType Error -Verbose
            }    
            return $null
        }

    }
    catch {
        $ErrorMessage = $_.Exception.Message
        Write-Host "Failed: $($ErrorMessage)" -ForegroundColor Red -BackgroundColor Black
        return $null
    } #End of Try   
}




function Enable-WinPE {
    try {
        #Where is WinPE
        $AjoloteDrive=(Get-Volume | Where-Object {$_.FileSystemLabel -eq "AJOLOTE" }).DriveLetter
        $AjoloteDrive="$($AjoloteDrive):"
        WriteLog -Message "Drive detected with WinPE: $($AjoloteDrive)" -Component $MyInvocation.MyCommand.Name 
        
        if ($null -eq $AjoloteDrive) {
            WriteLog -Message "Not possible detect WinPE partition" -MessageType Warning -Component $MyInvocation.MyCommand.Name
            return $null
        }
        if (Test-Path Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\MiniNT) {
            WriteLog -Message "Not expected WinPE Environment Detectect" -MessageType Warning -Component $MyInvocation.MyCommand.Name
        } else {
            WriteLog -Message "Windows Environment Detected" -Component $MyInvocation.MyCommand.Name
            $winpeid="{0f84e3b8-bab2-4209-bf1e-7e351ad25f6f}"
			$ramdisk="{ramdiskoptions}" 
            $ramdiskdesc="Ramdisk Ajolote Options"        
            $null=Invoke-RunPower -File "cmd.exe" -Params "/c bcdedit -enum all > $($logs)\bcd.txt" -WorkDir "C:\Windows\System32" -OutFile "$($logs)\getBCDWindows" -Verbose
            if (-Not(Test-Path "$($logs)\bcd.txt" -PathType Leaf)) { WriteLog -Message "Not possible extract BCD information" -MessageType Error -Verbose; exit 1; }
            $ContentBCD=Get-Content (Join-Path $logs "bcd.txt")
            if ($ContentBCD.Contains($ramdiskdesc)) {
                WriteLog -Message "WinPE was already configured, check options" -Verbose
                [string[]]$BCDWinPE=@("bcdedit -set $($ramdisk) ramdisksdidevice partition=$($AjoloteDrive)",
                        "bcdedit -set $($ramdisk) ramdisksdipath \boot\boot.sdi",
                        "bcdedit -set $($winpeid) device ramdisk=[$($AjoloteDrive)]\sources\boot.wim,$($ramdisk)",
                        "bcdedit -set $($winpeid) osdevice ramdisk=[$($AjoloteDrive)]\sources\boot.wim,$($ramdisk)",
                        "bcdedit -set $($winpeid) ramdisksdidevice partition=$($AjoloteDrive)",
                        "bcdedit  -set {memdiag} device partition=$($AjoloteDrive)",
                        "bcdedit -displayorder $($winpeid) /addfirst",
					    "bcdedit -default $($winpeid)")
            } else {
                WriteLog -Message "WinPE is missing, adding to current BCD" -Verbose
                [string[]]$BCDWinPE=@("bcdedit -create $($winpeid) -d ""Microsoft WindowsPE"" -application OSLOADER",
                        "bcdedit -create $($ramdisk) -d ""$($ramdiskdesc)""",
                        "bcdedit -set $($ramdisk) ramdisksdidevice partition=$($AjoloteDrive)",
                        "bcdedit -set $($ramdisk) ramdisksdipath \boot\boot.sdi",
                        "bcdedit -set $($winpeid) device ramdisk=[$($AjoloteDrive)]\sources\boot.wim,$($ramdisk)",
                        "bcdedit -set $($winpeid) osdevice ramdisk=[$($AjoloteDrive)]\sources\boot.wim,$($ramdisk)",
                        "bcdedit -set $($winpeid) path \windows\system32\boot\winload.efi",
                        "bcdedit -set $($winpeid) systemroot \windows",
                        "bcdedit -set $($winpeid) detecthal Yes",
                        "bcdedit -set $($winpeid) winpe Yes",
                        "bcdedit -timeout 0",
                        "bcdedit -bootsequence $($winpeid)",
                        "bcdedit -displayorder $($winpeid) /addfirst",
					    "bcdedit -default $($winpeid)" )
            }
            foreach ($bcd in $BCDWinPE) {
                WriteLog -Message "*$($bcd)" -Verbose
                $RunBCD=Invoke-RunPower -File "cmd.exe" -Params "/c $($bcd)" -WorkDir "C:\Windows\System32" -OutFile "$($logs)\ModBCDWindows2WinPE.log" -Verbose
                if ($RunBCD -ne 0) {WriteLog -Message "Not possible update BCD information, command: $($bcd)" -MessageType Error -Verbose; exit 1; }
            }


        }



    }
    catch {
        $ErrorMessage = $_.Exception.Message
		WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
    }
    
}

function Update-ServerJob {
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $Sourcejobfile,
        [Parameter(Mandatory=$true, Position=1)]
        [string] $Destinationjobfile
    )
    Begin {
        WriteLog -Message "Updating Job file" -Component $MyInvocation.MyCommand.Name
        if ($null -ne (Get-Variable -Name JobsDrive -ErrorAction SilentlyContinue)) { Remove-Variable -Name JobsDrive -Force -ErrorAction SilentlyContinue }
        $JobsDrive=Invoke-MountServer "/jobpath"
        if ([string]::IsNullOrEmpty($JobsDrive)) {
            WriteLog -Message "Not possible mount Jobs share" -MessageType Error -Component $MyInvocation.MyCommand.Name;
            return $null;
        } else {
            if ($JobsDrive.length -ne 2) {
                WriteLog -Message "Invalid format for Drive Mount point: [$($JobsDrive)]" -Messagetype Error -Component $MyInvocation.MyCommand.Name; 
                Remove-Variable -Name JobsDrive -Force -ErrorAction SilentlyContinue 
                return $null;
            } else {
                WriteLog -Message "Drive assigned for JobPath: [$($JobsDrive)]" -Component $MyInvocation.MyCommand.Name; 
            }
        }
    }
    Process {
        #Abort if source file doesn't exists
        if (-Not(Test-Path -Path $Sourcejobfile -PathType Leaf)) { WriteLog -Message "Doesn't exist source file job: $($Sourcejobfile)" -MessageType Error -Component $MyInvocation.MyCommand.Name; return $null;}
        #Enter in loop trying to copy
        $intTotalRetry=6;
        $intCountRetry=0;
        $boolRetry=$true;
        while ($boolRetry) {
            try {
                $intCountRetry++;
                WriteLog -Message "Trying to copy Job file to server [$($intCountRetry)/$($intTotalRetry)]" -Component $MyInvocation.MyCommand.Name;
                WriteLog -Message "*Copy-Item -Path $($Sourcejobfile) -Destination $((Join-Path $JobsDrive $Destinationjobfile)) -Force" -Component $MyInvocation.MyCommand.Name;
                Copy-Item -Path $Sourcejobfile -Destination (Join-Path $JobsDrive $Destinationjobfile) -Force
                #Validate file
                $checksumSource=(Get-FileHash -Path $Sourcejobfile -Algorithm MD5).Hash
                $checksumDestination=(Get-FileHash -Path (Join-Path $JobsDrive $Destinationjobfile) -Algorithm MD5).Hash
                if ($checksumSource -ne $checksumDestination) {
                    WriteLog -Message "Not possible move job file, checksum validation fails" -MessageType Error -Component $MyInvocation.MyCommand.Name;
                    WriteLog -Message "     MD5 hash for Source Job: $($checksumSource)" -Component $MyInvocation.MyCommand.Name
                    WriteLog -Message "MD5 hash for Destination Job: $($checksumDestination)" -Component $MyInvocation.MyCommand.Name
                    if ($intCountRetry -ge $intTotalRetry) {
                        WriteLog -Message "Reach maximum retries, abort process" -MessageType Error -Component $MyInvocation.MyCommand.Name;
                        return $null;
                    }
                    Start-Sleep -Seconds (Get-Random -Minimum 2 -Maximum 7); 
                } else {
                    WriteLog -Message "Job updated successfully" -Component $MyInvocation.MyCommand.Name;
                    $boolRetry=$false;
                }
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                [string]$ExceptionText = ($_ | Out-String).Trim()
                WriteLog -Message "Failed updating Job file, error: $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name;
                WriteLog -Message $Error -MessageType Error -Component $MyInvocation.MyCommand.Name;
                WriteLog -Message $ExceptionText -MessageType Error -Component $MyInvocation.MyCommand.Name;
                if ($intCountRetry -ge $intTotalRetry) {
                    WriteLog -Message "Reach maximum retries, abort process" -MessageType Error -Component $MyInvocation.MyCommand.Name;
                    return $null;
                }
                Start-Sleep -Seconds (Get-Random -Minimum 2 -Maximum 7);
            }  #end try/catch            
        } #Endloop

    } #end process
    
}

function New-Screenshot {
    $screenshotPath = (Join-Path $Global:logs "screenshot_$((Get-Date -Format 'MMddyyHHmmss')).png")
    # Load System.Windows.Forms assembly    
    Add-Type -AssemblyName System.Windows.Forms
    # Create a new bitmap object with the size of the screen
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
    # Create graphics object from the bitmap
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    # Capture the screen
    $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)

    # Save the screenshot to the specified path
    $bitmap.Save($screenshotPath)

    # Dispose of the graphics and bitmap objects to free up resources
    $graphics.Dispose()
    $bitmap.Dispose()

    # Output the path to the console
    WriteLog -Message "Screenshot saved to $screenshotPath" -Verbose
}

function Install-FSUpdate {
    [OutputType([int])]
    [CmdletBinding()]
	Param 
	(
		[Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$True,Position=0)]
		[Object[]]$UpdatesObject,

        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$True,Position=1)]
		[ValidateNotNullOrEmpty()]
		[Alias("FullPath")]
        [String]$RepositoryPath,

        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$True,Position=2)]
		[ValidateNotNullOrEmpty()]
		[Alias("LogsPath")]
        [String]$logs
    )
	Begin {
        if (($null -eq $UpdatesObject) -OR ($UpdatesObject.Count -eq 0)) {
            WriteLog -Message "No updates required or request include a empty object" -MessageType Warning -Verbose
            return 0
        }
	}
	Process {				
		Try 
		{   
            WriteLog -Message "Requested to install $($UpdatesObject.Count) update(s)" -Verbose
            $UpdateErrorCode=0;
            $UpdateErrorMsg="Exit without installation perfomed";
			foreach ($package in $UpdatesObject) {
                WriteLog -Message ">>Required package: $($package.Title)" -Verbose
                WriteLog -Message "`tPackage ID: $($package.ID)" -Verbose
                WriteLog -Message "`tPackage status: $($package.Status)" -Verbose
                WriteLog -Message "`tPackage severity: $($package.MSRCSeverity)" -Verbose
                foreach ($needfile in $package.FileName) {
                    WriteLog -Message "`t`tRequired package file: $($needfile)" -Verbose
                }
                $CurrentHotFix = Get-HotFix
                if ($null -eq ($CurrentHotFix | Where-Object { $_.HotFixID -eq $package.ID })) {
                    WriteLog -Message "Not detected as installed, try to install..." -Verbose
                    foreach ($file in $package.FileName) {
                        WriteLog -Message "Installing: $((Join-Path $RepositoryPath $file))" -Verbose
                        if (Test-Path (Join-Path $RepositoryPath $file)) {
                            $extensionfile = ([System.IO.Path]::GetExtension($file)).ToString().ToLower()
                            switch ($extensionfile) {
                                ".cab" {
                                    WriteLog -Message "Using Dism to add CAB package $($file)..." -Verbose
                                    $InjectUp = RunDism -Params "/online /ScratchDir:$($env:SystemDrive)\ /Add-Package /PackagePath:""$((Join-Path $RepositoryPath $package.FileName))""" -WorkDir $RepositoryPath -OutFile "$($Logs)\WinUpdate_$($package.ID).log" -ShowProgress $false	
                                    if (($InjectUp -ne 0) -AND ($InjectUp -ne 3010)) { 
                                        WriteLog -Message "Failed to install MS Update: $($package.Title), code: $($InjectUp)" -MessageType Error -Verbose;                             
                                        $UpdateErrorMsg = "Failed to install MS Update: $($package.Title), code: $($InjectUp)"
                                        $UpdateErrorCode = $InjectUp
                                    }
                                    else {
                                        WriteLog -Message "Successfully installed: $($package.Title)" -Verbose
                                        $UpdateErrorMsg = "Successfully installed: $($package.Title)"
                                    }                       
                                    break;
                                }
                                ".msu" {
                                    WriteLog -Message "Using WUSA to add MSU package $($file)..." -Verbose
                                    $InjectUp = Invoke-RunPower -File "wusa.exe" -Params """$((Join-Path $RepositoryPath $package.FileName))"" /quiet /norestart" -WorkDir $RepositoryPath -OutFile (Join-Path $logs "WinUpdate_$($package.ID).log")	
                                    if (($InjectUp -ne 0) -AND ($InjectUp -ne 3010)) { 
                                        WriteLog -Message "Failed to install MS Update: $($package.Title), code: $($InjectUp)" -MessageType Error -Verbose;                             
                                        $UpdateErrorMsg = "Failed to install MS Update: $($package.Title), code: $($InjectUp)"
                                        $UpdateErrorCode = $InjectUp
                                    }
                                    else {
                                        WriteLog -Message "Successfully installed: $($package.Title)" -Verbose
                                        $UpdateErrorMsg = "Successfully installed: $($package.Title)"
                                    }                   
                                    break;
                                }
                                ".exe" {
                                    #Checking MRT installed
                                    if (($package.Title -like "*Windows Malicious Software Removal Tool*") -OR ($package.ID -eq "KB890830")) {
                                        WriteLog -Message """Windows Malicious Software Removal Tool"", validating application..." -Verbose
                                        if (Test-Path -Path "$($env:SystemDrive)\Windows\System32\MRT.exe" -PathType Leaf) {
                                            WriteLog -Message "Found MRT.exe, try to execute..." -Verbose
                                            $mrt = Start-Process -FilePath "$($env:SystemDrive)\Windows\System32\MRT.exe" -PassThru -ErrorAction SilentlyContinue
                                            Start-Sleep -Seconds 10
                                            if ($null -eq $mrt) {
                                                WriteLog -Message "It cannot start MRT, installing: $((Join-Path $RepositoryPath $file))" -MessageType Warning -Verbose
                                                $applyMRT = Invoke-RunPower -File "cmd.exe" -Params "/c $((Join-Path $RepositoryPath $package)) /Q" -WorkDir $RepositoryPath -OutFile (Join-Path $logs "WinUpdateMRT.log")
                                                if ($applyMRT -ne 0) {
                                                    WriteLog -Message "Not possible install Microsoft Malicious Software Removal Tool" -MessageType Error -Verbose
                                                    $UpdateErrorMsg = "Not possible install Microsoft Malicious Software Removal Tool"
                                                    $UpdateErrorCode = $applyMRT
                                                } else {
                                                    $UpdateErrorMsg = "Successfully installed: $($package.Title)"
                                                }
                                            }
                                            if ($null -ne (Get-Process -Id $mrt.Id -ErrorAction SilentlyContinue)) { Stop-Process -Id $mrt.Id -Force -ErrorAction SilentlyContinue}
                                        }
                                        else {
                                            WriteLog -Message "It cannot detect MRT, installing: $((Join-Path $RepositoryPath $file))" -MessageType Warning -Verbose
                                            $applyMRT = Invoke-RunPower -File "cmd.exe" -Params "/c $((Join-Path $RepositoryPath $file)) /Q" -WorkDir $RepositoryPath -OutFile (Join-Path $logs "WinUpdateMRT.log")
                                            if ($applyMRT -ne 0) {
                                                WriteLog -Message "Not possible install Microsoft Malicious Software Removal Tool" -MessageType Error -Verbose
                                                $UpdateErrorMsg = "Not possible install Microsoft Malicious Software Removal Tool"
                                                $UpdateErrorCode = $applyMRT
                                            } else {
                                                $UpdateErrorMsg = "Successfully installed: $($package.Title)"
                                            }
                                        }
                                    }
                                    else {
                                        WriteLog -Message "There are no process for ""$($package.Title )""" -MessageType Warning -Verbose 
                                        $UpdateErrorMsg = "There are no process for ""$($package.Title )"""
                                        $UpdateErrorCode = 505
                                    }
                                    break;
                                }
                                Default {
                                    WriteLog -Message "Format not supported for install updates: $($_)" -Verbose
                                    $UpdateErrorMsg = "Format not supported for install updates: $($_)"
                                    $UpdateErrorCode = 506
                                }
                            }
                        } else {
                            WriteLog -Message "Not possible to locate file: $((Join-Path $RepositoryPath $file))" -MessageType Warning -Verbose
                            $UpdateErrorMsg = "Not possible to locate file: $((Join-Path $RepositoryPath $file))"
                            $UpdateErrorCode = 404
                        }
                        
                    }    
                }
                else {
                    WriteLog -Message "Package already detected as applied to this OS: $($package.Title)" -Verbose
                }                             
            }
            if ($UpdateErrorCode -ne 0) {
                WriteLog -Message $UpdateErrorMsg -MessageType Error -Verbose
            } else {
                WriteLog -Message $UpdateErrorMsg -Verbose
            }
            return $UpdateErrorCode
		} 
		Catch 
		{
			$ErrorMessage = $_.Exception.Message
			WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Verbose
		}
	
	}
    
}


function Set-BCDEnvironment {
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("Windows", "WinPE")]
        [string] $Environment,
        [Parameter(Mandatory=$false, Position=1)]
        [switch] $Force,
        [Parameter(Mandatory=$false, Position=1)]
        [ValidateNotNullOrEmpty()]
        [string] $OSDrive="C:",
        [Parameter(Mandatory=$false, Position=2)]
        [string]$logs
    )
    Begin {
        if (Test-Path HKLM:\SYSTEM\CurrentControlset\Control\MiniNT) { #WinPE environment detected 
            WriteLog -Message "WinPE environment detected, S: must be assigned to EFI" -Verbose
            $CurrentEnvironment="WinPE"
        } else {
            WriteLog -Message "Windows environment detected, S: must be assigned to EFI" -Verbose
            if (-Not(Test-Path "S:\")) {
                mountvol S: /s
            }
            $CurrentEnvironment="Windows"
        }
        $BCDPath = "S:\EFI\Microsoft\Boot\BCD"
        $AjoloteDrive=(Get-Volume | Where-Object {$_.FileSystemLabel -eq "AJOLOTE" }).DriveLetter
        $AjoloteDrive="$($AjoloteDrive):"
        if ([string]::IsNullOrEmpty($logs)) { $logs = (Join-Path $AjoloteDrive "\system.sav\logs\CSBuilt\HPLOGS_0") }
        WriteLog -Message "Logs folder: $($logs)" -Verbose
        #Rescan BCD
        $null = Invoke-RunPower -File "bcdedit.exe" -Params "/store $($BCDPath) /enum all" -WorkDir $PSScriptRoot -OutFile "$($logs)\BCDRescan.log" -Verbose

    }
    Process {        
        if ($Force) {
            if ($CurrentEnvironment -eq "Windows") {
                WriteLog -Message "BCD is locked for Windows, not possible recreate BCDfile" -Verbose
            } else {
                IF (Test-Path "S:\EFI") { Remove-Item -Path "S:\EFI" -Recurse -Force; WriteLog -Message "Remove EFI folder" -Verbose; }
                WriteLog -Message "Recreate BCD file from Windows" -Verbose                
                $CreateBCD = Invoke-RunPower -File "cmd.exe" -Params "/c bcdboot $((Join-Path $OSDrive "Windows")) /s S: /f UEFI" -WorkDir $PSScriptRoot -OutFile "$($logs)\BCDUpdate.log" -Verbose 
                if ($CreateBCD -ne 0) {
                    WriteLog -Message "Not possible recreate BCD file" -MessageType Error -Verbose
                    return $CreateBCD
                }
                $Pars = @("/create {0f84e3b8-bab2-4209-bf1e-7e351ad25f6f} -d ""Ajolote WinPE"" /application OSLOADER",
                "/create {7619dcc8-fafe-11d9-b411-000476eba25f} -d ""Ramdisk Ajolote Options"" /device",
                "/set {7619dcc8-fafe-11d9-b411-000476eba25f} ramdisksdidevice partition=$($AjoloteDrive)",
                "/set {7619dcc8-fafe-11d9-b411-000476eba25f} ramdisksdipath \boot\boot.sdi",
                "/set {0f84e3b8-bab2-4209-bf1e-7e351ad25f6f} device ramdisk=[$($AjoloteDrive)]\sources\boot.wim,{7619dcc8-fafe-11d9-b411-000476eba25f}",
                "/set {0f84e3b8-bab2-4209-bf1e-7e351ad25f6f} osdevice ramdisk=[$($AjoloteDrive)]\sources\boot.wim,{7619dcc8-fafe-11d9-b411-000476eba25f}",
                "/set {0f84e3b8-bab2-4209-bf1e-7e351ad25f6f} path \windows\system32\boot\winload.efi",
                "/set {0f84e3b8-bab2-4209-bf1e-7e351ad25f6f} systemroot \windows",
                "/set {0f84e3b8-bab2-4209-bf1e-7e351ad25f6f} detecthal yes",    
                "/set {0f84e3b8-bab2-4209-bf1e-7e351ad25f6f} winpe yes",
                "/timeout 0",
                "/bootsequence {0f84e3b8-bab2-4209-bf1e-7e351ad25f6f}"
                )
                foreach ($par in $Pars) {
                    $parametros = "/store $($BCDPath) $($par)"
                    WriteLog -Message "Execute BCDEDIT: $($parametros)" -Verbose
                    $UpdateBCD = Invoke-RunPower -File "bcdedit.exe" -Params $parametros -WorkDir $PSScriptRoot -OutFile "$($logs)\BCDUpdate.log" -Verbose 
                    if ($UpdateBCD -ne 0) {
                        WriteLog -Message "Not possible update BCD file" -MessageType Error -Verbose
                        return $UpdateBCD
                    }
                } 
            }
            
        }
        ##Get BCD BOOT LOADER IDs
        #[string[]]$BOOTLOADERS=bcdedit /store S:\EFI\Microsoft\Boot\BCD /enum all | Select-String "Windows Boot Loader" -Context 0,2 | ForEach-Object {$_.context.DisplayPostContext[1] -replace '^identifier +'}
        $pattern = [regex]::Escape("`{") + "(.*?)" + [regex]::Escape("`}")
        [string[]]$BOOTLOADERS=bcdedit /store S:\EFI\Microsoft\Boot\BCD /enum OSLOADER | Select-String "--------------" -Context 0,4 | ForEach-Object {if ($_.context.DisplayPostContext[0] -match $pattern) {return "`{$($Matches[1])`}"}}
        if ($null -eq $BOOTLOADERS) {
            WriteLog -Message "Not possible detect BCD Boot Loaders" -MessageType Error -Verbose
            return 1
        }
        $DIC_BOOTLOADER = [System.Collections.ArrayList]::new()
        foreach ($bootloader in $BOOTLOADERS) {
            Write-Host "Checking Bootloader GUID: $($bootloader)"
            if (Get-Variable -Name LABEL_ENTRY -ErrorAction SilentlyContinue) { Remove-Variable -Name LABEL_ENTRY -ErrorAction SilentlyContinue }
            $LABEL_ENTRY = bcdedit /store S:\EFI\Microsoft\Boot\BCD /enum $bootloader | Select-String "Ajolote"
            bcdedit /store S:\EFI\Microsoft\Boot\BCD /enum $bootloader | Out-Host
            if ($null -ne $LABEL_ENTRY) {
                $INT_LABEL=$LABEL_ENTRY.Line.Substring($LABEL_ENTRY.Line.IndexOf(" "),$LABEL_ENTRY.Line.Length-$LABEL_ENTRY.Line.IndexOf(" ")).Trim()
                Write-Host "Found Ajolote entry: $($INT_LABEL)"
                Write-Host "Found Ajolote GUID: $($bootloader)"
                if ($DIC_BOOTLOADER.Environment -contains $INT_LABEL) {
                    if (($DIC_BOOTLOADER | Where-Object {$_.Environment -ne $INT_LABEL} | Select-Object -ExpandProperty Bootloader) -ne $bootloader) {
                        Write-Host "[WARNING] Found another Ajolote GUID: $($bootloader)"
                    } else {
                        Write-Host "[WARNING] Ajolote GUID already added: $($bootloader)"
                    }
                    Continue
                }
                $DESCRIPTION = $INT_LABEL
                $NEWID = [PSCustomObject]@{
                    Environment = $DESCRIPTION
                    Bootloader = $bootloader
                }
                [Void]$DIC_BOOTLOADER.Add($NEWID)
            } else {
                $LABEL_ENTRY = bcdedit /store S:\EFI\Microsoft\Boot\BCD /enum $bootloader | Select-String "Winre.wim" -Context 0,2 | Where-Object {$_.line -notmatch "osdevice"} | ForEach-Object {$_.context.DisplayPostContext[1].Substring($_.context.DisplayPostContext[1].IndexOf(" "),$_.context.DisplayPostContext[1].Length-$_.context.DisplayPostContext[1].IndexOf(" ")).Trim()}
                if ($null -ne $LABEL_ENTRY) {                    
                    Write-Host "Found recovery entry: $($LABEL_ENTRY)"
                    Write-Host "Found Recovery GUID: $($bootloader)"
                    if ($DIC_BOOTLOADER.Environment -contains $LABEL_ENTRY) {
                        if (($DIC_BOOTLOADER | Where-Object {$_.Environment -ne $LABEL_ENTRY} | Select-Object -ExpandProperty Bootloader) -ne $bootloader) {
                            Write-Host "[WARNING] Found another Recovery GUID: $($bootloader)"
                        } else {
                            Write-Host "[WARNING] Recovery GUID already added: $($bootloader)"
                        }
                        Continue
                    }
                    $NEWID = [PSCustomObject]@{
                        Environment = $LABEL_ENTRY
                        Bootloader = $bootloader
                    }
                    [Void]$DIC_BOOTLOADER.Add($NEWID)
                } else {
                    if ($DIC_BOOTLOADER.Environment -contains "Windows OS") {
                        if (($DIC_BOOTLOADER | Where-Object {$_.Environment -ne "Windows OS"} | Select-Object -ExpandProperty Bootloader) -ne $bootloader) {
                            Write-Host "[WARNING] Found another Windows GUID: $($bootloader)"
                        } else {
                            Write-Host "[WARNING] Windows GUID already added: $($bootloader)"
                        }
                        Continue
                    }
                    Write-Host "Found Windows GUID: $($bootloader)"
                    $NEWID = [PSCustomObject]@{
                        Environment = "Windows OS"
                        Bootloader = $bootloader
                    }
                    [Void]$DIC_BOOTLOADER.Add($NEWID)
                }
                
            }
        }
        
        if (($Environment -eq "WinPE") -AND ($CurrentEnvironment -eq "WinPE")) {
            if ($null -ne ($DIC_BOOTLOADER | Where-Object {$_.Environment -eq "Ajolote WinPE"} | Select-Object -ExpandProperty Bootloader)) {
                WriteLog -Message "No actions to swith $($Environment) environemnt, current one is $($CurrentEnvironment)" -Verbose
                return $null;
            }            
        }
        if (($Environment -eq "Windows") -AND ($CurrentEnvironment -eq "Windows")) {
            if ($null -ne ($DIC_BOOTLOADER | Where-Object {$_.Environment -eq "Windows OS"} | Select-Object -ExpandProperty Bootloader)) {
                WriteLog -Message "No actions to swith $($Environment) environemnt, current one is $($CurrentEnvironment)" -Verbose
                return $null;
            }
        }
        #>
        if ($Environment -eq "Windows") {
            WriteLog -Message "Swith to $($Environment) environemnt" -Verbose
            #$WinGUID=bcdedit /store S:\EFI\Microsoft\Boot\BCD /enum all | Select-String "Windows Boot Loader" -Context 0,2 | ForEach-Object {$_.context.DisplayPostContext[1] -replace '^identifier +'} | Where-Object {$_ -ne "{0f84e3b8-bab2-4209-bf1e-7e351ad25f6f}"}
           
            $WindowsID=$DIC_BOOTLOADER | Where-Object {$_.Environment -eq "Windows OS"} | Select-Object -ExpandProperty Bootloader
            WriteLog -Message "Windows GUID: $($WindowsID)" -Verbose
            if ($DIC_BOOTLOADER.Environment -contains "Ajolote WinPE") {               
               $Pars = @("/bootsequence $($WindowsID) /addfirst",
                    "/displayorder $($WindowsID) /addfirst",
                    "/default $($WindowsID)",
                    "/timeout 0"
                ) 
            } else {
                WriteLog -Message "Required create Ramdisk input" -MessageType Warning -Verbose
                $Pars = @("/create {0f84e3b8-bab2-4209-bf1e-7e351ad25f6f} -d ""Ajolote WinPE"" /application OSLOADER",
                "/create {7619dcc8-fafe-11d9-b411-000476eba25f} -d ""Ramdisk Ajolote Options"" /device",
                "/set {7619dcc8-fafe-11d9-b411-000476eba25f} ramdisksdidevice partition=$($AjoloteDrive)",
                "/set {7619dcc8-fafe-11d9-b411-000476eba25f} ramdisksdipath \boot\boot.sdi",
                "/set {0f84e3b8-bab2-4209-bf1e-7e351ad25f6f} device ramdisk=[$($AjoloteDrive)]\sources\boot.wim,{7619dcc8-fafe-11d9-b411-000476eba25f}",
                "/set {0f84e3b8-bab2-4209-bf1e-7e351ad25f6f} osdevice ramdisk=[$($AjoloteDrive)]\sources\boot.wim,{7619dcc8-fafe-11d9-b411-000476eba25f}",
                "/set {0f84e3b8-bab2-4209-bf1e-7e351ad25f6f} path \windows\system32\boot\winload.efi",
                "/set {0f84e3b8-bab2-4209-bf1e-7e351ad25f6f} systemroot \windows",
                "/set {0f84e3b8-bab2-4209-bf1e-7e351ad25f6f} detecthal yes",    
                "/set {0f84e3b8-bab2-4209-bf1e-7e351ad25f6f} winpe yes",                
                "/bootsequence $($WindowsID) /addfirst",
                "/bootsequence {0f84e3b8-bab2-4209-bf1e-7e351ad25f6f} /addlast",                
                "/displayorder $($WindowsID) /addfirst",
                "/displayorder {0f84e3b8-bab2-4209-bf1e-7e351ad25f6f} /addlast",
                "/default $($WindowsID)"
                "/timeout 0"
                )
            }
                      
            foreach ($par in $Pars) {
                $parametros = "/store $($BCDPath) $($par)"
                WriteLog -Message "Execute BCDEDIT: $($parametros)" -Verbose
                $UpdateBCD = Invoke-RunPower -File "bcdedit.exe" -Params $parametros -WorkDir $PSScriptRoot -OutFile "$($logs)\BCDUpdate.log" -Verbose 
                if ($UpdateBCD -ne 0) {
                    WriteLog -Message "Not possible update BCD file" -MessageType Error -Verbose
                    return $UpdateBCD
                }
            }
        }
        if ($Environment -eq "WinPE") {
            WriteLog -Message "Swith to $($Environment) environemnt" -Verbose            
            #$WinPEGUID=bcdedit /store S:\EFI\Microsoft\Boot\BCD /enum all | Select-String "Windows Boot Loader" -Context 0,2 | ForEach-Object {$_.context.DisplayPostContext[1] -replace '^identifier +'} | Where-Object {$_ -eq "{0f84e3b8-bab2-4209-bf1e-7e351ad25f6f}"}
            $WindowsID=$DIC_BOOTLOADER | Where-Object {$_.Environment -eq "Windows OS"} | Select-Object -ExpandProperty Bootloader
            $WINPEID=$DIC_BOOTLOADER | Where-Object {$_.Environment -eq "Ajolote WinPE"} | Select-Object -ExpandProperty Bootloader
            WriteLog -Message "WinPE GUID: $($WINPEID)" -Verbose
            if ($DIC_BOOTLOADER.Environment -notcontains "Ajolote WinPE") {
                WriteLog -Message "Required create Ramdisk input" -MessageType Warning -Verbose
                $Pars = @("/create {0f84e3b8-bab2-4209-bf1e-7e351ad25f6f} -d ""Ajolote WinPE"" /application OSLOADER",
                "/create {7619dcc8-fafe-11d9-b411-000476eba25f} -d ""Ramdisk Ajolote Options"" /device",
                "/set {7619dcc8-fafe-11d9-b411-000476eba25f} ramdisksdidevice partition=$($AjoloteDrive)",
                "/set {7619dcc8-fafe-11d9-b411-000476eba25f} ramdisksdipath \boot\boot.sdi",
                "/set {0f84e3b8-bab2-4209-bf1e-7e351ad25f6f} device ramdisk=[$($AjoloteDrive)]\sources\boot.wim,{7619dcc8-fafe-11d9-b411-000476eba25f}",
                "/set {0f84e3b8-bab2-4209-bf1e-7e351ad25f6f} osdevice ramdisk=[$($AjoloteDrive)]\sources\boot.wim,{7619dcc8-fafe-11d9-b411-000476eba25f}",
                "/set {0f84e3b8-bab2-4209-bf1e-7e351ad25f6f} path \windows\system32\boot\winload.efi",
                "/set {0f84e3b8-bab2-4209-bf1e-7e351ad25f6f} systemroot \windows",
                "/set {0f84e3b8-bab2-4209-bf1e-7e351ad25f6f} detecthal yes",    
                "/set {0f84e3b8-bab2-4209-bf1e-7e351ad25f6f} winpe yes",                
                "/bootsequence {0f84e3b8-bab2-4209-bf1e-7e351ad25f6f} /addfirst",
                "/bootsequence $($WindowsID) /addlast",
                "/displayorder {0f84e3b8-bab2-4209-bf1e-7e351ad25f6f} /addfirst",
                "/displayorder $($WindowsID) /addlast",
                "/default {0f84e3b8-bab2-4209-bf1e-7e351ad25f6f}",
                "/timeout 0"
                )
            } else {
               $Pars = @("/bootsequence $($WINPEID) /addfirst",
               "/displayorder $($WINPEID) /addfirst",
               "/default $($WINPEID)",
               "/timeout 0"
               ) 
            }
            
            foreach ($par in $Pars) {
                $parametros = "/store $($BCDPath) $($par)"
                WriteLog -Message "Execute BCDEDIT: $($parametros)" -Verbose
                $UpdateBCD = Invoke-RunPower -File "bcdedit.exe" -Params $parametros -WorkDir $PSScriptRoot -OutFile "$($logs)\BCDUpdate.log" -Verbose 
                if ($UpdateBCD -ne 0) {
                    WriteLog -Message "Not possible update BCD file" -MessageType Error -Verbose
                    return $UpdateBCD
                }
            }
        }
        $null = Invoke-RunPower -File "bcdedit.exe" -Params "/store $($BCDPath) /enum all" -WorkDir $PSScriptRoot -OutFile "$($logs)\BCDAll.log" -Verbose
    }

}

