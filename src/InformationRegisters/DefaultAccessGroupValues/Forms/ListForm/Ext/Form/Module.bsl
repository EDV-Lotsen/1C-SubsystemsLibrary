
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	SetConditionalAppearance();
	
	ReadOnly = True;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure EnableEditing(Command)
	
	ReadOnly = False;
	
EndProcedure

&AtClient
Procedure UpdateRegisterData(Command)
	
	HasChanges = False;
	
	UpdateRegisterDataAtServer(HasChanges);
	
	If HasChanges Then
		Text = NStr("en = 'The update is completed.'");
	Else
		Text = NStr("en = 'No update required.'");
	EndIf;
	
	ShowMessageBox(, Text);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure UpdateRegisterDataAtServer(HasChanges)
	
	SetPrivilegedMode(True);
	
	InformationRegisters.AccessGroupValues.UpdateRegisterData(, HasChanges);
	
	Items.List.Refresh();
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	AccessValueTypes = Metadata.DefinedTypes.AccessValue.Type.Types();
	
	For Each Type In AccessValueTypes Do
		
		Types = New Array;
		Types.Add(Type);
		TypeDescription = New TypeDescription(Types);
		TypeEmptyRef = TypeDescription.AdjustValue(Undefined);
		
		// Appearance
		ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
		
		AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("Text");
		AppearanceColorItem.Value = String(Type);
		AppearanceColorItem.Use = True;
		
		DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		DataFilterItem.LeftValue        = New DataCompositionField("List.AccessValueType");
		DataFilterItem.ComparisonType   = DataCompositionComparisonType.Equal;
		DataFilterItem.RightValue       = TypeEmptyRef;
		DataFilterItem.Use              = True;
		
		FieldAppearanceItem = ConditionalAppearanceItem.Fields.Items.Add();
		FieldAppearanceItem.Field = New DataCompositionField(Items.ListAccessValueType.Name);
		FieldAppearanceItem.Use   = True;
	EndDo;
	
EndProcedure

#EndRegion
