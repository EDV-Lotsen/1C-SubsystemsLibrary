
////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	DataExchangeClient.SetupFormBeforeClose(Cancel, ThisForm);
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DataExchangeServer.NodeSettingsFormOnCreateAtServer(ThisForm, Metadata.ExchangePlans._DemoExchangeWithSubsystemsLibrary.Name);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure OKCommand(Command)
	
	DataExchangeClient.NodeSettingsFormCloseFormCommand(ThisForm);
	
EndProcedure
