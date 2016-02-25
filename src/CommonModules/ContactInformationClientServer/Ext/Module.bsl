////////////////////////////////////////////////////////////////////////////////////////////////////
// Contact information subsystem
// 
////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Returns flag specifying whether the contact information data string is in XML format
//
// Parameters:
//     Text - String - Checked string
//
// Returns:
//     Boolean - check result
//
Function IsXMLContactInformation(Val Text) Export
	// Basic check
	Return IsXMLString(Text);
EndFunction

#EndRegion

#Region InternalInterface

// Returns description consisting of "name plus abbreviation" pairs, comma-separated
//
Function FullDescr(Val n0 = "", Val s0 = "", Val n1 = "", Val s1 = "", Val n2 = "", Val s2 = "", Val n3 = "", Val s3 = "", Val n4 = "", Val s4 = "", Val n5 = "", Val s5 = "", Val n6 = "", Val s6 = "", Val n7 = "", Val s7 = "", Val n8 = "", Val s8 = "", Val n9 = "", Val s9 = "") Export
	
	// Part 0
	Result = ?(IsBlankString(n0), "", TrimAll( TrimR(n0) + " " + TrimL(s0)) );
	
	// Part 1
	TmpN = TrimAll(n1);
	Description = ?(TmpN = "", "", TrimAll(TmpN + " " + TrimL(s1)));
	If Description = "" Or Result = "" Then
		Result = Result + Description;
	Else
		Result = Result + ", " + Description;
	EndIf;
	
	// Part 2
	TmpN = TrimAll(n2);
	Description = ?(TmpN = "", "", TrimAll(TmpN + " " + TrimL(s2)));
	If Description = "" Or Result = "" Then
		Result = Result + Description;
	Else
		Result = Result + ", " + Description;
	EndIf;
	
	// Part 3
	TmpN = TrimAll(n3);
	Description = ?(TmpN = "", "", TrimAll(TmpN + " " + TrimL(s3)));
	If Description = "" Or Result = "" Then
		Result = Result + Description;
	Else
		Result = Result + ", " + Description;
	EndIf;
	
	// Part 4
	TmpN = TrimAll(n4);
	Description = ?(TmpN = "", "", TrimAll(TmpN + " " + TrimL(s4)));
	If Description = "" Or Result = "" Then
		Result = Result + Description;
	Else
		Result = Result + ", " + Description;
	EndIf;
	
	// Part 5
	TmpN = TrimAll(n5);
	Description = ?(TmpN = "", "", TrimAll(TmpN + " " + TrimL(s5)));
	If Description = "" Or Result = "" Then
		Result = Result + Description;
	Else
		Result = Result + ", " + Description;
	EndIf;
	
	// Part 6
	TmpN = TrimAll(n6);
	Description = ?(TmpN = "", "", TrimAll(TmpN + " " + TrimL(s6)));
	If Description = "" Or Result = "" Then
		Result = Result + Description;
	Else
		Result = Result + ", " + Description;
	EndIf;
	
	// Part 7
	TmpN = TrimAll(n7);
	Description = ?(TmpN = "", "", TrimAll(TmpN + " " + TrimL(s7)));
	If Description = "" Or Result = "" Then
		Result = Result + Description;
	Else
		Result = Result + ", " + Description;
	EndIf;
	
	// Part 8
	TmpN = TrimAll(n8);
	Description = ?(TmpN = "", "", TrimAll(TmpN + " " + TrimL(s8)));
	If Description = "" Or Result = "" Then
		Result = Result + Description;
	Else
		Result = Result + ", " + Description;
	EndIf;
	
	// Part 9
	TmpN = TrimAll(n9);
	Description = ?(TmpN = "", "", TrimAll(TmpN + " " + TrimL(s9)));
	If Description = "" Or Result = "" Then
		Result = Result + Description;
	Else
		Result = Result + ", " + Description;
	EndIf;
	
	Return Result;
EndFunction

// Returns structure with name and abbreviation by value
//
// Parameters:
//     Text - String - Long description
//
// Returns:
//     Structure - processing results
//         * Description  - String - text part
//         * Abbreviation - String - text part
//
Function DescriptionAbbreviation(Val Text) Export
	Result = New Structure("Description, Abbr");
	Parts = AddressParts(Text, True);
	If Parts.Count() > 0 Then
		FillPropertyValues(Result, Parts[0]);
	Else
		Result.Description = Text;
	EndIf;
	Return Result;
EndFunction

// Returns abbreviation by value
//
// Parameters:
//     Text - String - Full description
//
// Returns:
//     String - separated abbreviation
//
Function Abbr(Val Text) Export
	Parts = DescriptionAbbreviation(Text);
	Return Parts.Abbr;
EndFunction

// Splits text into words using the specified separators Default separators - space characters
//
// Parameters:
//     Text       - String - Split string 
//     Separators - String - List of separator characters, optional
//
// Returns:
//     Array - strings, words
//
Function TextWords(Val Text, Val Separators = Undefined) Export
	
	WordStart = 0;
	State   = 0;
	Result   = New Array;
	
	For Position = 1 To StrLen(Text) Do
		CurrentChar = Mid(Text, Position, 1);
		IsSeparator = ?(Separators = Undefined, IsBlankString(CurrentChar), Find(Separators, CurrentChar) > 0);
		
		If State = 0 And (Not IsSeparator) Then
			WordStart = Position;
			State   = 1;
		ElsIf State = 1 And IsSeparator Then
			Result.Add(Mid(Text, WordStart, Position-WordStart));
			State = 0;
		EndIf;
	EndDo;
	
	If State = 1 Then
		Result.Add(Mid(Text, WordStart, Position-WordStart));    
	EndIf;
	
	Return Result;
EndFunction

// Splits comma-separated text
//
// Parameters:
//     Text                  - String  - Split text 
//     SeparateAbbreviations - Boolean - Operating mode parameter, optional
//
// Returns:
//     Array - contains Description and Abbreviation structures
//
Function AddressParts(Val Text, Val SeparateAbbreviations = True) Export
	
	Result = New Array;
	For Each Term In TextWords(Text, ",") Do
		PartString = TrimAll(Term);
		If IsBlankString(PartString) Then
			Continue;
		EndIf;
		
		Position = ?(SeparateAbbreviations, StrLen(PartString), 0);
		While Position > 0 Do
			If Mid(PartString, Position, 1) = " " Then
				Result.Add(New Structure("Description, Abbr",
					TrimAll(Left(PartString, Position-1)), TrimAll(Mid(PartString, Position))));
				Position = -1;
				Break;
			EndIf;
			Position = Position - 1;
		EndDo;
		If Position = 0 Then
			Result.Add(New Structure("Description, Abbr", PartString));
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction    

// Returns the current address classifier option
//
// Returns:
//    String    - address classifier ID
//    Undefined - current address classifier not specified
//
Function UsedAddressClassifier() Export
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	AddressClassifierSubsystemExists = CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier");
#Else
	AddressClassifierSubsystemExists = CommonUseClient.SubsystemExists("StandardSubsystems.AddressClassifier");
#EndIf
	
	If AddressClassifierSubsystemExists Then
		Return "AC";
	EndIf;
	
	// No subsystem, possibly no enum
	Return Undefined;
EndFunction

// Returns the first list item
//
// Parameters:
//     DataList - ValueList, Array, FormField
//
// Returns:
//     Arbitrary - first item
//     Undefined - no first item
// 
Function FirstOrEmpty(Val DataList) Export
	
	ListType = TypeOf(DataList);
	If ListType = Type("ValueList") And DataList.Count() > 0 Then
		Return DataList[0].Value;
	ElsIf ListType = Type("Array") And DataList.Count() > 0 Then
		Return DataList[0];
	ElsIf ListType = Type("FormField") Then
		Return FirstOrEmpty(DataList.ChoiceList);
	EndIf;
	
	Return Undefined;
EndFunction

// Returns flag specifying whether the string contains XML data
//
// Parameters:
//     Text - String - Checked string
//
// Returns:
//     Boolean - check result
//
Function IsXMLString(Val Text) Export
	// Basic check
	Return TypeOf(Text) = Type("String") And Left(TrimL(Text),1) = "<";
EndFunction

#EndRegion
