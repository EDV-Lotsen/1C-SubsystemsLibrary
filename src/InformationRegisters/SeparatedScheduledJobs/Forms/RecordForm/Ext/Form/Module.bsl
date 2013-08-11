
////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Job = ScheduledJobs.FindByUUID(Record.ScheduledJob);
	If Job = Undefined Then
		PresentationPattern = NStr("en = 'The job with ID %1 is not found.'");
		ScheduledJobPresentation = StringFunctionsClientServer.SubstituteParametersInString(PresentationPattern,
			Record.ScheduledJob);
	Else
		
		PresentationPattern = NStr("en = '%1 (ID: %2)'");
		If IsBlankString(Job.Description) Then
			JobDescription = Job.Metadata.Presentation();
		Else
			JobDescription = Job.Description;
		EndIf;
		
		ScheduledJobPresentation = StringFunctionsClientServer.SubstituteParametersInString(PresentationPattern,
			JobDescription, Record.ScheduledJob);
			
	EndIf;
	
	
EndProcedure
