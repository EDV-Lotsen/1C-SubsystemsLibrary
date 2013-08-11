////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtClient
Procedure OnOpen(Cancel)
	
	#If ThickClientOrdinaryApplication Or ThickClientManagedApplication Then
	DomainAndUserTable = OSUsers();
	#ElsIf ThinClient Then
	DomainAndUserTable = New FixedArray (OSUsers());
	#EndIf
	
	FillDomainList();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENT HANDLERS OF DomainTable TABLE

&AtClient
Procedure DomainTableOnActivateRow(Item)
	
	CurrentDomainUserList.Clear();
	
	If Item.CurrentData <> Undefined Then
		DomainName = Item.CurrentData.DomainName;
		For Each Record In DomainAndUserTable Do
			If Record.DomainName = DomainName Then
				For Each User In Record.Users Do
					DomainUser = CurrentDomainUserList.Add();
					DomainUser.UserName = User;
				EndDo;
				Break;
			EndIf;
		EndDo;
		CurrentDomainUserList.Sort("UserName");
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENT HANDLERS OF UserTable TABLE

&AtClient
Procedure DomainUserTableChoice(Item, SelectedRow, Field, StandardProcessing)
	
	ComposeResultAndCloseForm();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure Choose(Command)
	
	If Items.DomainTable.CurrentData = Undefined Then
		DoMessageBox(NStr("en = 'Select a domain.'"));
		Return;
	EndIf;
	DomainName = Items.DomainTable.CurrentData.DomainName;
	
	If Items.DomainUserTable.CurrentData = Undefined Then
		DoMessageBox(NStr("en = 'Select a domain user.'"));
		Return;
	EndIf;
	UserName = Items.DomainUserTable.CurrentData.UserName;
	
	ComposeResultAndCloseForm();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtClient
Procedure FillDomainList()
	
	DomainList.Clear();
	
	For Each Record In DomainAndUserTable Do
		Domain = DomainList.Add();
		Domain.DomainName = Record.DomainName;
	EndDo;
	
	DomainList.Sort("DomainName");
	
EndProcedure

&AtClient
Procedure ComposeResultAndCloseForm()
	
	DomainName = Items.DomainTable.CurrentData.DomainName;
	UserName = Items.DomainUserTable.CurrentData.UserName;
	WindowsUserString = "\\" + DomainName + "\" + UserName;
	Close(WindowsUserString);
	
EndProcedure
