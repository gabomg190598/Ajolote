#Phats
$CurrentStageFolder = (Split-Path -Path (Get-Item -Path '.\' -Verbose).FullName -Leaf)
$ParentStagePath = (Split-Path -Path (Get-Item -Path '.\' -Verbose).FullName -Parent)
$ScriptName = ($MyInvocation.MyCommand.Name).ToString().Substring(0,$MyInvocation.MyCommand.Name.ToString().Length-4)

#System.sav paths
$flags = (Join-Path $Env:SystemDrive "\System.sav\flags")
$logs = (Join-Path $Env:SystemDrive "\system.sav\logs")
$ConfigPath = (Join-Path $ParentStagePath "Config")

#WDT paths
$WDT = (Join-Path $Env:SystemDrive "\System.sav\WDT")
$OSChanger = "$($WDT)\OSChanger64.exe"
$CustomOSChanger = "CustomOSchange.exe"
$LocalWDT = (Join-Path $ParentStagePath "WDT")
$Result = (Join-Path $WDT "Result.ini")

#USMT 
$USMT = (Join-Path $ParentStagePath "USMT_XXXXX")

#SplashScreen
$FSscreenFile = "FSLockScreen.exe"
$FSscreenStatusFile = (Join-Path $ParentStagePath "status.ini")
$FSscreenProgressFile = (Join-Path $ParentStagePath "progress.log")
$FSscreen = (Join-Path $ParentStagePath $FSscreenFile)
$global:OnScreenProcess=$null
$global:OnScreenName=$FSscreenFile.Substring(0,$FSscreenFile.LastIndexOf("."))

#Flags
$errorflg = (Join-Path $flags "cserror.flg")
$pauseflg = (Join-Path $flags "cspause.flg")
$CSDrvNoVal = (Join-Path $flags "CSDrvNoVal.flg")
$CSCustMode = (Join-Path $flags "CSCustMode.flg")
$CSDebug = (Join-Path $flags "CSDebug.flg")
$CSPK = (Join-Path $flags "CSPK.flg")
$ICFactoryflag = (Join-Path $flags "CaptureFactory.flg")
$ICPostProcflag = (Join-Path $flags "CapturePP.flg")
$NoUSMT = (Join-Path $flags "NoUSMT.flg")
$RetryDMA = (Join-Path $flags "FSretryDMA.flg")

<# NO ERROR FILE #>
$CurrentStageFolder | Out-Null
$ParentStagePath | Out-Null
$ScriptName | Out-Null
$flags | Out-Null
$logs | Out-Null
$ConfigPath | Out-Null
$WDT | Out-Null
$OSChanger | Out-Null
$CustomOSChanger | Out-Null
$LocalWDT | Out-Null
$Result | Out-Null
$USMT | Out-Null
$FSscreenFile | Out-Null
$FSscreenStatusFile | Out-Null
$FSscreenProgressFile | Out-Null
$FSscreen | Out-Null
$global:OnScreenProcess | Out-Null
$global:OnScreenName | Out-Null
$errorflg | Out-Null
$pauseflg | Out-Null
$CSDrvNoVal | Out-Null
$CSCustMode | Out-Null
$CSDebug | Out-Null
$CSPK | Out-Null
$ICFactoryflag | Out-Null
$ICPostProcflag | Out-Null
$NoUSMT | Out-Null
$RetryDMA | Out-Null
