
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("GetDefaultValue") Then
		
    EndIf;
    DataExchangeServer.NodesSetupFormOnCreateAtServer(ThisObject, Cancel);
    GetContextDetails();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)	
    DataExchangeClient.SetupFormBeforeClose(ThisObject);	
EndProcedure

&AtClient
Procedure SaveAndClose(Command)
	GetContextDetails();
    DataExchangeClient.SetupOfNodesFormCloseFormCommand(ThisObject);
EndProcedure

&AtServer
Procedure GetContextDetails()

	ContextDetails = "";	

EndProcedure


