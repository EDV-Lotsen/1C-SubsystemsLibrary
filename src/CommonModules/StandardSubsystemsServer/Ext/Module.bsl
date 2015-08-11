////////////////////////////////////////////////////////////////////////////////
// Base functionality subsystem.
//
//////////////////////////////////////////////////////////////////////////////// 

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Not interactive Infobase data update on library version change
// Obligatory Infobase update Entry point in Library.
//
Procedure ExecuteInfoBaseUpdate() Export
	
	InfoBaseUpdate.ExecuteUpdateIteration("StandardSubsystems", 
		LibVersion(), StandardSubsystemsOverridable.StandardSubsystemsUpdateHandlers());
	
EndProcedure

// The functions returns Subsystems library version number.
//
Function LibVersion() Export
	
	Return "2.0.1.15";
	
EndFunction

// Returns parameter structure required for this subsystem client script execution 
// on application start, that is in following еvent handlers
// - BeforeStart,
// - OnStart
//
// Important: when running the application, do not use cache reset commands of modules 
// that reuse return values because this can lead to unpredictable errors and unneeded 
// server calls. 
//
// Parameters:
// Parameters - structure - parameter structure.
//
// Returns:
// Boolean - False if further filling of parameters must be aborted.
//
Function AddClientParametersOnStart(Parameters) Export
	
	Parameters.Insert("DataSeparationEnabled", CommonUseCached.DataSeparationEnabled());
	
	Parameters.Insert("CanUseSeparatedData", CommonUseCached.CanUseSeparatedData());
	
	Parameters.Insert("IsSeparatedConfiguration", CommonUseCached.IsSeparatedConfiguration());
	Parameters.Insert("CanUpdatePlatformVersion", Users.InfoBaseUserWithFullAccess(,True));
	
	Parameters.Insert("SubsystemNames", StandardSubsystemsCached.SubsystemNames());
	
	CommonParameters = CommonUse.CommonBaseFunctionalityParameters();
	Parameters.Insert("LowestPlatformVersion", CommonParameters.LowestPlatformVersion);
	Parameters.Insert("MustExit",            CommonParameters.MustExit);
	
	If Parameters.RetrievedClientParameters <> Undefined
	   And Parameters.RetrievedClientParameters.Count() = 0 Then
	
		SetPrivilegedMode(True);
		ClientLaunchParameter = SessionParameters.ClientParametersAtServer.Get("LaunchParameter");
		If Find(Lower(ClientLaunchParameter), Lower("StartInfoBaseUpdate")) > 0 Then
			SetStartInfoBaseUpdate(True);
		EndIf;
		SetPrivilegedMode(False);
	EndIf;
	
	If Parameters.RetrievedClientParameters <> Undefined Then
		Parameters.Insert("InterfaceOptions", CommonUseCached.InterfaceOptions());
	EndIf;
	
	If Parameters.RetrievedClientParameters <> Undefined
	   And Not Parameters.RetrievedClientParameters.Property("ShowNotRecommendedPlatformVersion")
	   And ShowNotRecommendedPlatformVersion(Parameters) Then
		
		Parameters.Insert("ShowNotRecommendedPlatformVersion");
		StandardSubsystemsServerCall.HideDesktopOnStart();
		Return False;
	EndIf;
	
	ErrorDescription = InfobaseUpdateInternal.InfoBaseLockedForUpdate();
	If ValueIsFilled(ErrorDescription) Then
		Parameters.Insert("InfoBaseLockedForUpdate", ErrorDescription);
		Return False;
	EndIf;
	
	SetPrivilegedMode(True);
	If Parameters.RetrievedClientParameters <> Undefined
	   And Not Parameters.RetrievedClientParameters.Property("RestoreConnectionToMasterNode")
	   And Not CommonUseCached.DataSeparationEnabled()
	   And ExchangePlans.MasterNode() = Undefined
	   And ValueIsFilled(Constants.MasterNode.Get()) Then
		
		SetPrivilegedMode(False);
		Parameters.Insert("RestoreConnectionToMasterNode", Users.InfoBaseUserWithFullAccess());
		StandardSubsystemsServerCall.HideDesktopOnStart();
		Return False;
	EndIf;
	SetPrivilegedMode(False);
	
	If Parameters.RetrievedClientParameters <> Undefined
	   And Not (Parameters.DataSeparationEnabled And Not Parameters.CanUseSeparatedData)
	   And CommonUse.SubsystemExists("StandardSubsystems.ServiceMode") Then
		
		ServiceModeModule = CommonUse.CommonModule("ServiceMode");
		ErrorDescription = "";
		ServiceModeModule.LockDataAreaAtStartOnCheck(ErrorDescription);
		If ValueIsFilled(ErrorDescription) Then
			Parameters.Insert("DataAreaLocked", ErrorDescription);
			Return False;
		EndIf;
	EndIf;
	
	If InfobaseUpdateInternal.CheckUpdateObtainingLegalityRequired() Then
		Parameters.Insert("CheckUpdateObtainingLegality");
	EndIf;
	
	If Parameters.RetrievedClientParameters <> Undefined
	   And Not Parameters.RetrievedClientParameters.Property("RetryDataExchangeMessageImportBeforeStart")
	   And CommonUse.IsSubordinateDIBNode()
	   And CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
		
		DataExchangeServerCallModule = CommonUse.CommonModule("DataExchangeServerCall");
		If DataExchangeServerCallModule.RetryDataExchangeMessageImportBeforeStart() Then
			Parameters.Insert("RetryDataExchangeMessageImportBeforeStart");
			Try
				Parameters.Insert("ClientEventsHandlers", StandardSubsystemsCached.ProgramEventParameters(
					).EventHandlers.AtClient);
			Except
			EndTry;
			Return False;
		EndIf;
	EndIf;
	
	If Parameters.RetrievedClientParameters <> Undefined
	   And Not Parameters.RetrievedClientParameters.Property("ClientParametersUpdateRequired") Then
		
		If ClientParametersUpdateRequired() Then
			Parameters.Insert("ClientParametersUpdateRequired");
			Parameters.Insert("FileInfoBase", CommonUse.FileInfoBase());
			Return False;
		Else
			ConfirmApplicationParameterUpdate("*", "");
		EndIf;
	EndIf;
	
	Parameters.Insert("DetailedInformation", Metadata.DetailedInformation);
	
	Parameters.Insert("ClientEventsHandlers", StandardSubsystemsCached.ProgramEventParameters(
		).EventHandlers.AtClient);
	
	If InfobaseUpdateInternalServiceMode.SharedDataUpdateRequired() Then
		Parameters.Insert("SharedDataUpdateRequired");
	EndIf;
	
	Parameters.Insert("InterfaceOptions", CommonUseCached.InterfaceOptions());
	
	SafeModeInternal.AddClientParametersOnStart(Parameters);
	
	If Parameters.DataSeparationEnabled And Not Parameters.CanUseSeparatedData Then
		Return False;
	EndIf;
	
	If InfoBaseUpdate.InfoBaseUpdateRequired() Then
		Parameters.Insert("InfoBaseUpdateRequired");
		StandardSubsystemsServerCall.HideDesktopOnStart();
	EndIf;
	
	If Not Parameters.DataSeparationEnabled
		And CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
		
		DataExchangeServerModule = CommonUse.CommonModule("DataExchangeServer");
		If DataExchangeServerModule.LoadDataExchangeMessage() Then
			Parameters.Insert("LoadDataExchangeMessage");
		EndIf;
	EndIf;
	
	//If CommonUse.SubsystemExists("StandardSubsystems.ServiceMode.DataExchangeServiceMode") Then
	//	AutonomousOperationInternalModule = CommonUse.CommonModule("AutonomousOperationInternal");
	//	If AutonomousOperationInternalModule.ContinueAutonomousWorkplaceSetup(Parameters) Then
	//		Return False;
	//	EndIf;
	//EndIf;
	
	AuthorizationError = Users.AuthenticateCurrentUser();
	If AuthorizationError <> "" Then
		Parameters.Insert("AuthorizationError", AuthorizationError);
		Return False;
	EndIf;
	
	Parameters.Insert("ShowUpdateDetails", InfoBaseUpdate.ShowUpdateDetails());
	
	AddCommonClientParameters(Parameters);
	
	Return True;
	
	
EndFunction

// Fills parameter structure required for this subsystem client script execution.
//
//
// Parameters:
// Parameters - structure - parameter structure.
//
Procedure AddClientParameters(Parameters) Export
	
	Parameters.Insert("SubsystemNames", StandardSubsystemsCached.SubsystemNames());
	Parameters.Insert("CanUseSeparatedData", CommonUseCached.CanUseSeparatedData());
	Parameters.Insert("DataSeparationEnabled", CommonUseCached.DataSeparationEnabled());
	
	Parameters.Insert("InterfaceOptions", CommonUseCached.InterfaceOptions());
	
	AddCommonClientParameters(Parameters);
	
	Parameters.Insert("ConfigurationName",     Metadata.Name);
	Parameters.Insert("ConfigurationSynonym", Metadata.Synonym);
	Parameters.Insert("ConfigurationVersion",  Metadata.Version);
	Parameters.Insert("DetailedInformation", Metadata.DetailedInformation);
	Parameters.Insert("DefaultLanguageCode", Metadata.DefaultLanguage.LanguageCode);
	
	Parameters.Insert("AskConfirmationOnExit", AskConfirmationOnExit());
	
	Parameters.Insert("UserInfo", GetUserInfo());
	Parameters.Insert("COMConnectorName", CommonUse.COMConnectorName());
	
	SessionDate = CurrentSessionDate();
	UniversalSessionDate = ToUniversalTime(SessionDate, SessionTimeZone());
	Parameters.Insert("SessionTimeOffset", SessionDate); 
	Parameters.Insert("UniversalTimeOffset", UniversalSessionDate - SessionDate);
	
	SafeModeInternal.AddClientParameters(Parameters);
	
EndProcedure

// Internal use only.
Procedure AddCommonClientParameters(Parameters) 
	
	If Not Parameters.DataSeparationEnabled Or Parameters.CanUseSeparatedData Then
		
		SetPrivilegedMode(True);
		Parameters.Insert("AuthorizedUser", Users.AuthorizedUser());
		Parameters.Insert("UserPresentation", String(Parameters.AuthorizedUser));
		Parameters.Insert("SystemTitle", TrimAll(Constants.SystemTitle.Get()));
		SetPrivilegedMode(False);
		
	EndIf;
	
	Parameters.Insert("IsMasterNode", Not CommonUse.IsSubordinateDIBNode());
	Parameters.Insert("FileInfoBase", CommonUse.FileInfoBase());
	
	Parameters.Insert("DIBNodeConfigurationUpdateRequired",
		CommonUse.SubordinateDIBNodeConfigurationUpdateRequired());
	
	Parameters.Insert("IsBaseVersion", IsBaseVersion());
	
EndProcedure

// Internal use only.
Function IsBaseVersion() Export
	
	Return Find(Upper(Metadata.Name), "BASE") > 0;
	
EndFunction

// Internal use only.
Procedure SetStartInfoBaseUpdate(Start) Export
	
	CurrentParameters = New Map(SessionParameters.ClientParametersAtServer);
	
	If Start = True Then
		CurrentParameters.Insert("StartInfoBaseUpdate", True);
		
	ElsIf CurrentParameters.Get("StartInfoBaseUpdate") <> Undefined Then
		CurrentParameters.Delete("StartInfoBaseUpdate");
	EndIf;
	
	SessionParameters.ClientParametersAtServer = New FixedMap(CurrentParameters);
	
EndProcedure

// Internal use only.
Procedure ConfirmApplicationParameterUpdate(ConstantName, ParameterName) Export
	
	SetPrivilegedMode(True);
	
	SetPrivilegedMode(True);
	ClientParametersAtServer = New Map(SessionParameters.ClientParametersAtServer);
	
	AllUpdatedParameters = ClientParametersAtServer.Get("AllUpdatedClientParameters");
	If AllUpdatedParameters = Undefined Then
		AllUpdatedParameters = New Map;
		UpdatedParameters = New Map;
	Else
		UpdatedParameters = AllUpdatedParameters.Get(ConstantName);
		AllUpdatedParameters = New Map(AllUpdatedParameters);
		If UpdatedParameters = Undefined Then
			UpdatedParameters = New Map;
		Else
			UpdatedParameters = New Map(UpdatedParameters);
		EndIf;
	EndIf;
	UpdatedParameters.Insert(ParameterName, True);
	AllUpdatedParameters.Insert(ConstantName, New FixedMap(UpdatedParameters));
	
	ClientParametersAtServer.Insert("AllUpdatedClientParameters",
		New FixedMap(AllUpdatedParameters));
	
	SessionParameters.ClientParametersAtServer = New FixedMap(ClientParametersAtServer);
	
EndProcedure

// Internal use only.
Function ShowNotRecommendedPlatformVersion(Parameters)
	
	If Parameters.DataSeparationEnabled Then
		Return False;
	EndIf;
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("InfoBaseUserID", InfoBaseUsers.CurrentUser().UUID);
	
	Query.Text = 
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|WHERE
	|	ExternalUsers.InfoBaseUserID = &InfoBaseUserID";
	
	If Not Query.Execute().IsEmpty() Then
		Return False;
	EndIf;
	
	SystemInfo = New SystemInfo;
	Return CommonUseClientServer.CompareVersions(SystemInfo.AppVersion,
		Parameters.LowestPlatformVersion) < 0;
	
EndFunction

// Internal use only.
Function ClientParametersUpdateRequired(ExecuteImport = True) Export
	
	If CommonUseCached.DataSeparationEnabled() Then
		If Not CommonUseCached.CanUseSeparatedData()
			And InfoBaseUpdateInternal.SharedDataUpdateRequired() Then
			
			Return True;
		EndIf;
	Else
		If InfoBaseUpdate.InfoBaseUpdateRequired() Then
			Return True;
		EndIf;
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
		DataExchangeServerModule = CommonUse.CommonModule("DataExchangeServer");
		
		If DataExchangeServerModule.SubordinateDIBNodeSetup() Then
			ExecuteImport = False;
			Return True;
		EndIf;
	EndIf;
	
	Try
		UsersInternalCached.Parameters();
	Except
		ExecuteImport = False;
		Return True;
	EndTry;
	
	Return False;
	
EndFunction

// Returns version number name array that is supported by the SubsystemName subsystem.
//
// Parameters:
// SubsystemName - string - Subsystem name.
//
// Returns:
// String Array.
//
Function SupportedVersions(SubsystemName) Export
	
	VersionArray = Undefined;
	
	SupportedVersionStructure = New Structure;
	StandardSubsystemsOverridable.GetSupportedVersions(SupportedVersionStructure);
	
	SupportedVersionStructure.Property(SubsystemName, VersionArray);
	
	If VersionArray = Undefined Then
		Return CommonUse.ValueToXMLString(New Array);
	Else
		Return CommonUse.ValueToXMLString(VersionArray);
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Session initialization parameters
//

// Session initialization parameters.
// Parameters
// SessionParameterNames - Array, undefined if 
// there are session parameter names for initialization in the array
//
// Returns name array of set session parameters
// 
Function SetSessionParameters(SessionParameterNames) Export
	
	// All of session parameters require accessing the same data to initialization 
	// should be grouped and initialized at the same time to avoid their reinitialize.
	// Assigned parameter names are stored in the AssignedParameters array. 
	AssignedParameters = New Array;
	
	If SessionParameterNames = Undefined Then
		SessionParameters.ClientParametersAtServer = New FixedMap(New Map);
		
		BeforeStart();
		Return AssignedParameters;
	EndIf;
	
	If SessionParameterNames.Find("ClientParametersAtServer") <> Undefined Then
		SessionParameters.ClientParametersAtServer = New FixedMap(New Map);
		AssignedParameters.Add("ClientParametersAtServer");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
		DataExchangeServerModule = CommonUse.CommonModule("DataExchangeServer");
		Handlers = New Map;
		DataExchangeServerModule.SessionParameterSettingHandlersOnAdd(Handlers);
		ExecuteSetSessionParameterHandlers(SessionParameterNames, Handlers, AssignedParameters);
	EndIf;
	
	NotAssignedParameters = CommonUseClientServer.ReduceArray(SessionParameterNames, AssignedParameters);
	If NotAssignedParameters.Count() = 0 Then
		Return AssignedParameters;
	EndIf;
	
	Handlers = New Map;
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.BaseFunctionality\SessionParameterSettingHandlersOnAdd");
	
	For Each Handler In EventHandlers Do
		Handler.Module.SessionParameterSettingHandlersOnAdd(Handlers);
	EndDo;
	
	SelfEventHandlers = CommonUseOverridable.SessionParameterInitHandlers();
	For Each Handler In SelfEventHandlers Do
		Handlers.Insert(Handler.Key, Handler.Value);
	EndDo;
	
	SelfEventHandlers = New Map;
	CommonUseOverridable.SessionParameterSettingHandlersOnAdd(SelfEventHandlers);
	For Each Handler In SelfEventHandlers Do
		Handlers.Insert(Handler.Key, Handler.Value);
	EndDo;
	
	ExecuteSetSessionParameterHandlers(SessionParameterNames, Handlers, AssignedParameters);
	Return AssignedParameters;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Infobase update

// Adds update handlers required to this subsystem in the Handlers list. 
// 

// Parameters:
// Handlers - ValueTable - see InfoBaseUpdate.NewUpdateHandlerTable function for details. 
//
Procedure RegisterUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "1.1.3.9";
	Handler.Procedure = "StandardSubsystemsServer.SetConstantDontUseSeparationByDataAreas";
	Handler.SharedData = True;
	
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.Procedure = "Catalogs.MetadataObjectIDs.UpdateCatalogData";
	Handler.Priority = 999;
	Handler.SharedData = True;
	
	Processor = Handlers.Add();
	Processor.Version = "*";
	Processor.Procedure = "StandardSubsystemsServer.MarkVersionCacheRecordsObsolete";
	Processor.SharedData = True;
	
EndProcedure

// Sets the correct value to the DontUseSeparationByDataAreas constant
//
Procedure SetConstantDontUseSeparationByDataAreas() Export
	
	Constants.DontUseSeparationByDataAreas.Set(Not Constants.UseSeparationByDataAreas.Get());
	
EndProcedure

// Resets update date for all of cache version records, so
// all of cache records become obsolete.
//
Procedure MarkVersionCacheRecordsObsolete() Export
	
	BeginTransaction();
	
	DataLock = New DataLock;
	DataLock.Add("InformationRegister.ProgramInterfaceCache");
	DataLock.Lock();
	
	RecordSet = InformationRegisters.ProgramInterfaceCache.CreateRecordSet();
	RecordSet.Read();
	For Each Record In RecordSet Do
		Record.UpdateDate = Undefined;
	EndDo;
	RecordSet.Write();
	
	CommitTransaction();
	
EndProcedure

Function GetUserInfo()
	CurrentUser = InfoBaseUsers.CurrentUser();
	Return New Structure("Name, FullName, PasswordIsSet, StandardAuthentication, OSAuthentication",
		CurrentUser.Name, CurrentUser.FullName, CurrentUser.PasswordIsSet,
		CurrentUser.StandardAuthentication, CurrentUser.OSAuthentication);
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Program exit confirmation 

// Reads the program exit confirmation
// for the current user.
// 
// Returns:
// Boolean - setting value.
//
Function AskConfirmationOnExit() Export
	
	Result = CommonUse.CommonSettingsStorageLoad("UserCommonSettings", "AskConfirmationOnExit");
	If Result = Undefined Then
		Result = True;
		StandardSubsystemsServerCall.SaveExitConfirmationSettings(Result);
	EndIf;
	Return Result;
	
EndFunction

// Internal use only.
Function ApplicationParameters(ConstantName) Export
	
	Return StandardSubsystemsCached.ApplicationParameters(ConstantName);
	
EndFunction

// Internal use only.
Function ApplicationRunParameterErrorClarificationForDeveloper() Export
	
	Return Chars.LF + Chars.LF +
		NStr("en='For the developer: maybe it is required to update service data, that"
"causes application error. To update it you can:"
"- use external data processor Developer tools: Service data update;"
"- start the application with the following command line option:"
"  ""/C StartInfoBaseUpdate"";"
"- increase the configuration version, which will start the infobase"
"  data update next time when application starts.'");
	
EndFunction

// Internal use only.
Function EventHandlers() Export
	
	SubsystemDescriptions = StandardSubsystemsCached.SubsystemDescriptions();
	
	ClientEvents = New Array;
	ServerEvents = New Array;
	InternalClientEvents = New Array;
	InternalServerEvents = New Array;
	
	For Each Subsystem In SubsystemDescriptions.Order Do
		Description = SubsystemDescriptions.ByNames[Subsystem];
		
		If Not Description.AddEvents
		   And Not Description.AddInternalEvents Then
			
			Continue;
		EndIf;
		
		Module = CommonUse.CommonModule(
			Description.MainServerModule);
		
		If Description.Name = "StandardSubsystems" Then
			Module = StandardSubsystemsServer;
		EndIf;
		
		If Description.AddEvents Then
			Module.EventOnAdd(ClientEvents, ServerEvents);
		EndIf;
		
		If Description.AddInternalEvents Then
			Module.InternalEventOnAdd(InternalClientEvents, InternalServerEvents);
		EndIf;
	EndDo;
	
	CheckEventNamesUnique(ClientEvents);
	CheckEventNamesUnique(ServerEvents);
	CheckEventNamesUnique(InternalClientEvents);
	CheckEventNamesUnique(InternalServerEvents);
	
	ClientEventHandlersBySubsystems = New Map;
	ServerEventHandlersBySubsystems  = New Map;
	InternalClientEventHandlersBySubsystems = New Map;
	InternalServerEventHandlersBySubsystems  = New Map;
	
	RequiredClientEvents = New Map;
	RequiredServerEvents  = New Map;
	RequiredInternalClientEvents = New Map;
	RequiredInternalServerEvents  = New Map;
	
	For Each Subsystem In SubsystemDescriptions.Order Do
		
		ClientEventHandlersBySubsystems.Insert(Subsystem,
			EventHandlerTemplate(ClientEvents, RequiredClientEvents));
		
		ServerEventHandlersBySubsystems.Insert(Subsystem,
			EventHandlerTemplate(ServerEvents, RequiredServerEvents));
		
		InternalClientEventHandlersBySubsystems.Insert(Subsystem,
			EventHandlerTemplate(InternalClientEvents, RequiredInternalClientEvents));
		
		InternalServerEventHandlersBySubsystems.Insert(Subsystem,
			EventHandlerTemplate(InternalServerEvents, RequiredInternalServerEvents));
		
	EndDo;
	
	For Each Subsystem In SubsystemDescriptions.Order Do
		Description = SubsystemDescriptions.ByNames[Subsystem];
		
		If Not Description.AddEventHandlers
		   And Not Description.AddInternalEventHandlers Then
			
			Continue;
		EndIf;
		
		Module = CommonUse.CommonModule(
			Description.MainServerModule);
		
		If Description.Name = "StandardSubsystems" Then
			Module = StandardSubsystemsServer;
		EndIf;
		
		If Description.AddEventHandlers Then
			Module.EventHandlerOnAdd(
				ClientEventHandlersBySubsystems[Subsystem],
				ServerEventHandlersBySubsystems[Subsystem]);
		EndIf;
		
		If Description.AddInternalEventHandlers Then
			Module.InternalEventHandlersOnAdd(
				InternalClientEventHandlersBySubsystems[Subsystem],
				InternalServerEventHandlersBySubsystems[Subsystem]);
		EndIf;
	EndDo;
	
	RequiredEventsWithoutHandlers = New Array;
	
	AddRequiredEventsWithoutHandlers(RequiredEventsWithoutHandlers,
		RequiredClientEvents, ClientEventHandlersBySubsystems);
	
	AddRequiredEventsWithoutHandlers(RequiredEventsWithoutHandlers,
		RequiredServerEvents, ServerEventHandlersBySubsystems);
	
	AddRequiredEventsWithoutHandlers(RequiredEventsWithoutHandlers,
		RequiredInternalClientEvents, InternalClientEventHandlersBySubsystems);
	
	AddRequiredEventsWithoutHandlers(RequiredEventsWithoutHandlers,
		RequiredInternalServerEvents, InternalServerEventHandlersBySubsystems);
	
	If RequiredEventsWithoutHandlers.Count() > 0 Then
		EventName = NStr("en = 'Event handlers'", Metadata.DefaultLanguage.LanguageCode);
		
		Comment = NStr("en='Handlers for following required events are not defined:'")
			+ Chars.LF + StringFunctionsClientServer.StringFromSubstringArray(RequiredEventsWithoutHandlers, Chars.LF);
		
		WriteLogEvent(EventName, EventLogLevel.Error,,, Comment);
		Raise NStr("en='Handlers for required events are not defined."
"More details see in Event log.'");
	EndIf;
	
	AllEventHandlers = New Structure;
	AllEventHandlers.Insert("AtClient", New Structure);
	AllEventHandlers.Insert("AtServer", New Structure);
	
	AllEventHandlers.AtClient.Insert("EventHandlers", StandardEventHandlersDescription(
		SubsystemDescriptions, ClientEventHandlersBySubsystems));
	
	AllEventHandlers.AtServer.Insert("EventHandlers", StandardEventHandlersDescription(
		SubsystemDescriptions, ServerEventHandlersBySubsystems));
	
	AllEventHandlers.AtClient.Insert("InternalEventHandlers", StandardEventHandlersDescription(
		SubsystemDescriptions, InternalClientEventHandlersBySubsystems));
	
	AllEventHandlers.AtServer.Insert("InternalEventHandlers", StandardEventHandlersDescription(
		SubsystemDescriptions, InternalServerEventHandlersBySubsystems));
	
	Return New FixedStructure(AllEventHandlers);  
	
EndFunction

// Internal use only.
Procedure CheckIfApplicationRunParametersUpdated(ConstantName, ParameterNames = "", Cancel = Undefined) Export
	
	If ParameterNames <> "" Then
		UpdateRequired = False;
		
		If CommonUseCached.DataSeparationEnabled() Then
			UpdateRequired =
				InfoBaseUpdateInternal.SharedDataUpdateRequired();
		Else
			UpdateRequired =
				InfoBaseUpdate.InfoBaseUpdateRequired();
		EndIf;
		
		If UpdateRequired Then
			
			SetPrivilegedMode(True);
			AllUpdatedParameters = SessionParameters.ClientParametersAtServer.Get(
				"AllUpdatedApplicationParameters");
			SetPrivilegedMode(False);
			
			If AllUpdatedParameters <> Undefined Then
				If AllUpdatedParameters.Get("*") <> Undefined Then
					UpdateRequired = False;
				Else
					UpdatedParameters = AllUpdatedParameters.Get(ConstantName);
					If UpdatedParameters <> Undefined Then
						UpdateRequired = False;
						RequiredParameters = New Structure(ParameterNames);
						For Each KeyAndValue In RequiredParameters Do
							If UpdatedParameters.Get(KeyAndValue.Key) = Undefined Then
								UpdateRequired = True;
								Break;
							EndIf;
						EndDo;
					EndIf;
				EndIf;
			EndIf;
		EndIf;
		
		If UpdateRequired Then
			If Cancel <> Undefined Then
				Cancel = True;
				Return;
			EndIf;
			If CurrentRunMode() = Undefined Then
				Raise
					NStr("en='Unable log on the application because it is currently updated to the new version.'");
			Else
				Raise
					NStr("en='Invalid attempt to access not updated application parameters, for"
"example to session parameter:"
"- if trying to access from the form placed on the start page, check"
"  that this form calls CommonUse.OnCreateAtServer procedure;"
"- in other cases place the applied solution script execution after"
"  the application parameters update.'");
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

// Internal use only.
Procedure SetApplicationParameter(ConstantName, ParameterName, ParameterValue) Export
	
	DataLock = New DataLock;
	DataLockItem = DataLock.Add("Constant." + ConstantName);
	DataLockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		DataLock.Lock();
		
		Parameters = Constants[ConstantName].Get().Get();
		If TypeOf(Parameters) <> Type("Structure") Then
			Parameters = New Structure;
		EndIf;
		
		Parameters.Insert(ParameterName, ParameterValue);
		
		ValueManager = Constants[ConstantName].CreateValueManager();
		ValueManager.DataExchange.Load = True;
		ValueManager.DataExchange.Recipients.AutoFill = False;
		ValueManager.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
		ValueManager.Value = New ValueStorage(Parameters);
		ValueManager.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	RefreshReusableValues();
	
EndProcedure

// Internal use only.
Procedure CheckEventNamesUnique(Events)
	
	AllEvents    = New Map;
	
	For Each Event In Events Do
		
		If AllEvents.Get(Event) = Undefined Then
			AllEvents.Insert(Event, True);
		Else
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Error building the event list."
""
"%1 event"
"already added.'"),
				Event);
		EndIf;
		
	EndDo;
	
EndProcedure

// Internal use only.
Function EventHandlerTemplate(Events, RequiredEvents)
	
	EventHandlers  = New Map;
	
	For Each Event In Events Do
		
		If TypeOf(Event) = Type("String") Then 
			EventHandlers.Insert(Event, New Array);
			
		Else
			EventHandlers.Insert(Event.Name, New Array);
			If Event.Required Then
				If RequiredEvents.Get(Event.Name) = Undefined Then
					RequiredEvents.Insert(Event.Name, True);
				EndIf;
			EndIf;
		EndIf;
		
	EndDo;
	
	Return EventHandlers;
	
EndFunction

// Internal use only.
Procedure AddRequiredEventsWithoutHandlers(RequiredEventsWithoutHandlers,
                                                     RequiredEvents,
                                                     EventHandlersBySubsystems)
	
	For Each RequiredEvent In RequiredEvents Do
		
		HandlerFound = False;
		For Each SubsystemEventHandlers In EventHandlersBySubsystems Do
			
			If SubsystemEventHandlers.Value.Get(RequiredEvent.Key).Count() <> 0 Then
				HandlerFound = True;
				Break;
			EndIf;
			
		EndDo;
		
		If Not HandlerFound Then
			RequiredEventsWithoutHandlers.Add(RequiredEvent.Key);
		EndIf;
	EndDo;
	
EndProcedure

// Internal use only.
Function StandardEventHandlersDescription(SubsystemDescriptions, EventHandlersBySubsystems)
	
	EventHandlers  = New Map;
	HandlerModules  = New Map;
	HandlerEvents = New Map;
	
	For Each Subsystem In SubsystemDescriptions.Order Do
		SubsystemEventHandlers = EventHandlersBySubsystems[Subsystem];
		
		For Each KeyAndValue In SubsystemEventHandlers Do
			Event              = KeyAndValue.Key;
			HandlerDescriptions = KeyAndValue.Value;
			
			Handlers = EventHandlers[Event];
			If Handlers = Undefined Then
				Handlers = New Array;
				EventHandlers.Insert(Event, Handlers);
				HandlerModules.Insert(Event, New Map);
			EndIf;
			
			For Each HandlerDescription In HandlerDescriptions Do
				If TypeOf(HandlerDescription) = Type("Structure") Then
					Handler = HandlerDescription;
				Else
					Handler = New Structure;
					Handler.Insert("Module", HandlerDescription);
				EndIf;
				If Not Handler.Property("Version") Then
					Handler.Insert("Version", "");
				EndIf;
				Handler.Insert("Subsystem", Subsystem);
				
				If TypeOf(Handler.Module) <> Type("String")
				 Or Not ValueIsFilled(Handler.Module) Then
					
					Raise StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en='Error preparing handlers of the following event:"
"%1."
""
"Error in %2 module name.'"),
						Event,
						Handler.Module);
				EndIf;
				
				If HandlerModules[Event].Get(Handler.Module) = Undefined Then
					HandlerModules[Event].Insert(Handler.Module, True);
				Else
					Raise StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en='Error preparing handlers of the following event:"
"%1."
""
"%2 module already added.'"),
						Event,
						Handler.Module);
				EndIf;
				Handlers.Add(New FixedStructure(Handler));
				
				ProcedureName = Mid(Event, Find(Event, "\") + 1);
				HandlerName = Handler.Module + "." + ProcedureName;
				
				If HandlerEvents[HandlerName] = Undefined Then
					HandlerEvents.Insert(HandlerName, Event);
				Else
					Raise StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en='Error preparing handlers of the following event:"
"%1."
""
"%2 handler already added for %3 event.'"),
						Event,
						HandlerName,
						HandlerEvents[HandlerName]);
				EndIf;
			EndDo;
		EndDo;
	EndDo;
	
	For Each KeyAndValue In EventHandlers Do
		EventHandlers[KeyAndValue.Key] = New FixedArray(KeyAndValue.Value);
	EndDo;
	
	Return New FixedMap(EventHandlers);
	
EndFunction

// Internal use only.
Procedure BeforeStart()
	
	If Metadata.ScriptVariant <> Metadata.ObjectProperties.ScriptVariant.English Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='%1 variant of script not supported."
"Please use %2 variant of script.'"),
			Metadata.ScriptVariant,
			Metadata.ObjectProperties.ScriptVariant.English);
	EndIf;
		
	SystemInfo = New SystemInfo;
	If CommonUseClientServer.CompareVersions(SystemInfo.AppVersion, "8.3.5.1119") < 0 Then
		Raise NStr("en='To start the application 1C:Enterprise platform of 8.3.5.1119 or higher required.'");
	EndIf;
	
	Modes = Metadata.ObjectProperties.CompatibilityMode;
	CurrentMode = Metadata.CompatibilityMode;
	
	If CurrentMode = Modes.DontUse Then
		InaccessibleMode = "";
	ElsIf CurrentMode = Modes.Version8_1 Then
		InaccessibleMode = "8.1"
	ElsIf CurrentMode = Modes.Version8_2_13 Then
		InaccessibleMode = "8.2.13"
	ElsIf CurrentMode = Modes.Version8_2_16 Then
		InaccessibleMode = "8.2.16";
	ElsIf CurrentMode = Modes.Version8_3_1 Then
		InaccessibleMode = "8.3.1";
	ElsIf CurrentMode = Modes.Version8_3_2 Then
		InaccessibleMode = "8.3.2";
	ElsIf CurrentMode = Modes.Version8_3_3 Then
		InaccessibleMode = "8.3.3";
	ElsIf CurrentMode = Modes.Version8_3_4 Then
		InaccessibleMode = "8.3.4";
	Else
		InaccessibleMode = "";
	EndIf;
	
	If ValueIsFilled(InaccessibleMode) Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en=""The compatibility mode with 1C:Enterprise platform of %1 version not supported."
"To start, set compatibility mode with 1C:Enterprise platform version 8.3.5 or Don't use."""),
			InaccessibleMode);
	EndIf;
	
	If IsBlankString(Metadata.Version) Then
		Raise NStr("en='The Version configuration property not filled.'");
	Else
		Try
			ZeroVersion = CommonUseClientServer.CompareVersions(Metadata.Version, "0.0.0.0") = 0;
		Except
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Invalid format of value of the Version configuration property."
"Current value: %1."
"The correct format example: ""2.1.3.70"".'"),
				Metadata.Version);
		EndTry;
		If ZeroVersion Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Invalid value of the Version configuration property."
"Current value: %1."
"Version can not be zero.'"),
				Metadata.Version);
		EndIf;
	EndIf;
	
	If Metadata.DefaultRoles.Count() <> 2
	 Or Not Metadata.DefaultRoles.Contains(Metadata.Roles.FullAdministrator)
	 Or Not Metadata.DefaultRoles.Contains(Metadata.Roles.FullAccess) Then
		Raise
			NStr("en='In the MainRoles property of the configuration standard roles FullAdministrator and FullAccess are not listed or there are other roles which should not be included in MainRoles.'");
	EndIf;
	
	If Not ValueIsFilled(InfoBaseUsers.CurrentUser().Name)
	   And (Not CommonUseCached.DataSeparationEnabled()
	      Or Not CommonUseCached.CanUseSeparatedData())
	   And InfoBaseUpdate.InfoBaseVersion("StandardSubsystems",
	       CommonUseCached.DataSeparationEnabled()) = "0.0.0.0" Then
		
		UsersInternal.SetInitialSettings("");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ServiceMode") Then
		ServiceModeModule = CommonUse.CommonModule("ServiceMode");
		ServiceModeModule.EnablingDataSeparationSafeModeOnCheck();
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ServiceMode.DataAreaBackup") Then
		DataAreaBackupModule = CommonUse.CommonModule("DataAreaBackup");
		DataAreaBackupModule.SetUserActiveInDataAreaFlag();
	EndIf;
	
EndProcedure

// Internal use only.
Procedure ExecuteSetSessionParameterHandlers(SessionParameterNames, Handlers, AssignedParameters)
	
	Var MessageText;
	
	SafeMode.CanExecuteSessionParameterSettingHandlers();
	
	SessionParameterKeys = New Array;
	
	For Each Handler In Handlers Do
		If Find(Handler.Key, "*") > 0 Then
			KeyParameter = TrimAll(Handler.Key);
			SessionParameterKeys.Add(Left(KeyParameter, StrLen(KeyParameter)-1));
		EndIf;
	EndDo;
	
	For Each ParameterName In SessionParameterNames Do
		If AssignedParameters.Find(ParameterName) <> Undefined Then
			Continue;
		EndIf;
		Handler = Handlers.Get(ParameterName);
		If Handler <> Undefined Then
			
			HandlerParameters = New Array();
			HandlerParameters.Add(ParameterName);
			HandlerParameters.Add(AssignedParameters);
			SafeMode.ExecuteConfigurationMethod(Handler, HandlerParameters);
			Continue;
			
		EndIf;
		For Each ParameterKeyName In SessionParameterKeys Do
			If Left(ParameterName, StrLen(ParameterKeyName)) = ParameterKeyName Then
				
				Handler = Handlers.Get(ParameterKeyName+"*");
				HandlerParameters = New Array();
				HandlerParameters.Add(ParameterName);
				HandlerParameters.Add(AssignedParameters);
				SafeMode.ExecuteConfigurationMethod(Handler, HandlerParameters);
				
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

// Internal use only.
Procedure InternalEventOnAdd(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS.
	
	BaseFunctionalityInternalEventOnAdd(ClientEvents, ServerEvents);
	SafeModeInternal.InternalEventOnAdd(ClientEvents, ServerEvents);
	DataProcessors.MarkedObjectDeletion.InternalEventOnAdd(ClientEvents, ServerEvents);
	
	If CommonUse.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		Module = CommonUse.CommonModule("BusinessProcessesAndTasksServer");
		Module.InternalEventOnAdd(ClientEvents, ServerEvents);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ReportOptions") Then
		Module = CommonUse.CommonModule("ReportOptions");
		Module.InternalEventOnAdd(ClientEvents, ServerEvents);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		Module = CommonUse.CommonModule("AdditionalReportsAndDataProcessors");
		Module.InternalEventOnAdd(ClientEvents, ServerEvents);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.UserSessions") Then
		Module = CommonUse.CommonModule("InfoBaseConnections");
		Module.InternalEventOnAdd(ClientEvents, ServerEvents);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.CalendarSchedules") Then
		Module = CommonUse.CommonModule("CalendarSchedules");
		Module.InternalEventOnAdd(ClientEvents, ServerEvents);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.UserReminders") Then
		Module = CommonUse.CommonModule("UserReminderService");
		Module.InternalEventOnAdd(ClientEvents, ServerEvents);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
		Module = CommonUse.CommonModule("DataExchangeServer");
		Module.InternalEventOnAdd(ClientEvents, ServerEvents);
	EndIf;
	
	InfoBaseUpdateInternal.InternalEventOnAdd(ClientEvents, ServerEvents);
	
	UsersInternal.InternalEventOnAdd(ClientEvents, ServerEvents);
	
	If CommonUse.SubsystemExists("StandardSubsystems.AttachedFiles") Then
		Module = CommonUse.CommonModule("AttachedFilesUtility");
		Module.InternalEventOnAdd(ClientEvents, ServerEvents);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ServiceMode") Then
		Module = CommonUse.CommonModule("ServiceMode");
		Module.InternalEventOnAdd(ClientEvents, ServerEvents);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ServiceMode.MessageExchange") Then
		Module = CommonUse.CommonModule("MessageExchange");
		Module.InternalEventOnAdd(ClientEvents, ServerEvents);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ServiceMode.JobQueue") Then
		Module = CommonUse.CommonModule("JobQueueInternal");
		Module.InternalEventOnAdd(ClientEvents, ServerEvents);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ServiceMode.SuppliedData") Then
		Module = CommonUse.CommonModule("SuppliedData");
		Module.InternalEventOnAdd(ClientEvents, ServerEvents);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.CurrentAffairs") Then
		Module = CommonUse.CommonModule("CurrentAffairsService");
		Module.InternalEventOnAdd(ClientEvents, ServerEvents);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		Module = CommonUse.CommonModule("AccessControlService");
		Module.InternalEventOnAdd(ClientEvents, ServerEvents);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.FileFunctions") Then
		Module = CommonUse.CommonModule("FileUtilityFunctions");
		Module.InternalEventOnAdd(ClientEvents, ServerEvents);
	EndIf;
	
EndProcedure

// Internal use only.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	BaseFunctionalityInternalEventHandlerOnAdd(ClientHandlers, ServerHandlers);
	SafeModeInternal.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	
	If CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		Module = CommonUse.CommonModule("AddressClassifier");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.EventLogStatistics") Then
		Module = CommonUse.CommonModule("AnalysisOfLogUtility");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.Questioning") Then
		Module = CommonUse.CommonModule("Questioning");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.Banks") Then
		Module = CommonUse.CommonModule("BankOperations");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		Module = CommonUse.CommonModule("BusinessProcessesAndTasksServer");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.CurrencyRates") Then
		Module = CommonUse.CommonModule("ExchangeRateOperations");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ReportOptions") Then
		Module = CommonUse.CommonModule("ReportOptions");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.Interactions") Then
		Module = CommonUse.CommonModule("Interactions");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
		Module = CommonUse.CommonModule("EmailManagement");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ObjectVersioning") Then
		Module = CommonUse.CommonModule("ObjectVersioning");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.WorkSchedules") Then
		Module = CommonUse.CommonModule("WorkSchedules");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.EditProhibitionDates") Then
		Module = CommonUse.CommonModule("EditProhibitionDatesService");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		Module = CommonUse.CommonModule("AdditionalReportsAndDataProcessors");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
		Module = CommonUse.CommonModule("AdditionalReportsAndProcessingUtilityInSafeMode");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.UserSessions") Then
		Module = CommonUse.CommonModule("InfoBaseConnections");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.UserNotes") Then
		Module = CommonUse.CommonModule("UserNotesService");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.InformationOnStart") Then
		Module = CommonUse.CommonModule("InformationOnStart");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.CalendarSchedules") Then
		Module = CommonUse.CommonModule("CalendarSchedules");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ContactInformation") Then
		Module = CommonUse.CommonModule("ContactInformationManagement");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.DynamicConfigurationUpdateControl") Then
		Module = CommonUse.CommonModule("ControlOfDynamicUpdateConfigurationUtility");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.UserReminders") Then
		Module = CommonUse.CommonModule("UserReminderService");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	//If CommonUse.SubsystemExists("StandardSubsystems.InfoBaseVersionUpdate") Then
	Module = CommonUse.CommonModule("InfoBaseUpdateInternal");
	Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	//EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
		Module = CommonUse.CommonModule("DataExchangeServer");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then
		Module = CommonUse.CommonModule("ConfigurationUpdate");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.Companies") Then
		Module = CommonUse.CommonModule("CompaniesInternal");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SendingSMS") Then
		Module = CommonUse.CommonModule("SendingSMS");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.PerformanceEstimation") Then
		Module = CommonUse.CommonModule("PerformanceAssessmentService");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.Print") Then
		Module = CommonUse.CommonModule("PrintManagement");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.FullTextSearch") Then
		Module = CommonUse.CommonModule("FullTextSearchServer");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		Module = CommonUse.CommonModule("GetFilesFromInternet");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.Users") Then
		Module = CommonUse.CommonModule("UsersInternal");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.AttachedFiles") Then
		Module = CommonUse.CommonModule("AttachedFilesUtility");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ServiceMode") Then
		Module = CommonUse.CommonModule("ServiceMode");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ServiceMode.AddressClassifier") Then
		Module = CommonUse.CommonModule("AddressCodesForServiceServiceMode");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ServiceMode.BanksServiceMode") Then
		Module = CommonUse.CommonModule("BanksServiceMode");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ServiceMode.CurrenciesServiceMode") Then
		Module = CommonUse.CommonModule("ExchangeRatesServiceMode");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ServiceMode.CalendarSchedulesServiceMode") Then
		Module = CommonUse.CommonModule("CalendarSchedulesServiceMode");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ServiceMode.DataExchangeServiceMode") Then
		Module = CommonUse.CommonModule("DataExchangeServiceMode");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ServiceMode.MessageExchange") Then
		Module = CommonUse.CommonModule("MessageExchange");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ServiceMode.InfoBaseVersionUpdateServiceMode") Then
		Module = CommonUse.CommonModule("InfobaseUpdateInternalServiceMode");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ServiceMode.JobQueue") Then
		
		Module = CommonUse.CommonModule("JobQueueInternal");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
		
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ServiceMode.SuppliedData") Then
		Module = CommonUse.CommonModule("SuppliedData");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ServiceMode.DataAreaBackup") Then
		Module = CommonUse.CommonModule("DataAreaBackup");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ServiceMode.AccessManagementServiceMode") Then
		Module = CommonUse.CommonModule("AccessControlServiceInServiceModel");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ServiceMode.FileFunctionsServiceMode") Then
		Module = CommonUse.CommonModule("FileUtilityFunctionsInServiceModel");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.FileOperations") Then
		Module = CommonUse.CommonModule("FileManagementUtility");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ReportMailing") Then
		Module = CommonUse.CommonModule("ReportMailing");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ScheduledJobs") Then
		Module = CommonUse.CommonModule("ScheduledJobsInternal");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.InfoBaseBackup") Then
		Module = CommonUse.CommonModule("InfoBaseBackupServer");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("Property StandardSubsystems.name") Then
		Module = CommonUse.CommonModule("ControlPropertiesOfService");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		Module = CommonUse.CommonModule("AccessControlService");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.TotalsAndAggregatesManagement") Then
		Module = CommonUse.CommonModule("ControlTotalsAndAggregatesBusiness");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.FileFunctions") Then
		Module = CommonUse.CommonModule("FileUtilityFunctions");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ElectronicSignature") Then
		Module = CommonUse.CommonModule("ElectronicSignature");
		Module.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	EndIf;
	
EndProcedure

// Internal use only.
Procedure BaseFunctionalityInternalEventOnAdd(ClientEvents, ServerEvents) Export
	
	// CLIENT HANDLERS.
	
	ClientEvents.Add(
		"StandardSubsystems.BaseFunctionality\BeforeStart");
	
	ClientEvents.Add(
		"StandardSubsystems.BaseFunctionality\OnStart");
	
	ClientEvents.Add(
		"StandardSubsystems.BaseFunctionality\AfterStart");
	
	ClientEvents.Add(
		"StandardSubsystems.BaseFunctionality\LaunchParametersOnProcess");
	
	ClientEvents.Add(
		"StandardSubsystems.BaseFunctionality\BeforeExit");
	
	ClientEvents.Add(
		"StandardSubsystems.BaseFunctionality\ExitWarningListOnGet");
	
	// SERVER HANDLERS.
	
	ServerEvents.Add(
		"StandardSubsystems.BaseFunctionality\SessionParameterSettingHandlersOnAdd");
	
	ServerEvents.Add(
		"StandardSubsystems.BaseFunctionality\ReferenceSearchExceptionOnAdd");
	
	ServerEvents.Add(
		"StandardSubsystems.BaseFunctionality\SubjectPresentationOnSet");
	
	ServerEvents.Add(
		"StandardSubsystems.BaseFunctionality\RenamedMetadataObjectsOnAdd");
	
	ServerEvents.Add(
		"StandardSubsystems.BaseFunctionality\ClientParametersOnAddOnStart");
	
	ServerEvents.Add(
		"StandardSubsystems.BaseFunctionality\ClientParametersOnAdd");
	
	ServerEvents.Add(
		"StandardSubsystems.BaseFunctionality\ClientParametersOnAddOnExit");
	
	ServerEvents.Add(
		"StandardSubsystems.BaseFunctionality\OnEnableSeparationByDataAreas");
	
	ServerEvents.Add("StandardSubsystems.BaseFunctionality\NotUniquePredefinedItemOnFind");
	
	ServerEvents.Add("StandardSubsystems.BaseFunctionality\OnSendDataToSlave");
	
	ServerEvents.Add("StandardSubsystems.BaseFunctionality\OnSendDataToMaster");
	
	ServerEvents.Add("StandardSubsystems.BaseFunctionality\OnReceiveDataFromSlave");
	
	ServerEvents.Add("StandardSubsystems.BaseFunctionality\OnReceiveDataFromMaster");
	
	ServerEvents.Add("StandardSubsystems.BaseFunctionality\AfterReceiveDataFromSubordinate");
	
	ServerEvents.Add("StandardSubsystems.BaseFunctionality\AfterReceiveDataFromMaster");
	
	ServerEvents.Add("StandardSubsystems.BaseFunctionality\AfterSendDataToMaster");
	
	ServerEvents.Add("StandardSubsystems.BaseFunctionality\AfterSendDataToSubordinate");
	
	ServerEvents.Add("StandardSubsystems.BaseFunctionality\SupportedInterfaceVersionsOnDefine");
	
	ServerEvents.Add("StandardSubsystems.BaseFunctionality\StandardSubsystemClientLogicParametersOnAddOnExit");
	
	ServerEvents.Add("StandardSubsystems.BaseFunctionality\StandardSubsystemClientLogicParametersOnAddOnStart");
	
	ServerEvents.Add("StandardSubsystems.BaseFunctionality\StandardSubsystemClientLogicParametersOnAdd");
	
	ServerEvents.Add("StandardSubsystems.BaseFunctionality\RequiredExchangePlanObjectOnReceive");
	
	ServerEvents.Add("StandardSubsystems.BaseFunctionality\ExceptionExchangePlanObjectOnReceive");
	
	ServerEvents.Add("StandardSubsystems.BaseFunctionality\ExchangePlanInitialImageObjectsOnGet");
	
EndProcedure

// Internal use only.
Procedure BaseFunctionalityInternalEventHandlerOnAdd(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS.
	
	ServerHandlers[
		"StandardSubsystems.BaseFunctionality\StandardSubsystemClientLogicParametersOnAdd"].Add(
		"StandardSubsystemsServer");
	
	ServerHandlers["StandardSubsystems.InfoBaseVersionUpdate\UpdateHandlersOnAdd"].Add(
		"StandardSubsystemsServer");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\RequiredExchangePlanObjectOnReceive"].Add(
		"StandardSubsystemsServer");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\ExceptionExchangePlanObjectOnReceive"].Add(
		"StandardSubsystemsServer");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\ExchangePlanInitialImageObjectsOnGet"].Add(
		"StandardSubsystemsServer");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\RenamedMetadataObjectsOnAdd"].Add(
		"StandardSubsystemsServer");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\PermissionsToAccessExternalResourcesOnFill"].Add(
		"StandardSubsystemsServer");
	
	//ServerHandlers["StandardSubsystems.ReportOptions\ReportOptionsOnSetup"].Add(
	//	"StandardSubsystemsServer");
	
	If CommonUse.SubsystemExists("ServiceTechnology.DataImportExport") Then
		ServerHandlers[
			"ServiceTechnology.DataImportExport\SharedDataTypesSupportingReferenceMatchingOnImportOnFill"].Add(
				"StandardSubsystemsServer");
	EndIf;
	
EndProcedure

// Internal use only.
Procedure StandardSubsystemClientLogicParametersOnAdd(Parameters) Export
	
	AddClientParameters(Parameters);
	
EndProcedure
