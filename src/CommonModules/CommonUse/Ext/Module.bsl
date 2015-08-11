////////////////////////////////////////////////////////////////////////////////
// Base functionality subsystem.
// Common server procedures and functions for working with:
// - infobase data;
// - applied types and value collections;
// - math operations;
// - external connections;
// - forms;
// - types, metadata objects, and their string presentations;
// - metadata object type definition;
// - saving/reading/deleting settings to/from storages;
// - spreadsheet documents;
// - event log;
// - data separation mode;
// - API versioning.
//
// The module also includes auxiliary procedures and functions.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

////////////////////////////////////////////////////////////////////////////////
// Common procedures and functions for working with infobase data.

// Returns a structure that contains attribute values read from the infobase by
// object reference.
// 
// If access to any of the attributes is denied, an exception is raised.
// To be able to read attribute values irrespective of current user rights,
// turn privileged mode on.
// 
// Parameters:
// Ref - Reference - reference to a catalog, a document, or any other infobase object;
// AttributeNames - String or Structure - If AttributeNames is a string, it 
// contains attribute names separated by commas.
// Example: "Code, Description, Parent".
// If AttributeNames is a structure, its keys are used for resulting structure keys, 
// and its values are field names. If a value is empty, it is considered
// equal to the key.
// 
// Returns:
// Structure where keys are the same as in AttributeNames, and values are the retrieved field values.
//
Function GetAttributeValues(Ref, AttributeNames) Export

	If TypeOf(AttributeNames) = Type("Structure") Then
		AttributeStructure = AttributeNames;
	ElsIf TypeOf(AttributeNames) = Type("String") Then
		AttributeStructure = New Structure(AttributeNames);;
	Else
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Invalid AttributeNames type: %1.'"), 
			String(TypeOf(AttributeNames)));
	EndIf;

	FieldTexts = "";
	For Each KeyAndValue In AttributeStructure Do
		FieldName = ?(ValueIsFilled(KeyAndValue.Value), TrimAll(KeyAndValue.Value), TrimAll(KeyAndValue.Key));
		Alias = TrimAll(KeyAndValue.Key);
		FieldTexts = FieldTexts + ?(IsBlankString(FieldTexts), "", ",") + "
			|	" + FieldName + " AS " + Alias;
	EndDo;

	Query = New Query(
		"SELECT
		|" + FieldTexts + "
		|FROM
		|	" + Ref.Metadata().FullName() + " AS AliasForSpecifiedTable
		|WHERE
		|	AliasForSpecifiedTable.Ref = &Ref
		|");
	Query.SetParameter("Ref", Ref);
	Selection = Query.Execute().Select();
	Selection.Next();

	Result = New Structure;
	For Each KeyAndValue In AttributeStructure Do
		Result.Insert(KeyAndValue.Key);
	EndDo;
	FillPropertyValues(Result, Selection);

	Return Result;
EndFunction

// Returns an attribute value read from the infobase by object reference.
// 
// If access to the attribute is denied, an exception is raised.
// To be able to read the attribute value irrespective of current user rights,
// turn privileged mode on.
// 
// Parameters:
// Ref - AnyRef- reference to a catalog, a document, or any other infobase object;
// AttributeName - String, for example, "Code".
// 
// Returns:
// Arbitrary. It depends on the type of the read attribute.
//
Function GetAttributeValue(Ref, AttributeName) Export
	
	Result = GetAttributeValues(Ref, AttributeName);
	Return Result[AttributeName];
	
EndFunction 

// Returns a map that contains attribute values of several objects read from the infobase.
// 

// If access to any of the attributes is denied, an exception is raised.
// To be able to read attribute values irrespective of current user rights,
// turn privileged mode on.
// 
// Parameters:
// RefArray - array of references to objects of the same type (it is important
// that all referenced objects have the same type);

// AttributeNames - String - it must contains attribute names separated by commas.
// 			These attributes will be used for keys in the resulting structures.
// 			Example: "Code, Description, Parent".
// 
// Returns:
// Map where keys are object references, and values are structures that contains
// 			AttributeNames as keys and attribute values as values.
//
Function ObjectAttributeValues(RefArray, AttributeNames) Export
	
	AttributeValues = New Map;
	If RefArray.Count() = 0 Then
		Return AttributeValues;
	EndIf;
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	Ref, " + AttributeNames + "
		|FROM
		|	" + RefArray[0].Metadata().FullName() + " AS Table
		|WHERE
		|	Table.Ref IN (&RefArray)";
	Query.SetParameter("RefArray", RefArray);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Result = New Structure(AttributeNames);
		FillPropertyValues(Result, Selection);
		AttributeValues[Selection.Ref] = Result;
	EndDo;
	
	Return AttributeValues;
	
EndFunction

// Returns values of a specific attribute for several objects read from the infobase.
// 
// If access to the attribute is denied, an exception is raised.
// To be able to read attribute values irrespective of current user rights,
// turn privileged mode on.
// 
// Parameters:
// RefArray - array of references to objects of the same type (it is important that all
// referenced objects have the same type);
// AttributeName - String - for example, "Code".
// 
// Returns:
// Map where keys are object references, and values are attribute values.
//
Function ObjectAttributeValue(RefArray, AttributeName) Export
	
	AttributeValues = ObjectAttributeValues(RefArray, AttributeName);
	For Each Item In AttributeValues Do
		AttributeValues[Item.Key] = Item.Value[AttributeName];
	EndDo;
		
	Return AttributeValues;
	
EndFunction

// Checks whether the documents are posted.
//
// Parameters:
// Documents - Array - documents to be checked.
//
// Returns:
// Array - unposted documents from the Documents array.
//
Function CheckDocumentsPosted(Val Documents) Export
	
	Result = New Array;
	
	QueryPattern = 	
		"SELECT
		|	Document.Ref AS Ref
		|FROM
		|	&DocumentName AS Document
		|WHERE
		|	Document.Ref IN(&DocumentArray)
		|	AND (NOT Document.Posted)";
	
	UnionAllText =
		"
		|
		|UNION ALL
		|
		|";
		
	DocumentNames = New Array;
	For Each Document In Documents Do
		DocumentName = Document.Metadata().FullName();
		If DocumentNames.Find(DocumentName) = Undefined
		 And Metadata.Documents.Contains(Metadata.FindByFullName(DocumentName)) Then	
			DocumentNames.Add(DocumentName);
		EndIf;
	EndDo;
	
	QueryText = "";
	For Each DocumentName In DocumentNames Do
		If Not IsBlankString(QueryText) Then
			QueryText = QueryText + UnionAllText;
		EndIf;
		SubqueryText = StrReplace(QueryPattern, "&DocumentName", DocumentName);
		QueryText = QueryText + SubqueryText;
	EndDo;
		
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("DocumentArray", Documents);
	
	If Not IsBlankString(QueryText) Then
		Result = Query.Execute().Unload().UnloadColumn("Ref");
	EndIf;
	
	Return Result;
	
EndFunction

// Attempts to post the documents.
//
// Parameters:
//	Documents - Array - documents to be posted.
//
// Returns:
//	Array - array of structures with the following fields:
//									Ref - unposted document;
//									ErrorDescription - posting error text.
//
Function PostDocuments(Documents) Export
	
	UnpostedDocuments = New Array;
	
	For Each DocumentRef In Documents Do
		
		CompletedSuccessfully = False;
		DocumentObject = DocumentRef.GetObject();
		If DocumentObject.FillCheck() Then
			Try
				DocumentObject.Write(DocumentWriteMode.Posting);
				CompletedSuccessfully = True;
			Except
				ErrorPresentation = BriefErrorDescription(ErrorInfo());
				ErrorMessageText = NStr("en = 'Error posting the document: %1.'");
				ErrorMessageText = StringFunctionsClientServer.SubstituteParametersInString(ErrorMessageText, ErrorPresentation);
				WriteLogEvent(NStr("en = 'Posting documents before printing.'", Metadata.DefaultLanguage.LanguageCode),
					EventLogLevel.Information, DocumentObject.Metadata(), DocumentRef, 
					DetailErrorDescription(ErrorInfo()));
			EndTry;
		Else
			ErrorPresentation = NStr("en = 'Document fields are not filled.'");
		EndIf;
		
		If Not CompletedSuccessfully Then
			UnpostedDocuments.Add(New Structure("Ref,ErrorDescription", DocumentRef, ErrorPresentation));
		EndIf;
		
	EndDo;
	
	Return UnpostedDocuments;
	
EndFunction 

// Checks whether there are references to the object in the infobase.
//
// Parameters:
// Ref - Array of AnyRef.
//
// SearchInServiceObjects - Boolean - default value is False.
// If it is set to True, the list of search exceptions for references
// will not be taken into account.
//
// Returns:
// Boolean.
//
Function HasReferencesToObjectInInfoBase(Val RefOrRefArray, Val SearchInServiceObjects = False) Export
	
	SetPrivilegedMode(True);
	
	If TypeOf(RefOrRefArray) = Type("Array") Then
		RefArray = RefOrRefArray;
	Else
		RefArray = New Array;
		RefArray.Add(RefOrRefArray);
	EndIf;
	
	RefsTable = FindByRef(RefArray);
	
	If Not SearchInServiceObjects Then
		
		ServiceObjects = GetOverallRefSearchExceptionList();
		Exceptions = New Array;
		
		For Each ReferenceDetails In RefsTable Do
			If ServiceObjects.Find(ReferenceDetails.Metadata.FullName()) <> Undefined Then
				Exceptions.Add(ReferenceDetails);
			EndIf;
		EndDo;
		
		For Each ExceptionString In Exceptions Do
			RefsTable.Delete(ExceptionString);
		EndDo;
	EndIf;
	
	
	Return RefsTable.Count() > 0;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Common server procedures and functions for working with applied types and value collections.

// Gets a name of the enumeration value (enumeration value is a metadata object).
//
// Parameters:
// Value - enumeration value whose name will be retrieved.
//
// Returns:
// String - name of the enumeration value.
//
Function EnumValueName(Value) Export
	
	MetadataObject = Value.Metadata();
	
	ValueIndex = Enums[MetadataObject.Name].IndexOf(Value);
	
	Return MetadataObject.EnumValues[ValueIndex].Name;
	
EndFunction 

// Fills the destination array with unique values from the source array.
// If an element from the source array is already present, it is not added.
//
// Parameters:
// DestinationArray – Array – array to be filled with unique values;
// SourceArray – Array – array of values for filling DestinationArray.
//
Procedure FillArrayWithUniqueValues(DestinationArray, SourceArray) Export
	
	UniqueValues = New Map;
	
	For Each Value In DestinationArray Do
		UniqueValues.Insert(Value, True);
	EndDo;
	
	For Each Value In SourceArray Do
		If UniqueValues[Value] = Undefined Then
			DestinationArray.Add(Value);
			UniqueValues.Insert(Value, True);
		EndIf;
	EndDo;
	
EndProcedure

// Deletes AttributeArray elements that match to object attribute names from 
// the NoncheckableAttributeArray array.
// The procedure is intended for use in FillCheckProcessing event handlers.
//
// Parameters:
//	AttributeArray - Array of strings that contain names of object attributes;
//	NoncheckableAttributeArray - Array of string that contain names of object attributes
// that are excluded from checking.
//
Procedure DeleteNoncheckableAttributesFromArray(AttributeArray, NoncheckableAttributeArray) Export
	
	For Each ArrayElement In NoncheckableAttributeArray Do
	
		SequenceNumber = AttributeArray.Find(ArrayElement);
		If SequenceNumber <> Undefined Then
			AttributeArray.Delete(SequenceNumber);
		EndIf;
	
	EndDo;
	
EndProcedure

//	Converts the value table into an array.
//	Use this function to pass data that is received on the server as a value table 
//	to the client. This is only possible if all of values
//	from the value table can be passed to the client.
//
//	The resulting array contains structures that duplicate 
//	value table row structures.
//
//	It is recommended that you do not use this procedure to convert value tables
//	with a large number of rows.
//
//	Parameters: 
// ValueTable.
//
//	Returns:
// Array.
//
Function ValueTableToArray(ValueTable) Export
	
	Array = New Array();
	StructureAsString = "";
	CommaRequired = False;
	For Each Column In ValueTable.Columns Do
		If CommaRequired Then
			StructureAsString = StructureAsString + ",";
		EndIf;
		StructureAsString = StructureAsString + Column.Name;
		CommaRequired = True;
	EndDo;
	For Each String In ValueTable Do
		NewRow = New Structure(StructureAsString);
		FillPropertyValues(NewRow, String);
		Array.Add(NewRow);
	EndDo;
	Return Array;

EndFunction

// Creates a structure with properties whose names 
// match the value table column names
// of the passed row, and
// fills this structure with values from the row.
// 
// Parameters:
// ValueTableRow - ValueTableRow.
//
// Returns:
// Structure.
//
Function ValueTableRowToStructure(ValueTableRow) Export
	
	Structure = New Structure;
	For Each Column In ValueTableRow.Owner().Columns Do
		Structure.Insert(Column.Name, ValueTableRow[Column.Name]);
	EndDo;
	
	Return Structure;
	
EndFunction

Function GetStructureKeysAsString(Structure, Separator = ",") Export
	
	Result = "";
	
	For Each Item In Structure Do
		
		SeparatorChar = ?(IsBlankString(Result), "", Separator);
		
		Result = Result + SeparatorChar + Item.Key;
		
	EndDo;
	
	Return Result;
EndFunction

// Gets a string of structure keys separated by the separator character.
//
// Parameters:
//	Structure - Structure - structure whose keys will be converted into a string;
//	Separator - String - separator that will be inserted between the keys.
//
// Returns:
//	String - string of structure keys separated by the separator character.
//
Function StructureKeysToString(Structure, Separator = ",") Export
	
	Result = "";
	
	For Each Item In Structure Do
		
		SeparatorChar = ?(IsBlankString(Result), "", Separator);
		
		Result = Result + SeparatorChar + Item.Key;
		
	EndDo;
	
	Return Result;
EndFunction

// Creates a structure that matches the information register record manager. 
// 
// Parameters:
// RecordManager - InformationRegisterRecordManager;
// RegisterMetadata - information register metadata.
//
Function StructureByRecordManager(RecordManager, RegisterMetadata) Export
	
	RecordAsStructure = New Structure;
	
	If RegisterMetadata.InformationRegisterPeriodicity <> Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical Then
		RecordAsStructure.Insert("Period", RecordManager.Period);
	EndIf;
	For Each Field In RegisterMetadata.Dimensions Do
		RecordAsStructure.Insert(Field.Name, RecordManager[Field.Name]);
	EndDo;
	For Each Field In RegisterMetadata.Resources Do
		RecordAsStructure.Insert(Field.Name, RecordManager[Field.Name]);
	EndDo;
	For Each Field In RegisterMetadata.Attributes Do
		RecordAsStructure.Insert(Field.Name, RecordManager[Field.Name]);
	EndDo;
	
	Return RecordAsStructure;
	
EndFunction

// Creates an array and copies values from the row collection column into this array.
//
// Parameters:
//	RowCollection - collection where iteration using For each ... In ... Do operator 
//		is available;
//	ColumnName - String - name of the collection field to be retrieved;
//	UniqueValuesOnly - Boolean, optional - if it is True, the resulting array
//	will contain unique values only. 
//
Function UnloadColumn(RowCollection, ColumnName, UniqueValuesOnly = False) Export

	ValueArray = New Array;
	
	UniqueValues = New Map;
	
	For Each CollectionRow In RowCollection Do
		Value = CollectionRow[ColumnName];
		If UniqueValuesOnly And UniqueValues[Value] <> Undefined Then
			Continue;
		EndIf;
		ValueArray.Add(Value);
		UniqueValues.Insert(Value, True);
	EndDo; 
	
	Return ValueArray;
	
EndFunction

// Converts XML text into a value table.
// The function creates table columns based on the XML description.
//
// Parameters:
// XMLText - text in the XML format.
//
// XML schema:
//<?xml version="1.0" encoding="utf-8"?>
//<xs:schema attributeFormDefault="unqualified" elementFormDefault="qualified" xmlns:xs="http://www.w3.org/2001/XMLSchema">
// <xs:element name="Items">
//	<xs:complexType>
//	 <xs:sequence>
//		<xs:element maxOccurs="unbounded" name="Item">
//		 <xs:complexType>
//			<xs:attribute name="Code" type="xs:integer" use="required" />
//			<xs:attribute name="Name" type="xs:string" use="required" />
//			<xs:attribute name="Abbreviation" type="xs:string" use="required" />
//			<xs:attribute name="PostalCode" type="xs:string" use="required" />
//		 </xs:complexType>
//		</xs:element>
//	 </xs:sequence>
//	 <xs:attribute name="Description" type="xs:string" use="required" />
//	 <xs:attribute name="Columns" type="xs:string" use="required" />
//	</xs:complexType>
// </xs:element>
//</xs:schema>
//
// See examples of XML files in the demo configuration.
// 
// Example:
// ClassifierTable = ReadXMLToTable(InformationRegisters.AddressClassifier.
// GetTemplate("AddressClassifierUnits").GetText());
//
// Returns:
// ValueTable.
//
Function ReadXMLToTable(XMLText) Export
	
	Reader = New XMLReader;
	Reader.SetString(XMLText);
	
	// Reading the first node and checking it
	If Not Reader.Read() Then
		Raise("XML is empty.");
	ElsIf Reader.Name <> "Items" Then
		Raise("Error in the XML structure.");
	EndIf;
	
	// Getting table details and creating the table
	TableName = Reader.GetAttribute("Description");
	ColumnNames = StrReplace(Reader.GetAttribute("Columns"), ",", Chars.LF);
	Columns = StrLineCount(ColumnNames);
	
	ValueTable = New ValueTable;
	For Cnt = 1 to Columns Do
		ValueTable.Columns.Add(StrGetLine(ColumnNames, Cnt), New TypeDescription("String"));
	EndDo;
	
	// Filling the table with values
	While Reader.Read() Do
		
		If Reader.NodeType <> XMLNodeType.StartElement Then
			Continue;
		ElsIf Reader.Name <> "Item" Then
			Raise("Error in the XML structure.");
		EndIf;
		
		NewRow = ValueTable.Add();
		For Cnt = 1 to Columns Do
			ColumnName = StrGetLine(ColumnNames, Cnt);
			NewRow[Cnt-1] = Reader.GetAttribute(ColumnName);
		EndDo;
		
	EndDo;
	
	// Filling the resulting value table
	Result = New Structure;
	Result.Insert("TableName", TableName);
	Result.Insert("Data", ValueTable);
	
	Return Result;
	
EndFunction

// Compares two row collections. 
// Both collections must meet the following requirements:
//	- iteration using For each ... In ... Do operator is available;
//	- both collections include all columns that are passed to the ColumnNames parameter.
// If ColumnNames is empty, all columns included in one of the collections must be included 
// into the other one and vice versa.
//
// Parameters:
//	RowsCollection1 - collection that meets the requirements listed above;
//	RowsCollection2 - collection that meets the requirements listed above;
//	ColumnNames - String separated by commas - names of columns 
//						whose values will be compared. 
//						This parameter is optional for collections
//						that allow retrieving their column names:
//						ValueTable, ValueList, Map, and Structure.
//						If this parameter is not specified, values of all columns
//						will be compared. For collections of other types,
//						this parameter is mandatory.
//	ExcludingColumns	- names of columns whose values are not compared. Optional.
//	IncludingRowOrder - Boolean - If it is True, the collections are considered 
//						equal only if they have identical row order.
//
Function IdenticalCollections(RowsCollection1, RowsCollection2, ColumnNames = "", ExcludingColumns = "", IncludingRowOrder = False) Export
	
	// Collection types that allow retrieving their column names
	SpecialCollectionTypes = New Array;
	SpecialCollectionTypes.Add(Type("ValueTable"));
	SpecialCollectionTypes.Add(Type("ValueList"));
	
	KeyAndValueCollectionTypes = New Array;
	KeyAndValueCollectionTypes.Add(Type("Map"));
	KeyAndValueCollectionTypes.Add(Type("Structure"));
	KeyAndValueCollectionTypes.Add(Type("FixedMap"));
	KeyAndValueCollectionTypes.Add(Type("FixedStructure"));
	
	If IsBlankString(ColumnNames) Then
		If SpecialCollectionTypes.Find(TypeOf(RowsCollection1)) <> Undefined 
			Or KeyAndValueCollectionTypes.Find(TypeOf(RowsCollection1)) <> Undefined Then
			ColumnsToCompare = New Array;
			If TypeOf(RowsCollection1) = Type("ValueTable") Then
				For Each Column In RowsCollection1.Columns Do
					ColumnsToCompare.Add(Column.Name);
				EndDo;
			ElsIf TypeOf(RowsCollection1) = Type("ValueList") Then
				ColumnsToCompare.Add("Value");
				ColumnsToCompare.Add("Picture");
				ColumnsToCompare.Add("Check");
				ColumnsToCompare.Add("Presentation");
			ElsIf KeyAndValueCollectionTypes.Find(TypeOf(RowsCollection1)) <> Undefined Then
				ColumnsToCompare.Add("Key");
				ColumnsToCompare.Add("Value");
			EndIf;
		Else
			ErrorMessage = NStr("en = 'For collections of the %1 type, you have to specify names of fields that will be compared.'");
			Raise StringFunctionsClientServer.SubstituteParametersInString(ErrorMessage, TypeOf(RowsCollection1));
		EndIf;
	Else
		ColumnsToCompare = StringFunctionsClientServer.SplitStringIntoSubstringArray(ColumnNames);
	EndIf;

	// Removing excluded columns
	ColumnsToCompare = CommonUseClientServer.ReduceArray(ColumnsToCompare, 
						StringFunctionsClientServer.SplitStringIntoSubstringArray(ExcludingColumns));
						
	If IncludingRowOrder Then
		
		// Iterating both collections in parallel
		CollectionRowNumber1 = 0;
		For Each CollectionRow1 In RowsCollection1 Do
			// Searching for the same row in the second collection
			CollectionRowNumber2 = 0;
			HasCollectionRows2 = False;
			For Each CollectionRow2 In RowsCollection2 Do
				HasCollectionRows2 = True;
				If CollectionRowNumber2 = CollectionRowNumber1 Then
					Break;
				EndIf;
				CollectionRowNumber2 = CollectionRowNumber2 + 1;
			EndDo;
			If Not HasCollectionRows2 Then
				// Second collection has no rows
				Return False;
			EndIf;
			// Comparing field values for two rows
			For Each ColumnName In ColumnsToCompare Do
				If CollectionRow1[ColumnName] <> CollectionRow2[ColumnName] Then
					Return False;
				EndIf;
			EndDo;
			CollectionRowNumber1 = CollectionRowNumber1 + 1;
		EndDo;
		
		CollectionRowCount1 = CollectionRowNumber1;
		
		// Calculating rows in the second collection
		CollectionRowCount2 = 0;
		For Each CollectionRow2 In RowsCollection2 Do
			CollectionRowCount2 = CollectionRowCount2 + 1;
		EndDo;
		
		// If the first collection has no rows, 
		// the second collection must have no rows too.
		If CollectionRowCount1 = 0 Then
			For Each CollectionRow2 In RowsCollection2 Do
				Return False;
			EndDo;
			CollectionRowCount2 = 0;
		EndIf;
		
		// Number of rows must be the same in both collections
		If CollectionRowCount1 <> CollectionRowCount2 Then
			Return False;
		EndIf;
		
	Else
	
		// Compares two row collections without taking row order into account.
		
		// Accumulating compared rows in the first collection to ensure that:
		// - the search for identical rows is only performed once,
		// - all accumulated rows exist in the second collection.
		
		FilterRows = New ValueTable;
		FilterParameters = New Structure;
		For Each ColumnName In ColumnsToCompare Do
			FilterRows.Columns.Add(ColumnName);
			FilterParameters.Insert(ColumnName);
		EndDo;
		
		HasCollectionRows1 = False;
		For Each FilterRow In RowsCollection1 Do
			
			FillPropertyValues(FilterParameters, FilterRow);
			If FilterRows.FindRows(FilterParameters).Count() > 0 Then
				// Row with such field values is already checked
				Continue;
			EndIf;
			FillPropertyValues(FilterRows.Add(), FilterRow);
			
			// Calculating rows in the first collection
			CollectionRowsFound1 = 0;
			For Each CollectionRow1 In RowsCollection1 Do
				RowFits = True;
				For Each ColumnName In ColumnsToCompare Do
					If CollectionRow1[ColumnName] <> FilterRow[ColumnName] Then
						RowFits = False;
						Break;
					EndIf;
				EndDo;
				If RowFits Then
					CollectionRowsFound1 = CollectionRowsFound1 + 1;
				EndIf;
			EndDo;
			
			// Calculating rows in the second collection
			CollectionRowsFound2 = 0;
			For Each CollectionRow2 In RowsCollection2 Do
				RowFits = True;
				For Each ColumnName In ColumnsToCompare Do
					If CollectionRow2[ColumnName] <> FilterRow[ColumnName] Then
						RowFits = False;
						Break;
					EndIf;
				EndDo;
				If RowFits Then
					CollectionRowsFound2 = CollectionRowsFound2 + 1;
					// If the number of rows in the second collection is greater then the number of 
					// rows in the first one, the collections are not equal.
					If CollectionRowsFound2 > CollectionRowsFound1 Then
						Return False;
					EndIf;
				EndIf;
			EndDo;
			
			// The number of rows must be equal for both collections
			If CollectionRowsFound1 <> CollectionRowsFound2 Then
				Return False;
			EndIf;
			
			HasCollectionRows1 = True;
			
		EndDo;
		
		// If the first collection has no rows, 
		// the second collection must have no rows too.
		If Not HasCollectionRows1 Then
			For Each CollectionRow2 In RowsCollection2 Do
				Return False;
			EndDo;
		EndIf;
		
		// Checking that all rows from the second collection exist in the first one.
		For Each CollectionRow2 In RowsCollection2 Do
			FillPropertyValues(FilterParameters, CollectionRow2);
			If FilterRows.FindRows(FilterParameters).Count() = 0 Then
				Return False;
			EndIf;
		EndDo;
	
	EndIf;
	
	Return True;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Math procedures and functions

// Distributes the amount according to the weight coefficients.
//
// Parameters:
//		SrcAmount - amount to be distributed; 
//		CoeffArray - array of weight coefficients; 
//		Precision - rounding precision. Optional.
//
//	Returns:
//		AmountArray - Array - array that has the same length as the coefficient array 
//			dimension. It contains amounts calculated according to the distribution coefficients
// If distribution cannot be performed (amount = 0, number of coefficients = 0,
// or coefficient sum = 0), the return value is Undefined.
//
Function DistributeAmountProportionallyCoefficients(Val SrcAmount, CoeffArray, Val Precision = 2) Export
	
	If CoeffArray.Count() = 0 Or Not ValueIsFilled(SrcAmount) Then
		Return Undefined;
	EndIf;
	
	MaxIndex = 0;
	MaxVal = 0;
	DistribAmount = 0;
	AmountCoeff = 0;
	
	For K = 0 to CoeffArray.Count() - 1 Do
		
		AbsNumber = ?(CoeffArray[K] > 0, CoeffArray[K], - CoeffArray[K]);
		
		If MaxVal < AbsNumber Then
			MaxVal = AbsNumber;
			MaxIndex = K;
		EndIf;
		
		AmountCoeff = AmountCoeff + CoeffArray[K];
		
	EndDo;
	
	If AmountCoeff = 0 Then
		Return Undefined;
	EndIf;
	
	AmountArray = New Array(CoeffArray.Count());
	
	For K = 0 to CoeffArray.Count() - 1 Do
		AmountArray[K] = Round(SrcAmount * CoeffArray[K] / AmountCoeff, Precision, 1);
		DistribAmount = DistribAmount + AmountArray[K];
	EndDo;
	
	// Adding rounding error to the AmountArray element with maximum weight.
	If Not DistribAmount = SrcAmount Then
		AmountArray[MaxIndex] = AmountArray[MaxIndex] + SrcAmount - DistribAmount;
	EndIf;
	
	Return AmountArray;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for working with external connections.

// Returns the COM class name for establishing connection to 1C:Enterprise.
//
Function COMConnectorName() Export
	
	SystemInfo = New SystemInfo;
	VersionSubstrings = StringFunctionsClientServer.SplitStringIntoSubstringArray(
		SystemInfo.AppVersion, ".");
	Return "v" + VersionSubstrings[0] + VersionSubstrings[1] + ".COMConnector";
	
EndFunction	

// Establishes an external connection to an infobase by passed connection parameters,
// and returns this connection.
// 
// Parameters:
// Parameters - Structure - contains parameters for establishing an external connection to an infobase.
// The structure must contain the following keys (see the CommonUseClientServer.ExternalConnectionParameterStructure function for details):
//
//	 InfoBaseOperationMode - Number - infobase operation mode: 0 for the file mode, 1 for the client/server mode;
//	 InfoBaseDirectory - String - infobase directory, used in the file mode;
//	 PlatformServerName - String - platform server name, used in the client/server mode;
//	 InfoBaseNameAtPlatformServer - String - infobase name at the platform server;
//	 OSAuthentication - Boolean - flag that shows whether the infobase user is selected based on the operating system user;
//	 UserName - String - infobase user name;
//	 UserPassword - String - infobase user password;
// 
// ErrorMessageString – String – optional. If an error occurs when establishing
// an external connection, the error message text is returned to this parameter.
//
// Returns:
// COM object - if the external connection has been established successfully;
// Undefined - if the external connection has not been established.
// 
Function SetExternalConnection(Parameters, ErrorMessageString = "", ErrorAttachingAddIn = False) Export
	
	// The return value (COM object)
	Connection = Undefined;
	
	Try
		COMConnector = New COMObject(COMConnectorName()); // "V82.COMConnector"
	Except
		ErrorMessageString = NStr("en = 'Error while establishing the external connection: %1'");
		ErrorMessageString = StringFunctionsClientServer.SubstituteParametersInString(ErrorMessageString, DetailErrorDescription(ErrorInfo()));
		ErrorAttachingAddIn = True;
		Return Undefined;
	EndTry;
	
	If Parameters.InfoBaseOperationMode = 0 Then
		
		If IsBlankString(Parameters.InfoBaseDirectory) Then
			
			ErrorMessageString = NStr("en = 'The infobase directory is not specified.'");
			Return Undefined;
			
		EndIf;
		
		If Parameters.OSAuthentication Then
			
			ConnectionString = "File = ""&InfoBaseDirectory""";
			
			ConnectionString = StrReplace(ConnectionString, "&InfoBaseDirectory", Parameters.InfoBaseDirectory);
			
		Else
			
			ConnectionString = "File = ""&InfoBaseDirectory""; Usr = ""&UserName""; Pwd = ""&UserPassword""";
			
			ConnectionString = StrReplace(ConnectionString, "&InfoBaseDirectory", Parameters.InfoBaseDirectory);
			ConnectionString = StrReplace(ConnectionString, "&UserName", Parameters.UserName);
			ConnectionString = StrReplace(ConnectionString, "&UserPassword", Parameters.UserPassword);
			
		EndIf;
		
	Else // Client/server mode
		
		If IsBlankString(Parameters.PlatformServerName)
			Or IsBlankString(Parameters.InfoBaseNameAtPlatformServer) Then
			
			ErrorMessageString = NStr("en = 'The mandatory connection parameters (server name and infobase name)are not specified.'");
			Return Undefined;
			
		EndIf;
		
		If Parameters.OSAuthentication Then
			
			ConnectionString = "Srvr = &PlatformServerName; Ref = &InfoBaseNameAtPlatformServer";
			
			ConnectionString = StrReplace(ConnectionString, "&PlatformServerName", Parameters.PlatformServerName);
			ConnectionString = StrReplace(ConnectionString, "&InfoBaseNameAtPlatformServer", Parameters.InfoBaseNameAtPlatformServer);
			
		Else
			
			ConnectionString = "Srvr = &PlatformServerName; Ref = &InfoBaseNameAtPlatformServer; Usr = ""&UserName""; Pwd = ""&UserPassword""";
			
			ConnectionString = StrReplace(ConnectionString, "&PlatformServerName", Parameters.PlatformServerName);
			ConnectionString = StrReplace(ConnectionString, "&InfoBaseNameAtPlatformServer", Parameters.InfoBaseNameAtPlatformServer);
			ConnectionString = StrReplace(ConnectionString, "&UserName", Parameters.UserName);
			ConnectionString = StrReplace(ConnectionString, "&UserPassword", Parameters.UserPassword);
			
		EndIf;
		
	EndIf;
	
	Try
		Connection = COMConnector.Connect(ConnectionString);
	Except
		
		ErrorAttachingAddIn = True;
		
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		
		ErrorMessageString = NStr("en = 'Error establishing the external connection: %1'");
		ErrorMessageString = StringFunctionsClientServer.SubstituteParametersInString(ErrorMessageString, DetailErrorDescription);
		Return Undefined;
	EndTry;
	
	Return Connection;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

// Executes the export procedure by name.
//
// Parameters
// ExportProcedureName – String – export procedure name in the following format:
//										 <object name>.<procedure name> where <object name> is 
// 										a common module or an object manager module.
// Parameters - Array - parameters for passing to the <ExportProcedureName> procedure
// ordered by their positions in the array;
// DataArea - Number - data area where the procedure will be executed.
// 
// Example:
// ExecuteSafely("MyCommonModule.MyProcedure"); 
//
Procedure ExecuteSafely(ExportProcedureName, Parameters = Undefined, DataArea = Undefined) Export
	
	// Checking the ExportProcedureName format. 
	NameParts = StringFunctionsClientServer.SplitStringIntoSubstringArray(ExportProcedureName, ".");
	If NameParts.Count() <> 2 And NameParts.Count() <> 3 Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Invalid format of the ExportProcedureName parameter %1.'"),
			ExportProcedureName);
	EndIf;

	ObjectName = NameParts[0];
	If NameParts.Count() = 2 And Metadata.CommonModules.Find(ObjectName) = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Invalid format of the ExportProcedureName parameter %1.'"),
			ExportProcedureName);
	EndIf;
		
	If NameParts.Count() = 3 Then
		ValidTypeNames = New Array;
		ValidTypeNames.Add(Upper(TypeNameConstants()));
		ValidTypeNames.Add(Upper(TypeNameInformationRegisters()));
		ValidTypeNames.Add(Upper(TypeNameAccumulationRegisters()));
		ValidTypeNames.Add(Upper(TypeNameAccountingRegisters()));
		ValidTypeNames.Add(Upper(TypeNameCalculationRegisters()));
		ValidTypeNames.Add(Upper(TypeNameCatalogs()));
		ValidTypeNames.Add(Upper(TypeNameDocuments()));
		ValidTypeNames.Add(Upper(TypeNameReports()));
		ValidTypeNames.Add(Upper(TypeNameDataProcessors()));
		ValidTypeNames.Add(Upper(TypeNameBusinessProcesses()));
		ValidTypeNames.Add(Upper(TypeNameTasks()));
		ValidTypeNames.Add(Upper(TypeNameChartsOfAccounts()));
		ValidTypeNames.Add(Upper(TypeNameExchangePlans()));
		ValidTypeNames.Add(Upper(TypeNameChartsOfCharacteristicTypes()));
		ValidTypeNames.Add(Upper(TypeNameChartsOfCalculationTypes()));
		TypeName = Upper(NameParts[0]);
		If ValidTypeNames.Find(TypeName) = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Invalid format of the ExportProcedureName parameter %1.'"),
				ExportProcedureName);
		EndIf;
	EndIf;
	
	MethodName = NameParts[NameParts.UBound()];
	TempStructure = New Structure;
	Try
		TempStructure.Insert(MethodName);
	Except
		WriteLogEvent(NStr("en = 'Safe method execution.'", Metadata.DefaultLanguage.LanguageCode), EventLogLevel.Error, , ,
			DetailErrorDescription(ErrorInfo()));
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Invalid format of the ExportProcedureName parameter %1.'"),
			ExportProcedureName);
	EndTry;
	
	ParametersString = "";
	If Parameters <> Undefined And Parameters.Count() > 0 Then
		For Index = 0 to Parameters.UBound() Do 
			ParametersString = ParametersString + "Parameters[" + Index + "],";
		EndDo;
		ParametersString = Mid(ParametersString, 1, StrLen(ParametersString) - 1);
	EndIf;
	
	If CommonUseCached.DataSeparationEnabled() Then
		If Not CommonUseCached.SessionWithoutSeparator() Then
			If DataArea = Undefined Then
				DataArea = SessionSeparatorValue();
			Else 
				If DataArea <> SessionSeparatorValue() Then
					Raise(NStr("en = 'It is not allowed to process data from another data area in this session.'"));
				EndIf;
			EndIf;
		EndIf;
		If DataArea <> Undefined
			And (Not UseSessionSeparator() Or DataArea <> SessionSeparatorValue()) Then
			SetSessionSeparation(True, DataArea);
		EndIf;
	EndIf;
	
	Execute ExportProcedureName + "(" + ParametersString + ")";
	
EndProcedure

// Checks the validity of the export procedure name before passing it
// to the Execute operator. If the name is invalid,
// an exception is raised.
//
Function CheckExportProcedureName(Val ExportProcedureName, MessageText) Export
	
	// Checking ExportProcedureName format preconditions
	NameParts = StringFunctionsClientServer.SplitStringIntoSubstringArray(ExportProcedureName, ".");
	If NameParts.Count() <> 2 And NameParts.Count() <> 3 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'The ExportProcedureName parameter has incorrect format %1.'"),
			ExportProcedureName);
		Return False;
	EndIf;

	ObjectName = NameParts[0];
	If NameParts.Count() = 2 And Metadata.CommonModules.Find(ObjectName) = Undefined Then
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'The ExportProcedureName parameter has incorrect format %1.'"),
			ExportProcedureName);
		Return False;
	EndIf;
		
	If NameParts.Count() = 3 Then
		ValidTypeNames = New Array;
		ValidTypeNames.Add(Upper(TypeNameConstants()));
		ValidTypeNames.Add(Upper(TypeNameInformationRegisters()));
		ValidTypeNames.Add(Upper(TypeNameAccumulationRegisters()));
		ValidTypeNames.Add(Upper(TypeNameAccountingRegisters()));
		ValidTypeNames.Add(Upper(TypeNameCalculationRegisters()));
		ValidTypeNames.Add(Upper(TypeNameCatalogs()));
		ValidTypeNames.Add(Upper(TypeNameDocuments()));
		ValidTypeNames.Add(Upper(TypeNameBusinessProcesses()));
		ValidTypeNames.Add(Upper(TypeNameTasks()));
		ValidTypeNames.Add(Upper(TypeNameChartsOfAccounts()));
		ValidTypeNames.Add(Upper(TypeNameExchangePlans()));
		ValidTypeNames.Add(Upper(TypeNameChartsOfCharacteristicTypes()));
		ValidTypeNames.Add(Upper(TypeNameChartsOfCalculationTypes()));
		TypeName = Upper(NameParts[0]);
		If ValidTypeNames.Find(TypeName) = Undefined Then
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'The ExportProcedureName parameter has incorrect format %1.'"),
				ExportProcedureName);
			Return False;
		EndIf;
	EndIf;
	
	Return True;
	
EndFunction

// Determines the infobase mode: file (True) or client/server (False).
// This function requires the InfoBaseConnectionString parameter. 
// You can specify this parameter explicitly.
//
// Parameters:
// InfoBaseConnectionString - String - if this parameter is empty, 
// the connection string of the current infobase connection is used.
//
// Returns:
// Boolean.
//
Function FileInfoBase(Val InfoBaseConnectionString = "") Export
			
	If IsBlankString(InfoBaseConnectionString) Then
		InfoBaseConnectionString = InfoBaseConnectionString();
	EndIf;
	Return Find(Upper(InfoBaseConnectionString), "FILE=") = 1;
	
EndFunction 

// Resets session parameters to Undefined. 
// 
// Parameters: 
// ClearingParameters - String - names of session parameters to be cleared separated by commas;
// Exceptions - String - names of the session parameters to be preserved separated by commas.
//
Procedure ClearSessionParameters(ClearingParameters = "", Exceptions = "") Export
	
	ExceptionArray = StringFunctionsClientServer.SplitStringIntoSubstringArray(Exceptions);
	ParametersForClearingArray = StringFunctionsClientServer.SplitStringIntoSubstringArray(ClearingParameters);
	
	If ParametersForClearingArray.Count() = 0 Then
		For Each SessionParameter In Metadata.SessionParameters Do
			If ExceptionArray.Find(SessionParameter.Name) = Undefined Then
				ParametersForClearingArray.Add(SessionParameter.Name);
			EndIf;
		EndDo;
	EndIf;
	SessionParameters.Clear(ParametersForClearingArray);
	
EndProcedure

// Returns subject details in the string format.
// 
// Parameters
// SubjectRef – AnyRef – object of reference type.
//
// Returns:
// String
// 
Function SubjectString(SubjectRef) Export
	
	Result = "";
	StandardSubsystemsOverridable.SetSubjectPresentation(SubjectRef, Result); 
	CommonUseOverridable.SetSubjectPresentation(SubjectRef, Result); 
	
	If IsBlankString(Result) Then
		If SubjectRef = Undefined Or SubjectRef.Empty() Then
			Result = NStr("en = 'not specified");
		ElsIf Metadata.Documents.Contains(SubjectRef.Metadata()) Then
			Result = String(SubjectRef);
		Else
			ObjectPresentation = SubjectRef.Metadata().ObjectPresentation;
			If IsBlankString(ObjectPresentation) Then
				ObjectPresentation = SubjectRef.Metadata().Presentation();
			EndIf;
			Result = StringFunctionsClientServer.SubstituteParametersInString(
				"%1 (%2)", String(SubjectRef), ObjectPresentation);
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

// Merges reference search exceptions.
//
Function GetOverallRefSearchExceptionList() Export
	
	OverallRefExclusionArray = New Array;
	
	FillArrayWithUniqueValues(OverallRefExclusionArray, StandardSubsystemsOverridable.RefSearchExclusions());
	FillArrayWithUniqueValues(OverallRefExclusionArray, CommonUseOverridable.GetRefSearchExceptions());
	
	Return OverallRefExclusionArray;
	
EndFunction

// Creates a map that stores the table of correspondence between separated and shared data types.
//
// Returns:
// ValueTable - data type map.
//
Function GetSeparatedAndSharedDataMapTable() Export
	
	Result = StandardSubsystemsOverridable.SeparatedAndSharedDataMapTable();
	If Result = Undefined Then
		Return New ValueTable;
	Else
		Return Result;
	EndIf;
	
EndFunction

// Returns the value in the XML string format.
// The following value types can be serialized into an XML string with this function: 
// Undefined, Null, Boolean, Number, String, Date, Type, UUID, BinaryData,
// ValueStorage, TypeDescription, data object references and the data 
// objects themselves, sets of register records, and the constant value manager.
//
// Parameters:
// Value – Arbitrary - value to be serialized into an XML string.
//
// Returns:
// String - resulting string.
//
Function ValueToXMLString(Value) Export
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	XDTOSerializer.WriteXML(XMLWriter, Value, XMLTypeAssignment.Explicit);
	
	Return XMLWriter.Close();
EndFunction

// Returns a value restored from the XML string. 
// The following value types can be restored from the XML string with this function: 
// Undefined, Null, Boolean, Number, String, Date, Type, UUID, BinaryData,
// ValueStorage, TypeDescription, data object references and the data 
// objects themselves, sets of register records, and the constant value manager.
//
// Parameters:
// XMLString – serialized string.
//
// Returns:
// String - resulting string.
//
Function ValueFromXMLString(XMLString) Export
	
	XMLReader = New XMLReader;
	XMLReader.SetString(XMLString);
	
	Return XDTOSerializer.ReadXML(XMLReader);
EndFunction

// Generates a query search string from the source string.
//
// Parameters:
//	SearchString - String - source string that contains characters prohibited in queries. 	
//
// Returns:
// String - resulting string.
//
Function GenerateSearchQueryString(Val SearchString) Export
	
	ResultingSearchString = SearchString;
	ResultingSearchString = StrReplace(ResultingSearchString, "~", "~~");
	ResultingSearchString = StrReplace(ResultingSearchString, "%", "~%");
	ResultingSearchString = StrReplace(ResultingSearchString, "_", "~_");
	ResultingSearchString = StrReplace(ResultingSearchString, "[", "~[");
	ResultingSearchString = StrReplace(ResultingSearchString, "-", "~-");
	
	Return ResultingSearchString;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for working with forms.
//

// Fills a form attribute of the ValueTree type.
//
// Parameters:
// TreeItemCollection – form attribute of the ValueTree type;
// 							 It will be filled with values from the ValueTree parameter.
// ValueTree – ValueTree – data for filling TreeItemCollection.
//
Procedure FillFormDataTreeItemCollection(TreeItemCollection, ValueTree) Export
	
	For Each Row In ValueTree.Rows Do
		
		TreeItem = TreeItemCollection.Add();
		
		FillPropertyValues(TreeItem, Row);
		
		If Row.Rows.Count() > 0 Then
			
			FillFormDataTreeItemCollection(TreeItem.GetItems(), Row);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Gets a picture for displaying it on a page that contains the comment. 
// The picture will be displayed if the comment text is not empty.
//
// Parameters
// Comment - String - comment text.
//
// Returns:
// Picture - picture to be displayed on a page that contains the comment.
//
Function GetCommentPicture(Comment) Export
	
	If Not IsBlankString(Comment) Then
		Picture = PictureLib.Comment;
	Else
		Picture = New Picture;
	EndIf;
	
	Return Picture;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for working with types, metadata objects, and their string presentations.

// Gets the configuration metadata tree with the specified filter by metadata objects.
//
// Parameters:
// Filter – Structure – contains filter item values.
//						If this parameter is specified, the metadata tree will be retrieved according to the filter value; 
//						Key - String – metadata item property name;
//						Value - Array – array of filter values.
//
// Example of initializing the Filter variable:
//
// Array = New Array;
// Array.Add("Constant.UseDataExchange");
// Array.Add("Catalog.Currencies");
// Array.Add("Catalog.Companies");
// Filter = New Structure;
// Filter.Insert("FullName", Array);
// 
// Returns:
// ValueTree - configuration metadata tree.
//
Function GetConfigurationMetadataTree(Filter = Undefined) Export
	
	UseFilter = (Filter <> Undefined);
	
	MetadataObjectCollections = New ValueTable;
	MetadataObjectCollections.Columns.Add("Name");
	MetadataObjectCollections.Columns.Add("Synonym");
	MetadataObjectCollections.Columns.Add("Picture");
	MetadataObjectCollections.Columns.Add("ObjectPicture");
	
	NewMetadataObjectCollectionRow("Constants", "Constants", PictureLib.Constant, PictureLib.Constant, MetadataObjectCollections);
	NewMetadataObjectCollectionRow("Catalogs", "Catalogs", PictureLib.Catalog, PictureLib.Catalog, MetadataObjectCollections);
	NewMetadataObjectCollectionRow("Documents", "Documents", PictureLib.Document, PictureLib.DocumentObject, MetadataObjectCollections);
	NewMetadataObjectCollectionRow("ChartsOfCharacteristicTypes", "Charts of characteristic types", PictureLib.ChartOfCharacteristicTypes, PictureLib.ChartOfCharacteristicTypesObject, MetadataObjectCollections);
	NewMetadataObjectCollectionRow("ChartsOfAccounts", "Charts of accounts", PictureLib.ChartOfAccounts, PictureLib.ChartOfAccountsObject, MetadataObjectCollections);
	NewMetadataObjectCollectionRow("ChartsOfCalculationTypes", "Charts of calculation types", PictureLib.ChartOfCharacteristicTypes, PictureLib.ChartOfCharacteristicTypesObject, MetadataObjectCollections);
	NewMetadataObjectCollectionRow("InformationRegisters", "Information registers", PictureLib.InformationRegister, PictureLib.InformationRegister, MetadataObjectCollections);
	NewMetadataObjectCollectionRow("AccumulationRegisters", "Accumulation registers", PictureLib.AccumulationRegister, PictureLib.AccumulationRegister, MetadataObjectCollections);
	NewMetadataObjectCollectionRow("AccountingRegisters", "Accounting registers", PictureLib.AccountingRegister, PictureLib.AccountingRegister, MetadataObjectCollections);
	NewMetadataObjectCollectionRow("CalculationRegisters", "Calculation registers", PictureLib.CalculationRegister, PictureLib.CalculationRegister, MetadataObjectCollections);
	NewMetadataObjectCollectionRow("BusinessProcesses", "Business processes", PictureLib.BusinessProcess, PictureLib.BusinessProcessObject, MetadataObjectCollections);
	NewMetadataObjectCollectionRow("Tasks", "Tasks", PictureLib.Task, PictureLib.TaskObject, MetadataObjectCollections);
	
	// The return value 
	MetadataTree = New ValueTree;
	MetadataTree.Columns.Add("Name");
	MetadataTree.Columns.Add("FullName");
	MetadataTree.Columns.Add("Synonym");
	MetadataTree.Columns.Add("Picture");
	
	For Each CollectionRow In MetadataObjectCollections Do
		
		TreeRow = MetadataTree.Rows.Add();
		
		FillPropertyValues(TreeRow, CollectionRow);
		
		For Each MetadataObject In Metadata[CollectionRow.Name] Do
			
			// ============================ {Filter}
			If UseFilter Then
				
				ObjectPassedFilter = True;
				
				For Each FilterItem In Filter Do
					
					Value = ?(Upper(FilterItem.Key) = Upper("FullName"), MetadataObject.FullName(), MetadataObject[FilterItem.Key]);
					
					If FilterItem.Value.Find(Value) = Undefined Then
						
						ObjectPassedFilter = False;
						
						Break;
						
					EndIf;
					
				EndDo;
				
				If Not ObjectPassedFilter Then
					
					Continue;
					
				EndIf;
				
			EndIf;
			// ============================ {Filter}
			
			MOTreeRow = TreeRow.Rows.Add();
			MOTreeRow.Name = MetadataObject.Name;
			MOTreeRow.FullName = MetadataObject.FullName();
			MOTreeRow.Synonym = MetadataObject.Synonym;
			MOTreeRow.Picture = CollectionRow.ObjectPicture;
			
		EndDo;
		
	EndDo;
	
	// Deleting rows that have no subordinate items
	If UseFilter Then
		
		// Using reverse value tree iteration order
		CollectionItemCount = MetadataTree.Rows.Count();
		
		For ReverseIndex = 1 to CollectionItemCount Do
			
			CurrentIndex = CollectionItemCount - ReverseIndex;
			
			TreeRow = MetadataTree.Rows[CurrentIndex];
			
			If TreeRow.Rows.Count() = 0 Then
				
				MetadataTree.Rows.Delete(CurrentIndex);
				
			EndIf;
			
		EndDo;
	
	EndIf;
	
	Return MetadataTree;
	
EndFunction

// Returns detailed information about the configuration 
// (detailed information is a configuration metadata property).
//
// Returns: 
// String - string with detailed information about the configuration.
//
Function GetConfigurationDetails() Export
	
	Return Metadata.DetailedInformation;
	
EndFunction

// Get the infobase presentation for displaying it to the user.
//
// Returns:
// String - infobase presentation. 
//
// Result example:
// - if the infobase operates in the file mode: \\FileServer\1C_ib
// - if the infobase operates in the client/server mode: ServerName:1111 / Information_base_name
//
Function GetInfoBasePresentation() Export
	
	InfoBaseConnectionString = InfoBaseConnectionString();
	
	If FileInfoBase(InfoBaseConnectionString) Then
		PathToDB = Mid(InfoBaseConnectionString, 6, StrLen(InfoBaseConnectionString) - 6);
	Else
		// Adding the infobase name to the server name 
		SearchPosition = Find(Upper(InfoBaseConnectionString), "SRVR=");
		
		If SearchPosition <> 1 Then
			Return Undefined;
		EndIf;
		
		SemicolonPosition = Find(InfoBaseConnectionString, ";");
		CopyStartPosition = 6 + 1;
		CopyingEndPosition = SemicolonPosition - 2; 
		
		ServerName = Mid(InfoBaseConnectionString, CopyStartPosition, CopyingEndPosition - CopyStartPosition + 1);
		
		InfoBaseConnectionString = Mid(InfoBaseConnectionString, SemicolonPosition + 1);
		
		// Server name position
		SearchPosition = Find(Upper(InfoBaseConnectionString), "REF=");
		
		If SearchPosition <> 1 Then
			Return Undefined;
		EndIf;
		
		CopyStartPosition = 6;
		SemicolonPosition = Find(InfoBaseConnectionString, ";");
		CopyingEndPosition = SemicolonPosition - 2; 
		
		InfoBaseNameAtServer = Mid(InfoBaseConnectionString, CopyStartPosition, CopyingEndPosition - CopyStartPosition + 1);
		
		PathToDB = ServerName + "/ " + InfoBaseNameAtServer;
		
	EndIf;
	
	Return PathToDB;
	
EndFunction

// Returns a string of configuration metadata object attributes of the specified type.
//
// Parameters:
// Ref – AnyRef – reference to the infobase item whose attibutes will be retrieved;
// Type – Type – attribute value type.
// 
// Returns:
// String – string with configuration metadata object attributes separated by commas.
//
Function AttributeNamesByType(Ref, Type) Export
	
	Result = "";
	ObjectMetadata = Ref.Metadata();
	
	For Each Attribute In ObjectMetadata.Attributes Do
		If Attribute.Type.ContainsType(Type) Then
			Result = Result + ?(IsBlankString(Result), "", ", ") + Attribute.Name;
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

// Returns a name of the base type by the passed metadata object value.
//
// Parameters:
// MetadataObject - metadata object for determining the base type.
// 
// Returns:
// String - base type name.
//
Function BaseTypeNameByMetadataObject(MetadataObject) Export
	
	If Metadata.Documents.Contains(MetadataObject) Then
		Return TypeNameDocuments();
		
	ElsIf Metadata.Catalogs.Contains(MetadataObject) Then
		Return TypeNameCatalogs();
		
	ElsIf Metadata.Enums.Contains(MetadataObject) Then
		Return TypeNameEnums();
		
	ElsIf Metadata.InformationRegisters.Contains(MetadataObject) Then
		Return TypeNameInformationRegisters();
		
	ElsIf Metadata.AccumulationRegisters.Contains(MetadataObject) Then
		Return TypeNameAccumulationRegisters();
		
	ElsIf Metadata.AccountingRegisters.Contains(MetadataObject) Then
		Return TypeNameAccountingRegisters();
		
	ElsIf Metadata.CalculationRegisters.Contains(MetadataObject) Then
		Return TypeNameCalculationRegisters();
		
	ElsIf Metadata.ExchangePlans.Contains(MetadataObject) Then
		Return TypeNameExchangePlans();
		
	ElsIf Metadata.ChartsOfCharacteristicTypes.Contains(MetadataObject) Then
		Return TypeNameChartsOfCharacteristicTypes();
		
	ElsIf Metadata.BusinessProcesses.Contains(MetadataObject) Then
		Return TypeNameBusinessProcesses();
		
	ElsIf Metadata.Tasks.Contains(MetadataObject) Then
		Return TypeNameTasks();
		
	ElsIf Metadata.ChartsOfAccounts.Contains(MetadataObject) Then
		Return TypeNameChartsOfAccounts();
		
	ElsIf Metadata.ChartsOfCalculationTypes.Contains(MetadataObject) Then
		Return TypeNameChartsOfCalculationTypes();
		
	ElsIf Metadata.Constants.Contains(MetadataObject) Then
		Return TypeNameConstants();
		
	ElsIf Metadata.DocumentJournals.Contains(MetadataObject) Then
		Return TypeNameDocumentJournals();
		
	Else
		
		Return "";
		
	EndIf;
	
EndFunction

// Returns an object manager by the full metadata object name.
//
// This function does not process business process route points.
//
// Parameters:
// FullName - String - metadata object full name,
// for example: "Catalog.Companies".
//
// Returns:
// ObjectManager (CatalogManager, DocumentManager, and so on). 
//
Function ObjectManagerByFullName(FullName) Export
	
	NameParts = StringFunctionsClientServer.SplitStringIntoSubstringArray(FullName, ".");
	
	MOClass = NameParts[0];
	MOName = NameParts[1];
	
	If Upper(MOClass) = "EXCHANGEPLAN" Then
		Return ExchangePlans[MOName];
		
	ElsIf Upper(MOClass) = "CATALOG" Then
		Return Catalogs[MOName];
		
	ElsIf Upper(MOClass) = "DOCUMENT" Then
		Return Documents[MOName];
		
	ElsIf Upper(MOClass) = "DOCUMENTJOURNAL" Then
		Return DocumentJournals[MOName];
		
	ElsIf Upper(MOClass) = "ENUM" Then
		Return Enums[MOName];
		
	ElsIf Upper(MOClass) = "REPORT" Then
		Return Reports[MOName];
		
	ElsIf Upper(MOClass) = "DATAPROCESSOR" Then
		Return DataProcessors[MOName];
		
	ElsIf Upper(MOClass) = "CHARTOFCHARACTERISTICTYPES" Then
		Return ChartsOfCharacteristicTypes[MOName];
		
	ElsIf Upper(MOClass) = "CHARTOFACCOUNTS" Then
		Return ChartsOfAccounts[MOName];
		
	ElsIf Upper(MOClass) = "CHARTOFCALCULATIONTYPES" Then
		Return ChartsOfCalculationTypes[MOName];
		
	ElsIf Upper(MOClass) = "INFORMATIONREGISTER" Then
		Return InformationRegisters[MOName];
		
	ElsIf Upper(MOClass) = "ACCUMULATIONREGISTER" Then
		Return AccumulationRegisters[MOName];
		
	ElsIf Upper(MOClass) = "ACCOUNTINGREGISTER" Then
		Return AccountingRegisters[MOName];
		
	ElsIf Upper(MOClass) = "CALCULATIONREGISTER" Then
		Return CalculationRegisters[MOName];
		
	ElsIf Upper(MOClass) = "BUSINESSPROCESS" Then
		Return BusinessProcesses[MOName];
		
	ElsIf Upper(MOClass) = "TASK" Then
		Return Tasks[MOName];
	Else
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Unknown type of metadata object %1.'"), MOClass);
	EndIf;
	
EndFunction

// Returns an object manager by the object reference.
//
// This function does not process business process route points.
//
// Parameters:
// Ref - Reference - object reference (catalog item, document, and so on).
//
// Returns:
// ObjectManager (CatalogManager, DocumentManager, and so on). 
//
Function ObjectManagerByRef(Ref) Export
	
	ObjectName = Ref.Metadata().Name;
	ReferenceType = TypeOf(Ref);
	
	If Catalogs.AllRefsType().ContainsType(ReferenceType) Then
		Return Catalogs[ObjectName];
		
	ElsIf Documents.AllRefsType().ContainsType(ReferenceType) Then
		Return Documents[ObjectName];
		
	ElsIf BusinessProcesses.AllRefsType().ContainsType(ReferenceType) Then
		Return BusinessProcesses[ObjectName];
		
	ElsIf ChartsOfCharacteristicTypes.AllRefsType().ContainsType(ReferenceType) Then
		Return ChartsOfCharacteristicTypes[ObjectName];
		
	ElsIf ChartsOfAccounts.AllRefsType().ContainsType(ReferenceType) Then
		Return ChartsOfAccounts[ObjectName];
		
	ElsIf ChartsOfCalculationTypes.AllRefsType().ContainsType(ReferenceType) Then
		Return ChartsOfCalculationTypes[ObjectName];
		
	ElsIf Tasks.AllRefsType().ContainsType(ReferenceType) Then
		Return Tasks[ObjectName];
		
	ElsIf ExchangePlans.AllRefsType().ContainsType(ReferenceType) Then
		Return ExchangePlans[ObjectName];
		
	ElsIf Enums.AllRefsType().ContainsType(ReferenceType) Then
		Return Enums[ObjectName];
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// Checks whether the infobase record exists by its reference.
//
// Parameters:
// AnyRef - any infobase reference value.
// 
// Returns:
// True if the record exists;
// False if the record does not exist.
//
Function RefExists(AnyRef) Export
	
	QueryText = "
	|SELECT
	|	Ref
	|FROM
	|	[TableName]
	|WHERE
	|	Ref = &Ref
	|";
	
	QueryText = StrReplace(QueryText, "[TableName]", TableNameByRef(AnyRef));
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Ref", AnyRef);
	
	SetPrivilegedMode(True);
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

// Returns a metadata object kind name 
// by the object reference.
//
// This function does not process business process route points.
//
// Parameters:
// Ref - Reference - object reference (catalog item, document, and so on).
//
// Returns:
// String - metadata object kind name ("Catalog", "Document", and so on).
//
Function ObjectKindByRef(Ref) Export
	
	Return ObjectKindByType(TypeOf(Ref));
	
EndFunction 

// Returns a metadata object kind name by the object type.
//
// This function does not process business process route points.
//
// Parameters:
// Type - applied object type.
//
// Returns:
// String - metadata object kind name ("Catalog", "Document", and so on).
//
Function ObjectKindByType(Type) Export
	
	If Catalogs.AllRefsType().ContainsType(Type) Then
		Return "Catalog";
	
	ElsIf Documents.AllRefsType().ContainsType(Type) Then
		Return "Document";
	
	ElsIf BusinessProcesses.AllRefsType().ContainsType(Type) Then
		Return "BusinessProcess";
	
	ElsIf ChartsOfCharacteristicTypes.AllRefsType().ContainsType(Type) Then
		Return "ChartOfCharacteristicTypes";
	
	ElsIf ChartsOfAccounts.AllRefsType().ContainsType(Type) Then
		Return "ChartOfAccounts";
	
	ElsIf ChartsOfCalculationTypes.AllRefsType().ContainsType(Type) Then
		Return "ChartOfCalculationTypes";
	
	ElsIf Tasks.AllRefsType().ContainsType(Type) Then
		Return "Task";
	
	ElsIf ExchangePlans.AllRefsType().ContainsType(Type) Then
		Return "ExchangePlan";
	
	ElsIf Enums.AllRefsType().ContainsType(Type) Then
		Return "Enumeration";
	
	Else
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Invalid parameter value type %1.'"), String(Type));
	
	EndIf;
	
EndFunction 

// Returns full metadata object name by the passed reference value.
// Example:
// "Catalog.Items";
// "Document.Invoice".
//
// Parameters:
// Ref - AnyRef - value of the reference whose infobase table name will be retrieved.
// 
// Returns:
// String - full metadata object name.
//
Function TableNameByRef(Ref) Export
	
	Return Ref.Metadata().FullName();
	
EndFunction

// Checks whether the value has a reference type.
//
// Parameters:
// Value - Any;
//
// Returns:
// Boolean - True if the value has a reference type.
//
Function ReferenceTypeValue(Value) Export
	
	If Value = Undefined Then
		Return False;
	EndIf;
	
	If Catalogs.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If Documents.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If Enums.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If ChartsOfCharacteristicTypes.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If ChartsOfAccounts.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If ChartsOfCalculationTypes.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If BusinessProcesses.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If BusinessProcesses.RoutePointsAllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If Tasks.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If ExchangePlans.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// Checks whether the type is a reference type.
//
Function IsReference(Type) Export
	
	Return Catalogs.AllRefsType().ContainsType(Type)
		Or Documents.AllRefsType().ContainsType(Type)
		Or Enums.AllRefsType().ContainsType(Type)
		Or ChartsOfCharacteristicTypes.AllRefsType().ContainsType(Type)
		Or ChartsOfAccounts.AllRefsType().ContainsType(Type)
		Or ChartsOfCalculationTypes.AllRefsType().ContainsType(Type)
		Or BusinessProcesses.AllRefsType().ContainsType(Type)
		Or BusinessProcesses.RoutePointsAllRefsType().ContainsType(Type)
		Or Tasks.AllRefsType().ContainsType(Type)
		Or ExchangePlans.AllRefsType().ContainsType(Type);
	
EndFunction

// Checks whether the object is a folder.
//
// Parameters:
// Object - items belonging to catalogs or charts of characteristic types only.
//
Function ObjectIsFolder(Object) Export
	
	ObjectMetadata = Object.Metadata();
	
	If IsCatalog(ObjectMetadata)
	And Not (ObjectMetadata.Hierarchical And ObjectMetadata.HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems) Then
		Return False;
	EndIf;
	
	If ReferenceTypeValue(Object) Then
		Return Object.IsFolder;
	EndIf;
	
	Ref = Object.Ref;
	
	If Not ValueIsFilled(Ref) Then
		Return False;
	EndIf;
	
	Return GetAttributeValue(Ref, "IsFolder");
	
EndFunction

// Returns a reference that corresponds to the metadata object.
// 
// Example:
// ID = CommonUse.MetadataObjectID(TypeOf(Ref));
// ID = CommonUse.MetadataObjectID(MetadataObject);
// ID = CommonUse.MetadataObjectID("Catalog.Companies");
//
// Supported metadata objects:
// - Subsystems (manually through predefined items)
// - Roles
// - ExchangePlans
// - Catalogs
// - Documents
// - DocumentJournals
// - Reports
// - DataProcessors
// - ChartsOfCharacteristicTypes
// - ChartsOfAccounts
// - ChartsOfCalculationTypes
// - InformationRegisters
// - AccumulationRegisters
// - AccountingRegisters
// - CalculationRegisters
// - BusinessProcesses
// - Tasks
// 
// See MetadataObjectIDs.ManagerModule.MetadataObjectCollectionProperties()
// for details.
//
// Parameters:
// MetadataObjectName - MetadataObject
// - type that can be used 
// in Metadata.FindByType();
// - String - full metadata object name
// that can be used 
// in Metadata.FindByFullName().
//
// Returns:
// CatalogRef.MetadataObjectIDs.
//
Function MetadataObjectID(MetadataObjectName) Export
	
	SetPrivilegedMode(True);
	
	MetadataObjectDescriptionType = TypeOf(MetadataObjectName);
	If MetadataObjectDescriptionType = Type("Type") Then
		
		MetadataObject = Metadata.FindByType(MetadataObjectName);
		If MetadataObject = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error executing CommonUse.MetadataObjectID().
				 |
				 |Мetadata object is not found by its type:
				 |%1.'"),
				MetadataObjectName);
		Else
			Table = MetadataObject.FullName();
		EndIf;
		
	ElsIf MetadataObjectDescriptionType = Type("String") Then
		Table = MetadataObjectName;
	Else
		Table = MetadataObjectName.FullName();
	EndIf;
	
	Query = New Query;
	Query.SetParameter("FullName", Table);
	Query.Text =
	"SELECT
	|	IDs.Ref,
	|	IDs.MetadataObjectKey,
	|	IDs.FullName
	|FROM
	|	Catalog.MetadataObjectIDs AS IDs
	|WHERE
	|	IDs.FullName = &FullName
	|	AND IDs.Used";
	
	Data = Query.Execute().Unload();
	If Data.Count() = 0 Then
		// Perhaps the full name is specified with error if ID is not found by the full name. 
		If MetadataObjectDescriptionType = Type("String")
		 And Metadata.FindByFullName(MetadataObjectName) = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error executing CommonUse.MetadataObjectID().
				 |
				 |The metadata object is not found by its full name:
				 |%1.'"),
				MetadataObjectName);
		EndIf;
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Error executing CommonUse.MetadataObjectID().
			 |
			 |The ID for the %1 metadata object 
			 |is not found 
			 |in the Metadata objects IDs catalog.
			 |
			 |If the catalog was not updated during the infobase update,
			 |you have to update it manually:
			 |All functions -> Catalog. Metadata object IDs ->
			 |Update catalog data command.
			 |
			 |Some metadata objects can be added to the catalog only as
			 |a predefined items, for example, subsystems.'"),
			Table);
	ElsIf Data.Count() > 1 Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Error executing CommonUse.MetadataObjectID().
			 |
			 |Several IDs for the %1 metadata object 
			 |is found 
			 |in the Metadata objects IDs catalog.
			 |
			 |Catalog data is incorrect. If the catalog was not updated 
			 |during the infobase update, you have to update it manually:
			 |All functions -> Catalog. Metadata object IDs ->
			 |Update catalog data command.'"),
			Table);
	EndIf;
	
	// Checking whether metadata object key corresponds to the full metadata object name
	CheckResult = Catalogs.MetadataObjectIDs.MetadataObjectKeyCorrespondsFullName(Data[0]);
	If CheckResult.NotCorresponds Then
		If CheckResult.MetadataObject = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error executing CommonUse.MetadataObjectID().
				 |
				 |The ID for the %1 metadata object is 
				 |found in the Metadata objects IDs catalog,
				 |but it corresponds to the deleted metadata object.
				 |
				 |Catalog data is incorrect. If the catalog was not updated 
				 |during the infobase update, you have to update it manually:
				 |All functions -> Catalog. Metadata object IDs ->
				 |Update catalog data command.'"),
				Table);
		Else
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error executing CommonUse.MetadataObjectID().
				 |
				 |The ID for the %1 metadata object is 
				 |found in the Metadata objects IDs catalog
				 |but it corresponds to the %2 metadata object.
				 |
				 |Catalog data is incorrect. If the catalog was not updated 
				 |during the infobase update, you have to update it manually:
				 |All functions -> Catalog. Metadata object IDs ->
				 |Update catalog data command.'"),
				Table,
				CheckResult.MetadataObject);
		EndIf;
	EndIf;
	
	Return Data[0].Ref;
	
EndFunction

// Returns a metadata object by the passed ID.
//
// Parameters:
// ID - CatalogRef.MetadataObjectIDs
//
// Returns:
// MetadataObject
//
Function MetadataObjectByID(ID) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("Ref", ID);
	Query.Text =
	"SELECT
	|	IDs.Ref,
	|	IDs.MetadataObjectKey,
	|	IDs.FullName,
	|	IDs.Used
	|FROM
	|	Catalog.MetadataObjectIDs AS IDs
	|WHERE
	|	IDs.Ref = &Ref";
	
	Data = Query.Execute().Unload();
	
	If Data.Count() = 0 Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			 NStr("en = 'Error executing CommonUse.MetadataObjectByID().
			 |
			 |The %1 ID 
			 |is not found in the Metadata objects IDs catalog.
			 |
			 |If the catalog was not updated during the infobase update,
			 |you have to update it manually:
			 |All Functions -> Catalog. Metadata object IDs ->
			 |Update catalog data command.
			 |
			 |Some metadata objects can be added to the catalog only as
			 |a predefined items, for example, subsystems.'"),
			String(ID));
	EndIf;
	
	// Checking whether metadata object key corresponds to the full metadata object name
	CheckResult = Catalogs.MetadataObjectIDs.MetadataObjectKeyCorrespondsFullName(Data[0]);
	If CheckResult.NotCorresponds Then
		If CheckResult.MetadataObject = Undefined Then
			If CheckResult.MetadataObjectKey = Undefined Then
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					 NStr("en = 'Error executing CommonUse.MetadataObjectByID().
					 |
					 |The %1 ID 
					 |is found in the Metadata objects IDs catalog
					 |but it corresponds to the nonexistent metadata object
					 |%2.
					 |
					 |If the catalog was not updated during the infobase update,
					 |you have to update it manually:
					 |All functions -> Catalog. Metadata object IDs ->
					 |Update catalog data command.'"),
					String(ID),
					Data[0].FullName);
			Else
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Error executing CommonUse.MetadataObjectByID().
					 |
					 |The %1 ID
					 |is found in the Metadata objects IDs catalog,
					 |but it corresponds to the deleted metadata object.
					 |
					 |Catalog data is incorrect. If the catalog was not updated 
					 |during the infobase update, you have to update it manually:
					 |All functions -> Catalog. Metadata object IDs ->
					 |Update catalog data command.'"),
					String(ID));
			EndIf;
		Else
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error executing CommonUse.MetadataObjectByID().
				 |
				 |The %1 ID
				 |is found in the Metadata objects IDs catalog,
				 |but it corresponds to the %2 metadata object
				 |whose full name is different from the full name specified in the ID.
				 |
				 |If the catalog was not updated during the infobase update,
				 |you have to update it manually:
				 |All functions -> Catalog. Metadata object IDs ->
				 |Update catalog data command.'"),
				String(ID),
				CheckResult.MetadataObject.FullName());
		EndIf;
	EndIf;
	
	If Not Data[0].Used Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error executing CommonUse.MetadataObjectByID().
			 |
			 |The %1 ID
			 |is found in the Metadata objects IDs catalog,
			 |but the Used attribute value is False.
			 |
			 |If the catalog was not updated during the infobase update,
			 |you have to update it manually:
			 |All functions -> Catalog. Metadata object IDs ->
			 |Update catalog data command.'"),
			String(ID));
	EndIf;
	
	Return CheckResult.MetadataObject;
	
EndFunction

// You should use this procedure only in the 
// CommonUseOverridable.FillPresetMetadataObjectIDs()
// procedure for specifying preset IDs.
// 
// Parameters:
// IDs - BaseFunctionality subsystem passes this parameter value to the procedure;
// IDString - String - UUID that is set to the metadata object; 
// MetadataObject - ID will be preset for this metadata object.
//
Procedure AddID(IDs, IDString, MetadataObject) Export
	
	Try
		ID = Catalogs.MetadataObjectIDs.GetRef(New UUID(IDString));
	Except
		ID = Undefined;
	EndTry;
	
	If TypeOf(MetadataObject) <> Type("MetadataObject") Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Error executing
			 |CommonUseOverridable.FillPresetMetadataObjectIDs() 
			 |
			 |The metadata object for the %1 ID is not filled.'"),
			IDString);
	EndIf;
	
	FullName = MetadataObject.FullName();
	
	If Not ValueIsFilled(ID) Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Error executing
			 |CommonUseOverridable.FillPresetMetadataObjectIDs() 
			 |
			 |There is an error in the %1 ID string
			 |that is specified for
			 |the %2 metadata object.'"),
			IDString,
			FullName);
	EndIf;
	
	If IDs.Find(FullName, "FullName") <> Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Error executing
			 |CommonUseOverridable.FillPresetMetadataObjectIDs() 
			 |
			 |An ID for the %1 metadata object
			 |is already set.'"),
			FullName);
	EndIf;
	
	If IDs.Find(ID, "ID") <> Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Error executing
			 |CommonUseOverridable.FillPresetMetadataObjectIDs() 
			 |
			 |The %1 ID is already set
			 |for the %2 metadata object.'"),
			IDString,
			FullName);
	EndIf;
	
	IDInfo = IDs.Add();
	IDInfo.FullName = FullName;
	IDInfo.ID = ID;
	
EndProcedure

// Returns a string presentation of the type. 
// In case of reference types the function returns a presentation in the following format: "CatalogRef.ObjectName" or "DocumentRef.ObjectName".
// For other types it transforms the type to a string, for example, "Number".
//
Function TypePresentationString(Type) Export
	
	Presentation = "";
	
	If IsReference(Type) Then
	
		FullName = Metadata.FindByType(Type).FullName();
		ObjectName = StringFunctionsClientServer.SplitStringIntoSubstringArray(FullName, ".")[1];
		
		If Catalogs.AllRefsType().ContainsType(Type) Then
			Presentation = "CatalogRef";
		
		ElsIf Documents.AllRefsType().ContainsType(Type) Then
			Presentation = "DocumentRef";
		
		ElsIf BusinessProcesses.AllRefsType().ContainsType(Type) Then
			Presentation = "BusinessProcessRef";
		
		ElsIf ChartsOfCharacteristicTypes.AllRefsType().ContainsType(Type) Then
			Presentation = "ChartOfCharacteristicTypesRef";
		
		ElsIf ChartsOfAccounts.AllRefsType().ContainsType(Type) Then
			Presentation = "ChartOfAccountsRef";
		
		ElsIf ChartsOfCalculationTypes.AllRefsType().ContainsType(Type) Then
			Presentation = "ChartOfCalculationTypesRef";
		
		ElsIf Tasks.AllRefsType().ContainsType(Type) Then
			Presentation = "TaskRef";
		
		ElsIf ExchangePlans.AllRefsType().ContainsType(Type) Then
			Presentation = "ExchangePlanRef";
		
		ElsIf Enums.AllRefsType().ContainsType(Type) Then
			Presentation = "EnumRef";
		
		EndIf;
		
		Result = ?(Presentation = "", Presentation, Presentation + "." + ObjectName);
		
	Else
		
		Result = String(Type);
		
	EndIf;
	
	Return Result;
	
EndFunction

// Checks whether the type description contains only one value type and it 
// is equal to the specified type.
//
// Returns:
// Boolean.
//
Function TypeDescriptionContainsType(TypeDescription, ValueType) Export
	
	If TypeDescription.Types().Count() = 1
	 And TypeDescription.Types().Get(0) = ValueType Then
		Return True;
	EndIf;
	
	Return False;

EndFunction

// Checks whether the catalog has the tabular section.
//
//Parameters
// CatalogName - String - name of the catalog to be checked.
// TabularSectionName - String - name of the tabular section whose existence will be checked.
//
//Returns:
// Boolean - True if the catalog has the tabular section, otherwise is False.
//
//Example:
// If Not CommonUse.CatalogHasTabularSection(CatalogName, "ContactInformation") Then
// 	Return;
// EndIf;
//
Function CatalogHasTabularSection(CatalogName, TabularSectionName) Export
	
	Return (Metadata.Catalogs[CatalogName].TabularSections.Find(TabularSectionName) <> Undefined);
	
EndFunction 

// Generates an extended object presentation.
// An extended object presentation contains an object presentation, a code, and a description.
// If generating an extended object presentation failed,
// then the function returns a standard object presentation generated by the platform.
//
// An example of the returning value:
// "Counterparty 0A-0001234, Telecom"
//
// Parameters:
// Object. Type: CatalogRef,
//				ChartOfAccountsRef,
//				ExchangePlanRef,
//				ChartOfCharacteristicTypesRef,
//				ChartOfCalculationTypesRef.
// The object whose extended presentation will be generated.
//
// Returns:
// String - extended object presentation.
// 
Function ExtendedObjectPresentation(Object) Export
	
	MetadataObject = Object.Metadata();
	
	BaseTypeName = BaseTypeNameByMetadataObject(MetadataObject);
	
	If BaseTypeName = TypeNameCatalogs()
		Or BaseTypeName = TypeNameChartsOfAccounts()
		Or BaseTypeName = TypeNameExchangePlans()
		Or BaseTypeName = TypeNameChartsOfCharacteristicTypes()
		Or BaseTypeName = TypeNameChartsOfCalculationTypes()
		Then
		
		If IsStandardAttribute(MetadataObject.StandardAttributes, "Code")
			And IsStandardAttribute(MetadataObject.StandardAttributes, "Description") Then
			
			AttributeValues = GetAttributeValues(Object, "Code, Description");
			
			ObjectPresentation = ?(IsBlankString(MetadataObject.ObjectPresentation), 
										?(IsBlankString(MetadataObject.Synonym), MetadataObject.Name, MetadataObject.Synonym
										),
									MetadataObject.ObjectPresentation
			);
			
			Result = "[ObjectPresentation] [Code], [Description]";
			Result = StrReplace(Result, "[ObjectPresentation]", ObjectPresentation);
			Result = StrReplace(Result, "[Code]", ?(IsBlankString(AttributeValues.Code), "<>", AttributeValues.Code));
			Result = StrReplace(Result, "[Description]", ?(IsBlankString(AttributeValues.Description), "<>", AttributeValues.Description));
			
		Else
			
			Result = String(Object);
			
		EndIf;
		
	Else
		
		Result = String(Object);
		
	EndIf;
	
	Return Result;
EndFunction

// Returns a flag that shows whether the attribute is a standard attribute.
//
// Parameters:
// StandardAttributes – StandardAttributeDescriptions - collection whose types and values describe standard attibutes;
// AttributeName – String – attribute to be checked.
// 
// Returns:
// Boolean. True if attribute is a standard attribute, otherwise is False.
//
Function IsStandardAttribute(StandardAttributes, AttributeName) Export
	
	For Each Attribute In StandardAttributes Do
		
		If Attribute.Name = AttributeName Then
			
			Return True;
			
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction

// Gets a value table with the required property information of all metadata object attributes.
// Gets property values of standard and custom attributes (Custom attributes are attributes created in the designer mode.)
//
// Parameters:
// MetadataObject - metadata object whose attribute property values will be retrieved.
// For example: Metadata.Document.Invoice;
// Properties - String - attribute properties separated by commas whose values will be retrieved.
// For example: "Name, Type, Synonym, ToolTip".
//
// Returns:
// ValueTable - returning value table.
//
Function GetObjectPropertyInfoTable(MetadataObject, Properties) Export
	
	PropertyArray = StringFunctionsClientServer.SplitStringIntoSubstringArray(Properties);
	
	// The value to be returned
	ObjectPropertyInfoTable = New ValueTable;
	
	// Adding fields to the value table according to the names of the passed properties
	For Each PropertyName In PropertyArray Do
		
		ObjectPropertyInfoTable.Columns.Add(TrimAll(PropertyName));
		
	EndDo;
	
	// Filling table rows with metadata object attribute values
	For Each Attribute In MetadataObject.Attributes Do
		
		FillPropertyValues(ObjectPropertyInfoTable.Add(), Attribute);
		
	EndDo;
	
	// Filling table rows with values of the standard metadata object attributes 
	For Each Attribute In MetadataObject.StandardAttributes Do
		
		FillPropertyValues(ObjectPropertyInfoTable.Add(), Attribute);
		
	EndDo;
	
	Return ObjectPropertyInfoTable;
	
EndFunction

// Returns a common attribute content item usage state.
//
// Parameters:
// ContentItem - MetadataObject - common attribute content item 
// whose usage will be checked;
// CommonAttributeMetadata - MetadataObject - common attribute metadata 
// whose ContentItem usage will be checked.
//
// Returns:
// Boolean - True if the content item is used, otherwise is False.
//
Function CommonAttributeContentItemUsed(Val ContentItem, Val CommonAttributeMetadata) Export
	
	If ContentItem.Use = Metadata.ObjectProperties.CommonAttributeUse.Use Then
		Return True;
	ElsIf ContentItem.Use = Metadata.ObjectProperties.CommonAttributeUse.DontUse Then
		Return False;
	Else
		Return CommonAttributeMetadata.AutoUse = Metadata.ObjectProperties.CommonAttributeAutoUse.Use;
	EndIf;
	
EndFunction

// Returns a flag that shows whether the metadata object is used in a common separators.
//
// Parameters:
// MetadataObject - String; MetadataObject - if metadata object is specified by the string, the function calls the CommonUseCached module.
//
// Returns:
// Boolean - True if the metadata object is used in one or more common separators.
//
Function IsSeparatedMetadataObject(Val MetadataObject) Export
	
	If TypeOf(MetadataObject) = Type("String") Then
		MetadataObjectFullName = MetadataObject;
	Else
		MetadataObjectFullName = MetadataObject.FullName();
	EndIf;
	
	SeparatedMetadataObjects = CommonUseCached.SeparatedMetadataObjects();
	Return SeparatedMetadataObjects.Get(MetadataObjectFullName) <> Undefined;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions for working with metadata object type definition.
//

// Reference data types. 

// Checks whether the metadata object belongs to the Document type.
//
// Parameters:
// MetadataObject – metadata object to be checked.
// 
// Returns:
// Boolean - True if the metadata object belongs to the specified type, otherwise is False.
//
Function IsDocument(MetadataObject) Export
	
	Return BaseTypeNameByMetadataObject(MetadataObject) = TypeNameDocuments();
	
EndFunction

// Checks whether the metadata object belongs to the Catalog type.
//
// Parameters:
// MetadataObject – metadata object to be checked.
// 
// Returns:
// Boolean - True if the metadata objects belongs to the specified type, otherwise is False.
//
Function IsCatalog(MetadataObject) Export
	
	Return BaseTypeNameByMetadataObject(MetadataObject) = TypeNameCatalogs();
	
EndFunction

// Checks whether the metadata object belongs to the Enumeration type.
// 
// Parameters:
// MetadataObject – metadata object to be checked.
// 
// Returns:
// Boolean - True if the metadata objects belongs to the specified type, otherwise is False.
//
Function IsEnum(MetadataObject) Export
	
	Return BaseTypeNameByMetadataObject(MetadataObject) = TypeNameEnums();
	
EndFunction

// Checks whether the metadata object belongs to the Exchange plan type.
// 
// Parameters:
// MetadataObject – metadata object to be checked.
// 
// Returns:
// Boolean - True if the metadata objects belongs to the specified type, otherwise is False.
//
Function IsExchangePlan(MetadataObject) Export
	
	Return BaseTypeNameByMetadataObject(MetadataObject) = TypeNameExchangePlans();
	
EndFunction

// Checks whether the metadata object belongs to the Chart of characteristic types type.
// 
// Parameters:
// MetadataObject – metadata object to be checked.
// 
// Returns:
// Boolean - True if the metadata objects belongs to the specified type, otherwise is False.
//
Function IsChartOfCharacteristicTypes(MetadataObject) Export
	
	Return BaseTypeNameByMetadataObject(MetadataObject) = TypeNameChartsOfCharacteristicTypes();
	
EndFunction

// Checks whether the metadata object belongs to the Business process type.
// 
// Parameters:
// MetadataObject – metadata object to be checked.
// 
// Returns:
// Boolean - True if the metadata objects belongs to the specified type, otherwise is False.
//
Function IsBusinessProcess(MetadataObject) Export
	
	Return BaseTypeNameByMetadataObject(MetadataObject) = TypeNameBusinessProcesses();
	
EndFunction

// Checks whether the metadata object belongs to the Task type.
// 
// Parameters:
// MetadataObject – metadata object to be checked.
// 
// Returns:
// Boolean - True if the metadata objects belongs to the specified type, otherwise is False.
//
Function IsTask(MetadataObject) Export
	
	Return BaseTypeNameByMetadataObject(MetadataObject) = TypeNameTasks();
	
EndFunction

// Checks whether the metadata object belongs to the Chart of accounts type.
// 
// Parameters:
// MetadataObject – metadata object to be checked.
// 
// Returns:
// Boolean - True if the metadata objects belongs to the specified type, otherwise is False.
//
Function IsChartOfAccounts(MetadataObject) Export
	
	Return BaseTypeNameByMetadataObject(MetadataObject) = TypeNameChartsOfAccounts();
	
EndFunction

// Checks whether the metadata object belongs to the Chart of calculation types type.
// 
// Parameters:
// MetadataObject – metadata object to be checked.
// 
// Returns:
// Boolean - True if the metadata objects belongs to the specified type, otherwise is False.
//
Function IsChartOfCalculationTypes(MetadataObject) Export
	
	Return BaseTypeNameByMetadataObject(MetadataObject) = TypeNameChartsOfCalculationTypes();
	
EndFunction

// Registers

// Checks whether the metadata object belongs to the information register type.
// 
// Parameters:
// MetadataObject – metadata object to be checked.
// 
// Returns:
// Boolean - True if the metadata objects belongs to the specified type, otherwise is False.
//
Function IsInformationRegister(MetadataObject) Export
	
	Return BaseTypeNameByMetadataObject(MetadataObject) = TypeNameInformationRegisters();
	
EndFunction

// Checks whether the metadata object belongs to the Accumulation register type.
// 
// Parameters:
// MetadataObject – metadata object to be checked.
// 
// Returns:
// Boolean - True if the metadata objects belongs to the specified type, otherwise is False.
//
Function IsAccumulationRegister(MetadataObject) Export
	
	Return BaseTypeNameByMetadataObject(MetadataObject) = TypeNameAccumulationRegisters();
	
EndFunction

// Checks whether the metadata object belongs to the Accounting register type.
// 
// Parameters:
// MetadataObject – metadata object to be checked.
// 
// Returns:
// Boolean - True if the metadata objects belongs to the specified type, otherwise is False.
//
Function IsAccountingRegister(MetadataObject) Export
	
	Return BaseTypeNameByMetadataObject(MetadataObject) = TypeNameAccountingRegisters();
	
EndFunction

// Checks whether the metadata object belongs to the Calculation register type.
// 
// Parameters:
// MetadataObject – metadata object to be checked.
// 
// Returns:
// Boolean - True if the metadata objects belongs to the specified type, otherwise is False.
//
Function IsCalculationRegister(MetadataObject) Export
	
	Return BaseTypeNameByMetadataObject(MetadataObject) = TypeNameCalculationRegisters();
	
EndFunction

// Constants.

// Checks whether the metadata object belongs to the Constant type.
// 
// Parameters:
// MetadataObject – metadata object to be checked.
// 
// Returns:
// Boolean - True if the metadata objects belongs to the specified type, otherwise is False.
//
Function IsConstant(MetadataObject) Export
	
	Return BaseTypeNameByMetadataObject(MetadataObject) = TypeNameConstants();
	
EndFunction

// Document journals.

// Checks whether the metadata object belongs to the Document journal type.
// 
// Parameters:
// MetadataObject – metadata object to be checked.
// 
// Returns:
// Boolean - True if the metadata objects belongs to the specified type, otherwise is False.
//
Function IsDocumentJournal(MetadataObject) Export
	
	Return BaseTypeNameByMetadataObject(MetadataObject) = TypeNameDocumentJournals();
	
EndFunction

// Common.

// Checks whether the metadata object belongs to a register type.
// 
// Parameters:
// MetadataObject – metadata object to be checked.
// 
// Returns:
// Boolean - True if the metadata objects belongs to the specified type, otherwise is False.
//
Function IsRegister(MetadataObject) Export
	
	BaseTypeName = BaseTypeNameByMetadataObject(MetadataObject);
	
	Return BaseTypeName = TypeNameInformationRegisters()
		Or BaseTypeName = TypeNameAccumulationRegisters()
		Or BaseTypeName = TypeNameAccountingRegisters()
		Or BaseTypeName = TypeNameCalculationRegisters();
	
EndFunction

// Checks whether the metadata object belongs to a reference type.
// 
// Parameters:
// MetadataObject – metadata object to be checked.
// 
// Returns:
// Boolean - True if the metadata objects belongs to the specified type, otherwise is False.
//
Function IsReferenceTypeObject(MetadataObject) Export
	
	BaseTypeName = BaseTypeNameByMetadataObject(MetadataObject);
	
	Return BaseTypeName = TypeNameCatalogs()
		Or BaseTypeName = TypeNameDocuments()
		Or BaseTypeName = TypeNameBusinessProcesses()
		Or BaseTypeName = TypeNameTasks()
		Or BaseTypeName = TypeNameChartsOfAccounts()
		Or BaseTypeName = TypeNameExchangePlans()
		Or BaseTypeName = TypeNameChartsOfCharacteristicTypes()
		Or BaseTypeName = TypeNameChartsOfCalculationTypes();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Type names.

// Returns a value for identification of the Information registers type. 
//
// Returns:
// String.
//
Function TypeNameInformationRegisters() Export
	
	Return "InformationRegisters";
	
EndFunction

// Returns a value for identification of the Accumulation registers type. 
//
// Returns:
// String.
//
Function TypeNameAccumulationRegisters() Export
	
	Return "AccumulationRegisters";
	
EndFunction

// Returns a value for identification of the Accounting registers type. 
//
// Returns:
// String.
//
Function TypeNameAccountingRegisters() Export
	
	Return "AccountingRegisters";
	
EndFunction

// Returns a value for identification of the Calculation registers type. 
//
// Returns:
// String.
//
Function TypeNameCalculationRegisters() Export
	
	Return "CalculationRegisters";
	
EndFunction

// Returns a value for identification of the Documents type. 
//
// Returns:
// String.
//
Function TypeNameDocuments() Export
	
	Return "Documents";
	
EndFunction

// Returns a value for identification of the Catalogs type. 
//
// Returns:
// String.
//
Function TypeNameCatalogs() Export
	
	Return "Catalogs";
	
EndFunction

// Returns a value for identification of the Enumerations type. 
//
// Returns:
// String.
//
Function TypeNameEnums() Export
	
	Return "Enums";
	
EndFunction

// Returns a value for identification of the Reports type. 
//
// Returns:
// String.
//
Function TypeNameReports() Export
	
	Return "Reports";
	
EndFunction

// Returns a value for identification of the Data processors type. 
//
// Returns:
// String.
//
Function TypeNameDataProcessors() Export
	
	Return "DataProcessors";
	
EndFunction

// Returns a value for identification of the Exchange plans type. 
//
// Returns:
// String.
//
Function TypeNameExchangePlans() Export
	
	Return "ExchangePlans";
	
EndFunction

// Returns a value for identification of the Charts of characteristic types type. 
//
// Returns:
// String.
//
Function TypeNameChartsOfCharacteristicTypes() Export
	
	Return "ChartsOfCharacteristicTypes";
	
EndFunction

// Returns a value for identification of the Business processes type. 
//
// Returns:
// String.
//
Function TypeNameBusinessProcesses() Export
	
	Return "BusinessProcesses";
	
EndFunction

// Returns a value for identification of the Tasks type. 
//
// Returns:
// String.
//
Function TypeNameTasks() Export
	
	Return "Tasks";
	
EndFunction

// Returns a value for identification of the Charts of accounts type. 
//
// Returns:
// String.
//
Function TypeNameChartsOfAccounts() Export
	
	Return "ChartsOfAccounts";
	
EndFunction

// Returns a value for identification of the Charts of calculation types type. 
//
// Returns:
// String.
//
Function TypeNameChartsOfCalculationTypes() Export
	
	Return "ChartsOfCalculationTypes";
	
EndFunction

// Returns a value for identification of the Constants type. 
//
// Returns:
// String.
//
Function TypeNameConstants() Export
	
	Return "Constants";
	
EndFunction

// Returns a value for identification of the Document journals type. 
//
// Returns:
// String.
//
Function TypeNameDocumentJournals() Export
	
	Return "DocumentJournals";
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Saving, reading, and deleting settings from storages.

// Saves settings to the common settings storage.
// 
// Parameters:
// Corresponds to the CommonSettingsStorage.Save method. 
// See StorageSave() procedure parameters for details. 
//
Procedure CommonSettingsStorageSave(ObjectKey, SettingsKey = "", Value,
	SettingsDescription = Undefined, UserName = Undefined, 
	NeedToRefreshCachedValues = False) Export
	
	StorageSave(
		CommonSettingsStorage,
		ObjectKey,
		SettingsKey,
		Value,
		SettingsDescription,
		UserName,
		NeedToRefreshCachedValues
	);
	
EndProcedure

// Loads settings from the common settings storage.
//
// Parameters:
// Corresponds to the CommonSettingsStorage.Load method. 
// See StorageLoad() procedure parameters for details. 
//
Function CommonSettingsStorageLoad(ObjectKey, SettingsKey = "", DefaultValue = Undefined, 
	SettingsDescription = Undefined, UserName = Undefined) Export
	
	Return StorageLoad(
		CommonSettingsStorage,
		ObjectKey,
		SettingsKey,
		DefaultValue,
		SettingsDescription,
		UserName
	);
	
EndFunction

// Deletes settings from the common settings storage.
// 
// Parameters:
// Corresponds to the CommonSettingsStorage.Delete method. 
// See StorageDelete() procedure parameters for details. 
//
Procedure CommonSettingsStorageDelete(ObjectKey, SettingsKey, UserName) Export
	
	StorageDelete(
		CommonSettingsStorage,
		ObjectKey,
		SettingsKey,
		UserName
	);
	
EndProcedure

// Saves an array of user settings to StructureArray. 
// Can be called on client.
// 
// Parameters:
// StructureArray - Array - Array of Structure with the following fields:
// Object, Setting, Value;
// NeedToRefreshCachedValues - Boolean - flag that shows whether reusable values will be updated.
//
Procedure CommonSettingsStorageSaveArray(StructureArray,
	NeedToRefreshCachedValues = False) Export
	
	If Not AccessRight("SaveUserData", Metadata) Then
		Return;
	EndIf;
	
	For Each Element In StructureArray Do
		CommonSettingsStorage.Save(Element.Object, Element.Setting, Element.Value);
	EndDo;
	
	If NeedToRefreshCachedValues Then
		RefreshReusableValues();
	EndIf;
	
EndProcedure

// Saves the StructureArray user settings array and updates 
// reusable values. Can be called on client.
// 
// Parameters:
// StructureArray - Array - Array of Structure with the following fields:
// Object, Setting, Value.
//
Procedure CommonSettingsStorageSaveArrayAndRefreshCachedValues(StructureArray) Export
	
	CommonSettingsStorageSaveArray(StructureArray, True);
	
EndProcedure

// Saves settings to the common settings storage and updates 
// reusable values.
// 
// Parameters:
// Corresponds to the CommonSettingsStorage.Save method. 
// See StorageSave() procedure parameters for details. 
//
Procedure CommonSettingsStorageSaveAndRefreshCachedValues(ObjectKey, SettingsKey, Value) Export
	
	CommonSettingsStorageSave(ObjectKey, SettingsKey, Value,,,True);
	
EndProcedure

// Saves settings to the common settings storage.
// 
// Parameters:
// Corresponds to the CommonSettingsStorage.Save method. 
// See StorageSave() procedure parameters for details. 
//
Procedure SystemSettingsStorageSave(ObjectKey, SettingsKey = "", Value,
	SettingsDescription = Undefined, UserName = Undefined, 
	NeedToRefreshCachedValues = False) Export
	
	StorageSave(
		SystemSettingsStorage, 
		ObjectKey, 
		SettingsKey, 
		Value,
		SettingsDescription, 
		UserName, 
		NeedToRefreshCachedValues
	);
	
EndProcedure

// Loads settings from the common settings storage.
//
// Parameters: 
// Corresponds to the CommonSettingsStorage.Load method. 
// See StorageLoad() procedure parameters for details. 
//
Function SystemSettingsStorageLoad(ObjectKey, SettingsKey = "", DefaultValue = Undefined, 
	SettingsDescription = Undefined, UserName = Undefined) Export
	
	Return StorageLoad(
		SystemSettingsStorage, 
		ObjectKey, 
		SettingsKey, 
		DefaultValue, 
		SettingsDescription, 
		UserName
	);
	
EndFunction

// Deletes settings from the common settings storage.
//
// Parameters:
// Corresponds to the CommonSettingsStorage.Delete method. 
// See StorageDelete() procedure parameters for details. 
//
Procedure SystemSettingsStorageDelete(ObjectKey, SettingsKey, UserName) Export
	
	StorageDelete(
		SystemSettingsStorage,
		ObjectKey,
		SettingsKey,
		UserName
	);
	
EndProcedure

// Saves settings to the form data settings storage.
// 
// Parameters:
// Corresponds to the CommonSettingsStorage.Save method. 
// See StorageSave() procedure parameters for details. 
//
Procedure FormDataSettingsStorageSave(ObjectKey, SettingsKey = "", Value,
	SettingsDescription = Undefined, UserName = Undefined, 
	NeedToRefreshCachedValues = False) Export
	
	StorageSave(
		FormDataSettingsStorage, 
		ObjectKey, 
		SettingsKey, 
		Value,
		SettingsDescription, 
		UserName, 
		NeedToRefreshCachedValues
	);
	
EndProcedure

// Loads settings from the form data settings storage.
//
// Parameters:
// Corresponds to the CommonSettingsStorage.Load method. 
// See StorageLoad() procedure parameters for details. 
//
Function FormDataSettingsStorageLoad(ObjectKey, SettingsKey = "", DefaultValue = Undefined, 
	SettingsDescription = Undefined, UserName = Undefined) Export
	
	Return StorageLoad(
		FormDataSettingsStorage, 
		ObjectKey, 
		SettingsKey, 
		DefaultValue, 
		SettingsDescription, 
		UserName
	);
	
EndFunction

// Deletes settings from the form data settings storage.
//
// Parameters:
// Corresponds to the CommonSettingsStorage.Delete method. 
// See StorageDelete() procedure parameters for details. 
//
Procedure FormDataSettingsStorageDelete(ObjectKey, SettingsKey, UserName) Export
	
	StorageDelete(
		FormDataSettingsStorage,
		ObjectKey,
		SettingsKey,
		UserName
	);
	
EndProcedure

// Saves settings to the settings storage through its manager.
// 
// Parameters:
// StorageManager - StandardSettingsStorageManager - storage where settings will be saved;
// ObjectKey - String - settings object key; 
// For details, see Settings automatically saved in system storage help topic;
// SettingsKey - String - saved settings key;
// Value - contains settings to be saved in the storage.
// SettingsDescription - SettingsDescription - contains information about settings.
// UserName - String - user name whose settings will be saved.
// If this parameter is not specified, current user settings will be saved.
// NeedToRefreshCachedValues - Boolean.
//
Procedure StorageSave(StorageManager, ObjectKey, SettingsKey, Value,
	SettingsDescription, UserName, NeedToRefreshCachedValues)
	
	If Not AccessRight("SaveUserData", Metadata) Then
		Return;
	EndIf;
	
	StorageManager.Save(ObjectKey, SettingsKey, Value, SettingsDescription, UserName);
	
	If NeedToRefreshCachedValues Then
		RefreshReusableValues();
	EndIf;
	
EndProcedure

// Loads settings from the settings storage through its manager.
//
// Parameters:
// StorageManager - StandardSettingsStorageManager - settings will be loaded from this storage;
// ObjectKey - String - settings object key; 
// For details, see Settings automatically saved in system storage help topic;
// SettingsKey - String - loading settings key;
// DefaultValue - value to be loaded if settings are not found.
// SettingsDescription - SettingsDescription - settings description can be retrieved through this parameter.
// UserName - String - user name whose settings will be loaded.
// If this parameter is not specified, current user settings will be loaded.
// 
// Returns: 
// Loaded from storage settings. Undefined if settings is not found and DefaultValue is Undefined.
// 
Function StorageLoad(StorageManager, ObjectKey, SettingsKey, DefaultValue,
	SettingsDescription, UserName)
	
	Result = Undefined;
	
	If AccessRight("SaveUserData", Metadata) Then
		Result = StorageManager.Load(ObjectKey, SettingsKey, SettingsDescription, UserName);
	EndIf;
	
	If (Result = Undefined) And (DefaultValue <> Undefined) Then
		Result = DefaultValue;
	EndIf;

	Return Result;
	
EndFunction

// Deletes settings from the settings storage using the settings storage manager.
//
// Parameters:
// StorageManager - StandardSettingsStorageManager - storage where settings will be deleted;
// ObjectKey - String - settings object key;
// If this parameter is Undefined, all object settings will be deleted.
// SettingsKey - String - deleting settings key;
// If this parameter is Undefined, settings with any key will be deleted.
// UserName - String - user name whose settings will be deleted;
// If this parameter is not specified, all user settings will be deleted.
// 
Procedure StorageDelete(StorageManager, ObjectKey, SettingsKey, UserName)
	
	If AccessRight("SaveUserData", Metadata) Then
		StorageManager.Delete(ObjectKey, SettingsKey, UserName);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Functions for working with spreadsheet documents.

// Checks whether the passed spreadsheet document fits a single page in the print layout.
//
// Parameters
// Spreadsheet – Spreadsheet document;
// AreasToPut – Array of Table or Spreadsheet document to be checked;
// ResultOnError - result to be returned in case of error.
//
// Returns:
// Boolean – flag that shows whether the passed spreadsheet document fits a single page.
//
Function SpreadsheetDocumentFitsPage(Spreadsheet, AreasToPut, ResultOnError = True) Export

	Try
		Return Spreadsheet.CheckPut(AreasToPut);
	Except
		Return ResultOnError;
	EndTry;

EndFunction 

////////////////////////////////////////////////////////////////////////////////
// Functions for working with the event log.

// Batch record of messages to the event log.
// 
// Parameters: 
// EventsForEventLog - Array of Structure - global client variable. 
// Each structure is a message to be recorded in the event log.
// This variable will be cleared after recording.
//
Procedure WriteEventsToEventLog(EventsForEventLog) Export
	
	If TypeOf(EventsForEventLog) <> Type("ValueList") Then
		Return;
	EndIf;	
	
	If EventsForEventLog.Count() = 0 Then
		Return;
	EndIf;
	
	For Each LogMessage In EventsForEventLog Do
		MessagesValue = LogMessage.Value;
		EventName = MessagesValue.EventName;
		EventLevel = EventLevelByPresentation(MessagesValue.LevelPresentation);
		EventDate = CurrentSessionDate();
		If MessagesValue.Property("EventDate") And ValueIsFilled(MessagesValue.EventDate) Then
			EventDate = MessagesValue.EventDate;
		EndIf;
		Comment = String(EventDate) + " " + MessagesValue.Comment;
		WriteLogEvent(EventName, EventLevel,,, Comment);
	EndDo;
	EventsForEventLog.Clear();
	
EndProcedure

// Enables event log usage.
//
// Parameters: 
// LevelList - Value list - names of event log levels to be enabled. 
//
Procedure EnableUseEventLog(LevelList = Undefined) Export
	SetPrivilegedMode(True);
	Try
		SetExclusiveMode(True);
		LevelArray = New Array();
		
		If LevelList = Undefined Then
			LevelArray.Add(EventLogLevel.Information);
			LevelArray.Add(EventLogLevel.Error);
			LevelArray.Add(EventLogLevel.Warning);
			LevelArray.Add(EventLogLevel.Note);
		Else
			LevelArray = LogEventLevelsByString(LevelList);
		EndIf;
			
		SetEventLogUsing(LevelArray);	
		SetExclusiveMode(False);
	Except
		SetPrivilegedMode(False);	
		Raise
	EndTry;
	SetPrivilegedMode(False);	
EndProcedure

// Checks whether event recording to the event log is enabled.
//
// Parameters: 
// CheckList - ValueList - list of string presentations of event log usage modes to be checked.
//					If it is Undefined, then all modes are checked.
//
// Returns:
// True if the specified modes are enabled, otherwise is False.
//
Function EventLogEnabled(CheckList = Undefined) Export	
	ModeArray = GetEventLogUsing();
	If CheckList = Undefined Then
		Return ModeArray.Count() = 4 ;
	Else
		ModeNameArray = StringFunctionsClientServer.SplitStringIntoSubstringArray(CheckList);
		For Each Name In ModeNameArray Do
			CurrentModeToCheck = EventLevelByPresentation(Name);
			If ModeArray.Find(CurrentModeToCheck) = Undefined Then
				Return False;
			EndIf;
		EndDo;
	EndIf;
	Return True;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Common procedures and function for working in data separation mode.

// Enables the exclusive infobase (data area) access mode.
//
// If data separation is enabled,
// the procedure starts a transaction and sets an exclusive managed lock
// on lock namespaces of all metadata object that are included in the DataArea separator.
//
// In other cases (for example, in case of the local mode) the procedure enables the exclusive mode.
// 
Procedure LockInfoBase() Export
	
	If Not CommonUseCached.DataSeparationEnabled() 
		Or Not CommonUseCached.CanUseSeparatedData() Then
		
		If Not ExclusiveMode() Then
			SetExclusiveMode(True);
		EndIf;
	Else
		StandardSubsystemsOverridable.LockCurrentDataArea();
	EndIf;
		
EndProcedure

// Disables the exclusive infobase (data area) access mode.
//
// If data separation is enabled and this procedure is called from the 
// exception handler, it rolls a transaction back.
// If data separation is enabled and this procedure is called not from the exception 
// handler, it commits a transaction.
//
// In other cases (for example, in case of the local mode) the procedure disables the exclusive mode.
//
Procedure UnlockInfoBase() Export
	
	If Not CommonUseCached.DataSeparationEnabled() 
		Or Not CommonUseCached.CanUseSeparatedData() Then
		
		If ExclusiveMode() Then
			SetExclusiveMode(False);
		EndIf;
	Else
		StandardSubsystemsOverridable.UnlockCurrentDataArea();
	EndIf;
	
EndProcedure

Procedure SetSessionSeparation(Val Use, Val DataArea = Undefined) Export
	
	StandardSubsystemsOverridable.SetSessionSeparation(Use, DataArea);
	
EndProcedure

// Returns a value of the current data area separator.
// If the value is not set, an error is raised.
// 
// Returns: 
// Separator value type - value of the current data area separator.
// 
Function SessionSeparatorValue() Export
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		Return 0;
	Else
		Return StandardSubsystemsOverridable.SessionSeparatorValue();
	EndIf;
	
EndFunction

Function UseSessionSeparator() Export
	
	Return StandardSubsystemsOverridable.UseSessionSeparator();
	
EndFunction

// Initializes the infobase separation.
// 
// Parameters:
// TurnOnDataSeparation - Boolean - flag that shows whether 
// the infobase separation will be enabled.
//
Procedure SetInfoBaseSeparationParameters(Val TurnOnDataSeparation = False) Export
	
	SetPrivilegedMode(True);

	Constants.UseSeparationByDataAreas.Set(TurnOnDataSeparation);
	
EndProcedure

// Sets values of two additional constants.
// Constant names are strictly regulated and have to fit the following patterns:
// <Main constant name>ServiceMode
// <Main constant name>LocalMode
//
// Parameters:
// Value – Boolean – main constant value;
// ConstantName – String – main constant name.
//
Procedure SetAdditionalConstantValues(Val Value, Val ConstantName) Export
	
	If Value = True Then
		
		DataSeparationEnabled = CommonUseCached.DataSeparationEnabled();
		
		Constants[ConstantName + "ServiceMode"].Set(DataSeparationEnabled);
		Constants[ConstantName + "LocalMode"].Set(Not DataSeparationEnabled);
		
	Else
		
		Constants[ConstantName + "ServiceMode"].Set(False);
		Constants[ConstantName + "LocalMode"].Set(False);
		
	EndIf;
	
EndProcedure

/////////////////////////////////////////////////////////////////////////////////
// Interface versioning.

// Returns an array of version numbers supported by the remote system interface.
//
// Parameters:
// ConnectionParameters - Structure:
//							- URL - String - service URL. It must be supplied and cannot be empty;
//							- UserName - String - service user name;
//							- Password - String - service user password;
// InterfaceName - String.
//
// Returns:
// FixedArray - Array of String - each string contains interface version number presentation. For example, "1.0.2.1".
//
// Example:
//	 ConnectionParameters = New Structure;
//	 ConnectionParameters.Insert("URL", "http://vsrvx/sm");
//	 ConnectionParameters.Insert("UserName", "Doe");
//	 VersionArray = GetInterfaceVersions(ConnectionParameters, "FileTransferServer");
//
// Note: when getting versions, a cache is used. It updates once a day.
// If you need to update the cache, you have to delete corresponding records from the
// ProgramInterfaceCache information register.
//
Function GetInterfaceVersions(Val ConnectionParameters, Val InterfaceName) Export
	
	If Not ConnectionParameters.Property("URL") 
		Or Not ValueIsFilled(ConnectionParameters.URL) Then
		
		Raise(NStr("en = 'Service URL is not specified.'"));
	EndIf;
	
	ReceptionParameters = New Array;
	ReceptionParameters.Add(ConnectionParameters);
	ReceptionParameters.Add(InterfaceName);
	
	Return CommonUseCached.GetVersionCacheData(
		VersionCacheRecordID(ConnectionParameters.URL, InterfaceName), 
		Enums.ProgramInterfaceCacheDataTypes.InterfaceVersions, 
		ValueToXMLString(ReceptionParameters),
		True);
	
EndFunction

// Returns an array of version numbers supported by the interface of a system that is connected via the external connection.
//
// Parameters:
// ExternalConnection - COM connection object that is used for working with a correspondent;
// InterfaceName - String.
//
// Returns:
// FixedArray - Array of String - each string contains interface version number presentation. For example, "1.0.2.1".
//
// Example:
// Parameters = ...
// ExternalConnection = CommonUse.SetExternalConnection(Parameters);
// VersionArray = CommonUse.GetInterfaceVersionsViaExternalConnection(ExternalConnection, "DataExchange");
//
Function GetInterfaceVersionsViaExternalConnection(ExternalConnection, Val InterfaceName) Export
	
	Try
		XMLInterfaceVersions = ExternalConnection.StandardSubsystemsServer.SupportedVersions(InterfaceName);
	Except
		MessageString = NStr("en = 'Correspondent does not support interface versioning.
			|Error details: %1'"
		);
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, DetailErrorDescription(ErrorInfo()));
		WriteLogEvent(NStr("en = 'Getting interface versions'", Metadata.DefaultLanguage.LanguageCode), EventLogLevel.Error,,, MessageString);
		
		Return New FixedArray(New Array);
	EndTry;
	
	Return New FixedArray(ValueFromXMLString(XMLInterfaceVersions));
EndFunction

// Deletes version cache records that contain the specified
// substring in IDs. You can use, for example, a name of an interface that is not used any more in 
// the configuration as a substring.
//
// Parameters:
// IDSearchSubstring - String - ID search substring. It cannot contain 
// the % character, the _ character, and the [ character.
//
Procedure VersionCacheRecordDeletion(Val IDSearchSubstring) Export
	
	BeginTransaction();
	
	DataLock = New DataLock;
	DataLock.Add("InformationRegister.ProgramInterfaceCache");
	DataLock.Lock();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ProgramInterfaceCache.ID AS ID,
	|	ProgramInterfaceCache.DataType AS DataType
	|FROM
	|	InformationRegister.ProgramInterfaceCache AS ProgramInterfaceCache
	|WHERE
	|	ProgramInterfaceCache.ID LIKE ""%" + GenerateSearchQueryString(IDSearchSubstring) + "%""
	|		ESCAPE ""~""";
	Result = Query.Execute();
	Selection = Result.Select();
	While Selection.Next() Do
		Record = InformationRegisters.ProgramInterfaceCache.CreateRecordManager();
		Record.ID = Selection.ID;
		Record.DataType = Selection.DataType;
		Record.Delete();
	EndDo;
	
	CommitTransaction();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

Function EventLevelByPresentation(LevelPresentation)
	If LevelPresentation = "Information" Then
		Return EventLogLevel.Information;
	ElsIf LevelPresentation = "Error" Then
		Return EventLogLevel.Error;
	ElsIf LevelPresentation = "Warning" Then
		Return EventLogLevel.Warning; 
	ElsIf LevelPresentation = "Note" Then
		Return EventLogLevel.Note;
	EndIf;	
EndFunction

Function LogEventLevelsByString(LevelList)
	LevelNameArray = StringFunctionsClientServer.SplitStringIntoSubstringArray(LevelList);
	LevelArray = New Array;
	For Each Name In LevelNameArray Do
		LevelArray.Add(EventLevelByPresentation(Name));
	EndDo;
	Return LevelArray;
EndFunction

Procedure NewMetadataObjectCollectionRow(Name, Synonym, Picture, ObjectPicture, Tab)
	
	NewRow = Tab.Add();
	NewRow.Name = Name;
	NewRow.Synonym = Synonym;
	NewRow.Picture = Picture;
	NewRow.ObjectPicture = ObjectPicture;
	
EndProcedure

Procedure RefreshVersionCacheData(Val ID, Val DataType, Val ReceptionParameters) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ProgramInterfaceCache.UpdateDate AS UpdateDate,
	|	ProgramInterfaceCache.Data AS Data,
	|	ProgramInterfaceCache.DataType AS DataType
	|FROM
	|	InformationRegister.ProgramInterfaceCache AS ProgramInterfaceCache
	|WHERE
	|	ProgramInterfaceCache.ID = &ID
	|	AND ProgramInterfaceCache.DataType = &DataType";
	ID = ID;
	Query.SetParameter("ID", ID);
	Query.SetParameter("DataType", DataType);
	
	BeginTransaction();
	
	DataLock = New DataLock;
	LockItem = DataLock.Add("InformationRegister.ProgramInterfaceCache");
	LockItem.SetValue("ID", ID);
	LockItem.SetValue("DataType", DataType);
	DataLock.Lock();
	
	Result = Query.Execute();
	
	// Making sure that the data requires to be updated
	If Not Result.IsEmpty() Then
		Selection = Result.Select();
		Selection.Next();
		If Not VersionCacheRecordObsolete(Selection) Then
			// The data is relevant
			RollbackTransaction();
			Return;
		EndIf;
	EndIf;
	
	If DataType = Enums.ProgramInterfaceCacheDataTypes.InterfaceVersions Then
		Data = GetInterfaceVersionsToCache(ReceptionParameters[0], ReceptionParameters[1]);
	ElsIf DataType = Enums.ProgramInterfaceCacheDataTypes.WebServiceDetails Then
		Data = GetWSDL(ReceptionParameters[0], ReceptionParameters[1], ReceptionParameters[2]);
	Else
		TextTemplate = NStr("en = 'Unknown version cache data type: %1'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(TextTemplate, DataType);
		Raise(MessageText);
	EndIf;
	
	RecordManager = InformationRegisters.ProgramInterfaceCache.CreateRecordManager();
	RecordManager.ID = ID;
	RecordManager.DataType = DataType;
	RecordManager.UpdateDate = CurrentUniversalDate();
	RecordManager.Data = New ValueStorage(Data);
	RecordManager.Write();
	
	CommitTransaction();
	
EndProcedure

Function VersionCacheRecordObsolete(Val Record) Export
	
	If Record.DataType = Enums.ProgramInterfaceCacheDataTypes.WebServiceDetails Then
		Return Not ValueIsFilled(Record.UpdateDate)
	Else
		Return Record.UpdateDate + 86400 < CurrentUniversalDate();
	EndIf;
	
EndFunction

Function VersionCacheRecordID(Val Address, Val Name) Export
	
	Return Address + "|" + Name;
	
EndFunction

Function GetInterfaceVersionsToCache(Val ConnectionParameters, Val InterfaceName)
	
	StandardSubsystemsOverridable.ConvertServiceConnectionParameters(ConnectionParameters, InterfaceName);
	
	If Not ConnectionParameters.Property("URL") 
		Or Not ValueIsFilled(ConnectionParameters.URL) Then
		
		Raise(NStr("en = 'Service URL is not specified.'"));
	EndIf;
	
	If ConnectionParameters.Property("UserName")
		And ValueIsFilled(ConnectionParameters.UserName) Then
		
		UserName = ConnectionParameters.UserName;
		
		If ConnectionParameters.Property("Password") Then
			UserPassword = ConnectionParameters.Password;
		Else
			UserPassword = Undefined;
		EndIf;
		
	Else
		UserName = Undefined;
		UserPassword = Undefined;
	EndIf;
	
	ServiceAddress = ConnectionParameters.URL + "/ws/InterfaceVersioning?wsdl";
	
	VersioningProxy = CommonUseCached.GetWSProxy(ServiceAddress, "http://1c-dn.com/SaaS/1.0/WS",
		"InterfaceVersioning", , UserName, UserPassword);
		
	XDTOArray = VersioningProxy.GetVersions(InterfaceName);
	If XDTOArray = Undefined Then
		Return New FixedArray(New Array);
	Else	
		Serializer = New XDTOSerializer(VersioningProxy.XDTOFactory);
		Return New FixedArray(Serializer.ReadXDTO(XDTOArray));
	EndIf;
	
EndFunction

Function GetWSDL(Val Address, Val UserName, Val Password)
	
	ReceptionParameters = New Structure;
	If Not IsBlankString(UserName) Then
		ReceptionParameters.Insert("User", UserName);
		ReceptionParameters.Insert("Password", Password);
	EndIf;
	
	FileDetails = Undefined;
	StandardSubsystemsOverridable.DownloadFileAtServer(Address, ReceptionParameters, FileDetails);
	
	If Not FileDetails.State Then
		Raise(NStr("en = 'Error getting the Web service description file:'") + Chars.LF + FileDetails.ErrorMessage)
	EndIf;
	
	// Trying to create WS definitions based on the received file
	Definitions = New WSDefinitions(FileDetails.Path);
	If Definitions.Services.Count() = 0 Then
		MessagePattern = NStr("en = 'Error getting the Web service description file:
			|The received file does not contain any service descriptions.
			|
			|Possible, the description file address is specified incorrectly:
			|%1'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Address);
		Raise(MessageText);
	EndIf;
	Definitions = Undefined;
	
	FileData = New BinaryData(FileDetails.Path);
	
	Try
		DeleteFiles(FileDetails.Path);
	Except
		WriteLogEvent(NStr("en = 'TempFileDeletion'", Metadata.DefaultLanguage.LanguageCode), EventLogLevel.Error, , , 
			DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Return FileData;
	
EndFunction

// Internal use only.
Function SubsystemExists(FullSubsystemName) Export
	
	SubsystemNames = StandardSubsystemsCached.SubsystemNames();
	Return SubsystemNames.Get(FullSubsystemName) <> Undefined;
	
EndFunction

// Internal use only.
Function IsSubordinateDIBNode() Export
	
	SetPrivilegedMode(True);
	
	Return ExchangePlans.MasterNode() <> Undefined;
	
EndFunction

// Internal use only.
Function SubordinateDIBNodeConfigurationUpdateRequired() Export
	
	Return IsSubordinateDIBNode() And ConfigurationChanged();
	
EndFunction

// Internal use only.
Function CommonModule(Name) Export
	
	If Metadata.CommonModules.Find(Name) <> Undefined Then
		Module = SafeMode.EvaluateInSafeMode(Name);
	ElsIf StrOccurrenceCount(Name, ".") = 1 Then
		Return ManagerServerModule(Name);
	Else
		Module = Undefined;
	EndIf;
	
	If TypeOf(Module) <> Type("CommonModule") Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='%1 common module not found.'"), Name);
	EndIf;
	
	Return Module;
	
EndFunction

// Internal use only.
Function ManagerServerModule(Name)
	ObjectFound = False;
	                  
	NameParts = StringFunctionsClientServer.SplitStringIntoSubstringArray(Name, ".");
	If NameParts.Count() = 2 Then
		
		TypeName = Upper(NameParts[0]);
		ObjectName = NameParts[1];
		
		If TypeName = Upper(TypeNameConstants()) Then
			If Metadata.Constants.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf TypeName = Upper(TypeNameInformationRegisters()) Then
			If Metadata.InformationRegisters.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf TypeName = Upper(TypeNameAccumulationRegisters()) Then
			If Metadata.AccumulationRegisters.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf TypeName = Upper(TypeNameAccountingRegisters()) Then
			If Metadata.AccountingRegisters.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf TypeName = Upper(TypeNameCalculationRegisters()) Then
			If Metadata.CalculationRegisters.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf TypeName = Upper(TypeNameCatalogs()) Then
			If Metadata.Catalogs.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf TypeName = Upper(TypeNameDocuments()) Then
			If Metadata.Documents.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf TypeName = Upper(TypeNameReports()) Then
			If Metadata.Reports.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf TypeName = Upper(TypeNameDataProcessors()) Then
			If Metadata.DataProcessors.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf TypeName = Upper(TypeNameBusinessProcesses()) Then
			If Metadata.BusinessProcesses.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf TypeName = Upper(TypeNameDocumentJournals()) Then
			If Metadata.DocumentJournals.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf TypeName = Upper(TypeNameTasks()) Then
			If Metadata.Tasks.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf TypeName = Upper(TypeNameChartsOfAccounts()) Then
			If Metadata.ChartsOfAccounts.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf TypeName = Upper(TypeNameExchangePlans()) Then
			If Metadata.ExchangePlans.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf TypeName = Upper(TypeNameChartsOfCharacteristicTypes()) Then
			If Metadata.ChartsOfCharacteristicTypes.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf TypeName = Upper(TypeNameChartsOfCalculationTypes()) Then
			If Metadata.ChartsOfCalculationTypes.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		EndIf;
		
	EndIf;
	
	If Not ObjectFound Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='The %1 metadata object is not found"
"or obtaining of the manager module for this object is not supported.'"), Name);
	EndIf;
	
	Module = SafeMode.EvaluateInSafeMode(Name);
	
	Return Module;
EndFunction

// Internal use only.
Function CommonBaseFunctionalityParameters() Export
	
	CommonParameters = New Structure;
	CommonParameters.Insert("PersonalSettingsFormName", "");
	CommonParameters.Insert("LowestPlatformVersion", "8.3.4.365");
	CommonParameters.Insert("MustExit", True);
	CommonParameters.Insert("AskConfirmationOnExit", True);
	CommonParameters.Insert("DisableMetadataObjectIDsCatalog", False);
	
	CommonUseOverridable.BasicFunctionalityCommonParametersOnDefine(CommonParameters);
	
	CommonUseOverridable.PersonalSettingsFormName(CommonParameters.PersonalSettingsFormName);
	CommonUseOverridable.GetMinRequiredPlatformVersion(CommonParameters);
	
	Return CommonParameters;
	
EndFunction

// Internal use only.
Function IsEqualData(Data1, Data2) Export
	
	If TypeOf(Data1) <> TypeOf(Data2) Then
		Return False;
	EndIf;
	
	If TypeOf(Data1) = Type("Structure")
	 Or TypeOf(Data1) = Type("FixedStructure") Then
		
		If Data1.Count() <> Data2.Count() Then
			Return False;
		EndIf;
		
		For Each KeyAndValue In Data1 Do
			OldValue = Undefined;
			
			If Not Data2.Property(KeyAndValue.Key, OldValue)
			 Or Not IsEqualData(KeyAndValue.Value, OldValue) Then
			
				Return False;
			EndIf;
		EndDo;
		
		Return True;
		
	ElsIf TypeOf(Data1) = Type("Map")
	      Or TypeOf(Data1) = Type("FixedMap") Then
		
		If Data1.Count() <> Data2.Count() Then
			Return False;
		EndIf;
		
		NewMapKeys = New Map;
		
		For Each KeyAndValue In Data1 Do
			NewMapKeys.Insert(KeyAndValue.Key, True);
			OldValue = Data2.Get(KeyAndValue.Key);
			
			If Not IsEqualData(KeyAndValue.Value, OldValue) Then
				Return False;
			EndIf;
		EndDo;
		
		For Each KeyAndValue In Data2 Do
			If NewMapKeys[KeyAndValue.Key] = Undefined Then
				Return False;
			EndIf;
		EndDo;
		
		Return True;
		
	ElsIf TypeOf(Data1) = Type("Array")
	      Or TypeOf(Data1) = Type("FixedArray") Then
		
		If Data1.Count() <> Data2.Count() Then
			Return False;
		EndIf;
		
		Index = Data1.Count()-1;
		While Index >= 0 Do
			If Not IsEqualData(Data1.Get(Index), Data2.Get(Index)) Then
				Return False;
			EndIf;
			Index = Index - 1;
		EndDo;
		
		Return True;
		
	ElsIf TypeOf(Data1) = Type("ValueTable") Then
		
		If Data1.Count() <> Data2.Count() Then
			Return False;
		EndIf;
		
		If Data1.Columns.Count() <> Data2.Columns.Count() Then
			Return False;
		EndIf;
		
		For Each Column In Data1.Columns Do
			If Data2.Columns.Find(Column.Name) = Undefined Then
				Return False;
			EndIf;
			
			Index = Data1.Count()-1;
			While Index >= 0 Do
				If Not IsEqualData(Data1[Index][Column.Name], Data2[Index][Column.Name]) Then
					Return False;
				EndIf;
				Index = Index - 1;
			EndDo;
		EndDo;
		
		Return True;
		
	ElsIf TypeOf(Data1) = Type("ValueStorage") Then
	
		If Not IsEqualData(Data1.Get(), Data2.Get()) Then
			Return False;
		EndIf;
		
		Return True;
	EndIf;
	
	Return Data1 = Data2;
	
EndFunction

// Internal use only.
Function EventHandlers(Event) Export
	
	Return StandardSubsystemsCached.ServerEventHandlers(Event, False);
	
EndFunction

// Internal use only.
Function InternalEventHandlers(Event) Export
	
	Return StandardSubsystemsCached.ServerEventHandlers(Event, True);
	
EndFunction

// Internal use only.
Function FixedData(Data, RaiseException = True) Export
	
	If TypeOf(Data) = Type("Array") Then
		Array = New Array;
		
		Index = Data.Count() - 1;
		
		For Each Value In Data Do
			
			If TypeOf(Value) = Type("Structure")
			 Or TypeOf(Value) = Type("Map")
			 Or TypeOf(Value) = Type("Array") Then
				
				Array.Add(FixedData(Value, RaiseException));
			Else
				If RaiseException Then
					CheckDataIsFixed(Value, True);
				EndIf;
				Array.Add(Value);
			EndIf;
		EndDo;
		
		Return New FixedArray(Array);
		
	ElsIf TypeOf(Data) = Type("Structure")
	      Or TypeOf(Data) = Type("Map") Then
		
		If TypeOf(Data) = Type("Structure") Then
			Collection = New Structure;
		Else
			Collection = New Map;
		EndIf;
		
		For Each KeyAndValue In Data Do
			Value = KeyAndValue.Value;
			
			If TypeOf(Value) = Type("Structure")
			 Or TypeOf(Value) = Type("Map")
			 Or TypeOf(Value) = Type("Array") Then
				
				Collection.Insert(
					KeyAndValue.Key, FixedData(Value, RaiseException));
			Else
				If RaiseException Then
					CheckDataIsFixed(Value, True);
				EndIf;
				Collection.Insert(KeyAndValue.Key, Value);
			EndIf;
		EndDo;
		
		If TypeOf(Data) = Type("Structure") Then
			Return New FixedStructure(Collection);
		Else
			Return New FixedMap(Collection);
		EndIf;
		
	ElsIf RaiseException Then
		CheckDataIsFixed(Data);
	EndIf;
	
	Return Data;
	
EndFunction

// Internal use only.
Procedure CheckDataIsFixed(Data, DataInFixedTypeValue = False)
	
	DataType = TypeOf(Data);
	
	If DataType = Type("ValueStorage")
	 Or DataType = Type("FixedArray")
	 Or DataType = Type("FixedStructure")
	 Or DataType = Type("FixedMap") Then
		
		Return;
	EndIf;
	
	If DataInFixedTypeValue Then
		
		If DataType = Type("Boolean")
		 Or DataType = Type("String")
		 Or DataType = Type("Number")
		 Or DataType = Type("Date")
		 Or DataType = Type("Undefined")
		 Or DataType = Type("UUID")
		 Or DataType = Type("Null")
		 Or DataType = Type("Type")
		 Or DataType = Type("ValueStorage")
		 Or DataType = Type("CommonModule")
		 Or DataType = Type("MetadataObject")
		 Or DataType = Type("XDTOValueType")
		 Or DataType = Type("XDTOObjectType")
		 Or IsReference(DataType) Then
			
			Return;
		EndIf;
	EndIf;
	
	Raise StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Error in FixedData function of CommonUse module."
"Data of %1 type can not be fixed.'"),
		String(DataType) );
	
EndProcedure

// Internal use only.
Function OnCreateAtServer(Form, Cancel, StandardProcessing) Export
	
	If CommonUseCached.DataSeparationEnabled()
		And Not CommonUseCached.CanUseSeparatedData() Then
		Cancel = True;
		Return False;
	EndIf;
	
	If Form.Parameters.Property("AutoTest") Then
		Return False;
	EndIf;
	
	SetPrivilegedMode(True);
	If SessionParameters.ClientParametersAtServer.Get("HideDesktopOnStart") <> Undefined Then
		Cancel = True;
		Return False;
	EndIf;
	SetPrivilegedMode(False);
	
	Return True;
	
EndFunction

// Internal use only.
Function DefaultLanguageCode() Export
	
	Return Metadata.DefaultLanguage.LanguageCode;
	
EndFunction