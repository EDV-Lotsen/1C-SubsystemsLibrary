////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	UpdateDataCompositionParameterValue(UserList, "UnspecifiedUser", Users.UnspecifiedUserProperties().StandardRef);
	
	UpdateDataCompositionParameterValue(UserList, "SeparationDisabled", Not CommonUseCached.DataSeparationEnabled());
	
	ShowNotValidUsers = False;
	
	If Parameters.ChoiceMode Then
		
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
		
	Else
		
		// Filtering only if ChoiceMode is False
		
		If ShowNotValidUsers Then
			CommonUseClientServer.DeleteFilterItems(UserList.Filter, "NotValid");
		Else	
			CommonUseClientServer.SetFilterItem(
				UserList.Filter,
				"NotValid",
				False);
		EndIf;
			
	EndIf;
	
	UseGroups = GetFunctionalOption("UseUserGroups");
	
	If TypeOf(Parameters.CurrentRow) = Type("CatalogRef.UserGroups") Then
		If UseGroups Then
			Items.UserGroups.CurrentRow = Parameters.CurrentRow;
		Else
			Parameters.CurrentRow = Undefined;
		EndIf;
	Else
		CurrentItem = Items.UserList;
		Items.UserGroups.CurrentRow = Catalogs.UserGroups.AllUsers;
	EndIf;
	
	If Not UseGroups Then
		Parameters.UserGroupChoice = False;
		Items.ShowNestedGroupUsersGroup.Visible = False;
		Items.CreateUserGroup.Visible = False;
	EndIf;
	
	// Setting up permanent data of the user list
	UpdateDataCompositionParameterValue(UserList, "EmptyUUID", New UUID("00000000-0000-0000-0000-000000000000"));
	AllUsersUserGroup = Catalogs.UserGroups.AllUsers;
	
	If Not AccessRight("Insert", Metadata.Catalogs.UserGroups) Then
		Items.CreateUserGroup.Visible = False;
	EndIf;
	If Not AccessRight("Insert", Metadata.Catalogs.Users) Then
		Items.CreateUser.Visible = False;
	EndIf;
	
	If Parameters.ChoiceMode Then
	
		If Items.Find("InfoBaseUsers") <> Undefined Then
			Items.InfoBaseUsers.Visible = False;
		EndIf;
		
		// Selecting items that are not marked for deletion
		UserList.Filter.Items[0].Use = True;
		
		Items.UserList.ChoiceMode = True;
		Items.UserGroups.ChoiceMode = Parameters.UserGroupChoice;
		Items.ChooseGroupUsers.Visible = Parameters.UserGroupChoice;
		Items.ChooseUser.DefaultButton = Not Parameters.UserGroupChoice;
		
		If Parameters.CloseOnChoice = False Then
			// Multiple choice mode
			Items.UserList.MultipleChoice = True;
			
			If Parameters.UserGroupChoice Then
				Title = NStr("en = 'Choose users and groups'");
				Items.ChooseUser.Title = NStr("en = 'Choose users'");
				Items.ChooseGroupUsers.Title = NStr("en = 'Choose groups'");
				
				Items.UserGroups.MultipleChoice = True;
				Items.UserGroups.SelectionMode = TableSelectionMode.MultiRow;
			Else
				Title = NStr("en = 'Choose users'");
			EndIf;
		Else
			// Single choice mode
			If Parameters.UserGroupChoice Then
				Title = NStr("en = 'Choose users and groups'");
				Items.ChooseUser.Title = NStr("en = 'Choose users'");
			Else
				Title = NStr("en = 'Choose users'");
			EndIf;
		EndIf;
	Else
		Items.ChooseUser.Visible = False;
		Items.ChooseGroupUsers.Visible = False;
	EndIf;
	
	RefreshFormContentOnGroupChange(ThisForm);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("Write_UserGroups")
	 And Source = Items.UserGroups.CurrentRow Then
		
		Items.UserList.Refresh();
	EndIf;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	If Settings[SelectHierarchy] = Undefined Then
		SelectHierarchy = True;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure SelectHierarchicallyOnChange(Item)
	
	RefreshFormContentOnGroupChange(ThisForm);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENT HANDLERS OF UserGroups TABLE 

&AtClient
Procedure UserGroupsOnActivateRow(Item)
	
	AttachIdleHandler("UserGroupsAfterActivateRow", 0.1, True);
	
EndProcedure

&AtClient
Procedure UserGroupsValueChoice(Item, Value, StandardProcessing)
	
	StandardProcessing = False;
	
	NotifyChoice(Value);
	
EndProcedure

&AtClient
Procedure UserGroupsBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If Not Copy Then
		Cancel = True;
		FormParameters = New Structure;
		
		If ValueIsFilled(Items.UserGroups.CurrentRow) Then
			
			FormParameters.Insert("FillingValues", New Structure("Parent", Items.UserGroups.CurrentRow));
		EndIf;
		
		OpenForm("Catalog.UserGroups.ObjectForm", FormParameters, Items.UserGroups);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENT HANDLERS OF UserList TABLE

&AtClient
Procedure UserListValueChoice(Item, Value, StandardProcessing)
	
	StandardProcessing = False;
	
	NotifyChoice(Value);
	
EndProcedure

&AtClient
Procedure UserListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
	FormParameters = New Structure;
	FormParameters.Insert("NewUserGroup", Items.UserGroups.CurrentRow);
	
	If Copy And Item.CurrentData <> Undefined Then
		FormParameters.Insert("CopyingValue", Item.CurrentRow);
	EndIf;
	
	OpenForm("Catalog.Users.ObjectForm", FormParameters, Items.UserList);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure CreateUserGroup(Command)
	
	Items.UserGroups.AddRow();
	
EndProcedure

&AtClient
Procedure ShowNotValidUsers(Command)
	
	ShowNotValidUsers = Not ShowNotValidUsers;
	
	Items.ShowNotValidUsers.Check = ShowNotValidUsers;
	
	If ShowNotValidUsers Then
		CommonUseClientServer.DeleteFilterItems(UserList.Filter, "NotValid");
	Else	
		CommonUseClientServer.SetFilterItem(
			UserList.Filter,
			"NotValid",
			False);
	EndIf;
		
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtClient
Procedure UserGroupsAfterActivateRow()
	
	RefreshFormContentOnGroupChange(ThisForm);
	
EndProcedure

&AtClientAtServerNoContext
Procedure RefreshFormContentOnGroupChange(ThisForm)
	
	Items = ThisForm.Items;
	If Not ThisForm.UseGroups
	 Or Items.UserGroups.CurrentRow = ThisForm.AllUsersUserGroup Then
		Items.ShowNestedGroupUsersGroup.CurrentPage = Items.CannotSetPropertyGroup;
		UpdateDataCompositionParameterValue(ThisForm.UserList, "SelectHierarchy", True);
		UpdateDataCompositionParameterValue(ThisForm.UserList, "UserGroup", ThisForm.AllUsersUserGroup);
	Else
		Items.ShowNestedGroupUsersGroup.CurrentPage = Items.SetPropertyGroup;
		UpdateDataCompositionParameterValue(ThisForm.UserList, "SelectHierarchy", ThisForm.SelectHierarchy);
		UpdateDataCompositionParameterValue(ThisForm.UserList, "UserGroup", Items.UserGroups.CurrentRow);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateDataCompositionParameterValue(Val ParameterOwner, Val ParameterName, Val ParameterValue)
	
	For Each Parameter In ParameterOwner.Parameters.Items Do
		If String(Parameter.Parameter) = ParameterName Then
			If Parameter.Use And Parameter.Value = ParameterValue Then
				Return;
			EndIf;
			Break;
		EndIf;
	EndDo;
	
	ParameterOwner.Parameters.SetParameterValue(ParameterName, ParameterValue);
	
EndProcedure
