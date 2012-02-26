
Procedure BeforeWrite(Cancellation, Replacing)
	For Each String In ThisObject Do
		If String.Variant = Enums.ObjectVersioningRules.DoNotVersion Then
			String.Use = False;
		Else
			String.Use = True;
		EndIf;
	EndDo;
EndProcedure
