// Fills array of types that require reference annotation in files during export.
//
// Parameters:
//  Types - Array of MetadataObject.
//
Procedure OnFillTypesThatRequireRefAnnotationOnImport(Types) Export
	
	ListOfCommonSeparatedMetadataObjects = ReadCommonSeparatedObjectCache();
	
	For Each KeyAndValue In ListOfCommonSeparatedMetadataObjects Do
		
		For Each TypeName In KeyAndValue.Value.Objects Do
			
			Types.Add(Metadata.FindByFullName(TypeName));
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Called during registration of arbitrary data export handlers.
//
// Parameters: HandlerTable - ValueTable. This procedure requires that you add information on
//  the arbitrary data export handlers to the value table. Columns:
//    MetadataObject - MetadataObject. The handler to be registered
//      is called when the object data is exported. 
//    Handler - CommonModule. A common module implementing an arbitrary data export handler. 
//      The list of export procedures to be implemented in the handler depends on
//      the values of the following value table columns. 
//    BeforeExportType - Boolean. Flag specifying whether the handler must be called 
//      before exporting all infobase objects associated with this metadata object. 
//      If set to True, the common module of the handler must include the
//      exportable procedure BeforeExportType() supporting the following parameters:
//        Container - DataProcessorObject.ImportExportContainerManagerData - container
//          manager used for data export. For more information, see the comment to
//          ImportExportContainerManagerData interface. 
//        Serializer - XDTOSerializer initialized with reference annotation support. 
//          If an arbitrary export handler requires additional data export, it
//          is recommended that you use XDTOSerializer passed to BeforeExportType() 
//          as Serializer parameter, not obtained using XDTOSerializer global context property.
//        MetadataObject - MetadataObject. The handler is called before
//          the object data is exported. 
//        Cancel - Boolean. If set to True in BeforeExportType(), objects associated
//          with the current metadata objects are not exported.
//    BeforeExportObject - Boolean. Flag specifying whether the handler must be called 
//      before exporting a specific infobase object. If set to True, the common module 
//      of the handler must include the exportable procedure BeforeExportObject() 
//      supporting the following parameters:
//        Container - DataProcessorObject.ImportExportContainerManagerData - container
//          manager used for data export. For more information, see the comment to
//          ImportExportContainerManagerData interface. 
//        Serializer - XDTOSerializer initialized with reference annotation support. 
//          If an arbitrary export handler requires additional data export, it
//          is recommended that you use XDTOSerializer passed to BeforeExportObject() 
//          as Serializer parameter, not obtained using XDTOSerializer global context property.
//        Object - ConstantValueManager.*, CatalogObject.*, DocumentObject.*, 
//          BusinessProcessObject.*, TaskObject.*, ChartOfAccountsObject.*, 
//          ExchangePlanObject.*, ChartOfCharacteristicTypesObject.*,
//          ChartOfCalculationTypesObject.*, InformationRegisterRecordSet.*,
//          AccumulationRegisterRecordSet.*, AccountingRegisterRecordSet.*, 
//          CalculationRegisterRecordSet.*, SequenceRecordSet.*, RecalculationRecordSet.* -
//          infobase data object exported after calling the handler.
//          The value passed to BeforeExportObject() procedure as
//          value of the Object parameter can be changed
//          in the BeforeExportObject() handler. The changes will be reflected in the object
//          serialization in export files, but not in the infobase. 
//        Artifacts - Array of XDTODataObject - set of additional information
//          logically associated with the object but not contained in it (object artifacts). 
//          Artifacts must be created in the BeforeExportObject() handler and added
//          to the array that is passed as Artifacts parameter value. 
//          Each artifact is a XDTO object with abstract XDTO type used as its
//          basic type {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. 
//          XDTO packages not included in the DataImportExport subsystem can be used too. The
//          artifacts generated in the BeforeExportObject() procedure will be available
//          in the data import handler procedures 
//          (see the comment to OnRegisterDataImportHandlers() procedure).
//        Cancel - Boolean. If set to True in BeforeExportObject(), the corresponding object
//           is not exported.
//    AfterExportType() - Boolean. Flag specifying whether the handler is called 
//      after all infobase objects associated with this metadata object are exported. 
//      If set to True, the common module of the handler must include the exportable 
//      procedure AfterExportType() supporting the following parameters:
//        Container - DataProcessorObject.ImportExportContainerManagerData - container
//          manager used for data export. For more information, see the comment to
//          ImportExportContainerManagerData interface. 
//        Serializer - XDTOSerializer initialized with reference annotation support. 
//          If an arbitrary export handler requires additional data export, it
//          is recommended that you use XDTOSerializer passed
//          to AfterExportType() as Serializer parameter, not obtained 
//          using XDTOSerializer global context property.
//        MetadataObject - MetadataObject. The handler is called after the object data is exported.
//
Procedure OnRegisterDataExportHandlers(HandlerTable) Export
	
	ListOfCommonSeparatedMetadataObjects = ReadCommonSeparatedObjectCache();
	
	For Each KeyAndValue In ListOfCommonSeparatedMetadataObjects Do
		
		For Each MetadataObjectName In KeyAndValue.Value.Objects Do
			
			NewHandler = HandlerTable.Add();
			NewHandler.MetadataObject = Metadata.FindByFullName(MetadataObjectName);
			NewHandler.Handler = ImportExportCommonSeparatedData;
			NewHandler.BeforeExportObject = True;
			
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure BeforeExportObject(Container, Serializer, Object, Artifacts, Cancel) Export
	
	ListOfCommonSeparatedMetadataObjects = ReadCommonSeparatedObjectCache();
	
	ObjectFoundInCache = False;
	
	For Each KeyAndValue In ListOfCommonSeparatedMetadataObjects Do
		For Each MetadataObjectName In KeyAndValue.Value.Objects Do
			If MetadataObjectName = Object.Metadata().FullName() Then
				ObjectFoundInCache = True;
			EndIf;
		EndDo;
	EndDo;
	
	If Not ObjectFoundInCache Then
		
		Raise CTLAndSLIntegration.SubstituteParametersInString(
			NStr("en = 'ImportExportCommonSeparatedData.BeforeExportObject() handler 
                  |cannot process metadata object %1.
                  |The object is not found in the common separated object cache.
                  |If the cache is not updated after the configuration metadata structure
                  |was modified, you need to update the common separated object cache 
                  |by calling the ImportExportCommonSeparatedData.FillCommonSeparatedObjectCache() method'", Metadata.DefaultLanguage.LanguageCode),
			Object.Metadata().FullName()
		);
		
	EndIf;
	
	ImportExportInfobaseData.RecreateRefOnImportRequired(Container, Object.Ref);
	
EndProcedure

// Called during registration of arbitrary data import handlers.
//
// Parameters: HandlerTable - ValueTable. The procedure presumes that information 
//  on registered arbitrary data import handlers must be added to this table. Columns:
//    MetadataObject - MetadataObject. When importing its data, the
//      handler to be registered is called. 
//    Handler - CommonModule. A common module implementing an arbitrary data import handler. 
//      Set of export procedures to be implemented in the handler depends on the
//      values of the following value table columns. 
//    BeforeRefMapping - Boolean. Flag specifying whether the handler must be called 
//      before mapping the source infobase references and the current infobase references 
//      associated with this metadata object. If set to True, the common module of
//      the handler must include the exportable procedure BeforeRefMapping() 
//      supporting the following parameters:
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
//            SourceRefTable - ValueTable, contains details on references 
//              exported from the source infobase. Columns:
//                SourceRef - AnyRef, a source infobase object reference to be mapped to a
//                  current infobase reference. 
//                The other columns are identical to the object's natural key fields 
//                  that were passed to ImportExportInfobaseData.RefMappingRequiredOnImport() 
//                  during data export. 
//          MapRefs() returns: ValueTable with the following columns:
//            SourceRef - AnyRef, object reference exported from the original infobase.
//            Ref - AnyRef mapped the original reference in the current infobase.
//        Cancel - Boolean. If set to True in BeforeRefMapping(), references corresponding 
//          to the current metadata object are not mapped.
//    BeforeImportType - Boolean. Flag specifying whether the handler must be called 
//      before importing all infobase objects associated with this metadata object. 
//      If set to True, the common module of the handler must include the exportable procedure 
//      BeforeImportType() supporting the following parameters:
//        Container - DataProcessorObject.ImportExportContainerManagerData - container
//          manager used for data import. For more information, see the comment to 
//          ImportExportContainerManagerData interface.
//        MetadataObject - MetadataObject. The handler is called before the object data is imported. 
//        Cancel - Boolean. If set to True in AfterImportType(), the data objects 
//          corresponding to the current metadata object are not imported.
//    BeforeImportObject - Boolean. Flag specifying whether the handler must be called 
//      before importing the infobase object associated with this metadata object. 
//      If set to True, the common module of the handler must include the exportable 
//      procedure BeforeImportObject() supporting the following parameters:
//        Container - DataProcessorObject.ImportExportContainerManagerData - container
//          manager used for data import. For more information, see the comment to 
//          ImportExportContainerManagerData interface.
//        Object - ConstantValueManager.*, CatalogObject.*, DocumentObject.*, 
//          BusinessProcessObject.*, TaskObject.*,
//          ExchangePlanObject.*, ChartOfCharacteristicTypesObject.*,
//          ChartOfCalculationTypesObject.*, InformationRegisterRecordSet.*,
//          AccumulationRegisterRecordSet.*, AccountingRegisterRecordSet.*, 
//          CalculationRegisterRecordSet.*, SequenceRecordSet.*, RecalculationRecordSet.* -
//          infobase data object imported after the handler is called.
//          Value passed to the BeforeImportObject() procedure as Object parameter value 
//          can be modified in the BeforeImportObject() handler procedure.
//        Artifacts - Array of XDTODataObject - additional data logically
//          associated with the data object but not contained in it. Generated in
//          BeforeExportObject() exportable procedures of data export handlers (see
//          the comment to the OnRegisterDataExportHandlers() procedure). 
//          Each artifact is a XDTO object with abstract XDTO type used as its
//          basic type {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. 
//          XDTO packages not included in the DataImportExport subsystem can be used too.
//        Cancel - Boolean. If set to True in BeforeImportObject(), the data object is not imported.
//    AfterImportObject - Boolean. Flag specifying whether the handler must be called 
//      after importing the infobase object associated with this metadata object. 
//      If set to True, the common module of the handler must include the exportable 
//      procedure AfterImportObject() supporting the following parameters:
//        Container - DataProcessorObject.ImportExportContainerManagerData - container
//          manager used for data import. For more information, see the comment to 
//          ImportExportContainerManagerData interface.
//        Object - ConstantValueManager.*, CatalogObject.*, DocumentObject.*, 
//          BusinessProcessObject.*, TaskObject.*, ChartOfAccountsObject.*, 
//          ExchangePlanObject.*, ChartOfCharacteristicTypesObject.*,
//          ChartOfCalculationTypesObject.*, InformationRegisterRecordSet.*,
//          AccumulationRegisterRecordSet.*, AccountingRegisterRecordSet.*, 
//          CalculationRegisterRecordSet.*, SequenceRecordSet.*, RecalculationRecordSet.* -
//          infobase data object imported before the handler is called.
//        Artifacts - Array of XDTODataObject - additional data logically
//          associated with the data object but not contained in it. Generated in
//          BeforeExportObject() exportable procedures of data export handlers (see
//          the comment to the OnRegisterDataExportHandlers() procedure). 
//          Each artifact is a XDTO object with abstract XDTO type used as its
//          basic type {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. 
//          XDTO packages not included in the DataImportExport subsystem can be used too.
//    AfterImportType - Boolean. Flag specifying whether the handler must be called 
//      after importing all infobase objects associated with this metadata object. 
//      If set to True, the common module of the handler must include the
//      exportable procedure AfterImportType() supporting the following parameters:
//        Container - DataProcessorObject.ImportExportContainerManagerData - container
//          manager used for data import. For more information, see the comment to 
//          ImportExportContainerManagerData interface.
//        MetadataObject - MetadataObject. The handler is called after the object data is imported.
//
Procedure OnRegisterDataImportHandlers(HandlerTable) Export
	
	ListOfCommonSeparatedMetadataObjects = ReadCommonSeparatedObjectCache();
	
	For Each KeyAndValue In ListOfCommonSeparatedMetadataObjects Do
		
		For Each MetadataObjectName In KeyAndValue.Value.Constants Do
			
			NewHandler = HandlerTable.Add();
			NewHandler.MetadataObject = Metadata.FindByFullName(MetadataObjectName);
			NewHandler.Handler = ImportExportCommonSeparatedData;
			NewHandler.BeforeImportObject = True;
			
		EndDo;
		
		For Each MetadataObjectName In KeyAndValue.Value.Objects Do
			
			NewHandler = HandlerTable.Add();
			NewHandler.MetadataObject = Metadata.FindByFullName(MetadataObjectName);
			NewHandler.Handler = ImportExportCommonSeparatedData;
			NewHandler.BeforeImportObject = True;
			
		EndDo;
		
		For Each MetadataObjectName In KeyAndValue.Value.RecordSets Do
			
			NewHandler = HandlerTable.Add();
			NewHandler.MetadataObject = Metadata.FindByFullName(MetadataObjectName);
			NewHandler.Handler = ImportExportCommonSeparatedData;
			NewHandler.BeforeImportObject = True;
			
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure BeforeImportObject(Container, Object, Artifacts, Cancel) Export
	
	ListOfCommonSeparatedMetadataObjects = ReadCommonSeparatedObjectCache();
	
	ObjectFoundInCache = False;
	Separator = "";
	
	For Each KeyAndValue In ListOfCommonSeparatedMetadataObjects Do
		
		For Each MetadataObjectName In KeyAndValue.Value.Constants Do
			If MetadataObjectName = Object.Metadata().FullName() Then
				ObjectFoundInCache = True;
				Separator = KeyAndValue.Key;
			EndIf;
		EndDo;
		
		For Each MetadataObjectName In KeyAndValue.Value.Objects Do
			If MetadataObjectName = Object.Metadata().FullName() Then
				ObjectFoundInCache = True;
				Separator = KeyAndValue.Key;
			EndIf;
		EndDo;
		
		For Each MetadataObjectName In KeyAndValue.Value.RecordSets Do
			If MetadataObjectName = Object.Metadata().FullName() Then
				ObjectFoundInCache = True;
				Separator = KeyAndValue.Key;
			EndIf;
		EndDo;
		
	EndDo;
	
	If Not ObjectFoundInCache Then
		
		Raise CTLAndSLIntegration.SubstituteParametersInString(
			NStr("en = 'ImportExportCommonSeparatedData.BeforeImportObject() handler 
                  |cannot process metadata object %1.
                  |The object is not found in the common separated object cache.
                  |If the cache is not updated after the configuration metadata structure
                  |was modified, you need to update the common separated object cache 
                  |by calling the ImportExportCommonSeparatedData.FillCommonSeparatedObjectCache() method'", Metadata.DefaultLanguage.LanguageCode),
			Object.Metadata().FullName()
		);
		
	EndIf;
	
	SessionParameter = Metadata.CommonAttributes[Separator].DataSeparationValue.Name;
	SessionParameterValue = SessionParameters[SessionParameter];
	
	If DataExportImportInternal.IsRecordSet(Object.Metadata()) Then
		
		For Each Write In Object Do
			Write[Separator] = SessionParameterValue;
		EndDo;
		
	Else
		
		Object[Separator] = SessionParameterValue;
		
	EndIf;
	
EndProcedure

Function ReadCommonSeparatedObjectCache()
	
	SetPrivilegedMode(True);
	Return Constants.ListOfCommonSeparatedMetadataObjects.Get().Get();
	
EndFunction

// Adds update handler procedures required by the subsystem to the Handlers list.
//
// Parameters:
//   Handlers - ValueTable - see the description of NewUpdateHandlerTable function 
//     in the InfobaseUpdate common module.
// 
Procedure RegisterUpdateHandlers(Handlers) Export
	
	Handler               = Handlers.Add();
	Handler.Version       = "*";
	Handler.ExclusiveMode = False;
	Handler.SharedData    = True;
	Handler.Procedure     = "ImportExportCommonSeparatedData.FillCommonSeparatedObjectCache";
	
EndProcedure

// Fills the ListOfCommonSeparatedRefObjects constant.
//
Procedure FillCommonSeparatedObjectCache() Export
	
	Cache = New Structure();
	
	Separators = IndependentAndCommonTypeSeparators();
	
	For Each Separator In Separators Do
		
		SeparatedObjectStructure = New Structure("Constants,Objects,RecordSets", New Array(), New Array(), New Array());
		
		AutoUse = (Separator.AutoUse = Metadata.ObjectProperties.CommonAttributeAutoUse.Use);
		
		For Each ContentItem In Separator.Content Do
			
			If ContentItem.Use = Metadata.ObjectProperties.CommonAttributeUse.Use
					Or (AutoUse And ContentItem.Use = Metadata.ObjectProperties.CommonAttributeUse.Auto) Then
				
				If DataExportImportInternal.IsConstant(ContentItem.Metadata) Then
					SeparatedObjectStructure.Constants.Add(ContentItem.Metadata.FullName());
				ElsIf DataExportImportInternal.IsRefData(ContentItem.Metadata) Then
					SeparatedObjectStructure.Objects.Add(ContentItem.Metadata.FullName());
				ElsIf DataExportImportInternal.IsRecordSet(ContentItem.Metadata) Then
					SeparatedObjectStructure.RecordSets.Add(ContentItem.Metadata.FullName());
				EndIf;
				
			EndIf;
			
			Cache.Insert(Separator.Name, SeparatedObjectStructure);
			
		EndDo;
		
	EndDo;
	
	SetPrivilegedMode(True);
	Constants.ListOfCommonSeparatedMetadataObjects.Set(New ValueStorage(Cache));
	
EndProcedure

Function IndependentAndCommonTypeSeparators()
	
	Result = New Array();
	
	For Each CommonAttribute In Metadata.CommonAttributes Do
		
		If CommonAttribute.DataSeparation = Metadata.ObjectProperties.CommonAttributeDataSeparation.Separate
				And CommonAttribute.SeparatedDataUse = Metadata.ObjectProperties.CommonAttributeSeparatedDataUse.IndependentlyAndSimultaneously Then
			
			Result.Add(CommonAttribute);
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction