///////////////////////////////////////////////////////////////////////////////
// REMOTE ADMINISTRATION CONTROL MESSAGE TRANSLATION HANDLER
//  FOR TRANSLATION FROM VERSION 1.0.2.5 TO VERSION 1.0.2.4
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Returns the number of the version for translation from which the handler is intended
Function SourceVersion() Export
	
	Return "1.0.2.5";
	
EndFunction

// Returns the namespace of the version for translation from which the handler is intended
Function SourceVersionPackage() Export
	
	Return "http://www.1c.ru/1cFresh/RemoteAdministration/Control/" + SourceVersion();
	
EndFunction

// Returns the number of the version for translation to which the handler is intended
Function ResultingVersion() Export
	
	Return "1.0.2.4";
	
EndFunction

// Returns the namespace of the version for translation to which the handler is intended
Function ResultingVersionPackage() Export
	
	Return "http://www.1c.ru/1cFresh/RemoteAdministration/Control/" + ResultingVersion();
	
EndFunction

// Standard translation processing execution check handler
//
// Parameters:
//  SourceMessage - XDTODataObject - translated message,
//  StandardProcessing - Boolean - set False for this parameter 
//    within the procedure to cancel standard translation processing.
//    In that case, the MessageTranslation() function of the translation handler is called
//    instead of the standard translation processing.
//
Procedure BeforeTranslation(Val SourceMessage, StandardProcessing) Export
	
EndProcedure

// Execution handler of any message translation. It is only called if the StandardProcessing
// parameter of the BeforeTranslation procedure was set to False.
//
// Parameters:
//  SourceMessage - XDTODataObject - the translated message.
//
// Returns:
//  XDTODataObject - result message translation.
//
Function MessageTranslation(Val SourceMessage) Export
	
EndFunction

#EndRegion
