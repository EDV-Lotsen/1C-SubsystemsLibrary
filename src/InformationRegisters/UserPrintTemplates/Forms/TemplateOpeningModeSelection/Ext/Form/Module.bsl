
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	Value = CommonUse.CommonSettingsStorageLoad(
		"TemplateOpeningSettings", 
		"PromptForTemplateOpeningMode");
	
	If Value = Undefined Then
		DontAskAgain = False;
	Else
		DontAskAgain = Not Value;
	EndIf;
	
	Value = CommonUse.CommonSettingsStorageLoad(
		"TemplateOpeningSettings", 
		"TemplateOpeningModeView");
	
	If Value = Undefined Then
		HowToOpen = 0;
	Else
		If Value Then
			HowToOpen = 0;
		Else
			HowToOpen = 1;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	PromptForTemplateOpeningMode = Not DontAskAgain;
	TemplateOpeningModeView = ?(HowToOpen = 0, True, False);
	
	SaveOpenTemplateModeSettings(PromptForTemplateOpeningMode, TemplateOpeningModeView);
	
	NotifyChoice(New Structure("DontAskAgain, ViewOpenMode",
							DontAskAgain,
							TemplateOpeningModeView) );
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServerNoContext
Procedure SaveOpenTemplateModeSettings(PromptForTemplateOpeningMode, TemplateOpeningModeView)
	
	CommonUse.CommonSettingsStorageSave(
		"TemplateOpeningSettings", 
		"PromptForTemplateOpeningMode", 
		PromptForTemplateOpeningMode);
	
	CommonUse.CommonSettingsStorageSave(
		"TemplateOpeningSettings", 
		"TemplateOpeningModeView", 
		TemplateOpeningModeView);
	
EndProcedure

#EndRegion
