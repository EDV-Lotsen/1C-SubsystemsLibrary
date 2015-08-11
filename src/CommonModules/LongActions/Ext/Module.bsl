////////////////////////////////////////////////////////////////////////////////
// Base functionality subsystem.
// Support of long server actions at the web client.
//
//////////////////////////////////////////////////////////////////////////////// 

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Executes procedures in a background job.
// 
// Parameters:
// FormID - UUID - form ID, 
// the long action is executed from this form;
// ExportProcedureName - String - export procedure name 
// required to execute in background job
// Parameters - Structure - all necessary to ExportProcedureName execution parameters.
// JobDescription - String - background job description. 
// If JobDescription is not specified it will be equal to ExportProcedureName. 
//

// Returns:
// Structure - returns following properties: 
// - StorageAddress - Temporary storage address where a job
// execution result will be put; 
// - JobID - executing background job UUID;
// - JobCompleted - True if job completed successfully. 
//
Function ExecuteInBackground(Val FormID, Val ExportProcedureName, 
	Val Parameters, Val JobDescription = "") Export
	
	StorageAddress = PutToTempStorage(Undefined, FormID);

	If Not ValueIsFilled(JobDescription) Then
		JobDescription = ExportProcedureName;
	EndIf;
	
	ExportProcedureParameters = New Array;
	ExportProcedureParameters.Add(Parameters);
	ExportProcedureParameters.Add(StorageAddress);
	
	JobParameters = New Array;
	JobParameters.Add(ExportProcedureName);
	JobParameters.Add(ExportProcedureParameters);

	If GetClientConnectionSpeed() = ClientConnectionSpeed.Low Then
		Timeout = 4;
	Else
		Timeout = 2;
	EndIf;
	If CommonUseCached.DataSeparationEnabled()
		And CommonUseCached.SessionWithoutSeparator() Then
		
		JobParameters.Add(CommonUse.SessionSeparatorValue());
		
		CommonUse.SetSessionSeparation(False);
		
		Job = BackgroundJobs.Execute("CommonUse.ExecuteSafely", JobParameters,, JobDescription);
		Try
			Job.WaitForCompletion(Timeout);
		Except
			// There is no need in special processing. Perhaps the exception was raised because of a time-out occurred.
		EndTry;
		
		CommonUse.SetSessionSeparation(True);
	Else
		JobParameters.Add(Undefined);
		Job = BackgroundJobs.Execute("CommonUse.ExecuteSafely", JobParameters,, JobDescription);
		Try
			Job.WaitForCompletion(Timeout);
		Except		
			// There is no need in a special processing. Perhaps the exception was raised because of a time-out occurred.
		EndTry;
	EndIf;
	
		
	Result = New Structure;
	Result.Insert("StorageAddress" , StorageAddress);
	Result.Insert("JobCompleted" , JobCompleted(Job.UUID));
	Result.Insert("JobID", Job.UUID);	
	
	Return Result;
	
EndFunction

// Cancels background job execution by the passed ID.
// 
// Parameters:
// JobID - UUID - background job ID.
// 
Procedure CancelJobExecution(Val JobID) Export 
	
	If Not ValueIsFilled(JobID) Then
		Return;
	EndIf;
	
	Job = FindJobByID(JobID);
	If Job = Undefined
		Or Job.State <> BackgroundJobState.Active Then
		
		Return;
	EndIf;
	
	Try
		Job.Cancel();
	Except
		// Perhaps job finished just at this moment and there is no error.
		WriteLogEvent(NStr("en = 'Long actions. Background job cancellation'", Metadata.DefaultLanguage.LanguageCode),
			EventLogLevel.Error,,,
			DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

// Checks background job state by the passed ID.
// 
// Parameters:
// JobID - UUID - background job ID. 
//
// Returns:
// Boolean - returns True, if the job completed successfully;
// False - if the job is still executing. In other cases an exception is raised.
//
Function JobCompleted(Val JobID) Export
	
	Job = FindJobByID(JobID);
	
	If Job <> Undefined
		And Job.State = BackgroundJobState.Active Then
		Return False;
	EndIf;
	
	ActionNotExecuted = True;
	ShowFullErrorText = False;
	If Job = Undefined Then
		WriteLogEvent(NStr("en = 'Long actions. Background job is not found'", Metadata.DefaultLanguage.LanguageCode),
			EventLogLevel.Error,,, String(JobID));
	Else	
		If Job.State = BackgroundJobState.Failed Then
			JobError = Job.ErrorInfo;
			If JobError <> Undefined Then
				WriteLogEvent(NStr("en = 'Long actions. Background job failed'", Metadata.DefaultLanguage.LanguageCode),
					EventLogLevel.Error,,,
					DetailErrorDescription(Job.ErrorInfo));
				ShowFullErrorText = True;	
			Else
				WriteLogEvent(NStr("en = 'Long actions. Background job failed'", Metadata.DefaultLanguage.LanguageCode),
					EventLogLevel.Error,,,
					NStr("en = 'The job finished with an unknown error.'"));
			EndIf;
		ElsIf Job.State = BackgroundJobState.Canceled Then
			WriteLogEvent(NStr("en = 'Long actions. Administrator canceled background job'", Metadata.DefaultLanguage.LanguageCode),
				EventLogLevel.Error,,,
				NStr("en = 'The job finished with an unknown error.'"));
		Else
			Return True;
		EndIf;
	EndIf;
	
	If ShowFullErrorText Then
		ErrorText = BriefErrorDescription(GetErrorInfo(Job.ErrorInfo));
		Raise(ErrorText);
	ElsIf ActionNotExecuted Then
		Raise(NStr("en = 'This job cannot be executed. 
						|See details in the Event log.'"));
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

Function FindJobByID(Val JobID)
	
	If CommonUseCached.DataSeparationEnabled()
		And CommonUseCached.SessionWithoutSeparator() Then
		
		CommonUse.SetSessionSeparation(False);
		Job = BackgroundJobs.FindByUUID(JobID);
		CommonUse.SetSessionSeparation(True);
	Else
		Job = BackgroundJobs.FindByUUID(JobID);
	EndIf;
	
	Return Job;
	
EndFunction

Function GetErrorInfo(ErrorInfo)
	
	Result = ErrorInfo;
	If ErrorInfo <> Undefined Then
		If ErrorInfo.Cause <> Undefined Then
			Result = GetErrorInfo(ErrorInfo.Cause);
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

