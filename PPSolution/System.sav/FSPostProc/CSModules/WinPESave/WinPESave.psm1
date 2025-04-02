#requires -Modules "WriteLog"

<#
.SYNOPSIS
    Functions created for HPDeployment 
.DESCRIPTION
	WinPE-SaveLogsUSB Save logs on USB stick
	WinPE-SaveLogsHDD Save logs on local drive, $LogFolder
	SelectUSBDrive Propmt an UI form to select the USB drive. it return drive letter selected.
	DebugModeOn Open a CMD if $Global:Debug is True, Pause to prevent close script
	Set-ComputerName Function used to change computer name
	UIForm Fom used to request New Computer Name
	ValidateNewCompName Used to validate a string that will be used as ComputerName 
	UnattendComputerName Function used to write ComputerName into unattend file(xml)
	UnattendModel function used to change Model in OEMInformation for Unattend
	SwaptOSBoot - Function created for Ajolote solution
	Save-WinPELogs - Function created for Ajolote solution
	Close-WindowsLogs - Function created for Ajolote solution
.NOTES
	Script version 1.1.2
	Script Date Apr.16.2021
.PARAMETER LogFolder
    local directory, full path is provided where logs must copy
.PARAMETER UnattendFile
	Path to Unattend file
.PARAMETER Customer
	Optional. Used to calculate a new name for Coputer Name
.PARAMETER ComputerName
	Value to validate as new computername
.PARAMETER XMLPath
	Unattend location
.PARAMETER CompName
	Value for write  ComputerName
.PARAMETER Model
	String value for Model name
.EXAMPLE
	WinPE-SaveLogsUSB
	WinPE-SaveLogsHDD -LogFolder "C:\Windows\Setup\Scripts\WinPELogs"
	SelectUSBDrive
	TurnHTA -Mode "On"
	UnattendModel -XMLPath "W:\Windows\Panther\Unattend\Uanttend.xml" -Model "HP EliteDesk 800 G5 SFF"
#>

#This function save log on USB since local disk has issues
Function Save-WinPELogsUSB {
	[CmdletBinding()]
	Param (
	)
	Begin {
		WriteLog -Message "=================Save Logs on USB===========================" -Component $MyInvocation.MyCommand.Name
	}
	Process{
		$ErrorActionPreference = "Stop";
		Try
		{			
			$SaveDrive = ""
			while($SaveDrive -eq "") { 
				$SaveDrive = SelectUSBDrive
			}
			$USBLogFolder = "$($SaveDrive)\HPDEPLOYLOGS"		
			if (!(Test-Path $USBLogFolder)) { New-Item -ItemType Directory -Path $USBLogFolder }
			WriteLog -Message "You will find logs and files on $($USBLogFolder)" -Component $MyInvocation.MyCommand.Name
			if ((Get-PSCallStack).Count -lt 3){  #call from Command line
				$CallPath =(Get-Item -Path '.\' -Verbose).FullName
			} else {
				$CallPath = Split-Path (Get-PSCallStack)[(Get-PSCallStack).Count-2].ScriptName -Parent
			}
			WriteLog -Message "Copy .ini files" -Component $MyInvocation.MyCommand.Name
			Copy-Item -Path "$($CallPath)\HP*.ini" -Destination $USBLogFolder -Force
			WriteLog -Message "Copy .txt files" -Component $MyInvocation.MyCommand.Name
			Copy-Item -Path "$($CallPath)\HP*.txt" -Destination $USBLogFolder -Force
			WriteLog -Message "Copy .log files" -Component $MyInvocation.MyCommand.Name
			Copy-Item -Path "$($CallPath)\*.log" -Destination $USBLogFolder -Force
			WriteLog -Message "Copy .xml files" -Component $MyInvocation.MyCommand.Name
			Copy-Item -Path "$($CallPath)\HP*.xml" -Destination $USBLogFolder -Force
			WriteLog -Message "Saved on USB completed, shutdown unit" -Component $MyInvocation.MyCommand.Name
			Start-Sleep 5
		} 
		Catch 
		{
			$ErrorMessage = $_.Exception.Message
			WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
		}
		Finally { $ErrorActionPreference = "Continue" }
	}
}

#This function save logs on desired directory 
Function Save-WinPELogsHDD {
	[CmdletBinding()]
	Param 
	(
		[Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,HelpMessage="Where to move all logs",Position=0)]
		[ValidateNotNullOrEmpty()]
        [String]$LogFolder
    )
	Begin {
		WriteLog -Message "Save Logs on $($LogFolder)" -Component $MyInvocation.MyCommand.Name	
	}
	Process {
		$ErrorActionPreference = "Stop";
		Try																																																														  
		{			
			if (!(Test-Path $LogFolder)) { New-Item -ItemType Directory -Path $LogFolder }
			if ((Get-PSCallStack).Count -lt 3){  #call from Command line
				$CallPath =(Get-Item -Path '.\' -Verbose).FullName
			} else {
				$CallPath = Split-Path (Get-PSCallStack)[(Get-PSCallStack).Count-2].ScriptName -Parent
			}
			WriteLog -Message "Copy .ini files" -Component $MyInvocation.MyCommand.Name
			Copy-Item -Path "$($CallPath)\HP*.ini" -Destination $LogFolder -Force
			WriteLog -Message "Copy .txt files" -Component $MyInvocation.MyCommand.Name
			Copy-Item -Path "$($CallPath)\HP*.txt" -Destination $LogFolder -Force
			WriteLog -Message "Copy .log files" -Component $MyInvocation.MyCommand.Name
			Copy-Item -Path "$($CallPath)\*.log" -Destination $LogFolder -Force
			WriteLog -Message "Copy .xml files" -Component $MyInvocation.MyCommand.Name
			Copy-Item -Path "$($CallPath)\HP*.xml" -Destination $LogFolder -Force
			WriteLog -Message "Saved on local disk completed, shutdown unit" -Component $MyInvocation.MyCommand.Name
			Start-Sleep 15
		} 
		Catch 
		{
			$ErrorMessage = $_.Exception.Message
			WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
		}
		Finally { $ErrorActionPreference = "Continue" }
	}
}

#-------- PROMPT FOR SELECT USB DRIVE AND RETURN DRIVE LETTER
Function SelectUSBDrive {
	[OutputType([string])]
	Param (
	)
	Begin {
		WriteLog -Message "========= Select USB Form Open ===============" -Component $MyInvocation.MyCommand.Name
	}
	Process {
		$ErrorActionPreference = "Stop";
		Try
		{
		#->Start Process
			[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
			[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
			Add-Type -AssemblyName System.Windows.Forms | out-null
			Add-Type -assembly System.Windows.Forms | out-null
	#FORM CONSTRUCTION
			$global:dicDisk =@{}
			$global:x = ""
			$objForm = New-Object System.Windows.Forms.Form 
			$objForm.Text = "HP DEPLOYMENT - Save logs"
			$objForm.Size = New-Object System.Drawing.Size(500,320) 
			$objForm.StartPosition = "CenterScreen"
			$objForm.BackColor = "LightYellow"
			$objForm.ControlBox = $false
			$objForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Fixed3D	
			$Font = New-Object System.Drawing.Font("Verdana",10,[System.Drawing.FontStyle]::Bold)
			$Font2 = New-Object System.Drawing.Font("Impact",11,[System.Drawing.FontStyle]::Bold)
	#---> KEY PRESS
			$objForm.KeyPreview = $True
			$objForm.Add_KeyDown({if ($_.KeyCode -eq "Enter") 
				{$global:x="$($objListBox.SelectedItem)";$objForm.Close();$global:x|Out-Null;}})
			$objForm.Add_KeyDown({if ($_.KeyCode -eq "Escape") 
				{$objForm.Close()}})
	#---> SAVE BUTTON
			$OKButton = New-Object System.Windows.Forms.Button
			$OKButton.Location = New-Object System.Drawing.Size(90,220)
			$OKButton.Size = New-Object System.Drawing.Size(75,23)
			$OKButton.Text = "SAVE"
			$OKButton.BackColor = "DodgerBlue"
			$OKButton.TabIndex = 3
			$OKButton.Add_Click({$global:x="$($objListBox.SelectedItem)"; $objForm.Close();$global:x|Out-Null;})
			$objForm.Controls.Add($OKButton)
	#---> RESCAN BUTTON
			$RescanButton = New-Object System.Windows.Forms.Button
			$RescanButton.Location = New-Object System.Drawing.Size(165,220)
			$RescanButton.Size = New-Object System.Drawing.Size(75,23)
			$RescanButton.Text = "Rescan"
			$RescanButton.BackColor = "LightSteelBlue"
			$RescanButton.TabIndex = 4
			$RescanButton.Add_Click({
				#$objForm.Close()
				$USBDrive = Get-WmiObject Win32_Volume -Filter "DriveType='2'"
				if (($USBDrive | Measure-Object).Count -gt 0) {
					$label2.Text = "IMPORTANT: Logs will be saved on selected drive, under folder HPDEPLOYLOGS. `nDrive must be USB STICK.`nIf drive is not attached yet, do it now and press RESCAN buton"
					$RescanButton.BackColor = "LightSteelBlue"
					$OKButton.BackColor = "DodgerBlue"
				} else {
					$label2.Text = "There is no USB Stick Detected, please attach one before to continue"
					$RescanButton.BackColor = "OrangeRed"
					$OKButton.BackColor = "LightSteelBlue"
				}
				$objForm.Refresh()
				$global:dicDisk =@{}
				$order = 0
				[void] $objListBox.Items.Clear()
				ForEach ($drive in $USBDrive) {
					if ($null -ne $drive.DriveLetter) {
						[void] $objListBox.Items.Add($drive.DriveLetter)
						if ($null -ne $drive.label -and $drive.label.Trim().length -gt 0){
							$global:dicDisk.Add($order,$drive.label)
						} else {
							$global:dicDisk.Add($order,"[NoLabel]")
						}
						$order++
					}
				}
				$objListBox.SelectedIndex = -1
				$objListBox.Text = ""
				$objLabel.text = "Select USB Stick:"
				$objForm.Refresh()
			})
			$objForm.Controls.Add($RescanButton)
	#---> LABEL TOP
			$objLabel = New-Object System.Windows.Forms.Label
			$objLabel.Location = New-Object System.Drawing.Size(10,20) 
			$objLabel.Size = New-Object System.Drawing.Size(300,20) 
			$objLabel.Font = $Font2
			$objLabel.Text = "Please select a device to save logs:"
			$objForm.Controls.Add($objLabel) 	
	#---> LABEL NOTIFICATION
			$label2 = New-Object system.Windows.Forms.Label
			$label2.Location = New-Object System.Drawing.Size(10,90) 
			$label2.Size = New-Object System.Drawing.Size(380,120) 
			$label2.BackColor = "Transparent"
			$label2.ForeColor = "Blue"
			$label2.Font = $Font
			$objForm.controls.add($label2)
	#---> DROP BOX 
			$objListBox = New-Object System.Windows.Forms.ComboBox 
			$objListBox.Location = New-Object System.Drawing.Size(200,40) 
			$objListBox.Size = New-Object System.Drawing.Size(100,20) 
			$objListBox.Height = 80
			$objListBox.TabIndex = 2

			$USBDrive = Get-WmiObject Win32_Volume -Filter "DriveType='2'"
			if (($USBDrive | Measure-Object).Count -gt 0) {
				$label2.Text = "IMPORTANT: Logs will be saved on selected drive, under folder HPDEPLOYLOGS. `nDrive must be USB STICK.`nIf drive is not attached yet, do it now and press RESCAN buton"
				$RescanButton.BackColor = "LightSteelBlue"
				$OKButton.BackColor = "DodgerBlue"
			} else {
				$label2.Text = "There is no USB Stick Detected, please attach one and press Rescan button before to continue"
				$RescanButton.BackColor = "OrangeRed"
				$OKButton.BackColor = "LightSteelBlue"
			}
			$objForm.Refresh()
			$order = 0
			ForEach ($drive in $USBDrive) {
				if ($null -ne $drive.DriveLetter) {
					[void] $objListBox.Items.Add($drive.DriveLetter)
					if ($null -ne $drive.label -and $drive.label.Trim().length -gt 0){
						$global:dicDisk.Add($order,$drive.label)
					} else {
						$global:dicDisk.Add($order,"[NoLabel]")
					}
					$order++
				}
			}
			$objListBox.SelectedIndex = -1
			
			$objForm.Controls.Add($objListBox) 

			$objListBox_SelectedIndexChanged=
				{		
					$objLabel.text="USB Selected to save HP Deployment Logs: $($global:dicDisk.Get_Item($objListBox.SelectedIndex))"
					$objForm.Refresh()
				}
			$objListBox.add_SelectedIndexChanged($objListBox_SelectedIndexChanged)

			$objForm.Topmost = $True

			$objForm.Add_Shown({$objForm.Activate()})
			[void] $objForm.ShowDialog()
			
			if ($objListBox.Text.ToString().Trim().StartsWith("@")) {
				WriteLog -Message "Skip save logs, reboot unit to try again" -MessageType Warning -Component $MyInvocation.MyCommand.Name
				$global:x = "X:"
			}
			return $global:x.Trim()
		#-->End Process
		} 
		Catch 
		{
			$ErrorMessage = $_.Exception.Message
			WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
		}
		Finally { $ErrorActionPreference = "Continue" }
	}
}


function DebugModeOn {
	[CmdletBinding()]
	Param 
	(
    )
	Begin {
	}
	Process {
		$ErrorActionPreference = "Stop";
		Try																																																														  
		{
			if ($null -ne $global:Debug -AND $global:Debug) { 
				[void] [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.VisualBasic")
				WriteLog -Message "*************************DEBUG STATE ACTIVE*******************************" -Component $MyInvocation.MyCommand.Name
				$host.UI.RawUI.WindowTitle = "HP DEPLOYMENT PROCESS -DEBUG ON-"
				ControlHTA -HTAMode Off
				#if ((Get-Process |where Id -eq $hta.id) -ne $null) { Stop-Process -Id $hta.id }
				$advice=[Microsoft.VisualBasic.Interaction]::MsgBox("Debug Mode is ON",(0,0,48) ,"Debug Mode ON")
				$advice | Out-Null
				Do {
					$cmd = Start-Process -FilePath "cmd.exe" -PassThru
					WriteLog -Message "CMD process lauched with id# $($cmd.Id)" -Component $MyInvocation.MyCommand.Name
					While (Get-Process | Where-Object {$_.Id -eq $cmd.Id}) {Write-Host "DEBUG MODE ON, CLOSE CMD TO TERMINATE THIS SESSION"; start-sleep 5;}					
					$CloseSession=[Microsoft.VisualBasic.Interaction]::MsgBox("Debug Mode is ON, do you want exit Debug mode?",(4,256,32) ,"Close Debug?")
				} while ($CloseSession -eq "No")
				$host.UI.RawUI.WindowTitle = "HP DEPLOYMENT PROCESS"
				ControlHTA -HTAMode On
				#WriteLog -Message "HTA form start with ID: $($hta.id)" -Component $MyInvocation.MyCommand.Name
				#return $hta
			}
		} 
		Catch 
		{
			$ErrorMessage = $_.Exception.Message
			WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
		}
		Finally { $ErrorActionPreference = "Continue" }
	}
}

Function Set-ComputerName {
	[CmdletBinding()]
	Param 
	(
		[Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,HelpMessage="Full path to Unattend",Position=0)]
		[ValidateNotNullOrEmpty()]
		[Alias("pathunattend")]
        [string]$UnattendFile,
		
		[Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,HelpMessage="Customer name",Position=1)]
		[AllowNull()]
		[Alias("Name")]
        [string]$Customer

    )
	Begin {
		WriteLog -Message "Requested new name for computer..." -Component $MyInvocation.MyCommand.Name
	}
	Process {
		$ErrorActionPreference = "Stop";
		Try
		{
			if ((Get-PSCallStack).Count -lt 3){ #call from script
                $scriptpath=(Get-Item -Path '.\' -Verbose).FullName
            } else {
                $scriptpath = Split-Path (Get-PSCallStack)[(Get-PSCallStack).Count-2].ScriptName -Parent
            }
			$flagName = "$($scriptpath)\HPSetCompName.log"
			if (!(Test-Path $UnattendFile)) {
				WriteLog -Message "Unattend doesn't exist, there is nothing to modify, exit Set-ComputerName" -MessageType Error -Component $MyInvocation.MyCommand.Name
				return;
			}
			$oldName = $env:computername
			#Recommended name
			$SNMachine = (Get-WmiObject Win32_Bios).SerialNumber
			$maxlen = 15			
			if ($Customer -ne $null){
				$companylen = $Customer.Replace(" ","").length + 1
				if ($companylen -ge $maxlen) {$Customer = $Customer.Substring(0,5); $companylen = 6;}
				$SNlen = $maxlen - $companylen
				if ($SNlen -gt $SNMachine.length) {$SNlen = $SNMachine.length}
				$PropName = "$($Customer.Replace(' ',''))-$($SNMachine.Substring($SNMachine.length - $SNlen, $SNlen))"
				WriteLog -Message "-Calculate a name based on customer name and SN" -Component $MyInvocation.MyCommand.Name
				WriteLog -Message "`tCustomer Name: $($Customer.ToUpper())[$($Customer.Replace(' ','').length)]" -Component $MyInvocation.MyCommand.Name
			} else {
				$PropName = "HP-$($SNMachine)"
				if ($PropName.length -gt $maxlen) {$PropName=$PropName.Substring(0,$maxlen)}
				WriteLog -Message "-Calculate a name based on SerialNumber" -Component $MyInvocation.MyCommand.Name
			}
			WriteLog -Message "`tSerial Number: $($SNMachine)[$($SNMachine.length)]" -Component $MyInvocation.MyCommand.Name
			WriteLog -Message "`tProposal New Name: $($PropName.ToUpper())" -Component $MyInvocation.MyCommand.Name
			WriteLog -Message "`tCurrent Computer Name: $($oldName.ToUpper())" -Component $MyInvocation.MyCommand.Name

			$global:TextValue = $PropName.ToUpper()
			$global:AddText = "For Computer Name:`r`n `t`t[+]Length max is 15 chars`r`n `t`t[+]Should start with Letter or Number`r`n `t`t[+]Empty spaces will be removed`r`n`r`nIf press Cancel will allow Windows to assign new Computer Name randomly"
			$global:AddText | Out-Null
			ControlHTA -HTAMode Off
			$NewName = UIForm
			ControlHTA -HTAMode On
			if ($oldName.Trim() -eq $NewName.Trim()) {
				WriteLog -Message "New name and old name is same or cancelled form" -MessageType Warning -Component $MyInvocation.MyCommand.Name
				UnattendComputerName -XMLPath $UnattendFile -CompName "*" -Verbose
				Add-Content -Path $flagName -Value $oldName -NoNewline
			} else {
				ControlHTA -HTAMode Off
				While (!(ValidateNewCompName -ComputerName $global:TextValue))
				{
					$NewName = UIForm
				}
				ControlHTA -HTAMode Off
				if ($oldName.Trim() -eq $NewName.Trim()) {
					WriteLog -Message "New name and Old name is same, set random value" -MessageType Warning -Component $MyInvocation.MyCommand.Name
					UnattendComputerName -XMLPath $UnattendFile -CompName "*" -Verbose
					Add-Content -Path $flagName -Value $oldName -NoNewline
				} else {
					WriteLog -Message "New Computer name will be [$($global:TextValue)]" -Component $MyInvocation.MyCommand.Name
					UnattendComputerName -XMLPath $UnattendFile -CompName $global:TextValue -Verbose
					Add-Content -Path $flagName -Value $global:TextValue -NoNewline 
				}
			}
		} 
		Catch 
		{
			$ErrorMessage = $_.Exception.Message
			WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
		}
		Finally { $ErrorActionPreference = "Continue" }
	}
}

#Change Value for Model in OEMInformation for Unattends
Function UnattendModel {
	[CmdletBinding()]
	Param 
	(
		[Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,HelpMessage="Provide full path to Unattend file",Position=0)]
		[ValidateNotNullOrEmpty()]
		[Alias("xml")]
        [String]$XMLPath,
		
		[Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,HelpMessage="Provide value for computer Model",Position=1)]
		[ValidateNotNullOrEmpty()]
		[Alias("name")]
        [String]$Model
    )
	Process {
		$ErrorActionPreference = "SilentlyContinue";
		Try																																																														  
		{
			$xml = [xml](Get-Content $XMLPath)						
			if ($null -eq $xml.unattend.settings) {
				WriteLog -Message "XML error, not found structure Unattend\setting" -MessageType Error -Component $MyInvocation.MyCommand.Name
				return;
			} else {
				WriteLog -Message "Found Node Unattend\Settings\" -Component $MyInvocation.MyCommand.Name
				$nodeSettings = $xml.unattend.settings | Where-Object pass -eq 'specialize' -ErrorAction SilentlyContinue
				$nodeComponent = $nodeSettings.component | Where-Object name -eq 'Microsoft-Windows-Shell-Setup' -ErrorAction SilentlyContinue
				if ($null -ne $nodeComponent) {
					if ($null -ne $nodeComponent.OEMInformation.Model) {
						WriteLog -Message "Current value for Unattend\Settings\Specialize\OEMInformation\Model = $($nodeSettings.component.OEMInformation.Model)" -Component $MyInvocation.MyCommand.Name
						WriteLog -Message "New value for Unattend\Settings\Specialize\OEMInformation\Model = $($Model)" -Component $MyInvocation.MyCommand.Name
						$nodeComponent.OEMInformation.Model=$Model
						$xml.Save($XMLPath)
					} else {
						WriteLog -Message "XML error, not found structure Unattend\Settings\Specialize\Components\OEMInformation\Model" -MessageType Error -Component $MyInvocation.MyCommand.Name
						return;
					}
				} else {
					WriteLog -Message "XML error, not found structure Unattend\Settings\Specialize\Components" -MessageType Error -Component $MyInvocation.MyCommand.Name
					return;
				}	
			}			
		} 
		Catch 
		{
			$ErrorMessage = $_.Exception.Message
			WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
		}
		Finally { $ErrorActionPreference = "Continue" }
	}
}


Function UIForm {
	[OutputType([string])]
	Param 
	(
    )
	Process {
		$ErrorActionPreference = "Stop";
		Try																																																														  
		{			
			WriteLog -Message "Building and start Rename Form form" -Component $MyInvocation.MyCommand.Name
			
			[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
			[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
			Add-Type -AssemblyName System.Windows.Forms | out-null
			Add-Type -assembly System.Windows.Forms | out-null
		#---- Get Size
			$Screens = [system.windows.forms.screen]::AllScreens
			$height=800 #Default value
			$width=1700 #Default vaue
		#---- Set Size
			Foreach ($display in $Screens) {
				if ($display.Primary) {
					$height=[math]::round($display.Bounds.Height*0.4)	
					$width=[math]::round($display.Bounds.Width*0.45)
				}
			}						
		#----Properties for the form
			$UIRename = New-Object System.Windows.Forms.Form
			$UIRename.Text = "Computer Name"
			$UIRename.Height = $height;
			$UIRename.Width = $width;
			#$UIRename.BackColor = "DodgeBlue"
			$UIRename.BackColor = [Convert]::ToInt32("ff1e90ff", 16)
			#$UIRename.BackColor = [Convert]::ToInt32("ffffffff", 16)
			#$UIRename.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($iconForm)
		  #--Border Form
			$UIRename.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None	
			#---styles: None, Fixed3D, FixedDialog, FixedSingle, FixedToolWindow, Sizable, SizableToolWindow
			#---enable next option for FixedToolWindow
			$UIRename.ShowInTaskbar = $false
			$UIRename.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
			$UIRename.TopMost = $true
		#----Design label top label
			$label1 = New-Object system.Windows.Forms.Label
			$Font = New-Object System.Drawing.Font("Verdana",16,[System.Drawing.FontStyle]::Bold)
			# Font styles are: Regular, Bold, Italic, Underline, Strikeout
			$label1.Font = $Font
			$label1.BackColor = "White"
			$label1.ForeColor = "Black"
			$label1.Text = " Please introduce Computer Name:"
			$label1.Left= 0
			$label1.Top= 10
			$label1.Width= $width - 20
			$label1.Height=[math]::round($height*.12)
			#optional to show border 
			$label1.BorderStyle=0
			#add the label to the form
			$UIRename.controls.add($label1)
		#---- Message to user based on $global:TextValue
			$textBox = New-Object System.Windows.Forms.TextBox
			$textBox.Location = New-Object System.Drawing.Point(15,[math]::round($label1.height+30))
			$textBox.Size = New-Object System.Drawing.Size([math]::round($width*.7),[math]::round($height*.12))
			$Font3 = New-Object System.Drawing.Font("Verdana",12,[System.Drawing.FontStyle]::Bold)
			$textBox.Font = $Font3
			$textBox.BackColor = "LightGray"
			if ($null -ne $global:TextValue) {$textBox.Text = $global:TextValue} else {$textBox.Text = ""}
			$UIRename.Controls.Add($textBox)
		#---- OK button
			$OKButton = New-Object System.Windows.Forms.Button
			$OKButton.Location = New-Object System.Drawing.Point(75,[math]::round($textBox.Top+$TextBox.height+20))
			$OKButton.Size = New-Object System.Drawing.Size([math]::round($textBox.width*.25),[math]::round($textBox.height*.9))
			$OKButton.Text = 'OK'
			$OKButton.BackColor = [Convert]::ToInt32("ff0096d6", 16)
			$OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
			$UIRename.AcceptButton = $OKButton
			$UIRename.Controls.Add($OKButton)
		#---- Cancel button
			$CancelButton = New-Object System.Windows.Forms.Button
			$CancelButton.Location = New-Object System.Drawing.Point([math]::round($OKButton.Left+$OKButton.width+($OKButton.width*.5)),[math]::round($textBox.Top+$TextBox.height+20))
			$CancelButton.Size = New-Object System.Drawing.Size([math]::round($textBox.width*.25),[math]::round($textBox.height*.9))
			$CancelButton.Text = 'Cancel'
			$CancelButton.BackColor = "LightGray"
			$CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
			$UIRename.CancelButton = $CancelButton
			$UIRename.Controls.Add($CancelButton)
		#---- Custom Label fill with $Global:AddText
			$label2 = New-Object System.Windows.Forms.Label
			$Font2 = New-Object System.Drawing.Font("Verdana",11,[System.Drawing.FontStyle]::Bold)
			$label2.Font = $Font2
			$label2.ForeColor = 'White'
			$label2.BackColor =  [Convert]::ToInt32("ff0197d6", 16)
			$label2.BorderStyle = 0
			$label2.AutoSize = $false
			#$label2.ReadOnly = $true
			$label2.Left=15
			$label2.Top= [math]::round($OKButton.top+$OKButton.height+20)
			$label2.Width= $width - 80
			$label2.Height= $height - [math]::round($label2.top)
			#$label2.Location = New-Object System.Drawing.Point(10,150)
			#$label2.Size = New-Object System.Drawing.Size(,50)
			if ($null -ne $global:AddText) {$label2.Text = $global:AddText} else {$label2.Text = "Computer name based on standard rules"}
			$UIRename.Controls.Add($label2)
		#---- Propmt Form
			$UIRename.Add_Shown({$textBox.Select()})
			$result = $UIRename.ShowDialog()
			$UIRename.Focus() | out-null
		#---- Validate information
			if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
				$global:TextValue = $textBox.Text.Trim().Replace(' ','')
				$UIRename.Close()
			}
			if ($result -eq [System.Windows.Forms.DialogResult]::CANCEL){		
				$global:TextValue = $env:computername
				$UIRename.Close()
			}
			start-sleep -Seconds 1
			WriteLog -Message "Name captured in UI form is [$($global:TextValue)]" -Component $MyInvocation.MyCommand.Name
			return $global:TextValue
		} 
		Catch 
		{
			$ErrorMessage = $_.Exception.Message
			WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
		}
		Finally { $ErrorActionPreference = "Continue" }
	}
}

Function ValidateNewCompName {
	[OutputType([bool])]
	Param 
	(
		[Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,HelpMessage="Name of computer to validate",Position=0)]
		[ValidateNotNullOrEmpty()]
		[Alias("compname")]
        [String]$ComputerName
    )
	Process {
		$ErrorActionPreference = "Stop";
		Try																																																														  
		{
			$regex = "^[A-Za-z0-9]*(?:-[A-Za-z0-9]+)*$"
			$ComputerName = $ComputerName.Trim()
			WriteLog -Message "Validate $($ComputerName)[$($ComputerName.length)]..." -Component $MyInvocation.MyCommand.Name
			if ($ComputerName.length -eq 0) {
				WriteLog -Message "New Computer name is empty [$($ComputerName)]" -MessageType Error -Component $MyInvocation.MyCommand.Name
				$global:AddText = 'Please introduce any value'
				$global:AddText | Out-Null
				return $false
			}
			if ($ComputerName.length -gt 15) {
				WriteLog -Message "New Computer name is too long $($ComputerName)" -MessageType Error -Component $MyInvocation.MyCommand.Name
				$global:AddText = 'Max length must be 15 characters'
				return $false
			} 
			If ($ComputerName -notmatch $regex) {
				WriteLog -Message "Invalid New Name for computer: $($ComputerName)" -MessageType Error -Component $MyInvocation.MyCommand.Name
				$global:AddText = "Remove invalid characters, it should start with Letter or Number"
				return $false
			} else {
				WriteLog -Message "Valid New Name for computer: $($ComputerName)" -Component $MyInvocation.MyCommand.Name
				return $true
			}
		} 
		Catch 
		{
			$ErrorMessage = $_.Exception.Message
			WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
		}
		Finally { $ErrorActionPreference = "Continue" }
	}
}

Function UnattendComputerName {
	[CmdletBinding()]
	Param 
	(
		[Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,HelpMessage="Provide full path to Unattend file",Position=0)]
		[ValidateNotNullOrEmpty()]
		[Alias("xml")]
        [String]$XMLPath,
		
		[Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,HelpMessage="Provide new name for computer",Position=1)]
		[ValidateNotNullOrEmpty()]
		[Alias("name")]
        [String]$CompName
    )
	Begin {
		WriteLog -Message "Change Value on Unattend for Computer Name" -Component $MyInvocation.MyCommand.Name
	}
	Process {
		$ErrorActionPreference = "SilentlyContinue";
		Try																																																														  
		{
			$xml = [xml](Get-Content $XMLPath)
			if ($null -eq $xml.unattend.settings) {
				WriteLog -Message "XML error, not found structure Unattend\Settings" -MessageType Error -Component $MyInvocation.MyCommand.Name
				return;
			} else {
				$nodeSettings = $xml.unattend.settings | Where-Object {$_.pass -eq 'specialize'}
			}
			#$nodeSettingsaudit = $xml.unattend.settings | where {$_.pass -eq 'auditSystem'}
			if ($null -eq $nodeSettings.component) {
				WriteLog -Message "XML error, not found structure Unattend\Settings\Specialize\Components" -MessageType Error -Component $MyInvocation.MyCommand.Name
				return;
			} else {
				$nodeComponent = $nodeSettings.component | Where-Object {$_.name -eq 'Microsoft-Windows-Shell-Setup'}
			}
			if ($null -eq $nodeComponent.ComputerName) {
				WriteLog -Message "XML error, not found structure Unattend\Settings\Specialize\Components\ComputerName" -MessageType Error -Component $MyInvocation.MyCommand.Name
				return;
			} else {
				$nodeComponent.ComputerName = $CompName
			}
			#$nodeComponentaudit = $nodeSettingsaudit.component | where {$_.name -eq 'Microsoft-Windows-Deployment'}
			#$nodeComponentaudit.Name = $CompName
			$xml.Save($XMLPath)
		} 
		Catch 
		{
			$ErrorMessage = $_.Exception.Message
			WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
		}
		Finally { $ErrorActionPreference = "Continue" }
	}
}

Function SwaptOSBoot{
	[CmdletBinding()]
	Param 
	(
		[Parameter(Mandatory=$false,HelpMessage="Switch to OS Environment",Position=0)]
		[ValidateSet("Windows", "WinPE")]
        [Alias("envi")]
        [string] $Environment
	)
	Begin { 
		if ( $PSBoundParameters.ContainsKey( "Environment" ) -eq $false ) {
			if (Test-Path Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\MiniNT) {
				$Environment="Windows"
			} else {
				$Environment="WinPE"
			}
        }
	 }
	Process {				
		Try 
		{
			$winpeid="{7619dcc8-fafe-11d9-b411-000476eba25f}"
			$ramdisk="{0f84e3b8-bab2-4209-bf1e-7e351ad25f6f}"
			
			#Where is WinPE
			$AjoloteDrive=(Get-Volume | Where-Object {$_.FileSystemLabel -eq "AJOLOTE" }).DriveLetter
			$AjoloteDrive="$($AjoloteDrive):"
			WriteLog -Message "Drive detected with WinPE: $($AjoloteDrive)" -Component $MyInvocation.MyCommand.Name 
			
			if ($null -eq $AjoloteDrive) {
				WriteLog -Message "Not possible detect WinPE partition" -MessageType Warning -Component $MyInvocation.MyCommand.Name
				return $null
			}
			if (Test-Path Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\MiniNT) {
				WriteLog -Message "WinPE Environment Detectect" -Component $MyInvocation.MyCommand.Name
			} else {
				WriteLog -Message "Windows Environment Detected" -Component $MyInvocation.MyCommand.Name
			}
			WriteLog -Message "Selected switch to $($Environment)" -Component $MyInvocation.MyCommand.Name
			switch ($Environment) {
				"Windows" { 
					bcdedit -enum `{bootmgr`} | Out-File -FilePath "$($PSScriptRoot)\bootmgr.txt" -Encoding default -Force
					$order=0;
					$flag=$false
					$EntFirst=""
					$EntSecond=""
					foreach ($line in (Get-Content "$($PSScriptRoot)\bootmgr.txt")) { 
						if ($flag) {
							if ($line.StartsWith(" ")) {
							WriteLog -Message "Second Order: $($line.Trim())" -Component $MyInvocation.MyCommand.Name
								$EntSecond=$line.Trim()
							} else {
								WriteLog -Message "Second line is not expected: $($line)" -Component $MyInvocation.MyCommand.Name
							}
							$flag=$false
						} else { 
							if (($line.Length -gt 0) -AND ($line.StartsWith("displayorder"))) {
								WriteLog -Message "Fisrt Order: $($line.replace(""displayorder"","""").Trim())" -Component $MyInvocation.MyCommand.Name
								$EntFirst=$line.replace("displayorder","").Trim()
								$flag=$true
							} 
						}
					}
					$EntFirst | Out-Null
					#Not expected that only one entry appears
					if ($EntSecond -eq "") {
						WriteLog -Message "Not detected 2nd Entry on Boot Manager Order" -MessageType Warning -Component $MyInvocation.MyCommand.Name
						return $null
					}
					WriteLog -Message "Switch to Windows GUID: $($EntSecond)" -Component $MyInvocation.MyCommand.Name
					bcdedit -displayorder $EntSecond /addfirst
					bcdedit -default $EntSecond
					break;
				 }
				 "WinPE" {
					bcdedit -enum `{bootmgr`} | Out-File -FilePath "$($PSScriptRoot)\bootmgr.txt" -Encoding default -Force
					$order=0;
					$flag=$false
					$EntFirst=""
					$EntSecond=""
					foreach ($line in (Get-Content "$($PSScriptRoot)\bootmgr.txt")) { 
						$order++;
						if ($flag) {
							if ($line.StartsWith(" ")) {
								WriteLog -Message "Second Order: $($line.Trim())" -Component $MyInvocation.MyCommand.Name
								$EntSecond=$line.Trim()
							} else {
								WriteLog -Message "Second line is not expected: $($line)" -MessageType Warning -Component $MyInvocation.MyCommand.Name
							}
							$flag=$false
						} else { 
							if (($line.Length -gt 0) -AND ($line.StartsWith("displayorder"))) {
								WriteLog -Message "Fisrt Order: $($line.replace(""displayorder"","""").Trim())" -Component $MyInvocation.MyCommand.Name
								$EntFirst=$line.replace("displayorder","").Trim()
								$flag=$true
							} 
						}
					}
					
					if ($EntSecond -eq "") {
						WriteLog -Message "Dual OS is not configured" -MessageType Warning -Component $MyInvocation.MyCommand.Name
						#Create Entry
						bcdedit -create $winpeid -d "Microsoft WindowsPE" -application OSLOADER
						bcdedit -create $ramdisk -d "Ramdisk Device Options"
						bcdedit -set $ramdisk ramdisksdidevice partition=$AjoloteDrive
						bcdedit -set $ramdisk ramdisksdipath \boot\boot.sdi
						bcdedit -set $winpeid device ramdisk=[$AjoloteDrive]\sources\boot.wim,$ramdisk
						bcdedit -set $winpeid osdevice ramdisk=[$AjoloteDrive]\sources\boot.wim,$ramdisk
						bcdedit -set $winpeid path \windows\system32\boot\winload.efi
						bcdedit -set $winpeid systemroot \windows
						bcdedit -set $winpeid detecthal Yes
						bcdedit -set $winpeid winpe Yes
						bcdedit -timeout 0
						bcdedit -bootsequence $winpeid
					} else {
						if ($EntSecond -ne $winpeid) {
							WriteLog -Message "Configured WinPE is not the expected GUID" -MessageType Error -Component $MyInvocation.MyCommand.Name
							return $null
						}
					}
					WriteLog -Message "Switch to WinPE" -Component $MyInvocation.MyCommand.Name
					bcdedit -displayorder $winpeid /addfirst
					bcdedit -default $winpeid
					break;
				 }
				Default {
					WriteLog -Message "Not possible determinate which OS is required to boot" -MessageType Error -Component $MyInvocation.MyCommand.Name
					break;
				}
			}

		}
		Catch 
		{
			$ErrorMessage = $_.Exception.Message
			WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error
		}
	}
	#End {}
}


function Save-WinPELogs {
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $SourceLogs,
        [Parameter(Mandatory = $false)]
        [int] $ErrorCode=0,
        [Parameter(Mandatory = $false)]
        [string] $ErrorMessage = "CS Built Image exit"
	)
	Begin { 
		if ( $PSBoundParameters.ContainsKey( "ErrorCode" ) -eq $false ) { $ErrorCode=$global:CodeResults } 
		if ( $PSBoundParameters.ContainsKey( "ErrorMessage" ) -eq $false ) { $ErrorMessage=$global:MessageResults } 
	}
	Process {				
		Try 
		{
			WriteLog -Message "--------------Save WinPE Logs----------------" -Component $MyInvocation.MyCommand.Name
			WriteLog -Message "Source Logs path: $($SourceLogs)" -Component $MyInvocation.MyCommand.Name
            WriteLog -Message "    Exit Message: $($ErrorMessage)" -Component $MyInvocation.MyCommand.Name
			WriteLog -Message "       Exit Code: $($ErrorCode)" -Component $MyInvocation.MyCommand.Name
			if ($ErrorCode -ne 0) {	HPControl -Set "ErrorWinPE" }
			#Validate if source exist
			if (!(Test-Path $SourceLogs)) {
                [System.reflection.assembly]::LoadWithPartialName("Microsoft.VisualBasic") |Out-Null
                $opMessage = "Not found Logs folder to backup.`r`n" +
                    "Please report to HP CS Team `r`n" 
                $null = [Microsoft.VisualBasic.Interaction]::MsgBox($opMessage,"OkOnly,SystemModal,Critical","ERROR SAVING WinPE LOGS")
			}
			WriteLog -Message "Source logs exist: $($SourceLogs)" -Component $MyInvocation.MyCommand.Name
			$DestinyLogs=""
			#Search and create destination folder
			[string]$UniqueFolder=Get-Date -Format "MMddyyyy_hhmmss"
            WriteLog -Message "Moving logs to HDD" -Component $MyInvocation.MyCommand.Name
           # $PartitionBasic = (Get-Disk | Get-Partition | Where-Object{($_.Type -eq "Basic") -AND (Test-Path "$($_.DriveLetter):\")} | Sort-Object -Property Size -Descending)
			$PartitionBasic = Get-Volume | Where-Object {$_.FileSystemLabel -eq "AJOLOTE" }
			if ($null -ne $PartitionBasic) { 
                if (!(Test-Path "$($PartitionBasic[0].DriveLetter):\system.sav")) {
                    $null = RunPower -File "cmd.exe" -Params "/c md $($PartitionBasic[0].DriveLetter):\system.sav" -OutFile "$($SourceLogs)\CreateSYSTEM.SAV.log";  
                    $null = RunPower -File "cmd.exe" -Params "/c attrib +h $($PartitionBasic[0].DriveLetter):\system.sav /d" -OutFile "$($SourceLogs)\HideSYSTEM.SAV.log"; 
                }
                if (!(Test-Path "$($PartitionBasic[0].DriveLetter):\system.sav\logs\CSBuilt\$($UniqueFolder)")) {
                    $null = RunPower -File "cmd.exe" -Params "/c md $($PartitionBasic[0].DriveLetter):\system.sav\logs\CSBuilt\$($UniqueFolder)" -OutFile "$($SourceLogs)\Create$($UniqueFolder).log";
                }
                if (Test-Path "$($PartitionBasic[0].DriveLetter):\system.sav\logs\CSBuilt\$($UniqueFolder)") {
					WriteLog -Message "Found drive to move logs at $($PartitionBasic[0].DriveLetter):\System.sav\logs\CSBuilt\$($UniqueFolder)" -Component $MyInvocation.MyCommand.Name
					$DestinyLogs="$($PartitionBasic[0].DriveLetter):\system.sav\logs\CSBuilt\$($UniqueFolder)"
                }
            } else {
                WriteLog -Message "Not possible save log on local disk due not possible detect one valid partition" -MessageType Error -Component $MyInvocation.MyCommand.Name
                [System.reflection.assembly]::LoadWithPartialName("Microsoft.VisualBasic") |Out-Null
                $opMessage = "Not possible save folder on fixed HDD, due not drive detected.`r`n" +
                    "Please report to HP CS Team `r`n" 
                $null = [Microsoft.VisualBasic.Interaction]::MsgBox($opMessage,"OkOnly,SystemModal,Critical","ERROR SAVING WinPELOGS")
			}
			if ($DestinyLogs -eq "") {
				WriteLog -Message "Fail to copy logs into HDD" -MessageType Error -Component $MyInvocation.MyCommand.Name
			} else {
				$CopyAll = RunPower -File "cmd.exe" -Params "/c xcopy /sehiy $($SourceLogs)\* $($DestinyLogs)\" -WorkDir $PSScriptRoot -OutFile "$($DestinyLogs)\MoveLogs.log";
                if ($CopyAll -ne 0) {
                    [System.reflection.assembly]::LoadWithPartialName("Microsoft.VisualBasic") |Out-Null
	                $opMessage = "It was not possible copy logs into fixed drive, error code: $($CopyAll).`r`n" +
				                "Please report to HP CS Team `r`n" 
                    $null = [Microsoft.VisualBasic.Interaction]::MsgBox($opMessage,"OkOnly,SystemModal,Critical","ERROR COPY LOGS WinPE[$($CopyAll)]") 
                }
			}
		}
		Catch 
		{
			$ErrorMessage = $_.Exception.Message
        	WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
        	[System.reflection.assembly]::LoadWithPartialName("Microsoft.VisualBasic") |Out-Null
        	$opMessage = "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage).`r`n" +
                    "Please report to Cisneros, Jorge `r`n" 
        	$null = [Microsoft.VisualBasic.Interaction]::MsgBox($opMessage,"OkOnly,SystemModal,Critical","ERROR SAVING WinPE LOGS")
		}
	}
	End {
		if ($global:CodeResults -ne 0) {
			$global:DebugMode=$true; #prevent unit reboot
		}
		try{
			Stop-Transcript|out-null
		} catch [System.InvalidOperationException]{}
		if (!($global:DebugMode)) {
			Restart-Computer -Force
			exit $ErrorCode
		} else {
			Write-Host "______________________DEBUG MODE ENABLED - NOT REBOOT________________________" -BackgroundColor Black -ForegroundColor Yellow
			$helpcmd = Start-Process "Powershell.exe" -WindowStyle Minimized -PassThru -Wait
			$helpcmd | Out-Null
		}
		
	}
    
} 


Function Close-WindowsLogs{
	[CmdletBinding()]
	Param 
	(
		[Parameter(Mandatory = $false)]
        [int] $ErrorCode=0,
        [Parameter(Mandatory = $false)]
        [string] $ErrorMessage = "CS Built Image exit"
	)
	Begin { 
		if ( $PSBoundParameters.ContainsKey( "ErrorCode" ) -eq $false ) { $ErrorCode=$global:CodeResults } 
		if ( $PSBoundParameters.ContainsKey( "ErrorMessage" ) -eq $false ) { $ErrorMessage=$global:MessageResults } 
	 }
	Process {				
		Try 
		{
			WriteLog -Message "Exit Message: $($ErrorMessage)" -Component $MyInvocation.MyCommand.Name
			WriteLog -Message "   Exit Code: $($ErrorCode)" -Component $MyInvocation.MyCommand.Name
			if (($global:CodeResults -ne 0) -OR ($global:DebugMode)) {
				$global:DebugMode=$true; #prevent unit reboot
				Write-Host "______________________DEBUG MODE ENABLED OR ERROR DETECTED - REBOOT MANUALY________________________" -BackgroundColor Black -ForegroundColor Yellow
				$null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
			}
			try{
				Stop-Transcript|out-null
			} catch [System.InvalidOperationException]{}
			if (!($global:DebugMode)) {
				WriteLog -Message "   Restart computer" -Component $MyInvocation.MyCommand.Name
				Restart-Computer -Force
			}
			exit $ErrorCode
		}
		Catch 
		{
			$ErrorMessage = $_.Exception.Message
			WriteLog -Message "Exception on $($MyInvocation.MyCommand.Name): $($ErrorMessage)" -MessageType Error -Component $MyInvocation.MyCommand.Name
		}
	}
	#End {}
}