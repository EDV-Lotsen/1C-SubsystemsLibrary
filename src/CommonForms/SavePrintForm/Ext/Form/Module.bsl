
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	// Filling the list of formats
	For Each SavingFormat In PrintManagement.SpreadsheetDocumentStorageFormatSettings() Do
		SelectedStorageFormats.Add(SavingFormat.SpreadsheetDocumentFileType, String(SavingFormat.Ref), False, SavingFormat.Picture);
	EndDo;
	SelectedStorageFormats[0].Check = True; // By default only the first format from the list is selected
	
	// Filling the selection list for attaching files to objects 
	For Each PrintObject In Parameters.PrintObjects Do
		If YouCanAttachFilesToObject(PrintObject.Value) Then
			Items.SelectedObject.ChoiceList.Add(PrintObject.Value);
		EndIf;
	EndDo;
	
	// Default storage
	StorageOption = "SaveToFolder";
	
	// Default object for attaching files
	If Items.SelectedObject.ChoiceList.Count() > 0 Then
		SelectedObject = Items.SelectedObject.ChoiceList[0].Value;
	Else
		Items.StorageOption.Visible = False;
		Items.FileStorageFolder.TitleLocation = FormItemTitleLocation.Top;
	EndIf;
	
	Items.SelectedObject.ReadOnly = Items.SelectedObject.ChoiceList.Count() = 1;
EndProcedure

&AtServer
Procedure BeforeLoadDataFromSettingsAtServer(Settings)
	
	SavingFormatsFromSettings = Settings["SelectedStorageFormats"];
	If SavingFormatsFromSettings <> Undefined Then
		For Each SelectedFormat In SelectedStorageFormats Do 
			FormatFromSettings = SavingFormatsFromSettings.FindByValue(SelectedFormat.Value);
			If FormatFromSettings <> Undefined Then
				SelectedFormat.Check = FormatFromSettings.Check;
			EndIf;
		EndDo;
		Settings.Delete("SelectedStorageFormats");
	EndIf;
	
	If Items.SelectedObject.ChoiceList.Count() = 0 Then
		StorageOptionSetting = Settings["StorageOption"];
		If StorageOptionSetting <> Undefined Then
			Settings.Delete("StorageOption");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	SetSavingPlacePage();
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure StorageOptionOnChange(Item)
	SetSavingPlacePage();
	ClearMessages();
EndProcedure

&AtClient
Procedure FileStorageFolderChoiceStart(Item, ChoiceData, StandardProcessing)
	FolderSelectionDialog = New FileDialog(FileDialogMode.ChooseDirectory);
	If Not IsBlankString(SelectedFolder) Then
		FolderSelectionDialog.Directory = SelectedFolder;
	EndIf;
	If FolderSelectionDialog.Choose() Then
		SelectedFolder = FolderSelectionDialog.Directory;
		ClearMessages();
	EndIf;
EndProcedure

&AtClient
Procedure SelectedObjectClearing(Item, StandardProcessing)
	StandardProcessing = False;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Save(Command)
	
	#If Not WebClient Then
	If StorageOption = "SaveToFolder" And IsBlankString(SelectedFolder) Then
		CommonUseClientServer.MessageToUser(NStr("en = 'Specify the folder.'"),,"SelectedFolder");
		Return;
	EndIf;
	#EndIf
		
	SavingFormats = New Array;
	
	For Each SelectedFormat In SelectedStorageFormats Do
		If SelectedFormat.Check Then
			SavingFormats.Add(SelectedFormat.Value);
		EndIf;
	EndDo;
	
	If SavingFormats.Count() = 0 Then
		ShowMessageBox(,NStr("en = 'Specify at least one of the suggested formats.'"));
		Return;
	EndIf;
	
	ChoiceResult = New Structure;
	ChoiceResult.Insert("PackToArchive", PackToArchive);
	ChoiceResult.Insert("SavingFormats", SavingFormats);
	ChoiceResult.Insert("StorageOption", StorageOption);
	ChoiceResult.Insert("SavingFolder", SelectedFolder);
	ChoiceResult.Insert("ObjectForAttaching", SelectedObject);
	
	NotifyChoice(ChoiceResult);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure SetSavingPlacePage()
	
	#If WebClient Then
	Items.StorageLocationsGroup.CurrentPage = Items.AttachToObjectPage;
	Items.SelectedObject.Enabled = StorageOption = "Attach";
	#Else
	If StorageOption = "Attach" Then
		Items.StorageLocationsGroup.CurrentPage = Items.AttachToObjectPage;
	Else
		Items.StorageLocationsGroup.CurrentPage = Items.SaveToFolderPage;
	EndIf;
	#EndIf
	
EndProcedure

&AtServer
Function YouCanAttachFilesToObject(ObjectRef)
	Result = Undefined;
	
	PrintManagement.OnCheckCanAttachFilesToObject(ObjectRef, Result);
	
	If Result = Undefined Then
		Result = False;
	EndIf;
	
	Return Result;
EndFunction

#EndRegion
