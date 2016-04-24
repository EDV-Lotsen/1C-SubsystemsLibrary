
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	ByAuthor = Users.CurrentUser();
	
	CommonUseClientServer.SetDynamicListFilterItem(
		List, "SourceTask", Tasks.PerformerTask.EmptyRef());
	
	SetFilter();
	UseDateAndTimeInTaskDeadlines = GetFunctionalOption("UseDateAndTimeInTaskDeadlines");
	Items.DueDate.Format = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	Items.VerificationDueDate.Format = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	BusinessProcessesAndTasksServer.SetBusinessProcessAppearance(List.ConditionalAppearance);
	
	CommonUseClientServer.MoveFiltersToDynamicList(ThisObject);
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	SetListFilter(Settings);	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure ByAuthorOnChange(Item)
	SetFilter();
EndProcedure

&AtClient
Procedure ByPerformerOnChange(Item)
	SetFilter();
EndProcedure

&AtClient
Procedure BySupervisorOnChange(Item)
	SetFilter();
EndProcedure

&AtClient
Procedure ShowCompletedJobsOnChange(Item)
	SetFilter();
EndProcedure

&AtClient
Procedure ShowStoppedOnChange(Item)
	
	SetFilter();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Stop(Command)
	
	BusinessProcessesAndTasksClient.Stop(Items.List.SelectedRows);
	
EndProcedure

&AtClient
Procedure ContinueBusinessProcess(Command)
	
	BusinessProcessesAndTasksClient.Activate(Items.List.SelectedRows);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetFilter()
	FilterParameters = New Map();
	FilterParameters.Insert("ShowCompletedJobs", ShowCompletedJobs);	
	FilterParameters.Insert("ShowStopped", ShowStopped);	
	FilterParameters.Insert("ByAuthor", ByAuthor);
	FilterParameters.Insert("ByPerformer", ByPerformer);
	FilterParameters.Insert("BySupervisor", BySupervisor);
	SetListFilter(FilterParameters);
EndProcedure	

&AtServer
Procedure SetListFilter(FilterParameters)
	
	CommonUseClientServer.SetDynamicListFilterItem(List, "Completed", False,,,
		Not FilterParameters["ShowCompletedJobs"]);
	CommonUseClientServer.SetDynamicListFilterItem(List, "Stopped", False,,,
		Not FilterParameters["ShowStopped"]);
	CommonUseClientServer.SetDynamicListFilterItem(List, "Author", FilterParameters["ByAuthor"],,,
		Not FilterParameters["ByAuthor"].IsEmpty());
	CommonUseClientServer.SetDynamicListFilterItem(List, "Performer", FilterParameters["ByPerformer"],,,
		Not FilterParameters["ByPerformer"].IsEmpty());
	CommonUseClientServer.SetDynamicListFilterItem(List, "Supervisor", FilterParameters["BySupervisor"],,,
		Not FilterParameters["BySupervisor"].IsEmpty());
	
EndProcedure

#EndRegion
