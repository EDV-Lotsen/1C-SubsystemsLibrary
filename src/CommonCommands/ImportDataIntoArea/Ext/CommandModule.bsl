
////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS 

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm("CommonForm.ImportDataIntoArea", , CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure

