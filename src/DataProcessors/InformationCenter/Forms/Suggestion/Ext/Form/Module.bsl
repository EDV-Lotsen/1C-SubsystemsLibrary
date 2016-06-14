////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Getting the current user login (for SaaS mode)
	SetPrivilegedMode(True);
	Login = String(Users.CurrentUser().ServiceUserID);
	SetPrivilegedMode(False);
	
	// Determining the suggestion ID
	If Not Parameters.Property("SuggestionID") Then 
		Return;
	EndIf;
	SuggestionID = Parameters.SuggestionID;
	
	SuggestionStructure = GeneratePageItems(1);
	If Not SuggestionStructure Then 
		Raise NStr("en = 'The user suggestion service is temporarily unavailable.
			|Please try again later.'");
		Cancel = True;
		Return;
	EndIf;
	
	SetSuggestionReviewedFlag();
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure PageNumberClick(Item)
	
	LinkName  = Item.Name;
	
	If LinkName  = NStr("en = 'Next'") Then 
		PageNumber = CurrentPage + 1;
	ElsIf LinkName  = NStr("en = 'Previous'") Then 
		PageNumber = CurrentPage - 1;
	Else
		PageNumber = StrReplace(Item.Name, "p", "");
		Try
			PageNumber = Number(PageNumber);
		Except
			PageNumber = CurrentPage;
		EndTry;
	EndIf;
	
	// Creation items page
	Result = GeneratePageItems(PageNumber);
	If Not Result Then
		Raise NStr("en = 'The user suggestion service is temporarily unavailable.
			|Please try again later.'");
		Cancel = True;
		Return;
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure AddComment(Command)
	
	If IsBlankString(NewComment) Then 
		ShowMessageBox(,NStr("en = 'Type a comment.'"));
		Return;
	EndIf;
	
	Result = AddCommentServer();
	If Result Then
		NewComment = "";
		ShowUserNotification(NStr("en = 'Comment added.'"));
	Else
		ShowMessageBox(,NStr("en = 'Your comment cannot be added. Please try again later.'"));
		Return;
	EndIf;
	
	GeneratePageItems(CurrentPage);
	
	Notify("SuggestionChange");
	
EndProcedure

&AtClient
Procedure Vote(Command)
	
	
	VoteTaken = VoteForSuggestionServer(1, SuggestionID);
	If Not VoteTaken Then 
		// Deviation from the "Messages to user" standard 
		ShowMessageBox(,NStr("en = 'You vote cannot be taken.
								|Please try to vote later."));
		Return;
	EndIf;
	
	Items.Vote.Visible     = False;
	Items.WithYour.Visible = True;
	Items.Rating.Title        = Number(Items.Rating.Title) + 1;
	
	Notify("SuggestionChange");
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Procedure SetSuggestionReviewedFlag()
	
	SetPrivilegedMode(True);
	Query = New Query;
	Query.SetParameter("ID", New UUID(SuggestionID));
	Query.Text =
	"SELECT
	|	CommonInformationCenterData.Reference AS Ref
	|FROM
	|	Catalog.CommonInformationCenterData AS CommonInformationCenterData
	|WHERE
	|	CommonInformationCenterData.ID = &ID";
	Result = Query.Execute();
	
	If Result.IsEmpty() Then 
		Return;
	EndIf;
	
	Selection = Result.Select();
	
	While Selection.Next() Do
		Write = InformationRegisters.ViewedInformationCenterData.CreateRecordManager();
		Write.User = Users.CurrentUser();
		Write.InformationCenterData = Selection.Reference;
		Write.Reviewed = True;
		Write.Write();
	EndDo;
	
EndProcedure

&AtServer
Function VoteForSuggestionServer(Vote, ID)
	
	Try
		InformationCenterProxy = InformationCenterServer.GetInformationCenterProxy_1_0_1_2();
		Return InformationCenterProxy.AddVote(ID, Login, Vote);
	Except
		Return False
	EndTry;
	
EndFunction

&AtServer
Procedure GenerateFooter(CommentList)
	
	// Deleting obsolete pages and items
	DeleteFooterPages();
	
	// Defining the array of link names
	LinkNameArray = GetPageLinkNameArray(CommentList);
	
	// Creating footer items
	CreateFooterItems(LinkNameArray);
	
EndProcedure

&AtServer
Procedure DeleteFooterPages()
	
	For Each ListItem In FooterItemList Do 
		
		FoundItem = Items.Find(ListItem.Value);
		If FoundItem = Undefined Then 
			Continue;
		EndIf;
		
		Items.Delete(FoundItem);
		
	EndDo;
	
	FooterItemList.Clear();
	
EndProcedure

&AtServer
Procedure CreateFooterItems(LinkNameArray)
	
	If LinkNameArray = Undefined Then 
		Return;
	EndIf;
	
	NextItemName           = "Empty1";
	Item                   = Items.Add(NextItemName, Type("FormDecoration"), Items.Footer);
	Item.Kind              = FormDecorationType.Label;
	Item.HorizontalStretch = True;
	Item.Title             = "";
	
	FooterItemList.Add(NextItemName);
	
	Iteration = 0;
	
	For Each LinkName In LinkNameArray Do 
		
		Iteration = Iteration + 1;
		
		If LinkName = "..." Then 
			NextItemName = "ellipsis" + String(Iteration);
			Item         = Items.Add(NextItemName, Type("FormDecoration"), Items.Footer);
			Item.Kind    = FormDecorationType.Label;
			Item.Title   = String(LinkName);
			FooterItemList.Add(NextItemName);
			Continue;
		EndIf;
		
		If LinkName = NStr("en = 'Next'") Or LinkName = NStr("en = 'Previous'") Then 
			NextItemName   = LinkName;
			Item           = Items.Add(NextItemName, Type("FormDecoration"), Items.Footer);
			Item.Kind      = FormDecorationType.Label;
			Item.Title     = String(LinkName);
			Item.Hyperlink = True;
			Item.SetAction("Click", "PageNumberClick");
			FooterItemList.Add(NextItemName);
			Continue;
		EndIf;
		
		NextItemName = "p" + String(LinkName);
		Item         = Items.Add(NextItemName, Type("FormDecoration"), Items.Footer);
		Item.Kind    = FormDecorationType.Label;
		Item.Title   = String(LinkName);
		FooterItemList.Add(NextItemName);
		
		If Number(LinkName) = CurrentPage Then 
			Continue;
		EndIf;
		
		Item.Hyperlink = True;
		Item.SetAction("Click", "PageNumberClick");
		
	EndDo;
	
	NextItemName           = "Empty2";
	Item                   = Items.Add(NextItemName, Type("FormDecoration"), Items.Footer);
	Item.Kind              = FormDecorationType.Label;
	Item.HorizontalStretch = True;
	Item.Title             = "";
	FooterItemList.Add(NextItemName);
	
EndProcedure

&AtServer
Function GeneratePageItems(PageNumber)
	
	// Getting suggestion objects
	SuggestionObjects = GetSuggestionObjects();
	If SuggestionObjects = Undefined Then 
		Return False;
	EndIf;
	
	// Generating items for displaying suggestions
	GenerateSuggestionItems(SuggestionObjects);
	
	// Getting suggestion comments
	CommentList = GetComments(PageNumber);
	If CommentList = Undefined Then 
		Return False;
	EndIf;
	
	CurrentPage = PageNumber;
	
	// Generating comment representations
	GenerateCommentItems(CommentList.MaxAmountOnPage, CommentList.CommentList);
	
	// Generating comment representations
	GenerateFooter(CommentList);
	
	Return True;
	
EndFunction

&AtServer
Function GetSuggestionObjects()
	
	Try
		InformationCenterProxy = InformationCenterServer.GetInformationCenterProxy_1_0_1_2();
		Result = InformationCenterProxy.GetContentSuggestion(Login, SuggestionID);
		Return Result;
	Except
		EventName = InformationCenterServer.GetEventNameForEventLog();
		WriteLogEvent(EventName, EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Return Undefined;
	EndTry;
	
EndFunction

&AtServer
Function CastToStructureSuggestionObjects(SuggestionObjects)
	
	SuggestionParameters  = StructureSuggestionParameters(SuggestionObjects.Parameters);
	SuggestionContent = StructureSuggestionContent(SuggestionObjects.Content);
	
	Suggestion = New Structure;
	Suggestion.Insert("Parameters",  SuggestionParameters);
	Suggestion.Insert("Content", SuggestionContent);
	
	Return Suggestion;
	
EndFunction

&AtServer
Function StructureSuggestionParameters(SuggestionParameters)
	
	ParametersStructure = New Structure;
	
	ParametersStructure.Insert("EndDate",          SuggestionParameters.ClosingDate);
	ParametersStructure.Insert("ID",               SuggestionParameters.Ref);
	ParametersStructure.Insert("CreationDate",     SuggestionParameters.GenerationDate);
	ParametersStructure.Insert("TargetDate",       SuggestionParameters.PlanMadeDate);
	ParametersStructure.Insert("Rating",           SuggestionParameters.Rating);
	ParametersStructure.Insert("UserVote",         SuggestionParameters.Vote);
	ParametersStructure.Insert("Status",           SuggestionParameters.Status);
	ParametersStructure.Insert("Subject",          SuggestionParameters.Subject);
	ParametersStructure.Insert("Title",            SuggestionParameters.Title);
	ParametersStructure.Insert("DeveloperComment", SuggestionParameters.developerComment);
	
	Return ParametersStructure;
	
EndFunction

&AtServer
Function StructureSuggestionContent(SuggestionContent)
	
	ContentStructure = New Structure;
	
	ContentStructure.Insert("HTMLText", SuggestionContent.TextHTML);
	ContentStructure.Insert("Files",    GetSuggestionFileStructure(SuggestionContent.Files));
	
	Return ContentStructure;
	
EndFunction

&AtServer
Function GetSuggestionFileStructure(Files)
	
	Structure = New Structure;
	
	For Each FileStructure In Files.Files Do
		Structure.Insert(FileStructure.FullName, New Picture(FileStructure.BinData));
	EndDo;
	
	Return Structure;
	
EndFunction

&AtServer
Procedure GenerateSuggestionItems(SuggestionObjects)
	
	SuggestionStructure = CastToStructureSuggestionObjects(SuggestionObjects);
	
	Content.SetHTML(SuggestionStructure.Content.HTMLText, SuggestionStructure.Content.Files);
	
	Items.Rating.Title = SuggestionStructure.Settings.Rating;
	Items.Subject.Title = SuggestionStructure.Settings.Subject;
	Items.SuggestionTitle.Title = SuggestionStructure.Settings.Title;
	
	DeveloperComment = SuggestionStructure.Settings.DeveloperComment;
	If IsBlankString(DeveloperComment) Then
		Items.SupportTeamResponseGroup.Visible = False;
	EndIf;
	
	If SuggestionStructure.Settings.EndDate <> '00010101' Then
		Items.Done.Visible = True;
		Items.Done.Title = "made
		                    |" + String(Format(SuggestionStructure.Settings.EndDate, "DLF=D"));
		Return;
	EndIf;
	
	If SuggestionStructure.Settings.UserVote = 0 Then 
		Items.Vote.Visible = True;
	Else
		Items.WithYour.Visible = True;
	EndIf;
	
EndProcedure

&AtServer
Function AddCommentServer()
	
	InformationCenterProxy = InformationCenterServer.GetInformationCenterProxy_1_0_1_2();
	WebServiceXDTOFactory       = InformationCenterProxy.XDTOFactory;
	CommentDetails         = CastToXDTOUserCommentObject(WebServiceXDTOFactory);
	
	Return InformationCenterProxy.AddCommentSuggestion(CommentDetails);
	
EndFunction

&AtServer
Function CastToXDTOUserCommentObject(WebServiceXDTOFactory)
	
	CommentType      = WebServiceXDTOFactory.Type("http://www.1c.ru/SaaS/1.0/XMLSchema/ManageInfoCenter_1_0_1_2", "CommentListElement");
	CommentDetails = WebServiceXDTOFactory.Create(CommentType);
	
	CommentDetails.Text           = NewComment;
	CommentDetails.Date           = CurrentDate(); // SL project decision
	SetPrivilegedMode(True);
	CommentDetails.Author         = Login;
	CommentDetails.RefSuggestion  = SuggestionID;
	CommentDetails.Vote           = 0;
	SetPrivilegedMode(False);
	
	Return CommentDetails;
	
EndFunction

&AtServer
Procedure GenerateCommentItems(MaximumNumberPerPage, Comments)
	
	// Deleting obsolete items
	DeleteItems();
	
	MainGroup = Items.AllCommentsGroup;
	
	Iteration = 0;
	
	For Each Comment In Comments Do
		
		Iteration = Iteration + 1;
		
		If Iteration > MaximumNumberPerPage Then 
			Break;
		EndIf;
		
		CommentGroupName            = "CommentGroup" + String(Iteration);
		CommentGroup                = Items.Add(CommentGroupName, Type("FormGroup"), MainGroup);
		CommentGroup.Kind           = FormGroupType.UsualGroup;
		CommentGroup.ShowTitle      = False;
		CommentGroup.Grouping       = ChildFormItemsGroup.Vertical;
		CommentGroup.Representation = UsualGroupRepresentation.None;
		
		CommentItemList.Add(CommentGroupName);
		
		ItemNameCommentTitleGroup    = "CommentHeader" + String(Iteration);
		CommentHeader                = Items.Add(ItemNameCommentTitleGroup, Type("FormGroup"), CommentGroup);
		CommentHeader.Kind           = FormGroupType.UsualGroup;
		CommentHeader.ShowTitle      = False;
		CommentHeader.Grouping       = ChildFormItemsGroup.Horizontal;
		CommentHeader.Representation = UsualGroupRepresentation.None;
		
		CommentItemList.Add(ItemNameCommentTitleGroup);
		
		ItemNameCommentAuthor   = "CommentAuthor" + String(Iteration);
		CommentAuthor           = Items.Add(ItemNameCommentAuthor, Type("FormDecoration"), CommentHeader);
		CommentAuthor.Kind      = FormDecorationType.Label;
		CommentAuthor.Title     = String(Comment.Author);
		CommentAuthor.Font      = New Font( , , True);
		CommentAuthor.TextColor = New Color(159, 101, 0);
		
		CommentItemList.Add(ItemNameCommentAuthor);
		
		ItemNameCommentDate   = "CommentDate" + String(Iteration);
		CommentDate           = Items.Add(ItemNameCommentDate, Type("FormDecoration"), CommentHeader);
		CommentDate.Kind      = FormDecorationType.Label;
		CommentDate.Title     = String(Format(Comment.Date, "DLF=DD")) + ", " + String(Format(Comment.Date, "DF=HH:mm"));
		CommentDate.TextColor = New Color(128, 128, 128);
		
		CommentItemList.Add(ItemNameCommentDate);
		
		ItemNameCommentText = "CommentText" + String(Iteration);
		CommentText         = Items.Add(ItemNameCommentText, Type("FormDecoration"), CommentGroup);
		CommentText.Kind    = FormDecorationType.Label;
		CommentText.Title   = Comment.Text;
		
		CommentItemList.Add(ItemNameCommentText);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure DeleteItems()
	
	For Each ListItem In CommentItemList Do 
		FoundItem = Items.Find(ListItem.Value);
		If FoundItem = Undefined Then 
			Continue;
		EndIf;
		Items.Delete(FoundItem);
	EndDo;
	
	CommentItemList.Clear();
	
EndProcedure

&AtServer
Function GetComments(PageNumber)
	
	Try
		InformationCenterProxy = InformationCenterServer.GetInformationCenterProxy_1_0_1_2();
		Return InformationCenterProxy.GetCommentsSuggestion(SuggestionID, PageNumber);
	Except
		EventName = InformationCenterServer.GetEventNameForEventLog();
		WriteLogEvent(EventName, EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Return Undefined;
	EndTry;
	
EndFunction

&AtServer
Function GetPageLinkNameArray(Comments)
	
	LinkNameArray = New Array;
	
	// Current suggestion page 
	CurrentPage = Comments.CurrentPage;
	
	If CurrentPage > 1 Then 
		LinkNameArray.Add(NStr("en = 'Previous'"));
	EndIf;
	
	If CurrentPage >=1 Then 
		LinkNameArray.Add(CurrentPage);
	EndIf;
	
	If Comments.CommentList.Count() > Comments.MaxAmountOnPage Then 
		LinkNameArray.Add(NStr("en = 'Next'"));
	EndIf;
	
	If LinkNameArray.Count() = 1 Then 
		LinkNameArray.Clear();
	EndIf;
	
	Return LinkNameArray;
	
EndFunction
