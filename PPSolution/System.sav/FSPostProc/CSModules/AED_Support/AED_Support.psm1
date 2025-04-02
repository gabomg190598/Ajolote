#requires -Modules "WriteLog","RunPower","GetDrive"
#Requires -Version 2
<#
.SYNOPSIS
    Functions required for Sure Recover and eMMC device
.DESCRIPTION
	Functions required for Sure Recover and eMMC device
.NOTES
	Script version 1.0.11
	Script Date Nov.23.2021
.EXAMPLE

#>
$csscript = [io.file]::readalltext("$($PSScriptRoot)\ManageUEFI.cs")
if (-not ([System.Management.Automation.PSTypeName]'ManageUEFI').Type) { Add-Type -Language CSharp -TypeDefinition $csscript }


function Find-AedDiskIndex {
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [CimInstance[]] $DriveList,
        [Parameter(Mandatory = $False)]
        [string] $LogFilename,
        [Parameter(Mandatory = $False)]
        [string] $SerialNumber,
        [Parameter(Mandatory = $False)]
        [switch] $IncludeRemovable
	)
	
    [CimInstance[]] $DriveListInstance = $DriveList
    WriteLog -Message "Checking $(($DriveListInstance | Measure-Object).Count) total disks..." -Component $MyInvocation.MyCommand.Name
    WriteLog -Message "$(($DriveList | Format-List -Property * | Out-String | ForEach-Object { $_ }))" -Component $MyInvocation.MyCommand.Name
    if (!$IncludeRemovable) {
        [CimInstance[]] $FilteredDriveList = ($DriveListInstance | Where-Object { $_.Capabilities -notcontains 7 })
        WriteLog -Message "Found $(($FilteredDriveList | Measure-Object).Count) non-removable disks..." -Component $MyInvocation.MyCommand.Name
    }
    if (!([string]::IsNullOrWhiteSpace($SerialNumber))) {
        [CimInstance[]] $FilteredDriveList = ($DriveListInstance | Where-Object { $_.SerialNumber -eq $SerialNumber })
        WriteLog -Message "Found $(($FilteredDriveList | Measure-Object).Count) disks with SerialNumber='$SerialNumber'..." -Component $MyInvocation.MyCommand.Name
    } 
    else {
        # old eMMC method
        if ($null -ne ($DriveListInstance | Where-Object { $_.PNPDeviceID -cmatch "^SD\\" })) {
            [CimInstance[]] $FilteredDriveList = ($DriveListInstance | Where-Object { $_.PNPDeviceID -cmatch "^SD\\" })
            WriteLog -Message "Found $(($FilteredDriveList | Measure-Object).Count) disks with Type='SD'..." -Component $MyInvocation.MyCommand.Name
        } elseif ($null -ne ($DriveListInstance | Where-Object { $_.PNPDeviceID -like "USBSTOR\*SD/MMC*" })) {
            [CimInstance[]] $FilteredDriveList = ($DriveListInstance | Where-Object { $_.PNPDeviceID -like "USBSTOR\*SD/MMC*" })
            WriteLog -Message "Found $(($FilteredDriveList | Measure-Object).Count) disks with Type='USBSTOR'...SD/MMC..." -Component $MyInvocation.MyCommand.Name
        } else {
            WriteLog -Message "Not possible detect valid AED diskk using old method" -MessageType Warning -Component $MyInvocation.MyCommand.Name
        }        
    }
    [int] $DiskIndex = -1
    if (![string]::IsNullOrWhiteSpace($FilteredDriveList)) {
        if (($FilteredDriveList | Measure-Object).Count -gt 1) {
            $DiskIndex = $FilteredDriveList[0].Index
        } else {
            $DiskIndex = $FilteredDriveList.Index
        }
        WriteLog -Message "HP AED disk found at index $DiskIndex" -Component $MyInvocation.MyCommand.Name
    }
    return $DiskIndex
} #end Find-AedDiskIndex



function Get-AedSerialNumber {
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $False)]
        [string] $EmbeddedStorageValue,
        [Parameter(Mandatory = $False)]
        [string] $LogFilename
    )

    # NOTE: if we don't find the BIOS value, or matching serial number, it's not fatal, do not throw
    [string] $SerialNumber = $null
    WriteLog -Message "Reading 'Embedded Storage for Recovery' value from BIOS..." -Component $MyInvocation.MyCommand.Name
    if ([string]::IsNullOrWhiteSpace($EmbeddedStorageValue)) {
		[CimInstance[]] $EmbeddedStorage = (Get-CimInstance -Namespace "root\HP\InstrumentedBios" -ClassName "HP_BIOSString" | Where-Object { $_.Name -eq "Embedded Storage for Recovery" })
        if (($EmbeddedStorage | Measure-Object).Count) {
            $EmbeddedStorageValue = $EmbeddedStorage[0].Value
            WriteLog -Message "Found '$EmbeddedStorageValue'" -Component $MyInvocation.MyCommand.Name
        }
    }
    if (!([string]::IsNullOrWhiteSpace($EmbeddedStorageValue))) {
        $SerialNumber = ($EmbeddedStorageValue -match '/AED\((?<SerialNumber>.+)\)' | ForEach-Object { $Matches.SerialNumber })
    }
    if ([string]::IsNullOrWhiteSpace($SerialNumber)) {
        WriteLog -Message "Serial number not found" -Component $MyInvocation.MyCommand.Name
    }
    else {
        WriteLog -Message "Serial number '$SerialNumber' extracted successfully" -Component $MyInvocation.MyCommand.Name
    }
    return $SerialNumber
} #end Get-AedSerialNumber

function Get-AEDRecoveryState {
    [OutputType([boolean])]
    param(
        [Parameter(Mandatory = $False)]
        [string] $DMIcode,
        [Parameter(Mandatory = $False)]
        [string] $LogFilename
    )
    [CimInstance[]] $FBIntance = (Get-CimInstance -Namespace "root\HP\InstrumentedBios" -ClassName "HP_BIOSString" | Where-Object { $_.Name -eq "Feature Byte" })
    if ([string]::IsNullOrWhiteSpace($DMIcode)) {
        WriteLog -Message "Searching on Feature Byte state of Sure Recover" -Component $MyInvocation.MyCommand.Name
        $DMI_HP_SURREC="jh" #HP Sure Recover | Feature
        $DMI_AED="hW"   #Enable Recovery in hidden Drive ( automated endpoint deployment )
        $DMI_BO_kill_REC="ga"   #Bios: Kill Sure Recover
        $AEDSureRecover=$true
        if (($FBIntance | Measure-Object).Count) {
            $FBIntanceValue = $FBIntance[0].Value
            WriteLog -Message "Found FeatureByte: '$FBIntanceValue" -Component $MyInvocation.MyCommand.Name
            $FB=$FBIntanceValue.Substring(0,$FBIntanceValue.IndexOf("."))
            for ($i=0; $i -lt $FB.length; $i=$i+2) {
                if($FB.Substring($i,2) -ceq $DMI_HP_SURREC){ WriteLog -Message "Detected HP Sure Recover DMI option[$($DMI_HP_SURREC)]" -Component $MyInvocation.MyCommand.Name } 
                if($FB.Substring($i,2) -ceq $DMI_AED){ WriteLog -Message "eMMC will be hidden, DMI option[$($DMI_AED)]" -Component $MyInvocation.MyCommand.Name } 
                if($FB.Substring($i,2) -ceq $DMI_BO_kill_REC){ $AEDSureRecover=$false; WriteLog -Message "Sure Recover feature is disabled by DMI option[$($DMI_BO_kill_REC)]" -MessageType Warning -Component $MyInvocation.MyCommand.Name } 
            }
        } else {
            WriteLog -Message "Not possible read WMI intance" -MessageType Error -Component $MyInvocation.MyCommand.Name
            return $null
        }
        return $AEDSureRecover
    } else {
        WriteLog -Message "Searching ""$($DMIcode)"" on Feature Byte" -Component $MyInvocation.MyCommand.Name
        if (($FBIntance | Measure-Object).Count) {
            $FBIntanceValue = $FBIntance[0].Value
            WriteLog -Message "Found FeatureByte: '$FBIntanceValue" -Component $MyInvocation.MyCommand.Name
            $FB=$FBIntanceValue.Substring(0,$FB.IndexOf("."))
            for ($i=0; $i -lt $FB.length; $i=$i+2) {
                if($FB.Substring($i,2) -ceq $DMIcode){ 
                    WriteLog -Message "Detected DMI option $($DMIcode)" -Component $MyInvocation.MyCommand.Name
                    return $true
                }                 
            }
            WriteLog -Message "Not possible detected DMI option $($DMIcode)" -MessageType Warning -Component $MyInvocation.MyCommand.Name
            return $false
        } else {
            WriteLog -Message "Not possible read WMI intance" -MessageType Error -Component $MyInvocation.MyCommand.Name
            return $null
        }
    }
} #end Get-AEDRecoveryState

function Format-AedDrive {
    param(
        [Parameter(Mandatory = $true)]
        [int] $AedDiskIndex, 
        [Parameter(Mandatory = $false)]
        [bool] $CreateSR=$true,
        [Parameter(Mandatory = $False)]
        [string] $logs=$PSScriptRoot
    )
    try {
        if ($CreateSR) {
            WriteLog -Message "Require create SR partitions, detect where to create and prepare Diskpart file" -Component $MyInvocation.MyCommand.Name
            if ($null -eq $global:HDD_Disk) {
                WriteLog -Message "Main disk was not detected, not possible determinate where to create SR partitions" -MessageType Error -Component $MyInvocation.MyCommand.Name
            } else {
                $BigPar = (Get-Disk -Number $global:HDD_Disk | Get-Partition | Sort-Object -Descending -Property Size)[0]
                $DriveBigPart=Get_DriveLetter -iDisk $BigPar.DiskNumber -iPart $BigPar.PartitionNumber -Force
                WriteLog -Message "Biggest partition found on [$($BigPar.DiskNumber):$($BigPar.PartitionNumber)]=$($DriveBigPart)" -Component $MyInvocation.MyCommand.Name
                $DiskSizeMb=[math]::Round((Get-Disk -Number $AedDiskIndex).Size/1Mb)
                WriteLog -Message "It will require $($DiskSizeMb) Mb given size of current AED disk size" -Component $MyInvocation.MyCommand.Name
                [int] $SRSizeMb = $DiskSizeMb
                [int] $SRAgentSizeMb = 1024
                [string] $SRAgentLabel = "SR_AED"
                [string] $SRImageLabel = "SR_IMAGE"
                [string[]] $AssSR = @(
                    "select disk $($global:HDD_Disk)",
                    "select volume $($DriveBigPart)",
                    "shrink MINIMUM=$($SRSizeMb)",
                    "create partition primary size=$SRAgentSizeMb",
                    "format quick fs=fat32 label='$SRAgentLabel'",
                    "assign",
                    "gpt attributes=0x8000000000000001"
                    "create partition primary",
                    "format quick fs=ntfs label='$SRImageLabel'",
                    "assign",
                    "gpt attributes=0x8000000000000001",
                    "detail disk",
                    "lis part"
                )
                $AssSRFile = "$($logs)\FormatDrivesSR_$($global:HDD_Disk).txt"
                $AssSR | ForEach-Object { Add-Content $AssSRFile -Value $_ }
                $intDiskpart = RunPower -File "Diskpart.exe" -Params "/s $($AssSRFile) " -WorkDir "$($logs)\" -OutFile "$($logs)\AssigDrivesSR_$($global:HDD_Disk).log"
                if ($intDiskpart -ne 0) {
                    WriteLog -Message "Error executing Diskpart to Format SR partitions - $($intDiskpart)" -MessageType Error -Component $MyInvocation.MyCommand.Name
                    return $null
                }
                WriteLog -Message "SR partitions was created successfully" -Component $MyInvocation.MyCommand.Name
            }            
        }
        
        WriteLog -Message "Format eMMC in disk #$($AedDiskIndex)" -Component $MyInvocation.MyCommand.Name
        WriteLog -Message "Create Diskpart file to Setup eMMC Drive" -Component $MyInvocation.MyCommand.Name
        [int] $AgentDriveSizeMb = 1024
        [string] $AgentDriveLabel = "HP_AED"
        [string] $ImageDriveLabel = "HP_IMAGE"
        [string[]] $AssAED = @(
            "select disk $AedDiskIndex",
            "clean",
            "convert gpt NOERR",
            "create partition primary size=$AgentDriveSizeMb",
            "format quick fs=fat32 label='$AgentDriveLabel'",
            "assign",
            "create partition primary",
            "format quick fs=ntfs label='$ImageDriveLabel'",
            "assign",
            "detail disk",
            "lis part"
        )
        $AssAEDFile = "$($logs)\FormatDrivesAED_$($AedDiskIndex).txt"
        $AssAED | ForEach-Object { Add-Content $AssAEDFile -Value $_ }
        WriteLog -Message "Create file to Remove letter to each Drive on eMMC" -Component $MyInvocation.MyCommand.Name
        [string[]] $RemAED = @(
            "select disk $AedDiskIndex",
            "select partition 1",
            "remove noerr",
            "select partition 2",
            "remove noerr",
            "detail disk"
        )
        $RemAEDFile = "$($logs)\RemoveDrivesAED_$($AedDiskIndex).txt"
        $RemAED | ForEach-Object { Add-Content $RemAEDFile -Value $_ }
        WriteLog -Message "Execute Diskpart to Format AED disk" -Component $MyInvocation.MyCommand.Name
        $intDiskpart = RunPower -File "Diskpart.exe" -Params "/s $($AssAEDFile) " -WorkDir "$($logs)\" -OutFile "$($logs)\AssigDrivesAED_$($AedDiskIndex).log"
        if ($intDiskpart -ne 0) {
            WriteLog -Message "Error executing Diskpart to Format AED disk - $($intDiskpart)" -MessageType Error -Component $MyInvocation.MyCommand.Name
            return $null
        }
        WriteLog -Message "Retrieve drive letter assigned to both AED partitions" -Component $MyInvocation.MyCommand.Name
        $AED_EFI = Get_DriveLetter $AedDiskIndex 1 -Force
        $AED_OS = Get_DriveLetter $AedDiskIndex 2 -Force
        WriteLog -Message "AED Agent drive is $($AED_EFI)" -Component $MyInvocation.MyCommand.Name
        WriteLog -Message "AED Image drive is $($AED_OS)" -Component $MyInvocation.MyCommand.Name
        
        
        $AEDProperties = @{agent=$AED_EFI;image=$AED_OS;remove=$RemAEDFile;}
		$AEDObj = New-Object PSObject -Property $AEDProperties
		
		return $AEDObj
        
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
        return $null
    }
    
} 
function AedDriveFormat {
    param(
        [Parameter(Mandatory = $true)]
        [int] $AedDiskIndex,
        [Parameter(Mandatory = $false)]
        [int] $MainDisk=$global:HDD_Disk,
        [Parameter(Mandatory = $false)]
        [bool] $CreateSR=$true,
        [Parameter(Mandatory = $False)]
        [string] $logs=$PSScriptRoot,        
        [Parameter(Mandatory = $False)]
        [Switch] $DPSFormat
    )
    try {
        if ($CreateSR) {
            WriteLog -Message "Require create SR partitions, detect where to create and prepare Diskpart file" -Component $MyInvocation.MyCommand.Name
            if ($null -eq $MainDisk) {
                WriteLog -Message "Main disk was not detected, not possible determinate where to create SR partitions" -MessageType Error -Component $MyInvocation.MyCommand.Name
            } else {
                $BigPar = (Get-Disk -Number $MainDisk | Get-Partition | Sort-Object -Descending -Property Size)[0]
                $DriveBigPart=Get_DriveLetter -iDisk $BigPar.DiskNumber -iPart $BigPar.PartitionNumber -Force
                WriteLog -Message "Biggest partition found on [$($BigPar.DiskNumber):$($BigPar.PartitionNumber)]=$($DriveBigPart)" -Component $MyInvocation.MyCommand.Name
                $DiskSizeMb=[math]::Round((Get-Disk -Number $AedDiskIndex).Size/1Mb)
                WriteLog -Message "It will require $($DiskSizeMb) Mb given size of current AED disk size" -Component $MyInvocation.MyCommand.Name
                [int] $SRSizeMb = $DiskSizeMb
                [int] $SRAgentSizeMb = 1024
                [string] $SRAgentLabel = "SR_AED"
                [string] $SRImageLabel = "SR_IMAGE"
                if ($DPSFormat) {
                    WriteLog -Message "Create Diskpart for DPS service along with AED disk" -Component $MyInvocation.MyCommand.Name
                    [int] $SRSizeMb = $DiskSizeMb + 800;
                    [string[]] $AssSR = @(
                        "SELECT DISK $($MainDisk)",
                        "CREA PART EFI OFFSET=1 SIZE=500 NOERR",
                        "FORMAT FS=FAT32 QUICK LABEL='SYSTEM' NOERR",
                        "ASS",
                        "CREA PART MSR OFFSET=513024 SIZE=16 NOERR",
                        "SELECT PART 1",                        
                        "SHRINK DESIRED = $($SRSizeMb)",
                        "CREA PART PRIM SIZE=800 NOERR",
                        "FORMAT FS=NTFS QUICK LABEL='Windows RE Tools' NOERR",
                        "SET ID='DE94BBA4-06D1-4D40-A16A-BFD50179D6AC'",
                        "GPT ATTRIBUTES=0X8000000000000001",
                        "ASS",
                        "create partition primary size=$($SRAgentSizeMb)",
                        "format quick fs=fat32 label='$($SRAgentLabel)'",
                        "ASS",
                        "gpt attributes=0x8000000000000001"
                        "create partition primary",
                        "format quick fs=ntfs label='$($SRImageLabel)'",
                        "ASS",
                        "gpt attributes=0x8000000000000001",
                        "DETAIL DISK",
                        "LIS PART",
                        "LIST DISK"
                    )

                } else {
                    WriteLog -Message "Create Diskpart only for AED disk" -Component $MyInvocation.MyCommand.Name
                    [string[]] $AssSR = @(
                        "select disk $($MainDisk)",
                        "select volume $($DriveBigPart)",
                        "shrink MINIMUM=$($SRSizeMb)",
                        "create partition primary size=$SRAgentSizeMb",
                        "format quick fs=fat32 label='$SRAgentLabel'",
                        "assign",
                        "gpt attributes=0x8000000000000001"
                        "create partition primary",
                        "format quick fs=ntfs label='$SRImageLabel'",
                        "assign",
                        "gpt attributes=0x8000000000000001",
                        "detail disk",
                        "lis part"
                    )
                }
                $AssSRFile = "$($logs)\FormatDrivesSR_$($MainDisk).txt"
                if (Test-Path $AssSRFile) { Remove-Item $AssSRFile -Force }
                $AssSR | ForEach-Object { Add-Content $AssSRFile -Value $_ }
                $intDiskpart = RunPower -File "Diskpart.exe" -Params "/s $($AssSRFile) " -WorkDir "$($logs)\" -OutFile "$($logs)\AssigDrivesSR_$($MainDisk).log"
                if ($intDiskpart -ne 0) {
                    WriteLog -Message "Error executing Diskpart to Format SR partitions - $($intDiskpart)" -MessageType Error -Component $MyInvocation.MyCommand.Name
                    return $null
                }
                WriteLog -Message "SR partitions was created successfully" -Component $MyInvocation.MyCommand.Name
            }            
        }
        
        WriteLog -Message "Format eMMC in disk #$($AedDiskIndex)" -Component $MyInvocation.MyCommand.Name
        WriteLog -Message "Create Diskpart file to Setup eMMC Drive" -Component $MyInvocation.MyCommand.Name
        [int] $AgentDriveSizeMb = 1024
        [string] $AgentDriveLabel = "HP_AED"
        [string] $ImageDriveLabel = "HP_IMAGE"
        [string[]] $AssAED = @(
            "select disk $AedDiskIndex",
            "clean",
            "convert gpt NOERR",
            "create partition primary size=$AgentDriveSizeMb",
            "format quick fs=fat32 label='$AgentDriveLabel'",
            "assign",
            "create partition primary",
            "format quick fs=ntfs label='$ImageDriveLabel'",
            "assign",
            "detail disk",
            "lis part"
        )
        $AssAEDFile = "$($logs)\FormatDrivesAED_$($AedDiskIndex).txt"
        $AssAED | ForEach-Object { Add-Content $AssAEDFile -Value $_ }
        WriteLog -Message "Create file to Remove letter to each Drive on eMMC" -Component $MyInvocation.MyCommand.Name
        [string[]] $RemAED = @(
            "select disk $AedDiskIndex",
            "select partition 1",
            "remove noerr",
            "select partition 2",
            "remove noerr",
            "detail disk"
        )
        $RemAEDFile = "$($logs)\RemoveDrivesAED_$($AedDiskIndex).txt"
        $RemAED | ForEach-Object { Add-Content $RemAEDFile -Value $_ }
        WriteLog -Message "Execute Diskpart to Format AED disk" -Component $MyInvocation.MyCommand.Name
        $intDiskpart = RunPower -File "Diskpart.exe" -Params "/s $($AssAEDFile) " -WorkDir "$($logs)\" -OutFile "$($logs)\AssigDrivesAED_$($AedDiskIndex).log"
        if ($intDiskpart -ne 0) {
            WriteLog -Message "Error executing Diskpart to Format AED disk - $($intDiskpart)" -MessageType Error -Component $MyInvocation.MyCommand.Name
            return $null
        }
        WriteLog -Message "Retrieve drive letter assigned to both AED partitions" -Component $MyInvocation.MyCommand.Name
        $AED_EFI = Get_DriveLetter $AedDiskIndex 1 -Force
        $AED_OS = Get_DriveLetter $AedDiskIndex 2 -Force
        WriteLog -Message "AED Agent drive is $($AED_EFI)" -Component $MyInvocation.MyCommand.Name
        WriteLog -Message "AED Image drive is $($AED_OS)" -Component $MyInvocation.MyCommand.Name
        
        
        $AEDProperties = @{agent=$AED_EFI;image=$AED_OS;remove=$RemAEDFile;}
		$AEDObj = New-Object PSObject -Property $AEDProperties
		
		return $AEDObj
        
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
        return $null
    }
    
} 

function Get-AedPartitionDrive {
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [int] $iDisk,
        [Parameter(Mandatory = $true)]
        [int] $iPart
    )
    try {
        $SupStorage=$false
		if (Get-Command Get-Disk -errorAction SilentlyContinue) { $SupStorage=$true;}
		if ($SupStorage) {
            $DriveLetter = (Get-Disk -Number $iDisk | Get-Partition -PartitionNumber $iPart | Get-Volume).DriveLetter
            if ($DriveLetter) {
                WriteLog -Message "Detected Driver Letter [$($iDisk):$($iPart)]=[$($DriveLetter):]" -Component $MyInvocation.MyCommand.Name;
                return "$($DriveLetter):"
            } else {
                WriteLog -Message "Not drive letter detected for [$($iDisk):$($iPart)]" -MessageType Warning -Component $MyInvocation.MyCommand.Name
                return $null
            }
        } else {
            WriteLog -Message "Not possible use this function due not support for Storage cmdlet" -MessageType Error -Component $MyInvocation.MyCommand.Name
            return $null
        }
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
        return $null
    }
    
} 



function Get-ScratchDir {
    [OutputType([string])]
    param(
    )
    try {
        $SupStorage=$false
		if (Get-Command Get-Disk -errorAction SilentlyContinue) { $SupStorage=$true; WriteLog -Message "Storage cmdlet supported" -Component $MyInvocation.MyCommand.Name;}
		if ($SupStorage) {
            $AvailableParts = Get-Disk | Get-Partition | Sort-Object -Property Size -Descending
            foreach ($part in $AvailableParts) {
                $scratch=Get-AedPartitionDrive -iDisk $part.DiskNumber -iPart $part.PartitionNumber
                if ($scratch) {
                    WriteLog -Message "Biggest drive found is $($scratch) [$([math]::round($part.Size/1Gb, 0))GB]" -Component $MyInvocation.MyCommand.Name
                    return $scratch
                }
                
            }
            WriteLog -Message "Not possible detect a partition with letter assigned" -MessageType Error -Component $MyInvocation.MyCommand.Name
            return $null
        } else {
            WriteLog -Message "Not possible use this function due not support for Storage cmdlet" -MessageType Error -Component $MyInvocation.MyCommand.Name
            return $null
        }
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
        return $null
    }
    
} 

function Get-EFIDrive {
    [OutputType([string])]
    param(
    )
    try {
        $SupStorage=$false
		if (Get-Command Get-Disk -errorAction SilentlyContinue) { $SupStorage=$true; WriteLog -Message "Storage cmdlet supported" -Component $MyInvocation.MyCommand.Name;}
		if ($SupStorage) {
            $AvailableParts = Get-Disk | Get-Partition | Where-Object {$_.Type -eq "System"}
            WriteLog -Message "Detected EFI partition on [$($AvailableParts[0].DiskNumber):$($AvailableParts[0].PartitionNumber)]" -Component $MyInvocation.MyCommand.Name
            WriteLog -Message "Run Diskpart to Assign drive letter to EFI partition: AssigEFI_$($AvailableParts[0].DiskNumber).txt" -Component $MyInvocation.MyCommand.Name
            [string[]] $AssEFI = @(
            "select disk $($AvailableParts[0].DiskNumber)",
            "select partition $($AvailableParts[0].PartitionNumber)",
            "assign noerr",
            "detail disk"
            )
            $AssEFIFile = "$($global:logs)\AssigEFI_$($AvailableParts[0].DiskNumber).txt"
            $AssEFI | ForEach-Object {
                Add-Content $AssEFIFile -Value $_
            }
            $intDiskpart = RunPower -File "Diskpart.exe" -Params "/s $($AssEFIFile) " -WorkDir "$($global:logs)\" -OutFile "$($global:logs)\AssigDrivesEFI_$($AvailableParts[0].DiskNumber).log"
            if ($intDiskpart -ne 0) {
                WriteLog -Message "Not possible assign letter to EFI partition" -Component $MyInvocation.MyCommand.Name
                return $null
            }
            $DPVolume = (Get-Content "$($global:logs)\AssigDrivesEFI_$($AvailableParts[0].DiskNumber).log") | Select-String -Pattern "^\* Volume"
            $DPSplit = $DPVolume.ToString().Replace("     "," ").Replace("    "," ").Replace("   "," ").Replace("  "," ").Split(" ")
            if ($DPSplit[3].Length -eq 1) {
                $efidrive="$($DPSplit[3]):"
                WriteLog -Message "Drive letter detected on efi partition is [$($efidrive)]"
            } else {
                WriteLog -Message "It was not possible to detect letter assigned to EFI partition [$($DPVolume)]" -MessageType Warning -Verbose
                $efidrive=$null
            }
            
            return $efidrive
        } else {
            WriteLog -Message "Not possible use this function due not support for Storage cmdlet" -MessageType Error -Component $MyInvocation.MyCommand.Name
            return $null
        }
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
        return $null
    }
    
} 


function Save-SureAgentLogs {
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $SourceLogs,
        [Parameter(Mandatory = $false)]
        [bool] $WaitForHTA = $true,
        [Parameter(Mandatory = $false)]
        [int] $ErrorCode=0,
        [Parameter(Mandatory = $false)]
        [string] $ErrorMessage = "CS Sure Recover Agent exit"
    )
    try {
        $SupStorage=$false
		if (Get-Command Get-Disk -errorAction SilentlyContinue) { $SupStorage=$true; WriteLog -Message "Storage cmdlet supported" -Component $MyInvocation.MyCommand.Name;}
		if ($SupStorage) {
            WriteLog -Message "Save Sure Agent Logs trigger" -Component $MyInvocation.MyCommand.Name
            WriteLog -Message "Source Logs path: $($SourceLogs)" -Component $MyInvocation.MyCommand.Name
            WriteLog -Message "    Exit Message: $($ErrorMessage)" -Component $MyInvocation.MyCommand.Name
            WriteLog -Message "       Exit Code: $($ErrorCode)" -Component $MyInvocation.MyCommand.Name
            if (!(Test-Path $SourceLogs)) {
                [System.reflection.assembly]::LoadWithPartialName("Microsoft.VisualBasic") |Out-Null
                $opMessage = "Not found Logs folder.`r`n" +
                    "Please report to HP CS Team `r`n" 
                $null = [Microsoft.VisualBasic.Interaction]::MsgBox($opMessage,"OkOnly,SystemModal,Critical","ERROR SAVING CS RECOVERY AGENT LOGS")
            }
            WriteLog -Message "Source logs exist: $($SourceLogs)" -Component $MyInvocation.MyCommand.Name
            #Remove letters for AED drives
            WriteLog -Message "Check if exst files to remove AED drive letters" -Component $MyInvocation.MyCommand.Name;
            $AEDFiles = Get-ChildItem -Path $SourceLogs -Filter "RemoveDrivesAED_*.txt" -File
            $AEDFiles | ForEach-Object {
                $intDiskpart = RunPower -File "Diskpart.exe" -Params "/s $($_.FullName) " -WorkDir "$($SourceLogs)\" -OutFile "$($SourceLogs)\RemoveDrivesAED.log"
                if ($intDiskpart -ne 0) { #not an issue but is better for process
                    $Errormsg="Not possible remove letters for AED process" 
                    $Errorcod=$intDiskpart
                    WriteLog -Message "$($Errormsg) ($($Errorcod))" -MessageType Warning -Component $MyInvocation.MyCommand.Name
                }
            }
            <#$ScriptPath = Split-Path $MyInvocation.MyCommand.Path -Parent
            $SciptName = $MyInvocation.MyCommand.Name
            $SciptLogName = $SciptName.substring(0,[int]($SciptName.length)-4) + ".log"
            if (Test-Path "$($ScriptPath)\$($SciptLogName)") {
                Copy-Item -Path "$($ScriptPath)\$($SciptLogName)" -Destination "$($SourceLogs)\CSAgent_components.log"-Force
            }#>
            [string]$UniqueFolder=Get-Date -Format "MMddyyyy_hhmmss"
            WriteLog -Message "Moving logs to HDD" -Component $MyInvocation.MyCommand.Name
            $PartitionBasic = (Get-Disk | Get-Partition | Where-Object{($_.Type -eq "Basic") -AND (Test-Path "$($_.DriveLetter):\")} | Sort-Object -Property Size -Descending)
            if ($null -ne $PartitionBasic) { 
                if (!(Test-Path "$($PartitionBasic[0].DriveLetter):\system.sav")) {
                    $null = RunPower -File "cmd.exe" -Params "/c md $($PartitionBasic[0].DriveLetter):\system.sav" -OutFile "$($SourceLogs)\CreateSYSTEM.SAV.log";  
                    $null = RunPower -File "cmd.exe" -Params "/c attrib +h $($PartitionBasic[0].DriveLetter):\system.sav /d" -OutFile "$($SourceLogs)\HideSYSTEM.SAV.log"; 
                }
                if (!(Test-Path "$($PartitionBasic[0].DriveLetter):\system.sav\logs")) {
                    $null = RunPower -File "cmd.exe" -Params "/c md $($PartitionBasic[0].DriveLetter):\system.sav\logs" -OutFile "$($SourceLogs)\CreateLOGS.log";
                }
                if (!(Test-Path "$($PartitionBasic[0].DriveLetter):\system.sav\logs\CSAgent")) {
                    $null = RunPower -File "cmd.exe" -Params "/c md $($PartitionBasic[0].DriveLetter):\system.sav\logs\CSAgent" -OutFile "$($SourceLogs)\CreateCSAgent.log";
                }
                if (!(Test-Path "$($PartitionBasic[0].DriveLetter):\system.sav\logs\CSAgent\$($UniqueFolder)")) {
                    $null = RunPower -File "cmd.exe" -Params "/c md $($PartitionBasic[0].DriveLetter):\system.sav\logs\CSAgent\$($UniqueFolder)" -OutFile "$($SourceLogs)\Create$($UniqueFolder).log";
                }
                if (Test-Path "$($PartitionBasic[0].DriveLetter):\system.sav\logs\CSAgent\$($UniqueFolder)") {
                    WriteLog -Message "Found drive to move logs at $($PartitionBasic[0].DriveLetter):\System.sav\logs\CSAgent\$($UniqueFolder)" -Component $MyInvocation.MyCommand.Name
                }
            } else {
                WriteLog -Message "Not possible save log on local disk due not possible detect one valid partition" -MessageType Error -Component $MyInvocation.MyCommand.Name
                [System.reflection.assembly]::LoadWithPartialName("Microsoft.VisualBasic") |Out-Null
                $opMessage = "Not possible save folder on fixed HDD, due not drive detected.`r`n" +
                    "Please report to HP CS Team `r`n" 
                $null = [Microsoft.VisualBasic.Interaction]::MsgBox($opMessage,"OkOnly,SystemModal,Critical","ERROR SAVING CS RECOVERY AGENT LOGS")
            }
            if ($WaitForHTA) {
                $CanIleave = $false
                while (!($CanIleave)) {
                    if (Test-Path "$($SourceLogs)\msg\closehta.log") { $CanIleave=$true}
                    if ($null -eq (Get-Process | Where-Object {$_.Name -like "*mshta*"})) { $CanIleave=$true }
                }
            } 
            Get-Process | Where-Object {$_.Name -like "*mshta*"} | Stop-Process -Force
            if ($ErrorCode -ne 0) {
                WriteLog -Message $ErrorMessage -MessageType Error -Component $MyInvocation.MyCommand.Name
                <#if (!(Get-Process -Id $global:UIAgentID -ErrorAction SilentlyContinue)) {
                    [System.reflection.assembly]::LoadWithPartialName("Microsoft.VisualBasic") |Out-Null
	                $opMessage = "$($ErrorMessage).`r`n" +
				                "Please report to HP CS Team `r`n" 
                    $null = [Microsoft.VisualBasic.Interaction]::MsgBox($opMessage,"OkOnly,SystemModal,Critical","FATAL ERROR ON CS RECOVERY AGENT[$($ErrorCode)]") 
                }#>
            }
            if ($null -ne $PartitionBasic) {
                $CopyAll = RunPower -File "cmd.exe" -Params "/c xcopy /sehiy $($SourceLogs)\* $($PartitionBasic[0].DriveLetter):\system.sav\logs\CSAgent\$($UniqueFolder)\" -WorkDir $PSScriptRoot -OutFile "$($PartitionBasic[0].DriveLetter):\system.sav\logs\CSAgent\$($UniqueFolder)\MoveLogs.log";
                if ($CopyAll -ne 0) {
                    [System.reflection.assembly]::LoadWithPartialName("Microsoft.VisualBasic") |Out-Null
	                $opMessage = "It was not possible copy logs into fixed drive, error code: $($CopyAll).`r`n" +
				                "Please report to HP CS Team `r`n" 
                    $null = [Microsoft.VisualBasic.Interaction]::MsgBox($opMessage,"OkOnly,SystemModal,Critical","ERROR COPY LOGS CS RECOVERY AGENT[$($CopyAll)]") 
                }
            }
            try{
                Stop-Transcript|out-null
            } catch [System.InvalidOperationException]{}
            Restart-Computer -Force
            exit 0
        } else {
            [System.reflection.assembly]::LoadWithPartialName("Microsoft.VisualBasic") |Out-Null
            $opMessage = "Not possible save folder on fixed HDD, due error on Storage cmdlet.`r`n" +
                    "Please report to HP CS Team `r`n" 
            $null = [Microsoft.VisualBasic.Interaction]::MsgBox($opMessage,"OkOnly,SystemModal,Critical","ERROR SAVING CS RECOVERY AGENT LOGS")
        }
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
        [System.reflection.assembly]::LoadWithPartialName("Microsoft.VisualBasic") |Out-Null
        $opMessage = "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage).`r`n" +
                    "Please report to HP CS Team `r`n" 
        $null = [Microsoft.VisualBasic.Interaction]::MsgBox($opMessage,"OkOnly,SystemModal,Critical","ERROR SAVING CS RECOVERY AGENT LOGS")
        #Start-Process -FilePath "Powershell" -Wait
        Restart-Computer
    }
    
} 


function Get-DriveByPath() {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,Position=0)][ValidateNotNullOrEmpty()][ValidateScript({ ( Split-Path -IsAbsolute $_ ) -eq $false })][String]$RelativePath
    )
	process
	{
        # Get all fixed drives. Exclude WinPE ramdisk.
        $Found = $false
        $DrivebyPath=$null
		$Drives = [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq "fixed" -and $_.Name -ne "x:\" }
        :TopLoop foreach ( $Drive in $Drives ) {

			WriteLog -Message "Checking drive: $($Drive.Name.TrimEnd( "\" ))" -Component $MyInvocation.MyCommand.Name		
			$Path = $Drive.Name.TrimEnd( "\" ) + $RelativePath
			if ( Test-Path $Path ) # If directory exists...
			{
                WriteLog -Message "Found: $($Path)" -Component $MyInvocation.MyCommand.Name	
                $DrivebyPath=$Drive.Name.trimEnd( "\" )
                $Found = $true
                break TopLoop
            }
            else
            {
                WriteLog -Message "Path not found: $($Path)" -MessageType Warning -Component $MyInvocation.MyCommand.Name	
            }
        }
        if ($Found) {
            return $DrivebyPath
        } else {
            return $null
        }
    }
}



function Get-ValueUEFI {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,
        [Parameter(Mandatory = $False)]
        [string] $sGUID="{43b9c282-a6f5-4c36-b8de-c8738f979c65}"
    )
    WriteLog -Message "Retrieve UEFI variable: $($Name) [$($sGUID)]" -Component $MyInvocation.MyCommand.Name
    $GetValue = [ManageUEFI]::Get($Name, $sGUID)
    #WriteLog -Message "`t$($Name)=[$($GetValue)]" -Component $MyInvocation.MyCommand.Name
    return $GetValue
}

function Get-ValueUEFIstr {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,
        [Parameter(Mandatory = $False)]
        [string] $sGUID="{43b9c282-a6f5-4c36-b8de-c8738f979c65}"
    )
    WriteLog -Message "Retrieve UEFI variable: $($Name) [$($sGUID)]" -Component $MyInvocation.MyCommand.Name
    $GetValue = [ManageUEFI]::Getstr($Name, $sGUID)
    #WriteLog -Message "`t$($Name)=[$($GetValue)]" -Component $MyInvocation.MyCommand.Name
    return $GetValue
}
function Get-ValueUEFIInt {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,
        [Parameter(Mandatory = $False)]
        [string] $sGUID="{43b9c282-a6f5-4c36-b8de-c8738f979c65}"
    )
    WriteLog -Message "Retrieve UEFI variable: $($Name) [$($sGUID)]" -Component $MyInvocation.MyCommand.Name
    $GetValue = [ManageUEFI]::GetInt($Name, $sGUID)
    #WriteLog -Message "`t$($Name)=[$($GetValue)]" -Component $MyInvocation.MyCommand.Name
    return $GetValue
}

function Get-ValueUEFIInt64 {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,
        [Parameter(Mandatory = $False)]
        [string] $sGUID="{43b9c282-a6f5-4c36-b8de-c8738f979c65}"
    )
    WriteLog -Message "Retrieve UEFI variable: $($Name) [$($sGUID)]" -Component $MyInvocation.MyCommand.Name
    $GetValue = [ManageUEFI]::GetInt64($Name, $sGUID)
    #WriteLog -Message "`t$($Name)=[$($GetValue)]" -Component $MyInvocation.MyCommand.Name
    return $GetValue
}

function Get-ExistUEFI {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,
        [Parameter(Mandatory = $False)]
        [string] $sGUID="{6718cecf-d788-11e3-a200-78e7d1af36d1}"
	)
    [bool]$ExistVar = [ManageUEFI]::GetExist($Name, $sGUID)
   return $ExistVar
}

Function IsURLAlive{
	[CmdletBinding()]
	Param 
	(
		[Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$True,HelpMessage="URL",Position=0)]
		[AllowNull()]
		[Alias("url")]
        [String]$uri
	)
	##### CHECK IF IS ALIVE
    $Solicitud = $null 
    $time = try {
        $resultado = Measure-Command {$Solicitud = Invoke-WebRequest -Uri $uri -UseDefaultCredentials; $Solicitud | Out-Null; }
        $resultado.TotalMilliseconds
    } catch {
        $Solicitud = $_.Exception.Response 
        $time = -1 
	    WriteLog -Message "It seems like Site is down or not reacheable..." -MessageType Warning -Component $MyInvocation.MyCommand.Name
    }
    #
	if ($null -eq $time) {
		WriteLog -Message "Running Double check..." -MessageType Warning -Component $MyInvocation.MyCommand.Name
		For ($i=0; $i -lt 3; $i++) {
			WriteLog -Message "[$($i)]Refresh session..." -MessageType Warning -Component $MyInvocation.MyCommand.Name
			$time = try {
				$resultado = Measure-Command {$Solicitud = Invoke-WebRequest -Uri $uri -UseDefaultCredentials; $Solicitud | Out-Null; }
				$resultado.TotalMilliseconds
			} catch {
				$Solicitud = $_.Exception.Response 
				$time = -1 
			}
			if ($null -ne $time) {$i=5;}
		}
	}
    $resultado = [PSCustomObject] @{ 
        Time = Get-Date; 
        Uri = $uri; 
        StatusCode = [int] $Solicitud.StatusCode; 
        StatusDescription = $Solicitud.StatusDescription; 
        ResponseLength = $Solicitud.RawContentLength; 
        TimeTaken = $time; 
    } 
    WriteLog -Message $resultado -Component $MyInvocation.MyCommand.Name
    if ($resultado.StatusCode -eq 200) {
	    WriteLog -Message "Time Response from Site: $([Math]::Round($resultado.TimeTaken/(1000))) Seconds" -Component $MyInvocation.MyCommand.Name
	    return $true
    } else {
	    WriteLog -Message "`tSite semms to be down or is not reacheable" -MessageType Error -Component $MyInvocation.MyCommand.Name
	    return $false
    }
}