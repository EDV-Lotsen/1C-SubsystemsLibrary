////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	CITypeAddress = Enums.ContactInformationTypes.Address;
	CITypePhone = Enums.ContactInformationTypes.Phone;
	CITypeFax = Enums.ContactInformationTypes.Fax;
	CheckFormItems(ThisForm);
	
EndProcedure

&AtClient
Procedure AfterWrite()
	
	CheckFormItems(ThisForm);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure TypeOnChange(Item)
	
	CheckFormItems(ThisForm);
	
EndProcedure

&AtClient
Procedure EditInDialogOnlyOnChange(Item)
	
	CheckFormItems(ThisForm);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtClientAtServerNoContext
Procedure CheckFormItems(Form)
	
	IsNew = Not ValueIsFilled(Form.Object.Ref);
	
	If IsNew Then
		// Setting the flag of Can change the edit mode to True for new kinds of contact information
		Form.Object.CanChangeEditMode = True;
		
	Else
		// Prohibiting folder and type change for previously recorded objects
		Form.Items.Parent.ReadOnly = True;
		Form.Items.Type.ReadOnly = True;
		
		// Prohibiting description change for predefined objects
		If Form.Object.Predefined Then
			Form.Items.Description.ReadOnly = True;
		EndIf;
		
	EndIf;
	
	If Not Form.Object.CanChangeEditMode Then
		// If the edit mode cannot be changed, preventing access to the other items
		Form.Items.EditInDialogOnly.Enabled = False;
		Form.Items.HomeCountryAddressOnly.Enabled = False;
		Return;
	
	EndIf;
	
	IsAddress = (Form.Object.Type = Form.CITypeAddress);
	IsPhone = (Form.Object.Type = Form.CITypePhone);
	IsFax = (Form.Object.Type = Form.CITypeFax);
	
	// Setting availability and checking the value of the EditInDialogOnly field
	If IsAddress Or IsPhone Or IsFax Then
		Form.Items.EditInDialogOnly.Enabled = True;
	Else
		Form.Items.EditInDialogOnly.Enabled = False;
		If Form.Object.EditInDialogOnly Then
			Form.Object.EditInDialogOnly = False;
		EndIf;
	EndIf;
		
	// Setting availability and checking the value of the HomeCountryAddressOnly field
	If IsAddress And Form.Object.EditInDialogOnly Then
		Form.Items.HomeCountryAddressOnly.Enabled = True;
	Else
		Form.Items.HomeCountryAddressOnly.Enabled = False;
		If Form.Object.HomeCountryAddressOnly Then
			Form.Object.HomeCountryAddressOnly = False;
		EndIf;
	EndIf;
	
EndProcedure

