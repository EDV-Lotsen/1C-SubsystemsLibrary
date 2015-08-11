////////////////////////////////////////////////////////////////////////////////
// Contact information subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// The handler of the OnChange event of the contact information table Presentation column.
Procedure PresentationOnChange(Form, Item) Export
	
	RowData = GetAdditionalValueString(Form, Item);
	If (RowData <> Undefined) And (RowData.TypeNumber = 2) Then
		Value = Item.EditText;
		FillPhoneRecordFieldsByPresentation(Value, RowData.FieldValues);
	EndIf;
	If (RowData <> Undefined) And (RowData.TypeNumber = 1) And Item.EditText = "" Then
		RowData.FieldValues.Clear()
	EndIf;	
	
EndProcedure

// The handler of the StartChoice event of the contact information table Presentation column.
Procedure PresentationStartChoice(Form, Item, Modified, StandardProcessing) Export
	
	StandardProcessing = False;
	
	RowData = GetAdditionalValueString(Form, Item);
	If (RowData = Undefined) And (RowData.TypeNumber = 0) Then
		Return;
	EndIf;
	
	If RowData.TypeNumber = 1 Then
		EditFormName = "CommonForm.AddressInput";
	Else
		EditFormName = "CommonForm.PhoneInput";
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("FieldValues", RowData.FieldValues);
	FormParameters.Insert("Kind", RowData.Kind);
	FormParameters.Insert("MadeChanges", False);
	FormParameters.Insert("Presentation", Item.EditText);
	FormParameters.Insert("EditInDialogOnly", Not Item.TextEdit);
	FormParameters.Insert("HomeCountryAddressOnly", RowData.HomeCountryOnly);
	
	FunctionParameters = New Structure;
	FunctionParameters.Insert("Item", Item);
	FunctionParameters.Insert("Form", Form);
	FunctionParameters.Insert("RowData", RowData);
	OpenForm(EditFormName, FormParameters, , , , , New NotifyDescription("PresentationStartChoiceSave", ThisObject, FunctionParameters));
	
EndProcedure

// The PresentationStartChoice continuation
Procedure PresentationStartChoiceSave(Result, AdditionalParameters)
	If TypeOf(Result) = Type("Structure") Then
		AdditionalParameters.Form[AdditionalParameters.Item.Name] = Result.Presentation;
		AdditionalParameters.RowData.FieldValues = Result.FieldValues;
		Modified = True;
	EndIf;	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Returns a string of additional values by attribute name.
//
// Parameters:
// Form - Form - passed form;
// Item - FormDataStructureAndCollection - form data.
//
// Returns:
// Undefined or CollectionRow - collection row.
//
Function GetAdditionalValueString(Form, Item)
	
	Filter = New Structure("AttributeName", Item.Name);
	Rows = Form.ContactInformationAdditionalAttributesInfo.FindRows(Filter);
	
	Return ?(Rows.Count() = 0, Undefined, Rows[0]);
	
EndFunction

// Fills phone record fields by Presentation field.
//
// Parameters:
// Presentation - String - phone presentation;
// FieldList - FormDataCollection - list of fields to be filled.
//
Procedure FillPhoneRecordFieldsByPresentation(Presentation, FieldList)
	
	Raise("CHECK ON TEST");

	PhoneString = TrimAll(Presentation);
	FieldList.Clear();
	CountryCode = "";
	CityCode = "";
	PhoneNumber = "";
	Extension = "";
	Comment = "";
	
	// Filling an extension number and a comment
	PositionExtension = Find(Upper(PhoneString), "EXT.");
	If PositionExtension <> 0 Then
		ExtensionWithComment = TrimAll(Mid(PhoneString, PositionExtension + 4));
		
		PhoneString = TrimAll(Left(PhoneString, PositionExtension - 1));
		
		If Right(PhoneString, 1) = "," Then
			PhoneString = Left(PhoneString, StrLen(PhoneString)-1);
		EndIf;
		
		PositionExtension = Find(Upper(ExtensionWithComment), ", ");
		
		If PositionExtension <> 0 Then
			Extension = TrimAll(Left(ExtensionWithComment, PositionExtension - 1));
			Comment = TrimAll(Mid(ExtensionWithComment, PositionExtension + 2));
		Else
			Extension = ExtensionWithComment;
		EndIf;
		
	EndIf;
	
	// Filling a city code
	PositionOpeningBracket = Find(PhoneString, "(");
	If PositionOpeningBracket <> 0 Then
		CountryCode = TrimAll(Left(PhoneString, PositionOpeningBracket - 1));
		
		PhoneString = TrimAll(Mid(PhoneString, PositionOpeningBracket + 1));
		PositionClosingBracket = Find(PhoneString, ")");
		
		If PositionClosingBracket <> 0 Then
			CityCode = TrimAll(Left(PhoneString, PositionClosingBracket - 1));
			PhoneString = TrimAll(Mid(PhoneString, PositionClosingBracket + 1));
		EndIf;
	EndIf;
	
	CommaPosition = Find(PhoneString, ", ");
	// If there is no extension number, finding a phone number and a comment by comma position.
	If PositionExtension = 0 And CommaPosition <> 0 Then
		// Filling a comment
		PhoneNumber = TrimAll(Left(PhoneString, CommaPosition - 1));
		Comment = TrimAll(Mid(PhoneString, CommaPosition + 2));
	Else
		// All remained characters are the phone number
		PhoneNumber = PhoneString;
	EndIf;
	
	// Correcting the presentation
	Presentation = GeneratePhonePresentation(CountryCode, CityCode, PhoneNumber, Extension, Comment);
	FieldList.Add(CountryCode, "CountryCode");
	FieldList.Add(CityCode, "CityCode");
	FieldList.Add(PhoneNumber, "PhoneNumber");
	FieldList.Add(Extension, "Extension");
	FieldList.Add(Comment, "Comment");
	
EndProcedure

// Generating phone string presentation.
//
// Parameters:
// CountryCode - String - country code;
// CityCode - String - city code;
// PhoneNumber - String - phone number;
// Extension - String - extension number;
// Comment - String - comment.
//
// Returns:
// String - phone presentation.
//
Function GeneratePhonePresentation(CountryCode, CityCode, PhoneNumber, Extension, Comment) Export

	Raise("CHECK ON TEST");
	
	Presentation = TrimAll(CountryCode);
	
	If Not IsBlankString(CityCode) Then
		Presentation = Presentation + ?(IsBlankString(Presentation), "", " ") + "(" + TrimAll(CityCode) + ")";
	EndIf;
	
	If Not IsBlankString(PhoneNumber) Then
		Presentation = Presentation + ?(IsBlankString(Presentation), "", " ") + TrimAll(PhoneNumber);
	EndIf;
	
	If Not IsBlankString(Extension) Then
		Presentation = Presentation + ?(IsBlankString(Presentation), "", ", ") + "EXT. " + TrimAll(Extension);
	EndIf;
	
	If Not IsBlankString(Comment) Then
		Presentation = Presentation + ?(IsBlankString(Presentation), "", ", ") + TrimAll(Comment);
	EndIf;
	
	Return Presentation;
	
EndFunction