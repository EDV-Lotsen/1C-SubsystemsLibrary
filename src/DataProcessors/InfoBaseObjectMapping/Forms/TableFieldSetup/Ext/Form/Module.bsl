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
	
	MarkedListItemArray = CommonUseClientServer.GetMarkedListItemArray(FieldList);
	
	If MarkedListItemArray.Count() = 0 Then
		
		NString = NStr("en = 'Select one or more fields.'");
		
		CommonUseClientServer.MessageToUser(NString,,"FieldList");
		
		Return;
		
	EndIf;
	
	ThisForm.Close(FieldList.Copy());
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	ThisForm.Close(Undefined);
	
EndProcedure
