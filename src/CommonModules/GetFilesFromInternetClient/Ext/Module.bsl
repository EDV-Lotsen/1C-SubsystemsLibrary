
// Common interface function for getting file from the Internet via http(s) protocol
// or ftp protocol and saving it to a temporary storage.
//
// Parameters:
// URL*           			 - String  - file url in format:
//                						 [Protocol://]<Server>/<Path to the file at server>
// DownloadParameters* 	 - structure with keys:
//         DownloadFolderPath 		 - string  - path at client (including file name)
//         User  			 - String  - user, under whose name connection is established
//         Password          - string  - user password under whose name connection is established
//         Port          	 - number  - connection is established on this server port
//         SecureConnection  - Boolean - for http load flag indicates,
//                                  that connection should be established via https
//         PassiveConnection -  - Boolean - for ftp load flag indicates,
//                                  that connection should be passive (or active)
//
// marked by sign '*' are mandatory
//
// Value returned:
// Structure
// Status 			 - Boolean 		- key is alway present in the structure, values
//                   					 True 	- function call has successfully been completed
//                  					 False  - function call has failed
// Path 			 - String  		- path to the file at client, key is used only
//                 				if status is True
// ErrorMessage - String - error message, if status is False
//
Function DownloadFileAtClient(Val URL, Val DownloadParameters = Undefined) Export
	
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
	SaveSetting.Insert("StoragePlace", "Client");
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
