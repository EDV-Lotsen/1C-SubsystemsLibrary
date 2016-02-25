
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	Manager = ExchangePlans[Parameters.Node.Metadata().Name];
	
	If Parameters.Node = Manager.ThisNode() Then
		Raise
			NStr("en = 'Initial image cannot be created for this node.'");
	Else
		InfobaseType = 0; // File infobase
		DBMSType = "";
		Node = Parameters.Node;
		CanCreateFileModeInfobase = True;
		SystemInfo = New SystemInfo;
		If SystemInfo.PlatformType = PlatformType.Linux_x86_64 Then
			CanCreateFileModeInfobase = False;
		EndIf;
		
		LocaleCodes = GetAvailableLocaleCodes();
		FileModeInfobaseLanguage = Items.Find("FileModeInfobaseLanguage");
		ClientServerModeInfobaseLanguage = Items.Find("ClientServerModeInfobaseLanguage");
		
		For Each Code In LocaleCodes Do
			Presentation = LocaleCodePresentation(Code);
			FileModeInfobaseLanguage.ChoiceList.Add(Code, Presentation);
			ClientServerModeInfobaseLanguage.ChoiceList.Add(Code, Presentation);
		EndDo;
		
		Language = InfobaseLocaleCode();
		
	EndIf;
	
	HasFilesInVolumes = False;
	
	If FileFunctions.HasFileStorageVolumes() Then
		HasFilesInVolumes = FileFunctionsInternal.HasFilesInVolumes();
	EndIf;
	
	If HasFilesInVolumes Then
		ServerPlatformType = CommonUseCached.ServerPlatformType();
		
		If ServerPlatformType = PlatformType.Windows_x86
		 Or ServerPlatformType = PlatformType.Windows_x86_64 Then
			
			Items.FullFileInfobaseName.AutoMarkIncomplete = True;
			Items.PathToVolumeFilesArchive.AutoMarkIncomplete = True;
		Else
			Items.LinuxFullFileInfobaseName.AutoMarkIncomplete = True;
			Items.LinuxPathToVolumeFilesArchive.AutoMarkIncomplete = True;
		EndIf;
	Else
		Items.GroupPathToVolumeFilesArchive.Visible = False;
	EndIf;
	
	If Not StandardSubsystemsServerCall.ClientParameters().FileInfobase Then
		Items.PathToVolumeFilesArchive.InputHint = NStr("en = '\\server name\resource\files.zip'");
		Items.PathToVolumeFilesArchive.ChoiceButton = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure InfobaseVariantOnChange(Item)
	
	// Switch the parameters page.
	Pages = Items.Find("Pages");
	Pages.CurrentPage = Pages.ChildItems[InfobaseType];
	
	If ThisObject.InfobaseType = 0 Then
		Items.PathToVolumeFilesArchive.InputHint = "";
		Items.PathToVolumeFilesArchive.ChoiceButton = True;
	Else
		Items.PathToVolumeFilesArchive.InputHint = NStr("en = '\\server name\resource\files.zip'");
		Items.PathToVolumeFilesArchive.ChoiceButton = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure PathToVolumeFilesArchiveStartChoice(Item, ChoiceData, StandardProcessing)
	
	SaveFileHandler(
		"WindowsPathToVolumeFilesArchive",
		StandardProcessing,
		"files.zip",
		"ZIP archives(*.zip)|*.zip");
	
EndProcedure

&AtClient
Procedure FullFileInfobaseNameStartChoice(Item, ChoiceData, StandardProcessing)
	
	SaveFileHandler(
		"WindowsFullFileInfobaseName",
		StandardProcessing,
		"1Cv8.1CD",
		"Any file(*.*)|*.*");
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure CreateInitialImage(Command)
	
	ClearMessages();
	
	Status(
		NStr("en = 'Data synchronization'"),
		,
		NStr("en = 'Initial image is creating...'"),
		PictureLib.CreateInitialImage);
	
	If InfobaseType = 0 Then
		
		If Not CanCreateFileModeInfobase Then
			Raise
				NStr("en = 'File infobase initial image
				           |cannot be created on this platform.'");
		EndIf;
		
		If Not CreateFileInitialImageAtServer() Then
			Status();
			Return;
		EndIf;
		
	Else
		If Not CreateServerInitialImageAtServer() Then
			Status();
			Return;
		EndIf;
		
	EndIf;
	
	Handler = New NotifyDescription("CreateInitialImageEnd", ThisObject);
	ShowMessageBox(Handler, NStr("en = 'Initial image is created.'"));
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure CreateInitialImageEnd(ExecutionParameters) Export
	Close();
EndProcedure

&AtClient
Procedure SaveFileHandler(PropertyName,
                          StandardProcessing,
                          FileName,
                          Filter = "")
	
	StandardProcessing = False;
	
	If Not AttachFileSystemExtension() Then
		FileFunctionsInternalClient.ShowFileSystemExtensionRequiredMessageBox(Undefined);
		Return;
	EndIf;
	
	Dialog = New FileDialog(FileDialogMode.Save);
	
	Dialog.Title            = NStr("en = 'Select file to download'");
	Dialog.Multiselect      = False;
	Dialog.Preview          = False;
	Dialog.Filter           = Filter;
	Dialog.FullFileName     =
		?(ThisObject[PropertyName] = "", FileName, ThisObject[PropertyName]);
	
	If Dialog.Choose() Then
		ThisObject[PropertyName] = Dialog.FullFileName;
	EndIf;
	
EndProcedure

&AtServer
Function CreateFileInitialImageAtServer()
	
	Return FileFunctionsInternal.CreateFileInitialImageAtServer(
		Node,
		UUID,
		Language,
		WindowsFullFileInfobaseName,
		LinuxFullFileInfobaseName,
		WindowsPathToVolumeFilesArchive,
		LinuxPathToVolumeFilesArchive);
	
EndFunction

&AtServer
Function CreateServerInitialImageAtServer()
	
	ConnectionString =
		"Srvr="""       + Server + """;"
		+ "Ref="""      + InfobaseName + """;"
		+ "DBMS="""     + DBMSType + """;"
		+ "DBSrvr="""   + DatabaseServer + """;"
		+ "DB="""       + DatabaseName + """;"
		+ "DBUID="""    + DatabaseUser + """;"
		+ "DBPwd="""    + UserPassword + """;"
		+ "SQLYOffs=""" + Format(DateOffset, "NG=") + """;"
		+ "Locale="""   + Language + """;"
		+ "SchJobDn=""" + ?(SetScheduledJobLock, "Y", "N") + """;";
	
	Return FileFunctionsInternal.CreateServerInitialImageAtServer(
		Node, ConnectionString, WindowsPathToVolumeFilesArchive, LinuxPathToVolumeFilesArchive);
	
EndFunction

#EndRegion
