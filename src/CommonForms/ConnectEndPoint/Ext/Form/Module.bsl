&AtClient
Var ForceCloseForm;

////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	EndPointConnectionEventLogMessageText = MessageExchangeInternal.EndPointConnectionEventLogMessageText();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ForceCloseForm = False;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	CommonUseClient.RequestCloseFormConfirmation(
		Cancel,
		,
		ForceCloseForm,
		NStr("en = 'Do you want to cancel connecting the end point?'")
	); 
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure ConnectEndPoint(Command)
	
	Status(NStr("en = 'Connecting the end point. Please wait...'"));
	
	Cancel = False;
	FillError = False;
	
	ConnectEndPointAtServer(Cancel, FillError);
	
	If FillError Then
		Return;
	EndIf;
	
	If Cancel Then
		
		NString = NStr("en = 'Error connecting the end point.
		|Do you want to open the event log?'");
		Response = DoQueryBox(NString, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
		If Response = DialogReturnCode.Yes Then
			
			Filter = New Structure;
			Filter.Insert("EventLogMessageText", EndPointConnectionEventLogMessageText);
			OpenFormModal("DataProcessor.EventLogMonitor.Form", Filter, ThisForm);
			
		EndIf;
		Return;
	EndIf;
	
	Notify(MessageExchangeClient.EndPointAddedEventName());
	
	DoMessageBox(NStr("en = 'Connecting the end point completed successfully.'"));
	
	ForceCloseForm = True;
	
	Close();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Procedure ConnectEndPointAtServer(Cancel, FillError)
	
	If Not CheckFilling() Then
		FillError = True;
		Return;
	EndIf;
	
	MessageExchange.ConnectEndPoint(
		Cancel,
		SenderSettingsWSURL,
		SenderSettingsWSUserName,
		SenderSettingsWSPassword,
		RecipientSettingsWSURL,
		RecipientSettingsWSUserName,
		RecipientSettingsWSPassword
	);
	
EndProcedure





