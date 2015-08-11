﻿////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not Users.InfoBaseUserWithFullAccess() Then
		Raise NStr("en = 'Insufficient rights to open the infobase user list.'");
	EndIf;
	
	Users.FindAmbiguousInfoBaseUsers();
	
	Filter = "All";
	FilterPresentation = Items.FilterPresentation.ChoiceList[0].Presentation;
	
	If Not ExternalUsers.UseExternalUsers() Then
		Items.FilterPresentation.ChoiceList.Delete(Items.FilterPresentation.ChoiceList[4]);
		Items.FilterPresentation.ChoiceList.Delete(Items.FilterPresentation.ChoiceList[3]);
	
	ElsIf Parameters.Filter = "Users" Then
		Filter = "Users";
		FilterPresentation = Items.FilterPresentation.ChoiceList[3].Presentation;
		
	ElsIf Parameters.Filter = "ExternalUsers" Then
		Filter = "ExternalUsers";
		FilterPresentation = Items.FilterPresentation.ChoiceList[4].Presentation;
	EndIf;
	
	FillInfoBaseUserList(True);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "InfoBaseUserAdded" Or
	 EventName = "InfoBaseUserChanged" Or
	 EventName = "InfoBaseUserDeleted" Or
	 EventName = "NonexistentInfoBaseUserRelationCleared" Then
		
		FillInfoBaseUserList();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure FilterPresentationOnChange(Item)
	
	If Not ValueIsFilled(FilterPresentation) Then
		Filter = "All";
		FilterPresentation = Items.FilterPresentation.ChoiceList.FindByValue(Filter).Presentation;
	EndIf;
	
	FillInfoBaseUserList();
	
EndProcedure

&AtClient
Procedure FilterPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	SelectedItem = Undefined;

	
	ShowChooseFromList(New NotifyDescription("FilterPresentationStartChoiceEnd", ThisObject, New Structure("Item", Item)), Items.FilterPresentation.ChoiceList, Item, Items.FilterPresentation.ChoiceList.FindByValue(Filter));
	
EndProcedure

&AtClient
Procedure FilterPresentationStartChoiceEnd(SelectedItem1, AdditionalParameters) Export
    
    Item = AdditionalParameters.Item;
    
    
    SelectedItem = SelectedItem1;
    
    If SelectedItem <> Undefined Then
        
        Filter = SelectedItem.Value;
        FilterPresentation = SelectedItem.Presentation;
        
        FilterPresentationOnChange(Item);
    EndIf;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENT HANDLERS OF InfoBaseUserList TABLE 

// ProblemCode field value details:
// 0 - InfoBaseUser is not written to the catalog,
// 1 - FullName does not match Name,
// 2 - InfoBaseUser is not found,
// 3 - InfoBaseUser contains an empty UDI,
// 4 - no errors were detected.
//
// Codes 0 and 1 have red highlight,
// Codes 2 and 3 have grey highlight.

&AtClient
Procedure InfoBaseUserListChoice(Item, SelectedRow, Field, StandardProcessing)
	
	OpenUserByRef();
	
EndProcedure

&AtClient
Procedure InfoBaseUserListOnActivateRow(Item)
	
	CanDelete = Items.InfoBaseUserList.CurrentData <> Undefined And
	 Items.InfoBaseUserList.CurrentData.ProblemCode = 0;
	
	Items.InfoBaseUsersDelete.Enabled = CanDelete;
	Items.ContextMenuInfoBaseUsersDelete.Enabled = CanDelete;
	
EndProcedure

&AtClient
Procedure InfoBaseUserListBeforeDelete(Item, Cancel)
	
	Cancel = True;
	If Items.InfoBaseUserList.CurrentData.ProblemCode = 0 Then
		FunctionParameters = New Structure;
		FunctionParameters.Insert("InfoBaseUserID", Items.InfoBaseUserList.CurrentData.InfoBaseUserID);
		ShowQueryBox(New NotifyDescription("InfoBaseUserListBeforeDeleteContinuation", ThisForm, FunctionParameters), 
			NStr("en='Do you want to delete the infobase user?'"), QuestionDialogMode.YesNo);
	EndIf;
	
EndProcedure

&AtClient
// Internal use only.
Procedure InfoBaseUserListBeforeDeleteContinuation(QuestionResult, AdditionalParameters)
	
	Cancel = False;
	DeleteInfoBaseUser(AdditionalParameters.InfoBaseUserID, Cancel);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure Change(Command)
	
	OpenUserByRef();
	
EndProcedure

&AtClient
Procedure Refresh(Command)
	
	FillInfoBaseUserList();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Procedure FillInfoBaseUserList(FormOnCreate = False)
	
	InfoBaseUserList.Clear();
	HasIncorrect = False;
	
	Query = New Query(
	"SELECT
	|	Users.Ref,
	|	Users.Description,
	|	Users.InfoBaseUserID,
	|	Users.DeletionMark,
	|	FALSE AS IsExternalUser,
	|	TRUE AS IsUser
	|FROM
	|	Catalog.Users AS Users
	|
	|UNION ALL
	|
	|SELECT
	|	ExternalUsers.Ref,
	|	ExternalUsers.Description,
	|	ExternalUsers.InfoBaseUserID,
	|	ExternalUsers.DeletionMark,
	|	TRUE,
	|	FALSE
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers");
	
	SetPrivilegedMode(True);
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		InfoBaseUser = InfoBaseUsers.FindByUUID(Selection.InfoBaseUserID);
		
		NewRow = InfoBaseUserList.Add();
		
		NewRow.ProblemCode = 4;
		NewRow.Ref = Selection.Ref;
		NewRow.FullName = Selection.Description;
		NewRow.DeletionMark = Selection.DeletionMark;
		NewRow.IsUser = Selection.IsUser;
		NewRow.IsExternalUser = Selection.IsExternalUser;
		
		If InfoBaseUser = Undefined Then
			NewRow.ProblemCode = ?(ValueIsFilled(Selection.InfoBaseUserID), 2, 3);
			HasIncorrect = HasIncorrect Or ValueIsFilled(Selection.InfoBaseUserID);
		Else
			NewRow.Name = InfoBaseUser.Name;
			NewRow.StandardAuthentication = InfoBaseUser.StandardAuthentication;
			NewRow.OSAuthentication = InfoBaseUser.OSAuthentication;
			NewRow.OSUser = InfoBaseUser.OSUser;
			NewRow.InfoBaseUserID = InfoBaseUser.UUID;
			
			If Selection.Description <> InfoBaseUser.FullName Then // discrepancy between the full name and the description 
				NewRow.ProblemCode = 1;
				HasIncorrect = True;
			EndIf;
		EndIf;
		
		NewRow.Picture = GetPictureNumberByState(NewRow.ProblemCode, NewRow.DeletionMark, Selection.IsExternalUser);
		
	EndDo;
	
	CurInfoBaseUsers = InfoBaseUsers.GetUsers();
	
	For Each InfoBaseUser In CurInfoBaseUsers Do
		
		If InfoBaseUserList.FindRows(New Structure("InfoBaseUserID", InfoBaseUser.UUID)).Count() = 0 Then
			// This infobase user is not written to the catalog
			NewRow = InfoBaseUserList.Add();
			NewRow.ProblemCode = 0;
			NewRow.FullName = InfoBaseUser.FullName;
			NewRow.Name = InfoBaseUser.Name;
			NewRow.StandardAuthentication = InfoBaseUser.StandardAuthentication;
			NewRow.OSAuthentication = InfoBaseUser.OSAuthentication;
			NewRow.OSUser = InfoBaseUser.OSUser;
			NewRow.InfoBaseUserID = InfoBaseUser.UUID;
			NewRow.Picture = GetPictureNumberByState(NewRow.ProblemCode, NewRow.DeletionMark, False);
			HasIncorrect = True;
		EndIf;
		
	EndDo;
	
	If FormOnCreate And HasIncorrect Then
		Filter = "WrittenIncorrectly";
		FilterPresentation = Items.FilterPresentation.ChoiceList[1].Presentation;
	EndIf;
	
	RowsToDelete = New Array;
	If Filter = "Users" Then
		RowsToDelete.Add(InfoBaseUserList.FindRows(New Structure("IsUser", False)));
		
	ElsIf Filter = "ExternalUsers" Then
		RowsToDelete.Add(InfoBaseUserList.FindRows(New Structure("IsExternalUser", False)));
		
	ElsIf Filter = "WrittenIncorrectly" Then
		RowsToDelete.Add(InfoBaseUserList.FindRows(New Structure("ProblemCode", 3)));
		RowsToDelete.Add(InfoBaseUserList.FindRows(New Structure("ProblemCode", 4)));
		
	ElsIf Filter = "WithoutInfoBaseUser" Then
		RowsToDelete.Add(InfoBaseUserList.FindRows(New Structure("ProblemCode", 0)));
		RowsToDelete.Add(InfoBaseUserList.FindRows(New Structure("ProblemCode", 1)));
		RowsToDelete.Add(InfoBaseUserList.FindRows(New Structure("ProblemCode", 4)));
	EndIf;
	
	For Each Rows In RowsToDelete Do
		For Each String In Rows Do
			InfoBaseUserList.Delete(InfoBaseUserList.IndexOf(String));
		EndDo;
	EndDo;
	
	InfoBaseUserList.Sort("DeletionMark Asc, ProblemCode Asc");
	
	Items.Warning.Visible = HasIncorrect;
	
EndProcedure

&AtServer
Function GetPictureNumberByState(Val ProblemCode, Val DeletionMark, Val IsExternalUser)
	
	PictureNumber = -1;
	
	If ProblemCode = 1 Or ProblemCode = 0 Then
		PictureNumber = 5;
	EndIf;
		
	If DeletionMark Then
		If ProblemCode = 2 Or ProblemCode = 3 Or ProblemCode = 4 Then
			PictureNumber = 0;
		EndIf;
	Else
		If ProblemCode = 4 Then
			PictureNumber = 1;
		ElsIf ProblemCode = 2 Or ProblemCode = 3 Then
			PictureNumber = 4;
		EndIf;
	EndIf;
	
	If PictureNumber >= 0 And IsExternalUser Then
		PictureNumber = PictureNumber + 6;
	EndIf;
	
	Return PictureNumber;
	
EndFunction

&AtServer
Procedure DeleteInfoBaseUser(InfoBaseUserID, Cancel)
	
	ErrorDescription = "";
	If Not Users.DeleteInfoBaseUser(InfoBaseUserID, ErrorDescription) Then
		CommonUseClientServer.MessageToUser(ErrorDescription, , , , Cancel);
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenUserByRef()
	
	CurrentData = Items.InfoBaseUserList.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.ProblemCode = 0 Then
		ShowMessageBox(, NStr("en = 'No catalog items mapped to this infobase user.
		 |
		 |If you want to create an infobase user
		 |associated with a user or an external user, click the 
		 |<Access to the infobase for the user is allowed> check box that sat on
		 |the item form.'"));
		
		Cancel = False;
		InfoBaseUserListBeforeDelete(Items.InfoBaseUserList, Cancel);
		If Not Cancel Then
			InfoBaseUserList.Delete(CurrentData);
		EndIf;
	Else
		OpenForm(?(CurrentData.IsExternalUser,
		 "Catalog.ExternalUsers.ObjectForm",
		 "Catalog.Users.ObjectForm"),
		 New Structure("Key", CurrentData.Ref));
	EndIf;
	
EndProcedure



















