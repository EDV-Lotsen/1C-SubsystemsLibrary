
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	Authorization = AddressClassifier.WebsiteAuthenticationParameters();
	If Authorization.Filled Then
		Login  = Authorization.Login;
		Password = Authorization.Password;
	EndIf;
	
	RememberPassword = Not IsBlankString(Password);
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure GoToWebsiteRegistrationClick(Item)
	
	GotoURL("http://1c-dn.com/");
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

// The Continue button, user choice.
//
// Choice result:
//     Structure, Undefined - If user chooses not to enter password, then Undefined. 
//                            Otherwise, a structure containing fields:
//        * Login    - String - Website login
//        * Password - String - Entered password
//
&AtClient
Procedure SaveAuthenticationDataAndContinue()
	
	Result = New Structure("Login, Password", Login, Password);
	If RememberPassword Then
		SaveAuthenticationData(Result);
	EndIf;
	
	NotifyChoice(Result);
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServerNoContext
Procedure SaveAuthenticationData(Val Authentication)
	
	AddressClassifier.WebsiteAuthenticationParameters(Authentication);
	
EndProcedure

#EndRegion
