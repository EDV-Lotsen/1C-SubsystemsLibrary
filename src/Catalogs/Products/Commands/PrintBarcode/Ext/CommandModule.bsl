&AtServer
Function PrintForm(CommandParameter)
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.ShowGrid = False;
	SpreadsheetDocument.ShowHeaders = False;
	
	Generated = False;
	
	For Each Ref In CommandParameter Do
		Object = Ref.GetObject();
		If Object.IsFolder Or IsBlankString(Object.Barcode) Then 
			Message = New UserMessage();
			Message.Text = NStr("en = 'The barcode is not specified for '") + String(Object);
			Message.Field = "Barcode";
			Message.SetData(Object);
			Message.Message();
			Continue;
		EndIf;	
		Object.BarcodePrintForm(SpreadsheetDocument);
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
