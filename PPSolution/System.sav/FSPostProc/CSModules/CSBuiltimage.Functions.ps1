Add-Type -AssemblyName System.Windows.Forms

<#
Get-CVAObject return follow properties (when exist):
.Name
    Name of CVA
.Path
    Where is located CVA, path
.Title
    Title of software in en-US
.Version
    Vendor version 
.PN
    Part Number
.Vendor
    Vendor name
.Type
    Type of software
.Category
    Category of software
.Silent
    Silent command
.SilentFile
    Cleanup silent command extracting just file
.SilentParameters
    Cleanup silent command extracting only parameters
.SysIds
    Array list of all sysids supported
.Platforms
    Dictionary with SysID = Supported Platforms names separated by coma
.PassCodes
    Array list of all codes marked as SUCCESS
.ReturnCode
    Array with full string from CVA per code 
.Valid
    boolean to define if CVA can be used, it is expected to be found on sam level as silent executable file
.Length
    Int with length of path where CVA is located
#>
function Get-CVAObject { 
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$PathFile
    )
    
    try {
        if (Test-Path -Path $PathFile -PathType Leaf) {
            #Write-Host "Extract information from $($PathFile)"
            WriteLog -Message "`tExtracting information from $($PathFile)" -Verbose
            if ($null -ne (Get-Variable -Name File -ErrorAction SilentlyContinue)) { Remove-Variable -Name File -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name Path -ErrorAction SilentlyContinue)) { Remove-Variable -Name Path -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name retObj -ErrorAction SilentlyContinue)) { Remove-Variable -Name retObj -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name GetCVA -ErrorAction SilentlyContinue)) { Remove-Variable -Name GetCVA -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name Title -ErrorAction SilentlyContinue)) { Remove-Variable -Name Title -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name Version -ErrorAction SilentlyContinue)) { Remove-Variable -Name Version -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name Vendor -ErrorAction SilentlyContinue)) { Remove-Variable -Name Vendor -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name Type -ErrorAction SilentlyContinue)) { Remove-Variable -Name Type -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name Category -ErrorAction SilentlyContinue)) { Remove-Variable -Name Category -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name Silent -ErrorAction SilentlyContinue)) { Remove-Variable -Name Silent -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name objResult -ErrorAction SilentlyContinue)) { Remove-Variable -Name objResult -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name sub -ErrorAction SilentlyContinue)) { Remove-Variable -Name sub -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name sub2 -ErrorAction SilentlyContinue)) { Remove-Variable -Name sub2 -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name sub3 -ErrorAction SilentlyContinue)) { Remove-Variable -Name sub3 -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name rem -ErrorAction SilentlyContinue)) { Remove-Variable -Name rem -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name exefile -ErrorAction SilentlyContinue)) { Remove-Variable -Name exefile -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name flagread -ErrorAction SilentlyContinue)) { Remove-Variable -Name flagread -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name AllSysIDs -ErrorAction SilentlyContinue)) { Remove-Variable -Name AllSysIDs -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name SysID -ErrorAction SilentlyContinue)) { Remove-Variable -Name SysID -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name AllPass -ErrorAction SilentlyContinue)) { Remove-Variable -Name AllPass -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name ReturnCode -ErrorAction SilentlyContinue)) { Remove-Variable -Name ReturnCode -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name code -ErrorAction SilentlyContinue)) { Remove-Variable -Name code -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name PN -ErrorAction SilentlyContinue)) { Remove-Variable -Name PN -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name Platforms -ErrorAction SilentlyContinue)) { Remove-Variable -Name Platforms -Force -ErrorAction SilentlyContinue }
            if ($null -ne (Get-Variable -Name Devices -ErrorAction SilentlyContinue)) { Remove-Variable -Name Devices -Force -ErrorAction SilentlyContinue }
            $File = (Split-Path $PathFile -Leaf)
            $Path = (Split-Path $PathFile -Parent)
            $retObj = New-Object PSObject
            $retObj | Add-Member NoteProperty Name $File
            $retObj | Add-Member NoteProperty Path $Path
            $retObj | Add-Member NoteProperty Length $Path.Length
            $GetCVA = Get-Content $PathFile -Encoding Ascii
            
            if (($null -ne ($GetCVA | Select-String -Pattern "Software Title")) -AND (($GetCVA | Select-String -Pattern "Software Title").line.Trim().StartsWith('['))) {
                if ($null -ne ($GetCVA | Select-String -Pattern "US=")) {
                    $Title = (($GetCVA | Select-String -Pattern "US=")[0].Line).Split("=")[1].Trim()
                    $retObj | Add-Member Noteproperty Title $Title
                }
                else {
                    WriteLog -Message "`tTitle doesn't exist" -MessageType Error -Verbose
                }
            }
            else {
                #Write-Host "Software Title section doesn't exist"
                WriteLog -Message "`tSoftware Title section doesn't exist" -MessageType Error -Verbose
            }

                        
            if (($null -ne ($GetCVA | Select-String -Pattern "General")) -AND (($GetCVA | Select-String -Pattern "General").line.Trim().StartsWith('['))) {
                if ($null -ne ($GetCVA | Select-String -Pattern "VendorVersion=")) {
                    foreach ($ln in ($GetCVA | Select-String -Pattern "VendorVersion=")) {
                        if ($ln.Line.Trim().StartsWith("VendorVersion=")) {
                            $Version = ($ln.Line).Split("=")[1].Trim()
                        }
                    }
                    
                    if ([string]::IsNullOrEmpty($Version)) {
                        foreach ($line in ($GetCVA | Select-String -Pattern "Version=")) {
                            if ($line.Line.StartsWith("Version=")) {
                                $Version = $line.Line.Split("=")[1].Trim()
                            }
                        }
                        #$Version=(($GetCVA | Select-String -Pattern "Version=")[0].Line).Split("=")[1].Trim()
                        if ([string]::IsNullOrEmpty($Version)) { 
                            WriteLog -Message "`tVersion doesn't exist" -MessageType Warning -Verbose 
                            $retObj | Add-Member Noteproperty Version "0.0.0"
                        }
                        else {
                            $retObj | Add-Member Noteproperty Version $Version
                        }
                    }
                    else {
                        $retObj | Add-Member Noteproperty Version $Version
                    }
                    
                }
                else {
                    WriteLog -Message "`tVersion doesn't exist" -MessageType Warning -Verbose
                }
                #<<<<---- PN
                if ($null -ne ($GetCVA | Select-String -Pattern "PN=")) {
                    foreach ($ln in ($GetCVA | Select-String -Pattern "PN=")) {
                        if ($ln.Line.Trim().StartsWith("PN=")) {
                            $PN = ($ln.Line).Split("=")[1].Trim()
                        }
                    }
                    if (($PN -eq "000000-000") -OR ($PN -eq "")) {
                        if ($null -ne ($GetCVA | Select-String -Pattern "SoftpaqNumber=")) {
                            foreach ($ln in ($GetCVA | Select-String -Pattern "SoftpaqNumber=")) {
                                if ($ln.Line.Trim().StartsWith("SoftpaqNumber=")) {
                                    $PN = ($ln.Line).Split("=")[1].Trim()
                                }
                            }
                        }
                    }
                    $retObj | Add-Member Noteproperty PN $PN
                    
                }
                else {
                    WriteLog -Message "`tPN doesn't exist" -MessageType Warning -Verbose
                    $PN = "000000-000"
                    if ($null -ne ($GetCVA | Select-String -Pattern "SoftpaqNumber=")) {
                        foreach ($ln in ($GetCVA | Select-String -Pattern "SoftpaqNumber=")) {
                            if ($ln.Line.Trim().StartsWith("SoftpaqNumber=")) {
                                WriteLog -Message "`ttrying to use SoftpaqNumber" -MessageType Warning -Verbose
                                $PN = ($ln.Line).Split("=")[1].Trim()
                            }
                        }
                    }
                    $retObj | Add-Member Noteproperty PN $PN
                }
                #<<<---- VendorName
                if ($null -ne ($GetCVA | Select-String -Pattern "VendorName=")) {
                    $Vendor = (($GetCVA | Select-String -Pattern "VendorName=")[0].Line).Split("=")[1].Trim()
                    $retObj | Add-Member Noteproperty Vendor $Vendor
                }
                else {
                    WriteLog -Message "`tVendor doesn't exist" -MessageType Warning -Verbose
                }
                if ($null -ne ($GetCVA | Select-String -Pattern "Type=")) {
                    $Type = (($GetCVA | Select-String -Pattern "Type=")[0].Line).Split("=")[1].Trim()
                    $retObj | Add-Member Noteproperty Type $Type
                }
                else {
                    WriteLog -Message "`tType doesn't exist" -MessageType Warning -Verbose
                }
                if ($null -ne ($GetCVA | Select-String -Pattern "Category=")) {
                    $Category = (($GetCVA | Select-String -Pattern "Category=")[0].Line).Split("=")[1].Trim()
                    $retObj | Add-Member Noteproperty Category $Category
                }
                else {
                    WriteLog -Message "`tCategory doesn't exist" -MessageType Warning -Verbose
                }                
            }
            else {
                #Write-Host "General section doesn't exist"
                WriteLog -Message "`tGeneral section doesn't exist" -MessageType Warning -Verbose
            }
            
            if (($null -ne ($GetCVA | Select-String -Pattern "Install Execution")) -AND (($GetCVA | Select-String -Pattern "Install Execution").line.Trim().StartsWith('['))) {
                if ($null -ne ($GetCVA | Select-String -Pattern "SilentInstall=")) {
                    $Silent = (($GetCVA | Select-String -Pattern "SilentInstall=")[0].Line).Replace("$((($GetCVA | Select-String -Pattern "SilentInstall=")[0].Line).Split("=")[0])=", "").Trim()
                    $retObj | Add-Member Noteproperty Silent $Silent
                    #Clean Command to just call 
                    $objResult = @{}
                    foreach ($line in ($GetCVA | Select-String -Pattern "SilentInstall=")) {
                        if ($line.Line.ToString().Trim().StartsWith("SilentInstall")) {
                            $objResult.read = $line.Line.ToString().Trim().Substring(14, ($line.Line.ToString().Trim().Length - 14))
                        }
                    }
                    if (($null -eq $objResult.read) -OR ($objResult.read.ToLower() -eq "n/a")) {
                        WriteLog -Message "Not valid Silent command" -MessageType Warning -Verbose
                        $sub2 = "notfoundsilent.exe"
                        $sub3 = ""
                    }
                    else {
                        if ($objResult.read.StartsWith("""")) {
                            $sub = $objResult.read.Substring(1, $objResult.read.Length - 1)
                            $rem = $sub.indexOf("""")
                            $sub2 = $sub.Substring(0, $rem)
                            if ($sub.length -gt $rem + 1) {
                                $sub3 = $sub.Substring($rem + 1, ($sub.Length - $sub2.Length - 1))  
                            }
                            else {
                                $sub3 = ""
                            }                        
                        }
                        else {
                            if ($objResult.read.Trim().IndexOf(" ") -gt 0) {
                                $sub2 = $objResult.read.Split(" ")[0]
                                $sub3 = $objResult.read.Replace($sub2, "").Trim()
                            }
                            else {
                                $sub2 = $objResult.read.Trim()
                                $sub3 = ""
                            }                        
                        }
                    }                    
                    $objResult.file = $sub2
                    $objResult.parameters = $sub3
                    $objResult.silent = $sub2 + $sub3
                    $retObj | Add-Member Noteproperty SilentFile $objResult.file
                    $retObj | Add-Member Noteproperty SilentParameters $objResult.parameters
                }
                else { WriteLog -Message "`tSilent Install doesn't exist" -MessageType Warning -Verbose }
            }
            else {
                #Write-Host "Install Execution section doesn't exist"
                WriteLog -Message "`tInstall Execution section doesn't exist" -MessageType Warning -Verbose
            }
            ### Based on silent comannd define if CVA is valid, file mentioned should be present or command should be valid
            #N/A is not a valid command
            #use msiexec is valid
            if ($null -ne $retObj.Silent) {
                #Value for SilentInstall was detected
                if ($retObj.Silent.ToLower() -eq "n/a") {
                    $retObj | Add-Member Noteproperty Valid $false
                }
                else {
                    #Detect executable file
                    if ($retObj.Silent.StartsWith("""")) {
                        $sub = $retObj.Silent.Substring(1, $retObj.Silent.Length - 1)
                        $rem = $sub.indexOf("""")
                        $sub2 = $sub.Substring(0, $rem)
                        if ($sub.length -gt $rem + 1) {
                            $sub3 = $sub.Substring($rem + 1, ($sub.Length - $sub2.Length - 1))  
                        }
                        else {
                            $sub3 = ""
                        }                        
                    }
                    else {
                        if ($retObj.Silent.Trim().IndexOf(" ") -gt 0) {
                            $sub2 = $retObj.Silent.Split(" ")[0]
                            $sub3 = $retObj.Silent.Replace($sub2, "").Trim()
                        }
                        else {
                            $sub2 = $retObj.Silent.Trim()
                            $sub3 = ""
                        }                        
                    }
                    $exefile = $sub2
                    $null = $sub3
                    #msiexec is valid executable, more executables need to be added
                    if ($exefile.ToLower().StartsWith("msiexec")) {
                        $retObj | Add-Member Noteproperty Valid $true
                    }
                    elseif (Test-Path -Path (Join-Path $retObj.Path $exefile) -PathType Leaf) {
                        $retObj | Add-Member Noteproperty Valid $true
                    }
                    else {
                        $retObj | Add-Member Noteproperty Valid $false
                    }
                }
            }
            
            if (($null -ne ($GetCVA | Select-String -Pattern "System Information")) -AND (($GetCVA | Select-String -Pattern "System Information").line.Trim().StartsWith('['))) {
                $flagread = $false
                $AllSysIDs = [System.Collections.ArrayList]@()
                $AllPlatformsbyID = New-Object  System.Collections.Generic.Dictionary"[string,string]"
                foreach ($cvaline in $GetCVA) {
                    if ($flagread) {
                        #reading line by line
                        if (($cvaline.Trim().Length -eq 0) -OR ($cvaline.StartsWith("["))) { 
                            $flagread = $false
                        }
                        else {
                            if ($cvaline.StartsWith("SysId")) {
                                $SysID = $cvaline.Split("=")[1].Replace("0x", "")
                                [void]$AllSysIDs.Add($SysID)
                            }
                            if ($cvaline.StartsWith("SysName")) {
                                $numbgroup = $cvaline.Split("=")[0].Replace("SysName", "")
                                $Id = ($GetCVA | Select-String -Pattern "SysId$($numbgroup)")[0].Line.Split("=")[1].Replace("0x", "")
                                $Plats = $cvaline.Split("=")[1].Trim()
                                $AllPlatformsbyID.Add($Id, $Plats)                                
                            }
                        }
                    }
                    else {
                        if ($cvaline.Contains("System Information")) { $flagread = $true }
                    }

                }
                $retObj | Add-Member Noteproperty SysIds $AllSysIDs
                $retObj | Add-Member Noteproperty Platforms $AllPlatformsbyID
                if ($AllSysIDs.Count -eq 0) {
                    WriteLog -Message "`tSystem IDs missing" -MessageType Warning -Verbose
                }           
            }
            else {
                #Write-Host "System Information section doesn't exist"
                WriteLog -Message "`tSystem Information section doesn't exist" -MessageType Warning -Verbose
            }

            #Check for Device HW 
            if (($null -ne ($GetCVA | Select-String -Pattern "Devices")) -AND (($GetCVA | Select-String -Pattern "Devices").line.Trim().StartsWith('['))) {
                $flagread = $false
                $AllDevicesID = [System.Collections.ArrayList]@()
                $AllDevicesNamebyID = New-Object  System.Collections.Generic.Dictionary"[string,string]"
                foreach ($cvaline in $GetCVA) {
                    if ($flagread) {
                        #reading line by line
                        if (($cvaline.Trim().Length -eq 0) -OR ($cvaline.StartsWith("["))) { 
                            $flagread = $false
                        }
                        else {
                            if ($cvaline.Contains("=")) {
                                $hwID = $cvaline.Split("=")[0]
                                $hwName = $cvaline.Split("=")[1].Replace("""", "")
                                [void]$AllDevicesID.Add($hwID)
                                $AllDevicesNamebyID.Add($hwID, $hwName) 
                            }
                        }
                    }
                    else {
                        if ($cvaline.Contains("[Devices]")) { $flagread = $true }
                    }

                }
                $retObj | Add-Member Noteproperty HWId $AllDevicesID
                $retObj | Add-Member Noteproperty HWName $AllDevicesNamebyID
                if ($AllSysIDs.Count -eq 0) {
                    WriteLog -Message "`tHardware IDs missing" -MessageType Warning -Verbose
                }           
            }
            else {
                #Write-Host "System Information section doesn't exist"
                WriteLog -Message "`tDevices section doesn't exist" -MessageType Warning -Verbose
            }

            $AllPass = [System.Collections.ArrayList]@()
            $ReturnCode = [System.Collections.ArrayList]@()
            if (($null -ne ($GetCVA | Select-String -Pattern "ReturnCode")) -AND (($GetCVA | Select-String -Pattern "ReturnCode").line.Trim().StartsWith('['))) {
                $flagread = $false                
                foreach ($cvaline in $GetCVA) {
                    if ($flagread) {
                        #reading line by line
                        if (($cvaline.Trim().Length -eq 0) -OR ($cvaline.StartsWith("["))) { 
                            $flagread = $false
                        }
                        else {
                            if ($cvaline.Contains(":")) {
                                [void]$ReturnCode.Add($cvaline)
                                if ($cvaline.Split(":")[1] -like "SUCCESS") {
                                    try {
                                        [int]$code = $cvaline.Split(":")[0]
                                        [void]$AllPass.Add($code)
                                    }
                                    catch {
                                        #Write-Host "[ERROR] Parsing $($cvaline.Split(':')[0]) -> INT Message: $($_.Exception.Message)"
                                        WriteLog -Message "`t[ERROR] Parsing $($cvaline.Split(':')[0]) -> INT Message: $($_.Exception.Message)" -MessageType Error -Verbose
                                    } 
                                }                                
                            }
                        }
                    }
                    else {
                        if ($cvaline -contains "[ReturnCode]") { $flagread = $true }
                    }

                }
            }
            else {
                #Write-Host "ReturnCode doesn't exist, using defaults 0 and 3010"
                WriteLog -Message "`tReturnCode doesn't exist, using defaults 0 and 3010" -MessageType Warning -Verbose
                [void]$AllPass.Add(0)
                [void]$ReturnCode.Add("0:SUCCESS:NOREBOOT=The action completed successfully.")
                [void]$AllPass.Add(3010)
                [void]$ReturnCode.Add("3010:SUCCESS:REBOOT=A restart is required to complete the install. This message is indicative of a success.")
            }
            if (-Not($AllPass.Contains(0))) { 
                #Write-Host "Universal code 0 is mandatory, adding"
                WriteLog -Message "`tUniversal code 0 is mandatory, adding" -MessageType Warning -Verbose
                [void]$AllPass.Add(0)
                [void]$ReturnCode.Add("0:SUCCESS:NOREBOOT=The action completed successfully.")
            }
            if ($AllPass.Count -gt 0) {
                $retObj | Add-Member Noteproperty PassCodes $AllPass
                $retObj | Add-Member NoteProperty ReturnCode $ReturnCode
            }
            else {
                WriteLog -Message "`tReturnCode doesn't detected, using defaults 0 and 3010" -MessageType Warning -Verbose
                [void]$AllPass.Add(0)
                [void]$ReturnCode.Add("0:SUCCESS:NOREBOOT=The action completed successfully.")
                [void]$AllPass.Add(3010)
                [void]$ReturnCode.Add("3010:SUCCESS:REBOOT=A restart is required to complete the install. This message is indicative of a success.")
                $retObj | Add-Member Noteproperty PassCodes $AllPass
                $retObj | Add-Member Noteproperty ReturnCode $ReturnCode
            }
            
            ##########################################
            ######<---Return object pupulated#########
            ##########################################
            return $retObj

        }
        else {
            #Write-Error "File $($PathFile) doesn't exist"
            WriteLog -Message "`tFile $($PathFile) doesn't exist" -MessageType Error -Verbose
            return $null
        }

    }
    catch {
        $ErrorMessage = $_.Exception.Message
        Write-Host "Failed: $($ErrorMessage)" -ForegroundColor Red -BackgroundColor Black
        return $null
    } #End of Try   
}


function Get-InternetAccess {
    $timer = 0
    $isUp = $false
    $maxout = 10
    While (!($isUp)) {
        $AdaptersUp = Get-NetAdapter | Where-Object Status -eq "Up"
        if ($null -eq $AdaptersUp) {
            $timer++;
            Write-Host "There aren't Network Adapters active... [$($timer)/$($maxout)]"
            Start-Sleep -Seconds 10
            if ($timer -ge $maxout) {
                Write-Host "[ERROR] Not possible detect Network adapter with connection"
                return $false
            }
        }
        else {
            Write-Host "At least one Network adapter was detectect with network access" -Verbose
            ForEach ($UpAda in $AdaptersUp) {
                $Inter = $null
                $inter = Get-NetRoute | Where-Object DestinationPrefix -eq '0.0.0.0/0' | Get-NetIPInterface | Where-Object { $_.ConnectionState -eq 'Connected' -AND $_.ifIndex -eq $UpAda.ifIndex }
                if ($null -ne $inter) {	Write-Host "Adapter [$($UpAda.Name)] has network access"; } else { Write-Host "Adapter [$($UpAda.Name)] can't reach network yet"; }
            }
            $isUp = $true
        }
    }
    $ReachDNS = $false
    $timer = 0;
    $DNSname = "hp.com"
    While (!($ReachDNS)) {
        $HasConnection = $null
        try {
            Resolve-DnsName -Name $DNSname -Type A -ErrorAction SilentlyContinue | ForEach-Object { 
                if (Test-Connection -ComputerName $_.IPAddress -Quiet -Count 5) { 
                    $HasConnection = $true; break; $HasConnection | Out-Null; 
                } 
            }
        }
        catch {
            $ErrorMessage = $_.Exception.Message                
            [string]$ExceptionText = ($_ | Out-String).Trim()
            Write-Host "[ERROR] exception detected, script $($MyInvocation.MyCommand.Name): $($ErrorMessage)"
            Write-Host "[ERROR TEXT]: $($ExceptionText)"
            $DNSname = "github.com"
            $HasConnection = $null
        }
        if (($null -eq $HasConnection) -OR !($HasConnection)) {
            $timer++;
            Write-Host "It cannot reach DNS [$($DNSname)], no internet access detected... [$($timer)/$($maxout)]"
            Start-Sleep -Seconds 5	
            if ($timer -eq ([math]::Round($maxout / 2))) {
                Write-Host "No possible detect internet access, try with different configuration"
                $DNSname = "google.com"  
            }
            if ($timer -ge $maxout) {
                Write-Host "[ERROR] Not possible detect Internet access"
                return $false
            }    
        }
        else {
            Write-Host "Reacheable [$($DNSname)], There are Internet access, continue" -Verbose
            $ReachDNS = $true
        }
    }
    return $true  
}
<#Table of codes expected by Windows Setup
Return code	        Description
0                   The command was successful. No reboot is required.
1                   The command was successful. An immediate reboot is required. Then, the next command can be started.
2                   The command is still in process. An immediate reboot is required. Then, the same command must be restarted. This code can be returned multiple times.
Other codes         The command failed. An error must be returned and installation terminated.
#>
function Exit-WithCode($exitcode) {
    Write-Host "`t <------------- Clossing trascript, exit code: [$($exitcode)]"
    $WindowsSetupCode = [int]$exitcode
    try {
        switch ([int]$exitcode) {
            { ($_ -ne 0) -AND ($_ -ne 25031981) } { 
                Write-Host "Code $($exitcode) require reboot unit";
                Write-Host "========================= REBOOT UNIT =========================";
                Write-Host "========================= ^^^^^^^^^^^ =========================";
                #Translate result for trigger reboot
                $WindowsSetupCode = 1;
                break;
            }
            2 {
                Write-Host "Code $($exitcode) used to reboot unit and try again";
                Write-Host "==================== REBOOT/RETRY SETUP ======================";
                Write-Host "========================= ^^^^^^^^^^ =========================";
                #Translate result for trigger reboot and retry
                $WindowsSetupCode = 2;
                break;
            }
            25031981 {
                Write-Host "Code $($exitcode) is an especial code to mark postprocessing for debug and Windows Setup prevent continue";
                Write-Host "========================= STOP SETUP =========================";
                Write-Host "========================= ^^^^^^^^^^ =========================";
                #Translate result for trigger reboot
                $WindowsSetupCode = 25031981;
                break;
            }
            Default {
                Write-Host Write-Host "========================= CONTINUE PROCESS =========================";
                Write-Host Write-Host "========================= ^^^^^^^^^^^^^^^^ =========================";
                $WindowsSetupCode = [int]$exitcode;
                break;
            }
        }
        Write-Host "Windows Setup return Code: $($WindowsSetupCode)"
        Stop-Transcript -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning ">>not transcription running<<"
    }
    $host.SetShouldExit($WindowsSetupCode)
    exit $WindowsSetupCode
}
function Exit-PostProcessing {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [int] $ExitScriptCode
    )
    try {
        WriteLog -Message "----------------------------- CLOSE POST-PROCESSING --------------------------" -Verbose
        WriteLog -Message "           Exit Code: $($ExitScriptCode)" -Verbose        
        $nonfactflag = (Join-Path $Env:SystemDrive "\System.sav\flags\CSCustMode.flg")
        $failureflag = (Join-Path $Env:SystemDrive "\system.sav\flags\FAILURE.FLG")
        $errorflag = (Join-Path $Env:SystemDrive "\System.sav\flags\cserror.flg")
        #Remove previous logs
        $CheckPreviousLogs = Get-ChildItem -Path $Env:SystemDrive -Filter "*_system.sav.7z"
        if ($null -ne $CheckPreviousLogs) {
            foreach ($SevenZ in $CheckPreviousLogs) {
                Remove-Item -Path $SevenZ.FullName -Force
            }
        }
        #Create error flag for none 0, 3010 and 25031981
        switch ($ExitScriptCode) {
            0 { $ExitDefinition = "Step complete sucessfully"; break; }
            2 { $ExitDefinition = "Step complete but need execute again after unit reboot"; break; }
            3010 { $ExitDefinition = "Step requires a reboot to complete"; break; }
            25031981 { $ExitDefinition = "Step requires to mark Windows setup as error"; break; }
            Default { 
                $ExitDefinition = "Step has an error, debug is allowed on next reboot"; 
                "Error code: $($ExitScriptCode)" | Out-File -FilePath $errorflag -Encoding ascii -Force; 
                break;
            }
        }
        WriteLog -Message "        Exit Deteted: $($ExitDefinition)" -Verbose
        #capture logs are not required when receive a 3010
        if (($ExitScriptCode -ne 3010) -AND ($ExitScriptCode -ne 0) -AND ($ExitScriptCode -ne 2)) {
            WriteLog -Message "Capturing logs..." -Verbose
            $WhereLogs = $null
            Start-Process -FilePath "cmd.exe" -ArgumentList "/c $($Env:SystemDrive)\system.sav\logs\CaptureLogs\CaptureLogs.cmd $($Env:SystemDrive) $($Env:SystemDrive)" -WorkingDirectory "$($Env:SystemDrive)\system.sav\logs\CaptureLogs" -NoNewWindow -Wait -PassThru | Out-Host
            $CheckLogs = Get-ChildItem -Path "$($Env:SystemDrive)\" -Filter "*_system.sav.7z" -ErrorAction SilentlyContinue
            if ($null -eq $CheckLogs) { Write-Error "Not possible detect logs on root"; exit 999; }
            $WhereLogs = $CheckLogs[0].FullName
            Write-Host "Moving logs for WDT"
            if (Test-Path (Join-Path $Env:SystemDrive "\system.sav\WDT")) {                
                if ($null -ne $CheckLogs) {
                    if (-Not(Test-Path -Path "$($Env:SystemDrive)\system.sav\WDT\Logs")) { New-Item -Path "$($Env:SystemDrive)\system.sav\WDT\Logs" -ItemType Directory -Force; }
                    foreach ($SevenZ in $CheckLogs) {
                        Move-Item -Path $SevenZ.FullName -Destination "$($Env:SystemDrive)\system.sav\WDT\Logs\system.sav.7z" -Force
                        $WhereLogs = "$($Env:SystemDrive)\system.sav\WDT\Logs\system.sav.7z"
                    }
                }
            }
            
            $GetErrortxt = Get-ChildItem -Path (Join-Path $Env:SystemDrive "System.sav") -Filter "error.txt" -Recurse
            if ($null -ne $GetErrortxt) {
                Write-Host "error.txt can be found at $($GetErrortxt[0].FullName)"
                $WhereLogs | Out-File -FilePath $GetErrortxt[0].FullName -Append -Force
                if (Test-Path (Join-Path $Env:SystemDrive "\System.sav\WDT")) { 
                    Write-Host "WDT folder detected moving file"
                    Copy-Item -Path $GetErrortxt[0].FullName -Destination (Join-Path $Env:SystemDrive "\System.sav\WDT\error.txt") -Force
                }                
            }
            else {
                Write-Host "error.txt can't be found, creating file"
                if (Test-Path (Join-Path $Env:SystemDrive "\System.sav\WDT")) {
                    Write-Host "WDT folder detected moving file"
                    $WhereLogs | Out-File -FilePath (Join-Path $Env:SystemDrive "\System.sav\WDT\error.txt") -Encoding ascii -Force
                }
            }
            $callPath = (Get-Item -Path '.\' -Verbose).FullName
            Write-Host "Current path: $($callPath)"            
            
            if (Test-Path -Path $nonfactflag) {
                $RegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
                $RegName = "FSAuditModeFailure"
                $RegValue = "cmd.exe /c start /Min $($Env:SystemDrive)\System.sav\WDT\CustomOSchange.exe /SHOW"
                if (-Not(Test-Path $RegPath)) { New-Item -Path $RegPath -ItemType Directory -Force }
                New-ItemProperty -Path $RegPath -Name $RegName -Value $RegValue -PropertyType String -Force
                Start-Process -FilePath "cmd.exe" -ArgumentList "/c start /min $($Env:SystemDrive)\System.sav\WDT\CustomOSchange.exe /SHOW" -WindowStyle Hidden -WorkingDirectory "$($Env:SystemDrive)\System.sav\WDT"
            }

        }
        <#NEED TO IMPROVE CLEAN ON ERROR, NOT ON SUCESS        
        if (($ExitScriptCode -eq 0) -AND (-Not(Test-Path $failureflag))){
            Remove-Item -Path (Join-Path $PSScriptRoot $MyInvocation.MyCommand.Name.ToString()) -Force
            Exit-WithCode $ExitScriptCode
        }
        #>
        if ((Test-Path $nonfactflag) -AND (Test-Path $errorflag)) {
            #Need to move error.txt to system.sav\wdt folder?
            Write-Host "FS Audit Mode error flag present, but not factory process running"
        }
        elseif (($ExitScriptCode -eq 0) -AND ((Test-Path $failureflag))) {
            #Should be remove current script?
            Write-Host "Post processing completes successfully however a GBU flag error is present"
        }
        else {
            #none of previous scenarios exist
            Write-Host "Ready to complete stage"
        }
        Exit-WithCode $ExitScriptCode
        #Start-Process -FilePath "cmd.exe" -ArgumentList "/c Shutdown /r /t 5 /c ""FS Post processing mode: Reboot unit""" -WindowStyle Hidden -WorkingDirectory $PSScriptRoot
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        [string]$ExceptionText = ($_ | Out-String).Trim()
        Write-Host "Failed during exit of PP Script, error: $($ErrorMessage)"
        Write-Host $ExceptionText
    }
    

    
}

<#
.SYNOPSIS
	Get a Device Manager Information
.DESCRIPTION
	Get Devices with errors
.NOTES
	Script version 1.0.0
.PARAMETER ReportName
    Retrn an object with Devices reported with errors than 0, 22, 24
.PARAMETER ContinueOnError
	Optional. by default the process continue no matter result, disable this options can break all script process.
.EXAMPLE
    Get-DeviceManagerError
#>
Function Get-DeviceManagerError {
    [CmdletBinding()]
    Param 
    (		
        [Parameter(Mandatory = $false, HelpMessage = "should continue if result is not expected", Position = 0)]
        [Alias("Continue")]
        [bool]$ContinueOnError = $true
    )
    Begin {
        $SaveCurrentErrorAction = $ErrorActionPreference
        if ($ContinueOnError) {
            $ErrorActionPreference = "SilentlyContinue";
        }
        else {
            $ErrorActionPreference = "Stop";
        }
    }
    Process {		
        Try {				
            WriteLog -Message "===================== CHECKING DEVICE MANAGER ERRORS =====================" -Component $MyInvocation.MyCommand.Name -Verbose;
            WriteLog -Message "`tScaning Devices in local computer $($env:COMPUTERNAME)"  -Component $MyInvocation.MyCommand.Name -Verbose;
            $WMIDevices = Get-WmiObject Win32_PNPEntity
            WriteLog -Message "`tDevices detected: $($WMIDevices.count)" -Component $MyInvocation.MyCommand.Name -Verbose;
            $WMIDevices = Get-WmiObject Win32_PNPEntity | Where-Object { ($_.ConfigManagerErrorcode -ne 0) -AND ($_.ConfigManagerErrorcode -ne 24) -AND ($_.ConfigManagerErrorcode -ne 22) }
            WriteLog -Message "`tDevices detected with errors (-not 0, 22, 24): $($WMIDevices.count)" -Component $MyInvocation.MyCommand.Name -Verbose;
            if (($null -ne $WMIDevices) -AND ($WMIDevices.count -gt 0)) {
                foreach ($device in $WMIDevices) {
                    WriteLog -Message "`t         Device Name: $($device.Name)" -Component $MyInvocation.MyCommand.Name -Verbose;
                    WriteLog -Message "`t   Device Error Code: $($device.ConfigManagerErrorCode)" -Component $MyInvocation.MyCommand.Name -Verbose;
                    WriteLog -Message "`tDevice Error Message: $($device.Description)" -Component $MyInvocation.MyCommand.Name -Verbose;
                    if ($null -ne $device.HardwareID) {
                        WriteLog -Message "`t  Device Error HW ID: $($device.HardwareID[0])" -Component $MyInvocation.MyCommand.Name -Verbose;    
                    }                    
                }
                $ErrorActionPreference = $SaveCurrentErrorAction
                return $WMIDevices
            }
            else {
                WriteLog -Message "`tNo devices detected with error" -Component $MyInvocation.MyCommand.Name -Verbose;
                $ErrorActionPreference = $SaveCurrentErrorAction
                return $mull
            }
        }
        Catch {
            $ErrorMessage = $_.Exception.Message
            WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name;
            return $null;
        }
        Finally { $ErrorActionPreference = $SaveCurrentErrorAction; }	
    }
	
}


Function Get-RegKeyValue {
    [CmdletBinding()]
    Param 
    (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ValueFromPipeline = $True, HelpMessage = "Path", Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias("pathreg")]
        [String]$Path,
		
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ValueFromPipeline = $True, HelpMessage = "Key", Position = 1)]
        [ValidateNotNullOrEmpty()]
        [Alias("keyreg")]
        [String]$Key
    )
    Process {				
        Try {
            if (Get-Variable KeyValue -ErrorAction SilentlyContinue) { Remove-Variable KeyValue }
            if (Test-Path $Path) {
                WriteLog -Message "Access level $($Path)" -Verbose
                $KeyValue = (Get-ItemProperty $Path -Name $Key -ErrorAction SilentlyContinue).$Key
                if ($KeyValue) {
                    WriteLog -Message "Found Key with value: $($KeyValue)" -Verbose
                    return $KeyValue
                }
                else {
                    return $null
                }
            }
            return $null
        }
        Catch {
            $ErrorMessage = $_.Exception.Message
            WriteLog  -Message "[ERROR] Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Verbose
            return $null
        }
    }
}

function DisplayWinREStatus()
{
	# Get WinRE partition info
	$WinREInfo = Reagentc /info
	foreach ($line in $WinREInfo)
	{
		$params = $line.Split(':')
		if ($params.Count -lt 2)
		{
			continue
		}
		if (($params[1].Trim() -ieq "Enabled") -Or (($params[1].Trim() -ieq "Disabled")))
		{
			$Status = $params[1].Trim() -ieq "Enabled"
			WriteLog -Message $line.Trim() -Verbose
		}
		if ($params[1].Trim() -like "\\?\GLOBALROOT*")
		{
			$Location = $params[1].Trim()
			WriteLog -Message $line.Trim() -Verbose
		}
	}
	
	return $Status, $Location
}
function ExtractNumbers([string]$str)
{
	$cleanString = $str -replace "[^0-9]"
	return [long]$cleanString
}

function Enable-Privilege {
    param(
     ## The privilege to adjust. This set is taken from
     ## http://msdn.microsoft.com/en-us/library/bb530716(VS.85).aspx
     [ValidateSet(
      "SeAssignPrimaryTokenPrivilege", "SeAuditPrivilege", "SeBackupPrivilege",
      "SeChangeNotifyPrivilege", "SeCreateGlobalPrivilege", "SeCreatePagefilePrivilege",
      "SeCreatePermanentPrivilege", "SeCreateSymbolicLinkPrivilege", "SeCreateTokenPrivilege",
      "SeDebugPrivilege", "SeEnableDelegationPrivilege", "SeImpersonatePrivilege", "SeIncreaseBasePriorityPrivilege",
      "SeIncreaseQuotaPrivilege", "SeIncreaseWorkingSetPrivilege", "SeLoadDriverPrivilege",
      "SeLockMemoryPrivilege", "SeMachineAccountPrivilege", "SeManageVolumePrivilege",
      "SeProfileSingleProcessPrivilege", "SeRelabelPrivilege", "SeRemoteShutdownPrivilege",
      "SeRestorePrivilege", "SeSecurityPrivilege", "SeShutdownPrivilege", "SeSyncAgentPrivilege",
      "SeSystemEnvironmentPrivilege", "SeSystemProfilePrivilege", "SeSystemtimePrivilege",
      "SeTakeOwnershipPrivilege", "SeTcbPrivilege", "SeTimeZonePrivilege", "SeTrustedCredManAccessPrivilege",
      "SeUndockPrivilege", "SeUnsolicitedInputPrivilege")]
     $Privilege,
     ## The process on which to adjust the privilege. Defaults to the current process.
     $ProcessId = $pid,
     ## Switch to disable the privilege, rather than enable it.
     [Switch] $Disable
    )
   
    ## Taken from P/Invoke.NET with minor adjustments.
$definition = @'
using System;
using System.Runtime.InteropServices;
    
public class AdjPriv
{
    [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
    internal static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall,
    ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen);
    
    [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
    internal static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr phtok);
    [DllImport("advapi32.dll", SetLastError = true)]
    internal static extern bool LookupPrivilegeValue(string host, string name, ref long pluid);
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    internal struct TokPriv1Luid
    {
    public int Count;
    public long Luid;
    public int Attr;
    }
    
    internal const int SE_PRIVILEGE_ENABLED = 0x00000002;
    internal const int SE_PRIVILEGE_DISABLED = 0x00000000;
    internal const int TOKEN_QUERY = 0x00000008;
    internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;
    public static bool EnablePrivilege(long processHandle, string privilege, bool disable)
    {
    bool retVal;
    TokPriv1Luid tp;
    IntPtr hproc = new IntPtr(processHandle);
    IntPtr htok = IntPtr.Zero;
    retVal = OpenProcessToken(hproc, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, ref htok);
    tp.Count = 1;
    tp.Luid = 0;
    if(disable)
    {
    tp.Attr = SE_PRIVILEGE_DISABLED;
    }
    else
    {
    tp.Attr = SE_PRIVILEGE_ENABLED;
    }
    retVal = LookupPrivilegeValue(null, privilege, ref tp.Luid);
    retVal = AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
    return retVal;
    }
}
'@
   
    $processHandle = (Get-Process -id $ProcessId).Handle
    $type = Add-Type $definition -PassThru
    $type[0]::EnablePrivilege($processHandle, $Privilege, $Disable)
}


function Get-HardwareDevice {
    param (
        # Parameter help description
        [Parameter(Mandatory = $true, Position = 0)]
        [String]$HWID,
        [Parameter(Mandatory = $false, Position = 1)]
        [string]$logpath
    )
    if ($null -eq $logpath) { $logpath = (Join-Path $Env:SystemDrive "\system.sav\logs") }
    #define log file where all HW Ids will be stored.
    $hwidlog= (Join-Path $logpath "List_HWIDs.log")
    WriteLog -Message "===================== SEARCHING HARDWARE DEVICE =====================" -Verbose 
    "===================== SEARCHING HARDWARE DEVICE =====================" | Out-File -FilePath $hwidlog -Append -Force
    WriteLog -Message "`tSearching for HWID: $HWID" -Verbose
    $GetWMIDevices = Get-WmiObject Win32_PNPEntity
    foreach ($device in $GetWMIDevices) {
        if ($null -ne $device.HardwareID) {
            Foreach ($devid in $device.HardwareID) {
                "`tDevice HWID: $devid" | Out-File -FilePath $hwidlog -Append -Force
                if ($devid.length -gt $HWID.Length) {
                    if ($devid.substring(0,$HWID.Length) -eq $HWID) {
                        WriteLog -Message "`tDevice found: $($device.Name)" -Verbose
                        return $device
                    }
                } 
                if ($HWID.Length -gt $devid.Length) {
                    if ($HWID.substring(0,$devid.Length) -eq $devid) {
                        WriteLog -Message "`tDevice found: $($device.Name)" -Verbose
                        return $device
                    }

                }
                if ($devid -eq $HWID) {
                    WriteLog -Message "`tDevice found: $($device.Name)" -Verbose
                    return $device
                }
            }
        } else {
            "`tDevice without HWID" | Out-File -FilePath $hwidlog -Append -Force
        }
    }
    WriteLog -Message "`tDevice not found" -Verbose
    return $null
    
}


function Show-MessageBoxWithTimeout {
    param (
        [string]$Message,
        [int]$TimeoutSeconds = 300,
        [string]$DefaultOption = "Cancel"
    )

    $startTime = Get-Date
    $endTime = $startTime.AddSeconds($TimeoutSeconds)

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Confirm Manual Fingerprint Reset"
    $form.Size = New-Object System.Drawing.Size(400, 200)
    $form.StartPosition = "CenterScreen"

    $ToolTip = New-Object System.Windows.Forms.ToolTip
    $ToolTip.AutoPopDelay = 50000;
    $ToolTip.InitialDelay = 1000;
    $ToolTip.ReshowDelay = 500;
    $ToolTip.ShowAlways = $true;

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Message
    $label.AutoSize = $true
    $label.MaximumSize = New-Object System.Drawing.Size(350, 0)
    $label.Location = New-Object System.Drawing.Point(10, 20)
    $ToolTip.SetToolTip($label, "Default option will select ""$($DefaultOption)"" after $($TimeoutSeconds) seconds")
    $form.Controls.Add($label)

    $yesButton = New-Object System.Windows.Forms.Button
    $yesButton.Text = "OK"
    $yesButton.Location = New-Object System.Drawing.Point(50, 100)
    $yesButton.Add_Click({ $form.Tag = "OK"; $form.Close() })
    $form.Controls.Add($yesButton)

    $noButton = New-Object System.Windows.Forms.Button
    $noButton.Text = "Cancel"
    $noButton.Location = New-Object System.Drawing.Point(150, 100)
    $noButton.Add_Click({ $form.Tag = "Cancel"; $form.Close() })
    $form.Controls.Add($noButton)

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1000
    $timer.Add_Tick({
        if ((Get-Date) -ge $endTime) {
            $timer.Stop()
            $form.Tag = $DefaultOption
            $form.Close()
        }
    })
    $timer.Start()

    $form.ShowDialog() | Out-Null
    return $form.Tag
}