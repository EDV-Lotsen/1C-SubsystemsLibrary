#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS 

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	For Each Row In ThisObject Do
		If Row.Mode = Enums.ObjectVersioningModes.DontVersionize Then
			Row.Use = False;
		Else
			Row.Use = True;
		EndIf;
	EndDo;
	
EndProcedure


#EndIf