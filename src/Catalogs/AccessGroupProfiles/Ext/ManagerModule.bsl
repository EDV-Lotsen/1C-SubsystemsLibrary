#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Interface

// Returns a list of attributes that must not be edited
// using group processing of object changes
//
Function AttributesToSkipOnGroupProcessing() Export
	
	AttributesToSkip = New Array;
	AttributesToSkip.Add("SuppliedDataID");
	AttributesToSkip.Add("SuppliedProfileChanged");
	AttributesToSkip.Add("AccessKinds.*");
	AttributesToSkip.Add("AccessValues.*");
	
	Return AttributesToSkip;
	
EndFunction

#EndRegion

#Region InternalInterface

// Updates description of the supplied
// profiles in access restriction parameters when a configuration is modified.
// 
// Parameters:
//  HasChanges - Boolean (return value) - True if
//                  data is changed; not set otherwise.
//
Procedure UpdateSuppliedProfilesDescription(HasChanges = Undefined, CheckOnly = False) Export
	
	SetPrivilegedMode(True);
	
	If CheckOnly Or ExclusiveMode() Then
		DisableExclusiveMode = False;
	Else
		DisableExclusiveMode = True;
		SetExclusiveMode(True);
	EndIf;
	
	SuppliedProfiles = SuppliedProfiles();
	
	DataLock = New DataLock;
	LockItem = DataLock.Add("Constant.AccessRestrictionParameters");
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		DataLock.Lock();
		
		Parameters = StandardSubsystemsServer.ApplicationParameters(
			"AccessRestrictionParameters");
		
		Saved = Undefined;
		
		If Parameters.Property("SuppliedAccessGroupProfiles") Then
			Saved = Parameters.SuppliedAccessGroupProfiles;
			
			If Not CommonUse.IsEqualData(SuppliedProfiles, Saved) Then
				Saved = Undefined;
			EndIf;
		EndIf;
		
		If Saved = Undefined Then
			HasChanges = True;
			If CheckOnly Then
				CommitTransaction();
				Return;
			EndIf;
			StandardSubsystemsServer.SetApplicationParameter(
				"AccessRestrictionParameters",
				"SuppliedAccessGroupProfiles",
				SuppliedProfiles);
		EndIf;
		
		StandardSubsystemsServer.ConfirmApplicationParametersUpdate(
			"AccessRestrictionParameters", "SuppliedAccessGroupProfiles");
		
		If Not CheckOnly Then
			StandardSubsystemsServer.AddApplicationParameterChanges(
				"AccessRestrictionParameters",
				"SuppliedAccessGroupProfiles",
				?(Saved = Undefined,
				  New FixedStructure("HasChanges", True),
				  New FixedStructure()) );
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		If DisableExclusiveMode Then
			SetExclusiveMode(False);
		EndIf;
		Raise;
	EndTry;
	
	If DisableExclusiveMode Then
		SetExclusiveMode(False);
	EndIf;
	
EndProcedure

// Updates content of the predefined
// profiles in the access restriction options when a configuration is modified.
// 
// Parameters:
//  HasChanges - Boolean (return value) - True if
//                  data is modified; not set otherwise.
//
Procedure UpdatePredefinedProfileContent(HasChanges = Undefined, CheckOnly = False) Export
	
	SetPrivilegedMode(True);
	
	If CheckOnly Or ExclusiveMode() Then
		DisableExclusiveMode = False;
	Else
		DisableExclusiveMode = True;
		SetExclusiveMode(True);
	EndIf;
	
	PredefinedProfiles = StandardSubsystemsServer.PredefinedDataNames(
		"Catalog.AccessGroupProfiles");
	
	DataLock = New DataLock;
	LockItem = DataLock.Add("Constant.AccessRestrictionParameters");
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		DataLock.Lock();
		
		Parameters = StandardSubsystemsServer.ApplicationParameters(
			"AccessRestrictionParameters");
		
		HasDeleted = False;
		Saved = Undefined;
		
		If Parameters.Property("AccessGroupPredefinedProfiles") Then
			Saved = Parameters.AccessGroupPredefinedProfiles;
			
			If Not PredefinedProfilesMatch(PredefinedProfiles, Saved, HasDeleted) Then
				Saved = Undefined;
			EndIf;
		EndIf;
		
		If Saved = Undefined Then
			HasChanges = True;
			If CheckOnly Then
				CommitTransaction();
				Return;
			EndIf;
			StandardSubsystemsServer.SetApplicationParameter(
				"AccessRestrictionParameters",
				"AccessGroupPredefinedProfiles",
				PredefinedProfiles);
		EndIf;
		
		StandardSubsystemsServer.ConfirmApplicationParametersUpdate(
			"AccessRestrictionParameters",
			"AccessGroupPredefinedProfiles");
		
		If Not CheckOnly Then
			StandardSubsystemsServer.AddApplicationParameterChanges(
				"AccessRestrictionParameters",
				"AccessGroupPredefinedProfiles",
				?(HasDeleted,
				  New FixedStructure("HasDeleted", True),
				  New FixedStructure()) );
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		If DisableExclusiveMode Then
			SetExclusiveMode(False);
		EndIf;
		Raise;
	EndTry;
	
	If DisableExclusiveMode Then
		SetExclusiveMode(False);
	EndIf;
	
EndProcedure

// Updates the supplied catalog profiles according
// to the result of changing the supplied profiles saved in access restriction settings.
//
Procedure RefreshSuppliedProfilesOnConfigurationChanges() Export
	
	SetPrivilegedMode(True);
	
	Parameters = AccessManagementInternalCached.Parameters();
	
	LastChanges = StandardSubsystemsServer.ApplicationParameterChanges(
		Parameters, "SuppliedAccessGroupProfiles");
		
	If LastChanges = Undefined Then
		UpdateRequired = True;
	Else
		UpdateRequired = False;
		For Each ChangePart In LastChanges Do
			
			If TypeOf(ChangePart) = Type("FixedStructure")
			   And ChangePart.Property("HasChanges")
			   And TypeOf(ChangePart.HasChanges) = Type("Boolean") Then
				
				If ChangePart.HasChanges Then
					UpdateRequired = True;
					Break;
				EndIf;
			Else
				UpdateRequired = True;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	If UpdateRequired Then
		UpdateSuppliedProfiles();
	EndIf;
	
EndProcedure

// Updates supplied profiles and when necessary updates access groups of these profiles.
// If any access group supplied profiles are not found, the are created.
//
// Update details are configured in
// the FillAccessGroupsSuppliedProfiles procedure of AccessManagementOverridable common module (see comments to the procedure).
//
// Parameters:
//  HasChanges - Boolean (return value) - True if
//                  data is modified; not set otherwise.
//
Procedure UpdateSuppliedProfiles(HasChanges = Undefined) Export
	
	SuppliedProfiles = AccessManagementInternalCached.Parameters(
		).SuppliedAccessGroupProfiles;
	
	ProfileDescriptions    = SuppliedProfiles.ProfileDescriptions;
	UpdateParameters = SuppliedProfiles.UpdateParameters;
	
	UpdatedProfiles       = New Array;
	UpdatedAccessGroup = New Array;
	
	Query = New Query(
	"SELECT
	|	AccessGroupProfiles.SuppliedProfileChanged,
	|	AccessGroupProfiles.SuppliedDataID,
	|	AccessGroupProfiles.Ref AS Ref
	|FROM
	|	Catalog.AccessGroupProfiles AS AccessGroupProfiles");
	CurrentProfiles = Query.Execute().Unload();
	
	For Each ProfileDescription In ProfileDescriptions Do
		ProfileProperties = ProfileDescription.Value;
		
		CurrentProfileString = CurrentProfiles.Find(
			New UUID(ProfileProperties.ID),
			"SuppliedDataID");
		
		ProfileUpdated = False;
		
		If CurrentProfileString = Undefined Then
			// Creating a new supplied profile
			If RefreshAccessGroupsProfile(ProfileProperties) Then
				HasChanges = True;
			EndIf;
			Profile = SuppliedProfileById(ProfileProperties.ID);
			
		Else
			Profile = CurrentProfileString.Ref;
			If Not CurrentProfileString.SuppliedProfileChanged
			 Or UpdateParameters.UpdateModifiedProfiles Then
				// Updating the supplied profile
				ProfileUpdated = RefreshAccessGroupsProfile(ProfileProperties, True);
			EndIf;
		EndIf;
		
		If UpdateParameters.UpdateAccessGroups Then
			ProfileAccessGroupsUpdated = Catalogs.AccessGroups.UpdateProfileAccessGroups(
				Profile, UpdateParameters.UpdateAccessGroupsWithObsoleteSettings);
			
			ProfileUpdated = ProfileUpdated Or ProfileAccessGroupsUpdated;
		EndIf;
		
		If ProfileUpdated Then
			HasChanges = True;
			UpdatedProfiles.Add(Profile);
		EndIf;
	EndDo;
	
	// Updating user roles
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	UserGroupContents.User
	|FROM
	|	InformationRegister.UserGroupContents AS UserGroupContents
	|		INNER JOIN Catalog.AccessGroups.Users AS AccessGroupsUsers
	|		ON UserGroupContents.UserGroup = AccessGroupsUsers.User
	|			AND (AccessGroupsUsers.Ref.Profile IN (&Profiles))";
	Query.SetParameter("Profiles", UpdatedProfiles);
	UsersForUpdate = Query.Execute().Unload().UnloadColumn("User");
	
	AccessManagement.UpdateUserRoles(UsersForUpdate);
	
EndProcedure

// Fills a user's to-do list.
//
// Parameters:
//  ToDoList - ValueTable - value table with the following columns:
//    * ID - String - internal user task ID used by the To-do list algorithm.
//    * HasUserTasks   - Boolean - if True, the user task is displayed in the user's to-do list.
//    * Important      - Boolean - If True, the user task is outlined in red.
//    * Presentation   - String - user task presentation displayed to the user.
//    * Count          - Number  - quantitative indicator of the user task, displayed in the title of the user task.
//    * Form           - String - full path to the form that is displayed by
//                               clicking on the task hyperlink in the To-do list panel.
//    * FormParameters - Structure - parameters for opening the indicator form.
//    * Owner          - String, metadata object - string ID of the user task that
//                      is the owner of the current user task, or a subsystem metadata object.
//    * Hint           - String - hint text.
//
Procedure OnFillToDoList(ToDoList) Export
	
	If Not Users.InfobaseUserWithFullAccess(, True) Then
		Return;
	EndIf;
	
	// This procedure is only called when To-do list
	// subsystem is available. Therefore, the subsystem availability check is redundant.
	ToDoListInternalCachedModule = CommonUse.CommonModule("ToDoListInternalCached");
	
	ObjectsBelonging = ToDoListInternalCachedModule.ObjectsBelongingToCommandInterfaceSections();
	Sections = ObjectsBelonging[Metadata.Catalogs.AccessGroupProfiles.FullName()];
	
	If Sections = Undefined Then
		Return;
	EndIf;
	
	For Each Section In Sections Do
		
		IncompatibleAccessGroupProfileQuantity = IncompatibleAccessGroupProfileQuantity();
		
		ProfileID = "IncompatibleWithCurrentVersion" + StrReplace(Section.FullName(), ".", "");
		UserTask = ToDoList.Add();
		UserTask.ID = ProfileID;
		UserTask.HasUserTasks      = IncompatibleAccessGroupProfileQuantity > 0;
		UserTask.Presentation = NStr("en = 'Incompatible with current version'");
		UserTask.Quantity    = IncompatibleAccessGroupProfileQuantity;
		UserTask.Owner      = Section;
		
		UserTask = ToDoList.Add();
		UserTask.ID = "AccessGroupProfiles";
		UserTask.HasUserTasks      = IncompatibleAccessGroupProfileQuantity > 0;
		UserTask.Important        = True;
		UserTask.Presentation = NStr("en = 'Access group profiles'");
		UserTask.Quantity    = IncompatibleAccessGroupProfileQuantity;
		UserTask.Form         = "Catalog.AccessGroupProfiles.Form.ListForm";
		UserTask.FormParameters= New Structure("ProfilesWithRolesMarkedForDeletion", True);
		UserTask.Owner      = ProfileID;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// Returns a unique identifier string of a delivered and predefined Administrator profile.
//
Function AdministratorProfileID() Export
	
	Return "6c4b0307-43a4-4141-9c35-3dd7e9586d41";
	
EndFunction

// Returns a reference to a supplied profile by ID.
//
// Parameters:
//  ID - String - name or unique ID of a supplied profile.
//
Function SuppliedProfileById(ID) Export
	
	SetPrivilegedMode(True);
	
	SuppliedProfiles = AccessManagementInternalCached.Parameters(
		).SuppliedAccessGroupProfiles;
	
	ProfileProperties = SuppliedProfiles.ProfileDescriptions.Get(ID);
	
	Query = New Query;
	Query.SetParameter("SuppliedDataID",
		New UUID(ProfileProperties.ID));
	
	Query.Text =
	"SELECT
	|	AccessGroupProfiles.Ref AS Ref
	|FROM
	|	Catalog.AccessGroupProfiles AS AccessGroupProfiles
	|WHERE
	|	AccessGroupProfiles.SuppliedDataID = &SuppliedDataID";
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Return Selection.Ref;
	EndIf;
	
	Return Undefined;
	
EndFunction

// Returns a unique identifier string of a supplied profile data.
//
Function SuppliedProfileID(Profile) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("Ref", Profile);
	
	Query.SetParameter("EmptyUUID",
		New UUID("00000000-0000-0000-0000-000000000000"));
	
	Query.Text =
	"SELECT
	|	AccessGroupProfiles.SuppliedDataID
	|FROM
	|	Catalog.AccessGroupProfiles AS AccessGroupProfiles
	|WHERE
	|	AccessGroupProfiles.Ref = &Ref
	|	AND AccessGroupProfiles.SuppliedDataID <> &EmptyUUID";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		
		SuppliedProfiles = AccessManagementInternalCached.Parameters(
			).SuppliedAccessGroupProfiles;
		
		ProfileProperties = SuppliedProfiles.ProfileDescriptions.Get(
			String(Selection.SuppliedDataID));
		
		Return String(Selection.SuppliedDataID);
	EndIf;
	
	Return Undefined;
	
EndFunction

// Checks whether the supplied profile is changed compared to
// the AccessManagementOverridable. FillAccessGroupsSuppliedProfiles() procedure description.
//
// Parameters:
//  Profile      - CatalogRef.AccessGroupProfiles
//                     (returns the SuppliedProfileChanged attribute).
//               - CatalogObject.AccessGroupProfiles
//                     (returns the result of object filling
//                     comparison to description in the overridable common module).
//
// Returns:
//  Boolean.
//
Function SuppliedProfileChanged(Profile) Export
	
	If TypeOf(Profile) = Type("CatalogRef.AccessGroupProfiles") Then
		Return CommonUse.ObjectAttributeValue(Profile, "SuppliedProfileChanged");
	EndIf;
	
	ProfileProperties = AccessManagementInternalCached.Parameters(
		).SuppliedAccessGroupProfiles.ProfileDescriptions.Get(
			String(Profile.SuppliedDataID));
	
	If ProfileProperties = Undefined Then
		Return False;
	EndIf;
	
	ProfileRolesDescription = ProfileRolesDescription(ProfileProperties);
	
	If Upper(Profile.Description) <> Upper(ProfileProperties.Description) Then
		Return True;
	EndIf;
	
	If Profile.Roles.Count()            <> ProfileRolesDescription.Count()
	 Or Profile.AccessKinds.Count()     <> ProfileProperties.AccessKinds.Count()
	 Or Profile.AccessValues.Count() <> ProfileProperties.AccessValues.Count() Then
		Return True;
	EndIf;
	
	For Each Role In ProfileRolesDescription Do
		MetadataRoles = Metadata.Roles.Find(Role);
		If MetadataRoles = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'When checking the supplied profile ""%1"",
				           | role ""%2"" is not found in the metadata.'"),
				ProfileProperties.Description,
				Role);
		EndIf;
		IDRoles = CommonUse.MetadataObjectID(MetadataRoles);
		If Profile.Roles.FindRows(New Structure("Role", IDRoles)).Count() = 0 Then
			Return True;
		EndIf;
	EndDo;
	
	For Each AccessKindDescription In ProfileProperties.AccessKinds Do
		AccessKindProperties = AccessManagementInternal.AccessKindProperties(AccessKindDescription.Key);
		Filter = New Structure;
		Filter.Insert("AccessKind",        AccessKindProperties.Ref);
		Filter.Insert("Preset", AccessKindDescription.Value = "Preset");
		Filter.Insert("AllAllowed",      AccessKindDescription.Value = "InitiallyAllAllowed");
		If Profile.AccessKinds.FindRows(Filter).Count() = 0 Then
			Return True;
		EndIf;
	EndDo;
	
	For Each AccessValueDetails In ProfileProperties.AccessValues Do
		Filter = New Structure;
		Query = New Query(StrReplace("Select Value (%1) AS Value", "%1", AccessValueDetails.AccessValue));
		Filter.Insert("AccessValue", Query.Execute().Unload()[0].Value);
		If Profile.AccessValues.FindRows(Filter).Count() = 0 Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

// Checks whether initial filling is done an access group profile in an overridable module.
//  
// Parameters:
//  Profile      - CatalogRef.AccessGroupProfiles.
//  
// Returns:
//  Boolean.
//
Function HasInitialProfileFilling(Val Profile) Export
	
	SuppliedDataID = String(CommonUse.ObjectAttributeValue(
		Profile, "SuppliedDataID"));
	
	ProfileProperties = AccessManagementInternalCached.Parameters(
		).SuppliedAccessGroupProfiles.ProfileDescriptions.Get(SuppliedDataID);
	
	Return ProfileProperties <> Undefined;
	
EndFunction

// Determines whether the supplied profile is prohibited from editing.
// Profiles that are not supplied cannot be prohibited from editing.
//  
// Parameters:
//  Profile      - CatalogObject.AccessGroupProfiles,
//                 FormDataStructure created for an object.
//  
// Returns:
//  Boolean.
//
Function ProfileChangeProhibition(Val Profile) Export
	
	If Profile.SuppliedDataID =
			New UUID(AdministratorProfileID()) Then
		// Changing the Administrator profile is always prohibited.
		Return True;
	EndIf;
	
	SuppliedProfiles = AccessManagementInternalCached.Parameters(
		).SuppliedAccessGroupProfiles;
	
	ProfileProperties = SuppliedProfiles.ProfileDescriptions.Get(
		String(Profile.SuppliedDataID));
	
	Return ProfileProperties <> Undefined
	      And SuppliedProfiles.UpdateParameters.DenyProfileChange;
	
EndFunction

// Returns the supplied profile usage description.
//
// Parameters:
//  Profile - CatalogRef.AccessGroupProfiles.
//
// Returns:
//  String.
//
Function SuppliedProfileDescription(Profile) Export
	
	SuppliedDataID = String(CommonUse.ObjectAttributeValue(
		Profile, "SuppliedDataID"));
	
	ProfileProperties = AccessManagementInternalCached.Parameters(
		).SuppliedAccessGroupProfiles.ProfileDescriptions.Get(SuppliedDataID);
	
	Text = "";
	If ProfileProperties <> Undefined Then
		Text = ProfileProperties.Description;
	EndIf;
	
	Return Text;
	
EndFunction

// Creates a supplied profile matching the applied solution in the
// AccessGroupProfiles directory, and allows to refill 
// a previously created supplied profile by its supplied description.
//  Initial filling search is done by unique profile identifier string.
//
// Parameters:
//  Profile      - CatalogRef.AccessGroupProfiles.
//                 If initial filling description for the
//                 profile is found, the profile content is completely replaced.
//
// UpdateAccessGroups - Boolean - If True, access kinds of access group profile are refreshed.
//
Procedure FillSuppliedProfile(Val Profile, Val UpdateAccessGroups) Export
	
	SuppliedDataID = String(CommonUse.ObjectAttributeValue(
		Profile, "SuppliedDataID"));
	
	ProfileProperties = AccessManagementInternalCached.Parameters(
		).SuppliedAccessGroupProfiles.ProfileDescriptions.Get(SuppliedDataID);
	
	If ProfileProperties <> Undefined Then
		
		RefreshAccessGroupsProfile(ProfileProperties);
		
		If UpdateAccessGroups Then
			Catalogs.AccessGroups.UpdateProfileAccessGroups(Profile, True);
		EndIf;
	EndIf;
	
EndProcedure

// Infobase update handlers.

// Fills the supplied data IDs upon match to the reference ID.
Procedure FillSuppliedDataIDs() Export
	
	SetPrivilegedMode(True);
	
	SuppliedProfiles = AccessManagementInternalCached.Parameters(
		).SuppliedAccessGroupProfiles;
	
	SuppliedProfileReferences = New Array;
	
	For Each ProfileDescription In SuppliedProfiles.ProfileDescriptions Do
		SuppliedProfileReferences.Add(
			Catalogs.AccessGroupProfiles.GetRef(
				New UUID(ProfileDescription.Value.ID)));
	EndDo;
	
	Query = New Query;
	Query.SetParameter("EmptyUUID",
		New UUID("00000000-0000-0000-0000-000000000000"));
	
	Query.SetParameter("SuppliedProfileReferences", SuppliedProfileReferences);
	Query.Text =
	"SELECT
	|	AccessGroupProfiles.Ref
	|FROM
	|	Catalog.AccessGroupProfiles AS AccessGroupProfiles
	|WHERE
	|	AccessGroupProfiles.SuppliedDataID = &EmptyUUID
	|	AND AccessGroupProfiles.Ref IN (&SuppliedProfileReferences)";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		ProfileObject = Selection.Ref.GetObject();
		ProfileObject.SuppliedDataID = Selection.Ref.UUID();
		InfobaseUpdate.WriteData(ProfileObject);
	EndDo;
	
EndProcedure

// Replaces the link to PVC.AccessKinds empty reference of main type of access kind values.
Procedure ConvertAccessKindsIDs() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AccessGroupProfiles.Ref AS Ref
	|FROM
	|	Catalog.AccessGroupProfiles AS AccessGroupProfiles
	|WHERE
	|	Not(Not TRUE IN
	|						(SELECT TOP 1
	|							TRUE
	|						FROM
	|							Catalog.AccessGroupProfiles.AccessKinds AS AccessKinds
	|						WHERE
	|							AccessKinds.Ref = AccessGroupProfiles.Ref
	|							AND VALUETYPE(AccessKinds.AccessKind) = TYPE(ChartOfCharacteristicTypes.DELETE))
	|				AND Not TRUE IN
	|						(SELECT TOP 1
	|							TRUE
	|						FROM
	|							Catalog.AccessGroupProfiles.AccessValues AS AccessValues
	|						WHERE
	|							AccessValues.Ref = AccessGroupProfiles.Ref
	|							AND VALUETYPE(AccessValues.AccessKind) = TYPE(ChartOfCharacteristicTypes.DELETE)))
	|
	|UNION ALL
	|
	|SELECT
	|	AccessGroups.Ref
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	Not(Not TRUE IN
	|						(SELECT TOP 1
	|							TRUE
	|						FROM
	|							Catalog.AccessGroups.AccessKinds AS AccessKinds
	|						WHERE
	|							AccessKinds.Ref = AccessGroups.Ref
	|							AND VALUETYPE(AccessKinds.AccessKind) = TYPE(ChartOfCharacteristicTypes.DELETE))
	|				AND Not TRUE IN
	|						(SELECT TOP 1
	|							TRUE
	|						FROM
	|							Catalog.AccessGroups.AccessValues AS AccessValues
	|						WHERE
	|							AccessValues.Ref = AccessGroups.Ref
	|							AND VALUETYPE(AccessValues.AccessKind) = TYPE(ChartOfCharacteristicTypes.DELETE)))";
	
	Selection = Query.Execute().Select();
	
	If Selection.Count() = 0 Then
		Return;
	EndIf;
	
	AccessKindsProperties = AccessManagementInternalCached.Parameters().AccessKindsProperties;
	
	While Selection.Next() Do
		Object = Selection.Ref.GetObject();
		
		Index = Object.AccessKinds.Count()-1;
		While Index >= 0 Do
			Row = Object.AccessKinds[Index];
			AccessKindName = "";
			AccessKindProperties = AccessKindsProperties.ByNames.Get(AccessKindName);
			If AccessKindProperties = Undefined Then
				Object.AccessKinds.Delete(Index);
			Else
				Row.AccessKind = AccessKindProperties.Ref;
			EndIf;
			Index = Index - 1;
		EndDo;
		
		Index = Object.AccessValues.Count()-1;
		While Index >= 0 Do
			String = Object.AccessValues[Index];
			AccessKindName = "";
			AccessKindProperties = AccessKindsProperties.ByNames.Get(AccessKindName);
			If AccessKindProperties = Undefined Then
				Object.AccessValues.Delete(Index);
			Else
				Row.AccessKind = AccessKindProperties.Ref;
				If Object.AccessKinds.Find(Row.AccessKind, "AccessKind") = Undefined Then
					Object.AccessValues.Delete(Index);
				EndIf;
			EndIf;
			Index = Index - 1;
		EndDo;
		InfobaseUpdate.WriteData(Object);
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions

Function SuppliedProfiles()
	
	UpdateParameters = New Structure;
	// Properties of supplied profile updates
	UpdateParameters.Insert("UpdateModifiedProfiles", True);
	UpdateParameters.Insert("DenyProfileChange", True);
	// Properties of supplied profile access groups updates
	UpdateParameters.Insert("UpdateAccessGroups", True);
	UpdateParameters.Insert("UpdateAccessGroupsWithObsoleteSettings", False);
	
	ProfileDescriptions = New Array;
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.AccessManagement\OnFillSuppliedAccessGroupProfiles");
	For Each Handler In EventHandlers Do
		Handler.Module.OnFillSuppliedAccessGroupProfiles(ProfileDescriptions, UpdateParameters);
	EndDo;
	
	AccessManagementOverridable.OnFillSuppliedAccessGroupProfiles(
		ProfileDescriptions, UpdateParameters);
	
	ErrorTitle =
		NStr("en = 'Invalid values are set in the OnFillSuppliedAccessGroupProfiles procedure
		           |of AccessManagementOverridable common module.
		           |
		           |'");
	
	If UpdateParameters.DenyProfileChange
	   And Not UpdateParameters.UpdateModifiedProfiles Then
		
		Raise ErrorTitle +
			NStr("en = 'When the UpdateModifiedProfiles property of
			           |UpdateParameters parameter is set to False,
			           |the DenyProfileChange property must also be False.'");
	EndIf;
	
	// Description for the Administrator predefined profile filling.
	ProfileDescriptionAdministrator = AccessManagement.NewAccessGroupProfileDescription();
	ProfileDescriptionAdministrator.Name           = "Administrator";
	ProfileDescriptionAdministrator.ID = AdministratorProfileID();
	ProfileDescriptionAdministrator.Description  = NStr("en = 'Administrator'");
	ProfileDescriptionAdministrator.Roles.Add("FullAccess");
	ProfileDescriptionAdministrator.Description =
		NStr("en = 'It is intended for:
		           |- operating parameter setup and information system maintenance,
		           |- access rights setup for other users,
		           |- marked object deletion,
              |- configuration editing (in rare cases).
		           |
		           |It is not recommended to use it for routine work in the information system.
		           |'");
	ProfileDescriptions.Add(ProfileDescriptionAdministrator);
	
	AllRoles = UsersInternal.AllRoles().Map;
	
	AccessKindsProperties = StandardSubsystemsServer.ApplicationParameters(
		"AccessRestrictionParameters").AccessKindsProperties;
	
	// Transformation of descriptions into maps between IDs and properties,
	// for storage and quick processing
	ProfileProperties = New Map;
	For Each ProfileDescription In ProfileDescriptions Do
		// Checking whether roles are present in the metadata
		For Each Role In ProfileDescription.Roles Do
			If AllRoles.Get(Role) = Undefined Then
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'In the description of the profile ""%1 (%2)"",
					           | role ""%3"" is not found in the metadata.'"),
					ProfileDescription.Name,
					ProfileDescription.ID,
					Role);
			EndIf;
		EndDo;
		If ProfileProperties.Get(ProfileDescription.ID) <> Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Profile with ID ""%1"" already exists.'"),
				ProfileDescription.ID);
		EndIf;
		ProfileProperties.Insert(ProfileDescription.ID, ProfileDescription);
		If ValueIsFilled(ProfileDescription.Name) Then
			If ProfileProperties.Get(ProfileDescription.Name) <> Undefined Then
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Profile with the name ""%1"" already exists.'"),
					ProfileDescription.Name);
			EndIf;
			ProfileProperties.Insert(ProfileDescription.Name, ProfileDescription);
		EndIf;
		// Transformation of ValueList into Map, for fixing
		AccessKinds = New Map;
		For Each ListItem In ProfileDescription.AccessKinds Do
			AccessKindName       = ListItem.Value;
			AccessTypeAdjustment = ListItem.Presentation;
			If AccessKindsProperties.ByNames.Get(AccessKindName) = Undefined Then
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'In the description of profile ""%1"",
					           | a nonexistent access kind ""%2"" is specified.'"),
					?(ValueIsFilled(ProfileDescription.Name),
					  ProfileDescription.Name,
					  ProfileDescription.ID),
					AccessKindName);
			EndIf;
			If AccessTypeAdjustment <> ""
			   And AccessTypeAdjustment <> "InitiallyAllProhibited"
			   And AccessTypeAdjustment <> "Preset"
			   And AccessTypeAdjustment <> "InitiallyAllAllowed" Then
				
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'In the description of profile ""%1"",
					           |for access kind ""%2"",
                   |an unknown adjustment ""%3"" is specified.
					           |
					           |Only the following
					           |adjustments are allowed:
					           |- ""InitiallyAllProhibited"" or """",
					           |- ""InitiallyAllAllowed"", -  ""Preset"".'"),
					?(ValueIsFilled(ProfileDescription.Name),
					  ProfileDescription.Name,
					  ProfileDescription.ID),
					AccessKindName,
					AccessTypeAdjustment);
			EndIf;
			AccessKinds.Insert(AccessKindName, AccessTypeAdjustment);
		EndDo;
		ProfileDescription.AccessKinds = AccessKinds;
		
		// Deleting duplicate values
		AccessValues = New Array;
		AccessValueTable = New ValueTable;
		AccessValueTable.Columns.Add("AccessKind",      Metadata.DefinedTypes.AccessValue.Type);
		AccessValueTable.Columns.Add("AccessValue", Metadata.DefinedTypes.AccessValue.Type);
		
		For Each ListItem In ProfileDescription.AccessValues Do
			Filter = New Structure;
			Filter.Insert("AccessKind",      ListItem.Value);
			Filter.Insert("AccessValue", ListItem.Presentation);
			AccessKind      = Filter.AccessKind;
			AccessValue = Filter.AccessValue;
			
			AccessKindProperties = AccessKindsProperties.ByNames.Get(AccessKind);
			If AccessKindProperties = Undefined Then
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'In the description of profile ""%1"",
					           |a nonexistent access kind ""%2""
					           |is specified for the access value ""%3"".'"),
					?(ValueIsFilled(ProfileDescription.Name),
					  ProfileDescription.Name,
					  ProfileDescription.ID),
					AccessKind,
					AccessValue);
			EndIf;
			
			MetadataObject = Undefined;
			DotPosition = Find(AccessValue, ".");
			If DotPosition > 0 Then
				MetadataObjectKind = Left(AccessValue, DotPosition - 1);
				RemainingString = Mid(AccessValue, DotPosition + 1);
				DotPosition = Find(RemainingString, ".");
				If DotPosition > 0 Then
					MetadataObjectName = Left(RemainingString, DotPosition - 1);
					MetadataObjectFullName = MetadataObjectKind + "." + MetadataObjectName;
					MetadataObject = Metadata.FindByFullName(MetadataObjectFullName);
				EndIf;
			EndIf;
			
			If MetadataObject = Undefined Then
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'In the description
					           |of profile ""%1"",
					           |for access kind ""%2"",
					           |there is no specified access value type ""%3"".'"),
					?(ValueIsFilled(ProfileDescription.Name),
					  ProfileDescription.Name,
					  ProfileDescription.ID),
					AccessKind,
					AccessValue);
			EndIf;
			
			Try
				AccessValueEmptyRef = CommonUse.ObjectManagerByFullName(
					MetadataObjectFullName).EmptyRef();
			Except
				AccessValueEmptyRef = Undefined;
			EndTry;
			
			If AccessValueEmptyRef = Undefined Then
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'In the description of profile ""%1"",
					           |for access kind ""%2"",
					           |the specified access value type ""%3"" is not of reference type.'"),
					?(ValueIsFilled(ProfileDescription.Name),
					  ProfileDescription.Name,
					  ProfileDescription.ID),
					AccessKind,
					AccessValue);
			EndIf;
			AccessValueType = TypeOf(AccessValueEmptyRef);
			
			AccessKindPropertiesByType = AccessKindsProperties.ByValueTypes.Get(AccessValueType);
			If AccessKindPropertiesByType = Undefined
			 Or AccessKindPropertiesByType.Name <> AccessKind Then
				
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'In the description of profile ""%1"",
					           |the specified access value ""%3"" is of type 
                   |which is not specified in the properties of access type ""%2"".'"),
					?(ValueIsFilled(ProfileDescription.Name),
					  ProfileDescription.Name,
					  ProfileDescription.ID),
					AccessKind,
					AccessValue);
			EndIf;
			
			If AccessValueTable.FindRows(Filter).Count() > 0 Then
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'In the description of profile ""%1"",
					           |for access kind ""%2"",
					           |access value ""%3"" is specified again.'"),
					?(ValueIsFilled(ProfileDescription.Name),
					  ProfileDescription.Name,
					  ProfileDescription.ID),
					AccessKind,
					AccessValue);
			EndIf;
			AccessValues.Add(Filter);
		EndDo;
		ProfileDescription.AccessValues = AccessValues;
	EndDo;
	
	Return CommonUse.FixedData(New Structure(
		"UpdateParameters, ProfileDescriptions", UpdateParameters, ProfileProperties));
	
EndFunction

Function PredefinedProfilesMatch(NewProfiles, OldProfiles, HasDeleted)
	
	PredefinedProfilesMatch =
		NewProfiles.Count() = OldProfiles.Count();
	
	For Each Profile In OldProfiles Do
		If NewProfiles.Find(Profile) = Undefined Then
			PredefinedProfilesMatch = False;
			HasDeleted = True;
			Break;
		EndIf;
	EndDo;
	
	Return PredefinedProfilesMatch;
	
EndFunction

// Replaces an existing supplied access group profile by its description, or creates a new supplied profile.
// 
// Parameters:
//  ProfileProperties - FixedStructure - profile properties matching
//                    the structure returned by NewAccessGroupProfileDescription function of AccessManagement common module.
// 
// Returns:
//  Boolean. True - if the profile is changed.
//
Function RefreshAccessGroupsProfile(ProfileProperties, DoNotUpdateUserRoles = False)
	
	ProfileChanged = False;
	
	ProfileRef = SuppliedProfileById(ProfileProperties.ID);
	If ProfileRef = Undefined Then
		
		If ValueIsFilled(ProfileProperties.Name) Then
			Query = New Query;
			Query.Text =
			"SELECT
			|	AccessGroupProfiles.Ref AS Ref,
			|	AccessGroupProfiles.PredefinedDataName AS PredefinedDataName
			|FROM
			|	Catalog.AccessGroupProfiles AS AccessGroupProfiles
			|WHERE
			|	AccessGroupProfiles.Predefined = TRUE";
			Selection = Query.Execute().Select();
			
			While Selection.Next() Do
				PredefinedName = Selection.PredefinedDataName;
				If Upper(ProfileProperties.Name) = Upper(PredefinedName) Then
					ProfileRef = Selection.Ref;
					Break;
				EndIf;
			EndDo;
		EndIf;
		
		If ProfileRef = Undefined Then
			// The supplied profile is not found and must be created
			ProfileObject = Catalogs.AccessGroupProfiles.CreateItem();
		Else
			// The supplied profile is not associated with a predefined item
			ProfileObject = ProfileRef.GetObject();
		EndIf;
		
		ProfileObject.SuppliedDataID =
			New UUID(ProfileProperties.ID);
		
		ProfileChanged = True;
	Else
		ProfileObject = ProfileRef.GetObject();
		ProfileChanged = SuppliedProfileChanged(ProfileObject);
	EndIf;
	
	If ProfileChanged Then
		LockDataForEdit(ProfileObject.Ref, ProfileObject.DataVersion);
		
		ProfileObject.Description = ProfileProperties.Description;
		
		ProfileObject.Roles.Clear();
		For Each Role In ProfileRolesDescription(ProfileProperties) Do
			MetadataRoles = Metadata.Roles.Find(Role);
			If MetadataRoles = Undefined Then
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'When updating the supplied profile ""%1"",
					           |role ""%2"" is not found in the metadata.'"),
					ProfileProperties.Description,
					Role);
			EndIf;
			ProfileObject.Roles.Add().Role =
				CommonUse.MetadataObjectID(MetadataRoles)
		EndDo;
		
		ProfileObject.AccessKinds.Clear();
		For Each AccessKindDescription In ProfileProperties.AccessKinds Do
			AccessKindProperties = AccessManagementInternal.AccessKindProperties(AccessKindDescription.Key);
			Row = ProfileObject.AccessKinds.Add();
			Row.AccessKind  = AccessKindProperties.Ref;
			Row.Preset      = AccessKindDescription.Value = "Preset";
			Row.AllAllowed  = AccessKindDescription.Value = "InitiallyAllAllowed";
		EndDo;
		
		ProfileObject.AccessValues.Clear();
		For Each AccessValueDetails In ProfileProperties.AccessValues Do
			AccessKindProperties = AccessManagementInternal.AccessKindProperties(AccessValueDetails.AccessKind);
			ValueRow = ProfileObject.AccessValues.Add();
			ValueRow.AccessKind = AccessKindProperties.Ref;
			Query = New Query(StrReplace("Select Value (%1) AS Value", "%1", AccessValueDetails.AccessValue));
			ValueRow.AccessValue = Query.Execute().Unload()[0].Value;
		EndDo;
		
		If DoNotUpdateUserRoles Then
			ProfileObject.AdditionalProperties.Insert("DoNotUpdateUserRoles");
		EndIf;
		ProfileObject.Write();
		UnlockDataForEdit(ProfileObject.Ref);
	EndIf;
	
	Return ProfileChanged;
	
EndFunction

Function ProfileRolesDescription(ProfileDescription)
	
	ProfileRolesDescription = New Array;
	DataSeparationEnabled = CommonUseCached.DataSeparationEnabled();
	
	If DataSeparationEnabled Then
		// Deleting from profile descriptions the roles that contain rights
		// inaccessible for separated users.
		InaccessibleRoles = UsersInternal.InaccessibleRolesByUserType(
			Enums.UserTypes.DataAreaUser);
		
	ElsIf ProfileDescription.ID = AdministratorProfileID() Then
		
		FullAdministratorRoleName = Users.FullAdministratorRole().Name;
		
		If ProfileRolesDescription.Find(FullAdministratorRoleName) = Undefined Then
			ProfileRolesDescription.Add(FullAdministratorRoleName);
		EndIf;
	EndIf;
	
	For Each Role In ProfileDescription.Roles Do
		If DataSeparationEnabled Then
			If InaccessibleRoles.Get(Role) <> Undefined Then
				Continue;
			EndIf;
		EndIf;
		ProfileRolesDescription.Add(Role);
	EndDo;
	
	Return ProfileRolesDescription;
	
EndFunction

Function IncompatibleAccessGroupProfileQuantity()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AccessGroupProfiles.Ref
	|FROM
	|	Catalog.AccessGroupProfiles AS AccessGroupProfiles
	|WHERE
	|	AccessGroupProfiles.Roles.Role.DeletionMark = TRUE";
	
	Result = Query.Execute().Unload();
	
	Return Result.Count();
	
EndFunction

#EndRegion

#EndIf
