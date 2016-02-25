////////////////////////////////////////////////////////////////////////////////
// Contact information subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Handler of the OnChange event of a contact information form field.
// It is called from the attachable actions enabled while embedding the Contact information subsystem.
//
// Parameters:
//     Form             - ManagedForm - contact information owner form.
//     Item             - FormField   - form item containing contact information presentation.
//     IsTabularSection - Boolean     - flag specifying that the item is contained in a form table.
//
Procedure PresentationOnChange(Form, Item, IsTabularSection = False) Export
	
	IsTabularSection = IsTabularSection(Item);
	
	If IsTabularSection Then
		FillingData = Form.Items[Form.CurrentItem.Name].CurrentData;
		If FillingData = Undefined Then
			Return;
		EndIf;
	Else
		FillingData = Form;
	EndIf;
	
	// Clearing presentation if clearing is required
	RowData = GetAdditionalValueString(Form, Item, IsTabularSection);
	If RowData = Undefined Then 
		Return;
	EndIf;
	
	Text = Item.EditText;
	If IsBlankString(Text) Then
		FillingData[Item.Name] = "";
		If IsTabularSection Then
			FillingData[Item.Name + "FieldValues"] = "";
		EndIf;
		RowData.Presentation = "";
		RowData.FieldValues = Undefined;
		Return;
	EndIf;
	
	RowData.FieldValues = ContactInformationInternalServerCall.ContactInformationParsingXML(Text, RowData.Kind);
	RowData.Presentation = Text;
	
	If IsTabularSection Then
		FillingData[Item.Name + "FieldValues"] = RowData.FieldValues;
	EndIf;
	
EndProcedure

// Handler of the StartChoice event of a contact information form field.
// It is called from the attachable actions enabled while embedding the Contact information subsystem.
//
// Parameters:
//     Form               - ManagedForm - contact information owner form.
//     Item               - FormField   - form item containing contact information presentation.
//     Modified           - Boolean     - flag specifying that the form was modified.
//     StandardProcessing - Boolean     - flag specifying that standard processing is required for form event.
//
// Returns:
//     Undefined.
//
Function PresentationStartChoice(Form, Item, Modified = True, StandardProcessing = False) Export
	StandardProcessing = False;
	
	Result = New Structure;
	Result.Insert("AttributeName", Item.Name);
	
	IsTabularSection = IsTabularSection(Item);
	
	If IsTabularSection Then
		FillingData = Form.Items[Form.CurrentItem.Name].CurrentData;
		If FillingData = Undefined Then
			Return Undefined;
		EndIf;
	Else
		FillingData = Form;
	EndIf;
	
	RowData = GetAdditionalValueString(Form, Item, IsTabularSection);
	
	// Setting presentation equal to the attribute if the presentation was modified directly in the form field and no longer matches the attribute
	If FillingData[Item.Name] <> Item.EditText Then
		FillingData[Item.Name] = Item.EditText;
		PresentationOnChange(Form, Item, IsTabularSection);
		Form.Modified = True;
	EndIf;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("ContactInformationKind", RowData.Kind);
	OpenParameters.Insert("FieldValues", RowData.FieldValues);
	OpenParameters.Insert("Presentation", Item.EditText);
	
	If Not IsTabularSection Then
		OpenParameters.Insert("Comment", RowData.Comment);
	EndIf;
	
	Notification = New NotifyDescription("PresentationStartChoiceCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("FillingData",  FillingData);
	Notification.AdditionalParameters.Insert("IsTabularSection", IsTabularSection);
	Notification.AdditionalParameters.Insert("RowData",      RowData);
	Notification.AdditionalParameters.Insert("Item",           Item);
	Notification.AdditionalParameters.Insert("Result",         Result);
	Notification.AdditionalParameters.Insert("Form",             Form);
	
	OpenContactInformationForm(OpenParameters, , , , Notification);
	
	Return Undefined;
EndFunction

// Handler of the Clearing event for a contact information form field.
// It is called from the attachable actions enabled while embedding the Contact information subsystem.
//
// Parameters:
//     Form          - ManagedForm - contact information owner form.
//     AttributeName - String      - name of form attribute used for contact information presentation.
//
// Returns:
//     Undefined.
//
Function PresentationClearing(Val Form, Val AttributeName) Export
	
	Result = New Structure("AttributeName", AttributeName);
	FoundRow = Form.ContactInformationAdditionalAttributeInfo.FindRows(Result)[0];
	FoundRow.FieldValues = "";
	FoundRow.Presentation = "";
	FoundRow.Comment   = "";
	
	Form[AttributeName] = "";
	Form.Modified = True;
	
	UpdateFormContactInformation(Form, Result);
	Return Undefined;
EndFunction

// Handler of contact information-related commands (create an email message, open an address, and so on).
// It is called from the attachable actions enabled while embedding the Contact information subsystem.
//
// Parameters:
//     Form        - ManagedForm - contact information owner form.
//     CommandName - String      - name of automatically generated action command.
//
// Returns:
//     Undefined.
//
Function AttachableCommand(Val Form, Val CommandName) Export
	
	If CommandName = "ContactInformationAddInputField" Then
		Notification = New NotifyDescription("ContactInformationAddInputFieldCompletion", ThisObject, New Structure);
			
		Notification.AdditionalParameters.Insert("Form", Form);
		Form.ShowChooseFromMenu(Notification, Form.AddedContactInformationItemList, Form.Items.ContactInformationAddInputField);
		Return Undefined;
		
	ElsIf Left(CommandName, 7) = "Command" Then
		AttributeName = StrReplace(CommandName, "Command", "");
		ContextMenuCommand = False;
		
	Else
		AttributeName = StrReplace(CommandName, "ContextMenu", "");
		ContextMenuCommand = True;
		
	EndIf;
	
	Result = New Structure("AttributeName", AttributeName);
	FoundRow = Form.ContactInformationAdditionalAttributeInfo.FindRows(Result)[0];
	ContactInformationType = FoundRow.Type;
	
	If ContextMenuCommand Then
		EnterComment(Form, AttributeName, FoundRow, Result);
		
	ElsIf ContactInformationType = PredefinedValue("Enum.ContactInformationTypes.Address") Then
		FillAddress(Form, AttributeName, FoundRow, Result);
		
	ElsIf ContactInformationType = PredefinedValue("Enum.ContactInformationTypes.EmailAddress") Then
		EmailAddress = Form.Items[AttributeName].EditText;
		CreateEmailMessage("", EmailAddress, ContactInformationType);
		
	ElsIf ContactInformationType = PredefinedValue("Enum.ContactInformationTypes.WebPage") Then
		ReferenceAddress = Form.Items[AttributeName].EditText;
		GoToWebLink("", ReferenceAddress, ContactInformationType);
		
	EndIf;
	
	Return Undefined;
EndFunction

// Opens the address input form for the contact information form.
// It is called from the attachable actions enabled while embedding the Contact information subsystem.
//
// Parameters:
//     Form   - ManagedForm - contact information owner form.
//     Result - Arbitrary   - data passed by command handler.
//
Procedure OpenAddressInputForm(Form, Result) Export
	
	If Result <> Undefined Then
		
		If Result.Property("AddressFormItem") Then
			PresentationStartChoice(Form, Form.Items[Result.AddressFormItem]);
		EndIf;
		
	EndIf;
	
EndProcedure

// Handler of the refresh operation for the contact information form.
// It is called from the attachable actions enabled while embedding the Contact information subsystem.
//
// Parameters:
//     Form   - ManagedForm - contact information owner form.
//     Result - Arbitrary   - data passed by command handler.
//
Procedure FormRefreshControl(Form, Result) Export
	
	// Address input form callback analysis
	OpenAddressInputForm(Form, Result);
	
EndProcedure

// Handler of the ChoiceProcessing event for world countries. 
// Implements functionality for automated creation of WorldCountries catalog item based on user choice.
//
// Parameters:
//     Item               - FormField - item containing the world country to be edited.
//     SelectedValue      - Arbitrary - selected value.
//     StandardProcessing - Boolean   - flag specifying that standard processing is required for the form event.
//
Procedure WorldCountryChoiceProcessing(Item, SelectedValue, StandardProcessing) Export
	If Not StandardProcessing Then 
		Return;
	EndIf;
	
	SelectedValueType = TypeOf(SelectedValue);
	If SelectedValueType = Type("Array") Then
		TransformationList = New Map;
		For Index = 0 To SelectedValue.UBound() Do
			Data = SelectedValue[Index];
			If TypeOf(Data) = Type("Structure") And Data.Property("Code") Then
				TransformationList.Insert(Index, Data.Code);
			EndIf;
		EndDo;
		
		If TransformationList.Count() > 0 Then
			ContactInformationInternalServerCall.WorldCountryCollectionByClassifier(TransformationList);
			For Each KeyValue In TransformationList Do
				SelectedValue[KeyValue.Key] = KeyValue.Value;
			EndDo;
		EndIf;
		
	ElsIf SelectedValueType = Type("Structure") And SelectedValue.Property("Code") Then
		SelectedValue = ContactInformationInternalServerCall.WorldCountriesByClassifier(SelectedValue.Code);
		
	EndIf;
	
EndProcedure

//  Constructor used to create a structure with contact information form opening parameters.
//
//  Parameters:
//      ContactInformationKind - CatalogRef.ContactInformationKinds - contact information kind to be edited.
//      Value                  - String - serialized value of contact information fields.
//      Presentation           - String - presentation (optional).
//
Function ContactInformationFormParameters(ContactInformationKind, Value, Presentation = Undefined, Comment = Undefined) Export
	Return New Structure("ContactInformationKind, FieldValues, Presentation, Comment",
		ContactInformationKind, Value, Presentation, Comment);
EndFunction

//  Opens a contact information form for editing or viewing.
//
//  Parameters:
//      Parameters   - Arbitrary         - result of ContactInformationFormParameters function.
//      Owner        - Arbitrary         - form parameter.
//      Uniqueness   - Arbitrary         - form parameter.
//      Window       - Arbitrary         - form parameter.
//      Notification - NotifyDescription - used to process form closing.
//
//  Returns: the requested contact information form.
//
Function OpenContactInformationForm(Parameters, Owner = Undefined, Uniqueness = Undefined, Window = Undefined, Notification = Undefined) Export
	InformationKind = Parameters.ContactInformationKind;
	
	NameOfFormToOpen = ContactInformationClientServerCached.ContactInformationInputFormName(InformationKind);
	If NameOfFormToOpen = Undefined Then
		Raise NStr("en = 'Address type cannot be processed: """ + InformationKind + """'");
	EndIf;
	
	If Not Parameters.Property("Title") Then
		Parameters.Insert("Title", String(ContactInformationInternalServerCall.ContactInformationKindType(InformationKind)));
	EndIf;
	
	Parameters.Insert("OpenByScenario", True);
	
	Return OpenForm(NameOfFormToOpen, Parameters, Owner, Uniqueness, Window, , Notification);
EndFunction

// Creates a contact information email.
//
//  Parameters:
//    FieldValues  - String, Structure, Map, Value list - contact information.
//    Presentation - String - presentation. Used if unable to extract presentation 
//                   from FieldValues parameter (Presentation field not available).
//    ExpectedKind - CatalogRef.ContactInformationKinds, EnumRef.ContactInformationTypes, Structure.
//                   Used to determine type if it cannot be extracted from FieldValues parameter.
//
Procedure CreateEmailMessage(Val FieldValues, Val Presentation = "", ExpectedKind = Undefined) Export
	
	ContactInformation = ContactInformationInternalServerCall.TransformContactInformationXML(
		New Structure("FieldValues, Presentation, ContactInformationKind", FieldValues, Presentation, ExpectedKind));
	InformationType = ContactInformation.ContactInformationType;
	
	If InformationType <> PredefinedValue("Enum.ContactInformationTypes.EmailAddress") Then
		Raise StrReplace(NStr("en = 'Cannot create a contact information email for ""%1"" type'"),
			"%1", InformationType);
	EndIf;	
	
	XMLData = ContactInformation.XMLData;
	
	EmailAddress = ContactInformationInternalServerCall.ContactInformationContentString(XMLData);
	If TypeOf(EmailAddress) <> Type("String") Then
		Raise NStr("en = 'Email address retrieval error, invalid contact information type'");
	EndIf;
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.EmailOperations") Then
		EmailOperationsModuleClient = CommonUseClient.CommonModule("EmailOperationsClient");
		
		SendingParameters = New Structure("Recipient", EmailAddress);
		EmailOperationsModuleClient.CreateNewEmailMessage(SendingParameters);
		Return; 
	EndIf;
	
	// No email subsystem, using the platform notification
	Notification = New NotifyDescription("CreateContactInformationEmailCompletion", ThisObject, EmailAddress);
	SuggestionText = NStr("en = 'To be able to send email messages, you need to install the file system extension.'");
	CommonUseClient.CheckFileSystemExtensionAttached(Notification, SuggestionText);
EndProcedure

// Opens a contact information reference.
//
// Parameters:
//    FieldValues  - String, Structure, Map, Value list - contact information.
//    Presentation - String - presentation. Used if unable to extract presentation 
//                   from FieldValues parameter (Presentation field not available).
//    ExpectedKind - CatalogRef.ContactInformationKinds, EnumRef.ContactInformationTypes, Structure.
//                   Used to determine type if it cannot be extracted from FieldValues parameter.
//
Procedure GoToWebLink(Val FieldValues, Val Presentation = "", ExpectedKind = Undefined) Export
	
	ContactInformation = ContactInformationInternalServerCall.TransformContactInformationXML(
		New Structure("FieldValues, Presentation, ContactInformationKind", FieldValues, Presentation, ExpectedKind));
	InformationType = ContactInformation.ContactInformationType;
	
	If InformationType <> PredefinedValue("Enum.ContactInformationTypes.WebPage") Then
		Raise StrReplace(NStr("en = 'Cannot open a contact information reference for ""%1"" type'"),
			"%1", InformationType);
	EndIf;
		
	XMLData = ContactInformation.XMLData;

	ReferenceAddress = ContactInformationInternalServerCall.ContactInformationContentString(XMLData);
	If TypeOf(ReferenceAddress) <> Type("String") Then
		Raise NStr("en = 'Reference retrieval error, invalid contact information type'");
	EndIf;
	
	If Find(ReferenceAddress, "://") > 0 Then
		GoToWebLink(ReferenceAddress);
	Else
		GoToWebLink("http://" + ReferenceAddress);
	EndIf;
EndProcedure

Function OpenContactInformationForm_AddressInputClassifier(Form, Item, Modified = True, StandardProcessing = False) Export

	StandardProcessing = False;
	
	Result = New Structure;
	Result.Insert("AttributeName", Item.Name);
	
	IsTabularSection = IsTabularSection(Item);
	
	If IsTabularSection Then
		FillingData = Form.Items[Form.CurrentItem.Name].CurrentData;
		If FillingData = Undefined Then
			Return Undefined;
		EndIf;
	Else
		FillingData = Form;
	EndIf;
	
	RowData = GetAdditionalValueString(Form, Item, IsTabularSection);
	
	// Setting presentation equal to the attribute if the presentation was modified directly in the form field and no longer matches the attribute
	If FillingData[Item.Name] <> Item.EditText Then
		FillingData[Item.Name] = Item.EditText;
		PresentationOnChange(Form, Item, IsTabularSection);
		Form.Modified = True;
	EndIf;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("ContactInformationKind", RowData.Kind);
	OpenParameters.Insert("FieldValues", RowData.FieldValues);
	OpenParameters.Insert("Presentation", Item.EditText);
	
	If Not IsTabularSection Then
		OpenParameters.Insert("Comment", RowData.Comment);
	EndIf;
	
	Notification = New NotifyDescription("PresentationStartChoiceCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("FillingData",  FillingData);
	Notification.AdditionalParameters.Insert("IsTabularSection", IsTabularSection);
	Notification.AdditionalParameters.Insert("RowData",      	RowData);
	Notification.AdditionalParameters.Insert("Item",           Item);
	Notification.AdditionalParameters.Insert("Result",         Result);
	Notification.AdditionalParameters.Insert("Form",           Form);	
	
	InformationKind = OpenParameters.ContactInformationKind;
	
	//NameOfFormToOpen = ContactInformationClientServerCached.ContactInformationInputFormName(InformationKind);
	//If NameOfFormToOpen = Undefined Then
	//	Raise NStr("en = 'Address type cannot be processed: """ + InformationKind + """'");
	//EndIf;
	
	NameOfFormToOpen = "DataProcessor.ContactInformationInput.Form.AddressInputClassifier";
	
	If Not OpenParameters.Property("Title") Then
		OpenParameters.Insert("Title", String(ContactInformationInternalServerCall.ContactInformationKindType(InformationKind)));
	EndIf;
	
	OpenParameters.Insert("OpenByScenario", True);
	
	OpenForm(NameOfFormToOpen, OpenParameters, Form, , , , Notification);	
	
	Return Undefined;	

EndFunction // ()

#EndRegion

#Region InternalInterface

// Nonmodal dialog completion
Procedure PresentationStartChoiceCompletion(Val CloseResult, Val AdditionalParameters) Export
	If TypeOf(CloseResult) <> Type("Structure") Then
		Return;
	EndIf;
	
	FillingData = AdditionalParameters.FillingData;
	RowData     = AdditionalParameters.RowData;
	Result        = AdditionalParameters.Result;
	Item          = AdditionalParameters.Item;
	Form            = AdditionalParameters.Form;
	
	PresentationText = CloseResult.Presentation;
	
	If AdditionalParameters.IsTabularSection Then
		FillingData[Item.Name + "FieldValues"] = CloseResult.ContactInformation;
		
	Else
		If IsBlankString(RowData.Comment) And Not IsBlankString(CloseResult.Comment) Then
			Result.Insert("IsCommentAddition", True);
			
		ElsIf Not IsBlankString(RowData.Comment) And IsBlankString(CloseResult.Comment) Then
			Result.Insert("IsCommentAddition", False);
			
		Else
			If Not IsBlankString(RowData.Comment) Then
				Form.Items["Comment" + Item.Name].Title = CloseResult.Comment;
			EndIf;
			
		EndIf;
		
		RowData.Presentation = PresentationText;
		RowData.FieldValues = CloseResult.ContactInformation;
		RowData.Comment   = CloseResult.Comment;
	EndIf;
	
	FillingData[Item.Name] = PresentationText;
	
	Form.Modified = True;
	UpdateFormContactInformation(Form, Result);
EndProcedure

// Nonmodal dialog completion
Procedure ContactInformationAddInputFieldCompletion(Val SelectedItem, Val AdditionalParameters) Export
	If SelectedItem = Undefined Then
		// Canceling selection
		Return;
	EndIf;
	
	Result = New Structure("KindToAdd", SelectedItem.Value);
	
	UpdateFormContactInformation(AdditionalParameters.Form, Result);
EndProcedure

//  StartChoice event handler for streets.
//
//  Parameters:
//      Item                     - Arbitrary      - form item used to call the handler.
//      SettlementClassifierCode - Number         - settlement restriction.
//      CurrentValue             - Number, String - current value (classifier code, or text).
//      FormParameters           - Structure      - additional parameter structure for the item picking form (optional).
//
Procedure StreetStartChoice(Item, SettlementClassifierCode, CurrentValue, FormParameters = Undefined) Export
	Option = ContactInformationClientServer.UsedAddressClassifier();
	
	If Option = "AC" Then
		StreetStartChoiceAddressClassifier(Item, SettlementClassifierCode, CurrentValue, FormParameters);
	EndIf;
	
	// No classifier subsystem
EndProcedure

//  StartChoice event handler for an address item (state, county, city, and so on).
//
//  Parameters:
//      Item            - Arbitrary - form item used to call the handler.
//      AddressPartCode - Number    - ID of the processed address part, may vary depending on the classifier.
//      AddressParts    - Arbitrary - values of other address parts, may vary depending on the classifier.
//      FormParameters  - Structure - additional parameter structure for the item picking form (optional).
//
Procedure AddressItemStartChoice(Item, AddressPartCode, AddressParts, FormParameters = Undefined) Export
	Option = ContactInformationClientServer.UsedAddressClassifier();
	
	If Option = "AC" Then
		AddressItemStartChoiceAddressClassifier(Item, AddressPartCode, AddressParts, FormParameters);
	EndIf;
	
	// No classifier subsystem
EndProcedure

//  Returns the full name of a settlement. 
//  Settlement is a synthetic field storing any address unit greater than street.
//
//  Parameters:
//      AddressParts - Arbitrary - values of address parts, may vary depending on the classifier.
//
Function SettlementNameByAddressParts(AddressParts) Export
	Option = ContactInformationClientServer.UsedAddressClassifier();
	
	If Option = "AC" Then
		Return SettlementNameByAddressPartsAddressClassifier(AddressParts)
	EndIf;
	
	// No classifier subsystem
	Return "";
EndFunction

//  Suggests importing the address classifier.
//
//  Parameters:
//      Text  - String         - Additional suggestion text.
//      State - Number, String - Code or name of the state to be imported.
//
Procedure ClassifierImportSuggestion(Val Text = "", Val State = Undefined) Export
	
	Option = ContactInformationClientServer.UsedAddressClassifier();
	
	If Option <> "AC" Then
		// No classifier subsystem
		Return;
	EndIf;
	
	StateParameterType = TypeOf(State);
	ImportParameters   = New Structure;
	
	If StateParameterType = Type("Number") Then
		ImportParameters.Insert("StateCodeForImport", State);
		
	ElsIf StateParameterType = Type("String") Then
		ImportParameters.Insert("StateNameForImport", State);
		
	EndIf;
	
	TitleText = NStr("en = 'Confirmation'");
	QuestionText   = TrimAll(Text + Chars.LF + NStr("en = 'Import address classifier now?'") );

	Notification = New NotifyDescription("ClassifierImportSuggestionCompletion", ThisObject, ImportParameters);
	ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo,,,TitleText);
EndProcedure

Procedure ClassifierImportSuggestionCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	ImportAddressClassifier(AdditionalParameters);
EndProcedure

//  Imports the address classifier.
//
Procedure ImportAddressClassifier(Val AdditionalParameters = Undefined) Export
	
	Option = ContactInformationClientServer.UsedAddressClassifier();
	
	If Option = "AC" Then
		AddressClassifierModule = AddressClassifierClientModule();
		AddressClassifierModule.ImportAddressClassifier(AdditionalParameters);
	EndIf;
	
	// No classifier subsystem
EndProcedure

////////////////////////////////////////////////////////////////////////////////////////////////////

// Completes the modal dialog for email creation.
Procedure CreateContactInformationEmailCompletion(Action, EmailAddress) Export
	
	RunApp("mailto:" + EmailAddress);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////////////////////////
// Address classifier implementation.
//

Function AddressClassifierClientModule()
	
	Return CommonUseClient.CommonModule("AddressClassifierClient");

EndFunction

Procedure StreetStartChoiceAddressClassifier(Item, SettlementClassifierCode, CurrentValue, Parameters = Undefined)
	FormParameters = ?(Parameters = Undefined, New Structure, Parameters);
	
	FormParameters.Insert("Level", 5);
	FormParameters.Insert("Street",   String(CurrentValue));
	
	AddressClassifierModule = AddressClassifierClientModule();
	AddressClassifierModule.OpenACSelectionForm(FormParameters, Item);
EndProcedure

Procedure AddressItemStartChoiceAddressClassifier(Item, AddressPartCode, AddressParts, Parameters = Undefined)
	
	AttributeCode = Upper(AddressPartCode);
	If AttributeCode = "STATE" Then
		Level = 1;
		
	ElsIf AttributeCode = "COUNTY" Then
		Level = 2;
		
	ElsIf AttributeCode = "CITY" Then
		Level = 3;
		
	ElsIf AttributeCode = "SETTLEMENT" Then
		Level = 4;
		
	ElsIf AttributeCode = "STREET" Then
		Level = 5;
		
	Else
		Return;
		
	EndIf;
	
	FormParameters = ?(Parameters = Undefined, New Structure, Parameters);
	
	FormParameters.Insert("State", AddressParts.State.Value);
	If AddressParts.State.Property("ClassifierCode") Then
		FormParameters.Insert("StateClassifierCode", AddressParts.State.ClassifierCode);
	EndIf;
	
	FormParameters.Insert("County", AddressParts.County.Value);
	If AddressParts.County.Property("ClassifierCode") Then
		FormParameters.Insert("CountyClassifierCode", AddressParts.County.ClassifierCode);
	EndIf;
	
	FormParameters.Insert("City", AddressParts.City.Value);
	If AddressParts.City.Property("ClassifierCode") Then
		FormParameters.Insert("CityClassifierCode", AddressParts.City.ClassifierCode);
	EndIf;
	
	FormParameters.Insert("Settlement", AddressParts.Settlement.Value);
	If AddressParts.Settlement.Property("ClassifierCode") Then
		FormParameters.Insert("SettlementClassifierCode", AddressParts.Settlement.ClassifierCode);
	EndIf;
	
	FormParameters.Insert("Level", Level);
	
	AddressClassifierModule = AddressClassifierClientModule();
	AddressClassifierModule.OpenACSelectionForm(FormParameters, Item);
EndProcedure

Function SettlementNameByAddressPartsAddressClassifier(AddressParts)
	Return ContactInformationClientServer.FullDescr(
		ValueOrDescription(AddressParts.Settlement), "", 
		ValueOrDescription(AddressParts.City), "", 
		ValueOrDescription(AddressParts.County), "", 
		ValueOrDescription(AddressParts.State), "", );
EndFunction

////////////////////////////////////////////////////////////////////////////////////////////////////

Function ValueOrDescription(AddressPart)
	If IsBlankString(AddressPart.Value) Then
		Return TrimAll("" + AddressPart.Description + " " + AddressPart.Abbr);
	EndIf;
	Return AddressPart.Value;
EndFunction

#EndRegion

#Region InternalProceduresAndFunctions

// Returns a string of additional values by attribute name.
//
// Parameters:
//    Form - ManagedForm                    - passed form.
//    Item - FormDataStructureAndCollection - form data.
//
// Returns:
//    CollectionRow - data found.
//    Undefined     - if no data is available.
//
Function GetAdditionalValueString(Form, Item, IsTabularSection = False)
	
	Filter = New Structure("AttributeName", Item.Name);
	Rows = Form.ContactInformationAdditionalAttributeInfo.FindRows(Filter);
	RowData = ?(Rows.Count() = 0, Undefined, Rows[0]);
	
	If IsTabularSection And RowData <> Undefined Then
		
		PathToString = Form.Items[Form.CurrentItem.Name].CurrentData;
		
		RowData.Presentation = PathToString[Item.Name];
		RowData.FieldValues = PathToString[Item.Name + "FieldValues"];
		
	EndIf;
	
	Return RowData;
	
EndFunction

// Generates a string presentation of a phone number.
//
// Parameters:
//    CountryCode - String - country code.
//    AreaCode    - String - area code.
//    PhoneNumber - String - phone number.
//    Extension   - String - extension.
//    Comment     - String - comment.
//
// Returns:
//    String - phone number presentation.
//
Function GeneratePhonePresentation(CountryCode, AreaCode, PhoneNumber, Extension, Comment) Export
	
	Presentation = ContactInformationManagementClientServer.GeneratePhonePresentation(
	CountryCode, AreaCode, PhoneNumber, Extension, Comment);
	
	Return Presentation;
	
EndFunction

// Fills an address with another address.
Procedure FillAddress(Val Form, Val AttributeName, Val FoundRow, Val Result)
	
	// All strings are addresses
	AllRows = Form.ContactInformationAdditionalAttributeInfo;
	FoundRows = AllRows.FindRows( New Structure("Type, IsTabularSectionAttribute", FoundRow.Type, False) );
	FoundRows.Delete( FoundRows.Find(FoundRow) );
	
	FieldValuesForAnalysis = New Array;
	For Each Address In FoundRows Do
		FieldValuesForAnalysis.Add(New Structure("ID, Presentation, FieldValues, AddressKind",
			Address.GetID(), Address.Presentation, Address.FieldValues, Address.Kind));
	EndDo;
	
	AddressesForFilling = ContactInformationInternalServerCall.AddressesAvailableForCopying(FieldValuesForAnalysis, FoundRow.Kind);
		
	If AddressesForFilling.Count() = 0 Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription("FillAddressCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("Form", Form);
	Notification.AdditionalParameters.Insert("FoundRow", FoundRow);
	Notification.AdditionalParameters.Insert("AttributeName",    AttributeName);
	Notification.AdditionalParameters.Insert("Result",       Result);
	
	Form.ShowChooseFromMenu(Notification, AddressesForFilling, Form.Items["Command" + AttributeName]);
EndProcedure

// Completes a nonmodal dialog.
Procedure FillAddressCompletion(Val SelectedItem, Val AdditionalParameters) Export
	If SelectedItem = Undefined Then
		Return;
	EndIf;
	
	AllRows = AdditionalParameters.Form.ContactInformationAdditionalAttributeInfo;
	SourceRow = AllRows.FindByID(SelectedItem.Value);
	If SourceRow = Undefined Then
		Return;
	EndIf;
		
	AdditionalParameters.FoundRow.FieldValues = SourceRow.FieldValues;
	AdditionalParameters.FoundRow.Presentation = SourceRow.Presentation;
	AdditionalParameters.FoundRow.Comment   = SourceRow.Comment;
		
	AdditionalParameters.Form[AdditionalParameters.AttributeName] = SourceRow.Presentation;
		
	AdditionalParameters.Form.Modified = True;
	UpdateFormContactInformation(AdditionalParameters.Form, AdditionalParameters.Result);

EndProcedure

// Processes entering a comment using the context menu.
Procedure EnterComment(Val Form, Val AttributeName, Val FoundRow, Val Result)
	Comment = FoundRow.Comment;
	
	Notification = New NotifyDescription("EnterCommentCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("Form", Form);
	Notification.AdditionalParameters.Insert("CommentAttributeName", "Comment" + AttributeName);
	Notification.AdditionalParameters.Insert("FoundRow", FoundRow);
	Notification.AdditionalParameters.Insert("PreviousComment", Comment);
	Notification.AdditionalParameters.Insert("Result", Result);
	
	CommonUseClient.ShowMultilineTextEditingForm(Notification, Comment, 
		NStr("en = 'Comment'"));
EndProcedure

// Completes a nonmodal dialog.
Procedure EnterCommentCompletion(Val Comment, Val AdditionalParameters) Export
	If Comment = Undefined Or Comment = AdditionalParameters.PreviousComment Then
		// Input canceled, or no changes
		Return;
	EndIf;
	
	CommentWasEmpty  = IsBlankString(AdditionalParameters.PreviousComment);
	CommentBecameEmpty = IsBlankString(Comment);
	
	AdditionalParameters.FoundRow.Comment = Comment;
	
	If CommentWasEmpty And Not CommentBecameEmpty Then
		AdditionalParameters.Result.Insert("IsCommentAddition", True);
	ElsIf Not CommentWasEmpty And CommentBecameEmpty Then
		AdditionalParameters.Result.Insert("IsCommentAddition", False);
	Else
		Item = AdditionalParameters.Form.Items[AdditionalParameters.CommentAttributeName];
		Item.Title = Comment;
	EndIf;
	
	AdditionalParameters.Form.Modified = True;
	UpdateFormContactInformation(AdditionalParameters.Form, AdditionalParameters.Result)
EndProcedure

// Context call.
Procedure UpdateFormContactInformation(Form, Result)

	Form.RefreshContactInformation(Result);
	
EndProcedure

Function IsTabularSection(Item)
	
	Parent = Item.Parent;
	
	While TypeOf(Parent) <> Type("ManagedForm") Do
		
		If TypeOf(Parent) = Type("FormTable") Then
			Return True;
		EndIf;
		
		Parent = Parent.Parent;
		
	EndDo;
	
	Return False;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Handlers of conditional calls of other subsystems.

// Opens the address classifier import form.
//
Procedure OnAddressClassifierImport() Export
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		AddressClassifierClientModule = CommonUseClient.CommonModule("AddressClassifierClient");
		AddressClassifierClientModule.ImportAddressClassifier();
	EndIf;
	
EndProcedure

#EndRegion
