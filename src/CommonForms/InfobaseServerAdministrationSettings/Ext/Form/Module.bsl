
////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM EVENTS HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	If CommonUse.FileInformationBase() Then
		Raise NStr("en = 'Server Infobase is available only in the client-server mode'");
		Return;
	EndIf;
		
	Items.GroupAdministration.Enabled = ?(InfoBaseUsers.GetUsers().Count() > 0, True, False);
	
	AdministrationParameter = InfobaseConnections.GetInfobaseAdministrationParameters();
	
	IBAdministratorID 			 = InfoBaseUsers.FindByName(
		AdministrationParameter.IBAdministratorName).Uuid;
	IBAdministrator				 = Catalogs.Users.FindByAttribute("IBUserID", IBAdministratorID);
	IBAdministratorPassword		 = AdministrationParameter.IBAdministratorPassword;
	ClusterAdministratorName	 = AdministrationParameter.ClusterAdministratorName;
	ClusterAdministratorPassword = AdministrationParameter.ClusterAdministratorPassword;
	ServerAgentPort				 = AdministrationParameter.ServerAgentPort;
	ServersClusterPort			 = AdministrationParameter.ServersClusterPort;
	
	NonstandardPorts			 = ServersClusterPort <> 0 OR ServerAgentPort <> 0;
	ClusterRequiresAuthorization = NOT IsBlankString(ClusterAdministratorName);
		
	Items.GroupPorts.Enabled 	 			= NonstandardPorts;
	Items.GroupAuthorizationCluster.Enabled = ClusterRequiresAuthorization;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancellation, CheckedAttributes)

	If ValueIsFilled(IBAdministrator) Then
		
		IBUser = InfoBaseUsers.FindByUUID(IBAdministrator.IBUserID);
		If IBUser = Undefined Then
			CommonUseClientServer.MessageToUser(NStr("en = 'Specified user does not have access to the information base!'"),,
				"IBAdministrator",,Cancellation);
			Return;
		EndIf;
		If NOT AccessRight("Administration", Metadata, IBUser) Then
			CommonUseClientServer.MessageToUser(NStr("en = 'Specified user does not have the administrator''s right!'"),,
				"IBAdministrator",,Cancellation);
			Return;
		EndIf;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM ITEMS EVENT HANDLERS

&AtClient
Procedure Write(Command)
	
	ClearMessages();
	ConnectionParameters = SaveConnectionParameters(IBAdministrator, IBAdministratorPassword, ClusterRequiresAuthorization,
		ClusterAdministratorName, ClusterAdministratorPassword, NonstandardPorts,
		ServerAgentPort, ServersClusterPort);
	
	If ConnectionParameters = Undefined Then
		Return;
	EndIf;							
	
	Notify("UpdatedInfoBaseConnectionParameters", ConnectionParameters);
	Close();
	
EndProcedure

&AtClient
Procedure ClusterRequiresAuthorizationOnChange(Item)
	
	SetFieldsStatus()
	
EndProcedure

&AtClient
Procedure NonstandardPortsOnChange(Item)
	
	SetFieldsStatus();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// AUXILIARY PROCEDURES AND FUNCTIONS

&AtClient
Procedure SetFieldsStatus()
	
	Items.GroupPorts.Enabled 				= NonstandardPorts;
	Items.GroupAuthorizationCluster.Enabled = ClusterRequiresAuthorization;
	
EndProcedure

&AtServer
Function SaveConnectionParameters(IBAdministrator, IBAdministratorPassword, ClusterRequiresAuthorization,
	ClusterAdministratorName, ClusterAdministratorPassword, NonstandardPorts,
	ServerAgentPort, ServersClusterPort)
	
	If NOT FillCheck() Then
		Return Undefined;	
	EndIf;
	IBUser = InfoBaseUsers.FindByUUID(IBAdministrator.IBUserID);
	If IBUser <> Undefined Then
		IBAdministratorName = IBUser.Name;
	Else	
		IBAdministratorName = "";
	EndIf;
	AdministrationParameter = InfobaseConnections.GetInfobaseAdministrationParameters();
	
	AdministrationParameter.IBAdministratorName 	= IBAdministratorName;
	AdministrationParameter.IBAdministratorPassword = IBAdministratorPassword;
	
	If ClusterRequiresAuthorization Then
		AdministrationParameter.ClusterAdministratorName 	 = ClusterAdministratorName;
		AdministrationParameter.ClusterAdministratorPassword = ClusterAdministratorPassword;
	Else	
		AdministrationParameter.ClusterAdministratorName = "";
		AdministrationParameter.ClusterAdministratorPassword = "";
	EndIf;
	
	If NonstandardPorts Then
		AdministrationParameter.ServersClusterPort = ServersClusterPort;
		AdministrationParameter.ServerAgentPort = ServerAgentPort;
	Else	
		AdministrationParameter.ServersClusterPort = 0;
		AdministrationParameter.ServerAgentPort = 0;
	EndIf;	
	
	Constants.InfobaseAdministrationParameters.Set(New ValueStorage(AdministrationParameter));
	
	InfobaseConnections.WriteInfobaseAdministrationParameters(AdministrationParameter);
	
	Return AdministrationParameter;
	
EndFunction


