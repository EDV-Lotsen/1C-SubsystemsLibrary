#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then


Procedure BeforeWrite(Cancel)

	If DataExchange.Load Then
		Return;	
	EndIf;
	
	If ValueIsFilled(PerformerRole) Then
		
		Description = String(PerformerRole);
		
		If ValueIsFilled(MainAddressingObject) Then
			Description = Description + "," + String(MainAddressingObject);
		EndIf;
		
		If ValueIsFilled(AdditionalAddressingObject) Then
			Description = Description + "," + String(AdditionalAddressingObject);
		EndIf;
	Else
		Description = NStr("en = 'No role addressing'");
	EndIf;
	
	// Checking for duplicates.
	Query = New Query(
		"SELECT TOP 1
		|	TaskPerformerGroups.Ref
		|FROM
		|	Catalog.TaskPerformerGroups AS TaskPerformerGroups
		|WHERE
		|	TaskPerformerGroups.PerformerRole = &PerformerRole
		|	AND TaskPerformerGroups.MainAddressingObject = &MainAddressingObject
		|	AND TaskPerformerGroups.AdditionalAddressingObject = &AdditionalAddressingObject
		|	AND TaskPerformerGroups.Ref <> &Ref");
	Query.SetParameter("PerformerRole", PerformerRole);
	Query.SetParameter("MainAddressingObject", MainAddressingObject);
	Query.SetParameter("AdditionalAddressingObject", AdditionalAddressingObject);
	Query.SetParameter("Ref", Ref);
	
	If Not Query.Execute().IsEmpty() Then
		Raise(StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'A task performer group with the following parameters is already available: 
		             |performer role: %1
		             |main addressing object: %2
		             |additional addressing object: %3.'"),
			String(PerformerRole),
			String(MainAddressingObject),
			String(AdditionalAddressingObject)));
	EndIf;
	
EndProcedure

#EndIf