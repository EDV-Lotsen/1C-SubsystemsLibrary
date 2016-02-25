
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm("DataProcessor.AppUserSettings.Form.CopyAppUserSettings", , CommandExecuteParameters.Source,
			CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure
