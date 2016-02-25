////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Getting the current user login (for SaaS mode)
	SetPrivilegedMode(True);
	Login = String(Users.CurrentUser().ServiceUserID);
	SetPrivilegedMode(False);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS


////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure Send(Command)
	
	If IsBlankString(Content.GetText()) Then 
		ShowMessageBox(,NStr("en = 'Suggestion must be filled'"));
		Return;
	EndIf;
	
	SendingResult = SendSuggestion();
	If Not SendingResult Then 
		ShowMessageBox(,NStr("en = 'Your suggestion cannot be sent.
		|Try again later.'"));
		Return;
	Else
		ShowMessageBox(New NotifyDescription("SendCompletion", ThisForm), NStr("en = 'Your suggestion will be considered. Thank you for helping us make our service better.'"));
	EndIf;
	
	
	
EndProcedure


Procedure SendCompletion(AdditionalParameters) Export
	
	Close();
	
EndProcedure
////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Function SendSuggestion()
	
	Try
		Proxy = InformationCenterServer.GetInformationCenterProxy_1_0_1_2();
		UserMessage = CastToUserMessageXDTOObject(Proxy.XDTOFactory);
		Return Proxy.AddUserMessage(UserMessage);
	Except
		EventName = InformationCenterServer.GetEventNameForEventLog();
		WriteLogEvent(EventName, EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Return False;
	EndTry;
	
EndFunction

&AtServer
Function CastToUserMessageXDTOObject(WebServiceXDTOFactory)
	
	MessageType = WebServiceXDTOFactory.Type("http://www.1c.ru/SaaS/1.0/XMLSchema/ManageInfoCenter_1_0_1_2", "UserMessage");
	MessageDetails = WebServiceXDTOFactory.Create(MessageType);
	
	MessageDetails.Content  = GetUserMessageContent(WebServiceXDTOFactory);
	MessageDetails.Date     = CurrentDate(); // SL project decision 
	MessageDetails.Author   = Login;
	SetPrivilegedMode(True);
	MessageDetails.DataArea = CTLAndSLIntegration.SessionSeparatorValue();
	SetPrivilegedMode(False);
	
	Return MessageDetails;
	
EndFunction

&AtServer
Function GetUserMessageContent(WebServiceXDTOFactory)
	
	ContentType    = WebServiceXDTOFactory.Type("http://www.1c.ru/SaaS/1.0/XMLSchema/ManageInfoCenter_1_0_1_2", "HTMLContent");
	ContentDetails = WebServiceXDTOFactory.Create(ContentType);
	
	AttachmentList = Undefined;
	HTMLText       = Undefined;
	Content.GetHTML(HTMLText, AttachmentList);
	
	ContentDetails.Files    = CastUserMessageContentFileList(AttachmentList, WebServiceXDTOFactory);
	ContentDetails.TextHTML = HTMLText;
	
	Return ContentDetails;
	
EndFunction

&AtServer
Function CastUserMessageContentFileList(AttachmentList, WebServiceXDTOFactory)
	
	PictureListType     = WebServiceXDTOFactory.Type("http://www.1c.ru/SaaS/1.0/XMLSchema/ManageInfoCenter_1_0_1_2", "FileList");
	PictureStructureType = WebServiceXDTOFactory.Type("http://www.1c.ru/SaaS/1.0/XMLSchema/ManageInfoCenter_1_0_1_2", "FileListElement");
	
	PictureList = WebServiceXDTOFactory.Create(PictureListType);
	
	If AttachmentList.IndexOf() = 0 Then 
		Return PictureList;
	EndIf;
	
	For Each Attachment In AttachmentList Do
		
		PictureStructure = WebServiceXDTOFactory.Create(PictureStructureType);
		PictureStructure.FullName = Attachment.Reference;
		PictureStructure.BinData  = Attachment.Value.GetBinaryData();
		
		PictureList.Files.Append(PictureStructure);
		
	EndDo;
	
	Return PictureList;
	
EndFunction
