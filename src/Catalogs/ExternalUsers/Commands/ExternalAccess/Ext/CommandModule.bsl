
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FoundExternalUser = Undefined;
	FormParameters = New Structure;
	CanAddExternalUser = False;
	
	If ExternalUsers.AuthorizationObjectUsed(CommandParameter, , FoundExternalUser, CanAddExternalUser) Then
		FormParameters.Insert("Key", FoundExternalUser);
	ElsIf CanAddExternalUser Then
		FormParameters.Insert("NewExternalUserAuthorizationObject", CommandParameter);
	Else
		DoMessageBox(NStr("en = 'Access to the infobase is denied.'"));
		Return;
	EndIf;
	
	OpenForm("Catalog.ExternalUsers.ObjectForm", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure
