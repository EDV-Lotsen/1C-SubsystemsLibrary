#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Recipient = Filter["Recipient"].Value;
	
	If Recipient <> Undefined
		And Recipient = MessageExchangeInternal.ThisNode() Then
		
		Recipients = MessageExchangeInternal.AllRecipients();
		
		DataExchange.Recipients.Clear();
		
		For Each Node In Recipients Do
			
			DataExchange.Recipients.Add(Node);
			
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf