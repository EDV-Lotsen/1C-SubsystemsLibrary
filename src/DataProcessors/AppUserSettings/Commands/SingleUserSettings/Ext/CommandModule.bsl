&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure("User", CommandParameter);
	OpenForm("DataProcessor.AppUserSettings.Form.AppUserSettings", FormParameters, CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure
