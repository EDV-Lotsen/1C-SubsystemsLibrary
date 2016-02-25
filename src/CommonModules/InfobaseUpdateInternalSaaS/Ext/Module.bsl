///////////////////////////////////////////////////////////////////////////////////
// Infobase version update SaaS subsystem.
//
///////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

// Creates the data areas update plan and stores it to the infobase.
//
// Parameters:
//  LibraryID                 - String - configuration  name or library ID.
//  AllHandlers               - Map - list of all update handlers. 
//  RequiredSeparatedHandlers - Map - list of mandatory update handlers
//                              with SharedData = False.
//  SourceInfobaseVersion     - String - original infobase version.
//  InfobaseMetadataVersion   - String - configuration version (from metadata).
//
Procedure GenerateDataAreaUpdatePlan(LibraryID, AllHandlers, 
	RequiredSeparatedHandlers, SourceInfobaseVersion, InfobaseMetadataVersion) Export
	
	If CommonUseCached.DataSeparationEnabled()
		And Not CommonUseCached.CanUseSeparatedData() Then
		
		UpdateHandlers = AllHandlers.CopyColumns();
		For Each HandlerRow In AllHandlers Do
			// When generating area update plan, mandatory (*) handlers are not added by default
			If HandlerRow.Version = "*" Then
				Continue;
			EndIf;
			FillPropertyValues(UpdateHandlers.Add(), HandlerRow);
		EndDo;
		
		For Each RequiredHandler In RequiredSeparatedHandlers Do
			HandlerRow = UpdateHandlers.Add();
			FillPropertyValues(HandlerRow, RequiredHandler);
			HandlerRow.Version = "*";
		EndDo;
		
		DataAreaUpdatePlan = InfobaseUpdateInternal.UpdateInIntervalHandlers(
			UpdateHandlers, SourceInfobaseVersion, InfobaseMetadataVersion, True);
			
		PlanDetails = New Structure;
		PlanDetails.Insert("VersionFrom", SourceInfobaseVersion);
		PlanDetails.Insert("VersionTo", InfobaseMetadataVersion);
		PlanDetails.Insert("Plan", DataAreaUpdatePlan);
		
		RecordManager = InformationRegisters.SubsystemVersions.CreateRecordManager();
		RecordManager.SubsystemName = LibraryID;
		
		DataLock = New DataLock;
		LockItem = DataLock.Add("InformationRegister.SubsystemVersions");
		LockItem.SetValue("SubsystemName", LibraryID);
		
		BeginTransaction();
		Try
			DataLock.Lock();
			
			RecordManager.Read();
			RecordManager.UpdatePlan = New ValueStorage(PlanDetails);
			RecordManager.Write();
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
		UpdatePlanEmpty = DataAreaUpdatePlan.Rows.Count() = 0;
		
		If LibraryID = Metadata.Name Then
			// Configuration version can be set only if no library updates are required, otherwise the update will not run in the areas and the libraries will not be updated
			UpdatePlanEmpty = False;
			
			// Checking whether each plan is empty
			Libraries = New ValueTable;
			Libraries.Columns.Add("Name", Metadata.InformationRegisters.SubsystemVersions.Dimensions.SubsystemName.Type);
			Libraries.Columns.Add("Version", Metadata.InformationRegisters.SubsystemVersions.Resources.Version.Type);
			
			SubsystemDescriptions  = StandardSubsystemsCached.SubsystemDescriptions();
			For Each SubsystemName In SubsystemDescriptions.Order Do
				SubsystemDetails = SubsystemDescriptions.ByNames.Get(SubsystemName);
				If Not ValueIsFilled(SubsystemDetails.MainServerModule) Then
					// The library has no module, therefore no update handlers
					Continue;
				EndIf;
				
				LibraryRow = Libraries.Add();
				LibraryRow.Name = SubsystemDetails.Name;
				LibraryRow.Version = SubsystemDetails.Version;
			EndDo;
			
			Query = New Query;
			Query.SetParameter("Libraries", Libraries);
			Query.Text =
				"SELECT
				|	Libraries.Name AS Name,
				|	Libraries.Version AS Version
				|INTO Libraries
				|FROM
				|	&Libraries AS Libraries
				|;
				|
				|////////////////////////////////////////////////////////////////////////////////
				|SELECT
				|	Libraries.Name AS Name,
				|	Libraries.Version AS Version,
				|	SubsystemVersions.UpdatePlan AS UpdatePlan,
				|	CASE
				|		WHEN SubsystemVersions.Version = Libraries.Version
				|			THEN TRUE
				|		ELSE FALSE
				|	END AS Updated
				|FROM
				|	Libraries AS Libraries
				|		LEFT JOIN InformationRegister.SubsystemVersions AS SubsystemVersions
				|		ON Libraries.Name = SubsystemVersions.SubsystemName";
				
			BeginTransaction();
			Try
				DataLock = New DataLock;
				LockItem = DataLock.Add("InformationRegister.SubsystemVersions");
				LockItem.Mode = DataLockMode.Shared;
				DataLock.Lock();
				
				Result = Query.Execute();
				
				CommitTransaction();
			Except
				RollbackTransaction();
				Raise;
			EndTry;
			
			Selection = Result.Select();
			While Selection.Next() Do
				
				If Not Selection.Updated Then
					UpdatePlanEmpty = False;
					
					CommentPattern = NStr("en = 'Configuration version update was performed before updating %1 library version");
					CommentText = StringFunctionsClientServer.SubstituteParametersInString(CommentPattern, Selection.Name);
					WriteLogEvent(
						InfobaseUpdate.EventLogMessageText(),
						EventLogLevel.Error,
						,
						,
						CommentText);
					
					Break;
				EndIf;
				
				If Selection.UpdatePlan = Undefined Then
					LibraryUpdatePlanDetails = Undefined;
				Else
					LibraryUpdatePlanDetails = Selection.UpdatePlan.Get();
				EndIf;
				
				If LibraryUpdatePlanDetails = Undefined Then
					UpdatePlanEmpty = False;
					
					CommentPattern = NStr("en = '%1 library update plan not found");
					CommentText = StringFunctionsClientServer.SubstituteParametersInString(CommentPattern, Selection.Name);
					WriteLogEvent(
						InfobaseUpdate.EventLogMessageText(),
						EventLogLevel.Error,
						,
						,
						CommentText);
					
					Break;
				EndIf;
				
				If LibraryUpdatePlanDetails.VersionTo <> Selection.Version Then
					UpdatePlanEmpty = False;
					
					CommentPattern = NStr("en = 'Invalid %1 library update plan.
          |Plan for update to version %2 required, plan for update to version %3 found'");
					CommentText = StringFunctionsClientServer.SubstituteParametersInString(CommentPattern, Selection.Name);
					WriteLogEvent(
						InfobaseUpdate.EventLogMessageText(),
						EventLogLevel.Error,
						,
						,
						CommentText);
					
					Break;
				EndIf;
				
				If LibraryUpdatePlanDetails.Plan.Rows.Count() > 0 Then
					UpdatePlanEmpty = False;
					Break;
				EndIf;
				
			EndDo;
		EndIf;
		
		If UpdatePlanEmpty Then
			SetAllDataAreasVersion(LibraryID, SourceInfobaseVersion, InfobaseMetadataVersion);
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of the conditional subsystem calls

// Sets the job usage flag that corresponds to the deferred update scheduled job in the job queue.
//
// Parameters:
//  Use - Boolean - new value of the usage flag.
//
Procedure OnEnableDeferredUpdate(Val Use) Export
	
	Template = JobQueue.TemplateByName("DeferredInfobaseUpdate");
	
	JobFilter = New Structure;
	JobFilter.Insert("Template", Template);
	Jobs = JobQueue.GetJobs(JobFilter);
	
	JobParameters = New Structure("Use", Use);
	JobQueue.ChangeJob(Jobs[0].ID, JobParameters);
	
EndProcedure

// Checks if the shared infobase update part is executed.
//
Procedure InfobaseBeforeUpdate() Export
	
	If CommonUseCached.DataSeparationEnabled()
	   And CommonUseCached.CanUseSeparatedData() Then
		
		SharedDataVersion = InfobaseUpdateInternal.InfobaseVersion(Metadata.Name, True);
		If InfobaseUpdateInternal.UpdateRequired(Metadata.Version, SharedDataVersion) Then
			Message = NStr("en = 'Shared infobase update part is not performed.
				|Contact the application administrator.'");
			WriteLogEvent(InfobaseUpdate.EventLogMessageText(), EventLogLevel.Error,,, Message);
			Raise Message;
		EndIf;
	EndIf;
	
EndProcedure	

#EndRegion

#Region InternalProceduresAndFunctions

// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations.JobQueue") Then
		ServerHandlers[
			"StandardSubsystems.SaaSOperations.JobQueue\OnDefineHandlerAliases"].Add(
				"InfobaseUpdateInternalSaaS");
	
		ServerHandlers[
			"StandardSubsystems.SaaSOperations.JobQueue\OnDetermineScheduledJobsUsed"].Add(
				"InfobaseUpdateInternalSaaS");
	EndIf;
	
	ServerHandlers[
		"StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
			"InfobaseUpdateInternalSaaS");
	
	ServerHandlers[
		"StandardSubsystems.InfobaseVersionUpdate\AfterInfobaseUpdate"].Add(
			"InfobaseUpdateInternalSaaS");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnGetMandatoryExchangePlanObjects"].Add(
		"InfobaseUpdateInternalSaaS");
	
	If CommonUse.SubsystemExists("CloudTechnology.DataImportExport") Then
		ServerHandlers["CloudTechnology.DataImportExport\OnFillExcludedFromImportExportTypes"].Add(
			"InfobaseUpdateInternalSaaS");
	EndIf;
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\ExchangePlanObjectsToExcludeOnGet"].Add(
		"InfobaseUpdateInternalSaaS");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SL event handlers

// Fills a map of method names and their aliases for calling from a job queue.
//
// Parameters:
//  NameAndAliasMap - Map.
//   Key - method alias, example: ClearDataArea.
// Value - method name, example: SaaSOperations.ClearDataArea. 
// You can pass Undefined if the name is identical to the alias.
//
Procedure OnDefineHandlerAliases(NameAndAliasMap) Export
	
	NameAndAliasMap.Insert("InfobaseUpdateInternalSaaS.UpdateCurrentDataArea");
	
EndProcedure

// Generates a scheduled job table with flags that show whether a job is used in SaaS mode.
//
// Parameters:
// UsageTable - ValueTable - table to be filled with scheduled jobs with usage flags. It contains the following columns::
//  ScheduledJob - String - predefined scheduled job name. 
//  Use - Boolean - True if the scheduled job must be executed in SaaS mode. Otherwise False.
//
Procedure OnDetermineScheduledJobsUsed(UsageTable) Export
	
	NewRow = UsageTable.Add();
	NewRow.ScheduledJob = "DataAreaUpdate";
	NewRow.Use          = True;
	
EndProcedure

// The procedure is called after the completion of exclusive infobase update.
// 
// Parameters:
//   PreviousVersion - String - subsystem version before update. "0.0.0.0" for an empty infobase.
//   CurrentVersion - String - subsystem version after update.
//   ExecutedHandlers - ValueTree - the list of executed subsystem update handler procedures 
// grouped by version number.
//                            Procedure for iteration through executed handlers:
//
// For Each Version In ExecutedHandlers.Rows Do
//		
// 	If
// 		 Version.Version = "*" Then
//      Handler that is executed with each version change.
// 	Else
// 		  Handler that is executed for a certain version.
// 	EndIf;
//		
// 	For Each Handler In Version.Rows Do 
//     ...
// 	EndDo;
//		
// EndDo;
//
//   ShowUpdateDetails - Boolean (return value) - if True, the update description form is displayed.
//   ExclusiveMode     - Boolean - flag specifying whether the update was performed in exclusive mode.
//
Procedure AfterInfobaseUpdate(Val PreviousVersion, Val CurrentVersion,
		Val ExecutedHandlers, ShowUpdateDetails, ExclusiveMode) Export
	
	If CommonUseCached.CanUseSeparatedData() Then
		
		LockParameters = InfobaseConnections.GetDataAreaSessionLock();
		If Not LockParameters.Use Then
			Return;
		EndIf;
		LockParameters.Use = False;
		InfobaseConnections.SetDataAreaSessionLock(LockParameters);
		
	Else
		
		DisableExclusiveMode = False;
		If Not ExclusiveMode() Then
			
			Try
				SetExclusiveMode(True);
				DisableExclusiveMode = True;
			Except
				// No exception processing required.
				// Expected exception: error setting exclusive mode because other
				// sessions are running (for example, during dynamic configuration update).
				// In this case area update planning is performed considering the possible 
				// competition when accessing metadata object tables 
				// separated in the "Independent and shared" mode (which is
				// less efficient than the execution in the exclusive mode).
			EndTry;
			
		EndIf;
		
		ScheduleDataAreaUpdate(True);
		
		If DisableExclusiveMode Then
			SetExclusiveMode(False);
		EndIf;
		
	EndIf;
	
EndProcedure

// Adds update handlers that are required by the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see the description of NewUpdateHandlerTable function in the InfobaseUpdate common module.
//
Procedure OnAddUpdateHandlers(Handlers) Export
	
EndProcedure

// Fills the array of types excluded from data import and export.
//
// Parameters:
//  Types - Array(Types).
//
Procedure OnFillExcludedFromImportExportTypes(Types) Export
	
	Types.Add(Metadata.InformationRegisters.DataAreaSubsystemVersions);
	
EndProcedure

// The procedure is used when getting metadata objects that are mandatory for the exchange plan.
// If the subsystem includes metadata objects that must be included in the exchange plan 
// content, add these metadata objects to the Objects parameter.
//
// Parameters:
// Objects - Array. The array of configuration metadata objects that must be included in the exchange plan content.
// DistributedInfobase (read only) - Boolean. Flag that shows whether objects for a DIB exchange plan are retrieved.
// True - list of DIB exchange plan objects is retrieved.
// False - list of non-DIB exchange plan objects is retrieved.
//
Procedure OnGetMandatoryExchangePlanObjects(Objects, Val DistributedInfobase) Export
	
EndProcedure

// The procedure is used when getting metadata objects that must not be included in the exchange plan content.
// If the subsystem contains metadata objects that must not be included in the exchange plan content, add these metadata objects to the Objects parameter.
//
// Parameters:
// Objects - Array. The array of configuration metadata objects that should not be included in the exchange plan content.
// DistributedInfobase (read only) - Boolean. Flag that shows whether objects for a DIB exchange plan are retrieved.
// True - list of DIB exchange plan objects is retrieved.
// False - list of non-DIB exchange plan objects is retrieved.
//
Procedure ExchangePlanObjectsToExcludeOnGet(Objects, Val DistributedInfobase) Export
	
	If DistributedInfobase Then
		
		Objects.Add(Metadata.InformationRegisters.DataAreaSubsystemVersions);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INFOBASE UPDATE HANDLERS

// No handlers available
	
////////////////////////////////////////////////////////////////////////////////
// Data areas update.

// Performs infobase version update in the current data area and removes 
// session locks in the area if they were previously set.
//
Procedure UpdateCurrentDataArea() Export
	
	SetPrivilegedMode(True);
	
	InfobaseUpdateInternal.ExecuteInfobaseUpdate();
	
EndProcedure

// Selects all data areas with outdated versions and
// generates background jobs for updating when necessary.
//
// Parameters:
// LockAreas - Boolean - set data area session lock during the area update
//
Procedure ScheduleDataAreaUpdate(Val LockAreas = True, Val LockMessage = "") Export
	
	SetPrivilegedMode(True);
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	If IsBlankString(LockMessage) Then
		LockMessage = Constants.LockMessageOnConfigurationUpdate.Get();
		If IsBlankString(LockMessage) Then
			LockMessage = NStr("en = 'System is locked for update.'");
		EndIf;
	EndIf;
	LockParameters = InfobaseConnections.NewConnectionLockParameters();
	LockParameters.Beginning = CurrentUniversalDate();
	LockParameters.Message = LockMessage;
	LockParameters.Use = True;
	LockParameters.Exclusive = True;
	
	MetadataVersion = Metadata.Version;
	If IsBlankString(MetadataVersion) Then
		Return;
	EndIf;
	
	SharedDataVersion = InfobaseUpdateInternal.InfobaseVersion(Metadata.Name, True);
	If InfobaseUpdateInternal.UpdateRequired(MetadataVersion, SharedDataVersion) Then
		// Common data update is not performed yet, planning area update makes no sense
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DataAreas.DataAreaAuxiliaryData AS DataArea
	|FROM
	|	InformationRegister.DataAreas AS DataAreas
	|		LEFT JOIN InformationRegister.DataAreaSubsystemVersions AS DataAreaSubsystemVersions
	|		ON DataAreas.DataAreaAuxiliaryData = DataAreaSubsystemVersions.DataAreaAuxiliaryData
	|			AND (DataAreaSubsystemVersions.SubsystemName = &SubsystemName)
	|		LEFT JOIN InformationRegister.DataAreaActivityRating AS DataAreaActivityRating
	|		ON DataAreas.DataAreaAuxiliaryData = DataAreaActivityRating.DataArea
	|WHERE
	|	DataAreas.Status IN (VALUE(Enum.DataAreaStatuses.Used))
	|	AND (DataAreaSubsystemVersions.DataAreaAuxiliaryData IS NULL 
	|			OR DataAreaSubsystemVersions.Version <> &Version)
	|
	|ORDER BY
	|	ISNULL(DataAreaActivityRating.Rating, 9999999),
	|	DataArea";
	Query.SetParameter("SubsystemName", Metadata.Name);
	Query.SetParameter("Version", MetadataVersion);
	Result = CommonUse.ExecuteQueryOutsideTransaction(Query);
	If Result.IsEmpty() Then // Preliminary reading, perhaps with dirty read parts
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	DataAreas.Status AS Status
	|FROM
	|	InformationRegister.DataAreas AS DataAreas
	|WHERE
	|	DataAreas.DataAreaAuxiliaryData = &DataArea
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	DataAreaSubsystemVersions.Version AS Version
	|FROM
	|	InformationRegister.DataAreaSubsystemVersions AS DataAreaSubsystemVersions
	|WHERE
	|	DataAreaSubsystemVersions.DataAreaAuxiliaryData = &DataArea
	|	AND DataAreaSubsystemVersions.SubsystemName = &SubsystemName";
	Query.SetParameter("SubsystemName", Metadata.Name);
	
	Selection = Result.Select();
	While Selection.Next() Do
		KeyValues = New Structure;
		KeyValues.Insert("DataAreaAuxiliaryData", Selection.DataArea);
		KeyValues.Insert("SubsystemName", "");
		RecordKey = SaaSOperations.CreateAuxiliaryDataInformationRegisterRecordKey(
			InformationRegisters.DataAreaSubsystemVersions, KeyValues);
		
		LockingError = False;
		
		BeginTransaction();
		Try
			Try
				LockDataForEdit(RecordKey); // The lock will be removed after the transaction is completed
			Except
				LockingError = True;
				Raise;
			EndTry;
			
			Query.SetParameter("DataArea", Selection.DataArea);
		
			DataLock = New DataLock;
			
			LockItem = DataLock.Add("InformationRegister.DataAreaSubsystemVersions");
			LockItem.SetValue("DataAreaAuxiliaryData", Selection.DataArea);
			LockItem.SetValue("SubsystemName", Metadata.Name);
			LockItem.Mode = DataLockMode.Shared;
			
			LockItem = DataLock.Add("InformationRegister.DataAreas");
			LockItem.SetValue("DataAreaAuxiliaryData", Selection.DataArea);
			LockItem.Mode = DataLockMode.Shared;
			
			DataLock.Lock();
			
			Results = Query.ExecuteBatch();
			
			AreaRow = Undefined;
			If Not Results[0].IsEmpty() Then
				AreaRow = Results[0].Unload()[0];
			EndIf;
			VersionString = Undefined;
			If Not Results[1].IsEmpty() Then
				VersionString = Results[1].Unload()[0];
			EndIf;
			
			If AreaRow = Undefined
				Or AreaRow.Status <> Enums.DataAreaStatuses.Used
				Or (VersionString <> Undefined And VersionString.Version = MetadataVersion) Then
				
				// Records do not match the original selection
				CommitTransaction();
				Continue;
			EndIf;
			
			JobFilter = New Structure;
			JobFilter.Insert("MethodName", "InfobaseUpdateInternalSaaS.UpdateCurrentDataArea");
			JobFilter.Insert("Key", "1");
			JobFilter.Insert("DataArea", Selection.DataArea);
			Jobs = JobQueue.GetJobs(JobFilter);
			If Jobs.Count() > 0 Then
				// The area update job already exists
				CommitTransaction();
				Continue;
			EndIf;
			
			JobParameters = New Structure;
			JobParameters.Insert("MethodName"    , "InfobaseUpdateInternalSaaS.UpdateCurrentDataArea");
			JobParameters.Insert("Parameters"    , New Array);
			JobParameters.Insert("Key"         , "1");
			JobParameters.Insert("DataArea", Selection.DataArea);
			JobParameters.Insert("ExclusiveExecution", True);
			JobParameters.Insert("RestartCountOnFailure", 3);
			
			JobQueue.AddJob(JobParameters);
			
			If LockAreas Then
				InfobaseConnections.SetDataAreaSessionLock(LockParameters, False, Selection.DataArea);
			EndIf;
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			If LockingError Then
				Continue;
			Else
				Raise;
			EndIf;
			
		EndTry;
		
	EndDo;
	
EndProcedure

// DataAreaUpdate scheduled job handler selects all data areas with outdated versions and generates background InfobaseUpdate jobs for them when necessary.
//
Procedure DataAreaUpdate() Export
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	// OnScheduledJobStart is not called because the necessary actions are executed privately.
	
	ScheduleDataAreaUpdate(True);
	
EndProcedure

// Returns the record key for DataAreaSubsystemVersions information register.
//
// Returns: 
//   InformationRegisterRecordKey
//
Function SubsystemVersionsRecordKey() Export
	
	KeyValues = New Structure;
	If CommonUseCached.CanUseSeparatedData() Then
		KeyValues.Insert("DataAreaAuxiliaryData", CommonUse.SessionSeparatorValue());
		KeyValues.Insert("SubsystemName", "");
		RecordKey = SaaSOperations.CreateAuxiliaryDataInformationRegisterRecordKey(
			InformationRegisters.DataAreaSubsystemVersions, KeyValues);
	EndIf;
	
	Return RecordKey;
	
EndFunction

// Blocks the record in the DataAreaSubsystemVersions information register that corresponds to the current data area, and returns the record key.
//
// Returns: 
//   InformationRegisterRecordKey
//
Function LockDataAreaVersions() Export
	
	RecordKey = Undefined;
	If CommonUseCached.DataSeparationEnabled() Then
		
		If CommonUseCached.CanUseSeparatedData() Then
			SetPrivilegedMode(True);
		EndIf;
		
		RecordKey = SubsystemVersionsRecordKey();
		
	EndIf;
	
	If RecordKey <> Undefined Then
		Try
			LockDataForEdit(RecordKey);
		Except
			WriteLogEvent(InfobaseUpdate.EventLogMessageText() + "." 
				+ NStr("en = 'Data area update'", Metadata.DefaultLanguage.LanguageCode),
				EventLogLevel.Error,,,
				DetailErrorDescription(ErrorInfo()));
			Raise(NStr("en = 'Data area update error. Data area versions record is locked.'"));
		EndTry;
	EndIf;
	Return RecordKey;
	
EndFunction

// Unlocks the record in the DataAreaSubsystemVersions information register.
//
// Parameters: 
//   RecordKey - InformationRegisterRecordKey
//
Procedure UnlockDataAreaVersions(RecordKey) Export
	
	If RecordKey <> Undefined Then
		UnlockDataForEdit(RecordKey);
	EndIf;
	
EndProcedure

// For internal use only
Procedure OnDetermineInfobaseVersion(Val LibraryID, Val GetCommonDataVersion, StandardProcessing, InfobaseVersion) Export
	
	If CommonUse.UseSessionSeparator() And Not GetCommonDataVersion Then
		
		StandardProcessing = False;
		
		QueryText = 
		"SELECT
		|	DataAreaSubsystemVersions.Version
		|FROM
		|	InformationRegister.DataAreaSubsystemVersions AS DataAreaSubsystemVersions
		|WHERE
		|	DataAreaSubsystemVersions.SubsystemName = &SubsystemName
		|	AND DataAreaSubsystemVersions.DataAreaAuxiliaryData = &DataAreaAuxiliaryData";
		Query = New Query(QueryText);
		Query.SetParameter("SubsystemName", LibraryID);
		Query.SetParameter("DataAreaAuxiliaryData", CommonUse.SessionSeparatorValue());
		ValueTable = Query.Execute().Unload();
		InfobaseVersion = "";
		If ValueTable.Count() > 0 Then
			InfobaseVersion = TrimAll(ValueTable[0].Version);
		EndIf;
		
	EndIf;
	
EndProcedure

// For internal use only
Procedure OnDetermineDataAreaFirstLogon(StandardProcessing, Result) Export
	
	If CommonUse.UseSessionSeparator() Then
		
		StandardProcessing = False;
		
		QueryText = 
		"SELECT TOP 1
		|	1
		|FROM
		|	InformationRegister.DataAreaSubsystemVersions AS DataAreaSubsystemVersions
		|WHERE
		|	DataAreaSubsystemVersions.DataAreaAuxiliaryData = &DataAreaAuxiliaryData";
		Query = New Query(QueryText);
		Query.SetParameter("DataAreaAuxiliaryData", CommonUse.SessionSeparatorValue());
		Result = Query.Execute().IsEmpty();
		
	EndIf;
	
EndProcedure

// For internal use only
Procedure OnSetInfobaseVersion(Val LibraryID, Val VersionNumber, StandardProcessing) Export
	
	If CommonUse.UseSessionSeparator() Then
		
		StandardProcessing = False;
		
		DataArea = CommonUse.SessionSeparatorValue();
		
		RecordManager = InformationRegisters.DataAreaSubsystemVersions.CreateRecordManager();
		RecordManager.DataAreaAuxiliaryData = DataArea;
		RecordManager.SubsystemName = LibraryID;
		RecordManager.Version = VersionNumber;
		RecordManager.Write();
		
	EndIf;
	
EndProcedure

// For internal use only
Function EarliestDataAreaVersion() Export
	
	SetPrivilegedMode(True);
	
	If CommonUseCached.DataSeparationEnabled() And CommonUseCached.CanUseSeparatedData() Then
		Raise NStr("en = 'Calling the InfobaseUpdateInternalCached.EarliestInfobaseVersion() function is not available from the sessions with SaaS mode separators set.'");
	EndIf;
	
	Query = New Query;
	Query.SetParameter("SubsystemName", Metadata.Name);
	Query.Text =
	"SELECT DISTINCT
	|	DataAreaSubsystemVersions.Version AS Version
	|FROM
	|	InformationRegister.DataAreaSubsystemVersions AS DataAreaSubsystemVersions
	|WHERE
	|	DataAreaSubsystemVersions.SubsystemName = &SubsystemName";
	
	Selection = Query.Execute().Select();
	
	EarliestInfobaseVersion = Undefined;
	
	While Selection.Next() Do
		If CommonUseClientServer.CompareVersions(Selection.Version, EarliestInfobaseVersion) > 0 Then
			EarliestInfobaseVersion = Selection.Version;
		EndIf
	EndDo;
	
	Return EarliestInfobaseVersion;
	
EndFunction

// For internal use only
Procedure SetAllDataAreasVersion(LibraryID, SourceInfobaseVersion, InfobaseMetadataVersion)
	
	DataLock = New DataLock;
	DataLock.Add("InformationRegister.DataAreaSubsystemVersions");
	DataLock.Add("InformationRegister.DataAreas");
	
	BeginTransaction();
	Try
		DataLock.Lock();
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	DataAreas.DataAreaAuxiliaryData AS DataArea
		|FROM
		|	InformationRegister.DataAreas AS DataAreas
		|		INNER JOIN InformationRegister.DataAreaSubsystemVersions AS DataAreaSubsystemVersions
		|		ON DataAreas.DataAreaAuxiliaryData = DataAreaSubsystemVersions.DataAreaAuxiliaryData
		|WHERE
		|	DataAreas.Status = VALUE(Enum.DataAreaStatuses.Used)
		|	AND DataAreaSubsystemVersions.SubsystemName = &SubsystemName
		|	AND DataAreaSubsystemVersions.Version = &Version";
		Query.SetParameter("SubsystemName", LibraryID);
		Query.SetParameter("Version", SourceInfobaseVersion);
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			RecordManager = InformationRegisters.DataAreaSubsystemVersions.CreateRecordManager();
			RecordManager.DataAreaAuxiliaryData = Selection.DataArea;
			RecordManager.SubsystemName = LibraryID;
			RecordManager.Version = InfobaseMetadataVersion;
			RecordManager.Write();
		EndDo;
		
		CommitTransaction();
	Except
		Raise;
		RollbackTransaction();
	EndTry;
	
EndProcedure

#EndRegion
