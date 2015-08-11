////////////////////////////////////////////////////////////////////////////////
// User sessions subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for working with a forced session termination.

// Terminates the session by its number.
//
// Parameters:
// SessionNumber - Number - number of session to be terminated;
// ErrorMessage - String - if an error occurs during function execution, the error message is assigned to this parameter.
// Returns:
// Boolean – session termination result.
//
Function TerminateSessionWithMessage(SessionNumber, ErrorMessage) Export
	
	If InfoBaseConnections.InfoBaseSessionCount() <= 1 Then
		// All user sessions except the current one are terminated
		Return True; 
	EndIf;
	
	// File mode sessions cannot be forcibly terminated
	If FileInfoBase() Then
		Message = NStr("en = 'File mode sessions cannot be forcibly terminated.'");
		InfoBaseConnections.WriteInfoBaseConnectionNamesToLog(ErrorMessage);
		Return False; 
	EndIf;
	
#If AtClient Then		
	If CommonUseClient.ClientConnectedViaWebServer() Then
		// Passing control to the server
		Return InfoBaseConnections.TerminateSession(SessionNumber, ErrorMessage);
	EndIf;
#EndIf		
	
	Try
		Return TerminateSession(SessionNumber);
	Except
		ErrorMessage = NStr("en = 'Session cannot be forcibly terminated
				|for the following reason:
				|%1
				|
				|Possibly, infobase administration parameters are not configured.
				|See the event log for error technical details.'");
		ErrorInfo = ErrorInfo();
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(ErrorMessage, 
			BriefErrorDescription(ErrorInfo));
		WriteEvent(DetailErrorDescription(ErrorInfo), "Error");
		Return False;
	EndTry;
	
EndFunction

// Terminates all active infobase connections (except the current session).
//
// Parameters:
// InfoBaseAdministrationParameters – Structure – infobase administration parameters. 
//
// Returns:
// Boolean – connection termination result.
//
Function TerminateAllSessions(Val InfoBaseAdministrationParameters = Undefined) Export
	
	If InfoBaseConnections.InfoBaseSessionCount() <= 1 Then
	// All user sessions except the current one are terminated
		Return True;	
	EndIf;
	
	// File mode sessions cannot be forcibly terminated
	If FileInfoBase() Then
		InfoBaseConnections.WriteInfoBaseConnectionNamesToLog(NStr("en = 'File mode sessions cannot be forcibly terminated.'"));
		Return False; 
	EndIf;
	
#If AtClient Then		
	If CommonUseClient.ClientConnectedViaWebServer() Then
		If InfoBaseConnectionsCached.SessionTerminationParameters().WindowsPlatformAtServer Then
			// Passing control to the server that runs Windows
			Return InfoBaseConnections.TerminateAllSessions(InfoBaseAdministrationParameters);
		EndIf;
		InfoBaseConnections.WriteInfoBaseConnectionNamesToLog(NStr("en = 'Web server connection sessions cannot be forcibly terminated 
			|because the server does not run Windows.'"));
		Return False; 
	EndIf;
#EndIf		
	
	Try
		Sessions = GetActiveInfoBaseSessions(True, InfoBaseAdministrationParameters);
		For Each Session In Sessions.Sessions Do
			// Terminating infobase sessions
			Message = StringFunctionsClientServer.SubstituteParametersInString(
			 NStr("en= 'Terminating session: %1, computer: %2, started: %3, mode: %4.'"),
			 Session.UserName,
			 Session.Host,
			 Session.StartedAt,
				Session.AppID);
			
			WriteEvent(Message, "Information", False);
			Sessions.ServerAgent.TerminateSession(Sessions.ServersCluster, Session);
		EndDo;
		
#If AtClient Then		
		ClientMessages = MessagesForEventLog;
#Else		
		ClientMessages = Undefined;
#EndIf		
		Return InfoBaseConnections.InfoBaseSessionCount(ClientMessages) <= 1;
	Except
		WriteEvent(DetailErrorDescription(ErrorInfo()), "Error");
		Return False;
	EndTry;
	
EndFunction

// Establishes a connection to the server cluster and retrieves an 
// active session list using the specified administration parameters.
//
// Parameters:
// InfoBaseAdministrationParameters – Structure – infobase administration parameters;
// DetailedErrorMessage – Boolean – flag that shows whether details are included in
// an error message if an error occurs.
//
// Returns:
// Boolean – True if the check completed successfully.
//
Procedure CheckInfoBaseAdministrationParameters(InfoBaseAdministrationParameters,
	Val DetailedErrorMessage = False) Export
	
	Try
		If FileInfoBase() Then
			Raise NStr("en = 'The active connection list cannot be retrieved in the file mode.'");
		EndIf;
		
#If AtClient Then		
	If CommonUseClient.ClientConnectedViaWebServer() Then
		If InfoBaseConnectionsCached.SessionTerminationParameters().WindowsPlatformAtServer Then
			// Passing control to the server
			InfoBaseConnections.CheckInfoBaseAdministrationParameters(InfoBaseAdministrationParameters, DetailedErrorMessage);
		EndIf;
		// The active connection list cannot be retrieved if a client application connects
		// to the infobase through the web server and the server does not run Windows.
		Raise NStr("en = 'The active connection list cannot be retrieved if the client application connects 
			|to the infobase through the web server and the server does not run Windows.'");
	EndIf;
#EndIf		
		
		Sessions = GetActiveInfoBaseSessions(True, InfoBaseAdministrationParameters);
	Except
		Message = NStr("en = 'Failed to establish a connection to the server cluster.'");
		WriteEvent(Message + Chars.LF + DetailErrorDescription(ErrorInfo()), "Error");
		If DetailedErrorMessage Then
			Message = Message + " " + BriefErrorDescription(ErrorInfo());
		EndIf;
		Raise Message;
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and function for working with a scheduled job lock.

// Locks or unlocks scheduled jobs.
//
// Parameters:
// Value – Boolean - True to lock scheduled jobs, False to unlock them.
//
Procedure SetSheduledJobLock(Value) Export
	
	If FileInfoBase() Then
		Raise NStr("en = 'Scheduled and background jobs cannot be locked in the file mode.'");
	EndIf;

#If AtClient Then		
	If CommonUseClient.ClientConnectedViaWebServer() Then
		If InfoBaseConnectionsCached.SessionTerminationParameters().WindowsPlatformAtServer Then
			// Passing control to the server
			InfoBaseConnections.SetSheduledJobLock(Value);
		EndIf;
		Raise NStr("en = 'Scheduled and background jobs cannot be locked if the client application connects 
			|to the infobase through the web server and the server does not run Windows.'");
	EndIf;
#EndIf		

	Connection = ConnectToCurrentInfoBase();
	Connection.CurrentInfoBase.ScheduledJobsDenied = Value;
	Connection.WorkingProcess.UpdateInfoBase(Connection.CurrentInfoBase);
	
EndProcedure	

// Retrieves the current state of the scheduled job lock.
//
// Returns:
// Boolean – True if scheduled jobs are locked.
//
Function ScheduledJobsLocked() Export
	
	If FileInfoBase() Then
		Return False;	
	EndIf;
	
#If AtClient Then		
	If CommonUseClient.ClientConnectedViaWebServer() Then
		If InfoBaseConnectionsCached.SessionTerminationParameters().WindowsPlatformAtServer Then
			// Passing control to the server
			Return InfoBaseConnections.ScheduledJobsLocked();
		EndIf;
		Return False;
	EndIf;
#EndIf		

	Connection = ConnectToCurrentInfoBase();
	Return Connection.CurrentInfoBase.ScheduledJobsDenied;
		
EndFunction

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Retrieves the infobase connection string if a non-standard server cluster port is set.
//
// Parameters:
// ServerClusterPort - Number - non-standard server cluster port.
//
// Returns:
// String - Infobase connection string.
//
Function GetInfoBaseConnectionString(Val ServerClusterPort = 0) Export

	Result = InfoBaseConnectionString();
	If FileInfoBase() Or (ServerClusterPort = 0) Then
		Return Result;
	EndIf; 
	
#If AtClient Then		
	If CommonUseClient.ClientConnectedViaWebServer() Then
		Return Result;
	EndIf; 
#EndIf		
	
	ConnectionStringSubstrings = StringFunctionsClientServer.SplitStringIntoSubstringArray(Result, ";");
	ServerName = StringFunctionsClientServer.RemoveDoubleQuotationMarks(Mid(ConnectionStringSubstrings[0], 7));
	InfoBaseName = StringFunctionsClientServer.RemoveDoubleQuotationMarks(Mid(ConnectionStringSubstrings[1], 6));
	Result = "Srvr=" + """" + ServerName + 
		?(Find(ServerName, ":") > 0, "", ":" + Format(ServerClusterPort, "NG=0")) + """;" + 
		"Ref=" + """" + InfoBaseName + """;";
	Return Result;

EndFunction

// Returns a full path to the infobase (a connection string).
//
// Parameters:
// FileModeFlag - Boolean - output parameter.
// It is True if the infobase operates in the file mode,
// it is False if the infobase operates in the client/server mode;
// ServerClusterPort - Number - input parameter. It must be specified if 
// the server cluster uses a non-standard port.
// Default value is 0. It means that 
// the server cluster uses the default port.
//
// Returns:
// String - infobase connection string.
//
Function InfoBasePath(FileModeFlag = Undefined, Val ServerClusterPort = 0) Export
	
	ConnectionString = GetInfoBaseConnectionString(ServerClusterPort);
	
	SearchPosition = Find(Upper(ConnectionString), "FILE=");
	
	If SearchPosition = 1 Then // file infobase
		
		PathToInfoBase = Mid(ConnectionString, 6, StrLen(ConnectionString) - 6);
		FileModeFlag = True;
		
	Else
		FileModeFlag = False;
		
		SearchPosition = Find(Upper(ConnectionString), "SRVR=");
		
		If Not (SearchPosition = 1) Then
			Return Undefined;
		EndIf;
		
		SemicolonPosition = Find(ConnectionString, ";");
		CopyStartPosition = 6 + 1;
		CopyingEndPosition = SemicolonPosition - 2; 
		
		ServerName = Mid(ConnectionString, CopyStartPosition, CopyingEndPosition - CopyStartPosition + 1);
		
		ConnectionString = Mid(ConnectionString, SemicolonPosition + 1);
		
		// The server name position
		SearchPosition = Find(Upper(ConnectionString), "REF=");
		
		If Not (SearchPosition = 1) Then
			Return Undefined;
		EndIf;
		
		CopyStartPosition = 6;
		SemicolonPosition = Find(ConnectionString, ";");
		CopyingEndPosition = SemicolonPosition - 2;
		
		InfoBaseNameAtServer = Mid(ConnectionString, CopyStartPosition, CopyingEndPosition - CopyStartPosition + 1);
		
		PathToInfoBase = """" + ServerName + "\" + InfoBaseNameAtServer + """";
	EndIf;
	
	Return PathToInfoBase;
	
EndFunction

// Retrieves a structure with server cluster administration parameters.
//
// Parameters:
// InfoBaseAdministratorName - String - infobase administrator name;
// InfoBaseAdministratorPassword - String - infobase administrator password; 
// ClusterAdministratorName - String - cluster administrator name;
// ClusterAdministratorPassword - String - cluster administrator password;
// ServerClusterPort - Number - server cluster port;
// ServerAgentPort - Number - server agent port.
//
// Returns:
// Structure – structure with server cluster administration parameters and empty values.
//
Function NewInfoBaseAdministrationParameters(Val InfoBaseAdministratorName = "", Val InfoBaseAdministratorPassword = "",
	Val ClusterAdministratorName = "", Val ClusterAdministratorPassword = "", 
	Val ServerClusterPort = 0, Val ServerAgentPort = 0) Export
	
	Return New Structure("InfoBaseAdministratorName,InfoBaseAdministratorPassword,ClusterAdministratorName,
		|ClusterAdministratorPassword,ServerClusterPort,ServerAgentPort",
		InfoBaseAdministratorName,
		InfoBaseAdministratorPassword,
		ClusterAdministratorName,
		ClusterAdministratorPassword,
		ServerClusterPort,
		ServerAgentPort);
	
EndFunction

// Returns a text constant for generating messages.
// Is used for localization purposes.
//
// Returns:
// String - "For administrator:".
//
Function TextForAdministrator() Export
	
	Return NStr("en = 'For administrator:'");
	
EndFunction

// Returns a session lock message for users.
//
// Parameters:
// Message - String - full message.
//
// Returns:
// String - session lock message.
//
Function ExtractLockMessage(Val Message) Export
	
	MarkerIndex = Find(Message, TextForAdministrator());
	If MarkerIndex = 0 Then
		Return Message;
	ElsIf MarkerIndex >= 3 Then
		Return Mid(Message, 1, MarkerIndex - 3);
	Else
		Return "";
	EndIf;
		
EndFunction

// Returns a string constant for generating event log messages.
//
// Returns:
// String - event description for the event log.
//
Function EventLogMessageText()
	
	Return NStr("en = 'User sessions'", CommonUseClientServer.DefaultLanguageCode());
	
EndFunction

// Establishes a connection to a server agent.
//
// Parameters:
// PlatformServerConnectionParameters - Structure - platform server connection parameters.
//
// Returns:
// Structure with the following fields:
// COMConnector - COMObject - COM connector object;
// ServerName - String - server name;
// InfoBaseName - String - infobase name;
// ServerAgent - String - server agent;
// ClusterPort - Number - cluster port;
// ServerAgentID - String - server agent ID.
//
Function ConnectToServerAgent(PlatformServerConnectionParameters)
	
	ConnectionStringSubstrings = StringFunctionsClientServer.SplitStringIntoSubstringArray(
		InfoBaseConnectionString(), ";");
	
	ServerName = StringFunctionsClientServer.RemoveDoubleQuotationMarks(Mid(ConnectionStringSubstrings[0], 7));
	InfoBaseName = StringFunctionsClientServer.RemoveDoubleQuotationMarks(Mid(ConnectionStringSubstrings[1], 6));
	
	COMConnector = New COMObject(CommonUse.COMConnectorName());
	
	PortSeparator = Find(ServerName, ":");
	If PortSeparator > 0 Then
		ServerNameAndPort = ServerName;
		ServerName = Mid(ServerNameAndPort, 1, PortSeparator - 1);
		ClusterPort = Number(Mid(ServerNameAndPort, PortSeparator + 1));
	ElsIf PlatformServerConnectionParameters.ServerClusterPort <> 0 Then
		ClusterPort = PlatformServerConnectionParameters.ServerClusterPort;
	Else
		ClusterPort = COMConnector.RMngrPortDefault;
	EndIf;
	
	ServerAgentID = ServerName;
	If PlatformServerConnectionParameters.ServerAgentPort <> 0 Then
	 ServerAgentID = ServerAgentID + ":" + 
		 	Format(PlatformServerConnectionParameters.ServerAgentPort, "NG=0");
	EndIf;
	
	// Connecting to the server agent
	ServerAgent = COMConnector.ConnectAgent(ServerAgentID);
	Result = New Structure("COMConnector,ServerName,InfoBaseName,ServerAgent,ClusterPort,ServerAgentID");
	Result.COMConnector = COMConnector;
	Result.ServerName = ServerName;
	Result.InfoBaseName = InfoBaseName;
	Result.ServerAgent = ServerAgent;
	Result.ClusterPort = ClusterPort;
	Result.ServerAgentID = ServerAgentID;
	Return Result;
	
EndFunction

// Establishes a connection to a working process.
//
// Parameters:
// PlatformServerConnectionParameters - Structure - platform server connection parameters.
//
// Returns:
// COMConnector - COMObject - COM connector object;
// ServerName - String - server name;
// InfoBaseName - String - infobase name;
// ServerAgent - String - server agent;
// ClusterPort - Number - cluster port;
// ServerAgentID - String - server agent ID;
// WorkingProcess - WorkingProcess - working process.
//
Function ConnectToWorkingProcess(PlatformServerConnectionParameters)
	
	// Connecting to the server agent
	Connection = ConnectToServerAgent(PlatformServerConnectionParameters);
	
	// Finding the required cluster
	For Each Cluster In Connection.ServerAgent.GetClusters() Do
		
		If Cluster.MainPort <> Connection.ClusterPort Then
			Continue;
		EndIf;
		
		WorkingProcessPort = -1;
		Connection.ServerAgent.Authenticate(Cluster, 
			PlatformServerConnectionParameters.ClusterAdministratorName, 
			PlatformServerConnectionParameters.ClusterAdministratorPassword);
		WorkingProcesses = Connection.ServerAgent.GetWorkingProcesses(Cluster);
		For Each WorkingProcess In WorkingProcesses Do
			If WorkingProcess.Running = 1 Then
				WorkingProcessPort = WorkingProcess.MainPort;
				WorkingProcessServerName = WorkingProcess.HostName;
				Break;
			EndIf;
		EndDo;
		If WorkingProcessPort = -1 Then
	 		Raise NStr("en = 'There is no active working process.'");
		EndIf;
		Break;
		
	EndDo;
	
	WorkingProcessID = WorkingProcessServerName + ":" + Format(WorkingProcessPort, "NG=0");
		
	// Connecting to the working process
	WorkingProcess = Connection.COMConnector.ConnectWorkingProcess(WorkingProcessID);
	Connection.Insert("WorkingProcess", WorkingProcess);
	Return Connection;
	
EndFunction

// Establishes a connection to the working process of the current infobase.
//
// Returns:
// COMConnector - COMObject - COM connector object;
// ServerName - String - server name;
// InfoBaseName - String - infobase name;
// ServerAgent - String - server agent;
// ClusterPort - Number - cluster port;
// ServerAgentID - String - server agent ID;
// CurrentInfoBase - IInfoBaseInfo - infobase.
//
Function ConnectToCurrentInfoBase()
	
	InfoBaseAdministrationParameters = InfoBaseConnectionsCached.GetInfoBaseAdministrationParameters();
	Connection = ConnectToWorkingProcess(InfoBaseAdministrationParameters);
	Connection.WorkingProcess.AddAuthentication(InfoBaseAdministrationParameters.InfoBaseAdministratorName, 
		InfoBaseAdministrationParameters.InfoBaseAdministratorPassword);
		
	Bases = Connection.WorkingProcess.GetInfoBases();
	CurrentInfoBase = Undefined;
	For Each Base In Bases Do
		If Base.Name = Connection.InfoBaseName Then
			CurrentInfoBase = Base;
			Break;
		EndIf;
	EndDo;
	If CurrentInfoBase = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en= '%1 infobase is not registered in the server cluster.'"), Connection.InfoBaseName);
	EndIf;
	Connection.Insert("CurrentInfoBase", CurrentInfoBase);
	Return Connection;
	
EndFunction

// Returns active infobase sessions.
//
// Parameters:
// AllExceptCurrent - Boolean - True if the current session must be excluded;
// InfoBaseAdministrationParameters - Structure - see 
// the NewInfoBaseAdministrationParameters function for details.
//
// Returns:
// Structure with the following fields:
// ServerAgent - COMObject - server agent;
// ServersCluster - COMObject - server cluster;
// Sessions - Array - active sessions.
//
Function GetActiveInfoBaseSessions(Val AllExceptCurrent = True, Val InfoBaseAdministrationParameters = Undefined)
	
	Result = New Structure("ServerAgent,ServersCluster,Sessions", Undefined, Undefined, New Array);
	
	// Connecting to the server agent
	Parameters = InfoBaseAdministrationParameters;
	If Parameters = Undefined Then
		Parameters = InfoBaseConnectionsCached.GetInfoBaseAdministrationParameters();
	EndIf;
	Connection = ConnectToServerAgent(Parameters);
	Result.ServerAgent = Connection.ServerAgent; 

	// Finding the required cluster
	For Each Cluster In Connection.ServerAgent.GetClusters() Do
		
		If Cluster.MainPort <> Connection.ClusterPort Then
			Continue;
		EndIf;
		
		Result.ServersCluster = Cluster; 
		Connection.ServerAgent.Authenticate(Cluster, 
			Parameters.ClusterAdministratorName, 
			Parameters.ClusterAdministratorPassword);
		
		// Retrieving the session list
		CurrentSessionNumber = InfoBaseConnectionsCached.SessionTerminationParameters().InfoBaseSessionNumber;
		SessionList = Connection.ServerAgent.GetSessions(Cluster);
		For Each Session In SessionList Do
			If Upper(Session.InfoBase.Name) <> Upper(Connection.InfoBaseName) Then
				Continue;
			EndIf;
			If Not AllExceptCurrent Or (CurrentSessionNumber <> Session.SessionID) Then
				Result.Sessions.Add(Session);
			EndIf;
		EndDo;
		
	EndDo;
	
	Return Result;

EndFunction

// Terminates the infobase session by its number.
//
// Parameters:
// SessionNumberToTerminate - Number - number of session to be terminated.
//
// Returns:
// Boolean - True if the session was terminated successfully.
// 
Function TerminateSession(Val SessionNumberToTerminate)
	
	Result = New Structure("WorkingProcessConnection, Connections", Undefined, New Array);
	
	If FileInfoBase() Then
		Raise NStr("en = 'The active connection list cannot be retrieved in the file mode.'");
	EndIf;
	
#If AtClient Then		
	If CommonUseClient.ClientConnectedViaWebServer() Then
		Raise NStr("en = 'The active connection list cannot be retrieved if the client application connects 
			|to the infobase through the web server.'");
	EndIf;
#EndIf		
	
	// Connecting to the server agent
	InfoBaseAdministrationParameters = InfoBaseConnectionsCached.GetInfoBaseAdministrationParameters();
	Connection = ConnectToServerAgent(InfoBaseAdministrationParameters);
	
	// Finding the required cluster
	For Each Cluster In Connection.ServerAgent.GetClusters() Do
		
		If Cluster.MainPort = Connection.ClusterPort Then
			
			Connection.ServerAgent.Authenticate(Cluster,
				InfoBaseAdministrationParameters.ClusterAdministratorName,
				InfoBaseAdministrationParameters.ClusterAdministratorPassword);
			SessionList = Connection.ServerAgent.GetSessions(Cluster);
			For Each Session In SessionList Do
				If Upper(Session.InfoBase.Name) = Upper(Connection.InfoBaseName) Then
					If Session.SessionID = SessionNumberToTerminate Then
						Connection.ServerAgent.TerminateSession(Cluster, Session);
						Message = StringFunctionsClientServer.SubstituteParametersInString(
								NStr("en= 'The session was terminated. User: %1, Computer: %2, Started: %3, mode: %4.'"),
								Session.UserName,
								Session.Host,
								Session.StartedAt,
								Session.AppID);
						WriteEvent(Message, "Information");
						Return True;
					EndIf;
				EndIf;
			EndDo;
			
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction

// Returns a flag that shows whether the infobase operates in the file mode.
//
// Returns:
// Boolean - True if the infobase operates in the file mode.
//
Function FileInfoBase()
#If AtClient Then	
	If CommonUseCached.CanUseSeparatedData() Then
		Result = StandardSubsystemsClientCached.ClientParameters().FileInfoBase;
	Else
		Result = CommonUse.FileInfoBase();
	EndIf;
#Else
	Result = CommonUse.FileInfoBase();
#EndIf		
	Return Result;
EndFunction

// Writes the event to the event log.
//
// Parameters:
// EventText - String - event text;
// LevelPresentation - String - level presentation;
// Write - Boolean - True if the event must be written to the event log immediately.
//
Procedure WriteEvent(Val EventText, LevelPresentation = "Information", Write = True)
#If AtClient Then	
	CommonUseClient.AddMessageForEventLog(EventLogMessageText(),
		LevelPresentation, EventText,,Write);
#Else
	WriteLogEvent(EventLogMessageText(), 
		PredefinedValue("EventLogLevel." + LevelPresentation),,, EventText);
#EndIf		
EndProcedure