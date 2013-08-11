//------------------------------------------------------------------------------
// PASSED TO THE FORM PARAMETERS
//
// Account                 - ValueList with the following fields:
//                           Presentation - account description.
//                           Value - account reference.
//                         - CatalogRef.EmailAccounts.
//                         - Undefined - all accounts that are available for the
//                           current user will be included in the choice list.				
//
// Recipient               - ValueList with the following fields:
//                           Presentation - recipient name.
//                           Value	- email address.
//                         - String - email address list in the correct email address
//                           format*.
//
// Attachments             - ValueList with the following fields:
//                           Presentation - String - attachment description.
//                           Value - BinaryData - binary attachment data.
//                         - String - file address in the temporary storage.
//                         - String - path to the file on the client.
//
// DeleteFilesAfterSending - Boolean - flag that shows whether temporary files must be
//                           deleted after sending the message.
//
// Subject                 - String - email message subject.
// Body                    - String - email message body.
// ReplyTo                 - String - address that will be suggested to the recipient
//                           as a reply address.
//
// 
//
// *The correct format of email addresses:
// Z = ([User Name] [<]user@emailserver[>][;]), String = Z[Z].
//
// RETURN VALUE
//
// Undefined or
// Boolean - True if message was sent successfully, False if message sending failed.
//
//------------------------------------------------------------------------------
// HOW THE FORM WORKS
//
//   If the passed account list contains more than one item, the email account to be
// a sender is chosen from the list on the form. An account that is not in the passed
// list cannot be chosen.
//
//   If the Account value is Undefined, all accounts that are available for the user 
// are included in the choice list and the choice button of the Account form item 
// became enabled.
//
//    If attachment files are not on the application server, not a binary data but a
// reference to data into the temporary storage must be passed.
//
//------------------------------------------------------------------------------

////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

// Fills form fields by passed parameters. 
//
// The following parameters can be passed to the form:
// Account     - CatalogRef.EmailAccounts, ValueList - reference to the account that 
//               will be used for sending messages or a value list of accounts to 
//               choose one of them. 
// Attachments - ValueList with the following fields:
//               Presentation - String - attachment description.
//               Value - BinaryData - binary attachment data.
// Subject     - String - email message subject.
// Body        - String - email message body.
// Recipient   - Map where:
//               Key - String - recipient name.
//               Value - String - email address in the following format: addr@server
//             - String - email message recipients.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	EmailSubject = Parameters.Subject;
	EmailBody = Parameters.Body;
	ReplyTo = Parameters.ReplyTo;
	
	EmailAttachments = Parameters.Attachments;
	
	// Marking attachments that are paths to files on the client computer
	For Each AttachmentDetails In EmailAttachments Do
		If TypeOf(AttachmentDetails.Value) = Type("String") Then
			If IsTempStorageURL(AttachmentDetails.Value) Then
				AttachmentDetails.Value = GetFromTempStorage(AttachmentDetails.Value);
			Else
				AttachmentDetails.Check = True; // This is a path to the file on the client computer
			EndIf;
		EndIf;
	EndDo;
	
	// Processing form parameters of a composite type:
	// Account, Recipient.
	
	If Not ValueIsFilled(Parameters.Account) Then
		// No account was passed, the first available account will be chosen.
		AvailableEmailAccounts = Email.GetAvailableAccounts(True);
		If AvailableEmailAccounts.Count() = 0 Then
			MessageText = NStr("en = 'No available email accounts are found, please contact your infobase administrator.'");
			CommonUseClientServer.MessageToUser(MessageText,,,,Cancel);
			Return;
		EndIf;
		Account = AvailableEmailAccounts[0].Ref;
		PasswordSpecified = ValueIsFilled(Account.Password);
		Items.Account.ChoiceButton = True;
	ElsIf TypeOf(Parameters.Account) = Type("CatalogRef.EmailAccounts") Then
		Account = Parameters.Account;
		PasswordSpecified = ValueIsFilled(Account.Password);
		AccountSpecified = True;
	ElsIf TypeOf(Parameters.Account) = Type("ValueList") Then
		EmailAccountList = Parameters.Account;
		
		If EmailAccountList.Count() = 0 Then
			MessageText = NStr("en = 'Email accounts for sending the message are not specified, please contact your infobase administrator.'");
			CommonUseClientServer.MessageToUser(MessageText,,,, Cancel);
			Return;
		EndIf;
		
		PasswordIsSetMac = New Array;
		
		For Each ItemAccount In EmailAccountList Do
			Items.Account.ChoiceList.Add(
										ItemAccount.Value,
										ItemAccount.Presentation);
			If ItemAccount.Value.UseForReceiving Then
				ReplyToByEmailAccounts.Add(ItemAccount.Value,
														GetEmailAddressByAccount(ItemAccount.Value));
			EndIf;
			If ValueIsFilled(ItemAccount.Value.Password) Then
				PasswordIsSetMac.Add(ItemAccount.Value);
			EndIf;
		EndDo;
		PasswordSpecified = New FixedArray(PasswordIsSetMac);
		Items.Account.ChoiceList.SortByPresentation();
		Account = EmailAccountList[0].Value;
		
		// Enabling choice list button if the account list is passed
		Items.Account.ChoiceListButton = True;
		AccountSpecified = True;
		
		If Items.Account.ChoiceList.Count() <= 1 Then
			Items.Account.Visible = False;
		EndIf;
	EndIf;
	
	If	TypeOf(Parameters.Recipient) = Type("ValueList") Then
		RecipientEmailAddress = "";
		For Each ItemEmail In Parameters.Recipient Do
			If ValueIsFilled(ItemEmail.Presentation) Then
				RecipientEmailAddress = RecipientEmailAddress
										+ ItemEmail.Presentation
										+ " <"
										+ ItemEmail.Value
										+ ">; "
			Else
				RecipientEmailAddress = RecipientEmailAddress 
										+ ItemEmail.Value
										+ "; ";
			EndIf;
		EndDo;
	ElsIf TypeOf(Parameters.Recipient) = Type("String") Then
		RecipientEmailAddress = Parameters.Recipient;
	EndIf;
	
	// Retrieving a list of email addresses that the user used before
	ReplyToList = CommonUse.CommonSettingsStorageLoad(
		"EditNewEmailMessage", 
		"ReplyToList"
	);
	
	If ReplyToList <> Undefined And ReplyToList.Count() > 0 Then
		For Each ItemReplyTo In ReplyToList Do
			Items.ReplyTo.ChoiceList.Add(ItemReplyTo.Value, ItemReplyTo.Presentation);
		EndDo;
		Items.ReplyTo.ChoiceListButton = True;
	EndIf;
	
	If ValueIsFilled(ReplyTo) Then
		AutomaticReplyAddressSubstitution = False;
	Else
		If Account.UseForReceiving Then
			// Setting the default email address
			If ValueIsFilled(Account.UserName) Then
				ReplyTo = Account.UserName + " <" + Account.EmailAddress + ">";
			Else
				ReplyTo = Account.EmailAddress;
			EndIf;
		EndIf;
		
		AutomaticReplyAddressSubstitution = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	RefreshAttachmentPresentation();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure AccountStartChoice(Item, ChoiceData, StandardProcessing)
	
	If AccountSpecified Then
		// If the account was passed as a parameter, 
		// no other account can be chosen.
		StandardProcessing = False;
	EndIf;
	
EndProcedure


// Substitutes the ReplyTo email address if the AutomaticReplyAddressSubstitution flag is True.
//
&AtClient
Procedure AccountChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If AutomaticReplyAddressSubstitution Then
		If ReplyToByEmailAccounts.FindByValue(SelectedValue) <> Undefined Then
			ReplyTo = ReplyToByEmailAccounts.FindByValue(SelectedValue).Presentation;
		Else
			ReplyTo = GetEmailAddressByAccount(SelectedValue);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ReplyToTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	If AutomaticReplyAddressSubstitution Then
		If Not ValueIsFilled(ReplyTo)
		 Or Not ValueIsFilled(Text) Then
			AutomaticReplyAddressSubstitution = False;
		Else
			AddressMap1 = CommonUseClientServer.SplitStringWithEmailAddresses(ReplyTo);
			Try
				AddressMap2 = CommonUseClientServer.SplitStringWithEmailAddresses(Text);
			Except
				ErrorMessage = BriefErrorDescription(ErrorInfo());
				CommonUseClientServer.MessageToUser(ErrorMessage, , "ReplyTo");
				StandardProcessing = False;
				Return;
			EndTry;
				
			If Not EmailAddressesEqual(AddressMap1, AddressMap2) Then
				AutomaticReplyAddressSubstitution = False;
			EndIf;
		EndIf;
	EndIf;
	
	ReplyTo = GetNormalizedEmailInFormat(Text);
	
EndProcedure

// Clears the AutomaticReplyAddressSubstitution flag. 
//
&AtClient
Procedure ReplyToChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	AutomaticReplyAddressSubstitution = False;
	
EndProcedure

&AtClient
Procedure ReplyToClearing(Item, StandardProcessing)

	StandardProcessing = False;
	UpdateReplyToInStoredList(ReplyTo, False);
	
	For Each ItemReplyTo In Items.ReplyTo.ChoiceList Do
		If ItemReplyTo.Value = ReplyTo
		   And ItemReplyTo.Presentation = ReplyTo Then
			Items.ReplyTo.ChoiceList.Delete(ItemReplyTo);
		EndIf;
	EndDo;
	
	ReplyTo = "";
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENT HANDLERS OF Attachments TABLE 

// Deletes the attachment from the list and calls the attachment presentation table update function.
//
&AtClient
Procedure AttachmentsBeforeDelete(Item, Cancel)
	
	AttachmentDescription = Item.CurrentData[Item.CurrentItem.Name];
	
	For Each ItemAttachment In EmailAttachments Do
		If ItemAttachment.Presentation = AttachmentDescription Then
			EmailAttachments.Delete(ItemAttachment);
		EndIf;
	EndDo;
	
	RefreshAttachmentPresentation();
	
EndProcedure

&AtClient
Procedure AttachmentsBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	AddingFileToAttachments();
	
EndProcedure

&AtClient
Procedure AttachmentsChoice(Item, SelectedRow, Field, StandardProcessing)
	
	OpenAttachment();
	
EndProcedure

&AtClient
Procedure AttachmentsDragCheck(Item, DragParameters, StandardProcessing, Row, Field)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure AttachmentsDrag(Item, DragParameters, StandardProcessing, Row, Field)
	
	StandardProcessing = False;
	
	If TypeOf(DragParameters.Value) = Type("File") Then
		TempStorageAddress = "";
		If PutFile(TempStorageAddress, DragParameters.Value.FullName, , False) Then
			Files = New Array;
			PassedFile = New TransferableFileDescription(DragParameters.Value.Name, TempStorageAddress);
			Files.Add(PassedFile);
			AddFilesToList(Files); 
			RefreshAttachmentPresentation();
		EndIf;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure OpenFile(Command)
	OpenAttachment();
EndProcedure

&AtClient
Procedure SendEmailExecute()
	
	ClearMessages();
	
	Try
		NormalizedPostalAddress = CommonUseClientServer.SplitStringWithEmailAddresses(RecipientEmailAddress);
	Except
		CommonUseClientServer.MessageToUser(
				BriefErrorDescription(ErrorInfo()), ,
				RecipientEmailAddress);
		Return;
	EndTry;
	
	If ValueIsFilled(ReplyTo) Then
		Try
			NormalizedReplyTo = CommonUseClientServer.SplitStringWithEmailAddresses(ReplyTo);
		Except
			CommonUseClientServer.MessageToUser(
					BriefErrorDescription(ErrorInfo()), ,
					"ReplyTo");
			Return;
		EndTry;
	EndIf;
	
	Password = Undefined;
	
	If ((TypeOf(PasswordSpecified) = Type("Boolean") And Not PasswordSpecified)
	 Or  (TypeOf(PasswordSpecified) = Type("FixedArray") And PasswordSpecified.Find(Account) = Undefined)) Then
		AccountParameter = New Structure("Account", Account);
		Password = OpenFormModal("CommonForm.AccountPasswordConfirmation",
										 AccountParameter);
		If TypeOf(Password) <> Type("String") Then
			Return;
		EndIf;
	EndIf;
	
	EmailParameters = GenerateEmailParameters(NormalizedPostalAddress, Password);
	
	If EmailParameters = Undefined Then
		CommonUseClientServer.MessageToUser(NStr("en = 'Error generating email message parameters.'"));
		Return;
	EndIf;
	
	Try
		Email.SendEmailMessage(Account, EmailParameters);
	Except
		CommonUseClientServer.MessageToUser(BriefErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
	SaveReplyTo(ReplyTo);
	DoMessageBox(NStr("en = 'The message was sent successfully.'"));
	
	SetSentMessageState();
	
EndProcedure

&AtClient
Procedure AttachFileExecute()
	
	AddingFileToAttachments();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// FORM AND FORM ITEM EVENT HANDLER SECTION
//

&AtServerNoContext
Function GetEmailAddressByAccount(Val Account)
	
	Return TrimAll(Account.UserName)
			+ ? (IsBlankString(TrimAll(Account.UserName)),
					Account.EmailAddress,
					" <" + Account.EmailAddress + ">");
	
EndFunction

&AtClient
Procedure SetSentMessageState()
	
	Title = NStr("en = 'Message sent'");
	Items.SendEmail.Enabled = False;
	Items.Cancel.Title = NStr("en = 'Close'");;
	Items.RecipientEmail.ReadOnly = True;
	Items.EmailSubject.ReadOnly = True;
	Items.EmailBody.ReadOnly = True;
	Items.Attachments.ReadOnly = True;
	If Items.Find("Account") <> Undefined Then
		Items.Account.ReadOnly = True;
	EndIf;
	Items.ReplyTo.ReadOnly = True;
	Items.AttachFile.Enabled = False;
	
EndProcedure

&AtClient
Procedure OpenAttachment()
	
	If Items.Attachments.CurrentData <> Undefined Then
		AttachmentDescription = Items.Attachments.CurrentData[Items.Attachments.CurrentItem.Name];
		
		For Each AttachmentListItem In EmailAttachments Do
			If AttachmentListItem.Presentation = AttachmentDescription Then
				If TypeOf(AttachmentListItem.Value) = Type("BinaryData") Then
#If WebClient Then
					AddressInTempStorage = PutToTempStorage(AttachmentListItem.Value);
					GetFile(AddressInTempStorage, , True)
#Else
					File = New File(AttachmentListItem.Presentation);
					If File.Extension = "mxl" Then
						SpreadsheetDocument = GetSpreadsheetDocumentByBinaryData(AttachmentListItem.Value);
						SpreadsheetDocument.ReadOnly = True;
						SpreadsheetDocument.Show(AttachmentListItem.Presentation);
					Else
						FileNameForOpening = GetTempFileName(File.Extension);
						AttachmentListItem.Value.Write(FileNameForOpening);
						RunApp(FileNameForOpening);
					EndIf;
#EndIf
				Else
#If Not WebClient Then
					If Right(TrimAll(AttachmentListItem.Value), 4) = ".mxl" Then
						SpreadsheetDocument = GetSpreadsheetDocumentByBinaryData(New BinaryData(AttachmentListItem.Value));
						SpreadsheetDocument.ReadOnly = True;
						SpreadsheetDocument.Show(AttachmentListItem.Presentation, AttachmentListItem.Value);
					Else
#EndIf
						RunApp(AttachmentListItem.Value);
#If Not WebClient Then
					EndIf;
#EndIf
				EndIf;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetSpreadsheetDocumentByBinaryData(BinaryData)
	
	FileName = GetTempFileName("mxl");
	BinaryData.Write(FileName);
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.Read(FileName);
	
	Return SpreadsheetDocument;
	
EndFunction

&AtClient
Procedure AddingFileToAttachments()
	
	Var PlacedFiles;
	
	If AttachFileSystemExtension() Then
		PlacedFiles = New Array;
		If PutFiles(, PlacedFiles, "", True, ) Then
			AddFilesToList(PlacedFiles);
			RefreshAttachmentPresentation();
		EndIf;
	Else
		DoMessageBox(NStr("en = 'The file cannot be added because the file system extension is not installed at your web client.'"));
	EndIf;
	
EndProcedure

&AtServer
Procedure AddFilesToList(PlacedFiles)
	
	For Each FileDetails In PlacedFiles Do
		File = New File(FileDetails.Name);
		EmailAttachments.Add(GetFromTempStorage(FileDetails.Location), File.Name);
		DeleteFromTempStorage(FileDetails.Location);
	EndDo;
	
EndProcedure

&AtClient
Procedure RefreshAttachmentPresentation()
	
	AttachmentPresentation.Clear();
	
	Index = 0;
	
	For Each ItemAttachment In EmailAttachments Do
		If Index = 0 Then
			PresentationRow = AttachmentPresentation.Add();
		EndIf;
		
		PresentationRow["Attachment" + String(Index + 1)] = ItemAttachment.Presentation;
		
		Index = Index + 1;
		If Index = 2 Then
			Index = 0;
		EndIf;
	EndDo;
	
EndProcedure

// Checks whether the email message can be sent and, if it is, generates send parameters.
//
&AtClient
Function GenerateEmailParameters(Val NormalizedPostalAddress,
                                    Val Password = Undefined)
	
	EmailParameters = New Structure;
	
	If ValueIsFilled(Password) Then
		EmailParameters.Insert("Password", Password);
	EndIf;
	
	If ValueIsFilled(NormalizedPostalAddress) Then
		EmailParameters.Insert("Recipient", NormalizedPostalAddress);
	EndIf;
	
	If ValueIsFilled(ReplyTo) Then
		EmailParameters.Insert("ReplyTo", ReplyTo);
	EndIf;
	
	If ValueIsFilled(EmailSubject) Then
		EmailParameters.Insert("Subject", EmailSubject);
	EndIf;
	
	If ValueIsFilled(EmailBody) Then
		EmailParameters.Insert("Body", EmailBody);
	EndIf;
	
	If EmailAttachments.Count() > 0 Then
		Attachments = New Map;
		For Each ItemAttachment In EmailAttachments Do
			If ItemAttachment.Check Then
				BinaryData = New BinaryData(ItemAttachment.Value);
				Attachments.Insert(ItemAttachment.Presentation, BinaryData);
			Else
				Attachments.Insert(ItemAttachment.Presentation, ItemAttachment.Value);
			EndIf;
		EndDo;
		EmailParameters.Insert("Attachments", Attachments);
	EndIf;
	
	Return EmailParameters;
	
EndFunction

// Adds the ReplyTo address to the list of values to be saved.
//
&AtServerNoContext
Function SaveReplyTo(Val ReplyTo)
	
	UpdateReplyToInStoredList(ReplyTo);
	
EndFunction

// Updates the ReplyTo address in the list of values to be saved.
//
&AtServerNoContext
Function UpdateReplyToInStoredList(Val ReplyTo, Val AddAddressToList = True)
	
	// Retrieving a list of email addresses that the user used before
	ReplyToList = CommonUse.CommonSettingsStorageLoad(
		"EditNewEmailMessage",
		"ReplyToList"
	);
	
	If ReplyToList = Undefined Then
		ReplyToList = New ValueList();
	EndIf;
	
	For Each ItemReplyTo In ReplyToList Do
		If ItemReplyTo.Value = ReplyTo
		   And ItemReplyTo.Presentation = ReplyTo Then
			ReplyToList.Delete(ItemReplyTo);
		EndIf;
	EndDo;
	
	If AddAddressToList
	   And ValueIsFilled(ReplyTo) Then
		ReplyToList.Insert(0, ReplyTo, ReplyTo);
	EndIf;
	
	CommonUse.CommonSettingsStorageSave(
		"EditNewEmailMessage",
		"ReplyToList",
		ReplyToList
	);
	
EndFunction

// Compares two email addresses.
//
// Parameters:
// AddressMap1 - string - first email address.
// AddressMap2 - string - second email address.
//
// Returns:
// Boolean - True if the addresses are equal, otherwise is False.
//
&AtClient
Function EmailAddressesEqual(AddressMap1, AddressMap2)
	
	If AddressMap1.Count() <> 1
	 Or AddressMap2.Count() <> 1 Then
		Return False;
	EndIf;
	
	If AddressMap1[0].Presentation = AddressMap2[0].Presentation
	And AddressMap1[0].Address     = AddressMap2[0].Address Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

&AtClient
Function GetNormalizedEmailInFormat(Text)
	
	EmailAddress = "";
	
	AddressArray = CommonUseClientServer.SplitStringWithEmailAddresses(Text);
	
	For Each ItemAddress In AddressArray Do
		If ValueIsFilled(ItemAddress.Presentation) Then
			EmailAddress = EmailAddress + ItemAddress.Presentation
							+ ? (IsBlankString(TrimAll(ItemAddress.Address)), "", " <" + ItemAddress.Address + ">");
		Else
			EmailAddress = EmailAddress + ItemAddress.Address + "; ";
		EndIf;
	EndDo;
		
	Return EmailAddress;
	
EndFunction
