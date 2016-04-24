
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	BusinessProcessesAndTasksServer.SetBusinessProcessAppearance(List.ConditionalAppearance);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "Write_PerformerTask" Then
		Items.List.Refresh();
	EndIf;
EndProcedure

#EndRegion

#Region ListFormTableItemEventHandlers

&AtClient
Procedure ListChoice(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	If Items.List.CurrentData <> Undefined Then
		ShowValue(,Items.List.CurrentData.BusinessProcess);
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	If Item.CurrentData <> Undefined Then
		ShowValue(,Item.CurrentData.BusinessProcess);
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
