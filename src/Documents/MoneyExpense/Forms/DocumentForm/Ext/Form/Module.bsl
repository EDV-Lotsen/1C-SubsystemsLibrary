//////////////////////////////////////////////////////////////
// Event handlers

&AtClient
Procedure CompanyOnChange(Item)
	
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
Procedure OnReadAtServer(CurrentObject)
	
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

// StandardSubsystems.ObjectAttributeEditProhibition
&AtClient
Procedure Attachable_AllowObjectAttributeEdit()

	ObjectAttributeEditProhibitionClient.AllowObjectAttributeEdit(ThisObject);	

EndProcedure 

// End StandardSubsystems.ObjectAttributeEditProhibition