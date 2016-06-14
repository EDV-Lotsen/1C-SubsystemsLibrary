////////////////////////////////////////////////////////////////////////////////
// Business processes and tasks subsystem
//  
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Gets a structure with the description of the task execution form.
//
// Parameters
//  TaskRef - TaskRef.PerformerTask - task.
//
// Returns:
//   Structure - structure with description of task execution form.
//
Function TaskExecutionForm(Val TaskRef) Export
	
	If TypeOf(TaskRef) <> Type("TaskRef.PerformerTask") Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Invalid TaskRef parameter type (passed: %1, expected: %2))'"),
			TypeOf(TaskRef), "TaskRef.PerformerTask");
		Raise MessageText;
		
	EndIf;
	
	Attributes = CommonUse.ObjectAttributeValues(TaskRef, "BusinessProcess,RoutePoint");
	If Attributes.BusinessProcess = Undefined Or Attributes.BusinessProcess.IsEmpty() Then
		Return New Structure();
	EndIf;
	
	BusinessProcessType = Attributes.BusinessProcess.Metadata();
	FormParameters = BusinessProcesses[BusinessProcessType.Name].TaskExecutionForm(TaskRef,
		Attributes.RoutePoint);
	ExternalTask = False;
	BusinessProcessesAndTasksServer.OnDetermineExternalTask(TaskRef, ExternalTask);
	If ExternalTask Then
		BusinessProcessesAndTasksOverridable.OnReceiveTaskExecutionForm(
			BusinessProcessType.Name, TaskRef, Attributes.RoutePoint, FormParameters);
	EndIf;
	
	Return FormParameters;
	
EndFunction

// Checks whether the report cell contains a reference to a task 
// and returns the decrypted value in the DetailsValue parameter.
//
Function IsPerformerTask(Val Details, Val ReportDetailsData, DetailsValue) Export
	
	ObjectDetailsData = GetFromTempStorage(ReportDetailsData);
	DetailsValue = ObjectDetailsData.Items[Details].GetFields()[0].Value;
	Return TypeOf(DetailsValue) = Type("TaskRef.PerformerTask");
	
EndFunction

// Executes TaskRef task. If necessary executes the DefaultCompletionHandler
// in the manager module of the business process where the task belongs.
//
Procedure ExecuteTask(TaskRef, DefaultAction = False) Export

	BeginTransaction();
	Try
		BusinessProcessesAndTasksServer.LockTasks(TaskRef);
		
		TaskObject = TaskRef.GetObject();
		If TaskObject.Executed Then
			Raise NStr("en = 'The task was executed earlier.'");
		EndIf;
		
		If DefaultAction And TaskObject.BusinessProcess <> Undefined 
			And Not TaskObject.BusinessProcess.IsEmpty() Then
			BusinessProcessType = TaskObject.BusinessProcess.Metadata();
			BusinessProcesses[BusinessProcessType.Name].DefaultCompletionHandler(TaskRef,
				TaskObject.BusinessProcess, TaskObject.RoutePoint);
		EndIf;
			
		TaskObject.Executed = False;
		TaskObject.ExecuteTask();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;

EndProcedure

// Forward tasks TasksArray
// to a new performer, specified in the structure TaskForwardingDetails. 
//
// Parameters:
//  TasksArray            - Array    - array of tasks for forwarding. 
//  TaskForwardingDetails - Structure - contains new task addressing attribute values
//  CheckOnly             - Boolean    - If True, the function does not actually forward tasks,
//                                     it only checks whether they can be forwarded.
//  ForwardedTasksArray - Array - forwarded tasks array.
//                                The array elements might not exactly match
//                                the TasksArray elements if any tasks are not forwarded.
//
// Returns:
//   Boolean - True if the forwarding is successful.
//
Function ForwardTasks(Val TasksArray, Val TaskForwardingDetails, Val CheckOnly = False,
	ForwardedTasksArray = Undefined) Export
	
	Result = True;
	
	AdditionalTaskData = CommonUse.ObjectsAttributeValues(TasksArray, "BusinessProcess,Executed");
	For Each Task In AdditionalTaskData Do
		
		If Task.Value.Executed Then
			Result = False;
			If CheckOnly Then
				Break;
			EndIf;
		EndIf;	
		
		If CheckOnly Then
			Continue;
		EndIf;	
		
		If Not ValueIsFilled(ForwardedTasksArray) Then
			ForwardedTasksArray = New Array();
		EndIf;
		
		BeginTransaction();
		Try
			BusinessProcessesAndTasksServer.LockTasks(Task.Key);
			If Not Task.Value.BusinessProcess.IsEmpty() Then
				BusinessProcessesAndTasksServer.LockBusinessProcesses(Task.Value.BusinessProcess);
			EndIf;
							
			// The object lock is not set for the Task. This ensures that the task can be
			// forwarded using a task form command.
			TaskObject = Task.Key.GetObject();
			
			SetPrivilegedMode(True);
			NewTask = Tasks.PerformerTask.CreateTask();
			NewTask.Fill(TaskObject);
			FillPropertyValues(NewTask, TaskForwardingDetails, 
				"Performer,PerformerRole,MainAddressingObject,AdditionalAddressingObject");
			NewTask.Write();
			SetPrivilegedMode(False);
		
			ForwardedTasksArray.Add(NewTask.Ref);
			
			TaskObject.ExecutionResult = TaskForwardingDetails.Comment; 
			TaskObject.Executed = False;
			TaskObject.ExecuteTask();
			
			SubordinateBusinessProcesses = BusinessProcessesAndTasksServer.SelectHeadTaskBusinessProcesses(Task.Key, True).Select();
			While SubordinateBusinessProcesses.Next() Do
				BusinessProcessObject = SubordinateBusinessProcesses.Ref.GetObject();
				BusinessProcessObject.HeadTask = NewTask.Ref;
				BusinessProcessObject.Write();
			EndDo;
			
			SubordinateBusinessProcesses = BusinessProcessesAndTasksServer.MainTaskBusinessProcesses(Task.Key, True);
			For Each SubordinateBusinessProcess In SubordinateBusinessProcesses Do
				BusinessProcessObject = SubordinateBusinessProcess.GetObject();
				BusinessProcessObject.MainTask = NewTask.Ref;
				BusinessProcessObject.Write();
			EndDo;
			
			OnForwardTask(TaskObject, NewTask);
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
	EndDo;
	Return Result;
	
EndFunction

// Marks the specified business processes as active.
//
Procedure ActivateBusinessProcesses(BusinessProcesses) Export
	
	BeginTransaction();
	Try
		BusinessProcessesAndTasksServer.LockBusinessProcesses(BusinessProcesses);
		
		For Each BusinessProcess In BusinessProcesses Do
			ActivateBusinessProcess(BusinessProcess);
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure	

// Marks the specified business process as active.
//
Procedure ActivateBusinessProcess(BusinessProcess) Export
	
	If TypeOf(BusinessProcess) = Type("DynamicalListGroupRow") Then
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		BusinessProcessesAndTasksServer.LockBusinessProcesses(BusinessProcess);
		
		Object = BusinessProcess.GetObject();
		If Object.State = Enums.BusinessProcessStates.Active Then
			
			If Object.Completed Then
				Raise NStr("en = 'Cannot activate the completed business processes.'");
			EndIf;
				
			If Not Object.Started Then
				Raise NStr("en = 'Cannot activate the business processes that are not started yet.'");
			EndIf;
			
			Raise NStr("en = 'The business process is already active.'");
		EndIf;
			
		Object.Lock();
		Object.State = Enums.BusinessProcessStates.Active;
		Object.Write();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Marks the specified business processes as stopped.
//
Procedure StopBusinessProcesses(BusinessProcesses) Export
	
	BeginTransaction();
	Try 
		BusinessProcessesAndTasksServer.LockBusinessProcesses(BusinessProcesses);
		
		For Each BusinessProcess In BusinessProcesses Do
			StopBusinessProcess(BusinessProcess);
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(BusinessProcessesAndTasksServer.EventLogMessageText(), EventLogLevel.Error,,, 
			DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure	

// Marks the specified business process as stopped.
//
Procedure StopBusinessProcess(BusinessProcess) Export
	
	If TypeOf(BusinessProcess) = Type("DynamicalListGroupRow") Then
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		BusinessProcessesAndTasksServer.LockBusinessProcesses(BusinessProcess);
		
		Object = BusinessProcess.GetObject();
		If Object.State = Enums.BusinessProcessStates.Stopped Then
			
			If Object.Completed Then
				Raise NStr("en = 'Cannot stop the completed business processes.'");
			EndIf;
				
			If Not Object.Started Then
				Raise NStr("en = 'Cannot stop the business processes that are not started yet.'");
			EndIf;
			
			Raise NStr("en = 'The business process is already stopped.'");
		EndIf;
		
		Object.Lock();
		Object.State = Enums.BusinessProcessStates.Stopped;
		Object.Write();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Marks the specified tasks as accepted for execution.
//
Procedure AcceptTasksForExecution(Tasks) Export
	
	NewTaskArray = New Array();
	
	BeginTransaction();
	Try
		BusinessProcessesAndTasksServer.LockTasks(Tasks);
		
		For Each Task In Tasks Do
			
			If TypeOf(Task) = Type("DynamicalListGroupRow") Then 
				Continue;
			EndIf;
			
			TaskObject = Task.GetObject();
			If TaskObject.Executed Then
				Continue;
			EndIf;
			
			TaskObject.Lock();
			TaskObject.AcceptedForExecution = True;
			TaskObject.AcceptForExecutionDate = CurrentSessionDate();
			If TaskObject.Performer.IsEmpty() Then
				TaskObject.Performer = Users.CurrentUser();
			EndIf;
			TaskObject.Write();
			
			NewTaskArray.Add(Task);
			
		EndDo;
	CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Tasks = NewTaskArray;
	
EndProcedure

// Marks the specified tasks as not accepted for execution.
//
Procedure CancelAcceptTasksForExecution(Tasks) Export
	
	NewTaskArray = New Array();
	
	BeginTransaction();
	Try
		BusinessProcessesAndTasksServer.LockTasks(Tasks);
			
		For Each Task In Tasks Do
			
			If TypeOf(Task) = Type("DynamicalListGroupRow") Then 
				Continue;
			EndIf;	
			
			TaskObject = Task.GetObject();
			If TaskObject.Executed Then
				Continue;
			EndIf;
			
			TaskObject.Lock();
			TaskObject.AcceptedForExecution = False;
			TaskObject.AcceptForExecutionDate = "00010101000000";
			If Not TaskObject.PerformerRole.IsEmpty() Then
				TaskObject.Performer = Catalogs.Users.EmptyRef();
			EndIf;	
			TaskObject.Write();
			
			NewTaskArray.Add(Task);
			
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Tasks = NewTaskArray;
	
EndProcedure

// Checks whether the specified task is the head one.
//
// Parameters:
//  TaskRef - TaskRef.PerformerTask - task.
//
// Returns:
//   Boolean
//
Function IsHeadTask(TaskRef) Export
	
	SetPrivilegedMode(True);
	Result = BusinessProcessesAndTasksServer.SelectHeadTaskBusinessProcesses(TaskRef);
	Return Not Result.IsEmpty();
		
EndFunction	

// Handler of NewPerformerTaskNotifications scheduled job.
//
Procedure NotifyPerformersOnNewTasks() Export
	
	CommonUse.ScheduledJobOnStart();
	
	// Getting the current server time: CurrentDate().
	NotificationDate = CurrentDate();
	SetPrivilegedMode(True);
	LatestNotificationDate = Constants.NewTasksNotificationDate.Get();
	SetPrivilegedMode(False);
	
	// If no notifications were sent earlier or the last notification was sent more than
	// one day ago, selecting new tasks for the last 24 hours.
	If (LatestNotificationDate = '00010101000000') 
		Or (NotificationDate - LatestNotificationDate > 24*60*60) Then
		LatestNotificationDate = NotificationDate - 24*60*60;
	EndIf;
	
	WriteLogEvent(BusinessProcessesAndTasksServer.EventLogMessageText(),
		EventLogLevel.Information, , ,
		StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Scheduled notification about new tasks for the period %1 - %2 started'"),
			LatestNotificationDate, NotificationDate));
			
	TasksByPerformers = SelectNewTasksByPerformers(LatestNotificationDate, NotificationDate);
	For Each PerformerRow In TasksByPerformers.Rows Do
		SendNotificationOnNewTasks(PerformerRow.Performer, PerformerRow);
	EndDo;
	
	SetPrivilegedMode(True);
	Constants.NewTasksNotificationDate.Set(NotificationDate);
	SetPrivilegedMode(False);
	
	WriteLogEvent(BusinessProcessesAndTasksServer.EventLogMessageText(),
		EventLogLevel.Information, , ,
		StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Scheduled notification about the new tasks sent (performers notified: %1)'"),
			TasksByPerformers.Rows.Count()));
	
EndProcedure

// TaskMonitoring scheduled job handler.
//
Procedure CheckTasks() Export
	
	CommonUse.ScheduledJobOnStart();
	
	OverdueTasks = SelectOverdueTasks();
	If OverdueTasks.Count() = 0 Then
		Return;
	EndIf;
		
	MessageSetByRecipients = SelectOverdueTaskPerformers(OverdueTasks);
	For Each EmailFromSet In MessageSetByRecipients Do
		SendNotificationAboutOverdueTasks(EmailFromSet);
	EndDo;
	
EndProcedure

// Generates a selection list for specifying the performer in input fields of composite type (User and Role)
Function GeneratePerformerChoiceData(Text) Export
	
	ChoiceData = New ValueList;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	Users.Ref AS Ref
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.Description LIKE &Text
	|	AND Users.NotValid = FALSE
	|	AND Users.Internal = FALSE
	|	AND Users.DeletionMark = FALSE
	|
	|UNION ALL
	|
	|SELECT
	|	PerformerRoles.Ref
	|FROM
	|	Catalog.PerformerRoles AS PerformerRoles
	|WHERE
	|	PerformerRoles.Description LIKE &Text
	|	AND Not PerformerRoles.DeletionMark";
	Query.SetParameter("Text", Text + "%");
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		ChoiceData.Add(Selection.Ref);
	EndDo;
	
	Return ChoiceData;
	
EndFunction

// Obsolete. Use TaskExecutionForm instead.
//
// Gets a structure with a description of a task execution form.
//
// Parameters
//  TaskRef - TaskRef.PerformerTask  - task.
//
// Returns:
//   Structure - structure with a description of the task execution form.
//
Function GetTaskPerformForm(Val TaskRef) Export
	
	Return TaskExecutionForm(TaskRef);
	
EndFunction

#EndRegion

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Monitoring and management control of task completion

Function UnloadPerformers(QueryText, MainAddressingObjectRef, AdditionalAddressingObjectRef)
	
	Query = New Query(QueryText);
	
	If ValueIsFilled(AdditionalAddressingObjectRef) Then
		Query.SetParameter("AAO", AdditionalAddressingObjectRef);
	EndIf;
	
	If ValueIsFilled(MainAddressingObjectRef) Then
		Query.SetParameter("MAO", MainAddressingObjectRef);
	EndIf;
	
	Return Query.Execute().Unload();
	
EndFunction

Function FindPerformersByRoles(Val Task, Val BaseQueryText)
	
	UserList = New Array;
	
	MAO = Task.MainAddressingObject;
	AAO = Task.AdditionalAddressingObject;
	
	If ValueIsFilled(AAO) Then
		QueryText = BaseQueryText + " And TaskPerformers.MainAddressingObject = &MAO 
		                                     |And TaskPerformers.AdditionalAddressingObject = &AAO";
	ElsIf ValueIsFilled(MAO) Then
		QueryText = BaseQueryText + 
			" And TaskPerformers.MainAddressingObject = &MAO
		    |= And (TaskPerformers.AdditionalAddressingObject
		    |=
		    |VALUE (ChartOfCharacteristicTypes.TaskAddressingObjects.EmptyRef)
			|   OR TaskPerformers.AdditionalAddressingObject = Undefined)";
	Else
		QueryText = BaseQueryText + 
			" AND (TaskPerformers.MainAddressingObject = 
			|   VALUE(ChartOfCharacteristicTypes.TaskAddressingObjects.EmptyRef) OR
			|   TaskPerformers.MainAddressingObject = Undefined) AND (TaskPerformers.AdditionalAddressingObject = VALUE(ChartOfCharacteristicTypes.TaskAddressingObjects.EmptyRef) OR 
			|   TaskPerformers.AdditionalAddressingObject = Undefined)";
	EndIf;
	
	RetrievedPerformerData = UnloadPerformers(QueryText, MAO, AAO);
	
	// If the main and additional addressing objects are not filled in the task.
	If Not ValueIsFilled(AAO) And Not ValueIsFilled(MAO) Then
		For Each RetrievedDataItem In RetrievedPerformerData Do
			UserList.Add(RetrievedDataItem.Performer);
		EndDo;
		
		Return UserList;
	EndIf;
	
	If RetrievedPerformerData.Count() = 0 And ValueIsFilled(AAO) Then
		QueryText = BaseQueryText + " And TaskPerformers.MainAddressingObject = &MAO 
			|And (TaskPerformers.AdditionalAddressingObject = VALUE (ChartOfCharacteristicTypes.TaskAddressingObjects.EmptyRef)
			|   OR TaskPerformers.AdditionalAddressingObject = Undefined)";
		RetrievedPerformerData = UnloadPerformers(QueryText, MAO, Undefined);
	EndIf;
	
	If RetrievedPerformerData.Count() = 0 Then
		QueryText = BaseQueryText + " AND (TaskPerformers.MainAddressingObject = VALUE(ChartOfCharacteristicTypes.TaskAddressingObjects.EmptyRef)
			|   OR TaskPerformers.MainAddressingObject = Undefined) 
     |AND (TaskPerformers.AdditionalAddressingObject = VALUE(ChartOfCharacteristicTypes.TaskAddressingObjects.EmptyRef)  
			|   OR TaskPerformers.AdditionalAddressingObject = Undefined)";
		RetrievedPerformerData = UnloadPerformers(QueryText, Undefined, Undefined);
	EndIf;
	
	For Each RetrievedDataItem In RetrievedPerformerData Do
		UserList.Add(RetrievedDataItem.Performer);
	EndDo;
	
	Return UserList;
	
EndFunction

Function FindResponsibleForRoleAssignment(Val Task)
	
	BaseQueryText = "SELECT DISTINCT ALLOWED TaskPerformers.Performer
	                      |FROM
	                      |	InformationRegister.TaskPerformers As TaskPerformers, Catalog.PerformerRoles As PerformerRoles
	                      |Where
	                      |	TaskPerformers.PerformerRole = PerformerRoles.Ref
	                      |AND
	                      |	PerformerRoles.Ref = VALUE(Catalog.PerformerRoles.ResponsibleForCompletionControl)";
						  
	Responsible = FindPerformersByRoles(Task, BaseQueryText);
	Return Responsible;
	
EndFunction

Function SelectTaskPerformers(Val Task)
	
	QueryText = "SELECT DISTINCT ALLOWED
				  |	TaskPerformers.Performer AS Performer
				  |FROM
				  |	InformationRegister.TaskPerformers AS TaskPerformers
				  |WHERE
				  |	TaskPerformers.PerformerRole = &PerformerRole
				  |	AND TaskPerformers.MainAddressingObject = &MainAddressingObject
				  |	AND TaskPerformers.AdditionalAddressingObject = &AdditionalAddressingObject";
				  
	Query = New Query(QueryText);
	Query.Parameters.Insert("PerformerRole", Task.PerformerRole);
	Query.Parameters.Insert("MainAddressingObject", Task.MainAddressingObject);
	Query.Parameters.Insert("AdditionalAddressingObject", Task.AdditionalAddressingObject);
	Performers = Query.Execute().Unload();
	Return Performers;
	
EndFunction

Procedure FindMessageAndAddText(Val MessageSetByRecipients,
                                  Val EmailRecipient,
                                  Val MessageRecipientPresentation,
                                  Val EmailText,
                                  Val EmailType)
	
	FilterParameters = New Structure("EmailType, MailAddress", EmailType, EmailRecipient);
	EmailParametersRow = MessageSetByRecipients.FindRows(FilterParameters);
	If EmailParametersRow.Count() = 0 Then
		EmailParametersRow = Undefined;
	Else
		EmailParametersRow = EmailParametersRow[0];
	EndIf;
	
	If EmailParametersRow = Undefined Then
		EmailParametersRow = MessageSetByRecipients.Add();
		EmailParametersRow.MailAddress = EmailRecipient;
		EmailParametersRow.EmailText = "";
		EmailParametersRow.TaskQuantity = 0;
		EmailParametersRow.EmailType = EmailType;
		EmailParametersRow.Recipient = MessageRecipientPresentation;
	EndIf;
	
	If ValueIsFilled(EmailParametersRow.EmailText) Then
		EmailParametersRow.EmailText =
		        EmailParametersRow.EmailText + Chars.LF
		        + "------------------------------------"  + Chars.LF;
	EndIf;
	
	EmailParametersRow.TaskQuantity = EmailParametersRow.TaskQuantity + 1;
	EmailParametersRow.EmailText = EmailParametersRow.EmailText + EmailText;
	
EndProcedure

Function SelectOverdueTasks()
	
	QueryText = 
		"SELECT ALLOWED
		|	PerformerTask.Ref AS Ref,
		|	PerformerTask.DueDate AS DueDate,
		|	PerformerTask.Performer AS Performer,
		|	PerformerTask.PerformerRole AS PerformerRole,
		|	PerformerTask.MainAddressingObject AS MainAddressingObject,
		|	PerformerTask.AdditionalAddressingObject AS AdditionalAddressingObject,
		|	PerformerTask.Author AS Author,
		|	PerformerTask.Description AS Description
		|FROM
		|	Task.PerformerTask AS PerformerTask
		|WHERE
		|	PerformerTask.DeletionMark = FALSE
		|	AND PerformerTask.Executed = FALSE
		|	AND PerformerTask.DueDate <= &Date
		|	AND PerformerTask.BusinessProcessState <> VALUE(Enum.BusinessProcessStates.Stopped)";
	
	DueDate = EndOfDay(CurrentSessionDate());

	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Date", DueDate);
	
	OverdueTasks = Query.Execute().Unload();
	Return OverdueTasks;
	
EndFunction

Function SelectOverdueTaskPerformers(OverdueTasks)
	
	MessageSetByRecipients = New ValueTable;
	MessageSetByRecipients.Columns.Add("MailAddress");
	MessageSetByRecipients.Columns.Add("EmailText");
	MessageSetByRecipients.Columns.Add("TasksQuantity");
	MessageSetByRecipients.Columns.Add("EmailType");
	MessageSetByRecipients.Columns.Add("Recipient");
	
	For Each OverdueTasksItem In OverdueTasks Do
		OverdueTask = OverdueTasksItem.Ref;
		
		EmailText = GenerateTaskPresentation(OverdueTasksItem);
		// Is the task addressed to a performer personally?
		If ValueIsFilled(OverdueTask.Performer) Then
			EmailRecipient = "";
			BusinessProcessesAndTasksServer.OnReceiveEmailAddress(OverdueTask.Performer, EmailRecipient);
			FindMessageAndAddText(MessageSetByRecipients, EmailRecipient, OverdueTask.Performer, EmailText, "ToPerformer");
			EmailRecipient = "";
			BusinessProcessesAndTasksServer.OnReceiveEmailAddress(OverdueTask.Author, EmailRecipient);
			FindMessageAndAddText(MessageSetByRecipients, EmailRecipient, OverdueTask.Author, EmailText, "ToAuthor");
		Else
			Performers = SelectTaskPerformers(OverdueTask);
			Coordinators = FindResponsibleForRoleAssignment(OverdueTask);
			// Is there at least one performer for the task role addressing?
			If Performers.Count() > 0 Then
				// The performers do not execute their tasks.
				For Each Performer In Performers Do
					EmailRecipient = "";
					BusinessProcessesAndTasksServer.OnReceiveEmailAddress(Performer.Performer, EmailRecipient);
					FindMessageAndAddText(MessageSetByRecipients, EmailRecipient, Performer.Performer, EmailText, "ToPerformer");
				EndDo;
			Else	// There is no one to execute the task
				CreateTaskByRoleConfiguration(OverdueTask, Coordinators);
			EndIf;
			
			For Each Coordinator In Coordinators Do
				EmailRecipient = "";
				BusinessProcessesAndTasksServer.OnReceiveEmailAddress(Coordinator, EmailRecipient);
				FindMessageAndAddText(MessageSetByRecipients, EmailRecipient, Coordinator, EmailText, "ToCoordinator");
			EndDo;
		EndIf;
	EndDo;
	
	Return MessageSetByRecipients;
	
EndFunction

Procedure SendNotificationAboutOverdueTasks(EmailFromSet)
	
	If IsBlankString(EmailFromSet.MailAddress) Then
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Cannot send the notification as user% 1 does not have email address specified.'"), 
			EmailFromSet.Recipient);
		WriteLogEvent(NStr("en = 'Business processes and tasks.Overdue tasks notification'", 
			CommonUseClientServer.DefaultLanguageCode()),
			EventLogLevel.Information,,, MessageText);
		Return;
	EndIf;
	
	EmailParameters = New Structure;
	EmailParameters.Insert("Recipient", EmailFromSet.MailAddress);
	If EmailFromSet.EmailType = "ToPerformer" Then
		MessageBodyText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Overdue tasks:
				| 
				|%1'"), EmailFromSet.EmailText);
		EmailParameters.Insert("Body", MessageBodyText);
		
		MessageSubjectText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Overdue tasks (%1)'"),
			String(EmailFromSet.TasksQuantity ));
		EmailParameters.Insert("Subject", MessageSubjectText);
	ElsIf EmailFromSet.EmailType = "ToAuthor" Then
		MessageBodyText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'The following tasks that you created are overdue:
			   | 
			   |%1'"), EmailFromSet.EmailText);
		EmailParameters.Insert("Body", MessageBodyText);
		
		MessageSubjectText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Overdue tasks (%1)'"),
			String(EmailFromSet.TasksQuantity));
		EmailParameters.Insert("Subject", MessageSubjectText);
	ElsIf EmailFromSet.EmailType = "ToCoordinator" Then
		MessageBodyText = StringFunctionsClientServer.SubstituteParametersInString(
			 NStr("en = 'Overdue tasks:
				| 
				|%1'"), EmailFromSet.EmailText);
		EmailParameters.Insert("Body", MessageBodyText);
		
		MessageSubjectText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Overdue tasks (%1)'"),
			String(EmailFromSet.TasksQuantity));
		EmailParameters.Insert("Subject", MessageSubjectText);
	EndIf;
	
	MessageText = "";
	
	Try
		EmailOperations.SendEmailMessage(
			EmailOperations.SystemAccount(), EmailParameters);
	Except
		ErrorDescription = DetailErrorDescription(ErrorInfo());
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Error sending overdue task notification: %1.'"),
			ErrorDescription);
		EventImportanceLevel = EventLogLevel.Error;
	EndTry;
	
	If IsBlankString(MessageText) Then
		If EmailParameters.Recipient.Count() > 0 Then
			Recipient = ? (IsBlankString(EmailParameters.Recipient[0].Presentation),
						EmailParameters.Recipient[0].Address,
						EmailParameters.Recipient[0].Presentation + " <" + EmailParameters.Recipient[0].Address + ">");
		EndIf;
		
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Overdue task notification sent to %1.'"), Recipient);
							
		EventImportanceLevel = EventLogLevel.Information;
	EndIf;
	
	WriteLogEvent(NStr("en = 'Business processes and tasks.Overdue task notification'",
		CommonUseClientServer.DefaultLanguageCode()), 
		EventImportanceLevel,,, MessageText);
		
EndProcedure

Function CreateTaskByRoleConfiguration(TaskRef, Responsible)
	
	For Each Responsible In Responsible Do
		TaskObject = Tasks.PerformerTask.CreateTask();
		TaskObject.Date = CurrentSessionDate();
		TaskObject.Importance = Enums.TaskImportanceVariants.High;
		TaskObject.Performer = Responsible;
		TaskObject.Subject = TaskRef;

		TaskObject.Description =
		StringFunctionsClientServer.SubstituteParametersInString(
		  NStr("en = 'The task cannot be executed as the role has no performers specified:
		             |%1'"), String(TaskRef));
		
		TaskObject.Description =
		StringFunctionsClientServer.SubstituteParametersInString(
		  NStr("en = 'Assign performers: task %1 cannot be executed'"), String(TaskRef));
		
		TaskObject.Write();
	EndDo;
	
EndFunction

Function SelectNewTasksByPerformers(Val DateTimeFrom, Val DateTimeTo)
	
	Query = New Query(
		"SELECT ALLOWED
		|	PerformerTask.Ref AS Ref,
		|	PerformerTask.Number AS Number,
		|	PerformerTask.Date AS Date,
		|	PerformerTask.Description AS Description,
		|	PerformerTask.DueDate AS DueDate,
		|	PerformerTask.Author AS Author,
		|	SUBSTRING(PerformerTask.Description, 1, 250) AS Description,
		|	CASE
		|		WHEN PerformerTask.Performer IS Not NULL 
		|				AND PerformerTask.Performer <> VALUE(Catalog.Users.EmptyRef)
		|			THEN PerformerTask.Performer
		|		ELSE TaskPerformers.Performer
		|	END AS Performer,
		|	PerformerTask.PerformerRole AS PerformerRole,
		|	PerformerTask.MainAddressingObject AS MainAddressingObject,
		|	PerformerTask.AdditionalAddressingObject AS AdditionalAddressingObject
		|FROM
		|	Task.PerformerTask AS PerformerTask
		|		LEFT JOIN InformationRegister.TaskPerformers AS TaskPerformers
		|		ON PerformerTask.PerformerRole = TaskPerformers.PerformerRole
		|			AND PerformerTask.MainAddressingObject = TaskPerformers.MainAddressingObject
		|			AND PerformerTask.AdditionalAddressingObject = TaskPerformers.AdditionalAddressingObject
		|WHERE
		|	PerformerTask.DeletionMark = FALSE
		|	AND PerformerTask.Date > &DateTimeFrom
		|	AND PerformerTask.Date <= &DateTimeTo
		|	AND (PerformerTask.Performer IS Not NULL 
		|				AND PerformerTask.Performer <> VALUE(Catalog.Users.EmptyRef)
		|			OR TaskPerformers.Performer IS Not NULL 
		|				AND TaskPerformers.Performer <> VALUE(Catalog.Users.EmptyRef))
		|	AND PerformerTask.Executed = FALSE
		|
		|ORDER BY
		|	Performer,
		|	DueDate DESC
		|TOTALS BY
		|	Performer");
	Query.Parameters.Insert("DateTimeFrom", DateTimeFrom);
	Query.Parameters.Insert("DateTimeTo", DateTimeTo);
	Result = Query.Execute().Unload(QueryResultIteration.ByGroups);
	Return Result;
	
EndFunction

Function SendNotificationOnNewTasks(Performer, TasksByPerformer)
	
	RecipientEmailAddress = "";
	BusinessProcessesAndTasksServer.OnReceiveEmailAddress(Performer, RecipientEmailAddress);
	If IsBlankString(RecipientEmailAddress) Then
		WriteLogEvent(NStr("en = 'Business processes and tasks.New task notification'",
			CommonUseClientServer.DefaultLanguageCode()), 
			EventLogLevel.Information,,,
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Cannot send a notification as user %1 does not have email address specified.'"), String(Performer)));
		Return False;
	EndIf;
	
	EmailText = "";
	For Each Task In TasksByPerformer.Rows Do
		EmailText = EmailText + GenerateTaskPresentation(Task);
	EndDo;
	EmailSubject = StringFunctionsClientServer.SubstituteParametersInString(
		  NStr("en = 'Tasks sent: %1'"), Metadata.BriefInformation);
	
	EmailParameters = New Structure;
	EmailParameters.Insert("Subject", EmailSubject);
	EmailParameters.Insert("Body", EmailText);
	EmailParameters.Insert("Recipient", RecipientEmailAddress);
	
	Try 
		EmailOperations.SendEmailMessage(
			EmailOperations.SystemAccount(), EmailParameters);
	Except
		WriteLogEvent(NStr("en = 'Business processes and tasks. New task notification'",
			CommonUseClientServer.DefaultLanguageCode()), 
			EventLogLevel.Error,,,
			StringFunctionsClientServer.SubstituteParametersInString(
			   NStr("en = 'Error sending new task notifications: %1'"), 
			   DetailErrorDescription(ErrorInfo())));
		Return False;
	EndTry;

	WriteLogEvent(NStr("en = 'Business processes and tasks.New task notifications'",
		CommonUseClientServer.DefaultLanguageCode()),
		EventLogLevel.Information,,,
		StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Notifications sent to %1.'"), RecipientEmailAddress));
	Return True;	
		
EndFunction

Function GenerateTaskPresentation(TaskStructure)
	
	StringPattern = 
		NStr("en = '%1
   |
   |Deadline: %2'") + Chars.LF;
	If ValueIsFilled(TaskStructure.Performer) Then
		StringPattern = StringPattern + NStr("en = 'Performer: %3'") + Chars.LF;
	EndIf;
	If ValueIsFilled(TaskStructure.PerformerRole) Then
		StringPattern = StringPattern + NStr("en = 'Role: %4'") + Chars.LF;
	EndIf;
	If ValueIsFilled(TaskStructure.MainAddressingObject) Then
		StringPattern = StringPattern + NStr("en = 'Main  addressing object: %5'") + Chars.LF;
	EndIf;
	If ValueIsFilled(TaskStructure.AdditionalAddressingObject) Then
		StringPattern = StringPattern + NStr("en = 'Additional addressing object: %6'") + Chars.LF;
	EndIf;
	If ValueIsFilled(TaskStructure.Author) Then
		StringPattern = StringPattern + NStr("en = 'Author: %7'") + Chars.LF;
	EndIf;
	If ValueIsFilled(TaskStructure.Description) Then
		StringPattern = StringPattern + Chars.LF + NStr("en = '%8'") + Chars.LF;
	EndIf;
	StringPattern = StringPattern + Chars.LF;
	
	Return StringFunctionsClientServer.SubstituteParametersInString(StringPattern,
		TaskStructure.Ref, 
		Format(TaskStructure.DueDate, "DLF=DD; Am='not specified'"), TaskStructure.Performer,
		TaskStructure.PerformerRole, TaskStructure.MainAddressingObject, 
		TaskStructure.AdditionalAddressingObject, TaskStructure.Author,
		TaskStructure.Description);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Other internal procedures and functions.

// Returns the number of uncompleted tasks for the specified business processes.
//
Function UncompletedBusinessProcessesTasksCount(BusinessProcesses) Export
	
	TaskQuantity = 0;
	
	For Each BusinessProcess In BusinessProcesses Do
		
		If TypeOf(BusinessProcess) = Type("DynamicalListGroupRow") Then
			Continue;
		EndIf;
		
		TaskQuantity = TaskQuantity + UncompletedBusinessProcessTasksCount(BusinessProcess);
		
	EndDo;
		
	Return TaskQuantity;
	
EndFunction

// Returns the number of uncompleted tasks for the specified business process.
//
Function UncompletedBusinessProcessTasksCount(BusinessProcess) Export
	
	If TypeOf(BusinessProcess) = Type("DynamicalListGroupRow") Then
		Return 0;
	EndIf;	
	
	Query = New Query;
	Query.Text = "SELECT
	               |	COUNT(*) AS Quantity
	               |FROM
	               |	Task.PerformerTask AS Tasks
	               |WHERE
	               |	Tasks.BusinessProcess = &BusinessProcess
	               |	AND Tasks.Executed = False";
				   
	Query.SetParameter("BusinessProcess", BusinessProcess);			   
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Return Selection.Quantity;
	
EndFunction

// Marks the specified business processes for deletion.
//
Function MarkBusinessProcessesForDeletion(SelectedRows) Export
	Quantity = 0;
	For Each TableRow In SelectedRows Do
		BusinessProcessRef = TableRow.BusinessProcess;
		If BusinessProcessRef = Undefined Or BusinessProcessRef.IsEmpty() Then
			Continue;
		EndIf;	
		BeginTransaction();
		Try
			BusinessProcessesAndTasksServer.LockBusinessProcesses(BusinessProcessRef);
			BusinessProcessObject = BusinessProcessRef.GetObject();
			BusinessProcessObject.SetDeletionMark(Not BusinessProcessObject.DeletionMark);
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
		Quantity = Quantity + 1;
	EndDo;
	Return ?(Quantity = 1, SelectedRows[0].BusinessProcess, Undefined);
EndFunction

Procedure OnForwardTask(TaskObject, NewTaskObject) 
	
	If TaskObject.BusinessProcess.IsEmpty() Then
		Return;
	EndIf;
	
	BusinessProcessType = TaskObject.BusinessProcess.Metadata();
	Try
		BusinessProcesses[BusinessProcessType.Name].OnForwardTask(TaskObject.Ref, NewTaskObject.Ref);
	Except
		// method not defined
	EndTry;
	
EndProcedure

// Returns True if the task corresponds to the specified route point.
Function CheckTaskType(TaskObject, RoutePoint) Export
	
	Return TaskObject.RoutePoint = RoutePoint;
	
EndFunction

#EndRegion
