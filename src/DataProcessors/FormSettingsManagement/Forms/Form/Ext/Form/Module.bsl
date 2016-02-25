//////////////////////////////////////////////////////////////////////
// Helper procedures and functions

// This procedure populates the information base users list
&AtServer
Procedure FillUsersList()
	
	UserList = InfoBaseUsers.GetUsers();
	
	If UserList.Count() > 0 Then
 
		For Each CurUser In UserList Do
		
			Items.User.ChoiceList.Add(CurUser.Name);
		
		EndDo;
 
	Else
 
		Items.User.Enabled = False;
		Items.Copy.Enabled = False;
 
	EndIf;
	
EndProcedure

// This procedure updates the list of saved forms settings
&AtServer
Procedure RefreshFormList()
	
	DataProcessor = FormDataToValue(Object, Type("DataProcessorObject.FormSettingsManagement"));
	Forms.Clear();
	DataProcessor.GetSavedSettingsList(User, Forms);
	
EndProcedure

// This function gets the marked settings as an array
//
// Returns:
//  Array names settings forms
&AtServer
Function GetSelectedSettingsArray()
	
	SettingsArray = New Array;
	
	MarkedItems = Items.FilteredForms.SelectedRows;
	
	For Each MarkedItem In MarkedItems Do
		
		SettingsArray.Add(Forms.FindByValue(FilteredForms.FindByID(MarkedItem).Value).Value);
		
	EndDo;
	
	Return SettingsArray;
	
EndFunction

// This procedure copies the selected settings to the specified user
// Parameters :
//  UsersTarget - the user name, whom to copy settings
&AtServer
Procedure CopyAtServer(UsersTarget)

	SettingsArrayToCopy = GetSelectedSettingsArray();
	
	DataProcessor = FormDataToValue(Object, Type("DataProcessorObject.FormSettingsManagement"));
	DataProcessor.CopyFormSettings(User, UsersTarget, SettingsArrayToCopy);
		
EndProcedure

// Procedure removes selected Settings
&AtServer
Procedure DeleteAtServer()
	
	SettingsForDeletionArray = GetSelectedSettingsArray();
	
	DataProcessor = FormDataToValue(Object, Type("DataProcessorObject.FormSettingsManagement"));
	DataProcessor.DeleteFormSettings(User, SettingsForDeletionArray);
	
EndProcedure

// This procedure applies the filter to the list of settings
&AtServer
Procedure ApplyFilter()
	
	FilteredForms.Clear();
	
	For Each ItemForm In Forms Do
		
		If SearchString = "" Or Find(Upper(ItemForm.Presentation), Upper(SearchString)) <> 0 Then
			
			FilteredForms.Add(ItemForm.Value, ItemForm.Presentation, ItemForm.Check, ItemForm.Picture);
			
		EndIf;
		
	EndDo;
	
	AppliedSearch = SearchString;
	
EndProcedure

//////////////////////////////////////////////////////////////////////
// Commands handlers

// Handler Commands Refresh
&AtClient
Procedure RefreshExecute()
	
	RefreshFormList();
	ApplyFilter();
	
EndProcedure

// The Copy to another user commend handler
&AtClient
Procedure CopyExecute()
	
	If Items.FilteredForms.SelectedRows.Count() = 0 Then
		
		ShowMessageBox( ,NStr("en = 'Choose settings to be to copied.'"));
		Return;
		
	EndIf;
	
	UserChoiceList =  Items.User.ChoiceList.Copy();

	UserChoiceList.Delete(
		UserChoiceList.FindByValue(User));
	
	Notification =  New  NotifyDescription(
		"CopyExecuteCompletion",
		ThisObject,  UserChoiceList);
	UserChoiceList.ShowCheckItems(Notification,
		NStr("en = 'Select users which you want the settings to be copied.'"));
EndProcedure

&AtClient
Procedure CopyExecuteCompletion(Result, UserList) Export
 
	If Result <> Undefined Then	 
 
		UsersTarget = New Array;

		For Each Element In UserList Do
			
			Items.User.ChoiceList.FindByValue(Element.Value).Check = Element.Check;
			If Element.Check Then
				
				UsersTarget.Add(Element.Value);
				
			EndIf;
			
		EndDo;
		
		If UsersTarget.Count() = 0 Then
			
			ShowMessageBox(,NStr("en = 'Select users which you want the settings to be copied.'"));
			Return;
			
		EndIf;
		
		Activity = "ExecuteCopy";
		ButtonList = New ValueList;
		ButtonList.Add(Activity, NStr("en = 'Copy'"));
		ButtonList.Add(DialogReturnCode.Cancel);
		Context =  New Structure("Activity, UsersTarget", Activity,  UsersTarget);

		Notification =  New NotifyDescription(
			"CopyExecuteQueryCompletion",
			ThisObject,  Context);
		ShowQueryBox(Notification,
			NStr("en = 'Once the settings is copied, the user form is opened with the settings been copied. The current form settings will be lost.'"),
			ButtonList, , Activity);
	EndIf;
EndProcedure

&AtClient
Procedure CopyExecuteQueryCompletion(Result, Context) Export
	If Result =  Context.Activity  Then
		CopyAtServer(Context.UsersTarget);
		ShowUserNotification(NStr("en = 'Settings copied'"));
	EndIf;
EndProcedure 

// Delete command handler 
&AtClient
Procedure DeleteExecute()
	
	If Items.FilteredForms.SelectedRows.Count() = 0 Then
		
		ShowMessageBox(,NStr("en = 'Select settings to be deleted.'"));
		Return;
		
	EndIf;
	
	Activity = "DeleteExecute";
	ButtonList = New ValueList;
	ButtonList.Add(Activity, NStr("en = 'Delete'"));
	ButtonList.Add(DialogReturnCode.Cancel);
Notification =  New  NotifyDescription(

		"DeleteExeciteQueryCompletion",  ThisObject,  Activity);
	ShowQueryBox(Notification,
		NStr("en = 'Once the settings are deleted the form is opened with the default settings.'"),
		ButtonList,  , Activity);
	
EndProcedure

&AtClient
Procedure  DeleteExeciteQueryCompletion(Result,  Activity)  Export
	If  Result =  Activity Then
		DeleteAtServer();
		RefreshFormList();
		ApplyFilter();
		
		ShowUserNotification(NStr("en = 'Settings deleted'"));
	EndIf;
EndProcedure 

// Search command handler
&AtClient
Procedure SearchExecute()
	
	ApplyFilter();
	
EndProcedure

//////////////////////////////////////////////////////////////////////
// Form events handlers

// Create form event handler
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillUsersList();
	User = UserName();
	RefreshFormList();
	ApplyFilter();
	
EndProcedure

//////////////////////////////////////////////////////////////////////
// The controls event handlers

// The user name change handler
&AtClient
Procedure UserOnChange(Element)
	
	RefreshFormList();
	ApplyFilter();
	
EndProcedure

// Search string change handler
&AtClient
Procedure SearchOnChange(Element)
	
	ApplyFilter();
	
EndProcedure