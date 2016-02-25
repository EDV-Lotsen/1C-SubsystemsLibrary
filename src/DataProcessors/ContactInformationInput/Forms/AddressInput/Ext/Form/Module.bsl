// The form is parameterized as follows:
//
//      Title           - String  - form title.
//      FieldValues     - String  - serialized contact information value, or empty string used
//                                  to enter new contact information value.
//      Presentation    - String  - address presentation (used only when working with old data).
//      ContactInformationKind    - CatalogRef.ContactInformationKinds, Structure - description of
//                                  data to be edited.
//      Comment         - String  - comment to be placed in the Comment field, optional.
//
//      ReturnValueList - Boolean - flag specifying that the returned ContactInformation value 
//                                  has ValueList type (for compatibility purposes), optional.
//
//  Selection result:
//      Structure with the following fields:
//          * ContactInformation  - String  - contact information XML string.
//          * Presentation        - String  - presentation.
//          * Comment             - String  - comment.
//          * EnteredInFreeFormat - Boolean - input flag.
//
// -------------------------------------------------------------------------------------------------

#Region FormEventHandlers
 
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	If Not Parameters.Property("OpenByScenario") Then
		Raise NStr("en='The data processor cannot be opened manually'");
	EndIf;
	
	Parameters.Property("ReturnValueList", ReturnValueList);
	
	// Internal initialization
	MasterFieldBackgroundColor = StyleColors.MasterFieldBackground;
	FormBackColor              = StyleColors.FormBackColor;
	ValidFieldColor            = New Color;   // (243, 255, 243)
	AutoColor                  = New Color;
	
	HomeCountry = Catalogs.WorldCountries.USA;
	
	ContactInformationKind = ContactInformationManagement.ContactInformationKindStructure(Parameters.ContactInformationKind);
	ContactInformationKind.Insert("Ref", Parameters.ContactInformationKind);
	
	// Title
	If IsBlankString(Parameters.Title) Then
		If TypeOf(ContactInformationKind)=Type("CatalogRef.ContactInformationKinds") Then
			Title = String(ContactInformationKind);
			// Otherwise, keeping the title specified in the form
		EndIf;
	Else
		Title = Parameters.Title;
	EndIf;
	
	// Modes
	CanImportClassifier    = ContactInformationInternal.CanChangeAddressClassifier();
	HasClassifier          = Undefined <> ContactInformationClientServer.UsedAddressClassifier();
	
	HideObsoleteAddresses  = ContactInformationKind.HideObsoleteAddresses;
	
	DomesticAddressOnly = ContactInformationKind.DomesticAddressOnly;
	ContactInformationType = ContactInformationKind.Type;
	
	// Available building options
	//SetItemSelectionList(Items.BuildingType,      Items.Building,       ContactInformationInternal.DataOptionsHouse());
	
	// Attempting to fill data based on parameter values
	If ContactInformationClientServer.IsXMLString(Parameters.FieldValues) 
		And ContactInformationType=Enums.ContactInformationTypes.Address
	Then
		ReadResults = New Structure;
		XDTOContactInfo = ContactInformationInternal.ContactInformationDeserialization(Parameters.FieldValues, ContactInformationType, ReadResults);
		If ReadResults.Property("ErrorText") Then
			// Recognition errors. A warning must be displayed when opening the form
			WarningTextOnOpen = ReadResults.ErrorText;
			XDTOContactInfo.Presentation = Parameters.Presentation;
			XDTOContactInfo.Content.Country = String(HomeCountry);
		EndIf;
	Else
		XDTOContactInfo = ContactInformationInternal.AddressDeserialization(Parameters.FieldValues, Parameters.Presentation, );
	EndIf;
	
	If Parameters.Comment<>Undefined Then
		// Creating a new comment to prevent comment import from contact information
		ContactInformationInternal.ContactInformationComment(XDTOContactInfo, Parameters.Comment);
	EndIf;
	
	ContactInformationAttibuteValues(ThisObject, XDTOContactInfo);
	If ValueIsFilled(Country) Then
		// Record is found in the country catalog
		InitialCountryPresentation = "";
		
	ElsIf IsBlankString(CountryCode) Then
		// Record is found in the classifier but not in the country catalog. Create a catalog record?
		InitialCountryPresentation = TrimAll(XDTOContactInfo.Content.Country);
		
	Else
		// Record is found neither in the classifier nor in the country catalog
		InitialCountryPresentation = TrimAll(XDTOContactInfo.Content.Country);
		
	EndIf;
	
	//PARTIALLY_DELETED
	//DrawAdditionalBuildings();
	
	// Empty values are valid as well
	//If IsBlankString(Building) And IsBlankString(BuildingType) Then
	//	BuildingType = ContactInformationClientServer.FirstOrEmpty(Items.BuildingType);
	//EndIf;
	
	// Validating
	//If DomesticAddressOnly Then
	//	Items.Country.Enabled = False;
	//	Items.Country.BackColor = AutoColor;
	//	If Country <> HomeCountry Then
	//		If Not IsBlankString(Parameters.FieldValues) Then
	//			// Considering the address to be domestic
	//			AddressPresentationTest = TrimAll(
	//				TrimAll(Country) + " " + TrimAll(ForeignAddressPresentation)
	//			);
	//			If Not IsBlankString(AddressPresentationTest) Then
	//				AddressPresentation = AddressPresentationTest;
	//				AllowAddressInputInFreeFormat = True;
	//				AddressPresentationChanged    = True; 
	//			EndIf;
	//		EndIf;
	//		Country = HomeCountry;
	//		Modified = True;
	//	EndIf;
	//EndIf;
	
	// All addresses are domestic by default
	If ValueIsFilled(Country) Then
		CountryCode = Country.Code;
	Else
		If IsBlankString(InitialCountryPresentation) Then
			Country     = HomeCountry;
			CountryCode = HomeCountry.Code;
		Else 
			// Failed to determine country, but this address is definitely not domestic
			If IsBlankString(WarningTextOnOpen) Then
				WarningFieldOnOpen = "Country";
			EndIf;
			WarningTextOnOpen = WarningTextOnOpen
				+ StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Country ""%1"" is not found in the world country catalog.'"), InitialCountryPresentation
				);
		EndIf;
	EndIf;
	
	// Initializing items
	//If Country = HomeCountry Then
	//	Items.AddressType.CurrentPage = Items.HomeCountryAddress;
	//	CurrentItem = Items.Settlement;
	//Else
	//	Items.AddressType.CurrentPage = Items.ForeignAddress;
	//	CurrentItem = Items.ForeignAddressPresentation;
	//EndIf;
	
	If CommonUseClientServer.IsWebClient() Then
		CanImportClassifier = False;
	EndIf;
	//Items.ImportClassifier.Visible           = CanImportClassifier;
	//Items.ImportClassifierAllActions.Visible = CanImportClassifier;
	
	If Not HasClassifier Then
		Items.FillByPostalCode.Visible           = False;
		Items.FillByPostalCodeAllActions.Visible = False;
	EndIf;
	
	// Displaying presentation by default
	Items.AddressPresentationComment.CurrentPage = Items.AddressPagePresentation;
	
	// Content of the All actions command group depends on interface selection
	//If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Taxi Then
	//	Items.FormAllActions.Visible = False;
	//Else
	//	Items.EnterAddressInFreeFormat.Visible = False;
	//	Items.FillByPostalCode.Visible         = False;
	//	Items.FormClearAddress.Visible         = False;
	//	Items.ImportClassifier.Visible         = False;
	//	Items.CustomizeForm.Visible            = False;
	//EndIf;
	
	SetFormUsageKey();
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	SetCommentIcon();
	
	//PARTIALLY_DELETED
	//Items.AddObject.Enabled = CanAddAdditionalObjects();
	
	CountryChangeProcessingClient();
	AddressPresentationInputState(AllowAddressInputInFreeFormat, False);
	VisualizeChoiceValidity();
	
	If Not IsBlankString(WarningTextOnOpen) Then
		AttachIdleHandler("Attachable_WarningAfterFormOpen", 0.1, True);
	EndIf;
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	Notification = New NotifyDescription("ConfirmAndClose", ThisObject);
	CommonUseClient.ShowFormClosingConfirmation(Notification, Cancel);
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure CountryOnChange(Item)
	CountryChangeProcessingClient();
	
	Context = FormContextClient();
	FillAddressPresentation(Context);
	FormContextClient(Context);
	
#If WebClient Then
	// Addressing platform specifics
	Item.UpdateEditText();
#EndIf

	// Always displaying presentation
	Items.AddressPresentationComment.CurrentPage = Items.AddressPagePresentation;
EndProcedure

&AtClient
Procedure CountryClear(Item, StandardProcessing)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure CountryAutoComplete(Item, Text, ChoiceData, Waiting, StandardProcessing)
	
	If Waiting = 0 Then
		// Generating the quick selection list
		If IsBlankString(Text) Then
			ChoiceData = New ValueList;
		EndIf;
		Return;
	EndIf;

EndProcedure

&AtClient
Procedure CountryTextInputEnd(Item, Text, ChoiceData, StandardProcessing)
	
#If WebClient Then
	// Addressing platform specifics
	StandardProcessing = False;
	ChoiceData         = New ValueList;
	ChoiceData.Add(Country);
	Return;
#EndIf

EndProcedure

&AtClient
Procedure CountryChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	ContactInformationManagementClient.WorldCountryChoiceProcessing(Item, SelectedValue, StandardProcessing);
	
EndProcedure

&AtClient
Procedure PostalCodeOnChange(Item)
	
	//Context = FormContextClient();
	//
	//CurrentPostalCode = TrimAll(PostalCode);
	//If HasClassifier And StrLen(CurrentPostalCode) = 6 Then
	//	FormParameters = New Structure("PostalCode, HideObsoleteAddresses", CurrentPostalCode, HideObsoleteAddresses);
	//	OpenForm("DataProcessor.ContactInformationInput.Form.AddressSearchByPostalCode", FormParameters, Items.PostalCode);
	//EndIf;
	//
	//FillAddressPresentation(Context);
	//FormContextClient(Context);
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure PostalCodeChoiceProcessing(Item, SelectedValue, StandardProcessing)
	StandardProcessing = False;
	If SelectedValue = Undefined Then 
		Return;
	EndIf;
	
	Context = FormContextClient();
	FillAddressByPostalCodeData(Context, SelectedValue);
	FormContextClient(Context);
	
	VisualizeChoiceValidity();
	Modified = True;
	
	CurrentItem = Items.Building;
EndProcedure

&AtServer
Procedure FillAddressByPostalCodeData(Context, Val PostalCodeData)
	
	ClearAddressServer(Context);
	
	XDTOContactInformation = ContactInformationByAttributeValues(Context);
	
	// Assuming that the address is still domestic
	XDTOAddress = XDTOContactInformation.Content.Content;
	
	ContactInformationInternal.AddressPostalCode(XDTOAddress, PostalCodeData.PostalCode);
	ContactInformationInternal.SetAddressSettlementByPostalCode(XDTOAddress, PostalCodeData.Code);
	ContactInformationInternal.SetAddressStreetByPostalCode(XDTOAddress, PostalCodeData.Code);
	
	ContactInformationAttibuteValues(Context, XDTOContactInformation);
	
	FillAddressPresentation(Context);
EndProcedure

&AtClient
Procedure CommentOnChange(Item)
	
	SetCommentIcon();
	
EndProcedure

&AtClient
Procedure BuildingTypeOnChange(Item)
	Context = FormContextClient();
	FillAddressPresentation(Context);
	FormContextClient(Context);
	
	VisualizeChoiceValidity();
EndProcedure

&AtClient
Procedure BuildingOnChange(Item)
	Context = FormContextClient();
	UpdatePostalCodeAndPresentation(Context);
	FormContextClient(Context);
	
	VisualizeChoiceValidity();
EndProcedure

&AtClient
Procedure SettlementOnChange(Item)
	Context = FormContextClient();
	SettlementChangeProcessingServer(Context);
	FormContextClient(Context);
	
	VisualizeChoiceValidity();
EndProcedure

&AtClient
Procedure SettlementStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	
	// Clearing the address if this is executed directly after editing
	If Item.EditText<>Settlement Then
		Modified   = True;
		Settlement = Item.EditText;
		
		SettlementClassifierCode = 0;
		SettlementExactMatch = False;
		StreetExactMatch     = False;
		BuildingExactMatch   = False;
		
		Context = FormContextClient();
		SettlementChangeProcessingServer(Context, True);
		FormContextClient(Context);
	EndIf;
	
	OpenForm("DataProcessor.ContactInformationInput.Form.SettlementAddresses",
		New Structure("SettlementDetails, HideObsoleteAddresses", 
			SettlementDetails, HideObsoleteAddresses
		), Item);
	
EndProcedure

&AtClient
Procedure SettlementChoiceProcessing(Item, SelectedValue, StandardProcessing)
	Var CanImportState;
	
	StandardProcessing = False;
	If SelectedValue=Undefined Then
		Return;
	EndIf;
	Modified = True;
	
	ValueType = TypeOf(SelectedValue);
	GenerateDetails = True;
	If ValueType=Type("Structure") Then
		// Getting data from autocompletion results or manual selection results
		SettlementClassifierCode = SelectedValue.Code;
		Settlement                    = SelectedValue.Presentation;
		SettlementExactMatch         = SettlementClassifierCode>0;
		
		If SelectedValue.Property("SettlementDetails") Then
			// Making selection using the details input form
			SettlementDetails = SelectedValue.SettlementDetails;
			GenerateDetails = False;
		EndIf;
		
		StateNotImported = SelectedValue.Property("CanImportState") And SelectedValue.CanImportState;
		If CanImportClassifier And StateNotImported Then
			// Suggesting classifier import
			ContactInformationManagementClient.ClassifierImportSuggestion(
				StringFunctionsClientServer.SubstituteParametersInString(NStr("en='Data for ""%1"" is not imported.'"), SelectedValue.Presentation), 
				SelectedValue.Presentation
			);
		EndIf;
		
	Else
		// A different source, attempting to parse
		SettlementClassifierCode = 0;
	 	Settlement              = String(SelectedValue);
		
		SettlementExactMatch  = False;
		StreetExactMatch      = False;
		BuildingExactMatch    = False;
	EndIf;
	
	// If the city is selected exactly, settlement details are restored from the postal code; otherwise, the entered details are kept
	Context = FormContextClient();
	SettlementChangeProcessingServer(Context, GenerateDetails);
	FormContextClient(Context);
	
	VisualizeChoiceValidity();
EndProcedure

&AtClient
Procedure SettlementAutoComplete(Item, Text, ChoiceData, Waiting, StandardProcessing)
	ChoiceData = New ValueList;
	
	If Waiting = 0 Then
		// Creating a quick choice list, no changes to the standard processing procedure
		Return;
	EndIf;
	
	Items.Settlement.BackColor = AutoColor;
	If StrLen(Text) < 3 Then 
		// No options, the list is empty, no changes to the standard processing procedure
		VisualizeChoiceValidity();
		Return;
	EndIf;
	
	ClassifierAnalysis = SettlementAutoCompleteResults(Text, HideObsoleteAddresses, True);
	ChoiceData = ClassifierAnalysis.ChoiceData;
	
	// Disabling the standard processing procedure only if other options are available
	StandardProcessing = ChoiceData.Count() = 0;
EndProcedure

&AtClient
Procedure SettlementTextInputEnd(Item, Text, ChoiceData, StandardProcessing)
	// Exiting the field after its text was modified manually
	StandardProcessing = False;
	
	Modified = True;
	
	ChoiceData = New ValueList;
	ChoiceData.Add(Text);
	
	// Settlement data is now inaccurate
	SettlementClassifierCode = 0;
	SettlementExactMatch     = False;
	Settlement               = Text;
	
	// Street data is now inaccurate
	StreetClassifierCode = 0;
	StreetExactMatch     = False;
	
	// Building data is now inaccurate
	BuildingExactMatch = False;
	
	Context = FormContextClient();
	SettlementChangeProcessingServer(Context);
	FormContextClient(Context);
	
	VisualizeChoiceValidity();
EndProcedure

&AtClient
Procedure StreetOnChange(Item)
	Context = FormContextClient();
	StreetChangeProcessingServer(Context);
	FormContextClient(Context);
	
	VisualizeChoiceValidity();
EndProcedure

&AtClient
Procedure StreetStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	
	// Clearing data if this is executed directly after editing
	If Item.EditText<>Street Then
		Street = Item.EditText;
	EndIf;
	
	If SettlementClassifierCode>0 Then
		FormParameters = New Structure("HideObsoleteAddresses, SettlementClassifierCode, Street", 
			HideObsoleteAddresses, SettlementClassifierCode, Street);
	Else
		// Street parent is undefined, opening the form with no data
		FormParameters = New Structure("HideObsoleteAddresses, SettlementClassifierCode, Street, Title", 
			HideObsoleteAddresses, -1, Street, Settlement + " " + NStr("en = '(not found)'"));
	EndIf;
		
	ContactInformationManagementClient.StreetStartChoice(Item, SettlementClassifierCode, Street, FormParameters);
EndProcedure

&AtClient
Procedure StreetChoiceProcessing(Item, SelectedValue, StandardProcessing)
	StandardProcessing = False;
	
	If SelectedValue=Undefined Then
		Return;
	EndIf;
	Modified = True;
	
	ChoiceType = TypeOf(SelectedValue);
	If ChoiceType=Type("Structure") Then
		// Getting data from autocompletion results or manual selection results
		StreetClassifierCode = SelectedValue.Code;
		Street               = SelectedValue.Presentation;
		StreetExactMatch     = True;
	Else
		// A different source, attempting to parse
		StreetClassifierCode = 0;
	 	Street              = String(SelectedValue);
		
		StreetExactMatch   = False;
		BuildingExactMatch = False;
	EndIf;
	
	Context = FormContextClient();
	StreetChangeProcessingServer(Context);
	FormContextClient(Context);
	
	VisualizeChoiceValidity();
EndProcedure

&AtClient
Procedure StreetAutoComplete(Item, Text, ChoiceData, Waiting, StandardProcessing)
	ChoiceData = New ValueList;
	
	If Waiting = 0 Then
		// Creating a quick choice list; no changes to the standard processing procedure
		Return;
	EndIf;
	
	Items.Street.BgColor = AutoColor;
	If StrLen(Text) < 3 Or SettlementClassifierCode <= 0 Then 
		// No options, the list is empty, no changes to the standard processing procedure
		VisualizeChoiceValidity();
		Return;
	EndIf;
	
	ClassifierAnalysis = StreetAutoCompleteResults(SettlementClassifierCode, Text, HideObsoleteAddresses, True);
	ChoiceData = ClassifierAnalysis.ChoiceData;
	
	// Disabling the standard processing procedure only if other options are available
	StandardProcessing = ChoiceData.Count() = 0;
EndProcedure

&AtClient
Procedure StreetTextInputEnd(Item, Text, ChoiceData, StandardProcessing)
	// Exiting the field after its text was modified manually
	Modified = True;
	
	ChoiceData = New ValueList;
	ChoiceData.Add(Text);
	Street = Text;
	
	// Street data is now unverified
	StreetClassifierCode = 0;
	StreetExactMatch = False;
	
	// Building data is now unverified
	BuildingExactMatch = False;
EndProcedure

&AtClient
Procedure AddressPresentationOnChange(Item)
	AddressPresentationChanged = True;
	AddressPresentationOnChangeServer();
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OKCommand(Command)
	
	ConfirmAndClose();
	
EndProcedure

&AtClient
Procedure CancelCommand(Command)
	Modified = False;
	Close();
EndProcedure

&AtClient
Procedure CheckAddressFilled(Command)
	
	If AllowAddressInputInFreeFormat Then
		ShowMessageBox(, NStr("en='The address cannot be verified because it was entered in free format.'"));
		Return;
	EndIf;

	NotifyAboutNoErrors = True;
	
	Context = FormContextClient();
	ErrorList = FillErrorList(Context, NotifyAboutNoErrors);
	NotifyFillErrors(ErrorList, NotifyAboutNoErrors);
	
EndProcedure

&AtClient
Procedure ClearAddress(Command)
	
	ClearAddressClient();
	
EndProcedure

&AtClient
Procedure FillByPostalCode(Command)
	
	If HasClassifier And Not IsBlankString(PostalCode) Then
		FormParameters = New Structure("PostalCode, HideObsoleteAddresses", TrimAll(PostalCode), HideObsoleteAddresses);
		OpenForm("DataProcessor.ContactInformationInput.Form.AddressSearchByPostalCode", FormParameters, Items.PostalCode);
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportClassifier(Command)
	ContactInformationManagementClient.ImportAddressClassifier();
EndProcedure

//Raise ("CHECK ON TEST. Procedure AddObject deleted"):
&AtClient
Procedure EnterAddressInFreeFormat(Command)
	
	If AllowAddressInputInFreeFormat Then
		QuestionText = NStr("en='The changes entered manually will be lost.
		                        |Do you want to continue?'");
	Else
		QuestionText = NStr("en='Do you want to enter the address in free format?
		                        |Free-format addresses may fail address classifier verification.'");
	EndIf;
	
	Notification = New NotifyDescription("EnterAddressInFreeFormatCompletion", ThisObject);
	ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo, , , NStr("en='Confirmation'"));
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure SetCommentIcon()
	
	If IsBlankString(Comment) Then
		Items.AddressPageComment.Picture = New Picture;
	Else
		Items.AddressPageComment.Picture = PictureLib.Comment;
	EndIf;
		
EndProcedure

&AtClient
Procedure ConfirmAndClose(Result = Undefined, AdditionalParameters = Undefined) Export
	// If the data was not modified, emulating Cancel command
	
	If Modified Then
		// Address value is modified 
		
		Context = FormContextClient();
		Result = FlagUpdateSelectionResults(Context, ReturnValueList);
		
		// Reading contact information kind flags again
		ContactInformationKind = Context.ContactInformationKind;
		
		If ContactInformationKind.CheckValidity And (Not AllowAddressInputInFreeFormat) And Result.FillErrors.Count()>0 Then
			NotifyFillErrors(Result.FillErrors, False);
			If ContactInformationKind.ProhibitInvalidEntry Then
				Return;
			EndIf;
		EndIf;
		
		Result = Result.ChoiceData;
		
		ClearModifiedOnChoice();
#If WebClient Then
		CloseFlag = CloseOnChoice;
		CloseOnChoice = False;
		NotifyChoice(Result);
		CloseOnChoice = CloseFlag;
#Else
		NotifyChoice(Result);
#EndIf
		SaveFormState();
		
	ElsIf Comment <> CommentCopy Then
		// Only the comment is modified, attempting to revert
		Result = CommentChoiceOnlyResult(Parameters.FieldValues, Parameters.Presentation, Comment);
		Result = Result.ChoiceData;
		
		ClearModifiedOnChoice();
#If WebClient Then
		CloseFlag = CloseOnChoice;
		CloseOnChoice = False;
		NotifyChoice(Result);
		CloseOnChoice = CloseFlag;
#Else
		NotifyChoice(Result);
#EndIf
		SaveFormState();
		
	Else
		Result = Undefined;
	EndIf;
	
	If (ModalMode Or CloseOnChoice) And IsOpen() Then
		ClearModifiedOnChoice();
		SaveFormState();
		Close(Result);
	EndIf;

EndProcedure

&AtClient
Procedure SaveFormState()
	SetFormUsageKey();
	SavedInSettingsDataModified = True;
EndProcedure

&AtClient
Procedure AddObjectCompletion(Val SelectedItem, Val AdditionalParameters) Export
	If SelectedItem=Undefined Then
		// Canceling selection
		Return;
	EndIf;
	
	If SelectedItem.Value=1 Then
		Row = AdditionalBuildings.Add();
		
		Row.Type = SelectedItem.Presentation;
		Row.XPath = ContactInformationClientServerCached.AdditionalAddressingObjectNumberXPath(Row.Type);
		//PARTIALLY_DELETED
		//CurrentName = DrawAdditionalBuildings();
		CurrentName = Undefined;
	EndIf;
	
	// Adding a number of objects exceeding the number of available options is not allowed
	Items.AddObject.Enabled = AdditionalParameters.VariantCount>1;
	
	If CurrentName<>Undefined Then
		CurrentItem = Items[CurrentName];
	EndIf;
	
	Modified = True;
EndProcedure

&AtClient
Procedure EnterAddressInFreeFormatCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult<>DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	AllowAddressInputInFreeFormat = Not AllowAddressInputInFreeFormat;
	AddressPresentationInputState(AllowAddressInputInFreeFormat);
	
	Modified = True;
EndProcedure

&AtClient
Procedure ClearModifiedOnChoice()
	Modified    = False;
	CommentCopy = Comment;
EndProcedure

&AtClient
Procedure Attachable_WarningAfterFormOpen()
	CommonUseClientServer.MessageToUser(WarningTextOnOpen,, WarningFieldOnOpen);
EndProcedure

&AtServerNoContext
Function FlagUpdateSelectionResults(Context, ReturnValueList = False)
	// Updating some flags
	FlagsValue = ContactInformationManagement.ContactInformationKindStructure(Context.ContactInformationKind.Ref);
	
	Context.ContactInformationKind.DomesticAddressOnly = FlagsValue.DomesticAddressOnly;
	Context.ContactInformationKind.ProhibitInvalidEntry   = FlagsValue.ProhibitInvalidEntry;
	Context.ContactInformationKind.CheckValidity          = FlagsValue.CheckValidity;

	Return ChoiceResult(Context, ReturnValueList);
EndFunction

&AtServerNoContext
Function ChoiceResult(Context, ReturnValueList = False)
	XDTOInformation = ContactInformationByAttributeValues(Context);
	Result          = New Structure("ChoiceData, FillErrors");
	
	If ReturnValueList Then
		ChoiceData = ContactInformationInternal.ContactInformationToOldStructure(XDTOInformation);
		ChoiceData = ChoiceData.FieldValues;
		
	//ElsIf Context.Country = Context.HomeCountry And IsBlankString(XDTOInformation.Presentation) Then
		//ChoiceData = "";
		
	Else
		ChoiceData = ContactInformationInternal.ContactInformationSerialization(XDTOInformation);
		
	EndIf;
	
	Result.ChoiceData = New Structure("ContactInformation, Presentation, Comment, EnteredInFreeFormat",
		ChoiceData,
		XDTOInformation.Presentation,
		XDTOInformation.Comment,
		ContactInformationInternal.AddressEnteredInFreeFormat(XDTOInformation));
	
	Result.FillErrors = ContactInformationInternal.AddressFillErrors(
		XDTOInformation.Content,
		Context.ContactInformationKind);
	
	// Suppressing line breaks in the separately returned presentation
	Result.ChoiceData.Presentation = TrimAll(StrReplace(Result.ChoiceData.Presentation, Chars.LF, " "));
	
	Return Result;
EndFunction

&AtServerNoContext
Function FillErrorList(Context, NotifyAboutNoErrors)
	XDTOInformation = ContactInformationByAttributeValues(Context);
	
	// Getting value list: XPath is the error text
	Result = ContactInformationInternal.AddressFillErrors(
		XDTOInformation.Content, Context.ContactInformationKind
	);
	
	If Result.Count() = 0 // No errors
		And NotifyAboutNoErrors // It is necessary to notify user that no errors occurred.
		//  Additionally, checking if the address is empty.
		And (Not ContactInformationInternal.XDTOContactInformationFilled(XDTOInformation))
	Then
		Result.Add("/", NStr("en = 'The address is empty.'"));
	EndIf;
	
	Return Result;
EndFunction

&AtServer
Function CommentChoiceOnlyResult(ContactInfo, Presentation, Comment)
	
	If IsBlankString(ContactInfo) Then
		NewContactInfo = ContactInformationInternal.AddressDeserialization("");
		// Modifying NewContactInfo value
		ContactInformationInternal.ContactInformationComment(NewContactInfo, Comment);
		NewContactInfo = ContactInformationInternal.ContactInformationSerialization(NewContactInfo);
		AddressEnteredInFreeFormat = False;
		
	ElsIf ContactInformationClientServer.IsXMLContactInformation(ContactInfo) Then
		// Making a copy
		NewContactInfo = ContactInfo;
		// Modifying NewContactInfo value
		ContactInformationInternal.ContactInformationComment(NewContactInfo, Comment);
		AddressEnteredInFreeFormat = ContactInformationInternal.AddressEnteredInFreeFormat(ContactInfo);
		
	Else
		NewContactInfo = ContactInfo;
		AddressEnteredInFreeFormat = False;
	EndIf;
	
	Result = New Structure("ChoiceData, FillErrors", New Structure, New ValueList);
	Result.ChoiceData.Insert("ContactInformation", NewContactInfo);
	Result.ChoiceData.Insert("Presentation", Presentation);
	Result.ChoiceData.Insert("Comment", Comment);
	Result.ChoiceData.Insert("EnteredInFreeFormat", AddressEnteredInFreeFormat);
	Return Result;
EndFunction

&AtServerNoContext
Procedure SettlementChangeProcessingServer(Context, GenerateDetailsAgain=True)
	
	If Context.SettlementClassifierCode<=0 Then
		// Attempting to parse data entered manually
		ClassifierAnalysis = SettlementsByPresentation(
			Context.Settlement, Context.HideObsoleteAddresses);
		Context.SettlementExactMatch = ClassifierAnalysis.ChoiceData.Count()=1;
		If Context.SettlementExactMatch Then
			SelectedValue = ClassifierAnalysis.ChoiceData[0].Value.Value;
			Context.SettlementClassifierCode = SelectedValue.Code;
			Context.Settlement               = SelectedValue.Presentation;
		Else
			Context.StreetExactMatch   = False;
			Context.BuildingExactMatch = False;
		EndIf;
	EndIf;
	
	// Settlement data split into parts
	If GenerateDetailsAgain Then
		GenerateSettlementDetails(Context);
	EndIf;
	
	// Re-checking street data. Postal code and presentation will be updated
	StreetChangeProcessingServer(Context);
EndProcedure

&AtServerNoContext
Procedure StreetChangeProcessingServer(Context)
	
	If Context.StreetClassifierCode<=0 Then
		// Attempting to parse data entered manually
		ClassifierAnalysis = StreetsByPresentation(
			Context.SettlementClassifierCode, Context.Street, Context.HideObsoleteAddresses);
		Context.StreetExactMatch = ClassifierAnalysis.ChoiceData.Count()=1;
		If Context.StreetExactMatch Then
			SelectedValue = ClassifierAnalysis.ChoiceData[0].Value.Value;
			Context.StreetClassifierCode = SelectedValue.Code;
			Context.Street               = SelectedValue.Presentation;
			Context.StreetExactMatch     = True;
		EndIf;
	Else
		// The street matches the settlement
		Context.StreetExactMatch = IsChild(Context.StreetClassifierCode, Context.SettlementClassifierCode);
	EndIf;
	
	// Re-checking building number. Postal code and presentation will be updated
	BuildingChangeProcessingServer(Context);
EndProcedure

&AtServerNoContext
Procedure BuildingChangeProcessingServer(Context)
	Context.BuildingExactMatch = True;
	
	UpdatePostalCodeAndPresentation(Context);
EndProcedure

&AtClient
Procedure CountryChangeProcessingClient()
	
	IsDomesticAddress = Country = HomeCountry;
	
	//Items.PostalCode.Visible = IsDomesticAddress;
	//Items.AddressType.CurrentPage = ?(IsDomesticAddress, Items.HomeCountryAddress, Items.ForeignAddress);
	
	// Only domestic addresses can be checked, entered in free format, or found by postal code
	//Items.CheckAddressFilled.Enabled   = IsDomesticAddress;
	
	//Items.EnterAddressInFreeFormat.Enabled            = IsDomesticAddress;
	//Items.EnterAddressInFreeFormatAllActions.Enabled  = IsDomesticAddress;
	
	//Items.FillByPostalCode.Enabled           = IsDomesticAddress;
	//Items.FillByPostalCodeAllActions.Enabled = IsDomesticAddress;
	
	//// Only domestic addresses can be imported
	//If CanImportClassifier Then
	//	PanelButton = Items.Find("FormImportClassified");
	//	If PanelButton<>Undefined Then
	//		Items.FormImportClassified.Enabled = IsDomesticAddress;
	//	EndIf;
	//EndIf;
	
EndProcedure

&AtServer
Procedure SetItemSelectionList(ItemKind, ItemValue, Data)
	ItemValue.DropListButton = Data.CanPickValues;
	
	TypeList = Data.TypeOptions;
	ItemKind.DropListButton = TypeList.Count() > 0;
	If ItemKind.DropListButton Then
		ItemKind.ChoiceList.LoadValues(TypeList);
	EndIf;
	
EndProcedure

&AtClient
Procedure VisualizeChoiceValidity()
	
	//Items.Settlement.BackColor = ?(SettlementExactMatch, ValidFieldColor, AutoColor);
	//Items.Street.BackColor     = ?(StreetExactMatch, ValidFieldColor, AutoColor);
	//
	//RequiredColor = ?(BuildingExactMatch, ValidFieldColor, AutoColor);
	//
	//Items.BuildingType.BackColor = RequiredColor;
	//Items.Building.BackColor     = RequiredColor;
	
EndProcedure

&AtServerNoContext
Procedure UpdatePostalCodeAndPresentation(Context, XDTOContactInfo=Undefined)
	Info = ?(XDTOContactInfo=Undefined, ContactInformationByAttributeValues(Context), XDTOContactInfo);
	SetPostalCodeValue(Context, Info);
	FillAddressPresentation(Context, Info);
EndProcedure

&AtServerNoContext
Procedure SetPostalCodeValue(Context, XDTOContactInfo = Undefined)
	Info = ?(XDTOContactInfo = Undefined, ContactInformationByAttributeValues(Context), XDTOContactInfo);
	
	Address = Info.Content;
	PostalCodeByClassifier = ContactInformationInternal.GetAddressPostalCode(Address);
	If Not IsBlankString(PostalCodeByClassifier) Then
		Context.PostalCode = PostalCodeByClassifier;
		ContactInformationInternal.AddressPostalCode(Address, PostalCodeByClassifier);
		XDTOContactInfo.Presentation = ContactInformationInternal.AddressPresentation(Address, Context.ContactInformationKind);
	EndIf;
EndProcedure

&AtServerNoContext
Procedure FillAddressPresentation(Context, XDTOContactInfo=Undefined)
	
	// Country code is mandatory
	If TypeOf(Context.Country)=Type("CatalogRef.WorldCountries") Then
		Context.CountryCode = Context.Country.Code
	Else
		Context.CountryCode = "";
	EndIf;
	
	//If Context.AllowAddressInputInFreeFormat And Context.AddressPresentationChanged Then
	//	Return;
	//EndIf;
		
	//Info = ?(XDTOContactInfo=Undefined, ContactInformationByAttributeValues(Context), XDTOContactInfo);
	//Context.AddressPresentation = Info.Presentation;
EndProcedure

&AtServerNoContext
Procedure ContactInformationAttibuteValues(Context, InformationToEdit)
	
	AddressData = InformationToEdit.Content;
	
	// Common attributes
	Context.AddressPresentation = InformationToEdit.Presentation;
	Context.Comment             = InformationToEdit.Comment;
	
	// Comment copy used to identify data modifications
	Context.CommentCopy = Context.Comment;
	
	// Country by description
	CountryDescription = TrimAll(AddressData.Country);
	If IsBlankString(CountryDescription) Then
		Context.Country = Catalogs.WorldCountries.EmptyRef();
	Else
		ReferenceToUSA = Catalogs.WorldCountries.USA;
		If Upper(CountryDescription) = Upper(TrimAll(ReferenceToUSA.Description)) Then
			Context.Country     = ReferenceToUSA;
			Context.CountryCode = ReferenceToUSA.Code;
		Else
			CountryData = Catalogs.WorldCountries.WorldCountryData(, CountryDescription);
			If CountryData=Undefined Then
				// Country data is found neither in the country catalog nor in the classifier
				Context.Country     = Undefined;
				Context.CountryCode = Undefined;
			Else
				Context.Country     = CountryData.Ref;
				Context.CountryCode = CountryData.Code;
			EndIf;
		EndIf;
	EndIf;
	
	CalculatedPresentation = ContactInformationInternal.GenerateContactInformationPresentation(
		InformationToEdit, Context.ContactInformationKind);
		
	//If ContactInformationInternal.IsDomesticAddress(AddressData) Then
	//	Context.AllowAddressInputInFreeFormat = Not IsBlankString(AddressData.Content.Address_to_document);
	//	
	//	// Performing an additional check if the presentation by document and the calculated presentation are identical
	//	If Context.AllowAddressInputInFreeFormat Then
	//		If AddressPresentationsIdentical(CalculatedPresentation, AddressData.Content.Address_to_document, True) 
	//			And AddressPresentationsIdentical(InformationToEdit.Presentation, AddressData.Content.Address_to_document, True) 
	//		Then
	//			Context.AllowAddressInputInFreeFormat = False;
	//			AddressData.Content.Address_to_document      = "";
	//		EndIf;
	//	EndIf;
	//	
	//	If Context.AllowAddressInputInFreeFormat Then
	//		Context.AddressPresentation = AddressData.Content.Address_to_document;
	//	EndIf;
	//Else
	//	Context.ForeignAddressPresentation = String(AddressData.Content);
	//EndIf;
	
	// Setting the postal code value
	//Context.PostalCode = Format(ContactInformationInternal.AddressPostalCode(AddressData), "NG=");
	Context.PostalCode = ContactInformationInternal.AddressPostalCode(AddressData);
	Context.AddressLine1 = ContactInformationInternal.AddressAddressLine1(AddressData);
	Context.AddressLine2 = ContactInformationInternal.AddressAddressLine2(AddressData);
	Context.City = ContactInformationInternal.AddressCity(AddressData);
	Context.State = ContactInformationInternal.AddressState(AddressData);
	
	// Getting the synthetic Settlement value as presentation
	//Context.Settlement = ContactInformationInternal.SettlementPresentation(AddressData);
	//Context.Street = ContactInformationInternal.StreetPresentation(AddressData);
	
	//ClassifierAnalysis = ContactInformationInternal.SettlementsByPresentation(Context.Settlement, , , Context.Street);
	//FoundSettlementCount = ClassifierAnalysis.ChoiceData.Count();
	//If FoundSettlementCount = 0 Then
	//	// No matches are found. Making no changes to the settlement name.
	//	Context.SettlementClassifierCode = 0;
	//	Context.SettlementExactMatch     = False;
	//	
	//Else
	//	// Exact match or multiple matches are found. Using the first match.
	//	SelectedValue = ClassifierAnalysis.ChoiceData[0].Value.Value;
	//	Context.SettlementClassifierCode = SelectedValue.Code;
	//	Context.SettlementExactMatch     = True;
	//	Context.Settlement               = SelectedValue.Presentation;
	//	
	//EndIf;
	//
	//GenerateSettlementDetails(Context, AddressData);
	
	// Getting the synthetic Street value as presentation
		
	//ClassifierAnalysis = ContactInformationInternal.StreetsByPresentation(Context.SettlementClassifierCode, Context.Street);
	//FoundStreetCount = ClassifierAnalysis.ChoiceData.Count();
	//If FoundStreetCount = 1 Then
	//	// Exact match is found
	//	SelectedValue = ClassifierAnalysis.ChoiceData[0].Value.Value;
	//	Context.StreetClassifierCode = SelectedValue.Code;
	//	Context.StreetExactMatch     = True;
	//	Context.Street               = SelectedValue.Presentation;
	//Else
	//	// No matches or multiple matches are found. Making no changes to the street name.
	//	Context.StreetClassifierCode = 0;
	//	Context.StreetExactMatch      = False;
	//EndIf;
	
	// Building
	//Buildings = ContactInformationInternal.BuildingAddresses(AddressData);
	
	// Specifying the first and the second building separately, putting all other buildings in a list
	//DataTable = Buildings.Buildings;
	
	// Kind = 1 - flag used to specify a building
	//BuildingString = DataTable.Find(1, "Kind");
	//If BuildingString<>Undefined Then
	//	Context.BuildingType = BuildingString.Type;
	//	Context.Building     = BuildingString.Value;
	//	Context.BuildingExactMatch = True;
	//	DataTable.Delete(BuildingString);
	//Else
	//	Context.BuildingExactMatch = False;
	//EndIf;
	
	//LineNumber = DataTable.Count();
	//While LineNumber>0 Do 
	//	LineNumber = LineNumber - 1;
	//	FillPropertyValues(Context.AdditionalBuildings.Insert(0), DataTable[LineNumber]);
	//EndDo;
	
	// If the passed presentation is not identical to the calculated presentation, the address is considered to be modified
	If Not Context.AllowAddressInputInFreeFormat And Not AddressPresentationsIdentical(Context.AddressPresentation, CalculatedPresentation) Then
		Context.Modified = True;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function ContactInformationByAttributeValues(Context)	
	
	Namespace = ContactInformationClientServerCached.Namespace();
	
	Result = XDTOFactory.Create( XDTOFactory.Type(Namespace, "ContactInformation") );
	Result.Comment = Context.Comment;
	
	Result.Content = XDTOFactory.Create( XDTOFactory.Type(Namespace, "Address") );
	Address = Result.Content;
	
	Address.AddressLine1 = TrimAll(Context.AddressLine1);
	Address.AddressLine2 = TrimAll(Context.AddressLine2);
	Address.City = TrimAll(Context.City);
	Address.State = TrimAll(Context.State);
	Address.PostalCode = TrimAll(Context.PostalCode);
	Address.Country = String(Context.Country);
	Result.Presentation = ContactInformationInternal.AddressPresentation(Address, Context.ContactInformationKind);
	
	Return Result;
	
	//////////////////////
	
	//Address.Country = String(Context.Country);
	//If Upper(Context.Country)<>Upper(Context.HomeCountry.Description) Then
	//	Address.Content = Context.ForeignAddressPresentation;
	//	Result.Presentation = ContactInformationInternal.AddressPresentation(Address, Context.ContactInformationKind);
	//	Return Result;
	//EndIf;
	//
	//Address.Content = XDTOFactory.Create( XDTOFactory.Type(Namespace, "AddressUS") );
	//AddressUS = Address.Content;
	//
	//// Settlement
	//If Context.SettlementClassifierCode>0 Then
	//	ContactInformationInternal.SetAddressSettlementByPostalCode(
	//		AddressUS, Context.SettlementClassifierCode);
	//	// Adding (probably not empty) data
	//	For Each KeyValue In Context.SettlementDetails Do
	//		SettlementPart = KeyValue.Value;
	//		CurrentValue = ContactInformationInternal.PropertyByXPathValue(AddressUS, SettlementPart.XPath);
	//		If IsBlankString(CurrentValue) And (Not IsBlankString(SettlementPart.Value)) Then
	//			ContactInformationInternal.SetPropertyByXPath(AddressUS, SettlementPart.XPath, SettlementPart.Value);
	//		EndIf;
	//	EndDo;
	//Else
	//	NoDetailedData = True;
	//	For Each KeyValue In Context.SettlementDetails Do
	//		SettlementPart = KeyValue.Value;
	//		If Not IsBlankString(SettlementPart.Value) Then
	//			NoDetailedData = False;
	//		EndIf;
	//		ContactInformationInternal.SetPropertyByXPath(AddressUS, SettlementPart.XPath, SettlementPart.Value);
	//	EndDo;
	//	If NoDetailedData Then
	//		AddressUS.Settlement = Context.Settlement;
	//	EndIf;
	//EndIf;
	//
	//If Context.StreetClassifierCode>0 Then
	//	ContactInformationInternal.SetAddressStreetByPostalCode(AddressUS, Context.StreetClassifierCode);
	//Else
	//	AddressUS.Street = Context.Street;
	//EndIf;
	//
	//// Buildings
	//TypeValueTable = Type("ValueTable");
	//If TypeOf(Context.AdditionalBuildings)=TypeValueTable Then
	//	BuildingTable = Context.AdditionalBuildings.Copy();
	//Else
	//	BuildingTable = FormDataToValue(Context.AdditionalBuildings, TypeValueTable);
	//EndIf;
	//
	//// Postal code
	//ContactInformationInternal.AddressPostalCode(AddressUS, Context.PostalCode);
	//
	//// Presentation and address input in free format
	//ExpectedPresentation = ContactInformationInternal.AddressPresentation(Address, Context.ContactInformationKind);
	//EnteredPresentation = TrimAll(Context.AddressPresentation);
	//If Context.AllowAddressInputInFreeFormat And Context.AddressPresentationChanged Then
	//	If AddressPresentationsIdentical(EnteredPresentation, ExpectedPresentation) Then
	//		Result.Presentation = ExpectedPresentation;
	//		AddressUS.Unset("Address_by_document");
	//	Else
	//		Result.Presentation           = EnteredPresentation;
	//		AddressUS.Address_to_document = EnteredPresentation;
	//	EndIf;
	//Else
	//	AddressUS.Unset("Address_by_document");
	//	Result.Presentation = ExpectedPresentation;
	//EndIf;
	//
	//Return Result;
EndFunction

// Refills the SettlementDetails structure by the current address data or form attribute data
&AtServerNoContext
Procedure GenerateSettlementDetails(Context, XDTOAddressData=Undefined)
	
	If XDTOAddressData=Undefined And Context.SettlementClassifierCode>0 Then
		// Refilling
		Context.SettlementDetails = ContactInformationInternal.AttributeListSettlement(
			Context.SettlementClassifierCode);
		Return;
	ElsIf TypeOf(XDTOAddressData)=Type("String") Then
		// Parsing attempt
		ClassifierAnalysis = SettlementsByPresentation(XDTOAddressData, Context.HideObsoleteAddresses);
		If ClassifierAnalysis.ChoiceData.Count()=1 Then
			Option = ClassifierAnalysis.ChoiceData[0].Value.Value;
			Context.SettlementDetails = ContactInformationInternal.AttributeListSettlement(Option.Code);
			Return;
		EndIf;
	EndIf;
	
	Context.SettlementDetails = ContactInformationInternal.AttributeListSettlement();
	
	If XDTOAddressData=Undefined Then
		// All data is copied from the form attributes to the predefined settlement details
		For Each KeyValue In Context.SettlementDetails Do
			Value = KeyValue.Value;
			If Value.Predefined Then
				Value.Value = Context.Settlement;
				Break;
			EndIf;
		EndDo;
		Return;
	EndIf;
	
	// From the passed XDTO data
	AddressUS = ContactInformationInternal.HomeCountryAddress(XDTOAddressData);
	If AddressUS<>Undefined Then
		For Each KeyValue In Context.SettlementDetails Do
			Value = KeyValue.Value;
			ValueValue = ContactInformationInternal.PropertyByXPathValue(AddressUS, Value.XPath);
			
			Parts = ContactInformationClientServer.DescriptionAbbreviation(ValueValue);
			Value.Description = Parts.Description;
			Value.Abbr        = Parts.Abbr;
			Value.Value       = ValueValue;
		EndDo;
	EndIf;
		
EndProcedure

&AtServer
Procedure DeleteItemGroup(Group)
	While Group.ChildItems.Count()>0 Do
		Item = Group.ChildItems[0];
		If TypeOf(Item)=Type("FormGroup") Then
			DeleteItemGroup(Item);
		EndIf;
		Items.Delete(Item);
	EndDo;
	Items.Delete(Group);
EndProcedure

&AtClient
Procedure NotifyFillErrors(ErrorList, NotifyAboutNoErrors)
	
	ClearMessages();
	
	ErrorsCount = ErrorList.Count();
	If ErrorsCount = 0 And NotifyAboutNoErrors Then
		// No errors
		ShowMessageBox(, NStr("en='The entered address is valid.'"));
		Return;
	ElsIf ErrorsCount = 1 Then
		ErrorLocation = ErrorList[0].Value;
		If IsBlankString(ErrorLocation) Or ErrorLocation = "/" Then
			// The address contains a single error not bound to a specific field
			ShowMessageBox(, ErrorList[0].Presentation);
			Return;
		EndIf;
	EndIf;
	
	// Sending the field-bound list to user
	For Each Item In ErrorList Do
		CommonUseClientServer.MessageToUser(
			Item.Presentation,,,PathToFormDataByXPath(Item.Value)
		);
	EndDo;
		
EndProcedure

&AtClient
Function PathToFormDataByXPath(XPath) 
	
	If XPath = "Region" Then
		Return "Settlement";
		
	ElsIf XPath = ContactInformationClientServerCached.CountyXPath() Then
		Return "Settlement";
		
	ElsIf XPath = "City" Then
		Return "Settlement";
		
	ElsIf XPath = "District" Then
		Return "Settlement";
		
	ElsIf XPath = "Settlement" Then
		Return "Settlement";
		
	ElsIf XPath = "Street" Then
		Return "Street";
		
	ElsIf XPath = ContactInformationClientServerCached.PostalCodeXPath() Then
		Return "PostalCode";
		
	EndIf;
	
	// Building options
	For Each ListItem In Items.BuildingType.ChoiceList Do
		If XPath = ContactInformationClientServerCached.AdditionalAddressingObjectNumberXPath(ListItem.Value) Then
			Return "Building";
		EndIf;
	EndDo;
	
	// Unit options
	For Each ListItem In Items.DELETE.ChoiceList Do
		If XPath = ContactInformationClientServerCached.AdditionalAddressingObjectNumberXPath(ListItem.Value) Then
			Return "Unit";
		EndIf;
	EndDo;
		
	// Not found
	Return "";
EndFunction

&AtClient
Procedure ClearAddressClient()
	
	Context = FormContextClient();
	ClearAddressServer(Context);
	FormContextClient(Context);
	
	VisualizeChoiceValidity();
	
	Modified = True;
EndProcedure

&AtServer
Procedure ClearAddressServer(Context)
	
	If Context.Country<>Context.HomeCountry Then
		Context.ForeignAddressPresentation = "";
		Return;
	EndIf;
	
	Context.Comment = "";
	
	Context.PostalCode = Undefined;
	
	Context.SettlementClassifierCode = 0;
	Context.SettlementExactMatch     = False;
	Context.Settlement               = "";
	Context.SettlementDetails = ContactInformationInternal.AttributeListSettlement();
	
	Context.StreetClassifierCode = 0;
	Context.StreetExactMatch     = False;
	Context.Street = "";
	
	Context.BuildingType = ContactInformationClientServer.FirstOrEmpty(Items.BuildingType.ChoiceList);
	
	Context.Building = "";
	
	Context.BuildingExactMatch = False;
	
	Context.AdditionalBuildings.Clear();
	
	XDTOContactInformation = ContactInformationByAttributeValues(Context);
	GenerateSettlementDetails(Context, XDTOContactInformation.Content);
	FillAddressPresentation(Context, XDTOContactInformation);
	
	// Clearing data directly in the form, as it is already cleared in the context
	AdditionalBuildings.Clear();
	//PARTIALLY_DELETED
	//DrawAdditionalBuildings();
EndProcedure

&AtClient
Function UnusedAdditionalTableItems(DataTable, SourceItem, MarkerValue)
	Used = New Map;
	Used.Insert(ThisObject[SourceItem.Name], True);
	For Each Row In DataTable Do
		Used.Insert(Row.Type, True);
	EndDo;
	
	Result = New ValueList;
	For Each ListItem In SourceItem.ChoiceList Do
		If Used[ListItem.Value]=Undefined Then
			Result.Add(MarkerValue, ListItem.Value, ListItem.Check, ListItem.Picture);
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

&AtServer
Procedure SetFormUsageKey()
	WindowOptionsKey = String(Country);
	
	Quantity = 0;
	For Each Row In AdditionalBuildings Do
		If Not IsBlankString(Row.Value) Then
			Quantity = Quantity + 1;
		EndIf;
	EndDo;
	WindowOptionsKey = WindowOptionsKey + "/" + Format(Quantity, "NZ=; NG=");
	
	
	WindowOptionsKey = WindowOptionsKey + "/" + Format(Quantity, "NZ=; NG=");
EndProcedure

////////////////////////////////////////////////////////////////////////////////////////////////////

&AtServerNoContext
Function SettlementAutoCompleteResults(Text, HideObsoleteAddresses=False, WarnObsolete=True)
	Return ContactInformationInternal.SettlementAutoCompleteResults(
		Text, HideObsoleteAddresses, WarnObsolete);
EndFunction

&AtServerNoContext
Function SettlementsByPresentation(Text, HideObsoleteAddresses=False, NumberOfRowsToSelect=50)
	Return ContactInformationInternal.SettlementsByPresentation(
		Text, HideObsoleteAddresses, NumberOfRowsToSelect);
EndFunction

&AtServerNoContext
Function StreetAutoCompleteResults(SettlementCode, Text, HideObsoleteAddresses=False, WarnObsolete=True)
	Return ContactInformationInternal.StreetAutoCompleteResults(
		SettlementCode, Text, HideObsoleteAddresses, WarnObsolete);
EndFunction

&AtServerNoContext
Function StreetsByPresentation(SettlementCode, Text, HideObsoleteAddresses=False, NumberOfRowsToSelect=50)
	Return ContactInformationInternal.StreetsByPresentation(
		SettlementCode, Text, HideObsoleteAddresses, NumberOfRowsToSelect);
EndFunction

&AtServerNoContext
Function IsChild(StreetClassifierCode, SettlementClassifierCode)
	Return ContactInformationInternal.IsChild(StreetClassifierCode, SettlementClassifierCode);
EndFunction

// Transforming Form attributes <-> Structure
&AtClient
Function FormContextClient(NewData=Undefined)
	//PARTIALLY_DELETED
 	//Raise ("CHECK ON TEST. 4 attributes deleted");
	//AttributeList = "
	//	|ContactInformationKind,
	//	|Country,
	//	|CountryCode, HomeCountry, HideObsoleteAddresses, PostalCode, AddressPresentation,
	//	|ForeignAddressPresentation, Comment, CommentCopy, Settlement,
	//	|SettlementClassifierCode, SettlementDetails, SettlementExactMatch,
	//	|Street, StreetClassifierCode, StreetExactMatch, BuildingType, Building, BuildingExactMatch,
	//	|AllowAddressInputInFreeFormat, AddressPresentationChanged, Modified
	//	|";
	//PARTIALLY_DELETED	
	//Raise ("CHECK ON TEST. 1 attribute deleted");
	
	AttributeList = "
		|ContactInformationKind,
		|AddressLine1,
		|AddressLine2,
		|City,
		|State,
		|PostalCode,
		|Country, 
		|CountryCode,
		|Comment,
		|HomeCountry
		|";
	
	//CollectionList = "AdditionalBuildings";
	CollectionList = "";
	
	If NewData = Undefined Then
		// Reading
		//Result = New Structure(AttributeList + "," + CollectionList);
		//FillPropertyValues(Result, ThisObject, AttributeList + "," + CollectionList);
		Result = New Structure(AttributeList);
		FillPropertyValues(Result, ThisObject, AttributeList);
		Return Result;
	EndIf;
	
	//FillPropertyValues(ThisObject, NewData, AttributeList, CollectionList);
	//FillCollectionValues(ThisObject, NewData, CollectionList);
	FillPropertyValues(ThisObject, NewData, AttributeList);
	
	Return NewData;
EndFunction

&AtClient
Procedure FillCollectionValues(Target, Source, ListOfProperties)
	For Each KeyValue In New Structure(ListOfProperties) Do
		PropertyName = KeyValue.Key;
		TargetProperty = Target[PropertyName];
		TargetProperty.Clear();
		For Each Value In Source[PropertyName] Do
			FillPropertyValues(TargetProperty.Add(), Value);
		EndDo;
	EndDo;
EndProcedure

// Allows or denies free-format input for items
//
// Parameters:
//    - Mode                 - Boolean - if True, address presentation can be edited; 
//                                       if False, it cannot be edited.
//    - GeneratePresentation - Boolean - optional flag. Set by default.
//
&AtClient
Procedure AddressPresentationInputState(Mode, GeneratePresentation=True)
	//Item = Items.AddressPresentation;
	//
	//Item.TextEdit = Mode;
	//If Mode Then
	//	Item.TextEdit = True;
	//	Item.BackColor = AutoColor;
	//Else
	//	Item.TextEdit = False;
	//	Item.BackColor = FormBackColor;
	//	
	//	If GeneratePresentation Then
	//		Context = FormContextClient();
	//		FillAddressPresentation(Context);
	//		FormContextClient(Context);
	//	EndIf;
	//EndIf;
	//
	//// Other input fields
	//InputGroupStatus(Items.AddressCountry, Not Mode);
	//InputGroupStatus(Items.AddressType, Not Mode);
	//
	//// Mode mark
	////Items.EnterAddressInFreeFormat.Check           = Mode;
	////Items.EnterAddressInFreeFormatAllActions.Check = Mode;
	//
	//Items.AddressPresentationContextMenuEnterAddressInFreeFormat.Check = Mode;
	//
	//// Addresses entered manually cannot be validated
	////If Country = HomeCountry Then
	////	Items.CheckAddressFilled.Enabled = Not Mode;
	////EndIf;
	//
	//// Country remains a control field
	//If Items.Country.Enabled Then
	//	Items.Country.BackColor = MasterFieldBackgroundColor;
	//EndIf;
	//
	//// Setting presentation title and the current input item to ensure correct mode indication
	//If Mode Then
	//	Items.AddressPresentation.TitleLocation = FormItemTitleLocation.Top;
	//	Items.AddressPresentation.Title         = NStr("en='Address in free format'");
	//	
	//	Items.AddressCountry.Representation     = UsualGroupRepresentation.None;
	//	
	//	CurrentItem = Items.AddressPresentation;
	//Else 
	//	Items.AddressPresentation.TitleLocation = FormItemTitleLocation.None;
	//	Items.AddressPresentation.Title         = "";
	//	
	//	Items.AddressCountry.Representation     = UsualGroupRepresentation.NormalSeparation;
	//	
	//	CurrentItem = Items.Settlement;
	//EndIf;
	
EndProcedure

// Specifies whether the group items are accessible.
//
// Parameters:
//    - Group - FormGroup - Item container.
//    - Mode  - Boolean   - Item accessibility flag. If True, access is allowed; if False, not allowed.
//
&AtClient
Procedure InputGroupStatus(Group, Mode)
	
	For Each Item In Group.ChildItems Do
		ItemType = TypeOf(Item);
		If ItemType = Type("FormGroup") Then
			If Item <> Items.ForeignAddress Then
				InputGroupStatus(Item, Mode);
			EndIf;
			
		ElsIf ItemType = Type("FormButton") Then
			If Item = Items.AddObject Then
				//PARTIALLY_DELETED
				//Item.Enabled = Mode And CanAddAdditionalObjects();
			Else
				Item.Enabled = Mode;
			EndIf;
			
		ElsIf ItemType = Type("FormField") And Item.Type = FormFieldType.InputField Then
			If Item <> Items.AddressPresentation Then
				Item.ReadOnly = Not Mode;
				Item.BackColor = ?(Mode, AutoColor, FormBackColor);
			EndIf;
			
		Else 
			Item.Enabled = Mode;
			
		EndIf;
	EndDo;

EndProcedure

// Presentation can only be changed in free-format input mode.
// Therefore, all other fields must be set according to the changed presentation. 
// The Country field is unchanged because free-format input mode is only enabled for domestic addresses.
//
&AtServer
Procedure AddressPresentationOnChangeServer()
	
	// Attempting to parse again
	XDTOContactInfo = ContactInformationInternal.ContactInformationParsing(AddressPresentation, ContactInformationKind);
	
	// Presentation
	ContactInformationInternal.ContactInformationPresentation(XDTOContactInfo, AddressPresentation);
	
	// Comment
	ContactInformationInternal.ContactInformationComment(XDTOContactInfo, Comment);
	
	// And filling in the attributes (with the exception of country and presentation)
	CurrentPresentation = AddressPresentation;
	CurrentCountry      = Country;
	
	ClearAddressServer(ThisObject);
	
	// Free-format input mode may be disabled
	ContactInformationAttibuteValues(ThisObject, XDTOContactInfo);
	
	AddressPresentation = CurrentPresentation;
	Country             = CurrentCountry;
	
	//PARTIALLY_DELETED
	//DrawAdditionalBuildings();
	
	// Forcing free-format input mode
	AllowAddressInputInFreeFormat = True;
	Modified = True;
EndProcedure

// Comparing if two presentations are equivalent
&AtServerNoContext
Function AddressPresentationsIdentical(Val Presentation1, Val Presentation2, Val IgnoreNumberSign=False)
	Return PresentationHash(Presentation1, IgnoreNumberSign)=PresentationHash(Presentation2, IgnoreNumberSign);
EndFunction

&AtServerNoContext
Function PresentationHash(Val Presentation, Val IgnoreNumberSign=False)
	Result = StrReplace(Presentation, Chars.LF, "");
	Result = StrReplace(Result, " ", "");
	If IgnoreNumberSign Then
		Result = StrReplace(Result, "#", "");
	EndIf;
	Return Upper(Result);
EndFunction

&AtClient
Procedure AddressLine1OnChange(Item)
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure AddressLine2OnChange(Item)
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure CityOnChange(Item)
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure StateOnChange(Item)
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure InputAddressFromClassifier(Command)
	
	ContactInformationManagementClient.OpenContactInformationForm_AddressInputClassifier(ThisObject.OnCloseNotifyDescription.AdditionalParameters.Form, ThisObject.OnCloseNotifyDescription.AdditionalParameters.Item);		
	Modified = False;
	ThisObject.OnCloseNotifyDescription = Undefined;
	Close();
	
EndProcedure

#EndRegion