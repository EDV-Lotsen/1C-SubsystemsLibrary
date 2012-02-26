

// Handler of scheduled job that loads currency rates
//
Procedure LoadActualRate() Export
	
	WriteLogEvent(EventLogMessage(),
		EventLogLevel.Information, , ,
		NStr("en = 'Scheduled dump of currency rates has started'"));
		
	CurrentDate = CurrentDate();
	
	ErrorMessage = "";
	
	CurencyRatesLoadProcessing 					= DataProcessors.CurrencyRatesNB.Create();
	CurencyRatesLoadProcessing.LoadPeriodBegin 	= CurrentDate;
	CurencyRatesLoadProcessing.LoadPeriodEnding = CurrentDate;
	CurencyRatesLoadProcessing.FillCurrencyList();
	OperationStatus 							= CurencyRatesLoadProcessing.LoadCurrencyRates(ErrorMessage);
	If OperationStatus Then
		WriteLogEvent(EventLogMessage(),
			EventLogLevel.Information, , ,
			NStr("en = 'Scheduled loading of the currency exchange rate has been completed'"));
	Else
		WriteLogEvent(EventLogMessage(),
			EventLogLevel.Error, , ,
			StringFunctionsClientServer.SubstitureParametersInString(
				NStr("en = 'An error %1 occurred during scheduled job of downloading the exchange rates'"), 
				ErrorMessage));
	EndIf;
	
EndProcedure

Function EventLogMessage()
	
	Return NStr("en = 'Currencies. Exchange rates update'");
	
EndFunction	
