 
// This procedure gets the list of saved settings for the passed forms
//
// Parameters:
//  User - the user name, forms settings for which to Get
//  FormsWithSavedParametersList - the list of values in which the forms settings will be added to.
Procedure GetSavedSettingsList(User, FormsWithSavedSettingsList) Export
	
	Var Presentation;
	Var Picture;
	
	SettingType = "/FormSettings";
	SettingTypeStringLength = StrLen(SettingType);
	FilterCriterion = New Structure("User", User);
	SettingsSelection = SystemSettingsStorage.Select(FilterCriterion);
	
	While SettingsSelection.Next() Do
		
		If Right(SettingsSelection.ObjectKey, SettingTypeStringLength) = SettingType Then
		
			Presentation = "";
			Picture = Undefined;
			
			FirstSlash = Find(SettingsSelection.ObjectKey, "/");
			MetadataNameForm = Left(SettingsSelection.ObjectKey, FirstSlash - 1);			
			
			FormMetadataNameParts = StrReplace(MetadataNameForm, ".", Chars.LF);
			NamePartsLength = StrLineCount(FormMetadataNameParts);
			
			If NamePartsLength > 1 Then
				
				MetadataClassName = StrGetLine(FormMetadataNameParts, 1);
				MetadataObjectName = StrGetLine(FormMetadataNameParts, 2);
				Picture = GetMetadataClassPicture(MetadataClassName);
				
				MetadataObjectName = MetadataClassName + "." + MetadataObjectName;
				MetadataObject = Metadata.FindByFullName(MetadataObjectName);
				
				If MetadataObject <> Undefined Then
					Presentation = MetadataClassName + ". " + MetadataObject.Presentation() + ". ";
				Else
					Presentation = MetadataClassName + ". " + MetadataObjectName + ". ";
				EndIf;
			
				MetadataObjectForm = Metadata.FindByFullName(MetadataNameForm);
				
				If MetadataObjectForm <> Undefined Then
					Presentation = Presentation + MetadataObjectForm.Presentation();
				Else
					Presentation = Presentation + StrGetLine(FormMetadataNameParts, NamePartsLength);
				EndIf;
				
			Else
				
				Presentation = MetadataNameForm;
				
			EndIf;
			
			FormsWithSavedSettingsList.Add(MetadataNameForm, Presentation, False, Picture);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// This function gets picture for the metadata class
//
// Parameters:
//  MetadataClassName - the name of metadata class, for which the picture is requested
// Returns:
//  Picture of the metadata class
Function GetMetadataClassPicture(MetadataClassName)
	
	If MetadataClassName = "Catalog" Then
		Return PictureLib.Catalog;
	ElsIf MetadataClassName = "FilterCriterion" Then
		Return PictureLib.FilterCriterion;
	ElsIf MetadataClassName = "SettingsStorage" Then
		Return PictureLib.SettingsStorage;
	ElsIf MetadataClassName = "Document" Then
		Return PictureLib.Document;
	ElsIf MetadataClassName = "DocumentJournal" Then
		Return PictureLib.DocumentJournal;
	ElsIf MetadataClassName = "Enum" Then
		Return PictureLib.Enum;
	ElsIf MetadataClassName = "Report" Then
		Return PictureLib.Report;
	ElsIf MetadataClassName = "DataProcessor" Then
		Return PictureLib.DataProcessor;
	ElsIf MetadataClassName = "InformationRegister" Then
		Return PictureLib.InformationRegister;
	ElsIf MetadataClassName = "AccumulationRegister" Then
		Return PictureLib.AccumulationRegister;
	ElsIf MetadataClassName = "ChartOfCharacteristicTypes" Then
		Return PictureLib.ChartOfCharacteristicTypes;
	ElsIf MetadataClassName = "ChartOfAccounts" Then
		Return PictureLib.ChartOfAccounts;
	ElsIf MetadataClassName = "AccountingRegister" Then
		Return PictureLib.AccountingRegister;
	ElsIf MetadataClassName = "ChartOfCalculationTypes" Then
		Return PictureLib.ChartOfCalculationTypes;
	ElsIf MetadataClassName = "CalculationRegister" Then
		Return PictureLib.CalculationRegister;
	ElsIf MetadataClassName = "BusinessProcess" Then
		Return PictureLib.BusinessProcess;
	ElsIf MetadataClassName = "Task" Then
		Return PictureLib.Task;
	EndIf;
	
EndFunction
 
// This procedure allows to forms settings from one user to another
//
// Parameters:
//  UserSource - the user name, whos forms settings are copied
//  UsersReceiver - the user name, which to copy the forms settings
//  ParametersArrayToCopy - form names, which settings to copy
Procedure CopyFormSettings(UserSource, UsersReceiver, SettingsArrayToCopy) Export
	
	For Each Element In SettingsArrayToCopy Do
		
		Settings = SystemSettingsStorage.Load(Element + "/FormSettings", "", , UserSource);
		
		If Settings <> Undefined Then
			
			For Each UserReceiver In UsersReceiver Do
				
				SystemSettingsStorage.Save(Element + "/FormSettings", "", Settings, , UserReceiver);
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// This procedure allows you to delete forms settings
//
// Parameters:
//  User - the user name the forms settings for which to delete
//  ParametersForDeletionArray - form names, settings for which to delete
Procedure DeleteFormSettings(User, SettingsForDeletionArray) Export
	
	For Each Element In SettingsForDeletionArray Do
		
		SystemSettingsStorage.Delete(Element + "/FormSettings", "", User);
		
	EndDo;
	
EndProcedure