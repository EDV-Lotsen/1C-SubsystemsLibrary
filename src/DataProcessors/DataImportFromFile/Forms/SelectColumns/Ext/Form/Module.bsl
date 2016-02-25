#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	ColumnList = Parameters.ColumnList;
	ColumnList.SortByPresentation();
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Selection(Command)
	Close(ColumnList);
EndProcedure

#EndRegion

#Region SelectionTableElementEventHandlers

&AtClient
Procedure ColumnListSelection(Item, SelectedRow, Field, StandardProcessing)
	ColumnList.FindByID(SelectedRow).Check = Not ColumnList.FindByID(SelectedRow).Check;
EndProcedure

#EndRegion