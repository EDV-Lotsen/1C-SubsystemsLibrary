
&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	CITypeAddress   = Enums.ContactInformationTypes.Address;
	CITypePhone 	= Enums.ContactInformationTypes.Phone;
	CITypeFax    	= Enums.ContactInformationTypes.Fax;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancellation)
	
	CheckFormItems();
	
EndProcedure

&AtClient
Procedure AfterWrite()
	
	CheckFormItems();
	
EndProcedure

&AtClient
Procedure TypeOnChange(Item)
	
	CheckFormItems();
	
EndProcedure

&AtClient
Procedure EditInDialogOnlyOnChange(Item)
	
	CheckFormItems();
	
EndProcedure

&AtClient
Procedure CheckFormItems()
	
	IsNew = Not ValueIsFilled(Object.Ref);
	
	If IsNew Then
		// for new CI kinds raise flag "Can change edit mode"
		Object.EditMethodEditable = True;
		
	Else
		// for already recorded items prohibit to edit group and type
		Items.Parent.ReadOnly = True;
		Items.Type.ReadOnly      = True;
		
		// prohibit to edit description for predefined items too
		If Object.Predefined Then
			Items.Description.ReadOnly = True;
		EndIf;
		
	EndIf;
	
	If Not Object.EditMethodEditable Then
		// If one cannot change object edit method, then disable access to the remaining items
		Items.EditInDialogOnly.Enabled = False;
		Items.AlwaysUseAddressClassifier.Enabled = False;
		Return;
	
	EndIf;
	
	ThisIsAddress   = (Object.Type = CITypeAddress);
	ThisIsPhone 	= (Object.Type = CITypePhone);
	ThisIsFax   	= (Object.Type = CITypeFax);
	
	// Define accessibility and check value of the field EditInDialogOnly
	If ThisIsAddress OR ThisIsPhone OR ThisIsFax Then
		Items.EditInDialogOnly.Enabled = True;
	Else
		Items.EditInDialogOnly.Enabled = False;
		If Object.EditInDialogOnly Then
			Object.EditInDialogOnly = False;
		EndIf;
	EndIf;
		
	// Define accessibility and check value of the field EditInDialogOnly
	If ThisIsAddress And Object.EditInDialogOnly Then
		Items.AlwaysUseAddressClassifier.Enabled = True;
	Else
		Items.AlwaysUseAddressClassifier.Enabled = False;
		If Object.AlwaysUseAddressClassifier Then
			Object.AlwaysUseAddressClassifier = False;
		EndIf;
	EndIf;
	
EndProcedure

