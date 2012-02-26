
&AtClient
Procedure ListBeforeDelete(Item, Cancellation)
	FileData = FileOperations.GetFileData(Undefined, Items.List.CurrentRow);
	
	If FileData.CurrentVersion = Items.List.CurrentRow Then
			DoMessageBox(NStr("en = 'Active version cannot be deleted!'"));
			Cancellation = True;
	EndIf;	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "EditCompleted" Or EventName = "VersionSaved" Then
		Items.List.Refresh();
	EndIf;
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancellation, Clone, Parent, Folder)
	Cancellation = True;
EndProcedure

&AtClient
Procedure ListSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	FileOperationsClient.OpenFileVersion(
		FileOperations.GetFileDataForOpening(Undefined, RowSelected, Uuid),
		Uuid);
	
EndProcedure

