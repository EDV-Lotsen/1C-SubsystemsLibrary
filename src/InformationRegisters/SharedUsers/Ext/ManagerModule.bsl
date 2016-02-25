#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Returns the list of shared administrators.
//
// Returns:
//   ValueList - list of UUID's with presentations (user names).
//
Function AdministratorList() Export
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	SharedUsers.InfobaseUserID
		|FROM
		|	InformationRegister.SharedUsers AS SharedUsers";
	Selection = Query.Execute().Select();
	AdministratorList = New ValueList;
	While Selection.Next() Do
		IBUser = InfobaseUsers.FindByUUID(
			Selection.InfobaseUserID);
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
		If Not Users.InfobaseUserWithFullAccess(IBUser, True) Then
			Continue;
		EndIf;
		AdministratorList.Add(Selection.InfobaseUserID, IBUser.Name);
	EndDo;
	AdministratorList.SortByPresentation();
	Return AdministratorList;
	
EndFunction

// Returns the maximum sequence number of a shared infobase user.
//
// Returns:
//  Number.
Function MaximumSequenceNumber() Export
	
	QueryText = "SELECT
	            |	ISNULL(MAX(SharedUsers.SequenceNumber), 0) AS SequenceNumber
	            |FROM
	            |	InformationRegister.SharedUsers AS SharedUsers";
	Query = New Query(QueryText);
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.SequenceNumber;
	Else
		Return 0;
	EndIf;
	
EndFunction

// Returns the sequence number of a shared infobase user.
//
// Parameters:
//  ID - infobase user UUID.
//
// Returns:
//  Number.
Function InfobaseUserSequenceNumber(ID) Export
	
	Query = New Query;
	Query.SetParameter("InfobaseUserID", ID);
	Query.Text =
	"SELECT
	|	SharedUsers.SequenceNumber AS SequenceNumber
	|FROM
	|	InformationRegister.SharedUsers AS SharedUsers
	|WHERE
	|	SharedUsers.InfobaseUserID = &InfobaseUserID";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.SequenceNumber;
	Else
		Return "";
	EndIf;
	
EndFunction

#EndIf