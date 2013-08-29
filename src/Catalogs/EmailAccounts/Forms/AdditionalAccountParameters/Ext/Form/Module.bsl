////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	Ref = Parameters.Ref;
	
	Fill_ListSMTPAuthentication();
	Fill_ListSMTPAuthenticationMode();
	
	AccountStructure = Parameters.AccountStructure;
	
	ServerTimeout = AccountStructure.Timeout;
	
	KeepMessageCopiesAtServer = AccountStructure.KeepMessageCopiesAtServer;
	KeepMessageCopiesDayCount = AccountStructure.KeepMessageAtServerPeriod;
	DeleteMessagesFromServer		 = ?(KeepMessageCopiesDayCount = 0, False, True);
	
	SMTPPort = AccountStructure.SMTPPort;
	POP3Port = AccountStructure.POP3Port;
	
	// Passing Use SSL flags
	POP3UseSSL = AccountStructure.POP3UseSSL;
	SMTPUseSSL = AccountStructure.SMTPUseSSL;
	// SSL

	
	POP3AuthenticationMode = AccountStructure.POP3AuthenticationMode;
	
	SMTPAuthenticationMode = AccountStructure.SMTPAuthenticationMode;
	SMTPUser               = AccountStructure.SMTPUser;
	SMTPPassword           = AccountStructure.SMTPPassword;
	
	SMTPAuthentication = AccountStructure.SMTPAuthentication;
	
	SMTPAuthenticationSet = ?(SMTPAuthentication = Enums.SMTPAuthenticationVariants.NotDefined, False, True);
	
	Items.SMTPAuthenticationGroup.CurrentPage = ?(SMTPAuthentication = Enums.SMTPAuthenticationVariants.SetWithParameters,
															Items.ParametersGroup,
															Items.EmptyPageGroup);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetFormItemEnabled();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

// The SMTPAuthentication form item On change event handler.
// Calls the additional authentication parameter group update handler. 
//
&AtClient
Procedure SMTPAuthenticationOnChange(Item)
	
	SetExtendedParametersForSMTPAuthentication();
	
EndProcedure

// The RequiresAdditionalSMTPAuthentication form item On change event handler.
// Sets default authentication parameters or removes them if SMTPAuthenticationSet
// is disabled.
//
&AtClient
Procedure SMTPAuthenticationPassedOnChange(Item)
	
	If SMTPAuthenticationSet Then
		Items.SMTPAuthentication.Enabled = True;
		SMTPAuthenticationMode = ?(SMTPAuthenticationMode = SMTPAuthenticationMode_None(),
		                             SMTPAuthenticationMode_Default(),
		                             SMTPAuthenticationMode);
		SMTPAuthentication = SMTPAuthentication_SimilarlyPOP3();
	Else
		Items.SMTPAuthentication.Enabled = False;
		SMTPAuthentication = SMTPAuthentication_NotDefined();
		SMTPAuthenticationMode = SMTPAuthenticationMode_None();
	EndIf;
	
	SetExtendedParametersForSMTPAuthentication();
	
EndProcedure

&AtClient
Procedure KeepMessageCopiesAtServerOnChange(Item)
	
	SetFormItemEnabled();
	
EndProcedure

&AtClient
Procedure DeleteMessagesFromServerOnChange(Item)
	
	SetFormItemEnabled();
	
	If DeleteMessagesFromServer Then
		KeepMessageCopiesDayCount = 1;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure SetPortsByDefaultExecute()
	
	SMTPPort = 25;
	POP3Port = 110;
	
EndProcedure


// Verifying form attribute value correctness.
// Returns control and extended account parameter values to the calling environment.

// 
&AtClient
Procedure FillExtendedParametersAndReturnExecute()
	
	If SMTPAuthenticationSet
	   And SMTPAuthentication <> SMTPAuthentication_SimilarlyPOP3()
	   And SMTPAuthentication <> SMTPAuthentication_SetWithParameters()
	   And SMTPAuthentication <> SMTPAuthentication_POP3BeforeSMTP() Then
		CommonUseClientServer.MessageToUser(
		              NStr("en = 'Select SMTP authentication mode'"), ,
		              "SMTPAuthentication");
		Return;
	EndIf;
	
	Notify("SetAdditionalAccountParameters", FillExtendedParameters(), Ref);
	
	Close();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Unified procedure for setting form item enable states by conditions
//
&AtClient
Procedure SetFormItemEnabled()
	
	If KeepMessageCopiesAtServer Then
		Items.DeleteMessagesFromServer.Enabled = True;
		If DeleteMessagesFromServer Then
			Items.KeepMessageCopiesDayCount.Enabled = True;
		Else
			Items.KeepMessageCopiesDayCount.Enabled = False;
		EndIf;
	Else
		Items.DeleteMessagesFromServer.Enabled = False;
		Items.KeepMessageCopiesDayCount.Enabled = False;
	EndIf;
	
	If SMTPAuthenticationSet Then
		Items.SMTPAuthentication.Enabled = True;
	Else
		Items.SMTPAuthentication.Enabled = False;
	EndIf;
	
EndProcedure

// Generates settings parameters before they will be passed to the calling environment.
//
// Returns:
// Structure with the following keys:
//  SMTPPort                  - Number - SMTP port.
//  POP3Port                  - Number - POP3 port.
//  KeepMessageCopiesAtServer - Boolean - flag that shows that message copies will be
//                              saved on the server.
//  KeepMessageAtServerPeriod - Number - number of days during which the message will
//                              be stored on the server.
//  ServerTimeout             - Number - number of seconds during which the function 
//                              will wait for operation execution on the server.
//  SMTPAuthentication        - Enum.SMTPAuthentication
//  SMTPUser                  - String - SMTP authentication user name.
//  SMTPPassword              - String - SMTP authentication password.
//  SMTPAuthenticationMode*   - Enum.SMTPAuthenticationMode
//  POP3AuthenticationMode    - Enum.POP3AuthenticationMode
//
// *- If SMTP authentication mode is SimilarlyPOP3, the authentication parameter values
// are copied from POP3.
//
// All fields are always filled, that is why you can use them in the calling
// environment without any extra processing.
//
&AtClient
Function FillExtendedParameters()
	
	Result = New Structure;
	
	Result.Insert("SMTPPort", SMTPPort);
	Result.Insert("POP3Port", POP3Port);
	
	Result.Insert("KeepMessageCopiesAtServer", KeepMessageCopiesAtServer);
	
	If DeleteMessagesFromServer Then
		KeepMessageCopiesDayCount = KeepMessageCopiesDayCount;
	Else
		KeepMessageCopiesDayCount = 0;
	EndIf;
	
	Result.Insert("KeepMessageAtServerPeriod", KeepMessageCopiesDayCount);
	
	Result.Insert("ServerTimeout", ServerTimeout);
	
	If SMTPAuthenticationSet Then
		Result.Insert("SMTPAuthentication", SMTPAuthentication);
		If SMTPAuthentication = (SMTPAuthentication_SetWithParameters()) Then
			Result.Insert("SMTPUser", SMTPUser);
			Result.Insert("SMTPPassword", SMTPPassword);
			Result.Insert("SMTPAuthenticationMode", SMTPAuthenticationMode);
		Else
			Result.Insert("SMTPUser", "");
			Result.Insert("SMTPPassword", "");
			Result.Insert("SMTPAuthenticationMode", SMTPAuthenticationMode_None());
		EndIf;
	Else
		Result.Insert("SMTPAuthentication", SMTPAuthentication_NotDefined());
		Result.Insert("SMTPUser", "");
		Result.Insert("SMTPPassword", "");
		Result.Insert("SMTPAuthenticationMode", SMTPAuthenticationMode_None());
	EndIf;
	
	Result.Insert("POP3AuthenticationMode", POP3AuthenticationMode);
	
	// Including Use SSL flags into the result structure
	Result.Insert("POP3UseSSL", POP3UseSSL);
	Result.Insert("SMTPUseSSL", SMTPUseSSL);
	// SSL

	Return Result;
	
EndFunction

// Sets extended authentication parameter visibility
// if the SMTP authentication mode is SMTPAuthentication_SetWithParameters.
//
&AtClient
Procedure SetExtendedParametersForSMTPAuthentication()
	
	Items.SMTPAuthenticationGroup.CurrentPage =
	                  ?(SMTPAuthentication = SMTPAuthentication_SetWithParameters(),
	                   Items.ParametersGroup,
	                   Items.EmptyPageGroup);
	
EndProcedure

&AtServer
Function Fill_ListSMTPAuthentication()
	
	SMTPAuthenticationList.Add(Enums.SMTPAuthenticationVariants.POP3BeforeSMTP,
	                                     "POP3BeforeSMTP");
	SMTPAuthenticationList.Add(Enums.SMTPAuthenticationVariants.SimilarlyPOP3,
	                                     "SimilarlyPOP3");
	SMTPAuthenticationList.Add(Enums.SMTPAuthenticationVariants.SetWithParameters,
	                                     "SetWithParameters");
	SMTPAuthenticationList.Add(Enums.SMTPAuthenticationVariants.NotDefined,
	                                     "NotDefined");
	
EndFunction

&AtClient
Function SMTPAuthentication_POP3BeforeSMTP()
	
	Return SMTPAuthenticationList[0].Value;
	
EndFunction

&AtClient
Function SMTPAuthentication_SimilarlyPOP3()
	
	Return SMTPAuthenticationList[1].Value;
	
EndFunction

&AtClient
Function SMTPAuthentication_SetWithParameters()
	
	Return SMTPAuthenticationList[2].Value;
	
EndFunction

&AtClient
Function SMTPAuthentication_NotDefined()
	
	Return SMTPAuthenticationList[3].Value;
	
EndFunction

&AtServer
Function Fill_ListSMTPAuthenticationMode()
	
	ListSMTPAuthenticationMode.Add(Enums.SMTPAuthenticationModes.CramMD5,
	                                     "CramMD5");
	ListSMTPAuthenticationMode.Add(Enums.SMTPAuthenticationModes.Login,
	                                     "Login");
	ListSMTPAuthenticationMode.Add(Enums.SMTPAuthenticationModes.Plain,
	                                     "Plain");
	ListSMTPAuthenticationMode.Add(Enums.SMTPAuthenticationModes.None,
	                                     "None");
	ListSMTPAuthenticationMode.Add(Enums.SMTPAuthenticationModes.Default,
	                                     "Default");
	
EndFunction

&AtClient
Function SMTPAuthenticationMode_None()
	
	Return ListSMTPAuthenticationMode[3].Value;
	
EndFunction

&AtClient
Function SMTPAuthenticationMode_Default()
	
	Return ListSMTPAuthenticationMode[4].Value;
	
EndFunction
