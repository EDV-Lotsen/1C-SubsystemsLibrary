
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
 
// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.	
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	UseSubordinateBusinessProcesses = GetFunctionalOption("UseSubordinateBusinessProcesses");
	UseDateAndTimeInTaskDeadlines = GetFunctionalOption("UseDateAndTimeInTaskDeadlines");
	
	If UseSubordinateBusinessProcesses Then
		Items.List.Visibility = False;
		Items.ListCommandBar.Visibility = False;
		Items.TaskTree.Visibility = True;
	Else	
		Items.List.Visibility = True;
		Items.ListCommandBar.Visibility = True;
		Items.TaskTree.Visibility = False;
	EndIf;	
		
	Title = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Task of %1 business process'"), String(Parameters.SelectValue));
 
	BusinessProcessesAndTasksServer.SetTaskAppearance(List);
		
	If UseSubordinateBusinessProcesses Then 
		FillTaskTree();
		Items.DueDate.Format = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	Else
 
	CommonUseClientServer.SetDynamicListFilterItem
(
	 List,"BusinessProcess", Parameters.SelectValue);
 
	CommonUseClientServer.SetDynamicListFilterItem
(
		List, "Executed", False);
	EndIf;
	
 
	CommonUseClientServer.SetDynamicListFilterItem
(
	   List, "DeletionMark", False, DataCompositionComparisonType.Equal, , ,
 
   DataCompositionSettingsItemViewMode.Normal);
	
 
	CommonUseClientServer.MoveFiltersToDynamicList(ThisObject);
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "Write_PerformerTask" 
Then
		RefreshTaskList();
	EndIf;
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer
(Settings)
	
	ShowExecuted = Settings
["ShowExecuted"];
	RefreshTaskList();

EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure ShowExecutedOnChanging(Item)
	
	RefreshTaskList();
	
EndProcedure

#EndRegion

#Region 
TaskTreeFormTableItemEventHandlers 

&AtClient
Procedure TaskTreeChoice(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	OpenCurrentTaskTreeRow();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Refresh(Command)
	
	FillTaskTree();
	For Each String In TaskTree.GetItems() Do
		Items.TaskTree.Expand(Row.GetID(), True);
	EndDo;
	
EndProcedure

&AtClient
Procedure Change(Command)
	
	OpenCurrentTaskTreeRow();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

 

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.TaskTree.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New 
DataCompositionField("TaskTree.Expired");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.OverdueDataColor);



	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.TaskTree.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("TaskTree.Executed");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.CompletedBusinessProcess);

EndProcedure

&AtServer
Procedure RefreshTaskList()
	
	UseSubordinateBusinessProcesses = GetFunctionalOption("UseSubordinateBusinessProcesses");
	If UseSubordinateBusinessProcesses Then 
		FillTaskTree();
	Else
		CommonUseClientServer.DeleteDynamicListFilterCroupItems(List, "Executed");
		If Not ShowExecuted Then
 
			CommonUseClientServer.SetDynamicListFilterItem(
				List, "Executed", False);
		EndIf;
		BusinessProcessesAndTasksServer.SetTaskAppearance(List);
		Items.List.Refresh();
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenCurrentTaskTreeRow()
	
	If Items.TaskTree.CurrentData = Undefined Then
		Return;
	EndIf;
	
	ShowValue(,Items.TaskTree.CurrentData.Ref);
	
EndProcedure

&AtServer
Procedure FillTaskTree()
	
	Tree = FormAttributeToValue("TaskTree");
	Tree.Rows.Clear();
	
	AddSubordinateBusinessProcessTasks(Tree, Parameters.SelectValue);
	
	ValueToFormAttribute(Tree, "TaskTree");
	
EndProcedure	

&AtServer
Procedure AddSubordinateBusinessProcesses(Tree, TaskRef)
	
	Branch = Tree.Rows.Find(TaskRef, "Ref", True);
	
	For Each BusinessProcessMetadata In Metadata.BusinessProcesses Do
		
		// The business process can have no main task
		MainTaskAttribute = BusinessProcessMetadata.Attributes.Find("MainTask");
		If MainTaskAttribute = Undefined Then
			Continue;
		EndIf;	
			
		Query = New Query;
		Query.Text = 
			"SELECT ALLOWED
			|	BusinessProcesses.Ref,
			|	BusinessProcesses.Description,
			|	BusinessProcesses.Completed,
			|	CASE
			|		WHEN BusinessProcesses.Importance = VALUE(Enum.TaskImportanceVariants.Low)
			|			THEN 0
			|		WHEN BusinessProcesses.Importance = VALUE(Enum.TaskImportanceVariants.High)
			|			THEN 2
			|		ELSE 1
			|	END AS Importance,
			|	CASE
			|		WHEN BusinessProcesses.State = VALUE(Enum.BusinessProcessStates.Stopped)
			|			THEN True
			|		ELSE False
			|	END AS Stopped
			|FROM
			|	%BusinessProcess% AS BusinessProcesses
			|WHERE
			|   BusinessProcesses.MainTask = &MainTask
			|   AND BusinessProcesses.DeletionMark = False";
			
		Query.Text = StrReplace(Query.Text, "%BusinessProcess%", BusinessProcessMetadata.FullName());
		Query.SetParameter("MainTask", TaskRef);

		Result = Query.Execute();
		
		DetailedRecordSelection = Result.Select();

		While DetailedRecordSelection.Next() Do
			
			String = Branch.Rows.Add();
			
			Row.Description = DetailedRecordSelection.Description;
			Row.Importance = DetailedRecordSelection.Importance;
			Row.Stopped = DetailedRecordSelection.Stopped;
			Row.Ref = DetailedRecordSelection.Ref;
			Row.Executed = DetailedRecordSelection.Completed;
			Row.Type = 0;
			
			AddSubordinateBusinessProcessTasks(Tree, DetailedRecordSelection.Ref);
			
		EndDo;
		
	EndDo;	

EndProcedure

&AtServer
Procedure AddSubordinateBusinessProcessTasks(Tree, BusinessProcessRef)
	
	Branch = Tree.Rows.Find(BusinessProcessRef, "Ref", True);
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	Tasks.Ref,
		|	Tasks.Description,
		|	Tasks.Performer,
		|	Tasks.PerformerRole,
		|	Tasks.DueDate,
		|	Tasks.Executed,
		|	CASE
		|		WHEN Tasks.Importance = VALUE(Enum.TaskImportanceVariants.Low)
		|			THEN 0
		|		WHEN Tasks.Importance = VALUE(Enum.TaskImportanceVariants.High)
		|			THEN 2
		|		ELSE 1
		|	END AS Importance,
		|	CASE
		|		WHEN Tasks.BusinessProcessState = VALUE(Enum.BusinessProcessStates.Stopped)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS Stopped
		|FROM
		|	Task.PerformerTask AS Tasks
		|WHERE
		|	Tasks.BusinessProcess = &BusinessProcess
		|	AND Tasks.DeletionMark = FALSE";
	If Not ShowExecuted Then	
		Query.Text = Query.Text + "
			|	And tasks.Executed = &Executed";
		Query.SetParameter("Executed", False);
	EndIf;	
	Query.SetParameter("BusinessProcess", BusinessProcessRef);

	Result = Query.Execute();
	
	DetailedRecordSelection = Result.Select();

	While DetailedRecordSelection.Next() Do
		
		String = Undefined;
		If Branch = Undefined Then
			String = Tree.Rows.Add();
		Else	
			String = Branch.Rows.Add();
		EndIf;
		
		Row.Description = DetailedRecordSelection.Description;
		Row.Importance = DetailedRecordSelection.Importance;
		Row.Type = 1;
		Row.Stopped = DetailedRecordSelection.Stopped;
		Row.Ref = DetailedRecordSelection.Ref;
		Row.DueDate = DetailedRecordSelection.DueDate;
		Row.Executed = DetailedRecordSelection.Executed;
		If DetailedRecordSelection.DueDate <> '00010101000000'
			 And DetailedRecordSelection.DueDate < CurrentSessionDate() 
Then
			Row.Expired = True;
		EndIf;				
		If DetailedRecordSelection.Performer.IsEmpty() Then
			Row.Performer = DetailedRecordSelection.PerformerRole;
		Else	
			Row.Performer = DetailedRecordSelection.Performer;
		EndIf;	
		
		AddSubordinateBusinessProcesses(Tree, DetailedRecordSelection.Ref);
		
	EndDo;
	
EndProcedure

#EndRegion
