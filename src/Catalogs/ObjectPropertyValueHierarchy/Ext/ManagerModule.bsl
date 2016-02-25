#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Interface

// Returns the list of attributes that can be edited
// using the Batch object modification data processor.
//
Function BatchDataProcessorEditableAttributes() Export
	
	EditableAttributes = New Array;
	EditableAttributes.Add("Parent");
	EditableAttributes.Add("DeletionMark");
	
	Return EditableAttributes;
	
EndFunction

#EndRegion

#EndIf
