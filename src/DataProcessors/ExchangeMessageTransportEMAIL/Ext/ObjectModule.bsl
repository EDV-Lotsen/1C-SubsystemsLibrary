Var ErrorMessageString Export;
Var ErrorMessageStringEL Export;

Var mErrorMessages; // map that contains predefined error messages
Var mObjectName;		// metadata object name

Var mTempExchangeMessageFile; // temporary exchange message file for importing and exporting data
Var mTempExchangeMessageDirectory; // temporary exchange message directory

Var mMessageSubject;		// message subject pattern
Var mSimpleBody;	// message body text with attached XML file
Var mCompressedBody; // message body text with attached compressed file
Var mBatchBody; // message body text with attached compressed file that contains a file set

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

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
//  Boolean - True if the message was sent successfully, otherwise is False. 
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

// Receives an exchange message from the specified resource and puts it into the temporary exchange message directory.
// 
//  Returns:
//  Boolean - True if the message was received successfully, otherwise is False. 
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
//  Boolean - True if the specified resource contains an exchange message, otherwise is False.
//
Function ExchangeMessageFileExists() Export
	
	InitMessages();
	
	ColumnArray = New Array;
	ColumnArray.Add("Subject");
	
	DownloadParameters = New Structure;
	DownloadParameters.Insert("Columns", ColumnArray);
	DownloadParameters.Insert("GetHeaders", True);
	
	Try
		MessageSet = Email.DownloadEmailMessages(EMAILAccount, DownloadParameters);
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		GetErrorMessage(103);
		SupplementErrorMessage(ErrorText);
		Return False;
	EndTry;
	
	For Each Email In MessageSet Do
		
		If Upper(TrimAll(Email.Subject)) = Upper(TrimAll(mMessageSubject)) Then
			
			Return True;
			
		EndIf;
		
	EndDo;
	
	Return False;
EndFunction

// Initializes properties with initial values and constants
// 
Procedure Initialization() Export
	
	InitMessages();
	
	mMessageSubject = "Exchange message (%1)"; //this string does not require localization
	mMessageSubject = StringFunctionsClientServer.SubstituteParametersInString(mMessageSubject, MessageFileNamePattern);
	
	mSimpleBody	= NStr("en = 'Data exchange message");
	mCompressedBody	= NStr("en = 'Compressed data exchange message'");
	mBatchBody	= NStr("en = 'Batch data exchange message'");
	
EndProcedure

// Checking whether the connection to the specified resource can be established.
// 
// Returns:
//  Boolean – True if connection can be established, otherwise is False.
//
Function ConnectionIsSet() Export
	
	InitMessages();
	
	If Not ValueIsFilled(EMAILAccount) Then
		GetErrorMessage(101);
		Return False;
	EndIf;
	
	ErrorMessage = "";
	AdditionalMessage = "";
	Email.CheckSendReceiveEmailPossibility(EMAILAccount, Undefined, ErrorMessage, AdditionalMessage);
	
	If ValueIsFilled(ErrorMessage) Then
		GetErrorMessage(107);
		SupplementErrorMessage(ErrorMessage);
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

///////////////////////////////////////////////////////////////////////////////
// Functions for retrieving properties.

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

///////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.

Function CreateTempExchangeMessageDirectory()
	
	mTempExchangeMessageDirectory = New File(CommonUseClientServer.GetFullFileName(TempFilesDir(), DataExchangeServer.TempExchangeMessageDirectory()));
	
	// Creating the temporary exchange message directory
	Try
		CreateDirectory(ExchangeMessageDirectoryName());
	Except
		GetErrorMessage(4);
		SupplementErrorMessage(BriefErrorDescription(ErrorInfo()));
		Return False;
	EndTry;
	
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
			
			// Checking that the exchange message size does not exceed the maximum allowed size
			If DataExchangeServer.ExchangeMessageSizeExceedsAllowed(ArchiveTempFileName, MaxMessageSize()) Then
				GetErrorMessage(108);
				Result = False;
			EndIf;
			
		EndIf;
		
		If Result Then
			
			Result = SendMessagebyEmail(
									mCompressedBody,
									OutgoingMessageFileName,
									ArchiveTempFileName);
			
		EndIf;
		
	Else
		
		If Result Then
			
			// Checking that the exchange message size does not exceed the maximum allowed size
			If DataExchangeServer.ExchangeMessageSizeExceedsAllowed(ExchangeMessageFileName(), MaxMessageSize()) Then
				GetErrorMessage(108);
				Result = False;
			EndIf;
			
		EndIf;
		
		If Result Then
			
			Result = SendMessagebyEmail(
									mSimpleBody,
									OutgoingMessageFileName,
									ExchangeMessageFileName());
			
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

Function GetExchangeMessage()
	
	ExchangeMessageTable = New ValueTable;
	ExchangeMessageTable.Columns.Add("ID", New TypeDescription("Array"));
	ExchangeMessageTable.Columns.Add("PostDating", New TypeDescription("Date"));
	
	ColumnArray = New Array;
	
	ColumnArray.Add("ID");
	ColumnArray.Add("PostDating");
	ColumnArray.Add("Subject");
	
	DownloadParameters = New Structure;
	DownloadParameters.Insert("Columns", ColumnArray);
	DownloadParameters.Insert("GetHeaders", True);
	
	Try
		MessageSet = Email.DownloadEmailMessages(EMAILAccount, DownloadParameters);
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		GetErrorMessage(103);
		SupplementErrorMessage(ErrorText);
		Return False;
	EndTry;
	
	For Each Email In MessageSet Do
		
		If Upper(TrimAll(Email.Subject)) <> Upper(TrimAll(mMessageSubject)) Then
			Continue;
		EndIf;
		
		NewRow = ExchangeMessageTable.Add();
		FillPropertyValues(NewRow, Email);
		
	EndDo;
	
	If ExchangeMessageTable.Count() = 0 Then
		
		GetErrorMessage(104);
		
		MessageString = NStr("en = 'The messages with %1 header are not found.'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, mMessageSubject);
		SupplementErrorMessage(MessageString);
		
		Return False;
		
	Else
		
		ExchangeMessageTable.Sort("PostDating Desc");
		
		ColumnArray = New Array;
		ColumnArray.Add("Attachments");
		
		DownloadParameters = New Structure;
		DownloadParameters.Insert("Columns", ColumnArray);
		DownloadParameters.Insert("HeadersIDs", ExchangeMessageTable[0].ID);
		
		Try
			MessageSet = Email.DownloadEmailMessages(EMAILAccount, DownloadParameters);
		Except
			ErrorText = DetailErrorDescription(ErrorInfo());
			GetErrorMessage(105);
			SupplementErrorMessage(ErrorText);
			Return False;
		EndTry;
		
		BinaryData = MessageSet[0].Attachments.Get(MessageFileNamePattern+".zip");
		
		If BinaryData <> Undefined Then
			FilePacked = True;
		Else
			BinaryData = MessageSet[0].Attachments.Get(MessageFileNamePattern+".xml");
			FilePacked = False;
		EndIf;
			
		If BinaryData = Undefined Then
			GetErrorMessage(109);
			Return False;
		EndIf;
		
		If FilePacked Then
			
			// Getting the temporary archive file name
			ArchiveTempFileName = CommonUseClientServer.GetFullFileName(ExchangeMessageDirectoryName(), MessageFileNamePattern + ".zip");
			
			Try
				BinaryData.Write(ArchiveTempFileName);
			Except
				ErrorText = DetailErrorDescription(ErrorInfo());
				GetErrorMessage(106);
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
				BinaryData.Write(ExchangeMessageFileName());
			Except
				ErrorText = DetailErrorDescription(ErrorInfo());
				GetErrorMessage(106);
				SupplementErrorMessage(ErrorText);
				Return False;
			EndTry;
			
		EndIf;
		
	EndIf;
	
	Return True;
	
EndFunction

Procedure GetErrorMessage(MessageNo)
	
	SetErrorMessageString(mErrorMessages[MessageNo]);
	
EndProcedure

Procedure SetErrorMessageString(Val Message)
	
	If Message = Undefined Then
		Message = NStr("en = 'Internal error'");
	EndIf;
	
	ErrorMessageString   = Message;
	ErrorMessageStringEL = mObjectName + ": " + Message;
	
EndProcedure

Procedure SupplementErrorMessage(Message)
	
	ErrorMessageStringEL = ErrorMessageStringEL + Chars.LF + Message;
	
EndProcedure

// The overridable function, returns the maximum allowed size of a message to be sent.
// 
Function MaxMessageSize()
	
	Return EMAILMaxMessageSize;
	
EndFunction

///////////////////////////////////////////////////////////////////////////////
// Functions for retrieving properties.

// Retrieves a flag that shows that the outgoing message file is compressed.
// 
Function CompressOutgoingMessageFile()
	
	Return EMAILCompressOutgoingMessageFile;
	
EndFunction

///////////////////////////////////////////////////////////////////////////////
// Initialization

Procedure InitMessages()
	
	ErrorMessageString   = "";
	ErrorMessageStringEL = "";
	
EndProcedure

Procedure ErrorMessageInitialization()
	
	mErrorMessages = New Map;
	
	// Common error codes 
	mErrorMessages.Insert(001, NStr("en = 'Exchange messages are not detected.'"));
	mErrorMessages.Insert(002, NStr("en = 'Error unpacking the exchange message file.'"));
	mErrorMessages.Insert(003, NStr("en = 'Error packing the exchange message file.'"));
	mErrorMessages.Insert(004, NStr("en = 'Error creating the temporary directory'."));
	mErrorMessages.Insert(005, NStr("en = 'The archive does not contain the exchange message file.'"));
	mErrorMessages.Insert(006, NStr("en = 'Exchange message was not sent: the maximum allowed message size is exceeded.'"));
	
	// Errors codes that are dependent on the transport kind
	mErrorMessages.Insert(101, NStr("en = 'Initialization error: the exchange message transport email account is not specified.'"));
	mErrorMessages.Insert(102, NStr("en = 'Error sending the email message.'"));
	mErrorMessages.Insert(103, NStr("en = 'Error receiving message headers from the email server.'"));
	mErrorMessages.Insert(104, NStr("en = 'Exchange messages were not found on the email server.'"));
	mErrorMessages.Insert(105, NStr("en = 'Error receiving the message from the email server.'"));
	mErrorMessages.Insert(106, NStr("en = 'Error saving the exchange message file to the hard disk.'"));
	mErrorMessages.Insert(107, NStr("en = 'Errors occur when verifying account parameters.'"));
	mErrorMessages.Insert(108, NStr("en = 'The maximum allowed exchange message size is exceeded.'"));
	mErrorMessages.Insert(109, NStr("en = 'Error: no exchange message file is found in the email message.'"));
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Procedures and functions for working with Email.

Function SendMessagebyEmail(Body, OutgoingMessageFileName, PathToFile)
	
	Attachments = New Map;
	Attachments.Insert(OutgoingMessageFileName,
						New BinaryData(PathToFile));
	
	MessageParameters = New Structure;
	MessageParameters.Insert("Recipient", EMAILAccount.EmailAddress);
	MessageParameters.Insert("Subject", mMessageSubject);
	MessageParameters.Insert("Body", Body);
	MessageParameters.Insert("Attachments", Attachments);
	
	Try
		EmailOperations.SendMessage(EMAILAccount, MessageParameters);
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		GetErrorMessage(102);
		SupplementErrorMessage(ErrorText);
		Return False;
	EndTry;
	
	Return True;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Main application operators.

InitMessages();
ErrorMessageInitialization();

mTempExchangeMessageDirectory = Undefined;
mTempExchangeMessageFile    = Undefined;

mObjectName = NStr("en = 'Data processor: %1'");
mObjectName = StringFunctionsClientServer.SubstituteParametersInString(mObjectName, Metadata().Name);
