
////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM EVENTS HANDLERS

&AtServer
// Procedure handler events OnCreateAtServer.
// Initial filling of form attributes.
//
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	// Handler of the mechanism "Contact information".
	ContactInformationManagement.OnCreateAtServer(ThisForm, Object, "GroupContactInformation");
	
	// Handler of "Properties" system.
	AdditionalDataAndAttributesManagement.OnCreateAtServer(ThisForm, Object, "PageAdditionalAttributes");
	
	// Handler of subsystem "Additional reports and data processors"
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	
EndProcedure // OnCreateAtServer()

&AtClient
// Procedure handler events NotificationProcessing.
//
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Handler of "Properties" system.
	If AdditionalDataAndAttributesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		UpdateAdditionalDataAndAttributesItems();
	EndIf;
	
EndProcedure // NotificationProcessing()

&AtServer
// Procedure handler events OnCreateAtServer.
// Initial filling of form attributes.
//
Procedure BeforeWriteAtServer(Cancellation, CurrentObject, WriteParameters)
	
	// Handler of the mechanism "Contact information".
	ContactInformationManagement.BeforeWriteAtServer(ThisForm, CurrentObject, Cancellation);
	
	// Handler of "Properties" system.
	AdditionalDataAndAttributesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	
EndProcedure // BeforeWriteAtServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES OF THE MECHANISM "CONTACT INFORMATION"

&AtClient
// Procedure handler of event OnChange of input field ContactInformation.
//
Procedure Pluggable_ContactInformationOnChange(Item)
	
	ContactInformationManagementClient.PresentationOnChange(ThisForm, Item);
	
EndProcedure // Pluggable_ContactInformationOnChange()

&AtClient
// Procedure handler of event StartChoice of input field ContactInformation.
//
Procedure Pluggable_ContactInformationStartChoice(Item, ChoiceData, StandardProcessing)
	
	ContactInformationManagementClient.PresentationStartChoice(ThisForm, Item,Modified, StandardProcessing);
	
EndProcedure // Pluggable_ContactInformationStartChoice()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES OF SYSTEM 'PROPERTIES'

&AtClient
Procedure Pluggable_EditContentOfProperties(Command)
	
	AdditionalDataAndAttributesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
	
EndProcedure // Pluggable_EditContentOfProperties()

&AtServer
Procedure UpdateAdditionalDataAndAttributesItems()
	
	AdditionalDataAndAttributesManagement.UpdateAdditionalDataAndAttributesItems(ThisForm, FormAttributeToValue("Object"));
	
EndProcedure // UpdateAdditionalDataAndAttributesItems()


