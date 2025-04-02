#  Copyright 2018-2024 HP Development Company, L.P.
#  All Rights Reserved.
# 
# NOTICE:  All information contained herein is, and remains the property of HP Inc.
# 
# The intellectual and technical concepts contained herein are proprietary to HP Inc
# and may be covered by U.S. and Foreign Patents, patents in process, and are protected by 
# trade secret or copyright law. Dissemination of this information or reproduction of this material
# is strictly forbidden unless prior written permission is obtained from HP Inc.




<#
.SYNOPSIS

  Command line interface to perform various HP BIOS operations

.DESCRIPTION

  This script is a user-facing command line interface for manipulating HP BIOS settings. It can be used
  to set, read, or reset BIOS settings.

  The script supports input and output formats in XML, JSON, CSV, and also in the legacy BIOS Configuration Utility (BCU) format.
  Normally the file format is inferred from the extension of the file, but can also be dictated via the -format parameter.



.PARAMETER get

  format: \<-get\> <setting> [-format <csv|bcu|json|xml>]

  Get a single setting from the BIOS. By default, the only setting's value is returned.

  Optionally, the -format string may be provided to retrieve a full setting definition, and format it as a bcu, xml, json, or csv entry.

  
.PARAMETER set

  format: \<-set\> <setting> [-value] \<newvalue\> [-currentpassword \<password\>]

  Set a single BIOS setting. Specify the value with the -value switch
  If a BIOS setup password is currently active on the machine, the password must be supplied via the -currentpassword switch


.PARAMETER password

  format: \<-password\> <-set \<password\> |-check | -clear> [-currentpassword \<password\>] 

  Manipulates the setup password. 

  Specify -set <password> to set the password, -check to check if the password is set, and -clear to clear the password.

  To modify the password while a password is already set, the existing password must be supplied via the -currentpassword argument.

.PARAMETER import

  format: \<-import\> <file> [-format <csv|bcu|json|xml>] [-nosummary] [-nowarnings] [-currentpassword \<password\>]

  Import one or more settings from a file. Normally the format of the file is inferred from the file extension, but can be overridden
  with the -format parameter.

  Specify -nosummary to turn off the end-import one-line summary. By default, -nosummary is false.

  Specify -nowarnings to turn off any warnings about settings that are not found. By default, -nowarnings is false.

  If a setup password is active on the system, it must be specified via the -currentpassword switch.

.PARAMETER export

  format: \<-export\> <file> [-format <csv|bcu|json|xml>]

  Export one or more settings to a file. Normally the format of the file is inferred from the file extension, but can be overridden
  with the -format parameter. Password settings are not exported.

.PARAMETER reset

  format: \<-reset\>  [-currentpassword \<password\>]

  Reset all settings to factory defaults. The result of this operation may be platform specific.

  If a setup password is active on the system, it must be specified via the -currentpassword switch.

.PARAMETER help

  format: \<-help\> 

  Print the command line usage.


.NOTES

  Where passwords are required, they may be specified as a single dash (-). This will cause the script to prompt the user for the password.
  Use this when passing passwords via the command line is inappropriate.


.INPUTS
  For -import, read access to the specified file is expected.
  If a setup password is active on the machine, the setup password is a required input for modifying settings.

.OUTPUTS
  For -export, write access to the specified file is expected.

.EXAMPLE 

  Setting BIOS Settings
  
    bios-cli.ps1 -set "Asset Tracking Number" -value "My Tag"

.EXAMPLE 

  Getting a BIOS setting
  
    bios-cli.ps1 -get "Asset Tracking Number"

    bios-cli.ps1 -get "Asset Tracking Number" -format json
    

.EXAMPLE 

  Exporting all settings
  
    bios-cli.ps1 -export test.json

    bios-cli.ps1 -export test.txt -format bcu

    bios-cli.ps1 -export test.txt -currentpassword mycurrentpassword

  The following version is identical to previous version, but prompts for password

    bios-cli.ps1 -export test.txt -currentpassword -


.EXAMPLE 

  Exporting all settings
  
    bios-cli.ps1 -export test.json

    bios-cli.ps1 -export test.txt -format bcu


.EXAMPLE 

  Importing settings
  
    bios-cli.ps1 -import test.bcu

    bios-cli.ps1 -import test.txt -nowarnings -nosummary -format bcu

    bios-cli.ps1 -import test.json -currentpassword mypassword

  The following version is identical to previous version, but prompts for password

    bios-cli.ps1 -import test.json -currentpassword -

.EXAMPLE 

  Resetting settings
  
    bios-cli.ps1 -reset

.EXAMPLE 

  Check if BIOS setup password is set

    bios-cli -password -check

  Clear current password

    bios-cli -password -clear -currentpassword oldpassword

    or to prompt for password...

    bios-cli -password -clear -currentpassword -

  Set / Change password

    bios-cli -password -set newpassword -currentpassword oldpassword

    or to prompt for both password...

    bios-cli -password -set -  -currentpassword -


#>



#
# bios-cli.ps1
#
#requires -version 3
[CmdletBinding(DefaultParameterSetName = 'help')]
param(

  [string]
  [Parameter(ParameterSetName = 'import',Position = 0,Mandatory = $true)]
  $import,
  [string]
  [Parameter(ParameterSetName = 'export',Position = 0,Mandatory = $true)]
  $export,
  [switch]
  [Parameter(ParameterSetName = 'help',Position = 0,Mandatory = $false)]
  $help,
  [string]
  [Parameter(ParameterSetName = 'get',Position = 0,Mandatory = $true)]
  $get,
  [switch]
  [Parameter(ParameterSetName = 'reset',Position = 0,Mandatory = $true)]
  $reset,
  [switch]
  [Parameter(ParameterSetName = 'password',Position = 0,Mandatory = $true)]
  $password,
  [string]
  [Parameter(ParameterSetName = 'set',Position = 0,Mandatory = $true)]
  [Parameter(ParameterSetName = 'password',Position = 1,Mandatory = $false)]
  $set,
  [string]
  [Parameter(ParameterSetName = 'set',Position = 1,Mandatory = $true)]
  $value,
  [switch]
  [Parameter(ParameterSetName = 'password',Position = 1,Mandatory = $false)]
  $clear,
  [switch]
  [Parameter(ParameterSetName = 'password',Position = 1,Mandatory = $false)]
  $check,
  [string]
  [Parameter(Mandatory = $false,ParameterSetName = 'export',Position = 2)]
  [Parameter(Mandatory = $false,ParameterSetName = 'get',Position = 2)]
  [Parameter(Mandatory = $false,ParameterSetName = 'import',Position = 2)]
  [ValidateSet('bcu','csv','xml','json',"brief")]
  $format,
  [string]
  [Parameter(ParameterSetName = 'password',Mandatory = $false,Position = 3)]
  [Parameter(ParameterSetName = 'set',Mandatory = $false,Position = 3)]
  [Parameter(ParameterSetName = 'reset',Mandatory = $false,Position = 3)]
  [Parameter(ParameterSetName = 'import',Mandatory = $false,Position = 3)]
  $currentpassword = "",
  [switch]
  [Parameter(ParameterSetName = 'import',Position = 4,Mandatory = $false)]
  $nosummary,
  [switch]
  [Parameter(ParameterSetName = 'import',Position = 5,Mandatory = $false)]
  $nowarnings,
  [string]
  [Parameter(ParameterSetName = 'password',Mandatory = $false,Position = 6)]
  [Parameter(ParameterSetName = 'get',Mandatory = $false,Position = 6)]
  [Parameter(ParameterSetName = 'set',Mandatory = $false,Position = 6)]
  [Parameter(ParameterSetName = 'reset',Mandatory = $false,Position = 6)]
  [Parameter(ParameterSetName = 'import',Mandatory = $false,Position = 6)]
  [Parameter(ParameterSetName = 'export',Mandatory = $false,Position = 6)]
  $target = ".",
  [Parameter(ValueFromRemainingArguments = $true)] $args
)

if ($args) { Write-Warning "Unknown arguments: $args" }

if ($currentpassword -eq "-") {
  $currentpassword = $(Read-Host "Current BIOS password")
}

# print out the cmdlet help
function do-help ()
{
  Write-Host "HP BIOS Command Line Interface"
  Write-Host "Copyright 2018-2024 HP Development Company, L.P."
  Write-Host "----------------------------------------------"
  Write-Host "bios-cli -help"
  Write-Host "         - print this help text"
  Write-Host ""
  Write-Host "bios-cli -export <file> [-format bcu|json|xml|csv|brief] -target [computer]"
  Write-Host "         - exports all BIOS settings to a file, using specified format.  Specify bcu (default) for"
  Write-Host "           BiosConfigurationUtility compatibility, xml for HPIA XML format, or CSV for a simple"
  Write-Host "           comma-separated-values format. Default is determined from file extension, or 'brief' "
  Write-Host "           if an extension is unknown. Brief will export just the setting names (no values) "
  Write-Host ""
  Write-Host "bios-cli -import <file> [-format bcu|json|xml|csv] [-currentpassword password] [-nosummary] [-nowarnings] -target [computer]"
  Write-Host "         - imports all BIOS settings to a file, using specified format.  If the format"
  Write-Host "           is not specified, it's inferred from the file extension, defaulting to 'bcu'"
  Write-Host ""
  Write-Host "bios-cli -get <setting_name> [-format bcu|json|xml|csv] -target [computer]"
  Write-Host "         - print out the value of the specified BIOS setting. Optionally specify a formatting"
  Write-Host "          to get a full representation of the setting in the desired format."
  Write-Host ""
  Write-Host "bios-cli -set <setting_name> -value <setting_value> [-currentpassword password] -target [computer]"
  Write-Host "         - set the specified BIOS setting to the provided value"
  Write-Host ""
  Write-Host "bios-cli -password -set <password> [-currentpassword <str>] -target [computer]"
  Write-Host "         - change or set the BIOS password to the specified value"
  Write-Host ""
  Write-Host "bios-cli -password -clear -currentpassword <str> -target [computer]"
  Write-Host "         - clear the BIOS password"
  Write-Host ""
  Write-Host "bios-cli -password -check -target [computer]"
  Write-Host "         - check if a BIOS setup password is currently set"
  Write-Host ""
  Write-Host "bios-cli -reset [-currentpassword <str>] -target [computer]"
  Write-Host "         - reset all BIOS settings to default."
  Write-Host ""
  Write-Host "* passwords may be specified as - (dash) to instruct the script to prompt for the password"
}

function Do-Password ()
{
  [CmdletBinding()]
  param()

  try {
    switch ($true)
    {
      { $_ -eq $check } {
        $c = Get-HPBIOSSetupPasswordIsSet -Target $target -Verbose:$VerbosePreference
        return $c
      }

      { $_ -eq $clear } {
        $c = Clear-HPBIOSSetupPassword -password $currentpassword -Target $target -Verbose:$VerbosePreference
        return $c
      }

      { ($_ -eq $set) } {
        if ($set -eq "-") {
          $set = $(Read-Host "New BIOS password")
        }

        $c = Set-HPBIOSSetupPassword -NewPassword $set -password $currentpassword -Target $target -Verbose:$VerbosePreference
        return $c

      }
      { (($_ -eq $clear) -and ($currentpassword)) } {
        $c = Clear-HPBIOSSetupPassword -password $currentpassword -Target $target -Verbose:$VerbosePreference
        return $c
      }

      default { do-help }
    }
  }
  catch {
    Write-Host -ForegroundColor Magenta "$($PSItem.ToString())"
  }

}


function Do-Reset ()
{
  [CmdletBinding()]
  param()

  try {
    return Set-HPBIOSSettingDefaults ($currentpassword) -Target $target -Verbose:$VerbosePreference
  }
  catch {
    Write-Host -ForegroundColor Magenta "$($PSItem.ToString())"
  }
}


function Do-Set ()
{
  [CmdletBinding()]
  param()

  try {
    return Set-HPBIOSSettingValue -Name $set -Value $value -password $currentpassword -Target $target -Verbose:$VerbosePreference
  }
  catch {
    Write-Host -ForegroundColor Magenta "$($PSItem.ToString())"
    if ($PSItem.ToString().StartsWith("Setting not found:")) {
      exit (20)
    }
    else {
      $action = $PSItem.ToString()
      $code = $BiosErrorStringToCode[$action]
      exit ($code)
    }
  }
}

function Do-Get ()
{
  [CmdletBinding()]
  param()

  try {
    if (($format -eq "brief") -or ($format -eq "")) { $c = Get-HPBIOSSettingValue -Name $get -Target $target -Verbose:$VerbosePreference }
    else { $c = Get-HPBIOSSetting -Name $get -Format $format -Target $target -Verbose:$VerbosePreference }
    return $c
  }

  catch {
    Write-Host -ForegroundColor Magenta "$($PSItem.ToString())"
    if ($PSItem.ToString().StartsWith("Setting not found:")) {
      exit (20)
    }
    else {
      $action = $PSItem.ToString()
      $code = $BiosErrorStringToCode[$action]
      exit ($code)
    }
  }

}

function Do-Export ()
{
  [CmdletBinding()]
  param()
  try {
    [System.IO.Directory]::SetCurrentDirectory($PWD)
    $fullPath = [IO.Path]::GetFullPath($export)

    $supported = @("bcu","xml","json","csv")
    if ($supported -notcontains $format) {
      $format = (Split-Path -Path $fullPath -Leaf).Split(".")[1]

      if ($supported -notcontains $format) {
        $format = "bcu"
      }
    }

    if ($format -eq "bcu") {
      Get-HPBIOSSettingsList -Format $format -Target $target -Verbose:$VerbosePreference | Format-Utf8 $fullPath
    }
    else {
      $c = Get-HPBIOSSettingsList -Format $format -Target $target -Verbose:$VerbosePreference | Out-File $fullPath
    }
  }
  catch {
    Write-Host -ForegroundColor Magenta "$($PSItem.ToString())"
    exit (16) #Matching BCU, 16 = Unable to write to file or system.
  }
}

## utf-8 is required by BCU (no bom)
function Format-Utf8 {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory,Position = 0)] [string]$path,
    [switch]$Append,
    [Parameter(ValueFromPipeline)] $InputObject
  )
  [System.IO.Directory]::SetCurrentDirectory($PWD)

  $fullPath = [IO.Path]::GetFullPath($path)
  $stream = $null

  try {
    $stream = New-Object IO.StreamWriter $fullPath
  }
  catch {
    throw $($PSItem.Exception.innerException.Message)
  }

  [System.IO.StreamWriter]$sw = [System.Console]::OpenStandardOutput()
  $sw.AutoFlush = $true
  $htOutStringArgs = @{}
  try {
    $Input | Out-String -Stream @htOutStringArgs | ForEach-Object { $stream.WriteLine($_) }
  } finally {
    $stream.Dispose()
  }
}

function Do-Import ()
{
  [CmdletBinding()]
  param()

  $errorhandling = 1
  if ($nowarnings -eq $true) {
    $errorhandling = 2
  }

  #try {
  [System.IO.Directory]::SetCurrentDirectory($PWD)
  $fullPath = [IO.Path]::GetFullPath($import)

  $supported = @("bcu","xml","json","csv")
  if ($supported -notcontains $format) {
    $format = (Split-Path -Path $fullPath -Leaf).Split(".")[1]

    if ($supported -notcontains $format) {
      $format = "bcu"
    }
  }

  return Set-HPBIOSSettingValuesFromFile -File $fullPath -Format $format -password $currentpassword $nosummary $errorhandling -Target $target -Verbose:$VerbosePreference
}

$BiosErrorStringToCode = @{
  "OK" = 0;
  "Not Supported" = 1;
  "Unspecified error" = 2;
  "Operation timed out" = 3;
  "Operation failed or setting name is invalid" = 4;
  "Invalid parameter" = 5;
  "Access denied or incorrect password" = 6;
  "Bios user already exists" = 7;
  "Bios user not present" = 8;
  "Bios user name too long" = 9;
  "Password policy not met" = 10;
  "Invalid keyboard layout" = 11;
  "Too many users" = 12;
  "Security or password policy not met" = 32768;
}

# determine the command set requested
switch ($true)
{
  { $_ -eq $password } {
    Do-Password
    exit (0)
  }

  { $_ -eq $export } {
    Do-Export
    exit (0)
  }

  { $_ -eq $import } {
    $action = Do-Import
    if (-not $nosummary.IsPresent) {
      Write-Host -ForegroundColor Magenta $action[0]
      exit ($action[1])
    }
    else {
      exit ($action[0])
    }
  }
  { $_ -eq $get } {
    Do-Get
    exit (0)
  }

  { $_ -eq $reset } {
    Do-Reset
    exit (0)
  }

  { $_ -eq $set } {
    Do-Set
    exit (0)
  }

  { $_ -eq $help } {
    do-help
    exit (0)
  }
  default {
    do-help
    exit (0)
  }
}





# SIG # Begin signature block
# MIIoHQYJKoZIhvcNAQcCoIIoDjCCKAoCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCt3A+Ycj+YnjBd
# 0AB4uGXFD5ux2HLWhmrJY0gDmztsiKCCDYowggawMIIEmKADAgECAhAIrUCyYNKc
# TJ9ezam9k67ZMA0GCSqGSIb3DQEBDAUAMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNV
# BAMTGERpZ2lDZXJ0IFRydXN0ZWQgUm9vdCBHNDAeFw0yMTA0MjkwMDAwMDBaFw0z
# NjA0MjgyMzU5NTlaMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwg
# SW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBDb2RlIFNpZ25pbmcg
# UlNBNDA5NiBTSEEzODQgMjAyMSBDQTEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAw
# ggIKAoICAQDVtC9C0CiteLdd1TlZG7GIQvUzjOs9gZdwxbvEhSYwn6SOaNhc9es0
# JAfhS0/TeEP0F9ce2vnS1WcaUk8OoVf8iJnBkcyBAz5NcCRks43iCH00fUyAVxJr
# Q5qZ8sU7H/Lvy0daE6ZMswEgJfMQ04uy+wjwiuCdCcBlp/qYgEk1hz1RGeiQIXhF
# LqGfLOEYwhrMxe6TSXBCMo/7xuoc82VokaJNTIIRSFJo3hC9FFdd6BgTZcV/sk+F
# LEikVoQ11vkunKoAFdE3/hoGlMJ8yOobMubKwvSnowMOdKWvObarYBLj6Na59zHh
# 3K3kGKDYwSNHR7OhD26jq22YBoMbt2pnLdK9RBqSEIGPsDsJ18ebMlrC/2pgVItJ
# wZPt4bRc4G/rJvmM1bL5OBDm6s6R9b7T+2+TYTRcvJNFKIM2KmYoX7BzzosmJQay
# g9Rc9hUZTO1i4F4z8ujo7AqnsAMrkbI2eb73rQgedaZlzLvjSFDzd5Ea/ttQokbI
# YViY9XwCFjyDKK05huzUtw1T0PhH5nUwjewwk3YUpltLXXRhTT8SkXbev1jLchAp
# QfDVxW0mdmgRQRNYmtwmKwH0iU1Z23jPgUo+QEdfyYFQc4UQIyFZYIpkVMHMIRro
# OBl8ZhzNeDhFMJlP/2NPTLuqDQhTQXxYPUez+rbsjDIJAsxsPAxWEQIDAQABo4IB
# WTCCAVUwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQUaDfg67Y7+F8Rhvv+
# YXsIiGX0TkIwHwYDVR0jBBgwFoAU7NfjgtJxXWRM3y5nP+e6mK4cD08wDgYDVR0P
# AQH/BAQDAgGGMBMGA1UdJQQMMAoGCCsGAQUFBwMDMHcGCCsGAQUFBwEBBGswaTAk
# BggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEEGCCsGAQUFBzAC
# hjVodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9v
# dEc0LmNydDBDBgNVHR8EPDA6MDigNqA0hjJodHRwOi8vY3JsMy5kaWdpY2VydC5j
# b20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNybDAcBgNVHSAEFTATMAcGBWeBDAED
# MAgGBmeBDAEEATANBgkqhkiG9w0BAQwFAAOCAgEAOiNEPY0Idu6PvDqZ01bgAhql
# +Eg08yy25nRm95RysQDKr2wwJxMSnpBEn0v9nqN8JtU3vDpdSG2V1T9J9Ce7FoFF
# UP2cvbaF4HZ+N3HLIvdaqpDP9ZNq4+sg0dVQeYiaiorBtr2hSBh+3NiAGhEZGM1h
# mYFW9snjdufE5BtfQ/g+lP92OT2e1JnPSt0o618moZVYSNUa/tcnP/2Q0XaG3Ryw
# YFzzDaju4ImhvTnhOE7abrs2nfvlIVNaw8rpavGiPttDuDPITzgUkpn13c5Ubdld
# AhQfQDN8A+KVssIhdXNSy0bYxDQcoqVLjc1vdjcshT8azibpGL6QB7BDf5WIIIJw
# 8MzK7/0pNVwfiThV9zeKiwmhywvpMRr/LhlcOXHhvpynCgbWJme3kuZOX956rEnP
# LqR0kq3bPKSchh/jwVYbKyP/j7XqiHtwa+aguv06P0WmxOgWkVKLQcBIhEuWTatE
# QOON8BUozu3xGFYHKi8QxAwIZDwzj64ojDzLj4gLDb879M4ee47vtevLt/B3E+bn
# KD+sEq6lLyJsQfmCXBVmzGwOysWGw/YmMwwHS6DTBwJqakAwSEs0qFEgu60bhQji
# WQ1tygVQK+pKHJ6l/aCnHwZ05/LWUpD9r4VIIflXO7ScA+2GRfS0YW6/aOImYIbq
# yK+p/pQd52MbOoZWeE4wggbSMIIEuqADAgECAhAJvPMqSNxAYhV5FFpsbzOhMA0G
# CSqGSIb3DQEBCwUAMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwg
# SW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBDb2RlIFNpZ25pbmcg
# UlNBNDA5NiBTSEEzODQgMjAyMSBDQTEwHhcNMjQwMjE1MDAwMDAwWhcNMjUwMjE4
# MjM1OTU5WjBaMQswCQYDVQQGEwJVUzETMBEGA1UECBMKQ2FsaWZvcm5pYTESMBAG
# A1UEBxMJUGFsbyBBbHRvMRAwDgYDVQQKEwdIUCBJbmMuMRAwDgYDVQQDEwdIUCBJ
# bmMuMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEApbF6fMFy6zhGVra3
# SZN418Cp2O8kjihQCU9tqPO9tkzbMyTsgveLJVnXPJNG9kQPMGUNp+wEHcoUzlRc
# YJMEL9fhfzpWPeSIIezGLPCdrkMmS3fdRUwFqEs7z/C6Ui2ZqMaKhKjBJTIWnipe
# rRfzGB7RoLepQcgqeF5s0DBy4oG83dqcRHo3IJRTBg39tHe3mD5uoGHn5n366abX
# vC+k53BVyD8w8XLppFVH5XuNlXMq/Ohf613i7DRb/+u92ZiAPVPXXnlxUE26cuDb
# OfJKN/bXPmvnWcNW3YHVp9ztPTQZhX4yWYXHrAI2Cv6HxUpO6NzhFoRoBTkcYNbA
# 91pf1Vagh/MNcA2BfQYT975/Vlvj9cfEZ/NwZthZuHa3rdrvCKhhjw7YU2QUeaTJ
# 0uaX4g6B9PFNqAASYLach3CDJiLmYEfus/utPh57mk0q27yL25fXo/PaMDXiDNIi
# 7Wuz7A+sPsbtdiY8zvEIRQ+XJXtKAlD4tqG9YzlTO6ZoQX/rAgMBAAGjggIDMIIB
# /zAfBgNVHSMEGDAWgBRoN+Drtjv4XxGG+/5hewiIZfROQjAdBgNVHQ4EFgQURH4F
# u5yEAuElYWUbyGRYkNLLrA8wPgYDVR0gBDcwNTAzBgZngQwBBAEwKTAnBggrBgEF
# BQcCARYbaHR0cDovL3d3dy5kaWdpY2VydC5jb20vQ1BTMA4GA1UdDwEB/wQEAwIH
# gDATBgNVHSUEDDAKBggrBgEFBQcDAzCBtQYDVR0fBIGtMIGqMFOgUaBPhk1odHRw
# Oi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkRzRDb2RlU2lnbmlu
# Z1JTQTQwOTZTSEEzODQyMDIxQ0ExLmNybDBToFGgT4ZNaHR0cDovL2NybDQuZGln
# aWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0Q29kZVNpZ25pbmdSU0E0MDk2U0hB
# Mzg0MjAyMUNBMS5jcmwwgZQGCCsGAQUFBwEBBIGHMIGEMCQGCCsGAQUFBzABhhho
# dHRwOi8vb2NzcC5kaWdpY2VydC5jb20wXAYIKwYBBQUHMAKGUGh0dHA6Ly9jYWNl
# cnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNENvZGVTaWduaW5nUlNB
# NDA5NlNIQTM4NDIwMjFDQTEuY3J0MAkGA1UdEwQCMAAwDQYJKoZIhvcNAQELBQAD
# ggIBAFiCyuI6qmaQodDyMNpp0l7eIXFgJ4JI59o59PleFj4rcyd/+F4iI7u5if8G
# rV5Kn3s3tK9vfJO8SpqtEh7lL4e69z6v3ohcy4uy2hsjKQ/fFcDo9pQYDGmDVjCa
# D5qSVEIBlJHBe5NKEJAgUE0kaMjLzbi2+8DKJlNtvZ+hatuPl9fMnmU+VbQh7JhZ
# yJdz8Ay0tcQ9lC8HAX5Ah/pU+Vtv+c8gMSxjS1aWXoGCa1869IVi2O6qx7MuX12U
# 1eIpB9XxYr7HSebvg2G7Gz6nCh7u+4k7m3hJu9EStUIN2JII5260+E60uDWoHEhx
# tHbdueFQxJrTKnhplOSaaPFCVBDkWG83ZzN9N3z/45w1pBUNBiPJdRQJ58MhBYQe
# Zl90heMBL8QNQk2i0E5gHNT9pJiCR9+mvJkRxEVgUn+16ZpVnI6kzhThV9qBaWVF
# h83X4UWc/nwHKIuu+4x4fmkYc79A3MrsHflZIO8jOy0GC/xBnZTQ8s5b9Tb2UkHk
# w692Ypl7War3W7M37JCAPC/A7M4CwQYjdjG43zs5m36auYVaTvRLKtZVLzcj8oZX
# 4vqhlZ8+jCPXFiuDfoBXiTckTLpv/eHQ6q7Aoda+qARWPPE1U2v5r/lpKVqIx7B4
# PdFZAUf5MtG/Bj7LVXvXjW8ABIJv7L4cI2akn6Es0dmvd6PsMYIZ6TCCGeUCAQEw
# fTBpMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNV
# BAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQgQ29kZSBTaWduaW5nIFJTQTQwOTYgU0hB
# Mzg0IDIwMjEgQ0ExAhAJvPMqSNxAYhV5FFpsbzOhMA0GCWCGSAFlAwQCAQUAoHww
# EAYKKwYBBAGCNwIBDDECMAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYK
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIO68wcOc
# 5mm1XkIckGUd0VpkKlr3gMGK3HErYqhBMhhLMA0GCSqGSIb3DQEBAQUABIIBgFgi
# X/ul1x7zOYnDwP5vSfdcgEZxhcNsHGfAqt8GWr7nhIA1PmeHlgnLrym7foZi7pZ2
# qhFM3HyH4FxI2W5jZIvhXpNmKB2Er5F++cemXm4j1TRLiOBYcwZNRgcE6ovdrg7f
# ZCSEEfpsqMA0mmBY6xIU2qv7u7XUuGcTYhQqqn1NIv43PNwj+NiO3Ziw7UaM4WW1
# znWEERxe+2jG3c/HjiJPaSjq9IOklpNfW/hrvCxynBRrMy0tDNjUHwl2fcSLsFs/
# 4XFv5Ju5qono3TVKV4NQ+ohuQ4/xdhqAdwUhBOwLKz9i/UtGjcbo5EfM8BmUh/HX
# UJnq6pEGVMlUpeJEjm6q94OplNTHdYqMtZr0Wbmjoj4rGP2Tc6oLd2Hiw6PtRJQr
# nnvHko56KtPxoZdt2+FNyqHcivPqu3RKeQE6WZRGT4zu0cE1Sx8uZdIn4VKaUn54
# fyrj501uD5DoR39M5KJMnuRoBurbD1P478a0VvHtREgrrBZeVmoRZ75QofBTc6GC
# Fz8wghc7BgorBgEEAYI3AwMBMYIXKzCCFycGCSqGSIb3DQEHAqCCFxgwghcUAgED
# MQ8wDQYJYIZIAWUDBAIBBQAwdwYLKoZIhvcNAQkQAQSgaARmMGQCAQEGCWCGSAGG
# /WwHATAxMA0GCWCGSAFlAwQCAQUABCDoqh7tTzlUxRfCYOKTPqtp/P65LPuLDa2v
# xaItJypEsQIQNGD+he5S/rUcvefHfc8M1xgPMjAyNDA4MjcxNjU1NTBaoIITCTCC
# BsIwggSqoAMCAQICEAVEr/OUnQg5pr/bP1/lYRYwDQYJKoZIhvcNAQELBQAwYzEL
# MAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJE
# aWdpQ2VydCBUcnVzdGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBD
# QTAeFw0yMzA3MTQwMDAwMDBaFw0zNDEwMTMyMzU5NTlaMEgxCzAJBgNVBAYTAlVT
# MRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjEgMB4GA1UEAxMXRGlnaUNlcnQgVGlt
# ZXN0YW1wIDIwMjMwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCjU0WH
# HYOOW6w+VLMj4M+f1+XS512hDgncL0ijl3o7Kpxn3GIVWMGpkxGnzaqyat0QKYoe
# YmNp01icNXG/OpfrlFCPHCDqx5o7L5Zm42nnaf5bw9YrIBzBl5S0pVCB8s/LB6Yw
# aMqDQtr8fwkklKSCGtpqutg7yl3eGRiF+0XqDWFsnf5xXsQGmjzwxS55DxtmUuPI
# 1j5f2kPThPXQx/ZILV5FdZZ1/t0QoRuDwbjmUpW1R9d4KTlr4HhZl+NEK0rVlc7v
# CBfqgmRN/yPjyobutKQhZHDr1eWg2mOzLukF7qr2JPUdvJscsrdf3/Dudn0xmWVH
# VZ1KJC+sK5e+n+T9e3M+Mu5SNPvUu+vUoCw0m+PebmQZBzcBkQ8ctVHNqkxmg4ho
# Yru8QRt4GW3k2Q/gWEH72LEs4VGvtK0VBhTqYggT02kefGRNnQ/fztFejKqrUBXJ
# s8q818Q7aESjpTtC/XN97t0K/3k0EH6mXApYTAA+hWl1x4Nk1nXNjxJ2VqUk+tfE
# ayG66B80mC866msBsPf7Kobse1I4qZgJoXGybHGvPrhvltXhEBP+YUcKjP7wtsfV
# x95sJPC/QoLKoHE9nJKTBLRpcCcNT7e1NtHJXwikcKPsCvERLmTgyyIryvEoEyFJ
# UX4GZtM7vvrrkTjYUQfKlLfiUKHzOtOKg8tAewIDAQABo4IBizCCAYcwDgYDVR0P
# AQH/BAQDAgeAMAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgw
# IAYDVR0gBBkwFzAIBgZngQwBBAIwCwYJYIZIAYb9bAcBMB8GA1UdIwQYMBaAFLoW
# 2W1NhS9zKXaaL3WMaiCPnshvMB0GA1UdDgQWBBSltu8T5+/N0GSh1VapZTGj3tXj
# STBaBgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGln
# aUNlcnRUcnVzdGVkRzRSU0E0MDk2U0hBMjU2VGltZVN0YW1waW5nQ0EuY3JsMIGQ
# BggrBgEFBQcBAQSBgzCBgDAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNl
# cnQuY29tMFgGCCsGAQUFBzAChkxodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20v
# RGlnaUNlcnRUcnVzdGVkRzRSU0E0MDk2U0hBMjU2VGltZVN0YW1waW5nQ0EuY3J0
# MA0GCSqGSIb3DQEBCwUAA4ICAQCBGtbeoKm1mBe8cI1PijxonNgl/8ss5M3qXSKS
# 7IwiAqm4z4Co2efjxe0mgopxLxjdTrbebNfhYJwr7e09SI64a7p8Xb3CYTdoSXej
# 65CqEtcnhfOOHpLawkA4n13IoC4leCWdKgV6hCmYtld5j9smViuw86e9NwzYmHZP
# VrlSwradOKmB521BXIxp0bkrxMZ7z5z6eOKTGnaiaXXTUOREEr4gDZ6pRND45Ul3
# CFohxbTPmJUaVLq5vMFpGbrPFvKDNzRusEEm3d5al08zjdSNd311RaGlWCZqA0Xe
# 2VC1UIyvVr1MxeFGxSjTredDAHDezJieGYkD6tSRN+9NUvPJYCHEVkft2hFLjDLD
# iOZY4rbbPvlfsELWj+MXkdGqwFXjhr+sJyxB0JozSqg21Llyln6XeThIX8rC3D0y
# 33XWNmdaifj2p8flTzU8AL2+nCpseQHc2kTmOt44OwdeOVj0fHMxVaCAEcsUDH6u
# vP6k63llqmjWIso765qCNVcoFstp8jKastLYOrixRoZruhf9xHdsFWyuq69zOuhJ
# RrfVf8y2OMDY7Bz1tqG4QyzfTkx9HmhwwHcK1ALgXGC7KP845VJa1qwXIiNO9OzT
# F/tQa/8Hdx9xl0RBybhG02wyfFgvZ0dl5Rtztpn5aywGRu9BHvDwX+Db2a2QgESv
# gBBBijCCBq4wggSWoAMCAQICEAc2N7ckVHzYR6z9KGYqXlswDQYJKoZIhvcNAQEL
# BQAwYjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UE
# CxMQd3d3LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBS
# b290IEc0MB4XDTIyMDMyMzAwMDAwMFoXDTM3MDMyMjIzNTk1OVowYzELMAkGA1UE
# BhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2Vy
# dCBUcnVzdGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQTCCAiIw
# DQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAMaGNQZJs8E9cklRVcclA8TykTep
# l1Gh1tKD0Z5Mom2gsMyD+Vr2EaFEFUJfpIjzaPp985yJC3+dH54PMx9QEwsmc5Zt
# +FeoAn39Q7SE2hHxc7Gz7iuAhIoiGN/r2j3EF3+rGSs+QtxnjupRPfDWVtTnKC3r
# 07G1decfBmWNlCnT2exp39mQh0YAe9tEQYncfGpXevA3eZ9drMvohGS0UvJ2R/dh
# gxndX7RUCyFobjchu0CsX7LeSn3O9TkSZ+8OpWNs5KbFHc02DVzV5huowWR0QKfA
# csW6Th+xtVhNef7Xj3OTrCw54qVI1vCwMROpVymWJy71h6aPTnYVVSZwmCZ/oBpH
# IEPjQ2OAe3VuJyWQmDo4EbP29p7mO1vsgd4iFNmCKseSv6De4z6ic/rnH1pslPJS
# lRErWHRAKKtzQ87fSqEcazjFKfPKqpZzQmiftkaznTqj1QPgv/CiPMpC3BhIfxQ0
# z9JMq++bPf4OuGQq+nUoJEHtQr8FnGZJUlD0UfM2SU2LINIsVzV5K6jzRWC8I41Y
# 99xh3pP+OcD5sjClTNfpmEpYPtMDiP6zj9NeS3YSUZPJjAw7W4oiqMEmCPkUEBID
# fV8ju2TjY+Cm4T72wnSyPx4JduyrXUZ14mCjWAkBKAAOhFTuzuldyF4wEr1GnrXT
# drnSDmuZDNIztM2xAgMBAAGjggFdMIIBWTASBgNVHRMBAf8ECDAGAQH/AgEAMB0G
# A1UdDgQWBBS6FtltTYUvcyl2mi91jGogj57IbzAfBgNVHSMEGDAWgBTs1+OC0nFd
# ZEzfLmc/57qYrhwPTzAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUH
# AwgwdwYIKwYBBQUHAQEEazBpMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdp
# Y2VydC5jb20wQQYIKwYBBQUHMAKGNWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNv
# bS9EaWdpQ2VydFRydXN0ZWRSb290RzQuY3J0MEMGA1UdHwQ8MDowOKA2oDSGMmh0
# dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRSb290RzQuY3Js
# MCAGA1UdIAQZMBcwCAYGZ4EMAQQCMAsGCWCGSAGG/WwHATANBgkqhkiG9w0BAQsF
# AAOCAgEAfVmOwJO2b5ipRCIBfmbW2CFC4bAYLhBNE88wU86/GPvHUF3iSyn7cIoN
# qilp/GnBzx0H6T5gyNgL5Vxb122H+oQgJTQxZ822EpZvxFBMYh0MCIKoFr2pVs8V
# c40BIiXOlWk/R3f7cnQU1/+rT4osequFzUNf7WC2qk+RZp4snuCKrOX9jLxkJods
# kr2dfNBwCnzvqLx1T7pa96kQsl3p/yhUifDVinF2ZdrM8HKjI/rAJ4JErpknG6sk
# HibBt94q6/aesXmZgaNWhqsKRcnfxI2g55j7+6adcq/Ex8HBanHZxhOACcS2n82H
# hyS7T6NJuXdmkfFynOlLAlKnN36TU6w7HQhJD5TNOXrd/yVjmScsPT9rp/Fmw0HN
# T7ZAmyEhQNC3EyTN3B14OuSereU0cZLXJmvkOHOrpgFPvT87eK1MrfvElXvtCl8z
# OYdBeHo46Zzh3SP9HSjTx/no8Zhf+yvYfvJGnXUsHicsJttvFXseGYs2uJPU5vIX
# mVnKcPA3v5gA3yAWTyf7YGcWoWa63VXAOimGsJigK+2VQbc61RWYMbRiCQ8KvYHZ
# E/6/pNHzV9m8BPqC3jLfBInwAM1dwvnQI38AC+R2AibZ8GV2QqYphwlHK+Z/GqSF
# D/yYlvZVVCsfgPrA8g4r5db7qS9EFUrnEw4d2zc4GqEr9u3WfPwwggWNMIIEdaAD
# AgECAhAOmxiO+dAt5+/bUOIIQBhaMA0GCSqGSIb3DQEBDAUAMGUxCzAJBgNVBAYT
# AlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2Vy
# dC5jb20xJDAiBgNVBAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0y
# MjA4MDEwMDAwMDBaFw0zMTExMDkyMzU5NTlaMGIxCzAJBgNVBAYTAlVTMRUwEwYD
# VQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAf
# BgNVBAMTGERpZ2lDZXJ0IFRydXN0ZWQgUm9vdCBHNDCCAiIwDQYJKoZIhvcNAQEB
# BQADggIPADCCAgoCggIBAL/mkHNo3rvkXUo8MCIwaTPswqclLskhPfKK2FnC4Smn
# PVirdprNrnsbhA3EMB/zG6Q4FutWxpdtHauyefLKEdLkX9YFPFIPUh/GnhWlfr6f
# qVcWWVVyr2iTcMKyunWZanMylNEQRBAu34LzB4TmdDttceItDBvuINXJIB1jKS3O
# 7F5OyJP4IWGbNOsFxl7sWxq868nPzaw0QF+xembud8hIqGZXV59UWI4MK7dPpzDZ
# Vu7Ke13jrclPXuU15zHL2pNe3I6PgNq2kZhAkHnDeMe2scS1ahg4AxCN2NQ3pC4F
# fYj1gj4QkXCrVYJBMtfbBHMqbpEBfCFM1LyuGwN1XXhm2ToxRJozQL8I11pJpMLm
# qaBn3aQnvKFPObURWBf3JFxGj2T3wWmIdph2PVldQnaHiZdpekjw4KISG2aadMre
# Sx7nDmOu5tTvkpI6nj3cAORFJYm2mkQZK37AlLTSYW3rM9nF30sEAMx9HJXDj/ch
# srIRt7t/8tWMcCxBYKqxYxhElRp2Yn72gLD76GSmM9GJB+G9t+ZDpBi4pncB4Q+U
# DCEdslQpJYls5Q5SUUd0viastkF13nqsX40/ybzTQRESW+UQUOsxxcpyFiIJ33xM
# dT9j7CFfxCBRa2+xq4aLT8LWRV+dIPyhHsXAj6KxfgommfXkaS+YHS312amyHeUb
# AgMBAAGjggE6MIIBNjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTs1+OC0nFd
# ZEzfLmc/57qYrhwPTzAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzAO
# BgNVHQ8BAf8EBAMCAYYweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRw
# Oi8vb2NzcC5kaWdpY2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRz
# LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwRQYDVR0f
# BD4wPDA6oDigNoY0aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNz
# dXJlZElEUm9vdENBLmNybDARBgNVHSAECjAIMAYGBFUdIAAwDQYJKoZIhvcNAQEM
# BQADggEBAHCgv0NcVec4X6CjdBs9thbX979XB72arKGHLOyFXqkauyL4hxppVCLt
# pIh3bb0aFPQTSnovLbc47/T/gLn4offyct4kvFIDyE7QKt76LVbP+fT3rDB6mouy
# XtTP0UNEm0Mh65ZyoUi0mcudT6cGAxN3J0TU53/oWajwvy8LpunyNDzs9wPHh6jS
# TEAZNUZqaVSwuKFWjuyk1T3osdz9HNj0d1pcVIxv76FQPfx2CWiEn2/K2yCNNWAc
# AgPLILCsWKAOQGPFmCLBsln1VWvPJ6tsds5vIy30fnFqI2si/xK4VC0nftg62fC2
# h5b9W9FcrBjDTZ9ztwGpn1eqXijiuZQxggN2MIIDcgIBATB3MGMxCzAJBgNVBAYT
# AlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMyRGlnaUNlcnQg
# VHJ1c3RlZCBHNCBSU0E0MDk2IFNIQTI1NiBUaW1lU3RhbXBpbmcgQ0ECEAVEr/OU
# nQg5pr/bP1/lYRYwDQYJYIZIAWUDBAIBBQCggdEwGgYJKoZIhvcNAQkDMQ0GCyqG
# SIb3DQEJEAEEMBwGCSqGSIb3DQEJBTEPFw0yNDA4MjcxNjU1NTBaMCsGCyqGSIb3
# DQEJEAIMMRwwGjAYMBYEFGbwKzLCwskPgl3OqorJxk8ZnM9AMC8GCSqGSIb3DQEJ
# BDEiBCAzrfV8jZNWVnF4Gpv09zP90HTDZS4zix5u7Qc4gWw6yTA3BgsqhkiG9w0B
# CRACLzEoMCYwJDAiBCDS9uRt7XQizNHUQFdoQTZvgoraVZquMxavTRqa1Ax4KDAN
# BgkqhkiG9w0BAQEFAASCAgAFSJrobe1Kf45znH1mIsmk6RGg5rTDz2WmpZb1SnT+
# QSqdZXDnnL7iBYSWbFeN0ZAy0MQyHi2lchu9o/pR99OBNfN0Sfjhbw6lEM5GaQAD
# 6LsXszY16QGYx55zKnDz+h4H5oOG+Vp+XANLz0BXAzRVN8I9ChzSdSC9tNub62BH
# 5PRssGEh1WX5f0xzZxnokFd44W0oolJ/+iXKssmG89eKU2EqnuDrU6PSCVYdNvgZ
# 62uwhGS5cLTMiNlXEUjq7uLgiHiVJNYEDUD5Q6xaUVgn6Fbst3IFfq0PFk/Iikx/
# JBTGmt5/hCyG93IgSjsX7i7fN9vscm5XHVcPs1T3i3WDY6MLvtWoTGEaLq0In15o
# 9QNZlmg12F2aLxj0KUv9jN8g6MW2OFsunSdN/CSckAZWkFaRZfjhtkPXTL9XEMrZ
# fUkjz4E3GmfGzckaElmP/34Fbfei267YVkQN6qKQ6eWgihLV4KYWVuYg4WQ21WkS
# fYc1AVIc5dA2XD1pvDyMcUBCA8Yk+oFrx4PiS0EcMV8ju+CvFe4hfq5ejeudByKV
# z5lWcDMIi2nYWi/BoH8+/VY1bKpqDwgfqPwhGjldCJohGfA67Q+Nm6lBRgRHquq2
# /owz3mVqzixw1pf/A8QGowylvSd9cqzCXUrLoIDicdAbtqwDzmX2eJFcWPRkr3FV
# Yw==
# SIG # End signature block
