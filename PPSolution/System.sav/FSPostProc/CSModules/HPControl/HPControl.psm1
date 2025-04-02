#requires -Modules "WriteLog","WindowStyle"
<#
.SYNOPSIS
	HPControl function to help in script control, it allows to save steps into file and read to validate is string is the same as saved
.DESCRIPTION
	$global:hpcontrol is a global variable used to identify in what step require the script

.NOTES
	Script version 1.0.5
	Script Date May.17.2021
.PARAMETER Set
	String used to save into file and save into Global variable: $Global:hpcontrol
.PARAMETER Get
	String to compare against $Global:hpcontrol, it also compare with file, always file overwrite global variable
.PARAMETER Path
	String to set where to save file, by default is same as script
.PARAMETER Name
	String name of file, by default is Step.dat
.PARAMETER ContinueOnError
	Options. by default the process continue no matter result, disable this options can break all script process.
.EXAMPLE
    
    HPControl -Set "Start"
	HPControl -Get "Start" 
	HPControl -Set "Drivers" -Path C:\Windows\Temp\ -Name "step.stp"
#>
Function HPControl {
	[CmdletBinding()]
	Param 
	(
		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$True,HelpMessage="Save value on control file",Position=0)]
		[AllowNull()]
		[Alias("save")]
        [String]$Set,
		
		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,HelpMessage="Retrieve value from control file",Position=1)]
		[AllowNull()]
		[Alias("read")]
        [String]$Get,
		
		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,HelpMessage="Set directory to place control file",Position=2)]
		[AllowNull()]
        [Alias("directory")]
		[String]$Path,
		
		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,HelpMessage="Output file",Position=3)]
		[AllowNull()]
		[Alias("filename")]
        [String]$Name
    )
	Begin {
		$ErrorActionPreference = "Stop";
		#WriteLog -Message "============================== $($MyInvocation.MyCommand.Name) START ==============================" -Component $MyInvocation.MyCommand.Name
		if ( $PSBoundParameters.ContainsKey( "Path" ) -eq $false ) {
			if ( $null -ne $global:PathControl )
            {
                $Path = $global:PathControl
            }
            else
            {
				if ((Get-PSCallStack).Count -lt 3){  #call from Command line
					$Path =(Get-Item -Path '.\' -Verbose).FullName
				} else {
					$Path = Split-Path (Get-PSCallStack)[(Get-PSCallStack).Count-2].ScriptName -Parent
				}
                $global:PathControl = $Path
            }			
        } else {
			$global:PathControl=$Path
		}
		if ($PSBoundParameters.ContainsKey( "Name" ) -eq $false) {
			if ($null -ne $global:NameControl) {
				$Name = $global:NameControl
			} else {
				$Name = "step.dat"
				$global:NameControl = $Name
			}
		} else {
			$global:NameControl = $Name
		}
		$Step = "$($Path)\$($Name)"	

	}
	Process {
		Try 
		{
		#-----> Save file
			if ( $PSBoundParameters.ContainsKey( "Set" ) -eq $true ) {	
				WriteLog -Message "`tSave Control file: Step[$($Set)] --> $($Step)" -Component $MyInvocation.MyCommand.Name
				$Set | Out-File -FilePath $Step -Encoding default -Force -NoNewline
				$Global:hpcontrol = $Set
			}
		#----> Retrieve file
			if ( $PSBoundParameters.ContainsKey( "Get" ) -eq $true ) {
				WriteLog -Message "`tGet Control Value: Step[$($Get)] <-- $($Step)" -Component $MyInvocation.MyCommand.Name
			#----> hpcontrol and file exist 
				if (($null -ne $Global:hpcontrol) -AND (Test-Path $Step)) {
					if ($Global:hpcontrol -ne (Get-Content -Path $Step -Force).Trim()){
						WriteLog -Message "`t`tGlobal value [$($Global:hpcontrol)] is not the same as file[$((Get-Content -Path $Step -Force).Trim())], updating" -Component -MessageType Warning $MyInvocation.MyCommand.Name
						$Global:hpcontrol = (Get-Content -Path $Step -Force).Trim()
					}
				}
			#-----> hpcontrol doesn't exist and file does 
				if (($null -eq $Global:hpcontrol) -AND (Test-Path $Step)) {
					WriteLog -Message "`t`tGlobal value is not set, but file exist, create Global value as [$((Get-Content -Path $Step -Force).Trim())]" -MessageType Warning -Component $MyInvocation.MyCommand.Name
					$Global:hpcontrol = (Get-Content -Path $Step -Force).Trim()
				}
			#-----> hpcontrol and file doesn't exist
				if (($null -eq $Global:hpcontrol) -AND !(Test-Path $Step)) {
					WriteLog -Message "`t`tNot possible read Global value neither File is present, return False" -MessageType Error -Component $MyInvocation.MyCommand.Name
					return $false
				}

			#-----> Validate hpcontrol vs value
				if ($Global:hpcontrol -eq $Get){
					WriteLog -Message "`t`tValid Step! Next[$($Global:hpcontrol)] | Validate[$($Get)]" -Component $MyInvocation.MyCommand.Name
					return $true
				} else {
					WriteLog -Message "`t`tNot valid Step! Next[$($Global:hpcontrol)] X Validate[$($Get)]" -Component $MyInvocation.MyCommand.Name
					return $false
				}
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

<#
.SYNOPSIS
	Progress HTA is a form to hide script while a process is runing to prevent user cancel by accident
.DESCRIPTION
	$global:hpcontrol is a global variable used to identify in what step goes the script

.NOTES
	Script version 1.0.5
	Script Date May.17.2021
.PARAMETER HTAMode
	Action to apply to HTA
.PARAMETER htapath
	Where is the HTA
.PARAMETER DebugMode
	Enable for debug issues

.EXAMPLE
    ControlHTA -htapath $PSScriptRoot -HTAMode On
    ControlHTA -htapath $PSScriptRoot -HTAMode Off
    ControlHTA -htapath $PSScriptRoot -DebugMode
   
#>
Function ControlHTA{
	[CmdletBinding()]
	Param 
	(
		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$True,HelpMessage="Mode",Position=0)]
		[ValidateSet("On", "Off", "Restart")]
		[Alias("mode")]
		[String]$HTAMode="Restart",

		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$True,HelpMessage="Path",Position=1)]
		[AllowNull()]
		[Alias("path")]
		[String]$htapath,
		
		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$True,HelpMessage="Debug",Position=1)]
		[AllowNull()]
		[Alias("dbg")]
        [switch]$DebugMode
	)
	Begin {
		$ErrorActionPreference = "Stop";
		if ( $PSBoundParameters.ContainsKey( "htapath" ) -eq $false ) { 
			if ( $null -ne $global:htapath )
            {
                $htapath = $global:htapath
            }
            else
            {
				if ((Get-PSCallStack).Count -lt 3){  #call from Command line
					$htapath =(Get-Item -Path '.\' -Verbose).FullName
				} else {
					$htapath = Split-Path (Get-PSCallStack)[(Get-PSCallStack).Count-2].ScriptName -Parent
				}
				#$htapath =  "$($htapath)\hta"
                $global:htapath = $htapath
            }			
        } else {
			$global:htapath=$htapath
		}
		if ( $PSBoundParameters.ContainsKey( "DebugMode" ) -eq $false ) { 
			if ( $null -ne $global:debugmode )
            {
                $DebugMode = $global:debugmode
            }
            else
            {
				$DebugMode = $false
                $global:debugmode = $false
            }			
        } else {
			$global:debugmode=$DebugMode
		}
		#$htafile="Progress.hta"
		$htafile="HPFullLockScreen.exe"
		$htamsg="$($htapath)\status.ini"
		try {
			if (!(Test-Path "$($htapath)\$($htafile)")) {
				Copy-Item -Path "$($PSScriptRoot)\$($htafile)" -Destination "$($htapath)\$($htafile)" -Force
			}
		}
		catch {
			WriteLog -Message "Not possible copy HTA, probably already running" -MessageType Warning -Component $MyInvocation.MyCommand.Name 
		}
		
		#$GetHTA = Get-ChildItem -Path $PSScriptRoot -Recurse -Filter "Progress.zip" -File
		if (!(Test-Path "$($htapath)\$($htafile)")) { WriteLog -Message "HTA file wasn't found, not possible use for UI" -MessageType Error -Verbose; return $null; }
	}
	Process {				
		Try 
		{
			#$htazip=$GetHTA.FullName
			if ($DebugMode) {
				WriteLog -Message "Debug mode is ON" -MessageType Warning -Component $MyInvocation.MyCommand.Name 
				if ($null -ne $global:HTAId) {
					if ((Get-Process -Id $global:HTAId)) { Stop-Process -Id $global:HTAId; }
					$global:HTAId=$null;
				}
				#if (!(Test-Path -Path $htapath )) {New-Item -Path $htapath -ItemType Directory -Force }
				Get-Process -Id $PID -ErrorAction SilentlyContinue | Set-WindowStyle -Style MAXIMIZE
			} else {

				if ($null -ne $global:HTAId) {
					if ((Get-Process -Id $global:HTAId)) {
	#-------HTA is open and running
						WriteLog -Message "Currently HTA is open and running[$($global:HTAId)]" -Component $MyInvocation.MyCommand.Name
						switch ($HTAMode) {
							"On" { WriteLog -Message "HTA is runing nothing to do on this case" -Component $MyInvocation.MyCommand.Name; Get-Process -Id $PID -ErrorAction SilentlyContinue | Set-WindowStyle -Style HIDE; return (Get-Process -Id $global:HTAId); break;}
							"Off" {Stop-Process -Id $global:HTAId; $global:HTAId=$null; Get-Process -Id $PID -ErrorAction SilentlyContinue | Set-WindowStyle -Style SHOW; WriteLog -Message "Shutdown HTA" -Component $MyInvocation.MyCommand.Name; return $null; break;}
							"Restart" {
								"[info]Initializing interface..." | Out-File -FilePath $htamsg -Encoding default -NoNewline -Force; 
								WriteLog -Message "Restating HTA" -Component $MyInvocation.MyCommand.Name; 
								Stop-Process -Id $global:HTAId; 
								$runhta = Start-Process "$($htapath)\$($htafile)" -WorkingDirectory "$($htapath)\" -PassThru -ErrorAction SilentlyContinue
								if ($null -ne $runhta){ 
									WriteLog -Message "HTA interface is open with id: $($runhta.Id)" -Component $MyInvocation.MyCommand.Name 
									$global:HTAId = $runhta.Id
									Get-Process -Id $PID -ErrorAction SilentlyContinue | Set-WindowStyle -Style HIDE
									return $runhta;
								}
								return $null;
								break;
							}
							Default {WriteLog -Message "HTA is runing nothing to do on this case" -Component $MyInvocation.MyCommand.Name; return (Get-Process -Id $global:HTAId); break;}
						}
					} else {
	#-------HTA is currently off
						if ( (Get-Process | Where-Object ProcessName -eq "HPFullLockScreen" | Measure-Object).Count -gt 0) {
							WriteLog -Message "There are HTA process running but are not controled by this script" -MessageType Warning -Component $MyInvocation.MyCommand.Name
						}
						WriteLog -Message "HTA is currently off" -Component $MyInvocation.MyCommand.Name
						switch ($HTAMode) {
							"On" { 
								WriteLog -Message "Starting HTA" -Component $MyInvocation.MyCommand.Name; 
								"Initializing interface..." | Out-File -FilePath $htamsg -Encoding default -NoNewline -Force; 
								$runhta = Start-Process "$($htapath)\$($htafile)" -WorkingDirectory "$($htapath)\" -PassThru -ErrorAction SilentlyContinue
								if ($null -ne $runhta){ 
									WriteLog -Message "HTA interface is open with id: $($runhta.Id)" -Component $MyInvocation.MyCommand.Name 
									$global:HTAId = $runhta.Id
									Get-Process -Id $PID -ErrorAction SilentlyContinue | Set-WindowStyle -Style HIDE
									return $runhta;
								}
								return $null
								break;
							}
							"Off" {WriteLog -Message "HTA is off, nothing to do here" -Component $MyInvocation.MyCommand.Name; Get-Process -Id $PID -ErrorAction SilentlyContinue | Set-WindowStyle -Style SHOW; return $null; break;}
							"Restart" {
								WriteLog -Message "Restating HTA" -Component $MyInvocation.MyCommand.Name; 
								"Initializing interface..." | Out-File -FilePath $htamsg -Encoding default -NoNewline -Force; 
								$runhta = Start-Process "$($htapath)\$($htafile)" -WorkingDirectory "$($htapath)\" -PassThru -ErrorAction SilentlyContinue
								if ($null -ne $runhta){ 
									WriteLog -Message "HTA interface is open with id: $($runhta.Id)" -Component $MyInvocation.MyCommand.Name 
									$global:HTAId = $runhta.Id
									Get-Process -Id $PID -ErrorAction SilentlyContinue | Set-WindowStyle -Style HIDE
									return $runhta;
								}
								return $null
								break;
							}
							Default {WriteLog -Message "HTA is Off nothing to do on this case" -Component $MyInvocation.MyCommand.Name; return $null; break;}
						}
					}			
				} else {
	#-------HTA has never run with this script
					if ( (Get-Process | Where-Object ProcessName -eq "HPFullLockScreen" | Measure-Object).Count -gt 0) {
						WriteLog -Message "There are HTA process running but are not controled by this script" -MessageType Warning -Component $MyInvocation.MyCommand.Name
					}
					WriteLog -Message "HTA has never run with this script" -Component $MyInvocation.MyCommand.Name
					#if (Test-Path $htapath) { Get-ChildItem -Path $htapath -Recurse -File | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue; }
					#if (!(Test-Path $htapath) -OR !(Test-Path "$($htapath)\$($htafile)")) { Expand-Archive -Path $htazip -DestinationPath $htapath -Force; }
					switch ($HTAMode) {
						"On" { 
							WriteLog -Message "Starting HTA" -Component $MyInvocation.MyCommand.Name; 
							"[info]Initializing interface..." | Out-File -FilePath $htamsg -Encoding default -NoNewline -Force; 
							$runhta = Start-Process "$($htapath)\$($htafile)" -WorkingDirectory "$($htapath)\" -PassThru -ErrorAction SilentlyContinue
							if ($null -ne $runhta){ 
								WriteLog -Message "HTA interface is open with id: $($runhta.Id)" -Component $MyInvocation.MyCommand.Name 
								$global:HTAId = $runhta.Id
								Get-Process -Id $PID -ErrorAction SilentlyContinue | Set-WindowStyle -Style HIDE
								return $runhta;
							}
							return $null;
							break;
						}
						"Off" {WriteLog -Message "HTA is not required, nothing to do here" -Component $MyInvocation.MyCommand.Name; Get-Process -Id $PID -ErrorAction SilentlyContinue | Set-WindowStyle -Style SHOW; return $null; break;}
						"Restart" {
							WriteLog -Message "Restating HTA" -Component $MyInvocation.MyCommand.Name;
							"Initializing interface..." | Out-File -FilePath $htamsg -Encoding default -NoNewline -Force;  
							$runhta = Start-Process "$($htapath)\$($htafile)" -WorkingDirectory "$($htapath)\" -PassThru -ErrorAction SilentlyContinue
							if ($null -ne $runhta){ 
								WriteLog -Message "HTA interface is open with id: $($runhta.Id)" -Component $MyInvocation.MyCommand.Name 
								$global:HTAId = $runhta.Id
								Get-Process -Id $PID -ErrorAction SilentlyContinue | Set-WindowStyle -Style HIDE
								return $runhta;
							}
							return $null;
							break;
						}
						Default {WriteLog -Message "HTA is off nothing to do on this case" -Component $MyInvocation.MyCommand.Name; return $null; break;}
					}
				}
			
			} #Conditional Debug Mode


		}
		Catch 
		{
			$ErrorMessage = $_.Exception.Message
			WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
		}
		Finally { $ErrorActionPreference = "Continue" }
	}
}

<#
.SYNOPSIS
	Confirmm if key/value is present
.DESCRIPTION
	it will return tru if exiist

.NOTES
	Script version 1.0.4
	Script Date May.5.2021
.PARAMETER Path
	Path to Reg Key
.PARAMETER Key
	Reg Key Name
.PARAMETER Value
	Reg Key Value expected

.EXAMPLE
    GetRegKey -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce -Key "HPControl" -Value "cmd.exe /k"
   
#>
Function GetRegKey{
	[CmdletBinding()]
	Param 
	(
		[Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$True,HelpMessage="Path",Position=0)]
		[ValidateNotNullOrEmpty()]
		[Alias("pathreg")]
		[String]$Path,
		
		[Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$True,HelpMessage="Key",Position=1)]
		[ValidateNotNullOrEmpty()]
		[Alias("keyreg")]
		[String]$Key,

		[Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$True,HelpMessage="Value",Position=2)]
		[ValidateNotNullOrEmpty()]
		[Alias("valuereg")]
		[String]$Value
	)
	Process {	
		$ErrorActionPreference = "Stop";			
		Try 
		{
			$FoundKey=$false
			if (Test-Path $Path) {
				WriteLog -Message "Access level $($Path)"
				$KeyValue = (Get-ItemProperty $Path -Name $Key -ErrorAction SilentlyContinue).PPKG
				if ($KeyValue -eq $Value) { $FoundKey = $true; WriteLog -Message "Found correct value key: $($Key)=$($KeyValue)"; }
			}
			return $FoundKey
		}
		Catch 
		{
			$ErrorMessage = $_.Exception.Message
			WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
		}
		Finally { $ErrorActionPreference = "Continue" }
	}
}

# Check if the enum exists, if it doesn't, create it.
if(!("BusType" -as [Type])){
 Add-Type -TypeDefinition @'
    public enum BusType{
		NVME, 
		SATA, 
		SCSI, 
		IDE, 
		USB 
    }
'@
}

<#
$ErrorActionPreference = 0 #is SilentlyContinue
$ErrorActionPreference = 1 #is Stop
$ErrorActionPreference = 2 #is Continue
$ErrorActionPreference = 3 #is Inquire
$ErrorActionPreference = 4 #is Ignore

-MessageType Info
-MessageType Warning
-MessageType Error

if ($WriteLog) {WriteLog -Message "" -MessageType Error -Path $logdir -Name $logfile } else { Write-Verbose ""}
#>