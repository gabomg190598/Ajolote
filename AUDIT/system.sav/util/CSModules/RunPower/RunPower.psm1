#requires -Modules "WriteLog"
<#
.SYNOPSIS
    Running command line for scripting
.DESCRIPTION
	Call execute any command using start process and retrieving output
.NOTES
	Script version 1.0.8
	Script Date Apr.4.2024
.PARAMETER File
    Executable file, must be full path or exist on WirkDir. 
.PARAMETER Params
   optional parameter to send executable 
.PARAMETER TimeOut
    optional paramter to wait process, in seconds;  by default 3600 = 1 hour
.PARAMETER WorkDir
	Optional to send where should be executed the parameter
.PARAMETER OutFile
	Optional. Send output to file, it send by default to WriteLog
.EXAMPLE

    Invoke-RunPower -File "C:\Windows\system32\sysprep\sysprep.exe" -Params "/generalize /oobe /shutdown" -WorkDir "C:\Windows\system32\sysprep" -OutFile .\Sysprep.log
    Invoke-RunPower -File "C:\Windows\system32\sysprep\sysprep.exe" -Params "/generalize /oobe /shutdown" -TimeOut 180  -WorkDir "C:\Windows\system32\sysprep" -OutFile .\Sysprep.log
#>
function New-Screenshot([string]$SavePath) {
    $screenshotPath = (Join-Path $SavePath "screenshot_$((Get-Date -Format 'MMddyyHHmmss')).png")
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
}

Function Invoke-RunPower {
	[CmdletBinding()]
	[OutputType([int])]
	Param 
	(
		[Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,HelpMessage="Executable file with full path",Position=0)]
		[ValidateNotNullOrEmpty()]
		[Alias("FullPath")]
        [String]$File,
		
		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,HelpMessage="Parameters provided",Position=1)]
		[Alias("Parameters")]
		[String]$Params="",
		
		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,HelpMessage="TimeOut in seconds",Position=2)]
		[Alias("time")]
        [int]$TimeOut=3600,
		
		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,HelpMessage="Which Directory to start work",Position=3)]
		[AllowNull()]
        [Alias("Directory")]
		[String]$WorkDir = "$($Env:WinDir)\System32",
		
		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,HelpMessage="Output file",Position=4)]
		[Alias("Out")]
        [String]$OutFile
    )
	Begin {
        $ErrorActionPreference = "Stop";
		WriteLog -Message "================================= RunPower ==========================================" -Component $MyInvocation.MyCommand.Name
	}
	Process {		
		Try {
			WriteLog -Message "RunPower execute command line: $($File) $($Params)" -Component $MyInvocation.MyCommand.Name 
			WriteLog -Message "`tWorking Directory: $($WorkDir)" -Component $MyInvocation.MyCommand.Name
			if ( $PSBoundParameters.ContainsKey( "OutFile" ) -eq $true ) {
				WriteLog -Message "`tRetrive Output from $($OutFile)" -Component $MyInvocation.MyCommand.Name
				$OutParent=(Split-Path -Path $OutFile -Parent)
			}		
			if ( $PSBoundParameters.ContainsKey( "TimeOut" ) -eq $true ) {
				if ($TimeOut -gt 60) { WriteLog -Message "`tProcess Timeout set for $([math]::round($TimeOut/60)) minutes" -Component $MyInvocation.MyCommand.Name; } else { WriteLog -Message "`tProcess Timeout set for $($TimeOut) seconds" -Component $MyInvocation.MyCommand.Name; }	
			} else {
				WriteLog -Message "`tProcess Timeout set as default $([math]::round($TimeOut/60)) minutes" -Component $MyInvocation.MyCommand.Name
			}
			$StartInfo = New-Object System.Diagnostics.ProcessStartInfo -Property @{
				FileName = $File
				Arguments = $Params
				UseShellExecute = $false
				WorkingDirectory = $WorkDir
				RedirectStandardOutput = $true
				RedirectStandardError = $true
			}
			# Create new process
			$Process = New-Object System.Diagnostics.Process
			$Process.StartInfo = $StartInfo

			# Register Object Events for stdin\stdout reading
			$pso = new-object psobject -property @{verb = $PSBoundParameters.ContainsKey( "Verbose" ); Comp=$MyInvocation.MyCommand.Name; outfile=$OutFile}
			$OutEvent = Register-ObjectEvent -Action {
				[string]$logline= $Event.SourceEventArgs.Data
				if (!([string]::IsNullOrWhiteSpace($logline) )) {
					if ($Event.MessageData.outfile) {
						$logline | Out-File -FilePath $Event.MessageData.outfile -Encoding default -Append -Force 
					} else {
						if ($Event.MessageData.verb) {
							WriteLog -Message $logline -Component $Event.MessageData.Comp  -Verbose
						} else {
							WriteLog -Message $logline -Component $Event.MessageData.Comp 
						}
					}
				}
				
			} -MessageData $pso -InputObject $Process -EventName OutputDataReceived

			$ErrEvent = Register-ObjectEvent -Action {
				[string]$logline= $Event.SourceEventArgs.Data
				if (!([string]::IsNullOrWhiteSpace($logline) )) {					
					if ($Event.MessageData.outfile) {					
						$logline | Out-File -FilePath "$($Event.MessageData.outfile).err" -Encoding default -Append -Force 
					} else {
						if ($Event.MessageData.verb) {
							WriteLog -Message $logline -MessageType Error -Component $Event.MessageData.Comp  -Verbose
						} else {							
							WriteLog -Message $logline -MessageType Error -Component $Event.MessageData.Comp 
						}
					}
				}
				
			} -MessageData $pso -InputObject $Process -EventName ErrorDataReceived

			# Start process
			[void]$Process.Start()
			WriteLog -Message "`tProcess start Id=$($Process.Id)" -Component $MyInvocation.MyCommand.Name 

			# Begin reading stdin\stdout
			$Process.BeginOutputReadLine()
			$Process.BeginErrorReadLine()

			$Counter=0
			do
			{
				if ($TimeOut -gt 0) {
					Start-Sleep -Seconds 1
					$Counter++;
					if ($Counter -eq ($TimeOut - 2) -AND ($null -ne $OutParent)) {
						New-Screenshot -SavePath $OutParent
					}
					if ($Counter -ge $TimeOut) {
						WriteLog -Message "`tTimeout reached, kill process and return error" -MessageType Error -Component $MyInvocation.MyCommand.Name 
						Get-Process -Id $Process.Id | Stop-Process -Force
							#$Process.Kill()
					}
				}
			}
			while (!$Process.HasExited)
			if ($TimeOut -gt 0) {
				if (!$Process.WaitForExit($TimeOut*1000)) {
					$Process.Kill()
				}
			} else {
				[Void]$Process.WaitForExit()
			}				
			
			# Unregister events
			$OutEvent.Name, $ErrEvent.Name | ForEach-Object {Unregister-Event -SourceIdentifier $_}
		

			if ($Process.HasExited) {
				WriteLog -Message "`tProcess Exit Code: $($Process.ExitCode)" -Component $MyInvocation.MyCommand.Name;
				if ($Process.ExitCode -ne 0) {
					if ($File.ToLower().Contains("robocopy") -OR $Params.ToLower().Contains("robocopy")) {
						if ($Process.ExitCode -lt 4) {
							WriteLog -Message "Robocopy was completed" -Component $MyInvocation.MyCommand.Name 
						} else {
							WriteLog -Message "Robocopy finish with error code $($Process.ExitCode)" -MessageType Warning -Component $MyInvocation.MyCommand.Name 			
						}
					} else {
						WriteLog -Message "Process finish with error code $($Process.ExitCode)" -MessageType Warning -Component $MyInvocation.MyCommand.Name 				
					}
				} else {
					WriteLog -Message "Process was completed" -Component $MyInvocation.MyCommand.Name 
				}	
				[int]$ExitCode=$Process.ExitCode
			} else {
				WriteLog -Message "`tProcess Exit Code: -1" -Component $MyInvocation.MyCommand.Name;
				WriteLog -Message "Timeout reached or process aborted" -Verbose -MessageType Error -Component $MyInvocation.MyCommand.Name;
				$Process.Dispose()
				[int]$ExitCode=-1
			}	
			WriteLog -Message "========================================================================================" -Component $MyInvocation.MyCommand.Name
			return $ExitCode

		} 
		Catch 
		{
			$ErrorMessage = $_.Exception.Message
			WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
			WriteLog -Message "========================================================================================" -Component $MyInvocation.MyCommand.Name
			return -2
		}
		Finally { $ErrorActionPreference = "Continue" }
	}
}


<#
.SYNOPSIS
    Running command line for scripting. New Verb same action 
.DESCRIPTION
	Call execute any command using start process and retrieving output
.NOTES
	Module version 1.0.7
	Script Date Apr.18.2021
.PARAMETER File
    Executable file, must be full path or exist on WirkDir. 
.PARAMETER Params
   optional parameter to send executable 
.PARAMETER TimeOut
    optional paramter to wait process, by default forever=0
.PARAMETER WorkDir
	Optional to send where should be executed the parameter
.PARAMETER OutFile
	Optional. Send output to file, it send by default to WriteLog
.EXAMPLE

    RunPower -File "C:\Windows\system32\sysprep\sysprep.exe" -Params "/generalize /oobe /shutdown" -WorkDir "C:\Windows\system32\sysprep" -OutFile .\Sysprep.log
    RunPower -File "C:\Windows\system32\sysprep\sysprep.exe" -Params "/generalize /oobe /shutdown" -TimeOut 180  -WorkDir "C:\Windows\system32\sysprep" -OutFile .\Sysprep.log
#>

Function RunPower {
	[CmdletBinding()]
	[OutputType([int])]
	Param 
	(
		[Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,HelpMessage="Executable file with full path",Position=0)]
		[ValidateNotNullOrEmpty()]
		[Alias("FullPath")]
        [String]$File,
		
		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,HelpMessage="Parameters provided",Position=1)]
		[Alias("Parameters")]
		[String]$Params="",
		
		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,HelpMessage="TimeOut in seconds",Position=2)]
		[Alias("time")]
        [int]$TimeOut=3600,
		
		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,HelpMessage="Which Directory to start work",Position=3)]
		[AllowNull()]
        [Alias("Directory")]
		[String]$WorkDir = "$($Env:WinDir)\System32",
		
		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,HelpMessage="Output file",Position=4)]
		[Alias("Out")]
        [String]$OutFile
    )
	Begin {
        $ErrorActionPreference = "Stop";
		WriteLog -Message "================================= RunPower ==========================================" -Component $MyInvocation.MyCommand.Name
	}
	Process {		
		Try {
			WriteLog -Message "RunPower execute command line: $($File) $($Params)" -Component $MyInvocation.MyCommand.Name 
			WriteLog -Message "`tWorking Directory: $($WorkDir)" -Component $MyInvocation.MyCommand.Name
			if ( $PSBoundParameters.ContainsKey( "OutFile" ) -eq $true ) {
				WriteLog -Message "`tRetrive Output from $($OutFile)" -Component $MyInvocation.MyCommand.Name
			}		
			if ( $PSBoundParameters.ContainsKey( "TimeOut" ) -eq $true ) {
				if ($TimeOut -gt 60) { WriteLog -Message "`tProcess Timeout set for $([math]::round($TimeOut/60)) minutes" -Component $MyInvocation.MyCommand.Name; } else { WriteLog -Message "`tProcess Timeout set for $($TimeOut) seconds" -Component $MyInvocation.MyCommand.Name; }	
			} else {
				WriteLog -Message "`tProcess Timeout set as default $([math]::round($TimeOut/60)) minutes" -Component $MyInvocation.MyCommand.Name
			}
			$StartInfo = New-Object System.Diagnostics.ProcessStartInfo -Property @{
				FileName = $File
				Arguments = $Params
				UseShellExecute = $false
				WorkingDirectory = $WorkDir
				RedirectStandardOutput = $true
				RedirectStandardError = $true
			}
			# Create new process
			$Process = New-Object System.Diagnostics.Process
			$Process.StartInfo = $StartInfo

			# Register Object Events for stdin\stdout reading
			$pso = new-object psobject -property @{verb = $PSBoundParameters.ContainsKey( "Verbose" ); Comp=$MyInvocation.MyCommand.Name; outfile=$OutFile}
			$OutEvent = Register-ObjectEvent -Action {
				[string]$logline= $Event.SourceEventArgs.Data
				if (!([string]::IsNullOrWhiteSpace($logline) )) {
					if ($Event.MessageData.outfile) {
						$logline | Out-File -FilePath $Event.MessageData.outfile -Encoding default -Append -Force 
					} else {
						if ($Event.MessageData.verb) {
							WriteLog -Message $logline -Component $Event.MessageData.Comp  -Verbose
						} else {
							WriteLog -Message $logline -Component $Event.MessageData.Comp 
						}
					}
				}
				
			} -MessageData $pso -InputObject $Process -EventName OutputDataReceived

			$ErrEvent = Register-ObjectEvent -Action {
				[string]$logline= $Event.SourceEventArgs.Data
				if (!([string]::IsNullOrWhiteSpace($logline) )) {					
					if ($Event.MessageData.outfile) {					
						$logline | Out-File -FilePath "$($Event.MessageData.outfile).err" -Encoding default -Append -Force 
					} else {
						if ($Event.MessageData.verb) {
							WriteLog -Message $logline -MessageType Error -Component $Event.MessageData.Comp  -Verbose
						} else {							
							WriteLog -Message $logline -MessageType Error -Component $Event.MessageData.Comp 
						}
					}
				}
				
			} -MessageData $pso -InputObject $Process -EventName ErrorDataReceived

			# Start process
			[void]$Process.Start()
			WriteLog -Message "`tProcess start Id=$($Process.Id)" -Component $MyInvocation.MyCommand.Name 

			# Begin reading stdin\stdout
			$Process.BeginOutputReadLine()
			$Process.BeginErrorReadLine()

			$Counter=0
			do
			{
				if ($TimeOut -gt 0) {
					Start-Sleep -Seconds 1
					$Counter++;
					if ($Counter -ge $TimeOut) {
						WriteLog -Message "`tTimeout reached, kill process and return error" -MessageType Error -Component $MyInvocation.MyCommand.Name 
						Get-Process -Id $Process.Id | Stop-Process -Force
							#$Process.Kill()
					}
				}
			}
			while (!$Process.HasExited)
			if ($TimeOut -gt 0) {
				if (!$Process.WaitForExit($TimeOut*1000)) {
					$Process.Kill()
				}
			} else {
				[Void]$Process.WaitForExit()
			}				
			
			# Unregister events
			$OutEvent.Name, $ErrEvent.Name | ForEach-Object {Unregister-Event -SourceIdentifier $_}
		

			if ($Process.HasExited) {
				WriteLog -Message "`tProcess Exit Code: $($Process.ExitCode)" -Component $MyInvocation.MyCommand.Name;
				if ($Process.ExitCode -ne 0) {
					if ($File.ToLower().Contains("robocopy") -OR $Params.ToLower().Contains("robocopy")) {
						if ($Process.ExitCode -lt 4) {
							WriteLog -Message "Robocopy was completed" -Component $MyInvocation.MyCommand.Name 
						} else {
							WriteLog -Message "Robocopy finish with error code $($Process.ExitCode)" -MessageType Warning -Component $MyInvocation.MyCommand.Name 			
						}
					} else {
						WriteLog -Message "Process finish with error code $($Process.ExitCode)" -MessageType Warning -Component $MyInvocation.MyCommand.Name 				
					}
				} else {
					WriteLog -Message "Process was completed" -Component $MyInvocation.MyCommand.Name 
				}	
				[int]$ExitCode=$Process.ExitCode
			} else {
				WriteLog -Message "`tProcess Exit Code: -1" -Component $MyInvocation.MyCommand.Name;
				WriteLog -Message "Timeout reached or process aborted" -Verbose -MessageType Error -Component $MyInvocation.MyCommand.Name;
				$Process.Dispose()
				[int]$ExitCode=-1
			}	
			WriteLog -Message "========================================================================================" -Component $MyInvocation.MyCommand.Name
			return $ExitCode

		} 
		Catch 
		{
			$ErrorMessage = $_.Exception.Message
			WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
			WriteLog -Message "========================================================================================" -Component $MyInvocation.MyCommand.Name
			return -2
		}
		Finally { $ErrorActionPreference = "Continue" }
	}
}