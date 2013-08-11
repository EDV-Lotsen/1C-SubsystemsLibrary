////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure("InfoBaseNode", CommandParameter);
	OpenForm("Catalog.DataExchangeScenarios.Form.DataExchangeScheduleSetup", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure
