
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
 
 // Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	ValueToFormAttribute(Parameters.Key.GetObject(), "Object");
	BusinessProcessesAndTasksServer.SetDateFormat(Items.DueDate);
	BusinessProcessesAndTasksServer.SetDateFormat(Items.Date);
	BusinessProcessesAndTasksServer.SetDateFormat(Items.CompletionDate);
	
	StandardSubsystemsServer.SetGroupTitleRepresentation(ThisObject);
	
EndProcedure

#EndRegion
