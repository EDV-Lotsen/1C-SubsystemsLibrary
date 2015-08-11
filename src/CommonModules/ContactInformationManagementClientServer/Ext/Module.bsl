////////////////////////////////////////////////////////////////////////////////
//Contact information subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Generates an address presentation started with the address kind description.
//
// Parameters:
// AddressStructure - Structure - address structure;
// Presentation - String - address presentation;
// KindDescription - String -  kind description.
//
// Returns:
// String - address presentation started with the address kind description.
//
Function GenerateAddressPresentation(AddressStructure, Presentation, KindDescription = Undefined) Export 
	
	Presentation = "";
	
	Country = ValueByStructureKey("Country", AddressStructure);
	
	If Country <> Undefined Then
		SupplementAddressPresentation(TrimAll(ValueByStructureKey("CountryName", AddressStructure)), ", ", Presentation);
	EndIf;
	
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("Index", AddressStructure)), 	 ", ", Presentation);
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("State", AddressStructure)), ", ", Presentation);
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("County", AddressStructure)), ", ", Presentation);
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("City", AddressStructure)), ", ", Presentation);
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("Settlement", AddressStructure)), ", ", Presentation);
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("Street", AddressStructure)), ", ", Presentation);
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("Building", AddressStructure)), ", " + ValueByStructureKey("BuildingType", AddressStructure) + " # ", Presentation);
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("Appartment", AddressStructure)), ", " + ValueByStructureKey("AppartmentType", AddressStructure) + " ",	Presentation);
	
	If StrLen(Presentation) > 2 Then
		Presentation = Mid(Presentation, 3);
	EndIf;
	
	KindDescription	= ValueByStructureKey("KindDescription", AddressStructure);
	PresentationWithKind = KindDescription + ": " + Presentation;
	
	Return PresentationWithKind;
	
EndFunction


////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Supplements the address presentation with the specified string.
//
// Parameters:
// Supplement - String - address supplement;
// ConcatenationString - String - concatenation string;
// Presentation - String - address presentation.
//
Procedure SupplementAddressPresentation(Supplement, ConcatenationString, Presentation)
	
	If Supplement <> "" Then
		Presentation = Presentation + ConcatenationString + Supplement;
	EndIf;
	
EndProcedure

// Returns a string presentation of a structure by structure key.
//
// Parameters:
// Key - String - structure key;
// Structure - Structure - passed structure.
//
// Returns:
// String - structure value converted to String or an
// empty string if the key is not found in the structure.
//
Function ValueByStructureKey(Key, Structure)
	
	Value	= Undefined;
	
	If Structure.Property(Key, Value) Then 
		Return String(Value);
	EndIf;
	
	Return "";
	
EndFunction	