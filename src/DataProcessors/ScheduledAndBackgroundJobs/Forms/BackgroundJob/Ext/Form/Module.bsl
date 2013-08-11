////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	If Parameters.BackgroundJobProperties = Undefined Then
		
		BackgroundJobProperties = ScheduledJobsServer
			.GetBackgroundJobProperties(Parameters.ID);
		
		If BackgroundJobProperties =  Undefined Then
			Raise(NStr("en = 'Background job is not found.'"));
		EndIf;
		
		UserMessagesAndErrorDetails = ScheduledJobsServer.BackgroundJobMessagesAndErrorDescriptions(Parameters.ID);
			
		If ValueIsFilled(BackgroundJobProperties.ScheduledJobID) Then
			
			ScheduledJobID
				= BackgroundJobProperties.ScheduledJobID;
			
			ScheduledJobDescription
				= ScheduledJobsServer.ScheduledJobPresentation(
					BackgroundJobProperties.ScheduledJobID);
		Else
			ScheduledJobDescription  = ScheduledJobsServer.TextUndefined();
			ScheduledJobID = ScheduledJobsServer.TextUndefined();
		EndIf;
	Else
		BackgroundJobProperties = Parameters.BackgroundJobProperties;
		FillPropertyValues(
			ThisForm,
			BackgroundJobProperties,
			"UserMessagesAndErrorDetails, 
			|ScheduledJobID, 
			|ScheduledJobDescription");
	EndIf;
	
	FillPropertyValues(
		ThisForm,
		BackgroundJobProperties,
		"ID, 
		|Key, 
		|Description, 
		|Begin, 
		|End, 
		|Location, 
		|State, 
		|MethodName");
	
EndProcedure







