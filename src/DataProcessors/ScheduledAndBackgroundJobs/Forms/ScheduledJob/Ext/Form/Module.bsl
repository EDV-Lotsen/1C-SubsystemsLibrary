////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS


&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
If Parameters.Property("SelfTest") Then
  Return;
EndIf;


If Not Users.InfoBaseUserWithFullAccess(, True) Then
  Raise NStr("en = 'Insufficient access rights.
                   |
                   |Only administrators can change scheduled job properties.'");
EndIf;


Action = Parameters.Action;


If Find(", Add, Copy, Change,", ", " + Action + ",") = 0 Then
  
  Raise NStr("en = 'Scheduled job form open parameters are incorrect.'");
EndIf;


Items.UserName.Enabled = Not CommonUse.FileInfoBase();
	
	If Action = "Add" Then
		
		Schedule = New JobSchedule;
		
		For Each ScheduledJobMetadata In Metadata.ScheduledJobs Do
			ScheduledJobMetadataDetails.Add(
				ScheduledJobMetadata.Name
					+ Chars.LF
					+ ScheduledJobMetadata.Synonym
					+ Chars.LF
					+ ScheduledJobMetadata.MethodName,
				?(IsBlankString(ScheduledJobMetadata.Synonym),
				  ScheduledJobMetadata.Name,
				  ScheduledJobMetadata.Synonym) );
		EndDo;
	Else
		Job = ScheduledJobsServer.GetScheduledJob(Parameters.ID);
		FillPropertyValues(
			ThisForm,
			Job,
			"Key, 
			|Description, 
			|Use, 
			|UserName, 
			|RestartIntervalOnFailure, 
			|RestartCountOnFailure");
		
		ID                   = String(Job.UUID);
		If Job.Metadata      = Undefined Then
			MetadataName       = NStr("en = '<No metadata>'");
			MetadataSynonym    = NStr("en = '<No metadata>'");
			MetadataMethodName = NStr("en = '<No metadata>'");
		Else
			MetadataName       = Job.Metadata.Name;
			MetadataSynonym    = Job.Metadata.Synonym;
			MetadataMethodName = Job.Metadata.MethodName;
		EndIf;
		Schedule = Job.Schedule;
		
		UserMessagesAndErrorDetails = ScheduledJobsServer
			.ScheduledJobMessagesAndErrorDescriptions(Job);
	EndIf;
	
	If Action <> "Change" Then
		ID = NStr("en = '<Will be created when writing>'");
		Use = False;
		
		Description = ?(
			Action = "Add",
			"",
			ScheduledJobsServer.ScheduledJobPresentation(Job));
	EndIf;
	
	// Filling the user name choice list.
	UserArray = InfoBaseUsers.GetUsers();
	
	For Each User In UserArray Do
		Items.UserName.ChoiceList.Add(User.Name);
	EndDo;
	
EndProcedure 

&AtClient
Procedure OnOpen(Cancel)
	
	If Action = "Add" Then
		
		// Choosing scheduled job template (metadata).
		ListItem = ScheduledJobMetadataDetails.ChooseItem(
			NStr("en = 'Select scheduled job template"));
		
		If ListItem = Undefined Then
			Cancel = True;
			Return;
		Else
			MetadataName       = StrGetLine(ListItem.Value, 1);
			MetadataSynonym    = StrGetLine(ListItem.Value, 2);
			MetadataMethodName = StrGetLine(ListItem.Value, 3);
			Description        = ListItem.Presentation;
		EndIf;
	EndIf;
	
	RefreshFormTitle();

EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	CommonUseClient.RequestCloseFormConfirmation(Cancel, Modified);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure DescriptionOnChange(Item)
	
	RefreshFormTitle();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure Write(Command)
	
	WriteScheduledJob();
	
EndProcedure

&AtClient
Procedure WriteAndCloseExecute()
	
	WriteScheduledJob();
	Close();
	
EndProcedure

&AtClient
Procedure OpenScheduleExecute()

	Dialog = New ScheduledJobDialog(Schedule);
	
	If Dialog.DoModal() Then
		Schedule = Dialog.Schedule;
		Modified = True;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtClient
Procedure WriteScheduledJob()
	
	WriteScheduledJobAtServer();
	RefreshFormTitle();
	Notify("Write_ScheduledAndBackgroundJobs", Parameters.ID);
	
EndProcedure

&AtServer
Procedure WriteScheduledJobAtServer()
	
	If Action = "Change" Then
		Job = ScheduledJobsServer.GetScheduledJob(ID);
	Else
		Job = ScheduledJobs.CreateScheduledJob(
			Metadata.ScheduledJobs[MetadataName]);
		
		ID = String(Job.UUID);
		Action = "Change";
	EndIf;
	
	FillPropertyValues(
		Job,
		ThisForm,
		"Key, 
		|Description, 
		|Use, 
		|UserName, 
		|RestartIntervalOnFailure, 
		|RestartCountOnFailure");
	
	Job.Schedule = Schedule;
	Job.Write();
	
	Modified = False;
	
EndProcedure

&AtClient
Procedure RefreshFormTitle()
	
	If Not IsBlankString(Description) Then
		Presentation = Description;
		
	ElsIf Not IsBlankString(MetadataSynonym) Then
		Presentation = MetadataSynonym;
	Else
		Presentation = MetadataName;
	EndIf;
	
	If Action = "Change" Then
		Title = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = '%1 (Scheduled job)'"), Presentation);
	Else
		Title = NStr("en = 'Scheduled job (creating)'");
	EndIf;
	
EndProcedure
