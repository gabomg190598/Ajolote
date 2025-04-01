<#
    REMOVE APPX
    Root node: JOBREQUEST.RemoveAPPX
    value: state
        "new"/$null "fail" "pass" "validate"
        change state by status and adding error in order to use function:
        Update-JobStatus $jobfile $json $json.JOBREQUEST.RemoveAPPX "fail" $global:MessageResults
    JOBREQUEST.RemoveAPPX.APPXList 
        array to list all Display Name packages
#>

if ($null -ne $json.JOBREQUEST.RemoveAPPX) {
    WriteLog -Message "Remove APPX module, check state to continue" -Verbose
    #JOB request this module
    if (($null -eq $json.JOBREQUEST.RemoveAPPX.status) -OR ($json.JOBREQUEST.RemoveAPPX.status -eq "new")) {
        #process start
        WriteLog -Message "New request, read array to remove by DisplayName property" -Verbose
        if ($null -ne $json.JOBREQUEST.RemoveAPPX.APPXList) {
            $arrAPPXs=$json.JOBREQUEST.RemoveAPPX.APPXList
            #Run Get | Remove
            $NotRemovedAPPXs=[System.Collections.ArrayList]::new() 
            foreach ($appx in $arrAPPXs) {
                if ($null -ne (Get-AppxProvisionedPackage -Path "$($OSDrive)\" | Where-Object {$_.DisplayName -eq $appx})) {
                    WriteLog -Message "Removing $($appx)..." -Verbose
                    #Remove APPX
                    Get-AppxProvisionedPackage -Path "$($OSDrive)\" | Where-Object {$_.DisplayName -eq $appx} | Remove-AppxProvisionedPackage | Out-Host #sending to transcript log
                    #Confirm if persist
                    if ($null -ne (Get-AppxProvisionedPackage -Path "$($OSDrive)\" | Where-Object {$_.DisplayName -eq $appx})) {
                        WriteLog -Message "APPX $($appx) remains" -MessageType Error -Verbose
                        $NotRemovedAPPXs.Add($appx) #Save errors,at end it will list each one
                    } else {
                        WriteLog -Message "Successfully removed $($appx)" -Verbose
                    }

                } else {
                    WriteLog -Message "APPX [$($appx)] is not present on this OS, mark as removed" -MessageType Warning -Verbose
                }
            }
            WriteLog -Message "Creating list of remaining APPX, please check on $((Join-Path $logs "ReportAPPXx_$($OS.Build).csv"))" -Verbose
            Get-AppxProvisionedPackage -Path "$($OSDrive)\" | ConvertTo-Csv | Out-File -FilePath (Join-Path $logs "ReportAPPXx_$($OS.Build).csv") -Encoding ascii -Force
            if ($NotRemovedAPPXs.Count -ne 0) {
                WriteLog -Message "Some APPX were not removed, please check logs" -MessageType Error -Verbose
                $NotRemovedAPPXs | ForEach-Object {WriteLog -Message "Not possible to remove Appx: $($_)" -MessageType Error -Verbose }
                if ($null -eq $json.JOBREQUEST.RemoveAPPX.notremoved) {
                    $json.JOBREQUEST.RemoveAPPX | Add-Member -Name "notremoved" -MemberType NoteProperty -Value $NotRemovedAPPXs
                } else {
                    $json.JOBREQUEST.RemoveAPPX.notremoved=$NotRemovedAPPXs
                }    
                $global:MessageResults="Some APPX were not removed, please check logs"
                $global:CodeResults=2
                Update-JobStatus $jobfile $json $json.JOBREQUEST.RemoveAPPX "fail" $global:MessageResults
                Out-WinPE -Backuplogs -RemoveJob
            }
            WriteLog -Message "APPX were removed, marked to validate during Windows stage" -Verbose
            Update-JobStatus $jobfile $json $json.JOBREQUEST.RemoveAPPX "validate" "Waiting for validation"
        } else {
            WriteLog -Message "List of APPXs doesn't exist, check Job" -MessageType Error -Verbose
            $global:MessageResults="List of APPXs doesn't exist, check Job"
            $global:CodeResults=5
            Out-WinPE -Backuplogs -RemoveJob
        }

    } else {
        if ($json.JOBREQUEST.RemoveAPPX.status -eq "fail") {
            WriteLog -Message "Somenthing fail during APPX removal" -MessageType Error -Verbose
            $global:MessageResults="Somenthing fail during APPX removal"
            $global:CodeResults=1
            Update-JobStatus $jobfile $json $json.JOBREQUEST.RemoveAPPX "fail" $global:MessageResults
            Out-WinPE -Backuplogs -RemoveJob
        } elseif ($json.JOBREQUEST.RemoveAPPX.status -eq "pass") {
            WriteLog -Message "This module already successfully completed" -Verbose
        } elseif ($json.JOBREQUEST.RemoveAPPX.status -eq "validate") {   
            WriteLog -Message "Reach this point and remain as validation as status means that was successfully removed but not Windows stage run (yet or as expected)" -MessageType Warning -Verbose
        } else {
            WriteLog -Message "Error detected on Remove APPX module, state not expected [$($json.JOBREQUEST.RemoveAPPX.status)], check logs" -MessageType Error -Verbose
            $global:MessageResults="Error detected on Remove APPX module, state not expected [$($json.JOBREQUEST.RemoveAPPX.status)], check logs"
            $global:CodeResults=1
            Update-JobStatus $jobfile $json $json.JOBREQUEST.RemoveAPPX "fail" $global:MessageResults
            Out-WinPE -Backuplogs -RemoveJob
        }
    }
} else {
    WriteLog -Message "This module is not required" -Verbose
}