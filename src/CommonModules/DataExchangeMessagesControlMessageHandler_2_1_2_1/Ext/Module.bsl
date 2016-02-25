////////////////////////////////////////////////////////////////////////////////
// CHANNEL MESSAGE HANDLER MODULE FOR VERSION 2.1.2.1
// OF MESSAGE INTERFACE FOR MONITORING DATA EXCHANGE ADMINISTRATION
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Returns the namespace of the message interface version.
Function Package() Export
	
	Return "http://www.1c.ru/SaaS/Exchange/Control";
	
EndFunction

// Returns the message interface version that is supported by the handler.
Function Version() Export
	
	Return "2.1.2.1";
	
EndFunction

// Returns the default message type in a message interface version.
Function BaseType() Export
	
	Return MessagesSaaSCached.TypeBody();
	
EndFunction

// Processes incoming messages in SaaS mode.
//
// Parameters:
//  Message          - XDTODataObject - incoming message.
//  Sender           - ExchangePlanRef.MessageExchange - exchange plan node
//                     that matches the message sender.
//  MessageProcessed - Boolean - True if processing is successful. This 
//                     parameter value must be set to True if the message is
//                     successfully read in this handler.
//
Procedure ProcessSaaSMessage(Val Message, Val From, MessageProcessed) Export
	
	MessageProcessed = True;
	
	Dictionary = DataExchangeMessagesMonitoringInterface;
	MessageType = Message.Body.Type();
	
	If MessageType = Dictionary.ExchangeSetupStep1CompletedMessage(Package()) Then
		
		ExchangeSetupStep1Completed(Message, From);
		
	ElsIf MessageType = Dictionary.ExchangeSetupStep2CompletedMessage(Package()) Then
		
		ExchangeSetupStep2Completed(Message, From);
		
	ElsIf MessageType = Dictionary.ExchangeSetupErrorStep1Message(Package()) Then
		
		ExchangeSetupErrorStep1(Message, From);
		
	ElsIf MessageType = Dictionary.ExchangeSetupErrorStep2Message(Package()) Then
		
		ExchangeSetupErrorStep2(Message, From);
		
	ElsIf MessageType = Dictionary.ExchangeMessageImportCompletedMessage(Package()) Then
		
		ExchangeMessageImportCompleted(Message, From);
		
	ElsIf MessageType = Dictionary.ExchangeMessageImportErrorMessage(Package()) Then
		
		ExchangeMessageImportError(Message, From);
		
	ElsIf MessageType = Dictionary.CorrespondentDataGettingCompletedMessage(Package()) Then
		
		CorrespondentDataGettingCompleted(Message, From);
		
	ElsIf MessageType = Dictionary.GettingCorrespondentNodeCommonDataCompletedMessage(Package()) Then
		
		GettingCorrespondentNodeGeneralDataCompleted(Message, From);
		
	ElsIf MessageType = Dictionary.CorrespondentDataGettingErrorMessage(Package()) Then
		
		CorrespondentDataGettingError(Message, From);
		
	ElsIf MessageType = Dictionary.CorrespondentNodeCommonDataGettingErrorMessage(Package()) Then
		
		CorrespondentNodeCommonDataGettingError(Message, From);
		
	ElsIf MessageType = Dictionary.GettingCorrespondentAccountingParametersCompletedMessage(Package()) Then
		
		GettingCorrespondentAccountingOptionCompleted(Message, From);
		
	ElsIf MessageType = Dictionary.CorrespondentAccountingParameterGettingErrorMessage(Package()) Then
		
		CorrespondentAccountingOptionGettingError(Message, From);
		
	Else
		
		MessageProcessed = False;
		Return;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// Exchange setup

Procedure ExchangeSetupStep1Completed(Message, From)
	
	DataExchangeSaaS.CommitSuccessfulSession(Message, SynchronizationSetupStep1Presentation());
	
EndProcedure

Procedure ExchangeSetupStep2Completed(Message, From)
	
	DataExchangeSaaS.CommitSuccessfulSession(Message, SynchronizationSetupStep2Presentation());
	
EndProcedure

Procedure ExchangeSetupErrorStep1(Message, From)
	
	DataExchangeSaaS.CommitUnsuccessfulSession(Message, SynchronizationSetupStep1Presentation());
	
EndProcedure

Procedure ExchangeSetupErrorStep2(Message, From)
	
	DataExchangeSaaS.CommitUnsuccessfulSession(Message, SynchronizationSetupStep2Presentation());
	
EndProcedure

Procedure ExchangeMessageImportCompleted(Message, From)
	
	DataExchangeSaaS.CommitSuccessfulSession(Message, ExchangeMessageImportPresentation());
	
EndProcedure

Procedure ExchangeMessageImportError(Message, From)
	
	DataExchangeSaaS.CommitSuccessfulSession(Message, ExchangeMessageImportPresentation());
	
EndProcedure

// Retrieves correspondent data.
Procedure CorrespondentDataGettingCompleted(Message, From)
	
	DataExchangeSaaS.SaveSessionData(Message, CorrespondentDataGettingPresentation());
	
EndProcedure

Procedure GettingCorrespondentNodeGeneralDataCompleted(Message, From)
	
	DataExchangeSaaS.SaveSessionData(Message, GettingCorrespondentNodeGeneralDataPresentation());
	
EndProcedure

Procedure CorrespondentDataGettingError(Message, From)
	
	DataExchangeSaaS.CommitUnsuccessfulSession(Message, CorrespondentDataGettingPresentation());
	
EndProcedure

Procedure CorrespondentNodeCommonDataGettingError(Message, From)
	
	DataExchangeSaaS.CommitUnsuccessfulSession(Message, GettingCorrespondentNodeGeneralDataPresentation());
	
EndProcedure

// Retrieves correspondent accounting options.
Procedure GettingCorrespondentAccountingOptionCompleted(Message, From)
	
	DataExchangeSaaS.SaveSessionData(Message, GettingCorrespondentAccountingOptionPresentation());
	
EndProcedure

Procedure CorrespondentAccountingOptionGettingError(Message, From)
	
	DataExchangeSaaS.CommitUnsuccessfulSession(Message, GettingCorrespondentAccountingOptionPresentation());
	
EndProcedure

// Auxiliary functions

Function SynchronizationSetupStep1Presentation()
	
	Return NStr("en = 'Synchronization setup, step 1.'");
	
EndFunction

Function SynchronizationSetupStep2Presentation()
	
	Return NStr("en = 'Synchronization setup, step 2.'");
	
EndFunction

Function ExchangeMessageImportPresentation()
	
	Return NStr("en = 'Importing exchange message.'");
	
EndFunction

Function CorrespondentDataGettingPresentation()
	
	Return NStr("en = 'Getting correspondent data.'");
	
EndFunction

Function GettingCorrespondentNodeGeneralDataPresentation()
	
	Return NStr("en = 'Getting common correspondent node data.'");
	
EndFunction

Function GettingCorrespondentAccountingOptionPresentation()
	
	Return NStr("en = 'Getting correspondent accounting options.'");
	
EndFunction

#EndRegion
