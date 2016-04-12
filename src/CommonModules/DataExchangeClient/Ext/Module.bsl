 ////////////////////////////////////////////////////////////////////////////////
// Data exchange subsystem
// 
////////////////////////////////////////////////////////////////////////////////
 
#Region Interface
 
// The handler for closing the setup form of multiple exchange plan nodes.
//
// Parameters:
//  Form - managed form where the procedure is called.
// 
Procedure SetupOfNodesFormCloseFormCommand(Form) Export
	
	If Not Form.CheckFilling() Then
		Return;
	EndIf;
	
	Form.Modified = False;
	FillStructureData(Form);
	Form.Close(Form.Context);
	
EndProcedure
 
// The handler for closing the setup form of an exchange plan node.
//
// Parameters:
//  Form - managed form where the procedure is called.
// 
Procedure NodeSettingsFormCloseFormCommand(Form) Export
	
	OnCloseExchangePlanNodeSettingsForm(Form, "NodeFilterStructure");
	
EndProcedure
 
// The handler for closing the default value setup form of an exchange plan node.
//
// Parameters:
//  Form - managed form where the procedure is called.
// 
Procedure DefaultValueSetupFormCloseFormCommand(Form) Export
	
	OnCloseExchangePlanNodeSettingsForm(Form, "NodeDefaultValues");
	
EndProcedure
 
// The handler for closing the setup form of an exchange plan node.
//
// Parameters:
//  Cancel - cancellation flag.
//  Form   - managed form where the procedure is called.
// 
Procedure SetupFormBeforeClose(Cancel, Form) Export
	
	If Form.Modified Then
		
		Cancel = True;
		
		QuestionText = NStr("en = 'Data has been changed. Do you want to close the form without saving your changes?'");
		NotifyDescription = New NotifyDescription("SetupFormBeforeCloseCompletion", ThisObject, Form);
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo,, DialogReturnCode.No);
		
	EndIf;
	
EndProcedure
 
// Opens the data exchange setup wizard form for the specified exchange plan.
//
// Parameters:
//  ExchangePlanName         - String - name of the exchange plan (metadata object), 
//                             for which the wizard will be opened.
//  ExchangeWithServiceSetup - Boolean - flag that shows whether setup is performed for exchange with a SaaS 
//                             application.
// 
Procedure OpenDataExchangeSetupWizard(Val ExchangePlanName, ExchangeWithServiceSetup = False) Export
	
	If Find(ExchangePlanName, "CorrespondentInSaaS") > 0 Then
		
		ExchangePlanName = StrReplace(ExchangePlanName, "CorrespondentInSaaS", "");
		
		ExchangeWithServiceSetup = True;
		
	EndIf;
	
	FormParameters = New Structure("ExchangePlanName", ExchangePlanName);
	
	If ExchangeWithServiceSetup Then
		
		FormParameters.Insert("ExchangeWithServiceSetup");
		
	EndIf;
	
	OpenForm("DataProcessor.DataExchangeCreationWizard.Form.Form", FormParameters, , ExchangePlanName + ExchangeWithServiceSetup, , , , FormWindowOpeningMode.LockOwnerWindow);
EndProcedure
 
// Is called when the user starts choosing an item for the correspondent infobase node setup 
// during setting up the exchange via the external connection.
//
// Parameters:
//  AttributeName                - String - form attribute name.
//  TableName                    - String - metadata object full name.
//  Owner                        - ManagedForm - selection form of correspondent infobase items.
//  StandardProcessing           - Boolean - flag that shows whether the standard processing is used. 
//  ExternalConnectionParameters - Structure - external connection parameters.
//  ChoiceParameters             - Structure - selection parameter structure.
//
Procedure CorrespondentInfobaseItemSelectionHandlerStartChoice(Val AttributeName, Val TableName, Val Owner,
	Val StandardProcessing, Val ExternalConnectionParameters, Val ChoiceParameters=Undefined) Export
	
	IDAttributeName = AttributeName + "_Key";
	
	InitialSelectionValue = Undefined;
	ChoiceFoldersAndItems = Undefined;
	
	OwnerType = TypeOf(Owner);
	If OwnerType = Type("FormTable") Then
		CurrentData = Owner.CurrentData;
		If CurrentData <> Undefined Then
			InitialSelectionValue = CurrentData[IDAttributeName];
		EndIf;
		
	ElsIf OwnerType = Type("ManagedForm") Then
		InitialSelectionValue = Owner[IDAttributeName];
		
	EndIf;
	
	If ChoiceParameters <> Undefined Then
		If ChoiceParameters.Property("ChoiceFoldersAndItems") Then
			ChoiceFoldersAndItems = ChoiceParameters.ChoiceFoldersAndItems;
		EndIf;
	EndIf;
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	FormParameters.Insert("ExternalConnectionParameters",       ExternalConnectionParameters);
	FormParameters.Insert("CorrespondentInfobaseTableFullName", TableName);
	FormParameters.Insert("InitialSelectionValue",              InitialSelectionValue);
	FormParameters.Insert("AttributeName",                      AttributeName);
	FormParameters.Insert("ChoiceFoldersAndItems",              ChoiceFoldersAndItems);
	
	OpenForm("CommonForm.SelectCorrespondentInfobaseItems", FormParameters, Owner);
	
EndProcedure
 
// Is called when the user is picking items for the correspondent infobase node setup during setting up the exchange via the external connection.
//
// Parameters:
//  AttributeName                - String - form attribute name.
//  TableName                    - String - metadata object full name.
//  Owner                        - ManagedForm - selection form of correspondent infobase items. 
//  ExternalConnectionParameters - Structure - external connection parameters.
//  ChoiceParameters             - Structure - selection parameter structure.
//
Procedure CorrespondentInfobaseItemSelectionHandlerPick(Val AttributeName, Val TableName, Val Owner,
	Val ExternalConnectionParameters, Val ChoiceParameters=Undefined) Export
	
	IDAttributeName = AttributeName + "_Key";
	
	InitialSelectionValue = Undefined;
	ChoiceFoldersAndItems = Undefined;
	
	CurrentData = Owner.CurrentData;
	If CurrentData <> Undefined Then
		InitialSelectionValue = CurrentData[IDAttributeName];
	EndIf;
	
	StandardProcessing = False;
	
	If ChoiceParameters <> Undefined Then
		If ChoiceParameters.Property("ChoiceFoldersAndItems") Then
			ChoiceFoldersAndItems = ChoiceParameters.ChoiceFoldersAndItems;
		EndIf;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("ExternalConnectionParameters",       ExternalConnectionParameters);
	FormParameters.Insert("CorrespondentInfobaseTableFullName", TableName);
	FormParameters.Insert("InitialSelectionValue",              InitialSelectionValue);
	FormParameters.Insert("CloseOnChoice",                      False);
	FormParameters.Insert("AttributeName",                      AttributeName);
	FormParameters.Insert("ChoiceFoldersAndItems",              ChoiceFoldersAndItems);
	
	OpenForm("CommonForm.SelectCorrespondentInfobaseItems", FormParameters, Owner);
EndProcedure
 
// Is called when the user has chosen the item for the correspondent infobase node setup during setting up the exchange via the external connection.
//
// Parameters:
//  Item               - ManagedForm, FormTable - item to process selection.
//  SelectedValue      - see the SelectedValue parameter details of the ChoiceProcessing event.
//  FormDataCollection - FormDataCollection - this parameter is used for picking items from the list.
//
Procedure CorrespondentInfobaseItemSelectionHandlerChoiceProcessing(Val Item, Val SelectedValue, Val FormDataCollection=Undefined) Export
	
	If TypeOf(SelectedValue) <> Type("Structure") Then
		Return;
	EndIf;
	
	IDAttributeName = SelectedValue.AttributeName + "_Key";
	PresentationAttributeName  = SelectedValue.AttributeName;
	
	ItemType = TypeOf(Item);
	If ItemType = Type("FormTable") Then
		
		If SelectedValue.PickMode Then
			If FormDataCollection <> Undefined Then
				Filter = New Structure(IDAttributeName, SelectedValue.ID);
				ExistingRows = FormDataCollection.FindRows(Filter);
				If ExistingRows.Count() > 0 Then
					Return;
				EndIf;
			EndIf;
			
			Item.AddRow();
		EndIf;
		
		CurrentData = Item.CurrentData;
		If CurrentData<>Undefined Then
			CurrentData[IDAttributeName] = SelectedValue.ID;
			CurrentData[PresentationAttributeName]  = SelectedValue.Presentation;
		EndIf;
		
	ElsIf ItemType = Type("ManagedForm") Then
		Item[IDAttributeName] = SelectedValue.ID;
		Item[PresentationAttributeName]  = SelectedValue.Presentation;
		
	EndIf;
	
EndProcedure
 
// Checks whether the Use flag is set to True in all table rows.
//
// Table - ValueTable - table to be checked.
//
Function AllRowsMarkedInTable(Table) Export
	
	For Each Item In Table Do
		
		If Item.Use = False Then
			
			Return False;
			
		EndIf;
		
	EndDo;
	
	Return True;
EndFunction
 
#EndRegion
 
#Region InternalProceduresAndFunctions
 
////////////////////////////////////////////////////////////////////////////////
// Export internal functions for retrieving properties.
 
// Returns the maximum number of fields to be displayed
// in the infobase object mapping wizard.
//
// Returns:
//     Number - maximum number of fields for mapping.
//
Function MaxObjectMappingFieldCount() Export
	
	Return 5;
	
EndFunction
 
// Returns a data import state structure.
//
Function DataImportStatusPages() Export
	
	Structure = New Structure;
	Structure.Insert("Undefined", "ImportStatusUndefined");
	Structure.Insert("Error",     "ImportStatusError");
	Structure.Insert("Success",   "ImportStateSuccess");
	Structure.Insert("Perform",   "ImportStatusExecution");
	
	Structure.Insert("Warning_ExchangeMessageReceivedPreviously", "ImportStatusWarning");
	Structure.Insert("CompletedWithWarnings",                     "ImportStatusWarning");
	Structure.Insert("Error_MessageTransport",                    "ImportStatusError");
	
	Return Structure;
EndFunction
 
// Returns a data export state structure.
//
Function DataExportStatusPages() Export
	
	Structure = New Structure;
	Structure.Insert("Undefined", "ExportStatusUndefined");
	Structure.Insert("Error",     "ExportStatusError");
	Structure.Insert("Success",   "ExportStatusSuccess");
	Structure.Insert("Perform",   "ExportStatusExecution");
	
	Structure.Insert("Warning_ExchangeMessageReceivedPreviously", "ExportStatusWarning");
	Structure.Insert("CompletedWithWarnings",                     "ExportStatusWarning");
	Structure.Insert("Error_MessageTransport",                     "ExportStatusError");
	
	Return Structure;
EndFunction
 
// Returns a structure with data import field hyperlink name.
//
Function DataImportHyperlinkHeaders() Export
	
	Structure = New Structure;
	Structure.Insert("Undefined",               NStr("en = 'Data was not received.'"));
	Structure.Insert("Error",                   NStr("en = 'Cannot receive the data.'"));
	Structure.Insert("CompletedWithWarnings",   NStr("en = 'Data has been received with warnings.'"));
	Structure.Insert("Success",                 NStr("en = 'Data has been received successfully.'"));
	Structure.Insert("Perform",                 NStr("en = 'Sending data...'"));
	
	Structure.Insert("Warning_ExchangeMessageReceivedPreviously", NStr("en = 'No data to receive.'"));
	Structure.Insert("Error_MessageTransport",                    NStr("en = 'Cannot receive the data.'"));
	
	Return Structure;
EndFunction
 
// Returns a structure with data export field hyperlink name.
//
Function DataExportHyperlinkHeaders() Export
	
	Structure = New Structure;
	Structure.Insert("Undefined", NStr("en = 'Data was not sent.'"));
	Structure.Insert("Error",     NStr("en = 'Errors occurred during the data sending.'"));
	Structure.Insert("Success",   NStr("en = 'Data has been sent successfully.'"));
	Structure.Insert("Perform",   NStr("en = 'Sending data...'"));
	
	Structure.Insert("Warning_ExchangeMessageReceivedPreviously", NStr("en = 'Data has been sent with warnings.'"));
	Structure.Insert("CompletedWithWarnings",                     NStr("en = 'Data has been sent with warnings.'"));
	Structure.Insert("Error_MessageTransport",                    NStr("en = 'Errors occurred when sending the data.'"));
	
	Return Structure;
EndFunction
 
// Opens a form or a hyperlink that contains synchronization details.
//
Procedure OpenDetailedSynchronizationDetails(LinkToDetails) Export
	
	If Upper(Left(LinkToDetails, 4)) = "HTTP" Then
		
		GotoURL(LinkToDetails);
		
	Else
		
		OpenForm(LinkToDetails);
		
	EndIf;
	
EndProcedure
 
// Opens a form for entering proxy server parameters.
//
Procedure OpenProxyServerParameterForm() Export
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		GetFilesFromInternetClientModule = CommonUseClient.CommonModule("GetFilesFromInternetClient");
		GetFilesFromInternetClientModule.OpenProxyServerParameterForm();
	EndIf;
	
EndProcedure
 
////////////////////////////////////////////////////////////////////////////////
// SL event handlers.
 
// The handler for starting the client application session.
// If the subordinate distributed infobase is started and exchange message must be reimported,
// the user is prompted to select further action: reimport the message or skip it.
// 
Procedure BeforeStart(Parameters) Export
	
	ClientParameters = StandardSubsystemsClientCached.ClientParametersOnStart();
	
	If Not ClientParameters.Property("RetryDataExchangeMessageImportBeforeStart") Then
		Return;
	EndIf;
	
	Parameters.InteractiveHandler = New NotifyDescription(
		"RetryDataExchangeMessageImportBeforeStartInteractiveHandler", ThisObject);
	
EndProcedure
 
// The handler for starting the client application session.
// If the subordinate distributed infobase is started for the first time, 
// the data exchange creation wizard form is opened.
Procedure OnStart(Parameters) Export
	
	ClientParameters = StandardSubsystemsClientCached.ClientParametersOnStart();
	If Not ClientParameters.CanUseSeparatedData Or ClientParameters.DataSeparationEnabled Then
		Return;
	EndIf;
	
	If ClientParameters.Property("OpenDataExchangeCreationWizardForSubordinateNodeSetup") Then
		
		For Each Window In GetWindows() Do
			If Window.IsMain Then
				Window.Activate();
				Break;
			EndIf;
		EndDo;
		
		FormParameters = New Structure("ExchangePlanName, IsContinuedInDIBSubordinateNodeSetup", ClientParameters.DIBExchangePlanName, True);
		OpenForm("DataProcessor.DataExchangeCreationWizard.Form.Form", FormParameters, , , , , , FormWindowOpeningMode.LockWholeInterface);
	EndIf;
	
EndProcedure
 
Procedure AfterStart() Export
	
	ClientParameters = StandardSubsystemsClientCached.ClientParametersOnStart();
	If Not ClientParameters.CanUseSeparatedData Or ClientParameters.DataSeparationEnabled Then
		Return;
	EndIf;
		
	If Not ClientParameters.Property("OpenDataExchangeCreationWizardForSubordinateNodeSetup")
		And ClientParameters.Property("CheckSubordinateNodeConfigurationUpdateRequired") Then
		
		AttachIdleHandler("CheckSubordinateNodeConfigurationUpdateRequiredOnStart", 1, True);
		
	EndIf;
	
EndProcedure
 
////////////////////////////////////////////////////////////////////////////////
// Export internal procedures and functions.
 
// For internal use only.
//
Procedure RetryDataExchangeMessageImportBeforeStartInteractiveHandler(Parameters, NotDefined) Export
	
	Form = OpenForm(
		"InformationRegister.ExchangeTransportSettings.Form.DataResynchronizationBeforeStart", , , , , ,
		New NotifyDescription(
			"AfterCloseFormDataResynchronizationBeforeStart", ThisObject, Parameters));
	
	If Form = Undefined Then
		AfterCloseFormDataResynchronizationBeforeStart("Continue", Parameters);
	EndIf;
	
EndProcedure
 
// For internal use only. Continues the execution
// of the RetryDataExchangeMessageImportBeforeStartInteractiveHandler procedure.
//
Procedure AfterCloseFormDataResynchronizationBeforeStart(Result, Parameters) Export
	
	If Result <> "Continue" Then
		Parameters.Cancel = True;
	Else
		Parameters.RetrievedClientParameters.Insert(
			"RetryDataExchangeMessageImportBeforeStart");
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure
 
// For internal use only. Continues the execution of the SetupFormBeforeClose procedure.
//
Procedure SetupFormBeforeCloseCompletion(Answer, Form) Export
	
	If Answer <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	Form.Modified = False;
	Form.Close();
	
	// Clearing cached values to reset COM connections
	RefreshReusableValues();
EndProcedure
 
// Opens a file using the associated operating system application.
//
// Parameters:
//     Object             - Arbitrary - an object. The file name is retrieved from this object by property name. 
//     PropertyName       - String - name of the object property that stores the file name. 
//     StandardProcessing - Boolean - standard processing flag, it is set to False.
//
Procedure FileOrDirectoryOpenHandler(Object, PropertyName, StandardProcessing = False) Export
	StandardProcessing = False;
	
	FullFileName = Object[PropertyName];
	If IsBlankString(FullFileName) Then
		Return;
	EndIf;
	
	RunApp(FullFileName);
EndProcedure
 
// Opens a directory selection dialog and prompts the user to confirm the installation of the file system extension.
//
// Parameters:
//     Object                 - Arbitrary - object whose property will store the file name.
//     PropertyName           - String - name of the property that will store the file name. 
//                              Source of the initial value.
//     StandardProcessing     - Boolean - standard processing flag. It is set to False.
//     DialogParameters       - Structure - optional additional parameters of the directory selection dialog. 
//     CompletionNotification - NotifyDescription - optional notification that is called with the following parameters:
//                                 Result               - String - selected value (array of strings if multiple selection is used)
//                                 AdditionalParameters - Undefined.
//
Procedure FileDirectoryChoiceHandler(Object, Val PropertyName, StandardProcessing = False, Val DialogParameters = Undefined, CompletionNotification = Undefined) Export
	StandardProcessing = False;
	
	DialogDefaultOptions = New Structure;
	DialogDefaultOptions.Insert("Title", NStr("en = 'Select directory'") );
	
	SetDefaultStructureValues(DialogParameters, DialogDefaultOptions);
	
	WarningText = NStr("en = 'This action requires the file system extension for 1C:Enterprise web client.'");
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Object",                 Object);
	AdditionalParameters.Insert("PropertyName",           PropertyName);
	AdditionalParameters.Insert("DialogParameters",       DialogParameters);
	AdditionalParameters.Insert("CompletionNotification", CompletionNotification);
	
	Notification = New NotifyDescription("FileDirectorySelectionHandlerCompletion", ThisObject, AdditionalParameters);
	CommonUseClient.ShowFileSystemExtensionInstallationQuestion(Notification, WarningText, False);
EndProcedure
 
// Nonmodal completion handler for the directory selection dialog.
//
Procedure FileDirectorySelectionHandlerCompletion(Val Result, Val AdditionalParameters) Export
	If Result <> True Then
		Return;
	EndIf;
	
	PropertyName = AdditionalParameters.PropertyName;
	Object       = AdditionalParameters.Object;
	
	Dialog = New FileDialog(FileDialogMode.ChooseDirectory);
	FillPropertyValues(Dialog, AdditionalParameters.DialogParameters);
	
	Dialog.Directory = Object[PropertyName];
	If Dialog.Choose() Then
		Object[PropertyName] = Dialog.Directory;
		
		If AdditionalParameters.CompletionNotification <> Undefined Then
			Result = ?(Dialog.Multiselect, Dialog.SelectedFiles, Dialog.Directory);
			ExecuteNotifyProcessing(AdditionalParameters.CompletionNotification, Result);
		EndIf;
	EndIf;
	
EndProcedure
 
// Opens a file selection dialog and prompts the user to confirm the installation of the file system extension.
//
// Parameters:
//     Object                  - Arbitrary - object whose property will store the file name.
//     PropertyName            - String - name of the property that will store the file name. 
//                               Source of the initial value.
//     StandardProcessing      - Boolean - standard processing flag. It is set to False.
//     DialogParameters        - Structure - optional additional parameters of the file selection dialog.
//     CompletionNotification  - NotifyDescription - optional notification that is called with the following parameters:
//                                 Result               - String - selected value (array of strings if multiple selection is used)
//                                 AdditionalParameters - Undefined.
//
//
Procedure FileChoiceHandler(Object, Val PropertyName, StandardProcessing = False, Val DialogParameters = Undefined, CompletionNotification = Undefined) Export
	StandardProcessing = False;
	
	DialogDefaultOptions = New Structure;
	DialogDefaultOptions.Insert("Mode",           FileDialogMode.Open);
	DialogDefaultOptions.Insert("CheckFileExist", True);
	DialogDefaultOptions.Insert("Title",          NStr("en = 'Select file'"));
	DialogDefaultOptions.Insert("Multiselect",    False);
	DialogDefaultOptions.Insert("Preview",        False);
	
	SetDefaultStructureValues(DialogParameters, DialogDefaultOptions);
	
	WarningText = NStr("en = 'This action requires the file system extension for 1C:Enterprise web client.'");
	
	Notification = New NotifyDescription("FileChoiceHandlerCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("Object",                  Object);
	Notification.AdditionalParameters.Insert("PropertyName",            PropertyName);
	Notification.AdditionalParameters.Insert("DialogParameters",        DialogParameters);
	Notification.AdditionalParameters.Insert("CompletionNotification",  CompletionNotification);
	
	CommonUseClient.ShowFileSystemExtensionInstallationQuestion(Notification, WarningText, False);
EndProcedure
 
// Nonmodal completion handler for the file selection dialog.
//
Procedure FileChoiceHandlerCompletion(Val Result, Val AdditionalParameters) Export
	If Result <> True Then
		Return;
	EndIf;
	
	PropertyName = AdditionalParameters.PropertyName;
	Object       = AdditionalParameters.Object;
	
	SelectionDialogParameters = AdditionalParameters.DialogParameters;
	Dialog = New FileDialog(SelectionDialogParameters.Mode);
	FillPropertyValues(Dialog, SelectionDialogParameters);
	
	Dialog.FullFileName = Object[PropertyName];
	If Dialog.Choose() Then
		Object[PropertyName] = Dialog.FullFileName;
		
		If AdditionalParameters.CompletionNotification <> Undefined Then
			Result = ?(Dialog.Multiselect, Dialog.SelectedFiles, Dialog.FullFileName);
			ExecuteNotifyProcessing(AdditionalParameters.CompletionNotification, Result);
		EndIf;
	EndIf;
	
EndProcedure
 
// Prompts the user to install the file system extension and uploads files to the server.
//
// Parameters:
//     CompletionNotification - NotifyDescription - export procedure that is called with the following parameters:
//                                Result               - Array - contains structures that contain the following fields:
//                                                       Name, Location, and ErrorDetails. Each structure describes a file. 
//                                AdditionalParameters - Undefined.
//
//     FileNames             - Array - names of files for uploading to the server.
//     FormID        - UUID - this value is used for saving data to a temporary storage. 
//     WarningText           - String - warning text, notifies that the installation of the file system extension is required.
//
Procedure SendFilesToServer(CompletionNotification, Val FileNames, Val FormID = Undefined, Val WarningText = Undefined) Export
	
	FileData = New Array;
	HasEmpty = False;
	
	For Each FileName In FileNames Do
		FileDetails = New Structure("Name, Location, ErrorDetails", FileName);
		If IsBlankString(FileName) Then
			HasEmpty = True;
			FileDetails.ErrorDescription = NStr("en = 'File is not selected.'");
		EndIf;
		FileData.Add(FileDetails);
	EndDo;
	
	If HasEmpty Then
		ExecuteNotifyProcessing(CompletionNotification, FileData);
		Return;
	EndIf;
 
	Notification= New NotifyDescription("SendFileToServerExtensionInstallCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("Notification",   CompletionNotification);
	Notification.AdditionalParameters.Insert("FileData",       FileData);
	Notification.AdditionalParameters.Insert("FormID", FormID);
	
	If WarningText = Undefined Then
		If FileNames.Count() = 1 Then
			WarningText = NStr("en = 'To upload the file to the server, you have to install the file system extension.'");
		Else
			WarningText = NStr("en = 'To upload the files to the server, you have to install the file system extension.'");
		EndIf;
	EndIf;
	
	CommonUseClient.ShowFileSystemExtensionInstallationQuestion(Notification, WarningText, False);
EndProcedure
 
// Nonmodal completion handler for uploading the file to the server.
// 
Procedure SendFileToServerExtensionInstallCompletion(Val Result, Val AdditionalParameters) Export
	If Not Result Then
		Return;
	EndIf;
	// The extension is successfully installed
	
	FileData = AdditionalParameters.FileData;
	ListToTransfer = New Array;
	
	HasErrors  = False;
	For Each Item In FileData Do
		FileName = Item.Name;
		
		File = New File(FileName);
		If Not File.Exist() Or File.IsDirectory() Then
			HasErrors = True;
			Item.ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'The %1 file is inaccessible or does not exist.'"), FileName);
		Else
			ListToTransfer.Add( New TransferableFileDescription(FileName) );
		EndIf;
		
	EndDo;
	
	If Not HasErrors Then
		PlacedFiles = New Array;
		
		PutFiles(ListToTransfer, PlacedFiles, , False, AdditionalParameters.FormID);
		
		For Index = 0 To PlacedFiles.UBound() Do
			FileData[Index].Location = PlacedFiles[Index].Location;
		EndDo;
	EndIf;
	
	// Notifying a caller
	ExecuteNotifyProcessing(AdditionalParameters.Notification, FileData);
EndProcedure
 
// Uploads a file to the server interactively without using the file system extension.
//
// Parameters:
//     CompletionNotification - NotifyDescription - export procedure that is called with the following parameters:
//                                Result               - structure that contains the following fields: 
//                                                       Name, Location, and ErrorDetails. 
//                                AdditionalParameters - Undefined.
//
//     DialogParameters       - Structure - optional additional parameters of the file selection dialog.
//     FormID                 - String, UUID - this value is used for saving data to a temporary storage.
//
Procedure SelectAndSendFileToServer(CompletionNotification, Val DialogParameters = Undefined, Val FormID = Undefined) Export
	
	Result  = New Structure("Name, Location, ErrorDescription");
	
	Notification = New NotifyDescription("SelectAndSendFilesToServerCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("CompletionNotification", CompletionNotification);
	Notification.AdditionalParameters.Insert("Result", Result);
	
	If Not AttachFileSystemExtension() Then
		// If the extension is not available, using the selection dialog from the BeginPutFile method
		BeginPutFile(Notification, , , True, FormID);
		Return;
	EndIf;
		
	// If the extension is available, using the custom file dialog to select a file
	DialogDefaultOptions = New Structure;
	DialogDefaultOptions.Insert("CheckFileExist", True);
	DialogDefaultOptions.Insert("Title",          NStr("en = 'Select file'"));
	DialogDefaultOptions.Insert("Multiselect",    False);
	DialogDefaultOptions.Insert("Preview",        False);
	
	SetDefaultStructureValues(DialogParameters, DialogDefaultOptions);
	
	ChoiceDialog = New FileDialog(FileDialogMode.Open);
	FillPropertyValues(ChoiceDialog, DialogParameters);
	
	If ChoiceDialog.Choose() Then
		BeginPutFile(Notification, , ChoiceDialog.FullFileName, False, FormID);
	EndIf;
 
EndProcedure
 
// Nonmodal completion handler for selecting a file and uploading it to the server.
//
Procedure SelectAndSendFilesToServerCompletion(Val Done, Val Address, Val SelectedFileName, Val AdditionalParameters) Export
	If Not Done Then
		Return;
	EndIf;
	
	// Notifying a caller
	Result = AdditionalParameters.Result;
	Result.Name     = SelectedFileName;
	Result.Location = Address;
	
	ExecuteNotifyProcessing(AdditionalParameters.CompletionNotification, Result);
EndProcedure
 
// Starts interactive file download from the server without using the file system extension.
//
// Parameters:
//     FileToReceive    - Structure - file description. It contains Name and Location properties.
//     DialogParameters - Structure - optional additional parameters of the file selection dialog.
//
Procedure SelectAndSaveFileAtClient(Val FileToReceive, Val DialogParameters = Undefined) Export
	
	If Not AttachFileSystemExtension() Then
		// If the extension is not available, using the selection dialog from the GetFile method
		GetFile(FileToReceive.Location, FileToReceive.Name, True);
		Return;
	EndIf;
	
	// If the extension is available, using the custom file dialog to select a file
	DialogDefaultOptions = New Structure;
	DialogDefaultOptions.Insert("Title",       NStr("en = 'Select file to download'"));
	DialogDefaultOptions.Insert("Multiselect", False);
	DialogDefaultOptions.Insert("Preview",     False);
	
	SetDefaultStructureValues(DialogParameters, DialogDefaultOptions);
	
	SavingDialog = New FileDialog(FileDialogMode.Save);
	FillPropertyValues(SavingDialog, DialogParameters);
	
	FilesToReceive = New Array;
	FilesToReceive.Add( New TransferableFileDescription(FileToReceive.Name, FileToReceive.Location) );
	
	ReceivedFiles = New Array;
	GetFiles(FilesToReceive, ReceivedFiles, SavingDialog, True);
EndProcedure
 
// Adds fields to the target structure if the structure does not contain these fields.
//
// Parameters:
//     Result        - Structure - target structure. 
//     DefaultValues - Structure - default values.
//
Procedure SetDefaultStructureValues(Result, Val DefaultValues) Export
	
	If Result = Undefined Then
		Result = New Structure;
	EndIf;
	
	For Each KeyValue In DefaultValues Do
		PropertyName = KeyValue.Key;
		If Not Result.Property(PropertyName) Then
			Result.Insert(PropertyName, KeyValue.Value);
		EndIf;
	EndDo;
	
EndProcedure
 
// Opens the information register record form with the specified filter.
Procedure OpenInformationRegisterRecordFormByFilter(
												Filter,
												FillingValues,
												Val RegisterName,
												OwnerForm,
												Val FormName = "",
												FormParameters = Undefined,
												ClosingNotification = Undefined) Export
	
	Var RecordKey;
	
	EmptyRecordSet = DataExchangeServerCall.RegisterRecordSetEmpty(Filter, RegisterName);
	
	If Not EmptyRecordSet Then
		// Filling value type using the Type operator because other methods are not available on the client
		
		ValueType = Type("InformationRegisterRecordKey." + RegisterName);
		Parameters = New Array(1);
		Parameters[0] = Filter;
		
		RecordKey = New(ValueType, Parameters);
	EndIf;
	
	WriteParameters = New Structure;
	WriteParameters.Insert("Key",               RecordKey);
	WriteParameters.Insert("FillingValues", FillingValues);
	
	If FormParameters <> Undefined Then
		
		For Each Item In FormParameters Do
			
			WriteParameters.Insert(Item.Key, Item.Value);
			
		EndDo;
		
	EndIf;
	
	If IsBlankString(FormName) Then
		
		FullFormName = "InformationRegister.[RegisterName].RecordForm";
		FullFormName = StrReplace(FullFormName, "[RegisterName]", RegisterName);
		
	Else
		
		FullFormName = "InformationRegister.[RegisterName].Form.[FormName]";
		FullFormName = StrReplace(FullFormName, "[RegisterName]", RegisterName);
		FullFormName = StrReplace(FullFormName, "[FormName]", FormName);
		
	EndIf;
	
	// Opening the information register record form
	If ClosingNotification <> Undefined Then
		OpenForm(FullFormName, WriteParameters, OwnerForm, , , , ClosingNotification);
	Else
		OpenForm(FullFormName, WriteParameters, OwnerForm);
	EndIf;
	
EndProcedure
 
// Opens the form for importing conversion and registration rules from a single file.
//
Procedure ImportDataSynchronizationRules(Val ExchangePlanName) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("ExchangePlanName", ExchangePlanName);
	
	OpenForm("InformationRegister.DataExchangeRules.Form.ImportDataSynchronizationRules", FormParameters,, ExchangePlanName);
	
EndProcedure
 
// Opens the event log with a filter by import and export events for the specified exchange plan node.
// 
Procedure GoToDataEventLog(InfobaseNode, CommandExecuteParameters, ExchangeActionString) Export
	
	EventLogMessageText = DataExchangeServerCall.GetEventLogMessageKeyByActionString(InfobaseNode, ExchangeActionString);
	
	FormParameters = New Structure;
	FormParameters.Insert("EventLogMessageText", EventLogMessageText);
	
	OpenForm("DataProcessor.EventLog.Form", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure
 
// Opens the event log modally with a filter by import and export events for the specified exchange plan node.
//
Procedure GoToDataEventLogModally(InfobaseNode, Owner, ActionOnExchange) Export
	
	// Server call
	FormParameters = DataExchangeServerCall.GetEventLogFilterDataStructure(InfobaseNode, ActionOnExchange);
	
	OpenForm("DataProcessor.EventLog.Form", FormParameters, Owner);
	
EndProcedure
 
// Opens the data exchange execution form for the specified exchange plan node.
//
// Parameters:
//  InfobaseNode - ExchangePlanRef - exchange plan node whose form is opened.
//  Owner        - owner form for the form that is opened.
// 
Procedure ExecuteDataExchangeCommandProcessing(InfobaseNode, Owner,
		AddressForRestoringAccountPassword = "", Val AutomaticSynchronization = Undefined) Export
	
	If AutomaticSynchronization = Undefined Then
		AutomaticSynchronization = (DataExchangeServerCall.DataExchangeVariant(InfobaseNode) = "Synchronization");
	EndIf;
	
	If AutomaticSynchronization Then
		
		FormParameters = New Structure;
		FormParameters.Insert("InfobaseNode", InfobaseNode);
		FormParameters.Insert("AddressForRestoringAccountPassword", AddressForRestoringAccountPassword);
		
		OpenForm("DataProcessor.DataExchangeExecution.Form.Form", FormParameters, Owner, InfobaseNode);
		
	Else
		
		FormParameters = New Structure;
		FormParameters.Insert("InfobaseNode", InfobaseNode);
		FormParameters.Insert("ExportAdditionExtendedMode", True);
		
		OpenForm("DataProcessor.InteractiveDataExchangeWizard.Form", FormParameters, Owner, InfobaseNode, , , ,FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure
 
// Opens the form of the interactive data exchange execution for the specified exchange plan node.
//
// Parameters:
//  InfobaseNode - ExchangePlanRef - exchange plan node whose form is opened.
//  Owner        - owner form for the form that is opened.
//
Procedure OpenObjectMappingWizardCommandProcessing(InfobaseNode, Owner) Export
	
	// Opening the object mapping wizard form.
	// Passing the infobase node as a form parameter.
	FormParameters = New Structure("InfobaseNode", InfobaseNode);
	
	FormName = "DataProcessor.InteractiveDataExchangeWizard.Form";
	
	If CommonUseClient.SubsystemExists("DataExchangeXDTO") Then
		
		DataExchangeXDTOClientCachedModule = CommonUseClient.CommonModule("DataExchangeXDTOClientCached");
		If DataExchangeXDTOClientCachedModule.IsXDTOExchangePlan(InfobaseNode) Then
			FormName = "DataProcessor.InteractiveDataExchangeViaXDTOWizard.Form";
		EndIf;
		
	EndIf;
	
	OpenForm(FormName, FormParameters, Owner, InfobaseNode, , , ,FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure
 
// Opens the data exchange execution scenario list form for the specified exchange plan node.
//
// Parameters:
//  InfobaseNode - ExchangePlanRef - exchange plan node whose form is opened.
//  Owner        - owner form for the form that is opened.
//
Procedure SetExchangeExecutionScheduleCommandProcessing(InfobaseNode, Owner) Export
	
	FormParameters = New Structure("InfobaseNode", InfobaseNode);
	
	OpenForm("Catalog.DataExchangeScenarios.Form.DataExchangeScheduleSetup", FormParameters, Owner);
	
EndProcedure
 
// Notifies all opened dynamic lists that data that is displayed must be refreshed.
//
Procedure RefreshAllOpenDynamicLists() Export
	
	Types = DataExchangeServerCall.AllConfigurationReferenceTypes();
	
	For Each Type In Types Do
		
		NotifyChanged(Type);
		
	EndDo;
	
EndProcedure
 
// Opens form of the monitor that displays data registered for sending.
//
Procedure OpenSentDataContent(Val InfobaseNode) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("ExchangeNode", InfobaseNode);
	FormParameters.Insert("SelectExchangeNodeProhibited", True);
	
	// Internal data that cannot be modified if the data processor is called from a command
	FormParameters.Insert("NamesOfMetadataToHide", New ValueList);
	FormParameters.NamesOfMetadataToHide.Add("InformationRegister.InfobaseObjectMappings");
	
	NotExportByRules = DataExchangeServerCall.NonExportableNodeObjectMetadataNames(InfobaseNode);
	For Each MetadataName In NotExportByRules Do
		FormParameters.NamesOfMetadataToHide.Add(MetadataName);
	EndDo;
	
	OpenForm("DataProcessor.RecordChangesForDataExchange.Form", FormParameters,, InfobaseNode);
EndProcedure
 
// Deletes data synchronization settings item.
//
Procedure DeleteSynchronizationSettings(Val InfobaseNode) Export
	
	QuestionText = NStr("en = 'Do you want to delete the synchronization settings item?'");
	NotifyDescription = New NotifyDescription("DeleteSynchronizationSettingsCompletion", ThisObject, InfobaseNode);
	ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo,, DialogReturnCode.Yes);
	
EndProcedure
 
// Notification handler.
//
Procedure DeleteSynchronizationSettingsCompletion(Answer, InfobaseNode) Export
	
	If Answer = DialogReturnCode.Yes Then
		
		ClosingNotification = New NotifyDescription("AfterPermissionDeletion", ThisObject, InfobaseNode);
		Queries = DataExchangeServerCall.RequestForClearingPermissionsForExternalResources(InfobaseNode);
		SafeModeClient.ApplyExternalResourceRequests(Queries, Undefined, ClosingNotification);
		
	EndIf;
	
EndProcedure
 
Procedure AfterPermissionDeletion(Result, InfobaseNode)Export
	
	If Result = DialogReturnCode.OK Then
		
		DataExchangeServerCall.DeleteSynchronizationSettings(InfobaseNode);
		Notify("Write_ExchangePlanNode");
		CloseForms("NodeForm");
		
	EndIf;
	
EndProcedure
 
// Closes opened forms whose names contain the specified substring and the modification flag is False.
//
Procedure CloseForms(Val FormName)
	
	Windows = GetWindows();
	
	If Windows <> Undefined Then
		
		For Each Window In Windows Do
			
			If Not Window.IsMain Then
				
				Form = Window.GetContent();
				
				If TypeOf(Form) = Type("ManagedForm")
					And Not Form.Modified
					And Find(Form.FormName, FormName) <> 0 Then
					
					Form.Close();
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure
 
// Registers the handler that opens another form after the current form is closed.
// 
Procedure OpenFormAfterCurrentFormClosed(CurrentForm, Val FormName, Val Parameters = Undefined, Val OpenParameters = Undefined) Export
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("FormName",       FormName);
	AdditionalParameters.Insert("Parameters",     Parameters);
	AdditionalParameters.Insert("OpenParameters", OpenParameters);
	
	AdditionalParameters.Insert("PreviousCloseNotification",  CurrentForm.OnCloseNotifyDescription);
	
	CurrentForm.OnCloseNotifyDescription = New NotifyDescription("OpenFormAfterCurrentFormClosedHandler", ThisObject, AdditionalParameters);
EndProcedure
 
// Deferred opening
Procedure OpenFormAfterCurrentFormClosedHandler(Val CloseResult, Val AdditionalParameters) Export
	
	OpenParameters = New Structure("Owner, Uniqueness, Window, URL, OnCloseNotifyDescription, WindowOpeningMode");
	FillPropertyValues(OpenParameters, AdditionalParameters.OpenParameters);
	OpenForm(AdditionalParameters.FormName, AdditionalParameters.Parameters,
		OpenParameters.Owner, OpenParameters.Uniqueness, OpenParameters.Window, OpenParameters.URL, OpenParameters.OnCloseNotifyDescription, OpenParameters.WindowOpeningMode
	);
	
	If AdditionalParameters.PreviousCloseNotification <> Undefined Then
		ExecuteNotifyProcessing(AdditionalParameters.PreviousCloseNotification, CloseResult);
	EndIf;
	
EndProcedure
 
// Opens a form that contains a notification about an infobase update error that occurs due to an error in the ORR.
//
Procedure UnsuccessfulUpdateMessageFormName(NameOfFormToOpen) Export
	
	NameOfFormToOpen = "InformationRegister.DataExchangeRules.Form.UnsuccessfulUpdateMessage";
	
EndProcedure
 
////////////////////////////////////////////////////////////////////////////////
// Handlers of conditional calls from other subsystems.
 
////////////////////////////////////////////////////////////////////////////////
// Handlers of conditional calls to other subsystems.
 
// Updates infobase configuration.
//
Procedure ExecuteInfobaseUpdate(ExitApplication = False) Export
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then
		ConfigurationUpdateClientModule = CommonUseClient.CommonModule("ConfigurationUpdateClient");
		ConfigurationUpdateClientModule.OnInfobaseUpdate(ExitApplication);
	Else
		OpenForm("CommonForm.AdditionalDetails", New Structure("Title,TemplateName",
		NStr("en = 'Update setup'"), "ManualUpdateInstruction"));
	EndIf;
	
EndProcedure
 
// Opens the batch object modification form.
//
// Parameters:
//  List - FormTable - list form item that contains references to objects to be modified.
//
Procedure OnChangeSelectedObjects(List) Export
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.BatchObjectModification") Then
		BatchObjectModificationClientModule = CommonUseClient.CommonModule("BatchObjectModificationClient");
		BatchObjectModificationClientModule.ChangeSelected(List);
	EndIf;
	
EndProcedure
 
// Open event handler for the instruction for restoring or 
// changing the synchronization password on a standalone workstation.
//
Procedure OnOpenHowToChangeDataSynchronizationPasswordInstruction(Val AddressForRestoringAccountPassword) Export
	
	If IsBlankString(AddressForRestoringAccountPassword) Then
		
		ShowMessageBox(, NStr("en = 'Password recovery email address is not specified.'"));
		
	Else
		
		GotoURL(AddressForRestoringAccountPassword);
		
	EndIf;
	
EndProcedure
 
// Opens the version report or the version comparison report.
//
// Parameters:
//  Ref              - object reference.
//  ComparedVersions - Array - contains versions to be compared.
//                     If there is a single version in the array, 
//                     the version report is opened.
//
Procedure OnOpenReportFormByVersion(Ref, ComparedVersions) Export
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.ObjectVersioning") Then
		ObjectVersioningClientModule = CommonUseClient.CommonModule("ObjectVersioningClient");
		ObjectVersioningClientModule.OnOpenReportFormByVersion(Ref, ComparedVersions);
	EndIf;
	
EndProcedure
 
////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.
 
Procedure OnCloseExchangePlanNodeSettingsForm(Form, FormAttributeName)
	
	If Not Form.CheckFilling() Then
		Return;
	EndIf;
	
	For Each FilterSettings In Form[FormAttributeName] Do
		
		If TypeOf(Form[FilterSettings.Key]) = Type("FormDataCollection") Then
			
			TabularSectionStructure = Form[FormAttributeName][FilterSettings.Key];
			
			For Each Item In TabularSectionStructure Do
				
				TabularSectionStructure[Item.Key].Clear();
				
				For Each CollectionRow In Form[FilterSettings.Key] Do
					
					TabularSectionStructure[Item.Key].Add(CollectionRow[Item.Key]);
					
				EndDo;
				
			EndDo;
			
		Else
			
			Form[FormAttributeName][FilterSettings.Key] = Form[FilterSettings.Key];
			
		EndIf;
		
	EndDo;
	
	Form.Modified = False;
	Form.Close(Form[FormAttributeName]);
	
EndProcedure
 
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// 
// INTERNAL INTERFACE FOR THE INTERACTIVE EXPORT ADDITION.
//
 
// Opens the form of the interactive export addition data processor.
//
// Parameters:
//     ExportAddition            - Structure, FormDataStructure - export settings.
//     Owner, Uniqueness, Window - form opening parameters.
//
// Returns:
//     Opened form.
//
Function OpenExportAdditionFormNodeScenario(Val ExportAddition, Val Owner=Undefined, Val Uniqueness=Undefined, Val Window=Undefined) Export
	
	FormParameters = New Structure("ChoiceMode, CloseOnChoice", True, True);
	FormParameters.Insert("InfobaseNode", ExportAddition.InfobaseNode);
	FormParameters.Insert("FilterPeriod", ExportAddition.NodeScenarioFilterPeriod);
	FormParameters.Insert("Filter",       ExportAddition.AdditionalNodeScenarioRegistration);
 
	Return OpenForm(ExportAddition.AdditionScenarioParameters.AdditionalVariant.FilterFormName,
		FormParameters, Owner, Uniqueness, Window);
EndFunction
 
// Opens the form of the interactive export addition data processor.
//
// Parameters:
//     ExportAddition            - Structure, FormDataStructure - export settings. 
//     Owner, Uniqueness, Window - form opening parameters.
//
// Returns:
//     Opened form.
//
Function OpenExportAdditionFormAllDocuments(Val ExportAddition, Val Owner=Undefined, Val Uniqueness=Undefined, Val Window=Undefined) Export
	FormParameters = New Structure;
	
	FormParameters.Insert("Title", NStr("en='Adding documents to send.'") );
	FormParameters.Insert("ChoiceAction", 1);
	
	FormParameters.Insert("SelectPeriod", True);
	FormParameters.Insert("DataPeriod",   ExportAddition.AllDocumentsFilterPeriod);
	
	FormParameters.Insert("SettingsComposerAddress", ExportAddition.AllDocumentsComposerAddress);
	
	FormParameters.Insert("FromStorageAddress", ExportAddition.FromStorageAddress);
	
	Return OpenForm("DataProcessor.InteractiveExportModification.Form.EditPeriodAndFilter", 
		FormParameters, Owner, Uniqueness, Window);
EndFunction
 
// Opens the form of the interactive export addition data processor.
//
// Parameters:
//     ExportAddition            - Structure, FormDataStructure - export settings.
//     Owner, Uniqueness, Window - form opening parameters.
//
// Returns:
//     Opened form.
//
Function OpenExportAdditionFormDetailedFilter(Val ExportAddition, Val Owner=Undefined, Val Uniqueness=Undefined, Val Window=Undefined) Export
	FormParameters = New Structure;
	
	FormParameters.Insert("ChoiceAction", 2);
	FormParameters.Insert("ObjectSettings", ExportAddition);
	
	FormParameters.Insert("OpenByScenario", True);
	Return OpenForm("DataProcessor.InteractiveExportModification.Form", 
		FormParameters, Owner, Uniqueness, Window);
EndFunction
 
// Opens the form of the interactive export addition data processor.
//
// Parameters:
//     ExportAddition            - Structure, FormDataStructure - export settings.
//     Owner, Uniqueness, Window - form opening parameters.
//
// Returns:
//     Opened form.
//
Function OpenExportAdditionFormDataContent(Val ExportAddition, Val Owner=Undefined, Val Uniqueness=Undefined, Val Window=Undefined) Export
	FormParameters = New Structure;
	
	FormParameters.Insert("ObjectSettings", ExportAddition);
	If ExportAddition.ExportVariant = 3 Then
		FormParameters.Insert("SimplifiedMode", True);
	EndIf;
	
	Return OpenForm("DataProcessor.InteractiveExportModification.Form.ExportContent",
		FormParameters, Owner, Uniqueness, Window);
EndFunction
 
// Opens the form of the interactive export addition data processor.
//
// Parameters:
//     ExportAddition            - Structure, FormDataStructure - export settings.
//     Owner, Uniqueness, Window - form opening parameters.
//
// Returns:
//     Opened form.
//
Function OpenExportAdditionFormSettingsSaving(Val ExportAddition, Val Owner=Undefined, Val Uniqueness=Undefined, Val Window=Undefined) Export
	FormParameters = New Structure("CloseOnChoice, ChoiceAction", True, 3);
	
	// Data composer is not passed to the form being opened
	ExportAddition.AllDocumentsFilterComposer = Undefined;
	
	FormParameters.Insert("CurrentSettingsItemPresentation", ExportAddition.CurrentSettingsItemPresentation);
	FormParameters.Insert("Object", ExportAddition);
	
	Return OpenForm("DataProcessor.InteractiveExportModification.Form.EditSettingsContent",
		FormParameters, Owner, Uniqueness, Window);
EndFunction
 
// Selection handler of the export addition wizard form.
// The function checks the source for the call from the export addition and processes the data stored 
// in the ExportAddition parameter.
//
// Parameters:
//     SelectedValue  - Arbitrary - selection result.
//     ChoiceSource   - ManagedForm - selection is made in this form.
//     ExportAddition - Structure, FormDataCollection - custom synchronization settings.
//
// Returns:
//     Boolean - True if the selection is called from one of the export addition forms, False otherwise
//
Function ExportAdditionChoiceProcessing(Val SelectedValue, Val ChoiceSource, ExportAddition) Export
	
	If ChoiceSource.FormName="DataProcessor.InteractiveExportModification.Form.EditPeriodAndFilter" Then
		// Changing the "All documents" predefined filter. Actions that are executed are specified in SelectedValue.
		Return ExportAdditionStandardVariantChoiceProcessing(SelectedValue, ExportAddition);
		
	ElsIf ChoiceSource.FormName="DataProcessor.InteractiveExportModification.Form.Form" Then
		// Changing the "Detailed" predefined filter. Actions that are executed are specified in SelectedValue.
		Return ExportAdditionStandardVariantChoiceProcessing(SelectedValue, ExportAddition);
		
	ElsIf ChoiceSource.FormName="DataProcessor.InteractiveExportModification.Form.EditSettingsContent" Then
		// Settings. Actions that are executed are specified in SelectedValue.
		Return ExportAdditionStandardVariantChoiceProcessing(SelectedValue, ExportAddition);
		
	ElsIf ChoiceSource.FormName=ExportAddition.AdditionScenarioParameters.AdditionalVariant.FilterFormName Then
		// Changing settings according to the node scenario
		Return ExportAdditionNodeScenarioChoiceProcessing(SelectedValue, ExportAddition);
		
	EndIf;
	
	Return False;
EndFunction
 
Procedure FillStructureData(Form)
	
	//Saving the values entered in this application
	SettingsStructure = Form.Context.NodeFilterStructure;
	AppropriateAttributes = Form.AttributeNames;
	
	For Each SettingItem In SettingsStructure Do
		
		If AppropriateAttributes.Property(SettingItem.Key) Then
			
			AttributeName = AppropriateAttributes[SettingItem.Key];
			
		Else
			
			AttributeName = SettingItem.Key;
			
		EndIf;
		
		FormAttribute = Form[AttributeName];
		
		If TypeOf(FormAttribute) = Type("FormDataCollection") Then
			
			TableName = SettingItem.Key;
			
			Table = New Array;
			
			For Each Item In Form[AttributeName] Do
				
				TableRow = New Structure("Use, Presentation, RefUUID");
				
				FillPropertyValues(TableRow, Item);
				
				Table.Add(TableRow);
				
			EndDo;
			
			SettingsStructure.Insert(TableName, Table);
			
		Else
			
			SettingsStructure.Insert(SettingItem.Key, Form[AttributeName]);
			
		EndIf;
		
	EndDo;
	
	Form.Context.NodeFilterStructure = SettingsStructure;
	
	//Saving values entered in the other application
	SettingsStructure = Form.Context.CorrespondentInfobaseNodeFilterSetup;
	AppropriateAttributes = Form.CorrespondentInfobaseAttributeNames;
	
	For Each SettingItem In SettingsStructure Do
		
		If AppropriateAttributes.Property(SettingItem.Key) Then
			
			AttributeName = AppropriateAttributes[SettingItem.Key];
			
		Else
			
			AttributeName = SettingItem.Key;
			
		EndIf;
		
		FormAttribute = Form[AttributeName];
		
		If TypeOf(FormAttribute) = Type("FormDataCollection") Then
			
			TableName = SettingItem.Key;
			
			Table = New Array;
			
			For Each Item In Form[AttributeName] Do
				
				TableRow = New Structure("Use, Presentation, RefUUID");
				
				FillPropertyValues(TableRow, Item);
				
				Table.Add(TableRow);
				
			EndDo;
			
			SettingsStructure.Insert(TableName, Table);
			
		Else
			
			SettingsStructure.Insert(SettingItem.Key, Form[AttributeName]);
			
		EndIf;
		
	EndDo;
	
	Form.Context.CorrespondentInfobaseNodeFilterSetup = SettingsStructure;
	
	Form.Context.Insert("ContextDetails", Form.ContextDetails);
	
EndProcedure
 
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// 
// INTERNAL PROCEDURES AND FUNCTIONS FOR THE INTERACTIVE EXPORT ADDITION.
//
 
Function ExportAdditionStandardVariantChoiceProcessing(Val SelectedValue, ExportAddition)
	
	Result = False;
	If TypeOf(SelectedValue) = Type("Structure") Then 
		
		If SelectedValue.ChoiceAction=1 Then
			// Filter and period for all documents
			ExportAddition.AllDocumentsFilterComposer = Undefined;
			ExportAddition.AllDocumentsComposerAddress = SelectedValue.SettingsComposerAddress;
			ExportAddition.AllDocumentsFilterPeriod    = SelectedValue.DataPeriod;
			Result = True;
			
		ElsIf SelectedValue.ChoiceAction = 2 Then
			// Detailed setup
			SelectionObject = GetFromTempStorage(SelectedValue.ObjectAddress);
			FillPropertyValues(ExportAddition, SelectionObject, , "AdditionalRegistration");
			ExportAddition.AdditionalRegistration.Clear();
			For Each Row In SelectionObject.AdditionalRegistration Do
				FillPropertyValues(ExportAddition.AdditionalRegistration.Add(), Row);
			EndDo;
			Result = True;
			
		ElsIf SelectedValue.ChoiceAction=3 Then
			// Settings are saved, saving the current name
			ExportAddition.CurrentSettingsItemPresentation = SelectedValue.SettingsItemPresentation;
			Result = True;
			
		EndIf;
	EndIf;
	
	Return Result;
EndFunction
 
Function ExportAdditionNodeScenarioChoiceProcessing(Val SelectedValue, ExportAddition)
	If TypeOf(SelectedValue)<>Type("Structure") Then 
		Return False;
	EndIf;
	
	ExportAddition.NodeScenarioFilterPeriod       = SelectedValue.FilterPeriod;
	ExportAddition.NodeScenarioFilterPresentation = SelectedValue.FilterPresentation;
	
	ExportAddition.AdditionalNodeScenarioRegistration.Clear();
	For Each RegistrationRow In SelectedValue.Filter Do
		FillPropertyValues(ExportAddition.AdditionalNodeScenarioRegistration.Add(), RegistrationRow);
	EndDo;
	
	Return True;
EndFunction
 
#EndRegion