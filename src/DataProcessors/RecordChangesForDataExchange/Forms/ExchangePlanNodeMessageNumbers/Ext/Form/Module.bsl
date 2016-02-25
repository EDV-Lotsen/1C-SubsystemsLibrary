
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	VerifyAccessRights("Administration", Metadata);
 
	// Skipping the initialization to guarantee that the form will be
	// received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	ExchangeNodeRef = Parameters.ExchangeNodeRef;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	ReadMessageNumbers();
	Title = ExchangeNodeRef;
EndProcedure

#EndRegion

#Region FormCommandHandlers

// The procedure writes modified data and closes the form.
&AtClient
Procedure WriteNodeChanges(Command)
	WriteMessageNumbers();
	Notify("ExchangeNodeDataChange", ExchangeNodeRef, ThisObject);
	Close();
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Function ThisObject(CurrentObject = Undefined) 
	If CurrentObject = Undefined Then
		Return FormAttributeToValue("Object");
	EndIf;
	ValueToFormAttribute(CurrentObject, "Object");
	Return Undefined;
EndFunction

&AtServer
Procedure ReadMessageNumbers()
	Data = ThisObject().GetExchangeNodeParameters(ExchangeNodeRef, "SentNo, ReceivedNo, DataVersion");
	If Data = Undefined Then
		SentNo      = Undefined;
		ReceivedNo  = Undefined;
		DataVersion = Undefined;
	Else
		SentNo      = Data.SentNo;
		ReceivedNo  = Data.ReceivedNo;
		DataVersion = Data.DataVersion;
	EndIf;
EndProcedure	

&AtServer
Procedure WriteMessageNumbers()
	Data = New Structure("SentNo, ReceivedNo", SentNo, ReceivedNo);
	ThisObject().SetExchangeNodeParameters(ExchangeNodeRef, Data);
EndProcedure

#EndRegion
