////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	UserID = Users.CurrentUser().ServiceUserID;
	SetPrivilegedMode(False);
	
	CurrentPageNumber = 1;
	
	DefaultFilterValue = Items.TicketFilter.ChoiceList.Get(0).Value;
	TicketFilter       = DefaultFilterValue;
	
	UpdateFormContent();
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure TicketFilterOnChange(Item)
	
	UpdateFormContent();
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// Ticket list TABLE EVENT HANDLERS

&AtClient
Procedure TicketListChoice(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	FormParameters = New Structure();
	FormParameters.Insert("TicketID", Item.CurrentData.ID);
	FormParameters.Insert("Description",    Item.CurrentData.Description);
	
	OpenForm("DataProcessor.InformationCenter.Form.TicketHistory", FormParameters);
	
	SetReviewedFlag(Item.CurrentData.ID);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure Next(Command)
	
	UpdateFormContent(+1);
	
EndProcedure

&AtClient
Procedure Previous(Command)
	
	UpdateFormContent(-1);
	
EndProcedure

&AtClient
Procedure ContactSupport(Command)
	
	MessageParameters = GenerateMessageParameters();
	InformationCenterClient.OpenFormForSendingMessageToSupport(MessageParameters);
	
EndProcedure

&AtClient
Procedure Refresh(Command)
	
	UpdateFormContent();
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Procedure UpdateFormContent(PageOffset = 0)
	
	CurrentPageNumber = CurrentPageNumber + PageOffset;
	
	Result = GetUserTicketListAndCount();
	If Result = Undefined Then 
		Raise NStr("en = 'The support ticket service is temporarily unavailable.
								|Please try again later'");
	EndIf;
	
	DisplayHeaderItems(Result);
	
	OutputTicketList(Result);
	
EndProcedure

&AtServer
Function GetUserTicketListAndCount()
	
	ShowAllTickets = ?(TicketFilter = Items.TicketFilter.ChoiceList.Get(0).Value, True, False);
	
	Try
		Proxy = InformationCenterServer.GetInformationCenterProxy_1_0_1_2();
		Return Proxy.GetTicketsSupportService(UserID, CurrentPageNumber, ShowAllTickets);
	Except
		EventName = InformationCenterServer.GetEventNameForEventLog();
		WriteLogEvent(EventName, EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Return Undefined;
	EndTry;
	
EndFunction

&AtServer
Procedure DisplayHeaderItems(Result)
	
	TicketCount       = Result.count;
	TicketOnPageCount = Result.countOnPage;
	
	If TicketCount = 0 Then 
		Return;
	EndIf;
	
	Range = GetTicketRange(TicketOnPageCount, TicketCount);
	Items.Range.Title = GetTicketRangePattern(Range);
	
	DisplayCommandEnableStates(TicketOnPageCount, TicketCount);
	
EndProcedure

&AtServer
Function GetTicketRange(TicketOnPageCount, TicketCount)
	
	Beginning = (CurrentPageNumber - 1) * TicketOnPageCount + 1;
	End  = CurrentPageNumber * TicketOnPageCount;
	End  = ?(End > TicketCount, TicketCount, End);
	
	Return New Structure("Beginning, End", Beginning, End);
	
EndFunction

&AtServer
Function GetTicketRangePattern(Range)

	Template = "%1 - %2";
	Template = StringFunctionsClientServer.SubstituteParametersInString(Template, Range.Beginning, Range.End);
	
	Return Template;
	
EndFunction

&AtServer
Procedure DisplayCommandEnableStates(TicketOnPageCount, TicketCount)
	
	Items.Next.Accessibility  = ?(CurrentPageNumber * TicketOnPageCount < TicketCount, True, False);
	Items.Previous.Accessibility = ?(CurrentPageNumber > 1, True, False);
	
EndProcedure

&AtServer
Procedure OutputTicketList(Result)
	
	If Result.ticketList.Count() = 0 Then 
		Return;
	EndIf;
	
	TicketList.Clear();
	
	For Iteration = 0 to Result.ticketList.Count() - 1 Do
		
		Ticket = Result.ticketList.Get(Iteration);
		
		Item = TicketList.Add();
		
		Item.Status         = Ticket.stage;
		Item.Date           = Ticket.date;
		Item.Description    = Ticket.name;
		Item.Code           = Ticket.number;
		Item.ID             = Ticket.id;
		Item.HasNewMessages = Ticket.havingNewMessages;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure SetReviewedFlag(ID)
	
	Filter = New Structure("ID", ID);
	RowArray = TicketList.FindRows(Filter);
	If RowArray = 0 Then 
		Return;
	EndIf;
	
	RowArray.Get(0).HasNewMessages = False;
	
EndProcedure

&AtServer
Function GenerateMessageParameters()
	
	SetPrivilegedMode(True);
	
	MessageParameters = New Structure;
	MessageParameters.Insert("From",   InformationCenterServer.GetUserEmailAddress());
	MessageParameters.Insert("Text",    InformationCenterServer.GenerateTextToSupportPattern());
	MessageParameters.Insert("Attachments", InformationCenterServer.GenerateXMLWithTechParameters());
	
	Return MessageParameters;
	
EndFunction







