

Var FormerParent;

// Handler BeforeWrite locks invalid actions with the predefined
// group "All users".
//
Procedure BeforeWrite(Cancellation)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Ref = Catalogs.UserGroups.AllUsers Then
		If NOT Parent.IsEmpty() Then
			CommonUseClientServer.MessageToUser(NStr("en = 'Predefined folder ""All users"" can be only at the root!'"), , , , Cancellation);
			Return;
		EndIf;
		If Content.Count() > 0 Then
			CommonUseClientServer.MessageToUser(NStr("en = 'Adding users to the folder ""everyone"" is not supported.'"), , , , Cancellation);
			Return;
		EndIf;
	Else
		If Parent = Catalogs.UserGroups.AllUsers Then
			CommonUseClientServer.MessageToUser(NStr("en = 'Predefined folder ""All users"" cannot be parent!'"), , , , Cancellation);
			Return;
		EndIf;
		
		FormerParent = ?(Ref.IsEmpty(), Undefined, CommonUse.GetAttributeValue(Ref, "Parent"));
	EndIf;
	
EndProcedure

// Handler OnWrite calls update of user group content.
//
Procedure OnWrite(Cancellation)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Users.RefreshUserGroupsContent(Ref);
		
	If ValueIsFilled(FormerParent) And FormerParent <> Parent Then
		Users.RefreshUserGroupsContent(FormerParent);
	EndIf;
	
EndProcedure

// Handler FillCheckProcessing locks interactive choice of group "All users" as a parent.
//
Procedure FillCheckProcessing(Cancellation, CheckedAttributes)
	
	If Parent = Catalogs.UserGroups.AllUsers Then
		CommonUseClientServer.MessageToUser(NStr("en = 'Predefined folder ""All users"" cannot be parent!'"), , "Object.Parent", , Cancellation);
	EndIf;
	
EndProcedure

