
//------------------------------------------------------------------------------
//
// Value to return:
//
// Undefined - user hasn't entered the password
// Structure  -
//            key "Status", boolean - true or false depending if call is successful
//            key "Login", string - in case if status is True contains login
//            key "Password", string - if status is True contains password
//
//------------------------------------------------------------------------------

////////////////////////////////////////////////////////////////////////////////
// SECTION OF FORM AND FORM ITEMS EVENT HANDLERS
//

// Handler of event "OnCreateAtServer" of form
//
&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	LinkToUserWebsite = NStr("en = 'Go to registration at user site'");
	
	AddressClassifier.GetAuthenticationParameters(Login, Password);
	
	DoPasswordSave = ? (IsBlankString(Password), False, True);
	
EndProcedure

// Handler of event press button "Continue"
//
&AtClient
Procedure SaveAuthenticationDataAndContinueExecute()
	
	If DoPasswordSave Then
		AddressClassifier.SaveAuthenticationParameters(Login, Password);
	Else
		AddressClassifier.SaveAuthenticationParameters(Login, Undefined);
	EndIf;
	
	Close (New Structure("Status, Login ,Password", True, Login, Password));
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SECTION OF SERVICE FUNCTIONS
//

// Implements transition to 1C user site
//
&AtClient
Procedure LinkToUserWebsiteClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	RunApp("http://1c-dn.com/");
	
EndProcedure
