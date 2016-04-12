
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	 DataExchangeServer.NodeSettingsFormOnCreateAtServer(ThisObject, "DemoExchangeWithSL");
 EndProcedure
 
 &AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	DataExchangeClient.SetupFormBeforeClose(Cancel, ThisObject);
EndProcedure

&AtClient
Procedure OKCommand(Command)	
	DataExchangeClient.NodeSettingsFormCloseFormCommand(ThisObject);	
EndProcedure