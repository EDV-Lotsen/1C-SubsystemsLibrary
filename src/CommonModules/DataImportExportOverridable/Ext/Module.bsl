///////////////////////////////////////////////////////////////////////////////////////////////////////////
// DataImportExportOverridable: management of events related to data import/export in data areas.
// 
///////////////////////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Fills array of types that require reference annotation in files during export.
//
// Parameters:
//  Types - Array of MetadataObject.
//
Procedure OnFillTypesThatRequireRefAnnotationOnImport(Types) Export
	
	
	
EndProcedure

// Fills an array of shared data types that describe
// data included in reference mapping when data is imported to another infobase.
//
// Parameters:
//  Types - Array of MetadataObject.
//
Procedure OnFillCommonDataTypesSupportingRefMappingOnExport(Types) Export
	
	
	
EndProcedure

// Fills the array of shared data types that do not
// require reference mapping during data import to another infobase, as the
// correct reference mapping is provided by other algorithms.
//
// Parameters:
//  Types - Array of MetadataObject.
//
Procedure OnFillCommonDataTypesDoNotRequireMappingRefsOnImport(Types) Export
	
	
	
EndProcedure

// Fills the array of types excluded from data import and export.
//
// Parameters:
//  Types - Array(Types).
//
Procedure OnFillExcludedFromImportExportTypes(Types) Export
	
	
	
EndProcedure

// Called before data export.
//
// Parameters:
//  Container - DataProcessorObject.ImportExportContainerManagerData - container 
//    manager used for data export. For more information, see the comment 
//    to ImportExportContainerManagerData interface.
//
Procedure BeforeDataExport(Container) Export
	
	
	
EndProcedure

// Called during registration of arbitrary data export handlers.
//
// Parameters: HandlerTable - ValueTable. This procedure requires that you add information on
//  the arbitrary data export handlers to the value table. Columns:
//    MetadataObject - MetadataObject. The handler to be registered
//      is called when the object data is exported. 
//    Handler - CommonModule. A common module implementing an arbitrary data export handler. 
//      The list of export procedures to be implemented in the handler depends on the values 
//      of the following value table columns. 
//    BeforeExportType - Boolean. Flag specifying whether the handler must be called before 
//      exporting all infobase objects associated with this metadata object. If set to True,
//      the common module of the handler must include the exportable procedure 
//      BeforeExportType() supporting the following parameters:
//        Container - DataProcessorObject.ImportExportContainerManagerData - container
//          manager used for data export. For more information, see the comment to
//          ImportExportContainerManagerData interface. 
//        Serializer - XDTOSerializer initializedwith reference annotation support. 
//          If an arbitrary export handler requires additional data export, it
//          is recommended that you use XDTOSerializer passed to BeforeExportType() 
//          as Serializer parameter, not obtained using XDTOSerializer global
//          context property.
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
//          If an arbitrary export handler requires additional data export, it is
//          recommended that you use XDTOSerializer passed to BeforeExportObject() 
//          as Serializer parameter, not obtained using XDTOSerializer global
//          context property.
//        Object - ConstantValueManager.*, CatalogObject.*, DocumentObject.*, 
//          BusinessProcessObject.*, TaskObject.*, ChartOfAccountsObject.*, 
//          ExchangePlanObject.*, ChartOfCharacteristicTypesObject.*,
//          ChartOfCalculationTypesObject.*, InformationRegisterRecordSet.*,
//          AccumulationRegisterRecordSet.*, AccountingRegisterRecordSet.*, 
//          CalculationRegisterRecordSet.*, SequenceRecordSet.*, RecalculationRecordSet.* -
//          infobase data object exported after calling the handler.
//          The value passed to BeforeExportObject() procedure as value of the Object parameter 
//          can be changed in the BeforeExportObject() handler. The changes will be reflected 
//          in the object serialization in export files, but not in the infobase. 
//        Artifacts - Array of XDTODataObject - set of additional information logically 
//          associated with the object but not contained in it (object artifacts). 
//          Artifacts must be created in the BeforeExportObject() handler and added
//          to the array that is passed as Artifacts parameter value. Each artifact is
//          a XDTO object with abstract XDTO type used as its
//          basic type {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. XDTO 
//          packages not included in the DataImportExport subsystem can be used too. 
//          The artifacts generated in the BeforeExportObject() procedure will be available
//          in the data import handler procedures (see the comment to 
//          OnRegisterDataImportHandlers() procedure).
//        Cancel - Boolean. If set to True in BeforeExportObject(), the corresponding object
//          is not exported.
//    AfterExportType() - Boolean. Flag specifying whether the handler is called after all 
//      infobase objects associated with this metadata object are exported. If set to True, 
//      the common module of the handler must include the exportable procedure AfterExportType() 
//      supporting the following parameters:
//        Container - DataProcessorObject.ImportExportContainerManagerData - container
//          manager used for data export. For more information, see the comment to
//          ImportExportContainerManagerData interface. 
//        Serializer - XDTOSerializer initialized with reference annotation support. 
//          If an arbitrary export handler requires additional data export, it is
//          recommended that you use XDTOSerializer passed to AfterExportType() as Serializer 
//          parameter, not obtained using XDTOSerializer global context property.
//        MetadataObject - MetadataObject. The handler is called after the object data is exported.
//
Procedure OnRegisterDataExportHandlers(HandlerTable) Export
	
	
	
EndProcedure

// Called after data export.
//
// Parameters:
//  Container - DataProcessorObject.ImportExportContainerManagerData - container
//    manager used for data export. For more information, see the comment to 
//    ImportExportContainerManagerData interface.
//
Procedure AfterDataExport(Container) Export
	
	
	
EndProcedure

// Called before data import.
//
// Parameters:
//  Container - DataProcessorObject.ImportExportContainerManagerData - container
//    manager used for data import. For more information, see the comment to 
//    ImportExportContainerManagerData interface.
//
Procedure BeforeDataImport(Container) Export
	
	
	
EndProcedure

// Called during registration of arbitrary data import handlers.
//
// Parameters: HandlerTable - ValueTable. The procedure presumes that information 
//  on registered arbitrary data import handlers must be added to this table. 
//  Columns:
//    MetadataObject - MetadataObject. When importing its data, the handler 
//      to be registered is called. 
//    Handler - CommonModule. A common module implementing an arbitrary data import handler. 
//      Set of export procedures to be implemented in the handler depends on the values of the
//      following value table columns. 
//    BeforeRefMapping - Boolean. Flag specifying whether the handler must be called before 
//      mapping the source infobase references and the current infobase references associated 
//      with this metadata object. If set to True, the common module of the handler must 
//      include the exportable procedure BeforeRefMapping() supporting the following parameters:
//        Container - DataProcessorObject.ImportExportContainerManagerData - container
//          manager used for data import. For more information, see the comment to 
//          ImportExportContainerManagerData interface.
//        MetadataObject - MetadataObject. The handler is called before
//          the object references are mapped. 
//        StandardProcessing - Boolean. If set to False in BeforeRefMapping(), the MapRefs() 
//          function of the corresponding common module will be called instead of the standard
//          reference mapping (searching the current infobase for objects with the natural key 
//          values identical to the values exported from the source infobase).
//          MapRefs() function parameters:
//            Container - DataProcessorObject.ImportExportContainerManagerData - container
//              manager used for data import. For more information, see the comment to
//              ImportExportContainerManagerData interface. 
//            SourceRefTable - ValueTable, contains details on references exported 
//              from the original infobase. Columns:
//                SourceRef - AnyRef, a source infobase object reference to be mapped to a
//                current infobase reference. The other columns are identical to
//                the object's natural key fields that were passed
//                to ImportExportInfobaseData.RefMappingRequiredOnImport() during data export. 
//          MapRefs() returns: - ValueTable with the following columns:
//            SourceRef - AnyRef, object reference exported from the original infobase. 
//            Ref - AnyRef mapped the original reference in the current infobase.
//        Cancel - Boolean. If set to True in BeforeRefMapping(), references corresponding 
//          to the current metadata object are not mapped.
//    BeforeImportType - Boolean. Flag specifying whether the handler must be called before 
//      importing all infobase objects associated with this metadata object. If set to True,
//      the common module of the handler must include the exportable procedure 
//      BeforeImportType() supporting the following parameters:
//        Container - DataProcessorObject.ImportExportContainerManagerData - container
//          manager used for data import. For more information, see the comment to 
//          ImportExportContainerManagerData interface.
//        MetadataObject - MetadataObject. The handler is called before
//          the object data is imported. 
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
//          BusinessProcessObject.*, TaskObject.*, ChartOfAccountsObject.*, 
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
//        Cancel - Boolean. If set to True in BeforeImportObject(), 
//          the data object is not imported.
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
//          XDTO packagesnot included in the DataImportExport subsystem can be used too.
//    AfterImportType - Boolean. Flag specifying whether the handler must be called 
//      after importing all infobase objects associated with this metadata object. 
//      If set to True, the common module of the handler must include the exportable 
//      procedure AfterImportType() supporting the following parameters:
//        Container - DataProcessorObject.ImportExportContainerManagerData - container
//          manager used for data import. For more information, see the comment to 
//          ImportExportContainerManagerData interface.
//        MetadataObject - MetadataObject. The handler is called after the object data is imported.
//
Procedure OnRegisterDataImportHandlers(HandlerTable) Export
	
	
	
EndProcedure

// Called after data import.
//
// Parameters:
//  Container - DataProcessorObject.ImportExportContainerManagerData - container
//    manager used for data import. For more information, see the comment to 
//    ImportExportContainerManagerData interface.
//
Procedure AfterDataImport(Container) Export
	
	
	
EndProcedure

// Obsolete. Use AfterDataImport instead.
//
Procedure AfterDataImportFromOtherMode() Export
	
	
	
EndProcedure

// Called before importing an infobase user.
//
// Parameters:
//  Container - DataProcessorObject.ImportExportContainerManagerData - container
//    manager used for data import. For more information, see the comment
//    to ImportExportContainerManagerData interface. 
//  Serialization - XDTOObject {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}InfoBaseUser, 
//    infobase user serialization.
//  InfobaseUser - InfoBaseUser deserialized from the export data. 
//  Cancel - Boolean - when set to False, infobase user import is skipped.
//
Procedure OnImportInfobaseUser(Container, Serialization, IBUser, Cancel) Export
	
	
	
EndProcedure

// Called after infobase user import.
//
// Parameters:
//  Container - DataProcessorObject.ImportExportContainerManagerData - container
//    manager used for data import. For more information, see the comment
//    to ImportExportContainerManagerData interface. 
//  Serialization - XDTOObject {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}InfoBaseUser.
//    infobase user serialization.
//  InfobaseUser - InfobaseUser deserialized from the export data.
//
Procedure AfterImportInfobaseUser(Container, Serialization, IBUser) Export
	
	
	
EndProcedure

// Called after all infobase users are imported.
//
// Parameters:
//  Container - DataProcessorObject.ImportExportContainerManagerData - container
//    manager used for data import. For more information, see the comment to 
//    ImportExportContainerManagerData interface.
//
Procedure AfterImportInfobaseUsers(Container) Export
	
	
	
EndProcedure

//
//
