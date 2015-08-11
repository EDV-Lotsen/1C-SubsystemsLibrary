&AtClient
Var ForceCloseForm;

////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;

	LeadingEndPointSettingEventLogMessageText = MessageExchangeInternal.LeadingEndPointSetEventLogMessageText();
	
	EndPoint = Parameters.EndPoint;
	
	// Reading connection settings values
	FillPropertyValues(ThisForm, InformationRegisters.ExchangeTransportSettings.GetWSTransportSettings(EndPoint));
	
	Title = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Setting the leading end point for %1'"),
		CommonUse.GetAttributeValue(EndPoint, "Description")
	);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	//Cancel = CommonUseClient.RequestCloseFormConfirmation(
	//	Cancel,
	//	,
	//	ForceCloseForm,
	//	NStr("en = 'Do you want to cancel the operation?'")
	//); 
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure Set(Command)
	
	Status(NStr("en = 'Setting the leading end point. Please wait...'"));
	
	Cancel = False;
	FillError = False;
	
	SetLeadingEndpointAtServer(Cancel, FillError);
	
	If FillError Then
		Return;
	EndIf;
	
	If Cancel Then
		
		NString = NStr("en = 'Error setting the leading end point.
		|Do you want to open the event log'");
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("SetEnd", ThisObject), NString, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
		Return;
	EndIf;
	
	Notify(MessageExchangeClient.EventNameLeadingEndPointSet());
	
	ShowMessageBox(,NStr("en = 'The end point was set successfully.'"));
	
	ForceCloseForm = True;
	
	Close();
	
EndProcedure

&AtClient
Procedure SetEnd(QuestionResult, AdditionalParameters) Export
	
	Response = QuestionResult;
	If Response = DialogReturnCode.Yes Then
		
		Filter = New Structure;
		Filter.Insert("EventLogMessageText", LeadingEndPointSettingEventLogMessageText);
		OpenForm("DataProcessor.EventLogMonitor.Form", Filter, ThisForm,,,, Undefined, FormWindowOpeningMode.LockWholeInterface);
		
	EndIf;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Procedure SetLeadingEndpointAtServer(Cancel, FillError)
	
	If Not CheckFilling() Then
		FillError = True;
		Return;
	EndIf;
	
	WSConnectionSettings = DataExchangeServer.WSParameterStructure();
	
	FillPropertyValues(WSConnectionSettings, ThisForm);
	
	MessageExchangeInternal.SetLeadingEndpointAtSender(Cancel, WSConnectionSettings, EndPoint);
	
EndProcedure

