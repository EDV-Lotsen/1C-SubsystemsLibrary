
Procedure BeforeWrite(Cancellation)
	
	If DataExchange.Load Then 
		Return;
	EndIf;
	
	If Not IsFolder Then
		
		// Delete doubles and empty rows
		SelectedProperties 		= New Map;
		PropertiesToBeDeleted 	= New Array;
		
		// Additional attributes
		For each AdditionalAttribute In AdditionalAttributes Do
			
			If AdditionalAttribute.Property.IsEmpty() OR SelectedProperties.Get(AdditionalAttribute.Property) <> Undefined Then
				
				PropertiesToBeDeleted.Add(AdditionalAttribute);
				
			Else
				
				SelectedProperties.Insert(AdditionalAttribute.Property, True);
				
			EndIf;
			
		EndDo;
		
		For each PropertyBeingDeleted In PropertiesToBeDeleted Do
			
			AdditionalAttributes.Delete(PropertyBeingDeleted);
			
		EndDo;
		
		SelectedProperties.Clear();
		PropertiesToBeDeleted.Clear();
		
		// Additional info
		For each AdditionalProperty In AdditionalProperties Do
			
			If AdditionalProperty.Property.IsEmpty() OR SelectedProperties.Get(AdditionalProperty.Property) <> Undefined Then
				
				PropertiesToBeDeleted.Add(AdditionalProperty);
				
			Else
				
				SelectedProperties.Insert(AdditionalProperty.Property, True);
				
			EndIf;
			
		EndDo;
		
		For each PropertyBeingDeleted In PropertiesToBeDeleted Do
			
			AdditionalProperties.Delete(PropertyBeingDeleted);
			
		EndDo;
		
	ElsIf Predefined Then
		
		// Collect properties of the linked sets for the root set
		
		Query = New Query;
		Query.SetParameter("Parent", Ref);
		
		// Additional attributes
		Query.Text =
		"SELECT DISTINCT
		|	AdditionalAttributes.Property AS Property
		|FROM
		|	Catalog.AdditionalDataAndAttributesSettings.AdditionalAttributes AS AdditionalAttributes
		|WHERE
		|	AdditionalAttributes.Ref.Parent = &Parent
		|	AND AdditionalAttributes.Property.IsAdditionalData = FALSE";
		
		AdditionalAttributes.Load(Query.Execute().Unload());
		
		Query.Text =
		"SELECT DISTINCT
		|	AdditionalProperties.Property AS Property
		|FROM
		|	Catalog.AdditionalDataAndAttributesSettings.AdditionalProperties AS AdditionalProperties
		|WHERE
		|	AdditionalProperties.Ref.Parent = &Parent
		|	AND AdditionalProperties.Property.IsAdditionalData = TRUE";
		
		AdditionalData.Load(Query.Execute().Unload());
		
	EndIf;
	
EndProcedure

Procedure OnWrite()
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If ValueIsFilled(Parent) Then
		MainObject = Parent.GetObject();
		LockDataForEdit(MainObject.Ref);
		MainObject.Write();
	EndIf;
	
EndProcedure
