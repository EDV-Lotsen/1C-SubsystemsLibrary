
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
  // Skipping the initialization to guarantee that the form will 
  // be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	MappingFieldList = Parameters.MappingFieldList;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	UpdateCommentLabelText();
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure MappingFieldListOnChange(Item)
	
	UpdateCommentLabelText();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ExecuteMapping(Command)
	
	NotifyChoice(MappingFieldList.Copy());
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	NotifyChoice(Undefined);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure UpdateCommentLabelText()
	
	MarkedListItemArray = CommonUseClientServer.GetMarkedListItemArray(MappingFieldList);
	
	If MarkedListItemArray.Count() = 0 Then
		
		CommentLabel = NStr("en = 'Mapping will be performed by UUIDs only.'");
		
	Else
		
		CommentLabel = NStr("en = 'Mapping will be performed by UUIDs and selected fields.'");
		
	EndIf;
	
EndProcedure

#EndRegion
