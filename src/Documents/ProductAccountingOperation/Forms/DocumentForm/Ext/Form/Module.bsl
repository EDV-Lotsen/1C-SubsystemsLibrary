//////////////////////////////////////////////////////////////////////////////// 
// EVENT HANDLERS
// 

&AtClient
Procedure CompanyOnChange(Element)
	
	OptionsParameters = New Structure("Company", Object.Company);
	SetFormFunctionalOptionParameters(OptionsParameters);
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Key.IsEmpty() Then 
		
		OptionsParameters = New Structure("Company", Object.Company);
		SetFormFunctionalOptionParameters(OptionsParameters);
		
	EndIf;
	
	// StandardSubsystems.ObjectVersioning
	ObjectVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.ObjectAttributeEditProhibition
	ObjectAttributeEditProhibition.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributeEditProhibition
	
EndProcedure


&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	OptionsParameters = New Structure("Company", Object.Company);
	SetFormFunctionalOptionParameters(OptionsParameters);
	
EndProcedure


&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	OptionsParameters = New Structure("Company", Object.Company);
	SetFormFunctionalOptionParameters(OptionsParameters);
	
	// StandardSubsystems.ObjectAttributeEditProhibition
	ObjectAttributeEditProhibition.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributeEditProhibition
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	Inventory = FormAttributeToValue("Object.RegisterRecords.Inventory");
	
	If Inventory.Count() = 0 Then
		
		Message = New UserMessage;
		Message.Text = NStr("en = 'The RegisterRecords data is required!'");
		Message.Message();
		Cancel = True;
		
	EndIf;
	
	If Not Inventory.CheckFilling() Then
		
		Cancel = True;
		
	EndIf;
	
EndProcedure

// StandardSubsystems.ObjectAttributeEditProhibition
&AtClient
Procedure Attachable_AllowObjectAttributeEdit()

	ObjectAttributeEditProhibitionClient.AllowObjectAttributeEdit(ThisObject);	

EndProcedure 

// End StandardSubsystems.ObjectAttributeEditProhibition
