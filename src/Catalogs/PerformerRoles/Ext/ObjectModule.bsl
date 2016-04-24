#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// Object event handlers

Procedure FillCheckProcessing(Cancel, AttributesToCheck)
	
	If Not UsedByAddressingObjects And Not UsedWithoutAddressingObjects Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'The allowed methods for assigning performers to roles are not specified (together with the addressing objects, without them, or both ways).'"),
		 	ThisObject, "UsedWithoutAddressingObjects",,Cancel);
		Return;
	EndIf;
	
	If Not UsedByAddressingObjects Then
		Return;
	EndIf;
	
	MainAddressingObjectTypesSet = MainAddressingObjectTypes <> Undefined And Not MainAddressingObjectTypes.IsEmpty();
	If Not MainAddressingObjectTypesSet Then
		CommonUseClientServer.MessageToUser(NStr("en = 'Types of the main addressing object are not specified.'"),
		 	ThisObject, "MainAddressingObjectTypes",,Cancel);
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
		
	If MainAddressingObjectTypes <> Undefined And MainAddressingObjectTypes.IsEmpty() Then
		MainAddressingObjectTypes = Undefined;
	EndIf;
	
	If AdditionalAddressingObjectTypes <> Undefined And AdditionalAddressingObjectTypes.IsEmpty() Then
		AdditionalAddressingObjectTypes = Undefined;
	EndIf;
		
EndProcedure


#EndIf