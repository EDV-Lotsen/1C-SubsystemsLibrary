﻿
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	
#Region Interface

// Returns the list of attributes that can be edited using the Batch object modification data processor.
//
Function BatchProcessingEditableAttributes() Export 
	
	Return AttachedFiles.BatchProcessingEditableAttributes();
	
EndFunction

#EndRegion

#EndIf
