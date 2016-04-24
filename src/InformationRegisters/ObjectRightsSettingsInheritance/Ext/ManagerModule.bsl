#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalInterface

// Updates a hierarchy of object rights settings owners.
// For example, the hierarchy of FileFolders catalog items.
// Parameters:
//  RightsSettingsOwners - Reference - for example, CatalogRef.FileFolders
//                         or other type for configuring the rights directly.
//                       - Rights owner type,
//                         for example ("CatalogRef.FileFolders")Type.
//                       - Array of values of the types specified above.
//                       - Undefined - no filtering for all types.
//                       - Object - for example, CatalogObject.FileFolders.
//                         When passing an object, update is possible 
//                         only if the object is to be written and it is 
//                         changed (or its parent is changed).
//  HasChanges           - Boolean (return value) - True if data is
//                         changed; not set otherwise.
//

Procedure UpdateRegisterData(Val RightsSettingsOwners = Undefined, HasChanges = Undefined) Export
	
	If RightsSettingsOwners = Undefined Then
		
		AvailableRights = AccessManagementInternalCached.Parameters(
			).AvailableRightsForObjectRightsSettings;
		
		Query = New Query;
		QueryText =
		"SELECT
		|	CurrentTable.Ref
		|FROM
		|	&CurrentTable AS CurrentTable";
		
		For Each KeyAndValue In AvailableRights.ByFullNames Do
			
			Query.Text = StrReplace(QueryText, "&CurrentTable", KeyAndValue.Key);
			Selection = Query.Execute().Select();
			
			While Selection.Next() Do
				UpdateOwnerParents(Selection.Ref, HasChanges);
			EndDo;
		EndDo;
		
	ElsIf TypeOf(RightsSettingsOwners) = Type("Array") Then
		
		For Each RightsSettingsOwner In RightsSettingsOwners Do
			UpdateOwnerParents(RightsSettingsOwner, HasChanges);
		EndDo;
	Else
		UpdateOwnerParents(RightsSettingsOwners, HasChanges);
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// Updates parents of the object rights settings owner.
// For example, catalog FileFolders.
// Parameters:
//  RightsSettingsOwner   - Reference - for example,
//                         CatalogRef.FileFolders or another type used to
//                         configure the rights directly.
//                       - Object - for example, CatalogObject.FileFolders.
//                         When passing an object, update is possible
//                         only if the object is to be written and it is
//                         changed (or its parent is changed).
//  HasChanges           - Boolean (return value) - True if data is
//                         changed; not set otherwise.
//  UpdateHierarchy      - Boolean - updates the subordinate hierarchy forcibly,
//                         regardless of any owner parents changes.
//  ObjectsWithChanges   - for internal use only.
//
 
Procedure UpdateOwnerParents(RightsSettingsOwner, HasChanges, UpdateHierarchy = False, ObjectsWithChanges = Undefined) Export
	
	SetPrivilegedMode(True);
	
	AvailableRights = AccessManagementInternalCached.Parameters().AvailableRightsForObjectRightsSettings;
	OwnerType = TypeOf(RightsSettingsOwner);
	
	ErrorTitle =
		NStr("en = 'Error when updating the hierarchy of right owners by access values.'")
		+ Chars.LF
		+ Chars.LF;
	
	If AvailableRights.ByTypes.Get(OwnerType) = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			ErrorTitle +
			NStr("en = 'The usage of object rights settings
			           |is not configured for type %1.'"),
			String(OwnerType));
	EndIf;
	
	If AvailableRights.ByRefTypes.Get(OwnerType) = Undefined Then
		Ref    = AccessManagementInternal.ObjectRef(RightsSettingsOwner);
		Object = RightsSettingsOwner;
	Else
		Ref    = RightsSettingsOwner;
		Object = Undefined;
	EndIf;
	
	Hierarchical = AvailableRights.HierarchicalTables.Get(OwnerType) <> Undefined;
	UpdateRequired = False;
	
	If Hierarchical Then
		ObjectParentProperties = ParentProperties(Ref);
		
		If Object <> Undefined Then
			// Checking the object for changes
			If ObjectParentProperties.Ref <> Object.Parent Then
				UpdateRequired = True;
			EndIf;
			ObjectParentProperties.Ref     = Object.Parent;
			ObjectParentProperties.Inherit = SettingsInheritance(Object.Parent);
		Else
			UpdateRequired = True;
		EndIf;
	Else
		If Object = Undefined Then
			UpdateRequired = True;
		EndIf;
	EndIf;
	
	If Not UpdateRequired Then
		Return;
	EndIf;
	
	DataLock = New DataLock;
	LockItem = DataLock.Add("InformationRegister.ObjectRightsSettingsInheritance");
	LockItem.Mode = DataLockMode.Exclusive;
	
	If Object = Undefined Then
		AdditionalProperties = Undefined;
	Else
		AdditionalProperties = New Structure("LeadingObjectBeforeWrite", Object);
	EndIf;
	
	BeginTransaction();
	Try
		DataLock.Lock();
		
		RecordSet = InformationRegisters.ObjectRightsSettingsInheritance.CreateRecordSet();
		RecordSet.Filter.Object.Set(Ref);
		
		// Preparing object parents
		If Hierarchical Then
			NewRecords = ObjectParents(Ref, Ref, ObjectParentProperties);
		Else
			NewRecords = AccessManagementInternalCached.EmptyRecordSetTable(
				"InformationRegister.ObjectRightsSettingsInheritance").Copy();
			
			NewRow        = NewRecords.Add();
			NewRow.Object = Ref;
			NewRow.Parent = Ref;
		EndIf;
		
		HasCurrentChanges = False;
		AccessManagementInternal.UpdateRecordSet(
			RecordSet, NewRecords, , , , HasCurrentChanges, , , , , , AdditionalProperties);
		
		If HasCurrentChanges Then
			HasChanges = True;
			
			If ObjectsWithChanges <> Undefined
	  And ObjectsWithChanges.Find(Ref) = Undefined Then
				
				ObjectsWithChanges.Add(Ref);
			EndIf;
		EndIf;
		
		If Hierarchical And (HasCurrentChanges Or UpdateHierarchy) Then
			UpdateOwnerHierarchy(Ref, HasChanges, ObjectsWithChanges);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Procedure UpdateOwnerHierarchy(Ref, HasChanges, ObjectsWithChanges) Export
	
	// Updating the list of item parents in the current value hierarchy
	Query = New Query;
	Query.SetParameter("Ref", Ref);
	Query.Text =
	"SELECT
	|	TableWithHierarchy.Ref AS SubordinateRef
	|FROM
	|	&TableWithHierarchy AS TableWithHierarchy
	|WHERE
	|	TableWithHierarchy.Ref IN HIERARCHY(&Ref)
	|	AND TableWithHierarchy.Ref <> &Ref";
	
	Query.Text = StrReplace(
		Query.Text, "&TableWithHierarchy", Ref.Metadata().FullName() );
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		NewRecords = ObjectParents(Selection.SubordinateRef, Ref);
		
		RecordSet = InformationRegisters.ObjectRightsSettingsInheritance.CreateRecordSet();
		RecordSet.Filter.Object.Set(Selection.SubordinateRef);
		
		HasCurrentChanges = False;
		AccessManagementInternal.UpdateRecordSet(
			RecordSet, NewRecords, , , , HasCurrentChanges);
		
		If HasCurrentChanges Then
			HasChanges = True;
			
			If ObjectsWithChanges <> Undefined
	  And ObjectsWithChanges.Find(Ref) = Undefined Then
				
				ObjectsWithChanges.Add(Ref);
			EndIf;
		EndIf;
		
	EndDo;
	
EndProcedure

// Fills RecordSet with object parents including itself as a parent.
// Parameters:
//  Ref                    - Reference in ObjectRef hierarchy or ObjectRef.
//  ObjectRef              - Reference to the source object.
//  ObjectParentProperties - Structure with the following properties:
//                            Ref      - Reference to the source object parent
//                                       that can differ from the
//                                       parent recorded in the database.
//                            Inherit  - Boolean - parent settings inheritance.
// Returns:
//  RecordSet - InformationRegisterRecordSet.ObjectRightsSettingsInheritance.
//

Function ObjectParents(Ref, ObjectRef, ObjectParentProperties = "", GetInheritance = True) Export
	
	NewRecords = AccessManagementInternalCached.EmptyRecordSetTable(
		"InformationRegister.ObjectRightsSettingsInheritance").Copy();
	
	// Getting the parent rights settings inheritance flag for the reference
	If GetInheritance Then
		Inherit = SettingsInheritance(Ref);
	Else
		Inherit = True;
		NewRecords.Columns.Add("Level", New TypeDescription("Number"));
	EndIf;
	
	Row = NewRecords.Add();
	Row.Object  = Ref;
	Row.Parent  = Ref;
	Row.Inherit = Inherit;
	
	If Not Inherit Then
		Return NewRecords;
	EndIf;
	
	If Ref = ObjectRef Then
		CurrentParentProperties = ObjectParentProperties;
	Else
		CurrentParentProperties = ParentProperties(Ref);
	EndIf;
	
	While ValueIsFilled(CurrentParentProperties.Ref) Do
	
		Row = NewRecords.Add();
		Row.Object     = Ref;
		Row.Parent     = CurrentParentProperties.Ref;
		Row.UsageLevel = 1;
		
		If Not GetInheritance Then
			Row.Level = Row.Parent.Level();
		EndIf;
		
		If Not CurrentParentProperties.Inherit Then
			Break;
		EndIf;
		
		CurrentParentProperties = ParentProperties(CurrentParentProperties.Ref);
	EndDo;
	
	Return NewRecords;
	
EndFunction

Function SettingsInheritance(Ref) Export
	
	Query = New Query;
	Query.SetParameter("Ref", Ref);
	
	Query.Text =
	"SELECT
	|	SettingsInheritance.Inherit
	|FROM
	|	InformationRegister.ObjectRightsSettingsInheritance AS SettingsInheritance
	|WHERE
	|	SettingsInheritance.Object = &Ref
	|	AND SettingsInheritance.Parent = &Ref";
	
	Selection = Query.Execute().Select();
	
	Return ?(Selection.Next(), Selection.Inherit, True);
	
EndFunction

Function ParentProperties(Ref)
	
	Query = New Query;
	Query.SetParameter("Ref", Ref);
	Query.Text =
	"SELECT
	|	CurrentTable.Parent
	|INTO RefParent
	|FROM
	|	ObjectTable AS CurrentTable
	|WHERE
	|	CurrentTable.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RefParent.Parent
	|FROM
	|	RefParent AS RefParent
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Parents.Inherit AS Inherit
	|FROM
	|	InformationRegister.ObjectRightsSettingsInheritance AS Parents
	|WHERE
	|	Parents.Object = Parents.Parent
	|	AND Parents.Object IN
	|			(SELECT
	|				RefParent.Parent
	|			FROM
	|				RefParent AS RefParent)";
	
	Query.Text = StrReplace(Query.Text, "ObjectTable", Ref.Metadata().FullName());
	
	QueryResults = Query.ExecuteBatch();
	Selection    = QueryResults[1].Select();
	Parent       = ?(Selection.Next(), Selection.Parent, Undefined);
	
	Selection    = QueryResults[2].Select();
	Inherit      = ?(Selection.Next(), Selection.Inherit, True);
	
	Return New Structure("Ref, Inherit", Parent, Inherit);
	
EndFunction

#EndRegion

#EndIf
