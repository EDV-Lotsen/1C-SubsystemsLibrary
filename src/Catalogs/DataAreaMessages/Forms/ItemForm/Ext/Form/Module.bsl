
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.	
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	Body = CommonUse.ObjectAttributeValue(Object.Ref, "Body").Get();
	
	If TypeOf(Body) = Type("String") Then
		
		BodyPresentation = Body;
		
	Else
		
		Try
			BodyPresentation = CommonUse.ValueToXMLString(Body);
		Except
			BodyPresentation = NStr("en = 'The message body cannot be casted to the XML string type.'");
		EndTry;
		
	EndIf;
	
EndProcedure

#EndRegion
