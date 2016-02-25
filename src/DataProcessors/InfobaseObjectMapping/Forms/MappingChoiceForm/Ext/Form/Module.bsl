// The following form parameters are mandatory:
//
// ObjectToMap   - String - object description in the current infobase.
// Application1  - String - description of the correspondent infobase.
// Application2  - String - description of the current infobase.
//
// UsedFieldList - ValueList - fields for mapping: 
//     Value         - String - field name.
//     Presentation  - String - field description (title).
//     Mark          - Boolean - flag that shows whether a field is used in the mapping.
//
// MaxCustomFieldCount  - Number - maximum number of mapping fields.
//
// StartRowSerialNumber - Number - current row key in the input table.
//
// TempStorageAddress - String - address of the input table that stores the mapping. The table contains the following columns:
//     PictureIndex   - Number.
//     SerialNumber   - Number, unique row key. 
//     OrderField1    - String - the first attribute value from the list of mapping fields. 
//     ...
//     OrderFieldNN   - String - the last attribute value from the list of mapping fields.
//
// After the form opening, all data stored at TempStorageAddress is deleted from the temporary storage.
//

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
  // Skipping the initialization to guarantee that the form 
  // will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	ObjectToMap = Parameters.ObjectToMap;
	
	Items.ObjectToMap.Title = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Object in ""%1""'"), Parameters.Application1);
		
	Items.Header.Title = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Object in ""%1""'"), Parameters.Application2);
	
	// Generating choice table on the form
	GenerateChoiceTable (Parameters.MaxCustomFieldCount, Parameters.UsedFieldList, 
		Parameters.TempStorageAddress);
		
	SetChoiceTableCursor(Parameters.StartRowSerialNumber);
EndProcedure

#EndRegion

#Region ChoiceTableFormTableItemEventHandlers

&AtClient
Procedure ChoiceTableChoice(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;
	MakeSelection(SelectedRow);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Select(Command)
	MakeSelection(Items.ChoiceTable.CurrentRow);
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure MakeSelection(Val SelectedRowID)
	If SelectedRowID = Undefined Then
		Return;
	EndIf;
		
	ChoiceData = ChoiceTable.FindByID(SelectedRowID);
	If ChoiceData <> Undefined Then
		NotifyChoice(ChoiceData.SerialNumber);
	EndIf;
	
EndProcedure

&AtServer
Procedure GenerateChoiceTable (Val TotalFields, Val UsedFields, Val DataAddress)
	
	// Adding attribute columns
	ToAdd      = New Array;
	StringType = New TypeDescription("String");
	For FieldNumber = 1 To TotalFields Do
		ToAdd.Add(New FormAttribute("OrderField" + Format(FieldNumber, "NZ=; NG="), StringType, "ChoiceTable"));
	EndDo;
	ChangeAttributes(ToAdd);
	
	// Adding form items
	ColumnGroup = Items.GroupFields;
	ItemType    = Type("FormField");
	ListSize    = UsedFields.Count() - 1;
	
	For FieldNumber = 0 To TotalFields-1 Do
		Attribute = ToAdd[FieldNumber];
		
		NewColumn = Items.Add("ChoiceTable" + Attribute.Name, ItemType, ColumnGroup);
		NewColumn.DataPath = Attribute.Path + "." + Attribute.Name;
		If FieldNumber<=ListSize Then
			Field = UsedFields[FieldNumber];
			NewColumn.Visible = Field.Check;
			NewColumn.Title = Field.Presentation;
		Else
			NewColumn.Visible = False;
		EndIf;
	EndDo;
	
	// Filling the choice table and clearing data from the temporary storage
	If Not IsBlankString(DataAddress) Then
		ChoiceTable.Load( GetFromTempStorage(DataAddress) );
		DeleteFromTempStorage(DataAddress);
	EndIf;
EndProcedure

&AtServer
Procedure SetChoiceTableCursor(Val StartRowSerialNumber)
	
	For Each Row In ChoiceTable Do
		If Row.SerialNumber = StartRowSerialNumber Then
			Items.ChoiceTable.CurrentRow = Row.GetID();
			Break;
			
		ElsIf Row.SerialNumber > StartRowSerialNumber Then
			PreviousRowIndex = ChoiceTable.IndexOf(Row) - 1;
			If PreviousRowIndex > 0 Then
				Items.ChoiceTable.CurrentRow = ChoiceTable[PreviousRowIndex].GetID();
			EndIf;
			Break;
			
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion
