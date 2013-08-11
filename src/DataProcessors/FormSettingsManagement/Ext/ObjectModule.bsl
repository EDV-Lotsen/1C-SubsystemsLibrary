////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Export internal procedure and function

// Gets the common form list and fills the following fields:
//  Value        - form name, this name identifies the form;
//  Presentation - form synonym;
//  Picture      - picture corresponds to the object that form is related to.
// Parameters:
//  List         - ValueList - form discription will be added to this list.
//
Procedure GetFormList(List) Export
	
	For Each Form In Metadata.CommonForms Do
		
		List.Add("CommonForm." + Form.Name, "Common Form." + Form.Synonym, False, PictureLib.Form);
		
	EndDo;

	StandardFormNames = New ValueList;
	StandardFormNames.Add("ObjectForm", "Object form");
	StandardFormNames.Add("FolderForm", "Folder form");
	StandardFormNames.Add("ListForm", "List form");
	StandardFormNames.Add("ChoiceForm", "Choice form");
	StandardFormNames.Add("FolderChoiceForm", "Folder choise form");
	GetMetadataObjectFormList(Metadata.Catalogs, "Catalog", "Catalog", StandardFormNames, PictureLib.Catalog, List);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("Form", "Form");
	GetMetadataObjectFormList(Metadata.FilterCriteria, "FilterCriterion", "Filter criterion", StandardFormNames, PictureLib.FilterCriterion, List);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("SaveForm", "Save form");
	StandardFormNames.Add("LoadForm", "Load form");
	GetMetadataObjectFormList(Metadata.SettingsStorages, "SettingsStorage", "Settings storage", StandardFormNames, PictureLib.SettingsStorage, List);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ObjectForm", "Object form");
	StandardFormNames.Add("ListForm", "List form");
	StandardFormNames.Add("ChoiceForm", "Choice form");
	GetMetadataObjectFormList(Metadata.Documents, "Document", "Document", StandardFormNames, PictureLib.Document, List);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("Form", "Form");
	GetMetadataObjectFormList(Metadata.DocumentJournals, "DocumentJournal", "Document journal", StandardFormNames, PictureLib.DocumentJournal, List);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ListForm", "List form");
	StandardFormNames.Add("ChoiceForm", "Choice form");
	GetMetadataObjectFormList(Metadata.Enums, "Enumeration", "Enumeration", StandardFormNames, PictureLib.Enum, List);

	StandardFormNames = New ValueList;
	StandardFormNames.Add("Form", "Form");
	StandardFormNames.Add("SettingsForm", "Settings form");
	StandardFormNames.Add("VariantForm", "Variant form");
	GetMetadataObjectFormList(Metadata.Reports, "Report", "Report", StandardFormNames, PictureLib.Report, List);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("Form", "Form");
	GetMetadataObjectFormList(Metadata.DataProcessors, "DataProcessor", "Data processor", StandardFormNames, PictureLib.DataProcessor, List);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("RecordForm", "Record form");
	StandardFormNames.Add("ListForm", "List form");
	GetMetadataObjectFormList(Metadata.InformationRegisters, "InformationRegister", "Information register", StandardFormNames, PictureLib.InformationRegister, List);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ListForm", "List form");
	GetMetadataObjectFormList(Metadata.AccumulationRegisters, "AccumulationRegister", "Accumulation register", StandardFormNames, PictureLib.AccumulationRegister, List);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ObjectForm", "Object form");
	StandardFormNames.Add("FolderForm", "Folder form");
	StandardFormNames.Add("ListForm", "List form");
	StandardFormNames.Add("ChoiceForm", "Choice form");
	StandardFormNames.Add("FolderChoiceForm", "Folder choice form");
	GetMetadataObjectFormList(Metadata.ChartsOfCharacteristicTypes, "ChartOfCharacteristicTypes", "Chart of characteristic types", StandardFormNames, PictureLib.ChartOfCharacteristicTypes, List);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ObjectForm", "Object form");
	StandardFormNames.Add("ListForm", "List form");
	StandardFormNames.Add("ChoiceForm", "Choice form");
	GetMetadataObjectFormList(Metadata.ChartsOfAccounts, "ChartOfAccounts", "Plan Accounts", StandardFormNames, PictureLib.ChartOfAccounts, List);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ListForm", "List form");
	GetMetadataObjectFormList(Metadata.AccountingRegisters, "AccountingRegister", "Accounting register", StandardFormNames, PictureLib.AccountingRegister, List);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ObjectForm", "Object form");
	StandardFormNames.Add("ListForm", "List form");
	StandardFormNames.Add("ChoiceForm", "Choice form");
	GetMetadataObjectFormList(Metadata.ChartsOfCalculationTypes, "ChartOfCalculationTypes", "Chart of calculation types", StandardFormNames, PictureLib.ChartOfCalculationTypes, List);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ListForm", "List form");
	GetMetadataObjectFormList(Metadata.CalculationRegisters, "CalculationRegister", "Calculation register", StandardFormNames, PictureLib.CalculationRegister, List);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ObjectForm", "Object form");
	StandardFormNames.Add("ListForm", "List form");
	StandardFormNames.Add("ChoiceForm", "Choice form");
	GetMetadataObjectFormList(Metadata.BusinessProcesses, "BusinessProcess", "Business process", StandardFormNames, PictureLib.BusinessProcess, List);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ObjectForm", "Object form");
	StandardFormNames.Add("ListForm", "List form");
	StandardFormNames.Add("ChoiceForm", "Choice form");
	GetMetadataObjectFormList(Metadata.Tasks, "Task", "Task", StandardFormNames, PictureLib.Task, List);
	
EndProcedure

// Gets forms that have saved settings for a user passed to the User parameter.
// The selected forms are recorded to the FormsWithSavedSettingsList parameter.
//
//
Procedure GetSavedSettingsList(FormsList, User, FormsWithSavedSettingsList) Export
	
	For Each Item In FormsList Do
		
		Added = False;
		
		Details = SystemSettingsStorage.GetDescription(Item.Value + "/FormSettings", , User);
		
		If Details <> Undefined Then
			FormsWithSavedSettingsList.Add(Item.Value, Item.Presentation, Item.Check, Item.Picture);
			Added = True;
		EndIf;
		
		Details = SystemSettingsStorage.GetDescription(Item.Value + "/WindowSettings", , User);
		If Details <> Undefined And Not Added Then
			FormsWithSavedSettingsList.Add(Item.Value, Item.Presentation, Item.Check, Item.Picture);
		EndIf;
		
	EndDo;
	
EndProcedure

// Copies settings of one user to another.
// Parameters
// UserSource          - String - Infobase user name. This user settings will be copied.
// UsersTarget         - String - Infobase user name. Settings will be copied to this user.
// SettingsToCopyArray - Array of String. Each string is a full form name.
//
Procedure CopyFormSettings(UserSource, UsersTarget, SettingsToCopyArray) Export
	
	For Each Item In SettingsToCopyArray Do
		Setting = SystemSettingsStorage.Load(Item + "/FormSettings", "", , UserSource);
		If Setting <> Undefined Then
			For Each UserTarget In UsersTarget Do
				SystemSettingsStorage.Save(Item + "/FormSettings", "", Setting, , UserTarget);
			EndDo;
		EndIf;
		Setting = SystemSettingsStorage.Load(Item + "/WindowSettings", "", , UserSource);
		If Setting <> Undefined Then
			For Each UserTarget In UsersTarget Do
				SystemSettingsStorage.Save(Item + "/WindowSettings", "", Setting, , UserTarget);
			EndDo;
		EndIf;
	EndDo;
	
EndProcedure

// Clears all user settings that are related to forms
// User                - String - Infobase user name
// SettingsToCopyArray - Array of String. Each string is a full form name.
//
Procedure DeleteFormSettings(User, SettingsForDeletionArray) Export
	
	For Each Item In SettingsForDeletionArray Do
		SystemSettingsStorage.Delete(Item + "/FormSettings", "", User);
		SystemSettingsStorage.Delete(Item + "/WindowSettings", "", User);
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions

Procedure GetFormListFromFormMetadataList(Prefix, PresentationPrefix, FormMetadata, Picture, List)
	
	For Each Form In FormMetadata Do
		
		List.Add(Prefix + ".Form." + Form.Name, PresentationPrefix + "." + Form.Synonym, False, Picture);
		
	EndDo;
	
EndProcedure

Procedure AddStandardForm(Prefix, PresentationPrefix, MetadataObject, FormName, FormPresentation, Picture, List)
	
	If MetadataObject["Default" + FormName] = Undefined Then
		
		List.Add(Prefix + "." + FormName, PresentationPrefix + "." + FormPresentation, False, Picture);
		
	EndIf;
	
EndProcedure

Procedure GetMetadataObjectFormList(MetadataObjectList, MetadataObjectName, MetadataObjectPresentation, StandardFormNames, Picture, List)
	
	For Each Object In MetadataObjectList Do
		
		Prefix = MetadataObjectName + "." + Object.Name;
		PresentationPrefix = MetadataObjectPresentation + "." + Object.Synonym;
		
		GetFormListFromFormMetadataList(Prefix, PresentationPrefix, Object.Forms, Picture, List);
		
		For Each StandardFormName In StandardFormNames Do
			
			AddStandardForm(Prefix, PresentationPrefix, Object, StandardFormName.Value, StandardFormName.Presentation, Picture, List);
			
		EndDo;
		
	EndDo;
	
EndProcedure