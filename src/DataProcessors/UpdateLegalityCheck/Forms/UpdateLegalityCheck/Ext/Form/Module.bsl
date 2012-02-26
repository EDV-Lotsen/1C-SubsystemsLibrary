
&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	DocumentTemplate = DataProcessors.UpdateLegalityCheck.GetTemplate("TermsOfUpdatesDistribution");
	WarningText = DocumentTemplate.GetText();
	ChoiceConfirmation = 2;
	ForcedStart = Parameters.ForcedStart;
	Items.Note.Visible = Parameters.ShowWarningAboutRestart;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancellation)
	
	If Not ForcedStart Then
		DoMessageBox(NStr("en = 'Data processor is not designed to be used directly'"));
		Cancellation = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure FormMainActionsContinue(Command)
	
	Close(ChoiceConfirmation = 1);
	
EndProcedure

                            	