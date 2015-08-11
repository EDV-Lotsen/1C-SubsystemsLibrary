#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure Refresh(HasChanges = Undefined, OnlyCheck = False) Export
	
	SetExclusiveMode(True);
	
	If OnlyCheck Or ExclusiveMode() Then
		UnsetExclusiveMode = False;
	Else
		UnsetExclusiveMode = True;
		SetExclusiveMode(True);
	EndIf;
	
	EventHandlers = StandardSubsystemsServer.EventHandlers();
	
	DataLock = New DataLock;
	DataLockElement = DataLock.Add("Constant.InternalEventParameters");
	DataLockElement.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		DataLock.Lock();
		
		Parameters = StandardSubsystemsServer.ApplicationParameters(
			"InternalEventParameters");
		
		Saved = Undefined;
		
		If Parameters.Property("EventHandlers") Then
			Saved = Parameters.EventHandlers;
			
			If Not CommonUse.IsEqualData(EventHandlers, Saved) Then
				Saved = Undefined;
			EndIf;
		EndIf;
		
		If Saved = Undefined Then
			HasChanges = True;
			If OnlyCheck Then
				CommitTransaction();
				Return;
			EndIf;
			StandardSubsystemsServer.SetApplicationParameter(
				"InternalEventParameters", "EventHandlers", EventHandlers);
		EndIf;
		
		StandardSubsystemsServer.ConfirmApplicationParameterUpdate(
			"InternalEventParameters", "EventHandlers");
		
		CommitTransaction();
	Except
		RollbackTransaction();
		If UnsetExclusiveMode Then
			SetExclusiveMode(False);
		EndIf;
		Raise;
	EndTry;
	
	If UnsetExclusiveMode Then
		SetExclusiveMode(False);
	EndIf;
	
EndProcedure

#EndIf
