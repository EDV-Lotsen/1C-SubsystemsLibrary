////////////////////////////////////////////////////////////////////////////////
// Contact information subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// This function generates presentation and kind for address input form.
//
// Parameters:
//    AddressStructure  - Structure - address structure.
//    Presentation      - String    - address presentation.
//    KindDescription   - String    - kind description.
//
// Returns:
//    String - address and kind presentation.
//
Function GenerateAddressPresentation(AddressStructure, Presentation, KindDescription = Undefined) Export 
	
	Presentation = "";
	
	Country = ValueByStructureKey("Country", AddressStructure);
	
	If Country <> Undefined Then
		SupplementAddressPresentation(TrimAll(ValueByStructureKey("CountryDescription", AddressStructure)), ", ", Presentation);
	EndIf;
	
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("Index", AddressStructure)),			", ", Presentation);
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("State", AddressStructure)),			", ", Presentation);
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("County", AddressStructure)),			", ", Presentation);
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("City", AddressStructure)),			", ", Presentation);
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("Settlement", AddressStructure)),	", ", Presentation);
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("Street", AddressStructure)),			", ", Presentation);
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("Building", AddressStructure)),				", " + ValueByStructureKey("BuildingType", AddressStructure) + " # ", Presentation);
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("Unit", AddressStructure)),			", " + ValueByStructureKey("UnitType", AddressStructure)+ " ", Presentation);
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("Apartment", AddressStructure)),			", " + ValueByStructureKey("ApartmentType", AddressStructure) + " ", Presentation);
	
	If StrLen(Presentation) > 2 Then
		Presentation = Mid(Presentation, 3);
	EndIf;
	
	KindDescription	= ValueByStructureKey("KindDescription", AddressStructure);
	PresentationWithKind = KindDescription + ": " + Presentation;
	
	Return PresentationWithKind;
	
EndFunction

// Generates a string presentation of a phone number.
//
// Parameters:
//    CountryCode  - String - country code.
//    AreaCode     - String - area code.
//    PhoneNumber  - String - phone number.
//    Extension    - String - extension.
//    Comment      - String - comment.
//
// Returns - String - phone number presentation.
//
Function GeneratePhonePresentation(CountryCode, AreaCode, PhoneNumber, Extension, Comment) Export
	
	Presentation = TrimAll(CountryCode);
	If Not IsBlankString(Presentation) And Left(Presentation,1) <> "+" Then
		Presentation = "+" + Presentation;
	EndIf;
	
	If Not IsBlankString(AreaCode) Then
		Presentation = Presentation + ?(IsBlankString(Presentation), "", " ") + "(" + TrimAll(AreaCode) + ")";
	EndIf;
	
	If Not IsBlankString(PhoneNumber) Then
		Presentation = Presentation + ?(IsBlankString(Presentation), "", " ") + TrimAll(PhoneNumber);
	EndIf;
	
	If Not IsBlankString(Extension) Then
		Presentation = Presentation + ?(IsBlankString(Presentation), "", ", ") + "ext. " + TrimAll(Extension);
	EndIf;
	
	If Not IsBlankString(Comment) Then
		Presentation = Presentation + ?(IsBlankString(Presentation), "", ", ") + TrimAll(Comment);
	EndIf;
	
	Return Presentation;
	
EndFunction

//Returns contact information structure by type
//
// Parameters:
//    CIType - EnumRef.ContactInformationTypes - contact information type
//
// Returns:
//    Structure - empty contact information structure, keys - field names, fields values
//
Function ContactInformationStructureByType(CIType) Export
	
	If CIType = PredefinedValue("Enum.ContactInformationTypes.Address") Then
		Return AddressFieldStructure();
	ElsIf CIType = PredefinedValue("Enum.ContactInformationTypes.Phone") Then
		Return PhoneFieldStructure();
	Else
		Return New Structure;
	EndIf;
	
EndFunction

#EndRegion

#Region InternalProceduresAndFunctions

// Adds string to address presentation.
//
// Parameters:
//    Supplement          - String - string to be added to address.
//    ConcatenationString - String - concatenation string.
//    Presentation        - String - address presentation.
//
Procedure SupplementAddressPresentation(Supplement, ConcatenationString, Presentation)
	
	If Supplement <> "" Then
		Presentation = Presentation + ConcatenationString + Supplement;
	EndIf;
	
EndProcedure

// Returns value string by structure property.
// 
// Parameters:
//    Key       - String - structure key.
//    Structure - Structure - passed structure.
//
// Returns:
//    Arbitrary - value.
//    String    - empty string if no value
//
Function ValueByStructureKey(Key, Structure)
	
	Value = Undefined;
	
	If Structure.Property(Key, Value) Then 
		Return String(Value);
	EndIf;
	
	Return "";
	
EndFunction

// Returns a string of additional values by attribute name.
//
// Parameters:
//    Form          - ManagedForm - passed form.
//    AttributeName - String      - attribute name.
//
// Returns:
//    CollectionRow - collection string.
//    Undefined     - no data
//
Function GetAdditionalValueString(Form, AttributeName) Export
	
	Filter = New Structure("AttributeName", AttributeName);
	Rows = Form.ContactInformationAdditionalAttributeInfo.FindRows(Filter);
	
	Return ?(Rows.Count() = 0, Undefined, Rows[0]);
	
EndFunction

// Returns empty address structure
//
// Returns:
//    Structure - address, keys - field names, fields values
//
Function AddressFieldStructure() Export
	
	AddressStructure = New Structure;
	AddressStructure.Insert("Presentation", "");
	AddressStructure.Insert("Country", "");
	AddressStructure.Insert("CountryDescription", "");
	AddressStructure.Insert("CountryCode","");
	AddressStructure.Insert("Index","");
	AddressStructure.Insert("State","");
	AddressStructure.Insert("StateAbbr","");
	AddressStructure.Insert("County","");
	AddressStructure.Insert("CountyAbbr","");
	AddressStructure.Insert("City","");
	AddressStructure.Insert("CityAbbr","");
	AddressStructure.Insert("Settlement","");
	AddressStructure.Insert("SettlementAbbr","");
	AddressStructure.Insert("Street","");
	AddressStructure.Insert("StreetAbbr","");
	AddressStructure.Insert("Building","");
	AddressStructure.Insert("Unit","");
	AddressStructure.Insert("Apartment","");
	AddressStructure.Insert("BuildingType","");
	AddressStructure.Insert("UnitType","");
	AddressStructure.Insert("ApartmentType","");
	AddressStructure.Insert("KindDescription","");
	
	Return AddressStructure;
	
EndFunction

// Returns empty phone structure
//
// Returns:
//    Structure - keys - field names, field values
//
Function PhoneFieldStructure() Export
	
	PhoneStructure = New Structure;
	PhoneStructure.Insert("Presentation", "");
	PhoneStructure.Insert("CountryCode", "");
	PhoneStructure.Insert("AreaCode", "");
	PhoneStructure.Insert("PhoneNumber", "");
	PhoneStructure.Insert("Extension", "");
	PhoneStructure.Insert("Comment", "");
	
	Return PhoneStructure;
	
EndFunction

// Gets abbreviated geographical name of an object
//
// Parameters:
//    GeographicalName - String - geographical name of object
//
// Returns:
//     String - empty string, or last word of the geographical name
//
Function AddressAbbreviation(Val GeographicalName) Export
	
	Abbr = "";
	WordArray = StringFunctionsClientServer.SplitStringIntoWordArray(GeographicalName, " ");
	If WordArray.Count() > 1 Then
		Abbr = WordArray[WordArray.Count() - 1];
	EndIf;
	
	Return Abbr;
	
EndFunction

// Returns field list string.
//
// Parameters:
//    FieldMap       - ValueList - field mapping.
//    NoEmptyFields  - Boolean   - flag specifying that fields with empty values should be kept (optional)
//
//  Returns:
//     String - list transformation result
//
Function ConvertFieldListToString(FieldMap, NoEmptyFields = True) Export
	
	FieldValueStructure = New Structure;
	For Each Item In FieldMap Do
		FieldValueStructure.Insert(Item.Presentation, Item.Value);
	EndDo;
	
	Return FieldRow(FieldValueStructure, NoEmptyFields);
EndFunction

// Returns value list. Transforms field string to value list.
//
// Parameters:
//    FieldRow - String - field string.
//
// Returns:
//    ValueList - field value list.
//
Function ConvertStringToFieldList(FieldRow) Export
	
	// Transformation of XML serialization not necessary
	If ContactInformationClientServer.IsXMLContactInformation(FieldRow) Then
		Return FieldRow;
	EndIf;
	
	Result = New ValueList;
	
	FieldValueStructure = FieldValueStructure(FieldRow);
	For Each AttributeValue In FieldValueStructure Do
		Result.Add(AttributeValue.Value, AttributeValue.Key);
	EndDo;
	
	Return Result;
	
EndFunction

//  Transforms string containing Key=Value pairs to structure
//
//  Parameters:
//      FieldRow               - String - string containing data fields in Key=Value format 
//      ContactInformationKind - CatalogRef.ContactInformationKinds - used to determine unfilled field content
//
//  Returns:
//      Structure - field values
//
Function FieldValueStructure(FieldRow, ContactInformationKind = Undefined) Export
	
	If ContactInformationKind = Undefined Then
		Result = New Structure;
	Else
		Result = ContactInformationStructureByType(ContactInformationKind.Type);
	EndIf;
	
	LastItem = Undefined;
	
	For Iteration = 1 To StrLineCount(FieldRow) Do
		ReceivedString = StrGetLine(FieldRow, Iteration);
		If Left(ReceivedString, 1) = Chars.Tab Then
			If Result.Count() > 0 Then
				Result.Insert(LastItem, Result[LastItem] + Chars.LF + Mid(ReceivedString, 2));
			EndIf;
		Else
			CharPosition = Find(ReceivedString, "=");
			If CharPosition <> 0 Then
				FieldValue = Left(ReceivedString, CharPosition - 1);
				AttributeValue = Mid(ReceivedString, CharPosition + 1);
				If FieldValue = "State" Or FieldValue = "County" Or FieldValue = "City" 
					Or FieldValue = "Settlement" Or FieldValue = "Street" Then
					If Find(FieldRow, FieldValue + "Abbr") = 0 Then
						Result.Insert(FieldValue + "Abbr", AddressAbbreviation(AttributeValue));
					EndIf;
				EndIf;
				Result.Insert(FieldValue, AttributeValue);
				LastItem = FieldValue;
			EndIf;
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

//  Returns field list string.
//
//  Parameters:
//    FieldValueStructure - Structure - field value structure.
//    NoEmptyFields       - Boolean   - flag specifying if fields with empty values should be kept (optional)
//
//  Returns:
//      String - structure transformation result
//
Function FieldRow(FieldValueStructure, NoEmptyFields = True) Export
	
	Result = "";
	For Each AttributeValue In FieldValueStructure Do
		If NoEmptyFields And IsBlankString(AttributeValue.Value) Then
			Continue;
		EndIf;
		
		Result = Result + ?(Result = "", "", Chars.LF)
		            + AttributeValue.Key + "=" + StrReplace(AttributeValue.Value, Chars.LF, Chars.LF + Chars.Tab);
	EndDo;
	
	Return Result;
EndFunction

#EndRegion
