
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
 
  // Skipping the initialization to guarantee that the form will be
  // received if the Autotest parameter is passed.	
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	// Only users with full access rights can create and disable standalone workstations.
	If Not Users.InfobaseUserWithFullAccess() Then
		
		Raise NStr("en = 'Insufficient rights for standalone mode setup.'");
		
	ElsIf Not StandaloneModeInternal.StandaloneModeSupported() Then
		
		Raise NStr("en = 'Standalone mode is not supported.'");
		
	EndIf;
	
	UpdateStandaloneModeMonitorAtServer();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	AttachIdleHandler("UpdateStandaloneWorkstationMonitor", 60);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If    EventName = "Create_StandaloneWorkstation"
		OR EventName = "Write_StandalonWorkstation"
		OR EventName = "Delete_StandaloneWorkstation" Then
		
		UpdateStandaloneWorkstationMonitor();
		
	ElsIf EventName = "DataExchangeResultFormClosed" Then
		
		UpdateGoToConflictTitle();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure CreateStandaloneWorkstation(Command)
	
	OpenForm("DataProcessor.StandaloneWorkstationGenerationWizard.Form.SaaSSetup",, ThisObject, "1");
	
EndProcedure

&AtClient
Procedure StopSynchronizationWithStandaloneWorkstation(Command)
	
	DisconnectStandaloneWorkstation(StandaloneWorkstation);
	
EndProcedure

&AtClient
Procedure StopSynchronizationWithStandaloneWorkstationInList(Command)
	
	CurrentData = Items.StandaloneWorkstationList.CurrentData;
	
	If CurrentData <> Undefined Then
		
		DisconnectStandaloneWorkstation(CurrentData.StandaloneWorkstation);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeStandaloneWorkstation(Command)
	
	If StandaloneWorkstation <> Undefined Then
		
		ShowValue(, StandaloneWorkstation);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeStandaloneWorkstationInList(Command)
	
	CurrentData = Items.StandaloneWorkstationList.CurrentData;
	
	If CurrentData <> Undefined Then
		
		ShowValue(, CurrentData.StandaloneWorkstation);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Refresh(Command)
	
	UpdateStandaloneWorkstationMonitor();
	
EndProcedure

&AtClient
Procedure StandaloneWorkstationListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	ShowValue(, Items.StandaloneWorkstationList.CurrentData.StandaloneWorkstation);
	
EndProcedure

&AtClient
Procedure HowToInstallOrUpdate1CEnterprisePlatfomVersion(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("TemplateName", "HowToInstallOrUpdate1CEnterprisePlatfomVersion");
	FormParameters.Insert("Title", NStr("en = 'How to install or update 1C:Enterprise platform'"));
	
	OpenForm("DataProcessor.StandaloneWorkstationGenerationWizard.Form.AdditionalDetails", FormParameters, ThisObject, "HowToInstallOrUpdate1CEnterprisePlatfomVersion");
	
EndProcedure

&AtClient
Procedure HowToSetUpStandaloneWorkstation(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("TemplateName", "StandaloneWorkstationSetupInstruction");
	FormParameters.Insert("Title", NStr("en = 'How to set up a standalone workstation'"));
	
	OpenForm("DataProcessor.StandaloneWorkstationGenerationWizard.Form.AdditionalDetails", FormParameters, ThisObject, "StandaloneWorkstationSetupInstruction");
	
EndProcedure

&AtClient
Procedure GoToConflicts(Command)
	
	OpenParameters = New Structure;
	OpenParameters.Insert("ExchangeNodes", UsedNodeArray(StandaloneWorkstation, StandaloneWorkstationList));
	
	OpenForm("InformationRegister.DataExchangeResults.Form.Form", OpenParameters);
	
EndProcedure

&AtClient
Procedure SentDataContent(Command)
	
	CurrentPage = Items.StandaloneMode.CurrentPage;
	StandaloneNode  = Undefined;
	
	If CurrentPage = Items.SingleStandaloneWorkstation Then
		StandaloneNode = StandaloneWorkstation;
		
	ElsIf CurrentPage = Items.MultipleStandaloneWorkstations Then
		CurrentData = Items.StandaloneWorkstationList.CurrentData;
		If CurrentData <> Undefined Then
			StandaloneNode = CurrentData.StandaloneWorkstation;
		EndIf;
		
	EndIf;
		
	If ValueIsFilled(StandaloneNode) Then
		DataExchangeClient.OpenSentDataContent(StandaloneNode);
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure UpdateStandaloneModeMonitorAtServer()
	
	SetPrivilegedMode(True);
	
	StandaloneWorkstationNumber = StandaloneModeInternal.StandaloneWorkstationNumber();
	UpdateGoToConflictTitle();
	
	If StandaloneWorkstationNumber = 0 Then
		
		Items.StandaloneModeNotSetUp.Visible = True;
		
		Items.StandaloneMode.CurrentPage = Items.StandaloneModeNotSetUp;
		Items.SingleStandaloneWorkstation.Visible = False;
		Items.MultipleStandaloneWorkstations.Visible = False;
		
	ElsIf StandaloneWorkstationNumber = 1 Then
		
		Items.SingleStandaloneWorkstation.Visible = True;
		
		Items.StandaloneMode.CurrentPage = Items.SingleStandaloneWorkstation;
		Items.StandaloneModeNotSetUp.Visible = False;
		Items.MultipleStandaloneWorkstations.Visible = False;
		
		StandaloneWorkstation = StandaloneModeInternal.StandaloneWorkstation();
		StandaloneWorkstationList.Clear();
		
		Items.LastSynchronizationInformation.Title = DataExchangeServer.SynchronizationDatePresentation(
			StandaloneModeInternal.LastDoneSynchronizationDate(StandaloneWorkstation)
		) + ".";
		
		Items.DataTransferRestrictionDetails.Title = StandaloneModeInternal.DataTransferRestrictionDetails(StandaloneWorkstation);
		
	ElsIf StandaloneWorkstationNumber > 1 Then
		
		Items.MultipleStandaloneWorkstations.Visible = True;
		
		Items.StandaloneMode.CurrentPage = Items.MultipleStandaloneWorkstations;
		Items.StandaloneModeNotSetUp.Visible = False;
		Items.SingleStandaloneWorkstation.Visible = False;
		
		StandaloneWorkstation = Undefined;
		StandaloneWorkstationList.Load(StandaloneModeInternal.StandaloneWorkstationMonitor());
		
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateGoToConflictTitle()
	
	If DataExchangeCached.VersioningUsed() Then
		
		TitleStructure = DataExchangeServer.IssueMonitorHyperlinkTitleStructure(
			UsedNodeArray(StandaloneWorkstation, StandaloneWorkstationList));
		
		FillPropertyValues (Items.GoToConflicts, TitleStructure);
		FillPropertyValues (Items.GoToConflicts1, TitleStructure);
		
	Else
		
		Items.GoToConflicts.Visible  = False;
		Items.GoToConflicts1.Visible = False;
		
	EndIf;
	
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
	
	// If setting the current row by TableName value failed, the first row is set as the current one
	If Items[TableName].CurrentRow = Undefined
		And ThisObject[TableName].Count() <> 0 Then
		
		Items[TableName].CurrentRow = ThisObject[TableName][0].GetID();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateStandaloneWorkstationMonitor()
	
	LineIndex = GetCurrentRowIndex("StandaloneWorkstationList");
	
	UpdateStandaloneModeMonitorAtServer();
	
	// Specifying the cursor position
	MoveCursor("StandaloneWorkstationList", LineIndex);
	
EndProcedure

&AtClientAtServerNoContext
Function UsedNodeArray(StandaloneWorkstation, StandaloneWorkstationList)
	
	ExchangeNodes = New Array;
	
	If ValueIsFilled(StandaloneWorkstation) Then
		ExchangeNodes.Add(StandaloneWorkstation);
	Else
		For Each NodeRow In StandaloneWorkstationList Do
			ExchangeNodes.Add(NodeRow.StandaloneWorkstation);
		EndDo;
	EndIf;
	
	Return ExchangeNodes;
	
EndFunction

&AtClient
Procedure DisconnectStandaloneWorkstation(SwitchableStandaloneWorkstation)
	
	FormParameters = New Structure("StandaloneWorkstation", SwitchableStandaloneWorkstation);
	
	OpenForm("CommonForm.StandaloneWorkstationDisconnection", FormParameters, ThisObject, SwitchableStandaloneWorkstation);
	
EndProcedure

#EndRegion
