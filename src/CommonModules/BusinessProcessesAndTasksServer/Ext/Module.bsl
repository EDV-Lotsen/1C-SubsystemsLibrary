////////////////////////////////////////////////////////////////////////////////
// Business processes and tasks subsystem
//  
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Initializes common parameters of the task execution form.
//
// Parameters:
//  BusinessProcessTaskForm  - ManagedForm - task execution form.
//  TaskObject               - TaskObject  - task object.
//  ConditionGroupItem       - form control item - group with information on
//                                             task status.
//  CompletionDateItem       - form control item - field with the task completion date. 
//
Procedure TaskFormOnCreateAtServer(BusinessProcessTaskForm, TaskObject, 
	ConditionGroupItem, ComplitionDateItem) Export
	
	BusinessProcessTaskForm.ReadOnly = TaskObject.Executed;

	ConditionGroupItem.Visibility = TaskObject.Executed;
	If TaskObject.Executed Then
		Parent = ?(ConditionGroupItem <> Undefined, ConditionGroupItem, BusinessProcessTaskForm);
		Item = BusinessProcessTaskForm.Items.Find("__TaskStatePicture");
		If Item = Undefined Then
			Item = BusinessProcessTaskForm.Items.Add("__TaskStatePicture", Type("FormDecoration"), Parent);
			Item.Kind = FormDecorationType.Picture;
			Item.Picture = PictureLib.Information;
			Item.Height = 1;
			Item.Width = 2;
		EndIf;
		
		Item = BusinessProcessTaskForm.Items.Find("__TaskCondition");
		If Item = Undefined Then
			Item = BusinessProcessTaskForm.Items.Add("__TaskCondition", Type("FormDecoration"), Parent);
			Item.Kind = FormDecorationType.Label;
			Item.Height = 0; // Auto height
		EndIf;
		UseDateAndTimeInTaskDeadlines = GetFunctionalOption("UseDateAndTimeInTaskDeadlines");
		CompletionDateString = ?(UseDateAndTimeInTaskDeadlines, 
			Format(TaskObject.CompletionDate, "DLF=DT"), Format(TaskObject.CompletionDate, "DLF=D"));
		Item.Title = 
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en ='The task is executed on %1 by user %2.'"),
				CompletionDateString, 
				PerformerString(TaskObject.Performer, TaskObject.PerformerRole,
				TaskObject.MainAddressingObject, TaskObject.AdditionalAddressingObject));
	EndIf;
	
	If BusinessProcessesAndTasksServerCall.IsHeadTask(TaskObject.Ref) Then
		Parent = ?(ConditionGroupItem <> Undefined, ConditionGroupItem, BusinessProcessTaskForm);
		Item = BusinessProcessTaskForm.Items.Find("__HeadTaskPicture");
		If Item = Undefined Then
			Item = BusinessProcessTaskForm.Items.Add("__HeadTaskPicture", Type("FormDecoration"), Parent);
			Item.Kind = FormDecorationType.Picture;
			Item.Picture = PictureLib.Information;
			Item.Height = 1;
			Item.Width = 2;
		EndIf;
		
		Item = BusinessProcessTaskForm.Items.Find("__HeadTask");
		If Item = Undefined Then
			Item = BusinessProcessTaskForm.Items.Add("__HeadTask", Type("FormDecoration"), Parent);
			Item.Kind = FormDecorationType.Label;
			Item.Title = NStr("en ='This is the head task for nested business processes.'");
			Item.Height = 0; // Auto height
		EndIf;
	EndIf;	
	
EndProcedure             

// The procedure is called when creating a task list form on the server.
//
// Parameters:
//  ConditionalTaskListAppearance - ConditionalAppearance - conditional appearance of a task list.
//
Procedure SetTaskAppearance(Val TaskListsOrItsConditionalAppearance) Export
	
	If TypeOf(TaskListsOrItsConditionalAppearance) = Type("DynamicList") Then
		ConditionalTaskListAppearance = TaskListsOrItsConditionalAppearance.SettingsComposer.Settings.ConditionalAppearance;
		ConditionalTaskListAppearance.UserSettingID = "MainAppearance";
	Else
		ConditionalTaskListAppearance = TaskListsOrItsConditionalAppearance;
	EndIf;
	
	// Deleting preset appearance
	Preset = New Array;
	Items = ConditionalTaskListAppearance.Items;
	For Each ConditionalAppearanceItem In Items Do
		If ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible Then
			Preset.Add(ConditionalAppearanceItem);
		EndIf;
	EndDo;
	For Each ConditionalAppearanceItem In Preset Do
		Items.Delete(ConditionalAppearanceItem);
	EndDo;
		
	// Setting appearance for overdue tasks
	ConditionalAppearanceItem = ConditionalTaskListAppearance.Items.Add();
	ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField("DueDate");
	DataFilterItem.ComparisonType = DataCompositionComparisonType.Filled;
	DataFilterItem.Use = True;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField("DueDate");
	DataFilterItem.ComparisonType = DataCompositionComparisonType.Less;
	DataFilterItem.RightValue = CurrentSessionDate();
	DataFilterItem.Use = True;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField("Executed");
	DataFilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = False;
	DataFilterItem.Use = True;
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("TextColor");
	AppearanceColorItem.Value =  Metadata.StyleItems.OverdueDataColor.Value;   
	AppearanceColorItem.Use = True;
	
	// Setting appearance for completed tasks
	ConditionalAppearanceItem = ConditionalTaskListAppearance.Items.Add();
	ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField("Executed");
	DataFilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = True;
	DataFilterItem.Use = True;
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("TextColor");
	AppearanceColorItem.Value = Metadata.StyleItems.FinishedTask.Value; 
	AppearanceColorItem.Use = True;
	
	// Setting appearance for tasks that are not accepted for execution
	ConditionalAppearanceItem = ConditionalTaskListAppearance.Items.Add();
	ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField("AcceptedForExecution");
	DataFilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = False;
	DataFilterItem.Use = True;
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("Font");
	AppearanceColorItem.Value = Metadata.StyleItems.NotAcceptedForExecutionTasks.Value; 
	AppearanceColorItem.Use = True;
	
	// Setting appearance for tasks with unfilled "Due date" field 
	ConditionalAppearanceItem = ConditionalTaskListAppearance.Items.Add();
	ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	AppearanceField = ConditionalAppearanceItem.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("DueDate");
	AppearanceField.Use = True;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField("DueDate");
	DataFilterItem.ComparisonType = DataCompositionComparisonType.NotFilled;
	DataFilterItem.RightValue = True;
	DataFilterItem.Use = True;
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("TextColor");
	AppearanceColorItem.Value = Metadata.StyleItems.InaccessibleCellTextColor.Value;
	AppearanceColorItem.Use = True;
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("Text");
	AppearanceColorItem.Value = NStr("en = 'Due date is not specified'");
	AppearanceColorItem.Use = True;
	
EndProcedure

// The procedure is called when creating a list of business processes on the server.
//
// Parameters:
//  BusinessProcessesConditionalAppearance - ConditionalAppearance - conditional appearance of a business-process list.
//
Procedure SetBusinessProcessAppearance(Val BusinessProcessesConditionalAppearance) Export
	
	// Description is not specified
	ConditionalAppearanceItem = BusinessProcessesConditionalAppearance.Items.Add();
	ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	AppearanceField = ConditionalAppearanceItem.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("Description");
	AppearanceField.Use = True;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField("Description");
	DataFilterItem.ComparisonType = DataCompositionComparisonType.NotFilled;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleDataColor);
	ConditionalAppearanceItem.Appearance.SetParameterValue("Text", NStr("en = 'No description'"));
	
	// Completed business process
	ConditionalAppearanceItem = BusinessProcessesConditionalAppearance.Items.Add();
	ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField("Completed");
	DataFilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = True;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", StyleColors.CompletedBusinessProcess);
	
EndProcedure

// Returns the string presentation of the task's Performer, or the performer
// specified in PerformerRole, MainAddressingObject, or AdditionalAddressingObject parameter.
//
// Parameters:
//  Performer     - UserRef - task performer.
//  PerformerRole - Catalogs.PerformerRoles  - role.
//  MainAddressingObject, AdditionalAddressingObject - arbitrary reference type.
//
// Returns:
//   String. 
//
Function PerformerString(Val Performer, Val PerformerRole,
	Val MainAddressingObject = Undefined, Val AdditionalAddressingObject = Undefined) Export
	
	If Not Performer.IsEmpty() Then
		Return String(Performer)
	ElsIf Not PerformerRole.IsEmpty() Then
		Return RoleString(PerformerRole, MainAddressingObject, AdditionalAddressingObject);
	EndIf;
	Return NStr("en = 'Not specified'");

EndFunction

// Returns the string presentation of PerformerRole role.
//
// Parameters:
//  PerformerRole - Catalogs.PerformerRoles  - role.
//  MainAddressingObject, AdditionalAddressingObject - arbitrary reference type.
//
// Returns:
//   String. 
//
Function RoleString(Val PerformerRole,
	Val MainAddressingObject = Undefined, Val AdditionalAddressingObject = Undefined) Export
	
	If Not PerformerRole.IsEmpty() Then
		Result = String(PerformerRole);
		If MainAddressingObject <> Undefined Then
			Result = Result + " (" + String(MainAddressingObject);
			If AdditionalAddressingObject <> Undefined Then
				Result = Result + " ," + String(AdditionalAddressingObject);
			EndIf;
			Result = Result + ")";
		EndIf;
		Return Result;
	EndIf;
	Return NStr("en = 'Not specified'");

EndFunction

// Marks the tasks belonging to BusinessProcessRef business process for deletion.
//
// Parameters:
//  BusinessProcessRef - business process.
//  DeletionMark - Boolean - DeletionMark property value.
//
Procedure SetTaskDeletionMarks(BusinessProcessRef, DeletionMark) Export
	
	BeginTransaction();
	Try
		DataLock = New DataLock;
		LockItem = DataLock.Add("Task.PerformerTask");
		LockItem.SetValue("BusinessProcess", BusinessProcessRef);
		DataLock.Lock();
		
		Query = New Query("SELECT
			|	Tasks.Ref AS Ref 
			|FROM
			|	Task.PerformerTask AS Tasks
			|WHERE
			|	Tasks.BusinessProcess = &BusinessProcess");
		Query.SetParameter("BusinessProcess", BusinessProcessRef);
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			TaskObject = Selection.Ref.GetObject();
			TaskObject.SetDeletionMark(DeletionMark);
		EndDo;	
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(EventLogMessageText(), EventLogLevel.Error, 
			BusinessProcessRef.Metadata(), BusinessProcessRef, DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure	

// Sets the view and edit format for a form field of Date type
// based on the subsystem settings.
//
// Parameters:
//  DateField - form control, field with a value of Date type.
//
Procedure SetDateFormat(DateField) Export
	
	UseDateAndTimeInTaskDeadlines = GetFunctionalOption("UseDateAndTimeInTaskDeadlines");
	FormatString = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	If DateField.Kind = FormFieldType.InputField Then
		DateField.EditFormat = FormatString;
	Else	
		DateField.Format	 = FormatString;
	EndIf;	
	DateField.Width = ?(UseDateAndTimeInTaskDeadlines, 0, 8);
	
EndProcedure		

// Gets the business processes of the head TaskRef task.
//
// Parameters:
//   TaskRef   - TaskRef.PerformerTask - task.
//   ForChange - Boolean - If True, sets an exclusive managed lock for all business processes
//                         of the specified head task. The default value is False.
// Returns:
//    Array  - array of business processes.
// 
Function HeadTaskBusinessProcesses(TaskRef, ForChange = False) Export
	
	Result = SelectHeadTaskBusinessProcesses(TaskRef, ForChange);
	Return Result.Unload().UnloadColumn("Ref");
		
EndFunction	

// Returns the business process completion date,
// which is received as the maximum completion date for business process tasks.
//
// Parameters:
//  BusinessProcessRef  - business process.
//
// Returns:
//   Date. 
//
Function BusinessProcessCompletionDate(BusinessProcessRef) Export 
	
	VerifyAccessRights("Read", BusinessProcessRef.Metadata());
	SetPrivilegedMode(True);
	Query = New Query;
	Query.Text = 
		"SELECT
		|	MAX(PerformerTask.CompletionDate) AS MaxCompletionDate
		|FROM
		|	Task.PerformerTask AS PerformerTask
		|WHERE
		|	PerformerTask.BusinessProcess = &BusinessProcess
		|	AND PerformerTask.Executed = TRUE";
	Query.SetParameter("BusinessProcess", BusinessProcessRef);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then 
		Return CurrentSessionDate();
	EndIf;	
	
	Selection = Result.Select();
	Selection.Next();
	Return Selection.MaxCompletionDate;
	
EndFunction	

// Returns the array of business processes subordinate to the specified task.
//
// Parameters:
//  TaskRef   - TaskRef.PerformerTask - task.
//  ForChange - Boolean - if True, sets an exclusive managed lock to all subordinate
//                        business processes. The default value is False.
//
// Returns:
//   Array - array of references to business processes.
//
Function MainTaskBusinessProcesses(TaskRef, ForChange = False) Export
	
	Result = New Array;
	For Each BusinessProcessMetadata In Metadata.BusinessProcesses Do
		
		// Business processes are not required to have a main task.
		MainTaskAttribute = BusinessProcessMetadata.Attributes.Find("MainTask");
		If MainTaskAttribute = Undefined Then
			Continue;
		EndIf;	
			
		If ForChange Then
			DataLock = New DataLock;
			LockItem = DataLock.Add(BusinessProcessMetadata.FullName());
			LockItem.SetValue("MainTask", TaskRef);
			DataLock.Lock();
		EndIf;
		
		QueryText = StringFunctionsClientServer.SubstituteParametersInString(
			"SELECT ALLOWED
			|	%1.Ref AS Ref
			|FROM
			|	%2 AS %1
			|WHERE
			|	%1.MainTask = &MainTask", BusinessProcessMetadata.Name, BusinessProcessMetadata.FullName());
		Query = New Query(QueryText);
		Query.SetParameter("MainTask", TaskRef);
		
		QueryResult = Query.Execute();
		Selection = QueryResult.Select();
		While Selection.Next() Do
			Result.Add(Selection.Ref);
		EndDo;
			
	EndDo;	
	
	Return Result;
		
EndFunction	

// Checks if the current user has enough rights to change the business-process state.
//
// Parameters:
//  BusinessProcessObject  - business-process object.
//
Procedure ValidateRightsToUpdateBusinessProcessState(BusinessProcessObject) Export
	
	If Not ValueIsFilled(BusinessProcessObject.State) Then 
		BusinessProcessObject.State = Enums.BusinessProcessStates.Active;
	EndIf;
	
	If BusinessProcessObject.IsNew() Then
		PreviousCondition = Enums.BusinessProcessStates.Active;
	Else
		PreviousCondition = CommonUse.ObjectAttributeValue(BusinessProcessObject.Ref, "State");
	EndIf;
	
	If PreviousCondition <> BusinessProcessObject.State Then
		
		If Not HasStopBusinessProcessRights(BusinessProcessObject) Then 
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Insufficient rights for stopping business process ""%1"".'"),
				String(BusinessProcessObject));
			Raise MessageText;
		EndIf;
		
		If PreviousCondition = Enums.BusinessProcessStates.Active Then
			
			If BusinessProcessObject.Completed Then
				Raise NStr("en = 'Cannot stop the completed business processes.'");
			EndIf;
				
			If Not BusinessProcessObject.Started Then
				Raise NStr("en = 'Cannot stop the business processes that are not started yet.'");
			EndIf;
			
		ElsIf PreviousCondition = Enums.BusinessProcessStates.Stopped Then
			
			If BusinessProcessObject.Completed Then
				Raise NStr("en = 'Cannot activate the completed business processes.'");
			EndIf;
				
			If Not BusinessProcessObject.Started Then
				Raise NStr("en = 'Cannot activate the business processes that are not started yet.'");
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Sets an exclusive managed lock to the passed array of business processes.
//
// Parameters:
//   BusinessProcesses - Array - array of business process references, or a single business process reference.
//
Procedure LockBusinessProcesses(BusinessProcesses) Export
	
	DataLock = New DataLock;
	If TypeOf(BusinessProcesses) = Type("Array") Then
		For Each BusinessProcess In BusinessProcesses Do
			
			If TypeOf(BusinessProcess) = Type("DynamicalListGroupRow") Then
				Continue;
			EndIf;	
			
			LockItem = DataLock.Add(BusinessProcess.Metadata().FullName());
			LockItem.SetValue("Ref", BusinessProcess);
		EndDo;
	Else	
		If TypeOf(BusinessProcesses) = Type("DynamicalListGroupRow") Then
			Return;
		EndIf;	
		LockItem = DataLock.Add(BusinessProcesses.Metadata().FullName());
		LockItem.SetValue("Ref", BusinessProcesses);
	EndIf;
	DataLock.Lock();
	
EndProcedure	

// Sets an exclusive managed lock to the passed array of tasks.
//
// Parameters:
//   Tasks - Array  - array of task references, or a single TaskRef.PerformerTask reference.
//
Procedure LockTasks(Tasks) Export
	
	DataLock = New DataLock;
	If TypeOf(Tasks) = Type("Array") Then
		For Each Task In Tasks Do
			
			If TypeOf(Task) = Type("DynamicalListGroupRow") Then 
				Continue;
			EndIf;
			
			LockItem = DataLock.Add("Task.PerformerTask");
			LockItem.SetValue("Ref", Task);
		EndDo;
	Else	
		If TypeOf(BusinessProcesses) = Type("DynamicalListGroupRow") Then
			Return;
		EndIf;	
		LockItem = DataLock.Add("Task.PerformerTask");
		LockItem.SetValue("Ref", Tasks);
	EndIf;
	DataLock.Lock();
	
EndProcedure

#EndRegion

#Region InternalInterface

// Declares internal events of BusinessProcessesAndTasks subsystem:
//
// Server events:
//   OnDefineExternalTaskSubjectPresentation,
//   OnDefineFileList,
//   OnCompleteSourceTask.
//
// See the description of this procedure in the StandardSubsystemsServer module.
Procedure OnAddInternalEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS
	
	// Returns the content of the passed object for sending to another information system.
	//
	// Parameters:
	//  TaskSubject  - object whose presentation is to be generated.
	//  Presentation - String  - object content in HTML or MXL document format.
	//
	// Syntax:
	// Procedure OnDefineExternalTaskSubjectPresentation(TaskSubject, Presentation) Export
	//
	ServerEvents.Add(
		"StandardSubsystems.BusinessProcessesAndTasks\OnDefineExternalTaskSubjectPresentation");
	
	// Returns an array of objects of TransferableFileDescription or Undefined type.
	//
	// Parameters:
	//  TaskSubject - object whose file list is retrieved.
	//  FileList - Array  - list of subject files.
	//
	// Syntax:
	// Procedure OnDefineFileList(TaskSubject, FileList) Export
	//
	ServerEvents.Add("StandardSubsystems.BusinessProcessesAndTasks\OnDefineFileList");
	
	// Marks the source task of BusinessProcess business process as completed.
	//
	// Parameters
	//  BusinessProcess - BusinessProcessObject.Job
	//
	// Syntax:
	// Procedure OnCompleteSourceTask(BusinessProcess) Export
	//
	ServerEvents.Add("StandardSubsystems.BusinessProcessesAndTasks\OnCompleteSourceTask");
	
EndProcedure

// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"BusinessProcessesAndTasksServer");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\SubjectPresentationOnDefine"].Add(
		"BusinessProcessesAndTasksServer");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnAddReferenceSearchException"].Add(
		"BusinessProcessesAndTasksServer");
	
	If CommonUse.SubsystemExists("StandardSubsystems.UserReminders") Then
		ServerHandlers["StandardSubsystems.UserReminders\OnFillSourceAttributeListWithReminderDates"].Add(
			"BusinessProcessesAndTasksServer");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ServerHandlers["StandardSubsystems.AccessManagement\OnFillAccessRightDependencies"].Add(
			"BusinessProcessesAndTasksServer");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ServerHandlers["StandardSubsystems.AccessManagement\OnFillMetadataObjectAccessRestrictionKinds"].Add(
			"BusinessProcessesAndTasksServer");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ServerHandlers["StandardSubsystems.AccessManagement\OnFillAccessKinds"].Add(
			"BusinessProcessesAndTasksServer");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations") Then
		ServerHandlers["StandardSubsystems.SaaSOperations.JobQueue\OnReceiveTemplateList"].Add(
			"BusinessProcessesAndTasksServer");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ReportOptions") Then
		ServerHandlers["StandardSubsystems.ReportOptions\ReportOptionsOnSetup"].Add(
			"BusinessProcessesAndTasksServer");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ToDoList") Then
		ServerHandlers["StandardSubsystems.ToDoList\OnFillToDoList"].Add(
			"BusinessProcessesAndTasksServer");
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of the conditional subsystem calls

// Returns a temporary table manager that contains a temporary table of
// users included in some additional user groups, such as task
// performer group users that correspond to addressing keys 
//(PerformerRole + MainAddressingObject + AdditionalAddressingObject).
//
// When changing additional user group content, call the UpdatePerformerGroupUsers
// procedure from AccessManagement module to apply changes to the internal
// subsystem data.
//
// Parameters:
//  TempTablesManager - TempTablesManager that can store a PerformerGroupTable with the following fields:
//                       PerformerGroup - for example, CatalogRef.TaskPerformerGroups.
//                       User       - CatalogRef.Users,
//                                    CatalogRef.ExternalUsers.
//
//  ParameterContent  - Undefined - parameter is not specified, returns all data.
//                      String    - if "PerformerGroups", only returns the contents
//                                of the specified performer groups.
//                               If set to "Performers", only returns the contents of
//                               performer groups that include the specified performers.
//
//  ParameterValue             - Undefined when ParameterContent = Undefined.
//                             - for example,
CatalogRef.TaskPerformerGroups,
//                              when ParameterContent = "PerformerGroups"
//                             - CatalogRef.Users,
//                            CatalogRef.ExternalUsers,
//                               when ParameterContent = "Performers".
//                               Array of the types specified above.
//
Procedure OnDefinePerformerGroups(TempTablesManager, ParameterContent, ParameterValue) Export
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	If ParameterContent = "PerformerGroups" Then
		
		Query.SetParameter("PerformerGroups", ParameterValue);
		Query.Text =
		"SELECT DISTINCT
		|	TaskPerformers.TaskPerformerGroup AS PerformerGroup,
		|	TaskPerformers.Performer AS User
		|INTO PerformerGroupTable
		|FROM
		|	InformationRegister.TaskPerformers AS TaskPerformers
		|WHERE
		|	TaskPerformers.TaskPerformerGroup IN(&PerformerGroups)";
		
	ElsIf ParameterContent = "Performers" Then
		
		Query.SetParameter("Performers", ParameterValue);
		Query.Text =
		"SELECT DISTINCT
		|	TaskPerformers.TaskPerformerGroup AS PerformerGroup,
		|	TaskPerformers.Performer AS User
		|INTO PerformerGroupTable
		|FROM
		|	InformationRegister.TaskPerformers AS TaskPerformers
		|WHERE
		|	TRUE IN
		|			(SELECT TOP 1
		|				TRUE
		|			FROM
		|				InformationRegister.TaskPerformers AS PerformerGroups
		|			WHERE
		|				PerformerGroups.TaskPerformerGroup = TaskPerformers.TaskPerformerGroup
		|				AND PerformerGroups.Performer IN (&Performers))";
		
	Else
		Query.Text =
		"SELECT DISTINCT
		|	TaskPerformers.TaskPerformerGroup AS PerformerGroup,
		|	TaskPerformers.Performer AS User
		|INTO PerformerGroupTable
		|FROM
		|	InformationRegister.TaskPerformers AS TaskPerformers";
	EndIf;
	
	Query.Execute();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// SL event handlers

// Sets the text description of a subject.
//
// Parameters:
//  SubjectRef   - AnyRef - reference object.
//  Presentation - String - text description.
Procedure SubjectPresentationOnDefine(SubjectRef, Presentation) Export
	
	If TypeOf(SubjectRef) = Type("TaskRef.PerformerTask") Then
		ObjectPresentation = SubjectRef.Metadata().ObjectPresentation;
		If IsBlankString(ObjectPresentation) Then
			ObjectPresentation = SubjectRef.Metadata().Presentation();
		EndIf;
		Presentation = StringFunctionsClientServer.SubstituteParametersInString(
		"%1 (%2)", SubjectRef.Description, ObjectPresentation);
	EndIf;
	
EndProcedure

// Fills the array with the list of metadata object names that might include references to other metadata
// objects, but these references are ignored in the business logic of the application.
//
// Parameters:
//  Array - array of strings, for example, "InformationRegister.ObjectVersions".
//
Procedure OnAddReferenceSearchException(Array) Export
	
	Array.Add(Metadata.InformationRegisters.TaskPerformers.FullName());
	Array.Add(Metadata.InformationRegisters.BusinessProcessData.FullName());
	
EndProcedure

// OnReceiveTemplateList event handler.
//
// Generates a list of templates for queued jobs.
//
// Parameters:
//  Templates - Array - array of strings. The parameter should include names of predefined
// shared scheduled jobs to be used as queue job templates.
//
Procedure OnReceiveTemplateList(Templates) Export
	
	Templates.Add("TaskMonitoring");
	Templates.Add("NewPerformerTaskNotifications");
	
EndProcedure

// Redefines the array of object attributes for which the reminder time can be set.
// For example, you can hide the internal date attributes or attributes that do not need reminders: a document date or task date, and so on.
// 
// Parameters:
//  Source	- Any link - reference to the object for which the attribute array with dates is generated.
//  AttributeArray -Array - array of attribute names (from metadata). It includes the attributes that contain dates.
//
Procedure OnFillSourceAttributeListWithReminderDates(Source, AttributeArray) Export
	
	If TypeOf(Source) = Type("TaskRef.PerformerTask") Then
		AttributeArray.Clear();
		AttributeArray.Add("DueDate"); 
		AttributeArray.Add("StartDate"); 
	EndIf;
	
EndProcedure

// non-standard access right dependencies between the subordinate object
// and the main object.
// For example, fills access right dependencies between PerformerTask task
// and Job business process.
//
// The access right dependencies are used in the standard access restriction
// template for Object access kind:
// 1) When reading a subordinate object, the following standard checks are performed: 
//    whether the user has the right to read the main object, and
//    whether the user has no restrictions for reading the head object.
// 2) When adding, changing, or deleting a subordinate object, the following
//    standard checks are performed:
//    whether the user has the right to edit the head object and
//    whether the user has no restrictions for editing the main object.
//
// Only one change to the above check is allowed:
// in paragraph 2 above, checking the right to edit the head object can be replaced by checking the right to read the head object.
//
// Parameters:
//  RightDependencies - ValueTable with the following columns:
//                    - LeadingTable      - String, for example, "BusinessProcess.Job"
//                    - SubordinateTable  - String, for example, "Task.PerformerTask"
//
Procedure OnFillAccessRightDependencies(RightDependencies) Export
	
	// A performer task can be changed when a business process is available only for reading.
	// That is why you do not need to check the right to edit the object or the restrictions that apply to the object editing,
	// but you need a "softer" check condition: check the right to read the object
  // and the restrictions that apply to the object reading.
	
	String = RightDependencies.Add();
	Row.SubordinateTable = "Task.PerformerTask";
	Row.LeadingTable     = "BusinessProcess.Job";
	
EndProcedure

// Fills the list of access kinds that are used to set metadata object right restrictions.
// If the list of access kinds is not filled, the Access rights report displays incorrect data.
//
// Only access kinds that are explicitly used in access restriction templates
// must be filled, while access kinds used in access value sets can alternately 
// be obtained from the current
// state of the AccessValueSets information register.
//
//  To generate the procedure script automatically, it is recommended that
// you use the developer tools from the Access management subsystem.
//
// Parameters:
//  Description - String  - multiline string of the following format: 
//                <Table>.<Right>.<AccessKind>[.Object table] 
//                 For example,  Document.GoodsReceipt.Read.Counterparties
//                 Document.GoodsReceipt.Update.Companies
//
Document.GoodsReceipt.Update.Counterparties
//                 Document.EmailMessages.Read.Object.Document.EmailMessages
//                 Document.EmailMessages.Update.Object.Document.EmailMessages
//                 Document.Files.Read.Object.Catalog.FileFolders 
//
Document.Files.Read.Object.Document.EmailMessage
//                 Document.Files.Update.Object.Catalog.FileFolders
//
Document.Files.Update.Object.Document.EmailMessage
//                 The Object access kind is predefined as a literal.
//                 It is not included in predefined items of ChartsOfCharacteristicTypes.AccessKinds. 
//                 This access kind is used in access restriction templates
//                 as a reference to another object used to apply a restriction to the table.
//                 If Object access kind is specified, table types that are used in
//                 the access kind must be specified too (in other words,
//                 you have to list the types that match the access restriction template field 
//                 that describes the Object access kind)
//                 The list of types for the Object access kind should only include
//                 the field types available for the //                 InformationRegisters.AccessValueSets.Object field.
// 
Procedure OnFillMetadataObjectAccessRestrictionKinds(Description) Export
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		Return;
	EndIf;
	
	Description = Description + 
	"
	|BusinessProcess.Job.Read.Users
	|BusinessProcess.Job.Update.Users
	|
Task.PerformerTask.Read.Object.BusinessProcess.Job 
	|Task.PerformerTask.Read.Users
	|Task.PerformerTask.Update.Users
	|";
	
EndProcedure

// Fills access kinds used in access restrictions.
// Users and ExternalUsers access kinds are already filled.
// They can be deleted if they are not used in access restrictions.
//
// Parameters:
//  AccessKinds - ValueTable with the following fields:
//  - Name               - String - name used in definitions of supplied access group profiles
//                         and in RLS texts.
//  - Presentation       - String - access kind presentation in profiles and access groups.
//  - ValueType          - Type - access value reference type. 
//                         Example: Type("CatalogRef.ProductsAndServices").                
//  - ValueGroupType     - Type - access value group reference type.
//                         For example, Type("CatalogRef.ProductAndServiceAccessGroups").
//  - MultipleValueGroups - Boolean - If True multiple value groups (Items
//                          access groups) can be selected for a single access value (Items).
//
Procedure OnFillAccessKinds(AccessKinds) Export
	
	AccessKind = AccessKinds.Find("Users", "Name");
	If AccessKind <> Undefined Then
		AccessManagementModule = CommonUse.CommonModule("AccessManagement");
		AccessManagementModule.AddExtraTypesOfAccessKind(AccessKind,
			Type("CatalogRef.TaskPerformerGroups"));
	EndIf;
	
EndProcedure

// Fills report option layout settings used to display the reports in the reports panel.
//
// Parameters:
//   Settings - Collection - used to describe report settings and
//       report options. See the description of ReportOptions.ConfigurationReportOptionSettingsTree().
//
// Description:
//  See ReportOptionsOverridable.SetUpReportOptions().
//
Procedure ReportOptionsOnSetup(Settings) Export
	ReportOptionsModule = CommonUse.CommonModule("ReportOptions");
	ReportOptionsModule.SetupReportInManagerModule(Settings, Metadata.Reports.BusinessProcesses);
	ReportOptionsModule.SetupReportInManagerModule(Settings, Metadata.Reports.UnassignedTasks);
	ReportOptionsModule.SetupReportInManagerModule(Settings, Metadata.Reports.Jobs);
	ReportOptionsModule.SetupReportInManagerModule(Settings, Metadata.Reports.Tasks);
	ReportOptionsModule.SetupReportInManagerModule(Settings, Metadata.Reports.ExpiringTasksOnDate);
	ReportOptionsModule.SetupReportInManagerModule(Settings, Metadata.Reports.OverdueTasks);
EndProcedure

// Fills a user's to-do list.
//
// Parameters:
//  ToDoList - ValueTable - value table with the following columns:
//    * ID             - String - internal user task ID used by the To-do list algorithm.
//    * HasUserTasks   - Boolean - if True, the user task is displayed in the user's to-do list.
//    * Important      - Boolean - if True, the user task is outlined in red.
//    * Presentation   - String - user task presentation displayed to the user.
//    * Count          - Number  - quantitative indicator of the user task, displayed in the title of the user task.
//    * Form           - String - full path to the form that is displayed by clicking on the task hyperlink in the To-do list panel.
//    * FormParameters - Structure - parameters for opening the indicator form.
//    * Owner          - String, metadata object - string ID of the user task that is the owner of the current user task, or a subsystem metadata object.
//    * Hint          - String - hint text.
//
Procedure OnFillToDoList(ToDoList) Export
	
	If Not AccessRight("Edit", Metadata.Tasks.PerformerTask) Then
		Return;
	EndIf;
	
	If Not GetFunctionalOption("UseBusinessProcessesAndTasks") Then
		Return;
	EndIf;
	
	PerformerTaskQuantity = PerformerTaskQuantity();
	
	// This procedure is only called when the To-do list subsystem is available.
	// Therefore, the subsystem availability check is redundant.
	ToDoListInternalCachedModule = CommonUse.CommonModule("ToDoListInternalCached");
	
	ObjectsBelonging = ToDoListInternalCachedModule.ObjectsBelongingToCommandInterfaceSections();
	Sections = ObjectsBelonging[Metadata.Tasks.PerformerTask.FullName()];
	
	If Sections = Undefined Then
		Return; // Tasks are not included in the user’s command interface.
	EndIf;
	
	For Each Section In Sections Do
		
		MyTasksID = "PerformerTasks" + StrReplace(Section.FullName(), ".", "");
		UserTask = ToDoList.Add();
		UserTask.ID             = MyTasksID;
		UserTask.HasUserTasks   = PerformerTaskQuantity.Total > 0;
		UserTask.Presentation   = NStr("en = 'My tasks'");
		UserTask.Quantity       = PerformerTaskQuantity.Total;
		UserTask.Form           = "Task.PerformerTask.Form.MyTasks";
		UserTask.FormParameters = New Structure("Filter", New Structure("Executed", False));
		UserTask.Owner          = Section;
		
		UserTask = ToDoList.Add();
		UserTask.ID           = "PerformerTasksOverdue";
		UserTask.HasUserTasks = PerformerTaskQuantity.Overdue > 0;
		UserTask.Presentation = NStr("en = 'overdue'");
		UserTask.Quantity     = PerformerTaskQuantity.Overdue;
		UserTask.Important    = True;
		UserTask.Owner        = MyTasksID; 
		
		UserTask = ToDoList.Add();
		UserTask.ID           = "PerformerTasksForToday";
		UserTask.HasUserTasks = PerformerTaskQuantity.ForToday > 0;
		UserTask.Presentation = NStr("en = 'today'");
		UserTask.Quantity     = PerformerTaskQuantity.ForToday;
		UserTask.Owner        = MyTasksID; 

		UserTask = ToDoList.Add();
		UserTask.ID           = "PerformerTasksForWeek";
		UserTask.HasUserTasks = PerformerTaskQuantity.ForWeek > 0;
		UserTask.Presentation = NStr("en = 'this week'");
		UserTask.Quantity     = PerformerTaskQuantity.ForWeek;
		UserTask.Owner        = MyTasksID; 

		UserTask = ToDoList.Add();
		UserTask.ID           = "PerformerTasksForNextWeek";
		UserTask.HasUserTasks = PerformerTaskQuantity.ForNextWeek > 0;
		UserTask.Presentation = NStr("en = 'next week'");
		UserTask.Quantity     = PerformerTaskQuantity.ForNextWeek > 0;
		UserTask.Owner        = MyTasksID; 
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions

// Selects the list of roles that can be assigned to MainAddressingObject,
// and generates the list of assignments.
//
Function SelectRolesWithPerformerCount(MainAddressingObject) Export
	If MainAddressingObject <> Undefined Then
		QueryText = 
			"SELECT ALLOWED
			|	PerformerRoles.Ref AS RoleReference,
			|	PerformerRoles.Description AS Role,
			|	PerformerRoles.ExternalRole AS ExternalRole,
			|	PerformerRoles.MainAddressingObjectTypes AS MainAddressingObjectTypes,
			|	SUM(CASE
			|			WHEN TaskPerformers.PerformerRole <> VALUE(Catalog.PerformerRoles.EmptyRef) 
			|				AND TaskPerformers.PerformerRole IS Not NULL 
			|				AND TaskPerformers.MainAddressingObject = &MainAddressingObject
			|				THEN 1
			|			ELSE 0
			|		END) AS Performers
			|FROM
			|	Catalog.PerformerRoles AS PerformerRoles
			|		LEFT JOIN InformationRegister.TaskPerformers AS TaskPerformers
			|		ON (TaskPerformers.PerformerRole = PerformerRoles.Ref)
			|WHERE
			|	PerformerRoles.DeletionMark = FALSE
			|	AND PerformerRoles.UsedByAddressingObjects = TRUE
			| GROUP BY
			|	PerformerRoles.Ref,
			|	TaskPerformers.PerformerRole, 
			|	PerformerRoles.ExternalRole,
			|	PerformerRoles.Description,
			|	PerformerRoles.MainAddressingObjectTypes";
	Else
		QueryText = 
			"SELECT ALLOWED
			|	PerformerRoles.Ref AS RoleReference,
			|	PerformerRoles.Description AS Role,
			|	PerformerRoles.ExternalRole AS ExternalRole,
			|	PerformerRoles.MainAddressingObjectTypes AS MainAddressingObjectTypes,
			|	SUM(CASE
			|			WHEN TaskPerformers.PerformerRole <> VALUE(Catalog.PerformerRoles.EmptyRef) 
			|				AND TaskPerformers.PerformerRole IS Not NULL 
			|				AND (TaskPerformers.MainAddressingObject IS NULL 
			|					OR TaskPerformers.MainAddressingObject = Undefined)
			|				THEN 1
			|			ELSE 0
			|		END) AS Performers
			|FROM
			|	Catalog.PerformerRoles AS PerformerRoles
			|		LEFT JOIN InformationRegister.TaskPerformers AS TaskPerformers
			|		ON (TaskPerformers.PerformerRole = PerformerRoles.Ref)
			|WHERE
			|	PerformerRoles.DeletionMark = FALSE
			|	AND PerformerRoles.UsedWithoutAddressingObjects = TRUE
			| GROUP BY
			|	PerformerRoles.Ref,
			|	TaskPerformers.PerformerRole, 
			|	PerformerRoles.ExternalRole,
			|	PerformerRoles.Description, 
			|	PerformerRoles.MainAddressingObjectTypes";
	EndIf;		
	Query = New Query(QueryText);
	Query.Parameters.Insert("MainAddressingObject", MainAddressingObject);
	QuerySelection = Query.Execute().Select();
	Return QuerySelection;
	
EndFunction

// Selects the list of performers that have the specified role.
//
// Result:
//    Array - Array of Users catalog items.
//
Function RolePerformers(RoleReference, MainAddressingObject = Undefined,
	AdditionalAddressingObject = Undefined) Export
	
	QueryResult = ChooseRolePerformers(RoleReference, MainAddressingObject,
		AdditionalAddressingObject);
	Return QueryResult.Unload().UnloadColumn("Performer");	
	
EndFunction

// Checks whether at least one performer has the specified role.
//
// Result:
//   Boolean.
//
Function HasRolePerformers(RoleReference, MainAddressingObject = Undefined,
	AdditionalAddressingObject = Undefined) Export
	
	QueryResult = ChooseRolePerformers(RoleReference, MainAddressingObject,
		AdditionalAddressingObject);
	Return Not QueryResult.IsEmpty();	
	
EndFunction

Function ChooseRolePerformers(RoleReference, MainAddressingObject = Undefined,
	AdditionalAddressingObject = Undefined)
	
	QueryText = 
		"SELECT
	   |	TaskPerformers.Performer
	   |FROM
	   |	InformationRegister.TaskPerformers AS TaskPerformers
	   |WHERE
	   |	TaskPerformers.PerformerRole = &PerformerRole";
	If MainAddressingObject <> Undefined Then  
		QueryText = QueryText +
	   		"	And TaskPerformers.MainAddressingObject = &MainAddressingObject";
	EndIf;		
	If AdditionalAddressingObject <> Undefined Then  
		QueryText = QueryText +
		 	"	And TaskPerformers.AdditionalAddressingObject = &AdditionalAddressingObject";
	EndIf;		
	Query = New Query(QueryText);
	Query.Parameters.Insert("PerformerRole", RoleReference);
	Query.Parameters.Insert("MainAddressingObject", MainAddressingObject);
	Query.Parameters.Insert("AdditionalAddressingObject", AdditionalAddressingObject);
	QueryResult = Query.Execute();
	Return QueryResult;
	
EndFunction

// Selects any performer that has PerformerRole in MainAddressingObject.
// 
Function SelectPerformer(MainAddressingObject, PerformerRole) Export
	
	Query = New Query(
		"SELECT ALLOWED TOP 1
		|	TaskPerformers.Performer AS Performer
		|FROM
		|	InformationRegister.TaskPerformers AS TaskPerformers
		|WHERE
		|	TaskPerformers.PerformerRole = &PerformerRole
		|	AND TaskPerformers.MainAddressingObject = &MainAddressingObject");
	Query.Parameters.Insert("MainAddressingObject", MainAddressingObject);
	Query.Parameters.Insert("PerformerRole", PerformerRole);
	QuerySelection = Query.Execute().Unload();
	Return ?(QuerySelection.Count() > 0, QuerySelection[0].Performer, Catalogs.Users.EmptyRef());
	
EndFunction	

Function SelectHeadTaskBusinessProcesses(TaskRef, ForChange = False) Export
	
	Iteration = 1;
	QueryText = "";
	For Each BusinessProcessMetadata In Metadata.BusinessProcesses Do
		
		If ForChange Then
			DataLock = New DataLock;
			LockItem = DataLock.Add(BusinessProcessMetadata.FullName());
			LockItem.SetValue("HeadTask", TaskRef);
			DataLock.Lock();
		EndIf;
		
		If Not IsBlankString(QueryText) Then
			QueryText = QueryText + "
				|
				|UNION ALL
				|";
				
		EndIf;
		QueryFragment = StringFunctionsClientServer.SubstituteParametersInString(
			"SELECT %3
			|	%1.Ref AS Ref
			|FROM
			|	%2 AS %1
			|WHERE
			|	%1.HeadTask = &HeadTask", BusinessProcessMetadata.Name, BusinessProcessMetadata.FullName(),
			?(Iteration = 1, "ALLOWED", ""));
		QueryText = QueryText + QueryFragment;
		Iteration = Iteration + 1;
	EndDo;	
	
	Query = New Query(QueryText);
	Query.SetParameter("HeadTask", TaskRef);
	Result = Query.Execute();
	Return Result;
		
EndFunction	

// Returns the type of subsystem events in the event log.
//
Function EventLogMessageText() Export
	Return NStr("en = 'Business processes and tasks'", CommonUseClientServer.DefaultLanguageCode());
EndFunction

// The procedure is called when changing states of a business process,
// to expand this state change to the uncompleted tasks of the business process.
// 
Procedure OnChangeBusinessProcessState(BusinessProcess, OldState, NewState) Export
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	PerformerTask.Ref AS Ref
		|FROM
		|	Task.PerformerTask AS PerformerTask
		|WHERE
		|	PerformerTask.BusinessProcess = &BusinessProcess
		|	AND PerformerTask.Executed = False";

	Query.SetParameter("BusinessProcess", BusinessProcess.Ref);

	Result = Query.Execute();

	DetailedRecordSelection = Result.Select();

	While DetailedRecordSelection.Next() Do
		
		Task = DetailedRecordSelection.Ref.GetObject();
		Task.Lock();
		Task.BusinessProcessState =  NewState;
		Task.Write();
		
		OnChangeTaskState(Task.Ref, OldState, NewState);
	EndDo;

EndProcedure

Procedure OnChangeTaskState(TaskRef, OldState, NewState)
	
	// Changing the state of nested business processes
	For Each BusinessProcessMetadata In Metadata.BusinessProcesses Do
		
		If Not AccessRight("Update", BusinessProcessMetadata) Then
		    Continue;
		EndIf;
		
		Query = New Query;
		Query.Text = 
			"SELECT ALLOWED
			|	BusinessProcesses.Ref AS Ref
			|FROM
			|	%BusinessProcess% AS BusinessProcesses
			|WHERE
			|   BusinessProcesses.HeadTask = &HeadTask
			|   AND BusinessProcesses.DeletionMark = False
			| 	AND BusinessProcesses.Completed = False";
			
		Query.Text = StrReplace(Query.Text, "%BusinessProcess%", BusinessProcessMetadata.FullName());
		Query.SetParameter("HeadTask", TaskRef);

		Result = Query.Execute();
		
		DetailedRecordSelection = Result.Select();

		While DetailedRecordSelection.Next() Do
			
			BusinessProcess = DetailedRecordSelection.Ref.GetObject();
			BusinessProcess.State = NewState;
			BusinessProcess.Write();
			
		EndDo;
		
	EndDo;	
	
	// Changing the state of subordinate business processes
	For Each BusinessProcessMetadata In Metadata.BusinessProcesses Do
		
		// Business processes are not required to have a main task.
		MainTaskAttribute = BusinessProcessMetadata.Attributes.Find("MainTask");
		If MainTaskAttribute = Undefined Then
			Continue;
		EndIf;	
			
		Query = New Query;
		Query.Text = 
			"SELECT ALLOWED
			|	BusinessProcesses.Ref AS Ref
			|FROM
			|	%BusinessProcess% AS BusinessProcesses
			|WHERE
			|   BusinessProcesses.MainTask = &MainTask
			|   AND BusinessProcesses.DeletionMark = False
			| 	AND BusinessProcesses.Completed = False";
			
		Query.Text = StrReplace(Query.Text, "%BusinessProcess%", BusinessProcessMetadata.FullName());
		Query.SetParameter("MainTask", TaskRef);

		Result = Query.Execute();
		
		DetailedRecordSelection = Result.Select();

		While DetailedRecordSelection.Next() Do
			
			BusinessProcess = DetailedRecordSelection.Ref.GetObject();
			BusinessProcess.State = NewState;
			BusinessProcess.Write();
			
		EndDo;
		
	EndDo;	
	
EndProcedure

// Fills the MainTask attribute when creating a business process based on another business process.
//
Procedure FillPrimaryTask(BusinessProcessObject, FillingData) Export
	
	StandardProcessing = True;
	BusinessProcessesAndTasksOverridable.OnFillMainBusinessProcessTask(BusinessProcessObject, FillingData, StandardProcessing);
	If Not StandardProcessing Then
		Return;
	EndIf;
	
	// For backward compatibility
	Cancel = BusinessProcessesAndTasksOverridable.FillPrimaryTask(BusinessProcessObject, FillingData);
	If Cancel Then
		Return;
	EndIf;
	
	If FillingData = Undefined Then 
		Return;
	EndIf;
	
	If TypeOf(FillingData) = Type("TaskRef.PerformerTask") Then
		BusinessProcessObject.MainTask = FillingData;
	EndIf;
	
EndProcedure

// Gets the task performer groups according to the new task performer records.
//
// Parameters:
//  NewTaskPerformers  - ValueTable - data retrieved from the TaskPerformers information register
//                                   record set.
//
// Returns:
//   Array - containing elements of CatalogRef.TaskPerformerGroups type.
//
Function TaskPerformerGroups(NewTaskPerformers) Export
	
	FieldNames = "PerformerRole, MainAddressingObject, AdditionalAddressingObject";
	
	Query = New Query;
	Query.SetParameter("NewRecords", NewTaskPerformers.Copy( , FieldNames));
	Query.Text =
	"SELECT DISTINCT
	|	NewRecords.PerformerRole AS PerformerRole,
	|	NewRecords.MainAddressingObject AS MainAddressingObject,
	|	NewRecords.AdditionalAddressingObject AS AdditionalAddressingObject
	|INTO NewRecords
	|FROM
	|	&NewRecords AS NewRecords
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ISNULL(TaskPerformerGroups.Ref, VALUE(Catalog.TaskPerformerGroups.EmptyRef)) AS Ref,
	|	NewRecords.PerformerRole AS PerformerRole,
	|	NewRecords.MainAddressingObject AS MainAddressingObject,
	|	NewRecords.AdditionalAddressingObject AS AdditionalAddressingObject
	|FROM
	|	NewRecords AS NewRecords
	|		LEFT JOIN Catalog.TaskPerformerGroups AS TaskPerformerGroups
	|		ON NewRecords.PerformerRole = TaskPerformerGroups.PerformerRole
	|			AND NewRecords.MainAddressingObject = TaskPerformerGroups.MainAddressingObject
	|			AND NewRecords.AdditionalAddressingObject = TaskPerformerGroups.AdditionalAddressingObject";
	
	PerformerGroups = Query.Execute().Unload();
	
	PerformerGroupFilter = New Structure(FieldNames);
	TaskPerformerGroups = New Array;
	
	For Each Write In NewTaskPerformers Do
		FillPropertyValues(PerformerGroupFilter, Write);
		PerformerGroup = PerformerGroups.FindRows(PerformerGroupFilter)[0];
		// It is necessary to update the reference in the found string is required.
		If Not ValueIsFilled(PerformerGroup.Ref) Then
			// It is necessary to add a new performer group.
			PerformerGroupObject = Catalogs.TaskPerformerGroups.CreateItem();
			FillPropertyValues(PerformerGroupObject, PerformerGroupFilter);
			PerformerGroupObject.Write();
			PerformerGroup.Ref = PerformerGroupObject.Ref;
		EndIf;
		TaskPerformerGroups.Add(PerformerGroup.Ref);
	EndDo;
	
	Return TaskPerformerGroups;
	
EndFunction

// Gets a task performer group that matches the addressing attributes.
// If the group does not yet exist, it is created and returned.
// 
// Parameters:
//  PerformerRole               - CatalogRef.PerformerRoles
//  MainAddressingObject        - AnyRef.
//  AdditionalAddressingObject  - AnyRef.
// 
// Returns:
//   CatalogRef.TaskPerformerGroups.
//
Function TaskPerformerGroup(PerformerRole, MainAddressingObject, AdditionalAddressingObject) Export
	
	BeginTransaction();
	Try
		DataLock = New DataLock;
		LockItem = DataLock.Add("Catalog.TaskPerformerGroups");
		LockItem.SetValue("PerformerRole", PerformerRole);
		LockItem.SetValue("MainAddressingObject", MainAddressingObject);
		LockItem.SetValue("AdditionalAddressingObject", AdditionalAddressingObject);
		DataLock.Lock();
		
		Query = New Query(
			"SELECT
			|	TaskPerformerGroups.Ref AS Ref
			|FROM
			|	Catalog.TaskPerformerGroups AS TaskPerformerGroups
			|WHERE
			|	TaskPerformerGroups.PerformerRole = &PerformerRole
			|	AND TaskPerformerGroups.MainAddressingObject = &MainAddressingObject
			|	AND TaskPerformerGroups.AdditionalAddressingObject = &AdditionalAddressingObject");
		Query.SetParameter("PerformerRole",               PerformerRole);
		Query.SetParameter("MainAddressingObject",       MainAddressingObject);
		Query.SetParameter("AdditionalAddressingObject", AdditionalAddressingObject);
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			PerformersGroup = Selection.Ref;
		Else
			// It is necessary to add a new task performer group.
			PerformerGroupObject = Catalogs.TaskPerformerGroups.CreateItem();
			PerformerGroupObject.PerformerRole               = PerformerRole;
			PerformerGroupObject.MainAddressingObject       = MainAddressingObject;
			PerformerGroupObject.AdditionalAddressingObject = AdditionalAddressingObject;
			PerformerGroupObject.Write();
			PerformerGroup = PerformerGroupObject.Ref;
		EndIf;
		CommitTransaction();
		Return PerformerGroup;
	Except
		RollbackTransaction();
		Raise;
	EndTry;	
		
EndFunction 

// Marks nested and subordinate business processes of TaskRef task for deletion.
//
// Parameters:
//  TaskRef              - TaskRef.PerformerTask.
//  DeletionMarkNewValue - Boolean.
//
Procedure OnMarkTaskForDeletion(TaskRef, DeletionMarkNewValue) Export
	
	TaskObject = TaskRef.Metadata();
	If DeletionMarkNewValue Then
		VerifyAccessRights("InteractiveDeletionMark", TaskObject);
	EndIf;
	If Not DeletionMarkNewValue Then
		VerifyAccessRights("InteractiveClearDeletionMark", TaskObject);
	EndIf;
	
	BeginTransaction();
	Try
		// Marking nested business processes
		SetPrivilegedMode(True);
		NestedBusinessProcesses = LeadingTaskBusinessProcesses(TaskRef, True);
		For Each SubBusinessProcess In NestedBusinessProcesses Do
			BusinessProcessObject = SubBusinessProcess.GetObject();
			BusinessProcessObject.SetDeletionMark(DeletionMarkNewValue);
		EndDo;	
		SetPrivilegedMode(False);
		
		// Marking subordinate business processes
		SubordinateBusinessProcesses = MainTaskBusinessProcesses(TaskRef, True);
		For Each SubordinateBusinessProcess In SubordinateBusinessProcesses Do
			BusinessProcessObject = SubordinateBusinessProcess.GetObject();
			BusinessProcessObject.Lock();
			BusinessProcessObject.SetDeletionMark(DeletionMarkNewValue);
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Checks whether the user has enough rights to mark a business process as stopped or active.
// 
// Parameters:
//  BusinessProcess - business process reference.
//
// Returns:
//  True if the user has that right, False otherwise.
//
Function HasStopBusinessProcessRights(BusinessProcess)
	
	HasRights = False;
	StandardProcessing = True;
	BusinessProcessesAndTasksOverridable.OnCheckStopBusinessProcessRights(BusinessProcess, HasRights, StandardProcessing);
	If Not StandardProcessing Then
		Return HasRights;
	EndIf;
	
	// For backward compatibility
	Result = BusinessProcessesAndTasksOverridable.HasStopBusinessProcessRights(BusinessProcess);
	If Result <> Undefined Then
		Return Result;
	EndIf;
	
	If Users.InfobaseUserWithFullAccess() Then
		Return True;
	EndIf;
	
	If BusinessProcess.Author = Users.CurrentUser() Then
		Return True;
	EndIf;
	
	Return HasRights;
	
EndFunction

Procedure SetMyTaskListParameters(List) Export
	
	CurrentSessionDate = CurrentSessionDate();
	Today = New StandardPeriod(StandardPeriodVariant.Today);
	ThisWeek = New StandardPeriod(StandardPeriodVariant.ThisWeek);
	NextWeek = New StandardPeriod(StandardPeriodVariant.NextWeek);
	
	List.Parameters.SetParameterValue("CurrentDate", CurrentSessionDate);
	List.Parameters.SetParameterValue("EndOfDay", Today.EndDate);
	List.Parameters.SetParameterValue("EndOfWeek", ThisWeek.EndDate);
	List.Parameters.SetParameterValue("EndOfNextWeek", NextWeek.EndDate);
	List.Parameters.SetParameterValue("Overdue", NStr("en = ' Overdue'"));
	List.Parameters.SetParameterValue("Today", NStr("en = 'Today'"));
	List.Parameters.SetParameterValue("ThisWeek", NStr("en = 'Till the end of the week'"));
	List.Parameters.SetParameterValue("NextWeek", NStr("en = 'Next week'"));
	List.Parameters.SetParameterValue("Later", NStr("en = 'Later'"));
	List.Parameters.SetParameterValue("BegOfDay", BegOfDay(CurrentSessionDate));
	List.Parameters.SetParameterValue("EmptyDate", Date(1,1,1));
	
EndProcedure

Function PerformerTaskQuantity()
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	COUNT(TasksByPerformer.Ref) AS Quantity
		|FROM
		|	Task.PerformerTask.TasksByPerformer AS TasksByPerformer
		|WHERE
		|	Not TasksByPerformer.DeletionMark
		|	AND Not TasksByPerformer.Executed
		|	AND TasksByPerformer.BusinessProcessState = VALUE(Enum.BusinessProcessStates.Active)
		|
		|UNION ALL
		|
		|SELECT
		|	COUNT(TasksByPerformer.Ref)
		|FROM
		|	Task.PerformerTask.TasksByPerformer AS TasksByPerformer
		|WHERE
		|	TasksByPerformer.DueDate <= &CurrentDate
		|	AND Not TasksByPerformer.DeletionMark
		|	AND Not TasksByPerformer.Executed
		|	AND TasksByPerformer.BusinessProcessState = VALUE(Enum.BusinessProcessStates.Active)
		|
		|UNION ALL
		|
		|SELECT
		|	COUNT(TasksByPerformer.Ref)
		|FROM
		|	Task.PerformerTask.TasksByPerformer AS TasksByPerformer
		|WHERE
		|	TasksByPerformer.DueDate > &CurrentDate
		|	AND TasksByPerformer.DueDate <= &Today
		|	AND Not TasksByPerformer.DeletionMark
		|	AND Not TasksByPerformer.Executed
		|	AND TasksByPerformer.BusinessProcessState = VALUE(Enum.BusinessProcessStates.Active)
		|
		|UNION ALL
		|
		|SELECT
		|	COUNT(TasksByPerformer.Ref)
		|FROM
		|	Task.PerformerTask.TasksByPerformer AS TasksByPerformer
		|WHERE
		|	TasksByPerformer.DueDate > &Today
		|	AND TasksByPerformer.DueDate <= &EndOfWeek
		|	AND Not TasksByPerformer.DeletionMark
		|	AND Not TasksByPerformer.Executed
		|	AND TasksByPerformer.BusinessProcessState = VALUE(Enum.BusinessProcessStates.Active)
		|
		|UNION ALL
		|
		|SELECT
		|	COUNT(TasksByPerformer.Ref)
		|FROM
		|	Task.PerformerTask.TasksByPerformer AS TasksByPerformer
		|WHERE
		|	TasksByPerformer.DueDate > &EndOfWeek
		|	AND TasksByPerformer.DueDate <= &EndOfNextWeek
		|	AND Not TasksByPerformer.DeletionMark
		|	AND Not TasksByPerformer.Executed
		|	AND TasksByPerformer.BusinessProcessState = VALUE(Enum.BusinessProcessStates.Active)";

	Today = New StandardPeriod(StandardPeriodVariant.Today);
	ThisWeek = New StandardPeriod(StandardPeriodVariant.ThisWeek);
	NextWeek = New StandardPeriod(StandardPeriodVariant.NextWeek);
	
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	Query.SetParameter("Today", Today.EndDate);
	Query.SetParameter("EndOfWeek", ThisWeek.EndDate);
	Query.SetParameter("EndOfNextWeek", NextWeek.EndDate);

	QueryResult = Query.Execute().Unload();
	
	Result = New Structure("Total,Overdue,ForToday,ForWeek,ForNextWeek");
	Result.Total = QueryResult[0].Quantity;
	Result.Overdue = QueryResult[1].Quantity;
	Result.ForToday = QueryResult[2].Quantity;
	Result.ForWeek = QueryResult[3].Quantity;
	Result.ForNextWeek = QueryResult[4].Quantity;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Infobase updates

// Adds update handlers that are required by the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see the description of NewUpdateHandlerTable function in the InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.2.2";
	Handler.Procedure = "BusinessProcessesAndTasksServer.InfobaseUpdate";
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.6.6";
	Handler.Procedure = "BusinessProcessesAndTasksServer.InfobaseUpdateSubjectString";
	
	Handler = Handlers.Add();
	Handler.Version = "1.1.1.2";
	Handler.Procedure = "BusinessProcessesAndTasksServer.StateAndAcceptForExecutionUpdate";
	
	Handler = Handlers.Add();
	Handler.Version = "1.2.1.1";
	Handler.Procedure = "BusinessProcessesAndTasksServer.PerformerRoleCodeUpdate";
	
EndProcedure

// Initializes ResponsibleForCompletionControl predefined performer role.
// 
Procedure InfobaseUpdate() Export
	
	AllAddressingObjects = ChartsOfCharacteristicTypes.TaskAddressingObjects.AllAddressingObjects;
	
	RoleObject = Catalogs.PerformerRoles.ResponsibleForCompletionControl.GetObject();
	LockDataForEdit(RoleObject.Ref);
	RoleObject.UsedWithoutAddressingObjects = True;
	RoleObject.UsedByAddressingObjects = True;
	RoleObject.MainAddressingObjectTypes = AllAddressingObjects;
	RoleObject.Write();
	
EndProcedure

// Initializes the new State field for the processes that have it.
// 
Procedure StateAndAcceptForExecutionUpdate() Export
	
	// Updating the states of business processes and tasks
	For Each BusinessProcessMetadata In Metadata.BusinessProcesses Do
		
		AttributeCondition = BusinessProcessMetadata.Attributes.Find("State");
		If AttributeCondition = Undefined Then
			Continue;
		EndIf;	
			
		Query = New Query;
		Query.Text = 
			"SELECT 
			|	BusinessProcesses.Ref AS Ref
			|FROM
			|	%BusinessProcess% AS BusinessProcesses";
			
		Query.Text = StrReplace(Query.Text, "%BusinessProcess%", BusinessProcessMetadata.FullName());

		Result = Query.Execute();
		
		DetailedRecordSelection = Result.Select();

		While DetailedRecordSelection.Next() Do
			
			BusinessProcess = DetailedRecordSelection.Ref.GetObject();
			BusinessProcess.Lock();
			BusinessProcess.State = Enums.BusinessProcessStates.Active;
			InfobaseUpdate.WriteData(BusinessProcess);
			
		EndDo;
		
	EndDo;
	
	// Updating the property that marks tasks as "accepted for execution"
	Query = New Query;
	Query.Text = 
		"SELECT 
		|	Tasks.Ref AS Ref
		|FROM
		|	Task.PerformerTask AS Tasks";
		
	Result = Query.Execute();
	
	DetailedRecordSelection = Result.Select();

	While DetailedRecordSelection.Next() Do
		
		TaskObject = DetailedRecordSelection.Ref.GetObject();
		
		If TaskObject.Executed = True Then
			TaskObject.AcceptedForExecution = True;
			TaskObject.AcceptForCompletionDate = TaskObject.CompletionDate;
		EndIf;
		
		TaskObject.BusinessProcessState = Enums.BusinessProcessStates.Active;
		
		InfobaseUpdate.WriteData(TaskObject);
		
	EndDo;
	
EndProcedure	

// Fills the new SubjectString field in PerformerTask task.
// 
Procedure InfobaseUpdateSubjectString() Export
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	PerformerTask.Ref AS Ref,
		|	PerformerTask.Subject AS Subject
		|FROM
		|	Task.PerformerTask AS PerformerTask";

	Result = Query.Execute();
	DetailedRecordSelection = Result.Select();
	While DetailedRecordSelection.Next() Do
		
		SubjectRef = DetailedRecordSelection.Subject;
		If SubjectRef = Undefined Or SubjectRef.IsEmpty() Then
			Continue;	
		EndIf;	
		
		TaskObject = DetailedRecordSelection.Ref.GetObject();
		TaskObject.SubjectString = CommonUse.SubjectString(SubjectRef);
		InfobaseUpdate.WriteData(TaskObject);
		
	EndDo;

EndProcedure

// Moves data from the standard Code attribute to the new ShortPresentation attribute.
// 
Procedure PerformerRoleCodeUpdate() Export
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	PerformerRoles.Ref AS Ref,
		|	PerformerRoles.Code AS Code
		|FROM
		|	Catalog.PerformerRoles AS PerformerRoles";

	Result = Query.Execute();
	DetailedRecordSelection = Result.Select();
	While DetailedRecordSelection.Next() Do
		
		CodeValue = DetailedRecordSelection.Code;
		If IsBlankString(CodeValue) Then
			Continue;
		EndIf;
		
		PerformersRoleObject = DetailedRecordSelection.Ref.GetObject();
		PerformersRoleObject.ShortPresentation = CodeValue;
		InfobaseUpdate.WriteData(PerformersRoleObject);
		
	EndDo;

EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Handlers of conditional calls of other subsystems
// Returns the email of Recipient user for mailing task notifications.
//
// Parameters:
//  Recipient - CatalogRef.Users.
//  Address   - String - address to be returned.
//
//
Procedure OnReceiveEmailAddress(Val Recipient, Address) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ContactInformationManagementModule = CommonUse.CommonModule("ContactInformationManagement");
		Address = ContactInformationManagementModule.GetObjectContactInformation(
			Recipient, Catalogs.ContactInformationKinds.UserEmail);
	EndIf;
	
EndProcedure

// Returns True if ExternalTasksAndBusinessProcesses subsystem is used.
Procedure OnDefineUseExternalTasksAndBusinessProcesses(SubsystemUsed) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.ExternalBusinessProcessesAndTasks") Then
		SubsystemUsed = True;
	Else
		SubsystemUsed = False;
	EndIf;
	
EndProcedure

// Returns True if the task is external. 
//
// Parameters:
//  TaskRef - TaskRef.PerformerTask.
//
Procedure OnDetermineExternalTask(TaskRef, ExternalTask) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.ExternalBusinessProcessesAndTasks") Then
	Else
		ExternalTask = False;
	EndIf;
	
EndProcedure

#EndRegion
