
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Parameters.Property("SelfTest") Then 
		Return;
	EndIf;
	
	// Initial group setup
	DataGroup = List.SettingsComposer.Settings.Structure.Add(Type("DataCompositionGroup"));
	DataGroup.UserSettingID = "MainGroup";
	DataGroup.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	GroupFields = DataGroup.GroupFields;
	
	DataGroupItem = GroupFields.Items.Add(Type("DataCompositionGroupField"));
	DataGroupItem.Field = New DataCompositionField("Recipient");
	DataGroupItem.Use = True;
	
	DataGroupItem = GroupFields.Items.Add(Type("DataCompositionGroupField"));
	DataGroupItem.Field = New DataCompositionField("From");
	DataGroupItem.Use = False;
	
	// Conditional group setup
	GroupVariant = "ByRecipient";
	SetListGrouping();
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure GroupVariantOnChange(Item)
	
	SetListGrouping();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SendAndReceiveMessages(Command)
	
	MessageExchangeClient.SendAndReceiveMessages();
	
	Items.List.Refresh();
	
EndProcedure

&AtClient
Procedure Settings(Command)
	
	OpenForm("CommonForm.MessageExchangeSetup",, ThisObject);
	
EndProcedure

&AtClient
Procedure Delete(Command)
	
	If Items.List.CurrentData <> Undefined Then
		
		If Items.List.CurrentData.Property("RowGroup")
			And TypeOf(Items.List.CurrentData.RowGroup) = Type("DynamicListGroupRow") Then
			
			ShowMessageBox(, NStr("en = 'The action cannot be performed on a list group row.'"));
			
		Else
			
			If Items.List.SelectedRows.Count() > 1 Then
				
				QuestionString = NStr("en = 'Do you want to delete the selected messages?'");
				
			Else
				
				QuestionString = NStr("en = 'Do you want to delete ""[Message]""?'");
				QuestionString = StrReplace(QuestionString, "[Message]", Items.List.CurrentData.Description);
				
			EndIf;
			
			NotifyDescription = New NotifyDescription("DeleteCompletion", ThisObject);
			ShowQueryBox(NotifyDescription, QuestionString, QuestionDialogMode.YesNo,, DialogReturnCode.Yes);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteCompletion(Answer, Parameters) Export
	
	If Answer = DialogReturnCode.Yes Then
		
		DeleteMessageDirectly(Items.List.SelectedRows);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetListGrouping()
	
	RecipientGroup  = List.SettingsComposer.Settings.Structure[0].GroupFields.Items[0];
	SenderGroup = List.SettingsComposer.Settings.Structure[0].GroupFields.Items[1];
	
	If GroupVariant = "WithoutGrouping" Then
		
		RecipientGroup.Use = False;
		SenderGroup.Use = False;
		
		Items.Sender.Visible = True;
		Items.Recipient.Visible = True;
		
	Else
		
		Use = (GroupVariant = "ByRecipient");
		
		RecipientGroup.Use = Use;
		SenderGroup.Use = Not Use;
		
		Items.Sender.Visible = Use;
		Items.Recipient.Visible = Not Use;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure DeleteMessageDirectly(Val Messages)
	
	For Each Message In Messages Do
		
		If TypeOf(Message) <> Type("CatalogRef.DataAreaMessages") Then
			Continue;
		EndIf;
		
		MessageObject = Message.GetObject();
		
		If MessageObject <> Undefined Then
			
			MessageObject.Lock();
			
			If ValueIsFilled(MessageObject.Sender)
				And MessageObject.Sender<> MessageExchangeInternal.ThisNode() Then
				
				MessageObject.DataExchange.Recipients.Add(MessageObject.Sender);
				MessageObject.DataExchange.Recipients.AutoFill = False;
				
			EndIf;
		
			// References to the catalog should not prevent or slow down deletion of catalog items
			MessageObject.DataExchange.Load = True; 
			MessageObject.Delete();
			
		EndIf;
		
	EndDo;
	
	Items.List.Refresh();
	
EndProcedure

#EndRegion
