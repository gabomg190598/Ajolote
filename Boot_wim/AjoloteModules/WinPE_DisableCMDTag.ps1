## Find tag or json node
## validate state of tag or node
## Validate that image is ready to be saved
## Execute a command to create a file name DisableCMDRequest.tag
## Change status  new to  pass


if ($null -ne $json.JOBREQUEST.DisableCMDTag) {
    if (($null -ne $json.JOBREQUEST.DisableCMDTag.status) -AND ($json.JOBREQUEST.DisableCMDTag.status.ToLower()) -eq "new") {
        ##Get OS Drive 
        ##Validate image that is ready to be saved and perform the file creation
            ## Add job control
            if ($json.JOBREQUEST.Job.status -eq "save") {
                WriteLog -Message "Module is ready to run -> Status is ready to be Saved" -Verbose
                #Check if path exists if dont create it
                WriteLog -Message "Veryfing that path C:\Windows\Setup\Scripts exists "
                if(!(Test-Path -Path "$($OsDrive)\Windows\Setup\Scripts"))
                {
                    WriteLog -Message "Path does not exist... Creating Path" -Verbose
                    New-Item -Path "$($OsDrive)\Windows\Setup\Scripts" -Name "DisableCMDRequest.tag" -ItemType File -Value "Disable CMD"
                   
                }
                 ## PASS RESULT
                 if (Test-Path -Path "$($OsDrive)\Windows\Setup\Scripts\DisableCMDRequest.tag") {
                    WriteLog -Message "File exists...continuing process"
                 }
                else{
                    WriteLog -Message "Path exists... Creating DisableCMDRequest.Tag" -Verbose
                    New-Item -Path "$($OsDrive)\Windows\Setup\Scripts" -Name "DisableCMDRequest.tag" -ItemType File -Value "Disable CMD" -Force 
                    WriteLog -Message "==============DisableCMDRequest.tag created SUCCESSFULLY==============" -Verbose
    
                    if(!(Test-Path -Path "$($OsDrive)\Windows\Setup\Scripts\DisableCMDRequest.tag")){
                        WriteLog -Message "DisableCMDRequest.tag file does not exist"
                        $Global:MessageResults = "DisableCMDRequest.tag file does not exist... Nothing to do"
                        $Global:CodeResult = 101
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.DisableCMDTag "fail" $Global:MessageResults
                        Out-WinPe -Backuplogs -RemoveJob
                    }            
                }  
                Update-JobStatus $jobfile $json $json.JOBREQUEST.DisableCMDTag "pass" "Tag created succesfully"
                WriteLog -Message "DisableCMDTag module installed succesfully"
                $Global:MessageResults =  "DisableCMDTag module installed succesfully"
                $Global:CodeResult = 0
                ## no - abort with error
            }
        }elseif (($null -ne $json.JOBREQUEST.DisableCMDTag.status) -AND ($json.JOBREQUEST.DisableCMDTag.status.ToLower() -eq "pass")){ 
        WriteLog -Message "DisableCMDTag module already executed" -Verbose
       }elseif(($null -ne $json.JOBREQUEST.DisableCMDTag.status) -AND ($json.JOBREQUEST.DisableCMDTag.status.ToLower() -eq "fail")){
        WriteLog -Message "An Error has occured during DisableCMDTag module"
        $Global:MessageResults = "An Error has occured during DisableCMDTag module"
        $Global:CodeResult = 502
        ## FAIL RESULT
        Update-JobStatus $jobfile $json $json.JOBREQUEST.DisableCMDTag "fail" $Global:MessageResults
        Out-WinPe -Backuplogs -RemoveJob
    
       }elseif(($null -eq $json.JOBREQUEST.DisableCMDTag.status )){
        WriteLog -Message "Status is missing and will not appear in JOB... Nothing to do" -MessageType Warning -Verbose
        $Global:MessageResults = "Status is missing and will not appear in JOB... Nothing to do"
        $Global:CodeResult = 101
        Update-JobStatus $jobfile $json $json.JOBREQUEST.DisableCMDTag "fail" $Global:MessageResults
        Out-WinPe -Backuplogs -RemoveJob
      }else{
        ##All other states that cannot be handled by the script
        WriteLog -Message "There was an unexpected value for status = $($json.JOBREQUEST.DisableCMDTag.status) nothing to do" -MessageType Warning -Verbose
        $Global:MessageResults = "There was an unexpected value for status = $($json.JOBREQUEST.DisableCMDTag.status) nothing to do"
        $Global:CodeResult = 101
        ## FAIL RESULT
        Update-JobStatus $jobfile $json $json.JOBREQUEST.DisableCMDTag "fail" $Global:MessageResults
        Out-WinPe -Backuplogs -RemoveJob
       }
    }
    else {
    WriteLog -Message "DisableCMDTag was not found in the json file" -Verbose
   }
