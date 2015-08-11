////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

Procedure BeforeWrite(Cancel, Replacing)
	                    
	// Disabling standard object registration mechanism
	AdditionalProperties.Insert("DisableObjectChangeRecordMechanism", True);
	
	// Deleting all nodes that was added by AutoRecord if the AutoRecord flag is wrongly set to True
	DataExchange.Recipients.Clear();
	
	// Filling the SourceUUIDString by the source reference 
	If Count() > 0 Then
		
		If ThisObject[0].ObjectExportedByRef = True Then
			Return;
		EndIf;
		
		ThisObject[0]["SourceUUIDString"] = String(ThisObject[0]["SourceUUID"].UUID());
		
	EndIf;
	
	If DataExchange.Load
		Or Not ValueIsFilled(Filter.InfoBaseNode.Value)
		Or Not ValueIsFilled(Filter.TargetUUID.Value)
		Or Not CommonUse.RefExists(Filter.InfoBaseNode.Value) Then
		Return;
	EndIf;
	
	// The record set must be registered only in the node that is specified in the filter
	DataExchange.Recipients.Add(Filter.InfoBaseNode.Value);
	      
EndProcedure



