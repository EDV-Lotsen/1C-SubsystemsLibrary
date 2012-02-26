

&AtClient
Procedure ListBeforeAddRow(Item, Cancellation, Clone, Parent, Folder)
	
	// Check, if folder copy is performed
	If Clone And Folder Then
		DoMessageBox(NStr("en = 'Adding new groups in the catalog is prohibited!'"));
		Cancellation = True;
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// PROCEDURES OF SUBSYSTEM 'SETTING ITEM ORDER'

&AtClient
Procedure ShiftItemUp()
	
	ItemOrderSetupClient.ShiftItemUp(List, Items.List);
	
EndProcedure

&AtClient
Procedure ShiftItemDown()
	
	ItemOrderSetupClient.ShiftItemDown(List, Items.List);
	
EndProcedure


