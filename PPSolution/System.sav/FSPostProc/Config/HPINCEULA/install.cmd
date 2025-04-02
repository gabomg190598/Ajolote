echo on

rem *NOTE: use 00 worldwide, use E5 (International Spanish) instead of 07 and 16
if not defined UPDriveLetter set UPDriveLetter=%~d0
set Eula_logfile=%UPDriveLetter%\system.sav\logs\OSIT\EULA\HP_EULA.log
if not exist %UPDriveLetter%\system.sav\logs\OSIT\EULA (
  MD %UPDriveLetter%\system.sav\logs\OSIT\EULA
)

call %UPDriveLetter%\system.sav\util\SetVariables.cmd
Set block=%~dp0
CD /D "%block%"
set EULA_DIR=C:\WINDOWS\SYSTEM32\OOBE\INFO\DEFAULT

echo. >> "%Eula_logfile%"
echo ^>^> %~f0 >> "%Eula_logfile%"
echo ^>^> %date% %time% >> "%Eula_logfile%"
echo. >> "%Eula_logfile%"

echo Erase CVA file since component is not to be a part of app/driver recovery. >> %Eula_logfile%
erase /F /Q *.CVA >> %Eula_logfile%

@REM default use 2015_EULA files
SET EULA_SOURCE=HPINC
@REM debug remove HPINC.flg and HPEULA2021_HP_wolf_security.flg
if exist %UPDriveLetter%\system.sav\FLAGS\%EULA_SOURCE%.flg del /S /Q %UPDriveLetter%\system.sav\FLAGS\%EULA_SOURCE%.flg
if exist %UPDriveLetter%\system.sav\FLAGS\HPEULA2021_HP_wolf_security.flg del /S /Q %UPDriveLetter%\system.sav\FLAGS\HPEULA2021_HP_wolf_security.flg


Copy /y nul %UPDriveLetter%\system.sav\FLAGS\%EULA_SOURCE%.flg
SET EULA_flg=%UPDriveLetter%\system.sav\FLAGS\%EULA_SOURCE%.flg
echo Default EULA Files name=%EULA_SOURCE% >> %Eula_logfile%


@REM ############################
@REM ### condition ###
@REM -	Windows 10 PRO and LTSC:

@REM o	On corporate ready image:  R_ENTRDY  or  V_MMD 
@REM    	Feature bytes Kodiak or kodiak1Y is on:
@REM      •	install HP 2021 EULA + HP wolf security 2021 EULA
@REM    	Feature bytes Kodiak or kodiak1Y is not on:
@REM      •	install HP 2015 EULA

@REM o	On non-Corporate ready image 
@REM    	feature bytes HPShield is on: 
@REM      •	install HP 2021 EULA + HP wolf security 2021 EULA
@REM    	feature bytes HPShield is not on:
@REM      •	install HP 2015 EULA

@REM -	On windows 10 S and windows 10 HOME ( vos,ml or and VOS .sl ) will have HPshield FB but HP sure sense 2 not part of the image.
@REM  	install HP 2015 EULA

@REM -	windows 10 SAC ( build id using K )   => it will not have HPShield or Kodiaks
@REM  	install HP 2015 EULA

@REM -	windows 10 RS1 IOT ( build id using J )  
@REM  	install HP 2015 EULA

@REM -	windows 10 G ( build id using G)  
@REM  	install HP 2015 EULAs

@REM   ACB always install HP 2015 EULAs


@REM ############################



@REM 20210412_start ===decide 2015EULA or wolf security eula===
@REM S mode or Build ID K6/G6/J6 (Win10S/Win10 SAC/Win G/Win10 RS1 IOT) default 2015 EULA
@REM (Vos.B/Vos.SL/Vos.ML/VOS.EMBPOS)+(V_MMD/R_ENTRDY)+(Kodiak/kodiak1Y) default HPEULA2021_HP_wolf_security
@REM (Vos.B/Vos.SL/Vos.ML/VOS.EMBPOS)+ (HPShield) default HPEULA2021_HP_wolf_security

@REM special OS
:CheckOS_Type
if defined S_MODE (
  echo FeatureByte=S_MODE,Always use default EULA=%EULA_SOURCE% >> %Eula_logfile%
  echo goto checklanguage function >> %Eula_logfile%
  goto checklanguage
)


if "%BUILDID:~7,1%"=="K" (

    echo ML_OS_BuildID=%BUILDID:~7,1% >> %Eula_logfile%
    echo Windows 10 SAC,Always use default EULA=%EULA_SOURCE% >> %Eula_logfile%
    echo goto checklanguage function >> %Eula_logfile%
    goto checklanguage

) else if "%BUILDID:~7,1%"=="G" (
    echo ML BuildID=%BUILDID:~7,1% >> %Eula_logfile%
    echo Windows 10 G,Always use default EULA=%EULA_SOURCE% >> %Eula_logfile%
    echo goto checklanguage function >> %Eula_logfile%
    goto checklanguage

) else if "%BUILDID:~7,1%"=="J" (
    echo ML_OS_BuildID=%BUILDID:~7,1% >> %Eula_logfile%
    echo Windows 10 RS1 IOT,Always use default EULA=%EULA_SOURCE% >> %Eula_logfile%
    echo goto checklanguage function >> %Eula_logfile%
    goto checklanguage
) else (
    echo ML_OS_BuildID=%BUILDID:~7,1% >> %Eula_logfile%

)

@REM Support win10 pro/LTSC OS
if defined VOS.EMBPOS if defined DPK_LTSC18 (
  echo FeatureByte=VOS.EMBPOS , FeatureByte=DPK_LTSC18 >> %Eula_logfile%
  echo OS:Win10 IOT LTSC
  goto checkMMDimage
) 


if defined Vos.B if defined DPK_LTSC18 (
  echo FeatureByte=Vos.B , FeatureByte=DPK_LTSC18 >> %Eula_logfile%
  echo OS:Win10 IOT LTSC
  goto checkMMDimage
) 

if defined Vos.WKS (
  echo FeatureByte=Vos.WKS >> %Eula_logfile%
  echo OS:Win10 Workstation >> %Eula_logfile%
  goto checkMMDimage
) 

if defined Vos.B (
  echo FeatureByte=Vos.B >> %Eula_logfile%
  echo OS:Win10 Pro >> %Eula_logfile%
  goto checkMMDimage
) 

@REM If the above conditions are not met, the default value will be used.(Installition HP2015 EULA)
echo Not support Win10 pro/LTSC OS condition,it always set default EULA=%EULA_SOURCE% >> %Eula_logfile%
goto checklanguage


:checkMMDimage
if defined V_MMD (
  echo FeatureByte=V_MMD >> %Eula_logfile%
  goto corporate
)

if defined R_ENTRDY (
  echo FeatureByte=R_ENTRDY >> %Eula_logfile%
  goto corporate
)

goto Noncorporate


:corporate
echo. >> %Eula_logfile%
echo This's corporate image >> %Eula_logfile%
if defined Kodiak (
  echo FeatureByte=Kodiak >> %Eula_logfile%
  goto Eula_HP_wolf_security_folder
) else if defined kodiak1Y (
  echo FeatureByte=kodiak1Y >> %Eula_logfile%
  goto Eula_HP_wolf_security_folder
) else (
  goto checklanguage
)

:Noncorporate
echo This's non corporate image >> %Eula_logfile%
if defined HPShield (
  echo FeatureByte=HPShield >> %Eula_logfile%
  goto Eula_HP_wolf_security_folder
) else (
  goto checklanguage
)


:Eula_HP_wolf_security_folder
@REM Not support install ACB,so it still use default HP EULA(817678-XX1.html).
if defined PN.ACB (
  echo locate=PN.ACB >> %Eula_logfile%
  echo Not support install "ACB" image ,so it still use default EULA=%EULA_SOURCE% >> %Eula_logfile%
  goto checklanguage
) 


@REM del HPINC.flg,and created HPEULA2021_HP_wolf_security.flg
if exist %UPDriveLetter%\system.sav\FLAGS\%EULA_SOURCE%.flg (
  echo del /S /Q %UPDriveLetter%\system.sav\FLAGS\%EULA_SOURCE%.flg >> %Eula_logfile%
  del /S /Q %UPDriveLetter%\system.sav\FLAGS\%EULA_SOURCE%.flg >> %Eula_logfile%
  
)
set EULA_SOURCE=HPEULA2021_HP_wolf_security
echo Copy /y nul %UPDriveLetter%\system.sav\FLAGS\%EULA_SOURCE%.flg >> %Eula_logfile%
Copy /y nul %UPDriveLetter%\system.sav\FLAGS\%EULA_SOURCE%.flg >> %Eula_logfile%

echo EULA Files name=%EULA_SOURCE% >> %Eula_logfile%
goto checklanguage

@REM 20210412_End ===decide 2015EULA or wolf security eula===END


:checklanguage


:EULA_file_copy
rem copy the default HP INC EULA which will be English.
echo EULA_folder_name=src\%EULA_SOURCE%\* >> %Eula_logfile% 

if not exist %EULA_DIR% mkdir %EULA_DIR%
echo. >> %Eula_logfile% 
echo copy the default HP INC EULA which will be English. >> %Eula_logfile% 
echo xcopy /y src\%EULA_SOURCE%\??????-00?.rtf %EULA_DIR%\OEMEULA.RTF* >> %Eula_logfile% 
xcopy /y src\%EULA_SOURCE%\??????-00?.rtf %EULA_DIR%\OEMEULA.RTF* >> %Eula_logfile% 

echo xcopy /y src\%EULA_SOURCE%\??????-00?.HTML %EULA_DIR%\OEMEULA.HTML* >> %Eula_logfile% 
xcopy /y src\%EULA_SOURCE%\??????-00?.HTML %EULA_DIR%\OEMEULA.HTML* >> %Eula_logfile% 


@REM list EULA files from local os
echo === list LANGPACKS flag from local os === >> %Eula_logfile%
dir /s /b %UPDriveLetter%\system.sav\FLAGS\LANGPACKS >> %Eula_logfile% 
echo === list LANGPACKS flag from local os === >> %Eula_logfile%

call doit.cmd 1025 17 AR Arabic
call doit.cmd 1026 26 BG Bulgarian
call doit.cmd 1029 22 CS Czech
call doit.cmd 1030 08 DK Danish
call doit.cmd 1031 04 GR German
call doit.cmd 1032 15 GK Greek
call doit.cmd 1035 35 FI Finnish
call doit.cmd 1037 BB IL Hebrew
call doit.cmd 1038 21 HU Hungarian
call doit.cmd 1040 06 IT Italian
call doit.cmd 1041 29 JP Japanese
call doit.cmd 1042 AD KR Korean
call doit.cmd 1043 33 NL Dutch
call doit.cmd 1044 09 NO Norwegian
call doit.cmd 1045 24 PL Polish
call doit.cmd 1046 20 BR Portuguese-Brazil
call doit.cmd 1048 27 RO Romanian
call doit.cmd 1049 25 RU Russian
call doit.cmd 1050 BC HR Croatian
call doit.cmd 1051 23 SK Slovak
call doit.cmd 1053 10 SE Swedish
call doit.cmd 1054 28 TH Thai
call doit.cmd 1055 14 TR Turkish
call doit.cmd 1058 BD UR Ukrainian
call doit.cmd 1060 BA SL Slovenian
call doit.cmd 1061 E4 EI Estonian
call doit.cmd 1062 E1 LV Latvian
call doit.cmd 1063 E2 LT Lithuanian
call doit.cmd 2052 AA CH S-Chinese-PRC
call doit.cmd 2070 13 PT Portuguese-Portugal
call doit.cmd 1057 BW ID Indonesian
call doit.cmd 1087 DF KK Kazakh
REM call doit.cmd 1066 EP ?? Vietnamese
REM call doit.cmd 5146 FJ ?? Bosnian (Bosnia/Herzegovina) 

if %osver% geq 10.0 call doit.cmd 9242 E3 SR Serbian-Latin
if %osver% geq 8.1  call doit.cmd 9242 E3 SR Serbian-Latin
if %osver% geq 7.0  call doit.cmd 2074 E3 SR Serbian-Latin

rem Use -AB for both Taiwan and Hong Kong
call doit.cmd 1028 AB TW T-Chinese-Taiwan
call doit.cmd 3076 AB TZ T-Chinese-HongKong

rem Basque, Catalan, and Galician use Spanish
call doit.cmd 1027 E5 SP Catalan-Spain
call doit.cmd 1069 E5 SP Basque-Spain
call doit.cmd 1110 E5 SP Galician-Spain

rem If there are no flag files, use 00 for English/1033, use 05 for French/1036, and E5 for Spanish/3082 
call doit.cmd 1033 00 US English-UnitedStates
call doit.cmd 1036 05 FR French-France
call doit.cmd 3082 E5 SP Spanish-Spain

rem for APJ, use 00 for English/1033, use 05 for French/1036, and E5 for Spanish/3082 
if exist C:\SYSTEM.SAV\FLAGS\REGION-AP.FLG (
  call doit.cmd 1033 00 US English-AsiaPacific
  call doit.cmd 1036 05 FR French-France
  call doit.cmd 3082 E5 SP Spanish-Spain
)

rem for EMEA, use 00 for English/1033, use 05 for French/1036, and E5 for Spanish/3082 
rem the documentation team has obsoleted the 03 EULA file
if exist C:\SYSTEM.SAV\FLAGS\REGION-EMEA.FLG (
  call doit.cmd 1033 00 US English-UnitedStates
  call doit.cmd 1036 05 FR French-France
  call doit.cmd 3082 E5 SP Spanish-Spain
)

rem for Latin America, use 00 for English/1033, use 12 for French/1036, and E5 for Spanish/3082 
if exist C:\SYSTEM.SAV\FLAGS\REGION-LA.FLG (
  call doit.cmd 1033 00 US English-US
  REM For Win 7/Win8.1
  call doit.cmd 1036 12 FR French-Canada
  REM For Win 10
  call doit.cmd 3084 12 FC French-Canada
  REM For Win 7/Win8.1
  call doit.cmd 3082 E5 SP Spanish-LatinAmerica
  REM For Win 10
  call doit.cmd 2058 E5 LA Spanish-LatinAmerica
)

rem for North America, use 00 for English/1033, use 12 for French/1036, and E5 for Spanish/3082 
if exist C:\SYSTEM.SAV\FLAGS\REGION-NA.FLG (
  call doit.cmd 1033 00 US English-UnitedStates
  ::FOr Win 7/ Win8.1
  call doit.cmd 1036 12 FR French-Canada
  ::For Win 10
  call doit.cmd 3084 12 FC French-Canada
  ::For Win 7/Win8.1
  call doit.cmd 3082 E5 SP Spanish-LatinAmerica
  ::For Win 10
  call doit.cmd 2058 E5 LA Spanish-LatinAmerica
)



@REM list EULA files from local os

echo === list EULA files from local os === >> "%Eula_logfile%"
dir %EULA_DIR% /S /A >> "%Eula_logfile%"
echo === list EULA files from local os === >> "%Eula_logfile%"

echo. >> "%Eula_logfile%"
echo. >> "%Eula_logfile%"
echo ^<^< %~f0 >> "%Eula_logfile%"
echo ^<^< %date% %time% >> "%Eula_logfile%"
echo. >> "%Eula_logfile%"

@REM rmdir /s /q src

exit /b 0


MS LCID	HP Code	HP Dash	Microsoft Description

1025	AR	17	Arabic (Saudi Arabia)
1026	BG	26	Bulgarian (Bulgaria)
1028	TW	AB	Chinese (Taiwan)
1029	CS	22	Czech (Czech Republic)
1030	DK	08	Danish (Denmark)
1031	GR	04	German (Germany)
1032	GK	15	Greek (Greece)
1033	US	00	English (United States)
1035	FI	35	Finnish (Finland)
1036	FR	05	French (France)
3084  FC 	12	French	(Canada)
1037	IL	BB	Hebrew (Israel)
1038	HU	21	Hungarian (Hungary)
1040	IT	06	Italian (Italy)
1041	JP	29	Japanese (Japan)
1042	KR	AD	Korean (Korea)
1043	NL	33	Dutch (Netherlands)
1044	NO	09	Norwegian, Bokm�l (Norway)
1045	PL	24	Polish (Poland)
1046	PT	13	Portuguese (Brazil)
1048	RO	27	Romanian (Romania)
1049	RU	25	Russian (Russia)
1050	HR	BC	Croatian (Croatia)
1051	SK	23	Slovak (Slovakia)
1053	SE	10	Swedish (Sweden)
1054	TH	28	Thai (Thailand)
1055	TR	14	Turkish (Turkey)
1058	UR	BD	Ukrainian (Ukraine)
1060	SL	BA	Slovenian (Slovenia)
1061	EI	E4	Estonian (Estonia)
1062	LV	E1	Latvian (Latvia)
1063	LT	E2	Lithuanian (Lithuania)
2052	CH	AA	Chinese (PRC)
2070	BR	20	Portuguese (Portugal)
2074	SR	E3	Serbian (Latin, Serbia)		=> Win7, Win8
3076	TZ	AC	Chinese (Hong Kong S.A.R.)
3082	SP	07	Spanish (Spain)
2058 	LA	E5  Spanish (LatinAmerica)		=>Win10, Win8.1, Win10
9242	SR	E3	Serbian (Latin, Serbia)		=> Win8.1

1025	AR	17	Arabic (Saudi Arabia)
1026	BG	26	Bulgarian (Bulgaria)
3076	TZ	AC	Chinese (Hong Kong S.A.R.)
2052	CH	AA	Chinese (PRC)
1028	TW	AB	Chinese (Taiwan)
1050	HR	BC	Croatian (Croatia)
1029	CS	22	Czech (Czech Republic)
1030	DK	8	Danish (Denmark)
1043	NL	33	Dutch (Netherlands)
1033	US	0	English (United States)
1061	EI	E4	Estonian (Estonia)
1035	FI	35	Finnish (Finland)
1036	FR	5	French (France)
1031	GR	4	German (Germany)
1032	GK	15	Greek (Greece)
1037	IL	BB	Hebrew (Israel)
1038	HU	21	Hungarian (Hungary)
1040	IT	6	Italian (Italy)
1041	JP	29	Japanese (Japan)
1042	KR	AD	Korean (Korea)
1062	LV	E1	Latvian (Latvia)
1063	LT	E2	Lithuanian (Lithuania)
1044	NO	9	Norwegian, Bokm�l (Norway)
1045	PL	24	Polish (Poland)
1046	PT	13	Portuguese (Brazil)
2070	BR	20	Portuguese (Portugal)
1048	RO	27	Romanian (Romania)
1049	RU	25	Russian (Russia)
2074	SR	E3	Serbian (Latin, Serbia)		=> Win7, Win8
9242	SR	E3	Serbian (Latin, Serbia)		=> Win8.1
1051	SK	23	Slovak (Slovakia)
1060	SL	BA	Slovenian (Slovenia)
3082	SP	7	Spanish (Spain)
1053	SE	10	Swedish (Sweden)
1054	TH	28	Thai (Thailand)
1055	TR	14	Turkish (Turkey)
1058	UR	BD	Ukrainian (Ukraine)
