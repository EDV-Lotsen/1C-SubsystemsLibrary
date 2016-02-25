
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	IsThisNode = (Object.Ref = MessageExchangeInternal.ThisNode());
	
	Items.InfoMessageGroup.Visible = Not IsThisNode;
	
	If Not IsThisNode Then
		
		If Object.Locked Then
			Items.InfoMessage.Title
				= NStr("en = 'This endpoint is locked.'");
		ElsIf Object.Leading Then
			Items.InfoMessage.Title
				= NStr("en = 'This endpoint is leading, that is it initiates current infosystem exchange messages sending and receiving.'");
		Else
			Items.InfoMessage.Title
				= NStr("en = 'This endpoint is subordinate, that is it performs exchange messages sending and receiving only upon the current infosystem request.'");
		EndIf;
		
		Items.MakeThisEndpointSubordinate.Visible = Object.Leading And Not Object.Locked;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose()
	
	Notify(MessageExchangeClient.EndpointFormClosedEventName());
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = MessageExchangeClient.EventNameLeadingEndpointSet() Then
		
		Close();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure MakeThisEndpointSubordinate(Command)
	
	FormParameters = New Structure("Endpoint", Object.Ref);
	
	OpenForm("CommonForm.LeadingEndpointSetting", FormParameters, ThisObject, Object.Ref);
	
EndProcedure

#EndRegion
