////////////////////////////////////////////////////////////////////////////////
// Currencies subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

// Notifies that currency rates are to be updated.
//
Procedure CurrencyRateOperationsShowObsoleteNotification() Export
	If Not CurrencyRateOperationsServerCall.RatesRelevant() Then
		CurrencyRateOperationsClient.NotifyRatesObsolete();
	EndIf;
	
	CurrentDate = CommonUseClient.SessionDate();
	NextDayHandlerPeriod = EndOfDay(CurrentDate) - CurrentDate + 59;
	AttachIdleHandler("CurrencyRateOperationsShowObsoleteNotification", NextDayHandlerPeriod, True);
EndProcedure

#EndRegion
