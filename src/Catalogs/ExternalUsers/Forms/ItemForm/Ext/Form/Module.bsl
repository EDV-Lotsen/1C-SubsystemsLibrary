////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	//** Setting initial values before importing settings from the server
	//   if data was not written and there is nothing to import.
	ShowRoleSubsystems = True;
	Items.RolesShowRoleSubsystems.Check = True;
	// If the item is a new one, all roles are shown, otherwise only selected roles are shown
	ShowSelectedRolesOnly                  = ValueIsFilled(Object.Ref);
	Items.RolesShowSelectedRolesOnly.Check = ValueIsFilled(Object.Ref);
	//
	HideFullAccessRole = True;
	RefreshRoleTree();
	
	
	//** Filling permanent data
	RoleEditProhibition = UsersOverridable.RoleEditProhibition();
	FullAccessUserAuthorized = Users.InfoBaseUserWithFullAccess();
	
	// Filling the language choice list
	For Each LanguageMetadata In Metadata.Languages Do
		Items.LanguagePresentation.ChoiceList.Add(LanguageMetadata.Synonym);
	EndDo;
	
	//** Preparing to process interactive actions according to form opening scenarios
	
	SetPrivilegedMode(True);
	
	If Not ValueIsFilled(Object.Ref) Then
		// Creating a new item
		If Parameters.NewExternalUserGroup <> Catalogs.ExternalUserGroups.AllExternalUsers Then
			NewExternalUserGroup = Parameters.NewExternalUserGroup;
		EndIf;
		If ValueIsFilled(Parameters.CopyingValue) Then
			// Coping the item
			Object.AuthorizationObject = Undefined;
			Object.Description      = "";
			Object.Code               = "";
			Object.DeletePassword     = "";
			ReadInfoBaseUser(ValueIsFilled(Parameters.CopyingValue.InfoBaseUserID));
		Else
			// Adding the item
			If Parameters.Property("NewExternalUserAuthorizationObject") Then
				Object.AuthorizationObject = Parameters.NewExternalUserAuthorizationObject;
				IsAuthorizationObjectSetOnOpen = ValueIsFilled(Object.AuthorizationObject);
				AuthorizationObjectOnChangeAtClientAtServer(ThisForm, Object);
			ElsIf ValueIsFilled(NewExternalUserGroup) Then
				AuthorizationObjectType = CommonUse.GetAttributeValue(NewExternalUserGroup, "AuthorizationObjectType");
				Object.AuthorizationObject = AuthorizationObjectType;
				Items.AuthorizationObject.ChooseType = AuthorizationObjectType = Undefined;
			EndIf;
			// Reading initial values of infobase user properties
			ReadInfoBaseUser();
		EndIf;
	Else
		// Opening the existent item
		ReadInfoBaseUser();
	EndIf;
	
	SetPrivilegedMode(False);
	
	DefineActionsOnForm();
	
	FindUserAndInfoBaseUserInconsistencies();
	
	//** Setting permanent property availability
	Items.InfoBaseUserProperties.Visible = ValueIsFilled(ActionsOnForm.InfoBaseUserProperties);
	Items.RoleRepresentation.Visible    = ValueIsFilled(ActionsOnForm.Roles);
	Items.SetRolesDirectly.Visible       = ValueIsFilled(ActionsOnForm.Roles) And Not UsersOverridable.RoleEditProhibition();
	
	Items.SetRolesDirectly.Enabled = ActionsOnForm.Roles = "Edit";
	
	ReadOnly = ReadOnly Or
	                 ActionsOnForm.Roles <> "Edit" And
	                 Not (ActionsOnForm.InfoBaseUserProperties = "EditAll" Or
	                      ActionsOnForm.InfoBaseUserProperties = "EditOwn") And
	                 ActionsOnForm.ItemProperties <> "Edit";
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetPropertyEnabled();
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	CurrentAuthorizationObjectPresentation = String(Object.AuthorizationObject);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel)
	
	ClearMessages();
	
	If ActionsOnForm.Roles = "Edit" And Object.SetRolesDirectly And InfoBaseUserRoles.Count() = 0 Then
		
		ShowMessageBox(, NStr("en='No role specified for the infobase user. Select at least one role.'"),
		            , NStr("en='Writing infobase user'"));
		Cancel = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If ActionsOnForm.ItemProperties <> "Edit" Then
		FillPropertyValues(CurrentObject, CommonUse.GetAttributeValues(CurrentObject.Ref, "Description, DeletionMark"));
	EndIf;
	
	If ExternalUsers.AuthorizationObjectUsed(Object.AuthorizationObject, Object.Ref) Then
		
		CommonUseClientServer.MessageToUser(
						NStr("en = 'The infobase object is already used for another external user.'"), ,
						"Object.AuthorizationObject", ,
						Cancel);
		Return;
	EndIf;
	
	CurrentObject.AdditionalProperties.Insert("NewExternalUserGroup", NewExternalUserGroup);
	
	If InfoBaseAccessAllowed Then
		
		WriteIBUser(CurrentObject, Cancel);
		If Not Cancel Then
			If CurrentObject.InfoBaseUserID <> OldInfoBaseUserID Then
				WriteParameters.Insert("InfoBaseUserAdded", CurrentObject.InfoBaseUserID);
			Else
				WriteParameters.Insert("InfoBaseUserChanged", CurrentObject.InfoBaseUserID);
			EndIf
		EndIf;
		
	ElsIf Not HasRelationToNonexistentInfoBaseUser Or
	          ActionsOnForm.InfoBaseUserProperties = "EditAll" Then
		
		CurrentObject.InfoBaseUserID = Undefined;
	EndIf;
	
	SetPrivilegedMode(True);
	
	CurrentAuthorizationObjectPresentation = String(CurrentObject.AuthorizationObject);
	CurrentObject.Description = CurrentAuthorizationObjectPresentation;
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Not InfoBaseAccessAllowed And InfoBaseUserExists Then
		DeleteInfoBaseUser(Cancel);
		If Not Cancel Then
			WriteParameters.Insert("InfoBaseUserDeleted", OldInfoBaseUserID);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	ReadInfoBaseUser();
	
	FindUserAndInfoBaseUserInconsistencies(WriteParameters);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_ExternalUsers", New Structure, Object.Ref);
	
	If WriteParameters.Property("InfoBaseUserAdded") Then
		Notify("InfoBaseUserAdded", WriteParameters.InfoBaseUserAdded, ThisForm);
		
	ElsIf WriteParameters.Property("InfoBaseUserChanged") Then
		Notify("InfoBaseUserChanged", WriteParameters.InfoBaseUserChanged, ThisForm);
		
	ElsIf WriteParameters.Property("InfoBaseUserDeleted") Then
		Notify("InfoBaseUserDeleted", WriteParameters.InfoBaseUserDeleted, ThisForm);
		
	ElsIf WriteParameters.Property("NonexistentInfoBaseUserRelationCleared") Then
		Notify("NonexistentInfoBaseUserRelationCleared", WriteParameters.NonexistentInfoBaseUserRelationCleared, ThisForm);
	EndIf;
	
	If ValueIsFilled(NewExternalUserGroup) Then
		NotifyChanged(NewExternalUserGroup);
		Notify("Write_ExternalUserGroups", New Structure, NewExternalUserGroup);
		NewExternalUserGroup = Undefined;
	EndIf;
	
	SetPropertyEnabled();
	
	ExpandRoleSubsystems();
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, AttributesToCheck)
	
	If InfoBaseAccessAllowed Then
		
		If Not Cancel And IsBlankString(InfoBaseUserName) Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'The infobase user name is not filled.'"),
				,
				"InfoBaseUserName",
				,
				Cancel);
		EndIf;
		
		If Not Cancel And InfoBaseUserPassword <> Undefined  And Password <> PasswordConfirmation Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'The password and password confirmation do not match.'"),
				,
				"Password",
				,
				Cancel);
		EndIf;
		
		If CreateFirstAdministratorRequired() Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'The first infobase user must have full rights but an external user cannot have them. You must create an ordinary user with administrative rights first.'"),
				,
				"InfoBaseAccessAllowed",
				,
				Cancel);
		EndIf;
	EndIf;
	
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
Procedure AuthorizationObjectOnChange(Item)
	
	AuthorizationObjectOnChangeAtClientAtServer(ThisForm, Object);
	
EndProcedure

&AtClient
Procedure InfoBaseAccessAllowedOnChange(Item)
	
	If Not InfoBaseUserExists And InfoBaseAccessAllowed Then
		InfoBaseUserName = GetInfoBaseUserShortName(CurrentAuthorizationObjectPresentation);
	EndIf;
	
	SetPropertyEnabled();
	
EndProcedure

&AtClient
Procedure PasswordOnChange(Item)
	
	InfoBaseUserPassword = Password;
	
EndProcedure

&AtClient
Procedure SetRolesDirectlyOnChange(Item)
	
	If Not Object.SetRolesDirectly Then
		ReadInfoBaseUser(, True);
		ExpandRoleSubsystems();
	EndIf;
	
	SetPropertyEnabled();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENT HANDLERS OF Roles TABLE 

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions that provide the role interface

&AtClient
Procedure RolesCheckOnChange(Item)
	
	If Items.Roles.CurrentData <> Undefined Then
		UpdateRoleContent(Items.Roles.CurrentRow, Items.Roles.CurrentData.Check);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions that provide the role interface

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
Function CreateFirstAdministratorRequired()
	
	SetPrivilegedMode(True);
	
	Return InfoBaseUsers.GetUsers().Count() = 0;
	
EndFunction

&AtServer
Procedure DefineActionsOnForm()
	
	ActionsOnForm = New Structure;
	ActionsOnForm.Insert("Roles",                  ""); // "", "View",    "Edit"
	ActionsOnForm.Insert("InfoBaseUserProperties", ""); // "", "ViewAll", "EditAll", "EditOwn"
	ActionsOnForm.Insert("ItemProperties",         ""); // "", "View",    "Edit"
	
	If Users.InfoBaseUserWithFullAccess() Or
	     AccessRight("Insert", Metadata.Catalogs.Users) Then
		// Administrator
		ActionsOnForm.Roles                   = "Edit";
		ActionsOnForm.InfoBaseUserProperties = "EditAll";
		ActionsOnForm.ItemProperties       = "Edit";
		
	ElsIf IsInRole("AddEditExternalUsers") Then
		// External user manager
		ActionsOnForm.Roles                   = "";
		ActionsOnForm.InfoBaseUserProperties = "EditAll";
		ActionsOnForm.ItemProperties       = "View";
		
	ElsIf ValueIsFilled(ExternalUsers.CurrentExternalUser()) And
	          Object.Ref = ExternalUsers.CurrentExternalUser() Then
		// Own properties
		ActionsOnForm.Roles                   = "";
		ActionsOnForm.InfoBaseUserProperties = "EditOwn";
		ActionsOnForm.ItemProperties       = "View";
	Else
		// External user reader
		ActionsOnForm.Roles                   = "";
		ActionsOnForm.InfoBaseUserProperties = "";
		ActionsOnForm.ItemProperties       = "View";
	EndIf;
	
	If Not ValueIsFilled(Object.Ref) And Not ValueIsFilled(Object.AuthorizationObject) Then
		ActionsOnForm.ItemProperties       = "Edit";
	EndIf;
	
	UsersOverridable.ChangeActionsOnForm(Object.Ref, ActionsOnForm);
	
	// Verifying action names on the form
	If Find(", View, Edit,", ", " + ActionsOnForm.Roles + ",") = 0 Then
		ActionsOnForm.Roles = "";
	ElsIf UsersOverridable.RoleEditProhibition() Then
		ActionsOnForm.Roles = "View";
	EndIf;
	If Find(", ViewAll, EditAll, EditOwn,", ", " + ActionsOnForm.InfoBaseUserProperties + ",") = 0 Then
		ActionsOnForm.InfoBaseUserProperties = "";
	EndIf;
	If Find(", View, Edit,", ", " + ActionsOnForm.ItemProperties + ",") = 0 Then
		ActionsOnForm.ItemProperties = "";
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure AuthorizationObjectOnChangeAtClientAtServer(Context, Object)
	
	If Object.AuthorizationObject = Undefined Then
		Object.AuthorizationObject = Context.AuthorizationObjectType;
	EndIf;
	
	If Context.CurrentAuthorizationObjectPresentation <> String(Object.AuthorizationObject) Then
		
		Context.CurrentAuthorizationObjectPresentation = String(Object.AuthorizationObject);
		
		If Not Context.InfoBaseUserExists And Context.InfoBaseAccessAllowed Then
			Context.InfoBaseUserName = GetInfoBaseUserShortName(Context.CurrentAuthorizationObjectPresentation);
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Reading, writing, deleting, creating an infobase user short name, checking for inconsistencies.

&AtServer
Procedure ReadInfoBaseUser(OnCopyItem = False, RolesOnly = False)
	
	SetPrivilegedMode(True);
	
	ReadRoles = Undefined;
	
	If RolesOnly Then
		Users.ReadInfoBaseUser(Object.InfoBaseUserID, , ReadRoles);
		FillRoles(ReadRoles);
		Return;
	EndIf;
	
	Password              = "";
	PasswordConfirmation  = "";
	ReadProperties        = Undefined;
	OldInfoBaseUserID     = Undefined;
	InfoBaseUserExists    = False;
	InfoBaseAccessAllowed = False;
	
	// Filling initial InfoBaseUser property values for the user.
	Users.ReadInfoBaseUser(Undefined, ReadProperties, ReadRoles);
	FillPropertyValues(ThisForm, ReadProperties);
	
	If OnCopyItem Then
		
		If Users.ReadInfoBaseUser(Parameters.CopyingValue.InfoBaseUserID, ReadProperties, ReadRoles) Then
			// Setting a future relation for a new user.
			// because the copied one has a relation with InfoBaseUser,
			InfoBaseAccessAllowed = True;
			// Copping properties and roles of InfoBaseUser,
			// because InfoBaseUser of the copied user has been read.
			FillPropertyValues(ThisForm,
			                         ReadProperties,
			                         "InfoBaseUserCannotChangePassword");
		EndIf;
		Object.InfoBaseUserID = Undefined;
	Else
		If Users.ReadInfoBaseUser(Object.InfoBaseUserID, ReadProperties, ReadRoles) Then
		
			InfoBaseUserExists    = True;
			InfoBaseAccessAllowed = True;
			OldInfoBaseUserID     = Object.InfoBaseUserID;
			
			FillPropertyValues(ThisForm,
			                   ReadProperties,
			                   "InfoBaseUserName,
			                   |InfoBaseUserCannotChangePassword");
			
			If ReadProperties.InfoBaseUserPasswordIsSet Then
				Password             = "**********";
				PasswordConfirmation = "**********";
			EndIf;
		EndIf;
	EndIf;
	
	FillLanguagePresentation(ReadProperties.InfoBaseUserLanguage);
	FillRoles(ReadRoles);
	
EndProcedure

&AtServer
Procedure WriteIBUser(CurrentObject, Cancel)
	
	// Restoring actions on the form if they have been changed on a client
	DefineActionsOnForm();
	
	If Not (ActionsOnForm.InfoBaseUserProperties = "EditAll" Or
	         ActionsOnForm.InfoBaseUserProperties = "EditOwn")Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	InitialProperties = Undefined;
	NewProperties     = Undefined;
	NewRoles          = Undefined;
	
	// Reading old properties and filling InfobaseUser and User initial properties.
	Users.ReadInfoBaseUser(CurrentObject.InfoBaseUserID, NewProperties);
	NewProperties.InfoBaseUserFullName                 = String(CurrentObject.AuthorizationObject);
	NewProperties.InfoBaseUserStandardAuthentication = True;
	
	Users.ReadInfoBaseUser(Undefined, InitialProperties);
	FillPropertyValues(NewProperties,
	                         InitialProperties,
	                         "InfoBaseUserShowInList,
	                         |InfoBaseUserOSAuthentication,
	                         |InfoBaseUserDefaultInterface,
	                         |InfoBaseUserRunMode");
	
	If ActionsOnForm.InfoBaseUserProperties = "EditAll" Then
		FillPropertyValues(NewProperties,
		                         ThisForm,
		                         "InfoBaseUserName,
		                         |InfoBaseUserPassword,
		                         |InfoBaseUserCannotChangePassword");
	Else
		FillPropertyValues(NewProperties,
		                         ThisForm,
		                         "InfoBaseUserName,
		                         |InfoBaseUserPassword");
	EndIf;
	NewProperties.InfoBaseUserLanguage = GetSelectedLanguage();
		
	If ActionsOnForm.Roles = "Edit" And Object.SetRolesDirectly Then
		NewRoles = InfoBaseUserRoles.Unload(, "Role").UnloadColumn("Role");
	EndIf;
	
	// Attempting to write the infobase user
	ErrorDescription = "";
	If Users.WriteIBUser(CurrentObject.InfoBaseUserID, NewProperties, NewRoles, Not InfoBaseUserExists, ErrorDescription) Then
		If Not InfoBaseUserExists Then
			CurrentObject.InfoBaseUserID = NewProperties.InfoBaseUserUUID;
			InfoBaseUserExists = True;
		EndIf;
	Else
		Cancel = True;
		CommonUseClientServer.MessageToUser(ErrorDescription);
	EndIf;
	
EndProcedure

&AtServer
Function DeleteInfoBaseUser(Cancel)
	
	SetPrivilegedMode(True);
	
	ErrorDescription = "";
	If Not Users.DeleteInfoBaseUser(OldInfoBaseUserID, ErrorDescription) Then
		CommonUseClientServer.MessageToUser(ErrorDescription, , , , Cancel);
	EndIf;
	
EndFunction

&AtClientAtServerNoContext
Function GetInfoBaseUserShortName(Val FullName)
	
	ShortName = "";
	FirstLoopIteration = True;
	
	While True Do
		If Not FirstLoopIteration Then
			ShortName = ShortName + Upper(Left(FullName, 1));
		EndIf;
		SpacePosition = Find(FullName, " ");
		If SpacePosition = 0 Then
			If FirstLoopIteration Then
				ShortName = FullName;
			EndIf;
			Break;
		EndIf;
		
		If FirstLoopIteration Then
			ShortName = Left(FullName, SpacePosition - 1);
		EndIf;
		
		FullName = Right(FullName, StrLen(FullName) - SpacePosition);
		
		FirstLoopIteration = False;
	EndDo;
	
	ShortName = StrReplace(ShortName, " ", "");
	
	Return ShortName;
	
EndFunction

&AtServer
Procedure FindUserAndInfoBaseUserInconsistencies(WriteParameters = Undefined)
	
	//** Defining relations with an nonexistent infobase user
	HasNewRelationToNonExistentInfoBaseUser = Not InfoBaseUserExists And ValueIsFilled(Object.InfoBaseUserID);
	If WriteParameters <> Undefined
	   And HasRelationToNonexistentInfoBaseUser
	   And Not HasNewRelationToNonExistentInfoBaseUser Then
		
		WriteParameters.Insert("NonexistentInfoBaseUserRelationCleared", Object.Ref);
	EndIf;
	HasRelationToNonexistentInfoBaseUser = HasNewRelationToNonExistentInfoBaseUser;
	
	If ActionsOnForm.InfoBaseUserProperties <> "EditAll" Then
		// The relation cannot be changed
		Items.RelationMismatchProcessing.Visible = False;
	Else
		Items.RelationMismatchProcessing.Visible = HasRelationToNonexistentInfoBaseUser;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Initial filling, fill checking, property availability.

&AtServer
Procedure FillLanguagePresentation(Language)
	
	LanguagePresentation = "";
	
	For Each LanguageMetadata In Metadata.Languages Do
	
		If LanguageMetadata.Name = Language Then
			LanguagePresentation = LanguageMetadata.Synonym;
			Break;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Function GetSelectedLanguage()
	
	For Each LanguageMetadata In Metadata.Languages Do
	
		If LanguageMetadata.Synonym = LanguagePresentation Then
			Return LanguageMetadata.Name;
		EndIf;
	EndDo;
	
	Return "";
	
EndFunction

&AtServer
Procedure FillRoles(ReadRoles)
	
	InfoBaseUserRoles.Clear();
	
	For Each Role In ReadRoles Do
		InfoBaseUserRoles.Add().Role = Role;
	EndDo;
	
	If ShowSelectedRolesOnly Then
		RefreshRoleTree();
	Else
		RefreshSelectedRoleMarks(Roles.GetItems());
	EndIf;
	
EndProcedure

&AtClient
Procedure SetPropertyEnabled()
	
	Items.AuthorizationObject.ReadOnly                  = ActionsOnForm.ItemProperties       <> "Edit" Or
	                                                      IsAuthorizationObjectSetOnOpen Or
	                                                      ValueIsFilled(Object.Ref) And
	                                                      ValueIsFilled(Object.AuthorizationObject);
	Items.InfoBaseAccessAllowed.ReadOnly                = ActionsOnForm.InfoBaseUserProperties <> "EditAll";
	Items.InfoBaseUserProperties.ReadOnly               = ActionsOnForm.InfoBaseUserProperties =  "ViewAll";
	Items.Password.ReadOnly                             = InfoBaseUserCannotChangePassword And Not FullAccessUserAuthorized;
	Items.PasswordConfirmation.ReadOnly                 = InfoBaseUserCannotChangePassword And Not FullAccessUserAuthorized;
	Items.InfoBaseUserName.ReadOnly                     = ActionsOnForm.InfoBaseUserProperties <> "EditAll";
	Items.InfoBaseUserCannotChangePassword.ReadOnly = ActionsOnForm.InfoBaseUserProperties <> "EditAll";
	
	SetRolesReadOnly(RoleEditProhibition Or ActionsOnForm.Roles <> "Edit" Or Not Object.SetRolesDirectly);
	
	Items.MainProperties.Enabled              = InfoBaseAccessAllowed;
	Items.EditOrViewRoles.Enabled             = InfoBaseAccessAllowed;
	Items.InfoBaseUserName.AutoMarkIncomplete = InfoBaseAccessAllowed;
	
	Items.InfoBaseAccessAllowed.Enabled = Not Object.NotValid;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions to provide the role interface.

&AtServer
Function RoleCollection(ValueTableForReading = False)
	
	If ValueTableForReading Then
		Return FormAttributeToValue("InfoBaseUserRoles");
	EndIf;
	
	Return InfoBaseUserRoles;
	
EndFunction

&AtClient
Procedure SetRolesReadOnly(Val RolesReadOnly = Undefined, Val AllowViewSelectedOnly = False)
	
	If RolesReadOnly <> Undefined Then
		Items.Roles.ReadOnly          =     RolesReadOnly;
		Items.RolesCheckAll.Enabled   = Not RolesReadOnly;
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
	
	// Expanding all roles
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
	CurrentRole      = "";
	//
	If Items.Roles.CurrentRow <> Undefined Then
		CurrentData = Roles.FindByID(Items.Roles.CurrentRow);
		If CurrentData.IsRole Then
			CurrentSubsystem = ?(CurrentData.GetParent() = Undefined, "", CurrentData.GetParent().Name);
			CurrentRole      = CurrentData.Name;
		Else
			CurrentSubsystem = CurrentData.Name;
			CurrentRole      = "";
		EndIf;
	EndIf;
	
	UserType = Enums.UserTypes.ExternalUser;
	RoleTree = UsersServerCached.RoleTree(ShowRoleSubsystems, UserType).Copy();
	RoleTree.Columns.Add("Check",       New TypeDescription("Boolean"));
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
			If HideFullAccessRole And 
				(Upper(Row.Name) = Upper("FullAccess") Or Upper(Row.Name) = Upper("FullAdministrator")) Then
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
		
		Index = Index - 1;
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
		
		Index = Index - 1;
	EndDo;
	
EndProcedure

&AtClient
Procedure NotValidOnChange(Item)
	
	If Object.NotValid Then
		InfoBaseAccessAllowed = False;
	EndIf;	
	
	SetPropertyEnabled();
	
EndProcedure
