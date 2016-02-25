&AtClient
Var ChoiceContext;

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	FillPrintFormTemplateTable();
	If Parameters.Property("ShowOnlyUserChanges") Then
		FilterByUsingTemplate = "ModifiedItemsToUse";
	Else
		FilterByUsingTemplate = Items.FilterByUsingTemplate.ChoiceList[0].Value;
	EndIf;
	
	PromptForTemplateOpeningMode = CommonUse.CommonSettingsStorageLoad(
		"TemplateOpeningSettings", "PromptForTemplateOpeningMode", True);
	TemplateOpeningModeView = CommonUse.CommonSettingsStorageLoad(
		"TemplateOpeningSettings", "TemplateOpeningModeView", False);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_UserPrintTemplates" Then
		UpdateTemplateRepresentation(Parameter.TemplateMetadataObjectName);
	ElsIf EventName = "Write_SpreadsheetDocument" And Source.FormOwner = ThisObject Then
		Template = Parameter.SpreadsheetDocument;
		TemplateAddressInTempStorage = PutToTempStorage(Template);
		SaveTemplate(Parameter.TemplateMetadataObjectName, TemplateAddressInTempStorage);
		UpdateTemplateRepresentation(Parameter.TemplateMetadataObjectName)
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("InformationRegister.UserPrintTemplates.Form.TemplateOpeningModeSelection") Then
		
		If TypeOf(SelectedValue) <> Type("Structure") Then
			Return;
		EndIf;
		
		TemplateOpeningModeView = SelectedValue.OpeningModeBrowse;
		PromptForTemplateOpeningMode = Not SelectedValue.DontAskAgain;
		
		If ChoiceContext = "OpenPrintFormTemplate" Then
			
			If SelectedValue.DontAskAgain Then
				SaveOpenTemplateModeSettings(PromptForTemplateOpeningMode, TemplateOpeningModeView);
			EndIf;
			
			If TemplateOpeningModeView Then
				OpenPrintFormTemplateForViewing();
			Else
				OpenPrintFormTemplateForEdit();
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	Parameter = New Structure("Cancel", False);
	Notify("OwnerFormClosing", Parameter, ThisObject);
	
	If Parameter.Cancel Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	SetTemplateFilter();
EndProcedure

#EndRegion

#Region PrintFormTemplatesFormTableItemEventHandlers

&AtClient
Procedure PrintFormTemplatesSelection(Item, SelectedRow, Field, StandardProcessing)
	OpenPrintFormTemplate();
EndProcedure

&AtClient
Procedure PrintFormTemplatesOnActivateRow(Item)
	SetCommandBarButtonsEnabled();
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ChangeTemplate(Command)
	OpenPrintFormTemplateForEdit();
EndProcedure

&AtClient
Procedure OpenTemplate(Command)
	OpenPrintFormTemplateForViewing();
EndProcedure

&AtClient
Procedure UseModifiedTemplate(Command)
	SwitchSelectedTemplatesUse(True);
EndProcedure

&AtClient
Procedure UseStandardTemplate(Command)
	SwitchSelectedTemplatesUse(False);
EndProcedure

&AtClient
Procedure SetActionOnChoosePrintFormTemplate(Command)
	
	ChoiceContext = "SetActionOnChoosePrintFormTemplate";
	OpenForm("InformationRegister.UserPrintTemplates.Form.TemplateOpeningModeSelection", , ThisObject);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// Initial filling

&AtServer
Procedure FillPrintFormTemplateTable()
	
	MetadataObjectCollections = New Array;
	MetadataObjectCollections.Add(Metadata.Catalogs);
	MetadataObjectCollections.Add(Metadata.Documents);
	MetadataObjectCollections.Add(Metadata.DataProcessors);
	MetadataObjectCollections.Add(Metadata.BusinessProcesses);
	MetadataObjectCollections.Add(Metadata.Tasks);
	MetadataObjectCollections.Add(Metadata.DocumentJournals);
	
	For Each MetadataObjectCollection In MetadataObjectCollections Do
		For Each CollectionMetadataObject In MetadataObjectCollection Do
			For Each MetadataObjectTemplate In CollectionMetadataObject.Templates Do
				TemplateType = TemplateType(MetadataObjectTemplate.Name);
				If TemplateType = Undefined Then
					Continue;
				EndIf;
				AddTemplateDetails(CollectionMetadataObject.FullName() + "." + MetadataObjectTemplate.Name, MetadataObjectTemplate.Synonym, CollectionMetadataObject.Synonym, TemplateType);
			EndDo;
		EndDo;
	EndDo;
	
	For Each MetadataObjectTemplate In Metadata.CommonTemplates Do
		TemplateType = TemplateType(MetadataObjectTemplate.Name);
		If TemplateType = Undefined Then
			Continue;
		EndIf;
		AddTemplateDetails("CommonTemplate." + MetadataObjectTemplate.Name, MetadataObjectTemplate.Synonym, NStr("en = 'Common template'"), TemplateType);
	EndDo;
	
	PrintFormTemplates.Sort("TemplatePresentation Asc");
	
	SetModifiedTemplatesUsageFlags();
EndProcedure

&AtServer
Function AddTemplateDetails(TemplateMetadataObjectName, TemplatePresentation, OwnerPresentation, TemplateType)
	TemplateDetails = PrintFormTemplates.Add();
	TemplateDetails.TemplateType = TemplateType;
	TemplateDetails.TemplateMetadataObjectName = TemplateMetadataObjectName;
	TemplateDetails.OwnerPresentation = OwnerPresentation;
	TemplateDetails.TemplatePresentation = TemplatePresentation;
	TemplateDetails.Picture = PictureIndex(TemplateType);
	TemplateDetails.SearchString = TemplateMetadataObjectName + " "
								+ OwnerPresentation + " "
								+ TemplatePresentation + " "
								+ TemplateType;
	Return TemplateDetails;
EndFunction

&AtServer
Procedure SetModifiedTemplatesUsageFlags()
	
	QueryText =
	"SELECT
	|	ModifiedTemplates.TemplateName,
	|	ModifiedTemplates.Object,
	|	ModifiedTemplates.Use
	|FROM
	|	InformationRegister.UserPrintTemplates AS ModifiedTemplates";
	
	Query = New Query(QueryText);
	ModifiedTemplates = Query.Execute().Unload();
	For Each Template In ModifiedTemplates Do
		TemplateMetadataObjectName = Template.Object + "." + Template.TemplateName;
		FoundRows = PrintFormTemplates.FindRows(New Structure("TemplateMetadataObjectName", TemplateMetadataObjectName));
		For Each TemplateDetails In FoundRows Do
			TemplateDetails.Modified = True;
			TemplateDetails.ModifiedItemUsed = Template.Use;
			TemplateDetails.UsePicture = Number(TemplateDetails.Modified) + Number(TemplateDetails.ModifiedItemUsed);
		EndDo;
	EndDo;
	
EndProcedure

&AtServer
Function TemplateType(TemplateMetadataObjectName)
	
	TemplateTypes = New Array;
	TemplateTypes.Add("MXL");
	TemplateTypes.Add("DOC");
	TemplateTypes.Add("ODT");
	
	For Each TemplateType In TemplateTypes Do
		Position = Find(TemplateMetadataObjectName, "FF_" + TemplateType);
		If Position > 0 Then
			Return TemplateType;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction

&AtServer
Function PictureIndex(Val TemplateType)
	
	TemplateTypes = New Array;
	TemplateTypes.Add("DOC");
	TemplateTypes.Add("ODT");
	TemplateTypes.Add("MXL");
	
	Result = TemplateTypes.Find(Upper(TemplateType));
	Return ?(Result = Undefined, -1, Result);
	
EndFunction 

// Filters

&AtClient
Procedure SetTemplateFilter(Text = Undefined);
	If Text = Undefined Then
		Text = SearchString;
	EndIf;
	
	FilterStructure = New Structure;
	FilterStructure.Insert("SearchString", TrimAll(Text));
	If FilterByUsingTemplate = "Modified" Then
		FilterStructure.Insert("Changed", True);
	ElsIf FilterByUsingTemplate = "NotModified" Then
		FilterStructure.Insert("Changed", False);
	ElsIf FilterByUsingTemplate = "ModifiedItemsToUse" Then
		FilterStructure.Insert("ChangedTemplateUsed", True);
	ElsIf FilterByUsingTemplate = "ModifiedItemsNotToUse" Then
		FilterStructure.Insert("ChangedTemplateUsed", False);
		FilterStructure.Insert("Changed", True);
	EndIf;
	
	Items.PrintFormTemplates.RowFilter = New FixedStructure(FilterStructure);
	SetCommandBarButtonsEnabled();
EndProcedure

&AtClient
Procedure SearchStringAutoComplete(Item, Text, ChoiceData, Waiting, StandardProcessing)
	SetTemplateFilter(Text);
EndProcedure

&AtClient
Procedure SearchStringClearing(Item, StandardProcessing)
	SetTemplateFilter();
EndProcedure

&AtClient
Procedure SearchStringOnChange(Item)
	SetTemplateFilter();
	If Items.SearchString.ChoiceList.FindByValue(SearchString) = Undefined Then
		Items.SearchString.ChoiceList.Add(SearchString);
	EndIf;
EndProcedure

&AtClient
Procedure FilterByUsedOnChangeTemplateType(Item)
	SetTemplateFilter();
EndProcedure

&AtClient
Procedure FilterByUsingTemplateClearing(Item, StandardProcessing)
	StandardProcessing = False;
	FilterByUsingTemplate = Items.FilterByUsingTemplate.ChoiceList[0].Value;
	SetTemplateFilter();
EndProcedure

// Opening a template

&AtClient
Procedure OpenPrintFormTemplate()
	
	If PromptForTemplateOpeningMode Then
		ChoiceContext = "OpenPrintFormTemplate";
		OpenForm("InformationRegister.UserPrintTemplates.Form.TemplateOpeningModeSelection", , ThisObject);
		Return;
	EndIf;
	
	If TemplateOpeningModeView Then
		OpenPrintFormTemplateForViewing();
	Else
		OpenPrintFormTemplateForEdit();
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenPrintFormTemplateForViewing()
	
	CurrentData = Items.PrintFormTemplates.CurrentData;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("TemplateMetadataObjectName", CurrentData.TemplateMetadataObjectName);
	OpenParameters.Insert("TemplateType", CurrentData.TemplateType);
	OpenParameters.Insert("OpenOnly", True);
	#If WebClient Then
	OpenParameters.Insert("IsWebClient", True);
	#EndIf
	
	#If Not WebClient Then
	If CurrentData.TemplateType = "MXL" Then
		OpenParameters.Insert("DocumentName", CurrentData.TemplatePresentation);
		OpenForm("CommonForm.SpreadsheetDocumentEditing", OpenParameters, ThisObject);
		Return;
	EndIf;
	#EndIf
	
	OpenForm("InformationRegister.UserPrintTemplates.Form.EditTemplate", OpenParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure OpenPrintFormTemplateForEdit()
	
	CurrentData = Items.PrintFormTemplates.CurrentData;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("TemplateMetadataObjectName", CurrentData.TemplateMetadataObjectName);
	OpenParameters.Insert("TemplateType", CurrentData.TemplateType);
	#If WebClient Then
	OpenParameters.Insert("IsWebClient", True);
	#EndIf
	
	#If Not WebClient Then
	If CurrentData.TemplateType = "MXL" Then
		OpenParameters.Insert("DocumentName", CurrentData.TemplatePresentation);
		OpenParameters.Insert("Edit", True);
		OpenForm("CommonForm.SpreadsheetDocumentEditing", OpenParameters, ThisObject);
		Return;
	EndIf;
	#EndIf
	
	OpenForm("InformationRegister.UserPrintTemplates.Form.EditTemplate", OpenParameters, ThisObject);
	
EndProcedure

&AtServerNoContext
Procedure SaveOpenTemplateModeSettings(PromptForTemplateOpeningMode, TemplateOpeningModeView)
	
	CommonUse.CommonSettingsStorageSave("TemplateOpeningSettings",
		"PromptForTemplateOpeningMode", PromptForTemplateOpeningMode);
	
	CommonUse.CommonSettingsStorageSave("TemplateOpeningSettings",
		"TemplateOpeningModeView", TemplateOpeningModeView);
	
EndProcedure

// Actions with templates

&AtClient
Procedure SwitchSelectedTemplatesUse(ModifiedItemUsed)
	TemplatesToSwitch = New Array;
	For Each SelectedRow In Items.PrintFormTemplates.SelectedRows Do
		CurrentData = Items.PrintFormTemplates.RowData(SelectedRow);
		If CurrentData.Modified Then
			CurrentData.ModifiedItemUsed = ModifiedItemUsed;
			SetUsePicture(CurrentData);
			TemplatesToSwitch.Add(CurrentData.TemplateMetadataObjectName);
		EndIf;
	EndDo;
	SetUseModifiedTemplates(TemplatesToSwitch, ModifiedItemUsed);
	SetCommandBarButtonsEnabled();
EndProcedure

&AtServerNoContext
Procedure SetUseModifiedTemplates(Templates, ModifiedItemUsed)
	
	For Each TemplateMetadataObjectName In Templates Do
		NameParts = StringFunctionsClientServer.SplitStringIntoSubstringArray(TemplateMetadataObjectName, ".");
		TemplateName = NameParts[NameParts.UBound()];
		
		OwnerName = "";
		For PartNumber = 0 To NameParts.UBound()-1 Do
			If Not IsBlankString(OwnerName) Then
				OwnerName = OwnerName + ".";
			EndIf;
			OwnerName = OwnerName + NameParts[PartNumber];
		EndDo;
		
		Write = InformationRegisters.UserPrintTemplates.CreateRecordManager();
		Write.Object = OwnerName;
		Write.TemplateName = TemplateName;
		Write.Read();
		If Write.Selected() Then
			Write.Use = ModifiedItemUsed;
			Write.Write();
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure DeleteSelectedModifiedTemplates(Command)
	TemplatesToDelete = New Array;
	For Each SelectedRow In Items.PrintFormTemplates.SelectedRows Do
		CurrentData = Items.PrintFormTemplates.RowData(SelectedRow);
		CurrentData.ModifiedItemUsed = False;
		CurrentData.Modified = False;
		SetUsePicture(CurrentData);
		TemplatesToDelete.Add(CurrentData.TemplateMetadataObjectName);
	EndDo;
	DeleteModifiedTemplates(TemplatesToDelete);
	SetCommandBarButtonsEnabled();
EndProcedure

&AtServerNoContext
Procedure DeleteModifiedTemplates(TemplatesToDelete)
	
	For Each TemplateMetadataObjectName In TemplatesToDelete Do
		NameParts = StringFunctionsClientServer.SplitStringIntoSubstringArray(TemplateMetadataObjectName, ".");
		TemplateName = NameParts[NameParts.UBound()];
		
		OwnerName = "";
		For PartNumber = 0 To NameParts.UBound()-1 Do
			If Not IsBlankString(OwnerName) Then
				OwnerName = OwnerName + ".";
			EndIf;
			OwnerName = OwnerName + NameParts[PartNumber];
		EndDo;
		
		RecordManager = InformationRegisters.UserPrintTemplates.CreateRecordManager();
		RecordManager.Object = OwnerName;
		RecordManager.TemplateName = TemplateName;
		RecordManager.Delete();
	EndDo;
	
EndProcedure

&AtServerNoContext
Procedure SaveTemplate(TemplateMetadataObjectName, TemplateAddressInTempStorage)
	PrintManagement.SaveTemplate(TemplateMetadataObjectName, TemplateAddressInTempStorage);
EndProcedure

&AtClient
Procedure UpdateTemplateRepresentation(TemplateMetadataObjectName);
	
	FoundTemplates = PrintFormTemplates.FindRows(New Structure("TemplateMetadataObjectName", TemplateMetadataObjectName));
	For Each Template In FoundTemplates Do
		Template.Modified = True;
		Template.ModifiedItemUsed = True;
		SetUsePicture(Template);
	EndDo;
	
	SetCommandBarButtonsEnabled();
	
EndProcedure

// General

&AtClient
Procedure SetUsePicture(TemplateDetails)
	TemplateDetails.UsePicture = Number(TemplateDetails.Modified) + Number(TemplateDetails.ModifiedItemUsed);
EndProcedure

&AtClient
Procedure SetCommandBarButtonsEnabled()
	
	CurrentTemplate = Items.PrintFormTemplates.CurrentData;
	CurrentTemplateSelected = CurrentTemplate <> Undefined;
	SeveralTemplatesSelected = Items.PrintFormTemplates.SelectedRows.Count() > 1;
	
	Items.PrintFormTemplatesOpenTemplate.Enabled = CurrentTemplateSelected And Not SeveralTemplatesSelected;
	Items.PrintFormTemplatesChangeTemplate.Enabled = CurrentTemplateSelected And Not SeveralTemplatesSelected;
	
	UseModifiedTemplateEnabled = False;
	UseStandardTemplateEnabled = False;
	DeleteModifiedTemplateEnabled = False;
	
	For Each SelectedRow In Items.PrintFormTemplates.SelectedRows Do
		CurrentTemplate = Items.PrintFormTemplates.RowData(SelectedRow);
		UseModifiedTemplateEnabled = CurrentTemplateSelected And CurrentTemplate.Modified And Not CurrentTemplate.ModifiedItemUsed Or SeveralTemplatesSelected And UseModifiedTemplateEnabled;
		UseStandardTemplateEnabled = CurrentTemplateSelected And CurrentTemplate.Modified And CurrentTemplate.ModifiedItemUsed Or SeveralTemplatesSelected And UseStandardTemplateEnabled;
		DeleteModifiedTemplateEnabled = CurrentTemplateSelected And CurrentTemplate.Modified Or SeveralTemplatesSelected And DeleteModifiedTemplateEnabled;
	EndDo;
	
	Items.PrintFormTemplatesUseModifiedTemplate.Enabled = UseModifiedTemplateEnabled;
	Items.PrintFormTemplatesUseStandardTemplate.Enabled = UseStandardTemplateEnabled;
	Items.PrintFormTemplatesDeleteModifiedTemplate.Enabled = DeleteModifiedTemplateEnabled;
	
EndProcedure

#EndRegion
