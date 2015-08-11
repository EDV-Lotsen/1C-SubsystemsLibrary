///////////////////////////////////////////////////////////////////////////////////////////////////////////
// Export and import data into data area event handlers.
//
///////////////////////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Is called before saving data to a file during data export.
//
// Parameters:
// DataItem - ConstantManager.<Name>; CatalogObject.<Name>; <Kind>RegisterRecordSet.<Name>.
//
Procedure BeforeDataExport(DataItem) Export
	
	//// StandardSubsystems.FileFunctions
	//ItemSending = DataItemSend.Auto;
	//FileExchangeEvents.OnSendFileData(DataItem, ItemSending, False);
	//// End StandardSubsystems.FileFunctions
	
EndProcedure

// Is called before writing data to the infobase during data import.
//
// Parameters:
// DataItem - ConstantManager.<Name>; CatalogObject.<Name>; <Kind>RegisterRecordSet.<Name>.
//
Procedure BeforeDataImport(DataItem) Export
	
	//// StandardSubsystems.FileFunctions
	//ItemReceive = DataItemReceive.Auto;
	//FileExchangeEvents.OnFileDataReceive(DataItem, ItemReceive);
	//// End StandardSubsystems.FileFunctions
	
EndProcedure

// Is called before finishing area data export.
//
// Parameters:
// ExportDirectory - String - directory that contains prepared export files.
// When export will be completed, all files from this directory will be included 
// into the resulting archive.
//
Procedure ExportBeforeComplete(Val ExportDirectory) Export
	
	Catalogs.MetadataObjectIDs.UnloadCatalogData(ExportDirectory);
	
EndProcedure

// Is called before a standard creation of a replacement dictionary.
//
// Parameters:
// ReplacementDictionary - Value table with the following columns:
// Type - Type - value type of a reference to be replaced;
// ReferenceMap - Map - map between new references and original ones:
// Key - new reference to be substituted;
// Value - original reference to be removed;
// ExportDirectory - String - name of a directory that contains export files.
//
Procedure SupplementReplacementDictionaryByExportCatalog(Val ReplacementDictionary, Val ExportDirectory) Export
	
	Catalogs.MetadataObjectIDs.SupplementReplacementDictionaryReferencesCurrentIdentifiersAndDownloadables(ReplacementDictionary, ExportDirectory);
	
EndProcedure

// Is called at the end of a standard creation of a replacement dictionary
// by the current shared data file.
//
// Parameters:
// ReplacementDictionary - Value table with the following columns:
// Type - Type - value type of a reference to be replace;
// ReferenceMap - Map - map of a new reference and original one:
// Key - new reference to be substituted;
// Value - original reference to be removed;
// SharedDataFileName - String - name of a current shared data export file.
//
Procedure SupplementReplacementDictionaryForSharedData(Val ReplacementDictionary, Val SharedDataFileName) Export
	
EndProcedure