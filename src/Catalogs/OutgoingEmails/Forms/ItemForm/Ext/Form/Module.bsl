&AtServerNoContext
Function GetContactByEmail(Email)
	Query = New Query;
	Query.Text = "SELECT Contact FROM Catalog.Counterparties WHERE Email = &Email";
	Query.Parameters.Insert("Email", TrimAll(Email));
	Selection = Query.Execute().Select();
	Contact = "";
	If Selection.Next() Then
		Contact = Selection.Contact;
	EndIf;
	Return Contact;
EndFunction

&AtServerNoContext
Function GetContactByRecipient(Recipient)
	Query = New Query;
	Query.Text = "SELECT Contact FROM Catalog.Counterparties WHERE Ref = &Recipient";
	Query.Parameters.Insert("Recipient", Recipient);
	Selection = Query.Execute().Select();
	Contact = "";
	If Selection.Next() Then
		Contact = Selection.Contact;
	EndIf;
	Return Contact;
EndFunction

&AtServerNoContext
Procedure AddRecipients(Recipient, Recipients)	
	Query = New Query;
	Query.Text = "SELECT Email FROM Catalog.Counterparties WHERE Ref " ;
	If TypeOf(Recipients) = Type("Array") Then
		Query.Text = Query.Text + "IN (&Recipients)";
	Else
		Query.Text = Query.Text + "= &Recipients";
	EndIf;
	Query.Parameters.Insert("Recipients", Recipients);
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If Recipient <> "" Then
			Recipient = Recipient + "; ";
		EndIf;
		Recipient = Recipient + Selection.Email;
	EndDo;
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Key.IsEmpty() Then
		Title = "New outgoing message";
		Object.Date = CurrentDate();
		IncomingEmail = Parameters.IncomingEmail;
		ByTemplate =  Parameters.Property("ByTemplate");
		If ByTemplate = True Then
			Items.FillByTemplate.Visible = True;

			//EmailOperations.FillEmailMessageByTemplate(Object, Content);
		ElsIf Not IncomingEmail.IsEmpty() Then
			//EmailOperations.FillReplyToEmail(IncomingEmail, Object, Content);
		EndIf;
		Recipients = Parameters.Recipients;
		If Recipients <> Undefined Then
			Query = New Query;
			Query.Text = "SELECT
			               |	Counterparties.Email
			               |FROM
			               |	Catalog.Counterparties AS Counterparties
			               |WHERE
			               |	Counterparties.Ref IN (&Recipients)
			               |	AND Counterparties.Email <> """"";
			Query.SetParameter("Recipients", Recipients);			   
			Recipient = "";
			Selection = Query.Execute().Select();
			While Selection.Next() Do
				If Recipient <> "" Then
					Recipient = Recipient + "; ";
				EndIf;
				Recipient = Recipient + Selection.Email;
			EndDo;
			Object.Recipient = Recipient;
		EndIf;
	EndIf;
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	Content = CurrentObject.Content.Get();
	Title = CurrentObject.Description + " (Outgoing Email)";
	//If  EmailOperations.EmailSent(CurrentObject.Ref) Then
	//	Title = Title + " - Sent";
	//EndIf;
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	CurrentObject.Content = New ValueStorage(Content, New Deflation());
	CurrentObject.Text = Content.GetText();
EndProcedure

&AtServer
Function SendEmail(Error)
	If Not Write() Then
		Error = "WriteError";
		Return False;
	EndIf;
	//If Not EmailOperations.SendEmail(Object.Ref) Then
	//	Error = "SendError";
	//	Return False;
	//EndIf;
	Title = Title + " - Sent";
	Return True;
EndFunction

&AtClient
Function SendEmailClient()
	Error = "";
	If Not SendEmail(Error) Then
		If Error = "SendError" Then
			Buttons = New ValueList;
			Buttons.Add(1, "Setup email");
			Buttons.Add(2, "Close");
			
			Notification  = New  NotifyDescription(
				"SendEmailMessageClientQueryCompletion",  ThisObject);
			ShowQueryBox(Notification, "Email settings are not specified.", Buttons,, 1);
		EndIf;
		Return False;
	EndIf;
	
	Url = GetURL(Object.Ref);
	ShowUserNotification("Message sent", Url, Object.Description);
	NotifyChanged(Object.Ref);
	Return True;
EndFunction

&AtClient

Procedure SendEmailMessageClientQueryCompletion(Result, Parameters)  Export
	If  Result =  1 Then
		OpenForm("CommonForm.EmailOptions");
	EndIf;
EndProcedure

&AtClient
Procedure Send(Command)
	SendEmailClient();
EndProcedure

&AtClient
Procedure SendAndClose(Command)
	If Not SendEmailClient() Then
		Return;
	EndIf;
	Close();
EndProcedure

&AtClient
Procedure InsertLineAtCurrentPosition(Field, Document, String)
	Var Beginning, End;
	Field.GetTextSelectionBounds(Beginning, End);
	Position = Document.GetBookmarkPosition(Beginning);
	Document.Delete(Beginning, End);
	Beginning = Document.GetPositionBookmark(Position);
	Document.Insert(Beginning, String);
	Position = Position + StrLen(String);
	Bookmark = Document.GetPositionBookmark(Position);
	Field.SetTextSelectionBounds(Bookmark, Bookmark);
EndProcedure


&AtClient
Procedure InsertContact(Command)
	If Object.Counterparty.IsEmpty() Then
		Message("Select counterparty");
	Else
		Contact =  GetContactByRecipient(Object.Counterparty);
		InsertLineAtCurrentPosition(Items.Content, Content, Contact + " ");
	EndIf;
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	Title = CurrentObject.Description + " (Outgoing email)";
EndProcedure

 &AtClient

Procedure CounterpartyOnChange(Item)
	AddRecipients(Object.Recipient, Object.Counterparty);
EndProcedure

&AtClient
Procedure HighlightImportantText(Command)
	Var Start, End;
    AllImportant = True;
    Items.Content.GetTextSelectionBounds(Start, End);
    If Start = End Then
        Return;
    EndIf;
    
    TextItemSet =  New Array();
    For Each TextItem In  Content.GenerateItems(Start, End) Do
        If  Type(TextItem) = Type("FormattedDocumentText")  Then
             TextItemSet.Add(TextItem);    
        EndIf;    
    EndDo;
    
    For Each TextItem In  TextItemSet Do
        If  TextItem.Font.Bold  <> True And
             TextItem.TextColor <> New Color(255, 0, 0) Then
             AllImportant = False;
            Break;
        EndIf;
    EndDo;
    
    For Each TextItem In  TextItemSet Do
        TextItem.Font = New  Font(TextItem.Font, ,  , Not AllImportant);
        TextItem.TextColor = New Color(?(AllImportant, 0, 255), 0, 0);
    EndDo;
EndProcedure

&AtClient
Procedure FillByTemplate(Command)
	If Object.Counterparty.IsEmpty() Then
		Message("Select counterparty");
	Else
		FindAndReplace("[Counterparty]", Object.Counterparty);
		FindAndReplace("[Contact]", GetContactByRecipient(Object.Counterparty));
	EndIf;
	FindAndReplace("[EmailDate]", Object.Date);
EndProcedure

&AtClient
Procedure FindAndReplace(StringForSearch, StringForReplacement)
	Var InsertedText,  AppearanceFont, AppearanceTextColor, AppearanceBackColor,  AppearanceURL;
	SearchResult = Content.FindText(StringForSearch);
	While ((SearchResult  <> Undefined) And (SearchResult.BeginBookmark <> Undefined) And (SearchResult.EndBookmark <> Undefined)) Do
		SearchLoopNextBeginPosition =  Content.GetBookmarkPosition(SearchResult.BeginBookmark) + StrLen(StringForReplacement);
		ItemWithAppearanceArray = Content.GetItems(SearchResult.BeginBookmark, SearchResult.EndBookmark);
		For Each  ItemWithAppearance In ItemWithAppearanceArray  Do
			If Type(ItemWithAppearance) = Type("FormattedDocumentText")  Then
				AppearanceFont = ItemWithAppearance.Font;
				AppearanceTextColor =  ItemWithAppearance.TextColor;
				AppearanceBackColor =  ItemWithAppearance.BackColor;
				AppearanceURL =  ItemWithAppearance.URL;
				Break;
			EndIf;
		EndDo;	
		Content.Delete(SearchResult.BeginBookmark, SearchResult.EndBookmark);
		InsertedText = Content.Insert(SearchResult.BeginBookmark, StringForReplacement);
		If InsertedText <> Undefined And AppearanceFont <> Undefined Then
			InsertedText.Font = AppearanceFont;
		EndIf;
		If InsertedText <> Undefined And AppearanceTextColor <>  Undefined Then
			InsertedText.TextColor = AppearanceTextColor;
		EndIf;
		If InsertedText <> Undefined And AppearanceBackColor <>  Undefined Then
			InsertedText.BackColor = AppearanceBackColor;
		EndIf;
		If InsertedText <> Undefined And AppearanceURL <> Undefined Then
			InsertedText.URL = AppearanceURL;
		EndIf;
		
		SearchResult = Content.FindText(StringForSearch, Content.GetPositionBookmark(SearchLoopNextBeginPosition));
	EndDo;
EndProcedure



