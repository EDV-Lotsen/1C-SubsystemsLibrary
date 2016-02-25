////////////////////////////////////////////////////////////////////////////////
// Data exchange SaaS subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

// Declares internal events of the DataExchange subsystem:
//
// Server events:
//     OnDataExport, 
//     OnDataImport.
//
// See the description of this procedure in the StandardSubsystemsServer module.
Procedure OnAddInternalEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS.
	
  // The procedure is called when a user initiates standalone workstation
  // creation.
	// Additional checks before standalone workstation creation can be
  // implemented in event handlers (if creation is impossible, ensure that
  // an exception is raised).
	//
	// Syntax:
	// Procedure OnCreateStandaloneWorkstation() Export
	//
	ServerEvents.Add("StandardSubsystems.SaaSOperations.DataExchangeSaaS\OnCreateStandaloneWorkstation");
	
EndProcedure

// Initializes a standalone workstation during the first start,
// fills the list of users, and specifies other settings.
// The function is called before user authorization. It might
// require restarting the computer.
// 
Function ContinueSettingUpStandaloneWorkstation(Parameters) Export
	
	If Not MustPerformStandaloneWorkstationSetupOnFirstStart() Then
		Return False;
	EndIf;
		
	Try
		PerformStandaloneWorkstationSetupOnFirstStart();
		Parameters.Insert("RestartAfterStandaloneWorkstationSetup");
	Except
		ErrorInfo = ErrorInfo();
		
		WriteLogEvent(StandaloneWorkstationCreationEventLogMessageText(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo));
		
		Parameters.Insert("StandaloneWorkstationSetupError",
			BriefErrorDescription(ErrorInfo));
	EndTry;
	
	Return True;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS USED IN SAAS MODE

// For internal use
// 
Procedure CreateStandaloneWorkstationInitialImage(Parameters,
			InitialImageTempStorageAddress,
			SetupPackageInfoTempStorageAddress
	) Export
	
	StandaloneWorkstationGenerationWizard = DataProcessors.StandaloneWorkstationGenerationWizard.Create();
	
	FillPropertyValues(StandaloneWorkstationGenerationWizard, Parameters);
	
	StandaloneWorkstationGenerationWizard.CreateStandaloneWorkstationInitialImage(
				Parameters.NodeFilterStructure,
				Parameters.SelectedSynnchronizationUsers,
				InitialImageTempStorageAddress,
				SetupPackageInfoTempStorageAddress);
	
EndProcedure

// For internal use
// 
Procedure DeleteStandaloneWorkstation(Parameters, StorageAddress) Export
	
	DataExchangeServer.CheckExchangeManagementRights();
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		// ============================ {for compatibility with SL 2.1.3}
		User = InformationRegisters.CommonInfobaseNodeSettings.UserForDataSynchronization(Parameters.StandaloneWorkstation);
		
		If User <> Undefined Then
			
			UserObject = User.GetObject();
			
			If UserObject <> Undefined Then
				
				UserObject.Delete();
				
			EndIf;
			
		EndIf;
		// ============================ {for compatibility with SL 2.1.3}
		
		StandaloneWorkstationObject = Parameters.StandaloneWorkstation.GetObject();
		
		If StandaloneWorkstationObject <> Undefined Then
			
			StandaloneWorkstationObject.Delete();
			
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// For internal use
// 
Function StandaloneModeSupported() Export
	
	Return DataExchangeCached.StandaloneModeSupported();
	
EndFunction

// For internal use
// 
Function StandaloneWorkstationNumber() Export
	
	QueryText = "
	|SELECT
	|	COUNT(*) AS Count
	|FROM
	|	ExchangePlan.[ExchangePlanName] AS Table
	|WHERE
	|	Table.Ref <> &ApplicationInSaaS
	|	AND NOT Table.DeletionMark";
	
	QueryText = StrReplace(QueryText, "[ExchangePlanName]", StandaloneModeExchangePlan());
	
	Query = New Query;
	Query.SetParameter("ApplicationInSaaS", ApplicationInSaaS());
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Return Selection.Count;
EndFunction

// For internal use
// 
Function ApplicationInSaaS() Export
	
	SetPrivilegedMode(True);
	
	If DataExchangeServer.MasterNode() <> Undefined Then
		
		Return DataExchangeServer.MasterNode();
		
	Else
		
		Return ExchangePlans[StandaloneModeExchangePlan()].ThisNode();
		
	EndIf;
	
EndFunction

// For internal use
// 
Function StandaloneWorkstation() Export
	
	QueryText =
	"SELECT TOP 1
	|	Table.Ref AS StandaloneWorkstation
	|FROM
	|	ExchangePlan.[ExchangePlanName] AS Table
	|WHERE
	|	Table.Ref <> &ApplicationInSaaS
	|	AND NOT Table.DeletionMark";
	
	QueryText = StrReplace(QueryText, "[ExchangePlanName]", StandaloneModeExchangePlan());
	
	Query = New Query;
	Query.SetParameter("ApplicationInSaaS", ApplicationInSaaS());
	Query.Text = QueryText;
	
	Result = Query.Execute();
	
	If Result.IsEmpty() Then
		Return Undefined;
	EndIf;
	
	Selection = Result.Select();
	Selection.Next();
	
	Return Selection.StandaloneWorkstation;
EndFunction

// For internal use
// 
Function StandaloneModeExchangePlan() Export
	
	Return DataExchangeCached.StandaloneModeExchangePlan();
	
EndFunction

// For internal use
// 
Function IsStandaloneWorkstationNode(Val InfobaseNode) Export
	
	SetPrivilegedMode(True);
	
	Return DataExchangeCached.IsStandaloneWorkstationNode(InfobaseNode);
	
EndFunction

// For internal use
// 
Function LastDoneSynchronizationDate(StandaloneWorkstation) Export
	
	QueryText =
	"SELECT
	|	MIN(SuccessfulDataExchangeStates.EndDate) AS SynchronizationDate
	|FROM
	|	[SuccessfulDataExchangeStates] AS SuccessfulDataExchangeStates
	|WHERE
	|	SuccessfulDataExchangeStates.InfobaseNode = &StandaloneWorkstation";
	
	If CommonUseCached.DataSeparationEnabled()
		And CommonUseCached.CanUseSeparatedData() Then
		QueryText = StrReplace(QueryText, "[SuccessfulDataExchangeStates]", "InformationRegister.DataAreasSuccessfulDataExchangeStates");
	Else
		QueryText = StrReplace(QueryText, "[SuccessfulDataExchangeStates]", "InformationRegister.SuccessfulDataExchangeStates");
	EndIf;
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("StandaloneWorkstation", StandaloneWorkstation);
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Return ?(ValueIsFilled(Selection.SynchronizationDate), Selection.SynchronizationDate, Undefined);
EndFunction

// For internal use
// 
Function GenerateStandaloneWorkstationDefaultDescription() Export
	
	QueryText = "
	|SELECT
	|	COUNT(*) AS Count
	|FROM
	|	ExchangePlan.[ExchangePlanName] AS Table
	|WHERE
	|	Table.Description LIKE &NamePattern";
	
	QueryText = StrReplace(QueryText, "[ExchangePlanName]", StandaloneModeExchangePlan());
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("NamePattern", DefaultStandaloneWorkstationDescription() + "%");
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Count = Selection.Count;
	
	If Count = 0 Then
		
		Return DefaultStandaloneWorkstationDescription();
		
	Else
		
		Result = "[Description] ([Count])";
		Result = StrReplace(Result, "[Description]", DefaultStandaloneWorkstationDescription());
		Result = StrReplace(Result, "[Count]", Format(Count + 1, "NG=0"));
		
		Return Result;
	EndIf;
	
EndFunction

// For internal use
// 
Function GenerateStandaloneWorkstationPrefix(Val LastPrefix = "") Export
	
	AllowedChars = StandaloneWorkstationPrefixAllowedChars();
	
	LastStandaloneWorkstationChar = Left(LastPrefix, 1);
	
	CharPosition = Find(AllowedChars, LastStandaloneWorkstationChar);
	
	If CharPosition = 0 OR IsBlankString(LastStandaloneWorkstationChar) Then
		
		Char = Left(AllowedChars, 1); // Using the first character
		
	ElsIf CharPosition >= StrLen(AllowedChars) Then
		
		Char = Right(AllowedChars, 1); // Using the last character
		
	Else
		
		Char = Mid(AllowedChars, CharPosition + 1, 1); // Using the next character
		
	EndIf;
	
	ApplicationPrefix = Right(GetFunctionalOption("InfobasePrefix"), 1);
	
	Result = "[Char][ApplicationPrefix]";
	Result = StrReplace(Result, "[Char]", Char);
	Result = StrReplace(Result, "[ApplicationPrefix]", ApplicationPrefix);
	
	Return Result;
EndFunction

// For internal use
// 
Function InstallPackageFileName() Export
	
	Return NStr("en = 'Standalone mode.zip'");
	
EndFunction

// For internal use
// 
Function DataTransferRestrictionDetails(StandaloneWorkstation) Export
	
	StandaloneModeExchangePlan = StandaloneModeExchangePlan();
	
	NodeFilterStructure = DataExchangeServer.NodeFilterStructure(StandaloneModeExchangePlan, "");
	
	If NodeFilterStructure.Count() = 0 Then
		Return "";
	EndIf;
	
	Attributes = New Array;
	
	For Each Item In NodeFilterStructure Do
		
		Attributes.Add(Item.Key);
		
	EndDo;
	
	Attributes = StringFunctionsClientServer.StringFromSubstringArray(Attributes);
	
	AttributeValues = CommonUse.ObjectAttributeValues(StandaloneWorkstation, Attributes);
	
	For Each Item In NodeFilterStructure Do
		
		If TypeOf(Item.Value) = Type("Structure") Then
			
			Table = AttributeValues[Item.Key].Unload();
			
			For Each NestedItem In Item.Value Do
				
				NodeFilterStructure[Item.Key][NestedItem.Key] = Table.UnloadColumn(NestedItem.Key);
				
			EndDo;
			
		Else
			
			NodeFilterStructure[Item.Key] = AttributeValues[Item.Key];
			
		EndIf;
		
	EndDo;
	
	Return DataExchangeServer.DataTransferRestrictionDetails(StandaloneModeExchangePlan, NodeFilterStructure, "");
EndFunction

// For internal use
// 
Function StandaloneWorkstationMonitor() Export
	
	QueryText = "
	|SELECT
	|	SuccessfulDataExchangeStates.InfobaseNode AS StandaloneWorkstation,
	|	MIN(SuccessfulDataExchangeStates.EndDate) AS SynchronizationDate
	|INTO SuccessfulDataExchangeStates
	|FROM
	|	InformationRegister.DataAreasSuccessfulDataExchangeStates AS SuccessfulDataExchangeStates
	|
	|GROUP BY
	|	SuccessfulDataExchangeStates.InfobaseNode
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExchangePlan.Ref AS StandaloneWorkstation,
	|	ISNULL(SuccessfulDataExchangeStates.SynchronizationDate, Undefined) AS SynchronizationDate
	|FROM
	|	ExchangePlan.[ExchangePlanName] AS ExchangePlan
	|
	|	LEFT JOIN SuccessfulDataExchangeStates AS SuccessfulDataExchangeStates
	|	ON ExchangePlan.Ref = SuccessfulDataExchangeStates.StandaloneWorkstation
	|
	|WHERE
	|	ExchangePlan.Ref <> &ApplicationInSaaS
	|	AND NOT ExchangePlan.DeletionMark
	|
	|ORDER BY
	|	ExchangePlan.Presentation";
	
	QueryText = StrReplace(QueryText, "[ExchangePlanName]", StandaloneModeExchangePlan());
	
	Query = New Query;
	Query.SetParameter("ApplicationInSaaS", ApplicationInSaaS());
	Query.Text = QueryText;
	
	SynchronizationSettings = Query.Execute().Unload();
	SynchronizationSettings.Columns.Add("SynchronizationDatePresentation");
	
	For Each SynchronizationSettingsItem In SynchronizationSettings Do
		
		If ValueIsFilled(SynchronizationSettingsItem.SynchronizationDate) Then
			SynchronizationSettingsItem.SynchronizationDatePresentation =
				DataExchangeServer.RelativeSynchronizationDate(SynchronizationSettingsItem.SynchronizationDate);
		Else
			SynchronizationSettingsItem.SynchronizationDatePresentation = NStr("en = 'Never'");
		EndIf;
		
	EndDo;
	
	Return SynchronizationSettings;
EndFunction

// For internal use
// 
Function StandaloneWorkstationCreationEventLogMessageText() Export
	
	Return NStr("en = 'Standalone mode.Standalone workstation creation'", CommonUseClientServer.DefaultLanguageCode());
	
EndFunction

// For internal use
// 
Function StandaloneWorkstationDeletionEventLogMessageText() Export
	
	Return NStr("en = 'Standalone mode.Standalone workstation deletion'", CommonUseClientServer.DefaultLanguageCode());
	
EndFunction

// For internal use
// 
Function InstructionTextFromTemplate(Val TemplateName) Export
	
	Result = DataProcessors.StandaloneWorkstationGenerationWizard.GetTemplate(TemplateName).GetText();
	Result = StrReplace(Result, "ApplicationName", Metadata.Synonym);
	Result = StrReplace(Result, "[PlatformVersion]", DataExchangeSaaS.RequiredPlatformVersion());
	Return Result;
EndFunction

// For internal use
// 
Function ReplaceProhibitedCharsInUserName(Val Value, Val ReplacementChar = "_") Export
	
	ProhibitedChars = DataExchangeClientServer.ProhibitedCharsInWSProxyUserName();
	
	For Index = 1 To StrLen(ProhibitedChars) Do
		
		DisallowedChar = Mid(ProhibitedChars, Index, 1);
		
		Value = StrReplace(Value, DisallowedChar, ReplacementChar);
		
	EndDo;
	
	Return Value;
EndFunction

//

// For internal use
// 
Function DefaultStandaloneWorkstationDescription()
	
	Result = NStr("en = 'Standalone mode - %1'");
	
	Return StringFunctionsClientServer.SubstituteParametersInString(Result, UserFullName());
EndFunction

// For internal use
// 
Function StandaloneWorkstationPrefixAllowedChars()
	
	Return NStr("en = 'ABCDEFGHIKLMNOPQRSTVXYZabcdefghiklmnopqrstvxyz'"); // 47 characters
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS USED IN STANDALONE MODE

// For internal use
// 
Procedure SynchronizeDataWithApplicationOnInternet() Export
	
	CommonUse.ScheduledJobOnStart();
	
	SetPrivilegedMode(True);
	
	If Not IsStandaloneWorkstation() Then
		
		DefaultLanguageCode = CommonUseClientServer.DefaultLanguageCode();
		
		DetailErrorPresentationForEventLog =
			NStr("en = 'The infobase is not a standalone workstation. Data synchronization canceled.'", CommonUseClientServer.DefaultLanguageCode());
 
		DetailErrorDescription = NStr("en = 'The infobase is not a standalone workstation. Data synchronization canceled.'"); // Event log message text
		
		WriteLogEvent(DataSynchronizationEventLogMessageText(),
			EventLogLevel.Error,,, DetailErrorPresentationForEventLog);
		Raise DetailErrorDescription;
		
	EndIf;
	
	Cancel = False;
	
	DataExchangeServer.ExecuteDataExchangeForInfobaseNode(Cancel, ApplicationInSaaS(), True, True,
		Enums.ExchangeMessageTransportKinds.WS);
	
	If Cancel Then
		Raise NStr("en = 'Errors occurred during data synchronization with the web application (see the event log).'");
	EndIf;
	
EndProcedure

// For internal use
// 
Procedure PerformStandaloneWorkstationSetupOnFirstStart() Export
	
	If Not CommonUse.FileInfobase() Then
		Raise NStr("en = 'The first start of a standalone workstation must be performed in file mode.'");
	EndIf;
	
	SetPrivilegedMode(True);
	
	// Importing rules because exchange rules are not migrated to DIB
	DataExchangeServer.UpdateDataExchangeRules();
	ImportInitialImageData();
	ImportParametersFromInitialImage();
	
	SetPrivilegedMode(False);
	
	OnContinueStandaloneWorkstationSetup();
	
EndProcedure

Procedure OnContinueStandaloneWorkstationSetup()

	SetPrivilegedMode(True);
	UsersInternal.ClearNonExistentInfobaseUserIDs();

EndProcedure


// For internal use
// 
Procedure DisableAutoDataSyncronizationWithWebApplication() Export
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		
		SetPrivilegedMode(True);
		
		ScheduledJobsServer.SetUseScheduledJob(
			Metadata.ScheduledJobs.DataSynchronizationWithWebApplication, False);
	
	EndIf;
	
EndProcedure

// For internal use
// 
Function MustPerformStandaloneWorkstationSetupOnFirstStart() Export
	
	SetPrivilegedMode(True);
	Return Not Constants.SubordinateDIBNodeSetupCompleted.Get() And IsStandaloneWorkstation();
	
EndFunction

// For internal use
// 
Function SynchronizeDataWithWebApplicationOnStart() Export
	
	Return IsStandaloneWorkstation()
		And Constants.SubordinateDIBNodeSetupCompleted.Get()
		And Constants.SynchronizeDataWithWebApplicationOnStart.Get()
		And SynchronizationWithServiceNotExecuteLongTime()
		And DataExchangeServer.DataSynchronizationPermitted()
	;
EndFunction

// For internal use
// 
Function SynchronizeDataWithWebApplicationOnExit() Export
	
	Return IsStandaloneWorkstation()
		And Constants.SubordinateDIBNodeSetupCompleted.Get()
		And Constants.SynchronizeDataWithWebApplicationOnExit.Get()
		And DataExchangeServer.DataSynchronizationPermitted()
	;
EndFunction

// For internal use
// 
Function DefaultDataSynchronizationSchedule() Export // Every hour
	
	Months = New Array;
	Months.Add(1);
	Months.Add(2);
	Months.Add(3);
	Months.Add(4);
	Months.Add(5);
	Months.Add(6);
	Months.Add(7);
	Months.Add(8);
	Months.Add(9);
	Months.Add(10);
	Months.Add(11);
	Months.Add(12);
	
	WeekDays = New Array;
	WeekDays.Add(1);
	WeekDays.Add(2);
	WeekDays.Add(3);
	WeekDays.Add(4);
	WeekDays.Add(5);
	WeekDays.Add(6);
	WeekDays.Add(7);
	
	Schedule = New JobSchedule;
	Schedule.Months            = Months;
	Schedule.WeekDays          = WeekDays;
	Schedule.RepeatPeriodInDay = 60*60; // 60 minutes
	Schedule.DaysRepeatPeriod  = 1; // Every day
	
	Return Schedule;
EndFunction

// For internal use
// 
Function IsStandaloneWorkstation() Export
	
	SetPrivilegedMode(True);
	
	Return DataExchangeCached.IsStandaloneWorkstation();
	
EndFunction

// For internal use
// 
Function AddressForRestoringAccountPassword() Export
	
	SetPrivilegedMode(True);
	
	Return TrimAll(Constants.AddressForRestoringAccountPassword.Get());
EndFunction

// For internal use
// 
Function DataExchangeExecutionFormParameters() Export
	
	Return New Structure("InfobaseNode, AddressForRestoringAccountPassword, CloseAfterSynchronizationIsDone", ApplicationInSaaS(), AddressForRestoringAccountPassword(), True);
EndFunction

// For internal use
// 
Function SynchronizationWithServiceNotExecuteLongTime(Val Interval = 3600) Export // Default interval value is 1 hour
	
	Return True;
	
EndFunction

// Determines whether an object can be changed.
// An object cannot be written on a standalone workstation if 
// all of the following conditions are met:
// 1. This is standalone workstation.
// 2. This is a nonseparated metadata object.
// 3. This object is included in the standalone mode exchange plan.
// 4. This object is excluded from the exception list.
//
// Parameters:
//   MetadataObject - object metadata to check 
//   ReadOnly       - Boolean - if True, the object is read-only
//
Procedure DefineDataChangeCapability(MetadataObject, ReadOnly) Export
	
	SetPrivilegedMode(True);
	
	ReadOnly = IsStandaloneWorkstation()
		And (Not CommonUseCached.IsSeparatedMetadataObject(MetadataObject.FullName(),
			CommonUseCached.MainDataSeparator())
			And Not CommonUseCached.IsSeparatedMetadataObject(MetadataObject.FullName(),
				CommonUseCached.AuxiliaryDataSeparator()))
		And Not MetadataObjectIsException(MetadataObject)
		And Metadata.ExchangePlans[StandaloneModeExchangePlan()].Content.Contains(MetadataObject);
	
EndProcedure

// For internal use
// 
Procedure ImportParametersFromInitialImage()
	
	Parameters = GetParametersFromInitialImage();
	
	Try
		ExchangePlans.SetMasterNode(Undefined);
	Except
		WriteLogEvent(StandaloneWorkstationCreationEventLogMessageText(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Raise NStr("en = 'Possibly the infobase is open in Designer mode.
		|Exit Designer and restart the application.'");
	EndTry;
	
	// Creating exchange plan nodes for standalone mode in the zero data area
	StandaloneWorkstationNode = ExchangePlans[StandaloneModeExchangePlan()].ThisNode().GetObject();
	StandaloneWorkstationNode.Code          = Parameters.StandaloneWorkstationCode;
	StandaloneWorkstationNode.Description = Parameters.StandaloneWorkstationDescription;
	StandaloneWorkstationNode.AdditionalProperties.Insert("GettingExchangeMessage");
	StandaloneWorkstationNode.Write();
	
	ApplicationNodeSaaS = ExchangePlans[StandaloneModeExchangePlan()].CreateNode();
	ApplicationNodeSaaS.Code          = Parameters.ApplicationCodeSaaS;
	ApplicationNodeSaaS.Description = Parameters.ApplicationDescriptionSaaS;
	ApplicationNodeSaaS.AdditionalProperties.Insert("GettingExchangeMessage");
	ApplicationNodeSaaS.Write();
	
	// Making the created node the master node
	ExchangePlans.SetMasterNode(ApplicationNodeSaaS.Ref);
	
	BeginTransaction();
	Try
		
		Constants.UseDataSynchronization.Set(True);
		Constants.SubordinateDIBNodeSettings.Set("");
		Constants.DistributedInfobaseNodePrefix.Set(Parameters.Prefix);
		Constants.SynchronizeDataWithWebApplicationOnStart.Set(True);
		Constants.SynchronizeDataWithWebApplicationOnExit.Set(True);
		Constants.SystemTitle.Set(Parameters.SystemTitle);
		
		Constants.IsStandaloneWorkstation.Set(True);
		Constants.UseSeparationByDataAreas.Set(False);
		
		// The constant value must be True to call the standalone 
   // workstation setup wizard
		Constants.SubordinateDIBNodeSetupCompleted.Set(True);
		
		RecordStructure = New Structure;
		RecordStructure.Insert("Node", ApplicationInSaaS());
		RecordStructure.Insert("DefaultExchangeMessageTransportKind", Enums.ExchangeMessageTransportKinds.WS);
		
		RecordStructure.Insert("WSUseLargeDataTransfer", True);
		
		RecordStructure.Insert("WSURL", Parameters.URL);
		
		// Adding information register record
		InformationRegisters.ExchangeTransportSettings.AddRecord(RecordStructure);
		
		// Setting initial image creation date as the date of the first
   // successful synchronization
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", ApplicationInSaaS());
		RecordStructure.Insert("ActionOnExchange", Enums.ActionsOnExchange.DataExport);
		RecordStructure.Insert("EndDate", Parameters.InitialImageCreationDate);
		InformationRegisters.SuccessfulDataExchangeStates.AddRecord(RecordStructure);
		
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", ApplicationInSaaS());
		RecordStructure.Insert("ActionOnExchange", Enums.ActionsOnExchange.DataImport);
		RecordStructure.Insert("EndDate", Parameters.InitialImageCreationDate);
		InformationRegisters.SuccessfulDataExchangeStates.AddRecord(RecordStructure);
		
		// Default synchronization schedule setup.
		// Schedule disabled because the user password is not specified.
		ScheduledJob = ScheduledJobs.FindPredefined(Metadata.ScheduledJobs.DataSynchronizationWithWebApplication);
		ScheduledJob.Use = False;
		ScheduledJob.Schedule = DefaultDataSynchronizationSchedule();
		ScheduledJob.Write();
		
		// Creating infobase user and mapping it to the Users catalog item
		Roles = New Array;
		Roles.Add("FullAdministrator");
		Roles.Add("FullAccess");
		
		InfobaseUserDetails = New Structure;
		InfobaseUserDetails.Insert("Action",                 "Write");
		InfobaseUserDetails.Insert("Name",                   Parameters.OwnerName);
		InfobaseUserDetails.Insert("Roles",                  Roles);
		InfobaseUserDetails.Insert("StandardAuthentication", True);
		InfobaseUserDetails.Insert("ShowInList",             True);
		
		User = Catalogs.Users.GetRef(New UUID(Parameters.Owner)).GetObject();
		
		If User = Undefined Then
			Raise NStr("en = 'The user is not identified.
				|Possibly the Users catalog is not included in the standalone mode exchange plan.'");
		EndIf;
		
		SetUserPasswordMinLength(0);
		SetUserPasswordStrengthCheck(False);
		
		User.Internal = False;
		User.AdditionalProperties.Insert("InfobaseUserDetails", InfobaseUserDetails);
		User.Write();
		
		ExchangePlans.DeleteChangeRecords(ApplicationNodeSaaS.Ref);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(StandaloneWorkstationCreationEventLogMessageText(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

// For internal use
// 
Procedure ImportInitialImageData()
	
	InfobaseDirectory = CommonUseClientServer.FileInfobaseDirectory();
	
	InitialImageDataFileName = CommonUseClientServer.GetFullFileName(
		InfobaseDirectory,
		"data.xml");
	
	InitialImageDataFile = New File(InitialImageDataFileName);
	If Not InitialImageDataFile.Exist() Then
		Return; // Initial image data was successfully imported before
	EndIf;
	
	InitialImageData = New XMLReader;
	InitialImageData.OpenFile(InitialImageDataFileName);
	InitialImageData.Read();
	InitialImageData.Read();
	
	BeginTransaction();
	Try
		
		While CanReadXML(InitialImageData) Do
			
			DataItem = ReadXML(InitialImageData);
			DataItem.AdditionalProperties.Insert("InitialImageCreating");
			
			ItemReceive = DataItemReceive.Auto;
			StandardSubsystemsServer.OnReceiveDataFromMaster(DataItem, ItemReceive, False);
			
			If ItemReceive = DataItemReceive.Ignore Then
				Continue;
			EndIf;
			
			DataItem.DataExchange.Load = True;
			DataItem.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
			DataItem.Write();
			
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(StandaloneWorkstationCreationEventLogMessageText(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		
		InitialImageData = Undefined;
		Raise;
	EndTry;
	
	InitialImageData.Close();
	
	Try
		DeleteFiles(InitialImageDataFileName);
	Except
		WriteLogEvent(StandaloneWorkstationCreationEventLogMessageText(), EventLogLevel.Error,,,
			DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

// For internal use
// 
Function GetParametersFromInitialImage()
	
	XMLLine = Constants.SubordinateDIBNodeSettings.Get();
	
	If IsBlankString(XMLLine) Then
		Raise NStr("en = 'Standalone workstation settings were not transferred.
									|Cannot run the standalone workstation.'");
	EndIf;
	
	XMLReader = New XMLReader;
	XMLReader.SetString(XMLLine);
	
	XMLReader.Read(); // Parameters
	FormatVersion = XMLReader.GetAttribute("FormatVersion");
	
	XMLReader.Read(); // StandaloneWorkstationParameters
	
	Result = ReadDataToStructure(XMLReader);
	
	XMLReader.Close();
	
	Return Result;
EndFunction

// For internal use
// 
Function ReadDataToStructure(XMLReader)
	
	// Return value
	Result = New Structure;
	
	If XMLReader.NodeType <> XMLNodeType.StartElement Then
		Raise NStr("en = 'XML read error'");
	EndIf;
	
	XMLReader.Read();
	
	While XMLReader.NodeType <> XMLNodeType.EndElement Do
		
		Key = XMLReader.Name;
		
		Result.Insert(Key, ReadXML(XMLReader));
		
	EndDo;
	
	XMLReader.Read();
	
	Return Result;
EndFunction

// For internal use
// 
Function DataSynchronizationEventLogMessageText()
	
	Return NStr("en = 'Standalone mode.Data synchronization'", CommonUseClientServer.DefaultLanguageCode());
	
EndFunction

// Reads and sets the notification option about long standalone 
// workstation synchronization. 
// Parameters:
//         FlagValue      - Boolean   - flag value to be set
//         SettingDetails - Structure - stores the option description
//
// For internal use
//
Function LongSynchronizationQuestionSetupFlag(FlagValue = Undefined, SettingDetails = Undefined) Export
	SettingDetails = New Structure;
	
	SettingDetails.Insert("ObjectKey",    "ProgramSettings");
	SettingDetails.Insert("SettingsKey",  "ShowLongSynchronizationWarningSW");
	SettingDetails.Insert("Presentation", NStr("en = 'Show long synchronization warning'"));
	
	SettingsDescription = New SettingsDescription;
	FillPropertyValues(SettingsDescription, SettingDetails);
	
	If FlagValue = Undefined Then
		// Reading
		Return CommonUse.CommonSettingsStorageLoad(SettingsDescription.ObjectKey, SettingsDescription.SettingsKey, True);
	EndIf;
	
	// Writing
	CommonUse.CommonSettingsStorageSave(SettingsDescription.ObjectKey, SettingsDescription.SettingsKey, FlagValue, SettingsDescription);
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Handlers of conditional calls of other subsystems

// The function checks whether a passed object is included in the exception list.
Function MetadataObjectIsException(Val MetadataObject)
	
	// The InternalEventParameters constant belongs to the DIB initial image node but it must be checked without displaying service messages.
	If MetadataObject = Metadata.Constants.InternalEventParameters Then
		Return True;
	EndIf;
	
 // The MetadataObjectIDs catalog belongs to the DIB initial image node objects.
 // It is possible to update catalog attributes in subordinate DIB nodes
 // according to the metadata property values of the master node (you might
 // need this if any errors occur during the exchange).
 // The modifications are monitored in the BeforeWrite procedure, which is
 // located in the catalog object module.
	If MetadataObject = Metadata.Catalogs.MetadataObjectIDs Then
		Return True;
	EndIf;
	
	Return StandardSubsystemsServer.IsDIBModeInitialImageObject(MetadataObject);
	
EndFunction

#EndRegion
