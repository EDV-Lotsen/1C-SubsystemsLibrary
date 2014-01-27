////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If ValueIsFilled(Object.Password) Then
		RememberPassword = True;
	EndIf;
	
	// Hiding unused items if the email operation subsystem is the only one that is used
	If Metadata.CommonModules.Find("EmailManagement") = Undefined Then
		Items.IncludeUserNameInPresentation.Visible = False;
	EndIf;
	
	If Object.Ref.IsEmpty() Then
		Object.UseForSending = True;
		Object.UseForReceiving = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject)
	
	If Not RememberPassword Then
		CurrentObject.Password = "";
	EndIf;
	
	If Object.SMTPAuthentication <> Enums.SMTPAuthenticationVariants.SetWithParameters Then
		Object.SMTPUser = "";
		Object.SMTPPassword = "";
	EndIf;
	
EndProcedure

// Processes the notification that contains account settings from the additional account parameter form.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "SetAdditionalAccountParameters" And Source = Object.Ref Then
		Object.Timeout                   = Parameter.ServerTimeout;
		Object.KeepMessageCopiesAtServer = Parameter.KeepMessageCopiesAtServer;
		Object.KeepMessageAtServerPeriod = Parameter.KeepMessageAtServerPeriod;
		Object.SMTPUser                  = Parameter.SMTPUser;
		Object.SMTPPassword              = Parameter.SMTPPassword;
		Object.POP3Port                  = Parameter.POP3Port;
		Object.SMTPPort                  = Parameter.SMTPPort;
		Object.SMTPAuthentication        = Parameter.SMTPAuthentication;
		Object.SMTPAuthenticationMode    = Parameter.SMTPAuthenticationMode;
		Object.POP3AuthenticationMode    = Parameter.POP3AuthenticationMode;
		Modified = True;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure AdditionalSettingsExecute()
	
	AccountStructure = New Structure;
	AccountStructure.Insert("Timeout",                   Object.Timeout);
	AccountStructure.Insert("KeepMessageCopiesAtServer", Object.KeepMessageCopiesAtServer);
	AccountStructure.Insert("KeepMessageAtServerPeriod", Object.KeepMessageAtServerPeriod);
	AccountStructure.Insert("SMTPUser",                  Object.SMTPUser);
	AccountStructure.Insert("SMTPPassword",              Object.SMTPPassword);
	AccountStructure.Insert("POP3Port",                  Object.POP3Port);
	AccountStructure.Insert("SMTPPort",                  Object.SMTPPort);
	AccountStructure.Insert("SMTPAuthentication",        Object.SMTPAuthentication);
	AccountStructure.Insert("SMTPAuthenticationMode",    Object.SMTPAuthenticationMode);
	AccountStructure.Insert("POP3AuthenticationMode",    Object.POP3AuthenticationMode);
	
	CallParameters = New Structure("Ref, AccountStructure, ReadOnly", Object.Ref, AccountStructure, ReadOnly);
	
	OpenForm("Catalog.EmailAccounts.Form.AdditionalAccountParameters", CallParameters);
	
EndProcedure







