

Procedure FillCheckProcessing(Cancellation, CheckedAttributes)
	
	If DownloadRatesPeriodically And ValueIsFilled(SubordinateRateFrom) Then
		CommonUseClientServer.MessageToUser(
		              NStr("en = 'Currency cannot be dependant and concurrently being downloaded from the RBK web site'"));
		Return;
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancellation)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If ValueIsFilled(SubordinateRateFrom.SubordinateRateFrom) Then
		CommonUseClientServer.MessageToUser(NStr("en = 'Error during record: main currency cannot be dependant'"),,,,Cancellation);
	EndIf;
	
	If WorkWithExchangeRates.GetDependentCurrenciesList(Ref).Count() > 0 
	   And ValueIsFilled(SubordinateRateFrom) Then
		CommonUseClientServer.MessageToUser(NStr("en = 'Record error: the currency cannot be subordinated, as it is main for other currencies'"),,,,Cancellation);
	EndIf;
	
	If Cancellation Then
		Return;
	EndIf;
	
	WorkWithExchangeRates.CheckThatCourseIsCorrectOn01_01_1980(Ref);
	
	If ValueIsFilled(SubordinateRateFrom) Then
		WorkWithExchangeRates.WriteInfoForSubordinateRegister(SubordinateRateFrom, Ref);
	EndIf;
	
EndProcedure
