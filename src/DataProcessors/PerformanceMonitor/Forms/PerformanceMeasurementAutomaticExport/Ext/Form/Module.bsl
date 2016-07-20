&AtClient
Var ExternalResourcesAllowed;

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	DirectoriesForExport = PerformanceMonitorInternal.PerformanceMonitorDataExportDirectories();
	If TypeOf(DirectoriesForExport) <> Type("Structure")
		Or
		 DirectoriesForExport.Count() = 0
	Then
		Return;
	EndIf;
	
	ExecuteExportToFTP = DirectoriesForExport.ExecuteExportToFTP;
	FTPExportDirectory = DirectoriesForExport.FTPExportDirectory;
	ExecuteExportToLocalDirectory = DirectoriesForExport.ExecuteExportToLocalDirectory;
	LocalExportDirectory = DirectoriesForExport.LocalExportDirectory;
	
	ExecuteExport = ExecuteExportToFTP Or ExecuteExportToLocalDirectory;
	
EndProcedure

&AtClient
Procedure ExecuteExportOnChange(Item)
	ExportAllowed = ExecuteExport;
	ExecuteExportToLocalDirectory = ExportAllowed;
	ExecuteExportToFTP = ExportAllowed;
EndProcedure	

&AtClient
Procedure ExecuteExportToDirectoryOnChange(Item)
	ExecuteExport = ExecuteExportToLocalDirectory Or ExecuteExportToFTP;
EndProcedure	

&AtClient
Procedure ExportLocalFileDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	NotifyDescription = New NotifyDescription("SelectExportDirectorySuggested", ThisObject);
	CommonUseClient.ShowFileSystemExtensionInstallationQuestion(NotifyDescription);
	
EndProcedure

&AtServer
Function FillCheckProcessingAtServer()
	ItemsOnControl = New Map;
	ItemsOnControl.Insert(Items.ExecuteExportToLocalDirectory, Items.LocalExportDirectory);
	ItemsOnControl.Insert(Items.ExecuteExportToFTP, Items.FTPExportDirectory);
	
	NoErrors = True;	
	For Each PathFlag In ItemsOnControl Do
		ExecuteFlag = ThisObject[PathFlag.Key.DataPath];
		PathItem = PathFlag.Value;
		If ExecuteFlag And IsBlankString(TrimAll(ThisObject[PathItem.DataPath])) Then
			MessageText = NStr("en = '""%1"" field is required'");
			MessageText = StrReplace(MessageText, "%1", PathItem.Title);
			CommonUseClientServer.MessageToUser(
				MessageText,
				,
				PathItem.Name,
				PathItem.DataPath);
			NoErrors = False;
		EndIf;
	EndDo;
	
	Return NoErrors;	
EndFunction

&AtServer
Procedure SaveAtServer()
	
	ExecuteLocalDirectory = New Array;
	ExecuteLocalDirectory.Add(ExecuteExportToLocalDirectory);
	ExecuteLocalDirectory.Add(TrimAll(ThisObject.LocalExportDirectory));
	
	ExecuteFTPDirectory = New Array;
	ExecuteFTPDirectory.Add(ExecuteExportToFTP);
	ExecuteFTPDirectory.Add(TrimAll(ThisObject.FTPExportDirectory));
	
	SetExportDirectory(ExecuteLocalDirectory, ExecuteFTPDirectory);  

	SetUseScheduledJob(ExecuteExport);
	Modified = False;
	
EndProcedure

&AtClient
Procedure LocalExportDirectoryOnChange(Item)
	
	ExternalResourcesAllowed = False;
	
EndProcedure

&AtClient
Procedure FTPExportDirectoryOnChange(Item)
	
	ExternalResourcesAllowed = False;
	
EndProcedure

///////////////////////////////////////////////////////////////////////
// COMMAND HANDLERS

&AtClient
Procedure SetExportSchedule(Command)
	
	JobSchedule = PerformanceMonitorDataExportSchedule();
	
	Notification = New NotifyDescription("SetExportScheduleCompletion", ThisObject);
	Dialog = New ScheduledJobDialog(JobSchedule);
	Dialog.Show(Notification);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure SelectExportDirectorySuggested(FileSystemExtensionAttached, AdditionalParameters) Export
	
	If FileSystemExtensionAttached Then
		
		SelectFile = New FileDialog(FileDialogMode.ChooseDirectory);
		SelectFile.Multiselect = False;
		SelectFile.Title = NStr("en = 'Select export directory'");
		
		If SelectFile.Choose() Then
			SelectedDirectory = SelectFile.Directory;
			LocalExportDirectory = SelectedDirectory;
			ThisObject.Modified = True;
		EndIf;
		
	EndIf;
	
EndProcedure

// Changes the export directory.
//
// Parameters:
//  ExportDirectory - String - new export directory.
//
&AtServerNoContext
Procedure SetExportDirectory(ExecuteLocalExportDirectory, ExecuteFTPExportDirectory)
	
	Job = PerformanceMonitorInternal.PerformanceMonitorDataExportScheduledJob();
	
	Directories = New Structure();
	Directories.Insert(PerformanceMonitorClientServer.LocalExportDirectoryJobKey(), ExecuteLocalExportDirectory);
	Directories.Insert(PerformanceMonitorClientServer.FTPExportDirectoryJobKey(), ExecuteFTPExportDirectory);
	
	JobParameters = New Array;	
	JobParameters.Add(Directories);
	Job.Parameters = JobParameters;
	CommitScheduledJob(Job);
	
EndProcedure

// Changes scheduled job usage flag.
//
// Parameters:
//  NewValue - Boolean - new usage value.
//
// Returns:
//  Boolean - flag state before the change (the previous state).
//
&AtServerNoContext
Function SetUseScheduledJob(NewValue)
	
	Job = PerformanceMonitorInternal.PerformanceMonitorDataExportScheduledJob();
	CurrentState = Job.Use;
	If CurrentState <> NewValue Then
		Job.Use = NewValue;
		CommitScheduledJob(Job);
	EndIf;
	
	Return CurrentState;
	
EndFunction

// Returns the current job schedule.
//
// Returns:
//  JobSchedule - current schedule.
//
&AtServerNoContext
Function PerformanceMonitorDataExportSchedule()
	
	Job = PerformanceMonitorInternal.PerformanceMonitorDataExportScheduledJob();
	Return Job.Schedule;
	
EndFunction

// Sets a new job schedule.
//
// Parameters:
//  NewSchedule - JobSchedule - new schedule.
//
&AtServerNoContext
Procedure SetSchedule(Val NewSchedule)
	
	Job = PerformanceMonitorInternal.PerformanceMonitorDataExportScheduledJob();
	Job.Schedule = NewSchedule;
	CommitScheduledJob(Job);
	
EndProcedure

// Saves scheduled job settings.
//
// Parameters:
//  Job - ScheduledJob.PerformanceMonitorDataExport.
//
&AtServerNoContext
Procedure CommitScheduledJob(Job)
	
	SetPrivilegedMode(True);
	Job.Write();
	
EndProcedure

&AtClient
Procedure SetExportScheduleCompletion(Schedule, AdditionalParameters) Export
	
	If Schedule <> Undefined Then
		SetSchedule(Schedule);
	EndIf;
	
EndProcedure

&AtClient
Procedure SaveSettings(Command)
	
	If FillCheckProcessingAtServer() Then
		ValidatePermissionToAccessExternalResources(False);
	EndIf;
	
EndProcedure

&AtClient
Procedure SaveClose(Command)
	
	If FillCheckProcessingAtServer() Then
		ValidatePermissionToAccessExternalResources(True);
	EndIf;
	
EndProcedure

&AtClient
Function ValidatePermissionToAccessExternalResources(CloseForm)
	
	If ExternalResourcesAllowed <> True Then
		If CloseForm Then
			ClosingNotification = New NotifyDescription("AllowExternalResourceSaveAndClose", ThisObject);
		Else
			ClosingNotification = New NotifyDescription("AllowExternalResourceSave", ThisObject);
		EndIf;
		
		Directories = New Structure;
		Directories.Insert("ExecuteExportToFTP", ExecuteExportToFTP);
		
		URLStructure = CommonUseClientServer.URIStructure(FTPExportDirectory);
		Directories.Insert("FTPExportDirectory", URLStructure.ServerName);
		If ValueIsFilled(URLStructure.Port) Then
			Directories.Insert("FTPExportDirectoryPort", URLStructure.Port);
		EndIf;
		
		Directories.Insert("ExecuteExportToLocalDirectory", ExecuteExportToLocalDirectory);
		Directories.Insert("LocalExportDirectory", LocalExportDirectory);
		
		Request = RequestToUseExternalResources(Directories);
		
		SafeModeClient.ApplyExternalResourceRequests(
			CommonUseClientServer.ValueInArray(Request), ThisObject, ClosingNotification);
			
	ElsIf CloseForm Then
		SaveAtServer();
		ThisObject.Close();
		
	Else
		SaveAtServer();
	EndIf;
	
EndFunction

&AtServerNoContext
Function RequestToUseExternalResources(Directories)
	
	Return PerformanceMonitorInternal.RequestToUseExternalResources(Directories);
	
EndFunction

&AtClient
Procedure AllowExternalResourceSaveAndClose(Result, NotDefined) Export
	
	If Result = DialogReturnCode.OK Then
		ExternalResourcesAllowed = True;
		SaveAtServer();
		ThisObject.Close();
	EndIf;
	
EndProcedure

&AtClient
Procedure AllowExternalResourceSave(Result, NotDefined) Export
	
	If Result = DialogReturnCode.OK Then
		ExternalResourcesAllowed = True;
		SaveAtServer();
	EndIf;
	
EndProcedure

#EndRegion