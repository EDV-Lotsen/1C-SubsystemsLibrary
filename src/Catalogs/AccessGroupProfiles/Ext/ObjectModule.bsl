#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Var OldProfileRoles; // Profile roles before changing that can be used in the
                     // OnWrite event handler.

Var OldDeletionMark; // Access group profile deletion mark before changing that
                     // can be used in the OnWrite event handler. 

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If IsFolder Then
		Return;
	EndIf;
	
	// Getting old profile roles
	QueryResult = CommonUse.ObjectAttributeValue(Ref, "Roles");
	If TypeOf(QueryResult) = Type("QueryResult") Then
		OldProfileRoles = QueryResult.Unload();
	Else
		OldProfileRoles = Roles.Unload(New Array);
	EndIf;

	OldDeletionMark = CommonUse.ObjectAttributeValue(
		Ref, "DeletionMark");
	
	If Ref = Catalogs.AccessGroupProfiles.Administrator Then
		User = Undefined;
	Else
	 // Checking roles
		LineNumber = Roles.Count() - 1;
		While LineNumber >= 0 Do
			If Upper(Roles[LineNumber].Role) = Upper("FullAccess")
			Or Upper(Roles[LineNumber].Role) = Upper("FullAdministrator") Then
				
				Roles.Delete(LineNumber);
			EndIf;
			LineNumber = LineNumber - 1;
		EndDo;
	EndIf;
	
	If Not AdditionalProperties.Property("DoNotUpdateAttributeSuppliedProfileChanged") Then
		SuppliedProfileChanged =
			Catalogs.AccessGroupProfiles.SuppliedProfileChanged(ThisObject);
	EndIf;
	
	SimplifiedInterface = AccessManagementInternal.SimplifiedAccessRightSetupInterface();
	
	If SimplifiedInterface Then
// Updating descriptions for personal access groups with this profile (if any)
		Query = New Query;
		Query.SetParameter("Profile",     Ref);
		Query.SetParameter("Description", Description);
		Query.Text =
		"SELECT
		|	AccessGroups.Ref
		|FROM
		|	Catalog.AccessGroups AS AccessGroups
		|WHERE
		|	AccessGroups.Profile = &Profile
		|	AND AccessGroups.User <> UNDEFINED
		|	AND AccessGroups.User <> VALUE(Catalog.Users.EmptyRef)
		|	AND AccessGroups.User <> VALUE(Catalog.ExternalUsers.EmptyRef)
		|	AND AccessGroups.Description <> &Description";
		ChangedAccessGroups = Query.Execute().Unload().UnloadColumn("Ref");
		If ChangedAccessGroups.Count() > 0 Then
			For Each AccessGroupRef In ChangedAccessGroups Do
				PersonalAccessGroupObject = AccessGroupRef.GetObject();
				PersonalAccessGroupObject.Description = Description;
				PersonalAccessGroupObject.DataExchange.Load = True;
				PersonalAccessGroupObject.Write();
			EndDo;
			AdditionalProperties.Insert(
				"PersonalAccessGroupsWithUpdatedDescription", ChangedAccessGroups);
		EndIf;
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If IsFolder Then
		Return;
	EndIf;
	
	// Checking the supplied data for uniqueness
	If SuppliedDataID <> New UUID("00000000-0000-0000-0000-000000000000") Then
		SetPrivilegedMode(True);
		
		Query = New Query;
		Query.SetParameter("SuppliedDataID", SuppliedDataID);
		Query.Text =
		"SELECT
		|	AccessGroupProfiles.Ref AS Ref,
		|	AccessGroupProfiles.Description AS Description
		|FROM
		|	Catalog.AccessGroupProfiles AS AccessGroupProfiles
		|WHERE
		|	AccessGroupProfiles.SuppliedDataID = &SuppliedDataID";
		
		Selection = Query.Execute().Select();
		If Selection.Count() > 1 Then
			
			BriefErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error when writing profile ""%1"".
				           |The supplied profile already exists:'"),
				Description);
			
			DetailErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error when writing profile ""%1"".
				           |The supplied data ID ""%2"" is used in the profile:'"),
				Description,
				String(SuppliedDataID));
			
			While Selection.Next() Do
				If Selection.Ref <> Ref Then
					
					BriefErrorDescription = BriefErrorDescription
						+ Chars.LF + """" + Selection.Description + """.";
					
					DetailErrorDescription = DetailErrorDescription
						+ Chars.LF + """" + Selection.Description + """ ("
						+ String(Selection.Ref.UUID())+ ")."
				EndIf;
			EndDo;
			
			WriteLogEvent(
				NStr("en = 'Access management.Violation of the supplied profile uniqueness'",
				     CommonUseClientServer.DefaultLanguageCode()),
				EventLogLevel.Error, , , DetailErrorDescription);
			
			Raise BriefErrorDescription;
		EndIf;
		SetPrivilegedMode(False);
	EndIf;
	
	MetadataObjects = UpdateUserRolesOnChangeProfileRoles();
	
	// When setting the deletion mark, the deletion mark is also set for the profile access groups
	If DeletionMark And OldDeletionMark = False Then
		Query = New Query;
		Query.SetParameter("Profile", Ref);
		Query.Text =
		"SELECT
		|	AccessGroups.Ref
		|FROM
		|	Catalog.AccessGroups AS AccessGroups
		|WHERE
		|	(Not AccessGroups.DeletionMark)
		|	AND AccessGroups.Profile = &Profile";
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			LockDataForEdit(Selection.Ref);
			AccessGroupObject = Selection.Ref.GetObject();
			AccessGroupObject.DeletionMark = True;
			AccessGroupObject.Write();
		EndDo;
	EndIf;
	
	If AdditionalProperties.Property("UpdateProfileAccessGroups") Then
		Catalogs.AccessGroups.UpdateProfileAccessGroups(Ref, True);
	EndIf;
	
	// Updating access group tables and values
	Query = New Query;
	Query.SetParameter("Profile", Ref);
	Query.Text =
	"SELECT
	|	AccessGroups.Ref AS Ref
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	AccessGroups.Profile = &Profile
	|	AND (Not AccessGroups.IsFolder)";
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		ProfileAccessGroups = Query.Execute().Unload().UnloadColumn("Ref");
		
		InformationRegisters.AccessGroupValues.UpdateRegisterData(ProfileAccessGroups);
		
		If MetadataObjects.Count() > 0 Then
			InformationRegisters.AccessGroupTables.UpdateRegisterData(
				ProfileAccessGroups, MetadataObjects);
		EndIf;
	EndIf;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, AttributesToCheck)
	
	If AdditionalProperties.Property("CheckedObjectAttributes") Then
		CommonUse.DeleteNoCheckAttributesFromArray(
			AttributesToCheck, AdditionalProperties.CheckedObjectAttributes);
	EndIf;
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	If Not IsFolder Then
		SuppliedDataID = Undefined;
	EndIf;
	
EndProcedure

// Auxiliary procedures and functions

Function UpdateUserRolesOnChangeProfileRoles()
	
	Query = New Query;
	Query.SetParameter("Profile", Ref);
	Query.SetParameter("OldProfileRoles", OldProfileRoles);
	Query.Text =
	"SELECT
	|	OldProfileRoles.Role
	|INTO OldProfileRoles
	|FROM
	|	&OldProfileRoles AS OldProfileRoles
	|;
 
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	Data.Role
	|INTO ModifiedRoles
	|FROM
	|	(SELECT
	|		OldProfileRoles.Role AS Role,
	|		-1 AS RowChangeKind
	|	FROM
	|		OldProfileRoles AS OldProfileRoles
	|	
	|	UNION ALL
	|	
	|	SELECT DISTINCT
	|		NewProfileRoles.Role,
	|		1
	|	FROM
	|		Catalog.AccessGroupProfiles.Roles AS NewProfileRoles
	|	WHERE
	|		NewProfileRoles.Ref = &Profile) AS Data
	|
	|GROUP BY
	|	Data.Role
	|
	|HAVING
	|	SUM(Data.RowChangeKind) <> 0
	|
	|INDEX BY
	|	Data.Role";
	
	Query.Text = Query.Text + "
	|;
 
	|////////////////////////////////////////////////////////////////////////////////
	|" +
	"SELECT DISTINCT
	|	RoleRights.MetadataObject
	|FROM
	|	InformationRegister.RoleRights AS RoleRights
	|		INNER JOIN ModifiedRoles AS ModifiedRoles
	|		ON RoleRights.Role = ModifiedRoles.Role";
	
	QueryResults = Query.ExecuteBatch();
	
	If Not AdditionalProperties.Property("DoNotUpdateUserRoles")
	   And Not QueryResults[1].IsEmpty() Then
		
		Query.Text =
		"SELECT DISTINCT
		|	UserGroupContents.User
		|FROM
		|	InformationRegister.UserGroupContents AS UserGroupContents
		|		INNER JOIN Catalog.AccessGroups.Users AS AccessGroupsUsers
		|		ON UserGroupContents.UserGroup = AccessGroupsUsers.User
		|			AND (AccessGroupsUsers.Ref.Profile = &Profile)";
		
		UsersForRoleUpdate =
			Query.Execute().Unload().UnloadColumn("User");
		
		AccessManagement.UpdateUserRoles(UsersForRoleUpdate);
	EndIf;
	
	Return QueryResults[2].Unload().UnloadColumn("MetadataObject");
	
EndFunction

#EndRegion

#EndIf
