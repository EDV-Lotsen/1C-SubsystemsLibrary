#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalProceduresAndFunctions

// Updates the register data when changing:
// - allowed access group values,
// - allowed access group profile values,
// - access kind usage.
// Parameters:
//  AccessGroups  - CatalogRef.AccessGroups.
//                - Array of values of the types specified above.
//                - Undefined - not filtered.
//
//  HasChanges    - Boolean (return value) - True if data is
//                  changed; not set otherwise.
 
Procedure UpdateRegisterData(AccessGroups = Undefined, HasChanges = Undefined) Export
	
	DataLock = New DataLock;
	LockItem = DataLock.Add("InformationRegister.AccessGroupValues");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem = DataLock.Add("InformationRegister.DefaultAccessGroupValues");
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		DataLock.Lock();
		
		AccessKindsToUse      = New ValueTable;
		AccessKindsToUse.Columns.Add("AccessKind", Metadata.DefinedTypes.AccessValue.Type);
		AccessKindsProperties = AccessManagementInternal.AccessKindProperties();
		
		For Each AccessKindProperties In AccessKindsProperties Do
			If AccessManagementInternal.AccessKindUsed(AccessKindProperties.Ref) Then
				AccessKindsToUse.Add().AccessKind = AccessKindProperties.Ref;
			EndIf;
		EndDo;
		
		UpdateAllowedValues(AccessKindsToUse, AccessGroups, HasChanges);
		
		UpdateDefaultAllowedValues(AccessKindsToUse, AccessGroups, HasChanges);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Procedure UpdateAllowedValues(AccessKindsToUse, AccessGroups = Undefined, HasChanges = Undefined)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("AccessKindsToUse", AccessKindsToUse);
	
	Query.SetParameter("AccessKindGroupAndValueTypes",
		AccessManagementInternalCached.AccessKindGroupAndValueTypes());
	
	TemporaryTableQueryText =
	"SELECT
	|	AccessKindsToUse.AccessKind
	|INTO AccessKindsToUse
	|FROM
	|	&AccessKindsToUse AS AccessKindsToUse
	|
	|INDEX BY
	|	AccessKindsToUse.AccessKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessKindGroupAndValueTypes.AccessKind,
	|	AccessKindGroupAndValueTypes.GroupAndValueType
	|INTO AccessKindGroupAndValueTypes
	|FROM
	|	&AccessKindGroupAndValueTypes AS AccessKindGroupAndValueTypes
	|
	|INDEX BY
	|	AccessKindGroupAndValueTypes.GroupAndValueType,
	|	AccessKindGroupAndValueTypes.AccessKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessGroups.Ref AS AccessGroup,
	|	ProfileAccessValues.AccessKind,
	|	ProfileAccessValues.AccessValue,
	|	CASE
	|		WHEN ProfileAccessKinds.AllAllowed
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS ValueIsAllowed
	|INTO ValueSettings
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|		INNER JOIN Catalog.AccessGroupProfiles.AccessKinds AS ProfileAccessKinds
	|		ON AccessGroups.Profile = ProfileAccessKinds.Ref
	|			AND (ProfileAccessKinds.Preset)
	|			AND (Not AccessGroups.DeletionMark)
	|			AND (Not ProfileAccessKinds.Ref.DeletionMark)
	|			AND (&AccessGroupFilterCriterion1)
	|		INNER JOIN Catalog.AccessGroupProfiles.AccessValues AS ProfileAccessValues
	|		ON (ProfileAccessValues.Ref = ProfileAccessKinds.Ref)
	|			AND (ProfileAccessValues.AccessKind = ProfileAccessKinds.AccessKind)
	|
	|UNION ALL
	|
	|SELECT
	|	AccessKinds.Ref,
	|	AccessValues.AccessKind,
	|	AccessValues.AccessValue,
	|	CASE
	|		WHEN AccessKinds.AllAllowed
	|			THEN FALSE
	|		ELSE TRUE
	|	END
	|FROM
	|	Catalog.AccessGroups.AccessKinds AS AccessKinds
	|		INNER JOIN Catalog.AccessGroupProfiles.AccessKinds AS SpecifiedAccessKinds
	|		ON AccessKinds.Ref.Profile = SpecifiedAccessKinds.Ref
	|			AND AccessKinds.AccessKind = SpecifiedAccessKinds.AccessKind
	|			AND (Not SpecifiedAccessKinds.Preset)
	|			AND (Not AccessKinds.Ref.DeletionMark)
	|			AND (Not SpecifiedAccessKinds.Ref.DeletionMark)
	|			AND (&AccessGroupFilterCriterion2)
	|		INNER JOIN Catalog.AccessGroups.AccessValues AS AccessValues
	|		ON (AccessValues.Ref = AccessKinds.Ref)
	|			AND (AccessValues.AccessKind = AccessKinds.AccessKind)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ValueSettings.AccessGroup,
	|	ValueSettings.AccessValue,
	|	MAX(ValueSettings.ValueIsAllowed) AS ValueIsAllowed
	|INTO NewData
	|FROM
	|	ValueSettings AS ValueSettings
	|		INNER JOIN AccessKindGroupAndValueTypes AS AccessKindGroupAndValueTypes
	|		ON ValueSettings.AccessKind = AccessKindGroupAndValueTypes.AccessKind
	|			AND (VALUETYPE(ValueSettings.AccessValue) = VALUETYPE(AccessKindGroupAndValueTypes.GroupAndValueType))
	|		INNER JOIN AccessKindsToUse AS AccessKindsToUse
	|		ON ValueSettings.AccessKind = AccessKindsToUse.AccessKind
	|
	|GROUP BY
	|	ValueSettings.AccessGroup,
	|	ValueSettings.AccessValue
	|
	|INDEX BY
	|	ValueSettings.AccessGroup,
	|	ValueSettings.AccessValue,
	|	ValueIsAllowed
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP ValueSettings";
	
	QueryText =
	"SELECT
	|	NewData.AccessGroup,
	|	NewData.AccessValue,
	|	NewData.ValueIsAllowed,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	NewData AS NewData";
	
	// Preparing selected fields with optional filtering
	Fields = New Array; 
	Fields.Add(New Structure("AccessGroup", "&AccessGroupFilterCriterion3"));
	Fields.Add(New Structure("AccessValue"));
	Fields.Add(New Structure("ValueIsAllowed"));
	
	Query.Text = AccessManagementInternal.ChangeSelectionQueryText(
		QueryText, Fields, "InformationRegister.AccessGroupValues", TemporaryTableQueryText);
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, AccessGroups, "AccessGroups",
		"&AccessGroupFilterCriterion1:AccessGroups.Ref    
     |&AccessGroupFilterCriterion2:AccessKinds.Ref
	 |&AccessGroupFilterCriterion3:OldData.AccessGroup");
		
	Changes = Query.Execute().Unload();
	
	AccessManagementInternal.UpdateInformationRegister(
		InformationRegisters.AccessGroupValues, Changes, HasChanges, , "AccessGroup");
	
EndProcedure

Procedure UpdateDefaultAllowedValues(AccessKindsToUse, AccessGroups = Undefined, HasChanges = Undefined)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("AccessKindsToUse", AccessKindsToUse);
	
	Query.SetParameter("AccessKindValueTypes",
		AccessManagementInternalCached.AccessKindValueTypes());
	
	Query.SetParameter("AccessKindGroupAndValueTypes",
		AccessManagementInternalCached.AccessKindGroupAndValueTypes());
	
	TemporaryTableQueryText =
	"SELECT
	|	AccessKindsToUse.AccessKind
	|INTO AccessKindsToUse
	|FROM
	|	&AccessKindsToUse AS AccessKindsToUse
	|
	|INDEX BY
	|	AccessKindsToUse.AccessKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessKindValueTypes.AccessKind,
	|	AccessKindValueTypes.ValueType
	|INTO AccessKindValueTypes
	|FROM
	|	&AccessKindValueTypes AS AccessKindValueTypes
	|
	|INDEX BY
	|	AccessKindValueTypes.ValueType,
	|	AccessKindValueTypes.AccessKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessKindGroupAndValueTypes.AccessKind,
	|	AccessKindGroupAndValueTypes.GroupAndValueType
	|INTO AccessKindGroupAndValueTypes
	|FROM
	|	&AccessKindGroupAndValueTypes AS AccessKindGroupAndValueTypes
	|
	|INDEX BY
	|	AccessKindGroupAndValueTypes.GroupAndValueType,
	|	AccessKindGroupAndValueTypes.AccessKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessGroups.Ref AS Ref,
	|	AccessGroups.Profile AS Profile
	|INTO AccessGroups
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|		INNER JOIN Catalog.AccessGroupProfiles AS AccessGroupProfiles
	|		ON AccessGroups.Profile = AccessGroupProfiles.Ref
	|			AND (Not AccessGroups.DeletionMark)
	|			AND (Not AccessGroupProfiles.DeletionMark)
	|			AND (&AccessGroupFilterCriterion1)
	|
	|INDEX BY
	|	AccessGroups.Ref,
	|	AccessGroups.Profile
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessGroups.Ref AS AccessGroup,
	|	ProfileAccessKinds.AccessKind,
	|	ProfileAccessKinds.AllAllowed
	|INTO AccessKindSettings
	|FROM
	|	AccessGroups AS AccessGroups
	|		INNER JOIN Catalog.AccessGroupProfiles.AccessKinds AS ProfileAccessKinds
	|		ON AccessGroups.Profile = ProfileAccessKinds.Ref
	|			AND (ProfileAccessKinds.Preset)
	|		INNER JOIN AccessKindsToUse AS AccessKindsToUse
	|		ON (ProfileAccessKinds.AccessKind = AccessKindsToUse.AccessKind)
	|
	|UNION ALL
	|
	|SELECT
	|	AccessKinds.Ref,
	|	AccessKinds.AccessKind,
	|	AccessKinds.AllAllowed
	|FROM
	|	AccessGroups AS AccessGroups
	|		INNER JOIN Catalog.AccessGroups.AccessKinds AS AccessKinds
	|		ON (AccessKinds.Ref = AccessGroups.Ref)
	|		INNER JOIN Catalog.AccessGroupProfiles.AccessKinds AS SpecifiedAccessKinds
	|		ON (SpecifiedAccessKinds.Ref = AccessGroups.Profile)
	|			AND (SpecifiedAccessKinds.AccessKind = AccessKinds.AccessKind)
	|			AND (Not SpecifiedAccessKinds.Preset)
	|		INNER JOIN AccessKindsToUse AS AccessKindsToUse
	|		ON (AccessKinds.AccessKind = AccessKindsToUse.AccessKind)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ValueSettings.AccessGroup,
	|	AccessKindGroupAndValueTypes.AccessKind,
	|	TRUE AS WithSettings
	|INTO HasValueSettings
	|FROM
	|	AccessKindGroupAndValueTypes AS AccessKindGroupAndValueTypes
	|		INNER JOIN InformationRegister.AccessGroupValues AS ValueSettings
	|		ON (VALUETYPE(AccessKindGroupAndValueTypes.GroupAndValueType) = VALUETYPE(ValueSettings.AccessValue))
	|		INNER JOIN AccessKindsToUse AS AccessKindsToUse
	|		ON AccessKindGroupAndValueTypes.AccessKind = AccessKindsToUse.AccessKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessGroups.Ref AS AccessGroup,
	|	AccessKindValueTypes.ValueType AS AccessValueType,
	|	MAX(ISNULL(AccessKindSettings.AllAllowed, TRUE)) AS AllAllowed,
	|	MAX(ISNULL(HasValueSettings.WithSettings, FALSE)) AS WithSettings
	|INTO TemplateForNewData
	|FROM
	|	AccessGroups AS AccessGroups
	|		INNER JOIN AccessKindValueTypes AS AccessKindValueTypes
	|		ON (TRUE)
	|		LEFT JOIN AccessKindSettings AS AccessKindSettings
	|		ON (AccessKindSettings.AccessGroup = AccessGroups.Ref)
	|			AND (AccessKindSettings.AccessKind = AccessKindValueTypes.AccessKind)
	|		LEFT JOIN HasValueSettings AS HasValueSettings
	|		ON (HasValueSettings.AccessGroup = AccessKindSettings.AccessGroup)
	|			AND (HasValueSettings.AccessKind = AccessKindSettings.AccessKind)
	|
	|GROUP BY
	|	AccessGroups.Ref,
	|	AccessKindValueTypes.ValueType
	|
	|INDEX BY
	|	AccessGroups.Ref,
	|	AccessKindValueTypes.ValueType
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemplateForNewData.AccessGroup,
	|	TemplateForNewData.AccessValueType,
	|	TemplateForNewData.AllAllowed,
	|	CASE
	|		WHEN TemplateForNewData.AllAllowed = TRUE
	|				AND TemplateForNewData.WithSettings = FALSE
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS NoSettings
	|INTO NewData
	|FROM
	|	TemplateForNewData AS TemplateForNewData
	|
	|INDEX BY
	|	TemplateForNewData.AccessGroup,
	|	TemplateForNewData.AccessValueType,
	|	TemplateForNewData.AllAllowed,
	|	NoSettings
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP AccessKindSettings";
	
	QueryText =
	"SELECT
	|	NewData.AccessGroup,
	|	NewData.AccessValueType,
	|	NewData.AllAllowed,
	|	NewData.NoSettings,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	NewData AS NewData";
	
	// Preparing selected fields with optional filtering
	Fields   = New Array; 
	Fields.Add(New Structure("AccessGroup", "&AccessGroupFilterCriterion2"));
	Fields.Add(New Structure("AccessValueType"));
	Fields.Add(New Structure("AllAllowed"));
	Fields.Add(New Structure("NoSettings"));
	
	Query.Text = AccessManagementInternal.ChangeSelectionQueryText(
		QueryText, Fields, "InformationRegister.DefaultAccessGroupValues", TemporaryTableQueryText);
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, AccessGroups, "AccessGroups",
"&AccessGroupFilterCriterion1:AccessGroups.Ref                         
 |&AccessGroupFilterCriterion2:OldData.AccessGroup");
	
	Changes = Query.Execute().Unload();
	
	AccessManagementInternal.UpdateInformationRegister(
		InformationRegisters.DefaultAccessGroupValues, Changes, HasChanges, , "AccessGroup");
	
EndProcedure

#EndRegion

#EndIf