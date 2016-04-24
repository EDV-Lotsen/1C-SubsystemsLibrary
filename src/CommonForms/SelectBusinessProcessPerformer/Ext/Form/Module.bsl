
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	 
  // Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	If Parameters.SimpleRolesOnly Then
		CommonUseClientServer.SetDynamicListFilterItem(
			RolesList, "UsedWithoutAddressingObjects", True,,True);
	EndIf;	
	If Parameters.WithoutExternalRoles = True Then
		CommonUseClientServer.SetDynamicListFilterItem(
			RolesList, "ExternalRole", False);
	EndIf;	
	
	UpdateDataCompositionParameterValue(UsersList, "EmptyUUID", 
		New UUID("00000000-0000-0000-0000-000000000000"));
	
	If TypeOf(Parameters.Performer) = Type("CatalogRef.Users") Then
		
		CurrentItem = Items.UsersList;
		Items.UsersList.CurrentRow = Parameters.Performer;
		
	ElsIf TypeOf(Parameters.Performer) = Type("CatalogRef.PerformerRoles") Then
		
		Items.Pages.CurrentPage = Items.Roles;
		CurrentItem = Items.RolesList;
		Items.RolesList.CurrentRow = Parameters.Performer;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	If Upper(ChoiceSource.FormName) = Upper("CommonForm.SelectPerformerRole") Then
		If TypeOf(SelectedValue) = Type("Structure") Then
			NotifyChoice(SelectedValue);
		EndIf;
	EndIf;
EndProcedure

#EndRegion

#Region RolesListFormTableItemEventHandler

&AtClient
Procedure UsersListValueChoice(Item, Value, StandardProcessing)
	
	StandardProcessing = False;
	NotifyChoice(Value);
	
EndProcedure

&AtClient
Procedure RolesListValueChoice(Item, Value, StandardProcessing)
	
	StandardProcessing = False;
	ChooseRole(Item.CurrentData);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Select(Command)
	
	If Items.Pages.CurrentPage = Items.Users Then 
		NotifyChoice(Items.UsersList.CurrentRow);
		
	ElsIf Items.Pages.CurrentPage = Items.Roles Then 
		ChooseRole(Items.RolesList.CurrentData);
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Function ChooseRole(CurrentData)
	
	If CurrentData.UsedByAddressingObjects Then 
		FormParameters = New Structure;
		FormParameters.Insert("PerformerRole",              CurrentData.Ref);
		FormParameters.Insert("MainAddressingObject",       Undefined);
		FormParameters.Insert("AdditionalAddressingObject", Undefined);
		FormParameters.Insert("SelectAddressingObject",     True);
		OpenForm("CommonForm.SelectPerformerRole", FormParameters, ThisObject);
	Else
		SelectedValue = New Structure("PerformerRole, MainAddressingObject, AdditionalAddressingObject", CurrentData.Ref, Undefined, Undefined);
		NotifyChoice(SelectedValue);
	EndIf;
	
EndFunction

&AtClientAtServerNoContext
Procedure UpdateDataCompositionParameterValue(Val ParameterOwner, Val ParameterName, Val ParameterValue)
	
	For Each Parameter In ParameterOwner.Parameters.Items Do
		If String(Parameter.Parameter) = ParameterName Then
			If Parameter.Use And Parameter.Value = ParameterValue Then
				Return;
			EndIf;
			Break;
		EndIf;
	EndDo;
	
	ParameterOwner.Parameters.SetParameterValue(ParameterName, ParameterValue);
	
EndProcedure

#EndRegion
