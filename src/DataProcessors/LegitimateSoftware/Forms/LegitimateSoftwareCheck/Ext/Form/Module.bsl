
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	If Not Parameters.OpenedProgrammatically Then
		Raise
			NStr("en = 'The data processor cannot be opened manually'");
	EndIf;
	
	IgnoreRestart = Parameters.IgnoreRestart;
	
	DocumentTemplate = DataProcessors.LegitimateSoftware.GetTemplate(
		"UpdateDistributionTerms");
	
	WarningText = DocumentTemplate.GetText();
	ChoiceConfirmation = 0; // The user should clearly select one of the variants
	Items.Comment.Visible = Parameters.ShowRestartWarning;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ContinueFormMainActions(Command)
	
	Result = ChoiceConfirmation = 1;
	
	If Result <> True Then
		If Parameters.ShowRestartWarning And Not IgnoreRestart Then
			Terminate();
		EndIf;
	Else
		WriteLegitimateSoftwareConfirmation();
	EndIf;
	
	Close(Result);
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If Result <> True Then
		If Parameters.ShowRestartWarning And Not IgnoreRestart Then
			Terminate();
		EndIf;
	Else
		WriteLegitimateSoftwareConfirmation();
	EndIf;
	
	Notify("LegitimateSoftware", Result);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServerNoContext
Procedure WriteLegitimateSoftwareConfirmation()
	
	SetPrivilegedMode(True);
	
	InfobaseUpdateInternal.WriteLegitimateSoftwareConfirmation();
	
EndProcedure

#EndRegion
