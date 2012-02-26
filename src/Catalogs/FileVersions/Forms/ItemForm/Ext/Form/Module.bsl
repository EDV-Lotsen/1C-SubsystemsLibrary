

&AtClient
Procedure OpenExecute()
	FileData = FileOperations.GetFileDataForOpening(
		Undefined, Object.Ref, Uuid);
	FileOperationsClient.OpenFileVersion(FileData, Uuid);
EndProcedure

&AtClient
Procedure FullDescrOnChange(Item)
	Object.Description = Object.Details;
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	If TypeOf(Object.Owner) = Type("CatalogRef.Files") Then
		Items.Details.ReadOnly = True;
	EndIf;	
	
	If Users.CurrentUserHaveFullAccess() Then
		Items.Author.ReadOnly 			= False;
		Items.CreationDate.ReadOnly 		= False;
		Items.ParentalVersion.ReadOnly 	= False;
	Else
		Items.GroupStorage.Visible = False;
	EndIf;	
	
	VolumeFullPath = FileOperations.VolumeFullPath(Object.Volume);
	
EndProcedure


&AtClient
Procedure AfterWrite(WriteParameters)
	Notify("VersionSaved", Object.Owner);
EndProcedure

