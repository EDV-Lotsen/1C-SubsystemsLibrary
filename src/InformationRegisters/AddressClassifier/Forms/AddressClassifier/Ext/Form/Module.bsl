
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	Data = ImportedStates();
	ImportedObjectDescription = Data.Title;
	Items.CheckForAddressClassifierUpdates.Enabled = Data.ImportedCount>0;    
	Items.ClearAddressClassifier.Enabled = Items.CheckForAddressClassifierUpdates.Enabled;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AddressClassifierImported" Or EventName = "AddressClassifierCleared" Then
		Data = ImportedStates();
		ImportedObjectDescription = Data.Title;
		Items.CheckForAddressClassifierUpdates.Enabled = Data.ImportedCount > 0;
		Items.ClearAddressClassifier.Enabled = Items.CheckForAddressClassifierUpdates.Enabled;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ImportAddressClassifier(Command)
	
	AddressClassifierClient.ImportAddressClassifier();
	
EndProcedure

&AtClient
Procedure ClearAddressClassifier(Command)
	
	AddressClassifierClient.ClearClassifier(ThisObject);
	
EndProcedure

&AtClient
Procedure CheckForAddressClassifierUpdates(Command)
	
	AddressClassifierClient.CheckAddressObjectUpdateRequired(ThisObject);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServerNoContext
Function ImportedStates()
	
	Result = New Structure("Title, ImportedCount",
		NStr("en = 'Address classifier not filled.'"), AddressClassifier.FilledAddressObjectCount());
	
	If Result.ImportedCount > 0 Then
		Result.Title = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'States imported: %1.'"), Result.ImportedCount);
			
	EndIf;
	
	Return Result;
EndFunction

#EndRegion
