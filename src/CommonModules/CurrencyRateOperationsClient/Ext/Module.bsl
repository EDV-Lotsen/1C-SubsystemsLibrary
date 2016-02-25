////////////////////////////////////////////////////////////////////////////////
// Currency subsystem
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

// Is invoked after the configuration start, connects the idle handler.
Procedure AfterStart() Export
	
	ClientParameters = StandardSubsystemsClientCached.ClientParametersOnStart();
	If ClientParameters.Property("Currencies") And ClientParameters.Currencies.RatesAreUpdatedByResponsible Then
		AttachIdleHandler("CurrencyRateOperationsShowObsoleteNotification", 15, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Update currency rates

// Displays the corresponding warning.
//
Procedure NotifyRatesObsolete() Export
	
	ShowUserNotification(
		NStr("en = 'Currency rates are obsolete'"),
		HandlerNavigationLink(),
		NStr("en = 'Update currency rates'"),
		PictureLib.Warning32);
	
EndProcedure

// Displays the corresponding warning.
//
Procedure NotifyRatesAreRefreshed() Export
	
	ShowUserNotification(
		NStr("en = 'Currency rates are successfully updated'"),
		HandlerNavigationLink(),
		NStr("en = 'Currency rates are updated'"),
		PictureLib.Information32);
	
EndProcedure

// Displays the corresponding warning.
//
Procedure NotifyRatesRelevant() Export
	
	ShowUserNotification(
		NStr("en = 'Currency rates are already updated'"),
		HandlerNavigationLink(),
		NStr("en = 'Currency rates are relevant'"),
		PictureLib.Information32);
	
EndProcedure

// Returns an alert navigation link.
//
Function HandlerNavigationLink()
	Return "e1cib/app/Processing.CurrencyRateImport";
EndFunction

#EndRegion
