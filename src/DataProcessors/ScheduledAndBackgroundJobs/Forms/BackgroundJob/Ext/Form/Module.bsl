
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	If Parameters.BackgroundJobProperties = Undefined Then
		
		BackgroundJobProperties = ScheduledJobsInternal
			.GetBackgroundJobProperties(Parameters.ID);
		
		If BackgroundJobProperties =  Undefined Then
			Raise(NStr("en = 'Background job is not found.'"));
		EndIf;
		
		UserMessagesAndErrorDetails = ScheduledJobsInternal.BackgroundJobMessagesAndErrorDescriptions(Parameters.ID);
			
		If ValueIsFilled(BackgroundJobProperties.ScheduledJobID) Then
			
			ScheduledJobID
				= BackgroundJobProperties.ScheduledJobID;
			
			ScheduledJobDescription
				= ScheduledJobsInternal.ScheduledJobPresentation(
					BackgroundJobProperties.ScheduledJobID);
		Else
			ScheduledJobDescription  = ScheduledJobsInternal.TextUndefined();
			ScheduledJobID = ScheduledJobsInternal.TextUndefined();
		EndIf;
	Else
		BackgroundJobProperties = Parameters.BackgroundJobProperties;
		FillPropertyValues(
			ThisObject,
			BackgroundJobProperties,
			"UserMessagesAndErrorDetails, 
			|ScheduledJobID, 
			|ScheduledJobDescription");
	EndIf;
	
	FillPropertyValues(
		ThisObject,
		BackgroundJobProperties,
		"ID, 
		|Key, 
		|Description, 
		|Beginning, 
		|End, 
		|Location, 
		|State, 
		|MethodName");
		
	StandardSubsystemsServer.SetGroupTitleRepresentation(ThisObject);
	
EndProcedure

#EndRegion
