////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	// Calling the server
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(CommandParameter);
	
	// Calling the server
	RuleKind = PredefinedValue("Enum.DataExchangeRuleKinds.ObjectConversionRules");
	
	Filter        = New Structure("ExchangePlanName, RuleKind", ExchangePlanName, RuleKind);
	FillingValues = New Structure("ExchangePlanName, RuleKind", ExchangePlanName, RuleKind);
	
	DataExchangeClient.OpenInformationRegisterRecordFormByFilter(Filter, FillingValues, "DataExchangeRules", CommandExecuteParameters.Source);
	
EndProcedure
