
#Region Interface

// Returns type of an XDTO message.
//
// Returns:
//  XDTOObjectType - message type.
//
Function MessageType() Export
	
	Return XDTOFactory.Type(MessagesSaaSCached.MessagePackage(), "Message");
	
EndFunction

// Returns base type for all body types of messages SaaS.
//
// Returns:
//  XDTOObjectType - base body type for messages SaaS.
//
Function TypeBody() Export
	
	Return XDTOFactory.Type(MessagesSaaSCached.MessagePackage(), "Body");
	
EndFunction

// Returns base type for all body types of data area messages SaaS.
//
// Returns:
//  XDTOObjectType - base body type for data area messages SaaS.
//
Function AreaBodyType() Export
	
	Return XDTOFactory.Type(MessagesSaaSCached.MessagePackage(), "ZoneBody");
	
EndFunction

// Returns base type for all body types of data area messages with area authentication SaaS.
//
// Returns:
//  XDTOObjectType - base body type for data area messages with authentication SaaS.
//
Function AuthentifiedAreaBodyType() Export
	
	Return XDTOFactory.Type(MessagesSaaSCached.MessagePackage(), "AuthenticatedZoneBody");
	
EndFunction

// Returns type of a message title.
//
// Returns:
//  XDTOObjectType - message SaaS title type.
//
Function MessageTitleType() Export
	
	Return XDTOFactory.Type(MessagesSaaSCached.MessagePackage(), "Header");
	
EndFunction

// Returns type of a message SaaS exchange node.
//
// Returns:
//  XDTOObjectType - message SaaS exchange node type.
//
Function MessageExchangeNodeType() Export
	
	Return XDTOFactory.Type(MessagesSaaSCached.MessagePackage(), "Node");
	
EndFunction

// Returns types of XDTO objects in the package that match the remote administration message types.
//
// Parameters:
//  PackageURL - String - URL of XDTO package.
//
// Returns:
//  FixedArray(XDTOObjectType) - types of messages found in the package.
//
Function GetPackageMessageTypes(Val PackageURL) Export
	
	BaseType = MessagesSaaSCached.TypeBody();
	Result = MessageInterfacesSaaS.GetPackageMessageTypes(PackageURL, BaseType);
	Return New FixedArray(Result);
	
EndFunction

// Returns the message channel names used in a specified package.
//
// Parameters:
//  PackageURL - String - URL of XDTO package.
//
// Returns:
//  FixedArray(Row) - names of channels used in the package.
//
Function GetPackageChannels(Val PackageURL) Export
	
	Result = New Array;
	
	PackageMessageTypes = 
		MessagesSaaSCached.GetPackageMessageTypes(PackageURL);
	
	For Each MessageType In PackageMessageTypes Do
		Result.Add(MessagesSaaS.ChannelNameByMessageType(MessageType));
	EndDo;
	
	Return New FixedArray(Result);
	
EndFunction

// Returns URL of a message package containing base types.
//
// Returns:
//  String.
//
Function MessagePackage() Export
	
	Return "http://www.1c.ru/SaaS/Messages";
	
EndFunction

#EndRegion
