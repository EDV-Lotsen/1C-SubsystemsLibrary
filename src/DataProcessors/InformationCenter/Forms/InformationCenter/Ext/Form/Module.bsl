////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not CTLAndSLIntegration.OnCreateAtServer(ThisForm, Cancel, StandardProcessing) Then
		
		Return;
		
	EndIf;
	
	UseSeparationByDataAreas = CTLAndSLIntegration.DataSeparationEnabled()
		And CTLAndSLIntegration.CanUseSeparatedData();
	
	InformationSearchLink = "http://1c-dn.com/search/?q=%D1%81%D0%BB%D0%BE%D0%B2%D0%BE";
	
	If UseSeparationByDataAreas Then // for SaaS mode
		
		// Homepage
		MainPage                  = Catalogs.InformationLinksForForms.Homepage;
		Homepage                  = New Structure("Name, Address", MainPage.Description, MainPage.Address);
		Items.Homepage.Title       = Homepage.Name;
		Items.Homepage.Visible = ?(IsBlankString(Homepage.Address), False, True);
		
		InformationCenterServerOverridable.GetInformationSearchLink(InformationSearchLink);
		
		GenerateNewsList();
		
	Else // for local mode
		
		Items.StartPageGroup.Visible   = False;
		Items.InteractionGroup.Visible = False;
		
	EndIf;
	
	InformationCenterServer.DisplayContextLinks(ThisForm, Items.InformationLinks, 1, 5, False);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure NewsItemOnClick(Item)
	
	Filter = New Structure;
	Filter.Insert("FormItemName", Item.Name);
	
	RowArray = NewsTable.FindRows(Filter);
	If RowArray.Count() = 0 Then 
		Return;
	EndIf;
	
	CurrentMessage = RowArray.Get(0);
	
	If CurrentMessage.InformationType = "Unavailability" Then 
		
		ID           = CurrentMessage.ID;
		ExternalLink = CurrentMessage.ExternalLink;
		
		If Not IsBlankString(ExternalLink) Then 
			GotoURL(ExternalLink);
			Return;
		EndIf;
		
		InformationCenterClient.ShowNewsItem(ID);
		
	ElsIf CurrentMessage.InformationType = "SuggestionNotification" Then 
		
		SuggestionID = String(CurrentMessage.ID);
		
		InformationCenterClient.ShowSuggestion(SuggestionID);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure MoreMessagesClick(Item)
	
	InformationCenterClient.ShowAllNews();
	
EndProcedure

&AtClient
Procedure WriteToSupportClick(Item)
	
	OpenForm("DataProcessor.InformationCenter.Form.UserTickets");
	
EndProcedure

&AtClient
Procedure SuggestIdeaClick(Item)
	
	OpenForm("DataProcessor.InformationCenter.Form.UserSuggestions");
	
EndProcedure

&AtClient
Procedure HomepageClick(Item)
	
	If Not Homepage.Property("URL") Then 
		Return;
	EndIf;
	
	GotoURL(Homepage.URL);
	
EndProcedure

&AtClient
Procedure ForumClick(Item)
	
	OpenForm("DataProcessor.InformationCenter.Form.ForumTopics");
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure FindAnswerToQuestion(Command)
	
	SearchAnswerToQuestion();
	
EndProcedure

&AtClient
Procedure Attachable_InformationLinkClick(Command)
	
	InformationCenterClient.InformationLinkClick(ThisForm, Command);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Procedure GenerateNewsList()
	
	SetPrivilegedMode(True);
	InformationCenterServer.GenerateNewsListOnDesktop(NewsTable);
	
	If NewsTable.Count() = 0 Then 
		Return;
	EndIf;
	
	NewsGroup = Items.NewsGroup;
	
	For Iteration = 0 to NewsTable.Count() - 1 Do
		
		Description = NewsTable.Get(Iteration).LinkToData.Description;
		
		If IsBlankString(Description) Then 
			Continue;
		EndIf;
		
		Criticality = NewsTable.Get(Iteration).LinkToData.Criticality;
		Picture     = ?(Criticality > 5, PictureLib.ServiceNotification, PictureLib.ServiceMessage);
		
		NewsItemGroup                = Items.Add("NewsItemGroup" + String(Iteration), Type("FormGroup"), NewsGroup);
		NewsItemGroup.Kind           = FormGroupType.UsualGroup;
		NewsItemGroup.ShowTitle      = False;
		NewsItemGroup.Grouping       = ChildFormItemsGroup.Horizontal;
		NewsItemGroup.Representation = UsualGroupRepresentation.None;
		
		NewsItemPicture             = Items.Add("NewsItemPicture" + String(Iteration), Type("FormDecoration"), NewsItemGroup);
		NewsItemPicture.Kind        = FormDecorationType.Picture;
		NewsItemPicture.Picture     = Picture;
		NewsItemPicture.Width       = 2;
		NewsItemPicture.Height      = 1;
		NewsItemPicture.PictureSize = PictureSize.Stretch;
		
		NewsItemName                   = Items.Add("NewsItemName" + String(Iteration), Type("FormDecoration"), NewsItemGroup);
		NewsItemName.Kind              = FormDecorationType.Label;
		NewsItemName.Title             = Description;
		NewsItemName.HorizontalStretch = True;
		NewsItemName.VerticalAlign     = ItemVerticalAlign.Center;
		NewsItemName.TitleHeight       = 1;
		NewsItemName.Hyperlink         = True;
		NewsItemName.SetAction("Click", "NewsItemOnClick");
		
		NewsTable.Get(Iteration).FormItemName    = NewsItemName.Name;
		NewsTable.Get(Iteration).InformationType = NewsTable.Get(Iteration).LinkToData.InformationType.Description;
		NewsTable.Get(Iteration).ID              = NewsTable.Get(Iteration).LinkToData.ID;
		NewsTable.Get(Iteration).ExternalLink    = NewsTable.Get(Iteration).LinkToData.ExternalLink;
		
	EndDo;
	
	MoreMessages                   = Items.Add("MoreMessages", Type("FormDecoration"), NewsGroup);
	MoreMessages.Type              = FormDecorationType.Label;
	MoreMessages.Title             = NStr("en = 'More messages'");
	MoreMessages.HorizontalStretch = True;
	MoreMessages.VerticalAlign     = ItemVerticalAlign.Center;
	MoreMessages.Hyperlink         = True;
	MoreMessages.SetAction("Click", "MoreMessagesClick");
	
EndProcedure

&AtClient
Procedure SearchAnswerToQuestion()
	
	AttachIdleHandler("SearchAnswerToQuestionIdleHandler", 0.1, True);
	
EndProcedure

&AtClient
Procedure SearchAnswerToQuestionIdleHandler()
	
	If IsBlankString(SearchString) Then
		Return;
	EndIf;
	
	GotoURL(InformationSearchLink + SearchString);
	
EndProcedure
