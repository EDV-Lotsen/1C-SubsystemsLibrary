////////////////////////////////////////////////////////////////////////////////
// Get files from the Internet subsystem
// 
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Returns WebProxy object for Internet access.
//
// Parameters:
//   URLOrProtocol - String - file url in the following format:
//                            [Protocol://]<Server>/<Path to file on server>,
//                            or protocol indentifier (http, ftp, ...)
//
// Returns:
//   InternetProxy
//
Function GetProxy(Val URLOrProtocol) Export
	
#If Client Then
	ProxyServerSettings = StandardSubsystemsClientCached.ClientParameters().ProxyServerSettings;
#Else
	ProxyServerSettings = GetFilesFromInternet.ProxySettingsAtServer();
#EndIf
	If Find(URLOrProtocol, "://") > 0 Then
		Protocol = SplitURL(URLOrProtocol).Protocol;
	Else
		Protocol = Lower(URLOrProtocol);
	EndIf;
	Return GenerateWebProxy(ProxyServerSettings, Protocol);
	
EndFunction

// Splits URL: protocol, server, path to resource.
//
// Parameters:
//  URL - String - link to a web resource
//
// Returns:
//  Structure:
//             Protocol           - String - resource access protocol 
//             ServerName         - String - server resource 
//             PathToFileAtServer - String - resource path at server
//
Function SplitURL(Val URL) Export
	
	URLStructure = CommonUseClientServer.URIStructure(URL);
	
	Result = New Structure;
	Result.Insert("Protocol", ?(IsBlankString(URLStructure.Schema), "http", URLStructure.Schema));
	Result.Insert("ServerName", URLStructure.ServerName);
	Result.Insert("PathToFileAtServer", URLStructure.PathAtServer);
	
	Return Result;
	
EndFunction

// Splits URI string to assemble it and return it as a structure
//
Function URLStructure(Val URLString) Export
	
	Return CommonUseClientServer.URIStructure(URLString);
	
EndFunction

#EndRegion

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Export internal procedures and functions

// function meant for getting files from the Internet.
//
// Parameters:
// URL               - String - file url in the following format:
// ReceivingSettings - Featured structure 
//     SavePath          - String  - path to server (including file name), to save the 
//                                   downloaded file
//     User              - String  - user on whose behalf the connection is being made
//     Password          - String  - password for the user on whose behalf the connection 
//                                   is being made
//     Port              - Number  - server port to connect to
//     Timeout           - Number  - timeout for file acquisition, in seconds
//     SecureConnection  - Boolean - in case of http download the flag  shows
//                                   that the connection is performed through https
//     PassiveConnection - Boolean - in case of ftp download the flag shows
//                                   that the connection must be passive (or active)
//     Headings          - Map     - see HTTPRequest Object heading parameter description
//
// SavingSettings    - Map - contains parameters to save the downloaded file keys:
//                 Storage - String - can include
//                           "Client" - client,
//                           "Server" - server,
//                           "TemporaryStorage" - temporary storage
//                 Path    - String (optional parameter) - 
//                           path to catalogue on client or at server or temporary storage
//                           address will be generated, if not specified
//
// Returns:
// Structure
//  Success - Boolean - operation success or failure 
//  String  - String - in case of success either string-path to save file
//                     or address in temporary storage
//                     in case of failure message
//
Function PrepareFileReceiving(Val URL, Val ReceivingSettings, Val SavingSettings, Val WriteError = True) Export
	
	ConnectionSettings = New Map;
	ConnectionSettings.Insert("User",     ReceivingSettings.User);
	ConnectionSettings.Insert("Password", ReceivingSettings.Password);
	ConnectionSettings.Insert("Port",     ReceivingSettings.Port);
	ConnectionSettings.Insert("Timeout",  ReceivingSettings.Timeout);
	ConnectionSettings.Insert("Headings", ReceivingSettings.Headings);
	
	Protocol = SplitURL(URL).Protocol;
	
	If Protocol = "ftp" Then
		ConnectionSettings.Insert("PassiveConnection", ReceivingSettings.PassiveConnection);
	Else
		ConnectionSettings.Insert("SecureConnection", ReceivingSettings.SecureConnection);
	EndIf;
	
#If Client Then
	ProxyServerSettings = StandardSubsystemsClientCached.ClientParameters().ProxyServerSettings;
#Else
	ProxyServerSettings = GetFilesFromInternet.ProxySettingsAtServer();
#EndIf
	
	Return GetFileFromInternet(URL, SavingSettings, ConnectionSettings,
		ProxyServerSettings, WriteError);
	
EndFunction

Function FileAcquisitionParameterStructure() Export
	
	ReceivingParameters = New Structure;
	ReceivingParameters.Insert("PathForSaving", Undefined);
	ReceivingParameters.Insert("User", Undefined);
	ReceivingParameters.Insert("Password", Undefined);
	ReceivingParameters.Insert("Port", Undefined);
	ReceivingParameters.Insert("Timeout", Undefined);
	ReceivingParameters.Insert("SecureConnection", Undefined);
	ReceivingParameters.Insert("PassiveConnection", Undefined);
	ReceivingParameters.Insert("Headings", New Map());
	
	Return ReceivingParameters;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions

// Function meant for getting files from the Internet.
//
// Parameters:
// URL - String - file url in the following format: [Protocol://]<Server>/<Path to file at server>
//
// ConnectionSettings - Map:
// 	SecureConnection*  - Boolean - secure connection
// 	PassiveConnection* - Boolean - passive connection
// 	User     - String - user on whose behalf the connection is being made
// 	Password - String - password for the user on whose behalf the connection is being made
// 	Port     - Number - server port to connect to
// 	* - mutually exclusive keys
//
// ProxySettings - Map:
// 	UseProxy           - whether to use proxy server
// 	BypassProxyOnLocal - whether to use proxy server for local addresses
// 	UseSystemSettings  - use proxy server system settings
// 	Server             - proxy server address
// 	Port               - proxy server port
// 	User               - user name for proxy authorization
// 	Password           - user password
//
// SavingSettings - Map - contains paramters to save the downloaded file
// 	Storage - String - can contain: 
// 		"Client" - client,
// 		"Server" - server,
// 		"TemporaryStorage" - temporary storage
// 	Path    - String (optional parameter) - path to the directory on client or on server, 
// 	                                        or temporary storage address, will be generated 
//                                           automatically if not specified
//
// Returns:
// Structure
//  Success - Boolean - operation success or failure
//  String  - String  - in case of success either path to save file or address 
//                      in the temporary storage
//                      in case of failure error message
//
Function GetFileFromInternet(Val URL, Val SavingSettings, Val ConnectionSettings = Undefined,
	Val ProxySettings = Undefined, Val WriteError = True)
	
	// Declare variables before the first use
	// as Property method parameter when analyzing file aquisition parameters
	// from AcquisitionParameters. Contain values of transmitted file acquisition parameters
	Var ServerName, UserName, Password, Port,
	      SecureConnection, PassiveConnection,
	      PathToFileAtServer, Protocol;
	
	SeparatedURL = SplitURL(URL);
	
	ServerName         = SeparatedURL.ServerName;
	PathToFileAtServer = SeparatedURL.PathToFileAtServer;
	Protocol           = SeparatedURL.Protocol;
	
	SecureConnection  = ConnectionSettings.Get("SecureConnection");
	PassiveConnection = ConnectionSettings.Get("PassiveConnection");
	
	UserName     = ConnectionSettings.Get("User");
	UserPassword = ConnectionSettings.Get("Password");
	Port         = ConnectionSettings.Get("Port");
	Timeout      = ConnectionSettings.Get("Timeout");
	Headings     = ConnectionSettings.Get("Headings");
	
	If Protocol = "https" Then
		SecureConnection = True;
	EndIf;
	
	If Port = Undefined Then
		FullURLStructure = CommonUseClientServer.URIStructure(URL);
		
		If Not IsBlankString(FullURLStructure.Port) Then
			ServerName = FullURLStructure.Domain;
			Port = FullURLStructure.Port;
		EndIf;
	EndIf;
	
	Proxy = ?(ProxySettings <> Undefined, GenerateWebProxy(ProxySettings, Protocol), Undefined);
	FTPProtocolIsUsed = (Protocol = "ftp");
	
	If FTPProtocolIsUsed Then
		Try
			Connection = New FTPConnection(ServerName, Port, UserName, UserPassword, Proxy, PassiveConnection, Timeout);
		Except
			ErrorInfo = ErrorInfo();
			ErrorMessage = NStr("en = 'Error creating FTP connection to the %1 server:'") + Chars.LF + "%2";
			
			WriteErrorToEventLog(StringFunctionsClientServer.SubstituteParametersInString(
				ErrorMessage, ServerName, DetailErrorDescription(ErrorInfo)));
			ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(ErrorMessage, ServerName,
					BriefErrorDescription(ErrorInfo));
			Return GenerateResult(False, ErrorMessage);
		EndTry;
		
	Else
		If SecureConnection = True Then
			SecureConnection = New OpenSSLSecureConnection;
		Else
			SecureConnection = Undefined;
		EndIf;
		
		Try
			Connection = New HTTPConnection(ServerName, Port, UserName, UserPassword, Proxy, Timeout, SecureConnection);
		Except
			ErrorInfo = ErrorInfo();
			ErrorMessage = NStr("en = 'Error creating HTTP connection to the %1 server:'") + Chars.LF + "%2";
			WriteErrorToEventLog(
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
		
		If FTPProtocolIsUsed Then
			Connection.Get(PathToFileAtServer, PathForSaving);
			ResponseHeadings = Undefined;
		Else
			HTTPRequest = New HTTPRequest(PathToFileAtServer, Headings);
			HTTPRequest.Headers.Insert("Accept-Charset", "utf-8");
			HTTPResponse = Connection.Get(HTTPRequest, PathForSaving);
			If HTTPResponse.StatusCode < 200 Or HTTPResponse.StatusCode >= 300 Then
				ResponseFile = New TextReader(PathForSaving, TextEncoding.UTF8);
				Raise StringFunctionsClientServer.ExtractTextFromHTML(ResponseFile.Read(5 * 1024));
			EndIf;
			ResponseHeadings = HTTPResponse.Headers;
		EndIf;
		
	Except
		ErrorInfo = ErrorInfo();
		ErrorMessage = NStr("en = 'Error downloading file from the %1 server:'") + Chars.LF + "%2";
		If WriteError Then
			WriteErrorToEventLog(
				StringFunctionsClientServer.SubstituteParametersInString(ErrorMessage, ServerName, 
				DetailErrorDescription(ErrorInfo)));
		EndIf;
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(ErrorMessage, ServerName, 
				BriefErrorDescription(ErrorInfo));
		Return GenerateResult(False, ErrorMessage);
	EndTry;
	
	// If the file is saved in accordance with the setting 
	If SavingSettings["Storage"] = "TempStorage" Then
		UniquenessKey = New UUID;
		Address = PutToTempStorage (New BinaryData(PathForSaving), UniquenessKey);
		Return GenerateResult(True, Address, ResponseHeadings);
	ElsIf SavingSettings["Storage"] = "Client"
	      Or SavingSettings["Storage"] = "Server" Then
		Return GenerateResult(True, PathForSaving, ResponseHeadings);
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// Returns proxy according to settings ProxyServerSetting for the specified Protocol protocol.
// 
// Parameters:
//  ProxyServerSettings - Map:
// 	 UseProxy           - whether to use proxy server 
// 	 BypassProxyOnLocal - whether to use proxy server for local addresses
// 	 UseSystemSettings  - use server proxy system settings 
// 	 Server             - proxy server address
// 	 Port               - proxy server port
// 	 User               - user name for proxy authorization
// 	 Password           - user password
//  Protocol - String - protocol for which proxy server parameters are set, 
//                       for example http, https, ftp
// 
// Returns:
//   InternetProxy
// 
Function GenerateWebProxy(ProxyServerSettings, Protocol)
	
	If ProxyServerSettings = Undefined Then
		// Proxy server system guidelines
		Return Undefined;
	EndIf;	
	
	UseProxy = ProxyServerSettings.Get("UseProxy");
	If Not UseProxy Then
		// Bypass proxy server
		Return New InternetProxy(False);
	EndIf;
	
	UseSystemSettings = ProxyServerSettings.Get("UseSystemSettings");
	If UseSystemSettings Then
		// Proxy server system settings
		Return New InternetProxy(True);
	EndIf;
			
	// Manually configured proxy settings
	Proxy = New InternetProxy;
	
	// Detect proxy server address and port
	AdditionalSettings = ProxyServerSettings.Get("AdditionalProxySettings");
	ProxyToProtocol = Undefined;
	If TypeOf(AdditionalSettings) = Type("Map") Then
		ProxyToProtocol = AdditionalSettings.Get(Protocol);
	EndIf;
	
	If TypeOf(ProxyToProtocol) = Type("Structure") Then
		Proxy.Set(Protocol, ProxyToProtocol.Address, ProxyToProtocol.Port);
	Else
		Proxy.Set(Protocol, ProxyServerSettings["Server"], ProxyServerSettings["Port"]);
	EndIf;
	
	Proxy.BypassProxyOnLocal = ProxyServerSettings["BypassProxyOnLocal"];
	Proxy.User               = ProxyServerSettings["User"];
	Proxy.Password           = ProxyServerSettings["Password"];
	
	ExceptionAddresses = ProxyServerSettings.Get("BypassProxyOnAddresses");
	If TypeOf(ExceptionAddresses) = Type("Array") Then
		For Each ExceptionAddress In ExceptionAddresses Do
			Proxy.BypassProxyOnAddresses.Add(ExceptionAddress);
		EndDo;
	EndIf;
			
	Return Proxy;
	
EndFunction

// Function meant for completing the structure according to parameters
//
// Parameters:
//  OperationSuccess - Boolean - operation success or failure
//  MessagePath - String - 
//
// Returns - structure:
//          Success - Boolean
//          Path    - String
//
Function GenerateResult(Val Status, Val MessagePath, ResponseHeadings = Undefined)
	
	Result = New Structure("Status", Status);
	
	If Status Then
		Result.Insert("Path", MessagePath);
	Else
		Result.Insert("ErrorMessage", MessagePath);
	EndIf;
	
	If ResponseHeadings <> Undefined Then
		
		Result.Insert("Headings", ResponseHeadings);
		
	EndIf;
	
	Return Result;
	
EndFunction

// Writes error messages to the event log. 
// The Get files from the Internet event name.
//
// Parameters:
//    ErrorMessage - String - error message string
// 
Procedure WriteErrorToEventLog(Val ErrorMessage) Export
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	WriteLogEvent(
		EventLogMessageText(),
		EventLogLevel.Error, , ,
		ErrorMessage);
#Else
	EventLogOperationsClient.AddMessageForEventLog(EventLogMessageText(),
		"Error", ErrorMessage,,True);
#EndIf
	
EndProcedure

Function EventLogMessageText() Export
	
	Return NStr("en = 'Get files from the Internet'", CommonUseClientServer.DefaultLanguageCode());
	
EndFunction

#EndRegion