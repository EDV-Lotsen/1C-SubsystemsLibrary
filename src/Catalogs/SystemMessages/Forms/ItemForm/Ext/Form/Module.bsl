
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	Body = CommonUse.ObjectAttributeValue(Object.Ref, "Body").Get();
	
	If TypeOf(Body) = Type("String") Then
		
		BodyPresentation = Body;
		
	Else
		
		Try
			BodyPresentation = CommonUse.ValueToXMLString(Body);
		Except
			BodyPresentation = NStr("en = 'Body cannot be presented as a string.'");
		EndTry;
		
	EndIf;
	
EndProcedure

#EndRegion
