#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Interface

////////////////////////////////////////////////////////////////////////////////
// Programming interface for the Business processes and tasks subsystem

// Gets a structure with a description of a task execution form.
// The function is called when opening a task execution form.
//
// Parameters:
//   TaskRef - TaskRef.PerformerTask - task. 
//   BusinessProcessRoutePoint - route point. 
//
// Returns:
//   Structure   - structure with a description of the task execution form.
//                 Key "FormName" contains the form name that is passed to the OpenForm() context method. 
//                 Key "FormOptions" contains the form parameters. 
//
Function TaskExecutionForm(TaskRef, BusinessProcessRoutePoint) Export
	
	ExternalTask = False;
	BusinessProcessesAndTasksServer.OnDetermineExternalTask(TaskRef, ExternalTask);
	If Not ExternalTask Then
		FormName = 
"BusinessProcess.Job.Form.Action" + BusinessProcessRoutePoint.Name;
	EndIf;
	
	Result = New Structure;
	Result.Insert("FormParameters", New 
Structure("Key", TaskRef));
	Result.Insert("FormName", FormName);
	Return Result;
	
EndFunction

// The function is called when reassigning a task.
//
// Parameters
//   TaskRef     - TaskRef.PerformerTask - task that is reassigned.
//   NewTaskRef  - TaskRef.PerformerTask - task for a new performer.
//
Procedure OnForwardTask(TaskRef, NewTaskRef) Export
	
	BusinessProcessObject = TaskRef.BusinessProcess.GetObject();
	LockDataForEdit
(BusinessProcessObject.Ref);
	BusinessProcessObject.ExecutionResult = ExecutionResultOnForward(TaskRef) + 
		BusinessProcessObject.ExecutionResult;
	SetPrivilegedMode(True);
	BusinessProcessObject.Write();
	
EndProcedure

// The function is called when a task is executed from a list form.
//
// Parameters:
//   TaskRef - TaskRef.PerformerTask -- task. 
//   BusinessProcessRef - BusinessProcessRef - business process where the TaskRef task is generated.
//  BusinessProcessRoutePoint - route point. 
//
Procedure DefaultCompletionHandler(TaskRef, BusinessProcessRef, BusinessProcessRoutePoint) Export
	
	// Setting default values for batch task execution
	If BusinessProcessRoutePoint = BusinessProcesses.Job.RoutePoints.Execute Then
		SetPrivilegedMode(True);
		JobObject = BusinessProcessRef.GetObject();
		LockDataForEdit(JobObject.Ref);
		JobObject.Completed = True;	
		JobObject.Write();
	ElsIf BusinessProcessRoutePoint = BusinessProcesses.Job.RoutePoints.Validate Then
		SetPrivilegedMode(True);
		JobObject = BusinessProcessRef.GetObject();
		LockDataForEdit(JobObject.Ref);
		JobObject.Completed = True;
		JobObject.Confirmed = True;
		JobObject.Write();
	EndIf;
	
EndProcedure	

////////////////////////////////////////////////////////////////////////////////
// Batch object modification

// Returns a list of attributes that are excluded from the scope of the batch object modification data processor.
//
Function BatchProcessingEditableAttributes() 
Export
	
	Result = New Array;
	Result.Add("Author");
	Result.Add("Importance");
	Result.Add("Performer");
	Result.Add("CheckExecution");
	Result.Add("Supervisor");
	Result.Add("DueDate");
	Result.Add("VerificationDueDate");
	Return Result;
	
EndFunction

#EndRegion

#EndIf

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	
#Region InternalProceduresAndFunctions

// Sets the states of the task form items.
Procedure SetTaskFormItemsState(Form) Export
	
	If Form.Items.Find("ExecutionResult") <> Undefined 
		And Form.Items.Find("ExecutionHistory") <> Undefined Then
		If IsBlankString(Form.JobExecutionResult) Then
			Form.Items.ExecutionHistory.Picture = 
New Picture();
		Else
			Form.Items.ExecutionHistory.Picture = PictureLib.Comment;
		EndIf;
	EndIf;
	
	Form.Items.Subject.Hyperlink = Form.Object.Subject <> Undefined And Not Form.Object.Subject.IsEmpty();
	Form.SubjectString = 
CommonUse.SubjectString
(Form.Object.Subject);	
	
EndProcedure	

Function ExecutionResultOnForward(Val TaskRef)  
	
	FormatString = NStr("en = '%1, %2 reassigned the task:
		|%3
   |'");
	
	Comment = TrimAll
(TaskRef.ExecutionResult);
	Comment = ?(IsBlankString(Comment), "", 
Comment + Chars.LF);
	Result = StringFunctionsClientServer.SubstituteParametersInString(FormatString,
	              TaskRef.CompletionDate,
	              TaskRef.Performer,
	              Comment);
		
	Return Result;

EndFunction

#EndRegion

#EndIf