////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Procedure updates catalog data by configuration metadata.
// During executing of this procedure the 
// CommonUseOverridable.OnChangeMetadataObjectID() event handler can be called.
//
// Parameters:
// HasChanges - Boolean, it is set to True if changes were made,
// otherwise it is not changed.
// HasDeleted - Boolean, it is set to True
// if one or more catalog items were marked for deletion,
// otherwise it is not changed.
//
Procedure UpdateCatalogData(HasChanges = True, HasDeleted = True) Export
	
	SetPrivilegedMode(True);
	
	MetadataObjectCollectionProperties = MetadataObjectCollectionProperties();
	MetadataObjectProperties = MetadataObjectProperties(MetadataObjectCollectionProperties);
	CatalogManager = CommonUse.ObjectManagerByFullName("Catalog.MetadataObjectIDs");
	
	MetadataObjectProperties.Indexes.Add("FullName");
	
	// Processed is a state when ID is corresponded to the metadata object and
	// it was verified and updated, if its properties have changed
	MetadataObjectProperties.Columns.Add("Processed", New TypeDescription("Boolean"));
	
	// Change is a state when Processed = True and details of ID were changed
	MetadataObjectProperties.Columns.Add("Change", New TypeDescription("Boolean"));
	
	// ChangeAndReplace is a state when Change = True, one or more IDs with the same key is found, 
	// and procedure that replace a reference in the Infobase by a new ID was executed.
	// 
	MetadataObjectProperties.Columns.Add("ChangeAndReplace", New TypeDescription("Boolean"));
	
	// ChangeEventHandlerParameter is a property structure, which is filled
	// on ID properties change
	MetadataObjectProperties.Columns.Add("ChangeEventHandlerParameter");
	
	BeginTransaction();
	Try
		DataLock = New DataLock;
		LockItem = DataLock.Add();
		LockItem.Region = "Catalog.MetadataObjectIDs";
		LockItem.Mode = DataLockMode.Exclusive;
		DataLock.Lock();
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	IDs.Ref,
		|	IDs.Parent,
		|	IDs.DeletionMark,
		|	IDs.Predefined AS Predefined,
		|	IDs.Description,
		|	IDs.CollectionOrder,
		|	IDs.Name,
		|	IDs.Synonym,
		|	IDs.FullName,
		|	IDs.FullSynonym,
		|	IDs.WithoutData,
		|	IDs.EmptyRefValue,
		|	IDs.MetadataObjectKey,
		|	IDs.Used
		|FROM
		|	Catalog.MetadataObjectIDs AS IDs
		|
		|ORDER BY
		|	Predefined DESC";
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			// Checking and updating collection ID properties 
			CollectionProperties = MetadataObjectCollectionProperties.Find(Selection.Ref, "CollectionID");
			If CollectionProperties <> Undefined Then
				CheckRefreshCollectionProperties(Selection, CollectionProperties, HasChanges);
				Continue;
			EndIf;
			// Predefined items have priority, they are processed first.
			MetadataObjectKey = Selection.MetadataObjectKey.Get();
			If Selection.Predefined Then
				FullName = "";
				MetadataObject = FindPredefinedMetadataObject(Selection.Ref, FullName);
				If MetadataObject = Undefined Then
					Raise StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = 'In the Metadata Objects IDs catalog,
						 |%2
						 |metadata object
						 |is not found for 
						 |%1 
						 |predefined item.
						 |
						 |You have to specify a name of the predefined item,
						 |corresponded to the existent metadata object.'"),
						GetPredefinedItemName(Selection.Ref),
						FullName);
				EndIf;
				// Checking that predefined item refers to the metadata object collection,
				// for which there is a MetadataObjectKey
				SingularCollectionName = StringFunctionsClientServer.SplitStringIntoSubstringArray(FullName, ".")[0];
				CollectionDetails = MetadataObjectCollectionProperties.Find(SingularCollectionName, "SingularName");
				If CollectionDetails.WithoutMetadataObjectKey Then
					Raise StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = 'In the Metadata Object IDs catalog, 
						 |%2
						 |metadata object
						 |is found for
						 |%1 
						 |predefined item.
						 |
						 |But predefined items are not used for
						 |the metadata objects of the %3 type.
						 |
						 |Therefore, you have to delete the predefined item.'"),
						GetPredefinedItemName(Selection.Ref),
						FullName,
						SingularCollectionName);
				EndIf;
				
				If MetadataObjectKey <> Undefined
				 And MetadataObjectKey <> Type("Undefined") Then
					// If metadata object key is specified, then there is a need to check,
					// whether items that found by the full name and by the key are equal
					MetadataObjectByKey = MetadataObjectByKey(MetadataObjectKey);
					If MetadataObject <> MetadataObjectByKey Then
						// If the key is specified for the predefined metadata item,
						// but it is not equal to the name, specified in the predefined item, 
						// then it means that object was renamed to another existent metadata object
						If MetadataObjectByKey = Undefined Then
							Raise StringFunctionsClientServer.SubstituteParametersInString(
								NStr("en = 'In the Metadata Object IDs catalog, 
								 |a key of another deleted metadata object was set for
								 |%1
								 |predefined item.
								 |
								 |There is an error renaming the predefined item:
								 |the item was renamed to the existent metadata object
								 |%2.
								 |
								 |Reuse of a predefined item
								 |for another metadata object is not allowed.
								 |
								 |You have to delete the predefined item of the deleted metadata object
								 |and create a new item for 
								 |%2
								 |metadata object.'"),
								GetPredefinedItemName(Selection.Ref),
								FullName);
						Else
							Raise StringFunctionsClientServer.SubstituteParametersInString(
								NStr("en = 'In the Metadata Object IDs catalog, a key of 
								 |%2
								 |metadata object is set for
								 |%1
								 |predefined item.
								 |
								 |There is an error renaming the predefined item:
								 |the item was renamed to the existent metadata object
								 |%3.
								 |
								 |Reuse of a predefined item
								 |for another metadata object is not allowed.
								 |
								 |You have to specify a correct name 
								 |%4
								 |for
								 |%1
								 |predefined item, correspond to the
								 |%2
								 |metadata object.'"),
								GetPredefinedItemName(Selection.Ref),
								MetadataObjectByKey.FullName(),
								FullName,
								StrReplace(MetadataObjectByKey.FullName(), ".", "_"));
						EndIf;
					EndIf;
				EndIf;
			EndIf;
			
			// Metadata object key can be empty for predefined item
			// or can be equal to the Undefined type for metadata object without a key, by which
			// MetadataObject can be found
			If MetadataObjectKey = Undefined
			 or MetadataObjectKey = Type("Undefined") Then
				// If metadata object have no key, it can be found 
				// by name of predefined item or by preset ID
				If Selection.Predefined Then
					MetadataObject = Metadata.FindByFullName(FullName);
				Else
					//PrevMetadataObjectProperties = MetadataObjectProperties;
					Row = MetadataObjectProperties.Find(Selection.Ref, "ID");
					If Row = Undefined Then
						MetadataObject = Undefined;
						//MetadataObjectProperties = PrevMetadataObjectProperties;
					Else
						MetadataObject = Metadata.FindByFullName(Row.FullName);
					EndIf;
				EndIf;
			Else
				MetadataObject = MetadataObjectByKey(MetadataObjectKey);
			EndIf;
			
			// If metadata object is found by the key or by name of predefined item,
			// then a metadata object property row should be prepared
			If MetadataObject <> Undefined Then
				Row = MetadataObjectProperties.Find(MetadataObject.FullName(), "FullName");
				If ValueIsFilled(Row.ParentFullName) Then
					// Parent could be a preset or predefined item.
					ParentRow = MetadataObjectProperties.Find(Row.ParentFullName, "FullName");
					If ValueIsFilled(ParentRow.ID) Then
						Row.Parent = ParentRow.ID;
					Else
						PredefinedParentName = StrReplace(Row.ParentFullName, ".", "_");
						Try
							Row.Parent = CatalogManager[PredefinedParentName];
						Except
							Raise StringFunctionsClientServer.SubstituteParametersInString(
								NStr("en = 'In the Metadata Object IDs catalog,
								 |%2
								 |predefined parent item is not found for
								 |%1
								 |predefined item.
								 |
								 |You have to add the predefined parent item.'"),
								GetPredefinedItemName(Selection.Ref),
								StrReplace(Row.ParentFullName, ".", "_"));
						EndTry;
					EndIf;
				EndIf;
			EndIf;
			
			If MetadataObject = Undefined or Row.Processed Then
				// If metadata object is not found or is already processed,
				// then the duplicate ID should be marked for deletion.
				If Selection.Predefined = Selection.DeletionMark
				 or ValueIsFilled(Selection.Parent)
				 or Left(Selection.Description, 1) <> "?"
				 or Left(Selection.Name, 1) <> "?"
				 or Left(Selection.Synonym, 1) <> "?"
				 or Left(Selection.FullName, 1) <> "?"
				 or Left(Selection.FullSynonym, 1) <> "?"
				 or Selection.Used
				 or Selection.EmptyRefValue <> Undefined Then
					// Saving old properties for the OnChangeMetadataObjectID event handler
					TableObject = Selection.Ref.GetObject();
					Properties = EventHandlerParameters();
					FillPropertyValues(Properties.Old, TableObject);
					// Setting new properties to metadata object ID
					TableObject = Selection.Ref.GetObject();
					Used = TableObject.Used;
					TableObject.DeletionMark = Not Selection.Predefined;
					TableObject.Parent = Undefined;
					TableObject.Description = "? " + TableObject.Description;
					TableObject.Name = "? " + TableObject.Name;
					TableObject.Synonym = "? " + TableObject.Synonym;
					TableObject.FullName = "? " + TableObject.FullName;
					TableObject.FullSynonym = "? " + TableObject.FullSynonym;
					TableObject.Used = False;
					TableObject.EmptyRefValue = Undefined;
					TableObject.AdditionalProperties.Insert("ExecutingAutomaticCatalogDataUpdate");
					TableObject.Write();
					HasChanges = True;
					// Convertion of an ordinary item into a predefined item handler 
					// is executed, if there was an ordinary item and
					// predefined item was added
					If MetadataObject <> Undefined And Used Then
						// Searching for a predefined item
						Query = New Query;
						Query.SetParameter("FullName", MetadataObject.FullName());
						Query.Text =
						"SELECT
						|	Table.Ref,
						|	Table.FullName
						|FROM
						|	Catalog.MetadataObjectIDs AS Table
						|WHERE
						|	Table.FullName = &FullName
						|	AND Table.Predefined";
						ExportTable = Query.Execute().Unload();
						// More than one predefined item for one
						// metadata object means that an error occurred on designing or
						// on setting the same metadata object key to different predefined items
						If ExportTable.Count() > 1 Then
							Raise StringFunctionsClientServer.SubstituteParametersInString(
								NStr("en = 'Error updating the Metadata object IDs catalog.
								 |More than one predefined item have been found by the internal key
								 |for %1 metadata object.'"),
								ExportTable[0].FullName);
						ElsIf ExportTable.Count() = 1 Then
							// If old ID is used in the Infobase it have to be
							// replaced by a new predefined item ID.
							Row.ChangeAndReplace = True;
							Properties.ReplaceRefs = True;
							Properties.New = Row.ChangeEventHandlerParameter.New;
							CommonUseOverridable.OnChangeMetadataObjectID("Change", Properties);
							If Properties.ReplaceRefs = True Then
								ReplaceRefInInfoBase(TableObject.Ref, ExportTable[0].Ref);
							EndIf;
						EndIf;
					Else
						HasDeleted = True;
						// Calling OnChangeMetadataObjectID event handler
						CommonUseOverridable.OnChangeMetadataObjectID("Deletion", Properties);
					EndIf;
				EndIf;
			Else
				// Updating existing metadata object properties, if changed
				Row.Processed = True;
				If Selection.Parent <> Row.Parent
				 or Selection.Description <> Row.Description
				 or Selection.CollectionOrder <> Row.CollectionOrder
				 or Selection.Name <> Row.Name
				 or Selection.Synonym <> Row.Synonym
				 or Selection.FullName <> Row.FullName
				 or Selection.FullSynonym <> Row.FullSynonym
				 or Selection.WithoutData <> Row.WithoutData
				 or Selection.EmptyRefValue <> Row.EmptyRefValue
				 or Selection.DeletionMark
				 or MetadataObjectKey = Undefined
				 or Not Selection.Used Then
					// Saving old properties for the OnChangeMetadataObjectID event handler
					TableObject = Selection.Ref.GetObject();
					Properties = EventHandlerParameters();
					FillPropertyValues(Properties.Old, TableObject);
					// Setting new properties to the metadata object ID
					FillPropertyValues(TableObject, Row);
					If MetadataObjectKey = Undefined Then
						TableObject.MetadataObjectKey = New ValueStorage(MetadataObjectKey(Row.FullName));
					EndIf;
					TableObject.DeletionMark = False;
					TableObject.Used = True;
					TableObject.AdditionalProperties.Insert("ExecutingAutomaticCatalogDataUpdate");
					TableObject.Write();
					HasChanges = True;
					// Saving old properties for the OnChangeMetadataObjectID event handler
					FillPropertyValues(Properties.New, TableObject);
					Row.Change = True;
					Row.ChangeEventHandlerParameter = Properties;
				EndIf;
			EndIf;
		EndDo;
		
		// Adding IDs of new metadata objects
		// Metadata objects without a metadata object key are not added,
		// such metadata objects can be added only manually as predefined items,
		// like subsystems, for example.
		For Each Row In MetadataObjectProperties.FindRows(New Structure("Processed", False)) Do
			TableObject = CreateItem();
			If ValueIsFilled(Row.ID) Then
				TableObject.SetNewObjectRef(Row.ID);
			EndIf;
			If ValueIsFilled(Row.ParentFullName) Then
				Row.Parent = MetadataObjectProperties.Find(Row.ParentFullName, "FullName").ID;
			EndIf;
			FillPropertyValues(TableObject, Row);
			TableObject.MetadataObjectKey = New ValueStorage(MetadataObjectKey(Row.FullName));
			TableObject.Used = True;
			TableObject.AdditionalProperties.Insert("ExecutingAutomaticCatalogDataUpdate");
			TableObject.Write();
			HasChanges = True;
			// Calling OnChangeMetadataObjectID event handler
			Properties = EventHandlerParameters();
			FillPropertyValues(Properties.New, TableObject);
			CommonUseOverridable.OnChangeMetadataObjectID("Adding", Properties);
		EndDo;
		
		// Calling OnChangeMetadataObjectID event handler for Change without replacement event type
		For Each Row In MetadataObjectProperties.FindRows(New Structure("Change, ChangeAndReplace", True, False)) Do
			EventHandlerCallRequired = False;
			Properties = Row.ChangeEventHandlerParameter;
			For Each KeyAndValue In Properties.New Do
				If Properties.New[KeyAndValue.Key] <> Properties.Old[KeyAndValue.Key] Then
					EventHandlerCallRequired = True;
					Break;
				EndIf;
			EndDo;
			If EventHandlerCallRequired Then
				CommonUseOverridable.OnChangeMetadataObjectID("Change", Properties);
			EndIf;
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL INTERFACE

// For internal use only
Function MetadataObjectKeyCorrespondsFullName(IDProperties) Export
	
	CheckResult = New Structure;
	CheckResult.Insert("NotCorresponds", True);
	CheckResult.Insert("MetadataObjectKey", Undefined);
	
	MetadataObjectKey = IDProperties.MetadataObjectKey.Get();
	
	If MetadataObjectKey <> Undefined
	 And MetadataObjectKey <> Type("Undefined") Then
		// Key is set, searching metadata object by the key
		CheckResult.Insert("MetadataObjectKey", MetadataObjectKey);
		MetadataObject = MetadataObjectByKey(MetadataObjectKey);
		If MetadataObject <> Undefined Then
			CheckResult.NotCorresponds = MetadataObject.FullName() <> IDProperties.FullName;
		EndIf;
	Else
		// Key is not set, searching metadata object by the full name
		MetadataObject = Metadata.FindByFullName(IDProperties.FullName);
		If MetadataObject = Undefined Then
			// Possible, collection is set
			CollectionProperties = MetadataObjectCollectionProperties();
			Row = CollectionProperties.Find(IDProperties.Ref, "CollectionID");
			If Row <> Undefined Then
				MetadataObject = Metadata[Row.Name];
				CheckResult.NotCorresponds = Row.Name <> IDProperties.FullName;
			EndIf;
		Else
			CheckResult.NotCorresponds = False;
		EndIf;
	EndIf;
	
	CheckResult.Insert("MetadataObject", MetadataObject);
	
	Return CheckResult;
	
EndFunction

// For internal use only
Procedure UnloadCatalogData(Val ExportDirectory) Export
	
	Writer = New XMLWriter;
	Writer.OpenFile(ExportDirectory + "MetadataObjectIDs.xml");
	Writer.WriteXMLDeclaration();
	
	Writer.WriteStartElement("Data");
	Writer.WriteNamespaceMapping("xs", "http://www.w3.org/2001/XMLSchema");
	Writer.WriteNamespaceMapping("xsi", "http://www.w3.org/2001/XMLSchema-instance");
	Writer.WriteNamespaceMapping("ns1", "http://v8.1c.ru/8.1/data/core");
	Writer.WriteNamespaceMapping("ns2", "http://v8.1c.ru/8.1/data/enterprise");
	Writer.WriteNamespaceMapping("v8", "http://v8.1c.ru/8.1/data/enterprise/current-config");
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	MetadataObjectIDs.Ref AS Ref
	|FROM
	|	Catalog.MetadataObjectIDs AS MetadataObjectIDs";
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		XDTOSerializer.WriteXML(Writer, Selection.Ref.GetObject(), XMLTypeAssignment.Explicit);
	EndDo;
	
	Writer.WriteEndElement();
	
	Writer.Close();
	
EndProcedure

// For internal use only
Procedure SupplementReplacementDictionaryReferencesCurrentIdentifiersAndDownloadables(Val ReplacementDictionary, Val ExportDirectory) Export
	
	LinkMap = New Map;
	
	Reader= New XMLReader;
	Reader.OpenFile(ExportDirectory + "MetadataObjectIDs.xml");
	Reader.MoveToContent();
	If Reader.NodeType <> XMLNodeType.StartElement
		or Reader.Name <> "Data" Then
		
		Raise(NStr("en = 'Invalid format of MetadataObjectIDs.xml'"));
		
	EndIf;
	
	If Not Reader.Read() Then
		Raise(NStr("en = 'Error reading the XML file. Unexpected end of file detected.'"));
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	IDs.Ref,
	|	IDs.FullName,
	|	IDs.Used
	|FROM
	|	Catalog.MetadataObjectIDs AS IDs";
	
	IDProperties = Query.Execute().Unload();
	IDProperties.Indexes.Add("Ref");
	IDProperties.Indexes.Add("FullName");
	
	While Reader.NodeType = XMLNodeType.StartElement Do
		Data = XDTOSerializer.ReadXML(Reader);
		
		IDProperty = IDProperties.Find(Data.Ref, "Ref");
		If IDProperty = Undefined Or Not IDProperty.Used Then
			
			MetadataObject = MetadataObjectByKey(Data.MetadataObjectKey);
			If MetadataObject = Undefined Then
				MetadataObject = Metadata.FindByFullName(Data.FullName);
			EndIf;
			
			If MetadataObject <> Undefined Then
				ID = CommonUse.MetadataObjectID(MetadataObject);
				If Data.Ref <> ID Then
					// Key is the existent reference
					// Value is the downloadable reference.
					LinkMap.Insert(ID, Data.Ref);
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
	FragmentRow = ReplacementDictionary.Add();
	FragmentRow.Type = Type("CatalogRef.MetadataObjectIDs");
	FragmentRow.ReferenceMap = LinkMap;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

Procedure CheckRefreshCollectionProperties(Val CurrentProperties, Val NewProperties, HasChanges)
	
	CollectionDescription = NewProperties.Synonym + " (" + NStr("en = 'Collection'") + ")";
	
	If CurrentProperties.Description <> CollectionDescription
	 or CurrentProperties.CollectionOrder <> NewProperties.CollectionOrder
	 or CurrentProperties.Name <> NewProperties.Name
	 or CurrentProperties.Synonym <> NewProperties.Synonym
	 or CurrentProperties.FullName <> NewProperties.Name
	 or CurrentProperties.FullSynonym <> NewProperties.Synonym
	 or CurrentProperties.WithoutData <> False
	 or CurrentProperties.EmptyRefValue <> Undefined
	 or CurrentProperties.Used <> True
	 or CurrentProperties.MetadataObjectKey.Get() <> Undefined Then
		
		// Setting new properties
		Object = CurrentProperties.Ref.GetObject();
		Object.Description = CollectionDescription;
		Object.CollectionOrder = NewProperties.CollectionOrder;
		Object.Name = NewProperties.Name;
		Object.Synonym = NewProperties.Synonym;
		Object.FullName = NewProperties.Name;
		Object.FullSynonym = NewProperties.Synonym;
		Object.WithoutData = False;
		Object.EmptyRefValue = Undefined;
		Object.MetadataObjectKey = Undefined;
		Object.Used = True;
		Object.AdditionalProperties.Insert("ExecutingAutomaticCatalogDataUpdate");
		Object.Write();
		HasChanges = True;
	EndIf;
	
EndProcedure

Function FindPredefinedMetadataObject(Val Ref, FullName)
	
	PredefinedName = GetPredefinedItemName(Ref);
	
	If Upper(Left(PredefinedName, 10)) = Upper("Subsystem_") Then
		While True Do
			NextNamePosition = Find(Upper(PredefinedName), Upper("_Subsystem"));
			If NextNamePosition > 0 Then
				FullName = FullName + ".Subsystem." + Mid(PredefinedName, 11, NextNamePosition - 11);
				PredefinedName = Mid(PredefinedName, NextNamePosition + 1);
			Else
				FullName = FullName + ".Subsystem." + Mid(PredefinedName, 11);
				Break;
			EndIf;
		EndDo;
		FullName = Mid(FullName, 2);
	Else
		UnderlinePosition = Find(PredefinedName, "_");
		FullName = Left(PredefinedName, UnderlinePosition-1)
		 + "."
		 + Mid(PredefinedName, UnderlinePosition + 1);
	EndIf;
	
	Return Metadata.FindByFullName(FullName);
	
EndFunction

Function MetadataObjectKey(FullName)
	
	DotPosition = Find(FullName, ".");
	
	MOClass = Left( FullName, DotPosition-1);
	MOName = Mid(FullName, DotPosition+1);
	
	If Upper(MOClass) = Upper("Role") Then
		InfoBaseUser = InfoBaseUsers.CreateUser();
		InfoBaseUser.Roles.Add(Metadata.Roles[MOName]);
		Return InfoBaseUser.Roles;
		
	ElsIf Upper(MOClass) = Upper("ExchangePlan") Then
		Return Type(MOClass + "Ref." + MOName);
		
	ElsIf Upper(MOClass) = Upper("Catalog") Then
		Return Type(MOClass + "Ref." + MOName);
		
	ElsIf Upper(MOClass) = Upper("Document") Then
		Return Type(MOClass + "Ref." + MOName);
		
	ElsIf Upper(MOClass) = Upper("DocumentJournal") Then
		Return TypeOf(CommonUse.ObjectManagerByFullName(FullName));
		
	ElsIf Upper(MOClass) = Upper("Report") Then
		Return Type(MOClass + "Object." + MOName);
		
	ElsIf Upper(MOClass) = Upper("DataProcessor") Then
		Return Type(MOClass + "Object." + MOName);
		
	ElsIf Upper(MOClass) = Upper("ChartOfCharacteristicTypes") Then
		Return Type(MOClass + "Ref." + MOName);
		
	ElsIf Upper(MOClass) = Upper("ChartOfAccounts") Then
		Return Type(MOClass + "Ref." + MOName);
		
	ElsIf Upper(MOClass) = Upper("ChartOfCalculationTypes") Then
		Return Type(MOClass + "Ref." + MOName);
		
	ElsIf Upper(MOClass) = Upper("InformationRegister") Then
		Return Type(MOClass + "RecordKey." + MOName);
		
	ElsIf Upper(MOClass) = Upper("AccumulationRegister") Then
		Return Type(MOClass + "RecordKey." + MOName);
		
	ElsIf Upper(MOClass) = Upper("AccountingRegister") Then
		Return Type(MOClass + "RecordKey." + MOName);
		
	ElsIf Upper(MOClass) = Upper("CalculationRegister") Then
		Return Type(MOClass + "RecordKey." + MOName);
		
	ElsIf Upper(MOClass) = Upper("BusinessProcess") Then
		Return Type(MOClass + "Ref." + MOName);
		
	ElsIf Upper(MOClass) = Upper("Task") Then
		Return Type(MOClass + "Ref." + MOName);
	Else
		// Without metadata object key
		Return Type("Undefined");
	EndIf;
	
EndFunction 

Function MetadataObjectByKey(MetadataObjectKey)
	
	MetadataObject = Undefined;
	
	If TypeOf(MetadataObjectKey) = Type("UserRoles") Then
		For Each Role In Metadata.Roles Do
			If MetadataObjectKey.Contains(Role) Then
				Return Role;
			EndIf;
		EndDo;
	Else
		MetadataObject = Metadata.FindByType(MetadataObjectKey);
	EndIf;
	
	Return MetadataObject;
	
EndFunction

Function MetadataObjectProperties(MetadataObjectCollectionProperties)
	
	MetadataObjectProperties = New ValueTable;
	MetadataObjectProperties.Columns.Add("Description", New TypeDescription("String",, New StringQualifiers(150)));
	MetadataObjectProperties.Columns.Add("FullName", New TypeDescription("String",, New StringQualifiers(510)));
	MetadataObjectProperties.Columns.Add("ParentFullName", New TypeDescription("String",, New StringQualifiers(510)));
	MetadataObjectProperties.Columns.Add("CollectionOrder", New TypeDescription("Number"));
	MetadataObjectProperties.Columns.Add("ID", New TypeDescription("CatalogRef.MetadataObjectIDs"));
	MetadataObjectProperties.Columns.Add("Parent", New TypeDescription("CatalogRef.MetadataObjectIDs"));
	MetadataObjectProperties.Columns.Add("Name", New TypeDescription("String",, New StringQualifiers(150)));
	MetadataObjectProperties.Columns.Add("Synonym", New TypeDescription("String",, New StringQualifiers(255)));
	MetadataObjectProperties.Columns.Add("FullSynonym", New TypeDescription("String",, New StringQualifiers(510)));
	MetadataObjectProperties.Columns.Add("WithoutData", New TypeDescription("Boolean"));
	MetadataObjectProperties.Columns.Add("WithoutMetadataObjectKey", New TypeDescription("Boolean"));
	MetadataObjectProperties.Columns.Add("EmptyRefValue");
	
	// Preparing preset IDs
	PresetIDs = New ValueTable;
	PresetIDs.Columns.Add("ID", New TypeDescription("CatalogRef.MetadataObjectIDs"));
	PresetIDs.Columns.Add("FullName", New TypeDescription("String"));
	
	CommonUseOverridable.FillPresetMetadataObjectIDs(PresetIDs);
	
	For Each CollectionProperties In MetadataObjectCollectionProperties Do
		AddMetadataObjectProperties(Metadata[CollectionProperties.Name], CollectionProperties, MetadataObjectProperties, PresetIDs);
	EndDo;
	
	If PresetIDs.Count() > 0 Then
		RaisePresetIDsFillingErrorException(PresetIDs, MetadataObjectCollectionProperties);
	EndIf;
	
	Return MetadataObjectProperties;
	
EndFunction

Procedure AddMetadataObjectProperties(Val MetadataObjectCollection, Val CollectionProperties, Val MetadataObjectProperties, Val PresetIDs, Val ParentFullName = "", Val ParentFullSynonym = "")
	
	For Each MetadataObject In MetadataObjectCollection Do
		
		FullName = MetadataObject.FullName();
		
		If Not CollectionProperties.WithoutData
		 And Find(CollectionProperties.SingularName, "Register") = 0 Then
			
			EmptyRefValue = CommonUse.ObjectManagerByFullName(FullName).EmptyRef();
		Else
			EmptyRefValue = Undefined;
		EndIf;
		
		If CollectionProperties.WithoutMetadataObjectKey Then
			IDInfo = PresetIDs.Find(FullName, "FullName");
			If IDInfo = Undefined Then
				Continue;
			EndIf;
			ID = IDInfo.ID;
			PresetIDs.Delete(IDInfo);
		Else
			ID = EmptyRef();
		EndIf;
		
		NewRow = MetadataObjectProperties.Add();
		FillPropertyValues(NewRow, CollectionProperties);
		NewRow.ID = ID;
		NewRow.Parent = CollectionProperties.CollectionID;
		NewRow.Description = MetadataObjectPresentation(MetadataObject, CollectionProperties);
		NewRow.FullName = FullName;
		NewRow.ParentFullName = ParentFullName;
		NewRow.Name = MetadataObject.Name;
		NewRow.Synonym = ?(ValueIsFilled(MetadataObject.Synonym), MetadataObject.Synonym, MetadataObject.Name);
		NewRow.FullSynonym = ParentFullSynonym + CollectionProperties.SynonymInSingularNumber + ". " + NewRow.Synonym;
		NewRow.EmptyRefValue = EmptyRefValue;
		
		If CollectionProperties.Name = "Subsystems" Then
			AddMetadataObjectProperties(MetadataObject.Subsystems, CollectionProperties, MetadataObjectProperties, PresetIDs, FullName, NewRow.FullSynonym + ". ");
		EndIf;
	EndDo;
	
EndProcedure

Function MetadataObjectPresentation(Val MetadataObject, Val CollectionProperties);
	
	Postfix = "(" + CollectionProperties.SynonymInSingularNumber + ")";
	
	Synonym = ?(ValueIsFilled(MetadataObject.Synonym), MetadataObject.Synonym, MetadataObject.Name);
	
	SynonymMaxLength = 150 - StrLen(Postfix);
	If StrLen(Synonym) > SynonymMaxLength + 1 Then
		Return Left(Synonym, SynonymMaxLength - 2) + "..." + Postfix;
	EndIf;
	
	Return Synonym + " (" + CollectionProperties.SynonymInSingularNumber + ")";
	
EndFunction

Function MetadataObjectCollectionProperties()
	
	MetadataObjectCollectionProperties = New ValueTable;
	MetadataObjectCollectionProperties.Columns.Add("Name", New TypeDescription("String",, New StringQualifiers(50)));
	MetadataObjectCollectionProperties.Columns.Add("SingularName", New TypeDescription("String",, New StringQualifiers(50)));
	MetadataObjectCollectionProperties.Columns.Add("Synonym", New TypeDescription("String",, New StringQualifiers(255)));
	MetadataObjectCollectionProperties.Columns.Add("SynonymInSingularNumber", New TypeDescription("String",, New StringQualifiers(255)));
	MetadataObjectCollectionProperties.Columns.Add("CollectionOrder", New TypeDescription("Number"));
	MetadataObjectCollectionProperties.Columns.Add("WithoutData", New TypeDescription("Boolean"));
	MetadataObjectCollectionProperties.Columns.Add("WithoutMetadataObjectKey", New TypeDescription("Boolean"));
	MetadataObjectCollectionProperties.Columns.Add("CollectionID", New TypeDescription("CatalogRef.MetadataObjectIDs"));
	
	// Subsystems
	Row = MetadataObjectCollectionProperties.Add();
	Row.Name = "Subsystems";
	Row.Synonym = NStr("en = 'Subsystems'");
	Row.SingularName = "Subsystem";
	Row.SynonymInSingularNumber = NStr("en = 'Subsystem'");
	Row.WithoutData = True;
	Row.WithoutMetadataObjectKey = True;
	
	// Roles
	Row = MetadataObjectCollectionProperties.Add();
	Row.Name = "Roles";
	Row.Synonym = NStr("en = 'Roles'");
	Row.SingularName = "Role";
	Row.SynonymInSingularNumber = NStr("en = 'Role'");
	Row.WithoutData = True;

	// ExchangePlans
	Row = MetadataObjectCollectionProperties.Add();
	Row.Name = "ExchangePlans";
	Row.Synonym = NStr("en = 'Exchange plans'");
	Row.SingularName = "ExchangePlan";
	Row.SynonymInSingularNumber = NStr("en = 'Exchange plan'");
	
	// Catalogs
	Row = MetadataObjectCollectionProperties.Add();
	Row.Name = "Catalogs";
	Row.Synonym = NStr("en = 'Catalogs'");
	Row.SingularName = "Catalog";
	Row.SynonymInSingularNumber = NStr("en = 'Catalog'");
	
	// Documents
	Row = MetadataObjectCollectionProperties.Add();
	Row.Name = "Documents";
	Row.Synonym = NStr("en = 'Documents'");
	Row.SingularName = "Document";
	Row.SynonymInSingularNumber = NStr("en = 'Document'");
	
	// DocumentJournals
	Row = MetadataObjectCollectionProperties.Add();
	Row.Name = "DocumentJournals";
	Row.Synonym = NStr("en = 'Document journals'");
	Row.SingularName = "DocumentJournal";
	Row.SynonymInSingularNumber = NStr("en = 'Document journal'");
	Row.WithoutData = True;
	
	// Reports
	Row = MetadataObjectCollectionProperties.Add();
	Row.Name = "Reports";
	Row.Synonym = NStr("en = 'Reports'");
	Row.SingularName = "Report";
	Row.SynonymInSingularNumber = NStr("en = 'Report'");
	Row.WithoutData = True;
	
	// DataProcessors
	Row = MetadataObjectCollectionProperties.Add();
	Row.Name = "DataProcessors";
	Row.Synonym = NStr("en = 'Data processors'");
	Row.SingularName = "DataProcessor";
	Row.SynonymInSingularNumber = NStr("en = 'Data processor'");
	Row.WithoutData = True;
	
	// ChartsOfCharacteristicTypes
	Row = MetadataObjectCollectionProperties.Add();
	Row.Name = "ChartsOfCharacteristicTypes";
	Row.Synonym = NStr("en = 'Charts of characteristic types'");
	Row.SingularName = "ChartOfCharacteristicTypes";
	Row.SynonymInSingularNumber = NStr("en = 'Chart of characteristic types'");
	
	// ChartsOfAccounts
	Row = MetadataObjectCollectionProperties.Add();
	Row.Name = "ChartsOfAccounts";
	Row.Synonym = NStr("en = 'Charts of accounts'");
	Row.SingularName = "ChartOfAccounts";
	Row.SynonymInSingularNumber = NStr("en = 'Chart of accounts'");
	
	// ChartsOfCalculationTypes
	Row = MetadataObjectCollectionProperties.Add();
	Row.Name = "ChartsOfCalculationTypes";
	Row.Synonym = NStr("en = 'Charts of calculation types'");
	Row.SingularName = "ChartOfCalculationTypes";
	Row.SynonymInSingularNumber = NStr("en = 'Chart of calculation types'");
	
	// InformationRegisters
	Row = MetadataObjectCollectionProperties.Add();
	Row.Name = "InformationRegisters";
	Row.Synonym = NStr("en = 'Information registers'");
	Row.SingularName = "InformationRegister";
	Row.SynonymInSingularNumber = NStr("en = 'Information register'");
	
	// AccumulationRegisters
	Row = MetadataObjectCollectionProperties.Add();
	Row.Name = "AccumulationRegisters";
	Row.Synonym = NStr("en = 'Accumulation registers'");
	Row.SingularName = "AccumulationRegister";
	Row.SynonymInSingularNumber = NStr("en = 'Accumulation register'");
	
	// AccountingRegisters
	Row = MetadataObjectCollectionProperties.Add();
	Row.Name = "AccountingRegisters";
	Row.Synonym = NStr("en = 'Accounting registers'");
	Row.SingularName = "AccountingRegister";
	Row.SynonymInSingularNumber = NStr("en = 'Accounting register'");
	
	// CalculationRegisters
	Row = MetadataObjectCollectionProperties.Add();
	Row.Name = "CalculationRegisters";
	Row.Synonym = NStr("en = 'Calculation registers'");
	Row.SingularName = "CalculationRegister";
	Row.SynonymInSingularNumber = NStr("en = 'Calculation register'");
	
	// BusinessProcesses
	Row = MetadataObjectCollectionProperties.Add();
	Row.Name = "BusinessProcesses";
	Row.Synonym = NStr("en = 'Business processes'");
	Row.SingularName = "BusinessProcess";
	Row.SynonymInSingularNumber = NStr("en = 'Business process'");
	
	// Tasks
	Row = MetadataObjectCollectionProperties.Add();
	Row.Name = "Tasks";
	Row.Synonym = NStr("en = 'Tasks'");
	Row.SingularName = "Task";
	Row.SynonymInSingularNumber = NStr("en = 'Task'");
	
	// Filling additional properties
	CatalogManager = CommonUse.ObjectManagerByFullName("Catalog.MetadataObjectIDs");
	For Each Row In MetadataObjectCollectionProperties Do
		Try
			Row.CollectionID = CatalogManager[Row.Name];
		Except
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = '%1
				 |metadata object collection ID is not found.
				 |
				 |You have to add a predefined item to
				 |Catalog.MetadataObjectIDs.'"),
				Row.Name);
		EndTry;
		Row.CollectionOrder = MetadataObjectCollectionProperties.IndexOf(Row);
	EndDo;
	
	MetadataObjectCollectionProperties.Indexes.Add("CollectionID");
	
	Return MetadataObjectCollectionProperties;
	
EndFunction

Function EventHandlerParameters()
	
	Properties = New Structure;
	Properties.Insert("Old", MetadataObjectIDProperties());
	Properties.Insert("New", MetadataObjectIDProperties());
	Properties.Insert("ReplaceRefs", False);
	
	Return Properties;
	
EndFunction

Function MetadataObjectIDProperties()
	
	Properties = New Structure;
	Properties.Insert("Ref", EmptyRef());
	Properties.Insert("Parent", EmptyRef());
	Properties.Insert("Name", "");
	Properties.Insert("Synonym", "");
	Properties.Insert("FullName", "");
	Properties.Insert("FullSynonym", "");
	Properties.Insert("WithoutData", False);
	
	Return Properties;
	
EndFunction

Procedure RaisePresetIDsFillingErrorException(Val PresetIDs, Val MetadataObjectCollectionProperties)
	
	MetadataObject = Metadata.FindByFullName(PresetIDs[0].FullName);
	
	If MetadataObject = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Error in 
			 |CommonUseOverridable.FillPresetObjectIdentifiersOfMetadata()
			 |procedure.
			 |
			 |%1 ID is set
			 |for a not existent metadata object
			 |%2.'"),
			PresetIDs[0].ID.UUID(),
			PresetIDs[0].FullName);
	Else
		SingularCollectionName = StringFunctionsClientServer.SplitStringIntoSubstringArray(PresetIDs[0].FullName, ".")[0];
		CollectionDetails = MetadataObjectCollectionProperties.Find(SingularCollectionName, "SingularName");
		
		If CollectionDetails = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error in
				 |CommonUseOverridable.FillPresetObjectIdentifiersOfMetadata()
				 |procedure.
				 |
				 |For %1
				 |metadata object
				 |%2 ID is set,
				 |but for metadata objects of %3 type
				 |IDs are not supported.'"),
				PresetIDs[0].FullName,
				PresetIDs[0].ID.UUID(),
				SingularCollectionName);
		EndIf;
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Error in
			 |PredefinedObjectIdentifiersOfMetadata()
			 |procedure.
			 |
			 |for %1
			 |metadata object
			 |%2 ID is set,
			 |but to use this ID, all parent metadata object IDs 
			 |must be set.'"),
			PresetIDs[0].FullName,
			PresetIDs[0].ID.UUID() );
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions of ID replacement in the Infobase

Procedure ReplaceRefInInfoBase(OldRef, NewRef)
	
	RefArray = New Array;
	RefArray.Add(OldRef);
	
	FoundData = FindByRef(RefArray);
	
	FoundData.Columns[0].Name = "Ref";
	FoundData.Columns[1].Name = "Data";
	FoundData.Columns[2].Name = "Metadata";
	FoundData.Columns.Add("Enabled");
	FoundData.FillValues(True, "Enabled");
	
	Replaceable = New Map;
	Replaceable.Insert(OldRef, NewRef);
	
	ExecuteItemReplacement(Replaceable, FoundData, True);
	
EndProcedure

// The function is from the SearchAndReplaceValues universal dara processor
// Changes:
// - Removed form handlers 
// - Removed the UserInterruptProcessing() procedure 
// - InformationRegisters[TableRow.Metadata.Name] have been replaced by
// CommonUse.ObjectManagerByFullName(TableRow.Metadata.FullName())
//
Function ExecuteItemReplacement(Val Replaceable, Val RefsTable, Val DisableWriteControl = False, Val ExecuteTransactioned = False)
	
	Parameters = New Structure;
	
	For Each AccountingRegister In Metadata.AccountingRegisters Do
		Parameters.Insert(AccountingRegister.Name + "ExtDimension", AccountingRegister.ChartOfAccounts.MaxExtDimensionCount);
		Parameters.Insert(AccountingRegister.Name + "Correspondence", AccountingRegister.Correspondence);
	EndDo;
	
	Parameters.Insert("Object", Undefined);
	
	RefToProcess = Undefined;
	HasException = False;
		
	If ExecuteTransactioned Then
		BeginTransaction();
	EndIf;
	
	Try
		For Each TableRow In RefsTable Do
			If Not TableRow.Enabled Then
				Continue;
			EndIf;
			CorrectItem = Replaceable[TableRow.Ref];
			
			Ref = TableRow.Ref;
			
			If RefToProcess <> TableRow.Data Then
				If RefToProcess <> Undefined And Parameters.Object <> Undefined Then
					
					If DisableWriteControl Then
						Parameters.Object.DataExchange.Load = True;
					EndIf;
					
					Try
						Parameters.Object.Write();
					Except
						HasException = True;
						If ExecuteTransactioned Then
							Raise;
						EndIf;
						ReportError(ErrorInfo());
					EndTry;
					Parameters.Object = Undefined;
				EndIf;
				RefToProcess = TableRow.Data;
			EndIf;
			
			If Metadata.Documents.Contains(TableRow.Metadata) Then
				
				If Parameters.Object = Undefined Then
					Parameters.Object = TableRow.Data.GetObject();
				EndIf;
				
				For Each Attribute In TableRow.Metadata.Attributes Do
					If Attribute.Type.ContainsType(TypeOf(Ref)) And Parameters.Object[Attribute.Name] = Ref Then
						Parameters.Object[Attribute.Name] = CorrectItem;
					EndIf;
				EndDo;
					
				For Each TabularSection In TableRow.Metadata.TabularSections Do
					For Each Attribute In TabularSection.Attributes Do
						If Attribute.Type.ContainsType(TypeOf(Ref)) Then
							TabularSectionRow = Parameters.Object[TabularSection.Name].Find(Ref, Attribute.Name);
							While TabularSectionRow <> Undefined Do
								TabularSectionRow[Attribute.Name] = CorrectItem;
								TabularSectionRow = Parameters.Object[TabularSection.Name].Find(Ref, Attribute.Name);
							EndDo;
						EndIf;
					EndDo;
				EndDo;
				
				For Each RegisterRecord In TableRow.Metadata.RegisterRecords Do
					
					IsAccountingRegisterRecord = Metadata.AccountingRegisters.Contains(RegisterRecord);
					HasCorrespondence = IsAccountingRegisterRecord And Parameters[RegisterRecord.Name + "Correspondence"];
					
					RecordSet = Parameters.Object.RegisterRecords[RegisterRecord.Name];
					RecordSet.Read();
					MustWrite = False;
					SetTable = RecordSet.Unload();
					
					If SetTable.Count() = 0 Then
						Continue;
					EndIf;
					
					ColumnNames = New Array;
					
					// Getting names of dimentions that can contain a reference
					For Each Dimension In RegisterRecord.Dimensions Do
						
						If Dimension.Type.ContainsType(TypeOf(Ref)) Then
							
							If IsAccountingRegisterRecord Then
								
								If Dimension.AccountingFlag <> Undefined Then
									
									ColumnNames.Add(Dimension.Name + "Dr");
									ColumnNames.Add(Dimension.Name + "Cr");
								Else
									ColumnNames.Add(Dimension.Name);
								EndIf;
							Else
								ColumnNames.Add(Dimension.Name);
							EndIf;
						EndIf;
					EndDo;
					
					// Getting names of resources that can contain a reference
					If Metadata.InformationRegisters.Contains(RegisterRecord) Then
						For Each Resource In RegisterRecord.Resources Do
							If Resource.Type.ContainsType(TypeOf(Ref)) Then
								ColumnNames.Add(Resource.Name);
							EndIf;
						EndDo;
					EndIf;
					
					// Getting names of attributes that can contain a reference
					For Each Attribute In RegisterRecord.Attributes Do
						If Attribute.Type.ContainsType(TypeOf(Ref)) Then
							ColumnNames.Add(Attribute.Name);
						EndIf;
					EndDo;
					
					// Executing replacements in the table
					For Each ColumnName In ColumnNames Do
						TabularSectionRow = SetTable.Find(Ref, ColumnName);
						While TabularSectionRow <> Undefined Do
							TabularSectionRow[ColumnName] = CorrectItem;
							MustWrite = True;
							TabularSectionRow = SetTable.Find(Ref, ColumnName);
						EndDo;
					EndDo;
					
					If Metadata.AccountingRegisters.Contains(RegisterRecord) Then
						
						For ExtDimensionIndex = 1 to Parameters[RegisterRecord.Name + "ExtDimension"] Do
							If HasCorrespondence Then
								TabularSectionRow = SetTable.Find(Ref, "ExtDimensionDr"+ExtDimensionIndex);
								While TabularSectionRow <> Undefined Do
									TabularSectionRow["ExtDimensionDr"+ExtDimensionIndex] = CorrectItem;
									MustWrite = True;
									TabularSectionRow = SetTable.Find(Ref, "ExtDimensionDr"+ExtDimensionIndex);
								EndDo;
								TabularSectionRow = SetTable.Find(Ref, "ExtDimensionCr"+ExtDimensionIndex);
								While TabularSectionRow <> Undefined Do
									TabularSectionRow["ExtDimensionCr"+ExtDimensionIndex] = CorrectItem;
									MustWrite = True;
									TabularSectionRow = SetTable.Find(Ref, "ExtDimensionCr"+ExtDimensionIndex);
								EndDo;
							Else
								TabularSectionRow = SetTable.Find(Ref, "ExtDimension"+ExtDimensionIndex);
								While TabularSectionRow <> Undefined Do
									TabularSectionRow["ExtDimension"+ExtDimensionIndex] = CorrectItem;
									MustWrite = True;
									TabularSectionRow = SetTable.Find(Ref, "ExtDimension"+ExtDimensionIndex);
								EndDo;
							EndIf;
						EndDo;
						
						If Ref.Metadata() = RegisterRecord.ChartOfAccounts Then
							For Each TabularSectionRow In SetTable Do
								If HasCorrespondence Then
									If TabularSectionRow.AccountDr = Ref Then
										TabularSectionRow.AccountDr = CorrectItem;
										MustWrite = True;
									EndIf;
									If TabularSectionRow.AccountCr = Ref Then
										TabularSectionRow.AccountCr = CorrectItem;
										MustWrite = True;
									EndIf;
								Else
									If TabularSectionRow.Account = Ref Then
										TabularSectionRow.Account = CorrectItem;
										MustWrite = True;
									EndIf;
								EndIf;
							EndDo;
						EndIf;
					EndIf;
					
					If Metadata.CalculationRegisters.Contains(RegisterRecord) Then
						TabularSectionRow = SetTable.Find(Ref, "CalculationType");
						While TabularSectionRow <> Undefined Do
							TabularSectionRow["CalculationType"] = CorrectItem;
							MustWrite = True;
							TabularSectionRow = SetTable.Find(Ref, "CalculationType");
						EndDo;
					EndIf;
					
					If MustWrite Then
						RecordSet.Load(SetTable);
						If DisableWriteControl Then
							RecordSet.DataExchange.Load = True;
						EndIf;
						Try
							RecordSet.Write();
						Except
							HasException = True;
							If ExecuteTransactioned Then
								Raise;
							EndIf;
							ReportError(ErrorInfo());
						EndTry;
					EndIf;
				EndDo;
				
				For Each Sequence In Metadata.Sequences Do
					If Sequence.Documents.Contains(TableRow.Metadata) Then
						MustWrite = False;
						RecordSet = Sequences[Sequence.Name].CreateRecordSet();
						RecordSet.Filter.Recorder.Set(TableRow.Data);
						RecordSet.Read();
						
						If RecordSet.Count() > 0 Then
							For Each Dimension In Sequence.Dimensions Do
								If Dimension.Type.ContainsType(TypeOf(Ref)) And RecordSet[0][Dimension.Name]=Ref Then
									RecordSet[0][Dimension.Name] = CorrectItem;
									MustWrite = True;
								EndIf;
							EndDo;
							If MustWrite Then
								If DisableWriteControl Then
									RecordSet.DataExchange.Load = True;
								EndIf;
								Try
									RecordSet.Write();
								Except
									HasException = True;
									If ExecuteTransactioned Then
										Raise;
									EndIf;
									ReportError(ErrorInfo());
								EndTry;
							EndIf;
						EndIf;
					EndIf;
				EndDo;
				
			ElsIf Metadata.Catalogs.Contains(TableRow.Metadata) Then
				
				If Parameters.Object = Undefined Then
					Parameters.Object = TableRow.Data.GetObject();
				EndIf;
				
				If TableRow.Metadata.Owners.Contains(Ref.Metadata()) And Parameters.Object.Owner = Ref Then
					Parameters.Object.Owner = CorrectItem;
				EndIf;
				
				If TableRow.Metadata.Hierarchical And Parameters.Object.Parent = Ref Then
					Parameters.Object.Parent = CorrectItem;
				EndIf;
				
				For Each Attribute In TableRow.Metadata.Attributes Do
					If Attribute.Type.ContainsType(TypeOf(Ref)) And Parameters.Object[Attribute.Name] = Ref Then
						Parameters.Object[Attribute.Name] = CorrectItem;
					EndIf;
				EndDo;
				
				For Each TS In TableRow.Metadata.TabularSections Do
					For Each Attribute In TS.Attributes Do
						If Attribute.Type.ContainsType(TypeOf(Ref)) Then
							TabularSectionRow = Parameters.Object[TS.Name].Find(Ref, Attribute.Name);
							While TabularSectionRow <> Undefined Do
								TabularSectionRow[Attribute.Name] = CorrectItem;
								TabularSectionRow = Parameters.Object[TS.Name].Find(Ref, Attribute.Name);
							EndDo;
						EndIf;
					EndDo;
				EndDo;
				
			ElsIf Metadata.ChartsOfCharacteristicTypes.Contains(TableRow.Metadata)
			 or Metadata.ChartsOfAccounts.Contains (TableRow.Metadata)
			 or Metadata.ChartsOfCalculationTypes.Contains (TableRow.Metadata)
			 or Metadata.Tasks.Contains (TableRow.Metadata)
			 or Metadata.BusinessProcesses.Contains (TableRow.Metadata) Then
				
				If Parameters.Object = Undefined Then
					Parameters.Object = TableRow.Data.GetObject();
				EndIf;
				
				For Each Attribute In TableRow.Metadata.Attributes Do
					If Attribute.Type.ContainsType(TypeOf(Ref)) And Parameters.Object[Attribute.Name] = Ref Then
						Parameters.Object[Attribute.Name] = CorrectItem;
					EndIf;
				EndDo;
				
				For Each TS In TableRow.Metadata.TabularSections Do
					For Each Attribute In TS.Attributes Do
						If Attribute.Type.ContainsType(TypeOf(Ref)) Then
							TabularSectionRow = Parameters.Object[TS.Name].Find(Ref, Attribute.Name);
							While TabularSectionRow <> Undefined Do
								TabularSectionRow[Attribute.Name] = CorrectItem;
								TabularSectionRow = Parameters.Object[TS.Name].Find(Ref, Attribute.Name);
							EndDo;
						EndIf;
					EndDo;
				EndDo;
				
			ElsIf Metadata.Constants.Contains(TableRow.Metadata) Then
				
				Constants[TableRow.Metadata.Name].Set(CorrectItem);
				
			ElsIf Metadata.InformationRegisters.Contains(TableRow.Metadata) Then
				
				DimensionStructure = New Structure;
				RecordSet = CommonUse.ObjectManagerByFullName(TableRow.Metadata.FullName()).CreateRecordSet();
				For Each Dimension In TableRow.Metadata.Dimensions Do
					RecordSet.Filter[Dimension.Name].Set(TableRow.Data[Dimension.Name]);
					DimensionStructure.Insert(Dimension.Name);
				EndDo;
				If TableRow.Metadata.InformationRegisterPeriodicity <> Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical Then
					RecordSet.Filter["Period"].Set(TableRow.Data.Period);
				EndIf;
				RecordSet.Read();
				
				If RecordSet.Count() = 0 Then
					Continue;
				EndIf;
				
				SetTable = RecordSet.Unload();
				RecordSet.Clear();
				
				If DisableWriteControl Then
					RecordSet.DataExchange.Load = True;
				EndIf;
				
				
				If Not ExecuteTransactioned Then
					BeginTransaction();
				EndIf;
				
				Try
					RecordSet.Write();
					
					For Each Column In SetTable.Columns Do
						If SetTable[0][Column.Name] = Ref Then
							SetTable[0][Column.Name] = CorrectItem;
							If DimensionStructure.Property(Column.Name) Then
								RecordSet.Filter[Column.Name].Set(CorrectItem);
							EndIf;
							
						EndIf;
					EndDo;
					
					RecordSet.Load(SetTable);
					
					RecordSet.Write();
					
					If Not ExecuteTransactioned Then
						CommitTransaction();
					EndIf;
					
				Except
					HasException = True;
					If ExecuteTransactioned Then
						Raise;
					EndIf;
					RollbackTransaction();
					ReportError(ErrorInfo());
				EndTry;
			Else
				ReportError(StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Values in data of %1 type are not replaced'"), TableRow.Metadata));
			EndIf;
		EndDo;
	
		If Parameters.Object <> Undefined Then
			If DisableWriteControl Then
				Parameters.Object.DataExchange.Load = True;
			EndIf;
			Try
				Parameters.Object.Write();
			Except
				HasException = True;
				If ExecuteTransactioned Then
					Raise;
				EndIf;
				ReportError(ErrorInfo());
			EndTry;
		EndIf;
		
		If ExecuteTransactioned Then
			CommitTransaction();
		EndIf;
	Except
		HasException = True;
		If ExecuteTransactioned Then
			RollbackTransaction();
		EndIf;
		ReportError(ErrorInfo());
	EndTry;
	
	Return Not HasException;
	
EndFunction

// The procedure is from the SearchAndReplaceValues universal data processor
// Changes:
//- Message(...) method have been replaced with WriteLogEvent(...)
//
Procedure ReportError(Val Details)
	
	If TypeOf(Details) = Type("ErrorInfo") Then
		Details = ?(Details.Cause = Undefined, Details, Details.Cause).Details;
	EndIf;
	
	WriteLogEvent(
		NStr("en = 'Metadata object IDs. ID replacement'", Metadata.DefaultLanguage.LanguageCode),
		EventLogLevel.Error,
		,
		,
		Details,
		EventLogEntryTransactionMode.Independent);
	
EndProcedure

