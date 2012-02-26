
////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// Procedure - handler of event "OnCopy".
//
Procedure OnCopy(CopiedObject)
	
	Code = "";
	
EndProcedure // OnCopy()

// Procedure - handler of event "FillCheckProcessing".
//
Procedure FillCheckProcessing(Cancellation, CheckedAttributes)
	
	If DataExchange.Load Then
		Return;
	EndIf;
			
	If NOT IsFolder Then
	
		If StrLen(TrimAll(Code)) <> 6 Then
			MessageText = NStr("en = 'BIN must have 6 symbols.'");
			StandardSubsystemsServer.ShowErrorMessage(
				ThisObject,
				MessageText,
				,
				,
				"Code",
				Cancellation
			);
		EndIf;
		
	Else
		
		StandardSubsystemsServer.DeleteAttributeBeingChecked(CheckedAttributes, "Code");
		
	EndIf;
	
EndProcedure // FillCheckProcessing() 
