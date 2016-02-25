////////////////////////////////////////////////////////////////////////////////
// MessageExchangeClient: message exchange mechanism.
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

// Sends and receives system messages
// 
Procedure SendAndReceiveMessages() Export
	
	Status(NStr("en = 'Sending and receiving messages.'"),,
			NStr("en = 'Please wait...'"), PictureLib.Information32);
	
	Cancel = False;
	
	MessageExchangeServerCall.SendAndReceiveMessages(Cancel);
	
	If Cancel Then
		
		Status(NStr("en = 'Messages sending and receiving errors.'"),,
				NStr("en = 'Use the event log to diagnose errors.'"), PictureLib.Error32);
		
	Else
		
		Status(NStr("en = 'Messages are sent and recieved.'"),,, PictureLib.Information32);
		
	EndIf;
	
	Notify(EventNameSendAndReceiveMessageExecuted());
	
EndProcedure

// For internal use only
//
// Returns:
// String. 
//
Function EndpointAddedEventName() Export
	
	Return "MessageExchange.EndpointAdded";
	
EndFunction

// For internal use only
//
// Returns:
// String. 
//
Function EventNameSendAndReceiveMessageExecuted() Export
	
	Return "MessageExchange.SendAndReceiveExecuted";
	
EndFunction

// For internal use only
//
// Returns:
// String. 
//
Function EndpointFormClosedEventName() Export
	
	Return "MessageExchange.EndpointFormClosed";
	
EndFunction

// For internal use only
//
// Returns:
// String. 
//
Function EventNameLeadingEndpointSet() Export
	
	Return "MessageExchange.LeadingEndpointSet";
	
EndFunction

#EndRegion
