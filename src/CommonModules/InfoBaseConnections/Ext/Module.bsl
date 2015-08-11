////////////////////////////////////////////////////////////////////////////////
// User sessions subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for locking and terminating infobase connections.

// Locks infobase connections.
// If this function is called from a session where data separation is enabled,
// the function locks data area sessions.
//
// Parameters:
// MessageText – String – text to be a part of an error message that 
// will be displayed to users who attempt to establish a connection to
// the locked infobase;
// KeyCode - String - code that allows establishing a connection to the locked infobase.
// To use the code, add it to the /uc command-line option
// or to the uc connection string option.
// This parameter is ignored if data separation is enabled.
//
// Returns:
// Boolean – True if connections are locked successfully,
// False if the user has insufficient access rights.
//
Function SetConnectionsLockExecute(Val MessageText = "",
	Val KeyCode = "KeyCode") Export
	
	If CommonUseCached.DataSeparationEnabled() Then
		
		If Not Users.InfoBaseUserWithFullAccess() Then
			Return False;
		EndIf;
		
		Lock = NewLockConnectionParameters();
		Lock.Use = True;
		Lock.Begin = CurrentSessionDate();
		Lock.Message = GenerateLockMessage(MessageText, KeyCode);
		Lock.Exclusive = Users.InfoBaseUserWithFullAccess(, True);
		SetDataAreaSessionLock(Lock);
		Return True;
	Else
		If Not Users.InfoBaseUserWithFullAccess(, True) Then
			Return False;
		EndIf;
		
		Lock = New SessionsLock;
		Lock.Use = True;
		Lock.Begin = CurrentSessionDate();
		Lock.KeyCode = KeyCode;
		Lock.Message = GenerateLockMessage(MessageText, KeyCode);
		SetSessionsLock(Lock);
		Return True;
	EndIf;
	
EndFunction

// Defines whether connections are locked during 
// the batch infobase configuration update.
//
// Returns:
// Boolean - True if connections are locked, otherwise is False.
//
Function ConnectionsLocked() Export
	
	SetPrivilegedMode(True);
	CurrentDataAreaMode = GetDataAreaSessionLock();
	CurrentInfoBaseMode = GetSessionsLock();
	CurrentDate = CurrentSessionDate();
	Return ConnectionsLockedForDate(CurrentDataAreaMode, CurrentDate)
		Or ConnectionsLockedForDate(CurrentInfoBaseMode, CurrentDate);
		
EndFunction

// Retrieves infobase connection lock parameters for using them on a client.
//
// Parameters:
// GetSessionCount - Boolean - if this parameter is True, the SessionCount field of 
// the return structure is filled.
//
// Returns:
// Structure – structure with the following fields:
// Use - Boolean - True if connections are locked, otherwise is False; 
// Begin - Date - lock start date; 
// End - Date - lock end date; 
// Message - String - message to a user;
// SessionTerminationTimeout - Number - interval in seconds;
// SessionCount - number of sessions. 0 if GetSessionCount = False;
// CurrentSessionDate - Date - current session date.
//
Function SessionLockParameters(Val GetSessionCount = False) Export
	
	SetPrivilegedMode(True);
	CurrentDataAreaMode = GetDataAreaSessionLock();
	CurrentInfoBaseMode = GetSessionsLock();
	CurrentDate = CurrentSessionDate();
	CurrentMode = NewLockConnectionParameters();
	If ConnectionsLockedForDate(CurrentInfoBaseMode, CurrentDate) Then
		CurrentMode = CurrentInfoBaseMode;
	ElsIf ConnectionsLockedForDate(CurrentDataAreaMode, CurrentDate) Then
		CurrentMode = CurrentDataAreaMode;
	ElsIf CurrentInfoBaseMode.Use Then
		CurrentMode = CurrentInfoBaseMode;
	Else
		CurrentMode = CurrentDataAreaMode;
	EndIf;
	
	Return New Structure(
		"Use,Begin,End,Message,SessionTerminationTimeout,SessionCount,CurrentSessionDate",
		CurrentMode.Use,
		CurrentMode.Begin,
		CurrentMode.End,
		CurrentMode.Message,
		5 * 60, // 5 minutes. User logoff time-out that will be set after locking
		 // the infobase (in seconds).
		?(GetSessionCount, InfoBaseSessionCount(), 0),
		CurrentSessionDate()
	);

EndFunction

// Unlocks the infobase.
//
// Returns:
// Boolean – True if the operation completed successfully.
// False if the user has insufficient access rights.
//
Function AllowUserLogon() Export
	
	If CommonUseCached.DataSeparationEnabled() Then
		
		If Not Users.InfoBaseUserWithFullAccess() Then
			Return False;
		EndIf;
		
		CurrentMode = GetDataAreaSessionLock();
		If CurrentMode.Use Then
			NewMode = NewLockConnectionParameters();
			NewMode.Use = False;
			SetDataAreaSessionLock(NewMode);
		EndIf;
		Return True;
		
	Else
		If Not Users.InfoBaseUserWithFullAccess(, True) Then
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
// Procedures and functions for working with a scheduled job lock.

// Locks or unlocks scheduled jobs.
//
// Parameters:
// Value – Boolean - True to lock scheduled jobs, False to unlock them.
//
Procedure SetSheduledJobLock(Value) Export
	
	If Not Users.InfoBaseUserWithFullAccess(, True) Then
		Raise NStr("en= 'Insufficient access rights to perform the operation.'");
	EndIf;	
	SetPrivilegedMode(True);
	InfoBaseConnectionsClientServer.SetSheduledJobLock(Value);
	
EndProcedure	

// Retrieves the current state of the scheduled job lock.
//
// Returns:
// Boolean – True if scheduled jobs are locked.
//
Function ScheduledJobsLocked() Export
	
	If Not Users.InfoBaseUserWithFullAccess(, True) Then
		Raise NStr("en= 'Insufficient access rights to perform the operation.'");
	EndIf;	
	SetPrivilegedMode(True);
	Return InfoBaseConnectionsClientServer.ScheduledJobsLocked();
		
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for working with a data area session lock.

// Retrieves an empty structure with fields that correspond to data area session lock parameters.
// 
// Returns:
// Structure with the following fields:
// Begin - Date - lock start date; 
// End - Date - lock end date; 
// Message - String - message to users who attempt to log on to the locked data area;
// Use - Boolean - flag that shows whether data area sessions are locked;
// Exclusive - Boolean - if this parameter is True, the application administrator cannot change the session lock.
//
Function NewLockConnectionParameters() Export
	
	Return New Structure("End,Begin,Message,Use,Exclusive",
		Date(1,1,1), Date(1,1,1), "", False, False);
		
EndFunction

// Locks data area sessions.
// 
// Parameters:
// Parameters – Structure – see the NewLockConnectionParameters function for details;
// LocalTime - Boolean - flag that shows whether the lock start time and the lock end time are specified in session local time 
// (or in coordinated universal time (UTC) if LocalTime is False).
//
Procedure SetDataAreaSessionLock(Parameters, Val LocalTime = True) Export
	
	If Not Users.InfoBaseUserWithFullAccess() Then
		Raise NStr("en= 'Insufficient access rights to perform the operation.'");
	EndIf;
	
	Exclusive = False;
	If Not Parameters.Property("Exclusive", Exclusive) Then
		Exclusive = False;
	EndIf;
	If Exclusive And Not Users.InfoBaseUserWithFullAccess(, True) Then
		Raise NStr("en= 'Insufficient access rights to perform the operation.'");
	EndIf;
	
	SettingsStructure = Parameters;
	If TypeOf(Parameters) = Type("SessionsLock") Then
		SettingsStructure = NewLockConnectionParameters();
		FillPropertyValues(SettingsStructure, Parameters);
	EndIf;

	SetPrivilegedMode(True);
	LockSet = InformationRegisters.DataAreaSessionLocks.CreateRecordSet();
	LockSet.Filter.DataArea.Set(CommonUse.SessionSeparatorValue());
	LockSet.Read();
	LockSet.Clear();
	If Parameters.Use Then 
		DataLock = LockSet.Add();
		DataLock.DataArea = CommonUse.SessionSeparatorValue();
		DataLock.BeginLock = ?(LocalTime And ValueIsFilled(SettingsStructure.Begin), 
			ToUniversalTime(SettingsStructure.Begin), SettingsStructure.Begin);
		DataLock.EndLock = ?(LocalTime And ValueIsFilled(SettingsStructure.End), 
			ToUniversalTime(SettingsStructure.End), SettingsStructure.End);
		DataLock.LockMessage = SettingsStructure.Message;
		DataLock.Exclusive = SettingsStructure.Exclusive;
	EndIf;
	LockSet.Write();
	
EndProcedure

// Gets data area session lock details.
// Parameters:
// LocalTime - Boolean - flag that shows whether lock start time and lock end time must be returned in session local time 
// (or in coordinated universal time (UTC) if LocalTime is False).
//
// Returns:
// Structure – see the NewLockConnectionParameters function for details.
//
Function GetDataAreaSessionLock(Val LocalTime = True) Export
	
	Result = NewLockConnectionParameters();
	If Not CommonUseCached.DataSeparationEnabled() Then
		Return Result;
	EndIf;
	
	If Not Users.InfoBaseUserWithFullAccess() Then
		Raise NStr("en = 'Insufficient access rights to perform the operation.'");
	EndIf;
	
	SetPrivilegedMode(True);
	LockSet = InformationRegisters.DataAreaSessionLocks.CreateRecordSet();
	LockSet.Filter.DataArea.Set(CommonUse.SessionSeparatorValue());
	LockSet.Read();
	If LockSet.Count() = 0 Then
		Return Result;
	EndIf;
	DataLock = LockSet[0];
	Result.Begin = ?(LocalTime And ValueIsFilled(DataLock.BeginLock), 
		ToLocalTime(DataLock.BeginLock), DataLock.BeginLock);
	Result.End = ?(LocalTime And ValueIsFilled(DataLock.EndLock), 
		ToLocalTime(DataLock.EndLock), DataLock.EndLock);
	Result.Message = DataLock.LockMessage;
	Result.Exclusive = DataLock.Exclusive;
	CurrentDate = CurrentSessionDate();
	Result.Use = True;
	// Getting the Use field value by the lock period
	Result.Use = Not ValueIsFilled(DataLock.EndLock) 
		Or DataLock.EndLock >= CurrentDate 
		Or ConnectionsLockedForDate(Result, CurrentDate);
	Return Result;
	
EndFunction

// Fills the parameter structure required for executing the client script of 
// this subsystem on application startup, namely in the following event handlers:
// - BeforeStart;
// - OnStart.
//
// Returns:
// Structure - structure with the startup parameters.
//
Procedure CheckDataAreaConnectionsLock(Parameters) Export
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	If Not ConnectionsLocked() Then
		Return;
	EndIf;
	
	CurrentMode = GetDataAreaSessionLock();
	SetPrivilegedMode(False);
	
	If ValueIsFilled(CurrentMode.End) Then
		LockPeriod = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en= 'from %1 till %2'"),
			CurrentMode.Begin, CurrentMode.End);
	Else
		LockPeriod = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en= 'from %1'"), CurrentMode.Begin);
	EndIf;
	If ValueIsFilled(CurrentMode.Message) Then
		LockReason = NStr("en = 'for the following reason:'") + Chars.LF + CurrentMode.Message;
	Else
		LockReason = NStr("en = 'for performing a scheduled maintenance");
	EndIf;
	MessageText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en= 'The administrator locked the application %1 %2.
			|
			|The application is temporarily unavailable.'"),
		LockPeriod, LockReason);
	Parameters.Insert("DataAreaSessionsLocked", MessageText);
	MessageText = "";
	If (Users.InfoBaseUserWithFullAccess() And Not CurrentMode.Exclusive) 
		Or Users.InfoBaseUserWithFullAccess(, True) Then
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en= 'The administrator locked the application %1 %2.
			 |
				|Do you want to log on to the locked application?'"),
			LockPeriod, LockReason);
	EndIf;
	Parameters.Insert("SuggestUnlockingMessage", MessageText);
			
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for working with a forced session termination.

// Terminates session by the session number.
//
// Parameters
// SessionNumber - Number - number of a session to be terminated;
// ErrorMessage - String - if an error occurs during function execution, the error message is assigned to this parameter.
//
// Returns:
// Boolean – session termination result.
//
Function TerminateSession(SessionNumber, ErrorMessage) Export
	
	If Not Users.InfoBaseUserWithFullAccess() Then
		Raise NStr("en = 'Insufficient access rights to perform the operation.'");
	EndIf;	
	
	StandardProcessing = True;
	Result = True;
	StandardSubsystemsOverridable.OnCloseSession(SessionNumber, Result, ErrorMessage, StandardProcessing);
	If Not StandardProcessing Then
		Return Result;
	EndIf;
	If InfoBaseConnectionsCached.SessionTerminationParameters().WindowsPlatformAtServer Then
		SetPrivilegedMode(True);
		Return InfoBaseConnectionsClientServer.TerminateSessionWithMessage(SessionNumber, ErrorMessage);
	Else // If the server runs Linux
		ErrorMessage = NStr("Web server connection sessions cannot be forcibly terminated because the server does not run Microsoft Windows");
		WriteInfoBaseConnectionNamesToLog(ErrorMessage);
		Return False;
	EndIf;
	
EndFunction

// Terminates all active infobase connections except the current session.
//
// Parameters:
// InfoBaseAdministrationParameters – Structure – infobase administration parameters. 
//
// Returns:
// Boolean – connection termination result.
//
Function TerminateAllSessions(InfoBaseAdministrationParameters) Export
	
	If Not Users.InfoBaseUserWithFullAccess() Then
		Raise NStr("en= 'Insufficient access rights to perform the operation.'");
	EndIf;	
	SetPrivilegedMode(True);
	Return InfoBaseConnectionsClientServer.TerminateAllSessions(InfoBaseAdministrationParameters);
	
EndFunction

// Attempts to connect to the server cluster and get an active infobase connection list 
// using the specified administration parameters.
//
// Parameters:
// InfoBaseAdministrationParameters – Structure – infobase administration parameters;
// DetailedErrorMessage – Boolean – flag that shows whether details are included in an error message if an error occurs.
//
// Returns:
// Boolean – True if the check completed successfully.
//
Procedure CheckInfoBaseAdministrationParameters(InfoBaseAdministrationParameters,
	Val DetailedErrorMessage = False) Export
	
	If Not Users.InfoBaseUserWithFullAccess() Then
		Raise NStr("en= 'Insufficient access rights to perform the operation.'");
	EndIf;	
	SetPrivilegedMode(True);
	InfoBaseConnectionsClientServer.CheckInfoBaseAdministrationParameters(InfoBaseAdministrationParameters,
		DetailedErrorMessage);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions.

// Returns a session lock message text.
//
// Parameters:
// Message - String - message to be included in the result message;
// KeyCode - String - code that allows establishing a connection to the locked infobase.
//
// Returns:
// String - lock message.
//
Function GenerateLockMessage(Val Message, Val KeyCode) Export

	InfoBaseAdministrationParameters = InfoBaseConnectionsCached.GetInfoBaseAdministrationParameters();
	FileModeFlag = False;
	PathToInfoBase = InfoBaseConnectionsClientServer.InfoBasePath(FileModeFlag, 
		?(InfoBaseAdministrationParameters.Property("ServerClusterPort"), InfoBaseAdministrationParameters.ServerClusterPort, 0));
	InfoBasePathString = ?(FileModeFlag = True, "/F", "/S") + PathToInfoBase; 
	MessageText = ""; 
	If Not IsBlankString(Message) Then
		MessageText = Message + Chars.LF + Chars.LF;
	EndIf;
	
	If CommonUseCached.DataSeparationEnabled() Then
		MessageText = MessageText +
		 NStr("en= '%1
		 |If you want to allow user logon, start the application with the AllowUserLogon parameter. For example:
		 |http://<the web address of the server>/?C=AllowUsers'");
	Else
		MessageText = MessageText +
		 NStr("en= '%1
		 |If you want to allow user logon, use the server cluster console or start 1C:Enterprise with the following parameters:
		 |ENTERPRISE %2 /CAllowUserLogon /UC%3'");
	EndIf;
	MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText,
		InfoBaseConnectionsClientServer.TextForAdministrator(), InfoBasePathString, 
		NStr("en= '<key code>'"));
	
	Return MessageText;
	
EndFunction

// Returns a string with a list of active infobase connections.
// The linefeed characters separate connection names.
//
// Parameters:
// Message - String - result string starts with this message.
//
// Returns:
// String - connection names.
//
Function GetInfoBaseConnectionNames(Val Message) Export
	
	Result = Message;
	For Each Session In GetInfoBaseSessions() Do
		If Session.SessionNumber <> InfoBaseSessionNumber() Then
			Result = Result + Chars.LF + " - " + Session;
		EndIf;
	EndDo; 
	
	Return Result;
	
EndFunction

// Retrieves saved server cluster administration parameters.
// 
// Returns:
// Structure - see the NewInfoBaseAdministrationParameters function for details.
//
Function GetInfoBaseAdministrationParameters() Export

	If Not Users.InfoBaseUserWithFullAccess(, True) Then
		Raise NStr("en= 'Insufficient access rights to perform the operation.'");
	EndIf;	
	
	SetPrivilegedMode(True);
	Result = InfoBaseConnectionsClientServer.NewInfoBaseAdministrationParameters();
	SettingsStructure = Constants.InfoBaseAdministrationParameters.Get();
	If SettingsStructure <> Undefined Then
		SettingsStructure = SettingsStructure.Get();
		If TypeOf(SettingsStructure) = Type("Structure") Then
			FillPropertyValues(Result, SettingsStructure);
		EndIf;
	EndIf;
	Return Result;
	
EndFunction

// Saves server cluster administration parameters to the infobase.
//
// Parameters:
// Parameters - Structure - see the NewInfoBaseAdministrationParameters function for details.
//
Procedure WriteInfoBaseAdministrationParameters(Parameters) Export
	
	Constants.InfoBaseAdministrationParameters.Set(New ValueStorage(Parameters));
	RefreshReusableValues();
	
EndProcedure

// Retrieves a number of active infobase sessions.
//
// Parameters:
// IncludingConsole - Boolean - If it is False, server cluster console sessions will be excluded.
// Server cluster console sessions do not prevent execution of administrative operations 
// (such as setting the exclusive mode);
// MessagesForEventLog - ValueList - value list with messages generated on a client 
// for the event log.
//
// Returns:
// Number – number of active infobase sessions.
//
Function InfoBaseSessionCount(IncludingConsole = True, 
	MessagesForEventLog = Undefined) Export
	
	CommonUse.WriteEventsToEventLog(MessagesForEventLog);
	
	InfoBaseSessions = GetInfoBaseSessions();
	If IncludingConsole Then
		Return InfoBaseSessions.Count();
	EndIf;
	
	Result = 0;
	For Each InfoBaseSession In InfoBaseSessions Do
		If InfoBaseSession.ApplicationName <> "SrvrConsole" Then
			Result = Result + 1;
		EndIf;
	EndDo;
	Return Result;
	
EndFunction

// Returns a string constant for generating event log messages.
//
// Returns:
// String.
//
Function EventLogMessageText()
	
	Return NStr("en= 'User sessions'", Metadata.DefaultLanguage.LanguageCode);
	
EndFunction

// Writes the infobase session list to the event log.
//
// Parameters:
// MessageText - String, optional - explanatory text.
// 
Procedure WriteInfoBaseConnectionNamesToLog(Val MessageText) Export
	Message = GetInfoBaseConnectionNames(FailedTerminateSessionsText(MessageText));
	WriteLogEvent(EventLogMessageText(), 
		EventLogLevel.Information, , , Message);
EndProcedure

// Returns user session termination failure message.
//
// Parameters:
// Message - String - explanatory text to be included in the result message.
//
// Returns:
// String - user session termination failure message.
//
Function FailedTerminateSessionsText(Val Message) 
	
	If Not IsBlankString(Message) Then
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en= 'User sessions cannot be terminated (%1):'"),
			Message);
	Else		
		MessageText = NStr("en= 'User sessions cannot be terminated:'");
	EndIf;
	Return MessageText;
	
EndFunction

// Checks whether a connection lock is scheduled for the specified date.
//
// Parameters:
// CurrentMode - SessionsLock - session lock;
// CurrentDate - Date - date when the check will be performed.
//
// Returns:
// Boolean - True if connections are locked, otherwise is False.
//
Function ConnectionsLockedForDate(CurrentMode, CurrentDate)
	
	Return (CurrentMode.Use And CurrentMode.Begin <= CurrentDate 
		And (Not ValueIsFilled(CurrentMode.End) Or CurrentDate <= CurrentMode.End));
		
EndFunction

// Internal use only.
Procedure InternalEventOnAdd(ClientEvents, ServerEvents) Export
	
	ClientEvents.Add("StandardSubsystems.UserSessions\OnDisconnect");
	
EndProcedure

// Internal use only.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
EndProcedure
