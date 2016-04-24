
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	 
  // Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;

	If Not CommonUse.OnCreateAtServer(ThisObject, Cancel, StandardProcessing) Then
		Return;
	EndIf;
	
	BusinessProcessesAndTasksServer.SetMyTaskListParameters(List);
	CommonUseClientServer.SetDynamicListFilterItem(
		List, "Executed", False);
			
	UseDateAndTimeInTaskDeadlines = GetFunctionalOption("UseDateAndTimeInTaskDeadlines");
	Items.DueDate.Format = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	Items.StartDate.Format = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	Items.Date.Format = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	
	BusinessProcessesAndTasksServer.SetTaskAppearance(List);
	
	// Setting dynamic list filter.
	CommonUseClientServer.SetDynamicListFilterItem(
		List, "DeletionMark", False, DataCompositionComparisonType.Equal, , ,
		DataCompositionSettingsItemViewMode.Normal);
	
	CommonUseClientServer.MoveFiltersToDynamicList(ThisObject);
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	GroupByColumnAtServer(Settings["GroupMode"]);
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "Write_PerformerTask" Then
		RefreshTaskListAtServer();
	EndIf;
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
Procedure OpenBusinessProcess(Command)
	BusinessProcessesAndTasksClient.OpenBusinessProcess(Items.List);
EndProcedure

&AtClient
Procedure OpenTaskSubject(Command)
	BusinessProcessesAndTasksClient.OpenTaskSubject(Items.List);
EndProcedure

&AtClient
Procedure GroupByPriority(Command)
	GroupByColumn("Importance");
EndProcedure

&AtClient
Procedure GroupByWithoutGrouping(Command)
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

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();

	Item = ConditionalAppearance.Items.Add();

	BottomLineItems = New Array();
	SelectAllChildItems(Items.BottomLine, BottomLineItems);
	For Each FormItem In BottomLineItems Do
		
		ItemField = Item.Fields.Items.Add();
		ItemField.Field = New DataCompositionField(FormItem.Name);
		
	EndDo;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("List.Ref");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;

	Item.Appearance.SetParameterValue("Visibility", False);
	
EndProcedure

&AtServer
Procedure SelectAllChildItems(Parent, Result)
	
	For Each FormItem In Parent.ChildItems Do
		
		Result.Add(FormItem);
		If TypeOf(FormItem) = Type("FormGroup") Then
			SelectAllChildItems(FormItem, Result); 
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure GroupByColumn(Val AttributeColumnName)
	GroupMode = AttributeColumnName;
	List.Grouping.Items.Clear();
	If Not IsBlankString(AttributeColumnName) Then
		GroupField = List.Grouping.Items.Add(Type("DataCompositionGroupField"));
		GroupField.Field = New DataCompositionField(AttributeColumnName);
	EndIf;
EndProcedure

&AtServer
Procedure GroupByColumnAtServer(Val AttributeColumnName)
	GroupMode = AttributeColumnName;
	List.Grouping.Items.Clear();
	If Not IsBlankString(AttributeColumnName) Then
		GroupField = List.Grouping.Items.Add(Type("DataCompositionGroupField"));
		GroupField.Field = New DataCompositionField(AttributeColumnName);
	EndIf;
EndProcedure

&AtServer
Procedure RefreshTaskListAtServer()
	
	BusinessProcessesAndTasksServer.SetMyTaskListParameters(List);
	BusinessProcessesAndTasksServer.SetTaskAppearance(List);
	Items.List.Refresh();
	
EndProcedure

#EndRegion
