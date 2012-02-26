 

////////////////////////////////////////////////////////////////////////////////
// GETTING CONTACT INFO OF OBJECTS BY OTHER SUBSYSTEMS

// Get value of specific type of object contact information kind
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
// OBJECT FORM AND MODULE EVENT HADLERS

// Handler for form event OnCreateAtServer
Procedure OnCreateAtServer(Form, Object, ItemNameForPlacement) Export
	
	AttributesArray = New Array;
	
	// Create value table
	DetailsName = "__CI_AdditionalDataAndAttributesDescription";
	AttributesArray.Add(New FormAttribute(DetailsName,       New TypeDescription("ValueTable")));
	AttributesArray.Add(New FormAttribute("AttributeName",   New TypeDescription("String"),                                 DetailsName));
	AttributesArray.Add(New FormAttribute("FieldValues",     New TypeDescription("ValueList"),                              DetailsName));
	AttributesArray.Add(New FormAttribute("HomeCountryOnly", New TypeDescription("Boolean"),                                DetailsName));
	AttributesArray.Add(New FormAttribute("Type",            New TypeDescription("EnumRef.ContactInformationTypes"),    DetailsName));
	AttributesArray.Add(New FormAttribute("Kind",            New TypeDescription("CatalogRef.ContactInformationKinds"),     DetailsName));
	AttributesArray.Add(New FormAttribute("TypeNumber",      New TypeDescription("Number"),                                 DetailsName));

	
	// Get list of CI kinds
	CatalogName = Object.Ref.Metadata().Name;
	CIKindsGroup = Catalogs.ContactInformationKinds["Catalog" + CatalogName];
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ContactInformationKinds.Ref AS Kind,
	|	ContactInformationKinds.Description,
	|	ContactInformationKinds.Type,
	|	ContactInformationKinds.EditInDialogOnly,
	|	ContactInformationKinds.AlwaysUseAddressClassifier,
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
	
	
	// Add required attributes
	If TypeOf(Object.ContactInformation) = Type("ValueTable") Then
		ValTable = Object.ContactInformation;
	Else
		ValTable = Object.ContactInformation.Unload();
	EndIf;
	
	Number 		 = 0;
	KindNamesMap = New Map;
	For Each Row In ContactInformation Do
		
		RowInCI = ValTable.Find(Row.Kind, "Kind");
		If RowInCI = Undefined And Row.DeletionMark Then
			Row.Use = False;
			Continue;
		EndIf;
		
		Number = Number + 1;
		AttributeName = "__CI_Field" + Number;
		AttributesArray.Add(New FormAttribute(AttributeName, New TypeDescription("String"), , Row.Description, True));
		
		KindNamesMap.Insert(Row.Kind, AttributeName);
		
	EndDo;
	
	// Add new attributes
	Form.ChangeAttributes(AttributesArray);
	
	// Create items on form and fill attribute values
	Parent = ?(IsBlankString(ItemNameForPlacement), Form, Form.Items[ItemNameForPlacement]);
	For Each Row In ContactInformation Do
		
		If Not Row.Use Then
			Continue;
		EndIf;
		
		Kind 				= Row.Kind;
		AttributeName 		= KindNamesMap.Get(Kind);
		Item 				= Form.Items.Add(AttributeName, Type("FormField"), Parent);
		Item.Type 			= FormFieldType.InputField;
		Item.DataPath 		= AttributeName;
		Item.TitleLocation 	= FormItemTitleLocation.Top;
		
		If Row.Type = Enums.ContactInformationTypes.Another Then
			Item.Height = 5;
			Item.MultiLine = True;
		EndIf;
		
		If ContactInformationTypeEditDialogAvailable(Row.Type) Then
		Item.ChoiceButton = True;
			If Row.EditInDialogOnly Then
				Item.TextEdit = False;
				Item.BackColor = WebColors.Cream;
			EndIf;
			Item.SetAction("StartChoice", "Pluggable_ContactInformationStartChoice");
			Item.SetAction("OnChange", "Pluggable_ContactInformationOnChange");
		EndIf;
		
		
		NewRow 				   = Form.__CI_AdditionalDataAndAttributesDescription.Add();
		NewRow.AttributeName   = AttributeName;
		NewRow.HomeCountryOnly = Row.AlwaysUseAddressClassifier;
		NewRow.Kind            = Kind;
		NewRow.Type            = Row.Type;
		NewRow.TypeNumber      = GetNumberByContactInformationType(Row.Type);
		                           
		RowInCI = ValTable.Find(Row.Kind, "Kind");
		If RowInCI <> Undefined Then
			
			Form[AttributeName]  = RowInCI.Presentation;
			NewRow.FieldValues   = ConvertStringToFieldList(RowInCI.FieldValues);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Handler for form event BeforeWriteAtServer
Procedure BeforeWriteAtServer(Form, CurrentObject, Cancellation = False) Export
	
	CurrentObject.ContactInformation.Clear();
	
	For Each Row In Form.__CI_AdditionalDataAndAttributesDescription Do
		
		Presentation = Form[Row.AttributeName];
		If IsBlankString(Presentation) Then
			Continue;
		EndIf;
		
		NewRow 		= CurrentObject.ContactInformation.Add();
		NewRow.Type = Row.Type;
		NewRow.Kind = Row.Kind;
		NewRow.Presentation = Presentation;
		
		If Row.FieldValues.Count() > 0 Then
			NewRow.FieldValues = ConvertFieldListToString(Row.FieldValues);
		EndIf;
		
		// Fill values of additional attributes of tabular section
		If Row.Type = Enums.ContactInformationTypes.EmaiAddress Then
			// Email
			ErrorMessage = "";
			FillTabularSectionForEmailAddressAttributes(NewRow, ErrorMessage);
			If Not IsBlankString(ErrorMessage) Then
				CommonUseClientServer.MessageToUser(ErrorMessage, , Row.AttributeName);
				Cancellation = True;
			EndIf;
		ElsIf Row.Type = Enums.ContactInformationTypes.Address Then
			// Address
			FillTabularSectionForAddressAttributes(NewRow, Row.FieldValues);
		ElsIf Row.Type = Enums.ContactInformationTypes.Phone Or Row.Type = Enums.ContactInformationTypes.Fax Then
			// Telephone/Fax
			FillTabularSectionForPhoneAttributes(NewRow, Row.FieldValues);
		ElsIf Row.Type = Enums.ContactInformationTypes.WebPage Then
			// WWW
			FillTabularSectionForWebpageAttributes(NewRow);
		EndIf;
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// ADDITIONAL ATTRIBUTES OF CONTACT INFORMATION TABULAR SECTION

// For address
Procedure FillTabularSectionForAddressAttributes(TabularSectionRow, FieldValues)
	
	For Each FieldValue In FieldValues Do
		If Upper(FieldValue.Presentation) = "COUNTRY" Then
			TabularSectionRow.Country = FieldValue.Value;
		ElsIf Upper(FieldValue.Presentation) = "REGION" Then
			TabularSectionRow.State = FieldValue.Value;
		ElsIf Upper(FieldValue.Presentation) = "CITY" Then
			TabularSectionRow.City = FieldValue.Value;
		EndIf;
	EndDo;
	
EndProcedure

// For e-mail
Procedure FillTabularSectionForEmailAddressAttributes(TabularSectionRow, ErrorMessage = "")
	
	Try
		Result = CommonUseClientServer.ParseEmailString(TabularSectionRow.Presentation);
	Except
		ErrorMessage = BriefErrorDescription(ErrorInfo());
		Return;
	EndTry;
	
	If Result.Count() > 0 Then
		TabularSectionRow.Email = Result[0].Address;
		
		Pos = Find(TabularSectionRow.Email, "@");
		If Pos <> 0 Then
			TabularSectionRow.ServerDomainName = Mid(TabularSectionRow.Email, Pos+1);
		EndIf;
	EndIf;
	
EndProcedure

// For phone and fax
Procedure FillTabularSectionForPhoneAttributes(TabularSectionRow, FieldValues)
	
	CountryCode = "";
	CityCode 	= "";
	PhoneNumber = "";
	
	For Each FieldValue In FieldValues Do
		If Upper(FieldValue.Presentation) = "COUNTRYCODE" Then
			CountryCode = FieldValue.Value;
		ElsIf Upper(FieldValue.Presentation) = "CITYCODE" Then
			CityCode = FieldValue.Value;
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
	
	TabularSectionRow.PhoneNumberNoCodes  = RemoveSeparatorsFromPhoneNumber(PhoneNumber);
	TabularSectionRow.PhoneNumber         = RemoveSeparatorsFromPhoneNumber(CountryCode + CityCode + PhoneNumber);
		
EndProcedure

Function RemoveSeparatorsFromPhoneNumber(Val StrNumber)
	
	Pos = Find(StrNumber, ",");
	If Pos <> 0 Then
		StrNumber = Left(StrNumber, Pos-1);
	EndIf;
	
	StrNumber = StrReplace(StrNumber, "-", "");
	StrNumber = StrReplace(StrNumber, " ", "");
	StrNumber = StrReplace(StrNumber, "+", "");

	Return StrNumber;

EndFunction

// For web page
Procedure FillTabularSectionForWebpageAttributes(TabularSectionRow)

	Row = TabularSectionRow.Presentation;

	// Cut protocol name
	Pos = Find(Row, "://");
	If Pos <> 0 Then
		LeftPart = Lower(Left(Row, Pos-1));
		If (LeftPart = "http") OR (LeftPart = "https") Then
			Row = Mid(Row, Pos + 3);
		EndIf;
	EndIf;

	// Cut www on the left
	If Lower(Left(Row, 4)) = "www." Then
		Row = Mid(Row, 5);
	EndIf;
	
	Pos = Find(Row, "/");
	TabularSectionRow.ServerDomainName = ?(Pos = 0, Row, Left(Row, Pos-1));
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SERVICE

// Check by contact information type, if edit in dialog is available
Function ContactInformationTypeEditDialogAvailable(Type)
	
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

// Get number by contact information type.
//
// Number is used for determing edit method of contact
// information kind:
// 1 - Address
// 2 - Phone or fax
// 0 - All other types
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

// Convert list of fields to a string
Function ConvertFieldListToString(FieldsMap)
	
	Result = "";
	For Each Item In FieldsMap Do
		
		Value = Item.Value;
		If IsBlankString(Value) Then
			Continue;
		EndIf;
		
		Result = Result + ?(Result = "", "", Chars.LF) + 
			Item.Presentation + "=" + StrReplace(Value, Chars.LF, Chars.LF + Chars.Tab);
		
	EndDo;
	
	Return Result;
	
EndFunction

// Convert string of fields to a value list
Function ConvertStringToFieldList(FieldRow)
	
	Result   = New ValueList;
	LastItem = Undefined;
	
	For I = 1 To StrLineCount(FieldRow) Do
		Row = StrGetLine(FieldRow, I);
		If Left(Row, 1) = Chars.Tab Then
			If LastItem <> Undefined Then
				LastItem.Value = LastItem.Value + Chars.LF + Mid(Row, 2);
			EndIf;
		Else
			Pos = Find(Row, "=");
			If Pos <> 0 Then
				LastItem = Result.Add(Mid(Row, Pos+1), Left(Row, Pos-1));
			EndIf;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction


////////////////////////////////////////////////////////////////////////////////
// INFOBASE UPDATE

// Update one kind of contact information
Procedure RefreshContactInformationKind(ContactInformationKind, Type, EditMethodEditable, EditInDialogOnly, AlwaysUseAddressClassifier) Export

	Object 							  = ContactInformationKind.GetObject();
	LockDataForEdit(Object.Ref);     
	Object.Type                       = Type;
	Object.EditMethodEditable 		  = EditMethodEditable;
	Object.EditInDialogOnly      	  = EditInDialogOnly;
	Object.AlwaysUseAddressClassifier = AlwaysUseAddressClassifier;
	Object.Write();

EndProcedure

// Load catalog of world countries
Procedure LoadWorldCountries() Export
	
	// Get list of already loaded countries
	Query = New Query;
	Query.Text =
	"SELECT
	|	WorldCountries.Code AS Code
	|FROM
	|	Catalog.WorldCountries AS WorldCountries
	|
	|ORDER BY
	|	Code";
	
	TabCodes = Query.Execute().Unload();
	
	Template = Catalogs.WorldCountries.GetTemplate("Classifier");
	ValTable = CommonUse.ReadXMLToTable(Template.GetText()).Data;
	
	For Each Row In ValTable Do
		If TabCodes.Find(Row.Code, "Code") <> Undefined Then
			Continue;
		EndIf;
		
		Item 				 = Catalogs.WorldCountries.CreateItem();
		Item.Code			 = Row.Code;
		Item.Description	 = Row.ShortName;
		Item.Alpha2Code		 = Row.Alpha2;
		Item.Alpha3Code		 = Row.Alpha3;
		Item.Details = Row.FullName;
		Item.Write();
		
	EndDo;
	
EndProcedure
