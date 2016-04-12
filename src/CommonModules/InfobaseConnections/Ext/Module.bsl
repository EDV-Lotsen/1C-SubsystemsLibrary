////////////////////////////////////////////////////////////////////////////////
// User sessions subsystem.
//
////////////////////////////////////////////////////////////////////////////////
#Region Interface
////////////////////////////////////////////////////////////////////////////////
// Locking the infobase and terminating connections.
// Sets the infobase connection lock.
// If this function is called from a session with set separator values, it sets the data area session lock.
//
// Parameters
//  MessageText - String - text to be used in the error message displayed 
//                          upon attempt to connect to the locked infobase.
//
//  KeyCode - String - string to be added to "/uc" command-line parameter 
//                     or to "uc" connection-string parameter in order to 
//                     establish connection to the infobase regardless of the lock.
//                     Cannot be used for data area session locks.
//
// Returns:
//   Boolean - True if the lock is set successfully.
//             False if the lock cannot be set due to insufficient rights.
//
Function SetConnectionLock(Val MessageText = "",
	Val KeyCode = "KeyCode") Export
	
	If CommonUseCached.DataSeparationEnabled() And CommonUseCached.CanUseSeparatedData() Then
		
		If Not Users.InfobaseUserWithFullAccess() Then
			Return False;
		EndIf;
		
		DataLock = NewConnectionLockParameters();
		DataLock.Use = True;
		DataLock.Begin = CurrentSessionDate();
		DataLock.Message = GenerateLockMessage(MessageText, KeyCode);
		DataLock.Exclusive = Users.InfobaseUserWithFullAccess(, True);
		SetDataAreaSessionLock(DataLock);
		Return True;
	Else
		If Not Users.InfobaseUserWithFullAccess(, True) Then
			Return False;
		EndIf;
		
		DataLock = New SessionsLock;
		DataLock.Use = True;
		DataLock.Begin = CurrentSessionDate();
		DataLock.KeyCode = KeyCode;
		DataLock.Message = GenerateLockMessage(MessageText, KeyCode);
		SetSessionsLock(DataLock);
		Return True;
	EndIf;
	
EndFunction
// Determines whether connection lock is set for the infobase configuration batch update.
//
// Parameters:
//   LockParameters - Structure - session lock parameters. 
//                                For detailed description, see SessionLockParameterStructure().
//
// Returns:
//   Boolean - True if the lock is set, False otherwise.
//
Function ConnectionsLocked(LockParameters = Undefined) Export
	
	If LockParameters = Undefined Then
		LockParameters = SessionLockParameterStructure();
	EndIf;
	
	Return LockParameters.ConnectionsLocked;
		
EndFunction
// Gets the infobase connection lock parameters to be used at client side.
//
// Parameters:
//   GetSessionCount - Boolean   - if True, the SessionCount field is filled in the returned structure.
//   LockParameters  - Structure - session lock parameters. 
//                                 For detailed description, see SessionLockParameterStructure().
//
// Returns:
//   Structure - containing the following properties:
//     * Use                - Boolean - True if the lock is set, False otherwise.
//     * Beginning          - Date    - lock beginning date.
//     * End                - Date    - lock end date.
//     * Message            - String  - user message.
//     * SessionTerminationTimeout - Number - timeout in seconds.
//     * SessionCount       - Number  - 0 if GetSessionCount = False.
//     * CurrentSessionDate - Date    - current session date.
//
Function SessionLockParameters(Val GetSessionCount = False, LockParameters = Undefined) Export
	
	If LockParameters = Undefined Then
		LockParameters = SessionLockParameterStructure();
	EndIf;
	
	If LockParameters.InfobaseConnectionLockSetForDate Then
		CurrentMode = LockParameters.CurrentInfobaseMode;
	ElsIf LockParameters.DataAreaConnectionLockSetForDate Then
		CurrentMode = LockParameters.CurrentDataAreaMode;
	ElsIf LockParameters.CurrentInfobaseMode.Use Then
		CurrentMode = LockParameters.CurrentInfobaseMode;
	Else
		CurrentMode = LockParameters.CurrentDataAreaMode;
	EndIf;
	
	SetPrivilegedMode(True);
	Return New Structure(
		"Use,Begin,End,Message,SessionTerminationTimeout,SessionCount,CurrentSessionDate",
		CurrentMode.Use,
		CurrentMode.Begin,
		CurrentMode.End,
		CurrentMode.Message,
		15 * 60, // 15 minutes, user session timeout before the infobase lock is set (in seconds)
		?(GetSessionCount, InfobaseSessionCount(), 0),
		LockParameters.CurrentDate);
EndFunction
// Removes the infobase lock.
//
// Returns:
//   Boolean - True if the operation is successful.
//             False if the operation cannot be performed due to insufficient rights.
//
Function AllowUserLogon() Export
	
	If CommonUseCached.DataSeparationEnabled() And CommonUseCached.CanUseSeparatedData() Then
		
		If Not Users.InfobaseUserWithFullAccess() Then
			Return False;
		EndIf;
		
		CurrentMode = GetDataAreaSessionLock();
		If CurrentMode.Use Then
			NewMode = NewConnectionLockParameters();
			NewMode.Use = False;
			SetDataAreaSessionLock(NewMode);
		EndIf;
		Return True;
		
	Else
		If Not Users.InfobaseUserWithFullAccess(, True) Then
			Return False;
		EndIf;
		
		CurrentMode = GetSessionsLock();
		If CurrentMode.Use Then
			NewMode = New SessionsLock;
			NewMode.Use = False;
			SetSessionsLock(NewMode);
		EndIf;
		Return True;
	EndIf;
	
EndFunction	
////////////////////////////////////////////////////////////////////////////////
// Data area session lock.
// Gets an empty structure with data area session lock parameters.
//
// Returns:
//   Structure  - containing the following fields:
//     Beginning - Date    - lock start time.
//     End       - Date    - lock end time.
//     Message   - String  - message for users attempting to access the locked data area.
//     Use       - Boolean - flag specifying whether the lock is set.
//     Exclusive - Boolean - lock status cannot be modified by the application administrator.
//
Function NewConnectionLockParameters() Export
	
	Return New Structure("End,Begin,Message,Use,Exclusive",
		Date(1,1,1), Date(1,1,1), "", False, False);
		
EndFunction
// Sets the data area session lock.
//
// Parameters:
//   Parameters  - Structure   - see NewConnectionLockParameters.
//   LocalTime   - Boolean     - if True, lock beginning time and lock end time values are expressed 
//                               in the local session time.
//                               If False, these values are expressed in universal time.
//   DataArea    - Number(7,0) - number of the data area to be locked.
//     When calling this procedure from a session with separator values set,
//       only a value equal to the session separator value can be passed (or the value can be omitted).
//     When calling this procedure from a session without separator values set, 
//       the parameter value must be specified.
//
Procedure SetDataAreaSessionLock(Parameters, Val LocalTime = True, Val DataArea = -1) Export
	
	If Not Users.InfobaseUserWithFullAccess() Then
		Raise NStr("en ='Insufficient rights to perform the operation'");
	EndIf;
	
	Exclusive = False;
	If Not Parameters.Property("Exclusive", Exclusive) Then
		Exclusive = False;
	EndIf;
	If Exclusive And Not Users.InfobaseUserWithFullAccess(, True) Then
		Raise NStr("en ='Insufficient rights to perform the operation'");
	EndIf;
	
	If CommonUseCached.CanUseSeparatedData() Then
		
		If DataArea = -1 Then
			DataArea = CommonUse.SessionSeparatorValue();
		ElsIf DataArea <> CommonUse.SessionSeparatorValue() Then
			Raise NStr("en = 'When in a session that uses separator values, you can only set session lock for a data area used in your session.'");
		EndIf;
		
	Else
		
		If DataArea = -1 Then
			Raise NStr("en = 'Cannot set the data area session lock. The data area is not specified.'");
		EndIf;
		
	EndIf;
	
	SettingsStructure = Parameters;
	If TypeOf(Parameters) = Type("SessionsLock") Then
		SettingsStructure = NewConnectionLockParameters();
		FillPropertyValues(SettingsStructure, Parameters);
	EndIf;
	SetPrivilegedMode(True);
	LockSet = InformationRegisters.DataAreaSessionLocks.CreateRecordSet();
	LockSet.Filter.DataAreaAuxiliaryData.Set(DataArea);
	LockSet.Read();
	LockSet.Clear();
	If Parameters.Use Then
		DataLock = LockSet.Add();
		DataLock.DataAreaAuxiliaryData = DataArea;
		DataLock.LockPeriodStart = ?(LocalTime And ValueIsFilled(SettingsStructure.Begin),
			ToUniversalTime(SettingsStructure.Begin), SettingsStructure.Begin);
		DataLock.LockPeriodEnd = ?(LocalTime And ValueIsFilled(SettingsStructure.End),
			ToUniversalTime(SettingsStructure.End), SettingsStructure.End);
		DataLock.LockMessage = SettingsStructure.Message;
		DataLock.Exclusive = SettingsStructure.Exclusive;
	EndIf;
	LockSet.Write();
	
EndProcedure
// Gets information on the data area session lock.
//
// Parameters:
//   LocalTime - Boolean - if True, lock beginning time and lock end time values must be expressed
//                         in the local session time. 
//                         If False, these values are expressed in universal time.
//
// Returns:
//   Structure - see NewConnectionLockParameters.
//
Function GetDataAreaSessionLock(Val LocalTime = True) Export
	
	Result = NewConnectionLockParameters();
	If Not CommonUseCached.DataSeparationEnabled() Or Not CommonUseCached.CanUseSeparatedData() Then
		Return Result;
	EndIf;
	
	If Not Users.InfobaseUserWithFullAccess() Then
		Raise NStr("en ='Insufficient rights to perform the operation'");
	EndIf;
	
	SetPrivilegedMode(True);
	LockSet = InformationRegisters.DataAreaSessionLocks.CreateRecordSet();
	LockSet.Filter.DataAreaAuxiliaryData.Set(CommonUse.SessionSeparatorValue());
	LockSet.Read();
	If LockSet.Count() = 0 Then
		Return Result;
	EndIf;
	DataLock = LockSet[0];
	Result.Begin = ?(LocalTime And ValueIsFilled(DataLock.LockPeriodStart),
		ToLocalTime(DataLock.LockPeriodStart), DataLock.LockPeriodStart);
	Result.End = ?(LocalTime And ValueIsFilled(DataLock.LockPeriodEnd),
		ToLocalTime(DataLock.LockPeriodEnd), DataLock.LockPeriodEnd);
	Result.Message = DataLock.LockMessage;
	Result.Exclusive = DataLock.Exclusive;
	CurrentDate = CurrentSessionDate();
	Result.Use = True;
	// Making additional checks related to lock period
	Result.Use = Not ValueIsFilled(DataLock.LockPeriodEnd)
		Or DataLock.LockPeriodEnd >= CurrentDate
		Or ConnectionsLockedForDate(Result, CurrentDate);
	Return Result;
	
EndFunction
#EndRegion
#Region InternalInterface
// Fills the parameter structures required by the client configuration code.
//
// Parameters:
//   Parameters - Structure - parameter structure.
//
Procedure AddClientParameters(Parameters) Export
	Parameters.Insert("SessionLockParameters", New FixedStructure(SessionLockParameters()));
EndProcedure
////////////////////////////////////////////////////////////////////////////////
// Declarations of internal events that can have handlers.
// Declares UserSessions subsystem events:
//
// Client events:
//   OnTerminateSession.
//
// For the description of this procedure, see StandardSubsystemsServer module.
Procedure OnAddInternalEvent(ClientEvents, ServerEvents) Export
	
	// CLIENT EVENTS.
	
	// The event occurs when a session is terminated using the UserSessions subsystem.
	//
	// Parameters:
	//  OwnerForm          - ManagedForm used for session termination.
	//  SessionNumber      - Number (8,0,+) - number of the session to be terminated.
	//  StandardProcessing - Boolean, flag specifying whether standard session termination processing
	//                       is used (accessing the server agent via COM connection or administration
	//                       server, requesting the cluster connection parameters from the current user). 
	//                       Can be set to False in the event handler; in this case,
	//                       standard session termination processing is not performed.
	//
	// Syntax:
	// Procedure OnTerminateSession (Val SessionNumber, StandardProcessing) Export
	//
	ClientEvents.Add("StandardSubsystems.UserSessions\OnTerminateSession");
	
EndProcedure
////////////////////////////////////////////////////////////////////////////////
// Adding the event handlers.
// For description of this procedure, see StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// CLIENT HANDLERS.
	
	ClientHandlers[
		"StandardSubsystems.BaseFunctionality\AfterStart"].Add(
			"InfobaseConnectionsClient");
	
	ClientHandlers[
		"StandardSubsystems.BaseFunctionality\LaunchParametersOnProcess"].Add(
			"InfobaseConnectionsClient");
	
	// SERVER HANDLERS
	
	ServerHandlers[
		"StandardSubsystems.BaseFunctionality\OnAddStandardSubsystemClientLogicParametersOnStart"].Add(
		"InfobaseConnections");
	
	ServerHandlers[
		"StandardSubsystems.BaseFunctionality\StandardSubsystemClientLogicParametersOnAdd"].Add(
		"InfobaseConnections");
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations") Then
		ServerHandlers["StandardSubsystems.SaaSOperations\InfobaseParameterTableOnFill"].Add(
			"InfobaseConnections");
	EndIf;
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"InfobaseConnections");
	
	If CommonUse.SubsystemExists("CloudTechnology.DataImportExport") Then
		ServerHandlers[
			"CloudTechnology.DataImportExport\OnFillExcludedFromImportExportTypes"].Add(
				"InfobaseConnections");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ToDoList") Then
		ServerHandlers["StandardSubsystems.ToDoList\OnFillToDoList"].Add(
			"InfobaseConnections");
	EndIf;
	
EndProcedure
#EndRegion
#Region InternalProceduresAndFunctions
////////////////////////////////////////////////////////////////////////////////
// SL event handlers
// Generates the list of infobase parameters.
//
// Parameters:
//  ParameterTable - ValueTable - parameter description table.
//  For column content details, see SaaSOperations.GetInfobaseParameterTable().
//
Procedure InfobaseParameterTableOnFill(Val ParameterTable) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations") Then
		SaasOperationsModule = CommonUse.CommonModule("SaaSOperations");
		SaasOperationsModule.AddConstantToInfobaseParameterTable(ParameterTable, "LockMessageOnConfigurationUpdate");
	EndIf;
	
EndProcedure
// Fills the parameter structure enabling the functioning of client code of this subsystem 
// at application startup, i.e. in event handlers.
// - BeforeStart
// - OnStart
//
// Parameters:
//   Parameters - Structure - startup parameter structure.
//
Procedure OnAddStandardSubsystemClientLogicParametersOnStart(Parameters) Export
	
	LockParameters = SessionLockParameterStructure();
	Parameters.Insert("SessionLockParameters", New FixedStructure(SessionLockParameters(, LockParameters)));
	
	If Not LockParameters.ConnectionsLocked
		Or Not CommonUseCached.DataSeparationEnabled()
		Or Not CommonUseCached.CanUseSeparatedData() Then
		Return;
	EndIf;
	
	// The following code is intended for locked data areas only
	If InfobaseUpdate.ExecutingInfobaseUpdate()
		And Users.InfobaseUserWithFullAccess() Then
		// The application administrator can log on regardless of the incomplete area
		// update status (and the data area lock). 
		// The administrator initiates area update by logging on.
		Return;
	EndIf;	
	
	CurrentMode = LockParameters.CurrentDataAreaMode;
	
	If ValueIsFilled(CurrentMode.End) Then
		LockPeriod = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'between %1 and %2'"),
			CurrentMode.Begin, CurrentMode.End);
	Else
		LockPeriod = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'from %1'"), CurrentMode.Begin);
	EndIf;
	If ValueIsFilled(CurrentMode.Message) Then
		LockReason = NStr("en = 'for the following reason:'") + Chars.LF + CurrentMode.Message;
	Else
		LockReason = NStr("en = 'for scheduled maintenance'");
	EndIf;
	MessageText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'The application administrator locked out the users %1 %2.
			|
			|The application is temporarily inaccessible.'"),
		LockPeriod, LockReason);
	Parameters.Insert("DataAreaSessionsLocked", MessageText);
	MessageText = "";
	If Users.InfobaseUserWithFullAccess() Then
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'The application administrator locked out the users %1 %2.
			    |
				|Log on to the locked application?'"),
			LockPeriod, LockReason);
	EndIf;
	Parameters.Insert("LogonSuggestion", MessageText);
	If (Users.InfobaseUserWithFullAccess() And Not CurrentMode.Exclusive)
		Or Users.InfobaseUserWithFullAccess(, True) Then
		
		Parameters.Insert("CanUnlock", True);
	Else
		Parameters.Insert("CanUnlock", False);
	EndIf;
			
EndProcedure
 
// Adds update handlers that are required by the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see see the
//                                  description of NewUpdateHandlerTable function in the InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.3.9";
	Handler.Procedure = "InfobaseConnections.MoveDataAreasSessionLocksToAuxiliaryData";
	Handler.SharedData = True;
	
EndProcedure
 
// Fills the parameter structures required by the client configuration code.
//
// Parameters:
//   Parameters - Structure - parameter structure.
//
Procedure StandardSubsystemClientLogicParametersOnAdd(Parameters) Export
	
	AddClientParameters(Parameters);
	
EndProcedure
// Fills the array of types excluded from data import and export.
//
// Parameters:
//  Types - Array(Types).
//
Procedure OnFillExcludedFromImportExportTypes(Types) Export
	
	Types.Add(Metadata.InformationRegisters.DataAreaSessionLocks);
	
EndProcedure
// Fills a user's to-do list.
//
// Parameters:
//  ToDoList - ValueTable - value table with the following columns:
//    * ID             - String    - internal task ID used by the To-do list algorithm.
//    * HasUserTasks   - Boolean   - if True, the user task is displayed in the user's to-do list.
//    * Important      - Boolean   - If True the user task is outlined in red.
//    * Presentation   - String    - user task presentation displayed to the user.
//    * Quantity       - Number    - quantitative indicator of the user task, displayed in the title of the user task.
//    * Form           - String    - full path to the form that is displayed by a click on the task hyperlink in the To-do list panel.
//    * FormParameters - Structure - parameters for opening the user form.
//    * Owner          - String, metadata object - string ID of the user task that is the
//                                   owner of the current user task, or a subsystem metadata object.
//    * Tooltip        - String    - tooltip text.
//
Procedure OnFillToDoList(ToDoList) Export
	
	If Not AccessRight("DataAdministration", Metadata) Then
		Return;
	EndIf;
	
	
	// This procedure is only called when To do list subsystem is available.
	// Therefore, the subsystem availability check is redundant. 
	ToDoListInternalCachedModule = CommonUse.CommonModule("ToDoListInternalCached");
	ObjectsBelonging = ToDoListInternalCachedModule.ObjectsBelongingToCommandInterfaceSections();
	Sections = ObjectsBelonging[Metadata.DataProcessors.ApplicationLock.FullName()];
	If Sections = Undefined Then
		Return;
	EndIf;
	
	LockParameters = SessionLockParameters(False);
	CurrentSessionDate = CurrentSessionDate();
	
	If LockParameters.Use Then
		If CurrentSessionDate < LockParameters.Begin Then
			If LockParameters.End <> Date(1, 1, 1) Then
				Message = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Scheduled between %1 and %2'"),
					Format(LockParameters.Begin, "DLF=DT"), Format(LockParameters.End, "DLF=DT"));
			Else
				Message = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Scheduled for %1'"),
					Format(LockParameters.Begin, "DLF=DT"));
			EndIf;
			Importance = False;
		ElsIf LockParameters.End <> Date(1, 1, 1) And CurrentSessionDate > LockParameters.End And LockParameters.Begin <> Date(1, 1, 1) Then
			Importance = False;
			Message = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Inactive (expired on %1)'"), 
				Format(LockParameters.End, "DLF=DT"));
		Else
			If LockParameters.End <> Date(1, 1, 1) Then
				Message = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'between %1 and %2'"),
					Format(LockParameters.Begin, "DLF=DT"), Format(LockParameters.End, "DLF=DT"));
			Else
				Message = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'from %1'"),
					Format(LockParameters.Begin, "DLF=DT"));
			EndIf;
			Importance = True;
		EndIf;
	Else
		Message = NStr("en = 'Inactive'");
		Importance = False;
	EndIf;
	
	For Each Section In Sections Do
		
		UserTaskID = "SessionsLock" + StrReplace(Section.FullName(), ".", "");
		
		UserTask               = ToDoList.Add();
		UserTask.ID            = UserTaskID;
		UserTask.HasUserTasks  = LockParameters.Use;
		UserTask.Presentation  = NStr("en = 'Lock application'");
		UserTask.Form          = "DataProcessor.ApplicationLock.Form";
		UserTask.Important     = Importance;
		UserTask.Owner         = Section;
		
		UserTask              = ToDoList.Add();
		UserTask.ID           = "SessionLockDetails";
		UserTask.HasUserTasks = LockParameters.Use;
		UserTask.Presentation = Message;
		UserTask.Owner        = UserTaskID;
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Miscellaneous.
// Returns the session lock message text.
//
// Parameters:
//   Message - String - lock message.
//   KeyCode - String - infobase access code.
//
// Returns:
//   String - lock message.
//
Function GenerateLockMessage(Val Message, Val KeyCode) Export
	
	AdministrationParameters = StandardSubsystemsServer.AdministrationParameters();
	FileModeFlag = False;
	PathToInfobase = InfobaseConnectionsClientServer.InfobasePath(FileModeFlag, AdministrationParameters.ClusterPort);
	InfobasePathString = ?(FileModeFlag = True, "/F", "/S") + PathToInfobase;
	MessageText = "";
	If Not IsBlankString(Message) Then
		MessageText = Message + Chars.LF + Chars.LF;
	EndIf;
	
	If CommonUseCached.DataSeparationEnabled() And CommonUseCached.CanUseSeparatedData() Then
		MessageText = MessageText +
		    NStr("en = '%1
		               |To allow user logon, run the application with the AllowUserLogon parameter. Example:
		               |http://<server URL>/?C=AllowUserLogon'");
	Else
		MessageText = MessageText +
		    NStr("en = '%1
		               |To allow user logon, use the server cluster console or run 1C:Enterprise with the
		               |following parameters: ENTERPRISE %2 /CAllowUserLogon /UC%3'");
	EndIf;
	MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText,
		InfobaseConnectionsClientServer.TextForAdministrator(), InfobasePathString,
		NStr("en = '<access code>'"));
	
	Return MessageText;
	
EndFunction
// Returns a text string containing the active infobase connection list.
// The connection names are separated by line breaks.
//
// Parameters:
//   Message - String - passed string.
//
// Returns:
//   String - connection names.
//
Function GetInfobaseConnectionNames(Val Message) Export
	
	Result = Message;
	For Each Session In GetInfobaseSessions() Do
		If Session.SessionNumber <> InfobaseSessionNumber() Then
			Result = Result + Chars.LF + " - " + Session;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction
// Gets the number of active infobase sessions.
//
// Parameters:
//   IncludeConsole      - Boolean   - if False, the server cluster console sessions are excluded.
//                                     The server cluster console sessions do not prevent execution of
//                                     administrative operations (enabling the exclusive mode, and so on).
//   MessagesForEventLog - ValueList - batch of event log messages generated at client side.
//
// Returns:
//   Number - number of active infobase sessions.
//
Function InfobaseSessionCount(IncludeConsole = True,
	MessagesForEventLog = Undefined) Export
	
	EventLogOperations.WriteEventsToEventLog(MessagesForEventLog);
	
	InfobaseSessions = GetInfobaseSessions();
	If IncludeConsole Then
		Return InfobaseSessions.Count();
	EndIf;
	
	Result = 0;
	For Each InfobaseSession In InfobaseSessions Do
		If InfobaseSession.ApplicationName <> "SrvrConsole" Then
			Result = Result + 1;
		EndIf;
	EndDo;
	Return Result;
	
EndFunction
// Returns the flag specifying whether a connection lock is set for a specific date.
//
// Parameters:
//   CurrentMode - SessionsLock - session lock.
//   CurrentDate - Date         - date to be checked.
//
// Returns:
//   Boolean - True if the lock is set.
//
Function ConnectionsLockedForDate(CurrentMode, CurrentDate)
	
	Return (CurrentMode.Use And CurrentMode.Begin <= CurrentDate
		And (Not ValueIsFilled(CurrentMode.End) Or CurrentDate <= CurrentMode.End));
		
EndFunction
Function SessionLockParameterStructure()
	
	SetPrivilegedMode(True);
	
	CurrentDate = CurrentSessionDate();
	CurrentInfobaseMode = GetSessionsLock();
	CurrentDataAreaMode = GetDataAreaSessionLock();
	InfobaseConnectionLockSetForDate = ConnectionsLockedForDate(CurrentInfobaseMode, CurrentDate);
	DataAreaConnectionLockSetForDate = ConnectionsLockedForDate(CurrentDataAreaMode, CurrentDate);
	
	SessionLockParameters = New Structure;
	SessionLockParameters.Insert("CurrentDate", CurrentDate);
	SessionLockParameters.Insert("CurrentInfobaseMode", CurrentInfobaseMode);
	SessionLockParameters.Insert("CurrentDataAreaMode", CurrentDataAreaMode);
	SessionLockParameters.Insert("InfobaseConnectionLockSetForDate", ConnectionsLockedForDate(CurrentInfobaseMode, CurrentDate));
	SessionLockParameters.Insert("DataAreaConnectionLockSetForDate", ConnectionsLockedForDate(CurrentDataAreaMode, CurrentDate));
	SessionLockParameters.Insert("ConnectionsLocked", InfobaseConnectionLockSetForDate Or DataAreaConnectionLockSetForDate);
	
	Return SessionLockParameters;
	
EndFunction
#EndRegion