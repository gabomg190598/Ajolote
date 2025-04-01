2.0.3.9 [10/00/2024]
	-Added Windows 24H2 support 
	-Updated Modules due sysprep issue detected on Windows 26100
		Windows_sysprep, WinPE_saveimage, CSImageBuilder.Functions, CSImageBuilder, CSBuiltimage.Functions, ReturnAjolote

2.0.3.8 [9/14/2024]
	-Fibocom issue: Pre-detection inside of _INF folder and moving for PP or RunOnce, preventing to be injected.
		Module updated: WinPE_configuredrivers
	-Microsoft Update Septeber 10, 2024

2.0.3.7 [8/21/2024]
	-Microsoft Updates August 13, 2024
	-Corrected a couple typo errors on WinPE_checkmsupdatesonly, WinPE_installupdates
	-PPSolution small changes on labels and logs for 2nd step
	
2.0.3.6 [8/7/2024]
	-Improve Enable RSAT module, retrieving report in image build and PPSolution
	-Fix error detected on update modules that prevent fail even when latest update is applied to WinRE.
		Improvement on modules: WinPE_checkmsupdatesonly, WinPE_installupdates
	-Improve report to include country and RSAT feature status
		Improved PPSolution and Windows_sysprep module
	
2.0.3.5 [7/26/2024]
	-Fix Bug 309: updated module Windows_InteractiveLight to avoid empty CVA files
	-Updating WinPE_HPDocumentation to improve detection of latest version from local repository
	-Introducing new feature: Enable RSAT, module to install all FOD required to enable RSAT tools
		https://learn.microsoft.com/en-us/troubleshoot/windows-server/system-management-components/remote-server-administration-tools
		New module under testing: WinPE_EnableRSAT
	-PPSolution improved, now can detect and install standard components from C:\SWSETUP\DRV\
		
		
2.0.3.4 [07/16/2024]
	-Microsoft Updates July, 9 2024
	-Fix issue detected for latest MS updates, require update process on modules:
 	    	Windows_checkmsupdates, WinPE_checkmsupdatesonly, WinPE_installupdates
	-Small fix to Ajolote system time sync process.
	

2.0.3.3 [7/4/2024]
	-Improve process with new feature for localization: Country
		Configure as requested, valid countries (use Location (Short Name)): https://learn.microsoft.com/en-us/windows/win32/intl/table-of-geographical-locations
	-PPSolution updated
		Fix bug 260, adding C:\SWSETUP folder to captured state during PP
		Fix issue with DMA access denied on registry
	-Improve Ajolote system time, set function to sync Ajolote units with server [beta]

		
2.0.3.2 [6/17/2024]
	-Microsoft Updates June, 11 2024
	-PPSolution upgrade 2.0
		new process
		new interface
		new options
	-Fix issue with Create New user option, module updated: Windows_presysprep
	-Updated Get-CVAObject functions to prevent errors when CVA is empty file, however some modules could require update to double check
		-Updated Module  WinPE_ProgrammableKey, WinPE_HPHwDiagnosticUEFI, WinPE_HPDocumentation, Windows_HPSureView, Windows_HPPrivacySettings, Windows_HPPowerManager, Windows_HPNotification, Windows_HPHwDiagnosticWin, Windows_HPDocumentation, Windows_HPCollaborationKb, Windows_HPClientSecurityManager
	-Introduce new feature: Install Software from specific folder, using new module it will be possible to execute a silent command based on folder provided.
		1) Moving folder to OS drive
		2) Especify which Environment should be used
		3) Execute silent command
		4) New Modules: WinPE_InstallSoftware and Windows_InstallSoftware
	-Update module WinPE_saveimage for new PPSolution and create a scenario for TCO where is requested but no PPSolution present (under testing).
	-Introduce new feature, post audt mode script excecution - case Disney [testing]
		A CMD script can be drop and executed as part of last reseal step.
		File must be exist and named as C:\system.sav\tweaks\FSScripts\Post_FSAuditMode.cmd
		Designed to run during PPSolution 2.0
		Drop logs into C:\System.sav\logs
	-Introduce new feature, registry key creation - Case Disney
		registries are created just before sysprep
	-New office version requires updates modules: WinPE_removeoffice & Windows_setupoffice, new options on OfficeLanguageDic.json
		365 apps version 16.0.17328.20206 for Windows 11
	-Ajolote version change given the new ITG environment for a better control. 
		

2.0.2.9 [4/12/2024]
	-Microsoft Updates April 9, 2024
	-Introduce new feature to create users as part of image creation
		This will not prevent to new user will create during OOBE
		All properties must be specify
		Case: Raymond James
	-Introduce new feature to copy full structure into OS partition
		Case: Motorola
	New module Windows_presysprep to support new user creation
	Improve module Windows_InstallPPKG, Windows_sysprep
	Improve module Windows_RemoveAppx 
		Case: KAISER
	Improve CSImageBuilder.Functions 
		to retrieve Windows Logs (setupact and setuperr) in case of failure
		to capture screenshot on failure 
	Update RunPower function
	Fix issue on InstallPPKG module, timeout was not properly implemented to stop and fail.
	Same issue with Windows 19044 as last month, open rule to always remove Edge appx no matter revision.
	Fix issue on Windows_HPHwDiagnosticWin when CVA has incomplete information.
	Update Windows_setupoffice to remove installer folder on success, this was leaded by PPKG installation module and update 
		Case: KAISER
	Fix minor error on modules: WinPE_hpiadrivers and WinPE_checkmsupdatesonly
	
	
2.0.2.8 [3/23/2024]
	-Microsoft Updates March, 2024
	-Update WriteLog Module
	-Introduce new feature to build images for HPIA (feature available on PPSolution2), new module: WinPE_hpiadrivers
	-Introduce new feature to Enable Windows Identity Foundation (WIF). New module: WinPE_EnableIdentityFoundations
		Windows Identity Foundation (WIF) is a new extension to the Microsoft .NET Framework that makes it easy for developers 
		to enable advanced identity capabilities in the .NET Framework applications. Based on interoperable, standard protocols, 
		Windows Identity Foundation and the claims-based identity model can be used to enable single sign-on (SSO), personalization, 
		federation, strong authentication, identity delegation, and other identity capabilities in ASP.NET and Windows Communication 
		Foundation (WCF) applications that run on-premises or in the cloud.
		Module beta version, for now it can be enabled on any Windows build and not preinstalled requirements.
	-Update modules:
		WinPE_saveimage
		Windows_sysprep
		WinPE_HPDocumentation
		Windows_HPDocumentation
	-Fix issue with report imagebuild with languages installed
	-Introduce new feature: Instal Standard PPKG <BETA>
		-Based on KAISER FOUNDATION HEALTH PLAN complain
		-new modules created: WinPE_InstallPPKG, Windows_InstallPPKG
		-update module Windows_sysprep: prevent to remove Unattend.xml when PPKG installation is requested.
		-Based on standard PPKG created by Windows Imaging and Configuration Designer (WCD) and supported by AY709AV service
	-Fix issue detected on Windows_HPNotification module, adding wait time before to valiadate result of installation.
	-Fix issue detected on WinPE_ProgrammableKey module, typo issues on code.

	
2.0.2.7 [2/16/2024]
	-Microsoft Updates February, 2024
	-Improve Microsoft Updates to better control to include and exclude updates.
		modules: WinPE_installupdates, WinPE_checkmsupdatesonly, Windows_checkmsupdates
	-Remove of Recovery folder when is empty. module updated WinPE_PreSaveImage
	-Due an issue with Windows update 19044.4046 a rule was created on Windows_sysprep
	-Report html was improved to include locale information, module Windows_sysprep
	-Order of set time zone was moved after set default language due a report, not confirmed if issue was solved yet module updated WinPE_languagesetup
	

2.0.2.6 [1/24/2024]
	-Microsoft Updates January, 2024
	-Fix error on WinPE_languagesInboxApps module detecting Windows 10 and Windows 22000
	-Updated Microsoft 365 apps aka MS Office
		Windows 11 
			Version: 16.0.16327.20264
			Microsoft 365 Apps for enterprise - [lang tag]
			Microsoft OneNote - [lang tag]
			Microsoft Teams (1.5.00.30767)
			Teams Machine-Wide Installer (1.5.0.30767)
		Windows 10
			Version: 16.0.15128.20246
			Microsoft 365 Apps for enterprise - [lang tag]
			Microsoft Teams (1.5.00.4689)
			Teams Machine-Wide Installer (1.5.0.4689)
		Office modules improved to install languages based on image LPs installed and defined dictionary
			WinPE_removeoffice, Windows_setupoffice
			Language packages for Microsoft 365 Apps were included on Components share folder

2.0.2.5 [1/12/2024]
	-Microsoft Updates December, 2023
	-Adding support for Layered Driver (Agilent)
	-Minor fix to Audit script for Windows 11 versions
	-Adding cleansup commands for WinPE TEMP folder to avoid full disk error
	-Adding support for activation of .Net 3.5 on Windows 22631
	-New Module WinPE_languagesInboxApps.ps1 for reinstall Inbox Apps when default language different from en-us selected
	-PPSolution update: create script for protect system.sav folder during reset
	-Modification on modules to adapt new process: WinPE_languagesetup, Windows_checkmsupdates, WinPE_checkmsupdatesonly, WinPE_saveimage
	-New function to create flags into C:\system.sav\flags directly as part of image build.
	
	
2.0.2.4 [11/22/2023]
	-Microsoft Updates November, 2023
	-Adding support for Windows 11 23H2 (22631)
		WIM
		PPSolution
		Module: Windows_checkmsupdates.ps1
		Module: WinPE_installupdates.ps1
		Module: WinPE_languagesetup.ps1
	-PPSolution updated to implement P00W65-B2E - Tweak - Update DMASecurity_AllowedBuses
	
2.0.2.3 [8/22/2023]
	-Microsoft Updates September, 2023
	-Update/improve modules:
		Windows_checkmsupdates.ps1
		WinPE_ExecuteScript.ps1 [beta]
	-Update PPSolution 9.21.2023 - Remove BlackLotus revocations phase 2

2.0.2.2 [8/22/2023]
	-Microsoft Updates August 8, 2023
	-Update/improve modules:
		Windows_checkmsupdates.ps1
		WinPE_checkmsupdatesonly.ps1
		WinPE_installupdates.ps1
		WinPE_saveimage.ps1
	-New modules:
		WinPE_ExecuteScript.ps1 [beta]
		Windows_ExecuteScript.ps1 [beta]
	-Update PPSolution 8.20.2023 - Include BlackLotus revocations phase 2
	
2.0.2.1 [8/8/2023]
	-Ajolote WinPE update to 22621.1992 July 11, 2023 Microsoft Update, Secure Boot recreation files
	-Update latest CSModules
	-Update latest hp-cmsl-1.6.10
	-Update WinPE Drivers: SP145240 WinPE10_2.40
	-Added HotKey features:
		Shift + F10 |or| F10 = Opens Powershell prompt
		Shift + F8 |or| F8 = Opens CMD prompt
		F2 = Open Registry Editor
	-Improve/Fix issues below modules:
		WinPE_checkmsupdatesonly.ps1
		WinPE_configuredrivers.ps1
		WinPE_HPDocumentation.ps1
		WinPE_installupdates.ps1
		WinPE_languagesetup.ps1
		WinPE_PreSaveImage.ps1
		WinPE_saveimage.ps1
    		WinPE_EnableNetFX35.ps1
		Windows_checkmsupdates.ps1
		Windows_HPDocumentation.ps1
		Windows_sysprep.ps1
		CSImageBuilder.ps1
		CSImageBuilder.Functions.ps1
		CSBuiltImage.ps1
		CSBuiltimage.Functions.ps1
	-Microsoft Updates July 11, 2023
	-Update PPSolution, adding a validation for display when basic driver is detected (beta)

2.0.1.22 [6/29/2023]
	-logged same issue on MS updates for 19044 when more than 1 language is requested

2.0.1.21 [6/27/2023]
	-Update PPSolution adding sleep time before to scan Device Manager
	-Fix issue detected on MS updates for build 19045 when request more than 1 language

2.0.1.20 [6/25/2023]
	-Update Windows_HPHwDiagnosticWin.ps1
	-Update Windows_checkmsupdates.ps1
	-Microsoft Updates Jun 13

2.0.1.19 [5/24/2023]
	-Change on CSAuditMode.ps1 - removing IPK installation due Windows 11 Activation issue (disabled CSPK.flg)
	-Microsoft Updates May 9

2.0.1.18 [5/10/2023]
	-Improve Ajolote modules [Windows_ipk.ps1] [Windows_lastreboot.ps1] to create CSPK.flg which include Custom PK.
	-Update PPSolution [5.8.2023], Support C:\system.sav\flags\CSPK.flg - Prevent PP replace custom PK with OEM

2.0.1.17 [4/26/2023]
	-Microsoft Updates April

2.0.1.16 [4/3/23]
	-Update PPSolution, fix issue when reboot code delete script itself preventing continue with PP
	-improve module: WinPE_HPDocumentation.ps1, dynamic path retrieve from config.xml
  	-Improve Config.xml to include local HP Documentation path
	-Improve MountDrive.exe to support local HP documentation repo
	-Microsoft Updates March 

2.0.1.15 [2/232023]
	-Microsoft Updates February
	-Emergency update to fix bug "After Windows Reset PBR Teams app not appears"

2.0.1.14 [1/21/2023]
	-Removing install_Prox6421H1_19043.wim
	-Improve WinPE_languagesetup.ps1
	-Microsoft Updates January

2.0.1.13 [1/2/2023]
	-Fixing typo issues with WinPE_HPDocumentation.ps1
	-Fixing issues on WinPE_PreSaveImage.ps1
	-Moving HP HW Diagnostic UEFI to individual module: WinPE_HPHwDiagnosticUEFI.ps1 [19]
	-Adding Module: WinPE_ProgrammableKey.ps1 [18]
	-Update PPSolution to support Windows 10 19045 (22H2)
	-Update WinPE_configuredrivers.ps1 to inject storage driver to WinRe: Issue on Z2 G9 platforms detected
	-Microsoft Updates Decembers

2.0.1.12 [11/10/2022]
	-PPSolution update, now create html report for Applications and installed Software 
	-Fix issue on Module: Windows_HPNotification.ps1
	-Update module WinPE_saveimage.ps1 to remove folder C:\SWSETUP\APP before to save image, otherwise PPSolution will try to reinstall Office.
	-Update GBU Office package to correct issue installing Teams. 
		Note: Teams are now installed on Windows 10 and Windows 11
	-Adding WIM for Windows 10 Pro (pro, pro for education and pro for workstations) 22H2 (19045)
		Note: not removed previous versions, expected to require more space on Ajolote Drive.
	-Updates solution and modules: WinPE_languagesetup.ps1, WinPE_detectipk.ps1 - Supporting Windows 10 22H2 (19045)
	-Microsoft Updates November - out-of-band to cover Windows 10 22H2 (19045) version

2.0.1.11 [10/27/2022]
	-Error Detected on PPSolution when AY152AV component is present, fix component.
	-Adding Module: WinPE_HPSupportAssistant.ps1 [17]
	-Adding Module: Windows_HPSupportAssistant.ps1 [15]
	-Updating GBU office packages to version 16.0.15128.20056
          Still bug: Teams is not been installed on Windows 10
	-This version could require more space for Ajolote partition (~71GB)

2.0.1.10 [10/23/2022]
	Emergency Update
	-Improve Update validation, to support a scenario detected on Windows 11 22H2 October updates
	-Fix issue with module Windows_checkmsupdates.ps1, reading Exception lists
	-Fix issue selecting Office for Windows 11 22H2 on module: WinPE_removeoffice.ps1
	-Adjust October's MS updates for build 22621
	-Improve process: Create general report in HTML format

2.0.1.9 [10/21/2022]
	-Fixed issue on function Get-CVAObject
	-Fixed issue on module: Windows_checkmsupdates.ps1 - Unexpected status for testing updates when reboot was requested.
	-Improve function Invoke-MountServer adding option to "wakeup" mounted drive
	-Adding Module: WinPE_HPDocumentation.ps1 [16]
	-Adding Module: Windows_HPDocumentation.ps1 [12]
	-Adding Module: Windows_HPPowerManager.ps1 [13]
	-Adding Module: Windows_HPClientSecurityManager.ps1 [14]
	-Module change: Windows_HPNotification.ps1 - Adding exeptions cases to allow retry for certains return codes, unknown RC.
	-Microsoft Updates: October
	Note: Windows 22621 still not ready for production, a missing update cannot locate on catalog:
              2022-08 Security Update for Windows 11 22H2 for x64-based Systems (KB5012170)
              Working to improve Ajolote seeking exception like this update.

2.0.1.8 [10/13/2022]
	-Update AjoloteMonitor.exe - Fix issue detected where stuck on task when other process is using
	-Update AjoloteMonitor.exe - Adding support for Windows 11 build 22621
	-Improve CSImageBuilder.Functions.ps1, CSBuiltimage.Functions.ps1- function Get-CVAObject to return each line of [ReturnCode]
	-Adding Module: Windows_HPNotification.ps1 [6]
	-Adding Module: Windows_HPPrivacySettings.ps1 [7]
	-Adding Module: Windows_HPSureView.ps1 [8]
	-Adding Module: Windows_HPHwDiagnosticWin.ps1 [20]
	-Adding Module: WinPE_HPImageAssistant.ps1 [15]
	-Adding Module: Windows_HPImageAssistant.ps1 [10]
	-Adding Module: Windows_HPCollaborationKb.ps1 [9]
	-Adding Module: Windows_InteractiveLight.ps1 [11]
	-Adding Module: Windows_3p_AdobeReader.ps1 [30]
	-Adding Module: WinPE_3p_AdobeReader.ps1 [30]
	-Adding Module: Windows_3p_Java.ps1 [34]
	-Adding Module: WinPE_3p_Java.ps1 [34]
	-Adding Module: Windows_3p_7zip.ps1 [31]
	-Adding Module: WinPE_3p_7zip.ps1 [31]
	-Adding Module: Windows_3p_GoogleChrome [32]
	-Adding Module: WinPE_3p_GoogleChrome.ps1 [32]
	-Adding Module: Windows_3p_MozillaFirefox.ps1 [33]
	-Adding Module: WinPE_3p_MozillaFirefox.ps1 [33]
	-Adding Module: WinPE_PreSaveImage.ps1 [98]
	-Improve Module: WinPE_configuredrivers.ps1 [6]
	-Changes Module: WinPE_saveimage.ps1 [99] - required to allow module WinPE_HPImageAssistant.ps1

2.0.1.7 [10/7/2022]
	-Microsoft Updates: September
	Note: Windows 22621 is preview update, it cannot be use for production.


