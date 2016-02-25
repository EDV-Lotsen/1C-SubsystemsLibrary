&AtServer
Function PrintForm(CommandParameter)
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.ShowGrid = False;
	SpreadsheetDocument.Protection = False;
	SpreadsheetDocument.ReadOnly = False;
	SpreadsheetDocument.ShowHeaders = False;
	
	Generated = False;
	
	For Each Ref In CommandParameter Do
		Document = Ref.GetObject();
		If Not Document.Posted Then
			Message = New UserMessage();
			Message.Text = "Document not Posted: " + String(Document);
			Message.DataKey = Ref;
			Message.Message();
			Continue;
		EndIf;	
		Document.PrintForm(SpreadsheetDocument);
		Generated = True;
	EndDo;	
	
	If Generated Then
		Return SpreadsheetDocument;
	Else 	
		Return Undefined;
	EndIf;	
	
EndFunction

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	SpreadsheetDocument = PrintForm(CommandParameter);
	
	If SpreadsheetDocument <> Undefined Then
		SpreadsheetDocument.Show();
	EndIf;	
	
EndProcedure
