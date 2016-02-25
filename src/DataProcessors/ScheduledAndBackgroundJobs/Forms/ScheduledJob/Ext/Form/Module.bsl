
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;

	If Not Users.InfobaseUserWithFullAccess(, True) Then
		Raise NStr("en = 'Limited access rights.
		                             |
		                             |The scheduled job
		                             |properties can be changed only by administrators.'");
	EndIf;
	
	Action = Parameters.Action;
 
	If Find(", Add, Copy, Change,", ", " + Action + ",") = 0 Then
  
		Raise NStr("en = 'Incorrect opening parameters of the Scheduled job form.'");
	EndIf;
	
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
			ThisObject,
			Job,
			"Key,
			|Predefined,
			|Use,
			|Description,
			|UserName,
			|RestartIntervalOnFailure,
			|RestartCountOnFailure");
		
		ID = String(Job.UUID);
		If Job.Metadata = Undefined Then
			MetadataName       = NStr("en = '<no metadata>'");
			MetadataSynonym    = NStr("en = '<no metadata>'");
			MetadataMethodName = NStr("en = '<no metadata>'");
		Else
			MetadataName       = Job.Metadata.Name;
			MetadataSynonym    = Job.Metadata.Synonym;
			MetadataMethodName = Job.Metadata.MethodName;
		EndIf;
		Schedule = Job.Schedule;
		
		UserMessagesAndErrorDetails = ScheduledJobsInternal
			.ScheduledJobMessagesAndErrorDescriptions(Job);
	EndIf;
	
	If Action <> "Change" Then
		ID = NStr("en = '<will be created when writing>'");
		Use = False;
		
		Description = ?(
			Action = "Add",
			"",
			ScheduledJobsInternal.ScheduledJobPresentation(Job));
	EndIf;
	
	// Filling the user name selection list.
	UserArray = InfobaseUsers.GetUsers();
	
	For Each User In UserArray Do
		Items.UserName.ChoiceList.Add(User.Name);
	EndDo;
	
	StandardSubsystemsServer.SetGroupTitleRepresentation(ThisObject);
EndProcedure
 

&AtClient
Procedure OnOpen(Cancel)
	
	If Action = "Add" Then
		AttachIdleHandler("NewScheduledJobTemplateSelection", 0.1, True);
	Else
		RefreshFormTitle();
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	Notification = New NotifyDescription("WriteAndCloseCompletion", ThisObject);
	CommonUseClient.ShowFormClosingConfirmation(Notification, Cancel);
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure DescriptionOnChange(Item)
	
	RefreshFormTitle();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Write(Command)
	
	WriteScheduledJob();
	
EndProcedure

&AtClient
Procedure WriteAndCloseExecute()
	
	WriteAndCloseCompletion();
	
EndProcedure

&AtClient
Procedure SetScheduleExecute()

	Dialog = New ScheduledJobDialog(Schedule);
	Dialog.Show(New NotifyDescription("OpenScheduleEnd", ThisObject));
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure WriteAndCloseCompletion(Result = Undefined, AdditionalParameters = Undefined) Export
	
	WriteScheduledJob();
	Modified = False;
	Close();
	
EndProcedure

&AtClient
Procedure NewScheduledJobTemplateSelection()
	
	// Scheduled job template selection (metadata).
	ScheduledJobMetadataDetails.ShowChooseItem(
		New NotifyDescription("NewScheduledJobTemplateSelectionEnd", ThisObject),
		NStr("en = 'Select the scheduled job template'"));
	
EndProcedure

&AtClient
Procedure NewScheduledJobTemplateSelectionEnd(ListItem, NotDefined) Export
	
	If ListItem = Undefined Then
		Close();
		Return;
	EndIf;
	
	MetadataName       = StrGetLine(ListItem.Value, 1);
	MetadataSynonym    = StrGetLine(ListItem.Value, 2);
	MetadataMethodName = StrGetLine(ListItem.Value, 3);
	Description        = ListItem.Presentation;
	
	RefreshFormTitle();
	
EndProcedure

&AtClient
Procedure OpenScheduleEnd(NewSchedule, NotDefined) Export

	If NewSchedule <> Undefined Then
		Schedule = NewSchedule;
		Modified = True;
	EndIf;
	
EndProcedure


&AtClient
Procedure WriteScheduledJob()
	
	If Not ValueIsFilled(MetadataName) Then
		Return;
	EndIf;
	
	CurrentID = ?(Action = "Change", ID, Undefined);
	
	WriteScheduledJobAtServer();
	RefreshFormTitle();
	
	Notify("Write_ScheduledJobs", CurrentID);
	
EndProcedure

&AtServer
Procedure WriteScheduledJobAtServer()
	
	If Action = "Change" Then
		Job = ScheduledJobsServer.GetScheduledJob(ID);
	Else
		Job = ScheduledJobs.CreateScheduledJob(Metadata.ScheduledJobs[MetadataName]);
		
		ID = String(Job.UUID);
		Action = "Change";
	EndIf;
	
	FillPropertyValues(
		Job,
		ThisObject,
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

#EndRegion
