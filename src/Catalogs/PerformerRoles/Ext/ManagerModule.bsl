﻿#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Interface

////////////////////////////////////////////////////////////////////////////////
// Batch object modification

// Returns a list of attributes that are excluded from the scope of the batch 
// object modification data processor.
//
Function AttributesToSkipOnGroupProcessing() Export
	
	Result = New Array;
	
	Result.Add("ShortPresentation");
	Result.Add("Comment");
	Result.Add("ExternalRole");
	Result.Add("ExchangeNode");
	
	Return Result
EndFunction

#EndRegion

#EndIf
