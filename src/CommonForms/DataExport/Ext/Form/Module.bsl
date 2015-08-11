&AtClient
Var CheckIteration;

////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If CommonUseCached.DataSeparationEnabled() Then
		FormHeaderText = NStr("en = 'Export data for migration to local infobase'");
		MessageText = NStr("en = 'Data will be exported from the service into a file.			
			|Use this file for importing data into infobase that operates in file or client/server mode).'");
	Else
		FormHeaderText = NStr("en = 'Export data for migration to service");
		MessageText = NStr("en = 'Data will be exported from the local infobase into a file
			|Use this file for importing data into infobase that operates in service mode.'");
	EndIf;
	Items.WarningDecoration.Title = MessageText;
	Title = FormHeaderText;
	
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
	
	If CommonUse.FileInfoBase() Then
		
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
	
	DataImportExport.ExportCurrentAreaToTempStorage(StorageAddress);
	
EndProcedure

&AtClient 
Procedure SaveExportFile()
	
	FileName = "data_dump.zip";
	
	If AttachFileSystemExtension() Then
		
		FilesToReceive = New Array;
		
		ChoiceDialog = New FileDialog(FileDialogMode.Save);
		ChoiceDialog.Filter = "ZIP Archive(*.zip)|*.zip";
		ChoiceDialog.Extension = "zip";
		ChoiceDialog.FullFileName = FileName;
		
		If ChoiceDialog.Choose() Then
			FileDetails = New TransferableFileDescription(ChoiceDialog.FullFileName, StorageAddress);
			FilesToReceive.Add(FileDetails);
			
			GetFiles(FilesToReceive, , , False);
			
		EndIf;
		
	Else
		
		GetFile(StorageAddress, FileName, True);
		
	EndIf;
	
	Close();
	
EndProcedure

&AtClient
Procedure StartDataExport()
	
	StartDataExportAtServer();
	
	Items.GroupPages.CurrentPage = Items.Export;
	
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
	
	If CommonUseCached.DataSeparationEnabled()
		And CommonUseCached.SessionWithoutSeparator() Then
		
		CommonUse.SetSessionSeparation(False);
		Job = BackgroundJobs.FindByUUID(ID);
		CommonUse.SetSessionSeparation(True)
	Else
		Job = BackgroundJobs.FindByUUID(ID);
	EndIf;
	
	Return Job;
	
EndFunction

&AtServer
Function ExportDataReady()
	
	Job = FindJobByID(JobID);
	
	If Job <> Undefined
		And Job.State = BackgroundJobState.Active Then
		
		Return False;
	EndIf;
	
	Items.GroupPages.CurrentPage = Items.Warnings;
	
	If Job = Undefined Then
		Raise(NStr("en = 'Error initializing data export: a job that initializes data export is not found.'"));
	EndIf;
	
	If Job.State = BackgroundJobState.Failed Then
		JobError = Job.ErrorInfo;
		If JobError <> Undefined Then
			Raise(DetailErrorDescription(JobError));
		Else
			Raise(NStr("en = 'Error initializing data export: a job that initializes data export finished with an unknown error.'"));
		EndIf;
	ElsIf Job.State = BackgroundJobState.Canceled Then
		Raise(NStr("en = 'Error initializing data export: an administrator canceled a job that prepares data export.'"));
	Else
		JobID = Undefined;
		Return True;
	EndIf;
	
EndFunction

&AtServer
Procedure StartDataExportAtServer()
	
	StorageAddress = PutToTempStorage(Undefined, UUID);
	
	If CommonUseCached.DataSeparationEnabled()
		And CommonUseCached.SessionWithoutSeparator() Then
		
		JobParameters = New Array;
		JobParameters.Add(CommonUse.SessionSeparatorValue());
		JobParameters.Add(StorageAddress);
		
		CommonUse.SetSessionSeparation(False);
		
		Job = BackgroundJobs.Execute("DataImportExport.ExportAreaToTempStorage",
			JobParameters,
			,
			NStr("en = 'Initializing data area export'"));
			
		CommonUse.SetSessionSeparation(True)
	Else
		JobParameters = New Array;
		JobParameters.Add(StorageAddress);
		
		Job = BackgroundJobs.Execute("DataImportExport.ExportCurrentAreaToTempStorage", 
			JobParameters,
			,
			NStr("en = 'Initializing data area export'"));
	EndIf;
		
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
		// Perhaps the job finished just at this moment and there is no error.
		WriteLogEvent(NStr("en = 'Canceling the job of initialization of the data area export'", Metadata.DefaultLanguage.LanguageCode),
			EventLogLevel.Error,,,
			DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure