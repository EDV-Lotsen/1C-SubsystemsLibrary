////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	If Not Parameters.Filter.Property("NotValid") Then
		Parameters.Filter.Insert("NotValid", False);
	EndIf;
	
EndProcedure

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
	If FormType = "ChoiceForm" Then
		
		ParameterChanged = False;
		
		If Not Parameters.Property("Filter") Then
			Parameters.Insert("Filter", New Structure("NotValid", False));
			ParameterChanged = True;
		ElsIf Not Parameters.Filter.Property("NotValid") Then
			Parameters.Filter.Insert("NotValid", False);
			ParameterChanged = True;
		EndIf;
		
		If ParameterChanged Then
			StandardProcessing = False;
			SelectedForm = "ListForm";
		EndIf;
		
	EndIf;
	
EndProcedure
