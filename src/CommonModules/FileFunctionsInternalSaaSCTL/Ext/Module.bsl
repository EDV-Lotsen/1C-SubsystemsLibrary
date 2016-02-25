////////////////////////////////////////////////////////////////////////////////
// INTERNAL INTERFACE

// Declares internal events of the DataImportExport subsystem.
//
// See the description of this procedure in the StandardSubsystemsServer module.
//
Procedure OnAddInternalEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS
	
	// Fills a list of CloudTechnology.SaaSOperations.FileFunctionsSaaS subsystem integration handlers.
	//
	// Parameters:
	//  Handlers - Array (String) - name of the common module of the handler.
	//
	// Syntax:
	// Procedure OnFillFileFunctionIntegrationHandlersInSaaS(Handlers) Export
	ServerEvents.Add(
		"CloudTechnology.SaaSOperations.FileFunctionsSaaS\OnFillFileFunctionIntegrationHandlersInSaaS");
	
	// 
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Adds handlers of internal events (subscriptions).

// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS
	
	ServerHandlers["CloudTechnology.DataImportExport\OnRegisterDataExportHandlers"].Add(
		"FileFunctionsInternalSaaSCTL");
	
	ServerHandlers["CloudTechnology.DataImportExport\OnRegisterDataImportHandlers"].Add(
		"FileFunctionsInternalSaaSCTL");
	
	ServerHandlers["CloudTechnology.DataImportExport\OnFillExcludedFromImportExportTypes"].Add(
		"FileFunctionsInternalSaaSCTL");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Internal event handlers

// Called during registration of arbitrary data export handlers.
//
// Parameters: HandlerTable - ValueTable. This procedure requires that you add information on
//  the arbitrary data export handlers to the value table. Columns:
//    MetadataObject - MetadataObject. The handler to be registered
//      is called when the object data is exported. 
//    Handler - CommonModule. A common module implementing an arbitrary data export handler. 
//      The list of export procedures to be implemented in the handler depends on
//      the values of the following value table columns. 
//    BeforeExportType - Boolean. Flag specifying whether the handler must be called before 
//      exporting all infobase objects associated with this metadata object. If set to True,
//      the common module of the handler must include the exportable procedure 
//      BeforeExportType() supporting the following parameters:
//        Container - DataProcessorObject.ImportExportContainerManagerData - container
//          manager used for data export. For more information, see the comment to
//          ImportExportContainerManagerData interface. 
//        Serializer - XDTOSerializer initialized with reference annotation support. 
//          If an arbitrary export handler requires additional data export, it is recommended 
//          that you use XDTOSerializer passed to BeforeExportType() as Serializer parameter, 
//          not obtained using XDTOSerializer global context property.
//        MetadataObject - MetadataObject. The handler is called before the object data is exported. 
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
//          as Serializer parameter, not obtained using XDTOSerializer global context property.
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
//        Artifacts - Array of XDTODataObject - set of additional information
//          logically associated with the object but not contained in it (object artifacts). 
//          Artifacts must be created in the BeforeExportObject() handler and added
//          to the array that is passed as Artifacts parameter value. 
//          Each artifact is a XDTO object with abstract XDTO type used as its
//          basic type {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. 
//          XDTO packages not included in the DataImportExport subsystem can be used too. 
//          The artifacts generated in the BeforeExportObject() procedure will be available
//          in the data import handler procedures 
//          (see the comment to OnRegisterDataImportHandlers() procedure).
//        Cancel - Boolean. If set to True in BeforeExportObject(), the corresponding object
//           is not exported.
//    AfterExportType() - Boolean. Flag specifying whether the handler is called after all 
//      infobase objects associated with this metadata object are exported. If set to True,
//      the common module of the handler must include the exportable procedure 
//      AfterExportType() supporting the following parameters:
//        Container - DataProcessorObject.ImportExportContainerManagerData - container
//          manager used for data export. For more information, see the comment to
//          ImportExportContainerManagerData interface.
//        Serializer - XDTOSerializer initialized with reference annotation support. 
//          If an arbitrary export handler requires additional data export, it is
//          recommended that you use XDTOSerializer passed to AfterExportType() 
//          as Serializer parameter, not obtained using XDTOSerializer global context property.
//        MetadataObject - MetadataObject. The handler is called after the object data is exported.
//
Procedure OnRegisterDataExportHandlers(HandlerTable) Export
	
	FileCatalogs = ReadFileFunctionExportImportCache().FileCatalogs;
	For Each FileCatalog In FileCatalogs Do
		
		NewHandler = HandlerTable.Add();
		NewHandler.MetadataObject = Metadata.FindByFullName(FileCatalog.Key);
		NewHandler.Handler = FileFunctionsInternalSaaSCTL;
		NewHandler.BeforeExportObject = True;
		
	EndDo;
	
EndProcedure

// Called during registration of arbitrary data import handlers.
//
// Parameters: HandlerTable - ValueTable. The procedure presumes that information 
//  on registered arbitrary data import handlers must be added to this table. Columns:
//    MetadataObject - MetadataObject. When importing its data, the
//      handler to be registered is called. 
//    Handler - CommonModule. A common module implementing an arbitrary data import handler. 
//      Set of export procedures to be implemented in the handler depends on the values of the
//      following value table columns. 
//    BeforeRefMapping - Boolean. Flag specifying whether the handler must be called 
//      before mapping the source infobase references and the current infobase references 
//      associated with this metadata object. If set to True, the common module of
//      the handler must include the exportable procedure BeforeRefMapping() supporting 
//      the following parameters:
//        Container - DataProcessorObject.ImportExportContainerManagerData - container
//          manager used for data import. For more information, see the comment to 
//          ImportExportContainerManagerData interface.
//        MetadataObject - MetadataObject. The handler is called before
//          the object references are mapped.
//        StandardProcessing - Boolean. If set to False in BeforeRefMapping(), the MapRefs() 
//          function of the corresponding common module will be called 
//          instead of the standard reference mapping (searching the current infobase
//          for objects with the natural key values identical to the values exported
//          from the source infobase).
//          MapRefs() function parameters:
//            Container - DataProcessorObject.ImportExportContainerManagerData - container
//              manager used for data import. For more information, see the comment to
//              ImportExportContainerManagerData interface. 
//            SourceRefTable - ValueTable, contains details on references exported  
//              from the source infobase. Columns:
//                SourceRef - AnyRef, a source infobase object reference to be mapped to a
//                  current infobase reference. 
//                The other columns are identical to the object's natural key fields that were passed 
//                  to ImportExportInfobaseData.RefMappingRequiredOnImport() during data export. 
//          MapRefs() returns: ValueTable with the following columns:
//            SourceRef - AnyRef, object reference exported from the original infobase.
//            Ref - AnyRef mapped the original reference in the current infobase.
//        Cancel - Boolean. If set to True in BeforeRefMapping(), references
//          corresponding to the current metadata object are not mapped.
//    BeforeImportType - Boolean. Flag specifying whether the handler must be called before 
//      importing all infobase objects associated with this metadata object. 
//      If set to True, the common module of the handler must include the
//      exportable procedure BeforeImportType() supporting the following parameters:
//        Container - DataProcessorObject.ImportExportContainerManagerData - container
//          manager used for data import. For more information, see the comment to 
//          ImportExportContainerManagerData interface.
//        MetadataObject - MetadataObject. The handler is called before
//          the object data is imported. 
//        Cancel - Boolean. If set to True in AfterImportType(), the data objects corresponding 
//          to the current metadata object are not imported.
//    BeforeImportObject - Boolean. Flag specifying whether the handler must be called 
//      before importingthe infobase object associated with this metadata object. 
//      If set to True, the common module of the handler must include the
//      exportable procedure BeforeImportObject() supporting the following parameters:
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
//        Cancel - Boolean. If set to True in BeforeImportObject(), the data object is not imported.
//    AfterImportObject - Boolean. Flag specifying whether the handler must be called 
//      after importing the infobase object associated with this metadata object. 
//      If set to True, the common module of the handler must include the
//      exportable procedure AfterImportObject() supporting the following parameters:
//        Container - DataProcessorObject.ImportExportContainerManagerData - container
//          manager used for data import. For more information, see the comment to 
//          ImportExportContainerManagerData interface.
//        Object - ConstantValueManager CatalogObject.*, DocumentObject.*, .*,
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
//    AfterImportType - Boolean. Flag specifying whether the handler must be called after 
//      importing all infobase objects associated with this metadata object. 
//      If set to True, the common module of the handler must include the
//      exportable procedure AfterImportType() supporting the following parameters:
//        Container - DataProcessorObject.ImportExportContainerManagerData - container
//          manager used for data import. For more information, see the comment to 
//          ImportExportContainerManagerData interface.
//        MetadataObject - MetadataObject. The handler is called after the object data is imported.
//
Procedure OnRegisterDataImportHandlers(HandlerTable) Export
	
	FileCatalogs = ReadFileFunctionExportImportCache().FileCatalogs;
	For Each FileCatalog In FileCatalogs Do
		
		NewHandler = HandlerTable.Add();
		NewHandler.MetadataObject = Metadata.FindByFullName(FileCatalog.Key);
		NewHandler.Handler = FileFunctionsInternalSaaSCTL;
		NewHandler.BeforeImportObject = True;
		
	EndDo;
	
	
	
EndProcedure

// Fills the array of types excluded from data import and export.
//
// Parameters:
//  Types - Array(Types).
//
Procedure OnFillExcludedFromImportExportTypes(Types) Export
	
	ExcludedTypes = ReadFileFunctionExportImportCache().StorageObjects;
	
	For Each ExcludedType In ExcludedTypes Do
		Types.Add(Metadata.FindByFullName(ExcludedType.Key));
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Data export handlers

Procedure BeforeExportObject(Container, Serializer, Object, Artifacts, Cancel) Export
	
	FileCatalogs = ReadFileFunctionExportImportCache().FileCatalogs;
	
	Handler = FileCatalogs.Get(Object.Metadata().FullName());
	
	If Handler = Undefined Then
		
		Raise CTLAndSLIntegration.SubstituteParametersInString(
			NStr("en = 'FileFunctionsInternalSaaSCTL.BeforeExportObject()
                  |handler cannot process metadata object %1.'", Metadata.DefaultLanguage.LanguageCode),
			Object.Metadata().FullName()
		);
		
	EndIf;
	
	HandlerModule = CTLAndSLIntegration.CommonModule(Handler);
	
	FileExtention = HandlerModule.FileExtention(Object);
	
	FileName = Container.CreateArbitraryFile(FileExtention);
	
	HandlerModule.UnloadFile(Object, FileName);
	
	Artifact = XDTOFactory.Create(FileArtifactType());
	Artifact.RelativeFilePath = Container.GetRelativeFileName(FileName);
	Artifacts.Add(Artifact);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Data import handlers

Procedure BeforeImportObject(Container, Object, Artifacts, Cancel) Export
	
	FileCatalogs = ReadFileFunctionExportImportCache().FileCatalogs;
	
	Handler = FileCatalogs.Get(Object.Metadata().FullName());
	
	If Handler = Undefined Then
		
		Raise CTLAndSLIntegration.SubstituteParametersInString(
			NStr("en = 'FileFunctionsInternalSaaSCTL.BeforeExportObject() handler
                  |cannot process metadata object %1.'", Metadata.DefaultLanguage.LanguageCode),
			Object.Metadata().FullName()
		);
		
	EndIf;
	
	HandlerModule = CTLAndSLIntegration.CommonModule(Handler);
	
	For Each Artifact In Artifacts Do
		
		If Artifact.Type() = FileArtifactType() Then
			
			HandlerModule.LoadFile(Object, Container.GetFullFileName(Artifact.RelativeFilePath));
			
		EndIf;
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Update handlers

Procedure RegisterUpdateHandlers(Val Handlers) Export
	
	Handler               = Handlers.Add();
	Handler.Version       = "*";
	Handler.ExclusiveMode = False;
	Handler.SharedData    = True;
	Handler.Priority      = 99;
	Handler.Procedure     = "FileFunctionsInternalSaaSCTL.FillFileFunctionDataExportImportCache";
	
EndProcedure

Procedure FillFileFunctionDataExportImportCache() Export
	
	FileCatalogs = New Map();
	InfobaseStorageObjects = New Map();
	
	Handlers = IntegrationHandlers();
	
	For Each Handler In Handlers Do
		
		HandlerModule = CTLAndSLIntegration.CommonModule(Handler);
		
		HandlerFileCatalogs = HandlerModule.FileCatalogs();
		For Each HandlerFileCatalog In HandlerFileCatalogs Do
			FileCatalogs.Insert(HandlerFileCatalog.FullName(), Handler);
		EndDo;
		
		HandlerStorageObjects = HandlerModule.InfobaseFileStoredObjects();
		For Each HandlerStorageObject In HandlerStorageObjects Do
			InfobaseStorageObjects.Insert(HandlerStorageObject.FullName(), Handler);
		EndDo;
		
	EndDo;
	
	Cache = New Structure("FileCatalogs, StorageObjects", FileCatalogs, InfobaseStorageObjects);
	
	SetPrivilegedMode(True);
	Constants.ImportExportFileFunctionCacheData.Set(New ValueStorage(Cache));
	
EndProcedure

//

Function FileArtifactType()
	
	Return XDTOFactory.Type(Package(), "FileArtefact");
	
EndFunction

Function Package()
	
	Return "http://www.1c.ru/1cFresh/Data/Artefacts/Files/1.0.0.1";
	
EndFunction

Function ReadFileFunctionExportImportCache()
	
	SetPrivilegedMode(True);
	Return Constants.ImportExportFileFunctionCacheData.Get().Get();
	
EndFunction

Function IntegrationHandlers()
	
	IntegrationHandlers = New Array();
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"CloudTechnology.SaaSOperations.FileFunctionsSaaS\OnFillFileFunctionIntegrationHandlersInSaaS");
	For Each EventHandler In EventHandlers Do
		EventHandler.Module.OnFillFileFunctionIntegrationHandlersInSaaS(IntegrationHandlers);
	EndDo;
	
	Return IntegrationHandlers;
	
EndFunction