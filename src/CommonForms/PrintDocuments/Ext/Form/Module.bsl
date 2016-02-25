#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Var PrintFormCollection;
	
	SetConditionalAppearance();
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then
 		Return;
	EndIf;
	
	// Checking input parameters
	If Not ValueIsFilled(Parameters.DataSource) Then 
		CommonUseClientServer.Validate(TypeOf(Parameters.CommandParameter) = Type("Array") Or CommonUse.ReferenceTypeValue(Parameters.CommandParameter),
			StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Invalid CommandParameter parameter value in the PrintManagementClient.ExecutePrintCommand method call.
				|Expected type: Array, AnyRef.
				|Actual type: %1'"), TypeOf(Parameters.CommandParameter)));
	EndIf;

	// Support of backward compatibility with version 2.1.3
	PrintParameters = Parameters.PrintParameters;
	If Parameters.PrintParameters = Undefined Then
		PrintParameters = New Structure;
	EndIf;
	If Not PrintParameters.Property("AdditionalParameters") Then
		Parameters.PrintParameters = New Structure("AdditionalParameters", PrintParameters);
		For Each PrintParameter In PrintParameters Do
			Parameters.PrintParameters.Insert(PrintParameter.Key, PrintParameter.Value);
		EndDo;
	EndIf;
	
	GeneratePrintForms(PrintFormCollection, Parameters.TemplateNames, Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	CreateAttributesAndFormItemsForPrintForms(PrintFormCollection);
	SaveDefaultBatchSettings();
	ImportCopyCountSettings();
	HasAllowedOutput = HasAllowedOutput();
	SetUpFormItemVisibility(HasAllowedOutput);
	SetOutputAvailabilityFlagInPrintFormPresentations(HasAllowedOutput);
	SetPrinterNameInPrintButtonTooltip();
	SetFormTitle();
	If IsBatchPrinting() Then
		Items.Copies.Title = NStr("en = 'Batch copies'");
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If ValueIsFilled(StorageFormatSettings) Then
		Cancel = True; // Cancel the form opening
		SavePrintFormToFile();
	EndIf;
	SetCurrentPage();
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("CommonForm.SavePrintForm") Then
		
		If SelectedValue <> Undefined And SelectedValue <> DialogReturnCode.Cancel Then
			FilesInTempStorage = PutSpreadsheetDocumentsToTempStorage(SelectedValue);
			If SelectedValue.StorageOption = "SaveToFolder" Then
				SavePrintFormsToFolder(FilesInTempStorage, SelectedValue.SavingFolder);
			Else
				AttachPrintFormsToObject(FilesInTempStorage, SelectedValue.ObjectForAttaching);
				Status(NStr("en = 'Saved.'"));
			EndIf;
		EndIf;
		
	ElsIf Upper(ChoiceSource.FormName) = Upper("CommonForm.SelectAttachmentFormat")
		Or Upper(ChoiceSource.FormName) = Upper("CommonForm.ComposeNewMessage") Then
		
		If SelectedValue <> Undefined And SelectedValue <> DialogReturnCode.Cancel Then
			AttachmentList = PutSpreadsheetDocumentsToTempStorage(SelectedValue);
			SendingParameters = OutputParameters.SendingParameters;
			Recipients = SendingParameters.Recipient;
			If SelectedValue.Property("Recipients") Then
				Recipients = SelectedValue.Recipients;
			EndIf;
			
			NewEmailMessageParameters = New Structure;
			NewEmailMessageParameters.Insert("Recipient", Recipients);
			NewEmailMessageParameters.Insert("Subject", SendingParameters.Subject);
			NewEmailMessageParameters.Insert("Text", SendingParameters.Text);
			NewEmailMessageParameters.Insert("Attachments", AttachmentList);
			NewEmailMessageParameters.Insert("DeleteFilesAfterSending", True);
			
			EmailOperationsClientModule = CommonUseClient.CommonModule("EmailOperationsClient");
			EmailOperationsClientModule.CreateNewEmailMessage(NewEmailMessageParameters);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If Not IsBlankString(SettingsKey) Then
		PrintFormSettingsToSave = New Array;
		For Each PrintFormSettingsItem In PrintFormSettings Do
			SettingsItemToSave = New Structure;
			SettingsItemToSave.Insert("TemplateName", PrintFormSettingsItem.TemplateName);
			SettingsItemToSave.Insert("Count", ?(PrintFormSettingsItem.Print,PrintFormSettingsItem.Count, 0));
			SettingsItemToSave.Insert("DefaultPosition", PrintFormSettingsItem.DefaultPosition);
			
			PrintFormSettingsToSave.Add(SettingsItemToSave);
		EndDo;
		
		SavePrintFormSettings(SettingsKey, PrintFormSettingsToSave);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	PrintFormSettingsItem = PrintFormCurrentSettings();
	
	If EventName = "Write_UserPrintTemplates" 
		And Source.FormOwner = ThisObject
		And Parameter.TemplateMetadataObjectName = PrintFormSettingsItem.PathToTemplate Then
			AttachIdleHandler("RefreshCurrentPrintForm",0.1,True);
	ElsIf (EventName = "CancelTemplateChange"
		Or EventName = "CancelSpreadsheetDocumentEditing"
		And Parameter.TemplateMetadataObjectName = PrintFormSettingsItem.PathToTemplate)
		And Source.FormOwner = ThisObject Then
			DisplayCurrentPrintFormState();
	ElsIf EventName = "Write_SpreadsheetDocument" 
		And Parameter.TemplateMetadataObjectName = PrintFormSettingsItem.PathToTemplate 
		And Source.FormOwner = ThisObject Then
			Template = Parameter.SpreadsheetDocument;
			TemplateAddressInTempStorage = PutToTempStorage(Template);
			SaveTemplate(Parameter.TemplateMetadataObjectName, TemplateAddressInTempStorage);
			AttachIdleHandler("RefreshCurrentPrintForm",0.1,True);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure CopiesOnChange(Item)
	If PrintFormSettings.Count() = 1 Then
		PrintFormSettings[0].Count = Copies;
		ThisObject[PrintFormSettings[0].AttributeName].Copies = PrintFormSettings[0].Count;
	EndIf;
EndProcedure

&AtClient
Procedure Attachable_SpreadsheetDocumentFieldOnActivateArea(Item)
	//If ReportSettings.ShowSelectedCellsAmount Then
  IdleInterval = ?(GetClientConnectionSpeed() = ClientConnectionSpeed.Low, 1, 0.2);
		AttachIdleHandler("Attachable_CalculateCellAmount", IdleInterval, True);
	//EndIf;
EndProcedure

#EndRegion

#Region PrintFormSettingsFormTableItemEventHandlers

&AtClient
Procedure PrintFormSettingsOnChange(Item)
	
	CanPrint = False;
	CanSave = False;
	
	For Each PrintFormSettingsItem In PrintFormSettings Do
		PrintForm = ThisObject[PrintFormSettings.AttributeName];
		SpreadsheetDocumentField = Items[PrintFormSettings.AttributeName];
		
		CanPrint = CanPrint Or PrintFormSettings.Print And PrintForm.TableHeight > 0
			And SpreadsheetDocumentField.Output = UseOutput.Enable;
		
		CanSave = CanSave Or PrintFormSettings.Print And PrintForm.TableHeight > 0
			And SpreadsheetDocumentField.Output = UseOutput.Enable And Not SpreadsheetDocumentField.Protection;
	EndDo;
	
	Items.PrintButtonCommandBar.Enabled = CanPrint;
	Items.PrintButtonAllActions.Enabled = CanPrint;
	
	Items.SaveButton.Enabled = CanSave;
	Items.SaveButtonAllActions.Enabled = CanSave;
	
	Items.SendButton.Enabled = CanSave;
	Items.SendButtonAllActions.Enabled = CanSave;
EndProcedure

&AtClient
Procedure PrintFormSettingsOnActivateRow(Item)
	SetCurrentPage();
EndProcedure

&AtClient
Procedure PrintFormSettingsCountOnChange(Item)
	PrintFormSettings = PrintFormCurrentSettings();
	ThisObject[PrintFormSettings.AttributeName].Copies = PrintFormSettings.Quantity;
EndProcedure

&AtClient
Procedure PrintFormSettingsCountTuning(Item, Direction, StandardProcessing)
	PrintFormSettings = PrintFormCurrentSettings();
	PrintFormSettings.Print = PrintFormSettings.Quantity + Direction > 0;
EndProcedure

&AtClient
Procedure PrintFormSettingsPrintOnChange(Item)
	PrintFormSettings = PrintFormCurrentSettings();
	If PrintFormSettings.Print And PrintFormSettings.Quantity = 0 Then
		PrintFormSettings.Quantity = 1;
	EndIf;
EndProcedure

&AtClient
Procedure PrintFormSettingsBeforeAddRow(Item, Cancel, Clone, Parent, Group)
	Cancel = True;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Save(Command)
	FormParameters = New Structure;
	FormParameters.Insert("PrintObjects", PrintObjects);
	OpenForm("CommonForm.SavePrintForm", FormParameters, ThisObject);
EndProcedure

&AtClient
Procedure Send(Command)
	
	SendPrintFormsByEmail();
	
EndProcedure

&AtClient
Procedure GoToDocument(Command)
	
	ChoiceList = New ValueList;
	For Each PrintObject In PrintObjects Do
		ChoiceList.Add(PrintObject.Presentation, String(PrintObject.Value));
	EndDo;
	
	NotifyDescription = New NotifyDescription("GoToDocumentCompletion", ThisObject);
	ChoiceList.ShowChooseItem(NotifyDescription, NStr("en = 'Go to the print form'"));
	
EndProcedure

&AtClient
Procedure GoToTemplateManagement(Command)
	OpenForm("InformationRegister.UserPrintTemplates.Form.PrintFormTemplates");
EndProcedure

&AtClient
Procedure Print(Command)
	
	SpreadsheetDocuments = New ValueList;
	
	For Each PrintFormSettingsItem In PrintFormSettings Do
		If Items[PrintFormSettingsItem.AttributeName].Output = UseOutput.Enable And PrintFormSettingsItem.Print Then
			SpreadsheetDocuments.Add(ThisObject[PrintFormSettingsItem.AttributeName], PrintFormSettingsItem.Presentation);
		EndIf;
	EndDo;
	
	PrintManagementClient.PrintSpreadsheetDocuments(SpreadsheetDocuments, PrintObjects,
		OutputParameters.PrintBySetsAvailable, ?(PrintFormSettings.Count() > 1, Copies, 1));
	
EndProcedure

&AtClient
Procedure ShowHideCopyCountSettings(Command)
	SetCopyCountSettingsVisibility();
EndProcedure

&AtClient
Procedure CheckAll(Command)
	SelectOrClearMarks(True);
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	SelectOrClearMarks(False);
EndProcedure

&AtClient
Procedure ResetSettings(Command)
	RestorePrintFormSettings();
EndProcedure

&AtClient
Procedure ChangeTemplate(Command)
	OpenTemplateForEditing();
EndProcedure

&AtClient
Procedure ToggleEditing(Command)
	ToggleCurrentPrintFormEditing();
EndProcedure

&AtClient
Procedure EvalSum(Command)
	PrintFormSettingsItem = PrintFormCurrentSettings();
	If PrintFormSettingsItem <> Undefined Then
		SpreadsheetDocument = ThisObject[PrintFormSettingsItem.AttributeName];
		SelectedCellTotal = EvalSumServer(SpreadsheetDocument, SelectedAreas(SpreadsheetDocument));
	EndIf;
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.PrintFormSettings.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("PrintFormSettings.Print");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);

EndProcedure

&AtServer
Procedure GeneratePrintForms(PrintFormCollection, TemplateNames, Cancel)
	
	// Generating spreadsheet documents
	If ValueIsFilled(Parameters.DataSource) Then
		If CommonUse.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
			AdditionalReportsAndDataProcessorsModule = CommonUse.CommonModule("AdditionalReportsAndDataProcessors");
			AdditionalReportsAndDataProcessorsModule.PrintByExternalSource(Parameters.DataSource,
				Parameters.SourceParameters, PrintFormCollection, PrintObjects, OutputParameters);
		Else
			Cancel = True;
		EndIf;
	Else
		PrintObjectTypes = New Array;
		Parameters.PrintParameters.Property("PrintObjectTypes", PrintObjectTypes);
		PrintManagement.GeneratePrintForms(Parameters.PrintManagerName, TemplateNames,
			Parameters.CommandParameter, Parameters.PrintParameters.AdditionalParameters, PrintFormCollection,
			PrintObjects, OutputParameters, PrintObjectTypes);
	EndIf;
	
	// Setting the flag of saving print forms to a file (do not open the form, save it directly to a file)
	If TypeOf(Parameters.PrintParameters) = Type("Structure") And Parameters.PrintParameters.Property("SavingFormat") Then
		FoundFormat = PrintManagement.SpreadsheetDocumentStorageFormatSettings().Find(Parameters.PrintParameters.SavingFormat, "SpreadsheetDocumentFileType");
		If FoundFormat <> Undefined Then
			StorageFormatSettings = New Structure("SpreadsheetDocumentFileType,Presentation,Extension,Filter");
			FillPropertyValues(StorageFormatSettings, FoundFormat);
			StorageFormatSettings.Filter = StorageFormatSettings.Presentation + "|*." + StorageFormatSettings.Extension;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure ImportCopyCountSettings()
	
	SavedPrintFormSettings = New Array;
	
	UseSavedSettings = True;
	If TypeOf(Parameters.PrintParameters) = Type("Structure") And Parameters.PrintParameters.Property("OverrideCopiesUserSetting") Then
		UseSavedSettings = Not 
Parameters.PrintParameters.OverrideCopiesUserSetting;
	EndIf;
	
	If UseSavedSettings And Not ValueIsFilled(Parameters.DataSource) Then
		TemplateNames = Parameters.TemplateNames;
		If TypeOf(TemplateNames) = Type("Array") Then
			TemplateNames = StringFunctionsClientServer.StringFromSubstringArray(TemplateNames);
		EndIf;
			
		SettingsKey = Parameters.PrintManagerName + "-" + TemplateNames;
		If StrLen(SettingsKey) > 128 Then // A key longer than 128 characters raises an exception when accessing the settings storage
			DataHashing = New DataHashing(HashFunction.MD5);
			DataHashing.Append(TemplateNames);
			SettingsKey = Parameters.PrintManagerName + "-" + StrReplace(DataHashing.HashSum, " ", "");
		EndIf;
		SavedPrintFormSettings = CommonUse.CommonSettingsStorageLoad("PrintFormSettings", SettingsKey, New Array);
	EndIf;
	
	RestorePrintFormSettings(SavedPrintFormSettings);
	
	If IsBatchPrinting() Then
		Copies = 1;
	Else
		If PrintFormSettings.Count() > 0 Then
			Copies = PrintFormSettings[0].Count;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure CreateAttributesAndFormItemsForPrintForms(PrintFormCollection)
	
	// Creating attributes for spreadsheet documents
	NewFormAttributes = New Array;
	For PrintFormNumber = 1 To PrintFormCollection.Count() Do
		AttributeName = "PrintForm" + Format(PrintFormNumber,"NG=0");
		FormAttribute = New FormAttribute(AttributeName, New TypeDescription("SpreadsheetDocument"),,PrintFormCollection[PrintFormNumber - 1].TemplateSynonym);
		NewFormAttributes.Add(FormAttribute);
	EndDo;
	ChangeAttributes(NewFormAttributes);
	
	// Creating pages with spreadsheet documents on a form
	PrintFormNumber = 0;
	AddedPrintFormSettings = New Map;
	For Each FormAttribute In NewFormAttributes Do
		PrintFormDescription = PrintFormCollection[PrintFormNumber];
		
		// Print form settings table (beginning)
		NewPrintFormSettings = PrintFormSettings.Add();
		NewPrintFormSettings.Presentation = PrintFormDescription.TemplateSynonym;
		NewPrintFormSettings.Print = True;
		NewPrintFormSettings.Count = PrintFormDescription.Copies;
		NewPrintFormSettings.TemplateName = PrintFormDescription.TemplateName;
		NewPrintFormSettings.DefaultPosition = PrintFormNumber;
		NewPrintFormSettings.Name = PrintFormDescription.TemplateSynonym;
		NewPrintFormSettings.PathToTemplate = PrintFormDescription.FullPathToTemplate;
		NewPrintFormSettings.PrintFormFileName = CommonUse.ValueToXMLString(PrintFormDescription.PrintFormFileName);
		
		PreviouslyAddedPrintFormSettings = AddedPrintFormSettings[PrintFormDescription.TemplateName];
		If PreviouslyAddedPrintFormSettings = Undefined Then
			// Copying a spreadsheet document to a form attribute
			AttributeName = FormAttribute.Name;
			ThisObject[AttributeName] = PrintFormDescription.SpreadsheetDocument;
			
			// Creating pages for spreadsheet documents
			PageName = "Page" + AttributeName;
			Page = Items.Add(PageName, Type("FormGroup"), Items.Pages);
			Page.Type = FormGroupType.Page;
			Page.Picture = PictureLib.SpreadsheetInsertPageBreak;
			Page.Title = PrintFormDescription.TemplateSynonym;
			Page.ToolTip = PrintFormDescription.TemplateSynonym;
			Page.Visible = ThisObject[AttributeName].TableHeight > 0;
			
			// Creating items for displaying spreadsheet documents
			NewItem = Items.Add(AttributeName, Type("FormField"), Page);
			NewItem.Type = FormFieldType.SpreadsheetDocumentField;
			NewItem.TitleLocation = FormItemTitleLocation.None;
			NewItem.DataPath = AttributeName;
			NewItem.Output = EvalUseOutput(PrintFormDescription.SpreadsheetDocument);
			NewItem.Edit = NewItem.Output = UseOutput.Enable And Not PrintFormDescription.SpreadsheetDocument.ReadOnly;
			NewItem.Protection = PrintFormDescription.SpreadsheetDocument.Protection;
			NewItem.SetAction("OnActivateArea", "Attachable_SpreadsheetDocumentFieldOnActivateArea");
			
			// Print form settings table (continued)
			NewPrintFormSettings.PageName = PageName;
			NewPrintFormSettings.AttributeName = AttributeName;
			
			AddedPrintFormSettings.Insert(NewPrintFormSettings.TemplateName, NewPrintFormSettings);
		Else
			NewPrintFormSettings.PageName = PreviouslyAddedPrintFormSettings.PageName;
			NewPrintFormSettings.AttributeName = PreviouslyAddedPrintFormSettings.AttributeName;
		EndIf;
		
		PrintFormNumber = PrintFormNumber + 1;
	EndDo;
	
EndProcedure

&AtServer
Function SaveDefaultBatchSettings()
	For Each PrintFormSettingsItem In PrintFormSettings Do
		FillPropertyValues(DefaultBatchSettings.Add(), PrintFormSettings);
	EndDo;
EndFunction

&AtServer
Procedure SetUpFormItemVisibility(Val HasAllowedOutput)
	
	HasAllowedEditing = HasAllowedEditing();
	
	CanSendEmails = False;
	If CommonUse.SubsystemExists("StandardSubsystems.EmailOperations") Then
		EmailOperationsModule = CommonUse.CommonModule("EmailOperations");
		CanSendEmails = EmailOperationsModule.CanSendEmails();
	EndIf;
	CanSendByEmail = HasAllowedOutput And CanSendEmails;
	
	HasDataToPrint = HasDataToPrint();
	
	Items.GoToDocumentButton.Visible = PrintObjects.Count() > 1;
	
	Items.SaveButton.Visible = HasDataToPrint and HasAllowedOutput And HasAllowedEditing;
	Items.SaveButtonAllActions.Visible = Items.SaveButton.Visible;
	
	Items.SendButton.Visible = CanSendByEmail and HasDataToPrint And HasAllowedEditing;
	Items.SendButtonAllActions.Visible = Items.SendButton.Visible;
	
	Items.PrintButtonCommandBar.Visible = HasAllowedOutput And HasDataToPrint;
	Items.PrintButtonAllActions.Visible = Items.PrintButtonCommandBar.Visible;
	
	Items.Copies.Visible = HasAllowedOutput And HasDataToPrint;
	Items.EditButton.Visible = HasAllowedOutput And HasDataToPrint And HasAllowedEditing;
	
	Items.ShowHideBatchSettingsButton.Visible = IsBatchPrinting();
	Items.PrintFormSettings.Visible = IsBatchPrinting();
	Items.BatchSettingsGroupSubmenu.Visible = IsBatchPrinting();
	
	CanConfigureBatch = True;
	If TypeOf(Parameters.PrintParameters) = Type("Structure") And Parameters.PrintParameters.Property("FixedBatch") Then
		CanConfigureBatch = Not Parameters.PrintParameters.FixedBatch;
	EndIf;
	
	Items.BatchSettingsGroupContextMenu.Visible = CanConfigureBatch;
	Items.BatchSettingsGroupSubmenu.Visible = IsBatchPrinting() And CanConfigureBatch;
	Items.PrintFormSettingsPrint.Visible = CanConfigureBatch;
	Items.PrintFormSettingsCount.Visible = CanConfigureBatch;
	Items.PrintFormSettings.Header = CanConfigureBatch;
	Items.PrintFormSettings.HorizontalLines = CanConfigureBatch;
	
	If Not CanConfigureBatch Then
		AddCopiesToPrintFormPresentations();
	EndIf;
	
	CanEditTemplate = Users.RolesAvailable("EditPrintFormTemplates") And HasTemplatesToEdit();
	Items.ChangeTemplateButton.Visible = CanEditTemplate And HasDataToPrint;
	
	// Disabling the auxiliary page that is only needed for designing a form in Designer
	Items.PrintFormPatternPage.Visible = False;

EndProcedure

&AtServer
Procedure AddCopiesToPrintFormPresentations()
	For Each PrintFormSettingsItem In PrintFormSettings Do
		If PrintFormSettings.Quantity <> 1 Then
			PrintFormSettings.Presentation = PrintFormSettings.Presentation 
				+ " (" + PrintFormSettings.Quantity + " " + NStr("en = 'copies'") + ")";
		EndIf;
	EndDo;
EndProcedure

&AtServer
Procedure SetOutputAvailabilityFlagInPrintFormPresentations(HasAllowedOutput)
	If HasAllowedOutput Then
		For Each PrintFormSettingsItem In PrintFormSettings Do
			SpreadsheetDocumentField = Items[PrintFormSettingsItem.AttributeName];
			If SpreadsheetDocumentField.Output = UseOutput.Disable Then
				PrintFormSettings.Presentation = PrintFormSettingsItem.Presentation + " (" + NStr("en = 'output is not available'") + ")";
			ElsIf SpreadsheetDocumentField.Protection Then
				PrintFormSettings.Presentation = PrintFormSettingsItem.Presentation + " (" + NStr("en = 'printing only'") + ")";
			EndIf;
		EndDo;
	EndIf;	
EndProcedure

&AtClient
Procedure SetCopyCountSettingsVisibility(Val Visibility = Undefined)
	If Visibility = Undefined Then
		Visibility = Not Items.PrintFormSettings.Visibility;
	EndIf;
	
	Items.PrintFormSettings.Visible = Visibility;
	Items.BatchSettingsGroupSubmenu.Visible = Visibility And CanConfigureBatch;
EndProcedure

&AtServer
Procedure SetPrinterNameInPrintButtonTooltip()
	If PrintFormSettings.Count() > 0 Then
		PrinterName = ThisObject[PrintFormSettings[0].AttributeName].PrinterName;
		If Not IsBlankString(PrinterName) Then
			ThisObject.Commands["Print"].ToolTip = NStr("en = 'Use printer:'") + " (" + PrinterName + ")";
		EndIf;
	EndIf;
EndProcedure

&AtServer
Procedure SetFormTitle()
	Var FormTitle;
	
	If TypeOf(Parameters.PrintParameters) = Type("Structure") Then
		Parameters.PrintParameters.Property("FormTitle", FormTitle);
	EndIf;
	
	If ValueIsFilled(FormTitle) Then
		Title = FormTitle;
	Else
		If IsBatchPrinting() Then
			Title = NStr("en = 'Print batch'");
		ElsIf TypeOf(Parameters.CommandParameter) <> Type("Array") Or Parameters.CommandParameter.Count() > 1 Then
			Title = NStr("en = 'Print documents'");
		Else
			Title = NStr("en = 'Print document'");
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure SetCurrentPage()
	
	PrintFormSettingsItem = PrintFormCurrentSettings();
	
	CurrentPage = Items.PrintFormIsNotAvailablePage;
	If PrintFormSettingsItem <> Undefined And ThisObject[PrintFormSettingsItem.AttributeName].TableHeight > 0 Then
		CurrentPage = Items[PrintFormSettingsItem.PageName];
	EndIf;
	
	Items.Pages.CurrentPage = CurrentPage;
	
	ToggleEditingButtonMark();
	SetTemplateChangeEnabled();
	
EndProcedure

&AtClient
Procedure SelectOrClearMarks(Check)
	For Each PrintFormSettings In PrintFormSettings Do
		PrintFormSettings.Print = Check;
		If Check And PrintFormSettings.Quantity = 0 Then
			PrintFormSettings.Quantity = 1;
		EndIf;
	EndDo;
EndProcedure

&AtServer
Function EvalUseOutput(SpreadsheetDocument)
	If SpreadsheetDocument.Output = UseOutput.Auto Then
		Return ?(AccessRight("Output", Metadata), UseOutput.Enable, UseOutput.Disable);
	Else
		Return SpreadsheetDocument.Output;
	EndIf;
EndFunction

&AtServerNoContext
Procedure SavePrintFormSettings(SettingsKey, PrintFormSettingsToSave)
	CommonUse.CommonSettingsStorageSave("PrintFormSettings", SettingsKey, PrintFormSettingsToSave);
EndProcedure

&AtServer
Procedure RestorePrintFormSettings(SavedPrintFormSettings = Undefined)
	If SavedPrintFormSettings = Undefined Then
		SavedPrintFormSettings = DefaultBatchSettings;
	EndIf;
	
	If SavedPrintFormSettings = Undefined Then
		Return;
	EndIf;
	
	For Each SavedSettings In SavedPrintFormSettings Do
		FoundSettings = PrintFormSettings.FindRows(New Structure("DefaultPosition", SavedSettings.DefaultPosition));
		For Each PrintFormSettingsItem In FoundSettings Do
			LineIndex = PrintFormSettings.IndexOf(PrintFormSettingsItem);
			PrintFormSettings.Move(LineIndex, PrintFormSettings.Count()-1 - LineIndex); // Moving to the end
			PrintFormSettingsItem.Count = SavedSettings.Count;
			ThisObject[PrintFormSettingsItem.AttributeName].Copies = PrintFormSettingsItem.Count;
			PrintFormSettingsItem.Print = PrintFormSettingsItem.Count > 0;
		EndDo;
	EndDo;
EndProcedure

&AtServer
Function PutSpreadsheetDocumentsToTempStorage(SavingSettings)
	Var ZipFileWriter, ArchiveName;
	
	Result = New Array;
	
	// Preparing the archive
	If SavingSettings.PackToArchive Then
		ArchiveName = GetTempFileName("zip");
		ZipFileWriter = New ZipFileWriter(ArchiveName);
	EndIf;
	
	// Preparing a temporary folder
	TempFolderName = GetTempFileName();
	CreateDirectory(TempFolderName);
	UsedFileNames = New Map;
	
	SelectedStorageFormats = SavingSettings.SavingFormats;
	FormatTable = PrintManagement.SpreadsheetDocumentStorageFormatSettings();
	
	// Saving print forms
	ProcessedPrintForms = New Array;
	For Each PrintFormSettingsItem In PrintFormSettings Do
		
		If Not PrintFormSettingsItem.Print Then
			Continue;
		EndIf;
		
		PrintForm = ThisObject[PrintFormSettingsItem.AttributeName];
		If ProcessedPrintForms.Find(PrintForm) = Undefined Then
			ProcessedPrintForms.Add(PrintForm);
		Else
			Continue;
		EndIf;
		
		If EvalUseOutput(PrintForm) = UseOutput.Disable Then
			Continue;
		EndIf;
		
		If PrintForm.Protection Then
			Continue;
		EndIf;
		
		If PrintForm.TableHeight = 0 Then
			Continue;
		EndIf;
		
		PrintFormsByObjects = PrintFormsByObjects(PrintForm);
		For Each MapBetweenObjectAndPrintForm In PrintFormsByObjects Do
			PrintForm = MapBetweenObjectAndPrintForm.Value;
			For Each FileType In SelectedStorageFormats Do
				FormatSettings = FormatTable.FindRows(New Structure("SpreadsheetDocumentFileType", FileType))[0];
				
				If MapBetweenObjectAndPrintForm.Key <> "PrintObjectsNotSpecified" Then
					FileName = ObjectPrintFormFileName(MapBetweenObjectAndPrintForm.Key, CommonUse.ValueFromXMLString(PrintFormSettingsItem.PrintFormFileName));
					If FileName = Undefined Then
						FileName = DefaultPrintFormFileName(MapBetweenObjectAndPrintForm.Key, PrintFormSettingsItem.Name);
					EndIf;
					FileName = FileName + "." + FormatSettings.Extension;
					FileName = CommonUseClientServer.ReplaceProhibitedCharsInFileName(FileName);
				Else
					FileName = GetTempFileNameForPrintForm(PrintFormSettings.Name,FormatSettings.Extension,UsedFileNames);
				EndIf;
				
				FullFileName = CommonUseClientServer.AddFinalPathSeparator(TempFolderName) + FileName;
				PrintForm.Write(FullFileName, FileType);
				
				If FileType = SpreadsheetDocumentFileType.HTML Then
					InsertHTMLPictures(FullFileName);
				EndIf;
				
				If ZipFileWriter <> Undefined Then 
					ZipFileWriter.Add(FullFileName);
				Else
					BinaryData = New BinaryData(FullFileName);
					PathInTempStorage = PutToTempStorage(BinaryData, ThisObject.UUID);
					FileDetails = New Structure;
					FileDetails.Insert("Presentation", FileName);
					FileDetails.Insert("AddressInTempStorage", PathInTempStorage);
					If FileType = SpreadsheetDocumentFileType.ANSITXT Then
						FileDetails.Insert("Encoding", "windows-1251");
					EndIf;
					Result.Add(FileDetails);
				EndIf;
			EndDo;
		EndDo;
	EndDo;
	
	// If the archive is prepared, writing it and putting it to a temporary storage
	If ZipFileWriter <> Undefined Then 
		ZipFileWriter.Write();
		ArchiveFile = New File(ArchiveName);
		BinaryData = New BinaryData(ArchiveName);
		PathInTempStorage = PutToTempStorage(BinaryData, ThisObject.UUID);
		FileDetails = New Structure;
		FileDetails.Insert("Presentation", GetFileNameForArchive());
		FileDetails.Insert("AddressInTempStorage", PathInTempStorage);
		Result.Add(FileDetails);
	EndIf;
	
	DeleteFiles(TempFolderName);
	
	Return Result;
	
EndFunction

&AtServer
Function PrintFormsByObjects(PrintForm)
	If PrintObjects.Count() = 0 Then
		Return New Structure("PrintObjectsNotSpecified", PrintForm);
	EndIf;
		
	Result = New Map;
	For Each PrintObject In PrintObjects Do
		AreaName = PrintObject.Presentation;
		Area = PrintForm.Areas.Find(AreaName);
		If Area = Undefined Then
			Continue;
		EndIf;
		SpreadsheetDocument = PrintForm.GetArea(Area.Top, , Area.Bottom);
		FillPropertyValues(SpreadsheetDocument, PrintForm,
			"FitToPage,Output,PageHeight,DuplexPrinting,Protection,PrinterName,TemplateLanguageCode,Copies,PrintScale,PageOrientation,TopMargin,LeftMargin,BottomMargin,RightMargin,Collate,HeaderSize,FooterSize,PageSize,PrintAccuracy,BlackAndWhite,PageWidth,PerPage");
		Result.Insert(PrintObject.Value, SpreadsheetDocument);
	EndDo;
	Return Result;
EndFunction

&AtServer
Procedure InsertHTMLPictures(HTMLFileName)
	
	TextDocument = New TextDocument();
	TextDocument.Read(HTMLFileName, TextEncoding.UTF8);
	HTMLText = TextDocument.GetText();
	
	HTMLFile = New File(HTMLFileName);
	
	PictureFolderName = HTMLFile.BaseName + "_files";
	PathToPictureFolder = StrReplace(HTMLFile.FullName, HTMLFile.Name, PictureFolderName);
	
	// The folder is only for pictures
	PictureFiles = FindFiles(PathToPictureFolder, "*");
	
	For Each PictureFile In PictureFiles Do
		PictureText = Base64String(New BinaryData(PictureFile.FullName));
		PictureText = "data:image/" + Mid(PictureFile.Extension,2) + ";base64," + Chars.LF + PictureText;
		
		HTMLText = StrReplace(HTMLText, PictureFolderName + "\" + PictureFile.Name, PictureText);
	EndDo;
		
	TextDocument.SetText(HTMLText);
	TextDocument.Write(HTMLFileName, TextEncoding.UTF8);
	
EndProcedure

&AtServer
Function ObjectPrintFormFileName(PrintObject, PrintFormFileName)
	If TypeOf(PrintFormFileName) = Type("Map") Then
		Return String(PrintFormFileName[PrintObject]);
	ElsIf TypeOf(PrintFormFileName) = Type("String") And Not IsBlankString(PrintFormFileName) Then
		Return PrintFormFileName;
	Else
		Return Undefined;
	EndIf;
EndFunction

&AtServer
Function DefaultPrintFormFileName(PrintObject, PrintFormName)
	
	If CommonUse.IsDocument(Metadata.FindByType(TypeOf(PrintObject))) Then
		ParametersToInsert = CommonUse.ObjectAttributeValues(PrintObject, "Date,Number");
		If CommonUse.SubsystemExists("StandardSubsystems.ObjectPrefixation") Then
			ObjectPrefixationClientServerModule = CommonUse.CommonModule("ObjectPrefixationClientServer");
			ParametersToInsert.Number = ObjectPrefixationClientServerModule.GetNumberForPrinting(ParametersToInsert.Number);
		EndIf;
		ParametersToInsert.Date = Format(ParametersToInsert.Date, "DLF=D");
		ParametersToInsert.Insert("PrintFormName", PrintFormName);
		Template = NStr("en = '[PrintFormName] [number] dated [Date]'");
	Else
		ParametersToInsert = New Structure;
		ParametersToInsert.Insert("PrintFormName",PrintFormName);
		ParametersToInsert.Insert("ObjectPresentation", CommonUse.SubjectString(PrintObject));
		ParametersToInsert.Insert("CurrentDate",Format(CurrentSessionDate(), "DLF=D"));
		Template = NStr("en = '[PrintFormName] - [ObjectPresentation] - [CurrentDate]'");
	EndIf;
	
	Return StringFunctionsClientServer.SubstituteParametersInStringByName(Template, ParametersToInsert);
	
EndFunction

&AtServer
Function GetFileNameForArchive()
	
	Result = "";
	
	For Each PrintFormSettingsItem In PrintFormSettings Do
		
		If Not PrintFormSettings.Print Then
			Continue;
		EndIf;
		
		PrintForm = ThisObject[PrintFormSettings.AttributeName];
		
		If EvalUseOutput(PrintForm) = UseOutput.Disable Then
			Continue;
		EndIf;
		
		If IsBlankString(Result) Then
			Result = PrintFormSettings.Name;
		Else
			Result = NStr("en = 'Documents'");
			Break;
		EndIf;
	EndDo;
	
	Return Result + ".zip";
	
EndFunction

&AtClient
Procedure SavePrintFormToFile()
	
	SavingFormats = New Array;
	SavingFormats.Add(StorageFormatSettings.SpreadsheetDocumentFileType);
	SavingSettings = New Structure("SavingFormats,PackToArchive", SavingFormats, False);
	FilesInTempStorage = PutSpreadsheetDocumentsToTempStorage(SavingSettings);
	
	For Each FileToWrite In FilesInTempStorage Do
		#If WebClient Then
		GetFile(FileToWrite.AddressInTempStorage, FileToWrite.Presentation);
		#Else
		TempFileName = GetTempFileName(StorageFormatSettings.Extension);
		BinaryData = GetFromTempStorage(FileToWrite.AddressInTempStorage);
		BinaryData.Write(TempFileName);
		RunApp(TempFileName);
		#EndIf
	EndDo;
	
EndProcedure

&AtClient
Procedure SavePrintFormsToFolder(FileListInTempStorage, Val Folder = "")
	
	#If WebClient Then
		For Each FileToWrite In FileListInTempStorage Do
			GetFile(FileToWrite.AddressInTempStorage, FileToWrite.Presentation);
		EndDo;
		Return;
	#EndIf
	
	Folder = CommonUseClientServer.AddFinalPathSeparator(Folder);
	For Each FileToWrite In FileListInTempStorage Do
		FullFileName = Folder + FileToWrite.Presentation;
		File = New File(FullFileName);
		BaseName = File.BaseName;
		Extension = File.Extension;
		
		Counter = 1;
		While File.Exist() Do
			Counter = Counter + 1;
			File = New File(Folder + BaseName + " (" + Counter + ")" + Extension);
		EndDo;
		FullFileName = File.FullName;
		
		BinaryData = GetFromTempStorage(FileToWrite.AddressInTempStorage);
		BinaryData.Write(FullFileName);
	EndDo;
	
	Status(NStr("en = 'Saved'"), , NStr("en = 'to directory:'") + " " + Folder);
	
EndProcedure

&AtServer
Procedure AttachPrintFormsToObject(FilesInTempStorage, ObjectToAttach)
	For Each File In FilesInTempStorage Do
		PrintManagement.OnAttachPrintFormToObject (ObjectToAttach, File.Presentation, File.AddressInTempStorage);
	EndDo;
EndProcedure

&AtServer
Function IsBatchPrinting()
	Return PrintFormSettings.Count() > 1;
EndFunction

&AtServer
Function HasAllowedOutput()
	
	For Each PrintFormSettingsItem In PrintFormSettings Do
		If Items[PrintFormSettingsItem.AttributeName].Output = UseOutput.Enable Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

&AtServer
Function HasAllowedEditing()
	
	For Each PrintFormSettingsItem In PrintFormSettings Do
		If Items[PrintFormSettingsItem.AttributeName].Protection = False Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

&AtClient
Function MoreThanOneRecipient(Recipient)
	If TypeOf(Recipient) = Type("Array") Or TypeOf(Recipient) = Type("ValueList") Then
		Return Recipient.Count() > 1;
	Else
		Return CommonUseClientServer.EmailsFromString(Recipient).Count() > 1;
	EndIf;
EndFunction

&AtServer
Function HasDataToPrint()
	Result = False;
	For Each PrintFormSettingsItem In PrintFormSettings Do
		Result = Result Or ThisObject[PrintFormSettingsItem.AttributeName].TableHeight > 0;
	EndDo;
	Return Result;
EndFunction

&AtServer
Function HasTemplatesToEdit()
	Result = False;
	For Each PrintFormSettingsItem In PrintFormSettings Do
		Result = Result Or Not IsBlankString(PrintFormSettingsItem.PathToTemplate);
	EndDo;
	Return Result;
EndFunction

&AtClient
Procedure OpenTemplateForEditing()
	
	PrintFormSettings = PrintFormCurrentSettings();
	
	DisplayCurrentPrintFormState(NStr("en = 'Template is being edited'"));
	
	TemplateMetadataObjectName = PrintFormSettings.PathToTemplate;
	
	#If WebClient Then
		OpenParameters = New Structure;
		OpenParameters.Insert("TemplateMetadataObjectName", TemplateMetadataObjectName);
		OpenParameters.Insert("TemplateType", "MXL");
		OpenParameters.Insert("IsWebClient", True);
		
		OpenForm("InformationRegister.UserPrintTemplates.Form.EditTemplate", OpenParameters, ThisObject);
		
	#Else
		OpenParameters = New Structure;
		OpenParameters.Insert("TemplateMetadataObjectName", TemplateMetadataObjectName);
		OpenParameters.Insert("WindowOpeningMode", FormWindowOpeningMode.LockOwnerWindow);
		OpenParameters.Insert("DocumentName", PrintFormSettings.Presentation);
		OpenParameters.Insert("Edit", True);
		
		OpenForm("CommonForm.SpreadsheetDocumentEditing", OpenParameters, ThisObject);
	#EndIf
	
EndProcedure

&AtClient
Procedure DisplayCurrentPrintFormState(StateText = "")
	
	ShowStatus = Not IsBlankString(StateText);
	
	PrintFormSettings = PrintFormCurrentSettings();
	If PrintFormSettings = Undefined Then
		Return;
	EndIf;
	
	SpreadsheetDocumentField = Items[PrintFormSettings.AttributeName];
	
	StatePresentation = SpreadsheetDocumentField.StatePresentation;
	StatePresentation.Text = StateText;
	StatePresentation.Visible = ShowStatus;
	StatePresentation.AdditionalShowMode = 
		?(ShowStatus, AdditionalShowMode.Irrelevance, AdditionalShowMode.DontUse);
		
	SpreadsheetDocumentField.ReadOnly = ShowStatus Or SpreadsheetDocumentField.Output = UseOutput.Disable;
	
EndProcedure

&AtClient
Procedure ToggleCurrentPrintFormEditing()
	PrintFormSettingsItem = PrintFormCurrentSettings();
	If PrintFormSettingsItem <> Undefined Then
		SpreadsheetDocumentField = Items[PrintFormSettingsItem.AttributeName];
		SpreadsheetDocumentField.Edit = Not SpreadsheetDocumentField.Edit;
		ToggleEditingButtonMark();
	EndIf;
EndProcedure

&AtClient
Procedure ToggleEditingButtonMark()
	
	PrintFormAvailable = Items.Pages.CurrentPage <> Items.PrintFormIsNotAvailablePage;
	
	Editable = False;
	Check = False;
	
	PrintFormSettingsItem = PrintFormCurrentSettings();
	If PrintFormSettingsItem <> Undefined Then
		SpreadsheetDocumentField = Items[PrintFormSettingsItem.AttributeName];
		Editable = PrintFormAvailable And Not SpreadsheetDocumentField.Protection;
		Check = SpreadsheetDocumentField.Edit And Editable;
	EndIf;
	
	Items.EditButton.Check = Check;
	Items.EditButton.Enabled = Editable;
	
EndProcedure

&AtClient
Procedure SetTemplateChangeEnabled()
	PrintFormAvailable = Items.Pages.CurrentPage <> Items.PrintFormIsNotAvailablePage;
	PrintFormSettingsItem = PrintFormCurrentSettings();
	Items.ChangeTemplateButton.Enabled = PrintFormAvailable And Not IsBlankString(PrintFormSettingsItem.PathToTemplate);
EndProcedure

&AtClient
Procedure RefreshCurrentPrintForm()
	
	PrintFormSettings = PrintFormCurrentSettings();
	If PrintFormSettings = Undefined Then
		Return;
	EndIf;
	
	GeneratePrintFormAgain(PrintFormSettings.TemplateName, PrintFormSettings.AttributeName);
	DisplayCurrentPrintFormState();
	
EndProcedure

&AtServer
Procedure GeneratePrintFormAgain(TemplateName, AttributeName)
	Var PrintFormCollection;
	
	Cancel = False;
	
	GeneratePrintForms(PrintFormCollection, TemplateName, Cancel);
	If Cancel Then
		Raise NStr("en = 'Print form is not generated.'");
	EndIf;
	
	For Each PrintForm In PrintFormCollection Do
		If PrintForm.TemplateName = TemplateName Then
			ThisObject[AttributeName] = PrintForm.SpreadsheetDocument;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Function PrintFormCurrentSettings()
	Result = Items.PrintFormSettings.CurrentData;
	If Result = Undefined And PrintFormSettings.Count() > 0 Then
		Result = PrintFormSettings[0];
	EndIf;
	Return Result;
EndFunction

&AtServerNoContext
Procedure SaveTemplate(TemplateMetadataObjectName, TemplateAddressInTempStorage)
	PrintManagement.SaveTemplate(TemplateMetadataObjectName, TemplateAddressInTempStorage);
EndProcedure

&AtClient
Procedure GoToDocumentCompletion(SelectedItem, AdditionalParameters) Export
	
	If SelectedItem = Undefined Then
		Return;
	EndIf;
	
	For Each PrintFormSettingsItem In PrintFormSettings Do
		SpreadsheetDocumentField = Items[PrintFormSettings.AttributeName];
		SpreadsheetDocument = ThisObject[PrintFormSettings.AttributeName];
		SelectedDocumentArea = SpreadsheetDocument.Areas.Find(SelectedItem.Value);
		
		SpreadsheetDocumentField.CurrentArea = SpreadsheetDocument.Area("R1C1"); // Moving to the beginning
		
		If SelectedDocumentArea <> Undefined Then
			SpreadsheetDocumentField.CurrentArea = SpreadsheetDocument.Area(SelectedDocumentArea.Top,,SelectedDocumentArea.Bottom,);
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure SendPrintFormsByEmail()
	NotifyDescription = New NotifyDescription("SendPrintFormsByEmailAccountSetupOffered", ThisObject);
	If CommonUseClient.SubsystemExists("StandardSubsystems.EmailOperations") Then
		EmailOperationsClientModule = CommonUseClient.CommonModule("EmailOperationsClient");
		EmailOperationsClientModule.CheckAccountForSendingEmailExists(NotifyDescription);
	EndIf;
EndProcedure

&AtClient
Procedure SendPrintFormsByEmailAccountSetupOffered(AccountConfigured, AdditionalParameters) Export
	
	If AccountConfigured <> True Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	NameOfFormToOpen = "CommonForm.SelectAttachmentFormat";
	If MoreThanOneRecipient(OutputParameters.SendingParameters.Recipient) Then
		FormParameters.Insert("To", OutputParameters.SendingParameters.Recipient);
		NameOfFormToOpen = "CommonForm.ComposeNewMessage";
	EndIf;
	
	OpenForm(NameOfFormToOpen, FormParameters, ThisObject);
	
EndProcedure

&AtServer
Function GetTempFileNameForPrintForm(TemplateName, Extension, UsedFileNames)
	
	FileNamePattern = "%1%2.%3";
	
	TempFileName = CommonUseClientServer.ReplaceProhibitedCharsInFileName(
		StringFunctionsClientServer.SubstituteParametersInString(FileNamePattern, TemplateName, "", Extension));
		
	UsageNumber = ?(UsedFileNames[TempFileName] <> Undefined,
							UsedFileNames[TempFileName] + 1,
							1);
	
	UsedFileNames.Insert(TempFileName, UsageNumber);
	
	// If the name was used before, adding the counter at the end of the name
	If UsageNumber > 1 Then
		TempFileName = CommonUseClientServer.ReplaceProhibitedCharsInFileName(
			StringFunctionsClientServer.SubstituteParametersInString(
				FileNamePattern,
				TemplateName,
				" (" + UsageNumber + ")",
				Extension));
	EndIf;
	
	Return TempFileName;
	
EndFunction

// Autosum

&AtClient
Procedure Attachable_CalculateCellAmount()
	PrintFormSettingsItem = PrintFormCurrentSettings();
	If PrintFormSettingsItem = Undefined Then
		Return;
	EndIf;
	
	SpreadsheetDocument = ThisObject[PrintFormSettingsItem.AttributeName];
	
	Amount = CalculateSelectedCellsTotal(SpreadsheetDocument, Undefined);
	If TypeOf(Amount) = Type("Number") Then
		SelectedCellTotal = Format(Amount, "NZ=0");
	Else
		SelectedCellTotal = "-";
	EndIf;
EndProcedure

&AtServerNoContext
Function EvalSumServer(Val SpreadsheetDocument, Val SelectedAreas)
	Amount = CalculateSelectedCellsTotal(SpreadsheetDocument, SelectedAreas);
	Return Format(Amount, "NZ=0");
EndFunction

&AtClientAtServerNoContext
Function CalculateSelectedCellsTotal(SpreadsheetDocument, SelectedAreas)
	
	#If Client Then
		SelectedAreas = SpreadsheetDocument.SelectedAreas;
	#EndIf
	
	#If Client And Not ThickClientOrdinaryApplication Then
		SelectedAreaCount = SelectedAreas.Count();
		If SelectedAreaCount = 0 Then
			Return 0;
		ElsIf SelectedAreaCount >= 100 Then
			Return Undefined; // Server call required
		EndIf;
		SelectedCellCount = 0;
	#EndIf
	
	Amount = 0;
	CheckedCells = New Map;
	
	For Each SelectedArea In SelectedAreas Do
		#If Client Then
			If TypeOf(SelectedArea) <> Type("SpreadsheetDocumentRange") Then
				Continue;
			EndIf;
		#EndIf
		
		SelectedAreaTop = SelectedArea.Top;
		SelectedAreaBottom = SelectedArea.Bottom;
		SelectedAreaLeft = SelectedArea.Left;
		SelectedAreaRight = SelectedArea.Right;
		
		If SelectedAreaTop = 0 Then
			SelectedAreaTop = 1;
		EndIf;
		
		If SelectedAreaBottom = 0 Then
			SelectedAreaBottom = SpreadsheetDocument.TableHeight;
		EndIf;
		
		If SelectedAreaLeft = 0 Then
			SelectedAreaLeft = 1;
		EndIf;
		
		If SelectedAreaRight = 0 Then
			SelectedAreaRight = SpreadsheetDocument.TableWidth;
		EndIf;
		
		If SelectedArea.AreaType = SpreadsheetDocumentCellAreaType.Columns Then
			SelectedAreaTop = SelectedArea.Bottom;
			SelectedAreaBottom = SpreadsheetDocument.TableHeight;
		EndIf;
		
		SelectedAreaHeight = SelectedAreaBottom   - SelectedAreaTop;
		SelectedAreaWidth = SelectedAreaRight - SelectedAreaLeft;
		
		#If Client And Not ThickClientOrdinaryApplication Then
			SelectedCellCount = SelectedCellCount + SelectedAreaWidth * SelectedAreaHeight;
			If SelectedCellCount >= 1000 Then
				Return Undefined; // Server call required
			EndIf;
		#EndIf
		
		For ColumnNumber = SelectedAreaLeft To SelectedAreaRight Do
			For LineNumber = SelectedAreaTop To SelectedAreaBottom Do
				Cell = SpreadsheetDocument.Area(LineNumber, ColumnNumber, LineNumber, ColumnNumber);
				If CheckedCells.Get(Cell.Name) = Undefined Then
					CheckedCells.Insert(Cell.Name, True);
				Else
					Continue;
				EndIf;
				
				If Cell.Visible = True Then
					If Cell.AreaType <> SpreadsheetDocumentCellAreaType.Columns
						And Cell.ContainsValue And TypeOf(Cell.Value) = Type("Number") Then
						Amount = Amount + Cell.Value;
					ElsIf ValueIsFilled(Cell.Text) Then
						Amount = Amount + StringIntoNumber(Cell.Text);
					EndIf;
				EndIf;
			EndDo;
		EndDo;
	EndDo;
	
	Return Amount;
	
EndFunction

&AtClientAtServerNoContext
Function StringIntoNumber(SourceString)
// Converts a string to a number without raising exceptions. The standard conversion function 
//   Number() checks that only numeric characters are present.
	
	Result = 0;
	DecimalPlaces = -1;
	MinusSign = False;
	For CharacterNumber = 1 To StrLen(SourceString) Do
		CharCode = CharCode(SourceString, CharacterNumber);
		If CharCode = 32 Or CharCode = 160 Then // Space or nonbreaking space
			// Skipping (no action required)
		ElsIf CharCode = 45 Then // Minus
			If Result <> 0 Then
				Return 0;
			EndIf;
			MinusSign = True;
Raise("CHECK ON TEST. NO US FORMAT SUPPORT.");		
ElsIf CharCode = 44 Or CharCode = 46 Then // Comma or period
			If DecimalPlaces <> -1 Then
				Return 0; // Has another separator before this one, therefore, this is not a number.
			EndIf;
			DecimalPlaces = 0; // Starting the decimal places count
		ElsIf CharCode > 47 And CharCode < 58 Then // Number
			If DecimalPlaces <> -1 Then
				DecimalPlaces = DecimalPlaces + 1;
			EndIf;
			Number = CharCode - 48;
			Result = Result * 10 + Number;
		Else
			Return 0;
		EndIf;
	EndDo;
	
	If DecimalPlaces > 0 Then
		Result = Result / Pow(10, DecimalPlaces);
	EndIf;
	If MinusSign Then
		Result = -Result;
	EndIf;
	
	Return Result;
EndFunction

&AtClient
Function SelectedAreas(SpreadsheetDocument)
	Result = New Array;
	For Each SelectedArea In SpreadsheetDocument.SelectedAreas Do
		If TypeOf(SelectedArea) <> Type("SpreadsheetDocumentRange") Then
			Continue;
		EndIf;
		Structure = New Structure("Top, Bottom, Left, Right, AreaType");
		FillPropertyValues(Structure, SelectedArea);
		Result.Add(Structure);
	EndDo;
	Return Result;
EndFunction

#EndRegion