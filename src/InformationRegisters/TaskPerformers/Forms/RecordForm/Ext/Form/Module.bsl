
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
 
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	SetItemStates();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject)
	If Not ValueIsFilled(CurrentObject.MainAddressingObject) Then
		CurrentObject.MainAddressingObject = Undefined;
	EndIf;
	If Not ValueIsFilled(CurrentObject.AdditionalAddressingObject) Then
		CurrentObject.AdditionalAddressingObject = Undefined;
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient                
Procedure PerformerRoleOnChange(Item)
	
	Write.MainAddressingObject = Undefined;
	Write.AdditionalAddressingObject = Undefined;
	SetItemStates();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetItemStates()

	MainAddressingObjectTypes = Write.PerformerRole.MainAddressingObjectTypes.ValueType;
	AdditionalAddressingObjectTypes = Write.PerformerRole.AdditionalAddressingObjectTypes.ValueType;
	UsedByAddressingObjects = Write.PerformerRole.UsedByAddressingObjects;
	UsedWithoutAddressingObjects = Write.PerformerRole.UsedWithoutAddressingObjects;
	
	RoleIsSet = Not Write.PerformerRole.IsEmpty();
	MainAddressingObjectTitle = ?(RoleIsSet, String(Write.PerformerRole.MainAddressingObjectTypes), "");
	AdditionalAddressingObjectTitle = ?(RoleIsSet, String(Write.PerformerRole.AdditionalAddressingObjectTypes), "");
	
	MainAddressingObjectTypesSet = RoleIsSet And UsedByAddressingObjects
		And ValueIsFilled(MainAddressingObjectTypes);
	AditionalAddressingObjectTypesSet = RoleIsSet And UsedByAddressingObjects 
		And ValueIsFilled(AdditionalAddressingObjectTypes);
	Items.MainAddressingObject.Enabled = MainAddressingObjectTypesSet;
	Items.AdditionalAddressingObject.Enabled = AditionalAddressingObjectTypesSet;
	
	Items.MainAddressingObject.AutoMarkIncomplete = MainAddressingObjectTypesSet
		And Not UsedWithoutAddressingObjects;
	If MainAddressingObjectTypes <> Undefined Then
		Items.MainAddressingObject.TypeRestriction = MainAddressingObjectTypes;
	EndIf;
	Items.MainAddressingObject.Title = MainAddressingObjectTitle;
	
	Items.AdditionalAddressingObject.AutoMarkIncomplete = AditionalAddressingObjectTypesSet
		And Not UsedWithoutAddressingObjects;
	If AdditionalAddressingObjectTypes <> Undefined Then
		Items.AdditionalAddressingObject.TypeRestriction = AdditionalAddressingObjectTypes;
	EndIf;
	Items.AdditionalAddressingObject.Title = AdditionalAddressingObjectTitle;
	
EndProcedure

#EndRegion
