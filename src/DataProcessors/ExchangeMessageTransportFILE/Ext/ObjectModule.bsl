Var ErrorMessageString Export;
Var ErrorMessageStringEL Export;

Var mErrorMessages; // map that contains error messages
Var mObjectName; // metadata object name

Var mTempExchangeMessageFile; // temporary exchange message file for importing and exporting data 
Var mTempExchangeMessageDirectory; // temporary exchange message directory
Var mDataExchangeDirectory; // network exchange message directory

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Export internal procedures and functions.

// Creates a temporary directory in the temporary file directory of the operating system user.
// 
// Returns:
//  Boolean – True if the directory was created successfully, otherwise is False.
// 
Function ExecuteActionsBeforeMessageProcessing() Export
	
	InitMessages();
	
	Return CreateTempExchangeMessageDirectory();
	
EndFunction

// Sends the exchange message to the specified resource from the temporary exchange message directory.
// 
// Returns:
//  Boolean – True if the message was sent successfully, otherwise is False.
// 
Function SendMessage() Export
	
	Result = True;
	
	InitMessages();
	
	Try
		
		If UseTempDirectoryForSendingAndReceivingMessages Then
			
			Result = SendExchangeMessage();
			
		EndIf;
		
	Except
		Result = False;
	EndTry;
	
	Return Result;
	
EndFunction

// Receives an exchange message from the specified resource and puts it into the temporary exchange message directory.
//
// Returns:
//  Boolean – True if the message was received successfully, otherwise is False.
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
// Returns:
//  Boolean - True.
//
Function ExecuteAfterMessageProcessingActions() Export
	
	InitMessages();
	
	If UseTempDirectoryForSendingAndReceivingMessages Then
		
		DeleteTempExchangeMessageDirectory();
		
	EndIf;
	
	Return True;
EndFunction

// Checking whether the specified resource contains an exchange message.
// 
// Returns:
//  Boolean - True if the specified resource contains an exchange message, otherwise is False.
//
Function ExchangeMessageFileExists() Export
	
	Return (FindFiles(DataExchangeDirectoryName(), MessageFileNamePattern + ".*", False).Count() > 0);
	
EndFunction

// Initializes properties with initial values and constants.
// 
Procedure Initialization() Export
	
	mDataExchangeDirectory = New File(FILEDataExchangeDirectory);
	
EndProcedure

// Checking whether the connection to the specified resource can be established.
//
// Returns:
//  Boolean – True if the connection to the specified resource can be established, 
//            otherwise is False.
//
Function ConnectionIsSet() Export
	
	InitMessages();
	
	If IsBlankString(FILEDataExchangeDirectory) Then
		
		GetErrorMessage(1);
		Return False;
		
	ElsIf Not mDataExchangeDirectory.Exist() Then
		
		GetErrorMessage(2);
		Return False;
		
	ElsIf Not CreateCheckFile() Then
		
		GetErrorMessage(8);
		Return False;
		
	ElsIf Not DeleteCheckFiles() Then
		
		GetErrorMessage(9);
		Return False;
		
	EndIf;
	
	Return True;
	
EndFunction

///////////////////////////////////////////////////////////////////////////////
// Functions for retrieving properties.

// Retrieves the full name of the exchange message file.
//
// Returns:
//  String.
//
Function ExchangeMessageFileName() Export
	
	Name = "";
	
	If TypeOf(mTempExchangeMessageFile) = Type("File") Then
		
		Name = mTempExchangeMessageFile.FullName;
		
	EndIf;
	
	Return Name;
	
EndFunction

// Retrieves the full name of the exchange message directory.
//
// Returns:
//  String.
//
Function ExchangeMessageDirectoryName() Export
	
	Name = "";
	
	If TypeOf(mTempExchangeMessageDirectory) = Type("File") Then
		
		Name = mTempExchangeMessageDirectory.FullName;
		
	EndIf;
	
	Return Name;
	
EndFunction


// Retrieves the full name of the data exchange directory (local or network).
//
// Returns:
//  String.
//
Function DataExchangeDirectoryName() Export
	
	Name = "";
	
	If TypeOf(mDataExchangeDirectory) = Type("File") Then
		
		Name = mDataExchangeDirectory.FullName;
		
	EndIf;
	
	Return Name;
	
EndFunction


// Retrieves the exchange message file date.
//
// Returns:
//  Date.
//
Function ExchangeMessageFileDate() Export
	
	Result = Undefined;
	
	If TypeOf(mTempExchangeMessageFile) = Type("File") Then
		
		If mTempExchangeMessageFile.Exist() Then
			
			Result = mTempExchangeMessageFile.GetModificationTime();
			
		EndIf;
		
	EndIf;
	
	Return Result;
EndFunction

///////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.

Function CreateTempExchangeMessageDirectory()
	
	If UseTempDirectoryForSendingAndReceivingMessages Then
		
		TempDirectoryName = CommonUseClientServer.GetFullFileName(TempFilesDir(), DataExchangeServer.TempExchangeMessageDirectory());
		
		mTempExchangeMessageDirectory = New File(TempDirectoryName);
		
		// Creating the temporary exchange message directory
		Try
			CreateDirectory(ExchangeMessageDirectoryName());
		Except
			GetErrorMessage(6);
			SupplementErrorMessage(BriefErrorDescription(ErrorInfo()));
			Return False;
		EndTry;
		
	Else
		
		mTempExchangeMessageDirectory = New File(DataExchangeDirectoryName());
		
	EndIf;
	
	MessageFileName = CommonUseClientServer.GetFullFileName(ExchangeMessageDirectoryName(), MessageFileNamePattern + ".xml");
	
	mTempExchangeMessageFile = New File(MessageFileName);
	
	Return True;
EndFunction

Function DeleteTempExchangeMessageDirectory()
	
	Try
		
		If Not IsBlankString(ExchangeMessageDirectoryName()) Then
			
			DeleteFiles(ExchangeMessageDirectoryName());
			
			mTempExchangeMessageDirectory = Undefined;
			
		EndIf;
		
	Except
		Return False;
	EndTry;
	
	Return True;
EndFunction

Function SendExchangeMessage()
	
	Result = True;
	
	Extension = ?(CompressOutgoingMessageFile(), "zip", "xml");
	
	OutgoingMessageFileName = CommonUseClientServer.GetFullFileName(DataExchangeDirectoryName(), MessageFileNamePattern + "." + Extension);
	
	If CompressOutgoingMessageFile() Then
		
		// Getting the temporary archive file name
		ArchiveTempFileName = CommonUseClientServer.GetFullFileName(ExchangeMessageDirectoryName(), MessageFileNamePattern + ".zip");
		
		Try
			
			Archiver = New ZipFileWriter(ArchiveTempFileName, ExchangeMessageArchivePassword, "Exchange message file");
			Archiver.Add(ExchangeMessageFileName());
			Archiver.Write();
			
		Except
			Result = False;
			GetErrorMessage(5);
			SupplementErrorMessage(BriefErrorDescription(ErrorInfo()));
		EndTry;
		
		Archiver = Undefined;
		
		If Result Then
			
			// Copying the archive file to the data exchange directory
			If Not ExecuteFileCopying(ArchiveTempFileName, OutgoingMessageFileName) Then
				Result = False;
			EndIf;
			
		EndIf;
		
	Else
		
		// Copying the message file to the data exchange directory
		If Not ExecuteFileCopying(ExchangeMessageFileName(), OutgoingMessageFileName) Then
			Result = False;
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

Function GetExchangeMessage()
	
	ExchangeMessageFileTable = New ValueTable;
	ExchangeMessageFileTable.Columns.Add("File", New TypeDescription("File"));
	ExchangeMessageFileTable.Columns.Add("ModifiedAt");
	
	FoundFileArray = FindFiles(DataExchangeDirectoryName(), MessageFileNamePattern + ".*", False);
	
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
		
		// The file is a required exchange message.
   // Adding the file to the table.
		TableRow            = ExchangeMessageFileTable.Add();
		TableRow.File       = CurrentFile;
		TableRow.ModifiedAt = CurrentFile.GetModificationTime();
		
	EndDo;
	
	If ExchangeMessageFileTable.Count() = 0 Then
		
		GetErrorMessage(3);
		
		MessageString = NStr("en = 'Data exchange directory is %1.'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, DataExchangeDirectoryName());
		SupplementErrorMessage(MessageString);
		
		MessageString = NStr("en = 'Exchange message file name is %1 or %2.'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, MessageFileNamePattern + ".xml", MessageFileNamePattern + ".zip");
		SupplementErrorMessage(MessageString);
		
		Return False;
		
	Else
		
		ExchangeMessageFileTable.Sort("ModifiedAt Desc");
		
		// Getting the latest exchange message file from the table
		IncomingMessageFile = ExchangeMessageFileTable[0].File;
		
		FilePacked = (Upper(IncomingMessageFile.Extension) = ".ZIP");
		
		If FilePacked Then
			
			// Getting the temporary archive file name
			ArchiveTempFileName = CommonUseClientServer.GetFullFileName(ExchangeMessageDirectoryName(), MessageFileNamePattern + ".zip");
			
			// Copy the archive file from the network directory to the temporary one.
			If Not ExecuteFileCopying(IncomingMessageFile.FullName, ArchiveTempFileName) Then
				Return False;
			EndIf;
			
			// Unpacking the temporary archive file
			UnpackedSuccessfully = DataExchangeServer.UnpackZipFile(ArchiveTempFileName, ExchangeMessageDirectoryName(), ExchangeMessageArchivePassword);
			
			If Not UnpackedSuccessfully Then
				GetErrorMessage(4);
				Return False;
			EndIf;
			
			// Checking that the message file exists
			File = New File(ExchangeMessageFileName());
			
			If Not File.Exist() Then
				
				GetErrorMessage(7);
				Return False;
				
			EndIf;
			
		Else
			
			// Copying the file of the incoming message from the exchange directory to the temporary file directory
			If UseTempDirectoryForSendingAndReceivingMessages And Not ExecuteFileCopying(IncomingMessageFile.FullName, ExchangeMessageFileName()) Then
				
				Return False;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return True;
EndFunction

Function CreateCheckFile()
	
	TextDocument = New TextDocument;
	TextDocument.AddLine(NStr("en = 'Temporary test file'"));
	
	Try
		
		TextDocument.Write(CommonUseClientServer.GetFullFileName(DataExchangeDirectoryName(), FlagTempFileName()));
		
	Except
		WriteLogEvent(NStr("en = 'Data exchange'", Metadata.DefaultLanguage.LanguageCode), EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Return False;
	EndTry;
	
	Return True;
EndFunction

Function DeleteCheckFiles()
	
	Try
		
		DeleteFiles(DataExchangeDirectoryName(), FlagTempFileName());
		
	Except
		WriteLogEvent(NStr("en = 'Data exchange'", Metadata.DefaultLanguage.LanguageCode), EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Return False;
	EndTry;
	
	Return True;
EndFunction

Function ExecuteFileCopying(Val SourceFileName, Val TargetFileName)
	// Copying the file
	
	Try
		
		FileCopy(SourceFileName, TargetFileName);
		
	Except
		
		MessageString = NStr("en = 'Error copying the file from %1 to %2. Error details: %3'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString,
							SourceFileName,
							TargetFileName,
							BriefErrorDescription(ErrorInfo()));
		
		SetErrorMessageString(MessageString);
		
		Return False
		
	EndTry;
	
	Return True;
	
EndFunction

Procedure GetErrorMessage(MessageNo)
	
	SetErrorMessageString(mErrorMessages[MessageNo])
	
EndProcedure

Procedure SetErrorMessageString(Val Message)
	
	If Message = Undefined Then
		Message = "Internal error";
	EndIf;
	
	ErrorMessageString   = Message;
	ErrorMessageStringEL = mObjectName + ": " + Message;
	
EndProcedure

Procedure SupplementErrorMessage(Message)
	
	ErrorMessageStringEL = ErrorMessageStringEL + Chars.LF + Message;
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Functions for retrieving properties.

Function CompressOutgoingMessageFile()
	
	Return FILECompressOutgoingMessageFile;
	
EndFunction

Function FlagTempFileName()
	
	Return "flag.tmp";
	
EndFunction

///////////////////////////////////////////////////////////////////////////////
// Initialization.

Procedure InitMessages()
	
	ErrorMessageString   = "";
	ErrorMessageStringEL = "";
	
EndProcedure

Procedure ErrorMessageInitialization()
	
	mErrorMessages = New Map;
	mErrorMessages.Insert(1, NStr("en = 'Connection error: The data exchange directory is not specified.'"));
	mErrorMessages.Insert(2, NStr("en = 'Connection error: The data exchange directory does not exist.'"));
	
	mErrorMessages.Insert(3, NStr("en = 'No message file with data was found in the exchange directory.'"));
	mErrorMessages.Insert(4, NStr("en = 'Error unpacking the exchange message file.'"));
	mErrorMessages.Insert(5, NStr("en = 'Error packing the exchange message file.'"));
	mErrorMessages.Insert(6, NStr("en = 'Error creating the temporary directory.'"));
	mErrorMessages.Insert(7, NStr("en = 'The archive does not contain the exchange message file.'"));
	
	mErrorMessages.Insert(8, NStr("en = 'Error saving the file to the data exchange directory. Check user access rights to the directory.'"));
	mErrorMessages.Insert(9, NStr("en = 'Error deleting the file from data exchange directory. Check user access rights to the directory.'"));
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Main application operators

InitMessages();
ErrorMessageInitialization();

mTempExchangeMessageDirectory = Undefined;
mTempExchangeMessageFile    = Undefined;

mObjectName = NStr("en = 'Data processor: %1'");
mObjectName = StringFunctionsClientServer.SubstituteParametersInString(mObjectName, Metadata().Name);
