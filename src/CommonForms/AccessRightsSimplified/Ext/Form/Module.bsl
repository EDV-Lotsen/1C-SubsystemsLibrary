
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("Autotest") Then // Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
		Return;
	EndIf;
	
	If Not ValueIsFilled(Parameters.User) Then
		Cancel = True;
		Return;
	EndIf;
	
	If Users.InfobaseUserWithFullAccess() Then
		// Viewing and editing profile content and access restrictions
		FilterProfilesOnlyForCurrentUser = False;
		
	ElsIf Parameters.User = Users.AuthorizedUser() Then
		// Viewing your profiles and the access rights report
		FilterProfilesOnlyForCurrentUser = True;
		// Hiding extra information
		Items.Profiles.ReadOnly = True;
		Items.ProfilesCheck.Visibility = False;
		Items.Access.Visibility = False;
		Items.FormWrite.Visibility = False;
	Else
		Items.FormWrite.Visibility = False;
		Items.FormAccessRightsReport.Visibility = False;
		Items.RightsAndRestrictions.Visibility = False;
		Items.InsufficientViewRight.Visibility = True;
		Return;
	EndIf;
	
	If TypeOf(Parameters.User) = Type("CatalogRef.ExternalUsers") Then
		Items.Profiles.Title = NStr("en = 'External user profiles'");
	Else
		Items.Profiles.Title = NStr("en = 'User profiles'");
	EndIf;
	
	ImportData(FilterProfilesOnlyForCurrentUser);
	
	// Preparing auxiliary data
	AccessManagementInternal.OnCreateAtServerAllowedValueEditingForm(ThisObject, , "");
	
	For Each ProfileProperties In Profiles Do
		CurrentAccessGroup = ProfileProperties.Profile;
		AccessManagementInternalClientServer.FillPropertiesOfAccessKindsInForm(ThisObject);
	EndDo;
	CurrentAccessGroup = "";
	
	ProfileAdministrator = Catalogs.AccessGroupProfiles.Administrator;
	
	// Determining if the access restrictions must be set up
	If Not AccessManagement.UseRecordLevelSecurity() Then
		Items.Access.Visibility = False;
	EndIf;
	
	If CommonUseCached.DataSeparationEnabled() Then
		ActionsWithSaaSUser = Undefined;
		AccessManagementInternal.OnReceiveActionsWithSaaSUser(
			ActionsWithSaaSUser, Parameters.User);
		AdministrativeAccessChangeProhibition = Not ActionsWithSaaSUser.ChangeAdmininstrativeAccess;
	EndIf;
	
	StandardSubsystemsServer.SetGroupTitleRepresentation(ThisObject, "Access");
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	CommonUseClient.ShowFormClosingConfirmation(
		New NotifyDescription("BeforeCloseContinuation", ThisObject), Cancel);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, AttributesToCheck)
	
	// Checking for blank and duplicate access values
	Errors = Undefined;
	
	For Each ProfileProperties In Profiles Do
		
		CurrentAccessGroup = ProfileProperties.Profile;
		AccessManagementInternalClientServer.ProcessingCheckOfFillingEditingFormsOfAllowedValuesAtServer(
			ThisObject, Cancel, New Array, Errors);
		
		If Cancel Then
			Break;
		EndIf;
		
	EndDo;
	
	If Cancel Then
		CurrentAccessKindString = Items.AccessKinds.CurrentRow;
		CurrentAccessValueStringOnError = Items.AccessValues.CurrentRow;
		
		Items.Profiles.CurrentRow = ProfileProperties.GetID();
		WhenChangingCurrentProfile(ThisObject);
		
		Items.AccessKinds.CurrentRow = CurrentAccessKindString;
		AccessManagementInternalClientServer.OnChangeCurrentAccessKind(ThisObject);
		
		CommonUseClientServer.ShowErrorsToUser(Errors, Cancel);
	Else
		CurrentAccessGroup = CurrentProfile;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetCurrentAccessValueRowOnError()
	
	If CurrentAccessValueStringOnError <> Undefined Then
		Items.AccessValues.CurrentRow = CurrentAccessValueStringOnError;
		CurrentAccessValueStringOnError = Undefined;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableElementsEventHandlersProfiles

&AtClient
Procedure ProfilesOnActivateRow(Item)
	
	WhenChangingCurrentProfile(ThisObject);
	
EndProcedure

&AtClient
Procedure ProfilesCheckOnChange(Item)
	
	Cancel = False;
	CurrentData = Items.Profiles.CurrentData;
	
	If CurrentData <> Undefined
	   And Not CurrentData.Check Then
		// Checking for blank and duplicate access values 
		// before disabling the profile and disabling access to its settings
		ClearMessages();
		Errors = Undefined;
		AccessManagementInternalClientServer.ProcessingCheckOfFillingEditingFormsOfAllowedValuesAtServer(
			ThisObject, Cancel, New Array, Errors);
		CurrentAccessValueStringOnError = Items.AccessValues.CurrentRow;
		CommonUseClientServer.ShowErrorsToUser(Errors, Cancel);
		AttachIdleHandler("SetCurrentAccessValueRowOnError", True, 0.1);
	EndIf;
	
	If Cancel Then
		CurrentData.Check = True;
	Else
		WhenChangingCurrentProfile(ThisObject);
	EndIf;
	
	If CurrentData <> Undefined
		And CurrentData.Profile = PredefinedValue("Catalog.AccessGroupProfiles.Administrator") Then
		
		SynchronizationWithServiceRequired = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region AccessKindFormTableItemEventHandlers

&AtClient
Procedure AccessKindsChoice(Item, SelectedRow, Field, StandardProcessing)
	
	If EditCurrentRestrictions Then
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
Procedure Write(Command)
	
	WriteChanges();
	
EndProcedure

&AtClient
Procedure AccessRightReport(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("User", Parameters.User);
	
	OpenForm("Report.AccessRights.Form", FormParameters);
	
EndProcedure

&AtClient
Procedure ShowUnusedAccessKinds(Command)
	
	ShowNotUsedAccessKindsAtServer();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ProfilesCheck.Name);

	FilterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup1.GroupType = DataCompositionFilterItemsGroupType.AndGroup;

	ItemFilter = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("AdministrativeAccessChangeProhibition");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	ItemFilter = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Profiles.Profile");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Catalogs.AccessGroupProfiles.Administrator;

	Item.Appearance.SetParameterValue("Enabled", False);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ProfilesCheck.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ProfilesProfilePresentation.Name);

	FilterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup1.GroupType = DataCompositionFilterItemsGroupType.AndGroup;

	ItemFilter = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("AdministrativeAccessChangeProhibition");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	ItemFilter = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Profiles.Profile");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Catalogs.AccessGroupProfiles.Administrator;

	Item.Appearance.SetParameterValue("BgColor", StyleColors.InaccessibleDataColor);

EndProcedure

// BeforeClose event handler continuation
&AtClient
Procedure BeforeCloseContinuation(Answer, NotDefined) Export
	
	If Answer = DialogReturnCode.Yes Then
		WriteChanges(New NotifyDescription("BeforeCloseCompletion", ThisObject));
	Else
		Modified = False;
		Close();
	EndIf;
	
EndProcedure

// BeforeClose event handler continuation
&AtClient
Procedure BeforeCloseCompletion(Cancel, NotDefined) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	Close();
	
EndProcedure

&AtClient
Procedure WriteChanges(ContinuationHandler = Undefined)
	
	If StandardSubsystemsClientCached.ClientParameters().DataSeparationEnabled
	   And SynchronizationWithServiceRequired Then
		
		StandardSubsystemsClient.PasswordForAuthenticationInServiceOnRequest(
			New NotifyDescription("SaveChangesEnd", ThisObject, ContinuationHandler),
			ThisObject,
			ServiceUserPassword);
	Else
		SaveChangesEnd("", ContinuationHandler);
	EndIf;
	
EndProcedure

&AtClient
Procedure SaveChangesEnd(SaaSUserNewPassword, ContinuationHandler) Export
	
	If SaaSUserNewPassword = Undefined Then
		Return;
	EndIf;
	
	ServiceUserPassword = SaaSUserNewPassword;
	
	ClearMessages();
	
	Cancel = False;
	WriteChangesAtServer(Cancel);
	
	AttachIdleHandler("SetCurrentAccessValueRowOnError", True, 0.1);
	
	If Cancel Or ContinuationHandler = Undefined Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(ContinuationHandler);
	
EndProcedure

&AtServer
Procedure ShowNotUsedAccessKindsAtServer()
	
	AccessManagementInternal.RefreshNotUsedAccessKindRepresentation(ThisObject);
	
EndProcedure

&AtServer
Procedure ImportData(FilterProfilesOnlyForCurrentUser)
	
	Request = New Request;
	Request.SetParameter("User", Parameters.User);
	Request.SetParameter("FilterProfilesOnlyForCurrentUser",
	                           FilterProfilesOnlyForCurrentUser);
	Request.Text =
	"SELECT DISTINCT
	|	Profiles.Ref,
	|	ISNULL(AccessGroups.Ref, UNDEFINED) AS PersonalAccessGroup,
	|	CASE
	|		WHEN AccessGroupsUsers.Ref IS NULL 
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS Check
	|INTO Profiles
	|FROM
	|	Catalog.AccessGroupProfiles AS Profiles
	|		LEFT JOIN Catalog.AccessGroups AS AccessGroups
	|		ON Profiles.Ref = AccessGroups.Profile
	|			AND (AccessGroups.User = &User
	|				OR Profiles.Ref IN (VALUE(Catalog.AccessGroupProfiles.Administrator)))
	|		LEFT JOIN Catalog.AccessGroups.Users AS AccessGroupsUsers
	|		ON (AccessGroups.Ref = AccessGroupsUsers.Ref)
	|			AND (AccessGroupsUsers.User = &User)
	|WHERE
	|	Not Profiles.DeletionMark
	|	AND Not(&FilterProfilesOnlyForCurrentUser = TRUE
	|				AND AccessGroupsUsers.Ref IS NULL )
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Profiles.Ref AS Profile,
	|	Profiles.Ref.Description AS ProfilePresentation,
	|	Profiles.Check,
	|	Profiles.PersonalAccessGroup AS AccessGroup
	|FROM
	|	Profiles AS Profiles
	|
	|ORDER BY
	|	ProfilePresentation
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Profiles.Ref AS AccessGroup,
	|	ProfilesAccessKinds.AccessKind,
	|	ISNULL(AccessGroupsAccessKinds.AllAllowed, ProfilesAccessKinds.AllAllowed) AS AllAllowed,
	|	"""" AS AccessKindPresentation,
	|	"""" AS AllAllowedPresentation
	|FROM
	|	Profiles AS Profiles
	|		INNER JOIN Catalog.AccessGroupProfiles.AccessKinds AS ProfilesAccessKinds
	|		ON Profiles.Ref = ProfilesAccessKinds.Ref
	|		LEFT JOIN Catalog.AccessGroups.AccessKinds AS AccessGroupsAccessKinds
	|		ON Profiles.PersonalAccessGroup = AccessGroupsAccessKinds.Ref
	|			AND (ProfilesAccessKinds.AccessKind = AccessGroupsAccessKinds.AccessKind)
	|WHERE
	|	Not ProfilesAccessKinds.Preset
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Profiles.Ref AS AccessGroup,
	|	ProfilesAccessKinds.AccessKind,
	|	0 AS RowNumberByKind,
	|	AccessGroupsAccessValues.AccessValue
	|FROM
	|	Profiles AS Profiles
	|		INNER JOIN Catalog.AccessGroupProfiles.AccessKinds AS ProfilesAccessKinds
	|		ON Profiles.Ref = ProfilesAccessKinds.Ref
	|		INNER JOIN Catalog.AccessGroups.AccessValues AS AccessGroupsAccessValues
	|		ON Profiles.PersonalAccessGroup = AccessGroupsAccessValues.Ref
	|			AND (ProfilesAccessKinds.AccessKind = AccessGroupsAccessValues.AccessKind)
	|WHERE
	|	Not ProfilesAccessKinds.Preset";
	
	SetPrivilegedMode(True);
	QueryResults = Request.ExecuteBatch();
	SetPrivilegedMode(False);
	
	ValueToFormAttribute(QueryResults[1].Unload(), "Profiles");
	ValueToFormAttribute(QueryResults[2].Unload(), "AccessKinds");
	ValueToFormAttribute(QueryResults[3].Unload(), "AccessValues");
	
EndProcedure

&AtServer
Procedure WriteChangesAtServer(Cancel)
	
	If Not CheckFilling() Then
		Cancel = True;
		Return;
	EndIf;
	
	Users.FindAmbiguousInfobaseUsers();
	
	// Getting change list
	Request = New Request;
	
	Request.SetParameter("User", Parameters.User);
	
	Request.SetParameter(
		"Profiles", Profiles.Unload(, "Profile, Mark"));
	
	Request.SetParameter(
		"AccessKinds", AccessKinds.Unload(, "AccessGroup, AccessKind, AllAllowed"));
	
	Request.SetParameter(
		"AccessValues", AccessValues.Unload(, "AccessGroup, AccessKind, AccessValue"));
	
	Request.Text =
	"SELECT
	|	Profiles.Profile AS Ref,
	|	Profiles.Check
	|INTO Profiles
	|FROM
	|	&Profiles AS Profiles
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessKinds.AccessGroup AS Profile,
	|	AccessKinds.AccessKind,
	|	AccessKinds.AllAllowed
	|INTO AccessKinds
	|FROM
	|	&AccessKinds AS AccessKinds
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessValues.AccessGroup AS Profile,
	|	AccessValues.AccessKind,
	|	AccessValues.AccessValue
	|INTO AccessValues
	|FROM
	|	&AccessValues AS AccessValues
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	Profiles.Ref,
	|	ISNULL(AccessGroups.Ref, UNDEFINED) AS PersonalAccessGroup,
	|	CASE
	|		WHEN AccessGroupsUsers.Ref IS NULL 
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS Check
	|INTO CurrentProfiles
	|FROM
	|	Catalog.AccessGroupProfiles AS Profiles
	|		LEFT JOIN Catalog.AccessGroups AS AccessGroups
	|		ON Profiles.Ref = AccessGroups.Profile
	|			AND (AccessGroups.User = &User
	|				OR Profiles.Ref IN (VALUE(Catalog.AccessGroupProfiles.Administrator)))
	|		LEFT JOIN Catalog.AccessGroups.Users AS AccessGroupsUsers
	|		ON (AccessGroups.Ref = AccessGroupsUsers.Ref)
	|			AND (AccessGroupsUsers.User = &User)
	|WHERE
	|	Not Profiles.DeletionMark
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Profiles.Ref AS Profile,
	|	AccessGroupsAccessKinds.AccessKind,
	|	AccessGroupsAccessKinds.AllAllowed
	|INTO CurrentAccessKinds
	|FROM
	|	CurrentProfiles AS Profiles
	|		INNER JOIN Catalog.AccessGroups.AccessKinds AS AccessGroupsAccessKinds
	|		ON Profiles.PersonalAccessGroup = AccessGroupsAccessKinds.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Profiles.Ref AS Profile,
	|	AccessGroupsAccessValues.AccessKind,
	|	AccessGroupsAccessValues.AccessValue
	|INTO CurrentAccessValues
	|FROM
	|	CurrentProfiles AS Profiles
	|		INNER JOIN Catalog.AccessGroups.AccessValues AS AccessGroupsAccessValues
	|		ON Profiles.PersonalAccessGroup = AccessGroupsAccessValues.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ChangedGroupsProfiles.Profile
	|INTO ChangedGroupsProfiles
	|FROM
	|	(SELECT
	|		Profiles.Ref AS Profile
	|	FROM
	|		Profiles AS Profiles
	|			INNER JOIN CurrentProfiles AS CurrentProfiles
	|			ON Profiles.Ref = CurrentProfiles.Ref
	|	WHERE
	|		Profiles.Check <> CurrentProfiles.Check
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessKinds.Profile
	|	FROM
	|		AccessKinds AS AccessKinds
	|			LEFT JOIN CurrentAccessKinds AS CurrentAccessKinds
	|			ON AccessKinds.Profile = CurrentAccessKinds.Profile
	|				AND AccessKinds.AccessKind = CurrentAccessKinds.AccessKind
	|				AND AccessKinds.AllAllowed = CurrentAccessKinds.AllAllowed
	|	WHERE
	|		CurrentAccessKinds.AccessKind IS NULL 
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CurrentAccessKinds.Profile
	|	FROM
	|		CurrentAccessKinds AS CurrentAccessKinds
	|			LEFT JOIN AccessKinds AS AccessKinds
	|			ON (AccessKinds.Profile = CurrentAccessKinds.Profile)
	|				AND (AccessKinds.AccessKind = CurrentAccessKinds.AccessKind)
	|				AND (AccessKinds.AllAllowed = CurrentAccessKinds.AllAllowed)
	|	WHERE
	|		AccessKinds.AccessKind IS NULL 
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValues.Profile
	|	FROM
	|		AccessValues AS AccessValues
	|			LEFT JOIN CurrentAccessValues AS CurrentAccessValues
	|			ON AccessValues.Profile = CurrentAccessValues.Profile
	|				AND AccessValues.AccessKind = CurrentAccessValues.AccessKind
	|				AND AccessValues.AccessValue = CurrentAccessValues.AccessValue
	|	WHERE
	|		CurrentAccessValues.AccessKind IS NULL 
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CurrentAccessValues.Profile
	|	FROM
	|		CurrentAccessValues AS CurrentAccessValues
	|			LEFT JOIN AccessValues AS AccessValues
	|			ON (AccessValues.Profile = CurrentAccessValues.Profile)
	|				AND (AccessValues.AccessKind = CurrentAccessValues.AccessKind)
	|				AND (AccessValues.AccessValue = CurrentAccessValues.AccessValue)
	|	WHERE
	|		AccessValues.AccessKind IS NULL ) AS ChangedGroupsProfiles
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Profiles.Ref AS Profile,
	|	CatalogProfiles.Description AS ProfileDescription,
	|	Profiles.Check,
	|	CurrentProfiles.PersonalAccessGroup
	|FROM
	|	ChangedGroupsProfiles AS ChangedGroupsProfiles
	|		INNER JOIN Profiles AS Profiles
	|		ON ChangedGroupsProfiles.Profile = Profiles.Ref
	|		INNER JOIN CurrentProfiles AS CurrentProfiles
	|		ON ChangedGroupsProfiles.Profile = CurrentProfiles.Ref
	|		INNER JOIN Catalog.AccessGroupProfiles AS CatalogProfiles
	|		ON (CatalogProfiles.Ref = ChangedGroupsProfiles.Profile)";
	
	BeginTransaction();
	Try
		Selection = Request.Execute().Select();
		While Selection.Next() Do
			
			If ValueIsFilled(Selection.PersonalAccessGroup) Then
				LockDataForEdit(Selection.PersonalAccessGroup);
				AccessGroupObject = Selection.PersonalAccessGroup.GetObject();
			Else
				// Creating a personal access group
				AccessGroupObject = Catalogs.AccessGroups.CreateItem();
				AccessGroupObject.Parent     = Catalogs.AccessGroups.PersonalAccessGroupParent();
				AccessGroupObject.Description = Selection.ProfileDescription;
				AccessGroupObject.User = Parameters.User;
				AccessGroupObject.Profile      = Selection.Profile;
			EndIf;
			
			If Selection.Profile = Catalogs.AccessGroupProfiles.Administrator Then
				
				If SynchronizationWithServiceRequired Then
					AccessGroupObject.AdditionalProperties.Insert("ServiceUserPassword", ServiceUserPassword);
				EndIf;
				
				If Selection.Check Then
					If AccessGroupObject.Users.Find(
							Parameters.User, "User") = Undefined Then
						
						AccessGroupObject.Users.Add().User = Parameters.User;
					EndIf;
				Else
					UserDetails =  AccessGroupObject.Users.Find(
						Parameters.User, "User");
					
					If UserDetails <> Undefined Then
						AccessGroupObject.Users.Delete(UserDetails);
						
						If Not CommonUseCached.DataSeparationEnabled() Then
							// Checking the empty list of infobase users in the Administrators access group
							ErrorDescription = "";
							AccessManagementInternal.CheckAdministratorsAccessGroupForInfobaseUser(
								AccessGroupObject.Users, ErrorDescription);
							
							If ValueIsFilled(ErrorDescription) Then
								Raise
									NStr("en = 'Administrator profile must be assigned to
									           |at least one user with access to the application.'");
							EndIf;
						EndIf;
					EndIf;
				EndIf;
			Else
				AccessGroupObject.Users.Clear();
				If Selection.Check Then
					AccessGroupObject.Users.Add().User = Parameters.User;
				EndIf;
				
				Filter = New Structure("AccessGroup", Selection.Profile);
				
				AccessGroupObject.AccessKinds.Load(
					AccessKinds.Unload(Filter, "AccessKind, AllAllowed"));
				
				AccessGroupObject.AccessValues.Load(
					AccessValues.Unload(Filter, "AccessKind, AccessValue"));
			EndIf;
			
			Try
				AccessGroupObject.Write();
			Except
				ServiceUserPassword = Undefined;
				Raise;
			EndTry;
			
			If ValueIsFilled(Selection.PersonalAccessGroup) Then
				UnlockDataForEdit(Selection.PersonalAccessGroup);
			EndIf;
		EndDo;
		CommitTransaction();
		Modified = False;
		SynchronizationWithServiceRequired = False;
	Except
		RollbackTransaction();
		CommonUseClientServer.MessageToUser(
			BriefErrorDescription(ErrorInfo()), , , , Cancel);
	EndTry;
	
EndProcedure

&AtClientAtServerNoContext
Procedure WhenChangingCurrentProfile(Val Form)
	
	Items    = Form.Items;
	Profiles     = Form.Profiles;
	AccessKinds = Form.AccessKinds;
	
	#If Client Then
		CurrentData = Items.Profiles.CurrentData;
	#Else
		CurrentData = Profiles.FindByID(?(Items.Profiles.CurrentRow = Undefined, -1, Items.Profiles.CurrentRow));
	#EndIf
	
	Form.CurrentProfile = Undefined;
	EditCurrentRestrictions = False;
	
	If CurrentData <> Undefined Then
		Form.CurrentProfile = CurrentData.Profile;
		EditCurrentRestrictions = CurrentData.Check
		                                   And Form.CurrentProfile <> Form.ProfileAdministrator
		                                   And Not Form.ReadOnly;
	EndIf;
	
	Items.Access.Enabled                       =    CurrentData <> Undefined And CurrentData.Check;
	Items.AccessKinds.ReadOnly                 = Not EditCurrentRestrictions;
	Items.AccessValuesByAccessKind.Enabled     =    CurrentData <> Undefined And CurrentData.Check;
	Items.AccessValues.ReadOnly                = Not EditCurrentRestrictions;
	Items.AccessKindsContextMenuChange.Enabled =    EditCurrentRestrictions;
	
	If Form.CurrentProfile = Undefined Then
		Form.CurrentAccessGroup = "";
	Else
		Form.CurrentAccessGroup = Form.CurrentProfile;
	EndIf;
	
	If Items.AccessKinds.RowFilter = Undefined
	 Or Items.AccessKinds.RowFilter.AccessGroup <> Form.CurrentAccessGroup Then
		
		If Items.AccessKinds.RowFilter = Undefined Then
			RowFilter = New Structure;
		Else
			RowFilter = New Structure(Items.AccessKinds.RowFilter);
		EndIf;
		RowFilter.Insert("AccessGroup", Form.CurrentAccessGroup);
		Items.AccessKinds.RowFilter = New FixedStructure(RowFilter);
		CurrentAccessKinds = AccessKinds.FindRows(New Structure("AccessGroup", Form.CurrentAccessGroup));
		If CurrentAccessKinds.Count() = 0 Then
			Items.AccessValues.RowFilter = New FixedStructure("AccessGroup, AccessKind", Form.CurrentAccessGroup, "");
			AccessManagementInternalClientServer.OnChangeCurrentAccessKind(Form);
		Else
			Items.AccessKinds.CurrentRow = CurrentAccessKinds[0].GetID();
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion
