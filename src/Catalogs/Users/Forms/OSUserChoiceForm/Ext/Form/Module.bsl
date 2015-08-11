
////////////////////////////////////////////////////////////////////////////////
//                   FORM MODULE OF THE WINDOWS USERS CHOICE                 //
////////////////////////////////////////////////////////////////////////////////

&AtClient
Procedure OnOpen(Cancel)
	
	#If ThickClientOrdinaryApplication OR ThickClientManagedApplication Then
		DomainAndUsersTable = OSUsers();
	#ElsIf ThinClient Then
		DomainAndUsersTable = New FixedArray (OSUsers());
	#EndIf
	
	FillDomainsList();
	
EndProcedure

&AtClient
Procedure FillDomainsList ()
	
	ListOfDomains.Clear();
	
	For Each Record In DomainAndUsersTable Do
		Domain = ListOfDomains.Add();
		Domain.DomainName = Record.DomainName;
	EndDo;
	
EndProcedure

&AtClient
Procedure DomainTableOnActivateRow(Item)
	
	DomainName = Item.CurrentData.DomainName;
	
	For Each Record In DomainAndUsersTable Do
		If Record.DomainName = DomainName Then
			ListOfUsersOfCurrentDomain.Clear();
			For Each User In Record.Users Do
				DomainUser = ListOfUsersOfCurrentDomain.Add();
				DomainUser.UserName = User;
			EndDo;
			Break;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure DomainUsersTableSelection(Item, RowSelected, Field, StandardProcessing)
	
	ComposeResultAndCloseForm();
	
EndProcedure

&AtClient
Procedure CommandOKExecute()
	
	DomainName = Items.DomainTable.CurrentData.DomainName;
	UserName = Items.DomainUsersTable.CurrentData.UserName;
	
	If TrimAll(DomainName) <> "" And TrimAll(UserName) <> "" Then
		ComposeResultAndCloseForm();
	EndIf;
	
EndProcedure

// Compose selection result as string \\DOMAIN\NAME_USER_DOMAIN
// and closes form, returning this value, as a form operation result.
//
&AtClient
Procedure ComposeResultAndCloseForm()
	
	DomainName 			= Items.DomainTable.CurrentData.DomainName;
	UserName 			= Items.DomainUsersTable.CurrentData.UserName;
	WindowsUserString 	= "\\" + DomainName + "\" + UserName;
	Close(WindowsUserString);
	
EndProcedure

