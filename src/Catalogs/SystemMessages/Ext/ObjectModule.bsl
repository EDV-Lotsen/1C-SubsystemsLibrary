#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then


Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	MessageChannel = Description;
	
	BodyContent = Body.Get();
	
	// StandardSubsystems.SaaSOperations.BaseFunctionalitySaaS
	MessagesSaaS.MessagesBeforeSend(MessageChannel, BodyContent);
	// End StandardSubsystems.SaaSOperations.BaseFunctionalitySaaS
	
	Body = New ValueStorage(BodyContent);
	
EndProcedure

#EndIf