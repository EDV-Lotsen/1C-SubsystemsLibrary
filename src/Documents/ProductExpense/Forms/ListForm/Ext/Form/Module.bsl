
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// StandardSubsystems.Print
	PrintManagement.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.Print
	
	//StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
EndProcedure

// StandardSubsystems.Print
&AtClient
Процедура Attachable_ExecutePrintCommand(Command)
	
    PrintManagementClient.RunAttachablePrintCommand(Command, ThisObject, Items.List);
	
КонецПроцедуры

// End StandardSubsystems.Print
