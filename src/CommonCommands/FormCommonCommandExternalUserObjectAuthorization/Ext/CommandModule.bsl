

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FoundExternalUser = Undefined;
	FormParameters = New Structure;
	IsRightToAddExternalUser = False;
	
	If ExternalUsers.AuthorizationObjectLinkedToExternalUser(CommandParameter, , FoundExternalUser, IsRightToAddExternalUser) Then
		FormParameters.Insert("Key", FoundExternalUser);
	ElsIf IsRightToAddExternalUser Then
		FormParameters.Insert("AuthorizationObjectOfNewExternalUser", CommandParameter);
	Else
		DoMessageBox(NStr("en = 'Access to the information base is prohibited and was not provided'"));
		Return;
	EndIf;
	
	OpenForm("Catalog.ExternalUsers.ObjectForm", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure
