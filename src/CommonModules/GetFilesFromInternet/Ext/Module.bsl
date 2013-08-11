////////////////////////////////////////////////////////////////////////////////
// Get files from internet subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Receives a file from the internet with HTTP(S) or FTP protocol and saves it to 
// a temporary file.
//
// Parameters:
//  URL - String        - file URL in the following format:
//                        [Protocol://]<Server>/<Path to the file on server>
//  ReceivingParameters - structure with the following keys:
//  PathForSaving       - String - path at the server (including the file name) where
//                        the downloaded file will be saved.
//  User                - String - user on behalf of which the connection is
//                        established.
//  Password            - String - password of the user on behalf of which the
//                        connection is established.
//  Port - Number       - port that is used for establishing the connection.
//  SecureConnection    - Boolean - in case of HTTP this flag shows
//                        whether a secure HTTPS connection is used.
//  PassiveConnection   - Boolean - in case of FTP this flag shows 
//                        whether the connection mode is passive or active;
//
// Returns:
//  Structure with the following keys:
//   State        - Boolean - this key always exists in the structure. It can take 
//                  on the following values:
//                   True if function execution completed successfully, 
//                   False if function execution failed.
//   Path         - String - path to the file at the server. This key is used only if
//                  State is True.
//   ErrorMessage - String - error message if State is False.
//
Function DownloadFileAtServer(Val URL, ReceivingParameters = Undefined) Export
	
	// Declaring variables before their first use as the Property 
	// method parameter.
	Var PathForSaving, User, Password, Port,
	 SecureConnection, PassiveConnection;
	
	// Retrieving parameters to receive the file 
	If ReceivingParameters = Undefined Then
		ReceivingParameters = New Structure;
	EndIf;
	
	If Not ReceivingParameters.Property("PathForSaving", PathForSaving) Then
		PathForSaving = Undefined;
	EndIf;
	
	If Not ReceivingParameters.Property("User", User) Then
		User = Undefined;
	EndIf;
	
	If Not ReceivingParameters.Property("Password", Password) Then
		Password = Undefined;
	EndIf;
	
	If Not ReceivingParameters.Property("Port", Port) Then
		Port = Undefined;
	EndIf;
	
	If Not ReceivingParameters.Property("SecureConnection", SecureConnection) Then
		SecureConnection = Undefined;
	EndIf;
	
	If Not ReceivingParameters.Property("PassiveConnection", PassiveConnection) Then
		PassiveConnection = Undefined;
	EndIf;
	
	SavingSettings = New Map;
	SavingSettings.Insert("Storage", "Server");
	SavingSettings.Insert("Path", PathForSaving);
	
	Result = GetFilesFromInternetClientServer.PrepareFileReceiving(
		URL,
		User,
		Password,
		Port,
		SecureConnection,
		PassiveConnection,
		SavingSettings);
	
	Return Result;
	
EndFunction

// Receives a file from the internet with HTTP(S) or FTP protocol and saves it to 
// a temporary storage.
//
// Parameters:
//  URL                 - String - file URL in the following format:
//                        [Protocol://]<Server>/<Path to the file on server>
//  ReceivingParameters - structure with the following keys:
//  User                - String - user on behalf of which the connection is
//                        established.
//  Password            - String - password of the user on behalf of which the
//                        connection is established.
//  Port                - Number - port that is used for establishing the connection.
//  SecureConnection    - Boolean - in case of HTTP this flag shows
//                        whether a secure HTTPS connection is used.
//  PassiveConnection   - Boolean - in case of FTP this flag shows 
//                        whether the connection mode is passive or active;
//
// Returns:
//  Structure with the following keys:
//   State        - Boolean - this key always exists in the structure. It can take 
//                  on the following values:
//                   True if function execution completed successfully,
//                   False if function execution failed.
//   Path         - String - path to the temporary storage with binary data of the
//                  downloaded file.
//                  This key is used only if State is True.
//   ErrorMessage - String - error message if State is False.
//
Function DownloadFileToTempStorage(Val URL, ReceivingParameters = Undefined) Export
	
	// Declaring variables before their first use as the Property 
	// method parameter.
	Var PathForSaving, User, Password, Port,
	 SecureConnection, PassiveConnection;
		 
	// Retrieving parameters to receive the file 
	If ReceivingParameters = Undefined Then
		ReceivingParameters = New Structure;
	EndIf;
	
	If Not ReceivingParameters.Property("PathForSaving", PathForSaving) Then
		PathForSaving = Undefined;
	EndIf;
	
	If Not ReceivingParameters.Property("User", User) Then
		User = Undefined;
	EndIf;
	
	If Not ReceivingParameters.Property("Password", Password) Then
		Password = Undefined;
	EndIf;
	
	If Not ReceivingParameters.Property("Port", Port) Then
		Port = Undefined;
	EndIf;
	
	If Not ReceivingParameters.Property("SecureConnection", SecureConnection) Then
		SecureConnection = Undefined;
	EndIf;
	
	If Not ReceivingParameters.Property("PassiveConnection", PassiveConnection) Then
		PassiveConnection = Undefined;
	EndIf;
	
	SavingSettings = New Map;
	SavingSettings.Insert("Storage", "TempStorage");
	
	Result = GetFilesFromInternetClientServer.PrepareFileReceiving(
		URL,
		User,
		Password,
		Port,
		SecureConnection,
		PassiveConnection,
		SavingSettings);
	
	Return Result;
	
EndFunction

// Writes binary data that is stored in the temporary storage to the file.
//
// Parameters:
//  AddressInTempStorage - String - address of binary file data in the temporary
//                        storage. 
//  FileName             - String - path to the file that will be saved at the server.
//
Function SaveFileFromTempStorageAtServer(AddressInTempStorage, FileName) Export
	
	FileData = GetFromTempStorage(AddressInTempStorage);
	FileData.Write(FileName);
	
	Return True;
	
EndFunction

// Retrieves a temporary file name by calling the same name internal function at the server.
//
Function GetTempFileNameAtServer() Export

	Return GetTempFileName();

EndFunction

// Returns proxy server parameter settings at the application server side.
//
Function GetServerProxySettings() Export
	
	SetPrivilegedMode(True);
	
	Return Constants.ProxyServerSettings.Get().Get();
	
EndFunction

// Saves proxy server parameter settings at the application server side.
//
Procedure SaveServerProxySettings(Val Settings) Export
	
	SetPrivilegedMode(True);
	
	Constants.ProxyServerSettings.Set(New ValueStorage(Settings));
	
EndProcedure

// Returns proxy server parameter settings at the client side for the current user.
//
Function GetProxyServerSetting() Export
	
	Return CommonUse.CommonSettingsStorageLoad("ProxyServerSettings");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Writes the error event to the event log. Event name is "Get files from internet".
//
// Parameters:
//  ErrorMessage - error message string.
// 
Procedure WriteErrorToEventLog(Val ErrorMessage) Export
	
	WriteLogEvent(
		NStr("en = 'Get files from internet'"),
		EventLogLevel.Error, , ,
		ErrorMessage
	);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for updating the infobase.

// Adds update handlers required by this subsystem to the Handlers list. 
// 
// Parameters:
//  Handlers - ValueTable - see the InfoBaseUpdate.NewUpdateHandlerTable function for details. 
// 
Procedure RegisterUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "1.2.1.4";
	Handler.Procedure = "GetFilesFromInternet.RefreshStoredProxySettings";
	
EndProcedure	

// Initializes new values of UseProxy and UseSystemSettings proxy settings.
//
Procedure RefreshStoredProxySettings() Export
	
	InfoBaseUserArray = InfoBaseUsers.GetUsers();
	
	For Each InfoBaseUser In InfoBaseUserArray Do
		
		ProxyServerSettings = CommonUse.CommonSettingsStorageLoad(
			"ProxyServerSettings", ,	, ,	InfoBaseUser.Name);
		
		If TypeOf(ProxyServerSettings) = Type("Map") Then
			
			SaveUserSettings = False;
			If ProxyServerSettings.Get("UseProxy") = Undefined Then
				ProxyServerSettings.Insert("UseProxy", False);
				SaveUserSettings = True;
			EndIf;
			If ProxyServerSettings.Get("UseSystemSettings") = Undefined Then
				ProxyServerSettings.Insert("UseSystemSettings", False);
				SaveUserSettings = True;
			EndIf;
			If SaveUserSettings Then
				CommonUse.CommonSettingsStorageSave(
					"ProxyServerSettings", , ProxyServerSettings, , InfoBaseUser.Name);
			EndIf;
			
		EndIf;
		
	EndDo;
	
	ProxyServerSettings = GetServerProxySettings();
	
	If TypeOf(ProxyServerSettings) = Type("Map") Then
		
		SaveServerSettings = False;
		If ProxyServerSettings.Get("UseProxy") = Undefined Then
			ProxyServerSettings.Insert("UseProxy", False);
			SaveServerSettings = True;
		EndIf;
		If ProxyServerSettings.Get("UseSystemSettings") = Undefined Then
			ProxyServerSettings.Insert("UseSystemSettings", False);
			SaveServerSettings = True;
		EndIf;
		If SaveServerSettings Then
			SaveServerProxySettings(ProxyServerSettings);
		EndIf;
		
	EndIf;
	
EndProcedure

