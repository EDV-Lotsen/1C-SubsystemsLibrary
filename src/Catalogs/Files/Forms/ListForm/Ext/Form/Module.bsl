

&AtClient
Procedure ListSelection(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	FileOperationsClient.OpenFile(
		FileOperations.GetFileDataForOpening(Items.List.CurrentRow, Undefined, Uuid)); 
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancellation, Clone, Parent, Folder)
	Cancellation = True;
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	List.Parameters.SetParameterValue(
		"CurrentUser", CommonUse.CurrentUser());
	
	FileOperations.FillFileListConditionalAppearance(List);
EndProcedure

// File commands are accessible - there is at least one line in the list and not group is selected
&AtClient
Function FileCommandsAvailable()
	
	If Items.List.CurrentRow = Undefined Then 
		Return False;
	EndIf;
	
	If TypeOf(Items.List.CurrentRow) = Type("DynamicalListGroupRow") Then
		Return False;
	EndIf;	
	
	Return True;
	
EndFunction

&AtClient
Procedure View1(Command)
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	FileData = FileOperations.GetFileDataForOpening(Items.List.CurrentRow, Undefined, Uuid);
	FileOperationsCommands.Open(FileData);
EndProcedure


&AtClient
Procedure SaveAs(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	FileData = FileOperations.GetFileDataForSaving(Items.List.CurrentRow, Undefined, Uuid);
	FileOperationsCommands.SaveAs(FileData);
	
EndProcedure

&AtClient
Procedure Release(Command)
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	FileOperationsCommands.UnlockFile(
		Items.List.CurrentRow,
		Items.List.CurrentData.StoreVersions,
		Items.List.CurrentData.LockedByCurrentUser,
		Items.List.CurrentData.LockedBy);
		
	SetAccessibilityOfFileCommands();		
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	SetAccessibilityOfFileCommands();
EndProcedure

&AtClient
Procedure SetAccessibilityOfFileCommands()
	
	If Items.List.CurrentData <> Undefined Then
		
		If TypeOf(Items.List.CurrentRow) <> Type("DynamicalListGroupRow") Then
			
				SetAccessibilityOfCommands(Items.List.CurrentData.LockedByCurrentUser,
					Items.List.CurrentData.LockedBy);
		EndIf;	
			
	EndIf;	
EndProcedure


&AtClient
Procedure SetAccessibilityOfCommands(LockedByCurrentUser, LockedBy)
	Items.Release.Enabled = Not LockedBy.IsEmpty();
	Items.ListContextMenu.ChildItems.ContextMenuListRelease.Enabled = Not LockedBy.IsEmpty();
EndProcedure

