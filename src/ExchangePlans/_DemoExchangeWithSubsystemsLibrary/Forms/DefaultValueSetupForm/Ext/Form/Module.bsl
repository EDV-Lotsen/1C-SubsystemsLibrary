
////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	DataExchangeClient.SetupFormBeforeClose(Cancel, ThisForm);
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	DataExchangeServer.DefaultValueSetupFormOnCreateAtServer(ThisForm, Metadata.ExchangePlans._DemoExchangeWithSubsystemsLibrary.Name);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	DataExchangeServer.GetAttributesToCheckDependingOnFunctionalOptions(CheckedAttributes, Metadata.ExchangePlans._DemoExchangeWithSubsystemsLibrary.Name);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure DoneCommand(Command)
	
	DataExchangeClient.DefaultValueSetupFormCloseFormCommand(ThisForm);
	
EndProcedure

&AtClient
Procedure CancelCommand(Command)
	
	Close();
	
EndProcedure
