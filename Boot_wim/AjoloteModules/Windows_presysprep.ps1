<####################################################################
.Notes
Windows
PRE Sysprep module
Last update Mar/14/2025
-Create local user
  -Support empty passowrd
-Registry creation
-Configure TimeZone

#####################################################################>



if ($null -ne $json.JOBREQUEST.LocalNewUser -OR (($null -ne $json.JOBREQUEST.LocalNewUser.status) -AND ($json.JOBREQUEST.LocalNewUser.status.ToString().ToLower() -eq "new"))) {
    WriteLog -Message "Required New Local User" -Verbose
    $CreateUsers=$json.JOBREQUEST.LocalNewUser.NewUserList | Sort-Object -Property id
    foreach ($user in $CreateUsers) {
        WriteLog -Message "[$($user.id)] New user requested: $($user.Name)" -Verbose
        $newuser=Get-LocalUser -Name $user.Name
        if ($null -ne $newuser) {
            WriteLog -Message "User $($user.Name) already exist on this system" -MessageType Warning -Verbose            
        } else {
            WriteLog -Message "Checking group requested: $($user.UserGroup)" -Verbose
            switch ($user.UserGroup.ToLower()) {
                "administrators" { $UserSID_Pre="S-1-5-32"; $UserSID_Pos="-544"; break; }
                "access control assistance operators" { $UserSID_Pre="S-1-5-32"; $UserSID_Pos="-579"; break; }
                "backup operators" { $UserSID_Pre="S-1-5-32"; $UserSID_Pos="-551"; break; }
                "cryptographic operators" { $UserSID_Pre="S-1-5-32"; $UserSID_Pos="-569"; break; }
                "device owners" { $UserSID_Pre="S-1-5-32"; $UserSID_Pos="-583"; break; }
                "distributed com users" { $UserSID_Pre="S-1-5-32"; $UserSID_Pos="-562"; break; }
                "event log readers" { $UserSID_Pre="S-1-5-32"; $UserSID_Pos="-573"; break; }
                "guests" { $UserSID_Pre="S-1-5-32"; $UserSID_Pos="-546"; break; }
                "hyper-v administrators" { $UserSID_Pre="S-1-5-32"; $UserSID_Pos="-578"; break; }
                "iis_iusrs" { $UserSID_Pre="S-1-5-32"; $UserSID_Pos="-568"; break; }
                "network configuration operators" { $UserSID_Pre="S-1-5-32"; $UserSID_Pos="-556"; break; }
                "performance log users" { $UserSID_Pre="S-1-5-32"; $UserSID_Pos="-559"; break; }
                "performance monitor users" { $UserSID_Pre="S-1-5-32"; $UserSID_Pos="-558"; break; }
                "power users" { $UserSID_Pre="S-1-5-32"; $UserSID_Pos="-547"; break; }
                "remote desktop users" { $UserSID_Pre="S-1-5-32"; $UserSID_Pos="-555"; break; }
                "remote management users" { $UserSID_Pre="S-1-5-32"; $UserSID_Pos="-580"; break; }
                "replicator" { $UserSID_Pre="S-1-5-32"; $UserSID_Pos="-552"; break; }
                "system managed accounts group" { $UserSID_Pre="S-1-5-32"; $UserSID_Pos="-581"; break; }
                "users" { $UserSID_Pre="S-1-5-32"; $UserSID_Pos="-545"; break; }
                Default {$UserSID_Pre="S-1-5-32"; $UserSID_Pos="-544"; break;}
            }
            if (-Not([string]::IsNullOrEmpty($user.UserPassword))) {
                $UserPassword = ConvertTo-SecureString $user.UserPassword -AsPlainText -Force
            }
            
            $UserGroup= Get-LocalGroup | Where-Object {($_.SID.ToString().substring($_.SID.ToString().length - 4, 4) -like $UserSID_Pos) -and ($_.SID.ToString().substring(0,8) -like $UserSID_Pre) }
            WriteLog -Message "Local user group was identified $($UserGroup.Name) With SID: $($UserGroup.SID)" -Verbose
            WriteLog -Message "Creating user: $($user.FullName)..." -Verbose
            if ($user.AccountNeverExpires) {
                if ($null -ne $UserPassword) {
                    New-LocalUser -Name $user.Name -Password $UserPassword -Description $user.UserDescription -AccountNeverExpires -FullName $user.FullName | Out-Host
                } else {
                    New-LocalUser -Name $user.Name -Description $user.UserDescription -AccountNeverExpires -FullName $user.FullName | Out-Host
                }                
            } else {
                if ($null -ne $UserPassword) {
                    New-LocalUser -Name $user.Name -Password $UserPassword -Description $user.UserDescription -FullName $user.FullName | Out-Host
                } else {
                    New-LocalUser -Name $user.Name -Description $user.UserDescription -FullName $user.FullName | Out-Host
                }                
            }
            WriteLog -Message "Adding to $($UserGroup.Name) group..." -Verbose
            Add-LocalGroupMember -Group $UserGroup.Name -Member $user.Name
            $createduser = Get-LocalUser -Name $user.Name
            Get-LocalUser | Select-Object -Property * | Out-Host
            if ($null -ne $createduser) {
                if ($user.AccountNeverExpires) {
                    Set-LocalUser -Name $user.Name -AccountNeverExpires -PasswordNeverExpires $user.PasswordNeverExpires 
                } else {
                    Set-LocalUser -Name $user.Name -PasswordNeverExpires $user.PasswordNeverExpires
                }
                if (-Not($createduser.Enabled)) { Enable-LocalUser -Name $createduser.Name }
                WriteLog -Message "New user $($user.FullName) was created successfully and assigned to group $($user.UserGroup)"
            } else {
                Update-JobStatus $jobfile $json $json.JOBREQUEST.LocalNewUser "fail" "New user $($user.Name) was not possible to create"
                WriteLog -Message "New user $($user.Name) was not possible to create" -MessageType Error -Verbose
                $global:MessageResults="New user $($user.Name) was not possible to create"
                $global:CodeResults=901
                Out-Windows
            }
        }
    }
    Update-JobStatus $jobfile $json $json.JOBREQUEST.LocalNewUser "pass" "New user(s) created"
    Get-LocalUser | Select-Object -Property * | Out-Host
}


if ($null -ne $json.JOBREQUEST.RegistryInput -OR (($null -ne $json.JOBREQUEST.RegistryInput.status) -AND ($json.JOBREQUEST.RegistryInput.status.ToString().ToLower() -eq "new"))) {
    WriteLog -Message "Required create new registry key" -Verbose
    $NewRegistries=$json.JOBREQUEST.RegistryInput.AddKey | Sort-Object -Property id
    foreach ($key in $NewRegistries) {
        WriteLog -Message "Registry Order: [$($key.id)]" -Verbose
        WriteLog -Message " Registry Path: [$($key.Path)]" -Verbose
        WriteLog -Message " Registry Name: [$($key.Name)]" -Verbose
        WriteLog -Message "Registry Value: [$($key.Value)]" -Verbose
        WriteLog -Message " Registry Type: [$($key.Type)]" -Verbose
        try {
            WriteLog -Message "Checking Registry Path..." -Verbose
            if (-Not(Test-Path -Path $key.Path)) {
                WriteLog -Message "`tCreating Registry Path..." -Verbose
                New-Item -Path $key.Path -Force | Out-Host
            } else {
                WriteLog -Message "`tRegistry Path detected" -Verbose
            }
            WriteLog -Message "Inserting Registry Key" -Verbose
            New-ItemProperty -Path $key.Path -Name $key.Name -Value $key.Value -PropertyType $key.Type -Force | Out-Host
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            $global:MessageResults="Not possible to insert registry key: $($key.Name) [$($key.id)], error exception: $($ErrorMessage)"
            WriteLog -Message $global:MessageResults -MessageType Error -Verbose
            Update-JobStatus $jobfile $json $json.JOBREQUEST.RegistryInput "fail" $global:MessageResults          
            $global:CodeResults=905
            Out-Windows
        }
    }
        
    Update-JobStatus $jobfile $json $json.JOBREQUEST.RegistryInput "pass" "Registry(ies) has been created"

} elseif (($null -ne $json.JOBREQUEST.RegistryInput.status) -AND ($json.JOBREQUEST.RegistryInput.status.ToString().ToLower() -eq "fail")) {
    $global:MessageResults="Failure detected on this request, trying to stop process and report"
    WriteLog -Message $global:MessageResults -MessageType Error -Verbose       
    $global:CodeResults=900
    Out-Windows
} elseif (($null -ne $json.JOBREQUEST.RegistryInput.status) -AND ($json.JOBREQUEST.RegistryInput.status.ToString().ToLower() -eq "pass")) {
    WriteLog -Message "Add registry key was already successfully completed" -Verbose       
}



if (-Not([string]::IsNullOrEmpty($json.JOBREQUEST.Localization.timezone))) {
    WriteLog -Message "It is required to set time zone to: $($json.JOBREQUEST.Localization.timezone)" -Verbose
    #1st try using TZUTIL
    $FoundTZNames = [system.collections.arraylist]@()
    $null = Invoke-RunPower -File "cmd.exe" -Params "/c tzutil /l > $((Join-Path $logs "TZAvailable.txt"))" -WorkDir $logs -OutFile "$($logs)\TZutil.log"
    $GetTZfile=Get-Content (Join-Path $logs "TZAvailable.txt")
    for ($i = 0; $i -lt ($GetTZfile | Measure-Object).Count; $i++) {
        if($GetTZfile[$i].StartsWith("(") -AND ($GetTZfile[$i+1] -like "*$($json.JOBREQUEST.Localization.timezone)*")) {
            [void]$FoundTZNames.Add($GetTZfile[$i+1])
        }
    }
    if ($FoundTZNames.Count -gt 0) {
        WriteLog -Message "Using TZutil it was possible to detec $($FoundTZNames.Count) options, trying with: $($FoundTZNames[0])" -Verbose
        $null = Invoke-RunPower -File "cmd.exe" -Params "/c tzutil /s ""$($FoundTZNames[0])""" -WorkDir $logs -OutFile "$($logs)\TZutil.log"
        $null = Invoke-RunPower -File "cmd.exe" -Params "/c tzutil /g > $((Join-Path $logs "TZSet.txt"))" -WorkDir $logs -OutFile "$($logs)\TZutil.log"
        $GetTZSet=Get-Content (Join-Path $logs "TZSet.txt")
        WriteLog -Message "Configured TimeZone $($GetTZSet)" -Verbose
    } else {
        WriteLog -Message "It was not possible detect a supported Time zone using TZutil for $($json.JOBREQUEST.Localization.timezone)"
    }
    if ($null -ne (Get-TimeZone -ListAvailable | Where-Object {$_.Id -eq "$($json.JOBREQUEST.Localization.timezone)"})) {
        WriteLog -Message "Valid TimeZone, configuring..." -Verbose
        Set-TimeZone -Id $json.JOBREQUEST.Localization.timezone -PassThru | Out-Host
        WriteLog -Message "Checking if is possible to add unattend" -Verbose
        if ((-Not(Test-Path -Path (Join-Path $Env:SystemDrive "\system.sav\CustomUnattend") -PathType Container)) -OR (((Get-ChildItem -Path (Join-Path $Env:SystemDrive "\system.sav\CustomUnattend") -Recurse -File -ErrorAction SilentlyContinue) | Measure-Object -ErrorAction SilentlyContinue).Count -eq 0)) {
            if (Test-Path -Path (Join-Path $AjoloteDrive "\AUDIT\Unattends\TimeZone_Unattend.xml") -PathType Leaf) {
                WriteLog -Message "Adding unattend for TimeZone" -Verbose
                if (-Not(Test-Path (Join-Path $Env:SystemDrive "\system.sav\CustomUnattend"))) { WriteLog -Message "Creating Custom folder..." -Verbose; New-Item -Path (Join-Path $Env:SystemDrive "\system.sav\CustomUnattend") -ItemType Directory -Force | Out-Host; }
                Copy-Item -Path (Join-Path $AjoloteDrive "\AUDIT\Unattends\TimeZone_Unattend.xml") -Destination (Join-Path $Env:SystemDrive "\system.sav\CustomUnattend\Unattend.xml") -Force
                WriteLog -Message "Checking if is possible to update unattend..." -Verbose
                $xml = [xml](Get-Content (Join-Path $Env:SystemDrive "\system.sav\CustomUnattend\Unattend.xml"))
                if ($null -ne $xml.unattend.settings) {	
                    $nodeSettings = $xml.unattend.settings | Where-Object pass -eq 'oobeSystem' -ErrorAction SilentlyContinue
				    $nodeComponent = $nodeSettings.component | Where-Object name -eq 'Microsoft-Windows-Shell-Setup' -ErrorAction SilentlyContinue
                    if ($null -ne $nodeComponent) {
                        if ($null -ne $nodeComponent.TimeZone) {
                            WriteLog -Message "Updating current value for TimeZone[$($nodeComponent.TimeZone)] to $($json.JOBREQUEST.Localization.timezone)" -Verbose
                            $nodeComponent.TimeZone="$($json.JOBREQUEST.Localization.timezone)"
						    $xml.Save((Join-Path $Env:SystemDrive "\system.sav\CustomUnattend\Unattend.xml"))
                        }
                    }
                }
            } else {
                $global:MessageResults="Not possible locate TimeZone Unattend template at $((Join-Path $AjoloteDrive "\AUDIT\Unattends\TimeZone_Unattend.xml"))"
                WriteLog -Message $global:MessageResults -MessageType Error -Verbose
                $global:CodeResults=404
                Out-Windows
            }
        } else {
            WriteLog -Message "Not possible add unattend because path is already created and contains files" -MessageType Warning -Verbose
        }
    } else {
        $global:MessageResults="Not possible to configure TimeZone: $($json.JOBREQUEST.Localization.timezone)"
        WriteLog -Message $global:MessageResults -MessageType Error -Verbose       
        $global:CodeResults=905
        Out-Windows
    }
}


#Country Configuration
if (-Not([string]::IsNullOrEmpty($json.JOBREQUEST.Localization.country))) {     
    if (Test-Path (Join-Path $AjoloteDrive "\TOOLS\GeoIdCountry.json")) {
        $GeoIdLocation=(Get-Content -Path (Join-Path $AjoloteDrive "\TOOLS\GeoIdCountry.json") -Raw | ConvertFrom-Json)
        $GetgeoId=($GeoIdLocation | Where-Object {$_.HomeLocation -like "*$($json.JOBREQUEST.Localization.country)*"}).GeoId
        $GetHomeLocation=($GeoIdLocation | Where-Object {$_.HomeLocation -like "*$($json.JOBREQUEST.Localization.country)*"}).HomeLocation
        if ([string]::IsNullOrEmpty($GetgeoId)) {
            $global:MessageResults="Not found Country: $($json.JOBREQUEST.Localization.country)"
            WriteLog -Message $global:MessageResults -MessageType Error -Verbose       
            $global:CodeResults=907
            Out-Windows
        }
        WriteLog -Message "Currently this image has Home Location = $((Get-WinHomeLocation).HomeLocation) [$((Get-WinHomeLocation).GeoId)]" -Verbose
        WriteLog -Message "Replace by $($GetHomeLocation) [$($GetgeoId)]" -Verbose
        Set-WinHomeLocation -GeoId $GetgeoId.ToInt32($null) -Verbose
        WriteLog -Message "Checking new Home Location = $((Get-WinHomeLocation).HomeLocation) [$((Get-WinHomeLocation).GeoId)]" -Verbose
        if ((Get-WinHomeLocation).GeoId -ne $GetgeoId.ToInt32($null)) {
            $global:MessageResults="Failed configuring Country: $($json.JOBREQUEST.Localization.country)"
            WriteLog -Message $global:MessageResults -MessageType Error -Verbose       
            $global:CodeResults=908
            Out-Windows
        }
    } else {
        $global:MessageResults="Not possible to configure Country: $($json.JOBREQUEST.Localization.country), missing relation file $((Join-Path $AjoloteDrive "\TOOLS\GeoIdCountry.json"))"
        WriteLog -Message $global:MessageResults -MessageType Error -Verbose       
        $global:CodeResults=906
        Out-Windows
    }

}