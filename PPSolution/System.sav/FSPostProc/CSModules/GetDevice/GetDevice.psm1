#requires -Modules "WriteLog","RunPower","GetDrive"
<#
.SYNOPSIS
	Get a detailed report of Devices on current unit
.DESCRIPTION
	Get a full report of devices on current unit, report format is XML 
	It require Get_DriveByPath funtion loaded
.NOTES
	Script version 1.0.4
	Script Date June.26.2023
.PARAMETER ReportName
    Optional. Where to drop report fil, it is the full path to xml file, if exist it will replaced with new one without ask. 
	If this parameter is not provided by default is created on same location where was called with name: HPReportDevices.xml
.PARAMETER ContinueOnError
	Optional. by default the process continue no matter result, disable this options can break all script process.
.EXAMPLE

    DeviceReport -ReportName $PSScriptRoot"\ReportDevice.xml"
#>
Function DeviceReport {
	[CmdletBinding()]
	Param 
	(
		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$True,HelpMessage="Where to drop report",Position=0)]
		[AllowNull()]
		[Alias("name")]
        [String]$ReportName,
		
		[Parameter(Mandatory=$false,HelpMessage="should continue if result is not expected",Position=1)]
		[Alias("Continue")]
        [bool]$ContinueOnError=$true

    )
	Begin {
		if ((Get-PSCallStack).Count -lt 3){ #call from script
			$scriptpath=(Get-Item -Path '.\' -Verbose).FullName
		} else {
			$scriptpath = Split-Path (Get-PSCallStack)[(Get-PSCallStack).Count-2].ScriptName -Parent
		}
		
	}
	Process {
		if ( $PSBoundParameters.ContainsKey( "ReportName" ) -eq $false -OR $null -eq $ReportName) # Parameter not specified
        {			
			$ReportName = "$($scriptpath)\HPReportDevices.xml"
        }
		$ErrorActionPreference = "Stop";
		Try 
		{				
			WriteLog -Message "************************DRIVER SUMMARY REPORT************************************" -Component $MyInvocation.MyCommand.Name;
			if	(Test-Path $ReportName) { 
				WriteLog -Message "`Report file exist, remove to create new one..." -Component $MyInvocation.MyCommand.Name;
				Remove-Item $ReportName -Force 
			}
			WriteLog -Message "`tScaning Devices in local computer $($env:COMPUTERNAME)"  -Component $MyInvocation.MyCommand.Name;
			$WMIDevices = Get-WmiObject Win32_PNPEntity
			WriteLog -Message "`tDevices detected: $($WMIDevices.count)" -Component $MyInvocation.MyCommand.Name;

			if (Test-Path HKLM:\SYSTEM\CurrentControlset\Control\MiniNT) { #WinPE environment detected 
				$WinPart = Get_DriveByPath -Path "\Windows\HPInc"
				if ($null -eq $WinPart -OR $WinPart -eq ""){ $WinPart = Get_DriveByPath -Path "\Windows\system32\" }
				if ($null -ne $WinPart -AND $WinPart.Trim().length -eq 2) {
					WriteLog -Message "Retrieve Drivers information from WinPE environment on OS Drive: [$($WinPart)\]" -Component $MyInvocation.MyCommand.Name;
					$Drivers = Get-WindowsDriver -Path "$($WinPart)\" -All
				}
			} else {
				WriteLog -Message "Retrieve Drivers information from Windows environment" -Component $MyInvocation.MyCommand.Name;
				$Drivers = Get-WindowsDriver -Online -All
			}
			
			
			$DevicesFail = @()
			$noins = 0
			$yesins = 0
			$sComputer = Get-WmiObject Win32_Computersystem
			
			WriteLog -Message "`tBuilding report file [$($ReportName)]" -Component $MyInvocation.MyCommand.Name;
			$XmlWriter = New-Object System.XMl.XmlTextWriter($ReportName,$Null)   
			$xmlWriter.Formatting = "Indented"
			$xmlWriter.Indentation = "4"
			$xmlWriter.WriteStartDocument()
			$xmlWriter.WriteStartElement("HP")
			$XmlWriter.WriteAttributeString("Model",$sComputer.Model)
		#---- List all Devices	
			Foreach ($device in $WMIDevices) {
				$xmlWriter.WriteStartElement("DEVICE")  
				$XmlWriter.WriteAttributeString("Name", $device.Name) 
				$xmlWriter.WriteElementString("DevID",$device.DeviceID) 
			
				if ($null -ne $device.HardwareID) {
					Foreach ($HWID in $device.HardwareID) { $xmlWriter.WriteElementString("HWID",$HWID) }
				}
			
				$xmlWriter.WriteElementString("Manufacturer",$device.Manufacturer)		
				$xmlWriter.WriteElementString("ErrorCode",$device.ConfigManagerErrorCode)		
				$xmlWriter.WriteElementString("Description",$device.Description)
			
				if ($device.ConfigManagerErrorcode -ne 0) {
					if ($device.ConfigManagerErrorcode -eq 24) {
						WriteLog -Message "Device: $($device.Name) seems to be offline, not an issue. Code: [$($device.ConfigManagerErrorcode)]" -Component $MyInvocation.MyCommand.Name;
					} else {
						$noins++
						WriteLog -Message "Not expected code for $($device.Name) [$($device.ConfigManagerErrorcode)]" -MessageType Error -Component $MyInvocation.MyCommand.Name;
						if ($null -ne $device.HardwareID) {
							$DevicesFail += $device.HardwareID[0]
						} else {
							$DevicesFail += $device.DeviceID
						}
					}					
				} else {
					$yesins++
				}
			#--------------------------DRIVER Information, cross information
				if ($null -ne $Drivers) {
					$SelDrivers = $null
					$SelDrivers = $Drivers | Where-Object {$_.ClassGuid -eq $device.ClassGuid}
					if ($null -ne $SelDrivers) {
						$xmlWriter.WriteStartElement("DRIVERS")  
						$XmlWriter.WriteAttributeString("GUID", $device.ClassGuid)
						Foreach ($dri in $SelDrivers) {
							$xmlWriter.WriteStartElement("DRIVER") 
								$xmlWriter.WriteElementString("Name",$dri.Driver)
								$xmlWriter.WriteElementString("Version",$dri.Version)
								$xmlWriter.WriteElementString("Provider",$dri.ProviderName)
								$xmlWriter.WriteElementString("Date",$dri.Date)
								$xmlWriter.WriteElementString("File",$dri.OriginalFileName)
							$XmlWriter.WriteEndElement()
						}
						$XmlWriter.WriteEndElement()
					}
				}
			#--------------------------DRIVER Information
				$XmlWriter.WriteEndElement()
			}
			$xmlWriter.WriteEndElement()
			$xmlWriter.WriteEndDocument()  
			$xmlWriter.Flush()  
			$xmlWriter.Close()
			
				WriteLog -Message "`tThere are $($yesins)/$($WMIDevices.count) drivers installed" -Component $MyInvocation.MyCommand.Name;
				WriteLog -Message "`tThere are $($DevicesFail.Count) drivers with errors" -Component $MyInvocation.MyCommand.Name;
				WriteLog -Message "************************DRIVER SUMMARY REPORT************************************"  -Component $MyInvocation.MyCommand.Name;
			
			return $DevicesFail			
		} 
		Catch 
		{
			$ErrorMessage = $_.Exception.Message
			WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name;
			if (!($ContinueOnError)){ Exit 901}
		}
		Finally { $ErrorActionPreference = "Continue" }
	
	}

	
}

Function RescanDevices {
	[CmdletBinding()]
	Param 
	(
		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$True,HelpMessage="Where to drop log",Position=0)]
		[AllowNull()]
		[Alias("path")]
        [String]$logpath
    )
	Begin { 
		if ( $PSBoundParameters.ContainsKey( "logpath" ) -eq $false ) { 
			if ((Get-PSCallStack).Count -lt 3){  #call from Command line
				$logpath =(Get-Item -Path '.\' -Verbose).FullName
			} else {
				$logpath = Split-Path (Get-PSCallStack)[(Get-PSCallStack).Count-2].ScriptName -Parent
			}
		}
	}
	Process {
		try {
			WriteLog -Message "Process start: Rescan Devices using PNPUtil" -Component $MyInvocation.MyCommand.Name;
			$WMIDevices = Get-WmiObject Win32_PNPEntity
			if ($null -eq $WMIDevices) { WriteLog -Message "Not possible read WMI PNPEntity" -MessageType Error -Component $MyInvocation.MyCommand.Name;; return $null }
			$ErrorsFound=0
			$ErrorFixed=0
			$WMIDevices | Where-Object {($_.ConfigManagerErrorCode -ne 0) -AND ($_.ConfigManagerErrorCode -ne 24)} | ForEach-Object {
				WriteLog -Message "Remove HWId: $($_.DeviceID)" -Component $MyInvocation.MyCommand.Name;
				$ErrorsFound++
				$intPNPUtil = Invoke-RunPower -File "pnputil.exe" -Params "/remove-device ""$($_.DeviceID)""" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logpath)\pnputiltemp.log" -Verbose
				if ($intPNPUtil -ne 0) { WriteLog -Message "Not possible remove device $($_.Name) [$($_.DeviceID)]" -MessageType Warning -Component $MyInvocation.MyCommand.Name;}
			}			
			WriteLog -Message "Rescan Devices using PNPUtil" -Component $MyInvocation.MyCommand.Name;
			#adding a small pause
			Start-Sleep -Seconds 10
			$null = Invoke-RunPower -File "pnputil.exe" -Params "/scan-devices" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logpath)\pnputiltemp.log" -Verbose
			Start-Sleep -Seconds 20
			$WMIDevices2nd = Get-WmiObject Win32_PNPEntity
			$WMIDevices2nd | Where-Object {$_.ConfigManagerErrorCode -ne 0} | ForEach-Object {
				if ($_.ConfigManagerErrorCode -eq 24) {
					WriteLog -Message "This device was detected with error code 24 (offline), it's ignored: $($_.DeviceID)" -Component $MyInvocation.MyCommand.Name;
				} else {
					$ErrorFixed++;
					WriteLog -Message "This device was detected with error code $($_.ConfigManagerErrorCode), it's was not possible to fix by rescan: $($_.DeviceID)" -MessageType Warning -Component $MyInvocation.MyCommand.Name;
				}
			}
			if ($ErrorsFound -gt 0) {
				WriteLog -Message "It was detected/notfixed devices: $($ErrorsFound)/$($ErrorFixed)" -Component $MyInvocation.MyCommand.Name;
				return $ErrorFixed
			} else {
				WriteLog -Message "Not found errors on Device Manager" -Component $MyInvocation.MyCommand.Name;
				return $ErrorsFound
			}
		}
		catch {
			$ErrorMessage = $_.Exception.Message
			WriteLog -Message "Unhandled error detected: $($ErrorMessage) " -MessageType Error -Component $MyInvocation.MyCommand.Name;
			return $null
		}
	}

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

if ($WriteOut) {WriteLog -Message "" -MessageType Error -Path $logdir -Name $logfile } else { Write-Verbose ""}
#>