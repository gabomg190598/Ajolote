#requires -Modules "WriteLog","RunPower","GetDrive","RunDism"

<#
.SYNOPSIS
    This function used WSUS Offline CAB process to determinate if current image require MS Updates
.DESCRIPTION
	OfflineWsus use WSUS2 CAB to detect missing updates, it return number of missing MS updates, in error return $null value
.NOTES
	Script version 1.0.7
	Script Date Oct.21.2021
.PARAMETER WSUS2
	Indicate where is the wsusscn2.cab file
.PARAMETER Report
	Indicate where create report ini
.EXAMPLE

	OfflineWsus -WSUS2 "C:\Windows\Temp\wsusscn2.cab" -Report 
#>
Function OfflineWsus {
	Param 
	(		
		[Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,HelpMessage="Provide wsusscn2.cab to check offline",Position=0)]
		[Alias("wsus")]
        [String]$WSUS2,
		
        [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,HelpMessage="Provide file to add results",Position=1)]
		[Alias("wsusreport")]
        [String]$Report,

		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,HelpMessage="Provide file to exclude updates validation",Position=2)]
		[Alias("exckb")]
        [string]$ExcludeKB
    )
    Begin {
        $ErrorActionPreference = "Stop";
    }
    Process {
        Try
        {
            #Detect WinPE environment - Not allowed
            if (Test-Path HKLM:\SYSTEM\CurrentControlset\Control\MiniNT) { WriteLog -Message "This function $($MyInvocation.MyCommand.Name) cannot execute on WinPE environment" -Messagetype Error -Component $MyInvocation.MyCommand.Name; return $null  }
            #Require wsusscn2.cab
            if (!(Test-Path $WSUS2)) { WriteLog -Message "wsusscn2.cab is not present, skip scan" -MessageType Warning -Component $MyInvocation.MyCommand.Name; return $null; }
            WriteLog -Message "Scannig image for Microsoft Updates required, please wait..." -Component $MyInvocation.MyCommand.Name
            if ((Get-PSCallStack).Count -lt 3){ #call from script
                $GetPath=(Get-Item -Path '.\' -Verbose).FullName
            } else {
                $GetPath = Split-Path (Get-PSCallStack)[(Get-PSCallStack).Count-2].ScriptName -Parent
            }
            if ( $PSBoundParameters.ContainsKey( "Report" ) -eq $false ) {
                $Report="$($GetPath)\wsusreport.ini"
            }
			if ( $PSBoundParameters.ContainsKey( "ExcludeKB" ) -eq $true ) {
                WriteLog -Message "Parameter Exclude KB received with file: $($ExcludeKB)" -Component $MyInvocation.MyCommand.Name
            }
            $strRPT="$($GetPath)\MSUpdates.txt"
            ";---------Report Updates required for this image------------" | Out-File -FilePath $strRPT -Encoding default -Force
            
            $UpdateSession = New-Object -ComObject "Microsoft.Update.Session"
            $UpdateServiceManager = New-Object -ComObject "Microsoft.Update.ServiceManager"
            $UpdateService = $UpdateServiceManager.AddScanPackageService("Offline Sync Service",$WSUS2,1)
            $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
            $UpdateSearcher.ServerSelection = 3
            $UpdateSearcher.ServiceID = $UpdateService.ServiceID
            $SearchResult = $UpdateSearcher.Search("IsInstalled=0")
            $Updates = $SearchResult.Updates
			$MissingKbs = [system.collections.arraylist]@()
            if ($Updates.Count -eq 0) {WriteLog -Message "No updates required for this image, exit" -Component $MyInvocation.MyCommand.Name; return $null}
            WriteLog -Message "WUA API has detected $($SearchResult.Updates.Count) updates, compare with exception to list:" -MessageType Warning -Component $MyInvocation.MyCommand.Name
			$regex = [regex]"\((.*)\)"
			for ($i=0; $i -le $SearchResult.Updates.Count-1; $i++) {
                $update = $SearchResult.Updates.Item($i);
				if ((-Not([string]::IsNullOrEmpty($ExcludeKB))) -AND (Test-Path -Path $ExcludeKB -PathType Leaf)) {
					#list kb
					WriteLog -Message "Exclude KB file detected: $($ExcludeKB)" -Component $MyInvocation.MyCommand.Name
					$DetectMissingKB=$true
					foreach ($exkb in (Get-Content $ExcludeKB -Encoding Ascii)) {
						if (-Not([string]::IsNullOrEmpty($exkb.Trim()))) {
							if (-Not([string]::IsNullOrEmpty(([regex]::match($update.title, $regex).Groups[1].Value).Trim()))) {
								if (([regex]::match($update.title, $regex).Groups[1].Value).Trim().ToUpper() -eq $exkb.Trim().ToUpper()) {
									WriteLog -Message "KB: $([regex]::match($update.title, $regex).Groups[1].Value) was located on exception list, it will skip from report" -MessageType Warning -Component $MyInvocation.MyCommand.Name
									$DetectMissingKB=$false
								}
							}
						}
					}
					if ($DetectMissingKB) { 
						WriteLog -Message "`t$($i+1)) `t$($update.title)" -MessageType Warning -Component $MyInvocation.MyCommand.Name
						[void]$MissingKbs.Add($SearchResult.Updates.Item($i)) 
						$update.title | Out-File -FilePath $strRPT -Encoding default -Append -Force
						if (([regex]::match($update.title, $regex).Groups[1].Value).Trim() -ne "") {
							[regex]::match($update.title, $regex).Groups[1].Value | Out-File -FilePath $Report -Encoding default -Append -Force
						} else {
							WriteLog -Message "wsusscn2 report didn't include KB on title: $($update.title)" -MessageType Warning -Component $MyInvocation.MyCommand.Name;
						}
					}
				} else {					
					WriteLog -Message "`t$($i+1)) `t$($update.title)" -MessageType Warning -Component $MyInvocation.MyCommand.Name
					$update.title | Out-File -FilePath $strRPT -Encoding default -Append -Force
					if (([regex]::match($update.title, $regex).Groups[1].Value).Trim() -ne "") {
						[regex]::match($update.title, $regex).Groups[1].Value | Out-File -FilePath $Report -Encoding default -Append -Force
						[void]$MissingKbs.Add($SearchResult.Updates.Item($i));
					} else {
						WriteLog -Message "wsusscn2 report didn't include KB on title: $($update.title)" -MessageType Warning -Component $MyInvocation.MyCommand.Name;
					}
				}                
            }
            return $MissingKbs
            
        } 
        Catch 
        {
            $ErrorMessage = $_.Exception.Message
            WriteLog -Message "Exception error on $($MyInvocation.MyCommand.Name) function: $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
            return $null
        }
        Finally { $ErrorActionPreference = "Continue" }
    }
	
}


<#
.SYNOPSIS
    Function to install or inject MS updates
.DESCRIPTION
	Install regular MS Updates, It run on WinPE and Windows environment, only codes expected 0 & 3010, other return code is error
	WriteLog, GetDrive and Invoke-RunPower module are required 
.NOTES
	Script version 1.0.6
	Script Date Apr.18.2021
.PARAMETER Path
	Where are all updates to install
.PARAMETER OSDrive
	Select OS Drive letter like C:
.PARAMETER WSUS2
	Indicate where is the wsusscn2.cab file, full path including cab file
.PARAMETER Logs
	Indicate where drop logs generated
.PARAMETER RemoveSuccess
	Remove success files.
    for Windows environmment if there are no errors detected it will remove enrire Path folder 
.PARAMETER ExcludeWinPEFile
    list of KB name or file name pattern that will not be injected during WinPE environment.

.EXAMPLE
    MSUpdates -Path "C:\MSUpdates" -OSDrive="C:" -WSUS2 "C:\Windows\Temp\wsusscn2.cab" -Logs "C:\system.sav\logs" -RemoveSuccess $true -ExcludeWinPEFile "C:\system.sav\util\ExcludeWinPe.ini"
#>
Function MSUpdates {
	[OutputType([int])]
	Param 
	(
		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$True,HelpMessage="Provide path to scan, by default is current script path",Position=0)]
		[ValidateNotNullOrEmpty()]
		[Alias("FullPath")]
        [String]$Path,

        [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,HelpMessage="Provide drive of OS like C:",Position=1)]
		[Alias("drive")]
        [String]$OSDrive,
		
		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,HelpMessage="Provide wsusscn2.cab to check offline, by default this is same place as -Path",Position=2)]
		[Alias("wsus")]
        [String]$WSUS2,
		
		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,HelpMessage="Provide where to store logs",Position=3)]
		[Alias("logpath")]
        [String]$Logs,
		
		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,HelpMessage="confirm if file used need to be removed after be used",Position=4)]
		[Alias("remove")]
		[bool]$RemoveSuccess,
		
		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,HelpMessage="Provide file to exclude updates during WinPE",Position=5)]
		[Alias("excl")]
        [string]$ExcludeWinPEFile

        
    )
	Begin {
		if ( $PSBoundParameters.ContainsKey( "Path" ) -eq $false ) { 
            if ((Get-PSCallStack).Count -lt 3){ #call from script
                $Path=(Get-Item -Path '.\' -Verbose).FullName
            } else {
                $Path = $MyInvocation.PSScriptRoot;
            }
        }
		if ( $PSBoundParameters.ContainsKey( "WSUS2" ) -eq $false ) { $WSUS2 = "$($Path)\wsusscn2.cab" }
		if ( $PSBoundParameters.ContainsKey( "Logs" ) -eq $false ) { $Logs = $Path }
		if ( $PSBoundParameters.ContainsKey( "RemoveSuccess" ) -eq $false ) { $RemoveSuccess = $false }
		
	}
	Process {
		$ErrorActionPreference = "Stop";
		Try 
		{
			#Files
			$DismLog = "$($Logs)\MSUpdate_Dism.log"

			WriteLog -Message "=======================MICROSOFT UPDATES PROCESS START================================================" -Component $MyInvocation.MyCommand.Name			
			WriteLog -Message "Remove Files on Success: [$($RemoveSuccess)]" -Component $MyInvocation.MyCommand.Name				

			if (Test-Path HKLM:\SYSTEM\CurrentControlset\Control\MiniNT) { #WinPE Environment
				WriteLog -Message "=======================WINPE ENVIRONMENT DETECTED================================================" -Component $MyInvocation.MyCommand.Name
				if ( $PSBoundParameters.ContainsKey( "OSDrive" ) -eq $false ) { $OSDrive = Get_DriveByPath -Path "\Windows\System32\"}
				$ErrorCode=0
				WriteLog -Message "Retrieve files on current folder $($Path)" -Component $MyInvocation.MyCommand.Name
				$exclude = ("*.txt","*.log","*.csv","*.xlsx","*.ps1","*.xml","*.lnk", "wsusscn2.cab", "*.zip")
				#this secction allows to send an update to Windows installation
				if (Test-Path $ExcludeWinPEFile) {
					WriteLog -Message "It was detected an exclde names for WinPEenvironment" -Component $MyInvocation.MyCommand.Name
					$PatternValues=Get-Content $ExcludeWinPEFile
					foreach ($pat in $PatternValues) {
						if ($pat.ToString().Trim().Length -gt 0) {
							WriteLog -Message "Adding pattern $($pat.ToString().Trim())" -Component $MyInvocation.MyCommand.Name
							$exclude += "*$($pat.ToString().Trim())*"
						}
					}
				}
				$exclude | ForEach-Object {WriteLog -Message "Excluding file: $($_)" -Verbose}
				$validfiles=("*.msu","*.cab")
				#####
				$MSUFiles = Get-ChildItem -Path $Path -Recurse -file -Include $validfiles -Exclude $exclude | Sort-Object -Property DirectoryName
				
				####---Install
				Foreach ($msu in $MSUFiles) {
					WriteLog -Message "Inject file: $($msu.FullName)" -Component $MyInvocation.MyCommand.Name
					$kbname = $msu.Name.Split("-") |ForEach-Object {if (($_).Contains("kb")){return $_}}
					if ($null -eq $kbname) {$kbname=$msu.Name.ToString().ToLower().Replace(".msu","") }
					$intDism = RunDism -Params "/image:$($OSDrive)\ /ScratchDir:$($OSDrive)\ /Add-Package /PackagePath:""$($msu.FullName)""" -WorkDir $Path -OutFile "$($Logs)\DismUpdate_$($kbname).log" -ShowProgress $true	
					if ($intDism -eq 0 -OR $intDism -eq 3010) { 
						WriteLog -Message "Package $($msu.Name) installed successfully" -Component $MyInvocation.MyCommand.Name; 
						if ($RemoveSuccess) { 
							WriteLog -Message "Removing: $($msu.Name)" -Component $MyInvocation.MyCommand.Name;
							Remove-Item -Path $msu.FullName -Force;
						} 
					} else { 
						WriteLog -Message "[E R R O R]Update cannot be applied: $($msu.Name)" -MessageType Error -Component $MyInvocation.MyCommand.Name;  
						$ErrorCode=$intDism
						break
					}
				}
				
				$Files = Get-ChildItem -Path $Path -Recurse -file | Sort-Object -Property DirectoryName
				WriteLog -Message "---- List of files on current folder: " -Component $MyInvocation.MyCommand.Name
				Foreach ($f in $Files) { WriteLog -Message "`tFile: $($f.FullName)" -Component $MyInvocation.MyCommand.Name	}
				#if (!(Test-Path $WSUS2)) { WriteLog -Message "wsusscn2.cab is required but is not present,Windows stage will not run" -MessageType Warning -Component $MyInvocation.MyCommand.Name; }
				WriteLog -Message "=======================WINPE ENVIRONMENT COMPLETED================================================" -Component $MyInvocation.MyCommand.Name
				
			} else {
				WriteLog -Message "=======================WINDOWS ENVIRONMENT DETECTED================================================" -Component $MyInvocation.MyCommand.Name
				$sysp = Get-Process | Where-Object { $_.ProcessName -like "*sysprep*"}
				if ($null -ne $sysp) { WriteLog -Message "Sysprep tool is open, closing for now" -Component $MyInvocation.MyCommand.Name; Stop-Process -Id $sysp.Id }
				$exclude = ("*.txt","*.log","*.csv","*.xlsx","*.ps1","*.xml","*.lnk","wsusscn2.cab","*.zip","*.ini")
				WriteLog -Message "List files on Path: $($Path)"
				(Get-ChildItem -Path $Path -Recurse -file -Exclude $exclude | Sort-Object -Property DirectoryName) | ForEach-Object { WriteLog -Message "`t$($_.FullName)" -Component $MyInvocation.MyCommand.Name}
				#Expanding CAB files 
				WriteLog -Message "=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=# EXPAND STAGE =#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#" -Component $MyInvocation.MyCommand.Name
				WriteLog -Message "Searching CAB files to expando prio..." -Component $MyInvocation.MyCommand.Name
				$CABfiles = Get-ChildItem -Path $Path -Recurse -file -filter "*.cab" -Exclude $exclude | Sort-Object -Property DirectoryName
				Foreach ($cab in $CABfiles) {
					WriteLog -Message "[EXPANDING] file $($cab.Name) in path: $($cab.DirectoryName)" -Component $MyInvocation.MyCommand.Name
					#$PreFiles = Get-ChildItem -Path $cab.DirectoryName -file
					$ExeFile = "expand"
					$Params = """$($cab.FullName)"" -F:* ""$($cab.DirectoryName)"""
					$intExpand = Invoke-RunPower -File $ExeFile -Params $Params
					WriteLog -Message "Expanded file return code: $($intExpand)" -Component $MyInvocation.MyCommand.Name
					if ($intExpand -ne 0) { WriteLog -Message "Error during expansion detected for file $($cab.Name)" -MessageType Error -Component $MyInvocation.MyCommand.Name } else  { WriteLog -Message "Expansion completed successfully removing $($cab.Name)" -Component $MyInvocation.MyCommand.Name; if (Test-Path $cab.FullName) {Remove-Item -Path $cab.FullName -Force;}}
				}
				
				WriteLog -Message "=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=# INSTALL STAGE  =#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#" -Component $MyInvocation.MyCommand.Name
				$Files = Get-ChildItem -Path $Path -Recurse -file -Exclude $exclude | Sort-Object -Property DirectoryName
				$ErrorDetected = 0
				$RebootRequired=$false
				$ErrorCode=0
				Foreach ($file in $Files) {
					WriteLog -Message "File Found: $($file.Name)" -Component $MyInvocation.MyCommand.Name
					Switch ($file.Extension) {
						".cab" { $ExeFile = "Dism.exe"; $Params = "/online /add-package /packagepath:""$($file.FullName)""" }
						".cmd" { $ExeFile = "cmd.exe"; $Params = "/c ""$($file.FullName)""" }
						".msp" { $ExeFile = "msiexec.exe"; $Params = "/update ""$($file.FullName)"" REINSTALL=ALL REINSTALLMODE=omus /passive" }
						".msu" { $ExeFile = "wusa.exe"; $Params = """$($file.FullName)"" /quiet /norestart" }
						".exe" { $ExeFile = "cmd.exe"; $Params = "/c start /wait ""$($file.FullName)"" /q /norestart" }
						default { WriteLog -Message "There are no tool to install $($file.Name)" -Component $MyInvocation.MyCommand.Name; $ExeFile = "cmd.exe"; $Params = "/c echo Hello World: $($file.Name) & pause" }
					}
					if ($file.Name.ToString().ToLower() -eq "mpam-fe.exe") {
						WriteLog -Message "Defender definition found $($file.Name)" -Component $MyInvocation.MyCommand.Name
						$ExeFile = "cmd.exe"; $Params = "/c ""$($file.FullName)"""
					}
					if ($file.VersionInfo.ProductName -like "Malicious Software Removal Tool") {
						WriteLog -Message "Malicious update detected $($file.Name)" -Component $MyInvocation.MyCommand.Name
						$ExeFile = "cmd.exe"; $Params = "/c ""$($file.FullName)"" /Q"
					}
					if ($file.Directory.ToString().ToLower().Contains("malicious") -OR $file.Name.ToString().ToLower().Contains("malicious")) {
						WriteLog -Message "Malicious update detected $($file.Name)" -Component $MyInvocation.MyCommand.Name
						$ExeFile = "cmd.exe"; $Params = "/c ""$($file.FullName)"" /Q"
					}
				
					WriteLog -Message "[INSTALLING] - $($file.FullName)" -Component $MyInvocation.MyCommand.Name
					$run = Invoke-RunPower -File $ExeFile -Params $Params -WorkDir $file.DirectoryName -OutFile $DismLog
					if ($run -eq 3010) {
						WriteLog -Message "Reboot required to apply this Update" -Component $MyInvocation.MyCommand.Name; 
						$RebootRequired=$true
					}
					if ($run -eq 0 -OR $run -eq 3010) {
						WriteLog -Message "Successfully installation $($file.Name)" -Component $MyInvocation.MyCommand.Name; 
						if (Test-Path $file.FullName) {
							if ($RemoveSuccess) {
								Remove-Item -Path $file.FullName -Force
							}
						}
					} else { 
						WriteLog -Message "[E R R O R] Not expected return code $($run), leaving file $($file.Name)" -MessageType Error -Component $MyInvocation.MyCommand.Name; 
						$ErrorCode=$run
						$ErrorDetected ++;
					}
					$ExeFile = $null
					$Params = $null

				}
				WriteLog -Message "=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#= ERRORS FOUND: $($ErrorDetected) =#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=" -Component $MyInvocation.MyCommand.Name
				WriteLog -Message "Persisting files..." -Component $MyInvocation.MyCommand.Name
				$Files = Get-ChildItem -Path $Path -Recurse -file -Exclude $exclude | Sort-Object -Property DirectoryName
				Foreach ($file in $Files) {
					WriteLog -Message "[File]: $($file.FullName)" -Component $MyInvocation.MyCommand.Name
				}
				WriteLog -Message "Get HotFixes installed..." -Component $MyInvocation.MyCommand.Name
				$Fixes = Get-HotFix
				Foreach ($hot in $Fixes) {
					WriteLog -Message "Update KB: $($hot.HotFixID) | Description: $($hot.Description) | Installed: $($hot.InstalledOn) | By: $($hot.InstalledBy)" -Component $MyInvocation.MyCommand.Name
				}
				
				if ($ErrorDetected -eq 0) {
					WriteLog -Message "Removing Microsoft Updates folder[$($Path)]" -Component $MyInvocation.MyCommand.Name
					if (Test-Path $WSUS2) { Remove-Item -Path $WSUS2 -Force } 
                    Get-ChildItem -Path $Path -Recurse -File | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                    $Dirs=(Get-ChildItem -Path $Path -Directory -Recurse | Select-Object FullName, @{n='len';e={$_.FullName.Length}} | Sort-Object -Property len -Descending)
					foreach ($dir in $Dirs) { Remove-Item -Path $dir.FullName -Recurse -Force }
					$null = Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q  $($Path)"
				}
				WriteLog -Message "=======================WINDOWS ENVIRONMENT COMPLETED================================================" -Component $MyInvocation.MyCommand.Name				
			}	
			WriteLog -Message "=======================MICROSOFT UPDATES COMPLETED================================================" -Component $MyInvocation.MyCommand.Name
			if ($RebootRequired) {
				return 3010
			} else {
				return $ErrorCode
			}
		} 
		Catch 
		{
			$ErrorMessage = $_.Exception.Message
			WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
		}
		Finally { $ErrorActionPreference = "Continue" }
	}
	
}