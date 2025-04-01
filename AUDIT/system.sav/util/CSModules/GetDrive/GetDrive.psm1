#This module require elevate permision to execute
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{   
	#$arguments = "& '" + $myinvocation.mycommand.definition + "'"
	Write-Warning "Elevate Comand line as Administrator, module not loaded $($MyInvocation.MyCommand.Name)" 
	#Start-Process powershell -Verb runAs -ArgumentList $arguments
	Break
}
#requires -Modules "WriteLog","RunPower"
<#
LIST OF FUNCTIONS
	GetDiskInfo
	ValidateDisk
	IsGPT
	DetectPart
	Set-PartLetter
	Get_DriveLetter
	Get_DriveByPath
	Get_DriveByLabel
LIST OF GLOBALE VARIABLES CREATED ON FUNCTIONS MODULE
$global:HDD_Disk
$global:intHDDs
$global:sHDDSize_MB
$global:GPT
$global:Disk_Type
$global:Disk_Path
$global:TotalPart
$global:MSRPart
$global:RECPart
$global:EFIPart
$global:ACTPart
$global:FlagMSR
ValidateDisk will return PSObject with these properties:
	$GlobalDisk.disk
	$GlobalDisk.gpt
	$GlobalDisk.hdds
	$GlobalDisk.type
	$GlobalDisk.path
	$GlobalDisk.totalpart
	$GlobalDisk.msrpart
	$GlobalDisk.recpart
	$GlobalDisk.efipart

#>
<#
.SYNOPSIS
    Functions to retrieve all information from local disks.
.DESCRIPTION
	GetDiskInfo Retrive all informarmation about HDDs, if $global:HDD_Disk exist also will retrive and save the size in MB under variable $global:sHDDSize_MB
.NOTES
	Script version 1.0.4
	Script Date Sep.1.2020
.EXAMPLE
	GetDiskInfo
	
#>
Function GetDiskInfo {
	[CmdletBinding()]
	Param 
	(
    )
	Begin {
		WriteLog -Message "=============================== GetDiskInfo ========================================" -Component $MyInvocation.MyCommand.Name
		$SupStorage=$false
		if (Get-Command Get-Disk -errorAction SilentlyContinue) { $SupStorage=$true}
		
	}
	Process {		
		$ErrorActionPreference = "Stop";
		Try {
			if ($SupStorage){
				WriteLog -Message "******************SCAN HDDs Start*******************************" -Component $MyInvocation.MyCommand.Name
				$Disks = Get-Disk | Sort-Object -Property Number				
				$global:intHDDs = (Get-Disk | Measure-Object).Count
				WriteLog -Message "Detected $($global:intHDDs) Disk(s)..." -Component $MyInvocation.MyCommand.Name
				Foreach ($disk in $Disks) {
					if ($null -ne $global:HDD_Disk -and $disk.Number -eq $global:HDD_Disk) { $global:sHDDSize_MB=[math]::round($disk.Size/1Mb, 0); WriteLog -Message "Disk #$($global:HDD_Disk) has sie of $($global:sHDDSize_MB) MB" -Component $MyInvocation.MyCommand.Name; }
					WriteLog -Message "Details of HDD#[$($disk.Number)]" -Component $MyInvocation.MyCommand.Name
					WriteLog -Message "`t  HDD Layout: [$($disk.PartitionStyle)]" -Component $MyInvocation.MyCommand.Name
					WriteLog -Message "`t    HDD type: [$($disk.ProvisioningType)]" -Component $MyInvocation.MyCommand.Name
					WriteLog -Message "`tHDD Bus Type: [$($disk.BusType)]" -Component $MyInvocation.MyCommand.Name
					WriteLog -Message "`tHDD Location: [$($disk.Location)]" -Component $MyInvocation.MyCommand.Name
					WriteLog -Message "`t    HDD Size: [$([math]::round($disk.Size/1Gb, 0)) GB]" -Component $MyInvocation.MyCommand.Name
					WriteLog -Message "`t  Partitions: [$($disk.NumberOfPartitions)]" -Component $MyInvocation.MyCommand.Name
					$Partitions =  Get-Disk -Number $disk.Number | Get-Partition
					Foreach ($part in $Partitions) {
						WriteLog -Message "`t`t-->Partition: [$($part.PartitionNumber)]" -Component $MyInvocation.MyCommand.Name
						WriteLog -Message "`t`t`t        Label: [$(($part | Get-Volume).FileSystemLabel)]" -Component $MyInvocation.MyCommand.Name
						WriteLog -Message "`t`t`t  File System: [$(($part | Get-Volume).FileSystemType)]" -Component $MyInvocation.MyCommand.Name
						WriteLog -Message "`t`t`t         Type: [$($part.Type)]" -Component $MyInvocation.MyCommand.Name
						WriteLog -Message "`t`t`t     GPT GUID: [$($part.GptType)]" -Component $MyInvocation.MyCommand.Name
						WriteLog -Message "`t`t`tIs GPT Hidden: [$($part.IsHidden)]" -Component $MyInvocation.MyCommand.Name
						WriteLog -Message "`t`t`t    Is Active: [$($part.IsActive)]" -Component $MyInvocation.MyCommand.Name
						WriteLog -Message "`t`t`t       Letter: [$(($part | Get-Volume).DriveLetter)]" -Component $MyInvocation.MyCommand.Name
						WriteLog -Message "`t`t`t         Size: [$([math]::round($part.Size/1Mb, 0)) MB]" -Component $MyInvocation.MyCommand.Name
					}
				}
				WriteLog -Message "******************SCAN HDDs End*********************************" -Component $MyInvocation.MyCommand.Name
			} else {
				WriteLog -Message "******************SCAN HDDs Start*******************************" -Component $MyInvocation.MyCommand.Name
				$DisksQuery = GET-WMIOBJECT -query "SELECT * from Win32_DiskDrive"
				$DisksInfo = GET-WMIOBJECT -query "SELECT * from Win32_DiskDrive" | Measure-Object
				WriteLog -Message "Detected $(DisksInfo.Count) Disk(s)..." -Component $MyInvocation.MyCommand.Name
				$global:intHDDs = $DisksInfo.Count
				Foreach ($disk in $DisksQuery) {
					if ($null -ne $global:HDD_Disk -and $disk.Index -eq $global:HDD_Disk) {$global:sHDDSize_MB = [math]::floor($disk.Size/1024/1024)}
					WriteLog -Message "`tDetails of HDD#[$($disk.Index)]" -Component $MyInvocation.MyCommand.Name
					WriteLog -Message "`t         HDD Model: [$($disk.Model)]" -Component $MyInvocation.MyCommand.Name
					WriteLog -Message "`t    HDD Media Type: [$($disk.MediaType)]" -Component $MyInvocation.MyCommand.Name
					WriteLog -Message "`tHDD Interface Type: [$($disk.InterfaceType)]" -Component $MyInvocation.MyCommand.Name
					WriteLog -Message "`t          HDD Size: [[math]::round($disk.Size/1Gb, 0) GB]" -Component $MyInvocation.MyCommand.Name
					WriteLog -Message "tFormated Partitions: [$($disk.Partitions)]" -Component $MyInvocation.MyCommand.Name
					WriteLog -Message "`t HDD SCSI Bus/Port: [$($disk.SCSIBus):$($disk.SCSIPort)]" -Component $MyInvocation.MyCommand.Name
				}
				WriteLog -Message "******************SCAN HDDs End*********************************" -Component $MyInvocation.MyCommand.Name
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
	This function can retrive the # of HDD which meet all criterial require as parameter
.DESCRIPTION
	ValidateDisk return the Number of Disk which meet all criterial require as parameter
		Require function DetectPart
		Require function IsGPT
	Return $null if nothig meet requirements
	return custom object that contains details about diskk destected $GlobalDisk
.NOTES
	Script version 1.0.5
	Script Date Sep.1.2020
		1.0.1: Update Get_DriveLetter function
		1.0.2: Update when Validate HDD returns global hdd variables, ensure to return $global:GPT
		1.0.4: Order disk in GetDiskInfo
		1.0.5: return object 
.PARAMETER Val_isGPT
	Validation required if need to verify GPT layout
	Boolean vaues
.PARAMETER Val_Partitions
	Validation required if need to verify Number of partitions
	Integer value
.PARAMETER Val_Bus
	Validation required if need to verify BUS where is connected 
	Option String value
.PARAMETER Val_Size_GB
	Validation required if need to verify maximum size of hdd
	Integer value, maximum size of HDD in GB
.PARAMETER Val_Size_Diff
	Validation required if need to verify HDD size is under this rage of difference
	Integer value, Rage of size that HDD can verify as valid. if not provided default value is 20 when Validate for Size
.EXAMPLE
	ValidateDisk -Val_isGPT $true -Val_Partitions 4 -Val_Bus NVMe -Val_Size_GB 512 -Val_Size_Diff 10
#>
Function ValidateDisk {	
	Param 
	(
		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,HelpMessage="Validate HDD by GPT layout",Position=0)]
		[AllowNull()]
		[Alias("vgpt")]
        [Nullable[boolean]]$Val_isGPT,
		
		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,HelpMessage="Validate HDD by Partitions",Position=1)]
		[AllowNull()]
		[Alias("vpart")]
        [int]$Val_Partitions,
		
		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,HelpMessage="Validate HDD by Bus",Position=2)]
		[AllowNull()]
        [AllowEmptyCollection()]
        [BusType[]]$Val_Bus,
		
		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,HelpMessage="Validate HDD by Size in GB",Position=3)]
		[AllowNull()]
		[Alias("vsize")]
        [int]$Val_Size_GB,
		
		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,HelpMessage="Validate HDD by Size in GB",Position=4)]
		[AllowNull()]
		[Alias("vsizedif")]
        [int]$Val_Size_Diff
    )
	Begin {
		$ErrorActionPreference = "Stop";
		WriteLog -Message "=============================== ValidateDisk ========================================" -Component $MyInvocation.MyCommand.Name
		$SupStorage=$false
		if (Get-Command Get-Disk -errorAction SilentlyContinue) { $SupStorage=$true; WriteLog -Message "Storage cmdlet supported" -Component $MyInvocation.MyCommand.Name;}
		if ( $Val_Size_GB -ne $null -AND $null -eq $Val_Size_Diff){ $Val_Size_Diff=20; }
		#if ( $PSBoundParameters.ContainsKey( "Val_Size_GB" ) -ne $false -and $PSBoundParameters.ContainsKey( "Val_Size_Diff" ) -eq $false) {$Val_Size_Diff=20; }
	}
	Process {		
		Try{
			GetDiskInfo				
			WriteLog -Message "Parameter to validate:" -Component $MyInvocation.MyCommand.Name
			if ($Val_isGPT -ne $null -and $Val_isGPT) { $V1="X"} else { $V1=" "}
				WriteLog -Message "`t[$($V1)] Check if disk layout is GPT" -Component $MyInvocation.MyCommand.Name
			if ($Val_Partitions -ne $null -and $Val_Partitions -ne 0) { $V2="`t[X] Check if has $($Val_Partitions) partition(s)" } else {$V2="`t[ ] Check number of partitions"}
				WriteLog -Message $V2 -Component $MyInvocation.MyCommand.Name
			if ($null -ne $Val_Bus) { $V3="`t[X] Check if disk bus is $($Val_Bus.ToUpper())" } else { $V3="`t[ ] Check disk bus"}
				WriteLog -Message $V3 -Component $MyInvocation.MyCommand.Name
			if ($Val_Size_GB -ne $null -and $Val_Size_GB -ne 0) { $V4="`t[X] Check if disk size is $($Val_Size_GB) GB" } else { $V4="`t[ ] Check disk size"}
				WriteLog -Message $V4 -Component $MyInvocation.MyCommand.Name
		#Try with Get-Disk cmdlet
			if ($SupStorage) {				
				$ScannedHDD = $null
				if ($Val_isGPT) {
					if (($Val_Partitions -eq $null -or $Val_Partitions -eq 0) -AND ($null -eq $Val_Bus) -AND ($Val_Size_GB -eq $null -or $Val_Size_GB -eq 0)) {$SearchDisk = Get-Disk | Where-Object {$_.PartitionStyle -eq "GPT"}} else {
						if (($Val_Partitions -eq $null -or $Val_Partitions -eq 0) -AND ($Val_Size_GB -eq $null -or $Val_Size_GB -eq 0)) { $SearchDisk = Get-Disk | Where-Object {($_.PartitionStyle -eq "GPT") -AND ($_.BusType.ToUpper() -eq $Val_Bus.ToUpper())} } else {
							if (($null -eq $Val_Bus) -AND ($Val_Size_GB -eq $null -or $Val_Size_GB -eq 0)) {$SearchDisk = Get-Disk | Where-Object {($_.PartitionStyle -eq "GPT") -AND ($_.NumberOfPartitions -eq $Val_Partitions)}} else {
								if (($Val_Partitions -eq $null -or $Val_Partitions -eq 0) -AND ($null -eq $Val_Bus)) {$SearchDisk = Get-Disk | Where-Object {($_.PartitionStyle -eq "GPT") -AND ([math]::round($_.Size/1Gb, 0) -le $Val_Size_GB) -AND ([math]::round($_.Size/1Gb, 0) -ge $Val_Size_GB - $Val_Size_Diff )}} else {
									if ($Val_Partitions -eq $null -or $Val_Partitions -eq 0) {$SearchDisk = Get-Disk | Where-Object {($_.PartitionStyle -eq "GPT") -AND ([math]::round($_.Size/1Gb, 0) -le $Val_Size_GB) -AND ([math]::round($_.Size/1Gb, 0) -ge $Val_Size_GB - $Val_Size_Diff ) -AND ($_.BusType.ToUpper() -eq $Val_Bus.ToUpper())}} else {
										if ($null -eq $Val_Bus) {$SearchDisk = Get-Disk | Where-Object {($_.PartitionStyle -eq "GPT") -AND ([math]::round($_.Size/1Gb, 0) -le $Val_Size_GB) -AND ([math]::round($_.Size/1Gb, 0) -ge $Val_Size_GB - $Val_Size_Diff ) -AND ($_.NumberOfPartitions -eq $Val_Partitions)}} else {
											$SearchDisk = Get-Disk | Where-Object {($_.PartitionStyle -eq "GPT") -AND ([math]::round($_.Size/1Gb, 0) -le $Val_Size_GB) -AND ([math]::round($_.Size/1Gb, 0) -ge $Val_Size_GB - $Val_Size_Diff ) -AND ($_.NumberOfPartitions -eq $Val_Partitions) -AND ($_.BusType.ToUpper() -eq $Val_Bus.ToUpper())}
										}
									}
								}
							}		
						}
					}
				} else {
					if ($Val_Partitions -ne $null -and $Val_Partitions -ne 0) {
						if (($null -eq $Val_Bus) -AND ($Val_Size_GB -eq $null -or $Val_Size_GB -eq 0)) {$SearchDisk = Get-Disk | Where-Object {$_.NumberOfPartitions -eq $Val_Partitions}} else {
							if ($Val_Size_GB -eq $null -or $Val_Size_GB -eq 0) {$SearchDisk = Get-Disk | Where-Object {($_.NumberOfPartitions -eq $Val_Partitions) -AND ($_.BusType.ToUpper() -eq $Val_Bus.ToUpper())}} else {
								if ($null -eq $Val_Bus) {$SearchDisk = Get-Disk | Where-Object {($_.NumberOfPartitions -eq $Val_Partitions) -AND ([math]::round($_.Size/1Gb, 0) -le $Val_Size_GB) -AND ([math]::round($_.Size/1Gb, 0) -ge $Val_Size_GB - $Val_Size_Diff )}} else {
									$SearchDisk = Get-Disk | Where-Object {($_.NumberOfPartitions -eq $Val_Partitions) -AND ($_.BusType.ToUpper() -eq $Val_Bus.ToUpper()) -AND ([math]::round($_.Size/1Gb, 0) -le $Val_Size_GB) -AND ([math]::round($_.Size/1Gb, 0) -ge $Val_Size_GB - $Val_Size_Diff )}
								}
							}
						}
					} else {
						if ($null -ne $Val_Bus) {
							if ($Val_Size_GB -eq $null -or $Val_Size_GB -eq 0) {$SearchDisk = Get-Disk | Where-Object-Object {$_.BusType.ToUpper() -eq $Val_Bus.ToUpper()}} else {
								$SearchDisk = Get-Disk | Where-Object {($_.BusType.ToUpper() -eq $Val_Bus.ToUpper()) -AND ([math]::round($_.Size/1Gb, 0) -le $Val_Size_GB) -AND ([math]::round($_.Size/1Gb, 0) -ge $Val_Size_GB - $Val_Size_Diff )}
							}
						} else {
							if ($Val_Size_GB -ne $null -and $Val_Size_GB -ne 0) {$SearchDisk = Get-Disk | Where-Object {([math]::round($_.Size/1Gb, 0) -le $Val_Size_GB) -AND ([math]::round($_.Size/1Gb, 0) -ge $Val_Size_GB - $Val_Size_Diff )}} else {
								WriteLog -Message "No validation of HDD required" -MessageType Warning -Component $MyInvocation.MyCommand.Name
								WriteLog -Message "******************ValidateDisk End*********************************" -Component $MyInvocation.MyCommand.Name
								$global:HDD_Disk=$null;
								return $null; 
							}
						}
					}
				}
					
				if (($SearchDisk | Measure-Object).Count -le 0) {
					WriteLog -Message "Not possible detect the correct HDD, logic detection" -MessageType Error -Component $MyInvocation.MyCommand.Name
					WriteLog -Message "******************ValidateDisk End*********************************" -Component $MyInvocation.MyCommand.Name
					$global:HDD_Disk=$null;
					return $null 
				}
				if (($SearchDisk | Measure-Object).Count -gt 1) {
					WriteLog -Message "It was detectd $(($SearchDisk | Measure-Object).Count) disks than complies with all parameters, determinate which is correct..." -Component $MyInvocation.MyCommand.Name
					ForEach ($d in $SearchDisk) { 
						if ($null -ne $global:HDD_Disk -and $d.DiskNumber -eq $global:HDD_Disk) { 
							WriteLog -Message "Default disk $($global:HDD_Disk) is valid by parameter" -Component $MyInvocation.MyCommand.Name
							WriteLog -Message "******************ValidateDisk End***********************************" -Component $MyInvocation.MyCommand.Name
							$global:HDD_Disk=$d;
							$global:GPT = IsGPT -iDisk $global:HDD_Disk 
							WriteLog -Message "Disk #$($global:HDD_Disk) isGPT=$($global:GPT)" -Component $MyInvocation.MyCommand.Name
						
							
							$GlobalDisk = New-Object PSObject
							$GlobalDisk | Add-Member -MemberType NoteProperty -Name 'disk' -Value $d
							$GlobalDisk | Add-Member -MemberType NoteProperty -Name 'gpt' -Value $global:GPT
							$GlobalDisk | Add-Member -MemberType NoteProperty -Name 'hdds' -Value $global:intHDDs
							$GlobalDisk | Add-Member -MemberType NoteProperty -Name 'type' -Value $global:Disk_Type
							$GlobalDisk | Add-Member -MemberType NoteProperty -Name 'path' -Value $global:Disk_Path
							$GlobalDisk | Add-Member -MemberType NoteProperty -Name 'totalpart' -Value $global:TotalPart
							$GlobalDisk | Add-Member -MemberType NoteProperty -Name 'msrpart' -Value $global:MSRPart
							$GlobalDisk | Add-Member -MemberType NoteProperty -Name 'recpart' -Value $global:RECPart
							$GlobalDisk | Add-Member -MemberType NoteProperty -Name 'efipart' -Value $global:EFIPart
							return $GlobalDisk; 
						}
					}
					WriteLog -Message "Any disk is valid, returning first on list: [$(($SearchDisk |Sort-Object -Property DiskNumber)[0].DiskNumber)]" -Component $MyInvocation.MyCommand.Name
					$ScannedHDD = ($SearchDisk |Sort-Object -Property DiskNumber)[0].DiskNumber
				} else {
					WriteLog -Message "Disk [$($SearchDisk.DiskNumber)] meet all requirements" -Component $MyInvocation.MyCommand.Name
					$ScannedHDD = $SearchDisk.DiskNumber
				}
				WriteLog -Message "******************ValidateDisk End***********************************" -Component $MyInvocation.MyCommand.Name
				$global:HDD_Disk=$ScannedHDD
				$global:GPT = IsGPT -iDisk $global:HDD_Disk 
				
				$GlobalDisk = New-Object PSObject
				$GlobalDisk | Add-Member -MemberType NoteProperty -Name 'disk' -Value $ScannedHDD
				$GlobalDisk | Add-Member -MemberType NoteProperty -Name 'gpt' -Value $global:GPT
				$GlobalDisk | Add-Member -MemberType NoteProperty -Name 'hdds' -Value $global:intHDDs
				$GlobalDisk | Add-Member -MemberType NoteProperty -Name 'type' -Value $global:Disk_Type
				$GlobalDisk | Add-Member -MemberType NoteProperty -Name 'path' -Value $global:Disk_Path
				$GlobalDisk | Add-Member -MemberType NoteProperty -Name 'totalpart' -Value $global:TotalPart
				$GlobalDisk | Add-Member -MemberType NoteProperty -Name 'msrpart' -Value $global:MSRPart
				$GlobalDisk | Add-Member -MemberType NoteProperty -Name 'recpart' -Value $global:RECPart
				$GlobalDisk | Add-Member -MemberType NoteProperty -Name 'efipart' -Value $global:EFIPart
				return $GlobalDisk;
				
			} else { #if no commnad Get-Disk exist, it will try to do as WMI
			
				$DisksQuery = GET-WMIOBJECT -query "SELECT * from Win32_DiskDrive"
				Foreach ($disk in $DisksQuery) {
					$global:HDD_Disk = $disk.Index
					if ($Val_isGPT) {
						if (($Val_Partitions -eq $null -or $Val_Partitions -eq 0) -AND ($null -eq $Val_Bus) -AND ($Val_Size_GB -eq $null -or $Val_Size_GB -eq 0)) {	if (IsGPT -iDisk $disk.Index) {$SearchDisk=$disk.Index;}; } else {
							if (($Val_Partitions -eq $null -or $Val_Partitions -eq 0) -AND ($Val_Size_GB -eq $null -or $Val_Size_GB -eq 0)) { if ((IsGPT -iDisk $disk.Index) -AND ($disk.InterfaceType.ToUpper() -eq $Val_Bus.ToUpper())) {$SearchDisk=$disk.Index;}; } else {
								if (($null -eq $Val_Bus) -AND ($Val_Size_GB -eq $null -or $Val_Size_GB -eq 0)) {if ((IsGPT -iDisk $disk.Index) -AND ($global:TotalPart -eq $Val_Partitions)) {$SearchDisk=$disk.Index;};} else {
									if (($Val_Partitions -eq $null -or $Val_Partitions -eq 0) -AND ($null -eq $Val_Bus)) {if ((IsGPT -iDisk $disk.Index) -AND ([math]::round($disk.Size/1Gb, 0) -le $Val_Size_GB) -AND ([math]::round($disk.Size/1Gb, 0) -ge $Val_Size_GB - $Val_Size_Diff )) {$SearchDisk=$disk.Index;};} else {
										if ($Val_Partitions -eq $null -or $Val_Partitions -eq 0) {if ((IsGPT -iDisk $disk.Index) -AND ([math]::round($disk.Size/1Gb, 0) -le $Val_Size_GB) -AND ([math]::round($disk.Size/1Gb, 0) -ge $Val_Size_GB - $Val_Size_Diff ) -AND ($disk.InterfaceType.ToUpper() -eq $Val_Bus.ToUpper())) {$SearchDisk=$disk.Index;};} else {
											if ($null -eq $Val_Bus) {if ((IsGPT -iDisk $disk.Index) -AND ([math]::round($disk.Size/1Gb, 0) -le $Val_Size_GB) -AND ([math]::round($disk.Size/1Gb, 0) -ge $Val_Size_GB - $Val_Size_Diff ) -AND ($global:TotalPart -eq $Val_Partitions)) {$SearchDisk=$disk.Index;};} else {
												if ((IsGPT -iDisk $disk.Index) -AND ([math]::round($disk.Size/1Gb, 0) -le $Val_Size_GB) -AND ([math]::round($disk.Size/1Gb, 0) -ge $Val_Size_GB - $Val_Size_Diff ) -AND ($global:TotalPart -eq $Val_Partitions) -AND ($disk.InterfaceType.ToUpper() -eq $Val_Bus.ToUpper())) {$SearchDisk=$disk.Index;};
											}
										}
									}
								}
							}
						}
					} else {
						if ($Val_Partitions -ne $null -and $Val_Partitions -ne 0) {
							if (($null -eq $Val_Bus) -AND ($Val_Size_GB -eq $null -or $Val_Size_GB -eq 0)) {if (($global:TotalPart -eq $Val_Partitions)) {$SearchDisk=$disk.Index;};} else {
								if ($Val_Size_GB -eq $null -or $Val_Size_GB -eq 0) {if (($global:TotalPart -eq $Val_Partitions) -AND ($disk.InterfaceType.ToUpper() -eq $Val_Bus.ToUpper())) {$SearchDisk=$disk.Index;};} else {
									if ($null -eq $Val_Bus) {if (($global:TotalPart -eq $Val_Partitions) -AND ([math]::round($disk.Size/1Gb, 0) -le $Val_Size_GB) -AND ([math]::round($disk.Size/1Gb, 0) -ge $Val_Size_GB - $Val_Size_Diff )) {$SearchDisk=$disk.Index;};} else {
										if (($global:TotalPart -eq $Val_Partitions) -AND ($disk.InterfaceType.ToUpper() -eq $Val_Bus.ToUpper()) -AND ([math]::round($disk.Size/1Gb, 0) -le $Val_Size_GB) -AND ([math]::round($disk.Size/1Gb, 0) -ge $Val_Size_GB - $Val_Size_Diff )) {$SearchDisk=$disk.Index;};
									}
								}
							}
						} else {
							if ($null -ne $Val_Bus) {
								if ($Val_Size_GB -eq $null -or $Val_Size_GB -eq 0) {if ($disk.InterfaceType.ToUpper() -eq $Val_Bus.ToUpper()) {$SearchDisk=$disk.Index;};} else {
									if (($disk.InterfaceType.ToUpper() -eq $Val_Bus.ToUpper()) -AND ([math]::round($disk.Size/1Gb, 0) -le $Val_Size_GB) -AND ([math]::round($disk.Size/1Gb, 0) -ge $Val_Size_GB - $Val_Size_Diff )) {$SearchDisk=$disk.Index;};
								}
							} else {
								if ($Val_Size_GB -ne $null -and $Val_Size_GB -ne 0) {if (([math]::round($disk.Size/1Gb, 0) -le $Val_Size_GB) -AND ([math]::round($disk.Size/1Gb, 0) -ge $Val_Size_GB - $Val_Size_Diff )) {$SearchDisk=$disk.Index;};} else {
									WriteLog -Message "No validation of HDD required" -MessageType Warning -Component $MyInvocation.MyCommand.Name
									WriteLog -Message "******************ValidateDisk End*********************************" -Component $MyInvocation.MyCommand.Name
									$global:HDD_Disk=$null;
									return $null; 
								}
							}
						}
					}
				}
				
				if ($null -ne $SearchDisk) {
					WriteLog -Message "Disk [$($SearchDisk)] meet all requirements" -Component $MyInvocation.MyCommand.Name
					$global:HDD_Disk=$SearchDisk
					$global:GPT = IsGPT -iDisk $global:HDD_Disk
					WriteLog -Message "******************ValidateDisk End*********************************" -Component $MyInvocation.MyCommand.Name
					$GlobalDisk = New-Object PSObject
					$GlobalDisk | Add-Member -MemberType NoteProperty -Name 'disk' -Value $SearchDisk
					$GlobalDisk | Add-Member -MemberType NoteProperty -Name 'gpt' -Value $global:GPT
					$GlobalDisk | Add-Member -MemberType NoteProperty -Name 'hdds' -Value $global:intHDDs
					$GlobalDisk | Add-Member -MemberType NoteProperty -Name 'type' -Value $global:Disk_Type
					$GlobalDisk | Add-Member -MemberType NoteProperty -Name 'path' -Value $global:Disk_Path
					$GlobalDisk | Add-Member -MemberType NoteProperty -Name 'totalpart' -Value $global:TotalPart
					$GlobalDisk | Add-Member -MemberType NoteProperty -Name 'msrpart' -Value $global:MSRPart
					$GlobalDisk | Add-Member -MemberType NoteProperty -Name 'recpart' -Value $global:RECPart
					$GlobalDisk | Add-Member -MemberType NoteProperty -Name 'efipart' -Value $global:EFIPart
					return $GlobalDisk;
				} else {
					WriteLog -Message "Not possible detect the correct HDD, logic detection" -MessageType Error -Component $MyInvocation.MyCommand.Name
					WriteLog -Message "******************ValidateDisk End*********************************" -Component $MyInvocation.MyCommand.Name
					$global:HDD_Disk = $null
					$global:GPT = $null
					return $null
				}
			}		
		
		} 
		Catch 
		{
			$ErrorMessage = $_.Exception.Message
			WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
			if (!($ContinueOnError)){ Exit 901}
		}
		Finally { $ErrorActionPreference = "Continue" }	
	}	
}



<#
.SYNOPSIS
    Functions to retrieve properties of partitions of scpecific disk
.DESCRIPTION
	DetectPart is a functions based on diskpart that detect partitions on $global:HDD_Disk, it will save these global ariables: 
		$global:Disk_Type, $global:Disk_Path, $global:TotalPart, $global:MSRPart, $global:RECPart, $global:EFIPart, $global:ACTPart, $global:FlagMSR
	Big use of this function is detect MSR partition
.NOTES
	Script version 1.0.4
	Script Date Sep.1.2020
.EXAMPLE

	DetectPart
#>
function DetectPart {
	[CmdletBinding()]
	Param
    (
		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,HelpMessage="Disk number",Position=0)]
		[Alias("disk")]
        [int]$iDisk
    )
	Begin {
		#--> Variables
		$strFile = "$($PSScriptRoot)\HPScan.txt"
		$strResult = "$($PSScriptRoot)\HPResultScan.txt"
		$msr = "e3c9e316-0b5c-4db8-817d-f92df00215ae"
		$reco = "de94bba4-06d1-4d40-a16a-bfd50179d6ac"
		$basic = "ebd0a0a2-b9e5-4433-87c0-68b6b72699c7"
		$efi = "c12a7328-f81f-11d2-ba4b-00a0c93ec93b"
		if ($null -eq $global:HDD_Disk) { $global:HDD_Disk=0 }
		WriteLog -Message "=============================== Get Partitions Type ========================================" -Component $MyInvocation.MyCommand.Name
		if ( $PSBoundParameters.ContainsKey( "iDisk" ) -eq $false ) # Parameter not specified
        {
			if ( $null -ne $global:HDD_Disk )
            {
                $iDisk = $global:HDD_Disk
            }
            else # Use default value
            {
                WriteLog -Message "Not possible get detail about partitions since $iDisk or $global:HDD_Disk was not provided" -MessageType Error -Component $MyInvocation.MyCommand.Name
				return $null
            }			
        } else {
			$global:HDD_Disk=$iDisk
		}
		#Reset variables
		$global:MSRPart=$null
		$global:RECPart=$null
		$global:EFIPart=$null
		$global:ACTPart=$null
		$global:TotalPart=$null
		$global:Disk_Type=$null
		$global:Disk_Path=$null
	}
	Process {
		WriteLog -Message "Detecting GPT Partitions..." -Component $MyInvocation.MyCommand.Name
		$ErrorActionPreference = "Stop"
		Try
		{
			#-->Create Diskpart file for DETAIL DISK
			if	(Test-Path $strFile) { 
				Remove-Item $strFile -Force
				New-Item $strFile -ItemType file | out-null
			}
			Add-Content -Path $strFile -Value "RESCAN"
			Add-Content -Path $strFile -Value "SEL DISK $($global:HDD_Disk)"
			Add-Content -Path $strFile -Value "DETAIL DISK" -NoNewline
			#--->Run Diskpart
			Diskpart /s $strFile | Out-File -FilePath $strResult
			#---Read Results
			$Diskpart = Get-Content $strResult 
			if ($Diskpart.Count -gt 0){
				Foreach ($line in $Diskpart){
					if ($line.Trim().StartsWith("type","CurrentCultureIgnoreCase")){
						$global:Disk_Type = $line.Trim().ToLower().Split(":")[1]
						WriteLog -Message "Diskk #$($global:HDD_Disk) detected as type $($global:Disk_Type)" -Component $MyInvocation.MyCommand.Name
					}
					if ($line.Trim().StartsWith("location path","CurrentCultureIgnoreCase")){
						$global:Disk_Path = $line.Trim().ToLower().Split(":")[1]
						WriteLog -Message "Diskk #$($global:HDD_Disk) detected as path $($global:Disk_Path)" -Component $MyInvocation.MyCommand.Name
					}
				}
			}
			#-->Create Diskpart file LIST PART
			if	(Test-Path $strFile) { 
				Remove-Item $strFile -Force
				New-Item $strFile -ItemType file | out-null
			}
			Add-Content -Path $strFile -Value "RESCAN"
			Add-Content -Path $strFile -Value "SEL DISK $($global:HDD_Disk)"
			Add-Content -Path $strFile -Value "LIS PART" -NoNewline
			#--->Run Diskpart
			Diskpart /s $strFile | Out-File -FilePath $strResult
			#---Read Results
			$Diskpart = Get-Content $strResult 
			if ($Diskpart.Count -gt 0){
				Foreach ($line in $Diskpart){
					if ($line.Trim().ToLower().Contains("partition")){
						if ($line.Trim().ToLower() -ne "there are no partitions on this disk to show.") {
							$Partitions = $line.Trim().ToLower().Split(" ")[1]
						}
					}
				}
			}
			#-->Create Diskpart file for Detailed Partitions
			if	(Test-Path $strFile) { 
				Remove-Item $strFile -Force
				New-Item $strFile -ItemType file | out-null
			}
			Add-Content -Path $strFile -Value "RESCAN"
			Add-Content -Path $strFile -Value "SEL DISK $($global:HDD_Disk)"
			if ($null -ne $Partitions){
				$global:TotalPart = [int]$Partitions
				WriteLog -Message "`tFound $($global:TotalPart) partitions" -Component $MyInvocation.MyCommand.Name
				for($p=1; $p -le [int]$partitions; $p++){
					Add-Content -Path $strFile -Value "SEL PART $($p)"
					Add-Content -Path $strFile -Value "DET PART"
				}	
			}
			#--->Run Diskpart
			Diskpart /s $strFile | Out-File -FilePath $strResult
			#---Read Results
			$Diskpart = Get-Content $strResult 
			if ($Diskpart.Count -gt 0){
				Foreach ($line in $Diskpart){
					if ($line.Trim().ToLower().Contains("partition")){
						$CurrentPart = $line.Trim().ToLower().Split(" ")[1]
					}
					if ($null -ne $global:GPT -and $global:GPT) {
						if ($line.StartsWith("type","CurrentCultureIgnoreCase")){
							$Type = $line.Trim().ToLower().Split(":")[1]
							switch ($Type.Trim().ToLower())
							{							
								$msr {  $global:MSRPart = [int]$CurrentPart; WriteLog -Message "`tPartition $($global:MSRPart) is MSR" -Component $MyInvocation.MyCommand.Name; break}
								$reco { $global:RECPart = [int]$CurrentPart; WriteLog -Message "`tPartition $($global:RECPart) is RECOVERY" -Component $MyInvocation.MyCommand.Name; break}
								$basic { WriteLog -Message "`tPartition $($CurrentPart) is BASIC" -Component $MyInvocation.MyCommand.Name; break}
								$efi {  $global:EFIPart = [int]$CurrentPart; WriteLog -Message "`tPartition $($global:EFIPart) is EFI" -Component $MyInvocation.MyCommand.Name; break}
								default { WriteLog -Message "`tPartition $($CurrentPart) is Unknown" -Component $MyInvocation.MyCommand.Name; break}
							}
						}
					} else {
						if ($line.StartsWith("active","CurrentCultureIgnoreCase")){
							$Active = $line.Trim().ToLower().Split(":")[1]
							switch ($Active.Trim().ToLower())
							{
								"yes" { $global:ACTPart = [int]$CurrentPart; WriteLog -Message "`tPartition $($global:ACTPart) is Active" -Component $MyInvocation.MyCommand.Name; break}
								default { WriteLog -Message "`tPartition $($CurrentPart) is Not active" -Component $MyInvocation.MyCommand.Name; break}
							}
						}
					}
				}
			}
			#---->Clean Temporary Files
			if	(Test-Path $strFile) { Remove-Item $strFile -Force }
			if	(Test-Path $strResult) { Remove-Item $strResult -Force }
			#----->Save flag
			$global:FlagMSR = $true
			$global:FlagMSR | out-null
			if ($null -eq $global:MSRPart) { $global:MSRPart=0 }
		}
		Catch 
		{			
			$ErrorMessage = $_.Exception.Message
			WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
			if (!($ContinueOnError)){ Exit 901}
		}
		Finally { $ErrorActionPreference = "Continue" }
	}
}


<#
.SYNOPSIS
    Functions to validate if selected disk is GPT
.DESCRIPTION
	IsGPT search if disk# is GPT or not, paramete can define over what disk
	in case that $global:HDD_Disk exist it can search that disk, otherwise will use default 0, if iDisk is the same as $global:HDD_Disk then also set $global:GPT 
		Require function DetectPart
.NOTES
	Script version 1.0.4
	Script Date Sep.1.2020
.PARAMETER iDisk
    integer that represent the HDD# 
.EXAMPLE

	IsGPT -iDisk 2
	IsGPT 	
#>
function IsGPT {
	[OutputType([bool])]
	Param
    (
		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,HelpMessage="Disk number",Position=0)]
		[Alias("disk")]
        [int]$iDisk
    )
	Begin {
		if ( $PSBoundParameters.ContainsKey( "iDisk" ) -eq $false ) # Parameter not specified
        {
			if ( $null -ne $global:HDD_Disk )
            {
                $iDisk = $global:HDD_Disk
            }
            else # Use default value
            {
                $iDisk = 0
            }			
        }
		WriteLog -Message "=============================== IsGPT Detection ========================================" -Component $MyInvocation.MyCommand.Name
		
	}
	Process {
		$GPTDetected = $false
		WriteLog -Message "Checking if Disk $($iDisk) has GPT Layout..." -Component $MyInvocation.MyCommand.Name
		$ErrorActionPreference = "Stop"
		Try
		{
			$GPTquery = Get-WmiObject -query "Select * from Win32_DiskPartition WHERE Index = 0" | Select-Object DiskIndex, @{Name="GPT";Expression={$_.Type.StartsWith("GPT")}}
			Foreach ($eachdisk in $GPTquery) {
				if ($eachdisk.GPT -and $eachdisk.DiskIndex -eq $iDisk) {
					WriteLog -Message "`tFound GPT Layout in Disk $($eachdisk.DiskIndex)" -Component $MyInvocation.MyCommand.Name
					$GPTDetected = $true
				}
			}
			WriteLog -Message "Review Partition scheme..." -Component $MyInvocation.MyCommand.Name
			#if ($iDisk -eq $global:HDD_Disk) {$global:GPT = $GPTDetected;}
			$global:GPT = $GPTDetected;
			$global:GPT | out-null
			DetectPart -iDisk $iDisk
			return $GPTDetected
		}
		Catch 
		{
			$ErrorMessage = $_.Exception.Message
			WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
		}
		Finally { $ErrorActionPreference = "Continue" }
	}
}




Function Set-PartLetter {
	[OutputType([string])]
	Param 
	(
		[Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,HelpMessage="Provide disk number",Position=0)]
		[ValidateNotNullOrEmpty()]
		[Alias("disk")]
        [int]$iDisk,
		
		[Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,HelpMessage="Provide partition number",Position=1)]
		[ValidateNotNullOrEmpty()]
		[Alias("partition")]
        [int]$iPart
    )
	Begin {
		$ErrorActionPreference = "Stop"
		#Initialize WriteLog 
		WriteLog -Message "============================== $($MyInvocation.MyCommand.Name) START ==============================" -Component $MyInvocation.MyCommand.Name
	}
	Process {				
		Try 
		{
			WriteLog -Message "Forcing drive letter for Disk#$($iDisk) and Partition#$($iPart)" -Component $MyInvocation.MyCommand.Name
			$strdp="$($PSScriptRoot)\dptemp.txt"
			$strresult="$($PSScriptRoot)\dpresulta.log"
			WriteLog -Message "---> First stage get volume information from partition" -Component $MyInvocation.MyCommand.Name
			if (Test-Path $strdp) { Remove-Item -Path $strdp -Force }
			Add-Content -Path $strdp -Value "SEL DISK $($iDisk)"
			Add-Content -Path $strdp -Value "SEL PART $($iPart)"
			Add-Content -Path $strdp -Value "DET PART"
			Add-Content -Path $strdp -Value "EXIT"
			$runDiskpart=Invoke-RunPower -File "cmd.exe" -Params "/c Diskpart /s $($strdp)" -WorkDir $PSScriptRoot -OutFile $strresult 
			if ($runDiskpart -eq 0) {
				WriteLog -Message "Diskpart complete execution successfully, read results" -Component $MyInvocation.MyCommand.Name
				$Diskpart = Get-Content $strresult | Select-String -Pattern "Volume" | Where-Object { $_ -notlike "*#*"}
				if ($null -ne $Diskpart) {
					foreach ($line in $Diskpart) {
						WriteLog -Message "<DP LINE>: $($line.ToString().Trim())" -Component $MyInvocation.$MyInvocation.Name
						if ($line.ToString().Trim().ToLower() -ne "there is no volume associated with this partition.") {
							$Volume=$line.ToString().Replace("*","").Trim().Replace("    "," ").Replace("   "," ").Replace("  "," ").Split(" ")[1]
							WriteLog -Message "Volume detected #$($Volume)" -Component $MyInvocation.MyCommand.Name
							WriteLog -Message "---> Second stage Assign drive letter to volume detected" -Component $MyInvocation.MyCommand.Name
							if (Test-Path $strdp) { Remove-Item -Path $strdp -Force }
							Add-Content -Path $strdp -Value "SEL VOL $($Volume)"
							Add-Content -Path $strdp -Value "REMOVE NOERR"
							Add-Content -Path $strdp -Value "ASS"
							Add-Content -Path $strdp -Value "DET PART"
							Add-Content -Path $strdp -Value "EXIT"
							$runDiskpart=Invoke-RunPower -File "cmd.exe" -Params "/c Diskpart /s $($strdp)" -WorkDir $PSScriptRoot -OutFile $strResult 
							if ($runDiskpart -eq 0) {
								WriteLog -Message "Diskpart complete successfully, new letter assigned read results" -Component $MyInvocation.MyCommand.Name
								$DiskVol = Get-Content $strresult | Select-String -Pattern "Volume" | Where-Object { $_ -notlike "*#*"}
								if ($null -ne $DiskVol) {
									foreach ($line in $Diskpart) {
										WriteLog -Message "<DP LINE>: $($line.ToString().Trim())" -Component $MyInvocation.$MyInvocation.Name
										if ($line.ToString().Trim().ToLower() -ne "there is no volume associated with this partition.") {
											$VolumeDrive=$line.ToString().Trim().Replace("*","").Replace("    "," ").Replace("   "," ").Replace("  "," ").Split(" ")[2]
											WriteLog -Message "Drive letter detected on disckpart for [$($iDisk):$($iPart)]=$($VolumeDrive)" -Component $MyInvocation.MyCommand.Name
											$GetDrive=Get_DriveLetter -iDisk $iDisk -iPart $iPart
											if ($null -ne $GetDrive) {WriteLog -Message "Now Drive has letter assigned [$($iDisk):$($iPart)]=$($GetDrive)" -Component $MyInvocation.MyCommand.Name }
											if (Test-Path $strdp) { Remove-Item -Path $strdp -Force }
											if (Test-Path $strresult) { Remove-Item -Path $strresult -Force }
											return $GetDrive
										}
									}
									if (Test-Path $strdp) { Remove-Item -Path $strdp -Force }
									if (Test-Path $strresult) { Remove-Item -Path $strresult -Force }
									return $null
								} else {
									WriteLog -Message "Diskpart run successfully but not generate results" -MessageType Error -Component $MyInvocation.MyCommand.Name
									if (Test-Path $strdp) { Remove-Item -Path $strdp -Force }
									if (Test-Path $strresult) { Remove-Item -Path $strresult -Force }
									return $null
								}
							} else {
								WriteLog -Message "Diskpart return error trying to assign letter" -MessageType Error -Component $MyInvocation.MyCommand.Name
								if (Test-Path $strdp) { Remove-Item -Path $strdp -Force }
								if (Test-Path $strresult) { Remove-Item -Path $strresult -Force }
								return $null
							}
						}
					}
					if (Test-Path $strdp) { Remove-Item -Path $strdp -Force }
					if (Test-Path $strresult) { Remove-Item -Path $strresult -Force }
					return $null
				} else {
					WriteLog -Message "Not possible detect diskpart information" -MessageType Error -Component $MyInvocation.MyCommand.Name
					if (Test-Path $strdp) { Remove-Item -Path $strdp -Force }
					if (Test-Path $strresult) { Remove-Item -Path $strresult -Force }
					return $null
				}
			} else {
				WriteLog -Message "An error occurs during Diskpart execution" -MessageType Error -Component $MyInvocation.MyCommand.Name
				if (Test-Path $strdp) { Remove-Item -Path $strdp -Force }
				if (Test-Path $strresult) { Remove-Item -Path $strresult -Force }
				return $null
			}
						
		} 
		Catch 
		{
			$ErrorMessage = $_.Exception.Message
			WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
			if (Test-Path $strdp) { Remove-Item -Path $strdp -Force }
			if (Test-Path $strresult) { Remove-Item -Path $strresult -Force }
			return $null
		}
		Finally { $ErrorActionPreference = "Continue" }
	
	}
	end {
        WriteLog -Message "============================================================================" -Component $MyInvocation.MyCommand.Name
    }

	
}


<#
.SYNOPSIS
    Functions to retrieve driver letter from Disk:Partition
.DESCRIPTION
	Get_DriveLetter retrieve letter drive based on disk# and Partition#
		Require IsGPT
.NOTES
	Script version 1.0.4
	Script Date Sep.1.2020
.PARAMETER iDisk
    integer that represent the HDD# 
.PARAMETER iPart
   integert that represent the Partition#
.EXAMPLE
	Get_DriveLetter -iDisk 0 -iPart 1
	
#>
Function Get_DriveLetter {
	[OutputType([string])]
	Param 
	(
		[Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,HelpMessage="Provide disk number",Position=0)]
		[ValidateNotNullOrEmpty()]
		[Alias("disk")]
        [int]$iDisk,
		
		[Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,HelpMessage="Provide partition number",Position=1)]
		[ValidateNotNullOrEmpty()]
		[Alias("partition")]
        [int]$iPart,

		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,HelpMessage="Force Drive letter will set drive letter",Position=2)]
		[AllowNull()]
        [Alias("forcing")]
		[Switch]$Force
    )
	Begin {
		WriteLog -Message "=============================== Get_DriverLetter START ========================================" -Component $MyInvocation.MyCommand.Name
		
	}
	Process {
		WriteLog -Message "Retrive letter for [$($iDisk):$($iPart)]..." -Component $MyInvocation.MyCommand.Name
		$ErrorActionPreference = "Stop";
		Try {
			if (($null -eq $global:HDD_Disk) -OR ($global:HDD_Disk -ne $iDisk)) {DetectPart -iDisk $iDisk; $null = IsGPT -iDisk $iDisk} #search new disk
			if ($null -eq $global:GPT) { $null = IsGPT -iDisk $iDisk } #Check if is GPT 
			if ($null -eq $global:MSRPart) { DetectPart -iDisk $iDisk } #Check MSR partition 
			if ($null -eq $global:GPT) { WriteLog -Message "Not possible detect layout scheme, abort function" -MessageType Error -Component $MyInvocation.MyCommand.Name; return $null;}
			if ($global:GPT -AND ($null -ne $global:MSRPart)){
				if ($iPart -lt $global:MSRPart) {$iPartition = $iPart -1}
				if ($iPart -eq $global:MSRPart) {WriteLog -Message "`t[GPT]Partition $($iPart) is the MSR, no formated partition" -MessageType Warning -Component $MyInvocation.MyCommand.Name; $Letter = ""; return $Letter}
				if ($iPart -gt $global:MSRPart) {$iPartition = $iPart -2}
				if ($global:MSRPart -eq 0) {$iPartition = $iPart -1}	
			} else {
				$iPartition = $iPart -1 
			}
			$iQuery = GET-WMIOBJECT -query "SELECT * from win32_logicaldisktopartition"
			$iQueryInfo = GET-WMIOBJECT -query "SELECT * from win32_logicaldisktopartition" | Measure-Object
		
			if ($iQueryInfo.count -le 0) { WriteLog -Message "`tNo Antecedents found" -MessageType Error -Component $MyInvocation.MyCommand.Name; return $null }
			Foreach ($elem in $iQuery) {
				#WriteLog "Antecedent found $($iQueryInfo.count)"
				[string]$ant = $elem.Antecedent
				if ($ant.Contains("Disk #$($iDisk), Partition #$($iPartition)")) {
					$dep = $($elem.Dependent).Split("=")
					$Letter = $dep[1] -replace '"',''
					if ($global:GPT){
						WriteLog -Message "`t[GPT]Found Letter for Disk $($iDisk) / Partition $($iPart) = [$($Letter)]" -Component $MyInvocation.MyCommand.Name
					} else {
						WriteLog -Message "`tFound Letter for Disk $($iDisk) / Partition $($iPart) = [$($Letter)]" -Component $MyInvocation.MyCommand.Name
					}
					return $Letter
				}
			}
			if ($Null -eq $Letter) { 
				if ($Force) {
					WriteLog -Message "Option to force to assign letter is enabled, try to assign letter to this partition [$($iDisk):$($iPart)]" -Component $MyInvocation.MyCommand.Name;
					$Letter=Set-PartLetter -iDisk $iDisk -iPart $iPart
					if ($null -eq $Letter) { $Letter="";}
					return $Letter
				} else {
					WriteLog -Message "`tNot Found Letter for Disk $($iDisk) / Partition $($iPart)" -MessageType Warning -Component $MyInvocation.MyCommand.Name; 
					$Letter = ""; 
					return $Letter
				}
			}
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



<#
.SYNOPSIS
    Functions to retrieve drive letter based on root path
.DESCRIPTION
	Get_DriveByPath retrieve letter drive based on root directory path
.NOTES
	Script version 1.0.4
	Script Date Sep.1.2020
.PARAMETER Path
	string path to search from root on each drive available on computer
.EXAMPLE

    Get_DriveByPath -Path "\Windows\system32\sysprep"
#>
Function Get_DriveByPath {
	[OutputType([string])]
	Param 
	(
		[Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,HelpMessage="Relative path to seach",Position=0)]
		[ValidateNotNullOrEmpty()]
		[Alias("Relative")]
        [string]$Path
    )
	Begin {
		WriteLog -Message "=================== Get_DriveByPath START ======================================" -Component $MyInvocation.MyCommand.Name
	}
	Process {
		$FoundLetter = ""
		if (!($Path.Trim().StartsWith("\"))){ $Path = "\$($Path)"}
		WriteLog -Message "Get Drive by root path [root]$($Path) ..." -Component $MyInvocation.MyCommand.Name
		$ErrorActionPreference = "Stop";
		Try {
			$DiskQuery = GET-WMIOBJECT -query "select * from win32_logicaldisk where drivetype=3 and name!=null and name!='X:'" 
			Foreach ($disk in $DiskQuery){
				$buildpath = "$($disk.DeviceID)$($Path)"
				WriteLog -Message "`tTest drive [$($disk.DeviceID)]$($Path)" -Component $MyInvocation.MyCommand.Name
				if (Test-Path $buildpath) { WriteLog -Message "`tFound Path on Drive: $($disk.DeviceID)" -Component $MyInvocation.MyCommand.Name; $FoundLetter = $disk.DeviceID; return $FoundLetter }
			}
			WriteLog -Message "Not possible found provided Path on available Drives" -MessageType Error -Component $MyInvocation.MyCommand.Name
			return $FoundLetter
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
    Functions to retrieve drive letter based on label
.DESCRIPTION
	Get_DriveByLabel retrieve letter drive based on string 
.NOTES
	Script version 1.0.0
	Script Date Apr.24.2021
.PARAMETER Label
	string of partition's label or Volume Name
.EXAMPLE

    Get_DriveByLabel -Label "HP_RECOVERY"
#>
Function Get_DriveByLabel {
	[OutputType([string])]
	Param 
	(
		[Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,HelpMessage="Relative path to seach",Position=0)]
		[ValidateNotNullOrEmpty()]
		[Alias("volumename")]
        [string]$Label
    )
	Begin {
		$ErrorActionPreference = "Stop";
		WriteLog -Message "=================== Get_DriveByLabel START ======================================" -Component $MyInvocation.MyCommand.Name
	}
	Process {
		$FoundLetter = ""
		WriteLog -Message "Get Drive by label ""$($Label)""" -Component $MyInvocation.MyCommand.Name
		Try {
			$VolumeInstance=(Get-CimInstance win32_logicaldisk | Where-Object {$_.VolumeName -eq "$($Label)"})
			if ($null -ne $VolumeInstance){
				$FoundLetter=$VolumeInstance.DeviceID
				if (!([string]::IsNullOrWhiteSpace($FoundLetter) )) {
					WriteLog -Message "Found drive: [$($Label)]=[$($FoundLetter)]" -Component $MyInvocation.MyCommand.Name
					return $FoundLetter
				} else {
					WriteLog -Message "Not possible detect letter assigned to that label" -MessageType Error -Component $MyInvocation.MyCommand.Name
					return $null
				}
			}
			WriteLog -Message "Not possible detect partition associated with that label" -MessageType Error -Component $MyInvocation.MyCommand.Name
			return $null
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
