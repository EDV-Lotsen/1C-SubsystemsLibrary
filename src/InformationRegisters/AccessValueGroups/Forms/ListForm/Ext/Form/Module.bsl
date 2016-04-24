
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
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
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	ApplyDataGroupAppearance(0, NStr("en = 'Standard access values'"));
	ApplyDataGroupAppearance(1, NStr("en = 'Regular/external users'"));
	ApplyDataGroupAppearance(2, NStr("en = 'Regular/external user groups'"));
	ApplyDataGroupAppearance(3, NStr("en = 'Performer groups'"));
	ApplyDataGroupAppearance(4, NStr("en = 'Authorization objects'"));
	
EndProcedure

&AtServer
Procedure ApplyDataGroupAppearance(DataGroup, Text)
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.DataGroupList.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("List.DataGroup");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = DataGroup;
	
	Item.Appearance.SetParameterValue("Text", Text);
	
EndProcedure

&AtServer
Procedure UpdateRegisterDataAtServer(HasChanges)
	
	SetPrivilegedMode(True);
	
	InformationRegisters.AccessValueGroups.UpdateRegisterData(HasChanges);
	
	Items.List.Refresh();
	
EndProcedure

#EndRegion
