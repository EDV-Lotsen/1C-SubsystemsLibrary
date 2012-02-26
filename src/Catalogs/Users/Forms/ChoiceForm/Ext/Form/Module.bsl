
&AtClient
Var FirstActivization;

&AtClient
Var SelectHierarchicallyOnOpen;

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	Value = FormDataSettingsStorage.Load("CatalogUsersListForm", "SelectHierarchically");
	SelectHierarchically = ?(Value = Undefined, True, Value);
	
	UsersGroupOnOpen = Catalogs.UserGroups.AllUsers;
	
	Items.UserGroups.CurrentRow = UsersGroupOnOpen;
	
	RefreshFormContentOnGroupChange();
	
	If Parameters.CloseOnChoice = Undefined OR Parameters.CloseOnChoice Then
		Title = NStr("en = 'Select User'");
	Else
		Title = NStr("en = 'Select Users'");
		Items.UsersList.MultipleChoice = True;
		Items.UsersList.SelectionMode = TableSelectionMode.MultiRow;
	EndIf;
	
EndProcedure

&AtClient
Procedure IBUserAdministration(Command)
	OpenForm("Catalog.Users.Form.IBUsers");
EndProcedure

&AtClient
Procedure CreateUser(Command)
	OpenForm("Catalog.Users.ObjectForm", New Structure("UsersGroup", Items.UserGroups.CurrentRow));
EndProcedure

&AtClient
Procedure UserGroupsOnActivateRow(Item)
	
	If FirstActivization = Undefined OR FirstActivization = True Then
		FirstActivization = False;
		Return;
	EndIf;
	
	AttachIdleHandler("IdleProcessing", 0.2, True);
	
EndProcedure

&AtClient
Procedure IdleProcessing()
	
	RefreshFormContentOnGroupChange();
	
EndProcedure

&AtClient
Procedure SelectHierarchicallyOnChange(Item)
	
	RefreshFormContentOnGroupChange();
	
EndProcedure

&AtServer
Procedure RefreshFormContentOnGroupChange()
	
	If Items.UserGroups.CurrentRow = Catalogs.UserGroups.AllUsers Then
		Items.GroupShowChildGroupUsers.CurrentPage = 
				Items.GroupUnableToSetProperty;
		UsersList.Parameters.SetParameterValue("SelectHierarchically", True);
	Else
		Items.GroupShowChildGroupUsers.CurrentPage = 
				Items.GroupSetProperty;
		UsersList.Parameters.SetParameterValue("SelectHierarchically", SelectHierarchically);
	EndIf;
	
	UsersList.Parameters.SetParameterValue("UsersGroup", Items.UserGroups.CurrentRow);
	UsersList.Parameters.SetParameterValue("EmptyUUID", New Uuid("00000000-0000-0000-0000-000000000000"));
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If SelectHierarchicallyOnOpen <> SelectHierarchically Then
		SaveFormSettings(SelectHierarchically);
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure SaveFormSettings(SelectHierarchically)
	
	FormDataSettingsStorage.Save("CatalogUsersListForm", "SelectHierarchically", SelectHierarchically);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancellation)
	SelectHierarchicallyOnOpen = SelectHierarchically;
EndProcedure

&AtClient
Procedure CreateAccessGroup(Command)
	OpenForm("Catalog.UserGroups.ObjectForm");
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "UserGroupContentChanged" Then
		If Parameter = Items.UserGroups.CurrentRow Then
			Items.UsersList.Refresh();
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersListBeforeAddRow(Item, Cancellation, Clone, Parent, Folder)
	
	Cancellation = True;
	OpenForm("Catalog.Users.ObjectForm",
			New Structure("UsersGroup,CopyingValue",
						Items.UserGroups.CurrentRow,
						Item.CurrentData.Ref));
	
EndProcedure

&AtClient
Procedure UsersListSelection(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	NotifyChoice(RowSelected);
EndProcedure
