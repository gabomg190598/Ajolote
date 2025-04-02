##############################################################################
##############################################################################

#Create basic Structure
if (-Not(Test-Path -Path (Join-Path $Env:SystemDrive "System.sav"))) { New-Item -Path $Env:SystemDrive -ItemType Directory -Name "System.sav" -Force | Out-Null }
if (-Not(Test-Path $logs)) { New-Item -Path (Join-Path $Env:SystemDrive "System.sav") -ItemType Directory -Name "logs" -Force | Out-Null }
if (-Not(Test-Path $flags)) { New-Item -Path (Join-Path $Env:SystemDrive "System.sav") -ItemType Directory -Name "flags" -Force | Out-Null }



#Capture console
$TrascriptFileName = (Join-Path $logs "Transcript_$($env:COMPUTERNAME).log")
try {
    if (Test-Path -Path $TrascriptFileName) {
        Start-Transcript -Path $TrascriptFileName -Append -Force | Out-Null
    }
    else {
        Start-Transcript -Path $TrascriptFileName -Force | Out-Null
    }	
}
catch {
    Stop-Transcript
    if (Test-Path -Path $TrascriptFileName) {
        Start-Transcript -Path $TrascriptFileName -Append -Force | Out-Null
    }
    else {
        Start-Transcript -Path $TrascriptFileName -Force | Out-Null
    }
}

