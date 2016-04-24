#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalInterface

// Updates the register data when changing configuration.
// 
// Parameters:
//  HasChanges - Boolean (return value) - True if data is modified; not set otherwise.
//
Procedure UpdateRegisterData(HasChanges = Undefined, CheckOnly = False) Export
	
	SetPrivilegedMode(True);
	
	StandardSubsystemsCached.CatalogMetadataObjectIDsUsageCheck(True);
	
	If CheckOnly Or ExclusiveMode() Then
		DisableExclusiveMode = False;
	Else
		DisableExclusiveMode = True;
		SetExclusiveMode(True);
	EndIf;
	
	AvailableMetadataObjectRights = AvailableMetadataObjectRights();
	RoleRights = InformationRegisters.RoleRights.CreateRecordSet().Unload();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	IDs.Ref AS ID,
	|	IDs.FullName
	|FROM
	|	Catalog.MetadataObjectIDs AS IDs
	|WHERE
	|	Not IDs.DeletionMark";
	
	IDTable = Query.Execute().Unload();
	IDTable.Columns.Add("MetadataObject", New TypeDescription("MetadataObject"));
	IDTable.Indexes.Add("FullName");
	IDTable.Indexes.Add("MetadataObject");
	
	For Each AvailableRights In AvailableMetadataObjectRights Do
		For Each MetadataObject In Metadata[AvailableRights.Collection] Do
			
			FullName = MetadataObject.FullName();
			ID = MetadataObjectID(IDTable, FullName);
			Fields = AllFieldsOfMetadataObjectAccessRestriction(MetadataObject, FullName);
			
			For Each Role In Metadata.Roles Do
				
				If Not AccessRight("Read", MetadataObject, Role) Then
					Continue;
				EndIf;
				
				NewRow = RoleRights.Add();
				
				NewRow.Role = MetadataObjectID(IDTable, Role);
				NewRow.MetadataObject  = ID;
				
				NewRow.Insert = AvailableRights.AddRight
				                       And AccessRight("Insert", MetadataObject, Role);
				
				NewRow.Edit   = AvailableRights.EditRight
				                       And AccessRight("Edit", MetadataObject, Role);
				
				NewRow.ReadWithoutRestriction =
					Not AccessParameters("Read",       MetadataObject, Fields, Role).RestrictionByCondition;
				
				NewRow.InsertWithoutRestriction =
					NewRow.Insert
					And Not AccessParameters("Insert", MetadataObject, Fields, Role).RestrictionByCondition;
				
				NewRow.UpdateWithoutRestriction =
					NewRow.Edit
					And Not AccessParameters("Edit",  MetadataObject, Fields, Role).RestrictionByCondition;
				
				NewRow.View = AccessRight("View", MetadataObject, Role);
				
				NewRow.Edit = AvailableRights.EditRight
				                           And AccessRight("Edit", MetadataObject, Role);
				
				NewRow.InteractiveInsert =
					AvailableRights.AddRight
					And AccessRight("InteractiveInsert", MetadataObject, Role);
			EndDo;
			
		EndDo;
	EndDo;
	
	TemporaryTableQueryText =
	"SELECT
	|	NewData.MetadataObject,
	|	NewData.Role,
	|	NewData.Insert,
	|	NewData.Edit,
	|	NewData.ReadWithoutRestriction,
	|	NewData.InsertWithoutRestriction,
	|	NewData.UpdateWithoutRestriction,
	|	NewData.View,
	|	NewData.InteractiveInsert,
	|	NewData.Edit
	|INTO NewData
	|FROM
	|	&RoleRights AS NewData";
	
	QueryText =
	"SELECT
	|	NewData.MetadataObject,
	|	NewData.Role,
	|	NewData.Insert,
	|	NewData.Edit,
	|	NewData.ReadWithoutRestriction,
	|	NewData.InsertWithoutRestriction,
	|	NewData.UpdateWithoutRestriction,
	|	NewData.View,
	|	NewData.InteractiveInsert,
	|	NewData.Edit,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	NewData AS NewData";
	
	// Preparing selectable fields with optional selection
	Fields = New Array;
	Fields.Add(New Structure("MetadataObject"));
	Fields.Add(New Structure("Role"));
	Fields.Add(New Structure("Insert"));
	Fields.Add(New Structure("Edit"));
	Fields.Add(New Structure("ReadWithoutRestriction"));
	Fields.Add(New Structure("InsertWithoutRestriction"));
	Fields.Add(New Structure("UpdateWithoutRestriction"));
	Fields.Add(New Structure("View"));
	Fields.Add(New Structure("InteractiveInsert"));
	Fields.Add(New Structure("Edit"));
	
	Query = New Query;
	Query.SetParameter("RoleRights", RoleRights);
	
	Query.Text = AccessManagementInternal.ChangeSelectionQueryText(
		QueryText, Fields, "InformationRegister.RoleRights", TemporaryTableQueryText);
	
	DataLock = New DataLock;
	LockItem = DataLock.Add("Constant.AccessRestrictionParameters");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem = DataLock.Add("InformationRegister.RoleRights");
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		DataLock.Lock();
		Changes = Query.Execute().Unload();
		
		AccessManagementInternal.UpdateInformationRegister(
			InformationRegisters.RoleRights, Changes, HasChanges, , , CheckOnly);
		
		If CheckOnly Then
			CommitTransaction();
			Return;
		EndIf;
		
		Changes.GroupBy(
			"MetadataObject, Role, Insert, Edit", "RowChangeKind");
		
		ExcessiveRows = Changes.FindRows(New Structure("RowChangeKind", 0));
		For Each Row In ExcessiveRows Do
			Changes.Delete(Row);
		EndDo;
		
		Changes.GroupBy("MetadataObject");
		
		If Not CheckOnly Then
			StandardSubsystemsServer.AddApplicationParameterChanges(
				"AccessRestrictionParameters",
				"RoleRightMetadataObjects",
				CommonUse.FixedData(
					Changes.UnloadColumn("MetadataObject")));
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

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions

Function AvailableMetadataObjectRights()
	
	SetPrivilegedMode(True);
	
	MetadataObjectRights = New ValueTable;
	MetadataObjectRights.Columns.Add("Collection");
	MetadataObjectRights.Columns.Add("CollectionSingular");
	MetadataObjectRights.Columns.Add("AddRight");
	MetadataObjectRights.Columns.Add("EditRight");
	MetadataObjectRights.Columns.Add("DeleteRight");
	
	Row = MetadataObjectRights.Add();
	Row.Collection         = "Catalogs";
	Row.CollectionSingular = "Catalog";
	Row.AddRight           = True;
	Row.EditRight          = True;
	Row.DeleteRight      = True;
	
	Row = MetadataObjectRights.Add();
	Row.Collection         = "Documents";
	Row.CollectionSingular = "Document";
	Row.AddRight           = True;
	Row.EditRight          = True;
	Row.DeleteRight      = True;
	
	Row = MetadataObjectRights.Add();
	Row.Collection         = "DocumentJournals";
	Row.CollectionSingular = "DocumentJournal";
	Row.AddRight           = False;
	Row.EditRight          = False;
	Row.DeleteRight      = False;
	
	Row = MetadataObjectRights.Add();
	Row.Collection         = "ChartsOfCharacteristicTypes";
	Row.CollectionSingular = "ChartOfCharacteristicTypes";
	Row.AddRight           = True;
	Row.EditRight          = True;
	Row.DeleteRight      = True;
	
	Row = MetadataObjectRights.Add();
	Row.Collection         = "ChartsOfAccounts";
	Row.CollectionSingular = "ChartOfAccounts";
	Row.AddRight           = True;
	Row.EditRight          = True;
	Row.DeleteRight      = True;
	
	Row = MetadataObjectRights.Add();
	Row.Collection         = "ChartsOfCalculationTypes";
	Row.CollectionSingular = "ChartOfCalculationTypes";
	Row.AddRight           = True;
	Row.EditRight          = True;
	Row.DeleteRight      = True;
	
	Row = MetadataObjectRights.Add();
	Row.Collection         = "InformationRegisters";
	Row.CollectionSingular = "InformationRegister";
	Row.AddRight           = False;
	Row.EditRight          = True;
	Row.DeleteRight      = False;
	
	Row = MetadataObjectRights.Add();
	Row.Collection         = "AccumulationRegisters";
	Row.CollectionSingular = "AccumulationRegister";
	Row.AddRight           = False;
	Row.EditRight          = True;
	Row.DeleteRight      = False;
	
	Row = MetadataObjectRights.Add();
	Row.Collection         = "AccountingRegisters";
	Row.CollectionSingular = "AccountingRegister";
	Row.AddRight           = False;
	Row.EditRight          = True;
	Row.DeleteRight      = False;
	
	Row = MetadataObjectRights.Add();
	Row.Collection         = "CalculationRegisters";
	Row.CollectionSingular = "CalculationRegister";
	Row.AddRight           = False;
	Row.EditRight          = True;
	Row.DeleteRight      = False;
	
	Row = MetadataObjectRights.Add();
	Row.Collection         = "BusinessProcesses";
	Row.CollectionSingular = "BusinessProcess";
	Row.AddRight           = True;
	Row.EditRight          = True;
	Row.DeleteRight      = True;
	
	Row = MetadataObjectRights.Add();
	Row.Collection         = "Tasks";
	Row.CollectionSingular = "Task";
	Row.AddRight           = True;
	Row.EditRight          = True;
	Row.DeleteRight      = True;
	
	Return MetadataObjectRights;
	
EndFunction

Function MetadataObjectID(IDTable, MetadataObject)
	
	If TypeOf(MetadataObject) = Type("MetadataObject") Then
		TableRow = IDTable.Find(MetadataObject, "MetadataObject");
		If TableRow <> Undefined Then
			Return TableRow.ID;
		EndIf;
		FullName = MetadataObject.FullName();
	Else
		FullName = MetadataObject;
	EndIf;
	
	TableRow = IDTable.Find(FullName, "FullName");
	If TableRow = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Error occured when executing the CommonUse.MetadataObjectID()function.
			           |
			           |The %1 metadata
			           |object ID
			           |is not found in the Metadata object IDs directory.'")
			+ StandardSubsystemsServer.ApplicationRunParameterErrorClarificationForDeveloper(),
			FullName);
	EndIf;
	
	If TypeOf(MetadataObject) = Type("MetadataObject") Then
		TableRow.MetadataObject = MetadataObject;
	EndIf;
	
	Return TableRow.ID;
	
EndFunction

// Returns object metadata fields that can be used to restrict access.
//
// Parameters:
//  MetadataObject         - MetadataObject.
//  InfoBaseObject         - Undefined, COMObject.
//  GetNameArray - Boolean.
//
// Returns:
//  String - string of field names, comma-separated. 
//  If GetNameArray = True, then Array of field name strings.
//
Function AllFieldsOfMetadataObjectAccessRestriction(MetadataObject,
                                                   FullName,
                                                   InfoBaseObject = Undefined,
                                                   GetNameArray = False)
	
	CollectionNames = New Array;
	TypeName = Left(FullName, Find(FullName, ".") - 1);
	
	If      TypeName = "Catalog" Then
		CollectionNames.Add("Attributes");
		CollectionNames.Add("TabularSections");
		CollectionNames.Add("StandardAttributes");
		
	ElsIf TypeName = "Document" Then
		CollectionNames.Add("Attributes");
		CollectionNames.Add("TabularSections");
		CollectionNames.Add("StandardAttributes");
		
	ElsIf TypeName = "DocumentJournal" Then
		CollectionNames.Add("Columns");
		CollectionNames.Add("StandardAttributes");
		
	ElsIf TypeName = "ChartOfCharacteristicTypes" Then
		CollectionNames.Add("Attributes");
		CollectionNames.Add("TabularSections");
		CollectionNames.Add("StandardAttributes");
		
	ElsIf TypeName = "ChartOfAccounts" Then
		CollectionNames.Add("Attributes");
		CollectionNames.Add("TabularSections");
		CollectionNames.Add("AccountingFlags");
		CollectionNames.Add("StandardAttributes");
		CollectionNames.Add("StandardTabularSections");
		
	ElsIf TypeName = "ChartOfCalculationTypes" Then
		CollectionNames.Add("Attributes");
		CollectionNames.Add("TabularSections");
		CollectionNames.Add("StandardAttributes");
		CollectionNames.Add("StandardTabularSections");
		
	ElsIf TypeName = "InformationRegister" Then
		CollectionNames.Add("Dimensions");
		CollectionNames.Add("Resources");
		CollectionNames.Add("Attributes");
		CollectionNames.Add("StandardAttributes");
		
	ElsIf TypeName = "AccumulationRegister" Then
		CollectionNames.Add("Dimensions");
		CollectionNames.Add("Resources");
		CollectionNames.Add("Attributes");
		CollectionNames.Add("StandardAttributes");
		
	ElsIf TypeName = "AccountingRegister" Then
		CollectionNames.Add("Dimensions");
		CollectionNames.Add("Resources");
		CollectionNames.Add("Attributes");
		CollectionNames.Add("StandardAttributes");
		
	ElsIf TypeName = "CalculationRegister" Then
		CollectionNames.Add("Dimensions");
		CollectionNames.Add("Resources");
		CollectionNames.Add("Attributes");
		CollectionNames.Add("StandardAttributes");
		
	ElsIf TypeName = "BusinessProcess" Then
		CollectionNames.Add("Attributes");
		CollectionNames.Add("TabularSections");
		CollectionNames.Add("StandardAttributes");
		
	ElsIf TypeName = "Task" Then
		CollectionNames.Add("AddressingAttributes");
		CollectionNames.Add("Attributes");
		CollectionNames.Add("TabularSections");
		CollectionNames.Add("StandardAttributes");
	EndIf;
	
	FieldNames = New Array;
	If InfoBaseObject = Undefined Then
		ValueStorageType = Type("ValueStorage");
	Else
		ValueStorageType = InfoBaseObject.NewObject("TypeDescription", "ValueStorage").Types().Get(0);
	EndIf;

	For Each CollectionName In CollectionNames Do
		If CollectionName = "TabularSections"
		 Or CollectionName = "StandardTabularSections" Then
			For Each TabularSection In MetadataObject[CollectionName] Do
				AddFieldOfMetadataObjectAccessRestriction(MetadataObject, TabularSection.Name, FieldNames, InfoBaseObject);
				Attributes = ?(CollectionName = "TabularSections", TabularSection.Attributes, TabularSection.StandardAttributes);
				For Each Field In Attributes Do
					If Field.Type.ContainsType(ValueStorageType) Then
						Continue;
					EndIf;
					AddFieldOfMetadataObjectAccessRestriction(MetadataObject, TabularSection.Name + "." + Field.Name, FieldNames, InfoBaseObject);
				EndDo;
				If CollectionName = "StandardTabularSections" And TabularSection.Name = "ExtDimensionTypes" Then
					For Each Field In MetadataObject.ExtDimensionAccountingFlags Do
						AddFieldOfMetadataObjectAccessRestriction(MetadataObject, "ExtDimensionTypes." + Field.Name, FieldNames, InfoBaseObject);
					EndDo;
				EndIf;
			EndDo;
		Else
			For Each Field In MetadataObject[CollectionName] Do
	 			If TypeName = "DocumentJournal"       And Field.Name = "Type"
	 			 Or TypeName = "ChartOfCharacteristicTypes" And Field.Name = "ValueType"
	 			 Or TypeName = "ChartOfAccounts"             And Field.Name = "Kind"
	 			 Or TypeName = "AccumulationRegister"      And Field.Name = "RecordType"
	 			 Or TypeName = "AccountingRegister"     And CollectionName = "StandardAttributes" And Find(Field.Name, "ExtDimensions") > 0 Then
	 				Continue;
	 			EndIf;
				If CollectionName = "Columns" Or
					 Field.Type.ContainsType(ValueStorageType) Then
					Continue;
				EndIf;
				If (CollectionName = "Dimensions" Or CollectionName = "Resources")
				   And ?(InfoBaseObject = Undefined, Metadata, InfoBaseObject.Metadata).AccountingRegisters.Contains(MetadataObject)
				   And Not Field.Balance Then
					// Dr
					AddFieldOfMetadataObjectAccessRestriction(MetadataObject, Field.Name + "Dr", FieldNames, InfoBaseObject);
					// Cr
					AddFieldOfMetadataObjectAccessRestriction(MetadataObject, Field.Name + "Cr", FieldNames, InfoBaseObject);
				Else
					AddFieldOfMetadataObjectAccessRestriction(MetadataObject, Field.Name, FieldNames, InfoBaseObject);
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
	If GetNameArray Then
		Return FieldNames;
	EndIf;
	
	FieldList = "";
	For Each FieldName In FieldNames Do
		FieldList = FieldList + ", " + FieldName;
	EndDo;
	
	Return Mid(FieldList, 3);
	
EndFunction

Procedure AddFieldOfMetadataObjectAccessRestriction(MetadataObject,
                                                          FieldName,
                                                          FieldNames,
                                                          InfoBaseObject)
	
	Try
		If InfoBaseObject = Undefined Then
			AccessParameters("Read", MetadataObject, FieldName, Metadata.Roles.FullAccess);
		Else
			InfoBaseObject.AccessParameters(
				"Read",
				MetadataObject,
				FieldName,
				InfoBaseObject.Metadata.Roles.FullAccess);
		EndIf;
		CanGetAccessParameters = True;
	Except
		// If separate read restriction cannot be set for a field, any attempts to get 
		// access parameters for this field may generate errors.
		// Such fields must be excluded from the restriction check, as it is not necessary for them.
		CanGetAccessParameters = False;
	EndTry;
	
	If CanGetAccessParameters Then
		FieldNames.Add(FieldName);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf