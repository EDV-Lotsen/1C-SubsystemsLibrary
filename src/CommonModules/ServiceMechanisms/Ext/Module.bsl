
// Function prepares the list of parameters to use on system start
Function GetParameters() Export
	
	Parameters = New Structure;
	Parameters.Insert("ShortCaption", HandlingCommonSettingsStorage.GetShortApplicationTitleText());
	
	Return Parameters;
	
EndFunction
