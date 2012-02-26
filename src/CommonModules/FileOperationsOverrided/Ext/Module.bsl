

////////////////////////////////////////////////////////////////////////////////
// Link access control in FileOperations subsystem.

Function FileLockingPermitted(FileData, ErrorString = "") Export 

	Return True;
	
EndFunction

Procedure BeforeFileWrite(ThisObject, Cancellation) Export 
	
EndProcedure	

// Function DeletionMarkSettingPermitted, when using restriction
// of deletion mark checks, if current user can mark for deletion
// directory or file.
//
// Parameters:
//  Ref       - CatalogRef.FileFolders, CatalogRef.Files,
//                 <owner ref>.
//
// Value returned:
//  Boolean.
//
Function DeletionMarkSettingPermitted(Ref) Export
	
	Return True;
	
EndFunction

