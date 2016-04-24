
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Var FormTitleText;
 
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	If Parameters.Property("FormTitle", 
FormTitleText) And
		Not IsBlankString(FormTitleText) Then
		Title = FormTitleText;
		AutoTitle = False;
				
	EndIf;
	
	If Parameters.Property("BusinessProcess") Then
		BusinessProcessString = Parameters.BusinessProcess;
		TaskString = Parameters.Task;
		Items.TitleGroup.Visibility = True;
	EndIf;
	
	If Parameters.Property("ShowTasks") Then
		ShowTasks = Parameters.ShowTasks;
	Else
		ShowTasks = 2;
	EndIf;
	
	If Parameters.Property("FilterVisibility") Then
		Items.FilterGroup.Visibility = Parameters.FilterVisibility;
	Else	
		ByAuthor = Users.CurrentUser();
	EndIf;
	SetFilter();
	
	If Parameters.Property("OwnerWindowLock") Then
		WindowOpeningMode = Parameters.OwnerWindowLock;
	EndIf;
		
	UseDateAndTimeInTaskDeadlines = 
GetFunctionalOption
("UseDateAndTimeInTaskDeadlines");
	Items.DueDate.Format = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	Items.CompletionDate.Format = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	
	BusinessProcessesAndTasksServer.SetTaskAppearance(List);
	
	// Setting dynamic list filter
	CommonUseClientServer.SetDynamicListFilterItem(
		List, "DeletionMark", False, DataCompositionComparisonType.Equal, , False,
		DataCompositionSettingsItemViewMode.Normal);
	
	CommonUseClientServer.MoveFiltersToDynamicList(ThisObject);
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_PerformerTask" Then
		RefreshTaskListAtServer();
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeLoadDataFromSettingsAtServer(Settings)

	SettingName = ?(Parameters.Property("BusinessProcess"), "BPListForm", "ListForm");
	FilterSettings = CommonUse.SystemSettingsStorageLoad("Tasks.PerformerTask.Forms.ListForm", SettingName);
	If FilterSettings = Undefined Then 
		Settings.Clear();
		Return;
	EndIf;
	
	For Each Item In FilterSettings Do
		Settings.Insert(Item.Key, Item.Value);
	EndDo;
	SetListFilter(List, FilterSettings);
	
EndProcedure

&AtServer
Procedure OnSaveDataInSettingsAtServer(Settings)
	SettingsName = ?(Items.TitleGroup.Visibility, "BPListForm", "ListForm");
	CommonUse.SystemSettingsStorageSave("Tasks.PerformerTask.Forms.ListForm", SettingsName, Settings);
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure ByPerformerOnChange(Item)
	SetFilter();
EndProcedure

&AtClient
Procedure ByAuthorOnChange(Item)
	SetFilter();
EndProcedure

&AtClient
Procedure ShowTasksOnChange(Item)
	SetFilter();
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure AcceptForExecution(Command)
	
	BusinessProcessesAndTasksClient.AcceptTasksForExecution(Items.List.SelectedRows);
	
EndProcedure

&AtClient
Procedure CancelAcceptForExecution(Command)
	
	BusinessProcessesAndTasksClient.CancelAcceptTasksForExecution(Items.List.SelectedRows);
	
EndProcedure

&AtClient
Procedure RefreshTaskList(Command)
	
	RefreshTaskListAtServer();
	
EndProcedure

&AtClient
Procedure OpenBusinessProcess(Command)
	If TypeOf(Items.List.CurrentRow) <> Type("TaskRef.PerformerTask") Then
		ShowMessageBox(,NStr("en = 'Cannot execute the command for the specified object.'"));
		Return;
	EndIf;
	If Items.List.CurrentData.BusinessProcess = Undefined Then
		ShowMessageBox(,NStr("en = 'The business process of the selected task is not specified'"));
		Return;
	EndIf;
	ShowValue(, Items.List.CurrentData.BusinessProcess);
EndProcedure

&AtClient
Procedure OpenTaskSubject(Command)
	If TypeOf(Items.List.CurrentRow) <> Type("TaskRef.PerformerTask") Then
		ShowMessageBox(,NStr("en = 'Cannot execute the command for the specified object.'"));
		Return;
	EndIf;
	If Items.List.CurrentData.Subject = Undefined Then
		ShowMessageBox(,NStr("en = 'The subject of the selected task is not specified.'"));
		Return;
	EndIf;
	ShowValue(, Items.List.CurrentData.Subject);
EndProcedure

#EndRegion

#Region ListFormTableItemEventHandlers

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, Group)
	
	BusinessProcessesAndTasksClient.TaskListBeforeAddRow(ThisObject, Item, Cancel, Clone, 
		Parent, Group);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetFilter()
	
	FilterParameters = New Map();
	FilterParameters.Insert("ByAuthor", ByAuthor);
	FilterParameters.Insert("ByPerformer", ByPerformer);
	FilterParameters.Insert("ShowTasks", ShowTasks);
	SetListFilter(List, FilterParameters);
	
EndProcedure	

&AtServerNoContext
Procedure SetListFilter(List, FilterParameters)
	
	CommonUseClientServer.SetDynamicListFilterItem(
		List, "Author", FilterParameters["ByAuthor"],,, FilterParameters["ByAuthor"] <> Undefined And Not FilterParameters["ByAuthor"].IsEmpty());
	
	If FilterParameters["ByPerformer"] = Undefined Or FilterParameters["ByPerformer"].IsEmpty() Then
		List.Parameters.SetParameterValue("Performer", NULL);
	Else	
		List.Parameters.SetParameterValue("Performer", FilterParameters["ByPerformer"]);
	EndIf;
		
	If FilterParameters["ShowTasks"] = 0 Then 
		CommonUseClientServer.SetDynamicListFilterItem(
			List, "Executed", True,,,False);
	ElsIf FilterParameters["ShowTasks"] = 1 
Then
		CommonUseClientServer.SetDynamicListFilterItem(
			List, "Executed", True,,,True);
	ElsIf FilterParameters["ShowTasks"] = 2 
Then
		CommonUseClientServer.SetDynamicListFilterItem(
			List, "Executed", False,,,True);
	EndIf;	
	
EndProcedure

&AtServer
Procedure RefreshTaskListAtServer()
	
	BusinessProcessesAndTasksServer.SetTaskAppearance(List);
	Items.List.Refresh();
	
EndProcedure

#EndRegion
