///////////////////////////////////////////////////////////////////////////////////
// SuppliedDataClientServer: the supplied data service mechanism.
//
///////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// ManualEdit flag event handlers.
// This flag is used on separated supplied data forms.  
//
// All procedures that provide ManualEdit flag event processing contain only one parameter: 
// Form            - item ManagedForm. 
// The form must contain the following attributes:
//  Object         - object of separated supplied data.
//  ManualEdit     - Arbitrary - state of the separated object relative to the shared
//                   one. This attribute must not be displayed on the form.
//  ManualEditText - String, 0 - inscription that describes the state of the separated 
//                   object relative to the shared one.
// The form must contain the following buttons:
//  UpdateFromClassifier,
//  Change.
//

///////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Specifies the separated object state text, sets enable states of state control  
// buttons and the ReadOnly form flag.
//
Procedure ProcessManualEditFlag(Val Form) Export
	
	Items = Form.Items;
	
	If Form.ManualEdit = Undefined Then
		Form.ManualEditText = NStr("en = 'The item was created manually. It cannot be updated automatically.'");
		
		Items.UpdateFromClassifier.Enabled = False;
		Items.Change.Enabled = False;
		Form.ReadOnly = False;
	ElsIf Form.ManualEdit = True Then
		Form.ManualEditText = NStr("en = 'Automatic item update is disabled.'");
		
		Items.UpdateFromClassifier.Enabled = True;
		Items.Change.Enabled = False;
		Form.ReadOnly = False;
	Else
		Form.ManualEditText = NStr("en = 'The item is updated automatically.'");
		
		Items.UpdateFromClassifier.Enabled = False;
		Items.Change.Enabled = True;
		Form.ReadOnly = True;
	EndIf;
	
EndProcedure

#If Client Then
// Asks the user to update the item using common data.
// Returns True, if the user answer is Yes.
//
Function RefreshItemFromCommonData(Val Form) Export
	
	Text = NStr("en = 'Data of supplied data item will be replaced with common data.
		|All manual changes will be lost. Do you want to continue?'");
	Result = DoQueryBox(Text, QuestionDialogMode.YesNo, , DialogReturnCode.No);
	
	If Result = DialogReturnCode.Yes Then
		Form.LockFormDataForEdit();
		Form.Modified = True;
		
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

// Asks the user to disable future automatic updates using common data.
// Changes the object state, if the user answer is Yes.
//
Procedure ChangeSeparatedItem(Val Form) Export
	
	Text = NStr("en = 'Supplied data is updated automatically.
		|By applying your changes, you will disable future automatic updates of this item.
		|Do you want to save changes and continue?'");
	Result = Undefined;

	ShowQueryBox(New NotifyDescription("ChangeSeparatedItemEnd", ThisObject, New Structure("Form", Form)), Text, QuestionDialogMode.YesNo, , DialogReturnCode.No);
	
EndProcedure

Procedure ChangeSeparatedItemEnd(QuestionResult, AdditionalParameters) Export
	
	Form = AdditionalParameters.Form;
	
	
	Result = QuestionResult;
	
	If Result = DialogReturnCode.Yes Then
		
		Form.LockFormDataForEdit();
		Form.Modified = True;
		
		Form.ManualEdit = True;
		
		ProcessManualEditFlag(Form);
		
	EndIf;

EndProcedure
#EndIf
