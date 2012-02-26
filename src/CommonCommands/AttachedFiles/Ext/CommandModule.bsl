

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	Parameters = New Structure;
	Parameters.Insert("FileOwner", CommandParameter);
	Title = NStr("en = 'Attached files'");
	Parameters.Insert("FormTitle", Title);
	
	OpenForm(
		"Catalog.Files.Form.AttachedFilesListForm", 
		Parameters,
		CommandExecuteParameters.Source, 
		CommandExecuteParameters.Uniqueness, 
		CommandExecuteParameters.Window);
		
EndProcedure
