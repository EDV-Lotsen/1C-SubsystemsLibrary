////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Contact information subsystem.
// 
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

// Compares two XML data strings, returns a value table as comparison result.
//
// Parameters:
//    Text1 - String - XML data.
//    Text2 - String - XML data.
//
// Returns:
//    ValueTable with the following columns:
//        * Path   - String - XPath path to difference position.
//        * Value1 - String - XML value based on Text1 parameter.
//        * Value2 - String - XML value based on Text2 parameter.
//
Function DifferencesXML(Val Text1, Val Text2) Export
	Return ValueFromXMLString( XSLT_ValueTableDifferencesXML(Text1, Text2) );
EndFunction

// Returns a value of ContactInformationTypes enumeration by XML string.
//
// Parameters:
//    XMLString - string describing the contact information.
//
// Returns:
//     EnumRef.ContactInformationTypes - result.
//
Function ContactInformationType(Val XMLString) Export
	Return ValueFromXMLString( XSLT_ContactInformationTypeByXMLString(XMLString) );
EndFunction

// Reads a content string from the contact information value.
// If the content value has composite type, returns Undefined.
//
// Parameters:
//    Text - String - contact information XML string. Can be modified.
//
// Returns:
//    String    - XML content value.
//    Undefined - Content property not found.
//
Function ContactInformationContentString(Val Text, Val NewValue = Undefined) Export
	Read = New XMLReader;
	Read.SetString(Text);
	XDTODataObject= XDTOFactory.ReadXML(Read, 
		XDTOFactory.Type(ContactInformationClientServerCached.Namespace(), "ContactInformation"));
	
	Content = XDTODataObject.Content;
	If Content <> Undefined 
		And Content.Properties().Get("Value") <> Undefined
		And TypeOf(Content.Value) = Type("String") 
	Then
		Return Content.Value;
	EndIf;
	
	Return Undefined;
EndFunction

// Transforms a string containing one or several key-value pairs 
// (see obsolete address format for details) into a structure.
//
// Parameters:
//    Text - String - key-value pairs separated by line breaks.
//
// Returns:
//    Structure - transformation result.
//
Function KeyValueStringToStructure(Val Text) Export
	Return ValueFromXMLString( XSLT_KeyValueStringToStructure(Text) );
EndFunction

// Transforms a string containing one or several key-value pairs 
// (see obsolete address format for details) into a value list.
// In the returned value list, presentation is the source key, and value is the source value.
//
// Parameters:
//    Text            - String  - key-value pairs separated by line breaks.
//    FieldUniqueness - Boolean - flag specifying that only the last duplicate key is kept.
//
// Returns:
//    ValueList - transformation result.
// 
Function KeyValueStringToValueList(Val Text, Val FieldUniqueness = True) Export
	If FieldUniqueness Then
		Return ValueFromXMLString( XSLT_UniqueByListPresentation(XSLT_KeyValueStringToValueList(Text)) );
	EndIf;
	Return ValueFromXMLString( XSLT_KeyValueStringToValueList(Text) );
EndFunction

// Transforms a structure to a string of comma-separated key-value pairs.
//
// Parameters:
//    Structure - Structure - source structure.
//
// Returns:
//    String - transformation result.
// 
Function StructureToKeyValueString(Val Structure) Export
	Return XSLT_StructureToKeyValueString( ValueToXMLString(Structure) );
EndFunction

// Transforms a value list to a string of comma-separated key-value pairs.
//
// Parameters:
//    List - ValueList - source data.
//
// Returns:
//    String - transformation result.
// 
Function ValueListToKeyValueString(Val List) Export
	Return XSLT_ValueListToKeyValueString( ValueToXMLString(List) );
EndFunction

// Transforms a structure to a value list. Transforms key to presentation.
//
// Parameters:
//    Structure - Structure - source structure.
//
// Returns:
//    ValueList - transformation result.
//
Function StructureToValueList(Val Structure) Export
	Return ValueFromXMLString( XSLT_StructureToValueList( ValueToXMLString(Structure) ) );
EndFunction

// Transforms a value list to a structure. Transforms presentation to key.
//
// Parameters:
//    List - ValueList - source data.
//
// Returns:
//    Structure - transformation result.
//
Function ValueListToStructure(Val List) Export
	Return ValueFromXMLString( XSLT_ValueListToStructure( ValueToXMLString(List) ) );
EndFunction

// Compares two sets of contact information.
//
// Parameters:
//    Data1 - XTDOObject - object containing contact information.
//          - String     - contact information in XML format.
//          - Structure  - contact information description. The following fields are expected:
//                 * FieldValues - String, Structure, ValueList, Map - contact information fields. 
//                 * Presentation - String - presentation. Used when presentation cannot
//                   be extracted from FieldValues (no Presentation field there). 
//                 * Comment - String - comment. Used when comment cannot be extracted from
//                   FieldValues. 
//                 * ContactInformationKind - CatalogRef.ContactInformationKinds,
//                   EnumRef.ContactInformationTypes, Structure -
//                   used when type cannot be extracted from FieldValues.
//    Data2 - XTDOObject, String, Structure - similar to Data1.
//
// Returns:
//     ValueTable - table of different fields, with the following columns:
//        * Path        - String - XPath identifying the value difference. ContactInformationType value
//                                 specifies that passed contact information sets have different types.
//        * Description - String - description of the differing attribute in terms 
//                                 of application business logic.
//        * Value1      - String - value matching the object passed in Data1 parameter.
//        * Value2      - String - value matching the object passed in Data2 parameter.
//
Function ContactInformationDifferences(Val Data1, Val Data2) Export
	ContactInformationData1 = TransformContactInformationXML(Data1);
	ContactInformationData2 = TransformContactInformationXML(Data2);
	
	ContactInformationType = ContactInformationData1.ContactInformationType;
	If ContactInformationType <> ContactInformationData2.ContactInformationType Then
		// Type mismatch, comparison canceled
		Result = New ValueTable;
		Columns   = Result.Columns;
		ResultRow = Result.Add();
		ResultRow[Columns.Add("Path").Name]      = "ContactInformationType";
		ResultRow[Columns.Add("Value1").Name] = ContactInformationData1.ContactInformationType;
		ResultRow[Columns.Add("Value2").Name] = ContactInformationData2.ContactInformationType;
		ResultRow[Columns.Add("Description").Name]  = NStr("en = 'Contact information type mismatch'");
		Return Result;
	EndIf;
	
	TextXMLDifferences = XSLT_ValueTableDifferencesXML(ContactInformationData1.XMLData, ContactInformationData2.XMLData);
	
	// Providing interpretation depending on type
	Return ValueFromXMLString( XSLT_ContactInformationXMLDifferenceInterpretation(
			TextXMLDifferences, ContactInformationType));
	
EndFunction

// Transforms contact information to an XML string.
//
// Parameters:
//    Data - String     - contact information description.
//         - XTDOObject - contact information description.
//         - Structure  - contact information description. The following fields are expected:
//              * FieldValues - String, Structure, ValueList, Map - contact information fields.
//              * Presentation - String - presentation. Used when presentation cannot
//                be extracted from FieldValues (no Presentation field there).
//              * Comment - String - comment. Used when comment cannot be extracted from FieldValues.
//              * ContactInformationKind - CatalogRef.ContactInformationKinds, 
//                EnumRef.ContactInformationTypes, Structure -
//                used when type cannot be extracted from FieldValues.
//
// Returns:
//     Structure - containing fields:
//        * ContactInformationType - Enum.ContactInformationTypes.
//        * XMLData                - String - XML string.
//
Function TransformContactInformationXML(Val Data) Export
	If IsXMLString(Data) Then
		Return New Structure("XMLData, ContactInformationType",
			Data, ValueFromXMLString( XSLT_ContactInformationTypeByXMLString(Data) ));
		
	ElsIf TypeOf(Data) = Type("XDTODataObject") Then
		XMLData = ContactInformationInternal.ContactInformationSerialization(Data);
		Return New Structure("XMLData, ContactInformationType",
			XMLData, ValueFromXMLString( XSLT_ContactInformationTypeByXMLString(XMLData) ));
		
	EndIf;
		
	// Expecting structure
	Comment = Undefined;
	Data.Property("Comment", Comment);
	
	FieldValues = Data.FieldValues;
	If IsXMLString(FieldValues) Then 
		// It may be necessary to redefine the comment
		If Not IsBlankString(Comment) Then
			ContactInformationInternal.ContactInformationComment(FieldValues, Comment);
		EndIf;
		
		Return New Structure("XMLData, ContactInformationType",
			FieldValues, ValueFromXMLString( XSLT_ContactInformationTypeByXMLString(FieldValues) ));
		
	EndIf;
	
	// Parsing by FieldValues, ContactInformationKind, Presentation
	FieldValueType = TypeOf(FieldValues);
	If FieldValueType = Type("String") Then
		// Text contained in key-value pairs
		XMLStructureString = XSLT_KeyValueStringToStructure(FieldValues)
		
	ElsIf FieldValueType = Type("ValueList") Then
		// Value list
		XMLStructureString = XSLT_ValueListToStructure( ValueToXMLString(FieldValues) );
		
	ElsIf FieldValueType = Type("Map") Then
		// Map
		XMLStructureString = XSLT_MapToStructure( ValueToXMLString(FieldValues) );
		
	Else
		// Expecting structure
		XMLStructureString = ValueToXMLString(FieldValues);
		
	EndIf;
	
	// Parsing by ContactInformationKind
	ContactInformationType = ContactInformationManagement.ContactInformationKindType(Data.ContactInformationKind);
	
	Result = New Structure("ContactInformationType, XMLData", ContactInformationType);
	
	AllTypes = Enums.ContactInformationTypes;
	If ContactInformationType = AllTypes.Address Then
		Result.XMLData = XSLT_StructureToAddress(XMLStructureString, Data.Presentation, Comment);
		
	ElsIf ContactInformationType = AllTypes.EmailAddress Then
		Result.XMLData = XSLT_StructureToEmailAddress(XMLStructureString, Data.Presentation, Comment);
		
	ElsIf ContactInformationType = AllTypes.WebPage Then
		Result.XMLData = XSLT_StructureToWebPage(XMLStructureString, Data.Presentation, Comment);
		
	ElsIf ContactInformationType = AllTypes.Phone Then
		Result.XMLData = XSLT_StructureToPhone(XMLStructureString, Data.Presentation, Comment);
		
	ElsIf ContactInformationType = AllTypes.Fax Then
		Result.XMLData = XSLT_StructureToFax(XMLStructureString, Data.Presentation, Comment);
		
	ElsIf ContactInformationType = AllTypes.Other Then
		Result.XMLData = XSLT_StructureToOther(XMLStructureString, Data.Presentation, Comment);
		
	Else
		Raise NStr("en = 'Transformation parameter error, contact information type not specified'");
		
	EndIf;
	
	Return Result;
EndFunction

#EndRegion

#Region InternalProceduresAndFunctions

// Transforms a value list, keeping only the last key-value pair values, by presentation key.
//
// Parameters:
//    Text - String - serialized value list.
//
// Returns:
//     String - serialized value list XML string.
//
Function XSLT_UniqueByListPresentation(Val Text)
	Transformer = ContactInformationInternalCached.XSLT_UniqueByListPresentation();
	Return Transformer.TransformFromString(Text);
EndFunction

// Compares two XML strings.
// Only strings and attributes are compared; whitespace characters, CDATA, and so on, are ignored. 
// Comparison is performed in order.
//
// Parameters:
//    Text1 - String - XML string.
//    Text2 - String - XML string.
//
// Returns:
//    String - serialized ValueTable (http://v8.1c.ru/8.1/data/core) with 3 columns:
//       * Path   - String - path to difference position.
//       * Value1 - String - value based on Text1 parameter.
//       * Value2 - String - value based on Text2 parameter.
//
Function XSLT_ValueTableDifferencesXML(Text1, Text2)
	Transformer = ContactInformationInternalCached.XSLT_ValueTableDifferencesXML();
	
	Builder = New TextDocument;
	Builder.AddLine("<dn><f>");
	Builder.AddLine( XSLT_DeleteDescriptionXML(Text1) );
	Builder.AddLine("</f><s>");
	Builder.AddLine( XSLT_DeleteDescriptionXML(Text2) );
	Builder.AddLine("</s></dn>");
	
	Return Transformer.TransformFromString( Builder.GetText() );
EndFunction

// Transforms a text containing key-value pairs separated by line breaks (see address format) 
//  to an XML string.
// If duplicate keys are encountered, all of them are included in the output 
//  but only the last one is used during deserialization, due to platform serialization logic.
//
// Parameters:
//    Text - String - key-value pairs.
//
// Returns:
//     String  - serialized structure XML string.
//
Function XSLT_KeyValueStringToStructure(Val Text) 
	Transformer = ContactInformationInternalCached.XSLT_KeyValueStringToStructure();
	Return Transformer.TransformFromString( XSLT_ParameterStringNode(Text) );
EndFunction

// Transforms a text containing key-value pairs separated by line breaks (see address format) 
//  to an XML string.
// If duplicate keys are encountered, all of them are included in the output.
//
// Parameters:
//    Text - String - key-value pairs.
//
// Returns:
//    String  - serialized value list XML string.
//
Function XSLT_KeyValueStringToValueList(Val Text)
	Transformer = ContactInformationInternalCached.XSLT_KeyValueStringToValueList();
	Return Transformer.TransformFromString( XSLT_ParameterStringNode(Text) );
EndFunction

// Transforms a value list to a string containing key-value pairs separated by line breaks.
//
// Parameters:
//    Text - String - serialized value list.
//
// Returns:
//    String - transformation result.
//
Function XSLT_ValueListToKeyValueString(Val Text)
	Transformer = ContactInformationInternalCached.XSLT_ValueListToKeyValueString();
	Return Transformer.TransformFromString(Text);
EndFunction

// Transforms a structure to a string of key-value pairs separated by line breaks.
//
// Parameters:
//    Text - String - serialized structure.
//
// Returns:
//    String - transformation result.
//
Function XSLT_StructureToKeyValueString(Val Text)
	Transformer = ContactInformationInternalCached.XSLT_StructureToKeyValueString();
	Return Transformer.TransformFromString(Text);
EndFunction

// Transforms a value list to a structure. Transforms presentation to key.
//
// Parameters:
//    Text - String - serialized value list.
//
// Returns:
//    String - transformation result.
//
Function XSLT_ValueListToStructure(Text)
	Transformer = ContactInformationInternalCached.XSLT_ValueListToStructure();
	Return Transformer.TransformFromString(Text);
EndFunction

// Transforms a structure to a value list. Transforms key to presentation.
//
// Parameters:
//    Text - String - serialized structure.
//
// Returns:
//    String - transformation result.
//
Function XSLT_StructureToValueList(Text)
	Transformer = ContactInformationInternalCached.XSLT_StructureToValueList();
	Return Transformer.TransformFromString(Text);
EndFunction

// Transforms a map to a structure. Transforms key to key, value to value.
//
// Parameters:
//    Text - String - serialized map.
//
// Returns:
//    String - transformation result.
//
Function XSLT_MapToStructure(Text)
	Transformer = ContactInformationInternalCached.XSLT_MapToStructure();
	Return Transformer.TransformFromString(Text);
EndFunction

// Analyzes Path-Value1-Value2 table for the specified contact information kind.
//
// Parameters:
//    Text                   - String - XML string with ValueTable obtained from the XML comparison result.
//    ContactInformationType - EnumRef.ContactInformationTypes  - type value (from the enumeration).
//
// Returns:
//    String - serialized table containing values of differing fields.
//
Function XSLT_ContactInformationXMLDifferenceInterpretation(Val Text, Val ContactInformationType) 
	Transformer = ContactInformationInternalCached.XSLT_ContactInformationXMLDifferenceInterpretation(
		ContactInformationType);
	Return Transformer.TransformFromString(Text);
EndFunction

// Transforms a structure to a contact information XML string.
//
// Parameters:
//    Text         - String - serialized structure.
//    Presentation - String - presentation (optional). 
//       Used only if the structure contains no presentation field.
//    Comment      - String - comment (optional). 
//       Used only if the structure contains no comment field.
//
// Returns:
//    String - contact information XML string.
//
Function XSLT_StructureToAddress(Val Text, Val Presentation = Undefined, Val Comment = Undefined)
	Transformer = ContactInformationInternalCached.XSLT_StructureToAddress();
	Return XSLT_PresentationAndCommentControl(
		Transformer.TransformFromString(Text),
		Presentation, Comment);
EndFunction

// Transforms a structure to a contact information XML string.
//
// Parameters:
//    Text         - String - serialized structure.
//    Presentation - String - presentation (optional). 
//                   Used only if the structure contains no presentation field.
//    Comment      - String - comment (optional). 
//                   Used only if the structure contains no comment field.
//
// Returns:
//    String - contact information XML string.
//
Function XSLT_StructureToEmailAddress(Val Text, Val Presentation = Undefined, Val Comment = Undefined)
	Transformer = ContactInformationInternalCached.XSLT_StructureToEmailAddress();
	
	Return XSLT_PresentationAndCommentControl(
		XSLT_SimpleTypeStringValueControl(Transformer.TransformFromString(Text), Presentation), 
		Presentation, Comment
	);
EndFunction

// Transforms a structure to contact information XML string.
//
// Parameters:
//    Text         - String - serialized structure.
//    Presentation - String - presentation (optional). 
//                   Used only if the structure contains no presentation field. 
//    Comment      - String - comment (optional). 
//                   Used only if the structure contains no comment field.
//
// Returns:
//    String - contact information XML string.
//
Function XSLT_StructureToWebPage(Val Text, Val Presentation = Undefined, Val Comment = Undefined)
	Transformer = ContactInformationInternalCached.XSLT_StructureToWebPage();
	
	Return XSLT_PresentationAndCommentControl(
		XSLT_SimpleTypeStringValueControl( Transformer.TransformFromString(Text), Presentation),
		Presentation, Comment);
EndFunction

// Transforms a structure to a contact information XML string.
//
// Parameters:
//    Text         - String - serialized structure.
//    Presentation - String - presentation (optional). 
//                   Used only if the structure contains no presentation field. 
//    Comment      - String - comment (optional). 
//                   Used only if the structure contains no comment field.
//
// Returns:
//    String - contact information XML string.
//
Function XSLT_StructureToPhone(Val Text, Val Presentation = Undefined, Val Comment = Undefined)
	Transformer = ContactInformationInternalCached.XSLT_StructureToPhone();
	Return XSLT_PresentationAndCommentControl(
		Transformer.TransformFromString(Text),
		Presentation, Comment);
EndFunction

// Transforms a structure to a contact information XML string.
//
// Parameters:
//    Text         - String - serialized structure.
//    Presentation - String - presentation (optional). 
//                   Used only if the structure contains no presentation field. 
//    Comment      - String - comment (optional). 
//                   Used only if the structure contains no comment field.
//
// Returns:
//    String - contact information XML string.
//
Function XSLT_StructureToFax(Val Text, Val Presentation = Undefined, Val Comment = Undefined)
	Transformer = ContactInformationInternalCached.XSLT_StructureToFax();
	Return XSLT_PresentationAndCommentControl(
		Transformer.TransformFromString(Text),
		Presentation, Comment);
EndFunction

// Transforms a structure to a contact information XML string.
//
// Parameters:
//    Text         - String - serialized structure.
//    Presentation - String - presentation (optional). 
//                   Used only when structure contains no presentation field. 
//    Comment      - String - comment (optional). 
//                   Used only when structure contains no comment field.
//
// Returns:
//    String - contact information XML string.
//
Function XSLT_StructureToOther(Val Text, Val Presentation = Undefined, Val Comment = Undefined)
	Transformer = ContactInformationInternalCached.XSLT_StructureToOther();
	
	Return XSLT_PresentationAndCommentControl(
		XSLT_SimpleTypeStringValueControl( Transformer.TransformFromString(Text), Presentation),
		Presentation, Comment);
EndFunction

// Sets presentation and comment in the contact information if they are not filled.
//
// Parameters:
//    Text         - String - serialized structure.
//    Presentation - String - presentation (optional). 
//                   Used only if the structure contains no presentation field. 
//    Comment      - String - comment (optional). 
//                   Used only if the structure contains no comment field.
//
// Returns:
//    String - contact information XML string.
//
Function XSLT_PresentationAndCommentControl(Val Text, Val Presentation = Undefined, Val Comment = Undefined)
	If Presentation = Undefined And Comment = Undefined Then
		Return Text;
	EndIf;
	
	XSLT_Text = New TextDocument;
	XSLT_Text.AddLine("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:tns=""http://www.v8.1c.ru/ssl/contactinfo""
		|  xmlns=""http://www.v8.1c.ru/ssl/contactinfo"" 
		|>
		|  <xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|
		|  <xsl:template match=""node() | @*"">
		|    <xsl:copy>
		|      <xsl:apply-templates select=""node() | @*"" />
		|    </xsl:copy>
		|  </xsl:template>
		|");
		
	If Presentation <> Undefined Then
		XSLT_Text.AddLine("
		|  <xsl:template match=""tns:ContactInformation/@Presentation"">
		|    <xsl:attribute name=""Presentation"">
		|      <xsl:choose>
		|        <xsl:when test="".=''"">" + NormalizedStringXML(Presentation) + "</xsl:when>
		|        <xsl:otherwise>
		|          <xsl:value-of select="".""/>
		|        </xsl:otherwise>
		|      </xsl:choose>
		|    </xsl:attribute>
		|  </xsl:template>
		|");
	EndIf;
	
	If Comment <> Undefined Then
		XSLT_Text.AddLine("
		|  <xsl:template match=""tns:ContactInformation/tns:Comment"">
		|    <xsl:element name=""Comment"">
		|      <xsl:choose>
		|        <xsl:when test="".=''"">" + NormalizedStringXML(Comment) + "</xsl:when>
		|        <xsl:otherwise>
		|          <xsl:value-of select="".""/>
		|        </xsl:otherwise>
		|      </xsl:choose>
		|    </xsl:element>
		|  </xsl:template>
		|");
	EndIf;
		XSLT_Text.AddLine("
		|</xsl:stylesheet>
		|");
		
	Transformer = New XSLTransform;
	Transformer.LoadFromString( XSLT_Text.GetText() );
	
	Return Transformer.TransformFromString(Text);
EndFunction

// Sets Content.Value part of contact information to the passed presentation.
// If Presentation is undefined, no action is performed. 
// Otherwise checks whether Content is empty. 
// If Content is empty and Content.Value attribute is also empty, 
//  the presentation value is added to the content.
//
// Parameters:
//    Text         - String - contact information XML string.
//    Presentation - String - presentation to be set.
//
// Returns:
//    String - contact information XML string.
//
Function XSLT_SimpleTypeStringValueControl(Val Text, Val Presentation)
	If Presentation = Undefined Then
		Return Text;
	EndIf;
	
	Transformer = New XSLTransform;
	Transformer.LoadFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:tns=""http://www.v8.1c.ru/ssl/contactinfo""
		|>
		|  <xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|  
		|  <xsl:template match=""node() | @*"">
		|    <xsl:copy>
		|      <xsl:apply-templates select=""node() | @*"" />
		|    </xsl:copy>
		|  </xsl:template>
		|  
		|  <xsl:template match=""tns:ContactInformation/tns:Content/@Value"">
		|    <xsl:attribute name=""Value"">
		|      <xsl:choose>
		|        <xsl:when test="".=''"">" + NormalizedStringXML(Presentation) + "</xsl:when>
		|        <xsl:otherwise>
		|          <xsl:value-of select="".""/>
		|        </xsl:otherwise>
		|      </xsl:choose>
		|    </xsl:attribute>
		|  </xsl:template>
		|
		|</xsl:stylesheet>
		|");
	
	Return Transformer.TransformFromString(Text);
EndFunction

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Returns an XML fragment to be inserted to an XML string, in <Node>String<Node> format.
//
// Parameters:
//    Text        - String - fragment to be inserted to an XML string.
//    ElementName - String - external node name (optional).
//
// Returns:
//    String - resulting XML string.
//
Function XSLT_ParameterStringNode(Val Text, Val ElementName = "ExternalParamNode")
	// Writing XML to escape special characters
	Write = New XMLWriter;
	Write.SetString();
	Write.WriteStartElement(ElementName);
	Write.WriteText(Text);
	Write.WriteEndElement();
	Return Write.Close();
EndFunction

// Returns an XML string without <?xml...> description, to be inserted into another XML string.
//
// Parameters:
//    Text - String - source XML string.
//
// Returns:
//    String - resulting XML string.
//
Function XSLT_DeleteDescriptionXML(Val Text)
	Transformer = ContactInformationInternalCached.XSLT_DeleteDescriptionXML();
	Return Transformer.TransformFromString(TrimL(Text));
EndFunction

// Transforms a contact information XML string to a type enumeration.
//
// Parameters:
//    Text - String - source XML string.
//
// Returns:
//    String - serialized ContactInformationTypes enumeration value.
//
Function XSLT_ContactInformationTypeByXMLString(Val Text)
	Transformer = ContactInformationInternalCached.XSLT_ContactInformationTypeByXMLString();
	Return Transformer.TransformFromString(TrimL(Text));
EndFunction

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//  Returns a flag specifying whether a text is in XML format.
//
//  Parameters:
//      Text - String - text to be checked.
//
// Returns:
//      Boolean - check result.
//
Function IsXMLString(Text)
	Return TypeOf(Text) = Type("String") And Left(TrimL(Text),1) = "<";
EndFunction

// Deserializer of types registered with the platform.
Function ValueFromXMLString(Val Text)
	XMLReader = New XMLReader;
	XMLReader.SetString(Text);
	Return XDTOSerializer.ReadXML(XMLReader);
EndFunction

// Serializer of types registered with the platform.
Function ValueToXMLString(Val Value)
	XMLWriter = New XMLWriter;
	XMLWriter.SetString(New XMLWriterSettings(, , False, False, ""));
	XDTOSerializer.WriteXML(XMLWriter, Value, XMLTypeAssignment.Explicit);
	// Platform serializer allows writing line breaks to attribute values.
	Return StrReplace(XMLWriter.Close(), Chars.LF, "&#10;");
EndFunction

// Intended for processing attributes containing line breaks.
//
// Parameters:
//     Text - String - XML string to be modified.
//
// Returns:
//     String - normalized string.
//
Function MultilineXMLString(Val Text)
	
	Return StrReplace(Text, Chars.LF, "&#10;");
	
EndFunction

// Prepares a string for insertion to an XML string by removing special characters.
//
// Parameters:
//     Text - String - XML string to be modified.
//
// Returns:
//     String - normalized string.
//
Function NormalizedStringXML(Val Text)
	
	Result = StrReplace(Text,   """", "&quot;");
	Result = StrReplace(Result, "&",  "&amp;");
	Result = StrReplace(Result, "'",  "&apos;");
	Result = StrReplace(Result, "<",  "&lt;");
	Result = StrReplace(Result, ">",  "&gt;");
	
	Return MultilineXMLString(Result);
EndFunction
#EndRegion
