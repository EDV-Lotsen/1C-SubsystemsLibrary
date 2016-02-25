////////////////////////////////////////////////////////////////////////////////
// MESSAGE CHANNEL HANDLER FOR VERSION 1.0.3.4
//  OF REMOTE ADMINISTRATION MESSAGE INTERFACE
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Returns the namespace of the message interface version.
Function Package() Export
	
	Return "http://www.1c.ru/SaaS/RemoteAdministration/App/" + Version();
	
EndFunction

// Returns the message interface version that is supported by the handler.
Function Version() Export
	
	Return "1.0.3.1";
	
EndFunction

// Returns the default message type in a message interface version.
Function BaseType() Export
	
	Return MessagesSaaSCached.TypeBody();
	
EndFunction

// Processes incoming messages in SaaS mode.
//
// Parameters:
//  Message          - XDTODataObject - the incoming message, 
//  Sender           - ExchangePlanRef.MessageExchange - the exchange plan node that matches
//                     the message sender 
//  MessageProcessed - Boolean - True if processing is successful. This parameter
//                     value must be set to True if the message is successfully read in this
//                     handler.
//
Procedure ProcessSaaSMessage(Val Message, Val From, MessageProcessed) Export
	
	MessageProcessed = True;
	
	Dictionary = RemoteAdministrationMessagesInterface;
	MessageType = Message.Body.Type();
	
	If MessageType = Dictionary.MessageUpdateUser(Package()) Then
		UpdateUser(Message, From);
	ElsIf MessageType = Dictionary.MessagePrepareDataArea(Package()) Then
		PrepareDataArea(Message, From, False);
	ElsIf MessageType = Dictionary.MessagePrepareDataAreaFromExport(Package()) Then
		PrepareDataArea(Message, From, True);
	ElsIf MessageType = Dictionary.MessageDeleteDataArea(Package()) Then
		DeleteDataArea(Message, From);
	ElsIf MessageType = Dictionary.MessageSetAccessToDataArea(Package()) Then
		SetAccessToDataArea(Message, From);
	ElsIf MessageType = Dictionary.MessageSetServiceManagerEndpoint(Package()) Then
		SetServiceManagerEndpoint(Message, From);
	ElsIf MessageType = Dictionary.MessageSetInfobaseParameters(Package()) Then
		SetInfobaseParameters(Message, From);
	ElsIf MessageType = Dictionary.MessageSetDataAreaParameters(Package()) Then
		SetDataAreaParameters(Message, From);
	ElsIf MessageType = Dictionary.MessageSetDataAreaFullAccess(Package()) Then
		SetDataAreaFullAccess(Message, From);
	ElsIf MessageType = Dictionary.MessageSetDefaultUserRights(Package()) Then
		SetDefaultUserRights(Message, From);
	Else
		MessageProcessed = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

Procedure UpdateUser(Val Message, Val From)
	
	Body = Message.Body;
	RemoteAdministrationMessagesImplementation.UpdateUser(
		Body.Name,
		Body.FullName,
		Body.StoredPasswordValue,
		Body.UserApplicationID,
		Body.UserServiceID,
		Body.Phone,
		Body.EMail,
		Body.Language);
	
EndProcedure

Procedure PrepareDataArea(Val Message, Val From, Val FromExport)
	
	Body = Message.Body;
	RemoteAdministrationMessagesImplementation.PrepareDataArea(
		Body.Zone,
		FromExport,
		?(FromExport, Undefined, Body.Kind),
		Body.DataFileId);
	
EndProcedure

Procedure DeleteDataArea(Message, From)
	
	RemoteAdministrationMessagesImplementation.DeleteDataArea(Message.Body.Zone);
	
EndProcedure

Procedure SetAccessToDataArea(Val Message, Val From)
	
	Body = Message.Body;
	RemoteAdministrationMessagesImplementation.SetAccessToDataArea(
		Body.Name,
		Body.StoredPasswordValue,
		Body.UserServiceID,
		Body.Value,
		Body.Language);
	
EndProcedure

Procedure SetServiceManagerEndpoint(Val Message, Val From)
	
	RemoteAdministrationMessagesImplementation.SetServiceManagerEndpoint(From);
	
EndProcedure

Procedure SetInfobaseParameters(Val Message, Val From)
	
	Body = Message.Body;
	Parameters = XDTOSerializer.ReadXDTO(Body.Params);
	RemoteAdministrationMessagesImplementation.SetInfobaseParameters(Parameters);
	
EndProcedure

Procedure SetDataAreaParameters(Val Message, Val From)
	
	Body = Message.Body;
	RemoteAdministrationMessagesImplementation.SetDataAreaParameters(
		Body.Zone,
		Body.Presentation,
		Body.TimeZone);
	
EndProcedure

Procedure SetDataAreaFullAccess(Val Message, Val From)
	
	Body = Message.Body;
	RemoteAdministrationMessagesImplementation.SetDataAreaFullAccess(
		Body.UserServiceID,
		Body.Value);
	
EndProcedure

Procedure SetDefaultUserRights(Val Message, Val From)
	
	RemoteAdministrationMessagesImplementation.SetDefaultUserRights(
		Message.Body.UserServiceID);
	
EndProcedure

#EndRegion
