#If Server Or OrdinaryApplicationRichClient Or ExternalConnection Then

Procedure OnWrite(Cancel)
	
	SetPrivilegedMode(True);
	
	Constants.DontUseSeveralCompanies.Set(Not ThisObject.Value);
	
EndProcedure

#EndIf
