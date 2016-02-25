///////////////////////////////////////////////////////////////////////////////////
// SaaSOperationsCached.
//
///////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Retrieves an array of currently supported serializable structural types.
//
// Returns:
//  FixedArray of Type
// 
Function StructuralTypesToSerialize() Export
	
	TypeArray = New Array;
	
	TypeArray.Add(Type("Structure"));
	TypeArray.Add(Type("FixedStructure"));
	TypeArray.Add(Type("Array"));
	TypeArray.Add(Type("FixedArray"));
	TypeArray.Add(Type("Map"));
	TypeArray.Add(Type("FixedMap"));
	TypeArray.Add(Type("KeyAndValue"));
	TypeArray.Add(Type("ValueTable"));
	
	Return New FixedArray(TypeArray);
	
EndFunction
 
// Retrieves the endpoint for sending messages to the service manager.
//
// Returns:
//  ExchangePlanRef.MessageExchange - node that corresponds to the service manager.
//
Function ServiceManagerEndpoint() Export
	
	SetPrivilegedMode(True);
	Return Constants.ServiceManagerEndpoint.Get();
	
EndFunction
 
// Retrieves a map of user contact information kinds and contact information kinds 
// used in service mode XDTO.  
//
// Returns:
//  Map -  map of contact information kinds.
//
Function ContactInformationKindAndXDTOUserMap() Export
	
	Map = New Map;
	Map.Insert(Catalogs.ContactInformationKinds.UserEmail, "UserEMail");
	Map.Insert(Catalogs.ContactInformationKinds.UserPhone, "UserPhone");
	
	Return New FixedMap(Map);
	
EndFunction

// Retrieves a map of XDTO contact information kinds and user contact information
// kinds. 
//
// Returns:
//  Map - map of contact information kinds.
//
Function XDTOContactInformationKindAndUserContactInformationKindMap() Export
	
	Map = New Map;
	For Each KeyAndValue In SaaSOperationsCached.ContactInformationKindAndXDTOUserMap()  Do
		Map.Insert(KeyAndValue.Value, KeyAndValue.Key);
	EndDo;
	
	Return New FixedMap(Map);
	
EndFunction

// Retrieves a map of XDTO rights used in service mode and actions with service users
// 
// Returns:
//  Map -  map of rights and actions.
//
Function XDTORightAndServiceUserActionMap()  Export
	
	Map = New Map;
	Map.Insert("ChangePassword", "ChangePassword");
	Map.Insert("ChangeName", "ChangeName");
	Map.Insert("ChangeFullName", "ChangeFullName");
	Map.Insert("ChangeAccess", "ChangeAccess");
	Map.Insert("ChangeAdmininstrativeAccess", "ChangeAdmininstrativeAccess");
	
	Return New FixedMap(Map);
	
EndFunction

// Retrieves a details model of data related to the data area.
//
// Returns:
//  FixedMap where:
//   Key   - MetadataObject, 
//   Value - String - name of the separator.
//
Function GetDataAreaModel() Export
	
	Result = New Map();
	
	MainDataSeparator = CommonUseCached.MainDataSeparator();
	MainAreaData = CommonUseCached.SeparatedMetadataObjects(
		MainDataSeparator);
	For Each MainAreaDataItem In MainAreaData  Do
		Result.Insert(MainAreaDataItem.Key, MainAreaDataItem.Value);
	EndDo;
	
	AuxiliaryDataSeparator = CommonUseCached.AuxiliaryDataSeparator();
	AuxiliaryAreaData = CommonUseCached.SeparatedMetadataObjects(
		AuxiliaryDataSeparator);
	For Each  AuxiliaryAreaDataItem In AuxiliaryAreaData Do
		Result.Insert(AuxiliaryAreaDataItem.Key, AuxiliaryAreaDataItem.Value);
	EndDo;
	
	Return New FixedMap(Result);
	
EndFunction

#EndRegion