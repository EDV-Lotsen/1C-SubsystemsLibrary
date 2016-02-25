////////////////////////////////////////////////////////////////////////////////
// MESSAGE CHANNEL HANDLER FOR VERSION 1.0.3.4
//  OF REMOTE ADMINISTRATION MESSAGE INTERFACE
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Returns the namespace of the message interface version.
Function Package() Export
	
	Return "http://www.1c.ru/1cFresh/RemoteAdministration/App/" + Version();
	
EndFunction

// Returns the message interface version that is supported by the handler.
Function Version() Export
	
	Return "1.0.3.4";
	
EndFunction

// Returns the default message type in a message interface version.
Function BaseType() Export
	
	Return MessagesSaaSCached.TypeBody();
	
EndFunction

// Processes incoming messages in SaaS mode.
//
// Parameters:
//  Message          - XDTODataObject, incoming message, 
//  Sender           - ExchangePlanRef.MessageExchange - the exchange plan node that matches
//                     the message sender.
//  MessageProcessed - Boolean - True if processing is successful. This parameter
//                     value must be set to True if the message is successfully read in this
//                     handler.
//
Procedure ProcessSaaSMessage(Val Message, Val From, MessageProcessed) Export
	
	MessageProcessed = True;
	
	Dictionary = RemoteAdministrationMessagesInterface;
	
	If CommonUse.SubsystemExists("CloudTechnology.SaaSOperations.AdditionalReportsAndDataProcessorsSaaS") Then
		DictionaryARDP = CommonUse.CommonModule("AdditionalReportAndDataProcessorControlMessagesInterface");
	Else
		DictionaryARDP = Undefined;
	EndIf;
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
	ElsIf MessageType = Dictionary.MessageSetDataAreaRating(Package()) Then
		SetDataAreaRating(Message, From);
	ElsIf MessageType = Dictionary.MessageAttachDataArea(Package()) Then
		AttachDataArea(Message, From);
	ElsIf DictionaryARDP <> Undefined And MessageType = DictionaryARDP.MessageSetAdditionalReportOrDataProcessor(Package()) Then
		SetAdditionalReportOrDataProcessor(Message, From);
	ElsIf DictionaryARDP <> Undefined And MessageType = DictionaryARDP.MessageDeleteAdditionalReportOrDataProcessor(Package()) Then
		DeleteAdditionalReportOrDataProcessor(Message, From);
	ElsIf DictionaryARDP <> Undefined And MessageType = DictionaryARDP.MessageDisableAdditionalReportOrDataProcessor(Package()) Then
		DisableAdditionalReportOrDataProcessor(Message, From);
	ElsIf DictionaryARDP <> Undefined And MessageType = DictionaryARDP.MessageEnableAdditionalReportOrDataProcessor(Package()) Then
		EnableAdditionalReportOrDataProcessor(Message, From);
	ElsIf DictionaryARDP <> Undefined And MessageType = DictionaryARDP.MessageWithdrawAdditionalReportOrDataProcessor(Package()) Then
		WithdrawAdditionalReportOrDataProcessor(Message, From);
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

Procedure SetDataAreaRating(Val Message, Val From)
	
	Body = Message.Body;
	RatingTable = New ValueTable();
	RatingTable.Columns.Add("DataArea", New TypeDescription("Number", , New NumberQualifiers(7,0)));
	RatingTable.Columns.Add("Rating", New TypeDescription("Number", , New NumberQualifiers(7,0)));
	For Each MessageString In Body.Item Do
		RatingString = RatingTable.Add();
		RatingString.DataArea = MessageString.Zone;
		RatingString.Rating = MessageString.Rating;
	EndDo;
 
RemoteAdministrationMessagesImplementation.SetDataAreaRating(
		RatingTable, Body.SetAllZones);
	
EndProcedure

Procedure AttachDataArea(Val Message, Val From)
	
	Body = Message.Body;
 
RemoteAdministrationMessagesImplementation.AttachDataArea(Body); 
	
EndProcedure

Procedure SetAdditionalReportOrDataProcessor(Val Message, Val From)
	
	
	
EndProcedure

Procedure DeleteAdditionalReportOrDataProcessor(Val Message, Val From)
	
	If CommonUse.SubsystemExists("CloudTechnology.SaaSOperations.AdditionalReportsAndDataProcessorsSaaS") Then
		
		Body = Message.Body;
		
		ModuleAdditionalReportAndDataProcessorControlMessagesImplementation = CommonUse.CommonModule("AdditionalReportAndDataProcessorControlMessagesImplementation");
		
		ModuleAdditionalReportAndDataProcessorControlMessagesImplementation.DeleteAdditionalReportOrDataProcessor(
			Body.Extension, Body.Installation);
		
	EndIf;
	
EndProcedure

Procedure DisableAdditionalReportOrDataProcessor(Val Message, Val From)
	
	If CommonUse.SubsystemExists("CloudTechnology.SaaSOperations.AdditionalReportsAndDataProcessorsSaaS") Then
		
		ModuleAdditionalReportAndDataProcessorControlMessagesImplementation = CommonUse.CommonModule("AdditionalReportAndDataProcessorControlMessagesImplementation");
		
		ModuleAdditionalReportAndDataProcessorControlMessagesImplementation.DisableAdditionalReportOrDataProcessor(
			Message.Body.Extension);
		
	EndIf;
	
EndProcedure

Procedure EnableAdditionalReportOrDataProcessor(Val Message, Val From)
	
	If CommonUse.SubsystemExists("CloudTechnology.SaaSOperations.AdditionalReportsAndDataProcessorsSaaS") Then
		
		ModuleAdditionalReportAndDataProcessorControlMessagesImplementation = CommonUse.CommonModule("AdditionalReportAndDataProcessorControlMessagesImplementation");
		
		ModuleAdditionalReportAndDataProcessorControlMessagesImplementation.EnableAdditionalReportOrDataProcessor(
			Message.Body.Extension);
		
	EndIf;
	
EndProcedure

Procedure WithdrawAdditionalReportOrDataProcessor(Val Message, Val From)
	
	If CommonUse.SubsystemExists("CloudTechnology.SaaSOperations.AdditionalReportsAndDataProcessorsSaaS") Then
		
		ModuleAdditionalReportAndDataProcessorControlMessagesImplementation = CommonUse.CommonModule("AdditionalReportAndDataProcessorControlMessagesImplementation");
		
		ModuleAdditionalReportAndDataProcessorControlMessagesImplementation.WithdrawAdditionalReportOrDataProcessor(
			Message.Body.Extension);
		
	EndIf;
	
EndProcedure

#EndRegion
