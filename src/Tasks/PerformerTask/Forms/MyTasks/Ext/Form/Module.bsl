
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
 
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	BusinessProcessesAndTasksServer.SetMyTaskListParameters(List);
	FilterParameters = New Map();
	FilterParameters.Insert("ShowExecuted", ShowExecuted);
	SetFilter(FilterParameters);
	
	FormFilterParameters = CommonUseClientServer.CopyStructure(Parameters.Filter);
	Parameters.Filter.Clear();
	
	UseDateAndTimeInTaskDeadlines = GetFunctionalOption("UseDateAndTimeInTaskDeadlines");
	Items.DueDate.Format = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	Items.StartDate.Format = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	Items.Date.Format = ?
(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	
	BusinessProcessesAndTasksServer.SetTaskAppearance(List);
	
	CommonUseClientServer.SetDynamicListFilterItem(
		List, "DeletionMark", False, DataCompositionComparisonType.Equal, , ,
		DataCompositionSettingsItemViewMode.Normal);
	
	CommonUseClientServer.MoveFiltersToDynamicList(ThisObject);
EndProcedure

&AtServer
Procedure BeforeLoadDataFromSettingsAtServer(Settings)
	
	If FormFilterParameters <> Undefined Then
		// Moving the fixed selection items to inaccessible user settings
		For Each FilterItem In FormFilterParameters Do
 
			CommonUseClientServer.SetDynamicListFilterItem
(
				List, FilterItem.Key, 
FilterItem.Value);
		EndDo;
		
		SelectValue = Undefined;
		If FormFilterParameters.Property("Executed", SelectValue) Then
			Settings["ShowExecuted"] = SelectValue;
		EndIf;
		
		FormFilterParameters.Clear();
	EndIf;
	
	GroupByColumnAtServer(Settings["GroupMode"]);
	SetFilter(Settings);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "Write_PerformerTask" Then
		RefreshTaskListAtServer();
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure GroupByPriority(Command)
	GroupByColumn("Importance");
EndProcedure

&AtClient
Procedure GroupByNotGrouped(Command)
	GroupByColumn("");
EndProcedure

&AtClient
Procedure GroupByRoutePoint(Command)
	GroupByColumn("RoutePoint");
EndProcedure

&AtClient
Procedure GroupByAuthor(Command)
	GroupByColumn("Author");
EndProcedure

&AtClient
Procedure GroupBySubject(Command)
	GroupByColumn("SubjectString");
EndProcedure

&AtClient
Procedure GroupByDeadline(Command)
	GroupByColumn("GroupDeadline");
EndProcedure

&AtClient
Procedure ShowExecutedOnChange(Item)
	
	SetFilterOnClient();
	
EndProcedure

#EndRegion

#Region ListFormTableItemEventHandlers

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, Group)
	BusinessProcessesAndTasksClient.TaskListBeforeAddRow(ThisObject, Item, Cancel, Clone, 
		Parent, Group);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure AcceptForExecution(Command)
	
	BusinessProcessesAndTasksClient.AcceptTasksForExecution(Items.List.SelectedRows);
		
EndProcedure

&AtClient
Procedure CancelAcceptForExecution(Command)
	
	BusinessProcessesAndTasksClient.CancelAcceptTasksForExecution(Items.List.SelectedRows);
	
EndProcedure

&AtClient
Procedure RefreshTaskList(Command)
	
	RefreshTaskListAtServer();
	
EndProcedure

&AtClient
Procedure OpenBusinessProcess(Command)
	BusinessProcessesAndTasksClient.OpenBusinessProcess(Items.List);
EndProcedure

&AtClient
Procedure OpenTaskSubject(Command)
	BusinessProcessesAndTasksClient.OpenTaskSubject(Items.List);
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure GroupByColumn(Val AttributeColumnName)
	GroupMode = AttributeColumnName;
	If Not IsBlankString(GroupMode) Then
		ShowExecuted = False;
		SetFilterOnClient();
	EndIf;
	List.Grouping.Items.Clear();
	If Not IsBlankString(AttributeColumnName) Then
		GroupField = List.Grouping.Items.Add(Type("DataCompositionGroupField"));
		GroupField.Field = New DataCompositionField(AttributeColumnName);
	EndIf;
EndProcedure

&AtServer
Procedure GroupByColumnAtServer(Val AttributeColumnName)
	GroupMode = AttributeColumnName;
	If Not IsBlankString(GroupMode) Then
		ShowExecuted = False;
		FilterParameters = New Map();
		FilterParameters.Insert("ShowExecuted", ShowExecuted);	
		SetFilter(FilterParameters);	
	EndIf;
	List.Grouping.Items.Clear();
	If Not IsBlankString(AttributeColumnName) Then
		GroupField = List.Grouping.Items.Add(Type("DataCompositionGroupField"));
		GroupField.Field = New DataCompositionField(AttributeColumnName);
	EndIf;
EndProcedure

&AtClient
Procedure SetFilterOnClient()
	
	FilterParameters = New Map();
	FilterParameters.Insert("ShowExecuted", ShowExecuted);	
	SetFilter(FilterParameters);	
	
EndProcedure

&AtServer
Procedure SetFilter(FilterParameters)
	
	If FilterParameters["ShowExecuted"] Then
		GroupByColumnAtServer("");
	EndIf;
	
	CommonUseClientServer.SetDynamicListFilterItem(
		List, "Executed", False, , , Not FilterParameters["ShowExecuted"]);
		
EndProcedure

&AtServer
Procedure RefreshTaskListAtServer()
	
	BusinessProcessesAndTasksServer.SetMyTaskListParameters(List);
	BusinessProcessesAndTasksServer.SetTaskAppearance(List);
	Items.List.Refresh();
	
EndProcedure

#EndRegion