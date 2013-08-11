////////////////////////////////////////////////////////////////////////////////
// Get files from internet subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// The common interface function that receives a file from the internet with HTTP(S) 
// or FTP protocol and saves it to a temporary file.
//
// Parameters:
//  URL*                   - String - file URL in the following format:
//                           [Protocol://]<Server>/<Path to the file on server>
//  ReceivingParameters*   - structure with the following keys:
//   PathForSaving          - String - path at the client (including the file name) 
//                           where the downloaded file will be saved.
//   User                   - String - user on behalf of which the connection is 
//                           established.
//   Password               - String - password of the user on behalf of which the 
//                           connection is established.
//   Port                   - Number - port that is used for establishing the
//                           connection.
//   SecureConnection       - Boolean - in case of HTTP this flag shows
//                           whether a secure HTTPS connection is used.
//   PassiveConnection      - Boolean - in case of FTP this flag shows 
//                           whether the connection mode is passive or active;
//
// Parameters marked with * are mandatory.
//
// Returns:
//  Structure with the following keys:
//   State        - Boolean - this key always exists in the structure. It can take 
//                  on the following values:
//                   True if function execution completed successfully,
//                   False if function execution failed.
//   Path         - String - path to the file at the client. This key is used only if
//                  State is True.
//   ErrorMessage - String - error message if State is False.
//
Function DownloadFileAtClient(Val URL, Val ReceivingParameters = Undefined) Export
	
	// Declaring variables before their first use as the Property 
	// method parameter.
	Var PathForSaving, User, Password, Port, SecureConnection, PassiveConnection;
	
	// Retrieving parameters to receive the file 
	
	If ReceivingParameters = Undefined Then
		ReceivingParameters = New Structure;
	EndIf;
	
	ReceivingParameters.Property("PathForSaving", PathForSaving);
	ReceivingParameters.Property("User", User);
	ReceivingParameters.Property("Password", Password);
	ReceivingParameters.Property("Port", Port);
	ReceivingParameters.Property("SecureConnection", SecureConnection);
	ReceivingParameters.Property("PassiveConnection", PassiveConnection);
	
	SavingSettings = New Map;
	SavingSettings.Insert("Storage", "Client");
	SavingSettings.Insert("Path", PathForSaving);
	
	Result = GetFilesFromInternetClientServer.PrepareFileReceiving(
		URL,
		User,
		Password,
		Port,
		SecureConnection,
		PassiveConnection,
		SavingSettings
	);
	
	Return Result;
	
EndFunction
