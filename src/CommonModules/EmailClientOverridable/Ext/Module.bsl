////////////////////////////////////////////////////////////////////////////////
// Email operations subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Opens the edit form for the new letter.
//
// Parameters:
// StandardProcessing      - Boolean - pass False to this parameter if the form you 
//                           want to open is not the standard one.
// Sender*                 - ValueList, CatalogRef.EmailAccounts - email account 
//                           (account list) on behalf of which the email message can be
//                           send. If the parameter type is a value list, Value is 
//                           an email account reference and Presentation is an email 
//                           account description.
// Recipient               - ValueList, String.
//                            ValueList - Value fields contain email addresses, 
//                            Presentation fields contain email account descriptions.
//                            String - email address list in the correct email address
//                            format. 
// Subject                 - String - message subject.
// Text                    - String - message body.
// FileList                - ValueList - where:
//                           Presentation - string - attachment description.
//                           Value - BinaryData - binary attachment data.
//                                 - String - file address in the temporary store.
//                                 - String - path to the file on the client.
// DeleteFilesAfterSending - Boolean - flag that shows whether temporary files must be
//                            deleted after sending the message.
//
Procedure OpenEmailMessageSendForm(StandardProcessing,
												Sender,
												Recipient,
												Subject ,
												Text = "",
												FileList = Undefined,
												DeleteFilesAfterSending = False) Export
	
	
EndProcedure
