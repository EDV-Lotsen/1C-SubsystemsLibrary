

// Common interface function for getting file from the Internet via http(s) protocol
// or ftp protocol and saving it to a temporary storage.
//
// Parameters:
// DownloadFolderPath 	 		- String 	 - path at server (including file name), for saving downloaded file
// URL           		- String 	 - of url file in format:
//                 [Protocol://]<Server>/<Path to the file at server>
// User 		 		- String 	 - user, under whose name connection is established
// Password       		- String 	 - user password under whose name connection is established
// Port          		- Number  	 - connection is established on this server port
// SecureConnection 	- Boolean 	 - for the case of http load flag indicates,
//                 					that connection should be established via https
// PassiveConnection 	- Boolean 	 - for the case of ftp load flag indicates,
//                 						that connection should be passive (or active)
//                 	
// Value returned:
// Structure
// Status 			 - Boolean 		  - keyis alway present in the structure, values
//                   True	 		  - function call has successfully been completed
//                   False   		  - function call has failed
// Path 			 - String 		  - path to the file at server, key is used only
//                 if status is True
// ErrorMessage - String 		  - error message, if status is False
//
Function DownloadFileAtServer(Val URL, Val DownloadParameters = Undefined) Export
	
	// Declaration of variables before first use
	// of method Property parameter, on analysis of file get parameters
	// from DownloadParameters. Contain values of the passed file get parameters
	Var DownloadFolderPath, User, Password, Port, SecureConnection, PassiveConnection;
	
	// Get file get parameters
	
	If DownloadParameters = Undefined Then
		DownloadParameters = New Structure;
	EndIf;
	
	If Not DownloadParameters.Property("DownloadFolderPath", DownloadFolderPath) Then
		DownloadFolderPath = Undefined;
	EndIf;
	
	If Not DownloadParameters.Property("User", User) Then
		User = Undefined;
	EndIf;
	
	If Not DownloadParameters.Property("Password", Password) Then
		Password = Undefined;
	EndIf;
	
	If Not DownloadParameters.Property("Port", Port) Then
		Port = Undefined;
	EndIf;
	
	If Not DownloadParameters.Property("SecureConnection", SecureConnection) Then
		SecurePassiveConnection = Undefined;
	EndIf;
	
	If Not DownloadParameters.Property("PassiveConnection", PassiveConnection) Then
		SecurePassiveConnection = Undefined;
	EndIf;
	
	SaveSetting = New Map;
	SaveSetting.Insert("StoragePlace", "Server");
	SaveSetting.Insert("Path", DownloadFolderPath);
	
	Result = GetFilesFromInternetClientServer.PrepareFileReceiving(
		URL,
		User,
		Password,
		Port,
		SecureConnection,
		PassiveConnection,
		SaveSetting);
	
	Return Result;
	
EndFunction

// Common interface function for getting file from the Internet via http(s) protocol
// or ftp protocol and saving it to a temporary storage.
//
// Parameters:
// URL           	 - String - of url file in format:
//                 		[Protocol://]<Server>/<Path to the file at server>
// User  - string 	 - User, under whose name connection is established
// Password       	 - String  - user password under whose name connection is established
// Port          	 - Number  - connection is established on this server port
// SecureConnection  - Boolean - for the case of http load flag indicates,
//                          	 that connection should be established via https
// PassiveConnection - Boolean - for the case of ftp load flag indicates,
//                          that connection should be passive (or active)
//
// Value returned:
// Structure
// Status 			 - Boolean 	 - keyis alway present in the structure, values
//                   	 True 	 - function call has successfully been completed
//                  	 False   - function call has failed
// Path 			 - String  	 - path to the file in temporary storage,
//                				 key in used only if status is True
// ErrorMessage - String    - error message, if status is False
//
Function DownloadFileToTemporaryStorage(Val URL, Val DownloadParameters = Undefined) Export
	
	// Declaration of variables before first use
	// of method Property parameter, on analysis of file get parameters
	// from DownloadParameters. Contain values of the passed file get parameters
	Var DownloadFolderPath, User, Password, Port, SecureConnection, PassiveConnection;
	// Get file get parameters
	
	If DownloadParameters = Undefined Then
		DownloadParameters = New Structure;
	EndIf;
	
	If Not DownloadParameters.Property("DownloadFolderPath", DownloadFolderPath) Then
		DownloadFolderPath = Undefined;
	EndIf;
	
	If Not DownloadParameters.Property("User", User) Then
		User = Undefined;
	EndIf;
	
	If Not DownloadParameters.Property("Password", Password) Then
		Password = Undefined;
	EndIf;
	
	If Not DownloadParameters.Property("Port", Port) Then
		Port = Undefined;
	EndIf;
	
	If Not DownloadParameters.Property("SecureConnection", SecureConnection) Then
		SecurePassiveConnection = Undefined;
	EndIf;
	
	If Not DownloadParameters.Property("PassiveConnection", PassiveConnection) Then
		SecurePassiveConnection = Undefined;
	EndIf;
	
	SaveSetting = New Map;
	SaveSetting.Insert("StoragePlace", "TemporaryStorage");
	
	Result = GetFilesFromInternetClientServer.PrepareFileReceiving(
		URL,
		User,
		Password,
		Port,
		SecureConnection,
		PassiveConnection,
		SaveSetting);
	
	Return Result;
	
EndFunction

// Writes binary data to file, stored in temporary storage
//
// Parameters:
// AddressInTemporaryStorage - String - file binary data address in temporary storage
// FileName      			 - String - path at server where file should be saved
//
Function SaveFileFromTemporaryStorageAtServer(AddressInTemporaryStorage, FileName) Export
	
	FileData = GetFromTempStorage(AddressInTemporaryStorage);
	FileData.Write(FileName);
	
	Return True;
	
EndFunction

// Gets temporary file name by calling system function with the same name at server
//
Function GetTempFileNameAtServer() Export

	Return GetTempFileName();

EndFunction

// Returns proxy server setup parameters at 1C:Enterprise server side
//
Function GetProxySettingsAt1CEnterpriseServer() Export
	
	SetPrivilegedMode(True);
	
	Return Constants.ProxyServerConfiguration.Get().Get();
	
EndFunction

// Returns proxy server setup parameters at 1C:Enterprise server side
//
Procedure SaveProxySettingsAt1CEnterpriseServer(Val Settings) Export
	
	SetPrivilegedMode(True);
	
	Constants.ProxyServerConfiguration.Set(New ValueStorage(Settings));
	
EndProcedure

// Returns proxy server setup for access to the internet from client
// side by specific user
Function GetProxyServerSetting() Export
	
	Return CommonSettingsStorage.Load("ProxyServerConfiguration");
	
EndFunction

Procedure WriteErrorInEventLog(Val ErrorMessage) Export
	
	WriteLogEvent(NStr("en = 'Get files from Internet'"), 
		EventLogLevel.Error, , , ErrorMessage);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INFOBASE UPDATE

// Update proxy settings - new property "UseProxy" has been added to the settings
//
Procedure StoredProxySettingsUpdate() Export
	
	IBUsersArray = InfobaseUsers.GetUsers();
	
	For Each IBUser In IBUsersArray Do
		ProxyServerConfiguration = CommonSettingsStorage.Load("ProxyServerConfiguration",,, IBUser.Name);
		If TypeOf(ProxyServerConfiguration) = Type("Map") Then
			If ProxyServerConfiguration.Get("UseProxy") = Undefined Then
				ProxyServerConfiguration.Insert("UseProxy", True);
				CommonSettingsStorage.Save("ProxyServerConfiguration", , ProxyServerConfiguration, , IBUser.Name);
			EndIf;
		EndIf;
	EndDo;
	
	ProxyServerConfiguration = GetFilesFromInternet.GetProxySettingsAt1CEnterpriseServer();
	
	If TypeOf(ProxyServerConfiguration) = Type("Map") Then
		If ProxyServerConfiguration.Get("UseProxy") = Undefined Then
			ProxyServerConfiguration.Insert("UseProxy", True);
			GetFilesFromInternet.SaveProxySettingsAt1CEnterpriseServer(ProxyServerConfiguration);
		EndIf;
	EndIf;
	
EndProcedure
