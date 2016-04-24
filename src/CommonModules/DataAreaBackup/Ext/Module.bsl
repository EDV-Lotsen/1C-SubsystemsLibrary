////////////////////////////////////////////////////////////////////////////////
// DataAreaBackup.
//  
////////////////////////////////////////////////////////////////////////////////

#Region Interface

////////////////////////////////////////////////////////////////////////////////
// Message exchange

// Returns the usage status of the data area backup.
//
// Return value: Boolean.
//
Function BackupUsed() Export
	
	SetPrivilegedMode(True);
	Return Constants.BackupSupported.Get();
	
EndFunction

#EndRegion

#Region InternalProceduresAndFunctions

// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS
	
	If CommonUse.SubsystemExists
("StandardSubsystems.SaaSOperations.JobQueue") Then
		ServerHandlers[
 
			"StandardSubsystems.SaaSOperations.JobQueue\OnDefineHandlerAliases"].Add
(
				"DataAreaBackup");
	EndIf;
	
	ServerHandlers[
		"StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
			"DataAreaBackup");
	
	ServerHandlers[
 
		"StandardSubsystems.BaseFunctionality\SupportedInterfaceVersionsOnDefine"].Add
(
			"DataAreaBackup");
	
	If CommonUse.SubsystemExists("CloudTechnology.DataImportExport") 
Then
		ServerHandlers[
 
			"CloudTechnology.DataImportExport\OnFillExcludedFromImportExportTypes"].Add
(
				"DataAreaBackup");
	EndIf;
	
	ServerHandlers[
		"StandardSubsystems.SaaSOperations\InfobaseParameterTableOnFill"].Add
(
			"DataAreaBackup");
			
	ServerHandlers[
 
		"StandardSubsystems.SaaSOperations.JobQueue\OnDefineErrorHandlers"].Add
(
			"DataAreaBackup");
	
	ServerHandlers[
		"StandardSubsystems.SaaSOperations.MessageExchange\RecordingIncomingMessageInterfaces"].Add(
			"DataAreaBackup");
	
	ServerHandlers[
		"StandardSubsystems.SaaSOperations.MessageExchange\RecordingOutgoingMessageInterfaces"].Add(
			"DataAreaBackup");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Internal event handlers of SL subsystems

// Fills a map of method names and their aliases for calling from a job queue.
//
// Parameters:
//  NameAndAliasMap - Map
//    Key   - method alias, example: ClearDataArea.
//    Value - method name, example: SaaSOperations.ClearDataArea.
//            You can set Value to Undefined if the name is identical to the alias.
//
Procedure OnDefineHandlerAliases(NameAndAliasMap) Export
	
	NameAndAliasMap.Insert
("DataAreaBackup.ExportAreaToSMStorage");
	NameAndAliasMap.Insert("DataAreaBackup.DataBackup");
	
EndProcedure

// Fills the structure with arrays of supported versions of the subsystems that can have versions. 
// Subsystem names are used as structure keys.
// Implements the InterfaceVersion web service functionality.
// This procedure must return actual version sets, therefore its body must be changed before using. 
// See the example below.
//
// Parameters:
// SupportedVersionStructure - Structure: 
// - Keys = subsystem names. 
// - Values = arrays of supported version names.
//
// Implementation example:
//
// // FileTransferService
// VersionArray = New Array;
// VersionArray.Add("1.0.1.1");	
// VersionArray.Add("1.0.2.1"); 
// SupportedVersionStructure.Insert("FileTransferService", VersionArray);
// // End FileTransferService
//
Procedure SupportedInterfaceVersionsOnDefine(Val 
SupportedVersionStructure) Export
	
	VersionArray = New Array;
	VersionArray.Add("1.0.1.1");
	VersionArray.Add("1.0.1.2");
	SupportedVersionStructure.Insert("DataAreaBackup", 
VersionArray);
	
EndProcedure

// Adds update handlers that are required by the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see the description of NewUpdateHandlerTable function in the InfobaseUpdate common module.
//
Procedure OnAddUpdateHandlers(Handlers) Export
	
	//Handler = Handlers.Add();
	//Handler.Version = "2.1.3.9";
	//Handler.Procedure = "DataAreaBackup.CopyBackupPlanningStateToAuxiliaryData";
	//Handler.SharedData = True;
	
EndProcedure

// Fills the array of types excluded from data import and export.
//
// Parameters:
//  Types - Array(Types).
//
Procedure OnFillExcludedFromImportExportTypes(Types) Export
	
	Types.Add(Metadata.Constants.BackUpDataArea);
	Types.Add(Metadata.Constants.LastClientSessionStartDate);
	
EndProcedure

// Generates the list of infobase parameters.
//
// Parameters:
// ParameterTable - ValueTable - parameter description table.
// For description of column content, see SaaSOperations.GetInfobaseParameterTable().
//
Procedure InfobaseParameterTableOnFill(ParameterTable) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations") 
Then
		SaasOperationsModule = CommonUse.CommonModule("SaaSOperations");
		CurParameterString = SaasOperationsModule.AddConstantToInfobaseParameterTable(ParameterTable, "BackupSupported");
	EndIf;
	
EndProcedure

// Sets a mapping between error handler methods and 
// aliases of methods where errors occur.
//
// Parameters:
//   ErrorHandlers - Map
//     Key   - method alias, example: ClearDataArea.
//     Value - method name - error handler, called upon error. 
//             The error handler is called whenever a job execution fails. 
//             The error handler is always called in the data area of the failed job.
//             The error handler method can be called by the queue mechanisms. 
//             Error handler parameters:
//               JobParameters - Structure - queue job parameters.
//                 Parameters
//                 AttemptNumber
//                 RestartCountOnFailure
//               BeginDateOfLastStart 
//             ErrorInfo - ErrorInfo - description of error that occurred during job execution.
//
Procedure OnDefineErrorHandlers(ErrorHandlers) Export
	
	ErrorHandlers.Insert(
		"DataAreaBackup.DataBackup",
		"DataAreaBackup.BackupCreationError");
	
EndProcedure

// Fills the passed array with common modules that contain handlers for interfaces 
// of incoming messages.
//
// Parameters:
//  HandlerArray - array.
//
Procedure RecordingIncomingMessageInterfaces(HandlerArray) Export
	
	HandlerArray.Add(MessagesBackupManagementInterface);
	
EndProcedure

// Fills the passed array with common modules that contain handlers for interfaces 
// of outgoing messages.
//
// Parameters:
//  HandlerArray - array.
//
//
Procedure RecordingOutgoingMessageInterfaces(HandlerArray) Export
	
	HandlerArray.Add(MessagesBackupControlInterface);
	
EndProcedure

// Active users in data area

// Sets user activity flag in the current area.
// The flag is the value of the LastClientSessionStartDate constant 
// with Usage of split data set to Independent and Shared.
//
Procedure SetUserActivityInAreaFlag() Export
	
	If Not CommonUseCached.IsSeparatedConfiguration()
		Or Not CommonUseCached.CanUseSeparatedData()
		Or CurrentRunMode() = Undefined
		Or Not GetFunctionalOption("BackupSupported")
		Or SaaSOperations.DataAreaLocked(CommonUse.SessionSeparatorValue()) Then
		
		Return;
		
	EndIf;
	
	SetAreaActivityFlag(); // For backward compatibility
	
	StartDate = BegOfDay(CurrentUniversalDate());
	
	If Constants.LastClientSessionStartDate.Get() = StartDate Then
		Return;
	EndIf;
	
	Constants.LastClientSessionStartDate.Set(StartDate);
	
EndProcedure

// Sets or clears user activity flag in the current area.
// The flag is the value of the BackUpDataArea constant 
// with Usage of split data set to Independent and Shared.
// Obsolete.
//
// Parameters:
//   DataArea - Number, Undefined - separator value. 
//              Undefined means the value of the current data area separator.
//   State    - Boolean - True if the flag is set; False if cleared.
//
Procedure SetAreaActivityFlag(Val DataArea = Undefined, Val 
State = True)
	
	If DataArea = Undefined Then
		If CommonUseCached.CanUseSeparatedData() Then
			DataArea = CommonUse.SessionSeparatorValue();
		Else
			Raise NStr("en = 'When the SetAreaActivityFlag procedure is called from a shared session, the DataArea parameter is mandatory.'");
		EndIf;
	Else
		If Not CommonUseCached.SessionWithoutSeparators()
				And DataArea <> CommonUse.SessionSeparatorValue() Then
			
			Raise(NStr("en = 'Access to areas other than the current one is prohibited'"));
			
		EndIf;
	EndIf;
	
	SetPrivilegedMode(True);
	
	If State Then
		ValueManager = Constants.BackUpDataArea.CreateValueManager();
		ValueManager.DataAreaAuxiliaryData = DataArea;
		ValueManager.Read();
		If ValueManager.Value Then
			Return;
		EndIf;
	EndIf;
	
	ActivityFlag = Constants.BackUpDataArea.CreateValueManager();
	ActivityFlag.DataAreaAuxiliaryData = DataArea;
	ActivityFlag.Value = State;
	CommonUse.WriteAuxiliaryData(ActivityFlag);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Exporting data areas.

// Creates an area backup in accordance with the area backup settings.
//
// Parameters:
//   CreationParameters - FixedStructure - backup creation parameters, which match the backup settings.
//   CreationStatus     - FixedStructure - state of the area backup creation process.
//
Procedure DataBackup(Val CreationParameters, Val CreationStatus) Export
	
	ExecutionStarted = CurrentUniversalDate();
	
	BackupCreationConditions = New Array;
	
	Parameters = New Structure;
	Parameters.Insert("Type", "Daily");
	Parameters.Insert("Enabled", "CreateDailyBackups");
	Parameters.Insert("Periodicity", "Day");
	Parameters.Insert("CreationDate", "LastDailyBackupCreationDate");
	Parameters.Insert("Day", Undefined);
	Parameters.Insert("Month", Undefined);
	BackupCreationConditions.Add(Parameters);
	
	Parameters = New Structure;
	Parameters.Insert("Type", "Monthly");
	Parameters.Insert("Enabled", "CreateMonthlyBackups");
	Parameters.Insert("Periodicity", "Month");
	Parameters.Insert("CreationDate", "LastMonthlyBackupCreationDate");
	Parameters.Insert("Day", "MonthlyCreationDate");
	Parameters.Insert("Month", Undefined);
	BackupCreationConditions.Add(Parameters);
	
	Parameters = New Structure;
	Parameters.Insert("Type", "Yearly");
	Parameters.Insert("Enabled", "CreateYearlyBackups");
	Parameters.Insert("Periodicity", "Year");
	Parameters.Insert("CreationDate", "LastYearlyBackupCreationDate");
	Parameters.Insert("Day", "YearlyBackupCreationDate");
	Parameters.Insert("Month", "YearlyBackupCreationMonth");
	BackupCreationConditions.Add(Parameters);
	
	CreationRequired = False;
	CurrentDate = CurrentUniversalDate();
	
	LastSession = Constants.LastClientSessionStartDate.Get();
	
	CreateUnconditionally = Not CreationParameters.OnlyWhenUsersActive;
	
	PeriodicityFlags = New Structure;
	For Each PeriodicityParameters In BackupCreationConditions Do
		
		PeriodicityFlags.Insert(PeriodicityParameters.Type, False);
		
		If Not CreationParameters[PeriodicityParameters.Enabled] Then
			// Backups with this periodicity are disabled in the settings
			Continue;
		EndIf;
		
		PreviousBackupCreationDate = CreationStatus[PeriodicityParameters.CreationDate];
		
		If Year(CurrentDate) = Year(PreviousBackupCreationDate) Then
			If PeriodicityParameters.Periodicity = "Year" Then
				// The year has not changed yet
				Continue;
			EndIf;
		EndIf;
		
		If Month(CurrentDate) = Month(PreviousBackupCreationDate) Then
			If PeriodicityParameters.Periodicity = "Month" Then
				// The month has not changed yet
				Continue;
			EndIf;
		EndIf;
		
		If Day(CurrentDate) = Day(PreviousBackupCreationDate) Then
			// The day has not changed yet
			Continue;
		EndIf;
		
		If PeriodicityParameters.Day <> Undefined
			And Day(CurrentDate) < CreationParameters[PeriodicityParameters.Day] Then
			
			// The backup day has not come yet
			Continue;
		EndIf;
		
		If PeriodicityParameters.Month <> Undefined
			And Month(CurrentDate) < CreationParameters[PeriodicityParameters.Month] Then
			
			// The backup month has not come yet
			Continue;
		EndIf;
		
		If Not CreateUnconditionally
			And ValueIsFilled(PreviousBackupCreationDate)
			And LastSession < PreviousBackupCreationDate Then
			
			// Users did not enter the area since the backup creation
			Continue;
		EndIf;
		
		CreationRequired = True;
		PeriodicityFlags.Insert(PeriodicityParameters.Type, True);
		
	EndDo;
	
	If Not CreationRequired Then
		WriteLogEvent(
			EventLogMessageText() + "." 
				+ NStr("en = 'Skipping backup creation'", CommonUseClientServer.DefaultLanguageCode()),
			EventLogLevel.Information);
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	If Not CommonUse.SubsystemExists
("CloudTechnology.SaaSOperations.DataAreaExportImport") Then
		
		SaaSOperations.RaiseNoCTLSubsystemException("CloudTechnology.SaaSOperations.DataAreaExportImport");
		
	EndIf;
	
	DataAreaExportImportModule = CommonUse.CommonModule
("DataAreaExportImport");
	
	ArchiveName = Undefined;
	
	LockParameters = InfobaseConnections.NewConnectionLockParameters();
	LockParameters.Beginning = CurrentUniversalDate();
	LockParameters.Message = NStr("en = 'Creating application backup. You can change the backup settings in the service manager.'");
	LockParameters.Use = True;
	
	InfobaseConnections.SetDataAreaSessionLock(LockParameters, False);
	
	ArchiveName = DataAreaExportImportModule.ExportCurrentDataAreaToArchive();
	
	BackupCreationDate = CurrentUniversalDate();
	
	ArchiveDescription = New File(ArchiveName);
	FileSize = ArchiveDescription.Size();
	
	FileID = SaaSOperations.PutFileToServiceManagerStorage(ArchiveDescription);
	
	Try
		DeleteFiles(ArchiveName);
	Except
		// If a file cannot be deleted, backup creation must not be interrupted 
 EndTry;
	
	BackupID = New UUID;
	
	MessageParameters = New Structure;
	MessageParameters.Insert("DataArea", CommonUse.SessionSeparatorValue());
	MessageParameters.Insert("BackupID", BackupID);
	MessageParameters.Insert("FileID", FileID);
	MessageParameters.Insert("CreationDate", BackupCreationDate);
	For Each KeyAndValue In PeriodicityFlags Do
		MessageParameters.Insert(KeyAndValue.Key, KeyAndValue.Value);
	EndDo;
	
	SendAreaBackupCreatedMessage(MessageParameters);
	
	// Refreshing status in the parameters
	JobFilter = New Structure;
	JobFilter.Insert("MethodName", "DataAreaBackup.DataBackup");
	JobFilter.Insert("Key", "1");
	Jobs = JobQueue.GetJobs(JobFilter);
	If Jobs.Count() > 0 Then
		Job = Jobs[0].ID;
		
		MethodParameters = New Array;
		MethodParameters.Add(CreationParameters);
		
		UpdatedState = New Structure;
		For Each PeriodicityParameters In BackupCreationConditions Do
			If PeriodicityFlags[PeriodicityParameters.Type] Then
				StateDate = BackupCreationDate;
			Else
				StateDate = CreationStatus[PeriodicityParameters.CreationDate];
			EndIf;
			
			UpdatedState.Insert(PeriodicityParameters.CreationDate, StateDate);
		EndDo;
		
		MethodParameters.Add(New FixedStructure(UpdatedState));
		
		JobParameters = New Structure;
		JobParameters.Insert("Parameters", MethodParameters);
		JobQueue.ChangeJob(Job, JobParameters);
	EndIf;
	
	LockParameters = InfobaseConnections.NewConnectionLockParameters();
	LockParameters.Use = False;
	
	InfobaseConnections.SetDataAreaSessionLock(LockParameters, False);
	
	EventParameters = New Structure;
	For Each KeyAndValue In PeriodicityFlags Do
		EventParameters.Insert(KeyAndValue.Key, KeyAndValue.Value);
	EndDo;
	EventParameters.Insert("BackupID", BackupID);
	EventParameters.Insert("FileID", FileID);
	EventParameters.Insert("Size", FileSize);
	EventParameters.Insert("Duration", CurrentUniversalDate() - ExecutionStarted);
	
	WriteEventToLog(
		NStr("en = 'Creating backup'", CommonUseClientServer.DefaultLanguageCode()),
		EventParameters);
	
EndProcedure

// When the number of attempts to create a backup copy is exhausted, writes 
// the message that the backup is not created to the event log.
//
// Parameters:
//   JobParameters - Structure - see description of the 
//                   StandardSubsystems.SaasOperation.JobQueue\OnDefineErrorHandlers event.
//
Procedure BackupCreationError(Val JobParameters, Val ErrorInfo) Export
	
	If JobParameters.AttemptNumber < 
JobParameters.RestartCountOnFailure Then
		CommentPattern = NStr("en = 'An error occurred when creating %1 area backup.
			|Attempt number: %2
			|Reason:
     |%3'");
		Level = EventLogLevel.Warning;
		Event = NStr("en = 'Backup creation attempt error'", CommonUseClientServer.DefaultLanguageCode());
	Else
		CommentPattern = NStr("en = ''An unrecoverable error occurred when creating %1 area backup.
			|Attempt number: %2
			|Reason:
     |%3'");
		Level = EventLogLevel.Error;
		Event = NStr("en = 'Backup creation error'", CommonUseClientServer.DefaultLanguageCode());
		
		LockParameters = InfobaseConnections.NewConnectionLockParameters();
		LockParameters.Use = False;
		
		InfobaseConnections.SetDataAreaSessionLock(LockParameters, False);
	EndIf;
	
	CommentText = StringFunctionsClientServer.SubstituteParametersInString(
		CommentPattern,
		Format(CommonUse.SessionSeparatorValue(), "NZ=0;NG="),
		JobParameters.AttemptNumber,
		DetailErrorDescription(ErrorInfo));
		
	WriteLogEvent(
		EventLogMessageText() + "." + Event,
		Level,
		,
		,
		CommentText);
	
EndProcedure

// Schedules data area backup creation.
// 
// Parameters:
//   ExportParameters - Structure - for the list of keys, see CreateEmptyExportParameters().
//   
Procedure ScheduleArchivingInQueue(Val ExportParameters) Export
	
	If Not Users.InfobaseUserWithFullAccess() Then
		Raise(NStr("en = 'Insufficient rights to perform the operation'"));
	EndIf;
	
	SetPrivilegedMode(True);
	
	MethodParameters = New Array;
	MethodParameters.Add(ExportParameters);
	MethodParameters.Add(Undefined);
	
	JobParameters = New Structure;
	JobParameters.Insert("MethodName", DataAreaBackupCached.BackgroundBackupMethodName());
	JobParameters.Insert("Key", "" + ExportParameters.BackupID);
	JobParameters.Insert("DataArea", ExportParameters.DataArea);
	
	// Searching for active jobs with the same key
	ActiveJobs = JobQueue.GetJobs(JobParameters);
	
	If ActiveJobs.Count() = 0 Then
		
		// Planning execution of a new job
		
		JobParameters.Insert("Parameters", MethodParameters);
		JobParameters.Insert("ScheduledStartTime", 
ExportParameters.StartTime);
		
		JobQueue.AddJob(JobParameters);
	Else
		If ActiveJobs[0].JobState <> Enums.JobStates.Scheduled 
Then
			// The job is already completed or is running
			Return;
		EndIf;
		
		JobParameters.Delete("DataArea");
		
		JobParameters.Insert("Use", True);
		JobParameters.Insert("Parameters", MethodParameters);
		JobParameters.Insert("ScheduledStartTime", 
ExportParameters.StartTime);
		
		JobQueue.ChangeJob(ActiveJobs[0].ID, JobParameters);
	EndIf;
	
EndProcedure

// Creates a data export file in the specified area and puts it in a service manager storage.
//
// Parameters:
//   ExportParameters - Structure with the following fields:
// 	  - DataArea - Number.
//     - BackupID - UUID, Undefined.
//     - StartTime - Date - area backup start time.
//     - Forced - Boolean - flag from the service manager: create backup regardless of the user activity.
//     - OnDemand - Boolean - flag of the interactive backup start. If the flag value comes from the 
//                            service manager,it is always False.
//     - FileID - UUID - Export file ID in MS storage.
//     - AttemptNumber - Number - attempt counter. Initial value: 1.
//
Procedure ExportAreaToSMStorage(Val ExportParameters, StorageAddress = 
Undefined) Export
	
	If Not Users.InfobaseUserWithFullAccess() Then
		Raise(NStr("en = 'Access right violation'"));
	EndIf;
	
	SetPrivilegedMode(True);
	
	If Not ExportRequired(ExportParameters) Then
		SendAreaBackupSkippedMessage(ExportParameters);
		Return;
	EndIf;
	
	If Not CommonUse.SubsystemExists
("CloudTechnology.SaaSOperations.DataAreaExportImport") Then
		
		SaaSOperations.RaiseNoCTLSubsystemException("CloudTechnology.SaaSOperations.DataAreaExportImport");
		
	EndIf;
	
	DataAreaExportImportModule = CommonUse.CommonModule
("DataAreaExportImport");
	
	ArchiveName = Undefined;
	
	Try
		
		ArchiveName = DataAreaExportImportModule.ExportCurrentDataAreaToArchive();
		FileID = SaaSOperations.PutFileToServiceManagerStorage(New File
(ArchiveName));
		Try
			DeleteFiles(ArchiveName);
		Except
			// If a file cannot be deleted, backup creation must not be interrupted 	
EndTry;
		
		BeginTransaction();
		
		Try
			
			ExportParameters.Insert("FileID", FileID);
			ExportParameters.Insert("CreationDate", CurrentUniversalDate());
			SendAreaBackupCreatedMessage(ExportParameters);
			If ValueIsFilled(StorageAddress) Then
				PutToTempStorage(FileID, StorageAddress);
			EndIf;
			SetAreaActivityFlag(ExportParameters.DataArea, False);
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			Raise;
			
		EndTry;
		
	Except
		
		WriteLogEvent(NStr("en = 'Creating data area backup'", CommonUseClientServer.DefaultLanguageCode()), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Try
			If ArchiveName <> Undefined Then
				DeleteFiles(ArchiveName);
			EndIf;
		Except
			// If a file cannot be deleted, backup creation must not be interrupted 		
EndTry;
		If ExportParameters.OnDemand Then
			Raise;
		Else	
			If ExportParameters.AttemptNumber > 3 Then
				SendAreaBackupErrorMessage(ExportParameters);
			Else	
				// Rescheduling: current area time + 10 minutes
				ExportParameters.AttemptNumber = ExportParameters.AttemptNumber + 1;
				RestartMoment = CurrentAreaDate(ExportParameters.DataArea); // Current area time
				RestartMoment = RestartMoment + 10 * 60; // 10 minutes later
				ExportParameters.Insert("StartTime", RestartMoment);
				ScheduleArchivingInQueue(ExportParameters);
			EndIf;
		EndIf;
	EndTry;
	
EndProcedure

Function CurrentAreaDate(Val DataArea)
	
	TimeZone = SaaSOperations.GetDataAreaTimeZone(DataArea);
	Return ToLocalTime(CurrentUniversalDate(), TimeZone);
	
EndFunction

Function ExportRequired(Val ExportParameters)
	
	If Not CommonUseCached.SessionWithoutSeparators()
		And ExportParameters.DataArea <> CommonUse.SessionSeparatorValue() Then
		
		Raise(NStr("en = 'Cannot access data that belongs to another area'"));
	EndIf;
	
	Result = ExportParameters.Forced;
	
	If Not Result Then
		
		Manager = Constants.BackUpDataArea.CreateValueManager
();
		Manager.DataAreaAuxiliaryData = ExportParameters.DataArea;
		Manager.Read();
		Result = Manager.Value;
		
	EndIf;
	
	Return Result;
	
EndFunction

// Creates a blank structure for storing backup settings.
//
// Returns:
//   Structure with the following fields:
//     - DataArea - Number.
//     - BackupID - UUID, Undefined.
//     - StartTime - Date - area backup start time.
//     - Forced - Boolean - flag from the service manager: create backup regardless of the user activity.
//     - OnDemand - Boolean - flag of the interactive backup start. If the flag value comes from the 
//                            service manager,it is always False.
//     - FileID - UUID - Export file ID in MS storage.
//     - AttemptNumber - Number - Attempts counter. Initial value: 1.
//
Function CreateEmptyExportParameters() Export
	
	ExportParameters = New Structure;
	ExportParameters.Insert("DataArea");
	ExportParameters.Insert("BackupID");
	ExportParameters.Insert("StartTime");
	ExportParameters.Insert("Forced");
	ExportParameters.Insert("OnDemand");
	ExportParameters.Insert("FileID");
	ExportParameters.Insert("AttemptNumber", 1);
	Return ExportParameters;
	
EndFunction

// Cancels previously scheduled backup creation.
//
// Parameters:
//   CancellationParameters - Structure with the following fields:
//     DataArea - Number - data area where backup is cancelled. 
//     BackupID - UUID - ID of the backup to be cancelled.
//
Procedure CancelAreaBackingUp(Val CancellationParameters) Export
	
	If Not Users.InfobaseUserWithFullAccess() Then
		Raise(NStr("en = 'Insufficient rights to perform the operation'"));
	EndIf;
	
	SetPrivilegedMode(True);
	
	MethodName = 
DataAreaBackupCached.BackgroundBackupMethodName();
	
	Filter = New Structure("MethodName, Key, DataArea", 
		MethodName, "" + CancellationParameters.BackupID, CancellationParameters.DataArea);
	Jobs = JobQueue.GetJobs(Filter);
	
	For Each Job In Jobs Do
		JobQueue.DeleteJob(Job.ID);
	EndDo;
	
EndProcedure

// Notifies about successful backup of the current area.
//
Procedure SendAreaBackupCreatedMessage(Val MessageParameters)
	
	BeginTransaction();
	
	Try
		
		Message = MessagesSaaS.NewMessage(
			MessagesBackupControlInterface.AreaBackupCreatedMessage());
		
		Body = Message.Body;
		
		Body.Zone = MessageParameters.DataArea;
		Body.BackupID = MessageParameters.BackupID;
		Body.FileID = MessageParameters.FileID;
		Body.Date = MessageParameters.CreationDate;
		If MessageParameters.Property("Daily") Then
			Body.Daily = MessageParameters.Daily;
			Body.Monthly = MessageParameters.Monthly;
			Body.Yearly = MessageParameters.Yearly;
		Else
			Body.Daily = False;
			Body.Monthly = False;
			Body.Yearly = False;
		EndIf;
		Body.ConfigurationVersion = Metadata.Version;
		
		MessagesSaaS.SendMessage(
			Message,
			SaaSOperationsCached.ServiceManagerEndpoint());
			
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

// Schedules area backup in the applied base.
//
Procedure SendAreaBackupErrorMessage(Val MessageParameters)
	
	BeginTransaction();
	Try
		
		Message = MessagesSaaS.NewMessage(
			MessagesBackupControlInterface.AreaBackupErrorMessage());
		
		Message.Body.Zone = MessageParameters.DataArea;
		Message.Body.BackupID = MessageParameters.BackupID;
		
		MessagesSaaS.SendMessage(
			Message,
			SaaSOperationsCached.ServiceManagerEndpoint());
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

// Schedules area backup in the applied base.
//
Procedure SendAreaBackupSkippedMessage(Val MessageParameters)
	
	BeginTransaction();
	Try
		
		Message = MessagesSaaS.NewMessage(
			MessagesBackupControlInterface.AreaBackupSkippedMessage());
		
		Message.Body.Zone = MessageParameters.DataArea;
		Message.Body.BackupID = MessageParameters.BackupID;
		
		MessagesSaaS.SendMessage(
			Message,
			SaaSOperationsCached.ServiceManagerEndpoint());
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

Function EventLogMessageText()
	
	Return NStr("en = 'Application backup'", 
CommonUseClientServer.DefaultLanguageCode());
	
EndFunction

Procedure WriteEventToLog(Val Event, Val Parameters)
	
	WriteLogEvent(
		EventLogMessageText() + "." + Event,
		EventLogLevel.Information,
		,
		,
		CommonUse.ValueToXMLString(Parameters));
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Operations with backup settings

// Returns the data area backup settings structure.
//
// Parameters:
//   DataArea - Number, Undefined - if Undefined, returns the system settings.
//
// Returns:
//   Structure - settings structure. 
// See DataAreaBackupCached.MapBetweenSMSettingsAndAppSettings().
//
Function GetAreaBackupSettings(Val DataArea = Undefined) 
Export
	
	If Not CommonUseCached.SessionWithoutSeparators()
		And DataArea <> CommonUse.SessionSeparatorValue() 
		And DataArea <> Undefined Then
		
		Raise(NStr("en = 'Cannot access data that belongs to another area'"));
	EndIf;
	
	SetPrivilegedMode(True);
	
	Proxy = DataAreaBackupCached.BackupControlProxy();
	
	XDTOSettings = Undefined;
	ErrorMessage = Undefined;
	If DataArea = Undefined Then
		ActionDone = Proxy.GetDefaultSettings(XDTOSettings, ErrorMessage);
	Else
		ActionDone = Proxy.GetSettings(DataArea, XDTOSettings, 
ErrorMessage);
	EndIf;
	
	If Not ActionDone Then
		MessagePattern = NStr("en = 'Error getting backup settings:
			|%1'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString
(MessagePattern, ErrorMessage);
		Raise(MessageText);
	EndIf;
	
	Return XDTOSettingsToStructure(XDTOSettings);
	
EndFunction	

// Writes data area backup settings to the service manager storage.
//
// Parameters:
//   DataArea - Number.
//   BackupSettings - Structure.
//
// Returns:
//   Boolean - flag specifying whether data was written successfully. 
//
Procedure SetAreaBackupSettings(Val DataArea, Val 
BackupSettings) Export
	
	If Not CommonUseCached.SessionWithoutSeparators()
		And DataArea <> CommonUse.SessionSeparatorValue() Then
		
		Raise(NStr("en = 'Cannot access data that belongs to another area'"));
	EndIf;
	
	SetPrivilegedMode(True);
	
	Proxy = DataAreaBackupCached.BackupControlProxy();
	
	Type = Proxy.XDTOFactory.Type("http://www.1c.ru/SaaS/1.0/XMLSchema/ZoneBackupControl", "Settings");
	XDTOSettings = Proxy.XDTOFactory.Create(Type);
	
	NameMap = DataAreaBackupCached.MapBetweenSMSettingsAndAppSettings
();
	For Each SettingsNamePair In NameMap Do
		XDTOSettings[SettingsNamePair.Key] = BackupSettings[SettingsNamePair.Value];
	EndDo;
	
	ErrorMessage = Undefined;
	If Not Proxy.SetSettings(DataArea, XDTOSettings, ErrorMessage) Then
		MessagePattern = NStr("en = 'Error saving backup settings:
                                |%1'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString
(MessagePattern, ErrorMessage);
		Raise(MessageText);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Type conversion

Function XDTOSettingsToStructure(Val XDTOSettings)
	
	If XDTOSettings = Undefined Then
		Return Undefined;
	EndIf;	
	
	Result = New Structure;
	NameMap = 
DataAreaBackupCached.MapBetweenSMSettingsAndAppSettings();
	For Each SettingsNamePair In NameMap Do
		If XDTOSettings.IsSet(SettingsNamePair.Key) Then
			Result.Insert(SettingsNamePair.Value, XDTOSettings[SettingsNamePair.Key]);
		EndIf;
	EndDo;
	Return  Result; 
	
EndFunction	
 
#EndRegion