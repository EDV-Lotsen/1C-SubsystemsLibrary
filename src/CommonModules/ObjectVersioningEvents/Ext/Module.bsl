////////////////////////////////////////////////////////////////////////////////
// Object versioning subsystem
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Writes an object version (unless it is a document version) to the infobase.
//
// Parameters
//  Source    - Object  - infobase object to write.
//  Cancel    - Boolean - cancellation flag.
//
Procedure WriteObjectVersion(Source, Cancel) Export
	
	ObjectVersioning.WriteObjectVersion(Source, False);
	
EndProcedure

// Writes a document version to the infobase.
//
// Parameters
//  Source    - Object  - infobase document to write.
//  Cancel    - Boolean - cancellation flag.
//
Procedure WriteDocumentVersion(Source, Cancel, WriteMode, PostingMode) Export
	
	ObjectVersioning.WriteObjectVersion(Source, WriteMode = DocumentWriteMode.Posting);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Handlers of the conditional subsystem calls

// Writes an object version to the infobase. The procedure is called
// during the execution of data exchange with another infobase.
//
// Parameters
//  Source    - Object  - infobase object to write.
//  Cancel    - Boolean - cancellation flag.
//
Procedure WriteObjectVersionOnDataExchange(Source, Cancel) Export
	
	If Source.AdditionalProperties.Property("ObjectVersionDetails") Then
		
		ObjectVersioning.OnCreateObjectVersionOnDataExchange(Source);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event subscription handlers

// For internal use only
//
Procedure DeleteVersionAuthorInfo(Source, Cancel) Export
	
	InformationRegisters.ObjectVersions.DeleteVersionAuthorInfo(Source.Ref);
	
EndProcedure

#EndRegion
