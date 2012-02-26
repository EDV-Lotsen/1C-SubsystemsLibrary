

////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS
//

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	//** Assign initial values
	//   before loading data from settings at server
	//   for case, when data have not been recorded yet and are not being loaded
	ShowOnlySelectedRoles = (Items.RepresentationOfRoles.CurrentPage = Items.OnlySelectedRoles);
	
	//** Fill constant data
	
	PrepareChoiceListAndTableOfRoles();
	
	// Fill language choice list
	For each LanguageMetadata IN Metadata.Languages Do
		Items.LanguagePresentation.ChoiceList.Add(LanguageMetadata.Synonym);
	EndDo;
	
	//** Preparation for the interactive actions including form open scenarios
	
	SetActionsWithRoles();
	
	SetPrivilegedMode(True);
	
	If NOT ValueIsFilled(Object.Ref) Then
		// Creating new item
		If Parameters.GroupNewExternalUser <> Catalogs.ExternalUserGroups.AllExternalUsers Then
			GroupNewExternalUser = Parameters.GroupNewExternalUser;
		EndIf;
		If ValueIsFilled(Parameters.CopyingValue) Then
			// Copying item
			Object.AuthorizationObject 	= Undefined;
			Object.Description      	= "";
			Object.Code               	= "";
			Object.DeletePassword     	= "";
			ReadIBUser(ValueIsFilled(Parameters.CopyingValue.IBUserID));
		Else
			// Inserting item
			If Parameters.Property("AuthorizationObjectOfNewExternalUser") Then
				Object.AuthorizationObject = Parameters.AuthorizationObjectOfNewExternalUser;
				AuthorizationObjectSetOnOpen = ValueIsFilled(Object.AuthorizationObject);
				AuthorizationObjectOnChangeAtClientAtServer(ThisForm, Object);
			ElsIf ValueIsFilled(GroupNewExternalUser) Then
				AuthorizationObjectType = CommonUse.GetAttributeValue(GroupNewExternalUser, "AuthorizationObjectType");
				Object.AuthorizationObject = AuthorizationObjectType;
				Items.AuthorizationObject.ChooseType = False;
			EndIf;
			// Reading initial values of IB user properties
			ReadIBUser();
		EndIf;
	Else
		// Opening existing item
		ReadIBUser();
	EndIf;
	
	SetPrivilegedMode(False);
	
	DefineActionsInForm();
	
	DefineUserInconsistenciesWithUserIB();
	
	//** Assign constant accessibility of the properties
	Items.IBUserProperties.Visible      = ValueIsFilled(ActionsInForm.IBUserProperties);
	Items.RepresentationOfRoles.Visible = ValueIsFilled(ActionsInForm.Roles);
	Items.SetRolesDirectly.Visible   	= ValueIsFilled(ActionsInForm.Roles) And NOT UsersOverrided.RolesEditingProhibited();
	
	Items.SetRolesDirectly.Enabled = ActionsInForm.Roles = "Edit";
	
	ReadOnly = ReadOnly OR
	                 ActionsInForm.Roles <> "Edit" And
	                 NOT ( ActionsInForm.IBUserProperties = "EditAll" OR
	                      ActionsInForm.IBUserProperties = "EditOfTheir") And
	                 ActionsInForm.ItemProperties <> "Edit";
	
	MarkRolesByList();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancellation)
	
	SetAccessibilityOfProperties();
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	CurrentPresentationOfAuthorizationObject = String(Object.AuthorizationObject);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancellation)
	
	ClearMessages();
	
	If ActionsInForm.Roles = "Edit" And Object.SetRolesDirectly And Roles.Count() = 0 Then
	
		If DoQueryBox(NStr("en = 'No role has been assigned to the user of the information base. Do you want to continue?'"),
		            QuestionDialogMode.YesNo,
		            ,
		            ,
		            NStr("en = 'Recording of the information base user'")) = DialogReturnCode.No Then
			Cancellation = True;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancellation, CurrentObject, WriteParameters)
	
	If ActionsInForm.ItemProperties <> "Edit" Then
		FillPropertyValues(CurrentObject, CommonUse.GetAttributeValues(CurrentObject.Ref, "Description, DeletionMark"));
	EndIf;
	
	If ExternalUsers.AuthorizationObjectLinkedToExternalUser(Object.AuthorizationObject, Object.Ref) Then
		
		CommonUseClientServer.MessageToUser(
						NStr("en = 'Object of the Information base is used for another external user.'"), ,
						"Object.AuthorizationObject", ,
						Cancellation);
		Return;
	EndIf;
	
	CurrentObject.AdditionalProperties.Insert("GroupNewExternalUser", GroupNewExternalUser);
	
	If AccessToInformationBaseAllowed Then
		
		WriteIBUser(CurrentObject, Cancellation);
		If NOT Cancellation Then
			If CurrentObject.IBUserID <> OldIBUserID Then
				WriteParameters.Insert("AddedIBUser", CurrentObject.IBUserID);
			Else
				WriteParameters.Insert("IBUserChanged", CurrentObject.IBUserID);
			EndIf
		EndIf;
		
	ElsIf NOT IsLinkWithNonexistentIBUser OR
	          ActionsInForm.IBUserProperties = "EditAll" Then
		
		CurrentObject.IBUserID = Undefined;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancellation, CurrentObject, WriteParameters)
	
	If NOT AccessToInformationBaseAllowed And IBUserExists Then
		DeleteIBUsers(Cancellation);
		If NOT Cancellation Then
			WriteParameters.Insert("DeletedIBUser", OldIBUserID);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	If CurrentObject.AdditionalProperties.Property("AreErrors") Then
		WriteParameters.Insert("AreErrors");
	EndIf;
	
	ReadIBUser();
	
	DefineUserInconsistenciesWithUserIB(WriteParameters);
	
	MarkRolesByList();
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	If WriteParameters.Property("AddedIBUser") Then
		Notify("AddedIBUser", WriteParameters.AddedIBUser, ThisForm);
		
	ElsIf WriteParameters.Property("IBUserChanged") Then
		Notify("IBUserChanged", WriteParameters.IBUserChanged, ThisForm);
		
	ElsIf WriteParameters.Property("DeletedIBUser") Then
		Notify("DeletedIBUser", WriteParameters.DeletedIBUser, ThisForm);
		
	ElsIf WriteParameters.Property("ClearedLinkWithNotExistingIBUser") Then
		Notify("ClearedLinkWithNotExistingIBUser", WriteParameters.ClearedLinkWithNotExistingIBUser, ThisForm);
	EndIf;
	
	If WriteParameters.Property("AreErrors") Then
		DoMessageBox(NStr("en = 'An error occured while writing (see event log)'"));
	EndIf;
	
	If ValueIsFilled(GroupNewExternalUser) Then
		NotifyChanged(GroupNewExternalUser);
		Notify("ChangedContentOFExternalUsersGroup", GroupNewExternalUser, ThisForm);
		GroupNewExternalUser = Undefined;
	EndIf;
	
	SetAccessibilityOfProperties();
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancellation, CheckedAttributes)
	
	If AccessToInformationBaseAllowed Then
		
		FillCheckProcessingOfRoleList(Cancellation);
		
		If NOT Cancellation And IsBlankString(InfBaseUserName) Then
			CommonUseClientServer.MessageToUser(
							NStr("en = 'Information base user''s name is not filled.'"), ,
							"InfBaseUserName", ,
							Cancellation);
		EndIf;
		
		If NOT Cancellation And InfBaseUserPassword <> Undefined  And Password <> PasswordConfirmation Then
			CommonUseClientServer.MessageToUser(
							NStr("en = 'Password and password confirmation do not match.'"), ,
							"Password", ,
							Cancellation);
		EndIf;
		
		If NeedToCreateFirstAdministrator() Then
			CommonUseClientServer.MessageToUser(
					NStr("en = 'First user of the information base must have full rights.
                          |External user of the information base cannot have full rights.
                          |Create standard administrator first.'"), ,
					"AccessToInformationBaseAllowed", ,
					Cancellation);
		EndIf;
	EndIf;
	
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
Procedure AuthorizationObjectOnChange(Item)
	
	AuthorizationObjectOnChangeAtClientAtServer(ThisForm, Object);
	
EndProcedure

&AtClient
Procedure AccessToInformationBaseAllowedOnChange(Item)
	
	If NOT IBUserExists And AccessToInformationBaseAllowed Then
		InfBaseUserName = GetShortNameOfIBUser(CurrentPresentationOfAuthorizationObject);
	EndIf;
	
	SetAccessibilityOfProperties();
	
EndProcedure

&AtClient
Procedure PasswordOnChange(Item)
	
	InfBaseUserPassword = Password;
	
EndProcedure

&AtClient
Procedure SetRolesDirectlyOnChange(Item)
	
	If NOT Object.SetRolesDirectly Then
		ReadIBUser(, True);
	EndIf;
	
	SetAccessibilityOfProperties();
	
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
	
	RolesFound = Roles.FindRows(New Structure("Role", TableRow.Name));
	
	If TableRow.Check Then
		If RolesFound.Count() = 0 Then
			String = Roles.Add();
			String.Role = TableRow.Name;
			String.RoleSynonym = TableRow.Synonym;
		EndIf;
	ElsIf RolesFound.Count() > 0 Then
		Roles.Delete(RolesFound[0]);
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
Function NeedToCreateFirstAdministrator()
	
	SetPrivilegedMode(True);
	
	Return InfoBaseUsers.GetUsers().Count() = 0;
	
EndFunction

&AtServer
Procedure DefineActionsInForm()
	
	ActionsInForm = New Structure;
	ActionsInForm.Insert("Roles",            ""); // "", "View",     "Edit"
	ActionsInForm.Insert("IBUserProperties", ""); // "", "ViewAll", "EditAll", "EditOfTheir"
	ActionsInForm.Insert("ItemProperties",   ""); // "", "View",     "Edit"
	
	If Users.CurrentUserHaveFullAccess() OR
	     AccessRight("Insert", Metadata.Catalogs.Users) Then
		// Administrator
		ActionsInForm.Roles            		= "Edit";
		ActionsInForm.IBUserProperties 		= "EditAll";
		ActionsInForm.ItemProperties       	= "Edit";
		
	ElsIf IsInRole("AddChangeExternalUsers") Then
		// External users manager
		ActionsInForm.Roles                 = "";
		ActionsInForm.IBUserProperties 		= "EditAll";
		ActionsInForm.ItemProperties       	= "View";
		
	ElsIf ValueIsFilled(ExternalUsers.CurrentExternalUser()) And
	          Object.Ref = ExternalUsers.CurrentExternalUser() Then
		// Own properties
		ActionsInForm.Roles                 = "";
		ActionsInForm.IBUserProperties 		= "EditOfTheir";
		ActionsInForm.ItemProperties       	= "View";
	Else
		// External users reader
		ActionsInForm.Roles                 = "";
		ActionsInForm.IBUserProperties 		= "";
		ActionsInForm.ItemProperties       	= "View";
	EndIf;
	
	If NOT ValueIsFilled(Object.Ref) And NOT ValueIsFilled(Object.AuthorizationObject) Then
		ActionsInForm.ItemProperties       = "Edit";
	EndIf;
	
	UsersOverrided.ChangeActionsInForm(Object.Ref, ActionsInForm);
	
	// Check action names in the form
	If Find(", View, Edit,", ", " + ActionsInForm.Roles + ",") = 0 Then
		ActionsInForm.Roles = "";
	ElsIf UsersOverrided.RolesEditingProhibited() Then
		ActionsInForm.Roles = "View";
	EndIf;
	If Find(", ViewAll, EditAll, EditOfTheir,", ", " + ActionsInForm.IBUserProperties + ",") = 0 Then
		ActionsInForm.IBUserProperties = "";
	EndIf;
	If Find(", View, Edit,", ", " + ActionsInForm.ItemProperties + ",") = 0 Then
		ActionsInForm.ItemProperties = "";
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure AuthorizationObjectOnChangeAtClientAtServer(Context, Object)
	
	If Object.AuthorizationObject = Undefined Then
		Object.AuthorizationObject = Context.AuthorizationObjectType;
	EndIf;
	
	If Context.CurrentPresentationOfAuthorizationObject <> String(Object.AuthorizationObject) Then
		
		Context.CurrentPresentationOfAuthorizationObject = String(Object.AuthorizationObject);
		
		If NOT Context.IBUserExists And Context.AccessToInformationBaseAllowed Then
			Context.InfBaseUserName = GetShortNameOfIBUser(Context.CurrentPresentationOfAuthorizationObject);
		EndIf;
		
	EndIf;
	
EndProcedure

//** Read, write, delete, calculate of IB user short name, check mismatch

&AtServer
Procedure ReadIBUser(OnItemCopy = False, OnlyRoles = False)
	
	SetPrivilegedMode(True);
	
	ReadRoles = Undefined;
	
	If OnlyRoles Then
		Users.ReadIBUser(Object.IBUserID, , ReadRoles);
		FillRolesServer(ReadRoles);
		Return;
	EndIf;
	
	Password              			= "";
	PasswordConfirmation  			= "";
	ReadProperties        			= Undefined;
	OldIBUserID 		  			= Undefined;
	IBUserExists          		    = False;
	AccessToInformationBaseAllowed  = False;
	
	// Fill initial values of properties of IBuser for a user.
	Users.ReadIBUser(Undefined, ReadProperties, ReadRoles);
	FillPropertyValues(ThisForm, ReadProperties);
	
	If OnItemCopy Then
		
		If Users.ReadIBUser(Parameters.CopyingValue.IBUserID, ReadProperties, ReadRoles) Then
			// Because cloned user is linked with IBuser,
			// then future link is set for a new user too.
			AccessToInformationBaseAllowed = True;
			// Because IBUser of the cloned user has been read,
			// then properties and roles of IBUser are copied.
			FillPropertyValues(ThisForm,
			                         ReadProperties,
			                         "InfBaseUserProhibitedToChangePassword");
		EndIf;
		Object.IBUserID = Undefined;
	Else
		If Users.ReadIBUser(Object.IBUserID, ReadProperties, ReadRoles) Then
		
			IBUserExists          = True;
			AccessToInformationBaseAllowed = True;
			OldIBUserID = Object.IBUserID;
			
			FillPropertyValues(ThisForm,
			                         ReadProperties,
			                         "InfBaseUserName,
			                         |InfBaseUserProhibitedToChangePassword");
			
			If ReadProperties.InfBaseUserPasswordIsSet Then
				Password             = "**********";
				PasswordConfirmation = "**********";
			EndIf;
		EndIf;
	EndIf;
	
	FillLanguagePresentation(ReadProperties.InfBaseUserLanguage);
	FillRolesServer(ReadRoles);
	
EndProcedure

&AtServer
Procedure WriteIBUser(CurrentObject, Cancellation)
	
	// Restore actions in form, if they were modified at client
	DefineActionsInForm();
	
	If NOT (ActionsInForm.IBUserProperties = "EditAll" OR
	         ActionsInForm.IBUserProperties = "EditOfTheir"    )Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	InitialProperties = Undefined;
	NewProperties     = Undefined;
	NewRoles          = Undefined;
	
	// Read old properties/fill initial properties of IBUser for a user.
	Users.ReadIBUser(CurrentObject.IBUserID, NewProperties);
	NewProperties.InfBaseUserFullName                 = String(CurrentObject.AuthorizationObject);
	NewProperties.InfBaseUserStandardAuthentication = True;
	
	Users.ReadIBUser(Undefined, InitialProperties);
	FillPropertyValues(NewProperties,
	                         InitialProperties,
	                         "InfBaseUserShowInList,
	                         |InfBaseUserOSAuthentication,
	                         |InfBaseUserDefaultInterface,
	                         |InfBaseUserRunMode");
	
	If ActionsInForm.IBUserProperties = "EditAll" Then
		FillPropertyValues(NewProperties,
		                         ThisForm,
		                         "InfBaseUserName,
		                         |InfBaseUserPassword,
		                         |InfBaseUserProhibitedToChangePassword");
	Else
		FillPropertyValues(NewProperties,
		                         ThisForm,
		                         "InfBaseUserName,
		                         |InfBaseUserPassword");
	EndIf;
	NewProperties.InfBaseUserLanguage = GetSelectedLanguage();
		
	If ActionsInForm.Roles = "Edit" And Object.SetRolesDirectly Then
		NewRoles = Roles.Unload().UnloadColumn("Role");
	EndIf;
	
	// Trying to  write IB user
	ErrorDescription = "";
	If Users.WriteIBUser(CurrentObject.IBUserID, NewProperties, NewRoles, NOT IBUserExists, ErrorDescription) Then
		If NOT IBUserExists Then
			CurrentObject.IBUserID = NewProperties.InfBaseUserUUID;
			IBUserExists = True;
		EndIf;
	Else
		Cancellation = True;
		CommonUseClientServer.MessageToUser(ErrorDescription);
	EndIf;
	
EndProcedure

&AtServer
Function DeleteIBUsers(Cancellation)
	
	SetPrivilegedMode(True);
	
	ErrorDescription = "";
	If NOT Users.DeleteIBUsers(OldIBUserID, ErrorDescription) Then
		CommonUseClientServer.MessageToUser(ErrorDescription, , , , Cancellation);
	EndIf;
	
EndFunction

&AtClientAtServerNoContext
Function GetShortNameOfIBUser(Val FullName)
	
	ShortName = "";
	FirstCycleRun = True;
	
	While True Do
		If NOT FirstCycleRun Then
			ShortName = ShortName + Upper(Left(FullName, 1));
		EndIf;
		SpacePosition = Find(FullName, " ");
		If SpacePosition = 0 Then
			If FirstCycleRun Then
				ShortName = FullName;
			EndIf;
			Break;
		EndIf;
		
		If FirstCycleRun Then
			ShortName = Left(FullName, SpacePosition - 1);
		EndIf;
		
		FullName = Right(FullName, StrLen(FullName) - SpacePosition);
		
		FirstCycleRun = False;
	EndDo;
	
	ShortName = StrReplace(ShortName, " ", "");
	
	Return ShortName;
	
EndFunction

&AtServer
Procedure DefineUserInconsistenciesWithUserIB(WriteParameters = Undefined) Export
	
	//** Determine if there is link with inexistent IB user
	IsNewLinkWithNonexistentIBUser = NOT IBUserExists And ValueIsFilled(Object.IBUserID);
	If WriteParameters <> Undefined
	   And IsLinkWithNonexistentIBUser
	   And NOT IsNewLinkWithNonexistentIBUser Then
		
		WriteParameters.Insert("ClearedLinkWithNotExistingIBUser", Object.Ref);
	EndIf;
	IsLinkWithNonexistentIBUser = IsNewLinkWithNonexistentIBUser;
	
	If ActionsInForm.IBUserProperties <> "EditAll" Then
		// Link cannot be changed
		Items.LinkInconsistenceProcessing.Visible = False;
	Else
		Items.LinkInconsistenceProcessing.Visible = IsLinkWithNonexistentIBUser;
	EndIf;
	
EndProcedure

//** Initial filling, check fill, properties accessibility

&AtServer
Procedure FillLanguagePresentation(Language)
	
	LanguagePresentation = "";
	
	For each LanguageMetadata IN Metadata.Languages Do
	
		If LanguageMetadata.Name = Language Then
			LanguagePresentation = LanguageMetadata.Synonym;
			Break;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Function GetSelectedLanguage()
	
	For each LanguageMetadata IN Metadata.Languages Do
	
		If LanguageMetadata.Synonym = LanguagePresentation Then
			Return LanguageMetadata.Name;
		EndIf;
	EndDo;
	
	Return "";
	
EndFunction

&AtServer
Procedure FillRolesServer(ReadRoles)
	
	Roles.Clear();
	
	For each Role In ReadRoles Do
		NewRow = Roles.Add();
		NewRow.Role        = Role;
		NewRow.RoleSynonym = TableOfRoles.FindRows(New Structure("Name", Role))[0].Synonym;
	EndDo;
	
	Roles.Sort("RoleSynonym");
	
EndProcedure

&AtClient
Procedure SetAccessibilityOfProperties()
	
	Items.AuthorizationObject.ReadOnly = ActionsInForm.ItemProperties <> "Edit" OR
											AuthorizationObjectSetOnOpen OR
	                                        ValueIsFilled(Object.Ref) And
	                                        ValueIsFilled(Object.AuthorizationObject);
	Items.AccessToInformationBaseAllowed.ReadOnly           = ActionsInForm.IBUserProperties <> "EditAll";
	Items.IBUserProperties.ReadOnly                       	= ActionsInForm.IBUserProperties =  "ViewAll";
	Items.Password.ReadOnly                                 = InfBaseUserProhibitedToChangePassword;
	Items.PasswordConfirmation.ReadOnly                     = InfBaseUserProhibitedToChangePassword;
	Items.InfBaseUserProhibitedToChangePassword.ReadOnly   	= ActionsInForm.IBUserProperties <> "EditAll";
	SetReadOnlyOfRoles(ActionsInForm.Roles <> "Edit" OR NOT Object.SetRolesDirectly);
	
	Items.MainProperties.Enabled                     		= AccessToInformationBaseAllowed;
	Items.EditOrViewOfRoles.Enabled       					= AccessToInformationBaseAllowed;
	Items.InfBaseUserName.AutoMarkIncomplete 				= AccessToInformationBaseAllowed;
	
EndProcedure

//** For operation of the roles interface

&AtServer
Procedure SetActionsWithRoles()
	
	BanEdit = UsersOverrided.RolesEditingProhibited();
	
	// ** OnlySelectedRoles
	// Main menu
	Items.RolesFill.Visible                 = NOT BanEdit;
	Items.RolesAdd.Visible                  = NOT BanEdit;
	Items.RolesDelete.Visible               = NOT BanEdit;
	Items.RolesMoveUp.Visible               = NOT BanEdit;
	Items.RolesMoveDown.Visible             = NOT BanEdit;
	Items.RolesSortListAsc.Visible  		= NOT BanEdit;
	Items.RolesSortListDesc.Visible     	= NOT BanEdit;
	// Context menu
	Items.ContextMenuRolesFill.Visible      = NOT BanEdit;
	Items.ContextMenuRolesAdd.Visible       = NOT BanEdit;
	Items.ContextMenuRolesDelete.Visible    = NOT BanEdit;
	Items.ContextMenuRolesMoveUp.Visible 	= NOT BanEdit;
	Items.ContextMenuRolesMoveDown.Visible  = NOT BanEdit;
	
	// ** AmongAllSelectedRoles
	// Main menu
	Items.TableOfRolesCheckAll.Visible      = NOT BanEdit;
	Items.TableOfRolesUncheckAll.Visible    = NOT BanEdit;
	Items.TableOfRolesSortListAsc.Visible 	= NOT BanEdit;
	Items.TableOfRolesSortListDesc.Visible  = NOT BanEdit;
	
EndProcedure

&AtServer
Procedure MarkAllAtServer()
	
	For each TableRow In TableOfRoles Do
		
		TableRow.Check = True;
		
		RolesFound = Roles.FindRows(New Structure("Role", TableRow.Name));
		If RolesFound.Count() = 0 Then
			String = Roles.Add();
			String.Role = TableRow.Name;
			String.RoleSynonym = TableRow.Synonym;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure UncheckAllAtServer()
	
	For each TableRow In TableOfRoles Do
		
		TableRow.Check = False;
		
		RolesFound = Roles.FindRows(New Structure("Role", TableRow.Name));
		If RolesFound.Count() > 0 Then
			Roles.Delete(RolesFound[0]);
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure AddSelectedRoles(SelectedRoles)
	
	For each Value In SelectedRoles Do
	
		ItemOfList = ChoiceListOfRoles.FindByValue(Value);
		If ItemOfList <> Undefined Then
			
			If Roles.FindRows(New Structure("Role", Value)).Count() = 0 Then
				
				String = Roles.Add();
				String.Role        = ItemOfList.Value;
				String.RoleSynonym = ItemOfList.Presentation;
			EndIf;
		EndIf;
	EndDo;
	
	MarkRolesByList();
	
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

&AtClient
Procedure SetReadOnlyOfRoles(Val ReadOnlyOfRoles)
	
	Items.Roles.ReadOnly         	= ReadOnlyOfRoles;
	Items.TableOfRoles.ReadOnly 	= ReadOnlyOfRoles;
	
	Items.RolesFill.Enabled            		= NOT ReadOnlyOfRoles;
	Items.ContextMenuRolesFill.Enabled 		= NOT ReadOnlyOfRoles;
	Items.TableOfRolesCheckAll.Enabled 		= NOT ReadOnlyOfRoles;
	Items.TableOfRolesUncheckAll.Enabled    = NOT ReadOnlyOfRoles;
	
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
Procedure MarkRolesByList()
	
	For each TableRow In TableOfRoles Do
		
		TableRow.Check = Roles.FindRows(New Structure("Role", TableRow.Name)).Count() > 0;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingOfRoleList(Cancellation)
	
	// Check unfilled and duplicated roles.
	LineNumber = Roles.Count()-1;
	While NOT Cancellation And LineNumber >= 0 Do
	
		CurrentRow = Roles.Get(LineNumber);
		
		// Check that value is filled.
		If NOT ValueIsFilled(CurrentRow.RoleSynonym) Then
			CommonUseClientServer.MessageToUser(NStr("en = 'Role is not filled!'"),
			                                                  ,
			                                                  "Roles[" + Format(LineNumber, "NG=0") + "].RoleSynonym",
			                                                  ,
			                                                  Cancellation);
			Return;
		EndIf;
		
		// Check duplicated values.
		ValuesFound = Roles.FindRows(New Structure("Role", CurrentRow.Role));
		If ValuesFound.Count() > 1 Then
			CommonUseClientServer.MessageToUser( NStr("en = 'Role repeats!'"),
			                                                  ,
			                                                  "Roles[" + Format(LineNumber, "NG=0") + "].RoleSynonym",
			                                                  ,
			                                                  Cancellation);
			Return;
		EndIf;
			
		LineNumber = LineNumber - 1;
	EndDo;
	
EndProcedure


