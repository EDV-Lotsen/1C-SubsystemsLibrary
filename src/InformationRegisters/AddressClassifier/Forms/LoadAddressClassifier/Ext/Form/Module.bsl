// This form is parameterized. Optional parameters:
//     StateCodeForImport - Number, String, Array - Code (array of codes) of regions to be imported.
//     StateNameForImport - String                - Name of region to be imported.
// 
// If at least one parameter is specified, the related state 
// will be marked for import and selected as current state.
//

// Confirmation flag, used when closing
&AtClient
Var FormClosingConfirmation;

// Storage for transmitted files
&AtClient
Var PlacedFiles;

// Import parameters to be sent between client calls
&AtClient
Var ClassifierBackgroundImportParameters;

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	LongActionParameters = New Structure("IdleInterval, Completed, ResultAddress, ID, Error", 5);
	
	AvailableImportSources.Clear();
	
	AvailableImportSources.Add("DIRECTORY", NStr("en = 'From directory on disk'") );
	
	// ITS files are distributed in self-extracted .EXE format (not available for Linux).
	//If AddressClassifierClientServer.IsWindowsClient() Then
		//AvailableImportSources.Add("ITS", NStr("en = 'From 1C:ITS disc'") );
	//EndIf;
	
	AvailableImportSources.Add("WEBSITE", NStr("en = 'From 1C:Enterprise user support website'") );
	
	// Getting the previously imported regions
	StateTable = InformationRegisters.AddressClassifier.RegionImportInformation();
	StateTable.Columns.Add("Import", New TypeDescription("Boolean"));
	StateTable.LoadColumn(StateTable.UnloadColumn("Downloaded"), "Import");
	
	For Each State In StateTable Do
		State.Presentation = Format(State.RegionCode, "ND=2; NZ=; NLZ=; NG=") + ", " + State.Presentation;
	EndDo;
	
	// Selecting check box for the region, setting the selected region as current row
	StateNameForImport = Undefined;
	CurrentStateCode          = Undefined;
	
	Parameters.Property("StateCodeForImport", CurrentStateCode);
	
	CurrentStateCodeType = TypeOf(CurrentStateCode);
	NumberType               = New TypeDescription("Number");
		
	If CurrentStateCodeType = Type("Array") And CurrentStateCode.Count() > 0 Then
		// Array selected for import
		For Each StateCode In CurrentStateCode Do 
			Candidates = Regions.FindRows(New Structure("RegionCode", NumberType.AdjustValue(StateCode) )); 
			If Candidates.Count() > 0 Then
				Candidates[0].Import = True;
			EndIf;
		EndDo;
		CurrentStateCode = CurrentStateCode[0];
		
	ElsIf CurrentStateCodeType = Type("String") Then
		CurrentStateCode = NumberType.AdjustValue(CurrentStateCode);
		
	EndIf;
	
	If CurrentStateCode = Undefined And Parameters.Property("StateNameForImport", StateNameForImport) Then;
		// Attempting to determine state code by name
		CurrentStateCode = InformationRegisters.AddressClassifier.StateCodeByName(StateNameForImport);
	EndIf;
	
	ValueToFormAttribute(StateTable, "Regions");
	
	If CurrentStateCode <> Undefined Then
		Candidates = Regions.FindRows(New Structure("RegionCode", CurrentStateCode)); 
		If Candidates.Count() > 0 Then
			CurrentRow = Candidates[0];
			CurrentRow.Import = True;
			Items.Regions.CurrentRow = CurrentRow.GetID();
		EndIf;
	EndIf;
	
	// Attempting to set the first selected row as current row (if current row was not set parametrically)
	If Items.Regions.CurrentRow = Undefined Then
		Candidates = Regions.FindRows(New Structure("Import", True)); 
		If Candidates.Count() > 0 Then
			Items.Regions.CurrentRow = Candidates[0].GetID();
		EndIf;
	EndIf;
	
	// Interface variants
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Version8_2 Then
		Items.ImportAddress.ChoiceButtonPicture = New Picture;
	EndIf;
	
	
	// Autosaving settings
	SavedInSettingsDataModified = True;
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	// Validating import data source code
	SourceCode = Settings["ImportSourceCode"];
	If AvailableImportSources.FindByValue(SourceCode) = Undefined Then
		Settings.Delete("ImportSourceCode");
		Settings.Delete("ImportAddress");
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
#If WebClient Then
	ShowMessageBox(, NStr("en='Web client does not support the address classifier import functionality.'"));
	Cancel = True;
	Return;
#EndIf
	
	SetDataSourceLabel();
	RefreshInterfaceByImportedCount();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	// Checking the client variable
	If FormClosingConfirmation<>True Then
		Notification = New NotifyDescription("FormClosingCompletion", ThisObject);
		Cancel = True;
		
		Text = NStr("en = 'Cancel address classifier import?'");
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If LongActionParameters.ID = Undefined Then
		CancelBackgroundJob(LongActionParameters.ID);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormsItemEventHandlers

&AtClient
Procedure RegionsSelection(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;
	
	If Field = Items.RegionsPresentation Then
		CurrentData = Regions.FindByID(SelectedRow);
		If CurrentData <> Undefined Then
			CurrentData.Import = Not CurrentData.Import;
			RefreshInterfaceByImportedCount();
		EndIf
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportSourcePresentationURLProcessing(Item, URL, StandardProcessing)
	StandardProcessing = False;
	
	Notification = New NotifyDescription("EndImportSourceChange", ThisObject);
	
	ShowChooseFromMenu(Notification, AvailableImportSources, Item);
EndProcedure

&AtClient
Procedure ImportAddressStartChoice(Item, ChoiceData, StandardProcessing)
	
	AddressClassifierClient.ChooseDirectory(ThisObject, "ImportAddress", 
		NStr("en = 'Directory containing address classifier files'"),
		StandardProcessing
	);
	
EndProcedure

&AtClient
Procedure RegionsImportOnChange(Item)
	
	RefreshInterfaceByImportedCount();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure CheckAll(Command)
	
	SetCheckboxesForStateList(True);
	
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	
	SetCheckboxesForStateList(False);
	
EndProcedure

&AtClient
Procedure Import(Command)
	
	If ImportSourceCode = "DIRECTORY" Then
		Text = NStr("en = 'Before you can import address classifier data 
		                   |from directory, you need to install file system extension.'");
		FileSystemExtensionControl(Text, ImportSourceCode, ImportAddress);
		
	ElsIf ImportSourceCode = "ITS" Then
		Text = NStr("en = 'Before you can import address classifier data 
		                   |from ITS disc, you need to install file system extension.'");
		FileSystemExtensionControl(Text, ImportSourceCode, ImportAddress);
	
	ElsIf ImportSourceCode = "WEBSITE" Then
		Text = NStr("en = 'Before you can import address classifier data 
		                   |from website, you need to install file system extension.'");
		FileSystemExtensionControl(Text, ImportSourceCode, ImportAddress);
		
	Else
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Classifier import source not specified.'"), , "InvisibleRepresentationImportSource");
	EndIf;
		
EndProcedure

&AtClient
Procedure CancelImport(Command)
	FormClosingConfirmation = Undefined;
	Close();
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure FileSystemExtensionControl(Val SuggestionText, Val SourceCode, Val SourceAddress)
	
	Notification = New NotifyDescription("FileSystemExtensionControlEnd", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("ImportSourceCode", SourceCode);
	Notification.AdditionalParameters.Insert("ImportAddress",        SourceAddress);
	
	CommonUseClient.ShowFileSystemExtensionInstallationQuestion(Notification, SuggestionText, False);
EndProcedure

// Ending dialog that suggests installing file system extension
&AtClient
Procedure FileSystemExtensionControlEnd(Val Result, Val AdditionalParameters) Export
	
	If Result <> True Then
		Return;
		
	ElsIf Not AttachFileSystemExtension() Then
		ShowMessageBox(, NStr("en = 'The file system extension is not attached.'"));
		Return;
		
	EndIf;
	
	If AdditionalParameters.ImportSourceCode = "DIRECTORY" Then
		ImportClassifierFromDirectory(AdditionalParameters.ImportAddress);
		
	ElsIf AdditionalParameters.ImportSourceCode = "ITS" Then
		ImportClassifierFromITSDirectory(AdditionalParameters.ImportAddress);
		
	ElsIf AdditionalParameters.ImportSourceCode = "WEBSITE" Then
		ImportClassifierFromWebsite();
		
	EndIf;
	
EndProcedure

// Ending import change dialog
&AtClient
Procedure EndImportSourceChange(Val Result, Val AdditionalParameters) Export
	If Result = Undefined Then
		Return;
	EndIf;
	
	ImportSourceCode = Result.Value;
	SetDataSourceLabel();
EndProcedure

// Ending the form closing dialog
&AtClient
Procedure FormClosingCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult = DialogReturnCode.Yes Then
		FormClosingConfirmation = True;
		Close();
	Else 
		FormClosingConfirmation = Undefined;
	EndIf;
EndProcedure

&AtClient
Procedure SetDataSourceLabel()
	
	If ImportSourceCode = "DIRECTORY" Then
		Text = AvailableImportSources.FindByValue(ImportSourceCode).Presentation + ":";
		SourceVisibility = True;
		
	ElsIf ImportSourceCode = "ITS" Then
		Text = AvailableImportSources.FindByValue(ImportSourceCode).Presentation + ":";
		SourceVisibility = True;
			
	ElsIf ImportSourceCode = "WEBSITE" Then
		Text = AvailableImportSources.FindByValue(ImportSourceCode).Presentation;
		SourceVisibility = False;
		
	Else 
		Text = NStr("en = 'Source not specified'");
		SourceVisibility = False;
		
	EndIf;
	
	ImportSourcePresentation = New FormattedString(Text, , , , "Ref");
	
	If SourceVisibility Then
		Items.ImportAddressPresentationGroup.CurrentPage = Items.VisibleImportAddress;
	Else
		Items.ImportAddressPresentationGroup.CurrentPage = Items.InvisibleImportAddress;
	EndIf;
	
	SetImportPermission();
EndProcedure

&AtClient
Procedure SetImportPermission(Val ImportedCount = Undefined)
	
	If ImportedCount = Undefined Then
		ImportedCount = Regions.FindRows( New Structure("Import", True) ).Count();
	EndIf;
	
	Items.Load.Enabled = (ImportedCount > 0) 
		And AvailableImportSources.FindByValue(ImportSourceCode) <> Undefined;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	ConditionalAppearance.Items.Clear();
	
	Item = ConditionalAppearance.Items.Add();
	
	Fields = Item.Fields.Items;
	Fields.Add().Field = New DataCompositionField("RegionsRegionCode");
	Fields.Add().Field = New DataCompositionField("RegionsPresentation");

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Regions.Downloaded");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;

	Item.Appearance.SetParameterValue("TextColor", WebColors.Gray);
EndProcedure

&AtClient
Procedure SetCheckboxesForStateList(Val Check)
	
	// Set check boxes for visible rows only
	TableItem = Items.Regions;
	For Each StateString In Regions Do
		If TableItem.RowData( StateString.GetID() ) <> Undefined Then
			StateString.Import = Check;
		EndIf;
	EndDo;
	
	RefreshInterfaceByImportedCount();
EndProcedure

&AtClient
Procedure RefreshInterfaceByImportedCount()
	
	// Selection page
	RegionsSelectedForImport = Regions.FindRows( New Structure("Import", True) ).Count();
	
	// Import page
	ImportDescriptionText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Importing data on selected states (%1)'"), RegionsSelectedForImport 
	);
	
	SetImportPermission(RegionsSelectedForImport);
EndProcedure

&AtClient
Procedure ImportClassifierFromDirectory(Val DataDirectory)
	
	StateCodes = StateCodesForImport();
	
	// Checking file availability
	ImportParameters = New Structure("ImportSourceCode, ErrorField", ImportSourceCode, "ImportAddress");
	AnalysisResult = AddressClassifierClientServer.CheckForClassifierFilesAvailabilityInDirectory(StateCodes, DataDirectory, ImportParameters);
	If AnalysisResult.Errors <> Undefined Then
		// Files needed for import in selected modes are missing
		ClearMessages();
		CommonUseClientServer.ShowErrorsToUser(AnalysisResult.Errors);
		Return;
	EndIf;
	
	// Importing in background
	DeleteAfterSendingToServer = New Array;
	AnalysisResult.Insert("DeleteAfterSendingToServer", DeleteAfterSendingToServer);
	
	StartBackgroundImportFromClientDirectory(AnalysisResult);
EndProcedure

&AtClient
Procedure ImportClassifierFromITSDirectory(Val RootDirectory)
	StateCodes = StateCodesForImport();
	
	// Searching in the specified directory 
	DataDirectory = CommonUseClientServer.AddFinalPathSeparator(RootDirectory);
	PathSeparator = Right(DataDirectory, 1);
	
	DirectoryOptions = New Array;
	DirectoryOptions.Add(DataDirectory);
	DirectoryOptions.Add(DataDirectory + "EXE\CLASS\");
	DirectoryOptions.Add(DataDirectory + "1CIts\EXE\CLASS\");
	DirectoryOptions.Add(DataDirectory + "1CitsFr\EXE\CLASS\");
	DirectoryOptions.Add(DataDirectory + "1CItsB\EXE\CLASS\");
	
	ImportParameters = New Structure("ImportSourceCode, ErrorField", "ITS", "ImportAddress");
	HasErrors = True;
	
	For Each Option In DirectoryOptions Do
		AnalysisResult = AddressClassifierClientServer.CheckForClassifierFilesAvailabilityInDirectory(StateCodes, Option, ImportParameters);
		If AnalysisResult.AllFilesAvailable Then
			HasErrors = False;
			Break;
		EndIf;
	EndDo;
	
	If HasErrors Then
		Errors = Undefined;
		CommonUseClientServer.AddUserError(Errors, "ImportAddress", NStr("en = 'Import files not found in the specified 1C:ITS directory'") );
		
		ClearMessages();
		CommonUseClientServer.ShowErrorsToUser(Errors);
		Return;
	EndIf;
	
	// Importing in background, deleting excessive data
	StartBackgroundImportFromITSClientDirectory(AnalysisResult);
EndProcedure

&AtClient
Procedure ImportClassifierFromWebsite(Val Authentication = Undefined)
	
	StateCodes = StateCodesForImport();
	
	If Authentication = Undefined Then
		Authentication = SavedWebsiteAuthnticationData();
	EndIf;
	
	If IsBlankString(Authentication.Login) Then
		// No saved data found, moving to authorization form
		Notification = New NotifyDescription("ImportClassifierFromWebsiteAuthenticationRequest", ThisObject, New Structure);
		Notification.AdditionalParameters.Insert("StateCodes", StateCodes);
		
		OpenForm("InformationRegister.AddressClassifier.Form.AuthorizationOnSupportSite", , ThisObject, , , ,Notification);
		Return;
	EndIf;
	
	ImportClassifierFromWebsiteAuthentication(Authentication, StateCodes);
EndProcedure

// Ending authorization dialog
//
&AtClient
Procedure ImportClassifierFromWebsiteAuthenticationRequest(Val Authentication, Val AdditionalParameters) Export
	
	If TypeOf(Authentication) <> Type("Structure") Then
		// Going back to selection page
		Items.ImportSteps.CurrentPage = Items.SelectStatesForImport;
		Return;
		
	ElsIf IsBlankString(Authentication.Login) Then
		// Entering password once more
		ImportClassifierFromWebsite(Authentication);
		Return;
		
	EndIf;
	
	ImportClassifierFromWebsiteAuthentication(Authentication, AdditionalParameters.StateCodes);
EndProcedure

&AtClient
Procedure ImportClassifierFromWebsiteAuthentication(Val Authentication, Val StateCodes)
	
	ClearMessages();
	
	// Switching modes - page
	Items.ImportSteps.CurrentPage = Items.ImportWait;
	ImportStatusText = NStr("en = 'Importing files from the user support website...'");
	
	Items.CancelImport.Enabled = False;
	
	ClassifierBackgroundImportParameters = New Structure;
	ClassifierBackgroundImportParameters.Insert("Authentication", Authentication);
	ClassifierBackgroundImportParameters.Insert("StateCodes",   StateCodes);
	
	UsedClassifier = AddressClassifierClientServer.UsedAddressClassifier();
	If UsedClassifier <> "AC" Then
		Items.ImportSteps.CurrentPage = Items.SelectStatesForImport;
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Cannot process address classifier type ""%1""'"), UsedClassifier);
	EndIf;
	
	AttachIdleHandler("ImportClassifierFromACWebsite", 0.1, True);
EndProcedure

&AtClient
Procedure ImportClassifierFromACWebsite()
	
	StateCodes  = ClassifierBackgroundImportParameters.StateCodes;
	
	Authentication = New Structure;
	Authentication.Insert("UserCode", ClassifierBackgroundImportParameters.Authentication.Login);
	Authentication.Insert("Password",          ClassifierBackgroundImportParameters.Authentication.Password);
	
	// Clearing
	ClassifierBackgroundImportParameters = Undefined;
	
	// First file - abbreviations, validating authorization
	ImportDirectory = AddressClassifierClient.TemporaryClientDirectory();
	DeleteAfterSendingToServer = New Array;
	DeleteAfterSendingToServer.Add(ImportDirectory);
	
	Result = AddressClassifierClient.ImportACFromWebserver("SO", Authentication, ImportDirectory);
	If Not Result.Status Then
		// Import error, moving to authorization request once more
		CommonUseClientServer.MessageToUser(StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Importing AC data files from 1C website failed.
			         |%1'"), 
			Result.ErrorMessage));
			
		AddressClassifierClientServer.DeleteTempFile(ImportDirectory);
		
		Notification = New NotifyDescription("ImportClassifierFromWebsiteAuthenticationRequest", ThisObject, New Structure);
		Notification.AdditionalParameters.Insert("StateCodes", StateCodes);
		
		OpenForm("InformationRegister.AddressClassifier.Form.AuthorizationOnSupportSite", , ThisObject, , , ,Notification);
		Return;
	EndIf;

	FilesByState = New Map;
	
	ImportParameters = New Structure;
	ImportParameters.Insert("FilesByState", FilesByState);
	ImportParameters.Insert("StateCodes",    StateCodes);
	
	FilesByState.Insert("*", Result.Path);
	
	For Each StateCode In StateCodes Do
		ImportObject = Format(StateCode, "ND=2; NZ=; NLZ=");;
		Result = AddressClassifierClient.ImportACFromWebserver(ImportObject, Authentication, ImportDirectory);
		If Result.Status Then
			FilesByState.Insert(StateCode, Result.Path);
			
		Else
			CommonUseClientServer.MessageToUser(StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Importing AC data files from 1C website failed.
				         |%1'"), 
				Result.ErrorMessage));
			
			AddressClassifierClientServer.DeleteTempFile(ImportDirectory);
			Return;
		EndIf;
	EndDo;
	
	ImportParameters.Insert("Mode", "ACWebsite");
	ImportParameters.Insert("DeleteAfterSendingToServer", DeleteAfterSendingToServer);
	
	StartBackgroundImportFromClientDirectory(ImportParameters)
EndProcedure

&AtClient
Procedure StartBackgroundImportFromITSClientDirectory(Val ImportParameters)
	// Switching modes - page
	Items.ImportSteps.CurrentPage = Items.ImportWait;
	ImportStatusText = NStr("en = 'Extracting 1C:ITS files ...'");
	
	Items.CancelImport.Enabled = False;
	ClassifierBackgroundImportParameters = ImportParameters;
	AttachIdleHandler("StartBackgroundImportFromITSClientDirectoryContinuation", 0.1, True);
EndProcedure

&AtClient
Procedure StartBackgroundImportFromITSClientDirectoryContinuation()
	ImportParameters = ClassifierBackgroundImportParameters;
	ClassifierBackgroundImportParameters = Undefined;
	
	// AnalysisResult - valid source
	UsedClassifier = AddressClassifierClientServer.UsedAddressClassifier();
	If UsedClassifier = "AC" Then
		ExpectedMaskDuringExtraction = "*.DBF";
	Else
		Items.ImportSteps.CurrentPage = Items.SelectStatesForImport;
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Cannot process address classifier type ""%1""'"), UsedClassifier);
	EndIf;
	
	// Extracting files on client side (it is where the executable is located; no start permissions available for server)
	DeleteAfterSendingToServer = New Array;
	ImportParameters.Insert("DeleteAfterSendingToServer", DeleteAfterSendingToServer);
	
	For Each KeyValue In ImportParameters.FilesByState Do
		FileSource = KeyValue.Value;
		
		If TypeOf(FileSource) = Type("Array") Then
			Position = FileSource.UBound();
			While Position >= 0 Do
				FileName = FileSource[Position];
				If Upper(Right(FileName, 4)) = ".EXE" Then
					SupportData = ExtractITSArchive(FileName, ExpectedMaskDuringExtraction);
					FileSource[Position] = SupportData.FileName;
					DeleteAfterSendingToServer.Add(SupportData.DeletedFileName);
				EndIf;
				Position = Position - 1;
			EndDo;
		Else
			If Upper(Right(FileSource, 4)) = ".EXE" Then
			 	SupportData = ExtractITSArchive(FileSource, ExpectedMaskDuringExtraction);
				ImportParameters.FilesByState[KeyValue.Key] = SupportData.FileName;
				DeleteAfterSendingToServer.Add(SupportData.DeletedFileName);
			EndIf;
		EndIf;
		
	EndDo;
	
	// Initiating sending to server
	StartBackgroundImportFromClientDirectory(ImportParameters);
EndProcedure

&AtClient
Procedure StartBackgroundImportFromClientDirectory(Val ImportParameters)
	// Switching modes - page
	Items.ImportSteps.CurrentPage = Items.ImportWait;
	ImportStatusText = NStr("en = 'Sending files to application server...'");
	
	Items.CancelImport.Enabled = False;
	ClassifierBackgroundImportParameters = ImportParameters;
	AttachIdleHandler("StartBackgroundImportFromClientDirectoryContinuation", 0.1, True);
EndProcedure

&AtClient
Procedure StartBackgroundImportFromClientDirectoryContinuation()
	ImportParameters = ClassifierBackgroundImportParameters;
	ClassifierBackgroundImportParameters = Undefined;
	
	If ImportParameters = Undefined Then
		// Going back to selection page
		Items.ImportSteps.CurrentPage = Items.SelectStatesForImport;
		Return;
	EndIf;
		
	// Clearing files that could've been placed earlier
	If TypeOf(PlacedFiles) = Type("Array") Then
		For Each Details In PlacedFiles Do
			If Not IsBlankString(Details.Location) Then
				DeleteFromTempStorage(Details.Location);
			EndIf;
		EndDo;
		PlacedFiles.Clear();
	EndIf;
	
	// List of files to be sent to server
	FilesToBePlaced = New Array;
	For Each KeyValue In ImportParameters.FilesByState Do
		If TypeOf(KeyValue.Value) = Type("Array") Then
			For Each FileName In KeyValue.Value Do
				FilesToBePlaced.Add(New TransferableFileDescription(FileName) );
			EndDo;
		Else
			FilesToBePlaced.Add(New TransferableFileDescription(KeyValue.Value) );
		EndIf;
	EndDo;
	
	PlacedFiles = New Array;
	PutFiles(FilesToBePlaced, PlacedFiles, , False, UUID);
	
	// Saving change time - version
	For Position = 0 To PlacedFiles.UBound() Do
		Details = PlacedFiles[Position];
		
		FileData = New Structure("Name, Location");
		FillPropertyValues(FileData, Details);
		
		File = New File(Details.Name);
		FileData.Insert("ModificationTime", File.GetModificationUniversalTime());
		
		PlacedFiles[Position] = FileData;
	EndDo;
	
	// Deleting local temporary client files
	For Each FileName In ImportParameters.DeleteAfterSendingToServer Do
		AddressClassifierClientServer.DeleteTempFile(FileName);
	EndDo;
	
	// Starting background job to import data from the transmitted files
	If IsTempStorageURL(LongActionParameters.ResultAddress) Then
		DeleteFromTempStorage(LongActionParameters.ResultAddress);
	EndIf;
	LongActionParameters.ResultAddress = Undefined;
	
	Mode = Undefined;
	ImportParameters.Property("Mode", Mode);
	
	StartBackgroundImportAtServer(ImportParameters.StateCodes, PlacedFiles, Mode);
	AttachIdleHandler("Attachable_LongActionWait", 0.1, True);
EndProcedure

&AtServer
Procedure StartBackgroundImportAtServer(Val StateCodes, Val ImportFileDescription, Val Mode = Undefined)
	MethodParameters = New Array;
	MethodParameters.Add(StateCodes);
	
	// Converting files to binary data - storage cannot be shared with the background job session
	FileDescription = New Array;
	For Each Details In ImportFileDescription Do
		
		FileData = New Structure("Name, ModificationTime");
		FillPropertyValues(FileData, Details);
		FileData.Insert("Location", GetFromTempStorage(Details.Location));
		
		FileDescription.Add(FileData);
	EndDo;
	MethodParameters.Add(FileDescription);
	
	MethodParameters.Add(Mode);
	
	LongActionParameters.ID   = Undefined;
	LongActionParameters.Completed       = True;
	LongActionParameters.ResultAddress = Undefined;
	LongActionParameters.Error          = Undefined;
	
	Try
		StartResult = LongActions.ExecuteInBackground(
			UUID,
			"AddressClassifier.AddressClassifierImportBackgroundJob",
			MethodParameters,
			NStr("en = 'Importing address classifier'")
		);
	Except
		LongActionParameters.Error = DetailErrorDescription( ErrorInfo() );
		Return;
		
	EndTry;
	
	LongActionParameters.ID   = StartResult.JobID;
	LongActionParameters.Completed       = StartResult.JobCompleted;
	LongActionParameters.ResultAddress = StartResult.StorageAddress;
	
	// Executing 
	Items.CancelImport.Enabled = True;
EndProcedure

&AtServer
Function BackgroundJobState()
	Result = New Structure("Progress, Completed, Error");
	
	Result.Error = "";
	If LongActionParameters.ID = Undefined Then
		Result.Completed = True;
		Result.Progress  = Undefined;
		Result.Error    = LongActionParameters.Error;
	Else
		Try
			Result.Completed = LongActions.JobCompleted(LongActionParameters.ID);
			Result.Progress  = LongActions.ReadProgress(LongActionParameters.ID);
		Except
			Result.Error = DetailErrorDescription( ErrorInfo() );
		EndTry
	EndIf;
	
	Return Result;
EndFunction

&AtServerNoContext
Procedure CancelBackgroundJob(Val ID)
	
	If ID <> Undefined Then
		Try
			LongActions.CancelJobExecution(ID);
		Except
			// No action required, event log record already created
		EndTry
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_LongActionWait()
	
	// Updating status
	State = BackgroundJobState();
	If Not IsBlankString(State.Error) Then
		// Job failed; generating message and going back to the initial page
		Items.ImportSteps.CurrentPage = Items.SelectStatesForImport;
		Message(State.Error);
		Return;
		
	ElsIf State.Completed Then
		Items.ImportSteps.CurrentPage = Items.NoErrors;
		ImportDescriptionText = NStr("en = 'Address classifier imported.'");
		
		Notify("AddressClassifierImported", , ThisObject);
		
		Items.Close.DefaultButton = True;
		CurrentItem = Items.Close;
		FormClosingConfirmation = True;
		Return;
		
	EndIf;
	
	// Process continues running
	If TypeOf(State.Progress) = Type("Structure") Then
		ImportStatusText = State.Progress.Text;
	EndIf;
	AttachIdleHandler("Attachable_LongActionWait", LongActionParameters.IdleInterval, True);
	
EndProcedure

&AtClient
Function StateCodesForImport()
	Result = New Array;
	
	For Each State In Regions.FindRows( New Structure("Import", True) ) Do
		Result.Add(State.RegionCode);
	EndDo;
	
	Return Result;
EndFunction

&AtClient
Function ExtractITSArchive(Val FullFileName, Val ExpectedMask)
	
	ClientDirectory = AddressClassifierClient.TemporaryClientDirectory();

	Command = """" + FullFileName + """ -s -d """ + ClientDirectory + """";
	RunApp(Command, ClientDirectory, True);
	
	// Returning the first file conforming to the expected mask
	Found = AddressClassifierClientServer.FindFile(ClientDirectory, ExpectedMask);
	If Not Found.Exist Then
		Items.ImportSteps.CurrentPage = Items.SelectStatesForImport;
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = '""%1"" file extraction error, expected content not received'"), FullFileName);
	EndIf;
		
	Result = New Structure;
	Result.Insert("FileName", Found.FullName);
	Result.Insert("DeletedFileName", ClientDirectory);
	
	Return Result;
EndFunction

&AtServerNoContext
Function SavedWebsiteAuthnticationData()
	
	Return AddressClassifier.WebsiteAuthenticationParameters();
	
EndFunction

#EndRegion
