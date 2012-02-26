

//////////////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS
//

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	//** Assign initial values
	//   before loading data from settings at server
	//   for case, when data have not been recorded yet and are not being loaded
	ShowOnlySelectedRoles = (Items.RepresentationOfRoles.CurrentPage = Items.OnlySelectedRoles);
	
	//** Prepare constant data
	
	FillListOfObjectTypesOfAuthorization();
	
	PrepareChoiceListAndTableOfRoles();
	
	// Delete role FullAccess from choice list and table of roles
	ChoiceListOfRoles.Delete(ChoiceListOfRoles.FindByValue("FullAccess"));
	TableOfRoles.Delete(TableOfRoles.FindRows(New Structure("Name", "FullAccess"))[0]);
	
	//** Fill alterable data
	
	// On create using cloning
	If Object.Roles.Count() > 0 And NOT ValueIsFilled(Object.Roles[0].RoleSynonym) Then
		FillSynonymsOfRoleTabularSection();
	EndIf;
	
	If Object.Ref = Catalogs.ExternalUserGroups.EmptyRef() And
	     Object.Parent.Ref = Catalogs.ExternalUserGroups.AllExternalUsers Then
		
		Object.Parent = Catalogs.ExternalUserGroups.EmptyRef();
	EndIf;
	
	DefineActionsInForm();
	
	//** Assign constant accessibility of the properties
	
	Items.Description.Visible     		= ValueIsFilled(ActionsInForm.ItemProperties);
	Items.Parent.Visible         		= ValueIsFilled(ActionsInForm.ItemProperties);
	Items.Comment.Visible      			= ValueIsFilled(ActionsInForm.ItemProperties);
	Items.Content.Visible           	= ValueIsFilled(ActionsInForm.GroupContent);
	Items.RepresentationOfRoles.Visible = ValueIsFilled(ActionsInForm.Roles);
	
	ThisIsFolderAllExternalUsers = (Object.Ref = Catalogs.ExternalUserGroups.AllExternalUsers);
	
	ReadOnly = ReadOnly OR
	                 NOT ThisIsFolderAllExternalUsers And
	                 ActionsInForm.Roles <> "Edit" And
	                 ActionsInForm.GroupContent <> "Edit" And
	                 ActionsInForm.ItemProperties <> "Edit";
	
	Items.Description.ReadOnly          = ThisIsFolderAllExternalUsers OR ActionsInForm.ItemProperties <> "Edit";
	Items.Parent.ReadOnly               = ThisIsFolderAllExternalUsers OR ActionsInForm.ItemProperties <> "Edit";
	Items.Comment.ReadOnly              = ThisIsFolderAllExternalUsers OR ActionsInForm.ItemProperties <> "Edit";
	Items.ExternalUsersOfGroup.ReadOnly = ThisIsFolderAllExternalUsers OR ActionsInForm.GroupContent   <> "Edit";
	
	SetReadOnlyOfRoles(ActionsInForm.Roles <> "Edit");
	
	MarkRolesByList();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancellation)
	
	SetAccessibilityOfProperties();
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	FillSynonymsOfRoleTabularSection();
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	If CurrentObject.AdditionalProperties.Property("AreErrors") Then
		WriteParameters.Insert("AreErrors");
	EndIf;
	
	FillSynonymsOfRoleTabularSection();
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("ChangedGroupOfExternalUsers", Object.Ref, ThisForm);
	
	If WriteParameters.Property("AreErrors") Then
		DoMessageBox(NStr("en = 'Some errors occurred while writing (see event log)'"));
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancellation, CheckedAttributes)
	
	FillCheckProcessingOfRoleList(Cancellation);
	
	// Check unfilled and duplicated external users.
	LineNumber = Object.Content.Count()-1;
	
	While NOT Cancellation And LineNumber >= 0 Do
		CurrentRow = Object.Content.Get(LineNumber);
		
		// Check that value is filled.
		If NOT ValueIsFilled(CurrentRow.ExternalUser) Then
			CommonUseClientServer.MessageToUser(NStr("en = 'External user is not selected!'"),
			                                                  ,
			                                                  "Object.Content[" + Format(LineNumber, "NG=0") + "].ExternalUser",
			                                                  ,
			                                                  Cancellation);
			Break;
		EndIf;
		
		// Check duplicated values.
		ValuesFound = Object.Content.FindRows(New Structure("ExternalUser", CurrentRow.ExternalUser));
		If ValuesFound.Count() > 1 Then
			CommonUseClientServer.MessageToUser(NStr("en = 'External user is not unique!'"),
			                                                  ,
			                                                  "Object.Content[" + Format(LineNumber, "NG=0") + "].ExternalUser",
			                                                  ,
			                                                  Cancellation);
			Break;
		EndIf;
			
		LineNumber = LineNumber - 1;
	EndDo;
	
	If Cancellation Then
		CheckedAttributes.Clear();
	EndIf;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	If Settings["ShowOnlySelectedRoles"] = False Then
		Items.RepresentationOfRoles.CurrentPage = Items.AmongAllSelectedRoles;
	Else
		Items.RepresentationOfRoles.CurrentPage = Items.OnlySelectedRoles;
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// Event handlers of commands and form items
//

&AtClient
Procedure ParentOnChange(Item)
	
	Object.AllAuthorizationObjects = False;
	
	SetAccessibilityOfProperties();
	
EndProcedure

&AtClient
Procedure ParentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("ParentChoice");
	
	OpenForm("Catalog.ExternalUserGroups.ChoiceForm", FormParameters, Items.Parent);
	
EndProcedure

&AtClient
Procedure PresentationOfAuthorizationObjectsTypeOnChange(Item)
	
	If ValueIsFilled(PresentationOfAuthorizationObjectsType) Then
		DeleteNotTypicalExternalUsers();
	Else
		Object.AllAuthorizationObjects  = False;
		Object.AuthorizationObjectType = Undefined;
	EndIf;
	
	SetAccessibilityOfProperties();
	
EndProcedure

&AtClient
Procedure PresentationOfAuthorizationObjectsTypeStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	SelectedElement = ChooseFromList(TypesOfAuthorizationObjects, Item, TypesOfAuthorizationObjects.FindByValue(Object.AuthorizationObjectType));
	
	If SelectedElement <> Undefined Then
		
		Modified = True;
		Object.AuthorizationObjectType      = SelectedElement.Value;
		PresentationOfAuthorizationObjectsType = SelectedElement.Presentation;
		
		PresentationOfAuthorizationObjectsTypeOnChange(Item);
	EndIf;
	
EndProcedure

&AtClient
Procedure AllAuthorizationObjectsOnChange(Item)
	
	If Object.AllAuthorizationObjects Then
		Object.Content.Clear();
	EndIf;
	
	SetAccessibilityOfProperties();
	
EndProcedure

&AtClient
Procedure FillExternalUsers(Command)

	SelectFillUsers(True);
	
EndProcedure

&AtClient
Procedure ContentChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	If TypeOf(ValueSelected) = Type("Array") Then
		For each Value In ValueSelected Do
			ChoiceProcessingOfExternalUser(Value);
		EndDo;
	Else
		ChoiceProcessingOfExternalUser(ValueSelected);
	EndIf;
	
EndProcedure

&AtClient
Procedure ContentExternalUserStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	SelectFillUsers(False);
	
EndProcedure

//** For operation of the roles interface

&AtClient
Procedure FillRoles(Command)
	
	OpenForm("Catalog.Users.Form.ChoiceFormRoles", New Structure("CloseOnChoice", False), Items.Roles);
	
EndProcedure

&AtClient
Procedure RolesOnChange(Item)
	
	MarkRolesByList();
	
EndProcedure

&AtClient
Procedure RolesOnEditEnd(Item, NewRow, CancelEdit)
	
	MarkRolesByList();
	
EndProcedure

&AtClient
Procedure RolesChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	AddSelectedRoles(ValueSelected);
	
EndProcedure


&AtClient
Procedure RoleSynonymOnChange(Item)
	
	If ValueIsFilled(Items.Roles.CurrentData.RoleSynonym) Then
		Items.Roles.CurrentData.RoleSynonym = ChoiceListOfRoles.FindByValue(Items.Roles.CurrentData.Role).Presentation;
	Else
		Items.Roles.CurrentData.Role = "";
	EndIf;
	
EndProcedure

&AtClient
Procedure RoleSynonymStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	InitialValue = ?(Items.Roles.CurrentData = Undefined, Undefined, Items.Roles.CurrentData.Role);
	OpenForm("Catalog.Users.Form.ChoiceFormRoles", New Structure("CurrentRow", InitialValue), Item);

EndProcedure

&AtClient
Procedure RoleSynonymChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	Items.Roles.CurrentData.Role        = ValueSelected;
	Items.Roles.CurrentData.RoleSynonym = ChoiceListOfRoles.FindByValue(Items.Roles.CurrentData.Role).Presentation;
	
EndProcedure

&AtClient
Procedure RoleSynonymAutoComplete(Item, Text, ChoiceData, Wait, StandardProcessing)
	
	If ValueIsFilled(Text) Then 
		StandardProcessing = False;
		ChoiceData = GenerateRolesChoiceData(Text);
	EndIf;
	
EndProcedure

&AtClient
Procedure RoleSynonymTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	If ValueIsFilled(Text) Then 
		StandardProcessing = False;
		ChoiceData = GenerateRolesChoiceData(Text);
	EndIf;
	
EndProcedure


&AtClient
Procedure TableOfRolesCheckOnChange(Item)
	
	TableRow = Items.TableOfRoles.CurrentData;
	
	RolesFound = Object.Roles.FindRows(New Structure("Role", TableRow.Name));
	
	If TableRow.Check Then
		If RolesFound.Count() = 0 Then
			String = Object.Roles.Add();
			String.Role = TableRow.Name;
			String.RoleSynonym = TableRow.Synonym;
		EndIf;
	ElsIf RolesFound.Count() > 0 Then
		Object.Roles.Delete(RolesFound[0]);
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowOnlySelectedRoles(Command)
	
	ShowOnlySelectedRoles = NOT ShowOnlySelectedRoles;
	
	Items.RepresentationOfRoles.CurrentPage = ?(ShowOnlySelectedRoles, Items.OnlySelectedRoles, Items.AmongAllSelectedRoles);
	CurrentItem = ?(ShowOnlySelectedRoles, Items.Roles, Items.TableOfRoles);
	
EndProcedure

&AtClient
Procedure CheckAll(Command)
	
	MarkAllAtServer();
	
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	
	UncheckAllAtServer();
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// Auxiliary form procedures and functions
//

&AtServer
Procedure DefineActionsInForm()
	
	ActionsInForm = New Structure;
	ActionsInForm.Insert("Roles",         	""); // "", "View",     "Edit"
	ActionsInForm.Insert("GroupContent",    ""); // "", "View",     "Edit"
	ActionsInForm.Insert("ItemProperties",  ""); // "", "View",     "Edit"
	
	If Users.CurrentUserHaveFullAccess() OR
	     AccessRight("Insert", Metadata.Catalogs.Users) Then
		// Administrator
		ActionsInForm.Roles                 = "Edit";
		ActionsInForm.GroupContent          = "Edit";
		ActionsInForm.ItemProperties       	= "Edit";
		
	ElsIf IsInRole("AddChangeExternalUsers") Then
		// External users manager
		ActionsInForm.Roles                 = "";
		ActionsInForm.GroupContent          = "Edit";
		ActionsInForm.ItemProperties       	= "Edit";
		
	Else
		// External users reader
		ActionsInForm.Roles                 = "";
		ActionsInForm.GroupContent          = "View";
		ActionsInForm.ItemProperties       	= "View";
	EndIf;
	
	UsersOverrided.ChangeActionsInForm(Object.Ref, ActionsInForm);
	
	// Check action names in the form
	If Find(", View, Edit,", ", " + ActionsInForm.Roles + ",") = 0 Then
		ActionsInForm.Roles = "";
	ElsIf UsersOverrided.RolesEditingProhibited() Then
		ActionsInForm.Roles = "";
	EndIf;
	If Find(", View, Edit,", ", " + ActionsInForm.GroupContent + ",") = 0 Then
		ActionsInForm.IBUserProperties = "";
	EndIf;
	If Find(", View, Edit,", ", " + ActionsInForm.ItemProperties + ",") = 0 Then
		ActionsInForm.ItemProperties = "";
	EndIf;
	
EndProcedure

&AtClient
Procedure SetAccessibilityOfProperties()
	
	Items.Content.Enabled = NOT Object.AllAuthorizationObjects;
	
	Items.FillContent.Enabled             = NOT Items.Content.ReadOnly And Items.Content.Enabled;
	Items.ContextMenuContentFill.Enabled  = NOT Items.Content.ReadOnly And Items.Content.Enabled;
	Items.ContentAdd.Enabled              = NOT Items.Content.ReadOnly And Items.Content.Enabled;
	Items.ContextMenuContentAdd.Enabled   = NOT Items.Content.ReadOnly And Items.Content.Enabled;
	
	Items.AllAuthorizationObjects.Enabled = ValueIsFilled(PresentationOfAuthorizationObjectsType) And NOT ValueIsFilled(Object.Parent);
	
EndProcedure


&AtServer
Procedure FillListOfObjectTypesOfAuthorization()
	
	For each AuthorizationObjectRefType IN Metadata.Catalogs.ExternalUsers.Attributes.AuthorizationObject.Type.Types() Do
	
		MetadataOfType = Metadata.FindByType(AuthorizationObjectRefType);
		
		ArrayOfTypes = New Array;
		ArrayOfTypes.Add(AuthorizationObjectRefType);
		DetailsOfRefType = New TypeDescription(ArrayOfTypes);
		
		TypesOfAuthorizationObjects.Add(DetailsOfRefType.AdjustValue(Undefined), MetadataOfType.Synonym);
	EndDo;
	
	
	ItemFound = TypesOfAuthorizationObjects.FindByValue(Object.AuthorizationObjectType);
	PresentationOfAuthorizationObjectsType = ?(ItemFound = Undefined, "", ItemFound.Presentation);
	
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
	|	And ExternalUsers.Ref In(&SelectedExternalUsers)");
	Query.SetParameter("SelectedExternalUsers", Object.Content.Unload().UnloadColumn("ExternalUser"));
	Query.SetParameter("AuthorizationObjectType", TypeOf(Object.AuthorizationObjectType));
	
	Selection = Query.Execute().Choose();
	While Selection.Next() Do
		RowsFound = Object.Content.FindRows(New Structure("ExternalUser", Selection.Ref));
		For each StringFound In RowsFound Do
			Object.Content.Delete(Object.Content.IndexOf(StringFound));
		EndDo;
	EndDo;
	
EndProcedure


&AtClient
Procedure SelectFillUsers(Fill)
	
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
Procedure ChoiceProcessingOfExternalUser(ValueSelected)
	
	If TypeOf(ValueSelected) = Type("CatalogRef.ExternalUsers") Then
		If Object.Content.FindRows(New Structure("ExternalUser", ValueSelected)).Count() = 0 Then
			Object.Content.Add().ExternalUser = ValueSelected;
		EndIf;
	EndIf;
	
EndProcedure


//** For operation of the roles interface

&AtServer
Procedure MarkAllAtServer()
	
	For each TableRow In TableOfRoles Do
		
		TableRow.Check = True;
		
		RolesFound = Object.Roles.FindRows(New Structure("Role", TableRow.Name));
		If RolesFound.Count() = 0 Then
			String = Object.Roles.Add();
			String.Role = TableRow.Name;
			String.RoleSynonym = TableRow.Synonym;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure UncheckAllAtServer()
	
	For each TableRow In TableOfRoles Do
		
		TableRow.Check = False;
		
		RolesFound = Object.Roles.FindRows(New Structure("Role", TableRow.Name));
		If RolesFound.Count() > 0 Then
			Object.Roles.Delete(RolesFound[0]);
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure AddSelectedRoles(SelectedRoles)
	
	For each Value In SelectedRoles Do
	
		ItemOfList = ChoiceListOfRoles.FindByValue(Value);
		If ItemOfList <> Undefined Then
			
			If Object.Roles.FindRows(New Structure("Role", Value)).Count() = 0 Then
				
				String 				= Object.Roles.Add();
				String.Role        	= ItemOfList.Value;
				String.RoleSynonym 	= ItemOfList.Presentation;
			EndIf;
		EndIf;
	EndDo;
	
	MarkRolesByList();
	
EndProcedure

&AtServer
Procedure FillSynonymsOfRoleTabularSection()
	
	AllRoles = UsersServerSecondUse.AllRoles();
	
	For each String In Object.Roles Do
		
		StringFound = AllRoles.Find(String.Role, "Name");
		String.RoleSynonym = ?(StringFound = Undefined, "? " + String.Role, StringFound.Synonym);
	EndDo;
	
EndProcedure

&AtServer
Procedure PrepareChoiceListAndTableOfRoles()
	
	AllRoles = UsersServerSecondUse.AllRoles();
	AllRoles.Sort("Synonym");
	
	For each String In AllRoles Do
		// Fill choice list
		ChoiceListOfRoles.Add(String.Name, String.Synonym);
		// Fill table of roles
		TableRow = TableOfRoles.Add();
		FillPropertyValues(TableRow, String);
	EndDo;
	
EndProcedure

&AtServer
Procedure SetReadOnlyOfRoles(Val ReadOnlyOfRoles)
	
	Items.Roles.ReadOnly         			= ReadOnlyOfRoles;
	Items.TableOfRoles.ReadOnly 			= ReadOnlyOfRoles;
	
	Items.FillRoles.Enabled                	= NOT ReadOnlyOfRoles;
	Items.ContextMenuRolesFill.Enabled 		= NOT ReadOnlyOfRoles;
	Items.TableOfRolesCheckAll.Enabled 		= NOT ReadOnlyOfRoles;
	Items.TableOfRolesUncheckAll.Enabled    = NOT ReadOnlyOfRoles;
	
EndProcedure

&AtServer
Procedure MarkRolesByList()
	
	For each TableRow In TableOfRoles Do
		
		TableRow.Check = Object.Roles.FindRows(New Structure("Role", TableRow.Name)).Count() > 0;
		
	EndDo;
	
EndProcedure

&AtClient
Function GenerateRolesChoiceData(Text)
	
	List = ChoiceListOfRoles.Copy();
	
	ItemNumber = List.Count()-1;
	While ItemNumber >= 0 Do
		If Upper(Left(List[ItemNumber].Presentation, StrLen(Text))) <> Upper(Text) Then
			List.Delete(ItemNumber);
		EndIf;
		ItemNumber = ItemNumber - 1;
	EndDo;
	
	Return List;
	
EndFunction

&AtServer
Procedure FillCheckProcessingOfRoleList(Cancellation)
	
	// Check unfilled and duplicated roles.
	LineNumber = Object.Roles.Count()-1;
	While NOT Cancellation And LineNumber >= 0 Do
	
		CurrentRow = Object.Roles.Get(LineNumber);
		
		// Check that value is filled.
		If NOT ValueIsFilled(CurrentRow.RoleSynonym) Then
			CommonUseClientServer.MessageToUser(NStr("en = 'Role is not selected!'"),
			                                                  ,
			                                                  "Object.Roles[" + Format(LineNumber, "NG=0") + "].RoleSynonym",
			                                                  ,
			                                                  Cancellation);
			Return;
		EndIf;
		
		// Check duplicated values.
		ValuesFound = Object.Roles.FindRows(New Structure("Role", CurrentRow.Role));
		If ValuesFound.Count() > 1 Then
			CommonUseClientServer.MessageToUser( NStr("en = 'Role is not unique!'"),
			                                                  ,
			                                                  "Object.Roles[" + Format(LineNumber, "NG=0") + "].RoleSynonym",
			                                                  ,
			                                                  Cancellation);
			Return;
		EndIf;
			
		LineNumber = LineNumber - 1;
	EndDo;
	
EndProcedure


