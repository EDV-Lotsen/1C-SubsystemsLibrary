
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Autotest") Then // Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
		Return;
	EndIf;
	
	CommonUseClientServer.SetDynamicListFilterItem(Performers, 
		"PerformerRole", Parameters.PerformerRole, DataCompositionComparisonType.Equal);
	RoleProperties = CommonUse.ObjectAttributeValues(Parameters.PerformerRole, "UsedByAddressingObjects,AdditionalAddressingObjectTypes,MainAddressingObjectTypes");
	If RoleProperties.UsedByAddressingObjects Then
		GroupField = Performers.Grouping.Items.Add(Type("DataCompositionGroupField"));
		GroupField.Field = New DataCompositionField("MainAddressingObject");
		GroupField.Use = True;
		If Not RoleProperties.AdditionalAddressingObjectTypes.IsEmpty() Then
			GroupField = Performers.Grouping.Items.Add(Type("DataCompositionGroupField"));
			GroupField.Field = New DataCompositionField("AdditionalAddressingObject");
			GroupField.Use = True;
		EndIf;
	EndIf;
	
	CommonUseClientServer.MoveFiltersToDynamicList(ThisObject, Performers);
EndProcedure

#EndRegion
