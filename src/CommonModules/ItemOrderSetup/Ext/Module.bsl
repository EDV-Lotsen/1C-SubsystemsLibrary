////////////////////////////////////////////////////////////////////////////////
// Item order setup subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Fills the additional ordering object attribute.
//
// Parameters:
//  Source - Object - object that is written.
//  Cancel - Boolean - сancellation flag.
Procedure FillOrderingAttributeValue(Source, Cancel) Export
	
	If Source.DataExchange.Load Then 
		Return; 
	EndIf;
	// Skipping the calculation of the new order if the cancellation flag is set in the handler
		If Cancel Then
		Return;
	EndIf;
	
	// Checking  whether the object has the additional ordering attribute
	Information = ItemOrderSetupInternal.GetInformationForMoving(Source.Ref);
	If Not ObjectHasAdditionalOrderingAttribute(Source, Information) Then
		Return;
	EndIf;
	
	// Updating the order while moving an item to another group
	If Information.HasParent And CommonUse.ObjectAttributeValue(Source.Ref, "Parent") <> Source.Parent Then
		Source.AdditionalOrderingAttribute = 0;
	EndIf;
	
	// Calculating the new item order value
	If Source.AdditionalOrderingAttribute = 0 Then
		Source.AdditionalOrderingAttribute =
			ItemOrderSetupInternal.GetNewAdditionalOrderingAttributeValue(
					Information,
					?(Information.HasParent, Source.Parent, Undefined),
					?(Information.HasOwner, Source.Owner, Undefined));
	EndIf;
	
EndProcedure

// Resets the additional ordering object attribute.
//
// Parameters:
// Source       - Object - object created by copying.
// CopiedObject - Ref - original object (the source for copying).
Procedure ResetOrderingAttributeValue(Source, CopiedObject) Export
	
	Information = ItemOrderSetupInternal.GetInformationForMoving(Source.Ref);
	If ObjectHasAdditionalOrderingAttribute(Source, Information) Then
		Source.AdditionalOrderingAttribute = 0;
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

Function ObjectHasAdditionalOrderingAttribute(Object, Information)
	
	If Not Information.HasParent Then
		// The catalog is nonhierarchical so the attribute exists
		Return True;
		
	ElsIf Object.IsFolder And Not Information.ForFolders Then
		// This is a group, the order is not assigned to groups
		Return False;
		
	ElsIf Not Object.IsFolder And Not Information.ForItems Then
		// This is an item, the order is not assigned to items
		Return False;
		
	Else
		Return True;
		
	EndIf;
	
EndFunction

#EndRegion
