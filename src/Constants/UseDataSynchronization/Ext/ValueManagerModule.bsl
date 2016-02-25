#If Server OR ThickClientOrdinaryApplication OR ExternalConnection Then

Procedure OnWrite(Cancel)
	
	If Value = True Then
		
		DataSeparationEnabled = CommonUseCached.DataSeparationEnabled();
		Constants.UseDataSynchronizationInLocalMode.Set(Not DataSeparationEnabled);
		Constants.UseDataSynchronizationSaaS.Set(DataSeparationEnabled);
		
	Else
		
		Constants.UseDataSynchronizationInLocalMode.Set(False);
		Constants.UseDataSynchronizationSaaS.Set(False);
		
	EndIf;
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Value = True Then
		DataExchangeServer.DataSynchronizationOnEnable(Cancel);
	Else
		DataExchangeServer.DataSynchronizationOnDisable(Cancel);
	EndIf;
	
EndProcedure

#EndIf