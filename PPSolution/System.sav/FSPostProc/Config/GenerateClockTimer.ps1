Param (
	[Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,HelpMessage="Provide Out file path",Position=0)]
	[ValidateNotNullOrEmpty()]
    [string]$OutFile,
    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,HelpMessage="TimeOut",Position=1)]
    [int]$TimeWaitSecs=3600 #1Hour
)

$StaticText="";
if (Test-Path $OutFile) {
    $StaticText=(Get-Content -Path $OutFile)
    if ($StaticText.Trim().Length -gt 0) {
        $StaticText += "`r`n"
    } else {
        $StaticText="";
    }
}
$Counter=0
$Tik=$true
$clock = [Diagnostics.Stopwatch]::StartNew()
while (($Tik) -AND ($clock.Elapsed.TotalSeconds -le $TimeWaitSecs)) {
    Start-Sleep -Seconds 1
    $Counter++							
    #$mins=[math]::Floor($Counter/60)
    #$secs=$Counter % 60
    "$($StaticText)Elapsed time $([math]::Floor($clock.Elapsed.TotalHours).ToString().PadLeft(2,'0')):$([math]::Floor(($clock.Elapsed.TotalMinutes % 60)).ToString().PadLeft(2,'0')):$([math]::Floor(($clock.Elapsed.TotalSeconds % 60)).ToString().PadLeft(2,'0'))" | Out-File -FilePath $OutFile -Encoding default -Force
    if ($Counter -gt $TimeWaitSecs) {
        #Exceeded timeout, stop clock
        $Tik=$false
    }
}