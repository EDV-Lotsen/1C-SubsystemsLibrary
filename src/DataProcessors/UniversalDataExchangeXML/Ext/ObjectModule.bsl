#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then


////////////////////////////////////////////////////////////////////////////////
// VARIABLE NAME ACRONYMS (ABBREVIATIONS).

// OCR  - object conversion rule;
// PCR  - object property conversion rule;
// PGCR - object property group conversion rule;
// VCR  - object value conversion rule;
// DER  - data export rule;
// DCR  - data clearing rule.



////////////////////////////////////////////////////////////////////////////////
// AUXILIARY MODULE VARIABLES THAT ARE USED FOR CREATING ALGORITHMS (BOTH FOR IMPORT AND EXPORT).

Var Conversion                        Export;  // Conversion property structure 
                                               // (Name, ID, exchange event handlers).
 
Var Algorithms                        Export;  // Structure that contains algorithms 
                                               // to be used.
Var Queries                           Export;  // Structure that contains queries to
                                               // used.
Var AdditionalDataProcessors          Export;  // Structure that contains external 
                                               // data processors to be used.
 
Var Rules                             Export;  // Structure that contains OCR 
                                               // references.
 
Var Managers                          Export;  // Map with the following fields:  
                                               // Name, TypeName, RefTypeString, 
                                               // Manager, MDObject, OCR.
Var ManagersForExchangePlans          Export;
Var ExchangeFile                      Export;  // Exchange file to be consistently
                                               // written/read. 
 
Var AdditionalDataProcessorParameters Export;  // Structure that contains external
                                               // processor parameters.
 
Var ParametersInitialized             Export;  // True if the required parameters have
                                               // been initialized.
 
Var mDataLogFile                      Export;  // Data exchange log file.
Var CommentObjectProcessingFlag       Export;
 
Var EventHandlerExternalDataProcessor Export;  // ExternalDataProcessorsManager object
                                               // for calling export procedures during
                                               // export/import debugging.
 
Var CommonProceduresFunctions;                 // Reference to the current instance of 
                                               // the data processor (ThisObject).
                                               // Is required for calling export 
                                               // procedures from event handlers.
 
Var mHandlerParameterTemplate;                 // Tabular document with handler
                                               // parameters.
Var mCommonProceduresFunctionsTemplate;        // Text document with comments,
                                               // global variables, and wrappers of
                                               // common procedures and functions.
 
Var mDataProcessingModes;                      // Structure that contains available data
                                               // processing modes.
Var DataProcessingMode;                        // Current data processing mode value.
 
Var mAlgorithmDebugModes;                      // Structure that contains algorithm
                                               // debugging modes.
Var IntegratedAlgorithms;                      // Structure that contains algorithms
                                               // with integrated scripts of nested 
                                               // algorithms. 
Var HandlerNames;                              // Structure that contains names of all
                                               // exchange rule handlers.


////////////////////////////////////////////////////////////////////////////////
// FLAGS THAT SHOW WHETHER GLOBAL EVENT HANDLERS EXIST.

Var HasBeforeExportObjectGlobalHandler;
Var HasAfterExportObjectGlobalHandler;

Var HasBeforeConvertObjectGlobalHandler;

Var HasBeforeImportObjectGlobalHandler;
Var HasAfterImportObjectGlobalHandler;

Var TargetPlatformVersion;
Var TargetPlatform;

////////////////////////////////////////////////////////////////////////////////
// VARIABLES THAT ARE USED IN EXCHANGE HANDLERS (BOTH FOR IMPORT AND EXPORT).

Var deStringType;                 // Type("String")
Var deBooleanType;                // Type("Boolean")
Var deNumberType;                 // Type("Number")
Var deDateType;                   // Type("Date")
Var deValueStorageType;           // Type("ValueStorage")
Var deUUIDType;                   // Type("UUID")
Var deBinaryDataType;             // Type("BinaryData")
Var deAccumulationRecordTypeType; // Type("AccumulationRecordType")
Var deObjectDeletionType;         // Type("ObjectDeletion")
Var deAccountTypeType;            // Type("AccountType")
Var deTypeType;                   // Type("Type")
Var deMapType;                    // Type("Map")
 
Var deXMLNodeType_EndElement   Export;
Var deXMLNodeType_StartElement Export;
Var deXMLNodeType_Text         Export;
 
Var EmptyDateValue             Export;
 
Var deMessages; // Map, where Key is an error code and Value is error details
 
Var mExchangeRuleTemplateList  Export;



////////////////////////////////////////////////////////////////////////////////
// EXPORT PROCESSING MODULE VARIABLES.
 
Var mExportedObjectCounter Export; // Number - exported object counter.
Var mSnCounter Export;             // Number - serial number counter.
Var mXMLDocument;                  // DOM-XML document used during XML nodes creation.
Var mPropertyConversionRuleTable;  // ValueTable - pattern for recreating a table 
                                   // structure by copying.
Var mXMLRules;                     // XML string that contains exchange rule
                                   // description.
Var mTypesForTargetString;



////////////////////////////////////////////////////////////////////////////////
// IMPORT PROCESSING MODULE VARIABLES.
 
Var mImportedObjectCounter Export;     // Number - imported object counter.
 
Var mExchangeFileAttributes Export;    // Structure. Once the file is open, it contains
                                       // exchange file attributes. 
 
Var ImportedObjects Export;            // Map whose Keys are object serial numbers in 
                                       // the file and Values are imported object
                                       // references. 
Var ImportedGlobalObjects Export;
Var ImportedObjectToStoreCount Export; // Number of stored imported objects. If the
                                       // number of imported object exceeds the value
                                       // of this variable, the ImportedObjects map
                                       // is cleared.
Var RememberImportedObjects Export;
 
Var mExtendedSearchParameterMap;
Var mConversionRuleMap;                // Map that is used for determining object
                                       // conversion rules by the object type.
 
Var mDataImportDataProcessor Export;
 
Var mEmptyTypeValueMap;
Var mTypeDescriptionMap;
 
Var mExchangeRulesReadOnImport Export;
 
Var mDataExportCallStack;
 
Var mDataTypeMapForImport;
 
Var mNotWrittenObjectGlobalStack;
 
Var EventsAfterParameterImport Export;
 
Var CurrentNestingLevelExportByRule;


////////////////////////////////////////////////////////////////////////////////
// AUXILIARY PROCEDURES FOR WRITING ALGORITHMS.

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR WORKING WITH STRINGS.

// Splits string in two parts: before the separator substring and after it.
//
// Parameters:
//  Str       - string to be split;
//  Separator - separator substring:
//  Mode      - 0 - separator is not included in the return substrings;
//              1 - separator is included in the first substring;
//              2 - separator is included in the second substring.
//
// Returns:
//  Result substrings.
//
Function SplitWithSeparator(Str, Val Separator, Mode=0) Export

	RightPart       = "";
	SplitterPos     = Find(Str, Separator);
	SeparatorLength = StrLen(Separator);
	If SplitterPos > 0 Then
		RightPart = Mid(Str, SplitterPos + ?(Mode=2, 0, SeparatorLength));
		Str       = TrimAll(Left(Str, SplitterPos - ?(Mode=1, -SeparatorLength + 1, 1)));
	EndIf;
 
	Return(RightPart);


EndFunction // SplitWithSeparator()

// Casts values from String to Array using the specified separator.
//
// Parameters:
//  Str       - string to be split.
//  Separator - separator substring.
//
// Returns:
//  Array of values.

// 
Function ArrayFromString(Val Str, Separator=",") Export

	Array     = New Array;
	RightPart = SplitWithSeparator(Str, Separator);
	
	While Not IsBlankString(Str) Do
		Array.Add(TrimAll(Str));
		Str       = RightPart;
		RightPart = SplitWithSeparator(Str, Separator);
	EndDo; 

	Return(Array);
	
EndFunction // ArrayFromString() 

// Splits the string into several strings by the separator. The separator can be any length.
//
// Parameters:
//  String           - String - text with separators;
//  Separator        - String - text separator, at least 1 character;
//  SkipEmptyStrings - Boolean - flag that shows whether empty strings must be included
//                     in the result;
//                     If this parameter is not set, the function executes in 
//                     compatibility with its earlier version mode:
//                     - if space is used as a separator, empty strings are not included
//                       in the result, for other separators empty strings are included
//                       in the result.
//                     - if String parameter does not contain significant characters (or
//                       it is an empty string) and space is used as a separator, the 
//                       function returns an array with a single empty string value ("").
//                     - if the String parameter does not contain significant characters 
//                       (or it is an empty string) and any character except space is 
//                       used as a separator, the function returns an empty array.
//
// Returns:
// Array - array of strings.
//
// Examples:
// SplitStringIntoSubstringArray(",One,Two,", ",") - returns an array of 5 elements, 
// three of them are empty strings;
// SplitStringIntoSubstringArray(",One,Two,", ",", True) - returns an array of 2 
// elements;
// SplitStringIntoSubstringArray(" one two ", " ") - returns an array of 2 elements;
// SplitStringIntoSubstringArray("") - returns an empty array;
// SplitStringIntoSubstringArray("",,False) - returns an array with an empty string ("");
// SplitStringIntoSubstringArray("", " ") - returns an array with an empty string ("");
//

Function SplitStringIntoSubstringArray(Val String, Val Separator = ",", Val SkipEmptyStrings = Undefined) Export
	
	Result = New Array;
	
	// for backward compatibility
	If SkipEmptyStrings = Undefined Then
		SkipEmptyStrings = ?(Separator = " ", True, False);
		If IsBlankString(String) Then 
			If Separator = " " Then
				Result.Add("");
			EndIf;
			Return Result;
		EndIf;
	EndIf;
	
	Position = Find(String, Separator);
	While Position > 0 Do
		Substring = Left(String, Position - 1);
		If Not SkipEmptyStrings Or Not IsBlankString(Substring) Then
			Result.Add(Substring);
		EndIf;
		String   = Mid(String, Position + StrLen(Separator));
		Position = Find(String, Separator);
	EndDo;
	
	If Not SkipEmptyStrings Or Not IsBlankString(String) Then
		Result.Add(String);
	EndIf;
	
	Return Result;
	
EndFunction 

// Returns the number string without a prefix.
// For example:
//  GetStringNumberWithoutPrefixes("UT0000001234") = "0000001234"
// 
// Parameters:
//  Number – String – number whose numeric part will be returned.
// 
// Returns:
//  Number string without a prefix.
//

Function GetStringNumberWithoutPrefixes(Number) Export
	
	NumberWithoutPrefixes = "";
	Cnt = StrLen(Number);
	
	While Cnt > 0 Do
		
		Char = Mid(Number, Cnt, 1);
		
		If (Char >= "0" And Char <= "9") Then
			
			NumberWithoutPrefixes = Char + NumberWithoutPrefixes;
			
		Else
			
			Return NumberWithoutPrefixes;
			
		EndIf;
		
		Cnt = Cnt - 1;
		
	EndDo;
	
	Return NumberWithoutPrefixes;
	
EndFunction

// Splits the string into a prefix and numerical part.
//
// Parameters:
//  Str           - String - string to be split.
//  NumericalPart - Number - variable where the numerical part will be returned.
//  Mode          - String - pass "Number" if you want a numeric part to be returned,
//                  otherwise pass "Prefix".
//
// Returns:
//  String prefix.
//

Function GetNumberPrefixAndNumericalPart(Val Str, NumericalPart = "", Mode = "") Export

	NumericalPart = 0;
	Prefix = "";
	Str = TrimAll(Str);
	Length   = StrLen(Str);
	
	StringNumberWithoutPrefix = GetStringNumberWithoutPrefixes(Str);
	StringPartLength = StrLen(StringNumberWithoutPrefix);
	If StringPartLength > 0 Then
		NumericalPart = Number(StringNumberWithoutPrefix);
		Prefix = Mid(Str, 1, Length - StringPartLength);
	Else
		Prefix = Str;	
	EndIf;

	If Mode = "Number" Then
		Return(NumericalPart);
	Else
		Return(Prefix);
	EndIf;

EndFunction

// Casts the number (code) into the required length, splitting the number into a prefix
// and numeric part. The space between the prefix and number is filled with zeros.
// Can be used in the event handlers whose script is stored in data exchange rules.
// Is called with the Execute method.
// The "No links to function found" message during the configuration check is 
// not an error.
//
// Parameters:
//  Str    - string to be casted.
//  Length - required string length.
//
// Returns:
//  String - result code or number.
//
 
Function CastNumberToLength(Val Str, Length, AddZerosIfLengthNotLessCurrentNumberLength = True, Prefix = "") Export

	If IsBlankString(Str)
		Or StrLen(Str) = Length Then
		
		Return Str;
		
	EndIf;
	
	Str                  = TrimAll(Str);
	IncomingNumberLength = StrLen(Str);

	NumericalPart      = "";
	StringNumberPrefix = GetNumberPrefixAndNumericalPart(Str, NumericalPart);
	
	FinalPrefix = ?(IsBlankString(Prefix), StringNumberPrefix, Prefix);
	ResultingPrefixLength = StrLen(FinalPrefix);
	
	NumericPartString = Format(NumericalPart, "NG=0");
	NumericPartLength = StrLen(NumericPartString);

	If (Length >= IncomingNumberLength And AddZerosIfLengthNotLessCurrentNumberLength)
		Or (Length < IncomingNumberLength) Then
		
		For TemporaryVariable = 1 To Length - ResultingPrefixLength - NumericPartLength Do
			
			NumericPartString = "0" + NumericPartString;
			
		EndDo;
	
	EndIf;
	
	// Cutting excess symbols
	NumericPartString = Right(NumericPartString, Length - ResultingPrefixLength);
		
	Result = FinalPrefix + NumericPartString;

	Return Result;

EndFunction // CastNumberToLength()

// Adds the substring to the number prefix or code.
// Can be used in the event handlers whose script is stored in data exchange rules.
// Is called with the Execute method.
// The "No links to function found" message during the configuration check is 
// not an error.
//
// Parameters:
// Str      - String - number or code.
// Additive - substring to be added.
// Length   - required string length.
// Mode     - pass "Left" if you want to add substring from the left, otherwise the
//            substring will be added from the right.
//
// Returns:
// String - number or code with substring added to the prefix.
//
Function AddToPrefix(Val Str, Additive = "", Length = "", Mode = "Left") Export

	Str = TrimAll(Format(Str,"NG=0"));

	If IsBlankString(Length) Then
		Length = StrLen(Str);
	EndIf;

	NumericalPart = "";
	Prefix        = GetNumberPrefixAndNumericalPart(Str, NumericalPart);

	If Mode = "Left" Then
		Result = TrimAll(Additive) + Prefix;
	Else
		Result = Prefix + TrimAll(Additive);
	EndIf;

	While Length - StrLen(Result) - StrLen(Format(NumericalPart, "NG=0")) > 0 Do
		Result = Result + "0";
	EndDo;

	Result = Result + Format(NumericalPart, "NG=0");

	Return Result;

EndFunction // AddToPrefix()

// Supplements string with the specified symbol to the specified length.
//
// Parameters: 
//  Str      - string to be supplemented.
//  Length   - required string length.
//  Additive - substring to be added.
//

Function odSupplementString(Str, Length, Than = " ") Export

	Result = TrimAll(Str);
	While Length - StrLen(Result) > 0 Do
		Result = Result + Than;
	EndDo;

	Return(Result);

EndFunction // odSupplementString() 


////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR WORKING WITH DATA.

// Returns a string that contains the name of the passed enumeration value.
// Can be used in the event handlers whose script is stored in data exchange rules.
// Is called with the Execute method.
// The "No links to function found" message during the configuration check is 
// not an error.
//
// Parameters:
//  Value - enumeration value.
//
// Returns:
//  String - name of the passed enumeration value.
//
Function deEnumValueName(Value) Export

	MDObject    = Value.Metadata();
	ValueIndex = Enums[MDObject.Name].IndexOf(Value);

	Return MDObject.EnumValues[ValueIndex].Name;

EndFunction // deEnumValueName()

// Determines whether the passed value is empty.
//
// Parameters: 
//  Value - value to be checked.
//
// Returns:
//  True if the value is empty, False otherwise.
//

Function deEmpty(Value, IsNULL=False) Export

	// Primitive types first
	If Value = Undefined Then
		Return True;
	ElsIf Value = NULL Then
		IsNULL   = True;
   Return True;
	EndIf;
	
	ValueType = TypeOf(Value);
	

	If ValueType = deValueStorageType Then
		
		Result = deEmpty(Value.Get());
		Return Result;		
		
	ElsIf ValueType = deBinaryDataType Then
		
		Return False;
		
	Else

		// The value is considered empty if it is equal to the default value of its type
		Try
			Result = Not ValueIsFilled(Value);
			Return Result;
		Except
			Return False;
		EndTry;
			
	EndIf;
                           
EndFunction // deEmpty()

// Returns the TypeDescription object that contains the specified type.
//  
// Parameters:
//  TypeValue - string with a type name or Type.
//  
// Returns:
//  TypeDescription.
//
Function deTypeDescription(TypeValue) Export
	
	TypeDescription = mTypeDescriptionMap[TypeValue];
	
	If TypeDescription = Undefined Then
		
		TypeArray = New Array;
		If TypeOf(TypeValue) = deStringType Then
			TypeArray.Add(Type(TypeValue));
		Else
			TypeArray.Add(TypeValue);
		EndIf; 
		TypeDescription	= New TypeDescription(TypeArray);
		
		mTypeDescriptionMap.Insert(TypeValue, TypeDescription);
		
	EndIf;	
	
	Return TypeDescription;

EndFunction // deTypeDescription()

// Returns an empty (default) value of the specified type.
//
// Parameters:
// Type - String with a type name or Type.
//
// Returns:
// Empty value of the specified type.
//
 
Function deGetEmptyValue(Type) Export

	EmptyTypeValue = mEmptyTypeValueMap[Type];
	
	If EmptyTypeValue = Undefined Then
		
		EmptyTypeValue = deTypeDescription(Type).AdjustValue(Undefined);	
		
		mEmptyTypeValueMap.Insert(Type, EmptyTypeValue);
			
	EndIf;
	
	Return EmptyTypeValue;

EndFunction // GetEmptyValue()

Function CheckRefExists(Ref, Manager, FoundByUUIDObject, 
	MainObjectSearchMode, SearchByUUIDQueryString)
	
	Try
			
		If MainObjectSearchMode
			Or IsBlankString(SearchByUUIDQueryString) Then
			
			FoundByUUIDObject = Ref.GetObject();
			
			If FoundByUUIDObject = Undefined Then
			
				Return Manager.EmptyRef();
				
			EndIf;
			
		Else
			// "Search by reference" mode. It is enough to execute a query by the following pattern:
			// PropertyStructure.SearchString
 
			
			Query = New Query();
			Query.Text = SearchByUUIDQueryString + "  Ref = &Ref ";
			Query.SetParameter("Ref", Ref);
			
			QueryResult = Query.Execute();
			
			If QueryResult.IsEmpty() Then
			
				Return Manager.EmptyRef();
				
			EndIf;
			
		EndIf;
		
		Return Ref;	
		
	Except
			
		Return Manager.EmptyRef();
		
	EndTry;
	
EndFunction

// Performs a simple search for infobase object by the specified property.
//
// Parameters:
//  Manager  - manager of the object to be searched;
//  Property - property to implement the search: Name, Code, Description, or a name of
//             an indexed attribute.
//  Value    - value of a property to be used for searching the object.
//
// Returns:
//  Found infobase object.
//
Function deFindObjectByProperty(Manager, Property, Value, 
	FoundByUUIDObject = Undefined, 
	CommonPropertyStructure = Undefined, CommonSearchProperties = Undefined, 
	MainObjectSearchMode = True, SearchByUUIDQueryString = "") Export

	If Property = "Name" Then
		
		Return Manager[Value];
		
	ElsIf Property = "Code" Then
		
		Return Manager.FindByCode(Value);
		
	ElsIf Property = "Description" Then
		
		Return Manager.FindByDescription(Value, TRUE);
		
	ElsIf Property = "Number" Then
		
		Return Manager.FindByNumber(Value);
		
	ElsIf Property = "{UUID}" Then
		
		RefByUUID = Manager.GetRef(New UUID(Value));
		
		Ref =  CheckRefExists(RefByUUID, Manager, FoundByUUIDObject, 
			MainObjectSearchMode, SearchByUUIDQueryString);
			
		Return Ref;
				
	ElsIf Property = "{PredefinedItemName}" Then
		
		Try
			
			Ref = Manager[Value];
			
		Except
			
			Ref = Manager.FindByCode(Value);
			
		EndTry;
		
		Return Ref;
		
	Else
	
		If Not (Property = "Date"
			Or Property = "Posted"
			Or Property = "DeletionMark"
			Or Property = "Owner"
			Or Property = "Parent"
			Or Property = "IsFolder") Then
			
			Try
			
				UnlimitedLengthString = IsUnlimitedLengthParameter(CommonPropertyStructure, Value, Property);		
														
			Except
						
				UnlimitedLengthString = False;
						
			EndTry;
			
			If Not UnlimitedLengthString Then
			
				Return Manager.FindByAttribute(Property, Value);
				
			EndIf;
			
		EndIf;
		
		ObjectRef = FindItemUsingRequest(CommonPropertyStructure, CommonSearchProperties, , Manager);
		Return ObjectRef;		
		
	EndIf; 

EndFunction // deFindObjectByProperty() 

// Performs a simple search for infobase object by the specified property.
//
// Parameters:
//  Str      - String - property value (search string).
//  Type     - object type.
//  Property - String - property name.
//
// Returns:
//  Found infobase object.
//

Function deGetValueByString(Str, Type, Property = "") Export

	If IsBlankString(Str) Then
		Return New(Type);
	EndIf; 

	Properties = Managers[Type];

	If Properties = Undefined Then
		
		TypeDescription = deTypeDescription(Type);
		Return TypeDescription.AdjustValue(Str);
		
	EndIf;

	If IsBlankString(Property) Then
		
		If Properties.TypeName = "Enum" Then
			Property = "Name";
		Else
			Property = "{PredefinedItemName}";
		EndIf;
		
	EndIf; 

	Return deFindObjectByProperty(Properties.Manager, Property, Str);

EndFunction // deGetValueByString()

// Returns a string that contains a value type presentation. 
//
// Parameters: 
//  ValueOrType - arbitrary value or Type.
//
// Returns:
//  String - string that contains the value type presentation.
//
Function deValueTypeString(ValueOrType) Export

	ValueType	= TypeOf(ValueOrType);
	
	If ValueType = deTypeType Then
		ValueType	= ValueOrType;
	EndIf; 
	
	If (ValueType = Undefined) Or (ValueOrType = Undefined) Then
		Result = "";
	ElsIf ValueType = deStringType Then
		Result = "String";
	ElsIf ValueType = deNumberType Then
		Result = "Number";
	ElsIf ValueType = deDateType Then
		Result = "Date";
	ElsIf ValueType = deBooleanType Then
		Result = "Boolean";
	ElsIf ValueType = deValueStorageType Then
		Result = "ValueStorage";
	ElsIf ValueType = deUUIDType Then
		Result = "UUID";
	ElsIf ValueType = deAccumulationRecordTypeType Then
		Result = "AccumulationRecordType";
	Else
		Manager = Managers[ValueType];
		If Manager = Undefined Then
			
			Text= NStr("en='Unknown type:'") + String(TypeOf(ValueType));
			MessageToUser(Text);
			
		Else
			Result = Manager.RefTypeString;
		EndIf;
	EndIf;

	Return Result;
	
EndFunction // deValueTypeString()

// Returns a TypeDescription object XML presentation.
// Can be used in the event handlers whose script is stored in the data exchange rules.
// 
// Parameters:
//  TypeDescription  - TypeDescription object whose XML presentation will be retrieved.
//
// Returns:
//  String - XML presentation of the passed TypeDescription object.
//
Function deGetXMLTypeDescriptionPresentation(TypeDescription) Export
	
	TypeNode = CreateNode("Types");
	
	If TypeOf(TypeDescription) = Type("Structure") Then
		SetAttribute(TypeNode, "AllowedSign",    TrimAll(TypeDescription.AllowedSign));
		SetAttribute(TypeNode, "DigitCapacity",  TrimAll(TypeDescription.DigitCapacity));
		SetAttribute(TypeNode, "FractionDigits", TrimAll(TypeDescription.FractionDigits));
		SetAttribute(TypeNode, "Length",         TrimAll(TypeDescription.Length));
		SetAttribute(TypeNode, "AllowedLength",  TrimAll(TypeDescription.AllowedLength));
		SetAttribute(TypeNode, "DateContent",    TrimAll(TypeDescription.DateFractions));
		
		For Each StrType In TypeDescription.Types Do
			NodeType = CreateNode("Type");
			NodeType.WriteText(TrimAll(StrType));
			AddSubordinateNode(TypeNode, NodeType);
		EndDo;
	Else
		NumberQualifier = TypeDescription.NumberQualifiers;
		StringQualifier = TypeDescription.StringQualifiers;
		DateQualifier   = TypeDescription.DateQualifiers;
		
		SetAttribute(TypeNode, "AllowedSign",    TrimAll(NumberQualifier.AllowedSign));
		SetAttribute(TypeNode, "DigitCapacity",  TrimAll(NumberQualifier.DigitCapacity));
		SetAttribute(TypeNode, "FractionDigits", TrimAll(NumberQualifier.FractionDigits));
		SetAttribute(TypeNode, "Length",         TrimAll(StringQualifier.Length));
		SetAttribute(TypeNode, "AllowedLength",  TrimAll(StringQualifier.AllowedLength));
		SetAttribute(TypeNode, "DateContent",    TrimAll(DateQualifier.DateFractions));
		
		For Each Type In TypeDescription.Types() Do
			NodeType = CreateNode("Type");
			NodeType.WriteText(deValueTypeString(Type));
			AddSubordinateNode(TypeNode, NodeType);
		EndDo;
	EndIf;
	
	TypeNode.WriteEndElement();
	
	Return(TypeNode.Close());
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR WORKING WITH THE XMLWriter OBJECT.

// Replaces invalid XML characters with the specified character.
//
// Parameters:
//  Text            - String.
//  ReplacementChar - String.
//
Function ReplaceDisallowedXMLCharacters(Val Text, ReplacementChar = " ") Export
	
	Position = FindDisallowedXMLCharacters(Text);
	While Position > 0 Do
		Text = StrReplace(Text, Mid(Text, Position, 1), ReplacementChar);
		Position = FindDisallowedXMLCharacters(Text);
	EndDo;
	
	Return Text;
EndFunction

Function DeleteDisallowedXMLCharacters(Val Text)
	
	Return ReplaceDisallowedXMLCharacters(Text, "");
	
EndFunction

// Creates a new XML node.
// Can be used in the event handlers whose script is stored in the data exchange rules.
// Is called with the Execute method.
//
// Parameters: 
//  Name - node name.
//
// Returns:
//  Object of the new XML node.
//
Function CreateNode(Name) Export 

	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	XMLWriter.WriteStartElement(Name);

	Return XMLWriter;

EndFunction // CreateNode()

// Adds a new XML node to the specified parent node.
// Can be used in the event handlers whose script is stored in data exchange rules.
// Is called with the Execute method.
// The "No links to function found" message during the configuration check is 
// not an error.
//
// Parameters: 
//  ParentNode - parent XML node.
//  Name       - name of the node to be added.
//
// Returns:
//  New XML node added to the specified parent node.
//

Function AddNode(ParentNode, Name) Export

	ParentNode.WriteStartElement(Name);

	Return ParentNode;

EndFunction // AddNode()

// Copies the specified XML node.
// Can be used in the event handlers whose script is stored in data exchange rules.
// Is called with the Execute method.
// The "No links to function found" message during the configuration check is 
// not an error.
//
// Parameters: 
//  Node - node to be copied.
//
// Returns:
//  New file that is a copy of the specified node.
//

Function CopyNode(Node) Export

	Str = Node.Close();

	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	
	If PerformAdditionalWriteToXMLControl Then
		
		Str = DeleteDisallowedXMLCharacters(Str);
		
	EndIf;
	
	XMLWriter.WriteRaw(Str);

	Return XMLWriter;
	
EndFunction // CopyNode() 

// Writes the element and its value to the specified object.
//
// Parameters:
//  Object - XMLWriter.
//  Name   - String - element name.
//  Value  - element value.
//

Procedure deWriteElement(Object, Name, Value="") Export

	Object.WriteStartElement(Name);
	Str = XMLString(Value);
	
	If PerformAdditionalWriteToXMLControl Then
		
		Str = DeleteDisallowedXMLCharacters(Str);
		
	EndIf;
	
	Object.WriteText(Str);
	Object.WriteEndElement();
	
EndProcedure

// Subordinates the XML node to the specified parent node.
//
// Parameters: 
//  ParentNode - parent XML node.
//  Node       - node to be subordinated. 
//

Procedure AddSubordinateNode(ParentNode, Node) Export

	If TypeOf(Node) <> deStringType Then
		Node.WriteEndElement();
		InformationToWriteToFile = Node.Close();
	Else
		InformationToWriteToFile = Node;
	EndIf;
	
	ParentNode.WriteRaw(InformationToWriteToFile);
		
EndProcedure

// Sets the attribute of the specified XML node.
//
// Parameters: 
// Node  - XML node.
// Name  - attribute name.
// Value - value to be set.
//

Procedure SetAttribute(Node, Name, Value) Export

	XMLString = XMLString(Value);
	
	If PerformAdditionalWriteToXMLControl Then
		
		XMLString = DeleteDisallowedXMLCharacters(XMLString);
		
	EndIf;
	
	Node.WriteAttribute(Name, XMLString);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR WORKING WITH THE XMLReader OBJECT.

// Reads the attribute value by the name from the specified object, converts the value to the
// specified primitive type.

//
// Parameters:
// Object - XMLReader - XMLReader object positioned to the beginning of the
//          element whose attribute will be retrieved.
// Type   - Type - attribute type.
// Name   - String - attribute name.
//
// Returns:
//  The attribute value received by the name and casted to the specified type.
//

Function deAttribute(Object, Type, Name) Export

	ValueStr = Object.GetAttribute(Name);
	If Not IsBlankString(ValueStr) Then
		Return XMLValue(Type, TrimR(ValueStr));		
	ElsIf      Type = deStringType Then
		Return ""; 
	ElsIf Type = deBooleanType Then
		Return False;
	ElsIf Type = deNumberType Then
		Return 0;
	ElsIf Type = deDateType Then
		Return EmptyDateValue;
	EndIf; 
		
EndFunction // deAttribute() 
 
// Skips XML nodes till the end of the specified element (default is the current one).
//
// Parameters:
//  Object - XMLReader.
//  Name   - name of the node whose elements will be skipped.
// 
Procedure deSkip(Object, Name = "") Export

	AttachmentCount = 0; // Number of attachments with the same name

	If Name = "" Then
		
		Name = Object.LocalName;
		
	EndIf; 
	
	While Object.Read() Do
		
		If Object.LocalName <> Name Then
			Continue;
		EndIf;
		
		NodeType = Object.NodeType;
			
		If NodeType = deXMLNodeType_EndElement Then
				
			If AttachmentCount = 0 Then
					
				Break;
					
			Else
					
				AttachmentCount = AttachmentCount - 1;
					
			EndIf;
				
		ElsIf NodeType = deXMLNodeType_StartElement Then
				
			AttachmentCount = AttachmentCount + 1;
				
		EndIf;
					
	EndDo;
	
EndProcedure

// Reads the element text and casts the value to the specified primitive type.
//
// Parameters:
//  Object           - XMLReader - object whose data will be read. 
//  Type             - type of the return value.
//  SearchByProperty - for reference types, a property for searching can be specified.
//                     It can be: Code, Description, <AttributeName>, Name (of a 
//                     predefined value).
//
// Returns:
//  XML element value casted to the specified type.
//

Function deElementValue(Object, Type, SearchByProperty = "", CutStringRight = True) Export

	Value = "";
	Name  = Object.LocalName;

	While Object.Read() Do
		
		NodeType = Object.NodeType;
		
		If NodeType = deXMLNodeType_Text Then
			
			Value = Object.Value;
			
			If CutStringRight Then
				
				Value = TrimR(Value);
				
			EndIf;
						
		ElsIf (Object.LocalName = Name) And (NodeType = deXMLNodeType_EndElement) Then
			
			Break;
			
		Else
			
			Return Undefined;
			
		EndIf;
		
	EndDo;

	
	If (Type = deStringType)
		Or (Type = deBooleanType)
		Or (Type = deNumberType)
		Or (Type = deDateType)
		Or (Type = deValueStorageType)
		Or (Type = deUUIDType)
		Or (Type = deAccumulationRecordTypeType)
		Or (Type = deAccountTypeType)
		Then
		
		Return XMLValue(Type, Value);
		
	Else
		
		Return deGetValueByString(Value, Type, SearchByProperty);
		
	EndIf; 
	
EndFunction // deElementValue() 


////////////////////////////////////////////////////////////////////////////////
// PROCEDURE AND FUNCTION FOR WORKING WITH EXCHANGE FILE.

// Saves the specified XML node to a file.
//
// Parameters:
//  Node - XML node to be saved.
//
Procedure WriteToFile(Node) Export

	If TypeOf(Node) <> deStringType Then
		InformationToWriteToFile = Node.Close();
	Else
		InformationToWriteToFile = Node;
	EndIf;
	
	If DirectReadingInTargetInfobase Then
		
		ErrorStringInTargetInfobase = "";
		PassWriteInfoToTarget(InformationToWriteToFile, ErrorStringInTargetInfobase);
		If Not IsBlankString(ErrorStringInTargetInfobase) Then
			
			Raise ErrorStringInTargetInfobase;
			
		EndIf;
		
	Else
		
		ExchangeFile.WriteLine(InformationToWriteToFile);
		
	EndIf;
	
EndProcedure

// Opens the exchange file, writes the file header according to the exchange format.
//
Function OpenExportFile(ErrorMessageString = "")

	// Archive files are identified by .zip extension
	
	If ArchiveFile Then
		ExchangeFileName = StrReplace(ExchangeFileName, ".zip", ".xml");
	EndIf;
    	
	ExchangeFile = New TextWriter;
	Try
		
		If DirectReadingInTargetInfobase Then
			ExchangeFile.Open(GetTempFileName(".xml"), TextEncoding.UTF8);
		Else
			ExchangeFile.Open(ExchangeFileName, TextEncoding.UTF8);
		EndIf;
				
	Except
		
		ErrorMessageString = WriteToExecutionLog(8);
		Return "";
		
	EndTry; 
	
	XMLInfoString = "<?xml version=""1.0"" encoding=""UTF-8""?>";
	
	ExchangeFile.WriteLine(XMLInfoString);

	TempXMLWriter = New XMLWriter();
	
	TempXMLWriter.SetString();
	
	TempXMLWriter.WriteStartElement("ExchangeFile");
							
	SetAttribute(TempXMLWriter, "FormatVersion",           "2.0");
	SetAttribute(TempXMLWriter, "ExportDate",              CurrentSessionDate());
	SetAttribute(TempXMLWriter, "ExportPeriodStart",       StartDate);
	SetAttribute(TempXMLWriter, "ExportPeriodEnd",         EndDate);
	SetAttribute(TempXMLWriter, "SourceConfigurationName", Conversion.Source);
	SetAttribute(TempXMLWriter, "TargetConfigurationName", Conversion.Target);
	SetAttribute(TempXMLWriter, "ConversionRuleIDs",       Conversion.ID);
	SetAttribute(TempXMLWriter, "Comment",                 Comment);
	
	TempXMLWriter.WriteEndElement();
	
	Str = TempXMLWriter.Close(); 
	
	Str = StrReplace(Str, "/>", ">");
	
	ExchangeFile.WriteLine(Str);
	
	Return XMLInfoString + Chars.LF + Str;
			
EndFunction

// Closes the exchange file.
//
Procedure CloseFile()

    ExchangeFile.WriteLine("</ExchangeFile>");
	ExchangeFile.Close();
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR WORKING WITH THE EXCHANGE PROTOCOL.

// Returns a structure that contains all possible log record fields (error messages and so on).
//
// Returns:
//  Structure.
// 
Function GetLogRecordStructure(MessageCode = "", ErrorString = "") Export

	ErrorStructure = New Structure("OCRName,DERName,Sn,GSn,Source,ObjectType,Property,Value,ValueType,OCR,PCR,PGCR,DER,DCP,Object,TargetProperty,ConvertedValue,Handler,ErrorDescription,ModulePosition,Text,MessageCode,ExchangePlanNode");
	
	ModuleString     = SplitWithSeparator(ErrorString, "{");
	ErrorDescription = SplitWithSeparator(ModuleString, "}: ");

	
	If ErrorDescription <> "" Then
		
		ErrorStructure.ErrorDescription = ErrorDescription;
		ErrorStructure.ModulePosition   = ModuleString;

				
	EndIf;
	
	If ErrorStructure.MessageCode <> "" Then
		
		ErrorStructure.MessageCode           = MessageCode;
		
	EndIf;
	
	Return ErrorStructure;
	
EndFunction 

// Initializes a file for writing data import/export events.
// 
Procedure EnableExchangeLog() Export
	
	If IsBlankString(ExchangeLogFileName) Then
		
		mDataLogFile = Undefined;
		CommentObjectProcessingFlag = OutputInfoMessagesToMessageWindow;		
		Return;
		
	Else	
		
		CommentObjectProcessingFlag = WriteInfoMessagesToLog Or OutputInfoMessagesToMessageWindow;		
		
	EndIf;
	
	mDataLogFile = New TextWriter(ExchangeLogFileName, TextEncoding.ANSI, , AppendDataToExchangeLog) ;
	
EndProcedure

Procedure EnableExchangeLogForHandlerExport()
	
	//Getting a unique file name
	ExchangeLogTempFileName = GetNewUniqueTempFileName("ExchangeLog", "txt", ExchangeLogTempFileName);
	
	mDataLogFile = New TextWriter(ExchangeLogTempFileName, TextEncoding.ANSI);
	
	CommentObjectProcessingFlag = False;
	
EndProcedure

// Closes the data exchange log file. Saves the file on the hard disk.
//
Procedure DisableExchangeProtocol() Export 
	
	If mDataLogFile <> Undefined Then
		
		mDataLogFile.Close();
				
	EndIf;	
	
	mDataLogFile = Undefined;
	
EndProcedure

// Writes messages of the specified structure to the execution log (or displays these 
// messages to the screen).
//
// Parameters:
//  Code            - Number - message code.
//  RecordStructure - Structure - protocol writing structure.
//  SetErrorFlag    - pass True if an error message will be written to set ErrorFlag.
//

Function WriteToExecutionLog(Code="", RecordStructure=Undefined, SetErrorFlag=True, 
	Level=0, Align=22, ForceWritingToExchangeLog = False) Export

	Indent = "";
    For Cnt = 0 To Level-1 Do
		Indent = Indent + Chars.Tab;
	EndDo; 
	
	If TypeOf(Code) = deNumberType Then
		
		If deMessages = Undefined Then
			InitMessages();
		EndIf;
		
		Str = deMessages[Code];
		
	Else
		
		Str = String(Code);
		
	EndIf;

	Str = Indent + Str;
	
	If RecordStructure <> Undefined Then
		
		For Each Field In RecordStructure Do
			
			Value = Field.Value;
			If Value = Undefined Then
				Continue;
			EndIf; 
			Key = Field.Key;
			Str  = Str + Chars.LF + Indent + Chars.Tab + odSupplementString(Field.Key, Align) + " =  " + String(Value);
			
		EndDo;
		
	EndIf;
	
	ResultingStringToWrite = Chars.LF + Str;

	
	If SetErrorFlag Then
		
		SetErrorFlag(True);
		MessageToUser(ResultingStringToWrite);
		
	Else
		
		If DontShowInfoMessagesToUser = False
			And (ForceWritingToExchangeLog Or OutputInfoMessagesToMessageWindow) Then
			
			MessageToUser(ResultingStringToWrite);
			
		EndIf;
		
	EndIf;
	
	If mDataLogFile <> Undefined Then
		
		If SetErrorFlag Then
			
			mDataLogFile.WriteLine(Chars.LF + "Error.");
			
		EndIf;
		
		If SetErrorFlag Or ForceWritingToExchangeLog Or WriteInfoMessagesToLog Then
			
			mDataLogFile.WriteLine(ResultingStringToWrite);
		
		EndIf;		
		
	EndIf;
	
	Return Str;
		
EndFunction

// Writes error details to the exchange log.
//
Function WriteErrorInfoToLog(MessageCode, ErrorString, Object, ObjectType = Undefined) Export
	
	LR        = GetLogRecordStructure(MessageCode, ErrorString);
	LR.Object = Object;
	
	If ObjectType <> Undefined Then
		LR.ObjectType = ObjectType;
	EndIf;	
		
	ErrorString = WriteToExecutionLog(MessageCode, LR);	
	
	Return ErrorString;	
	
EndFunction

// Writes error details to the exchange log for the data clearing handler.
//
Function WriteDataClearingHandlerErrorInfo(MessageCode, ErrorString, DataClearingRuleName, Object = "", HandlerName = "")Export
	
	LR     = GetLogRecordStructure(MessageCode, ErrorString);
	LR.DCR = DataClearingRuleName;

	
	If Object <> "" Then
		Try
			LR.Object = String(Object) + "  (" + TypeOf(Object) + ")";
		Except
			LR.Object = "" + TypeOf(Object) + "";
		EndTry;
	EndIf;
	
	If HandlerName <> "" Then
		LR.Handler = HandlerName;
	EndIf;
	
	ErrorMessageString = WriteToExecutionLog(MessageCode, LR);
	
	If Not DebugModeFlag Then
		Raise ErrorMessageString;
	EndIf;	
	
EndFunction

// Writes details of an OCR handler execution error to the exchange log (import).
//
Function WriteErrorInfoOCRHandlerImport(MessageCode, ErrorString, RuleName, Source = "", 
	ObjectType, Object = Undefined, HandlerName) Export
	
	LR            = GetLogRecordStructure(MessageCode, ErrorString);
	LR.OCRName    = RuleName;
	LR.ObjectType = ObjectType;
	LR.Handler    = HandlerName;

						
	If Not IsBlankString(Source) Then
							
		LR.Source = Source;
							
	EndIf;
						
	If Object <> Undefined Then
	
		LR.Object = String(Object);
		
	EndIf;
	
	ErrorMessageString = WriteToExecutionLog(MessageCode, LR);
	
	If Not DebugModeFlag Then
		Raise ErrorMessageString;
	EndIf;
		
EndFunction

// Writes details of an OCR handler execution error to the exchange log (export).
//
Function WriteErrorInfoOCRHandlerExport(MessageCode, ErrorString, OCR, Source, HandlerName)
	
	LR     = GetLogRecordStructure(MessageCode, ErrorString);
	LR.OCR = OCR.Name + "  (" + OCR.Description + ")";

	
	Try
		LR.Object = String(Source) + "  (" + TypeOf(Source) + ")";
	Except
		LR.Object = "(" + TypeOf(Source) + ")";
	EndTry;
	
	LR.Handler = HandlerName;
	
	ErrorMessageString = WriteToExecutionLog(MessageCode, LR);
	
	If Not DebugModeFlag Then
		Raise ErrorMessageString;
	EndIf;
		
EndFunction

// Writes details of a PCR handler execution error to the exchange log.
//
Function WriteErrorInfoPCRHandlers(MessageCode, ErrorString, OCR, PCR, Source = "", 
	HandlerName = "", Value = Undefined, IsPCR = True) Export
	
	LR     = GetLogRecordStructure(MessageCode, ErrorString);
	LR.OCR = OCR.Name + "  (" + OCR.Description + ")";
	
	RuleName = PCR.Name + "  (" + PCR.Description + ")";
	If IsPCR Then
		LR.PCR                = RuleName;
	Else
		LR.PGCR               = RuleName;
	EndIf;
	
	Try
		LR.Object                 = String(Source) + "  (" + TypeOf(Source) + ")";
	Except
		LR.Object                 = "(" + TypeOf(Source) + ")";
	EndTry;
	
	If IsPCR Then
		LR.TargetProperty      = PCR.Target + "  (" + PCR.TargetType + ")";
	EndIf;
	
	If HandlerName <> "" Then
		LR.Handler         = HandlerName;
	EndIf;
	
	If Value <> Undefined Then
		LR.ConvertedValue = String(Value) + "  (" + TypeOf(Value) + ")";
	EndIf;
	
	ErrorMessageString = WriteToExecutionLog(MessageCode, LR);
	
	If Not DebugModeFlag Then
		Raise ErrorMessageString;
	EndIf;
		
EndFunction	

Function WriteErrorInfoDERHandlers(MessageCode, ErrorString, RuleName, HandlerName, Object = Undefined)
	
	LR     = GetLogRecordStructure(MessageCode, ErrorString);
	LR.DER = RuleName;
	
	If Object <> Undefined Then
		Try
			LR.Object = String(Object) + "  (" + TypeOf(Object) + ")";
		Except
			LR.Object = "" + TypeOf(Object) + "";
		EndTry;
	EndIf;
	
	LR.Handler = HandlerName;
	
	ErrorMessageString = WriteToExecutionLog(MessageCode, LR);
	
	If Not DebugModeFlag Then
		Raise ErrorMessageString;
	EndIf;
	
EndFunction

Function WriteErrorInfoConversionHandlers(MessageCode, ErrorString, HandlerName)
	
	LR                 = GetLogRecordStructure(MessageCode, ErrorString);
	LR.Handler         = HandlerName;
	ErrorMessageString = WriteToExecutionLog(MessageCode, LR);
	Return ErrorMessageString;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// EXCHANGE RULE IMPORT PROCEDURES.

// Imports the property group conversion rule.
//
// Parameters:
//  ExchangeRules - XMLReader.
//  PropertyTable - value table that contains PCR.
// 
Procedure ImportPGCR(ExchangeRules, PropertyTable)

	If deAttribute(ExchangeRules, deBooleanType, "Disable") Then
		deSkip(ExchangeRules);
		Return;
	EndIf;

	
	NewRow            = PropertyTable.Add();
	NewRow.IsFolder   = True;
	NewRow.GroupRules = mPropertyConversionRuleTable.Copy();

	
	// Default values

	NewRow.DontReplace              = False;
	NewRow.GetFromIncomingData      = False;
	NewRow.SimplifiedPropertyExport = False;
	
	SearchFieldString = "";	
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Source" Then
			NewRow.Source     = deAttribute(ExchangeRules, deStringType, "Name");
			NewRow.SourceKind = deAttribute(ExchangeRules, deStringType, "Kind");
			NewRow.SourceType = deAttribute(ExchangeRules, deStringType, "Type");
			deSkip(ExchangeRules);
			
		ElsIf NodeName = "Target" Then
			NewRow.Target     = deAttribute(ExchangeRules, deStringType, "Name");
			NewRow.TargetKind = deAttribute(ExchangeRules, deStringType, "Kind");
			NewRow.TargetType = deAttribute(ExchangeRules, deStringType, "Type");
			deSkip(ExchangeRules);
			
		ElsIf NodeName = "Property" Then
			ImportPCR(ExchangeRules, NewRow.GroupRules, , SearchFieldString);

		ElsIf NodeName = "BeforeProcessExport" Then
			NewRow.BeforeProcessExport	= GetHandlerValueFromText(ExchangeRules);
			NewRow.HasBeforeProcessExportHandler = Not IsBlankString(NewRow.BeforeProcessExport);
			
		ElsIf NodeName = "AfterProcessExport" Then
			NewRow.AfterProcessExport	= GetHandlerValueFromText(ExchangeRules);
			NewRow.HasAfterProcessExportHandler = Not IsBlankString(NewRow.AfterProcessExport);
			
		ElsIf NodeName = "Code" Then
			NewRow.Name = deElementValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "Description" Then
			NewRow.Description = deElementValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "Order" Then
			NewRow.Order = deElementValue(ExchangeRules, deNumberType);
			
		ElsIf NodeName = "DontReplace" Then
			NewRow.DontReplace = deElementValue(ExchangeRules, deBooleanType);
			
		ElsIf NodeName = "ConversionRuleCode" Then
			NewRow.ConversionRule = deElementValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "BeforeExport" Then
			NewRow.BeforeExport = GetHandlerValueFromText(ExchangeRules);
			NewRow.HasBeforeExportHandler = Not IsBlankString(NewRow.BeforeExport);
			
		ElsIf NodeName = "OnExport" Then
			NewRow.OnExport = GetHandlerValueFromText(ExchangeRules);
			NewRow.HasOnExportHandler    = Not IsBlankString(NewRow.OnExport);
			
		ElsIf NodeName = "AfterExport" Then
			NewRow.AfterExport = GetHandlerValueFromText(ExchangeRules);
	        NewRow.HasAfterExportHandler  = Not IsBlankString(NewRow.AfterExport);
			
		ElsIf NodeName = "ExportGroupToFile" Then
			NewRow.ExportGroupToFile = deElementValue(ExchangeRules, deBooleanType);
			
		ElsIf NodeName = "GetFromIncomingData" Then
			NewRow.GetFromIncomingData = deElementValue(ExchangeRules, deBooleanType);
			
		ElsIf (NodeName = "Group") And (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
			Break;
		EndIf;
		
	EndDo;
	
	NewRow.SearchFieldString = SearchFieldString;
	
	NewRow.XMLNodeRequiredOnExport = NewRow.HasOnExportHandler Or NewRow.HasAfterExportHandler;
	
	NewRow.XMLNodeRequiredOnExportGroup = NewRow.HasAfterProcessExportHandler; 

EndProcedure

Procedure AddFieldToSearchString(SearchFieldString, FieldName)
	
	If IsBlankString(FieldName) Then
		Return;
	EndIf;
	
	If Not IsBlankString(SearchFieldString) Then
		SearchFieldString = SearchFieldString + ",";
	EndIf;
	
	SearchFieldString = SearchFieldString + FieldName;
	
EndProcedure

// Imports the property conversion rule.
//
// Parameters:
//  ExchangeRules - XMLReader.
//  PropertyTable - value table that contains PCR.
//  SearchTable   - value table that contains PCR (to provide synchronization).
//
 
Procedure ImportPCR(ExchangeRules, PropertyTable, SearchTable = Undefined, SearchFieldString = "")

	If deAttribute(ExchangeRules, deBooleanType, "Disable") Then
		deSkip(ExchangeRules);
		Return;
	EndIf;

	
	IsSearchField = deAttribute(ExchangeRules, deBooleanType, "Search");
	
	If IsSearchField 
		And SearchTable <> Undefined Then
		
		NewRow = SearchTable.Add();
		
	Else
		
		NewRow = PropertyTable.Add();
		
	EndIf;  

	
	// Default values

	NewRow.DontReplace         = False;
	NewRow.GetFromIncomingData = False;
	
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Source" Then
			NewRow.Source     = deAttribute(ExchangeRules, deStringType, "Name");
			NewRow.SourceKind = deAttribute(ExchangeRules, deStringType, "Kind");
			NewRow.SourceType = deAttribute(ExchangeRules, deStringType, "Type");
			deSkip(ExchangeRules);

			
		ElsIf NodeName = "Target" Then
			NewRow.Target		  = deAttribute(ExchangeRules, deStringType, "Name");
			NewRow.TargetKind	= deAttribute(ExchangeRules, deStringType, "Kind");
			NewRow.TargetType	= deAttribute(ExchangeRules, deStringType, "Type");
			
			If IsSearchField Then
				AddFieldToSearchString(SearchFieldString, NewRow.Target);
			EndIf;
			
			deSkip(ExchangeRules);
			
		ElsIf NodeName = "Code" Then
			NewRow.Name = deElementValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "Description" Then
			NewRow.Description = deElementValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "Order" Then
			NewRow.Order = deElementValue(ExchangeRules, deNumberType);
			
		ElsIf NodeName = "DontReplace" Then
			NewRow.DontReplace = deElementValue(ExchangeRules, deBooleanType);
			
		ElsIf NodeName = "ConversionRuleCode" Then
			NewRow.ConversionRule = deElementValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "BeforeExport" Then
			NewRow.BeforeExport = GetHandlerValueFromText(ExchangeRules);
			NewRow.HasBeforeExportHandler = Not IsBlankString(NewRow.BeforeExport);
			
		ElsIf NodeName = "OnExport" Then
			NewRow.OnExport = GetHandlerValueFromText(ExchangeRules);
			NewRow.HasOnExportHandler    = Not IsBlankString(NewRow.OnExport);
			
		ElsIf NodeName = "AfterExport" Then
			NewRow.AfterExport = GetHandlerValueFromText(ExchangeRules);
	        NewRow.HasAfterExportHandler  = Not IsBlankString(NewRow.AfterExport);
			
		ElsIf NodeName = "GetFromIncomingData" Then
			NewRow.GetFromIncomingData = deElementValue(ExchangeRules, deBooleanType);
			
		ElsIf NodeName = "CastToLength" Then
			NewRow.CastToLength = deElementValue(ExchangeRules, deNumberType);
			
		ElsIf NodeName = "ParameterForTransferName" Then
			NewRow.ParameterForTransferName = deElementValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "SearchByEqualDate" Then
			NewRow.SearchByEqualDate = deElementValue(ExchangeRules, deBooleanType);
			
		ElsIf (NodeName = "Property") And (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
			Break;
		EndIf;
		
	EndDo;
	
	NewRow.SimplifiedPropertyExport = Not NewRow.GetFromIncomingData
		And Not NewRow.HasBeforeExportHandler
		And Not NewRow.HasOnExportHandler
		And Not NewRow.HasAfterExportHandler
		And IsBlankString(NewRow.ConversionRule)
		And NewRow.SourceType = NewRow.TargetType
		And (NewRow.SourceType = "String" Or NewRow.SourceType = "Number" Or NewRow.SourceType = "Boolean" Or NewRow.SourceType = "Date");
		
	NewRow.XMLNodeRequiredOnExport = NewRow.HasOnExportHandler Or NewRow.HasAfterExportHandler;
	
EndProcedure

// Imports property conversion rules.
//
// Parameters:
//  ExchangeRules - XMLReader.
//  PropertyTable - value table that contains PCR.
//  SearchTable   - value table that contains PCR (to provide synchronization).
//
 
Procedure ImportProperties(ExchangeRules, PropertyTable, SearchTable)

	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Property" Then
			ImportPCR(ExchangeRules, PropertyTable, SearchTable);
		ElsIf NodeName = "Group" Then
			ImportPGCR(ExchangeRules, PropertyTable);
		ElsIf (NodeName = "Properties") And (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
			Break;
		EndIf;

		
	EndDo;

	PropertyTable.Sort("Order");
	SearchTable.Sort("Order");
	
EndProcedure

// Imports the value conversion rule.
//
// Parameters:
//  ExchangeRules - XMLReader.
//  Values        - map source object values to target object presentation strings. 
//  SourceType    - Type - source object type.
//

Procedure ImportVCR(ExchangeRules, Values, SourceType)

	Source = "";
	Target = "";
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Source" Then
			Source = deElementValue(ExchangeRules, deStringType);
		ElsIf NodeName = "Target" Then
			Target = deElementValue(ExchangeRules, deStringType);
		ElsIf (NodeName = "Value") And (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
			Break;
		EndIf;
		
	EndDo;

	Values[deGetValueByString(Source, SourceType)] = Target;
	
EndProcedure

// Imports value conversion rules.
//
// Parameters:
// ExchangeRules - XMLReader.
// Values        - map source object values to target object presentation strings. 
// SourceType    - Type - source object type.
// 
 
Procedure LoadValues(ExchangeRules, Values, SourceType);

	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Value" Then
			ImportVCR(ExchangeRules, Values, SourceType);
		ElsIf (NodeName = "Values") And (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
			Break;
		EndIf;

		
	EndDo;
	
EndProcedure

// Clears manager OCR for exchange rules.
Procedure ClearManagerOCR()
	
	If Managers = Undefined Then
		Return;
	EndIf;
	
	For Each RuleManager In Managers Do
		RuleManager.Value.OCR = Undefined;
	EndDo;
	
EndProcedure

// Imports object conversion rules.
//
// Parameters:
//  ExchangeRules  - XMLReader.
//  XMLWriter      - XMLWriter - rules to be saved to the exchange file to be used
//                   during the data import.
//
 
Procedure ImportConversionRule(ExchangeRules, XMLWriter)

	XMLWriter.WriteStartElement("Rule");

	NewRow = ConversionRuleTable.Add();

	
	// Default values
	
	NewRow.RememberExported = True;
	NewRow.DontReplace      = False;
	
	
	SearchInTSTable = New ValueTable;
	SearchInTSTable.Columns.Add("ItemName");
	SearchInTSTable.Columns.Add("TSSearchFields");
	
	NewRow.SearchInTabularSections = SearchInTSTable;
	
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
				
		If NodeName = "Code" Then
			
			Value = deElementValue(ExchangeRules, deStringType);
			deWriteElement(XMLWriter, NodeName, Value);
			NewRow.Name = Value;
			
		ElsIf NodeName = "Description" Then
			
			NewRow.Description = deElementValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "SynchronizeByID" Then
			
			NewRow.SynchronizeByID = deElementValue(ExchangeRules, deBooleanType);
			deWriteElement(XMLWriter, NodeName, NewRow.SynchronizeByID);
			
		ElsIf NodeName = "DontCreateIfNotFound" Then
			
			NewRow.DontCreateIfNotFound = deElementValue(ExchangeRules, deBooleanType);
			
		ElsIf NodeName = "DontExportPropertyObjectsByRefs" Then
			
			NewRow.DontExportPropertyObjectsByRefs = deElementValue(ExchangeRules, deBooleanType);
						
		ElsIf NodeName = "SearchBySearchFieldsIfNotFoundByID" Then
			
			NewRow.SearchBySearchFieldsIfNotFoundByID = deElementValue(ExchangeRules, deBooleanType);	
			deWriteElement(XMLWriter, NodeName, NewRow.SearchBySearchFieldsIfNotFoundByID);
			
		ElsIf NodeName = "OnExchangeObjectByRefSetGIUDOnly" Then
			
			NewRow.OnExchangeObjectByRefSetGIUDOnly = deElementValue(ExchangeRules, deBooleanType);	
			deWriteElement(XMLWriter, NodeName, NewRow.OnExchangeObjectByRefSetGIUDOnly);
			
		ElsIf NodeName = "DontReplaceCreatedInTargetObject" Then
			// Has no effect on the exchange
			DontReplaceCreatedInTargetObject = deElementValue(ExchangeRules, deBooleanType);	
						
		ElsIf NodeName = "UseQuickSearchOnImport" Then
			
			NewRow.UseQuickSearchOnImport = deElementValue(ExchangeRules, deBooleanType);	
			
		ElsIf NodeName = "GenerateNewNumberOrCodeIfNotSet" Then
			
			NewRow.GenerateNewNumberOrCodeIfNotSet = deElementValue(ExchangeRules, deBooleanType);
			deWriteElement(XMLWriter, NodeName, NewRow.GenerateNewNumberOrCodeIfNotSet);
			
		ElsIf NodeName = "DontRememberExported" Then
			
			NewRow.RememberExported = Not deElementValue(ExchangeRules, deBooleanType);
			
		ElsIf NodeName = "DontReplace" Then
			
			Value = deElementValue(ExchangeRules, deBooleanType);
			deWriteElement(XMLWriter, NodeName, Value);
			NewRow.DontReplace = Value;
			
		ElsIf NodeName = "ExchangeObjectPriority" Then
			
			// Does not take a part in the universal exchange
			ExchangeObjectPriority = deElementValue(ExchangeRules, deStringType);			
			
		ElsIf NodeName = "Target" Then
			
			Value = deElementValue(ExchangeRules, deStringType);
			deWriteElement(XMLWriter, NodeName, Value);
			NewRow.Target = Value;
			
		ElsIf NodeName = "Source" Then
			
			Value = deElementValue(ExchangeRules, deStringType);
			deWriteElement(XMLWriter, NodeName, Value);
			
			If ExchangeMode = "Import" Then
				
				NewRow.Source	= Value;
				
			Else
				
				If Not IsBlankString(Value) Then
					          
					NewRow.SourceType = Value;
					NewRow.Source	= Type(Value);
					
					Try
						
						Managers[NewRow.Source].OCR = NewRow;
						
					Except
						
						WriteErrorInfoToLog(11, ErrorDescription(), String(NewRow.Source));
						
					EndTry; 
					
				EndIf;
				
			EndIf;
			
		// Properties
		
		ElsIf NodeName = "Properties" Then
		
			NewRow.SearchProperties	= mPropertyConversionRuleTable.Copy();
			NewRow.Properties		= mPropertyConversionRuleTable.Copy();
			
			
			If NewRow.SynchronizeByID <> Undefined And NewRow.SynchronizeByID Then
				
				SearchPropertyUUID = NewRow.SearchProperties.Add();
				SearchPropertyUUID.Name = "{UUID}";
				SearchPropertyUUID.Source = "{UUID}";
				SearchPropertyUUID.Target = "{UUID}";
				
			EndIf;
			
			ImportProperties(ExchangeRules, NewRow.Properties, NewRow.SearchProperties);

			
		// Values
		
		ElsIf NodeName = "Values" Then
		
			LoadValues(ExchangeRules, NewRow.Values, NewRow.Source);

			
		// Events handlers
		
		ElsIf NodeName = "BeforeExport" Then
		
			NewRow.BeforeExport = GetHandlerValueFromText(ExchangeRules);
			NewRow.HasBeforeExportHandler = Not IsBlankString(NewRow.BeforeExport);
			
		ElsIf NodeName = "OnExport" Then
			
			NewRow.OnExport = GetHandlerValueFromText(ExchangeRules);
			NewRow.HasOnExportHandler    = Not IsBlankString(NewRow.OnExport);
			
		ElsIf NodeName = "AfterExport" Then
			
			NewRow.AfterExport = GetHandlerValueFromText(ExchangeRules);
			NewRow.HasAfterExportHandler  = Not IsBlankString(NewRow.AfterExport);
			
		ElsIf NodeName = "AfterExportToFile" Then
			
			NewRow.AfterExportToFile = GetHandlerValueFromText(ExchangeRules);
			NewRow.HasAfterExportToFileHandler  = Not IsBlankString(NewRow.AfterExportToFile);
						
		// For import
		
		ElsIf NodeName = "BeforeImport" Then
			
			Value = GetHandlerValueFromText(ExchangeRules);
			
			
 			If ExchangeMode = "Import" Then
				
				NewRow.BeforeImport           = Value;
				NewRow.HasBeforeImportHandler = Not IsBlankString(Value);
				
			Else
				
				deWriteElement(XMLWriter, NodeName, Value);
				
			EndIf;
			
		ElsIf NodeName = "OnImport" Then
			
			Value = GetHandlerValueFromText(ExchangeRules);
			
			If ExchangeMode = "Import" Then
				
				NewRow.OnImport           = Value;
				NewRow.HasOnImportHandler = Not IsBlankString(Value);
				
			Else
				
				deWriteElement(XMLWriter, NodeName, Value);
				
			EndIf; 
			
		ElsIf NodeName = "AfterImport" Then
			
			Value = GetHandlerValueFromText(ExchangeRules);
			
			If ExchangeMode = "Import" Then
				
				NewRow.AfterImport           = Value;
				NewRow.HasAfterImportHandler = Not IsBlankString(Value);
				
			Else
				
				deWriteElement(XMLWriter, NodeName, Value);
				
	 		EndIf;
			
		ElsIf NodeName = "SearchFieldSequence" Then
			
			Value = GetHandlerValueFromText(ExchangeRules);
			
			NewRow.HasSearchFieldSequenceHandler = Not IsBlankString(Value);
			
			If ExchangeMode = "Import" Then
				
				NewRow.SearchFieldSequence = Value;
				
			Else
				
				deWriteElement(XMLWriter, NodeName, Value);
				
			EndIf;
			
		ElsIf NodeName = "SearchInTabularSections" Then
			
			Value = deElementValue(ExchangeRules, deStringType);
			
			For Number = 1 To StrLineCount(Value) Do
				
				CurrentRow = StrGetLine(Value, Number);
				
				SearchString = SplitWithSeparator(CurrentRow, ":");
				
				TableRow = SearchInTSTable.Add();
				TableRow.ItemName = CurrentRow;
				
				TableRow.TSSearchFields = SplitStringIntoSubstringArray(SearchString);
				
			EndDo;
			
		ElsIf (NodeName = "Rule") And (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
			
			Break;
			
		EndIf;
		
	EndDo;
	
	ResultingTSSearchString = "";
	
	// Tabular section search field details must be passed to the target.
	For Each PropertyString In NewRow.Properties Do
		
		If Not PropertyString.IsFolder
			Or IsBlankString(PropertyString.SourceKind)
			Or IsBlankString(PropertyString.Target) Then
			
			Continue;
			
		EndIf;
		
		If IsBlankString(PropertyString.SearchFieldString) Then
			Continue;
		EndIf;
		
		ResultingTSSearchString = ResultingTSSearchString + Chars.LF + PropertyString.SourceKind + "." + PropertyString.Target + ":" + PropertyString.SearchFieldString;
		
	EndDo;
	
	ResultingTSSearchString = TrimAll(ResultingTSSearchString);
	
	If Not IsBlankString(ResultingTSSearchString) Then
		
		deWriteElement(XMLWriter, "SearchInTabularSections", ResultingTSSearchString);	
		
	EndIf;

	XMLWriter.WriteEndElement();

	
	// Quick access to OCR by name
	
	Rules.Insert(NewRow.Name, NewRow);
	
EndProcedure
 
// Imports object conversion rules.
//
// Parameters:
//  ExchangeRules  - XMLReader.
//  XMLWriter      - XMLWriter - rules to be saved to the exchange file to be used
//                   during the data import.
//
 
Procedure ImportConversionRules(ExchangeRules, XMLWriter)

	ConversionRuleTable.Clear();
	ClearManagerOCR();
	
	XMLWriter.WriteStartElement("ObjectConversionRules");
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Rule" Then
			
			ImportConversionRule(ExchangeRules, XMLWriter);
			
		ElsIf (NodeName = "ObjectConversionRules") And (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
			
			Break;
			
		EndIf;
		
	EndDo;

	XMLWriter.WriteEndElement();
	
EndProcedure

// Imports the data clearing rule group according to the format of exchange rules.
//
// Parameters:
//  NewRow - value tree row that describes the data clearing rule group.
// 
Procedure ImportDCRGroup(ExchangeRules, NewRow)

	NewRow.IsFolder = True;
	NewRow.PrivilegedModeOn  = Number(Not deAttribute(ExchangeRules, deBooleanType, "Disable"));
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		NodeType = ExchangeRules.NodeType;
		
		If NodeName = "Code" Then
			NewRow.Name = deElementValue(ExchangeRules, deStringType);

		ElsIf NodeName = "Description" Then
			NewRow.Description = deElementValue(ExchangeRules, deStringType);
		
		ElsIf NodeName = "Order" Then
			NewRow.Order = deElementValue(ExchangeRules, deNumberType);
			
		ElsIf NodeName = "Rule" Then
			VTRow = NewRow.Rows.Add();
			ImportDCR(ExchangeRules, VTRow);
			
		ElsIf (NodeName = "Group") And (NodeType = deXMLNodeType_StartElement) Then
			VTRow = NewRow.Rows.Add();
			ImportDCRGroup(ExchangeRules, VTRow);
			
		ElsIf (NodeName = "Group") And (NodeType = deXMLNodeType_EndElement) Then
			Break;
		EndIf;
		
	EndDo;

	
	If IsBlankString(NewRow.Description) Then
		NewRow.Description = NewRow.Name;
	EndIf; 
	
EndProcedure

// Imports the data clearing rule according to the format of exchange rules.
//
// Parameters:
//  NewRow - value tree row that describes the data clearing rule.
// 
Procedure ImportDCR(ExchangeRules, NewRow)
	
	NewRow.PrivilegedModeOn = Number(Not deAttribute(ExchangeRules, deBooleanType, "Disable"));
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Code" Then
			Value = deElementValue(ExchangeRules, deStringType);
			NewRow.Name = Value;

		ElsIf NodeName = "Description" Then
			NewRow.Description = deElementValue(ExchangeRules, deStringType);
		
		ElsIf NodeName = "Order" Then
			NewRow.Order = deElementValue(ExchangeRules, deNumberType);
			
		ElsIf NodeName = "DataSelectionVariant" Then
			NewRow.DataSelectionVariant = deElementValue(ExchangeRules, deStringType);

		ElsIf NodeName = "SelectionObject" Then
			SelectionObject = deElementValue(ExchangeRules, deStringType);
			If Not IsBlankString(SelectionObject) Then
				NewRow.SelectionObject = Type(SelectionObject);
			EndIf; 

		ElsIf NodeName = "DeleteForPeriod" Then
			NewRow.DeleteForPeriod = deElementValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "Directly" Then
			NewRow.Directly = deElementValue(ExchangeRules, deBooleanType);

		
		// Events handlers

		ElsIf NodeName = "BeforeProcessRule" Then
			NewRow.BeforeProcess = GetHandlerValueFromText(ExchangeRules);
			
		ElsIf NodeName = "AfterProcessRule" Then
			NewRow.AfterProcess = GetHandlerValueFromText(ExchangeRules);
		
		ElsIf NodeName = "BeforeDeleteObject" Then
			NewRow.BeforeDelete = GetHandlerValueFromText(ExchangeRules);

		// Exit
		ElsIf (NodeName = "Rule") And (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
			Break;
			
		EndIf;
		
	EndDo;

	
	If IsBlankString(NewRow.Description) Then
		NewRow.Description = NewRow.Name;
	EndIf; 
	
EndProcedure

// Imports data clearing rules.
//
// Parameters:
//  ExchangeRules  - XMLReader.
//  XMLWriter      - XMLWriter - rules to be saved to the exchange file to be used
//                   during the data import.
//
 
Procedure ImportClearingRules(ExchangeRules, XMLWriter)
	
  ClearingRuleTable.Rows.Clear();
  VTRows = ClearingRuleTable.Rows;
	
	XMLWriter.WriteStartElement("DataClearingRules");

	While ExchangeRules.Read() Do
		
		NodeType = ExchangeRules.NodeType;
		
		If NodeType = deXMLNodeType_StartElement Then
			NodeName = ExchangeRules.LocalName;
			If ExchangeMode <> "Import" Then
				XMLWriter.WriteStartElement(ExchangeRules.Name);
				While ExchangeRules.ReadAttribute() Do
					XMLWriter.WriteAttribute(ExchangeRules.Name, ExchangeRules.Value);
				EndDo;
			Else
				If NodeName = "Rule" Then
					VTRow = VTRows.Add();
					ImportDCR(ExchangeRules, VTRow);
				ElsIf NodeName = "Group" Then
					VTRow = VTRows.Add();
					ImportDCRGroup(ExchangeRules, VTRow);
				EndIf;
			EndIf;
		ElsIf NodeType = deXMLNodeType_EndElement Then
			NodeName = ExchangeRules.LocalName;
			If NodeName = "DataClearingRules" Then
				Break;
			Else
				If ExchangeMode <> "Import" Then
					XMLWriter.WriteEndElement();
				EndIf;
			EndIf;
		ElsIf NodeType = deXMLNodeType_Text Then
			If ExchangeMode <> "Import" Then
				XMLWriter.WriteText(ExchangeRules.Value);
			EndIf;
		EndIf; 
	EndDo;

	VTRows.Sort("Order", True);
	
 	XMLWriter.WriteEndElement();
	
EndProcedure

// Imports the algorithm according to the format of exchange rules.
//
// Parameters:
//  ExchangeRules  - XMLReader.
//  XMLWriter      - XMLWriter - rules to be saved to the exchange file to be used
//                   during the data import.
//
 
Procedure ImportAlgorithm(ExchangeRules, XMLWriter)

	UsedOnImport = deAttribute(ExchangeRules, deBooleanType, "UsedOnImport");
	Name         = deAttribute(ExchangeRules, deStringType, "Name");
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Text" Then
			Text = GetHandlerValueFromText(ExchangeRules);
		ElsIf (NodeName = "Algorithm") And (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
			Break;
		Else
			deSkip(ExchangeRules);
		EndIf;
		
	EndDo;

	
	If UsedOnImport Then
		If ExchangeMode = "Import" Then
			Algorithms.Insert(Name, Text);
		Else
			XMLWriter.WriteStartElement("Algorithm");
			SetAttribute(XMLWriter,   "UsedOnImport", True);
			SetAttribute(XMLWriter,   "Name",   Name);
			deWriteElement(XMLWriter, "Text", Text);
			XMLWriter.WriteEndElement();
		EndIf;
	Else
		If ExchangeMode <> "Import" Then
			Algorithms.Insert(Name, Text);
		EndIf;
	EndIf;
	
	
EndProcedure

// Imports algorithms according to the format of exchange rules.
//
// Parameters:
//  ExchangeRules - XMLReader.
//  XMLWriter     - XMLWriter - rules to be saved to the exchange file to be used
//                  during the data import.
//
 
Procedure ImportAlgorithms(ExchangeRules, XMLWriter)

	Algorithms.Clear();

	XMLWriter.WriteStartElement("Algorithms");
	
	While ExchangeRules.Read() Do
		NodeName = ExchangeRules.LocalName;
		If NodeName = "Algorithm" Then
			ImportAlgorithm(ExchangeRules, XMLWriter);
		ElsIf (NodeName = "Algorithms") And (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
			Break;
		EndIf;
		
	EndDo;

	XMLWriter.WriteEndElement();
	
EndProcedure

// Imports the query according to the format of exchange rules.
//
// Parameters:
//  ExchangeRules  - XMLReader.
//  XMLWriter      - XMLWriter - rules to be saved to the exchange file to be used
//                   during the data import.
//

Procedure ImportQuery(ExchangeRules, XMLWriter)

	UsedOnImport = deAttribute(ExchangeRules, deBooleanType, "UsedOnImport");
	Name         = deAttribute(ExchangeRules, deStringType, "Name");
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Text" Then
			Text = GetHandlerValueFromText(ExchangeRules);
		ElsIf (NodeName = "Query") And (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
			Break;
		Else
			deSkip(ExchangeRules);
		EndIf;
		
	EndDo;

	If UsedOnImport Then
		If ExchangeMode = "Import" Then
			Query	= New Query(Text);
			Queries.Insert(Name, Query);
		Else
			XMLWriter.WriteStartElement("Query");
			SetAttribute(XMLWriter,   "UsedOnImport", True);
			SetAttribute(XMLWriter,   "Name", Name);
			deWriteElement(XMLWriter, "Text", Text);
			XMLWriter.WriteEndElement();
		EndIf;
	Else
		If ExchangeMode <> "Import" Then
			Query	= New Query(Text);
			Queries.Insert(Name, Query);
		EndIf;
	EndIf;
	
EndProcedure

// Imports queries according to the format of exchange rules.
//
// Parameters:
//  ExchangeRules  - XMLReader.
//  XMLWriter      - XMLWriter - rules to be saved to
//                   the exchange file to be used during the data import.
// 
Procedure ImportQueries(ExchangeRules, XMLWriter)

	Queries.Clear();

	XMLWriter.WriteStartElement("Queries");
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Query" Then
			ImportQuery(ExchangeRules, XMLWriter);
		ElsIf (NodeName = "Queries") And (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
			Break;
		EndIf;
		
	EndDo;

	XMLWriter.WriteEndElement();
	
EndProcedure

// Imports parameters according to the format of exchange rules.
//
// Parameters:
//  ExchangeRules  - XMLReader.
// 
Procedure ImportParameters(ExchangeRules, XMLWriter)

	Parameters.Clear();
	EventsAfterParameterImport.Clear();
	ParameterSetupTable.Clear();
	
	XMLWriter.WriteStartElement("Parameters");
	
	While ExchangeRules.Read() Do
		NodeName = ExchangeRules.LocalName;
		NodeType = ExchangeRules.NodeType;

		If NodeName = "Parameter" And NodeType = deXMLNodeType_StartElement Then
			
			//Importing by the 2.01 rule version
			Name                          = deAttribute(ExchangeRules, deStringType,  "Name");
			Description                   = deAttribute(ExchangeRules, deStringType,  "Description");
			SetInDialog                   = deAttribute(ExchangeRules, deBooleanType, "SetInDialog");
			ValueTypeString               = deAttribute(ExchangeRules, deStringType,  "ValueType");
			UsedOnImport                  = deAttribute(ExchangeRules, deBooleanType, "UsedOnImport");
			PassParameterOnExport         = deAttribute(ExchangeRules, deBooleanType, "PassParameterOnExport");
			ConversionRule                = deAttribute(ExchangeRules, deStringType,  "ConversionRule");
			AfterParameterImportAlgorithm = deAttribute(ExchangeRules, deStringType,  "AfterParameterImport");

			
			If Not IsBlankString(AfterParameterImportAlgorithm) Then
				
				EventsAfterParameterImport.Insert(Name, AfterParameterImportAlgorithm);
				
			EndIf;
			
			// Determining value types and setting initial values
			If Not IsBlankString(ValueTypeString) Then
				
				Try
					DataValueType = Type(ValueTypeString);
					TypeDefined = TRUE;
				Except
					TypeDefined = FALSE;
				EndTry;
				
			Else
				
				TypeDefined = FALSE;
				
			EndIf;
			
			If TypeDefined Then
				ParameterValue = deGetEmptyValue(DataValueType);
				Parameters.Insert(Name, ParameterValue);
			Else
				ParameterValue = "";
				Parameters.Insert(Name);
			EndIf;
						
			If SetInDialog = TRUE Then
				
				TableRow                       = ParameterSetupTable.Add();
				TableRow.Description           = Description;
				TableRow.Name                  = Name;
				TableRow.Value                 = ParameterValue;				
				TableRow.PassParameterOnExport = PassParameterOnExport;
				TableRow.ConversionRule        = ConversionRule;

				
			EndIf;
			
			If UsedOnImport
				And ExchangeMode = "Export" Then
				
				XMLWriter.WriteStartElement("Parameter");
				SetAttribute(XMLWriter, "Name",   Name);
				SetAttribute(XMLWriter, "Description", Description);
					
				If Not IsBlankString(AfterParameterImportAlgorithm) Then
					SetAttribute(XMLWriter, "AfterParameterImport", XMLString(AfterParameterImportAlgorithm));
				EndIf;
				
				XMLWriter.WriteEndElement();
				
			EndIf;

		ElsIf (NodeType = deXMLNodeType_Text) Then
			
			// Importing from the string to provide 2.0 compatibility
			ParameterString = ExchangeRules.Value;
			For Each Param In ArrayFromString(ParameterString) Do
				Parameters.Insert(Param);
			EndDo;
			
		ElsIf (NodeName = "Parameters") And (NodeType = deXMLNodeType_EndElement) Then
			Break;
		EndIf;
		
	EndDo;

	XMLWriter.WriteEndElement();

EndProcedure

// Imports the data processor according to the format of exchange rules.
//
// Parameters:
//  ExchangeRules - XMLReader.
//  XMLWriter     - XMLWriter - rules to be saved to the exchange file to be used
//                  during the data import.
// 
Procedure ImportDataProcessor(ExchangeRules, XMLWriter)

	Name                 = deAttribute(ExchangeRules, deStringType,  "Name");
	Description          = deAttribute(ExchangeRules, deStringType,  "Description");
	IsSetupDataProcessor = deAttribute(ExchangeRules, deBooleanType, "IsSetupDataProcessor");
	
	UsedOnExport         = deAttribute(ExchangeRules, deBooleanType, "UsedOnExport");
	UsedOnImport         = deAttribute(ExchangeRules, deBooleanType, "UsedOnImport");
 
	ParameterString      = deAttribute(ExchangeRules, deStringType, "Parameters");
	
	DataProcessorStorage = deElementValue(ExchangeRules, deValueStorageType);
 
	AdditionalDataProcessorParameters.Insert(Name, ArrayFromString(ParameterString));

	
	
	If UsedOnImport Then
		If ExchangeMode = "Import" Then
			
		Else
			XMLWriter.WriteStartElement("Data processor");
			SetAttribute(XMLWriter, "UsedOnImport",         True);
			SetAttribute(XMLWriter, "Name",                 Name);
			SetAttribute(XMLWriter, "Description",          Description);
			SetAttribute(XMLWriter, "IsSetupDataProcessor", IsSetupDataProcessor);
			XMLWriter.WriteText(XMLString(DataProcessorStorage));
			XMLWriter.WriteEndElement();

		EndIf;
	EndIf;
	
	If IsSetupDataProcessor Then
		If (ExchangeMode = "Import") And UsedOnImport Then
			ImportSetupDataProcessors.Add(Name, Description, , );
			
		ElsIf (ExchangeMode = "Export") And UsedOnExport Then
			ExportSetupDataProcessors.Add(Name, Description, , );
			
		EndIf; 
	EndIf; 
	
EndProcedure

// Imports external data processors according to the format of exchange rules.
//
// Parameters:
//  ExchangeRules - XMLReader.
//  XMLWriter     - XMLWriter - rules to be saved to the exchange file to be used during
//                  the data import.
//
 
Procedure ImportDataProcessors(ExchangeRules, XMLWriter)

	AdditionalDataProcessors.Clear();
	AdditionalDataProcessorParameters.Clear();
	
	ExportSetupDataProcessors.Clear();
	ImportSetupDataProcessors.Clear();

	XMLWriter.WriteStartElement("DataProcessors");
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Processing" Then
			ImportDataProcessor(ExchangeRules, XMLWriter);
		ElsIf (NodeName = "DataProcessors") And (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
			Break;
		EndIf;
		
	EndDo;

	XMLWriter.WriteEndElement();
	
EndProcedure

// Imports the data export rule group according to the format of exchange rules.
//
// Parameters:
//  ExchangeRules - XMLReader.
//  NewRow        - value tree row that describes the data export rule group.
//
 
Procedure ImportDERGroup(ExchangeRules, NewRow)

	NewRow.IsFolder = True;
	NewRow.PrivilegedModeOn  = Number(Not deAttribute(ExchangeRules, deBooleanType, "Disable"));
	
	While ExchangeRules.Read() Do
		NodeName = ExchangeRules.LocalName;
		NodeType = ExchangeRules.NodeType;
		If NodeName = "Code" Then
			NewRow.Name = deElementValue(ExchangeRules, deStringType);

		ElsIf NodeName = "Description" Then
			NewRow.Description = deElementValue(ExchangeRules, deStringType);
		
		ElsIf NodeName = "Order" Then
			NewRow.Order = deElementValue(ExchangeRules, deNumberType);
			
		ElsIf NodeName = "Rule" Then
			VTRow = NewRow.Rows.Add();
			ImportDER(ExchangeRules, VTRow);
			
		ElsIf (NodeName = "Group") And (NodeType = deXMLNodeType_StartElement) Then
			VTRow = NewRow.Rows.Add();
			ImportDERGroup(ExchangeRules, VTRow);
					
		ElsIf (NodeName = "Group") And (NodeType = deXMLNodeType_EndElement) Then
			Break;
		EndIf;
		
	EndDo;

	
	If IsBlankString(NewRow.Description) Then
		NewRow.Description = NewRow.Name;
	EndIf; 
	
EndProcedure

// Imports the data export rule according to the format of exchange rules.
//
// Parameters:
//  ExchangeRules - XMLReader.
//  NewRow        - value tree row that describes the data export rule.
// 
Procedure ImportDER(ExchangeRules, NewRow)

	NewRow.PrivilegedModeOn = Number(Not deAttribute(ExchangeRules, deBooleanType, "Disable"));
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		If NodeName = "Code" Then
			NewRow.Name = deElementValue(ExchangeRules, deStringType);

		ElsIf NodeName = "Description" Then
			NewRow.Description = deElementValue(ExchangeRules, deStringType);
		
		ElsIf NodeName = "Order" Then
			NewRow.Order = deElementValue(ExchangeRules, deNumberType);
			
		ElsIf NodeName = "DataSelectionVariant" Then
			NewRow.DataSelectionVariant = deElementValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "SelectExportDataInSingleQuery" Then
			NewRow.SelectExportDataInSingleQuery = deElementValue(ExchangeRules, deBooleanType);
			
		ElsIf NodeName = "DontExportCreatedInTargetInfobaseObjects" Then
			// Skipping the parameter during the data exchange
			DontExportCreatedInTargetInfobaseObjects = deElementValue(ExchangeRules, deBooleanType);

		ElsIf NodeName = "SelectionObject" Then
			SelectionObject = deElementValue(ExchangeRules, deStringType);
			If Not IsBlankString(SelectionObject) Then
				NewRow.SelectionObject = Type(SelectionObject);
			EndIf;
			// For filtering using the query builder
			If Find(SelectionObject, "Ref.") Then
				NewRow.ObjectForQueryName = StrReplace(SelectionObject, "Ref.", ".");
			Else
				NewRow.ObjectNameForRegisterQuery = StrReplace(SelectionObject, "Write.", ".");
			EndIf;

		ElsIf NodeName = "ConversionRuleCode" Then
			NewRow.ConversionRule = deElementValue(ExchangeRules, deStringType);

		// Events handlers

		ElsIf NodeName = "BeforeProcessRule" Then
			NewRow.BeforeProcess = GetHandlerValueFromText(ExchangeRules);
			
		ElsIf NodeName = "AfterProcessRule" Then
			NewRow.AfterProcess = GetHandlerValueFromText(ExchangeRules);
		
		ElsIf NodeName = "BeforeExportObject" Then
			NewRow.BeforeExport = GetHandlerValueFromText(ExchangeRules);

		ElsIf NodeName = "AfterExportObject" Then
			NewRow.AfterExport = GetHandlerValueFromText(ExchangeRules);
        		
		ElsIf (NodeName = "Rule") And (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
			Break;
		EndIf;
		
	EndDo;

	If IsBlankString(NewRow.Description) Then
		NewRow.Description = NewRow.Name;
	EndIf; 
	
EndProcedure

// Imports the data export rules according to the format of exchange rules.
//
// Parameters:
//  ExchangeRules - XMLReader object.
// 
Procedure ImportExportRules(ExchangeRules)

	ExportRuleTable.Rows.Clear();

	VTRows = ExportRuleTable.Rows;
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Rule" Then
			
			VTRow = VTRows.Add();
			ImportDER(ExchangeRules, VTRow);
			
		ElsIf NodeName = "Group" Then
			
			VTRow = VTRows.Add();
			ImportDERGroup(ExchangeRules, VTRow);
			
		ElsIf (NodeName = "DataExportRules") And (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
			
			Break;
			
		EndIf;
		
	EndDo;

	VTRows.Sort("Order", True);

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES FOR EXPORTING HANDLERS AND ALGORITHMS TO THE TXT FILE FROM EXCHANGE RULES.

// Exports event handlers and algorithms into the temporary text file  (in the temporary
// user directory).
// Generates a debugging module with handlers, algorithms, required global
// variables, wrappers of common functions, and comments.
//
// Parameters:
//  Cancel - cancellation flag. Is set in case of exchange rule reading failure.
//  
Procedure ExportEventHandlers(Cancel) Export
	
	EnableExchangeLogForHandlerExport();
	
	DataProcessingMode = mDataProcessingModes.EventHandlerExport;
	
	ErrorFlag = False;
	
	ImportExchangeRulesForHandlerExport();
	
	If ErrorFlag Then
		Cancel = True;
		Return;
	EndIf; 
	
	SupplementRulesWithHandlerInterfaces(Conversion, ConversionRuleTable, ExportRuleTable, ClearingRuleTable);
	
	If AlgorithmDebugMode = mAlgorithmDebugModes.CodeIntegration Then
		
		GetFullAlgorithmScriptRecursively();
		
	EndIf;
	
	//Getting a unique file name
	EventHandlerTempFileName = GetNewUniqueTempFileName("EventHandlers", "txt", EventHandlerTempFileName);
	
	Result = New TextWriter(EventHandlerTempFileName, TextEncoding.ANSI);
	
	mCommonProceduresFunctionsTemplate = GetTemplate("CommonProceduresFunctions");
	
	//Adding comments
	AddCommentToStream(Result, "Header");
	AddCommentToStream(Result, "DataProcessorVariables");
	
	//Adding the service script
	AddServiceCodeToStream(Result, "DataProcessorVariables");
	
	//Exporting global handlers
	ExportConversionHandlers(Result);
	
    //Exporting DER
	AddCommentToStream(Result, "DER", ExportRuleTable.Rows.Count() <> 0);
	ExportDataExportRuleHandlers(Result, ExportRuleTable.Rows);
	
    //Exporting DCR
	AddCommentToStream(Result, "DCP", ClearingRuleTable.Rows.Count() <> 0);
	ExportDataClearingRuleHandlers(Result, ClearingRuleTable.Rows);
	
	//Exporting OCR, PCR, PGCR
	ExportConversionRuleHandlers(Result);
	
	If AlgorithmDebugMode = mAlgorithmDebugModes.ProceduralCall Then
		
		//Exporting algorithms with standard (default) parameters
		ExportAlgorithms(Result);
		
	EndIf; 
	
	//Adding comments
	AddCommentToStream(Result, "Warning");
	AddCommentToStream(Result, "CommonProceduresFunctions");
		
	//Adding common procedures and functions to the stream
	AddServiceCodeToStream(Result, "CommonProceduresFunctions");

	//Adding the external data processor constructor
	ExportExternalDataProcessorConstructor(Result);
	
	//Adding the destructor
	AddServiceCodeToStream(Result, "Destructor");
	
	Result.Close();
	
	DisableExchangeProtocol();
	
	If IsInteractiveMode Then
		
		If ErrorFlag Then
			
			MessageToUser(NStr("en = 'Error exporting handlers.'"));
			
		Else
			
			MessageToUser(NStr("en = 'Handlers has been successfully exported.'"));
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Clears variables that contain the exchange rule structure.
//
Procedure ClearExchangeRules()
	
	ExportRuleTable.Rows.Clear();
	ClearingRuleTable.Rows.Clear();
	ConversionRuleTable.Clear();
	Algorithms.Clear();
	Queries.Clear();

	//DataProcessors
	AdditionalDataProcessors.Clear();
	AdditionalDataProcessorParameters.Clear();
	ExportSetupDataProcessors.Clear();
	ImportSetupDataProcessors.Clear();

EndProcedure  

// Imports the exchange rules from the rule file or data file.
//
Procedure ImportExchangeRulesForHandlerExport()
	
	ClearExchangeRules();
	
	If ReadEventHandlersFromExchangeRuleFile Then
		
		ExchangeMode = ""; //Export

		ImportExchangeRules();
		
		mExchangeRulesReadOnImport = False;
		
		InitializeInitialParameterValues();
		
	Else //Data file
		
		ExchangeMode = "Import"; 
		
		If IsBlankString(ExchangeFileName) Then
			WriteToExecutionLog(15);
			Return;
		EndIf;
		
		OpenImportFile(True);
		
		//If the flag is set, the data processor requires to reimport rules on data export start
		mExchangeRulesReadOnImport = True;

	EndIf;
	
EndProcedure

// Exports global conversion handlers into a text file.
//  
// Parameters:
//  Result - TextWriter to be used for the handler export.
//  
// Note:
//  The Conversion_AfterParameterImport handler content is not exported during the
//  handler export due to handler script does not placed in the exchange rule node but
//  in a separate node.
//  During the handler export from the rule file, this algorithm exported as all others.
//
Procedure ExportConversionHandlers(Result)
	
	AddCommentToStream(Result, "Conversion");
	
	For Each Item In HandlerNames.Conversion Do
		
		AddConversionHandlerToStream(Result, Item.Key);
		
	EndDo; 
	
EndProcedure 

// Exports data export rule handlers into a text file.
//
// Parameters:
//  Result   - TextWriter - to be used for the handler export.
//  TreeRows - ValueTreeRowCollection - contains DER of the current value tree level.
// 
Procedure ExportDataExportRuleHandlers(Result, TreeRows)
	
	For Each Rule In TreeRows Do
		
		If Rule.IsFolder Then
			
			ExportDataExportRuleHandlers(Result, Rule.Rows); 
			
		Else
			
			For Each Item In HandlerNames.DER Do
				
				AddHandlerToStream(Result, Rule, "DER", Item.Key);
				
			EndDo; 
			
		EndIf; 
		
	EndDo; 
	
EndProcedure  

// Exports data clearing rule handlers into a text file.
//
// Parameters:
//  Result   - TextWriter - to be used for the handler export.
//  TreeRows - ValueTreeRowCollection - contains DCR of the current value tree level.
// 
Procedure ExportDataClearingRuleHandlers(Result, TreeRows)
	
	For Each Rule In TreeRows Do
		
		If Rule.IsFolder Then
			
			ExportDataClearingRuleHandlers(Result, Rule.Rows); 
			
		Else
			
			For Each Item In HandlerNames.DCP Do
				
				AddHandlerToStream(Result, Rule, "DCP", Item.Key);
				
			EndDo; 
			
		EndIf; 
		
	EndDo; 
	
EndProcedure  

// Exports handlers of conversion rules (OCR, PCR, PGCR) into a text file.
//
// Parameters:
//  Result - TextWriter - to be used for the handler export.
// 
Procedure ExportConversionRuleHandlers(Result)
	
	DisplayComment = ConversionRuleTable.Count() <> 0;
	
	//Exporting OCR
	AddCommentToStream(Result, "OCR", DisplayComment);
 
	For Each OCR In ConversionRuleTable Do
		
		For Each Item In HandlerNames.OCR Do
			
			AddOCRHandlerToStream(Result, OCR, Item.Key);
			
		EndDo; 
		
	EndDo; 
	
	//Exporting PCR and PGCR
	AddCommentToStream(Result, "PCR", DisplayComment);
	
	For Each OCR In ConversionRuleTable Do
		
		ExportPropertyConversionRuleHandlers(Result, OCR.SearchProperties);
		ExportPropertyConversionRuleHandlers(Result, OCR.Properties);
		
	EndDo; 
	
EndProcedure 

// Exports property conversion rule handlers into a text file.
//
// Parameters:
//  Result - TextWriter - to be used for the handler export.
//  PCR    - ValueTable - contains property conversion rules or property group conversion rules.
// 
Procedure ExportPropertyConversionRuleHandlers(Result, PCR)
	
	For Each Rule In PCR Do
		
		If Rule.IsFolder Then //PGCR
			
			For Each Item In HandlerNames.PGCR Do
				
				AddOCRHandlerToStream(Result, Rule, Item.Key);
				
			EndDo; 

			ExportPropertyConversionRuleHandlers(Result, Rule.GroupRules);
			
		Else
			
			For Each Item In HandlerNames.PCR Do
				
				AddOCRHandlerToStream(Result, Rule, Item.Key);
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Exports algorithms into a text file.
//
// Parameters:
//  Result - TextWriter.
// 
Procedure ExportAlgorithms(Result)
	
	//Commenting the Algorithms block
	AddCommentToStream(Result, "Algorithms", Algorithms.Count() <> 0);
	
	For Each Algorithm In Algorithms Do
		
		AddAlgorithmToSteam(Result, Algorithm);
		
	EndDo; 
	
EndProcedure  

// Exports the external data processor constructor into a text file.
//  If the algorithm debugging mode is "Debug algorithms as procedures", the Algorithms
//   structure is added to the constructor.
//  Structure item key is an algorithm name, value is an procedure call interface that
//   contains an algorithm script.
//
// Parameters:
//  Result - TextWriter.
//
 
Procedure ExportExternalDataProcessorConstructor(Result)
	
	//Displaying the comment
	AddCommentToStream(Result, "Constructor");
	
	ProcedureBody = GetServiceCode("Constructor_ProcedureBody");

	If AlgorithmDebugMode = mAlgorithmDebugModes.ProceduralCall Then
		
		ProcedureBody = ProcedureBody + GetServiceCode("Constructor_ProcedureBody_ProceduralAlgorithmCall");
		
		//Adding algorithm calls to the constructor body
		For Each Algorithm In Algorithms Do
			
			AlgorithmKey = TrimAll(Algorithm.Key);
			
			AlgorithmInterface = GetAlgorithmInterface(AlgorithmKey) + ";";
			
			AlgorithmInterface = StrReplace(StrReplace(AlgorithmInterface, Chars.LF, " ")," ","");
			
			ProcedureBody = ProcedureBody + Chars.LF 
			   + "Algorithms.Insert(""" + AlgorithmKey + """, """ + AlgorithmInterface + """);";

			
		EndDo; 
		
	ElsIf AlgorithmDebugMode = mAlgorithmDebugModes.CodeIntegration Then
		
		ProcedureBody = ProcedureBody + GetServiceCode("Constructor_ProcedureBody_AlgorithmCodeIntegration");
		
	ElsIf AlgorithmDebugMode = mAlgorithmDebugModes.DontUse Then
		
		ProcedureBody = ProcedureBody + GetServiceCode("Constructor_ProcedureBody_DontUseAlgorithmDebug");
		
	EndIf; 
	
	ExternalDataProcessorProcedureInterface = "Procedure " + GetExternalDataProcessorProcedureInterface("Constructor") + " Export";
	
	AddFullHandlerToStream(Result, ExternalDataProcessorProcedureInterface, ProcedureBody);
	
EndProcedure  


// Adds the OCR, PCR, or PGCR handler to the Result object. 
//
// Parameters:
//  Result      - TextWriter.
//  Rule        - value table row that contains object conversion rules.
//  HandlerName - String - handler name.
//  
Procedure AddOCRHandlerToStream(Result, Rule, HandlerName)
	
	If Not Rule["HasHandler" + HandlerName] Then
		Return;
	EndIf; 
	
	HandlerInterface = "Procedure " + Rule["HandlerInterface" + HandlerName] + " Export";
	
	AddFullHandlerToStream(Result, HandlerInterface, Rule[HandlerName]);
	
EndProcedure  

// Adds the algorithm script to the Result object.
//
// Parameters:
//  Result    - TextWriter.
//  Algorithm - structure item - algorithm to be added.
//  
Procedure AddAlgorithmToSteam(Result, Algorithm)
	
	AlgorithmInterface = "Procedure " + GetAlgorithmInterface(Algorithm.Key);

	AddFullHandlerToStream(Result, AlgorithmInterface, Algorithm.Value);
	
EndProcedure  

// Adds the DCR or DER handler to the Result object. 
//
// Parameters:
//  Result        - TextWriter.
//  Rule          - value tree row with rules.
//  HandlerPrefix - String - handler prefix: "DER" or "DCR".
//  HandlerName   - String - handler name.
//  
Procedure AddHandlerToStream(Result, Rule, HandlerPrefix, HandlerName)
	
	If IsBlankString(Rule[HandlerName]) Then
		Return;
	EndIf;
	
	HandlerInterface = "Procedure " + Rule["HandlerInterface" + HandlerName] + " Export";
	
	AddFullHandlerToStream(Result, HandlerInterface, Rule[HandlerName]);
	
EndProcedure  

// Adds the global conversion handler to the Result object. 
//
// Parameters:
//  Result      - TextWriter.
//  HandlerName - String - handler name.
//  
Procedure AddConversionHandlerToStream(Result, HandlerName)
	
	HandlerAlgorithm = "";
	
	If Conversion.Property(HandlerName, HandlerAlgorithm) And Not IsBlankString(HandlerAlgorithm) Then
		
		HandlerInterface = "Procedure " + Conversion["HandlerInterface" + HandlerName] + " Export";
		
		AddFullHandlerToStream(Result, HandlerInterface, HandlerAlgorithm);
		
	EndIf;
	
EndProcedure  

// Adds the procedure with the handler script or the algorithm script to the Result object.
//
// Parameters:
//  Result           - TextWriter.
//  HandlerInterface - String - full handler interface description:
//                     procedure name, parameters, "Export" keyword.
//  Handler          - String - handler or algorithm body.
//

Procedure AddFullHandlerToStream(Result, HandlerInterface, Handler)
	
	PrefixString = Chars.Tab;
	
	Result.WriteLine("");
	
	Result.WriteLine(HandlerInterface);
	
	Result.WriteLine("");
	
	For Index = 1 To StrLineCount(Handler) Do
		
		HandlerRow = StrGetLine(Handler, Index);
		
		// In the "Script integration" algorithm debugging mode the algorithm script is 
		// inserted directly into the handler script. The algorithm script is inserted 
		// instead of this algorithm call.
		// Algorithms can be nested. The algorithm scripts support nested algorithms.

		If AlgorithmDebugMode = mAlgorithmDebugModes.CodeIntegration Then
			
			HandlerAlgorithms = GetHandlerAlgorithms(HandlerRow);
			
			If HandlerAlgorithms.Count() <> 0 Then //There are algorithm calls in the line
				
				//Getting the initial algorithm script offset relative to the current handler script
				PrefixStringForInlineCode = GetInlineAlgorithmPrefix(HandlerRow, PrefixString);
				
				For Each Algorithm In HandlerAlgorithms Do
					
					AlgorithmHandler = IntegratedAlgorithms[Algorithm];
					
					For AlgorithmRowIndex = 1 To StrLineCount(AlgorithmHandler) Do
						
						Result.WriteLine(PrefixStringForInlineCode + StrGetLine(AlgorithmHandler, AlgorithmRowIndex));
						
					EndDo;	
					
				EndDo;
				
			EndIf;
		EndIf;

		Result.WriteLine(PrefixString + HandlerRow);
		
	EndDo;
	
	Result.WriteLine("");
	Result.WriteLine("EndProcedure");
	
EndProcedure

// Adds the comment to the Result object. 
//
// Parameters:
//  Result         - TextWriter.
//  AreaName       - String - name of the mCommonProceduresFunctionsTemplate text 
//                   template area that contains the required comment.
//  DisplayComment - Boolean - flag that shows whether the comment must be displayed to 
//                   a user.
//

Procedure AddCommentToStream(Result, AreaName, DisplayComment = True)
	
	If Not DisplayComment Then
		Return;
	EndIf; 
	
	//Getting handler comments by the area name
	CurrentArea = mCommonProceduresFunctionsTemplate.GetArea(AreaName+"_Comment");
	
	CommentFromTemplate = TrimAll(GetTextByAreaWithoutAreaTitle(CurrentArea));
	
	CommentFromTemplate = Mid(CommentFromTemplate, 1, StrLen(CommentFromTemplate)); //Excluding last end of line character
	
	Result.WriteLine(Chars.LF + Chars.LF + CommentFromTemplate);
	
EndProcedure  

// Adds the service script to the Result object (Parameters, common procedures and functions, the external data processor destructor). 
//
// Parameters:
//  Result   - TextWriter.
//  AreaName - String - name of the mCommonProceduresFunctionsTemplate text template
//             area that contains the required service script.
//

Procedure AddServiceCodeToStream(Result, AreaName)
	
	//Getting the area text
	CurrentArea = mCommonProceduresFunctionsTemplate.GetArea(AreaName);
	
	Text = TrimAll(GetTextByAreaWithoutAreaTitle(CurrentArea));
	
	Text = Mid(Text, 1, StrLen(Text)); //Excluding last end of line character
	
	Result.WriteLine(Chars.LF + Chars.LF + Text);
	
EndProcedure  

// Retrieves the service script from the specified mCommonProceduresFunctionsTemplate template area.
//  
// Parameters:
//  AreaName - String - mCommonProceduresFunctionsTemplate text template area.
//  
// Returns:
//  Text from the template.
//
Function GetServiceCode(AreaName)
	
	//Getting the area text
	CurrentArea = mCommonProceduresFunctionsTemplate.GetArea(AreaName);
	
	Return GetTextByAreaWithoutAreaTitle(CurrentArea);
EndFunction

//////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS THAT IS USED FOR RETRIEVING THE FULL ALGORITHM SCRIPTS. 
// ALGORITHM SCRIPTS CAN BE NESTED.

// Generates the full algorithm script taking algorithm nesting into account.
//  
Procedure GetFullAlgorithmScriptRecursively()
	
	//Filling the structure of integrated algorithms
	IntegratedAlgorithms = New Structure;
	
	For Each Algorithm In Algorithms Do
		
		IntegratedAlgorithms.Insert(Algorithm.Key, ReplaceAlgorithmCallsWithTheirHandlerScript(Algorithm.Value, Algorithm.Key, New Array));
		
	EndDo; 
	
EndProcedure 

// Adds the next script insert comment to the NewHandler string.
//
// Parameters:
//  NewHandler    - String - result string that contains full algorithm scripts taking
//                  algorithm nesting into account.
//  AlgorithmName - String - algorithm name.
//  PrefixString  - String - sets the initial offset of the comment to be inserted
//  Title         - String - comment description: "{START ALGORITHM}", "{END ALGORITHM}".
//

Procedure WriteAlgorithmBlockTitle(NewHandler, AlgorithmName, PrefixString, Title) 
	
	AlgorithmTitle = "//============================ " + Title + " """ + AlgorithmName + """ ============================";
	
	NewHandler = NewHandler + Chars.LF;
	NewHandler = NewHandler + Chars.LF + PrefixString + AlgorithmTitle;
	NewHandler = NewHandler + Chars.LF;
	
EndProcedure  

// Complements the HandlerAlgorithms array with names of algorithms that are called 
// from the passed procedure of the HandlerLine handler line.
//
// Parameters:
//  HandlerLine       - String - handler line or algorithm line where algorithm calls 
//                      are searched.
//  HandlerAlgorithms - Array - names of algorithms that are called from the specified
//                      handler.
//  
Procedure GetHandlerStringAlgorithms(HandlerRow, HandlerAlgorithms)
	
	HandlerRow = Upper(HandlerRow);
	
	SearchTemplate = "ALGORITHMS.";
	
	PatternStringLength = StrLen(SearchTemplate);
	
	InitialChar = Find(HandlerRow, SearchTemplate);
	
	If InitialChar = 0 Then
		//There are no algorithms or all algorithms from this line have been taken into account.
		Return; 
	EndIf;
	
	//Checking whether this operator is commented
	HandlerLineBeforeAlgorithmCall = Left(HandlerRow, InitialChar);
	
	If Find(HandlerLineBeforeAlgorithmCall, "//") <> 0  Then 
		//The current operator and all next operators are commented.
		//Exiting loop
		Return;
	EndIf; 
	
	HandlerRow = Mid(HandlerRow, InitialChar + PatternStringLength);
	
	EndChar = Find(HandlerRow, ")") - 1;
	
	AlgorithmName = Mid(HandlerRow, 1, EndChar); 
	
	HandlerAlgorithms.Add(TrimAll(AlgorithmName));
	
	//Going through the handler line to consider all algorithm calls
	GetHandlerStringAlgorithms(HandlerRow, HandlerAlgorithms);
	
EndProcedure 

// Returns the modified algorithm script taking nested algorithms into account. Instead
// of the "Execute(Algorithms.Algorithm_1);" algorithm call operator, the calling
// algorithm script is inserted with the PrefixString offset.
 
// Recursively calls itself to take into account all nested algorithms. 
 
//  
// Parameters:
//  Handler            - String - initial algorithm script.
//  PrefixString       - String - inserting algorithm script offset mode.
//  AlgorithmOwner     - String - name of the parent algorithm.
//  RequestedItemArray - Array - names of algorithms that were already processed in this
//                       recursion branch. It is used to prevent endless function 
//                       recursion and to display the error message.
//  
// Returns:
//  NewHandler         - String - modified algorithm script that took nested into account.
//
 
Function ReplaceAlgorithmCallsWithTheirHandlerScript(Handler, AlgorithmOwner, RequestedItemArray, Val PrefixString = "")
	
	RequestedItemArray.Add(Upper(AlgorithmOwner));
	
	//Initializing the return value
	NewHandler = "";
	
	WriteAlgorithmBlockTitle(NewHandler, AlgorithmOwner, PrefixString, NStr("en = '{ALGORITHM START}'"));
	
	For Index = 1 To StrLineCount(Handler) Do
		
		HandlerRow = StrGetLine(Handler, Index);
		
		HandlerAlgorithms = GetHandlerAlgorithms(HandlerRow);
		
		If HandlerAlgorithms.Count() <> 0 Then //There are algorithm calls in the line
			
			//Getting the initial algorithm script offset relative to the current handler script
			PrefixStringForInlineCode = GetInlineAlgorithmPrefix(HandlerRow, PrefixString);
				
			//Extracting full scripts for all algorithms that were called from HandlerLine 
			For Each Algorithm In HandlerAlgorithms Do
				
				If RequestedItemArray.Find(Upper(Algorithm)) <> Undefined Then //recursive algorithm call
					
					WriteAlgorithmBlockTitle(NewHandler, Algorithm, PrefixStringForInlineCode, NStr("en = '{RECURSIVE ALGORITHM CALL}'"));
					
					OperatorString = NStr("en = 'Raise ""RECURSIVE ALGORITHM CALL: %1"";'");
					OperatorString = SubstituteParametersInString(OperatorString, Algorithm);
					
					NewHandler = NewHandler + Chars.LF + PrefixStringForInlineCode + OperatorString;
					
					WriteAlgorithmBlockTitle(NewHandler, Algorithm, PrefixStringForInlineCode, NStr("en = '{RECURSIVE ALGORITHM CALL}'"));
					
					RecordStructure = New Structure;
					RecordStructure.Insert("Algorithm_1", AlgorithmOwner);
					RecordStructure.Insert("Algorithm_2", Algorithm);
					
					WriteToExecutionLog(79, RecordStructure);
					
				Else
					
					NewHandler = NewHandler + ReplaceAlgorithmCallsWithTheirHandlerScript(Algorithms[Algorithm], Algorithm, CopyArray(RequestedItemArray), PrefixStringForInlineCode);
					
				EndIf; 
				
			EndDo;
			
		EndIf; 
		
		NewHandler = NewHandler + Chars.LF + PrefixString + HandlerRow; 
		
	EndDo;
	
	WriteAlgorithmBlockTitle(NewHandler, AlgorithmOwner, PrefixString, NStr("en = '{END ALGORITHM}'"));
	
	Return NewHandler;
	
EndFunction

// Copies the passed array and returns a new one.
//  
// Parameters:
//  SourceArray - Array - source array to be copied.
//  
// Returns:
//  NewArray - Array - result array.
// 
Function CopyArray(SourceArray)
	
	NewArray = New Array;
	
	For Each ArrayElement In SourceArray Do
		
		NewArray.Add(ArrayElement);
		
	EndDo; 
	
	Return NewArray;
EndFunction 

// Returns an array of names of algorithms that were detected in the body of the passed handler.
//  
// Parameters:
//  Handler - String - handler body.
//  
// Returns:
//  HandlerAlgorithms - Array - result array.
//
Function GetHandlerAlgorithms(Handler)
	
	//Initializing the return value
	HandlerAlgorithms = New Array;
	
	For Index = 1 To StrLineCount(Handler) Do
		
		HandlerRow = TrimL(StrGetLine(Handler, Index));
		
		If Left(HandlerRow, 2) = "//" Then //Skipping the commented string
			Continue;
		EndIf;
		
		GetHandlerStringAlgorithms(HandlerRow, HandlerAlgorithms);
		
	EndDo;
	
	Return HandlerAlgorithms;
EndFunction 

// Generates a prefix string for outputting the script of the nested algorithm.
//
// Parameters:
//  HandlerLine               - String - source string where the call offset value will
//                              be retrieved from.
//  PrefixString              - String - initial the offset.
// Return:
//  PrefixStringForInlineCode - String - result algorithm script offset.
//
 
Function GetInlineAlgorithmPrefix(HandlerRow, PrefixString)
	
	HandlerRow = Upper(HandlerRow);
	
	TemplatePositionNumberExecute = Find(HandlerRow, "EXECUTE");
	
	PrefixStringForInlineCode = PrefixString + Left(HandlerRow, TemplatePositionNumberExecute - 1) + Chars.Tab;
	
	//If the handler line contained an algorithm call, clearing the handler line
	HandlerRow = "";
	
	Return PrefixStringForInlineCode;
EndFunction 

//////////////////////////////////////////////////////////////////////////////
// FUNCTIONS FOR FORMATTING UNIQUE EVENT HANDLER NAMES.

// Generates a PCR or PGCR handler interface. (Generates a unique name of the procedure
// with parameters of the corresponding handler).
//
// Parameters:
//  OCR         - Value table row - contains the object conversion rule.
//  PGCR        - Value table row - contains the property group conversion rule.
//  Rule        - Value table row - contains the object property conversion rule.
//  HandlerName - String - event handler name.
//
// Returns:
//  String - handler interface.
//
 
Function GetPCRHandlerInterface(OCR, PGCR, Rule, HandlerName)
	
	AreaName = "CR" + ?(Rule.IsFolder, "D", "") + "From_" + HandlerName;
	
	OwnerName = "_" + TrimAll(OCR.Name);
	
	ParentName  = "";
	
	If PGCR <> Undefined Then
		
		If Not IsBlankString(PGCR.TargetKind) Then 
			
			ParentName = "_" + TrimAll(PGCR.Target);	
			
		EndIf; 
		
	EndIf; 
	
	TargetName = "_" + TrimAll(Rule.Target);
	TargetKind = "_" + TrimAll(Rule.TargetKind);
	
	PropertyCode = TrimAll(Rule.Name);
	
	FullHandlerName = AreaName + OwnerName + ParentName + TargetName + TargetKind + PropertyCode;
	
	Return FullHandlerName + "(" + GetHandlerParameters(AreaName) + ")";
EndFunction 

// Generates a OCR, DER, or DCR handler interface. (Generates a unique name of the 
// procedure with parameters of the corresponding handler).
//
// Parameters:
//  Rule          - arbitrary value collection - OCR, DER, DCR.
//  HandlerPrefix - String - can takes the following values: "OCR", "DER", "DCR".
//  HandlerName   - String - the name handler events for this rules.
//
// Returns:
//  String - handler interface.
//
 
Function GetHandlerInterface(Rule, HandlerPrefix, HandlerName)
	
	AreaName = HandlerPrefix + "_" + HandlerName;
	
	RuleName = "_" + TrimAll(Rule.Name);
	
	FullHandlerName = AreaName + RuleName;
	
	Return FullHandlerName + "(" + GetHandlerParameters(AreaName) + ")";
EndFunction 

// Generates the interface of the global conversion handler (Generates a unique name of
// the procedure with parameters of the corresponding handler).
//
// Parameters:
//  HandlerName - String - conversion event handler name.
//
// Returns:
//  String - handler interface.
//
 
Function GetConversionHandlerInterface(HandlerName)
	
	AreaName = "Conversion_" + HandlerName;
	
	FullHandlerName = AreaName;
	
	Return FullHandlerName + "(" + GetHandlerParameters(AreaName) + ")";
EndFunction 

// Generates a procedure interface (constructor or destructor) for the external data
// processor.
//
// Parameters:
//  ProcedureName - String - procedure name.
//
// Returns:
//  String - handler interface.
//
 
Function GetExternalDataProcessorProcedureInterface(ProcedureName)
	
	AreaName = "DataProcessor_" + ProcedureName;
	
	FullHandlerName = ProcedureName;
	
	Return FullHandlerName + "(" + GetHandlerParameters(AreaName) + ")";
EndFunction 

// Forms Interface algorithm for external processing.
// For all algorithms Get the same set parameters to default.
//
// Parameters:
//  AlgorithmName - String - algorithm name.
//
// Returns:
//  String - algorithm interface.
//
 
Function GetAlgorithmInterface(AlgorithmName)
	
	FullHandlerName = "Algorithm_" + AlgorithmName;
	
	AreaName = "Algorithm_Default";
	
	Return FullHandlerName + "(" + GetHandlerParameters(AreaName) + ")";
EndFunction 

Function GetHandlerCallString(Rule, HandlerName)
	
	Return "EventHandlerExternalDataProcessor." + Rule["HandlerInterface" + HandlerName] + ";";
	
EndFunction 

Function GetTextByAreaWithoutAreaTitle(Area)
	
	AreaText = Area.GetText();
	
	If Find(AreaText, "#Region") > 0 Then
	
		FirstLinefeed = Find(AreaText, Chars.LF);
		
		AreaText = Mid(AreaText, FirstLinefeed + 1);
		
	EndIf;
	
	Return AreaText;
	
EndFunction

Function GetHandlerParameters(AreaName)
	
	NewLineString = Chars.LF + "                                           ";
	
	HandlerParameters = "";
	
	TotalString = "";
	
	Region = mHandlerParameterTemplate.GetArea(AreaName);
	
	ParameterArea = Region.Areas[AreaName];
	
	For LineNumber = ParameterArea.Top To ParameterArea.Bottom Do
		
		CurrentArea = Region.GetArea(LineNumber, 2, LineNumber, 2);
		
		Parameter = TrimAll(CurrentArea.CurrentArea.Text);
		
		If Not IsBlankString(Parameter) Then
			
			HandlerParameters = HandlerParameters + Parameter + ", ";
			
			TotalString = TotalString + Parameter;
			
		EndIf; 
		
		If StrLen(TotalString) > 50 Then
			
			TotalString = "";
			
			HandlerParameters = HandlerParameters + NewLineString;
			
		EndIf; 
		
	EndDo;
	
	HandlerParameters = TrimAll(HandlerParameters);
	
	//Deleting the last "," character and returning the string
	
	Return Mid(HandlerParameters, 1, StrLen(HandlerParameters) - 1); 
EndFunction 


////////////////////////////////////////////////////////////////////////////////
// PROCEDURES FOR GENERATING HANDLER CALL INTERFACES IN EXCHANGE RULES.

// Complements the available exchange rule collections with handler call interfaces.
//
// Parameters:
//  ConversionStructure - Structure - contains the conversion rules and global handlers.
//  OCRTable            - ValueTable - contains the objects conversion rules.
//  DERTable            - ValueTree - contains the data export rules.
//  DCRTable            - ValueTree - contains the data clearing rules.
//  
Procedure SupplementRulesWithHandlerInterfaces(ConversionStructure, OCRTable, DERTable, DCPTable) Export
	
	mHandlerParameterTemplate = GetTemplate("HandlerParameters");
	
	//Adding the Conversion interfaces (global)
	SupplementWithConversionRuleInterfaceHandler(ConversionStructure);
	
	//Adding the DER interfaces
	SupplementDataExportRulesWithHandlerInterfaces(DERTable, DERTable.Rows);
	
	//Adding the DCR interfaces
	SupplementWithDataClearingRuleHandlerInterfaces(DCPTable, DCPTable.Rows);
	
	//Adding the OCR, PCR, PGCR interfaces
	SupplementWithObjectConversionRuleHandlerInterfaces(OCRTable);
	
EndProcedure 

// Complements the data clearing rule value collection with handler interfaces.
//
// Parameters:
//  DCRTable - ValueTree - contains data clearing rules.
//  TreeRows - ValueTreeRowCollection - contains DCR of the current value tree level.
//  
Procedure SupplementWithDataClearingRuleHandlerInterfaces(DCPTable, TreeRows)
	
	For Each Rule In TreeRows Do
		
		If Rule.IsFolder Then
			
			SupplementWithDataClearingRuleHandlerInterfaces(DCPTable, Rule.Rows); 
			
		Else
			
			For Each Item In HandlerNames.DCP Do
				
				AddHandlerInterface(DCPTable, Rule, "DCP", Item.Key);
				
			EndDo; 
			
		EndIf; 
		
	EndDo; 
	
EndProcedure  

// Complements the data export rule value collection with handler interfaces.
//
// Parameters:
//  DERTable - ValueTree - contains the data export rules.
//  TreeRows - Object type ValueTreeRowCollection - contains DER of the current value tree level.
//  
Procedure SupplementDataExportRulesWithHandlerInterfaces(DERTable, TreeRows) 
	
	For Each Rule In TreeRows Do
		
		If Rule.IsFolder Then
			
			SupplementDataExportRulesWithHandlerInterfaces(DERTable, Rule.Rows); 
			
		Else
			
			For Each Item In HandlerNames.DER Do
				
				AddHandlerInterface(DERTable, Rule, "DER", Item.Key);
				
			EndDo; 
			
		EndIf; 
		
	EndDo; 
	
EndProcedure  

// Complements the conversion structure with handler interfaces.
//
// Parameters:
//  ConversionStructure - Structure - contains the conversion rules and global handlers.
//  
Procedure SupplementWithConversionRuleInterfaceHandler(ConversionStructure) 
	
	For Each Item In HandlerNames.Conversion Do
		
		AddConversionHandlerInterface(ConversionStructure, Item.Key);
		
	EndDo; 
	
EndProcedure  

// Complements the object conversion rule value collection with handler interfaces.
//
// Parameters:
//  OCRTable - ValueTable - contains the object conversion rules.
//  
Procedure SupplementWithObjectConversionRuleHandlerInterfaces(OCRTable)
	
	For Each OCR In OCRTable Do
		
		For Each Item In HandlerNames.OCR Do
			
			AddOCRHandlerInterface(OCRTable, OCR, Item.Key);
			
		EndDo; 
		
		//Adding the interfaces for PCR
		SupplementWithPCRHandlerInterfaces(OCR, OCR.SearchProperties);
		SupplementWithPCRHandlerInterfaces(OCR, OCR.Properties);
		
	EndDo; 
	
EndProcedure

// Complements the object property conversion rule value collection with handler interfaces.
//
// Parameters:
//  OCR                           - value table row - contains the object conversion rule. 
//  ObjectPropertyConversionRules - ValueTable - contains the property conversion rules
//                                  or the object property group from the OCR rules.
//  PGCR                          - value table row - contains the property group
//                                  conversion rule.
//
Procedure SupplementWithPCRHandlerInterfaces(OCR, ObjectPropertyConversionRules, PGCR = Undefined)
	
	For Each PCR In ObjectPropertyConversionRules Do
		
		If PCR.IsFolder Then //PGCR
			
			For Each Item In HandlerNames.PGCR Do
				
				AddPCRHandlerInterface(ObjectPropertyConversionRules, OCR, PGCR, PCR, Item.Key);
				
			EndDo; 

			SupplementWithPCRHandlerInterfaces(OCR, PCR.GroupRules, PCR);
			
		Else
			
			For Each Item In HandlerNames.PCR Do
				
				AddPCRHandlerInterface(ObjectPropertyConversionRules, OCR, PGCR, PCR, Item.Key);
				
			EndDo; 
			
		EndIf; 
		
	EndDo; 
	
EndProcedure  


Procedure AddHandlerInterface(Table, Rule, HandlerPrefix, HandlerName) 
	
	If IsBlankString(Rule[HandlerName]) Then
		Return;
	EndIf;
	
	FieldName = "HandlerInterface" + HandlerName;
	
	AddMissingColumns(Table.Columns, FieldName);
		
	Rule[FieldName] = GetHandlerInterface(Rule, HandlerPrefix, HandlerName);
	
EndProcedure 

Procedure AddOCRHandlerInterface(Table, Rule, HandlerName) 
	
	If Not Rule["HasHandler" + HandlerName] Then
		Return;
	EndIf; 
	
	FieldName = "HandlerInterface" + HandlerName;
	
	AddMissingColumns(Table.Columns, FieldName);
	
	Rule[FieldName] = GetHandlerInterface(Rule, "OCR", HandlerName);
  
EndProcedure 

Procedure AddPCRHandlerInterface(Table, OCR, PGCR, PCR, HandlerName) 
	
	If Not PCR["HasHandler" + HandlerName] Then
		Return;
	EndIf; 
	
	FieldName = "HandlerInterface" + HandlerName;
	
	AddMissingColumns(Table.Columns, FieldName);
	
	PCR[FieldName] = GetPCRHandlerInterface(OCR, PGCR, PCR, HandlerName);
	
EndProcedure  

Procedure AddConversionHandlerInterface(ConversionStructure, HandlerName)
	
	HandlerAlgorithm = "";
	
	If ConversionStructure.Property(HandlerName, HandlerAlgorithm) And Not IsBlankString(HandlerAlgorithm) Then
		
		FieldName = "HandlerInterface" + HandlerName;
		
		ConversionStructure.Insert(FieldName);
		
		ConversionStructure[FieldName] = GetConversionHandlerInterface(HandlerName); 
		
	EndIf;
	
EndProcedure  


////////////////////////////////////////////////////////////////////////////////
// PROCEDURES FOR WORKING WITH EXCHANGE RULES.

// Searches for the conversion rules by the name or according to the type of the passed
// object.

//
// Parameters:
//  Object   - source object whose conversion rule is searched.
//  RuleName - conversion rule name.
//
// Returns:
//  Rule table row - conversion rule reference.
//
 
Function FindRule(Object, RuleName="") Export

	If Not IsBlankString(RuleName) Then
		
		Rule = Rules[RuleName];
		
	Else
		
		Rule = Managers[TypeOf(Object)];
		If Rule <> Undefined Then
			Rule    = Rule.OCR;
			
			If Rule <> Undefined Then 
				RuleName = Rule.Name;
			EndIf;
			
		EndIf; 
		
	EndIf;
	
	Return Rule; 
	
EndFunction

// Saves the exchange rules in the internal format.
// 
Procedure SaveRulesInInternalFormat() Export

	For Each Rule In ConversionRuleTable Do
		Rule.Exported.Clear();
		Rule.OnlyRefsExported.Clear();
	EndDo;

	RuleStructure = New Structure;
	
	//Saving queries
	QueriesToSave = New Structure;
	For Each StructureItem In Queries Do
		QueriesToSave.Insert(StructureItem.Key, StructureItem.Value.Text);
	EndDo;

	ParametersToSave = New Structure;
	For Each StructureItem In Parameters Do
		ParametersToSave.Insert(StructureItem.Key, Undefined);
	EndDo;

	RuleStructure.Insert("ExportRuleTable",       ExportRuleTable);
	RuleStructure.Insert("ConversionRuleTable",   ConversionRuleTable);
	RuleStructure.Insert("Algorithms",            Algorithms);
	RuleStructure.Insert("Queries",               QueriesToSave);
	RuleStructure.Insert("Conversion",            Conversion);
	RuleStructure.Insert("mXMLRules",             mXMLRules);
	RuleStructure.Insert("ParameterSetupTable",   ParameterSetupTable);
	RuleStructure.Insert("Parameters",            ParametersToSave);
	
	RuleStructure.Insert("TargetPlatformVersion", TargetPlatformVersion);

	
	SavedSettings  = New ValueStorage(RuleStructure);
	
EndProcedure

Function GetPlatformByTargetPlatformVersion(PlatformVersion)
	
	If Find(PlatformVersion, "8.") > 0 Then
		
		Return "V8";
		
	Else
		
		Return "V7";
		
	EndIf;	
	
EndFunction

// Restores the rules from the internal format.
// 
Procedure RestoreRulesFromInternalFormat() Export

	If SavedSettings = Undefined Then
		Return;
	EndIf;
	
	RuleStructure = SavedSettings.Get();

	ExportRuleTable     = RuleStructure.ExportRuleTable;
	ConversionRuleTable = RuleStructure.ConversionRuleTable;
	Algorithms          = RuleStructure.Algorithms;
	QueriesToRestore    = RuleStructure.Queries;
	Conversion          = RuleStructure.Conversion;
	mXMLRules           = RuleStructure.mXMLRules;
	ParameterSetupTable = RuleStructure.ParameterSetupTable;
	Parameters          = RuleStructure.Parameters;

	
	SupplementServiceTablesWithColumns();
	
	RuleStructure.Property("TargetPlatformVersion", TargetPlatformVersion);
	
	TargetPlatform = GetPlatformByTargetPlatformVersion(TargetPlatformVersion);
		
	HasBeforeExportObjectGlobalHandler  = Not IsBlankString(Conversion.BeforeExportObject);
	HasAfterExportObjectGlobalHandler   = Not IsBlankString(Conversion.AfterExportObject);
	HasBeforeImportObjectGlobalHandler  = Not IsBlankString(Conversion.BeforeImportObject);
	HasAfterImportObjectGlobalHandler   = Not IsBlankString(Conversion.AfterImportObject);
	HasBeforeConvertObjectGlobalHandler = Not IsBlankString(Conversion.BeforeObjectConversion);


	// Restoring queries
	Queries.Clear();
	For Each StructureItem In QueriesToRestore Do
		Query = New Query(StructureItem.Value);
		Queries.Insert(StructureItem.Key, Query);
	EndDo;

	InitManagersAndMessages();
	
	Rules.Clear();
	ClearManagerOCR();
	
	If ExchangeMode = "Export" Then
	
		For Each TableRow In ConversionRuleTable Do
			Rules.Insert(TableRow.Name, TableRow);

			If TableRow.Source <> Undefined Then
				
				Try
					If TypeOf(TableRow.Source) = deStringType Then
						Managers[Type(TableRow.Source)].OCR = TableRow;
					Else
						Managers[TableRow.Source].OCR = TableRow;
					EndIf;			
				Except
					WriteErrorInfoToLog(11, ErrorDescription(), String(TableRow.Source));
				EndTry;
				
			EndIf;

		EndDo;
	
	EndIf;	
	
EndProcedure

// Sets parameter values in the Parameters structure according to the ParameterSetupTable table.
// 
Procedure SetParametersFromDialog() Export

	For Each TableRow In ParameterSetupTable Do
		Parameters.Insert(TableRow.Name, TableRow.Value);
	EndDo;

EndProcedure

// Sets the parameter value in the parameter table on the data processor form.
//
Procedure SetParameterValueInTable(ParameterName, ParameterValue) Export
	
	TableRow = ParameterSetupTable.Find(ParameterName, "Name");
	
	If TableRow <> Undefined Then
		
		TableRow.Value = ParameterValue;	
		
	EndIf;
	
EndProcedure

// Initializes parameters with default values from the exchange rules.
//
Procedure InitializeInitialParameterValues() Export
	
	For Each CurParameter In Parameters Do
		
		SetParameterValueInTable(CurParameter.Key, CurParameter.Value);
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// CLEARING RULE PROCESSING.

Procedure ExecuteObjectDeletion(Object, Properties, DeleteDirectly)
	
	If Properties.TypeName = "InformationRegister" Then
			
		Object.Delete();
			
	Else
		
		Try
		
			Predefined = Object.Predefined;
			
		Except
			
			Predefined = False;
			
		EndTry;
		
		If Predefined Then
			
			Return;
			
		EndIf;
		
		If DeleteDirectly Then
			
			Object.Delete();
			
		Else
			
			SetObjectDeletionMark(Object, True, Properties.TypeName);
			
		EndIf;
			
	EndIf;	
	
EndProcedure

// Deletes (or sets the deletion mark) the selection object according to the specified rule.
//
// Parameters:
//  Object       - selection object to be deleted (or whose deletion mark will be set).
//  Rule         - data clearing rule reference.
//  Properties   - metadata object properties of the object to be deleted.
//  IncomingData - arbitrary auxiliary data.
//
 
Procedure SelectionObjectDeletion(Object, Rule, Properties=Undefined, IncomingData=Undefined) Export

	Cancel			    = False;
	DeleteDirectly = Rule.Directly;


	// BeforeSelectionObjectDeletion handler
	If Not IsBlankString(Rule.BeforeDelete) Then
	
		Try
			
			If HandlerDebugModeFlag Then
				
				Execute(GetHandlerCallString(Rule, "BeforeDelete"));
				
			Else
				
				Execute(Rule.BeforeDelete);
				
			EndIf;
			
		Except
			
			WriteDataClearingHandlerErrorInfo(29, ErrorDescription(), Rule.Name, Object, "BeforeSelectionObjectDeletion");
									
		EndTry;
		
		If Cancel Then
		
			Return;
			
		EndIf;
			
	EndIf;	 


	Try
		
		ExecuteObjectDeletion(Object, Properties, DeleteDirectly);
					
	Except
		
		WriteDataClearingHandlerErrorInfo(24, ErrorDescription(), Rule.Name, Object, "");
								
	EndTry;	

EndProcedure

// Clears data by the specified rule.
//
// Parameters:
//  Rule - data clearing rule reference.
// 
Procedure ClearDataByRule(Rule)
	
	// BeforeProcess handle

	Cancel        = False;
	DataSelection = Undefined;

	OutgoingData	= Undefined;


	// BeforeProcessClearingRule handler
	If Not IsBlankString(Rule.BeforeProcess) Then
		
		Try
			
			If HandlerDebugModeFlag Then
				
				Execute(GetHandlerCallString(Rule, "BeforeProcess"));
				
			Else
				
				Execute(Rule.BeforeProcess);
				
			EndIf;
			
		Except
			
			WriteDataClearingHandlerErrorInfo(27, ErrorDescription(), Rule.Name, "", "BeforeProcessClearingRule");
						
		EndTry;
		
		If Cancel Then
		
			Return;
			
		EndIf;
		
	EndIf;
	
	// Standard selection
	
	Try
		Properties	= Managers[Rule.SelectionObject];
	Except
		Properties	= Undefined;
	EndTry;
	
	If Rule.DataSelectionVariant = "StandardSelection" Then
				
		TypeName = Properties.TypeName;
		
		If TypeName = "AccountingRegister" 
			Or TypeName = "Constants" Then
			
			Return;
			
		EndIf;
		
		AllFieldsRequired = Not IsBlankString(Rule.BeforeDelete);
		
		Selection = GetSelectionForDataClearingExport(Properties, TypeName, True, Rule.Directly, AllFieldsRequired);
		
		While Selection.Next() Do
			
			If TypeName =  "InformationRegister" Then
				
				RecordManager = Properties.Manager.CreateRecordManager(); 
				FillPropertyValues(RecordManager, Selection);
									
				SelectionObjectDeletion(RecordManager, Rule, Properties, OutgoingData);
					
			Else
					
				SelectionObjectDeletion(Selection.Ref.GetObject(), Rule, Properties, OutgoingData);
					
			EndIf;
				
		EndDo;
		
	ElsIf Rule.DataSelectionVariant = "ArbitraryAlgorithm" Then
		
		If DataSelection <> Undefined Then
			
			Selection = GetExportWithArbitraryAlgorithmSelection(DataSelection);
			
			If Selection <> Undefined Then
				
				While Selection.Next() Do
										
					If TypeName =  "InformationRegister" Then
				
						RecordManager = Properties.Manager.CreateRecordManager(); 
						FillPropertyValues(RecordManager, Selection);
											
						SelectionObjectDeletion(RecordManager, Rule, Properties, OutgoingData);				
											
					Else
							
						SelectionObjectDeletion(Selection.Ref.GetObject(), Rule, Properties, OutgoingData);
							
					EndIf;					
					
				EndDo;	
				
			Else
				
				For Each Object In DataSelection Do
					
					SelectionObjectDeletion(Object.GetObject(), Rule, Properties, OutgoingData);
					
				EndDo;
				
			EndIf;
			
		EndIf; 
			
	EndIf; 

	
	// AfterProcessClearingRule handler

	If Not IsBlankString(Rule.AfterProcess) Then
		
		Try
			
			If HandlerDebugModeFlag Then
				
				Execute(GetHandlerCallString(Rule, "AfterProcess"));
				
			Else
				
				Execute(Rule.AfterProcess);
				
			EndIf;
			
		Except
			
			WriteDataClearingHandlerErrorInfo(28, ErrorDescription(), Rule.Name, "", "AfterProcessClearingRule");
									
		EndTry;
		
	EndIf;
	
EndProcedure

// Goes over the data clearing rule tree and performs cleaning.
//
// Parameters:
//  Rows - value tree row collection.
//
 
Procedure ProcessClearingRules(Rows)
	
	For Each ClearingRule In Rows Do
		
		If ClearingRule.PrivilegedModeOn = 0 Then
			
			Continue;
			
		EndIf; 

		If ClearingRule.IsFolder Then
			
			ProcessClearingRules(ClearingRule.Rows);
			Continue;
			
		EndIf;
		
		ClearDataByRule(ClearingRule);
		
	EndDo; 
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// PROCEDURES FOR IMPORTING DATA.

// Sets the Load parameter value for the DataExchange object property.
//
// Parameters:
//  Object - object whose property will be set.
//  Value  - Load property value to be set.
//
 
Procedure SetDataExchangeLoad(Object, Value = True) Export
	
	If Not ImportDataInExchangeMode Then
		Return;
	EndIf;
	
	// Objects those take part in the exchange might not have the DataExchange property
	Try
		Object.DataExchange.Load = Value;
	Except
	EndTry;
	
EndProcedure

Function SetNewObjectRef(Object, Manager, SearchProperties)
	
	UI = SearchProperties["{UUID}"];
	
	If UI <> Undefined Then
		
		NewRef = Manager.GetRef(New UUID(UI));
		
		Object.SetNewObjectRef(NewRef);
		
		SearchProperties.Delete("{UUID}");
		
	Else
		
		NewRef = Undefined;
		
	EndIf;
	
	Return NewRef;
	
EndFunction

// Searches for the object by its number in the list of already imported objects.
//
// Parameters:
//  Sn - number in the exchange file of the object to be found.
//
// Returns:
//  Reference to the found object. If object is not found, Undefined is returned.
//
 
Function FindObjectByNumber(Sn, MainObjectSearchMode = False)

	If Sn = 0 Then
		Return Undefined;
	EndIf;
	
	ResultStructure = ImportedObjects[Sn];
	
	If ResultStructure = Undefined Then
		Return Undefined;
	EndIf;
	
	If MainObjectSearchMode And ResultStructure.DummyRef Then
		Return Undefined;
	Else
		Return ResultStructure.ObjectRef;
	EndIf; 

EndFunction // FindObjectByNumber() 

Function FindObjectByGlobalNumber(Sn, MainObjectSearchMode = False)

	ResultStructure = ImportedGlobalObjects[Sn];
	
	If ResultStructure = Undefined Then
		Return Undefined;
	EndIf;
	
	If MainObjectSearchMode And ResultStructure.DummyRef Then
		Return Undefined;
	Else
		Return ResultStructure.ObjectRef;
	EndIf;
	
EndFunction

Procedure WriteObjectToInfobase(Object, Type)
		
	Try
		
		SetDataExchangeLoad(Object);
		Object.Write();
		
	Except
		
		ErrorMessageString = WriteErrorInfoToLog(26, ErrorDescription(), Object, Type);
		
		If Not DebugModeFlag Then
			Raise ErrorMessageString;
		EndIf;
		
	EndTry;
	
EndProcedure

// Creates a new object of the specified type, sets attributes that are specified in the
// SearchProperties structure.
//
// Parameters:
//  Type             - type of the object to be generated.
//  SearchProperties - Structure - contains  object attributes to be set.
//
// Returns:
//  New infobase object.
//

Function CreateNewObject(Type, SearchProperties, Object = Undefined, 
	WriteObjectImmediatelyAfterCreation = True, RegisterRecordSet = Undefined,
	NewRef = Undefined, Sn = 0, GSn = 0, ObjectParameters = Undefined,
	SetAllObjectSearchProperties = True)

	MDProperties = Managers[Type];
	TypeName     = MDProperties.TypeName;
	Manager      = MDProperties.Manager;
	DeletionMark = Undefined;

	If TypeName = "Catalog"
		Or TypeName = "ChartOfCharacteristicTypes" Then
		
		IsFolder = SearchProperties["IsFolder"];
		
		If IsFolder = True Then
			
			Object = Manager.CreateFolder();
						
		Else
			
			Object = Manager.CreateItem();
			
		EndIf;		
				
	ElsIf TypeName = "Document" Then
		
		Object = Manager.CreateDocument();
				
	ElsIf TypeName = "ChartOfAccounts" Then
		
		Object = Manager.CreateAccount();
				
	ElsIf TypeName = "ChartOfCalculationTypes" Then
		
		Object = Manager.CreateCalculationType();
				
	ElsIf TypeName = "InformationRegister" Then
		
		If WriteRegisterRecordsAsRecordSets Then
			
			RegisterRecordSet = Manager.CreateRecordSet();
			Object = RegisterRecordSet.Add();
			
		Else
			
			Object = Manager.CreateRecordManager();
						
		EndIf;
		
		Return Object;
		
	ElsIf TypeName = "ExchangePlan" Then
		
		Object = Manager.CreateNode();
				
	ElsIf TypeName = "Task" Then
		
		Object = Manager.CreateTask();
		
	ElsIf TypeName = "BusinessProcess" Then
		
		Object = Manager.CreateBusinessProcess();	
		
	ElsIf TypeName = "Enum" Then
		
		Object = MDProperties.EmptyRef;	
		Return Object;
		
	ElsIf TypeName = "BusinessProcessRoutePoint" Then
		
		Return Undefined;
				
	EndIf;
	
	NewRef = SetNewObjectRef(Object, Manager, SearchProperties);
	
	If SetAllObjectSearchProperties Then
		SetObjectSearchAttributes(Object, SearchProperties, , False, False);
	EndIf;
	
	// Checks
	If TypeName = "Document"
		Or TypeName = "Task"
		Or TypeName = "BusinessProcess" Then
		
		If Not ValueIsFilled(Object.Date) Then
			
			Object.Date = CurrentSessionDate();
			
		EndIf;
		
	EndIf;
		
	// If Owner is not set, the field must be added to the search fields, and fields
	// without Owner must be set in the SEARCHFIELDS event.

	
	If WriteObjectImmediatelyAfterCreation Then
		
		If Not ImportObjectsByRefWithoutDeletionMark Then
			Object.DeletionMark = True;
		EndIf;
		
		If GSn <> 0
			Or Not OptimizedObjectWriting Then
		
			WriteObjectToInfobase(Object, Type);
			
		Else
			
			// The object is not written immediately. Instead of this, the object will be
			// stored to the stack of objects to be written.
			// Both the new reference and the object are returned, although the object
			// is not written.

			If NewRef = Undefined Then
				
				// Generating the new reference
				NewUUID = New UUID;
				NewRef = Manager.GetRef(NewUUID);
				Object.SetNewObjectRef(NewRef);
				
			EndIf;			
			
			SupplementNotWrittenObjectStack(Sn, GSn, Object, NewRef, Type, ObjectParameters);
			
			Return NewRef;
			
		EndIf;
		
	Else
		
		Return Undefined;
		
	EndIf;
	
	Return Object.Ref;
	
EndFunction

// Reads the node properties object from the file, sets the property value
//
// Parameters:
//  Type        - property value type.
//  ObjectFound - False returned to this parameter means, that the property object is
//                not found in the infobase and a new one has been created.
//
// Returns:
//  Property value.
//
 
Function ReadProperty(Type, OCRName = "")
	
	Value = Undefined;
	PropertyExistence = False;
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
				
		If NodeName = "Value" Then
			
			SearchByProperty  = deAttribute(ExchangeFile, deStringType, "Property");
			Value             = deElementValue(ExchangeFile, Type, SearchByProperty, CutRowsFromRight);
			PropertyExistence = True;
			
		ElsIf NodeName = "Ref" Then
			
			Value             = FindObjectByRef(Type,,,,,,,,,,,, OCRName);
			PropertyExistence = True;
			
		ElsIf NodeName = "Sn" Then
			
			deSkip(ExchangeFile);
			
		ElsIf NodeName = "GSn" Then
			
			ExchangeFile.Read();
			GSn = Number(ExchangeFile.Value);
			If GSn <> 0 Then
				Value  = FindObjectByGlobalNumber(GSn);
				PropertyExistence = True;
			EndIf;
			
			ExchangeFile.Read();
			
		ElsIf (NodeName = "Property" Or NodeName = "ParameterValue") And (ExchangeFile.NodeType = deXMLNodeType_EndElement) Then
			
			If Not PropertyExistence
				And ValueIsFilled(Type) Then
				
				Value = deGetEmptyValue(Type);
				
			EndIf;
			
			Break;
			
		ElsIf NodeName = "Expression" Then
			
			Value = Eval(deElementValue(ExchangeFile, deStringType, , False));
			PropertyExistence = True;
			
		ElsIf NodeName = "Empty" Then
			
			Value = deGetEmptyValue(Type);
			PropertyExistence = True;		
			
		Else
			
			WriteToExecutionLog(9);
			Break;
			
		EndIf;
		
	EndDo;
	
	Return Value;	
	
EndFunction

Function SetObjectSearchAttributes(FoundObject, SearchProperties, SearchPropertiesDontReplace, 
	ShouldCompareWithCurrentAttributes = True, DontReplacePropertiesNotToChange = True)
	
	ObjectAttributeChanged = False;
				
	For Each Property In SearchProperties Do
					
		Name  = Property.Key;
		Value = Property.Value;
		
		If DontReplacePropertiesNotToChange
			And SearchPropertiesDontReplace[Name] <> Undefined Then
			
			Continue;
			
		EndIf;
					
		If Name = "IsFolder" 
			Or Name = "{UUID}" 
			Or Name = "{PredefinedItemName}" Then
						
			Continue;
						
		ElsIf Name = "DeletionMark" Then
						
			If Not ShouldCompareWithCurrentAttributes
				Or FoundObject.DeletionMark <> Value Then
							
				FoundObject.DeletionMark = Value;
				ObjectAttributeChanged = True;
							
			EndIf;
						
		Else
				
			// Setting attributes that are different
			If FoundObject[Name] <> NULL Then
			
				If Not ShouldCompareWithCurrentAttributes
					Or FoundObject[Name] <> Value Then
						
					FoundObject[Name] = Value;
					ObjectAttributeChanged = True;
						
				EndIf;
				
			EndIf;
				
		EndIf;
					
	EndDo;
	
	Return ObjectAttributeChanged;
	
EndFunction

Function FindOrCreateObjectByProperty(PropertyStructure, ObjectType, SearchProperties, SearchPropertiesDontReplace,
	ObjectTypeName, SearchProperty, SearchPropertyValue, ObjectFound, 
	CreateNewItemIfNotFound = True, FoundOrCreatedObject = Undefined, 
	MainObjectSearchMode = False, ObjectPropertyModified = False, 
	NewUUIDRef = Undefined, Sn = 0, GSn = 0, ObjectParameters = Undefined)
	
	IsEnum = PropertyStructure.TypeName = "Enum";
	
	If IsEnum Then
		
		SearchString = "";
		
	Else
		
		SearchString = PropertyStructure.SearchString;	
		
	EndIf;
	
	Object = deFindObjectByProperty(PropertyStructure.Manager, SearchProperty, SearchPropertyValue, 
		FoundOrCreatedObject, , , MainObjectSearchMode, SearchString);
		
	ObjectFound = Not (Object = Undefined
				Or Object.IsEmpty());
		
	If Not ObjectFound
		And CreateNewItemIfNotFound Then
		
		Object = CreateNewObject(ObjectType, SearchProperties, FoundOrCreatedObject, 
			Not MainObjectSearchMode,,NewUUIDRef, Sn, GSn, ObjectParameters);
			
		ObjectPropertyModified = True;
		Return Object;
		
	EndIf;
	
	If IsEnum Then
		Return Object;
	EndIf;			
	
	If MainObjectSearchMode Then
		
		Try
			
			If FoundOrCreatedObject = Undefined Then
				FoundOrCreatedObject = Object.GetObject();
			EndIf;
			
		Except
			Return Object;
		EndTry;
			
		ObjectPropertyModified = SetObjectSearchAttributes(FoundOrCreatedObject, SearchProperties, SearchPropertiesDontReplace);
				
	EndIf;
		
	Return Object;
	
EndFunction

Function GetPropertyType()
	
	PropertyTypeString = deAttribute(ExchangeFile, deStringType, "Type");
	If IsBlankString(PropertyTypeString) Then
		Return Undefined;
	EndIf;
	
	Return Type(PropertyTypeString);
	
EndFunction

Function GetPropertyTypeByAdditionalData(TypeInformation, PropertyName)
	
	PropertyType = GetPropertyType();
				
	If PropertyType = Undefined
		And TypeInformation <> Undefined Then
		
		PropertyType = TypeInformation[PropertyName];
		
	EndIf;
	
	Return PropertyType;
	
EndFunction

Procedure ReadSearchPropertiesFromFile(SearchProperties, SearchPropertiesDontReplace, TypeInformation, 
	SearchByEqualDate = False, ObjectParameters = Undefined)
	
	SearchByEqualDate = False;
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
				
		If NodeName = "Property"
			Or NodeName = "ParameterValue" Then
					
			IsParameter = (NodeName = "ParameterValue");
			
			Name = deAttribute(ExchangeFile, deStringType, "Name");
			
			If Name = "{UUID}" 
				Or Name = "{PredefinedItemName}" Then
				
				PropertyType = deStringType;
				
			Else
			
				PropertyType = GetPropertyTypeByAdditionalData(TypeInformation, Name);
			
			EndIf;
			
			DontReplaceProperty = deAttribute(ExchangeFile, deBooleanType, "DontReplace");
			SearchByEqualDate = SearchByEqualDate 
					Or deAttribute(ExchangeFile, deBooleanType, "SearchByEqualDate");

			OCRName = deAttribute(ExchangeFile, deStringType, "OCRName");
			
			PropertyValue = ReadProperty(PropertyType, OCRName);
			
			If (Name = "IsFolder") And (PropertyValue <> True) Then
				
				PropertyValue = False;
												
			EndIf;
			
			If IsParameter Then
				
				
				AddParameterIfNecessary(ObjectParameters, Name, PropertyValue);
				
			Else
			
				SearchProperties[Name] = PropertyValue;
				
				If DontReplaceProperty Then
					
					SearchPropertiesDontReplace[Name] = True;
					
				EndIf;
				
			EndIf;
			
		ElsIf (NodeName = "Ref") And (ExchangeFile.NodeType = deXMLNodeType_EndElement) Then
			
			Break;
			
		Else
			
			WriteToExecutionLog(9);
			Break;
			
		EndIf;
		
	EndDo;	
	
EndProcedure

Function UnlimitedLengthField(TypeManager, ParameterName)
	
	LongStrings = Undefined;
	If Not TypeManager.Property("LongStrings", LongStrings) Then
		
		LongStrings = New Map;
		For Each Attribute In TypeManager.MDObject.Attributes Do
			
			If Attribute.Type.ContainsType(deStringType) 
				And (Attribute.Type.StringQualifiers.Length = 0) Then
				
				LongStrings.Insert(Attribute.Name, Attribute.Name);	
				
			EndIf;
			
		EndDo;
		
		TypeManager.Insert("LongStrings", LongStrings);
		
	EndIf;
	
	Return (LongStrings[ParameterName] <> Undefined);
		
EndFunction

Function IsUnlimitedLengthParameter(TypeManager, ParameterValue, ParameterName)
	
	Try
			
		If TypeOf(ParameterValue) = deStringType Then
			UnlimitedLengthString = UnlimitedLengthField(TypeManager, ParameterName);
		Else
			UnlimitedLengthString = False;
		EndIf;		
												
	Except
				
		UnlimitedLengthString = False;
				
	EndTry;
	
	Return UnlimitedLengthString;	
	
EndFunction

Function FindItemUsingRequest(PropertyStructure, SearchProperties, ObjectType = Undefined, 
	TypeManager = Undefined, RealPropertyForSearchCount = Undefined)
	
	PropertyCountForSearch = ?(RealPropertyForSearchCount = Undefined, SearchProperties.Count(), RealPropertyForSearchCount);
	
	If PropertyCountForSearch = 0
		And PropertyStructure.TypeName = "Enum" Then
		
		Return PropertyStructure.EmptyRef;
		
	EndIf;	
	
	QueryText = PropertyStructure.SearchString;
	
	If IsBlankString(QueryText) Then
		Return PropertyStructure.EmptyRef;
	EndIf;
	
	SearchQuery       = New Query();
	PropertyUsedInSearchCount = 0;
			
	For Each Property In SearchProperties Do
				
		ParameterName      = Property.Key;
		
		// The following parameters cannot be a search fields
		If ParameterName = "{UUID}"
			Or ParameterName = "{PredefinedItemName}" Then
						
			Continue;
						
		EndIf;
		
		ParameterValue = Property.Value;
		SearchQuery.SetParameter(ParameterName, ParameterValue);
				
		Try
			
			
			UnlimitedLengthString = IsUnlimitedLengthParameter(PropertyStructure, ParameterValue, ParameterName);		
													
		Except
					
			UnlimitedLengthString = False;
					
		EndTry;
		
		PropertyUsedInSearchCount = PropertyUsedInSearchCount + 1;
				
		If UnlimitedLengthString Then
					
			QueryText = QueryText + ?(PropertyUsedInSearchCount > 1, " And ", "") + ParameterName + " LIKE &" + ParameterName;
					
		Else
					
			QueryText = QueryText + ?(PropertyUsedInSearchCount > 1, " And ", "") + ParameterName + " = &" + ParameterName;
					
		EndIf;
								
	EndDo;
	
	If PropertyUsedInSearchCount = 0 Then
		Return Undefined;
	EndIf;
	
	SearchQuery.Text = QueryText;
	Result = SearchQuery.Execute();
			
	If Result.IsEmpty() Then
		
		Return Undefined;
								
	Else
		
		// Returning the first found object
		Selection = Result.Select();
		Selection.Next();
		ObjectRef = Selection.Ref;
				
	EndIf;
	
	Return ObjectRef;
	
EndFunction

Function GetAdditionalSearchBySearchFieldsUsageByObjectType(RefTypeString)
	
	MapValue = mExtendedSearchParameterMap.Get(RefTypeString);
	
	If MapValue <> Undefined Then
		Return MapValue;
	EndIf;
	
	Try
	
		For Each Item In Rules Do
			
			If Item.Value.Target = RefTypeString Then
				
				If Item.Value.SynchronizeByID = True Then
					
					MustContinueSearch = (Item.Value.SearchBySearchFieldsIfNotFoundByID = True);
					mExtendedSearchParameterMap.Insert(RefTypeString, MustContinueSearch);
					
					Return MustContinueSearch;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
		mExtendedSearchParameterMap.Insert(RefTypeString, False);
		Return False;
	
	Except
		
		mExtendedSearchParameterMap.Insert(RefTypeString, False);
		Return False;
	
    EndTry;
	
EndFunction

// Retrieves the object conversion rule (OCR) by the target object type.
// 
// Parameters:
//  RefTypeString - String - object type string, for example, "CatalogRef.ProductsAndServices".ProductsAndServices".
// 
// Returns:
//  MapValue - object conversion rule.
// 
Function GetConversionRuleWithSearchAlgorithmByTargetObjectType(RefTypeString)
	
	MapValue = mConversionRuleMap.Get(RefTypeString);
	
	If MapValue <> Undefined Then
		Return MapValue;
	EndIf;
	
	Try
	
		For Each Item In Rules Do
			
			If Item.Value.Target = RefTypeString Then
				
				If Item.Value.HasSearchFieldSequenceHandler = True Then
					
					Rule = Item.Value;
					
					mConversionRuleMap.Insert(RefTypeString, Rule);
					
					Return Rule;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
		mConversionRuleMap.Insert(RefTypeString, Undefined);
		Return Undefined;
	
	Except
		
		mConversionRuleMap.Insert(RefTypeString, Undefined);
		Return Undefined;
	
	EndTry;
	
EndFunction

Function FindObjectRefBySingleProperty(SearchProperties, PropertyStructure)
	
	For Each Property In SearchProperties Do
					
		ParameterName = Property.Key;
					
		// The following parameters cannot be a search fields
		If ParameterName = "{UUID}"
			Or ParameterName = "{PredefinedItemName}" Then
						
			Continue;
						
		EndIf;
					
		ParameterValue = Property.Value;
		ObjectRef      = deFindObjectByProperty(PropertyStructure.Manager, ParameterName, ParameterValue, , PropertyStructure, SearchProperties);
					
	EndDo;
	
	Return ObjectRef;
	
EndFunction

Function FindDocumentRef(SearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery, SearchByEqualDate)
	
	// Attempting to search for the document by the date and number
	SearchWithQuery = SearchByEqualDate Or (RealPropertyForSearchCount <> 2);
				
	If SearchWithQuery Then
		Return Undefined;
	EndIf;
					
	DocumentNumber = SearchProperties["Number"];
	DocumentDate   = SearchProperties["Date"];
					
	If (DocumentNumber <> Undefined) And (DocumentDate <> Undefined) Then
						
		ObjectRef = PropertyStructure.Manager.FindByNumber(DocumentNumber, DocumentDate);
																		
	Else
						
		// Failed to find the document by the date and number, search with a query is
		// necessary.
		SearchWithQuery = True;
		ObjectRef = Undefined;
						
	EndIf;
	
	Return ObjectRef;
	
EndFunction

Function FindRefToCatalog(SearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery)
	
	Owner       = SearchProperties["Owner"];
	Parent      = SearchProperties["Parent"];
	Code        = SearchProperties["Code"];
	Description = SearchProperties["Description"];
				
	Count       = 0;

				
	If Owner <> Undefined Then	Count = 1 + Count; EndIf;
	If Parent <> Undefined Then	Count = 1 + Count; EndIf;
	If Code <> Undefined Then Count = 1 + Count; EndIf;
	If Description <> Undefined Then	Count = 1 + Count; EndIf;
				
	SearchWithQuery = (Count <> RealPropertyForSearchCount);
				
	If SearchWithQuery Then
		Return Undefined;
	EndIf;
					
	If (Code <> Undefined) And (Description = Undefined) Then
						
		ObjectRef = PropertyStructure.Manager.FindByCode(Code, , Parent, Owner);
																		
	ElsIf (Code = Undefined) And (Description <> Undefined) Then
						
		ObjectRef = PropertyStructure.Manager.FindByDescription(Description, TRUE, Parent, Owner);
											
	Else
						
		SearchWithQuery = True;
		ObjectRef       = Undefined;
						
	EndIf;
															
	Return ObjectRef;
	
EndFunction

Function FindRefToCCT(SearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery)
	
	Parent      = SearchProperties["Parent"];
	Code        = SearchProperties["Code"];
	Description = SearchProperties["Description"];
	Count       = 0;
				
	If Parent      <> Undefined Then	Count = 1 + Count EndIf;
	If Code        <> Undefined Then Count = 1 + Count EndIf;
	If Description <> Undefined Then	Count = 1 + Count EndIf;
				
	SearchWithQuery = (Count <> RealPropertyForSearchCount);
				
	If SearchWithQuery Then
		Return Undefined;
	EndIf;
					
	If     (Code <> Undefined) And (Description = Undefined) Then
						
		ObjectRef = PropertyStructure.Manager.FindByCode(Code, Parent);
												
	ElsIf (Code = Undefined) And (Description <> Undefined) Then
						
		ObjectRef = PropertyStructure.Manager.FindByDescription(Description, TRUE, Parent);
																	
	Else
						
		SearchWithQuery = True;
		ObjectRef = Undefined;
			
	EndIf;
															
	Return ObjectRef;
	
EndFunction

Function FindRefToExchangePlan(SearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery)
	
	Code        = SearchProperties["Code"];
	Description = SearchProperties["Description"];
	Count       = 0;
				
	If Code        <> Undefined Then Count = 1 + Count EndIf;
	If Description <> Undefined Then	Count = 1 + Count EndIf;
				
	SearchWithQuery = (Count <> RealPropertyForSearchCount);
				
	If SearchWithQuery Then
		Return Undefined;
	EndIf;
					
	If     (Code <> Undefined) And (Description = Undefined) Then
						
		ObjectRef = PropertyStructure.Manager.FindByCode(Code);
												
	ElsIf (Code = Undefined) And (Description <> Undefined) Then
						
		ObjectRef = PropertyStructure.Manager.FindByDescription(Description, TRUE);
																	
	Else
						
		SearchWithQuery = True;
		ObjectRef = Undefined;
						
	EndIf;
															
	Return ObjectRef;
	
EndFunction

Function FindTaskRef(SearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery)
	
	Code        = SearchProperties["Number"];
	Description = SearchProperties["Description"];
	Count       = 0;
				
	If Code        <> Undefined Then Count = 1 + Count EndIf;
	If Description <> Undefined Then	Count = 1 + Count EndIf;
				
	SearchWithQuery = (Count <> RealPropertyForSearchCount);
				
	If SearchWithQuery Then
		Return Undefined;
	EndIf;
	
					
	If     (Code <> Undefined) And (Description = Undefined) Then
						
		ObjectRef = PropertyStructure.Manager.FindByNumber(Code);
												
	ElsIf (Code = Undefined) And (Description <> Undefined) Then
						
		ObjectRef = PropertyStructure.Manager.FindByDescription(Description, TRUE);
																	
	Else
						
		SearchWithQuery = True;
		ObjectRef = Undefined;
						
	EndIf;
															
	Return ObjectRef;
	
EndFunction

Function FindRefToBusinessProcess(SearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery)
	
	Code          = SearchProperties["Number"];
	Count         = 0;
				
	If Code <> Undefined Then Count = 1 + Count EndIf;
								
	SearchWithQuery = (Count <> RealPropertyForSearchCount);
				
	If SearchWithQuery Then
		Return Undefined;
	EndIf;
					
	If  (Code <> Undefined) Then
						
		ObjectRef = PropertyStructure.Manager.FindByNumber(Code);
												
	Else
						
		SearchWithQuery = True;
		ObjectRef = Undefined;
						
	EndIf;
															
	Return ObjectRef;
	
EndFunction

Procedure AddRefToImportedObjectList(RefGSn, RefSn, ObjectRef, DummyRef = False)
	
	// Remembering the object reference
	If Not RememberImportedObjects 
		Or ObjectRef = Undefined Then
		
		Return;
		
	EndIf;
	
	RecordStructure = New Structure("ObjectRef, DummyRef", ObjectRef, DummyRef);
	
	// Remembering the object reference
	If RefGSn <> 0 Then
		
		ImportedGlobalObjects[RefGSn] = RecordStructure;
		
	ElsIf RefSn <> 0 Then
		
		ImportedObjects[RefSn] = RecordStructure;
						
	EndIf;	
	
EndProcedure

Function FindItemBySearchProperties(ObjectType, ObjectTypeName, SearchProperties, 
	PropertyStructure, SearchPropertyNameString, SearchByEqualDate)
	
	// Searching by predefined item name or by unique reference link is not required.
	// Searching by properties that are in the property name string. If this parameter
	// is empty, searching by all available search properties.

		
	SearchWithQuery = False;	
	
	If IsBlankString(SearchPropertyNameString) Then
		
		TemporarySearchProperties = SearchProperties;
		
	Else
		
		ResultingStringForParsing = StrReplace(SearchPropertyNameString, " ", "");
		StringLength = StrLen(ResultingStringForParsing);
		If Mid(ResultingStringForParsing, StringLength, 1) <> "," Then
			
			ResultingStringForParsing = ResultingStringForParsing + ",";
			
		EndIf;
		
		TemporarySearchProperties = New Map;
		For Each PropertyItem In SearchProperties Do
			
			ParameterName = PropertyItem.Key;
			If Find(ResultingStringForParsing, ParameterName + ",") > 0 Then
				
				TemporarySearchProperties.Insert(ParameterName, PropertyItem.Value); 	
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	UUIDProperty = TemporarySearchProperties["{UUID}"];
	PredefinedNameProperty = TemporarySearchProperties["{PredefinedItemName}"];
	
	RealPropertyForSearchCount = TemporarySearchProperties.Count();
	RealPropertyForSearchCount = RealPropertyForSearchCount - ?(UUIDProperty <> Undefined, 1, 0);
	RealPropertyForSearchCount = RealPropertyForSearchCount - ?(PredefinedNameProperty <> Undefined, 1, 0);
	
	
	If RealPropertyForSearchCount = 1 Then
				
		ObjectRef = FindObjectRefBySingleProperty(TemporarySearchProperties, PropertyStructure);
																						
	ElsIf ObjectTypeName = "Document" Then
				
		ObjectRef = FindDocumentRef(TemporarySearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery, SearchByEqualDate);
											
	ElsIf ObjectTypeName = "Catalog" Then
				
		ObjectRef = FindRefToCatalog(TemporarySearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery);
								
	ElsIf ObjectTypeName = "ChartOfCharacteristicTypes" Then
				
		ObjectRef = FindRefToCCT(TemporarySearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery);
							
	ElsIf ObjectTypeName = "ExchangePlan" Then
				
		ObjectRef = FindRefToExchangePlan(TemporarySearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery);
							
	ElsIf ObjectTypeName = "Task" Then
				
		ObjectRef = FindTaskRef(TemporarySearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery);
												
	ElsIf ObjectTypeName = "BusinessProcess" Then
				
		ObjectRef = FindRefToBusinessProcess(TemporarySearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery);
									
	Else
				
		SearchWithQuery = True;
				
	EndIf;
		
	If SearchWithQuery Then
			
		ObjectRef = FindItemUsingRequest(PropertyStructure, TemporarySearchProperties, ObjectType, , RealPropertyForSearchCount);
				
	EndIf;
	
	Return ObjectRef;
	
EndFunction

Procedure ProcessObjectSearchPropertySetting(SetAllObjectSearchProperties, ObjectType, SearchProperties, 
	SearchPropertiesDontReplace, ObjectRef, CreatedObject, WriteNewObjectToInfobase = True, ObjectAttributeChanged = False)
	
	If SetAllObjectSearchProperties <> True Then
		Return;
	EndIf;
	
	Try
		
		If CreatedObject = Undefined Then
			CreatedObject = ObjectRef.GetObject();
		EndIf;
		
	Except
		Return;
	EndTry;
		
	ObjectAttributeChanged = SetObjectSearchAttributes(CreatedObject, SearchProperties, SearchPropertiesDontReplace);
			
	// Rewriting the object if changes were made
	If ObjectAttributeChanged
		And WriteNewObjectToInfobase Then
		
		WriteObjectToInfobase(CreatedObject, ObjectType);
				
	EndIf;	
	
EndProcedure

Function ProcessObjectSearchByStructure(ObjectNumber, ObjectType, CreatedObject, 
	MainObjectSearchMode, ObjectPropertyModified, ObjectFound, 
	IsGlobalNumber, ObjectParameters = Undefined)
	
	DataStructure = mNotWrittenObjectGlobalStack[ObjectNumber];
		
	If DataStructure <> Undefined Then
				
		ObjectPropertyModified = True;
		CreatedObject = DataStructure.Object;
		
		If DataStructure.KnownRef = Undefined Then
			
			SetObjectRef(DataStructure);
								
		EndIf;
			
		ObjectRef = DataStructure.KnownRef;
		ObjectParameters = DataStructure.ObjectParameters;
		
		ObjectFound = False;
							
	Else
		
		CreatedObject = Undefined;
		
		If IsGlobalNumber Then
			ObjectRef = FindObjectByGlobalNumber(ObjectNumber, MainObjectSearchMode);
		Else
			ObjectRef = FindObjectByNumber(ObjectNumber, MainObjectSearchMode);
		EndIf;
		
	EndIf;			
	
	
	If ObjectRef <> Undefined Then
		
		If MainObjectSearchMode Then
			
			SearchProperties = "";
			SearchPropertiesDontReplace = "";
			ReadSearchPropertyInfo(ObjectType, SearchProperties, SearchPropertiesDontReplace, , ObjectParameters);
			
			// Verifying search fields
			If CreatedObject = Undefined Then
				
				CreatedObject = ObjectRef.GetObject();
				
			EndIf;
			
			ObjectPropertyModified = SetObjectSearchAttributes(CreatedObject, SearchProperties, SearchPropertiesDontReplace);
			
		Else
			
			deSkip(ExchangeFile);			
			
		EndIf;		
		
		Return ObjectRef;
		
	EndIf;	
	
	Return Undefined;
	
EndFunction

Procedure ReadSearchPropertyInfo(ObjectType, SearchProperties, SearchPropertiesDontReplace, 
	SearchByEqualDate = False, ObjectParameters = Undefined)
	
	If SearchProperties = "" Then
		SearchProperties = New Map;		
	EndIf;
	
	If SearchPropertiesDontReplace = "" Then
		SearchPropertiesDontReplace = New Map;		
	EndIf;	
	
	TypeInformation = mDataTypeMapForImport[ObjectType];
	ReadSearchPropertiesFromFile(SearchProperties, SearchPropertiesDontReplace, TypeInformation, SearchByEqualDate, ObjectParameters);	
	
EndProcedure

// Searches for the infobase object. If it is not found, creates a new one.
//
// Parameters:
//  ObjectType       - type of the object to be found.
//  SearchProperties - structure with properties to be used for object searching.
//  ObjectFound      - False if object is not found and a new one is created.
//
// Returns:
//  New or found infobase object.
//  
Function FindObjectByRef(ObjectType, 
							SearchProperties = "", 
							SearchPropertiesDontReplace = "", 
							ObjectFound = True, 
							CreatedObject = Undefined, 
							DontCreateObjectIfNotFound = Undefined,
							MainObjectSearchMode = False, 
							ObjectPropertyModified = False,
							GlobalRefSn = 0,
							RefSn = 0,
							KnownUUIDRef = Undefined,
							ObjectParameters = Undefined,
							OCRName = "")

							
	SearchByEqualDate = False;
	ObjectRef = Undefined;
	PropertyStructure = Undefined;
	ObjectTypeName = Undefined;
	IsDocumentObject = False;
	DummyObjectRef = False;
	OCR = Undefined;
	SearchAlgorithm = "";
							
	If RememberImportedObjects Then
		
		// Searching by the serial number
		GlobalRefSn = deAttribute(ExchangeFile, deNumberType, "GSn");
		
		If GlobalRefSn <> 0 Then
			
			ObjectRef = ProcessObjectSearchByStructure(GlobalRefSn, ObjectType, CreatedObject, 
				MainObjectSearchMode, ObjectPropertyModified, ObjectFound, True, ObjectParameters);
			
			If ObjectRef <> Undefined Then
				Return ObjectRef;
			EndIf;				
			
		EndIf;
		
		// Searching by the serial number
		RefSn = deAttribute(ExchangeFile, deNumberType, "Sn");
		
		If RefSn <> 0 Then
		
			ObjectRef = ProcessObjectSearchByStructure(RefSn, ObjectType, CreatedObject, 
				MainObjectSearchMode, ObjectPropertyModified, ObjectFound, False, ObjectParameters);
				
			If ObjectRef <> Undefined Then
				Return ObjectRef;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	DontCreateObjectIfNotFound = deAttribute(ExchangeFile, deBooleanType, "DontCreateIfNotFound");
	OnExchangeObjectByRefSetGIUDOnly = Not MainObjectSearchMode 
		And deAttribute(ExchangeFile, deBooleanType, "OnExchangeObjectByRefSetGIUDOnly");
	
	// Creating object search property
	ReadSearchPropertyInfo(ObjectType, SearchProperties, SearchPropertiesDontReplace, SearchByEqualDate, ObjectParameters);
		
	CreatedObject = Undefined;
	
	If Not ObjectFound Then
		
		ObjectRef = CreateNewObject(ObjectType, SearchProperties, CreatedObject, , , , RefSn, GlobalRefSn);
		AddRefToImportedObjectList(GlobalRefSn, RefSn, ObjectRef);
		Return ObjectRef;
		
	EndIf;	
		
	PropertyStructure = Managers[ObjectType];
	ObjectTypeName    = PropertyStructure.TypeName;
		
	UUIDProperty = SearchProperties["{UUID}"];
	PredefinedNameProperty = SearchProperties["{PredefinedItemName}"];
	
	OnExchangeObjectByRefSetGIUDOnly = OnExchangeObjectByRefSetGIUDOnly
		And UUIDProperty <> Undefined;			
		
	// Searching by name if the item is predefined
	If PredefinedNameProperty <> Undefined Then
		
		CreateNewObjectAutomatically = Not DontCreateObjectIfNotFound
			And Not OnExchangeObjectByRefSetGIUDOnly;
		
		ObjectRef = FindOrCreateObjectByProperty(PropertyStructure, ObjectType, SearchProperties, SearchPropertiesDontReplace,
			ObjectTypeName, "{PredefinedItemName}", PredefinedNameProperty, ObjectFound, 
			CreateNewObjectAutomatically, CreatedObject, MainObjectSearchMode, ObjectPropertyModified, , 
			RefSn, GlobalRefSn, ObjectParameters);
									
	ElsIf (UUIDProperty <> Undefined) Then
			
		// Creating the new item by the unique ID is not always necessary. Perhaps, the
		// search must be continued.
		MustContinueSearchIfItemNotFoundByGUID = GetAdditionalSearchBySearchFieldsUsageByObjectType(PropertyStructure.RefTypeString);
		
		CreateNewObjectAutomatically = (Not DontCreateObjectIfNotFound
			And Not MustContinueSearchIfItemNotFoundByGUID)
			And Not OnExchangeObjectByRefSetGIUDOnly;		
			
		ObjectRef = FindOrCreateObjectByProperty(PropertyStructure, ObjectType, SearchProperties, SearchPropertiesDontReplace,
			ObjectTypeName, "{UUID}", UUIDProperty, ObjectFound, 
			CreateNewObjectAutomatically, CreatedObject, 
			MainObjectSearchMode, ObjectPropertyModified, KnownUUIDRef, 
			RefSn, GlobalRefSn, ObjectParameters);
			
		If Not MustContinueSearchIfItemNotFoundByGUID Then

			If Not ValueIsFilled(ObjectRef)
				And OnExchangeObjectByRefSetGIUDOnly Then
				
				ObjectRef = PropertyStructure.Manager.GetRef(New UUID(UUIDProperty));
				ObjectFound = False;
				DummyObjectRef = True;
			
			EndIf;
			
			If ObjectRef <> Undefined 
				And ObjectRef.IsEmpty() Then
						
				ObjectRef = Undefined;
						
			EndIf;			
			
			If ObjectRef <> Undefined
				Or CreatedObject <> Undefined Then

				AddRefToImportedObjectList(GlobalRefSn, RefSn, ObjectRef, DummyObjectRef);
				
			EndIf;
						
			Return ObjectRef;	
			
		EndIf;	
							
	EndIf;
		
	If ObjectRef <> Undefined 
		And ObjectRef.IsEmpty() Then
				
		ObjectRef = Undefined;
				
	EndIf;
		
	// ObjectRef is not found yet
	If ObjectRef <> Undefined
		Or CreatedObject <> Undefined Then
		
		AddRefToImportedObjectList(GlobalRefSn, RefSn, ObjectRef);
		Return ObjectRef;
		
	EndIf;
			
	SearchVariantNumber = 1;
	SearchPropertyNameString = "";
	PreviousSearchString = Undefined;
	StopSearch = False;
	SetAllObjectSearchProperties = True;
	
	If Not IsBlankString(OCRName) Then
		
		OCR = Rules[OCRName];
		
	EndIf;
	
	If OCR = Undefined Then
		
		OCR = GetConversionRuleWithSearchAlgorithmByTargetObjectType(PropertyStructure.RefTypeString);
		
	EndIf;
	
	If OCR <> Undefined Then
		
		SearchAlgorithm = OCR.SearchFieldSequence;
		
	EndIf;
	
	HasSearchAlgorithm = Not IsBlankString(SearchAlgorithm);
	
	While SearchVariantNumber <= 10
		And HasSearchAlgorithm Do
		
		Try
			
			If HandlerDebugModeFlag Then
				
				Execute(GetHandlerCallString(OCR, "SearchFieldSequence"));
					
			Else
				
				Execute(SearchAlgorithm);
			
			EndIf;
			
		Except
			
			WriteErrorInfoOCRHandlerImport(73, ErrorDescription(), "", "",
				ObjectType, Undefined, NStr("en = 'Search field sequence'"));
			
		EndTry;
		
		DontSearch = StopSearch = True 
			Or SearchPropertyNameString = PreviousSearchString
			Or ValueIsFilled(ObjectRef);
		
		If Not DontSearch Then
		
			// The search
			ObjectRef = FindItemBySearchProperties(ObjectType, ObjectTypeName, SearchProperties, PropertyStructure, 
				SearchPropertyNameString, SearchByEqualDate);
				
			DontSearch = ValueIsFilled(ObjectRef);
			
		EndIf;
			
		If DontSearch Then
			
			If MainObjectSearchMode Then
			
				ProcessObjectSearchPropertySetting(SetAllObjectSearchProperties, ObjectType, SearchProperties, 
					SearchPropertiesDontReplace, ObjectRef, CreatedObject, Not MainObjectSearchMode, ObjectPropertyModified);	
					
			EndIf;
						
			Break;
			
		EndIf;	
		
		SearchVariantNumber = SearchVariantNumber + 1;
		PreviousSearchString = SearchPropertyNameString;
		
	EndDo;
	
	If Not HasSearchAlgorithm Then
		
		// The search with no search algorithm
		ObjectRef = FindItemBySearchProperties(ObjectType, ObjectTypeName, SearchProperties, PropertyStructure, 
					SearchPropertyNameString, SearchByEqualDate);
		//
		ObjectFound = ValueIsFilled(ObjectRef);
		
	EndIf;
					
	If MainObjectSearchMode
		And ValueIsFilled(ObjectRef)
		And (ObjectTypeName = "Document" 
		Or ObjectTypeName = "Task"
		Or ObjectTypeName = "BusinessProcess") Then
		
		// Setting the date if it is in the document - search fields
		EmptyDate = Not ValueIsFilled(SearchProperties["Date"]);
		CanReplace = (Not EmptyDate) 
			And (SearchPropertiesDontReplace["Date"] = Undefined);
			
		If CanReplace Then
			
			If CreatedObject = Undefined Then
				CreatedObject = ObjectRef.GetObject();
			EndIf;
			
			CreatedObject.Date = SearchProperties["Date"];
				
		EndIf;
		
	EndIf;	
	
	// Creating a new object is not always necessary
	If Not ValueIsFilled(ObjectRef)
		And CreatedObject = Undefined Then 
		
		If OnExchangeObjectByRefSetGIUDOnly Then
			
			ObjectRef = PropertyStructure.Manager.GetRef(New UUID(UUIDProperty));	
			DummyObjectRef = True;
			
		ElsIf Not DontCreateObjectIfNotFound Then
		
			ObjectRef = CreateNewObject(ObjectType, SearchProperties, CreatedObject, Not MainObjectSearchMode, , KnownUUIDRef, RefSn, 
				GlobalRefSn, ,SetAllObjectSearchProperties);
				
			ObjectPropertyModified = True;
				
		EndIf;
			
		ObjectFound = False;
					
	EndIf;
	
	If ObjectRef <> Undefined
		And ObjectRef.IsEmpty() Then
		
		ObjectRef = Undefined;	
		
	EndIf;
	
	AddRefToImportedObjectList(GlobalRefSn, RefSn, ObjectRef, DummyObjectRef);
		
	Return ObjectRef;
	
EndFunction

// Sets object (record) properties. 
//
// Parameters:
//  Record  - object whose properties are set, for example, a tabular section row or a
//            record set.
//

Procedure SetRecordProperties(Object, Record, TypeInformation, 
	ObjectParameters, BranchName, RecordNumber,
	SearchDataInTS = Undefined, TSCopyForSearch = Undefined)
	
	MustSearchInTS = (SearchDataInTS <> Undefined)
								And (TSCopyForSearch <> Undefined)
								And TSCopyForSearch.Count() <> 0;
								
	If MustSearchInTS Then
									
		PropertyReadingStructure = New Structure();
		ExtDimensionReadingStructure = New Structure();
		
	EndIf;
		
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
				
		If NodeName = "Property"
			Or NodeName = "ParameterValue" Then
						
			IsParameter = (NodeName = "ParameterValue");
			
			Name    = deAttribute(ExchangeFile, deStringType, "Name");
			OCRName = deAttribute(ExchangeFile, deStringType, "OCRName");
			
			If Name = "RecordType" And Find(Metadata.FindByType(TypeOf(Record)).FullName(), "AccumulationRegister") Then
				
				PropertyType = deAccumulationRecordTypeType;
				
			Else
				
				PropertyType = GetPropertyTypeByAdditionalData(TypeInformation, Name);
				
			EndIf;
			
			PropertyValue = ReadProperty(PropertyType, OCRName);
			
			If IsParameter Then
				AddComplexParameterIfNecessary(ObjectParameters, BranchName, RecordNumber, Name, PropertyValue);			
			ElsIf MustSearchInTS Then 
				PropertyReadingStructure.Insert(Name, PropertyValue);	
			Else
				
				Try
					
					Record[Name] = PropertyValue;
					
				Except
					
					LR = GetLogRecordStructure(26, ErrorDescription());
					LR.OCRName         = OCRName;
					LR.Object          = Object;
					LR.ObjectType      = TypeOf(Object);
					LR.Property        = String(Record) + "." + Name;
					LR.Value           = PropertyValue;
					LR.ValueType       = TypeOf(PropertyValue);
					ErrorMessageString = WriteToExecutionLog(26, LR, True);

					
					If Not DebugModeFlag Then
						Raise ErrorMessageString;
					EndIf;
				EndTry;
				
			EndIf;
			
		ElsIf NodeName = "ExtDimensionsDr" Or NodeName = "ExtDimensionsCr" Then
			
			// The search by extra dimensions is not implemented
			
			Key = Undefined;
			Value = Undefined;
			
			While ExchangeFile.Read() Do
				
				NodeName = ExchangeFile.LocalName;
								
				If NodeName = "Property" Then
					
					Name    = deAttribute(ExchangeFile, deStringType, "Name");
					OCRName = deAttribute(ExchangeFile, deStringType, "OCRName");
					PropertyType = GetPropertyTypeByAdditionalData(TypeInformation, Name);
										
					If Name = "Key" Then
						
						Key = ReadProperty(PropertyType);
						
					ElsIf Name = "Value" Then
						
						Value = ReadProperty(PropertyType, OCRName);
						
					EndIf;
					
				ElsIf (NodeName = "ExtDimensionsDr" Or NodeName = "ExtDimensionsCr") And (ExchangeFile.NodeType = deXMLNodeType_EndElement) Then
					
					Break;
					
				Else
					
					WriteToExecutionLog(9);
					Break;
					
				EndIf;
				
			EndDo;
			
			If Key <> Undefined 
				And Value <> Undefined Then
				
				If Not MustSearchInTS Then
				
					Record[NodeName][Key] = Value;
					
				Else
					
					RecordMapping = Undefined;
					If Not ExtDimensionReadingStructure.Property(NodeName, RecordMapping) Then
						RecordMapping = New Map;
						ExtDimensionReadingStructure.Insert(NodeName, RecordMapping);
					EndIf;
					
					RecordMapping.Insert(Key, Value);
					
				EndIf;
				
			EndIf;
				
		ElsIf (NodeName = "Write") And (ExchangeFile.NodeType = deXMLNodeType_EndElement) Then
			
			Break;
			
		Else
			
			WriteToExecutionLog(9);
			Break;
			
		EndIf;
		
	EndDo;
	
	If MustSearchInTS Then
		
		TheStructureOfTheSearch = New Structure();
		
		For Each SearchItem In  SearchDataInTS.TSSearchFields Do
			
			ElementValue = Undefined;
			PropertyReadingStructure.Property(SearchItem, ElementValue);
			
			TheStructureOfTheSearch.Insert(SearchItem, ElementValue);		
			
		EndDo;		
		
		SearchResultArray = TSCopyForSearch.FindRows(TheStructureOfTheSearch);
		
		RecordFound = SearchResultArray.Count() > 0;
		If RecordFound Then
			FillPropertyValues(Record, SearchResultArray[0]);
		EndIf;
		
		// Filling with properties and extra dimension value
		For Each Item In PropertyReadingStructure Do
			
			Record[Item.Key] = Item.Value;
			
		EndDo;
		
		For Each ItemName In ExtDimensionReadingStructure Do
			
			For Each ItemKey In ItemName.Value Do
			
				Record[ItemName.Key][ItemKey.Key] = ItemKey.Value;
				
			EndDo;
			
		EndDo;			
		
	EndIf;
	
EndProcedure

// Imports the object tabular section.
//
// Parameters:
//  Object - object whose tabular section is imported.
//  Name   - tabular section name.
//  Clear  - pass True to clear the target tabular section before import.
//
 
Procedure ImportTabularSection(Object, Name, Clear, DocumentTypeCommonInformation, MustWriteObject, 
	ObjectParameters, Rule)

	TabularSectionName = Name + "TabularSection";
	If DocumentTypeCommonInformation <> Undefined Then
		TypeInformation = DocumentTypeCommonInformation[TabularSectionName];
	Else
	    TypeInformation = Undefined;
	EndIf;
			
	SearchDataInTS = Undefined;
	If Rule <> Undefined Then
		SearchDataInTS = Rule.SearchInTabularSections.Find("TabularSection." + Name, "ItemName");
	EndIf;
	
	TSCopyForSearch = Undefined;
	
	TS = Object[Name];

	If Clear
		And TS.Count() <> 0 Then
		
		MustWriteObject = True;
		
		Try
			
			If SearchDataInTS <> Undefined Then 
				TSCopyForSearch = TS.Unload();
			EndIf;
			
			TS.Clear();
			
		Except
			
		EndTry;
		
	ElsIf SearchDataInTS <> Undefined Then
		
		TSCopyForSearch = TS.Unload();	
		
	EndIf;
	
	RecordNumber = 0;
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
				
		If      NodeName = "Write" Then
			Try
				
				MustWriteObject = True;
				Write = TS.Add();
				
			Except
				Write = Undefined;
			EndTry;
			
			If Write = Undefined Then
				deSkip(ExchangeFile);
			Else
				SetRecordProperties(Object, Write, TypeInformation, ObjectParameters, TabularSectionName, RecordNumber, SearchDataInTS, TSCopyForSearch);
			EndIf;
			
			RecordNumber = RecordNumber + 1;
			
		ElsIf (NodeName = "TabularSection") And (ExchangeFile.NodeType = deXMLNodeType_EndElement) Then
			
			Break;
			
		Else
			
			WriteToExecutionLog(9);
			Break;
			
		EndIf;
		
	EndDo;
	
EndProcedure 

// Imports object records.
//
// Parameters:
//  Object - object whose records are imported.
//  Name   - register name.
//  Clear  - pass True to clear the target records before import.
//
 
Procedure ImportRegisterRecords(Object, Name, Clear, DocumentTypeCommonInformation, MustWriteObject, 
	ObjectParameters, Rule)
	
	RegisterRecordName = Name + "RecordSet";
	If DocumentTypeCommonInformation <> Undefined Then
		TypeInformation = DocumentTypeCommonInformation[RegisterRecordName];
	Else
	    TypeInformation = Undefined;
	EndIf;
	
	SearchDataInTS = Undefined;
	If Rule <> Undefined Then
		SearchDataInTS = Rule.SearchInTabularSections.Find("RecordSet." + Name, "ItemName");
	EndIf;
	
	TSCopyForSearch = Undefined;
	
	RegisterRecords = Object.RegisterRecords[Name];
	
	If RegisterRecords.Count()=0 Then
		RegisterRecords.Read();
	EndIf;
	
	If Clear
		And RegisterRecords.Count() <> 0 Then
		
		MustWriteObject = True;
		
		If SearchDataInTS <> Undefined Then 
			TSCopyForSearch = RegisterRecords.Unload();
		EndIf;
		
        RegisterRecords.Clear();
		
	ElsIf SearchDataInTS <> Undefined Then
		
		TSCopyForSearch = RegisterRecords.Unload();	
		
	EndIf;
	
	RecordNumber = 0;
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
			
		If      NodeName = "Write" Then
			
			Write = RegisterRecords.Add();
			MustWriteObject = True;
			SetRecordProperties(Object, Write, TypeInformation, ObjectParameters, RegisterRecordName, RecordNumber, SearchDataInTS, TSCopyForSearch);
			
			RecordNumber = RecordNumber + 1;
			
		ElsIf (NodeName = "RecordSet") And (ExchangeFile.NodeType = deXMLNodeType_EndElement) Then
			
			Break;
			
		Else
			
			WriteToExecutionLog(9);
			Break;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Imports the object of the TypeDescription type from the specified source XML node.
//
// Parameters:
//  Source - source XML node.
// 
Function ImportObjectTypes(Source)

	// DateQualifiers

	DateContent =  deAttribute(Source, deStringType,  "DateContent");

	
	// StringQualifiers

	Length        =  deAttribute(Source, deNumberType, "Length");
	AllowedLength =  deAttribute(Source, deStringType, "AllowedLength");

	
	// NumberQualifiers

	DigitCapacity  = deAttribute(Source, deNumberType, "DigitCapacity");
	FractionDigits = deAttribute(Source, deNumberType, "FractionDigits");
	AllowedFlag    = deAttribute(Source, deStringType, "AllowedSign");


	// Reading the array of types
	
	TypeArray = New Array;
	
	While Source.Read() Do
		NodeName = Source.LocalName;
		
		If      NodeName = "Type" Then
			TypeArray.Add(Type(deElementValue(Source, deStringType)));
		ElsIf (NodeName = "Types") And ( Source.NodeType = deXMLNodeType_EndElement) Then
			Break;
		Else
			WriteToExecutionLog(9);
			Break;
		EndIf;
		
	EndDo;


	
	If TypeArray.Count() > 0 Then
		
		// DateQualifiers
		
		If DateContent = "Date" Then
			DateQualifiers = New DateQualifiers(DateFractions.Date);
		ElsIf DateContent = "DateTime" Then
			DateQualifiers = New DateQualifiers(DateFractions.DateTime);
		ElsIf DateContent = "Time" Then
			DateQualifiers = New DateQualifiers(DateFractions.Time);
		Else
			DateQualifiers = New DateQualifiers(DateFractions.DateTime);
		EndIf;
 


		// NumberQualifiers
		
		If DigitCapacity > 0 Then
			If AllowedFlag = "Nonnegative" Then
				Mark = AllowedSign.Nonnegative;
			Else
				Mark = AllowedSign.Any;
			EndIf; 
			NumberQualifiers  = New NumberQualifiers(DigitCapacity, FractionDigits, Mark);
		Else
			NumberQualifiers  = New NumberQualifiers();
		EndIf; 


		// StringQualifiers

		If Length > 0 Then
			If AllowedLength = "Fixed" Then
				AllowedLength = AllowedLength.Fixed;
			Else
				AllowedLength = AllowedLength.Variable;
			EndIf;
			StringQualifiers = New StringQualifiers(Length, AllowedLength);
		Else
			StringQualifiers = New StringQualifiers();
		EndIf; 
        
		Return New TypeDescription(TypeArray, NumberQualifiers, StringQualifiers, DateQualifiers);
	EndIf;

	Return Undefined;
	
EndFunction // ImportObjectTypes()

Procedure SetObjectDeletionMark(Object, DeletionMark, ObjectTypeName)
	
	If (DeletionMark = Undefined)
		And (Object.DeletionMark <> True) Then
		
		Return;
		
	EndIf;
	
	MarkToSet = ?(DeletionMark <> Undefined, DeletionMark, False);
	
	SetDataExchangeLoad(Object);
		
	// For hierarchical object the deletion mark is set only for the current object.
	If ObjectTypeName = "Catalog"
		Or ObjectTypeName = "ChartOfCharacteristicTypes"
		Or ObjectTypeName = "ChartOfAccounts" Then
			
		Object.SetDeletionMark(MarkToSet, False);
			
	Else	
		
		Object.SetDeletionMark(MarkToSet);
		
	EndIf;
	
EndProcedure

Procedure WriteDocumentInSafeMode(Document, ObjectType)
	
	If Document.Posted Then
						
		Document.Posted = False;
			
	EndIf;		
								
	WriteObjectToInfobase(Document, ObjectType);
	
EndProcedure

Function GetObjectByRefAndAdditionalInformation(CreatedObject, Ref)
	
	// Getting the found object
	If CreatedObject <> Undefined Then
		Object = CreatedObject;
	Else
		If Ref.IsEmpty() Then
			Object = Undefined;
		Else
			Object = Ref.GetObject();
		EndIf;		
	EndIf;
	
	Return Object;
	
EndFunction

Procedure ObjectImportComments(Sn, RuleName, Source, ObjectType, GSn = 0)
	
	If CommentObjectProcessingFlag Then
		
		If Sn <> 0 Then
			MessageString = SubstituteParametersInString(NStr("en = 'Importing object #%1'"), Sn);
		Else
			MessageString = SubstituteParametersInString(NStr("en = 'Importing object #%1'"), GSn);
		EndIf;
		
		LR = GetLogRecordStructure();
		
		If Not IsBlankString(RuleName) Then
			
			LR.OCRName = RuleName;
			
		EndIf;
		
		If Not IsBlankString(Source) Then
			
			LR.Source = Source;
			
		EndIf;
		
		LR.ObjectType = ObjectType;
		WriteToExecutionLog(MessageString, LR, False);
		
	EndIf;	
	
EndProcedure

Procedure AddParameterIfNecessary(DataParameters, ParameterName, ParameterValue)
	
	If DataParameters = Undefined Then
		DataParameters = New Map;
	EndIf;
	
	DataParameters.Insert(ParameterName, ParameterValue);
	
EndProcedure

Procedure AddComplexParameterIfNecessary(DataParameters, ParameterBranchName, LineNumber, ParameterName, ParameterValue)
	
	If DataParameters = Undefined Then
		DataParameters = New Map;
	EndIf;
	
	CurrentParameterData = DataParameters[ParameterBranchName];
	
	If CurrentParameterData = Undefined Then
		
		CurrentParameterData = New ValueTable;
		CurrentParameterData.Columns.Add("LineNumber");
		CurrentParameterData.Columns.Add("ParameterName");
		CurrentParameterData.Indexes.Add("LineNumber");
		
		DataParameters.Insert(ParameterBranchName, CurrentParameterData);	
		
	EndIf;
	
	If CurrentParameterData.Columns.Find(ParameterName) = Undefined Then
		CurrentParameterData.Columns.Add(ParameterName);
	EndIf;		
	
	RowData = CurrentParameterData.Find(LineNumber, "LineNumber");
	If RowData = Undefined Then
		RowData = CurrentParameterData.Add();
		RowData.LineNumber = LineNumber;
	EndIf;		
	
	RowData[ParameterName] = ParameterValue;
	
EndProcedure

Procedure SetObjectRef(NotWrittenObjectStackRow)
	
	// The is not written yet but need a reference
	ObjectToWrite = NotWrittenObjectStackRow.Object;
	
	MDProperties  = Managers[NotWrittenObjectStackRow.ObjectType];
	Manager       = MDProperties.Manager;
		
	NewUUID = New UUID;
	NewRef = Manager.GetRef(NewUUID);
		
	ObjectToWrite.SetNewObjectRef(NewRef);
	NotWrittenObjectStackRow.KnownRef = NewRef;
	
EndProcedure

Procedure SupplementNotWrittenObjectStack(Sn, GSn, Object, KnownRef, ObjectType, ObjectParameters)
	
	NumberForStack = ?(Sn = 0, GSn, Sn);
	
	StackString = mNotWrittenObjectGlobalStack[NumberForStack];
	If StackString <> Undefined Then
		Return;
	EndIf;
	
	mNotWrittenObjectGlobalStack.Insert(NumberForStack, New Structure("Object, KnownRef, ObjectType, ObjectParameters", Object, KnownRef, ObjectType, ObjectParameters));
	
EndProcedure

Procedure DeleteFromNotWrittenObjectStack(Sn, GSn)
	
	NumberForStack = ?(Sn = 0, GSn, Sn);
	mNotWrittenObjectGlobalStack.Delete(NumberForStack);	
	
EndProcedure

Procedure ExecuteWriteNotWrittenObjects()
	
	For Each DataRow In mNotWrittenObjectGlobalStack Do
		
		// Deferred objects writing
		Object = DataRow.Value.Object;
		RefSn  = DataRow.Key;
		
		WriteObjectToInfobase(Object, DataRow.Value.ObjectType);
		
		AddRefToImportedObjectList(0, RefSn, Object.Ref);
				
	EndDo;
	
	mNotWrittenObjectGlobalStack.Clear();
	
EndProcedure

Procedure GenerateNumberCodeIfNecessary(GenerateNewNumberOrCodeIfNotSet, Object, ObjectTypeName, MustWriteObject, 
	DataExchangeMode)
	
	If Not GenerateNewNumberOrCodeIfNotSet
		Or Not DataExchangeMode Then
		
		// No need to generate the number or it is generated automatically by the platform
		Return;
	EndIf;
	
	// Checking whether the code or number are filled (depends on the object type)
	If ObjectTypeName = "Document"
		Or ObjectTypeName =  "BusinessProcess"
		Or ObjectTypeName = "Task" Then
		
		If Not ValueIsFilled(Object.Number) Then
			
			Object.SetNewNumber();
			MustWriteObject = True;
			
		EndIf;
		
	ElsIf ObjectTypeName = "Catalog"
		Or ObjectTypeName = "ChartOfCharacteristicTypes"
		Or ObjectTypeName = "ExchangePlan" Then
		
		If Not ValueIsFilled(Object.Code) Then
			
			Object.SetNewCode();
			MustWriteObject = True;
			
		EndIf;	
		
	EndIf;
	
EndProcedure

// Reads the next object from the exchange file, imports it.
//
Function ReadObject()

	Sn                   = deAttribute(ExchangeFile, deNumberType, "Sn");
	GSn                  = deAttribute(ExchangeFile, deNumberType, "GSn");
	Source               = deAttribute(ExchangeFile, deStringType, "Source");
	RuleName             = deAttribute(ExchangeFile, deStringType, "RuleName");
	DontReplaceObject    = deAttribute(ExchangeFile, deBooleanType, "DontReplace");
	AutonumerationPrefix = deAttribute(ExchangeFile, deStringType, "AutonumerationPrefix");
	ObjectTypeString     = deAttribute(ExchangeFile, deStringType, "Type");
	ObjectType           = Type(ObjectTypeString);
	TypeInformation      = mDataTypeMapForImport[ObjectType];


	ObjectImportComments(Sn, RuleName, Source, ObjectType, GSn);    
	
	PropertyStructure = Managers[ObjectType];
	ObjectTypeName   = PropertyStructure.TypeName;

	If ObjectTypeName = "Document" Then
		
		WriteMode   = deAttribute(ExchangeFile, deStringType, "WriteMode");
		PostingMode = deAttribute(ExchangeFile, deStringType, "PostingMode");
		
	EndIf;	
	
	Ref          = Undefined;
	Object       = Undefined;
	ObjectFound  = True;
	DeletionMark = Undefined;
	
	SearchProperties  = New Map;
	SearchPropertiesDontReplace  = New Map;
	
	MustWriteObject = Not WriteOnlyChangedObjectsToInfobase;
	


	If Not IsBlankString(RuleName) Then
		
		Rule = Rules[RuleName];
		HasBeforeImportHandler = Rule.HasBeforeImportHandler;
		HasOnImportHandler     = Rule.HasOnImportHandler;
		HasAfterImportHandler  = Rule.HasAfterImportHandler;
		GenerateNewNumberOrCodeIfNotSet = Rule.GenerateNewNumberOrCodeIfNotSet;

		
	Else
		
		HasBeforeImportHandler = False;
		HasOnImportHandler     = False;
		HasAfterImportHandler  = False;
		GenerateNewNumberOrCodeIfNotSet = False;
		
	EndIf;


    // BeforeImportObject global event handler
	If HasBeforeImportObjectGlobalHandler Then
		
		Cancel = False;
		
		Try
			
			If HandlerDebugModeFlag Then
				
				Execute(GetHandlerCallString(Conversion, "BeforeImportObject"));
				
			Else
				
				Execute(Conversion.BeforeImportObject);
				
			EndIf;
			
		Except
			
			WriteErrorInfoOCRHandlerImport(53, ErrorDescription(), RuleName, Source, 
				ObjectType, Undefined, NStr("en = 'BeforeImportObject (global)'"));
							
		EndTry;
						
		If Cancel Then	//	Canceling the object import
			
			deSkip(ExchangeFile, "Object");
			Return Undefined;
			
		EndIf;
		
	EndIf;
	
	
    // BeforeImportObject event handler
	If HasBeforeImportHandler Then
		
		Cancel = False;
		
		Try
			
			If HandlerDebugModeFlag Then
				
				Execute(GetHandlerCallString(Rule, "BeforeImport"));
				
			Else
				
				Execute(Rule.BeforeImport);
				
			EndIf;
			
		Except
			
			WriteErrorInfoOCRHandlerImport(19, ErrorDescription(), RuleName, Source, 
				ObjectType, Undefined, "BeforeImportObject");				
							
		EndTry;
				
		If Cancel Then // Canceling the object import
			
			deSkip(ExchangeFile, "Object");
			Return Undefined;
			
		EndIf;
		
	EndIf;
	
	ObjectPropertyModified = False;
	RecordSet = Undefined;
	GlobalRefSn = 0;
	RefSn = 0;
	ObjectParameters = Undefined;
		
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
				
		If NodeName = "Property"
			Or NodeName = "ParameterValue" Then
			
			IsParameterForObject = (NodeName = "ParameterValue");
			
			If Not IsParameterForObject
				And Object = Undefined Then
				
				// The object was not found and was not created, attempting to do it now
				ObjectFound = False;

			    // OnImportObject event handler
				If HasOnImportHandler Then
					
					// Rewriting the object if OnImporthandler exists, because of possible changes
					MustWriteObjectEarlier = MustWriteObject;
      				ObjectModified = True;
										
					Try
						
						If HandlerDebugModeFlag Then
							
							Execute(GetHandlerCallString(Rule, "OnImport"));
							
						Else
							
							Execute(Rule.OnImport);
						
						EndIf;
						MustWriteObject = ObjectModified Or MustWriteObjectEarlier;
						
					Except
						
						WriteErrorInfoOCRHandlerImport(20, ErrorDescription(), RuleName, Source, 
							ObjectType, Object, "OnImportObject");						
						
					EndTry;
										
				EndIf;

				// Failed to create the object in the event, creating it now
				If Object = Undefined Then
					
					MustWriteObject = True;
					
					If ObjectTypeName = "Constants" Then
						
						Object = Constants.CreateSet();
						Object.Read();
						
					Else
						
						CreateNewObject(ObjectType, SearchProperties, Object, False, RecordSet, , RefSn, GlobalRefSn, ObjectParameters);
												
					EndIf;
					
				EndIf;
				
			EndIf;
			
			Name                = deAttribute(ExchangeFile, deStringType, "Name");
			DontReplaceProperty = deAttribute(ExchangeFile, deBooleanType, "DontReplace");
			OCRName             = deAttribute(ExchangeFile, deStringType, "OCRName");
			
			If Not IsParameterForObject
				And ((ObjectFound And DontReplaceProperty) 
				Or (Name = "IsFolder")
				Or (Object[Name] = NULL)) Then
				
				// Unknown property
				deSkip(ExchangeFile, NodeName);
				Continue;
				
			EndIf; 

			
			// Reading and setting the property value
			PropertyType = GetPropertyTypeByAdditionalData(TypeInformation, Name);
			Value        = ReadProperty(PropertyType, OCRName);
			
			If IsParameterForObject Then
				
				// Supplementing the object parameter collection
				AddParameterIfNecessary(ObjectParameters, Name, Value);
				
			Else
			
				If Name = "DeletionMark" Then
					
					DeletionMark = Value;
					
					If Object.DeletionMark <> DeletionMark Then
						Object.DeletionMark = DeletionMark;
						MustWriteObject = True;
					EndIf;
										
				Else
					
					Try
						
						If Not MustWriteObject Then
							
							MustWriteObject = (Object[Name] <> Value);
							
						EndIf;
						
						Object[Name] = Value;
						
					Except
						
						LR = GetLogRecordStructure(26, ErrorDescription());
						LR.OCRName         = RuleName;
						LR.Sn              = Sn;
						LR.GSn             = GSn;
						LR.Source          = Source;
						LR.Object          = Object;
						LR.ObjectType      = ObjectType;
						LR.Property        = Name;
						LR.Value           = Value;
						LR.ValueType       = TypeOf(Value);

						ErrorMessageString = WriteToExecutionLog(26, LR, True);
						
						If Not DebugModeFlag Then
							Raise ErrorMessageString;
						EndIf;
						
					EndTry;					
									
				EndIf;
				
			EndIf;
			
		ElsIf NodeName = "Ref" Then

			// Item reference. Getting the object by reference and then setting properties.
			CreatedObject = Undefined;
			DontCreateObjectIfNotFound = Undefined;
			KnownUUIDRef = Undefined;
			
			Ref = FindObjectByRef(ObjectType,
								SearchProperties,
								SearchPropertiesDontReplace,
								ObjectFound,
								CreatedObject,
								DontCreateObjectIfNotFound,
								True,
								ObjectPropertyModified,
								GlobalRefSn,
								RefSn,
								KnownUUIDRef,
								ObjectParameters,
								RuleName);

			MustWriteObject = MustWriteObject Or ObjectPropertyModified;
			
			If Ref = Undefined
				And DontCreateObjectIfNotFound = True Then
				
				deSkip(ExchangeFile, "Object");
				Break;	
			
			ElsIf ObjectTypeName = "Enum" Then
				
				Object = Ref;	
			
			Else
				
				Object = GetObjectByRefAndAdditionalInformation(CreatedObject, Ref);
				
				If ObjectFound And DontReplaceObject And (Not HasOnImportHandler) Then
					
					deSkip(ExchangeFile, "Object");
					Break;
					
				EndIf;
				
				If Ref = Undefined Then
					
					SupplementNotWrittenObjectStack(Sn, GSn, CreatedObject, KnownUUIDRef, ObjectType, ObjectParameters);
					
				EndIf;
							
			EndIf; 
			
		    // OnImportObject event handler
			If HasOnImportHandler Then
				
				MustWriteObjectEarlier = MustWriteObject;
      			ObjectModified = True;
				
				Try
					
					If HandlerDebugModeFlag Then
						
						Execute(GetHandlerCallString(Rule, "OnImport"));
						
					Else
						
						Execute(Rule.OnImport);
						
					EndIf;
					
					MustWriteObject = ObjectModified Or MustWriteObjectEarlier;
					
				Except
					
					WriteErrorInfoOCRHandlerImport(20, ErrorDescription(), RuleName, Source, 
							ObjectType, Object, "OnImportObject");						
					
				EndTry;
								
				If ObjectFound And DontReplaceObject Then
					
					deSkip(ExchangeFile, "Object");
					Break;
					
				EndIf;
				
			EndIf;			
			
		ElsIf NodeName = "TabularSection"
			Or NodeName = "RecordSet" Then

			If Object = Undefined Then
				
				ObjectFound = False;

			    // OnImportObject event handler
				
				If HasOnImportHandler Then
					
					MustWriteObjectEarlier = MustWriteObject;
      				ObjectModified = True;
					
					Try
						
						If HandlerDebugModeFlag Then
							
							Execute(GetHandlerCallString(Rule, "OnImport"));
							
						Else
							
							Execute(Rule.OnImport);
							
						EndIf;
						
						MustWriteObject = ObjectModified Or MustWriteObjectEarlier;
						
					Except
						
						WriteErrorInfoOCRHandlerImport(20, ErrorDescription(), RuleName, Source, 
							ObjectType, Object, "OnImportObject");							
						
					EndTry;				
					
				EndIf;						
				
			EndIf;
			

			Name                = deAttribute(ExchangeFile, deStringType, "Name");
			DontReplaceProperty = deAttribute(ExchangeFile, deBooleanType, "DontReplace");
			DontClear           = deAttribute(ExchangeFile, deBooleanType, "DontClear");

			If ObjectFound And DontReplaceProperty Then
				
				deSkip(ExchangeFile, NodeName);
				Continue;
				
			EndIf;
			
			If Object = Undefined Then
					
				CreateNewObject(ObjectType, SearchProperties, Object, False, RecordSet, , RefSn, GlobalRefSn, ObjectParameters);
				MustWriteObject = True;
									
			EndIf;
			
			If NodeName = "TabularSection" Then
				
				// Importing items from the tabular section
				ImportTabularSection(Object, Name, Not DontClear, TypeInformation, MustWriteObject, ObjectParameters, Rule);
				
			ElsIf NodeName = "RecordSet" Then
				
				// Importing register
				ImportRegisterRecords(Object, Name, Not DontClear, TypeInformation, MustWriteObject, ObjectParameters, Rule);
				
			EndIf;			
			
		ElsIf (NodeName = "Object") And (ExchangeFile.NodeType = deXMLNodeType_EndElement) Then
			
			Cancel = False;
			
		    // AfterImportObject global event handler
			If HasAfterImportObjectGlobalHandler Then
				
				MustWriteObjectEarlier = MustWriteObject;
      			ObjectModified = True;
				
				Try
					
					If HandlerDebugModeFlag Then
						
						Execute(GetHandlerCallString(Conversion, "AfterImportObject"));
						
					Else
						
						Execute(Conversion.AfterImportObject);
						
					EndIf;
					
					MustWriteObject = ObjectModified Or MustWriteObjectEarlier;
					
				Except
					
					WriteErrorInfoOCRHandlerImport(54, ErrorDescription(), RuleName, Source,
							ObjectType, Object, NStr("en = 'AfterImportObject (global)'"));
					
				EndTry;
						
			EndIf;
			
			// AfterImportObject event handler
			If HasAfterImportHandler Then
				
				MustWriteObjectEarlier = MustWriteObject;
				ObjectModified = True;
				
				Try
					
					If HandlerDebugModeFlag Then
						
						Execute(GetHandlerCallString(Rule, "AfterImport"));
						
					Else
						
						Execute(Rule.AfterImport);
				
					EndIf;
					
					MustWriteObject = ObjectModified Or MustWriteObjectEarlier;
					
				Except
					
					WriteErrorInfoOCRHandlerImport(21, ErrorDescription(), RuleName, Source, 
							ObjectType, Object, "AfterImportObject");				
											
				EndTry;
							
			EndIf;
			
			If Cancel Then
				
				AddRefToImportedObjectList(GlobalRefSn, RefSn, Undefined);
				DeleteFromNotWrittenObjectStack(Sn, GSn);
				Return Undefined;
				
			EndIf;			
			
			If ObjectTypeName = "Document" Then
				
				If WriteMode = "Posting" Then
					
					WriteMode = DocumentWriteMode.Posting;
					
				Else
					
					WriteMode = ?(WriteMode = "UndoPosting", DocumentWriteMode.UndoPosting, DocumentWriteMode.Write);
					
				EndIf;
				
				
				PostingMode = ?(PostingMode = "RealTime", DocumentPostingMode.RealTime, DocumentPostingMode.Regular);
				

				// Clearing the deletion mark to post the marked for deletion object
				If Object.DeletionMark
					And (WriteMode = DocumentWriteMode.Posting) Then
					
					Object.DeletionMark = False;
					MustWriteObject = True;
					
					// The deletion mark is deleted anyway
					DeletionMark = False;
									
				EndIf;				
				
				Try
					
					MustWriteObject = MustWriteObject Or (WriteMode <> DocumentWriteMode.Write);
					
					DataExchangeMode = WriteMode = DocumentWriteMode.Write;
					
					GenerateNumberCodeIfNecessary(GenerateNewNumberOrCodeIfNotSet, Object, 
						ObjectTypeName, MustWriteObject, DataExchangeMode);
					
					If MustWriteObject Then
					
						SetDataExchangeLoad(Object, DataExchangeMode);
						If Object.Posted Then
							Object.DeletionMark = False;
						EndIf;
						
						Object.Write(WriteMode, PostingMode);
						
					EndIf;					
						
				Except
						
					// Failed to execute actions required for the document
					WriteDocumentInSafeMode(Object, ObjectType);
						
						
					LR            = GetLogRecordStructure(25, ErrorDescription());
					LR.OCRName    = RuleName;

						
					If Not IsBlankString(Source) Then
							
						LR.Source           = Source;
							
					EndIf;
						
					LR.ObjectType             = ObjectType;
					LR.Object                 = String(Object);
					WriteToExecutionLog(25, LR);
						
				EndTry;
				
				AddRefToImportedObjectList(GlobalRefSn, RefSn, Object.Ref);
									
				DeleteFromNotWrittenObjectStack(Sn, GSn);
				
			ElsIf ObjectTypeName <> "Enum" Then
				
				If ObjectTypeName = "InformationRegister" Then
					
					MustWriteObject = Not WriteOnlyChangedObjectsToInfobase;
					
					If PropertyStructure.Periodical 
						And Not ValueIsFilled(Object.Period) Then
						
						Object.Period = CurrentSessionDate();
						MustWriteObject = True;							
												
					EndIf;
					
					If WriteRegisterRecordsAsRecordSets Then
						
						MustCheckDataForTempSet = 
							(WriteOnlyChangedObjectsToInfobase
								And Not MustWriteObject) 
							Or DontReplaceObject;
						
						If MustCheckDataForTempSet Then
							
							TemporaryRecordSet = InformationRegisters[PropertyStructure.Name].CreateRecordSet();
							
						EndIf;
						
						// The register requires the filter to be set
						For Each FilterItem In RecordSet.Filter Do
							
							FilterItem.Set(Object[FilterItem.Name]);
							If MustCheckDataForTempSet Then
								TemporaryRecordSet.Filter[FilterItem.Name].Set(Object[FilterItem.Name]);
							EndIf;
							
						EndDo;
						
						If MustCheckDataForTempSet Then
							
							TemporaryRecordSet.Read();
							
							If TemporaryRecordSet.Count() = 0 Then
								MustWriteObject = True;
							Else
								
								// Existing set is not be replaced
								If DontReplaceObject Then
									Return Undefined;
								EndIf;
								
								MustWriteObject = False;
								NewTable = RecordSet.Unload();
								TableOld = TemporaryRecordSet.Unload(); 
								
								RowNew = NewTable[0]; 
								OldRow = TableOld[0]; 
								
								For Each TableColumn In NewTable.Columns Do
									
									MustWriteObject = RowNew[TableColumn.Name] <>  OldRow[TableColumn.Name];
									If MustWriteObject Then
										Break;
									EndIf;
									
								EndDo;							
								
							EndIf;
							
						EndIf;
						
						Object = RecordSet;
						
					Else
						
						// Checking whether the current record set must be replaced
						If DontReplaceObject Then
							
							TemporaryRecordSet = InformationRegisters[PropertyStructure.Name].CreateRecordSet();
							
							// The register requires the filter to be set
							For Each FilterItem In TemporaryRecordSet.Filter Do
							
								FilterItem.Set(Object[FilterItem.Name]);
																
							EndDo;
							
							TemporaryRecordSet.Read();
							
							If TemporaryRecordSet.Count() > 0 Then
								Return Undefined;
							EndIf;
							
						EndIf;
						
					EndIf;
					
				EndIf;
				
				IsReferenceTypeObject = Not( ObjectTypeName = "InformationRegister"
					Or ObjectTypeName = "Constants");
					
				If IsReferenceTypeObject Then 	
					
					GenerateNumberCodeIfNecessary(GenerateNewNumberOrCodeIfNotSet, Object, ObjectTypeName, MustWriteObject, ImportDataInExchangeMode);
					
					If DeletionMark = Undefined Then
						DeletionMark = False;
					EndIf;
					
					If Object.DeletionMark <> DeletionMark Then
						Object.DeletionMark = DeletionMark;
						MustWriteObject = True;
					EndIf;
					
				EndIf;
				
				//Writing the object directly
				If MustWriteObject Then
				
					WriteObjectToInfobase(Object, ObjectType);
					
				EndIf;
				
				If IsReferenceTypeObject Then
					
					AddRefToImportedObjectList(GlobalRefSn, RefSn, Object.Ref);
					
				EndIf;
				
				DeleteFromNotWrittenObjectStack(Sn, GSn);
								
			EndIf;
			
			Break;
			
		ElsIf NodeName = "SequenceRecordSet" Then
			
			deSkip(ExchangeFile);
			
		ElsIf NodeName = "Types" Then

			If Object = Undefined Then
				
				ObjectFound = False;
				Ref         = CreateNewObject(ObjectType, SearchProperties, Object, , , , RefSn, GlobalRefSn, ObjectParameters);
								
			EndIf; 

			ObjectTypeDescription = ImportObjectTypes(ExchangeFile);

			If ObjectTypeDescription <> Undefined Then
				
				Object.ValueType = ObjectTypeDescription;
				
			EndIf; 
			
		Else
			
			WriteToExecutionLog(9);
			Break;
			
		EndIf;
		
	EndDo;
	
	Return Object;

EndFunction // ReadObject() 


////////////////////////////////////////////////////////////////////////////////
// PROCEDURES FOR EXPORTING DATA USING EXCHANGE RULES.

Function GetDocumentRegisterRecordSet(DocumentRef, SourceKind, RegisterName)
	
	If SourceKind = "AccumulationRegisterRecordSet" Then
		
		DocumentRegisterRecordSet = AccumulationRegisters[RegisterName].CreateRecordSet();
		
	ElsIf SourceKind = "InformationRegisterRecordSet" Then
		
		DocumentRegisterRecordSet = InformationRegisters[RegisterName].CreateRecordSet();
		
	ElsIf SourceKind = "AccountingRegisterRecordSet" Then
		
		DocumentRegisterRecordSet = AccountingRegisters[RegisterName].CreateRecordSet();
		
	ElsIf SourceKind = "CalculationRegisterRecordSet" Then	
		
		DocumentRegisterRecordSet = CalculationRegisters[RegisterName].CreateRecordSet();
		
	Else
		
		Return Undefined;
		
	EndIf;
	
	DocumentRegisterRecordSet.Filter.Recorder.Set(DocumentRef);
	DocumentRegisterRecordSet.Read();
	
	Return DocumentRegisterRecordSet;
	
EndFunction


Procedure WriteStructureToXML(DataStructure, PropertyCollectionNode)
	
	PropertyCollectionNode.WriteStartElement("Property");
	
	For Each CollectionItem In DataStructure Do
		
		If CollectionItem.Key = "Expression"
			Or CollectionItem.Key = "Value"
			Or CollectionItem.Key = "Sn"
			Or CollectionItem.Key = "GSn" Then
			
			deWriteElement(PropertyCollectionNode, CollectionItem.Key, CollectionItem.Value);
			
		ElsIf CollectionItem.Key = "Ref" Then
			
			PropertyCollectionNode.WriteRaw(CollectionItem.Value);
			
		Else
			
			SetAttribute(PropertyCollectionNode, CollectionItem.Key, CollectionItem.Value);
			
		EndIf;
		
	EndDo;
	
	PropertyCollectionNode.WriteEndElement();		
	
EndProcedure

Procedure CreateObjectsForXMLWriter(DataStructure, PropertyNode, XMLNodeRequired, NodeName, XMLNodeDescription = "Property")
	
	If XMLNodeRequired Then
		
		PropertyNode = CreateNode(XMLNodeDescription);
		SetAttribute(PropertyNode, "Name", NodeName);
		
	Else
		
		DataStructure = New Structure("Name", NodeName);	
		
	EndIf;		
	
EndProcedure

Procedure AddAttributeForXMLWriter(PropertyNodeStructure, PropertyNode, AttributeName, AttributeValue)
	
	If PropertyNodeStructure <> Undefined Then
		PropertyNodeStructure.Insert(AttributeName, AttributeValue);
	Else
		SetAttribute(PropertyNode, AttributeName, AttributeValue);
	EndIf;
	
EndProcedure

Procedure WriteDataToMasterNode(PropertyCollectionNode, PropertyNodeStructure, PropertyNode)
	
	If PropertyNodeStructure <> Undefined Then
		WriteStructureToXML(PropertyNodeStructure, PropertyCollectionNode);
	Else
		AddSubordinateNode(PropertyCollectionNode, PropertyNode);
	EndIf;
	
EndProcedure



// Generates target object property nodes based on the specified property conversion
// rule collection.
//
// Parameters:
//  Source                 - arbitrary data source.
//  Target                 - target object XML node.
//  IncomingData           - arbitrary auxiliary data passed to the rule for performing  
//                           the conversion.
//  OutgoingData           - arbitrary auxiliary data, passed to the property object 
//                           conversion rules.
//  OCR                    - reference to the object conversion rule (property
//                           conversion rule collection parent).
//  PGCR                   - reference to the property group conversion rule.
//  PropertyCollectionNode - property collection XML node.
//
 
Procedure ExportPropertyGroup(Source, Target, IncomingData, OutgoingData, OCR, PGCR, PropertyCollectionNode, 
	ExportRefOnly, TempFileList = Undefined)
	
	ObjectCollection = Undefined;
	DontReplace        = PGCR.DontReplace;
	DontClear         = False;
	ExportGroupToFile = PGCR.ExportGroupToFile;
	
	// BeforeProcessExport handler
	If PGCR.HasBeforeProcessExportHandler Then
		
		Cancel = False;
		Try
			
			If HandlerDebugModeFlag Then
				
				Execute(GetHandlerCallString(PGCR, "BeforeProcessExport"));
				
			Else
				
				Execute(PGCR.BeforeProcessExport);
				
			EndIf;
			
		Except
			
			WriteErrorInfoPCRHandlers(48, ErrorDescription(), OCR, PGCR,
				Source, "BeforePropertyGroupExport",, False);
		
		EndTry;
		
		If Cancel Then // Canceling property group processing
			
			Return;
			
		EndIf;
		
	EndIf;

	
    TargetKind = PGCR.TargetKind;
	  SourceKind = PGCR.SourceKind;
	
	
    // Creating a node of subordinate object collection
	PropertyNodeStructure = Undefined;
	ObjectCollectionNode = Undefined;
	MasterNodeName = "";
	
	If TargetKind = "TabularSection" Then
		
		MasterNodeName = "TabularSection";
		
		CreateObjectsForXMLWriter(PropertyNodeStructure, ObjectCollectionNode, TRUE, PGCR.Target, MasterNodeName);
		
		If DontReplace Then
			
			AddAttributeForXMLWriter(PropertyNodeStructure, ObjectCollectionNode, "DontReplace", "true");
						
		EndIf;
		
		If DontClear Then
			
			AddAttributeForXMLWriter(PropertyNodeStructure, ObjectCollectionNode, "DontClear", "true");
						
		EndIf;
		
	ElsIf TargetKind = "SubordinateCatalog" Then
				
		
	ElsIf TargetKind = "SequenceRecordSet" Then
		
		MasterNodeName = "RecordSet";
		
		CreateObjectsForXMLWriter(PropertyNodeStructure, ObjectCollectionNode, TRUE, PGCR.Target, MasterNodeName);
		
	ElsIf Find(TargetKind, "RegisterRecordSet") > 0 Then
		
		MasterNodeName = "RecordSet";
		
		CreateObjectsForXMLWriter(PropertyNodeStructure, ObjectCollectionNode, TRUE, PGCR.Target, MasterNodeName);
		
		If DontReplace Then
			
			AddAttributeForXMLWriter(PropertyNodeStructure, ObjectCollectionNode, "DontReplace", "true");
						
		EndIf;
		
		If DontClear Then
			
			AddAttributeForXMLWriter(PropertyNodeStructure, ObjectCollectionNode, "DontClear", "true");
						
		EndIf;
		
	Else  // Simple group
		
		ExportProperties(Source, Target, IncomingData, OutgoingData, OCR, PGCR.GroupRules, 
		     PropertyCollectionNode, , , OCR.DontExportPropertyObjectsByRefs Or ExportRefOnly);
			
		If PGCR.HasAfterProcessExportHandler Then
			
			Try
				
				If HandlerDebugModeFlag Then
					
					Execute(GetHandlerCallString(PGCR, "AfterProcessExport"));
					
				Else
					
					Execute(PGCR.AfterProcessExport);
			
				EndIf;
				
			Except
				
				WriteErrorInfoPCRHandlers(49, ErrorDescription(), OCR, PGCR,
					Source, "AfterProcessPropertyGroupExport",, False);
				
			EndTry;
			
		EndIf;
		
		Return;
		
	EndIf;
	
	// Getting the collection of subordinate objects
	
	If ObjectCollection <> Undefined Then
		
		// The collection was initialized in the BeforeProcess handler
		
	ElsIf PGCR.GetFromIncomingData Then
		
		Try
			
			ObjectCollection = IncomingData[PGCR.Target];
			
			If TypeOf(ObjectCollection) = Type("QueryResult") Then
				
				ObjectCollection = ObjectCollection.Unload();
				
			EndIf;
			
		Except
			
			WriteErrorInfoPCRHandlers(66, ErrorDescription(), OCR, PGCR, Source,,,False);
			
			Return;
		EndTry;
		
	ElsIf SourceKind = "TabularSection" Then
		
		ObjectCollection = Source[PGCR.Source];
		
		If TypeOf(ObjectCollection) = Type("QueryResult") Then
			
			ObjectCollection = ObjectCollection.Unload();
			
		EndIf;
		
	ElsIf SourceKind = "SubordinateCatalog" Then
		
	ElsIf Find(SourceKind, "RegisterRecordSet") > 0 Then
		
		ObjectCollection = GetDocumentRegisterRecordSet(Source, SourceKind, PGCR.Source);
				
	ElsIf IsBlankString(PGCR.Source) Then
		
		ObjectCollection = Source[PGCR.Target];
		
		If TypeOf(ObjectCollection) = Type("QueryResult") Then
			
			ObjectCollection = ObjectCollection.Unload();
			
		EndIf;
		
	EndIf;
	
	ExportGroupToFile = ExportGroupToFile Or (ObjectCollection.Count() > 1000);
	ExportGroupToFile = ExportGroupToFile And (DirectReadingInTargetInfobase = False);
	
	If ExportGroupToFile Then
		
		PGCR.XMLNodeRequiredOnExport = False;
		
		If TempFileList = Undefined Then
			TempFileList = New ValueList();
		EndIf;
		
		RecordFileName = GetTempFileName();
		TempFileList.Add(RecordFileName);
		
		TempRecordFile = New TextWriter;
		Try
			
			TempRecordFile.Open(RecordFileName, TextEncoding.UTF8);
			
		Except
			
			WriteErrorInfoConversionHandlers(1000, ErrorDescription(), NStr("en = 'Error creating temporary file for data export'"));
			
		EndTry; 
		
		InformationToWriteToFile = ObjectCollectionNode.Close();
		TempRecordFile.WriteLine(InformationToWriteToFile);
		
	EndIf;
	
	For Each CollectionObject In ObjectCollection Do
		
		// BeforeExport handler
		If PGCR.HasBeforeExportHandler Then
			
			Cancel = False;
			
			Try
				
				If HandlerDebugModeFlag Then
					
					Execute(GetHandlerCallString(PGCR, "BeforeExport"));
					
				Else
					
					Execute(PGCR.BeforeExport);
					
				EndIf;
				
			Except
				
				WriteErrorInfoPCRHandlers(50, ErrorDescription(), OCR, PGCR,
					Source, "BeforeImportPropertyGroup",, False);
				
				Break;
				
			EndTry;
			
			If Cancel Then	//	Canceling subordinate object export
				
				Continue;
				
			EndIf;
			
		EndIf;
		
		// OnExport handler 
		
		If PGCR.XMLNodeRequiredOnExport Or ExportGroupToFile Then
			CollectionObjectNode = CreateNode("Write");
		Else
			ObjectCollectionNode.WriteStartElement("Write");
			CollectionObjectNode = ObjectCollectionNode;
		EndIf;
		
		StandardProcessing	= True;
		
		If PGCR.HasOnExportHandler Then
			
			Try
				
				If HandlerDebugModeFlag Then
					
					Execute(GetHandlerCallString(PGCR, "OnExport"));
					
				Else
					
					Execute(PGCR.OnExport);
					
				EndIf;
				
			Except
				
				WriteErrorInfoPCRHandlers(51, ErrorDescription(), OCR, PGCR,
					Source, "OnExportPropertyGroup",, False);
				
				Break;
				
			EndTry;
			
		EndIf;

		//	Exporting the collection object properties
		
		If StandardProcessing Then
			
			If PGCR.GroupRules.Count() > 0 Then
				
		 		ExportProperties(Source, Target, IncomingData, OutgoingData, OCR, PGCR.GroupRules, 
		 			CollectionObjectNode, CollectionObject, , OCR.DontExportPropertyObjectsByRefs Or ExportRefOnly);
				
			EndIf;
			
		EndIf;
		
		// AfterExport handler
		
		If PGCR.HasAfterExportHandler Then
			
			Cancel = False;
			
			Try
				
				If HandlerDebugModeFlag Then
					
					Execute(GetHandlerCallString(PGCR, "AfterExport"));
					
				Else
					
					Execute(PGCR.AfterExport);
					
				EndIf;
				
			Except
				
				WriteErrorInfoPCRHandlers(52, ErrorDescription(), OCR, PGCR,
					Source, "AfterExportPropertyGroup",, False);
				
				Break;
			EndTry; 
			
			If Cancel Then	//	Canceling subordinate object export
				
				Continue;
				
			EndIf;
			
		EndIf;
		
		If PGCR.XMLNodeRequiredOnExport Then
			AddSubordinateNode(ObjectCollectionNode, CollectionObjectNode);
		EndIf;
		
		// Filling the file with node objects
		If ExportGroupToFile Then
			
			CollectionObjectNode.WriteEndElement();
			InformationToWriteToFile = CollectionObjectNode.Close();
			TempRecordFile.WriteLine(InformationToWriteToFile);
			
		Else
			
			If Not PGCR.XMLNodeRequiredOnExport Then
				
				ObjectCollectionNode.WriteEndElement();
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	
    // AfterProcessExport handler

	If PGCR.HasAfterProcessExportHandler Then
		
		Cancel = False;
		
		Try
			
			If HandlerDebugModeFlag Then
				
				Execute(GetHandlerCallString(PGCR, "AfterProcessExport"));
				
			Else
				
				Execute(PGCR.AfterProcessExport);
				
			EndIf;
			
		Except
			
			WriteErrorInfoPCRHandlers(49, ErrorDescription(), OCR, PGCR,
				Source, "AfterProcessPropertyGroupExport",, False);
			
		EndTry;
		
		If Cancel Then	//	Canceling subordinate object collection writing
			
			Return;
			
		EndIf;
		
	EndIf;
	
	If ExportGroupToFile Then
		TempRecordFile.WriteLine("</" + MasterNodeName + ">"); // Closing the node
		TempRecordFile.Close(); 	// Closing the file
	Else
		WriteDataToMasterNode(PropertyCollectionNode, PropertyNodeStructure, ObjectCollectionNode);
	EndIf;

EndProcedure

Procedure GetPropertyValue(Value, CollectionObject, OCR, PCR, IncomingData, Source)
	
	If Value <> Undefined Then
		Return;
	EndIf;
	
	If PCR.GetFromIncomingData Then
			
			ObjectForReceivingData = IncomingData;
			
			If Not IsBlankString(PCR.Target) Then
			
				PropertyName = PCR.Target;
				
			Else
				
				PropertyName = PCR.ParameterForTransferName;
				
			EndIf;
			
			ErrorCode = ?(CollectionObject <> Undefined, 67, 68);
	
	ElsIf CollectionObject <> Undefined Then
		
		ObjectForReceivingData = CollectionObject;
		
		If Not IsBlankString(PCR.Source) Then
			
			PropertyName = PCR.Source;
			ErrorCode = 16;
						
		Else
			
			PropertyName = PCR.Target;
			ErrorCode = 17;
            							
		EndIf;
						
	Else
		
		ObjectForReceivingData = Source;
		
		If Not IsBlankString(PCR.Source) Then
		
			PropertyName = PCR.Source;
			ErrorCode = 13;
		
		Else
		
			PropertyName = PCR.Target;
			ErrorCode = 14;
		
		EndIf;
			
	EndIf;
	
	
	Try
					
		Value = ObjectForReceivingData[PropertyName];
					
	Except
					
		If ErrorCode <> 14 Then
			WriteErrorInfoPCRHandlers(ErrorCode, ErrorDescription(), OCR, PCR, Source, "");
		EndIf;
																	
	EndTry;					
			
EndProcedure

Procedure ExportItemPropertyType(PropertyNode, PropertyType)
	
	SetAttribute(PropertyNode, "Type", PropertyType);	
	
EndProcedure

Procedure _ExportExtDimension(Source,
							Target,
							IncomingData,
							OutgoingData,
							OCR,
							PCR,
							PropertyCollectionNode = Undefined,
							CollectionObject = Undefined,
							Val ExportRefOnly = False)
 
	// Variables for supporting the event handler script debugging mechanism.
	// (supporting the wrapper procedure interface).

	Var TargetType, Empty, Expression, DontReplace, PropertyNode, PropertyOCR;
	
	// Initializing the value
	Value = Undefined;
	OCRName = "";
	ExtDimensionTypeOCRName = "";
	
	// BeforeExport handler
	If PCR.HasBeforeExportHandler Then
		
		Cancel = False;
		
		Try
			
			If HandlerDebugModeFlag Then
				
				Execute(GetHandlerCallString(PCR, "BeforeExport"));
				
			Else
				
				Execute(PCR.BeforeExport);
				
			EndIf;
			
		Except
			
			WriteErrorInfoPCRHandlers(55, ErrorDescription(), OCR, PCR, Source, 
				"BeforeExportProperty", Value);				
							
		EndTry;
			
		If Cancel Then // Canceling the export
			
			Return;
			
		EndIf;
		
	EndIf;
	
	GetPropertyValue(Value, CollectionObject, OCR, PCR, IncomingData, Source);
	
	If PCR.CastToLength <> 0 Then
				
		CastValueToLength(Value, PCR);
						
	EndIf;
		
	For Each KeyAndValue In Value Do
		
		ExtDimensionType = KeyAndValue.Key;
		ExtDimensions = KeyAndValue.Value;
		OCRName = "";
		
		// OnExport hadler 
		If PCR.HasOnExportHandler Then
			
			Cancel = False;
			
			Try
				
				If HandlerDebugModeFlag Then
					
					Execute(GetHandlerCallString(PCR, "OnExport"));
					
				Else
					
					Execute(PCR.OnExport);
					
				EndIf;
				
			Except
				
				WriteErrorInfoPCRHandlers(56, ErrorDescription(), OCR, PCR, Source, 
					"OnExportProperty", Value);				
				
			EndTry;
				
			If Cancel Then // Canceling extra dimension exporting
				
				Continue;
				
			EndIf;
			
		EndIf;
		
		If ExtDimensions = Undefined
			Or FindRule(ExtDimensions, OCRName) = Undefined Then
			
			Continue;
			
		EndIf;
			
		ExtDimensionNode = CreateNode(PCR.Target);
			
		// Key
		PropertyNode = CreateNode("Property");
		
		If IsBlankString(ExtDimensionTypeOCRName) Then
				
			OCRKey = FindRule(ExtDimensionType, ExtDimensionTypeOCRName);
				
		Else
				
			OCRKey = FindRule(, ExtDimensionTypeOCRName);
				
		EndIf;
									
		SetAttribute(PropertyNode, "Name", "Key");
		ExportItemPropertyType(PropertyNode, OCRKey.Target);
			
		RefNode = ExportByRule(ExtDimensionType,, OutgoingData,, ExtDimensionTypeOCRName,, ExportRefOnly, OCRKey);
			
		If RefNode <> Undefined Then
			
			IsRuleWithGlobalExport = False;
			RefNodeType = TypeOf(RefNode);
			AddPropertiesForExport(RefNode, RefNodeType, PropertyNode, IsRuleWithGlobalExport);
				
		EndIf;
			
		AddSubordinateNode(ExtDimensionNode, PropertyNode);
		
		
		
		// Value
		PropertyNode = CreateNode("Property");
			
		OCRValue = FindRule(ExtDimensions, OCRName);
		
		TargetType = OCRValue.Target;
		
		IsNULL = False;
		Empty = deEmpty(ExtDimensions, IsNULL);
		
		If Empty Then
			
			If IsNULL 
				Or ExtDimensions = Undefined Then
				
				Continue;
				
			EndIf;
			
			If IsBlankString(TargetType) Then
				
				TargetType = GetDataTypeForTarget(ExtDimensions);
											
			EndIf;			
			
			SetAttribute(PropertyNode, "Name", "Value");
			
			If Not IsBlankString(TargetType) Then
				SetAttribute(PropertyNode, "Type", TargetType);
			EndIf;
				
			// If it is a variable of multiple type, it must be exported with the specified type, perhaps this is an empty reference
			deWriteElement(PropertyNode, "Empty");
					
			AddSubordinateNode(ExtDimensionNode, PropertyNode);
			
		Else
			
			IsRuleWithGlobalExport = False;
			RefNode = ExportByRule(ExtDimensions,, OutgoingData, , OCRName, , ExportRefOnly, OCRValue, IsRuleWithGlobalExport);
			
			SetAttribute(PropertyNode, "Name", "Value");
			ExportItemPropertyType(PropertyNode, TargetType);			
							
			If RefNode = Undefined Then
					
				Continue;
					
			EndIf;
			
			RefNodeType = TypeOf(RefNode);
							
			AddPropertiesForExport(RefNode, RefNodeType, PropertyNode, IsRuleWithGlobalExport);						
			
			AddSubordinateNode(ExtDimensionNode, PropertyNode);
			
		EndIf;	
		
		
			
		// AfterExport handler
		If PCR.HasAfterExportHandler Then
				
			Cancel = False;
				
			Try
				
				If HandlerDebugModeFlag Then
					
					Execute(GetHandlerCallString(PCR, "AfterExport"));
					
				Else
					
					Execute(PCR.AfterExport);
					
				EndIf;
					
			Except
					
				WriteErrorInfoPCRHandlers(57, ErrorDescription(), OCR, PCR, Source, 
					"AfterExportProperty", Value);					
					
			EndTry;
					
			If Cancel Then // Canceling the export
					
				Continue;
					
			EndIf;
							
		EndIf;
		
		AddSubordinateNode(PropertyCollectionNode, ExtDimensionNode);
		
	EndDo;
	
EndProcedure

Procedure AddPropertiesForExport(RefNode, RefNodeType, PropertyNode, IsRuleWithGlobalExport)
	
	If RefNodeType = deStringType Then
				
		If Find(RefNode, "<Ref") > 0 Then
					
			PropertyNode.WriteRaw(RefNode);
					
		Else
			
			deWriteElement(PropertyNode, "Value", RefNode);
					
		EndIf;
				
	ElsIf RefNodeType = deNumberType Then
		
		If IsRuleWithGlobalExport Then
		
			deWriteElement(PropertyNode, "GSn", RefNode);
			
		Else     		
			
			deWriteElement(PropertyNode, "Sn", RefNode);
			
		EndIf;
				
	Else
				
		AddSubordinateNode(PropertyNode, RefNode);
				
	EndIf;	
	
EndProcedure

Procedure AddPropertyValueToNode(Value, ValueType, TargetType, PropertyNode, PropertySet)
	
	PropertySet = True;
		
	If ValueType = deStringType Then
				
		If TargetType = "String"  Then
		ElsIf TargetType = "Number"  Then
					
			Value = Number(Value);
					
		ElsIf TargetType = "Boolean"  Then
					
			Value = Boolean(Value);
					
		ElsIf TargetType = "Date"  Then
					
			Value = Date(Value);
					
		ElsIf TargetType = "ValueStorage"  Then
					
			Value = New ValueStorage(Value);
					
		ElsIf TargetType = "UUID" Then
					
			Value = New UUID(Value);
					
		ElsIf IsBlankString(TargetType) Then
					
			SetAttribute(PropertyNode, "Type", "String");
					
		EndIf;
				
		deWriteElement(PropertyNode, "Value", Value);
				
	ElsIf ValueType = deNumberType Then
				
		If TargetType = "Number"  Then
		ElsIf TargetType = "Boolean"  Then
					
			Value = Boolean(Value);
					
		ElsIf TargetType = "String"  Then
		ElsIf IsBlankString(TargetType) Then
					
			SetAttribute(PropertyNode, "Type", "Number");
					
		Else
					
			Return;
					
		EndIf;
				
		deWriteElement(PropertyNode, "Value", Value);
				
	ElsIf ValueType = deDateType Then
				
		If TargetType = "Date"  Then
		ElsIf TargetType = "String"  Then
					
			Value = Left(String(Value), 10);
					
		ElsIf IsBlankString(TargetType) Then
					
			SetAttribute(PropertyNode, "Type", "Date");
					
		Else
					
			Return;
					
		EndIf;
				
		deWriteElement(PropertyNode, "Value", Value);  // Format(Value, "DF=""yyyyMMddHHmmss""")
				
	ElsIf ValueType = deBooleanType Then
				
		If TargetType = "Boolean"  Then
		ElsIf TargetType = "Number"  Then
					
			Value = Number(Value);
					
		ElsIf IsBlankString(TargetType) Then
					
			SetAttribute(PropertyNode, "Type", "Boolean");
					
		Else
					
			Return;
					
		EndIf;
				
		deWriteElement(PropertyNode, "Value", Value);
				
	ElsIf ValueType = deValueStorageType Then
				
		If IsBlankString(TargetType) Then
					
			SetAttribute(PropertyNode, "Type", "ValueStorage");
					
		ElsIf TargetType <> "ValueStorage"  Then
					
			Return;
					
		EndIf;
				
		deWriteElement(PropertyNode, "Value", Value);
				
	ElsIf ValueType = deUUIDType Then
		
		If TargetType = "UUID" Then
		ElsIf TargetType = "String"  Then
					
			Value = String(Value);
					
		ElsIf IsBlankString(TargetType) Then
					
			SetAttribute(PropertyNode, "Type", "UUID");
					
		Else
					
			Return;
					
		EndIf;
		
		deWriteElement(PropertyNode, "Value", Value);
		
	ElsIf ValueType = deAccumulationRecordTypeType Then
				
		deWriteElement(PropertyNode, "Value", String(Value));		
		
	Else	
		
		PropertySet = False;
		
	EndIf;	
	
EndProcedure


Function ExportRefObjectData(Value, OutgoingData, OCRName, PropertyOCR, TargetType, PropertyNode, Val ExportRefOnly)
	
	IsRuleWithGlobalExport = False;
	RefNode     = ExportByRule(Value, , OutgoingData, , OCRName, , ExportRefOnly, PropertyOCR, IsRuleWithGlobalExport);
	RefNodeType = TypeOf(RefNode);

	If IsBlankString(TargetType) Then
				
		TargetType  = PropertyOCR.Target;
		SetAttribute(PropertyNode, "Type", TargetType);
				
	EndIf;
			
	If RefNode = Undefined Then
				
		Return Undefined;
				
	EndIf;
				
	AddPropertiesForExport(RefNode, RefNodeType, PropertyNode, IsRuleWithGlobalExport);	
	
	Return RefNode;
	
EndFunction

Function GetDataTypeForTarget(Value)
	
	TargetType = deValueTypeString(Value);
	
	// Checking for any ORR with the TargetType target type.
	// If no rule is found, passing "" to TargetType, otherwise returning TargetType.

	TableRow = ConversionRuleTable.Find(TargetType, "Target");
	
	If TableRow = Undefined Then
		TargetType = "";
	EndIf;
	
	Return TargetType;
	
EndFunction

Procedure CastValueToLength(Value, PCR)
	
	Value = CastNumberToLength(String(Value), PCR.CastToLength);
		
EndProcedure

// Generates target object property nodes based on the specified property conversion 
// rule collection.
//
// Parameters:
//  Source                 - arbitrary data source.
//  Target                 - target object XML node.
//  IncomingData           - arbitrary auxiliary data passed to the rule for performing
//                           the conversion.
//  OutgoingData           - arbitrary auxiliary data passed to the property object
//                           conversion rules.
//  OCR                    - reference to the object conversion rule (property
//                           conversion rules collection parent).
//  PCRCollection          - property conversion rule collection.
//  PropertyCollectionNode - property collection XML node.
//  CollectionObject       - if this parameter is specified, collection object 
//                           properties are exported, otherwise source object properties 
//                           are exported.
//  PredefinedItemName     - if this parameter is specified, the predefined item name is
//                           written to the properties. 
//  PGCR                   - reference to the property group conversion rule (PCR 
//                           collection parent folder), for example, a document tabular
//                           section.
//
 
Procedure ExportProperties(Source, Target, IncomingData, OutgoingData, OCR, PCRCollection, PropertyCollectionNode = Undefined, 
	CollectionObject = Undefined, PredefinedItemName = Undefined, Val ExportRefOnly = False, 
	TempFileList = Undefined)
	
	Var KeyAndValue, ExtDimensionType, ExtDimensions, ExtDimensionTypeOCRName, ExtDimensionNode; //for correct handler execution
	
	If PropertyCollectionNode = Undefined Then
		
		PropertyCollectionNode = Target;
		
	EndIf;
	
	// Exporting the predefined item name if it is specified
	If PredefinedItemName <> Undefined Then
		
		PropertyCollectionNode.WriteStartElement("Property");
		SetAttribute(PropertyCollectionNode, "Name", "{PredefinedItemName}");
		If Not ExecuteDataExchangeInOptimizedFormat Then
			SetAttribute(PropertyCollectionNode, "Type", "String");
		EndIf;
		deWriteElement(PropertyCollectionNode, "Value", PredefinedItemName);
		PropertyCollectionNode.WriteEndElement();		
		
	EndIf;
		
	For Each PCR In PCRCollection Do
		
		If PCR.SimplifiedPropertyExport Then
						
			 //	Creating the property node
			 
			PropertyCollectionNode.WriteStartElement("Property");
			SetAttribute(PropertyCollectionNode, "Name", PCR.Target);
			
			If Not ExecuteDataExchangeInOptimizedFormat
				And Not IsBlankString(PCR.TargetType) Then
			
				SetAttribute(PropertyCollectionNode, "Type", PCR.TargetType);
				
			EndIf;
			
			If PCR.DontReplace Then
				
				SetAttribute(PropertyCollectionNode, "DontReplace",	"true");
				
			EndIf;
			
			If PCR.SearchByEqualDate  Then
				
				SetAttribute(PropertyCollectionNode, "SearchByEqualDate", "true");
				
			EndIf;
			
			Value = Undefined;
			GetPropertyValue(Value, CollectionObject, OCR, PCR, IncomingData, Source);
			
			If PCR.CastToLength <> 0 Then
				
				CastValueToLength(Value, PCR);
								
			EndIf;
			
			IsNULL = False;
			Empty = deEmpty(Value, IsNULL);
						
			If Empty Then
				
				// Writing the empty value
				If Not ExecuteDataExchangeInOptimizedFormat Then
					deWriteElement(PropertyCollectionNode, "Empty");
				EndIf;
				
				PropertyCollectionNode.WriteEndElement();
				Continue;
				
			EndIf;
			
			deWriteElement(PropertyCollectionNode,	"Value", Value);
			
			PropertyCollectionNode.WriteEndElement();
			Continue;	
			
		ElsIf PCR.TargetKind = "AccountExtDimensionTypes" Then
			
			_ExportExtDimension(Source, Target, IncomingData, OutgoingData, OCR, 
		 		       PCR, PropertyCollectionNode, CollectionObject, ExportRefOnly);
				
			
			Continue;
			
		ElsIf PCR.Name = "{UUID}" 
			And PCR.Source = "{UUID}" 
			And PCR.Target = "{UUID}" Then
			
			Try
				
				UUID = Source.UUID();
				
			Except
				
				Try
					
					UUID = Source.Ref.UUID();
					
				Except
					
					Continue;
					
				EndTry;
				
			EndTry;
			
			PropertyCollectionNode.WriteStartElement("Property");
			SetAttribute(PropertyCollectionNode, "Name", "{UUID}");
			
			If Not ExecuteDataExchangeInOptimizedFormat Then 
				SetAttribute(PropertyCollectionNode, "Type", "String");
			EndIf;
			
			deWriteElement(PropertyCollectionNode, "Value", UUID);
			PropertyCollectionNode.WriteEndElement();
			Continue;
			
		ElsIf PCR.IsFolder Then
			
			ExportPropertyGroup(Source, Target, IncomingData, OutgoingData, OCR, PCR, PropertyCollectionNode, ExportRefOnly, TempFileList);
			Continue;
			
		EndIf;

		
		//	Initializing the value to be converted
		Value        = Undefined;
		OCRName      = PCR.ConversionRule;
		DontReplace = PCR.DontReplace;
		
		Empty        = False;
		Expression   = Undefined;
		TargetType   = PCR.TargetType;
 
		IsNULL      = False;


		
		// BeforeExport handler
		If PCR.HasBeforeExportHandler Then
			
			Cancel = False;
			
			Try
				
				If HandlerDebugModeFlag Then
					
					Execute(GetHandlerCallString(PCR, "BeforeExport"));
					
				Else
					
					Execute(PCR.BeforeExport);
					
				EndIf;
				
			Except
				
				WriteErrorInfoPCRHandlers(55, ErrorDescription(), OCR, PCR, Source, 
						"BeforeExportProperty", Value);
														
			EndTry;
				                             
			If Cancel Then	//	Canceling property export
				
				Continue;
				
			EndIf;
			
		EndIf;

        		
   //	Creating the property node
		If IsBlankString(PCR.ParameterForTransferName) Then
			
			PropertyNode = CreateNode("Property");
			SetAttribute(PropertyNode, "Name", PCR.Target);
			
		Else
			
			PropertyNode = CreateNode("ParameterValue");
			SetAttribute(PropertyNode, "Name", PCR.ParameterForTransferName);
			
		EndIf;
		
		If DontReplace Then
			
			SetAttribute(PropertyNode, "DontReplace",	"true");
			
		EndIf;
		
		If PCR.SearchByEqualDate  Then
			
			SetAttribute(PropertyCollectionNode, "SearchByEqualDate", "true");
			
		EndIf;

        		
		//	Perhaps, the conversion rule is already defined
		If Not IsBlankString(OCRName) Then
			
			PropertyOCR = Rules[OCRName];
			
		Else
			
			PropertyOCR = Undefined;
			
		EndIf;


		//	Attempting to define the target property type
		If IsBlankString(TargetType)	And PropertyOCR <> Undefined Then
			
			TargetType = PropertyOCR.Target;
			SetAttribute(PropertyNode, "Type", TargetType);
			
		ElsIf Not ExecuteDataExchangeInOptimizedFormat 
			And Not IsBlankString(TargetType) Then
			
			SetAttribute(PropertyNode, "Type", TargetType);
						
		EndIf;
		
		If Not IsBlankString(OCRName)
			And PropertyOCR <> Undefined
			And PropertyOCR.HasSearchFieldSequenceHandler = True Then
			
			SetAttribute(PropertyNode, "OCRName", OCRName);
			
		EndIf;
		
		If Expression <> Undefined Then
			
			deWriteElement(PropertyNode, "Expression", Expression);
			AddSubordinateNode(PropertyCollectionNode, PropertyNode);
			Continue;
			
		ElsIf Empty Then
			
			If IsBlankString(TargetType) Then
				
				Continue;
				
			EndIf;
			
			If Not ExecuteDataExchangeInOptimizedFormat Then 
				deWriteElement(PropertyNode, "Empty");
			EndIf;
			
			AddSubordinateNode(PropertyCollectionNode, PropertyNode);
			Continue;
			
		Else
			
			GetPropertyValue(Value, CollectionObject, OCR, PCR, IncomingData, Source);
			
			If PCR.CastToLength <> 0 Then
				
				CastValueToLength(Value, PCR);
								
			EndIf;
						
		EndIf;


		OldValueBeforeOnExportHandler = Value;
		Empty = deEmpty(Value, IsNULL);

		
		// OnExport handler
		If PCR.HasOnExportHandler Then
			
			Cancel = False;
			
			Try
				
				If HandlerDebugModeFlag Then
					
					Execute(GetHandlerCallString(PCR, "OnExport"));
					
				Else
					
					Execute(PCR.OnExport);
					
				EndIf;
				
			Except
				
				WriteErrorInfoPCRHandlers(56, ErrorDescription(), OCR, PCR, Source, 
						"OnExportProperty", Value);
														
			EndTry;
				
			If Cancel Then	//	Canceling property export
				
				Continue;
				
			EndIf;
			
		EndIf;


		// Initializing the Empty variable one more time, perhaps its value has been changed in the OnExport handler
		If OldValueBeforeOnExportHandler <> Value Then
			
			Empty = deEmpty(Value, IsNULL);
			
		EndIf;

		If Empty Then
			
			If IsNULL 
				Or Value = Undefined Then
				
				Continue;
				
			EndIf;
			
			If IsBlankString(TargetType) Then
				
				TargetType = GetDataTypeForTarget(Value);
				
				If Not IsBlankString(TargetType) Then				
				
					SetAttribute(PropertyNode, "Type", TargetType);
				
				EndIf;
				
			EndIf;			
				
			// If it is a variable of multiple type, it must be exported with the specified type, perhaps this is an empty reference
			If Not ExecuteDataExchangeInOptimizedFormat Then
				deWriteElement(PropertyNode, "Empty");
			EndIf;
			
			AddSubordinateNode(PropertyCollectionNode, PropertyNode);
			Continue;
			
		EndIf;

      		
		RefNode = Undefined;
		
		If (PropertyOCR <> Undefined) 
			Or (Not IsBlankString(OCRName)) Then
			
			RefNode = ExportRefObjectData(Value, OutgoingData, OCRName, PropertyOCR, TargetType, PropertyNode, ExportRefOnly);
			
			If RefNode = Undefined Then
				Continue;				
			EndIf;				
										
		Else
			
			PropertySet = False;
			ValueType = TypeOf(Value);
			AddPropertyValueToNode(Value, ValueType, TargetType, PropertyNode, PropertySet);
						
			If Not PropertySet Then
				
				ValueManager = Managers[ValueType];
				
				If ValueManager = Undefined Then
					Continue;
				EndIf;
				
				PropertyOCR = ValueManager.OCR;
				
				If PropertyOCR = Undefined Then
					Continue;
				EndIf;
				
				OCRName = PropertyOCR.Name;
				
				RefNode = ExportRefObjectData(Value, OutgoingData, OCRName, PropertyOCR, TargetType, PropertyNode, ExportRefOnly);
			
				If RefNode = Undefined Then
					Continue;				
				EndIf;				
												
			EndIf;
			
		EndIf;


		
		// AfterExport handler

		If PCR.HasAfterExportHandler Then
			
			Cancel = False;
			
			Try
				
				If HandlerDebugModeFlag Then
					
					Execute(GetHandlerCallString(PCR, "AfterExport"));
					
				Else
					
					Execute(PCR.AfterExport);
					
				EndIf;
				
			Except
				
				WriteErrorInfoPCRHandlers(57, ErrorDescription(), OCR, PCR, Source, 
						"AfterExportProperty", Value);					
				
			EndTry;
				
			If Cancel Then	//	Canceling property export
				
				Continue;
				
			EndIf;
			
		EndIf;

		
		AddSubordinateNode(PropertyCollectionNode, PropertyNode);
		
	EndDo;		//	by PCR

EndProcedure

// Exports the object according to the specified conversion rule.
//
// Parameters:
//  Source         - arbitrary data source.
//  Target         - target object XML node.
//  IncomingData   - arbitrary auxiliary data that is passed to rule for performing the
//                   conversion.
//  OutgoingData   - arbitrary auxiliary data that is passed to the conversion property
//                   rules.
//  OCRName        - conversion rule name, according to which the export is executed.
//  RefNode        - target object reference XML node.
//  GetRefNodeOnly - if True is passed, the exchange is not executed but the reference
//                   XML node is generated.
//  OCR            - conversion rule reference.
//
// Returns:
//  Reference XML node or the target value.
//

Function ExportByRule(Source					= Undefined,
						   Target					= Undefined,
						   IncomingData			= Undefined,
						   OutgoingData			= Undefined,
						   OCRName					= "",
						   RefNode				= Undefined,
						   GetRefNodeOnly	= False,
						   OCR						= Undefined,
						   IsRuleWithGlobalObjectExport = False,
						   SelectionForDataExport = Undefined) Export
	
	// Searching for OCR
	If OCR = Undefined Then
		
		OCR = FindRule(Source, OCRName);
		
	ElsIf (Not IsBlankString(OCRName))
		And OCR.Name <> OCRName Then
		
		OCR = FindRule(Source, OCRName);
				
	EndIf;	
	
	If OCR = Undefined Then
		
		LR = GetLogRecordStructure(45);
		
		LR.Object = Source;
		Try
			LR.ObjectType = TypeOf(Source);
		Except
		EndTry;
		
		WriteToExecutionLog(45, LR, True); // OCR is not found
		Return Undefined;
		
	EndIf;

	If CommentObjectProcessingFlag Then
		
		Try
			SourceToString = String(Source);
		Except
			SourceToString = " ";
		EndTry;
		
		ObjectPresentation = SourceToString + "  (" + TypeOf(Source) + ")";
		
		OCRNameString = " OCR: " + TrimAll(OCRName) + "  (" + TrimAll(OCR.Description) + ")";
		
		StringForUser = ?(GetRefNodeOnly, NStr("en = 'Converting object reference: %1'"), NStr("en = 'Converting object: %1'"));
		StringForUser = SubstituteParametersInString(StringForUser, ObjectPresentation);
		
		CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule + 1;
		
		WriteToExecutionLog(StringForUser + OCRNameString, , False, CurrentNestingLevelExportByRule + 1, 7);
		
	EndIf;
	
	IsRuleWithGlobalObjectExport = ExecuteDataExchangeInOptimizedFormat And OCR.UseQuickSearchOnImport;
 
	RememberExported                 = OCR.RememberExported;
	ExportedObjects                  = OCR.Exported;
	ExportedObjectsOnlyRefs          = OCR.OnlyRefsExported;
	AllObjectsExported               = OCR.AllObjectsExported;
	DontReplaceObjectOnImport        = OCR.DontReplace;
	DontCreateIfNotFound             = OCR.DontCreateIfNotFound;
	OnExchangeObjectByRefSetGIUDOnly = OCR.OnExchangeObjectByRefSetGIUDOnly;


	
	AutonumerationPrefix = "";
	WriteMode            = "";
	PostingMode          = "";
	TempFileList         = Undefined;


  TypeName          = "";
	PropertyStructure = Managers[OCR.Source];
	If PropertyStructure = Undefined Then
		PropertyStructure = Managers[TypeOf(Source)];
	EndIf;
	
	If PropertyStructure <> Undefined Then
		TypeName = PropertyStructure.TypeName;
	EndIf;

	// ExportedDataKey
	
	If (Source <> Undefined) And RememberExported Then
		If TypeName = "InformationRegister" Or TypeName = "Constants" Or IsBlankString(TypeName) Then
			RememberExported = False;
		Else
			ExportedDataKey = ValueToStringInternal(Source);
		EndIf;
	Else
		ExportedDataKey = OCRName;
		RememberExported = False;
	EndIf;
	
	
	// Variable for storing the predefined item name
	PredefinedItemName = Undefined;

	// BeforeObjectConversion global handler
    Cancel = False;	
	If HasBeforeConvertObjectGlobalHandler Then
		
		Try
			
			If HandlerDebugModeFlag Then
				
				Execute(GetHandlerCallString(Conversion, "BeforeObjectConversion"));

			Else
				
				Execute(Conversion.BeforeObjectConversion);
				
			EndIf;
			
		Except
			WriteErrorInfoOCRHandlerExport(64, ErrorDescription(), OCR, Source, NStr("en = 'BeforeObjectConversion (global)'"));
		EndTry;
		
		If Cancel Then	//	Canceling further rule processing
			CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
			Return Target;
		EndIf;
		
	EndIf;
	
	// BeforeExport handler
	If OCR.HasBeforeExportHandler Then
		
		Try
			
			If HandlerDebugModeFlag Then
				
				Execute(GetHandlerCallString(OCR, "BeforeExport"));
				
			Else
				
				Execute(OCR.BeforeExport);
				
			EndIf;
			
		Except
			WriteErrorInfoOCRHandlerExport(41, ErrorDescription(), OCR, Source, "BeforeExportObject");
		EndTry;
		
		If Cancel Then	//	Canceling further rule processing
			CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
			Return Target;
		EndIf;
		
	EndIf;
	
	// Perhaps this data has already been exported
	If Not AllObjectsExported Then
		
		Sn = 0;
		
		If RememberExported Then
			
			RefNode = ExportedObjects[ExportedDataKey];
			If RefNode <> Undefined Then
				
				If GetRefNodeOnly Then
					CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
					Return RefNode;
				EndIf;
				
				ExportedRefNumber = ExportedObjectsOnlyRefs[ExportedDataKey];
				If ExportedRefNumber = Undefined Then
					CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
					Return RefNode;
				Else
					
					ExportStackRow = mDataExportCallStack.Find(ExportedDataKey, "Ref");
				
					If ExportStackRow <> Undefined Then
						CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
						Return RefNode;
					EndIf;
					
					ExportStackRow = mDataExportCallStack.Add();
					ExportStackRow.Ref = ExportedDataKey;
					
					Sn = ExportedRefNumber;
				EndIf;
			EndIf;
			
		EndIf;
		
		If Sn = 0 Then
			
			mSnCounter = mSnCounter + 1;
			Sn         = mSnCounter;
			
		EndIf;
		
		// Preventing cyclic reference existence
		If RememberExported Then
			
			ExportedObjects[ExportedDataKey] = Sn;
			If GetRefNodeOnly Then
				ExportedObjectsOnlyRefs[ExportedDataKey] = Sn;
			Else
				
				ExportStackRow = mDataExportCallStack.Add();
				ExportStackRow.Ref = ExportedDataKey;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	ValueMap = OCR.Values;
	ValueMapItemCount = ValueMap.Count();
	
	// Predefined item map processing
	If TargetPlatform = "V8" Then
		
		// If the name of predefined item is not defined yet, attempting to define it
		If PredefinedItemName = Undefined Then
			
			If PropertyStructure <> Undefined
				And ValueMapItemCount > 0
				And PropertyStructure.SearchByPredefinedPossible Then
			
				Try
					PredefinedNameSource = PredefinedName(Source);
				Except
					PredefinedNameSource = "";
				EndTry;
				
			Else
				
				PredefinedNameSource = "";
				
			EndIf;
			
			If Not IsBlankString(PredefinedNameSource)
				And ValueMapItemCount > 0 Then
				
				PredefinedItemName = ValueMap[Source];
				
			Else
				PredefinedItemName = Undefined;
			EndIf;
			
		EndIf;
		
		If PredefinedItemName <> Undefined Then
			ValueMapItemCount = 0;
		EndIf;
		
	Else
		PredefinedItemName = Undefined;
	EndIf;
	
	DontExportByValueMap = (ValueMapItemCount = 0);
	
	If Not DontExportByValueMap Then
		
		// If value mapping does not contain values, exporting mapping in the ordinary way
		RefNode = ValueMap[Source];
		If RefNode = Undefined
			And OCR.SearchProperties.Count() > 0 Then
			
			// Perhaps, this is a conversion from enumeration into enumeration and required VCR
			// is not found. Exporting the empty reference.

			If PropertyStructure.TypeName = "Enum"
				And Find(OCR.Target, "EnumRef.") > 0 Then
				
				RefNode = "";
				
			Else
						
				DontExportByValueMap = True;	
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	MustRememberObject = RememberExported And (Not AllObjectsExported);

	If DontExportByValueMap Then
		
		If OCR.SearchProperties.Count() > 0 
			Or PredefinedItemName <> Undefined Then
			
			//	Creating reference node
			RefNode = CreateNode("Ref");
			
			If MustRememberObject Then
				
				If IsRuleWithGlobalObjectExport Then
					SetAttribute(RefNode, "GSn", Sn);
				Else
					SetAttribute(RefNode, "Sn", Sn);
				EndIf;
				
			EndIf;
			
			ExportRefOnly = OCR.DontExportPropertyObjectsByRefs Or GetRefNodeOnly;
			
			If DontCreateIfNotFound Then
				SetAttribute(RefNode, "DontCreateIfNotFound", DontCreateIfNotFound);
			EndIf;
			
			If OnExchangeObjectByRefSetGIUDOnly Then
				SetAttribute(RefNode, "OnExchangeObjectByRefSetGIUDOnly", OnExchangeObjectByRefSetGIUDOnly);
			EndIf;
			
			ExportProperties(Source, Target, IncomingData, OutgoingData, OCR, OCR.SearchProperties, 
				RefNode, SelectionForDataExport, PredefinedItemName, OCR.DontExportPropertyObjectsByRefs Or GetRefNodeOnly);
			
			RefNode.WriteEndElement();
			RefNode = RefNode.Close();
			
			If MustRememberObject Then
				
				ExportedObjects[ExportedDataKey] = RefNode;
				
			EndIf;
			
		Else
			RefNode = Sn;
		EndIf;
		
	Else
		
		// Searching in the value map by VCR
		If RefNode = Undefined Then
			// Nothing found in the value map, attempting to find by the search properties
			RecordStructure = New Structure("Source,SourceType", Source, TypeOf(Source));
			WriteToExecutionLog(71, RecordStructure);
			If ExportStackRow <> Undefined Then
				mDataExportCallStack.Delete(ExportStackRow);
			EndIf;
			CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
			Return Undefined;
		EndIf;
		
		If RememberExported Then
			ExportedObjects[ExportedDataKey] = RefNode;
		EndIf;
		
		If ExportStackRow <> Undefined Then
			mDataExportCallStack.Delete(ExportStackRow);
		EndIf;
		CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
		Return RefNode;
		
	EndIf;
	
	If GetRefNodeOnly Or AllObjectsExported Then
	
		If ExportStackRow <> Undefined Then
			mDataExportCallStack.Delete(ExportStackRow);
		EndIf;
		CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
		Return RefNode;
		
	EndIf;

	If Target = Undefined Then
		
		Target = CreateNode("Object");
		
		If IsRuleWithGlobalObjectExport Then
			SetAttribute(Target, "GSn", Sn);
		Else
			SetAttribute(Target, "Sn",	Sn);
		EndIf;
		
		SetAttribute(Target, "Type", 			OCR.Target);
		SetAttribute(Target, "RuleName",	OCR.Name);
		
		If DontReplaceObjectOnImport Then
			SetAttribute(Target, "DontReplace",	"true");
		EndIf;
		
		If Not IsBlankString(AutonumerationPrefix) Then
			SetAttribute(Target, "AutonumerationPrefix",	AutonumerationPrefix);
		EndIf;
		
		If Not IsBlankString(WriteMode) Then
			SetAttribute(Target, "WriteMode",	WriteMode);
			If Not IsBlankString(PostingMode) Then
				SetAttribute(Target, "PostingMode",	PostingMode);
			EndIf;
		EndIf;
		
		If TypeOf(RefNode) <> deNumberType Then
			AddSubordinateNode(Target, RefNode);
		EndIf; 
		
	EndIf;

	// OnExport handler
	StandardProcessing = True;
	Cancel = False;
	
	If OCR.HasOnExportHandler Then
		
		Try
			
			If HandlerDebugModeFlag Then
				
				Execute(GetHandlerCallString(OCR, "OnExport"));
				
			Else
				
				Execute(OCR.OnExport);
				
			EndIf;
			
		Except
			WriteErrorInfoOCRHandlerExport(42, ErrorDescription(), OCR, Source, "OnExportObject");
		EndTry;
		
		If Cancel Then	//	Canceling writing the object to a file
			If ExportStackRow <> Undefined Then
				mDataExportCallStack.Delete(ExportStackRow);
			EndIf;
			CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
			Return RefNode;
		EndIf;
		
	EndIf;

	// Exporting properties
	If StandardProcessing Then
		
		ExportProperties(Source, Target, IncomingData, OutgoingData, OCR, OCR.Properties, , SelectionForDataExport, ,
			OCR.DontExportPropertyObjectsByRefs Or GetRefNodeOnly, TempFileList);
			
	EndIf;
	
	// AfterExport handler
	If OCR.HasAfterExportHandler Then
		
		Try
			
			If HandlerDebugModeFlag Then
				
				Execute(GetHandlerCallString(OCR, "AfterExport"));
				
			Else
				
				Execute(OCR.AfterExport);
				
			EndIf;
			
		Except
			WriteErrorInfoOCRHandlerExport(43, ErrorDescription(), OCR, Source, "AfterExportObject");
		EndTry;
		
		If Cancel Then	//	Canceling writing the object to a file
			
			If ExportStackRow <> Undefined Then
				mDataExportCallStack.Delete(ExportStackRow);
			EndIf;
			CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
			Return RefNode;
			
		EndIf;
		
	EndIf;
	
	If TempFileList = Undefined Then
	
		//	Writing the object to a file
		Target.WriteEndElement();
		WriteToFile(Target);
		
	Else
		
		WriteToFile(Target);
		
		TempFile = New TextReader;
		For Each TempFileName In TempFileList Do
			
			Try
				TempFile.Open(TempFileName, TextEncoding.UTF8);
			Except
				Continue;
			EndTry;
			
			TempFileLine = TempFile.ReadLine();
			While TempFileLine <> Undefined Do
				WriteToFile(TempFileLine);	
				TempFileLine = TempFile.ReadLine();
			EndDo;
			
			TempFile.Close();
			
			// Deleting files
			Try
				DeleteFiles(TempFileName); 
			Except				
			EndTry;
			
		EndDo;
		
		WriteToFile("</Object>");
		
	EndIf;
	
	mExportedObjectCounter = 1 + mExportedObjectCounter;
	
	If MustRememberObject Then
				
		If IsRuleWithGlobalObjectExport Then
			ExportedObjects[ExportedDataKey] = Sn;
		EndIf;
		
	EndIf;
	
	If ExportStackRow <> Undefined Then
		mDataExportCallStack.Delete(ExportStackRow);
	EndIf;
	
	CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
	
	// AfterExportToFile handler
	If OCR.HasAfterExportToFileHandler Then
		
		Try
			
			If HandlerDebugModeFlag Then
				
				Execute(GetHandlerCallString(OCR, "AfterExportToFile"));
				
			Else
				
				Execute(OCR.AfterExportToFile);
				
			EndIf;
			
		Except
			WriteErrorInfoOCRHandlerExport(76, ErrorDescription(), OCR, Source, "HasAfterExportToFileHandler");
		EndTry;				
				
	EndIf;	
	
	Return RefNode;

EndFunction	//	ExportByRule()

// Exports the selection item according to the specified rule.
//
// Parameters:
//  Object       - selection item to be exported.
//  Rule         - data export rule reference.
//  Properties   - metadata object properties of the object to be exported. 
//  IncomingData - arbitrary auxiliary data.
//
 
Procedure SelectionItemExport(Object, Rule, Properties=Undefined, IncomingData=Undefined, SelectionForDataExport = Undefined)

	If CommentObjectProcessingFlag Then
		
		Try
			ObjectPresentation   = String(Object) + "  (" + TypeOf(Object) + ")";			
		Except
			ObjectPresentation   = TypeOf(Object);
		EndTry;
		
		MessageString = SubstituteParametersInString(NStr("en = 'Exporting object: %1'"), ObjectPresentation);
		WriteToExecutionLog(MessageString, , False, 1, 7);
		
	EndIf;
	
	OCRName			 = Rule.ConversionRule;
	Cancel       = False;
	OutgoingData = Undefined;
	
	// BeforeExportObject global handler
	If HasBeforeExportObjectGlobalHandler Then
		
		Try
			
			If HandlerDebugModeFlag Then
				
				Execute(GetHandlerCallString(Conversion, "BeforeExportObject"));
				
			Else
				
				Execute(Conversion.BeforeExportObject);
				
			EndIf;
			
		Except
			WriteErrorInfoDERHandlers(65, ErrorDescription(), Rule.Name, NStr("en = 'BeforeExportSelectionObject (global)'"), Object);
		EndTry;
			
		If Cancel Then
			Return;
		EndIf;
		
	EndIf;
	
	// BeforeExport handler
	If Not IsBlankString(Rule.BeforeExport) Then
		
		Try
			
			If HandlerDebugModeFlag Then
				
				Execute(GetHandlerCallString(Rule, "BeforeExport"));
				
			Else
				
				Execute(Rule.BeforeExport);
				
			EndIf;
			
		Except
			WriteErrorInfoDERHandlers(33, ErrorDescription(), Rule.Name, "BeforeExportSelectionObject", Object);
		EndTry;
		
		If Cancel Then
			Return;
		EndIf;
		
	EndIf;
	
	RefNode = Undefined;
	
	ExportByRule(Object, , OutgoingData, , OCRName, RefNode, , , , SelectionForDataExport);
	
	// AfterExportObject global handler
	If HasAfterExportObjectGlobalHandler Then
		
		Try
			
			If HandlerDebugModeFlag Then
				
				Execute(GetHandlerCallString(Conversion, "AfterExportObject"));
				
			Else
				
				Execute(Conversion.AfterExportObject);
			
			EndIf;
			
		Except
			WriteErrorInfoDERHandlers(69, ErrorDescription(), Rule.Name, NStr("en = 'AfterExportSelectionObject (global)'"), Object);
		EndTry;
		
	EndIf;
	
	// AfterExport handler
	If Not IsBlankString(Rule.AfterExport) Then
		
		Try
			
			If HandlerDebugModeFlag Then
				
				Execute(GetHandlerCallString(Rule, "AfterExport"));
				
			Else
				
				Execute(Rule.AfterExport);
				
			EndIf;
			
		Except
			WriteErrorInfoDERHandlers(34, ErrorDescription(), Rule.Name, "AfterExportSelectionObject", Object);
		EndTry;
		
	EndIf;
	
EndProcedure

Function GetFirstMetadataAttributeName(ObjectMetadata)
	
	Try
		Return ObjectMetadata.Attributes[0].Name;
	Except   	
		Return "";
	EndTry;
	
EndFunction

// Returns a query language text fragment that contains restriction by date.
//
Function GetRestrictionByDateStringForQuery(Properties, TypeName, TableGroupName = "", SelectionForDataClearing = False) Export
	
	ResultingDateRestriction = "";
	
	If Not (TypeName = "Document" Or TypeName = "InformationRegister") Then
		Return ResultingDateRestriction;
	EndIf;
	
	If TypeName = "InformationRegister" Then
		
		Nonperiodical = Not Properties.Periodical;
		RestrictionByDateNotRequired = SelectionForDataClearing	Or Nonperiodical;
		
		If RestrictionByDateNotRequired Then
			Return ResultingDateRestriction;
		EndIf;
				
	EndIf;	
	
	If IsBlankString(TableGroupName) Then
		RestrictionFieldName = ?(TypeName = "Document", "Date", "Period");
	Else
		RestrictionFieldName = TableGroupName + "." + ?(TypeName = "Document", "Date", "Period");
	EndIf;
	
	If StartDate <> EmptyDateValue Then
		
		ResultingDateRestriction = "
		|	WHERE
		|		" + RestrictionFieldName + " >= &StartDate";
		
	EndIf;
		
	If EndDate <> EmptyDateValue Then
		
		If IsBlankString(ResultingDateRestriction) Then
			
			ResultingDateRestriction = "
			|	WHERE
			|		" + RestrictionFieldName + " <= &EndDate";
			
		Else
			
			ResultingDateRestriction = ResultingDateRestriction + "
			|	And
			|		" + RestrictionFieldName + " <= &EndDate";
			
		EndIf;
		
	EndIf;
	
	Return ResultingDateRestriction;
	
EndFunction

// Generates a query result for exporting the data clearing.
//
Function GetQueryResultForExportDataClearing(Properties, TypeName, 
	SelectionForDataClearing = False, DeleteObjectsDirectly = False, SelectAllFields = True) Export 
	
	PermissionRow = ?(ExportAllowedOnly, " ALLOWED ", "");
			
	FieldSelectionString = ?(SelectAllFields, " * ", "	ObjectForExport.Ref AS Ref ");
	
	If TypeName = "Catalog" 
		Or TypeName = "ChartOfCharacteristicTypes" 
		Or TypeName = "ChartOfAccounts" 
		Or TypeName = "ChartOfCalculationTypes" 
		Or TypeName = "AccountingRegister"
		Or TypeName = "ExchangePlan"
		Or TypeName = "Task"
		Or TypeName = "BusinessProcess" Then
		
		Query = New Query();
		
		If TypeName = "Catalog" Then
			ObjectMetadata = Metadata.Catalogs[Properties.Name];
		ElsIf TypeName = "ChartOfCharacteristicTypes" Then
		    ObjectMetadata = Metadata.ChartsOfCharacteristicTypes[Properties.Name];			
		ElsIf TypeName = "ChartOfAccounts" Then
		    ObjectMetadata = Metadata.ChartsOfAccounts[Properties.Name];
		ElsIf TypeName = "ChartOfCalculationTypes" Then
		    ObjectMetadata = Metadata.ChartsOfCalculationTypes[Properties.Name];
		ElsIf TypeName = "AccountingRegister" Then
		    ObjectMetadata = Metadata.AccountingRegisters[Properties.Name];
		ElsIf TypeName = "ExchangePlan" Then
		    ObjectMetadata = Metadata.ExchangePlans[Properties.Name];
		ElsIf TypeName = "Task" Then
		    ObjectMetadata = Metadata.Tasks[Properties.Name];
		ElsIf TypeName = "BusinessProcess" Then
		    ObjectMetadata = Metadata.BusinessProcesses[Properties.Name];			
		EndIf;
		
		If TypeName = "AccountingRegister" Then
			
			FieldSelectionString = "*";
			SelectionTableName = Properties.Name + ".RecordsWithExtDimensions";
			
		Else
			
			SelectionTableName = Properties.Name;	
			
			If ExportAllowedOnly
				And Not SelectAllFields Then
				
				FirstAttributeName = GetFirstMetadataAttributeName(ObjectMetadata);
				If Not IsBlankString(FirstAttributeName) Then
					FieldSelectionString = FieldSelectionString + ", ObjectForExport." + FirstAttributeName;
				EndIf;
				
			EndIf;
			
		EndIf;
		
		Query.Text = "SELECT " + PermissionRow + "
		         |	" + FieldSelectionString + "
		         |FROM
		         |	" + TypeName + "." + SelectionTableName + " AS ObjectForExport
				 |
				 |";
		
	ElsIf TypeName = "Document" Then
		
		If ExportAllowedOnly Then
			
			FirstAttributeName = GetFirstMetadataAttributeName(Metadata.Documents[Properties.Name]);
			If Not IsBlankString(FirstAttributeName) Then
				FieldSelectionString = FieldSelectionString + ", ObjectForExport." + FirstAttributeName;
			EndIf;
			
		EndIf;
		
		ResultingDateRestriction = GetRestrictionByDateStringForQuery(Properties, TypeName, "ObjectForExport", SelectionForDataClearing);
		
		Query = New Query();
		
		Query.SetParameter("StartDate", StartDate);
		Query.SetParameter("EndDate", EndDate);
		
		Query.Text = "SELECT " + PermissionRow + "
		         |	" + FieldSelectionString + "
		         |FROM
		         |	" + TypeName + "." + Properties.Name + " AS ObjectForExport
				 |
				 |" + ResultingDateRestriction;
					 
											
	ElsIf TypeName = "InformationRegister" Then
		
		Nonperiodical = Not Properties.Periodical;
		SubordinatedToRecorder = Properties.SubordinatedToRecorder;		
		
		ResultingDateRestriction = GetRestrictionByDateStringForQuery(Properties, TypeName, "ObjectForExport", SelectionForDataClearing);
						
		Query = New Query();
		
		Query.SetParameter("StartDate", StartDate);
		Query.SetParameter("EndDate", EndDate);
		
		SelectionFieldSupplementionStringSubordinateToRegistrar = ?(Not SubordinatedToRecorder, ", NULL AS Active,
		|	NULL AS Recorder,
		|	NULL AS LineNumber", "");
		
		SelectionFieldSupplementionStringPeriodicity = ?(Nonperiodical, ", NULL AS Period", "");
		
		Query.Text = "SELECT " + PermissionRow + "
		         |	*
				 |
				 | " + SelectionFieldSupplementionStringSubordinateToRegistrar + "
				 | " + SelectionFieldSupplementionStringPeriodicity + "
				 |
		         |FROM
		         |	" + TypeName + "." + Properties.Name + " AS ObjectForExport
				 |
				 |" + ResultingDateRestriction;
		
	Else
		
		Return Undefined;
					
	EndIf;	
	
	Return Query.Execute();
	
EndFunction

// Generates a selection for exporting the data clearing.
//
Function GetSelectionForDataClearingExport(Properties, TypeName, 
	SelectionForDataClearing = False, DeleteObjectsDirectly = False, SelectAllFields = True) Export
	
	QueryResult = GetQueryResultForExportDataClearing(Properties, TypeName, 
			SelectionForDataClearing, DeleteObjectsDirectly, SelectAllFields);
			
	If QueryResult = Undefined Then
		Return Undefined;
	EndIf;
			
	Selection = QueryResult.Select();
	
	Return Selection;
	
EndFunction

Function GetSelectionForExportWithRestrictions(Rule, SelectionForSubstitutionToOCR = Undefined, Properties = Undefined)
	
	MetadataName           = Rule.ObjectForQueryName;
	
	PermissionRow = ?(ExportAllowedOnly, " ALLOWED ", "");
	
	SelectionFields = "";
	
	IsRegisterExport = (Rule.ObjectForQueryName = Undefined);
	
	If IsRegisterExport Then
		
		Nonperiodical = Not Properties.Periodical;
		SubordinatedToRecorder = Properties.SubordinatedToRecorder;
		
		SelectionFieldSupplementionStringSubordinateToRegistrar = ?(Not SubordinatedToRecorder, ", NULL AS Active,
		|	NULL AS Recorder,
		|	NULL AS LineNumber", "");
		
		SelectionFieldSupplementionStringPeriodicity = ?(Nonperiodical, ", NULL AS Period", "");
		
		ResultingDateRestriction = GetRestrictionByDateStringForQuery(Properties, Properties.TypeName, Rule.ObjectNameForRegisterQuery, False);
		
		ReportBuilder.Text = "SELECT " + PermissionRow + "
		         |	*
				 |
				 | " + SelectionFieldSupplementionStringSubordinateToRegistrar + "
				 | " + SelectionFieldSupplementionStringPeriodicity + "
				 |
				 | FROM " + Rule.ObjectNameForRegisterQuery + "
				 |
				 |" + ResultingDateRestriction;		
				 
		ReportBuilder.FillSettings();
				
	Else
		
		If Rule.SelectExportDataInSingleQuery Then
		
			// Selecting all object fields
			SelectionFields = "*";
			
		Else
			
			SelectionFields = "Ref AS Ref";
			
		EndIf;
		
		ResultingDateRestriction = GetRestrictionByDateStringForQuery(Properties, Properties.TypeName,, False);
		
		ReportBuilder.Text = "SELECT " + PermissionRow + " " + SelectionFields + " FROM " + MetadataName + "
		|
		|" + ResultingDateRestriction + "
		|
		|{WHERE Ref.* AS " + StrReplace(MetadataName, ".", "_") + "}";
		
	EndIf;
	
	ReportBuilder.Filter.Reset();
	If Rule.BuilderSettings <> Undefined Then
		ReportBuilder.SetSettings(Rule.BuilderSettings);
	EndIf;
	
	ReportBuilder.Parameters.Insert("StartDate", StartDate);
	ReportBuilder.Parameters.Insert("EndDate", EndDate);

	ReportBuilder.Execute();
	Selection = ReportBuilder.Result.Select();
	
	If Rule.SelectExportDataInSingleQuery Then
		SelectionForSubstitutionToOCR = Selection;
	EndIf;
		
	Return Selection;
		
EndFunction

Function GetExportWithArbitraryAlgorithmSelection(DataSelection)
	
	Selection = Undefined;
	
	SelectionType = TypeOf(DataSelection);
			
	If SelectionType = Type("QueryResultSelection") Then
				
		Selection = DataSelection;
		
	ElsIf SelectionType = Type("QueryResult") Then
				
		Selection = DataSelection.Select();
					
	ElsIf SelectionType = Type("Query") Then
				
		QueryResult = DataSelection.Execute();
		Selection   = QueryResult.Select();
									
	EndIf;
		
	Return Selection;	
	
EndFunction

Function GetConstantSetRowForExport(ConstantDataTableForExport)
	
	ConstantSetString = "";
	
	For Each TableRow In ConstantDataTableForExport Do
		
		If Not IsBlankString(TableRow.Source) Then
		
			ConstantSetString = ConstantSetString + ", " + TableRow.Source;
			
		EndIf;
		
	EndDo;	
	
	If Not IsBlankString(ConstantSetString) Then
		
		ConstantSetString = Mid(ConstantSetString, 3);
		
	EndIf;
	
	Return ConstantSetString;
	
EndFunction

Procedure ExportConstantsSet(Rule, Properties, OutgoingData)
	
	If Properties.OCR <> Undefined Then
	
		ConstantSetNameString = GetConstantSetRowForExport(Properties.OCR.Properties);
		
	Else
		
		ConstantSetNameString = "";
		
	EndIf;
			
	ConstantsSet = Constants.CreateSet(ConstantSetNameString);
	ConstantsSet.Read();
	SelectionItemExport(ConstantsSet, Rule, Properties, OutgoingData);	
	
EndProcedure

Function MustSelectAllFields(Rule)
	
	AllFieldsRequiredForSelection = Not IsBlankString(Conversion.BeforeExportObject)
		Or Not IsBlankString(Rule.BeforeExport)
		Or Not IsBlankString(Conversion.AfterExportObject)
		Or Not IsBlankString(Rule.AfterExport);		
		
	Return AllFieldsRequiredForSelection;	
	
EndFunction

// Exports data by the specified rule.
//
// Parameters:
//  Rule - data export rule reference.
// 
Procedure ExportDataByRule(Rule)
	
	OCRName = Rule.ConversionRule;
	
	If Not IsBlankString(OCRName) Then
		
		OCR = Rules[OCRName];
		
	EndIf;
	
	If CommentObjectProcessingFlag Then
		
		MessageString = SubstituteParametersInString(NStr("en = 'Data export rule: %1 (%2)'"), TrimAll(Rule.Name), TrimAll(Rule.Description));
		WriteToExecutionLog(MessageString, , False, , 4);
		
	EndIf;
	
	// BeforeProcess handle
	Cancel        = False;
	OutgoingData  = Undefined;
	DataSelection = Undefined;
	
	If Not IsBlankString(Rule.BeforeProcess) Then
	
		Try
			
			If HandlerDebugModeFlag Then
				
				Execute(GetHandlerCallString(Rule, "BeforeProcess"));
				
			Else
				
				Execute(Rule.BeforeProcess);
				
			EndIf;
			
		Except
			
			WriteErrorInfoDERHandlers(31, ErrorDescription(), Rule.Name, "BeforeProcessDataExport");
			
		EndTry;
		
		If Cancel Then
			
			Return;
			
		EndIf;
		
	EndIf;
	
	// Standard selection with filter
	If Rule.DataSelectionVariant = "StandardSelection" And Rule.UseFilter Then
		
		Properties = Managers[Rule.SelectionObject];
		TypeName   = Properties.TypeName;
		
		SelectionForOCR = Undefined;
		Selection = GetSelectionForExportWithRestrictions(Rule, SelectionForOCR, Properties);
		
		IsNotReferenceType = TypeName =  "InformationRegister" Or TypeName = "AccountingRegister";
		
		While Selection.Next() Do
			
			If IsNotReferenceType Then
				SelectionItemExport(Selection, Rule, Properties, OutgoingData);
			Else					
				SelectionItemExport(Selection.Ref, Rule, Properties, OutgoingData, SelectionForOCR);
			EndIf;
			
		EndDo;
		
	// Standard selection without filter
	ElsIf (Rule.DataSelectionVariant = "StandardSelection") Then
		
		Properties = Managers[Rule.SelectionObject];
		TypeName   = Properties.TypeName;
		
		If TypeName = "Constants" Then
			
			ExportConstantsSet(Rule, Properties, OutgoingData);
			
		Else
			
			IsNotReferenceType = TypeName =  "InformationRegister" 
				Or TypeName = "AccountingRegister";
			
			If IsNotReferenceType Then
					
				SelectAllFields = MustSelectAllFields(Rule);
				
			Else
				
				// Getting only the reference
				SelectAllFields = Rule.SelectExportDataInSingleQuery;	
				
			EndIf;
			
			Selection = GetSelectionForDataClearingExport(Properties, TypeName, , , SelectAllFields);
			SelectionForOCR = ?(Rule.SelectExportDataInSingleQuery, Selection, Undefined);
			
			If Selection = Undefined Then
				Return;
			EndIf;
			
			While Selection.Next() Do
				
				If IsNotReferenceType Then
					
					SelectionItemExport(Selection, Rule, Properties, OutgoingData);
					
				Else
					
					SelectionItemExport(Selection.Ref, Rule, Properties, OutgoingData, SelectionForOCR);
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	ElsIf Rule.DataSelectionVariant = "ArbitraryAlgorithm" Then

		If DataSelection <> Undefined Then
			
			Selection = GetExportWithArbitraryAlgorithmSelection(DataSelection);
			
			If Selection <> Undefined Then
				
				While Selection.Next() Do
					
					SelectionItemExport(Selection, Rule, , OutgoingData);
					
				EndDo;
				
			Else
				
				For Each Object In DataSelection Do
					
					SelectionItemExport(Object, Rule, , OutgoingData);
					
				EndDo;
				
			EndIf;
			
		EndIf;
			
	EndIf;

	
	// AfterProcess handler
	
	If Not IsBlankString(Rule.AfterProcess) Then
	
		Try
			
			If HandlerDebugModeFlag Then
				
				Execute(GetHandlerCallString(Rule, "AfterProcess"));
				
			Else
				
				Execute(Rule.AfterProcess);
				
			EndIf;
			
		Except
			
			WriteErrorInfoDERHandlers(32, ErrorDescription(), Rule.Name, "AfterProcessDataExport");
			
		EndTry;
		
	 EndIf;	
	
EndProcedure

// Reviews the data export rule tree and performs the export.
//
// Parameters:
//  Rows - value tree row collection.
//
 
Procedure ProcessExportRules(Rows, ExchangePlanNodesAndExportRowsMap)
	
	For Each ExportRule In Rows Do
		
		If ExportRule.PrivilegedModeOn = 0 Then
			
			Continue;
			
		EndIf; 
		
		If (ExportRule.ExchangeNodeRef <> Undefined 
				And Not ExportRule.ExchangeNodeRef.IsEmpty()) Then
			
			ExportRuleArray = ExchangePlanNodesAndExportRowsMap.Get(ExportRule.ExchangeNodeRef);
			
			If ExportRuleArray = Undefined Then
				
				ExportRuleArray = New Array();	
				
			EndIf;
			
			ExportRuleArray.Add(ExportRule);
			
			ExchangePlanNodesAndExportRowsMap.Insert(ExportRule.ExchangeNodeRef, ExportRuleArray);
			
			Continue;
			
		EndIf;

		If ExportRule.IsFolder Then
			
			ProcessExportRules(ExportRule.Rows, ExchangePlanNodesAndExportRowsMap);
			Continue;
			
		EndIf;
		
		ExportDataByRule(ExportRule);
		
	EndDo; 
	
EndProcedure

Function CopyExportRuleArray(SourceArray)
	
	ResultingArray = New Array();
	
	For Each Item In SourceArray Do
		
		ResultingArray.Add(Item);	
		
	EndDo;
	
	Return ResultingArray;
	
EndFunction

Function FindExportRuleTreeRowByExportType(RowArray, ExportType)
	
	For Each ArrayRow In RowArray Do
		
		If ArrayRow.SelectionObject = ExportType Then
			
			Return ArrayRow;
			
		EndIf;
			
	EndDo;
	
	Return Undefined;
	
EndFunction

Procedure DeleteExportRuleTreeRowByExportTypeFromArray(RowArray, ItemToDelete)
	
	Counter = RowArray.Count() - 1;
	While Counter >= 0 Do
		
		ArrayRow = RowArray[Counter];
		
		If ArrayRow = ItemToDelete Then
			
			RowArray.Delete(Counter);
			Return;
			
		EndIf; 
		
		Counter = Counter - 1;	
		
	EndDo;
	
EndProcedure

Procedure GetExportRuleRowByExchangeObject(Data, LastObjectMetadata, ExportObjectMetadata, 
	LastExportRuleRow, CurrentExportRuleRow, TempConversionRuleArray, ObjectForExportRules, 
	ExportingRegister, ExportingConstants, ConstantsWereExported)
	
	CurrentExportRuleRow = Undefined;
	ObjectForExportRules = Undefined;
	ExportingRegister = False;
	ExportingConstants = False;
	
	If LastObjectMetadata = ExportObjectMetadata
		And LastExportRuleRow = Undefined Then
		
		Return;
		
	EndIf;
	
	DataStructure = ManagersForExchangePlans[ExportObjectMetadata];
	
	If DataStructure = Undefined Then
		
		ExportingConstants = Metadata.Constants.Contains(ExportObjectMetadata);
		
		If ConstantsWereExported 
			Or Not ExportingConstants Then
			
			Return;
			
		EndIf;
		
		// Searching for the rule for constants
		If LastObjectMetadata <> ExportObjectMetadata Then
		
			CurrentExportRuleRow = FindExportRuleTreeRowByExportType(TempConversionRuleArray, Type("ConstantsSet"));
			
		Else
			
			CurrentExportRuleRow = LastExportRuleRow;	
			
		EndIf;
		
		Return;
		
	EndIf;
	
	If DataStructure.IsReferenceType = True Then
						
		If LastObjectMetadata <> ExportObjectMetadata Then
		
			CurrentExportRuleRow = FindExportRuleTreeRowByExportType(TempConversionRuleArray, DataStructure.RefType);
			
		Else
			
			CurrentExportRuleRow = LastExportRuleRow;	
			
		EndIf;
		
		ObjectForExportRules = Data.Ref;
		
	ElsIf DataStructure.IsRegister = True Then
		
		If LastObjectMetadata <> ExportObjectMetadata Then
		
			CurrentExportRuleRow = FindExportRuleTreeRowByExportType(TempConversionRuleArray, DataStructure.RefType);
			
		Else
			
			CurrentExportRuleRow = LastExportRuleRow;	
			
		EndIf;
		
		ObjectForExportRules = Data;
		
		ExportingRegister = True;
		
	EndIf;	
		
EndProcedure

Function ExecuteExchangeNodeChangedDataExport(ExchangeNode, ConversionRuleArray, StructureForChangeRecordDeletion)
	
	StructureForChangeRecordDeletion.Insert("OCRArray", Undefined);
	StructureForChangeRecordDeletion.Insert("MessageNo", Undefined);
	
	XMLWriter = New XMLWriter();
	XMLWriter.SetString();
	
	// Creating a new message
	WriteMessage = ExchangePlans.CreateMessageWriter();
		
	WriteMessage.BeginWrite(XMLWriter, ExchangeNode);
	
	// Counting the number of written objects
	FoundObjectToWriteCount = 0;
	
	// Beginning a transaction
	If UseTransactionsForExchangePlansOnExport Then
		BeginTransaction();
	EndIf;
	
	LastMetadataObject = Undefined;
	LastExportRuleRow = Undefined;
	
	CurrentMetadataObject = Undefined;
	CurrentExportRuleRow  = Undefined;
	
	OutgoingData = Undefined;
	
	TempConversionRuleArray = CopyExportRuleArray(ConversionRuleArray);
	
	Cancel			   = False;
	OutgoingData  = Undefined;
	DataSelection = Undefined;
	
	ObjectForExportRules = Undefined;
	ConstantsWereExported = False;
	
	Try
	
		// Getting a changed data selection
		MetadataToExportArray = New Array();
				
		// Supplementing the array with metadata that have eport rules.
		For Each ExportRuleRow In TempConversionRuleArray Do
			
			DERMetadata = Metadata.FindByType(ExportRuleRow.SelectionObject);
			MetadataToExportArray.Add(DERMetadata);
			
		EndDo;
		
		ChangeSelection = ExchangePlans.SelectChanges(WriteMessage.Recipient, WriteMessage.MessageNo, MetadataToExportArray);
		
		StructureForChangeRecordDeletion.MessageNo = WriteMessage.MessageNo;
		
		While ChangeSelection.Next() Do
					
			Data = ChangeSelection.Get();
			FoundObjectToWriteCount = FoundObjectToWriteCount + 1;
			
			ExportDataType = TypeOf(Data); 
			
			Delete = (ExportDataType = deObjectDeletionType);
			
			// Skipping deletion.
			If Delete Then
				Continue;
			EndIf;
			
			CurrentMetadataObject = Data.Metadata();
			
			// Processing data received from the exchange node.
			// Using this data, determining the conversion rule and exporting data.

			
			ExportingRegister = False;
			ExportingConstants = False;
			
			GetExportRuleRowByExchangeObject(Data, LastMetadataObject, CurrentMetadataObject, 
				LastExportRuleRow, CurrentExportRuleRow, TempConversionRuleArray, ObjectForExportRules, 
				ExportingRegister, ExportingConstants, ConstantsWereExported);
				
				
			If LastMetadataObject <> CurrentMetadataObject Then
				
				
				// After processing data
				If LastExportRuleRow <> Undefined Then
			
					If Not IsBlankString(LastExportRuleRow.AfterProcess) Then
					
						Try
							
							If HandlerDebugModeFlag Then
								
								Execute(GetHandlerCallString(LastExportRuleRow, "AfterProcess"));
								
							Else
								
								Execute(LastExportRuleRow.AfterProcess);
								
							EndIf;
							
						Except
							
							WriteErrorInfoDERHandlers(32, ErrorDescription(), LastExportRuleRow.Name, "AfterProcessDataExport");
							
						EndTry;
						
					EndIf;
					
				EndIf;
				
				// Before processing data
				If CurrentExportRuleRow <> Undefined Then
					
					If CommentObjectProcessingFlag Then
						
						MessageString = SubstituteParametersInString(NStr("en = 'Data export rule: %1 (%2)'"),
							TrimAll(CurrentExportRuleRow.Name), TrimAll(CurrentExportRuleRow.Description));
						WriteToExecutionLog(MessageString, , False, , 4);
						
					EndIf;
					
					// BeforeProcess handle
					Cancel			   = False;
					OutgoingData  = Undefined;
					DataSelection = Undefined;
					
					If Not IsBlankString(CurrentExportRuleRow.BeforeProcess) Then
					
						Try
							
							If HandlerDebugModeFlag Then
								
								Execute(GetHandlerCallString(CurrentExportRuleRow, "BeforeProcess"));
								
							Else
								
								Execute(CurrentExportRuleRow.BeforeProcess);
								
							EndIf;
							
						Except
							
							WriteErrorInfoDERHandlers(31, ErrorDescription(), CurrentExportRuleRow.Name, "BeforeProcessDataExport");
							
						EndTry;
						
					EndIf;
					
					If Cancel Then
						
						// Deleting the rule from rule array
						CurrentExportRuleRow = Undefined;
						DeleteExportRuleTreeRowByExportTypeFromArray(TempConversionRuleArray, CurrentExportRuleRow);
						ObjectForExportRules = Undefined;
						
					EndIf;
					
				EndIf;
				
			EndIf;
			
			// The rule for exporting data exists
			If CurrentExportRuleRow <> Undefined Then
				
				If ExportingRegister Then
					
					For Each RegisterLine In ObjectForExportRules Do
						SelectionItemExport(RegisterLine, CurrentExportRuleRow, , OutgoingData);
					EndDo;
					
				ElsIf ExportingConstants Then
					
					Properties	= Managers[CurrentExportRuleRow.SelectionObject];
					ExportConstantsSet(CurrentExportRuleRow, Properties, OutgoingData);
					
				Else
				
					SelectionItemExport(ObjectForExportRules, CurrentExportRuleRow, , OutgoingData);
				
				EndIf;
				
			EndIf;
			
			LastMetadataObject = CurrentMetadataObject;
			LastExportRuleRow = CurrentExportRuleRow; 
			
			If ProcessedObjectNumberToUpdateStatus > 0 
				And FoundObjectToWriteCount % ProcessedObjectNumberToUpdateStatus = 0 Then
				
				Try
					MetadataName = CurrentMetadataObject.FullName();
				Except
					MetadataName = "";
				EndTry;
				
			EndIf;
			
			If UseTransactionsForExchangePlansOnExport 
				And (TransactionItemCountOnExportForExchangePlans > 0)
				And (FoundObjectToWriteCount = TransactionItemCountOnExportForExchangePlans) Then
				
				// Committing the transaction and beginning a new one
				CommitTransaction();
				BeginTransaction();
				
				FoundObjectToWriteCount = 0;
			EndIf;
			
		EndDo;
		
		If UseTransactionsForExchangePlansOnExport Then
			CommitTransaction();
		EndIf;
		
		// Finishing writing the message
		WriteMessage.EndWrite();
		
		XMLWriter.Close();
		
		// Event after processing
		If LastExportRuleRow <> Undefined Then
		
			If Not IsBlankString(LastExportRuleRow.AfterProcess) Then
			
				Try
					
					If HandlerDebugModeFlag Then
						
						Execute(GetHandlerCallString(LastExportRuleRow, "AfterProcess"));
						
					Else
						
						Execute(LastExportRuleRow.AfterProcess);
						
					EndIf;
					
				Except
					
					WriteErrorInfoDERHandlers(32, ErrorDescription(), LastExportRuleRow.Name, "AfterProcessDataExport");
					
				EndTry;
				
			EndIf;
			
		EndIf;
		
	Except
		
		If UseTransactionsForExchangePlansOnExport Then
			RollbackTransaction();
		EndIf;
		
		LR = GetLogRecordStructure(72, ErrorDescription());
		LR.ExchangePlanNode  = ExchangeNode;
		LR.Object = Data;
		LR.ObjectType = ExportDataType;
		
		ErrorMessageString = WriteToExecutionLog(72, LR, True);
						
		XMLWriter.Close();
		
		Return False;
		
	EndTry;
	
	StructureForChangeRecordDeletion.OCRArray = TempConversionRuleArray;
	
	Return Not Cancel;
	
EndFunction

Function ProcessExportForExchangePlans(NodeAndExportRuleMap, StructureForChangeRecordDeletion)
	
	SuccessfulExport = True;
	
	For Each MapRow In NodeAndExportRuleMap Do
		
		ExchangeNode = MapRow.Key;
		ConversionRuleArray = MapRow.Value;
		
		LocalStructureForChangeRecordDeletion = New Structure();
		
		CurrentSuccessfulExport = ExecuteExchangeNodeChangedDataExport(ExchangeNode, ConversionRuleArray, LocalStructureForChangeRecordDeletion);
		
		SuccessfulExport = SuccessfulExport And CurrentSuccessfulExport;
		
		If LocalStructureForChangeRecordDeletion.OCRArray <> Undefined
			And LocalStructureForChangeRecordDeletion.OCRArray.Count() > 0 Then
			
			StructureForChangeRecordDeletion.Insert(ExchangeNode, LocalStructureForChangeRecordDeletion);	
			
		EndIf;
		
	EndDo;
	
	Return SuccessfulExport;
	
EndFunction

Procedure ProcessExchangeNodeRecordChangeEditing(NodeAndExportRuleMap)
	
	For Each Item In NodeAndExportRuleMap Do
	
		If ChangeRecordsForExchangeNodeDeleteAfterExportType = 0 Then
			
			Return;
			
		ElsIf ChangeRecordsForExchangeNodeDeleteAfterExportType = 1 Then
			
			// Deleting registration of all changes that are in the exchange plan
			ExchangePlans.DeleteChangeRecords(Item.Key, Item.Value.MessageNo);
			
		ElsIf ChangeRecordsForExchangeNodeDeleteAfterExportType = 2 Then	
			
			// Deleting changes of metadata of the first level exported objects 
			
			For Each ExportedOCR In Item.Value.OCRArray Do
				
				Try
					
					Rule = Rules[ExportedOCR.ConversionRule];
					
					Manager = Managers[Rule.Source];
					
					ExchangePlans.DeleteChangeRecords(Item.Key, Manager.MDObject);	
					
				Except
					
					
				EndTry;
				
			EndDo;
			
		EndIf;
	
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// EXPORT PROCEDURES AND FUNCTIONS.

// Opens the exchange file, reads root node file attributes according to the exchange format.
//
// Parameters:
//  ReadHeaderOnly - Boolean - if True is passed, the file is closed once the header is read.

//
Procedure OpenImportFile(ReadHeaderOnly=False, ExchangeFileData = "") Export

	If IsBlankString(ExchangeFileName) And ReadHeaderOnly Then
		StartDate            = "";
		EndDate              = "";
		DataExportDate       = "";
		ExchangeRulesVersion = "";
		Comment              = "";

		Return;
	EndIf;


    DataImportFileName = ExchangeFileName;
	
	
	// Archive files are identified by .zip extension
	If Find(ExchangeFileName, ".zip") > 0 Then
		
		DataImportFileName = UnpackZipFile(ExchangeFileName);		 
		
	EndIf; 
	
	
	ErrorFlag = False;
	ExchangeFile = New XMLReader();

	Try
		If Not IsBlankString(ExchangeFileData) Then
			ExchangeFile.SetString(ExchangeFileData);
		Else
			ExchangeFile.OpenFile(DataImportFileName);
		EndIf;
	Except
		WriteToExecutionLog(5);
		Return;
	EndTry;
	
	ExchangeFile.Read();


	mExchangeFileAttributes = New Structure;
	
	
	If ExchangeFile.LocalName = "ExchangeFile" Then
		
		mExchangeFileAttributes.Insert("FormatVersion",           deAttribute(ExchangeFile, deStringType, "FormatVersion"));
		mExchangeFileAttributes.Insert("ExportDate",              deAttribute(ExchangeFile, deDateType,   "ExportDate"));
		mExchangeFileAttributes.Insert("ExportPeriodStart",       deAttribute(ExchangeFile, deDateType,   "ExportPeriodStart"));
		mExchangeFileAttributes.Insert("ExportPeriodEnd",         deAttribute(ExchangeFile, deDateType,   "ExportPeriodEnd"));
		mExchangeFileAttributes.Insert("SourceConfigurationName", deAttribute(ExchangeFile, deStringType, "SourceConfigurationName"));
		mExchangeFileAttributes.Insert("TargetConfigurationName", deAttribute(ExchangeFile, deStringType, "TargetConfigurationName"));
		mExchangeFileAttributes.Insert("ConversionRuleIDs",       deAttribute(ExchangeFile, deStringType, "ConversionRuleIDs"));

		
		StartDate      = mExchangeFileAttributes.ExportPeriodStart;
		EndDate        = mExchangeFileAttributes.ExportPeriodEnd;
		DataExportDate = mExchangeFileAttributes.ExportDate;
		Comment        = deAttribute(ExchangeFile, deStringType, "Comment");

		
	Else
		
		WriteToExecutionLog(9);
		Return;
		
	EndIf;


	ExchangeFile.Read();
			
	NodeName = ExchangeFile.LocalName;
		
	If NodeName = "ExchangeRules" Then
		ImportExchangeRules(ExchangeFile, "XMLReader");
						
	Else
		ExchangeFile.Close();
		ExchangeFile = New XMLReader();
		Try
			
			If Not IsBlankString(ExchangeFileData) Then
				ExchangeFile.SetString(ExchangeFileData);
			Else
				ExchangeFile.OpenFile(DataImportFileName);
			EndIf;
			
		Except
			
			WriteToExecutionLog(5);
			Return;
			
		EndTry;
		
		ExchangeFile.Read();
		
	EndIf; 
	
	mExchangeRulesReadOnImport = True;

	If ReadHeaderOnly Then
		
		ExchangeFile.Close();
		Return;
		
	EndIf;
   
EndProcedure

// Fills the passed value table with types of metadata objects to be deleted that are allowed by access rights to be deleted.
//
Procedure FillTypeAvailableToDeleteList(DataTable) Export
	
	DataTable.Clear();
	
	For Each MDObject In Metadata.Catalogs Do
		
		If Not AccessRight("Delete", MDObject) Then
			Continue;
		EndIf;
		
		TableRow = DataTable.Add();
		TableRow.Metadata = "CatalogRef." + MDObject.Name;
		
	EndDo;

	For Each MDObject In Metadata.ChartsOfCharacteristicTypes Do
		
		If Not AccessRight("Delete", MDObject) Then
			Continue;
		EndIf;
		
		TableRow = DataTable.Add();
		TableRow.Metadata = "ChartOfCharacteristicTypesRef." + MDObject.Name;
	EndDo;

	For Each MDObject In Metadata.Documents Do
		
		If Not AccessRight("Delete", MDObject) Then
			Continue;
		EndIf;
		
		TableRow = DataTable.Add();
		TableRow.Metadata = "DocumentRef." + MDObject.Name;
	EndDo;

	For Each MDObject In Metadata.InformationRegisters Do
		
		If Not AccessRight("Delete", MDObject) Then
			Continue;
		EndIf;
		
		Subordinate = (MDObject.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.RecorderSubordinate);
		If Subordinate Then Continue EndIf;
		
		TableRow = DataTable.Add();
		TableRow.Metadata = "InformationRegisterRecord." + MDObject.Name;
		
	EndDo;
	
EndProcedure

// Sets marks of subordinate value tree rows according to the current row mark.
//
// Parameters:
//  CurRow - value tree row.
//
 
Procedure SetSubordinateMarks(CurRow, Attribute) Export

	Subordinate = CurRow.Rows;

	If Subordinate.Count() = 0 Then
		Return;
	EndIf;
	
	For Each Row In Subordinate Do
		
		If Row.BuilderSettings = Undefined 
			And Attribute = "UseFilter" Then
			
			Row[Attribute] = 0;
			
		Else
			
			Row[Attribute] = CurRow[Attribute];
			
		EndIf;
		
		SetSubordinateMarks(Row, Attribute);
		
	EndDo;
		
EndProcedure

// Sets marks of parent value tree rows according to the current row mark.
//
// Parameters:
//  CurRow - value tree row.
//
 
Procedure SetParentMarks(CurRow, Attribute) Export

	Parent = CurRow.Parent;
	If Parent = Undefined Then
		Return;
	EndIf; 

	CurState       = Parent[Attribute];

	EnabledItemsFound  = False;
	DisabledItemsFound = False;

	If Attribute = "UseFilter" Then
		
		For Each Row In Parent.Rows Do
			
			If Row[Attribute] = 0 And 
				Row.BuilderSettings <> Undefined Then
				
				DisabledItemsFound = True;
				
			ElsIf Row[Attribute] = 1 Then
				EnabledItemsFound  = True;
			EndIf; 
			
			If EnabledItemsFound And DisabledItemsFound Then
				Break;
			EndIf; 
			
		EndDo;
		
	Else
		
		For Each String In Parent.Rows Do
			If String[Attribute] = 0 Then
				DisabledItemsFound = True;
			ElsIf String[Attribute] = 1
				Or String[Attribute] = 2 Then
				EnabledItemsFound  = True;
			EndIf; 
			If EnabledItemsFound And DisabledItemsFound Then
				Break;
			EndIf; 
		EndDo;
		
	EndIf;

	
	If EnabledItemsFound And DisabledItemsFound Then
		PrivilegedModeOn = 2;
	ElsIf EnabledItemsFound And (Not DisabledItemsFound) Then
		PrivilegedModeOn = 1;
	ElsIf (Not EnabledItemsFound) And DisabledItemsFound Then
		PrivilegedModeOn = 0;
	ElsIf (Not EnabledItemsFound) And (Not DisabledItemsFound) Then
		PrivilegedModeOn = 2;
	EndIf;

	If PrivilegedModeOn = CurState Then
		Return;
	Else
		Parent[Attribute] = PrivilegedModeOn;
		SetParentMarks(Parent, Attribute);
	EndIf; 
	
EndProcedure


Function RefreshAllExportRuleParentMarks(ExportRuleTreeRows, MustSetMarks = True)
	
	If ExportRuleTreeRows.Rows.Count() = 0 Then
		
		If MustSetMarks Then
			SetParentMarks(ExportRuleTreeRows, "PrivilegedModeOn");	
		EndIf;
		
		Return True;
		
	Else
		
		MarksRequired = True;
		
		For Each RuleTreeRow In ExportRuleTreeRows.Rows Do
			
			SetupResult = RefreshAllExportRuleParentMarks(RuleTreeRow, MarksRequired);
			If MarksRequired = True Then
				MarksRequired = False;
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndFunction


Procedure FillPropertiesForSearch(DataStructure, PCR)
	
	For Each FieldRow In PCR Do
		
		If FieldRow.IsFolder Then
						
			If FieldRow.TargetKind = "TabularSection" 
				Or Find(FieldRow.TargetKind, "RegisterRecordSet") > 0 Then
				
				RecipientStructureName = FieldRow.Target + ?(FieldRow.TargetKind = "TabularSection", "TabularSection", "RecordSet");
				
				InternalStructure = DataStructure[RecipientStructureName];
				
				If InternalStructure = Undefined Then
					InternalStructure = New Map();
				EndIf;
				
				DataStructure[RecipientStructureName] = InternalStructure;
				
			Else
				
				InternalStructure = DataStructure;	
				
			EndIf;
			
			FillPropertiesForSearch(InternalStructure, FieldRow.GroupRules);
									
		Else
			
			If IsBlankString(FieldRow.TargetType)	Then
				
				Continue;
				
			EndIf;
			
			DataStructure[FieldRow.Target] = FieldRow.TargetType;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure DeleteExcessiveItemsFromMap(DataStructure)
	
	For Each Item In DataStructure Do
		
		If TypeOf(Item.Value) = deMapType Then
			
			DeleteExcessiveItemsFromMap(Item.Value);
			
			If Item.Value.Count() = 0 Then
				DataStructure.Delete(Item.Key);
			EndIf;
			
		EndIf;		
		
	EndDo;		
	
EndProcedure

Procedure FillInformationByTargetDataTypes(DataStructure, Rules)
	
	For Each Row In Rules Do
		
		If IsBlankString(Row.Target) Then
			Continue;
		EndIf;
		
		StructureData = DataStructure[Row.Target];
		If StructureData = Undefined Then
			
			StructureData = New Map();
			DataStructure[Row.Target] = StructureData;
			
		EndIf;
		
		// Reviewing search fields and other PCR and writing data types
		FillPropertiesForSearch(StructureData, Row.SearchProperties);
				
		// Properties
		FillPropertiesForSearch(StructureData, Row.Properties);
		
	EndDo;
	
	DeleteExcessiveItemsFromMap(DataStructure);	
	
EndProcedure

Procedure CreateStringWithPropertyTypes(XMLWriter, PropertyTypes)
	
	If TypeOf(PropertyTypes.Value) = deMapType Then
		
		If PropertyTypes.Value.Count() = 0 Then
			Return;
		EndIf;
		
		XMLWriter.WriteStartElement(PropertyTypes.Key);
		
		For Each Item In PropertyTypes.Value Do
			CreateStringWithPropertyTypes(XMLWriter, Item);
		EndDo;
		
		XMLWriter.WriteEndElement();
		
	Else		
		
		deWriteElement(XMLWriter, PropertyTypes.Key, PropertyTypes.Value);
		
	EndIf;
	
EndProcedure

Function CreateTypeStringForTarget(DataStructure)
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	XMLWriter.WriteStartElement("DataTypeInfo");	
	
	For Each Row In DataStructure Do
		
		XMLWriter.WriteStartElement("DataType");
		SetAttribute(XMLWriter, "Name", Row.Key);
		
		For Each SubordinationRow In Row.Value Do
			
			CreateStringWithPropertyTypes(XMLWriter, SubordinationRow);	
			
		EndDo;
		
		XMLWriter.WriteEndElement();
		
	EndDo;	
	
	XMLWriter.WriteEndElement();
	
	ResultRow = XMLWriter.Close();
	Return ResultRow;
	
EndFunction

Procedure ImportSingleTypeData(ExchangeRules, TypeMap, LocalItemName)
	
	NodeName = LocalItemName; 	
	
	ExchangeRules.Read();
	
	If (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
		
		ExchangeRules.Read();
		Return;
		
	ElsIf ExchangeRules.NodeType = deXMLNodeType_StartElement Then
			
		// New item
		NewMap = New Map;
		TypeMap.Insert(NodeName, NewMap);
		
		ImportSingleTypeData(ExchangeRules, NewMap, ExchangeRules.LocalName);			
		ExchangeRules.Read();
		
	Else
		TypeMap.Insert(NodeName, Type(ExchangeRules.Value));
		ExchangeRules.Read();
	EndIf;	
	
	ImportTypeMapForSingleType(ExchangeRules, TypeMap);
	
EndProcedure

Procedure ImportTypeMapForSingleType(ExchangeRules, TypeMap)
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
			
		    Break;
			
		EndIf;
		
		// Reading the element start
		ExchangeRules.Read();
		
		If ExchangeRules.NodeType = deXMLNodeType_StartElement Then
			
			// New item
			NewMap = New Map;
			TypeMap.Insert(NodeName, NewMap);
			
			ImportSingleTypeData(ExchangeRules, NewMap, ExchangeRules.LocalName);			
			
		Else
			TypeMap.Insert(NodeName, Type(ExchangeRules.Value));
			ExchangeRules.Read();
		EndIf;	
		
	EndDo;	
	
EndProcedure

Procedure ImportDataTypeInfo()
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
		
		If NodeName = "DataType" Then
			
			TypeName = deAttribute(ExchangeFile, deStringType, "Name");
			
			TypeMap = New Map;
			mDataTypeMapForImport.Insert(Type(TypeName), TypeMap);

			ImportTypeMapForSingleType(ExchangeFile, TypeMap);	
			
		ElsIf (NodeName = "DataTypeInfo") And (ExchangeFile.NodeType = deXMLNodeType_EndElement) Then
			
			Break;
			
		EndIf;
		
	EndDo;	
	
EndProcedure

Procedure ImportDataExchangeParameterValues()
	
	Name = deAttribute(ExchangeFile, deStringType, "Name");
		
	PropertyType = GetPropertyTypeByAdditionalData(Undefined, Name);
	
	Value = ReadProperty(PropertyType);
	
	Parameters.Insert(Name, Value);	
	
	AfterParameterImportAlgorithm = "";
	If EventsAfterParameterImport.Property(Name, AfterParameterImportAlgorithm)
		And Not IsBlankString(AfterParameterImportAlgorithm) Then
		
		If HandlerDebugModeFlag Then
			
			Raise NStr("en = '""After parameter import"" handler debugging is not supported.'");
			
		Else
			
			Execute(AfterParameterImportAlgorithm);
			
		EndIf;
		
	EndIf;
		
EndProcedure

Function GetHandlerValueFromText(ExchangeRules)
	
	HandlerText = deElementValue(ExchangeRules, deStringType);
	
	If Find(HandlerText, Chars.LF) = 0 Then
		Return HandlerText;
	EndIf;
	
	HandlerText = StrReplace(HandlerText, Char(10), Chars.LF);
	
	Return HandlerText;
	
EndFunction

// Imports exchange rules according to the exchange format.
//
// Parameters:
//  Source     - object where the exchange rules are imported from.
//  SourceType - String - specifies the source type: XMLFile, XMLReader, String.
//
 
Procedure ImportExchangeRules(Source="", SourceType="XMLFile") Export
	
	InitManagersAndMessages();
	
	HasBeforeExportObjectGlobalHandler    = False;
	HasAfterExportObjectGlobalHandler     = False;
	
	HasBeforeConvertObjectGlobalHandler   = False;

	HasBeforeImportObjectGlobalHandler    = False;
	HasAfterImportObjectGlobalHandler     = False;
	
	CreateConversionStructure();
	
	mPropertyConversionRuleTable = New ValueTable;
	InitPropertyConversionRuleTable(mPropertyConversionRuleTable);
	SupplementServiceTablesWithColumns();
	
	// Perhaps, embedded exchange rules are selected (one of templates)
	
	ExchangeRuleTempFileName = "";
	If IsBlankString(Source) Then
		
		Source = ExchangeRuleFileName;
		If mExchangeRuleTemplateList.FindByValue(Source) <> Undefined Then
			For Each Template In ThisObject.Metadata().Templates Do
				If Template.Synonym = Source Then
					Source = Template.Name;
					Break;
				EndIf; 
			EndDo; 
			ExchangeRuleTemplate     = GetTemplate(Source);
			UUID                     = New UUID();
			ExchangeRuleTempFileName = TempFilesDir() + UUID + ".xml";
			ExchangeRuleTemplate.Write(ExchangeRuleTempFileName);
			Source = ExchangeRuleTempFileName;
		EndIf;
		
	EndIf;

	
	If SourceType="XMLFile" Then
		
		If IsBlankString(Source) Then
			WriteToExecutionLog(12);
			Return; 
		EndIf;
		
		File = New File(Source);
		If Not File.Exist() Then
			WriteToExecutionLog(3);
			Return; 
		EndIf;
		
		RuleFilePacked = (File.Extension = ".zip");
		
		If RuleFilePacked Then
			
			// Unpacking the rule file
			Source = UnpackZipFile(Source);
						
		EndIf;
		
		ExchangeRules = New XMLReader();
		ExchangeRules.OpenFile(Source);
		ExchangeRules.Read();
		
	ElsIf SourceType="String" Then
		
		ExchangeRules = New XMLReader();
		ExchangeRules.SetString(Source);
		ExchangeRules.Read();
		
	ElsIf SourceType="XMLReader" Then
		
		ExchangeRules = Source;
		
	EndIf; 
	

	If Not ((ExchangeRules.LocalName = "ExchangeRules") And (ExchangeRules.NodeType = deXMLNodeType_StartElement)) Then
		WriteToExecutionLog(6);
		Return;
	EndIf;


	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	XMLWriter.Indent = True;
	XMLWriter.WriteStartElement("ExchangeRules");
	

	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		// Conversion attributes
		If NodeName = "FormatVersion" Then
			Value = deElementValue(ExchangeRules, deStringType);
			Conversion.Insert("FormatVersion", Value);
			deWriteElement(XMLWriter, NodeName, Value);
		ElsIf NodeName = "ID" Then
			Value = deElementValue(ExchangeRules, deStringType);
			Conversion.Insert("ID",                   Value);
			deWriteElement(XMLWriter, NodeName, Value);
		ElsIf NodeName = "Description" Then
			Value = deElementValue(ExchangeRules, deStringType);
			Conversion.Insert("Description",         Value);
			deWriteElement(XMLWriter, NodeName, Value);
		ElsIf NodeName = "CreationDateTime" Then
			Value = deElementValue(ExchangeRules, deDateType);
			Conversion.Insert("CreationDateTime",    Value);
			deWriteElement(XMLWriter, NodeName, Value);
			ExchangeRulesVersion = Conversion.CreationDateTime;
		ElsIf NodeName = "Source" Then
			Value = deElementValue(ExchangeRules, deStringType);
			Conversion.Insert("Source",             Value);
			deWriteElement(XMLWriter, NodeName, Value);
		ElsIf NodeName = "Target" Then
			
			TargetPlatformVersion = ExchangeRules.GetAttribute ("PlatformVersion");
			TargetPlatform = GetPlatformByTargetPlatformVersion(TargetPlatformVersion);
			
			Value = deElementValue(ExchangeRules, deStringType);
			Conversion.Insert("Target",           Value);
			deWriteElement(XMLWriter, NodeName, Value);
			
		ElsIf NodeName = "DeleteMappedObjectsFromTargetOnDeleteFromSource" Then
			deSkip(ExchangeRules);
		
		ElsIf NodeName = "Comment" Then
			deSkip(ExchangeRules);
			
		ElsIf NodeName = "MainExchangePlan" Then
			deSkip(ExchangeRules);

		ElsIf NodeName = "Parameters" Then
			ImportParameters(ExchangeRules, XMLWriter)

		// Conversion events
		
		ElsIf NodeName = "" Then
			
		ElsIf NodeName = "AfterExchangeRuleImport" Then
			Conversion.Insert("AfterExchangeRuleImport", GetHandlerValueFromText(ExchangeRules));	
			
		ElsIf NodeName = "BeforeDataExport" Then
			Conversion.Insert("BeforeDataExport", GetHandlerValueFromText(ExchangeRules));
			
		ElsIf NodeName = "AfterDataExport" Then
			Conversion.Insert("AfterDataExport",  GetHandlerValueFromText(ExchangeRules));

		ElsIf NodeName = "BeforeExportObject" Then
			Conversion.Insert("BeforeExportObject", GetHandlerValueFromText(ExchangeRules));
			HasBeforeExportObjectGlobalHandler = Not IsBlankString(Conversion.BeforeExportObject);

		ElsIf NodeName = "AfterExportObject" Then
			Conversion.Insert("AfterExportObject", GetHandlerValueFromText(ExchangeRules));
			HasAfterExportObjectGlobalHandler = Not IsBlankString(Conversion.AfterExportObject);

		ElsIf NodeName = "BeforeImportObject" Then
			
			Value = GetHandlerValueFromText(ExchangeRules);
			
			If ExchangeMode = "Import" Then
				
				Conversion.Insert("BeforeImportObject", Value);
				HasBeforeImportObjectGlobalHandler = Not IsBlankString(Value);
				
			Else
				
				deWriteElement(XMLWriter, NodeName, Value);
				
			EndIf;
			
		ElsIf NodeName = "AfterImportObject" Then
			
			Value = GetHandlerValueFromText(ExchangeRules);
			
			If ExchangeMode = "Import" Then
				
				Conversion.Insert("AfterImportObject", Value);
				HasAfterImportObjectGlobalHandler = Not IsBlankString(Value);
				
			Else
				
				deWriteElement(XMLWriter, NodeName, Value);
				
			EndIf;
			
		ElsIf NodeName = "BeforeObjectConversion" Then
			Conversion.Insert("BeforeObjectConversion", GetHandlerValueFromText(ExchangeRules));
			HasBeforeConvertObjectGlobalHandler = Not IsBlankString(Conversion.BeforeObjectConversion);
			
		ElsIf NodeName = "BeforeDataImport" Then
			
			Value = GetHandlerValueFromText(ExchangeRules);
			
			If ExchangeMode = "Import" Then
				
				Conversion.BeforeDataImport = Value;
				
			Else
				
				deWriteElement(XMLWriter, NodeName, Value);
				
			EndIf;
			
		ElsIf NodeName = "AfterDataImport" Then
			
			Value = GetHandlerValueFromText(ExchangeRules);
			
			If ExchangeMode = "Import" Then
				
				Conversion.AfterDataImport = Value;
				
			Else
				
				deWriteElement(XMLWriter, NodeName, Value);
				
			EndIf;
			
		ElsIf NodeName = "AfterParameterImport" Then
			Conversion.Insert("AfterParameterImport", GetHandlerValueFromText(ExchangeRules));
			
		ElsIf NodeName = "BeforeSendDeletionInfo" Then
			Conversion.Insert("BeforeSendDeletionInfo",  deElementValue(ExchangeRules, deStringType));
			
		ElsIf NodeName = "BeforeGetChangedObjects" Then
			Conversion.Insert("BeforeGetChangedObjects", deElementValue(ExchangeRules, deStringType));
			
		ElsIf NodeName = "OnGetDeletionInfo" Then
			
			Value = GetHandlerValueFromText(ExchangeRules);
			
			If ExchangeMode = "Import" Then
				
				Conversion.Insert("OnGetDeletionInfo", Value);
				
			Else
				
				deWriteElement(XMLWriter, NodeName, Value);
				
			EndIf;
			
		ElsIf NodeName = "AfterReceiveExchangeNodeDetails" Then
			
			Value = GetHandlerValueFromText(ExchangeRules);
			
			If ExchangeMode = "Import" Then
				
				Conversion.Insert("AfterReceiveExchangeNodeDetails", Value);
				
			Else
				
				deWriteElement(XMLWriter, NodeName, Value);
				
			EndIf;

		// Rules
		
		ElsIf NodeName = "DataExportRules" Then
		
 			If ExchangeMode = "Import" Then
				deSkip(ExchangeRules);
			Else
				ImportExportRules(ExchangeRules);
 			EndIf; 
			
		ElsIf NodeName = "ObjectConversionRules" Then
			ImportConversionRules(ExchangeRules, XMLWriter);
			
		ElsIf NodeName = "DataClearingRules" Then
			ImportClearingRules(ExchangeRules, XMLWriter)
			
		ElsIf NodeName = "ObjectChangeRecordRules" Then
			deSkip(ExchangeRules); // Object registration rules are imported with another data processor
			
		// Algorithms / Queries / Data processors
		
		ElsIf NodeName = "Algorithms" Then
			ImportAlgorithms(ExchangeRules, XMLWriter);
			
		ElsIf NodeName = "Queries" Then
			ImportQueries(ExchangeRules, XMLWriter);

		ElsIf NodeName = "DataProcessors" Then
			ImportDataProcessors(ExchangeRules, XMLWriter);
			
		// Exit
		ElsIf (NodeName = "ExchangeRules") And (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
		
			If ExchangeMode <> "Import" Then
				ExchangeRules.Close();
			EndIf;
			Break;

			
		// Format error
		Else
		    RecordStructure = New Structure("NodeName", NodeName);
			WriteToExecutionLog(7, RecordStructure);
			Return;
		EndIf;
	EndDo;


	XMLWriter.WriteEndElement();
	mXMLRules = XMLWriter.Close();
	
	For Each ExportRuleRow In ExportRuleTable.Rows Do
		RefreshAllExportRuleParentMarks(ExportRuleRow, True);
	EndDo;
	
	// Deleting the temporary rule file
	If Not IsBlankString(ExchangeRuleTempFileName) Then
		Try
 			DeleteFiles(ExchangeRuleTempFileName);
		Except 
		EndTry;
	EndIf;
	
	If SourceType="XMLFile"
		And RuleFilePacked Then
		
		Try
			DeleteFiles(Source);
		Except 
		EndTry;	
		
	EndIf;
	
	// Target type information required for quick data import
	DataStructure = New Map();
	FillInformationByTargetDataTypes(DataStructure, ConversionRuleTable);
	
	mTypesForTargetString = CreateTypeStringForTarget(DataStructure);
	
	// Event call is required after importing the exchange rules
	AfterExchangeRuleImportEventText = "";
	If Conversion.Property("AfterExchangeRuleImport", AfterExchangeRuleImportEventText)
		And Not IsBlankString(AfterExchangeRuleImportEventText) Then
		
		Try
			
			If HandlerDebugModeFlag Then
				
				Raise NStr("en = '""After exchange rule import"" handler debugging is not supported.'");
				
			Else
				
				Execute(AfterExchangeRuleImportEventText);
				
			EndIf;
			
		Except
			
			Text = NStr("en = 'AfterExchangeRuleImport handler: %1'");
			Text = SubstituteParametersInString(Text, BriefErrorDescription(ErrorInfo()));
			
			MessageToUser(Text);
			
		EndTry;
		
	EndIf;
	
EndProcedure


Procedure ProcessNewItemReadEnd(LastImportObject)
	
	mImportedObjectCounter = 1 + mImportedObjectCounter;
				
	If mImportedObjectCounter % ProcessedObjectNumberToUpdateStatus = 0 Then
		
		If LastImportObject <> Undefined Then
			
			ImportObjectString = ", Object: " + String(TypeOf(LastImportObject)) + "  " + String(LastImportObject);
								
		Else
			
			ImportObjectString = "";
			
		EndIf;
		
	EndIf;
	
	If RememberImportedObjects
		And mImportedObjectCounter % 100 = 0 Then
				
		If ImportedObjects.Count() > ImportedObjectToStoreCount Then
			ImportedObjects.Clear();
		EndIf;
				
	EndIf;
	
	If mImportedObjectCounter % 100 = 0
		And mNotWrittenObjectGlobalStack.Count() > 100 Then
		
		ExecuteWriteNotWrittenObjects();
		
	EndIf;
	
	If UseTransactions
		And ObjectCountPerTransaction > 0 
		And mImportedObjectCounter % ObjectCountPerTransaction = 0 Then
		
		CommitTransaction();
		BeginTransaction();
		
	EndIf;	

EndProcedure

// Reads the exchange message file consecutively and writes data to the infobase.
//
// Parameters:
//  ErrorInfoResultString - String - result string where error details are placed.
// 
Procedure ReadData(ErrorInfoResultString = "") Export
	
	Try
	
		While ExchangeFile.Read() Do
			
			NodeName = ExchangeFile.LocalName;
			
			If NodeName = "Object" Then
				
				LastImportObject = ReadObject();
				
				ProcessNewItemReadEnd(LastImportObject);
				
			ElsIf NodeName = "ParameterValue" Then	
				
				ImportDataExchangeParameterValues();
				
			ElsIf NodeName = "AfterParameterExportAlgorithm" Then	
				
				Cancel = False;
				CancelReason = "";
				
				AlgorithmText = deElementValue(ExchangeFile, deStringType);
				
				If Not IsBlankString(AlgorithmText) Then
				
					Try
						
						If HandlerDebugModeFlag Then
							
							Raise NStr("en = '""After parameter import"" handler debugging is not supported.'");
							
						Else
							
							Execute(AlgorithmText);
							
						EndIf;
						
						If Cancel = True Then
							
							If Not IsBlankString(CancelReason) Then
								ExceptionString = SubstituteParametersInString(NStr("en = 'Data import is canceled for the following reason: %1'"), CancelReason);
								Raise ExceptionString;
							Else
								Raise NStr("en = 'Data import has been canceled.'");
							EndIf;
							
						EndIf;
						
					Except
												
						LR = GetLogRecordStructure(75, ErrorDescription());
						LR.Handler     = "AfterParameterImport";
						ErrorMessageString = WriteToExecutionLog(75, LR, True);
						
						If Not DebugModeFlag Then
							Raise ErrorMessageString;
						EndIf;
						
					EndTry;
					
				EndIf;				
				
			ElsIf NodeName = "Algorithm" Then
				
				AlgorithmText = deElementValue(ExchangeFile, deStringType);
				
				If Not IsBlankString(AlgorithmText) Then
				
					Try
						
						If HandlerDebugModeFlag Then
							
							Raise NStr("en = 'Global algorithm debugging is not supported.'");
							
						Else
							
							Execute(AlgorithmText);
							
						EndIf;
						
					Except
						
						LR = GetLogRecordStructure(39, ErrorDescription());
						LR.Handler     = "ExchangeFileAlgorithm";
						ErrorMessageString = WriteToExecutionLog(39, LR, True);
						
						If Not DebugModeFlag Then
							Raise ErrorMessageString;
						EndIf;
						
					EndTry;
					
				EndIf;
				
			ElsIf NodeName = "ExchangeRules" Then
				
				mExchangeRulesReadOnImport = True;
				
				If ConversionRuleTable.Count() = 0 Then
					ImportExchangeRules(ExchangeFile, "XMLReader");
				Else
					deSkip(ExchangeFile);
				EndIf;
				
			ElsIf NodeName = "DataTypeInfo" Then
				
				ImportDataTypeInfo();
				
			ElsIf (NodeName = "ExchangeFile") And (ExchangeFile.NodeType = deXMLNodeType_EndElement) Then
				
			Else
				RecordStructure = New Structure("NodeName", NodeName);
				WriteToExecutionLog(9, RecordStructure);
			EndIf;
			
		EndDo;
		
	Except
		
		ErrorString = SubstituteParametersInString(NStr("en = 'Error importing data: %1'"), ErrorDescription());
		
		ErrorInfoResultString = WriteToExecutionLog(ErrorString, Undefined, True, , , True);
		
		DisableExchangeProtocol();
		ExchangeFile.Close();
		Return;
		
	EndTry;
	
EndProcedure

// Performs the following actions before reading data from the file:
//  - initializes variables;
//  - imports exchange rules from the data file;
//  - begins a transaction for writing data to the infobase;
//  - executes required event handlers.
// 
// Parameters:
//  DataString – name of the file where data is imported from or the XML string that
//               contains data to be imported.
// 
// Returns:
//  True if the data can be imported, otherwise is False.
//

Function ExecuteActionsBeforeReadData(DataRow = "") Export
	
	DataProcessingMode = mDataProcessingModes.Import;

	mExtendedSearchParameterMap = New Map;
	mConversionRuleMap          = New Map;
	
	Rules.Clear();
	
	InitializeCommentsOnDataExportAndImport();
	
	EnableExchangeLog();
	
	ImportPossible = True;
	
	If IsBlankString(DataRow) Then
	
		If IsBlankString(ExchangeFileName) Then
			WriteToExecutionLog(15);
			ImportPossible = False;
		EndIf;
	
	EndIf;
	
	//Initializing the external data processor with export handlers
	InitEventHandlerExternalDataProcessor(ImportPossible, ThisObject);
	
	If Not ImportPossible Then
		Return False;
	EndIf;
	
	MessageString = SubstituteParametersInString(NStr("en = 'Import started at: %1'"), CurrentSessionDate());
	WriteToExecutionLog(MessageString, , False, , , True);
	
	If DebugModeFlag Then
		UseTransactions = False;
	EndIf;
	
	If ProcessedObjectNumberToUpdateStatus = 0 Then
		
		ProcessedObjectNumberToUpdateStatus = 100;
		
	EndIf;
	
	mDataTypeMapForImport        = New Map;
	mNotWrittenObjectGlobalStack = New Map;
	
	mImportedObjectCounter = 0;
	ErrorFlag              = False;
	ImportedObjects        = New Map;
	ImportedGlobalObjects  = New Map;

	InitManagersAndMessages();
	
	OpenImportFile(,DataRow);
	
	If ErrorFlag Then 
		DisableExchangeProtocol();
		Return False; 
	EndIf;

	//Defining handler interfaces
	If HandlerDebugModeFlag Then
		
		SupplementRulesWithHandlerInterfaces(Conversion, ConversionRuleTable, ExportRuleTable, ClearingRuleTable);
		
	EndIf;
	
	// BeforeDataImport handler
	Cancel = False;
	
	If Not IsBlankString(Conversion.BeforeDataImport) Then
		
		Try
			
			If HandlerDebugModeFlag Then
				
				Execute(GetHandlerCallString(Conversion, "BeforeDataImport"));
				
			Else
				
				Execute(Conversion.BeforeDataImport);
				
			EndIf;
			
		Except
			ErrorMessageString = WriteErrorInfoConversionHandlers(22, ErrorDescription(), NStr("en = 'BeforeDataImport (conversion)'"));
			Cancel = True;
		EndTry;
		
		If Cancel Then // Canceling data import
			DisableExchangeProtocol();
			ExchangeFile.Close();
			EventHandlerExternalDataProcessorDestructor();
			Return False;
		EndIf;
		
	EndIf;

	// Clearing infobase by rules
	ProcessClearingRules(ClearingRuleTable.Rows);
		
	If UseTransactions Then
		BeginTransaction();
	EndIf;
	
	Return True;
	
EndFunction

// Performs the following actions after the data import iteration:
// - commits the transaction (if necessary);
// - closes the exchange message file;
// - executing the AfterDataImport handler conversion;
// - finishes logging exchange events (if necessary).
//
 
Procedure ExecuteActionsAfterDataReadingCompleted() Export
	
	// Deferred writing
	ExecuteWriteNotWrittenObjects();
	
	If UseTransactions Then
		CommitTransaction();
	EndIf;

	ExchangeFile.Close();	
	
	// Handler AfterDataImport
	If Not IsBlankString(Conversion.AfterDataImport) Then
		
		Try
			
			If HandlerDebugModeFlag Then
				
				Execute(GetHandlerCallString(Conversion, "AfterDataImport"));
				
			Else
				
				Execute(Conversion.AfterDataImport);
				
			EndIf;
			
		Except
			ErrorMessageString = WriteErrorInfoConversionHandlers(23, ErrorDescription(), NStr("en = 'AfterDataImport (conversion)'"));
		EndTry;
		
	EndIf;
	
	EventHandlerExternalDataProcessorDestructor();
	
	WriteToExecutionLog(SubstituteParametersInString(
		NStr("en = 'Import finished at: %1'"), CurrentSessionDate()), , False, , , True);
	WriteToExecutionLog(SubstituteParametersInString(
		NStr("en = '%1 objects imported'"), mImportedObjectCounter), , False, , , True);
	
	DisableExchangeProtocol();
	
	If IsInteractiveMode Then
		MessageToUser(NStr("en = 'Data import completed.'"));
	EndIf;
	
EndProcedure

// Imports data according to the specified modes (exchange rules).
//
Procedure ExecuteImport() Export
	
	ExecutionPossible = ExecuteActionsBeforeReadData();
	
	If Not ExecutionPossible Then
		Return;
	EndIf;	

	ReadData();
	ExecuteActionsAfterDataReadingCompleted(); 
	
EndProcedure


Procedure CompressResultingExchangeFile()
	
	Try
		
		SourceExchangeFileName = ExchangeFileName;
		If ArchiveFile Then
			ExchangeFileName = StrReplace(ExchangeFileName, ".xml", ".zip");
		EndIf;
		
		Archiver = New ZipFileWriter(ExchangeFileName, ExchangeFileCompressionPassword, NStr("en = 'Data exchange file'"));
		Archiver.Add(SourceExchangeFileName);
		Archiver.Write();
		
		DeleteFiles(SourceExchangeFileName);
		
	Except
		
	EndTry;
	
EndProcedure

// Generates the full file name from the directory name and the file name.
//
// Parameters:
//  DirectoryName - String - contains a path to the file directory on the hard disk.
//  FileName      - String - contains the file name without directory name.
//
// Returns:
//   String - result file name.
//
Function GetExchangeFileName(DirectoryName, FileName) Export

	If Not IsBlankString(FileName) Then
		
		Return DirectoryName + ?(Right(DirectoryName, 1) = "\", "", "\") + FileName;	
		
	Else
		
		Return DirectoryName;
		
	EndIf;

EndFunction

Function UnpackZipFile(FileNameForUnpacking)
	
	DirectoryForUnpacking = TempFilesDir();
	
	UnpackedFileName = "";
	
	Try
		
		Archiver = New ZipFileReader(FileNameForUnpacking, ExchangeFileExtractionPassword);
		
		If Archiver.Items.Count() > 0 Then
			
			Archiver.Extract(Archiver.Items[0], DirectoryForUnpacking, ZIPRestoreFilePathsMode.DontRestore);
			UnpackedFileName = GetExchangeFileName(DirectoryForUnpacking, Archiver.Items[0].Name);
			
		Else
			
			UnpackedFileName = "";
			
		EndIf;
		
		Archiver.Close();
	
	Except
		
		LR = GetLogRecordStructure(2, ErrorDescription());
		WriteToExecutionLog(2, LR, True);
		
		Return "";
							
	EndTry;
	
	Return UnpackedFileName;
		
EndFunction

// Passes the data string to be imported into the target infobase.
//
// Parameters:
//  InformationToWriteToFile    – String (XML text) – data string.
//  ErrorStringInTargetInfobase – String – contains details of an error that occurs during importing into the target infobase.
//
 
Procedure PassWriteInfoToTarget(InformationToWriteToFile, ErrorStringInTargetInfobase = "") Export
	
	mDataImportDataProcessor.ExchangeFile.SetString(InformationToWriteToFile);
	
	mDataImportDataProcessor.ReadData(ErrorStringInTargetInfobase);
	
	If Not IsBlankString(ErrorStringInTargetInfobase) Then
		
		MessageString = SubstituteParametersInString(NStr("en = 'Importing in target: %1'"), ErrorStringInTargetInfobase);
		WriteToExecutionLog(MessageString, Undefined, True, , , True);
		
	EndIf;
	
EndProcedure

Function SendExchangeStartedInfoToTarget(CurrentRowForWrite)
	
	If Not DirectReadingInTargetInfobase Then
		Return True;
	EndIf;
	
	CurrentRowForWrite = CurrentRowForWrite + Chars.LF + mXMLRules + Chars.LF + "</ExchangeFile>" + Chars.LF;
	
	ExecutionPossible = mDataImportDataProcessor.ExecuteActionsBeforeReadData(CurrentRowForWrite);
	
	Return ExecutionPossible;	
	
EndFunction

Function ExecuteInformationTransferOnCompleteDataTransfer()
	
	If Not DirectReadingInTargetInfobase Then
		Return True;
	EndIf;
	
	mDataImportDataProcessor.ExecuteActionsAfterDataReadingCompleted();
	
EndFunction

// Writes the parameter name, type, and value to the exchange message file for passing to the target infobase.
// 
Procedure PassOneParameterToTarget(Name, InitialParameterValue, ConversionRule = "") Export
	
	If IsBlankString(ConversionRule) Then
		
		ParameterNode = CreateNode("ParameterValue");
		
		SetAttribute(ParameterNode, "Name", Name);
		SetAttribute(ParameterNode, "Type", deValueTypeString(InitialParameterValue));
		
		IsNULL = False;
		Empty = deEmpty(InitialParameterValue, IsNULL);
					
		If Empty Then
			
			// Writing the empty value
			deWriteElement(ParameterNode, "Empty");
								
			ParameterNode.WriteEndElement();
			
			WriteToFile(ParameterNode);
			
			Return;
								
		EndIf;
	
		deWriteElement(ParameterNode, "Value", InitialParameterValue);
	
		ParameterNode.WriteEndElement();
		
		WriteToFile(ParameterNode);
		
	Else
		
		ParameterNode = CreateNode("ParameterValue");
		
		SetAttribute(ParameterNode, "Name", Name);
		
		IsNULL = False;
		Empty = deEmpty(InitialParameterValue, IsNULL);
					
		If Empty Then
			
			PropertyOCR = FindRule(InitialParameterValue, ConversionRule);
			TargetType  = PropertyOCR.Target;
			SetAttribute(ParameterNode, "Type", TargetType);
			
			// Writing the empty value
			deWriteElement(ParameterNode, "Empty");
								
			ParameterNode.WriteEndElement();
			
			WriteToFile(ParameterNode);
			
			Return;
								
		EndIf;
		
		ExportRefObjectData(InitialParameterValue, , ConversionRule, , , ParameterNode, True);
		
		ParameterNode.WriteEndElement();
		
		WriteToFile(ParameterNode);				
		
	EndIf;	
	
EndProcedure

Procedure PassExtendedParametersToTarget()
	
	For Each Parameter In ParameterSetupTable Do
		
		If Parameter.PassParameterOnExport = True Then
			
			PassOneParameterToTarget(Parameter.Name, Parameter.Value, Parameter.ConversionRule);
					
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure PassTypeDetailsToTarget()
	
	If Not IsBlankString(mTypesForTargetString) Then
		WriteToFile(mTypesForTargetString);
	EndIf;
		
EndProcedure

// Exports data according to the set modes (exchange rules).
//
Procedure ExecuteExport() Export
	
	DataProcessingMode = mDataProcessingModes.Data;
	
	EnableExchangeLog();
	
	InitializeCommentsOnDataExportAndImport();
	
	ExportPossible = True;
	CurrentNestingLevelExportByRule = 0;
	
	mDataExportCallStack = New ValueTable;
	mDataExportCallStack.Columns.Add("Ref");
	mDataExportCallStack.Indexes.Add("Ref");
	
	If mExchangeRulesReadOnImport = True Then
		
		WriteToExecutionLog(74);
		ExportPossible = False;	
		
	EndIf;
	
	If IsBlankString(ExchangeRuleFileName) Then
		WriteToExecutionLog(12);
		ExportPossible = False;
	EndIf;
	
	If Not DirectReadingInTargetInfobase Then
		
		If IsBlankString(ExchangeFileName) Then
			WriteToExecutionLog(10);
			ExportPossible = False;
		EndIf;
		
	Else
		
		mDataImportDataProcessor = EstablishConnectionWithTargetInfobase(); 
		
		ExportPossible = mDataImportDataProcessor <> Undefined;
		
	EndIf;
	
	//Initializing the external data processor with export handlers
	InitEventHandlerExternalDataProcessor(ExportPossible, ThisObject);
	
	If Not ExportPossible Then
		mDataImportDataProcessor = Undefined;
		Return;
	EndIf;
	
	WriteToExecutionLog(SubstituteParametersInString(
		NStr("en = 'Export started at: %1'"), CurrentSessionDate()), , False, , , True);
		
	InitManagersAndMessages();
	
	mExportedObjectCounter = 0;
	mSnCounter             = 0;
	ErrorFlag              = False;

	// Importing exchange rules
	If Conversion.Count() = 9 Then
		
		ImportExchangeRules();
		If ErrorFlag Then
			DisableExchangeProtocol();
			mDataImportDataProcessor = Undefined;
			Return;
		EndIf;
		
	Else
		
		For Each Rule In ConversionRuleTable Do
			Rule.Exported.Clear();
			Rule.OnlyRefsExported.Clear();
		EndDo;
		
	EndIf;

	//Assigning options that are set in the dialog
	SetParametersFromDialog();

	// Opening the exchange file
	CurrentRowForWrite = OpenExportFile() + Chars.LF;
	
	If ErrorFlag Then
		ExchangeFile = Undefined;
		DisableExchangeProtocol();
		mDataImportDataProcessor = Undefined;
		Return; 
	EndIf;
	
	//Defining handler interfaces
	If HandlerDebugModeFlag Then
		
		SupplementRulesWithHandlerInterfaces(Conversion, ConversionRuleTable, ExportRuleTable, ClearingRuleTable);
		
	EndIf;
	
	Try
	
		// Writing the exchange rules to the file
		ExchangeFile.WriteLine(mXMLRules);
		
		ExecutionPossible = SendExchangeStartedInfoToTarget(CurrentRowForWrite);
		
		If Not ExecutionPossible Then
			ExchangeFile = Undefined;
			DisableExchangeProtocol();
			mDataImportDataProcessor = Undefined;
			EventHandlerExternalDataProcessorDestructor();
			Return;
		EndIf;
		
		// BeforeDataExport handler
		Cancel = False;
		Try
			
			If HandlerDebugModeFlag Then
				
				If Not IsBlankString(Conversion.BeforeDataExport) Then
					
					Execute(GetHandlerCallString(Conversion, "BeforeDataExport"));
					
				EndIf;
				
			Else
				
				Execute(Conversion.BeforeDataExport);
				
			EndIf;
			
		Except
			WriteErrorInfoConversionHandlers(62, ErrorDescription(), NStr("en = 'BeforeDataExport (conversion)'"));
			Cancel = True;
		EndTry; 
		
		If Cancel Then // Canceling data export
			ExchangeFile = Undefined;
			DisableExchangeProtocol();
			mDataImportDataProcessor = Undefined;
			EventHandlerExternalDataProcessorDestructor();
			Return;
		EndIf;
		
		If ExecuteDataExchangeInOptimizedFormat Then
			PassTypeDetailsToTarget();
		EndIf;
		
		// Passing parameters to the target infobase
		PassExtendedParametersToTarget();
		
		EventTextAfterParameterImport = "";
		If Conversion.Property("AfterParameterImport", EventTextAfterParameterImport)
			And Not IsBlankString(EventTextAfterParameterImport) Then
			
			WritingEvent = New XMLWriter;
			WritingEvent.SetString();
			deWriteElement(WritingEvent, "AfterParameterExportAlgorithm", EventTextAfterParameterImport);
			WriteToFile(WritingEvent);
			
		EndIf;
		
		NodeAndExportRuleMap = New Map();
		StructureForChangeRecordDeletion = New Map();
		
		ProcessExportRules(ExportRuleTable.Rows, NodeAndExportRuleMap);
		
		SuccessfullyExportedByExchangePlans = ProcessExportForExchangePlans(NodeAndExportRuleMap, StructureForChangeRecordDeletion);
		
		If SuccessfullyExportedByExchangePlans Then
		
			ProcessExchangeNodeRecordChangeEditing(StructureForChangeRecordDeletion);
		
		EndIf;
		
		// AfterDataExport handler
		Try
			
			If HandlerDebugModeFlag Then
				
				If Not IsBlankString(Conversion.AfterDataExport) Then
					
					Execute(GetHandlerCallString(Conversion, "AfterDataExport"));
					
				EndIf;
				
			Else
				
				Execute(Conversion.AfterDataExport);
				
			EndIf;

		Except
			WriteErrorInfoConversionHandlers(63, ErrorDescription(), NStr("en = 'AfterDataExport (conversion)'"));
		EndTry;
		
	Except
		
		ErrorString = ErrorDescription();
		
		WriteToExecutionLog(SubstituteParametersInString(
			NStr("en = 'Error exporting data: %1'"), ErrorString), Undefined, True, , , True);
		
		ExecuteInformationTransferOnCompleteDataTransfer();
		
		DisableExchangeProtocol();
		CloseFile();
		mDataImportDataProcessor = Undefined;
		
		Return;
		
	EndTry;
	
	If Cancel Then // Canceling saving the data file
		
		ExecuteInformationTransferOnCompleteDataTransfer();
		
		DisableExchangeProtocol();
		mDataImportDataProcessor = Undefined;
		ExchangeFile = Undefined;
		
		EventHandlerExternalDataProcessorDestructor();
		
		Return;
	EndIf;
	
	// Closing the exchange file
	CloseFile();
	
	If ArchiveFile Then
		CompressResultingExchangeFile();
	EndIf;
	
	ExecuteInformationTransferOnCompleteDataTransfer();
	
	WriteToExecutionLog(SubstituteParametersInString(
		NStr("en = 'Export finished at: %1'"), CurrentSessionDate()), , False, , ,True);
	WriteToExecutionLog(SubstituteParametersInString(
		NStr("en = '%1 objects exported'"), mExportedObjectCounter), , False, , , True);
	
	DisableExchangeProtocol();
	
	mDataImportDataProcessor = Undefined;
	
	EventHandlerExternalDataProcessorDestructor();
	
	If IsInteractiveMode Then
		MessageToUser(NStr("en = 'Data has been exported.'"));
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR INITIALIZING ATTRIBUTE VALUES AND DATA PROCESSOR MODAL VARIABLES.

// Sets the ErrorFlag global variable value.
//
// Parameters:
//  Value - Boolean - new value of the ErrorFlag variable.
//  
Procedure SetErrorFlag(Value)
	
	ErrorFlag = Value;
	
	If ErrorFlag Then
		
		EventHandlerExternalDataProcessorDestructor(DebugModeFlag);
		
	EndIf;
	
EndProcedure

// Returns the current data processor version value.
//
// Returns:
//  Current current data processor version value.
//
Function ObjectVersion() Export
	
	Return 218;
	
EndFunction

// Returns the current data processor version value.
// 
// Returns:
//  Current current data processor version value.
//
Function ObjectVersionString() Export
	
	Return "2.1.8";
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// EXCHANGE RULE TABLE INITIALIZATION.

Procedure AddMissingColumns(Columns, Name, Types = Undefined)
	
	If Columns.Find(Name) <> Undefined Then
		Return;
	EndIf;
	
	Columns.Add(Name, Types);	
	
EndProcedure

// Initializes object property conversion rule table columns.
//
// Parameters:
//  Tab - ValueTable - property conversion rule table to be initialized.
//
 
Procedure InitPropertyConversionRuleTable(Tab) Export

	Columns = Tab.Columns;

	AddMissingColumns(Columns, "Name");
	AddMissingColumns(Columns, "Description");
	AddMissingColumns(Columns, "Order");

  AddMissingColumns(Columns, "IsFolder", 			deTypeDescription("Boolean"));
  AddMissingColumns(Columns, "GroupRules");

	AddMissingColumns(Columns, "SourceKind");
	AddMissingColumns(Columns, "TargetKind");
	
	AddMissingColumns(Columns, "SimplifiedPropertyExport", deTypeDescription("Boolean"));
	AddMissingColumns(Columns, "XMLNodeRequiredOnExport", deTypeDescription("Boolean"));
	AddMissingColumns(Columns, "XMLNodeRequiredOnExportGroup", deTypeDescription("Boolean"));


	AddMissingColumns(Columns, "SourceType", deTypeDescription("String"));
	AddMissingColumns(Columns, "TargetType", deTypeDescription("String"));
	
	AddMissingColumns(Columns, "Source");
	AddMissingColumns(Columns, "Target");

	AddMissingColumns(Columns, "ConversionRule");

	AddMissingColumns(Columns, "GetFromIncomingData", deTypeDescription("Boolean"));
	
	AddMissingColumns(Columns, "DontReplace", deTypeDescription("Boolean"));
	
	AddMissingColumns(Columns, "BeforeExport");
	AddMissingColumns(Columns, "OnExport");
	AddMissingColumns(Columns, "AfterExport");

	AddMissingColumns(Columns, "BeforeProcessExport");
	AddMissingColumns(Columns, "AfterProcessExport");

	AddMissingColumns(Columns, "HasBeforeExportHandler",	 deTypeDescription("Boolean"));
	AddMissingColumns(Columns, "HasOnExportHandler",				deTypeDescription("Boolean"));
	AddMissingColumns(Columns, "HasAfterExportHandler",		deTypeDescription("Boolean"));
	
	AddMissingColumns(Columns, "HasBeforeProcessExportHandler", deTypeDescription("Boolean"));
	AddMissingColumns(Columns, "HasAfterProcessExportHandler",  deTypeDescription("Boolean"));
	
	AddMissingColumns(Columns, "CastToLength",	deTypeDescription("Number"));
	AddMissingColumns(Columns, "ParameterForTransferName");
	AddMissingColumns(Columns, "SearchByEqualDate",					deTypeDescription("Boolean"));
	AddMissingColumns(Columns, "ExportGroupToFile",					deTypeDescription("Boolean"));
	
	AddMissingColumns(Columns, "SearchFieldString");
	
EndProcedure

// Initializes object conversion rule table columns.
// 
Procedure InitConversionRuleTable()

	Columns = ConversionRuleTable.Columns;
	
	AddMissingColumns(Columns, "Name");
	AddMissingColumns(Columns, "Description");
	AddMissingColumns(Columns, "Order");

	AddMissingColumns(Columns, "SynchronizeByID");
	AddMissingColumns(Columns, "DontCreateIfNotFound",               deTypeDescription("Boolean"));
	AddMissingColumns(Columns, "DontExportPropertyObjectsByRefs",    deTypeDescription("Boolean"));
	AddMissingColumns(Columns, "SearchBySearchFieldsIfNotFoundByID", deTypeDescription("Boolean"));
	AddMissingColumns(Columns, "OnExchangeObjectByRefSetGIUDOnly",   deTypeDescription("Boolean"));
	AddMissingColumns(Columns, "UseQuickSearchOnImport",             deTypeDescription("Boolean"));
	AddMissingColumns(Columns, "GenerateNewNumberOrCodeIfNotSet",    deTypeDescription("Boolean"));
	AddMissingColumns(Columns, "TinyObjectCount",                    deTypeDescription("Boolean"));
	AddMissingColumns(Columns, "RefExportReferenceCount",            deTypeDescription("Number"));
	AddMissingColumns(Columns, "InfobaseItemCount",                  deTypeDescription("Number"));

	
	AddMissingColumns(Columns, "ExportMethod");

	AddMissingColumns(Columns, "Source");
	AddMissingColumns(Columns, "Target");
	
	AddMissingColumns(Columns, "SourceType",  deTypeDescription("String"));

	AddMissingColumns(Columns, "BeforeExport");
	AddMissingColumns(Columns, "OnExport");
	AddMissingColumns(Columns, "AfterExport");
	AddMissingColumns(Columns, "AfterExportToFile");
	
	AddMissingColumns(Columns, "HasBeforeExportHandler",      deTypeDescription("Boolean"));
	AddMissingColumns(Columns, "HasOnExportHandler",          deTypeDescription("Boolean"));
	AddMissingColumns(Columns, "HasAfterExportHandler",       deTypeDescription("Boolean"));
	AddMissingColumns(Columns, "HasAfterExportToFileHandler", deTypeDescription("Boolean"));


	AddMissingColumns(Columns, "BeforeImport");
	AddMissingColumns(Columns, "OnImport");
	AddMissingColumns(Columns, "AfterImport");
	
	AddMissingColumns(Columns, "SearchFieldSequence");
	AddMissingColumns(Columns, "SearchInTabularSections");
	
	AddMissingColumns(Columns, "HasBeforeImportHandler", deTypeDescription("Boolean"));
	AddMissingColumns(Columns, "HasOnImportHandler",     deTypeDescription("Boolean"));
	AddMissingColumns(Columns, "HasAfterImportHandler",  deTypeDescription("Boolean"));

	
	AddMissingColumns(Columns, "HasSearchFieldSequenceHandler",  deTypeDescription("Boolean"));

	AddMissingColumns(Columns, "SearchProperties", deTypeDescription("ValueTable"));
	AddMissingColumns(Columns, "Properties", deTypeDescription("ValueTable"));

	
	AddMissingColumns(Columns, "Values",		deTypeDescription("Map"));

	AddMissingColumns(Columns, "Exported",                 deTypeDescription("Map"));
	AddMissingColumns(Columns, "OnlyRefsExported",         deTypeDescription("Map"));
	AddMissingColumns(Columns, "ExportSourcePresentation", deTypeDescription("Boolean"));

	
	AddMissingColumns(Columns, "DontReplace", deTypeDescription("Boolean"));
	
	AddMissingColumns(Columns, "RememberExported",   deTypeDescription("Boolean"));
	AddMissingColumns(Columns, "AllObjectsExported", deTypeDescription("Boolean"));

	
EndProcedure

// Initializes data export rule table columns.
// 
Procedure InitExportRuleTable()

	Columns = ExportRuleTable.Columns;

	AddMissingColumns(Columns, "Enable", deTypeDescription("Number"));
	AddMissingColumns(Columns, "IsFolder", deTypeDescription("Boolean"));
	
	AddMissingColumns(Columns, "Name");
	AddMissingColumns(Columns, "Description");
	AddMissingColumns(Columns, "Order");

	AddMissingColumns(Columns, "DataSelectionVariant");
	AddMissingColumns(Columns, "SelectionObject");
	
	AddMissingColumns(Columns, "ConversionRule");

	AddMissingColumns(Columns, "BeforeProcess");
	AddMissingColumns(Columns, "AfterProcess");

	AddMissingColumns(Columns, "BeforeExport");
	AddMissingColumns(Columns, "AfterExport");
	
	// Columns those are used for filtering with the builder.
	AddMissingColumns(Columns, "UseFilter", deTypeDescription("Boolean"));
	AddMissingColumns(Columns, "BuilderSettings");
	AddMissingColumns(Columns, "ObjectForQueryName");
	AddMissingColumns(Columns, "ObjectNameForRegisterQuery");
	
	AddMissingColumns(Columns, "SelectExportDataInSingleQuery", deTypeDescription("Boolean"));
	
	AddMissingColumns(Columns, "ExchangeNodeRef");

EndProcedure

// Initializes data clearing rule table columns.
// 
Procedure CleaningRuleTableInitialization()

	Columns = ClearingRuleTable.Columns;

	AddMissingColumns(Columns, "Enable", deTypeDescription("Boolean"));
	AddMissingColumns(Columns, "IsFolder", deTypeDescription("Boolean"));

	
	AddMissingColumns(Columns, "Name");
	AddMissingColumns(Columns, "Description");
	AddMissingColumns(Columns, "Order",	deTypeDescription("Number"));

	AddMissingColumns(Columns, "DataSelectionVariant");
	AddMissingColumns(Columns, "SelectionObject");
	
	AddMissingColumns(Columns, "DeleteForPeriod");
	AddMissingColumns(Columns, "Directly",	deTypeDescription("Boolean"));

	AddMissingColumns(Columns, "BeforeProcess");
	AddMissingColumns(Columns, "AfterProcess");
	AddMissingColumns(Columns, "BeforeDelete");
	
EndProcedure

// Initializes parameter settings table columns.
// 
Procedure InitializationParameterSetupTable()

	Columns = ParameterSetupTable.Columns;

	AddMissingColumns(Columns, "Name");
	AddMissingColumns(Columns, "Description");
	AddMissingColumns(Columns, "Value");
	AddMissingColumns(Columns, "PassParameterOnExport");
	AddMissingColumns(Columns, "ConversionRule");

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INITIALIZATION OF ATTRIBUTES AND MODULE VARIABLES.

Procedure InitializeCommentsOnDataExportAndImport()
	
	CommentOnDataExport = "";
	CommentOnDataImport = "";
	
EndProcedure

// Initializes the deMessages variable, which contains a map of message codes to their
// descriptions.
// 
Procedure InitMessages()

	deMessages = New Map;
	
	deMessages.Insert(2,  NStr("en = 'Error unpacking exchange file. The file is locked'"));
	deMessages.Insert(3,  NStr("en = 'The specified exchange rule file does not exist'"));
	deMessages.Insert(4,  NStr("en = 'Error creating Msxml2.DOMDocument COM object.'"));
	deMessages.Insert(5,  NStr("en = 'Error opening exchange file'"));
	deMessages.Insert(6,  NStr("en = 'Error importing exchange rules'"));
	deMessages.Insert(7,  NStr("en = 'Exchange rule format error'"));
	deMessages.Insert(8,  NStr("en = 'Invalid data export file name'"));
	deMessages.Insert(9,  NStr("en = 'Exchange file format error'"));
	deMessages.Insert(10, NStr("en = 'Data export file name is not specified.'"));
	deMessages.Insert(11, NStr("en = 'Exchange rules contain a reference to a nonexistent metadata object'"));
	deMessages.Insert(12, NStr("en = 'Exchange rule file name is not specified.'"));
	
	deMessages.Insert(13, NStr("en = 'Error retrieving object property value (by source property name).'"));
	deMessages.Insert(14, NStr("en = 'Error retrieving object property value (by target property name).'"));
	
	deMessages.Insert(15, NStr("en = 'Import file name is not specified.'"));
	
	deMessages.Insert(16, NStr("en = 'Error retrieving subordinate object property value (by source property name).'"));
	deMessages.Insert(17, NStr("en = 'Error retrieving subordinate object property value (by target property name).'"));
	
	deMessages.Insert(19, NStr("en = 'BeforeImportObject event handler error'"));
	deMessages.Insert(20, NStr("en = 'OnImportObject event handler error'"));
	deMessages.Insert(21, NStr("en = 'AfterImportObject event handler error'"));
	deMessages.Insert(22, NStr("en = 'BeforeDataImport event handler error (data conversion).'"));
	deMessages.Insert(23, NStr("en = 'AfterDataImport event handler error (data conversion).'"));
	deMessages.Insert(24, NStr("en = 'Error deleting object'"));
	deMessages.Insert(25, NStr("en = 'Error writing document'"));
	deMessages.Insert(26, NStr("en = 'Error writing object'"));
	deMessages.Insert(27, NStr("en = 'BeforeProcessClearingRule event handler error'"));
	deMessages.Insert(28, NStr("en = 'AfterProcessClearingRule event handler error'"));
	deMessages.Insert(29, NStr("en = 'BeforeDeleteObject event handler error'"));
	
	deMessages.Insert(31, NStr("en = 'BeforeProcessExportRule event handler error'"));
	deMessages.Insert(32, NStr("en = 'AfterProcessExportRule event handler error'"));
	deMessages.Insert(33, NStr("en = 'BeforeExportObject event handler error'"));
	deMessages.Insert(34, NStr("en = 'AfterExportObject event handler error'"));
	
	deMessages.Insert(39, NStr("en = 'Error executing algorithm from exchange file.'"));
	
	deMessages.Insert(41, NStr("en = 'BeforeExportObject event handler error'"));
	deMessages.Insert(42, NStr("en = 'OnExportObject event handler error'"));
	deMessages.Insert(43, NStr("en = 'AfterExportObject event handler error'"));
	
	deMessages.Insert(45, NStr("en = 'No conversion rule is found'"));
	
	deMessages.Insert(48, NStr("en = 'BeforeProcessExport property group event handler error'"));
	deMessages.Insert(49, NStr("en = 'AfterProcessExport property group event handler error'"));
	deMessages.Insert(50, NStr("en = 'BeforeExport event handler error (collection object).'"));
	deMessages.Insert(51, NStr("en = 'OnExport event handler error (collection object).'"));
	deMessages.Insert(52, NStr("en = 'AfterExport event handler error (collection object).'"));
	deMessages.Insert(53, NStr("en = 'BeforeImportObject global event handler error (data conversion).'"));
	deMessages.Insert(54, NStr("en = 'AfterImportObject global event handler error (data conversion).'"));
	deMessages.Insert(55, NStr("en = 'BeforeExport event handler error (property).'"));
	deMessages.Insert(56, NStr("en = 'OnExport event handler error (property).'"));
	deMessages.Insert(57, NStr("en = 'AfterExport event handler error (property).'"));
	
	deMessages.Insert(62, NStr("en = 'BeforeDataExport event handler error (data conversion).'"));
	deMessages.Insert(63, NStr("en = 'AfterDataExport event handler error (data conversion).'"));
	deMessages.Insert(64, NStr("en = 'BeforeObjectConversion global event handler error (data conversion).'"));
	deMessages.Insert(65, NStr("en = 'BeforeExportObject global event handler error (data conversion).'"));
	deMessages.Insert(66, NStr("en = 'Error retrieving subordinate object collection from incoming data'"));
	deMessages.Insert(67, NStr("en = 'Error retrieving subordinate object properties from incoming data'"));
	deMessages.Insert(68, NStr("en = 'Error retrieving object properties from incoming data'"));
	
	deMessages.Insert(69, NStr("en = 'AfterExportObject global event handler error (data conversion).'"));
	
	deMessages.Insert(71, NStr("en = 'The map of the Source value is not found'"));
	
	deMessages.Insert(72, NStr("en = 'Error exporting data for exchange plan node'"));
	
	deMessages.Insert(73, NStr("en = 'SearchFieldSequence event handler error'"));
	
	deMessages.Insert(74, NStr("en = 'Exchange rules for data export must be reread'"));
	
	deMessages.Insert(75, NStr("en = 'Error executing algorithm after parameter value import'"));
	
	deMessages.Insert(76, NStr("en = 'AfterExportObjectToFile event handler error'"));
	
	deMessages.Insert(77, NStr("en = 'The external data processor file with pluggable event handler procedures is not specified'"));
	
	deMessages.Insert(78, NStr("en = 'Error creating external data processor from file with event handler procedures'"));
	
	deMessages.Insert(79, NStr("en = 'The algorithm code cannot be integrated into the handler because the recursive algorithm call has been detected. 
	                         |Select ""Do not debug algorithms"" if it is not required to debug algorithm code or
	                         |select ""Debug algorithms as procedures"" if it required to debug algorithms with recursive calls. Than try to export data again.'"));
	
	deMessages.Insert(80, NStr("en = 'You must have the full rights to execute the data exchange'"));
	
	deMessages.Insert(1000, NStr("en = 'Error creating temporary data export file'"));

EndProcedure

Procedure SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MDObject, TypeName, Manager, TypeNamePrefix, SearchByPredefinedPossible = False)
	
	Name          = MDObject.Name;
	RefTypeString = TypeNamePrefix + "." + Name;
	SearchString  = "SELECT Ref FROM " + TypeName + "." + Name + " WHERE ";
	RefType       = Type(RefTypeString);
	Structure = New Structure("Name,TypeName,RefTypeString,Manager,MDObject,SearchString,SearchByPredefinedPossible,OCR", Name, TypeName, RefTypeString, Manager, MDObject, SearchString, SearchByPredefinedPossible);
	Managers.Insert(RefType, Structure);
	
	
	StructureForExchangePlan = New Structure("Name,RefType,IsReferenceType,IsRegister", Name, RefType, True, False);
	ManagersForExchangePlans.Insert(MDObject, StructureForExchangePlan);
	
EndProcedure

Procedure SupplementManagerArrayWithRegisterType(Managers, MDObject, TypeName, Manager, TypeNamePrefixRecord, SelectionTypeNamePrefix)
	
	Periodical = Undefined;
	
	Name           = MDObject.Name;
	RefTypeString	= TypeNamePrefixRecord + "." + Name;
	RefType			   = Type(RefTypeString);
	Structure      = New Structure("Name,TypeName,RefTypeString,Manager,MDObject,SearchByPredefinedPossible,OCR", Name, TypeName, RefTypeString, Manager, MDObject, False);
	
	If TypeName = "InformationRegister" Then
		
		Periodical = (MDObject.InformationRegisterPeriodicity <> Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical);
		SubordinatedToRecorder = (MDObject.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.RecorderSubordinate);
		
		Structure.Insert("Periodical", Periodical);
		Structure.Insert("SubordinatedToRecorder", SubordinatedToRecorder);
		
	EndIf;	
	
	Managers.Insert(RefType, Structure);
		

	StructureForExchangePlan = New Structure("Name,RefType,IsReferenceType,IsRegister", Name, RefType, False, True);
	ManagersForExchangePlans.Insert(MDObject, StructureForExchangePlan);
	
	
	RefTypeString = SelectionTypeNamePrefix + "." + Name;
	RefType			  = Type(RefTypeString);
	Structure     = New Structure("Name,TypeName,RefTypeString,Manager,MDObject,SearchByPredefinedPossible,OCR", Name, TypeName, RefTypeString, Manager, MDObject, False);
	
	If Periodical <> Undefined Then
		
		Structure.Insert("Periodical", Periodical);
		Structure.Insert("SubordinatedToRecorder", SubordinatedToRecorder);	
		
	EndIf;
	
	Managers.Insert(RefType, Structure);	
		
EndProcedure

// Initializes the Managers variable, which contains a mapping of object types to their properties.
// 
Procedure ManagerInitialization()

	Managers = New Map;
	
	ManagersForExchangePlans = New Map;
    	
	// REFERENCES
	
	For Each MDObject In Metadata.Catalogs Do
		
		SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MDObject, "Catalog", Catalogs[MDObject.Name], "CatalogRef", True);
					
	EndDo;

	For Each MDObject In Metadata.Documents Do
		
		SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MDObject, "Document", Documents[MDObject.Name], "DocumentRef");
				
	EndDo;

	For Each MDObject In Metadata.ChartsOfCharacteristicTypes Do
		
		SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MDObject, "ChartOfCharacteristicTypes", ChartsOfCharacteristicTypes[MDObject.Name], "ChartOfCharacteristicTypesRef", True);
				
	EndDo;
	
	For Each MDObject In Metadata.ChartsOfAccounts Do
		
		SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MDObject, "ChartOfAccounts", ChartsOfAccounts[MDObject.Name], "ChartOfAccountsRef", True);
						
	EndDo;
	
	For Each MDObject In Metadata.ChartsOfCalculationTypes Do
		
		SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MDObject, "ChartOfCalculationTypes", ChartsOfCalculationTypes[MDObject.Name], "ChartOfCalculationTypesRef", True);
				
	EndDo;
	
	For Each MDObject In Metadata.ExchangePlans Do
		
		SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MDObject, "ExchangePlan", ExchangePlans[MDObject.Name], "ExchangePlanRef");
				
	EndDo;
	
	For Each MDObject In Metadata.Tasks Do
		
		SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MDObject, "Task", Tasks[MDObject.Name], "TaskRef");
				
	EndDo;
	
	For Each MDObject In Metadata.BusinessProcesses Do
		
		SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MDObject, "BusinessProcess", BusinessProcesses[MDObject.Name], "BusinessProcessRef");
		
		TypeName = "BusinessProcessRoutePoint";
		// Route point references
   Name                = MDObject.Name;
		Manager             = BusinessProcesses[Name].RoutePoints;
		SearchString        = "";

		RefTypeString       = "BusinessProcessRoutePointRef." + Name;
		RefType             = Type(RefTypeString);
		Structure = New Structure("Name,TypeName,RefTypeString,Manager,MDObject,OCR,EmptyRef,SearchByPredefinedPossible,SearchString", Name, 
			TypeName, RefTypeString, Manager, MDObject, , Undefined, False, SearchString);		
		Managers.Insert(RefType, Structure);
				
	EndDo;
	
	// REGISTERS

	For Each MDObject In Metadata.InformationRegisters Do
		
		SupplementManagerArrayWithRegisterType(Managers, MDObject, "InformationRegister", InformationRegisters[MDObject.Name], "InformationRegisterRecord", "InformationRegisterSelection");
						
	EndDo;

	For Each MDObject In Metadata.AccountingRegisters Do
		
		SupplementManagerArrayWithRegisterType(Managers, MDObject, "AccountingRegister", AccountingRegisters[MDObject.Name], "AccountingRegisterRecord", "AccountingRegisterSelection");
				
	EndDo;
	
	For Each MDObject In Metadata.AccumulationRegisters Do
		
		SupplementManagerArrayWithRegisterType(Managers, MDObject, "AccumulationRegister", AccumulationRegisters[MDObject.Name], "AccumulationRegisterRecord", "AccumulationRegisterSelection");
						
	EndDo;
	
	For Each MDObject In Metadata.CalculationRegisters Do
		
		SupplementManagerArrayWithRegisterType(Managers, MDObject, "CalculationRegister", CalculationRegisters[MDObject.Name], "CalculationRegisterRecord", "CalculationRegisterSelection");
						
	EndDo;
	
	TypeName = "Enum";
	
	For Each MDObject In Metadata.Enums Do
		
		Name          = MDObject.Name;
		Manager       = Enums[Name];
		RefTypeString = "EnumRef." + Name;
		RefType       = Type(RefTypeString);
		Structure = New Structure("Name,TypeName,RefTypeString,Manager,MDObject,OCR,EmptyRef,SearchByPredefinedPossible", Name, TypeName, RefTypeString, Manager, MDObject, , Enums[Name].EmptyRef(), False);
		Managers.Insert(RefType, Structure);
		
	EndDo;	
	
	// Constants
	TypeName            = "Constants";
	MDObject            = Metadata.Constants;
	Name                = "Constants";
	Manager             = Constants;
	RefTypeString = "ConstantsSet";
	RefType       = Type(RefTypeString);

	Structure = New Structure("Name,TypeName,RefTypeString,Manager,MDObject,SearchByPredefinedPossible,OCR", Name, TypeName, RefTypeString, Manager, MDObject, False);
	Managers.Insert(RefType, Structure);
	
EndProcedure

// Initializes object managers and all data exchange protocol messages.
// 
Procedure InitManagersAndMessages() Export
	
	If Managers = Undefined Then
		ManagerInitialization();
	EndIf; 

	If deMessages = Undefined Then
		InitMessages();
	EndIf;
	
EndProcedure

Procedure CreateConversionStructure()
	
	Conversion  = New Structure("BeforeDataExport, AfterDataExport, BeforeExportObject, AfterExportObject, BeforeObjectConversion, BeforeImportObject, AfterImportObject, BeforeDataImport, AfterDataImport");
	
EndProcedure

// Initializes data processor attributes and modular variables.
// 
Procedure InitAttributesAndModuleVariables()

	ProcessedObjectNumberToUpdateStatus = 100;
	
	RememberImportedObjects    = True;
	ImportedObjectToStoreCount = 5000;
	
	ParametersInitialized      = False;

	
	PerformAdditionalWriteToXMLControl = False;
	DirectReadingInTargetInfobase = False;
	DontShowInfoMessagesToUser = False;
	
	Managers    = Undefined;
	deMessages  = Undefined;
	
	ErrorFlag   = False;
	
	CreateConversionStructure();
	
	Rules                    = New Structure;
	Algorithms               = New Structure;
	AdditionalDataProcessors = New Structure;
	Queries                  = New Structure;

	Parameters                 = New Structure;
	EventsAfterParameterImport = New Structure;
	
	AdditionalDataProcessorParameters = New Structure;
	
	// Types
	deStringType                 = Type("String");
	deBooleanType                = Type("Boolean");
	deNumberType                 = Type("Number");
	deDateType                   = Type("Date");
	deValueStorageType           = Type("ValueStorage");
	deUUIDType                   = Type("UUID");
	deBinaryDataType             = Type("BinaryData");
	deAccumulationRecordTypeType = Type("AccumulationRecordType");
	deObjectDeletionType         = Type("ObjectDeletion");
	deAccountTypeType			       = Type("AccountType");
	deTypeType                   = Type("Type");
	deMapType                    = Type("Map");


	EmptyDateValue		   = Date('00010101');
	
	mXMLRules  = Undefined;
	
	// XML node types
	
	deXMLNodeType_EndElement   = XMLNodeType.EndElement;
	deXMLNodeType_StartElement = XMLNodeType.StartElement;
	deXMLNodeType_Text         = XMLNodeType.Text;


	mExchangeRuleTemplateList  = New ValueList;

	For Each Template In ThisObject.Metadata().Templates Do
		mExchangeRuleTemplateList.Add(Template.Synonym);
	EndDo; 
	    	
	mDataLogFile = Undefined;
	
	InfobaseConnectionType = True;
	InfobaseConnectionWindowsAuthentication = False;
	InfobaseConnectionPlatformVersion = "V8";
	OpenExchangeLogsAfterOperationsExecuted = False;
	ImportDataInExchangeMode = True;
	WriteOnlyChangedObjectsToInfobase = True;
	WriteRegisterRecordsAsRecordSets = True;
	OptimizedObjectWriting = True;
	ExportAllowedOnly = True;
	ImportObjectsByRefWithoutDeletionMark = True;	
	UseFilterByDateForAllObjects = True;
	
	mEmptyTypeValueMap = New Map;
	mTypeDescriptionMap = New Map;
	
	mExchangeRulesReadOnImport = False;

	ReadEventHandlersFromExchangeRuleFile = True;
	
	mDataProcessingModes = New Structure;
	mDataProcessingModes.Insert("Export",             0);
	mDataProcessingModes.Insert("Import",             1);
	mDataProcessingModes.Insert("ExchangeRuleImport", 2);
	mDataProcessingModes.Insert("EventHandlerExport", 3);

	
	DataProcessingMode = mDataProcessingModes.Data;
	
	mAlgorithmDebugModes = New Structure;
	mAlgorithmDebugModes.Insert("DontUse",         0);
	mAlgorithmDebugModes.Insert("ProceduralCall",  1);
	mAlgorithmDebugModes.Insert("CodeIntegration", 2);

	
	AlgorithmDebugMode = mAlgorithmDebugModes.DontUse;
	
EndProcedure

Function VerifyParameterCountForConnectingInfobase(ConnectionStructure, ConnectionString = "", ErrorMessageString = "")
	
	ErrorsExist = False;
	
	If ConnectionStructure.FileMode  Then
		
		If IsBlankString(ConnectionStructure.InfobaseDirectory) Then
			
			ErrorMessageString = NStr("en='The target infobase directory is not specified.'");
			
			MessageToUser(ErrorMessageString);
			
			ErrorsExist = True;
			
		EndIf;
		
		ConnectionString = "Файл=""" + ConnectionStructure.InfobaseDirectory + """";
	Else
		
		If IsBlankString(ConnectionStructure.ServerName) Then
			
			ErrorMessageString = NStr("en='The target infobase platform server name is not specified.'");
			
			MessageToUser(ErrorMessageString);
			
			ErrorsExist = True;
			
		EndIf;
		
		If IsBlankString(ConnectionStructure.InfobaseNameAtServer) Then
			
			ErrorMessageString = NStr("en='The target infobase name on the platform server is not specified.'");
			
			MessageToUser(ErrorMessageString);
			
			ErrorsExist = True;
			
		EndIf;		
		
		ConnectionString = "Srvr = """ + ConnectionStructure.ServerName + """; Ref = """ + ConnectionStructure.InfobaseNameAtServer + """";		
		
	EndIf;
	
	Return Not ErrorsExist;	
	
EndFunction

Function ConnectToInfobase(ConnectionStructure, ErrorMessageString = "")
	
	Var ConnectionString;
	
	EnoughParameters = VerifyParameterCountForConnectingInfobase(ConnectionStructure, ConnectionString, ErrorMessageString);
	
	If Not EnoughParameters Then
		Return Undefined;
	EndIf;
	
	If Not ConnectionStructure.OSAuthentication Then
		If Not IsBlankString(ConnectionStructure.User) Then
			ConnectionString = ConnectionString + ";Usr = """ + ConnectionStructure.User + """";
		EndIf;
		If Not IsBlankString(ConnectionStructure.Password) Then
			ConnectionString = ConnectionString + ";Pwd = """ + ConnectionStructure.Password + """";
		EndIf;
	EndIf;
	
	//"V82" or "V83"
	ConnectionObject = ConnectionStructure.PlatformVersion;
	
	ConnectionString = ConnectionString + ";";
	
	Try
		
		ConnectionObject = ConnectionObject +".COMConnector";
		CurrentCOMConnection = New COMObject(ConnectionObject);
		CurCOMObject = CurrentCOMConnection.Connect(ConnectionString);
		
	Except
		
		ErrorMessageString = NStr("en = 'Establishing the connection with the COM server failed with the following error:
			|%1'");
		ErrorMessageString = SubstituteParametersInString(ErrorMessageString, ErrorDescription());
		
		MessageToUser(ErrorMessageString);
		
		Return Undefined;
		
	EndTry;
	
	Return CurCOMObject;
	
EndFunction

// Returns the string part that follows the last specified character.
Function GetStringAfterCharacter(Val SourceString, Val SearchChar)
	
	CharPosition = StrLen(SourceString);
	While CharPosition >= 1 Do
		
		If Mid(SourceString, CharPosition, 1) = SearchChar Then
						
			Return Mid(SourceString, CharPosition + 1); 
			
		EndIf;
		
		CharPosition = CharPosition - 1;	
	EndDo;

	Return "";
  	
EndFunction

// Returns the extension of the fail (characters after the latest dot).
//
// Parameters
//  FileName - String - file name with or without the directory name.
//
// Returns:
//   String – file extension.
//

Function GetFileNameExtension(Val FileName) Export
	
	Extension = GetStringAfterCharacter(FileName, ".");
	Return Extension;
	
EndFunction

Function GetProtocolNameForCOMConnectionSecondInfobase()
	
	If Not IsBlankString(ImportExchangeLogFileName) Then
			
		Return ImportExchangeLogFileName;	
		
	ElsIf Not IsBlankString(ExchangeLogFileName) Then
		
		LogFileExtension = GetFileNameExtension(ExchangeLogFileName);
		
		If Not IsBlankString(LogFileExtension) Then
							
			ExportLogFileName = StrReplace(ExchangeLogFileName, "." + LogFileExtension, "");
			
		EndIf;
		
		ExportLogFileName = ExportLogFileName + "_Import";
		
		If Not IsBlankString(LogFileExtension) Then
			
			ExportLogFileName = ExportLogFileName + "." + LogFileExtension;	
			
		EndIf;
		
		Return ExportLogFileName;
		
	EndIf;
	
	Return "";
	
EndFunction

// Establishing the connection to the target infobase by the specified parameters.
// Returns the initialized UniversalDataExchangeXML target infobase data processor,
// which is used for importing data into the target infobase.
// 
//  Returns:
//  DataProcessorObject – UniversalDataExchangeXML – target infobase data processor,
//                        which is used for importing data into the target infobase.
//

Function EstablishConnectionWithTargetInfobase() Export
	
	ConnectionResult = Undefined;
	
	ConnectionStructure = New Structure();
	ConnectionStructure.Insert("FileMode", InfobaseConnectionType);
	ConnectionStructure.Insert("OSAuthentication", InfobaseConnectionWindowsAuthentication);
	ConnectionStructure.Insert("InfobaseDirectory", InfobaseConnectionDirectory);
	ConnectionStructure.Insert("ServerName", InfobaseConnectionServerName);
	ConnectionStructure.Insert("InfobaseNameAtServer", InfobaseConnectionNameOnServer);
	ConnectionStructure.Insert("User", InfobaseUserForConnection);
	ConnectionStructure.Insert("Password", InfobaseConnectionPassword);
	ConnectionStructure.Insert("PlatformVersion", InfobaseConnectionPlatformVersion);
	
	ConnectionObject = ConnectToInfobase(ConnectionStructure);
	
	If ConnectionObject = Undefined Then
		Return Undefined;
	EndIf;
	
	Try
		ConnectionResult = ConnectionObject.DataProcessors.UniversalDataExchangeXML.Create();
	Except
		
		Text = NStr("en='Creating the UniversalDataExchangeXML data processor failed with the following error: %1'");
		Text = SubstituteParametersInString(Text, BriefErrorDescription(ErrorInfo()));
		MessageToUser(Text);
		ConnectionResult = Undefined;
	EndTry;
	
	If ConnectionResult <> Undefined Then
		
		ConnectionResult.UseTransactions = UseTransactions;	
		ConnectionResult.ObjectCountPerTransaction = ObjectCountPerTransaction;
		
		ConnectionResult.DebugModeFlag = DebugModeFlag;
		
		ConnectionResult.ExchangeLogFileName = GetProtocolNameForCOMConnectionSecondInfobase();
								
		ConnectionResult.AppendDataToExchangeLog = AppendDataToExchangeLog;
		ConnectionResult.WriteInfoMessagesToLog = WriteInfoMessagesToLog;
		
		ConnectionResult.ExchangeMode = "Import";
		
	EndIf;
	
	Return ConnectionResult;
	
EndFunction

// Deletes objects of the specified type according to the data clearing rules
// (deletes physically or marks for deletion).

//
// Parameters:
//  TypeNameToRemove - String - type name string.
// 
Procedure DeleteObjectsOfType(TypeNameToRemove) Export
	
	DataToDeleteType = Type(TypeNameToRemove);
	
	Manager     = Managers[DataToDeleteType];
	TypeName    = Manager.TypeName;
	Name        = Manager.Name;	
	Properties  = Managers[DataToDeleteType];

	
	Rule = New Structure("Name,Directly,BeforeDelete", "ObjectDeletion", True, "");
					
	Selection = GetSelectionForDataClearingExport(Properties, TypeName, True, True, False);
	
	While Selection.Next() Do
		
		If TypeName =  "InformationRegister" Then
			
			RecordManager = Properties.Manager.CreateRecordManager(); 
			FillPropertyValues(RecordManager, Selection);
								
			SelectionObjectDeletion(RecordManager, Rule, Properties, Undefined);
				
		Else
				
			SelectionObjectDeletion(Selection.Ref.GetObject(), Rule, Properties, Undefined);
				
		EndIf;
			
	EndDo;	
	
EndProcedure

Procedure SupplementServiceTablesWithColumns()
	
	InitConversionRuleTable();
	InitExportRuleTable();
	CleaningRuleTableInitialization();
	InitializationParameterSetupTable();	
	
EndProcedure

// Initializes external data processor with event handler debugging module.
//
// Parameters:
//  ExecutionPossible - Boolean - flag that shows that external data processor is
//                      initialized successfully.
//  OwnerObject       - DataProcessorObject - object to be an owner of the initialized 
//                      external data processor.
//  
Procedure InitEventHandlerExternalDataProcessor(ExecutionPossible, OwnerObject) Export
	
	If Not ExecutionPossible Then
		Return;
	EndIf; 
	
	If HandlerDebugModeFlag And IsBlankString(EventHandlerExternalDataProcessorFileName) Then
		
		WriteToExecutionLog(77); 
		ExecutionPossible = False;
		
	ElsIf HandlerDebugModeFlag Then
		
		Try
			
			If IsExternalDataProcessor() Then
				
				EventHandlerExternalDataProcessor = ExternalDataProcessors.Create(EventHandlerExternalDataProcessorFileName, False);
				
			Else
				
				EventHandlerExternalDataProcessor = DataProcessors[EventHandlerExternalDataProcessorFileName].Create();
				
			EndIf;
			
			EventHandlerExternalDataProcessor.Constructor(OwnerObject);
			
		Except
			
			EventHandlerExternalDataProcessorDestructor();
			
			MessageToUser(BriefErrorDescription(ErrorInfo()));
			WriteToExecutionLog(78);
			
			ExecutionPossible               = False;
			HandlerDebugModeFlag = False;
			
		EndTry;
		
	EndIf;
	
	If ExecutionPossible Then
		
		CommonProceduresFunctions = ThisObject;
		
	EndIf; 
	
EndProcedure

// External data processor destructor.
//
Procedure EventHandlerExternalDataProcessorDestructor(DebugModeEnabled = False) Export
	
	If Not DebugModeEnabled Then
		
		If EventHandlerExternalDataProcessor <> Undefined Then
			
			Try
				
				EventHandlerExternalDataProcessor.Destructor();
				
			Except
				MessageToUser(BriefErrorDescription(ErrorInfo()));
			EndTry; 
			
		EndIf; 
		
		EventHandlerExternalDataProcessor = Undefined;
		CommonProceduresFunctions               = Undefined;
		
	EndIf;
	
EndProcedure

// Deletes temporary files with the specified name.
//
// Parameters:
//  TempFileName - String - full name of the file to be deleted. The value is cleared once the procedure is executed.
//  
Procedure DeleteTempFiles(TempFileName) Export
	
	If Not IsBlankString(TempFileName) Then
		
		Try
			
			DeleteFiles(TempFileName);
			
			TempFileName = "";
			
		Except
		EndTry; 
		
	EndIf; 
	
EndProcedure  

Function GetNewUniqueTempFileName(Prefix, Extension, OldTempFileName)
	
	//Deleting the previous temporary file
	DeleteTempFiles(OldTempFileName);
	
	UUID = New UUID();
	
	Prefix    = ?(IsBlankString(Prefix), "", Prefix + "_");
	
	Extension = ?(IsBlankString(Extension), "", "." + Extension);
	
	Return TempFilesDir() + Prefix + UUID + Extension;
EndFunction 

Procedure InitHandlerNamesStructure()
	
	//Conversion handlers
	ConversionHandlerNames = New Structure;
	ConversionHandlerNames.Insert("BeforeDataExport");
	ConversionHandlerNames.Insert("AfterDataExport");
	ConversionHandlerNames.Insert("BeforeExportObject");
	ConversionHandlerNames.Insert("AfterExportObject");
	ConversionHandlerNames.Insert("BeforeObjectConversion");
	ConversionHandlerNames.Insert("BeforeSendDeletionInfo");
	ConversionHandlerNames.Insert("BeforeGetChangedObjects");
	
	ConversionHandlerNames.Insert("BeforeImportObject");
	ConversionHandlerNames.Insert("AfterImportObject");
	ConversionHandlerNames.Insert("BeforeDataImport");
	ConversionHandlerNames.Insert("AfterDataImport");
	ConversionHandlerNames.Insert("OnGetDeletionInfo");
	ConversionHandlerNames.Insert("AfterReceiveExchangeNodeDetails");
	
	ConversionHandlerNames.Insert("AfterExchangeRuleImport");
	ConversionHandlerNames.Insert("AfterParameterImport");
	
	//OCR handlers
	OCRHandlerNames = New Structure;
	OCRHandlerNames.Insert("BeforeExport");
	OCRHandlerNames.Insert("OnExport");
	OCRHandlerNames.Insert("AfterExport");
	OCRHandlerNames.Insert("AfterExportToFile");
	
	OCRHandlerNames.Insert("BeforeImport");
	OCRHandlerNames.Insert("OnImport");
	OCRHandlerNames.Insert("AfterImport");
	
	OCRHandlerNames.Insert("SearchFieldSequence");
	
	//PCR handlers
	PCRHandlerNames = New Structure;
	PCRHandlerNames.Insert("BeforeExport");
	PCRHandlerNames.Insert("OnExport");
	PCRHandlerNames.Insert("AfterExport");

	//PGCR handlers
	PGCRHandlerNames = New Structure;
	PGCRHandlerNames.Insert("BeforeExport");
	PGCRHandlerNames.Insert("OnExport");
	PGCRHandlerNames.Insert("AfterExport");
	
	PGCRHandlerNames.Insert("BeforeProcessExport");
	PGCRHandlerNames.Insert("AfterProcessExport");
	
	//DER handlers
	DERHandlerNames = New Structure;
	DERHandlerNames.Insert("BeforeProcess");
	DERHandlerNames.Insert("AfterProcess");
	DERHandlerNames.Insert("BeforeExport");
	DERHandlerNames.Insert("AfterExport");
	
	//DCR handlers
	DCPHandlerNames = New Structure;
	DCPHandlerNames.Insert("BeforeProcess");
	DCPHandlerNames.Insert("AfterProcess");
	DCPHandlerNames.Insert("BeforeDelete");
	
	//Global structure with handler names
	HandlerNames = New Structure;
	HandlerNames.Insert("Conversion",  ConversionHandlerNames); 
	HandlerNames.Insert("OCR",         OCRHandlerNames); 
	HandlerNames.Insert("PCR",         PCRHandlerNames); 
	HandlerNames.Insert("PGCR",        PGCRHandlerNames); 
	HandlerNames.Insert("DER",         DERHandlerNames); 
	HandlerNames.Insert("DCP",         DCPHandlerNames); 
	
EndProcedure  

// Displays a message to a user.
//
// Parameters:
// MessageToUserText - String - message text.
//
Procedure MessageToUser(MessageToUserText) Export
	
	Message = New UserMessage;
	Message.Text = MessageToUserText;
	Message.Message();
	
EndProcedure

// Substitutes parameters in a string. The maximum number of parameters is 9.
// Parameters in the string have the following format: %<parameter number>. 
// The parameter numbering starts from 1.
//
// Parameters:
//  SubstitutionString - String - string pattern that contains parameters (occurrences of %"ParameterName").
//  Parameter<n>       - String - parameter for substitution.
//
// Returns:
//  String - text string with the substituted parameters.
//
// Example:
//  SubstituteParametersInString(NStr("en='%1 went to %2'"), "John", "the Zoo") = "John went to the Zoo".
//
Function SubstituteParametersInString(Val SubstitutionString,
	Val Parameter1, Val Parameter2 = Undefined, Val Parameter3 = Undefined,
	Val Parameter4 = Undefined, Val Parameter5 = Undefined, Val Parameter6 = Undefined,
	Val Parameter7 = Undefined, Val Parameter8 = Undefined, Val Parameter9 = Undefined) Export
	
	SubstitutionString = StrReplace(SubstitutionString, "%1", Parameter1);
	SubstitutionString = StrReplace(SubstitutionString, "%2", Parameter2);
	SubstitutionString = StrReplace(SubstitutionString, "%3", Parameter3);
	SubstitutionString = StrReplace(SubstitutionString, "%4", Parameter4);
	SubstitutionString = StrReplace(SubstitutionString, "%5", Parameter5);
	SubstitutionString = StrReplace(SubstitutionString, "%6", Parameter6);
	SubstitutionString = StrReplace(SubstitutionString, "%7", Parameter7);
	SubstitutionString = StrReplace(SubstitutionString, "%8", Parameter8);
	SubstitutionString = StrReplace(SubstitutionString, "%9", Parameter9);
	
	Return SubstitutionString;
	
EndFunction

Function IsExternalDataProcessor()
	
	Return ?(Find(EventHandlerExternalDataProcessorFileName, ".") <> 0, True, False);
	
EndFunction

Function PredefinedName(Ref)
	
	Query = New Query;
	Query.SetParameter("Ref", Ref);
	Query.Text =
	"SELECT
	| PredefinedDataName As PredefinedDataName
	|FROM
	|	" + Ref.Metadata().FullName() + " AS
	|SpecifiedTableAlias
	|WHERE SpecifiedTableAlias.Ref = &Ref
	|";
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Return Selection.PredefinedDataName;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Main application operators

InitAttributesAndModuleVariables();
SupplementServiceTablesWithColumns();
InitHandlerNamesStructure();


#EndIf