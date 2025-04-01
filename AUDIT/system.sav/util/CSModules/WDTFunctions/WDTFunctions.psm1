#requires -Modules "WriteLog","RunPower","GetDrive","RunDism"
<#
.SYNOPSIS
    SaveMyLogsWDT simple function to move logs from absolute path to relattive one
.DESCRIPTION
	When an script is called from different location, use this function will help to send al logs files back
.NOTES
	Script version 1.0.2 
	Script Date Apr.18.2021
.PARAMETER CGLOGS
    provide where to drop files as logs
.EXAMPLE
    SaveMyLogsWDT -CGLOGS C:\logsfolder
#>
Function SaveMyLogsWDT {
	[CmdletBinding()]
	Param 
	(
		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$True,HelpMessage="Where are current logs",Position=0)]
		[Alias("path")]
        [String]$CGLOGS
    )
	Begin {
        $ErrorActionPreference = "SilentlyContinue";
        if ((Get-PSCallStack).Count -lt 3){ #call from script
            $GetPath=(Get-Item -Path '.\' -Verbose).FullName
        } else {
            $GetPath = Split-Path (Get-PSCallStack)[(Get-PSCallStack).Count-2].ScriptName -Parent
        }
		if ( $PSBoundParameters.ContainsKey( "CGLOGS" ) -eq $false ) { 
            $CGLOGS = "$($GetPath)\CGLOGS" 
            if (!(Test-Path $CGLOGS)) {New-Item -Path $CGLOGS -ItemType  -Force;}           
        }
        $ExecutionPath=(Get-Item -Path '.\' -Verbose).FullName
	}
	Process {
        Try 
        {
            WriteLog -Message "=============================== SaveMyLogsWDT START ========================================" -Component $MyInvocation.MyCommand.Name
            
            if ( $PSBoundParameters.ContainsKey( "CGLOGS" ) -eq $true ) { 
                if ((Get-PSCallStack).Count -gt 2){
                    $inlcudeFiles=("*.txt","*.ini","*.log","*.err")
                    Get-ChildItem -Path $GetPath -File -Recurse -Include $inlcudeFiles | ForEach-Object { if (!(Test-Path "$($CGLOGS)\$($_.Name)")) {Copy-Item Copy-Item -Path $_.FullName -Destination "$($CGLOGS)\$($_.Name)" -Force } }
                    #$null = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy $($Script:MyInvocation.MyCommand.Path)\* $($CGLOGS)\ /sehiy" -OutFile "$($CGLOGS)\$($MyInvocation.MyCommand.Name).log"
                }
            } 

            if ($CGLOGS.Split("\")[0] -ne $ExecutionPath.Split("\")[0])  {
                WriteLog -Message "Moving logs [$($CGLOGS)] --> [$($ExecutionPath)]" -Component $MyInvocation.MyCommand.Name
                WriteLog -Message "`tMoving *.txt files" -Component $MyInvocation.MyCommand.Name
                WriteLog -Message "`tMoving *.ini files" -Component $MyInvocation.MyCommand.Name
                WriteLog -Message "`tMoving *.log files" -Component $MyInvocation.MyCommand.Name
                WriteLog -Message "`tMoving *.err files" -Component $MyInvocation.MyCommand.Name
                $null = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy $($CGLOGS)\*.txt $($ExecutionPath)\ /hiy" -OutFile "$($CGLOGS)\$($MyInvocation.MyCommand.Name).log"
                $null = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy $($CGLOGS)\*.ini $($ExecutionPath)\ /hiy" -OutFile "$($CGLOGS)\$($MyInvocation.MyCommand.Name).log"
                $null = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy $($CGLOGS)\*.log $($ExecutionPath)\ /hiy" -OutFile "$($CGLOGS)\$($MyInvocation.MyCommand.Name).log"
                $null = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy $($CGLOGS)\*.err $($ExecutionPath)\ /hiy" -OutFile "$($CGLOGS)\$($MyInvocation.MyCommand.Name).log"
            } else {
                WriteLog -Message "Execution path and Logs path are the same path. nothing to move" -Component $MyInvocation.MyCommand.Name
            }	
            WriteLog -Message "============================================================================================" -Component $MyInvocation.MyCommand.Name		
        } 
        Catch 
        {
            $ErrorMessage = $_.Exception.Message
            WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
	}
	Finally { $ErrorActionPreference = "Continue" }	
	
	}

	
}

Function CRIPayload {
	[CmdletBinding()]
	Param 
	(
		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$True,HelpMessage="Where are current logs",Position=0)]
		[Alias("path")]
        [String]$CGLOGS
    )
	Begin {
		if ( $PSBoundParameters.ContainsKey( "CGLOGS" ) -eq $false ) { $CGLOGS = "$($PSScriptRoot)\CGLOGS" }
	}
	Process {
		$ErrorActionPreference = "Stop";
	Try 
	{
		WriteLog -Message "===================Copy Payload process start===========================" -Component $MyInvocation.MyCommand.Name

		WriteLog -Message "Where is located script?" -Component $MyInvocation.MyCommand.Name
	#Get parent level
		$CGLevel = Split-Path $PSScriptRoot -Parent
		WriteLog -Message "Current folder is located at: $($CGLevel)" -Component $MyInvocation.MyCommand.Name;
		$SystemSavLevel = Split-Path $CGLevel -Parent		
		if ((Split-Path -Path $SystemSavLevel -Leaf).ToUpper() -eq "SYSTEM.SAV") { WriteLog -Message "System.sav folder is located at: $($SystemSavLevel)" -Component $MyInvocation.MyCommand.Name; } else {
			WriteLog -Message "Not found system.sav folder: $($SystemSavLevel), down one level." -MessageType Warning -Component $MyInvocation.MyCommand.Name;
			$SystemSavLevel = Split-Path $SystemSavLevel -Parent
			if (!((Split-Path -Path $SystemSavLevel -Leaf).ToUpper() -eq "SYSTEM.SAV")) { WriteLog -Message "System.sav folder wasn't located at: $($SystemSavLevel)" -MessageType Error -Component $MyInvocation.MyCommand.Name; return 404;} 
		}
		$RootLevel = Split-Path $SystemSavLevel -Parent
		
		#include flag for PP when OA3 legacy is used
		if (Test-Path "$($SystemSavLevel)\CG5999OA3") {
			WriteLog -Message "OA3 legacy component located, create flag for PP: $($CGLevel)\ImagePostProc.flg" -Component $MyInvocation.MyCommand.Name
			"Image Post processing flag for OA3 Legacy" | Out-File -FilePath "$($CGLevel)\ImagePostProc.flg" -Encoding default -Force
		} else {
			WriteLog -Message "OA3 legacy component was NOT located [$($SystemSavLevel)\CG5999OA3], skip flag creation" -Component $MyInvocation.MyCommand.Name
		}
		
		############################################
		
		WriteLog -Message "Root folder is located at: $($RootLevel)" -Component $MyInvocation.MyCommand.Name
		WriteLog -Message "Exist SW path?" -Component $MyInvocation.MyCommand.Name
		#Localize SW folder
		$HDD = 99
		if (Test-Path "$($RootLevel)\SW") { 
			$PPKGComps = Get-ChildItem -Path "$($RootLevel)\SW" -Attributes Directory -ErrorAction SilentlyContinue;
			if ($PPKGComps) {
				WriteLog -Message "It found path, searching for specific HP\CSSetup path" -Component $MyInvocation.MyCommand.Name;
			#--- Identify CS component
				foreach ($ppkf in $PPKGComps) {
					if (Test-Path "$($ppkf.FullName)\HP\CSSetup") { 
						$PPKGCompLevel = $ppkf.FullName; WriteLog -Message "Discover valid component $($ppkf.Name)" -Component $MyInvocation.MyCommand.Name; 
					#######################
						WriteLog -Message "Try to identify OS partition, seaching for Basic type" -Component $MyInvocation.MyCommand.Name;
						$OS=(Get-Disk | Get-Partition | Where-Object Type -eq Basic | Get-Volume)
						if ($OS) {
							if (($OS | Measure-Object).Count -gt 1) { WriteLog -Message "There are more than one disk that contains Basic partition, not possible define OS partition" -MessageType Warning -Component $MyInvocation.MyCommand.Name; return 406; }
							WriteLog -Message "Confirming if Drive ($($OS.DriveLetter):\) detected is part of HDD layout expeced (4 partitions for Corporate Ready layout)..." -Component $MyInvocation.MyCommand.Name;
							$OSDisk = (Get-Disk | Get-Partition  | Where-Object DriveLetter -eq $OS.DriveLetter ).DiskNumber
							$OSDiskPartitions = (Get-Disk -Number $OSDisk).NumberOfPartitions
							[int]$HDD=$OSDisk
							WriteLog -Message "OS drive belong to disk #$($OSDisk)" -Component $MyInvocation.MyCommand.Name
							if ($OSDiskPartitions -eq 4) {
								WriteLog -Message "Drive seems to be expected, start copy Payload..." -Component $MyInvocation.MyCommand.Name
								$CopyResource = RunPower -File "cmd.exe" -Params "/c xcopy /sehiy $($PPKGCompLevel)\* $($OS.DriveLetter):\" -WorkDir $PSScriptRoot -OutFile "$($CGLOGS)\_CopyPayload2HDD.log";
								if ($CopyResource -ne 0) {
									WriteLog -Message "Failed copying payload into OS Disk, review log _CopyPayload2HDD.log" -MessageType Error -Component $MyInvocation.MyCommand.Name;
								} else {
									WriteLog -Message "Copy Payload complete successfully, remove source" -Component $MyInvocation.MyCommand.Name;
									WriteLog -Message "+H Hide HP folder $($OS.DriveLetter):\HP" -Component $MyInvocation.MyCommand.Name
									$null = RunPower -File "cmd.exe" -Params "/c attrib +h $($OS.DriveLetter):\HP /s /d " -OutFile "$($CGLOGS)\_HideHP.log";  
									WriteLog -Message "+H Hide system.sav folder $($OS.DriveLetter):\system.sav" -Component $MyInvocation.MyCommand.Name
									$null = RunPower -File "cmd.exe" -Params "/c attrib +h $($OS.DriveLetter):\System.sav /s /d " -OutFile "$($CGLOGS)\_HideSYSTEMSAV.log";
									WriteLog -Message "Remove payload from logs to reduce size $($PPKGCompLevel)" -Component $MyInvocation.MyCommand.Name
									$null = RunPower -File "cmd.exe" -Params "/c rd /s /q $($PPKGCompLevel)" -OutFile "$($CGLOGS)\_DeleteDash.log"; 
									"CS Corporate Ready Image" | Out-File -FilePath "$($RootLevel)\SW\$($ppkf.Name)_done" -Encoding default -Force
								}
								$null = RunPower -File "cmd.exe" -Params "/c dir /a $($OS.DriveLetter):\" -WorkDir $PSScriptRoot -OutFile "$($CGLOGS)\_ContentOS.log";
							} else {
								WriteLog -Message "Not possible define OS drive. abort process" -MessageType Warning -Component $MyInvocation.MyCommand.Name;
								return 407
							}
						}
					######################
					}
				}
			} else {
				WriteLog -Message "Not possible found SW folder on Root ($($RootLevel)\SW)" -MessageType Warning -Component $MyInvocation.MyCommand.Name;
				return 405;
			}
		} else {
			WriteLog -Message "Not found SW folder at $($RootLevel)" -MessageType Warning -Component $MyInvocation.MyCommand.Name;
		}
		
		#Review if loaded on any partition
		WriteLog -Message "--------- Try to detect Payload on any Partition" -Component $MyInvocation.MyCommand.Name;
		$parts = Get-Disk  | Get-Partition | Where-Object Type -ne Reserved
		#ensure that all partitions has Drive letter
		$dp="$($CGLOGS)\dp.txt"
		if (Test-Path $dp) { Remove-Item -Path $dp -Force }
		foreach ($p in $parts) { 
			if (!($p.DriveLetter)) {
				"sel dis $($p.DiskNumber)" | Out-File -FilePath $dp -Encoding default -Append -Force
				"sel part $($p.PartitionNumber )" | Out-File -FilePath $dp -Encoding default -Append -Force
				"ass" | Out-File -FilePath $dp -Encoding default -Append -Force
			} 
		}
		if (Test-Path $dp) {
			"lis vol" | Out-File -FilePath $dp -Encoding default -Append -Force
			"exit" | Out-File -FilePath $dp -Encoding default -Append -Force
			$null = RunPower -File "cmd.exe" -Params "/c Diskpart /s $($dp)" -WorkDir $PSScriptRoot -OutFile "$($CGLOGS)\_Diskpart.log";
		}
		#Verify partition by partition
		foreach ($p in $parts) { 
			$Drive = Get_DriveLetter $p.DiskNumber $p.PartitionNumber -Verbose
			if (($null -ne $Drive) -OR ($Drive -ne "")) {
				WriteLog -Message "Searching SW folder into $($Drive)\SW" -Component $MyInvocation.MyCommand.Name
				if (Test-Path "$($Drive)\SW") {
					WriteLog -Message "Found SW folder into $($Drive), try to remove it" -Component $MyInvocation.MyCommand.Name
					$null = RunPower -File "cmd.exe" -Params "/c rd /s /q $($Drive)\SW" -OutFile "$($CGLOGS)\_DeleteSW_$($p.DiskNumber)$($p.PartitionNumber).log"; 
					if (!(Test-Path "$($Drive)\SW")) { WriteLog -Message "Successfully removed from $($Drive)\" -Component $MyInvocation.MyCommand.Name; } else { WriteLog -Message "Not possible remove from $($Drive)\" -MessageType Error -Component $MyInvocation.MyCommand.Name; }
				} else {
					WriteLog -Message "Not detected SW folder in $($Drive)\" -Component $MyInvocation.MyCommand.Name
				}
			} else {
				WriteLog -Message "Partition [$($p.DiskNumber):$($p.PartitionNumber)] has no letter associated, skip search" -MessageType Warning -Component $MyInvocation.MyCommand.Name
			}
		}
		WriteLog -Message "===================Copy Payload process reach end===========================" -Component $MyInvocation.MyCommand.Name
		return 0
	} 
	Catch 
	{
		$ErrorMessage = $_.Exception.Message
		WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error
		return 500
	}
	Finally { $ErrorActionPreference = "Continue" }	
	
	}

	
}


Function Get-Exception{
    [CmdletBinding()]
    Param
    (
		[Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$True,HelpMessage="Where is SiteList.xml",Position=0)]
		[ValidateNotNullOrEmpty()]
		[Alias("site")]
        [String]$SiteList
    )
    Process
    {
		try {
			$SystemId=(Get-WmiObject Win32_BaseBoard).Product
			[xml]$SiteListXML = Get-Content $SiteList
			#Check ODM platform
			$Platform = $SiteListXML.SelectSingleNode("//ODMProcess//Platform[SystemID='$($SystemId.ToLower())']")        
			if ($null -ne $Platform)
			{
				WriteLog -Message "SystemID '$($SystemId)' is listed in SiteList.xml as an ODM platform" -Component $MyInvocation.MyCommand.Name
				return "ODM"
			}

			# Check CM platform
			$Platform = $SiteListXML.SelectSingleNode("//CMProcess//Platform[SystemID='$($SystemId.ToLower())']")
			if ($null -ne $Platform)
			{
				WriteLog -Message "SystemID '$($SystemId)' is listed in SiteList.xml as a CM platform" -Component $MyInvocation.MyCommand.Name
				return "CM"
			}
			
			return $null
		} 
		Catch 
		{
			$ErrorMessage = $_.Exception.Message
			WriteLog -Message "Exception on Get-Exception: $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
			return $null
		}
    }
}

Function Test-ODM {
	[CmdletBinding()]
	Param 
	(	
		[Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$True,HelpMessage="Where is SiteList.xml",Position=0)]
		[ValidateNotNullOrEmpty()]
		[Alias("site")]
        [String]$SiteList
    )
	Begin {
	}
	Process {
		Try 
		{
			WriteLog -Message "Validate on Exception list..." -Component $MyInvocation.MyCommand.Name
			switch ( Get-Exception -SiteList $SiteList)
			{
				"ODM"
					{
						WriteLog -Message "It is an ODM process" -Component $MyInvocation.MyCommand.Name
						return $true
					}

				"CM"
					{
						WriteLog -Message "It is a CM process" -Component $MyInvocation.MyCommand.Name
						return $false
					}

				Default
					{
						WriteLog -Message "Validate with bios value..." -Component $MyInvocation.MyCommand.Name
						$SKUNumber = gcim -Namespace "root/HP/InstrumentedBIOS" -ClassName "HP_BIOSString" | Where-Object Name -eq "SKU Number"
						if ($SKUNumber.Value) {
							WriteLog -Message "Unit has SKU Number: [$($SKUNumber.Value)]"
							if ($SKUNumber.Value.ToString().Contains('@GM')) {
								WriteLog -Message "ODM detected by skunumber@GM: $($SKUNumber.Value)" -Component $MyInvocation.MyCommand.Name;
								return $true;
							}
						} else {
							WriteLog -Message "Not possible read SKU Number" -MessageType Error -Component $MyInvocation.MyCommand.Name;
						}
						return $false;
					}
			}
		} 
		Catch 
		{
			$ErrorMessage = $_.Exception.Message
			WriteLog -Message "Exception on Test-ODM Message: $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
		}
		Finally { $ErrorActionPreference = "Continue" }
	}
	end {        
    }
}