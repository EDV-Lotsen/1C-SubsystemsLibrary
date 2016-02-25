
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm("Catalog.Companies.ObjectForm", GetFormOpeningParameters());
	
EndProcedure

&AtServer
Function GetFormOpeningParameters()
	
	Return New Structure("Key", Catalogs.Companies.DefaultCompany());
	
EndFunction
