// Fills array of types for which the reference annotation
// in files must be used when exporting.
//
// Parameters:
//  Types - Array of MetadataObject
//
Procedure OnFillTypesThatRequireRefAnnotationOnImport(Types) Export
	
	ObjectsWithPredefinedItems = ReadCacheOfObjectsWithPredefinedItems();
	For Each TypeName In ObjectsWithPredefinedItems Do
		If HasPredefinedItemsInCurrentArea(TypeName) Then
			Types.Add(Metadata.FindByFullName(TypeName));
		EndIf;
	EndDo;
	
EndProcedure

// Called during registration of arbitrary data export handlers.
//
// Parameters: HandlerTable - ValueTable. This procedure requires that you add information on
//  the arbitrary data export handlers to the value table. Columns:
//    MetadataObject - MetadataObject. The handler to be registered
//      is called when the object data is exported. 
//    Handler - CommonModule. A common module
//      implementing an arbitrary data export handler. The list of export
//      procedures to be implemented in the handler depends on
//      the values of the following value table columns.
//     BeforeExportType - Boolean. Flag specifying whether
//      the handler must be called before exporting all infobase
//      objects associated with this metadata object. If set to True, the common module of
//      the handler must include the exportable procedure BeforeExportType() supporting 
//      the following parameters:
//        Container - DataProcessorObject.ImportExportContainerManagerData - container
//          manager used for data export. For more information, see the comment to
//          ImportExportContainerManagerData interface. 
//        Serializer - XDTOSerializer initialized with reference annotation support. 
//          If an arbitrary export handler requires additional data export, it
//          is recommended that you use XDTOSerializer passed
//          to BeforeExportType() as Serializer parameter, not obtained using 
//          XDTOSerializer global
//          context property.
//        MetadataObject - MetadataObject. The handler is called before
//          the object data is exported. 
//        Cancel - Boolean. If set to True in BeforeExportType(), objects associated
//          to the current metadata objects are not exported.
//    BeforeExportObject - Boolean. Flag specifying whether the handler must be called 
//      before exporting a specific infobase object. If set to True, the common module 
//      of the handler must include
//      the exportable procedure BeforeExportObject() supporting the following parameters:
//        Container - DataProcessorObject.ImportExportContainerManagerData - container
//          manager used for data export. For more information, see the comment to
//          ImportExportContainerManagerData interface. 
//        Serializer - XDTOSerializer initialized with reference annotation support. 
//          If an arbitrary export handler requires additional data export, it
//          is recommended that you use XDTOSerializer passed to BeforeExportObject() 
//          as Serializer parameter, not obtained using XDTOSerializer global
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
//          in the infobase. 
//        Artifacts - Array of XDTODataObject - set of additional information
//          logically associated with the object but not contained in it (object artifacts). Artifacts
//          must be created in the BeforeExportObject() handler and added
//          to the array that is passed as Artifacts parameter value. Each artifact is
//          a XDTO object with abstract XDTO type used as its
//          basic type {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. XDTO packages
//          not included in the DataImportExport subsystem can be used too. The
//          artifacts generated in the BeforeExportObject() procedure will be available
//          in the data import handler procedures 
//          (see the comment to OnRegisterDataImportHandlers() procedure).
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
	
	SharedDataTypes = DataExportImportInternalEvents.GetCommonDataTypesThatSupportRefMappingOnImport();
	
	ObjectsWithPredefinedItems = ReadCacheOfObjectsWithPredefinedItems();
	For Each MetadataObjectName In ObjectsWithPredefinedItems Do
		
		MetadataObject = Metadata.FindByFullName(MetadataObjectName);
		
		If SharedDataTypes.Find(MetadataObject) = Undefined And HasPredefinedItemsInCurrentArea(MetadataObjectName) Then
			
			NewHandler = HandlerTable.Add();
			NewHandler.MetadataObject = Metadata.FindByFullName(MetadataObjectName);
			NewHandler.Handler = ImportExportPredefinedData;
			NewHandler.BeforeExportObject = True;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure BeforeExportObject(Container, Serializer, Object, Artifacts, Cancel) Export
	
	If DataExportImportInternal.IsRefDataSupportingPredefinedItems(Object.Metadata()) Then
		
		If Object.Predefined Then
			
			If CommonUseClientServer.IsPlatform83WithoutCompatibilityMode() Then
				NaturalKey = New Structure("PredefinedDataName", Object.PredefinedDataName);
			Else
				ObjectManager = CommonUse.ObjectManagerByFullName(Object.Metadata().FullName());
				NaturalKey = New Structure("PredefinedDataName", ObjectManager.GetPredefinedItemName(Object.Ref));
			EndIf;
			
			ImportExportInfobaseData.MustMapRefOnImport(Container, Object.Ref, NaturalKey);
			
		EndIf;
		
	Else
		
		Raise CTLAndSLIntegration.SubstituteParametersInString(
			NStr("en = 'ImportExportPredefinedData.BeforeExportObject() handler
                  |cannot process metadata object %1.
                  |The object must not contain any predefined items.'", Metadata.DefaultLanguage.LanguageCode),
			Object.Metadata().FullName()
		);
		
	EndIf;
	
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
//        StandardProcessing - Boolean. If set to False in BeforeRefMapping(), 
//          the MapRefs() function of the corresponding common module will be called 
//          instead of the standard reference mapping (searching the current infobase
//          for objects with the natural key values identical to the values exported
//          fromt he source infobase).
//          MapRefs() function parameters:
//            Container - DataProcessorObject.ImportExportContainerManagerData - container
//              manager used for data import. For more information, see the comment to
//              ImportExportContainerManagerData interface. 
//            SourceRefTable - ValueTable, contains details on references exported from 
//              original infobase. Columns:
//                SourceRef - AnyRef, a source infobase object reference to be mapped to a
//                current infobase reference. The other columns are identical to
//                the object's natural key fields that were passed
//                to ImportExportInfobaseData.RefMappingRequiredOnImport() during data export. 
//          MapRefs() returns: - ValueTable with the following columns:
//            SourceRef - AnyRef, object reference exported from the original infobase.
//            Ref - AnyRef mapped the original reference in the current infobase.
//        Cancel - Boolean. If set to True in BeforeRefMapping(), references
//          corresponding to the current metadata object are not mapped.
//    BeforeImportType - Boolean. Flag specifying whether the handler must be called before importing all
//      infobase objects associated with this metadata object. If set to True - the common module of
//      the handler must include the
//      exportable procedure BeforeImportType() supporting the following parameters:
//        Container - DataProcessorObject.ImportExportContainerManagerData - container
//          manager used for data import. For more
//          information, see the comment to ImportExportContainerManagerData interface.
//        MetadataObject - MetadataObject. The handler is called before
//        the object data is imported. Cancel - Boolean. If set to True in
//          AfterImportType(), the data objects corresponding to
//          the current metadata object are not imported.
//    BeforeImportObject - Boolean. Flag specifying whether the handler must be called before importing
//      the infobase object associated with this metadata object. If set to True - the common module of
//      the handler must include the
//      exportable procedure BeforeImportObject() supporting the following parameters:
//        Container - DataProcessorObject.ImportExportContainerManagerData - container
//          manager used for data import. For more
//          information, see the comment to ImportExportContainerManagerData interface.
//        Object - ConstantValueManager.*,
//          CatalogObject.*, DocumentObject.*, BusinessProcessObject.*, TaskObject.*,
//          ChartOfAccountsObject.*, ExchangePlanObject.*, ChartOfCharacteristicTypesObject.*,
//          ChartOfCalculationTypesObject.*, InformationRegisterRecordSet.*,
//          AccumulationRegisterRecordSet.*, AccountingRegisterRecordSet.*, CalculationRegisterRecordSet.*, 
//          SequenceRecordSet.*, RecalculationRecordSet.* -
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
//    AfterImportObject - Boolean. Flag specifying whether the handler must be called after importing
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
//          AccumulationRegisterRecordSet.*, AccountingRegisterRecordSet.*, CalculationRegisterRecordSet.*, 
//          SequenceRecordSet.*, RecalculationRecordSet.* -
//          infobase data object imported before the handler is called.
//        Artifacts - Array of XDTODataObject - additional data logically
//          associated with the data object but not contained in it. Generated in
//          BeforeExportObject() exportable procedures of data export handlers (see
//          the comment to the OnRegisterDataExportHandlers() procedure). Each artifact is
//          a XDTO object with abstract XDTO type used as its
//          basic type {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. XDTO packages
//          not included in the DataImportExport subsystem can be used too.
//    AfterImportType - Boolean. Flag specifying whether the handler must be called after importing all
//      infobase objects associated with this metadata object. If set to True - the common module of
//      the handler must include the
//      exportable procedure AfterImportType() supporting the following parameters:
//        Container - DataProcessorObject.ImportExportContainerManagerData - container
//          manager used for data import. For more
//          information, see the comment to ImportExportContainerManagerData interface.
//        MetadataObject - MetadataObject. The handler is called after the object data is imported.
//
Procedure OnRegisterDataImportHandlers(HandlerTable) Export
	
	SharedDataTypes = DataExportImportInternalEvents.GetCommonDataTypesThatSupportRefMappingOnImport();
	
	ObjectsWithPredefinedItems = ReadCacheOfObjectsWithPredefinedItems();
	For Each MetadataObjectName In ObjectsWithPredefinedItems Do
		
		MetadataObject = Metadata.FindByFullName(MetadataObjectName);
		If SharedDataTypes.Find(MetadataObject) = Undefined Then
			
			NewHandler = HandlerTable.Add();
			NewHandler.MetadataObject = Metadata.FindByFullName(MetadataObjectName);
			NewHandler.Handler = ImportExportPredefinedData;
			NewHandler.BeforeMapRefs = True;
			NewHandler.BeforeImportObject = True;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure BeforeMapRefs(Container, MetadataObject, SourceRefTable, StandardProcessing, Cancel) Export
	
	If SourceRefTable.Columns.Find("PredefinedDataName") <> Undefined Then
		
		If Not CommonUseClientServer.IsPlatform83WithoutCompatibilityMode() Then
			// For platforms versions earlier than 8.3.3, predefined items
			// always use identical references. No mapping is necessary.
			Cancel = True;
		Else
			StandardProcessing = False;
		EndIf;
		
	EndIf;
	
EndProcedure

Function MapRefs(Container, SourceRefTable) Export
	
	ColumnName = DataExportImportInternal.SourceURLColumnName(Container);
	
	Result = New ValueTable();
	Result.Columns.Add(ColumnName, SourceRefTable.Columns.Find(ColumnName).ValueType);
	Result.Columns.Add("Ref", SourceRefTable.Columns.Find(ColumnName).ValueType);
	
	For Each SourceRefTablesRow In SourceRefTable Do
		
		QueryText = 
			"SELECT
			|	Table.Ref AS Ref
			|FROM
			|	" + SourceRefTablesRow[ColumnName].Metadata().FullName() + " AS
			|Table
			|	WHERE Table.PredefinedDataName = &PredefinedDataName";
		Query = New Query(QueryText);
		Query.SetParameter("PredefinedDataName", SourceRefTablesRow.PredefinedDataName);
		
		QueryResult = Query.Execute();
		If Not QueryResult.IsEmpty() Then
			
			Selection = QueryResult.Select();
			
			If Selection.Count() = 1 Then
				
				Selection.Next();
				
				ResultRow = Result.Add();
				ResultRow.Ref = Selection.Ref;
				ResultRow[ColumnName] = SourceRefTablesRow[ColumnName];
				
			Else
				
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Duplicate predefined items %1 are found in table %2.'", Metadata.DefaultLanguage.LanguageCode),
					SourceRefTablesRow.PredefinedDataName,
					SourceRefTablesRow[ColumnName].Metadata().FullName()
				);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

Procedure BeforeImportObject(Container, Object, Artifacts, Cancel) Export
	
	MetadataObject = Object.Metadata();
	
	If DataExportImportInternal.IsRefDataSupportingPredefinedItems(MetadataObject) Then
		
		If Not CommonUseClientServer.IsPlatform83WithoutCompatibilityMode() And
				Object.Predefined And Object.DeletionMark Then
			
			// For platforms versions earlier than 8.3.3, predefined items marked for deletion are not allowed.
			Object.DeletionMark = False;
			
		EndIf;
		
	Else
		
		Raise CTLAndSLIntegration.SubstituteParametersInString(
			NStr("en = 'ImportExportPredefinedData.BeforeImportObject()
                  |handler
                  |cannot process metadata object %1.
                  |The object must not contain any predefined items.'", Metadata.DefaultLanguage.LanguageCode),
			Object.Metadata().FullName()
		);
		
	EndIf;
	
EndProcedure

Function ReadCacheOfObjectsWithPredefinedItems()
	
	SetPrivilegedMode(True);
	Return Constants.ListOfMetadataObjectsWithPredefinedItems.Get().Get();
	
EndFunction

Function HasPredefinedItemsInCurrentArea(Val MetadataObjectName)
	
	QueryText = "SELECT TOP 1 Ref FROM " + MetadataObjectName + " WHERE Predefined = TRUE";
	Query = New Query(QueryText);
	Return Not Query.Execute().IsEmpty();
	
EndFunction

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
	Handler.Procedure     = "ImportExportPredefinedData.FillCacheOfObjectsWithPredefinedItems";
	
EndProcedure

// Fills the ListOfMetadataObjectsWithPredefinedItems constant.
//
Procedure FillCacheOfObjectsWithPredefinedItems() Export
	
	// If natural key content is set for a shared catalog containing predefined data, 
	// it is not necessary to add PredefinedItemName to the natural key content of the catalog.
	SharedDataTypes = DataExportImportInternalEvents.GetCommonDataTypesThatSupportRefMappingOnImport();
	
	Cache = New Array();
	
	For Each MetadataObject In Metadata.Catalogs Do
		If SharedDataTypes.Find(MetadataObject) = Undefined Then
			Cache.Add(MetadataObject.FullName());
		EndIf;
	EndDo;
	
	For Each MetadataObject In Metadata.ChartsOfAccounts Do
		If SharedDataTypes.Find(MetadataObject) = Undefined Then
			Cache.Add(MetadataObject.FullName());
		EndIf;
	EndDo;
	
	For Each MetadataObject In Metadata.ChartsOfCharacteristicTypes Do
		If SharedDataTypes.Find(MetadataObject) = Undefined Then
			Cache.Add(MetadataObject.FullName());
		EndIf;
	EndDo;
	
	For Each MetadataObject In Metadata.ChartsOfCalculationTypes Do
		If SharedDataTypes.Find(MetadataObject) = Undefined Then
			Cache.Add(MetadataObject.FullName());
		EndIf;
	EndDo;
	
	SetPrivilegedMode(True);
	Constants.ListOfMetadataObjectsWithPredefinedItems.Set(New ValueStorage(Cache));
	
EndProcedure
