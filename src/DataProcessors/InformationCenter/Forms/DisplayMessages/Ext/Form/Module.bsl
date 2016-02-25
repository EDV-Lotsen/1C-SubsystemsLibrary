////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the
	// AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then 
		Return;
	EndIf;
	
	If Parameters.Property("OpenAllNews") Then
		OpenAllNews();
	ElsIf Parameters.Property("OpenNewsItem") Then
		If Parameters.Property("ID") Then 
			OpenNewsItem(Parameters.ID);
		EndIf;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure NewsItemOnClick(Item)
	
	Filter = New Structure;
	Filter.Insert("FormItemName", Item.Name);
	
	RowArray = AllNewsTable.FindRows(Filter);
	If RowArray.Index() = 0 Then 
		Return;
	EndIf;
	
	CurrentMessage = RowArray.Get(0);
	
	If CurrentMessage.InformationType = "Unavailability" Then 
		
		OpenNewsItem(CurrentMessage.ID);
		
	ElsIf CurrentMessage.InformationType = "SuggestionNotification" Then 
		
		SuggestionID = String(CurrentMessage.ID);
		
		InformationCenterClient.ShowSuggestion(SuggestionID);
		
	EndIf;

	
EndProcedure

&AtClient
Procedure AllMessagesOnClick(Item)
	
	Close();
	InformationCenterClient.ShowAllNews();
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Procedure OpenAllNews()
	
	Title = NStr("en = 'Messages'");
	GenerateAllNewsList();
	Items.CommonGroup.CurrentPage = Items.NewsGroup;
	
EndProcedure

&AtServer
Procedure OpenNewsItem(ID)
	
	Items.CommonGroup.CurrentPage = Items.NewsItemGroup;
	SetPrivilegedMode(True);
	LinkToData	= Catalogs.CommonInformationCenterData.FindByAttribute("ID", ID);
	If LinkToData.IsEmpty() Then 
		Return;
	EndIf;
		
	Title = LinkToData.Description;
	
	Attachment  = LinkToData.Attachments.Get();
	HTMLText = LinkToData.HTMLText;
	
	If TypeOf(Attachment) = Type("Structure") Then 
		AttachmentStructure = Attachment;
	Else
		AttachmentStructure = New Structure;
	EndIf;
	
	Content.SetHTML(HTMLText, AttachmentStructure);
	
EndProcedure

&AtServer
Procedure GenerateAllNewsList()
	
	AllNewsTable.Clear();
	
	SetPrivilegedMode(True);
	
	ReturnValueTable = InformationCenterServer.GenerateAllNewsList();
	
	If ReturnValueTable.Index() = 0 Then 
		Return;
	EndIf;
	
	AllNewsTable.Load(ReturnValueTable);
	
	NewsGroup = Items.AllNewsGroup;
	
	For Iteration = 0 to AllNewsTable.Count() - 1 Do
		
		Criticality = AllNewsTable.Get(Iteration).Criticality;
		Description = AllNewsTable.Get(Iteration).Description;
		Picture     = ?(Criticality > 5, PictureLib.ServiceNotification, PictureLib.ServiceMessage);
		
		NewsItemGroup                = Items.Add("NewsItemGroup" + String(Iteration), Type("FormGroup"), NewsGroup);
		NewsItemGroup.Type           = FormGroupType.UsualGroup;
		NewsItemGroup.ShowTitle      = False;
		NewsItemGroup.Grouping       = ChildFormItemsGroup.Horizontal;
		NewsItemGroup.Representation = UsualGroupRepresentation.None;
		
		NewsItemPicture             = Items.Add("NewsItemPicture" + String(Iteration), Type("FormDecoration"), NewsItemGroup);
		NewsItemPicture.Type        = FormDecorationType.Picture;
		NewsItemPicture.Picture     = Picture;
		NewsItemPicture.Width       = 2;
		NewsItemPicture.Height      = 1;
		NewsItemPicture.PictureSize = PictureSize.Stretch;
		
		NewsItemName                   = Items.Add("NewsItemName" + String(Iteration), Type("FormDecoration"), NewsItemGroup);
		NewsItemName.Type              = FormDecorationType.Label;
		NewsItemName.Title             = Description;
		NewsItemName.HorizontalStretch = True;
		NewsItemName.VerticalAlign     = ItemVerticalAlign.Center;
		NewsItemName.TitleHeight       = 1;
		NewsItemName.Hyperlink         = True;
		NewsItemName.SetAction("Click", "NewsItemOnClick");
		
		If Criticality = 10 Then 
			NewsItemName.Font = New Font(, , True, , , );
		EndIf;
		
		AllNewsTable.Get(Iteration).FormItemName = "NewsItemName" + String(Iteration);
	
	EndDo;
	
EndProcedure















