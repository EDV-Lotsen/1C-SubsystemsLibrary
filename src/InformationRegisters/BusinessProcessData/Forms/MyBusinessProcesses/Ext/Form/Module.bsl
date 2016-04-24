
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
 
If Parameters.Property("Autotest") Then // Returning in obtaining form for analysis.
 	Return;
	EndIf;
	
	SetFilter(New Structure("ShowCompletedItems", ShowCompletedItems));
	CommonUseClientServer.SetDynamicListFilterItem
(
		List, "Author", 
Users.CurrentUser());
	BusinessProcessesAndTasksServer.SetBusinessProcessAppearance(List.ConditionalAppearance);
	
	CommonUseClientServer.MoveFiltersToDynamicList(ThisObject);
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "Write_PerformerTask" 
Then
		Items.List.Refresh();
	EndIf;
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer
(Settings)
	
	SetFilter(Settings);
		
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure ShowCompletedItemsOnChange
(Item)
	
	SetFilter(New Structure
("ShowCompletedItems", ShowCompletedItems));
	
EndProcedure

#EndRegion

#Region 
ListFormTableItemEventHandlers

&AtClient
Procedure ListChoice(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	If Items.List.CurrentData <> 
Undefined Then
		ShowValue(,Items.List.CurrentData.BusinessProcess);
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	If Item.CurrentData <> Undefined Then
		ShowValue
(,Item.CurrentData.BusinessProcess);
		Cancel = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure DeletionMark(Command)
	BusinessProcessesAndTasksClient.BusinessProcessListDeletionMark(Items.List);
EndProcedure

&AtClient
Procedure Flowchart(Command)
	If Items.List.CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpenForm("DataProcessor.BusinessProcessFlowchart.Form", 
		New Structure("BusinessProcess", Items.List.CurrentData.BusinessProcess));
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetFilter(FilterParameters)
	
	CommonUseClientServer.SetDynamicListFilterItem(
		List, "Completed", False,,, Not FilterParameters["ShowCompletedItems"]);
	
EndProcedure

#EndRegion
