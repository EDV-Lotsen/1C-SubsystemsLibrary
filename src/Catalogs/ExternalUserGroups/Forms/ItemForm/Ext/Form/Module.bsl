////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	//** Setting initial values before importing settings from the server
	// if data was not written and there is nothing to import.
	ShowRoleSubsystems = True;
	Items.RolesShowRoleSubsystems.Check = True;
	// A form initial script is executed in OnCreateAtServer, in case of new object,
	// and in OnReadAtServer if object already exists.
	If Object.Ref.IsEmpty() Then
		FormInitialization();
	EndIf;
	
	//** Preparing permanent data
	FillAuthorizationObjectTypeList();
	
	// Deleting the FullAccess role from the choice list and the role table
	
	//** Filling variable data
	
	If Object.Ref = Catalogs.ExternalUserGroups.EmptyRef() And
	 Object.Parent.Ref = Catalogs.ExternalUserGroups.AllExternalUsers Then
		
		Object.Parent = Catalogs.ExternalUserGroups.EmptyRef();
	EndIf;
	
	DefineActionsOnForm();
	
	//** Setting permanent property availability
	
	Items.Description.Visible = ValueIsFilled(ActionsOnForm.ItemProperties);
	Items.Parent.Visible = ValueIsFilled(ActionsOnForm.ItemProperties);
	Items.Comment.Visible = ValueIsFilled(ActionsOnForm.ItemProperties);
	Items.Content.Visible = ValueIsFilled(ActionsOnForm.GroupContent);
	Items.RoleRepresentation.Visible = ValueIsFilled(ActionsOnForm.Roles);
	
	IsAllExternalUsersGroup = (Object.Ref = Catalogs.ExternalUserGroups.AllExternalUsers);
	
	ReadOnly = ReadOnly Or
	 Not IsAllExternalUsersGroup And
	 ActionsOnForm.Roles <> "Edit" And
	 ActionsOnForm.GroupContent <> "Edit" And
	 ActionsOnForm.ItemProperties <> "Edit";
	
	Items.Description.ReadOnly = IsAllExternalUsersGroup Or ActionsOnForm.ItemProperties <> "Edit";
	Items.Parent.ReadOnly = IsAllExternalUsersGroup Or ActionsOnForm.ItemProperties <> "Edit";
	Items.Comment.ReadOnly = IsAllExternalUsersGroup Or ActionsOnForm.ItemProperties <> "Edit";
	Items.GroupExternalUsers.ReadOnly = IsAllExternalUsersGroup Or ActionsOnForm.GroupContent <> "Edit";
	Items.Content.ReadOnly = IsAllExternalUsersGroup Or ActionsOnForm.GroupContent <> "Edit";
	Items.ContentFill.Enabled = Not (IsAllExternalUsersGroup Or ActionsOnForm.GroupContent <> "Edit");
	
	SetRolesReadOnly(ActionsOnForm.Roles <> "Edit");
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetPropertyEnabled();
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	FormInitialization();
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_ExternalUserGroups", New Structure, Object.Ref);
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	If Settings["ShowRoleSubsystems"] = False Then
		ShowRoleSubsystems = False;
		Items.RolesShowRoleSubsystems.Check = False;
	Else
		ShowRoleSubsystems = True;
		Items.RolesShowRoleSubsystems.Check = True;
	EndIf;
	
	HideFullAccessRole = True;
	RefreshRoleTree();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure ParentOnChange(Item)
	
	Object.AllAuthorizationObjects = False;
	
	SetPropertyEnabled();
	
EndProcedure

&AtClient
Procedure ParentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("ChooseParent");
	
	OpenForm("Catalog.ExternalUserGroups.ChoiceForm", FormParameters, Items.Parent);
	
EndProcedure

&AtClient
Procedure AuthorizationObjectTypePresentationOnChange(Item)
	
	If ValueIsFilled(AuthorizationObjectTypePresentation) Then
		DeleteNotTypicalExternalUsers();
	Else
		Object.AllAuthorizationObjects = False;
		Object.AuthorizationObjectType = Undefined;
	EndIf;
	
	SetPropertyEnabled();
	
EndProcedure

&AtClient
Procedure AuthorizationObjectTypePresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	SelectedItem = Undefined;

	
	ShowChooseFromList(New NotifyDescription("AuthorizationObjectTypePresentationStartChoiceEnd", ThisObject, New Structure("Item", Item)), AuthorizationObjectTypes, Item, AuthorizationObjectTypes.FindByValue(Object.AuthorizationObjectType));
	
EndProcedure

&AtClient
Procedure AuthorizationObjectTypePresentationStartChoiceEnd(SelectedItem1, AdditionalParameters) Export
    
    Item = AdditionalParameters.Item;
    
    
    SelectedItem = SelectedItem1;
    
    If SelectedItem <> Undefined Then
        
        Modified = True;
        Object.AuthorizationObjectType = SelectedItem.Value;
        AuthorizationObjectTypePresentation = SelectedItem.Presentation;
        
        AuthorizationObjectTypePresentationOnChange(Item);
    EndIf;

EndProcedure

&AtClient
Procedure AllAuthorizationObjectsOnChange(Item)
	
	If Object.AllAuthorizationObjects Then
		Object.Content.Clear();
	EndIf;
	
	SetPropertyEnabled();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedure and functuions to provide the role interface.

&AtClient
Procedure RolesCheckOnChange(Item)
	
	If Items.Roles.CurrentData <> Undefined Then
		UpdateRoleContent(Items.Roles.CurrentRow, Items.Roles.CurrentData.Check);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENT HANDLERS OF Content TABLE 

&AtClient
Procedure ContentChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If TypeOf(SelectedValue) = Type("Array") Then
		For Each Value In SelectedValue Do
			ExternalUserChoiceProcessing(Value);
		EndDo;
	Else
		ExternalUserChoiceProcessing(SelectedValue);
	EndIf;
	
EndProcedure

&AtClient
Procedure ContentExternalUserStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	ChooseFillUsers(False);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure FillExternalUsers(Command)

	ChooseFillUsers(True);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedure and functuions to provide the role interface.

&AtClient
Procedure ShowSelectedRolesOnly(Command)
	
	ShowSelectedRolesOnly = Not ShowSelectedRolesOnly;
	Items.RolesShowSelectedRolesOnly.Check = ShowSelectedRolesOnly;
	
	RefreshRoleTree();
	ExpandRoleSubsystems();
	
EndProcedure

&AtClient
Procedure ShowRoleSubsystems(Command)
	
	ShowRoleSubsystems = Not ShowRoleSubsystems;
	Items.RolesShowRoleSubsystems.Check = ShowRoleSubsystems;
	
	RefreshRoleTree();
	ExpandRoleSubsystems();
	
EndProcedure

&AtClient
Procedure CheckAll(Command)
	
	UpdateRoleContent(Undefined, True);
	If ShowSelectedRolesOnly Then
		ExpandRoleSubsystems();
	EndIf;
	
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	
	UpdateRoleContent(Undefined, False);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Procedure FormInitialization()
	
	// If an item is a new one, all roles must be shown, otherwise only selected roles must be shown
	ShowSelectedRolesOnly = ValueIsFilled(Object.Ref);
	Items.RolesShowSelectedRolesOnly.Check = ValueIsFilled(Object.Ref);
	//
	HideFullAccessRole = True;
	RefreshRoleTree();
	
EndProcedure

&AtServer
Procedure DefineActionsOnForm()
	
	ActionsOnForm = New Structure;
	ActionsOnForm.Insert("Roles", ""); // "", "View", "Edit"
	ActionsOnForm.Insert("GroupContent", ""); // "", "View", "Edit"
	ActionsOnForm.Insert("ItemProperties", ""); // "", "View", "Edit"
	
	If Users.InfoBaseUserWithFullAccess() Or
	 AccessRight("Insert", Metadata.Catalogs.Users) Then
		// Administrator
		ActionsOnForm.Roles = "Edit";
		ActionsOnForm.GroupContent = "Edit";
		ActionsOnForm.ItemProperties = "Edit";
		
	ElsIf IsInRole("AddEditExternalUsers") Then
		// External user manager
		ActionsOnForm.Roles = "";
		ActionsOnForm.GroupContent = "Edit";
		ActionsOnForm.ItemProperties = "Edit";
		
	Else
		// External user reader
		ActionsOnForm.Roles = "";
		ActionsOnForm.GroupContent = "View";
		ActionsOnForm.ItemProperties = "View";
	EndIf;
	
	UsersOverridable.ChangeActionsOnForm(Object.Ref, ActionsOnForm);
	
	// Verifying action names on the form
	If Find(", View, Edit,", ", " + ActionsOnForm.Roles + ",") = 0 Then
		ActionsOnForm.Roles = "";
	ElsIf UsersOverridable.RoleEditProhibition() Then
		ActionsOnForm.Roles = "";
	EndIf;
	If Find(", View, Edit,", ", " + ActionsOnForm.GroupContent + ",") = 0 Then
		ActionsOnForm.InfoBaseUserProperties = "";
	EndIf;
	If Find(", View, Edit,", ", " + ActionsOnForm.ItemProperties + ",") = 0 Then
		ActionsOnForm.ItemProperties = "";
	EndIf;
	
EndProcedure

&AtClient
Procedure SetPropertyEnabled()
	
	Items.Content.ReadOnly = Object.AllAuthorizationObjects;
	
	Items.ContentFill.Enabled = Not Items.Content.ReadOnly And Items.Content.Enabled;
	Items.ShortcutMenuContentFill.Enabled = Not Items.Content.ReadOnly And Items.Content.Enabled;
	Items.ContentAdd.Enabled = Not Items.Content.ReadOnly And Items.Content.Enabled;
	Items.ContextMenuContentAdd.Enabled = Not Items.Content.ReadOnly And Items.Content.Enabled;
	
	Items.AllAuthorizationObjects.Enabled = ValueIsFilled(AuthorizationObjectTypePresentation) And Not ValueIsFilled(Object.Parent);
	
EndProcedure

&AtServer
Procedure FillAuthorizationObjectTypeList()
	
	For Each AuthorizationObjectRefType In Metadata.Catalogs.ExternalUsers.Attributes.AuthorizationObject.Type.Types() Do
	
		TypeMetadata = Metadata.FindByType(AuthorizationObjectRefType);
		
		TypeArray = New Array;
		TypeArray.Add(AuthorizationObjectRefType);
		ReferenceTypeDescription = New TypeDescription(TypeArray);
		
		AuthorizationObjectTypes.Add(ReferenceTypeDescription.AdjustValue(Undefined), TypeMetadata.Synonym);
	EndDo;
	
	
	FoundItem = AuthorizationObjectTypes.FindByValue(Object.AuthorizationObjectType);
	AuthorizationObjectTypePresentation = ?(FoundItem = Undefined, "", FoundItem.Presentation);
	
EndProcedure

&AtServer
Procedure DeleteNotTypicalExternalUsers()
	
	Query = New Query(
	"SELECT
	|	ExternalUsers.Ref
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|WHERE
	|	VALUETYPE(ExternalUsers.AuthorizationObject) <> &AuthorizationObjectType
	|	AND ExternalUsers.Ref IN(&SelectedExternalUsers)");
	Query.SetParameter("SelectedExternalUsers", Object.Content.Unload().UnloadColumn("ExternalUser"));
	Query.SetParameter("AuthorizationObjectType", TypeOf(Object.AuthorizationObjectType));
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		FoundRows = Object.Content.FindRows(New Structure("ExternalUser", Selection.Ref));
		For Each FoundRow In FoundRows Do
			Object.Content.Delete(Object.Content.IndexOf(FoundRow));
		EndDo;
	EndDo;
	
EndProcedure

&AtClient
Procedure ChooseFillUsers(Fill)
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("CurrentRow", ?(Items.Content.CurrentData = Undefined, Undefined, Items.Content.CurrentData.ExternalUser));
	
	If Fill Then
		FormParameters.Insert("CloseOnChoice", False);
	EndIf;
	
	If Object.AuthorizationObjectType <> Undefined Then
		FormParameters.Insert("AuthorizationObjectType", Object.AuthorizationObjectType);
	EndIf;
	
	OpenForm("Catalog.ExternalUsers.ChoiceForm", FormParameters, ?(Fill, Items.Content, Items.ContentExternalUser));
	
EndProcedure

&AtClient
Procedure ExternalUserChoiceProcessing(SelectedValue)
	
	If TypeOf(SelectedValue) = Type("CatalogRef.ExternalUsers") Then
		If Object.Content.FindRows(New Structure("ExternalUser", SelectedValue)).Count() = 0 Then
			Object.Content.Add().ExternalUser = SelectedValue;
		EndIf;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedure and functuions to provide the role interface.

&AtServer
Function RoleCollection(ValueTableForReading = False)
	
	If ValueTableForReading Then
		Return Object.Roles.Unload();
	EndIf;
	
	Return Object.Roles;
	
EndFunction

&AtServer
Procedure SetRolesReadOnly(Val RolesReadOnly = Undefined, Val AllowViewSelectedOnly = False)
	
	If RolesReadOnly <> Undefined Then
		Items.Roles.ReadOnly = RolesReadOnly;
		Items.RolesCheckAll.Enabled = Not RolesReadOnly;
		Items.RolesUncheckAll.Enabled = Not RolesReadOnly;
	EndIf;
	
	If AllowViewSelectedOnly Then
		Items.RolesShowSelectedRolesOnly.Enabled = False;
	EndIf;
	
EndProcedure


&AtClient
Procedure ExpandRoleSubsystems(Collection = Undefined);
	
	If Collection = Undefined Then
		Collection = Roles.GetItems();
	EndIf;
	
	// Expand all subsystems
	For Each Row In Collection Do
		Items.Roles.Expand(Row.GetID());
		If Not Row.IsRole Then
			ExpandRoleSubsystems(Row.GetItems());
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure RefreshRoleTree()
	
	If Not Items.RolesShowSelectedRolesOnly.Enabled Then
		Items.RolesShowSelectedRolesOnly.Check = True;
		ShowSelectedRolesOnly = True;
	EndIf;
	
	// Storing the current row
	CurrentSubsystem = "";
	CurrentRole = "";
	//
	If Items.Roles.CurrentRow <> Undefined Then
		CurrentData = Roles.FindByID(Items.Roles.CurrentRow);
		If CurrentData.IsRole Then
			CurrentSubsystem = ?(CurrentData.GetParent() = Undefined, "", CurrentData.GetParent().Name);
			CurrentRole = CurrentData.Name;
		Else
			CurrentSubsystem = CurrentData.Name;
			CurrentRole = "";
		EndIf;
	EndIf;
	
	RoleTree = UsersServerCached.RoleTree(ShowRoleSubsystems).Copy();
	AddNonexistentRoleNames(RoleTree);
	RoleTree.Columns.Add("Check", New TypeDescription("Boolean"));
	RoleTree.Columns.Add("PictureNumber", New TypeDescription("Number"));
	PrepareRoleTree(RoleTree.Rows, HideFullAccessRole, ShowSelectedRolesOnly);
	
	ValueToFormAttribute(RoleTree, "Roles");
	
	Items.Roles.Representation = ?(RoleTree.Rows.Find(False, "IsRole") = Undefined, TableRepresentation.List, TableRepresentation.Tree);
	
	// Restoring the current row
	FoundRows = RoleTree.Rows.FindRows(New Structure("IsRole, Name", False, CurrentSubsystem), True);
	If FoundRows.Count() <> 0 Then
		SubsystemDetails = FoundRows[0];
		SubsystemIndex = ?(SubsystemDetails.Parent = Undefined, RoleTree.Rows, SubsystemDetails.Parent.Rows).IndexOf(SubsystemDetails);
		SubsystemRow = FormDataTreeItemCollection(Roles, SubsystemDetails).Get(SubsystemIndex);
		If ValueIsFilled(CurrentRole) Then
			FoundRows = SubsystemDetails.Rows.FindRows(New Structure("IsRole, Name", True, CurrentRole));
			If FoundRows.Count() <> 0 Then
				RoleDetails = FoundRows[0];
				Items.Roles.CurrentRow = SubsystemRow.GetItems().Get(SubsystemDetails.Rows.IndexOf(RoleDetails)).GetID();
			Else
				Items.Roles.CurrentRow = SubsystemRow.GetID();
			EndIf;
		Else
			Items.Roles.CurrentRow = SubsystemRow.GetID();
		EndIf;
	Else
		FoundRows = RoleTree.Rows.FindRows(New Structure("IsRole, Name", True, CurrentRole), True);
		If FoundRows.Count() <> 0 Then
			RoleDetails = FoundRows[0];
			RoleIndex = ?(RoleDetails.Parent = Undefined, RoleTree.Rows, RoleDetails.Parent.Rows).IndexOf(RoleDetails);
			RoleRow = FormDataTreeItemCollection(Roles, RoleDetails).Get(RoleIndex);
			Items.Roles.CurrentRow = RoleRow.GetID();
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure PrepareRoleTree(Val Collection, Val HideFullAccessRole, Val ShowSelectedRolesOnly)
	
	Index = Collection.Count()-1;
	
	While Index >= 0 Do
		Row = Collection[Index];
		
		PrepareRoleTree(Row.Rows, HideFullAccessRole, ShowSelectedRolesOnly);
		
		If Row.IsRole Then
			If HideFullAccessRole 
				And (Upper(Row.Name) = Upper("FullAccess") Or Upper(Row.Name) = Upper("FullAdministrator")) Then
				
				Collection.Delete(Index);
			Else
				Row.PictureNumber = 6;
				Row.Check = RoleCollection().FindRows(New Structure("Role", Row.Name)).Count() > 0;
				If ShowSelectedRolesOnly And Not Row.Check Then
					Collection.Delete(Index);
				EndIf;
			EndIf;
		Else
			If Row.Rows.Count() = 0 Then
				Collection.Delete(Index);
			Else
				Row.PictureNumber = 5;
				Row.Check = Row.Rows.FindRows(New Structure("Check", False)).Count() = 0;
			EndIf;
		EndIf;
		
		Index = Index-1;
	EndDo;
	
EndProcedure

&AtServer
Function FormDataTreeItemCollection(Val FormDataTree, Val ValueTreeRow)
	
	If ValueTreeRow.Parent = Undefined Then
		FormDataTreeItemCollection = FormDataTree.GetItems();
	Else
		ParentIndex = ?(ValueTreeRow.Parent.Parent = Undefined, ValueTreeRow.Owner().Rows, ValueTreeRow.Parent.Parent.Rows).IndexOf(ValueTreeRow.Parent);
		FormDataTreeItemCollection = FormDataTreeItemCollection(FormDataTree, ValueTreeRow.Parent).Get(ParentIndex).GetItems();
	EndIf;
	
	Return FormDataTreeItemCollection;
	
EndFunction


&AtServer
Procedure UpdateRoleContent(RowID, Add);
	
	If RowID = Undefined Then
		// Processing all roles
		RoleCollection = RoleCollection();
		RoleCollection.Clear();
		If Add Then
			AllRoles = UsersServerCached.AllRoles();
			For Each RoleDetails In AllRoles Do
				If RoleDetails.Name <> "FullAccess" And RoleDetails.Name <> "FullAdministrator" Then
					RoleCollection.Add().Role = RoleDetails.Name;
				EndIf;
			EndDo;
		EndIf;
		If ShowSelectedRolesOnly Then
			If RoleCollection.Count() > 0 Then
				RefreshRoleTree();
			Else
				Roles.GetItems().Clear();
			EndIf;
			// Return
			Return;
			// Return
		EndIf;
	Else
		CurrentData = Roles.FindByID(RowID);
		If CurrentData.IsRole Then
			AddDeleteRole(CurrentData.Name, Add);
		Else
			AddDeleteSubsystemRoles(CurrentData.GetItems(), Add);
		EndIf;
	EndIf;
	
	RefreshSelectedRoleMarks(Roles.GetItems());
	
	Modified = True;
	
EndProcedure

&AtServer
Procedure AddDeleteRole(Val Role, Val Add)
	
	FoundRoles = RoleCollection().FindRows(New Structure("Role", Role));
	
	If Add Then
		If FoundRoles.Count() = 0 Then
			RoleCollection().Add().Role = Role;
		EndIf;
	Else
		If FoundRoles.Count() > 0 Then
			RoleCollection().Delete(FoundRoles[0]);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure AddDeleteSubsystemRoles(Val Collection, Val Add)
	
	For Each Row In Collection Do
		If Row.IsRole Then
			AddDeleteRole(Row.Name, Add);
		Else
			AddDeleteSubsystemRoles(Row.GetItems(), Add);
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure RefreshSelectedRoleMarks(Val Collection)
	
	Index = Collection.Count()-1;
	
	While Index >= 0 Do
		Row = Collection[Index];
		
		If Row.IsRole Then
			Row.Check = RoleCollection().FindRows(New Structure("Role", Row.Name)).Count() > 0;
			If ShowSelectedRolesOnly And Not Row.Check Then
				Collection.Delete(Index);
			EndIf;
		Else
			RefreshSelectedRoleMarks(Row.GetItems());
			If Row.GetItems().Count() = 0 Then
				Collection.Delete(Index);
			Else
				Row.Check = True;
				For Each Item In Row.GetItems() Do
					If Not Item.Check Then
						Row.Check = False;
						Break;
					EndIf;
				EndDo;
			EndIf;
		EndIf;
		
		Index = Index-1;
	EndDo;
	
EndProcedure

&AtServer
Procedure AddNonexistentRoleNames(RoleTree)
	
	// Adding nonexistent roles
	For Each Row In RoleCollection() Do
		If RoleTree.Rows.FindRows(New Structure("IsRole, Name", True, Row.Role), True).Count() = 0 Then
			TreeRow = RoleTree.Rows.Insert(0);
			TreeRow.IsRole = True;
			TreeRow.Name = Row.Role;
			TreeRow.Synonym = "? " + Row.Role;
		EndIf;
	EndDo;
	
EndProcedure
