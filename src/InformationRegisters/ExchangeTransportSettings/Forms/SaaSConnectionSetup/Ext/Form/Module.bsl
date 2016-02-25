
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
 
  // Skipping the initialization to guarantee that the form will be
  // received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	DataExchangeServer.CheckExchangeManagementRights();
	
	SetPrivilegedMode(True);
	
	AddressForRestoringAccountPassword = Parameters.AddressForRestoringAccountPassword;
	AutomaticSynchronizationSetup = Parameters.AutomaticSynchronizationSetup;
	
	If CommonUse.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		Items.InternetAccessParameters.Visible = True;
	Else
		Items.InternetAccessParameters.Visible = False;
	EndIf;
	
	If Not IsBlankString(Write.WSUserName) Then
		
		User = Users.FindByName(Write.WSUserName);
		
	EndIf;
	
	For Each SynchronizationUser In DataSynchronizationUsers() Do
		
		Items.User.ChoiceList.Add(SynchronizationUser.User, SynchronizationUser.Presentation);
		
	EndDo;
	
	Items.ForgotPassword.Visible = Not IsBlankString(AddressForRestoringAccountPassword);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	TestSaaSConnection(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	If AutomaticSynchronizationSetup Then
		
		Notify("Write_ExchangeTransportSettings",
			New Structure("AutomaticSynchronizationSetup"));
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CurrentObject.WSRememberPassword = True;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ForgotPassword(Command)
	
	DataExchangeClient.OnOpenHowToChangeDataSynchronizationPasswordInstruction(AddressForRestoringAccountPassword);
	
EndProcedure

&AtClient
Procedure InternetAccessParameters(Command)
	
	DataExchangeClient.OpenProxyServerParameterForm();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure TestSaaSConnection(Cancel)
	
	SetPrivilegedMode(True);
	
	// Determining the user name
	UserProperties = Undefined;
	
	Users.ReadInfobaseUser(
		CommonUse.ObjectAttributeValue(User, "InfobaseUserID"),
		UserProperties);
	If UserProperties <> Undefined Then
		Write.WSUserName = UserProperties.Name
	EndIf;
	
	// Testing connection to the correspondent
	ConnectionParameters = DataExchangeServer.WSParameterStructure();
	FillPropertyValues(ConnectionParameters, Write);
	
	UserMessage = "";
	If Not DataExchangeServer.CorrespondentConnectionEstablished(Write.Node, ConnectionParameters, UserMessage) Then
		CommonUseClientServer.MessageToUser(UserMessage,, "Write.WSPassword",, Cancel);
	EndIf;
	
EndProcedure

&AtServer
Function DataSynchronizationUsers()
	
	Result = New ValueTable;
	Result.Columns.Add("User"); // Type: CatalogRef.Users
	Result.Columns.Add("Presentation");
	
	QueryText =
	"SELECT
	|	Users.Ref AS User,
	|	Users.Description AS Presentation,
	|	Users.InfobaseUserID AS InfobaseUserID
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	NOT Users.DeletionMark
	|	AND NOT Users.NotValid
	|	AND NOT Users.Internal
	|
	|ORDER BY
	|	Users.Description";
	
	Query = New Query;
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		If ValueIsFilled(Selection.InfobaseUserID) Then
			
			IBUser = InfobaseUsers.FindByUUID(Selection.InfobaseUserID);
			
			If IBUser <> Undefined
				And DataExchangeServer.DataSynchronizationPermitted(IBUser) Then
				
				FillPropertyValues(Result.Add(), Selection);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

#EndRegion
