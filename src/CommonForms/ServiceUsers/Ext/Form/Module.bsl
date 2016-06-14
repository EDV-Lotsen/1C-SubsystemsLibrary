
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
 
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 	
  	Return;
	EndIf;
	
	Mode = Constants.InfobaseUsageMode.Get();
	If Mode = Enums.InfobaseUsageModes.Demo Then
		Raise(NStr("en = 'Adding users is not available in the demo mode.'"));
	EndIf;
	
	// The form is not available until the preparation is finished.
	Enabled = False;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ServiceUserPassword = Undefined Then
		Cancel = True;
		AttachIdleHandler("RequestPasswordForAuthenticationInService", 0.1, True);
	Else
		PrepareForm();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure CheckAll(Command)
	
	For Each TableRow In ServiceUsers Do
		If TableRow.Access Then
			Continue;
		EndIf;
		TableRow.Add = True;
	EndDo;
	
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	
	For Each TableRow In ServiceUsers Do
		TableRow.Add = False;
	EndDo;
	
EndProcedure

&AtClient
Procedure AddSelectedUsers(Command)
	
	AddSelectedUsersAtServer();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ServiceUsersAdd.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ServiceUsers.Access");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("Enabled", False);

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ServiceUsersAdd.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ServiceUsersName.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ServiceUsersFullName.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ServiceUsersAccess.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ServiceUsers.Access");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("BackColor", StyleColors.InaccessibleDataColor);

EndProcedure

&AtClient
Procedure RequestPasswordForAuthenticationInService()
	
	StandardSubsystemsClient.PasswordForAuthenticationInServiceOnRequest(
		New NotifyDescription("OnOpenContinue", ThisObject));
	
EndProcedure

&AtClient
Procedure OnOpenContinue(SaaSUserNewPassword, NotDefined) Export
	
	If SaaSUserNewPassword <> Undefined Then
		ServiceUserPassword = SaaSUserNewPassword;
		Open();
	EndIf;
	
EndProcedure

&AtServer
Procedure PrepareForm()
	
	UsersInternalSaaS.GetActionsWithSaaSUser(
		Catalogs.Users.EmptyRef());
		
	UserTable = UsersInternalSaaS.GetSaaSUsers(
		ServiceUserPassword);
		
	For Each UserInfo In UserTable Do
		UserRow = ServiceUsers.Add();
		FillPropertyValues(UserRow, UserInfo);
	EndDo;
	
	Enabled = True;
	
EndProcedure

&AtServer
Procedure AddSelectedUsersAtServer()
	
	SetPrivilegedMode(True);
	
	Counter = 0;
	LineCount = ServiceUsers.Count();
	For Counter = 1 To LineCount Do
		TableRow = ServiceUsers[LineCount - Counter];
		If Not TableRow.Add Then
			Continue;
		EndIf;
		
		UsersInternalSaaS.GrantSaaSUserAccess(
			TableRow.ID, ServiceUserPassword);
		
		ServiceUsers.Delete(TableRow);
	EndDo;
	
EndProcedure

#EndRegion
