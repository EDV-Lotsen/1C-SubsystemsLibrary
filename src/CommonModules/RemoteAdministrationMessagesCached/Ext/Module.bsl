///////////////////////////////////////////////////////////////////////////////////
// RemoteAdministrationMessagesCached.
//
///////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Returns a type that is a base one for all remote administration message types.
//
// Returns:
// XDTOObjectType - remote administration message base type.
//
Function AbstractMessage() Export
	
	Return XDTOFactory.Type(RemoteAdministrationMessagePackage(), "Message");
	
EndFunction

// Retrieves XDTO object types that are contained in the specified
// package.
//
// Parameters:
// PackageURL - String - URI of the XDTO package whose message types 
// will be retrieved.
//
// Returns:
// FixedArray of XDTOObjectType - remote administration message types.
//
Function GetPackageMessageTypes(Val PackageURL) Export
	
	Result = New Array;
	
	PackageModels = XDTOFactory.ExportXDTOModel(PackageURL);
	
	BaseType = AbstractMessage();
	
	For Each PackageModel In PackageModels.package Do
		For Each ObjectTypeModel In PackageModel.objectType Do
			ObjectType = XDTOFactory.Type(PackageURL, ObjectTypeModel.name);
			If Not ObjectType.Abstract
				And BaseType.IsDescendant(ObjectType) Then
				
				Result.Add(ObjectType);
			EndIf;
		EndDo;
	EndDo;
	
	Return New FixedArray(Result);
	
EndFunction

// Retrieves message channel names of the specified package.
//
// Parameters:
// PackageURL - String - URI of the XDTO package whose channel names
// will be retrieved.
//
// Returns:
// Array of String - channel names that are found in the package.
//
Function GetPackageChannels(Val PackageURL) Export
	
	Result = New Array;
	
	PackageMessageTypes = 
		RemoteAdministrationMessagesCached.GetPackageMessageTypes(PackageURL);
	
	For Each MessageType In PackageMessageTypes Do
		Result.Add(RemoteAdministrationMessages.ChannelNameByMessageType(MessageType));
	EndDo;
	
	Return New FixedArray(Result);
	
EndFunction

///////////////////////////////////////////////////////////////////////////////////
// Functions returns message types and names of packages that contains these messages. 

// Returns a remote administration package name.
//
// Returns:
// String.
//
Function RemoteAdministrationPackage() Export
	
	Return "http://1c-dn.com/SaaS/RemoteAdministration/App";
	
EndFunction

// Returns a remote administration control package name.
//
// Returns:
// String.
//
Function RemoteAdministrationControlPackage() Export

	Return "http://1c-dn.com/SaaS/RemoteAdministration/Control";
	
EndFunction

// Returns a remote administration message package name.
//
// Returns:
// String.
//
Function RemoteAdministrationMessagePackage() Export

	Return "http://1c-dn.com/SaaS/RemoteAdministration/Messages";
	
EndFunction

// Returns the UpdateUser message type.
//
// Returns:
// XDTOpackages.RemoteAdministrationServiceMode.UpdateUser
//
Function MessageUpdateUser() Export
	
	Return XDTOFactory.Type(RemoteAdministrationPackage(), "UpdateUser");
	
EndFunction

// Returns the SetDataAreaFullAccess message type.
//
// Returns:
// XDTOpackages.RemoteAdministrationServiceMode.SetDataAreaFullAccess
//
Function MessageSetDataAreaFullAccess() Export
	
	Return XDTOFactory.Type(RemoteAdministrationPackage(), "SetDataAreaFullAccess");
	
EndFunction

// Returns the SetAccessToDataArea message type.
//
// Returns:
// XDTOpackages.RemoteAdministrationServiceMode.SetAccessToDataArea
//
Function MessageSetAccessToDataArea() Export
	
	Return XDTOFactory.Type(RemoteAdministrationPackage(), "SetAccessToDataArea");
	
EndFunction

// Returns the SetDefaultUserRights message type.
//
// Returns:
// XDTOpackages.RemoteAdministrationServiceMode.SetDefaultUserRights
//
Function MessageSetDefaultUserRights() Export
	
	Return XDTOFactory.Type(RemoteAdministrationPackage(), "SetDefaultUserRights");
	
EndFunction

// Returns the PrepareDataArea message type.
//
// Returns:
// XDTOpackages.RemoteAdministrationServiceMode.PrepareDataArea
//
Function MessagePrepareDataArea() Export
	
	Return XDTOFactory.Type(RemoteAdministrationPackage(), "PrepareDataArea");
	
EndFunction

// Returns the DeleteDataArea message type.
//
// Returns:
// XDTOpackages.RemoteAdministrationServiceMode.DeleteDataArea
//
Function MessageDeleteDataArea() Export
	
	Return XDTOFactory.Type(RemoteAdministrationPackage(), "DeleteDataArea");
	
EndFunction

// Returns the SetDataAreaParameters message type.
//
// Returns:
// XDTOpackages.RemoteAdministrationServiceMode.SetDataAreaParameters
//
Function MessageSetDataAreaParameters() Export
	
	Return XDTOFactory.Type(RemoteAdministrationPackage(), "SetDataAreaParameters");
	
EndFunction

// Returns the DataAreaPrepared message type.
//
// Returns:
// XDTOpackages.RemoteAdministratorControl.DataAreaPrepared
//
Function MessageDataAreaPrepared() Export
	
	Return XDTOFactory.Type(RemoteAdministrationControlPackage(), "DataAreaPrepared");
	
EndFunction

// Returns the DataAreaDeleted message type.
//
// Returns:
// XDTOpackages.RemoteAdministratorControl.DataAreaDeleted
//
Function MessageDataAreaDeleted() Export
	
	Return XDTOFactory.Type(RemoteAdministrationControlPackage(), "DataAreaDeleted");
	
EndFunction

// Returns the ErrorPreparingDataArea.ErrorPreparingDataArea message type
//
// Returns:
// XDTOpackages.RemoteAdministratorControl.
//
Function MessageErrorPreparingDataArea() Export
	
	Return XDTOFactory.Type(RemoteAdministrationControlPackage(), "ErrorPreparingDataArea");
	
EndFunction

// Returns the ErrorDeletingDataArea message type.
//
// Returns:
// XDTOpackages.RemoteAdministratorControl.ErrorDeletingDataArea
//
Function MessageErrorDeletingDataArea() Export
	
	Return XDTOFactory.Type(RemoteAdministrationControlPackage(), "ErrorDeletingDataArea");
	
EndFunction

// Returns the SetInfoBaseParameters message type.
//
// Returns:
// XDTOpackages.RemoteAdministrationServiceMode.SetInfoBaseParameters
//
Function MessageSetInfoBaseParameters() Export
	
	Return XDTOFactory.Type(RemoteAdministrationPackage(), "SetInfoBaseParameters");
	
EndFunction

// Returns the SetServiceManagerEndPoint message type.
//
// Returns:
// XDTOpackages.RemoteAdministrationServiceMode.SetServiceManagerEndPoint
//
Function MessageSetServiceManagerEndPoint() Export
	
	Return XDTOFactory.Type(RemoteAdministrationPackage(), "SetServiceManagerEndPoint");
	
EndFunction
