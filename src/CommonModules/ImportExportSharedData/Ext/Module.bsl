////////////////////////////////////////////////////////////////////////////////
// Data import/export subsystem.
//
////////////////////////////////////////////////////////////////////////////////

Function TypeDependenciesOnRefReplacement() Export
	
	Return ReadCommonClassifierDependencyCache();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// INTERNAL EVENT HANDLERS

// Fills array of types for which the reference annotation
// in files must be used when exporting.
//
// Parameters:
//  Types - Array of MetadataObject
//
Procedure OnFillTypesThatRequireRefAnnotationOnImport(Types) Export
	
	SharedDataTypes = DataExportImportInternalEvents.GetCommonDataTypesThatSupportRefMappingOnImport();
	For Each SharedDataType In SharedDataTypes Do
		Types.Add(SharedDataType);
	EndDo;
	
EndProcedure

// Called during registration of arbitrary data export handlers.
//
// Parameters: HandlerTable - ValueTable. This
//  procedure requires that you add information on
//  the arbitrary data export handlers to the value table. Columns:
//    MetadataObject - MetadataObject. The handler
//      to be registered
//    is called when the object data is exported. Handler - CommonModule. A common module
//      implementing an arbitrary data export handler. The list of export
//      procedures to be implemented in the handler depends on
//      the values of
//    the following value table columns. BeforeExportType - Boolean. Flag specifying whether
//      the handler must be called before exporting all infobase
//      objects associated with this metadata object. If set to True - the common module of
//      the handler must include the
//      exportable procedure BeforeExportType() supporting the following parameters:
//        Container - DataProcessorObject.ImportExportContainerManagerData - container
//          manager used for data export. For more
//          information, see the comment to
//        ImportExportContainerManagerData interface. Serializer - XDTOSerializer initialized
//          with reference annotation support. If an arbitrary export handler requires
//          additional data export - it
//          is recommended that you use XDTOSerializer passed
//          to BeforeExportType() as Serializer parameter, not obtained using XDTOSerializer global
//          context property.
//        MetadataObject - MetadataObject. The handler
//          is called before
//        the object data is exported. Cancel - Boolean. If set to True
//          in BeforeExportType() - objects associated
//          to the current metadata objects are not exported.
//    BeforeExportObject - Boolean. Flag specifying whether
//      the handler must be called before exporting a specific infobase object. If set
//      to True - the common module of the handler must include
//      the exportable procedure BeforeExportObject() supporting the following parameters:
//        Container - DataProcessorObject.ImportExportContainerManagerData - container
//          manager used for data export. For more
//          information, see the comment to
//        ImportExportContainerManagerData interface. Serializer - XDTOSerializer initialized
//          with reference annotation support. If an arbitrary export handler requires
//          additional data export - it
//          is recommended that you use XDTOSerializer passed
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
//          serialization in export files, but not
//        in the infobase. Artifacts - Array of XDTODataObject - set of additional information
//          logically associated with the object but not contained in it (object artifacts). Artifacts
//          must be created in the BeforeExportObject() handler and added
//          to the array that is passed as Artifacts parameter value. Each artifact is
//          a XDTO object with abstract XDTO type used as its
//          basic type {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. XDTO packages
//          not included in the DataImportExport subsystem can be used too. The
//          artifacts generated in the BeforeExportObject() procedure will be available
//          in the data import handler procedures (see the comment to OnRegisterDataImportHandlers() procedure).
//        Cancel - Boolean. If set to True
//           in BeforeExportObject() - the corresponding object
//           is not exported.
//    AfterExportType() - Boolean. Flag specifying whether the handler
//      is called after all infobase objects associated with this metadata object are exported. If set
//      to True - the common module of the handler must include
//      the exportable procedure AfterExportType() supporting the following parameters:
//        Container - DataProcessorObject.ImportExportContainerManagerData - container
//          manager used for data export. For more
//          information, see the comment to
//        ImportExportContainerManagerData interface. Serializer - XDTOSerializer initialized
//          with reference annotation support. If an arbitrary export handler requires
//          additional data export - it
//          is recommended that you use XDTOSerializer passed
//          to AfterExportType() as Serializer parameter, not obtained using XDTOSerializer global
//          context property.
//        MetadataObject - MetadataObject. The handler
//          is called after the object data is exported.
//
Procedure OnRegisterDataExportHandlers(HandlerTable) Export
	
	SharedDataTypes = DataExportImportInternalEvents.GetCommonDataTypesThatSupportRefMappingOnImport();
	
	For Each SharedDataType In SharedDataTypes Do
		
		NewHandler = HandlerTable.Add();
		NewHandler.MetadataObject = SharedDataType;
		NewHandler.Handler = ImportExportSharedData;
		NewHandler.BeforeExportType = True;
		NewHandler.BeforeExportObject = True;
		
	EndDo;
	
	SharedDataControlObjectsOnExport = ReadSharedDataReferenceControlCacheOnExport();
	For Each SharedDataControlObjectOnExport In SharedDataControlObjectsOnExport Do
		
		MetadataObject = Metadata.FindByFullName(SharedDataControlObjectOnExport.Key);
		
		If SharedDataTypes.Find(MetadataObject) = Undefined Then // Otherwise, a handler is already registered for the object
			
			NewHandler = HandlerTable.Add();
			NewHandler.MetadataObject = MetadataObject;
			NewHandler.Handler = ImportExportSharedData;
			NewHandler.BeforeExportObject = True;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure BeforeDataExport(Container) Export
	
	Container.AdditionalProperties.Insert(
		"SharedDataRefControlObjects",
		ReadSharedDataReferenceControlCacheOnExport()
	);
	
	Container.AdditionalProperties.Insert(
		"CommonDataRequiringRefMapping",
		DataExportImportInternalEvents.GetCommonDataTypesThatSupportRefMappingOnImport()
	);
	
	Container.AdditionalProperties.Insert(
		"SeparatorContentLocalCache",
		New Map()
	);
	
EndProcedure

//Called before exporting
// a data type. See OnRegisterDataExportHandlers
//
Procedure BeforeExportType(Container, Serializer, MetadataObject, Cancel) Export
	
	If Not DataExportImportInternal.IsRefData(MetadataObject) Then 
		Raise NStr("en = 'Reference substitution is only available for reference data'");
	EndIf;
	
	ObjectManager = CTLAndSLIntegration.ObjectManagerByFullName(MetadataObject.FullName());
	NaturalKeyFields = ObjectManager.NaturalKeyFields();
	
	CheckNaturalKeyFields(MetadataObject, NaturalKeyFields);
	CheckNaturalKeyDuplicates(MetadataObject, NaturalKeyFields);
	
EndProcedure

//Called before exporting
// a data object. See OnRegisterDataExportHandlers
//
Procedure BeforeExportObject(Container, Serializer, Object, Artifacts, Cancel) Export
	
	MetadataObject = Object.Metadata();
	MetadataObjectFullName = MetadataObject.FullName();
	
	SharedDataRefControlFields =
		Container.AdditionalProperties.SharedDataRefControlObjects.Get(MetadataObjectFullName);
	
	If SharedDataRefControlFields <> Undefined Then
		SharedDataReferenceControlOnExport(Container, Object, SharedDataRefControlFields);
	EndIf;
	
	If Container.AdditionalProperties.CommonDataRequiringRefMapping.Find(MetadataObject) <> Undefined Then
		
		If Not DataExportImportInternal.IsRefData(MetadataObject) Then 
			Raise NStr("en = 'Reference substitution is only available for reference data'");
		EndIf;
		
		ObjectManager = CTLAndSLIntegration.ObjectManagerByFullName(MetadataObjectFullName);
		
		NaturalKeyFields = ObjectManager.NaturalKeyFields();
		
		NaturalKey = New Structure();
		For Each NaturalKeyField In NaturalKeyFields Do
			NaturalKey.Insert(NaturalKeyField, Object[NaturalKeyField]);
		EndDo;
		
		ImportExportInfobaseData.MustMapRefOnImport(Container, Object.Ref, NaturalKey);
		
	EndIf;
	
EndProcedure

// Fills the common classifier dependency cache for reference substitution purposes
//
Procedure FillCommonClassifierDependencyCache() Export
	
	Cache = New Map();
	
	CommonClassifierTypes = DataExportImportInternalEvents.GetCommonDataTypesThatSupportRefMappingOnImport();
	
	For Each CommonClassifierType In CommonClassifierTypes Do
		
		Manager = CTLAndSLIntegration.ObjectManagerByFullName(CommonClassifierType.FullName());
		
		NaturalKeyFields = Manager.NaturalKeyFields();
		For Each NaturalKeyField In NaturalKeyFields Do
			
			For Iterator = 0 To CommonClassifierType.StandardAttributes.Count() - 1 Do
				
				TypesOfFields = Undefined;
				
				// Search in standard attributes
				StandardAttribute = CommonClassifierType.StandardAttributes[Iterator];
				If StandardAttribute.Name = NaturalKeyField Then
					TypesOfFields = StandardAttribute.Type;
				EndIf;
				
			EndDo;
			
			// Search in attributes
			Attribute = CommonClassifierType.Attributes.Find(NaturalKeyField);
			If Attribute <> Undefined Then
				TypesOfFields = Attribute.Type;
			EndIf;
			
			// Search in common attributes
			CommonAttribute = Metadata.CommonAttributes.Find(NaturalKeyField);
			If CommonAttribute <> Undefined Then
				For Each CommonAttribute In Metadata.CommonAttributes Do
					If CommonAttribute.Content.Find(CommonClassifierType) <> Undefined Then
						TypesOfFields = CommonAttribute.Type;
					EndIf;
				EndDo;
			EndIf;
			
			If TypesOfFields = Undefined Then
				
				Raise CTLAndSLIntegration.SubstituteParametersInString(
					NStr("en = 'Cannot use field %1 as a natural key field
                          |for object %2: object field not found.'", Metadata.DefaultLanguage.LanguageCode),
					NaturalKeyField,
					CommonClassifierType.FullName()
				);
				
			EndIf;
			
			For Each FieldType In TypesOfFields.Types() Do
				
				If Not DataExportImportInternal.IsPrimitiveType(FieldType) Then
					
					If FieldType = Type("ValueStorage") Then
						
						Raise CTLAndSLIntegration.SubstituteParametersInString(
							NStr("en = 'Cannot use field %1 as a natural key field for
                                  |object %2: using values of ValueStorage type as natural key fields is not supported.'", Metadata.DefaultLanguage.LanguageCode),
							NaturalKeyField,
							CommonClassifierType.FullName()
						);
						
					EndIf;
					
					Ref = New(FieldType);
					
					If CommonClassifierTypes.Find(Ref.Metadata()) <> Undefined Then
						
						If Cache.Get(CommonClassifierType.FullName()) <> Undefined Then
							Cache.Get(CommonClassifierType.FullName()).Add(Ref.Metadata().FullName());
						Else
							NewArray = New Array();
							NewArray.Add(Ref.Metadata().FullName());
							Cache.Insert(CommonClassifierType.FullName(), NewArray);
						EndIf;
						
					Else
						
						Raise StringFunctionsClientServer.SubstituteParametersInString(
							NStr("en = 'Cannot use field %1 as a natural key field
                                  |for object %2: object %3 can be used as field type, but this
                                  |object is not included in
                                  |the common data list through overridable procedure DataImportExportOverridable.OnFillCommonDataTypesSupportingRefMappingOnExport().'", Metadata.DefaultLanguage.LanguageCode),
							NaturalKeyField,
							CommonClassifierType.FullName(),
							Ref.Metadata().FullName()
						);
						
					EndIf;
					
					
				EndIf;
				
			EndDo;
			
		EndDo;
		
	EndDo;
	
	SetPrivilegedMode(True);
	Constants.ImportExportCommonClassifierCacheData.Set(New ValueStorage(Cache));
	
EndProcedure

// Fills the shared data reference control cache on export.
//
Procedure FillSharedDataReferenceControlCacheOnExport() Export
	
	Cache = New Map();
	
	SharedDataTypes = DataExportImportInternalEvents.GetCommonDataTypesThatSupportRefMappingOnImport();
	ObjectsToExcludeFromExportImport = DataExportImportInternalEvents.GetTypesToExcludeFromExportImport();
	ObjectsNotRequiringRefMapping = DataExportImportInternalEvents.GetCommonDataTypesNotRequiringRefMappingOnImport();
	
	SeparatorContentLocalCache = New Map();
	
	For Each MetadataObject In DataExportImportInternal.AllConstants() Do
		FillSharedDataReferenceControlCacheOnExportForConstants(
			Cache, MetadataObject, SharedDataTypes, ObjectsToExcludeFromExportImport, ObjectsNotRequiringRefMapping,
				SeparatorContentLocalCache
		);
	EndDo;
	
	For Each MetadataObject In DataExportImportInternal.AllRefData() Do
		FillSharedDataReferenceControlCacheOnExportForObjects(
			Cache, MetadataObject, SharedDataTypes, ObjectsToExcludeFromExportImport, ObjectsNotRequiringRefMapping,
				SeparatorContentLocalCache
		);
	EndDo;
	
	For Each MetadataObject In DataExportImportInternal.AllRecordsSets() Do
		FillSharedDataReferenceControlCacheOnExportForRecordSets(
			Cache, MetadataObject, SharedDataTypes, ObjectsToExcludeFromExportImport, ObjectsNotRequiringRefMapping,
				SeparatorContentLocalCache
		);
	EndDo;
	
	SetPrivilegedMode(True);
	Constants.ImportExportRefsToSharedDataCheckCacheOnExport.Set(New ValueStorage(Cache));
	
EndProcedure

// Adds update handler procedures
// required by the subsystem to the Handlers list.
//
// Parameters:
//   Handlers - ValueTable - see see the
//                                   description of NewUpdateHandlerTable function in the InfobaseUpdate common module.
// 
Procedure RegisterUpdateHandlers(Handlers) Export
	
	Handler                  = Handlers.Add();
	Handler.Version           = "*";
	Handler.ExclusiveMode = False;
	Handler.SharedData      = True;
	Handler.Procedure        = "ImportExportSharedData.FillCommonClassifierDependencyCache";
	
	Handler                  = Handlers.Add();
	Handler.Version           = "*";
	Handler.ExclusiveMode = False;
	Handler.SharedData      = True;
	Handler.Procedure        = "ImportExportSharedData.FillSharedDataReferenceControlCacheOnExport";
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Checks the objects for natural key duplicates.
//
// Parameters:
// MetadataObject - MetadataObject - metadata object to be exported.
// NaturalKeyFields - Array - array of strings with natural key names.
//
Procedure CheckNaturalKeyDuplicates(Val MetadataObject, Val NaturalKeyFields)
	
	TableName = MetadataObject.FullName();
	
	QueryText =
	"SELECT
	|	_Catalog_Table_First.Ref AS ItemReference
	|FROM
	|	" + TableName + " AS
	|	_Catalog_Table_First LEFT JOIN " + TableName + " AS _Catalog_Table_Second
	|	%1
	|
	|GROUP BY
	|	_Catalog_Table_First.Ref
	|HAVING
	|	COUNT(*) > 1";
	
	
	AdditionalQueryText = "";
	Iteration = 1;
	For Each NaturalKeyField In NaturalKeyFields Do 
		
		AdditionalQueryText = AdditionalQueryText + "%LogicalFunction (_Catalog_Table_First.%KeyName = _Catalog_Table_Second.%KeyName) ";
		LogicalFunction = ?(Iteration = 1, "ON", "And");
		
		AdditionalQueryText = StrReplace(AdditionalQueryText, "%KeyName",          NaturalKeyField);
		AdditionalQueryText = StrReplace(AdditionalQueryText, "%LogicalFunction", LogicalFunction);
		
		Iteration = Iteration + 1;
		
	EndDo;
	
	QueryText = StrReplace(QueryText, "%1", AdditionalQueryText);
	
	Query = New Query;
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	// Determining objects with duplicate natural keys
	DuplicatesTable = QueryResult.Unload();
	Iteration = 0;
	ItemList = "";
	For Each DuplicateItem In DuplicatesTable Do 
		
		PunctuationMark = ?(Iteration = 0, "", ", ");
		ItemList = ItemList + PunctuationMark + String(DuplicateItem.ItemReference);
		Iteration = Iteration + 1;
		If Iteration = 5 Then 
			Break;
		EndIf;
		
	EndDo;
	
	KeyNames = "";
	Iteration = 0;
	For Each NaturalKeyField In NaturalKeyFields Do 
		
		PunctuationMark = ?(Iteration = 0, "", ", ");
		KeyNames = KeyNames + PunctuationMark + NaturalKeyField;
		Iteration = Iteration + 1;
		
	EndDo;
	
	// Filling the warning text
	MessageText = CTLAndSLIntegration.SubstituteParametersInString(
		NStr("en = 'Objects: %1 have duplicate fields: %2.'"),
		ItemList, KeyNames);
	
	Raise MessageText;
	
EndProcedure

// Checks a metadata object for natural keys.
//
// Parameters:
// MetadataObject - MetadataObject - metadata object to be exported.
// NaturalKeyFields - Array - array of strings with natural key names.
//
Procedure CheckNaturalKeyFields(Val MetadataObject, Val NaturalKeyFields)
	
	If NaturalKeyFields = Undefined Or NaturalKeyFields.Count() = 0 Then
		
		Raise CTLAndSLIntegration.SubstituteParametersInString(
			NStr("en = 'Natural keys for reference replacement are not specified for data type %1.
                  |Check OnDetermineTypesRequiringImportToLocalVersion handler.'"),
			MetadataObject.FullName());
		
	EndIf;
	
EndProcedure

Function IsRefTypeSet(Val TypeToCheck)
	
	TypeDescriptionSerialization = XDTOSerializer.WriteXDTO(TypeToCheck);
	
	If TypeDescriptionSerialization.TypeSet.Count() > 0 Then
		
		ContainsRefSets = False;
		
		For Each TypeSet In TypeDescriptionSerialization.TypeSet Do
			
			If TypeSet.NamespaceURI = "http://v8.1c.ru/8.1/data/enterprise/current-config" Then
				
				If TypeSet.LocalName = "AnyRef" Or TypeSet.LocalName = "CatalogRef"
						Or TypeSet.LocalName = "DocumentRef" Or TypeSet.LocalName = "BusinessProcessRef"
						Or TypeSet.LocalName = "TaskRef" Or TypeSet.LocalName = "ChartOfAccountsRef"
						Or TypeSet.LocalName = "ExchangePlanRef" Or TypeSet.LocalName = "ChartOfCharacteristicTypesRef"
						Or TypeSet.LocalName = "ChartOfCalculationTypesRef" Then
					
					ContainsRefSets = True;
					Break;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
		Return ContainsRefSets;
		
	Else
		Return False;
	EndIf;
	
EndFunction

Function GetAllRefTypes()
	
	Result = New Array();
	
	Result.Add(Catalogs.AllRefsType());
	Result.Add(Documents.AllRefsType());
	Result.Add(ChartsOfCharacteristicTypes.AllRefsType());
	Result.Add(ChartsOfAccounts.AllRefsType());
	Result.Add(ChartsOfCalculationTypes.AllRefsType());
	Result.Add(ExchangePlans.AllRefsType());
	Result.Add(BusinessProcesses.AllRefsType());
	Result.Add(Tasks.AllRefsType());
	
	Return Result;
	
EndFunction

Function MetadataObjectHasAtLeastOneSeparator(Val MetadataObject, Cache)
	
	For Each CommonAttribute In Metadata.CommonAttributes Do
		
		If CommonAttribute.DataSeparation = Metadata.ObjectProperties.CommonAttributeDataSeparation.Separate Then
			
			AutoUse = (CommonAttribute.AutoUse = Metadata.ObjectProperties.CommonAttributeAutoUse.Use);
			
			Content = Cache.Get(CommonAttribute.FullName());
			If Content = Undefined Then
				Content = CommonAttribute.Content;
				Cache.Insert(CommonAttribute.FullName(), Content);
			EndIf;
			
			ContentItem = Content.Find(MetadataObject);
			If ContentItem <> Undefined Then
				
				If ContentItem.Use = Metadata.ObjectProperties.CommonAttributeUse.Use
						Or (AutoUse And ContentItem.Use = Metadata.ObjectProperties.CommonAttributeUse.Auto) Then
					
					Return True;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction

Procedure FillSharedDataReferenceControlCacheOnExportForConstants(Cache, Val MetadataObject, Val CommonDataTypes, Val ObjectsToExcludeFromExportImport, Val ObjectsNotRequiringRefMapping, SeparatorContentLocalCache)
	
	If ObjectsToExcludeFromExportImport.Find(MetadataObject) = Undefined And MetadataObjectHasAtLeastOneSeparator(MetadataObject, SeparatorContentLocalCache) Then
		
		FillSharedDataReferenceControlCacheOnExportBySeparatedObjectField(
			Cache, MetadataObject, MetadataObject, CommonDataTypes, ObjectsNotRequiringRefMapping, SeparatorContentLocalCache
		);
		
	EndIf;
	
EndProcedure

Procedure FillSharedDataReferenceControlCacheOnExportForObjects(Cache, Val MetadataObject, Val SharedDataTypes, Val ObjectsToExcludeFromExportImport, Val ObjectsNotRequiringRefMapping, SeparatorContentLocalCache)
	
	If ObjectsToExcludeFromExportImport.Find(MetadataObject) = Undefined And MetadataObjectHasAtLeastOneSeparator(MetadataObject, SeparatorContentLocalCache) Then
		
		For Each Attribute In MetadataObject.Attributes Do
			
			FillSharedDataReferenceControlCacheOnExportBySeparatedObjectField(
				Cache, MetadataObject, Attribute, SharedDataTypes, ObjectsNotRequiringRefMapping, SeparatorContentLocalCache
			);
			
		EndDo;
		
		For Each TabularSection In MetadataObject.TabularSections Do
			
			For Each Attribute In TabularSection.Attributes Do
				
				FillSharedDataReferenceControlCacheOnExportBySeparatedObjectField(
					Cache, MetadataObject, Attribute, SharedDataTypes, ObjectsNotRequiringRefMapping, SeparatorContentLocalCache
				);
				
			EndDo;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure FillSharedDataReferenceControlCacheOnExportForRecordSets(Cache, Val MetadataObject, Val SharedDataTypes, Val ObjectsToExcludeFromExportImport, Val ObjectsNotRequiringRefMapping, SeparatorContentLocalCache)
	
	If ObjectsToExcludeFromExportImport.Find(MetadataObject) = Undefined And MetadataObjectHasAtLeastOneSeparator(MetadataObject, SeparatorContentLocalCache) Then
		
		For Each Dimension In MetadataObject.Dimensions Do
			
			FillSharedDataReferenceControlCacheOnExportBySeparatedObjectField(
				Cache, MetadataObject, Dimension, SharedDataTypes, ObjectsNotRequiringRefMapping, SeparatorContentLocalCache
			);
			
		EndDo;
		
		For Each Resource In MetadataObject.Resources Do
			
			FillSharedDataReferenceControlCacheOnExportBySeparatedObjectField(
				Cache, MetadataObject, Resource, SharedDataTypes, ObjectsNotRequiringRefMapping, SeparatorContentLocalCache
			);
			
		EndDo;
		
		For Each Attribute In MetadataObject.Attributes Do
			
			FillSharedDataReferenceControlCacheOnExportBySeparatedObjectField(
				Cache, MetadataObject, Attribute, SharedDataTypes, ObjectsNotRequiringRefMapping, SeparatorContentLocalCache
			);
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure FillSharedDataReferenceControlCacheOnExportBySeparatedObjectField(Cache, Val MetadataObject, Val Field, Val SharedDataTypes, Val ObjectsNotRequiringRefMapping, SeparatorContentLocalCache)
	
	TypesOfFields = Field.Type;
	
	If IsRefTypeSet(TypesOfFields) Then
		
		// This attribute is assigned the AnyRef type or a
		// composite type (such as CatalogRef.*, DocumentRef.*). - no check is performed during this step, as developers
		// may assume any kind of refernce to a separated reference metadata object.
		//
		// Object and attribute information will
		// be saved to cache, to be further used for checks during data export.
		//
		
		If Cache.Get(MetadataObject.FullName()) = Undefined Then
			Cache.Insert(MetadataObject.FullName(), New Array());
		EndIf;
		
		Cache.Get(MetadataObject.FullName()).Add(Field.FullName());
		
	Else
		
		For Each FieldType In TypesOfFields.Types() Do
			
			If Not DataExportImportInternal.IsPrimitiveType(FieldType) And Not (FieldType = Type("ValueStorage")) Then
				
				RefMetadata = DataExportImportInternal.MetadataObjectByRefType(FieldType);
				
				If SharedDataTypes.Find(RefMetadata) = Undefined
						And Not DataExportImportInternal.IsEnum(RefMetadata)
						And Not MetadataObjectHasAtLeastOneSeparator(RefMetadata, SeparatorContentLocalCache)
						And Not ObjectsNotRequiringRefMapping.Find(RefMetadata) <> Undefined Then
					
					RaiseExceptionIfSeparatedDataHasRefsToSharedDataWithoutRefMappingSupport(
						MetadataObject,
						Field.FullName(),
						RefMetadata,
						False
					);
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure RaiseExceptionInvalidSharedDataReferenceControlCacheOnExport()
	
	Raise NStr("en = 'Invalid shared data control cache on export.'");
	
EndProcedure

Procedure SharedDataReferenceControlOnExport(Container, Object, SharedDataRefControlFields)
	
	MetadataObject = Object.Metadata();
	MetadataObjectFullName = MetadataObject.FullName();
	ObjectNameStructure = StringFunctionsClientServer.SplitStringIntoSubstringArray(MetadataObjectFullName, ".");
	
	For Each SharedDataRefControlField In SharedDataRefControlFields Do
		
		FieldNameStructure = StringFunctionsClientServer.SplitStringIntoSubstringArray(SharedDataRefControlField, ".");
		
		If ObjectNameStructure[0] <> FieldNameStructure[0] Or ObjectNameStructure[1] <> FieldNameStructure[1] Then
			
			RaiseExceptionInvalidSharedDataReferenceControlCacheOnExport();
			
		EndIf;
		
		If DataExportImportInternal.IsConstant(MetadataObject) Then
			
			SharedDataSingleReferenceControlOnExport(
				Container,
				Object.Value,
				MetadataObject,
				SharedDataRefControlField);
			
		ElsIf DataExportImportInternal.IsRefData(MetadataObject) Then
			
			If FieldNameStructure[2] = "Attribute" Or FieldNameStructure[2] = "Attribute" Then // Do not localize this parameter
				
				SharedDataSingleReferenceControlOnExport(
					Container,
					Object[FieldNameStructure[3]],
					MetadataObject,
					SharedDataRefControlField
				);
				
			ElsIf FieldNameStructure[2] = "TabularSection" Or FieldNameStructure[2] = "TabularSection" Then // Do not localize this parameter
				
				TabularSectionName = FieldNameStructure[3];
				
				If FieldNameStructure[4] = "Attribute" Or FieldNameStructure[4] = "Attribute" Then // Do not localize this parameter
					
					AttributeName = FieldNameStructure[5];
					
					For Each TabularSectionRow In Object[TabularSectionName] Do
						
						SharedDataSingleReferenceControlOnExport(
							Container,
							TabularSectionRow[AttributeName],
							MetadataObject,
							SharedDataRefControlField
						);
						
					EndDo;
					
				Else
					
					RaiseExceptionInvalidSharedDataReferenceControlCacheOnExport();
					
				EndIf;
				
			Else
				
				RaiseExceptionInvalidSharedDataReferenceControlCacheOnExport();
				
			EndIf;
			
		ElsIf DataExportImportInternal.IsRecordSet(MetadataObject) Then
			
			If FieldNameStructure[2] = "Dimension" Or FieldNameStructure[2] = "Dimension"
					Or FieldNameStructure[2] = "Resource" Or FieldNameStructure[2] = "Resource"
					Or FieldNameStructure[2] = "Attribute" Or FieldNameStructure[2] = "Attribute" Then // Do not localize this parameter
				
				For Each Write In Object Do
					
					SharedDataSingleReferenceControlOnExport(
						Container,
						Write[FieldNameStructure[3]],
						MetadataObject,
						SharedDataRefControlField
					);
					
				EndDo;
				
			Else
				
				RaiseExceptionInvalidSharedDataReferenceControlCacheOnExport();
				
			EndIf;
			
		Else
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Metadata object %1 is not supported.'", Metadata.DefaultLanguage.LanguageCode),
				MetadataObjectFullName
			);
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure SharedDataSingleReferenceControlOnExport(Container, Val RefToCheck, Val SourceMetadataObject, Val FieldName)
	
	ValueType = TypeOf(RefToCheck);
	If ValueIsFilled(RefToCheck) And CommonUse.IsReference(ValueType) And Not DataExportImportInternal.IsEnum(RefToCheck.Metadata()) And Not RefToCheck.IsEmpty() Then
		
		MetadataObject = DataExportImportInternal.MetadataObjectByRefType(ValueType);
		If Not MetadataObjectHasAtLeastOneSeparator(
					MetadataObject, Container.AdditionalProperties.SeparatorContentLocalCache) Then
			
			If Container.AdditionalProperties.CommonDataRequiringRefMapping.Find(MetadataObject) = Undefined Then
				
				RaiseExceptionIfSeparatedDataHasRefsToSharedDataWithoutRefMappingSupport(
					SourceMetadataObject,
					FieldName,
					MetadataObject,
					True
				);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure RaiseExceptionIfSeparatedDataHasRefsToSharedDataWithoutRefMappingSupport(Val MetadataObject, Val FieldName, Val RefMetadata, Val OnExport)
	
	If DataExportImportInternal.IsConstant(MetadataObject) Then
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'References to shared object %2 are used
                  |as value of separated constant %1'", Metadata.DefaultLanguage.LanguageCode),
			MetadataObject.FullName(),
			RefMetadata.FullName()
		);
		
	ElsIf DataExportImportInternal.IsRefData(MetadataObject) Then
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'References to shared object %3 are used as value
                  |of attribute %1 of separated object %2'", Metadata.DefaultLanguage.LanguageCode),
			FieldName,
			MetadataObject.FullName(),
			RefMetadata.FullName()
		);
		
	ElsIf DataExportImportInternal.IsRecordSet(MetadataObject) Then
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'References to shared object %3 are used as value of dimension, resource, or
                  |attribute %1 of separated record set %2'", Metadata.DefaultLanguage.LanguageCode),
			FieldName,
			MetadataObject.FullName(),
			RefMetadata.FullName()
		);
		
	Else
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Unexpected metadata object: %1.'", Metadata.DefaultLanguage.LanguageCode),
			MetadataObject.FullName()
		);
		
	EndIf;
	
	If OnExport Then
		
		ErrorText = ErrorText +
			NStr("en = ' (the object value type is set to a composite
                  |data type that may contain references both to separated and shared data,
                  |but an attempt to export a shared object reference was identified during export).'", Metadata.DefaultLanguage.LanguageCode);
		
	Else
		
		ErrorText = ErrorText + ".";
		
	EndIf;
	
	ErrorExplanation = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'The shared object %1 is not listed among the common
              |data types that support reference mapping during export or import.
              |This situation is abnormal, as the exported references to object %1
              |will be corrupted when imported to another infobase.
              |
              |To resolve the problem, you need to implement a
              |mechanism for determining fields that unambiguously specify the natural key for object
              |%1, and add the object %1 to the list of
              |common data types that support reference mapping during export
              |or import (by specifying the metadata object %1 in procedure DataImportExportOverridable.OnFillCommonDataTypesSupportingRefMappingOnExport().'", Metadata.DefaultLanguage.LanguageCode),
		RefMetadata.FullName()
	);
	
	If Not OnExport Then
		
		ErrorExplanation = ErrorExplanation +
			NStr("en = '
                  |If shared data reference mapping between the source infobase
                  |and target infobase is achieved through other mechanisms, you need
                  |to specify the metadata object %1
                  |in procedure DataImportExportOverridable.OnFillCommonDataTypesNotRequiringRefMappingOnExport().'", Metadata.DefaultLanguage.LanguageCode);
		
	EndIf;
	
	Raise ErrorText + Chars.LF + Chars.CR + ErrorExplanation;
	
EndProcedure

Function ReadCommonClassifierDependencyCache()
	
	SetPrivilegedMode(True);
	Return Constants.ImportExportCommonClassifierCacheData.Get().Get();
	
EndFunction

Function ReadSharedDataReferenceControlCacheOnExport() Export
	
	SetPrivilegedMode(True);
	Return Constants.ImportExportRefsToSharedDataCheckCacheOnExport.Get().Get();
	
EndFunction



