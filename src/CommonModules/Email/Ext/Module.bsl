////////////////////////////////////////////////////////////////////////////////
// Email operations subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Sends email messages. Checks whether the email account is filled correctly and
// calls the function that implements the mechanism of email sending.
// 
// See SendMessage function parameters for details.
// 
// Note: The EmailParameters.Attachments parameter can contain binary data or addresses 
// in the temporary storage where data is stored.
//
Function SendEmailMessage(Val Account,
	 Val EmailParameters,
	 Val Connection = Undefined) Export
	
	If TypeOf(Account) <> Type("CatalogRef.EmailAccounts")
	 Or Not ValueIsFilled(Account) Then
		Raise NStr("en = 'The email account is not filled or filled incorrectly.'");
	EndIf;
	
	If EmailParameters = Undefined Then
		Raise NStr("en = 'Send parameters are not filled.'");
	EndIf;
	
	TypeOfRecipient = ?(EmailParameters.Property("Recipient"), TypeOf(EmailParameters.Recipient), Undefined);
	TypeOfCc = ?(EmailParameters.Property("Cc"), TypeOf(EmailParameters.Cc), Undefined);
	TypeOfBcc = ?(EmailParameters.Property("Bcc"), TypeOf(EmailParameters.Bcc), Undefined);
	
	If TypeOfRecipient = Undefined And TypeOfCc = Undefined And TypeOfBcc = Undefined Then
		Raise NStr("en = 'No recipients are specified.'");
	EndIf;
	
	If TypeOfRecipient = Type("String") Then
		EmailParameters.Recipient = CommonUseClientServer.SplitStringWithEmailAddresses(EmailParameters.Recipient);
	ElsIf TypeOfRecipient <> Type("Array") Then
		EmailParameters.Insert("Recipient", New Array);
	EndIf;
	
	If TypeOfCc = Type("String") Then
		EmailParameters.Cc = CommonUseClientServer.SplitStringWithEmailAddresses(EmailParameters.Cc);
	ElsIf TypeOfCc <> Type("Array") Then
		EmailParameters.Insert("Cc", New Array);
	EndIf;
	
	If TypeOfBcc = Type("String") Then
		EmailParameters.Bcc = CommonUseClientServer.SplitStringWithEmailAddresses(EmailParameters.Bcc);
	ElsIf TypeOfBcc <> Type("Array") Then
		EmailParameters.Insert("Bcc", New Array);
	EndIf;
	
	If EmailParameters.Property("ReplyTo") And TypeOf(EmailParameters.ReplyTo) = Type("String") Then
		EmailParameters.ReplyTo = CommonUseClientServer.SplitStringWithEmailAddresses(EmailParameters.ReplyTo);
	EndIf;
	
	If EmailParameters.Property("Attachments") Then
		For Each KeyAndValue In EmailParameters.Attachments Do
			Attachment = KeyAndValue.Value;
			If ConvertAttachmentForEmailing(Attachment) Then
				EmailParameters.Attachments.Insert(KeyAndValue.Key, Attachment);
			EndIf;
		EndDo;
	EndIf;
	
	Return SendMessage(Account, EmailParameters,Connection);
	
EndFunction

// Downloads email messages. Checks whether the email account is filled correctly and
// calls the function that implements the mechanism of email downloading.
// 
// See DownloadMessages function parameters for details.
//
Function DownloadEmailMessages(Val Account,
                                   Val DownloadParameters = Undefined) Export
	
	If Not Account.UseForReceiving Then
		Raise NStr("en = 'The email account cannot be used for message receiving.'");
	EndIf;
	
	If DownloadParameters = Undefined Then
		DownloadParameters = New Structure;
	EndIf;
	
	Result = DownloadMessages(Account, DownloadParameters);
	
	Return Result;
	
EndFunction

// Retrieves the system account reference.
//
// Returns:
//  Account - CatalogRef.EmailAccounts - email account reference.<BR>
//
Function GetSystemAccount() Export
	
	Return Catalogs.EmailAccounts.SystemEmailAccount;
	
EndFunction

// Returns available email accounts.
//
// Parameters:
//  ForSending                  - Boolean - flag that shows whether only accounts that  
//                                can be used as a sender can be chosen.
//  ForReceiving                - Boolean - flag that shows whether only accounts that  
//                                can be used as a recipient can be chosen.
//  IncludingSystemEmailAccount - flag that shows whether the system email account will
//                                be included in the selection (if it is available).
//
// Returns:
//  ValueTable that contains the following columns:
//   Ref                        - CatalogRef.EmailAccounts - account reference.
//   Description                - String - account description.
//   Address                    - String - email address.
//
Function GetAvailableAccounts(Val ForSending = Undefined,
										Val ForReceiving  = Undefined,
										Val IncludingSystemEmailAccount = True) Export
	
	If Not AccessRight("Read", Metadata.Catalogs.EmailAccounts) Then
		Return New ValueTable;
	EndIf;
	
	QueryText = 
		"SELECT ALLOWED
		|	EmailAccounts.Ref AS Ref,
		|	EmailAccounts.Description AS Description,
		|	EmailAccounts.EmailAddress AS Address
		|FROM
		|	Catalog.EmailAccounts AS EmailAccounts
		|WHERE";
	
	If ForSending <> Undefined Then
		QueryText = QueryText + "
		|	EmailAccounts.UseForSending = &ForSending";
	EndIf;
	
	If ForReceiving <> Undefined Then
		If ForSending <> Undefined Then
			QueryText = QueryText + "
			| AND";
		EndIf;
		QueryText = QueryText + "
		|	EmailAccounts.UseForReceiving = &ForReceiving";
	EndIf;

	If Not IncludingSystemEmailAccount Then
		QueryText =QueryText + "
		|	And EmailAccounts.Ref <> Value(Catalog.EmailAccounts.SystemEmailAccount)";
	EndIf;
	
	Query = New Query;
	Query.Text = QueryText;
	Query.Parameters.Insert("ForSending", ForSending);
	Query.Parameters.Insert("ForReceiving", ForReceiving);
	
	Return Query.Execute().Unload();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Converts internal formats of attachments to binary data.
//
Function ConvertAttachmentForEmailing(Attachment) Export
	If TypeOf(Attachment) = Type("String") And IsTempStorageURL(Attachment) Then
		Attachment = GetFromTempStorage(Attachment);
		ConvertAttachmentForEmailing(Attachment);
		Return True;
	ElsIf TypeOf(Attachment) = Type("Picture") Then
		Attachment = Attachment.GetBinaryData();
		Return True;
	ElsIf TypeOf(Attachment) = Type("File") And Attachment.Exist() And Attachment.IsFile() Then
		Attachment = New BinaryData(Attachment.FullName);
		Return True;
	EndIf;
	Return False;
EndFunction

// Checks whether predefined system email account is available for use.
//
Function CheckSystemAccountAvailable() Export
	
	If Not AccessRight("Read", Metadata.Catalogs.EmailAccounts) Then
		Return False;
	EndIf;
	
	QueryText =
		"SELECT ALLOWED
		|	EmailAccounts.Ref AS Ref
		|FROM
		|	Catalog.EmailAccounts AS EmailAccounts
		|WHERE
		|	EmailAccounts.Ref = &Ref";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.Parameters.Insert("Ref", GetSystemAccount());
	If Query.Execute().IsEmpty() Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////

// Directly implements email message sending.
//
// Parameters:
//  Account         - CatalogRef.EmailAccounts - email account reference.
//
//  EmailParameters - Structure - Contains all required message details:
//   Recipient*      - Array of Structure with the following fields:
//                      Address      - String - email address.
//                      Presentation - String - recipient name.
//                   - String - message recipient address.
//   Cc              - Array of Structure with the following fields:
//                      Address      - String - email address (must be filled).
//                      Presentation - String - recipient name.
//                   - String - message copy recipient addresses.
//   Bcc             - Array of Structure with the following fields:
//                      Address      - String - email address (must be filled).
//                      Presentation - String - recipient name.
//                   - String - message blind copy recipient addresses.
//  Subject*         - String - message subject.
//  Body*            - String - message body (win-1251 text).
//  Importance       - InternetMailMessageImportance.
//  Attachments      - Map with the following keys and values:
//                      Key   - AttachmentDescription - String - attachment 
//                              description.
//                      Value - BinaryData - binary attachment data.
//                            - Structure with the following fields:
//                               BinaryData - binary attachment data.
//                               ID         - String - attachment ID that is used for
//                                            storing pictures that are shown in the
//                                            message body.
//
//  Additional structure key that can be used:
//   ReplyTo                 - Map - see Recipient for details.
//   Password                - String - account password.
//   BasisIDs                - String - IDs of this message basis objects.
//   ProcessTexts            - Boolean - flag that shows whether texts must be  
//                             processed when sending the message.
//   RequestDeliveryReceipt  - Boolean -  flag that shows whether the delivery receipt
//                             confirmation is required. 
//   RequestReadReceipt      - Boolean - flag that shows whether the read receipt
//                             confirmation is required.
//   TextType                - String, Enum.EmailTextTypes - determines the 
//                             passed text type. It can take the following values:
//                              HTML - EmailTextTypes.HTML - HTML formatted text.
//                              PlainText - EmailTextTypes.PlainText - plain text. 
//                              It is displayed "as is" (the default value).
//                              RichText - EmailTextTypes.RichText - rich text.
//
//  Note: Parameters marked with * are mandatory.
//
// Connection       - InternetMail - exist connection with the  email server. If it is 
// not specified, it is established in the function body.
//
// Returns:
// String - ID of the sent email message on the SMTP server.
//
// NOTE: the function can raise an exception, which must be processed.
//
Function SendMessage(Val Account,
	                       Val EmailParameters,
	                       Connection = Undefined) Export
	
	// Declaring variables before their first use as the Property 
	// method parameter.
	Var Recipient, Subject, Body, Attachments, ReplyTo, TextType, Cc, Bcc, Password;
	
	If Not EmailParameters.Property("Subject", Subject) Then
		Subject = "";
	EndIf;
	
	If Not EmailParameters.Property("Body", Body) Then
		Body = "";
	EndIf;
	
	Recipient = EmailParameters.Recipient;
	
	If TypeOf(Recipient) = Type("String") Then
		Recipient = CommonUseClientServer.SplitStringWithEmailAddresses(Recipient);
	EndIf;
	
	EmailParameters.Property("Attachments", Attachments);
	
	CurEmail = New InternetMailMessage;
	CurEmail.Subject = Subject;
	
	// Generating the recipient address	
	For Each RecipientEmailAddress In Recipient Do
		Recipient = CurEmail.To.Add(RecipientEmailAddress.Address);
		Recipient.DisplayName = RecipientEmailAddress.Presentation;
	EndDo;
	
	If EmailParameters.Property("Cc", Cc) Then
		// Generating the recipient address from the Cc field value
		For Each CcRecipientEmailAddress In Cc Do
			Recipient = CurEmail.Cc.Add(CcRecipientEmailAddress.Address);
			Recipient.DisplayName = CcRecipientEmailAddress.Presentation;
		EndDo;
	EndIf;
	
	If EmailParameters.Property("Bcc", Bcc) Then
		// Generating the recipient address from the Bcc field value
		For Each BccRecipientEmailAddress In Bcc Do
			Recipient = CurEmail.Bcc.Add(BccRecipientEmailAddress.Address);
			Recipient.DisplayName = BccRecipientEmailAddress.Presentation;
		EndDo;
	EndIf;
	
	// Generating the ReplyTo address, if necessary
	If EmailParameters.Property("ReplyTo", ReplyTo) Then
		For Each ReplyToEmailAddress In ReplyTo Do
			ReplyToEmailAddress = CurEmail.ReplyTo.Add(ReplyToEmailAddress.Address);
			ReplyToEmailAddress.DisplayName = ReplyToEmailAddress.Presentation;
		EndDo;
	EndIf;
	
	// Adding the sender name to the message
	CurEmail.SenderName         = Account.UserName;
	CurEmail.From.DisplayName = Account.UserName;
	CurEmail.From.Address     = Account.EmailAddress;
	
	// Adding attachments to the message
	If Attachments <> Undefined Then
		For Each ItemAttachment In Attachments Do
			If TypeOf(ItemAttachment.Value) = Type("Structure") Then
				NewAttachment = CurEmail.Attachments.Add(ItemAttachment.Value.BinaryData, ItemAttachment.Key);
				NewAttachment.ID = ItemAttachment.Value.ID;
			Else
				CurEmail.Attachments.Add(ItemAttachment.Value, ItemAttachment.Key);
			EndIf;
		EndDo;
	EndIf;

	// Setting basis object IDs
	If EmailParameters.Property("BasisIDs") Then
		CurEmail.SetField("References", EmailParameters.BasisIDs);
	EndIf;
	
	// Adding the text
	Text = CurEmail.Texts.Add(Body);
	If EmailParameters.Property("TextType", TextType) Then
		If TypeOf(TextType) = Type("String") Then
			If TextType = "HTML" Then
				Text.TextType = InternetMailTextType.HTML;
			ElsIf TextType = "RichText" Then
				Text.TextType = InternetMailTextType.RichText;
			Else
				Text.TextType = InternetMailTextType.PlainText;
			EndIf;
		ElsIf TypeOf(TextType) = Type("EnumRef.EmailTextTypes") Then
			If TextType = Enums.EmailTextTypes.HTML
				  Or TextType = Enums.EmailTextTypes.HTMLWithPictures Then
				Text.TextType = InternetMailTextType.HTML;
			ElsIf TextType = Enums.EmailTextTypes.RichText Then
				Text.TextType = InternetMailTextType.RichText;
			Else
				Text.TextType = InternetMailTextType.PlainText;
			EndIf;
		Else
			Text.TextType = TextType;
		EndIf;
	Else
		Text.TextType = InternetMailTextType.PlainText;
	EndIf;

	// Setting the message importance
	Importance = Undefined;
	If EmailParameters.Property("Importance", Importance) Then
		CurEmail.Importance = Importance;
	EndIf;
	
	// Setting encoding
	Encoding = Undefined;
	If EmailParameters.Property("Encoding", Encoding) Then
		CurEmail.Encoding = Encoding;
	EndIf;

	If EmailParameters.Property("ProcessTexts") And Not EmailParameters.ProcessTexts Then
		ProcessMessageText =  InternetMailTextProcessing.DontProcess;
	Else
		ProcessMessageText =  InternetMailTextProcessing.Process;
	EndIf;
	
	If EmailParameters.Property("RequestDeliveryReceipt") Then
		CurEmail.RequestDeliveryReceipt = EmailParameters.RequestDeliveryReceipt;
		CurEmail.DeliveryReceiptAddresses.Add(Account.EmailAddress);
	EndIf;
	
	If EmailParameters.Property("RequestReadReceipt") Then
		CurEmail.RequestReadReceipt = EmailParameters.RequestReadReceipt;
		CurEmail.ReadReceiptAddresses.Add(Account.EmailAddress);
	EndIf;
	
	If TypeOf(Connection) <> Type("InternetMail") Then
		EmailParameters.Property("Password", Password);
		Profile = GenerateInternetProfile(Account, Password);
	 	Connection = New InternetMail;
	 	Connection.Logon(Profile);
	EndIf;

	Connection.Send(CurEmail, ProcessMessageText);
	
	Return CurEmail.MessageID;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////

// Directly implements email message downloading from the email server for the
// specified email account.
//
// Parameters:
// Account             - CatalogRef.EmailAccounts - email account reference.
//
// DownloadParameters  - Structure with the following keys:
//  Columns            - Array - Array of String - column names that must match 
//                       InternetMailMessage object fields. 
//  TestMode           - Boolean - flag that shows whether account test mode is on. In
//                       this mode messages are selected but not downloaded. The 
//                       default value is False.

//  GetHeaders         - Boolean - flag that shows whether the return value will 
//                       contain only headers but not whole messages.
//  HeadersIDs         - Array - headers or IDs of messages to be downloaded.
//  CastMessagesToType - Boolean - flag that shows whether messages will be returned as
//                       a value table of ordinary types. The default value is True.
//
// Password            - String - POP3 access password.
//
// Returns:
// MessageSet*         - value table that contains an adapted version of the list of
//                       messages on the server.
//                       By default, the value table contains the following columns:
//                       Importance, Attachments**, PostDating, DateReceived, Title,
//                       SenderName, ID, Cc, ReplyTo, Sender, Recipients, Size, Texts,
//                       Encoding, NonASCIISymbolsEncodingMode, Partial.
//                       It is filled if the state is True.
//
// *  - In the test mode, the return value is boolean. It shows whether the connection 
//      is established successfully.
// ** - if attachments are other email messages, they are not returned but their
//      attachments (binary data) and texts as binary data are included recursively.
//
Function DownloadMessages(Val Account,
                           Val DownloadParameters = Undefined)
	
	// Is used to check whether connection to the mail box can be established
	Var TestMode;
	
	// Shows whether the return value will contain only headers but not whole messages
	Var GetHeaders;
	
	// Shows whether messages will be returned as a value table of ordinary types
	Var CastMessagesToType;
	
	// Headers or IDs of messages to be downloaded
	Var HeadersIDs;
	
	If DownloadParameters.Property("TestMode") Then
		TestMode = DownloadParameters.TestMode;
	Else
		TestMode = False;
	EndIf;
	
	If DownloadParameters.Property("GetHeaders") Then
		GetHeaders = DownloadParameters.GetHeaders;
	Else
		GetHeaders = False;
	EndIf;
	
	If DownloadParameters.Property("Password") Then
		Profile = GenerateInternetProfile(Account, DownloadParameters.Password);
	Else
		Profile = GenerateInternetProfile(Account);
	EndIf;
	
	If DownloadParameters.Property("HeadersIDs") Then
		HeadersIDs = DownloadParameters.HeadersIDs;
	Else
		HeadersIDs = New Array;
	EndIf;
	
	MessageSetToDelete = New Array;
	
	Connection = New InternetMail;
	
	Connection.Logon(Profile);
	
	If TestMode Or GetHeaders Then
		
		MessageSet = Connection.GetHeaders();
		
	Else
		
		If Account.KeepMessageCopiesAtServer Then
			
			If HeadersIDs.Count() =  0
			   And Account.KeepMessageAtServerPeriod > 0 Then
				
				Headers = Connection.GetHeaders();
				
				MessageSetToDelete = New Array;
				
				For Each ItemHeader In Headers Do
					CurrentDate = CurrentSessionDate();
					DateDifference = (CurrentDate - ItemHeader.PostDating) / (3600*24);
					If DateDifference >= Account.KeepMessageAtServerPeriod Then
						MessageSetToDelete.Add(ItemHeader);
					EndIf;
				EndDo;
				
			EndIf;
			
			AutomaticallyDeleteMessagesOnChoiceFromServer = False;
			
		Else
			
			AutomaticallyDeleteMessagesOnChoiceFromServer = True;
			
		EndIf;
		
		MessageSet = Connection.Get(AutomaticallyDeleteMessagesOnChoiceFromServer, HeadersIDs);
		
		If MessageSetToDelete.Count() > 0 Then
			Connection.DeleteMessages(MessageSetToDelete);
		EndIf;
		
	EndIf;
	
	Connection.Logoff();
	
	If TestMode Then
		Return True;
	EndIf;
	
	If DownloadParameters.Property("CastMessagesToType") Then
		CastMessagesToType = DownloadParameters.CastMessagesToType;
	Else
		CastMessagesToType = True;
	EndIf;
	
	If CastMessagesToType Then
		If DownloadParameters.Property("Columns") Then
			MessageSet = GetAdaptedMessageSet(MessageSet, DownloadParameters.Columns);
		Else
			MessageSet = GetAdaptedMessageSet(MessageSet);
		EndIf;
	EndIf;
	
	Return MessageSet;
	
EndFunction

// Established a connection to the email server.
//
// Parameters:
// Profile - InternetMailProfile - email account profile for establishing a connection.
//
// Returns:
// InternetMail
//
Function ConnectToMailServer(Profile) Export
	
	Connection = New InternetMail;
	Connection.Logon(Profile);
	
	Return Connection;
	
EndFunction

// Generates an email connection profile by account reference.
//
// Parameters:
// Account - CatalogRef.EmailAccount - profile details.
//
// Returns:
// InternetMailProfile.
//
Function GenerateInternetProfile(Val Account,
                                    Val Password = Undefined,
                                    Val GenerateSMTPProfile = True,
                                    Val GeneratePOP3Profile = True) Export
	
	Profile = New InternetMailProfile;
	
	Profile.User = Account.User;
	
	Profile.Timeout = Account.Timeout;
	
	If ValueIsFilled(Password) Then
		Profile.Password = Password;
	Else
		Profile.Password = Account.Password;
	EndIf;
	
	If GenerateSMTPProfile Then
		Profile.SMTPServerAddress = Account.OutgoingMailServerSMTP;
		Profile.SMTPPort         = Account.SMTPPort;
		
		If Account.SMTPAuthentication = Enums.SMTPAuthenticationVariants.SimilarlyPOP3 Then
			Profile.SMTPAuthentication = SMTPAuthenticationMode.Default;
			Profile.SMTPUser           = Account.User;
			Profile.SMTPPassword       = Profile.Password;
		ElsIf Account.SMTPAuthentication = Enums.SMTPAuthenticationVariants.SetWithParameters Then
			
			If Account.SMTPAuthenticationMode = Enums.SMTPAuthenticationModes.CramMD5 Then
				Profile.SMTPAuthentication = SMTPAuthenticationMode.CramMD5;
			ElsIf Account.SMTPAuthenticationMode = Enums.SMTPAuthenticationModes.Login Then
				Profile.SMTPAuthentication = SMTPAuthenticationMode.Login;
			ElsIf Account.SMTPAuthenticationMode = Enums.SMTPAuthenticationModes.Plain Then
				Profile.SMTPAuthentication = SMTPAuthenticationMode.Plain;
			ElsIf Account.SMTPAuthenticationMode = Enums.SMTPAuthenticationModes.None Then
				Profile.SMTPAuthentication = SMTPAuthenticationMode.None;
			Else
				Profile.SMTPAuthentication = SMTPAuthenticationMode.Default;
			EndIf;
			
			Profile.SMTPUser     = Account.SMTPUser;
			Profile.SMTPPassword = Account.SMTPPassword;
			
		ElsIf Account.SMTPAuthentication = Enums.SMTPAuthenticationVariants.POP3BeforeSMTP Then
			Profile.SMTPAuthentication = SMTPAuthenticationMode.None;
			Profile.POP3BeforeSMTP = True;
		Else
			Profile.SMTPAuthentication = SMTPAuthenticationMode.None;
		EndIf;
	EndIf;
	
	If GeneratePOP3Profile Then
		Profile.POP3ServerAddress = Account.IncomingMailServerPOP3;
		Profile.POP3Port          = Account.POP3Port;
		
		If Account.POP3AuthenticationMode = Enums.POP3AuthenticationModes.APOP Then
			Profile.POP3Authentication = POP3AuthenticationMode.APOP;
		ElsIf Account.POP3AuthenticationMode = Enums.POP3AuthenticationModes.CramMD5 Then
			Profile.POP3Authentication = POP3AuthenticationMode.CramMD5;
		Else
			Profile.POP3Authentication = POP3AuthenticationMode.General;
		EndIf;
	EndIf;
	
	// Passing Use SSL flags to the profile settings
	Profile.POP3UseSSL = Account.POP3UseSSL;
	Profile.SMTPUseSSL = Account.SMTPUseSSL;
	// SSL
	
	Return Profile;
	
EndFunction

// Writes an adapted message set by columns.
// Column values that are not supported on the client are converted to String.
//
Function GetAdaptedMessageSet(Val MessageSet, Val Columns = Undefined)
	
	Result = CreateAdaptedEmailMessageDetails(Columns);
	
	For Each EmailMessage In MessageSet Do
		NewRow = Result.Add();
		
		For Each ColumnDescription In Columns Do
			
			Value = EmailMessage[ColumnDescription];
			
			If TypeOf(Value) = Type("String") Then
				Value = CommonUseClientServer.DeleteDisallowedXMLCharacters(Value);
			EndIf;
			
			If TypeOf(Value) = Type("InternetMailAddresses") Then
				value_total = "";
				For Each NextAddress In Value Do
					value_tmp =  NextAddress.Address;
					If ValueIsFilled(NextAddress.DisplayName) Then
						value_tmp = NextAddress.DisplayName + " <" + value_tmp + ">";
					EndIf;
					If ValueIsFilled(value_tmp) Then
						value_tmp = value_tmp + "; "
					EndIf;
					value_total = value_total + value_tmp;
				EndDo;
				
				If ValueIsFilled(value_total) Then
					value_total = Mid(value_total, 1, StrLen(value_total)-2)
				EndIf;
				
				Value = value_total;
			EndIf;
			
			If TypeOf(Value) = Type("InternetMailAddress") Then
				value_tmp =  Value.Address;
				If ValueIsFilled(Value.DisplayName) Then
					value_tmp = Value.DisplayName + " <" + value_tmp + ">";
				EndIf;
				Value = value_tmp;
			EndIf;
			
			If TypeOf(Value) = Type("InternetMailMessageImportance") Then
				Value = String(Value);
			EndIf;
			
			If TypeOf(Value) = Type("InternetMailMessageNonASCIISymbolsEncodingMode") Then
				Value = String(Value);
			EndIf;
			
			If TypeOf(Value) = Type("InternetMailAttachments") Then
				value_map = New Map;
			
				For Each NextAttachment In Value Do
					AttachmentName = NextAttachment.Name;
					If TypeOf(NextAttachment.Data) = Type("BinaryData") Then
						value_map.Insert(AttachmentName, NextAttachment.Data);
					Else
						FillNestedAttachments(value_map, AttachmentName, NextAttachment.Data);
					EndIf;
				EndDo;
				
				Value = value_map;
			EndIf;
			
			If TypeOf(Value) = Type("InternetMailTexts") Then
				value_arr = New Array;
				For Each NextText In Value Do
					value_map = New Map;
					
					value_map.Insert("Data", NextText.Data);
					value_map.Insert("Encoding", NextText.Encoding);
					value_map.Insert("Text", CommonUseClientServer.DeleteDisallowedXMLCharacters(NextText.Text));
					value_map.Insert("TextType", String(NextText.TextType));
					
					value_arr.Add(value_map);
				EndDo;
				Value = value_arr;
			EndIf;
			
			NewRow[ColumnDescription] = Value;
		EndDo;
	EndDo;
	
	Return Result;
	
EndFunction

Procedure FillNestedAttachments(Attachments, AttachmentName, InternetMailMessage)
	
	For Each InternetMailAttachment In InternetMailMessage.Attachments Do
		AttachmentName = InternetMailAttachment.Name;
		If TypeOf(InternetMailAttachment.Data) = Type("BinaryData") Then
			Attachments.Insert(AttachmentName, InternetMailAttachment.Data);
		Else
			FillNestedAttachments(Attachments, AttachmentName, InternetMailAttachment.Data);
		EndIf;
	EndDo;
	
	Index = 0;
	
	For Each InternetMailTexts In InternetMailMessage.Texts Do
		
		If InternetMailTexts.TextType = InternetMailTextType.HTML Then
			Extension = "html";
		ElsIf InternetMailTexts.TextType = InternetMailTextType.PlainText Then
			Extension = "txt";
		Else
			Extension = "rtf";
		EndIf;
		AttachmentsTextName = "";
		While AttachmentsTextName = "" Or Attachments.Get(AttachmentsTextName) <> Undefined Do
			Index = Index + 1;
			AttachmentsTextName = StringFunctionsClientServer.SubstituteParametersInString("%1 - (%2).%3", AttachmentName, Index, Extension);
		EndDo;
		Attachments.Insert(AttachmentsTextName, InternetMailTexts.Data);
	EndDo;
	
EndProcedure

// Creates a table where email messages will be stored.
// 
// Parameters:
// Columns    - String - comma-separated list of message fields to be stored to the 
//              table. During the procedure execution this parameter value is converted 
//              to Array.
// Return:
// ValueTable - empty value table with the specified columns.
//
Function CreateAdaptedEmailMessageDetails(Columns = Undefined)
	
	If Columns <> Undefined
	   And TypeOf(Columns) = Type("String") Then
		Columns = StringFunctionsClientServer.SplitStringIntoSubstringArray(Columns, ",");
		For Index = 0 to Columns.Count()-1 Do
			Columns[Index] = TrimAll(Columns[Index]);
		EndDo;
	EndIf;
	
	DefaultColumnArray = New Array;
	DefaultColumnArray.Add("Importance");
	DefaultColumnArray.Add("Attachments");
	DefaultColumnArray.Add("PostDating");
	DefaultColumnArray.Add("DateReceived");
	DefaultColumnArray.Add("Header");
	DefaultColumnArray.Add("SenderName");
	DefaultColumnArray.Add("ID");
	DefaultColumnArray.Add("Cc");
	DefaultColumnArray.Add("ReplyTo");
	DefaultColumnArray.Add("Sender");
	DefaultColumnArray.Add("Recipients");
	DefaultColumnArray.Add("Size");
	DefaultColumnArray.Add("Subject");
	DefaultColumnArray.Add("Texts");
	DefaultColumnArray.Add("Encoding");
	DefaultColumnArray.Add("NonASCIISymbolsEncodingMode");
	DefaultColumnArray.Add("Partial");
	
	If Columns = Undefined Then
		Columns = DefaultColumnArray;
	EndIf;
	
	Result = New ValueTable;
	
	For Each ColumnDescription In Columns Do
		Result.Columns.Add(ColumnDescription);
	EndDo;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for the infobase initial filling and updating.
//

// Adds update handlers required by this subsystem to the Handlers list. 
// 
// Parameters:
// Handlers - ValueTable - see the InfoBaseUpdate.NewUpdateHandlerTable function for details. 
// 
Procedure RegisterUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.0.0";
	Handler.Procedure = "Email.FillSystemAccount";
	
EndProcedure

// Fills system email account with default values.
//
Procedure FillSystemAccount() Export
	
	Account = GetSystemAccount().GetObject();
	Account.Lock();
	Account.FillObjectWithDefaultValues();
	Account.Write();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
//
// Procedures and functions for verifying accounts.
//

// Checks whether the account password is specified.
//
Function PasswordSpecified(Account) Export
	
	Return ValueIsFilled(Account.Password);
	
EndFunction

// The internal function, that is used verifying email accounts.
//
Procedure CheckSendReceiveEmailPossibility(Account, PasswordParameter, ErrorMessage, AdditionalMessage) Export
	
	ErrorMessage = "";
	AdditionalMessage = "";
	
	If Account.UseForSending Then
		Try
			CanSendTestEmail(Account, PasswordParameter);
		Except
			ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(
									NStr("en = 'Error sending the message: %1'"),
									BriefErrorDescription(ErrorInfo()) );
		EndTry;
		If Not Account.UseForReceiving Then
			AdditionalMessage = Chars.LF + NStr("en = '(Email message sending is verified.)'");
		EndIf;
	EndIf;
	
	If Account.UseForReceiving Then
		Try
			CheckIncomingMailServerConnection(Account, PasswordParameter);
		Except
			If ValueIsFilled(ErrorMessage) Then
				ErrorMessage = ErrorMessage + Chars.LF;
			EndIf;
			
			ErrorMessage = ErrorMessage
								+ StringFunctionsClientServer.SubstituteParametersInString(
										NStr("en = 'Error accessing the incoming message server: %1'"),
										BriefErrorDescription(ErrorInfo()) );
		EndTry;
		If Not Account.UseForSending Then
			AdditionalMessage = Chars.LF + NStr("en = '(Email message receiving is verified.)'");
		EndIf;
	EndIf;
	
EndProcedure

// Checks whether the message can be send via the specified account.
//
// Parameters:
// Account - CatalogRef.EmailAccounts- account to be checked.
//
// Returns:
// Structure with the following keys: 
// State        - Boolean - flag that shows whether the SMTP server connection is
//                established successfully.
// ErrorMessage - String - contains the error message if State is False.
//
Procedure CanSendTestEmail(Val Account,
														Val Password = Undefined)
	
	EmailParameters = New Structure;
	
	EmailParameters.Insert("Subject", NStr("en = '1C:Enterprise test message.'"));
	EmailParameters.Insert("Body", NStr("en = 'This message was sent by the 1C:Enterprise email subsystem.'"));
	EmailParameters.Insert("Recipient", Account.EmailAddress);
	If Password <> Undefined Then
		EmailParameters.Insert("Password", Password);
	EndIf;
	
	Try
		SendEmailMessage(Account, EmailParameters);
	Except
		WriteLogEvent(EventLogMessageText(), EventLogLevel.Error,,
			Account, DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

// Checks whether the message can be received via the specified account.
//
// Parameters:
// Account - CatalogRef.EmailAccounts- account to be checked.
//
// Returns:
// Structure with the following keys: 
// State        - Boolean - flag that shows whether the POP3 server connection is
//                esteblished successfully.
// ErrorMessage - String - contains the error message if State is False.
//
Procedure CheckIncomingMailServerConnection(Val Account,
														Val Password = Undefined)
	
	DownloadParameters = New Structure("TestMode", True);
	
	If Password <> Undefined Then
		DownloadParameters.Insert("Password", Password);
	EndIf;
	
	Try
		DownloadEmailMessages(Account, DownloadParameters);
	Except
		WriteLogEvent(EventLogMessageText(), EventLogLevel.Error,,
			Account, DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

Function EventLogMessageText()
	Return NStr("en = 'Verifying email account'");	
EndFunction
