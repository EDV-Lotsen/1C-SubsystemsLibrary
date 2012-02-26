

&AtServer
// Procedure - handler of event OnCreateAtServer.
//
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
		
	// Handler of subsystem "Additional reports and data processors"
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	
EndProcedure // OnCreateAtServer()

///////////////////////////////////////////////////////////////////////////////
// PROCEDURES - ACTIONS OF FORM COMMAND BARS

&AtClient
// Procedure - handler of event "ChoiceProcessing" of form.
//
Procedure ChoiceProcessing(ChoiceResult, ChoiceSource)
	
	Items.List.Refresh();
	
EndProcedure // ChoiceProcessing()

&AtClient
// Procedure is called via button "Add from classifier".
//
Procedure AddFromClassifier(Command)
	
	OpenForm("Catalog.Banks.Form.BanksChoiceForm", , ThisForm);
	
EndProcedure // AddFromClassifier()
