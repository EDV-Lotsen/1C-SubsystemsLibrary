
#Region FormEventHandlers
//

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	CloseOnOwnerClose = True;
	
	If ValueIsFilled(Parameters.InfobaseNode) Then
		StringCommonSynchronizationSettings = DataExchangeServer.DataSynchronizationRuleDetails(Parameters.InfobaseNode);
		NodeDescription = String(Parameters.InfobaseNode);
	Else
		NodeDescription = "";
	EndIf;
	
	Title = StrReplace(Title, "%1", NodeDescription);
	
EndProcedure

#EndRegion
