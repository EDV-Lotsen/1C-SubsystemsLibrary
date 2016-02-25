////////////////////////////////////////////////////////////////////////////////
// MessageExchange: data area message management.
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

// Called when filling an array of catalogs that can be used for message storage purposes.
//
// Parameters:
//  ArrayCatalog - Array - Managers for catalogs that can be used for message storage 
//                         are added to this parameter.
//
Procedure OnFillMessageCatalogs(CatalogArray) Export
	
	CatalogArray.Add(Catalogs.DataAreaMessages);
	
EndProcedure

// Selects a catalog for a message.
//
// Parameters:
//  Body - Arbitrary - message body.
//
Function OnSelectCatalogForMessage(Val Body) Export
	
	Message = Undefined;
	If MessagesSaaS.BodyContainsTypedMessage(Body, Message) Then
		
		If MessagesSaaSCached.AreaBodyType().IsDescendant(Message.Body.Type()) Then
			
			Return Catalogs.DataAreaMessages;
			
		EndIf;
		
	Else
		
		If CommonUse.UseSessionSeparator() Then
			Return Catalogs.DataAreaMessages;
		EndIf;
		
	EndIf;
	
EndFunction

// Called before writing a message catalog item.
//
// Parameters:
//  MessageObject - CatalogObject.SystemMessages,
//  CatalogObject.DataAreaMessages, StandardProcessing - Boolean.
//
Procedure BeforeWriteMessage(MessageObject, StandardProcessing) Export
	
	Message = Undefined;
	If MessagesSaaS.BodyContainsTypedMessage(MessageObject.Body.Get(), Message) Then
		
		If MessagesSaaSCached.AreaBodyType().IsDescendant(Message.Body.Type()) Then
			
			MessageObject.DataAreaAuxiliaryData = Message.Body.Zone;
			
		EndIf;
		
	EndIf;
	
	StandardProcessing = False;
	CommonUse.WriteAuxiliaryData(MessageObject);
	
EndProcedure

// "On send message" event handler.
// This event handler is called before a message is sent to an XML data stream.
// The handler is called separately for each message to be sent.
//
// Parameters:
//  MessageChannel - String    - ID of a message channel used to send the message.
//  Body           - Arbitrary - Body of the message to be sent. 
//                               In this event handler, message body can be modified 
//                               (for example, new data added).
//
Procedure OnSendMessage(MessageChannel, Body, MessageObject) Export
	
	Message = Undefined;
	If MessagesSaaS.BodyContainsTypedMessage(Body, Message) Then
		
		If CommonUseCached.CanUseSeparatedData()
			And MessagesSaaSCached.AreaBodyType().IsDescendant(Message.Body.Type()) Then
			
			If CommonUse.SessionSeparatorValue() <> Message.Body.Zone Then
				MessagePattern = NStr("en = 'Message delivery from area %2 on behalf of area %1 is attempted'");
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, 
					Message.Body.Zone, 
					CommonUse.SessionSeparatorValue());
				Raise(MessageText);
			EndIf;
		EndIf;
		
		If MessagesSaaSCached.AuthentifiedAreaBodyType().IsDescendant(Message.Body.Type()) Then
			
			If CommonUseCached.CanUseSeparatedData() Then
				Message.Body.ZoneKey = Constants.DataAreaKey.Get();
			Else
				SetPrivilegedMode(True);
				CommonUse.SetSessionSeparation(True, Message.Body.Zone);
				Message.Body.ZoneKey = Constants.DataAreaKey.Get();
				CommonUse.SetSessionSeparation(False);
			EndIf;
			
		EndIf;
		
		Body = MessagesSaaS.WriteMessageToUntypedBody(Message);
		
	EndIf;
	
	If TypeOf(MessageObject) <> Type("CatalogObject.SystemMessages") Then
		
		MessageObjectSubstitution = Catalogs.SystemMessages.CreateItem();
		
		FillPropertyValues(MessageObjectSubstitution, MessageObject, , "Parent,Owner");
		
		MessageObjectSubstitution.SetNewObjectRef(Catalogs.SystemMessages.GetRef(
			MessageObject.Ref.UUID()));
		
		MessageObject = MessageObjectSubstitution;
		
	EndIf;
	
EndProcedure

// "On receive message" event handler.
// This event handler is called after a message is received from an XML data stream.
// The handler is called separately for each received message.
//
// Parameters:
//  MessageChannel - String    - ID of the message channel that delivered the message.
//  Body           - Arbitrary - Body of the received message.
//                               In this event handler, message body can be modified
//                               (for example, new data added).
//
Procedure OnReceiveMessage(MessageChannel, Body, MessageObject) Export
	
	SetPrivilegedMode(True);
	
	Message = Undefined;
	If MessagesSaaS.BodyContainsTypedMessage(Body, Message) Then
		
		If CommonUseCached.IsSeparatedConfiguration() Then
			
			OverriddenCatalog = OnSelectCatalogForMessage(Body);
			
			If OverriddenCatalog <> Undefined Then
				
				If TypeOf(OverriddenCatalog.EmptyRef()) <> TypeOf(MessageObject.Ref) Then
					
					MessageObjectSubstitutionRef = OverriddenCatalog.GetRef(
						MessageObject.GetNewObjectRef().UUID());
					
					If CommonUse.RefExists(MessageObjectSubstitutionRef) Then
						
						MessageObjectSubstitution = MessageObjectSubstitutionRef.GetObject();
						
					Else
						
						MessageObjectSubstitution = OverriddenCatalog.CreateItem();
						MessageObjectSubstitution.SetNewObjectRef(MessageObjectSubstitutionRef);
						
					EndIf;
					
					FillPropertyValues(MessageObjectSubstitution, MessageObject, , "Parent,Owner");
					MessageObjectSubstitution.DataAreaAuxiliaryData = Message.Body.Zone;
					
					MessageObject = MessageObjectSubstitution;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// This procedure is called when an incoming message processing starts.
//
// Parameters:
//  Message - XDTODataObject                  - incoming message.
//  Sender  - ExchangePlanRef.MessageExchange - exchange plan node matching the infobase 
//                                              used to send the message.
//
Procedure OnMessageProcessingStart(Val Message, Val From) Export
	
	If MessagesSaaSCached.AreaBodyType().IsDescendant(Message.Body.Type()) Then
		
		CommonUse.SetSessionSeparation(True, Message.Body.Zone);
		ProcessAreaKeyInMessage(Message);
		
	EndIf;
	
EndProcedure

// This procedure is called after an incoming message processing ends.
//
// Parameters:
//  Message          - XDTODataObject                  - incoming message. 
//  Sender           - ExchangePlanRef.MessageExchange - exchange plan node matching the infobase
//                                                     used to send the message. 
//  MessageProcessed - Boolean - flag specifying whether the message was processed successfully. 
//                               If set to False, an exception is raised after this procedure is complete. 
//                               In this procedure, value of this parameter can be modified.
//
Procedure AfterMessageProcessing(Val Message, Val From, MessageProcessed) Export
	
	If MessagesSaaSCached.AreaBodyType().IsDescendant(Message.Body.Type()) Then
		
		CommonUse.SetSessionSeparation(False);
		
	EndIf;
	
EndProcedure

// This procedure is called when a message processing error occurs.
//
// Parameters:
//  Message - XDTODataObject                  - incoming message.
//  Sender -  ExchangePlanRef.MessageExchange - exchange plan node matching the infobase 
//                                              used to send the message.
//
Procedure OnMessageProcessingError(Val Message, Val From) Export
	
	If MessagesSaaSCached.AreaBodyType().IsDescendant(Message.Body.Type()) Then
		
		CommonUse.SetSessionSeparation(False);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

Procedure ProcessAreaKeyInMessage(Message)
	
	MessageContainsAreaKey = False;
	
	If MessagesSaaSCached.AuthentifiedAreaBodyType().IsDescendant(Message.Body.Type()) Then
		MessageContainsAreaKey = True;
	EndIf;
	
	If Not MessageContainsAreaKey Then
		
		HandlerArray = New Array();
		RemoteAdministrationMessagesInterface.MessageChannelHandlers(HandlerArray);
		For Each Handler In HandlerArray Do
			
			HandlerMessageType = RemoteAdministrationMessagesInterface.MessageSetDataAreaParameters(
				Handler.Package());
			
			If Message.Body.Type() = HandlerMessageType Then
				MessageContainsAreaKey = True;
				Break;
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If MessageContainsAreaKey Then
		
		CurrentAreaKey = Constants.DataAreaKey.Get();
		
		If Not ValueIsFilled(CurrentAreaKey) Then
			
			Constants.DataAreaKey.Set(Message.Body.ZoneKey);
			
		Else
			
			If CanCheckAreaKeyInMessages() Then
				
				If CurrentAreaKey <> Message.Body.ZoneKey Then
					
					Raise NStr("en = 'Incorrect data area key is used in the message.'");
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Function CanCheckAreaKeyInMessages()
	
	SettingsStructure = InformationRegisters.ExchangeTransportSettings.TransportSettingsWS(
		SaaSOperationsCached.ServiceManagerEndpoint());
	SaaSConnectionParameters = New Structure;
	SaaSConnectionParameters.Insert("URL",      SettingsStructure.WSURL);
	SaaSConnectionParameters.Insert("UserName", SettingsStructure.WSUserName);
	SaaSConnectionParameters.Insert("Password", SettingsStructure.WSPassword);
	
	LatestVersion = Undefined;
	SaaSVersions = CommonUse.GetInterfaceVersions(SaaSConnectionParameters, "MessagesSaaS");
	If SaaSVersions = Undefined Then
		Return False;
	EndIf;
	
	For Each SaaSVersion In SaaSVersions Do
		
		If LatestVersion = Undefined Then
			LatestVersion = SaaSVersion;
		Else
			LatestVersion = ?(CommonUseClientServer.CompareVersions(
				SaaSVersion, LatestVersion) > 0, SaaSVersion,
				LatestVersion);
		EndIf;
		
	EndDo;
	
	If SaaSVersion = Undefined Then
		Return False;
	EndIf;
	
	Return (CommonUseClientServer.CompareVersions(LatestVersion, "1.0.4.1") >= 0);
	
EndFunction

#EndRegion
