////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If CommonUseCached.DataSeparationEnabled() Then
		
		If Not StandardSubsystemsOverridable.CanChangeUsers() Then
			If Object.Ref.IsEmpty() Then
				Raise(NStr("en = 'New users cannot be created in the demo mode.'"));
			EndIf;
			
			ReadOnly = True;
		EndIf;
		
		Items.InfoBaseUserShowInList.Visible = False;
		Items.InfoBaseUserStandardAuthentication.Visible = False;
		Items.InfoBaseUserCannotChangePassword.Visible = False;
		Items.OSAuthenticationProperties.Visible = False;
		Items.InfoBaseUserRunMode.Visible = False;
		If Metadata.Languages.Count() = 1 Then
			Items.InfoBaseUserLanguage.Visible = False;
		EndIf;
	EndIf;
	
	If Object.Ref = Users.UnspecifiedUserProperties().StandardRef Then
		ReadOnly = True;
	EndIf;
	
	//** Setting initial values before importing settings from the server
	// if data was not written and there is nothing to import.
	ShowRoleSubsystems = True;
	Items.RolesShowRoleSubsystems.Check = True;
	// If the item is a new one, all roles are shown, otherwise only selected roles are shown
	ShowSelectedRolesOnly = ValueIsFilled(Object.Ref);
	Items.RolesShowSelectedRolesOnly.Check = ShowSelectedRolesOnly;
	//
	RefreshRoleTree();
	
	//** Filling permanent data
	FullAccessUserAuthorized = Users.InfoBaseUserWithFullAccess();
	
	// Filling the language choice list
	For Each LanguageMetadata In Metadata.Languages Do
		Items.InfoBaseUserLanguage.ChoiceList.Add(LanguageMetadata.Name, LanguageMetadata.Synonym);
	EndDo;
	
	// Filling the run mode choice list
	For Each RunMode In ClientRunMode Do
		ValueFullName = GetPredefinedValueFullName(RunMode);
		EnumValueName = Mid(ValueFullName, Find(ValueFullName, ".") + 1);
		Items.InfoBaseUserRunMode.ChoiceList.Add(EnumValueName, String(RunMode));
	EndDo;
	Items.InfoBaseUserRunMode.ChoiceList.SortByPresentation();
	
	//** Preparing to process interactive actions according to form opening scenarios
	
	SetPrivilegedMode(True);
	
	If Not ValueIsFilled(Object.Ref) Then
		// Creating a new item
		If Parameters.NewUserGroup <> Catalogs.UserGroups.AllUsers Then
			NewUserGroup = Parameters.NewUserGroup;
		EndIf;
		If ValueIsFilled(Parameters.CopyingValue) Then
			// Coping the item
			Object.Description = "";
			ReadInfoBaseUser(ValueIsFilled(Parameters.CopyingValue.InfoBaseUserID));
		Else
			// Adding the item
			Object.InfoBaseUserID = Parameters.InfoBaseUserID;
			// Reading initial values of infobase user properties
			ReadInfoBaseUser();
			
			If CommonUseCached.DataSeparationEnabled() Then
				InfoBaseUserShowInList = False;
				InfoBaseUserStandardAuthentication = True;
				InfoBaseAccessAllowed = True;
			EndIf;
		EndIf;
	Else
		// Opening the existent item
		ReadInfoBaseUser();
	EndIf;
	
	SetPrivilegedMode(False);
	
	SetActionsOnForm();
	
	FindUserAndInfoBaseUserInconsistencies();
	
	ReadOnly = ReadOnly Or
	           ActionsOnForm.Roles <> "Edit" And
	           ActionsOnForm.ContactInformation <> "Edit" And
	           Not (ActionsOnForm.InfoBaseUserProperties = "EditAll" Or
	                ActionsOnForm.InfoBaseUserProperties = "EditOwn") And
	           ActionsOnForm.ItemProperties <> "Edit";
	
	SetRolesReadOnly(UsersOverridable.RoleEditProhibition() Or ActionsOnForm.Roles <> "Edit");
	
	// StandardSubsystems.ContactInformation
	ContactInformationManagement.OnCreateAtServer(ThisForm, Object, "ContactInformation");
	// End StandardSubsystems.ContactInformation
	
	If Not Users.InfoBaseUserWithFullAccess() Then
		Items.NotValid.ReadOnly = True;
	EndIf;
	
	SetPermanentEnabledProperty();
	SetPropertyEnabled(ThisForm);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	#If WebClient Then
	Items.InfoBaseUserOSUser.ChoiceButton = False;
	#EndIf
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel)
	
	ClearMessages();
	
	QuestionTitle = NStr("en = 'Writing infobase user'");
	
	If InfoBaseAccessAllowed Then
		If ActionsOnForm.Roles = "Edit" And InfoBaseUserRoles.Count() = 0 Then
			Response = DoQueryBox(NStr("en = 'No roles are specified for the infobase user. Do you want to continue?'"),
				QuestionDialogMode.YesNo, , , QuestionTitle);
			If Response = DialogReturnCode.No Then
				Cancel = True;
			EndIf;
		EndIf;
	
		// Processing first administrator write
		QuestionText = "";
		If Users.CreateFirstAdministratorRequired(GetInfoBaseUserInfoStructure(), 
			QuestionText) Then
			
			Response = DoQueryBox(QuestionText, QuestionDialogMode.YesNo, , , QuestionTitle);
			If Response = DialogReturnCode.No Then
				Cancel = True;
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If CreateServiceUser Then
		// Previous creation attempt failed
		
		CreateServiceUser = False;
		Object.ServiceUserID = Undefined;
		CurrentObject.ServiceUserID = Undefined;
	EndIf;
	
	If InfoBaseAccessAllowed
		And CommonUseCached.DataSeparationEnabled() Then
		
		If Not ValueIsFilled(CurrentObject.ServiceUserID) Then
			
			CreateServiceUser = True;
			
			ServiceUserID = New UUID;
			
			Object.ServiceUserID = ServiceUserID;
			CurrentObject.ServiceUserID = ServiceUserID;
			
		EndIf;
	EndIf;
	
	If ActionsOnForm.InfoBaseUserProperties = "EditAll"
		Or ActionsOnForm.InfoBaseUserProperties = "EditOwn" Then
		
		CurrentObject.AdditionalProperties.Insert("InfoBaseAccessAllowed", InfoBaseAccessAllowed);
	
		If InfoBaseAccessAllowed Then
			
			CurrentObject.AdditionalProperties.Insert("InfoBaseUserInfoStructure", GetInfoBaseUserInfoStructure());
			
		EndIf;
	EndIf;
	
	If ActionsOnForm.ItemProperties <> "Edit" Then
		FillPropertyValues(CurrentObject, CommonUse.GetAttributeValues(CurrentObject.Ref, "Description, DeletionMark"));
	EndIf;
	
	CurrentObject.AdditionalProperties.Insert("NewUserGroup", NewUserGroup);
	
	// StandardSubsystems.ContactInformation
	If Not Cancel And ActionsOnForm.ContactInformation = "Edit" Then
		ContactInformationManagement.BeforeWriteAtServer(ThisForm, CurrentObject, Cancel);
	EndIf;
	// End StandardSubsystems.ContactInformation
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	UserDetails = New Structure;
	UserDetails.Insert("Name", InfoBaseUserName);
	UserDetails.Insert("FullName", InfoBaseUserFullName);
	UserDetails.Insert("Language", InfoBaseUserLanguage);
	
	StandardSubsystemsOverridable.UserOnWrite(CurrentObject, UserDetails, 
		InfoBaseUserExists, InfoBaseAccessAllowed, CreateServiceUser);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	InfoBaseUserWriteEvents = New Array;
	InfoBaseUserWriteEvents.Add("InfoBaseUserAdded");
	InfoBaseUserWriteEvents.Add("InfoBaseUserChanged");
	InfoBaseUserWriteEvents.Add("InfoBaseUserDeleted");
	For Each WriteEvent In InfoBaseUserWriteEvents Do
		If CurrentObject.AdditionalProperties.Property(WriteEvent) Then
			WriteParameters.Insert(WriteEvent, CurrentObject.AdditionalProperties[WriteEvent]);
		EndIf;
	EndDo;
	
	ReadInfoBaseUser();
	
	FindUserAndInfoBaseUserInconsistencies(WriteParameters);
	
	If CreateServiceUser Then
		CreateServiceUser = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_Users", New Structure, Object.Ref);
	
	If WriteParameters.Property("InfoBaseUserAdded") Then
		Notify("InfoBaseUserAdded", WriteParameters.InfoBaseUserAdded, ThisForm);
		
	ElsIf WriteParameters.Property("InfoBaseUserChanged") Then
		Notify("InfoBaseUserChanged", WriteParameters.InfoBaseUserChanged, ThisForm);
		
	ElsIf WriteParameters.Property("InfoBaseUserDeleted") Then
		Notify("InfoBaseUserDeleted", WriteParameters.InfoBaseUserDeleted, ThisForm);
		
	ElsIf WriteParameters.Property("NonexistentInfoBaseUserRelationCleared") Then
		Notify("NonexistentInfoBaseUserRelationCleared", WriteParameters.NonexistentInfoBaseUserRelationCleared, ThisForm);
	EndIf;
	
	If ValueIsFilled(NewUserGroup) Then
		NotifyChanged(NewUserGroup);
		Notify("Write_UserGroups", New Structure, NewUserGroup);
		NewUserGroup = Undefined;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, AttributesToCheck)
	
	If InfoBaseAccessAllowed Then
		
		Users.CheckInfoBaseUserInfoStructureFilling(GetInfoBaseUserInfoStructure(), Cancel);
		
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
	
	RefreshRoleTree();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure FillFullNameByInfoBaseUser(Command)
	
	Object.Description = InfoBaseUserFullName;
	Items.MismatchProcessingFullName.Visible = False;
	
EndProcedure

&AtClient
Procedure DescriptionOnChange(Item)
	
	// If FullName is defined, it must be updated.
	// Note: If FullName or any other property is undefined, it is not taken into account 
	//       when writing an infobase user. FullName is defined for WithoutRestriction 
	//       interactive action kind only.
	If InfoBaseUserFullName <> Undefined Then
		InfoBaseUserFullName = Object.Description;
	EndIf;
	
	If Not InfoBaseUserExists And InfoBaseAccessAllowed Then
		InfoBaseUserName = GetInfoBaseUserShortName(Object.Description);
	EndIf;
	
EndProcedure

&AtClient
Procedure InfoBaseAccessAllowedOnChange(Item)
	
	If Not InfoBaseUserExists And InfoBaseAccessAllowed Then
		InfoBaseUserName       = GetInfoBaseUserShortName(Object.Description);
		InfoBaseUserFullName = Object.Description;
	EndIf;
	
	SetPropertyEnabled(ThisForm);
	
EndProcedure

&AtClient
Procedure InfoBaseUserStandardAuthenticationOnChange(Item)
	
	SetPropertyEnabled(ThisForm);
	
EndProcedure

&AtClient
Procedure PasswordOnChange(Item)
	
	InfoBaseUserPassword = Password;
	
EndProcedure

&AtClient
Procedure InfoBaseUserOSAuthenticationOnChange(Item)
	
	SetPropertyEnabled(ThisForm);
	
EndProcedure

&AtClient
Procedure InfoBaseUserOSUserStartChoice(Item, ChoiceData, StandardProcessing)
	
	#If Not WebClient Then
		Result = OpenFormModal("Catalog.Users.Form.OSUserChoiceForm");
		
		If TypeOf(Result) = Type("String") Then
			InfoBaseUserOSUser = Result;
		EndIf;
	#EndIf
	
EndProcedure

&AtClient
Procedure ValidOnChange(Item)
	
	If Object.NotValid Then
		InfoBaseAccessAllowed = False;
	EndIf;
	
	SetPropertyEnabled(ThisForm);
	
EndProcedure

// StandardSubsystems.ContactInformation

&AtClient
Procedure Attachable_ContactInformationOnChange(Item)
	
	ContactInformationManagementClient.PresentationOnChange(ThisForm, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationStartChoice(Item, ChoiceData, StandardProcessing)
	
	ContactInformationManagementClient.PresentationStartChoice(ThisForm, Item, Modified, StandardProcessing);
	
EndProcedure

// End StandardSubsystems.ContactInformation

////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENT HANDLERS OF Roles TABLE 

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions to provide the role interface

&AtClient
Procedure RolesCheckOnChange(Item)
	
	If Items.Roles.CurrentData <> Undefined Then
		UpdateRoleContent(Items.Roles.CurrentRow, Items.Roles.CurrentData.Check);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions to provide the role interface

&AtClient
Procedure ShowSelectedRolesOnly(Command)
	
	ShowSelectedRolesOnly = Not ShowSelectedRolesOnly;
	Items.RolesShowSelectedRolesOnly.Check = ShowSelectedRolesOnly;
	
	RefreshRoleTree();
	ExpandRoleSubsystems();
	
EndProcedure

&AtClient
Procedure GroupBySubsystems(Command)
	
	ShowRoleSubsystems = Not ShowRoleSubsystems;
	Items.RolesShowRoleSubsystems.Check = ShowRoleSubsystems;
	
	RefreshRoleTree();
	ExpandRoleSubsystems();
	
EndProcedure

&AtClient
Procedure EnableRoles(Command)
	
	UpdateRoleContent(Undefined, True);
	If ShowSelectedRolesOnly Then
		ExpandRoleSubsystems();
	EndIf;
	
EndProcedure

&AtClient
Procedure ExcludeRoles(Command)
	
	UpdateRoleContent(Undefined, False);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Procedure SetActionsOnForm()
	
	ActionsOnForm = New Structure;
	ActionsOnForm.Insert("Roles",                   ""); // "", "View",    "Edit"
	ActionsOnForm.Insert("ContactInformation",   "");    // "", "View",    "Edit"
	ActionsOnForm.Insert("InfoBaseUserProperties", "");  // "", "ViewAll", "EditAll", "EditOwn"
	ActionsOnForm.Insert("ItemProperties",       "");    // "", "View",    "Edit"
	
	If Users.InfoBaseUserWithFullAccess() Then
		// Administrator
		ActionsOnForm.Roles                  = "Edit";
		ActionsOnForm.ContactInformation     = "Edit";
		ActionsOnForm.InfoBaseUserProperties = "EditAll";
		ActionsOnForm.ItemProperties         = "Edit";
		
	ElsIf IsInRole("AddEditUsers")
	        And Not Users.InfoBaseUserWithFullAccess(Object.Ref) Then
		// The role for a person responsible for the user list and user groups
		// (a user who keeps records on employee recruiting, transfer, and position changes, 
   // as well as for creation of departments, subsidiaries, and workgroups).	ActionsOnForm.Roles                  = "";
		ActionsOnForm.ContactInformation     = "Edit";
		ActionsOnForm.InfoBaseUserProperties = "EditAll";
		ActionsOnForm.ItemProperties         = "Edit";
		
	ElsIf ValueIsFilled(Users.CurrentUser()) And
	          Object.Ref = Users.CurrentUser() Then
		// Own properties
		ActionsOnForm.Roles                  = "";
		ActionsOnForm.ContactInformation     = "Edit";
		ActionsOnForm.InfoBaseUserProperties = "EditOwn";
		ActionsOnForm.ItemProperties         = "View";
		
	Else
		// Another's properties
		ActionsOnForm.Roles                  = "";
		ActionsOnForm.ContactInformation     = "View";
		ActionsOnForm.InfoBaseUserProperties = "";
		ActionsOnForm.ItemProperties         = "View";
	EndIf;
	
	UsersOverridable.ChangeActionsOnForm(Object.Ref, ActionsOnForm);
	
	// Verifying action names on the form
	If Find(", View, Edit,", ", " + ActionsOnForm.Roles + ",") = 0 Then
		ActionsOnForm.Roles = "";
	ElsIf UsersOverridable.RoleEditProhibition() Then
		ActionsOnForm.Roles = "View";
	EndIf;
	If Find(", View, Edit,", ", " + ActionsOnForm.ContactInformation + ",") = 0 Then
		ActionsOnForm.ContactInformation = "";
	EndIf;
	If Find(", ViewAll, EditAll, EditOwn,", ", " + ActionsOnForm.InfoBaseUserProperties + ",") = 0 Then
		ActionsOnForm.InfoBaseUserProperties = "";
	EndIf;
	If Find(", View, Edit,", ", " + ActionsOnForm.ItemProperties + ",") = 0 Then
		ActionsOnForm.ItemProperties = "";
	EndIf;
	
EndProcedure

&AtServer
Function GetInfoBaseUserInfoStructure()
	
	// Restoring actions on the form if they have been changed on the client
	SetActionsOnForm();
	
	If ActionsOnForm.InfoBaseUserProperties <> "EditAll"
		And ActionsOnForm.InfoBaseUserProperties <> "EditOwn" Then
		
		// Nothing can be changed
		Return New Structure;
	EndIf;
	
	If Items.MismatchCommentFullName.Visible Then
		InfoBaseUserFullName = Object.Description;
	EndIf;
	
	If ActionsOnForm.InfoBaseUserProperties = "EditAll" Then
		Result = Users.NewInfoBaseUserInfo();
		FillPropertyValues(Result, ThisForm);
	Else
		Result = New Structure;
		Result.Insert("InfoBaseUserName", InfoBaseUserName);
		Result.Insert("InfoBaseUserPassword", InfoBaseUserPassword);
		Result.Insert("InfoBaseUserLanguage", InfoBaseUserLanguage);
	EndIf;
	Result.Insert("PasswordConfirmation", PasswordConfirmation);
	
	If ActionsOnForm.Roles = "Edit" Then
		CurrentRoles = InfoBaseUserRoles.Unload(, "Role").UnloadColumn("Role");
		Result.Insert("InfoBaseUserRoles", CurrentRoles);
	EndIf;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Reading, writing, deleting, creating an infobase user short name, checking for inconsistencies.

&AtServer
Procedure ReadInfoBaseUser(OnCopyItem = False)
	
	SetPrivilegedMode(True);
	
	ReadRoles = New Array;
	
	Password              = "";
	PasswordConfirmation  = "";
	ReadProperties        = Users.NewInfoBaseUserInfo();
	OldInfoBaseUserID     = Undefined;
	InfoBaseUserExists    = False;
	InfoBaseAccessAllowed = False;
	
	// Filling initial InfoBaseUser property values.
	If CommonUseCached.DataSeparationEnabled() Then
		ReadProperties.InfoBaseUserShowInList = False;
	Else
		ReadProperties.InfoBaseUserShowInList = Not Constants.UseExternalUsers.Get();
	EndIf;
	
	FillPropertyValues(ThisForm, ReadProperties);
	InfoBaseUserStandardAuthentication = True;
	
	If OnCopyItem Then
		
		If Users.ReadInfoBaseUser(Parameters.CopyingValue.InfoBaseUserID, ReadProperties, ReadRoles) Then
			// Setting a future relation for a new user.
			// because the copied one has a relation with InfoBaseUser,
			InfoBaseAccessAllowed = True;
			// Copping properties and roles of InfoBaseUser,
			// because InfoBaseUser of the copied user has been read.
			FillPropertyValues(ThisForm,
			                         ReadProperties,
			                         "InfoBaseUserStandardAuthentication,
			                         |InfoBaseUserCannotChangePassword,
			                         |InfoBaseUserShowInList,
			                         |InfoBaseUserOSAuthentication,
			                         |InfoBaseUserRunMode,
			                         |InfoBaseUserLanguage");
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
			                         |InfoBaseUserFullName,
			                         |InfoBaseUserStandardAuthentication,
			                         |InfoBaseUserShowInList,
			                         |InfoBaseUserCannotChangePassword,
			                         |InfoBaseUserOSAuthentication,
			                         |InfoBaseUserOSUser,
			                         |InfoBaseUserRunMode,
			                         |InfoBaseUserLanguage");
			
			If ReadProperties.InfoBaseUserPasswordIsSet Then
				Password             = "**********";
				PasswordConfirmation = "**********";
			EndIf;
		EndIf;
	EndIf;
	
	FillRoles(ReadRoles);
	
EndProcedure

&AtClient
Function GetInfoBaseUserShortName(Val FullName)
	
	Separators = New Array;
	Separators.Add(" ");
	Separators.Add(".");
	
	ShortName = "";
	For Counter = 1 to 3 Do
		
		If Counter <> 1 Then
			ShortName = ShortName + Upper(Left(FullName, 1));
		EndIf;
		
		SeparatorPosition = 0;
		For Each Separator In Separators Do
			CurrentSeparatorPosition = Find(FullName, Separator);
			If CurrentSeparatorPosition > 0
			   And (SeparatorPosition = 0
			      Or SeparatorPosition > CurrentSeparatorPosition ) Then
				SeparatorPosition = CurrentSeparatorPosition;
			EndIf;
		EndDo;
		
		If SeparatorPosition = 0 Then
			If Counter = 1 Then
				ShortName = FullName;
			EndIf;
			Break;
		EndIf;
		
		If Counter = 1 Then
			ShortName = Left(FullName, SeparatorPosition - 1);
		EndIf;
		
		FullName = Right(FullName, StrLen(FullName) - SeparatorPosition);
		While Separators.Find(Left(FullName, 1)) <> Undefined Do
			FullName = Mid(FullName, 2);
		EndDo;
	EndDo;
	
	Return ShortName;
	
EndFunction

&AtServer
Procedure FindUserAndInfoBaseUserInconsistencies(WriteParameters = Undefined)
	
	//** Checking whether the FullName property of InfoBaseUser matches the Description user property.
	
	If Not (ActionsOnForm.ItemProperties          = "Edit" And
	        ActionsOnForm.InfoBaseUserProperties = "EditAll") Then
		// FullName of the user cannot be changed
		InfoBaseUserFullName = Undefined;
	EndIf;
	
	If Not InfoBaseUserExists Or
	     InfoBaseUserFullName = Undefined Or
	     InfoBaseUserFullName = Object.Description Then
		
		Items.MismatchProcessingFullName.Visible = False;
		
	ElsIf ValueIsFilled(Object.Ref) Then
	
		Items.MismatchCommentFullName.Title = StringFunctionsClientServer.SubstituteParametersInString(
				Items.MismatchCommentFullName.Title,
				InfoBaseUserFullName);
	Else
		Object.Description = InfoBaseUserFullName;
		Items.MismatchProcessingFullName.Visible = False;
	EndIf;
	
	//** Defining relations of nonexistent infobase users
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
Procedure FillRoles(ReadRoles)
	
	InfoBaseUserRoles.Clear();
	
	For Each Role In ReadRoles Do
		InfoBaseUserRoles.Add().Role = Role;
	EndDo;
	
	RefreshRoleTree();
	
EndProcedure

&AtServer
Procedure SetPermanentEnabledProperty()
	
	Items.ContactInformation.Visible   = ValueIsFilled(ActionsOnForm.ContactInformation);
	Items.InfoBaseUserProperties.Visible = ValueIsFilled(ActionsOnForm.InfoBaseUserProperties);
	
	OutputRoleList = ValueIsFilled(ActionsOnForm.Roles);
	Items.RoleRepresentation.Visible = OutputRoleList;
	Items.PlatformAuthenticationProperties.Representation = 
		?(OutputRoleList, UsualGroupRepresentation.None, UsualGroupRepresentation.NormalSeparation);
	
	Items.Description.ReadOnly                          = ActionsOnForm.ItemProperties         <> "Edit";
	Items.InfoBaseAccessAllowed.ReadOnly                = ActionsOnForm.InfoBaseUserProperties <> "EditAll";
	Items.InfoBaseUserProperties.ReadOnly               = ActionsOnForm.InfoBaseUserProperties =  "ViewAll";
	Items.InfoBaseUserName.ReadOnly                     = ActionsOnForm.InfoBaseUserProperties <> "EditAll";
	Items.InfoBaseUserStandardAuthentication.ReadOnly   = ActionsOnForm.InfoBaseUserProperties <> "EditAll";
	Items.InfoBaseUserCannotChangePassword.ReadOnly = ActionsOnForm.InfoBaseUserProperties <> "EditAll";
	Items.InfoBaseUserShowInList.ReadOnly         = ActionsOnForm.InfoBaseUserProperties <> "EditAll";
	Items.InfoBaseUserOSAuthentication.ReadOnly         = ActionsOnForm.InfoBaseUserProperties <> "EditAll";
	Items.InfoBaseUserOSUser.ReadOnly                   = ActionsOnForm.InfoBaseUserProperties <> "EditAll";
	Items.InfoBaseUserRunMode.ReadOnly                  = ActionsOnForm.InfoBaseUserProperties <> "EditAll";
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetPropertyEnabled(Form)
	
	Items = Form.Items;
	
	Items.Password.ReadOnly             = Form.InfoBaseUserCannotChangePassword And Not Form.FullAccessUserAuthorized;
	Items.PasswordConfirmation.ReadOnly = Form.InfoBaseUserCannotChangePassword And Not Form.FullAccessUserAuthorized;
	
	Items.MainProperties.Enabled              = Form.InfoBaseAccessAllowed;
	Items.RoleRepresentation.Enabled          = Form.InfoBaseAccessAllowed;
	Items.InfoBaseUserName.AutoMarkIncomplete = Form.InfoBaseAccessAllowed;
	
	Items.Password.Enabled                             = Form.InfoBaseUserStandardAuthentication;
	Items.PasswordConfirmation.Enabled                 = Form.InfoBaseUserStandardAuthentication;
	Items.InfoBaseUserCannotChangePassword.Enabled = Form.InfoBaseUserStandardAuthentication;
	Items.InfoBaseUserShowInList.Enabled         = Form.InfoBaseUserStandardAuthentication;
	
	Items.InfoBaseUserOSUser.Enabled = Form.InfoBaseUserOSAuthentication;
	
	Items.InfoBaseAccessAllowed.Enabled = Not Form.Object.NotValid;
	
EndProcedure

&AtClient
Procedure InfoBaseUserRunModeClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
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

&AtServer
Procedure SetRolesReadOnly(Val RolesReadOnly = Undefined)
	
	If RolesReadOnly <> Undefined Then
		Items.Roles.ReadOnly          =     RolesReadOnly;
		Items.RolesCheckAll.Enabled   = Not RolesReadOnly;
		Items.RolesUncheckAll.Enabled = Not RolesReadOnly;
	EndIf;
	
EndProcedure

&AtClient
Procedure ExpandRoleSubsystems();
	
	// Expanding all subsystems
	For Each Row In Roles.GetItems() Do
		Items.Roles.Expand(Row.GetID(), True);
	EndDo;
	
EndProcedure

&AtServer
Procedure RefreshRoleTree()
	
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
	
	If CommonUseCached.DataSeparationEnabled() Then
		UserType = Enums.UserTypes.DataAreaUser;
	Else
		UserType = Enums.UserTypes.LocalApplicationUser;
	EndIf;
	
	RoleTree = UsersServerCached.RoleTree(ShowRoleSubsystems, UserType).Copy();
	RoleTree.Columns.Add("Check",         New TypeDescription("Boolean"));
	RoleTree.Columns.Add("PictureNumber", New TypeDescription("Number"));
	PrepareRoleTree(RoleTree.Rows, ShowSelectedRolesOnly);
	
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
Procedure PrepareRoleTree(Val Collection, Val ShowSelectedRolesOnly)
	
	Index = Collection.Count()-1;
	
	While Index >= 0 Do
		Row = Collection[Index];
		
		PrepareRoleTree(Row.Rows, ShowSelectedRolesOnly);
		
		If Row.IsRole Then
			Row.PictureNumber = 6;
			Row.Check = RoleCollection().FindRows(New Structure("Role", Row.Name)).Count() > 0;
			If ShowSelectedRolesOnly And Not Row.Check Then
				Collection.Delete(Index);
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
