////////////////////////////////////////////////////////////////////////////////
// A COMMON IMPLEMENTATION OF BACKUP MANAGEMENT MESSAGE PROCESSING
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Processes incoming messages of {http://www.1c.ru/SaaS/ManageZonesBackup/a.b.c.d}PlanZoneBackup type.
//
// Parameters:
//  DataAreaCode - number(7,0).
//  BackupID - UUID.
//  BackupEventTime - date (date and time).
//  Forced - Boolean - forced backup creation flag.
//
Procedure ScheduleAreaBackingUp(Val DataAreaCode,
		Val BackupID, Val BackupEventTime,
		Val Forced) Export
	
	ExportParameters = DataAreaBackup.CreateEmptyExportParameters();
	ExportParameters.DataArea = DataAreaCode;
	ExportParameters.CopyID = BackupID;
	ExportParameters.StartTime = ToLocalTime(BackupEventTime, // Converting universal time to local time
		SaaSOperations.GetDataAreaTimeZone(DataAreaCode)); // because the job queue requires the local time.
	ExportParameters.Forced = Forced;
	ExportParameters.OnDemand = False;
	
	DataAreaBackup.ScheduleArchivingInQueue(ExportParameters);
	
EndProcedure

// Processes incoming messages of {http://www.1c.ru/SaaS/ManageZonesBackup/a.b.c.d}CancelZoneBackup type.
//
// Parameters:
//  DataAreaCode - number(7,0).
//  BackupID - UUID.
//
Procedure CancelAreaBackingUp(Val DataAreaCode, Val 
BackupID) Export
	
	CancellationParameters = New Structure("DataArea, CopyID", DataAreaCode, BackupID);
	DataAreaBackup.CancelAreaBackingUp
(CancellationParameters);
	
EndProcedure

// Processes incoming messages of {http://www.1c.ru/SaaS/ManageZonesBackup/a.b.c.d}UpdateScheduledBackupZoneSettings type.
//
// Parameters:
//  DataArea - Number - data area separator value.
//  Settings - Structure - new backup settings.
Procedure UpdatePeriodicBackupSettings(Val DataArea, Val Settings) Export
	
	CreationParameters = New Structure;
	CreationParameters.Insert("CreateDailyBackups");
	CreationParameters.Insert("CreateMonthlyBackups");
	CreationParameters.Insert("CreateYearlyBackups");
	CreationParameters.Insert("OnlyWhenUsersActive");
	CreationParameters.Insert("MonthlyBackupCreationDate");
	CreationParameters.Insert("YearlyBackupCreationMonth");
	CreationParameters.Insert("YearlyBackupCreationDate");
	FillPropertyValues(CreationParameters, Settings);
	
	CreationStatus = New Structure;
	CreationStatus.Insert("LastDailyBackupCreationDate");
	CreationStatus.Insert("LastMonthlyBackupCreationDate");
	CreationStatus.Insert("LastYearlyBackupCreationDate");
	FillPropertyValues(CreationStatus, Settings);
	
	MethodParameters = New Array;
	MethodParameters.Add(New FixedStructure(CreationParameters));
	MethodParameters.Add(New FixedStructure(CreationStatus));
	
	Schedule = New JobSchedule;
	Schedule.BeginTime = Settings.BackupCreationIntervalStart;
	Schedule.EndTime = Settings.BackupCreationIntervalEnd;
	Schedule.DaysRepeatPeriod = 1;
	
	JobParameters = New Structure;
	JobParameters.Insert("Parameters", MethodParameters);
	JobParameters.Insert("Schedule", Schedule);
	
	JobFilter = New Structure;
	JobFilter.Insert("DataArea", DataArea);
	JobFilter.Insert("MethodName", "DataAreaBackup.Copying");
	JobFilter.Insert("Key", "1");
	
	BeginTransaction();
	Try
		Jobs = JobQueue.GetJobs(JobFilter);
		If Jobs.Count() > 0 Then
			JobQueue.ChangeJob(Jobs[0].ID, JobParameters);
		Else
			JobParameters.Insert("DataArea", DataArea);
			JobParameters.Insert("MethodName", "DataAreaBackup.Copying");
			JobParameters.Insert("Key", "1");
			JobParameters.Insert("RestartCountOnFailure", 3);
			JobParameters.Insert("RestartIntervalOnFailure", 600); // 10 minutes
			JobQueue.AddJob(JobParameters);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Processes incoming messages of {http://www.1c.ru/SaaS/ManageZonesBackup/a.b.c.d}CancelScheduledZoneBackup type.
//
// Parameters:
//  DataArea - Number - data area separator value.
Procedure CancelPeriodicBackup(Val DataArea) Export
	
	JobFilter = New Structure;
	JobFilter.Insert("DataArea", DataArea);
	JobFilter.Insert("MethodName", "DataAreaBackup.Copying");
	JobFilter.Insert("Key", "1");
	
	BeginTransaction();
	Try
		Jobs = JobQueue.GetJobs(JobFilter);
		If Jobs.Count() > 0 Then
			JobQueue.DeleteJob(Jobs[0].ID);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion
