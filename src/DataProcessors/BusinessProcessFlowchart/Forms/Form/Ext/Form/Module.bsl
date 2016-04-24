
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
 
 // Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.	
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	If ValueIsFilled(Parameters.BusinessProcess) Then
		BusinessProcess = Parameters.BusinessProcess;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	UpdateFlowchart();
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure BusinessProcessOnChange(Item)
	UpdateFlowchart();
EndProcedure

&AtClient
Procedure FlowchartChoice(Item)
	OpenRoutePointTaskList();
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure RefreshExecute(Command)
	UpdateFlowchart();   
EndProcedure

&AtClient
Procedure TasksExecute(Command)
	OpenRoutePointTaskList();
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure UpdateFlowchart()
	
	If ValueIsFilled(BusinessProcess) Then
		Flowchart = BusinessProcess.GetObject().GetFlowchart();
	ElsIf BusinessProcess <> Undefined Then
		Flowchart = BusinessProcesses[BusinessProcess.Metadata().Name].GetFlowchart();
		Return;
	Else
		Flowchart = New GraphicalSchema;
		Return;
	EndIf;
	
	HasState = BusinessProcess.Metadata().Attributes.Find("State") <> Undefined;
	BusinessProcessProperties = CommonUse.ObjectAttributeValues(
		BusinessProcess, "Author,Date,CompletionDate,Completed,Started" +
		?(HasState, ",State", ""));
	FillPropertyValues(ThisObject, BusinessProcessProperties);
	If BusinessProcessProperties.Completed Then
		Status = NStr("en = 'Completed'");
		Items.StatusGroup.CurrentPage = Items.CompletedGroup;
	ElsIf BusinessProcessProperties.Started Then
		Status = NStr("en = 'Started'");
		Items.StatusGroup.CurrentPage = Items.NotCompletedGroup;
	Else	
		Status = NStr("en = 'Not started'");
		Items.StatusGroup.CurrentPage = Items.NotCompletedGroup;
	EndIf;
	If HasState Then
		Status = Status + ", " + Lower(State);
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenRoutePointTaskList()

#If WebClient Then
	ShowMessageBox(,NStr("en = 'This operation is not available in the web client.'"));
	Return;
#EndIf
	ClearMessages();
	CurItem = Items.Flowchart.CurrentItem;

	If Not ValueIsFilled(BusinessProcess) Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Specify the business process.'"),,
			"BusinessProcess");
		Return;
	EndIf;
	
	If CurItem = Undefined Or
		Not (TypeOf(CurItem) = Type("GraphicalSchemaItemActivity")
		Or TypeOf(CurItem) = Type("GraphicalSchemaItemSubBusinessProcess")) Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Select an activity point or a nested business process on the flowchart.'"),,
			"Flowchart");
		Return;
	EndIf;

	FormTitle = NStr("en = 'Business process route point tasks'");
	
	OpenForm("Task.PerformerTask.ListForm", 
		New Structure("Filter,FormTitle,ShowTasks,FilterVisibility,OwnerWindowLock,Task,BusinessProcess", 
			New Structure("BusinessProcess,RoutePoint", BusinessProcess, CurItem.Value),
			FormTitle,0,False,FormWindowOpeningMode.LockOwnerWindow,String(CurItem.Value),String(BusinessProcess)),
		ThisObject, BusinessProcess);

EndProcedure

#EndRegion
