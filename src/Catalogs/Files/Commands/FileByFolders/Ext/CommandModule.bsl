

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	OpenForm(
		"Catalog.Files.Form.FilesByFolders",
		,
		CommandExecuteParameters.Source, 
		CommandExecuteParameters.Uniqueness, 
		CommandExecuteParameters.Window);
	
EndProcedure
