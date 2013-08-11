////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Filter = New Structure("Recipient", CommandParameter);
	
	FormParameters = New Structure("Filter", Filter);
	
	OpenForm("InformationRegister.SenderSettings.ListForm", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure
