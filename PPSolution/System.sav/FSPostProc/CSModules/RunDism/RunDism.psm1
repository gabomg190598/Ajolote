#requires -Modules "WriteLog"
<#
.SYNOPSIS
    Run Dism command using System.Diagnostics, retrieving %ERRORLEVEL% and output
.DESCRIPTION
	Call execute Dism using System.Diagnostics and retrieving output, it can build HTA form to show progress
.NOTES
	Script version 1.0.7
	Script Date May.24.2021
.PARAMETER Params
   Parameter for Dism command 
.PARAMETER WorkDir
	Optional to send where should be executed the parameter, by default %WinDir%\System32
.PARAMETER OutFile
	Optional. Send output to file, it send by default to file with random name
.PARAMETER ContinueOnError
	Options. by default the process continue no matter result, disable this options can break all script process.
.PARAMETER ShowProgress
	Optional. Enable this option allows to create and show progress in HTA form
.PARAMETER ErrorCodes
	Optional, list of parameter accepted as valid for that command
.EXAMPLE

    RunDism -Params "/Apply-Image /ImageFile:Y:\Images\PCC\245_G7\7SY03AV_100\ImgCPE_OS.wim /ScratchDir:W:\ /ApplyDir:W:\ /Index:1 /Verify" -WorkDir "C:\Windows\system32\sysprep" -OutFile .\Sysprep.log -ShowProgress $true
#>

Function RunDism {
	[OutputType([int])]
	Param 
	(
		[Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true,HelpMessage="Parameters provided",Position=0)]
		[ValidateNotNullOrEmpty()]
		[Alias("Parameters")]
        [String]$Params,
		
		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,HelpMessage="Which Directory to start work",Position=1)]
		[AllowNull()]
        [Alias("Directory")]
		[String]$WorkDir = "$($Env:WinDir)\System32",
		
		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,HelpMessage="Output file",Position=2)]
		[Alias("Out")]
        [String]$OutFile,
		
		[Parameter(Mandatory=$false,HelpMessage="This option can show a HTA with progress",Position=3)]
		[Alias("showme")]
		[bool]$ShowProgress=$false,
		
		[Parameter(Mandatory=$false,HelpMessage="This option is created for Sure Agent",Position=4)]
		[Alias("filepb")]
        [string]$FileProgress,

		[Parameter(Mandatory=$false,HelpMessage="Set a time in seconds to kill process if not completed",Position=5)]
		[Alias("killtime")]
        [int]$TimeOut=3600
    )
	Begin {
        $ErrorActionPreference = "Stop";
		WriteLog -Message "================================== RunDism ===========================================" -Component $MyInvocation.MyCommand.Name
	}
	Process {
		Try {
			WriteLog -Message "RunDism execute command line: Dism.exe $($Params)" -Component $MyInvocation.MyCommand.Name 
			WriteLog -Message "`tWorking Directory: $($WorkDir)" -Component $MyInvocation.MyCommand.Name
            if ( $PSBoundParameters.ContainsKey( "OutFile" ) -eq $true ) {
			    WriteLog -Message "`tRetrive Output from $($OutFile)" -Component $MyInvocation.MyCommand.Name 
            }
			WriteLog -Message "`tSet timeout of $($TimeOut) seconds" -Component $MyInvocation.MyCommand.Name
			$pinfo = New-Object System.Diagnostics.ProcessStartInfo -Property @{
				FileName = "Dism.exe"
				Arguments = $Params
				UseShellExecute = $false
				WorkingDirectory = $WorkDir
				RedirectStandardOutput = $true
				RedirectStandardError = $true
			}
			
			if ($ShowProgress) {
				if ((Get-PSCallStack).Count -lt 3){  #call from Command line
					$emerPath =(Get-Item -Path '.\' -Verbose).FullName
				} else {
					$emerPath = Split-Path (Get-PSCallStack)[(Get-PSCallStack).Count-2].ScriptName -Parent
				}
				$pgf = "$($emerPath)\Dism_pg.ini"
				$pgmessage = "$($emerPath)\Dism_file.ini"
				$pgstatus = "$($emerPath)\status.ini"
				$LockScreen="$($PSScriptRoot)\HPFullLockScreen.exe"
				$IsrunLock=$false
				if (!(Test-Path $LockScreen)) {
					$gethta = BuildHTA
				}
				if (Test-Path $pgf) {Remove-Item $pgf -Force}
				if (Test-Path $pgmessage) {Remove-Item $pgmessage -Force}
				if (Test-Path $pgstatus) {Remove-Item $pgstatus -Force}

				$ArrayParams = $Params.Split("/")
				$strMode = "Dism CS command"
				$strFile = ""
				$global:pg="0.0%"
				$OptDrivers=$false
				ForEach ($par in $ArrayParams) {
					if ($par.Trim().ToLower().Contains("apply-image")) {$strMode="Applying CS Image "}
					if ($par.Trim().ToLower().Contains("export-image")) {$strMode="Exporting CS Image "}
					if ($par.Trim().ToLower().Contains("capture-image")) {$strMode="Capturing CS Image "}
					if ($par.Trim().ToLower().Contains("mount-image")) {$strMode="Mount CS Image "}
					if ($par.Trim().ToLower().Contains("unmount-image")) {$strMode="Unmount CS Image "}
					if ($par.Trim().ToLower().Contains("add-package")) {$strMode="Adding Package to CS Image "}
					if ($par.Trim().ToLower().Contains("add-provisionedappxpackage")) {$strMode="Adding Appx to CS Image "}
					if ($par.Trim().ToLower().Contains("add-driver")) {$strMode="Injecting Drivers to CS Image "; $OptDrivers=$true}
					if ($par.Trim().ToLower().Contains("imagefile")) { $tempFile = $par.ToLower().Replace("imagefile:","").Replace("""",""); if ($tempFile.Contains("\")) { $strFile = $tempFile.Split("\")[$tempFile.Split("\").Count-1]; } else { $strFile=$tempFile; } }	
					if ($par.Trim().ToLower().Contains("packagepath")) { $tempFile = $par.ToLower().Replace("packagepath:","").Replace("""",""); if ($tempFile.Contains("\")) { $strFile = $tempFile.Split("\")[$tempFile.Split("\").Count-1]; } else { $strFile=$tempFile; } }	
					if ($par.Trim().ToLower().Contains("destinationimagefile")) { $tempFile = $par.ToLower().Replace("destinationimagefile:","").Replace("""",""); if ($tempFile.Contains("\")) { $strFile = $tempFile.Split("\")[$tempFile.Split("\").Count-1]; } else { $strFile=$tempFile; }	}	
				}
				if ($null -ne $gethta) {
					$suphtaPath = Split-Path -Path $gethta -Parent
					$pgf = "$($suphtaPath)\Dism_pg.ini"
					$pgmessage = "$($suphtaPath)\Dism_file.ini"
					"$($strMode)$($strFile)"|Out-File $pgmessage -Encoding default -NoNewline
					"0.0%" |Out-File $pgf -Encoding default -NoNewline
					if (Test-Path $pgf) {
						$runhta = Start-Process $gethta -PassThru -WorkingDirectory $suphtaPath -ErrorAction SilentlyContinue
					}					
				}
				if (($null -eq $gethta) -AND (Test-Path $LockScreen)) {
					if (Get-Process | Where-Object {$_.Name -eq "HPFullLockScreen"}) {
						$supPath = Split-path (Get-Process -Name HPFullLockScreen).Path -Parent
						$IsrunLock=$true
					} else {
						$supPath = Split-Path -Path $LockScreen -Parent
					}
					
					$pgstatus = "$($supPath)\status.ini"
					"$($strMode)$($strFile)"|Out-File $pgstatus -Encoding default -Force
					"[progress] 0%" |Out-File $pgstatus -Encoding default -Append -force
					if (!($IsrunLock)){
						$runexe = Start-Process $LockScreen -PassThru -WorkingDirectory $supPath -ErrorAction SilentlyContinue
						WriteLog -Message "`tCall Look screen [$($supPath)]" -Component $MyInvocation.MyCommand.Name
					}
					
				}
				$pso = new-object psobject -property @{showp=$true; showl=$supPath; drivers=$OptDrivers; mode=$strMode; file=$strFile; outf=$FileProgress; verb=$PSBoundParameters.ContainsKey( "Verbose" ); Comp=$MyInvocation.MyCommand.Name; outfile=$OutFile;}
			} else {
				$pso = new-object psobject -property @{showp=$false; showl=$PSScriptRoot; drivers=$false; mode="Empty"; file="Empty"; outf=$FileProgress; verb=$PSBoundParameters.ContainsKey( "Verbose" ); Comp=$MyInvocation.MyCommand.Name; outfile=$OutFile;}
				
			}
			if ($IsrunLock) {
				WriteLog -Message "`tHPFullLockScreen process was detected running" -Component $MyInvocation.MyCommand.Name
			} else{
				WriteLog -Message "`tHPFullLockScreen process was launched" -Component $MyInvocation.MyCommand.Name
			}

			$p = New-Object System.Diagnostics.Process
			$p.StartInfo = $pinfo
			
			$OutEvent = Register-ObjectEvent -Action {
				[string]$logline= $Event.SourceEventArgs.Data
				if (!([string]::IsNullOrWhiteSpace($logline) )) {
					if ($Event.MessageData.verb) {
						WriteLog -Message $logline -Component $Event.MessageData.Comp  -Verbose
					} else {
						WriteLog -Message $logline -Component $Event.MessageData.Comp 
					}
					if ($Event.MessageData.outfile) { $logline | Out-File $Event.MessageData.outfile -Encoding default -Append -Force }
					#Wrrite-host "ShowProgress: "$Event.MessageData.showp
					if ($Event.MessageData.showp) {
						try {
							if (!($global:pg)) {$global:pg="0.0%"}
							#$pgf = "$($Event.MessageData.showl)\Dism_pg.ini"
							$pgstatus = "$($Event.MessageData.showl)\status.ini"
							#Write-host "line: "$logline
							#Write-host "file: "$pgstatus
							if ($logline.Contains("%")){  #used for application or where % value exists
								$prevpg= $global:pg.ToString().Trim().Substring(0, $global:pg.ToString().Trim().IndexOf("."))
								$global:pg = $logline.Replace("[","").Replace("=","").Replace("]","").Trim()
								#Write-Host "PG: $($global:pg)" -NoNewline
								try {
									[int]$porc=[math]::round($global:pg.Trim().Replace("%","").Trim(), 0)
								}
								catch {
									[int]$porc=$prevpg
								}								
								$forLock="[progress] $($porc)%"
								"$($Event.MessageData.mode)$($Event.MessageData.file)" | Out-File $pgstatus -Encoding default -Force
								$forLock | Out-File $pgstatus -Encoding default -Append -Force
								if ($porc -eq 100) {"Almost complete, verifying..." | Out-File $pgstatus -Encoding default -Append -Force}
								
							} else {
								Write-host "No % found"
							}
							if ($Event.MessageData.drivers) {
								if ($null -ne $logline -AND $logline.Contains("-")){  #used for drivers installation
									$logline.split('-')[0].Trim() |Out-File $pgf -Encoding default -NoNewline
									$forLock="[loading] "
									$forLock+=$logline.split('-')[0].Trim() 
									"$($Event.MessageData.mode)$($Event.MessageData.file)"|Out-File $pgstatus -Encoding default -Force
									$forLock | Out-File $pgstatus -Encoding default -Append -Force
								}
							}
						}
						catch {
							$ErrorMessage = $_.Exception.Message
							Write-Verbose "Report & Continue exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)"
						}
					}
					$DataOutFile=$Event.MessageData.outf
					if (!([string]::IsNullOrWhiteSpace($DataOutFile))) {
						try {
							$StrPercent=$logline.Replace("[","").Replace("=","").Replace("]","").Replace("%","").Trim()
							if ($null -eq $AED) {$AED=1}
							if (($null -eq $StrPercent) -OR ($StrPercent -eq "")) { $StrPercent=$proAED } else { $proAED=$StrPercent }
							[int]$intPercent = $StrPercent -as [int]
							$intPercent = [math]::round($intPercent, 0)
							if($intPercent -eq 0){ $intPercent=1 }
							if ((Get-Content $DataOutFile).ToLower() | Select-String -Pattern "image") {
								$GetCurrentStr=(Get-Content $DataOutFile | Select-String -Pattern "image").ToString().Trim()
								$Content = (Get-Content $DataOutFile)
								$Content -Replace $GetCurrentStr, "image,loading,$($intPercent)" | Set-Content $DataOutFile; 
							}
						}
						catch {
							$ErrorMessage = $_.Exception.Message
							Write-Verbose "`tReport & continue on $($MyInvocation.MyCommand.Name) calculating progress: $($ErrorMessage)"
						}
						
					}
				}
			} -MessageData $pso -InputObject $p -EventName OutputDataReceived

			$ErrEvent = Register-ObjectEvent -Action {
				[string]$logline= $Event.SourceEventArgs.Data
				if (!([string]::IsNullOrWhiteSpace($logline) )) {
					if ($Event.MessageData.verb) {
						WriteLog -Message $logline -MessageType Error -Component $Event.MessageData.Comp  -Verbose
					} else {							
						WriteLog -Message $logline -MessageType Error -Component $Event.MessageData.Comp 
					}
					if ($Event.MessageData.outfile) { $logline | Out-File "$($Event.MessageData.outfile).err" -Encoding default -Append -Force }
					if ($Event.MessageData.showp) {
						try {
							if (!($global:pg)) {$global:pg="0.0%"}
							$pgstatus = "$($Event.MessageData.showl)\status.ini"
							#"-1%" |Out-File $pgf -Encoding default -NoNewline
							"$($Event.MessageData.mode)$($Event.MessageData.file)"|Out-File $pgstatus -Encoding default -Force
							"[error] $($logline)" | Out-File $pgstatus -Encoding default -Append -Force
							if ($Event.MessageData.drivers) {
								#"$($logline)" |Out-File $pgf -Encoding default -NoNewline
								"$($Event.MessageData.mode)$($Event.MessageData.file)"|Out-File $pgstatus -Encoding default -Force
								 "[error] $($logline)" | Out-File $pgstatus -Encoding default -Append -Force
							}
						}
						catch {
							$ErrorMessage = $_.Exception.Message
							Write-Verbose "Report & Continue exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)"
						}
					}
					if ($Event.MessageData.outp) {
						try {							
								$logline | Out-file  $Event.MessageData.outf -Encoding default -force
						}
						catch {
							$ErrorMessage = $_.Exception.Message
							Write-Verbose "`tReport & continue on $($MyInvocation.MyCommand.Name) calculating progress: $($ErrorMessage)"
						}
						
					}
				}
			} -MessageData $pso -InputObject $p -EventName ErrorDataReceived

			# Start process
			[void]$p.Start()
			WriteLog -Message "`tProcess start Id=$($p.Id)" -Component $MyInvocation.MyCommand.Name 

			# Begin reading stdin\stdout
			$p.BeginOutputReadLine()
			$p.BeginErrorReadLine()
			$count=0
			do {
				if ($TimeOut -gt 0) {
					Start-Sleep -Seconds 1
					$count++;
					if ($count -gt $TimeOut){
						WriteLog -Message "Process has reach timeout, kill process and return error" -MessageType Error -Component $MyInvocation.MyCommand.Name
						Get-Process -Id $p.Id | Stop-Process -Force
					}
				}				
			}
			while (!$p.HasExited)
			if ($TimeOut -gt 0) {
				if (!$p.WaitForExit($TimeOut*1000)) {
					$p.Kill()
				}
			} else {
				[Void]$p.WaitForExit()
			}
			# Unregister events
			$OutEvent.Name, $ErrEvent.Name | ForEach-Object {Unregister-Event -SourceIdentifier $_}

			if ($p.HasExited) {
				WriteLog -Message "`tDism Exit Code: $($p.ExitCode)" -Component $MyInvocation.MyCommand.Name;
				[int]$ExitCode=$p.ExitCode
			} else {
				WriteLog -Message "`tDism Exit Code: -1" -Component $MyInvocation.MyCommand.Name;
				WriteLog -Message "Process aborted" -Verbose -MessageType Error -Component $MyInvocation.MyCommand.Name;
				$p.Dispose()
				[int]$ExitCode=-1
			}	
			if ($ShowProgress){
				"EOF" |Out-File $pgf -Encoding default -NoNewline
				#Start-Sleep -Seconds 1	
				if (!($IsrunLock))	{		
					"[EOF] Close this screen: Crtl + Alt + C" |Out-File $pgstatus -Encoding default -NoNewline -Force
				}
				if ($null -ne $runhta) { 
					try {
						Get-Process -Id $runhta.Id -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
						Remove-Item $gethta -Force;
					} catch {
						WriteLog -Message "Not possible shutdown HTA, ignore and continue" -Messagetype Warning -Component $MyInvocation.MyCommand.Name
					}
				}
				if ($null -ne $runexe) {
					try {
						if (!($IsrunLock))	{	
							Get-Process -Id $runexe.Id -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
						}
					} catch {
						WriteLog -Message "Not possible shutdown EXE, ignore and continue" -Messagetype Warning -Component $MyInvocation.MyCommand.Name
					}
				}
				if (Test-Path $pgf) {Remove-Item $pgf -Force}
				if (Test-Path $pgmessage) {Remove-Item $pgmessage -Force}
				#if (Test-Path $pgstatus) {Remove-Item $pgstatus -Force}
			}
			$p.Dispose() | out-null
			WriteLog -Message "========================================================================================" -Component $MyInvocation.MyCommand.Name
			return $ExitCode

		} 
		Catch 
		{
			$ErrorMessage = $_.Exception.Message
			WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
			WriteLog -Message "========================================================================================" -Component $MyInvocation.MyCommand.Name
			if (Test-Path $pgf) {Remove-Item $pgf -Force}
			if (Test-Path $pgmessage) {Remove-Item $pgmessage -Force}
			#if (Test-Path $pgstatus) {Remove-Item $pgstatus -Force}
			if (!($IsrunLock))	{
				Get-Process | Where-Object {$_.Name -like "*HPFullLockScreen*"} | Stop-Process -Force -ErrorAction SilentlyContinue
			}
			return -2
		}
		Finally { $ErrorActionPreference = "Continue" }
	}
}

<#
.SYNOPSIS
    HTA created for RunDism to show progress
.DESCRIPTION
	write HTA file used to show progress
.NOTES
	Script version 1.0.1
	Script Date Apr.18.2021
.EXAMPLE

    BuildHTA
#>

Function BuildHTA {
	#WriteLog -Message "=============================== Build HTA START ========================================" -Component $MyInvocation.MyCommand.Name
	$ErrorActionPreference = "Stop";
	Try {
		if ((Get-PSCallStack).Count -lt 3){  #call from Command line
            $htaPath =(Get-Item -Path '.\' -Verbose).FullName
        } else {
            $htaPath = Split-Path (Get-PSCallStack)[(Get-PSCallStack).Count-2].ScriptName -Parent
        }
		$htaName = "Progress.hta"
		$hta = "$($htaPath)\$($htaName)"
		if (Test-Path $hta) { Remove-Item $hta -Force}
		"<html xmlns=""http://www.w3.org/1999/xhtml"">" | Out-file -FilePath $hta -Append -Encoding default
		"<head>" | Out-file -FilePath $hta -Append -Encoding default
		"<meta http-equiv=""Content-Type"" content=""text/html; charset=utf-8"" />" | Out-file -FilePath $hta -Append -Encoding default
		"<title>DISM progress</title>" | Out-file -FilePath $hta -Append -Encoding default
		"<HTA:APPLICATION " | Out-file -FilePath $hta -Append -Encoding default
		"        Id=""offInstall"" " | Out-file -FilePath $hta -Append -Encoding default
		"        APPLICATIONNAME=""DISM"" " | Out-file -FilePath $hta -Append -Encoding default
		"        SCROLL=""no"" " | Out-file -FilePath $hta -Append -Encoding default
		"        SINGLEINSTANCE=""yes"" " | Out-file -FilePath $hta -Append -Encoding default
		"        WINDOWSTATE=""Maximized"" " | Out-file -FilePath $hta -Append -Encoding default
		"        SELECTION=""NO"" " | Out-file -FilePath $hta -Append -Encoding default
		"        CONTEXTMENU = ""NO"" " | Out-file -FilePath $hta -Append -Encoding default
		"        BORDER=""Thin"" " | Out-file -FilePath $hta -Append -Encoding default
		"        BORDERStyle = ""Normal"" " | Out-file -FilePath $hta -Append -Encoding default
		"        INNERBORDER = ""YES"" " | Out-file -FilePath $hta -Append -Encoding default
		"        NOWRAP " | Out-file -FilePath $hta -Append -Encoding default
		"        MAXIMIZEBUTTON = ""NO"" " | Out-file -FilePath $hta -Append -Encoding default
		"        MINIMIZEBUTTON = ""NO"" " | Out-file -FilePath $hta -Append -Encoding default
		"        SYSMENU = ""NO"" " | Out-file -FilePath $hta -Append -Encoding default
		"		CAPTION = ""NO"" " | Out-file -FilePath $hta -Append -Encoding default
		">" | Out-file -FilePath $hta -Append -Encoding default
		"" | Out-file -FilePath $hta -Append -Encoding default
		"</head>" | Out-file -FilePath $hta -Append -Encoding default
		"<SCRIPT LANGUAGE=""VBScript"">" | Out-file -FilePath $hta -Append -Encoding default
		"Dim dtmStartTime" | Out-file -FilePath $hta -Append -Encoding default
		"" | Out-file -FilePath $hta -Append -Encoding default
		"Ver = ""1.0.0.1"" " | Out-file -FilePath $hta -Append -Encoding default
		"'Support jocisneros@hp.com" | Out-file -FilePath $hta -Append -Encoding default
		"" | Out-file -FilePath $hta -Append -Encoding default
		"" | Out-file -FilePath $hta -Append -Encoding default
		"" | Out-file -FilePath $hta -Append -Encoding default
		"Sub Window_Onload" | Out-file -FilePath $hta -Append -Encoding default
		"  ResizeThis" | Out-file -FilePath $hta -Append -Encoding default
		"End Sub" | Out-file -FilePath $hta -Append -Encoding default
		"" | Out-file -FilePath $hta -Append -Encoding default
		"" | Out-file -FilePath $hta -Append -Encoding default
		"Sub ResizeThis" | Out-file -FilePath $hta -Append -Encoding default
		"	dim porce, wsize, hsize, xloc, yloc" | Out-file -FilePath $hta -Append -Encoding default
		"	porce = 0.70" | Out-file -FilePath $hta -Append -Encoding default
		"	wsize = screen.width*porce" | Out-file -FilePath $hta -Append -Encoding default
		"	hsize = screen.height*0.3" | Out-file -FilePath $hta -Append -Encoding default
		"	xloc = (screen.width/2)-(wsize/2)" | Out-file -FilePath $hta -Append -Encoding default
		"	yloc = (screen.height/2)-(hsize/2)" | Out-file -FilePath $hta -Append -Encoding default
		"   self.Focus " | Out-file -FilePath $hta -Append -Encoding default
		"   self.resizeTo wsize,hsize " | Out-file -FilePath $hta -Append -Encoding default
		"   self.MoveTo xloc,yloc" | Out-file -FilePath $hta -Append -Encoding default
		"   document.getElementById(""progress"").style.width=wsize*0.9&""px""" | Out-file -FilePath $hta -Append -Encoding default
		"   self.Focus" | Out-file -FilePath $hta -Append -Encoding default
		"   LoadandShow" | Out-file -FilePath $hta -Append -Encoding default
		"End Sub" | Out-file -FilePath $hta -Append -Encoding default
		"" | Out-file -FilePath $hta -Append -Encoding default
		"Sub LoadandShow" | Out-file -FilePath $hta -Append -Encoding default
		"	ForReading = 1" | Out-file -FilePath $hta -Append -Encoding default
		"    strNewFile = ""Dism_pg.ini"" " | Out-file -FilePath $hta -Append -Encoding default
		"	strFile = ""Dism_file.ini"" " | Out-file -FilePath $hta -Append -Encoding default
		"	dim idTimer" | Out-file -FilePath $hta -Append -Encoding default
		"    Set objFSO = CreateObject(""Scripting.FileSystemObject"")" | Out-file -FilePath $hta -Append -Encoding default
		"	if (objFSO.FileExists(strNewFile)) Then" | Out-file -FilePath $hta -Append -Encoding default
		"	    if objFSO.GetFile(strNewFile).size <> 0 then" | Out-file -FilePath $hta -Append -Encoding default
		"		    Set objFile = objFSO.OpenTextFile(strNewFile, ForReading)" | Out-file -FilePath $hta -Append -Encoding default
		"		    If Not objFile.AtEndOfStream Then " | Out-file -FilePath $hta -Append -Encoding default
		"			    strItems = objFile.ReadAll" | Out-file -FilePath $hta -Append -Encoding default
		"			    objFile.Close" | Out-file -FilePath $hta -Append -Encoding default
		"		    end if" | Out-file -FilePath $hta -Append -Encoding default
		"		    if (objFSO.FileExists(strFile)) Then" | Out-file -FilePath $hta -Append -Encoding default
		"		        if objFSO.GetFile(strFile).size <> 0 then" | Out-file -FilePath $hta -Append -Encoding default
		"			        Set objFile = objFSO.OpenTextFile(strFile, ForReading)" | Out-file -FilePath $hta -Append -Encoding default
		"			        If Not objFile.AtEndOfStream Then " | Out-file -FilePath $hta -Append -Encoding default
		"				        strItemn = objFile.ReadAll" | Out-file -FilePath $hta -Append -Encoding default
		"				        objFile.Close" | Out-file -FilePath $hta -Append -Encoding default
		"			        end if" | Out-file -FilePath $hta -Append -Encoding default
		"			        Msg.innerHTML = strItemn & ""...""" | Out-file -FilePath $hta -Append -Encoding default
        "	            else" | Out-file -FilePath $hta -Append -Encoding default
		"		            Msg.innerHTML = ""DISM running...""" | Out-file -FilePath $hta -Append -Encoding default
		"	            end if" | Out-file -FilePath $hta -Append -Encoding default
        "	        else" | Out-file -FilePath $hta -Append -Encoding default
		"		        Msg.innerHTML = ""DISM running...""" | Out-file -FilePath $hta -Append -Encoding default
        "	        end if" | Out-file -FilePath $hta -Append -Encoding default
		"		    " | Out-file -FilePath $hta -Append -Encoding default
		"		    dtmStartTime = Now" | Out-file -FilePath $hta -Append -Encoding default
		"		    idTimer = window.setTimeout(""PausedSection"", 1000, ""VBScript"")" | Out-file -FilePath $hta -Append -Encoding default
		"		    if (Trim(strItems) = ""EOF"") then" | Out-file -FilePath $hta -Append -Encoding default
		"			    Msg.innerHTML = Msg.innerHTML & ""<BR>"" & ""Process complete...""" | Out-file -FilePath $hta -Append -Encoding default
		"			    idTimer = window.setTimeout(""PauseClose"", 500)" | Out-file -FilePath $hta -Append -Encoding default
		"		    else" | Out-file -FilePath $hta -Append -Encoding default
		"			    progress.innerHTML =  ""|----- "" & strItems & "" -----|""" | Out-file -FilePath $hta -Append -Encoding default
		"		    end if" | Out-file -FilePath $hta -Append -Encoding default
		"		    " | Out-file -FilePath $hta -Append -Encoding default
		"	    else" | Out-file -FilePath $hta -Append -Encoding default
        "		    Msg.innerHTML =  ""loading app""" | Out-file -FilePath $hta -Append -Encoding default
		"		    dtmStartTime = Now" | Out-file -FilePath $hta -Append -Encoding default
		"		    idTimer = window.setTimeout(""PausedSection"", 1000,""VBScript"")" | Out-file -FilePath $hta -Append -Encoding default
		"	    end if " | Out-file -FilePath $hta -Append -Encoding default
		"	else" | Out-file -FilePath $hta -Append -Encoding default
		"		Msg.innerHTML =  ""Not valid information found, close app""" | Out-file -FilePath $hta -Append -Encoding default
		"		dtmStartTime = Now" | Out-file -FilePath $hta -Append -Encoding default
		"		idTimer = window.setTimeout(""PauseClose"", 5000)" | Out-file -FilePath $hta -Append -Encoding default
		"	end if " | Out-file -FilePath $hta -Append -Encoding default
		"    " | Out-file -FilePath $hta -Append -Encoding default
		"End Sub" | Out-file -FilePath $hta -Append -Encoding default
		"" | Out-file -FilePath $hta -Append -Encoding default
		"Sub PausedSection" | Out-file -FilePath $hta -Append -Encoding default
		"        window.clearTimeout(idTimer)" | Out-file -FilePath $hta -Append -Encoding default
		"		LoadandShow" | Out-file -FilePath $hta -Append -Encoding default
		"End Sub" | Out-file -FilePath $hta -Append -Encoding default
		"Function PauseClose()" | Out-file -FilePath $hta -Append -Encoding default
		"		ExitProgram" | Out-file -FilePath $hta -Append -Encoding default
		"End Function" | Out-file -FilePath $hta -Append -Encoding default
		"Sub ExitProgram" | Out-file -FilePath $hta -Append -Encoding default
		"        window.close()" | Out-file -FilePath $hta -Append -Encoding default
		"End sub" | Out-file -FilePath $hta -Append -Encoding default
		"" | Out-file -FilePath $hta -Append -Encoding default
		"" | Out-file -FilePath $hta -Append -Encoding default
		"</SCRIPT>" | Out-file -FilePath $hta -Append -Encoding default
		"" | Out-file -FilePath $hta -Append -Encoding default
		"<body bgcolor=""#00CCFF"""">" | Out-file -FilePath $hta -Append -Encoding default
		"<font size=""+3"" face=""Verdana, Geneva, sans-serif"">" | Out-file -FilePath $hta -Append -Encoding default
		"<DIV Id=""Msg""></DIV>" | Out-file -FilePath $hta -Append -Encoding default
		"<DIV Id=""progress"" align=""center"">|----- 00% -----|</DIV>" | Out-file -FilePath $hta -Append -Encoding default
		"</font>" | Out-file -FilePath $hta -Append -Encoding default
		"</body>" | Out-file -FilePath $hta -Append -Encoding default
		"</html>" | Out-file -FilePath $hta -Append -Encoding default
		if (Test-Path $hta) {
			WriteLog -Message "HTA built" -Component $MyInvocation.MyCommand.Name
			#WriteLog -Message "=============================== ================ ========================================" -Component $MyInvocation.MyCommand.Name
			return $hta
		} else {
			WriteLog -Message "HTA was not created" -MessageType Error -Component $MyInvocation.MyCommand.Name
			#WriteLog -Message "=============================== ================ ========================================" -Component $MyInvocation.MyCommand.Name
			return $null
		}
	} 
	Catch 
	{
		$ErrorMessage = $_.Exception.Message
		WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
		if (!($ContinueOnError)){ Exit 901}
		return $null
	}
	Finally { $ErrorActionPreference = "Continue" }
}