////////////////////////////////////////////////////////////////////////////////
// INTERNAL INTERFACE

////////////////////////////////////////////////////////////////////////////////
// Adds handlers of internal events (subscriptions).

// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS
	
	ServerHandlers["CloudTechnology.DataImportExport\BeforeDataExport"].Add(
		"InfobaseUpdateInternalSaaSCTL");
	
	ServerHandlers["CloudTechnology.DataImportExport\BeforeDataImport"].Add(
		"InfobaseUpdateInternalSaaSCTL");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Internal event handlers

// Called before data export.
//
// Parameters:
//  Container - DataProcessorObject.ImportExportContainerManagerData - container manager 
//    used for data export. For more information, see the comment to 
//    ImportExportContainerManagerData interface.
Procedure BeforeDataExport(Container) Export
	
	FileName = Container.CreateArbitraryFile("xml", DataTypeForSubsystemVersionExportImport());
	
	SubsystemVersions = New Structure();
	
	SubsystemDescriptions = StandardSubsystemsCached.SubsystemDescriptions().ByNames;
	For Each SubsystemDetails In SubsystemDescriptions Do
		SubsystemVersions.Insert(SubsystemDetails.Key, InfobaseUpdate.InfobaseVersion(SubsystemDetails.Key));
	EndDo;
	
	DataExportImportInternal.WriteObjectToFile(SubsystemVersions, FileName);
	Container.SetObjectAndRecordCount(FileName, SubsystemVersions.Count());
	
EndProcedure

// Called before data import.
//
// Parameters:
//  Container - DataProcessorObject.ImportExportContainerManagerData - container manager
//    used for data import. For more information, see the comment to 
//    ImportExportContainerManagerData interface.
//
Procedure BeforeDataImport(Container) Export
	
	FileName = Container.GetArbitraryFile(DataTypeForSubsystemVersionExportImport());
	
	SubsystemVersions = DataExportImportInternal.ReadObjectFromFile(FileName);
	
	BeginTransaction();
	
	Try
		
		For Each SubsystemVersion In SubsystemVersions Do
			InfobaseUpdateInternal.SetInfobaseVersion(SubsystemVersion.Key, SubsystemVersion.Value, False);
		EndDo;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

Function DataTypeForSubsystemVersionExportImport()
	
	Return "1cfresh\ApplicationData\SubstemVersions";
	
EndFunction
