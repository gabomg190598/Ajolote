@{
GUID="a22dcc86-d17b-49d6-b5da-3b2731bc4589"
Author="Jorge Cisneros"
CompanyName="HP Inc"
Copyright="� HP Inc. All rights reserved."
ModuleVersion="1.0.11.0"
FunctionsToExport = @('Find-AedDiskIndex', 
                    'Get-AedSerialNumber', 
                    'Get-AEDRecoveryState', 
                    'Format-AedDrive', 
                    "AedDriveFormat",
                    'Get-AedPartitionDrive', 
                    'Get-ScratchDir', 
                    'Get-EFIDrive', 
                    'Save-SureAgentLogs', 
                    'Get-DriveByPath', 
                    'Get-ValueUEFI', 
                    'Get-ValueUEFIstr', 
                    'Get-ValueUEFIInt', 
                    'Get-ValueUEFIInt64', 
                    'Get-ExistUEFI', 
                    'IsURLAlive')
DotNetFrameworkVersion = 4.5
CmdletsToExport = @()
AliasesToExport = @()
NestedModules="AED_Support.psm1"
HelpInfoURI = 'mailto:jocisneros@hp.com'
}
