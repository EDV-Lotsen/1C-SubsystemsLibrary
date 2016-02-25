#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Var ErrorMessageString Export;
Var ErrorMessageStringEL Export;

Var ErrorMessages; // map that contains predefined error messages
Var ObjectName;		// metadata object name
Var FTPServerName;		// FTP server address (name or IP)
Var DirectoryAtFTPServer;// Directory on server for storing and receiving exchange messages

Var TempExchangeMessageFile; // temporary exchange message file for importing and exporting data
Var TempExchangeMessageDirectory; // temporary exchange message directory

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Export internal procedures and functions.

// Creates a temporary directory in the temporary file directory of the operating system user.
// 
//  Returns:
//  Boolean - True if the directory was created successfully, otherwise is False.
// 
Function ExecuteActionsBeforeMessageProcessing() Export
	
	InitMessages();
	
	Return CreateTempExchangeMessageDirectory();
	
EndFunction

// Sends the exchange message to the specified resource from the temporary exchange message directory.
// 
//  Returns:
//  Boolean - True if the directory was created successfully, otherwise is False.
// 
Function SendMessage() Export
	
	InitMessages();
	
	Try
		Result = SendExchangeMessage();
	Except
		Result = False;
	EndTry;
	
	Return Result;
	
EndFunction

// Receives an exchange message from the specified resource and puts it into the 
// temporary exchange message durectory.
// 
//  Returns:
//  Boolean - True if the directory was created successfully, otherwise is False.
// 
Function ReceiveMessage() Export
	
	InitMessages();
	
	Try
		Result = GetExchangeMessage();
	Except
		Result = False;
	EndTry;
	
	Return Result;
	
EndFunction

// Deletes the temporary exchange message directory after performing data import and export.
// 
//  Returns:
//  Boolean - True.
//
Function ExecuteAfterMessageProcessingActions() Export
	
	InitMessages();
	
	DeleteTempExchangeMessageDirectory();
	
	Return True;
	
EndFunction

// Checking whether the specified resource contains an exchange message.
// 
//  Returns:
//  Boolean - True if the specified resource contains an exchange message, False otherwise.
//
Function ExchangeMessageFileExists() Export
	
	InitMessages();
	
	Try
		FTPConnection = GetFTPConnection();
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		GetErrorMessage(102);
		SupplementErrorMessage(ErrorText);
		Return False;
	EndTry;
	
	Try
		FoundFileArray = FTPConnection.FindFiles(DirectoryAtFTPServer, MessageFileNamePattern + ".*", False);
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		GetErrorMessage(104);
		SupplementErrorMessage(ErrorText);
		Return False;
	EndTry;
	
	Return FoundFileArray.Count() > 0;
	
EndFunction

// Initializes properties with initial values and constants.
// 
Procedure Initialization() Export
	
	InitMessages();
	
	ServerNameAndDirectoryAtServer = SplitFTPResourceToServerAndDirectory(TrimAll(FTPConnectionPath));
	FTPServerName			             = ServerNameAndDirectoryAtServer.ServerName;
	DirectoryAtFTPServer           = ServerNameAndDirectoryAtServer.DirectoryName;
	
EndProcedure

// Checking whether the connection to the specified resource can be established.
// 
//  Returns:
//  Boolean - True if connection can be established, otherwise is False.
//
Function ConnectionIsSet() Export
	
	// Return value
	Result = True;
	
	InitMessages();
	
	If IsBlankString(FTPConnectionPath) Then
		
		GetErrorMessage(101);
		Return False;
		
	EndIf;
	
	// Creating a file in the temporary directory
	TempConnectionCheckFileName = GetTempFileName("tmp");
	FileNameForTarget = DataExchangeServer.TestConnectionFileName();
	
	TextWriter = New TextWriter(TempConnectionCheckFileName);
	TextWriter.WriteLine(FileNameForTarget);
	TextWriter.Close();
	
	// Coping the file to the external resource from the temporary directory
	Result = CopyFileToFTPServer(TempConnectionCheckFileName, FileNameForTarget);
	
	// Deleting file from the external resource
	If Result Then
		
		Result = DeleteFileAtFTPServer(FileNameForTarget, True);
		
	EndIf;
	
	// Deleting file from the temporary directory
	Try
		DeleteFiles(TempConnectionCheckFileName);
	Except
	EndTry;
	
	Return Result;
EndFunction

///////////////////////////////////////////////////////////////////////////////
// Functions for retrieving properties.

// Retrieves the exchange message file modification date.
//
// Returns:
//  Date - exchange message file modification date.
//
Function ExchangeMessageFileDate() Export
	
	Result = Undefined;
	
	If TypeOf(TempExchangeMessageFile) = Type("File") Then
		
		If TempExchangeMessageFile.Exist() Then
			
			Result = TempExchangeMessageFile.GetModificationTime();
			
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

// Retrieves the full name of the exchange message file.
//
// Returns:
//  String - full name of the exchange message file.
//
Function ExchangeMessageFileName() Export
	
	Name = "";
	
	If TypeOf(TempExchangeMessageFile) = Type("File") Then
		
		Name = TempExchangeMessageFile.FullName;
		
	EndIf;
	
	Return Name;
	
EndFunction

// Retrieves the full name of the exchange message directory.
//
// Returns:
//  String - full name of the exchange message directory.
//
Function ExchangeMessageDirectoryName() Export
	
	Name = "";
	
	If TypeOf(TempExchangeMessageDirectory) = Type("File") Then
		
		Name = TempExchangeMessageDirectory.FullName;
		
	EndIf;
	
	Return Name;
	
EndFunction

///////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.

Function CreateTempExchangeMessageDirectory()
	
	// Creating the temporary exchange message directory
	Try
		TempDirectoryName = DataExchangeServer.CreateTempExchangeMessageDirectory();
	Except
		GetErrorMessage(4);
		SupplementErrorMessage(BriefErrorDescription(ErrorInfo()));
		Return False;
	EndTry;
	
	TempExchangeMessageDirectory = New File(TempDirectoryName);
	
	MessageFileName = CommonUseClientServer.GetFullFileName(ExchangeMessageDirectoryName(), MessageFileNamePattern + ".xml");
	
	TempExchangeMessageFile = New File(MessageFileName);
	
	Return True;
EndFunction

Function DeleteTempExchangeMessageDirectory()
	
	Try
		If Not IsBlankString(ExchangeMessageDirectoryName()) Then
			DeleteFiles(ExchangeMessageDirectoryName());
			TempExchangeMessageDirectory = Undefined;
		EndIf;
	Except
		Return False;
	EndTry;
	
	Return True;
	
EndFunction

Function SendExchangeMessage()
	
	Result = True;
	
	Extension = ?(CompressOutgoingMessageFile(), ".zip", ".xml");
	
	OutgoingMessageFileName = MessageFileNamePattern + Extension;
	
	If CompressOutgoingMessageFile() Then
		
		// Getting the temporary archive file name
		ArchiveTempFileName = CommonUseClientServer.GetFullFileName(ExchangeMessageDirectoryName(), MessageFileNamePattern + ".zip");
		
		Try
			
			Archiver = New ZipFileWriter(ArchiveTempFileName, ExchangeMessageArchivePassword, NStr("en = 'Exchange message file'"));
			Archiver.Add(ExchangeMessageFileName());
			Archiver.Write();
			
		Except
			
			Result = False;
			GetErrorMessage(3);
			SupplementErrorMessage(BriefErrorDescription(ErrorInfo()));
			
		EndTry;
		
		Archiver = Undefined;
		
		If Result Then
			
			// Checking that the exchange message size does not exeed the maximum allowed size
			If DataExchangeServer.ExchangeMessageSizeExceedsAllowed(ArchiveTempFileName, MaxMessageSize()) Then
				GetErrorMessage(108);
				Result = False;
			EndIf;
			
		EndIf;
		
		If Result Then
			
			// Copying the archive file to the FTP server in the data exchange directory
			If Not CopyFileToFTPServer(ArchiveTempFileName, OutgoingMessageFileName) Then
				Result = False;
			EndIf;
			
		EndIf;
		
	Else
		
		If Result Then
			
			// Checking that the exchange message size does not exeed the maximum allowed size
			If DataExchangeServer.ExchangeMessageSizeExceedsAllowed(ExchangeMessageFileName(), MaxMessageSize()) Then
				GetErrorMessage(108);
				Result = False;
			EndIf;
			
		EndIf;
		
		If Result Then
			
			// Copying the archive file to the FTP server in the data exchange directory
			If Not CopyFileToFTPServer(ExchangeMessageFileName(), OutgoingMessageFileName) Then
				Result = False;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

Function GetExchangeMessage()
	
	ExchangeMessageFileTable = New ValueTable;
	ExchangeMessageFileTable.Columns.Add("File");
	ExchangeMessageFileTable.Columns.Add("Modified");
	
	Try
		FTPConnection = GetFTPConnection();
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		GetErrorMessage(102);
		SupplementErrorMessage(ErrorText);
		Return False;
	EndTry;
	
	Try
		FoundFileArray = FTPConnection.FindFiles(DirectoryAtFTPServer, MessageFileNamePattern + ".*", False);
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		GetErrorMessage(104);
		SupplementErrorMessage(ErrorText);
		Return False;
	EndTry;
	
	For Each CurrentFile In FoundFileArray Do
		
		// Verifying the extension
		If ((Upper(CurrentFile.Extension) <> ".ZIP")
			And (Upper(CurrentFile.Extension) <> ".XML")) Then
			
			Continue;
			
		// Checking that CurrentFile is a file but not a directory
		ElsIf (CurrentFile.IsFile() = False) Then
			
			Continue;
			
		// Checking that the file size is greater than 0
		ElsIf (CurrentFile.Size() = 0) Then
			
			Continue;
			
		EndIf;
		
		// The file is a required exchange message. Adding the file to the table.
		TableRow = ExchangeMessageFileTable.Add();
		TableRow.File           = CurrentFile;
		TableRow.Modified = CurrentFile.GetModificationTime();
		
	EndDo;
	
	If ExchangeMessageFileTable.Count() = 0 Then
		
		GetErrorMessage(1);
		
		MessageString = NStr("en = 'The data exchange directory on the server is %1.'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, DirectoryAtFTPServer);
		SupplementErrorMessage(MessageString);
		
		MessageString = NStr("en = 'Exchange message file name is %1 or %2'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, MessageFileNamePattern + ".xml", MessageFileNamePattern + ".zip");
		SupplementErrorMessage(MessageString);
		
		Return False;
		
	Else
		
		ExchangeMessageFileTable.Sort("Modified Desc");
		
		// Getting the latest exchange message file from the table
		IncomingMessageFile = ExchangeMessageFileTable[0].File;
		
		FilePacked = (Upper(IncomingMessageFile.Extension) = ".ZIP");
		
		If FilePacked Then
			
			// Getting the temporary archive file name
			ArchiveTempFileName = CommonUseClientServer.GetFullFileName(ExchangeMessageDirectoryName(), MessageFileNamePattern + ".zip");
			
			Try
				FTPConnection.Get(IncomingMessageFile.FullName, ArchiveTempFileName);
			Except
				ErrorText = DetailErrorDescription(ErrorInfo());
				GetErrorMessage(105);
				SupplementErrorMessage(ErrorText);
				Return False;
			EndTry;
			
			// Unpacking the temporary archive file
			UnpackedSuccessfully = DataExchangeServer.UnpackZipFile(ArchiveTempFileName, ExchangeMessageDirectoryName(), ExchangeMessageArchivePassword);
			
			If Not UnpackedSuccessfully Then
				GetErrorMessage(2);
				Return False;
			EndIf;
			
			// Checking that the message file exists
			File = New File(ExchangeMessageFileName());
			
			If Not File.Exist() Then
				
				GetErrorMessage(5);
				Return False;
				
			EndIf;
			
		Else
			Try
				FTPConnection.Get(IncomingMessageFile.FullName, ExchangeMessageFileName());
			Except
				ErrorText = DetailErrorDescription(ErrorInfo());
				GetErrorMessage(105);
				SupplementErrorMessage(ErrorText);
				Return False;
			EndTry;
		EndIf;
		
	EndIf;
	
	Return True;
	
EndFunction

Procedure GetErrorMessage(MessageNo)
	
	SetErrorMessageString(ErrorMessages[MessageNo]);
	
EndProcedure

Procedure SetErrorMessageString(Val Message)
	
	If Message = Undefined Then
		Message = NStr("en = 'Internal error'");
	EndIf;
	
	ErrorMessageString   = Message;
	ErrorMessageStringEL = ObjectName + ": " + Message;
	
EndProcedure

Procedure SupplementErrorMessage(Message)
	
	ErrorMessageStringEL = ErrorMessageStringEL + Chars.LF + Message;
	
EndProcedure

// The overridable function, returns
// the maximum allowed size of a message to be sent.
// 
Function MaxMessageSize()
	
	Return FTPConnectionMaxMessageSize;
	
EndFunction

///////////////////////////////////////////////////////////////////////////////
// Functions for retrieving properties.

Function CompressOutgoingMessageFile()
	
	Return FTPCompressOutgoingMessageFile;
	
EndFunction

///////////////////////////////////////////////////////////////////////////////
// Initialization.

Procedure InitMessages()
	
	ErrorMessageString   = "";
	ErrorMessageStringEL = "";
	
EndProcedure

Procedure ErrorMessageInitialization()
	
	ErrorMessages = New Map;
	
	// Common error codes
	ErrorMessages.Insert(001, NStr("en = 'No message file with data was found in the exchange directory.'"));
	ErrorMessages.Insert(002, NStr("en = 'Error unpacking the exchange message file.'"));
	ErrorMessages.Insert(003, NStr("en = 'Error packing the exchange message file.'"));
	ErrorMessages.Insert(004, NStr("en = 'Error creating the temporary directory.'"));
	ErrorMessages.Insert(005, NStr("en = 'The archive does not contain the exchange message file.'"));
	
	// Errors codes that are dependent on the transport kind
	ErrorMessages.Insert(101, NStr("en = 'Path on the server is not specified.'"));
	ErrorMessages.Insert(102, NStr("en = 'Error initializing connection to the FTP server.'"));
	ErrorMessages.Insert(103, NStr("en = 'Error establishing connection to the FTP server. Check whether the path is specified correctly and whether access rights are sufficient.'"));
	ErrorMessages.Insert(104, NStr("en = 'Error searching for files on the FTP server.'"));
	ErrorMessages.Insert(105, NStr("en = 'Error receiving the file from the FTP server.'"));
	ErrorMessages.Insert(106, NStr("en = 'Error deleting the file from the FTP server. Check whether resource access rights are sufficient.'"));
	
	ErrorMessages.Insert(108, NStr("en = 'The maximum allowed exchange message size is exceeded.'"));
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Procedures and functions for working with FTP connection.

Function GetFTPConnection()
	
	FTPSettings                   = DataExchangeServer.FTPConnectionSettings();
	FTPSettings.Server            = FTPServerName;
	FTPSettings.Port              = FTPConnectionPort;
	FTPSettings.UserName          = FTPConnectionUser;
	FTPSettings.UserPassword      = FTPConnectionPassword;
	FTPSettings.PassiveConnection = FTPConnectionPassiveConnection;
	
	Return DataExchangeServer.FTPConnection(FTPSettings);
	
EndFunction

Function CopyFileToFTPServer(Val SourceFileName, TargetFileName)
	
	Var DirectoryAtServer;
	
	ServerAndDirectoryAtServer = SplitFTPResourceToServerAndDirectory(TrimAll(FTPConnectionPath));
	DirectoryAtServer          = ServerAndDirectoryAtServer.DirectoryName;
	
	Try
		FTPConnection = GetFTPConnection();
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		GetErrorMessage(102);
		SupplementErrorMessage(ErrorText);
		Return False;
	EndTry;
	
	Try
		FTPConnection.Put(SourceFileName, DirectoryAtServer + TargetFileName);
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		GetErrorMessage(103);
		SupplementErrorMessage(ErrorText);
		Return False;
	EndTry;
	
	Try
		FileArray = FTPConnection.FindFiles(DirectoryAtServer, TargetFileName, False);
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		GetErrorMessage(104);
		SupplementErrorMessage(ErrorText);
		Return False;
	EndTry;
	
	Return FileArray.Count() > 0;
	
EndFunction

Function DeleteFileAtFTPServer(Val FileName, ConnectionCheck = False)
	
	Var DirectoryAtServer;
	
	ServerAndDirectoryAtServer = SplitFTPResourceToServerAndDirectory(TrimAll(FTPConnectionPath));
	DirectoryAtServer = ServerAndDirectoryAtServer.DirectoryName;
	
	Try
		FTPConnection = GetFTPConnection();
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		GetErrorMessage(102);
		SupplementErrorMessage(ErrorText);
		Return False;
	EndTry;
	
	Try
		FTPConnection.Delete(DirectoryAtServer + FileName);
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		GetErrorMessage(106);
		SupplementErrorMessage(ErrorText);
		
		If ConnectionCheck Then
			
			ErrorMessage = NStr("en = 'Cannot test connection using the test file %1.
			|The specified directory is inaccessible or does not exist.
			|We recommend that you check the FTP server documentation for information about support of non-Latin characters in file names.'");
			ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(ErrorMessage, DataExchangeServer.TestConnectionFileName());
			SupplementErrorMessage(ErrorMessage);
			
		EndIf;
		
		Return False;
	EndTry;
	
	Return True;
	
EndFunction

Function SplitFTPResourceToServerAndDirectory(Val FullPath)
	
	Result = New Structure("ServerName, DirectoryName");
	
	FTPParameters = DataExchangeServer.FTPServerNameAndPath(FullPath);
	
	Result.ServerName    = FTPParameters.Server;
	Result.DirectoryName = FTPParameters.Path;
	
	Return Result;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Main application operators.

InitMessages();
ErrorMessageInitialization();

TempExchangeMessageDirectory = Undefined;
TempExchangeMessageFile      = Undefined;

FTPServerName        = Undefined;
DirectoryAtFTPServer = Undefined;

ObjectName = NStr("en = 'Data processor: %1'");
ObjectName = StringFunctionsClientServer.SubstituteParametersInString(ObjectName, Metadata().Name);

#EndRegion

#EndIf