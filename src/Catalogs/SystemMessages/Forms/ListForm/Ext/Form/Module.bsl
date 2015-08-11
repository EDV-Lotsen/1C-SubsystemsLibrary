////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GroupVariant = "ByRecipient";
	
	//SetListGrouping();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure GroupVariantOnChange(Item)
	
	SetListGrouping();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure SendAndReceiveMessages(Command)
	
	MessageExchangeClient.SendAndReceiveMessages();
	
	Items.List.Refresh();
	
EndProcedure

&AtClient
Procedure Setup(Command)
	
	OpenForm("CommonForm.MessageExchangeSetup",, ThisForm);
	
EndProcedure

&AtClient
Procedure Delete(Command)
	
	If Items.List.CurrentData <> Undefined Then
		
		If Items.List.CurrentData.Property("RowGroup")
			And TypeOf(Items.List.CurrentData.RowGroup) = Type("DynamicalListGroupRow") Then
			
			ShowMessageBox(, NStr("en = 'A list group row cannot be deleted.'"));
			
		Else
			
			If Items.List.SelectedRows.Count() > 1 Then
				
				QuestionString = NStr("en = 'Do you want to delete selected messages?'");
				
			Else
				
				QuestionString = NStr("en = 'Do you want to delete the message [Message]?'");
				QuestionString = StrReplace(QuestionString, "[Message]", Items.List.CurrentData.Description);
				
			EndIf;
			
			Response = DoQueryBox(QuestionString, QuestionDialogMode.YesNo,, DialogReturnCode.Yes);
			
			If Response = DialogReturnCode.Yes Then
				
				DeleteMessageDirectly(Items.List.SelectedRows);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Procedure SetListGrouping()
	
	If GroupVariant = "WithoutGrouping" Then
		
		List.Group.Items[0].Use = False;
		List.Group.Items[1].Use = False;
		
		Items.Sender.Visible = True;
		Items.Recipient.Visible = True;
		
	Else
		
		Use = (GroupVariant = "ByRecipient");
		
		List.Group.Items[0].Use = Use;
		List.Group.Items[1].Use = Not Use;
		
		Items.Sender.Visible = Use;
		Items.Recipient.Visible = Not Use;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure DeleteMessageDirectly(Val Messages)
	
	For Each Message In Messages Do
		
		MessageObject = Message.GetObject();
		
		If MessageObject <> Undefined Then
			
			MessageObject.Lock();
			
			If ValueIsFilled(MessageObject.Sender)
				And MessageObject.Sender <> MessageExchangeInternal.ThisNode() Then
				
				MessageObject.DataExchange.Recipients.Add(MessageObject.Sender);
				MessageObject.DataExchange.Recipients.AutoFill = False;
				
			EndIf;
			
			// Existence of catalog references should not interfere with catalog item deletion.
			MessageObject.DataExchange.Load = True; 
			MessageObject.Delete();
			
		EndIf;
		
	EndDo;
	
	Items.List.Refresh();
	
EndProcedure







