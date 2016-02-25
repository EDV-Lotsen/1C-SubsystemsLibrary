////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Get the current user login (for SaaS mode)
	SetPrivilegedMode(True);
	Login = String(Users.CurrentUser().ServiceUserID);
	SetPrivilegedMode(False);
	
	ChooseAll = True;
	
	HyperlinkColor = New Color(24, 52, 161);
	
	// Creation page items
	Result = GeneratePageItems("New", 1);
	If Not Result Then
		Raise NStr("en = 'The user suggestion service is temporarily unavailable.
			|Please try again later.");
		Cancel = True;
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Src)
	
	If EventName = "SuggestionChange" Then
		GeneratePageItems(CurrentGroup, CurrentPage);
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure SugesstionGroupClicking(Item)
	
	FillFormWithSuggestions(Item);
	
EndProcedure

&AtClient
Procedure SuggestionClick(Item)
	
	Rows = SuggestionTable.FindRows(New Structure("FormItemName", Item.Name));
	SuggestionID = Rows.Get(0).ID;
	FormParameters = New Structure("SuggestionID", SuggestionID);
	
	OpenForm("DataProcessor.InformationCenter.Form.Suggestion", FormParameters);
	
EndProcedure

&AtClient
Procedure PageNumberClick(Item)
	
	LinkName = Item.Name;
	
	If LinkName = NStr("en = 'Next'") Then 
		PageNumber = CurrentPage + 1;
	ElsIf LinkName = NStr("en = 'Previous'") Then 
		PageNumber = CurrentPage - 1;
	Else
		PageNumber = StrReplace(Item.Name, "p", "");
		Try
			PageNumber = Number(PageNumber);
		Except
			PageNumber = CurrentPage;
		EndTry;
	EndIf;
	
	// Creating the page items
	Result = GeneratePageItems(CurrentGroup, PageNumber, False);
	If Not Result Then
		Raise NStr("en = 'The user suggestion service is temporarily unavailable.
			|Please try again later.");
		Cancel = True;
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnFilterValueChange(Item)
	
	FilterValueChange(Item.Name);
	
EndProcedure

&AtClient
Procedure SelectAllOnChange(Item)
	
	OnSelectAllChange();
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure FindSuggestions(Command)
	
	If IsBlankString(Search) Then 
		ShowMessageBox(,NStr("en = 'Fill the search string'"));
		Return;
	EndIf;
	
	GeneratePageItems("Search", 1);
	
EndProcedure

&AtClient
Procedure Vote(Command)
	
	ExecuteActionByVote(Command.Name);
	
EndProcedure

&AtClient
Procedure WriteSuggestion(Command)
	
	FormParameters = New Structure("Login", Login);
	OpenForm("DataProcessor.InformationCenter.Form.MakeSuggestion", FormParameters);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Procedure OnSelectAllChange()
	
	For Each Filter In FiltersList Do
		Filter.Selected = ChooseAll;
	EndDo;
	
	// Generating page items
	Result = GeneratePageItems(CurrentGroup, 1, False);
	If Not Result Then
		Raise NStr("en = 'The user suggestion service is temporarily unavailable.
			|Please try again later.'");
		Cancel = True;
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteActionByVote(CommandName)
	
	SuggestionID = "";
	
	For Each ListItem In CommandList Do
		If ListItem.CommandName = CommandName Then 
			SuggestionID = ListItem.SuggestionID;
			Break;
		EndIf;
	EndDo;
	
	VoteTaken = VoteForSuggestionServer(1, SuggestionID);
	If Not VoteTaken Then 
		ShowMessageBox(,NStr("en = 'You vote cannot be added.
								|Please try to vote later."));
		Return;
	EndIf;
	
	ShowUserNotification(NStr("en = 'Your vote was taken.'"));
	
	FormParameters = New Structure("Login, SuggestionID", Login, SuggestionID);
	OpenFormModal("DataProcessor.InformationCenter.Form.Comment", FormParameters);
	
	// Generating page items
	Result = GeneratePageItems(CurrentGroup, CurrentPage);
	If Not Result Then
		ShowMessageBox(,NStr("en = 'The user suggestion service is temporarily unavailable.
			|Please try again later.'"));
		Return;
	EndIf;
	
EndProcedure

&AtServer
Procedure FilterValueChange(Val ItemName)
	
	For Each Filter In FiltersList Do
		If Filter.Description = ItemName Then 
			Filter.Selected = ThisForm[ItemName];
			Break;
		EndIf;
	EndDo;
	
	// Generating page items
	Result = GeneratePageItems(CurrentGroup, 1, False);
	If Not Result Then
		Raise NStr("en = 'The user suggestion service is temporarily unavailable.
			|Please try again later.'");
		Cancel = True;
		Return;
	EndIf;
	
EndProcedure

&AtServer
Function GeneratePageItems(GroupType, PageNumber, ResetFilters = True)
	
	SuggestionGroup = GetSuggestionGroup(GroupType, PageNumber, ResetFilters);
	If SuggestionGroup = Undefined Then
		Return False;
	EndIf;
	
	// Getting visibility of filter hyperlinks
	GenerateSuggestionGroupTitles(SuggestionGroup, GroupType);
	
	// Generating filters
	GenerateFilters(SuggestionGroup.ParametersForForm.ObjectSuggestion.ObjectSuggestion, ResetFilters);
	
	// Determining the current group
	CurrentGroup = GroupType;
	
	// Generating suggestion form items
	GenerateItemsForSuggestions(SuggestionGroup.MaxAmountOnPage, SuggestionGroup.Suggestions);
	
	// Generating the footer
	GenerateFooter(SuggestionGroup);
	
	Return True;
	
EndFunction

&AtServer
Procedure GenerateSuggestionGroupTitles(ParameterListForForm, GroupType)
	
	// Getting group title items
	GetSuggestionGroupTitleItems(ParameterListForForm, GroupType);
	
EndProcedure

&AtServer
Procedure GetSuggestionGroupTitleItems(ParameterListForForm, GroupType)
	
	ResetParametersForGroupTitleItems();
	
	If GroupType = "Popular" Then 
		Items.Popular.Hyperlink = False;
		Items.Popular.Font      = New Font(,, True);
	ElsIf GroupType = "My" Then
		Items.MySuggestions.Hyperlink = False;
		Items.MySuggestions.Font      = New Font(,, True);
	ElsIf GroupType = "New" Then
		Items.New.Hyperlink = False;
		Items.New.Font      = New Font(,, True);
	ElsIf GroupType = "Made" Then
		Items.Completed.Hyperlink = False;
		Items.Completed.Font      = New Font(,, True);
	EndIf;
	
EndProcedure

&AtServer
Procedure ResetParametersForGroupTitleItems()
	
	Items.Popular.Hyperlink       = True;
	Items.Completed.Hyperlink     = True;
	Items.MySuggestions.Hyperlink = True;
	Items.New.Hyperlink           = True;
	
	Items.Popular.Font          = New Font();
	Items.Completed.Font        = New Font();
	Items.MySuggestions.Font    = New Font();
	Items.New.Font              = New Font();
	
EndProcedure

&AtServer
Procedure GenerateFilters(ParameterListForForm, ResetFilters)
	
	// Deleting form items
	DeleteFormItemsForFilters();
	
	// Deleting form attributes
	DeleteFormAttributesForFilters();
	
	// Creating new attributes
	CreateFormAttributesForFilters(ParameterListForForm, ResetFilters);
	
	// Creating new form items
	CreateFormItemsForFilters(ParameterListForForm);
	
EndProcedure

&AtServer
Procedure CreateFormItemsForFilters(ParameterListForForm)
	
	FiltersList.Clear();
	
	Iteration = 0;
	
	FilterCountInGroup = ParameterListForForm.Count() / 3;
	
	FilterCountInGroup = ?(Int(FilterCountInGroup) < FilterCountInGroup, Int(FilterCountInGroup) + 1, Int(FilterCountInGroup));
	
	For Each FormParameter In ParameterListForForm Do 
		
		If Iteration = 0 Or Iteration%FilterCountInGroup = 0 Then 
			FormItemName               = "FilterGroup" + String(Iteration);
			ParentGroup                = Items.Add(FormItemName, Type("FormGroup"), Items.FilterGroup);
			ParentGroup.Kind           = FormGroupType.UsualGroup;
			ParentGroup.ShowTitle      = False;
			ParentGroup.Grouping       = ChildFormItemsGroup.Vertical;
			ParentGroup.Representation = UsualGroupRepresentation.None;
			FilterGroupList.Add(FormItemName);
		EndIf;
		
		FormItemName                  = "OneFilterGroup" + String(Iteration);
		OneFilterGroup                = Items.Add(FormItemName, Type("FormGroup"), ParentGroup);
		OneFilterGroup.Kind           = FormGroupType.UsualGroup;
		OneFilterGroup.ShowTitle      = False;
		OneFilterGroup.Grouping       = ChildFormItemsGroup.Horizontal;
		OneFilterGroup.Representation = UsualGroupRepresentation.None;
		
		Iteration    = Iteration + 1;
		ItemName = "Filter" + String(Iteration);
		
		FormField               = Items.Add(ItemName, Type("FormField"), OneFilterGroup);
		FormField.Kind          = FormFieldType.CheckBoxField;
		FormField.DataPath      = ItemName;
		FormField.TitleLocation = FormItemTitleLocation.None;
		FormField.Title                = FormParameter.Name;
		FormField.SetAction("OnChange", "OnFilterValueChange");
		
		ListItem = FiltersList.Add();
		ListItem.Description = ItemName;
		ListItem.Selected    = ThisForm[ItemName];
		
		NextItemName           = "FilterTitle" + String(Iteration);
		Item                   = Items.Add(NextItemName, Type("FormDecoration"), OneFilterGroup);
		Item.Kind              = FormDecorationType.Label;
		Item.Title             = FormParameter.Name;
		Item.HorizontalStretch = True;
		
		FilterTitles.Add(NextItemName);
		
		NextItemName                           = "BlankLineAfterFilter" + String(Iteration);
		BlankLineAfterFilter                   = Items.Add(NextItemName, Type("FormDecoration"), OneFilterGroup);
		BlankLineAfterFilter.Kind              = FormDecorationType.Label;
		BlankLineAfterFilter.Title             = "";
		BlankLineAfterFilter.HorizontalStretch = True;
		
		FilterTitles.Add(NextItemName);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure CreateFormAttributesForFilters(ParameterListForForm, ResetFilters)
	
	// Adding attributes
	AttributesToAddArray = New Array;
	Iteration = 0;
	For Each FormParameter In ParameterListForForm Do
		Iteration = Iteration + 1;
		NewAttribute = New FormAttribute("Filter" + String(Iteration), New TypeDescription("Boolean"));
		AttributesToAddArray.Add(NewAttribute);
	EndDo;
	
	If AttributesToAddArray.Count() = 0 Then 
		Return;
	EndIf;
	
	ChangeAttributes(AttributesToAddArray);
	
	Iteration = 0;
	For Each FormParameter In ParameterListForForm Do
		Iteration = Iteration + 1;
		ThisForm["Filter" + String(Iteration)] = True;
	EndDo;
	
	If Not ResetFilters Then 
		For Each ListItem In FiltersList Do
			Try
				ThisForm[ListItem.Description] = ListItem.Selected;
			Except
			EndTry;
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Procedure DeleteFormAttributesForFilters()
	
	AttributesToDeleteArray = New Array;
	For Each Filter In FiltersList Do
		AttributesToDeleteArray.Add(Filter.Description);
	EndDo;
	
	If AttributesToDeleteArray.Count() = 0 Then 
		Return;
	EndIf;
	
	ChangeAttributes( , AttributesToDeleteArray);
	
EndProcedure

&AtServer
Procedure DeleteFormItemsForFilters()
	
	For Each Filter In FiltersList Do
		
		FormItem = Items.Find(Filter.Description);
		If FormItem = Undefined Then 
			Continue;
		EndIf;
		
		Items.Delete(FormItem);
		
	EndDo;
	
	For Each FilterGroup In FilterGroupList Do
		
		FormItem = Items.Find(FilterGroup.Value);
		If FormItem = Undefined Then 
			Continue;
		EndIf;
		
		Items.Delete(FormItem);
		
	EndDo;
	
	For Each FilterTitle In FilterTitles Do
		
		FormItem = Items.Find(FilterTitle.Value);
		If FormItem = Undefined Then 
			Continue;
		EndIf;
		
		Items.Delete(FormItem);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure GenerateFooter(SuggestionGroup)
	
	// Deleting obsolete pages and items
	DeleteFooterPages();
	
	// Getting an array of link names
	LinkNameArray = GetPageLinkNameArray(SuggestionGroup);
	
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
	
	If LinkNameArray.Count() = 0 Then 
		Items.Footer.Visibility = False;
		Return;
	EndIf;
	
	Items.Footer.Visibility = True;
	
	Items.CommonFooter.Representation = CTLAndSLIntegration.UsualGroupRepresentationLine();
	
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
			NextItemName       = "ellipsis" + String(Iteration);
			Item               = Items.Add(NextItemName, Type("FormDecoration"), Items.Footer);
			Item.Kind          = FormDecorationType.Label;
			Item.Title         = String(LinkName);
			Item.VerticalAlign = ItemVerticalAlign.Center;
			FooterItemList.Add(NextItemName);
			Continue;
		EndIf;
		
		If LinkName = NStr("en = 'Next'") Or LinkName = NStr("en = 'Previous'") Then 
			NextItemName       = LinkName;
			Item               = Items.Add(NextItemName, Type("FormDecoration"), Items.Footer);
			Item.Kind          = FormDecorationType.Label;
			Item.Title         = String(LinkName);
			Item.Hyperlink     = True;
			Item.VerticalAlign = ItemVerticalAlign.Center;
			Item.Font          = New Font( , , , , False);
			Item.SetAction("Click", "PageNumberClick");
			FooterItemList.Add(NextItemName);
			Continue;
		EndIf;
		
		NextItemName            = "p" + String(LinkName);
		Item                    = Items.Add(NextItemName, Type("FormDecoration"), Items.Footer);
		Item.Kind               = FormDecorationType.Label;
		Item.Title              = String(LinkName);
		Item.VerticalAlign      = ItemVerticalAlign.Center;
		Item.HorizontalLocation = ItemHorizontalLocation.Center;
		Item.Font               = New Font( , , , , False);
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
Function GetPageLinkNameArray(SuggestionGroup)
	
	LinkNameArray = New Array;
	
	// Current suggestion page 
	CurrentPage = SuggestionGroup.CurrentPage;
	
	SuggestionCount    = SuggestionGroup.AmountSuggestion;
	MaximumCount = SuggestionGroup.MaxAmountOnPage;
	
	PageCount = Int(SuggestionCount / MaximumCount) + ?((SuggestionCount % MaximumCount) > 0, 1, 0);
	
	SidePageCount = 3;
	
	IterationStart = ?((CurrentPage - SidePageCount) >= 1, CurrentPage - SidePageCount, 1);
	IterationEnd  = ?((CurrentPage + SidePageCount) >= PageCount, PageCount, CurrentPage + SidePageCount);
	
	If CurrentPage > 1 Then 
		LinkNameArray.Add(NStr("en = 'Previous'"));
	EndIf;
	
	For Iteration = IterationStart to IterationEnd Do
		LinkNameArray.Add(String(Iteration));
	EndDo;
	
	If CurrentPage < IterationEnd Then 
		LinkNameArray.Add(NStr("en = 'Next'"));
	EndIf;
	
	If LinkNameArray.Count() = 1 And CurrentPage = 1 Then 
		LinkNameArray.Clear();
	EndIf;
	
	Return LinkNameArray;
	
EndFunction

&AtServer
Function GetSuggestionSubjectList(WebServiceXDTOFactory)
	
	GroupListType = WebServiceXDTOFactory.Type("http://www.1c.ru/SaaS/1.0/XMLSchema/ManageInfoCenter_1_0_1_2", "ObjectSuggestionList");
	GroupListDetails = WebServiceXDTOFactory.Create(GroupListType);
	
	GroupType = WebServiceXDTOFactory.Type("http://www.1c.ru/SaaS/1.0/XMLSchema/ManageInfoCenter_1_0_1_2", "ObjectSuggestionListElement");
	
	For Each ListItem In FiltersList Do 
		
		If Not ListItem.Selected Then 
			Continue;
		EndIf;
		
		FoundItem = Items.Find(ListItem.Description);
		If FoundItem = Undefined Then 
			Continue;
		EndIf;
		
		GroupDetails      = WebServiceXDTOFactory.Create(GroupType);
		GroupDetails.Name = FoundItem.Title;
		GroupListDetails.ObjectSuggestion.Add(GroupDetails);
		
	EndDo;
	
	Return GroupListDetails;
	
EndFunction

&AtServer
Function GetSuggestionGroup(GroupType, PageNumber, ResetFilters)
	
	Try
		Proxy = InformationCenterServer.GetInformationCenterProxy_1_0_1_2();
		Subjects = GetSuggestionSubjectList(Proxy.XDTOFactory);
		Return Proxy.GetGroupSuggestion(GroupType, PageNumber, Login, Subjects, Search, ResetFilters);
	Except
		EventName = InformationCenterServer.GetEventNameForEventLog();
		WriteLogEvent(EventName, EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Return Undefined;
	EndTry;
	
EndFunction

&AtServer
Procedure DeleteSuggestionFormItems(ItemTree)
	
	For Each TreeRow In ItemTree.Strings Do 
		
		If TreeRow.Row.Count() <> 0 Then 
			DeleteSuggestionFormItems(TreeRow);
		EndIf;
		
		// Deleting form items
		FormItemName = TreeRow.ItemName;
		FormItem = Items.Find(FormItemName);
		If FormItem = Undefined Then 
			Continue;
		EndIf;
		Items.Delete(FormItem);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure GenerateItemsForSuggestions(MaxNumberOnPage, Suggestions)
	
	// Deleting obsolete form items
	DeleteItems();
	
	// Deleting form commands
	DeleteCommands();
	
	SuggestionTable.Clear();
	
	MainGroup = Items.SuggestionGroup;
	
	ItemTree = FormAttributeToValue("SuggestionItemTree", Type("ValueTree"));
	Iteration = 0;
	For Each Suggestion In Suggestions Do 
		
		Iteration = Iteration + 1;
		
		If Iteration > MaxNumberOnPage Then 
			Break;
		EndIf;
		
		GroupForSuggestions = GenerateGroupForSuggestion(Suggestion, MainGroup, Iteration, ItemTree);
		
	EndDo;
	ValueToFormAttribute(ItemTree, "SuggestionItemTree");
	
EndProcedure

&AtServer
Procedure DeleteCommands()
	
	For Each ListItem In CommandList Do 
		FoundCommand = Commands.Find(ListItem.CommandName);
		If FoundCommand <> Undefined Then 
			Commands.Delete(FoundCommand);
		EndIf;
	EndDo;
	
	CommandList.Clear();
	
EndProcedure

&AtServer
Procedure DeleteItems()
	
	ItemTree = FormAttributeToValue("SuggestionItemTree", Type("ValueTree"));
	
	DeleteSuggestionFormItems(ItemTree);
	
	TypeArray = New Array;
	TypeArray.Add(Type("String"));
	DetailsString = New TypeDescription(TypeArray);
	ItemTree = New ValueTree;
	ItemTree.Columns.Add("ItemName", DetailsString);
	
	ValueToFormAttribute(ItemTree, "SuggestionItemTree");
	
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
Function GenerateGroupForSuggestion(Suggestion, MainGroup, Iteration, ItemTree)
	
	FormItemName                      = "SuggestionGroup" + String(Iteration);
	SuggestionGroup                   = Items.Add(FormItemName, Type("FormGroup"), MainGroup);
	SuggestionGroup.Kind              = FormGroupType.UsualGroup;
	SuggestionGroup.ShowTitle         = False;
	SuggestionGroup.Grouping          = ChildFormItemsGroup.Horizontal;
	SuggestionGroup.Representation    = CTLAndSLIntegration.UsualGroupRepresentationLine();
	SuggestionGroup.HorizontalStretch = True;
	
	TreeRow = ItemTree.Rows.Add();
	TreeRow.ItemName = FormItemName;
	
	// Generating subordinate items
	GenerateSuggestionRatingGroup(Suggestion, Iteration, SuggestionGroup, TreeRow);
	GenerateSuggestionContentGroup(Suggestion, Iteration, SuggestionGroup, TreeRow);
	
EndFunction

&AtServer
Procedure GenerateSuggestionRatingGroup(Suggestion, Iteration, ParentGroup, ParentTreeRow)
	
	GroupItemWidth = 7;
	
	GroupName                  = "RatingGroup" + String(Iteration);
	RatingGroup                = Items.Add(GroupName, Type("FormGroup"), ParentGroup);
	RatingGroup.Kind           = FormGroupType.UsualGroup;
	RatingGroup.ShowTitle      = False;
	RatingGroup.Grouping       = ChildFormItemsGroup.Vertical;
	RatingGroup.Representation = UsualGroupRepresentation.None;
	
	GroupRow          = ParentTreeRow.Rows.Add();
	GroupRow.ItemName = GroupName;
	
	CurrentSuggestionRating = Suggestion.Rating;
	CurrentSuggestionRating = ?(CurrentSuggestionRating = 0, "0", Format(Suggestion.Rating, "NG=0"));
	
	SuggestionRatingItemName            = "Rating" + String(Iteration);
	SuggestionRating                    = Items.Add(SuggestionRatingItemName, Type("FormDecoration"), RatingGroup);
	SuggestionRating.Kind               = FormDecorationType.Label;
	SuggestionRating.Title              = CurrentSuggestionRating;
	SuggestionRating.Font               = New Font( , 18);
	SuggestionRating.Width              = GroupItemWidth;
	SuggestionRating.HorizontalLocation = ItemHorizontalLocation.Center;
	
	TreeRow          = GroupRow.Rows.Add();
	TreeRow.ItemName = SuggestionRatingItemName;
	
	If Suggestion.ClosingDate <> '00010101' Then 
		
		DoneItemName                    = "Done" + String(Iteration);
		DoneItemName                    = Items.Add(DoneItemName, Type("FormDecoration"), RatingGroup);
		DoneItemName.Title              = NStr("en = 'made
		                                          |'") + String(Format(Suggestion.ClosingDate, "DLF=D"));
		DoneItemName.Height             = 2;
		DoneItemName.Width              = GroupItemWidth;
		DoneItemName.HorizontalLocation = ItemHorizontalLocation.Center;
		
		TreeRow          = GroupRow.Rows.Add();
		TreeRow.ItemName = DoneItemName;
		
		Return;
		
	EndIf;
	
	If Suggestion.Vote = 0 Then
		
		VoteButtonItemName = "Vote" + String(Iteration);
		CommandName = VoteButtonItemName + "Command";
		
		Command = Commands.Add(CommandName);
		Command.Activity = "Vote";
		
		ListItem = CommandList.Add();
		ListItem.CommandName  = CommandName;
		ListItem.SuggestionID = Suggestion.Ref;
		
		VoteButtin             = Items.Add(VoteButtonItemName, Type("FormButton"), RatingGroup);
		VoteButtin.Title       = "+1";
		VoteButtin.CommandName = Command.Name;
		VoteButtin.Font        = New Font("Tahoma", 10, True);
		VoteButtin.TextColor   = New Color(5, 177, 4);
		VoteButtin.Width       = GroupItemWidth - 1;
		
		TreeRow          = GroupRow.Rows.Add();
		TreeRow.ItemName = VoteButtonItemName;
		
	Else
		
		WithYourItemName                    = "WithYour" + String(Iteration);
		WithYourItemName                    = Items.Add(WithYourItemName, Type("FormDecoration"), RatingGroup);
		WithYourItemName.Title              = NStr("en = 'with your
		                                          |vote'");
		WithYourItemName.TextColor          = New Color(5, 177, 4);
		WithYourItemName.Height             = 2;
		WithYourItemName.Width              = GroupItemWidth;
		WithYourItemName.HorizontalLocation = ItemHorizontalLocation.Center;
		
		TreeRow          = GroupRow.Rows.Add();
		TreeRow.ItemName = WithYourItemName;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure GenerateSuggestionContentGroup(Suggestion, Iteration, ParentGroup, ParentTreeRow)
	
	GroupName                             = "ContentGroup" + String(Iteration);
	SuggestionContentGroup                = Items.Add(GroupName, Type("FormGroup"), ParentGroup);
	SuggestionContentGroup.Kind           = FormGroupType.UsualGroup;
	SuggestionContentGroup.ShowTitle      = False;
	SuggestionContentGroup.Representation = UsualGroupRepresentation.None;
	
	GroupRow          = ParentTreeRow.Rows.Add();
	GroupRow.ItemName = GroupName;
	
	SuggestionsHTitleItemName         = "SuggestionTitle" + String(Iteration);
	SuggestionTitle                   = Items.Add(SuggestionsHTitleItemName, Type("FormDecoration"), SuggestionContentGroup);
	SuggestionTitle.Kind              = FormDecorationType.Label;
	SuggestionTitle.Title             = Suggestion.Title;
	SuggestionTitle.Hyperlink         = True;
	SuggestionTitle.Font              = New Font(, 11, True);
	SuggestionTitle.TextColor         = New Color(51, 51, 51);
	SuggestionTitle.HorizontalStretch = True;
	SuggestionTitle.VerticalAlign     = ItemVerticalAlign.Top;
	SuggestionTitle.SetAction("Click", "SuggestionClick");
	
	TreeRow             = GroupRow.Rows.Add();
	TreeRow.ItemName = SuggestionsHTitleItemName;
	
	TableItem = SuggestionTable.Add();
	TableItem.FormItemName = SuggestionsHTitleItemName;
	TableItem.ID           = Suggestion.Ref;
	
	If Suggestion.AmountComments = 0 Then 
		CommentsTitle = NStr("en = 'Add comment'");
	Else
		CommentsTitle = NStr("en = 'Comments'") + " (" + String(Suggestion.AmountComments) + ")";
	EndIf;
	
	GroupName                            = "SuggestionFooterGroup"+ String(Iteration);
	SuggestionFooterGroup                = Items.Add(GroupName, Type("FormGroup"), SuggestionContentGroup);
	SuggestionFooterGroup.Kind           = FormGroupType.UsualGroup;
	SuggestionFooterGroup.ShowTitle      = False;
	SuggestionFooterGroup.Grouping       = ChildFormItemsGroup.Horizontal;
	SuggestionFooterGroup.Representation = UsualGroupRepresentation.None;
	
	GroupRow          = ParentTreeRow.Rows.Add();
	GroupRow.ItemName = GroupName;
	
	CommentTitleName               = "CommentTitle" + String(Iteration);
	CommentTitle                   = Items.Add(CommentTitleName, Type("FormDecoration"), SuggestionFooterGroup);
	CommentTitle.Kind              = FormDecorationType.Label;
	CommentTitle.Title             = CommentsTitle;
	CommentTitle.Hyperlink         = True;
	CommentTitle.HorizontalStretch = True;
	CommentTitle.VerticalAlign     = ItemVerticalAlign.Bottom;
	CommentTitle.VerticalStretch   = True;
	CommentTitle.SetAction("Click", "SuggestionClick");
	
	TreeRow          = GroupRow.Rows.Add();
	TreeRow.ItemName = CommentTitle;
	
	SuggestionSubjectName                = "SuggestionSubject" + ParentGroup.Name + String(Iteration);
	SuggestionSubject                    = Items.Add(SuggestionSubjectName, Type("FormDecoration"), SuggestionFooterGroup);
	SuggestionSubject.Kind               = FormDecorationType.Label;
	SuggestionSubject.Font               = New Font( ,9);
	SuggestionSubject.HorizontalStretch  = True;
	SuggestionSubject.VerticalStretch    = True;
	SuggestionSubject.HorizontalLocation = ItemHorizontalLocation.Right;
	SuggestionSubject.VerticalAlign      = ItemVerticalAlign.Bottom;
	SuggestionSubject.Title              = Suggestion.Subject;
	
	TreeRow          = GroupRow.Rows.Add();
	TreeRow.ItemName = SuggestionSubjectName;
	
	TableItem = SuggestionTable.Add();
	TableItem.FormItemName = CommentTitleName;
	TableItem.ID           = Suggestion.Ref;
	
EndProcedure

&AtClient
Procedure FillFormWithSuggestions(Item)
	
	If Item.Name = "MySuggestions" Then
		GroupType = "My";
	ElsIf Item.Name = "New" Then
		GroupType = "New";
	ElsIf Item.Name = "Completed" Then
		GroupType = "Made";
	Else
		GroupType = "Popular";
	EndIf;
	
	
	Result = GeneratePageItems(GroupType, 1, False);
	If Not Result Then
		ShowMessageBox(,NStr("en = 'The user suggestion service is temporarily unavailable.
			|Please try again later.'"));
	EndIf;
	
EndProcedure
