////////////////////////////////////////////////////////////////////////////////
// File functions subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Returns maximum file size.
//
// Returns:
//  Number - number of bytes (integer).
//
Function MaxFileSize() Export
	
	SetPrivilegedMode(True);
	
	MaxFileSize = Constants.MaxFileSize.Get();
	
	If MaxFileSize = Undefined
	 Or MaxFileSize = 0 Then
		
		MaxFileSize = 50*1024*1024; // 50 MB
		Constants.MaxFileSize.Set(MaxFileSize);
	EndIf;
	
	If CommonUseCached.DataSeparationEnabled()
	   And CommonUseCached.CanUseSeparatedData() Then
		
		MaxDataAreaFileSize =
			Constants.MaxDataAreaFileSize.Get();
		
		If MaxDataAreaFileSize = Undefined
		 Or MaxDataAreaFileSize = 0 Then
			
			MaxDataAreaFileSize = 50*1024*1024; // 50 MB
			
			Constants.MaxDataAreaFileSize.Set(
				MaxDataAreaFileSize);
		EndIf;
		
		MaxFileSize = Min(MaxFileSize, MaxDataAreaFileSize);
	EndIf;
	
	Return MaxFileSize;
	
EndFunction

// Returns maximum provider file size.
//
// Returns:
//  Number - number of bytes (integer).
//
Function MaxFileSizeCommon() Export
	
	SetPrivilegedMode(True);
	
	MaxFileSize = Constants.MaxFileSize.Get();
	
	If MaxFileSize = Undefined
	 Or MaxFileSize = 0 Then
		
		MaxFileSize = 50*1024*1024; // 50 MB
		Constants.MaxFileSize.Set(MaxFileSize);
	EndIf;
	
	Return MaxFileSize;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Managing file volumes

// Whether there is at least one file storage volume.
//
// Returns:
//  Boolean - If True, then there is at least one available volume.
//
Function HasFileStorageVolumes() Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.FileStorageVolumes AS FileStorageVolumes
	|WHERE
	|	FileStorageVolumes.DeletionMark = FALSE";
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

#EndRegion
