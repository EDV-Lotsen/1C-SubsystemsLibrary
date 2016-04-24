
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

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.AdjustmentList.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("List.IsTableRightCheck");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("List.Adjustment");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Catalogs.MetadataObjectIDs.EmptyRef();

	Item.Appearance.SetParameterValue("Text", NStr("en = 'Check the Read right'"));
	Item.Appearance.SetParameterValue("Text", NStr("en = 'Check the Change right'"));

EndProcedure

#EndRegion
