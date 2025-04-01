<#
.VERSION
    1.1.10 = Move the order of configuration: SetDefaut --> SetTimezone --> RemoveUS
    1.1.9 = Add commands to clean Temp directory after install languages to image and WinRE
    1.1.8 = Adding Windows 11 22631
    1.1.7 = Fix a typo error that prevents to install languages on WinRe
    1.1.6 = Adding new setup for language FOD required by Windows 11
    1.1.5 = fix typo, trim to tag name on codes provided on payload
    1.1.3 = Now process create a couple of arrays on job to reflect installed lanaguages
    1.1.2 = Adding support for Windows 11 22H2
    1.1.1 = Validate languages installed
.DATE
    12/21/2023
.DEVELOPER
    Cisneros Jorge
#>

if ($null -ne $json.JOBREQUEST.Localization) { 
    WriteLog -Message "Localization  was requested" -Verbose
    if (([string]::IsNullOrEmpty($json.JOBREQUEST.Localization.status)) -OR ($json.JOBREQUEST.Localization.status.ToLower() -eq "new")) { 
    #---Define folder name based on build
        if (![string]::IsNullOrEmpty($json.JOBREQUEST.Localization.lpcodes)) {
            switch ($WinVersion) {
                {($_ -eq "1903") -OR ($_ -eq "1909")} { $LPPACK="1900"; $Convert4OS="Windows 10"; break; } #Not used anymore
                {($_ -eq "19041") -OR ($_ -eq "19042") -OR ($_ -eq "19043") -OR ($_ -eq "19044") -OR ($_ -eq "19045")} { $LPPACK="2021"; $Convert4OS="Windows 10"; break; }
                "22000" { $LPPACK="2120"; $Convert4OS="Windows 11"; break; }
                {($_ -eq "22621") -OR ($_ -eq "22631")} { $LPPACK="2202"; $Convert4OS="Windows 11"; break; }
                Default { $LPPACK="0000"; $Convert4OS="Windows 10"; break; }
            }
        #---Validate structure 
            if (!(Test-Path -Path "$($AjoloteDrive)\LANGUAGES\$($LPPACK)" -PathType Container)) {
                WriteLog -Message "Missing required folder: $($AjoloteDrive)\LANGUAGES\$($LPPACK)" -MessageType Error -Verbose
                $global:MessageResults="Missing required folder: $($AjoloteDrive)\LANGUAGES\$($LPPACK)"
                $global:CodeResults=404
                ##### FAIL RESULT
                Update-JobStatus $jobfile $json $json.JOBREQUEST.Localization "fail" $global:MessageResults                
                Out-WinPE -Backuplogs -RemoveJob
            }
            $LPRepository="$($AjoloteDrive)\LANGUAGES\$($LPPACK)\LanguagePack"
            $EPRespository="$($AjoloteDrive)\LANGUAGES\$($LPPACK)\LocalExperiencePack"
            $WinPERepository="$($AjoloteDrive)\LANGUAGES\$($LPPACK)\WinPE_OCs"
            
            if (!(Test-Path -Path $LPRepository -PathType Container)) {
                WriteLog -Message "Missing required folder: $($LPRepository)" -MessageType Error -Verbose
                $global:MessageResults="Missing required folder: $($LPRepository)"
                $global:CodeResults=404
                ##### FAIL RESULT
                Update-JobStatus $jobfile $json $json.JOBREQUEST.Localization "fail" $global:MessageResults
                Out-WinPE -Backuplogs -RemoveJob
            }
            if (!(Test-Path -Path $EPRespository -PathType Container)) {
                WriteLog -Message "Missing required folder: $($EPRespository)" -MessageType Error -Verbose
                $global:MessageResults="Missing required folder: $($EPRespository)"
                $global:CodeResults=404
                ##### FAIL RESULT
                Update-JobStatus $jobfile $json $json.JOBREQUEST.Localization "fail" $global:MessageResults
                Out-WinPE -Backuplogs -RemoveJob
            }
            if (!(Test-Path -Path $WinPERepository -PathType Container)) {
                WriteLog -Message "Missing required folder: $($WinPERepository)" -MessageType Error -Verbose
                $global:MessageResults="Missing required folder: $($WinPERepository)"
                $global:CodeResults=404
                ##### FAIL RESULT
                Update-JobStatus $jobfile $json $json.JOBREQUEST.Localization "fail" $global:MessageResults
                Out-WinPE -Backuplogs -RemoveJob
            }
            WriteLog -Message "           Language Pack repository: $($LPRepository)" -Verbose
            WriteLog -Message "Language Experience Pack repository: $($EPRespository)" -Verbose
            WriteLog -Message "     WinPE Language Pack repository: $($WinPERepository)" -Verbose
            #WriteLog -Message "         Inbox Apps Pack repository: $($InboxAppRepository)" -Verbose
        #---list all codes required
            if ($json.JOBREQUEST.Localization.lpcodes.Trim().Tolower().Contains("en-us") -OR $json.JOBREQUEST.Localization.lpcodes.Trim().Tolower().Contains("English (United States)")) {
                WriteLog -Message "EN-US is base language don't need to be added" -MessageType Warning -Verbose
            } 

            #read and validate all language who must be in Tag format
            [string[]]$CurrentLanguagesJob=$json.JOBREQUEST.Localization.lpcodes
            WriteLog -Message "Detected $($CurrentLanguagesJob.Count) languages on Job file" -Verbose
            #create initialize array
            $LanguagesCodes = [System.Collections.ArrayList]::new()
            $LPInstalled = [System.Collections.ArrayList]::new()
            $LIPInstalled = [System.Collections.ArrayList]::new()
            #check each item and if not include '-' it will convert
            foreach ($lang in $CurrentLanguagesJob) {
                if ($lang.Contains("-")) {
                    WriteLog -Message "Valid language tag: [$($lang.Trim())]" -Verbose
                    if ($lang.Tolower().Trim() -eq "en-us") {
                        WriteLog -Message "US english is base image language and doesn't required to added again" -MessageType Warning -Verbose
                    } else {
                        [void]$LanguagesCodes.Add($lang.Trim())
                    }                    
                } else {
                    WriteLog -Message "Need to get tag value from: $($lang)" -Verbose
                    $convertag=Convert-Languagtag -InputLanguage $lang -WindowsEdition $Convert4OS
                    if ($null -eq $convertag) {
                        WriteLog -Message "Incorrect language requested or cannot locate it Tag value for $($region)" -MessageType Error -Verbose
                        $global:MessageResults="Incorrect language requested or cannot locate it Tag value for $($region)"
                        $global:CodeResults=404
                        ##### FAIL RESULT
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.Localization "fail" $global:MessageResults
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                    if ($convertag.Tag.ToLower() -ne "en-us") {
                        [void]$LanguagesCodes.Add($convertag.Tag)
                    } else {
                        WriteLog -Message "US english is base image language and doesn't required to added again" -MessageType Warning -Verbose
                    }
                }
            }            
            
            if ($LanguagesCodes.Count -lt 1) {
                #FOR NOW IF THERE ARE NO TAGS DETECTED IT IS NOT MARKED AS AN ISSUE
                WriteLog -Message "Not single language tag was detected to be installed in $($json.JOBREQUEST.Localization.lpcodes.Trim())" -MessageType Warning -Verbose
                #$global:MessageResults="Not single language tag was detected to be installed in  $($json.JOBREQUEST.Localization.lpcodes.Trim())"
                #$global:CodeResults=405
                ##### FAIL RESULT
                #Update-JobStatus $jobfile $json $json.JOBREQUEST.Localization "fail" $global:MessageResults
                #Out-WinPE -Backuplogs -RemoveJob
            } else {
                WriteLog -Message "Updating Job to reflect any possible change on language request" -Verbose
                $json.JOBREQUEST.Localization.lpcodes=$LanguagesCodes
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
            }
            $LanguagesCodes | ForEach-Object {WriteLog -Message "Language code requested: $($_)" -Verbose }
            foreach ($code in $LanguagesCodes) {
            ###--- LANGUAGE PACK SETUP
                ##--Starting on Windows 11 22H2 22621 some LIPS are delivered as CAB file, now are included on search
                $codeislip=$false
                WriteLog -Message "Try to search $($code) in LPs as CAB files" -Verbose
                $findcab=Get-ChildItem -Path $LPRepository -File | Where-Object {$_.Name -like "*Windows-Client-Language*$($code)*"}
                if ($null -eq $findcab) {
                    WriteLog -Message "Try to search $($code) in LIPs as CAB files" -Verbose
                    $findcab=Get-ChildItem -Path $LPRepository -File | Where-Object {$_.Name -like "*Windows-Lip-Language-Pack*$($code)*"}
                    $codeislip=$true
                }
                
                #search for Language FOD
                $PackagePath_FOD=""
                if ($null -ne $findcab) {
                    WriteLog -Message "LP detected, searching for language FOD capabilities..." -Verbose
                    #Microsoft-Windows-LanguageFeatures-Basic-af-za-Package~31bf3856ad364e35~amd64~~.cab
                    $get_lpfod=Get-ChildItem -Path $LPRepository -File | Where-Object {$_.Name -like "*Microsoft-Windows-LanguageFeatures-Basic*$($code)*"}
                    if ($null -ne $get_lpfod) {
                        WriteLog -Message "Language FOD detected: $($get_lpfod[0].Name)" -Verbose
                        $PackagePath_FOD += " /PackagePath:$($get_lpfod[0].FullName)"
                    }
                    #Microsoft-Windows-LanguageFeatures-Handwriting-af-za-Package~31bf3856ad364e35~amd64~~.cab
                    Remove-Variable -Name get_lpfod -Force -ErrorAction SilentlyContinue
                    $get_lpfod=Get-ChildItem -Path $LPRepository -File | Where-Object {$_.Name -like "*Microsoft-Windows-LanguageFeatures-Handwriting*$($code)*"}
                    if ($null -ne $get_lpfod) {
                        WriteLog -Message "Language FOD detected: $($get_lpfod[0].Name)" -Verbose
                        $PackagePath_FOD += " /PackagePath:$($get_lpfod[0].FullName)"
                    }
                    #Microsoft-Windows-LanguageFeatures-OCR-ar-sa-Package~31bf3856ad364e35~amd64~~.cab
                    Remove-Variable -Name get_lpfod -Force -ErrorAction SilentlyContinue
                    $get_lpfod=Get-ChildItem -Path $LPRepository -File | Where-Object {$_.Name -like "*Microsoft-Windows-LanguageFeatures-OCR*$($code)*"}
                    if ($null -ne $get_lpfod) {
                        WriteLog -Message "Language FOD detected: $($get_lpfod[0].Name)" -Verbose
                        $PackagePath_FOD += " /PackagePath:$($get_lpfod[0].FullName)"
                    }
                    #Microsoft-Windows-LanguageFeatures-Speech-da-dk-Package~31bf3856ad364e35~amd64~~.cab
                    Remove-Variable -Name get_lpfod -Force -ErrorAction SilentlyContinue
                    $get_lpfod=Get-ChildItem -Path $LPRepository -File | Where-Object {$_.Name -like "*Microsoft-Windows-LanguageFeatures-Speech*$($code)*"}
                    if ($null -ne $get_lpfod) {
                        WriteLog -Message "Language FOD detected: $($get_lpfod[0].Name)" -Verbose
                        $PackagePath_FOD += " /PackagePath:$($get_lpfod[0].FullName)"
                    }
                    #Microsoft-Windows-LanguageFeatures-TextToSpeech-ar-eg-Package~31bf3856ad364e35~amd64~~.cab
                    Remove-Variable -Name get_lpfod -Force -ErrorAction SilentlyContinue
                    $get_lpfod=Get-ChildItem -Path $LPRepository -File | Where-Object {$_.Name -like "*Microsoft-Windows-LanguageFeatures-TextToSpeech*$($code)*"}
                    if ($null -ne $get_lpfod) {
                        WriteLog -Message "Language FOD detected: $($get_lpfod[0].Name)" -Verbose
                        $PackagePath_FOD += " /PackagePath:$($get_lpfod[0].FullName)"
                    }
                    WriteLog -Message "Language FOD to be installed: $($PackagePath_FOD)" -Verbose
                }  

                if ($null -ne $findcab) {
                    WriteLog -Message "[+] Injecting LP: $($findcab[0].Name)" -Verbose
                    $ApplyLP = RunDism -Params "/image:$($OSDrive)\ /scratchdir:$($OSDrive)\ /add-package /packagepath:$($findcab[0].FullName)$($PackagePath_FOD)" -WorkDir "$($PSScriptRoot)\" -OutFile "$($logs)\DismLP_$($findcab[0].Name).log" -Verbose
                    if ($ApplyLP -ne 0) {
                        WriteLog -Message "Unexpected code found injecting Language pack $($findcab[0].Name)" -MessageType Error -Verbose
                        $global:MessageResults="Unexpected code found injecting Language pack $($findcab[0].Name)"
                        $global:CodeResults=$ApplyLP
                        ##### FAIL RESULT
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.Localization "fail" $global:MessageResults
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                    if ($codeislip) {
                        [void]$LIPInstalled.Add($code)
                    } else {
                        [void]$LPInstalled.Add($code)
                    }
                    
                } else {
                    WriteLog -Message "Not detected Language Pack for $($code)" -MessageType Warning -Verbose
                }
            ###--- LIP SEUP / Experience Pack
                $lip=Get-ChildItem -Path $EPRespository -Directory | Where-Object {$_.Name -eq $code}
                if ($null -ne $lip) {
                    WriteLog -Message "Found Local Experience pack for $($code)" -Verbose
                    foreach ($appx in (Get-ChildItem -Path $lip[0].FullName -Filter "*.appx" -File)) {
                        WriteLog -Message "[+] Installing Local Experience Pack: $($appx.Name)" -Verbose
                        $InjectLIP=RunDism -Params "/Image:$($OSDrive)\ /ScratchDir:$($OSDrive)\ /Add-ProvisionedAppxPackage /PackagePath:""$($appx.FullName)"" /LicensePath:""$($lip[0].FullName)\License.xml""" -WorkDir "$($EPRespository)\" -OutFile "$($logs)\Dism_LIP_$($code).log" -Verbose
                        if ($InjectLIP -ne 0) { 
                            WriteLog -Message "Local Experience pack fail installing: $($appx.Name)" -MessageType Error -Verbose; 
                            $global:MessageResults="Local Experience pack fail installing: $($appx.Name)"
                            $global:CodeResults=$InjectLIP
                            ##### FAIL RESULT
                            Update-JobStatus $jobfile $json $json.JOBREQUEST.Localization "fail" $global:MessageResults
                            Out-WinPE -Backuplogs -RemoveJob
                        }                        
                    }
                    if (-Not($LIPInstalled.Contains($code))) { [void]$LIPInstalled.Add($code) }
                    
                } else {
                    WriteLog -Message "Not detected Language Experience Pack for $($code)" -MessageType Warning -Verbose
                }
            #---- FOD LANGUAGE SETUP
                $Capabilities=""
                switch ($code) {
                    {Get-ChildItem -Path $LPRepository -File | Where-Object {$_.Name -like "*LanguageFeatures-Basic*$($code)*"}} { $Capabilities+="/capabilityname:Language.Basic~~~$($code)~0.0.1.0 " }
                    {Get-ChildItem -Path $LPRepository -File | Where-Object {$_.Name -like "*LanguageFeatures-Handwriting*$($code)*"}} { $Capabilities+="/capabilityname:Language.Handwriting~~~$($code)~0.0.1.0 " }
                    {Get-ChildItem -Path $LPRepository -File | Where-Object {$_.Name -like "*LanguageFeatures-OCR*$($code)*"}} { $Capabilities+="/capabilityname:Language.OCR~~~$($code)~0.0.1.0 " }
                    {Get-ChildItem -Path $LPRepository -File | Where-Object {$_.Name -like "*LanguageFeatures-Speech*$($code)*"}} { $Capabilities+="/capabilityname:Language.Speech~~~$($code)~0.0.1.0 " }
                    {Get-ChildItem -Path $LPRepository -File | Where-Object {$_.Name -like "*LanguageFeatures-TextToSpeech*$($code)*"}} { $Capabilities+="/capabilityname:Language.TextToSpeech~~~$($code)~0.0.1.0 " }
                    "am-et" { $Capabilities+="/capabilityname:Language.Fonts.Ethi~~~und-ETHI~0.0.1.0 "; break; }
                    "ar-sa" { $Capabilities+="/capabilityname:Language.Fonts.Arab~~~und-ARAB~0.0.1.0 "; break; }
                    "ar-sy" { $Capabilities+="/capabilityname:Language.Fonts.Syrc~~~und-SYRC~0.0.1.0 "; break; }
                    "as-in" { $Capabilities+="/capabilityname:Language.Fonts.Beng~~~und-BENG~0.0.1.0 "; break; }
                    "bn-bd" { $Capabilities+="/capabilityname:Language.Fonts.Beng~~~und-BENG~0.0.1.0 "; break; }
                    "bn-in" { $Capabilities+="/capabilityname:Language.Fonts.Beng~~~und-BENG~0.0.1.0 "; break; }
                    "chr-cher-us" { $Capabilities+="/capabilityname:Language.Fonts.Cher~~~und-CHER~0.0.1.0 "; break; }
                    "fa-ir" { $Capabilities+="/capabilityname:Language.Fonts.Arab~~~und-ARAB~0.0.1.0 "; break; }
                    "gu-in" { $Capabilities+="/capabilityname:Language.Fonts.Gujr~~~und-GUJR~0.0.1.0 "; break; }
                    "he-il" { $Capabilities+="/capabilityname:Language.Fonts.Hebr~~~und-HEBR~0.0.1.0 "; break; }
                    "hi-in" { $Capabilities+="/capabilityname:Language.Fonts.Deva~~~und-DEVA~0.0.1.0 "; break; }
                    "ja-jp" { $Capabilities+="/capabilityname:Language.Fonts.Jpan~~~und-JPAN~0.0.1.0 "; break; }
                    "km-kh" { $Capabilities+="/capabilityname:Language.Fonts.Khmr~~~und-KHMR~0.0.1.0 "; break; }
                    "kn-in" { $Capabilities+="/capabilityname:Language.Fonts.Knda~~~und-KNDA~0.0.1.0 "; break; }
                    "kok-in" { $Capabilities+="/capabilityname:Language.Fonts.Deva~~~und-DEVA~0.0.1.0 "; break; }
                    "ko-kr" { $Capabilities+="/capabilityname:Language.Fonts.Kore~~~und-KORE~0.0.1.0 "; break; }
                    "ku-arab-iq" { $Capabilities+="/capabilityname:Language.Fonts.Arab~~~und-ARAB~0.0.1.0 "; break; }
                    "lo-la" { $Capabilities+="/capabilityname:Language.Fonts.Laoo~~~und-LAOO~0.0.1.0 "; break; }
                    "ml-in" { $Capabilities+="/capabilityname:Language.Fonts.Mlym~~~und-MLYM~0.0.1.0 "; break; }
                    "mr-in" { $Capabilities+="/capabilityname:Language.Fonts.Deva~~~und-DEVA~0.0.1.0 "; break; }
                    "ne-np" { $Capabilities+="/capabilityname:Language.Fonts.Deva~~~und-DEVA~0.0.1.0 "; break; }
                    "or-in" { $Capabilities+="/capabilityname:Language.Fonts.Orya~~~und-ORYA~0.0.1.0 "; break; }
                    "pa-arab-pk" { $Capabilities+="/capabilityname:Language.Fonts.Arab~~~und-ARAB~0.0.1.0 "; break; }
                    "pa-in" { $Capabilities+="/capabilityname:Language.Fonts.Guru~~~und-GURU~0.0.1.0 "; break; }
                    "prs-af" { $Capabilities+="/capabilityname:Language.Fonts.Arab~~~und-ARAB~0.0.1.0 "; break; }
                    "sd-arab-pk" { $Capabilities+="/capabilityname:Language.Fonts.Arab~~~und-ARAB~0.0.1.0 "; break; }
                    "si-lk" { $Capabilities+="/capabilityname:Language.Fonts.Sinh~~~und-SINH~0.0.1.0 "; break; }
                    "syr-sy" { $Capabilities+="/capabilityname:Language.Fonts.Syrc~~~und-SYRC~0.0.1.0 "; break; }
                    "ta-in" { $Capabilities+="/capabilityname:Language.Fonts.Taml~~~und-TAML~0.0.1.0 "; break; }
                    "te-in" { $Capabilities+="/capabilityname:Language.Fonts.Telu~~~und-TELU~0.0.1.0 "; break; }
                    "th-th" { $Capabilities+="/capabilityname:Language.Fonts.Thai~~~und-THAI~0.0.1.0 "; break; }
                    "ti-et" { $Capabilities+="/capabilityname:Language.Fonts.Ethi~~~und-ETHI~0.0.1.0 "; break; }
                    "ug-cn" { $Capabilities+="/capabilityname:Language.Fonts.Arab~~~und-ARAB~0.0.1.0 "; break; }
                    "ur-pk" { $Capabilities+="/capabilityname:Language.Fonts.Arab~~~und-ARAB~0.0.1.0 "; break; }
                    "zh-cn" { $Capabilities+="/capabilityname:Language.Fonts.Hans~~~und-HANS~0.0.1.0 "; break; }
                    "zh-tw" { $Capabilities+="/capabilityname:Language.Fonts.Hant~~~und-HANT~0.0.1.0 "; break; }
                    Default { WriteLog -Message "This Language ($($code)) doesn't require fonts"; break;}
                }
                if ($Capabilities.Length -gt 16) {
                    WriteLog -Message "[+] Adding Language Feature On Demand" -Verbose
                    $AddFDO = RunDism -Params "/Image:$($OSDrive)\ /ScratchDir:$($OSDrive)\ /Add-Capability $($Capabilities) /source:""$($LPRepository)""" -WorkDir $LPRepository -OutFile "$($logs)\Dism_AddFOD_$($code).log" -Verbose
                    if ($AddFDO -ne 0) { 
                        WriteLog -Message "Fail add Feature On Demand for code $($code)" -MessageType Error -Verbose; 
                        $global:MessageResults="Fail add Feature On Demand for code $($code)"
                        $global:CodeResults=$AddFDO
                        ##### FAIL RESULT
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.Localization "fail" $global:MessageResults
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                } else {
                    WriteLog -Message "No capabilities found for code $($code)" -Verbose
                }
                #--- Specific FOD desired
                [string[]] $ListAddFOD = @(
                    "Windows-InternetExplorer-Optional",
                    "WirelessDisplay-FOD-Package"
                )
                foreach ($addfod in $ListAddFOD) {
                    $speFOD=Get-ChildItem -Path $LPRepository -File | Where-Object {$_.Name -like "*$($addfod)*$($code)*"}
                    if ($null -ne $speFOD) {
                        WriteLog -Message "[+] Found Additional FOD for $($code): $($speFOD[0].Name)" -Verbose
                        $InjectAFOD=RunDism -Params "/Image:$($OSDrive)\ /ScratchDir:$($OSDrive)\ /Add-Package /PackagePath:""$($speFOD[0].FullName)""" -WorkDir "$($LPRepository)\" -OutFile "$($Logs)\Dism_AddFOD_$($code).log" -Verbose
                        if ($InjectAFOD -ne 0) { 
                            WriteLog -Message "Fail injecting additional FOD: $($speFOD[0].Name) return error" -MessageType Error -Verbose; 
                            $global:MessageResults="Fail injecting additional FOD: $($speFOD[0].Name) return error"
                            $global:CodeResults=$InjectAFOD
                            ##### FAIL RESULT
                            Update-JobStatus $jobfile $json $json.JOBREQUEST.Localization "fail" $global:MessageResults
                            Out-WinPE -Backuplogs -RemoveJob
                        }
                    } else {
                        WriteLog -Message "There are no additional FOD in $($code) for $($addfod)" -MessageType Warning -Verbose
                    }
                }
            } #End Setup LPs
            
        ###---- Validating installed langauges
            if (($LPInstalled.Count -gt 0) -OR ($LIPInstalled.Count -gt 0)) {
                ## Adding installed languages to Job
                WriteLog -Message "Updating Job installed languages" -Verbose
                if ($null -eq $json.JOBREQUEST.Localization.lpinstalled) {
                    $json.JOBREQUEST.Localization | Add-Member -Name "lpinstalled" -MemberType NoteProperty -Value $LPInstalled
                } else {
                    $json.JOBREQUEST.Localization.lpinstalled=$LPInstalled
                }
                if ($null -eq $json.JOBREQUEST.Localization.lipinstalled) {
                    $json.JOBREQUEST.Localization | Add-Member -Name "lipinstalled" -MemberType NoteProperty -Value $LIPInstalled
                } else {
                    $json.JOBREQUEST.Localization.lipinstalled=$LIPInstalled
                }
                #Save job
                try {
                    $json | ConvertTo-Json -Depth 16 | Out-File -FilePath $jobfile -Encoding ascii -Force
                }
                catch {
                    $ErrorMessage = $_.Exception.Message
                    WriteLog -Message "Failed updating JOB file: $($ErrorMessage)" -MessageType Error -Verbose
                    $global:MessageResults="Failed updating JOB file: $($ErrorMessage)"
                    $global:CodeResults=209
                    Out-WinPE -Backuplogs -RemoveJob
                }
                if ($LPInstalled.Count -eq $LanguagesCodes.Count) {
                    WriteLog -Message "All Language Packs were installed successfully on image" -Verbose
                } elseif ($LIPInstalled.Count -eq $LanguagesCodes.Count) {
                    WriteLog -Message "All Language Interface Packs were installed successfully on image" -Verbose                    
                } else {
                    $errorlp=$false
                    foreach ($rlp in $LanguagesCodes) {
                        $foundlp=$false
                        foreach ($ilp in $LPInstalled) {
                            if ($rlp.ToString().ToLower() -eq $ilp.ToString().ToLower()) {
                                WriteLog -Message "Language $($rlp) installed successfully" -Verbose
                                $foundlp=$true
                            }
                        }
                        foreach ($ilp in $LIPInstalled) {
                            if ($rlp.ToString().ToLower() -eq $ilp.ToString().ToLower()) {
                                WriteLog -Message "Language Interface $($rlp) installed successfully" -Verbose
                                $foundlp=$true
                            }
                        }
                        if (-Not($foundlp)) {
                            WriteLog -Message "Failed to install language $($rlp)" -MessageType Error -Verbose
                            $errorlp=$true
                        }
                    }
                    if ($errorlp) {
                        WriteLog -Message "At least one language was not successfully installed, please check logs" -MessageType Error -Verbose
                        $global:MessageResults="At least one language was not successfully installed, please check logs"
                        $global:CodeResults=501
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                }


            } else {
                WriteLog -Message "There are no languages installed, checking if this is an issue" -Verbose
                if ($LanguagesCodes.Count -gt 0) {
                    WriteLog -Message "There were requestes languages to install, seems like all failed, please check logs" -MessageType Error -Verbose
                    $global:MessageResults="There were requestes languages to install, seems like all failed, please check logs"
                    $global:CodeResults=500
                    Out-WinPE -Backuplogs -RemoveJob
                }
                if ($LanguagesCodes.Count -eq 0) {
                    WriteLog -Message "No languages was requested or at least was not possible to identify using provided payload, by now this is not an issue" -MessageType Warning -Verbose
                }
            }
            ####----- WINRE SETUP
            if (Test-Path -Path  (Join-Path $OSDrive "\Windows\System32\Recovery\winre.wim") -PathType Leaf) {
                $TempFolder="mntwinre"
                WriteLog -Message "Create Temp Folder" -Verbose
				if (!(Test-Path -Path (Join-Path $OSDrive $TempFolder) -PathType Container)) {New-Item -Path (Join-Path $OSDrive $TempFolder) -ItemType Directory -Force; }
				WriteLog -Message "Mounting WinRE image" -Verbose
				$MountWinRE=RunDism -Params "/Mount-Image /ImageFile:""$((Join-Path $OSDrive "\Windows\System32\Recovery\winre.wim"))"" /index:1 /MountDir:""$(Join-Path $OSDrive $TempFolder)""" -WorkDir "$($PSScriptRoot)\" -OutFile "$($Logs)\MountWinRE.log" -Verbose
				if ($MountWinRE -ne 0) {
                    WriteLog -Message "Not possible mount WinRE image to perform changes" -MessageType Error -Verbose; 
                    $global:MessageResults="Not possible mount WinRE image to perform changes"
                    $global:CodeResults=$MountWinRE
                    ##### FAIL RESULT
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.Localization "fail" $global:MessageResults
                    Out-WinPE -Backuplogs -RemoveJob
                }
                foreach ($code in $LanguagesCodes) {
                    WriteLog -Message "[+] Installing WinPE language code: $($code)" -Verbose
                    $lp=Get-ChildItem -Path $WinPERepository -Directory | Where-Object {$_.Name -like "*$($code)*"}
                    if ($null -ne $lp) {
                        WriteLog -Message "Found OCs for $($code)" -Verbose
                        $resulta=0
                        $InjectLP=RunDism -Params "/Image:$($OSDrive)\mntwinre /ScratchDir:$($OSDrive)\ /Add-Package /PackagePath:""$($lp[0].FullName)\lp.cab""" -WorkDir "$($lp[0].FullName)\" -OutFile "$($logs)\Dism_WinPELP_$($code).log" -Verbose
                        if($InjectLP -ne 0) { $resulta=$InjectLP}							
                        $InjectLP=RunDism -Params "/Image:$($OSDrive)\mntwinre /ScratchDir:$($OSDrive)\ /Add-Package /PackagePath:""$($lp[0].FullName)\WinPE-Rejuv_$($code).cab""" -WorkDir "$($lp[0].FullName)\" -OutFile "$($logs)\Dism_WinPELP_$($code).log" -Verbose
                        if($InjectLP -ne 0) { $resulta=$InjectLP}
                        $InjectLP=RunDism -Params "/Image:$($OSDrive)\mntwinre /ScratchDir:$($OSDrive)\ /Add-Package /PackagePath:""$($lp[0].FullName)\WinPE-EnhancedStorage_$($code).cab""" -WorkDir "$($lp[0].FullName)\" -OutFile "$($logs)\Dism_WinPELP_$($code).log" -Verbose
                        if($InjectLP -ne 0) { $resulta=$InjectLP}
                        $InjectLP=RunDism -Params "/Image:$($OSDrive)\mntwinre /ScratchDir:$($OSDrive)\ /Add-Package /PackagePath:""$($lp[0].FullName)\WinPE-Scripting_$($code).cab""" -WorkDir "$($lp[0].FullName)\" -OutFile "$($logs)\Dism_WinPELP_$($code).log" -Verbose
                        if($InjectLP -ne 0) { $resulta=$InjectLP}
                        $InjectLP=RunDism -Params "/Image:$($OSDrive)\mntwinre /ScratchDir:$($OSDrive)\ /Add-Package /PackagePath:""$($lp[0].FullName)\WinPE-SecureStartup_$($code).cab""" -WorkDir "$($lp[0].FullName)\" -OutFile "$($logs)\Dism_WinPELP_$($code).log" -Verbose
                        if($InjectLP -ne 0) { $resulta=$InjectLP}
                        $InjectLP=RunDism -Params "/Image:$($OSDrive)\mntwinre /ScratchDir:$($OSDrive)\ /Add-Package /PackagePath:""$($lp[0].FullName)\WinPE-SRT_$($code).cab""" -WorkDir "$($lp[0].FullName)\" -OutFile "$($logs)\Dism_WinPELP_$($code).log" -Verbose
                        if($InjectLP -ne 0) { $resulta=$InjectLP}
                        $InjectLP=RunDism -Params "/Image:$($OSDrive)\mntwinre /ScratchDir:$($OSDrive)\ /Add-Package /PackagePath:""$($lp[0].FullName)\WinPE-WDS-Tools_$($code).cab""" -WorkDir "$($lp[0].FullName)\" -OutFile "$($logs)\Dism_WinPELP_$($code).log" -Verbose
                        if($InjectLP -ne 0) { $resulta=$InjectLP}
                        $InjectLP=RunDism -Params "/Image:$($OSDrive)\mntwinre /ScratchDir:$($OSDrive)\ /Add-Package /PackagePath:""$($lp[0].FullName)\WinPE-WMI_$($code).cab""" -WorkDir "$($lp[0].FullName)\" -OutFile "$($logs)\Dism_WinPELP_$($code).log" -Verbose
                        if($InjectLP -ne 0) { $resulta=$InjectLP}
                        $InjectLP=RunDism -Params "/Image:$($OSDrive)\mntwinre /ScratchDir:$($OSDrive)\ /Add-Package /PackagePath:""$($lp[0].FullName)\WinPE-StorageWMI_$($code).cab""" -WorkDir "$($lp[0].FullName)\" -OutFile "$($logs)\Dism_WinPELP_$($code).log" -Verbose
                        if($InjectLP -ne 0) { $resulta=$InjectLP}
                        $InjectLP=RunDism -Params "/Image:$($OSDrive)\mntwinre /ScratchDir:$($OSDrive)\ /Add-Package /PackagePath:""$($lp[0].FullName)\WinPE-HTA_$($code).cab""" -WorkDir "$($lp[0].FullName)\" -OutFile "$($logs)\Dism_WinPELP_$($code).log" -Verbose
                        if($InjectLP -ne 0) { $resulta=$InjectLP}						
                        if ($resulta -ne 0) { 
                            WriteLog -Message "Inject WinPE Language Pack: $($lp[0].Name) return error" -MessageType Error -Verbose; 
                            $global:MessageResults="Inject WinPE Language Pack: $($lp[0].Name) return error"
                            $global:CodeResults=$resulta
                            ##### FAIL RESULT
                            Update-JobStatus $jobfile $json $json.JOBREQUEST.Localization "fail" $global:MessageResults
                            Out-WinPE -Backuplogs -RemoveJob
                        }
                        
                    } else {
                        WriteLog -Message "It was not possible to locate LP $($code)" -MessageType Warning -Verbose
                    }
                }
                WriteLog -Message "Try to cleaunup WinRE image to reduce size" -Verbose
                $null=RunDism -Params "/image:""$(Join-Path $OSDrive $TempFolder)"" /Cleanup-Image /StartComponentCleanup" -WorkDir "$($PSScriptRoot)\" -OutFile "$($Logs)\CleanupWinRE.log" -Verbose
                $UnMountWinRE=RunDism -Params "/UnMount-Image /MountDir:""$(Join-Path $OSDrive $TempFolder)"" /Commit" -WorkDir "$($PSScriptRoot)\" -OutFile "$($Logs)\UnMountWinRE.log" -Verbose
                if ($UnMountWinRE -ne 0) {
                    WriteLog -Message "Not possible Save changes on WinRE image" -MessageType Error -Verbose; 
                    $global:MessageResults="Not possible Save changes on WinRE image"
                    $global:CodeResults=$UnMountWinRE
                    ##### FAIL RESULT
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.Localization "fail" $global:MessageResults
                    Out-WinPE -Backuplogs -RemoveJob
                }
                WriteLog -Message "Optimizing WinRE image, exporting" -Verbose
                $ExportWinRE=RunDism -Params "/export-image /sourceimagefile:""$((Join-Path $OSDrive "\Windows\System32\Recovery\winre.wim"))"" /sourceindex:1 /DestinationImageFile:""$($OSDrive)\windows\system32\recovery\winre_opt.wim""" -WorkDir "$($PSScriptRoot)\" -OutFile "$($Logs)\ExportWinRE.log" -Verbose
                if ($ExportWinRE -ne 0) {
                    WriteLog -Message "Not possible Export WinRE file" -MessageType Error -Verbose; 
                    $global:MessageResults="Not possible Export WinRE file"
                    $global:CodeResults=$ExportWinRE
                    ##### FAIL RESULT
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.Localization "fail" $global:MessageResults
                    Out-WinPE -Backuplogs -RemoveJob
                }
                if (Test-Path -Path "$($OSDrive)\windows\system32\recovery\winre_opt.wim" -PathType Leaf) {
                    Remove-Item -Path (Join-Path $OSDrive "\Windows\System32\Recovery\winre.wim") -Force 
                    Rename-Item -Path "$($OSDrive)\windows\system32\recovery\winre_opt.wim" -NewName "winre.wim" -Force
                }                
                if (!(Test-Path -Path (Join-Path $OSDrive "\Windows\System32\Recovery\winre.wim") -PathType Leaf)) {
                    WriteLog -Message "Not possible locate WinRE file" -MessageType Error -Verbose; 
                    $global:MessageResults="Not possible locate WinRE file"
                    $global:CodeResults=224
                    ##### FAIL RESULT
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.Localization "fail" $global:MessageResults
                    Out-WinPE -Backuplogs -RemoveJob
                }
                if (Test-Path -Path (Join-Path $OSDrive $TempFolder) -PathType Container) { Remove-Item (Join-Path $OSDrive $TempFolder) -Force -Recurse }
            }

        } else {
            WriteLog -Message "Not required to add more languages, continue" -Verbose
        }
        
       
        ##---Default language / internationalization configuration
        if (![string]::IsNullOrEmpty($json.JOBREQUEST.Localization.defaultlanguage)) { 
            $RequestDefaultCode=$json.JOBREQUEST.Localization.defaultlanguage.Trim().ToLower()
            WriteLog -Message "Default language code requested: $($RequestDefaultCode), validating..." -Verbose
            if ($RequestDefaultCode -eq 'en-us') {
                WriteLog -Message "Default base language is en-US, not need to change" -Verbose
            } else {
                $ContainsLP=$json.JOBREQUEST.Localization.lpcodes.Trim().Tolower().Contains($RequestDefaultCode)
                if (!($ContainsLP)) {
                    WriteLog -Message "Impossible to set default language that was not installed, review languages requested" -MessageType Error -Verbose
                    $global:MessageResults="Impossible to set default language that was not installed, review languages requested"
                    $global:CodeResults=223
                    ##### FAIL RESULT
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.Localization "fail" $global:MessageResults
                    Out-WinPE -Backuplogs -RemoveJob
                } else {
                    $SetInt = Invoke-RunPower -File "dism.exe" -Params "/Image:$($OSDrive)\ /Set-AllIntl:$($RequestDefaultCode)" -WorkDir $PSScriptRoot -OutFile "$($Logs)\SetDefaultOS.log" -Verbose
					if ($SetInt -ne 0) { 
                        WriteLog -Message "Not possible to configure International settings to $($RequestDefaultCode)" -MessageType Error -Verbose; 
                        $global:MessageResults="Not possible to configure International settings to $($RequestDefaultCode)"
                        $global:CodeResults=$SetInt
                        ##### FAIL RESULT
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.Localization "fail" $global:MessageResults
                        Out-WinPE -Backuplogs -RemoveJob
                    }
					
                }
            }

        }
         #TIMEZONE
        if (![string]::IsNullOrEmpty($json.JOBREQUEST.Localization.timezone)) { 
            $TimeZone=$json.JOBREQUEST.Localization.timezone.Trim()
            WriteLog -Message "Required to set TimeZone to $($TimeZone)" -Verbose
            $SetTimeZone = Invoke-RunPower -File "dism.exe" -Params "/Image:$($OSDrive)\ /Set-TimeZone:""$($TimeZone)""" -WorkDir $PSScriptRoot -OutFile "$($Logs)\SetTimeZoneOS.log" -Verbose
			if ($SetTimeZone -ne 0) {
                WriteLog -Message "Not possible set Timezone to [$($TimeZone)]" -MessageType Error -Verbose; 
                $global:MessageResults="Not possible set Timezone to [$($TimeZone)]"
                $global:CodeResults=222
                ##### FAIL RESULT
                Update-JobStatus $jobfile $json $json.JOBREQUEST.Localization "fail" $global:MessageResults
                Out-WinPE -Backuplogs -RemoveJob
            }
        }

        ##--- Remove EN-US
        if ($null -ne $json.JOBREQUEST.Localization.removeus) {
            if ($json.JOBREQUEST.Localization.removeus) {
                WriteLog -Message "Remove en-US is requested, validating..." -Verbose
                try {
                    $RequestDefaultCode=$json.JOBREQUEST.Localization.defaultlanguage.Trim().ToLower()
                    $ContainsLP=$json.JOBREQUEST.Localization.lpcodes.Trim().Tolower().Contains($RequestDefaultCode)
                    if (($RequestDefaultCode -ne "en-us") -AND $ContainsLP ) {
                        WriteLog -Message "[-] Removing EN-US from base image" -Verbose
                    } else {
                        WriteLog -Message "Not valid configuration to remove EN-US, abort process" -MessageType Error -Verbose
                        $global:MessageResults="Not valid configuration to remove EN-US, abort process"
                        $global:CodeResults=229
                        ##### FAIL RESULT
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.Localization "fail" $global:MessageResults
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                }
                catch {
                    WriteLog -Message "Not valid configuration to remove EN-US, abort process" -MessageType Error -Verbose
                    $global:MessageResults="Not valid configuration to remove EN-US, abort process"
                    $global:CodeResults=229
                    ##### FAIL RESULT
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.Localization "fail" $global:MessageResults
                    Out-WinPE -Backuplogs -RemoveJob
                }
                ######################## REMOVE EN-US
                #Get-WindowsPackage -Path "$($OSDrive)\" | out-file -FilePath "$($Logs)\CurrentPackagesWindow.log" -Encoding default -Force #Not supported in WDT
                #Search current packages
                $null = Invoke-RunPower -File "dism.exe" -Params "/Image:$($OSDrive)\ /Get-Packages /format:table" -WorkDir $PSScriptRoot -OutFile "$($Logs)\CurrentPackagesWindow.log";
                $Packages=Get-Content "$($Logs)\CurrentPackagesWindow.log"
                WriteLog -Message "Searching known packages" -Verbose
                $pkgname=""
                foreach ($line in $Packages){
                    if ($line.Contains("|")) { #Extract only table
                        $PackageName=$line.Split('|')[0].Trim()
                        if (!($PackageName.StartsWith("---")) -AND !($PackageName.Contains(" "))) { #Extract only content of list and remove headers
                            switch ($PackageName) {
                                {$_ -like "*Client-LanguagePack*en-us*"} { $pkgname+="/packagename:$($PackageName) " }
                                {$_ -like "*LanguageFeatures-Basic*en-us*"} { $pkgname+="/packagename:$($PackageName) " }
                                {$_ -like "*LanguageFeatures-Handwriting*en-us*"} { $pkgname+="/packagename:$($PackageName) " }
                                {$_ -like "*LanguageFeatures-OCR*en-us*"} { $pkgname+="/packagename:$($PackageName) " }
                                {$_ -like "*LanguageFeatures-Speech*en-us*"} { $pkgname+="/packagename:$($PackageName) " }
                                {$_ -like "*LanguageFeatures-TextToSpeech*en-us*"} { $pkgname+="/packagename:$($PackageName) " }
                                {$_ -like "*RetailDemo-OfflineContent*en-us*"} { $pkgname+="/packagename:$($PackageName) " }
                            }					
                        }
                    }
                }
                $null = Invoke-RunPower -File "dism.exe" -Params "/Image:$($OSDrive)\ /ScratchDir:$($OSDrive)\  /remove-package $($pkgname)" -WorkDir $PSScriptRoot -OutFile "$($Logs)\RemoveLanguage_en_us.log";
                WriteLog -Message "Search for more en-US packages" -Verbose
                $Clear=$false
                $MyRetry=0
                While (!($Clear)) {
                    $MyRetry++;
					if (Test-Path -Path "$($Logs)\RescanPackagesWindow.log" -PathType Leaf) { remove-item -fo "$($Logs)\RescanPackagesWindow.log"; } ## TEST
                    $null = Invoke-RunPower -File "dism.exe" -Params "/Image:$($OSDrive)\ /Get-Packages /format:table" -WorkDir $PSScriptRoot -OutFile "$($Logs)\RescanPackagesWindow.log";
                    $Packages=Get-Content "$($Logs)\RescanPackagesWindow.log"
                    $pkgs=0
                    foreach ($line in $Packages){
                        if ($line.Contains("|")) { #Extract only table
                            $PackageName=$line.Split('|')[0].Trim()
                            if (!($PackageName.StartsWith("---")) -AND !($PackageName.Contains(" "))) { #Extract only content of list and remove headers
                                if ($PackageName.ToLower() -like "*en-us*"){
                                    $pkgs++
                                    WriteLog -Message "Remain en-US package: $($PackageName)" -Verbose
                                    $null = Invoke-RunPower -File "dism.exe" -Params "/Image:$($OSDrive)\ /ScratchDir:$($OSDrive)\  /remove-package /packagename:""$($PackageName)""" -WorkDir $PSScriptRoot -OutFile "$($Logs)\RemovePackage_$($PackageName).log";
                                }
                            }
                        }
                    }
                    if ($pkgs -eq 0) {WriteLog -Message "Not detected more en-US packages" -Verbose; $Clear=$true; } else {WriteLog -Message "Still detected $($pkgs) packages" -MessageType Warning -Verbose;}
                    if ($MyRetry -gt 10) { 
                        WriteLog -Message "Too many retries to remove all en-US packages" -MessageType Error -Verbose; 
                        $global:MessageResults="Too many retries to remove all en-US packages"
                        $global:CodeResults=230
                        ##### FAIL RESULT
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.Localization "fail" $global:MessageResults
                        Out-WinPE -Backuplogs -RemoveJob
                    } else {Start-Sleep -Seconds 5}
                }
				WriteLog -Message "Verify language packages installed: Verify_InstalledPackages.log" -Verbose
				$null = Invoke-RunPower -File "dism.exe" -Params "/Image:$($OSDrive)\ /Get-Packages /format:table" -WorkDir $PSScriptRoot -OutFile "$($Logs)\Verify_InstalledPackages.log" -Verbose;
				Get-Content "$($Logs)\Verify_InstalledPackages.log" -ErrorAction SilentlyContinue
                WriteLog -Message "Verify language Capabilities installed: Verify_InstalledCapabilities.log" -Verbose
				$null = Invoke-RunPower -File "cmd.exe" -Params "/c dism.exe /Image:$($OSDrive)\ /Get-Capabilities /format:table" -WorkDir $PSScriptRoot -OutFile "$($Logs)\Verify_InstalledCapabilities.log" -Verbose;
                Get-Content "$($Logs)\Verify_InstalledCapabilities.log" -ErrorAction SilentlyContinue
                ######################## REMOVE EN-US
            }
        }
        
        ###Save sucessfully status and continue
        Update-JobStatus $jobfile $json $json.JOBREQUEST.Localization "pass" "Successfully configured language"
        $global:MessageResults="Reboot unit after successfully complete language installation"
        $global:CodeResults=3010
        Out-WinPE
    } elseif (!([string]::IsNullOrEmpty($json.JOBREQUEST.Localization.status)) -AND ($json.JOBREQUEST.Localization.status.Trim().ToLower() -eq "pass")) {
        WriteLog -Message "Localization request was already completed, continue" -Verbose
    } elseif (!([string]::IsNullOrEmpty($json.JOBREQUEST.Localization.status)) -AND ($json.JOBREQUEST.Localization.status.Trim().ToLower() -eq "fail")) {
        WriteLog -Message "Localization request marked as fail, return to report" -MessageType Error -Verbose
        $global:MessageResults="Localization request marked as fail, return to report"
        $global:CodeResults=1
        Out-WinPE -Backuplogs -RemoveJob
    } else {
        WriteLog -Message "Localization request was not expected to receive with status $($json.JOBREQUEST.Localization.status)" -MessageType Error -Verbose
    }
    
} else {
    WriteLog -Message "Module not required, continue" -Verbose
}