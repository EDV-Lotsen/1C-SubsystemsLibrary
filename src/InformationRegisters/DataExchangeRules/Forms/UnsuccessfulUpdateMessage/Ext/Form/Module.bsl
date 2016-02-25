
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	ExchangePlanName = Parameters.ExchangePlanName;
	ExchangePlanSynonym = Metadata.ExchangePlans[ExchangePlanName].Synonym;
	
	ObjectConversionRules = Enums.DataExchangeRuleKinds.ObjectConversionRules;
	ObjectChangeRecordRules = Enums.DataExchangeRuleKinds.ObjectChangeRecordRules;
	
	WriteLogEvent(InfobaseUpdate.EventLogMessageText(), EventLogLevel.Error,,,
		Parameters.DetailedErrorMessage);
		
	ErrorMessage = Items.ErrorMessageText.Title;
	ErrorMessage = StrReplace(ErrorMessage, "%2", Parameters.BriefErrorMessage);
	ErrorMessage = StrReplaceWithFormalization(ErrorMessage, "%1", ExchangePlanSynonym);
	Items.ErrorMessageText.Title = ErrorMessage;
	
	RulesFromFile = InformationRegisters.DataExchangeRules.RulesFromFileUsed(ExchangePlanName, True);
	
	If RulesFromFile.ConversionRules And RulesFromFile.RecordRules Then
		RuleType = NStr("en = 'conversion and registration'");
	ElsIf RulesFromFile.ConversionRules Then
		RuleType = NStr("en = 'conversion'");
	ElsIf RulesFromFile.RecordRules Then
		RuleType = NStr("en = 'registration'");
	EndIf;
	
	Items.RuleTextFromFile.Title = StringFunctionsClientServer.SubstituteParametersInString(
		Items.RuleTextFromFile.Title, ExchangePlanSynonym, RuleType);
	
	UpdateStartTime = Parameters.UpdateStartTime;
	If Parameters.UpdateEndTime = Undefined Then
		UpdateEndTime = CurrentSessionDate();
	Else
		UpdateEndTime = Parameters.UpdateEndTime;
	EndIf;
	
	Items.ImportConversionRules.Visible = RulesFromFile.ConversionRules;
	Items.ImportRecordRules.Visible = RulesFromFile.RecordRules;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ExitCommand(Command)
	Close(True);
EndProcedure

&AtClient
Procedure GoToEventLog(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("StartDate", UpdateStartTime);
	FormParameters.Insert("EndDate", UpdateEndTime);
	FormParameters.Insert("ExecuteNotInBackground", True);
	
	OpenForm("DataProcessor.EventLog.Form.EventLog", FormParameters);
	
EndProcedure

&AtClient
Procedure Restart(Command)
	Close(False);
EndProcedure

&AtClient
Procedure ImportRuleSet(Command)
	
	DataExchangeClient.ImportDataSynchronizationRules(ExchangePlanName);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Function StrReplaceWithFormalization(String, SearchSubstring, ReplaceSubstring)
	
	StartPosition = Find(String, SearchSubstring);
	
	StringsArray = New Array;
	
	StringsArray.Add(Left(String, StartPosition - 1));
	StringsArray.Add(New FormattedString(ReplaceSubstring, New Font(,,True)));
	StringsArray.Add(Mid(String, StartPosition + StrLen(SearchSubstring)));
	
	Return New FormattedString(StringsArray);
	
EndFunction

#EndRegion