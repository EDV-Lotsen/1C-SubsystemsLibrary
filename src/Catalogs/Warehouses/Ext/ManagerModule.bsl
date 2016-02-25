
// The choice event data handler
Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	If Parameters.SearchString = Undefined Then
		
		StandardProcessing = False;
		ChoiceData = New ValueList;
		
		//Generating the list with warnings
		Query = New Query;
		Query.Text = 
			"SELECT
			|	Warehouses.Ref,
			|	Warehouses.Description,
			|	Warehouses.DontUse
			|FROM
			|	Catalog.Warehouses AS Warehouses";

		Result = Query.Execute();
		SelectionDetailRecords = Result.Select();
		
		While SelectionDetailRecords.Next() Do
			
			Structure = New Structure("Value",  SelectionDetailRecords.Ref);
			
			//Filling a warning
			If SelectionDetailRecords.DontUse Then
				 Structure.Insert("Warning", NStr("en = 'This warehouse should not be used!'"));
			EndIf;
			
			Element = ChoiceData.Add();
			Element.Value = Structure;
			Element.Presentation = SelectionDetailRecords.Description;
			
		EndDo;
		
	Else
		
		//Removing unused from the input by a string
		Parameters.Filter.Insert("DontUse", False);
		
	EndIf;	
	
EndProcedure
