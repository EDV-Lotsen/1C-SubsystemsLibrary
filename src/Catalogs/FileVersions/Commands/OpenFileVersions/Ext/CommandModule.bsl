

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure("File", CommandParameter);
	OpenForm("Catalog.FileVersions.Form.FileVersionsListForm", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure
