#requires -Modules "WriteLog"

<#
.SYNOPSIS
    Change State of Window 
.DESCRIPTION
	Hide, Show, Minimize, Maximize, etc window from Powershell.
.NOTES
	Script version 1.0.2
	Script Date May.8.2021
.PARAMETER InputObject
    Bind object to affect 
.PARAMETER Style
	Select new style for object 
.EXAMPLE

    Get-Process -Name ZSATray | Set-WindowStyle -Style MINIMIZE
#>

function Set-WindowStyle {
	[CmdletBinding(DefaultParameterSetName = 'InputObject')]
	param(
		[Parameter(Position = 0, Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelinebyPropertyName = $True)]
		[Object[]] $InputObject,
		[Parameter(Position = 1)]
		[ValidateSet('FORCEMINIMIZE', 'HIDE', 'MAXIMIZE', 'MINIMIZE', 'RESTORE', 'SHOW', 'SHOWDEFAULT', 'SHOWMAXIMIZED', 'SHOWMINIMIZED', 'SHOWMINNOACTIVE', 'SHOWNA', 'SHOWNOACTIVATE', 'SHOWNORMAL')]
		[string] $Style = 'SHOW'
	)

	BEGIN {
		WriteLog -Message "Change Window Style to $($Style)" -Component $MyInvocation.MyCommand.Name 
		$WindowStates = @{
			'FORCEMINIMIZE'   = 11
			'HIDE'            = 0
			'MAXIMIZE'        = 3
			'MINIMIZE'        = 6
			'RESTORE'         = 9
			'SHOW'            = 5
			'SHOWDEFAULT'     = 10
			'SHOWMAXIMIZED'   = 3
			'SHOWMINIMIZED'   = 2
			'SHOWMINNOACTIVE' = 7
			'SHOWNA'          = 8
			'SHOWNOACTIVATE'  = 4
			'SHOWNORMAL'      = 1
		}

$Win32ShowWindowAsync = Add-Type -MemberDefinition @'
[DllImport("user32.dll")] 
public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow); 
'@ -Name "Win32ShowWindowAsync" -Namespace Win32Functions -PassThru
	
	}

	PROCESS {
		foreach ($process in $InputObject) {
		    $Win32ShowWindowAsync::ShowWindowAsync($process.MainWindowHandle, $WindowStates[$Style]) | Out-Null
		    WriteLog -Message "Set Window Style $($MainWindowHandle) on $($Style)" -Component $MyInvocation.MyCommand.Name 
		}
	}
}