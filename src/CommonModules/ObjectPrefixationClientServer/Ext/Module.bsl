
////////////////////////////////////////////////////////////////////////////////
// FUNCTIONS GENERATING OBJECT NUMBER/CODE FOR OUTPUT IN PRINT FORMS

// Removes prefix of the infobase and prefix of the Company from the passed string ObjectNumber
// Variable ObjectNumber should match template: OOBB-XXX...XX, where
// OO    	- Company prefix;
// BB  		- infobase prefix;
// "-" 		- separator;
// XXX...XX - object number/code.
//
// Parameters:
//  ObjectNumber 			 - String 				- number or code of the object from which prefixes should be removed
//  DeleteCompanyPrefix - Boolean (optional) 	- flag of Company prefix removal; by default is False;
//  DeleteInfobasePrefix 	 - Boolean (optional) 	- flag of infobase prefix removal; by default is False;
//
// Examples:
//  DeletePrefixesFromObjectNumber("NFGL-000001234", True,  True)	= "000001234"
//  DeletePrefixesFromObjectNumber("NFGL-000001234", False, True)   = "NF-000001234"
//  DeletePrefixesFromObjectNumber("NFGL-000001234", True,  False)  = "GL-000001234"
//  DeletePrefixesFromObjectNumber("NFGL-000001234", False, False)  = "NFGL-000001234"
//
Function DeletePrefixesFromObjectNumber(Val ObjectNumber, DeleteCompanyPrefix = False, DeleteInfobasePrefix = False) Export
	
	// initially empty string of the object number prefix
	ObjectPrefix = "";
	
	CompanyPrefix        = Left(ObjectNumber, 2);
	InfobasePrefix = Mid(ObjectNumber, 3, 2);
	
	// add Company prefix
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
	
	Return ObjectPrefix + Mid(ObjectNumber, 6);
EndFunction

// Removes leading zeros from the object number
// Variable ObjectNumber should match template: OOBB-XXX...XX, where
// OO  		- Company prefix;
// BB  		- infobase prefix;
// "-" 		- separator;
// XXX...XX - object number/code.
//
// Parameters:
//  ObjectNumber - String - object number or code from which leading zeros should be removed
//
Function DeleteLeadingZerosFromObjectNumber(Val ObjectNumber) Export
	
	Prefix 		= Left(ObjectNumber, 5);
	UserPrefix 	= GetUserPrefix(ObjectNumber);
	
	Number = Mid(ObjectNumber, 6 + StrLen(UserPrefix));
	
	// delete leading zeros in number from the left
	Number = StringFunctionsClientServer.DeleteDuplicatedChars(Number, "0");
	
	Return Prefix + UserPrefix + Number;
EndFunction

// Removes all user prefixes from the object number (all non-digit chars)
// Variable ObjectNumber should match template: OOBB-XXX...XX, where
// OO 		- Company prefix;
// BB  		- infobase prefix;
// "-" 		- separator;
// XXX...XX - object number/code.
//
// Parameters:
//  ObjectNumber - String - object number or code from which leading zeros should be removed
//
Function DeleteUserPrefixesFromObjectNumber(Val ObjectNumber) Export
	
	StringOfNumericChars = "0123456789";
	
	Prefix     = Left(ObjectNumber, 5);
	NumberFull = Mid(ObjectNumber, 6);
	
	Number = "";
	
	For IndexOf = 1 To StrLen(NumberFull) Do
		
		Char = Mid(NumberFull, IndexOf, 1);
		
		If Find(StringOfNumericChars, Char) > 0 Then
			
			Number = Number + Char;
			
		EndIf;
		
	EndDo;
	
	Return Prefix + Number;
EndFunction

// Gets user prefix of object number/code
// Variable ObjectNumber should match template: OOBB-AAXX..XX, where
// OO 		- Company prefix;
// BB 		- infobase prefix;
// "-" 		- separator;
// AA 		- user prefix;
// XX..XX 	- object number/code
//
// Parameters:
//  ObjectNumber - String - object number or code from which user prefix should be extracted
//
Function GetUserPrefix(Val ObjectNumber) Export
	
	// function returned value (user prefix)
	Result = "";
	
	ObjectNumber = Mid(ObjectNumber, 6);
	
	StringOfNumericChars = "0123456789";
	
	For IndexOf = 1 To StrLen(ObjectNumber) Do
		
		Char = Mid(ObjectNumber, IndexOf, 1);
		
		If Find(StringOfNumericChars, Char) > 0 Then
			Break;
		EndIf;
		
		Result = Result + Char;
		
	EndDo;
	
	Return Result;
EndFunction

// Gets document number for printing; prefixes and leading zeros are removed from the number
// Function:
// removes Company prefix,
// removes infobase prefix (optional),
// removes user prefixes (optional),
// removes leading zeros in object number
//
Function GetNumberForPrinting(Val ObjectNumber, DeleteInfobasePrefix = False, DeleteUserPrefix = False) Export
	
	// delete user prefixes from object number
	If DeleteUserPrefix Then
		
		ObjectNumber = DeleteUserPrefixesFromObjectNumber(ObjectNumber);
		
	EndIf;
	
	// delete leading zeros from object number
	ObjectNumber = DeleteLeadingZerosFromObjectNumber(ObjectNumber);
	
	// delete Company prefix and infobase prefix from object number
	ObjectNumber = DeletePrefixesFromObjectNumber(ObjectNumber, True, DeleteInfobasePrefix);
	
	Return ObjectNumber;
EndFunction
