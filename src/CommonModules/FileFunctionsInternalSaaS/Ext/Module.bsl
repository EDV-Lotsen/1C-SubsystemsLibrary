////////////////////////////////////////////////////////////////////////////////
// File functions SaaS subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS
	
	ServerHandlers[
		"StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
			"FileFunctionsInternalSaaS");
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations.JobQueue") Then
		ServerHandlers[
			"StandardSubsystems.SaaSOperations.JobQueue\OnDefineHandlerAliases"].Add(
				"FileFunctionsInternalSaaS");
	
		ServerHandlers[
			"StandardSubsystems.SaaSOperations.JobQueue\OnDetermineScheduledJobsUsed"].Add(
				"FileFunctionsInternalSaaS");
	EndIf;
	
	If CommonUse.SubsystemExists("CloudTechnology.DataImportExport") Then
		ServerHandlers[
			"CloudTechnology.DataImportExport\OnFillExcludedFromImportExportTypes"].Add(
				"FileFunctionsInternalSaaS");
	EndIf;
	
EndProcedure

// OnDefineHandlerAliases event handler.
//
// Fills a map of method names and their aliases for calling from a job queue.
//
// Parameters:
//  NameAndAliasMap - Map.
//  Key             - Method alias, example: ClearDataArea.
//  Value           - Method name, example: SaaSOperations.ClearDataArea. 
//                    You can pass Undefined if the name is identical to the alias.
//
Procedure OnDefineHandlerAliases(NameAndAliasMap) Export
	
	NameAndAliasMap.Insert("FileFunctionsInternal.ExtractTextFromFilesAtServer");
	
EndProcedure

// Generates a scheduled job table with flags that show whether a job is used in SaaS mode.
//
// Parameters:
//  UsageTable   - ValueTable - table to be filled with scheduled jobs with usage
//                 flags. It contains the following columns:
//  ScheduledJob - String - predefined scheduled job name.
//  Use          - Boolean - True if the scheduled job must be executed in SaaS 
//                 mode. False otherwise.
//
Procedure OnDetermineScheduledJobsUsed(UsageTable) Export
	
	NewRow = UsageTable.Add();
	NewRow.ScheduledJob = "TextExtractionPlanningSaaS";
	NewRow.Use          = True;
	
EndProcedure

// Fills the array of types excluded from data import and export.
//
// Parameters:
//  Types  - Array (Types).
//
Procedure OnFillExcludedFromImportExportTypes(Types) Export
	
	Types.Add(Metadata.InformationRegisters.TextExtractionQueue);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Standard application programming interface

// Adds update handlers that are required by the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see the description of NewUpdateHandlerTable function in the InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Text extraction

// Adds and deletes TextExtractionQueue information register records when the
// file version text extraction state changes.
//
// Parameters:
// TextSource          - CatalogRef.FileVersions, CatalogRef.*AttachedFiles, 
//                       the file whose text extraction state is changed.
// TextExtractionState - EnumRef.FileTextExtractionStatus, new
//  	                   file text extraction status.
//
Procedure UpdateTextExtractionQueueState(TextSource, TextExtractionState) Export
	
	SetPrivilegedMode(True);
	
	RecordSet = InformationRegisters.TextExtractionQueue.CreateRecordSet();
	RecordSet.Filter.DataAreaAuxiliaryData.Set(CommonUse.SessionSeparatorValue());
	RecordSet.Filter.TextSource.Set(TextSource);
	
	If TextExtractionState = Enums.FileTextExtractionStatuses.NotExtracted
			Or TextExtractionState = Enums.FileTextExtractionStatuses.EmptyRef() Then
			
		Write = RecordSet.Add();
		Write.DataAreaAuxiliaryData = CommonUse.SessionSeparatorValue();
		Write.TextSource = TextSource.Ref;
			
	EndIf;
		
	RecordSet.Write();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Text extraction

// Defines the list of data areas that require text extraction and plans
// the extraction using the job queue.
//
Procedure HandleTextExtractionQueue() Export
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	CommonUse.ScheduledJobOnStart();
	
	SetPrivilegedMode(True);
	
	SeparatedMethodName = "FileFunctionsInternal.ExtractTextFromFilesAtServer";
	
	QueryText = 
	"SELECT DISTINCT
	|	TextExtractionQueue.DataAreaAuxiliaryData AS DataArea,
	|	CASE
	|		WHEN TimeZones.Value = """"
	|			THEN UNDEFINED
	|		ELSE ISNULL(TimeZones.Value, UNDEFINED)
	|	END AS TimeZone
	|FROM
	|	InformationRegister.TextExtractionQueue AS TextExtractionQueue
	|		LEFT JOIN Constant.DataAreaTimeZone AS TimeZones
	|		ON TextExtractionQueue.DataAreaAuxiliaryData = TimeZones.DataAreaAuxiliaryData
	|		LEFT JOIN InformationRegister.DataAreas AS DataAreas
	|		ON TextExtractionQueue.DataAreaAuxiliaryData = DataAreas.DataAreaAuxiliaryData
	|WHERE
	|	Not TextExtractionQueue.DataAreaAuxiliaryData IN (&DataAreasToProcess)
	|	AND DataAreas.Status = VALUE(Enum.DataAreaStatuses.Used)";
	Query = New Query(QueryText);
	Query.SetParameter("DataAreasToProcess", JobQueue.GetJobs(
		New Structure("MethodName", SeparatedMethodName)));
	
	Selection = CommonUse.ExecuteQueryOutsideTransaction(Query).Select();
	While Selection.Next() Do
		// Checking for data area lock
		If SaaSOperations.DataAreaLocked(Selection.DataArea) Then
			// The area is locked, proceeding to the next record
			Continue;
		EndIf;
		
		NewJob = New Structure();
		NewJob.Insert("DataArea", Selection.DataArea);
		NewJob.Insert("ScheduledStartTime", ToLocalTime(CurrentUniversalDate(), Selection.TimeZone));
		NewJob.Insert("MethodName", SeparatedMethodName);
		JobQueue.AddJob(NewJob);
	EndDo;
	
EndProcedure

#EndRegion
