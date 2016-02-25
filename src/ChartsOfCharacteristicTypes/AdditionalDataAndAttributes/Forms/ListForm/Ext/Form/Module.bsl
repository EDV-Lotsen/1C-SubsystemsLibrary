
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardDataProcessor)

	// Skipping the initialization to guarantee that the form will be received if the autotest parameter is passed.	
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	CommonUseClientServer.SetDynamicListParameter(
		List,
		"CommonPropertyGroupingPresentation",
		NStr("en = 'Common (for several sets)'"),
		True);
	
	// Grouping properties to sets.
	DataGroup = List.SettingsComposer.Settings.Structure.Add(Type("DataCompositionGroup"));
	DataGroup.UserSettingID = "PropertiesBySetsGroup";
	DataGroup.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	GroupFields = DataGroup.GroupFields;
	
	DataGroupItem = GroupFields.Items.Add(Type("DataCompositionGroupField"));
	DataGroupItem.Field = New DataCompositionField("PropertySetGrouping");
	DataGroupItem.Use = True;
	
EndProcedure

#EndRegion
