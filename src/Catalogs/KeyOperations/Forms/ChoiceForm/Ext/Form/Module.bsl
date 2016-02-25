#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	CommonUseClientServer.SetFilterItem(
		List.Filter,
		"Ref",
		Parameters.Filter,
		DataCompositionComparisonType.NotInList
	);
	
	CommonUseClientServer.SetFilterItem(
		List.Filter,
		"DeletionMark",
		False,
		DataCompositionComparisonType.Equal
	);
	
EndProcedure

#EndRegion

#Region ListFormTableItemEventHandlers

&AtClient
Procedure ListChoice(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	ChoiceResult = Undefined;
	CD = Items.List.CurrentData;
	If CD <> Undefined Then
		ChoiceResult = New Structure("KeyOperation, Priority, TargetTime");
		ChoiceResult.KeyOperation = CD.Ref;
		ChoiceResult.Priority     = CD.Priority;
		ChoiceResult.TargetTime   = CD.TargetTime;
	EndIf;
	
	NotifyChoice(ChoiceResult);
	
EndProcedure

#EndRegion
