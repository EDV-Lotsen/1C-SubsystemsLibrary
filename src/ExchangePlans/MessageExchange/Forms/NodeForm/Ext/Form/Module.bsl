
////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	IsThisNode = (Object.Ref = MessageExchangeInternal.ThisNode());
	
	Items.InfoMessageGroup.Visible = Not IsThisNode;
	
	If Not IsThisNode Then
		
		If Object.Leading Then
			Items.InfoMessage.Title 
				= NStr("en = 'This is a leading end point. It initiates sending and receiving exchange messages for the current application.'");
			
		Else
			Items.InfoMessage.Title 
				= NStr("en = 'This is a subordinate end point. It sends and receives exchange messages only if the application requires this.'");
			
		EndIf;
		
		Items.MakeThisEndPointSubordinate.Visible = Object.Leading;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose()
	
	Notify(MessageExchangeClient.EndPointFormClosedEventName());
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = MessageExchangeClient.EventNameLeadingEndPointSet() Then
		
		Close();
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure MakeThisEndPointSubordinate(Command)
	
	FormParameters = New Structure("EndPoint", Object.Ref);
	
	OpenForm("CommonForm.LeadingEndPointSetting", FormParameters, ThisForm, Object.Ref);
	
EndProcedure





