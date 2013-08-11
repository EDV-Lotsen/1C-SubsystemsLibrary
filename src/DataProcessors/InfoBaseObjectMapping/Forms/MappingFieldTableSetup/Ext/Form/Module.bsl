////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	FieldList = Parameters.FieldList;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure Apply(Command)
	
	Cancel = False;
	
	MarkedListItemArray = CommonUseClientServer.GetMarkedListItemArray(FieldList);
	
	If MarkedListItemArray.Count() = 0 Then
		
		NString = NStr("en = 'Select one or more fields.'");
		
		CommonUseClientServer.MessageToUser(NString,,"FieldList",, Cancel);
		
	ElsIf MarkedListItemArray.Count() > MaxCustomFieldCount() Then
		
		// The value must not exceed the specified number 
		MessageString = NStr("en = 'Reduce the number of fields (you can select no more than [NumberOfFields] fields).'");
		MessageString = StrReplace(MessageString, "[NumberOfFields]", String(MaxCustomFieldCount()));
		CommonUseClientServer.MessageToUser(MessageString,,"FieldList",, Cancel);
		
	EndIf;
	
	If Not Cancel Then
		
		ThisForm.Close(FieldList.Copy());
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	ThisForm.Close(Undefined);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtClient
Function MaxCustomFieldCount()
	
	Return DataExchangeClient.MaxObjectMappingFieldCount();
	
EndFunction
