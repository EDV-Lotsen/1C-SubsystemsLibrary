
////////////////////////////////////////////////////////////////////////////////
// COMMON PROCEDURES AND FUNCTIONS

&AtClient
// Procedure adjusts visibility of the form attributes.
//
// Parameters:
//  No.
//
Procedure SetAttributesVisibility()
	
	If Object.BusinessIndividual = Business Then
		Items.Individual.Visible = False;
		Object.Individual 		 = Undefined;
	Else
		Items.Individual.Visible = True;
	EndIf;
	
EndProcedure // SetAttributesVisibility()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM EVENTS HANDLERS

&AtServer
// Procedure handler events OnCreateAtServer.
// Initial filling of form attributes.
//
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	Business = Enums.BusinessIndividual.Business;
		
	If Object.BusinessIndividual = Business Then
		Items.Individual.Visible = False;
		Object.Individual 		 = Undefined;
	Else
		Items.Individual.Visible = True;
	EndIf;
	
	// Handler of the mechanism "Contact information".
	ContactInformationManagement.OnCreateAtServer(ThisForm, Object, "GroupContactInformation");
	
	// Handler of "Properties" system.
	AdditionalDataAndAttributesManagement.OnCreateAtServer(ThisForm, Object, "PageAdditionalAttributes");
	
	// Handler of subsystem "Additional reports and data processors"
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	
EndProcedure // OnCreateAtServer()

&AtClient
// Procedure handler of event OnOpen.
// Adjusts visibility of form attributes.
//
Procedure OnOpen(Cancellation)
	
	If NOT ValueIsFilled(Object.Ref)
	   And NOT FunctionalOptionMultipleCompanies Then
		TextOfMessage = NStr("en = 'A new Company cannot be added. ""Account by several Companies"" flag is not set!'");
		DoMessageBox(TextOfMessage);
		Cancellation = True;
	EndIf;
	
EndProcedure // OnOpen()

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
// Procedure handler events BeforeWriteAtServer.
//
Procedure BeforeWriteAtServer(Cancellation, CurrentObject, WriteParameters)
	
	// Handler of the mechanism "Contact information".
	ContactInformationManagement.BeforeWriteAtServer(ThisForm, CurrentObject, Cancellation);
	
	// Handler of "Properties" system.
	AdditionalDataAndAttributesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	
EndProcedure // BeforeWriteAtServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - EVENT HANDLERS OF FORM ATTRIBUTES

&AtClient
// Procedure handler of event OnChange of input field Description.
//
Procedure DescriptionOnChange(Item)
	
	If NOT ValueIsFilled(Object.PrintedName) Then
		Object.PrintedName = Object.Description;
	EndIf;
	
EndProcedure // DescriptionOnChange()

&AtClient
// Procedure handler of event OnChange of input field BusinessIndividual.
//
Procedure BusinessIndividualOnChange(Item)
	
	SetAttributesVisibility();
	
EndProcedure // BusinessIndividualOnChange()

&AtClient
// Procedure - handler of event StartChoice of field  DefaultBankAccount.
//
Procedure DefaultBankAccountStartChoice(Item, ChoiceData, StandardProcessing)
	
	If NOT ValueIsFilled(Object.Ref) Then
		
		StandardProcessing = False;
		Message = New UserMessage();
		Message.Text = NStr("en = 'Catalog item has not yet been written.'");
		Message.Message();
		
	EndIf;
	
EndProcedure // DefaultBankAccountStartChoice()

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
// Procedure - handler of event Run of command EditContentOfProperties.
//
Procedure Pluggable_EditContentOfProperties(Command)
	
	AdditionalDataAndAttributesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
	
EndProcedure // Pluggable_EditContentOfProperties()

&AtServer
// Procedure updates items of additional attributes.
//
Procedure UpdateAdditionalDataAndAttributesItems()
	
	AdditionalDataAndAttributesManagement.UpdateAdditionalDataAndAttributesItems(ThisForm, FormAttributeToValue("Object"));
	
EndProcedure // UpdateAdditionalDataAndAttributesItems()


