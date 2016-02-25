
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
  // Skipping the initialization to guarantee that the form will be
  // received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	If Not Users.InfobaseUserWithFullAccess(Undefined, True, False) Then
		Raise NStr("en = 'Not enough rights for data exchange administration.'");
	EndIf;
	
	SetPrivilegedMode(True);
	
	RefreshNodeStateList();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

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
Procedure RefreshNodeStateList()
	
	NodeStateList.Clear();
	
	NodeStateList.Load(
		DataExchangeSaaS.DataExchangeMonitorTable(DataExchangeCached.SeparatedSLExchangePlans()));
	
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
	
	Items.NodeStateListLastSuccessfulExportDate.Visible = Items.DetailedNodeStateList.Check;
	Items.NodeStateListLastSuccessfulImportDate.Visible = Items.DetailedNodeStateList.Check;
	Items.NodeStateListExchangePlanName.Visible = Items.DetailedNodeStateList.Check;
	
EndProcedure

#EndRegion
