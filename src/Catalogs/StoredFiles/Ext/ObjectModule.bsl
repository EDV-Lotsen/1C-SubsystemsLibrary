Procedure BeforeWrite(Cancel)
	Signatures = Signature.Get();
	If TypeOf(Signatures) = Type("Array") And Signatures.Count() > 0 Then
		Signed = True;
	Else 
		Signed = False;
	EndIf;
EndProcedure
