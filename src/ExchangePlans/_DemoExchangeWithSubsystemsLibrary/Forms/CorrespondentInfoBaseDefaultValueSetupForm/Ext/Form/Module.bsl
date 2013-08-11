
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
	
	If ExternalConnectionParameters.ConnectionType = "ExternalConnection" Then
		
		ErrorMessageString = "";
		ExternalConnection = DataExchangeCached.EstablishExternalConnection(ExternalConnectionParameters, ErrorMessageString);
		
		If ExternalConnection = Undefined Then
			CommonUseClientServer.MessageToUser(ErrorMessageString,,,, Cancel);
			Return;
		EndIf;
		
	ElsIf ExternalConnectionParameters.ConnectionType = "WebService" Then
		
		ErrorMessageString = "";
		WSProxy = DataExchangeCached.GetWSProxy(ExternalConnectionParameters, ErrorMessageString);
		
		If WSProxy = Undefined Then
			CommonUseClientServer.MessageToUser(ErrorMessageString,,,, Cancel);
			Return;
		EndIf;
		
	EndIf;
	
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
	

//////////////////////////////////////////////////////////
// FORM ITEM EVENT HANDLERS

&AtClient
Procedure DefaultItemStartChoice(Item, ChoiceData, StandardProcessing)
	
	DataExchangeClient.CorrespondentInfoBaseItemChoiceHandlerStartChoice("DefaultItem", "Catalog.Items", ThisForm, StandardProcessing, ExternalConnectionParameters);
	
EndProcedure
