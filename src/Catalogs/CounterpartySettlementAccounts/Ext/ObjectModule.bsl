
// New item filling handler
Procedure Filling(FillingData, StandardProcessing)

	If TypeOf(FillingData) = Type("Structure") Then

		Value = Undefined;

		If FillingData.Property("DescriptionFill", Value) Then

			Description = Value;

		EndIf;

	EndIf;

EndProcedure
