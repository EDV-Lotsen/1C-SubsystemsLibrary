////////////////////////////////////////////////////////////////////////////////
// MessageExchangeClient: message exchange mechanism.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Sends and receives system messages. 
//
Procedure SendAndReceiveMessages() Export
	
	Status(NStr("en = 'Sending and receiving messages.'"),,
			NStr("en = 'Please wait...'"), PictureLib.Information32
	);
	
	Cancel = False;
	
	MessageExchangeInternal.SendAndReceiveMessages(Cancel);
	
	If Cancel Then
		
		Status(NStr("en = 'Error sending and receiving messages.'"),,
				NStr("en = 'See the event log for details.'"), PictureLib.Error32
		);
		
	Else
		
		Status(NStr("en = 'Sending and receiving messages completed successfully.'"),,, PictureLib.Information32);
		
	EndIf;
	
	Notify(SendReceiveEmailExecutedEventName());
	
EndProcedure

// For internal use only.
//
// Returns:
// String.
// 
Function EndPointAddedEventName() Export
	
	Return "MessageExchange.EndPointAdded";
	
EndFunction

// For internal use only.
//
// Returns:
// String.
// 
Function SendReceiveEmailExecutedEventName() Export
	
	Return "MessageExchange.SendAndReceiveExecuted";
	
EndFunction

// For internal use only.
//
// Returns:
// String.
// 
Function EndPointFormClosedEventName() Export
	
	Return "MessageExchange.EndPointFormClosed";
	
EndFunction

// For internal use only.
//
// Returns:
// String.
// 
Function EventNameLeadingEndPointSet() Export
	
	Return "MessageExchange.LeadingEndPointSet";
	
EndFunction







