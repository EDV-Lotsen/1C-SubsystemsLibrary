#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Interface

// Returns the list of attributes that can be edited
// using the Batch object modification data processor.
//
Function BatchProcessingEditableAttributes() Export
	
	EditableAttributes = New Array;
	
	Return EditableAttributes;
	
EndFunction

#EndRegion

#Region InternalInterface

// Updates the content of descriptions of predefined sets 
// in additional data and attribute parameters.
// 
// Parameters:
//  HasChanges - Boolean (return parameter) - if recorded, 
//               it will be set to True, otherwise it would not change.
//
Procedure RefreshPredefinedSetDescriptionContents(HasChanges = Undefined) Export
	
	SetPrivilegedMode(True);
	
	PredefinedSets = PredefinedSets();
	
	DataLock = New DataLock;
	LockItem = DataLock.Add("Constant.AdditionalDataAndAttributeParameters");
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		DataLock.Lock();
		
		Parameters = StandardSubsystemsServer.ApplicationParameters(
			"AdditionalDataAndAttributeParameters");
		
		HasDeleted = False;
		Saved = Undefined;
		
		If Parameters.Property("AdditionalDataAndAttributePredefinedSets") Then
			Saved = Parameters.AdditionalDataAndAttributePredefinedSets;
			
			If Not PredefinedSetsMatch(PredefinedSets, Saved, HasDeleted) Then
				Saved = Undefined;
			EndIf;
		EndIf;
		
		If Saved = Undefined Then
			HasChanges = True;
			StandardSubsystemsServer.SetApplicationParameter(
				"AdditionalDataAndAttributeParameters",
				"AdditionalDataAndAttributePredefinedSets",
				PredefinedSets);
		EndIf;
		
		StandardSubsystemsServer.ConfirmApplicationParametersUpdate(
			"AdditionalDataAndAttributeParameters",
			"AdditionalDataAndAttributePredefinedSets");
		
		StandardSubsystemsServer.AddApplicationParameterChanges(
			"AdditionalDataAndAttributeParameters",
			"AdditionalDataAndAttributePredefinedSets",
			New FixedStructure("HasDeleted", HasDeleted));
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Function PredefinedSets()
	
	PredefinedSets = New Map;
	
	PredefinedNames = StandardSubsystemsServer.PredefinedDataNames(
		"Catalog.AdditionalDataAndAttributeSets");
	
	For Each Name In PredefinedNames Do
		PredefinedSets.Insert(
			Name, PropertyManagementInternal.PredefinedSetDescription(Name));
	EndDo;
	
	Return New FixedMap(PredefinedSets);
	
EndFunction

Function PredefinedSetsMatch(NewSets, OldSets, HasDeleted)
	
	PredefinedSetsMatch =
		NewSets.Count() = OldSets.Count();
	
	For Each Set In OldSets Do
		If NewSets.Get(Set.Key) = Undefined Then
			PredefinedSetsMatch = False;
			HasDeleted = True;
			Break;
		ElsIf Set.Value <> NewSets.Get(Set.Key) Then
			PredefinedSetsMatch = False;
		EndIf;
	EndDo;
	
	Return PredefinedSetsMatch;
	
EndFunction

#EndRegion

#EndIf
