

// Procedure handler of event ChoiceDataGetProcessing.
//
Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)	
	
	If NOT (Parameters.Property("SearchString") And ValueIsFilled(Parameters.SearchString)) Then		
		Return
	EndIf; 
	
	StandardProcessing = False;
	ValuesArray = New Array;
	
	For Counter = 1 To 5 Do	
		If Parameters.Property("TimeKind" + Counter) And ValueIsFilled(Parameters["TimeKind" + Counter]) Then		
			ValuesArray.Add(Parameters["TimeKind" + Counter]);
		EndIf;	
	EndDo;		
		
	Query = New Query("SELECT
				  |	WorkTimeTypes.Ref
				  |FROM
				  |	Catalog.WorkTimeTypes AS WorkTimeTypes
				  |WHERE
				  |	NOT (WorkTimeTypes.Ref In(&ValuesArray))
				  |
				  |GROUP BY
				  |	WorkTimeTypes.Ref
				  |
				  |HAVING
				  |	SUBSTRING(WorkTimeTypes.Description, 1, &SubstringLength) LIKE &SearchString
				  |
				  |ORDER BY
				  |	WorkTimeTypes.Description");
				  
	Query.SetParameter("ValuesArray", ValuesArray);
	Query.SetParameter("SearchString", Parameters.SearchString);
	Query.SetParameter("SubstringLength", StrLen(Parameters.SearchString));
	
	Result = Query.Execute();
	If NOT Result.IsEmpty() Then
		ChoiceData = New ValueList;
		Selection = Result.Choose();
		While Selection.Next() Do
			ChoiceData.Add(Selection.Ref);	
		EndDo;
	EndIf;	
	
EndProcedure // ChoiceDataGetProcessing()
