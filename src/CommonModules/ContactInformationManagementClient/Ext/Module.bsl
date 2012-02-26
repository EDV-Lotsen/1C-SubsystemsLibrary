

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS RELATED TO CONTACT INFORMATION TABLE ON FORMS

// Event OnChange in column Presentation of contact information table
Procedure PresentationOnChange(Form, Item) Export
	
	StrData = GetAdditionalValuesString(Form, Item);
	If (StrData <> Undefined) And (StrData.TypeNumber = 2) Then
		Value = Item.EditText;
		FillRecordFieldsByPhonePresentation(Value, StrData.FieldValues);
	EndIf;
	
EndProcedure

// Event StartChoice in column Presentation of contact information table
Procedure PresentationStartChoice(Form, Item, Modified, StandardProcessing) Export
	
	StandardProcessing = False;
	
	StrData = GetAdditionalValuesString(Form, Item);
	If (StrData = Undefined) And (StrData.TypeNumber = 0) Then
		Return;
	EndIf;
	
	If StrData.TypeNumber = 1 Then
		EditFormName =  "CommonForm.InputAddress";
	Else
		EditFormName =  "CommonForm.InputPhone";
	EndIf;
	
	Parameters = New Structure;
	Parameters.Insert("FieldValues",                StrData.FieldValues);
	Parameters.Insert("Kind",                       StrData.Kind);
	Parameters.Insert("Modified",        	 	    False);
	Parameters.Insert("Presentation",               Item.EditText);
	Parameters.Insert("EditInDialogOnly", 			Not Item.TextEdit);
	Parameters.Insert("AlwaysUseAddressClassifier", StrData.HomeCountryOnly);
	
	Result = OpenFormModal(EditFormName, Parameters);
	
	If TypeOf(Result) = Type("Structure") Then
		Form[Item.Name]   	= Result.Presentation;
		StrData.FieldValues = Result.FieldValues;
		Modified      		= True;
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// SERVICE

Function GetAdditionalValuesString(Form, Item)
	
	Filter = New Structure("AttributeName", Item.Name);
	Rows   = Form.__CI_AdditionalDataAndAttributesDescription.FindRows(Filter);
	
	Return ?(Rows.Count() = 0, Undefined, Rows[0]);
	
EndFunction

// Fill other fields in phone record using Presentation field
Procedure FillRecordFieldsByPhonePresentation(Presentation, FieldList)
	
	CurStr 		= TrimAll(Presentation);
	FieldList.Clear();
	CountryCode = "";
	CityCode    = "";
	PhoneNumber = "";
	Extension   = "";
	Comment   	= "";
	
	// cut extension number with comment
	PosAdd = Find(Upper(CurStr), "EXT.");
	If PosAdd <> 0 Then
		ExtensionWithComment = TrimAll(Mid(CurStr, PosAdd+4));
		
		CurStr = TrimAll(Left(CurStr, PosAdd-1));
		
		If Right(CurStr, 1) = "," Then
			CurStr = Left(CurStr, StrLen(CurStr)-1);
		EndIf;
		
		PosAdd = Find(Upper(ExtensionWithComment), ", ");
		
		If PosAdd <> 0 Then
			Extension = TrimAll(Left(ExtensionWithComment, PosAdd-1));
			Comment = TrimAll(Mid(ExtensionWithComment, PosAdd+2));
		Else
			Extension = ExtensionWithComment;
		EndIf;
		
	EndIf;
	
	// cut city code
	Pos = Find(CurStr, "(");
	If Pos <> 0 Then
		CountryCode = TrimAll(Left(CurStr, Pos-1));
		
		CurStr = TrimAll(Mid(CurStr, Pos+1));
		Pos = Find(CurStr, ")");
		
		If Pos <> 0 Then
			CityCode = TrimAll(Left(CurStr, Pos-1));
			CurStr = TrimAll(Mid(CurStr, Pos+1));
		EndIf;
	EndIf;
	
	Pos = Find(CurStr, ", ");
	// If there is no ext number - then use phone number and comments
	If PosAdd = 0 And Pos <> 0 Then
		// cut comment
		PhoneNumber = TrimAll(Left(CurStr, Pos-1));
		Comment = TrimAll(Mid(CurStr, Pos+2));
	Else
		// the rest is number
		PhoneNumber = CurStr;
	EndIf;
	
	// Adjust presentation
	Presentation = GeneratePhonePresentation(CountryCode, CityCode, PhoneNumber, Extension, Comment);
	FieldList.Add(CountryCode, "CountryCode");
	FieldList.Add(CityCode,    "CityCode");
	FieldList.Add(PhoneNumber, "PhoneNumber");
	FieldList.Add(Extension,   "Extension");
	FieldList.Add(Comment,     "Comment");
	
EndProcedure

// Procedure generates phone string presentation
Function GeneratePhonePresentation(CountryCode, CityCode, PhoneNumber, Extension, Comment) Export
	
	Presentation = TrimAll(CountryCode);
	
	If Not IsBlankString(CityCode) Then
		Presentation = Presentation + ?(IsBlankString(Presentation), "", " ") + "(" + TrimAll(CityCode) + ")";
	EndIf;
	
	If Not IsBlankString(PhoneNumber) Then
		Presentation = Presentation + ?(IsBlankString(Presentation), "", " ") + TrimAll(PhoneNumber);
	EndIf;
	
	If NOT IsBlankString(Extension) Then
		Presentation = Presentation + ?(IsBlankString(Presentation), "", ", ") + "ext. " + TrimAll(Extension);
	EndIf;
	
	If NOT IsBlankString(Comment) Then
		Presentation = Presentation + ?(IsBlankString(Presentation), "", ", ") + TrimAll(Comment);
	EndIf;
	
	Return Presentation;
	
EndFunction
