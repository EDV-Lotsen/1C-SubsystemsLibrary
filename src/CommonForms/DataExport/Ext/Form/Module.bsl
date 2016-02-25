&AtClient
Var CheckIteration;

////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Autotest") Then // Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
		Return;
	EndIf;
	
	If CommonUseCached.DataSeparationEnabled() Then
		FormTitleText = NStr("en = 'Export data into local version'");
		MessageText      = NStr("en = 'Data will be exported from the service to a
			|file, for further import to the local version.'");
	Else
		FormTitleText = NStr("en = 'Export data for migration to service'");
		MessageText      = NStr("en = 'Data will be exported from the local version to a
			|file, for further import and use SaaS.'");
	EndIf;
	Items.WarningDecoration.Title = MessageText;
	Title = FormTitleText;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure OpenActiveUsersForm(Command)
	
	OpenForm("DataProcessor.ActiveUsers.Form.ActiveUsersListForm");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure ExportData(Command)
	
	If StandardSubsystemsClientCached.ClientParameters().FileInfobase Then
		
		PrepareDataExport();
		SaveExportFile();
	Else
		
		StartDataExport();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Procedure PrepareDataExport()
	
	StorageAddress = PutToTempStorage(Undefined, UUID);
	DataAreaExportImport.ExportCurrentDataAreaToTemporaryStorage(StorageAddress);
	
EndProcedure

&AtClient 
Procedure SaveExportFile()
	
	FileName = "data_dump.zip";
	
	If AttachFileSystemExtension() Then
		
		FilesToBeObtained = New Array;
		
		ChoiceDialog = New FileDialog(FileDialogMode.Save);
		ChoiceDialog.Filter = "ZIP archive(*.zip)|*.zip";
		ChoiceDialog.Extension = "zip";
		ChoiceDialog.FullFileName = FileName;
		
		If ChoiceDialog.Choose() Then
			FileDetails = New TransferableFileDescription(ChoiceDialog.FullFileName, StorageAddress);
			FilesToBeObtained.Add(FileDetails);
			
			GetFiles(FilesToBeObtained, , , False);
			
		EndIf;
		
	Else
		
		GetFile(StorageAddress, FileName, True);
		
	EndIf;
	
	Close();
	
EndProcedure

&AtClient
Procedure StartDataExport()
	
	StartDataExportAtServer();
	
	Items.GroupPages.CurrentPage = Items.Data;
	
	CheckIteration = 1;
	
	AttachIdleHandler("CheckExportReadyState", 15);
	
EndProcedure

&AtClient
Procedure CheckExportReadyState()
	
	Try
		ExportReadyState = ExportDataReady();
	Except
		DetachIdleHandler("CheckExportReadyState");
		Raise;
	EndTry;
	
	If ExportReadyState Then
		DetachIdleHandler("CheckExportReadyState");
		SaveExportFile();
	Else
		
		CheckIteration = CheckIteration + 1;
		
		If CheckIteration = 3 Then
			DetachIdleHandler("CheckExportReadyState");
			AttachIdleHandler("CheckExportReadyState", 30);
		ElsIf CheckIteration = 4 Then
			DetachIdleHandler("CheckExportReadyState");
			AttachIdleHandler("CheckExportReadyState", 60);
		EndIf;
			
	EndIf;
	
EndProcedure

&AtServerNoContext
Function FindJobByID(ID)
	
	Job = BackgroundJobs.FindByUUID(ID);
	
	Return Job;
	
EndFunction

&AtServer
Function ExportDataReady()
	
	Job = FindJobByID(JobID);
	
	If Job <> Undefined
		And Job.State = BackgroundJobState.Active Then
		
		Return False;
	EndIf;
	
	Items.GroupPages.CurrentPage = Items.Warning;
	
	If Job = Undefined Then
		Raise(NStr("en = 'Error while preparing for data export - export preparation job is not found.'"));
	EndIf;
	
	If Job.State = BackgroundJobState.Failed Then
		JobError = Job.ErrorInfo;
		If JobError <> Undefined Then
			Raise(DetailErrorDescription(JobError));
		Else
			Raise(NStr("en = 'Error while preparing for data export - export preparation job terminated with an unknown error.'"));
		EndIf;
	ElsIf Job.State = BackgroundJobState.Canceled Then
		Raise(NStr("en = 'Error while preparing for data export - export preparation job is cancelled by administrator.'"));
	Else
		JobID = Undefined;
		Return True;
	EndIf;
	
EndFunction

&AtServer
Procedure StartDataExportAtServer()
	
	StorageAddress = PutToTempStorage(Undefined, UUID);
	
	JobParameters = New Array;
	JobParameters.Add(StorageAddress);

	Job = BackgroundJobs.Execute("DataAreaExportImport.ExportCurrentDataAreaToTemporaryStorage", 
		JobParameters,
		,
		NStr("en = 'Preparing data area export'"));
		
	JobID = Job.UUID;
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If ValueIsFilled(JobID) Then
		CancelInitializationJob(JobID);
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure CancelInitializationJob(Val JobID)
	
	Job = FindJobByID(JobID);
	If Job = Undefined
		Or Job.State <> BackgroundJobState.Active Then
		
		Return;
	EndIf;
	
	Try
		Job.Cancel();
	Except
		// It is possible that the job has completed at that moment and no error has occurred
		WriteLogEvent(NStr("en = 'Canceling data area export preparation job'", 
			CommonUseClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,,,
			DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure
