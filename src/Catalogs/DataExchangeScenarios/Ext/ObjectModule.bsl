#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If DeletionMark Then
		
		UseScheduledJob = False;
		
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	// Deleting the scheduled job, if necessary
	If DeletionMark Then
		
		DeleteScheduledJob(Cancel);
		
	EndIf;
 
  // Updating the platform cache for reading actual exchange message 
  // transport settings with the DataExchangeCached.GetExchangeSettingsStructure procedure
	RefreshReusableValues();
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	ScheduledJobGUID = "";
	
EndProcedure

Procedure BeforeDelete(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DeleteScheduledJob(Cancel);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// Deletes a background job.
//
// Parameters:
//  Cancel - Boolean - cancellation flag. It is set to True if
//           errors occur during the procedure execution.
// 
Procedure DeleteScheduledJob(Cancel)
	
	SetPrivilegedMode(True);
	
	// Searching for the scheduled job
	ScheduledJobObject = DataExchangeServerCall.FindScheduledJobByParameter(ScheduledJobGUID);
	
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

#EndRegion

#EndIf
