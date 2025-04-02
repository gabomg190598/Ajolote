
    #--Close sysprep
    while ((Get-Process | Where-Object { $_.ProcessName -like "*sysprep*" }).Count -gt 0) {
        $sysp = Get-Process | Where-Object { $_.ProcessName -like "*sysprep*" }
        if ($sysp) { WriteLog -Message "Sysprep tool is open, closing for now"; Stop-Process -Id $sysp.Id; Start-Sleep -Seconds 3; }
    }

    <#################################################################
    ###     RETRIEVE SYSTEM INFORMATION
    ##################################################################>
    WriteLog -Message "-----------------------------------------Record Main Information----------------------------------------------------" -Verbose 
    $OS = @{}
    $OS.ProductName = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').ProductName
    $OS.Architecture = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
    $OS.Version = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').ReleaseId
    $OS.Build = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuildNumber
    switch ($OS.Build) {
        "19041" { $OS.Name = $OS.ProductName; $USMT = (Join-Path $ParentStagePath "USMT_19041"); break; }
        "19042" { $OS.Name = $OS.ProductName; $USMT = (Join-Path $ParentStagePath "USMT_19041"); break; }
        "19043" { $OS.Name = $OS.ProductName; $USMT = (Join-Path $ParentStagePath "USMT_19041"); break; }
        "19044" { $OS.Name = $OS.ProductName; $USMT = (Join-Path $ParentStagePath "USMT_19041"); break; }
        "19045" { $OS.Name = $OS.ProductName; $USMT = (Join-Path $ParentStagePath "USMT_19041"); break; }
        "22000" { $OS.Name = $OS.ProductName.Replace(" 10 ", " 11 "); $USMT = (Join-Path $ParentStagePath "USMT_22000"); break; }
        "22621" { $OS.Name = $OS.ProductName.Replace(" 10 ", " 11 "); $USMT = (Join-Path $ParentStagePath "USMT_22621"); break; }
        "22631" { $OS.Name = $OS.ProductName.Replace(" 10 ", " 11 "); $USMT = (Join-Path $ParentStagePath "USMT_22621"); break; }
        "26100" { $OS.Name = $OS.ProductName.Replace(" 10 ", " 11 "); $USMT = (Join-Path $ParentStagePath "USMT_26100"); break; }
        Default { if ([int]$OS.Build -ge 22000) { $OS.Name = $OS.ProductName.Replace(" 10 ", " 11 ") } else { $OS.Name = $OS.ProductName }; $USMT = (Join-Path $ParentStagePath "USMT_$($OS.Build)"); break; }
    }
    $OS.Revision = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').UBR
    $OS.DisplayVersion = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DisplayVersion
    $OS.Branch = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').BuildBranch
    $SKU = (Get-CimInstance -Namespace ROOT\HP\InstrumentedBIOS -ClassName HP_BIOSSetting | Where-Object { $_.Name -eq "SKU Number" }).Value
    $BuildID = (Get-CimInstance -Namespace ROOT\HP\InstrumentedBIOS -ClassName HP_BIOSSetting | Where-Object { $_.Name -eq "Build ID" }).Value
    $FeatureByte = (Get-CimInstance -Namespace ROOT\HP\InstrumentedBIOS -ClassName HP_BIOSSetting | Where-Object { $_.Name -eq "Feature Byte" }).Value

    if (!([string]::IsNullOrWhiteSpace($BuildID))) {
        try {
            $LOC = $BuildID.ToString().Split("#")[2].Substring(1, 3).ToUpper()
        }
        catch {
            $LOC = "ABA"
        }
    }

    if (!([string]::IsNullOrWhiteSpace($SKU))) {
        try {
            $AV = $SKU.Substring(0, $SKU.IndexOf("#"))
        }
        catch {
            $AV = "12345AV"
        }
    }
    else {
        WriteLog -Message "Missing SKU value on bios, it will be used default #ABA" -MessageType Error -Verbose
        $AV = "12345AV"
    } 

    WriteLog -Message " Checking PowerShell Version: $($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor).$($PSVersionTable.PSVersion.Build).$($PSVersionTable.PSVersion.Revision)" -Verbose
    WriteLog -Message "      Executing script from : $((Get-Item -Path '.\' -Verbose).FullName)" -Verbose
    WriteLog -Message "             Script Version : $($ScriptVersion)" -Verbose
    WriteLog -Message "         Windows ProductName: $($OS.ProductName)" -Verbose
    WriteLog -Message "                Windows Name: $($OS.Name)" -Verbose
    WriteLog -Message "             Windows Version: $($OS.Version)" -Verbose
    WriteLog -Message "     Windows Display Version: $($OS.DisplayVersion)" -Verbose
    WriteLog -Message "       Windows Build Version: $($OS.Build)" -Verbose
    WriteLog -Message "      Windows Build Revision: $($OS.Revision)" -Verbose
    WriteLog -Message "              Windows Branch: $($OS.Branch)" -Verbose
    WriteLog -Message "           Language Detected: $((GET-WinSystemLocale).Name)" -Verbose
    WriteLog -Message "           Current User Name: $($env:USERNAME)" -Verbose
    WriteLog -Message "                  Current OS: $((Get-WmiObject Win32_OperatingSystem).Name)" -Verbose
    WriteLog -Message "            Current OS Drive: $($env:HOMEDRIVE)" -Verbose
    WriteLog -Message "     Current OS Architecture: $($env:PROCESSOR_ARCHITECTURE)" -Verbose
    WriteLog -Message "     Current OS Architecture: $((Get-WmiObject Win32_OperatingSystem).OSArchitecture)" -Verbose
    WriteLog -Message "             Current PC Name: $((Get-WmiObject Win32_OperatingSystem).CSName)" -Verbose
    WriteLog -Message "              Computer Model: $((Get-WmiObject Win32_Computersystem).Model) [$((Get-WmiObject Win32_BaseBoard).Product)]" -Verbose
    WriteLog -Message "               Serial Number: $((Get-WmiObject Win32_Bios).SerialNumber)" -Verbose	
    WriteLog -Message "                  SKU Number: $($SKU)" -Verbose
    WriteLog -Message "                     Buil ID: $($BuildID)" -Verbose
    WriteLog -Message "                Feature Byte: $($FeatureByte)" -Verbose
    WriteLog -Message "                      SKU AV: $($AV)" -Verbose				
    WriteLog -Message "            SKU Localization: $($LOC)" -Verbose		

    if (Test-Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State) { 
        $regkey = Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State -Name ImageState;
        WriteLog -Message "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State ImageState=[$($regkey.ImageState)]" -Verbose
    }
    if (Test-Path HKLM:\SYSTEM\Setup) { 
        $regkey = Get-ItemProperty -Path HKLM:\SYSTEM\Setup -Name SystemSetupInProgress;
        WriteLog -Message "HKLM:\SYSTEM\Setup SystemSetupInProgress=[$($regkey.SystemSetupInProgress)]" -Verbose
    }
    WriteLog -Message "-----------------------------------------------Process start----------------------------------------------------------" -Verbose

    if ($null -ne $OS.DisplayVersion -AND $OS.DisplayVersion.Length -gt 2) {
        "[info]HP CS Post-Processing for $($OS.Name) $($OS.Architecture) Ver.$($OS.DisplayVersion)" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline
    }
    else {
        "[info]HP CS Post-Processing for $($OS.Name) $($OS.Architecture) Ver.$($OS.Version)" | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline
    }
    $USMT | Out-Null