if ($null -ne $json.JOBREQUEST.PNP) {
    $json.JOBREQUEST.PNP="set"
    WriteLog -Message "Check if OEM file exists and update job file into share" -Verbose
    if ((Test-Path -Path (Join-Path $logs "OEMs.log") -PathType Leaf) -AND (Test-Path -Path (Join-Path $logs "OEM.csv") -PathType Leaf)) {
        WriteLog -Message "Search Drivers installed for network" -Verbose
        $DriversOEM=Get-Content (Join-Path $logs "OEM.csv") | Convertfrom-Csv 
        $DicDrivers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $DriversOEM | ForEach-Object { $DicDrivers.Add($_.OEM,$_.Driver) }
        (Get-Content -Path (Join-Path $logs "OEMs.log") | Select-String -Pattern "Published Name:") | ForEach-Object { 
            WriteLog -Message "Driver added $($_.Line.ToString().Replace(""Published Name:"","""").Trim())" -Verbose 
            if ($null -eq $json.JOBREQUEST.Drivers.sysid) { #removing drivers used for Network only because this image was requested without drivers
                $RemovePNP = Invoke-RunPower -File "cmd.exe" -Params "/c pnputil /delete-driver $($_.Line.ToString().Replace(""Published Name:"","""").Trim())" -WorkDir $PSScriptRoot -OutFile "$($logs)\HPNetOEMDriversRemove.log" -Verbose 
                if ($RemovePNP -ne 0) {
                    WriteLog -Message "There was an error removing driver: $($_.Line.ToString().Replace(""Published Name:"","""").Trim())" -MessageType Error -Verbose
                }
            } else {                
                $DriversPath = (Join-Path (Join-Path (Join-Path $LocalDrive "DRIVERS") $json.JOBREQUEST.Drivers.sysid) "_INF")
                if ($null -eq (Get-ChildItem -Path $DriversPath -Recurse -File -filter $DicDrivers[$_.Line.ToString().Replace("Published Name:","").Trim()])) {
                    WriteLog -Message "It was not possible detect OEM driver[$($DicDrivers[$_.Line.ToString().Replace(""Published Name:"","""").Trim()])] on current build image drivers, removing for security reasons" -Verbose
                    $RemovePNP = Invoke-RunPower -File "cmd.exe" -Params "/c pnputil /delete-driver $($_.Line.ToString().Replace(""Published Name:"","""").Trim())" -WorkDir $PSScriptRoot -OutFile "$($logs)\HPNetOEMDriversRemove.log" -Verbose 
                    if ($RemovePNP -ne 0) {
                        WriteLog -Message "There was an error removing driver: $($_.Line.ToString().Replace(""Published Name:"","""").Trim())" -MessageType Error -Verbose
                    }
                    $json.JOBREQUEST.PNP="remove"
                }
            }
        }
        if ($null -eq $json.JOBREQUEST.Drivers.sysid) {
            $json.JOBREQUEST.PNP="remove"
        }
    }
    
    try {
        $json | ConvertTo-Json -Depth 16 | Out-File -FilePath $jobfile -Encoding ascii -Force
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        WriteLog -Message "Failed updating JOB file: $($ErrorMessage)" -MessageType Error -Verbose
        $global:MessageResults="Failed updating JOB file: $($ErrorMessage)"
        $global:CodeResults=209
        Out-Windows
    }
    if ($null -ne $json.JOBREQUEST.Job.error) {
        $json.JOBREQUEST.Job.error="Image Ready for Sysprep"
        try {
            $json | ConvertTo-Json -Depth 16 | Out-File -FilePath $jobfile -Encoding ascii -Force
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            WriteLog -Message "Failed updating JOB file: $($ErrorMessage)" -MessageType Error -Verbose
            $global:MessageResults="Failed updating JOB file: $($ErrorMessage)"
            $global:CodeResults=209
            Out-Windows
        }
        WriteLog -Message "Send job before sysprep image" -Verbose
        Invoke-UpdateJob -Verbose
    } 
}




