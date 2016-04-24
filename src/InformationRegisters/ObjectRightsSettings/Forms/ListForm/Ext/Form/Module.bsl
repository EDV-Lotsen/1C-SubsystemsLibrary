
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
 
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	Read = True;
	ReadOnly = True;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure EnableEditing(Command)
	
	ReadOnly = False;
	
EndProcedure

&AtClient
Procedure UpdateAuxiliaryRegisterData
(Command)
	
	HasChanges = False;
	
	UpdateAuxiliaryRegisterDataAtServer
(HasChanges);
	
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


	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ListTable.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("List.Table");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Catalogs.MetadataObjectIDs.EmptyRef();

	Item.Appearance.SetParameterValue("Text", NStr("en = 'All tables except the specified one.'"));

EndProcedure

&AtServer
Procedure UpdateAuxiliaryRegisterDataAtServer(HasChanges)
	
	SetPrivilegedMode(True);
	
	InformationRegisters.ObjectRightsSettings.UpdateAuxiliaryRegisterData(HasChanges);
	
	Items.List.Refresh();
	
EndProcedure

#EndRegion
