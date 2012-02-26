

////////////////////////////////////////////////////////////////////////////////
// Block of event handlers
//

// Handler of form event "on create at server".
// Fills choice list of address units for loading.
//
&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	AddressClassifierUnitsTransmitted = ?(Parameters.Property("AddressClassifierUnits"), Parameters.AddressClassifierUnits, Undefined);
	
	FillAddressClassifierUnitsTable(AddressClassifierUnitsTransmitted);
	
	DataSourceForLoad = 0;
	PathToDataFilesOnDrive = "";
	ITSDisc = "";
	
	If AddressClassifierUnitsTransmitted = Undefined Then
		LoadSavedLoadParameters();
	Else
		DataSourceForLoad = 1;
	EndIf;
	
EndProcedure

// Handler of form events "on open"
// Call interface update code
//
&AtClient
Procedure OnOpen(Cancellation)
	
	#If WebClient Then
		DoMessageBox(NStr("en = 'Classifier cannot be loaded using the Web Client'"),, NStr("en = 'Loading address classificator'"));
		Close();
	#EndIf
	
	SetChangesInInterface();
	
EndProcedure

// Handler of click event of button "SelectAll"
// of command bar of form item "AddressClassifierUnitsForLoad"
// Select all address units in the list of address units for loading
//
&AtClient
Procedure SelectAllRun()
	
	For Each AddressClassifierUnit In AddressClassifierUnitsForLoad Do
		AddressClassifierUnit.Check = True;
	EndDo;
	
	SetChangesInInterface();
	
EndProcedure

// Handler of click event of button "CancelSelectAll"
// of command bar of form item "AddressClassifierUnitsForLoad"
// Deselect all address units in the list
// of address units for loading
//
&AtClient
Procedure CancelSelectAllRun()
	
	For Each AddressClassifierUnit In AddressClassifierUnitsForLoad Do
		AddressClassifierUnit.Check = False;
	EndDo;
	
	SetChangesInInterface();
	
EndProcedure

// Handler of event StartChoice of the form input field PathToDataFilesOnDrive.
// Calls directory choice dialog, checks after choice, if there exist
// data files in the selected directory.
//
&AtClient
Procedure PathToFilesDataOnDriveStartChoice(Item, ChoiceData, StandardProcessing)
	
#If Not WebClient Then
	FileOpenDialog = New FileDialog(FileDialogMode.ChooseDirectory);
	FileOpenDialog.Title = NStr("en = 'Select directory with data files folder'");
	FileOpenDialog.Directory = PathToDataFilesOnDrive;
	
	If FileOpenDialog.Choose() Then
		PathToDataFilesOnDrive = FileOpenDialog.Directory;
		
		ClearMessages();
		
		If AddressClassifierClient.CheckExistenceOfDataFilesDataInDirectory(PathToDataFilesOnDrive) Then
			SetChangesInInterface ();
		Else
			CommonUseClientServer.MessageToUser(
						StringFunctionsClientServer.SubstitureParametersInString(
							NStr("en = 'Data files not found in %1 directory.'"),
							PathToDataFilesOnDrive), ,
						"PathToDataFilesOnDrive");
		EndIf;
	EndIf;
#Else
	DoMessageBox(NStr("en = 'This functionality is not supported on the Web Client'"));
#EndIf
	
EndProcedure

// Handler of event StartChoice of input field of form ITSDisc.
// Calls directory choice dialog, checks after choice, if there exist
// data archive files in the selected directory.
//
&AtClient
Procedure ITSDiscStartChoice(Item, ChoiceData, StandardProcessing)
	
#If Not WebClient Then
	FileOpenDialog = New FileDialog(FileDialogMode.ChooseDirectory);
	FileOpenDialog.Title = "Choose path to ITS disk";
	FileOpenDialog.Directory = ITSDisc;
	
	If FileOpenDialog.Choose() Then
		ITSDisc = FileOpenDialog.Directory;
		
		FilesExist = AddressClassifierClient.CheckExistenceOfFilesOnITSDisc(ITSDisc);
		
		ClearMessages();
		
		If FilesExist Then
			SetChangesInInterface();
		Else
			CommonUseClientServer.MessageToUser(
				StringFunctionsClientServer.SubstitureParametersInString(
							NStr("en = 'Classifier data files are not found: %1.
                                  |Check the path to the ITS Disk.'"),
								 ITSDisc), ,
								 "ITSDisc");
		EndIf;
	EndIf;
#Else
	DoMessageBox(NStr("en = 'This functionality is not supported on the Web Client.'"));
#EndIf
	
EndProcedure

// Handler of choice event of table field "AddressClassifierUnit"
// Changes load status of the filed address unit to the opposite status
//
&AtClient
Procedure AddressClassifierUnitsTableSelection(Item, RowSelected, Field, StandardProcessing)
	
	Item.CurrentData.Check = NOT Item.CurrentData.Check;
	
EndProcedure

// Handler of event OnChange of radio button field DataSourceForLoad
// Assigns visibility parameters of the items (load kind parameters)
// depending on the radio button value.
//
&AtClient
Procedure LoadMethodOnChange(Item)
	
	SetChangesInInterface();
	
EndProcedure

// Handler of click event of button "Load" of the form command bar
//
&AtClient
Procedure LoadExecute()
	
	ClearMessages();
	
	If LoadClassifier() Then
		Status(NStr("en = 'Address classifier loaded successefully'"));
		Notify("AddressClassifierUpdate");
		SaveParametersOfLoad();
		Close(True);
	EndIf;
	
	SetLoadStatus("");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Loading wizard control

// Handler of the click event on button "NextStep"
//
&AtClient
Procedure CommandNext(Command)
	
	ClearMessages();
	
	If      Items.FormPages.CurrentPage = Items.PageAddressClassifierUnitsChoice Then
		If NumberOfMarkedAddressClassifierUnits() = 0 Then
			CommonUseClientServer.MessageToUser(
						NStr("en = 'You have to select at least one address classifier unit.'"), ,
						"AddressClassifierUnitsForLoad");
			Return;
		EndIf;
		Items.FormPages.CurrentPage = Items.PageSourceChoice;
	ElsIf Items.FormPages.CurrentPage = Items.PageSourceChoice Then
		If DataSourceForLoad = 2
			And (IsBlankString(ITSDisc)
				OR NOT AddressClassifierClient.CheckExistenceOfFilesOnITSDisc(ITSDisc))Then
				CommonUseClientServer.MessageToUser(
							NStr("en = 'Please check if the path to ITS disc is correct.'"), ,
							"ITSDisc");
			Return;
		ElsIf  DataSourceForLoad = 3
			And (IsBlankString(PathToDataFilesOnDrive)
				OR NOT AddressClassifierClient.CheckExistenceOfDataFilesDataInDirectory(PathToDataFilesOnDrive))Then
				CommonUseClientServer.MessageToUser(
							NStr("en = 'Please check if path to the Address Classifier files is correct and all files present'"), ,
							"PathToDataFilesOnDrive");
			Return;
		EndIf;
		Items.FormPages.CurrentPage = Items.PageLoad;
	EndIf;
	
	SetChangesInInterface();
	
EndProcedure

// Handler of the click event on button "Back"
//
&AtClient
Procedure CommandBack(Command)
	
	If Items.FormPages.CurrentPage = Items.PageSourceChoice Then
		Items.FormPages.CurrentPage = Items.PageAddressClassifierUnitsChoice;
	ElsIf Items.FormPages.CurrentPage = Items.PageLoad Then
		Items.FormPages.CurrentPage = Items.PageSourceChoice;
	EndIf;
	
	SetChangesInInterface();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Block of service functions
//

&AtServer
Procedure SaveParametersOfLoad()
	
	LoadedAOArray = New Array;
	
	For Each ItemAO In AddressClassifierUnitsForLoad Do
		If ItemAO.Check Then
			LoadedAOArray.Add(Left(ItemAO.Description, 2));
		EndIf;
	EndDo;
	
	CommonSettingsStorage.Save("ParametersOfLoadOfAddressClassifier", "LoadableRegions", LoadedAOArray);
	
	SourceClassifier = New Structure("DataSourceForLoad");
	SourceClassifier.DataSourceForLoad = DataSourceForLoad;
	
	If      DataSourceForLoad = 2 Then
		SourceClassifier.Insert("ITSDisc", ITSDisc);
	ElsIf DataSourceForLoad = 3 Then
		SourceClassifier.Insert("PathToDataFilesOnDrive", PathToDataFilesOnDrive);
	EndIf;
	
	CommonSettingsStorage.Save("ParametersOfLoadOfAddressClassifier", "SourceClassifier", SourceClassifier);
	
EndProcedure

&AtServer
Procedure LoadSavedLoadParameters()
	
	SourceClassifier = LoadClassifierLoadSettings("SourceClassifier");
	
	If SourceClassifier <> Undefined Then
		DataSourceForLoad = SourceClassifier.DataSourceForLoad;
		If DataSourceForLoad = 2 Then
			ITSDisc = SourceClassifier.ITSDisc;
		ElsIf DataSourceForLoad = 3 Then
			PathToDataFilesOnDrive = SourceClassifier.PathToDataFilesOnDrive;
		EndIf;
	EndIf;
	
EndProcedure

// Obtains value from IB settings system storage
//
&AtServerNoContext
Function LoadClassifierLoadSettings(SettingsKey)
	
	Return CommonSettingsStorage.Load("ParametersOfLoadOfAddressClassifier", SettingsKey);
	
EndFunction

// Assigns text load status
//
&AtClient
Procedure SetLoadStatus(Val Message = "")
	
	LoadStatus = Message;
	
	If IsBlankString(Message) Then
		Items.LoadPages.CurrentPage = Items.GroupEmptyGroup;
	Else
		Items.LoadPages.CurrentPage = Items.PageLoadStatus;
	EndIf;
	
	RefreshDataRepresentation();
	
EndProcedure

// Classifier loading implementation
//
&AtClient
Function LoadClassifier()
	
	// If authentication is required at user web-site
	Var AuthenticationFormQuery, AuthenticationData, DataPath;
	
	LoadIndicator = 0;
	
	ReturnValue = True;
	
	If DataSourceForLoad = 2 Then // load from ITS disc
		If Right(ITSDisc, 1) <> "\" Then
			ITSDisc = ITSDisc + "\";
		EndIf;
	ElsIf DataSourceForLoad = 3 Then // load from files on drive
		If Right(PathToDataFilesOnDrive, 1) <> "\" Then
			PathToDataFilesOnDrive = PathToDataFilesOnDrive + "\";
		EndIf;
	EndIf;
	
	// Prepare the array of address units for loading
	AddressClassifierUnits = New Array;
	
	For Each AddressClassifierUnit In AddressClassifierUnitsForLoad Do
		If AddressClassifierUnit.Check Then
			AddressClassifierUnits.Add(Left(AddressClassifierUnit.Description, 2));
		EndIf;
	EndDo;
	
	Try
		// First stage - load adapted Classifier database to the server.
		// Depending on the method choice load is processed in different ways.
		
		If DataSourceForLoad = 1 Then // load from 1C user site
			If Not GetAuthenticationData(AuthenticationData, AuthenticationFormQuery) Then
				Return False;
			EndIf;
			
			Status(NStr("en = 'Loading the Address Classifier'"));
			
			Result = LoadAddressClassifierUnitsFromServer(AddressClassifierUnits, AuthenticationData, DataPath);
			
			If Not Result.Status And Not AuthenticationFormQuery Then
				If Not GetAuthenticationData(AuthenticationData, AuthenticationFormQuery, True) Then
					Return False;
				EndIf;
				Result = LoadAddressClassifierUnitsFromServer(AddressClassifierUnits, AuthenticationData, DataPath);
			EndIf;
			
			If Not Result.Status Then
				Raise Result.MessageAboutError;
			EndIf;
			
			If Right(DataPath, 1) <> "\" Then
				DataPath = DataPath + "\";
			EndIf;
			
		ElsIf DataSourceForLoad = 2 Then // load from ITS disk
			Status(NStr("en = 'Uploading the Address Classifier'"));
			SetLoadStatus(NStr("en = 'Reformatting to normalize files from ITS disc'"));
			DataPath = AddressClassifierClient.ConvertFilesClassifierEXEToZIP(ITSDisc);
			If DataPath = Undefined Then
				CommonUseClientServer.MessageToUser(NStr("en = 'The Address Classifier uploading was cancelled'"));
				Return False;
			EndIf;
			LoadIndicator = 25;
		ElsIf DataSourceForLoad = 3 Then // load from files on drive
			Status(NStr("en = 'Uploading the Address Classifier'"));
			SetLoadStatus(NStr("en = 'Compress files before transferring to the server'"));
			FilesArrayForLoad = AddressClassifierClient.DataFileList();
			For Each FileName In FilesArrayForLoad Do
				AddressClassifierClient.CompressFile(PathToDataFilesOnDrive, FileName, DataPath);
				LoadIndicator = (FilesArrayForLoad.Find(FileName)+1) * 25 / FilesArrayForLoad.Count();
				RefreshDataRepresentation();
			EndDo;
		EndIf;
		
		RefreshDataRepresentation();
		
		// Second stage - transfer files to 1C:Enterprise server
		SetLoadStatus(NStr("en = 'Transfer files to 1C:Enterprise server'"));
		
		If DataSourceForLoad = 1 Then
			
			DataPathAtServer = Undefined;
			
			For Each Unit In AddressClassifierUnits Do
				AddressClassifierClient.TransferFilesToServerByAddressClassifierUnits(
				           DataPath, DataPathAtServer, Unit,
				           ? (AddressClassifierUnits.Find(Unit) > 0, False, True));
				LoadIndicator = 25 + (AddressClassifierUnits.Find(Unit)+1) * 25 / AddressClassifierUnits.Count();
				RefreshDataRepresentation();
			EndDo;
			
			AddressClassifierClient.TransferFileToServer(DataPath, "abbrbase.zip", DataPathAtServer);
			AddressClassifierClient.TransferFileToServer(DataPath, "altnames.zip", DataPathAtServer);
			
		Else
			
			DataPathAtServer = Undefined;
			
			FilesArrayForLoad = AddressClassifierClient.DataFileList();
			For Each FileName In FilesArrayForLoad Do
				AddressClassifierClient.TransferFileToServer(DataPath, FileName, DataPathAtServer);
				LoadIndicator = 25 + (FilesArrayForLoad.Find(FileName)+1) * 25 / FilesArrayForLoad.Count();
				RefreshDataRepresentation();
			EndDo;
			
		EndIf;
		
		// Third stage - load address information into information register.
		// It is supposed that at the moment all the required data files are present
		// at server in directory DataPathAtServer
		
		For Each Unit In AddressClassifierUnits Do
			
			AddressInfo = AddressClassifier.InformationAboutAddressUnit(Unit);
			
			SetLoadStatus(
				StringFunctionsClientServer.SubstitureParametersInString(
					NStr("en = 'Loading data for object: %1 %2'"),
					AddressInfo.Description,
					AddressInfo.Abbreviation));
			AddressClassifier.LoadClassifierByAddressUnit(Unit,
															DataPathAtServer,
															DataSourceForLoad = 1);
			LoadIndicator = 50 + (AddressClassifierUnits.Find(Unit)+1) * 50 / AddressClassifierUnits.Count();
			RefreshDataRepresentation();
		EndDo;
		
		SetLoadStatus(NStr("en = 'Loading address abbreviations'"));
		AddressClassifier.LoadAddressAbbreviations(DataPathAtServer);
		
		If DataSourceForLoad = 1 Then
			AddressClassifierClientServer.GetFileVersionsAndRefreshAddressInfoVersion(AddressClassifierUnits);
		EndIf;
	
	Except
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Error while loading the address information: '")
			+ BriefErrorDescription(ErrorInfo()));
		ReturnValue = False;
	EndTry;
	
	CommonUseClientServer.DeleteFilesInDirectory(DataPath);
	
	CommonUse.DeleteFilesAt1CEnterpriseServer(DataPathAtServer);
	
	Return ReturnValue;
	
EndFunction

&AtClient
Function GetAuthenticationData(AuthenticationData, AuthenticationFormQuery, Val QueryToUser = False)
	
	Var Login, Password;
	
	AuthenticationFormQuery = False;
	
	If QueryToUser Or Not AddressClassifier.GetAuthenticationParameters(Login, Password) Then
		AuthenticationFormQuery = True;
		SetLoadStatus(NStr("en = '1C user site authentication'"));
		Result = OpenFormModal("InformationRegister.AddressClassifier.Form.AuthenticationAtUsersWebsite");
		If Result = Undefined OR TypeOf(Result) = Type("DialogReturnCode") Then
			Return False;
		Else
			Login = Result.Login;
			Password          = Result.Password;
		EndIf;
	EndIf;
	
	AuthenticationData = New Structure("Login ,Password", Login, Password);
	
	Return True;
	
EndFunction

&AtClient
Function LoadAddressClassifierUnitsFromServer(Val AddressClassifierUnits, Val AuthenticationData, DataPath)
	
	For Each Unit In AddressClassifierUnits Do
		AddressInfo = AddressClassifier.InformationAboutAddressUnit(Unit);
		SetLoadStatus(
		    StringFunctionsClientServer.SubstitureParametersInString(
		            NStr("en = 'Loading files from 1C web server: %1 %2'"),
		                AddressInfo.Description,
		                AddressInfo.Abbreviation));
		
		Result = AddressClassifierClient.LoadClassifierFromWebServer(
		                Unit,
		                AuthenticationData,
		                DataPath);
		If Not Result.Status Then
			Break;
		EndIf;
		LoadIndicator = (AddressClassifierUnits.Find(Unit)+1) * 25 / AddressClassifierUnits.Count();
	EndDo;
	
	Return Result;
	
EndFunction

// Fill passed value table using values of address units table.
// Select code, description and object type abbreviation.
//
&AtServer
Procedure FillAddressClassifierUnitsTable(SpecifiedRegionsForLoad)
	
	LoadedAOArray = LoadClassifierLoadSettings("LoadableRegions");
	
	AddressClassifierUnitsForLoad.Clear();
	
	AddressClassifierUnitsClassifierXML =
		InformationRegisters.AddressClassifier.GetTemplate("AddressClassifierUnits").GetText();
	
	ClassifierTable = CommonUse.ReadXMLToTable(AddressClassifierUnitsClassifierXML).Data;
	
	For Each Unit In ClassifierTable Do
		
		Description = Left(Unit.Code, 2) + " - " + Unit.Name + " " + Unit.Abbreviation;
		
		NewRow = AddressClassifierUnitsForLoad.Add();
		NewRow.Description = Description;
		
		If      SpecifiedRegionsForLoad <> Undefined Then
			If SpecifiedRegionsForLoad.Find(Left(Unit.Code, 2)) <> Undefined Then
				NewRow.Check = True;
			Else
				NewRow.Check = False;
			EndIf;
		ElsIf LoadedAOArray <> Undefined Then
			If LoadedAOArray.Find(Left(Unit.Code, 2)) <> Undefined Then
				NewRow.Check = True;
			Else
				NewRow.Check = False;
			EndIf;
		Else
			NewRow.Check = False;
		EndIf;
		
	EndDo;
	
EndProcedure

// Returns the number of marked address units
//
&AtClient
Function NumberOfMarkedAddressClassifierUnits()
	
	NumberOfMarkedAddressClassifierUnits = 0;
	
	For Each AddressClassifierUnit In AddressClassifierUnitsForLoad Do
		If AddressClassifierUnit.Check Then
			NumberOfMarkedAddressClassifierUnits = NumberOfMarkedAddressClassifierUnits + 1;
		EndIf;
	EndDo;
	
	Return NumberOfMarkedAddressClassifierUnits;
	
EndFunction

// Depending on the current page procedure modifies fields accessibility for a user
//
&AtClient
Procedure SetChangesInInterface()
	
	DataSourceForLoadSelected = DataSourceForLoadSelected();
	NumberOfMarkedAddressClassifierUnits = NumberOfMarkedAddressClassifierUnits();
	
	If Items.FormPages.CurrentPage = Items.PageAddressClassifierUnitsChoice Then
		Items.Back.Enabled = False;
		Items.NextStep.Enabled = True;
	ElsIf Items.FormPages.CurrentPage = Items.PageSourceChoice Then
		Items.Back.Enabled = True;
		Items.NextStep.Enabled = True;
		
		If DataSourceForLoad = 0 Then
			DataSourceForLoad = 1;
		EndIf;
		
		If		DataSourceForLoad = 2 Then
			Items.LoadMethodPages.CurrentPage = Items.PageLoadFromDiskITS;
		ElsIf	DataSourceForLoad = 3 Then
			Items.LoadMethodPages.CurrentPage = Items.PageLoadFiles;
		Else
			Items.LoadMethodPages.CurrentPage = Items.EmptyPage;
		EndIf;
	ElsIf Items.FormPages.CurrentPage = Items.PageLoad Then
		Items.Back.Enabled = True;
		Items.NextStep.Enabled = False;
	EndIf;
	
EndProcedure

&AtClient
Function DataSourceForLoadSelected()
	
	SourceSelected = False;
	
	If DataSourceForLoad = 1 Then
		SourceSelected = True;
	ElsIf DataSourceForLoad = 2 Then
		If AddressClassifierClient.CheckExistenceOfFilesOnITSDisc(ITSDisc) Then
			SourceSelected = True;
		EndIf;
	ElsIf DataSourceForLoad = 3 Then
		If AddressClassifierClient.CheckExistenceOfDataFilesDataInDirectory(PathToDataFilesOnDrive) Then
			SourceSelected = True;
		EndIf;
	EndIf;
	
	Return SourceSelected;
	
EndFunction
