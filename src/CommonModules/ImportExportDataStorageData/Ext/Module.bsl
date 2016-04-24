////////////////////////////////////////////////////////////////////////////////
// Data import/export subsystem.
//
////////////////////////////////////////////////////////////////////////////////

// Procedures and functions of this module
// are used to map or recreate the references in the value storage.
// Reference mapping requires additional processing in this case, as
// values from value storage are written to stream in base64 format during serialization.
//

// Called during registration of arbitrary data export handlers.
//
// Parameters: HandlerTable - ValueTable. This procedure requires that you add information on
//  the arbitrary data export handlers to the value table. Columns:
//    MetadataObject - MetadataObject. The handler to be registered
//      is called when the object data is exported. 
//    Handler - CommonModule. A common module
//      implementing an arbitrary data export handler. The list of export procedures 
//      to be implemented in the handler depends on the values of
//      the following value table columns. 
//    BeforeExportType - Boolean. Flag specifying whether
//      the handler must be called before exporting all infobase
//      objects associated with this metadata object. If set to True, the common module of
//      the handler must include the
//      exportable procedure BeforeExportType() supporting the following parameters:
//        Container - DataProcessorObject.ImportExportContainerManagerData - container
//          manager used for data export. For more information, see the comment to
//          ImportExportContainerManagerData interface. 
//        Serializer - XDTOSerializer initialized with reference annotation support. 
//          If an arbitrary export handler requires additional data export, it
//          is recommended that you use XDTOSerializer passed
//          to BeforeExportType() as Serializer parameter, not obtained using XDTOSerializer global
//          context property.
//        MetadataObject - MetadataObject. The handler is called before the object data is exported. 
//        Cancel - Boolean. If set to True in BeforeExportType(), objects associated
//          to the current metadata objects are not exported.
//    BeforeExportObject - Boolean. Flag specifying whether
//      the handler must be called before exporting a specific infobase object. If set
//      to True, the common module of the handler must include
//      the exportable procedure BeforeExportObject() supporting the following parameters:
//        Container - DataProcessorObject.ImportExportContainerManagerData - container
//          manager used for data export. For more information, see the comment to
//          ImportExportContainerManagerData interface. 
//        Serializer - XDTOSerializer initialized
//          with reference annotation support. If an arbitrary export handler requires
//          additional data export, it is recommended that you use XDTOSerializer passed
//          to BeforeExportObject() as Serializer parameter, not obtained using XDTOSerializer global
//          context property.
//        Object - ConstantValueManager.*,
//          CatalogObject.*, DocumentObject.*, BusinessProcessObject.*, TaskObject.*,
//          ChartOfAccountsObject.*, ExchangePlanObject.*, ChartOfCharacteristicTypesObject.*,
//          ChartOfCalculationTypesObject.*, InformationRegisterRecordSet.*,
//          AccumulationRegisterRecordSet.*, AccountingRegisterRecordSet.*, CalculationRegisterRecordSet.*, SequenceRecordSet.*, RecalculationRecordSet.* -
//          infobase data object exported after calling the handler.
//          The value passed to BeforeExportObject() procedure as
//          value of the Object parameter can be changed
//          in the BeforeExportObject() handler. The changes will be reflected in the object
//          serialization in export files, but not in the infobase. 
//        Artifacts - Array of XDTODataObject - set of additional information
//          logically associated with the object but not contained in it (object artifacts). Artifacts
//          must be created in the BeforeExportObject() handler and added
//          to the array that is passed as Artifacts parameter value. Each artifact is
//          a XDTO object with abstract XDTO type used as its
//          basic type {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. XDTO packages
//          not included in the DataImportExport subsystem can be used too. The
//          artifacts generated in the BeforeExportObject() procedure will be available
//          in the data import handler procedures (see the comment to OnRegisterDataImportHandlers() procedure).
//        Cancel - Boolean. If set to True in BeforeExportObject(), the corresponding object
//          is not exported.
//    AfterExportType() - Boolean. Flag specifying whether the handler
//      is called after all infobase objects associated with this metadata object are exported. If set
//      to True, the common module of the handler must include
//      the exportable procedure AfterExportType() supporting the following parameters:
//        Container - DataProcessorObject.ImportExportContainerManagerData - container
//          manager used for data export. For more information, see the comment to
//          ImportExportContainerManagerData interface. 
//        Serializer - XDTOSerializer initialized with reference annotation support. 
//          If an arbitrary export handler requires additional data export, it
//          is recommended that you use XDTOSerializer passed
//          to AfterExportType() as Serializer parameter, not obtained using XDTOSerializer global
//          context property.
//        MetadataObject - MetadataObject. The handler is called after the object data is exported.
//
Procedure OnRegisterDataExportHandlers(HandlerTable) Export
	
	MetadataList = ListOfMetadataWithValueStorage();
	
	For Each ListItem In MetadataList Do
		
		NewHandler = HandlerTable.Add();
		NewHandler.MetadataObject = Metadata.FindByFullName(ListItem.Key);
		NewHandler.Handler = ImportExportDataStorageData;
		NewHandler.BeforeExportObject = True;
		
	EndDo;
	
EndProcedure

// Called during registration of arbitrary data import handlers.
//
// Parameters: HandlerTable - ValueTable. The
//  procedure presumes that information on registered arbitrary
//  data import handlers must be added to this table. Columns:
//    MetadataObject - MetadataObject. When importing its data, the
//      handler to be registered is called. 
//    Handler - CommonModule. A common module
//      implementing an arbitrary data import handler. Set of export procedures
//      to be implemented in the handler depends on the values of the
//      following value table columns. 
//    BeforeRefMapping - Boolean. Flag specifying whether
//      the handler must be called before mapping the source infobase references and
//      the current infobase references associated with this metadata object. 
//      If set to True, the common module of the handler must include the
//      exportable procedure BeforeRefMapping() supporting the following parameters:
//        Container - DataProcessorObject.ImportExportContainerManagerData - container
//          manager used for data import. For more information, see the comment to 
//          ImportExportContainerManagerData interface.
//        MetadataObject - MetadataObject. The handler is called before
//          the object references are mapped. 
//        StandardProcessing - Boolean. If set
//          to False in BeforeRefMapping(), the MapRefs() function of
//          the corresponding common module will be called instead of the standard
//          reference mapping (searching the current infobase
//          for objects with the natural key values identical to the values exported
//          from the source infobase).
//          MapRefs() function parameters:
//            Container - DataProcessorObject.ImportExportContainerManagerData - container
//              manager used for data import. For more information, see the comment to
//              ImportExportContainerManagerData interface. 
//            SourceRefTable - ValueTable, contains details
//              on references exported from original infobase. Columns:
//                SourceRef - AnyRef, a source infobase object reference to be mapped to a
//                  current infobase reference. 
//                The other columns are identical to the object's natural key fields that were passed
//                  to ImportExportInfobaseData.RefMappingRequiredOnImport() during data export. 
//          MapRefs() returns: - ValueTable with the following columns:
//            SourceRef - AnyRef, object reference exported from
//              the original infobase.
//            Ref - AnyRef mapped the original reference in the current infobase.
//        Cancel - Boolean. If set to True in BeforeRefMapping(), references
//          corresponding to the current metadata object are not mapped.
//    BeforeImportType - Boolean. Flag specifying whether
//      the handler must be called before importing all
//      infobase objects associated with this metadata object. If set to True, the common module of
//      the handler must include the
//      exportable procedure BeforeImportType() supporting the following parameters:
//        Container - DataProcessorObject.ImportExportContainerManagerData - container
//          manager used for data import. For more
//          information, see the comment to ImportExportContainerManagerData interface.
//        MetadataObject - MetadataObject. The handler is called before
//          the object data is imported. 
//        Cancel - Boolean. If set to True in AfterImportType(), the data objects corresponding to
//          the current metadata object are not imported.
//    BeforeImportObject - Boolean. Flag specifying whether
//      the handler must be called before importing
//      the infobase object associated with this metadata object. If set to True, the common module of
//      the handler must include the
//      exportable procedure BeforeImportObject() supporting the following parameters:
//        Container - DataProcessorObject.ImportExportContainerManagerData - container
//          manager used for data import. For more
//          information, see the comment to ImportExportContainerManagerData interface.
//        Object - ConstantValueManager.*,
//          CatalogObject.*, DocumentObject.*, BusinessProcessObject.*, TaskObject.*,
//          ChartOfAccountsObject.*, ExchangePlanObject.*, ChartOfCharacteristicTypesObject.*,
//          ChartOfCalculationTypesObject.*, InformationRegisterRecordSet.*,
//          AccumulationRegisterRecordSet.*, AccountingRegisterRecordSet.*, CalculationRegisterRecordSet.*, SequenceRecordSet.*, RecalculationRecordSet.* -
//          infobase data object imported after the handler is called.
//          Value passed to the BeforeImportObject() procedure as
//          Object parameter value can be modified in the BeforeImportObject() handler procedure.
//        Artifacts - Array of XDTODataObject - additional data logically
//          associated with the data object but not contained in it. Generated in
//          BeforeExportObject() exportable procedures of data export handlers (see
//          the comment to the OnRegisterDataExportHandlers() procedure). Each artifact is
//          a XDTO object with abstract XDTO type used as its
//          basic type {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. XDTO packages
//          not included in the DataImportExport subsystem can be used too.
//        Cancel - Boolean. If set to True in BeforeImportObject(), the data object is not imported.
//    AfterImportObject - Boolean. Flag specifying whether
//      the handler must be called after importing
//      the infobase object associated with this metadata object. If set to True, the common module of
//      the handler must include the
//      exportable procedure AfterImportObject() supporting the following parameters:
//        Container - DataProcessorObject.ImportExportContainerManagerData - container
//          manager used for data import. For more
//          information, see the comment to ImportExportContainerManagerData interface.
//        Object - ConstantValueManager.*,
//          CatalogObject.*, DocumentObject.*, BusinessProcessObject.*, TaskObject.*,
//          ChartOfAccountsObject.*, ExchangePlanObject.*, ChartOfCharacteristicTypesObject.*,
//          ChartOfCalculationTypesObject.*, InformationRegisterRecordSet.*,
//          AccumulationRegisterRecordSet.*, AccountingRegisterRecordSet.*, CalculationRegisterRecordSet.*, SequenceRecordSet.*, RecalculationRecordSet.* -
//          infobase data object imported before the handler is called.
//        Artifacts - Array of XDTODataObject - additional data logically
//          associated with the data object but not contained in it. Generated in
//          BeforeExportObject() exportable procedures of data export handlers (see
//          the comment to the OnRegisterDataExportHandlers() procedure). Each artifact is
//          a XDTO object with abstract XDTO type used as its
//          basic type {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. XDTO packages
//          not included in the DataImportExport subsystem can be used too.
//    AfterImportType - Boolean. Flag specifying whether
//      the handler must be called after importing all
//      infobase objects associated with this metadata object. If set to True, the common module of
//      the handler must include the
//      exportable procedure AfterImportType() supporting the following parameters:
//        Container - DataProcessorObject.ImportExportContainerManagerData - container
//          manager used for data import. For more
//          information, see the comment to ImportExportContainerManagerData interface.
//        MetadataObject - MetadataObject. The handler is called after the object data is imported.
//
Procedure OnRegisterDataImportHandlers(HandlerTable) Export
	
	MetadataList = ListOfMetadataWithValueStorage();
	
	For Each ListItem In MetadataList Do
		
		NewHandler = HandlerTable.Add();
		NewHandler.MetadataObject = Metadata.FindByFullName(ListItem.Key);
		NewHandler.Handler = ImportExportDataStorageData;
		NewHandler.BeforeImportObject = True;
		
	EndDo;
	
EndProcedure

// Adds update handler procedures required by the subsystem to the Handlers list.
//
// Parameters:
//   Handlers - ValueTable - see the description of NewUpdateHandlerTable function 
//              in the InfobaseUpdate common module.
// 
Procedure RegisterUpdateHandlers(Handlers) Export
	
	Handler               = Handlers.Add();
	Handler.Version       = "*";
	Handler.ExclusiveMode = False;
	Handler.SharedData    = True;
	Handler.Procedure     = "ImportExportDataStorageData.GenerateListOfMetadataObjectsWithValueStorage";
	
EndProcedure

// Update handler 
// Generates the list of metadata that have types with Value storage.
//
Procedure GenerateListOfMetadataObjectsWithValueStorage() Export
	
	ValueStorageType = Type("ValueStorage");
	
	MetadataList = New Map;
	
	For Each ObjectMetadata In DataExportImportInternal.AllConstants() Do
		AddConstantToMetadataList(ObjectMetadata, MetadataList);
	EndDo;
	
	For Each ObjectMetadata In DataExportImportInternal.AllRefData() Do
		AddRefTypeToMetadataList(ObjectMetadata, MetadataList);
	EndDo;
	
	For Each ObjectMetadata In DataExportImportInternal.AllRecordsSets() Do
		AddRegisterToMetadataTable(ObjectMetadata, MetadataList);
	EndDo;
	
	ListStorage = New ValueStorage(MetadataList);
	
	SetPrivilegedMode(True);
	Constants.MetadataObjectsWithValueStorageList.Set(ListStorage);
	SetPrivilegedMode(False);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// INTERNAL EVENT HANDLERS

Procedure BeforeDataExport(Container) Export
	
	Container.AdditionalProperties.Insert("MetadataWithValueStorage", ListOfMetadataWithValueStorage());
	
EndProcedure

Procedure BeforeExportObject(Container, Serializer, Object, Artifacts, Cancel) Export
	
	MetadataObject = Object.Metadata();
	CurrentObjectMetadata = CurrentObjectMetadata(Container, MetadataObject);
	
	If CurrentObjectMetadata = Undefined Then
		
		Raise CTLAndSLIntegration.SubstituteParametersInString(
			NStr("en = 'ImportExportDataStorageData.BeforeExportObject() handler cannot process metadata object %1.'"),
			MetadataObject.FullName());
		
	EndIf;
	
	If DataExportImportInternal.IsConstant(MetadataObject) Then
		
		BeforeExportConstant(Container, Object, Artifacts, CurrentObjectMetadata);
		
	ElsIf DataExportImportInternal.IsRefData(MetadataObject) Then
		
		BeforeExportRefObject(Container, Object, Artifacts, CurrentObjectMetadata);
		
	ElsIf DataExportImportInternal.IsRecordSet(MetadataObject) Then
		
		BeforeExportRecordSet(Container, Object, Artifacts, CurrentObjectMetadata);
		
	Else
		
		Raise CTLAndSLIntegration.SubstituteParametersInString(
			NStr("en = 'Unexpected metadata object: %1.'"),
			MetadataObject.FullName);
		
	EndIf;
	
EndProcedure

Procedure BeforeExportConstant(Container, Object, Artifacts, CurrentObjectMetadata)
	
	NewArtifact = XDTOFactory.Create(ValueStorageArtifactType());
	NewArtifact.Owner = XDTOFactory.Create(ConstantOwnerType());
	
	If ExportValueStorage(Container, Object.Value, NewArtifact.Data) Then
		Object.Value = New ValueStorage(Undefined);
		Artifacts.Add(NewArtifact);
	EndIf;
	
EndProcedure

Procedure BeforeExportRefObject(Container, Object, Artifacts, CurrentObjectMetadata)
	
	For Each CurrentAttribute In CurrentObjectMetadata Do
		
		If CurrentAttribute.TabularSectionName = Undefined Then
			
			AttributeName = CurrentAttribute.AttributeName;
			
			NewArtifact = XDTOFactory.Create(ValueStorageArtifactType());
			NewArtifact.Owner = XDTOFactory.Create(ObjectOwnerType());
			NewArtifact.Owner.Property = AttributeName;
			
			If ExportValueStorage(Container, Object[AttributeName], NewArtifact.Data) Then
				Object[AttributeName] = New ValueStorage(Undefined);
				Artifacts.Add(NewArtifact);
			EndIf;
			
		Else
			
			AttributeName      = CurrentAttribute.AttributeName;
			TabularSectionName = CurrentAttribute.TabularSectionName;
			
			For Each TabularSectionRow In Object[TabularSectionName] Do 
				
				NewArtifact = XDTOFactory.Create(ValueStorageArtifactType());
				NewArtifact.Owner = XDTOFactory.Create(TabularSectionOwnerType());
				NewArtifact.Owner.TabularSection = TabularSectionName;
				NewArtifact.Owner.Property = AttributeName;
				NewArtifact.Owner.LineNumber = TabularSectionRow.LineNumber;
				
				If ExportValueStorage(Container, TabularSectionRow[AttributeName], NewArtifact.Data) Then
					TabularSectionRow[AttributeName] = New ValueStorage(Undefined);
					Artifacts.Add(NewArtifact);
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure BeforeExportRecordSet(Container, RecordSet, Artifacts, CurrentObjectMetadata)
	
	For Each CurrentAttribute In CurrentObjectMetadata Do
		
		PropertyName = CurrentAttribute.AttributeName;
		
		For Each Write In RecordSet Do
			
			NewArtifact = XDTOFactory.Create(ValueStorageArtifactType());
			NewArtifact.Owner = XDTOFactory.Create(RecordSetOwnerType());
			NewArtifact.Owner.Property = PropertyName;
			NewArtifact.Owner.LineNumber = Write.LineNumber;
			
			If ExportValueStorage(Container, Write[PropertyName], NewArtifact.Data) Then
				Write[PropertyName] = New ValueStorage(Undefined);
				Artifacts.Add(NewArtifact);
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

Function ExportValueStorage(Container, ValueStorage, Artifact)
	
	If ValueStorage = Null Then
		// For example, values (read from the catalog group) 
		// of attributes used for catalog items only
		Return False;
	EndIf;
	
	Value = ValueStorage.Get();
	If Value = Undefined Or
		(DataExportImportInternal.IsPrimitiveType(TypeOf(Value)) And Not ValueIsFilled(Value)) Then
		Return False;
	Else
		
		Try
			
			Artifact = WriteValueStorageToArtifact(Container, Value);
			Return True;
			
		Except
			
			Return False; // If storage serialization fails, the storage should remain in the object form
			
		EndTry;
		
	EndIf;
	
EndFunction

Function WriteValueStorageToArtifact(Container, Val StorageValue)
	
	ExportAsBinary = TypeOf(StorageValue) = Type("BinaryData");
	
	If ExportAsBinary Then
		
		Return WriteBinaryValueStorageToArtifact(Container, StorageValue);
		
	Else
		
		Return WriteSerializedValueStorageToArtifact(Container, StorageValue);
		
	EndIf;
	
EndFunction

Function WriteSerializedValueStorageToArtifact(Container, Val StorageValue)
	
	ValueDetails = XDTOFactory.Create(ValueToSerializeType());
	ValueDetails.Data = XDTOSerializer.WriteXDTO(StorageValue);
	
	Return ValueDetails;
	
EndFunction

Function WriteBinaryValueStorageToArtifact(Container, Val StorageValue)
	
	FileName = Container.CreateArbitraryFile("bin");
	StorageValue.Write(FileName);
	
	ValueDetails = XDTOFactory.Create(BinaryValueType());
	ValueDetails.RelativeFilePath = Container.GetRelativeFileName(FileName);
	
	Return ValueDetails;
	
EndFunction

//

Procedure BeforeImportObject(Container, Object, Artifacts, Cancel) Export
	
	MetadataObject = Object.Metadata();
	
	For Each Artifact In Artifacts Do
		
		If Artifact.Type() <> ValueStorageArtifactType() Then
			Continue;
		EndIf;
		
		If DataExportImportInternal.IsConstant(MetadataObject) Then
			
			BeforeImportConstant(Container, Object, Artifact);
			
		ElsIf DataExportImportInternal.IsRefData(MetadataObject) Then
			
			BeforeImportRefObject(Container, Object, Artifact);
			
		ElsIf DataExportImportInternal.IsRecordSet(MetadataObject) Then
			
			BeforeImportRecordSet(Container, Object, Artifact);
			
		Else
			
			Raise CTLAndSLIntegration.SubstituteParametersInString(
				NStr("en = 'Unexpected metadata object: %1.'"),
				MetadataObject.FullName);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure BeforeImportConstant(Container, Object, Artifact)
	
	If Artifact.Owner.Type() = ConstantOwnerType() Then
		ImportValueStorage(Container, Object.Value, Artifact);
	Else
		
		Raise CTLAndSLIntegration.SubstituteParametersInString(
			NStr("en = 'Owner type {%1}%2 cannot be used for metadata object %3.'"),
			Artifact.Owner.Type().NamespaceURI,
			Artifact.Owner.Type().Name,
			Object.Metadata().FullName()
		);
		
	EndIf;
	
EndProcedure

Procedure BeforeImportRefObject(Container, Object, Artifact)
	
	If Artifact.Owner.Type() = ObjectOwnerType() Then
		ImportValueStorage(Container, Object[Artifact.Owner.Property], Artifact);
	ElsIf Artifact.Owner.Type() = TabularSectionOwnerType() Then
		ImportValueStorage(Container,
			Object[Artifact.Owner.TabularSection].Get(Artifact.Owner.LineNumber - 1)[Artifact.Owner.Property],
			Artifact);
	Else
		
		Raise CTLAndSLIntegration.SubstituteParametersInString(
			NStr("en = 'Owner type {%1}%2 cannot be used for metadata object %3.'"),
			Artifact.Owner.Type().NamespaceURI,
			Artifact.Owner.Type().Name,
			Object.Metadata().FullName()
		);
		
	EndIf;
	
EndProcedure

Procedure BeforeImportRecordSet(Container, RecordSet, Artifact)
	
	If Artifact.Owner.Type() = RecordSetOwnerType() Then
		ImportValueStorage(Container,
			RecordSet.Get(Artifact.Owner.LineNumber)[Artifact.Owner.Property],
			Artifact);
	Else
		
		Raise CTLAndSLIntegration.SubstituteParametersInString(
			NStr("en = 'Owner type {%1}%2 cannot be used for metadata object %3.'"),
			Artifact.Owner.Type().NamespaceURI,
			Artifact.Owner.Type().Name,
			RecordSet.Metadata().FullName()
		);
		
	EndIf;
	
EndProcedure

Procedure ImportValueStorage(Container, ValueStorage, Artifact)
	
	If Artifact.Data.Type() = BinaryValueType() Then
		FileName = Container.GetFullFileName(Artifact.Data.RelativeFilePath);
		Value = New BinaryData(FileName);
	ElsIf Artifact.Data.Type() = ValueToSerializeType() Then
		//If TypeOf(Value) = Type("XDTODataObject") Then
		If TypeOf(Artifact.Data.Data) = Type("XDTODataObject") Then
			Value = XDTOSerializer.ReadXDTO(Artifact.Data.Data);
		Else
			Value = Artifact.Data.Data;
		EndIf;
	Else
		
		Raise CTLAndSLIntegration.SubstituteParametersInString(
			NStr("en = 'Unexpected type of value storage data placement in the export container: {%1}%2.'"),
			Artifact.Data.Type().NamespaceURI,
			Artifact.Data.Type().Name,
		);
		
	EndIf;
	
	ValueStorage = New ValueStorage(Value);
	
EndProcedure

//


Function ValueStorageArtifactType()
	
	Return XDTOFactory.Type(Package(), "ValueStorageArtefact");
	
EndFunction

Function BinaryValueType()
	
	Return XDTOFactory.Type(Package(), "BinaryValueStorageData");
	
EndFunction

Function ValueToSerializeType()
	
	Return XDTOFactory.Type(Package(), "SerializableValueStorageData");
	
EndFunction

Function ConstantOwnerType()
	
	Return XDTOFactory.Type(Package(), "OwnerConstant");
	
EndFunction

Function ObjectOwnerType()
	
	Return XDTOFactory.Type(Package(), "OwnerObject");
	
EndFunction

Function TabularSectionOwnerType()
	
	Return XDTOFactory.Type(Package(), "OwnerObjectTabularSection");
	
EndFunction

Function RecordSetOwnerType()
	
	Return XDTOFactory.Type(Package(), "OwnerOfRecordset");
	
EndFunction

Function Package()
	
	Return "http://www.1c.ru/1cFresh/Data/Artefacts/ValueStorage/1.0.0.1";
	
EndFunction


////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

Function CurrentObjectMetadata(Container, Val ObjectMetadata)
	
	FullMetadataName = ObjectMetadata.FullName();
	
	MetadataList = Container.AdditionalProperties.MetadataWithValueStorage;
	
	CurrentMetadata = MetadataList.Get(FullMetadataName);
	If CurrentMetadata = Undefined Then 
		Return Undefined;
	EndIf;
	
	Return CurrentMetadata;
	
EndFunction

// Returns a deserialized value of the MetadataObjectsWithValueStorageList constant.
//
// Returns:
//  Map - Key: Metadata object, Value - Structure. For constants, the structure is
//  empty. For reference types and records sets, the structure is: Key - Name of attribute with value storage, 
//  Value - Name of the attribute's tabular section, or empty string.
//
Function ListOfMetadataWithValueStorage()
	
	SetPrivilegedMode(True);
	MetadataList = Constants.MetadataObjectsWithValueStorageList.Get().Get();
	SetPrivilegedMode(False);
	
	If TypeOf(MetadataList) <> Type("Map") Then 
		Raise NStr("en = 'The list of metadata with value storage is not filled.'");
	EndIf;
	
	Return MetadataList;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

Function StructureOfAttributesWithValueStorage()
	
	Result = New Structure;
	Result.Insert("TabularSectionName");
	Result.Insert("AttributeName");
	
	Return Result;
	
EndFunction

Procedure AddConstantToMetadataList(Metadata, MetadataList)
	
	ValueStorageType = Type("ValueStorage");
	
	If Not Metadata.Type.ContainsType(ValueStorageType) Then 
		Return;
	EndIf;
	
	MetadataList.Insert(Metadata.FullName(), New Array);
	
EndProcedure

Procedure AddRefTypeToMetadataList(Metadata, MetadataList)
	
	StructureArray = New Array;
	
	For Each Attribute In Metadata.Attributes Do 
		
		AddAttributeToTable(StructureArray, Attribute);
		
	EndDo;
	
	For Each TabularSection In Metadata.TabularSections Do 
		
		For Each Attribute In TabularSection.Attributes Do
			
			AddAttributeToTable(StructureArray, Attribute, TabularSection);
			
		EndDo;
		
	EndDo;
	
	InsertMetadataWithValueStorageToMap(Metadata.FullName(), MetadataList, StructureArray);
	
EndProcedure

Procedure AddRegisterToMetadataTable(Val ObjectMetadata, Val MetadataList)
	
	StructureArray = New Array;
	
	For Each Dimension In ObjectMetadata.Dimensions Do 
		
		If Metadata.CalculationRegisters.Contains(ObjectMetadata.Parent()) Then
			Dimension = Dimension.RegisterDimension;
		EndIf;
		AddAttributeToTable(StructureArray, Dimension);
		
	EndDo;
	
	If Metadata.Sequences.Contains(ObjectMetadata) 
		Or Metadata.CalculationRegisters.Contains(ObjectMetadata.Parent()) Then 
		
		Return;
		
	EndIf;
	
	For Each Attribute In ObjectMetadata.Attributes Do 
		
		AddAttributeToTable(StructureArray, Attribute);
		
	EndDo;
	
	For Each Resource In ObjectMetadata.Resources Do 
		
		AddAttributeToTable(StructureArray, Resource);
		
	EndDo;
	
	InsertMetadataWithValueStorageToMap(ObjectMetadata.FullName(), MetadataList, StructureArray);
	
EndProcedure

Procedure AddAttributeToTable(StructureArray, Attribute, TabularSection = Undefined)
	
	ValueStorageType = Type("ValueStorage");
	
	If Not Attribute.Type.ContainsType(ValueStorageType) Then 
		Return;
	EndIf;
	
	AttributeName      = Attribute.Name;
	TabularSectionName = ?(TabularSection = Undefined, Undefined, TabularSection.Name);
	
	Structure = StructureOfAttributesWithValueStorage();
	Structure.TabularSectionName = TabularSectionName;
	Structure.AttributeName      = AttributeName;
	
	StructureArray.Add(Structure);
	
EndProcedure

Procedure InsertMetadataWithValueStorageToMap(FullMetadataName, MetadataList, StructureArray)
	
	If StructureArray.Count() = 0 Then 
		Return;
	EndIf;
	
	MetadataList.Insert(FullMetadataName, StructureArray);
	
EndProcedure
