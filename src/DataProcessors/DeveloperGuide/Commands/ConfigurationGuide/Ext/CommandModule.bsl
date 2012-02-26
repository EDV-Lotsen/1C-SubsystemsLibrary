
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	FormParameters = New Structure("", );
	OpenForm("DataProcessor.DeveloperGuide.Form", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
EndProcedure
