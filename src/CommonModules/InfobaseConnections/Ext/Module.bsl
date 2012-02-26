
////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR LOCKING AND TERMINATION OF CONNECTIONS WITH IB

// Sets IB connections lock.
//
// Parameters
//  MessageText    – String – text, that will be included in error message
//                             on the attempt to connect to a locked
//                             infobase.
//
//  KeyCode - String -   string, that should be added to the parameter
//                             of command line "/uc" or to the parameter of the connection
//                             string "uc", to establish connection with
//                             the infobase despite the lock.
//
// Value returned:
//   Boolean   		– True, if lock is successful.
//              		False, if there is not enogh rights to perform the lock.
//
Function RejectNewConnections(Val MessageText = "",
                             Val KeyCode = "KeyCode") Export
	
	If Not AccessRight("Administration", Metadata) Then
		Return False;
	EndIf;
	
	Block 			= New SessionsLock;
	Block.Use 		= True;
	Block.Begin 	= CurrentDate();
	Block.KeyCode 	= KeyCode;
	Block.Message 	= GenerateBlockMessage(MessageText, KeyCode);
	SetSessionsLock(Block);
	Return True;
	
EndFunction

// Determines, if connections lock is applied on batch
// infobase configuration update
//
Function ConnectionsBlockIsSet() Export
	
	CurrentMode = GetSessionsLock();
	Return CurrentMode.Use;
	
EndFunction

// Determines, if connections lock is applied on batch
// infobase configuration update
//
Function SessionLockParameters() Export
	
	SetPrivilegedMode(True);
	
	CurrentMode = GetSessionsLock();
	
	Return New Structure(
		"Use,Begin,End,Message,UserExitWaitPeriod,SessionsCount,CurrentSessionDate",
		CurrentMode.Use,
		CurrentMode.Begin,
		CurrentMode.End,
		CurrentMode.Message,
		5 * 60, // 5 minutes; interval for user sessions termination
				// infobase lock (in seconds).
		GetInfobaseConnections().Count(),
		CurrentSessionDate()
	);

EndFunction

// Cancel infobase lock.
//
// Value returned:
//   Boolean   – True, if operation is successful.
//              False, not enough of rights.
//
Function PermitUserConnections() Export
	
	If Not AccessRight("Administration", Metadata) Then
		Return False;
	EndIf;
	
	CurrentMode = GetSessionsLock();
	If CurrentMode.Use Then
		NewMode 	= New SessionsLock;
		NewMode.Use = False;
		SetSessionsLock(NewMode);
	EndIf;
	Return True;
	
EndFunction	

// Disable all active IB connections (except current session).
//
// Parameters
//  InfobaseAdministrationParameters  – Structure – parameters of IB administration.
//
// Value returned:
//   Boolean  				    – connection termination result
//
Function CloseInfobaseConnection(InfobaseAdministrationParameters, ConnectionNumber, Message) Export
	
	If GetInfobaseConnections().Count() <= 1 Then
		Return True; // All users except current session users are terminated
	EndIf;
	
	If CommonUse.FileInformationBase() Then
		Message = GetInfobaseConnectionsTitles(TextFailedToTerminateUserSessions());
		WriteLogEvent(EventLogMessage(), 
			EventLogLevel.Warning, , , Message);
		Return False; // Impossible to terminate user sessions in file mode
	EndIf;
	
	Try
		Return TerminateUserSession(InfobaseAdministrationParameters, ConnectionNumber);
	Except
		Message = DetailErrorDescription(ErrorInfo());
		WriteLogEvent(EventLogMessage(), EventLogLevel.Error, , , Message);
		Return False;
	EndTry;
	
EndFunction

// Tries to connect to a server cluster and to get the list
// of active IB connections using specified administration parameters.
//
// Parameters
//  InfobaseAdministrationParameters  – Structure  – IB administration parameters
//  DisplayMessages             – Boolean    – allow output of interactive messages.
//
// Value returned:
//   Boolean   					– True, if check has completed successfully.
//
Procedure CheckInfobaseAdministrationParameters(InfobaseAdministrationParameters,
										  Val DetailedErrorMessage = False) Export
	
	Try
		Connections = GetActiveInfobaseConnections(InfobaseAdministrationParameters);
	Except
		Message = NStr("en = 'Unable to connect to servers'' cluster'");
		WriteLogEvent(EventLogMessage(), EventLogLevel.Error,,,
			Message + Chars.LF + ErrorDescription());
		If DetailedErrorMessage Then
			Message = Message + " " + ErrorInfo().Description;
		EndIf;
		Raise Message;
	EndTry;
	
EndProcedure

// Terminate active sessions.
//
// Value returned:
//   Boolean   - String error code; empty string - in case of successful termination.
//
Function CloseInfobaseConnectionsByOptionsLaunch(Val LaunchParameter) Export

	InfobaseAdministrationParameters = InfobaseConnections.GetInfobaseAdministrationParameters();
	LaunchParameters = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(LaunchParameter,";");
	
	If LaunchParameters.Count() > 1 Then
		InfobaseAdministrationParameters.IBAdministratorName = Upper(LaunchParameters[1]);
	EndIf;
	
	If LaunchParameters.Count() > 2 Then
		InfobaseAdministrationParameters.IBAdministratorPassword = Upper(LaunchParameters[2]);
	EndIf;
	
	Result = CloseInfobaseConnections(InfobaseAdministrationParameters);
	
	Return Result;
	
EndFunction

// Disable all active IB connections (except current session).
//
// Parameters
//  InfobaseAdministrationParameters  – Structure – parameters of IB administration.
//
// Value returned:
//   Boolean   					– Connection closing result
//
Function CloseInfobaseConnections(InfobaseAdministrationParameters) Export
	
	If GetInfobaseConnections().Count() <= 1 Then
		Return True;	// All users except current session users are terminated
	EndIf;
	
	If CommonUse.FileInformationBase() Then
		Message = GetInfobaseConnectionsTitles(TextFailedToTerminateUserSessions());
		WriteLogEvent(EventLogMessage(), 
			EventLogLevel.Warning, , , Message);
		Return False; // Impossible to close connections in file mode
	EndIf;
	
	Try
		Connections = GetActiveInfobaseConnections(InfobaseAdministrationParameters);
		For each Connection In Connections.Connections Do
			// Drop Connections with IB
			StrMessages =
			StringFunctionsClientServer.SubstitureParametersInString(
			    NStr("en = 'Closing connection: User %1, computer %2, connected at %3, mode %4 '"),
			    Connection.UserName,
			    Connection.HostName,
			    Connection.ConnectedAt,
			    Connection.AppID );
			
			WriteLogEvent(EventLogMessage(), 
				EventLogLevel.Information, , , StrMessages);
			Connections.ConnectionWithRunningProcess.TerminateUserSession(Connection);
		EndDo;
		
		Return GetInfobaseConnections().Count() <= 1;
	Except
		ErrorDescription = DetailErrorDescription(ErrorInfo());
		WriteLogEvent(EventLogMessage(), 
			EventLogLevel.Error, , , ErrorDescription);
		Return False;
	EndTry;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// SERVICE FUNCTIONS
//

// Returns message text about sessions lock.
//
Function GenerateBlockMessage(Val Message, Val KeyCode) Export

	InfobaseAdministrationParameters = GetInfobaseAdministrationParameters();
	IsFileMode 			   = False;
	PathToIB 				   = InfobasePath(IsFileMode, InfobaseAdministrationParameters.ServersClusterPort);
	InfobasePathString = ?(IsFileMode = True, "/F", "/S") + PathToIB; 
	MessageText = "";                                 
	If Not IsBlankString(Message) Then
		MessageText = Message + Chars.LF + Chars.LF;
	EndIf;
	
	MessageText = MessageText +
	    NStr("en = '%1
              |To unlock the infobase you must use the servers cluster console or run 1C:Enterprise using parameter:
              |ENTERPRISE %2 /CPermitUserConnections /UC%3'");
	
	MessageText = StringFunctionsClientServer.SubstitureParametersInString(
		MessageText,
		InfobaseConnectionsClientServer.TextForAdministrator(),
		InfobasePathString,
		NStr("en = '<authorization code>'"));
	
	Return MessageText;
	
EndFunction

// Returns text constant for generating the messages.
// Is used for localization purposes.
//
Function TextFailedToTerminateUserSessions() Export
	
	Return NStr("en = 'Failed to terminate user sessions:'");
	
EndFunction

// Returns text constant for generating the messages.
//
Function EventLogMessage()
	
	Return NStr("en = 'User Session Termination'");
	
EndFunction

Function NewInfobaseAdministrationParameters(Val IBAdministratorName 			= "",
	                                         Val IBAdministratorPassword 		= "",
	                                         Val ClusterAdministratorName 		= "",
	                                         Val ClusterAdministratorPassword 	= "",
	                                         Val ServersClusterPort 			= 0, 
	                                         Val ServerAgentPort 				= 0) Export
	
	Return New Structure("IBAdministratorName,
						 |IBAdministratorPassword,
						 |ClusterAdministratorName,
						 |ClusterAdministratorPassword,
						 |ServersClusterPort,
						 |ServerAgentPort",
						 IBAdministratorName,
						 IBAdministratorPassword,
						 ClusterAdministratorName,
						 ClusterAdministratorPassword,
						 ServersClusterPort,
						 ServerAgentPort);
	
EndFunction

Function GetInfobaseConnectionsTitles(Val Message) Export
	
	Result = Message;
	For Each Connection In GetInfobaseConnections() Do
		If Connection.ConnectionNumber <> InfobaseConnectionNumber() Then
			Result = Result + Chars.LF + " - " + Connection;
		EndIf;
	EndDo; 
	
	Return Result;
	
EndFunction

// Get saved parameters of server cluster administration.
//
Function GetInfobaseAdministrationParameters() Export

	SettingsStructure = Constants.InfobaseAdministrationParameters.Get().Get();
	If TypeOf(SettingsStructure) <> Type("Structure") Then
		Return NewInfobaseAdministrationParameters();
	Else
		Return SettingsStructure;
	EndIf;
	
EndFunction

Procedure WriteInfobaseAdministrationParameters(Parameters) Export
	
	Constants.InfobaseAdministrationParameters.Set(New ValueStorage(Parameters));
	
EndProcedure

Function GetActiveInfobaseConnections(LockSetting, Val AllExceptCurrent = True)
	
	Result = New Structure("ConnectionWithRunningProcess, Connections", Undefined, New Array);
	
	If CommonUse.FileInformationBase() Then
		Raise NStr("en = 'It is impossible to get list if active connections in File Mode'");
	EndIf;
	
	ConnectionStringSubstrings = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(
		InfobaseConnectionString(), ";");
	
	ServerName  = StringFunctionsClientServer.RemoveQuotes(Mid(ConnectionStringSubstrings[0], 7));
	InfobaseName      = StringFunctionsClientServer.RemoveQuotes(Mid(ConnectionStringSubstrings[1], 6));
	
	COMConnector = New COMObject(CommonUse.COMConnectorName());
	
	PortSeparator = Find(ServerName, ":");
	If PortSeparator > 0 Then
		ServerNameAndPort = ServerName;
		ServerName = Mid(ServerNameAndPort, 1, PortSeparator - 1);
		ClusterPortNumber = Number(Mid(ServerNameAndPort, PortSeparator + 1));
	ElsIf LockSetting.ServersClusterPort <> 0 Then
		ClusterPortNumber = LockSetting.ServersClusterPort;
	Else
		ClusterPortNumber = COMConnector.RMngrPortDefault;
	EndIf;
	
	ServerAgentID = ServerName;
	If LockSetting.ServerAgentPort <> 0 Then
	      ServerAgentID = ServerAgentID + ":"
		  + Format(LockSetting.ServerAgentPort, "NG=0");
	EndIf;
	
	// Connected to the server agent
	ServerAgent = COMConnector.ConnectAgent(ServerAgentID);
	
	// Find cluster that we need
	For each Cluster In ServerAgent.GetClusters() Do
		
		If Cluster.MainPort <> ClusterPortNumber Then
			Continue;
		EndIf;
		
		ServerAgent.Authenticate(Cluster, LockSetting.ClusterAdministratorName, 
			LockSetting.ClusterAdministratorPassword);
		
		// Get list of active processes
		WorkingProcesses = ServerAgent.GetWorkingProcesses(Cluster);
		For each WorkingProcess In WorkingProcesses Do
			
			If WorkingProcess.Running <> 1 Then
				Continue;
			EndIf;
			
			// For each active process create connection with active process
			ConnectToWorkProcess = COMConnector.ConnectWorkingProcess("tcp://" + WorkingProcess.HostName + 
				":" + Format(WorkingProcess.MainPort, "NG=0"));
			ConnectToWorkProcess.AddAuthentication(LockSetting.IBAdministratorName, 
				LockSetting.IBAdministratorPassword);
			Result.ConnectionWithRunningProcess = ConnectToWorkProcess;
			// Get IB list of active process
			Infobases = ConnectToWorkProcess.GetInfobases();
			For Each Infobase In Infobases Do
				// Looking for the required base
				If Upper(Infobase.Name) <> Upper(InfobaseName) Then
					Continue;
				EndIf;
					
				// Get array of IB connections
				Connections = ConnectToWorkProcess.GetInfobaseConnections(Infobase);
				For each Connection In Connections Do
					If Not AllExceptCurrent OR (InfobaseConnectionNumber() <> Connection.ConnID) Then
							Result.Connections.Add(Connection);
					EndIf;
				EndDo;
			EndDo;
			
		EndDo;
		
	EndDo;
	
	Return Result;

EndFunction

Function TerminateUserSession(ConnectionTo1CEnterpriseServerParameters, Val ConnectionNumberToDrop)
	
	Result = New Structure("ConnectionWithRunningProcess, Connections", Undefined, New Array);
	
	If CommonUse.FileInformationBase() Then
		Raise NStr("en = 'It is impossible to get list if active connections in File Mode'");
	EndIf;
	
	ConnectionStringSubstrings = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(
		InfobaseConnectionString(), ";");
	
	ServerName = StringFunctionsClientServer.RemoveQuotes(Mid(ConnectionStringSubstrings[0], 7));
	InfobaseName = StringFunctionsClientServer.RemoveQuotes(Mid(ConnectionStringSubstrings[1], 6));
	
	COMConnector = New COMObject(CommonUse.COMConnectorName());
	
	PortSeparator = Find(ServerName, ":");
	If PortSeparator > 0 Then
		ServerNameAndPort = ServerName;
		ServerName = Mid(ServerNameAndPort, 1, PortSeparator - 1);
		ClusterPortNumber = Number(Mid(ServerNameAndPort, PortSeparator + 1));
	ElsIf ConnectionTo1CEnterpriseServerParameters.ServersClusterPort <> 0 Then
		ClusterPortNumber = ConnectionTo1CEnterpriseServerParameters.ServersClusterPort;
	Else
		ClusterPortNumber = COMConnector.RMngrPortDefault;
	EndIf;
	
	ServerAgentID = ServerName;
	If ConnectionTo1CEnterpriseServerParameters.ServerAgentPort <> 0 Then
	    ServerAgentID = ServerAgentID + ":"
			+ Format(ConnectionTo1CEnterpriseServerParameters.ServerAgentPort, "NG=0");
	EndIf;
	
	// Connected to the server agent
	ServerAgent = COMConnector.ConnectAgent(ServerAgentID);
	
	// Find cluster that we need
	For each Cluster In ServerAgent.GetClusters() Do
		
		If Cluster.MainPort <> ClusterPortNumber Then
			Continue;
		EndIf;
		
		ServerAgent.Authenticate(Cluster, ConnectionTo1CEnterpriseServerParameters.ClusterAdministratorName, 
			ConnectionTo1CEnterpriseServerParameters.ClusterAdministratorPassword);
		
		// Get list of active processes
		WorkingProcesses = ServerAgent.GetWorkingProcesses(Cluster);
		For each WorkingProcess In WorkingProcesses Do
			
			If WorkingProcess.Running <> 1 Then
				Continue;
			EndIf;
			
			// For each active process create connection with active process
			ConnectToWorkProcess = COMConnector.ConnectWorkingProcess("tcp://" + WorkingProcess.HostName + 
				":" + Format(WorkingProcess.MainPort, "NG=0"));
			ConnectToWorkProcess.AddAuthentication(ConnectionTo1CEnterpriseServerParameters.IBAdministratorName, 
				ConnectionTo1CEnterpriseServerParameters.IBAdministratorPassword);
			// Get IB list of active process
			Infobases = ConnectToWorkProcess.GetInfobases();
			
			For each Infobase In Infobases Do
				// Looking for the required base
				If Upper(Infobase.Name) <> Upper(InfobaseName) Then
					Continue;
				EndIf;
				
				// Get array of IB connections
				Connections = ConnectToWorkProcess.GetInfobaseConnections(Infobase);
				For Each Connection In Connections Do
					If ConnectionNumberToDrop = Connection.ConnID Then
						ConnectToWorkProcess.TerminateUserSession(Connection);
						StrMessage =
						StringFunctionsClientServer.SubstitureParametersInString(
							NStr("en = 'Session terminated: User %1, Computer %2, Connected %3, Mode %4'"),
							Connection.UserName,
							Connection.HostName,
							Connection.ConnectedAt,
							Connection.AppID);
						WriteLogEvent(EventLogMessage(), EventLogLevel.Information, , , StrMessage);
						Return True;
					EndIf;
				EndDo;
			EndDo;
			
		EndDo;
		
	EndDo;
	
	Return False;
	
EndFunction

// Get ID connection string, if not standard port of servers cluster is specified.
//
// Parameters
//  ServersClusterPort  - Number - not standard port of servers cluster
//
// Value returned:
//   String  		    - IB connection string
//
Function GetInfobaseConnectionString(Val ServersClusterPort = 0) Export

	Result = InfobaseConnectionString();
	If CommonUse.FileInformationBase() Or (ServersClusterPort = 0) Then
		Return Result;
	EndIf; 
	
	ConnectionStringSubstrings  = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Result, ";");
	ServerName 					= StringFunctionsClientServer.RemoveQuotes(Mid(ConnectionStringSubstrings[0], 7));
	InfobaseName      				= StringFunctionsClientServer.RemoveQuotes(Mid(ConnectionStringSubstrings[1], 6));
	Result = "Srvr=" + """" + ServerName + ":"
		   + Format(ServersClusterPort, "NG=0") + """;"
		   + "Ref=" + """" + InfobaseName + """;";
	Return Result;

EndFunction

// Determine path to the infobase
//
Function InfobasePath(IsFileMode = Undefined, Val ServersClusterPort = 0) Export
	
	ConnectionString = GetInfobaseConnectionString(ServersClusterPort);
	
	SearchPosition = Find(Upper(ConnectionString), "FILE=");
	
	If SearchPosition = 1 Then // file mode
		
		InfobasePath = Mid(ConnectionString, 6, StrLen(ConnectionString) - 6);
		IsFileMode = True;
		
	Else
		IsFileMode = False;
		
		SearchPosition = Find(Upper(ConnectionString), "SRVR=");
		
		If Not (SearchPosition = 1) Then
			Return Undefined;
		EndIf;
		
		SemicolonPosition = Find(ConnectionString, ";");
		CopyStartPosition = 6 + 1;
		CopyEndPosition = SemicolonPosition - 2; 
		
		ServerName = Mid(ConnectionString, CopyStartPosition, CopyEndPosition - CopyStartPosition + 1);
		
		ConnectionString = Mid(ConnectionString, SemicolonPosition + 1);
		
		// position of the server name
		SearchPosition = Find(Upper(ConnectionString), "REF=");
		
		If Not (SearchPosition = 1) Then
			Return Undefined;
		EndIf;
		
		CopyStartPosition = 6;
		SemicolonPosition = Find(ConnectionString, ";");
		CopyEndPosition = SemicolonPosition - 2;
		
		InfobaseNameAtServer = Mid(ConnectionString, CopyStartPosition, CopyEndPosition - CopyStartPosition + 1);
		
		InfobasePath = """" + ServerName + "\" + InfobaseNameAtServer + """";
	EndIf;
	
	Return InfobasePath;
	
EndFunction
