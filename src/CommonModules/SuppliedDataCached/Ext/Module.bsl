///////////////////////////////////////////////////////////////////////////////////
// SuppliedDataCached: the supplied data service mechanism.
//
///////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Retrieves a node that corresponds to the data area.
// 
// Parameters:
//  DataArea - Number – data area whose node will be defined.
//
// Returns:
//  Reference - exchange plan node reference.
//
Function GetDataAreaNode(DataArea) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	SuppliedDataChanges.Ref AS Ref
	|FROM
	|	ExchangePlan.SuppliedDataChanges AS SuppliedDataChanges
	|WHERE
	|	SuppliedDataChanges.DataArea = &DataArea";
	Query.SetParameter("DataArea", DataArea);
	
	SetPrivilegedMode(True);
	Result = Query.Execute();
	SetPrivilegedMode(False);
	
	If Result.IsEmpty() Then
		MessagePattern = NStr("en = 'The node that corresponds the %1 data area is not found.");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, DataArea);
		Raise(MessageText);
	EndIf;
	
	Return Result.Unload()[0].Ref;
	
EndFunction

// Checks whether the item must be added in the data area.
//
// Parameters:
//  TypeEmptyRef – item reference to copy the type.
//
// Returns:
//  Boolean - flag that shows whether the item must be added in the data area.
//
Function MustAddItemInDataArea(TypeEmptyRef) Export
	
	Type = TypeOf(TypeEmptyRef);
	
	MapTable = CommonUse.GetSeparatedAndSharedDataMapTable();
	
	FoundRow = MapTable.Find(Type, "SharedDataType");
	If FoundRow = Undefined Then
		MessagePattern = NStr("en = 'The map row for the %1 supplied data type is not found.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Type);
		Raise(MessageText);
	EndIf;
	
	Add = FoundRow.CopyToAllDataAreas;
	
	Return Add;
	
EndFunction

// Retrieves an object manager.
//
// Parameters:
//  TypeEmptyRef – reference that is used to retrieve the object manager.
//
// Return:
//  ObjectManager 
//
Function GetManagerByTypeEmptyRef(TypeEmptyRef) Export
	
	Type = TypeOf(TypeEmptyRef);
	
	TypeMetadata = Metadata.FindByType(Type);
	
	If Metadata.Catalogs.Contains(TypeMetadata) Then
		Return Catalogs[TypeMetadata.Name];
	ElsIf Metadata.InformationRegisters.Contains(TypeMetadata) Then
		Return InformationRegisters[TypeMetadata.Name];
	Else
		MessagePattern = NStr("en = '%1 is an unsupported type.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Type);
		Raise(MessageText);
	EndIf;
	
EndFunction

// Retrieves a shared data type by the empty reference.
//
// Parameters:
//  SuppliedDataKind – enumeration value that is used to determine the shared data type. 
//
Function GetSharedDataTypeByKind(SuppliedDataKind) Export
	
	MapTable = CommonUse.GetSeparatedAndSharedDataMapTable();
	
	FoundRow = MapTable.Find(SuppliedDataKind, "SuppliedDataKind");
	If FoundRow = Undefined Then
		MessagePattern = NStr("en = 'The supplied data type that corresponds to the %1 data kind is not found.");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, SuppliedDataKind);
		Raise(MessageText);
	EndIf;
	
	SharedDataType = FoundRow.SharedDataType;
	
	Return SharedDataType;
	
EndFunction

// Returns a map of separated data to shared data.
//
// Returns:
// FixedMap with the following key and value:
//  Key   - shared data type. 
//  Value - separated data type.
//
Function SeparatedAndSharedDataTypeMap() Export
	
	TypesToReplace = New Map;
	For Each MapRow In CommonUse.GetSeparatedAndSharedDataMapTable() Do
		If MapRow.SeparatedDataType <> Undefined Then
			TypesToReplace.Insert(MapRow.SharedDataType, 
				MapRow.SeparatedDataType);
		EndIf;
	EndDo;
	
	Return New FixedMap(TypesToReplace);
	
EndFunction
	
Function GetCatalogAttributeTypesByNodeName(NodeName) Export
	
	AttributeTypes = New Structure;
	
	DataType = SuppliedDataCached.GetSharedDataTypeByKind(
		XMLValue(Type("EnumRef.SuppliedDataTypes"),
		"Catalog_" + Mid(NodeName,Find(NodeName, ".")+1)));
	If DataType <> Undefined Then
		CatalogMetadata = Metadata.FindByType(DataType);
	Else
		CatalogMetadata = Metadata.FindByType(FromXMLType(NodeName, ""));
	EndIf;
	
	CatalogName = CatalogMetadata.Name;
	For Each Attribute In CatalogMetadata.StandardAttributes Do	
		AttributeTypes.Insert(Attribute.Name, New Structure("Type, AttributeUse", Attribute.Type.Types()[0], Metadata.ObjectProperties.AttributeUse.ForFolderAndItem));
	EndDo;	
	For Each Attribute In CatalogMetadata.Attributes Do
		AttributeTypes.Insert(Attribute.Name, New Structure("Type, AttributeUse", Attribute.Type.Types()[0], Attribute.Use));	
	EndDo;
	For Each TabularSection In CatalogMetadata.TabularSections Do 
		TabularSectionAttributeTypeList = New Map;
		For Each Attribute In TabularSection.Attributes Do
			TabularSectionAttributeTypeList.Insert(Attribute.Name, Attribute.Type.Types()[0]);
		EndDo;
		AttributeTypes.Insert(TabularSection.Name, New Structure("Type, AttributeUse", TabularSectionAttributeTypeList, TabularSection.Use));
	EndDo;
	
	Return AttributeTypes;
	
EndFunction

Function GetInformationRegisterAttributeTypesByNodeName(NodeName) Export
	
	AttributeTypes = New Structure;
	
	DataType = SuppliedDataCached.GetSharedDataTypeByKind(
		XMLValue(Type("EnumRef.SuppliedDataTypes"),
		"InformationRegister_" + Metadata.FindByType(FromXMLType(NodeName, "")).Name));
	If DataType <> Undefined Then
		InformationRegisterMetadata = Metadata.FindByType(DataType);
	Else
		InformationRegisterMetadata = Metadata.FindByType(FromXMLType(NodeName, ""));
	EndIf;
	
	InformationRegisterName = GetInformationRegisterNameByNodeName(NodeName);
	For Each Attribute In InformationRegisterMetadata.StandardAttributes Do
		AttributeTypes.Insert(Attribute.Name, Attribute.Type.Types()[0]);
	EndDo;	
	For Each Attribute In InformationRegisterMetadata.Dimensions Do
		AttributeTypes.Insert(Attribute.Name, Attribute.Type.Types()[0]);
	EndDo;
	For Each Attribute In InformationRegisterMetadata.Resources Do
		AttributeTypes.Insert(Attribute.Name, Attribute.Type.Types()[0]);
	EndDo;
	For Each Attribute In InformationRegisterMetadata.Attributes Do
		AttributeTypes.Insert(Attribute.Name, Attribute.Type.Types()[0]);
	EndDo;
	
	Return AttributeTypes;
	
EndFunction

Function GetCatalogNameByNodeName(NodeName) Export
	
	DataType = SuppliedDataCached.GetSharedDataTypeByKind(
		XMLValue(Type("EnumRef.SuppliedDataTypes"),
		"Catalog_" + Mid(NodeName,Find(NodeName, ".")+1)));
	If DataType <> Undefined Then
		CatalogMetadata = Metadata.FindByType(DataType);
	Else
		CatalogMetadata = Metadata.FindByType(FromXMLType(NodeName, ""));
	EndIf;
	
	Return CatalogMetadata.Name;	
	
EndFunction

Function GetInformationRegisterNameByNodeName(NodeName) Export
	
	DataType = SuppliedDataCached.GetSharedDataTypeByKind(
		XMLValue(Type("EnumRef.SuppliedDataTypes"),
		"InformationRegister_" + Metadata.FindByType(FromXMLType(NodeName, "")).Name));
	If DataType <> Undefined Then
		InformationRegisterMetadata = Metadata.FindByType(DataType);
	Else
		InformationRegisterMetadata = Metadata.FindByType(FromXMLType(NodeName, ""));
	EndIf;
	
	Return InformationRegisterMetadata.Name;
	
EndFunction







