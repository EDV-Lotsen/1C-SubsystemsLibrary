////////////////////////////////////////////////////////////////////////////////
// Infobase version update subsystem.
// Server procedures and functions for updating the infobase
// when the configuration version is changed.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Checks whether the infobase update is required when configuration version is changed.
// 
Function InfoBaseUpdateRequired() Export
	
	Return UpdateRequired(Metadata.Version, InfoBaseVersion(Metadata.Name));
	
EndFunction

// Checks whether the current user has rights to execute the infobase update.
// 
Function CanUpdateInfoBase() 
	
	If Not CommonUseCached.DataSeparationEnabled() 
		Or Not CommonUseCached.CanUseSeparatedData() Then
		
		Return AccessRight("ExclusiveMode", Metadata) And Users.InfoBaseUserWithFullAccess(, True);
	Else
		Return True;
	EndIf;
	
EndFunction

// Returns True if the infobase update is required but the current user
// has insufficient rights to do this.
//
Function CantUpdateInfoBase() Export
	
	MetadataVersion = Metadata.Version;
	If IsBlankString(MetadataVersion) Then
		MetadataVersion = "0.0.0.0";
	EndIf;
	
	SharedDataUpdateRequired = False;
	If CommonUseCached.DataSeparationEnabled()
		And CommonUseCached.CanUseSeparatedData() Then
		
		SharedDataVersion = InfoBaseVersion(Metadata.Name, True);
		If UpdateRequired(MetadataVersion, SharedDataVersion) Then
			SharedDataUpdateRequired = True;
		EndIf;
	EndIf;
	
	Return SharedDataUpdateRequired
		Or InfoBaseUpdateRequired() And Not CanUpdateInfoBase();
	
EndFunction	

// Returns True if the infobase update is being executed.

Function ExecutingInfoBaseUpdate() Export
	
	Return InfoBaseUpdateRequired() And CanUpdateInfoBase();
	
EndFunction

// Executes the non interactive infobase data update.
// 
// Parameters:
//  Force - Boolean - if this parameter is set to True, the infobase update will be 
//   executed even if the configuration version was not changed.
// 
// Returns:
//  Undefined - if the update is not required and was not executed.
//  String - address of a temporary store with the list of completed update handlers.
//
Function ExecuteInfoBaseUpdate(Val Force = False) Export

	MetadataVersion = Metadata.Version;
	If IsBlankString(MetadataVersion) Then
		MetadataVersion = "0.0.0.0";
	EndIf;
	
	If CommonUseCached.DataSeparationEnabled()
		And CommonUseCached.CanUseSeparatedData() Then
		
		SharedDataVersion = InfoBaseVersion(Metadata.Name, True);
		If UpdateRequired(MetadataVersion, SharedDataVersion) Then
			Message = NStr("en = 'The common part of the infobase update is not completed.
				|Please contact your infobase administrator.'");
			WriteError(Message);
			Raise Message;
		EndIf;
	EndIf;
	
	DataVersion = InfoBaseVersion(Metadata.Name);
	If Not Force And Not UpdateRequired(MetadataVersion, DataVersion) Then
		Return Undefined;
	EndIf;
	
	Message = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'The application version number is changed from %1 to %2. The infobase will be updated.'"),
		DataVersion, MetadataVersion);
	WriteInformation(Message);
	
	// Checking whether the user has rights for updating the infobase
	
	If Not CanUpdateInfoBase() Then
		Message = NStr("en = 'Insufficient rights to perform the update. Please contact your infobase administrator.'");
		WriteError(Message);
		Raise Message;
	EndIf;
	
	RecordKey = Undefined;
	If CommonUseCached.DataSeparationEnabled() Then
		
		If CommonUseCached.CanUseSeparatedData() Then
			SetPrivilegedMode(True);
		EndIf;
		
		KeyValues = New Structure;
		If CommonUseCached.CanUseSeparatedData() Then
			KeyValues.Insert("DataArea", CommonUse.SessionSeparatorValue());
		Else
			KeyValues.Insert("DataArea", -1);
		EndIf;
		KeyValues.Insert("SubsystemName", "");
		RecordKey = InformationRegisters.SubsystemVersions.CreateRecordKey(KeyValues);
		LockDataForEdit(RecordKey);
	EndIf;
	
	If CommonUseCached.DataSeparationEnabled() Then
		DebugMode = False;
	Else
		SettingValue = CommonSettingsStorage.Load("InfoBaseVersionUpdate", "DebugMode");
		DebugMode = SettingValue = True;
	EndIf;
	
	// Setting the exclusive mode for updating the infobase.
	If Not DebugMode Then
		
		Try
			CommonUse.LockInfoBase();
		Except
			Message = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'The infobase update cannot be performed because there are other connected sessions.
					 |Please contact your infobase administrator.
					 |
					 |Error details:
					 |%1'"), BriefErrorDescription(ErrorInfo()));
			
			WriteError(Message);
			
			If RecordKey <> Undefined Then
				UnlockDataForEdit(RecordKey);
			EndIf;
			
			Raise Message;
		EndTry;
	EndIf;
	
	
	Try
		UpdateHandlerList = InfoBaseUpdateOverridable.UpdateHandlers();
		
		// Subsystem library update handlers are called always
		Handler = UpdateHandlerList.Add();
		Handler.Version = "*";
		Handler.Priority = 1;
		Handler.Procedure = "StandardSubsystemsServer.ExecuteInfoBaseUpdate";
		If Not CommonUseCached.CanUseSeparatedData() Then
			Handler.SharedData = True;
		EndIf;
		
		ExecutedHandlers = ExecuteUpdateIteration(Metadata.Name, Metadata.Version,
			UpdateHandlerList);
	Except
		Message = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Errors occurred during updating the infobase to the version %1: 
				|%2'"), MetadataVersion, DetailErrorDescription(ErrorInfo()));
		WriteError(Message);
		// Disabling the exclusive mode
		If Not DebugMode Then
			
			If ExclusiveMode() Then
				While TransactionActive() Do
					RollbackTransaction();
				EndDo;
			EndIf;
				
			CommonUse.UnlockInfoBase();
			
			If RecordKey <> Undefined Then
				UnlockDataForEdit(RecordKey);
			EndIf;
		EndIf;	
		Raise;
	EndTry;
	
	// Disabling the exclusive mode
	If Not DebugMode Then
		CommonUse.UnlockInfoBase();
		If RecordKey <> Undefined Then
			UnlockDataForEdit(RecordKey);
		EndIf;
	EndIf;	
	
	Message = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'The infobase has been successfully updated to the version %1.'"), MetadataVersion);
	WriteInformation(Message);
	
	PutUpdateDetails = DataVersion <> "0.0.0.0";
	InfoBaseUpdateOverridable.AfterUpdate(DataVersion, MetadataVersion, 
		ExecutedHandlers, PutUpdateDetails);
	
	Address = "";
	If PutUpdateDetails Then
		If CommonUseCached.DataSeparationEnabled()
			And CommonUseCached.CanUseSeparatedData() Then
			
			SaveUpdateDetailsForUsers(ExecutedHandlers);
		Else
			Address = PutToTempStorage(ExecutedHandlers, New UUID);
		EndIf;
	EndIf;
	
	Return Address;

EndFunction

// Calls update handlers from the UpdateHandlers list 
// for LibraryID when updating to InfoBaseMetadataVersion.
//
// Parameters:
//  LibraryID – String – configuration name or library ID;
//  InfoBaseMetadataVersion – String – required metadata version;
//  UpdateHandlers – Map – update handler list.
//
// Returns:
//  ValueTree – update handlers that were executed.
//
Function ExecuteUpdateIteration(Val LibraryID, Val InfoBaseMetadataVersion, 
	Val UpdateHandlers) Export
	
	CurrentInfoBaseVersion = InfoBaseVersion(LibraryID);
	If IsBlankString(CurrentInfoBaseVersion) Then
		 CurrentInfoBaseVersion = "0.0.0.0";
	EndIf;
	NewInfoBaseVersion = CurrentInfoBaseVersion;
	MetadataVersion = InfoBaseMetadataVersion;
	If IsBlankString(MetadataVersion) Then
		 MetadataVersion = "0.0.0.0";
	EndIf;
	
	HandlersToExecute = UpdateInIntervalHandlers(UpdateHandlers, CurrentInfoBaseVersion, MetadataVersion);
	For Each Version In HandlersToExecute.Rows Do
		
		If Version.Version = "*" Then
			Message = NStr("en = 'Performing mandatory infobase update procedures.'");
		Else
			NewInfoBaseVersion = Version.Version;
			
			If LibraryID = Metadata.Name Then 
				Message = NStr("en = 'Performing the infobase update from the version %1 to the version %2.'");
			Else
				Message = NStr("en = 'Performing the infobase update of the parent configuration %3 from the version %1 to the version %2'");
			EndIf;
			
			Message = StringFunctionsClientServer.SubstituteParametersInString(Message,
			 CurrentInfoBaseVersion, NewInfoBaseVersion, LibraryID);
			
		EndIf;
		
		WriteInformation(Message);
		
		For Each Handler In Version.Rows Do
			CommonUse.ExecuteSafely(Handler.Procedure);
		EndDo;
		
		If Version.Version = "*" Then
			Message = NStr("en = 'Mandatory infobase update procedures have been performed successfully.'");
		Else
			// Setting the infobase version number
			SetInfoBaseVersion(LibraryID, NewInfoBaseVersion);
			
			If LibraryID = Metadata.Name Then 
				Message = NStr("en = 'The infobase has been successfully updated from the version %1 to the version %2.'");
			Else
				Message = NStr("en = 'The infobase of the parent configuration %3 has been successfully updated from the version %1 to the version %2.'");
			EndIf;
			
			Message = StringFunctionsClientServer.SubstituteParametersInString(Message,
			 CurrentInfoBaseVersion, NewInfoBaseVersion, LibraryID);
			
			CurrentInfoBaseVersion = NewInfoBaseVersion;
			
		EndIf;
		WriteInformation(Message);
		
	EndDo;
	
	// Setting the infobase version number
	If InfoBaseVersion(LibraryID) <> InfoBaseMetadataVersion Then
		SetInfoBaseVersion(LibraryID, InfoBaseMetadataVersion);
	EndIf;
	
	Return HandlersToExecute;
	
EndFunction

// Returns an empty table of update and initial filling handlers.
//
// Returns:
//  ValueTable – table with the following columns:
//   Version - update handler is executed when you update the infobase to this version;
//   Procedure - update handler full name. 
//    The procedure must have the Export keyword. 
//   Optional - flag that shows whether the handler must be executed on a first run
//    of the empty infobase.
//   Priority - Number - for internal use.
//   SharedData - flag that shows whether the handler must be executed before
//    any handler that uses separated data.
//
Function NewUpdateHandlerTable() Export
	
	Handlers = New ValueTable;
	Handlers.Columns.Add("Version", New TypeDescription("String", New StringQualifiers(0)));
	Handlers.Columns.Add("Procedure", New TypeDescription("String", New StringQualifiers(0)));
	Handlers.Columns.Add("Optional");
	Handlers.Columns.Add("Priority", New TypeDescription("Number", New NumberQualifiers(2)));
	Handlers.Columns.Add("SharedData", New TypeDescription("Boolean"));
	Return Handlers;
	
EndFunction

// Retrieves the configuration or parent configuration (library) version 
// that is stored in the infobase.
//
// Parameters:
//  LibraryID – String – configuration name or library ID.
//
// Returns:
//  String – version.
//
// Example:
//  InfoBaseConfigurationVersion = InfoBaseVersion(Metadata.Name);
//
Function InfoBaseVersion(Val LibraryID, Val GetCommonDataVersion = False) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	SubsystemVersions.Version AS Version
	|FROM
	|	InformationRegister.SubsystemVersions AS SubsystemVersions
	|WHERE
	|	SubsystemVersions.SubsystemName = &SubsystemName
	|	AND SubsystemVersions.DataArea = &DataArea";
	If Not CommonUseCached.CanUseSeparatedData() 
		Or GetCommonDataVersion Then
		
		DataArea = -1;
	Else
		DataArea = CommonUse.SessionSeparatorValue();
	EndIf;
	Query.SetParameter("DataArea", DataArea);
	Query.SetParameter("SubsystemName", LibraryID);
	ValueTable = Query.Execute().Unload();
	Result = "";
	If ValueTable.Count() > 0 Then
		Result = TrimAll(ValueTable[0].Version);
	EndIf;
	Return ?(IsBlankString(Result), "0.0.0.0", Result);
	
EndFunction

// Shows whether the infobase starts for the first time.
//
Function FirstRun() Export
	
	SetPrivilegedMode(True);
	
	If CommonUseCached.IsSeparatedConfiguration() Then
		
		If Not Constants.UseSeparationByDataAreas.Get()
			And Not Constants.DontUseSeparationByDataAreas.Get() Then
			
			// The infobase starts for the first time
			
			Return True;
			
		Else
			
			Query = New Query;
			Query.Text = 
			"SELECT
			|	1
			|FROM
			|	InformationRegister.SubsystemVersions AS SubsystemVersions
			|WHERE
			|	SubsystemVersions.DataArea = &DataArea";
			If CommonUseCached.CanUseSeparatedData() Then
				DataArea = CommonUse.SessionSeparatorValue();
			Else
				DataArea = -1;
			EndIf;
			Query.SetParameter("DataArea", DataArea);
			
			Return Query.Execute().IsEmpty();
			
		EndIf;
		
	Else
	
		Query = New Query;
		Query.Text = 
		"SELECT
		|	1
		|FROM
		|	InformationRegister.SubsystemVersions AS SubsystemVersions";
		Return Query.Execute().IsEmpty();
		
	EndIf;
	
EndFunction

// Shows whether update details must be displayed to the user.
//
Function ShowUpdateDetails() Export
	
	DontShow = CommonUse.CommonSettingsStorageLoad("UpdateInfoBase", 
		"DontShowUpdateDetails");
	If DontShow = True Then
		Return False;
	EndIf;
	
	ExecutedHandlers = CommonUse.CommonSettingsStorageLoad("UpdateInfoBase", 
		"ExecutedHandlers");
	If ExecutedHandlers = Undefined Then
		Return False;
	Else
		Return True;
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Common use procedures and functions.

// For internal use only.
//
Function UpdateRequired(Val MetadataVersion, Val DataVersion) Export
	
	Return Not IsBlankString(MetadataVersion) And DataVersion <> MetadataVersion;
	
EndFunction

Procedure SetInfoBaseVersion(Val LibraryID, Val VersionNumber) 
	
	If Not CommonUseCached.CanUseSeparatedData() Then
		DataArea = -1;
	Else
		DataArea = CommonUse.SessionSeparatorValue();
	EndIf;
	
	RecordSet = InformationRegisters.SubsystemVersions.CreateRecordSet();
	RecordSet.Filter.DataArea.Set(DataArea);
	RecordSet.Filter.SubsystemName.Set(LibraryID);
	
	NewRecord = RecordSet.Add();
	
	NewRecord.DataArea = DataArea;
	NewRecord.SubsystemName = LibraryID;
	NewRecord.Version = VersionNumber;
	
	RecordSet.Write();
	
EndProcedure

Function UpdateInIntervalHandlers(Val AllHandlers, Val VersionFrom, Val VersionBefore)
	
	QueryBuilder = New QueryBuilder();
	Source = New DataSourceDescription(AllHandlers);
	Source.Columns.Version.Dimension = True;
	QueryBuilder.DataSource = Source;
	QueryBuilder.Dimensions.Add("Version");
	QueryBuilder.Execute();
	SelectionTotals = QueryBuilder.Result.Choose(QueryResultIteration.ByGroups);
	
	SharedDataFilter = New Array;
	If CommonUseCached.DataSeparationEnabled() Then
		SharedDataFilter.Add(Not CommonUseCached.CanUseSeparatedData());
	Else
		SharedDataFilter.Add(True);
		SharedDataFilter.Add(False);
	EndIf;
	
	HandlersToExecute = New ValueTree();
	HandlersToExecute.Columns.Add("Version");
	HandlersToExecute.Columns.Add("Procedure");
	HandlersToExecute.Columns.Add("Priority");
	While SelectionTotals.Next() Do
		
		If SelectionTotals.Version <> "*" And 
			Not (CommonUseClientServer.CompareVersions(SelectionTotals.Version, VersionFrom) > 0 
				And CommonUseClientServer.CompareVersions(SelectionTotals.Version, VersionBefore) <= 0) Then
			Continue;
		EndIf;
		
		VersionString = Undefined;
		Selection = SelectionTotals.Choose(QueryResultIteration.Linear);
		While Selection.Next() Do
			If Selection.Procedure = Null Then
				Continue;
			EndIf;
			If Selection.Optional = True And VersionFrom = "0.0.0.0" Then
				Continue;
			EndIf;
			
			If SharedDataFilter.Find(Selection.SharedData) = Undefined Then
				Continue;
			EndIf;
			
			If VersionString = Undefined Then
				VersionString = HandlersToExecute.Rows.Add();
				VersionString.Version = SelectionTotals.Version;
				VersionString.Priority = Selection.Priority;
			EndIf;
			Handler = VersionString.Rows.Add();
			FillPropertyValues(Handler, Selection, "Version,Procedure");
		EndDo;
		
	EndDo;
	
	SortUpdateHandlerTree(HandlersToExecute);
	
	Return HandlersToExecute;
	
EndFunction

// For internal use only.
//
Procedure SortUpdateHandlerTree(Val HandlerTree) Export
	
	// Sorting handler in ascending order based on versions
	LineCount = HandlerTree.Rows.Count();
	For Ind1 = 2 to LineCount Do
		For Ind2 = 0 to LineCount - Ind1 Do
			
			Version1 = HandlerTree.Rows[Ind2].Version;
			Version2 = HandlerTree.Rows[Ind2+1].Version;
			If Version1 = "*" And Version2 = "*" Then
				Result = HandlerTree.Rows[Ind2].Priority - HandlerTree.Rows[Ind2 + 1].Priority;
			ElsIf Version1 = "*" Then
				Result = -1;
			ElsIf Version2 = "*" Then
				Result = 1;
			Else
				Result = CommonUseClientServer.CompareVersions(Version1, Version2);
				If Result = 0 Then
					Result = HandlerTree.Rows[Ind2].Priority - HandlerTree.Rows[Ind2 + 1].Priority;
				EndIf;
			EndIf;	
			
			If Result > 0 Then 
				HandlerTree.Rows.Move(Ind2, 1);
			EndIf;
			
		EndDo;
	EndDo;
	
EndProcedure

Procedure SaveUpdateDetailsForUsers(Val ExecutedHandlers)
	
	ColumnStructure = GetColumnStructure(ExecutedHandlers);
	
	For Each InfoBaseUser In InfoBaseUsers.GetUsers() Do
		PreviouslyExecutedHandlers = CommonSettingsStorage.Load("UpdateInfoBase", 
			"ExecutedHandlers", , InfoBaseUser.Name);
		
		If PreviouslyExecutedHandlers = Undefined Then
			HandlerTree = ExecutedHandlers;
		Else
			HandlerTree = PreviouslyExecutedHandlers;
			CopyRowsToTree(HandlerTree.Rows, PreviouslyExecutedHandlers.Rows, ColumnStructure);
			SortUpdateHandlerTree(HandlerTree);
		EndIf;
		
		SettingsDescription = New SettingsDescription;
		SettingsDescription.Presentation = NStr("en = 'Executed infobase update handlers'");
		
		CommonSettingsStorage.Save("UpdateInfoBase", "ExecutedHandlers", HandlerTree,
			SettingsDescription, InfoBaseUser.Name);
		
	EndDo;
	
EndProcedure

Function GetColumnStructure(Val SourceCollection)
	
	ColumnStructure = New Structure;
	For Each Column In SourceCollection.Columns Do
		ColumnStructure.Insert(Column.Name);
	EndDo;
	Return ColumnStructure;
	
EndFunction

Procedure CopyRowsToTree(Val TargetRows, Val SourceRows, Val ColumnStructure)
	
	For Each SourceRow In SourceRows Do
		FillPropertyValues(ColumnStructure, SourceRow);
		FoundRows = TargetRows.FindRows(ColumnStructure);
		If FoundRows.Count() = 0 Then
			TargetRow = TargetRows.Add();
			FillPropertyValues(TargetRow, SourceRow);
		Else
			TargetRow = FoundRows[0];
		EndIf;
		
		CopyRowsToTree(TargetRow.Rows, SourceRow.Rows, ColumnStructure);
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for logging the update.

// Returns a string constant that is used for generating an event log message.
//
// Returns:
// String.
//
Function EventLogMessageText() Export
	
	Return NStr("en = 'Infobase update'");
	
EndFunction	

Procedure WriteInformation(Val Text) 
	
	WriteLogEvent(EventLogMessageText(), EventLogLevel.Information,,, Text);
	
EndProcedure

Procedure WriteError(Val Text) 
	
	WriteLogEvent(EventLogMessageText(), EventLogLevel.Error,,, Text);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for outputting update details.

// Generates a spreadsheet document with update details
// based on the UpdateHandlers version list.
//
Function DocumentUpdateDetails(Val UpdateHandlers) Export
	
	DocumentUpdateDetails = New SpreadsheetDocument();
	If UpdateHandlers = Undefined Then
		Return DocumentUpdateDetails;
	EndIf;
	
	UpdateDetailsTemplate = Metadata.CommonTemplates.Find("UpdateDetails");
	If UpdateDetailsTemplate <> Undefined Then
		UpdateDetailsTemplate = GetCommonTemplate(UpdateDetailsTemplate);
	Else	
		UpdateDetailsTemplate = New SpreadsheetDocument();
	EndIf;
	
	For Each Version In UpdateHandlers.Rows Do
		
		If Version.Version = "*" Then
			Continue;
		EndIf;
		
		OutputUpdateDetails(Version.Version, DocumentUpdateDetails, UpdateDetailsTemplate);
		
	EndDo;
	
	Return DocumentUpdateDetails;
	
EndFunction

// Outputs update details of the specified version.
//
// Parameters:
// VersionNumber – String - version number whose update details will be outputted 
// to the DocumentUpdateDetails spreadsheet document based on the 
// UpdateDetailsTemplate template.
//
Procedure OutputUpdateDetails(Val VersionNumber, DocumentUpdateDetails, UpdateDetailsTemplate)
	
	Number = StrReplace(VersionNumber, ".", "_");
	
	If UpdateDetailsTemplate.Areas.Find("Header" + Number) = Undefined Then
		Return;
	EndIf;
	
	DocumentUpdateDetails.Put(UpdateDetailsTemplate.GetArea("Header" + Number));
	DocumentUpdateDetails.StartRowGroup("Version" + Number);
	DocumentUpdateDetails.Put(UpdateDetailsTemplate.GetArea("Version" + Number));
	DocumentUpdateDetails.EndRowGroup();
	DocumentUpdateDetails.Put(UpdateDetailsTemplate.GetArea("Indent"));
	
EndProcedure

