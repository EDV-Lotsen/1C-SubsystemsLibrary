////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

Procedure BeforeWrite(Cancel)
	
	If DeletionMark Then
		
		UseScheduledJob = False;
		
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	// Deleting the scheduled job, if necessary
	If DeletionMark Then
		
		DeleteScheduledJob(Cancel);
		
	EndIf;
	
	// Updating the platform cache for reading actual exchange message transport 
	// settings with the DataExchangeCached.GetExchangeSettingsStructure procedure.
	RefreshReusableValues();
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	ScheduledJobGUID = "";
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Delets the scheduled job.
//
// Parameters:
//  Cancel             - Boolean - cancel flag. It is set to True if errors occur
//                       during the procedure execution. 
//  ScheduledJobObject - scheduled job object to be deleted.
// 
Procedure DeleteScheduledJob(Cancel)
	
	SetPrivilegedMode(True);
	
	// Searching for the scheduled job
	ScheduledJobObject = DataExchangeServer.FindScheduledJobByParameter(ScheduledJobGUID);
	
	If ScheduledJobObject <> Undefined Then
		
		Try
			ScheduledJobObject.Delete();
		Except
			MessageString = NStr("en = 'Error deleting the scheduled job: %1'");
			MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, BriefErrorDescription(ErrorInfo()));
			DataExchangeServer.ReportError(MessageString, Cancel);
		EndTry;
		
	EndIf;
	
EndProcedure



















