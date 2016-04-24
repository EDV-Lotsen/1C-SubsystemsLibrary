
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
  // Skipping the initialization to guarantee that the form will be 
  // received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	FillPropertyValues(Object, Parameters.Object , , "AllDocumentsFilterComposer, AdditionalRegistration, AdditionalNodeScenarioRegistration");
	For Each Row In Parameters.Object.AdditionalRegistration Do
		FillPropertyValues(Object.AdditionalRegistration.Add(), Row);
	EndDo;
	For Each Row In Parameters.Object.AdditionalNodeScenarioRegistration Do
		FillPropertyValues(Object.AdditionalNodeScenarioRegistration.Add(), Row);
	EndDo;
	
	// Initializing settings composer
	DataProcessorObject = FormAttributeToValue("Object");
	
	Data = GetFromTempStorage(Parameters.Object.AllDocumentsComposerAddress);
	DataProcessorObject.AllDocumentsFilterComposer = New DataCompositionSettingsComposer;
	DataProcessorObject.AllDocumentsFilterComposer.Initialize(
		New DataCompositionAvailableSettingsSource(Data.CompositionSchema));
	DataProcessorObject.AllDocumentsFilterComposer.LoadSettings(Data.Settings);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
	CurrentSettingsItemPresentation = Parameters.CurrentSettingsItemPresentation;
	ReadSavedSettings();
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersSettingsVariant

&AtClient
Procedure SettingsVariantsChoice(Item, SelectedRow, Field, StandardProcessing)
	CurrentData = SettingVariants.FindByID(SelectedRow);
	If CurrentData<>Undefined Then
		CurrentSettingsItemPresentation = CurrentData.Presentation;
	EndIf;
EndProcedure

&AtClient
Procedure SettingsVariantsBeforeAdd(Item, Cancel, Copy, Parent, Group)
	Cancel = True;
EndProcedure

&AtClient
Procedure SettingsVariantsBeforeDelete(Item, Cancel)
	Cancel = True;
	
	SettingsItemPresentation = Item.CurrentData.Presentation;
	
	TitleText = NStr("en='Confirmation'");
	QuestionText   = NStr("en='Do you want to delete ""%1"" settings?'");
	
	QuestionText = StrReplace(QuestionText, "%1", SettingsItemPresentation);
	
	AdditionalParameters = New Structure("SettingsItemPresentation", SettingsItemPresentation);
	NotifyDescription = New NotifyDescription("DeleteSettingsVariantRequestNotification", ThisObject, 
		AdditionalParameters);
	
	ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo,,,TitleText);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SaveSettings(Command)
	
	If IsBlankString(CurrentSettingsItemPresentation) Then
		CommonUseClientServer.MessageToUser(
			NStr("en='Enter a name for the current settings.'"), , "CurrentSettingsItemPresentation");
		Return;
	EndIf;
		
	If SettingVariants.FindByValue(CurrentSettingsItemPresentation)<>Undefined Then
		TitleText = NStr("en='Confirmation'");
		QuestionText   = NStr("en='Do you want to overwrite ""%1"" settings?'");
		QuestionText = StrReplace(QuestionText, "%1", CurrentSettingsItemPresentation);
		
		AdditionalParameters = New Structure("SettingsItemPresentation", CurrentSettingsItemPresentation);
		NotifyDescription = New NotifyDescription("SaveSettingsVariantRequestNotification", ThisObject, 
			AdditionalParameters);
			
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo,,,TitleText);
		Return;
	EndIf;
	
	// Saving without displaying a question
	SaveAndExecuteCurrentSettingSelection();
EndProcedure
	
&AtClient
Procedure MakeSelection(Command)
	ExecuteSelection(CurrentSettingsItemPresentation);
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Function ThisObject(NewObject=Undefined)
	If NewObject=Undefined Then
		Return FormAttributeToValue("Object");
	EndIf;
	ValueToFormAttribute(NewObject, "Object");
	Return Undefined;
EndFunction

&AtServer
Procedure DeleteSettingsServer(SettingsItemPresentation)
	ThisObject().DeleteSettingsVariant(SettingsItemPresentation);
EndProcedure

&AtServer
Procedure ReadSavedSettings()
	ThisDataProcessor = ThisObject();
	
	VariantFilter = DataExchangeServer.InteractiveExportModificationVariantFilter(Object);
	SettingVariants = ThisDataProcessor.ReadSettingsListPresentations(Object.InfobaseNode, VariantFilter);
	
	ListItem = SettingVariants.FindByValue(CurrentSettingsItemPresentation);
	Items.SettingVariants.CurrentRow = ?(ListItem=Undefined, Undefined, ListItem.GetID())
EndProcedure

&AtServer
Procedure SaveCurrentSettings()
	ThisObject().SaveCurrentValuesInSettings(CurrentSettingsItemPresentation);
EndProcedure

&AtClient
Procedure ExecuteSelection(Presentation)
	If SettingVariants.FindByValue(Presentation)<>Undefined And CloseOnChoice Then 
		NotifyChoice( New Structure("ChoiceAction, SettingsItemPresentation", 3, Presentation) );
	EndIf;
EndProcedure

&AtClient
Procedure DeleteSettingsVariantRequestNotification(Result, AdditionalParameters) Export
	If Result<>DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	DeleteSettingsServer(AdditionalParameters.SettingsItemPresentation);
	ReadSavedSettings();
EndProcedure

&AtClient
Procedure SaveSettingsVariantRequestNotification(Result, AdditionalParameters) Export
	If Result<>DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	CurrentSettingsItemPresentation = AdditionalParameters.SettingsItemPresentation;
	SaveAndExecuteCurrentSettingSelection();
EndProcedure

&AtClient
Procedure SaveAndExecuteCurrentSettingSelection()
	
	SaveCurrentSettings();
	ReadSavedSettings();
	
	CloseOnChoice = True;
	ExecuteSelection(CurrentSettingsItemPresentation);
EndProcedure;

#EndRegion
