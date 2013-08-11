////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm("CommonForm.DataExchangeExecutionWithAllInfoBases",, CommandExecuteParameters.Source, 1);
	
EndProcedure



