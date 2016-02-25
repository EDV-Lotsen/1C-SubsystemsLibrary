
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm("DataProcessor.AppUserSettings.Form.ClearAppUserSettings", , CommandExecuteParameters.Source,
			CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure
