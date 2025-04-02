#################################################################
    ####      OSChanger Preparation
    ##################################################################
    switch ($env:PROCESSOR_ARCHITECTURE) {
        "AMD64" { $OSChanger = (Join-Path $WDT "OSChanger64.exe"); break; }
        "x86" { $OSChanger = (Join-Path $WDT "OSChanger32.exe"); break; }
        "IA64" { $OSChanger = (Join-Path $WDT "OSChangerARM.exe"); break; }
        Default { $OSChanger = (Join-Path $WDT "OSChanger64.exe"); break; }
    }
    WriteLog -Message "---> OSChanger required: $($OSChanger)" -Verbose

    #-Create WDT folde if not exist
    if (-Not(Test-Path $WDT)) { New-Item -Path $WDT -ItemType Directory -Force }

    if (-Not(Test-Path -Path $OSChanger)) {
        #----- Check if 1st partition has WDT folder
        $DriveID = (Get-Partition -DiskNumber (Get-Partition -DriveLetter C).DiskNumber -PartitionNumber 1 | Get-Volume).UniqueId
        if ($null -ne $DriveID) {
            if (Test-Path "$($DriveID)system.sav\WDT") {
                WriteLog -Message "Foud WDT folder on 1st partition" -Verbose
                $CopyEFI = Copy-Item "$($DriveID)system.sav\WDT\*" -Destination "$($WDT)\" -Recurse  -Force -PassThr
                if (($null -eq $CopyEFI) -OR ($CopyEFI.Count -lt 1)) { WriteLog -Message "It seems like was not possible copy handshare files from 1st prtition" -MessageType Warning -Verbose } else { $CopyEFI | Out-File -FilePath "$($logs)\CopyWDTfromEFI.log" -Encoding default -Force }
            }
        }
        #---- If WDT is not present, use the one in component
        if (-Not(Test-Path -Path $OSChanger)) { 
            $null = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /sehiy $($LocalWDT)\* $($WDT)\" -WorkDir (Get-Item -Path '.\' -Verbose).FullName -OutFile "$($logs)\CopyWDTfromComponent.log"; 
        }
    }

    if (-Not(Test-Path -Path $Result)) { 
        "[Results]" | Out-File -FilePath $Result -Encoding default -Force;
        "Version=1.00" | Out-File -FilePath $Result -Encoding default -Force -Append;	
    }

    if (-Not(Test-Path $OSChanger) -OR !(Test-Path $Result)) { 
        WriteLog -Message "Something fail preparing WDT folder" -MessageType Error -Verbose; 
        "error in HandShake files, review content on $($WDT)" | Out-File -FilePath $errorflg -Encoding default -Force; 
        "[error]HP FS Post-Processing Mode for failed. Missing OSChanger." | Out-File -FilePath $FSscreenStatusFile -Encoding default -Force -NoNewline
        Exit-FSCode(401);
    }
    ##----Flag to prevent use factory process
    if (Test-Path -Path $CSCustMode -PathType Leaf) {
        WriteLog -Message "CSCustMode.flg was detected, prevent process return to factory process"
        $OSChanger = (Join-Path $WDT $CustomOSChanger)
        WriteLog -Message "--->New OSChanger required: $($OSChanger)" -Verbose
        if (-Not(Test-Path -Path $OSChanger -PathType Leaf)) {
            Copy-Item -Path (Join-Path $LocalWDT $CustomOSChanger) -Destination "$($WDT)\" -Force
        }
        [string[]]$MyExclude = @($CustomOSChanger, "result.ini")
        foreach ($item in (Get-ChildItem -Path $WDT -Recurse -File -Exclude $MyExclude)) {
            WriteLog -Message "Remove unecesary file: $($item.Name)" -Verbose;
            Remove-Item -Path $item.FullName -Force
        }
    }
    #################################################################
    # Initialize OSChanger - FROM THIS POINT ERRORS CAN RETURN TO WDT
    ##################################################################
    WriteLog -Message "Write Error meessage on result.ini in case of unexpected return to WDT" -Verbose
    $null = Invoke-RunPower -File $OSChanger -Params "/ErrorNumber:700 /Message:""***FAIL*** The CS Post Processing fail unexpected on 1PP phase""" -WorkDir $WDT -OutFile "$($logs)\OSChangerError.log" -Verbose
