////////////////////////////////////////////////////////////////////////////////
// Object attribute edit prohibition subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

Procedure AllowObjectAttributeEditAfterWarn(ContinuationHandler) Export
	
	If ContinuationHandler <> Undefined Then
		ExecuteNotifyProcessing(ContinuationHandler, False);
	EndIf;
	
EndProcedure

Procedure AllowObjectAttributeEditAfterCheckRefs(Result, Parameters) Export
	
	If Result Then
		ObjectAttributeEditProhibitionClient.SetAttributeEditEnabling(
			Parameters.Form, Parameters.LockedAttributes);
		
		ObjectAttributeEditProhibitionClient.SetFormItemEnabled(Parameters.Form);
	EndIf;
	
	If Parameters.ContinuationHandler <> Undefined Then
		ExecuteNotifyProcessing(Parameters.ContinuationHandler, Result);
	EndIf;
	
EndProcedure


Procedure CheckObjectReferenceAfterValidationConfirm(Answer, Parameters) Export
	
	If Answer <> DialogReturnCode.Yes Then
		ExecuteNotifyProcessing(Parameters.ContinuationHandler, False);
		Return;
	EndIf;
		
	If Parameters.RefArray.Count() = 0 Then
		ExecuteNotifyProcessing(Parameters.ContinuationHandler, True);
		Return;
	EndIf;
	
	If CommonUseServerCall.ReferencesToObjectFound(Parameters.RefArray) Then
		
		If Parameters.RefArray.Count() = 1 Then
			MessageText = NStr("en = 'Item %1 is already used elsewhere in the application.
				|It is not recommended to allow editing this item, as this could lead to data discrepancies.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, Parameters.RefArray[0]);
		Else
			MessageText = NStr("en = 'Selected items (%1) are already used elsewhere in the application.
				|It is not recommended to allow editing these items, as this could lead to data discrepancies.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, Parameters.RefArray.Count());
		EndIf;
		
		Buttons = New ValueList;
		Buttons.Add(DialogReturnCode.Yes, NStr("en = 'Allow editing'"));
		Buttons.Add(DialogReturnCode.No, NStr("en = 'Cancel'"));
		ShowQueryBox(
			New NotifyDescription(
				"CheckObjectRefsAfterEditConfirmation", ThisObject, Parameters),
			MessageText, Buttons, , DialogReturnCode.No, Parameters.DialogTitle);
	Else
		If Parameters.RefArray.Count() = 1 Then
			ShowUserNotification(NStr("en = 'Attribute editing allowed'"),
				GetURL(Parameters.RefArray[0]), Parameters.RefArray[0]);
		Else
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Attribute editing allowed for objects (%1)'"), Parameters.RefArray.Count());
			ShowUserNotification(NStr("en = 'Attribute editing allowed'"),, MessageText);
		EndIf;
		ExecuteNotifyProcessing(Parameters.ContinuationHandler, True);
	EndIf;
	
EndProcedure

Procedure CheckObjectRefsAfterEditConfirmation(Answer, Parameters) Export
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler, Answer = DialogReturnCode.Yes);
	
EndProcedure

#EndRegion
