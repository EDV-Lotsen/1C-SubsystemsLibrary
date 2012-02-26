

&AtClient
Procedure WriteAndClose(Command)
	StructuresArray = New Array;
	
	// Work with files
	Item = New Structure;
	Item.Insert("Object", 	"FilesOpenSettings");
	Item.Insert("Options", 	"OnDoubleClickAction");
	Item.Insert("Value", 	OnDoubleClickAction);
	StructuresArray.Add(Item);
	
	Item = New Structure;
	Item.Insert("Object", 	"FilesOpenSettings");
	Item.Insert("Options", 	"AskEditModeOnFileOpening");
	Item.Insert("Value", 	AskEditModeOnFileOpening);
	StructuresArray.Add(Item);
	
	Item = New Structure;
	Item.Insert("Object", 	"ProgrammeSettings");
	Item.Insert("Options", 	"ShowTipsOnEditFiles");
	Item.Insert("Value", 	ShowTipsOnEditFiles);
	StructuresArray.Add(Item);
	
	Item = New Structure;
	Item.Insert("Object", 	"ProgrammeSettings");
	Item.Insert("Options", 	"ShowLockedFilesOnExit");
	Item.Insert("Value", 	ShowLockedFilesOnExit);
	StructuresArray.Add(Item);
	
	Item = New Structure;
	Item.Insert("Object", 	"FilesComparisonSettings");
	Item.Insert("Options", 	"FileVersionsCompareMethod");
	Item.Insert("Value", 	FileVersionsCompareMethod);
	StructuresArray.Add(Item);
	
	Item = New Structure;
	Item.Insert("Object", 	"ProgrammeSettings");
	Item.Insert("Options", 	"ShowColumnSize");
	Item.Insert("Value", 	ShowColumnSize);
	StructuresArray.Add(Item);
	
	CommonUse.CommonSettingsStorageSaveArray(StructuresArray);
	Close();
	
	RefreshReusableValues();
EndProcedure

&AtClient
Procedure WorkingDirectorySetting(Command)
	OpenFormModal("CommonForm.LocalFileCacheSettings");
EndProcedure

&AtClient
Procedure InstallFileOperationsExtensionAtClient(Command)
	InstallFileSystemExtension();
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	// work with users
	AuthorizedUser = Users.AuthorizedUser();
	
	// Work with files
	AskEditModeOnFileOpening = 
		CommonSettingsStorage.Load("FilesOpenSettings", "AskEditModeOnFileOpening");
	If AskEditModeOnFileOpening = Undefined Then
		AskEditModeOnFileOpening = True;
		CommonSettingsStorage.Save("FilesOpenSettings", "AskEditModeOnFileOpening", AskEditModeOnFileOpening);
	EndIf;
	
	OnDoubleClickAction = CommonSettingsStorage.Load("FilesOpenSettings", "OnDoubleClickAction");
	If OnDoubleClickAction = Undefined Then
		OnDoubleClickAction = Enums.FileDoubleClickActions.OpenFile;
		CommonSettingsStorage.Save("FilesOpenSettings", "OnDoubleClickAction", OnDoubleClickAction);
	EndIf;
	
	FileVersionsCompareMethod = CommonSettingsStorage.Load("FilesComparisonSettings", "FileVersionsCompareMethod");
	ShowTipsOnEditFiles = CommonUse.CommonSettingsStorageLoad("ProgrammeSettings", "ShowTipsOnEditFiles");
	
	ShowLockedFilesOnExit = CommonUse.CommonSettingsStorageLoad("ProgrammeSettings", "ShowLockedFilesOnExit");
	If ShowLockedFilesOnExit = Undefined Then 
		ShowLockedFilesOnExit = True;
		CommonSettingsStorage.Save("ProgrammeSettings", "ShowLockedFilesOnExit", ShowLockedFilesOnExit);
	EndIf;	
	
	ShowColumnSize = CommonSettingsStorage.Load("ProgrammeSettings", "ShowColumnSize");
	If ShowColumnSize = Undefined Then
		ShowColumnSize = False;
		CommonSettingsStorage.Save("ProgrammeSettings", "ShowColumnSize", ShowColumnSize);
	EndIf;
	
	// work with documents
	InternalDocumentKind 	= CommonSettingsStorage.Load("SettingsOfWorkWithDocuments", "InternalDocumentKind");
	IncomingDocumentKind	= CommonSettingsStorage.Load("SettingsOfWorkWithDocuments", "IncomingDocumentKind");
	OutgoingDocumentKind 	= CommonSettingsStorage.Load("SettingsOfWorkWithDocuments", "OutgoingDocumentKind");
	
	SendMethod  	= CommonSettingsStorage.Load("SettingsOfWorkWithDocuments", "SendMethod");
	ObtainingMethod = CommonSettingsStorage.Load("SettingsOfWorkWithDocuments", "ObtainingMethod");
	
	ShowWarningOnRegistration = CommonSettingsStorage.Load("SettingsOfWorkWithDocuments", "ShowWarningOnRegistration");
	If ShowWarningOnRegistration = Undefined Then 
		ShowWarningOnRegistration = True;
		CommonSettingsStorage.Save("SettingsOfWorkWithDocuments", "ShowWarningOnRegistration", ShowWarningOnRegistration);
	EndIf;	
	
	If Parameters.Property("ThisIsWebClient") Then 
		If Not Parameters.ThisIsWebClient Then
			Items.InstallFileOperationsExtensionAtClient.Visible = False;
		EndIf;		
	EndIf;
EndProcedure

&AtClient
Procedure ScanningSetup(Command)
	ComponentInstalled = WorkWithScannerClient.InitializeComponent();
	
	SystemInfo 	= New SystemInfo();
	ClientID 	= SystemInfo.ClientID;
	
	FormParameters = New Structure("ComponentInstalled, ClientID", 
		ComponentInstalled, ClientID);
	OpenFormModal("Catalog.Files.Form.ScanningSetup", FormParameters);
EndProcedure

&AtClient
Procedure WorkingDirectorySettingForPrinting(Command)
	OpenForm("InformationRegister.PrintedFormTemplates.Form.PrintFilesFolderSettings");
EndProcedure

&AtClient
Procedure UserInfo(Command)
	
	OpenValue(AuthorizedUser);
	
EndProcedure

&AtClient
Procedure SetActionOnPrintFormTemplateSelect(Command)
	OpenForm("InformationRegister.PrintedFormTemplates.Form.ChoiceOfTemplateOpenMode");
EndProcedure

&AtClient
Procedure PersonalSettingsProxyServer(Command)
	
	OpenForm("CommonForm.ProxyServerParameters",
					New Structure("SettingProxyAtClient", True));
	
EndProcedure
