////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Exports data to a ZIP archive file. Later, the data can be imported from this archive
//   to other infobases or data areas by using DataImportExport.ImportDataFromArchive().
//
// Parameters:
//  ExportParameters - Structure containing data export parameters.
//    Keys:
//      TypesToExport - Array of MetadataObject - array of metadata objects 
//        whose data must be exported to archive.
//      ExportUsers - Boolean - export information on infobase users. 
//      ExportUserSettings - Boolean. If ExportUsers = False, this parameter is ignored.
//    The structure can also contain additional keys intended to be processed 
//      by arbitrary data export handlers.
//
// Returns: String - path to export file.
//
Function ExportDataToArchive(Val ExportParameters) Export
	
	If Not CheckRights() Then
		Raise NStr("en = 'Insufficient rights for data export.'");
	EndIf;
	
	SetPrivilegedMode(True);
	
	If Not ExportParameters.Property("TypesToExport") Then
		ExportParameters.Insert("TypesToExport", New Array());
	EndIf;
	
	If Not ExportParameters.Property("ExportUsers") Then
		ExportParameters.Insert("ExportUsers", False);
	EndIf;
	
	If Not ExportParameters.Property("ExportUserSettings") Then
		ExportParameters.Insert("ExportUserSettings", False);
	EndIf;
	
	Directory = GetTempFileName();
	CreateDirectory(Directory);
	Directory = Directory + "\";
	
	Try
		
		DataExportImportInternal.ExportDataToDirectory(Directory, ExportParameters);
		
		Archive = GetTempFileName("zip");
		Archiver = New ZipFileWriter(Archive, , , ZIPCompressionMethod.Deflate, ZIPCompressionLevel.Optimal);
		Archiver.Add(Directory + "*", ZIPStorePathMode.StoreRelativePath, ZIPSubDirProcessingMode.ProcessRecursively);
		Archiver.Write();
		
		DeleteFiles(Directory);
		
	Except
		
		DeleteFiles(Directory);
		If Archive <> Undefined Then 
			DeleteFiles(Archive);
		EndIf;
		
		Raise;
		
	EndTry;
	
	Return Archive;
	
EndFunction

// Imports data from a ZIP archive containing XML files.
//
// Parameters:
//  ArchiveName - String - full name of archive data file.
//  ImportParameters - Structure containing data import parameters.
//    Keys:
//      TypesToImport - Array of MetadataObject - array of metadata objects 
//        whose data must be imported from archive. 
//        If the parameter value is set, only the specified data will be imported from the archive file. 
//        If the parameter value is not set, all data will be imported from the archive file.
//      ImportUsers - Boolean - import information on infobase users.
//      ImportUserSettings - Boolean. If ImportUsers = False, this parameter is ignored.
//    The structure can also contain additional keys intended to be processed 
//      by arbitrary data import handlers.
//
Procedure ImportDataFromArchive(Val ArchiveName, Val ImportParameters) Export
	
	If Not CheckRights() Then
		Raise NStr("en = 'Insufficient rights for data import.'");
	EndIf;
	
	SetPrivilegedMode(True);
	
	Directory = GetTempFileName();
	CreateDirectory(Directory);
	Directory = Directory + "\";
	
	Archiver = New ZipFileReader(ArchiveName);
	
	Try
		
		Archiver.ExtractAll(Directory, ZIPRestoreFilePathsMode.Restore);
		
		DataExportImportInternal.ImportDataFromDirectory(Directory, ImportParameters);
		
		DeleteFiles(Directory);
		
	Except
		
		DeleteFiles(Directory);
		Raise;
		
	EndTry;
	
EndProcedure

// Checks compatibility of data to be imported from file with the current infobase configuration.
//
// Parameters:
//  ArchiveName - String - path to export file.
//
// Returns: Boolean - True if the archive data can be imported to the current configuration.
//
Function DataInArchiveCompatibleWithCurrentConfiguration(Val ArchiveName) Export
	
	Directory = GetTempFileName();
	CreateDirectory(Directory);
	Directory = Directory + "\";
	
	Archiver = New ZipFileReader(ArchiveName);
	
	Try
		
		ExportDescriptionItem = Archiver.Items.Find("DumpInfo.xml");
		
		If ExportDescriptionItem = Undefined Then
			Raise NStr("en = 'DumpInfo.xml is missing from the export file.'");
		EndIf;
		
		Archiver.Extract(ExportDescriptionItem, Directory, ZIPRestoreFilePathsMode.Restore);
		
		ExportDescriptionFile = Directory + "DumpInfo.xml";
		
		ExportInfo = DataExportImportInternal.ReadXDTOObjectFromFile(
			ExportDescriptionFile, XDTOFactory.Type("http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1", "DumpInfo")
		);
		
		Result = DataExportImportInternal.DataInArchiveCompatibleWithCurrentConfiguration(ExportInfo)
			And DataExportImportInternal.ExportArchiveFileCompatibleWithCurrentConfigurationVersion(ExportInfo);
		
		DeleteFiles(Directory);
		
		Return Result;
		
	Except
		
		DeleteFiles(Directory);
		Raise;
		
	EndTry;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

Function CheckRights()
	
	Return AccessRight("DataAdministration", Metadata);
	
EndFunction
