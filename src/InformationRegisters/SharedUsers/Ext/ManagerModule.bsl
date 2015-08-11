// Returns a shared administrator list.
//
// Returns:
// ValueList – a UUID list with presentations (user names).
//
Function AdministratorList() Export
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	SharedUsers.InfoBaseUserID
		|FROM
		|	InformationRegister.SharedUsers AS SharedUsers";
	Selection = Query.Execute().Select();
	AdministratorList = New ValueList;
	While Selection.Next() Do
		IBUser = InfoBaseUsers.FindByUUID(
			Selection.InfoBaseUserID);
		If IBUser = Undefined Then
			Continue;
		EndIf;		
		HasRoles = False;
		For Each UserRole In IBUser.Roles Do
			HasRoles = True;
			Break;
		EndDo;
		If Not HasRoles Then
			Continue;
		EndIf;
		If Not Users.InfoBaseUserWithFullAccess(IBUser, True) Then
			Continue;
		EndIf;
		AdministratorList.Add(Selection.InfoBaseUserID, IBUser.Name);
	EndDo;
	AdministratorList.SortByPresentation();
	Return AdministratorList;
	
EndFunction