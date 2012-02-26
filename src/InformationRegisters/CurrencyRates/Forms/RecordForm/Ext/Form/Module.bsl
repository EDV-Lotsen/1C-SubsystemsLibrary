

&AtClient
Procedure AfterWrite(WriteParameters)
	Notify("CurrencyRateUpdate");
EndProcedure
