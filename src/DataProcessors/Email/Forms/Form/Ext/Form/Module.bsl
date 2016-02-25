&AtServerNoContext
Function GetLastIncomingEmail()


	Query = New Query;
	Query.Text = 
		"SELECT TOP 1
		|	IncomingEmails.Ref AS Ref
		|FROM
		|	Catalog.IncomingEmails AS IncomingEmails
		|		INNER JOIN (SELECT
		|			MAX(IncomingEmails.Date) AS Date
		|		FROM
		|			Catalog.IncomingEmails AS IncomingEmails) AS T
		|		ON IncomingEmails.Date = T.Date
		|
		|ORDER BY
		|	Ref";

	Result = Query.Execute();
	SelectionDetailRecords = Result.Select();
	If Not SelectionDetailRecords.Next() Then
		Return Catalogs.IncomingEmails.EmptyRef();
	EndIf;
	Return SelectionDetailRecords.Ref;
EndFunction

&AtServer
Function GetEmails(Count)
	//Profile = EmailOperations.GetProfile();
	//If  Profile.SMTPServerAddress = "" Then
	//	Return False;
	//EndIf;

	//Count = EmailOperations.GetNewEmails(
	//    Profile, UseIMAP, IMAPMailbox);
	//If Count <> 0 Then
	//	Items.IncomingList.CurrentRow = GetLastIncomingEmail();
	//EndIf;
	Return True;
EndFunction	

&AtClient
Procedure GetEmailsCommand(Command)
	Count = 0;
	If Not GetEmails(Count) Then
		Buttons = New ValueList;
		Buttons.Add(1, "Email setup");
		Buttons.Add(2, "Close");
		
		Notification = New NotifyDescription("GetMessagesCommandCompletion", ThisObject);

		ShowQueryBox(Notification, "Email settings are not specified!", Buttons,, 1);

		Return;
	EndIf;
	ShowUserNotification("Messages loaded: " + Count);
EndProcedure

&AtClient

Procedure GetMessagesCommandCompletion(Result,  Parameters)  Export
	If  Result =  1 Then
		OpenForm("CommonForm.EmailOptions");
	EndIf;
EndProcedure

&AtClient
Procedure NewEmailCommand(Command)
	FormParameters = New Structure();
	OpenForm("Catalog.OutgoingEmails.ObjectForm", FormParameters, ThisObject);
EndProcedure

&AtClient

Procedure NewEmailByTemplateCommand(Command)
	FormParameters =  New  Structure("ByTemplate", True);
	OpenForm("Catalog.OutgoingEmails.ObjectForm", FormParameters,  ThisObject);
EndProcedure


&AtClient
Procedure ReplyCommand(Command)
	If Items.PagesGroup.CurrentPage = Items.IncomingGroup Then
		Email = Items.IncomingList.CurrentRow;
	Else
		Email = Items.OutgoingList.CurrentRow;
	EndIf;
	FormParameters = New Structure("IncomingEmail", Email);
	OpenForm("Catalog.OutgoingEmails.ObjectForm",FormParameters, ThisObject);
EndProcedure


&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "RefreshIncomingEmailsList" Then
		Items.IncomingList.Refresh();
	EndIf;
EndProcedure

&AtServerNoContext
Function GetMailboxes()
	//Return EmailOperations.GetIMAPMailboxes();
EndFunction

&AtServer
Procedure LoadMailboxesInChoiceList(ComboBox)
	ComboBox.ChoiceList.Clear();
	Mailboxes = GetMailboxes();
	For Each Mailbox In Mailboxes Do
		ComboBox.ChoiceList.Add(Mailbox);
	EndDo;
EndProcedure

&AtServer
Procedure CreateMailbox(Mailbox)
	//EmailOperations.CreateIMAPMailbox(Mailbox);
	//LoadMailboxesInChoiceList(Items.IMAPMailbox);
EndProcedure

&AtClient
Procedure CommandCreateIMAPMailbox(Command)
	Notification = New  NotifyDescription("CreateIMAPMailboxCommandCompletion", ThisObject);
	ShowInputString(Notification, "<New name>", "Type the mailbox name")
EndProcedure

&AtClient
Procedure  CreateIMAPMailboxCommandCompletion(Mailbox, Parameters) Export
	If Not Mailbox  = Undefined Then
	 CreateMailbox(Mailbox);
	 IMAPMailbox = Mailbox;
	 FilterEmailsLists();		
	EndIf;
EndProcedure
&AtServer
Procedure FillSettings()
	//Profile = EmailOperations.GetProfile("", UseIMAP);
	Items.IMAPMailbox.Enabled = UseIMAP;
	Items.CommandCreateIMAPMailbox.Enabled = UseIMAP;
	FilterEmailsLists();
EndProcedure

&AtServer
Procedure SetFilterByMailbox(List)
	DeleteFilterByMailbox(List);
	FilterItem = List.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue    = New DataCompositionField("Mailbox");
	FilterItem.ComparisonType     = DataCompositionComparisonType.Equal;
	FilterItem.Use    = True;
	FilterItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	If UseIMAP Then
		If IMAPMailbox = "" Then
			IMAPMailbox = "INBOX";
		EndIf;		
		FilterItem.RightValue   = "IMAP/" + IMAPMailbox;
	Else
		FilterItem.RightValue   = "POP3";
	EndIf;
EndProcedure

&AtServer
Procedure DeleteFilterByMailbox(List)
	FilterItems = List.Filter.Items;
	CompositionField = New DataCompositionField("Mailbox");
	For Each FilterItem In FilterItems Do
		If FilterItem.LeftValue = CompositionField Then
			FilterItems.Delete(FilterItem);
		EndIf;
	EndDo;
EndProcedure


&AtServer
Procedure FilterEmailsLists()
    SetFilterByMailbox(IncomingList);
EndProcedure

&AtServer

Procedure  OnCreateAtServer(Cancel, StandardProcessing)
	FillSettings();
	LoadMailboxesInChoiceList(Items.IMAPMailbox);
EndProcedure

&AtClient
Procedure EmailSetupCommand(Command)
	Notification = New  NotifyDescription(
		"EmailSetupCommandCompletion", ThisObject);
	OpenForm("CommonForm.EmailOptions",,,,,,  Notification);
EndProcedure

&AtClient
Procedure EmailSetupCommandCompletion(Result, Parameters) Export
	FillSettings();
EndProcedure

&AtClient
Procedure IMAPMailboxOnChange(Element)
	FilterEmailsLists();
EndProcedure


