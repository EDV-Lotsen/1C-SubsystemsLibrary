
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
 
 // Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
		If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	MainAddressingObject = Parameters.MainAddressingObject;
	RefreshItemsData();
	BusinessProcessesAndTasksServer.OnDefineUseExternalTasksAndBusinessProcesses(UseExternalTasksAndBusinessProcesses);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "Write_RoleAddressing" Then
		RefreshItemsData();
 	EndIf;
EndProcedure

#EndRegion

#Region ListFormTableItemEventHandlers

&AtClient
Procedure ListChoice(Item, SelectedRow, Field, StandardProcessing)
	AssignPerformers(Undefined);
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	AssignPerformers(Undefined);
	Cancel = True;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure AllPurposesExecute(Command)
	
	OpenForm("InformationRegister.TaskPerformers.ListForm", 
		New Structure("Filter", New Structure("MainAddressingObject", MainAddressingObject)),
		ThisObject);
	
EndProcedure

&AtClient
Procedure RefreshExecute(Command)
	RefreshItemsData();
EndProcedure

&AtClient
Procedure AssignPerformers(Command)
	
	Purpose = Items.List.CurrentData;
	If Purpose = Undefined Then
		ShowMessageBox(,NStr("en = 'Select a role.'"));
		Return;
	EndIf;
	
	If UseExternalTasksAndBusinessProcesses Then
		If Purpose.ExternalRole = True Then
			ShowMessageBox(,NStr("en = 'External role performers must be defined in another infobase.'"));
			Return;
		EndIf;
	EndIf;

	OpenForm("InformationRegister.TaskPerformers.Form.AddressingByObjectAndRole", 
		New Structure("MainAddressingObject,Role", 
			MainAddressingObject, 
			Purpose.RoleReference));
			
EndProcedure

&AtClient
Procedure RoleList(Command)
	OpenForm("Catalog.PerformerRoles.ListForm",,ThisObject);
EndProcedure

&AtClient
Procedure OpenRoleInfo(Command)
	
	If Items.List.CurrentData = Undefined Then
		Return;	
	EndIf;
	
	ShowValue(, Items.List.CurrentData.RoleReference);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure RefreshItemsData()
	
	QuerySelection = BusinessProcessesAndTasksServer.SelectRolesWithPerformerCount(MainAddressingObject);
	ObjectList = FormAttributeToValue("List");
	ObjectList.Clear();
	While QuerySelection.Next() Do
		ValueType = QuerySelection.MainAddressingObjectTypes.ValueType;
		IncludesType = True;
		If MainAddressingObject <> Undefined Then
			IncludesType = ValueType <> Undefined And ValueType.ContainsType(TypeOf(MainAddressingObject));
		EndIf;
		If IncludesType Then
			NewRow = ObjectList.Add();
			FillPropertyValues(NewRow, QuerySelection, "Performers,Role,RoleReference,ExternalRole"); 
		EndIf;
	EndDo;
	ObjectList.Sort("Role");
	For Each ListRow In ObjectList Do
		If ListRow.Performers = 0 Then
			ListRow.PerformersString = ?(ListRow.ExternalRole, NStr("en = 'defined in another infobase'"), NStr("en = 'undefined'"));
			ListRow.Picture = ?(ListRow.ExternalRole, -1, 1);
		ElsIf ListRow.Performers = 1 Then
			ListRow.PerformersString = String(BusinessProcessesAndTasksServer.SelectPerformer(MainAddressingObject, ListRow.RoleReference));
			ListRow.Picture = -1;
		Else
			ListRow.PerformersString =
			  StringFunctionsClientServer.SubstituteParametersInString(
			  NStr("en = '%1 people'"), String(ListRow.Performers) );
			
			ListRow.Picture = -1;
		EndIf;
	EndDo;
	ValueToFormAttribute(ObjectList, "List");
	
EndProcedure

#EndRegion
