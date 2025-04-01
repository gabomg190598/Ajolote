<#
.SYNOPSIS
    Write log function
.DESCRIPTION
	Create and register all events on specific format and  file  
.NOTES
	Script version 1.0.6
	Script Date Feb.21.2024
		1.0.1 Update name of file due error when script contains more than one point on name
		1.0.2 Small update to validate $global:PathLog
		1.0.3 $global:PathLog fail when is called as module, fixing
		1.0.4 Small changes to cmdlet names
		1.0.5 Renew script to spport all current scenarios
		1.0.6 Use 24H for standard clock
.PARAMETER Name
    Name of file, by default it takes the current name as name. 
	Global parameter can save this value on variable $global:NameLog, this values is saved for future use until this paramet is call again
.PARAMETER Path
   Where to save log, default is same as invoke script
   Global parameter can save this value on variable $global:PathLog, this values is saved for future use until this paramet is call again
.PARAMETER Message
		Any message to save on log
.PARAMETER MessageType
    Accepted 3 types of messages:
		Log = Info
		Log = Warning
		Log = Error
.PARAMETER Format
	It accepts 2 formats, basic and standard which can be read with any txt reader and Trace which support Trace applications= Trace32 or CMTrace
	parameter is saved on $global:FormatLog, this avoid to require for new call of function
.EXAMPLE

    WriteLog -Name Setup.log -Path C:\Windows\Tem\ -Message "---Process Start----" -MessageType Info
#>
function WriteLog {
    [CmdletBinding()]
    Param(
		[Parameter(HelpMessage="Message to write on log", Position=0, Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$True)]
        [Alias("Msg")]
        [string[]] $Message,
		
		[Parameter(HelpMessage="Directory to save log", Position=1, ValueFromPipelineByPropertyName=$true)]
		[AllowNull()]
        [Alias("FilePath")]
        [string] $Path,
		
        [Parameter(HelpMessage="Name of log file.", Position=2, ValueFromPipelineByPropertyName=$true)]
        [AllowNull()]
        [Alias("FileName")]
        [string] $Name, 
		
		[Parameter(HelpMessage="Type of message for log", Position=3,ValueFromPipelineByPropertyName=$true)]
        [ValidateSet("Info", "Warning", "Error")]
        [Alias("Type")]
        [string] $MessageType="Info",
		
		[Parameter(HelpMessage="Format log", Position=4)]
        [ValidateSet("Basic", "Trace")]
        [Alias("fm")]
        [string] $Format,
		
		[Parameter(HelpMessage="Component Root", Position=5)]
        [AllowNull()]
        [Alias("comp")]
        [string] $Component

    )
	Begin {
		if (-not $PSBoundParameters.ContainsKey('Verbose'))
		{
			$VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
		}
	}
	
	Process {
		# Set Log Directory by default usinng  Global var
        if ( $PSBoundParameters.ContainsKey( "Path" ) -eq $false ) # Parameter not specified
        {
			if ( $null -ne $global:PathLog -AND $global:PathLog.Length -gt 2)
            {
                $Path = $global:PathLog
            }
            else # Use default value
            {
				if ((Get-PSCallStack).Count -lt 3){  #call from Command line
					$Path =(Get-Item -Path '.\' -Verbose).FullName
					$global:PathLog = $Path
				} else {
					if ($null -ne $Script:MyInvocation.MyCommand.Path) { #invoke from other script
						$Path = Split-Path (Get-PSCallStack)[(Get-PSCallStack).Count-2].ScriptName -Parent
						$global:PathLog = Split-Path (Get-PSCallStack)[(Get-PSCallStack).Count-2].ScriptName -Parent
					} else {
						$Path = $MyInvocation.PSScriptRoot
						$global:PathLog = $MyInvocation.PSScriptRoot
					}
				}				
            }			
        } else {
			if (Test-Path $Path) {
				$global:PathLog=$Path
			} else {
				New-Item -Path $Path -ItemProperty Directory -Force
				$global:PathLog=$Path
			}
			
		}
		# Set Log Name
        if ( $PSBoundParameters.ContainsKey( "Name" ) -eq $false ) # Parameter not specified
        {
			if ( $null -ne $global:NameLog )
            {
                $Name = $global:NameLog
            }
            else # Use default value
            {
				if ((Get-PSCallStack).Count -lt 3){ #call from script
					$Name="WriteLog.log"
				} else {
					[int]$CountStack=(Get-PSCallStack).Count-2
					$Name = (Get-PSCallStack)[$CountStack].Command
					if ($Name.ToLower().EndsWith(".ps1")) {
						$Name = $Name.substring(0,[int]($Name.length)-4) + ".log"
					} else {
						$Name = $Name + ".log"
					}
				}
                $global:NameLog = $Name
            }            
        } else {
			$global:NameLog=$Name
		}
		# Set Component value if not provided
        if ( $PSBoundParameters.ContainsKey( "Component" ) -eq $false ) # Parameter not specified
        {
			if ((Get-PSCallStack).Count -lt 3){ #call from script
				$Component = "PSCMD"
			} else {
				$Component = ( Get-PSCallStack )[1].Command
			}            
        }
		if ( $PSBoundParameters.ContainsKey( "Format" ) -eq $false ) # Parameter not specified
        {
            if ( $null -ne $global:FormatLog )
            {
                $Format = $global:FormatLog
            }
            else # Use default value
            {
                $Format = "Basic"
                $global:FormatLog = "Basic"
            }
        } else {
			$global:FormatLog = $Format
		}
		$WhereLog = Join-Path $Path $Name
		$WhereLog2 = Join-Path $Path $Name.Replace(".log","_Execption.log")
		$DateLog = Get-Date -format "[MM-dd-yy : HH:mm:ss]"
		switch ($MessageType.Tolower()) 	{
			"info" { $Code = "   Info"; $CodeID=1; break}
			"warning" { $Code = "   Warn"; $CodeID=2; break}
			"error" { $Code = "  Error"; $CodeID=3; break}
			default { $Code = "Message"; $CodeID=0; break}
		}
		
		$ErrorActionPreference = "Stop"
		Try
		{ 
			if ($Format.Tolower() -eq "trace") {
				$Message | ForEach-Object {
					$TimeStamp = ( Get-Date -Format "HH:mm:ss.fff" ) + "{0:+000;-000}" -f ( [Int32]( Get-Date -Format "%z" ) * -60 )
					$DateStamp = Get-Date -Format "MM-dd-yyyy"
					$File = "$( ( Get-PSCallStack )[1].Command ).ps1"
					#$Component = $Name.Split( '.' )[0]
					$LogEntry = "<![LOG[$_]LOG]!>" +
								"<time=`"$TimeStamp`" date=`"$DateStamp`" component=`"$Component`" context=`"`" type=`"$($CodeID -as [Int32])`" thread=`"$Component`" file=`"$File`">"
					
					$LogEntry | Out-File $WhereLog -Append -Encoding default
					Write-Verbose "`t [$($Component)] - $($_)"
				}
			} else {
				$LogEntry = "$($DateLog) `t [$($Code)] - $Message" 
				$LogEntry | Out-File $WhereLog -Append -Encoding default
				$Message | Foreach-Object {
					Write-Verbose "`t [$($Code)] - $($_)"
				}
			}
		}
		Catch 
		{
			$ErrorMessage = $_.Exception.Message
			Write-Warning "Exception error on $($MyInvocation.MyCommand.Name) function: $($ErrorMessage)"
			$LogEntry2 = "$($DateLog) `t [$($Code)] - $Message" 
			$LogEntry2 | Out-File $WhereLog2 -Append -Encoding default
		}
		Finally { $ErrorActionPreference = "Continue" }	
	
	}
}

