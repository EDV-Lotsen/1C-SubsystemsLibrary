////////////////////////////////////////////////////////////////////////////////
// Business processes and tasks subsystem
//  
////////////////////////////////////////////////////////////////////////////////

#Region Interface

////////////////////////////////////////////////////////////////////////////////
// Commands for business process operation

// Marks the specified business process as stopped.
//
Procedure Stop(Val CommandParameter) Export
	
	QuestionText = "";
	TaskCount = 0;
	
	If TypeOf(CommandParameter) = Type("Array") 
Then
		
		If CommandParameter.Count() = 0 Then
			ShowMessageBox(,NStr("en= 'No business processes are selected.'"));
			Return;
		EndIf;	
		
		If CommandParameter.Count() = 1 And TypeOf(CommandParameter[0]) = Type("DynamicalListGroupRow") Then
			ShowMessageBox(,NStr("en= 'No business processes are selected.'"));
			Return;
		EndIf;	
		
		TaskCount = BusinessProcessesAndTasksServerCall.UncompletedBusinessProcessesTasksCount(CommandParameter);
		If CommandParameter.Count() = 1 Then
			If TaskCount > 0 Then
				QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Business process ""%1"" and all its uncompleted tasks (%2) will be stopped. Do you want to continue?'"), 
					String(CommandParameter[0]), TaskCount);
			Else
				QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Business process ""%1"" will be stopped. Do you want to continue?'"), 
					String(CommandParameter[0]));
			EndIf;		
		Else
			QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Business processes (%1) and all of their uncompleted tasks (%2) will be stopped. Do you want to continue?'"), 
				CommandParameter.Count(), TaskCount);
		EndIf;		
		
	Else
		
		If TypeOf(CommandParameter) = Type("DynamicalListGroupRow") Then
			ShowMessageBox(,NStr("en= 'No business processes are selected'"));
			Return;
		EndIf;	
		
		TaskCount = BusinessProcessesAndTasksServerCall.UncompletedBusinessProcessTasksCount(CommandParameter);
		If TaskCount > 0 Then
			QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Business process ""%1"" and all its uncompleted tasks (%2) will be stopped. Do you want to continue?'"), 
				String(CommandParameter), TaskCount);
		Else
			QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Business process ""%1"" will be stopped. Do you want to continue?'"), 
				String(CommandParameter));
		EndIf;		
			
	EndIf;
	
	Notification = New NotifyDescription(
"StopCompletion", ThisObject, CommandParameter);
	ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.No, NStr("en = 'Stopping business process'"));
	
EndProcedure

// Marks the specified business process as stopped.
// The procedure is intended for calling from a business process form.
//
Procedure StopBusinessProcessFromObjectForm(Form) Export
	
	Form.Object.State = PredefinedValue("Enum.BusinessProcessStates.Stopped");
	Form.Write();
	ShowUserNotification(
		NStr("en = 'The business process is stopped'"),
		GetURL(Form.Object.Ref),
		String(Form.Object.Ref),
		PictureLib.Information32);
	NotifyChanged(Form.Object.Ref);
	
EndProcedure

// Marks the specified business process as active.
//
Procedure Activate(Val CommandParameter) Export
	
	QuestionText = "";
	TaskCount = 0;
	
	If TypeOf(CommandParameter) = Type("Array") Then
		
		If CommandParameter.Count() = 0 Then
			ShowMessageBox(,NStr("en= 'No business processes are selected.'"));
			Return;
		EndIf;	
		
		If CommandParameter.Count() = 1 And TypeOf(CommandParameter[0]) = Type("DynamicalListGroupRow") Then
			ShowMessageBox(,NStr("en= 'No business processes are selected.'"));
			Return;
		EndIf;	
		
		TaskCount = BusinessProcessesAndTasksServerCall.UncompletedBusinessProcessesTasksCount(CommandParameter);
		If CommandParameter.Count() = 1 Then
			QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Business process ""%1"" and all its tasks (%2) will be activated. Do you want to continue?'"), 
				String(CommandParameter[0]), TaskCount);
		Else		
			QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Business processes (%1) and all of their tasks (%2) will be activated. Do you want to continue?'"), 
				CommandParameter.Count(), TaskCount);
		EndIf;		
		
	Else
		
		If TypeOf(CommandParameter) = Type("DynamicalListGroupRow") Then
			ShowMessageBox(,NStr("en= 'No business processes are selected.'"));
			Return;
		EndIf;	
		
		TaskCount = BusinessProcessesAndTasksServerCall.UncompletedBusinessProcessTasksCount(CommandParameter);
		QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Business process ""%1"" and all its tasks (%2) will be activated. Do you want to continue?'"), 
			String(CommandParameter), TaskCount);
			
	EndIf;
	
	Notification = New NotifyDescription("ActivateCompletion", ThisObject, CommandParameter);
	ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.No, NStr("en = 'Stop business process'"));
	
EndProcedure

// Marks the specified business process as active.
// The procedure is intended for calling from a business process form.
//
Procedure ContinueBusinessProcessFromObjectForm(Form) Export
	
	Form.Object.State = PredefinedValue("Enum.BusinessProcessStates.Active");
	Form.Write();
	ShowUserNotification(
		NStr("en = 'The business process is activated'"),
		GetURL(Form.Object.Ref),
		String(Form.Object.Ref),
		PictureLib.Information32);
	NotifyChanged(Form.Object.Ref);
	
EndProcedure

// Marks the specified tasks as accepted for execution.
//
Procedure AcceptTasksForExecution(Val TaskArray) Export
	
	BusinessProcessesAndTasksServerCall.AcceptTasksForExecution(TaskArray);
	If TaskArray.Count() = 0 Then
		ShowMessageBox(,NStr("en = 'Cannot execute the command for the specified object.'"));
		Return;
	ElsIf TaskArray.Count() <> 1 Then
		Status(NStr("en = 'The tasks are accepted for execution.'"));
	Else		
		Status(NStr("en = 'The task is accepted for execution.'"));
	EndIf;	
	
	TaskValueType = Undefined;
	For Each Task In TaskArray Do
		If TypeOf(Task) <> Type("DynamicalListGroupRow") Then 
			TaskValueType = TypeOf(Task);
			Break;
		EndIf;	
	EndDo;	
	If TaskValueType <> Undefined Then
		NotifyChanged(TaskValueType);
	EndIf;	
	
EndProcedure

// Marks the specified task as accepted for execution.
//
Procedure AcceptTaskForExecution(Form, CurrentUser) Export
	
	Form.Object.AcceptedForExecution = True;
	
	// Setting empty AcceptForExecutionDate. It will be initialized with the current session date before writing the task.
	Form.Object.AcceptForExecutionDate = Date('00010101');
	If Form.Object.Performer.IsEmpty() Then
		Form.Object.Performer = CurrentUser;
	EndIf;	
			
	Form.Write();
	Status(NStr("en = 'The task is accepted for execution.'"));
	UpdateAcceptForExecutionCommandsEnabled(Form);
	NotifyChanged(Form.Object.Ref);
	
EndProcedure

// Marks the specified tasks as not accepted for execution.
//
Procedure CancelAcceptTasksForExecution(Val TaskArray) Export
	
	BusinessProcessesAndTasksServerCall.CancelAcceptTasksForExecution(TaskArray);
	If TaskArray.Count() = 0 Then
		ShowMessageBox(,NStr("en = 'Cannot execute the command for the specified object.'"));
		Return;
	ElsIf TaskArray.Count() <> 1 Then
		Status(NStr("en = 'The tasks are marked as NOT accepted for execution.'"));
	Else		
		Status(NStr("en = 'The task is marked as NOT accepted for execution.'"));
	EndIf;		
	
	TaskValueType = Undefined;
	For Each Task In TaskArray Do
		If TypeOf(Task) <> Type("DynamicalListGroupRow") Then 
			TaskValueType = TypeOf(Task);
			Break;
		EndIf;	
	EndDo;	
	If TaskValueType <> Undefined Then
		NotifyChanged(TaskValueType);
	EndIf;	
	
EndProcedure

// Marks the specified task as not accepted for execution.
//
Procedure CancelAcceptTaskForExecution(Form) Export
	
	Form.Object.AcceptedForExecution = False;
	Form.Object.AcceptForExecutionDate = "00010101000000";
	If Not Form.Object.PerformerRole.IsEmpty() Then
		Form.Object.Performer = PredefinedValue("Catalog.Users.EmptyRef");
	EndIf;	
	
	Form.Write();
	Status(NStr("en = 'The task is marked as NOT accepted for execution.'"));
	UpdateAcceptForExecutionCommandsEnabled(Form);
	NotifyChanged(Form.Object.Ref);
	
EndProcedure

// Sets the availability of the commands for accepting tasks for execution.
//
Procedure UpdateAcceptForExecutionCommandsEnabled(Form) Export
	
	If Form.Object.AcceptedForExecution = True 
Then
		Form.Items.FormAcceptForExecution.Enabled = False;
		
		If Form.Object.Executed Then
			Form.Items.FormCancelAcceptForExecution.Enabled = False;
		Else
			Form.Items.FormCancelAcceptForExecution.Enabled = True;
		EndIf;
		
	Else	
 
		Form.Items.FormAcceptForExecution.Enabled = True;
 
		Form.Items.FormCancelAcceptForExecution.Enabled = False;
	EndIf;	
		
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Additional procedures and functions

// Standard notification handler for task execution forms.
// The procedure is intended for calling the NotificationProcessing form from an event handler.
//
// Parameters
//  Form       - ManagedForm     - task execution form.
//  EventName  - String          - event name.
//  Parameter  - arbitrary type  - event parameter
//  Source     - arbitrary type  - event source.
//
Procedure TaskFormNotificationProcessing(Form, EventName, Parameter, Source) Export
	
	If EventName = "Write_PerformerTask" 
		And Not Form.Modified 
		And (Source = Form.Object.Ref Or (TypeOf(Source) = Type("Array") 
		And Source.Find(Form.Object.Ref) <> Undefined)) Then
		If Parameter.Property("Redirected") Then
			Form.Close();
		Else
			Form.Read();
		EndIf;
	EndIf;
	
EndProcedure

// Standard BeforeAddRow handler for task lists.
// The procedure is intended for calling from the handler of the BeforeAddRow table form event.
//
// Parameters
//   are identical to the parameters of the BeforeAddRow table form event handler.
//
Procedure TaskListBeforeAddRow(Form, Item, Cancel, Clone, Parent, Group) Export
	
	If Clone Then
		Task = Item.CurrentRow;
		If Not ValueIsFilled(Task) Then
			Return;
		EndIf;
		FormParameters = New Structure("Base", Task);
	EndIf;
	CreateJob(Form, FormParameters);
	Cancel = True;
	
EndProcedure

// Saves and closes the task execution form.
//
// Parameters
//  Form - ManagedForm - task execution form.
//  ExecuteTask - Boolean - the task is written in execution mode.
//  NotificationParameters - Structure - additional notification parameters.
//
// Returns:
//   Boolean - True if the writing is successful.
//
Function WriteAndCloseExecute(Form, ExecuteTask = False, NotificationParameters = Undefined) Export
	
	ClearMessages();
	
	NewObject = Form.Object.Ref.IsEmpty();
	NotificationText = "";
	If NotificationParameters = Undefined Then
		NotificationParameters = New Structure;
	EndIf;
	If Not Form.InitialExecutionFlag And 
ExecuteTask Then
		If Not Form.Write(New Structure("ExecuteTask", True)) Then
			Return False;
		EndIf;
		NotificationText = NStr("en = 'The task is executed'");
	Else
		If Not Form.Write() Then
			Return False;
		EndIf;
		NotificationText = ?(NewObject, NStr("en = 'The task is created'"), NStr("en = 'The task is changed'"));
	EndIf;
	
	Notify("Write_PerformerTask", NotificationParameters, Form.Object.Ref);
	ShowUserNotification(NotificationText,
		GetURL(Form.Object.Ref),
		String(Form.Object.Ref),
		PictureLib.Information32);
	Form.Close();
	Return True;
	
EndFunction

// Opens a task creation form.
//
// Parameters
//  OwnerForm      - ManagedForm - form that should be the owner for the form being opened.
//  FormParameters - Structure  - parameters of the form being opened.
//
Procedure CreateJob(Val OwnerForm = Undefined, Val FormParameters = Undefined) Export
	
	OpenForm("BusinessProcess.Job.ObjectForm", FormParameters, OwnerForm);
	
EndProcedure	

// Open a form for forwarding one or several tasks to another performer.
//
// Parameters
//  TaskArray  - Array - list of tasks to be forwarded.
//  OwnerForm - ManagedForm - form that should be the owner for the form being opened.
//
Procedure ForwardTasks(TaskArray, OwnerForm) Export

	If TaskArray = Undefined Then
		ShowMessageBox(,NStr("en = 'No tasks are selected.'"));
		Return;
	EndIf;
		
	TasksCanBeForwarded = BusinessProcessesAndTasksServerCall.ForwardTasks(
		TaskArray, Undefined, True);
	If Not TasksCanBeForwarded And 
TaskArray.Count() = 1 Then
		ShowMessageBox(,NStr("en = 'You cannot forward a completed task.'"));
		Return;
	EndIf;
		
	Notification = New NotifyDescription("ForwardTasksCompletion", ThisObject, TaskArray);
	OpenForm("Task.PerformerTask.Form.ForwardTasks",
		New Structure("Task,TaskQuantity,FormTitle", 
		TaskArray[0], TaskArray.Count(), 
		?(TaskArray.Count() > 1, NStr("en = 'Forward tasks'"), 
			NStr("en = 'Forward task'"))), 
		OwnerForm,,,,Notification);
		
EndProcedure

// Open the form with additional information about the task.  
//
// Parameters
//  TaskRef - PerformerTaskRef - task.
//
Function OpenAdditionalTaskInfo(Val TaskRef) Export
	
	OpenForm
("Task.PerformerTask.Form.Advanced", 
		New Structure("Key", TaskRef));
	
EndFunction

// Obsolete. It is not required anymore.
//
// Standard Selection handler for task lists.
// The procedure is intended for calling from the Selection event handler of a form table.
//
// Parameters
//   are identical to the parameters of the Selection form table event handler.
//
Procedure TaskListChoice(Item, SelectedRow, Field, StandardProcessing) Export
	
EndProcedure

// Obsolete. It is not required anymore.
//
// Standard BeforeChangeStart handler for task lists.
// The procedure is intended for calling from the BeforeChangeStart event handler of a form table.
//
// Parameters
//   are identical to the parameters of the BeforeChangeStart table form event handler.
//
Procedure TaskListBeforeChangeStart(Item, Cancel) Export
	
EndProcedure

// Obsolete. It is not required anymore.
// Call the following script instead:
//
//   ShowValue (, TaskRef);
//
// Opens the task execution form provided by the business process.  
//
// Parameters
//  TaskRef - PerformerTaskRef - task.
//
// Returns:
//   Boolean - True if the task execution form is found and opened.
//
Function OpenTaskExecutionForm(Val 
TaskRef) Export
	
	FormParameters = BusinessProcessesAndTasksServerCall.TaskExecutionForm(TaskRef);
	TaskExecutionFormName = "";
	Result = FormParameters.Property("FormName", TaskExecutionFormName);
	If Result Then
		OpenForm(TaskExecutionFormName, FormParameters.FormParameters);
	EndIf; 
	Return Result;
	
EndFunction

#EndRegion

#Region InternalProceduresAndFunctions

Procedure OpenBusinessProcess(List) Export
	If TypeOf(List.CurrentRow) <> Type("TaskRef.PerformerTask") Then
		ShowMessageBox(,NStr("en = 'Cannot execute the command for the specified object.'"));
		Return;
	EndIf;
	If List.CurrentData.BusinessProcess = 
Undefined Then
		ShowMessageBox(,NStr("en = 'The business process of the selected task is not specified'"));
		Return;
	EndIf;
	ShowValue(, List.CurrentData.BusinessProcess);
EndProcedure

Procedure OpenTaskSubject(List) Export
	If TypeOf(List.CurrentRow) <> Type("TaskRef.PerformerTask") Then
		ShowMessageBox(,NStr("en = 'Cannot execute the command for the specified object.'"));
		Return;
	EndIf;
	If List.CurrentData.Subject = Undefined 
Then
		ShowMessageBox(,NStr("en = 'The subject of the selected task is not specified.'"));
		Return;
	EndIf;
	ShowValue(, List.CurrentData.Subject);
EndProcedure

// Standard DeletionMark handler for business-process lists.
// The procedure is intended for calling from the DeletionMark event handler of a list.
//
// Parameters
//   List - FormTable  - form control (form table) with a list of business processes.
//
Procedure BusinessProcessListDeletionMark(List) Export
	
	SelectedRows = List.SelectedRows;
	If SelectedRows = Undefined Or SelectedRows.Count() <= 0 Then
		ShowMessageBox(,NStr("en = 'Cannot execute the command for the specified object.'"));
		Return;
	EndIf;
	Notification = New NotifyDescription("BusinessProcessListDeletionMarkCompletion", ThisObject, List);
	ShowQueryBox(Notification, NStr("en = 'Change deletion mark?'"), QuestionDialogMode.YesNo);
	
EndProcedure

// Opens the performer selection form.
//
// Parameters:
//   PerformerItem - form item where the performer is selected.
//      The selected performer is specified as the owner of the performer selection form. 
//   PerformerAttribute - previously selected performer value.
//      It is used for setting the current row in the performer selection form. 
//   SimpleRolesOnly - Boolean - if True, only roles without
//    addressing objects are used in the selection. 
// WithoutExternalRoles	- Boolean - if True, only roles
//      without the ExternalRole flag are used in the selection.
//
Procedure SelectPerformer(PerformerItem, PerformerAttribute, SimpleRolesOnly = False, WithoutExternalRoles = False) Export 
	
	StandardProcessing = True;
	BusinessProcessesAndTasksClientOverridable.OnSelectPerformer(PerformerItem, PerformerAttribute, 
		SimpleRolesOnly, WithoutExternalRoles, StandardProcessing);
	If Not StandardProcessing Then
		Return;
	EndIf;
			
	FormParameters = New Structure("Performer, SimpleRolesOnly, WithoutExternalRoles", 
		PerformerAttribute, SimpleRolesOnly, WithoutExternalRoles);
	OpenForm("CommonForm.SelectBusinessProcessPerformer", FormParameters, PerformerItem);
	
EndProcedure	

Procedure StopCompletion(Val Result, Val CommandParameter) Export
	
	If Result <> DialogReturnCode.Yes Then
		Return;
	EndIf;	
		
	If TypeOf(CommandParameter) = Type("Array") 
Then
		If CommandParameter.Count() = 1 Then
			Status(NStr("en = 'Stopping business process. Please wait...'"));
		Else
			Status(NStr("en = 'Stopping business processes. Please wait...'"));
		EndIf;	
		
		BusinessProcessesAndTasksServerCall.StopBusinessProcesses(CommandParameter);
		
		If CommandParameter.Count() = 1 Then
			Status(NStr("en = 'The business process is stopped.'"));
		Else	
			Status(NStr("en = 'The business processes are stopped.'"));
		EndIf;	
	Else	
		Status(NStr("en = 'Stopping business process. Please wait...'"));
		BusinessProcessesAndTasksServerCall.StopBusinessProcess(CommandParameter);
		Status(NStr("en = 'The business process is stopped.'"));
	EndIf;	
	
	If TypeOf(CommandParameter) = Type("Array") 
Then
		
		If CommandParameter.Count() <> 0 Then
			
			For Each Parameter In CommandParameter Do
				
				If TypeOf(Parameter) <> Type("DynamicalListGroupRow") Then
					NotifyChanged(TypeOf(Parameter));
					Break;
				EndIf;	
				
			EndDo;
			
		EndIf;
		
	Else
		NotifyChanged(CommandParameter);	
	EndIf;	

EndProcedure

Procedure BusinessProcessListDeletionMarkCompletion(Result, List) Export
	
	If Result <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	SelectedRows = List.SelectedRows;
	BusinessProcessRef = BusinessProcessesAndTasksServerCall.MarkBusinessProcessesForDeletion(SelectedRows);
	List.Refresh();
	ShowUserNotification(NStr("en = 'The deletion mark is changed.'"), 
		?(BusinessProcessRef <> Undefined, GetURL(BusinessProcessRef), ""),
		?(BusinessProcessRef <> Undefined, String(BusinessProcessRef), ""));
	
EndProcedure

Procedure ActivateCompletion(Val Result, Val CommandParameter) Export
	
	If Result <> DialogReturnCode.Yes Then
		Return;
	EndIf;	
		
	If TypeOf(CommandParameter) = Type("Array") 
Then
		
		If CommandParameter.Count() = 1 Then
			Status(NStr("en = 'Activating business process and its tasks. Please wait...'"));
		Else	
			Status(NStr("en = 'Activating business processes and their tasks. Please wait...'"));
		EndIf;	
		
		BusinessProcessesAndTasksServerCall.ActivateBusinessProcesses(CommandParameter);
		
		If CommandParameter.Count() = 1 Then
			Status(NStr("en = 'The business process and its tasks are activated.'"));
		Else	
			Status(NStr("en = 'The business processes and their tasks are activated.'"));
		EndIf;	
		
	Else	
		Status(NStr("en = 'Canceling the stopping of the business process. Please wait...'"));
		BusinessProcessesAndTasksServerCall.ActivateBusinessProcess(CommandParameter);
		Status(NStr("en = 'The business process and its tasks are activated.'"));
	EndIf;	
	
	If TypeOf(CommandParameter) = Type("Array") Then
		
		If CommandParameter.Count() <> 0 Then
			
			For Each Parameter In CommandParameter Do
				
				If TypeOf(Parameter) <> Type("DynamicalListGroupRow") Then
					NotifyChanged(TypeOf(Parameter));
					Break;
				EndIf;	
				
			EndDo;
			
		EndIf;
		
	Else
		NotifyChanged(CommandParameter);	
	EndIf;	
		
EndProcedure

Procedure ForwardTasksCompletion(Val Result, Val TaskArray) Export
	
	If TypeOf(Result) <> Type("Structure") Then
		Return;
	EndIf;
	
	If TaskArray.Count() > 10 Then
		Status(NStr("en = 'Forwarding tasks'"),, 
			NStr("en = 'Task forwarding is in progress...'"));
	EndIf;
	ForwardedTasksArray = Undefined;
	TasksForwarded = BusinessProcessesAndTasksServerCall.ForwardTasks
(
		TaskArray, Result, False, 
ForwardedTasksArray);
	If TaskArray.Count() > 1 Then
		If TasksForwarded Then
			Status(NStr("en = 'Forwarding tasks'"),, 
				NStr("en = 'Tasks forwarded:'") + " " + TaskArray.Count());
		Else
			Status(NStr("en = 'Forwarding tasks'"),,
				NStr("en = 'Some tasks are not forwarded. The skipped tasks are marked as completed.'"));
		EndIf;
	Else
		Task = ForwardedTasksArray[0];
		ShowUserNotification(
			NStr("en = 'The task is forwarded'"),
			GetURL(Task),
			String(Task));
	EndIf;
	Notify("Write_PerformerTask", New Structure("Redirected", True), TaskArray);
	
EndProcedure

#EndRegion
