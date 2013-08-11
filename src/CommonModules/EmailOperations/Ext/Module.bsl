////////////////////////////////////////////////////////////////////////////////
// Email operations subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
//   The EmailOperations module contains functions for working with email messages.
// This module must be embedded in all configurations that contain the email subsystem.
//
//   Functions contain no parameters, all parameters are at modules that provide
// function implementation.
//

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Retrieves the system account reference.
//
// Returns:
//  Account - CatalogRef.EmailAccounts - account reference.
//
Function GetSystemAccount() Export
	
	Return Email.GetSystemAccount();
	
EndFunction

// Checks whether the system account is available and can be used.
//
Function CheckSystemAccountAvailable() Export
	
	Return Email.CheckSystemAccountAvailable();
	
EndFunction

// Returns available email accounts.
//
// Parameters:
// ForSending                  - Boolean - flag that shows whether only accounts that 
//                               can be used as a sender will be chosen.
// ForReceiving                - Boolean - flag that shows whether only accounts that 
//                               can be used as arecipient will be chosen.
// IncludingSystemEmailAccount - flag that shows whether the system email account will
//                               be included in the selection (if it is available).
//
// Returns:
// ValueTable that contains the following columns:
//    Ref         - CatalogRef.EmailAccounts - account reference.
//    Description - String - account description.
//    Address     - String - email address.
//
Function GetAvailableAccounts(Val ForSending = Undefined, Val ForReceiving = Undefined, Val IncludingSystemEmailAccount = True) Export
	
	Return Email.GetAvailableAccounts(ForSending, ForReceiving, IncludingSystemEmailAccount);
	
EndFunction

// Sends the email message.
//
// Parameters:
//  Account         - CatalogRef.EmailAccounts - email account reference.
//  EmailParameters - Structure - Contains all required message details:
//    Recipient*    - Array of Structure, String - message recipient address.
//                    Address - String - email address.
//                    Presentation - String - recipient name.
//    Subject*      - String - message subject.
//    Body*         - String - message body (win-1251 text).
//    Attachments   - Map
//                    Key - AttachmentDescription - String - attachment description.
//                    Value - BinaryData - attachment data.
//
//  Additional structure key that can be used:
//    ReplyTo       - Map - see Recipient for details.
//    Password      - String - account password.
//    TextType      - String, Enumeration.EmailTextTypes - determines the passed text
//                    type. It can take the following values:
//                    HTML - EmailTextTypes.HTML - HTML formatted text.
//                    PlainText - EmailTextTypes.PlainText - plain text. It is 
//                    displayed "as is" (the default value).
//                    RichText - EmailTextTypes.RichText - rich text.
//
//    Note: Parameters marked with * are mandatory.
//
// Returns:
// String - ID of the sent email message on the SMTP server.
//
// NOTE: the function can raise an exception, which must be processed.
//
Function SendMessage(Val Account, Val EmailParameters) Export
	
	Return Email.SendEmailMessage(Account, EmailParameters);
	
EndFunction
