////////////////////////////////////////////////////////////////////////////////////////////////////
// Contact information subsystem
// 
////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Obsolete. Use ContactInformationManagement.PreviousContactInformationXMLFormat instead.
//
Function PreviousContactInformationXMLFormat(Val Data, Val OldFieldContent = False) Export
	Return ContactInformationManagement.PreviousContactInformationXMLFormat(Data, OldFieldContent);
EndFunction

// Obsolete. Use ContactInformationManagement.PreviousContactInformationXMLStructure instead.
//
Function PreviousContactInformationXMLStructure(Val Data, Val ContactInformationKind = Undefined) Export
	Return ContactInformationManagement.PreviousContactInformationXMLStructure(Data, ContactInformationKind);
EndFunction

#EndRegion

#Region InternalInterface

//  Returns a structure wich the ChoiceData field containing the list
//  used for settlement autocompletion by superiority-based hierarchical presentation.
//
//  Parameters:
//      Text                  - String - autocompletion text. 
//      HideObsoleteAddresses - Boolean - flag specifying that obsolete addresses must be excluded
//                                        from the autocompletion list. 
//      WarnObsolete - Boolean - result structure flag. When True, the return value
//                               list contains structures with obsolete data warnings. 
//                               When False, it contains a normal value list.
// Returns:
//      Structure - data search result. Contains fields:
//         * TooMuchData - Boolean - flag specifying that the some of the data
//                                   is not included in the resulting list. 
//         * ChoiceData  - ValueList - autocompletion data.
//
Function SettlementAutoCompleteResults(Text, HideObsoleteAddresses = False, WarnObsolete = True) Export
	Option = ContactInformationClientServer.UsedAddressClassifier();
	
	If Option = "AC" Then
		Return SettlementAutoCompleteResultsAddressClassifier(Text, HideObsoleteAddresses, WarnObsolete, 20);
	EndIf;
	
	// No classifier subsystem
	Return New Structure("TooMuchData, ChoiceData", False, New ValueList);
EndFunction

//  Returns a structure wich the ChoiceData field containing the
//  list used for street autocompletion by superiority-based hierarchical presentation.
//
//  Parameters:
//      SettlementCode        - Number  - classifier code used to limit the autocompletion.
//      Text                  - String - autocompletion text. 
//      HideObsoleteAddresses - Boolean - flag specifying that obsolete addresses must be excluded
//                                        from the autocompletion list. 
//      WarnObsolete - Boolean - result structure flag. When True, the returned value
//                               list contains structures with obsolete data warnings. 
//                               When False, it contains a normal value list.
//
// Returns:
//      Structure - data search result. Contains fields:
//         * TooMuchData - Boolean   - flag specifying that the some
//                                     of the data is not included in the resulting list. 
//         * ChoiceData  - ValueList - autocompletion data.
//
Function StreetAutoCompleteResults(SettlementCode, Text, HideObsoleteAddresses = False, WarnObsolete = True) Export
	Option = ContactInformationClientServer.UsedAddressClassifier();
	
	If Option = "AC" Then
		Return StreetAutoCompleteResultsAddressClassifier(SettlementCode, Text, HideObsoleteAddresses, WarnObsolete, 50);
	EndIf;
	
	// No classifier subsystem
	Return New Structure("TooMuchData, ChoiceData", False, New ValueList);
EndFunction

// Returns a structure wich the ChoiceData field containing the
// list of settlement options by superiority-based hierarchical presentation.
//
//  Parameters:
//      Text                  - String - autocompletion text. 
//      HideObsoleteAddresses - Boolean - flag specifying that obsolete addresses must be excluded
//                                        from the autocompletion list. 
//      NumberOfRowsToSelect  - Number  - result number limit.
//      StreetClarification   - String - street clarification presentation.
//
// Returns:
//      Structure - data search result. Contains the following fields:
//         * TooMuchData - Boolean - flag specifying that the some of the data is not included in the resulting list. 
//         * ChoiceData  - ValueList - autocompletion data.
//
Function SettlementsByPresentation(Val Text, Val HideObsoleteAddresses = False, Val NumberOfRowsToSelect = 50, Val StreetClarification = "") Export
	Option = ContactInformationClientServer.UsedAddressClassifier();
	
	If Option = "AC" Then
		Return SettlementsByPresentationAddressClassifier(Text, HideObsoleteAddresses, NumberOfRowsToSelect, StreetClarification);
	EndIf;
	
	// No classifier subsystem
	Return New Structure("TooMuchData, ChoiceData", False, New ValueList);
EndFunction

// Returns a structure wich the ChoiceData field containing the
// list of settlement options by superiority-based hierarchical presentation.
//
//  Parameters:
//      SettlementCode        - Number  - classifier code used to limit the autocompletion. 
//      Text                  - Text    - autocompletion string. 
//      HideObsoleteAddresses - Boolean - flag specifying that obsolete addresses must be excluded from the autocompletion list. 
//      NumberOfRowsToSelect  - Number  - result number limit.
//
// Returns:
//      Structure - data search result. Contains fields:
//         * TooMuchData - Boolean - flag specifying that the some of the data is not included in the resulting list. 
//         * ChoiceData  - ValueList - autocompletion data.
//
Function StreetsByPresentation(SettlementCode, Text, HideObsoleteAddresses = False, NumberOfRowsToSelect = 50) Export
	Option = ContactInformationClientServer.UsedAddressClassifier();
	
	If Option = "AC" Then
		Return StreetsByPresentationAddressClassifier(SettlementCode, Text, HideObsoleteAddresses, NumberOfRowsToSelect);
	EndIf;
	
	// No classifier subsystem
	Return New Structure("TooMuchData, ChoiceData", False, New ValueList);    
EndFunction

//  Returns building type options.
Function DataOptionsHouse() Export
	
	Return New Structure("TypeOptions, CanPickValues", 
		ContactInformationClientServerCached.AddressingObjectNamesByType(1), False);
		
EndFunction
	
Function DataOptionsUnit() Export

	Return New Structure("TypeOptions, CanPickValues", 
		ContactInformationClientServerCached.AddressingObjectNamesByType(2), False);	

EndFunction // DataOptionunit()()

 	

//PARTIALLY_DELETED
//Raise ("CHECK ON TEST. 2 functions deleted");

//  Returns the flag specifying whether the object is included in the parent.
//
//  Parameters:
//      ObjectCode - Number - classifier code of the object. 
//      ParentCode - Number - classifier code of the parent.
//
// Returns:
//      Boolean - check result.
//
Function IsChild(ObjectCode, ParentCode) Export
	Option = ContactInformationClientServer.UsedAddressClassifier();
	
	If Option = "AC" Then
		Return IsChildAddressClassifier(ObjectCode, ParentCode);
	EndIf;
	
	// No classifier subsystem
	Return Undefined;
EndFunction

//  Returns state code by its full name.
//
//  Parameters:
//      StateDescription - String - full name of the state, including abbreviation.
//
// Returns:
//      String - two-character state code. Empty string if the name could not be determined. 
//      Undefined - if no address classifier subsystems are available.
// 
Function StateCode(Val FullDescr) Export
	Option = ContactInformationClientServer.UsedAddressClassifier();
	
	If Option = "AC" Then
		Return StateCodeAddressClassifier(FullDescr);
	EndIf;
	
	// No classifier subsystem
	Return Undefined;
EndFunction

//  Returns state name by its code.
//
//  Parameters:
//      Code - String, Number - state code.
//
// Returns:
//      String - full name of the state, including abbreviation. 
//      Undefined - if no address classifier subsystems are available.
// 
Function CodeState(Val Code) Export
	Option = ContactInformationClientServer.UsedAddressClassifier();
	
	If Option = "AC" Then
		Return CodeStateAddressClassifier(Code);
	EndIf;
	
	// No classifier subsystem
	Return Undefined;
EndFunction

//  Gets the full state list.
//
// Returns:
//      ValueTable - all states. Contains columns:
//          * Code         - Number  - state code. 
//          * Description  - String - part of state description. 
//          * Abbreviation - String - part of state description. 
//          * Presentation - String - state description. 
//      Undefined - if no address classifier subsystems are available.
// 
Function AllStates() Export
	Option = ContactInformationClientServer.UsedAddressClassifier();
	
	If Option = "AC" Then
		Return AllStatesAddressClassifier();
	EndIf;
	
	// No classifier subsystem
	Return Undefined;
EndFunction

//  Returns a structure describing a settlement according
//  to the superiority-based hierarchy for the current address classifier. 
//  Structure key names may vary depending on the classifier.
//
//  Parameters:
//      Code - Number - object classifier code (optional). If specified, the structure is filled with data from this object.
//
// Returns:
//      Structure - settlement description.
//
Function AttributeListSettlement(Code = Undefined) Export
	Option = ContactInformationClientServer.UsedAddressClassifier();
	
	If Option = "AC" Then
		Return AttributeListSettlementAddressClassifier(Code);
	EndIf;
	
	// No classifier subsystem
	Return New Structure;
EndFunction

//  Returns a structure describing a street
//  according to the superiority-based hierarchy for the current address classifier. 
//  Structure key names may vary depending on the classifier.
//
//  Parameters:
//      Code - Number - object classifier code (optional). If specified, the structure is filled with data from this object.
//
// Returns:
//      Structure - settlement description.

Function AttributeListStreet(Code = Undefined) Export
	Option = ContactInformationClientServer.UsedAddressClassifier();
	
	If Option = "AC" Then
		Return AttributeListStreetAddressClassifier(Code);
	EndIf;
	
	// No classifier subsystem
	Return New Structure;
EndFunction

//  Returns classifier code of the object represented in the fields.
//
//  Parameters:
//      AddressParts - Structure - description of the address parts. 
//      HideObsolete - Boolean   - flag specifying that the obsolete data must be hidden.
//
// Returns:
//      Number - classifier code.
//
Function SettlementCodeByAddressParts(AddressParts, HideObsolete = False) Export
	Option = ContactInformationClientServer.UsedAddressClassifier();
	
	If Option = "AC" Then
		Return ObjectCodeByAddressPartsAddressClassifier(AddressParts, HideObsolete);
	EndIf;
	
	// No classifier subsystem
	Return Undefined;
EndFunction

//  Returns an address item autompletion list (fuzzy search). The list length is limited to 50 records.
//
//  Parameters:
//      Text            - String    - text entered in the field. 
//      AddressPartCode - Arbitrary - ID of the processed address part, may vary depending on the classifier. 
//      AddressParts    - Arbitrary - values of other address parts, may vary depending on the classifier. 
//      WarnObsolete    - Boolean   - list structure flag. 
//                                    True when the list contains structures with obsolete data warnings. 
//                                    False when the list is a standard value list.
//
// Returns:
//     ValueList - result for autocompletion.
//
Function AddressItemAutoCompleteList(Text, AddressPartCode, AddressParts, WarnObsolete) Export
	Option = ContactInformationClientServer.UsedAddressClassifier();
	
	If Option = "AC" Then
		Return AddressItemAutoCompleteListAddressClassifier(Text, AddressPartCode, AddressParts, WarnObsolete, 50);
	EndIf;
	
	// No classifier subsystem
	Return New ValueList;
EndFunction

//  Returns a list of options for an entered address item.
//
//  Parameters:
//      Text             - String   - text entered in the field. 
//      AddressPartCode - Arbitrary - ID of the processed address part, may vary depending on the classifier. 
//      AddressParts    - Arbitrary - values for other address parts, may vary depending on the classifier.
//      NumberOfRowsToSelect  - Number        - limit for the number of returned rows.
//
// Returns:
//     ValueList - result for autocompletion.
//
Function AddressItemOptionListByText(Text, AddressPartCode, AddressParts, NumberOfRowsToSelect = 50) Export
	Option = ContactInformationClientServer.UsedAddressClassifier();
	
	If Option = "AC" Then
		Return AddressItemOptionListByTextAddressClassifier(Text, AddressPartCode, AddressParts, NumberOfRowsToSelect);
	EndIf;
	
	// No classifier subsystem
	Return New ValueList;
EndFunction

// Returns classifier codes by postal code.
//
// Parameters:
//     Index - String - postal code.
//
//     AdditionalSearchParameters - Structure - describes the search settings. Contains a set of optional fields:
//         HideObsolete         - Boolean - flag specifying that obsolete addresses must be excluded from the list. The default value is False. 
//         NumberOfRowsToSelect - Number  - limit for the number of returned rows, 0 - no limit. The default value is 0.
//
// Returns:
//     Structure -  found options. Contains fields:
//         * TooMuchData            - Boolean - True if the number of found records exceeds the NumberOfRowsToSelect limit.
//         * PresentationCommonPart - String - Common part of the address presentations.
//         * Data                   - ValueTable - Contains data for selection. Columns:
//                                         ** Obsolete      - Boolean - flag specifying that
//                                             a data string is obsolete. 
//                                         ** PostalCode    - String - postal code corresponding
//                                             to the address. 
//                                         ** Code          - Number  - classifier code used to search 
//                                             options by postal code.
//                                          ** Presentation - String - option presentation.
//
Function ClassifierAddressesByPostalCode(Val Index, Val AdditionalSearchParameters = Undefined) Export
	Option = ContactInformationClientServer.UsedAddressClassifier();
	
	If Option = "AC" Then
		Return AddressesByClassifierPostalCode(Index, AdditionalSearchParameters);
	EndIf;
	
	// No classifier subsystem
	Return New Structure("Data, PresentationCommonPart, TooMuchData", New ValueTable, "", False);
EndFunction

////////////////////////////////////////////////////////////////////////////////////////////////////
// Common internal
//

// Transforms XDTO contact information to XML string.
//
//  Parameters:
//      XDTOInformationObject - XDTODataObject - contact information.
//
// Returns:
//      String - conversion result.
//
Function ContactInformationSerialization(XDTOInformationObject) Export
	Write = New XMLWriter;
	Write.SetString(New XMLWriterSettings(, , False, False, ""));
	
	If XDTOInformationObject <> Undefined Then
		XDTOFactory.WriteXML(Write, XDTOInformationObject);
	EndIf;
	
	Return StrReplace(Write.Close(), Chars.LF, "&#10;");
EndFunction

// Transforms an XML string to XDTO contact information object.
//
//  Parameters:
//      Text          - String - XML string. 
//      ExpectedKind  - CatalogRef.ContactInformationKinds, EnumRef.ContactInformationTypes, Structure. 
//      ReadResults   - Structure - target for additional fields:
//                          * ErrorText - String - description of read procedure errors. Value returned by the
//                             function is of valid type but unfilled.
//
Function ContactInformationDeserialization(Val Text, Val ExpectedKind = Undefined, ReadResults = Undefined) Export
	
	ExpectedType = ContactInformationManagement.ContactInformationKindType(ExpectedKind);
	
	EnumAddress      = Enums.ContactInformationTypes.Address;
	EnumEmailAddress = Enums.ContactInformationTypes.EmailAddress;
	EnumWebpage      = Enums.ContactInformationTypes.WebPage;
	EnumPhone        = Enums.ContactInformationTypes.Phone;
	EnumFax          = Enums.ContactInformationTypes.Fax;
	EnumOther        = Enums.ContactInformationTypes.Other;
	
	Namespace = ContactInformationClientServerCached.Namespace();
	If ContactInformationClientServer.IsXMLContactInformation(Text) Then
		XMLReader = New XMLReader;
		XMLReader.SetString(Text);
		
		ErrorText = Undefined;
		Try
			Result = XDTOFactory.ReadXML(XMLReader, XDTOFactory.Type(Namespace, "ContactInformation"));
		Except
			// Invalid XML format
			WriteLogEvent(ContactInformationInternalCached.EventLogMessageText(),
				EventLogLevel.Error, , Text, DetailErrorDescription(ErrorInfo())
			);
			
			If TypeOf(ExpectedKind) = Type("CatalogRef.ContactInformationKinds") Then
				ErrorText = StrReplace(NStr("en = 'Invalid contact information XML format for ""%1"". The field values are cleared.'"),
					"%1", String(ExpectedKind));
			Else
				ErrorText = NStr("en = 'Invalid contact information XML format. The field values are cleared.'");
			EndIf;
		EndTry;
		
		If ErrorText = Undefined Then
			// Checking for type match
			TypeFound = ?(Result.Content = Undefined, Undefined, Result.Content.Type());
			If ExpectedType = EnumAddress And TypeFound <> XDTOFactory.Type(Namespace, "Address") Then
				ErrorText = NStr("en = 'Contact information deserialization error. Address is expected.'");
			ElsIf ExpectedType = EnumEmailAddress And TypeFound <> XDTOFactory.Type(Namespace, "Email") Then
				ErrorText = NStr("en = 'Contact information deserialization error. Email address is expected.'");
			ElsIf ExpectedType = EnumWebpage And TypeFound <> XDTOFactory.Type(Namespace, "Website") Then
				ErrorText = NStr("en = 'Contact information deserialization error. Webpage is expected.'");
			ElsIf ExpectedType = EnumPhone And TypeFound <> XDTOFactory.Type(Namespace, "PhoneNumber") Then
				ErrorText = NStr("en = 'Contact information deserialization error. Phone number is expected.'");
			ElsIf ExpectedType = EnumFax And TypeFound <> XDTOFactory.Type(Namespace, "FaxNumber") Then
				ErrorText = NStr("en = 'Contact information deserialization error. Phone number is expected.'");
			ElsIf ExpectedType = EnumOther And TypeFound <> XDTOFactory.Type(Namespace, "Others") Then
				ErrorText = NStr("en = 'Contact information deserialization error. Other data is expected.'");
			EndIf;
		EndIf;
		
		If ErrorText = Undefined Then
			// Reading was successful
			Return Result;
		EndIf;
		
		// Checking for errors, returning detailed information
		If ReadResults = Undefined Then
			Raise ErrorText;
		ElsIf TypeOf(ReadResults) <> Type("Structure") Then
			ReadResults = New Structure;
		EndIf;
		ReadResults.Insert("ErrorText", ErrorText);
		
		// Returning an empty object
		Text = "";
	EndIf;
	
	If TypeOf(Text) = Type("ValueList") Then
		Presentation = "";
		IsNew = Text.Count() = 0;
	Else
		Presentation = String(Text);
		IsNew = IsBlankString(Text);
	EndIf;
	
	Result = XDTOFactory.Create(XDTOFactory.Type(Namespace, "ContactInformation"));
	
	// Parsing
	If ExpectedType = EnumAddress Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Address"));
		Else
			Result = AddressDeserialization(Text, Presentation, ExpectedType);
		EndIf;
		
	ElsIf ExpectedType = EnumPhone Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "PhoneNumber"));
		Else
			Result = PhoneDeserialization(Text, Presentation, ExpectedType)
		EndIf;
		
	ElsIf ExpectedType = EnumFax Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "FaxNumber"));
		Else
			Result = FaxDeserialization(Text, Presentation, ExpectedType)
		EndIf;
		
	ElsIf ExpectedType = EnumEmailAddress Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Email"));
		Else
			Result = OtherContactInformationDeserialization(Text, Presentation, ExpectedType)
		EndIf;
		
	ElsIf ExpectedType = EnumWebpage Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Website"));
		Else
			Result = OtherContactInformationDeserialization(Text, Presentation, ExpectedType)
		EndIf;
		
	ElsIf ExpectedType = EnumOther Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Others"));
		Else
			Result = OtherContactInformationDeserialization(Text, Presentation, ExpectedType)    
		EndIf;
		
	Else
		Raise NStr("en = 'Contact information deserialization error. Expected type is not specified.'");
	EndIf;
	
	Return Result;
EndFunction

// Parses a contact information presentation and returns an XDTO object.
//
//  Parameters:
//      Text         - String - XML string. 
//      ExpectedKind - CatalogRef.ContactInformationKinds, EnumRef.ContactInformationTypes, Structure.
//
// Returns:
//      XDTODataObject - contact information.
//
Function ContactInformationParsing(Text, ExpectedKind) Export
	
	ExpectedType = ContactInformationManagement.ContactInformationKindType(ExpectedKind);
	
	If ExpectedType = Enums.ContactInformationTypes.Address Then
		Return AddressDeserialization("", Text, ExpectedType);
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.EmailAddress Then
		Return OtherContactInformationDeserialization("", Text, ExpectedType);
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.WebPage Then
		Return OtherContactInformationDeserialization("", Text, ExpectedType);
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Phone Then
		Return PhoneDeserialization("", Text, ExpectedType);
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Fax Then
		Return FaxDeserialization("", Text, ExpectedType);
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Other Then
		Return OtherContactInformationDeserialization("", Text, ExpectedType);
		
	EndIf;
	
	Return Undefined;
EndFunction

// Parses a contact information presentation and returns an XML string.
//
//  Parameters:
//      Text         - String - XML string. 
//      ExpectedKind - CatalogRef.ContactInformationKinds, EnumRef.ContactInformationTypes, Structure.
//
// Returns:
//      String - contact information in XML format.
//
Function ContactInformationParsingXML(Text, ExpectedKind) Export
	Return ContactInformationSerialization(
		ContactInformationParsing(Text, ExpectedKind));
EndFunction

// Transforms a string to an XDTO contact information address object.
//
//  Parameters:
//      FieldValues  - String - serialized information, field values. 
//      Presentation - String - superiority-based presentation. 
//                      Used for parsing purposes if FieldValues is empty. 
//      ExpectedType - EnumRef.ContactInformationTypes - optional type used for control purposes.
//
//  Returns:
//      XDTODataObject  - contact information.
//
Function AddressDeserialization(Val FieldValues, Val Presentation = "", Val ExpectedType = Undefined) Export
	ValueType = TypeOf(FieldValues);
	
	ParseByFields = ValueType = Type("ValueList") Or ValueType = Type("Structure") 
	                   Or ( ValueType = Type("String") And Not IsBlankString(FieldValues) );
	
	If ParseByFields Then
		// Parsing the field values
		Return AddressDeserializationCommon(FieldValues, Presentation, ExpectedType);
	EndIf;
	
	// Parsing the classifier presentation
	Option = ContactInformationClientServer.UsedAddressClassifier();
	
	If Option = "AC" Then
		Return AddressDeserializationByAddressClassifierPresentation(Presentation);
	EndIf;
	
	// No classifier subsystem
	
	// Empty object with presentation
	Namespace = ContactInformationClientServerCached.Namespace();
	Result = XDTOFactory.Create(XDTOFactory.Type(Namespace, "ContactInformation"));
	Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Address"));
	Result.Presentation = Presentation;
	
	Return Result;
EndFunction  

// Transforms a string to an XDTO phone number contact information.
//
//      FieldValues  - String - serialized information, field values. 
//      Presentation - String - superiority-based presentation. 
//                      Used for parsing purposes if FieldValues is empty. 
//      ExpectedType - EnumRef.ContactInformationTypes - optional type used for control purposes.
//
//  Returns:
//      XDTODataObject  - contact information.
//
Function PhoneDeserialization(FieldValues, Presentation = "", ExpectedType = Undefined) Export
	Return PhoneFaxDeserialization(FieldValues, Presentation, ExpectedType);
EndFunction

// Transforms a string to an XDTO fax number contact information.
//
//      FieldValues  - String - serialized information, field values. 
//      Presentation - String - superiority-based presentation. 
//                      Used for parsing purposes if FieldValues is empty.
//      ExpectedType - EnumRef.ContactInformationTypes - optional type used for control purposes.
//
//  Returns:
//      XDTODataObject  - contact information.
//
Function FaxDeserialization(FieldValues, Presentation = "", ExpectedType = Undefined) Export
	Return PhoneFaxDeserialization(FieldValues, Presentation, ExpectedType);
EndFunction

// Transforms a string to other XDTO contact information.
//
//      FieldValues  - String - serialized information, field values. 
//      Presentation - String - superiority-based presentation. 
//                      Used for parsing purposes if FieldValues is empty. 
//      ExpectedType - EnumRef.ContactInformationTypes - optional type used for control purposes.
//
//  Returns:
//      XDTODataObject  - contact information.
//
Function OtherContactInformationDeserialization(FieldValues, Presentation = "", ExpectedType = Undefined) Export
	
	If ContactInformationClientServer.IsXMLContactInformation(FieldValues) Then
		// Common format of contact information
		Return ContactInformationDeserialization(FieldValues, ExpectedType);
	EndIf;
	
	Namespace = ContactInformationClientServerCached.Namespace();
	Result = XDTOFactory.Create(XDTOFactory.Type(Namespace, "ContactInformation"));
	Result.Presentation = Presentation;
	
	If ExpectedType = Enums.ContactInformationTypes.EmailAddress Then
		Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Email"));
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.WebPage Then
		Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Website"));
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Other Then
		Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Others"));
		
	ElsIf ExpectedType <> Undefined Then
		Raise NStr("en = 'Contact information deserialization error. Another type is expected.'");
		
	EndIf;
	
	Result.Content.Value = Presentation;
	
	Return Result;
	
EndFunction

//  Reads and sets the contact information presentation. The object may vary.
//
//  Parameters:
//      XDTOInformation - XDTODataObject, String - contact information. 
//      NewValue        - String - new presentation to be set in XDTOInformation (optional).
//
//  Returns:
//      String - new value.

Function ContactInformationPresentation(XDTOInformation, NewValue = Undefined) Export
	SerializationRequired = TypeOf(XDTOInformation) = Type("String");
	If SerializationRequired And Not ContactInformationClientServer.IsXMLContactInformation(XDTOInformation) Then
		// Old version of field values. Returning the string.
		Return XDTOInformation;
	EndIf;
	
	XDTODataObject = ?(SerializationRequired, ContactInformationDeserialization(XDTOInformation), XDTOInformation);
	If NewValue <> Undefined Then
		XDTODataObject.Presentation = NewValue;
		If SerializationRequired Then
			XDTOInformation = ContactInformationSerialization(XDTODataObject);
		EndIf;
	EndIf;
	
	Return XDTODataObject.Presentation
EndFunction

//  Reads and sets the contact information comment.
//
//  Parameters:
//      XDTOInformation - XDTODataObject, String - contact information. 
//      NewValue  - String - new comment to be set in XDTOInformation (optional).
//
//  Returns:
//      String - new value.
//
Function ContactInformationComment(XDTOInformation, NewValue = Undefined) Export
	SerializationRequired = TypeOf(XDTOInformation) = Type("String");
	If SerializationRequired And Not ContactInformationClientServer.IsXMLContactInformation(XDTOInformation) Then
		// Old version of field values. The comment is not supported.
		Return "";
	EndIf;
	
	XDTODataObject = ?(SerializationRequired, ContactInformationDeserialization(XDTOInformation), XDTOInformation);
	If NewValue <> Undefined Then
		XDTODataObject.Comment = NewValue;
		If SerializationRequired Then
			XDTOInformation = ContactInformationSerialization(XDTODataObject);
		EndIf;
	EndIf;
	
	Return XDTODataObject.Comment;
EndFunction

//  Determines and sets the flag specifying whether the address is entered in free format. 
//  Non-empty value of Address_to_document field is used as the flag value.
//
//  Parameters:
//      XDTOInformation - XDTODataObject, String - Contact information. 
//      NewValue        - Boolean - new value to be set (optional).
//
//  Returns:
//      Boolean - new value.
//
Function AddressEnteredInFreeFormat(XDTOInformation, NewValue = Undefined) Export
	SerializationRequired = TypeOf(XDTOInformation) = Type("String");
	If SerializationRequired And Not ContactInformationClientServer.IsXMLContactInformation(XDTOInformation) Then
		// Old version of field values. Not supported.
		Return False;
	EndIf;
	
	XDTODataObject = ?(SerializationRequired, ContactInformationDeserialization(XDTOInformation), XDTOInformation);
	If Not IsDomesticAddress(XDTODataObject) Then
		// Not supported
		Return False;
	EndIf;
	
	AddressUS = XDTODataObject.Content.Content;
	If TypeOf(NewValue) <> Type("Boolean") Then
		// Reading
		Return Not IsBlankString(AddressUS.Address_by_document);
	EndIf;
		
	// Setting values
	If NewValue Then
		AddressUS.Address_to_document = XDTODataObject.Presentation;
	Else
		AddressUS.Unset("Address_by_document");
	EndIf;
	
	If SerializationRequired Then
		XDTOInformation = ContactInformationSerialization(XDTODataObject);
	EndIf;
	Return NewValue;
EndFunction

//  Generates and returns a contact information presentation.
//
//  Parameters:
//      Information     - XDTODataObject, String - contact information. 
//      InformationKind - CatalogRef.ContactInformationKinds, Structure - presentation generation parameters.
//
//  Returns:
//      String - generated presentation.
//
Function GenerateContactInformationPresentation(Information, InformationKind) Export
	
	If TypeOf(Information) = Type("XDTODataObject") Then
		If Information.Content = Undefined Then
			// Using available information "as is"
			Return Information.Presentation;
		EndIf;
		
		Namespace = ContactInformationClientServerCached.Namespace();
		InformationType    = Information.Content.Type();
		If InformationType = XDTOFactory.Type(Namespace, "Address") Then
			Return AddressPresentation(Information.Content, InformationKind);
			
		ElsIf InformationType = XDTOFactory.Type(Namespace, "PhoneNumber") Then
			Return PhonePresentation(Information.Content, InformationKind);
			
		ElsIf InformationType = XDTOFactory.Type(Namespace, "FaxNumber") Then
			Return PhonePresentation(Information.Content, InformationKind);
			
		EndIf;
		
		// Placeholder for other types
		If TypeOf(InformationType) = Type("XDTODataObject") And InformationType.Properties.Get("Value") <> Undefined Then
			Return String(Information.Content.Value);
		EndIf;
		
		Return String(Information.Content);
	EndIf;
	
	// Old format, or new deserialized format
	If InformationKind.Type = Enums.ContactInformationTypes.Address Then
		NewInfo = AddressDeserialization(Information,,Enums.ContactInformationTypes.Address);
		Return GenerateContactInformationPresentation(NewInfo, InformationKind);
	EndIf;
	
	Return TrimAll(Information);
EndFunction

//  Returns the flag specifying whether the passed address is domestic.
//
//  Parameters:
//      XDTOAddress - XDTODataObject - contact information or address XDTO object.
//
//  Returns:
//      Boolean - check result.
//
Function IsDomesticAddress(XDTOAddress) Export
	Return HomeCountryAddress(XDTOAddress) <> Undefined;
EndFunction

//  Returns an extracted XDTO object for domestic addresses, or Undefined for foreign addresses.
//
//  Parameters:
//      InformationObject - XDTODataObject - contact information or address XDTO object.
//
//  Returns:
//      XDTODataObject - domestic address.
//      Undefined - foreign address
//
Function HomeCountryAddress(InformationObject) Export
	Result = Undefined;
	XDTOType   = Type("XDTODataObject");
	
	If TypeOf(InformationObject) = XDTOType Then
		Namespace = ContactInformationClientServerCached.Namespace();
		
		If InformationObject.Type() = XDTOFactory.Type(Namespace, "ContactInformation") Then
			Address = InformationObject.Content;
		Else
			Address = InformationObject;
		EndIf;
		
		If TypeOf(Address) = XDTOType And Address.Type() = XDTOFactory.Type(Namespace, "Address") Then
			Address = Address.Content;
		EndIf;
		
		If TypeOf(Address) = XDTOType And Address.Type() = XDTOFactory.Type(Namespace, "AddressUS") Then
			Result = Address;
		EndIf;
	EndIf;
	
	Return Result;
EndFunction

//  Reads and sets the address postal code.
//
//  Parameters:
//      XDTOAddress - XDTODataObject - contact information or address XDTO object. 
//      NewValue    - String - value to be set.
//
//  Returns:
//      String - postal code.
//
Function AddressPostalCode(XDTOAddress, NewValue = Undefined) Export
	
	If XDTOAddress.Type().Name = "Address" And XDTOAddress.AddressLine1	<> Undefined And XDTOAddress.AddressLine2 <> Undefined Then
		Return XDTOAddress.PostalCode;
	EndIf;	
	
	AddressUS = HomeCountryAddress(XDTOAddress);
	If AddressUS = Undefined Then
		Return Undefined;
	EndIf;
	
	If NewValue = Undefined Then
		// Reading
		Result = AddressUS.Get( ContactInformationClientServerCached.PostalCodeXPath() );
		If Result <> Undefined Then
			Result = Result.Value;
		EndIf;
		Return Result;
	EndIf;
	
	// Writing
	PostalCodeCode = ContactInformationClientServerCached.PostalCodeSerializationCode();
	
	PostalCodeRecord = AddressUS.Get( ContactInformationClientServerCached.PostalCodeXPath() );
	If PostalCodeRecord = Undefined Then
		PostalCodeRecord = AddressUS.AdditionalAddressItem.Add( XDTOFactory.Create(XDTOAddress.AdditionalAddressItem.OwningProperty.Type) );
		PostalCodeRecord.AddressItemType = PostalCodeCode;
	EndIf;
	
	PostalCodeRecord.Value = NewValue;
	Return NewValue;
EndFunction

Function AddressAddressLine1(XDTOAddress) Export
	Return XDTOAddress.AddressLine1;
EndFunction

Function AddressAddressLine2(XDTOAddress) Export
	Return XDTOAddress.AddressLine2;
EndFunction

Function AddressCity(XDTOAddress) Export
	Return XDTOAddress.City;
EndFunction

Function AddressState(XDTOAddress) Export
	Return XDTOAddress.State;
EndFunction

//  Returns the address postal code, based on the classifier data.
//
//  Parameters:
//      XDTOAddress - XDTODataObject - contact information or address XDTO object.
//
//  Returns:
//      String - postal code. 
//      Undefined - postal code is not found, or a foreign address is found.
//
Function GetAddressPostalCode(XDTOAddress) Export
	
	Namespace = ContactInformationClientServerCached.Namespace();
	
	If XDTOAddress.Type() = XDTOFactory.Type(Namespace, "Address") Then
		XDTOHomeCountryAddress = XDTOAddress.Content;
	Else 
		XDTOHomeCountryAddress = XDTOAddress;
	EndIf;
	
	If XDTOHomeCountryAddress = Undefined Or XDTOHomeCountryAddress.Type() <> XDTOFactory.Type(Namespace, "AddressUS") Then
		Return Undefined;	// Foreign or empty address
	EndIf;
	
	Option = ContactInformationClientServer.UsedAddressClassifier();
	
	If Option = "AC" Then
		Return DetermineAddressPostalCodeAddressClassifier(XDTOHomeCountryAddress);
	EndIf;
	
	// No classifier subsystem
	Return Undefined;
EndFunction

//  Reads and sets the address county.
//
//  Parameters:
//      XDTOAddress - XDTODataObject - Contact information or address XDTO object. 
//      NewValue    - String - value to be set.
//
//  Returns:
//      String - new value.
//
Function AddressCounty(XDTOAddress, NewValue = Undefined) Export
	
	If NewValue = Undefined Then
		// Reading
		Result = Undefined;
		Namespace = ContactInformationClientServerCached.Namespace();
		
		XDTOType = XDTOAddress.Type();
		If XDTOType = XDTOFactory.Type(Namespace, "AddressUS") Then
			AddressUS = XDTOAddress;
		Else
			AddressUS = XDTOAddress.Content;
		EndIf;
		
		If TypeOf(AddressUS) = Type("XDTODataObject") Then
			Return PropertyByXPathValue(AddressUS, ContactInformationClientServerCached.CountyXPath() );
		EndIf;
		
		Return Undefined;
	EndIf;
	
	// Writing
	Write = CountyMunicipalEntity(XDTOAddress);
	Write.County = NewValue;
	Return NewValue;
EndFunction

//  Reads and sets address unit numbers.
//
//  Parameters:
//      XDTOAddress     - XDTODataObject - Contact information or address XDTO object. 
//      NewValue - Structure  - value to be set. The following fields are expected:
//                          * Units - ValueTable with the following columns:
//                                ** Type  - String - internal classifier type for additional address objects. 
//                                   Example: Unit.
//                                ** Value - String  - building number, apartment number, and so on.
//
//  Returns:
//      Structure - current data. Contains fields:
//          * Units - ValueTable with the following columns:
//                        ** Type         - String - internal classifier type for additional address objects. 
//                                          Example: Unit. 
//                        ** Abbreviation - String - abbreviated name to be used in presentations.
//                        ** Value        - String - building number, apartment number, and so on.
//                        ** XPath        - String - path to object value.
//
Function BuildingAddresses(XDTOAddress, NewValue = Undefined) Export
	
	Result = New Structure("Buildings", 
		ValueTable("Type, Value, Abbr, XPath, Kind", "Type, Kind"));
	
	AddressUS = HomeCountryAddress(XDTOAddress);
	If AddressUS = Undefined Then
		Return Result;
	EndIf;
	
	If NewValue <> Undefined Then
		// Writing
		If NewValue.Property("Buildings") Then
			For Each Row In NewValue.Buildings Do
				InsertUnit(XDTOAddress, Row.Type, Row.Value);
			EndDo;
		EndIf;
		Return NewValue
	EndIf;
	
	// Reading
	For Each AdditionalItem In AddressUS.AdditionalAddressItem Do
		If AdditionalItem.Number <> Undefined Then
			ObjectCode = AdditionalItem.Number.Type;
			ObjectType = ContactInformationClientServerCached.ObjectTypeBySerializationCode(ObjectCode);
			If ObjectType <> Undefined Then
				Kind = ObjectType.Type;
				If Kind = 1 Or Kind = 2 Then
					NewRow = Result.Buildings.Add();
				Else
					NewRow = Undefined;
				EndIf;
				If NewRow <> Undefined Then
					NewRow.Type        = ObjectType.Description;
					NewRow.Value   = AdditionalItem.Number.Value;
					NewRow.Abbr = ObjectType.Abbr;
					NewRow.XPath  = ContactInformationClientServerCached.AdditionalAddressingObjectNumberXPath(NewRow.Type);
					NewRow.Kind        = Kind;
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
	Result.Buildings.Sort("Kind");
	
	Return Result;
EndFunction

//  Sets settlement field values in the address.
//  
//  Parameters:
//      XDTOAddress    - XDTODataObject - domestic address. 
//      ClassifierCode - Number - full code, may vary depending on the classifier.
//
Procedure SetAddressSettlementByPostalCode(XDTOAddress, ClassifierCode) Export
	Option = ContactInformationClientServer.UsedAddressClassifier();
	
	If Option = "AC" Then
		SetAddressSettlementByPostalCodeAddressClassifier(XDTOAddress, ClassifierCode);
	EndIf;
	
EndProcedure

//  Sets street field values.
//  
//  Parameters:
//      XDTOAddress    - XDTODataObject  - domestic address.
//      ClassifierCode - Number - full code, may vary depending on the classifier.
//
Procedure SetAddressStreetByPostalCode(XDTOAddress, ClassifierCode) Export
	Option = ContactInformationClientServer.UsedAddressClassifier();
	
	If Option = "AC" Then
		SetAddressStreetByPostalCodeAddressClassifier(XDTOAddress, ClassifierCode);
	EndIf;
	
	// No classifier subsystem
EndProcedure

//  Returns the superiority-based presentation for a settlement.
//
//  Parameters:
//      AddressObj - XDTODataObject - domestic address.
//
//  Returns:
//      String - presentation.
//
Function SettlementPresentation(AddressObj) Export
	
	AddressUS = HomeCountryAddress(AddressObj);
	If AddressUS = Undefined Then
		Return "";
	EndIf;
	
	If AddressUS.CountyMunicipalEntity = Undefined Then
		County = "";
	ElsIf AddressUS.CountyMunicipalEntity.County <> Undefined Then
		County = AddressUS.CountyMunicipalEntity.County;
	ElsIf AddressUS.CountyMunicipalEntity.MunicipalEntity <> Undefined Then
		County = ContactInformationClientServer.FullDescr(
			AddressUS.CountyMunicipalEntity.MunicipalEntity.MunicipalEntity2, "",
			AddressUS.CountyMunicipalEntity.MunicipalEntity.MunicipalEntity1, "");
	Else
		County = "";;
	EndIf;
	
	Return ContactInformationClientServer.FullDescr(
		AddressUS.Settlement, "",
		AddressUS.City,  "",
		County, "",
		AddressUS.Region, "");
	
EndFunction    

//  Returns the superiority-based presentation for a settlement.
//
//  Parameters:
//      AddressObj - XDTODataObject - domestic address.
//
//  Returns:
//      String - presentation.
//
Function StreetPresentation(AddressObj) Export
	
	AddressUS = HomeCountryAddress(AddressObj);
	If AddressUS = Undefined Then
		Return "";
	EndIf;
	
	Return ContactInformationClientServer.FullDescr(
		AddressUS.Street, "");
	
EndFunction

//  Returns the address presentation.
//
//  Parameters:
//      AddressObj - XDTODataObject - address.
//      InformationKind - CatalogRef.ContactInformationKinds, Structure - description used to generate the presentation.
//
//  Returns:
//      String - presentation.
//
Function AddressPresentation(XDTOAddress, InformationKind) Export
	
	If XDTOAddress.AddressLine1 <> Undefined And  XDTOAddress.AddressLine2 <> Undefined Then//data is passed from the first address inpup form
		Return ContactInformationClientServer.FullDescr(TrimAll(XDTOAddress.AddressLine1), "", TrimAll(XDTOAddress.AddressLine2), "", TrimAll(XDTOAddress.City), "",
			TrimAll(XDTOAddress.State), "", TrimAll(XDTOAddress.PostalCode), "", TrimAll(XDTOAddress.Country));	
	EndIf;
	
	// 1) Country, if necessary.
	// 2) Postal code, state, county, city, settlement, street
	// 3) Building, unit
	
	FormationParameters = New Structure("IncludeCountryInPresentation", False);
	FillPropertyValues(FormationParameters, InformationKind);
	
	Namespace = ContactInformationClientServerCached.Namespace();
	AddressUS         = XDTOAddress.Content;
	Country           = TrimAll(XDTOAddress.Country);
	If IsDomesticAddress(AddressUS) Then
		// This address is domestic; examining the settings
		If Not FormationParameters.IncludeCountryInPresentation Then
			Country = "";
		EndIf;
		
		// Key parts
		Presentation = ContactInformationClientServer.FullDescr(
			AddressPostalCode(AddressUS), "",
			AddressUS.Region, "",
			AddressCounty(AddressUS), "",
			AddressUS.City, "",
			AddressUS.District, "",
			AddressUS.Settlement, "",
			AddressUS.Street, "");
			
		// Building units
		NumberNotDisplayed = True;
		Data = BuildingAddresses(AddressUS);
		For Each Row In Data.Buildings Do
			Presentation =  ContactInformationClientServer.FullDescr(
				Presentation, "",
				TrimAll(Row.Abbr + ?(NumberNotDisplayed, " № ", " ") + Row.Value), "");
			NumberNotDisplayed = False;
		EndDo;
			
		// If the presentation is empty, there is no point in displaying the country
		If IsBlankString(Presentation) Then
			Country = "";
		EndIf;
	Else
		// This address is foreign
		Presentation = TrimAll(AddressUS);
	EndIf;
	
	Return ContactInformationClientServer.FullDescr(Country, "", Presentation, "");
EndFunction

//  Returns the list of address errors.
//
// Parameters:
//     XDTOAddress         - XDTODataObject, ValueList, String - address
//     description InformationKind     - CatalogRef.ContactInformationKinds - reference to a related contact
// information kind. ResultByGroups - Boolean - if True, returns an array of error groups, otherwise - value list.
//
// Returns:
//     ValueList - if ResultByGroups = False. Contains a presentation - error text, value - error field
//     XPath. Array         - if ResultByGroups = True. Contains structures with fields:
//                         ** ErrorType - String - error group (type) name. Allowed values:
//                               "PresentationNotMatchingFieldSet"
//                               "MandatoryFieldsNotFilled"
//                               "FieldAbbreviationsNotSpecified"
//                               "InvalidFieldCharacters"
//                               "FieldLengthsNotMatching"
//                               "ClassifierErrors"
//                         ** Message - String - detailed
//                         error text. ** Fields      - Array - contains the error field description structures. Each structure has attributes:
//                               *** FieldName   - String - internal ID invalid item addresses 
//                               *** Message - String - detailed error text for this field
//
Function AddressFillErrors(Val XDTOAddress, Val InformationKind, Val ResultByGroups = False) Export
	
	If TypeOf(XDTOAddress) = Type("XDTODataObject") Then
		AddressUS = XDTOAddress.Content;
	Else
		XTDOContactInformation = AddressDeserialization(XDTOAddress);
		Address = XTDOContactInformation.Content;
		AddressUS = ?(Address = Undefined, Undefined, Address.Content);
	EndIf;
	
	// Check flags
	If TypeOf(InformationKind) = Type("CatalogRef.ContactInformationKinds") Then
		CheckFlags = ContactInformationManagement.ContactInformationKindStructure(InformationKind);
	Else
		CheckFlags = InformationKind;
	EndIf;
	
	Namespace = ContactInformationClientServerCached.Namespace();
	If TypeOf(AddressUS) <> Type("XDTODataObject") Or AddressUS.Type() <> XDTOFactory.Type(Namespace, "AddressUS") Then
		// Foreign address
		Result = ?(ResultByGroups, New Array, New ValueList);
		
		If CheckFlags.DomesticAddressOnly Then
			ErrorText = NStr("en = 'Only domestic addresses are allowed.'");
			If ResultByGroups Then
				Result.Add(New Structure("Fields, ErrorType, Message", New Array,
					"MandatoryFieldsNotFilled", ErrorText
				)); 
			Else
				Result.Add("/", ErrorText);
			EndIf;
		EndIf;
		
		Return Result;
	EndIf;
	
	// Checking the empty address separately if it has to be filled
	If Not XDTOContactInformationFilled(AddressUS) Then
		// The address is empty
		If CheckFlags.Mandatory Then
			// But it is mandatory to fill
			ErrorText = NStr("en = 'The address is not filled.'");
			
			If ResultByGroups Then
				Result = New Array;
				Result.Add(New Structure("Fields, ErrorType, Message", New Array,
					"MandatoryFieldsNotFilled", ErrorText
				)); 
			Else
				Result = New ValueList;
				Result.Add("/", ErrorText);
			EndIf;
			
			Return Result
		EndIf;
		
		// The address is empty but it is not mandatory to fill; therefore it is valid
		Return ?(ResultByGroups, New Array, New ValueList);
	EndIf;
	
	AllErrors = AddressFillErrorsCommonGroups(AddressUS, CheckFlags);
	CheckClassifier = True;
	
	For Each Group In AllErrors Do
		If Find("FieldAbbreviationsNotSpecified, InvalidFieldCharacters", Group.ErrorType) > 0 Then
			// Invalid field data; there is no point in validating it by classifier
			CheckClassifier = False;
			Break;
		EndIf
	EndDo;
	
	ClassifierErrors = New ValueList;
	If CheckClassifier Then
		Option = ContactInformationClientServer.UsedAddressClassifier();
		
		If Option = "AC" Then
			FillAddressErrorsAddressClassifier(AddressUS, ClassifierErrors);
		Else
			// No classifier subsystem
		EndIf;
		
	EndIf;
	
	If ResultByGroups Then
		ErrorGroupDescription = "ErrorsByClassifier";
		ErrorsCount = ClassifierErrors.Count();
		
		If ErrorsCount = 1 And ClassifierErrors[0].Value <> Undefined
			And ClassifierErrors[0].Value.XPath = Undefined 
		Then
			AllErrors.Add(AddressErrorGroup(ErrorGroupDescription,
				ClassifierErrors[0].Presentation));
			
		ElsIf ErrorsCount > 0 Then
			// Detailed error description
			AllErrors.Add(AddressErrorGroup(ErrorGroupDescription,
				NStr("en = 'Address parts do not match the address classifier:'")));
				
			ClassifierErrorGroup = AllErrors[AllErrors.UBound()];
			
			EntityList = "";
			For Each Item In ClassifierErrors Do
				ErrorItem = Item.Value;
				If ErrorItem = Undefined Then
					// Abstract error
					AddAddressFillError(ClassifierErrorGroup, 
						"", Item.Presentation);
				Else
					AddAddressFillError(ClassifierErrorGroup, 
						ErrorItem.XPath, Item.Presentation);
					EntityList = EntityList + ", " + ErrorItem.FieldEntity;
				EndIf;
			EndDo;
			
			ClassifierErrorGroup.Message = ClassifierErrorGroup.Message + Mid(EntityList, 2);
		EndIf;
		
		Return AllErrors;
	EndIf;
	
	// Adding all data to a list
	Result = New ValueList;
	For Each Group In AllErrors Do
		For Each Field In Group.Fields Do
			Result.Add(Field.FieldName, Field.Message);
		EndDo;
	EndDo;
	For Each ListItem In ClassifierErrors Do
		Result.Add(ListItem.Value.XPath, ListItem.Presentation);
	EndDo;
	
	Return Result;
EndFunction

// General address validation
//
//  Parameters:
//      AddressData  - String, ValueList - XML, XDTO with domestic
//      address data. InformationKind - CatalogRef.ContactInformationKinds - reference to a related contact information kind 
//
// Returns:
//      Array - contains structures with fields:
//         * ErrorType - String - error group ID. Can take on values:
//              "PresentationNotMatchingFieldSet"
//              "MandatoryFieldsNotFilled"
//              "FieldAbbreviationsNotSpecified"
//              "InvalidFieldCharacters"
//              "FieldLengthsNotMatching"
//         * Message - String - detailed error text.
//         * Fields - array of structures with fields:
//             ** FieldName - internal ID of the invalid field. 
//             ** Message - detailed error text for the field.
//
Function AddressFillErrorsCommonGroups(Val AddressData, Val InformationKind) Export
	Result = New Array;
	
	If TypeOf(AddressData) = Type("XDTODataObject") Then
		AddressUS = AddressData;
		
	Else
		XTDOContactInformation = AddressDeserialization(AddressData);
		Address = XTDOContactInformation.Content;
		If Not IsDomesticAddress(Address) Then
			Return Result;
		EndIf;
		AddressUS = Address.Content;
		
		// 1) presentation must match the data set
		Presentation = AddressPresentation(AddressUS, InformationKind);
		If XTDOContactInformation.Presentation <> Presentation Then
			Result.Add(AddressErrorGroup("PresentationNotMatchingFieldSet",
				NStr("en = 'The address does not match the field set values.'")));
			AddAddressFillError(Result[0], "",
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en = 'Address presentation for ""%1"" contact information kind does not match the address data.'"),
					String(InformationKind.Description)));
		EndIf;
	EndIf;
	
	MandatoryFieldsNotFilled = AddressErrorGroup("MandatoryFieldsNotFilled",
		NStr("en = 'Mandatory fields are not filled:'"));
	Result.Add(MandatoryFieldsNotFilled);
	
	FieldAbbreviationsNotSpecified = AddressErrorGroup("FieldAbbreviationsNotSpecified",
		NStr("en = 'Abbreviations are not specified for fields:'"));
	Result.Add(FieldAbbreviationsNotSpecified);
	
	InvalidFieldCharacters = AddressErrorGroup("InvalidFieldCharacters",
		NStr("en = 'Invalid characters are identified in fields:'"));
	Result.Add(InvalidFieldCharacters);
	
	FieldLengthsNotMatching = AddressErrorGroup("FieldLengthsNotMatching",
		NStr("en = 'Field length does not match the predefined value for fields:'"));
	Result.Add(FieldLengthsNotMatching);
	
	// 2) PostalCode, State, Building fields must be filled
	Index = AddressPostalCode(AddressUS);
	If IsBlankString(Index) Then
		AddAddressFillError(MandatoryFieldsNotFilled, ContactInformationClientServerCached.PostalCodeXPath(),
			NStr("en = 'Postal code is not specified.'"), "Index");
	EndIf;
	
	State = AddressUS.Region;
	If IsBlankString(State) Then
		AddAddressFillError(MandatoryFieldsNotFilled, "Region",
			NStr("en = 'State name is not specified.'"), "State");
	EndIf;
	
	BuildingsUnits = BuildingAddresses(AddressUS);
	If SkipBuildingAddressCheck(AddressUS) Then
		// Any building unit data must be filled
		
		UnitNotSpecified = True;
		For Each BuildingData In BuildingsUnits.Buildings Do
			If Not IsBlankString(BuildingData.Value) Then
				UnitNotSpecified = False;
				Break;
			EndIf;
		EndDo;
		If UnitNotSpecified Then
			AddAddressFillError(MandatoryFieldsNotFilled, 
				ContactInformationClientServerCached.AdditionalAddressingObjectNumberXPath("Building"),
				NStr("en = 'Building or unit number is not specified.'"), 
				NStr("en = 'Building'")
			);
		EndIf;
			
	Else
		// Building number is mandatory; unit number is optional.
		
		BuildingData = BuildingsUnits.Buildings.Find(1, "Kind");	// 1 - kind by ownership
		If BuildingData = Undefined Then
			AddAddressFillError(MandatoryFieldsNotFilled, 
				ContactInformationClientServerCached.AdditionalAddressingObjectNumberXPath("Building"),
				NStr("en = 'Building is not specified.'"),
				NStr("en = 'Building'")
			);
		ElsIf IsBlankString(BuildingData.Value) Then
			AddAddressFillError(MandatoryFieldsNotFilled, BuildingData.XPath,
				NStr("en = 'Building value is not filled.'"),
				NStr("en = 'Building'")
			);
		EndIf;
		
	EndIf;
	
	// 3) State, County, City, Settlement, Street must:    
	//      - have abbreviations
	//      - be under 50 characters
	//      - contain Latin letters only
	
	AllowedBesidesLatin = "/,-. 0123456789_";
	
	// State
	If Not IsBlankString(State) Then
		Field = "Region";
		If IsBlankString(ContactInformationClientServer.Abbr(State)) Then
			AddAddressFillError(FieldAbbreviationsNotSpecified, "Region",
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en = 'Abbreviation is not specified for state ""%1"".'"), State
				), NStr("en = 'State'"));
		EndIf;
		If StrLen(State) > 50 Then
			AddAddressFillError(FieldLengthsNotMatching, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en = 'The name of state ""%1"" must be under 50 characters.'"), State
				), NStr("en = 'State'"));
		EndIf;
		If Not StringFunctionsClientServer.OnlyLatinInString(State, False, AllowedBesidesLatin) Then
			AddAddressFillError(InvalidFieldCharacters, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en = 'The name of state ""%1"" contains non-Latin characters.'"), State
				), NStr("en = 'State'"));
		EndIf
	EndIf;
	
	// County
	County = AddressCounty(AddressUS);
	If Not IsBlankString(County) Then
		Field = ContactInformationClientServerCached.CountyXPath();
		If IsBlankString(ContactInformationClientServer.Abbr(County)) Then
			AddAddressFillError(FieldAbbreviationsNotSpecified, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en = 'Abbreviation is not specified for county ""%1""'."), County
				), NStr("en = 'County'"));
		EndIf;
		If StrLen(County) > 50 Then
			AddAddressFillError(FieldLengthsNotMatching, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en = 'The name of county ""%1"" must be under 50 characters.'"), County
				), NStr("en = 'County'"));
		EndIf;
		If Not StringFunctionsClientServer.OnlyLatinInString(County, False, AllowedBesidesLatin) Then
			AddAddressFillError(InvalidFieldCharacters, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en = 'The name of county ""%1"" contains non-Latin characters.'"), County
				), NStr("en = 'County'"));
		EndIf;
	EndIf;
	
	// City
	City = AddressUS.City;
	If Not IsBlankString(City) Then
		Field = "City";
		If IsBlankString(ContactInformationClientServer.Abbr(City)) Then
			AddAddressFillError(FieldAbbreviationsNotSpecified, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en = 'Abbreviation is not specified for city ""%1"".'"), City
				), NStr("en = 'City'"));
		EndIf;
		If StrLen(City) > 50 Then
			AddAddressFillError(FieldLengthsNotMatching, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en = 'The name of city ""%1"" must be under 50 characters.'"), City
				), NStr("en = 'City'"));
		EndIf;
		If Not StringFunctionsClientServer.OnlyLatinInString(City, False, AllowedBesidesLatin) Then
			AddAddressFillError(InvalidFieldCharacters, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en = 'The name of city ""%1"" contains non-Latin characters.'"), City
				), NStr("en = 'City'"));
		EndIf;
	EndIf;
	
	// Settlement
	Settlement = AddressUS.Settlement;
	If Not IsBlankString(Settlement) Then
		Field = "Settlement";
		If IsBlankString(ContactInformationClientServer.Abbr(Settlement)) Then
			AddAddressFillError(FieldAbbreviationsNotSpecified, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en = 'Abbreviation is not specified for settlement ""%1"".'"), Settlement
				), NStr("en = 'Settlement'"));
		EndIf;
		If StrLen(Settlement) > 50 Then
			AddAddressFillError(FieldLengthsNotMatching, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en = 'The name of settlement ""%1"" must be under 50 characters.'"), Settlement
				), NStr("en = 'Settlement'"));
		EndIf;
		If Not StringFunctionsClientServer.OnlyLatinInString(Settlement, False, AllowedBesidesLatin) Then
			AddAddressFillError(InvalidFieldCharacters, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en = 'The name of settlement ""%1"" contains non-Latin characters.'"), Settlement
				), NStr("en = 'Settlement'"));
		EndIf;
	EndIf;
	
	// Street
	Street = AddressUS.Street;
	If Not IsBlankString(Street) Then
		Field = "Street";
		If IsBlankString(ContactInformationClientServer.Abbr(Street)) Then
			AddAddressFillError(FieldAbbreviationsNotSpecified, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en = 'Abbreviation is not specified for street ""%1"".'"), Street
				), NStr("en = 'Street'"));
		EndIf;
		If StrLen(County) > 50 Then
			AddAddressFillError(FieldLengthsNotMatching, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en = 'The name of street ""%1"" must be under 50 characters.'"), Street
				), NStr("en = 'Street'"));
		EndIf;
		If Not StringFunctionsClientServer.OnlyLatinInString(Street, False, AllowedBesidesLatin) Then
			AddAddressFillError(InvalidFieldCharacters, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en = 'The name of street ""%1"" contains non-Latin characters.'"), Street
				), NStr("en = 'Street'"));
		EndIf;
	EndIf;
	
	// 4) Postal code - must contain 6 digits, if any
	If Not IsBlankString(Index) Then
		Field = ContactInformationClientServerCached.PostalCodeXPath();
		If StrLen(Index) <> 6 Or Not StringFunctionsClientServer.OnlyDigitsInString(Index) Then
			AddAddressFillError(FieldLengthsNotMatching, Field,
				NStr("en = 'The postal code must contain 6 digits.'"),
				NStr("en = 'Index'")
			);
		EndIf;
	EndIf;
	
	// 5) Building, Unit, Apartment must be under 10 characters
	For Each UnitData In BuildingsUnits.Buildings Do
		If StrLen(UnitData.Value) > 10 Then
			AddAddressFillError(FieldLengthsNotMatching, UnitData.XPath,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en = 'The value of field ""%1"" must be under 10 characters.'"), UnitData.Type
				), UnitData.Type);
		EndIf;
	EndDo;

    // 6) City and Settlement fields cannot both be empty	
	If IsBlankString(City) And IsBlankString(Settlement) Then
			AddAddressFillError(MandatoryFieldsNotFilled, "City and Settlement fields cannot both be empty",
				NStr("en = 'Settlement'")
			);
	EndIf;
	
	// 7) Street name cannot be empty if Settlement name is empty
	If Not SkipStreetAddressCheck(AddressUS) Then
			
		If IsBlankString(Settlement) And IsBlankString(Street) Then
			AddAddressFillError(MandatoryFieldsNotFilled, "Street",
				NStr("en = 'If the settlement is undefined, the street is mandatory.'"), 
				NStr("en = 'Street'")
			);
		EndIf;
		
	EndIf;
	
	// Final step - removing the empty results, modifying the group message
	For Index = 1-Result.Count() To 0 Do
		Group = Result[-Index];
		Fields = Group.Fields;
		EntityList = "";
		For FieldIndex = 1-Fields.Count() To 0 Do
			Field = Fields[-FieldIndex];
			If IsBlankString(Field.Message) Then
				Fields.Delete(-FieldIndex);
			Else
				EntityList = ", " + Field.FieldEntity + EntityList;
				Field.Delete("FieldEntity");
			EndIf;
		EndDo;
		If Fields.Count() = 0 Then
			Result.Delete(-Index);
		ElsIf Not IsBlankString(EntityList) Then
			Group.Message = Group.Message + Mid(EntityList, 2);
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

// Local exceptions allowed during address validation
//
Function SkipBuildingAddressCheck(Val AddressUS)
	Result = False;
	Return Result;
EndFunction
	
// Local exceptions allowed during address validation
//
Function SkipStreetAddressCheck(Val AddressUS)
	Result = False;
	
	Return Result;
EndFunction

//  Returns a phone number presentation.
//
//  Parameters:
//      XDTOData        - XDTODataObject - contact information. 
//      InformationKind - CatalogRef.ContactInformationKinds - reference to a related contact information kind 
//
// Returns:
//      String - presentation.
//
Function PhonePresentation(XDTOData, InformationKind = Undefined) Export
	Return ContactInformationManagementClientServer.GeneratePhonePresentation(
		RemoveNonDigitCharacters(XDTOData.CountryCode), 
		XDTOData.AreaCode,
		XDTOData.Number,
		XDTOData.Extension,
		"");
EndFunction    

//  Returns a fax number presentation.
//
//  Parameters:
//      XDTOData    - XDTODataObject - contact information. 
//      InformationKind - CatalogRef.ContactInformationKinds - reference to a related contact information kind.
//
// Returns:
//      String - presentation.
//
Function FaxPresentation(XDTOData, InformationKind = Undefined) Export
	Return ContactInformationManagementClientServer.GeneratePhonePresentation(
		RemoveNonDigitCharacters(XDTOData.CountryCode), 
		XDTOData.AreaCode,
		XDTOData.Number,
		XDTOData.Extension,
		"");
EndFunction    

// Returns the flag specifying whether the current user can import or clear the address classifier.
//
// Returns:
//     Boolean - check result.
//
Function CanChangeAddressClassifier() Export
	Option = ContactInformationClientServer.UsedAddressClassifier();
		
	If Option = "AC" Then
		ControlObject = Metadata.InformationRegisters.Find("AddressClassifier");
		Return ControlObject <> Undefined And AccessRight("Update", ControlObject);
	EndIf;
	
	// Classifier is not available
	Return False;
EndFunction

////////////////////////////////////////////////////////////////////////////////////////////////////
// Compatibility
//

//  Returns a structure containing a string and a list.
//
//  Parameters:
//      XDTOContactInformation - XDTODataObject, String - contact information or an XML string.
//      OldFieldContent        - Boolean - optional flag specifying whether fields not available in SL 
//                                          versions below 2.1.3 should be excluded from the field content.
//
//  Returns:
//      Structure - data. Contains fields:
//          * Presentation - String - address presentation.
//          * FieldValues - ValueList - values.
//
Function ContactInformationToOldStructure(XDTOContactInformation, OldFieldContent = False) Export
	
	If ContactInformationClientServer.IsXMLContactInformation(XDTOContactInformation) Then
		XDTOContactInfo = ContactInformationDeserialization(XDTOContactInformation);
	Else
		XDTOContactInfo = XDTOContactInformation
	EndIf;
	
	Result = New Structure("Presentation, FieldValues", XDTOContactInfo.Presentation, New ValueList);
	
	Namespace = ContactInformationClientServerCached.Namespace();
	Content = XDTOContactInfo.Content;
	
	If Content = Undefined Then
		Return Result;
	EndIf;
	
	Type = Content.Type();
	If Type = XDTOFactory.Type(Namespace, "Address") Then
		Result.FieldValues = AddressToOldFieldList(Content, Not OldFieldContent);
		Result.FieldValues.Add(Result.Presentation, "Presentation");
		
	ElsIf Type = XDTOFactory.Type(Namespace, "PhoneNumber") Then
		Result.FieldValues = PhoneNumberToOldFieldList(Content);
		Result.FieldValues.Add(XDTOContactInfo.Comment, "Comment");
		
	EndIf;
	
	Return Result;
EndFunction

// Transforms an address in XDTO format to an old ValueList type field list.
//
// Parameters:
//     XDTOAddress          - XDTODataObject, String - contact information or an XML string.
//     ExpandedFieldContent - Boolean - optional flag specifying whether fields should be excluded
//                                     from the field content to ensure compatibility with SL version 2.1.2.
//
//  Returns:
//     ValueList.
//
Function AddressToOldFieldList(XDTOAddress, ExpandedFieldContent = True) Export
	List = New ValueList;
	
	Namespace = ContactInformationClientServerCached.Namespace();
	XDTOType = XDTOAddress.Type();
	If XDTOType = XDTOFactory.Type(Namespace, "Address") Then
		
		// Country with code
		AddValue(List, "Country", XDTOAddress.Country);
		If IsBlankString(XDTOAddress.Country) Then
			CountryCode = "";
		Else
			Country = Catalogs.WorldCountries.FindByDescription(XDTOAddress.Country, True);
			CountryCode = TrimAll(Country.Code);
		EndIf;
		AddValue(List, "CountryCode", CountryCode);
		
		If Not IsDomesticAddress(XDTOAddress) Then
			Return List;
		EndIf;
		
		AddressUS = XDTOAddress.Content;
		
	ElsIf XDTOType = XDTOFactory.Type(Namespace, "AddressUS") Then
		AddressUS = XDTOAddress;
		
	Else
		Return List;
		
	EndIf;
	
	AddValue(List, "Index", AddressPostalCode(AddressUS) );
	
	AddValue(List, "State", AddressUS.Region);
	AddValue(List, "StateCode", StateCode(AddressUS.Region) );
	If ExpandedFieldContent Then
		AddValue(List, "StateAbbr", ContactInformationClientServer.Abbr(AddressUS.Region));
	EndIf;
	
	County = AddressCounty(AddressUS);
	AddValue(List, "County", County);
	If ExpandedFieldContent Then
		AddValue(List, "CountyAbbr", ContactInformationClientServer.Abbr(County));
	EndIf;
	
	AddValue(List, "City", AddressUS.City);
	If ExpandedFieldContent Then
		AddValue(List, "CityAbbr", ContactInformationClientServer.Abbr(AddressUS.City));
	EndIf;
	
	AddValue(List, "Settlement", AddressUS.Settlement);
	If ExpandedFieldContent Then
		AddValue(List, "SettlementAbbr", ContactInformationClientServer.Abbr(AddressUS.Settlement));
	EndIf;
	
	AddValue(List, "Street", AddressUS.Street);
	If ExpandedFieldContent Then
		AddValue(List, "StreetAbbr", ContactInformationClientServer.Abbr(AddressUS.Street));
	EndIf;
	
	// Building and unit
	Buildings = BuildingAddresses(AddressUS);
	
	ObjectParameters = BuildingUnitValue(Buildings.Buildings, DataOptionsHouse(), ExpandedFieldContent);
	If ObjectParameters.Count() = 0 Then
		AddValue(List, "BuildingType", "");
		AddValue(List, "Building",     "");
	Else
		For Each ObjectString In ObjectParameters Do
			AddValue(List, "BuildingType", ObjectString.Type,  ExpandedFieldContent);
			AddValue(List, "Building",     ObjectString.Value, ExpandedFieldContent);
		EndDo;
	EndIf;
	
	Return List;
EndFunction

Procedure AddValue(List, FieldName, Value, AllowDuplicates = False)
	
	If Not AllowDuplicates Then
		For Each Item In List Do
			If Item.Presentation = FieldName Then
				Item.Value = String(Value);
				Return;
			EndIf;
		EndDo;
	EndIf;
	
	List.Add(String(Value), FieldName);
EndProcedure

Function BuildingUnitValue(Data, Options, AllOptionValues)
	Result = ValueTable("Type, Value");
	
	For Each Option In Options.TypeOptions Do
		For Each Row In Data.FindRows(New Structure("Type", Option)) Do
			FillPropertyValues(Result.Add(), Row);
			If Not AllOptionValues Then
				Break;
			EndIf;
		EndDo;
	EndDo;
	
	Return Result;
EndFunction

Function PhoneNumberToOldFieldList(XDTOPhone)
	Result = New ValueList;
	
	Result.Add(XDTOPhone.CountryCode,  "CountryCode");
	Result.Add(XDTOPhone.AreaCode,  "AreaCode");
	Result.Add(XDTOPhone.Number,      "PhoneNumber");
	Result.Add(XDTOPhone.Extension, "Extension");
	
	Return Result;
EndFunction

Function AddressErrorGroup(ErrorType, Message)
	Return New Structure("ErrorType, Message, Fields", ErrorType, Message, New Array);
EndFunction

Procedure AddAddressFillError(Group, FieldName = "", Message = "", FieldEntity = "")
	Group.Fields.Add(New Structure("FieldName, Message, FieldEntity", FieldName, Message, FieldEntity));
EndProcedure

////////////////////////////////////////////////////////////////////////////////////////////////////
// Address classifier implementation
//

//  Returns the common server module for address classifier subsystem calls; ensures operation without the subsystem.
//
Function ServerModuleAddressClassifier()
	
	Return CommonUse.CommonModule("AddressClassifier");
	
EndFunction

Function CodePartsAddressClassifier(Val FullCode)
	// SS CCC CCC SSS SSSS AA BBBB
	
	Result = New Structure("StateCode, CountyCode, AreaCode, SettlementCode, StreetCode, BuildingCode, DataIsCurrentFlag");
	
	Result.BuildingCode = FullCode % 10000;
	FullCode = Int(FullCode/10000);
	
	Result.DataIsCurrentFlag = FullCode % 100;
	FullCode = Int(FullCode/100);
	
	Result.StreetCode = FullCode % 10000;
	FullCode = Int(FullCode/10000);
	
	Result.SettlementCode = FullCode % 1000;
	FullCode = Int(FullCode/1000);
	
	Result.AreaCode = FullCode % 1000;
	FullCode = Int(FullCode/1000);
	
	Result.CountyCode = FullCode % 1000;
	FullCode = Int(FullCode/1000);
	
	Result.StateCode = FullCode;
	
	Return Result;
EndFunction        

Function SettlementAutoCompleteResultsAddressClassifier(Text, HideObsoleteAddresses, WarnObsolete, NumberOfRowsToSelect)
	Result = New Structure("TooMuchData, ChoiceData", True, New ValueList);
	
	AddressClassifierModule = ServerModuleAddressClassifier();
	Query = AddressClassifierModule.QuerySettlementAutoCompleteResultsAC(NumberOfRowsToSelect, HideObsoleteAddresses);
	
	SimilarityString = EscapeSpecialCharacters(Text);
	Query.SetParameter("TextBeginning", SimilarityString + "%");
	
	Selection = Query.Execute().Select();
	
	Result.TooMuchData = Selection.Count() > NumberOfRowsToSelect;
	ChoiceData = Result.ChoiceData;
	
	ObsoleteWarning = NStr("en = 'Address ""%1"" is obsolete.'");
	ObsoleteDataPicture = PictureLib.ContactInformationObsolete;
	CurrentDataPicture   = Undefined;
	
	UniquePresentations = New Map;
	
	While Selection.Next() Do
		FullDescr = ContactInformationClientServer.FullDescr(
			Selection.SettlementsDescription, Selection.SettlementsAbbreviation,
			Selection.CitiesDescription,  Selection.CitiesAbbreviation,
			Selection.CountiesDescription,  Selection.CountiesAbbreviation,
			Selection.StatesDescription, Selection.StatesAbbreviation);
			
		// Complementing identical names with postal codes and alternate names
		PresentationInList = FullDescr;
		If UniquePresentations[PresentationInList] <> Undefined Then
			PostalCode = TrimAll(Selection.Index);
			If IsBlankString(PostalCode) Then
				Description = "";
			Else
				Description = StrReplace(NStr("en = 'postal code: %1'"), "%1", PostalCode);
			EndIf;
			AlternateNames = TrimAll(Selection.AlternateNames);
			If Not IsBlankString(AlternateNames) Then
				Description = Description + ", " + AlternateNames;
			EndIf;
			
			If Not IsBlankString(Description) Then
				PresentationInList = PresentationInList + " (" + Description + ")";
			EndIf;
		EndIf;
		UniquePresentations[PresentationInList] = True;
			
		If Selection.Obsolete Then
			WarningText = StrReplace(ObsoleteWarning, "%1", FullDescr);
			Check  = True;
			Picture = ObsoleteDataPicture;
		Else
			WarningText = Undefined;
			Check  = False;
			Picture = CurrentDataPicture;
		EndIf;
		
		If WarnObsolete Then
			ChoiceData.Add(
				New Structure("Warning, Value", 
					WarningText, New Structure("Code, Presentation, CanImportState", Selection.Code, FullDescr, Selection.CanImportState)
				), 
				PresentationInList, Check, Picture
			);
		Else
			ChoiceData.Add(FullDescr, PresentationInList, Check, Picture);
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

Function StreetAutoCompleteResultsAddressClassifier(SettlementCode, Text, HideObsoleteAddresses, WarnObsolete, NumberOfRowsToSelect)
	
	AddressClassifierModule = ServerModuleAddressClassifier();
	Query = AddressClassifierModule.QueryStreetAutoCompleteResultsAC(NumberOfRowsToSelect, HideObsoleteAddresses);
	
	Query.SetParameter("Code", SettlementCode);
	
	SearchString = EscapeSpecialCharacters(Text);
	Query.SetParameter("BeginningOfTheLine", SearchString +  "%");         // String beginning
	Query.SetParameter("WordStart",  "% " + SearchString + "%");   // Word beginning
	
	ChoiceData = New ValueList;
	
	ObsoleteWarning = NStr("en = 'Address ""%1"" is obsolete.'");
	ObsoleteDataPicture = PictureLib.ContactInformationObsolete;
	CurrentDataPicture   = Undefined;
	
	UniquePresentations = New Map;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		FullDescr = ContactInformationClientServer.FullDescr(Selection.Description, Selection.Abbr);
		
		// Complementing identical names with postal codes and alternate names
		PresentationInList = FullDescr;
		If UniquePresentations[PresentationInList] <> Undefined Then
			PostalCode = TrimAll(Selection.Index);
			If IsBlankString(PostalCode) Then
				Description = "";
			Else
				Description = StrReplace(NStr("en = 'postal code: %1'"), "%1", PostalCode);
			EndIf;
			AlternateNames = TrimAll(Selection.AlternateNames);
			If Not IsBlankString(AlternateNames) Then
				Description = Description + ", " + AlternateNames;
			EndIf;
			
			If Not IsBlankString(Description) Then
				PresentationInList = PresentationInList + " (" + Description + ")";
			EndIf;
		EndIf;
		UniquePresentations[PresentationInList] = True;
		
		If Selection.Obsolete Then
			WarningText = StrReplace(ObsoleteWarning, "%1", FullDescr);
			Check  = True;
			Picture = ObsoleteDataPicture;
		Else
			WarningText = Undefined;
			Check  = False;
			Picture = CurrentDataPicture;
		EndIf;
		
		If WarnObsolete Then
			ChoiceData.Add(
				New Structure("Warning, Value", 
					WarningText, New Structure("Code, Presentation", Selection.Code, FullDescr)
				), 
				PresentationInList, Check, Picture
			);
		Else
			ChoiceData.Add(FullDescr, PresentationInList, Check, Picture);
		EndIf;
		
	EndDo;
	
	Return New Structure("TooMuchData, ChoiceData", Selection.Count() > NumberOfRowsToSelect, ChoiceData);
	
EndFunction

Function SettlementsByPresentationAddressClassifier(Text, HideObsoleteAddresses, NumberOfRowsToSelect, StreetClarification)
	
	// As opposite to SettlementAutoCompleteResultsAddressClassifier: 
	// 1) Splitting by comma 
	// 2) Deleting the first word (left of the whitespace) from each split section 
	//    (this word is an abbreviation) 
	// 3) Attempting to find all options by exact match
	
	AddressParts = ContactInformationClientServer.AddressParts(Text);
	Result = New Structure("TooMuchData, ChoiceData", True, New ValueList);
	
	AdditionalSearchStrings = AddressParts.UBound();
	If AdditionalSearchStrings < 0 Then
		// Empty initial data
		Return Result;
	ElsIf AdditionalSearchStrings = 0 Then
		AddressPart = AddressParts[0];
		If IsBlankString(AddressPart.Abbr) And StrLen(AddressPart.Description) < 3 Then
			// Insufficient initial data
			Return Result;
		EndIf;
	EndIf;
	
	AddressClassifierModule = ServerModuleAddressClassifier();
	Query = AddressClassifierModule.QuerySettlementsByPresentationAC(AddressParts, NumberOfRowsToSelect, HideObsoleteAddresses);
	
	Selection = Query.Execute().Select();
	
	Result.TooMuchData = Selection.Count() > NumberOfRowsToSelect;
	ChoiceData = Result.ChoiceData;
	
	ObsoleteWarning = NStr("en = 'The settlement is obsolete.'");
	ObsoleteDataPicture = PictureLib.ContactInformationObsolete;
	CurrentDataPicture   = Undefined;
	
	While Selection.Next() Do
		FullDescr = ContactInformationClientServer.FullDescr(
			Selection.SettlementsDescription, Selection.SettlementsAbbreviation,
			Selection.CitiesDescription,  Selection.CitiesAbbreviation,
			Selection.CountiesDescription,  Selection.CountiesAbbreviation,
			Selection.StatesDescription, Selection.StatesAbbreviation);
		
		If Selection.Obsolete Then
			WarningText = ObsoleteWarning;
			Check  = True;
			Picture = ObsoleteDataPicture;
		Else
			WarningText = Undefined;
			Check  = False;
			Picture = CurrentDataPicture;
		EndIf;
		
		AttributeList = AttributeListSettlementAddressClassifier();
		AttributeList.Settlement.Value          = ContactInformationClientServer.FullDescr(Selection.SettlementsDescription, Selection.SettlementsAbbreviation);
		AttributeList.Settlement.ClassifierCode = Selection.SettlementsCode;
		AttributeList.Settlement.Description    = Selection.SettlementsDescription;
		AttributeList.Settlement.Abbr           = Selection.SettlementsAbbreviation;
		
		AttributeList.City.Value          = ContactInformationClientServer.FullDescr(Selection.CitiesDescription, Selection.CitiesAbbreviation);
		AttributeList.City.ClassifierCode = Selection.CitiesCode;
		AttributeList.City.Description    = Selection.CitiesDescription;
		AttributeList.City.Abbr           = Selection.CitiesAbbreviation;
		
		AttributeList.County.Value          = ContactInformationClientServer.FullDescr(Selection.CountiesDescription, Selection.CountiesAbbreviation);
		AttributeList.County.ClassifierCode = Selection.CountiesCode;
		AttributeList.County.Description    = Selection.CountiesDescription;
		AttributeList.County.Abbr           = Selection.CountiesAbbreviation;
		
		AttributeList.State.Value          = ContactInformationClientServer.FullDescr(Selection.StatesDescription, Selection.StatesAbbreviation);
		AttributeList.State.ClassifierCode = Selection.StatesCode;
		AttributeList.State.Description    = Selection.StatesDescription;
		AttributeList.State.Abbr           = Selection.StatesAbbreviation;
		
		ChoiceData.Add(New Structure("Warning, Value", WarningText,
			New Structure("Code, Presentation, AttributeList",
				Selection.Code, FullDescr, AttributeList
			)), FullDescr, Check, Picture);
	EndDo;
	
	// Clarification required
	LastItemIndex = ChoiceData.Count() - 1;
	If IsBlankString(StreetClarification) = Undefined Or LastItemIndex = 0 Then
		Return Result;
	EndIf;
	
	// Discarding options without street clarification
	While LastItemIndex >=0 Do
		SettlementCode = ChoiceData[LastItemIndex].Value.Value.Code;
		StreetOptions = StreetsByPresentationAddressClassifier(SettlementCode, StreetClarification, HideObsoleteAddresses, 1);
		If StreetOptions.ChoiceData.Count() = 0 Then
			ChoiceData.Delete(LastItemIndex);
		EndIf;
		LastItemIndex = LastItemIndex - 1;
	EndDo;
	
	Return Result;
EndFunction

Function StreetsByPresentationAddressClassifier(SettlementCode, Text, HideObsoleteAddresses, NumberOfRowsToSelect)
	
	AddressParts = ContactInformationClientServer.AddressParts(Text);
	Result = New Structure("TooMuchData, ChoiceData", True, New ValueList);
	
	SearchStringCount = AddressParts.UBound();
	If SearchStringCount  < 0 Then
		// Empty initial data
		Return Result;
	ElsIf SearchStringCount = 0 Then
		AddressPart = AddressParts[0];
		If IsBlankString(AddressPart.Abbr) And StrLen(AddressPart.Description) < 3 Then
			// Insufficient initial data
			Return Result;
		EndIf;
	EndIf;
	
	AddressClassifierModule = ServerModuleAddressClassifier();
	Query = AddressClassifierModule.QueryStreetsByPresentationAddressClassifier(AddressParts, NumberOfRowsToSelect, HideObsoleteAddresses);
	
	// The remaining parameters
	Query.SetParameter("SettlementCode", SettlementCode);
	
	SearchString = EscapeSpecialCharacters(Text);
	Query.SetParameter("BeginningOfTheLine", SearchString +  "%");  // String beginning
	Query.SetParameter("WordStart",  "% " + SearchString + "%");    // Word beginning
	
	Selection = Query.Execute().Select();
	ChoiceData = Result.ChoiceData;
	
	ObsoleteWarning = NStr("en = 'The street is obsolete.'");
	ObsoleteDataPicture = PictureLib.ContactInformationObsolete;
	CurrentDataPicture   = Undefined;
	
	While Selection.Next() Do
		FullDescr = ContactInformationClientServer.FullDescr(
			Selection.Description, Selection.Abbr);
		
		If Selection.Obsolete Then
			WarningText = ObsoleteWarning;
			Check  = True;
			Picture = ObsoleteDataPicture;
		Else
			WarningText = Undefined;
			Check  = False;
			Picture = CurrentDataPicture;
		EndIf;
		
		ChoiceData.Add(New Structure("Warning, Value", WarningText,
			New Structure("Code, Presentation",
				Selection.Code, FullDescr
			)), FullDescr, Check, Picture);
	EndDo;
	
	Result.TooMuchData = Selection.Count() > NumberOfRowsToSelect;
	Return Result;
EndFunction

Function IsChildAddressClassifier(ObjectCode, ParentCode)
	ParentStructure = CodePartsAddressClassifier(ParentCode);
	ObjectStructure  = CodePartsAddressClassifier(ObjectCode);
	
	If ObjectStructure.StreetCode <> 0 Then
		Return ObjectStructure.SettlementCode = ParentStructure.SettlementCode
		And ObjectStructure.AreaCode = ParentStructure.AreaCode
		And ObjectStructure.CountyCode = ParentStructure.CountyCode
		And ObjectStructure.StateCode = ParentStructure.StateCode
		
	ElsIf ObjectStructure.SettlementCode <> 0 Then
		Return ObjectStructure.AreaCode = ParentStructure.AreaCode
		And ObjectStructure.CountyCode = ParentStructure.CountyCode
		And ObjectStructure.StateCode = ParentStructure.StateCode
		
	ElsIf ObjectStructure.AreaCode <> 0 Then
		Return ObjectStructure.CountyCode = ParentStructure.CountyCode
		And ObjectStructure.StateCode = ParentStructure.StateCode
		
	ElsIf ObjectStructure.CountyCode <> 0 Then
		Return ObjectStructure.StateCode = ParentStructure.StateCode
		
	ElsIf ObjectStructure.StateCode <> 0 Then
		Return True;
	EndIf;
	
	Return False;
EndFunction

// Returns an empty template structure, or a structure filled by code.
Function AttributeListSettlementAddressClassifier(Code = Undefined)
	
	// Level one - internal IDs
	Result = New Structure;
	Result.Insert("State",      AddressStructureItem(NStr("en = 'State'"), "Region") );
	Result.Insert("County",     AddressStructureItem(NStr("en = 'County'"), "CountyMunicipalEntity/County") );
	Result.Insert("City",       AddressStructureItem(NStr("en = 'City'"), "City") );
	Result.Insert("Settlement", AddressStructureItem(NStr("en = 'Settlement.item'"), "Settlement", ,True));
	
	// Interface tooltips
	Result.State.Insert("ToolTip",      NStr("en = 'Address state'"));
	Result.County.Insert("ToolTip",     NStr("en = 'Address county'"));
	Result.City.Insert("ToolTip",       NStr("en = 'Address city'"));
	Result.Settlement.Insert("ToolTip", NStr("en = 'Address settlement'"));
	
	If Code = Undefined Then
		Return Result;
	EndIf;
	
	AddressClassifierModule = ServerModuleAddressClassifier();
	Query = AddressClassifierModule.QueryAttributeListSettlementAddressClassifier();
	
	Query.SetParameter("Code", Code);
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Result.Settlement.Value          = ContactInformationClientServer.FullDescr(Selection.SettlementsDescription, Selection.SettlementsAbbreviation);
		Result.Settlement.ClassifierCode = Selection.SettlementsCode;
		Result.Settlement.Description    = Selection.SettlementsDescription;
		Result.Settlement.Abbr           = Selection.SettlementsAbbreviation;
		
		Result.City.Value          = ContactInformationClientServer.FullDescr(Selection.CitiesDescription, Selection.CitiesAbbreviation);
		Result.City.ClassifierCode = Selection.CitiesCode;
		Result.City.Description    = Selection.CitiesDescription;
		Result.City.Abbr           = Selection.CitiesAbbreviation;
		
		Result.County.Value          = ContactInformationClientServer.FullDescr(Selection.CountiesDescription, Selection.CountiesAbbreviation);
		Result.County.ClassifierCode = Selection.CountiesCode;
		Result.County.Description    = Selection.CountiesDescription;
		Result.County.Abbr           = Selection.CountiesAbbreviation;
		
		Result.State.Value          = ContactInformationClientServer.FullDescr(Selection.StatesDescription, Selection.StatesAbbreviation);
		Result.State.ClassifierCode = Selection.StatesCode;
		Result.State.Description    = Selection.StatesDescription;
		Result.State.Abbr           = Selection.StatesAbbreviation;
	EndIf;
	Return Result;
EndFunction

// Returns an empty template structure, or a structure filled by code.
Function AttributeListStreetAddressClassifier(Code = Undefined)
	Result = New Structure("Street", AddressStructureItem("Street", "Street"),);
	
	If Code <> Undefined Then
		AddressClassifierModule = ServerModuleAddressClassifier();
		Query = AddressClassifierModule.QueryAttributeListStreetAddressClassifier();
		Query.SetParameter("Code", Code);
		
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			Result.Street.Value       = ContactInformationClientServer.FullDescr(Selection.StreetsDescription, Selection.StreetsAbbreviation);
			Result.Street.Code        = Selection.StreetsCode;
			Result.Street.Description = Selection.StreetsDescription;
			Result.Street.Abbr        = Selection.StreetsAbbreviation;
		EndIf;
	EndIf;
	
	Return Result;
EndFunction

Function AddressItemAutoCompleteListAddressClassifier(Text, AddressPartCode, AddressParts, WarnObsolete, NumberOfRowsToSelect)
	Return AddressItemAnalysisListAddressClassifier(Text, "", AddressPartCode, AddressParts, True, WarnObsolete, NumberOfRowsToSelect);
EndFunction

Function AddressItemOptionListByTextAddressClassifier(Text, AddressPartCode, AddressParts, NumberOfRowsToSelect = 50)
	
	SearchAddressParts = ContactInformationClientServer.AddressParts(Text);
	If SearchAddressParts.Count() = 0 Then
		Return Undefined;
	EndIf;
	Description = TrimAll(SearchAddressParts[0].Description);
	Abbr   = TrimAll(SearchAddressParts[0].Abbr);
	
	SearchBySimilarity = IsBlankString(Abbr);
	
	Return AddressItemAnalysisListAddressClassifier(Description, Abbr, AddressPartCode, AddressParts, SearchBySimilarity, True, NumberOfRowsToSelect);
EndFunction

Function AddressItemAnalysisListAddressClassifier(Description, Abbr, AddressPartCode, AddressParts, SearchBySimilarity = True, WarnObsolete = True, NumberOfRowsToSelect = 50)
	
	AttributeCode = Upper(AddressPartCode);
	
	If AttributeCode    = "STATE" Then
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
		Return Undefined;
	EndIf;
	
	AddressClassifierModule = ServerModuleAddressClassifier();
	Query = AddressClassifierModule.QueryAddressItemAnalysisListAddressClassifier(AddressParts, Level, Description, Abbr, SearchBySimilarity, NumberOfRowsToSelect);
	
	Query.SetParameter("Level", Level);
	Selection = Query.Execute().Select();
	
	ObsoleteWarning = NStr("en = 'Address ""%1"" is obsolete.'");
	ObsoleteDataPicture = PictureLib.ContactInformationObsolete;
	CurrentDataPicture   = Undefined;
	
	UniquePresentations = New Map;
	
	ChoiceData = New ValueList;
	While Selection.Next() Do
		
		FullDescr = ContactInformationClientServer.FullDescr(
			Selection.AddressesDescription, Selection.AddressesAbbreviation);
			
		// Complementing identical names with postal codes and alternate names
		PresentationInList = FullDescr;
		If UniquePresentations[PresentationInList] <> Undefined Then
			PostalCode = TrimAll(Selection.Index);
			If IsBlankString(PostalCode) Then
				Description = "";
			Else
				Description = StrReplace(NStr("en = 'postal code: %1'"), "%1", PostalCode);
			EndIf;
			AlternateNames = TrimAll(Selection.AlternateNames);
			If Not IsBlankString(AlternateNames) Then
				Description = Description + ", " + AlternateNames;
			EndIf;
			
			If Not IsBlankString(Description) Then
				PresentationInList = PresentationInList + " (" + Description + ")";
			EndIf;
		EndIf;
		UniquePresentations[PresentationInList] = True;
			
		If Selection.Obsolete Then
			WarningText = StrReplace(ObsoleteWarning, "%1", FullDescr);
			Check  = True;
			Picture = ObsoleteDataPicture;
		Else
			WarningText = Undefined;
			Check  = False;
			Picture = CurrentDataPicture;
		EndIf;
		
		If WarnObsolete Then
			
			RowData = New Structure(
				"Code, Presentation, FullDescr, Description, Abbreviation, CanImportState",
				Selection.Code, FullDescr, FullDescr, 
				Selection.AddressesDescription, Selection.AddressesAbbreviation, Selection.CanImportState
			);
			
			ChoiceData.Add(
				New Structure("Warning, Value", WarningText, RowData),
				PresentationInList, Check, Picture
			);
			
		Else
			ChoiceData.Add(FullDescr, PresentationInList, Check, Picture);
			
		EndIf;
		
	EndDo;
	
	Return ChoiceData;
EndFunction

Procedure SetAddressSettlementByPostalCodeAddressClassifier(XDTOHomeCountryAddress, ClassifierCode)
	
	AddressClassifierModule = ServerModuleAddressClassifier();
	If AddressClassifierModule = Undefined Then
		Return;
	EndIf;
	
	StructureAddressClassifier = New Structure;
	AddressClassifierModule.GetComponentsToStructureByAddressItemCode(ClassifierCode, StructureAddressClassifier);
	XDTOHomeCountryAddress.Region = TrimAll(StructureAddressClassifier.State);
	AddressCounty(XDTOHomeCountryAddress, TrimAll(StructureAddressClassifier.County));
	XDTOHomeCountryAddress.City = TrimAll(StructureAddressClassifier.City);
	XDTOHomeCountryAddress.Settlement = TrimAll(StructureAddressClassifier.Settlement);
	
EndProcedure

Procedure SetAddressStreetByPostalCodeAddressClassifier(XDTOHomeCountryAddress, ClassifierCode)
	AddressClassifierModule = ServerModuleAddressClassifier();
	If AddressClassifierModule = Undefined Then
		Return;
	EndIf;
	
	StructureAddressClassifier = New Structure;
	AddressClassifierModule.GetComponentsToStructureByAddressItemCode(ClassifierCode, StructureAddressClassifier);
	If Not IsBlankString(StructureAddressClassifier.Street) Then
		XDTOHomeCountryAddress.Street = StructureAddressClassifier.Street;
	EndIf;
EndProcedure

Procedure FillAddressErrorsAddressClassifier(XDTOHomeCountryAddress, Result)
	
	AddressClassifierModule = ServerModuleAddressClassifier();
	If AddressClassifierModule = Undefined Then
		// Address classifier is not available
		Return;
	EndIf;
	
	CheckAttributes = AddressAttributeListAddressClassifier();
	
	FieldEntityState = NStr("en = 'Region'");
	AttributeNameState = "State";
	XPathState    = CheckAttributes[AttributeNameState].XPath;
	
	If AddressClassifierModule.FilledAddressObjectCount() = 0 Then
		// The address classifier is not imported for any state
		Result.Add(New Structure("FieldEntity, XPath", FieldEntityState, XPathState),
			NStr("en = 'The address classifier is not imported.'"));
		Return;
	EndIf;
	
	Data = StructureAddressClassifierByDomesticAddress(XDTOHomeCountryAddress);
	
	// Validating the state
	StateCode = StateCodeAddressClassifier(Data.State);
	If IsBlankString(StateCode) Then
		// Passed value - not listed as a state in the address classifier
		Result.Add(New Structure("FieldEntity, XPath", FieldEntityState, XPathState),
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'State ""%1"" is not listed as a state in the address classifier'"), 
				Data.State));
		Return;
	EndIf;
	
	// Checking whether the address classifier is imported for the state
	If Not AddressClassifierModule.AddressItemImported(Data.State) Then
		Result.Add(New Structure("FieldEntity, XPath", FieldEntityState, XPathState), 
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'The address classifier is not imported for state ""%1""'"),
				Data.State));
		Return;
	EndIf;
		
	// Checking the address parts for address classifier match
	CheckStructure = AddressClassifierModule.CheckAddressByAC(
		Data.Index, Data.State, Data.County, Data.City, Data.Settlement, Data.Street, 
		Data.Building, Data.Unit);
	If CheckStructure = Undefined Or Not CheckStructure.HasErrors Then
		// No errors discovered, the address is valid
		Return;
	EndIf;
	
	For Each Item In CheckStructure.ErrorsStructure Do
		AttributeName = Item.Key;
		If CheckAttributes.Property(AttributeName) Then
			Result.Add(
				New Structure("FieldEntity, XPath", Item.Value, CheckAttributes[AttributeName].XPath),
				Item.Value);
		Else
			Result.Add(
				New Structure("FieldEntity, XPath"),
				Item.Value);
		EndIf;
	EndDo;
	
EndProcedure

Function ObjectCodeByAddressPartsAddressClassifier(AddressParts, HideObsolete = False) 
	Var AddressPartValue;
	
	AddressClassifierModule = ServerModuleAddressClassifier();
	If AddressClassifierModule = Undefined Then
		Return Undefined;
	EndIf;
	
	If AddressParts.Property("Street", AddressPartValue) Then
		Street = TrimAll(AddressPartValue.Value);
	Else
		Street = "";
	EndIf;
	
	If AddressParts.Property("Settlement", AddressPartValue) Then
		Settlement = TrimAll(AddressPartValue.Value);
	Else
		Settlement = "";
	EndIf;
	
	If AddressParts.Property("City", AddressPartValue) Then
		City = TrimAll(AddressPartValue.Value);
	Else
		City = "";
	EndIf;
	
	If AddressParts.Property("County", AddressPartValue) Then
		County = TrimAll(AddressPartValue.Value);
	Else
		County = "";
	EndIf;
	
	If AddressParts.Property("State", AddressPartValue) Then
		State = TrimAll(AddressPartValue.Value);
	Else
		State = "";
	EndIf;
	
	AddressObj = New Structure("PostalCode, BuildingNumber, UnitNumber");
	AddressObj.Insert("State",      State);
	AddressObj.Insert("County",     County);
	AddressObj.Insert("City",       City);
	AddressObj.Insert("Settlement", Settlement);
	AddressObj.Insert("Street",     Street);
	
	AnalysisResults = AddressClassifierModule.AddressComplianceToClassifierAnalysis(AddressObj);
	Options = AnalysisResults.Options;
	If Not IsBlankString(Street) Then
		If Options.Find(AddressParts.Street.ClassifierCode, "Code") <> Undefined  Then
			Return AddressParts.Street.ClassifierCode;
		EndIf;
		
	ElsIf Not IsBlankString(Settlement) Then
		If Options.Find(AddressParts.Settlement.ClassifierCode, "Code") <> Undefined Then
			Return AddressParts.Settlement.ClassifierCode;
		EndIf;
		
	ElsIf Not IsBlankString(City) Then
		If Options.Find(AddressParts.City.ClassifierCode, "Code") <> Undefined Then
			Return AddressParts.City.ClassifierCode;
		EndIf;
		
	ElsIf Not IsBlankString(County) Then
		If Options.Find(AddressParts.County.ClassifierCode, "Code") <> Undefined Then
			Return AddressParts.County.ClassifierCode;
		EndIf;
		
	ElsIf Not IsBlankString(State) Then
		If Options.Find(AddressParts.State.ClassifierCode, "Code") <> Undefined Then
			Return AddressParts.State.ClassifierCode;
		EndIf;
		
	EndIf;
	
	Return Undefined;
EndFunction

Function StateCodeAddressClassifier(FullDescr)
	
	AddressClassifierModule = ServerModuleAddressClassifier();
	Query = AddressClassifierModule.QueryStateCodeAddressClassifier();
	
	Parameters = ContactInformationClientServer.DescriptionAbbreviation(FullDescr);
	Query.SetParameter("Description", Parameters.Description);
	Query.SetParameter("Abbr",   Parameters.Abbr);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Format(Selection.Code, "ND=2; NZ=; NLZ=");
	EndIf;
	
	Return "";
EndFunction

Function CodeStateAddressClassifier(Val Code)
	
	AddressClassifierModule = ServerModuleAddressClassifier();
	Query = AddressClassifierModule.QueryCodeStateAddressClassifier();
		
	If TypeOf(Code) = Type("Number") Then
		NumericCode = Code;
	Else 
		NumberType = New TypeDescription("Number");
		NumericCode = NumberType.AdjustValue(Code);
	EndIf;
	Query.SetParameter("Code", NumericCode);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.State;
	EndIf;
	
	Return "";
EndFunction

Function AllStatesAddressClassifier() 
	
	AddressClassifierModule = ServerModuleAddressClassifier();
	Query = AddressClassifierModule.QueryAllStatesAddressClassifier();
	
	Result = Query.Execute().Unload();
	Result.Indexes.Add("Code");
	Result.Indexes.Add("Presentation");
	
	Return Result;
EndFunction

Function DetermineAddressPostalCodeAddressClassifier(XDTOHomeCountryAddress)
	
	AddressClassifierModule = ServerModuleAddressClassifier();
	If AddressClassifierModule = Undefined Then
		Return Undefined;
	EndIf;
	
	Data = StructureAddressClassifierByDomesticAddress(XDTOHomeCountryAddress);
	
	Index = AddressClassifierModule.AddressPostalCode(
		Data.State, Data.County, Data.City, Data.Settlement, Data.Street, 
		Data.Building, Data.Unit);
		
	If Not IsBlankString(Index) Then
		Return TrimAll(Index);
	EndIf;
	
EndFunction

Function AddressesByClassifierPostalCode(Val Index, Val AdditionalSearchParameters = Undefined)
	
	SearchParameters = New Structure("HideObsolete, NumberOfRowsToSelect", False, 0);
	If AdditionalSearchParameters <> Undefined Then
		FillPropertyValues(SearchParameters, AdditionalSearchParameters);
	EndIf;
	
	HideObsolete = SearchParameters.HideObsolete;
	NumberOfRowsToSelect        = SearchParameters.NumberOfRowsToSelect;
	
	AddressClassifierModule = ServerModuleAddressClassifier();
	Query = AddressClassifierModule.QueryAddressByPostalCodeAddressClassifier(NumberOfRowsToSelect, HideObsolete);
	
	Query.SetParameter("PostalCode", TrimAll(Index));
	
	Results = Query.ExecuteBatch();
	
	// Common part of presentation
	Data = Results[2].Unload();
	Row = Data[0];
	PresentationCommonPart = ContactInformationClientServer.FullDescr(
		Row.StreetName, Row.StreetAbbr,
		Row.SettlementName, Row.SettlementAbbr,
		Row.CityName, Row.CityAbbr,
		Row.CountyName, Row.CountyAbbr,
		Row.StateName, Row.StateAbbr
	);
	CommonFields = New Structure;
	For Each Column In Data.Columns Do
		Name = Column.Name;
		If Not IsBlankString(Row[Name]) Then
			CommonFields.Insert(Name, "");
		EndIf;
	EndDo;
	
	// All results
	Data = Results[1].Unload();
	DataColumns = Data.Columns;
	DataColumns.Insert(0, "Presentation", New TypeDescription("String") );
	
	For Each Row In Data Do
		// Clearing the common fields
		FillPropertyValues(Row, CommonFields);
		// Generating a presentation based on the remaining fields
		Row.Presentation = ContactInformationClientServer.FullDescr(
			Row.StreetName, Row.StreetAbbr,
			Row.SettlementName, Row.SettlementAbbr,
			Row.CityName, Row.CityAbbr,
			Row.CountyName, Row.CountyAbbr,
			Row.StateName, Row.StateAbbr
		);
	EndDo;
	
	// Deleting the unnecessary columns
	Position = DataColumns.Count() - 1;
	While Position > 3 Do 
		DataColumns.Delete(Position);
		Position = Position - 1;
	EndDo;
	
	Return New Structure("Data, PresentationCommonPart, TooMuchData", Data, PresentationCommonPart,
		(NumberOfRowsToSelect > 0) And (Data.Count() > NumberOfRowsToSelect) );
EndFunction

// Value table constructor
Function ValueTable(ColumnList, IndexList = "")
	ResultTable = New ValueTable;
	
	For Each KeyValue In (New Structure(ColumnList)) Do
		ResultTable.Columns.Add(KeyValue.Key);
	EndDo;
	
	IndexRows = StrReplace(IndexList, "|", Chars.LF);
	For PostalCodeNumber = 1 To StrLineCount(IndexRows) Do
		IndexColumns = TrimAll(StrGetLine(IndexRows, PostalCodeNumber));
		For Each KeyValue In (New Structure(IndexColumns)) Do
			ResultTable.Indexes.Add(KeyValue.Key);
		EndDo;
	EndDo;
	
	Return ResultTable;
EndFunction

// Address item internal structure constructor
Function AddressStructureItem(Title, XPath, Value = Undefined, Predefined = False)
	Return New Structure("Title, XPath, Value, Predefined, Description, Abbr, ClassifierCode", 
		Title, XPath, Value, Predefined);
EndFunction

// Returns a string to be used for LIKE search
Function EscapeSpecialCharacters(Text)
	Result = Text;
	SpecialCharacter = "\";
	Service  = "%_[]^" + SpecialCharacter;
	For Index = 1 To StrLen(Service) Do
		Char = Mid(Service, Index, 1);
		Result = StrReplace(Result, Char, SpecialCharacter + Char);
	EndDo;
	Return Result;
EndFunction

Function AddressAttributeListAddressClassifier() 
	
	Result = AttributeListSettlementAddressClassifier();
	For Each KeyValue In AttributeListStreetAddressClassifier() Do
		Result.Insert(KeyValue.Key, KeyValue.Value);
	EndDo;
	
	// Index
	Result.Insert("Index", AddressStructureItem("Index", 
		ContactInformationClientServerCached.PostalCodeXPath()));
	// Building
	Result.Insert("Building", AddressStructureItem("Building",
		ContactInformationClientServerCached.AdditionalAddressingObjectNumberXPath("Building")));
	// Unit
	Result.Insert("Unit", AddressStructureItem("Unit", 
		ContactInformationClientServerCached.AdditionalAddressingObjectNumberXPath("Unit")));
	
	Return Result;
EndFunction

Function StructureAddressClassifierByDomesticAddress(XDTOHomeCountryAddress)
	Result = New Structure;
	
	// Fields listed in the address classifier
	Result.Insert("Index", AddressPostalCode(XDTOHomeCountryAddress));
	Result.Insert("State", XDTOHomeCountryAddress.Region);
	Result.Insert("County", AddressCounty(XDTOHomeCountryAddress));
	Result.Insert("City", XDTOHomeCountryAddress.City);
	Result.Insert("Settlement", XDTOHomeCountryAddress.Settlement);
	Result.Insert("Street", XDTOHomeCountryAddress.Street);
	
	BuildingTable = BuildingAddresses(XDTOHomeCountryAddress).Buildings;
	BuildingsTotal   = BuildingTable.Count();
	
	// Only building and unit numbers can be validated by the address classifier
	Building = Undefined;
	For Each Option In DataOptionsHouse().TypeOptions Do
		Row = BuildingTable.Find(Option, "Type");
		Building = ?(Row = Undefined, Undefined, Row.Value);
		If Not IsBlankString(Building) Then
			Break;
		EndIf;
	EndDo;
	Result.Insert("Building", Building);
	
	Unit = Undefined;
	For Each Option In DataOptionsUnit().TypeOptions Цикл
		Row = BuildingTable.Find(Option, "Type");
		Unit = ?(Row = Undefined, Undefined, Row.Value);
		If Not IsBlankString(Unit) Then
			Break;
		EndIf;
	EndDo;
	Result.Insert("Unit", Unit);
	
	Return Result;
EndFunction

// Internal, for serialization purposes
Function AddressDeserializationCommon(Val FieldValues, Val Presentation, Val ExpectedType = Undefined)
	
	If ContactInformationClientServer.IsXMLContactInformation(FieldValues) Then
		// Common format of contact information
		Return ContactInformationDeserialization(FieldValues, ExpectedType);
	EndIf;
	
	If ExpectedType <> Undefined Then
		If ExpectedType <> Enums.ContactInformationTypes.Address Then
			Raise NStr("en = 'Contact information deserialization error. Address is expected.'");
		EndIf;
	EndIf;
	
	// Old format, with string separator and exact match
	Namespace = ContactInformationClientServerCached.Namespace();
	
	Result = XDTOFactory.Create(XDTOFactory.Type(Namespace, "ContactInformation"));
	
	Result.Comment = "";
	Result.Content      = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Address"));
	
	AddressDomestic = True;
	HomeCountryName  = Upper(Catalogs.WorldCountries.USA.Description);
	
	ApartmentItem = Undefined;
	UnitItem   = Undefined;
	BuildingItem      = Undefined;
	
	// Domestic
	AddressUS = XDTOFactory.Create(XDTOFactory.Type(Namespace, "AddressUS"));
	
	// Common content
	Address = Result.Content;
	
	FieldValueType = TypeOf(FieldValues);
	If FieldValueType = Type("ValueList") Then
		FieldList = FieldValues;
	ElsIf FieldValueType = Type("Structure") Then
		FieldList = ContactInformationManagementClientServer.ConvertStringToFieldList(
			ContactInformationManagementClientServer.FieldRow(FieldValues, False));
	Else
		// Already transformed to a string
		FieldList = ContactInformationManagementClientServer.ConvertStringToFieldList(FieldValues);
	EndIf;
	
	ApartmentTypeUndefined = True;
	UnitTypeUndefined  = True;
	BuildingTypeUndefined     = True;
	PresentationField      = "";
	
	For Each ListItem In FieldList Do
		FieldName = Upper(ListItem.Presentation);
		
		If FieldName="POSTALCODE" Then
			PostalCodeItem = CreateAdditionalAddressItem(AddressUS);
			PostalCodeItem.AddressItemType = ContactInformationClientServerCached.PostalCodeSerializationCode();
			PostalCodeItem.Value = ListItem.Value;
			
		ElsIf FieldName = "COUNTRY" Then
			Address.Country = ListItem.Value;
			If Upper(ListItem.Value) <> HomeCountryName Then
				AddressDomestic = False;
			EndIf;
			
		ElsIf FieldName = "COUNTRYCODE" Then
			;
			
		ElsIf FieldName = "STATECODE" Then
			AddressUS.Region = CodeState(ListItem.Value);
			
		ElsIf FieldName = "STATE" Then
			AddressUS.Region = ListItem.Value;
			
		ElsIf FieldName = "COUNTY" Then
			If AddressUS.CountyMunicipalEntity = Undefined Then
				AddressUS.CountyMunicipalEntity = XDTOFactory.Create( AddressUS.Type().Properties.Get("CountyMunicipalEntity").Type )
			EndIf;
			AddressUS.CountyMunicipalEntity.County = ListItem.Value;
			
		ElsIf FieldName = "CITY" Then
			AddressUS.City = ListItem.Value;
			
		ElsIf FieldName = "SETTLEMENT" Then
			AddressUS.Settlement = ListItem.Value;
			
		ElsIf FieldName = "STREET" Then
			AddressUS.Street = ListItem.Value;
			
		ElsIf FieldName = "BUILDINGTYPE" Then
			If BuildingItem = Undefined Then
				BuildingItem = CreateAdditionalAddressItemNumber(AddressUS);
			EndIf;
			BuildingItem.Type = ContactInformationClientServerCached.AddressingObjectSerializationCode(ListItem.Value);
			BuildingTypeUndefined = False;
			
		ElsIf FieldName = "BUILDING" Then
			If BuildingItem = Undefined Then
				BuildingItem = CreateAdditionalAddressItemNumber(AddressUS);
			EndIf;
			BuildingItem.Value = ListItem.Value;
			
		ElsIf FieldName = "UNITTYPE" Then
			If UnitItem = Undefined Then
				UnitItem = CreateAdditionalAddressItemNumber(AddressUS);
			EndIf;
			UnitItem.Type = ContactInformationClientServerCached.AddressingObjectSerializationCode(ListItem.Value);
			UnitTypeUndefined = False;
			
		ElsIf FieldName = "UNIT" Then
			If UnitItem = Undefined Then
				UnitItem = CreateAdditionalAddressItemNumber(AddressUS);
			EndIf;
			UnitItem.Value = ListItem.Value;
			
		ElsIf FieldName = "APARTMENTTYPE" Then
			If ApartmentItem = Undefined Then
				ApartmentItem = CreateAdditionalAddressItemNumber(AddressUS);
			EndIf;
			ApartmentItem.Type = ContactInformationClientServerCached.AddressingObjectSerializationCode(ListItem.Value);
			ApartmentTypeUndefined = False;
			
		ElsIf FieldName = "APARTMENT" Then
			If ApartmentItem = Undefined Then
				ApartmentItem = CreateAdditionalAddressItemNumber(AddressUS);
			EndIf;
			ApartmentItem.Value = ListItem.Value;
			
		ElsIf FieldName = "PRESENTATION" Then
			PresentationField = TrimAll(ListItem.Value);
			
		EndIf;
		
	EndDo;
	
	// Default preferences
	If BuildingTypeUndefined And BuildingItem <> Undefined Then
		BuildingItem.Type = ContactInformationClientServerCached.AddressingObjectSerializationCode("Building");
	EndIf;
	
	If UnitTypeUndefined And UnitItem <> Undefined Then
		UnitItem.Type = ContactInformationClientServerCached.AddressingObjectSerializationCode("Unit");
	EndIf;
	
	If ApartmentTypeUndefined And ApartmentItem <> Undefined Then
		ApartmentItem.Type = ContactInformationClientServerCached.AddressingObjectSerializationCode("Apartment");
	EndIf;
	
	// Presentation with priorities
	If Not IsBlankString(Presentation) Then
		Result.Presentation = Presentation;
	Else
		Result.Presentation = PresentationField;
	EndIf;
	
	Address.Content = ?(AddressDomestic, AddressUS, Result.Presentation);
	
	Return Result;
EndFunction

// Returns a flag specifying whether the passed contact information object contains data.
//
// Parameters:
//     XDTOData - XDTODataObject - contact information data to be checked.
//
// Returns:
//     Boolean - data availability flag.
//
Function XDTOContactInformationFilled(Val XDTOData) Export
	
	Return HasFilledXDTOContactInformationProperies(XDTOData);
	
EndFunction

// Parameters: Owner - XDTODataObject, Undefined
//
Function HasFilledXDTOContactInformationProperies(Val Owner)
	
	If Owner = Undefined Then
		Return False;
	EndIf;
	
	// List of the current owner properties to be ignored during comparison - contact information specifics
	Ignored = New Map;
	
	Namespace = ContactInformationClientServerCached.Namespace();
	OwnerType     = Owner.Type();
	
	If OwnerType = XDTOFactory.Type(Namespace, "Address") Then
		// The country is irrelevant if other fields are empty. Ignoring
		Ignored.Insert(Owner.Properties().Get("Country"), True);
		
	ElsIf OwnerType = XDTOFactory.Type(Namespace, "AddressUS") Then
		// Ignoring lists with empty values and possibly non-empty types
		List = Owner.GetList("AdditionalAddressItem");
		If List <> Undefined Then
			For Each ListProperty In List Do
				If IsBlankString(ListProperty.Value) Then
					Ignored.Insert(ListProperty, True);
				EndIf;
			EndDo;
		EndIf;
		
	EndIf;
	
	For Each Property In Owner.Properties() Do
		
		If Not Owner.IsSet(Property) Or Ignored[Property] <> Undefined Then
			Continue;
		EndIf;
		
		If Property.UpperBound > 1 Or Property.UpperBound < 0 Then
			List = Owner.GetList(Property);
			
			If List <> Undefined Then
				For Each ListItem In List Do
					If Ignored[ListItem] = Undefined 
						And HasFilledXDTOContactInformationProperies(ListItem) 
					Then
						Return True;
					EndIf;
				EndDo;
			EndIf;
			
			Continue;
		EndIf;
		
		Value = Owner.Get(Property);
		If TypeOf(Value) = Type("XDTODataObject") Then
			If HasFilledXDTOContactInformationProperies(Value) Then
				Return True;
			EndIf;
			
		ElsIf Not IsBlankString(Value) Then
			Return True;
			
		EndIf;
		
	EndDo;
		
	Return False;
EndFunction

Procedure InsertUnit(XDTOAddress, Type, Value)
	If IsBlankString(Value) Then
		Return;
	EndIf;
	
	Write = XDTOAddress.Get( ContactInformationClientServerCached.AdditionalAddressingObjectNumberXPath(Type) );
	If Write = Undefined Then
		Write = XDTOAddress.AdditionalAddressItem.Add( XDTOFactory.Create(XDTOAddress.AdditionalAddressItem.OwningProperty.Type) );
		Write.Number = XDTOFactory.Create(Write.Properties().Get("Number").Type);
		Write.Number.Value = Value;
		
		TypeCode = ContactInformationClientServerCached.AddressingObjectSerializationCode(Type);
		If TypeCode = Undefined Then
			TypeCode = Type;
		EndIf;
		Write.Number.Type = TypeCode
	Else        
		Write.Value = Value;
	EndIf;
	
EndProcedure

Function CreateAdditionalAddressItemNumber(AddressUS)
	AdditionalAddressItem = CreateAdditionalAddressItem(AddressUS);
	AdditionalAddressItem.Number = XDTOFactory.Create(AdditionalAddressItem.Type().Properties.Get("Number").Type);
	Return AdditionalAddressItem.Number;
EndFunction

Function CreateAdditionalAddressItem(AddressUS)
	AdditionalAddressItemProperty = AddressUS.AdditionalAddressItem.OwningProperty;
	AdditionalAddressItem = XDTOFactory.Create(AdditionalAddressItemProperty.Type);
	AddressUS.AdditionalAddressItem.Add(AdditionalAddressItem);
	Return AdditionalAddressItem;
EndFunction

Function CountyMunicipalEntity(AddressUS)
	If AddressUS.CountyMunicipalEntity <> Undefined Then
		Return AddressUS.CountyMunicipalEntity;
	EndIf;
	
	AddressUS.CountyMunicipalEntity = XDTOFactory.Create( AddressUS.Properties().Get("CountyMunicipalEntity").Type );
	Return AddressUS.CountyMunicipalEntity;
EndFunction

Function AddressDeserializationByAddressClassifierPresentation(Val Presentation)
	
	Namespace = ContactInformationClientServerCached.Namespace();
	
	Result = XDTOFactory.Create(XDTOFactory.Type(Namespace, "ContactInformation"));
	Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Address"));
	Result.Presentation = Presentation;
	
	AnalysisData = AddressPartsAsTable(Presentation);
	If AnalysisData.Count() = 0 Then
		Return Result;
	EndIf;
	
	Address = Result.Content;
	
	AddressClassifierModule = ServerModuleAddressClassifier();
	Query = AddressClassifierModule.QueryAddressDeserializationByACPresentation();
	
	USAName = TrimAll(Catalogs.WorldCountries.USA.Description);
	
	Classifier = Catalogs.WorldCountries.ClassifierTable();
	
	Query.SetParameter("ClassifierCountries", Classifier.UnloadColumn("Description") );
	Query.SetParameter("AddressData", AnalysisData);
	Query.SetParameter("USAName", USAName);
	
	AnalysisResult = Query.Execute().Unload();
	
	AddressUS = XDTOFactory.Create(XDTOFactory.Type(Namespace, "AddressUS"));
	
	// Viewing in reverse order, so that the latest items are viewed first
	IsDomesticAddress = True;
	CountryString = Undefined;
	
	ProcessedLevels = New Map;
	EnteredInFreeFormat = False;
	
	BuildingUnitTable = New ValueTable;
	BuildingUnitTable.Columns.Add("Type");
	BuildingUnitTable.Columns.Add("Value");
	
	For Each Row In AnalysisResult Do
		// Going through the classifier with abbreviations, countries, postal codes
		If Row.FoundByPostalCode Then
			AddressPostalCode(AddressUS, Row.Value);
			Row.Processed = True;
			
		ElsIf Row.IsUSA Then
			IsDomesticAddress = True;
			Row.Processed  = True;
			CountryString  = Row;
			
		ElsIf Row.FoundInWorldCountries Then
			IsDomesticAddress = False;
			Row.Processed  = True;
			CountryString  = Row;
			
		ElsIf Row.FoundInClassifier Then
			Level = Row.LevelByClassifier;
			SetPartInAddressByLevelAddressClassifier(AddressUS, Level, Row.Value);
			Row.Processed = True;
			// Double processing control
			If ProcessedLevels[Level] <> Undefined Then
				EnteredInFreeFormat = True;
			EndIf;
			
		ElsIf Row.FoundInAbbreviations Then
			Level = Row.LevelByAbbreviations;
			SetPartInAddressByLevelAddressClassifier(AddressUS, Level, Row.Value);
			Row.Processed = True;
			// Double processing control
			If ProcessedLevels[Level] <> Undefined Then
				EnteredInFreeFormat = True;
			EndIf;
			
		Else
			// Checking for an apartment or building
			Type = TrimAll(StrReplace(Row.Description, "№", ""));
			If ContactInformationClientServerCached.AddressingObjectSerializationCode(Type) <> Undefined Then
				// Inserting into the beginning, due to the reverse order of query results
				NewRow        = BuildingUnitTable.Insert(0);
				NewRow.Value  = TrimAll(StrReplace(Row.Abbr, "№", ""));
				NewRow.Type   = Type;
				Row.Processed = True;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	// Checking the country
	If IsDomesticAddress Then
		Address.Country = USAName;
		Address.Content = AddressUS;
		
		Buildings = New Structure("Buildings", BuildingUnitTable, BuildingUnitTable);
		BuildingAddresses(AddressUS, Buildings);
		
		If EnteredInFreeFormat Or AnalysisResult.Find(False, "Processed") <> Undefined Then
			// Any remaining data is considered to be a free-format address data
			AddressUS.Address_by_document = Presentation;
		EndIf;
		
		Return Result;
	EndIf;
	
	// Foreign address
	If CountryString = Undefined Then
		Address.Content = Presentation;
	Else
		Address.Country = CountryString.Value;
		
		// The content does not include country, which remains in the presentation
		Position = CountryString.Beginning + CountryString.Length;
		Length   = StrLen(Presentation);
		Separators = "," + Chars.LF;
		While Position <= Length And Find(Separators, Mid(Presentation, Position, 1)) <= 0 Do
			Position = Position + 1;
		EndDo;
		While Position <= Length And Find(Separators, Mid(Presentation, Position, 1)) > 0 Do
			Position = Position + 1;
		EndDo;
		Address.Content = TrimAll( Left(Presentation, CountryString.Beginning -1 ) + " " + Mid(Presentation, Position) );
	EndIf;
	
	Return Result;
EndFunction

Function AddressPartsAsTable(Val Text)
	
	StringType = New TypeDescription("String", New StringQualifiers(128));
	NumberType  = New TypeDescription("Number");
	
	Result = New ValueTable;
	Columns = Result.Columns;
	Columns.Add("Position0",   NumberType);
	Columns.Add("Position",    NumberType);
	Columns.Add("Value",       StringType);
	Columns.Add("Description", StringType);
	Columns.Add("Abbr",        StringType);
	
	Columns.Add("Beginning", NumberType);
	Columns.Add("Length",    NumberType);
	
	Number = 0;
	For Each Term In TextWordsAsTable(Text, "," + Chars.LF) Do
		Value = TrimAll(Term.Value);
		If IsBlankString(Value) Then
			Continue;
		EndIf;
		
		Row = Result.Add();
		Row.Value = Value;
		
		Row.Position0 = Number;
		Number = Number + 1;
		Row.Position  = Number;
		
		Row.Beginning = Term.Beginning;
		Row.Length  = Term.Length;
		
		Position = StrLen(Value);
		While Position > 0 Do
			Char = Mid(Value, Position, 1);
			If IsBlankString(Char) Then
				Row.Description = Left(Value, Position-1);
				Break;
			EndIf;
			Row.Abbr = Char + Row.Abbr;
			Position = Position - 1;
		EndDo;
		
		If IsBlankString(Row.Description) Then
			Row.Description = Row.Abbr;
			Row.Abbr   = "";
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

Function TextWordsAsTable(Val Text, Val Separators = Undefined)
	
	WordStart = 0;
	State   = 0;
	
	StringType = New TypeDescription("String");
	NumberType  = New TypeDescription("Number");
	
	Result = New ValueTable;
	Columns = Result.Columns;
	Columns.Add("Value",     StringType);
	Columns.Add("Beginning", NumberType);
	Columns.Add("Length",    NumberType);
	
	For Position = 1 To StrLen(Text) Do
		CurrentChar = Mid(Text, Position, 1);
		IsSeparator = ?(Separators = Undefined, IsBlankString(CurrentChar), Find(Separators, CurrentChar) > 0);
		
		If State = 0 And (Not IsSeparator) Then
			WordStart = Position;
			State   = 1;
		ElsIf State = 1 And IsSeparator Then
			Row = Result.Add();
			Row.Beginning = WordStart;
			Row.Length  = Position-WordStart;
			Row.Value = Mid(Text, Row.Beginning, Row.Length);
			State = 0;
		EndIf;
	EndDo;
	
	If State = 1 Then
		Row = Result.Add();
		Row.Beginning = WordStart;
		Row.Length  = Position-WordStart;
		Row.Value = Mid(Text, Row.Beginning, Row.Length)
	EndIf;
	
	Return Result;
EndFunction

Procedure SetPartInAddressByLevelAddressClassifier(XDTOHomeCountryAddress, Val Level, Val Value)
	
	// XPath
	If Level = 1 Then
		Path = "Region";
	ElsIf Level = 2 Then
		Path = "CountyMunicipalEntity/County";
	ElsIf Level = 3 Then
		Path = "City";
	ElsIf Level = 4 Then
		Path = "Settlement";
	ElsIf Level = 5 Then
		Path = "Street";
	Else
		Return;
	EndIf;
	
	SetPropertyByXPath(XDTOHomeCountryAddress, Path, Value);
EndProcedure

Function PhoneFaxDeserialization(FieldValues, Presentation = "", ExpectedType = Undefined)
	
	If ContactInformationClientServer.IsXMLContactInformation(FieldValues) Then
		// Common format of contact information
		Return ContactInformationDeserialization(FieldValues, ExpectedType);
	EndIf;
	
	Namespace = ContactInformationClientServerCached.Namespace();
	
	If ExpectedType=Enums.ContactInformationTypes.Phone Then
		Data = XDTOFactory.Create(XDTOFactory.Type(Namespace, "PhoneNumber"));
		
	ElsIf ExpectedType=Enums.ContactInformationTypes.Fax Then
		Data = XDTOFactory.Create(XDTOFactory.Type(Namespace, "FaxNumber"));
		
	ElsIf ExpectedType=Undefined Then
		// This data is considered to be a phone number
		Data = XDTOFactory.Create(XDTOFactory.Type(Namespace, "PhoneNumber"));
		
	Else
		Raise NStr("en='Contact information deserialization error. A phone or fax number is expected'");
	EndIf;
	
	Result = XDTOFactory.Create(XDTOFactory.Type(Namespace, "ContactInformation"));
	Result.Content        = Data;
	
	// From key-value pairs
	FieldValueList = Undefined;
	If TypeOf(FieldValues)=Type("ValueList") Then
		FieldValueList = FieldValues;
	ElsIf Not IsBlankString(FieldValues) Then
		FieldValueList = ContactInformationManagementClientServer.ConvertStringToFieldList(FieldValues);
	EndIf;
	
	PresentationField = "";
	If FieldValueList <> Undefined Then
		For Each AttributeValue In FieldValueList Do
			Field = Upper(AttributeValue.Presentation);
			
			If Field = "COUNTRYCODE" Then
				Data.CountryCode = AttributeValue.Value;
				
			ElsIf Field = "AREACODE" Then
				Data.AreaCode = AttributeValue.Value;
				
			ElsIf Field = "PHONENUMBER" Then
				Data.Number = AttributeValue.Value;
				
			ElsIf Field = "EXTENSION" Then
				Data.Extension = AttributeValue.Value;
				
			ElsIf Field = "PRESENTATION" Then
				PresentationField = TrimAll(AttributeValue.Value);
				
			EndIf;
			
		EndDo;
		
		// Presentation with priorities
		If Not IsBlankString(Presentation) Then
			Result.Presentation = Presentation;
		Else
			Result.Presentation = PresentationField;
		EndIf;
		
		Return Result;
	EndIf;
	
	// Parsing the presentation
	
	// Digit groups separated by non-digit characters - country, city, number, extension. 
	// The extension is bracketed by non-whitespace characters.
	Position = 1;
	Data.CountryCode  = FindDigitSubstring(Presentation, Position);
	CityBeginning = Position;
	
	Data.AreaCode  = FindDigitSubstring(Presentation, Position);
	Data.Number      = FindDigitSubstring(Presentation, Position, " -");
	
	Extension = TrimAll(Mid(Presentation, Position));
	If Left(Extension, 1) = "," Then
		Extension = TrimL(Mid(Extension, 2));
	EndIf;
	If Upper(Left(Extension, 3 ))= "EXT" Then
		Extension = TrimL(Mid(Extension, 4));
	EndIf;
	If Upper(Left(Extension, 1 ))= "." Then
		Extension = TrimL(Mid(Extension, 2));
	EndIf;
	Data.Extension = TrimAll(Extension);
	
	// Fixing possible errors
	If IsBlankString(Data.Number) Then
		If Left(TrimL(Presentation),1)="+" Then
			// An attempt to specify the area code explicitly is detected. Leaving the area code "as is"
			Data.AreaCode  = "";
			Data.Number      = RemoveNonDigitCharacters(Mid(Presentation, CityBeginning));
			Data.Extension = "";
		Else
			Data.CountryCode  = "";
			Data.AreaCode  = "";
			Data.Number      = Presentation;
			Data.Extension = "";
		EndIf;
	EndIf;
	
	Result.Presentation = Presentation;
	Return Result;
EndFunction  

// Returns the first digit substring found in a string. 
// The StartPosition parameter is set to the position of the first non-digit character.
Function FindDigitSubstring(Text, StartPosition = Undefined, AllowedBesidesDigits = "")
	
	If StartPosition = Undefined Then
		StartPosition = 1;
	EndIf;
	
	Result = "";
	EndPosition = StrLen(Text);
	BeginningSearch  = True;
	
	While StartPosition <= EndPosition Do
		Char = Mid(Text, StartPosition, 1);
		IsDigit = Char >= "0" And Char <= "9";
		
		If BeginningSearch Then
			If IsDigit Then
				Result = Result + Char;
				BeginningSearch = False;
			EndIf;
		Else
			If IsDigit Or Find(AllowedBesidesDigits, Char) > 0 Then
				Result = Result + Char;    
			Else
				Break;
			EndIf;
		EndIf;
		
		StartPosition = StartPosition + 1;
	EndDo;
	
	// Discarding possible hanging separators to the right
	Return RemoveNonDigitCharacters(Result, AllowedBesidesDigits, False);
	
EndFunction

Function RemoveNonDigitCharacters(Text, AllowedBesidesDigits = "", Direction = True)
	
	Length = StrLen(Text);
	If Direction Then
		// Abbreviation on the left
		Index = 1;
		End  = 1 + Length;
		Step    = 1;
	Else
		// Abbreviation to the right    
		Index = Length;
		End  = 0;
		Step    = -1;
	EndIf;
	
	While Index <> End Do
		Char = Mid(Text, Index, 1);
		IsDigit = (Char >= "0" And Char <= "9") Or Find(AllowedBesidesDigits, Char) = 0;
		If IsDigit Then
			Break;
		EndIf;
		Index = Index + Step;
	EndDo;
	
	If Direction Then
		// Abbreviation on the left
		Return Right(Text, Length - Index + 1);
	EndIf;
	
	// Abbreviation to the right
	Return Left(Text, Index);
	
EndFunction

// Gets a deep property of the object.
Function PropertyByXPathValue(XTDOObject, XPath) Export
	
	// Line breaks are not expected in XPath
	PropertyString = StrReplace(StrReplace(XPath, "/", Chars.LF), Chars.LF + Chars.LF, "/");
	
	PropertyCount = StrLineCount(PropertyString);
	If PropertyCount = 1 Then
		Return XTDOObject.Get(PropertyString);
	EndIf;
	
	Result = ?(PropertyCount = 0, Undefined, XTDOObject);
	For Index = 1 To PropertyCount Do
		Result = Result.Get(StrGetLine(PropertyString, Index));     
		If Result = Undefined Then 
			Break;
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

// Sets a deep property of the object.
Procedure SetPropertyByXPath(XTDOObject, XPath, Value) Export
	
	// Line breaks are not expected in XPath
	PropertyString = StrReplace(StrReplace(XPath, "/", Chars.LF), Chars.LF + Chars.LF, "/");
	
	PropertyCount = StrLineCount(PropertyString);
	If PropertyCount = 1 Then
		XTDOObject.Set(PropertyString, Value);
		Return;
	ElsIf PropertyCount < 1 Then
		Return;
	EndIf;
		
	ParentObject = Undefined;
	CurrentObject      = XTDOObject;
	For Index = 1 To PropertyCount Do
		
		CurrentName = StrGetLine(PropertyString, Index);
		If CurrentObject.IsSet(CurrentName) Then
			ParentObject = CurrentObject;
			CurrentObject = CurrentObject.GetXDTO(CurrentName);
		Else
			NewType = CurrentObject.Properties().Get(CurrentName).Type;
			TypeType = TypeOf(NewType);
			If TypeType = Type("XDTOObjectType") Then
				NewObject = XDTOFactory.Create(NewType);
				CurrentObject.Set(CurrentName, NewObject);
				ParentObject = CurrentObject;
				CurrentObject = NewObject; 
			ElsIf TypeType = Type("XDTOValueType") Then
				// Immediate value
				CurrentObject.Set(CurrentName, Value);
				ParentObject = Undefined;
				Break;
			EndIf;
		EndIf;
	EndDo;
	
	If ParentObject <> Undefined Then
		ParentObject.Set(CurrentName, Value);
	EndIf;
	
EndProcedure

#EndRegion