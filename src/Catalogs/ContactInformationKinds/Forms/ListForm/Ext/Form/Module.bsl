////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure MoveItemUp()
	
	ItemOrderSetupClient.MoveItemUpExecute(List, Items.List);
	
EndProcedure

&AtClient
Procedure MoveItemDown()
	
	ItemOrderSetupClient.MoveItemDownExecute(List, Items.List);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	// Checking whether copying a folder is allowed
	If Copy And Group Then
		DoMessageBox(NStr("en = 'Adding new groups is not allowed.'"));
		Cancel = True;
	EndIf;
	
EndProcedure





