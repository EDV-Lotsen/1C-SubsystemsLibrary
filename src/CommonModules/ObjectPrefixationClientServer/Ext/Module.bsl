////////////////////////////////////////////////////////////////////////////////
// Object prefixation subsystem.
// Creating an object number or code for print forms.
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Deletes infobase and company prefixes from the passed ObjectNumber string. 
// The ObjectNumber string must match the following pattern: CCBB-XXX...XX or
// BBXXX...XX, where:
// CC  - company prefix;
// BB  - infobase prefix;
// "-" - separator;
// XXX...XX - object number or code.
// Prefix insignificant characters (zero character - "0") are deleted anyway.
//
// Parameters:
//  ObjectNumber         - String - object number or code whose prefix will be deleted.
//  DeleteCompanyPrefix  - Boolean (Optional) - flag that shows whether the company
//                         prefix will be deleted. The default value is False.
//  DeleteInfoBasePrefix - Boolean (Optional) - flag that shows whether the infobase
//                         prefix will be deleted. The default value is False.
//
// Examples:
//  DeletePrefixesFromObjectNumber("0CMN-000001234", True, True)   = "000001234"
//  DeletePrefixesFromObjectNumber("0CMN-000001234", False, True)  = "C-000001234"
//  DeletePrefixesFromObjectNumber("0CMN-000001234", True, False)  = "MN-000001234"
//  DeletePrefixesFromObjectNumber("0CMN-000001234", False, False) = "CMN-000001234"
//
Function DeletePrefixesFromObjectNumber(Val ObjectNumber, DeleteCompanyPrefix = False, DeleteInfoBasePrefix = False) Export
	
	If Not NumberContainsStandardPrefix(ObjectNumber) Then
		Return ObjectNumber;
	EndIf;
	
	// Creating the empty initial object number prefix string
	ObjectPrefix = "";
	
	NumberContainsFiveDigitPrefix = NumberContainsFiveDigitPrefix(ObjectNumber);
	
	If NumberContainsFiveDigitPrefix Then
		CompanyPrefix  = Left(ObjectNumber, 2);
		InfoBasePrefix = Mid(ObjectNumber, 3, 2);
	Else
		CompanyPrefix  = "";
		InfoBasePrefix = Left(ObjectNumber, 2);
	EndIf;
	
	CompanyPrefix  = StrReplace(CompanyPrefix, "0", "");
	InfoBasePrefix = StrReplace(InfoBasePrefix, "0", "");
	
	// Adding the company prefix
	If Not DeleteCompanyPrefix Then
		
		ObjectPrefix = ObjectPrefix + CompanyPrefix;
		
	EndIf;
	
	// Adding the infobase prefix
	If Not DeleteInfoBasePrefix Then
		
		ObjectPrefix = ObjectPrefix + InfoBasePrefix;
		
	EndIf;
	
	If Not IsBlankString(ObjectPrefix) Then
		
		ObjectPrefix = ObjectPrefix + "-";
		
	EndIf;
	
	Return ObjectPrefix + Mid(ObjectNumber, ?(NumberContainsFiveDigitPrefix, 6, 4));
EndFunction

// Deletes leading zeros from the object number.
// The ObjectNumber string must match the following pattern: CCBB-XXX...XX or
// BBXXX...XX, where:
// CC - company prefix;
// BB - infobase prefix;
// "-" - separator;
// XXX...XX - object number or code.
//
// Parameters:
//  ObjectNumber - String - object number or code where leading zeroes will be deleted.
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
	
	// Deleting leading zeros on the left of the number.
	Number = StringFunctionsClientServer.DeleteDuplicatedChars(Number, "0");
	
	Return Prefix + CustomPrefix + Number;
EndFunction

// Deletes all custom prefixes from the object number (all nonnumeric characters). 
// The ObjectNumber string must match the following pattern: CCBB-XXX...XX or
// BBXXX...XX, where:
// CC - company prefix;
// BB - infobase prefix;
// "-" - separator;
// XXX...XX - object number or code.
//
// Parameters:
// ObjectNumber - String - object number or code where all nonnumeric characters will
//                be deleted.
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
	
	For Index = 1 to StrLen(FullNumber) Do
		
		Char = Mid(FullNumber, Index, 1);
		
		If Find(DigitalCharacterString, Char) > 0 Then
			
			Number = Number + Char;
			
		EndIf;
		
	EndDo;
	
	Return Prefix + Number;
EndFunction

// Retrieves the custom prefix of the object number or code.
// The ObjectNumber string must match the following pattern: CCBB-XXX...XX or
// BBXXX...XX, where:
// CC - company prefix;
// BB - infobase prefix;
// "-" - separator;
// XXX...XX - object number or code.
//
// Parameters:
// ObjectNumber - String - object number or code whose custom prefix will be retrieved.
// 
Function GetCustomPrefix(Val ObjectNumber) Export
	
	// Return value (custom prefix)
	Result = "";
	
	If NumberContainsStandardPrefix(ObjectNumber) Then
		
		If NumberContainsFiveDigitPrefix(ObjectNumber) Then
			ObjectNumber = Mid(ObjectNumber, 6);
		Else
			ObjectNumber = Mid(ObjectNumber, 4);
		EndIf;
		
	EndIf;
	
	DigitalCharacterString = "0123456789";
	
	For Index = 1 to StrLen(ObjectNumber) Do
		
		Char = Mid(ObjectNumber, Index, 1);
		
		If Find(DigitalCharacterString, Char) > 0 Then
			Break;
		EndIf;
		
		Result = Result + Char;
		
	EndDo;
	
	Return Result;
EndFunction

// Retrieves the document number for printing. All prefixes and leading zeroes are
// deleted from the number.
//
// Removes a company prefix.
// Removes an infobase prefix (optional).
// Removes a custom prefix (optional).
// Removes leading zeroes.
//
Function GetNumberForPrinting(Val ObjectNumber, DeleteInfoBasePrefix = False, DeleteCustomPrefix = False) Export
	
	// {Handler: OnGetNumberForPrinting} Start
	StandardProcessing = True;
	
	ObjectPrefixationClientServerOverridable.OnGetNumberForPrinting(ObjectNumber, StandardProcessing);
	
	If StandardProcessing = False Then
		Return ObjectNumber;
	EndIf;
	// {Handler: OnGetNumberForPrinting} End
	
	// Deleting custom prefixes from the object number
	If DeleteCustomPrefix Then
		
		ObjectNumber = DeleteCustomPrefixesFromObjectNumber(ObjectNumber);
		
	EndIf;
	
	// Deleting leading zeroes from the object number
	ObjectNumber = DeleteLeadingZerosFromObjectNumber(ObjectNumber);
	
	// Deleting company and infobase prefixes from the object number
	ObjectNumber = DeletePrefixesFromObjectNumber(ObjectNumber, True, DeleteInfoBasePrefix);
	
	Return ObjectNumber;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

Function NumberContainsStandardPrefix(Val ObjectNumber)
	
	SeparatorPosition = Find(ObjectNumber, "-");
	
	Return SeparatorPosition = 3
		Or SeparatorPosition = 5
	;
EndFunction

Function NumberContainsFiveDigitPrefix(Val ObjectNumber)
	
	Return Find(ObjectNumber, "-") = 5;
	
EndFunction
