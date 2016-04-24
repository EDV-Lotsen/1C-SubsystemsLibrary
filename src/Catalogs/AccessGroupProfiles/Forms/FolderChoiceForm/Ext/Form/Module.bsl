
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed
	If Parameters.Property("Autotest") Then 	
 	Return;
	EndIf;
	
	// Applying a filter that excludes all items except folders
	CommonUseClientServer.SetDynamicListFilterItem(
		List, "IsFolder", True, , , True);
	
	// Applying a filter that excludes items marked for deletion
	CommonUseClientServer.SetDynamicListFilterItem(
		List, "DeletionMark", False, , , True,
		DataCompositionSettingsItemViewMode.Normal);
	
	CommonUseClientServer.MoveFiltersToDynamicList(ThisObject);
EndProcedure
