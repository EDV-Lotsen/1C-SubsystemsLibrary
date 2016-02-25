
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	// Server call
	ExchangePlanName = ExchangePlanName(CommandParameter);
	
	// Server call
	RuleKind = PredefinedValue("Enum.DataExchangeRuleKinds.ObjectChangeRecordRules");
	
	Filter        = New Structure("ExchangePlanName, RuleKind", ExchangePlanName, RuleKind);
	FillingValues = New Structure("ExchangePlanName, RuleKind", ExchangePlanName, RuleKind);
	
	DataExchangeClient.OpenInformationRegisterRecordFormByFilter(Filter, FillingValues, "DataExchangeRules", CommandExecuteParameters.Source, "ObjectChangeRecordRules");
	
EndProcedure

&AtServer
Function ExchangePlanName(Val InfobaseNode)
	
	Return DataExchangeCached.GetExchangePlanName(InfobaseNode);
	
EndFunction

#EndRegion
