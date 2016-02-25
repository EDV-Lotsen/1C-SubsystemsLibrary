////////////////////////////////////////////////////////////////////////////////
// Object prefixation subsystem
// Object number/code generation for printing.
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Deletes the infobase prefix and the company prefix from the transmitted string ObjectNumber
// ObjectNumber Variable should conform to the template: OOGG-XXX...XX or GG-XXX...XX, where
// OO       - company prefix;
// GG       - infobase prefix;
// "-"      - separator;
// XXX...XX - object number/code.
// insignificant prefix characters (zero - "0") are also removed.
//
// Parameters:
//  ObjectNumber         - String             - object number or object code whose prefixes should be deleted
//  DeleteCompanyPrefix  - Boolean (optional) - company prefix deletion flag; the default is False;
//  DeleteInfobasePrefix - Boolean (optional) - infobase prefix deletion flag; the default is False;
//
// Examples:
//  DeletePrefixesFromObjectNumber("0FGL-000001234", True, True)  = "000001234"
//  DeletePrefixesFromObjectNumber("0FGL-000001234", False, True) = "F-000001234"
//  DeletePrefixesFromObjectNumber("0FGL-000001234", True, False) = "CH-000001234"
//  DeletePrefixesFromObjectNumber("0FGL-000001234", False, False)= "FGL-000001234"
//
Function DeletePrefixesFromObjectNumber(Val ObjectNumber, DeleteCompanyPrefix = False, DeleteInfobasePrefix = False) Export
	
	If Not NumberContainsStandardPrefix(ObjectNumber) Then
		Return ObjectNumber;
	EndIf;
	
	// an initially empty object number prefix string
	ObjectPrefix = "";
	
	NumberContainsFiveDigitPrefix = NumberContainsFiveDigitPrefix(ObjectNumber);
	
	If NumberContainsFiveDigitPrefix Then
		CompanyPrefix  = Left(ObjectNumber, 2);
		InfobasePrefix = Mid(ObjectNumber, 3, 2);
	Else
		CompanyPrefix  = "";
		InfobasePrefix = Left(ObjectNumber, 2);
	EndIf;
	
	CompanyPrefix  = StrReplace(CompanyPrefix, "0", "");
	InfobasePrefix = StrReplace(InfobasePrefix, "0", "");
	
	// add company prefix
	If Not DeleteCompanyPrefix Then
		
		ObjectPrefix = ObjectPrefix + CompanyPrefix;
		
	EndIf;
	
	// add infobase prefix
	If Not DeleteInfobasePrefix Then
		
		ObjectPrefix = ObjectPrefix + InfobasePrefix;
		
	EndIf;
	
	If Not IsBlankString(ObjectPrefix) Then
		
		ObjectPrefix = ObjectPrefix + "-";
		
	EndIf;
	
	Return ObjectPrefix + Mid(ObjectNumber, ?(NumberContainsFiveDigitPrefix, 6, 4));
EndFunction

// Deletes leading zeros from the object number
// ObjectNumber Variable should conform to the template: OOGG-XXX...XX or GG-XXX...XX, where
// OO       - company prefix;
// GG       - infobase prefix;
// "-"      - separator;
// XXX...XX - object number/code.
//
// Parameters:
//  ObjectNumber - String - object number or object code whose leading zeros should be deleted
// 
Function DeleteLeadingZerosFromObjectNumber(Val ObjectNumber) Export
	
	CustomPrefix = GetCustomPrefix(ObjectNumber);
	
	If NumberContainsStandardPrefix(ObjectNumber) Then
		
		If NumberContainsFiveDigitPrefix(ObjectNumber) Then
			Prefix = Left(ObjectNumber, 5);
			Number = Mid(ObjectNumber, 6 + StrLen(CustomPrefix));
		Else
			Prefix = Left(ObjectNumber, 3);
			Number = Mid(ObjectNumber, 4 + StrLen(CustomPrefix));
		EndIf;
		
	Else
		
		Prefix = "";
		Number = Mid(ObjectNumber, 1 + StrLen(CustomPrefix));
		
	EndIf;
	
	// left delete leading zeroes from the number
	Number = StringFunctionsClientServer.DeleteDuplicatedChars(Number, "0");
	
	Return Prefix + CustomPrefix + Number;
EndFunction

// Deletes all custom prefixes from the object number (all non-numeric characters)
// ObjectNumber Variable should conform to the template: OOGG-XXX...XX or GG-XXX...XX, where
// OO       - company prefix;
// GG       - infobase prefix;
// "-"      - separator;
// XXX...XX - object number/code.
//
// Parameters:
//  ObjectNumber - String - object number or object code whose leading zeros should be deleted
// 
Function DeleteCustomPrefixesFromObjectNumber(Val ObjectNumber) Export
	
	DigitalCharacterString = "0123456789";
	
	If NumberContainsStandardPrefix(ObjectNumber) Then
		
		If NumberContainsFiveDigitPrefix(ObjectNumber) Then
			Prefix     = Left(ObjectNumber, 5);
			FullNumber = Mid(ObjectNumber, 6);
		Else
			Prefix     = Left(ObjectNumber, 3);
			FullNumber = Mid(ObjectNumber, 4);
		EndIf;
		
	Else
		
		Prefix     = "";
		FullNumber = ObjectNumber;
		
	EndIf;
	
	Number = "";
	
	For Index = 1 To StrLen(FullNumber) Do
		
		Char = Mid(FullNumber, Index, 1);
		
		If Find(DigitalCharacterString, Char) > 0 Then
			
			Number = Number + Char;
			
		EndIf;
		
	EndDo;
	
	Return Prefix + Number;
EndFunction

// Gets the custom object number/code prefix
// ObjectNumber Variable should conform to the template: OOGG-XXX...XX or GG-XXX...XX, where
// OO     - company prefix;
// GG     - infobase prefix;
// "-"    - separator;
// AA     - custom prefix;
// XX..XX - object number/code.
//
// Parameters:
//  ObjectNumber - String - object number or object code from which the custom prefix should be extracted
// 
Function GetCustomPrefix(Val ObjectNumber) Export
	
	// return value (custom prefix)
	Result = "";
	
	If NumberContainsStandardPrefix(ObjectNumber) Then
		
		If NumberContainsFiveDigitPrefix(ObjectNumber) Then
			ObjectNumber = Mid(ObjectNumber, 6);
		Else
			ObjectNumber = Mid(ObjectNumber, 4);
		EndIf;
		
	EndIf;
	
	DigitalCharacterString = "0123456789";
	
	For Index = 1 To StrLen(ObjectNumber) Do
		
		Char = Mid(ObjectNumber, Index, 1);
		
		If Find(DigitalCharacterString, Char) > 0 Then
			Break;
		EndIf;
		
		Result = Result + Char;
		
	EndDo;
	
	Return Result;
EndFunction

// Gets the document number for printing; the prefixes and leading zeros should be deleted from the number
// Function:
// discards company prefix,
// discards infobase prefix (optional),
// discards custom prefixes (optional),
// deletes leading zeros from the object number
//
Function GetNumberForPrinting(Val ObjectNumber, DeleteInfobasePrefix = False, DeleteCustomPrefix = False) Export
	
	// {Handler: OnGetNumberForPrinting} Begin
	StandardProcessing = True;
	
	ObjectPrefixationClientServerOverridable.OnGetNumberForPrinting(ObjectNumber, StandardProcessing);
	
	If StandardProcessing = False Then
		Return ObjectNumber;
	EndIf;
	// {Handler: OnGetNumberForPrinting} End
	
	// delete custom prefixes from the object number
	If DeleteCustomPrefix Then
		
		ObjectNumber = DeleteCustomPrefixesFromObjectNumber(ObjectNumber);
		
	EndIf;
	
	// delete leading zeros from the object number
	ObjectNumber = DeleteLeadingZerosFromObjectNumber(ObjectNumber);
	
	// delete company prefix and infobase prefix from the object number
	ObjectNumber = DeletePrefixesFromObjectNumber(ObjectNumber, True, DeleteInfobasePrefix);
	
	Return ObjectNumber;
EndFunction

#EndRegion

#Region InternalProceduresAndFunctions

Function NumberContainsStandardPrefix(Val ObjectNumber)
	
	SeparatorPosition = Find(ObjectNumber, "-");
	
	Return SeparatorPosition = 3
		Or SeparatorPosition = 5
	;
EndFunction

Function NumberContainsFiveDigitPrefix(Val ObjectNumber)
	
	Return Find(ObjectNumber, "-") = 5;
	
EndFunction

#EndRegion
