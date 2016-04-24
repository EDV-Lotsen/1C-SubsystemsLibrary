
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	If Not AccessRight("Update", Metadata.Catalogs.AccessGroups)
	     
	 Or AccessParameters("Update", Metadata.Catalogs.AccessGroups,
	         "Ref").RestrictionByCondition Then
		
		ReadOnly = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed
	If Parameters.Property("Autotest") Then 		
Return;
	EndIf;
	
	If CurrentObject.Ref = Catalogs.AccessGroups.PersonalAccessGroupParent(True) Then
		ReadOnly = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, AttributesToCheck)
	
	PersonalAccessGroupDescription = Undefined;
	
	PersonalAccessGroupParent = Catalogs.AccessGroups.PersonalAccessGroupParent
(
		True, PersonalAccessGroupDescription);
	
	If Object.Ref <> PersonalAccessGroupParent
	   And Object.Description = PersonalAccessGroupDescription Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en = 'This description is reserved.'"),
			,
			"Object.Description",
			,
			Cancel);
	EndIf;
	
EndProcedure

#EndRegion
