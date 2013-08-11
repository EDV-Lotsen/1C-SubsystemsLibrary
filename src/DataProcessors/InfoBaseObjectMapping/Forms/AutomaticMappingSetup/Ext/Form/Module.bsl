////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	MappingFieldList = Parameters.MappingFieldList;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	UpdateCommentLabelText();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure MappingFieldListOnChange(Item)
	
	UpdateCommentLabelText();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure ExecuteMapping(Command)
	
	ThisForm.Close(MappingFieldList.Copy());
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	ThisForm.Close(Undefined);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtClient
Procedure UpdateCommentLabelText()
	
	MarkedListItemArray = CommonUseClientServer.GetMarkedListItemArray(MappingFieldList);
	
	If MarkedListItemArray.Count() = 0 Then
		
		CommentLabel = NStr("en = 'Mapping will be performed by UUIDs only.'");
		
	Else
		
		CommentLabel = NStr("en = 'Mapping will be performed by UUIDs and selected fields.'");
		
	EndIf;
	
EndProcedure







