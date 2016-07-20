
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	Role = Parameters.PerformerRole;
	MainAddressingObject = Parameters.MainAddressingObject;
	AdditionalAddressingObject = Parameters.AdditionalAddressingObject;
	SetAddressingObjectTypes();
	SetItemStates();
	
	If Parameters.SelectAddressingObject Then
		CurrentItem = Items.MainAddressingObject;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, AttributesToCheck)
	
	If UsedWithoutAddressingObjects Then
		Return;
	EndIf;
		
	MainAddressingObjectTypesSet = UsedByAddressingObjects And ValueIsFilled(MainAddressingObjectTypes);
	AditionalAddressingObjectTypesSet = UsedByAddressingObjects And ValueIsFilled(AdditionalAddressingObjectTypes);
	
	If MainAddressingObjectTypesSet And MainAddressingObject = Undefined Then
		
		CommonUseClientServer.MessageToUser( 
		    StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'The %1 field is required.'"), 
				Role.MainAddressingObjectTypes.Description ),,,
				"MainAddressingObject", 
				Cancel);
				
	ElsIf AditionalAddressingObjectTypesSet And AdditionalAddressingObject = Undefined Then
		
		CommonUseClientServer.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'The %1 field is required.'"), 
			  Role.AdditionalAddressingObjectTypes.Description ),,, 
			"AdditionalAddressingObject", 
			Cancel);
			
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure PerformerOnChange(Item)
	
	MainAddressingObject = Undefined;
	AdditionalAddressingObject = Undefined;
	SetAddressingObjectTypes();
	SetItemStates();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OKExecute()
	
	ClearMessages();
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	ChoiceResult = CloseParameters();
	
	NotifyChoice(ChoiceResult);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetAddressingObjectTypes()
	
	MainAddressingObjectTypes = Role.MainAddressingObjectTypes.ValueType;
	AdditionalAddressingObjectTypes = Role.AdditionalAddressingObjectTypes.ValueType;
	UsedByAddressingObjects = Role.UsedByAddressingObjects;
	UsedWithoutAddressingObjects = Role.UsedWithoutAddressingObjects;
	
EndProcedure

&AtServer
Procedure SetItemStates()

	MainAddressingObjectTypesSet = UsedByAddressingObjects
		And ValueIsFilled(MainAddressingObjectTypes);
	AditionalAddressingObjectTypesSet = UsedByAddressingObjects 
		And ValueIsFilled(AdditionalAddressingObjectTypes);
		
	Items.MainAddressingObject.Title = Role.MainAddressingObjectTypes.Description;
	Items.MainAddressingObject.Enabled = MainAddressingObjectTypesSet; 
	Items.MainAddressingObject.AutoMarkIncomplete = MainAddressingObjectTypesSet
		And Not UsedWithoutAddressingObjects;
	Items.MainAddressingObject.TypeRestriction = MainAddressingObjectTypes;
		
	Items.AdditionalAddressingObject.Title = Role.AdditionalAddressingObjectTypes.Description;
	Items.AdditionalAddressingObject.Enabled = AditionalAddressingObjectTypesSet; 
	Items.AdditionalAddressingObject.AutoMarkIncomplete = AditionalAddressingObjectTypesSet
		And Not UsedWithoutAddressingObjects;
	Items.AdditionalAddressingObject.TypeRestriction = AdditionalAddressingObjectTypes;
	                        
EndProcedure

&AtServer
Function CloseParameters()
	Return New Structure("PerformerRole,MainAddressingObject,AdditionalAddressingObject", 
		Role,
		?(MainAddressingObject <> Undefined And Not MainAddressingObject.IsEmpty(), MainAddressingObject, Undefined),
		?(AdditionalAddressingObject <> Undefined And Not AdditionalAddressingObject.IsEmpty(), AdditionalAddressingObject, Undefined));
EndFunction

#EndRegion
