////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then 
		Return;
	EndIf;
	
	ForumURL = Catalogs.InformationLinksForForms.Forum.Address;
	
	Items.FooterGroup.Visibility = Not IsBlankString(ForumURL);
	
	SetPrivilegedMode(True);
	UserID = Users.CurrentUser().ServiceUserID;
	SetPrivilegedMode(False);
	
	Result = GetTopicList();
	If Result = Undefined Then 
		Return;
	EndIf;
	
	ShowForm = True;
	
	GeneratePageItems(Result);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not ShowForm Then 
		
		If Not IsBlankString(ForumURL) Then 
			GotoURL(ForumURL);
		EndIf;
		
		Cancel = True;
		
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure TopicWithNewCommentsOnClick(Item)
	
	Filter = New Structure("FormItemName", Item.Name);
	FoundRows = TableForNewComments.FindRows(Filter);
	If FoundRows.IndexOf() = 0 Then 
		Return;
	EndIf;
	
	TopicURL = FoundRows.Get(0).URL;
	
	GotoURL(TopicURL);
	
EndProcedure

&AtClient
Procedure NewTopicOnClick(Item)
	
	Filter = New Structure("FormItemName", Item.Name);
	FoundRows = TableForNewTopics.FindRows(Filter);
	If FoundRows.IndexOf() = 0 Then 
		Return;
	EndIf;
	
	TopicURL = FoundRows.Get(0).URL;
	
	GotoURL(TopicURL);
	
EndProcedure

&AtClient
Procedure ForumLabelOnClick(Item)
	
	If Not IsBlankString(ForumURL) Then 
		GotoURL(ForumURL);
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS


////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Function GetTopicList()
	
	Try
		Proxy = InformationCenterServer.GetForumManagementProxy();
		Return Proxy.getForumTopics(String(UserID));
	Except
		EventName = InformationCenterServer.GetEventNameForEventLog();
		WriteLogEvent(EventName, EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Return Undefined;
	EndTry;
	
EndFunction

&AtServer
Procedure GeneratePageItems(Result)
	
	If Result.commentTopics.topicDescriptionCollection.IndexOf() <> 0 Then 
		GenerateNewCommentItems(Result.commentTopics.topicDescriptionCollection);
	EndIf;
	
	If Result.mainTopics.topicDescriptionCollection.IndexOf() <> 0 Then
		GenerateNewTopicItems(Result.mainTopics.topicDescriptionCollection);
	EndIf;
	
EndProcedure

&AtServer
Procedure GenerateNewCommentItems(NewComments)
	
	TopicWithNewCommentsTemplate = "%1 (%2)";
	
	Iteration = 0;
	For Each Comment In NewComments Do 
		
		NewItemName               = "TopicWithNewComments" + String(Iteration);
		NewItem                   = Items.Add(NewItemName, Type("FormDecoration"), Items.NewComments);
		NewItem.Type              = FormDecorationType.Label;
		NewItem.Title             = StringFunctionsClientServer.SubstituteParametersInString(TopicWithNewCommentsTemplate, Comment.subject, String(Comment.messageCount));
		NewItem.Hyperlink         = True;
		NewItem.HorizontalStretch = True;
		NewItem.SetAction("Click", "TopicWithNewCommentsOnClick");
		
		TableItem                 = TableForNewComments.Add();
		TableItem.FormItemName    = NewItemName;
		TableItem.URL             = Comment.url;
		
		Iteration = Iteration + 1;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure GenerateNewTopicItems(NewTopics)
	
	Iteration = 0;
	For Each Topic In NewTopics Do 
		
		NewTopicGroupItemName        = "NewTopicGroup" + String(Iteration);
		NewTopicGroup                = Items.Add(NewTopicGroupItemName, Type("FormGroup"), Items.NewTopics);
		NewTopicGroup.Type           = FormGroupType.UsualGroup;
		NewTopicGroup.ShowTitle      = False;
		NewTopicGroup.Grouping       = ChildFormItemsGroup.Horizontal;
		NewTopicGroup.Representation = ?(Iteration = 0, UsualGroupRepresentation.None, CTLAndSLIntegration.UsualGroupRepresentationLine());
		
		NewTopicItemName               = "NewTopic" + String(Iteration);
		NewTopicItem                   = Items.Add(NewTopicItemName, Type("FormDecoration"), NewTopicGroup);
		NewTopicItem.Type              = FormDecorationType.Label;
		NewTopicItem.Title             = Topic.subject;
		NewTopicItem.Hyperlink         = True;
		NewTopicItem.HorizontalStretch = True;
		NewTopicItem.SetAction("Click", "NewTopicOnClick");
		
		SubjectItemName                = "Subject" + String(Iteration);
		SubjectItem                    = Items.Add(SubjectItemName, Type("FormDecoration"), NewTopicGroup);
		SubjectItem.Type               = FormDecorationType.Label;
		SubjectItem.Title              = Topic.topicName;
		SubjectItem.HorizontalStretch  = True;
		SubjectItem.HorizontalLocation = ItemHorizontalLocation.Right;
		
		TableItem              = TableForNewTopics.Add();
		TableItem.FormItemName = NewTopicItemName;
		TableItem.URL          = Topic.url;
		
		Iteration = Iteration + 1;
		
	EndDo;
	
EndProcedure















