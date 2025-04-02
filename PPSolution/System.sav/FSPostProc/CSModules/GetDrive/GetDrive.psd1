@{
GUID="8f9e59db-9f56-42b7-b3cf-35516bcfe81b"
Author="Jorge Cisneros"
CompanyName="HP Inc"
Copyright="� HP Inc. All rights reserved."
ModuleVersion="1.0.4.0"
FunctionsToExport = @('GetDiskInfo', 'ValidateDisk', 'IsGPT', 'DetectPart', 'Set-PartLetter', 'Get_DriveLetter', 'Get_DriveByPath', 'Get_DriveByLabel')
DotNetFrameworkVersion = 4.5
CmdletsToExport = @()
AliasesToExport = @()
NestedModules="GetDrive.psm1"
HelpInfoURI = 'mailto:jocisneros@hp.com'
}
