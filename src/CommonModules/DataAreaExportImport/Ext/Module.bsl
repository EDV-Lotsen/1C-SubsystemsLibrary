////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Exports application data to a ZIP archive file.
//  Later, data can be imported from this archive to other infobases or data areas 
//  by using DataAreaExportImport.ImportCurrentDataAreaFromArchive().
//
// Returns: String - path to export file.
//
Function ExportCurrentDataAreaToArchive() Export
	
	TypesToExport = New Array();
	CommonUseClientServer.SupplementArray(TypesToExport, GetAreaDataModelTypes());
	CommonUseClientServer.SupplementArray(TypesToExport,
		DataExportImportInternalEvents.GetCommonDataTypesThatSupportRefMappingOnImport(), True);
	
	ExportParameters = New Structure();
	ExportParameters.Insert("TypesToExport", TypesToExport);
	ExportParameters.Insert("ExportUsers", True);
	ExportParameters.Insert("ExportUserSettings", True);
	
	Return DataImportExport.ExportDataToArchive(ExportParameters);
	
	
EndFunction

// Exports application data to a ZIP archive file and puts the archive in temporary storage.
//  Later, data can be imported from the archive to other infobases or data areas 
//  by using DataAreaExportImport.ImportCurrentDataAreaFromArchive().
//
// Parameters:
//  StorageAddress - String - temporary storage address where the ZIP archive file must be stored.
//
Procedure ExportCurrentDataAreaToTemporaryStorage(StorageAddress) Export
	
	FileName = ExportCurrentDataAreaToArchive();
	
	Try
		
		ExportData = New BinaryData(FileName);
		PutToTempStorage(ExportData, StorageAddress);
		ExportData = Undefined;
		DeleteFiles(FileName);
		
	Except
		
		DeleteFiles(FileName);
		Raise;
		
	EndTry;
	
EndProcedure

// Imports application data from a ZIP archive containing XML files.
//
// Parameters:
//  ArchiveName - String - full name of archive by data file.
//  ImportParameters - Structure containing data import parameters.
//    Keys:
//      TypesToImport - Array(MetadataObject) - array of metadata objects 
//        whose data must be imported from archive. If the parameter value is set, 
//        only the specified data will be imported from the archive file. If the
//        parameter value is not set, all data will be imported from the archive file.
//      ImportUsers - Boolean - import information on infobase users.
//      ImportUserSettings - Boolean. If ImportUsers = False, this parameter is ignored.
//    The structure can also contain additional keys 
//     intended to be processed by arbitrary data import handlers.
//
Procedure ImportCurrentDataAreaFromArchive(Val ArchiveName, Val ImportUsers = False, Val CollapseUserCatalogItems = False) Export
	
	TypesToImport = New Array();
	CommonUseClientServer.SupplementArray(TypesToImport, GetAreaDataModelTypes());
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		CommonUseClientServer.SupplementArray(TypesToImport,
			DataExportImportInternalEvents.GetCommonDataTypesThatSupportRefMappingOnImport(), True);
	EndIf;
	
	ImportParameters = New Structure();
	ImportParameters.Insert("TypesToImport", TypesToImport);
	
	If CTLAndSLIntegration.DataSeparationEnabled() Then
		
		ImportParameters.Insert("ImportUsers", ImportUsers);
		ImportParameters.Insert("ImportUserSettings", ImportUsers);
	Else
		
		ImportParameters.Insert("ImportUsers", False);
		ImportParameters.Insert("ImportUserSettings", False);
		
	EndIf;
	
	ImportParameters.Insert("CollapseSeparatedUsers", CollapseUserCatalogItems);
	
	DataImportExport.ImportDataFromArchive(ArchiveName, ImportParameters);
	
EndProcedure

// Checks compatibility of data to be imported from file with the current infobase configuration.
//
// Parameters:
//  ArchiveName - String - path to export file.
//
// Returns: Boolean - True if the archive data can be imported to the current configuration.
//
Function DataInArchiveCompatibleWithCurrentConfiguration(Val ArchiveName) Export
	
	Return DataImportExport.DataInArchiveCompatibleWithCurrentConfiguration(ArchiveName);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

Function GetAreaDataModelTypes()
	
	Result = New Array();
	
	DataModel = CTLAndSLIntegration.GetDataAreaModel();
	
	For Each ModelItemData In DataModel Do
		
		MetadataObject = Metadata.FindByFullName(ModelItemData.Key);
		
		If Not DataExportImportInternal.IsScheduledJob(MetadataObject)
				And Not DataExportImportInternal.IsDocumentJournal(MetadataObject) Then
			
			Result.Add(MetadataObject);
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction
