
////////////////////////////////////////////////////////////////////////////////
// COMMON PROCEDURES AND FUNCTIONS

&AtServerNoContext
Function IsPersonID(Individual, DocumentKind, Date)
	
	Return InformationRegisters.IndividualDocuments.IsPersonID(Individual, DocumentKind, Date);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM ITEMS EVENT HANDLERS

&AtClient
Procedure DocumentKindOnChange(Item)
	
	If IsPersonID(Record.Individual, Record.DocumentKind, Record.Period) Then
		Record.IsIdentityDocument = True;
	EndIf;
	
EndProcedure
