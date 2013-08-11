////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If CommonUseCached.DataSeparationEnabled()
		And CommonUseCached.CanUseSeparatedData() Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Subsystem setup in the separated mode is not supported.'"),,,, Cancel
		);
		Return;
	EndIf;
	
	RefreshNodeStateList();
	
	SetPrivilegedMode(True);
	ScheduledJob = ScheduledJobs.FindPredefined(Metadata.ScheduledJobs.SendReceiveSystemMessages);
	SetPrivilegedMode(False);
	
	ScheduledJobID = String(ScheduledJob.UUID);
	
	UseScheduledJob = ScheduledJob.Use;
	
	Items.NodeStateListEnableDisableSendReceiveSystemMessagesSchedule.Check = UseScheduledJob;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = MessageExchangeClient.SendReceiveEmailExecutedEventName()
		Or EventName = MessageExchangeClient.EndPointFormClosedEventName()
		Or EventName = MessageExchangeClient.EndPointAddedEventName()
		Or EventName = MessageExchangeClient.EventNameLeadingEndPointSet()
		Then
		
		RefreshMonitorData();
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure NodeStateListChoice(Item, SelectedRow, Field, StandardProcessing)
	
	ChangeEndPoint(Undefined);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure ConnectEndPoint(Command)
	
	OpenForm("CommonForm.ConnectEndPoint",, ThisForm, 1);
	
EndProcedure

&AtClient
Procedure SetupSubscriptions(Command)
	
	OpenForm("InformationRegister.RecipientSubscriptions.Form.ThisEndPointSubscriptionSetup",, ThisForm);
	
EndProcedure

&AtClient
Procedure SendAndReceiveMessages(Command)
	
	MessageExchangeClient.SendAndReceiveMessages();
	
EndProcedure

&AtClient
Procedure ChangeEndPoint(Command)
	
	CurrentData = Items.NodeStateList.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpenValue(CurrentData.InfoBaseNode);
	
EndProcedure

&AtClient
Procedure GoToDataExportEventLog(Command)
	
	CurrentData = Items.NodeStateList.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	DataExchangeClient.GoToDataEventLogModally(CurrentData.InfoBaseNode, ThisForm, "DataExport");
	
EndProcedure

&AtClient
Procedure GoToDataImportEventLog(Command)
	
	CurrentData = Items.NodeStateList.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	DataExchangeClient.GoToDataEventLogModally(CurrentData.InfoBaseNode, ThisForm, "DataImport");
	
EndProcedure

&AtClient
Procedure SetupSystemMessageSendReceiveSchedule(Command)
	
	Dialog = New ScheduledJobDialog(ScheduledJobsClient.GetJobSchedule(ScheduledJobID));
	
	If Dialog.DoModal() Then
		
		ScheduledJobsClient.SetJobSchedule(ScheduledJobID, Dialog.Schedule);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EnableDisableSendReceiveSystemMessagesSchedule(Command)
	
	UseScheduledJob = Not UseScheduledJob;
	
	ScheduledJobsServer.SetScheduledJobUse(ScheduledJobID, UseScheduledJob);
	
	Items.NodeStateListEnableDisableSendReceiveSystemMessagesSchedule.Check = UseScheduledJob;
	
EndProcedure

&AtClient
Procedure RefreshMonitor(Command)
	
	RefreshMonitorData();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Procedure RefreshNodeStateList()
	
	Array = New Array;
	Array.Add("MessageExchange");
	
	// Updating data in the node state list
	NodeStateList.Load(DataExchangeServer.DataExchangeMonitorTable(Array, "Leading"));
	
EndProcedure

&AtClient
Procedure RefreshMonitorData()
	
	NodeStateListRowIndex = GetCurrentRowIndex("NodeStateList");
	
	// Updating the node state list on the server
	RefreshNodeStateList();
	
	// Determining the cursor position
	MoveCursor("NodeStateList", NodeStateListRowIndex);
	
EndProcedure

&AtClient
Function GetCurrentRowIndex(TableName)
	
	// The return value
	RowIndex = Undefined;
	
	// Determining the cursor position during the monitor update
	CurrentData = Items[TableName].CurrentData;
	
	If CurrentData <> Undefined Then
		
		RowIndex = ThisForm[TableName].IndexOf(CurrentData);
		
	EndIf;
	
	Return RowIndex;
EndFunction

&AtClient
Procedure MoveCursor(TableName, RowIndex)
	
	If RowIndex <> Undefined Then
		
		// Checking the cursor position once new data is received
		If ThisForm[TableName].Count() <> 0 Then
			
			If RowIndex > ThisForm[TableName].Count() - 1 Then
				
				RowIndex = ThisForm[TableName].Count() - 1;
				
			EndIf;
			
			// Determining the cursor position
			Items[TableName].CurrentRow = ThisForm[TableName][RowIndex].GetID();
			
		EndIf;
		
	EndIf;
	
EndProcedure







