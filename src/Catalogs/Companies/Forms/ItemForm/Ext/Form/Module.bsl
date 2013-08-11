////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// StandardSubsystems.ContactInformation
	ContactInformationManagement.OnCreateAtServer(ThisForm, Object, "GroupContactInformation");
	// End StandardSubsystems.ContactInformation
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject)
	
	// StandardSubsystems.ContactInformation
	ContactInformationManagement.BeforeWriteAtServer(ThisForm, CurrentObject, Cancel);
	// End StandardSubsystems.ContactInformation
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INFORMATION"  "CONTACT SUBSYSTEM PROCEDURES

// StandardSubsystems.ContactInformation

&AtClient
Procedure Attachable_ContactInformationOnChange(Item)
	
	ContactInformationManagementClient.PresentationOnChange(ThisForm, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationStartChoice(Item, ChoiceData, StandardProcessing)
	
	ContactInformationManagementClient.PresentationStartChoice(ThisForm, Item, Modified, StandardProcessing);
	
EndProcedure

// End StandardSubsystems.ContactInformation