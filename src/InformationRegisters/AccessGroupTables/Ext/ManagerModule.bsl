#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalInterface

// Updates the register data based on the result of changing the role rights
//saved when updating the RoleRights information register.
//
Procedure UpdateRegisterDataByConfigurationChanges() Export
	
	SetPrivilegedMode(True);
	
	Parameters = AccessManagementInternalCached.Parameters();
	
	LastChanges = StandardSubsystemsServer.ApplicationParameterChanges(
		Parameters, "RoleRightMetadataObjects");
	
	If LastChanges = Undefined Then
		UpdateRegisterData();
	Else
		MetadataObjects = New Array;
		For Each ChangePart In LastChanges Do
			If TypeOf(ChangePart) = Type("FixedArray") Then
				For Each MetadataObject In ChangePart Do
					If MetadataObjects.Find(MetadataObject) = Undefined Then
						MetadataObjects.Add(MetadataObject);
					EndIf;
				EndDo;
			Else
				MetadataObjects = Undefined;
				Break;
			EndIf;
		EndDo;
		
		If MetadataObjects.Count() > 0 Then
			UpdateRegisterData(, MetadataObjects);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// Updates the register data when changing the
// profile role content or the access group profiles.
 
// Parameters:
//  AccessGroups - CatalogRef.AccessGroups.
//               - Undefined - no selection.
//
//  Tables       - CatalogRef.MetadataObjectIDs.
//               - Array of values of the type specified above.
//               - Undefined - no selection.
 
//  HasChanges   - Boolean (return value) - True if data is changed; not set otherwise.
 
Procedure UpdateRegisterData(AccessGroups     = Undefined,
                             Tables           = Undefined,
                             HasChanges       = Undefined) Export
	
	If TypeOf(Tables) = Type("Array")
	   And Tables.Count() > 500 Then
	
		Tables = Undefined;
	EndIf;
	
	SetPrivilegedMode(True);
	
	TemporaryTableQueryText =
	"SELECT
	|	AccessGroups.Profile AS Profile,
	|	RoleRights.MetadataObject AS Table,
	|	RoleRights.MetadataObject.EmptyRefValue AS TableType,
	|	MAX(RoleRights.Update) AS Update
	|INTO ProfileTables
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|		INNER JOIN Catalog.AccessGroupProfiles.Roles AS ProfileRoles
	|		ON AccessGroups.Profile = ProfileRoles.Ref
	|			AND (&AccessGroupFilterCriterion1)
	|			AND (Not AccessGroups.DeletionMark)
	|			AND (Not ProfileRoles.Ref.DeletionMark)
	|			AND (ProfileRoles.Ref <> VALUE(Catalog.AccessGroupProfiles.Administrator))
	|		INNER JOIN InformationRegister.RoleRights AS RoleRights
	|		ON (&TableFilterCriterion1)
	|			AND (RoleRights.Role = ProfileRoles.Role)
	|			AND (Not RoleRights.Role.DeletionMark)
	|			AND (Not RoleRights.MetadataObject.DeletionMark)
	|
	|GROUP BY
	|	AccessGroups.Profile,
	|	RoleRights.MetadataObject,
	|	RoleRights.MetadataObject.EmptyRefValue
	|
	|INDEX BY
	|	RoleRights.MetadataObject
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ProfileTables.Table,
	|	AccessGroups.Ref AS AccessGroup,
	|	ProfileTables.Update AS Update,
	|	ProfileTables.TableType AS TableType
	|INTO NewData
	|FROM
	|	ProfileTables AS ProfileTables
	|		INNER JOIN Catalog.AccessGroups AS AccessGroups
	|		ON (&AccessGroupFilterCriterion1)
	|			AND (AccessGroups.Profile = ProfileTables.Profile)
	|			AND (Not AccessGroups.DeletionMark)
	|
	|INDEX BY
	|	ProfileTables.Table,
	|	AccessGroups.Ref";
	
	QueryText =
	"SELECT
	|	NewData.Table,
	|	NewData.AccessGroup,
	|	NewData.Update,
	|	NewData.TableType,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	NewData AS NewData";
	
	// Preparing selectable fields with optional selection
	Fields = New Array; 
	Fields.Add(New Structure("Table",       "&TableFilterCriterion2"));
	Fields.Add(New Structure("AccessGroup", "&AccessGroupFilterCriterion2"));
	Fields.Add(New Structure("Update"));
	Fields.Add(New Structure("TableType"));
	
	Query = New Query;
	Query.Text = AccessManagementInternal.ChangeSelectionQueryText(
		QueryText, Fields, "InformationRegister.AccessGroupTables", TemporaryTableQueryText);
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, Tables, "Tables",
		"&TableFilterCriterion1:RoleRights.MetadataObject
		|&TableFilterCriterion2:OldData.Table");
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, AccessGroups, "AccessGroups",
		"&AccessGroupFilterCriterion1:AccessGroups.Ref
		|&AccessGroupFilterCriterion2:OldData.AccessGroup");
		
	DataLock = New DataLock;
	LockItem = DataLock.Add("InformationRegister.AccessGroupTables");
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		DataLock.Lock();
		Changes = Query.Execute().Unload();
		
		If AccessGroups <> Undefined
		   And Tables    = Undefined Then
			
			FilterDimensions = "AccessGroup";
		Else
			FilterDimensions = Undefined;
		EndIf;
		
		AccessManagementInternal.UpdateInformationRegister(
			InformationRegisters.AccessGroupTables, Changes, HasChanges, , FilterDimensions);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion

#EndIf