

&AtServer
// Procedure - handler of event OnCreateAtServer.
//
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
		
	// Handler of subsystem "Additional reports and data processors"
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	
EndProcedure // OnCreateAtServer()
