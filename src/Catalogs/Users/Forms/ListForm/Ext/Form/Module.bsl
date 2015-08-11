

////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS
//

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	UseGroups = GetFunctionalOption("UseUserGroups");
	
	If TypeOf(Parameters.CurrentRow) = Type("CatalogRef.UserGroups") Then
		If UseGroups Then
			Items.UserGroups.CurrentRow = Parameters.CurrentRow;
		Else
			Parameters.CurrentRow = Undefined;
		EndIf;
	Else
		CurrentItem = Items.UsersList;
		Items.UserGroups.CurrentRow = Catalogs.UserGroups.AllUsers;
		RefreshDataCompositionParameterValue(UsersList, "UserGroup", Catalogs.UserGroups.AllUsers);
		RefreshDataCompositionParameterValue(UsersList, "SelectHierarchically", True);
	EndIf;
	
	If NOT UseGroups Then
		Parameters.ChoiceOfUserGroups = False;
		Items.GroupShowChildGroupUsers.Visible = False;
		Items.CreateGroupOfUsers.Visible = False;
	EndIf;
	
	// Configure constant data for user list
	RefreshDataCompositionParameterValue(UsersList, "EmptyUUID", New Uuid("00000000-0000-0000-0000-000000000000"));
	UsersGroupAllUsers = Catalogs.UserGroups.AllUsers;
	
	If NOT AccessRight("Insert", Metadata.Catalogs.UserGroups) Then
		Items.CreateGroupOfUsers.Visible = False;
	EndIf;
	If NOT AccessRight("Insert", Metadata.Catalogs.Users) Then
		Items.CreateUser.Visible = False;
	EndIf;
	
	If Parameters.ChoiceMode Then
		
		If Items.Find("InfoBaseUsers") <> Undefined Then
			Items.InfoBaseUsers.Visible = False;
		EndIf;
		
		// Filter of items not marked for deletion
		UsersList.SettingsComposer.Settings.Filter.Items[0].Use = True;
		
		Items.UsersList.ChoiceMode       	=	True;
		Items.UserGroups.ChoiceMode       	=	Parameters.ChoiceOfUserGroups;
		Items.SelectUsersGroup.Visible  	=	Parameters.ChoiceOfUserGroups;
		Items.SelectUser.DefaultButton 		= 	NOT Parameters.ChoiceOfUserGroups;
		
		If Parameters.CloseOnChoice = False Then
			// Selection mode
			Items.UsersList.MultipleChoice = True;
			Items.UsersList.SelectionMode = TableSelectionMode.MultiRow;
			
			If Parameters.ChoiceOfUserGroups Then
				Title                         	= NStr("en='User and group selection'");
				Items.SelectUser.Title        	= NStr("en='Select users'");
				
				Items.SelectUsersGroup.Title 	= NStr("en='Select groups'");
				
				Items.UserGroups.MultipleChoice = True;
				Items.UserGroups.SelectionMode 	= TableSelectionMode.MultiRow;
			Else
				Title                          	= NStr("en='User selection'");
			EndIf;
		Else
			If Parameters.ChoiceOfUserGroups Then
				Title							= NStr("en='Select user and group'");
				Items.SelectUser.Title        	= NStr("en='Select user'");
			Else
				Title							= NStr("en='Select user'");
			EndIf;
		EndIf;
	Else
		Items.SelectUser.Visible        = False;
		Items.SelectUsersGroup.Visible  = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	RefreshFormContentOnGroupChange();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "UserGroupContentChanged" Then
		If Parameter = Items.UserGroups.CurrentRow Then
			Items.UsersList.Refresh();
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	If Settings[SelectHierarchically] = Undefined Then
		SelectHierarchically = True;
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// Event handlers of commands and form items
//

&AtClient
Procedure CreateGroupOfUsers(Command)
	
	Items.UserGroups.AddRow();
	
EndProcedure


&AtClient
Procedure UserGroupsOnActivateRow(Item)
	
	RefreshFormContentOnGroupChange();
	
EndProcedure

&AtClient
Procedure UserGroupsValueChoice(Item, Value, StandardProcessing)
	
	StandardProcessing = False;
	
	NotifyChoice(Value);
	
EndProcedure

&AtClient
Procedure UserGroupsBeforeAddRow(Item, Cancel, Clone, Parent, Folder)
	
	If NOT Clone Then
		Cancel = True;
		FormParameters = New Structure;
		
		If ValueIsFilled(Items.UserGroups.CurrentRow) Then
			
			FormParameters.Insert("FillingValues", New Structure("Parent", Items.UserGroups.CurrentRow));
		EndIf;
		
		OpenForm("Catalog.UserGroups.ObjectForm", FormParameters, Items.UserGroups);
	EndIf;
	
EndProcedure


&AtClient
Procedure UsersListValueChoice(Item, Value, StandardProcessing)
	
	StandardProcessing = False;
	
	NotifyChoice(Value);
	
EndProcedure

&AtClient
Procedure UsersListBeforeAddRow(Item, Cancel, Clone, Parent, Folder)
	
	Cancel = True;
	
	FormParameters = New Structure;
	FormParameters.Insert("GroupNewUser", Items.UserGroups.CurrentRow);
	
	If Clone And Item.CurrentData <> Undefined Then
		FormParameters.Insert("CopyingValue", Item.CurrentRow);
	EndIf;
	
	OpenForm("Catalog.Users.ObjectForm", FormParameters, Items.UsersList);
	
EndProcedure


&AtClient
Procedure SelectHierarchicallyOnChange(Item)
	
	RefreshFormContentOnGroupChange();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary form procedures and functions
//

&AtClient
Procedure RefreshFormContentOnGroupChange()
	If NOT UseGroups
		OR Items.UserGroups.CurrentRow = UsersGroupAllUsers Then
		//
		Items.GroupShowChildGroupUsers.CurrentPage = Items.GroupUnableToSetProperty;
		RefreshDataCompositionParameterValue(UsersList, "SelectHierarchically", True);
		RefreshDataCompositionParameterValue(UsersList, "UserGroup", UsersGroupAllUsers);
	Else
		Items.GroupShowChildGroupUsers.CurrentPage = Items.GroupSetProperty;
		RefreshDataCompositionParameterValue(UsersList, "SelectHierarchically", SelectHierarchically);
		RefreshDataCompositionParameterValue(UsersList, "UserGroup", Items.UserGroups.CurrentRow);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure RefreshDataCompositionParameterValue(Val OwnerOfParameters, Val ParameterName, Val ParameterValue)
	
	For each Parameter In OwnerOfParameters.Parameters.Items Do
		If String(Parameter.Parameter) = ParameterName Then
			If Parameter.Use And Parameter.Value = ParameterValue Then
				Return;
			EndIf;
			Break;
		EndIf;
	EndDo;
	
	OwnerOfParameters.Parameters.SetParameterValue(ParameterName, ParameterValue);
	
EndProcedure

