<#
Enable RSAT feature
Version 1.0.5 beta
Date: 1/31/2025

Description:
    Module designed to install RSAT: https://learn.microsoft.com/en-us/troubleshoot/windows-server/system-management-components/remote-server-administration-tools
Changes:

#>

if ($null -ne $json.JOBREQUEST.EnableRSAT) { 
    if (($null -eq $json.JOBREQUEST.EnableRSAT.status) -OR ($json.JOBREQUEST.EnableRSAT.status.Tolower() -eq "new")) {
        $LanguageCodes = [System.Collections.ArrayList]::new()
        switch ($WinVersion) {
            {($_ -eq "1903") -OR ($_ -eq "1909")} { $LPPACK="1900"; $Convert4OS="Windows 10"; break; } #Not used anymore
            {($_ -eq "19041") -OR ($_ -eq "19042") -OR ($_ -eq "19043") -OR ($_ -eq "19044") -OR ($_ -eq "19045")} { $LPPACK="2021"; $Convert4OS="Windows 10"; break; }
            "22000" { $LPPACK="2120"; $Convert4OS="Windows 11"; break; }
            {($_ -eq "22621") -OR ($_ -eq "22631")} { $LPPACK="2202"; $Convert4OS="Windows 11"; break; }
            Default { $LPPACK="0000"; $Convert4OS="Windows 10"; break; }
        }
        $LPRepository="$($AjoloteDrive)\LANGUAGES\$($LPPACK)\LanguagePack"
        if (!(Test-Path -Path $LPRepository -PathType Container)) {
            WriteLog -Message "Missing required folder: $($LPRepository)" -MessageType Error -Verbose
            $global:MessageResults="Missing required folder: $($LPRepository)"
            $global:CodeResults=404
            ##### FAIL RESULT
            Update-JobStatus $jobfile $json $json.JOBREQUEST.EnableRSAT "fail" $global:MessageResults
            Out-WinPE -Backuplogs -RemoveJob
        }
        WriteLog -Message "Repository detected for $($Convert4OS) is $($LPRepository)" -Verbose
        $RSAT = [system.collections.arraylist]@()
        #Feature Name
        $FeatureNames=@("Active Directory Domain Services and Lightweight Directory Services Tools",
                        "BitLocker Drive Encryption Administration Utilities",
                        "Active Directory Certificate Services Tools",
                        "Azure Stack HCI PowerShell module",
                        "DHCP Server Tools",
                        "DNS Server Tools",
                        "Failover Clustering Tools",
                        "File Services Tools",
                        "Group Policy Management Tools",
                        "IP Address Management (IPAM) Client",
                        "Data Center Bridging LLDP Tools",
                        "Network Controller Management Tools",
                        "Network Load Balancing Tools",
                        "Remote Access Management Tools",
                        "Remote Desktop Services Tools",
                        "Server Manager",
                        "Shielded VM Tools",
                        "Storage Replica Module for Windows PowerShell",
                        "Volume Activation Tools",
                        "Windows Server Update Services Tools",
                        "Storage Migration Service Management Tools",
                        "Systems Insights Module for Windows PowerShell")
        #Package list
        $SearchPackages=@("Microsoft-Windows-ActiveDirectory-DS-LDS-Tools-FoD-Package",
                        "Microsoft-Windows-BitLocker-Recovery-Tools-FoD-Package",
                        "Microsoft-Windows-CertificateServices-Tools-FoD-Package",
                        "Microsoft-AzureStack-HCI-Management-Tools-FOD-Package",
                        "Microsoft-Windows-DHCP-Tools-FoD-Package",
                        "Microsoft-Windows-DNS-Tools-FoD-Package",
                        "Microsoft-Windows-FailoverCluster-Management-Tools-FOD-Package",
                        "Microsoft-Windows-FileServices-Tools-FoD-Package",
                        "Microsoft-Windows-GroupPolicy-Management-Tools-FoD-Package",
                        "Microsoft-Windows-IPAM-Client-FoD-Package",
                        "Microsoft-Windows-LLDP-Tools-FoD-Package",
                        "Microsoft-Windows-NetworkController-Tools-FoD-Package",
                        "Microsoft-Windows-NetworkLoadBalancing-Tools-FoD-Package",
                        "Microsoft-Windows-RemoteAccess-Management-Tools-FoD-Package",
                        "Microsoft-Windows-RemoteDesktop-Services-Tools-FoD-Package",
                        "Microsoft-Windows-ServerManager-Tools-FoD-Package",
                        "Microsoft-Windows-Shielded-VM-Tools-FoD-Package",
                        "Microsoft-Windows-StorageReplica-Tools-FoD-Package",
                        "Microsoft-Windows-VolumeActivation-Tools-FoD-Package",
                        "Microsoft-Windows-WSUS-Tools-FoD-Package",
                        "Microsoft-Windows-StorageMigrationService-Management-Tools-FOD-Package",
                        "Microsoft-Windows-SystemInsights-Management-Tools-FOD-Package")
        #Capabililty Name
        $CapabilityNames=@("Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0",
                        "Rsat.BitLocker.Recovery.Tools~~~~0.0.1.0",
                        "Rsat.CertificateServices.Tools~~~~0.0.1.0",
                        "Rsat.AzureStack.HCI.Management.Tools~~~~0.0.1.0",
                        "Rsat.DHCP.Tools~~~~0.0.1.0",
                        "Rsat.Dns.Tools~~~~0.0.1.0",
                        "Rsat.FailoverCluster.Management.Tools~~~~0.0.1.0",
                        "Rsat.FileServices.Tools~~~~0.0.1.0",
                        "Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0",
                        "Rsat.IPAM.Client.Tools~~~~0.0.1.0",
                        "Rsat.LLDP.Tools~~~~0.0.1.0",
                        "Rsat.NetworkController.Tools~~~~0.0.1.0",
                        "Rsat.NetworkLoadBalancing.Tools~~~~0.0.1.0",
                        "Rsat.RemoteAccess.Management.Tools~~~~0.0.1.0",
                        "Rsat.RemoteDesktop.Services.Tools~~~~0.0.1.0",
                        "Rsat.ServerManager.Tools~~~~0.0.1.0",
                        "Rsat.Shielded.VM.Tools~~~~0.0.1.0",
                        "Rsat.StorageReplica.Tools~~~~0.0.1.0",
                        "Rsat.VolumeActivation.Tools~~~~0.0.1.0",
                        "Rsat.WSUS.Tools~~~~0.0.1.0",
                        "Rsat.StorageMigrationService.Management.Tools~~~~0.0.1.0",
                        "Rsat.SystemInsights.Management.Tools~~~~0.0.1.0")
        
        if (($SearchPackages.Count -ne $CapabilityNames.Count) -OR ($SearchPackages.Count -ne $FeatureNames.Count)) {
            $global:MessageResults="Cross reference failed due not same number of elements for Packages [$($SearchPackages.Count)], Feature Name elements [$($FeatureNames.Count)] and Capabilities elements [$($CapabilityNames.Count)]"
            WriteLog -Message $global:MessageResults -MessageType Error -Verbose            
            $global:CodeResults=90
            Out-WinPE -Backuplogs -RemoveJob
        }
        #build array object - cross definitions
        for ($i=0; $i -lt $CapabilityNames.Count; $i++) {$foradd=[pscustomobject]@{Name=$FeatureNames[$i];Capability=$CapabilityNames[$i];Package=$SearchPackages[$i]}; $RSAT.Add($foradd);}
        #initial language en-us
        if (($null -eq $json.JOBREQUEST.Localization.removeus) -OR (-Not($json.JOBREQUEST.Localization.removeus))) {
            [void]$LanguageCodes.Add("en-us")
        }
        #in case that languages has been added, inlcude for package search
        if ($null -ne $json.JOBREQUEST.Localization.lpcodes) {
            [string[]]$ConvertArrayLPs=$json.JOBREQUEST.Localization.lpcodes
            WriteLog -Message "Required $($ConvertArrayLPs.Count) languages" -Verbose
            foreach ($lang in $ConvertArrayLPs) {
                if (-Not($lang.Contains("-"))) { 
                    WriteLog -Message "Not expected to request language: $($lang) or Install language module fail" -MessageType Error -Verbose
                } else {
                    WriteLog -Message "language package required: $($lang)" -Verbose
                    [void]$LanguageCodes.Add($lang)
                }
            }
        }
        #Search packages
        $FileNamePackages = [System.Collections.ArrayList]::new()
        $CapabilitiesFound = [System.Collections.ArrayList]::new()
        #Odd scenario, but must fail if not able to add single language code to array
        if ($LanguageCodes.Count -eq 0) {
            WriteLog -Message "EnableRSAT failed due not a single language detected (includign en-us)" -MessageType Error -Verbose
            $global:MessageResults="EnableRSAT failed due not a single language detected (includign en-us)"
            $global:CodeResults=4
            Out-WinPE -Backuplogs -RemoveJob
        }
        #searching packages        
        $Archi="amd64"
        foreach ($lang in $LanguageCodes) {
            $PackagePath_FOD=""
            [int]$PackagesFound=0
            WriteLog -Message "Searching packages for language code: $($lang)" -Verbose
            foreach ($hintpkg in $RSAT) {
                WriteLog -Message "Search query: [*$($hintpkg.Package)*$($Archi)*$($lang)*.cab]" -Verbose
                $get_lpfod=Get-ChildItem -Path $LPRepository -File | Where-Object {$_.Name -like "*$($hintpkg.Package)*$($Archi)*$($lang)*.cab"}
                if ($null -ne $get_lpfod) {
                    WriteLog -Message "Feature destected by package: $($hintpkg.Name)" -Verbose
                    WriteLog -Message "FOD file detected: $($get_lpfod[0].Name)" -Verbose
                    $PackagePath_FOD += " /PackagePath:$($get_lpfod[0].FullName)"
                    $PackagesFound++;
                    [void]$FileNamePackages.Add($get_lpfod[0]);
                    [void]$CapabilitiesFound.Add($hintpkg.Capability);
                } else {
                    WriteLog -Message "Not found, try changing query: [*$($hintpkg.Package)*$($Archi)~~.cab]" -MessageType Warning -Verbose
                    $get_lpfod=Get-ChildItem -Path $LPRepository -File | Where-Object {$_.Name -like "*$($hintpkg.Package)*$($Archi)~~.cab"}
                    if ($null -ne $get_lpfod) {
                        WriteLog -Message "Feature detected by package: $($hintpkg.Name)" -Verbose
                        WriteLog -Message "FOD file detected: $($get_lpfod[0].Name)" -Verbose
                        $PackagePath_FOD += " /PackagePath:$($get_lpfod[0].FullName)"
                        $PackagesFound++;
                        [void]$FileNamePackages.Add($get_lpfod[0]);
                        [void]$CapabilitiesFound.Add($hintpkg.Capability);
                    } else {
                        WriteLog -Message "It was not possible to detect a package file with above query" -MessageType Warning -Verbose
                    }
                }
                WriteLog -Message "Was located $($PackagesFound)/$($SearchPackages.Count) packages for language $($lang)" -Verbose
                Remove-Variable -Name get_lpfod -Force -ErrorAction SilentlyContinue
            }
            if ($PackagePath_FOD.Trim().Length -lt 10) {
                $global:MessageResults="Not detected a single package for enable RSAT, satelite failure"
                WriteLog -Message  $global:MessageResults -MessageType Error -Verbose                
                $global:CodeResults=404
                ##### FAIL RESULT
                Update-JobStatus $jobfile $json $json.JOBREQUEST.EnableRSAT "fail" $global:MessageResults
                Out-WinPE -Backuplogs -RemoveJob
            }
            WriteLog -Message "Adding packages:" -Verbose
            WriteLog -Message "*Dism.exe /image:$($OSDrive)\ /scratchdir:$($OSDrive)\ /add-package$($PackagePath_FOD)" -Verbose
            $ApplyFOD = RunDism -Params "/image:$($OSDrive)\ /scratchdir:$($OSDrive)\ /add-package$($PackagePath_FOD)" -WorkDir "$($logs)\" -OutFile "$($logs)\DismFOD_$($lang).log" -Verbose
            if ($ApplyFOD -ne 0) {
                WriteLog -Message "Unexpected code found injecting FOD $($lang)" -MessageType Error -Verbose
                $global:MessageResults="Unexpected code found injecting FOD $($lang)"
                $global:CodeResults=$ApplyFOD
                ##### FAIL RESULT
                Update-JobStatus $jobfile $json $json.JOBREQUEST.EnableRSAT "fail" $global:MessageResults
                Out-WinPE -Backuplogs -RemoveJob
            }
            Remove-Variable -Name PackagePath_FOD -Force -ErrorAction SilentlyContinue
        }
        #Enable features
        if ($CapabilitiesFound.Count -gt 0) {            
            foreach ($feat in $CapabilitiesFound) {
                WriteLog -Message "Enabling $(($RSAT | Where-Object {$_.Capability -eq $feat}).Name)" -Verbose
                WriteLog -Message "*Dism.exe /image:$($OSDrive)\ /scratchdir:$($OSDrive)\ /add-capability /source:$($LPRepository) /LimitAccess /CapabilityName:$($feat)"  -Verbose
                $EnableRSAT = RunDism -Params "/image:$($OSDrive)\ /scratchdir:$($OSDrive)\ /add-capability /source:$($LPRepository) /LimitAccess /CapabilityName:$($feat)" -WorkDir "$($logs)\" -OutFile "$($logs)\DismEnableRSAT.log" -Verbose
                if ($EnableRSAT -ne 0) {
                    WriteLog -Message "Unexpected code found enabling FOD $($feat)" -MessageType Error -Verbose
                    $global:MessageResults="Unexpected code found enabling FOD $($feat)"
                    $global:CodeResults=$EnableRSAT
                    ##### FAIL RESULT
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.EnableRSAT "fail" $global:MessageResults
                    Out-WinPE -Backuplogs -RemoveJob
                }
            }
        } else {
            WriteLog -Message "It was not possible detect a single feature to enableb for RSAT" -MessageType Warning -Verbose
        }
        
        if ($FileNamePackages.Count -gt 0) {
            if ($null -eq $json.JOBREQUEST.EnableRSAT.packages) {
                $json.JOBREQUEST.EnableRSAT | Add-Member -Name "packages" -MemberType NoteProperty -Value ($FileNamePackages | Select-Object -Property Name | Sort-Object)
            } else {
                $json.JOBREQUEST.EnableRSAT.packages=($FileNamePackages | Select-Object -Property Name | Sort-Object)
            }
            ###Save sucessfully status and continue
            Update-JobStatus $jobfile $json $json.JOBREQUEST.EnableRSAT "pass" "Successfully configured RSAT"
        } else {
            WriteLog -Message "Not a single file was added for report, somenthing was wrong" -MessageType Error
            $global:MessageResults="Not a single file was added for report, somenthing was wrong"
            $global:CodeResults=5
            Out-WinPE -Backuplogs -RemoveJob
        }

    } elseif ($json.JOBREQUEST.EnableRSAT.status.Tolower() -eq "pass") {
        WriteLog -Message "Process already complete and marked as successfully" -Verbose
    } elseif ($json.JOBREQUEST.EnableRSAT.status.Tolower() -eq "fail") {
        WriteLog -Message "EnableRSAT request marked as fail" -MessageType Error -Verbose
        $global:MessageResults="EnableRSAT request marked as fail"
        $global:CodeResults=2
        Out-WinPE -Backuplogs -RemoveJob
    } else {
        WriteLog -Message "EnableRSAT request was not expected to receive with status $($json.JOBREQUEST.EnableRSAT.status)" -MessageType Error -Verbose
    }
} else {
    WriteLog -Message "EnableRSAT module is not required, continue" -Verbose
}