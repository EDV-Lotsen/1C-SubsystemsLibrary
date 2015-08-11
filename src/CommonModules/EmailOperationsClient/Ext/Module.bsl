////////////////////////////////////////////////////////////////////////////////
// Email operations subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// The interface client function that supports simplified call of the new message edit form.
//
// Parameters:
// Sender*                 - ValueList, CatalogRef.EmailAccounts - email account 
//                           (account list) on behalf of which the email message can be
//                           send. If the parameter type is a value list, Value is 
//                           an email account reference and Presentation is an email 
//                           account description.
// Recipient               - ValueList - 
//                           Value fields contain email addresses. 
//                           Presentation fields contain email account descriptions.
//                         - String - email address list in the correct email address
//                           format. 
// Subject                 - String - message subject.
// Text                    - String - message body.
// FileList                - ValueList - where:
//                           Presentation - string - attachment description.
//                           Value - BinaryData - binary attachment data.
//                                 - String - file address in the temporary store,
//                                 - String - path to the file on the client.
// DeleteFilesAfterSending - Boolean - flag that shows whether temporary files must be
//                           deleted after sending the message.
// SaveEmailMessage        - Boolean - flag that shows whether the message must be 
//                           saved (is used only if the Interactions subsystem is
//                           embedded).
//
Procedure OpenEmailMessageSendForm(Val Sender = Undefined,
												Val Recipient = Undefined,
												Val Subject = "",
												Val Text = "",
												Val FileList = Undefined,
												Val DeleteFilesAfterSending = False,
												Val SaveEmailMessage = True) Export
	
	StandardProcessing = True;
	
	EmailClientOverridable.OpenEmailMessageSendForm(StandardProcessing,
	      Sender,Recipient,Subject,Text,FileList,DeleteFilesAfterSending);
	
	If StandardProcessing Then
		OpenSimpleSendEmailForm(Sender,
		Recipient, Subject,Text, FileList, DeleteFilesAfterSending);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// The interface client function that supports simplified call of the new message edit
// form. Messages are not saved in the infobase when sending them through the simple
// message form.
//
// See the OpenEmailMessageSendForm for details.
//
Procedure OpenSimpleSendEmailForm(Sender,
			Recipient, Subject, Text, FileList, DeleteFilesAfterSending) Export
	
	//EmailParameters = New Structure;
	//
	//EmailParameters.Insert("Account", Sender);
	//EmailParameters.Insert("Recipient", Recipient);
	//EmailParameters.Insert("Subject", Subject);
	//EmailParameters.Insert("Body", Text);
	//EmailParameters.Insert("Attachments", FileList);
	//EmailParameters.Insert("DeleteFilesAfterSending", DeleteFilesAfterSending);
	//
	//OpenForm("CommonForm.EditNewEmailMessage", EmailParameters);
	
EndProcedure

// Verifying the account.
//
// Parameters:
// Account - CatalogRef.EmailAccounts - account to be verified.
//
Procedure CheckAccount(Val Account) Export
	
	ClearMessages();
	
	Status(NStr("en = 'Verifying account'"),,NStr("en = 'Verifying the account. Please wait...'"));
	
	If Email.PasswordSpecified(Account) Then
		PasswordParameter = Undefined;
	Else
		//AccountParameter = New Structure("Account", Account);
		//OpenForm("CommonForm.AccountPasswordConfirmation", AccountParameter,,,,, New NotifyDescription("CheckAccountEnd", ThisObject, New Structure("Account", Account)), FormWindowOpeningMode.LockWholeInterface);
        Return;
	EndIf;
	
	CheckAccountPart(Account, PasswordParameter);
EndProcedure

Procedure CheckAccountEnd(Result, AdditionalParameters) Export
	
	Account = AdditionalParameters.Account;
	
	
	PasswordParameter = Result;
	If TypeOf(PasswordParameter) <> Type("String") Then
		Return
	EndIf;
	
	CheckAccountPart(Account, PasswordParameter);

EndProcedure

Procedure CheckAccountPart(Val Account, Val PasswordParameter)
	
	Var AdditionalMessage, ErrorMessage;
	
	ErrorMessage = "";
	AdditionalMessage = "";
	Email.CheckSendReceiveEmailPossibility(Account, PasswordParameter, ErrorMessage, AdditionalMessage);
	
	If ValueIsFilled(ErrorMessage) Then
		ShowMessageBox(,StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'During verification of account parameters, the following errors were found:
		|%1'"), ErrorMessage ),,
		NStr("en = 'Verifying account'"));
	Else
		ShowMessageBox(,StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Account parameter verifying completed successfully. %1'"),
		AdditionalMessage ),,
		NStr("en = 'Verifying account'"));
	EndIf;
	
EndProcedure
 // CheckAccount()

