
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
 
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed
	If Parameters.Property("Autotest") Then
		Return;
	   EndIf;
	
 // Executing form initialization script.
 // For new objects it is executed in OnCreateAtServer.
 // For existing objects it is executed in OnReadAtServer.
 If Object.Ref.IsEmpty() Then
  FormInitialization();
 EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	FormInitialization();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	BusinessProcessesAndTasksClient.TaskFormNotificationProcessing(ThisObject, EventName, Parameter, Source);
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure OpenTaskFormDecorationClick(Item)
	
	ShowValue(,Object.Ref);
	Modified = False;
	Close();
	
EndProcedure

&AtClient
Procedure SubjectClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	ShowValue(,Object.Subject);
	
EndProcedure

&AtClient
Procedure CompletionDateOnChange(Item)
	
	If Object.CompletionDate = BegOfDay(Object.CompletionDate) Then
		Object.CompletionDate = EndOfDay(Object.CompletionDate);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure WriteAndCloseExecute(Command)
	
	BusinessProcessesAndTasksClient.WriteAndCloseExecute(ThisObject);
	
EndProcedure

&AtClient
Procedure ExecutedExecute(Command)

	BusinessProcessesAndTasksClient.WriteAndCloseExecute(ThisObject, True);

EndProcedure

&AtClient
Procedure Advanced(Command)
	
	BusinessProcessesAndTasksClient.OpenAdditionalTaskInfo(Object.Ref);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure FormInitialization()
	
	If ValueIsFilled(Object.BusinessProcess) 
Then
		FormParameters = BusinessProcessesAndTasksServerCall.TaskExecutionForm(Object.Ref);
		HasTaskForm = FormParameters.Property
("FormName");
		Items.ExecutionFormGroup.Visibility = HasTaskForm;
		Items.Executed.Enabled = Not 
HasTaskForm;
	Else
		Items.ExecutionFormGroup.Visibility = False;
	EndIf;
	InitialExecutionFlag = Object.Executed;
	If Object.Ref.IsEmpty() Then
		Object.Importance = Enums.TaskImportanceVariants.Normal;
		Object.DueDate = CurrentSessionDate();
	EndIf;
	
	Items.Subject.Hyperlink = Object.Subject <> Undefined And Not Object.Subject.IsEmpty();
	SubjectString = CommonUse.SubjectString(Object.Subject);	
	
	UseDateAndTimeInTaskDeadlines = GetFunctionalOption("UseDateAndTimeInTaskDeadlines");
	Items.CompletionStartDeadlineTime.Visibility = UseDateAndTimeInTaskDeadlines;
	Items.CompletionDateTime.Visibility = UseDateAndTimeInTaskDeadlines;
	BusinessProcessesAndTasksServer.SetDateFormat(Items.DueDate);
	BusinessProcessesAndTasksServer.SetDateFormat(Items.Date);
	
	BusinessProcessesAndTasksServer.TaskFormOnCreateAtServer(ThisObject, Object, 
		Items.StateGroup, 
Items.CompletionDate);
	
EndProcedure	

#EndRegion
