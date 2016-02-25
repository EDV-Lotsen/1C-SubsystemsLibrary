#If Server OR ThickClientOrdinaryApplication OR ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	// If data separation mode is set, record set modification is prohibited for shared nodes
	DataExchangeServer.ExecuteSharedDataOnWriteCheck(Filter.InfobaseNode.Value);
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
