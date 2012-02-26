
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm(
		"Catalog.Files.Form.OpenedForEditingFiles",
		,
		CommandExecuteParameters.Source, 
		CommandExecuteParameters.Uniqueness, 
		CommandExecuteParameters.Window);
	
EndProcedure
