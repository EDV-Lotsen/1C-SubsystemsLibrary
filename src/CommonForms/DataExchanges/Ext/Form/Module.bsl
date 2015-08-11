////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ExchangePlanList = DataExchangeCached.SLExchangePlanList();
	If ExchangePlanList.Count() = 0 Then
		MessageText = NStr("en = 'The data exchange setup is not supported.'");
			CommonUseClientServer.MessageToUser(MessageText,,,, Cancel);
		Return;
	EndIf;
	
	RefreshNodeStateList();
	
	IsInRoleAddEditDataExchanges = Users.RolesAvailable("AddEditDataExchanges");
	If IsInRoleAddEditDataExchanges Then
		AddCreateNewExchangeCommands();
	EndIf;
	
	Items.NodeStateListChangeInfoBaseNode.Visible = IsInRoleAddEditDataExchanges;
	Items.SetupExchangeExecutionSchedule.Visible  = IsInRoleAddEditDataExchanges;
	Items.SetupExchangeExecutionSchedule1.Visible = IsInRoleAddEditDataExchanges;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "DataExchangeCompleted"
	Or EventName = "Write_DataExchangeScenarios"
	Or EventName = "Write_ExchangePlanNode"
	Or EventName = "ObjectMappingWizardFormClosed"
	Or EventName = "DataExchangeCreationWizardFormClosed" Then
		
		// Updating monitor data
		RefreshMonitorData();
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENT HANDLERS OF NodeStateList TABLE 

&AtClient
Procedure NodeStateListChoice(Item, SelectedRow, Field, StandardProcessing)
	
	DataExchangeClient.ExecuteDataExchangeCommandProcessing(Items.NodeStateList.CurrentData.InfoBaseNode, ThisForm);
	
EndProcedure

&AtClient
Procedure NodeStateListOnActivateRow(Item)
	
	CurrentDataSet = Items.NodeStateList.CurrentData <> Undefined;
	
	Items.Setup.Enabled = CurrentDataSet;
	Items.NodeStateListChangeInfoBaseNode.Enabled = CurrentDataSet;
	
	Items.DataExchangeExecutionButtonGroup.Enabled = CurrentDataSet;
	Items.ContextMenuStateListDiagnostics.Enabled = CurrentDataSet;
	Items.ScheduleSettingsButtonGroup.Enabled = CurrentDataSet;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure ExecuteDataExchange(Command)
	
	CurrentData = Items.NodeStateList.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	DataExchangeClient.ExecuteDataExchangeCommandProcessing(CurrentData.InfoBaseNode, ThisForm);
	
EndProcedure

&AtClient
Procedure ExecuteDataExchangeInteractively(Command)
	
	CurrentData = Items.NodeStateList.CurrentData;
	DataExchangeClient.OpenObjectMappingWizardCommandProcessing(CurrentData.InfoBaseNode, ThisForm);
	
EndProcedure

&AtClient
Procedure SetUpDataExchangeScenarios(Command)
	
	CurrentData = Items.NodeStateList.CurrentData;
	DataExchangeClient.SetupExchangeExecutionScheduleCommandProcessing(CurrentData.InfoBaseNode, ThisForm);
	
EndProcedure

&AtClient
Procedure RefreshMonitor(Command)
	
	RefreshMonitorData();
	
EndProcedure

&AtClient
Procedure ChangeInfoBaseNode(Command)
	
	CurrentData = Items.NodeStateList.CurrentData;
	
	ShowValue(Undefined, CurrentData.InfoBaseNode);
	
EndProcedure

&AtClient
Procedure GoToDataImportEventLog(Command)
	
	CurrentData = Items.NodeStateList.CurrentData;
	
	DataExchangeClient.GoToDataEventLogModally(CurrentData.InfoBaseNode, ThisForm, "DataImport");
	
EndProcedure

&AtClient
Procedure GoToDataExportEventLog(Command)
	
	CurrentData = Items.NodeStateList.CurrentData;
	
	DataExchangeClient.GoToDataEventLogModally(CurrentData.InfoBaseNode, ThisForm, "DataExport");
	
EndProcedure

&AtClient
Procedure OpenDataExchangeSetupWizard(Command)
	
	DataExchangeClient.OpenDataExchangeSetupWizard(Command.Name);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtClient
Procedure RefreshMonitorData()
	
	NodeStateListRowIndex = GetCurrentRowIndex("NodeStateList");
	
	// Update monitor tables on the server
	RefreshNodeStateList();
	
	// Determining the cursor position
	MoveCursor("NodeStateList", NodeStateListRowIndex);
	
EndProcedure

&AtServer
Procedure RefreshNodeStateList()
	
	// Updating node state list data
	NodeStateList.Load(DataExchangeServer.DataExchangeMonitorTable(DataExchangeCached.SLExchangePlans()));
	
EndProcedure

&AtServer
Procedure AddCreateNewExchangeCommands()
	
	ExchangePlanList = DataExchangeCached.SLExchangePlanList();
	
	For Each Item In ExchangePlanList Do
		
		ExchangePlanName = Item.Value;
		
		ExchangePlanManager = ExchangePlans[ExchangePlanName];
		
		If ExchangePlanManager.UseDataExchangeCreationWizard() 
			And DataExchangeCached.CanUseExchangePlan(ExchangePlanName) Then
			
			Commands.Add(ExchangePlanName);
			Commands[ExchangePlanName].Title = ExchangePlanManager.NewDataExchangeCreationCommandTitle();
			Commands[ExchangePlanName].Action  = "OpenDataExchangeSetupWizard";
			
			Items.Add(ExchangePlanName, Type("FormButton"), Items.SubmenuCreate);
			Items[ExchangePlanName].CommandName = ExchangePlanName;
			
			If ExchangePlanManager.ExchangePlanUsedInServiceMode()
				And Not Metadata.ExchangePlans[ExchangePlanName].DistributedInfoBase Then
				
				CommandName = "[ExchangePlanName]ExchangePlanUsedInServiceMode";
				CommandName = StrReplace(CommandName, "[ExchangePlanName]", ExchangePlanName);
				
				Commands.Add(CommandName);
				Commands[CommandName].Title = ExchangePlanManager.NewDataExchangeCreationCommandTitle() + NStr("en = ' (in the service mode)'");
				Commands[CommandName].Action  = "OpenDataExchangeSetupWizard";
				
				Items.Add(CommandName, Type("FormButton"), Items.SubmenuCreate);
				Items[CommandName].CommandName = CommandName;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Function GetCurrentRowIndex(TableName)
	
	// Return value
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
	
	// Moving the cursor to the first row if determining the cursor position failed.
	If Items[TableName].CurrentRow = Undefined
		And ThisForm[TableName].Count() <> 0 Then
		
		Items[TableName].CurrentRow = ThisForm[TableName][0].GetID();
		
	EndIf;
	
EndProcedure







