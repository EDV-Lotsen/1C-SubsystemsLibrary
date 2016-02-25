#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Returns locked attribute names for the Object attribute edit prohibition
// subsystem
//
// Returns:
//  Array of String - names of attributes to lock.
// 
Function GetObjectAttributesToLock() Export
	
	Result = New Array;
	
	Result.Add("ValueType");
	
	Return Result;
	
EndFunction

// Returns the list of attributes that can be edited
// using the Batch object modification data processor. 
//
Function BatchProcessingEditableAttributes() Export
	
	EditableAttributes = New Array;
	
	EditableAttributes.Add("MultilineInputField");
	EditableAttributes.Add("ValueFormTitle");
	EditableAttributes.Add("ValueChoiceFormTitle");
	EditableAttributes.Add("FormatProperties");
	EditableAttributes.Add("Comment");
	EditableAttributes.Add("ToolTip");
	
	Return EditableAttributes;
	
EndFunction

#EndRegion

#Region InternalProceduresAndFunctions

// Changes the property setting from the common property or property value common list
// into a separate property with individual value list.
//
Procedure ChangePropertySetting(Parameters, StorageAddress) Export
	
	Property           = Parameters.Property;
	CurrentPropertySet = Parameters.CurrentPropertySet;
	
	OpenProperty = Undefined;
	DataLock = New DataLock;
	
	LockItem = DataLock.Add("ChartOfCharacteristicTypes.AdditionalDataAndAttributes");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Ref", Property);
	
	LockItem = DataLock.Add("Catalog.AdditionalDataAndAttributeSets");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Ref", CurrentPropertySet);
	
	LockItem = DataLock.Add("Catalog.PropertyObjectValues");
	LockItem.Mode = DataLockMode.Exclusive;
	
	LockItem = DataLock.Add("Catalog.ObjectPropertyValueHierarchy");
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		DataLock.Lock();
		
		PropertyObject = Property.GetObject();
		
		Query = New Query;
		If ValueIsFilled(PropertyObject.AdditionalValuesOwner) Then
			Query.SetParameter("Owner", PropertyObject.AdditionalValuesOwner);
			PropertyObject.AdditionalValuesOwner = Undefined;
			PropertyObject.Write();
		Else
			Query.SetParameter("Owner", Property);
			NewObject = ChartsOfCharacteristicTypes.AdditionalDataAndAttributes.CreateItem();
			FillPropertyValues(NewObject, PropertyObject, , "Parent");
			PropertyObject = NewObject;
			PropertyObject.PropertiesSet = CurrentPropertySet;
			PropertyObject.Write();
			
			PropertySetObject = CurrentPropertySet.GetObject();
			If PropertyObject.IsAdditionalData Then
				FoundRow = PropertySetObject.AdditionalData.Find(Property, "Property");
				If FoundRow = Undefined Then
					PropertySetObject.AdditionalData.Add().Property = PropertyObject.Ref;
				Else
					FoundRow.Property = PropertyObject.Ref;
					FoundRow.DeletionMark = False;
				EndIf;
			Else
				FoundRow = PropertySetObject.AdditionalAttributes.Find(Property, "Property");
				If FoundRow = Undefined Then
					PropertySetObject.AdditionalAttributes.Add().Property = PropertyObject.Ref;
				Else
					FoundRow.Property = PropertyObject.Ref;
					FoundRow.DeletionMark = False;
				EndIf;
			EndIf;
			PropertySetObject.Write();
		EndIf;
		
		OpenProperty = PropertyObject.Ref;
		
		OwnerMetadata = PropertyManagementInternal.PropertySetValueOwnerMetadata(
			PropertyObject.PropertiesSet, False);
		
		If OwnerMetadata = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error changing the %1 property settings.
				           |The %2 property set not associated with any property value owner.'"),
				Property,
				PropertyObject.PropertiesSet);
		EndIf;
		
		OwnerFullName = OwnerMetadata.FullName();
		ReferenceMap = New Map;
		
		HaveAdditionalValues = PropertyManagementInternal.ValueTypeContainsPropertyValues(
			PropertyObject.ValueType);
		
		If HaveAdditionalValues Then
			
			If PropertyObject.ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValues")) Then
				CatalogName = "ObjectPropertyValues";
				IsFolder      = "Values.IsFolder";
			Else
				CatalogName = "ObjectPropertyValueHierarchy";
				IsFolder      = "False AS IsFolder";
			EndIf;
			
			Query.Text =
			"SELECT
			|	Values.Ref AS Ref,
			|	Values.Parent AS ReferenceParent,
			|	Values.IsFolder,
			|	Values.DeletionMark,
			|	Values.Description,
			|	Values.Weight
			|FROM
			|	Catalog.ObjectPropertyValue AS Values
			|WHERE
			|	Values.Owner = &Owner
			|TOTALS BY
			|	Ref HIERARCHY";
			Query.Text = StrReplace(Query.Text, "ObjectPropertyValue", CatalogName);
			Query.Text = StrReplace(Query.Text, "Values.IsFolder", IsFolder);
			
			Data = Query.Execute().Unload(QueryResultIteration.ByGroupsWithHierarchy);
			CreateGroupsAndValues(Data.Rows, ReferenceMap, CatalogName, PropertyObject.Ref);
			
		ElsIf Property = PropertyObject.Ref Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error changing the %1 property settings.
				           |The value type does not contain additional values.'"),
				Property);
		EndIf;
		
		If Property <> PropertyObject.Ref
		 Or ReferenceMap.Quantity() > 0 Then
			
			DataLock = New DataLock;
			
			ItemLock = DataLock.Add("InformationRegister.AdditionalData");
			ItemLock.Mode = DataLockMode.Exclusive;
			ItemLock.SetValue("Property", Property);
			
			ItemLock = DataLock.Add("InformationRegister.AdditionalData");
			ItemLock.Mode = DataLockMode.Exclusive;
			ItemLock.SetValue("Property", PropertyObject.Ref);
			
			// If the original property is common then one should get object set list
			// by each reference, and if the replaced common property is not only in
			// the target set then add a new property and value.
			//
			// For source common properties when their value owners have several  
			// property sets, this procedure can be especially long as requires
			// analysis of each object set of the owner because of having set content 
			// overrided in the CompleteObjectPropertySets procedure 
     // of the PropertyManagementOverridable common module.
			
			OwnerWithAdditionalAttributes = False;
			
			If PropertyManagementInternal.IsMetadataObjectWithAdditionalAttributes(OwnerMetadata) Then
				OwnerWithAdditionalAttributes = True;
				ItemLock = DataLock.Add(OwnerFullName);
				ItemLock.Mode = DataLockMode.Exclusive;
			EndIf;
			
			DataLock.Lock();
			
			OwnerEachObjectSetsAnalysIsRequired = False;
			
			If Property <> PropertyObject.Ref Then
				PredefinedName = StrReplace(OwnerMetadata.FullName(), ".", "_");
				Try
					RootSet = Catalogs.AdditionalDataAndAttributeSets[PredefinedName];
				Except
					RootSet = Undefined;
				EndTry;
				
				If RootSet <> Undefined Then
					If ValueIsFilled(CommonUse.ObjectAttributeValue(RootSet, "IsFolder")) = True Then
						EachOwnerObjectSetAnalysisRequired = True;
					EndIf;
				EndIf;
			EndIf;
			
			If EachOwnerObjectSetAnalysisRequired Then
				AnalysisQuery = New Query;
				AnalysisQuery.SetParameter("CommonProperty", Property);
				AnalysisQuery.SetParameter("NewPropertySet", PropertyObject.PropertySet);
				AnalysisQuery.Text =
				"SELECT TOP 1
				|	TRUE AS TrueValue
				|FROM
				|	Catalog.AdditionalDataAndAttributeSets.AdditionalData AS PropertySets
				|WHERE
				|	PropertySets.Ref <> &NewPropertySet
				|	AND PropertySets.Ref IN(&ObjectAllSets)
				|	AND PropertySets.Property = &CommonProperty";
			EndIf;
			
			Query = New Query;
			
			If Property = PropertyObject.Ref Then
				// If not separate property but whole additional value list was changed then
				// only additional value replacement is required.
				Query.TempTablesManager = New TempTablesManager;
				
				ValueTable = New ValueTable;
				ValueTable.Columns.Add("Value", New TypeDescription(
					"CatalogRef." + CatalogName));
				
				For Each KeyAndValue In ReferenceMap Do
					ValueTable.Add().Value = KeyAndValue.Key;
				EndDo;
				
				Query.SetParameter("ValueTable", ValueTable);
				
				Query.Text =
				"SELECT
				|	ValueTable.Value AS Value
				|INTO OldValues
				|FROM
				|	&ValueTable AS ValueTable
				|
				|INDEX BY
				|	Value";
				Query.Execute();
			EndIf;
			
			Query.SetParameter("Property", Property);
			AdditionalValueTypes = New Map;
			AdditionalValueTypes.Insert(Type("CatalogRef.ObjectPropertyValues"), True);
			AdditionalValueTypes.Insert(Type("CatalogRef.ObjectPropertyValueHierarchy"), True);
			
			// Additional data replacement.
			
			If Property = PropertyObject.Ref Then
				// If not property (already separated) but additional value list was changed  
				// then only additional value replacement is required.
				Query.Text =
				"SELECT TOP 1000
				|	AdditionalData.Object
				|FROM
				|	InformationRegister.AdditionalData AS AdditionalData
				|		INNER JOIN OldValues AS OldValues
				|		ON (VALUETYPE(AdditionalData.Object) = TYPE(Catalog.ObjectPropertyValue))
				|			AND (NOT AdditionalData.Object IN (&ProcessedObjects))
				|			AND (AdditionalData.Property = &Property)
				|			AND AdditionalData.Value = OldValues.Value";
			Else
				// If the property is changed, the common property becomes separated, 
				// and additional values are copied, then property and additional 
				// value replacement is required.
				Query.Text =
				"SELECT TOP 1000
				|	AdditionalData.Object
				|FROM
				|	InformationRegister.AdditionalData AS AdditionalData
				|WHERE
				|	VALUETYPE(AdditionalData.Object) = TYPE(Catalog.ObjectPropertyValue)
				|	AND NOT AdditionalData.Object IN (&ProcessedObjects)
				|	AND AdditionalData.Property = &Property";
			EndIf;
			
			Query.Text = StrReplace(Query.Text, "Catalog.ObjectPropertyValue", 
OwnerFullName);
			
			OldRecordSet = InformationRegisters.AdditionalData.CreateRecordSet();
			NewRecordSet = InformationRegisters.AdditionalData.CreateRecordSet();
			NewRecordSet.Add();
			
			ProcessedObjects = New Array;
			
			While True Do
				Query.SetParameter("ProcessedObjects", ProcessedObjects);
				Selection = Query.Execute().Select();
				If Selection.Count() = 0 Then
					Break;
				EndIf;
				While Selection.Next() Do
					Replace = True;
					If EachOwnerObjectSetAnalysisRequired Then
						AnalysisQuery.SetParameter("ObjectAllSets",
							PropertyManagementInternal.GetObjectPropertySets(
								Selection.Object).UnloadColumn("Set"));
						Replace = AnalysisQuery.Execute().IsEmpty();
					EndIf;
					OldRecordSet.Filter.Object.Set(Selection.Object);
					OldRecordSet.Filter.Property.Set(Property);
					OldRecordSet.Read();
					If OldRecordSet.Count() > 0 Then
						NewRecordSet[0].Object = Selection.Object;
						NewRecordSet[0].Property = PropertyObject.Ref;
						Value = OldRecordSet[0].Value;
						If AdditionalValueTypes[TypeOf(Value)] = Undefined Then
							NewRecordSet[0].Value = Value;
						Else
							NewRecordSet[0].Value = ReferenceMap[Value];
						EndIf;
						NewRecordSet.Filter.Object.Set(Selection.Object);
						NewRecordSet.Filter.Property.Set(NewRecordSet[0].Property);
						If Replace Then
							OldRecordSet.Clear();
							OldRecordSet.DataExchange.Load = True;
							OldRecordSet.Write();
						Else
							ProcessedObjects.Add(Selection.Object);
						EndIf;
						NewRecordSet.DataExchange.Load = True;
						NewRecordSet.Write();
					EndIf;
				EndDo;
			EndDo;
			
			// Additional attribute replacement.
			
			If OwnerWithAdditionalAttributes Then
				
				If EachOwnerObjectSetAnalysisRequired Then
					AnalysisQuery = New Query;
					AnalysisQuery.SetParameter("CommonProperty", Property);
					AnalysisQuery.SetParameter("NewPropertySet", PropertyObject.PropertySet);
					AnalysisQuery.Text =
					"SELECT TOP 1
					|	TRUE AS TrueValue
					|FROM
					|	Catalog.AdditionalDataAndAttributeSets.AdditionalAttributes AS PropertySets
					|WHERE
					|	PropertySets.Ref <> &NewPropertySet
					|	AND PropertySets.Ref IN(&ObjectAllSets)
					|	AND PropertySets.Property = &CommonProperty";
				EndIf;
				
				If Property = PropertyObject.Ref Then
					// If not property (already separated) but additional value list was changed  
					// then only additional value replacement is required.
					Query.Text =
					"SELECT TOP 1000
					|	CurrentTable.Ref AS Ref
					|FROM
					|	TableName AS CurrentTable
					|		INNER Connection OldValues AS OldValues
					|		ON (NOT CurrentTable.Ref IN (&ProcessedObjects))
					|			AND (CurrentTable.Property = &Property)
					|			AND CurrentTable.Value = OldValues.Value";
				Else
					// If the property is changed, the common property becomes separated, 
        // and additional values are copied, then property and additional 
        // value replacement is required.
					Query.Text =
					"SELECT TOP 1000
					|	CurrentTable.Ref AS Ref
					|FROM
					|	TableName AS CurrentTable
					|WHERE
					|	NOT CurrentTable.Ref IN (&ProcessedObjects)
					|	AND CurrentTable.Property = &Property";
				EndIf;
				Query.Text = StrReplace(Query.Text, "TableName", OwnerFullName + ".AdditionalAttributes");
				
				ProcessedObjects = New Array;
				
				While True Do
					Query.SetParameter("ProcessedObjects", ProcessedObjects);
					Selection = Query.Execute().Select();
					If Selection.Count() = 0 Then
						Break;
					EndIf;
					While Selection.Next() Do
						CurrentObject = Selection.Ref.GetObject();
						Replace = True;
						If EachOwnerObjectSetAnalysisRequired Then
							AnalysisQuery.SetParameter("ObjectAllSets",
								PropertyManagementInternal.GetObjectPropertySets(
									Selection.Ref).UnloadColumn("Set"));
							Replace = AnalysisQuery.Execute().IsEmpty();
						EndIf;
						For Each Row In CurrentObject.AdditionalAttributes Do
							If Row.Property = Property Then
								Value = Row.Value;
								If AdditionalValueTypes[TypeOf(Value)] <> Undefined Then
									Value = ReferenceMap[Value];
								EndIf;
								If Replace Then
									If Row.Property <> PropertyObject.Ref Then
										Row.Property = PropertyObject.Ref;
									EndIf;
									If Row.Value <> Value Then
										Row.Value = Value;
									EndIf;
								Else
									NewRow = CurrentObject.AdditionalAttributes.Add();
									NewRow.Property = PropertyObject.Ref;
									NewRow.Value = Value;
									ProcessedObjects.Add(CurrentObject.Ref);
									Break;
								EndIf;
							EndIf;
						EndDo;
						If CurrentObject.Modified() Then
							CurrentObject.DataExchange.Load = True;
							CurrentObject.Write();
						EndIf;
					EndDo;
				EndDo;
			EndIf;
			
			If Property = PropertyObject.Ref Then
				Query.TempTablesManager.Close();
			EndIf;
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	PutToTempStorage(OpenProperty, StorageAddress);
	
EndProcedure

Procedure CreateGroupsAndValues(Rows, ReferenceMap, CatalogName, Property, OldParent = Undefined)
	
	For Each Row In Rows Do
		If Row.Ref = OldParent Then
			Continue;
		EndIf;
		
		If Row.IsFolder = True Then
			NewObject = Catalogs[CatalogName].CreateFolder();
			FillPropertyValues(NewObject, Row, "Description, DeletionMark");
		Else
			NewObject = Catalogs[CatalogName].CreateItem();
			FillPropertyValues(NewObject, Row, "Description, Weight, DeletionMark");
		EndIf;
		NewObject.Owner = Property;
		If ValueIsFilled(Row.RefParent) Then
			NewObject.Parent = ReferenceMap[Row.RefParent];
		EndIf;
		NewObject.Write();
		ReferenceMap.Insert(Row.Ref, NewObject.Ref);
		
		CreateGroupsAndValues(Row.Rows, ReferenceMap, CatalogName, Property, Row.Ref);
	EndDo;
	
EndProcedure

#EndRegion

#EndIf
