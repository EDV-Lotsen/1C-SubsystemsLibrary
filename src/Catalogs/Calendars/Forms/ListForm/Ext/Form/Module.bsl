
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	If Parameters.ChoiceMode Then
		Items.List.ChoiceMode = True;
	EndIf;
	
	List.Parameters.SetParameterValue("CurrentDate", CurrentSessionDate());
	
	CommonUseClientServer.SetDynamicListFilterItem(
		List, "ScheduleOwner", , DataCompositionComparisonType.NotFilled, , ,
		DataCompositionSettingsItemViewMode.Normal);
	
	CommonUseClientServer.MoveFiltersToDynamicList(ThisObject);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ChangeSelected(Command)
	BatchObjectModificationClientModule = CommonUseClient.CommonModule("BatchObjectModificationClient");
	BatchObjectModificationClientModule.ChangeSelected(Items.List);
EndProcedure

#EndRegion
