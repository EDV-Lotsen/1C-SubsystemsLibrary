#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("ExchangePlansWithRulesFromFile") Then
		
		Items.RuleSource.Visibility = False;
		CommonUseClientServer.SetDynamicListFilterItem(
			List,
			"RuleSource",
			Enums.DataExchangeRuleSources.File,
			DataCompositionComparisonType.Equal);
		
	EndIf;
	
	CommonUseClientServer.MoveFiltersToDynamicList(ThisObject);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure UpdateAllStandardRules(Command)
	
	UpdateAllStandardRulesAtServer();
	Items.List.Refresh();
	
	ShowUserNotification(NStr("en = 'The rule update is completed.'"));
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure UpdateAllStandardRulesAtServer()
	
	DataExchangeServer.UpdateDataExchangeRules();
	
	RefreshReusableValues();
	
EndProcedure

&AtClient
Procedure UseStandardRules(Command)
	UseStandardRulesAtServer();
	Items.List.Refresh();
	ShowUserNotification(NStr("en = The rule update is completed.'"));
EndProcedure

&AtServer
Procedure UseStandardRulesAtServer()
	
	For Each Write In Items.List.SelectedRows Do
		RecordManager = InformationRegisters.DataExchangeRules.CreateRecordManager();
		FillPropertyValues(RecordManager, Write);
		RecordManager.Read();
		RecordManager.RuleSource = Enums.DataExchangeRuleSources.ConfigurationTemplate;
		HasErrors = False;
		InformationRegisters.DataExchangeRules.ImportRules(HasErrors, RecordManager);
		If Not HasErrors Then
			RecordManager.Write();
		EndIf;
	EndDo;
	
	DataExchangeServerCall.ResetObjectChangeRecordMechanismCache();
	RefreshReusableValues();
	
EndProcedure

#EndRegion
