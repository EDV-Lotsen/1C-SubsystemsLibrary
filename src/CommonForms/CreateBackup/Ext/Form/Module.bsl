&AtClient
Var IdleHandlerParameters;

&AtClient
Var LongActionForm;

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	If Not CommonUse.UseSessionSeparator() Then 
		Raise(NStr("en = 'The separator value is not specified.'"));
	EndIf;
	
	SwitchPage(ThisObject);
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure CreateAreaCopy(Command)
	
	Try
		Result = CreateAreaCopyAtServer();
	Except	
		SwitchPage(ThisObject, "PageAfterExportError");
	EndTry;
	
	If Result.JobCompleted Then
		ProcessJobExecutionResult();
	Else
		LongActionsClient.InitIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler("Attachable_CheckJobExecution", 1, True);
		LongActionForm = LongActionsClient.OpenLongActionForm(ThisObject, JobID);
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure Attachable_CheckJobExecution()
	
	Try
		If LongActionForm.IsOpen() 
			And LongActionForm.JobID = JobID Then
			
			If JobCompleted(JobID) Then 
				LongActionsClient.CloseLongActionForm(LongActionForm);
				ProcessJobExecutionResult();
			Else
				LongActionsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
				AttachIdleHandler(
					"Attachable_CheckJobExecution", 
					IdleHandlerParameters.CurrentInterval, 
					True);
			EndIf;
		EndIf;
	Except
		ErrorPresentation = DetailErrorDescription(ErrorInfo());
		LongActionsClient.CloseLongActionForm(LongActionForm);
		SwitchPage(ThisObject, "PageAfterExportError");
		WriteExceptionsAtServer(ErrorPresentation);	
	EndTry;
	
EndProcedure

&AtClient
Procedure ProcessJobExecutionResult()
	
	DisableExclusiveMode();
	
	If Not IsBlankString(StorageAddress) Then
		DeleteFromTempStorage(StorageAddress);
		StorageAddress = "";
		// Go to result page
		SwitchPage(ThisObject, "PageAfterExportSuccess");
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SwitchPage(Form, Val PageName = "PageBeforeExport")
	
	Form.Items.GroupPages.CurrentPage = Form.Items[PageName];
	
	If PageName = "PageBeforeExport" Then
		Form.Items.FormCreateAreaCopy.Enabled = True;
	Else
		Form.Items.FormCreateAreaCopy.Enabled = False;
	EndIf;

EndProcedure

&AtServer
Procedure WriteExceptionsAtServer(Val ErrorPresentation)
	
	DisableExclusiveMode();
	
	Event = DataAreaBackupCached.BackgroundBackupDescription();
	WriteLogEvent(Event, EventLogLevel.Error, , , 
ErrorPresentation);
	ErrorMessage = ErrorPresentation;
	
EndProcedure

&AtServer
Function CreateAreaCopyAtServer()
	
	DataArea = CommonUse.SessionSeparatorValue();
	
	If CommonUseClientServer.IsPlatform83WithoutCompatibilityMode() Then
		CommonUse.LockInfobase();
	EndIf;
	
	JobParameters = DataAreaBackup.CreateEmptyExportParameters();
	JobParameters.DataArea = DataArea;
	JobParameters.CopyID = New UUID;
	JobParameters.Forced = True;
	JobParameters.OnDemand = True;
	
	Try
		Result = LongActions.ExecuteInBackground(
			UUID,
			DataAreaBackupCached.BackgroundBackupMethodName(),
			JobParameters, 
			DataAreaBackupCached.BackgroundBackupDescription());
		
	Except
		ErrorPresentation = DetailErrorDescription(ErrorInfo());
		WriteExceptionsAtServer(ErrorPresentation);
	EndTry;
	
	StorageAddress = Result.StorageAddress;
	JobID = Result.JobID;
	Return Result;
	
EndFunction

&AtServerNoContext
Function JobCompleted(JobID)
	
	Return LongActions.JobCompleted(JobID);
	
EndFunction

&AtServerNoContext
Procedure DisableExclusiveMode()
	
	If CommonUseClientServer.IsPlatform83WithoutCompatibilityMode() Then
		CommonUse.UnlockInfobase();
	EndIf;
	
EndProcedure

#EndRegion
