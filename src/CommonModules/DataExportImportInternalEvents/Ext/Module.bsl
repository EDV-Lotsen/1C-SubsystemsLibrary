// Declares internal events of the DataImportExport subsystem:
//
// See the description of this procedure in the StandardSubsystemsServer module.
//
Procedure OnAddInternalEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS
	
	// Fills array of types for which the reference annotation
	// in files must be used when exporting.
	//
	// Parameters:
	//  Types - Array of MetadataObject
	//
	// Syntax:
	// Procedure OnFillTypesThatRequireRefAnnotationOnImport(Types) Export
	//
	// (identical to DataImportExportOverridable.OnFillTypesThatRequireRefAnnotationOnImport).
	ServerEvents.Add("CloudTechnology.DataImportExport\OnFillTypesThatRequireRefAnnotationOnImport");
	
	// Fills an array of shared data types that describe
	// data included in reference mapping when data is imported to another infobase.
	//
	// Parameters:
	//  Types - Array of MetadataObject
	//
	// Syntax:
	// Procedure OnFillCommonDataTypesSupportingRefMappingOnExport(Types)
	// Export (identical to DataImportExportOverridable.OnFillCommonDataTypesSupportingRefMappingOnExport).
	ServerEvents.Add("CloudTechnology.DataImportExport\OnFillCommonDataTypesSupportingRefMappingOnExport");
	
	// Fills the array of shared data types that do not
	// require reference mapping during data import to another infobase, as the
	// correct reference mapping is provided by other algorithms.
	//
	// Parameters:
	//  Types - Array of MetadataObject
	//
	// Syntax:
	// Procedure OnFillCommonDataTypesDoNotRequireMappingRefsOnImport(Types)
	// Export (identical to DataImportExportOverridable.OnFillCommonDataTypesDoNotRequireMappingRefsOnImport).
	ServerEvents.Add("CloudTechnology.DataImportExport\OnFillCommonDataTypesDoNotRequireMappingRefsOnImport");
	
	// Fills the array of types excluded from data import and export.
	//
	// Parameters:
	//  Types - Array(Types).
	//
	// Syntax:
	// Procedure OnFillExcludedFromImportExportTypes(Types)
	// Export (identical to DataImportExportOverridable.OnFillExcludedFromImportExportTypes).
	ServerEvents.Add("CloudTechnology.DataImportExport\OnFillExcludedFromImportExportTypes");
	
	// Called before data export.
	//
	// Parameters:
	//  Container - DataProcessorObject.ImportExportContainerManagerData - container
	//    manager used for data export. For more
	//    information, see the comment to ImportExportContainerManagerData interface.
	//
	// Syntax:
	// Procedure BeforeDataExport(Container)
	// Export (identical to DataImportExportOverridable.BeforeDataExport).
	ServerEvents.Add("CloudTechnology.DataImportExport\BeforeDataExport");
	
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
	// Syntax:
	// Procedure OnRegisterDataExportHandlers(HandlerTable)
	// Export (identical to DataImportExportOverridable.OnRegisterDataExportHandlers).
	ServerEvents.Add("CloudTechnology.DataImportExport\OnRegisterDataExportHandlers");
	
	// Called after data export.
	//
	// Parameters:
	//  Container - DataProcessorObject.ImportExportContainerManagerData - container
	//    manager used for data export. For more
	//    information, see the comment to ImportExportContainerManagerData interface.
	//
	// Syntax:
	// Procedure AfterDataExport(Container)
	// Export (identical to DataImportExportOverridable.AfterDataExport).
	ServerEvents.Add("CloudTechnology.DataImportExport\AfterDataExport");
	
	// Called before data import.
	//
	// Parameters:
	//  Container - DataProcessorObject.ImportExportContainerManagerData - container
	//    manager used for data import. For more
	//    information, see the comment to ImportExportContainerManagerData interface.
	//
	// Syntax:
	// Procedure BeforeDataImport(Container)
	// Export (identical to DataImportExportOverridable.BeforeDataImport).
	ServerEvents.Add("CloudTechnology.DataImportExport\BeforeDataImport");
	
	// Called during registration of arbitrary data import handlers.
	//
	// Parameters: HandlerTable - ValueTable. The
	//  procedure presumes that information on registered arbitrary
	//  data import handlers must be added to this table. Columns:
	//    MetadataObject - MetadataObject. When importing
	//      its data, the
	//    handler to be registered is called. Handler - CommonModule. A common module
	//      implementing an arbitrary data import handler. Set of export procedures
	//      to be implemented in the handler depends on the
	//      values of the
	//    following value table columns. BeforeRefMapping - Boolean. Flag specifying whether
	//      the handler must be called before mapping the source infobase references and
	//      the current infobase references associated with this metadata object. If set to True - the common module of
	//      the handler must include the
	//      exportable procedure BeforeRefMapping() supporting the following parameters:
	//        Container - DataProcessorObject.ImportExportContainerManagerData - container
	//          manager used for data import. For more
	//          information, see the comment to ImportExportContainerManagerData interface.
	//        MetadataObject - MetadataObject. The handler
	//          is called before
	//        the object references are mapped. StandardProcessing - Boolean. If set
	//          to False in BeforeRefMapping(), the MapRefs() function of
	//          the corresponding common module will be called instead of the standard
	//          reference mapping (searching the current infobase
	//          for objects with the natural key values
	//          identical to the values exported
	//          fromt he source infobase).
	//          MapRefs() function parameters:
	//            Container - DataProcessorObject.ImportExportContainerManagerData - container
	//              manager used for data import. For more
	//              information, see the comment to
	//            ImportExportContainerManagerData interface. SourceRefTable - ValueTable, contains details
	//              on references exported from original infobase. Columns:
	//                SourceRef - AnyRef, a source infobase object
	//                  reference to be mapped to a
	//                current infobase reference. The other columns are identical to
	//                  the object's natural key fields that were
	//                  passed
	//          to ImportExportInfobaseData.RefMappingRequiredOnImport() during data export. MapRefs() returns: - ValueTable with the following columns:
	//            SourceRef - AnyRef, object reference exported from
	//            the original infobase, Ref - AnyRef mapped the original reference in the current infobase.
	//        Cancel - Boolean. If set to True
	//          in BeforeRefMapping() - references
	//          corresponding to the current metadata object are not mapped.
	//    BeforeImportType - Boolean. Flag specifying whether
	//      the handler must be called before importing all
	//      infobase objects associated with this metadata object. If set to True - the common module of
	//      the handler must include the
	//      exportable procedure BeforeImportType() supporting the following parameters:
	//        Container - DataProcessorObject.ImportExportContainerManagerData - container
	//          manager used for data import. For more
	//          information, see the comment to ImportExportContainerManagerData interface.
	//        MetadataObject - MetadataObject. The handler
	//          is called before
	//        the object data is imported. Cancel - Boolean. If set to True in
	//          AfterImportType() - the data objects corresponding to
	//          the current metadata object are not imported.
	//    BeforeImportObject - Boolean. Flag specifying whether
	//      the handler must be called before importing
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
	//        Cancel - Boolean. If set to True in
	//          BeforeImportObject() - the data object is not imported.
	//    AfterImportObject - Boolean. Flag specifying whether
	//      the handler must be called after importing
	//      the infobase object associated with this metadata object. If set to True - the common module of
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
	//      infobase objects associated with this metadata object. If set to True - the common module of
	//      the handler must include the
	//      exportable procedure AfterImportType() supporting the following parameters:
	//        Container - DataProcessorObject.ImportExportContainerManagerData - container
	//          manager used for data import. For more
	//          information, see the comment to ImportExportContainerManagerData interface.
	//        MetadataObject - MetadataObject. The handler
	//          is called after the object data is imported.
	//
	// Syntax:
	// Procedure OnRegisterDataImportHandlers(HandlerTable)
	// Export (identical to DataImportExportOverridable.OnRegisterDataImportHandlers).
	ServerEvents.Add("CloudTechnology.DataImportExport\OnRegisterDataImportHandlers");
	
	// Called after data import.
	//
	// Parameters:
	//  Container - DataProcessorObject.ImportExportContainerManagerData - container
	//    manager used for data import. For more
	//    information, see the comment to ImportExportContainerManagerData interface.
	//
	// Syntax:
	// Procedure AfterDataImport(Container)
	// Export (identical to DataImportExportOverridable.AfterDataImport).
	ServerEvents.Add("CloudTechnology.DataImportExport\AfterDataImport");
	
	// Called after data import from another mode.
	//
	// Syntax:
	// Procedure AfterDataImportFromOtherMode()
	// Export (identical to DataImportExportOverridable.AfterDataImportFromOtherMode).
	ServerEvents.Add("CloudTechnology.DataImportExport\AfterDataImportFromOtherMode");
	
	// Called before importing an infobase user.
	//
	// Parameters:
	//  Container - DataProcessorObject.ImportExportContainerManagerData - container
	//    manager used for data import. For more
	//    information, see the comment
	//  to ImportExportContainerManagerData interface. Serialization - XDTOObject
	//    {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}InfoBaseUser, infobase user
	//  serialization, InfobaseUser - InfoBaseUser deserialized
	//  from the export data. Cancel - Boolean - when set to False,
	//    infobase user import is skipped.
	//
	// Syntax:
	// Procedure OnImportInfobaseUser(Container, Serialization, InfobaseUser, Cancel)
	// Export (identical to DataImportExportOverridable.OnImportInfobaseUser).
	ServerEvents.Add("CloudTechnology.DataImportExport\OnImportInfobaseUser");
	
	// Called after infobase user import.
	//
	// Parameters:
	//  Container - DataProcessorObject.ImportExportContainerManagerData - container
	//    manager used for data import. For more
	//    information, see the comment
	//  to ImportExportContainerManagerData interface. Serialization - XDTOObject
	//    {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}InfoBaseUser, infobase user
	//  serialization, InfobaseUser - InfobaseUser deserialized from the export data.
	//
	// Syntax:
	// Procedure AfterImportInfobaseUser(Container, Serialization, InfobaseUser, Cancel)
	// Export (identical to DataImportExportOverridable.AfterImportInfobaseUser).
	ServerEvents.Add("CloudTechnology.DataImportExport\AfterImportInfobaseUser");
	
	// Called after all infobase users are imported.
	//
	// Parameters:
	//  Container - DataProcessorObject.ImportExportContainerManagerData - container
	//    manager used for data import. For more
	//    information, see the comment to ImportExportContainerManagerData interface.
	//
	// Syntax:
	// Procedure AfterImportInfobaseUsers(Container)
	// Export (identical to DataImportExportOverridable.AfterImportInfobaseUsers).
	ServerEvents.Add("CloudTechnology.DataImportExport\AfterImportInfobaseUsers");
	
	
	//ServerEvents.Add("CloudTechnology.DataImportExport\BeforeExportObject");
	//ServerEvents.Add("CloudTechnology.DataImportExport\AfterImportObject");
	
	ServerEvents.Add("CloudTechnology.DataImportExport\OnDetermineTypesRequiringImportToLocalVersion");
	
	ServerEvents.Add("CloudTechnology.DataImportExport\OnDetermineMetadataObjectsToExcludeFromExportImport");
	
EndProcedure

// Initializes events during data export

Function GetTypesRequiringRefAnnotationOnExport() Export
	
	Types = New Array();
	
	// Integrated handlers
	ImportExportSharedData.OnFillTypesThatRequireRefAnnotationOnImport(Types);
	DataImportExportOverridable.OnFillTypesThatRequireRefAnnotationOnImport(Types);
	ImportExportCommonSeparatedData.OnFillTypesThatRequireRefAnnotationOnImport(Types);
	ImportExportPredefinedData.OnFillTypesThatRequireRefAnnotationOnImport(Types);
	
	// SL event handlers
	SLProgramEventHandlers = CommonUseCTL.GetSLProgramEventHandlers(
		"CloudTechnology.DataImportExport\OnFillTypesThatRequireRefAnnotationOnImport");
	For Each SLProgramEventHandler In SLProgramEventHandlers Do
		SLProgramEventHandler.Module.OnFillTypesThatRequireRefAnnotationOnImport(Types);
	EndDo;
	
	// Overridable procedure
	DataImportExportOverridable.OnFillTypesThatRequireRefAnnotationOnImport(Types);
	
	Return New FixedArray(Types);
	
EndFunction

Function GetCommonDataTypesThatSupportRefMappingOnImport() Export
	
	Types = New Array();
	
	// SL event handlers
	SLProgramEventHandlers = CommonUseCTL.GetSLProgramEventHandlers(
		"CloudTechnology.DataImportExport\OnFillCommonDataTypesSupportingRefMappingOnExport");
	For Each SLProgramEventHandler In SLProgramEventHandlers Do
		SLProgramEventHandler.Module.OnFillCommonDataTypesSupportingRefMappingOnExport(Types);
	EndDo;
	
	// Overridable procedure
	DataImportExportOverridable.OnFillCommonDataTypesSupportingRefMappingOnExport(Types);
	
	Return New FixedArray(Types);
	
EndFunction

Function GetCommonDataTypesNotRequiringRefMappingOnImport() Export
	
	Types = New Array();
	
	// SL event handlers
	SLProgramEventHandlers = CommonUseCTL.GetSLProgramEventHandlers(
		"CloudTechnology.DataImportExport\OnFillCommonDataTypesDoNotRequireMappingRefsOnImport");
	For Each SLProgramEventHandler In SLProgramEventHandlers Do
		SLProgramEventHandler.Module.OnFillCommonDataTypesDoNotRequireMappingRefsOnImport(Types);
	EndDo;
	
	// Overridable procedure
	DataImportExportOverridable.OnFillCommonDataTypesDoNotRequireMappingRefsOnImport(Types);
	
	Return New FixedArray(Types);
	
EndFunction

Function GetTypesToExcludeFromExportImport() Export
	
	Types = New Array();
	
	// SL event handlers
	SLProgramEventHandlers = CommonUseCTL.GetSLProgramEventHandlers(
		"CloudTechnology.DataImportExport\OnFillExcludedFromImportExportTypes");
	For Each SLProgramEventHandler In SLProgramEventHandlers Do
		SLProgramEventHandler.Module.OnFillExcludedFromImportExportTypes(Types);
	EndDo;
	
	// Overridable procedure
	DataImportExportOverridable.OnFillExcludedFromImportExportTypes(Types);
	
	Return New FixedArray(Types);
	
EndFunction

Procedure ExecuteActionsBeforeDataExport(Container) Export
	
	// Integrated handlers
	ImportExportDataStorageData.BeforeDataExport(Container);
	ImportExportSharedData.BeforeDataExport(Container);
	DataExportImportInternal.BeforeDataExport(Container);
	
	// SL event handlers
	SLProgramEventHandlers = CommonUseCTL.GetSLProgramEventHandlers(
		"CloudTechnology.DataImportExport\BeforeDataExport");
	For Each SLProgramEventHandler In SLProgramEventHandlers Do
		SLProgramEventHandler.Module.BeforeDataExport(Container);
	EndDo;
	
	// Overridable procedure
	DataImportExportOverridable.BeforeDataExport(Container);
	
EndProcedure

Function GetDataExportHandlers() Export
	
	Result = New ValueTable();
	
	Result.Columns.Add("MetadataObject", New TypeDescription("MetadataObject"));
	Result.Columns.Add("Handler", New TypeDescription("CommonModule"));
	
	Result.Columns.Add("BeforeExportType", New TypeDescription("Boolean"));
	Result.Columns.Add("BeforeExportObject", New TypeDescription("Boolean"));
	Result.Columns.Add("AfterExportType", New TypeDescription("Boolean"));
	
	// Integrated handlers
	ImportExportSequenceBoundaryData.OnRegisterDataExportHandlers(Result);
	ImportExportDataStorageData.OnRegisterDataExportHandlers(Result);
	ImportExportSharedData.OnRegisterDataExportHandlers(Result);
	ImportExportPredefinedData.OnRegisterDataExportHandlers(Result);
	ImportExportCommonSeparatedData.OnRegisterDataExportHandlers(Result);
	
	// SL event handlers
	SLProgramEventHandlers = CommonUseCTL.GetSLProgramEventHandlers(
		"CloudTechnology.DataImportExport\OnRegisterDataExportHandlers");
	For Each SLProgramEventHandler In SLProgramEventHandlers Do
		SLProgramEventHandler.Module.OnRegisterDataExportHandlers(Result);
	EndDo;
	
	// Overridable procedure
	DataImportExportOverridable.OnRegisterDataExportHandlers(Result);
	
	Return Result;
	
EndFunction

Procedure ExecuteHandlersBeforeExportType(HandlerTable, Container, Serializer, MetadataObject, Cancel) Export
	
	HandlerDescriptions = HandlerTable.Copy(New Structure("BeforeExportType", True));
	
	For Each HandlerDetails In HandlerDescriptions Do
		HandlerDetails.Handler.BeforeExportType(Container, Serializer, MetadataObject, Cancel);
	EndDo;
	
EndProcedure

Procedure ExecuteHandlersBeforeExportObject(HandlerTable, Container, Serializer, Object, Artifacts, Cancel) Export
	
	HandlerDescriptions = HandlerTable.Copy(New Structure("BeforeExportObject", True));
	
	For Each HandlerDetails In HandlerDescriptions Do
		HandlerDetails.Handler.BeforeExportObject(Container, Serializer, Object, Artifacts, Cancel);
	EndDo;
	
EndProcedure

Procedure ExecuteHandlersAfterExportType(HandlerTable, Container, Serializer, MetadataObject) Export
	
	HandlerDescriptions = HandlerTable.Copy(New Structure("AfterExportType", True));
	
	For Each HandlerDetails In HandlerDescriptions Do
		HandlerDetails.Handler.AfterExportType(Container, Serializer, MetadataObject);
	EndDo;
	
EndProcedure

Procedure ExecuteActionsAfterDataExport(Container) Export
	
	// SL event handlers
	SLProgramEventHandlers = CommonUseCTL.GetSLProgramEventHandlers(
		"CloudTechnology.DataImportExport\AfterDataExport");
	For Each SLProgramEventHandler In SLProgramEventHandlers Do
		SLProgramEventHandler.Module.AfterDataExport(Container);
	EndDo;
	
	// Overridable procedure
	DataImportExportOverridable.AfterDataExport(Container);
	
EndProcedure

// Initializes events during data import

Procedure ExecuteActionsBeforeDataImport(Container) Export
	
	// Integrated handlers
	DataExportImportInternal.BeforeDataImport(Container);
	
	// SL event handlers
	SLProgramEventHandlers = CommonUseCTL.GetSLProgramEventHandlers(
		"CloudTechnology.DataImportExport\BeforeDataImport");
	For Each SLProgramEventHandler In SLProgramEventHandlers Do
		SLProgramEventHandler.Module.BeforeDataImport(Container);
	EndDo;
	
	// Overridable procedure
	DataImportExportOverridable.BeforeDataImport(Container);
	
EndProcedure

Function GetTypeDependenciesOnRefReplacement() Export
	
	// Integrated handlers
	Return ImportExportSharedData.TypeDependenciesOnRefReplacement();
	
EndFunction

Function GetDataImportHandlers() Export
	
	Result = New ValueTable();
	
	Result.Columns.Add("MetadataObject", New TypeDescription("MetadataObject"));
	Result.Columns.Add("Handler", New TypeDescription("CommonModule"));
	
	Result.Columns.Add("BeforeMapRefs", New TypeDescription("Boolean"));
	Result.Columns.Add("BeforeImportType", New TypeDescription("Boolean"));
	Result.Columns.Add("BeforeImportObject", New TypeDescription("Boolean"));
	Result.Columns.Add("AfterImportObject", New TypeDescription("Boolean"));
	Result.Columns.Add("AfterImportType", New TypeDescription("Boolean"));
	
	// Integrated handlers
	ImportExportSequenceBoundaryData.OnRegisterDataImportHandlers(Result);
	ImportExportDataStorageData.OnRegisterDataImportHandlers(Result);
	ImportExportPredefinedData.OnRegisterDataImportHandlers(Result);
	ImportExportCommonSeparatedData.OnRegisterDataImportHandlers(Result);
	
	// SL event handlers
	SLProgramEventHandlers = CommonUseCTL.GetSLProgramEventHandlers(
		"CloudTechnology.DataImportExport\OnRegisterDataImportHandlers");
	For Each SLProgramEventHandler In SLProgramEventHandlers Do
		SLProgramEventHandler.Module.OnRegisterDataImportHandlers(Result);
	EndDo;
	
	// Overridable procedure
	DataImportExportOverridable.OnRegisterDataImportHandlers(Result);
	
	Return Result;
	
EndFunction

Procedure ExecuteHandlersBeforeRefMapping(HandlerTable, Container, MetadataObject, SourceRefTable, StandardProcessing, CustomHandler, Cancel) Export
	
	HandlerDescriptions = HandlerTable.Copy(New Structure("BeforeMapRefs", True));
	
	For Each HandlerDetails In HandlerDescriptions Do
		
		HandlerDetails.Handler.BeforeMapRefs(Container, MetadataObject, SourceRefTable, StandardProcessing, Cancel);
		
		If Not StandardProcessing Then
			CustomHandler = HandlerDetails.Handler;
			Return;
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure ExecuteActionsOnRefReplacement(Container, ReferenceMap) Export
	
	// Integrated handlers
	ImportExportUserSettings.OnSubstituteURL(Container, ReferenceMap);
	
EndProcedure

Procedure ExecuteHandlersBeforeImportType(HandlerTable, Container, MetadataObject, Cancel) Export
	
	HandlerDescriptions = HandlerTable.Copy(New Structure("BeforeImportType", True));
	
	For Each HandlerDetails In HandlerDescriptions Do
		HandlerDetails.Handler.BeforeImportType(Container, MetadataObject, Cancel);
	EndDo;
	
EndProcedure

Procedure ExecuteHandlersBeforeImportObject(HandlerTable, Container, Object, Artifacts, Cancel) Export
	
	HandlerDescriptions = HandlerTable.Copy(New Structure("BeforeImportObject", True));
	
	For Each HandlerDetails In HandlerDescriptions Do
		HandlerDetails.Handler.BeforeImportObject(Container, Object, Artifacts, Cancel);
	EndDo;
	
EndProcedure

Procedure ExecuteHandlersAfterImportObject(HandlerTable, Container, Object, Artifacts) Export
	
	HandlerDescriptions = HandlerTable.Copy(New Structure("AfterImportObject", True));
	
	For Each HandlerDetails In HandlerDescriptions Do
		HandlerDetails.Handler.AfterImportObject(Container, Object, Artifacts);
	EndDo;
	
EndProcedure

Procedure ExecuteHandlersAfterImportType(HandlerTable, Container, MetadataObject) Export
	
	HandlerDescriptions = HandlerTable.Copy(New Structure("AfterImportType", True));
	
	For Each HandlerDetails In HandlerDescriptions Do
		HandlerDetails.Handler.AfterImportType(Container, MetadataObject);
	EndDo;
	
EndProcedure

Procedure ExecuteActionsAfterDataImport(Container) Export
	
	// SL event handlers
	SLProgramEventHandlers = CommonUseCTL.GetSLProgramEventHandlers(
		"CloudTechnology.DataImportExport\AfterDataImport");
	For Each SLProgramEventHandler In SLProgramEventHandlers Do
		SLProgramEventHandler.Module.AfterDataImport(Container);
	EndDo;
	
	// Overridable procedure
	DataImportExportOverridable.AfterDataImport(Container);
	
	// For backwards compatibility, let us call AfterDataImportFromOtherMode()
	
	// SL event handlers
	SLProgramEventHandlers = CommonUseCTL.GetSLProgramEventHandlers(
		"CloudTechnology.DataImportExport\AfterDataImportFromOtherMode");
	For Each SLProgramEventHandler In SLProgramEventHandlers Do
		SLProgramEventHandler.Module.AfterDataImportFromOtherMode();
	EndDo;
	
	// Overridable procedure
	DataImportExportOverridable.AfterDataImportFromOtherMode();
	
EndProcedure

Procedure ExecuteActionsOnImportInfobaseUser(Container, Serialization, IBUser, Cancel) Export
	
	// SL event handlers
	SLProgramEventHandlers = CommonUseCTL.GetSLProgramEventHandlers(
		"CloudTechnology.DataImportExport\OnImportInfobaseUser");
	For Each SLProgramEventHandler In SLProgramEventHandlers Do
		SLProgramEventHandler.Module.OnImportInfobaseUser(Container, Serialization, IBUser, Cancel);
	EndDo;
	
	// Overridable procedure
	DataImportExportOverridable.OnImportInfobaseUser(Container, Serialization, IBUser, Cancel);
	
EndProcedure

Procedure ExecuteActionsAfterImportInfobaseUser(Container, Serialization, IBUser) Export
	
	// SL event handlers
	SLProgramEventHandlers = CommonUseCTL.GetSLProgramEventHandlers(
		"CloudTechnology.DataImportExport\AfterImportInfobaseUser");
	For Each SLProgramEventHandler In SLProgramEventHandlers Do
		SLProgramEventHandler.Module.AfterImportInfobaseUser(Container, Serialization, IBUser);
	EndDo;
	
	// Overridable procedure
	DataImportExportOverridable.AfterImportInfobaseUser(Container, Serialization, IBUser);
	
EndProcedure

Procedure ExecuteActionsOnImportInfobaseUsers(Container) Export
	
	// SL event handlers
	SLProgramEventHandlers = CommonUseCTL.GetSLProgramEventHandlers(
		"CloudTechnology.DataImportExport\AfterImportInfobaseUsers");
	For Each SLProgramEventHandler In SLProgramEventHandlers Do
		SLProgramEventHandler.Module.AfterImportInfobaseUsers(Container);
	EndDo;
	
	// Overridable procedure
	DataImportExportOverridable.AfterImportInfobaseUsers(Container);
	
EndProcedure


