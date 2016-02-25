
#Region FormCommandHandlers

&AtClient
Procedure MoveItemUp()
	
	ItemOrderSetupClient.MoveItemUpExecute(List, Items.List);
	
EndProcedure

&AtClient
Procedure MoveItemDown()
	
	ItemOrderSetupClient.MoveItemDownExecute(List, Items.List);
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, Group)
	
	// Checking if group is being cloned
	If Clone And Group Then
		Cancel = True;
		
		ShowMessageBox(, NStr("en='Adding new groups to catalog is prohibited.'"));
	EndIf;
	
EndProcedure

#EndRegion
