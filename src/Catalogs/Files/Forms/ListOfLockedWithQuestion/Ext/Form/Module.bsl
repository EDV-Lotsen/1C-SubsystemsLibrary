

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	MessageQuestion = Parameters.MessageQuestion;
	MessageTitle 	= Parameters.MessageTitle;
	Title 			= Parameters.Title;
	
	If ValueIsFilled(Parameters.FileOwner) Then 
		CommonUseClientServer.SetFilterItem(
			FileList.Filter, "FileOwner", Parameters.FileOwner);
	EndIf;
		
	If ValueIsFilled(Parameters.LockedBy) Then 
		CommonUseClientServer.SetFilterItem(
			FileList.Filter, "LockedBy", Parameters.LockedBy);
	EndIf;
	
EndProcedure

&AtClient
Procedure ListSelection(Item, RowSelected, Field, StandardProcessing)
	
	FileOperationsClient.OpenFile(
		FileOperations.GetFileDataForOpening(RowSelected, Undefined, Uuid)); 
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancellation, Clone, Parent, Folder)
	Cancellation = True;
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "EditCompleted" Then
		Items.List.Refresh(); 
	EndIf;
	
EndProcedure

&AtClient
Procedure EndEdit(Command)
	
	If Items.List.CurrentRow = Undefined Then 
		Return;
	EndIf;
	
	LockedByCurrentUser = True;	
	FileOperationsCommands.EndEdit(
		Items.List.CurrentRow,
		Uuid,
		Items.List.CurrentData.StoreVersions,
		LockedByCurrentUser,
		Items.List.CurrentData.LockedBy);
		
EndProcedure

&AtClient
Procedure OpenFile(Command)
	
	If Items.List.CurrentRow = Undefined Then 
		Return;
	EndIf;
	
	FileData = FileOperations.GetFileDataForOpening(Items.List.CurrentRow, Undefined, Uuid);
	FileOperationsCommands.Open(FileData);
	
EndProcedure

&AtClient
Procedure Release(Command)
	
	If Items.List.CurrentRow = Undefined Then 
		Return;
	EndIf;
	
	LockedByCurrentUser = True;
	FileOperationsCommands.UnlockFile(
		Items.List.CurrentRow,
		Items.List.CurrentData.StoreVersions,
		LockedByCurrentUser,
		Items.List.CurrentData.LockedBy);
		
EndProcedure

&AtClient
Procedure SaveChanges(Command)
	
	If Items.List.CurrentRow = Undefined Then 
		Return;
	EndIf;
	
	FileOperationsCommands.SaveAs(Items.List.CurrentRow);
	
EndProcedure

&AtClient
Procedure OpenFileDirectory(Command)
	
	If Items.List.CurrentRow = Undefined Then 
		Return;
	EndIf;
	
	FileData = FileOperations.GetFileDataForOpening(
		Items.List.CurrentRow, Undefined, Uuid);
	
	FileOperationsCommands.OpenFileDirectory(FileData);
	
EndProcedure

&AtClient
Procedure SaveAs(Command)
	
	If Items.List.CurrentRow = Undefined Then 
		Return;
	EndIf;
	
	FileData = FileOperations.GetFileDataForSaving(
		Items.List.CurrentRow, 
		Undefined, 
		Uuid);
	
	FileOperationsCommands.SaveAs(FileData);
	
EndProcedure

&AtClient
Procedure UpdateFromFileOnDisk(Command)
	If Items.List.CurrentRow = Undefined Then 
		Return;
	EndIf;
	
	FileData = FileOperations.GetFileDataAndWorkingDirectory(Items.List.CurrentRow);
	FileOperationsCommands.UpdateFromFileOnDisk(FileData, Uuid);
EndProcedure
