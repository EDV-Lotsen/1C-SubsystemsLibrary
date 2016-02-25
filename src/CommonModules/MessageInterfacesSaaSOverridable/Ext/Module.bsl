////////////////////////////////////////////////////////////////////////////////
// Message interfaces Saas subsystem, overridable procedures and functions
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Fills the passed array with common modules that contain handlers for interfaces of incoming messages.
//
// Parameters:
//  HandlerArray - Array.
//
Procedure FillIncomingMessageHandlers(HandlerArray) Export
	
EndProcedure

// Fills the passed array with common modules that contain handlers for interfaces of outgoing messages.
//
// Parameters:
//  HandlerArray - Array.
//
Procedure FillOutgoingMessageHandlers(HandlerArray) Export
	
EndProcedure

// The procedure is called when determining a message interface
//  version supported both by correspondent infobase and the current infobase. 
//  This procedure is intended to implement mechanisms for enabling backward compatibility 
//  with earlier versions of correspondent infobases.
//
// Parameters:
//  MessageInterface - String - name of an application message interface
//                              whose version is to be determined. 
//  ConnectionParameters - Structure - correspondent infobase connection parameters. 
//  RecipientPresentation - String - correspondent infobase presentation. 
//  Result - String - version to be determined. Value of this parameter can be modified in this procedure.
//
Procedure OnDetermineCorrespondentInterfaceVersion(Val MessageInterface, Val ConnectionParameters, Val RecipientPresentation, Result) Export
	
EndProcedure

#EndRegion
