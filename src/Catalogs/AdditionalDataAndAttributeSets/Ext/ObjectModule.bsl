#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not IsFolder Then
		
		// Delete duplicates and empty rows.
		SelectedProperties = New Map;
		PropertiesToDelete = New Array;
		
		// Additional attributes.
		For Each AdditionalAttribute In AdditionalAttributes Do
			
			If AdditionalAttribute.Property.IsEmpty()
			 Or SelectedProperties.Get(AdditionalAttribute.Property) <> Undefined Then
				
				PropertiesToDelete.Add(AdditionalAttribute);
			Else
				SelectedProperties.Insert(AdditionalAttribute.Property, True);
			EndIf;
		EndDo;
		
		For Each PropertyToDelete In PropertiesToDelete Do
			AdditionalAttributes.Delete(PropertyToDelete);
		EndDo;
		
		SelectedProperties.Clear();
		PropertiesToDelete.Clear();
		
		// Additional data.
		For Each AdditionalDataItem In AdditionalData Do
			
			If AdditionalDataItem.Property.IsEmpty()
			 Or SelectedProperties.Get(AdditionalDataItem.Property) <> Undefined Then
				
				PropertiesToDelete.Add(AdditionalDataItem);
			Else
				SelectedProperties.Insert(AdditionalDataItem.Property, True);
			EndIf;
		EndDo;
		
		For Each PropertyToDelete In PropertiesToDelete Do
			AdditionalData.Delete(PropertyToDelete);
		EndDo;
		
		// Calculating number of properties not marked for deletion.
		AttributeNumber = Format(AdditionalAttributes.FindRows(
			New Structure("DeletionMark", False)).Count(), "NG=");
		
		DataNumber = Format(AdditionalData.FindRows(
			New Structure("DeletionMark", False)).Count(), "NG=");
	
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not IsFolder Then
		// Update of the top group content for use during customisation
		// of the dynamic list's fields content and its settings (selection, ...).
		If ValueIsFilled(Parent) Then
			PropertyManagementInternal.CheckRefreshGroupPropertyContent(Parent);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
