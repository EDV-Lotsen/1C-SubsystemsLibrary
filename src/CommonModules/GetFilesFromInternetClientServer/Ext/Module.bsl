
// Function for getting file from the internet.
//
// Parameters:
// URL           	- String - of url file in format:
//                 [Protocol://]<Server>/<Path to the file at server>
// User  - string 	- User, under whose name connection is established
// Password         - String - user password under whose name connection is established
// Port         	- Number  - connection is established on this server port
// SecurePassiveConnection
//
// SaveSetting 		- Map - contains parameters for saving downloaded file
//                 			keys:
//     StoragePlace - String 		- may contain
//                        "Client"  - client,
//                        "Server"  - server,
//                        "TemporaryStorage" - temporary storage
//             Path - String (optional parameter) -
//                        path to the directory at client or at server or address in temporary storage
//                        if not specified, it will be generated automatically
//
// Value returned:
// Structure
// success  - Boolean - operation success or failure
// string 	- String  - if success it's string - file save path,
//                   or address in temporary storage,
//                   if failure - it's error message
//
Function PrepareFileReceiving(Val URL,
							  Val User				= Undefined,
							  Val Password			= Undefined,
							  Val Port				= Undefined,
							  Val SecureConnection	= False,
							  Val PassiveConnection	= False,
							  Val SaveSetting) Export
	
	ConnectionOptions = New Map;
	ConnectionOptions.Insert("User",	 User);
	ConnectionOptions.Insert("Password", Password);
	ConnectionOptions.Insert("Port",	 Port);
	
	Protocol = SplitURL(URL).Protocol;
	
	If Protocol = "ftp" Then
		ConnectionOptions.Insert("PassiveConnection", PassiveConnection);
	Else
		ConnectionOptions.Insert("SecureConnection",  SecureConnection);
	EndIf;
	
#If AtClient Then
	ProxyServerConfiguration = StandardSubsystemsClientSecondUse.ClientParameters().ProxyServerSettings;
#Else
	ProxyServerConfiguration = GetFilesFromInternet.GetProxySettingsAt1CEnterpriseServer();
#EndIf
	
	If ProxyServerConfiguration <> Undefined
	   And ProxyServerConfiguration["UseProxy"] = False Then
		ProxyServerConfiguration = Undefined;
	EndIf;
	
	Result = GetFileFromInternet(URL, SaveSetting, ConnectionOptions, ProxyServerConfiguration);
	
	Return Result;
	
EndFunction

// Function for getting file from the internet.
//
// Parameters:
// URL           - string - of url file in format:
//                 [Protocol://]<Server>/<Path to the file at server>
//
// ConnectionOptions - Map -
//                 SecureConnection*    - Boolean - connection is secure
//                 PassiveConnection*   - Boolean - connection is passive
//                 User 				- String  - user, under whose name connection is established
//                 Password       		- String  - user password under whose name connection is established
//                 Port         		- Number  - connection is established on this server port
//                 * 					- Selfexcluding keys
//
// Proxy        - Map -
//                 keys:
//                 BypassProxyOnLocal	- String -
//                 Server       		- Proxy	 -server address
//                 Port         		- Proxy	 -server port
//                 User 				- User name for authorization on proxy-server
//                 Password       		- User password
//
// SaveSetting - map - contains parameters for saving downloaded file
//                 keys:
//                 StoragePlace 			 - String - may contain
//                        "Client" 			 - Client,
//                        "Server" 			 - Server,
//                        "TemporaryStorage" - Temporary storage
//                 Path - string (optional parameter) -
//                        path to the directory at client or at server or address in temporary storage
//                        if not specified, it will be generated automatically
//
// Value returned:
// Structure
// success  - Boolean - operation success or failure
// string   - String  - if success it's string - file save path,
//                   	or address in temporary storage,
//                   	if failure - it's error message
//
Function GetFileFromInternet(Val URL,
                             Val SaveSetting,
                             Val ConnectionOptions = Undefined,
                             Val Proxy = Undefined)
	
	// Declaration of variables before first use
	// of method Property parameter, on analysis of file get parameters
	// from ReceivingParameters. Contain values of the passed file get parameters
	Var ServerName, UserName, Password, Port,
	      SecureConnection, PassiveConnection,
	      FilePathAtServer, Protocol;
	
	URLSplitted = SplitURL(URL);
	
	ServerName        = URLSplitted.ServerName;
	FilePathAtServer  = URLSplitted.FilePathAtServer;
	Protocol          = ?(URLSplitted.Protocol=Undefined, "", URLSplitted.Protocol);
	
	SecureConnection  = ConnectionOptions.Get("SecureConnection");
	PassiveConnection = ConnectionOptions.Get("PassiveConnection");
	
	UserName      	  = ConnectionOptions.Get("User");
	PasswordOfUser    = ConnectionOptions.Get("Password");
	Port              = ConnectionOptions.Get("Port");
	
	If Not ValueIsFilled(URLSplitted.Protocol) Then
		If SecureConnection <> Undefined Then
			If SecureConnection Then
				Protocol = "https";
			Else
				Protocol = "http";
			EndIf;
		ElsIf PassiveConnection <> Undefined Then
			If PassiveConnection Then
				Protocol = "ftp";
			EndIf;
		EndIf;
	EndIf;
	
	Protocol = ?(ValueIsFilled(Protocol), Protocol, "http");
	
	Proxy = ?(Proxy = Undefined, Undefined, GenerateProxy(Proxy, Protocol));
	
	If Protocol = "ftp" Then
		Try
			Connection = New FTPConnection(ServerName, Port, UserName, PasswordOfUser, Proxy, PassiveConnection);
		Except
			ErrorInfo = ErrorInfo();
			ErrorMessage = NStr("en = 'Error creating FTP connection with %1 server'") + Chars.LF + "%2";
			GetFilesFromInternet.WriteErrorInEventLog(
				StringFunctionsClientServer.SubstitureParametersInString(ErrorMessage, ServerName,
					DetailErrorDescription(ErrorInfo)));
			ErrorMessage = StringFunctionsClientServer.SubstitureParametersInString(ErrorMessage, ServerName,
					BriefErrorDescription(ErrorInfo));
			Return GenerateResult(False, ErrorMessage);
		EndTry;
	Else
		Try
			Connection = New HTTPConnection(ServerName, Port, UserName, PasswordOfUser, Proxy, SecureConnection);
		Except
			ErrorInfo = ErrorInfo();
			ErrorMessage = NStr("en = 'Error creating HTTP connection with %1 server.'") + Chars.LF + "%2";
			GetFilesFromInternet.WriteErrorInEventLog(
				StringFunctionsClientServer.SubstitureParametersInString(ErrorMessage, ServerName, 
					DetailErrorDescription(ErrorInfo)));
			ErrorMessage = StringFunctionsClientServer.SubstitureParametersInString(ErrorMessage, ServerName, 
				BriefErrorDescription(ErrorInfo));
			Return GenerateResult(False, ErrorMessage);
		EndTry;
	EndIf;
	
	If SaveSetting["Path"] <> Undefined Then
		DownloadFolderPath = SaveSetting["Path"];
	Else
#If NOT WebClient Then
		DownloadFolderPath = GetTempFileName();
#EndIf
	EndIf;
	
	Try
		Connection.Get(FilePathAtServer, DownloadFolderPath);
	Except
		ErrorInfo = ErrorInfo();
		ErrorMessage = NStr("en = 'Error receiving file form %1 server:'") + Chars.LF + "%2";
		GetFilesFromInternet.WriteErrorInEventLog(
			StringFunctionsClientServer.SubstitureParametersInString(ErrorMessage, ServerName, 
				DetailErrorDescription(ErrorInfo)));
		ErrorMessage = StringFunctionsClientServer.SubstitureParametersInString(ErrorMessage, ServerName, 
			BriefErrorDescription(ErrorInfo));
		Return GenerateResult(False, ErrorMessage);
	EndTry;
	
	// If saving file according to the setting
	If SaveSetting["StoragePlace"] = "TemporaryStorage" Then
		UniqueKey = New UUID;
		Address = PutToTempStorage(DownloadFolderPath, UniqueKey);
		Return GenerateResult(True, Address);
	ElsIf SaveSetting["StoragePlace"] = "Client"
	      Or SaveSetting["StoragePlace"] = "Server" Then
		Return GenerateResult(True, DownloadFolderPath);
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// Function generates proxy using proxy settings (passed parameter)
//
// Parameters:
//
// Proxy         - Map -
//                 Keys:
//                 BypassProxyOnLocal 	- String -
//                 Server       		- Proxy-server address
//                 Port         		- Proxy-server port
//                 User 				- User name for authorization on proxy-server
//                 Password      		- User password
// Protocol      - String 				- Proxy server protocol
//                 For example "http", "https", "ftp"
//
Function GenerateProxy(ProxySettings, Protocol)
	
	Proxy 					 = New InternetProxy;
	Proxy.BypassProxyOnLocal = ProxySettings["BypassProxyOnLocal"];
	Proxy.Set(Protocol, ProxySettings["Server"], ProxySettings["Port"]);
	Proxy.User 				 = ProxySettings["User"];
	Proxy.Password      	 = ProxySettings["Password"];
	
	Return Proxy;
	
EndFunction

// Split URL to several parts (protocol, server and path)
// Parameters:
// URL           		- string - correct url to a resource on the Internet
//
// Value returned:
// Structure with the fields:
// protocol      		- string - protocol of access to a resource
// ServerName    		- string - server where resource is located
// FilePathAtServer	- string - path to the file at server
//
Function SplitURL(Val URL)
	
	Result = New Structure;

	// protocol by default
	Protocol = "http";
	
	URL = TrimAll(URL);
	
	If Left(URL, 5) = "ftp://" Then
		URL = Right(URL, StrLen(URL) - 7);
	EndIf;
	
	If Left(URL, 7) = "http://" Then
		URL = Right(URL, StrLen(URL) - 7);
		Protocol = "http";
	EndIf;
	
	If Left(URL, 8) = "https://" Then
		URL = Right(URL, StrLen(URL) - 8);
		Protocol = "https";
	EndIf;

	Index 		= 1;
	ServerName 	= "";
	
	While Index < StrLen(URL) Do
		CurChar = Mid(URL, Index, 1);
		If CurChar = "/" Then
			Break;
		EndIf;
		ServerName = ServerName + CurChar;
		Index = Index + 1;
	EndDo;
	
	PatthToFile = Right(URL, StrLen(URL) - Index);
	
	Result.Insert("ServerName", 	  ServerName);
	Result.Insert("FilePathAtServer", PatthToFile);
	Result.Insert("Protocol", 		  Protocol);
	
	Return Result;
	
EndFunction

// Function, filling structure by parameters.
//
// Parameters:
// OperationSuccess - Boolean - operation success or failure
// MessagePath 		- String
//
// Value returned:
// structure :
//          field success 	 - boolean
//          field path 		 - string
//
Function GenerateResult(Val Status, Val MessagePath)
	
	Result = New Structure("Status");
	
	Result.Status = Status;

	If Status Then
		Result.Insert("Path", MessagePath);
	Else
		Result.Insert("ErrorMessage", MessagePath);
	EndIf;
	
	Return Result;
	
EndFunction
