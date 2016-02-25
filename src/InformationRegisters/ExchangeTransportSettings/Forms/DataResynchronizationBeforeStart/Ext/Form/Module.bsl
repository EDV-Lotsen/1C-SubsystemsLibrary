#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
  // Skipping the initialization to guarantee that the form will be received
  // if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	// Performing preliminary update of cached internal events (or getting update confirmation).
	Constants.InternalEventParameters.CreateValueManager().Update();
	// Client parameters update required.
	RefreshReusableValues();
	
	InfobaseNode = DataExchangeServer.MasterNode();
	LongActionAllowed = DataExchangeCached.IsStandaloneWorkstation();
	
	Items.NodeNameInfoLabel.Title = StringFunctionsClientServer.SubstituteParametersInString(
		Items.NodeNameInfoLabel.Title, InfobaseNode.Description);
	
	SetEnabled();
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure URLProcessingInfoLabel(Item, URL, StandardProcessing)
	
	StandardProcessing = False;
	
	If URL = "ConnectionParameters" Then
		
		Filter        = New Structure("Node", InfobaseNode);
		FillingValues = New Structure("Node", InfobaseNode);
		
		DataExchangeClient.OpenInformationRegisterRecordFormByFilter(Filter,
			FillingValues, "ExchangeTransportSettings", Undefined);
		
	ElsIf URL = "EventLog" Then
		
		FormParameters = New Structure;
		
		OpenForm("DataProcessor.EventLog.Form.EventLog", FormParameters,,,,,,
			FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SynchronizeAndContinue(Command)
	
	WarningText = "";
	HasErrors = False;
	LongAction = False;
	
	CheckUpdateRequired();
	
	If UpdateStatus = "NoUpdateRequired" Then
		
		SynchronizeAndContinueWithoutInfobaseUpdate();
		
	ElsIf UpdateStatus = "InfobaseUpdate" Then
		
		SynchronizeAndContinueWithInfobaseUpdate();
		
	ElsIf UpdateStatus = "ConfigurationUpdate" Then
		
		WarningText = NStr("en = 'Configuration changes received from the master node are not applied to the configuration.
			|Open Designer and update the infobase configuration.'");
		
	EndIf;
	
	If Not LongAction Then
		
		SynchronizeAndContinueCompletion();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure NotSynchronizeAndContinue(Command)
	
	NotSynchronizeAndContinueAtServer();
	
	Close("Continue");
	
EndProcedure

&AtClient
Procedure ExitCommand(Command)
	
	Close();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Scenario that does not include infobase update

&AtClient
Procedure SynchronizeAndContinueWithoutInfobaseUpdate()
	
	ImportDataExchangeMessageWithoutUpdating();
	
	If LongAction Then
		
		AttachIdleHandler("LongActionIdleHandler", 5, True);
		
	Else
		
		SynchronizeAndContinueWithoutInfobaseUpdateCompletion();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SynchronizeAndContinueWithoutInfobaseUpdateCompletion()
	
	// Repeat mode must be enabled in the following cases.
	// Case 1. A new configuration version is received and therefore infobase
  // update is required.
	//  - If Cancel = True, the operation cannot be continued because this can
  //    create duplicates of generated data items.
	//  - If Cancel = False, an error might occur during the infobase update
  //    and you might need to reimport the message. 
	// Case 2. Received configuration version is equal to the current
  // configuration version and therefore infobase update is not required.
	//  - If Cancel = True, an error might occur during the infobase startup,
  //    possible cause is that predefined items are not imported.
	//  - If Cancel = False, it is possible to continue because importing can
  //    be performed later (if importing fails, a new message for importing
  //    can be received later). 
	
	SetPrivilegedMode(True);
	
	If Not HasErrors Then
		
		DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart("ImportPermitted", False);
		
		// If the message is imported, reimporting is not required.
		If Constants.LoadDataExchangeMessage.Get() = True Then
			Constants.LoadDataExchangeMessage.Set(False);
		EndIf;
		Constants.RetryDataExchangeMessageImportBeforeStart.Set(False);
		
		Try
			DataExchangeServer.ExportMessageAfterInfobaseUpdate();
		Except
			// If exporting data fails, it is possible to start the 
     // application and export data in 1C:Enterprise mode.
		EndTry;
		
	ElsIf ConfigurationChanged() Then
		If Constants.LoadDataExchangeMessage.Get() = False Then
			Constants.LoadDataExchangeMessage.Set(True);
		EndIf;
		WarningText = NStr("en = 'Configuration changes are received from the master node. Configuration update is required.
			|Open Designer and update the infobase configuration.'");
	Else
		
		If InfobaseUpdate.InfobaseUpdateRequired() Then
			EnableDataExchangeMessageImportRecurrenceBeforeStart();
		EndIf;
		
		WarningText = NStr("en = 'Errors occurred when getting data from the master node.
			|For details, see the event log.'");
		
		DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart("ImportPermitted", False);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ImportDataExchangeMessageWithoutUpdating()
	
	Try
		ImportMessageBeforeInfobaseUpdate();
	Except
		WriteLogEvent(DataExchangeServer.EventLogMessageTextDataExchange(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		HasErrors = True;
	EndTry;
	
	SetFormItemRepresentation();
	
EndProcedure

&AtServer
Procedure ImportMessageBeforeInfobaseUpdate()
	
	If DataExchangeServerCall.DataExchangeMessageImportModeBeforeStart(
			"SkipDataExchangeMessageImportingBeforeStart") Then
		Return;
	EndIf;
	
	If GetFunctionalOption("UseDataSynchronization") = True Then
		
		If InfobaseNode <> Undefined Then
			
			SetPrivilegedMode(True);
			DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart("ImportPermitted", True);
			SetPrivilegedMode(False);
			
			// Updating object registration rules before importing data
			DataExchangeServer.UpdateDataExchangeRules();
			
			TransportKind = InformationRegisters.ExchangeTransportSettings.DefaultExchangeMessageTransportKind(InfobaseNode);
			
			ActionStartDate = CurrentSessionDate();
			
			DataExchangeServer.ExecuteDataExchangeForInfobaseNode(HasErrors, InfobaseNode, True, False, TransportKind,
				LongAction, ActionID, FileID, LongActionAllowed); // import only
			
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Scenario that includes infobase update

&AtClient
Procedure SynchronizeAndContinueWithInfobaseUpdate()
	
	ImportDataExchangeMessageWithUpdate();
	
	If LongAction Then
		
		AttachIdleHandler("LongActionIdleHandler", 5, True);
		
	Else
		
		SynchronizeAndContinueWithInfobaseUpdateCompletion();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SynchronizeAndContinueWithInfobaseUpdateCompletion()
	
	SetPrivilegedMode(True);
	
	If Not HasErrors Then
		
		DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart("ImportPermitted", False);
		
		If Constants.LoadDataExchangeMessage.Get() = False Then
			Constants.LoadDataExchangeMessage.Set(True);
		EndIf;
		
		DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart(
			"SkipMetadataObjectIDImportBeforeStart", True);
		
	ElsIf ConfigurationChanged() Then
			
		If Constants.LoadDataExchangeMessage.Get() = False Then
			Constants.LoadDataExchangeMessage.Set(True);
		EndIf;
		WarningText = NStr("en = 'Configuration changes are received from the master node. Configuration update is required.
			|Open Designer and update the infobase configuration.'");
		
	Else
		
		DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart("ImportPermitted", False);
		
		EnableDataExchangeMessageImportRecurrenceBeforeStart();
		
		WarningText = NStr("en = 'Errors occurred when getting data from the master node.
			|For details, see the event log.'");
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ImportDataExchangeMessageWithUpdate()
	
	Try
		MetadataObjectIDsInSubordinateDIBNodeBeforeCheck();
	Except
		WriteLogEvent(DataExchangeServer.EventLogMessageTextDataExchange(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		HasErrors = True;
	EndTry;
	
	SetFormItemRepresentation();
	
EndProcedure

&AtServer
Procedure MetadataObjectIDsInSubordinateDIBNodeBeforeCheck()
	
	If DataExchangeServerCall.DataExchangeMessageImportModeBeforeStart(
			"SkipDataExchangeMessageImportingBeforeStart") Then
		Return;
	EndIf;
	
	If DataExchangeServerCall.DataExchangeMessageImportModeBeforeStart(
			"SkipMetadataObjectIDImportBeforeStart") Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart("ImportPermitted", True);
	SetPrivilegedMode(False);
	
	CheckDataSynchronizationEnabled();
	
	If GetFunctionalOption("UseDataSynchronization") = True Then
		
		InfobaseNode = DataExchangeServer.MasterNode();
		
		If InfobaseNode <> Undefined Then
			
			TransportKind = InformationRegisters.ExchangeTransportSettings.DefaultExchangeMessageTransportKind(InfobaseNode);
			
			ActionStartDate = CurrentSessionDate();
			
			// Importing only application parameters
			DataExchangeServer.ExecuteDataExchangeForInfobaseNode(HasErrors, InfobaseNode, True,
				False, TransportKind, LongAction, ActionID, FileID, LongActionAllowed,, True);
			
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Scenario that does not include synchronization

&AtServer
Procedure NotSynchronizeAndContinueAtServer()
	
	SetPrivilegedMode(True);
	
	If Not InfobaseUpdate.InfobaseUpdateRequired() Then
		If Constants.LoadDataExchangeMessage.Get() = True Then
			Constants.LoadDataExchangeMessage.Set(False);
			DataExchangeServer.ClearDataExchangeMessageFromMasterNode();
		EndIf;
	EndIf;
	
	DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart(
		"SkipDataExchangeMessageImportingBeforeStart", True);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Procedure CheckUpdateRequired()
	
	SetPrivilegedMode(True);
	
	If ConfigurationChanged() Then
		UpdateStatus = "ConfigurationUpdate";
	ElsIf InfobaseUpdate.InfobaseUpdateRequired() Then
		UpdateStatus = "InfobaseUpdate";
	Else
		UpdateStatus = "NoUpdateRequired";
	EndIf;
	
EndProcedure

&AtClient
Procedure SynchronizeAndContinueCompletion()
	
	SetEnabled();
	
	If IsBlankString(WarningText) Then
		Close("Continue");
	Else
		ShowMessageBox(, WarningText);
	EndIf;
	
EndProcedure

// Sets the RetryDataExchangeMessageImportBeforeStart flag value to True.
// Clears exchange messages received from the master node.
//
Procedure EnableDataExchangeMessageImportRecurrenceBeforeStart()
	
	DataExchangeServer.ClearDataExchangeMessageFromMasterNode();
	
	Constants.RetryDataExchangeMessageImportBeforeStart.Set(True);
	
EndProcedure

&AtServer
Procedure SetEnabled()
	
	If DataExchangeServer.LoadDataExchangeMessage()
	   And InfobaseUpdate.InfobaseUpdateRequired() Then
		
		Items.NotSynchronizeAndContinueForm.Enabled = False;
		Items.NotSynchronizeInfoLabel.Enabled = False;
	Else
		Items.NotSynchronizeAndContinueForm.Enabled = True;
		Items.NotSynchronizeInfoLabel.Enabled = True;
	EndIf;
	
	SetFormItemRepresentation();
	
EndProcedure

&AtClient
Procedure LongActionIdleHandler()
	
	ActionState = DataExchangeServerCall.LongActionStateForInfobaseNode(
		ActionID,
		InfobaseNode,
		,
		WarningText);
	
	If ActionState = "Active" Then
		
		AttachIdleHandler("LongActionIdleHandler", 5, True);
		
	Else
		
		If ActionState <> "Completed" Then
			
			HasErrors = True;
			
		EndIf;
		
		LongAction = False;
		
		ProcessLongActionCompletion();
		
		If UpdateStatus = "NoUpdateRequired" Then
			
			SynchronizeAndContinueWithoutInfobaseUpdateCompletion();
			
		ElsIf UpdateStatus = "InfobaseUpdate" Then
			
			SynchronizeAndContinueWithInfobaseUpdateCompletion();
			
		EndIf;
		
		SynchronizeAndContinueCompletion();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure CheckDataSynchronizationEnabled()
	
	If GetFunctionalOption("UseDataSynchronization") = False Then
		
		If CommonUseCached.DataSeparationEnabled() Then
			
			UseDataSynchronization = Constants.UseDataSynchronization.CreateValueManager();
			UseDataSynchronization.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
			UseDataSynchronization.DataExchange.Load = True;
			UseDataSynchronization.Value = True;
			UseDataSynchronization.Write();
			
		Else
			
			If DataExchangeServer.GetUsedExchangePlans().Count() > 0 Then
				
				UseDataSynchronization = Constants.UseDataSynchronization.CreateValueManager();
				UseDataSynchronization.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
				UseDataSynchronization.DataExchange.Load = True;
				UseDataSynchronization.Value = True;
				UseDataSynchronization.Write();
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetFormItemRepresentation()
	
	Items.MainPanel.CurrentPage = ?(LongAction, Items.LongAction, Items.Beginning);
	Items.LongActionButtonGroup.Visible = LongAction;
	Items.MainButtonGroup.Visible = Not LongAction;
	
EndProcedure

&AtClient
Procedure ProcessLongActionCompletion()
	
	If Not HasErrors Then
		
		ExecuteDataExchangeForInfobaseNodeFinishLongAction(
			InfobaseNode,
			FileID,
			ActionStartDate);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ExecuteDataExchangeForInfobaseNodeFinishLongAction(
															Val InfobaseNode,
															Val FileID,
															Val ActionStartDate
	)
	
	DataExchangeServer.CheckCanSynchronizeData();
	
	DataExchangeServer.CheckUseDataExchange();
	
	SetPrivilegedMode(True);
	
	Try
		FileExchangeMessages = DataExchangeServer.GetFileFromStorageInService(New UUID(FileID), InfobaseNode);
	Except
		DataExchangeServer.AddExchangeFinishedWithErrorEventLogMessage(InfobaseNode,
			Enums.ActionsOnExchange.DataImport,
			ActionStartDate,
			DetailErrorDescription(ErrorInfo()));
			HasErrors = True;
		Return;
	EndTry;
	
	NewMessage = New BinaryData(FileExchangeMessages);
	DataExchangeServer.SetDataExchangeMessageFromMasterNode(NewMessage, InfobaseNode);
	
	Try
		DeleteFiles(FileExchangeMessages);
	Except
	EndTry;
	
	Try
		
		ParametersOnly = (UpdateStatus = "InfobaseUpdate");
		TransportKind = InformationRegisters.ExchangeTransportSettings.DefaultExchangeMessageTransportKind(InfobaseNode);
		
		DataExchangeServer.ExecuteDataExchangeForInfobaseNode(HasErrors, InfobaseNode,
			True, False, TransportKind,,,,,, ParametersOnly);
			
	Except
		
		WriteLogEvent(DataExchangeServer.EventLogMessageTextDataExchange(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		HasErrors = True;
		
	EndTry;
	
EndProcedure

#EndRegion