

// Handle event Selection of list
//
&AtClient
Procedure ListSelection(Item, RowSelected, Field, StandardProcessing)
	
	FileOperationsClient.OpenFile(
		FileOperations.GetFileDataForOpening(RowSelected, Undefined, Uuid)); 
	StandardProcessing = False;
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	User = CommonUse.CurrentUser();
	FileList.Parameters.SetParameterValue("LockedBy", User);
	
	ShowColumnSize = FileOperations.GetShowColumnSize();
	If ShowColumnSize = False Then
		Items.CurrentVersionSize.Visible = False;
	EndIf;
				   
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancellation, Clone, Parent, Folder)
	Cancellation = True;
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
		Items.List.CurrentData.LockedBy,
		Items.List.CurrentData.Author);
		
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

&AtClient
Procedure SetAccessibilityOfCommands(Enabled)
	Items.EndEdit.Enabled = Enabled;
	Items.ListContextMenu.ChildItems.ContextMenuListEndEdit.Enabled = Enabled;
	
	Items.OpenFile.Enabled = Enabled;
	Items.ListContextMenu.ChildItems.ContextMenuListOpenFile.Enabled = Enabled;
	
	Items.Change.Enabled = Enabled;
	
	Items.ListContextMenu.ChildItems.ContextMenuListSaveChanges.Enabled 			= Enabled;
	Items.ListContextMenu.ChildItems.ContextMenuListOpenFileDirectory.Enabled 		= Enabled;
	Items.ListContextMenu.ChildItems.ContextMenuListSaveAs.Enabled 					= Enabled;
	Items.ListContextMenu.ChildItems.ContextMenuListRelease.Enabled 				= Enabled;
	Items.ListContextMenu.ChildItems.ContextMenuListRefreshFromFileAtDrive.Enabled 	= Enabled;
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	
	If Items.List.CurrentRow = Undefined Then
		SetAccessibilityOfCommands(False);
	Else
		SetAccessibilityOfCommands(True);
	EndIf;	
	                                       	
EndProcedure
