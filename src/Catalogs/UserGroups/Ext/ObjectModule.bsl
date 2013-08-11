
// The group parent value to use it in the OnWrite event handler
Var OldParent; 

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// Prevents invalid actions with the All users predefined group.
//
Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Ref = Catalogs.UserGroups.AllUsers Then
		If Not Parent.IsEmpty() Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'The All users predefined group can be placed in the root only.'"),
				, , , Cancel);
			Return;
		EndIf;
		If Content.Count() > 0 Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'Users cannot be added to the All users predefined group.'"),
				, , , Cancel);
			Return;
		EndIf;
	Else
		If Parent = Catalogs.UserGroups.AllUsers Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'The All users predefined group cannot have subgroups.'"),
				, , , Cancel);
			Return;
		EndIf;
		
		OldParent = ?(Ref.IsEmpty(), Undefined, CommonUse.GetAttributeValue(Ref, "Parent"));
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Users.UpdateUserGroupContent(Ref);
		
	If ValueIsFilled(OldParent) And OldParent <> Parent Then
		Users.UpdateUserGroupContent(OldParent);
	EndIf;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, AttributesToCheck)
	
	CheckedObjectAttributes = New Array;
	Errors = Undefined;
	
	// Checking whether AllUsers has subgroups
	If Parent = Catalogs.UserGroups.AllUsers Then
		CommonUseClientServer.AddUserError(Errors,
			"Object.Parent",
			NStr("en = 'The All users predefined group cannot have subgroups.'"));
	EndIf;
	
	// Checking whether there are empty or repeated users
	CheckedObjectAttributes.Add("Content.User");
	
	For Each CurrentRow In Content Do;
		LineNumber = Content.IndexOf(CurrentRow);
		
		// Checking whether the value is filled
		If Not ValueIsFilled(CurrentRow.User) Then
			CommonUseClientServer.AddUserError(Errors,
				"Object.Content[%1].User",
				NStr("en = 'User is not selected.'"),
				"Object.Content",
				LineNumber,
				NStr("en = 'A user in the row #%1 is not selected.'"));
			Continue;
		EndIf;
		
		// Checking whether there are repeated values
		FoundValues = Content.FindRows(New Structure("User", CurrentRow.User));
		If FoundValues.Count() > 1 Then
			CommonUseClientServer.AddUserError(Errors,
				"Object.Content[%1].User",
				NStr("en = 'Repeated user.'"),
				"Object.Content",
				LineNumber,
				NStr("en = 'There is a repeated user in the row #%1.'"));
		EndIf;
	EndDo;
	
	CommonUseClientServer.ShowErrorsToUser(Errors, Cancel);
	
	CommonUse.DeleteNoncheckableAttributesFromArray(AttributesToCheck, CheckedObjectAttributes);
	
EndProcedure
