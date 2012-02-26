

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	 OpenForm("Catalog.Files.ListForm", 
	 	, 
		CommandExecuteParameters.Source, 
		CommandExecuteParameters.Uniqueness, 
		CommandExecuteParameters.Window);
EndProcedure
