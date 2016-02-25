#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Interface

// Returns the list of attributes that can be edited
// using the Batch object modification data processor.
//
Function BatchProcessingEditableAttributes() Export
	
	EditableAttributes = New Array;
	EditableAttributes.Add("Comment");
	
	Return EditableAttributes;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Import data from file

// Prohibits importing data to the catalog from the "Import data from file" subsystem.
// Batch data import to that catalog is potentially insecure.
//
Function UseDataImportFromFile() Export
	Return False;
EndFunction

#EndRegion

#Region InternalProceduresAndFunctions

// For internal use only
Procedure AddRequestsToUseAllVolumesExternalResources(Requests) Export
	
	If CommonUseCached.DataSeparationEnabled() And CommonUseCached.CanUseSeparatedData() Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	FileStorageVolumes.Ref AS Ref,
	|	FileStorageVolumes.LinuxFullPath,
	|	FileStorageVolumes.WindowsFullPath,
	|	FileStorageVolumes.DeletionMark AS DeletionMark
	|FROM
	|	Catalog.FileStorageVolumes AS FileStorageVolumes
	|WHERE
	|	FileStorageVolumes.DeletionMark = FALSE";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		Requests.Add(RequestToUseExternalResourcesForVolume(
			Selection.Ref, Selection.WindowsFullPath, Selection.LinuxFullPath));
	EndDo;
	
EndProcedure

// For internal use only
Procedure AddRequestsToCancelUseOfAllVolumesExternalResources(Requests) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	FileStorageVolumes.Ref AS Ref,
	|	FileStorageVolumes.LinuxFullPath,
	|	FileStorageVolumes.WindowsFullPath,
	|	FileStorageVolumes.DeletionMark AS DeletionMark
	|FROM
	|	Catalog.FileStorageVolumes AS FileStorageVolumes";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		Requests.Add(SafeMode.RequestForClearingPermissionsForExternalResources(
			Selection.Ref));
	EndDo;
	
EndProcedure

// For internal use only
Function RequestToUseExternalResourcesForVolume(Volume, WindowsFullPath, LinuxFullPath) Export
	
	Permissions = New Array;
	
	If ValueIsFilled(WindowsFullPath) Then
		Permissions.Add(SafeMode.PermissionToUseFileSystemDirectory(
			WindowsFullPath, True, True));
	EndIf;
	
	If ValueIsFilled(LinuxFullPath) Then
		Permissions.Add(SafeMode.PermissionToUseFileSystemDirectory(
			LinuxFullPath, True, True));
	EndIf;
	
	Return SafeMode.RequestToUseExternalResources(Permissions, Volume);
	
EndFunction

#EndRegion

#EndIf
