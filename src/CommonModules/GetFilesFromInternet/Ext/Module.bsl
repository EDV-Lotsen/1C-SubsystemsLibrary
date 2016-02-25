////////////////////////////////////////////////////////////////////////////////
// Get files from the Internet subsystem
// 
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Gets the file from the Internet via http(s) protocol or ftp protocol and saves it 
// at the specified path on server.
//
// Parameters:
//   URL                   - String - file URL in the following format: 
//                                    [Protocol://]<Server>/<Path to file on server>
//   AcquisitionParameters - Structure with the following properties:
//      * PathForSaving     - String  - path to server (including file name), to save 
//                                      the downloaded file
//      * User              - String  - the user on behalf of whom the connection 
//                                      is established
//      * Password          - String  - password of the user on behalf of whom 
//                                      the connection is established
//      * Port              - Number  - server port to establish connection with
//      * Timeout           - Number  - timeout for file acquisition, in seconds
//      * SecureConnection  - Boolean - in case of http download the flag shows 
//                                      that the connection must be estabished via https
//      * PassiveConnection - Boolean - in case of ftp download the flag shows that 
//                                      the connection must be passive (or active)
//      * Headings          - Map     - see HTTPQuery Object headings parameter description 
//   WriteError            - Boolean - Indicates necessity to write errors to event log 
//                                     while acquiring the file
//
// Returns:
//   Structure - Structure with the following properties:
//      * Status       - Boolean - file acquisition result
//      * Path         - String  - path to the file on server, the key is used only if Status is True
//      * ErrorMessage - String  - error message, if Status is False
//      * Headings     - Map     - see HTTPResponse Object headings parameter description
//
Function DownloadFileAtServer(Val URL, ReceivingParameters = Undefined, Val WriteError = True) Export
	
	ReceivingSettings = GetFilesFromInternetClientServer.FileAcquisitionParameterStructure();
	
	If ReceivingParameters <> Undefined Then
		
		FillPropertyValues(ReceivingSettings, ReceivingParameters);
		
	EndIf;
	
	SavingSettings = New Map;
	SavingSettings.Insert("Storage", "Server");
	SavingSettings.Insert("Path", ReceivingSettings.PathForSaving);
	
	Return GetFilesFromInternetClientServer.PrepareFileReceiving(URL,
		ReceivingSettings, SavingSettings, WriteError);
	
EndFunction

// Gets the file from the Internet via http(s) protocol or ftp protocol and saves it 
// in the temporary storage.
//
// Parameters:
//   URL                   - String  - file url in the following format: 
//                                     [Protocol://]<Server>/<Path to file on server>
//   AcquisitionParameters - Structure with the following properties:
//      * User              - String  - the user on behalf of whom the connection 
//                                      is established
//      * Password          - String  - password of the user on behalf of whom 
//                                      the connection is established
//      * Port              - Number  - server port to establish connection with 
//      * Timeout           - Number  - timeout for file acquisition, in seconds
//      * SecureConnection  - Boolean - in case of http download the flag shows that 
//                                      the connection must be estabished via https
//      * PassiveConnection - Boolean - in case of ftp download the flag shows that 
//                                      the connection must be passive (or active)
//      * Headings          - Map     - see HTTPQuery Object headings parameter description
//   WriteError            - Boolean - Indicates necessity to write errors to event log 
//                                     while acquiring the file
//
// Returns:
//   Structure - Structure with the following properties:
//      * Status       - Boolean - file acquisition result
//      * Path         - String  - temporary storage address with binary data, the key 
//                                 is used only if Status is True
//      * ErrorMessage - String  - error message, if Status is False
//      * Headings     - Map     - see HTTPResponse Object headings parameter description
//
Function DownloadFileToTempStorage(Val URL, ReceivingParameters = Undefined, Val WriteError = True) Export
	
	ReceivingSettings = GetFilesFromInternetClientServer.FileAcquisitionParameterStructure();
	
	If ReceivingParameters <> Undefined Then
		
		FillPropertyValues(ReceivingSettings, ReceivingParameters);
		
	EndIf;
	
	SavingSettings = New Map;
	SavingSettings.Insert("Storage", "TempStorage");
	
	Return GetFilesFromInternetClientServer.PrepareFileReceiving(URL,
		ReceivingSettings, SavingSettings, WriteError);
	
EndFunction

// Returns proxy settings of Internet access
// on the client side of the currnet user.
//
// Returns:
//   Map - properties:
// 	UseProxy           - whether to use proxy server
// 	BypassProxyOnLocal - whether to use proxy server for local addresses
// 	UseSystemSettings  - use proxy server system settings
// 	Server             - proxy server address
// 	Port               - proxy server port
// 	User               - user name for proxy authorization
// 	Password           - user password
//
Function ProxySettingsAtClient() Export
	
	Return CommonUse.CommonSettingsStorageLoad("ProxyServerSettings");
	
EndFunction

// Returns proxy setting parameters on the 1C:Enterprise server side
//
// Returns:
//   Map - properties:
// 	UseProxy           - whether to use proxy server
// 	BypassProxyOnLocal - whether to use proxy server for local addresses
// 	UseSystemSettings  - use proxy server system settings
// 	Server             - proxy server address
// 	Port               - proxy server port
// 	User               - user name for proxy authorization
// 	Password           - user password
//
Function ProxySettingsAtServer() Export
	
	If CommonUseCached.ApplicationRunMode().File Then
		Return ProxySettingsAtClient();
	Else
		SetPrivilegedMode(True);
		ProxySettingsAtServer = Constants.ProxyServerSettings.Get().Get();
		Return ?(TypeOf(ProxySettingsAtServer) = Type("Map"),
				  ProxySettingsAtServer,
				  Undefined);
	EndIf;
	
EndFunction

// Obsolete. Must use ProxySettingsAtServer
//
Function GetServerProxySettings() Export
	
	Return ProxySettingsAtServer();
	
EndFunction	

// Obsolete. Must use ProxySettingsAtClient
//
Function GetProxyServerSetting() Export
	
	Return ProxySettingsAtClient();
	
EndFunction

#EndRegion
