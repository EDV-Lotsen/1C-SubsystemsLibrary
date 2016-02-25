////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	TicketID = Undefined;
	If Parameters.Property("TicketID") Then 
		TicketID = Parameters.TicketID;
	EndIf;
	
	If Parameters.Property("Description") Then 
		Title = Parameters.Description;
	EndIf;
	
	CurrentPageNumber = 1;
	
	UpdateFormContent();
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS


////////////////////////////////////////////////////////////////////////////////
// InteractionTable EVENT HANDLERS

&AtClient
Procedure InteractionTableOnActivateRow(Item)
	
	RefreshContentRepresentation(Item.CurrentData.ID);
	
EndProcedure

&AtClient
Procedure SaveFile(Command)
	
	Structure = GetFileStorageAddress(Items.InteractionTableAttachments.CurrentData.ID);
	If Structure.Address <> Undefined Then 
		GetFile(Structure.Address, Structure.Name, True);
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure Previous(Command)
	
	UpdateFormContent(-1);
	
EndProcedure

&AtClient
Procedure Next(Command)
	
	UpdateFormContent(-1);
	
EndProcedure

&AtClient
Procedure Refresh(Command)
	
	UpdateFormContent();
	
EndProcedure

&AtClient
Procedure AddNewMessage(Command)
	
	MessageParameters = GenerateMessageParameters();
	InformationCenterClient.OpenFormForSendingMessageToSupport(MessageParameters);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Procedure UpdateFormContent(PageOffset = 0)
	
	CurrentPageNumber = CurrentPageNumber + PageOffset;
	
	If TicketID = Undefined Then 
		RaiseTicketRepresentationServiceException();
	EndIf;
	
	Result = GetUserTicketMessageListAndCount();
	If Result = Undefined Then 
		RaiseTicketRepresentationServiceException();
	EndIf;
	
	DisplayHeaderItems(Result);
	
	OutputMessageList(Result);
	
EndProcedure

&AtServer
Procedure RaiseTicketRepresentationServiceException()
	
	If TicketID = Undefined Then 
		Raise NStr("en = 'The support ticket service is temporarily unavailable.
								|Please try again later'");
	EndIf;
	
EndProcedure

&AtServer
Function GetUserTicketMessageListAndCount()
	
	Try
		Proxy = InformationCenterServer.GetInformationCenterProxy_1_0_1_2();
		Return Proxy.GetMessagesSupportService(TicketID, CurrentPageNumber);
	Except
		EventName = InformationCenterServer.GetEventNameForEventLog();
		WriteLogEvent(EventName, EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Return Undefined;
	EndTry;
	
EndFunction

&AtServer
Function GetFileStorageAddress(FileID)
	
	Try
		Proxy     = InformationCenterServer.GetInformationCenterProxy_1_0_1_2();
		Structure = Proxy.GetAttachmaent(FileID);
		Address   = PutToTempStorage(Structure.binData);
		Return New Structure("Address, Name", Address, Structure.name)
	Except
		EventName = InformationCenterServer.GetEventNameForEventLog();
		WriteLogEvent(EventName, EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Return Undefined;
	EndTry;
	
EndFunction

&AtServer
Procedure DisplayHeaderItems(Result)
	
	MessageCount       = Result.count;
	MessageOnPageCount = Result.countOnPage;
	
	If MessageCount = 0 Then 
		Return;
	EndIf;
	
	Range = GetRange(MessageOnPageCount, MessageCount);
	Items.Range.Title = GetRangePattern(Range);
	
	DisplayCommandEnableStates(MessageOnPageCount, MessageCount);
	
EndProcedure

&AtServer
Function GetRange(MessageOnPageCount, MessageCount)
	
	Beginning   = (CurrentPageNumber - 1) * MessageOnPageCount + 1;
	End         = CurrentPageNumber * MessageOnPageCount;
	End         = ?(End > MessageCount, MessageCount, End);
	
	Return New Structure("Beginning, End", Beginning, End);
	
EndFunction

&AtServer
Function GetRangePattern(Range)

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
Procedure OutputMessageList(Result)
	
	If Result.messageList.Count() = 0 Then 
		Return;
	EndIf;
	
	InteractionList.Clear();
	
	For Iteration = 0 to Result.messageList.Count() - 1 Do
		
		Message = Result.messageList.Get(Iteration);
		
		Item = InteractionList.Add();
		
		Item.MessageText        = Message.text;
		Item.MessageTypePicture = ?(Message.ingoing, PictureLib.IncomingMessage, PictureLib.OutgoingMessage);
		Item.MessageDate        = Message.date;
		Item.HTMLText           = Message.textHTML;
		Item.ID                 = Message.ID;
		Item.HTMLAttachments.Add(GetPictureFileStructure(Message.filesHTML));
		FillAttachmentList(Item, Message.attachments);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure FillAttachmentList(TableRow, Attachments)
	
	For Each Attachment In Attachments Do 
		NewItem = TableRow.Attachments.Add();
		NewItem.Name = Attachment.name;
		NewItem.ID   = Attachment.id;
	EndDo;
	
EndProcedure

&AtServer
Function GetPictureFileStructure(Files)
	
	Structure = New Structure;
	
	For Each FileStructure In Files Do
		Structure.Insert(FileStructure.name, New Picture(FileStructure.binData));
	EndDo;
	
	Return Structure;
	
EndFunction

&AtServer
Procedure RefreshContentRepresentation(ID)
	
	Filter = New Structure("ID", ID);
	RowArray = InteractionList.FindRows(Filter);
	If RowArray.Count() = 0 Then 
		Return;
	EndIf;
	
	TableRow = RowArray.Get(0);
	
	CurrentMessageContent.SetHTML(TableRow.HTMLText, TableRow.HTMLAttachments.Get(0).Value);
	
	Items.InteractionTableAttachments.Visibility = ?(TableRow.Attachments.Count() = 0, False, True);
	
EndProcedure

&AtServer
Function GenerateMessageParameters()
	
	SetPrivilegedMode(True);
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("TicketID", TicketID);
	
	MessageParameters = New Structure;
	MessageParameters.Insert("From",   InformationCenterServer.GetUserEmailAddress());
	MessageParameters.Insert("Attachments", InformationCenterServer.GenerateXMLWithTechParameters(AdditionalParameters));
	MessageParameters.Insert("ShowTopic", False);
	
	Return MessageParameters;
	
EndFunction



























