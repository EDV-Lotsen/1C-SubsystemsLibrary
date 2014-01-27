////////////////////////////////////////////////////////////////////////////////
// Base functionality subsystem.
//
//////////////////////////////////////////////////////////////////////////////// 

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Not interactive infobase update on library version change
// Obligatory infobase update Entry point in library.
//
Procedure ExecuteInfoBaseUpdate() Export
	
	InfoBaseUpdate.ExecuteUpdateIteration("StandardSubsystems", 
		LibVersion(), StandardSubsystemsOverridable.StandardSubsystemsUpdateHandlers());
	
EndProcedure

// The functions returns Subsystems library version number.
//
Function LibVersion() Export
	
	Return "2.0.1.17";
	
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
	
	Parameters.Insert("AuthorizationError", Users.AuthenticateCurrentUser());
	If ValueIsFilled(Parameters.AuthorizationError) Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

// Fills parameter structure required for this subsystem client script execution.
//
//
// Parameters:
// Parameters - structure - parameter structure.
//
Procedure AddClientParameters(Parameters) Export
	
	Try
		CurrentUser = SessionParameters.CurrentUser;
	Except
	EndTry;
	
	Parameters.Insert("InfoBaseLockedForUpdate", 
		InfoBaseUpdate.CantUpdateInfoBase());
	Parameters.Insert("InfoBaseUpdateRequired", 
		InfoBaseUpdate.InfoBaseUpdateRequired());
	Parameters.Insert("AuthorizedUser", Users.AuthorizedUser());
	Parameters.Insert("IsBaseConfigurationVersion", StandardSubsystemsOverridable.IsBaseConfigurationVersion());
	
	SetPrivilegedMode(True);
	Parameters.Insert("ApplicationCaption", TrimAll(Constants.SystemTitle.Get()));
	SetPrivilegedMode(False);
	Parameters.Insert("ConfigurationName", Metadata.Name);
	Parameters.Insert("ConfigurationSynonym", Metadata.Synonym);
	Parameters.Insert("ConfigurationVersion", Metadata.Version);
	Parameters.Insert("DetailedInformation", Metadata.DetailedInformation);
	Parameters.Insert("FileInfoBase", CommonUse.FileInfoBase());
	Parameters.Insert("AskConfirmationOnExit", AskConfirmationOnExit());
	Parameters.Insert("CurrentUser", Users.CurrentUser());
	// Parameters for external сonnections of users
	Parameters.Insert("UserInfo", GetUserInfo());
	Parameters.Insert("COMConnectorName", CommonUse.COMConnectorName());
	
	Parameters.Insert("SessionTimeOffset", CurrentSessionDate()); // Writing server time to replace it with client time offset in future.
	StandardSubsystemsOverridable.AddClientParametersServiceMode(Parameters);
	
EndProcedure

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
Function SessionParametersSetting(SessionParameterNames) Export
	
	Var MessageText;
	
	// All session parameters require accessing the same data to initialization 
	// should be grouped and initialized at the same time to avoid their reinitialize.
	// Specified parameter names are stored in the SpecifiedParameters array. 
	SpecifiedParameters = New Array;
	
	If SessionParameterNames = Undefined Then
		Return SpecifiedParameters;
	EndIf;
	
	Handlers = StandardSubsystemsOverridable.SubsystemsLibrarySessionParameterInitHandlers();
	CustomHandlers = CommonUseOverridable.SessionParameterInitHandlers();
	
	For Each Record In CustomHandlers Do
		Handlers.Insert(Record.Key, Record.Value);
	EndDo;
	
	// Array contains session parameter keys. 
	// Keys are specified as a first word of parameter name and the "*" symbol
	SessionParameterKeys = New Array;
	
	For Each Record In Handlers Do
		If Find(Record.Key, "*") > 0 Then
			ParameterKey = TrimAll(Record.Key);
			SessionParameterKeys.Add(Left(ParameterKey, StrLen(ParameterKey)-1));
		EndIf;
	EndDo;
	
	For Each ParameterName In SessionParameterNames Do
		If SpecifiedParameters.Find(ParameterName) <> Undefined Then
			Continue;
		EndIf;
		Handler = Handlers.Get(ParameterName);
		If Handler <> Undefined Then
			If Not CommonUse.CheckExportProcedureName(Handler, MessageText) Then
				Raise MessageText;
			EndIf;
			
			Execute Handler + "(ParameterName, SpecifiedParameters)";
			Continue;
		EndIf;
		For Each ParameterKeyName In SessionParameterKeys Do
			If Left(ParameterName, StrLen(ParameterKeyName)) = ParameterKeyName Then
				Handler = Handlers.Get(ParameterKeyName+"*");
				If Not CommonUse.CheckExportProcedureName(Handler, MessageText) Then
					Raise MessageText;
				EndIf;
				Execute Handler + "(ParameterName, SpecifiedParameters)";
			EndIf;
		EndDo;
	EndDo;
	
	Return SpecifiedParameters;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Infobase update

// Adds update handlers required by this subsystem in the Handlers list. 
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