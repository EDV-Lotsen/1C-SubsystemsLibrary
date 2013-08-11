//------------------------------------------------------------------------------
// PASSED TO THE FORM PARAMETERS
//
// Account*  - CatalogRef.EmailAccounts
//
// RETURNS
//
// Undefined - if the user refused to enter the password.
// Structure - State key        - Boolean - flag that shows whether the password was  
//                                entered correctly.
//           - Password key     - string - contains the password if State is True.
//           - ErrorMessage key - contains the error message if State is False.
//
//------------------------------------------------------------------------------
// HOW THE FORM WORKS
//
//   If the passed account list contains more than one item, the email account to be
// a sender is chosen from the list on the form.
//
//------------------------------------------------------------------------------

////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	If Parameters.Account.IsEmpty() Then
		Cancel = True;
		Return;
	EndIf;
	
	Account = Parameters.Account;
	Result = LoadPassword();
	
	If ValueIsFilled(Result) Then
		Password = Result;
		PasswordConfirmation = Result;
		StorePassword = True;
	Else
		Password = "";
		PasswordConfirmation = "";
		StorePassword = False;
	EndIf;
	
	If Not AccessRight("SaveUserData", Metadata) Then
		Items.StorePassword.Visible = False;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure SavePasswordAndContinueExecute()
	
	If Password <> PasswordConfirmation Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'The password and password confirmation do not match.'"), , "Password");
		Return;
	EndIf;
	
	If StorePassword Then
		SavePassword(Password);
	Else
		SavePassword(Undefined);
	EndIf;
	
	Close(Password);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Procedure SavePassword(Value)
	
	CommonUse.CommonSettingsStorageSave(
		"AccountPasswordConfirmationForm",
		Account,
		Value
	);
	
EndProcedure

&AtServer
Function LoadPassword()
	
	Return CommonUse.CommonSettingsStorageLoad("AccountPasswordConfirmationForm", Account);
	
EndFunction
