///////////////////////////////////////////////////////////////////////////////////
// InfobaseUpdateServiceMode: current data area update.
//
///////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Data area update.

// Updates the infobase version in the current data area
// and unlocks sessions in the area if they were locked.
//
Procedure UpdateCurrentDataArea() Export
	
	SetPrivilegedMode(True);
	
	InfoBaseUpdate.ExecuteInfoBaseUpdate();
	
	LockParameters = InfoBaseConnections.GetDataAreaSessionLock();
	If Not LockParameters.Use Then
		Return;
	EndIf;
	LockParameters.Use = False;
	InfoBaseConnections.SetDataAreaSessionLock(LockParameters);
	
EndProcedure

// Selects all data areas whose versions are obsolete
// and creates background jobs to update them, if necessary. 
//
// Parameters:
// LockAreas - Boolean - flag that shows whether data area sessions must be locked
// while updating areas.
//
Procedure ScheduleDataAreaUpdate(Val LockAreas = True, Val LockMessage = "") Export
	
	SetPrivilegedMode(True);
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	If IsBlankString(LockMessage) Then
		LockMessage = Constants.LockMessageOnConfigurationUpdate.Get();
		If IsBlankString(LockMessage) Then
			LockMessage = NStr("en = 'System is locked to perform the update.'");
		EndIf;
	EndIf;
	LockParameters = InfoBaseConnections.NewLockConnectionParameters();
	LockParameters.Begin = CurrentUniversalDate();
	LockParameters.Message = LockMessage;
	LockParameters.Use = True;
	LockParameters.Exclusive = True;
	
	MetadataVersion = Metadata.Version;
	If IsBlankString(MetadataVersion) Then
		Return;
	EndIf;
	
	SharedDataVersion = InfoBaseUpdate.InfoBaseVersion(Metadata.Name, True);
	If InfoBaseUpdate.UpdateRequired(MetadataVersion, SharedDataVersion) Then
		// The common data update was not performed, there is no point to 
		// schedule the area update.
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DataAreas.DataArea AS DataArea
	|FROM
	|	InformationRegister.DataAreas AS DataAreas
	|		LEFT JOIN InformationRegister.SubsystemVersions AS SubsystemVersions
	|			ON DataAreas.DataArea = SubsystemVersions.DataArea
	|			AND (SubsystemVersions.SubsystemName = &SubsystemName)
	|WHERE
	|	DataAreas.State IN (VALUE(Enum.DataAreaStates.Used))
	|	AND (SubsystemVersions.DataArea IS NULL 
	|			OR SubsystemVersions.Version <> &Version)
	|
	|ORDER BY
	|	DataArea";
	Query.SetParameter("SubsystemName", Metadata.Name);
	Query.SetParameter("Version", MetadataVersion);
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	1
	|FROM
	|	InformationRegister.DataAreas AS DataAreas
	|		LEFT JOIN InformationRegister.SubsystemVersions AS SubsystemVersions
	|			ON DataAreas.DataArea = SubsystemVersions.DataArea
	|			AND (SubsystemVersions.SubsystemName = &SubsystemName)
	|WHERE
	|	DataAreas.DataArea = &DataArea
	|	AND DataAreas.State IN (VALUE(Enum.DataAreaStates.Used))
	|	AND (SubsystemVersions.DataArea IS NULL 
	|			OR SubsystemVersions.Version <> &Version)";
	Query.SetParameter("SubsystemName", Metadata.Name);
	Query.SetParameter("Version", MetadataVersion);
	
	Selection = Result.Choose();
	While Selection.Next() Do
		KeyValues = New Structure;
		KeyValues.Insert("DataArea", Selection.DataArea);
		KeyValues.Insert("SubsystemName", "");
		RecordKey = InformationRegisters.SubsystemVersions.CreateRecordKey(KeyValues);
		Try
			LockDataForEdit(RecordKey);
		Except
			Continue;
		EndTry;
		
		Query.SetParameter("DataArea", Selection.DataArea);
		BeginTransaction();
		Try
			Result = Query.Execute();
			CommitTransaction();
		Except
			RollbackTransaction();
			WriteLogEvent(NStr("en = 'Scheduling the data area update'"), 
				EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
			Raise;
		EndTry;
		If Result.IsEmpty() Then
			UnlockDataForEdit(RecordKey);
			Continue;
		EndIf;
		
		JobFilter = New Structure;
		JobFilter.Insert("MethodName", "InfobaseUpdateServiceMode.UpdateCurrentDataArea");
		JobFilter.Insert("Key" , "1");
		ScheduledJob = JobQueue.GetJob(JobFilter, Selection.DataArea);
		If ScheduledJob <> Undefined Then
			UnlockDataForEdit(RecordKey);
			Continue;
		EndIf;
		
		UnlockDataForEdit(RecordKey);
		
		JobQueue.ScheduleJobExecution(
			"InfobaseUpdateServiceMode.UpdateCurrentDataArea",, "1", True, Selection.DataArea);
		
		If LockAreas Then
			CommonUse.SetSessionSeparation(True, Selection.DataArea);
			InfoBaseConnections.SetDataAreaSessionLock(LockParameters, False);
			CommonUse.SetSessionSeparation(False);
		EndIf;
		
	EndDo;
	
EndProcedure

// The UpdateDataAreas schedule job handler.
// Selects all data areas whose versions are obsolete
// and creates UpdateInfoBase background jobs for them, if necessary.
//
Procedure UpdateDataAreas() Export
	
	If IsBlankString(UserName()) Then
		SetPrivilegedMode(True);
	EndIf;
	
	ScheduleDataAreaUpdate(True);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Infobase update handlers.

// Replaces DeleteReady data area stares with Used states in the DataAreas register.
// 
Procedure ReplaceReadyAreaStates() Export
	
	BeginTransaction();
	Try
		Lock = New DataLock;
		Lock.Add("InformationRegister.DataAreas");
		Lock.Lock();
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	DataAreas.DataArea AS DataArea
		|FROM
		|	InformationRegister.DataAreas AS DataAreas
		|WHERE
		|	DataAreas.State = VALUE(Enum.DataAreaStates.DeleteReady)";
		Selection = Query.Execute().Choose();
		While Selection.Next() Do
			RecordManager = InformationRegisters.DataAreas.CreateRecordManager();
			RecordManager.DataArea = Selection.DataArea;
			RecordManager.Read();
			RecordManager.State = Enums.DataAreaStates.Used;
			RecordManager.Write();
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Adds update handlers required by this subsystem to the Handlers list.
//
// Parameters:
// Handlers - ValueTable - see the InfoBaseUpdate.NewUpdateHandlerTable
// for details.
// 
Procedure RegisterUpdateHandlers(Handlers) Export
	
	If CommonUseCached.DataSeparationEnabled() Then
		Handler = Handlers.Add();
		Handler.Version = "*";
		Handler.Procedure = "InfobaseUpdateServiceMode.ScheduleDataAreaUpdate";
		Handler.SharedData = True;
		
		Handler = Handlers.Add();
		Handler.Version = "2.0.1.6";
		Handler.Procedure = "InfobaseUpdateServiceMode.ReplaceReadyAreaStates";
		Handler.SharedData = True;
	EndIf;
	
EndProcedure
