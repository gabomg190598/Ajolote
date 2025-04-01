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
.SYNOPSIS
    Assign letter to all volumes.
.DESCRIPTION
    Proces use Diskpart to list all Volume and then check which on has not letter, it try to assign one
    Don't control what drive is assigned but current drive letter assigned are not modified.
.NOTES
	Script version 1.0.1
	Script Date May.17.2021
.EXAMPLE
    Set-AllLetterDrive
#>
function Set-AllLetterDrive {
    [CmdletBinding()]
    Param(
    )
	Begin {
        $ErrorActionPreference = "Stop"
        if ((Get-PSCallStack).Count -lt 3){  #call from Command line
            $Path =(Get-Item -Path '.\' -Verbose).FullName
        } else {
            $Path = Split-Path (Get-PSCallStack)[(Get-PSCallStack).Count-2].ScriptName -Parent
        }
		WriteLog -Message "============================== ASSIGN LETTER TO ALL PARTITIONS START ==============================" -Component $MyInvocation.MyCommand.Name
	}	
	Process {
	
		$strScan = "$($Path)\HPScan.txt"
		$strResult = "$($Path)\HPResult.log"
        $strAssign = "$($Path)\HPAssign.txt"
        $strAssResult = "$($Path)\HPAssignResults.log"
		
		Try
		{ 
            if (Test-Path $strScan) { Remove-Item -Path $strScan -Force }
            if (Test-Path $strAssign) { Remove-Item -Path $strAssign -Force }
            ForEach ($d in (Get-Disk)) {
                WriteLog -Message "Scan disk #$($d.Number)" -Component $MyInvocation.MyCommand.Name
                WriteLog -Message "`tPartitions detected #$($d.NumberofPartitions)" -Component $MyInvocation.MyCommand.Name
                $part = Get-Partition -DiskNumber $d.Number -ErrorAction SilentlyContinue | Where-Object {$_.Type -ne "Reserved"}
                ForEach ($p in $part) {
                    if ($null -eq ($p|Get-Volume).DriveLetter -OR ($p|Get-Volume).DriveLetter.ToString().Trim().length -lt 1) {
                        WriteLog -Message "`tPartition [$($d.Number):$($p.PartitionNumber)] has no letter, assign one..." -Component $MyInvocation.MyCommand.Name
                        Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber $p.PartitionNumber -AssignDriveLetter 
                    }
                    $vol = Get-Partition -DiskNumber $d.Number -PartitionNumber $p.PartitionNumber | Get-Volume
                    WriteLog -Message "`tVolume Information [$($d.Number):$($p.PartitionNumber)], Letter: [$($vol.DriveLetter)], Label: [$($vol.FileSystemLabel)]" -Component $MyInvocation.MyCommand.Name
                }
            }
            WriteLog -Message "Scan Volumes, you can find results on $($strResult)" -Component $MyInvocation.MyCommand.Name			
            Add-Content -Path $strScan -Value "RESCAN"
            Add-Content -Path $strScan -Value "LIS VOL"
            $runDiskpart=Invoke-RunPower -File "cmd.exe" -Params "/c Diskpart /s $($strScan)" -WorkDir $PSScriptRoot -OutFile $strResult 
            if ($runDiskpart -eq 0) {
                WriteLog -Message "Diskpart complete execution successfully, read results" -Component $MyInvocation.MyCommand.Name
                $Diskpart = Get-Content $strResult | Select-String -Pattern "Volume" | Where-Object { $_ -notlike "*#*"}
                if ($null -ne $Diskpart) {
                    foreach ($line in $Diskpart) {
                        if (($line.ToString().Trim().ToLower() -notlike "*no volume*") -OR ($line.ToString().Trim().ToLower() -notlike "*is the selected*")) {
                            $arrayVolume = $line.ToString().Replace("*","").Trim().Replace("    "," ").Replace("   "," ").Replace("  "," ").Split(" ")
                            WriteLog -Message "Volumme detected: #$($arrayVolume[1]) - $($arrayVolume[2]) $($arrayVolume[3])" -Component $MyInvocation.MyCommand.Name
                            if ($arrayVolume[2].Trim().Length -ne 1) {
                                WriteLog -Message "This volume [$($arrayVolume[1])] require assign letter" -MessageType Warning -Component $MyInvocation.MyCommand.Name
                                Add-Content -Path $strAssign -Value "SEL VOL $($arrayVolume[1])"
                                Add-Content -Path $strAssign -Value "ASS NOERR"
                                Add-Content -Path $strAssign -Value "DETA PART"
                            }
                        }
                    }
                } else {
                    WriteLog -Message "Not possible detect diskpart information" -MessageType Error -Component $MyInvocation.MyCommand.Name
                }
            } else {
                WriteLog -Message "An error occurs during Diskpart execution" -MessageType Error -Component $MyInvocation.MyCommand.Name
            }

            if (Test-Path $strAssign) {
                WriteLog -Message "Some volumes require assign letter, running Dispart..." -Component $MyInvocation.MyCommand.Name
                $runDiskpart=Invoke-RunPower -File "cmd.exe" -Params "/c Diskpart /s $($strAssign)" -WorkDir $PSScriptRoot -OutFile $strAssResult
                if ($runDiskpart -eq 0) {
                    WriteLog -Message "Diskpart run successfully, log can be review on $($strAssResult)" -Component $MyInvocation.MyCommand.Name;
                    if (Test-Path $strAssign) { Remove-Item -Path $strAssign -Force }
                }
            }
            if (Test-Path $strScan) { Remove-Item -Path $strScan -Force }
			
				
			WriteLog -Message "============================== ASSIGN LETTER TO ALL PARTITIONS END ================================" -Component $MyInvocation.MyCommand.Name
		}
		Catch 
		{
			$ErrorMessage = $_.Exception.Message
			WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
		}
		Finally { $ErrorActionPreference = "Continue" }	
	
	}
}
