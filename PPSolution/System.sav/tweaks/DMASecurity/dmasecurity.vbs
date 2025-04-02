option explicit
on error resume next 

rem This script does not work on IoT Enterprise since there is no DMASecurity registry value
rem MSINFO32 also does not show Device Encryption

rem May need to add rem or DeviceID like 'ACPI%' at some point - but not all ACPI device nodes have a compatible ID field.

const HKEY_LOCAL_MACHINE = &H80000002
const strKeyPath1 = "SYSTEM\CurrentControlSet\Control\DmaSecurity\Default\UnallowedBuses"
const strKeyPath2 = "SYSTEM\CurrentControlSet\Control\DmaSecurity\AllowedBuses"

dim strDMARegCmd
dim objFSO, tf
dim objReg, arrValueNames, strValueName, arrValueTypes, strRegVal
dim objWMIService, colDevices, objDevice, strCompatibleID, strVenID, strDevID, dictDevs

function IsBus(strDevID) 
    IsBus = false
    for each strValueName in arrValueNames
        call objReg.GetStringValue(HKEY_LOCAL_MACHINE, strKeyPath1, strValueName, strRegVal)
        if strDevID = strRegVal then
            IsBus = true
        end if 
    next
end function

'-----------------------------------------------------------------------------
' Initialization
'-----------------------------------------------------------------------------
If WScript.arguments.count < 1 Then
    strDMARegCmd = "c:\system.sav\tweaks\scripts\DmaSecurity_AllowedBuses.cmd"
Else
    strDMARegCmd = wscript.arguments(0)
End If

WScript.Echo "==>"
WScript.Echo "strDMARegCmd: " & strDMARegCmd
WScript.Echo

set objReg=GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
call objReg.EnumValues(HKEY_LOCAL_MACHINE, strKeyPath1, arrValueNames, arrValueTypes)

rem TAKEOWN /F <filename>
rem ICACLS <filename> /grant %username%:F
rem ICACLS <filename> /grant administrators:F
rem icacls "C:\Windows\PolicyDefinitions\WindowsStore.admx" /setowner "NT Service\TrustedInstaller"

set objWMIService = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
set colDevices = objWMIService.ExecQuery("Select * from Win32_PNPEntity where DeviceID like 'PCI%' ")

set objFSO = CreateObject("Scripting.FileSystemObject")
set tf = objFSO.CreateTextFile(strDMARegCmd, True)

tf.WriteLine("REM reg load hklm\sys c:\Windows\System32\Config\SYSTEM")

set dictDevs = CreateObject("Scripting.Dictionary")

for each objDevice in colDevices

    for each strCompatibleID in objDevice.CompatibleID

    strVenID = mid(objDevice.DeviceID,  9, 4)
    strDevID = mid(objDevice.DeviceID, 18, 4)

        if IsBus(strCompatibleID) then

                   strValueName = objDevice.Description
            if right(objDevice.Description, 5) <> (" " & strDevID) then 
                strValueName = strValueName & " - " & strVenID & " " & strDevID
            end if        
            'wscript.echo strVenID & vbTab & strDevID & vbTab & strValueName

            if not dictDevs.Exists(strValueName) then 
              call dictDevs.Add(strValueName, strValueName)
              wscript.Echo "REM " & strCompatibleID & vbTab & objDevice.DeviceID & vbTab & objDevice.Description
              wscript.echo "REM REG ADD HKLM\SYSTEM\CurrentControlSet\Control\DmaSecurity\AllowedBuses /V " & """" & strValueName & """" & " /T REG_SZ /F /D " & """" & Left(objDevice.DeviceID,21) & """"

              tf.WriteLine("reg add hklm\sys\ControlSet001\Control\DmaSecurity\AllowedBuses /v " & """" & strValueName & """" & " /t REG_SZ /f /d " & """" & Left(objDevice.DeviceID, 21) & """")
              call objReg.SetStringValue(HKEY_LOCAL_MACHINE, strKeyPath2, strValueName, Left(objDevice.DeviceID,21))

              wscript.echo
          end if
        end if
    next
next

tf.WriteLine("REM reg unload hklm\sys")

Set tf = Nothing
Set objFSO = Nothing
