
Procedure FillContactInformation(Source, FillingData, StandardProcessing) Export
	
	If TypeOf(FillingData) <> Type("Structure") Then
		Return;
	EndIf;
	
	// Fill description
	Description = "";
	If FillingData.Property("Description", Description) Then
		Source.Description = Description;
	EndIf;
	
	// Fill contact information
	ContactInformation = Undefined;
	If FillingData.Property("ContactInformation", ContactInformation) Then
		For Each Row In ContactInformation Do
			
			NewRow = Source.ContactInformation.Add();
			FillPropertyValues(NewRow, Row);
			
			If TypeOf(Row.FieldValues) = Type("ValueList") Then
				NewRow.FieldValues = New ValueStorage(Row.FieldValues);
			EndIf;
			
		EndDo;
	EndIf;
	
EndProcedure
