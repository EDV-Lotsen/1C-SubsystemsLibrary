
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
 
// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
 
		If Parameters.Property("Autotest") Then		
Return;
	EndIf;
	
	Items.AddressingGroup.Enabled = Not Object.Predefined;
	If Not Object.Predefined Then
		Items.AddressingObjectTypesGroup.Enabled = Object.UsedByAddressingObjects;
	EndIf;
	
	RefreshEnabled();
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	If Upper(ChoiceSource.FormName) = Upper("CommonForm.ExchangePlanNodeSelection") Then
		If ValueIsFilled(SelectedValue) Then
			Object.ExchangeNode = SelectedValue;
		EndIf;
	EndIf;
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, AttributesToCheck)
	
	If Object.ExternalRole And Not ValueIsFilled(Object.ExchangeNode) Then
		CommonUseClientServer.MessageToUser( 
		    NStr("en = 'Specify the infobase where the role performers are defined.'"),
			,
			"ExchangeNode",
			"Object",
			Cancel);
	EndIf;		
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM ITEM EVENT HANDLERS

&AtClient
Procedure UsedInOtherAddressingDimensionsContextOnChange(Item)
	Items.AddressingObjectTypesGroup.Enabled = Object.UsedByAddressingObjects;
EndProcedure

&AtClient
Procedure ExternalRoleOnChange(Item)
	
	ExternalRoleOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure ExchangeNodeStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	
	ExchangePlansForChoice = New Array;
	BusinessProcessesAndTasksClientOverridable.FillExchangePlanArray(ExchangePlansForChoice);
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("CurrentRow", Object.ExchangeNode);
	FormParameters.Insert("ChooseAllNodes", False);
	FormParameters.Insert("ExchangePlansForChoice", ExchangePlansForChoice);
	FormParameters.Insert("CloseOnChoice", True);
	FormParameters.Insert("MultipleChoice", False);
	
	OpenForm("CommonForm.ExchangePlanNodeSelection", FormParameters, ThisObject);
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	CommonUseClient.ShowCommentEditingForm(Item.EditText, ThisObject, "Object.Comment");
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// AUXILIARY PROCEDURES AND FUNCTIONS

&AtServer
Procedure ExternalRoleOnChangeAtServer()
	
	Object.UsedWithoutAddressingObjects = True;
	Object.UsedByAddressingObjects = False;
	RefreshEnabled();
	
EndProcedure

&AtServer
Procedure RefreshEnabled()
	
	ExternalTasksAndBusinessProcessesUsed = False;
	BusinessProcessesAndTasksServer.OnDefineUseExternalTasksAndBusinessProcesses(ExternalTasksAndBusinessProcessesUsed);
	
	If ExternalTasksAndBusinessProcessesUsed Then
		
		If Object.ExternalRole Then
			Items.UsedWithoutOtherAddressingDimensionsContext.Enabled = False;
			Items.UsedInOtherAddressingDimensionsContext.Enabled = False;
			Items.MainAddressingObjectTypes.Enabled = False;
			Items.AdditionalAddressingObjectTypes.Enabled = False;
			Items.ExchangeNode.Enabled = True;
			Items.ExchangeNode.AutoMarkIncomplete = True;
		Else
			Items.UsedWithoutOtherAddressingDimensionsContext.Enabled = True;
			Items.UsedInOtherAddressingDimensionsContext.Enabled = True;
			Items.MainAddressingObjectTypes.Enabled = True;
			Items.AdditionalAddressingObjectTypes.Enabled = True;
			Items.ExchangeNode.Enabled = False;
			Items.ExchangeNode.AutoMarkIncomplete = False;
		EndIf;
		
	Else
		
		Items.UsedWithoutOtherAddressingDimensionsContext.Enabled = True;
		Items.UsedInOtherAddressingDimensionsContext.Enabled = True;
		Items.MainAddressingObjectTypes.Enabled = True;
		Items.AdditionalAddressingObjectTypes.Enabled = True;
		Items.ExchangeNode.Visible = False;
		Items.ExchangeNode.AutoMarkIncomplete = False;
		Items.ExternalRole.Visible = False;
		
	EndIf;
		
EndProcedure

#EndRegion
