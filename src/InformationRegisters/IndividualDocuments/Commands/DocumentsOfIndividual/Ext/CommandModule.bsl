

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure("Filter", New Structure("Individual", CommandParameter));
	OpenForm("InformationRegister.IndividualDocuments.Form.DocumentsOfIndividual", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure
