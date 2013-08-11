////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillUserList();
	User = UserName();
	RefreshFormList();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure UserOnChange(Item)
	
	RefreshFormList();
	
EndProcedure

&AtClient
Procedure SearchOnChange(Item)
	
	ApplyFilter();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure RefreshExecute()
	
	RefreshFormList();
	
EndProcedure

&AtClient
Procedure CopyExecute()
	
	If Items.FilteredForms.SelectedRows.Count() = 0 Then
		DoMessageBox(NStr("en = 'You should select settings to be copied.'"));
		Return;
	EndIf;
	
	UserList = Items.User.ChoiceList.Copy();
	
	If UserList.Count() = 0 Then
		DoMessageBox(NStr("en = 'It is impossible to copy settings because there are no user accounts in the application.'"));
		Return;
	EndIf;
	
	ListItem = UserList.FindByValue(User);
	If ListItem <> Undefined Then
		UserList.Delete(ListItem);
	EndIf;
	
	If UserList.CheckItems(NStr("en = 'Mark users to whom the settings will be copied.'")) Then
		UsersTarget = New Array;
		For Each Item In UserList Do
			Items.User.ChoiceList.FindByValue(Item.Value).Mark = Item.Check;
			If Item.Check Then
				UsersTarget.Add(Item.Value);
			EndIf;
		EndDo;
		
		If UsersTarget.Count() = 0 Then
			DoMessageBox(NStr("en = 'You should select users to whom the settings will be copied.'"));
			Return;
		EndIf;
		
		QuestionText = NStr("en = 'After you copy settings to a user,
		|previous settings of this user will be lost. 
		|Are you really want to copy settings to the selected users?'");
		Response = DoQueryBox(QuestionText, QuestionDialogMode.YesNo,, DialogReturnCode.Yes);
		If Response = DialogReturnCode.No Then
			Return;
		EndIf;
		
		CopyAtServer(UsersTarget);
		ShowUserNotification(NStr("en = 'Settings are copied'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteExecute()
	
	If Items.FilteredForms.SelectedRows.Count() = 0 Then
		
		DoMessageBox(NStr("en = 'You should select settings to be deleted.'"));
		Return;
		
	EndIf;
	
	QuestionText = NStr("en = 'After you delete settings, the form will be opened with default settings. 
	|Are you really want to copy settings?'");
	Response = DoQueryBox(QuestionText, QuestionDialogMode.YesNo,, DialogReturnCode.Yes);
	If Response = DialogReturnCode.No Then
		
		Return;
		
	EndIf;
	
	DeleteAtServer();
	
	ShowUserNotification(NStr("en = 'Settings are deleted'"));
	
EndProcedure

&AtClient
Procedure SearchExecute()
	
	ApplyFilter();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Procedure FillUserList()
	
	SetPrivilegedMode(True);
	UserList = InfoBaseUsers.GetUsers();
	
	For Each CurrentUser In UserList Do
		
		Items.User.ChoiceList.Add(CurrentUser.Name);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure RefreshFormList()
	
	DataProcessor = FormAttributeToValue("Object");
	FormsList = New ValueList;
	DataProcessor.GetFormList(FormsList);
	Forms.Clear();
	DataProcessor.GetSavedSettingsList(FormsList, User, Forms);
	
	ApplyFilter();
	
EndProcedure

&AtServer
Function GetSelectedSettingsArray()
	
	SettingsArray = New Array;
	
	SelectedItems = Items.FilteredForms.SelectedRows;
	
	For Each SelectedItem In SelectedItems Do
		
		SettingsArray.Add(Forms.FindByValue(FilteredForms.FindByID(SelectedItem).Value).Value);
		
	EndDo;
	
	Return SettingsArray;
	
EndFunction

&AtServer
Procedure CopyAtServer(UsersTarget)
	
	SettingsToCopyArray = GetSelectedSettingsArray();
	
	DataProcessor = FormAttributeToValue("Object");
	DataProcessor.CopyFormSettings(User, UsersTarget, SettingsToCopyArray);
	
EndProcedure

&AtServer
Procedure DeleteAtServer()
	
	SettingsForDeletionArray = GetSelectedSettingsArray();
	
	DataProcessor = FormAttributeToValue("Object");
	DataProcessor.DeleteFormSettings(User, SettingsForDeletionArray);
	
	RefreshFormList();
	
EndProcedure

&AtServer
Procedure ApplyFilter()
	
	FilteredForms.Clear();
	
	For Each ItemForm In Forms Do
		
		If Search = "" or Find(Upper(ItemForm.Presentation), Upper(Search)) <> 0 Then
			
			FilteredForms.Add(ItemForm.Value, ItemForm.Presentation, ItemForm.Check, ItemForm.Picture);
			
		EndIf;
		
	EndDo;
	
	ActiveSearch = Search;
	
EndProcedure