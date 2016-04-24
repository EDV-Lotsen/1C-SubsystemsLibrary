#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalInterface

// The procedure updates the cache register attributes based on the result of changing the content of value types and access value groups.
 
Procedure UpdateConfigurationChangesAuxiliaryRegisterData() Export
	
	SetPrivilegedMode(True);
	
	Parameters = AccessManagementInternalCached.Parameters();
	
	LastChanges = StandardSubsystemsServer.ApplicationParameterChanges(
		Parameters, "GroupAndAccessValueTypes");
	
	If LastChanges = Undefined
	 Or LastChanges.Count() > 0 Then
		
		AccessManagementInternal.SetDataFillingForAccessRestrictions(True);
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// The procedure updates the register data during the full update of auxiliary data.
// 
// Parameters:
// HasChanges - Boolean (return value) - True if data is changed; not set otherwise.
//
Procedure UpdateRegisterData(HasChanges = Undefined) Export
	
	DataVolume = 0;
	While DataVolume > 0 Do
	DataVolume = 0;
		AccessManagementInternal.DataFillingForAccessRestrictions(DataVolume, True, HasChanges);
	EndDo;
	
	ObjectTypes = AccessManagementInternalCached.ObjectTypesInEventSubscriptions(
		"WriteAccessValueSets");
	
	For Each TypeDescription In ObjectTypes Do
		Type = TypeDescription.Key;
		
		If Type = Type("String") Then
			Continue;
		EndIf;
		
		Selection = CommonUse.ObjectManagerByFullName(Metadata.FindByType(Type).FullName()).Select();
		
		While Selection.Next() Do
			AccessManagementInternal.UpdateAccessValueSets(Selection.Ref, HasChanges);
		EndDo;
	EndDo;
	
EndProcedure

#EndRegion

#EndIf
