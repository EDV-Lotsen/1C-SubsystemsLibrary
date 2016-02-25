
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	If CommonUseCached.DataSeparationEnabled()
		And CommonUseCached.CanUseSeparatedData() Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Subsystem setup is not supported on the share mode.'"),,,, Cancel);
		Return;
	EndIf;
	
	RefreshNodeStateList();
	
	SetPrivilegedMode(True);
	
	Items.NodeStateListEnableDisableSendReceiveSystemMessagesSchedule.Check =
		ScheduledJobsServer.GetScheduledJobUse(
			Metadata.ScheduledJobs.SendReceiveSystemMessages);;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If    EventName = MessageExchangeClient.EventNameSendAndReceiveMessageExecuted()
		Or EventName = MessageExchangeClient.EndpointFormClosedEventName()
		Or EventName = MessageExchangeClient.EndpointAddedEventName()
		Or EventName = MessageExchangeClient.EventNameLeadingEndpointSet()
		Then
		
		RefreshMonitorData();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure NodeStateListChoice(Item, SelectedRow, Field, StandardProcessing)
	
	ChangeEndpoint(Undefined);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ConnectEndpoint(Command)
	
	OpenForm("CommonForm.ConnectEndpoint",, ThisObject, 1);
	
EndProcedure

&AtClient
Procedure SetupSubscriptions(Command)
	
	OpenForm("InformationRegister.RecipientSubscriptions.Form.ThisEndpointSubscriptionSetup",, ThisObject);
	
EndProcedure

&AtClient
Procedure SendAndReceiveMessages(Command)
	
	MessageExchangeClient.SendAndReceiveMessages();
	
EndProcedure

&AtClient
Procedure ChangeEndpoint(Command)
	
	CurrentData = Items.NodeStateList.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	ShowValue(, CurrentData.InfobaseNode);
	
EndProcedure

&AtClient
Procedure GoToDataExportEventLog(Command)
	
	CurrentData = Items.NodeStateList.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	DataExchangeClient.GoToDataEventLogModally(CurrentData.InfobaseNode, ThisObject, "DataExport");
	
EndProcedure

&AtClient
Procedure GoToDataImportEventLog(Command)
	
	CurrentData = Items.NodeStateList.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	DataExchangeClient.GoToDataEventLogModally(CurrentData.InfobaseNode, ThisObject, "DataImport");
	
EndProcedure

&AtClient
Procedure SetSystemMessageSendReceiveSchedule(Command)
	
	Dialog = New ScheduledJobDialog(GetSchedule());
	NotifyDescription = New NotifyDescription("SetSendReceiveSystemMessagesSchedule", ThisObject);
	Dialog.Show(NotifyDescription);
	
EndProcedure

&AtClient
Procedure SetSendReceiveSystemMessagesSchedule(Schedule, AdditionalParameters) Export
	
	If Schedule <> Undefined Then
		
		SetSchedule(Schedule);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EnableDisableSendReceiveSystemMessagesSchedule(Command)
	
	EnableDisableSendReceiveSystemMessagesScheduleAtServer();
	
EndProcedure

&AtClient
Procedure RefreshMonitor(Command)
	
	RefreshMonitorData();
	
EndProcedure

&AtClient
Procedure Detailed(Command)
	
	DetailedAtServer();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure EnableDisableSendReceiveSystemMessagesScheduleAtServer()
	
	SetPrivilegedMode(True);
	
	Items.NodeStateListEnableDisableSendReceiveSystemMessagesSchedule.Check =
		Not ScheduledJobsServer.GetScheduledJobUse(
			Metadata.ScheduledJobs.SendReceiveSystemMessages);
	
	ScheduledJobsServer.SetUseScheduledJob(
		Metadata.ScheduledJobs.SendReceiveSystemMessages,
		Items.NodeStateListEnableDisableSendReceiveSystemMessagesSchedule.Check);

EndProcedure

&AtServerNoContext
Function GetSchedule()
	
	SetPrivilegedMode(True);
	
	Return ScheduledJobsServer.GetJobSchedule(
		Metadata.ScheduledJobs.SendReceiveSystemMessages);
	
EndFunction

&AtServerNoContext
Procedure SetSchedule(Val Schedule)
	
	SetPrivilegedMode(True);
	
	ScheduledJobsServer.SetJobSchedule(
		Metadata.ScheduledJobs.SendReceiveSystemMessages,
		Schedule);
	
EndProcedure

&AtServer
Procedure RefreshNodeStateList()
	
	NodeStateList.Clear();
	
	Array = New Array;
	Array.Add("MessageExchange");
	
	MonitorDataExchange = DataExchangeServer.DataExchangeMonitorTable(Array, "Leading,Locked");
	
	// Updating data in the list of node states
	For Each Settings In MonitorDataExchange Do
		
		If Settings.Locked Then
			Continue;
		EndIf;
		
		FillPropertyValues(NodeStateList.Add(), Settings);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure RefreshMonitorData()
	
	NodeStateListRowIndex = GetCurrentRowIndex("NodeStateList");
	
	// Updating monitor tables on the server
	RefreshNodeStateList();
	
	// Specifying the cursor position
	MoveCursor("NodeStateList", NodeStateListRowIndex);
	
EndProcedure

&AtClient
Function GetCurrentRowIndex(TableName)
	
	// Return value
	LineIndex = Undefined;
	
	// Specifying the cursor position during the monitor update
	CurrentData = Items[TableName].CurrentData;
	
	If CurrentData <> Undefined Then
		
		LineIndex = ThisObject[TableName].IndexOf(CurrentData);
		
	EndIf;
	
	Return LineIndex;
EndFunction

&AtClient
Procedure MoveCursor(TableName, LineIndex)
	
	If LineIndex <> Undefined Then
		
		// Checking the cursor position once new data is received
		If ThisObject[TableName].Count() <> 0 Then
			
			If LineIndex > ThisObject[TableName].Count() - 1 Then
				
				LineIndex = ThisObject[TableName].Count() - 1;
				
			EndIf;
			
			// Specifying the cursor position
			Items[TableName].CurrentRow = ThisObject[TableName][LineIndex].GetID();
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure DetailedAtServer()
	
	Items.DetailedNodeStateList.Check = Not Items.DetailedNodeStateList.Check;
	
	Items.NodeStateListLastImportDate.Visible = Items.DetailedNodeStateList.Check;
	Items.NodeStateListLastExportDate.Visible = Items.DetailedNodeStateList.Check;
	
EndProcedure

#EndRegion
