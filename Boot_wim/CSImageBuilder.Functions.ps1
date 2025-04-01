<# Global variables
$global:ScriptVer="2.0.0"
$global:MessageResults=""
$global:CodeResults=0
$global:envLogs=""
$global:envDrive=""
$global:envPath=""
$global:logs=""
$global:DebugMode=$false
#>


function Invoke-MountServer {
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true,Position=0)]
        [string] $MounParameter
    )
    $SecureMountDrive = "MountDrive.exe"
    
    if ($null -ne $MounParameter) {
        try {
            WriteLog -Message "Mount drive, parameter detected: $($MounParameter)" -Component $MyInvocation.MyCommand.Name; 
            if ($MounParameter.StartsWith("/")) {
                [xml]$con = Get-Content "$($global:envDrive)\config.xml"
                $MountOption = $MounParameter.Substring(1,$MounParameter.Length - 1);
                $MountPath="\\$($con.AJOLOTE.servername)$($con.AJOLOTE.$MountOption)";
            } else {
                $MountPath=$MounParameter;
            }           
        } catch {
            WriteLog -Message "Mount option $($MountOption) is incorrect and cannot continue" -Component $MyInvocation.MyCommand.Name; 
            return $null;
        }
        #Verify free letters
        $drvlist=(Get-PSDrive -PSProvider filesystem).Name
        $freedrv=[System.Collections.ArrayList]@()
        Foreach ($drvletter in "CDEFGHIJKLMNOPQRSTUVWYZ".ToCharArray()) {
            If ($drvlist -notcontains $drvletter) {
                $freedrv.Add($drvletter) | Out-Null
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
            WriteLog -Message "It seems like mount point [$($MountPath)] appears more than once, try to remove additionals" -Component $MyInvocation.MyCommand.Name; 
            Get-SmbMapping | Where-Object {$_.RemotePath -eq $MountPath} | Out-Host
            for ($i = 1; $i -lt $intMap; $i++) {
                $securedelete = Invoke-RunPower -File "cmd.exe" -Params "/c net use $($objMap[$i].LocalPath) /delete" -WorkDir $PSScriptRoot -OutFile "$($global:logs)\Securedelete.log"
                if ($securedelete -ne 0) {
                    WriteLog -Message "It's not possible remove additional mounted drive [$objMap[$i].LocalPath]" -MessageType Error -Component $MyInvocation.MyCommand.Name; 
                }
            }
            WriteLog -Message "Rescan current Mount points" -Component $MyInvocation.MyCommand.Name; 
            $objMap = Get-SmbMapping | Where-Object {$_.RemotePath -eq $MountPath}
        }
        if ($null -eq $objMap) {
            $secureconnect = Invoke-RunPower -File "cmd.exe" -Params "/c $($SecureMountDrive) $($MounParameter)" -WorkDir $PSScriptRoot -OutFile "$($global:logs)\Secureconnect.log"
            if ($secureconnect -ne 0) {
                WriteLog -Message "It's not possible contact or connect server share" -MessageType Error -Component $MyInvocation.MyCommand.Name; 
                return $null
            }
            $objMap = Get-SmbMapping | Where-Object {$_.RemotePath -eq $MountPath}
            if ($null -eq $objMap)
            {
                WriteLog -Message "It's not possible mount server share" -MessageType Error -Component $MyInvocation.MyCommand.Name; 
                return $null; 
            }
        }
        if ($objMap[0].Status.ToString().Trim().ToUpper() -ne "OK") {
            WriteLog -Message "Status for drive is $($objMap[0].Status.ToString()), require to wakeup" -MessageType Warning -Component $MyInvocation.MyCommand.Name; 
            $securedelete = Invoke-RunPower -File "cmd.exe" -Params "/c net use $($objMap[0].LocalPath) /delete" -WorkDir $PSScriptRoot -OutFile "$($global:logs)\Securedelete.log"
            if ($securedelete -ne 0) {
                WriteLog -Message "It's not possible remove mounted drive [$($objMap[0].LocalPath)]" -MessageType Error -Component $MyInvocation.MyCommand.Name;  
                return $null; 
            }
            $secureconnect = Invoke-RunPower -File "cmd.exe" -Params "/c $($SecureMountDrive) $($MounParameter)" -WorkDir $PSScriptRoot -OutFile "$($global:logs)\Secureconnect.log"
            if ($secureconnect -ne 0) {
                WriteLog -Message "It's not possible contact or connect server share" -MessageType Error -Component $MyInvocation.MyCommand.Name; 
                return $null
            }
            $objMap = Get-SmbMapping | Where-Object {$_.RemotePath -eq $MountPath}
            if ($null -eq $objMap) {
                WriteLog -Message "It's not possible mount server share" -MessageType Error -Component $MyInvocation.MyCommand.Name;  
                return $null; 
            }
        }
        if ($objMap[0].LocalPath.ToString().Trim().Length -ne 2) {
            WriteLog -Message "Not expecteded this value for drive assigned: [$($objMap[0].LocalPath)]" -MessageType Warning -Component $MyInvocation.MyCommand.Name; 
            return $null;
        } 
        WriteLog -Message "$($MyInvocation.MyCommand.Name) return drive: [$($objMap[0].LocalPath.ToString().Trim())]" -Component $MyInvocation.MyCommand.Name; 
        return $objMap[0].LocalPath.ToString().Trim()
    }  else {
        WriteLog -Message "This function is not designed to work without parameter, you can use tool directly" -MessageType Error -Component $MyInvocation.MyCommand.Name; 
        return $null
    }
        
}

function Update-ServerJob {
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [ValidateNotNullOrEmpty()]
        [string] $Sourcejobfile,
        [Parameter(Mandatory=$true, Position=1)]
        [ValidateNotNullOrEmpty()]
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

function Out-WinPE {
    param (
        [Parameter(Mandatory = $False)]
        [switch] $Backuplogs,
        [Parameter(Mandatory = $False)]
        [switch] $RemoveJob
    )
    Begin { 
        #Validate that information its correct
        if (!(Test-Path -Path $Global:logs -PathType Container)) { WriteLog -Message "Logs folder doesn't exist" -MessageType Error -Verbose; Exit -1;  }
        if ([string]::IsNullOrEmpty($Global:logs)) {throw [System.Exception] "Invalid folder provided"; exit -1}
        if ([string]::IsNullOrEmpty($Global:CodeResults)) {throw [System.Exception] "Not expected empty code result"; $Global:CodeResults=-1; exit -1}
        if ([string]::IsNullOrEmpty($Global:MessageResults)) {throw [System.Exception] "Not expected empty Message result"; $Global:MessageResults="No message error"; exit -1}
    }
    Process {
        try {
            WriteLog -Message "----------------------------- CLOSE WINPE --------------------------" -Component $MyInvocation.MyCommand.Name
             #Labeling codes and set pause mode when error is detected, 
             #this value is overwrite later if JOB automated is detected
            switch ($Global:CodeResults) {
                0 { $setstatus="pass"; break; }
                3010 {$setstatus="reboot"; break;}
                Default { $setstatus="fail"; $Global:DebugMode=$true; break;}
            }
            #---All folders on parent will be saved            
            $ParentFolder=(Split-Path $Global:logs -Parent)
            $SavePath=(Split-Path $ParentFolder -Parent)
            $SaveName="CSSavedLogs_$(get-date -Format "MMddyyHHmmss")"
            $jsonfile="$($global:envDrive)\job.json"
            if (Test-Path -Path $jsonfile -PathType Leaf) { 
                $json=Get-Content -Path $jsonfile -Raw | ConvertFrom-Json
                if ($null -ne $json.JOBREQUEST.Job.namejob) { 
                    $SaveName = "CSLogs_"
                    $SaveName += "$($setstatus)_"
                    $SaveName += $json.JOBREQUEST.Job.namejob.Replace(" ","_")
                    $SaveName += "_$(get-date -Format "MMddyyHHmmss")"
                }
            }
            #Logs_$($job.JOBREQUEST.namejob.ToString().Replace(" ","_"))_$((Get-WmiObject Win32_Bios).SerialNumber)
            WriteLog -Message "        Exit Message: $($Global:MessageResults)" -Component $MyInvocation.MyCommand.Name
            WriteLog -Message "           Exit Code: $($Global:CodeResults)" -Component $MyInvocation.MyCommand.Name
            WriteLog -Message "           Logs Path: $($Global:logs)" -Component $MyInvocation.MyCommand.Name
            WriteLog -Message "           Logs File: $($SaveName).zip" -Component $MyInvocation.MyCommand.Name
            if ($RemoveJob) {
                WriteLog -Message "          Remove Job: True" -Component $MyInvocation.MyCommand.Name     
            } else {
                  
                WriteLog -Message "          Remove Job: False" -Component $MyInvocation.MyCommand.Name 
            }
            Start-Process -FilePath "cmd.exe" -ArgumentList "/c bcdedit /enum all > $($Global:logs)\BCD_WinPE.log" -Wait -NoNewWindow
            #
            ### Prevent to run script if process fail and job is removed
            #
            if (($setstatus -eq "fail") -AND $RemoveJob) {
                WriteLog -Message "It was detected as failure on process and Remove Job was requested, in this scenario run registry will be removed and error flag added to image" -Verbose
                #Flag OS partition
                if (-Not(Test-Path -Path (Join-Path $global:WinDrive "\system.sav\flags"))) { New-Item -Path (Join-Path $global:WinDrive "\system.sav\flags") -ItemType Directory -Force }
                $Global:MessageResults | Out-File -FilePath (Join-Path $global:WinDrive "\system.sav\flags\csbuilderror.flg") -Encoding ascii -Force
                #remove registry unattend
                $null = Invoke-RunPower -File "cmd.exe" -Params "/c reg load  HKLM\HPImg $($global:WinDrive)\Windows\System32\Config\SOFTWARE" -WorkDir $PSScriptRoot -OutFile "$($Global:logs)\MountReg.log";
                $regkey = (Get-ItemProperty -Path HKLM:\HPImg\Microsoft\Windows\CurrentVersion\Run)
	            $regkey.PSObject.Properties | ForEach-Object {
		            if ($_.Value -like "*CSBuiltImage.*") { 
			            WriteLog -Message "Found RUN on registry for cs audit build, removing: $($_.Name)" -Verbose 
			            Remove-ItemProperty -Name $_.Name -Path HKLM:\HPImg\Microsoft\Windows\CurrentVersion\Run
		            } 
	            }

	            $maxretry=10
	            $retrycount=0
	            $SuccessUnmount=$false
                [gc]::Collect()
	            Start-Sleep 2
	            While (!($SuccessUnmount)) {
		            $retrycount++
		            $UnMountReg = Invoke-RunPower -File "cmd.exe" -Params "/c reg unload HKLM\HPImg" -WorkDir $PSScriptRoot -OutFile "$($Global:logs)\UnMountReg.log";
		            if ($UnMountReg -ne 0) { 
			            WriteLog -Message "Not successfully unmount registry[$($UnMountReg)], start sleep 6 secs and try again" -MessageType Warning -Verbose;
			            Start-Sleep -Seconds 6
		            } else {
			            $SuccessUnmount=$true
			            WriteLog -Message "Successfully unmounted registry" -Verbose
		            }
		            if ($retrycount -gt $maxretry) {
			            WriteLog -Message "Not successfully unmount registry[$($UnMountReg) after several retries" -MessageType Error -Verbose;
			            $SuccessUnmount=$true
			            
                    }
	            }
            }

            <#
            if (($setstatus -eq "pass") -AND (-Not($RemoveJob))) {
                Set-BCDEnvironment -Environment Windows
            }
            if (($setstatus -eq "reboot") -AND (-Not($RemoveJob))) {
                Set-BCDEnvironment -Environment WinPE
            }
                #>

            if (Test-Path -Path $jsonfile -PathType Leaf) {
                $json=Get-Content -Path $jsonfile -Raw | ConvertFrom-Json
                if ($null -eq $json.JOBREQUEST) { 
                    WriteLog -Message "Invalid JSON file, missing root path" -Messagetype Error -Component $MyInvocation.MyCommand.Name;
                } else {
                   
                    if ($null -ne $json.JOBREQUEST.Job) {
                       #Job detection
                        $updatestatus=$setstatus
                        if (-Not($RemoveJob) -AND($null -ne $json.JOBREQUEST.Job.status)){
                            $updatestatus=$json.JOBREQUEST.Job.status
                        }
                        if ($Backuplogs) {
                            if ($null -eq $json.JOBREQUEST.Job.logsfile){
                                $json.JOBREQUEST.Job | Add-Member -Name "logsfile" -MemberType NoteProperty -Value "$($SaveName).zip"
                            } else {
                                $json.JOBREQUEST.Job.logsfile="$($SaveName).zip"
                            }
                            $currentdate=(Get-Date).ToString("MM-dd-yy HH:mm:ss")
                            if ($null -eq $json.JOBREQUEST.Job.enddate) {
                                $json.JOBREQUEST.Job | Add-Member -Name "enddate" -MemberType NoteProperty -Value $currentdate
                            } else {
                                $json.JOBREQUEST.Job.enddate=$currentdate
                            }
                        }
                        Update-JobStatus $jsonfile $json $json.JOBREQUEST.Job $updatestatus $Global:MessageResults
                    }
                    if ($null -ne $json.JOBREQUEST.Control) {
                        $updatestatus=$setstatus
                        if (-Not($RemoveJob) -AND ($null -eq $json.JOBREQUEST.Control.status)){
                            $updatestatus=$json.JOBREQUEST.Control.status
                        }
                        if ($Backuplogs) {
                            if ($null -eq $json.JOBREQUEST.Control.logsfile){
                                $json.JOBREQUEST.Control | Add-Member -Name "logsfile" -MemberType NoteProperty -Value "$($SaveName).zip"
                            } else {
                                $json.JOBREQUEST.Control.logsfile="$($SaveName).zip"
                            }
                        }
                        Update-JobStatus $jsonfile $json $json.JOBREQUEST.Control $updatestatus $Global:MessageResults
                     }
                    
                    if ($null -ne $json.JOBREQUEST.Job.namejob) { 
                        #Even with errors, when Job exist must continue
                        $Global:DebugMode=$false;
                        $MountPoint=Invoke-MountServer "/jobpath"
                        if ($null -ne $MountPoint) {
                            WriteLog -Message "Copying Job.json file to Server" -Component $MyInvocation.MyCommand.Name
                            Copy-Item -Path $jsonfile -Destination "$($MountPoint)\$($json.JOBREQUEST.Job.namejob).job" -Force
                        } else {
                            WriteLog -Message "Not possible mount Jobs share" -MessageType Error -Component $MyInvocation.MyCommand.Name
                        }
                    }                    
                }    
                $jobsavename="job.json"
                switch ($Global:CodeResults) {
                    0 { $jobsavename="job.json"; break; }
                    3010 {$jobsavename="reboot.job.json"; break;}
                    Default { $jobsavename="job.err"; break;}
                }
                Copy-Item $jsonfile (Join-Path $Global:logs $jobsavename) -Force            
            }

            if (($Backuplogs) -AND (Test-Path -Path $Global:logs -PathType Container)){   
                if (($Global:CodeResults -ne 0) -AND ($Global:CodeResults -ne 3010)) {
                    if (Test-Path (Join-Path $global:WinDrive "\Windows\System32\Sysprep\Panther")) {
                        $null = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy $((Join-Path $global:WinDrive "\Windows\System32\Sysprep\Panther"))\*.log $(Join-Path $Global:logs "\WindowsLogsSysprep")\" -WorkDir $PSScriptRoot -OutFile "$($Global:logs)\MoveWinLogs.log";
                    }
                    if (Test-Path (Join-Path $global:WinDrive "\Windows\Panther")) {
                        $null = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy $((Join-Path $global:WinDrive "\Windows\Panther"))\*.log $(Join-Path $Global:logs "\WindowsLogsPanther")\" -WorkDir $PSScriptRoot -OutFile "$($Global:logs)\MoveWinLogs.log";
                    }
                    if (Test-Path (Join-Path $global:WinDrive "\Windows\Panther\UnattendGC")) {
                        $null = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy $((Join-Path $global:WinDrive "\Windows\Panther\UnattendGC"))\*.log $(Join-Path $Global:logs "\WindowsLogsUnattendGC")\" -WorkDir $PSScriptRoot -OutFile "$($Global:logs)\MoveWinLogs.log";
                    }
                }             
                WriteLog -Message "Capture Folders Path: $($ParentFolder)" -Component $MyInvocation.MyCommand.Name
                New-Item -Path (Join-Path $SavePath "Ajolote") -ItemType Container -Force | Out-Null
			    Get-ChildItem -Path $SavePath -Directory -Exclude "Ajolote" | ForEach-Object { WriteLog -Message "`tMoving for package logs: $($_.FullName)" -Verbose; Copy-Item -Path $_.FullName -Destination "$($SavePath)\Ajolote\$($_.Name)" -Recurse -Force -Container -ErrorAction SilentlyContinue}					
			    Compress-Archive -Path "$($SavePath)\Ajolote" -DestinationPath "$($SavePath)\$($SaveName).zip" -CompressionLevel Optimal -Force
                
                #Move log files to share
                if ($null -ne $json.JOBREQUEST.Job.namejob) { 
                    #mount logs share
                    $ShareLogs=Invoke-MountServer "/logspath"
                    if ($null -ne $ShareLogs) {
                        Write-Host "Copying logs file to Server, please wait..."
                        Copy-Item -Path "$($SavePath)\$($SaveName).zip" -Destination (Join-Path $ShareLogs "$($SaveName).zip") -Force
                        if (!(Test-Path -Path (Join-Path $ShareLogs "$($SaveName).zip") -PathType Leaf )) {
                            Write-Host "Log File was not copied: $(Join-Path $ShareLogs ""$($SaveName).zip"")" -ForegroundColor Red -BackgroundColor Yellow
                            Read-Host -Prompt "Please check"
                        }
                        Start-Sleep -Seconds 15    
                    } else {
                        Write-Host "Not possible mount Logs share" -ForegroundColor Red -BackgroundColor Yellow  
                        Write-Host "    Not possible mount Logs share" -ForegroundColor Red -BackgroundColor Yellow  
                        Write-Host "        Not possible mount Logs share" -ForegroundColor Red -BackgroundColor Yellow  
                        Write-Host "            Not possible mount Logs share" -ForegroundColor Red -BackgroundColor Yellow  
                        Start-Sleep -Seconds 15         
                        Read-Host -Prompt "Please check"        
                    }
                }

                #its expected that not all folder can be removed, specially current since its been used by logs
                try {
                    $null = Stop-Transcript
                } Catch {
                    Write-Host "Not detected transcription running" -ForegroundColor Red -BackgroundColor Yellow
                }
			    Get-ChildItem -Path $SavePath -Directory | ForEach-Object { Remove-Item -Path $_.FullName -Force -Recurse -ErrorAction SilentlyContinue }
            }
            if ($RemoveJob) {                
                $retry=0
                $maxretry=20
                While (Test-Path -Path $jsonfile -PathType Leaf) {
                    $retry++;
                    Write-Host "Removing job, retry $($retry)/$($maxretry)"
                    Remove-Item -Path $jsonfile -Force
                    if ($retry -eq $maxretry) { break; }
                    start-sleep -Seconds 3
                }   
                if (Test-Path (Join-Path $global:envDrive "/system.sav/temp") -PathType Container) { Remove-Item -Path (Join-Path $global:envDrive "/system.sav/temp") -Recurse -Force -ErrorAction SilentlyContinue}
            }

        }
        catch {
            $ErrorMessage = $_.Exception.Message
			#throw [System.Exception]  "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)"
            Write-Host "[EXCEPTION ERROR] - Error: $($ErrorMessage)" -BackgroundColor Black -ForegroundColor Red
            Write-Host "`r`n`r`nPRESS ANY KEY TO EXIT"
            $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    }
    End {
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c bcdedit /timeout 0" -Wait -NoNewWindow
        if ($Global:DebugMode) {
            Write-Host "___________________________________________________________________________________________________" -ForegroundColor Yellow -BackgroundColor Red
            Write-Host "___________________________________________________________________________________________________" -ForegroundColor Yellow -BackgroundColor Red
            Write-Host "___________________________________________________________________________________________________" -ForegroundColor Yellow -BackgroundColor Red
            Write-Host "___________________________________________________________________________________________________" -ForegroundColor Yellow -BackgroundColor Red
            Write-Host $Global:MessageResults
            Write-Host "                      CODE ERROR $($Global:CodeResults)"
            Write-Host "___________________________________________________________________________________________________" -ForegroundColor Yellow -BackgroundColor Red
            Write-Host "___________________________________________________________________________________________________" -ForegroundColor Yellow -BackgroundColor Red
            Write-Host "___________________________________________________________________________________________________" -ForegroundColor Yellow -BackgroundColor Red
            Write-Host "___________________________________________________________________________________________________" -ForegroundColor Yellow -BackgroundColor Red
            Start-Process powershell  -Wait
            Restart-Computer -Force
            Start-Sleep -Seconds 10
            Stop-Process -Id $global:MainID -Force
            Exit $Global:CodeResults
        } else {
            #$null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            #Start-Process powershell  -Wait
            #Restart-Computer -Force
            wpeutil reboot
            Start-Sleep -Seconds 10
            Stop-Process -Id $global:MainID -Force
            Exit 0
        }
    }
}



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
        $intCounter=0
        $intMaximum=10
        $boolRetry=$true
        while ($boolRetry) {
            ### Save JOB file
            try {
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
                $JsonObject | ConvertTo-Json -Depth 16 | Out-File -FilePath $Path -Encoding ascii -Force
                $boolRetry=$false;
            } catch {
                $ErrorMessage = $_.Exception.Message
                WriteLog -Message "Failed updating JOB file: $($ErrorMessage)" -MessageType Error -Verbose
                $global:MessageResults="Failed updating JOB file: $($ErrorMessage)"
                $global:CodeResults=209
                if ($intCounter -gt $intMaximum) {
                    WriteLog -Message "Maximum reties reached, abort process" -MessageType Error -Verbose
                    Out-WinPE -Backuplogs
                    $global:MessageResults | Out-Null
                    $global:CodeResults | Out-Null
                    return;
                }
                Start-Sleep -Seconds 2;
            }
            
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
            Out-WinPE -Backuplogs
            $global:MessageResults | Out-Null
            $global:CodeResults | Out-Null
        }
    } else {
        WriteLog -Message "JSON path doesn't exist, check object $($JsonPath)" -MessageType Error -Verbose
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
.Vendor
    Vendor name
.PN
    Part Number
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


function Invoke-XMLBuild {
    param (
        [Parameter(Mandatory = $true)]
        [string] $XMLFileName,
        [Parameter(Mandatory = $false)]
        [string] $platform="",
		[Parameter(Mandatory = $true)]
        [string] $spnumber,
        [Parameter(Mandatory = $true)]
        [string] $spname,
        [Parameter(Mandatory = $true)]
        [string] $spsilent,
        [Parameter(Mandatory = $true)]
        [string] $spversion,
        [Parameter(Mandatory = $true)]
        [string] $spfolder,
        [Parameter(Mandatory = $true)]
        [string] $spcodes,
        [Parameter(Mandatory = $false)]
        [string] $spenable="no"
    )
    try {
        if (Test-Path -Path $XMLFileName -PathType Leaf) {
            Write-Host "HPCOMPLETE[XML] file already exist, adding new node"
            [xml]$xml = Get-Content $XMLFileName
            $rootnode = $xml.DocumentElement
            if ($null -eq $rootnode) {Write-Error "XMl file is damaged"; Stop-Transcript; exit 101}
            if ($rootnode.Name -ne "HPDRIVERS") {Write-Error "XML file hasn't expected format, incorrect Root Node Name: $($rootnode.Name)"}
            if ($rootnode.model -ne $platform) {
                Write-Host "`tUpdating Model, from $($rootnode.model) to $($platform)"
                $rootnode.model=$platform
            }
            if ($null -eq $rootnode.SelectSingleNode("DRIVER[@id='$($spnumber)']")) {
                Write-Host "`tNew node doesn't exist, add new one"
                $node = $xml.CreateElement("DRIVER")
                $node.SetAttribute("id",$spnumber)
                $node.SetAttribute("persist","true")
                $node.SetAttribute("reboot","false")
                $node.SetAttribute("limitless","false")                
                $rootnode.AppendChild($node) 
                    $nodesp = $xml.CreateElement("sp")
                    $nodesp.InnerText = $spnumber
                    $node.AppendChild($nodesp) | Out-Null
                    $nodename = $xml.CreateElement("name")
                    $nodename.InnerText = $spname
                    $node.AppendChild($nodename) | Out-Null
                    $nodesilent = $xml.CreateElement("silent")
                    $nodesilent.InnerText = $spsilent
                    $node.AppendChild($nodesilent) | Out-Null
                    $nodeversion = $xml.CreateElement("version")
                    $nodeversion.InnerText = $spversion
                    $node.AppendChild($nodeversion) | Out-Null
                    $nodefolder = $xml.CreateElement("folder")
                    $nodefolder.InnerText = $spfolder
                    $node.AppendChild($nodefolder) | Out-Null
                    $nodeerrorcode = $xml.CreateElement("errorcode")
                    $nodeerrorcode.InnerText = $spcodes
                    $node.AppendChild($nodeerrorcode) | Out-Null
                    $nodeenable = $xml.CreateElement("enable")
                    $nodeenable.InnerText = $spenable
                    $node.AppendChild($nodeenable) | Out-Null
                    $xml.Save($XMLFileName)
            } else {
                Write-Host "`tThis SP was alredy present on current XML $($XMLFileName)"
                $rootnode.SelectSingleNode("DRIVER[@id='$($spnumber)']")
            }
        } else {
    #---- XML doesn't exist and created adding node
            Write-Host "HPCOMPLETE[XML] doesn't exist, create and add node"
            $XmlWriter = New-Object System.XMl.XmlTextWriter($XMLFileName,$Null)   
            $xmlWriter.Formatting = "Indented"
            $xmlWriter.Indentation = "4"
            $xmlWriter.WriteStartDocument()
            $xmlWriter.WriteStartElement("HPDRIVERS")
            $XmlWriter.WriteAttributeString("rootpath","C:\HPDrivers")
            $XmlWriter.WriteAttributeString("cleanroot","true")
            $XmlWriter.WriteAttributeString("reboot","false")
            $XmlWriter.WriteAttributeString("pcname","*")
            $XmlWriter.WriteAttributeString("model",$platform)
            #---Node
                $xmlWriter.WriteStartElement("DRIVER")
                $XmlWriter.WriteAttributeString("id", $spnumber)
                $XmlWriter.WriteAttributeString("persist", "true")
                $XmlWriter.WriteAttributeString("reboot", "false")
                $XmlWriter.WriteAttributeString("limitless", "false")
                #---Element
                    $xmlWriter.WriteElementString("sp",$spnumber)
                    $xmlWriter.WriteElementString("name",$spname)
                    $xmlWriter.WriteElementString("silent",$spsilent)
                    $xmlWriter.WriteElementString("version",$spversion)
                    $xmlWriter.WriteElementString("folder",$spfolder)
                    $xmlWriter.WriteElementString("errorcode",$spcodes)
                    $xmlWriter.WriteElementString("enable",$spenable)
                $XmlWriter.WriteEndElement()
        #--- end Doc
            $xmlWriter.WriteEndElement()
		$xmlWriter.WriteEndDocument()  
		$xmlWriter.Flush()  
		$xmlWriter.Close()
        }
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        Write-Error "Error creating HPCOMPLETE[XML] file: $($ErrorMessage)"
    }
}


function Convert-Languagtag {
    param (
        [Parameter(Mandatory = $true, Position=0)]
        [string]$InputLanguage,
        [Parameter(Mandatory=$false, Position=1)]
        [ValidateSet("Windows 10","Windows 11")]
        [string]$WindowsEdition
    )
    Begin {
        #default value for Windows Edition
        if ([string]::IsNullOrEmpty($WindowsEdition)) {$WindowsEdition="Windows 10"}
        #Convert encode 
        $enc = [System.Text.Encoding]::UTF8
        $encoded=$enc.GetBytes($InputLanguage)
        $InputLanguage=[System.Text.Encoding]::ASCII.GetString($encoded)
        
        WriteLog -Message "Searching $($InputLanguage)" -Verbose
        WriteLog -Message "for OS $($WindowsEdition)" -Verbose
        #definitions Windows 10
        [string[]]$LanguageRegion10=@("Arabic (Saudi Arabia)","Basque (Basque)","Bulgarian (Bulgaria)","Catalan","Chinese (Simplified, China)","Chinese (Traditional, Taiwan)","Croatian (Croatia)","Czech (Czech Republic)","Danish (Denmark)","Dutch (Netherlands)","English (United States)","English (United Kingdom)","Estonian (Estonia)","Finnish (Finland)","French (Canada)","French (France)","Galician","German (Germany)","Greek (Greece)","Hebrew (Israel)","Hungarian (Hungary)","Indonesian (Indonesia)","Italian (Italy)","Japanese (Japan)","Korean (Korea)","Latvian (Latvia)","Lithuanian (Lithuania)","Norwegian, Bokmål (Norway)","Polish (Poland)","Portuguese (Brazil)","Portuguese (Portugal)","Romanian (Romania)","Russian (Russia)","Serbian (Latin, Serbia)","Slovak (Slovakia)","Slovenian (Slovenia)","Spanish (Mexico)","Spanish (Spain)","Swedish (Sweden)","Thai (Thailand)","Turkish (Turkey)","Ukrainian (Ukraine)","Vietnamese")
        [string[]]$LanguageTag10=@("ar-SA","eu-ES","bg-BG","ca-ES","zh-CN","zh-TW","hr-HR","cs-CZ","da-DK","nl-NL","en-US","en-GB","et-EE","fi-FI","fr-CA","fr-FR","gl-ES","de-DE","el-GR","he-IL","hu-HU","id-ID","it-IT","ja-JP","ko-KR","lv-LV","lt-LT","nb-NO","pl-PL","pt-BR","pt-PT","ro-RO","ru-RU","sr-Latn-RS","sk-SK","sl-SI","es-MX","es-ES","sv-SE","th-TH","tr-TR","uk-UA","vi-VN")
        [string[]]$LanguageHEXID10=@("0x0401","0x042d","0x0402","0x0403","0x0804","0x0404","0x041a","0x0405","0x0406","0x0413","0x0409","0x0809","0x0425","0x040b","0x0c0c","0x040c","0x0456","0x0407","0x0408","0x040d","0x040e","0x0421","0x0410","0x0411","0x0412","0x0426","0x0427","0x0414","0x0415","0x0416","0x0816","0x0418","0x0419","0x241A","0x041b","0x0424","0x080a","0x0c0a","0x041d","0x041e","0x041f","0x0422","0x042a")
        [string[]]$LanguageDECID10=@("1025","1069","1026","1027","2052","1028","1050","1029","1030","1043","1033","2057","1061","1035","3084","1036","1110","1031","1032","1037","1038","1057","1040","1041","1042","1062","1063","1044","1045","1046","2070","1048","1049","9242","1051","1060","2058","3082","1053","1054","1055","1058","1066")
        [string[]]$LIPRegion10=@("Afrikaans (South Africa)","Albanian (Albania)","Amharic (Ethiopia)","Armenian (Armenia)","Assamese (India)","Azerbaijan","Bangla (Bangladesh)","Basque (Basque)","Belarusian","Bangla (India)","Bosnian (Latin)","Catalan","Central Kurdish","Cherokee","Dari","Filipino","Galician","Georgian (Georgia)","Gujarati (India)","Hausa (Latin, Nigeria)","Hindi (India)","Icelandic (Iceland)","Igbo (Nigeria)","Indonesian (Indonesia)","Irish (Ireland)","isiXhosa (South Africa)","isiZulu (South Africa)","Kannada (India)","Kazakh (Kazakhstan)","Khmer (Cambodia)","K'iche' (Guatemala)","Kinyarwanda","Kiswahili (Kenya)","Konkani (India)","Kyrgyz (Kyrgyzstan)","Lao (Laos)","Luxembourgish (Luxembourg)","Macedonian (FYROM)","Malay (Malaysia, Brunei, and Singapore)","Malayalam (India)","Maltese (Malta)","Maori (New Zealand)","Marathi (India)","Mongolian (Cyrillic)","Nepali (Federal Democratic Republic of Nepal)","Norwegian, Nynorsk (Norway)","Odia (India)","Persian","Punjabi (India)","Punjabi (Arabic)","Quechua (Peru)","Scottish Gaelic","Serbian (Cyrillic, Bosnia and Herzegovina)","Serbian (Cyrillic, Serbia)","Sesotho sa Leboa (South Africa)","Setswana (South Africa)","Sindhi (Arabic)","Sinhala (Sri Lanka)","Tajik (Cyrillic)","Tamil (India)","Tatar (Russia)","Telugu (India)","Tigrinya","Turkmen","Urdu","Uyghur","Uzbek (Latin)","Valencian","Vietnamese","Welsh (Great Britain)","Wolof","Yoruba (Nigeria)")
        [string[]]$LIPTag10=@("af-ZA","sq-AL","am-ET","hy-AM","as-IN","az-Latn-AZ","bn-BD","eu-ES","be-BY","bn-IN","bs-Latn-BA","ca-ES","ku-ARAB-IQ","chr-CHER-US","prs-AF","fil-PH","gl-ES","ka-GE","gu-IN","ha-Latn-NG","hi-IN","is-IS","ig-NG","id-ID","ga-IE","xh-ZA","zu-ZA","kn-IN","kk-KZ","km-KH","quc-Latn-GT","rw-RW","sw-KE","kok-IN","ky-KG","lo-LA","lb-LU","mk-MK","ms-MY","ml-IN","mt-MT","mi-NZ","mr-IN","mn-MN","ne-NP","nn-NO","or-IN","fa-IR","pa-IN","pa-Arab-PK","quz-PE","gd-GB","sr-Cyrl-BA","sr-Cyrl-RS","nso-ZA","tn-ZA","sd-Arab-PK","si-LK","tg-Cyrl-TJ","ta-IN","tt-RU","te-IN","ti-ET","tk-TM","ur-PK","ug-CN","uz-Latn-UZ","ca-ES-valencia","vi-VN","cy-GB","wo-SN","yo-NG")
        [string[]]$LIPHEXID10=@("0x0436","0x041c","0x045e","0x042b","0x044d","0x042c","0x0845","0x042d","0x0423","0x0445","0x141a","0x0403","0x0492","0x045c","0x048c","0x0464","0x0456","0x0437","0x0447","0x0468","0x0439","0x040f","0x0470","0x0421","0x083c","0x0434","0x0435","0x044b","0x043f","0x0453","0x0486","0x0487","0x0441","0x0457","0x0440","0x0454","0x046e","0x042f","0x043e","0x044c","0x043a","0x0481","0x044e","0x0450","0x0461","0x0814","0x0448","0x0429","0x0446","0x0846","0x0c6b","0x0491","0x1C1A","0x281A","0x046c","0x0432","0x0859","0x045b","0x0428","0x0449","0x0444","0x044a","0x0473","0x0442","0x0420","0x0480","0x0443","0x0803","0x042a","0x0452","0x0488","0x046a")
        [string[]]$LIPDECID10=@("1078","1052","1118","1067","1101","1068","2117","1069","1059","1093","5146","1027","1170","1116","1164","1124","1110","1079","1095","1128","1081","1039","1136","1057","2108","1076","1077","1099","1087","1107","1158","1159","1089","1111","1088","1108","1134","1071","1086","1100","1082","1153","1102","1104","1121","2068","1096","1065","1094","2118","3179","1169","7194","10266","1132","1074","2137","1115","1064","1097","1092","1098","1139","1090","1056","1152","1091","2051","1066","1106","1160","1130")

        #definitions Windows 11
        [string[]]$LanguageRegion11=@("Arabic (Saudi Arabia)","Basque (Basque)","Bulgarian (Bulgaria)","Catalan","Chinese (Simplified, China)","Chinese (Traditional, Taiwan)","Croatian (Croatia)","Czech (Czech Republic)","Danish (Denmark)","Dutch (Netherlands)","English (United States)","English (United Kingdom)","Estonian (Estonia)","Finnish (Finland)","French (Canada)","French (France)","Galician","German (Germany)","Greek (Greece)","Hebrew (Israel)","Hungarian (Hungary)","Indonesian (Indonesia)","Italian (Italy)","Japanese (Japan)","Korean (Korea)","Latvian (Latvia)","Lithuanian (Lithuania)","Norwegian, Bokmål (Norway)","Polish (Poland)","Portuguese (Brazil)","Portuguese (Portugal)","Romanian (Romania)","Russian (Russia)","Serbian (Latin, Serbia)","Slovak (Slovakia)","Slovenian (Slovenia)","Spanish (Mexico)","Spanish (Spain)","Swedish (Sweden)","Thai (Thailand)","Turkish (Turkey)","Ukrainian (Ukraine)","Vietnamese")
        [string[]]$LanguageTag11=@("ar-SA","eu-ES","bg-BG","ca-ES","zh-CN","zh-TW","hr-HR","cs-CZ","da-DK","nl-NL","en-US","en-GB","et-EE","fi-FI","fr-CA","fr-FR","gl-ES","de-DE","el-GR","he-IL","hu-HU","id-ID","it-IT","ja-JP","ko-KR","lv-LV","lt-LT","nb-NO","pl-PL","pt-BR","pt-PT","ro-RO","ru-RU","sr-Latn-RS","sk-SK","sl-SI","es-MX","es-ES","sv-SE","th-TH","tr-TR","uk-UA","vi-VN")
        [string[]]$LanguageHEXID11=@("0x0401","0x042d","0x0402","0x0403","0x0804","0x0404","0x041a","0x0405","0x0406","0x0413","0x0409","0x0809","0x0425","0x040b","0x0c0c","0x040c","0x0456","0x0407","0x0408","0x040d","0x040e","0x0421","0x0410","0x0411","0x0412","0x0426","0x0427","0x0414","0x0415","0x0416","0x0816","0x0418","0x0419","0x241A","0x041b","0x0424","0x080a","0x0c0a","0x041d","0x041e","0x041f","0x0422","0x042a")
        [string[]]$LanguageDECID11=@("1025","1069","1026","1027","2052","1028","1050","1029","1030","1043","1033","2057","1061","1035","3084","1036","1110","1031","1032","1037","1038","1057","1040","1041","1042","1062","1063","1044","1045","1046","2070","1048","1049","9242","1051","1060","2058","3082","1053","1054","1055","1058","1066")
        [string[]]$LIPRegion11=@("Afrikaans (South Africa)","Albanian (Albania)","Amharic (Ethiopia)","Armenian (Armenia)","Assamese (India)","Azerbaijan","Basque (Basque)","Belarusian","Bangla (India)","Bosnian (Latin)","Catalan","Cherokee","Filipino","Galician","Georgian (Georgia)","Gujarati (India)","Hindi (India)","Icelandic (Iceland)","Indonesian (Indonesia)","Irish (Ireland)","Kannada (India)","Kazakh (Kazakhstan)","Khmer (Cambodia)","Konkani (India)","Lao (Laos)","Luxembourgish (Luxembourg)","Macedonian (FYROM)","Malay (Malaysia, Brunei, and Singapore)","Malayalam (India)","Maltese (Malta)","Maori (New Zealand)","Marathi (India)","Nepali (Federal Democratic Republic of Nepal)","Norwegian, Nynorsk (Norway)","Odia (India)","Persian","Punjabi (India)","Quechua (Peru)","Scottish Gaelic","Serbian (Cyrillic, Bosnia and Herzegovina)","Serbian (Cyrillic, Serbia)","Tamil (India)","Tatar (Russia)","Telugu (India)","Urdu","Uyghur","Uzbek (Latin)","Valencian","Vietnamese","Welsh (Great Britain)")
        [string[]]$LIPTag11=@("af-ZA","sq-AL","am-ET","hy-AM","as-IN","az-Latn-AZ","eu-ES","be-BY","bn-IN","bs-Latn-BA","ca-ES","chr-CHER-US","fil-PH","gl-ES","ka-GE","gu-IN","hi-IN","is-IS","id-ID","ga-IE","kn-IN","kk-KZ","km-KH","kok-IN","lo-LA","lb-LU","mk-MK","ms-MY","ml-IN","mt-MT","mi-NZ","mr-IN","ne-NP","nn-NO","or-IN","fa-IR","pa-IN","quz-PE","gd-GB","sr-Cyrl-BA","sr-Cyrl-RS","ta-IN","tt-RU","te-IN","ur-PK","ug-CN","uz-Latn-UZ","ca-ES-valencia","vi-VN","cy-GB")
        [string[]]$LIPHEXID11=@("0x0436","0x041c","0x045e","0x042b","0x044d","0x042c","0x042d","0x0423","0x0445","0x141a","0x0403","0x045c","0x0464","0x0456","0x0437","0x0447","0x0439","0x040f","0x0421","0x083c","0x044b","0x043f","0x0453","0x0457","0x0454","0x046e","0x042f","0x043e","0x044c","0x043a","0x0481","0x044e","0x0461","0x0814","0x0448","0x0429","0x0446","0x0c6b","0x0491","0x1C1A","0x281A","0x0449","0x0444","0x044a","0x0420","0x0480","0x0443","0x0803","0x042a","0x0452")
        [string[]]$LIPDECID11=@("1078","1052","1118","1067","1101","1068","1069","1059","1093","5146","1027","1116","1124","1110","1079","1095","1081","1039","1057","2108","1099","1087","1107","1111","1108","1134","1071","1086","1100","1082","1153","1102","1121","2068","1096","1065","1094","3179","1169","7194","10266","1097","1092","1098","1056","1152","1091","2051","1066","1106")

        $returnObj = New-Object PSObject
    }
    Process {
        #Validate that definitions are correctly
        if ($WindowsEdition -eq "Windows 10") {
            if (($LanguageDECID10.Count -ne $LanguageHEXID10.Count) -OR ($LanguageRegion10.Count -ne $LanguageTag10.Count) -OR ($LanguageRegion10.Count -ne$LanguageDECID10.Count)) {
                WriteLog -Message "Missing number of languages for Windows 10, check code for definitions" -MessageType Error -Verbose
                return $null
            } else {
                WriteLog -Message "Loaded $($LanguageRegion10.Length) Language packs for $($WindowsEdition)" -Verbose
            }
            if (($LIPHEXID10.Count -ne $LIPDECID10.Count) -OR ($LIPRegion10.Count -ne $LIPTag10.Count) -OR ($LIPRegion10.Count -ne$LIPDECID10.Count)) {
                WriteLog -Message "Missing number of LIPs for Windows 10, check code for definitions" -MessageType Error -Verbose
                return $null
            } else {
                WriteLog -Message "Loaded $($LIPRegion10.Length) Language interface packs for $($WindowsEdition)" -Verbose
            }
            #normalyze encode characers
            $NormalLanguageRegion = [System.Collections.ArrayList]::new()
            $LanguageRegion10 | ForEach-Object {
                $encoded=$enc.GetBytes($_)
                [void]$NormalLanguageRegion.Add([System.Text.Encoding]::ASCII.GetString($encoded))
            }
            $LanguageRegion10=$NormalLanguageRegion
        
            WriteLog -Message "Valid definitions for $($WindowsEdition), continue" -Verbose
            
            $Win10 =@{Region=$LanguageRegion10;Tag=$LanguageTag10;HEX=$LanguageHEXID10;DEC=$LanguageDECID10}
            $Win10LIP =@{Region=$LIPRegion10;Tag=$LIPTag10;HEX=$LIPHEXID10;DEC=$LIPDECID10}
            if ($Win10.Region.ToLower().Contains($InputLanguage.ToLower().Trim())) {
                WriteLog -Message "Identified as Language Region" -Verbose
                for ($i=0;$i -lt $Win10.Region.Count; $i++) {
                    if ($Win10.Region[$i].ToLower() -eq $InputLanguage.ToLower().Trim()) { 
                        WriteLog -Message "`tIndex: $($i)" -Verbose
                        $dec= [System.Text.Encoding]::Default
                        $Decoded=$dec.GetBytes($Win10.Region[$i])
                        $PropName=[System.Text.Encoding]::UTF8.GetString($Decoded)
                        $returnObj | Add-Member NoteProperty Region $PropName
                        $returnObj | Add-Member NoteProperty Tag $Win10.Tag[$i]
                        $returnObj | Add-Member NoteProperty HEX $Win10.HEX[$i]
                        $returnObj | Add-Member NoteProperty DEC $Win10.DEC[$i]
                        WriteLog -Message "`tTag: $($Win10.Tag[$i])" -Verbose
                    }
                }
            } elseif ($Win10.Tag.ToLower().Contains($InputLanguage.ToLower().Trim())) {
                WriteLog -Message "Identified as Language Tag" -Verbose
                for ($i=0;$i -lt $Win10.Tag.Count; $i++) {
                    if ($Win10.Tag[$i].ToLower() -eq $InputLanguage.ToLower().Trim()) { 
                        WriteLog -Message "`tIndex: $($i)" -Verbose
                        $dec= [System.Text.Encoding]::Default
                        $Decoded=$dec.GetBytes($Win10.Region[$i])
                        $PropName=[System.Text.Encoding]::UTF8.GetString($Decoded)
                        $returnObj | Add-Member NoteProperty Region $PropName
                        $returnObj | Add-Member NoteProperty Tag $Win10.Tag[$i]
                        $returnObj | Add-Member NoteProperty HEX $Win10.HEX[$i]
                        $returnObj | Add-Member NoteProperty DEC $Win10.DEC[$i]
                        WriteLog -Message "`tRegion: $($PropName)" -Verbose
                    }
                }
            } elseif ($Win10LIP.Region.ToLower().Contains($InputLanguage.ToLower().Trim())) {
                WriteLog -Message "Identified as Language Interface Region" -Verbose
                for ($i=0;$i -lt $Win10LIP.Region.Count; $i++) {
                    if ($Win10LIP.Region[$i].ToLower() -eq $InputLanguage.ToLower().Trim()) { 
                        WriteLog -Message "`tIndex: $($i)" -Verbose
                        $dec= [System.Text.Encoding]::Default
                        $Decoded=$dec.GetBytes($Win10.Region[$i])
                        $PropName=[System.Text.Encoding]::UTF8.GetString($Decoded)
                        $returnObj | Add-Member NoteProperty Region $PropName
                        $returnObj | Add-Member NoteProperty Tag $Win10LIP.Tag[$i]
                        $returnObj | Add-Member NoteProperty HEX $Win10LIP.HEX[$i]
                        $returnObj | Add-Member NoteProperty DEC $Win10LIP.DEC[$i]
                        WriteLog -Message "`tTag: $($Win10LIP.Tag[$i])" -Verbose
                    }
                }
            } elseif ($Win10LIP.Tag.ToLower().Contains($InputLanguage.ToLower().Trim())) {
                WriteLog -Message "Identified as Language Interface Tag" -Verbose
                for ($i=0;$i -lt $Win10LIP.Tag.Count; $i++) {
                    if ($Win10LIP.Tag[$i].ToLower() -eq $InputLanguage.ToLower().Trim()) { 
                        WriteLog -Message "`tIndex: $($i)" -Verbose
                        $dec= [System.Text.Encoding]::Default
                        $Decoded=$dec.GetBytes($Win10.Region[$i])
                        $PropName=[System.Text.Encoding]::UTF8.GetString($Decoded)
                        $returnObj | Add-Member NoteProperty Region $PropName
                        $returnObj | Add-Member NoteProperty Tag $Win10LIP.Tag[$i]
                        $returnObj | Add-Member NoteProperty HEX $Win10LIP.HEX[$i]
                        $returnObj | Add-Member NoteProperty DEC $Win10LIP.DEC[$i]
                        WriteLog -Message "`tRegion: $($PropName)" -Verbose
                    }
                }
            }
        } else {
            if (($LanguageDECID11.Count -ne $LanguageHEXID11.Count) -OR ($LanguageRegion11.Count -ne $LanguageTag11.Count) -OR ($LanguageRegion11.Count -ne$LanguageDECID11.Count)) {
                WriteLog -Message "Missing number of languages for Windows 11, check code for definitions" -MessageType Error -Verbose
                return $null
            } else {
                WriteLog -Message "Loaded $($LanguageRegion11.Length) Language packs for $($WindowsEdition)" -Verbose
            }
            if (($LIPHEXID11.Count -ne $LIPDECID11.Count) -OR ($LIPRegion11.Count -ne $LIPTag11.Count) -OR ($LIPRegion11.Count -ne$LIPDECID11.Count)) {
                WriteLog -Message "Missing number of LIPs for Windows 11, check code for definitions" -MessageType Error -Verbose
                return $null
            } else {
                WriteLog -Message "Loaded $($LIPRegion11.Length) Language interface packs for $($WindowsEdition)" -Verbose
            }
            #normalyze encode characers
            $NormalLanguageRegion = [System.Collections.ArrayList]::new()
            $LanguageRegion11 | ForEach-Object {
                $encoded=$enc.GetBytes($_)
                [void]$NormalLanguageRegion.Add([System.Text.Encoding]::ASCII.GetString($encoded))
            }
            $LanguageRegion11=$NormalLanguageRegion
        
            WriteLog -Message "Valid definitions for $($WindowsEdition), continue" -Verbose
            
            $Win11 =@{Region=$LanguageRegion11;Tag=$LanguageTag11;HEX=$LanguageHEXID11;DEC=$LanguageDECID11}
            $Win11LIP =@{Region=$LIPRegion11;Tag=$LIPTag11;HEX=$LIPHEXID11;DEC=$LIPDECID11}
            if ($Win11.Region.ToLower().Contains($InputLanguage.ToLower().Trim())) {
                WriteLog -Message "Identified as Language Region" -Verbose
                for ($i=0;$i -lt $Win11.Region.Count; $i++) {
                    if ($Win11.Region[$i].ToLower() -eq $InputLanguage.ToLower().Trim()) { 
                        WriteLog -Message "`tIndex: $($i)" -Verbose
                        $dec= [System.Text.Encoding]::Default
                        $Decoded=$dec.GetBytes($Win11.Region[$i])
                        $PropName=[System.Text.Encoding]::UTF8.GetString($Decoded)
                        $returnObj | Add-Member NoteProperty Region $PropName
                        $returnObj | Add-Member NoteProperty Tag $Win11.Tag[$i]
                        $returnObj | Add-Member NoteProperty HEX $Win11.HEX[$i]
                        $returnObj | Add-Member NoteProperty DEC $Win11.DEC[$i]
                        WriteLog -Message "`tTag: $($Win11.Tag[$i])" -Verbose
                    }
                }
            } elseif ($Win11.Tag.ToLower().Contains($InputLanguage.ToLower().Trim())) {
                WriteLog -Message "Identified as Language Tag" -Verbose
                for ($i=0;$i -lt $Win11.Tag.Count; $i++) {
                    if ($Win11.Tag[$i].ToLower() -eq $InputLanguage.ToLower().Trim()) { 
                        WriteLog -Message "`tIndex: $($i)" -Verbose
                        $dec= [System.Text.Encoding]::Default
                        $Decoded=$dec.GetBytes($Win11.Region[$i])
                        $PropName=[System.Text.Encoding]::UTF8.GetString($Decoded)
                        $returnObj | Add-Member NoteProperty Region $PropName
                        $returnObj | Add-Member NoteProperty Tag $Win11.Tag[$i]
                        $returnObj | Add-Member NoteProperty HEX $Win11.HEX[$i]
                        $returnObj | Add-Member NoteProperty DEC $Win11.DEC[$i]
                        WriteLog -Message "`tRegion: $($PropName)" -Verbose
                    }
                }
            } elseif ($Win11LIP.Region.ToLower().Contains($InputLanguage.ToLower().Trim())) {
                WriteLog -Message "Identified as Language Interface Region" -Verbose
                for ($i=0;$i -lt $Win11LIP.Region.Count; $i++) {
                    if ($Win11LIP.Region[$i].ToLower() -eq $InputLanguage.ToLower().Trim()) { 
                        WriteLog -Message "`tIndex: $($i)" -Verbose
                        $dec= [System.Text.Encoding]::Default
                        $Decoded=$dec.GetBytes($Win11.Region[$i])
                        $PropName=[System.Text.Encoding]::UTF8.GetString($Decoded)
                        $returnObj | Add-Member NoteProperty Region $PropName
                        $returnObj | Add-Member NoteProperty Tag $Win11LIP.Tag[$i]
                        $returnObj | Add-Member NoteProperty HEX $Win11LIP.HEX[$i]
                        $returnObj | Add-Member NoteProperty DEC $Win11LIP.DEC[$i]
                        WriteLog -Message "`tTag: $($Win11LIP.Tag[$i])" -Verbose
                    }
                }
            } elseif ($Win11LIP.Tag.ToLower().Contains($InputLanguage.ToLower().Trim())) {
                WriteLog -Message "Identified as Language Interface Tag" -Verbose
                for ($i=0;$i -lt $Win11LIP.Tag.Count; $i++) {
                    if ($Win11LIP.Tag[$i].ToLower() -eq $InputLanguage.ToLower().Trim()) { 
                        WriteLog -Message "`tIndex: $($i)" -Verbose
                        $dec= [System.Text.Encoding]::Default
                        $Decoded=$dec.GetBytes($Win11.Region[$i])
                        $PropName=[System.Text.Encoding]::UTF8.GetString($Decoded)
                        $returnObj | Add-Member NoteProperty Region $PropName
                        $returnObj | Add-Member NoteProperty Tag $Win11LIP.Tag[$i]
                        $returnObj | Add-Member NoteProperty HEX $Win11LIP.HEX[$i]
                        $returnObj | Add-Member NoteProperty DEC $Win11LIP.DEC[$i]
                        WriteLog -Message "`tRegion: $($PropName)" -Verbose
                    }
                }
            }
        }


        if ($null -eq $returnObj.Region) {
            WriteLog -Message "Language was not detected, invalid option: $($InputLanguage)" -MessageType Error -Verbose
            return $null
        }
        return $returnObj


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
        $LegacyBCDPath = "S:\Boot\BCD"
        $AjoloteDrive=(Get-Volume | Where-Object {$_.FileSystemLabel -eq "AJOLOTE" }).DriveLetter
        $AjoloteDrive="$($AjoloteDrive):"
        if ([string]::IsNullOrEmpty($logs)) { $logs = (Join-Path $AjoloteDrive "\system.sav\logs\CSBuilt\HPLOGS_0") }
        WriteLog -Message "Logs folder: $($logs)" -Verbose
        #Rescan BCD
        $null = Invoke-RunPower -File "bcdedit.exe" -Params "/store $($BCDPath) /enum all" -WorkDir $PSScriptRoot -OutFile "$($logs)\BCDRescan.log" -Verbose
        #DP Script
        $strFile = "$($logs)\dp_FormatEFI.txt"
        $strResult = "$($logs)\dp_FormatEFI.log"
        if (Test-Path $strFile) { Remove-Item $strFile -Force }
        Add-Content -Path $strFile -Value "SEL VOL S"
        Add-Content -Path $strFile -Value "FORMAT FS=FAT32 QUICK OVERRIDE NOERR"
        Add-Content -Path $strFile -Value "DETAIL PART"
        Add-Content -Path $strFile -Value "LIS VOL" -NoNewline
        $RestoreFolderContent = @("Boot","EFI","en-us")
        $RestoreFilesContent = @("bootmgr","bootmgr.efi")
    }		
    Process {
        Write-Host "Current Environment: $($CurrentEnvironment), switch to $($Environment)"
        if ($Environment -eq "WinPE") { 
            $intDiskpart = Invoke-RunPower -File "Diskpart.exe" -Params "/s $($strFile)" -WorkDir $PSScriptRoot -OutFile $strResult
			if ($intDiskpart -ne 0) {
				WriteLog -Message "There is an error formatting EFI partition with diskpart" -MessageType Error  -Verbose
				return $null
			}
            Write-Host "Restore Ajolote EFI content"
            foreach ($compfolder in $RestoreFolderContent) {
                if (Test-Path (Join-Path "$($AjoloteDrive)\" $compfolder)) {
                    Copy-Item -Path (Join-Path "$($AjoloteDrive)\" $compfolder) -Destination "S:\" -Recurse -Force -Verbose | Out-Host
                } else {
                    Write-Host "Not possible locate $((Join-Path "$($AjoloteDrive)\" $compfolder))"
                    return $null    
                }
                
            }
            foreach ($compfile in $RestoreFilesContent) {
                if (Test-Path (Join-Path "$($AjoloteDrive)\" $compfile)) {
                    Copy-Item -Path (Join-Path "$($AjoloteDrive)\" $compfile) -Destination "S:\$($compfile)" -Force -Verbose | Out-Host
                } else {
                    Write-Host "Not possible locate $((Join-Path "$($AjoloteDrive)\" $compfile))"
                    return $null
                }
            }
            $Pars = @("/set {default} device ramdisk=[$($AjoloteDrive)]\sources\boot.wim,{7619dcc8-fafe-11d9-b411-000476eba25f}",
            "/set {default} osdevice ramdisk=[$($AjoloteDrive)]\sources\boot.wim,{7619dcc8-fafe-11d9-b411-000476eba25f}",
            "/set description ""Ajolote WinPE""")
            foreach ($par in $Pars) {
                $parametros = "/store $($BCDPath) $($par)"
                $parametroslegacy = "/store $($LegacyBCDPath) $($par)"
                WriteLog -Message "Execute BCDEDIT: $($parametros)" -Verbose
                $UpdateBCD = Invoke-RunPower -File "bcdedit.exe" -Params $parametros -WorkDir $PSScriptRoot -OutFile "$($logs)\BCD_AjoloteUpdate.log" -Verbose 
                if ($UpdateBCD -ne 0) {
                    WriteLog -Message "Not possible update Ajolote BCD file" -MessageType Error -Verbose
                    return $UpdateBCD
                }
                $UpdateBCDLegacy = Invoke-RunPower -File "bcdedit.exe" -Params $parametroslegacy -WorkDir $PSScriptRoot -OutFile "$($logs)\BCD_AjoloteUpdate.log" -Verbose
                if ($UpdateBCDLegacy -ne 0) {
                    WriteLog -Message "Not possible update Ajolote Legacy BCD file" -MessageType Error -Verbose
                    return $UpdateBCDLegacy
                }
            } 

        } 
        if ($Environment -eq "Windows") { 
            $intDiskpart = Invoke-RunPower -File "Diskpart.exe" -Params "/s $($strFile)" -WorkDir $PSScriptRoot -OutFile $strResult
			if ($intDiskpart -ne 0) {
				WriteLog -Message "There is an error formatting EFI partition with diskpart" -MessageType Error  -Verbose
				return $null
			}
            $CreateWindowsBCD = Invoke-RunPower -File "cmd.exe" -Params "/c bcdboot $((Join-Path $OSDrive "Windows")) /s S: /f UEFI" -WorkDir $PSScriptRoot -OutFile "$($logs)\BCDU_Windowspdate.log" -Verbose
            if ($CreateWindowsBCD -ne 0) {
                WriteLog -Message "Not possible recreate Windows BCD file" -MessageType Error -Verbose
                return $CreateWindowsBCD
            }
        }
               
        $null = Invoke-RunPower -File "bcdedit.exe" -Params "/store $($BCDPath) /enum all" -WorkDir $PSScriptRoot -OutFile "$($logs)\BCDAll.log" -Verbose
    }

}

function Set-BCDEnvironmentBKP {
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
                $Pars = @("-set {default} path \EFI\HP\SystemRecovery\bootmgfw.efi
                /create {0f84e3b8-bab2-4209-bf1e-7e351ad25f6f} -d ""Ajolote WinPE"" /application OSLOADER",
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
        [string[]]$BOOTLOADERS=bcdedit /store S:\EFI\Microsoft\Boot\BCD /enum all | Select-String "Windows Boot Loader" -Context 0,2 | ForEach-Object {$_.context.DisplayPostContext[1] -replace '^identifier +'}
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
function Set-APIUnitStatus {
    param (
        [Parameter(Mandatory=$false, Position=0)]
        [string]$computername,
        [Parameter(Mandatory=$false, Position=1)]
        [string]$LocVersion
    )
    Begin {
        $API_ServerName = "GUAFSIMAGES"
        $API_PORT = "4010"
        $API_ACTION = "register"
        $API_URL = "http://$($API_ServerName):$($API_PORT)/ajolote/$($API_ACTION)"
    }
    Process {
        #Validate is server is responding ping
        try {
            $ip = (Test-Connection -ComputerName $API_ServerName -Count 1 -ErrorAction Stop).IPv4Address.IPAddressToString
            $API_URL = "http://$($ip):$($API_PORT)/ajolote/$($API_ACTION)"
        }
        catch [System.Net.NetworkInformation.PingException] {
            WriteLog -Message "Server is not responding" -MessageType Error -Verbose
        } catch {
            WriteLog -Message "Something went wrong: $($_)" -MessageType Error -Verbose
        }
        #Get computer name
        if ($null -eq $computername) {
            $computername = $env:COMPUTERNAME
        }
        #Get Monitor Server Path
        if (Test-Path -Path (Join-Path $PSScriptRoot "config.xml")) {
            try {
                [xml]$config = Get-Content (Join-Path $PSScriptRoot "config.xml") -ErrorAction Stop
                $MonitorServerPath="\\$($config.AJOLOTE.servername)$($config.AJOLOTE.jobpath)"
                $MonitorStatus = [System.Convert]::ToBoolean($config.AJOLOTE.listenmode) 
            }
            catch {
                $MonitorServerPath="N/A"
                $MonitorStatus=$false
            }
        } else {
            $MonitorServerPath="N/A"
            $MonitorStatus=$false
        }  
        #Confirm Local Version
        if ($null -eq $LocVersion) {
            $LocVersion = "N/A"
        }
        #Get current job
        if (Test-Path -Path (Join-Path $PSScriptRoot "job.json")) {
            try {
                $GetCurrentJob = Get-Content (Join-Path $PSScriptRoot "job.json") -Raw -ErrorAction Stop | ConvertFrom-Json
                if ($null -ne $GetCurrentJob.JOBREQUEST.Job) {
                    $CurrentJobName = $GetCurrentJob.JOBREQUEST.Job.namejob
                } else {
                    $CurrentJobName = "Testing Updates"
                }
            }
            catch {
                $CurrentJobName = "IDLE"
            }
        } else {
            if ($MonitorStatus) {
                $CurrentJobName = "IDLE"
            } else {
                $CurrentJobName = "OFFLINE"
            }
        }
        #only if server seponse to ping
        if ($null -ne $ip) {
            $Headers = @{
                "APIKEY"="95855930-FFBC-4AA8-B9E7-09CA1D7B00B1"
            }
            $body = @{
                "ComputerName" = $computername
                "COmputerClock" = (Get-Date).ToString("MM-dd-yy HH:mm:ss")
                "ComputerMonitor" = $MonitorServerPath
                "Job"=$CurrentJobName
                "Version" = $LocVersion
            } | ConvertTo-Json
            
            try {
                $response = Invoke-RestMethod -Uri $API_URL -Method Post -Body $body -Headers $Headers -ContentType "application/json" -ErrorAction Stop
                WriteLog -Message "$($response.message)" -Verbose
            }
            catch [System.Net.WebException] {
                $ErrorMessage = $_.Exception.Message
                WriteLog -Message "Error, API doesn't response: $($ErrorMessage)" -MessageType Error -Verbose
            }
            
        }
    }
}