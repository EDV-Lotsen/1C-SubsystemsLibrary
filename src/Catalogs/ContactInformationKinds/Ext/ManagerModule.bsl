#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Interface

// Returns locked attribute description
//
// Returns:
//     Array - contains strings in format AttributeName[;FormItemName,...]
//             where AttributeName - name of object attribute, 
//                   FormItemName - name of item form corresponding to the attribute
//
Function GetObjectAttributesToLock() Export
	
	AttributesToLock = New Array;
	
	AttributesToLock.Add("Type;Type");
	AttributesToLock.Add("Parent");
	
	Return AttributesToLock;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Batch object modification

// Returns a list of attributes excluded from the batch object modification.
//
// Returns:
//     Array - contains strings with attribute names
//
Function AttributesToSkipOnGroupProcessing() Export
	
	Result = New Array;
	Result.Add("*");
	Return Result;
	
EndFunction

#EndRegion

#EndIf