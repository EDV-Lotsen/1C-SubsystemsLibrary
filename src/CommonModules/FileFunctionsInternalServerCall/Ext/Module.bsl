////////////////////////////////////////////////////////////////////////////////
// File functions subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

// See the procedure in the FileFunctionsInternal module.
Procedure RecordTextExtractionResult(FileOrVersionRef,
                                     ExtractionResult,
                                     TempTextStorageAddress) Export
	
	FileFunctionsInternal.RecordTextExtractionResult(
		FileOrVersionRef,
		ExtractionResult,
		TempTextStorageAddress);
	
EndProcedure

// For internal use only
Function SpreadsheetDocumentFromTemporaryStorage(Address) Export
	
	BinaryData = GetFromTempStorage(Address);
	
	TempFileName = GetTempFileName();
	BinaryData.Write(TempFileName);
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.Read(TempFileName);
	
	Return SpreadsheetDocument;
	
EndFunction

#EndRegion
