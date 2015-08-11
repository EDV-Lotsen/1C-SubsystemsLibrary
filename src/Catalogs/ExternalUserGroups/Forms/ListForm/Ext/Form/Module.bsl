 
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.ChoiceMode Then
		
		Items.List.ChoiceMode = True;
		// Filter of items not marked for deletion
		FilterItem = List.Filter.Items.Add(Type("DataCompositionFilterItem"));
		FilterItem.Use = True;
		FilterItem.LeftValue = New DataCompositionField("DeletionMark");
		FilterItem.RightValue = False;
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		
		FilterItem = List.Filter.Items.Add(Type("DataCompositionFilterItem"));
		FilterItem.Use = True;
		FilterItem.LeftValue = New DataCompositionField("Ref");
		FilterItem.RightValue = New Array;
		FilterItem.RightValue.Add(Catalogs.ExternalUserGroups.AllExternalUsers);
		FilterItem.ComparisonType = DataCompositionComparisonType.NotInList;
		FilterItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		
		If Parameters.CloseOnChoice = False Then
			// Selection mode
			Title = NStr("en='Pick up of the groups of external users'");
			Items.List.MultipleChoice = True;
			Items.List.SelectionMode = TableSelectionMode.MultiRow;
		Else
			Title = NStr("en='Select group of external users'");
		EndIf;
	EndIf;
	
EndProcedure
