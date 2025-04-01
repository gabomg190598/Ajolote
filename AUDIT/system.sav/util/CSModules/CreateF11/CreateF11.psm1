#This module require elevate permision to execute
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{   
	#$arguments = "& '" + $myinvocation.mycommand.definition + "'"
	Write-Warning "Elevate Comand line as Administrator, module not loaded $($MyInvocation.MyCommand.Name)" 
	#Start-Process powershell -Verb runAs -ArgumentList $arguments
	Break
}
#requires -Modules "WriteLog","RunPower","GetDrive"
<#
.SYNOPSIS
    Function to detect or create F11 partition, it will return drive letter of Recovery partition
.DESCRIPTION
	Function to detect or create F11 partition, it will return drive letter of Recovery partition.
    Before to run this fucntion ensure that ValidateDisk function already run successfully since this process require global variables
    $global:HDD_Disk & $global:GPT
	Some modules are required for this module, ensure you include:
		GetDrive.psm1
		WriteLog.psm1
		RunPower.psm1
.NOTES
	Script version 1.0.2
	Script Date Jul.9.2021
.PARAMETER Size
	Requied to create new partition or validate if current is valid
.PARAMETER Hide
	Optional. If layout is GPT, this allows to prevent or confirm if F11 partition ID set as recovery
.PARAMETER Logs
	Optional. some files could created, if not specify will remain on same path as script
.PARAMETER ContinueOnError
	Options. by default the process continue no matter result, disable this options can break all script process.

.EXAMPLE

    CreateF11 -Size 10240 -Hide $true -Verbose
#>

Function CreateF11 {
	[CmdletBinding()]
	[OutputType([string])]
	Param 
	(
		[Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$True,HelpMessage="Provide Minimum size in MB",Position=0)]
		[ValidateNotNullOrEmpty()]
		[Alias("F11Size")]
        [int]$Size,
		
		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$True,HelpMessage="if layout is GPT this option set Recovery ID",Position=1)]
		[ValidateNotNullOrEmpty()]
		[Alias("HideRecovery")]
        [bool]$Hide,

		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$True,HelpMessage="Where drop files",Position=2)]
		[ValidateNotNullOrEmpty()]
		[Alias("PathLogs")]
        [string]$Logs

    )
	Begin {
        $ErrorActionPreference = "Stop";
		#Label of Recovery partition
		$HP_RECOVERY = "HP_RECOVERY"
		WriteLog -Message "================= F11 Laegacy Solution Preparation Start ==================="  -Component $MyInvocation.MyCommand.Name
		if ( $PSBoundParameters.ContainsKey( "Hide" ) -eq $false ) { $Hide=$true}
		if ( $PSBoundParameters.ContainsKey( "Logs" ) -eq $false ) {
			if ((Get-PSCallStack).Count -lt 3){  #call from Command line
            	$PathCall =(Get-Item -Path '.\' -Verbose).FullName
        	} else {
           	 	$PathCall = Split-Path (Get-PSCallStack)[(Get-PSCallStack).Count-2].ScriptName -Parent
        	}
		} else {
			$PathCall=$Logs
		}
		WriteLog -Message "`tDrop files on $($PathCall)"
	}
	Process { 
		
		Try 
		{            
		#----------------> Search in MSC.xml
			$RelativePath = (Get-Item -Path '.\' -Verbose).FullName
			if ($RelativePath.ToLower().Contains("system.sav")){ $rootDash = $RelativePath.Substring(0,$RelativePath.ToLower().IndexOf("system.sav")) } else { WriteLog -Message "Drive label $($HP_RECOVERY) wasn't detect due MSC.xml is not present"  -MessageType Warning -Component $MyInvocation.MyCommand.Name }
			if ($null -ne $rootDash -AND (Test-Path "$($rootDash)\MSC\MSC.xml")) { 
				WriteLog -Message "DASH in progress detected, search on MSC.xml"  -Component $MyInvocation.MyCommand.Name
				[xml]$xml = Get-Content -Path "$($rootDash)\MSC\MSC.xml"
				$XMLparts = $xml.HDDs.ChildNodes.Partition | Where-Object {($null -ne $_.Label) -AND ($_.Label.ToUpper() -eq $HP_RECOVERY)}
				if (($XMLparts | Measure-Object).Count -eq 1) {
					$XMLparts = $xml.HDDs.ChildNodes.Partition | Where-Object {($null -ne $_.Label) -AND ($_.Label.ToUpper() -eq $HP_RECOVERY)}
					WriteLog -Message "MSC.xml Disk: $($XMLparts.ParentNode.Number)"  -Component $MyInvocation.MyCommand.Name
					WriteLog -Message "MSC.xml Partition: $($XMLparts.Order)"  -Component $MyInvocation.MyCommand.Name
					WriteLog -Message "MSC.xml Type: $($XMLparts.TYPE)"  -Component $MyInvocation.MyCommand.Name
					WriteLog -Message "MSC.xml Size: $($XMLparts.SIZE)"  -Component $MyInvocation.MyCommand.Name
					
					if ($null -ne $global:HDD_Disk) {
						WriteLog -Message "Detected Global Disk, search Letter..."  -Component $MyInvocation.MyCommand.Name
						$UsedDiskNumber=$global:HDD_Disk
					} else {
						WriteLog -Message "Missing Global Disk, try with MSC Disk, Detecting letter..." -Component $MyInvocation.MyCommand.Name
						$UsedDiskNumber=$XMLparts.ParentNode.Number
					}
					$RecoveryPart = Get_DriveLetter -iDisk $UsedDiskNumber -iPart $XMLparts.Order
					if (($null -eq $RecoveryPart) -OR ($RecoveryPart.Length -lt 2)) {
						WriteLog -Message "F11 Was not successfully detected in [disk#:$($XMLparts.Order)]" -MessageType Warning -Component $MyInvocation.MyCommand.Name;
					} else {
						WriteLog -Message "F11 detected drive to use under F11 = [$($RecoveryPart)]" -Component $MyInvocation.MyCommand.Name;
						if ([math]::round((Get-Disk -Number $UsedDiskNumber | Get-Partition -PartitionNumber $XMLparts.Order).Size / 1Mb) -lt $Size) {
							#WriteLog -Message "Partition detected is too small [$((Get-Disk | Get-Partition | Where-Object {$_.DriveLetter -eq $RecoveryPart.Substring(0,1)}).Size / 1Mb)MB]  :: [$($Size)]" -MessageType Error -Component $MyInvocation.MyCommand.Name;
							WriteLog -Message "Partition detected is too small [$((Get-Disk -Number $UsedDiskNumber | Get-Partition -PartitionNumber $XMLparts.Order).Size / 1Mb)MB]  :: [$($Size)]" -MessageType Error -Component $MyInvocation.MyCommand.Name;
							return $null
						} else {
							WriteLog -Message "Partition detected size: [$((Get-Disk -Number $UsedDiskNumber | Get-Partition -PartitionNumber $XMLparts.Order).Size / 1Mb)MB]" -Component $MyInvocation.MyCommand.Name;
							return $RecoveryPart #---------------Drive detected by MSC.xml
						}
					}
				} else {
					WriteLog -Message "Not found expected partitions with label $($HP_RECOVERY) on MSC.xml[$(($XMLparts | Measure-Object).Count)]" -MessageType Warning -Component $MyInvocation.MyCommand.Name 
				}
			}
		#----------------- Search by Label
			#$SearchLabel = Get-Volume | Where-Object {($_.FileSystemLabel.ToUpper() -eq $HP_RECOVERY) -AND ($_.DriveType -eq "Fixed")} | Get-Partition
			$SearchLabel =Get_DriveByLabel -Label $HP_RECOVERY
			if (![string]::IsNullOrWhiteSpace($SearchLabel)) {
			#if ($null -ne $SearchLabel) {
				#if ($global:HDD_Disk -ne $SearchLabel.DiskNumber) { WriteLog -Message "Global disk[$($global:HDD_Disk)] is not the same as detected[$($SearchLabel.DiskNumber)] with $($HP_RECOVERY) partition" -MessageType Error -Component $MyInvocation.MyCommand.Name; return $null}
				#$getDrive = Get_DriveLetter -iDisk $global:HDD_Disk -iPart $SearchLabel.PartitionNumber
                #if ($null -eq $getDrive) {WriteLog -Message "Not possible detect drive letter for [$($global:HDD_Disk):$($SearchLabel.PartitionNumber)]" -MessageType Error -Component $MyInvocation.MyCommand.Name; return $null}
				#WriteLog -Message "F11 Drive was detected by Label = $($getDrive)" -Component $MyInvocation.MyCommand.Name
				#if ([math]::round($SearchLabel.Size / 1Mb)+2 -lt $Size) {
				#	WriteLog -Message "Partition detected is too small [$([math]::round($SearchLabel.Size / 1Mb)+2)MB] :: [$($Size)MB]" -MessageType Warning -Component $MyInvocation.MyCommand.Name;
				#	return $null
				#} else {
				#	WriteLog -Message "Partition detected size: [$([math]::round($SearchLabel.Size / 1Mb))MB]" -Component $MyInvocation.MyCommand.Name;
				#	return $getDrive #---------------Drive detected by Label
				#}
				WriteLog -Message "Drive letter found for partition with label=[$($HP_RECOVERY)] Drive=[$($SearchLabel)]" -Component $MyInvocation.MyCommand.Name
				return $SearchLabel #---------------Drive detected by Label
			} else {
				WriteLog -Message "Drive wasn't detected by Label $($HP_RECOVERY) on all disks" -Component $MyInvocation.MyCommand.Name -MessageType Warning
			}
		#---------------> Not found in MSC or by Label, create new partition
			WriteLog -Message "$($HP_RECOVERY) wasn't detect by MSC or Label now let's creating new parition" -Component $MyInvocation.MyCommand.Name
			if (($null -eq $global:HDD_Disk) -OR ($null -eq $global:GPT)) { WriteLog -Message "Not valid HDD was detected, not possible determinate where create $($HP_RECOVERY)" -MessageType Error -Component $MyInvocation.MyCommand.Name; return $null } 
			#determinate biggest partition on $global:HDD_Disk 
			$BigPart = (Get-Disk -Number $global:HDD_Disk | Get-Partition | Sort-Object -Descending -Property Size)[0]
            $DriveLetterBigPart=Get_DriveLetter -iDisk $BigPart.DiskNumber -iPart $BigPart.PartitionNumber -Force
            if ($null -eq $DriveLetterBigPart) {
                WriteLog -Message "Biggest partition detected [$($BigPart.DiskNumber):$($BigPart.PartitionNumber)] has no drive letter assigned" -MessageType Warning -Component $MyInvocation.MyCommand.Name;  
            } else {
                WriteLog -Message "Biggest partition detected: [$($BigPart.DiskNumber):$($BigPart.PartitionNumber)]=$($DriveLetterBigPart)\" -Component $MyInvocation.MyCommand.Name
            }			
			
			#Diskpart
			$strFile = "$($PathCall)\F11_PrepareDisk.txt"
			$strResult = "$($PathCall)\F11_dpresult.log"
			if	(Test-Path $strFile) { Remove-Item $strFile -Force }
			Add-Content -Path $strFile -Value "SEL DISK $($global:HDD_Disk)"
			Add-Content -Path $strFile -Value "SEL PART $($BigPart.PartitionNumber)"
			Add-Content -Path $strFile -Value "SHRINK desired = $($Size)"
			Add-Content -Path $strFile -Value "CREA PART PRIM NOERR"
			Add-Content -Path $strFile -Value "FORMAT FS=NTFS QUICK LABEL='HP_RECOVERY' NOERR"
			if ($global:GPT -AND $Hide) {
				Add-Content -Path $strFile -Value "SET ID=de94bba4-06d1-4d40-a16a-bfd50179d6ac OVERRIDE"
			}
			Add-Content -Path $strFile -Value "ASS"
			Add-Content -Path $strFile -Value "DETAIL DISK"
			Add-Content -Path $strFile -Value "LIS PART" -NoNewline
			$intDiskpart = Invoke-RunPower -File "Diskpart.exe" -Params "/s $($strFile)" -WorkDir $PSScriptRoot -OutFile $strResult
			if ($intDiskpart -ne 0) {WriteLog -Message "There is an error creating $($HP_RECOVERY) partition on diskpart" -MessageType Error -Component $MyInvocation.MyCommand.Name}
            #refresh disk configurtion
            Update-Disk -Number $global:HDD_Disk -ErrorAction SilentlyContinue
			$NuParts = (Get-Disk -Number $global:HDD_Disk).NumberOfPartitions
			$Newpart = Get_DriveByLabel -Label $HP_RECOVERY
			$NewF11part = Get-Disk  | Get-Partition | Get-Volume | Where-Object {($_.FileSystemLabel.ToUpper() -eq $HP_RECOVERY) -AND ($_.DriveType -eq "Fixed")}
			WriteLog -Message "Now disk #$($global:HDD_Disk) has $($NuParts) partitions"  -Component $MyInvocation.MyCommand.Name
			WriteLog -Message "F11 partition drive created = $($Newpart)"  -Component $MyInvocation.MyCommand.Name
			WriteLog -Message "Partition detected size: [$([math]::round($NewF11part.Size / 1Mb))MB]"  -Component $MyInvocation.MyCommand.Name;
			return "$($Newpart)" #---------------Drive detected by New Partition
		} 
		Catch 
		{
			$ErrorMessage = $_.Exception.Message
			WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
            return $null
		}
		Finally { $ErrorActionPreference = "Continue" }
	
	}

	
}