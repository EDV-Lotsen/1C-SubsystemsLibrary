////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	If ValueIsFilled(Parameters.JobID) Then
		TaskID = Parameters.JobID;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose()
	
	LongActionsClient.CancelJobExecution(JobID);
	
EndProcedure