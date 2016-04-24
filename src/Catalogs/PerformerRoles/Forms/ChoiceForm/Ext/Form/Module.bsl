
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
 
 // Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	SimpleRolesOnly = False;
	If Parameters.Property("SimpleRolesOnly", SimpleRolesOnly) And SimpleRolesOnly = True Then
		CommonUseClientServer.SetDynamicListFilterItem(
			List, "ExternalRole", True, , , True);
	EndIf;
	
	CommonUseClientServer.MoveFiltersToDynamicList(ThisObject);
EndProcedure
