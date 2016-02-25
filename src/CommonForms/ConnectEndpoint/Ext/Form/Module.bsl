
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	EndpointConnectionEventLogMessageText = MessageExchangeInternal.EndpointConnectionEventLogMessageText();
	
	StandardSubsystemsServer.SetGroupTitleRepresentation(ThisObject);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	WarningText = NStr("en = 'Do you want to cancel the endpoint connection?'");
	Notification = New NotifyDescription("ConnectAndClose", ThisObject);
	CommonUseClient.ShowFormClosingConfirmation(Notification, Cancel, WarningText);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ConnectEndpoint(Command)
	
	ConnectAndClose();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure ConnectAndClose(Result = Undefined, AdditionalParameters = Undefined) Export
	
	Status(NStr("en = 'The endpoint connection is in process. Please wait...'"));
	
	Cancel = False;
	FillError = False;
	
	ConnectEndpointAtServer(Cancel, FillError);
	
	If FillError Then
		Return;
	EndIf;
	
	If Cancel Then
		
		NString = NStr("en = 'The endpoint connection errors.
		|Do you want to view the event log?'");
		NotifyDescription = New NotifyDescription("OpenEventLog", ThisObject);
		ShowQueryBox(NotifyDescription, NString, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
		Return;
	EndIf;
	
	Notify(MessageExchangeClient.EndpointAddedEventName());
	
	ShowUserNotification(,,NStr("en = 'The endpoint is connected.'"));
	
	Modified = False;
	
	Close();
	
EndProcedure

&AtClient
Procedure OpenEventLog(Answer, AdditionalParameters) Export
	
	If Answer = DialogReturnCode.Yes Then
		
		Filter = New Structure;
		Filter.Insert("EventLogMessageText", EndpointConnectionEventLogMessageText);
		OpenForm("DataProcessor.EventLog.Form", Filter, ThisObject);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ConnectEndpointAtServer(Cancel, FillError)
	
	If Not CheckFilling() Then
		FillError = True;
		Return;
	EndIf;
	
	MessageExchange.ConnectEndpoint(
		Cancel,
		SenderSettingsWSURL,
		SenderSettingsWSUserName,
		SenderSettingsWSPassword,
		RecipientSettingsWSURL,
		RecipientSettingsWSUserName,
		RecipientSettingsWSPassword);
	
EndProcedure

#EndRegion
