////////////////////////////////////////////////////////////////////////////////
// Contact information subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

Procedure CIFilling(Source, FillingData, StandardProcessing) Export
	
	If TypeOf(FillingData) <> Type("Structure") Then
		Return;
	EndIf;
	
	// Filling the description
	Description = "";
	If FillingData.Property("Description", Description) Then
		Source.Description = Description;
	EndIf;
	
	// Filling contact information
	ContactInformation = Undefined;
	If FillingData.Property("ContactInformation", ContactInformation) Then
		For Each CIRow In ContactInformation Do
			
			NewCIRow = Source.ContactInformation.Add();
			FillPropertyValues(NewCIRow, CIRow);
			
			If TypeOf(CIRow.FieldValues) = Type("ValueList") Then
				NewCIRow.FieldValues = New ValueStorage(CIRow.FieldValues);
			EndIf;
			
		EndDo;
	EndIf;
	
EndProcedure