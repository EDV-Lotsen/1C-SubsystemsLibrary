

&AtClient
Procedure Reply(Command)
	FormParameters = New Structure("IncomingEmail", Object.Ref);
	OpenForm("Catalog.OutgoingEmails.ObjectForm", FormParameters);
	Close();
EndProcedure


&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Not Parameters.Key.IsEmpty() Then
		Filter = New Structure("Email", Parameters.Key);
		WasRead = InformationRegisters.IncomingEmailsState.Get(Filter).Read;
		If Not WasRead Then
			RS = InformationRegisters.IncomingEmailsState.CreateRecordSet();
			RS.Filter.Email.Set(Parameters.Key);
			Write = RS.Add();
			Write.Email = Parameters.Key;
			Write.Read = True;
			RS.Write();
		EndIf;
		If Object.ContentKind = Enums.IncomingEmailContentType.Text Then
			Text = Object.Text;
			Items.Folder.CurrentPage = Items.TextGroup;
		Else
			HTML = Object.Text;
			Items.Folder.CurrentPage = Items.HTMLGroup;
		EndIf;
	EndIf;		
EndProcedure


&AtClient
Procedure OnOpen(Cancel)
	If Not WasRead Then
		NotifyChanged(Object.Ref);
		//Notify("RefreshIncomingEmailsList");
	EndIf;
EndProcedure

