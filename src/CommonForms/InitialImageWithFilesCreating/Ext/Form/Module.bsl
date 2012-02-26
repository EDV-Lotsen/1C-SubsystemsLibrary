

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)

	Manager = ExchangePlans[Parameters.Node.Metadata().Name];
	If Parameters.Node = Manager.ThisNode() Then
		
		Raise NStr("en = 'Initial image creating for the node cannot be done'");
		
	Else
		
		BaseKind 			= 0;	// file base
		DBMSType 			= "";
		Node 				= Parameters.Node;
		CanCreateFilebase 	= True;
		SystemInfo 			= New SystemInfo;
		If SystemInfo.PlatformType = PlatformType.Linux_x86_64 Then
			CanCreateFilebase = False;
		EndIf;
		
		LocalizationCodes 		= GetAvailableLocaleCodes();
		LanguageOfFileBase	 	= Items.Find("LanguageOfFileBase");
		LanguageOfServerBase 	= Items.Find("LanguageOfServerBase");
		For Each Code In LocalizationCodes Do
			Presentation = LocaleCodePresentation(Code);
			LanguageOfFileBase.ChoiceList.Add(Code, Presentation);
			LanguageOfServerBase.ChoiceList.Add(Code, Presentation);
		EndDo;
		Language = InfoBaseLocaleCode();
		
	EndIf;
	
	ServerPlatformType = FileOperationsSecondUse.ServerPlatformType();
	If ServerPlatformType = PlatformType.Windows_x86 OR ServerPlatformType = PlatformType.Windows_x86_64 Then
		Items.FileBaseFullName.AutoMarkIncomplete = True;
		Items.PathToArchiveWithVolumeFiles.AutoMarkIncomplete = True;
	Else
		Items.LinuxFileBaseFullName.AutoMarkIncomplete = True;
		Items.PathToArchiveWithLinuxVolumeFiles.AutoMarkIncomplete = True;
	EndIf;	
	
EndProcedure

&AtClient
Procedure BaseKindOnChange(Item)
	// turn page of parameters
	Pages = Items.Find("Pages");
	Pages.CurrentPage = Pages.ChildItems[BaseKind];
EndProcedure

&AtClient
Procedure CreateInitialImage(Command)
	ClearMessages();
	
	Status(NStr("en = 'Data exchange'"), ,
						 NStr("en = 'Creating initial image...'"),
						 PictureLib.CreateInitialImage);
	TemporaryRef = Undefined;
	If BaseKind = 0 Then
		
		If CanCreateFilebase = False Then
			
			Raise NStr("en = 'Creation of initial image of file information base is not supported at this platform.'");
			
		EndIf;
		
		If Not FileExchange.CreateFileModeInfobaseInitialImageAtServer(Node, Uuid, Language, WindowsFileBaseFullName, LinuxFileBaseFullName, PathToArchiveWithWindowsVolumesFiles, PathToArchiveWithLinuxVolumeFiles) Then
			Status();
			Return;
		EndIf;	
		
	Else
		ConnectionString = "Srvr=""" 		+ Server 		 + """;" 
		                 + "Ref=""" 		+ BaseName1 	 + """;"
		                 + "DBMS=""" 		+ DBMSType 		 + """;"
		                 + "DBSrvr=""" 		+ DatabaseServer + """;"
						 + "DB=""" 			+ DataBaseName 	 + """;"
						 + "DBUID=""" 		+ DatabaseUser   + """;"
						 + "DBPwd=""" 		+ PasswordOfUser + """;"
						 + "SQLYOffs=""" 	+ ShiftOfDates   + """;"
						 + "Locale=""" 		+ Language 		 + """;";
		If Not FileExchange.CreateClientServerModeInfobaseInitialImageAtServer(Node, ConnectionString, PathToArchiveWithWindowsVolumesFiles, PathToArchiveWithLinuxVolumeFiles) Then
			Status();
			Return;
		EndIf;	
		
	EndIf;

	DoMessageBox(NStr("en = 'Initial image creating completed successful.'"));
EndProcedure

