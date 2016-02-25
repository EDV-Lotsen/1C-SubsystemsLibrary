////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Parameters.Property("Login") Then 
		Login = Parameters.Login;
	EndIf;
	
	If Parameters.Property("SuggestionID") Then 
		SuggestionID = Parameters.SuggestionID;
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS


////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure Send(Command)
	
	If IsBlankString(Comment) Then 
		ShowMessageBox(,NStr("en = 'Comment must be filled'"));
		Return;
	EndIf;
	
	
	Result = AddComment();
	If Result Then
		ShowUserNotification(NStr("en = 'Comment added.'"));
	Else	
		ShowMessageBox(New NotifyDescription("SendCompletion", ThisForm), NStr("en = 'Comment has not been added. Try again later.'"));
	EndIf;
	
EndProcedure

Procedure SendCompletion(AdditionalParameters) Export
	
	Close();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Function AddComment()
	
	InformationCenterProxy = InformationCenterServer.GetInformationCenterProxy_1_0_1_2();
	WebServiceXDTOFactory       = InformationCenterProxy.XDTOFactory;
	CommentDetails         = CastToXDTOUserCommentObject(WebServiceXDTOFactory);
	
	Return InformationCenterProxy.AddCommentSuggestion(CommentDetails);
	
EndFunction

&AtServer
Function CastToXDTOUserCommentObject(WebServiceXDTOFactory)
	
	CommentType      = WebServiceXDTOFactory.Type("http://www.1c.ru/SaaS/1.0/XMLSchema/ManageInfoCenter_1_0_1_2", "CommentListElement");
	CommentDetails = WebServiceXDTOFactory.Create(CommentType);
	
	CommentDetails.Text           = Comment;
	CommentDetails.Date           = CurrentDate(); // SL design decision
	CommentDetails.Author         = Login;
	CommentDetails.RefSuggestion  = SuggestionID;
	CommentDetails.Vote           = 0;
	
	Return CommentDetails;
	
EndFunction















