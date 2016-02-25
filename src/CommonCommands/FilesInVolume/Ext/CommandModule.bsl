////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS 

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure;
	FormParameters.Insert("Volume", CommandParameter);
	
	OpenForm("CommonForm.FilesInVolume",
	         FormParameters,
	         CommandExecuteParameters.Source,
	         CommandExecuteParameters.Uniqueness,
	         CommandExecuteParameters.Window);
	
EndProcedure
