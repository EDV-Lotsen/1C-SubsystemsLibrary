////////////////////////////////////////////////////////////////////////////////
// Business processes and tasks subsystem
//  
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Subsystem event subscription handlers.

// Handler for WriteToBusinessProcessList event subscription.
//
Procedure WriteToBusinessProcessList(Source, Cancel) Export
	
	If Source.DataExchange.Load Then 
        Return;  
	EndIf; 
	
	RecordSet = InformationRegisters.BusinessProcessData.CreateRecordSet();
	RecordSet.Filter.BusinessProcess.Value = Source.Ref;
	RecordSet.Filter.BusinessProcess.Use = True;
	Write = RecordSet.Add();
	Write.BusinessProcess = Source.Ref;
	FieldList = "Number,Date,Completed,Started,Author,CompletionDate,Description,DeletionMark";
	FillPropertyValues(Write, Source, FieldList);
	
	BusinessProcessesAndTasksOverridable.OnWriteBusinessProcessList(Write);
	
	SetPrivilegedMode(True);
	RecordSet.Write();

EndProcedure

// Handler for SetTaskDeletionMarks event subscription.
//
Procedure SetTaskDeletionMarks(Source, Cancel) Export
	
	If Source.DataExchange.Load Then 
        Return;  
	EndIf; 
	
	If Source.IsNew() Then 
        Return;  
	EndIf; 
	
	PreviousDeletionMark = CommonUse.ObjectAttributeValue(Source.Ref, "DeletionMark");
	If Source.DeletionMark <> PreviousDeletionMark Then
		SetPrivilegedMode(True);
		BusinessProcessesAndTasksServer.SetTaskDeletionMarks(Source.Ref, Source.DeletionMark);
	EndIf;	
	
EndProcedure

// Handler for UpdateBusinessProcessState event subscription.
//
Procedure UpdateBusinessProcessState(Source, Cancel) Export
	
	If Source.DataExchange.Load Then 
        Return;  
	EndIf; 
	
	If Source.Metadata().Attributes.Find("State") = Undefined Then
		Return;
	EndIf;	
	
	If Not Source.IsNew() Then
		NewState = Source.State;
		OldState = CommonUse.ObjectAttributeValue(Source.Ref, "State");
		If NewState <> OldState Then
			BusinessProcessesAndTasksServer.OnChangeBusinessProcessState(Source, OldState, NewState);
		EndIf;
	EndIf;	
	
EndProcedure

#EndRegion
