////////////////////////////////////////////////////////////////////////////////
// Message interfaces SaaS subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Returns message interface versions supported by the current infobase.
//
// Parameters:
//   InterfaceName - String - application message interface name.
//
// Returns:
//   Array (containing strings) - numbers of supported versions, in RR.{S|SS}.VV.BB format
//
Function CurrentInfobaseInterfaceVersions(Val InterfaceName) Export
	
	Result = Undefined;
	
	SenderInterfaces = New Structure;
	RecordOutgoingMessageVersions(SenderInterfaces);
	SenderInterfaces.Property(InterfaceName, Result);
	
	If Result = Undefined Or Result.Count() = 0 Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Current infobase does not support the %1 interface.'"), InterfaceName);
	Else
		Return Result;
	EndIf;
	
EndFunction

// Returns message interface versions supported by the correspondent infobase.
//
// Parameters:
//   MessageInterface         - String    - application message interface name.
//   ConnectionParameters     - Structure - infobase correspondent connection parameters.
//   RecipientPresentation    - String    - infobase correspondent presentation.
//   CurrentInfobaseInterface - String    - application interface name for the current infobase (used for 
//                                          the purposes of backward compatibility with earlier SL versions).
// Returns:
//   String - latest interface version supported both by the correspondent infobase and the current infobase.
//
Function CorrespondentInterfaceVersion(Val MessageInterface, Val ConnectionParameters, Val RecipientPresentation, Val CurrentInfobaseInterface = "") Export
	
	CorrespondentVersions = CommonUse.GetInterfaceVersions(ConnectionParameters, MessageInterface);
	If CurrentInfobaseInterface = "" Then
		CorrespondentVersion = CorrespondentVersionSelection(MessageInterface, CorrespondentVersions);
	Else
		CorrespondentVersion = CorrespondentVersionSelection(CurrentInfobaseInterface, CorrespondentVersions);
	EndIf;
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.SaaSOperations.MessageExchange\OnDetermineCorrespondentInterfaceVersion");
	
	For Each Handler In EventHandlers Do
		Handler.Module.OnDetermineCorrespondentInterfaceVersion(
			MessageInterface,
			ConnectionParameters,
			RecipientPresentation,
			CorrespondentVersion);
	EndDo;
	
	MessageInterfacesSaaSOverridable.OnDetermineCorrespondentInterfaceVersion(
		MessageInterface,
		ConnectionParameters,
		RecipientPresentation,
		CorrespondentVersion);
	
	Return CorrespondentVersion;
	
EndFunction

// Returns the message channel names used in a specified package.
//
// Parameters:
//   PackageURL - String - URL of the XDTO package.
//   BaseType   - XDTOType, base type.
//
// Returns:
//   FixedArray(Row) - channel names in the package.
//
Function GetPackageChannels(Val PackageURL, Val BaseType) Export
	
	Result = New Array;
	
	PackageMessageTypes = 
		GetPackageMessageTypes(PackageURL, BaseType);
	
	For Each MessageType In PackageMessageTypes Do
		Result.Add(MessagesSaaS.ChannelNameByMessageType(MessageType));
	EndDo;
	
	Return New FixedArray(Result);
	
EndFunction

// Returns types of XDTO objects in the package that match the remote administration message types.
//
// Parameters:
//   PackageURL - String - URL of the XDTO package.
//   BaseType   - XDTOType, base type.
//
// Returns:
//   Array(XDTOObjectType) - message types in the package.
//
Function GetPackageMessageTypes(Val PackageURL, Val BaseType) Export
	
	Result = New Array;
	
	PackageModels = XDTOFactory.ExportXDTOModel(PackageURL);
	
	For Each PackageModel In PackageModels.package Do
		For Each ObjectTypeModel In PackageModel.objectType Do
			ObjectType = XDTOFactory.Type(PackageURL, ObjectTypeModel.name);
			If Not ObjectType.Abstract
				And BaseType.IsDescendant(ObjectType) Then
				
				Result.Add(ObjectType);
			EndIf;
		EndDo;
	EndDo;
	
	Return Result;
	
EndFunction

// Returns a fixed array containing the common modules used as outgoing message interface handlers.
//
// Returns:
//   FixedArray.
//
Function GetOutgoingMessageInterfaceHandlers() Export
	
	HandlerArray = New Array();
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.SaaSOperations.MessageExchange\RecordingOutgoingMessageInterfaces");
	
	For Each Handler In EventHandlers Do
		Handler.Module.RecordingOutgoingMessageInterfaces(HandlerArray);
	EndDo;
	
	MessageInterfacesSaaSOverridable.FillOutgoingMessageHandlers(
		HandlerArray);
	
	Return New FixedArray(HandlerArray);
	
EndFunction

// Returns a fixed array containing the common modules used as incoming message interface handlers.
//
// Returns:
//   FixedArray.
//
Function GetIncomingMessageInterfaceHandlers() Export
	
	HandlerArray = New Array();
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.SaaSOperations.MessageExchange\RecordingIncomingMessageInterfaces");
	
	For Each Handler In EventHandlers Do
		Handler.Module.RecordingIncomingMessageInterfaces(HandlerArray);
	EndDo;
	
	MessageInterfacesSaaSOverridable.FillIncomingMessageHandlers(
		HandlerArray);
	
	Return New FixedArray(HandlerArray);
	
EndFunction

// Returns mapping between application message interface names and their handlers.
//
// Returns:
//  FixedMap:
//    Key - String - application interface name.
//    Value - CommonModule.
//
Function GetOutgoingMessageInterfaces() Export
	
	Result = New Map();
	HandlerArray = GetOutgoingMessageInterfaceHandlers();
	For Each Handler In HandlerArray Do
		
		Try
			Result.Insert(Handler.Package(), Handler.Interface());
		Except
			// The application interface export procedure is optional
		EndTry;
		
	EndDo;
	
	Return New FixedMap(Result);
	
EndFunction

// Returns mapping between application interface names and their current versions 
// (those with messages generated in the caller script).
//
// Returns:
//  FixedMap:
//    Key - String - application interface name. 
//    Value - String - version number.
//
Function GetOutgoingMessageVersions() Export
	
	Result = New Map();
	HandlerArray = GetOutgoingMessageInterfaceHandlers();
	For Each Handler In HandlerArray Do
		
		Try
			Result.Insert(Handler.Interface(), Handler.Version());
		Except
			// The application interface export procedure is optional
		EndTry;
		
	EndDo;
	
	Return New FixedMap(Result);
	
EndFunction

// Returns an array of message SaaS translation handlers.
//
// Returns:
//   Array(CommonModule).
//
Function GetMessageTranslationHandlers() Export
	
	Result = New Array();
	
	InterfaceHandlers = GetOutgoingMessageInterfaceHandlers();
	
	For Each InterfaceHandler In InterfaceHandlers Do
		
		TranslationHandlers = New Array();
		InterfaceHandler.MessageTranslationHandlers(TranslationHandlers);
		CommonUseClientServer.SupplementArray(Result, TranslationHandlers);
		
	EndDo;
	
	Return New FixedArray(Result);
	
EndFunction

#EndRegion

#Region InternalInterface

// Declares events of the JobQueue subsystem.
//
// Server events:
//   RecordingIncomingMessageInterfaces
//   RecordingOutgoingMessageInterfaces
//   OnDetermineCorrespondentInterfaceVersion
//
// See the description of this procedure in the StandardSubsystemsServer module.
Procedure OnAddInternalEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS
	
	// Fills the passed array with common modules that contain handlers for interfaces of incoming messages.
	//
	// Parameters:
	//   HandlerArray - array.
	//
	// Syntax:
	// Procedure RecordingIncomingMessageInterfaces(HandlerArray) Export
	//
	// (identical to MessageInterfacesSaaSOverridable.FillIncomingMessageHandlers).
	ServerEvents.Add(
		"StandardSubsystems.SaaSOperations.MessageExchange\RecordingIncomingMessageInterfaces");
	
	// Fills the passed array with common modules that contain handlers for interfaces of outgoing messages.
	//
	// Parameters:
	//   HandlerArray - array.
	//
	//
	// Syntax:
	// Procedure RecordingOutgoingMessageInterfaces(HandlerArray) Export
	//
	// (identical to MessageInterfacesSaaSOverridable.FillOutgoingMessageHandlers).
	ServerEvents.Add(
		"StandardSubsystems.SaaSOperations.MessageExchange\RecordingOutgoingMessageInterfaces");
	
	// It is called when determining a message interface version supported both by the correspondent 
	// infobase and the current infobase. This procedure is intended to implement mechanisms for
	// enabling backward compatibility with earlier versions of correspondent infobases.
	//
	// Parameters:
	//  MessageInterface      - String - name of an application message interface whose version is to be determined.
	//  ConnectionParameters  - Structure - infobase correspondent connection parameters.
	//  RecipientPresentation - String - infobase correspondent presentation.
	//  Result                - String - supported message interface version. 
	//                                   Value of this parameter can be modified in this procedure.
	//
	//
	// Syntax:
	// Procedure OnDetermineCorrespondentInterfaceVersion(Val MessageInterface, Val ConnectionParameters, Val RecipientPresentation, Result) Export
	//
	// (identical to MessageInterfacesSaaSOverridable.OnDetermineCorrespondentInterfaceVersion).
	ServerEvents.Add(
		"StandardSubsystems.SaaSOperations.MessageExchange\OnDetermineCorrespondentInterfaceVersion");
	
EndProcedure

// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS
	
	ServerHandlers[
			"StandardSubsystems.SaaSOperations.MessageExchange\MessageChannelHandlersOnDefine"].Add(
				"MessageInterfacesSaaS");
	
	ServerHandlers[
		"StandardSubsystems.BaseFunctionality\SupportedInterfaceVersionsOnDefine"].Add(
			"MessageInterfacesSaaS");
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// SL event handlers

// Gets the list of message handlers that are processed by the library subsystems.
// 
// Parameters:
//   Handlers - ValueTable - for field structure, see MessageExchange.NewMessageHandlerTable.
// 
Procedure MessageChannelHandlersOnDefine(Handlers) Export
	
	InterfaceHandlers = GetIncomingMessageInterfaceHandlers();
	
	For Each InterfaceHandler In InterfaceHandlers Do
		
		InterfaceChannelHandlers  = New Array();
		InterfaceHandler.MessageChannelHandlers(InterfaceChannelHandlers);
		
		For Each InterfaceChannelHandler In InterfaceChannelHandlers Do
			
			Package = InterfaceChannelHandler.Package();
			BaseType = InterfaceChannelHandler.BaseType();
			
			ChannelNames = GetPackageChannels(Package, BaseType);
			
			For Each ChannelName In ChannelNames Do
				Handler = Handlers.Add();
				Handler.Channel = ChannelName;
				Handler.Handler = MessagesSaaSMessageHandler;
			EndDo;
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Fills the structure with arrays of supported versions of the subsystems that can have versions. 
// Subsystem names are used as structure keys.
// Implements the InterfaceVersion web service functionality.
// This procedure must return current version sets, therefore its body must be changed accordingly 
// before use (see the example below).
//
// Parameters:
//   SupportedVersionStructure - Structure: 
//     Keys   - subsystem names. 
//     Values - arrays of supported version names.
//
// Example:
//
// // FileTransferService
// VersionArray = New Array;
// VersionArray.Add("1.0.1.1");	
// VersionArray.Add("1.0.2.1"); 
// SupportedVersionStructure.Insert("FileTransferService", VersionArray);
// // End FileTransferService
//
Procedure SupportedInterfaceVersionsOnDefine(Val SupportedVersionStructure) Export
	
	RecordIncomingMessageVersions(SupportedVersionStructure);
	
EndProcedure

// Fills the passed structure with the supported versions of incoming messages.
//
// Parameters:
//   SupportedVersionStructure - Structure:
//     Key   - subsystem names.
//     Value - arrays of supported version names.
//
Procedure RecordIncomingMessageVersions(SupportedVersionStructure)
	
	InterfaceHandlers = GetIncomingMessageInterfaceHandlers();
	
	For Each InterfaceHandler In InterfaceHandlers Do
		
		ChannelHandlers = New Array();
		InterfaceHandler.MessageChannelHandlers(ChannelHandlers);
		
		SupportedVersions = New Array();
		
		For Each VersionHandler In ChannelHandlers Do
			
			SupportedVersions.Add(VersionHandler.Version());
			
		EndDo;
		
		SupportedVersionStructure.Insert(
			InterfaceHandler.Interface(),
			SupportedVersions);
		
	EndDo;
	
EndProcedure

// Fills the passed structure with the supported versions of outgoing messages.
//
// Parameters:
//   SupportedVersionStructure - Structure:
//     Key - subsystem names.
//     Value - arrays of supported version names.
//
Procedure RecordOutgoingMessageVersions(SupportedVersionStructure)
	
	InterfaceHandlers = GetOutgoingMessageInterfaceHandlers();
	
	For Each InterfaceHandler In InterfaceHandlers Do
		
		TranslationHandlers = New Array();
		InterfaceHandler.MessageTranslationHandlers(TranslationHandlers);
		
		SupportedVersions = New Array();
		
		For Each VersionHandler In TranslationHandlers Do
			
			SupportedVersions.Add(VersionHandler.ResultingVersion());
			
		EndDo;
		
		SupportedVersions.Add(InterfaceHandler.Version());
		
		SupportedVersionStructure.Insert(
			InterfaceHandler.Interface(),
			SupportedVersions);
		
	EndDo;
	
EndProcedure

// Selects an interface version supported both by the current infobase and the correspondent infobase.
//
// Parameters:
//   Interface             - String        - message interface name.
//   CorrespondentVersions - Array(String) - message interface versions supported by the correspondent infobase.
//
Function CorrespondentVersionSelection(Val Interface, Val CorrespondentVersions)
	
	SenderVersions = CurrentInfobaseInterfaceVersions(Interface);
	
	SelectedVersion = Undefined;
	
	For Each CorrespondentVersion In CorrespondentVersions Do
		
		If SenderVersions.Find(CorrespondentVersion) <> Undefined Then
			
			If SelectedVersion = Undefined Then
				SelectedVersion = CorrespondentVersion;
			Else
				SelectedVersion = ?(CommonUseClientServer.CompareVersions(
						CorrespondentVersion, SelectedVersion) > 0, CorrespondentVersion,
						SelectedVersion);
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return SelectedVersion;
	
EndFunction

#EndRegion
