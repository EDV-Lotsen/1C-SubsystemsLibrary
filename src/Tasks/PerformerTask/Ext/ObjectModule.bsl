#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Interface

// Returns True if performer or performer's role is specified in the task.
//
Function AddressingAttributesFilled() Export
	
	Return Not Performer.IsEmpty() Or Not PerformerRole.IsEmpty();

EndFunction

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS 

Procedure FillCheckProcessing(Cancel, AttributesToCheck)
	
	TaskWasExecuted = CommonUse.ObjectAttributeValue(Ref, "Executed");
	If Not TaskWasExecuted And Executed Then
		
		If Not AddressingAttributesFilled() Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'Specify the task performer.'"),,,
				"Object.Performer", Cancel);
			Return;
		EndIf;
		
	ElsIf TaskWasExecuted And Executed Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'This task is already executed.'"),,,, Cancel);
		Return;
	EndIf;
	
	If DueDate <> '00010101' And StartDate > DueDate Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'The start date cannot be greater than the end date.'"),,,
			"Object.StartDate", Cancel);
		Return;
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
		
	If Not Ref.IsEmpty() Then
		InitialAttributes = CommonUse.ObjectAttributeValue(Ref, 
			"Executed, DeletionMark, BusinessProcessState");
	Else 
		InitialAttributes = New Structure(
			"Executed, DeletionMark, BusinessProcessState",
			False, False, Enums.BusinessProcessStates.EmptyRef());
	EndIf;
	
	If Not InitialAttributes.Executed And Executed Then
		
		If BusinessProcessState = Enums.BusinessProcessStates.Stopped Then
			Raise NStr("en = 'Tasks of stopped business processes cannot be executed.'");
		EndIf;	
		
		// If the task is executed,  
   // recording the user that actually completed the task to the Performer attribute.
		// We will need it later for reports. The recording is only performed 
   //if the task is not marked completed in the infobase but is marked 
   //completed in the object.
		If Not ValueIsFilled(Performer) Then
			Performer = Users.CurrentUser();
		EndIf;
		If CompletionDate = Date(1, 1, 1) Then
			CompletionDate = CurrentSessionDate();
		EndIf;
	EndIf;
	
	If Importance.IsEmpty() Then
		Importance = Enums.TaskImportanceVariants.Normal;
	EndIf;
	
	If Not ValueIsFilled(BusinessProcessState) Then
		BusinessProcessState = Enums.BusinessProcessStates.Active;
	EndIf;
	
	SubjectString = CommonUse.SubjectString(Subject);
	
	If InitialAttributes.DeletionMark <> DeletionMark Then
  BusinessProcessesAndTasksServer.OnMarkTaskForDeletion(Ref, DeletionMark);
	EndIf;
	
	If Not Ref.IsEmpty() And InitialAttributes.BusinessProcessState <> BusinessProcessState Then
		SetSubordinateBusinessProcessesState(BusinessProcessState);
	EndIf;
	
	If Executed And Not AcceptedForExecution Then
		AcceptedForExecution = True;
		AcceptForExecutionDate = CurrentSessionDate();
	EndIf;	
		
	// StandardSubsystems.AccessManagement
	SetPrivilegedMode(True);
	TaskPerformerGroup = BusinessProcessesAndTasksServer.TaskPerformerGroup(PerformerRole, 
		MainAddressingObject, AdditionalAddressingObject);
	SetPrivilegedMode(False);
	// End StandardSubsystems. AccessManagement
	
	// Filling the AcceptForExecutionDate attribute 
	If AcceptedForExecution And AcceptForExecutionDate = Date('00010101') Then
		AcceptForExecutionDate = CurrentSessionDate();
	EndIf;
	
EndProcedure

Procedure Filling(FillingData)
	
	If TypeOf(FillingData) = Type("TaskObject.PerformerTask") Then
		FillPropertyValues(ThisObject, FillingData, 
			"BusinessProcess,RoutePoint,Description,Performer,PerformerRole,MainAddressingObject," + 
			"AdditionalAddressingObject,Importance,CompletionDate,Author,Description,DueDate," + 
			"StartDate,ExecutionResult,Subject");
		Date = CurrentSessionDate();
	EndIf;
	If Not ValueIsFilled(Importance) Then
		Importance = Enums.TaskImportanceVariants.Normal;
	EndIf;
	
	If Not ValueIsFilled(BusinessProcessState) Then
		BusinessProcessState = Enums.BusinessProcessStates.Active;
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

Procedure SetSubordinateBusinessProcessesState(NewState)
	
	BeginTransaction();
	Try
		SubordinateBusinessProcesses = BusinessProcessesAndTasksServer.MainTaskBusinessProcesses(Ref, True);
		
		If SubordinateBusinessProcesses <> Undefined Then
			For Each SubordinateBusinessProcess In SubordinateBusinessProcesses Do
				BusinessProcessObject = SubordinateBusinessProcess.GetObject();
				BusinessProcessObject.Lock();
				BusinessProcessObject.State = NewState;
				BusinessProcessObject.Write();
			EndDo;	
		EndIf;	
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion

#EndIf