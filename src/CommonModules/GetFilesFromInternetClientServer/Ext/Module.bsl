
////////////////////////////////////////////////////////////////////////////////
// Get files from internet subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Export internal procedures and functions.

// Receives files from the internet.
//
// Parameters:
//  URL               - String - file URL in the following format:
//                      [Protocol://]<Server>/<Path to the file on server>
//  User              - String - user on behalf of which the connection is established.
//  Password          - String - password of the user on behalf of which the connection
//                      is established.
//  Port              - Number - port that is used for establishing the connection.
//  SecureConnection  - Boolean - in case of HTTP this flag shows
//                      whether a secure HTTPS connection is used.
//  PassiveConnection - Boolean - in case of FTP this flag shows 
//                      whether the connection mode is passive or active.
//  SavingSettings    - Map - contains the following parameters for saving
//                      the downloaded file: 
//  Storage           - String - can take on the following values:
//                       "Client" - save file at the client.
//                       "Server" - save file at the server.
//                       "TempararyStorage" - save file to the temporary storage.
//
// Returns:
//  Structure with the following key and value:
//   Success - Boolean - flag that shows whether the file has been saved successfully.
//   String  - String - it can contain a path to the file, an address in the temporary 
//             storage, or an error message in case of failure.
//
Function PrepareFileReceiving(Val URL, Val User = Undefined, Val Password = Undefined,
	Val Port = Undefined, Val SecureConnection = False, Val PassiveConnection = False, 
	Val SavingSettings) Export
	
	ConnectionSettings = New Map;
	ConnectionSettings.Insert("User", User);
	ConnectionSettings.Insert("Password", Password);
	ConnectionSettings.Insert("Port", Port);
	
	Protocol = SplitURL(URL).Protocol;
	
	If Protocol = "ftp" Then
		ConnectionSettings.Insert("PassiveConnection", PassiveConnection);
	Else
		ConnectionSettings.Insert("SecureConnection", SecureConnection);
	EndIf;
	
	#If Client Then
		ProxyServerSettings = StandardSubsystemsClientCached.ClientParameters().ProxyServerSettings;
	#Else
		ProxyServerSettings = GetFilesFromInternet.GetServerProxySettings();
	#EndIf
	
	If ProxyServerSettings = Undefined Or ProxyServerSettings.Get("UseProxy") <> True Then
		ProxyServerSettings = GetEmptyProxyServerSettings();
	EndIf;
	
	Result = GetFileFromInternet(URL, SavingSettings, ConnectionSettings, ProxyServerSettings);
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.

// Receives a file from the internet.
//
// Parameters:
//  URL                      - String - file URL in the following format:
//                             [Protocol://]<Server>/<Path to the file on server>
//
//  ConnectionSettings       - Map - map with the following fields:
//   User                    - String - user on behalf of which the connection is
//                             established.
//   Password                - String - password of the user on behalf of which the
//                             connection is established.
//   Port                    - Number - port that is used for establishing the
//                             connection.
//   SecureConnection        - Boolean - in case of HTTP this flag shows
//                             whether a secure HTTPS connection is used.
//   PassiveConnection       - Boolean - in case of FTP this flag shows 
//                             whether the connection mode is passive or active.
//
//  ProxySettings            - Map - map with the following fields:
//   UseProxy                - flag that shows whether the proxy server is used.
//   BypassProxyForLocalURLs - flag that shows whether the proxy server is bypassed
//                             for the local addresses.
//   UseSystemSettings       - flag that shows whether system proxy server settings are
//                             used. 
//   Server                  - proxy server address.
//   Port                    - proxy server port.
//   User                    - name of the user for authorization at the proxy server.
//   Password                - password of the user for authorization at the proxy
//                             server.
//
// SavingSettings            - String - contains parameters for saving the downloaded
//                             file.
//  Storage                  - string - can take on the following values:
//                             "Client" - save file at the client.
//                             "Server" - save file at the server.
//                             "TempararyStorage" - save file to the temporary storage.
//  Path                     - String, Optional - path to a directory at client or  
//                             at server,	or an address in the temporary storage.
//                             If it is not specified, it is generated automatically.
//
// Returns:
//  Structure with the following key and value:
//  Success - Boolean - flag that shows whether the file has been saved successfully.
//  String  - String - it can contain a path to the file, an address in the temporary
//            storage, or an error message in case of failure.
//
Function GetFileFromInternet(Val URL, Val SavingSettings, Val ConnectionSettings = Undefined,
	Val ProxySettings = Undefined)
	
	// Declaring variables before their first use as the Property 
	// method parameter.
	Var ServerName, UserName, Password, Port,
	 SecureConnection,PassiveConnection,
	 PathToFileAtServer, Protocol;
	
	SeparatedURL = SplitURL(URL);
	
	ServerName = SeparatedURL.ServerName;
	PathToFileAtServer = SeparatedURL.PathToFileAtServer;
	Protocol = SeparatedURL.Protocol;
	
	SecureConnection = ConnectionSettings.Get("SecureConnection");
	PassiveConnection = ConnectionSettings.Get("PassiveConnection");
	
	UserName = ConnectionSettings.Get("User");
	UserPassword = ConnectionSettings.Get("Password");
	Port = ConnectionSettings.Get("Port");
	
	If Port = Undefined Then
		FullURLStructure = URLStructure(URL);
		
		If Not IsBlankString(FullURLStructure.Port) Then
			ServerName = FullURLStructure.Host;
			Port = FullURLStructure.Port;
		EndIf;
	EndIf;
	
	ProxySettings = ?(ProxySettings = Undefined, GetEmptyProxyServerSettings(), ProxySettings);
	Proxy = GenerateProxy(ProxySettings, Protocol);
	
	If Protocol = "ftp" Then
		Try
			Connection = New FTPConnection(ServerName, Port, UserName, UserPassword, Proxy, PassiveConnection);
		Except
			ErrorInfo = ErrorInfo();
			ErrorMessage = NStr("en = 'Error creating FTP connection with %1 server:'") + Chars.LF + "%2";
			GetFilesFromInternet.WriteErrorToEventLog(
				StringFunctionsClientServer.SubstituteParametersInString(ErrorMessage, ServerName,
					DetailErrorDescription(ErrorInfo)));
			ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(ErrorMessage, ServerName,
					BriefErrorDescription(ErrorInfo));
			Return GenerateResult(False, ErrorMessage);
		EndTry;
	Else
		Try
			Connection = New HTTPConnection(ServerName, Port, UserName, UserPassword, Proxy, SecureConnection);
		Except
			ErrorInfo = ErrorInfo();
			ErrorMessage = NStr("en = 'Error creating FTP connection with %1 server:'") + Chars.LF + "%2";
			GetFilesFromInternet.WriteErrorToEventLog(
				StringFunctionsClientServer.SubstituteParametersInString(ErrorMessage, ServerName, 
					DetailErrorDescription(ErrorInfo)));
			ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(ErrorMessage, ServerName, 
					BriefErrorDescription(ErrorInfo));
			Return GenerateResult(False, ErrorMessage);
		EndTry;
	EndIf;
	
	If SavingSettings["Path"] <> Undefined Then
		PathForSaving = SavingSettings["Path"];
	Else
		#If Not WebClient Then
			PathForSaving = GetTempFileName();
		#EndIf
	EndIf;
	
	Try
		Connection.Get(PathToFileAtServer, PathForSaving);
	Except
		ErrorInfo = ErrorInfo();
		ErrorMessage = NStr("en = 'Error recieving file from %1 server:'") + Chars.LF + "%2";
		GetFilesFromInternet.WriteErrorToEventLog(
			StringFunctionsClientServer.SubstituteParametersInString(ErrorMessage, ServerName, 
				DetailErrorDescription(ErrorInfo)));
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(ErrorMessage, ServerName, 
				BriefErrorDescription(ErrorInfo));
		Return GenerateResult(False, ErrorMessage);
	EndTry;
	
	// Stoting a file according to settings 
	If SavingSettings["Storage"] = "TempStorage" Then
		UniqueKey = New UUID;
		Address = PutToTempStorage (PathForSaving, UniqueKey);
		Return GenerateResult(True, Address);
	ElsIf SavingSettings["Storage"] = "Client"
	 Or SavingSettings["Storage"] = "Server" Then
		Return GenerateResult(True, PathForSaving);
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// Generates a proxy by proxy settings.
// 
// Parameters: 
// ProxyServerSettings      - Map - map with the following fields:
//  UseProxy                - flag that shows whether the proxy server is used.
//  BypassProxyForLocalURLs - flag that shows whether the proxy server is bypassed
//                            for the local addresses.
//  UseSystemSettings       - flag that shows whether system proxy server settings is
//                            used. 
//  Server                  - proxy server address.
//  Port                    - proxy server port.
//  User                    - name of the user for authorization at the proxy server.
//  Password                - password of the user for authorization at the proxy
//                            server.
// Protocol                 - string - protocol for which proxy server parameters are  
//                            set, for example, "http", "https", "ftp".
// 
Function GenerateProxy(ProxyServerSettings, Protocol)
	
	If ProxyServerSettings <> Undefined Then
		UseProxy = ProxyServerSettings.Get("UseProxy");
		UseSystemSettings = ProxyServerSettings.Get("UseSystemSettings");
		If UseProxy Then
			If UseSystemSettings Then
			// System proxy server settings
				Proxy = New InternetProxy(True);
			Else
			// Manual proxy server settings
				Proxy = New InternetProxy;
				Proxy.Set(Protocol, ProxyServerSettings["Server"], ProxyServerSettings["Port"]);
				Proxy.BypassProxyForLocalURLs = ProxyServerSettings["BypassProxyForLocalURLs"];
				Proxy.User = ProxyServerSettings["User"];
				Proxy.Password = ProxyServerSettings["Password"];
			EndIf;
		Else
			// Do not use proxy server	
			Proxy = New InternetProxy(False);
		EndIf;
	Else
		Proxy = Undefined;
	EndIf;
	
	Return Proxy;
	
EndFunction

// Splits URL into components: protocol, server, path to the resource.
//
// Parameters:
//  URL - String - link to the resource in the internet.
//
// Returns:
//  Structure with the following fields:
//   Protocol           - String - protocol that will be used to get access to the
//                        resource.
//   ServerName         - String - server where the resource is placed.
//   PathToFileAtServer - String - path to the resource at the server.
//
Function SplitURL(Val URL)
	
	URLStructure = URLStructure(URL);
	
	Result = New Structure;
	Result.Insert("Protocol", ?(IsBlankString(URLStructure.Schema),"http",URLStructure.Schema));
	Result.Insert("ServerName", URLStructure.ServerName);
	Result.Insert("PathToFileAtServer", URLStructure.PathAtServer);
	
	Return Result;
	
EndFunction

// Splits the URL string into components according to RFC 3986 and returns it as a structure.
//
// Parameters:
// URLString - String - link to the resource in the following format:
// 
//  <schema>://<login>:<password>@<host>:<port>/<path>?<parameters>#<anchor>
//             \________________/ \___________/
//                     |                |
// 	             authorization     server name
//               \____________________________/ \___________________________/
//                              |                             |
//                     connection string                path at server
//
// Returns:
//  Structure with the following fields:
//   Schema       - String.
//   Login        - String. 
//   Password     - String.
//   ServerName   - String.
//   Host         - String. 
//   Port         - String. 
//   PathAtServer - String.
//
Function URLStructure(Val URLString)
	
	URLString = TrimAll(URLString);
	
	// Schema
	Schema = "";
	Position = Find(URLString, "://");
	If Position > 0 Then
		Schema = Lower(Left(URLString, Position - 1));
		URLString = Mid(URLString, Position + 3);
	EndIf;

	// Connection string and path at server
	ConnectionString = URLString;
	PathAtServer = "";
	Position = Find(ConnectionString, "/");
	If Position > 0 Then
		PathAtServer = Mid(ConnectionString, Position + 1);
		ConnectionString = Left(ConnectionString, Position - 1);
	EndIf;
		
	// User information and server name 
	AuthorizationString = "";
	ServerName = ConnectionString;
	Position = Find(ConnectionString, "@");
	If Position > 0 Then
		AuthorizationString = Left(ConnectionString, Position - 1);
		ServerName = Mid(ConnectionString, Position + 1);
	EndIf;
	
	// Login and password
	Login = AuthorizationString;
	Password = "";
	Position = Find(AuthorizationString, ":");
	If Position > 0 Then
		Login = Left(AuthorizationString, Position - 1);
		Password = Mid(AuthorizationString, Position + 1);
	EndIf;
	
	// Host and port
	Host = ServerName;
	Port = "";
	Position = Find(ServerName, ":");
	If Position > 0 Then
		Host = Left(ServerName, Position - 1);
		Port = Mid(ServerName, Position + 1);
	EndIf;
	
	Result = New Structure;
	Result.Insert("Schema", Schema);
	Result.Insert("Login", Login);
	Result.Insert("Password", Password);
	Result.Insert("ServerName", ServerName);
	Result.Insert("Host", Host);
	Result.Insert("Port", Port);
	Result.Insert("PathAtServer", PathAtServer);
	
	Return Result;
	
EndFunction

// Fills the structure with parameters.
//
// Parameters:
//  State              - Boolean - flag that shows whether the operation completed
//                       successfully.
//  MessagePath        - String - path or error message. 
//
// Returns:
//  Structure with the following fields:
//   Success field - Boolean.
//   Path field    - String.
//
Function GenerateResult(Val State, Val MessagePath)
	
	Result = New Structure("State");
	
	Result.State = State;

	If State Then
		Result.Insert("Path", MessagePath);
	Else
		Result.Insert("ErrorMessage", MessagePath);
	EndIf;
	
	Return Result;
	
EndFunction

// Returns empty proxy server settings that means that the proxy server is not used.
//
// Returns:
// Structure with the following fields:
// 	UseProxy                - flag that shows whether the proxy server is used.
// 	BypassProxyForLocalURLs - flag that shows whether the proxy server is bypassed
// 	                          for the local addresses.
// 	UseSystemSettings       - flag that shows whether system proxy server settings is
//                             used. 
// 	Server                  - proxy server address.
// 	Port                    - proxy server port.
// 	User                    - name of the user for authorization at the proxy server.
// 	Password                - password of the user for authorization at the proxy
//                             server.
//
Function GetEmptyProxyServerSettings()
	
	ProxyServerSettings = New Map;
	ProxyServerSettings.Insert("UseProxy", False);
	ProxyServerSettings.Insert("User", "");
	ProxyServerSettings.Insert("Password", "");
	ProxyServerSettings.Insert("Port", "");
	ProxyServerSettings.Insert("Server", "");
	ProxyServerSettings.Insert("BypassProxyForLocalURLs", False);
	ProxyServerSettings.Insert("UseSystemSettings", False);
	Return ProxyServerSettings;	
	
EndFunction
