
#Region FormEventHadlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	Если Parameters.Property("SelfTest") Then
		Return;
	EndIf;
 
	// StandardSubsystems.ContactInformation
	ContactInformationManagement.OnCreateAtServer(ThisObject, Object, "ContactInformationGroup");
	// End StandardSubsystems.ContactInformation
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.ContactInformation
	ContactInformationManagement.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.ContactInformation
		
EndProcedure
 
&AtServer
Procedure FillCheckProcessingAtServer(Cancel, AttributesToCheck)

	// StandardSubsystems.ContactInformation	 
	ContactInformationManagement.FillCheckProcessingAtServer(ThisObject, Object, Cancel);
	// End StandardSubsystems.ContactInformation
 
EndProcedure
 
&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// StandardSubsystems.ContactInformation
	ContactInformationManagement.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.ContactInformation
 
EndProcedure
 
&AtClient
Procedure AfterWrite(WriteParameters)
	
	
	
EndProcedure

#Endregion

#Region ServiceProceduresAndFunctions


////////////////////////////////////////////////////////////////////////////////
// CONTACT INFORMATION SUBSYSTEM PROCEDURES

// StandardSubsystems.ContactInformation

&AtClient
Procedure Attachable_ContactInformationOnChange(Item)
	
	ContactInformationManagementClient.PresentationOnChange(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationStartChoice(Item, ChoiceData, StandardProcessing)
	
	Result = ContactInformationManagementClient.PresentationStartChoice(ThisObject, Item, , StandardProcessing);
	RefreshContactInformation(Result);
 
EndProcedure

&AtClient
Procedure Attachable_ContactInformationCleanup(Item, StandardProcessing)
	
	Result = ContactInformationManagementClient.PresentationClearing(ThisObject, Item.Name);
	RefreshContactInformation(Result);
	
EndProcedure
 
&AtClient
Procedure Attachable_ContactInformationExecuteCommand(Command)
	
	Result = ContactInformationManagementClient.AttachableCommand(ThisObject, Command.Name);
	RefreshContactInformation(Result);
	ContactInformationManagementClient.OpenAddressInputForm(ThisObject, Result);

EndProcedure

&AtServer
Function RefreshContactInformation(Result = Undefined)
	
	Return ContactInformationManagement.UpdateContactInformation(ThisObject, Object, Result);
	
EndFunction


// End StandardSubsystems.ContactInformation

#EndRegion