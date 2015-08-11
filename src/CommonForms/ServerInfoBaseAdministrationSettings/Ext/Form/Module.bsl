////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	If CommonUse.FileInfoBase() Then
		Raise NStr("en = 'Configuring the server infobase is possible only in the client/server mode.'");
		Return;
	EndIf;
		
	AdministrationParameters = InfoBaseConnections.GetInfoBaseAdministrationParameters();
	
	InfoBaseUser = InfoBaseUsers.FindByName(
		AdministrationParameters.InfoBaseAdministratorName);
	If InfoBaseUser <> Undefined Then
		InfoBaseAdministratorID = InfoBaseUser.UUID;
	EndIf;
	
	If CommonUseCached.DataSeparationEnabled() Then
		Items.OperatingMode.CurrentPage = Items.DataSeparation;
		SharedInfoBaseAdministrator = String(InfoBaseAdministratorID);
		ChoiceList = Items.SharedInfoBaseAdministrator.ChoiceList;
		ChoiceList.Clear();
		Administrators = InformationRegisters.SharedUsers.AdministratorList();
		For Each ListItem In Administrators Do
			ChoiceList.Add(String(ListItem.Value), ListItem.Presentation);
		EndDo;
	Else
		Items.OperatingMode.CurrentPage = Items.NoDataSeparation;
		Users.FindAmbiguousInfoBaseUsers(, InfoBaseAdministratorID);
		InfoBaseAdministrator	= Catalogs.Users.FindByAttribute("InfoBaseUserID", InfoBaseAdministratorID);
	EndIf;
	InfoBaseAdministratorPassword		 = AdministrationParameters.InfoBaseAdministratorPassword;
	
	ClusterAdministratorName	 = AdministrationParameters.ClusterAdministratorName;
	ClusterAdministratorPassword = AdministrationParameters.ClusterAdministratorPassword;
	ServerAgentPort			 = AdministrationParameters.ServerAgentPort;
	ServerClusterPort		 = AdministrationParameters.ServerClusterPort;
	
	NonstandardPorts			 = ServerClusterPort <> 0 Or ServerAgentPort <> 0;
	ClusterRequiresAuthorization	 = Not IsBlankString(ClusterAdministratorName);
		
	Items.PortsGroup.Enabled = NonstandardPorts;
	Items.ClusterAuthorizationGroup.Enabled = ClusterRequiresAuthorization;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, AttributesToCheck)
	
	If CommonUseCached.DataSeparationEnabled() Then
		If IsBlankString(SharedInfoBaseAdministrator) Then
			Return;
		EndIf;
		FieldName = "SharedInfoBaseAdministrator";
	Else
		If Not ValueIsFilled(InfoBaseAdministrator) Then
			Return;
		EndIf;
		FieldName = "InfoBaseAdministrator";
	EndIf;
	InfoBaseUser = GetInfoBaseAdministrator();
	If InfoBaseUser = Undefined Then
		CommonUseClientServer.MessageToUser(NStr("en = 'The specified user cannot access the infobase.'"),,
			FieldName,,Cancel);
		Return;
	EndIf;
	If Not Users.InfoBaseUserWithFullAccess(InfoBaseUser, True) Then
		CommonUseClientServer.MessageToUser(NStr("en = 'The user does not have administrative rights.'"),,
			FieldName,,Cancel);
		Return;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure ClusterRequiresAuthorizationOnChange(Item)
	
	SetAccessibilityOfFormItems()
	
EndProcedure

&AtClient
Procedure NonstandardPortsOnChange(Item)
	
	SetAccessibilityOfFormItems();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure Write(Command)
	
	ClearMessages();
	If Not SaveConnectionParameters() Then
		Return;
	EndIf;							
	
	Notify("Write_InfoBaseAdministrationParameters");
	Close();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtClient
Procedure SetAccessibilityOfFormItems()
	
	Items.PortsGroup.Enabled = NonstandardPorts;
	Items.ClusterAuthorizationGroup.Enabled = ClusterRequiresAuthorization;
	
EndProcedure

&AtServer
Function SaveConnectionParameters()
	
	If Not CheckFilling() Then
		Return False;	
	EndIf;
		
	AdministrationParameters = InfoBaseConnections.GetInfoBaseAdministrationParameters();
		
	InfoBaseUser = GetInfoBaseAdministrator();
	If InfoBaseUser <> Undefined Then
		InfoBaseAdministratorName = InfoBaseUser.Name;
	Else	
		InfoBaseAdministratorName = "";
	EndIf;
	AdministrationParameters.InfoBaseAdministratorName = InfoBaseAdministratorName;
	AdministrationParameters.InfoBaseAdministratorPassword = InfoBaseAdministratorPassword;
	
	If ClusterRequiresAuthorization Then
		AdministrationParameters.ClusterAdministratorName = ClusterAdministratorName;
		AdministrationParameters.ClusterAdministratorPassword = ClusterAdministratorPassword;
	Else	
		AdministrationParameters.ClusterAdministratorName = "";
		AdministrationParameters.ClusterAdministratorPassword = "";
	EndIf;
	
	If NonstandardPorts Then
		AdministrationParameters.ServerClusterPort = ServerClusterPort;
		AdministrationParameters.ServerAgentPort = ServerAgentPort;
	Else	
		AdministrationParameters.ServerClusterPort = 0;
		AdministrationParameters.ServerAgentPort = 0;
	EndIf;	
	
	InfoBaseConnections.WriteInfoBaseAdministrationParameters(AdministrationParameters);
	
	Return True;
	
EndFunction

Function GetInfoBaseAdministrator()
	If CommonUseCached.DataSeparationEnabled() Then
		If IsBlankString(SharedInfoBaseAdministrator) Then
			Return Undefined;
		EndIf;
		Return InfoBaseUsers.FindByUUID(
			New UUID(SharedInfoBaseAdministrator));
	Else
		If Not ValueIsFilled(InfoBaseAdministrator) Then
			Return Undefined;
		EndIf;
		Return InfoBaseUsers.FindByUUID(
			InfoBaseAdministrator.InfoBaseUserID);
	EndIf;
EndFunction

