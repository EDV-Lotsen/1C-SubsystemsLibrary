////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	ObjectToMap = Parameters.ObjectToMap;
	
	ChoiceTable.Load(GetFromTempStorage(Parameters.TempStorageAddress));
	
	// Deleting the passed table from the temporary storage
	DeleteFromTempStorage(Parameters.TempStorageAddress);
	
	// Setting choice table field titles and visibility 
	SetTableFieldVisible("ChoiceTable", Parameters.MaxCustomFieldCount, Parameters.UsedFieldList);
	
	// Determining the choice table cursor position 
	MoveChoiceTableCursor(Parameters.StartRowSerialNumber);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENT HANDLERS OF ChoiceTable TABLE 

&AtClient
Procedure ChoiceTableChoice(Item, SelectedRow, Field, StandardProcessing)
	
	Choose(Undefined);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure Choose(Command)
	
	CurrentData = Items.ChoiceTable.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	ThisForm.Close(CurrentData.SerialNumber);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Procedure MoveChoiceTableCursor(Val StartRowSerialNumber)
	
	RowIndex = 0;
	
	While  (RowIndex <= ChoiceTable.Count() - 1)
		And (ChoiceTable[RowIndex]["SerialNumber"] < StartRowSerialNumber) Do
		
		RowIndex = RowIndex + 1;
		
	EndDo;
	
	If RowIndex <= ChoiceTable.Count() - 1 Then
		
		Items.ChoiceTable.CurrentRow = ChoiceTable[RowIndex].GetID();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetTableFieldVisible(FormTableName, MaxCustomFieldCount, UsedFieldList)
	
	SourceFieldName = StrReplace("#FormTableName#SortFieldNN","#FormTableName#", FormTableName);
	TargetFieldName = StrReplace("#FormTableName#SortFieldNN","#FormTableName#", FormTableName);
	
	// Making all map table fields invisible
	For FieldNumber = 1 to MaxCustomFieldCount Do
		
		SourceField = StrReplace(SourceFieldName, "NN", String(FieldNumber));
		TargetField = StrReplace(TargetFieldName, "NN", String(FieldNumber));
		
		ThisForm.Items[SourceField].Visible = False;
		ThisForm.Items[TargetField].Visible = False;
		
	EndDo;
	
	// Setting visibility of map table fields selected by user.
	For Each Item In UsedFieldList Do
		
		FieldNumber = UsedFieldList.IndexOf(Item) + 1;
		
		SourceField = StrReplace(SourceFieldName, "NN", String(FieldNumber));
		TargetField = StrReplace(TargetFieldName, "NN", String(FieldNumber));
		
		// Setting field visibility 
		ThisForm.Items[SourceField].Visible = Item.Check;
		ThisForm.Items[TargetField].Visible = Item.Check;
		
		// Setting field titles
		ThisForm.Items[SourceField].Title = Item.Value;
		ThisForm.Items[TargetField].Title = Item.Value;
		
	EndDo;
	
EndProcedure
