

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	// Insert handler content.
	FormParameters = New Structure("User", CommandParameter);
	OpenForm("InformationRegister.UsersSettings.Form.UserConfigurationForm", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure // CommandProcessing()
