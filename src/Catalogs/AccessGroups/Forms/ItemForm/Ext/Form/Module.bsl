
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Autotest") Then // Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
		Return;
	EndIf;
	
	// Preparing auxiliary data
 
AccessManagementInternal.OnCreateAtServerAllowedValueEditingForm(ThisObject);
	
	InitialSettingsOnReadAndCreate(Object);
	
	ExternalUsersCatalogAvailable = AccessRight(
		"View", Metadata.Catalogs.ExternalUsers);
	
	UserTypeList.Add(Type("CatalogRef.Users"));
	
	UserTypeList.Add(Type("CatalogRef.ExternalUsers"));
	
	// Filling the user type selection list filling
	FillUserTypeList();
	
	// Setting the availability of properties
	
	// Determining if the access restrictions must be set up
	If Not AccessManagement.UseRecordLevelSecurity() Then
		Items.Access.Visible = False;
	EndIf;
	
	// Setting availability for viewing the form in read only mode
	Items.UsersPick.Enabled            = Not ReadOnly;
	Items.ContextMenuUsersPick.Enabled = Not ReadOnly;
	
	If CommonUseCached.DataSeparationEnabled()
		And Object.Ref = Catalogs.AccessGroups.Administrators Then
		
		ActionsWithSaaSUser = Undefined;
		AccessManagementInternal.OnReceiveActionsWithSaaSUser(ActionsWithSaaSUser);
		
		If Not ActionsWithSaaSUser.ChangeAdmininstrativeAccess Then
			Raise
				NStr("en = 'Insufficient permissions to change the administrator content.'");
		EndIf;
	EndIf;
	
	ProcedureExecutedOnCreateAtServer = True;
	
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Version8_2 Then
		Items.UsersAdd.OnlyInAllActions = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If AnswerToQuestionOnOpenForm = "SetViewOnly" Then
		AnswerToQuestionOnOpenForm = "";
		ReadOnly = True;
	EndIf;
	
	If AnswerToQuestionOnOpenForm = "SetAdministratorProfile" Then
		AnswerToQuestionOnOpenForm = Undefined;
		Object.Profile = PredefinedValue("Catalog.AccessGroupProfiles.Administrator");
		Modified = True;
		
	ElsIf Object.Ref = PredefinedValue("Catalog.AccessGroups.Administrators")
		    And Object.Profile <> PredefinedValue("Catalog.AccessGroupProfiles.Administrator") Then
		
		Cancel = True;
		ShowQueryBox(
			New NotifyDescription("OnOpenAfterAdministratorProfileInstallationConfirmation", ThisObject),
			NStr("en = 'Administrators access group requires the Administrator profile.
			           |
			           |Apply the profile to the access group (No - open in read-only mode)?'"),
			QuestionDialogMode.YesNo,
			,
			DialogReturnCode.No);
	Else
		If AnswerToQuestionOnOpenForm = "RefreshAccessKindContent" Then
			AnswerToQuestionOnOpenForm = "";
			RefreshAccessKindContent();
			AccessKindContentOnReadIsChanged = False;
			
		ElsIf Not ReadOnly And AccessKindContentOnReadIsChanged Then
			
			Cancel = True;
			ShowQueryBox(
				New NotifyDescription("OnOpenAfterAccessKindUpdateConfirmation", ThisObject),
				NStr("en = 'Profile access kind content of this access group is changed.
				           |
				           |Update access kinds in the access group (No - open in read-only mode)?'"),
				QuestionDialogMode.YesNo,
				,
				DialogReturnCode.No);
		
		ElsIf Not ReadOnly
			   And Not ValueIsFilled(Object.Ref)
			   And TypeOf(FormOwner) = Type("FormTable")
			   And FormOwner.Parent.Parameters.Property("Profile") Then
			
			If ValueIsFilled(FormOwner.Parent.Parameters.Profile) Then
				Object.Profile = FormOwner.Parent.Parameters.Profile;
				AttachIdleHandler("IdleHandlerProfileOnChange", 0.1, True);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	If Parameters.Property("Autotest") Then // Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
		Return;
	EndIf;
	
	If Not ProcedureExecutedOnCreateAtServer Then
		Return;
	EndIf;
	
	AccessManagementInternal.OnRereadAtServerAllowedValueEditingForm(ThisObject, CurrentObject);
	
	InitialSettingsOnReadAndCreate(CurrentObject);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If StandardSubsystemsClientCached.ClientParameters().DataSeparationEnabled
	   And Object.Ref = PredefinedValue("Catalog.AccessGroups.Administrators")
	   And ServiceUserPassword = Undefined Then
		
		Cancel = True;
		StandardSubsystemsClient.PasswordForAuthenticationInServiceOnRequest(
			New NotifyDescription("BeforeWriteContinued", ThisObject, WriteParameters),
			ThisObject,
			ServiceUserPassword);
		Return;
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Not Users.InfobaseUserWithFullAccess() Then
		// The responsible user can not change anything except the user content.
		// In order to prevent any unauthorized access group changes on the client,
		// object is re-read.
		RestoreObjectWithoutGroupMembers(CurrentObject);
	EndIf;
	
	CurrentObject.Users.Clear();
	
	If CurrentObject.Ref <> Catalogs.AccessGroups.Administrators
	   And ValueIsFilled(CurrentObject.User) Then
		
		If PersonalAccessUse Then
			CurrentObject.Users.Add().User = CurrentObject.User;
		EndIf;
	Else
		For Each Item In GroupUsers.GetItems() Do
			CurrentObject.Users.Add().User = Item.User;
		EndDo;
	EndIf;
	
	If CurrentObject.Ref = Catalogs.AccessGroups.Administrators Then
		Object.Responsible = Undefined;
	EndIf;
	
	If CommonUseCached.DataSeparationEnabled()
		And Object.Ref = Catalogs.AccessGroups.Administrators Then
		
		CurrentObject.AdditionalProperties.Insert(
			"ServiceUserPassword", ServiceUserPassword);
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	SetPrivilegedMode(True);
	
	ProfileIsMarkedForDeletion = CommonUse.ObjectAttributeValue(
		Object.Profile, "DeletionMark") = True;
	
	SetPrivilegedMode(False);
	
	If Not Object.DeletionMark And ProfileIsMarkedForDeletion Then
		WriteParameters.Insert("WarnThatProfileIsMarkedForDeletion");
	EndIf;
	
	AccessManagementInternal.AfterWriteAtServerAllowedValueEditingForm(
		ThisObject, CurrentObject, WriteParameters);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_AccessGroups", New Structure, Object.Ref);
	
	If WriteParameters.Property("WarnThatProfileIsMarkedForDeletion") Then
		
		ShowMessageBox(,
			NStr("en = 'Access group does not affect the rights of participants
			           |because its profile is marked for deletion.'"));
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, AttributesToCheck)
	
	CheckedObjectAttributes = New Array;
	Errors = Undefined;
	
	// Checking whether blank or duplicate users are present
	CheckedObjectAttributes.Add("Users.User");
	UserTreeRows = FormAttributeToValue("GroupUsers").Rows;
	ErrorsCount = ?(Errors = Undefined, 0, Errors.Count());
	
	// Preparing data to check compliance for authorization object types
	If Object.UserType <> Undefined Then
		Query = New Query;
		Query.SetParameter(
			"Users", UserTreeRows.UnloadColumn("User"));
		Query.Text =
		"SELECT
		|	ExternalUsers.Ref AS User,
		|	ExternalUsers.AuthorizationObject AS AuthorizationObjectType
		|FROM
		|	Catalog.ExternalUsers AS ExternalUsers
		|WHERE
		|	ExternalUsers.Ref IN(&Users)
		|
		|UNION ALL
		|
		|SELECT
		|	ExternalUserGroups.Ref,
		|	ExternalUserGroups.AuthorizationObjectType
		|FROM
		|	Catalog.ExternalUserGroups AS ExternalUserGroups
		|WHERE
		|	ExternalUserGroups.Ref IN(&Users)";
		SetPrivilegedMode(True);
		UserAuthorizationObjectTypes = Query.Execute().Unload();
		SetPrivilegedMode(False);
		UserAuthorizationObjectTypes.Indexes.Add("User");
	EndIf;
	
	For Each CurrentRow In UserTreeRows Do
		LineNumber = UserTreeRows.IndexOf(CurrentRow);
		Party = CurrentRow.User;
		
		// Checking whether value is filled
		If Not ValueIsFilled(Party) Then
			CommonUseClientServer.AddUserError(Errors,
				"GroupUsers[%1].User",
				SpecifyMessage(NStr("en = 'User name is not specified.'"), Party),
				"GroupUsers",
				LineNumber,
				SpecifyMessage(NStr("en = 'User name is not specified in row #%1.'"), Party));
			Continue;
		EndIf;
		
		// Checking whether duplicate values are present
		FoundValues = UserTreeRows.FindRows(
			New Structure("User", CurrentRow.User));
		
		If FoundValues.Count() > 1 Then
			
			If TypeOf(CurrentRow.User)   = Type("CatalogRef.Users") Then
				SingleErrorText             = NStr("en = 'User ""%2"" is duplicated.'");
				SeveralErrorText            = NStr("en = 'User ""%2"" on line %1 is duplicated.'");
				
			ElsIf TypeOf(CurrentRow.User) = Type("CatalogRef.ExternalUsers") Then
				SingleErrorText  = NStr("en = 'External user ""%2"" is duplicated.'");
				SeveralErrorText = NStr("en = 'External user ""%2"" on line %1 is duplicated.'");
				
			ElsIf TypeOf(CurrentRow.User) = Type("CatalogRef.UserGroups") Then
				SingleErrorText  = NStr("en = 'User group ""%2"" is duplicated.'");
				SeveralErrorText = NStr("en = 'Users group ""%2""  on line %1 is duplicated.'");
			Else
				SingleErrorText  = NStr("en = 'External user group ""%2"" is duplicated.'");
				SeveralErrorText = NStr("en = 'External user group ""%2""  on line %1 is duplicated.'");
			EndIf;
			
			CommonUseClientServer.AddUserError(Errors,
				"GroupUsers[%1].User",
				SpecifyMessage(SingleErrorText, Party),
				"GroupUsers",
				LineNumber,
				SpecifyMessage(SeveralErrorText, Party));
		EndIf;
		
		// Checking users in the predefined Administrators group
		If Object.Ref = Catalogs.AccessGroups.Administrators
		   And TypeOf(CurrentRow.User) <> Type("CatalogRef.Users") Then
			
			If TypeOf(CurrentRow.User) = Type("CatalogRef.ExternalUsers") Then
				SingleErrorText  = NStr("en = 'External user ""%2:"" cannot be a member of the predefined Administrators access group.'");
				SeveralErrorText = NStr("en = 'External user ""%2"" on line %1 cannot be a member of the predifined Administrators access group.'");
				
			ElsIf TypeOf(CurrentRow.User) = Type("CatalogRef.UserGroups") Then
				SingleErrorText  = NStr("en = 'Users group ""%2""  cannot be a member of the predefined Administrators access group.'");
				SeveralErrorText = NStr("en = 'Users group ""%2"" on line %1 cannot be a member of the predefined Administrators access group.'");
			Else
				SingleErrorText  = NStr("en = 'External user group ""%2""  cannot be a member of the predefined Administrators access group.'");
				SeveralErrorText = NStr("en = 'External user group ""%2"" on the line %1 cannot be a member of the predefined Administrators access group.'");
			EndIf;
			
			CommonUseClientServer.AddUserError(Errors,
				"GroupUsers[%1].User",
				SpecifyMessage(SingleErrorText, Party),
				"GroupUsers",
				LineNumber,
				SpecifyMessage(SeveralErrorText, Party));
		EndIf;
		
		If Object.UserType <> Undefined Then
			// Checking whether the authorization object types for 
			// external users and external user groups match the user type specified in an access group.
			SingleErrorText = "";
			
			If TypeOf(CurrentRow.User) = Type("CatalogRef.Users") Then
				
				If TypeOf(Object.UserType) <> Type("CatalogRef.Users") Then
					SingleErrorText  = NStr("en = 'User ""%2"" does not match the specified participant type.'");
					SeveralErrorText = NStr("en = 'User ""%2"" on line %1 does not match the specified type of participants.'");
				EndIf;
				
			ElsIf TypeOf(CurrentRow.User) = Type("CatalogRef.UserGroups") Then
				
				If TypeOf(Object.UserType) <> Type("CatalogRef.Users") Then
					SingleErrorText  = NStr("en = 'Users group ""%2"" does not match the specified type of participants.'");
					SeveralErrorText = NStr("en = 'Users group ""%2"" on line %1 does not match the specified type of participants.'");
				EndIf;
			Else
				AuthorizationObjectTypeDescription = UserAuthorizationObjectTypes.Find(
					CurrentRow.User, "User");
				
				If TypeOf(CurrentRow.User) = Type("CatalogRef.ExternalUsers") Then
					
					If AuthorizationObjectTypeDescription = Undefined
					 Or TypeOf(Object.UserType) <> TypeOf(AuthorizationObjectTypeDescription.AuthorizationObjectType) Then
						
						SingleErrorText  = NStr("en = 'EExternal user ""%2"" does not match the specified type of participants.'");
						SeveralErrorText = NStr("en = 'External user ""%2"" on line %1 does not match the specified type of participants.'");
					EndIf;
				
				Else // External user group
					
					If AuthorizationObjectTypeDescription = Undefined
					 Or TypeOf(Object.UserType) = Type("CatalogRef.Users")
					 Or AuthorizationObjectTypeDescription.AuthorizationObjectType <> Undefined
					   And TypeOf(Object.UserType) <> TypeOf(AuthorizationObjectTypeDescription.AuthorizationObjectType) Then
						
						SingleErrorText  = NStr("en = 'External user group ""%2"" does not match the specified type of participants.'");
						SeveralErrorText = NStr("en = 'External user group ""%2"" on line %1 does not match the specified type of participants.'");
					EndIf;
				EndIf;
			EndIf;
			
			If ValueIsFilled(SingleErrorText) Then
				CommonUseClientServer.AddUserError(Errors,
					"GroupUsers[%1].User",
					SpecifyMessage(SingleErrorText, Party),
					"GroupUsers",
					LineNumber,
					SpecifyMessage(SeveralErrorText, Party));
			EndIf;
		EndIf;
		
	EndDo;
	
	If Not CommonUseCached.DataSeparationEnabled()
		And Object.Ref = Catalogs.AccessGroups.Administrators Then
		
		ErrorDescription = "";
		AccessManagementInternal.CheckAdministratorsAccessGroupForInfobaseUser(
			GroupUsers.GetItems(), ErrorDescription);
		
		If ValueIsFilled(ErrorDescription) Then
			CommonUseClientServer.AddUserError(Errors,
				"GroupUsers", ErrorDescription);
		EndIf;
	EndIf;
	
	// Checking for blank and duplicate access values
	IgnoreKindsAndValuesCheck = False;
	If ErrorsCount <> ?(Errors = Undefined, 0, Errors.Count()) Then
		IgnoreKindsAndValuesCheck = True;
		Items.UsersAndAccess.CurrentPage = Items.GroupUsers;
	EndIf;
	
	AccessManagementInternalClientServer.ProcessingCheckOfFillingEditingFormsOfAllowedValuesAtServer(
		ThisObject, Cancel, CheckedObjectAttributes, Errors, IgnoreKindsAndValuesCheck);
	
	CommonUseClientServer.ShowErrorsToUser(Errors, Cancel);
	
	AttributesToCheck.Delete(AttributesToCheck.Find("Object"));
	CurrentObject = FormAttributeToValue("Object");
	
	CurrentObject.AdditionalProperties.Insert(
		"CheckedObjectAttributes", CheckedObjectAttributes);
	
	If Not CurrentObject.CheckFilling() Then
		Cancel = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure ProfileOnChange(Item)
	
	ProfileOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure TypePresentationUsersStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	ShowChooseFromList(
		New NotifyDescription("TypePresentationUsersStartChoiceEnd", ThisObject),
		UserTypes,
		Item,
		UserTypes.FindByValue(Object.UserType));
	
EndProcedure

&AtClient
Procedure PresentationOfUserTypeClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure UserOwnerStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

#EndRegion

#Region UserFormTableElementsEventHandlers

&AtClient
Procedure UsersOnChange(Item)
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure UsersBeforeAddRow(Item, Cancel, Clone, Parent, Group)
	
	If Clone Then
		
		If Item.CurrentData.GetParent() <> Undefined Then
			Cancel = True;
			
			Items.Users.CurrentRow =
				Item.CurrentData.GetParent().GetID();
			
			Items.Users.CopyRow();
		EndIf;
		
	ElsIf Items.Users.CurrentRow <> Undefined Then
		Cancel = True;
		Items.Users.CopyRow();
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersBeforeRowChange(Item, Cancel)
	
	If Item.CurrentData.GetParent() <> Undefined Then
		Cancel = True;
		
		Items.Users.CurrentRow =
			Item.CurrentData.GetParent().GetID();
		
		Items.Users.ChangeRow();
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersBeforeDelete(Item, Cancel)
	
	ParentRow = Item.CurrentData.GetParent();
	
	If ParentRow <> Undefined Then
		Cancel = True;
		
		If TypeOf(ParentRow.User) =
		        Type("CatalogRef.UserGroups") Then
			
			ShowMessageBox(,
				NStr("en = 'User groups are displayed for information purpose only
				           |(they are granted user groups access).
				           |They cannot be deleted from this list.'"));
		Else
			ShowMessageBox(,
				NStr("en = 'External group users are displayed for information purpose only
				           |that they receive the group access of external user.
				           |They cannot be deleted from this list.'"));
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersOnStartEdit(Item, NewRow, Clone)
	
	If Clone Then
		Item.CurrentData.User = Undefined;
	EndIf;
	
	If Item.CurrentData.User = Undefined Then
		Item.CurrentData.PictureNumber = -1;
		Item.CurrentData.User = PredefinedValue(
			"Catalog.Users.EmptyRef");
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersOnEditEnd(Item, NewRow, CancelEdit)
	
	If NewRow
	   And Item.CurrentData <> Undefined
	   And Item.CurrentData.User = PredefinedValue(
	     	"Catalog.Users.EmptyRef") Then
		
		Item.CurrentData.User = Undefined;
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	HasChanges = False;
	If PickMode Then
		GroupUsers.GetItems().Clear();
	EndIf;
	ModifiedRows = New Array;
	
	If TypeOf(SelectedValue) = Type("Array") Then
		For Each Value In SelectedValue Do
			ValueNotFound = True;
			For Each Item In GroupUsers.GetItems() Do
				If Item.User = Value Then
					ValueNotFound = False;
					Break;
				EndIf;
			EndDo;
			If ValueNotFound Then
				NewItem = GroupUsers.GetItems().Add();
				NewItem.User = Value;
				ModifiedRows.Add(NewItem.GetID());
			EndIf;
		EndDo;
		
	ElsIf Item.CurrentData.User <> SelectedValue Then
		Item.CurrentData.User = SelectedValue;
		ModifiedRows.Add(Item.CurrentRow);
	EndIf;
	
	If ModifiedRows.Count() > 0 Then
		UpdatedRows = Undefined;
		RefreshGroupUsers(ModifiedRows, UpdatedRows);
		For Each RowID In UpdatedRows Do
			Items.Users.Expand(RowID);
		EndDo;
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersAfterDelete(Item)
	
	// Tree view setting.
	AreNested = False;
	For Each Item In GroupUsers.GetItems() Do
		If Item.GetItems().Count() > 0 Then
			AreNested = True;
			Break;
		EndIf;
	EndDo;
	
	Items.Users.Representation =
		?(AreNested, TableRepresentation.Tree, TableRepresentation.List);
	
EndProcedure

&AtClient
Procedure UserOnChange(Item)
	
	If ValueIsFilled(Items.Users.CurrentData.User) Then
		RefreshGroupUsers(Items.Users.CurrentRow);
		Items.Users.Expand(Items.Users.CurrentRow);
	Else
		Items.Users.CurrentData.PictureNumber = -1;
	EndIf;
	
EndProcedure

&AtClient
Procedure UserStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	SelectPickUsers(False);
	PickMode = False;
	
EndProcedure

&AtClient
Procedure UserClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	Items.Users.CurrentData.PictureNumber = -1;
	Items.Users.CurrentData.User  = PredefinedValue(
		"Catalog.Users.EmptyRef");
	
EndProcedure

&AtClient
Procedure UserTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	If ValueIsFilled(Text) Then
		StandardProcessing = False;
		If Object.Ref = PredefinedValue("Catalog.AccessGroups.Administrators") Then
			ChoiceData = AccessManagementInternalServerCall.GenerateUserSelectionData(
				Text, False, False);
		Else
			ChoiceData = AccessManagementInternalServerCall.GenerateUserSelectionData(
				Text);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure UserAutoComplete(Item, Text, ChoiceData, Waiting, StandardProcessing)
	
	If ValueIsFilled(Text) Then
		StandardProcessing = False;
		If Object.Ref = PredefinedValue("Catalog.AccessGroups.Administrators") Then
			ChoiceData = AccessManagementInternalServerCall.GenerateUserSelectionData(
				Text, False, False);
		Else
			ChoiceData = AccessManagementInternalServerCall.GenerateUserSelectionData(
				Text);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region AccessKindFormTableItemEventHandlers

&AtClient
Procedure AccessKindsChoice(Item, SelectedRow, Field, StandardProcessing)
	
	If Not ReadOnly Then
		Items.AccessKinds.ChangeRow();
	EndIf;
	
EndProcedure

&AtClient
Procedure AccessKindsOnActivateRow(Item)
	
	AccessManagementInternalClient.AccessKindsOnActivateRow(
		ThisObject, Item);
	
EndProcedure

&AtClient
Procedure AccessKindsOnActivateCell(Item)
	
	AccessManagementInternalClient.AccessKindsOnActivateCell(
		ThisObject, Item);
	
EndProcedure

&AtClient
Procedure AccessKindsOnStartEdit(Item, NewRow, Clone)
	
	AccessManagementInternalClient.AccessKindsOnStartEdit(
		ThisObject, Item, NewRow, Clone);
	
EndProcedure

&AtClient
Procedure AccessKindsOnEndEdit(Item, NewRow, CancelEdit)
	
	AccessManagementInternalClient.AccessKindsOnEndEdit(
		ThisObject, Item, NewRow, CancelEdit);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event handlers of the AllAllowedPresentation item of the AccessKinds form table

&AtClient
Procedure AccessKindsAllAllowedPresentationOnChange(Item)
	
	AccessManagementInternalClient.AccessKindsAllAllowedPresentationOnChange(
		ThisObject, Item);
	
EndProcedure

&AtClient
Procedure AccessKindsAllAllowedPresentationChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	AccessManagementInternalClient.AccessKindsAllAllowedPresentationChoiceProcessing(
		ThisObject, Item, SelectedValue, StandardProcessing);
	
EndProcedure

#EndRegion

#Region AccessValueFormTableItemEventHandlers

&AtClient
Procedure AccessValuesOnChange(Item)
	
	AccessManagementInternalClient.AccessValuesOnChange(
		ThisObject, Item);
	
EndProcedure

&AtClient
Procedure AccessValuesOnStartEdit(Item, NewRow, Clone)
	
	AccessManagementInternalClient.AccessValuesOnStartEdit(
		ThisObject, Item, NewRow, Clone);
	
EndProcedure

&AtClient
Procedure AccessValuesOnEndEdit(Item, NewRow, CancelEdit)
	
	AccessManagementInternalClient.AccessValuesOnEndEdit(
		ThisObject, Item, NewRow, CancelEdit);
	
EndProcedure

&AtClient
Procedure AccessValueStartChoice(Item, ChoiceData, StandardProcessing)
	
	AccessManagementInternalClient.AccessValueStartChoice(
		ThisObject, Item, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure AccessValueChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	AccessManagementInternalClient.AccessValueChoiceProcessing(
		ThisObject, Item, SelectedValue, StandardProcessing);
	
EndProcedure

&AtClient
Procedure AccessValueClearing(Item, StandardProcessing)
	
	AccessManagementInternalClient.AccessValueClearing(
		ThisObject, Item, StandardProcessing);
	
EndProcedure

&AtClient
Procedure AccessValueAutoComplete(Item, Text, ChoiceData, Waiting, StandardProcessing)
	
	AccessManagementInternalClient.AccessValueAutoComplete(
		ThisObject, Item, Text, ChoiceData, Waiting, StandardProcessing);
	
EndProcedure

&AtClient
Procedure AccessValueTextEditCompletion(Item, Text, ChoiceData, StandardProcessing)
	
	AccessManagementInternalClient.AccessValueTextEditCompletion(
		ThisObject, Item, Text, ChoiceData, StandardProcessing);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Pick(Command)
	
	SelectPickUsers(True);
	PickMode = True;
	
EndProcedure

&AtClient
Procedure ShowUnusedAccessKinds(Command)
	
	ShowNotUsedAccessKindsAtServer();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// OnOpen event handler continuation
&AtClient
Procedure OnOpenAfterAdministratorProfileInstallationConfirmation(Answer, NotDefined) Export
	
	If Answer = DialogReturnCode.Yes Then
		AnswerQuestionsOnFormOpen = "SetAdministratorProfile";
	Else
		AnswerQuestionsOnFormOpen = "SetViewOnly";
	EndIf;
	
	Open();
	
EndProcedure

// OnOpen event handler continuation
&AtClient
Procedure OnOpenAfterAccessKindUpdateConfirmation(Answer, NotDefined) Export
	
	If Answer = DialogReturnCode.Yes Then
		AnswerQuestionsOnFormOpen = "RefreshAccessKindContent";
	Else
		AnswerQuestionsOnFormOpen = "SetViewOnly";
	EndIf;
	
	Open();
	
EndProcedure

// BeforeWrite event handler continuation
&AtClient
Procedure BeforeWriteContinued(SaaSUserNewPassword, WriteParameters) Export
	
	If SaaSUserNewPassword = Undefined Then
		Return;
	EndIf;
	
	ServiceUserPassword = SaaSUserNewPassword;
	
	Try
		
		Write(WriteParameters);
		
	Except
		
		ServiceUserPassword = Undefined;
		Raise;
		
	EndTry;
	
EndProcedure

// TypePresentationUsersStartChoice event handler continuation
&AtClient
Procedure TypePresentationUsersStartChoiceEnd(SelectedItem, NotDefined) Export
	
	If SelectedItem <> Undefined
	   And Object.UserType <> SelectedItem.Value Then
		
		Modified = True;
		Object.UserType       = SelectedItem.Value;
		TypePresentationUsers = SelectedItem.Presentation;
		
		If Object.UserType <> Undefined Then
			DeleteNotTypicalUsers();
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure IdleHandlerProfileOnChange()
	
	ProfileOnChangeAtServer();
	
EndProcedure

&AtServer
Procedure InitialSettingsOnReadAndCreate(CurrentObject)
	
	If CurrentObject.Ref <> Catalogs.AccessGroups.Administrators Then
		
		// Preparing for personal access group mode
		If ValueIsFilled(CurrentObject.User) Then
			
			AutoTitle = False;
			
			Title
				= CurrentObject.Description
				+ ": "
				+ CurrentObject.User
				+ " "
				+ NStr("en = '(Access group)'");
			
			Filter = New Structure("User", CurrentObject.User);
			FoundRows = CurrentObject.Users.FindRows(Filter);
			PersonalAccessUse = FoundRows.Count() > 0;
		Else
			AutoTitle = True;
		EndIf;
		
		UserIsFull = ValueIsFilled(CurrentObject.User);
		
		Items.Description.ReadOnly                = UserIsFull;
		Items.Parent.ReadOnly                     = UserIsFull;
		Items.Profile.ReadOnly                    = UserIsFull;
		Items.PersonalGroupProperties.Visible     = UserIsFull;
		Items.UserTypePresentation.Visible        = Not UserIsFull;
		Items.GroupUsers.Visible                  = Not UserIsFull;
		Items.ResponsibleForPersonalGroup.Visible = UserIsFull;
		
		Items.UsersAndAccess.PagesRepresentation =
			?(UserIsFull,
			  FormPagesRepresentation.None,
			  FormPagesRepresentation.TabsOnTop);
		
		Items.AccessKinds.TitleLocation =
			?(UserIsFull,
			  FormItemTitleLocation.Top,
			  FormItemTitleLocation.None);
		
		Items.UserTypePresentation.Visible
			= Not UserIsFull
			And (    ExternalUsers.UseExternalUsers()
			   Or   Object.UserType <> Undefined
			       And TypeOf(Object.UserType) <> Type("CatalogRef.Users"));
		
		Items.UserOwner.ReadOnly
			= AccessManagementInternal.SimplifiedAccessRightSetupInterface();
		
		// Preparing to edit users responsible for participants
		If Not Users.InfobaseUserWithFullAccess() Then
			Items.Description.ReadOnly = True;
			Items.Parent.ReadOnly = True;
			Items.Profile.ReadOnly = True;
			Items.TypePresentationUsers.ReadOnly = True;
			Items.Access.ReadOnly = True;
			Items.Responsible.ReadOnly = True;
			Items.ResponsibleForPersonalGroup.ReadOnly = True;
			Items.Description.ReadOnly = True;
		EndIf;
	Else
		Items.Description.ReadOnly                = True;
		Items.Profile.ReadOnly                    = True;
		Items.PersonalGroupsProperties.Visible    = False;
		Items.TypePresentationUsers.ReadOnly      = True;
		Items.Responsible.ReadOnly                = True;
		Items.ResponsibleForPersonalGroup.Visible = False;
		Items.Description.ReadOnly                = True;
		
		If Not AccessManagement.RoleExists("FullAccess") Then
			ReadOnly = True;
		EndIf;
	EndIf;
	
	RefreshAccessKindContent(True);
	
	// Preparing user tree
	UserTree = GroupUsers.GetItems();
	UserTree.Clear();
	For Each TSRow In CurrentObject.Users Do
		UserTree.Add().User = TSRow.User;
	EndDo;
	RefreshGroupUsers();
	
EndProcedure

&AtServer
Procedure ProfileOnChangeAtServer()
	
	RefreshAccessKindContent();
	AccessManagementInternalClientServer.FillPropertiesOfAccessKindsInForm(ThisObject);
	
EndProcedure

&AtServer
Procedure FillUserTypeList()
	
	UserTypes.Add(
		Undefined,
		NStr("en = 'Arbitrary participants'"));
	
	UserTypes.Add(
		Catalogs.Users.EmptyRef(),
		NStr("en = 'Common users'"));
	
	If UseExternalUsers Then
		
		AuthorizationObjectRefTypes =
			Metadata.Catalogs.ExternalUsers.Attributes.AuthorizationObject.Type.Types();
		
		For Each AuthorizationObjectRefType In AuthorizationObjectRefTypes Do
			
			TypeMetadata = Metadata.FindByType(AuthorizationObjectRefType);
			
			TypeArray = New Array;
			TypeArray.Add(AuthorizationObjectRefType);
			RefTypeDescription = New TypeDescription(TypeArray);
			
			UserTypes.Add(
				RefTypeDescription.AdjustValue(Undefined),
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'External users (%1)'"),
					TypeMetadata.Synonym));
		EndDo;
	EndIf;
	
	FoundItem = UserTypes.FindByValue(Object.UserType);
	
	TypePresentationUsers =
		?(FoundItem = Undefined,
		  StringFunctionsClientServer.SubstituteParametersInString(
		      NStr("en = 'Unknown type ""%1""'"),
		      String(TypeOf(Object.UserType))),
		  FoundItem.Presentation);
	
EndProcedure

&AtServer
Procedure DeleteNotTypicalUsers()
	
	If Object.UserType = Undefined Then
		Return;
	EndIf;
	
	If TypeOf(Object.UserType) = Type("CatalogRef.Users") Then
	
		Index = Object.Users.Count()-1;
		While Index >= 0 Do
			
			If TypeOf(Object.Users[Index].User)
			     <> Type("CatalogRef.Users")
			   And TypeOf(Object.Users[Index].User)
			     <> Type("CatalogRef.UserGroups") Then
				
				Object.Users.Delete(Index);
			EndIf;
			
			Index = Index - 1;
		EndDo;
	Else
		Index = Object.Users.Count()-1;
		While Index >= 0 Do
			
			If TypeOf(Object.Users[Index].User)
			     <> Type("CatalogRef.ExternalUsers")
			   And TypeOf(Object.Users[Index].User)
			     <> Type("CatalogRef.ExternalUserGroups") Then
				
				Object.Users.Delete(Index);
			EndIf;
			Index = Index - 1;
		EndDo;
		
		Query = New Query(
		"SELECT
		|	ExternalUsers.Ref
		|FROM
		|	Catalog.ExternalUsers AS ExternalUsers
		|WHERE
		|	VALUETYPE(ExternalUsers.AuthorizationObject) <> &ExternalUserType
		|	AND ExternalUsers.Ref IN(&SelectedExternalUsersAndGroups)
		|
		|UNION ALL
		|
		|SELECT
		|	ExternalUserGroups.Ref
		|FROM
		|	Catalog.ExternalUserGroups AS ExternalUserGroups
		|WHERE
		|	ExternalUserGroups.AuthorizationObjectType <> UNDEFINED
		|	AND VALUETYPE(ExternalUserGroups.AuthorizationObjectType) <> &ExternalUserType
		|	AND ExternalUserGroups.Ref IN(&SelectedExternalUsersAndGroups)");
		
		Query.SetParameter(
			"SelectedExternalUsersAndGroups",
			Object.Users.Unload().UnloadColumn("User"));
		
		Query.SetParameter("ExternalUserType", TypeOf(Object.UserType));
		
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			Filter = New Structure("User", Selection.Ref);
			FoundRows = Object.Users.FindRows(Filter);
			For Each FoundRow In FoundRows Do
				Object.Users.Delete(Object.Users.IndexOf(FoundRow));
			EndDo;
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Procedure RefreshAccessKindContent(Val OnReadAtServer = False)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ProfileAccessKinds.AccessKind,
	|	ProfileAccessKinds.Preset,
	|	ProfileAccessKinds.AllAllowed
	|FROM
	|	Catalog.AccessGroupProfiles.AccessKinds AS ProfileAccessKinds
	|WHERE
	|	ProfileAccessKinds.Ref = &Ref
	|	AND Not ProfileAccessKinds.Preset";
	
	Query.SetParameter("Ref", Object.Profile);
	
	SetPrivilegedMode(True);
	ProfileAccessKinds = Query.Execute().Unload();
	SetPrivilegedMode(False);
	
	AccessKindContentChanged = False;
	
	// Adding missing access types
	Index = ProfileAccessKinds.Count() - 1;
	While Index >= 0 Do
		Row = ProfileAccessKinds[Index];
		
		Filter = New Structure("AccessKind", Row.AccessKind);
		AccessKindProperties = AccessManagementInternal.AccessKindProperties(Row.AccessKind);
		
		If AccessKindProperties = Undefined Then
			ProfileAccessKinds.Delete(Row);
		
		ElsIf Object.AccessKinds.FindRows(Filter).Count() = 0 Then
			AccessKindContentChanged = True;
			
			If OnReadAtServer Then
				Break;
			Else
				NewRow = Object.AccessKinds.Add();
				NewRow.AccessKind = Row.AccessKind;
				NewRow.AllAllowed = Row.AllAllowed;
			EndIf;
		EndIf;
		Index = Index - 1;
	EndDo;
	
	// Deleting unused access types
	Index = Object.AccessKinds.Count() - 1;
	While Index >= 0 Do
		
		AccessKind = Object.AccessKinds[Index].AccessKind;
		Filter = New Structure("AccessKind", AccessKind);
		
		AccessKindPropertiesInProfile = ProfileAccessKinds.FindRows(Filter);
		AccessKindProperties = AccessManagementInternal.AccessKindProperties(AccessKind);
		
		If AccessKindProperties = Undefined
		 Or ProfileAccessKinds.FindRows(Filter).Count() = 0 Then
			
			AccessKindContentChanged = True;
			If OnReadAtServer Then
				Break;
			Else
				Object.AccessKinds.Delete(Index);
				For Each CollectionItem In Object.AccessValues.FindRows(Filter) Do
					Object.AccessValues.Delete(CollectionItem);
				EndDo;
			EndIf;
		EndIf;
		Index = Index - 1;
	EndDo;
	
	Modified = Modified
		Or AccessKindContentChanged And Not OnReadAtServer;
	
	// Setting a flag for prompting the user if they want to update the access kind content
	If OnReadAtServer
	     And Not Object.Ref.IsEmpty() // Is new
	     And AccessKindContentChanged
	     And Users.InfobaseUserWithFullAccess() // Only the administrator can update the access kinds.
	     And CommonUse.ObjectAttributeValue(Object.Ref, "Profile") = Object.Profile Then
	     
		AccessKindContentOnReadIsChanged = True;
	EndIf;
	
	Items.Access.Enabled = Object.AccessKinds.Count() > 0;
	
	// Setting access kind order by profile
	If Not AccessKindContentOnReadIsChanged Then
		For Each TSRow In ProfileAccessKinds Do
			Filter = New Structure("AccessKind", TSRow.AccessKind);
			Index = Object.AccessKinds.IndexOf(Object.AccessKinds.FindRows(Filter)[0]);
			Object.AccessKinds.Move(Index, ProfileAccessKinds.IndexOf(TSRow) - Index);
		EndDo;
	EndIf;
	
	If AccessKindContentChanged Then
		CurrentAccessKind = Undefined;
	EndIf;
	
	AccessManagementInternalClientServer.FillPropertiesOfAccessKindsInForm(ThisObject);
	
EndProcedure

&AtServer
Procedure ShowNotUsedAccessKindsAtServer()
	
	AccessManagementInternal.RefreshNotUsedAccessKindRepresentation(ThisObject);
	
EndProcedure

&AtClient
Procedure ShowSelectionTypeUsersOrExternalUsers(ContinuationHandler)
	
	ExternalUsersSelectionAndPickup = False;
	
	If Object.Ref = PredefinedValue("Catalog.AccessGroups.Administrators") Then
		ExecuteNotifyProcessing(ContinuationHandler, ExternalUsersSelectionAndPickup);
		Return;
	EndIf;
	
	If Object.UserType <> Undefined Then
		If TypeOf(Object.UserType) <> Type("CatalogRef.Users") Then
			ExternalUsersSelectionAndPickup = True;
		EndIf;
		ExecuteNotifyProcessing(ContinuationHandler, ExternalUsersSelectionAndPickup);
		Return;
	EndIf;
	
	If UseExternalUsers Then
		
		UserTypeList.ShowChooseItem(
			New NotifyDescription(
				"ShowSelectionTypeUsersOrExternalUsersEnd",
				ThisObject,
				ContinuationHandler),
			NStr("en = 'Select data type'"),
			UserTypeList[0]);
	Else
		ExecuteNotifyProcessing(ContinuationHandler, ExternalUsersSelectionAndPickup);
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowSelectionTypeUsersOrExternalUsersEnd(SelectedItem, ContinuationHandler) Export
	
	If SelectedItem <> Undefined Then
		ExternalUsersSelectionAndPickup =
			SelectedItem.Value = Type("CatalogRef.ExternalUsers");
		
		ExecuteNotifyProcessing(ContinuationHandler, ExternalUsersSelectionAndPickup);
	Else
		ExecuteNotifyProcessing(ContinuationHandler, Undefined);
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectPickUsers(Pick)
	
	CurrentUser = ?(Items.Users.CurrentData = Undefined,
		Undefined, Items.Users.CurrentData.User);
	
	If Not Pick
	   And ValueIsFilled(CurrentUser)
	   And (    TypeOf(CurrentUser) = Type("CatalogRef.Users")
	      Or TypeOf(CurrentUser) = Type("CatalogRef.UserGroups") ) Then
	
		ExternalUsersSelectionAndPickup = False;
	
	ElsIf Not Pick
	        And UseExternalUsers
	        And ValueIsFilled(CurrentUser)
	        And (    TypeOf(CurrentUser) = Type("CatalogRef.ExternalUsers")
	           Or TypeOf(CurrentUser) = Type("CatalogRef.ExternalUserGroups") ) Then
	
		ExternalUsersSelectionAndPickup = True;
	Else
		ShowSelectionTypeUsersOrExternalUsers(
			New NotifyDescription("SelectPickUsersEnd", ThisObject, Pick));
		Return;
	EndIf;
	
	SelectPickUsersEnd(ExternalUsersSelectionAndPickup, Pick);
	
EndProcedure

&AtClient
Procedure SelectPickUsersEnd(ExternalUsersSelectionAndPickup, Pick) Export
	
	If ExternalUsersSelectionAndPickup = Undefined Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("CurrentRow", ?(
		Items.Users.CurrentData = Undefined,
		Undefined,
		Items.Users.CurrentData.User));
	
	If Object.Ref <> PredefinedValue("Catalog.AccessGroups.Administrators") Then
		If ExternalUsersSelectionAndPickup Then
			FormParameters.Insert("ExternalUserGroupSelection", True);
		Else
			FormParameters.Insert("UserGroupSelection", True);
		EndIf;
	EndIf;
	
	If Pick Then
		FormParameters.Insert("CloseOnChoice", False);
		FormParameters.Insert("Multiselect", True);
		FormParameters.Insert("ExtendedPick", True);
		FormParameters.Insert("ExtendedPickFormParameters", SelectedAccessGroupMembers());
	EndIf;
	
	If ExternalUsersSelectionAndPickup Then
	
		If Object.UserType <> Undefined Then
			FormParameters.Insert("AuthorizationObjectType", Object.UserType);
		EndIf;
		If ExternalUsersCatalogAvailable Then
			OpenForm("Catalog.ExternalUsers.ChoiceForm", FormParameters, Items.Users);
		Else
			ShowMessageBox(, NStr("en = 'Insufficient rights for external user selection.'"));
		EndIf;
	Else
		OpenForm("Catalog.Users.ChoiceForm", FormParameters, Items.Users);
	EndIf;
	
EndProcedure

&AtServer
Function SelectedAccessGroupMembers()
	
	CollectionItems = GroupUsers.GetItems();
	
	SelectedUsers = New ValueTable;
	SelectedUsers.Columns.Add("User");
	SelectedUsers.Columns.Add("PictureNumber");
	
	For Each Item In CollectionItems Do
		
		SelectedUsersRow = SelectedUsers.Add();
		SelectedUsersRow.User = Item.User;
		SelectedUsersRow.PictureNumber = Item.PictureNumber;
		
	EndDo;
	
	PickFormTitle = NStr("en = 'Select the access group members'");
	ExtendedPickFormParameters = New Structure("PickFormTitle, SelectedUsers",
	                                                   PickFormTitle, SelectedUsers);
	StorageAddress = PutToTempStorage(ExtendedPickFormParameters);
	Return StorageAddress;
	
EndFunction

&AtServer
Procedure RefreshGroupUsers(RowID = Undefined,
                                     ModifiedRows = Undefined)
	
	SetPrivilegedMode(True);
	ModifiedRows = New Array;
	
	If RowID = Undefined Then
		CollectionItems = GroupUsers.GetItems();
		
	ElsIf TypeOf(RowID) = Type("Array") Then
		CollectionItems = New Array;
		For Each ID In RowID Do
			CollectionItems.Add(GroupUsers.FindByID(ID));
		EndDo;
	Else
		CollectionItems = New Array;
		CollectionItems.Add(GroupUsers.FindByID(RowID));
	EndIf;
	
	UserGroupMembers = New Array;
	For Each Item In CollectionItems Do
		
		If TypeOf(Item.User) = Type("CatalogRef.UserGroups")
		 Or TypeOf(Item.User) = Type("CatalogRef.ExternalUserGroups") Then
		
			UserGroupMembers.Add(Item.User);
		EndIf;
	EndDo;
	
	Query = New Query;
	Query.SetParameter("UserGroupMembers", UserGroupMembers);
	Query.Text =
	"SELECT
	|	UserGroupContents.UserGroup,
	|	UserGroupContents.User
	|FROM
	|	InformationRegister.UserGroupContents AS UserGroupContents
	|WHERE
	|	UserGroupContents.UserGroup IN(&UserGroupMembers)";
	
	GroupsUsers = Query.Execute().Unload();
	GroupsUsers.Indexes.Add("UserGroup");
	
	For Each Item In CollectionItems Do
		Item.Ref = Item.User;
		
		If TypeOf(Item.User) = Type("CatalogRef.UserGroups")
		 Or TypeOf(Item.User) = Type("CatalogRef.ExternalUserGroups") Then
		
			// Filling group users
			OldUsers = Item.GetItems();
			Filter = New Structure("UserGroup", Item.User);
			NewUsers = GroupsUsers.FindRows(Filter);
			
			HasChanges = False;
			
			If OldUsers.Count() <> NewUsers.Count() Then
				OldUsers.Clear();
				For Each Row In NewUsers Do
					NewItem = OldUsers.Add();
					NewItem.Ref       = Row.User;
					NewItem.User = Row.User;
				EndDo;
				HasChanges = True;
			Else
				Index = 0;
				For Each Row In OldUsers Do
					
					If Row.Ref       <> NewUsers[Index].User
					 Or Row.User <> NewUsers[Index].User Then
						
						Row.Ref       = NewUsers[Index].User;
						Row.User = NewUsers[Index].User;
						HasChanges = True;
					EndIf;
					Index = Index + 1;
				EndDo;
			EndIf;
			
			If HasChanges Then
				ModifiedRows.Add(Item.GetID());
			EndIf;
		EndIf;
	EndDo;
	
	Users.FillUserPictureNumbers(
		GroupUsers, "Ref", "PictureNumber", RowID, True);
	
	// Setting tree presentation
	HasTree = False;
	For Each Item In GroupUsers.GetItems() Do
		If Item.GetItems().Count() > 0 Then
			HasTree = True;
			Break;
		EndIf;
	EndDo;
	Items.Users.Representation = ?(HasTree, TableRepresentation.Tree, TableRepresentation.List);
	
EndProcedure

&AtServer
Procedure RestoreObjectWithoutGroupMembers(CurrentObject)
	
	SetPrivilegedMode(True);
	
	Query = New Query(
	"SELECT
	|	AccessGroups.DeletionMark,
	|	AccessGroups.Predefined,
	|	AccessGroups.Parent,
	|	AccessGroups.IsFolder,
	|	AccessGroups.Description,
	|	AccessGroups.Profile,
	|	AccessGroups.Responsible,
	|	AccessGroups.UserType,
	|	AccessGroups.User,
	|	AccessGroups.Description
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	AccessGroups.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessGroupsAccessKinds.AccessKind,
	|	AccessGroupsAccessKinds.AllAllowed
	|FROM
	|	Catalog.AccessGroups.AccessKinds AS AccessGroupsAccessKinds
	|WHERE
	|	AccessGroupsAccessKinds.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessGroupsAccessValues.AccessKind,
	|	AccessGroupsAccessValues.AccessValue
	|FROM
	|	Catalog.AccessGroups.AccessValues AS AccessGroupsAccessValues
	|WHERE
	|	AccessGroupsAccessValues.Ref = &Ref");
	
	Query.SetParameter("Ref", CurrentObject.Ref);
	QueryResults = Query.ExecuteBatch();
	
	// Restoring attributes
	FillPropertyValues(CurrentObject, QueryResults[0].Unload()[0]);
	
	// Restoring the AccessKinds tabular section
	CurrentObject.AccessKinds.Load(QueryResults[1].Unload());
	
	// Restoring the AccessValues tabular section
	CurrentObject.AccessValues.Load(QueryResults[2].Unload());
	
EndProcedure

&AtServer
Function SpecifyMessage(String, Value)
	
	Return StrReplace(String, "%2", Value);
	
EndFunction

#EndRegion