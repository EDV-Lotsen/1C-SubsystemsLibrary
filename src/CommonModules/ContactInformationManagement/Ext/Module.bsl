////////////////////////////////////////////////////////////////////////////////
// Contact information subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for reading contact information by other subsystems.

// Retrieves a value of the specified contact information kind of the object.
//
// Parameters:
// Ref - AnyRef - reference to the contact information owner object (such a company, a counterparty, a partner, and so on).
// ContactInformationKind - CatalogRef.ContactInformationKinds
//
// Returns:
// String - value string presentation.
//
Function GetObjectContactInformation(Ref, ContactInformationKind) Export
	
	QueryText =
		"SELECT ALLOWED
		|	ContactInformation.Presentation
		|FROM
		|	Catalog." + Ref.Metadata().Name + ".ContactInformation AS ContactInformation
		|WHERE
		|	ContactInformation.Ref = &Ref
		|	And ContactInformation.Kind = &Kind";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Kind", ContactInformationKind);
	
	Selection = Query.Execute().Choose();
	If Selection.Next() Then
		Return Selection.Presentation;
	Else
		Return "";
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Object module and form event handlers. 

// OnCreateAtServer form event handler.
//
Procedure OnCreateAtServer(Form, Object, ItemForPlacementName) Export
	
	AttributeArray = New Array;
	
	// Creating a value table
	DescriptionName = "ContactInformationAdditionalAttributeInfo";
	AttributeArray.Add(New FormAttribute(DescriptionName, New TypeDescription("ValueTable")));
	AttributeArray.Add(New FormAttribute("AttributeName", New TypeDescription("String"), DescriptionName));
	AttributeArray.Add(New FormAttribute("FieldValues", New TypeDescription("ValueList"), DescriptionName));
	AttributeArray.Add(New FormAttribute("HomeCountryOnly", New TypeDescription("Boolean"), DescriptionName));
	AttributeArray.Add(New FormAttribute("Type", New TypeDescription("EnumRef.ContactInformationTypes"), DescriptionName));
	AttributeArray.Add(New FormAttribute("Kind", New TypeDescription("CatalogRef.ContactInformationKinds"), DescriptionName));
	AttributeArray.Add(New FormAttribute("TypeNumber", New TypeDescription("Number"), DescriptionName));

	
	// Retrieving a list of contact information kinds
	CatalogName = Object.Ref.Metadata().Name;
	CIKindsGroup = Catalogs.ContactInformationKinds["Catalog" + CatalogName];
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ContactInformationKinds.Ref AS Kind,
	|	ContactInformationKinds.Description,
	|	ContactInformationKinds.Type,
	|	ContactInformationKinds.EditInDialogOnly,
	|	ContactInformationKinds.HomeCountryAddressOnly,
	|	ContactInformationKinds.DeletionMark AS DeletionMark,
	|	TRUE AS Use
	|FROM
	|	Catalog.ContactInformationKinds AS ContactInformationKinds
	|WHERE
	|	ContactInformationKinds.Parent = &CIKindsGroup
	|
	|ORDER BY
	|	DeletionMark,
	|	ContactInformationKinds.AdditionalOrderingAttribute";
	
	Query.SetParameter("CIKindsGroup", CIKindsGroup);
	SetPrivilegedMode(True);
	ContactInformation = Query.Execute().Unload();
	SetPrivilegedMode(False);
	
	
	// Adding necessary attributes
	If TypeOf(Object.ContactInformation) = Type("ValueTable") Then
		CITable = Object.ContactInformation;
	Else
		CITable = Object.ContactInformation.Unload();
	EndIf;
	
	Number = 0;
	CIKindAndAttributeNameMap = New Map;
	For Each CIRow In ContactInformation Do
		
		RowInTable = CITable.Find(CIRow.Kind, "Kind");
		If RowInTable = Undefined And CIRow.DeletionMark Then
			CIRow.Use = False;
			Continue;
		EndIf;
		
		Number = Number + 1;
		AttributeName = "ContactInformationField" + Number;
		AttributeArray.Add(New FormAttribute(AttributeName, New TypeDescription("String"), , CIRow.Description, True));
		
		CIKindAndAttributeNameMap.Insert(CIRow.Kind, AttributeName);
		
	EndDo;
	
	// Adding new attributes
	Form.ChangeAttributes(AttributeArray);
	
	// Creating form items and filling attribute values
	Parent = ?(IsBlankString(ItemForPlacementName), Form, Form.Items[ItemForPlacementName]);
	For Each CIRow In ContactInformation Do
		
		If Not CIRow.Use Then
			Continue;
		EndIf;
		
		Kind = CIRow.Kind;
		AttributeName = CIKindAndAttributeNameMap.Get(Kind);
		Item = Form.Items.Add(AttributeName, Type("FormField"), Parent);
		Item.Type = FormFieldType.InputField;
		Item.DataPath = AttributeName;
		Item.TitleLocation = FormItemTitleLocation.Top;
		
		If CIRow.Type = Enums.ContactInformationTypes.Other Then
			Item.Height = 5;
			Item.MultiLine = True;
		EndIf;
		
		If CanEditContactInformationTypeInDialog(CIRow.Type) Then
			Item.ChoiceButton = True;
			If CIRow.EditInDialogOnly Then
				Item.TextEdit = False;
				Item.BackColor = WebColors.Cream;
			EndIf;
			Item.SetAction("StartChoice", "Attachable_ContactInformationStartChoice");
			Item.SetAction("OnChange", "Attachable_ContactInformationOnChange");
		EndIf;
		
		
		NewRow = Form.ContactInformationAdditionalAttributeInfo.Add();
		NewRow.AttributeName = AttributeName;
		NewRow.HomeCountryOnly = CIRow.HomeCountryAddressOnly;
		NewRow.Kind = Kind;
		NewRow.Type = CIRow.Type;
		NewRow.TypeNumber = GetNumberByContactInformationType(CIRow.Type);
		
		RowInTable = CITable.Find(CIRow.Kind, "Kind");
		If RowInTable <> Undefined Then
			
			Form[AttributeName] = RowInTable.Presentation;
			NewRow.FieldValues = ConvertStringToFieldList(RowInTable.FieldValues);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// BeforeWriteAtServer form event handler.
//
Procedure BeforeWriteAtServer(Form, CurrentObject, Cancel = False) Export
	
	CurrentObject.ContactInformation.Clear();
	
	For Each TableRow In Form.ContactInformationAdditionalAttributeInfo Do
		
		Presentation = Form[TableRow.AttributeName];
		If IsBlankString(Presentation) Then
			Continue;
		EndIf;
		
		NewRow = CurrentObject.ContactInformation.Add();
		NewRow.Type = TableRow.Type;
		NewRow.Kind = TableRow.Kind;
		NewRow.Presentation = Presentation;
		
		If TableRow.FieldValues.Count() > 0 Then
			NewRow.FieldValues = ConvertFieldListToString(TableRow.FieldValues);
		EndIf;
		
		// Filling values of additional tabular section attributes
		If TableRow.Type = Enums.ContactInformationTypes.EmailAddress Then
			// Email
			ErrorMessage = "";
			FillTabularSectionAttributesForEmailAddress(NewRow, ErrorMessage);
			If Not IsBlankString(ErrorMessage) Then
				CommonUseClientServer.MessageToUser(ErrorMessage, , TableRow.AttributeName);
				Cancel = True;
			EndIf;
		ElsIf TableRow.Type = Enums.ContactInformationTypes.Address Then
			// Address
			FillTabularSectionAttributesForAddress(NewRow, TableRow.FieldValues);
		ElsIf TableRow.Type = Enums.ContactInformationTypes.Phone Or TableRow.Type = Enums.ContactInformationTypes.Fax Then
			// Phone/fax
			FillTabularSectionAttributesForPhone(NewRow, TableRow.FieldValues);
		ElsIf TableRow.Type = Enums.ContactInformationTypes.WebPage Then
			// Web page
			FillTabularSectionAttributesForWebPage(NewRow);
		EndIf;
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for filling additional attributes of the Contact information tabular section.

// Fills additional attributes of the Contact information tabular section for an address.
//
// Parameters:
// TabularSectionRow - tabular section row - Contact information tabular section row.
// FieldValues - value list - value list of fields.
//
Procedure FillTabularSectionAttributesForAddress(TabularSectionRow, FieldValues)
	
	For Each FieldValue In FieldValues Do
		If Upper(FieldValue.Presentation) = "COUNTRY" Then
			TabularSectionRow.Country = FieldValue.Value;
		ElsIf Upper(FieldValue.Presentation) = "STATE" Then
			TabularSectionRow.State= FieldValue.Value;
		ElsIf Upper(FieldValue.Presentation) = "CITY" Then
			TabularSectionRow.City = FieldValue.Value;
		EndIf;
	EndDo;
	
EndProcedure

// Fills additional attributes of the Contact information tabular section for an email address.
//
// Parameters:
// TabularSectionRow - tabular section row - Contact information tabular section row.
// ErrorMessage - String - error message.
//
Procedure FillTabularSectionAttributesForEmailAddress(TabularSectionRow, ErrorMessage = "")
	
	Try
		Result = CommonUseClientServer.SplitStringWithEmailAddresses(TabularSectionRow.Presentation);
	Except
		ErrorMessage = BriefErrorDescription(ErrorInfo());
		Return;
	EndTry;
	
	If Result.Count() > 0 Then
		TabularSectionRow.EmailAddress = Result[0].Address;
		
		Pos = Find(TabularSectionRow.EmailAddress, "@");
		If Pos <> 0 Then
			TabularSectionRow.ServerDomainName = Mid(TabularSectionRow.EmailAddress, Pos+1);
		EndIf;
	EndIf;
	
EndProcedure

// Fills additional attributes of the Contact information tabular section for phone and fax numbers.
//
// Parameters:
// TabularSectionRow - tabular section row - Contact information tabular section row.
// FieldValues - value list - value list of fields.
//
Procedure FillTabularSectionAttributesForPhone(TabularSectionRow, FieldValues)
	
	CountryCode = "";
	AreaCode = "";
	PhoneNumber = "";
	
	For Each FieldValue In FieldValues Do
		If Upper(FieldValue.Presentation) = "COUNTRYCODE" Then
			CountryCode = FieldValue.Value;
		ElsIf Upper(FieldValue.Presentation) = "AREACODE" Then
			AreaCode = FieldValue.Value;
		ElsIf Upper(FieldValue.Presentation) = "PHONENUMBER" Then
			PhoneNumber = FieldValue.Value;
		EndIf;
	EndDo;
	
	If Left(CountryCode, 1) = "+" Then
		CountryCode = Mid(CountryCode, 2);
	EndIf;
	
	Pos = Find(PhoneNumber, ",");
	If Pos <> 0 Then
		PhoneNumber = Left(PhoneNumber, Pos-1);
	EndIf;
	
	Pos = Find(PhoneNumber, Chars.LF);
	If Pos <> 0 Then
		PhoneNumber = Left(PhoneNumber, Pos-1);
	EndIf;
	
	TabularSectionRow.PhoneNumberWithoutCodes = RemoveSeparatorsFromPhoneNumber(PhoneNumber);
	TabularSectionRow.PhoneNumber = RemoveSeparatorsFromPhoneNumber(CountryCode + AreaCode + PhoneNumber);
		
EndProcedure

// Removes separators from the phone number.
//
// Parameters:
// PhoneNumber - String - phone or fax number.
//
// Returns:
// String - phone or fax number without separators.
//
Function RemoveSeparatorsFromPhoneNumber(Val PhoneNumber)
	
	Pos = Find(PhoneNumber, ",");
	If Pos <> 0 Then
		PhoneNumber = Left(PhoneNumber, Pos-1);
	EndIf;
	
	PhoneNumber = StrReplace(PhoneNumber, "-", "");
	PhoneNumber = StrReplace(PhoneNumber, "", "");
	PhoneNumber = StrReplace(PhoneNumber, "+", "");
	PhoneNumber = StrReplace(PhoneNumber, "(", "");
	PhoneNumber = StrReplace(PhoneNumber, ")", "");

	Return PhoneNumber;

EndFunction

// Fills additional attributes of the Contact information tabular section for a web page.
//
// Parameters:
// TabularSectionRow - tabular section row - Contact information tabular section row.
//
Procedure FillTabularSectionAttributesForWebPage(TabularSectionRow)

	WebPageURL = TabularSectionRow.Presentation;

	// Cutting the protocol name
	CharacterPosition = Find(WebPageURL, "://");
	If CharacterPosition <> 0 Then
		LeftPart = Lower(Left(WebPageURL, CharacterPosition - 1));
		If (LeftPart = "http") Or (LeftPart = "https") Then
			WebPageURL = Mid(WebPageURL, CharacterPosition + 3);
		EndIf;
	EndIf;

	// Cutting "www" from the left
	If Lower(Left(WebPageURL, 4)) = "www." Then
		WebPageURL = Mid(WebPageURL, 5);
	EndIf;
	
	CharPosition = Find(WebPageURL, "");
	TabularSectionRow.ServerDomainName = ?(CharPosition = 0, WebPageURL, Left(WebPageURL, CharPosition - 1));
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Determines by type whether contact information can be edited in a dialog.
//
// Parameters:
// Type - EnumRef.ContactInformationTypes - contact information type.
//
// Returns:
// Boolean - flag that shows whether contact information can be edited in a dialog.
//
Function CanEditContactInformationTypeInDialog(Type)
	
	If Type = Enums.ContactInformationTypes.Address Then
		Return True;
	ElsIf Type = Enums.ContactInformationTypes.Phone Then
		Return True;
	ElsIf Type = Enums.ContactInformationTypes.Fax Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

// Returns a number by contact information type.
//
// Parameters:
// Type - EnumRef.ContactInformationTypes - contact information type.
//
// Returns:
// Number - digital code of the contact information type:
// 		1 - address;
// 		2 - phone or fax;
// 		0 - all other types.
//
Function GetNumberByContactInformationType(Type)
	
	If Type = Enums.ContactInformationTypes.Address Then
		Return 1;
	ElsIf Type = Enums.ContactInformationTypes.Phone Or Type = Enums.ContactInformationTypes.Fax Then
		Return 2;
	Else
		Return 0;
	EndIf;
	
EndFunction

// Converts the field map to a string.
//
// Parameters:
// FieldMap - Map - field map.
// Return - String - map that was converted to a string.
//
Function ConvertFieldListToString(FieldMap) Export
	
	Result = "";
	For Each Item In FieldMap Do
		
		Value = Item.Value;
		If IsBlankString(Value) Then
			Continue;
		EndIf;
		
		Result = Result + ?(Result = "", "", Chars.LF) + 
			Item.Presentation + "=" + StrReplace(Value, Chars.LF, Chars.LF + Chars.Tab);
		
	EndDo;
	
	Return Result;
	
EndFunction

// Converts a string of fields to a value list.
//
// Parameters:
// FieldRow - String - string of fields.
//
// Returns:
// Value list - value list of fields.
//
Function ConvertStringToFieldList(FieldString) Export
	
	Result = New ValueList;
	LastItem = Undefined;
	
	For Iteration = 1 to StrLineCount(FieldString) Do
		ReceivedString = StrGetLine(FieldString, Iteration);
		If Left(ReceivedString, 1) = Chars.Tab Then
			If LastItem <> Undefined Then
				LastItem.Value = LastItem.Value + Chars.LF + Mid(ReceivedString, 2);
			EndIf;
		Else
			CharPosition = Find(ReceivedString, "=");
			If CharPosition <> 0 Then
				LastItem = Result.Add(Mid(ReceivedString, CharPosition + 1), Left(ReceivedString, CharPosition - 1));
			EndIf;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

// Deletes WorldCountries catalog items.
//
Procedure DeleteWorldCountriesCatalogItems() Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	WorldCountries.Ref
	|FROM
	|	Catalog.WorldCountries AS WorldCountries
	|WHERE
	|	WorldCountries.Predefined = FALSE";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Choose();
		While Selection.Next() Do
			
			Deletion = New ObjectDeletion(Selection.Ref);
			Deletion.DataExchange.Load = True;
			Deletion.Write();
			
		EndDo;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for the infobase update.

// Adds update handlers required by this subsystem to the Handlers list. 
// 
// Parameters:
// Handlers - ValueTable - see the InfoBaseUpdate.NewUpdateHandlerTable function for details. 
//
Procedure RegisterUpdateHandlers(Handlers) Export
	
	Processor = Handlers.Add();
	Processor.Version = "1.0.1.1";
	Processor.Procedure = "ContactInformationManagementOverridable.ContactInformationInfoBaseUpdate";
	
	Processor = Handlers.Add();
	Processor.Version = "1.2.1.2";
	Processor.Procedure = "ContactInformationManagement.ImportWorldCountries";
	
EndProcedure	

// Updates one kind of contact information.
//
// Parameters:
// CIKind - Catalog.ContactInformationKinds - contact information kind.
// Type - Enumeration.ContactInformationTypes - contact information type.
// CanChangeEditMode - Boolean - flag that shows whether the edit mode can be changed in
// the enterprise mode.
// For example, editing addresses that are used in tax reports must be prohibited.
// EditInDialogOnly - Boolean - flag that shows whether the contact information kind
// will be edited in the input form only.
// HomeCountryAddressOnly - Boolean - flag that shows whether only a home country address 
// (in this configuration it is an address in the United States) can be entered.
// Order - Undefined or Number - defines the order of item on the form.
// 
Procedure UpdateCIKind(CIKind, Type, CanChangeEditMode, EditInDialogOnly, HomeCountryAddressOnly,
						Order = Undefined) Export

	Object = CIKind.GetObject();
	LockDataForEdit(Object.Ref);
	Object.Type = Type;
	Object.CanChangeEditMode = CanChangeEditMode;
	Object.EditInDialogOnly = EditInDialogOnly;
	Object.HomeCountryAddressOnly = HomeCountryAddressOnly;
	If Order <> Undefined Then
		Object.AdditionalOrderingAttribute = Order;
	EndIf;
	
	Object.Write();

EndProcedure

// Updates the World countries catalog according to data of the Catalogs.WorldCountries.Templates.Classifier template.
// Existed items are compared by Code field.
//
Procedure ImportWorldCountries() Export
	
	If CommonUseCached.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	// Retrieving list of countries that are already existed in the infobase.
	Query = New Query;
	Query.Text =
	"SELECT
	|	WorldCountries.Code AS Code,
	|	WorldCountries.Ref AS Ref
	|FROM
	|	Catalog.WorldCountries AS WorldCountries
	|
	|	ORDER BY Code";
	
	QueryResult = Query.Execute().Unload();
	
	Template 				= Catalogs.WorldCountries.GetTemplate("Classifier");
	CountryTable 		= CommonUse.ReadXMLToTable(Template.GetText()).Data;
	ItemStructure 	= New Structure;
	
	For Each CurrentCountry In CountryTable Do
		FoundItem = QueryResult.Find(CurrentCountry.Code, "Code");
		
		If FoundItem = Undefined Then
			Item 					= Catalogs.WorldCountries.CreateItem();
			Item.Code				= CurrentCountry.Code;
			Item.Description		= CurrentCountry.ShortName;
			Item.AlphaCode2			= CurrentCountry.Alpha2;
			Item.AlphaCode3			= CurrentCountry.Alpha3;
			Item.LongDescription 	= CurrentCountry.FullName;
			Item.Write();

			Continue;
			
		EndIf;
		
		Item 			= FoundItem.Ref;
		Fields 				= "";
		If Item.Code <> CurrentCountry.Code Then 
			ItemStructure.Insert("Code", CurrentCountry.Code);
			Fields = Fields + "%Field%,"; 
			Fields = StrReplace(Fields, "%Field%", "Code");
		EndIf;
		If Item.Description <> CurrentCountry.ShortName Then 
			ItemStructure.Insert("Description", CurrentCountry.ShortName);
			Fields = Fields + "%Field%,";
			Fields = StrReplace(Fields, "%Field%", "Description");
		EndIf;
		If Item.AlphaCode2 <> CurrentCountry.Alpha2 Then 
			ItemStructure.Insert("AlphaCode2", CurrentCountry.Alpha2);
			Fields = Fields + "%Field%,";
			Fields = StrReplace(Fields, "%Field%", "AlphaCode2");
		EndIf;
		If Item.AlphaCode3 <> CurrentCountry.Alpha3 Then 
			ItemStructure.Insert("AlphaCode3", CurrentCountry.Alpha3);
			Fields = Fields + "%Field%,";
			Fields = StrReplace(Fields, "%Field%", "AlphaCode3");
		EndIf;
		If Item.LongDescription <> CurrentCountry.FullName Then 
			ItemStructure.Insert("LongDescription", CurrentCountry.FullName);
			Fields = Fields + "%Field%,";
			Fields = StrReplace(Fields, "%Field%", "LongDescription");
		EndIf;
		
		If ItemStructure.Count() > 0 Then 
			StringLength 	= StrLen(Fields);
			Fields 			= Left(Fields, StringLength - 1);
			CountryObject 	= Item.GetObject();
			FillPropertyValues(CountryObject, ItemStructure, Fields);
			CountryObject.Write();
		EndIf;	
		
		ItemStructure.Clear();
		
	EndDo;
	
EndProcedure

// Retrieves a values of the specified contact information type of the object.
//
// Parameters:
// Ref - AnyRef - reference to the contact information owner object (such a company, a counterparty, a partner, and so on).
// ContactInformationType - EnumRef.ContactInformationTypes
//
// Returns:
// ValueTable - value table with the following fields: 
// Value - String - string presentation of a value.
// Kind - String - presentation of the contact information type.
// 
Function ObjectContactInformationValues(Ref, ContactInformationType) Export
	
	Query = New Query(
		"SELECT ALLOWED
		|	ContactInformation.Presentation AS Value,
		|	ContactInformation.Kind.Presentation AS Kind
		|FROM
		|	Catalog." + Ref.Metadata().Name + ".ContactInformation AS ContactInformation
		|WHERE
		|	ContactInformation.Ref = &Ref
		|	And ContactInformation.Type = &Type
		|");
	
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Type", ContactInformationType);
	
	Return Query.Execute().Unload();
	
EndFunction

// Retrieves an address field value.
//
// Parameters:
// FieldValueString - string that contains address field values.
// FieldName - field name. For example: "City".
//
// Returns:
// String - address field value.
//
Function GetAddressFieldValue(FieldValueString, FieldName) Export
	
	FieldPosition = Find(FieldValueString, FieldName);
	Value = "";
	If FieldPosition <> 0 Then
		FieldValues = Right(FieldValueString, StrLen(FieldValueString) - FieldPosition - StrLen(FieldName));
		LFPosition = Find(FieldValues, Chars.LF);
		Value = Mid(FieldValues, 0 ,LFPosition - 1);
	EndIf;
	Return Value;

EndFunction

// Retrieves a contact information value.
//
// Parameters:
// FieldValueString - string that contains address field values.
// FieldName - field name. For example: "City".
//
// Returns:
// String - contact information value.
//
Function GetContactInformationValue(FieldValueString, FieldName) Export
	
	FieldPosition = Find(FieldValueString, FieldName);
	Value = "";
	If FieldPosition <> 0 Then
		FieldValues = Right(FieldValueString, StrLen(FieldValueString) - FieldPosition - StrLen(FieldName));
		LFPosition = Find(FieldValues, Chars.LF);
		Value = Mid(FieldValues, 0 , LFPosition - 1);
	EndIf;
	
	Return Value;

EndFunction