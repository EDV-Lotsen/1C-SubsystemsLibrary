#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnCopy(CopiedObject)
	
	Title = "";
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If PropertyManagementInternal.ValueTypeContainsPropertyValues(ValueType) Then
		
		Query = New Query;
		Query.SetParameter("OwnerValues", Ref);
		Query.Text =
		"SELECT
		|	Properties.Ref AS Ref,
		|	Properties.ValueType AS ValueType
		|FROM
		|	ChartOfCharacteristicTypes.AdditionalDataAndAttributes AS Properties
		|WHERE
		|	Properties.AdditionalValueOwner = &OwnerValues";
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			NewValueType = Undefined;
			
			If ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValues"))
			   And Not Selection.ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValues")) Then
				
				NewValueType = New TypeDescription(
					Selection.ValueType,
					"CatalogRef.ObjectPropertyValues",
					"CatalogRef.ObjectPropertyValueHierarchy");
				
			ElsIf ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy"))
			        And Not Selection.ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy")) Then
				
				NewValueType = New TypeDescription(
					Selection.ValueType,
					"CatalogRef.ObjectPropertyValueHierarchy",
					"CatalogRef.ObjectPropertyValues");
				
			EndIf;
			
			If NewValueType <> Undefined Then
				CurrentObject = Selection.Ref.GetObject();
				CurrentObject.ValueType = NewValueType;
				CurrentObject.DataExchange.Load = True;
				CurrentObject.Write();
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

Procedure BeforeDelete(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Property", Ref);
	Query.Text =
	"SELECT
	|	PropertySets.Ref AS Ref
	|FROM
	|	Catalog.AdditionalDataAndAttributeSets.AdditionalAttributes AS PropertySets
	|WHERE
	|	PropertySets.Property = &Property
	|
	|UNION
	|
	|SELECT
	|	PropertySets.Ref
	|FROM
	|	Catalog.AdditionalDataAndAttributeSets.AdditionalData AS PropertySets
	|WHERE
	|	PropertySets.Property = &Property";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		CurrentObject = Selection.Ref.GetObject();
		// Delete additional attributes.
		Index = CurrentObject.AdditionalAttributes.Count()-1;
		While Index >= 0 Do
			If CurrentObject.AdditionalAttributes[Index].Property = Ref Then
				CurrentObject.AdditionalAttributes.Delete(Index);
			EndIf;
			Index = Index - 1;
		EndDo;
		// Delete additional data.
		Index = CurrentObject.AdditionalData.Count()-1;
		While Index >= 0 Do
			If CurrentObject.AdditionalData[Index].Property = Ref Then
				CurrentObject.AdditionalData.Delete(Index);
			EndIf;
			Index = Index - 1;
		EndDo;
		If CurrentObject.Modified() Then
			CurrentObject.DataExchange.Load = True;
			CurrentObject.Write();
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#EndIf
