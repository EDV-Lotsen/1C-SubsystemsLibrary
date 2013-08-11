////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Fills a new account with default values.
//
Procedure FillObjectWithDefaultValues() Export
	
	UserName = NStr("en = '1C:Enterprise'");
	SMTPAuthentication = Enums.SMTPAuthenticationVariants.NotDefined;
	UseForReceiving = False;
	KeepMessageCopiesAtServer = False;
	KeepMessageAtServerPeriod = 0;
	Timeout = 30;
	SMTPAuthentication = Enums.SMTPAuthenticationVariants.NotDefined;
	SMTPAuthenticationMode = Enums.SMTPAuthenticationModes.None;
	POP3AuthenticationMode = Enums.POP3AuthenticationModes.Ordinary;
	SMTPUser = "";
	SMTPPassword = "";
	POP3Port = 110;
	SMTPPort = 25;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

Procedure Filling(FillingData, StandardProcessing)
	
	FillObjectWithDefaultValues();
	
EndProcedure
