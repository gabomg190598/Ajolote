REM The following is required in all INSTALL.CMD files
Call c:\system.sav\util\SetVariables.cmd
Set block=%~dp0
CD "%block%"
REM Add the command-line to have your component to be installed properly

set lgname=c:\hp\support\LanguageSettings.INI

if not exist c:\hp\tmp md c:\hp\tmp\

set blockSS=c:\hp\tmp

xcopy c:\windows\system32\oobe\info\oobe.xml %blockSS%\ /y
xcopy c:\windows\syswow64\oobe\info\oobe.xml %blockSS%\ /y

copy /y %blockSS%\oobe.xml oobesource.xml

set pn.>>t.cmd
call t.cmd
set countcount=%pnpn:~3,3%

if /I  "%languagecode%"=="ABM" set languagecode=%countcount%

cmd /u /c %BIN%\UINI %lgname%  %languagecode% count nblang nblang.bat

call %block%\nblang.bat

setlocal enabledelayedexpansion

if DEfined nblang  (

   FOR /L %%n IN (1,1,%nblang%) DO (

   	cmd /u /c %BIN%\UINI %lgname%  %languagecode% lang%%n% xlang xlang.bat
 	call %block%\xlang.bat
	cmd /u /c del %block%\xlang.bat
	if DEfined nblang  (
		cmd /u /c %BIN%\UINI %lgname%  !xlang!_%languagecode% clanguage clanguage xlang2.bat
		call %block%\xlang2.bat
		cmd /u /c %BIN%\UINI %lgname%  !xlang!_%languagecode% clocation clocation xlang2.bat
		call %block%\xlang2.bat
		cmd /u /c %BIN%\UINI %lgname%  !xlang!_%languagecode% clocale   clocale  xlang2.bat
		call %block%\xlang2.bat
   		cmd /u /c %BIN%\UINI %lgname%  !xlang!_%languagecode% ckeyboard ckeyboard xlang2.bat
   		call %block%\xlang2.bat
   		for /F "delims=]" %%i in ( %lgname% ) do  (
			set toto=%%i 
			if /i "%languagecode%_TZ"=="!toto:~0,6!" set TZ=!toto:~7!
		)
   		cmd /u /c del %block%\xlang2.bat 

 		if exist c:\windows\system32\oobe\info\oobe.xml (
			set oobet=%blockSS%\toobe.xml
	
			echo changing oobe.xml for %ISO_COUNTRY% %ISO_LG% %LANGUAGECODE% > %log%\changeoobe.xml

	
			echo ^<?xml version="1.0" encoding="utf-8" ?^> >!oobet!
			echo  ^<defaults^> 	>>!oobet! 
			if defined clanguage (
				echo  ^<language^> 	>>!oobet! 
				echo !clanguage!	>>!oobet! 
				echo ^</language^>  	>>!oobet! 
			)
			if defined clocation (
				echo ^<location^> 	>>!oobet! 
				echo !clocation!	>>!oobet! 
				echo ^</location^> 	>>!oobet! 
			)
			if defined clocale (
				echo ^<locale^>	>>!oobet! 
				echo !clocale!	>>!oobet! 
				echo ^</locale^> 	>>!oobet! 
			)

			if defined ckeyboard (
				echo ^<keyboard^> 	>>!oobet! 
				echo !ckeyboard!	>>!oobet! 
				echo ^</keyboard^> 	>>!oobet! 
			)
			if defined TZ (
				echo ^<timezone^> 	>>!oobet! 
				echo !TZ!		>>!oobet! 
				echo ^</timezone^> 	>>!oobet! 
			)
			echo ^<moveRegionalSettingsAfterLanguage^>true^</moveRegionalSettingsAfterLanguage^>	>>!oobet! 
			echo ^<hideRegionalSettings^>false^</hideRegionalSettings^>	>>!oobet! 
			echo ^</defaults^> 	>>!oobet! 
		start /w oobechange.exe
		xcopy %blockSS%\oobe.xml c:\windows\system32\oobe\info\default\!clanguage!\ /Y
		copy /Y %block%\oobesource.xml %blockSS%\oobe.xml

		)

	     )
	)

)

if %nblang%==1 xcopy c:\windows\system32\oobe\info\default\!clanguage!\* c:\windows\system32\oobe\info\ /Y

endlocal

rd /q /s c:\hp\tmp

Rem Remove the REM from the next line if your component does not support selective restore
Erase /F /Q *.CVA