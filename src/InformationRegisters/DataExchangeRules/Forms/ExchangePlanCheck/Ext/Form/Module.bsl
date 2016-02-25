#Region FormCommandHandlers

&AtClient
Procedure GoToList(Command)
	FormParameters = New Structure;
	FormParameters.Insert("ExchangePlansWithRulesFromFile", True);
	
	OpenForm("InformationRegister.DataExchangeRules.Form.ListForm", FormParameters);
EndProcedure

&AtClient
Procedure CloseForm(Command)
	Close();
EndProcedure

&AtClient
Procedure Checked(Command)
	MarkTaskDone();
	Close();
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure MarkTaskDone()
	
	VersionArray  = StringFunctionsClientServer.SplitStringIntoSubstringArray(Metadata.Version, ".");
	CurrentVersion = VersionArray[0] + VersionArray[1] + VersionArray[2];
	CommonSettingsStorage.Save("ToDoList", "ExchangePlans", CurrentVersion);
	
EndProcedure

#EndRegion