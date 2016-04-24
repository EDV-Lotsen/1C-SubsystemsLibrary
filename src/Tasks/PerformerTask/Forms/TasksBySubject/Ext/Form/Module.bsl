
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
 
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	UseSubordinateBusinessProcesses = GetFunctionalOption("UseSubordinateBusinessProcesses");	
	
	If UseSubordinateBusinessProcesses Then
		Items.List.Visibility = False;
		Items.ListCommandBar.Visibility = False;
		Items.ShowExecuted.Visibility = False;
		Items.TaskTree.Visibility = True;
	Else	
		Items.List.Visibility = True;
		Items.ListCommandBar.Visibility = True;
		Items.ShowExecuted.Visibility = True;
		Items.TaskTree.Visibility = False;
	EndIf;	
	
	List.Parameters.Items[0].Value = Parameters.SelectValue;
	List.Parameters.Items[0].Use = True;
	Title = NStr("en = 'Tasks by subject'");
	UseDateAndTimeInTaskDeadlines = GetFunctionalOption("UseDateAndTimeInTaskDeadlines");
	Items.DueDate.Format = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
BusinessProcessesAndTasksServer.SetTaskAppearance(List);
	SetFilter(New Structure("ShowExecuted", ShowExecuted));
	
	If UseSubordinateBusinessProcesses Then 
		FillTaskTree();
	EndIf;
	
	// Setting dynamic list filter
 
	CommonUseClientServer.SetDynamicListFilterItem(
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
Procedure OnLoadDataFromSettingsAtServer(Settings)
	SetFilter(Settings);
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure ShowExecutedOnChange
(Item)
	SetFilter(New Structure("ShowExecuted", ShowExecuted));
EndProcedure

#EndRegion

#Region
TaskTreeFormTableItemEventHandlers

&AtClient
Procedure TaskTreeChoice(Item, 
SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	OpenTaskTreeCurrentRow();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Refresh(Command)
	
	RefreshTaskList();
	For each String 
FROM TaskTree.GetItems()
Do
		Items.TaskTree.Expand
(Row.GetID(), True);
	EndDo;
	
EndProcedure

&AtClient
Procedure Change(Command)
	
	OpenTaskTreeCurrentRow();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.TaskTree.Name);

 ItemFilter = Item.Filter.Items.Add
(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New 
DataCompositionField("TaskTree.Expired");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.OverdueDataColor);

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.TaskTree.Name);

	ItemFilter = Item.Filter.Items.Add
(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New 
DataCompositionField("TaskTree.Executed");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.CompletedBusinessProcess);

EndProcedure

&AtServer
Procedure SetFilter(FilterParameters)
	
	CommonUseClientServer.DeleteDynamicListFilterCroupItems(List, "Executed");
	If Not FilterParameters["ShowExecuted"] 
Then
 
		CommonUseClientServer.SetDynamicListFilterItem
( List, "Executed", False);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillTaskTree()
	
	Tree = FormAttributeToValue("TaskTree");
	Tree.Rows.Clear();
	
	AddTasksBySubject(Tree, Parameters.SelectValue);
	
	ValueToFormAttribute(Tree, "TaskTree");
	
EndProcedure	

&AtServer
Procedure RefreshTaskList()
	
	UseSubordinateBusinessProcesses = GetFunctionalOption("UseSubordinateBusinessProcesses");
	If UseSubordinateBusinessProcesses Then 
		FillTaskTree();
	Else
		BusinessProcessesAndTasksServer.SetTaskAppearance(List);
		Items.List.Refresh();
	EndIf;
	
EndProcedure

&AtServer
Procedure AddTasksBySubject(Tree, Subject)
	
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
		|			THEN True
		|		ELSE False
		|	END AS Stopped
		|FROM
		|	Task.PerformerTask AS Tasks
		|WHERE
		|   Tasks.Subject = &Subject
		|   AND Tasks.DeletionMark = False";
		
	Query.SetParameter("Subject", Subject);

	Result = Query.Execute();
	
	DetailedRecordSelection = Result.Select();

	While DetailedRecordSelection.Next() Do
		
		Branch = Tree.Rows.Find(DetailedRecordSelection.Ref, "Ref", True);
		If Branch = Undefined Then
			String = Tree.Rows.Add();
			
			Row.Description = DetailedRecordSelection.Description;
			Row.Importance = DetailedRecordSelection.Importance;
			Row.Type = 1;
			Row.Stopped = DetailedRecordSelection.Stopped;
			Row.Ref = DetailedRecordSelection.Ref;
			Row.DueDate = DetailedRecordSelection.DueDate;
			Row.Executed = DetailedRecordSelection.Executed;
			If DetailedRecordSelection.DueDate <> "00010101" 
				And DetailedRecordSelection.DueDate < CurrentSessionDate() Then
				Row.Expired = True;
			EndIf;				
			If DetailedRecordSelection.Performer.IsEmpty() Then
				Row.Performer = DetailedRecordSelection.PerformerRole;
			Else	
				Row.Performer = DetailedRecordSelection.Performer;
			EndIf;	
			
			AddSubordinateBusinessProcesses(Tree, DetailedRecordSelection.Ref);
		EndIf;	
		
	EndDo;
	
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
			|   BusinessProcesses.MainTask = 
&MainTask
			|   AND BusinessProcesses.DeletionMark = False";
			
		Query.Text = StrReplace(Query.Text, "%BusinessProcess%", BusinessProcessMetadata.FullName());
		Query.SetParameter("MainTask", TaskRef);

		Result = Query.Execute();
		
		DetailedRecordSelection = Result.Select();

		While DetailedRecordSelection.Next() Do
			
			AddSubordinateBusinessProcessTasks(Tree, DetailedRecordSelection.Ref, TaskRef);
			
		EndDo;
		
	EndDo;	

EndProcedure

&AtServer
Procedure AddSubordinateBusinessProcessTasks(Tree, BusinessProcessRef, TaskRef)
	
	Branch = Tree.Rows.Find(TaskRef, "Ref", True);
	
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
		|			THEN True
		|		ELSE False
		|	END AS Stopped
		|FROM
		|	Task.PerformerTask AS Tasks
		|WHERE
		|   Tasks.BusinessProcess = &BusinessProcess
		|   AND Tasks.DeletionMark = False";
		
	Query.SetParameter("BusinessProcess", BusinessProcessRef);

	Result = Query.Execute();
	
	DetailedRecordSelection = Result.Select();

	While DetailedRecordSelection.Next() Do
		
		FoundBranch = Tree.Rows.Find(DetailedRecordSelection.Ref, "Ref", True);
		If FoundBranch <> Undefined Then
			Tree.Rows.Delete(FoundBranch);
		EndIf;	
			
		String = Undefined;
		If Branch = Undefined Then
			String = Tree.Rows.Add();
		Else	
			String = Branch.Rows.Add();
		EndIf;
		
		Row.Description = DetailedRecordSelection.Description;
		Row.Importance = DetailedRecordSelection.Importance;
		Row.Type = 1;
		Row.Stopped = 
DetailedRecordSelection.Stopped;
		Row.Ref = DetailedRecordSelection.Ref;
		Row.DueDate = DetailedRecordSelection.DueDate;
		Row.Executed = DetailedRecordSelection.Executed;
		If DetailedRecordSelection.DueDate <> '00010101000000' 
			And DetailedRecordSelection.DueDate < CurrentSessionDate() Then
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

&AtClient
Procedure OpenTaskTreeCurrentRow()
	
	If Items.TaskTree.CurrentData = 
Undefined Then
		Return;
	EndIf;
	
	ShowValue
(,Items.TaskTree.CurrentData.Ref);
	
EndProcedure

#EndRegion
