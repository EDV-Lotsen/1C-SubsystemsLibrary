////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Fills a value of the additional ordering attribute of the source object.
//
// Parameters:
//  Source - Object - object whose ordering attribute will be filled;
//  Cancel - Boolean - flag that shows whether writing the object must be canceled.
//
Procedure FillOrderingAttributeValue(Source, Cancel) Export
	
	If Source.DataExchange.Load Then 
		Return; 
	EndIf;		
	
	// If Cancel was set to True, the old order must be kept
	If Cancel Then
		Return;
	EndIf;
	
	// Checking whether the object has additional ordering attribute
	Information = ItemOrderSetup.GetMetadataToMoveInfo(Source.Ref);
	If Not ObjectHasAdditionalOrderingAttribute(Source, Information) Then
		Return;
	EndIf;
	
	// Counting a new item order value
	If Source.AdditionalOrderingAttribute = 0 Then
		Source.AdditionalOrderingAttribute =
			ItemOrderSetup.GetNewAdditionalOrderingAttributeValue(
					Information,
					?(Information.HasParent, Source.Parent, Undefined),
					?(Information.HasOwner, Source.Owner, Undefined) );
	EndIf;
	
EndProcedure

// Resets a value of the additional ordering attribute of the source object.
//
// Parameters:
//  Source - Object - object that is generated with copying;
//  CopiedObject - Ref - source object.
//
Procedure ResetOrderingAttributeValue(Source, CopiedObject) Export
	
	Information = ItemOrderSetup.GetMetadataToMoveInfo(Source.Ref);
	If ObjectHasAdditionalOrderingAttribute(Source, Information) Then
		Source.AdditionalOrderingAttribute = 0;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

Function ObjectHasAdditionalOrderingAttribute(Object, Information)
	
	If Not Information.HasParent Then
		// All hierarchical catalogs have the additional ordering attribute
		Return True;
		
	ElsIf Object.IsFolder And Not Information.ForFolders Then
		// Order cannot be set for a folder
		Return False;
		
	ElsIf Not Object.IsFolder And Not Information.ForItems Then
		// Order cannot be set for an item
		Return False;
		
	Else
		Return True;
		
	EndIf;
	
EndFunction
