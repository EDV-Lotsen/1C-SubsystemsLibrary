#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalInterface

// Updates available rights for object rights settings, and stores content of the latest changes.
// 
// Parameters:
//  HasChanges - Boolean (return value) - True if changes are found,
//                   undefined otherwise.
//
Procedure UpdateAvailableRightsForObjectRightSetup(HasChanges = Undefined, CheckOnly = False) Export
	
	If CheckOnly Or ExclusiveMode() Then
		DisableExclusiveMode = False;
	Else
		DisableExclusiveMode = True;
		SetExclusiveMode(True);
	EndIf;
	
	AvailableRights = AvailableRights();
	
	DataLock = New DataLock;
	LockItem = DataLock.Add("Constant.AccessRestrictionParameters");
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		DataLock.Lock();
		
		Parameters = StandardSubsystemsServer.ApplicationParameters(
			"AccessRestrictionParameters");
		
		Saved = Undefined;
		
		If Parameters.Property("AvailableRightsForObjectRightsSettings") Then
			Saved = Parameters.AvailableRightsForObjectRightsSettings;
			
			If Not CommonUse.IsEqualData(AvailableRights, Saved) Then
				Saved = Undefined;
			EndIf;
		EndIf;
		
		SetPrivilegedMode(True);
		
		If Saved = Undefined Then
			HasChanges = True;
			If CheckOnly Then
				CommitTransaction();
				Return;
			EndIf;
			StandardSubsystemsServer.SetApplicationParameter(
				"AccessRestrictionParameters",
				"AvailableRightsForObjectRightsSettings",
				AvailableRights);
		EndIf;
		
		StandardSubsystemsServer.ConfirmApplicationParametersUpdate(
			"AccessRestrictionParameters",
			"AvailableRightsForObjectRightsSettings");
		
		If Not CheckOnly Then
			StandardSubsystemsServer.AddApplicationParameterChanges(
				"AccessRestrictionParameters",
				"AvailableRightsForObjectRightsSettings",
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

// Updates the auxiliary register data after changing rights
// based on access values saved in the access restriction parameters.
//
Procedure UpdateConfigurationChangesAuxiliaryRegisterData() Export
	
	SetPrivilegedMode(True);
	
	Parameters = AccessManagementInternalCached.Parameters();
	
	LastChanges = StandardSubsystemsServer.ApplicationParameterChanges(
		Parameters, "AvailableRightsForObjectRightsSettings");
		
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
		UpdateAuxiliaryRegisterData();
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// Returns the object rights settings.
//
// Parameters:
//  ObjectRef - reference to an object.
//
// Returns value:
//  Structure
//    Inherit        - Boolean  - flag specifying whether the parent rights settings are inherited.
//     Settings          - ValueTable
//                         - SettingsOwner        - reference to an object or object parent 
//                                                  (from the object parent hierarchy)
//                         - InheritanceIsAllowed - Boolean - inheritance is allowed
//                         - User                 - CatalogRef.Users
//                                                   CatalogRef.UserGroups
//                                                   CatalogRef.ExternalUsers
//                                                   CatalogRef.ExternalUserGroups
//                         - <RightName1>           - Undefined, Boolean
//                                                       Undefined  - right is undefined,
//                                                       True       - allowed
//                                                       False      - prohibited
//                         - <RightName2>           - ...
//
Function Read(Val ObjectRef) Export
	
	AvailableRights = AccessManagementInternalCached.Parameters(
		).AvailableRightsForObjectRightsSettings;
	
	RightDescription = AvailableRights.ByTypes.Get(TypeOf(ObjectRef));
	
	If RightDescription = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Error in InformationRegisters.ObjectRightsSettings.Read()procedure.
			           |
			           |Invalid %1 ObjectRef parameter value.
			           |The rights cannot be set up for objects in %2 table.'"),
			String(ObjectRef),
			ObjectRef.Metadata().FullName());
	EndIf;
	
	RightsSettings = New Structure;
	
	// Getting the inheritance settings value
	RightsSettings.Insert("Inherit",
		InformationRegisters.ObjectRightsSettingsInheritance.SettingsInheritance(ObjectRef));
	
	// Preparing the rights settings table structure
	Settings = New ValueTable;
	Settings.Columns.Add("User");
	Settings.Columns.Add("SettingsOwner");
	Settings.Columns.Add("InheritanceIsAllowed", New TypeDescription("Boolean"));
	Settings.Columns.Add("ParentSettings",       New TypeDescription("Boolean"));
	For Each RightDetails In RightDescription Do
		Settings.Columns.Add(RightDetails.Key);
	EndDo;
	
	If AvailableRights.HierarchicalTables.Get(TypeOf(ObjectRef)) = Undefined Then
		SettingsInheritance = AccessManagementInternalCached.EmptyRecordSetTable(
			"InformationRegister.ObjectRightsSettingsInheritance").Copy();
		NewRow = SettingsInheritance.Add();
		SettingsInheritance.Columns.Add("Level", New TypeDescription("Number"));
		NewRow.Object   = ObjectRef;
		NewRow.Parent = ObjectRef;
	Else
		SettingsInheritance = InformationRegisters.ObjectRightsSettingsInheritance.ObjectParents(
			ObjectRef, , , False);
	EndIf;
	
	// Reading the object settings and the settings of parent objects inherited by the object
	Query = New Query;
	Query.SetParameter("Object", ObjectRef);
	Query.SetParameter("SettingsInheritance", SettingsInheritance);
	Query.Text =
	"SELECT
	|	SettingsInheritance.Object,
	|	SettingsInheritance.Parent,
	|	SettingsInheritance.Level
	|INTO SettingsInheritance
	|FROM
	|	&SettingsInheritance AS SettingsInheritance
	|
	|INDEX BY
	|	SettingsInheritance.Object,
	|	SettingsInheritance.Parent
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SettingsInheritance.Parent AS SettingsOwner,
	|	ObjectRightsSettings.User AS User,
	|	ObjectRightsSettings.Right AS _Right,
	|	CASE
	|		WHEN SettingsInheritance.Parent <> &Object
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ParentSettings,
	|	ObjectRightsSettings.RightIsProhibited AS RightIsProhibited,
	|	ObjectRightsSettings.InheritanceIsAllowed AS InheritanceIsAllowed
	|FROM
	|	InformationRegister.ObjectRightsSettings AS ObjectRightsSettings
	|		INNER JOIN SettingsInheritance AS SettingsInheritance
	|		ON ObjectRightsSettings.Object = SettingsInheritance.Parent
	|WHERE
	|	Not(SettingsInheritance.Parent <> &Object
	|				AND ObjectRightsSettings.InheritanceIsAllowed <> TRUE)
	|
	|ORDER BY
	|	ParentSettings DESC,
	|	SettingsInheritance.Level,
	|	ObjectRightsSettings.SettingsOrder";
	Table = Query.Execute().Unload();
	
	Table.Columns._Right.Name = "Right";
	
	CurrentOwnerSettings = Undefined;
	CurrentUser = Undefined;
	For Each Row In Table Do
		If CurrentOwnerSettings <> Row.SettingsOwner
		 Or CurrentUser <> Row.User Then
			CurrentOwnerSettings = Row.SettingsOwner;
			CurrentUser      = Row.User;
			Settings = Settings.Add();
			Settings.User      = Row.User;
			Settings.SettingsOwner = Row.SettingsOwner;
			Settings.ParentSettings = Row.ParentSettings;
		EndIf;
		If Settings.Columns.Find(Row.Right) = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error in InformationRegisters.ObjectRightsSettings.Read()procedure.
				           |
				           |For objects in table %1,
				           |right %2 cannot be set up, but it is recorded
				           |in the ObjectRightsSettings information register
				           |for object %3.
				           |
				           |The infobase may not be updated
				           |or updated incorrectly.
				           |Register data must be repaired.'"),
				ObjectRef.Metadata().FullName(),
				Row.Right,
				String(ObjectRef));
		EndIf;
		Settings.InheritanceIsAllowed = Settings.InheritanceIsAllowed Or Row.InheritanceIsAllowed;
		Settings[Row.Right] = Not Row.RightIsProhibited;
	EndDo;
	
	RightsSettings.Insert("Settings", Settings);
	
	Return RightsSettings;
	
EndFunction

// Writes the object right settings.
//
// Parameters:
//  Inherit  - Boolean - flag specifying whether the parent rights settings are inherited.
//  Settings - ValueTable containing structure returned by Read().
//             Only the rows with SettingsOwner = ObjectRef are written.
//
Procedure Write(Val ObjectRef, Val Settings, Val Inherit) Export
	
	AvailableRights = AccessManagementInternalCached.Parameters(
		).AvailableRightsForObjectRightsSettings;
	
	RightDescription = AvailableRights.ByRefTypes.Get(TypeOf(ObjectRef));
	
	If RightDescription = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Error in InformationRegisters.ObjectRightsSettings.Read()procedure.
			           |
			           |Invalid %1 ObjectRef parameter value.
			           |The rights cannot be set up for objects in %2 table.'"),
			String(ObjectRef),
			ObjectRef.Metadata().FullName());
	EndIf;
	
	// Setting the inheritance settings flag
	RecordSet = InformationRegisters.ObjectRightsSettingsInheritance.CreateRecordSet();
	RecordSet.Filter.Object.Set(ObjectRef);
	RecordSet.Filter.Parent.Set(ObjectRef);
	RecordSet.Read();
	
	If RecordSet.Count() = 0 Then
		ChangedInheritance = True;
		NewRecord = RecordSet.Add();
		NewRecord.Object  = ObjectRef;
		NewRecord.Parent  = ObjectRef;
		NewRecord.Inherit = Inherit;
	Else
		ChangedInheritance = RecordSet[0].Inherit <> Inherit;
		RecordSet[0].Inherit = Inherit;
	EndIf;
	
	// Preparing new settings
	NewRightSettings = AccessManagementInternalCached.EmptyRecordSetTable(
		"InformationRegister.ObjectRightsSettings").Copy();
	
	CommonRightTable = Catalogs.MetadataObjectIDs.EmptyRef();
	
	Filter = New Structure("SettingsOwner", ObjectRef);
	SettingsOrder = 0;
	For Each Settings In Settings.FindRows(Filter) Do
		For Each RightDetails In RightDescription Do
			If TypeOf(Settings[RightDetails.Name]) <> Type("Boolean") Then
				Continue;
			EndIf;
			SettingsOrder = SettingsOrder + 1;
			
			RightSetting = NewRightSettings.Add();
			RightSetting.SettingsOrder        = SettingsOrder;
			RightSetting.Object               = ObjectRef;
			RightSetting.User                 = Settings.User;
			RightSetting.Right                = RightDetails.Name;
			RightSetting.RightIsProhibited    = Not Settings[RightDetails.Name];
			RightSetting.InheritanceIsAllowed = Settings.InheritanceIsAllowed;
			// Cache attributes
			RightSetting.RightPermissionLevel =
				?(RightSetting.RightIsProhibited, 0, ?(RightSetting.InheritanceIsAllowed, 2, 1));
			RightSetting.RightProhibitionLevel =
				?(RightSetting.RightIsProhibited, ?(RightSetting.InheritanceIsAllowed, 2, 1), 0);
			
			AddedIndividualTableSettings = False;
			For Each KeyAndValue In AvailableRights.SeparateTables Do
				SeparateTable = KeyAndValue.Key;
				ReadTable     = RightDetails.ReadInTables.Find(   SeparateTable) <> Undefined;
				TableChange   = RightDetails.ChangeInTables.Find(SeparateTable) <> Undefined;
				If Not ReadTable And Not TableChange Then
					Continue;
				EndIf;
				AddedIndividualTableSettings = True;
				TableRightsSettings = NewRightSettings.Add();
				FillPropertyValues(TableRightsSettings, RightSetting);
				TableRightsSettings.Table = SeparateTable;
				If ReadTable Then
					TableRightsSettings.ReadingPermissionLevel  = RightSetting.RightPermissionLevel;
					TableRightsSettings.ReadingProhibitionLevel = RightSetting.RightProhibitionLevel;
				EndIf;
				If TableChange Then
					TableRightsSettings.ChangingPermissionLevel  = RightSetting.RightPermissionLevel;
					TableRightsSettings.ChangingProhibitionLevel = RightSetting.RightProhibitionLevel;
				EndIf;
			EndDo;
			
			CommonRead   = RightDetails.ReadInTables.Find(CommonRightTable) <> Undefined;
			CommonChange = RightDetails.ChangeInTables.Find(CommonRightTable) <> Undefined;
			
			If Not CommonRead And Not CommonChange And AddedIndividualTableSettings Then
				NewRightSettings.Delete(RightSetting);
			Else
				If CommonRead Then
					RightSetting.ReadingPermissionLevel  = RightSetting.RightPermissionLevel;
					RightSetting.ReadingProhibitionLevel = RightSetting.RightProhibitionLevel;
				EndIf;
				If CommonChange Then
					RightSetting.ChangingPermissionLevel  = RightSetting.RightPermissionLevel;
					RightSetting.ChangingProhibitionLevel = RightSetting.RightProhibitionLevel;
				EndIf;
			EndIf;
		EndDo;
	EndDo;
	
	// Writing the object rights settings and the rights settings inheritance flag
	BeginTransaction();
	Try
		HasChanges = False;
		
		AccessManagementInternal.UpdateRecordSet(
			InformationRegisters.ObjectRightsSettings,
			NewRightSettings,
			,
			"Object",
			ObjectRef,
			HasChanges);
			
		If HasChanges Then
			ObjectsWithChanges = New Array;
		Else
			ObjectsWithChanges = Undefined;
		EndIf;
		
		If ChangedInheritance Then
			RecordSet.Write();
			InformationRegisters.ObjectRightsSettingsInheritance.UpdateOwnerParents(
				ObjectRef, , True, ObjectsWithChanges);
		EndIf;
		
		If ObjectsWithChanges <> Undefined Then
			AddHierarchyObjects(ObjectRef, ObjectsWithChanges);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Updates the auxiliary register data when changing configuration.
// 
// Parameters:
//  HasChanges - Boolean (return value) - True if data is changed;
//                                        undefined otherwise.
//
Procedure UpdateAuxiliaryRegisterData(HasChanges = Undefined) Export
	
	SetPrivilegedMode(True);
	
	AvailableRights = AccessManagementInternalCached.Parameters().AvailableRightsForObjectRightsSettings;
	
	RightTables = New ValueTable;
	RightTables.Columns.Add("RightOwner", Metadata.InformationRegisters.ObjectRightsSettings.Dimensions.Object.Type);
	RightTables.Columns.Add("Right",        Metadata.InformationRegisters.ObjectRightsSettings.Dimensions.Right.Type);
	RightTables.Columns.Add("Table",      Metadata.InformationRegisters.ObjectRightsSettings.Dimensions.Table.Type);
	RightTables.Columns.Add("Read",      New TypeDescription("Boolean"));
	RightTables.Columns.Add("Update",    New TypeDescription("Boolean"));
	
	EmptyReferencesRightOwner = AccessManagementInternalCached.EmptyRefMappingToSpecifiedRefTypes(
		"InformationRegister.ObjectRightsSettings.Dimension.Object");
	
	Filter = New Structure;
	For Each KeyAndValue In AvailableRights.ByRefTypes Do
		RightOwnerType = KeyAndValue.Key;
		RightDescription     = KeyAndValue.Value;
		
		If EmptyReferencesRightOwner.Get(RightOwnerType) = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error in
				           |UpdateAuxiliaryRegisterData procedure of
                 |ObjectRightsSettings information register module manager.
				           |
				           |Rights owner type %1 is not specified in Object dimension.'"),
				RightOwnerType);
		EndIf;
		
		Filter.Insert("RightOwner", EmptyReferencesRightOwner.Get(RightOwnerType));
		For Each RightDetails In RightDescription Do
			Filter.Insert("Right", RightDetails.Name);
			
			For Each Table In RightDetails.ReadInTables Do
				Row = RightTables.Add();
				FillPropertyValues(Row, Filter);
				Row.Table = Table;
				Row.Read = True;
			EndDo;
			
			For Each Table In RightDetails.ChangeInTables Do
				Filter.Insert("Table", Table);
				Rows = RightTables.FindRows(Filter);
				If Rows.Count() = 0 Then
					Row = RightTables.Add();
					FillPropertyValues(Row, Filter);
				Else
					Row = Rows[0];
				EndIf;
				Row.Update = True;
			EndDo;
		EndDo;
	EndDo;
	
	TemporaryTableQueryText =
	"SELECT
	|	RightTables.RightOwner,
	|	RightTables.Right AS _Right,
	|	RightTables.Table,
	|	RightTables.Read,
	|	RightTables.Update
	|INTO RightTables
	|FROM
	|	&RightTables AS RightTables
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RightsSettings.Object AS Object,
	|	RightsSettings.User AS User,
	|	RightsSettings.Right AS _Right,
	|	MAX(RightsSettings.RightIsProhibited) AS RightIsProhibited,
	|	MAX(RightsSettings.InheritanceIsAllowed) AS InheritanceIsAllowed,
	|	MAX(RightsSettings.SettingsOrder) AS SettingsOrder
	|INTO RightsSettings
	|FROM
	|	InformationRegister.ObjectRightsSettings AS RightsSettings
	|
	|GROUP BY
	|	RightsSettings.Object,
	|	RightsSettings.User,
	|	RightsSettings.Right
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RightsSettings.Object,
	|	RightsSettings.User,
	|	RightsSettings._Right,
	|	ISNULL(RightTables.Table, VALUE(Catalog.MetadataObjectIDs.EmptyRef)) AS Table,
	|	RightsSettings.RightIsProhibited,
	|	RightsSettings.InheritanceIsAllowed,
	|	RightsSettings.SettingsOrder,
	|	CASE
	|		WHEN RightsSettings.RightIsProhibited
	|			THEN 0
	|		WHEN RightsSettings.InheritanceIsAllowed
	|			THEN 2
	|		ELSE 1
	|	END AS RightPermissionLevel,
	|	CASE
	|		WHEN Not RightsSettings.RightIsProhibited
	|			THEN 0
	|		WHEN RightsSettings.InheritanceIsAllowed
	|			THEN 2
	|		ELSE 1
	|	END AS RightProhibitionLevel,
	|	CASE
	|		WHEN Not ISNULL(RightTables.Read, FALSE)
	|			THEN 0
	|		WHEN RightsSettings.RightIsProhibited
	|			THEN 0
	|		WHEN RightsSettings.InheritanceIsAllowed
	|			THEN 2
	|		ELSE 1
	|	END AS ReadingPermissionLevel,
	|	CASE
	|		WHEN Not ISNULL(RightTables.Read, FALSE)
	|			THEN 0
	|		WHEN Not RightsSettings.RightIsProhibited
	|			THEN 0
	|		WHEN RightsSettings.InheritanceIsAllowed
	|			THEN 2
	|		ELSE 1
	|	END AS ReadingProhibitionLevel,
	|	CASE
	|		WHEN Not ISNULL(RightTables.Update, FALSE)
	|			THEN 0
	|		WHEN RightsSettings.RightIsProhibited
	|			THEN 0
	|		WHEN RightsSettings.InheritanceIsAllowed
	|			THEN 2
	|		ELSE 1
	|	END AS ChangingPermissionLevel,
	|	CASE
	|		WHEN Not ISNULL(RightTables.Update, FALSE)
	|			THEN 0
	|		WHEN Not RightsSettings.RightIsProhibited
	|			THEN 0
	|		WHEN RightsSettings.InheritanceIsAllowed
	|			THEN 2
	|		ELSE 1
	|	END AS ChangingProhibitionLevel
	|INTO NewData
	|FROM
	|	RightsSettings AS RightsSettings
	|		LEFT JOIN RightTables AS RightTables
	|		ON (VALUETYPE(RightsSettings.Object) = VALUETYPE(RightTables.RightOwner))
	|			AND RightsSettings._Right = RightTables._Right
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP RightTables
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP RightsSettings";
	
	QueryText =
	"SELECT
	|	NewData.Object,
	|	NewData.User,
	|	NewData._Right,
	|	NewData.Table,
	|	NewData.RightIsProhibited,
	|	NewData.InheritanceIsAllowed,
	|	NewData.SettingsOrder,
	|	NewData.RightPermissionLevel,
	|	NewData.RightProhibitionLevel,
	|	NewData.ReadingPermissionLevel,
	|	NewData.ReadingProhibitionLevel,
	|	NewData.ChangingPermissionLevel,
	|	NewData.ChangingProhibitionLevel,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	NewData AS NewData";
	
	// Preparing selected fields with optional filtering
	Fields = New Array;
	Fields.Add(New Structure("Object"));
	Fields.Add(New Structure("User"));
	Fields.Add(New Structure("Right"));
	Fields.Add(New Structure("Table"));
	Fields.Add(New Structure("RightIsProhibited"));
	Fields.Add(New Structure("InheritanceIsAllowed"));
	Fields.Add(New Structure("SettingsOrder"));
	Fields.Add(New Structure("RightPermissionLevel"));
	Fields.Add(New Structure("RightProhibitionLevel"));
	Fields.Add(New Structure("ReadingPermissionLevel"));
	Fields.Add(New Structure("ReadingProhibitionLevel"));
	Fields.Add(New Structure("ChangingPermissionLevel"));
	Fields.Add(New Structure("ChangingProhibitionLevel"));
	
	Query = New Query;
	Query.SetParameter("RightTables", RightTables);
	
	Query.Text = AccessManagementInternal.ChangeSelectionQueryText(
		QueryText, Fields, "InformationRegister.ObjectRightsSettings", TemporaryTableQueryText);
	
	DataLock = New DataLock;
	LockItem = DataLock.Add("InformationRegister.ObjectRightsSettings");
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		DataLock.Lock();
		Query.Text = StrReplace(Query.Text, "AllRows.Right,", "AllRows._Right,");
		Query.Text = StrReplace(Query.Text, "OldData.Right,", "OldData.Right AS _Right,");
		Changes = Query.Execute().Unload();
		Changes.Columns._Right.Name = "Right";
		
		AccessManagementInternal.UpdateInformationRegister(
			InformationRegisters.ObjectRightsSettings, Changes, HasChanges);
			
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions

Procedure AddHierarchyObjects(Ref, ObjectArray)
	
	Query = New Query;
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("ObjectArray", ObjectArray);
	
	Query.Text = StrReplace(
	"SELECT
	|	TableWithHierarchy.Ref
	|FROM
	|	ObjectTable AS TableWithHierarchy
	|WHERE
	|	TableWithHierarchy.Ref IN HIERARCHY(&Ref)
	|	AND Not TableWithHierarchy.Ref IN (&ObjectArray)",
	"ObjectTable",
	Ref.Metadata().FullName());
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		ObjectArray.Add(Selection.Ref);
	EndDo;
	
EndProcedure

// Returns the table of available rights that can be applied to objects
// of specified types. The table is created using the procedure prepared
// by the applied developer using OnFillAvailableRightsForObjectRightsSettings
// in the AccessManagementOverridable common module.
//
// Returns:
//  ValueTable
//   RightOwner   - String - full name of the access value table, 
//   Name         - String - right ID, for example, FolderChange.
//                  The RightsManagement right must be set for common right settings form.
//                  Access rights and Rights management - this is the right to change rights
//                  by the owner which is checked when you open 
//                  InformationRegister.ObjectRightsSettings.Form.ObjectRightsSettings;
//   Title        - String - the right title. For example, the title of
//                  the ObjectRightsSettings form is:
//                  "Change
//                  |folders".
//   Tooltip      - String - tooltip for the right title. For example, "Adding, changing, and 
//                  marking folders for deletion".
//   InitialValue - Boolean - initial value of right flag when adding a new row 
//                  to the "Rights by access values" form.
//   RequiredRights - Array of String  - names of rights required by this right.
//                  For example, FileChanging right is required by FileAdding right.
//   ReadInTables - Array of String - full names of tables for which this right implies Read right.
//                  It can take on the asterisk ("*" character) as a value,
//                  which means "any table". 
//                  As Read right can depend only on Read rights,
//                  the asterisk should be used (required for access restriction templates).
//   ChangeInTables - Array of String - full names of tables for which this right
//                  implies Update right.
//                  It can take on the asterisk ("*" character) as a value, meaning
//                  "any table" (required for access restriction templates).
//
Function AvailableRights()
	
	AvailableRights = New ValueTable();
	AvailableRights.Columns.Add("RightOwner",     New TypeDescription("String"));
	AvailableRights.Columns.Add("Name",           New TypeDescription("String", , New StringQualifiers(60)));
	AvailableRights.Columns.Add("Title",          New TypeDescription("String", , New StringQualifiers(60)));
	AvailableRights.Columns.Add("Tooltip",        New TypeDescription("String", , New StringQualifiers(150)));
	AvailableRights.Columns.Add("InitialValue",   New TypeDescription("Boolean,Number"));
	AvailableRights.Columns.Add("RequiredRights", New TypeDescription("Array"));
	AvailableRights.Columns.Add("ReadInTables",   New TypeDescription("Array"));
	AvailableRights.Columns.Add("ChangeInTables", New TypeDescription("Array"));
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.AccessManagement\OnFillAvailableRightsForObjectRightsSettings");
	
	For Each Handler In EventHandlers Do
		Handler.Module.OnFillAvailableRightsForObjectRightsSettings(AvailableRights);
	EndDo;
	
	AccessManagementOverridable.OnFillAvailableRightsForObjectRightsSettings(AvailableRights);
	
	ErrorTitle =
		NStr("en = 'Error in
 |the OnFillAvailableRightsForObjectRightsSettings procedure of the AccessManagementOverridable common module.'")
		+ Chars.LF
		+ Chars.LF;
	
	ByTypes            = New Map;
	ByRefTypes         = New Map;
	ByFullNames        = New Map;
	OwnerTypes         = New Array;
	SeparateTables     = New Map;
	HierarchicalTables = New Map;
	
	RightOwnersDefinedType  = AccessManagementInternalCached.TableFieldTypes("DefinedType.RightsSettingsOwner");
	AccessValuesDefinedType = AccessManagementInternalCached.TableFieldTypes("DefinedType.AccessValue");
	
	AccessKindsProperties = StandardSubsystemsServer.ApplicationParameters(
		"AccessRestrictionParameters").AccessKindsProperties;
	
	SubscriptionTypesRefreshAccessValuesGroups = AccessManagementInternalCached.ObjectTypesInEventSubscriptions(
		"UpdateAccessValueGroups");
	
	SubscriptionTypesWriteAccessValueSets = AccessManagementInternalCached.ObjectTypesInEventSubscriptions(
		"WriteAccessValueSets");
	
	SubscriptionTypesWriteDependentAccessValueSets = AccessManagementInternalCached.ObjectTypesInEventSubscriptions(
		"WriteDependentAccessValueSets");
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("RightOwner");
	AdditionalParameters.Insert("CommonOwnerRights", New Map);
	AdditionalParameters.Insert("IndividualOwnerRights", New Map);
	
	OwnerRightsIndexes = New Map;
	
	For Each PossibleRight In AvailableRights Do
		OwnerMetadataObject = Metadata.FindByFullName(PossibleRight.RightOwner);
		
		If OwnerMetadataObject = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				ErrorTitle + NStr("en = 'The rights owner ""%1"" is not found.'"),
				PossibleRight.RightOwner);
		EndIf;
		
		AdditionalParameters.RightOwner = PossibleRight.RightOwner;
		
		FillIDs("ReadInTables",    PossibleRight, ErrorTitle, SeparateTables, AdditionalParameters);
		FillIDs("ChangeInTables", PossibleRight, ErrorTitle, SeparateTables, AdditionalParameters);
		
		OwnerRights = ByFullNames[PossibleRight.RightOwner];
		If OwnerRights = Undefined Then
			OwnerRights = New Map;
			OwnerRightArray = New Array;
			
			RefType = StandardSubsystemsServer.MetadataObjectReferenceOrMetadataObjectRecordKeyType(
				OwnerMetadataObject);
			
			ObjectType = StandardSubsystemsServer.MetadataObjectOrMetadataObjectRecordSetType(
				OwnerMetadataObject);
			
			If RightOwnersDefinedType.Get(RefType) = Undefined Then
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					ErrorTitle +
					NStr("en = 'Right owner type %1
					           |is not specified in ""Rights settings owner"" type.'"),
					String(RefType));
			EndIf;
			
			If (SubscriptionTypesWriteDependentAccessValueSets.Get(ObjectType) <> Undefined
			      Or SubscriptionTypesWriteAccessValueSets.Get(ObjectType) <> Undefined)
			    And AccessValuesDefinedType.Get(RefType) = Undefined Then
				
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					ErrorTitle +
					NStr("en = 'Right owner type %1
					           |is not specified in the
					           |""Access value"" type but used to fill
					           |the access value sets, because it is specified
					           |in a subscription to one of these events:
					           |- WriteDependentAccessValueSets*,
                   |- WriteAccessValueSets*.
					           |You must specify the type in the ""Access value"" 
					           |in order to fill the AccessValueSets register correctly.'"),
					String(RefType));
			EndIf;
			
			If AccessKindsProperties.ByValueTypes.Get(RefType) <> Undefined Then
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					ErrorTitle +
					NStr("en = 'Rights owner type %1
					           |cannot be used as an access value type,
					           |but it is found in the description of access type %2.'"),
					String(RefType),
					AccessKindsProperties.ByValueTypes.Get(RefType).Name);
			EndIf;
			
			If AccessKindsProperties.ByGroupTypesAndValues.Get(RefType) <> Undefined Then
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					ErrorTitle +
					NStr("en = 'Rights owner type %1
					           |cannot be used as an access value group type,
					           |but it is found in the description of access type %2.'"),
					String(RefType),
					AccessKindsProperties.ByValueTypes.Get(RefType).Name);
			EndIf;
			
			If SubscriptionTypesRefreshAccessValuesGroups.Get(ObjectType) = Undefined Then
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					ErrorTitle +
					NStr("en = 'Rights owner type %1
					           |is not specified in the ""Update access value groups"" event subscription.'"),
					String(ObjectType));
			EndIf;
			
			ByFullNames.Insert(PossibleRight.RightOwner, OwnerRights);
			ByRefTypes.Insert(RefType,  OwnerRightArray);
			ByTypes.Insert(RefType,  OwnerRights);
			ByTypes.Insert(ObjectType, OwnerRights);
			HierarchicalTables.Insert(RefType,  HierarchicalMetadataObject(OwnerMetadataObject));
			HierarchicalTables.Insert(ObjectType, HierarchicalMetadataObject(OwnerMetadataObject));
			
			OwnerTypes.Add(CommonUse.ObjectManagerByFullName(
				PossibleRight.RightOwner).EmptyRef());
				
			OwnerRightsIndexes.Insert(PossibleRight.RightOwner, 0);
		EndIf;
		
		If OwnerRights.Get(PossibleRight.Name) <> Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				ErrorTitle +
				NStr("en = 'For rights owner %1,
				           |right %2 is redefined.'"),
				PossibleRight.RightOwner,
				PossibleRight.Name);
		EndIf;
		
		// Converting the list of required rights to arrays
		Separator = "|";
		For Index = 0 To PossibleRight.RequiredRights.Count()-1 Do
			If Find(PossibleRight.RequiredRights[Index], Separator) > 0 Then
				PossibleRight.RequiredRights[Index] =
					StringFunctionsClientServer.SplitStringIntoSubstringArray(
						PossibleRight.RequiredRights[Index],
						Separator);
			EndIf;
		EndDo;
		
		PossibleRightProperties = New Structure(
			"RightOwner,
			|Name,
			|Title,
			|ToolTip,
			|InitialValue,
			|RequiredRights,
			|ReadInTables,
			|ChangeInTables,
			|RightIndex");
		FillPropertyValues(PossibleRightProperties, PossibleRight);
		PossibleRightProperties.RightIndex = OwnerRightsIndexes[PossibleRight.RightOwner];
		OwnerRightsIndexes[PossibleRight.RightOwner] = PossibleRightProperties.RightIndex + 1;
		
		OwnerRights.Insert(PossibleRight.Name, PossibleRightProperties);
		OwnerRightArray.Add(PossibleRightProperties);
	EndDo;
	
	// Adding individual tables
	CommonTable = Catalogs.MetadataObjectIDs.EmptyRef();
	For Each RightDescription In ByFullNames Do
		CertainRights = AdditionalParameters.IndividualOwnerRights.Get(RightDescription.Key);
		For Each RightDetails In RightDescription.Value Do
			RightProperties = RightDetails.Value;
			If RightProperties.ChangeInTables.Find(CommonTable) <> Undefined Then
				For Each KeyAndValue In SeparateTables Do
					SeparateTable = KeyAndValue.Key;
					
					If CertainRights.ChangeInTables[SeparateTable] = Undefined
					   And RightProperties.ChangeInTables.Find(SeparateTable) = Undefined Then
					
						RightProperties.ChangeInTables.Add(SeparateTable);
					EndIf;
				EndDo;
			EndIf;
		EndDo;
	EndDo;
	
	AvailableRights = New Structure;
	AvailableRights.Insert("ByTypes",                   ByTypes);
	AvailableRights.Insert("ByRefTypes",                ByRefTypes);
	AvailableRights.Insert("ByFullNames",               ByFullNames);
	AvailableRights.Insert("OwnerTypes",                OwnerTypes);
	AvailableRights.Insert("SeparateTables",            SeparateTables);
	AvailableRights.Insert("HierarchicalTables",        HierarchicalTables);
	
	Return CommonUse.FixedData(AvailableRights);
	
EndFunction

Procedure FillIDs(Property, PossibleRight, ErrorTitle, SeparateTables, AdditionalParameters)
	
	If AdditionalParameters.CommonOwnerRights.Get(AdditionalParameters.RightOwner) = Undefined Then
		GeneralRights = New Structure("ReadInTables, ChangeInTables", "", "");
		CertainRights = New Structure("ReadInTables, ChangeInTables", New Map, New Map);
		
		AdditionalParameters.CommonOwnerRights.Insert(AdditionalParameters.RightOwner, GeneralRights);
		AdditionalParameters.IndividualOwnerRights.Insert(AdditionalParameters.RightOwner, CertainRights);
	Else
		GeneralRights = AdditionalParameters.CommonOwnerRights.Get(AdditionalParameters.RightOwner);
		CertainRights = AdditionalParameters.IndividualOwnerRights.Get(AdditionalParameters.RightOwner);
	EndIf;
	
	Array = New Array;
	
	For Each Value In PossibleRight[Property] Do
		
		If Value = "*" Then
			If PossibleRight[Property].Count() <> 1 Then
				
				If Property = "ReadInTables" Then
					ErrorDescription = NStr("en = 'For the rights owner %1,
					                            |asterisk is specified in read tables for right %2.
					                            |In this case you do not need to specify the individual tables.'")
				Else
					ErrorDescription = NStr("en = 'For rights owner
					                            |""%1"" for right ""%2"" in tables for changes character ""*"" is specified.
					                            |In this case you don''t need to specify the individual tables.'")
				EndIf;
				
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					ErrorTitle + ErrorDescription,
					AdditionalParameters.RightOwner,
					PossibleRight.Name);
			EndIf;
			
			If ValueIsFilled(GeneralRights[Property]) Then
				
				If Property = "ReadInTables" Then
					ErrorDescription = NStr("en = 'For the rights owner %1,
					                            |asterisk is specified in read tables for right %2.
					                            |However, asterisk is already specified in read tables for right %3.'")
				Else
					ErrorDescription = NStr("en = 'For the rights owner %1,
					                            |asterisk is specified in change tables for right %2.
					                            |However, asterisk is already specified in change tables for right %3.'")
				EndIf;
				
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					ErrorTitle + ErrorDescription,
					AdditionalParameters.RightOwner,
					PossibleRight.Name,
					GeneralRights[Property]);
			Else
				GeneralRights[Property] = PossibleRight.Name;
			EndIf;
			
			Array.Add(Catalogs.MetadataObjectIDs.EmptyRef());
			
		ElsIf Property = "ReadInTables" Then
			ErrorDescription =
				NStr("en = 'For rights owner %1
				           |read table %3 is specified for right %2.
				           |This does not make sense as Read right can depend only on Read right.
				           |Asterisk should be used here instead.'");
				
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				ErrorTitle + ErrorDescription,
				AdditionalParameters.RightOwner,
				PossibleRight.Name,
				Value);
			
		ElsIf Metadata.FindByFullName(Value) = Undefined Then
			
			If Property = "ReadInTables" Then
				ErrorDescription = NStr("en = 'For the rights owner %1,
				                            |read table %3 is not found for right %2.'")
			Else
				ErrorDescription = NStr("en = 'For the rights owner %1,
				                            |change table %3 is not found for right %2.'")
			EndIf;
			
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				ErrorTitle + ErrorDescription,
				AdditionalParameters.RightOwner,
				PossibleRight.Name,
				Value);
		Else
			TableID = CommonUse.MetadataObjectID(Value);
			Array.Add(TableID);
			
			SeparateTables.Insert(TableID, Value);
			CertainRights[Property].Insert(TableID, PossibleRight.Name);
		EndIf;
		
	EndDo;
	
	PossibleRight[Property] = Array;
	
EndProcedure

Function HierarchicalMetadataObject(MetadataObjectName)
	
	If TypeOf(MetadataObjectName) = Type("String") Then
		MetadataObject = Metadata.FindByFullName(MetadataObjectName);
	ElsIf TypeOf(MetadataObjectName) = Type("Type") Then
		MetadataObject = Metadata.FindByType(MetadataObjectName);
	Else
		MetadataObject = MetadataObjectName;
	EndIf;
	
	If TypeOf(MetadataObject) <> Type("MetadataObject") Then
		Return False;
	EndIf;
	
	If Not Metadata.Catalogs.Contains(MetadataObject) Then
		Return False;
	EndIf;
	
	If Not Metadata.ChartsOfCharacteristicTypes.Contains(MetadataObject) Then
		Return False;
	EndIf;
	
	Return MetadataObject.Hierarchical;
	
EndFunction

#EndRegion

#EndIf
