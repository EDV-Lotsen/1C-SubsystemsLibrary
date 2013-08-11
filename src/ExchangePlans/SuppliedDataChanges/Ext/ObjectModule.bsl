
////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS 

Procedure BeforeWrite(Cancel)
	
	If IsBlankString(Description) Then
		Description = Code;	
	EndIf;
	
EndProcedure
