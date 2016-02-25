
////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Autotest") Then // Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
		Return;
	EndIf;
	
	If CommonUse.FileInfobase() And Parameters.PromptForClusterAdministrationParameters Then
		Raise NStr("en = 'Server cluster parameters can only be set up in client/server mode.'");
	EndIf;
	
	CanUseSeparatedData = CommonUseCached.CanUseSeparatedData();
	
	If Parameters.AdministrationParameters = Undefined Then
		AdministrationParameters = StandardSubsystemsServer.AdministrationParameters();
	Else
		AdministrationParameters = Parameters.AdministrationParameters;
	EndIf;
	
	If Not AdministrationParametersInputRequired() Then
		Return;
	EndIf;
	
	If CanUseSeparatedData Then
		
		IBUser = InfobaseUsers.FindByName(
		AdministrationParameters.InfobaseAdministratorName);
		If IBUser <> Undefined Then
			InfobaseAdministratorID = IBUser.UUID;
		EndIf;
		Users.FindAmbiguousInfobaseUsers(, InfobaseAdministratorID);
		InfobaseAdministrator = Catalogs.Users.FindByAttribute("InfobaseUserID", InfobaseAdministratorID);
		
	EndIf;
	
	If Not IsBlankString(Parameters.Title) Then
		Title = Parameters.Title;
	EndIf;
	
	If IsBlankString(Parameters.CommentLabel) Then
		Items.CommentLabel.Visible = False;
	Else
		Items.CommentLabel.Title = Parameters.CommentLabel;
	EndIf;
	
	FillPropertyValues(ThisObject, AdministrationParameters);
	
	Items.Mode.CurrentPage = ?(CanUseSeparatedData, Items.SeparatedMode, Items.SharedMode);
	Items.InfobaseAdministrationGroup.Visible = Parameters.PromptForInfobaseAdministrationParameters;
	Items.ClusterAdministrationGroup.Visible = Parameters.PromptForClusterAdministrationParameters;
	
	If CommonUseClientServer.IsLinuxClient() Then
		
		ConnectionType = "RAS";
		Items.ConnectionType.Visible = False;
		Items.ManagementParametersGroup.ShowTitle = True;
		Items.ManagementParametersGroup.Representation = UsualGroupRepresentation.WeakSeparation;
		
	EndIf;
	
	Items.ConnectionTypeGroup.CurrentPage = ?(ConnectionType = "COM", Items.COMGroup, Items.RASGroup);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If Not AdministrationParametersInputRequired Then
		Close(AdministrationParameters);
	EndIf;
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, AttributesToCheck)
	
	If Not Parameters.PromptForInfobaseAdministrationParameters Then
		Return;
	EndIf;
	
	If CommonUseCached.CanUseSeparatedData() Then
		If Not ValueIsFilled(InfobaseAdministrator) Then
			Return;
		EndIf;
		FieldName = "InfobaseAdministrator";
	Else
		If IsBlankString(InfobaseAdministratorName) Then
			Return;
		EndIf;
		FieldName = "InfobaseAdministratorName";
	EndIf;
	IBUser = Undefined;
	GetInfobaseAdministrator(IBUser);
	If IBUser = Undefined Then
		CommonUseClientServer.MessageToUser(NStr("en = 'This user is not allowed to access the infobase.'"),,
			FieldName,,Cancel);
		Return;
	EndIf;
	If Not Users.InfobaseUserWithFullAccess(IBUser, True) Then
		CommonUseClientServer.MessageToUser(NStr("en = 'This user has no administrative rights.'"),,
			FieldName,,Cancel);
		Return;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure ConnectionTypeOnChange(Item)
	
	Items.ConnectionTypeGroup.CurrentPage = ?(ConnectionType = "COM", Items.COMGroup, Items.RASGroup);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure Write(Command)
	
	ClearMessages();
	
	If Not CheckFillingAtServer() Then
		Return;
	EndIf;
	
	// Filling the settings structure
	FillPropertyValues(AdministrationParameters, ThisObject);
	
	CheckAdministrationParameters(AdministrationParameters);
	
	SaveConnectionParameters();
	
	// Restoring the password values
	FillPropertyValues(AdministrationParameters, ThisObject);
	
	Close(AdministrationParameters);
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	Close();
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

Function CheckFillingAtServer()
	
	Return CheckFilling();
	
EndFunction

&AtServer
Procedure SaveConnectionParameters()
	
	// Saving the parameters to a constant, clearing the passwords
	StandardSubsystemsServer.SetAdministrationParameters(AdministrationParameters);
	
EndProcedure

&AtServer
Procedure GetInfobaseAdministrator(IBUser = Undefined)
	
	If CommonUseCached.CanUseSeparatedData() Then
		If Not ValueIsFilled(InfobaseAdministrator) Then
			IBUser = Undefined;
		EndIf;
		IBUser = InfobaseUsers.FindByUUID(
			InfobaseAdministrator.InfobaseUserID);
	Else
		If IsBlankString(InfobaseAdministratorName) Then
			IBUser = Undefined;
		EndIf;
		IBUser = InfobaseUsers.FindByUUID(
		New UUID(InfobaseAdministratorName));
	EndIf;
	
	InfobaseAdministratorName = ?(IBUser = Undefined, "", IBUser.Name);
	
EndProcedure

&AtClient
Procedure CheckAdministrationParameters(AdministrationParameters)
	
	If ConnectionType = "COM" Then
		CommonUseClient.RegisterCOMConnector(False);
	EndIf;
	
	If StandardSubsystemsClientCached.ClientParameters().FileInfobase Then
		
		ValidateFileInfobaseAdministrationParameters();
		
	Else
		
		If CommonUseClient.ClientConnectedViaWebServer() Then
			
			ValidateAdministrationParametersAtServer();
			
		Else
			ClusterAdministrationClientServer.CheckAdministrationParameters(AdministrationParameters,,
				Parameters.PromptForClusterAdministrationParameters, Parameters.PromptForInfobaseAdministrationParameters);
		EndIf;
			
	EndIf;
	
EndProcedure

&AtServer
Procedure ValidateAdministrationParametersAtServer()
	
	ClusterAdministrationClientServer.CheckAdministrationParameters(AdministrationParameters,,
		Parameters.PromptForClusterAdministrationParameters, Parameters.PromptForInfobaseAdministrationParameters);
	
EndProcedure

&AtServer
Function AdministrationParametersInputRequired()
	
	AdministrationParametersInputRequired = True;
	
	If Parameters.PromptForInfobaseAdministrationParameters And Not Parameters.PromptForClusterAdministrationParameters Then
		
		UserCount = InfobaseUsers.GetUsers().Count();
		
		If UserCount > 0 Then
			
			// Determining the actual user name even if it has been changed in the current session
			// (for example, for connecting to the current infobase through an external connection from this session).
			// In all other cases, getting InfobaseUsers.CurrentUser() is sufficient
			CurrentUser = InfobaseUsers.FindByUUID(
				InfobaseUsers.CurrentUser().UUID);
			
			If CurrentUser = Undefined Then
				CurrentUser = InfobaseUsers.CurrentUser();
			EndIf;
			
			If CurrentUser.StandardAuthentication And Not CurrentUser.PasswordIsSet 
				And Users.InfobaseUserWithFullAccess(CurrentUser, True) Then
				
				AdministrationParameters.InfobaseAdministratorName = CurrentUser.Name;
				AdministrationParameters.InfobaseAdministratorPassword = "";
				
				AdministrationParametersInputRequired = False;
				
			EndIf;
			
		ElsIf UserCount = 0 Then
			
			AdministrationParameters.InfobaseAdministratorName = "";
			AdministrationParameters.InfobaseAdministratorPassword = "";
			
			AdministrationParametersInputRequired = False;
			
		EndIf;
		
	EndIf;
	
	Return AdministrationParametersInputRequired;
	
EndFunction

&AtClient
Procedure ValidateFileInfobaseAdministrationParameters()
	
	If Parameters.PromptForInfobaseAdministrationParameters Then
		
		// Connection check is not performed for the base versions
		ClientParameters = StandardSubsystemsClientCached.ClientParameters();
		If ClientParameters.IsBaseConfigurationVersion Then
			Return;
		EndIf;
		
		COMConnectorName = ClientParameters.COMConnectorName;
		
		ConnectionString = InfobaseConnectionString();
		ConnectionString = "Usr=""" + InfobaseAdministratorName + """;Pwd=""" + InfobaseAdministratorPassword + """";
		
		CommonUseClient.RegisterCOMConnector(False);
		
		ComConnector = New COMObject(COMConnectorName);
		InfobaseConnectionString = ConnectionString + ConnectionString;
		Connection = ComConnector.Connect(InfobaseConnectionString);
		
	EndIf;
	
EndProcedure