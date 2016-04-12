
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	BatchModificationEnabled = False;
	DataExchangeServer.OnDetermineBatchObjectModificationUsed(BatchModificationEnabled);
	
	If Not BatchModificationEnabled Then
		
		Items.UnpostedDocumentsContextMenu.ChildItems.UnpostedDocumentsContextMenuChangeSelectedDocuments.Visible = False;
		Items.UnpostedDocumentsChangeSelectedDocuments.Visible = False;
		Items.BlankAttributesContextMenu.ChildItems.BlankAttributesContextMenuChangeSelectedObjects.Visible = False;
		Items.BlankAttributesChangeSelectedObjects.Visible = False;
		
	EndIf;
	
	EditProhibitionDatesEnabled = False;
	DataExchangeServer.OnDetermineEditProhibitionDatesUsed(EditProhibitionDatesEnabled);
	
	VersioningUsed = DataExchangeCached.VersioningUsed(, True);
	
	If Not VersioningUsed Then
		
		Conflicts.QueryText = "SELECT 1";
		DeclinedByDate.QueryText = "SELECT 1";
		Items.ConflictPage.Visible = False;
		Items.PageDeclinedByProhibitionDate.Visible = False;
		
	ElsIf Not EditProhibitionDatesEnabled Then
		
		DeclinedByDate.QueryText = "SELECT 1";
		Items.PageDeclinedByProhibitionDate.Visible = False;
		
	EndIf;
	
	// Setting dynamic list filters and storing them to an attribute for further use.
	SetUpDynamicListFilters(DynamicListFilterSettings);
	
	If CommonUseCached.DataSeparationEnabled() And VersioningUsed Then
		
		Items.ConflictsOtherVersionAuthor.Title = NStr("en = 'Object version obtained from the application'");
		
	EndIf;
	
	FillNodeList();
	
	UpdateFiltersAndIgnoredItems();
	
EndProcedure

&AtClient
Procedure OnClose()
	
	Notify("DataExchangeResultFormClosed");
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	UpdateAtServer();
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	UpdateFiltersAndIgnoredItems();
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure SearchStringOnChange(Item)
	
	UpdateFilterByReason();
	
EndProcedure

&AtClient
Procedure PeriodOnChange(Item)
	
	UpdateFilterByPeriod();
	
EndProcedure

&AtClient
Procedure InfobaseNodeClearing(Item, StandardProcessing)
	
	InfobaseNode = Undefined;
	UpdateFilterByNode();
	
EndProcedure

&AtClient
Procedure InfobaseNodeOnChange(Item)
	
	UpdateFilterByNode();
	
EndProcedure

&AtClient
Procedure InfobaseNodeStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not Items.InfobaseNode.ListChoiceMode Then
		
		StandardProcessing = False;
		
		Handler = New NotifyDescription("InfobaseNodeStartChoiceCompletion", ThisObject);
		Mode = FormWindowOpeningMode.LockOwnerWindow;
		OpenForm("CommonForm.ExchangePlanNodeSelection",,,,,, Handler, Mode);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InfobaseNodeStartChoiceCompletion(CloseResult, AdditionalParameters) Export
	
	InfobaseNode = CloseResult;
	
	UpdateFilterByNode();
	
EndProcedure

&AtClient
Procedure InfobaseNodeChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	InfobaseNode = SelectedValue;
	
EndProcedure

&AtClient
Procedure DataExchangeResultsOnCurrentPageChange(Item, CurrentPage)
	
	If Item.ChildItems.ConflictPage = CurrentPage Then
		Items.SearchString.Enabled = False;
	Else
		Items.SearchString.Enabled = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region UnpostedDocumentsFormTableItemsEventHandlers

&AtClient
Procedure UnpostedDocumentsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	OpenObject(Items.UnpostedDocuments);
	
EndProcedure

&AtClient
Procedure UnpostedDocumentsBeforeRowChange(Item, Cancel)
	
	ObjectChange();
	Cancel = True;
	
EndProcedure

#EndRegion

#Region BlankAttributesFormTableItemsEventHandlers

&AtClient
Procedure BlankAttributesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	OpenObject(Items.BlankAttributes);
	
EndProcedure

&AtClient
Procedure BlankAttributesBeforeRowChange(Item, Cancel)
	
	ObjectChange();
	Cancel = True;
	
EndProcedure

&AtClient
Procedure ConflictsBeforeRowChange(Item, Cancel)
	
	ObjectChange();
	Cancel = True;
	
EndProcedure

&AtClient
Procedure ConflictsOnActivateRow(Item)
	
	If Item.CurrentData <> Undefined Then
		
		If Item.CurrentData.OtherVersionAccepted Then
			
			ConflictReason = NStr("en = 'Conflict resolved automatically, object version from application %1 is given priority.'");
			ConflictReason = StringFunctionsClientServer.SubstituteParametersInString(ConflictReason, Item.CurrentData.OtherVersionAuthor);
			
		Else
			
			ConflictReason = NStr("en = 'Conflict resolved automatically, object version from this application is given priority.'");
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DeclinedByDateBeforeRowChange(Item, Cancel)
	
	ObjectChange();
	Cancel = True;
	
EndProcedure

&AtClient
Procedure DeclinedByDateOnActivateRow(Item)
	
	If Item.CurrentData <> Undefined Then
		
		If Item.CurrentData.NewObject Then
			
			Items.DeclinedByDateAcceptVersion.Enabled = False;
			
		Else
			
			Items.DeclinedByDateAcceptVersion.Enabled = True;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Change(Command)
	
	ObjectChange();
	
EndProcedure

&AtClient
Procedure IgnoreDocument(Command)
	
	Ignore(Items.UnpostedDocuments.SelectedRows, True, "UnpostedDocuments");
	
EndProcedure

&AtClient
Procedure NotIgnoreDocument(Command)
	
	Ignore(Items.UnpostedDocuments.SelectedRows, False, "UnpostedDocuments");
	
EndProcedure

&AtClient
Procedure NotIgnoreObject(Command)
	
	Ignore(Items.BlankAttributes.SelectedRows, False, "BlankAttributes");
	
EndProcedure

&AtClient
Procedure IgnoreObject(Command)
	
	Ignore(Items.BlankAttributes.SelectedRows, True, "BlankAttributes");
	
EndProcedure

&AtClient
Procedure ChangeSelectedDocuments(Command)
	
	DataExchangeClient.OnChangeSelectedObjects(Items.UnpostedDocuments);
	
EndProcedure

&AtClient
Procedure Refresh(Command)
	
	UpdateAtServer();
	
EndProcedure

&AtClient
Procedure PostDocument(Command)
	
	ClearMessages();
	PostDocuments(Items.UnpostedDocuments.SelectedRows);
	UpdateAtServer("UnpostedDocuments");
	
EndProcedure

&AtClient
Procedure ChangeSelectedObjects(Command)
	
	DataExchangeClient.OnChangeSelectedObjects(Items.BlankAttributes);
	
EndProcedure

&AtClient
Procedure ShowDifferencesNotAccepted(Command)
	
	ShowDifferences(Items.DeclinedByDate);
	
EndProcedure

&AtClient
Procedure OpenVersionNotAccepted(Command)
	
	If Items.DeclinedByDate.CurrentData = Undefined Then
		Return;
	EndIf;
	
	ComparedVersions = New Array;
	ComparedVersions.Add(Items.DeclinedByDate.CurrentData.OtherVersionNumber);
	DataExchangeClient.OnOpenReportFormByVersion(Items.DeclinedByDate.CurrentData.Ref, ComparedVersions);
	
EndProcedure

&AtClient
Procedure OpenVersionNotAcceptedInThisApplication(Command)
	
	If Items.DeclinedByDate.CurrentData = Undefined Then
		Return;
	EndIf;
	
	ComparedVersions = New Array;
	ComparedVersions.Add(Items.DeclinedByDate.CurrentData.ThisVersionNumber);
	DataExchangeClient.OnOpenReportFormByVersion(Items.DeclinedByDate.CurrentData.Ref, ComparedVersions);

EndProcedure

&AtClient
Procedure ShowConflictDifference(Command)
	
	ShowDifferences(Items.Conflicts);
	
EndProcedure

&AtClient
Procedure IgnoreConflict(Command)
	
	IgnoreVersion(Items.Conflicts.SelectedRows, True, "Conflicts");
	
EndProcedure

&AtClient
Procedure IgnoreNotAccepted(Command)
	
	IgnoreVersion(Items.DeclinedByDate.SelectedRows, True, "DeclinedByDate");
	
EndProcedure

&AtClient
Procedure NotIgnoreConflict(Command)
	
	IgnoreVersion(Items.Conflicts.SelectedRows, False, "Conflicts");
	
EndProcedure

&AtClient
Procedure NotIgnoreNotAccepted(Command)
	
	IgnoreVersion(Items.DeclinedByDate.SelectedRows, False, "DeclinedByDate");
	
EndProcedure

&AtClient
Procedure AcceptVersionNotAccepted(Command)
	
	NotifyDescription = New NotifyDescription("AcceptVersionNotAcceptedCompletion", ThisObject);
	ShowQueryBox(NotifyDescription, NStr("en = 'Do you want to accept the version even though import is prohibited?'"), QuestionDialogMode.YesNo, , DialogReturnCode.No);
	
EndProcedure

&AtClient
Procedure AcceptVersionNotAcceptedCompletion(Answer, AdditionalParameters) Export
	
	If Answer = DialogReturnCode.Yes Then
		AcceptRejectVersionAtServer(Items.DeclinedByDate.SelectedRows, "DeclinedByDate");
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenVersionUpBeforeConflict(Command)
	
	CurrentData = Items.Conflicts.CurrentData;
	OpenVersionAtClient(Items.Conflicts.CurrentData, CurrentData.ThisVersionNumber);
	
EndProcedure

&AtClient
Procedure OpenConflictVersion(Command)
	
	CurrentData = Items.Conflicts.CurrentData;
	OpenVersionAtClient(Items.Conflicts.CurrentData, CurrentData.OtherVersionNumber);
	
EndProcedure

&AtClient
Procedure ShowIgnoredConflicts(Command)
	
	ShowIgnoredConflicts = Not ShowIgnoredConflicts;
	ShowIgnoredConflictsAtServer();
	
EndProcedure

&AtClient
Procedure ShowIgnoredBlank(Command)
	
	ShowIgnoredBlank = Not ShowIgnoredBlank;
	ShowIgnoredBlankAtServer();
	
EndProcedure

&AtClient
Procedure ShowIgnoredNotAccepted(Command)
	
	ShowIgnoredNotAccepted = Not ShowIgnoredNotAccepted;
	ShowIgnoredNotAcceptedAtServer();
	
EndProcedure

&AtClient
Procedure ShowIgnoredUnposted(Command)
	
	ShowIgnoredUnposted = Not ShowIgnoredUnposted;
	ShowIgnoredUnpostedAtServer();
	
EndProcedure

&AtClient
Procedure ChangeConflictResult(Command)
	
	If Items.Conflicts.CurrentData <> Undefined Then
		
		If Items.Conflicts.CurrentData.OtherVersionAccepted Then
			
			QuestionText = NStr("en = 'Do you want to replace the object version from another application with the object version from this application?'");
			
		Else
			
			QuestionText = NStr("en = 'Do you want to replace the object version from this application with the object version from another application?'");
			
		EndIf;
		
		NotifyDescription = New NotifyDescription("ChangeConflictResultCompletion", ThisObject);
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeConflictResultCompletion(Answer, AdditionalParameters) Export
	
	If Answer = DialogReturnCode.Yes Then
		
		AcceptRejectVersionAtServer(Items.Conflicts.SelectedRows, "Conflicts");
		
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure Ignore(Val SelectedRows, Ignore, ItemName)
	
	For Each SelectedRow In SelectedRows Do
		
		If TypeOf(SelectedRow) = Type("DynamicalListGroupRow") Then
			Continue;
		EndIf;
	
		InformationRegisters.DataExchangeResults.Ignore(SelectedRow.ProblematicObjects, SelectedRow.ProblemType, Ignore);
	
	EndDo;
	
	UpdateAtServer(ItemName);
	
EndProcedure

&AtServer
Procedure ShowIgnoredConflictsAtServer(Update= True)
	
	Items.ConflictsShowIgnoredConflicts.Check = ShowIgnoredConflicts;
	CommonUseClientServer.SetDynamicListFilterItem(
		Conflicts,
		"VersionIgnored",
		,
		,
		,
		Not ShowIgnoredConflicts);
	
	If Update Then
		
		UpdateAtServer("Conflicts");
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ShowIgnoredBlankAtServer(Update= True)
	
	Items.BlankAttributesShowIgnoredBlank.Check = ShowIgnoredBlank;
	CommonUseClientServer.SetDynamicListFilterItem(
		BlankAttributes,
		"Skipped",
		,
		,
		,
		Not ShowIgnoredBlank);
	
	If Update Then
		
		UpdateAtServer("BlankAttributes");
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ShowIgnoredNotAcceptedAtServer(Update= True)
	
	Items.DeclinedByDateShowIgnoredNotAccepted.Check = ShowIgnoredNotAccepted;
	CommonUseClientServer.SetDynamicListFilterItem(
		DeclinedByDate,
		"VersionIgnored",
		,
		,
		,
		Not ShowIgnoredNotAccepted);
	
	If Update Then
		
		UpdateAtServer("DeclinedByDate");
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ShowIgnoredUnpostedAtServer(Update= True)
	
	Items.UnpostedDocumentsShowIgnoredUnposted.Check = ShowIgnoredUnposted;
	CommonUseClientServer.SetDynamicListFilterItem(
		UnpostedDocuments,
		"Skipped",
		,
		,
		,
		Not ShowIgnoredUnposted);
	
	If Update Then
		
		UpdateAtServer("UnpostedDocuments");
		
	EndIf;
	
EndProcedure

&AtServer
Procedure PostDocuments(Val SelectedRows)
	
	For Each SelectedRow In SelectedRows Do
		
		If TypeOf(SelectedRow) = Type("DynamicalListGroupRow") Then
			Continue;
		EndIf;
		
		DocumentObject = SelectedRow.ProblematicObjects.GetObject();
		
		If DocumentObject.CheckFilling() Then
			
			DocumentObject.Write(DocumentWriteMode.Posting);
			
		EndIf;
	
	EndDo;
	
EndProcedure

&AtServer
Procedure FillNodeList()
	
	NoExchangeByRules = True;
	ContextOpening = ValueIsFilled(Parameters.ExchangeNodes);
	
	ExchangeNodes = ?(ContextOpening, Parameters.ExchangeNodes, NodeArrayOnOpenOutOfContext());
	Items.InfobaseNode.ChoiceList.LoadValues(ExchangeNodes);
	
	For Each ExchangeNode In ExchangeNodes Do
		
		If DataExchangeCached.IsUniversalDataExchangeNode(ExchangeNode) Then
			
			NoExchangeByRules = False;
			
		EndIf;
		
	EndDo;
	
	If ContextOpening Then
		
		SetFilterByNodes(ExchangeNodes);
		NodeList = New ValueList;
		NodeList.LoadValues(ExchangeNodes);
		
	EndIf;
	
	If ContextOpening And ExchangeNodes.Count() = 1 Then
		
		InfobaseNode = Undefined;
		Items.InfobaseNode.Visible = False;
		Items.UnpostedDocumentsInfobaseNode.Visible = False;
		Items.BlankAttributesInfobaseNode.Visible = False;
		
		If VersioningUsed Then
			Items.ConflictsOtherVersionAuthor.Visible = False;
			Items.DeclinedByDateOtherVersionAuthor.Visible = False;
		EndIf;
		
	ElsIf ExchangeNodes.Count() >= 7 Then
		
		Items.InfobaseNode.ListChoiceMode = False;
		
	EndIf;
	
	If ContextOpening And NoExchangeByRules Then
		Title = NStr("en = 'Data synchronization conflicts'");
		Items.SearchString.Visible = False;
		Items.DataExchangeResults.CurrentPage = Items.DataExchangeResults.ChildItems.ConflictPage;
		Items.DataExchangeResults.PagesRepresentation = FormPagesRepresentation.None;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetFilterByNodes(ExchangeNodes)
	
	FilterByNodesDocument = DynamicListFilterItem(UnpostedDocuments,
		DynamicListFilterSettings.UnpostedDocuments.NodeInList);
	FilterByNodesDocument.Use = True;
	FilterByNodesDocument.RightValue = ExchangeNodes;
	
	FilterByNodesObject = DynamicListFilterItem(BlankAttributes,
		DynamicListFilterSettings.BlankAttributes.NodeInList);
	FilterByNodesObject.Use = True;
	FilterByNodesObject.RightValue = ExchangeNodes;
	
	If VersioningUsed Then
		
		FilterByNodesConflict = DynamicListFilterItem(Conflicts,
			DynamicListFilterSettings.Conflicts.AuthorInList);
		FilterByNodesConflict.Use = True;
		FilterByNodesConflict.RightValue = ExchangeNodes;
		
		FilterByNodesNotAccepted = DynamicListFilterItem(DeclinedByDate,
			DynamicListFilterSettings.DeclinedByDate.AuthorInList);
		FilterByNodesNotAccepted.Use = True;
		FilterByNodesNotAccepted.RightValue = ExchangeNodes;
		
	EndIf;
	
EndProcedure

&AtServer
Function NodeArrayOnOpenOutOfContext()
	
	ExchangeNodes = New Array;
	
	ExchangePlanList = DataExchangeCached.SLExchangePlans();
	
	For Each ExchangePlanName In ExchangePlanList Do
		
		If Not AccessRight("Read", ExchangePlans[ExchangePlanName].EmptyRef().Metadata()) Then
			Continue;
		EndIf;	
		Query = New Query;
		Query.SetParameter("ThisNode", ExchangePlans[ExchangePlanName].ThisNode());
		Query.Text =
		"SELECT ALLOWED
		|	ExchangePlanTable.Ref AS ExchangeNode
		|FROM
		|	&ExchangePlanTable AS ExchangePlanTable
		|WHERE
		|	ExchangePlanTable.Ref <> &ThisNode
		|	AND ExchangePlanTable.Ref.DeletionMark = FALSE
		|
		|ORDER BY
		|	Presentation";
		Query.Text = StrReplace(Query.Text, "&ExchangePlanTable", "ExchangePlan." + ExchangePlanName);
		
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			
			ExchangeNodes.Add(Selection.ExchangeNode);
			
		EndDo;
		
	EndDo;
	
	Return ExchangeNodes;
	
EndFunction

&AtServer
Procedure UpdateFilterByNode(Update = True)
	
	Use = ValueIsFilled(InfobaseNode);
	
	FilterByNodeDocument = DynamicListFilterItem(UnpostedDocuments,
		DynamicListFilterSettings.UnpostedDocuments.NodeEqual);
	FilterByNodeDocument.Use = Use;
	FilterByNodeDocument.RightValue = InfobaseNode;
	
	FilterByNodeObject = DynamicListFilterItem(BlankAttributes,
		DynamicListFilterSettings.BlankAttributes.NodeEqual);
	FilterByNodeObject.Use = Use;
	FilterByNodeObject.RightValue = InfobaseNode;
	
	If VersioningUsed Then
		
		FilterByNodeConflicts = DynamicListFilterItem(Conflicts,
			DynamicListFilterSettings.Conflicts.AuthorEqual);
		FilterByNodeConflicts.Use = Use;
		FilterByNodeConflicts.RightValue = InfobaseNode;
		
		FilterByNodeNotAccepted = DynamicListFilterItem(DeclinedByDate,
			DynamicListFilterSettings.DeclinedByDate.AuthorEqual);
		FilterByNodeNotAccepted.Use = Use;
		FilterByNodeNotAccepted.RightValue = InfobaseNode;
		
	EndIf;
	
	If Update Then
		UpdateAtServer();
	EndIf;
EndProcedure

&AtServer
Function NotAcceptedCount()
	
	ExchangeNodes = ?(ValueIsFilled(InfobaseNode), InfobaseNode, NodeList);
	
	Return DataExchangeServer.VersioningIssueCount(ExchangeNodes, False,
		ShowIgnoredConflicts, Period, SearchString);
	
EndFunction

&AtServer
Function ConflictCount()
	
	ExchangeNodes = ?(ValueIsFilled(InfobaseNode), InfobaseNode, NodeList);
	
	Return DataExchangeServer.VersioningIssueCount(ExchangeNodes, True,
		ShowIgnoredConflicts, Period, SearchString);
	
EndFunction

&AtServer
Function BlankAttributeCount()
	
	ExchangeNodes = ?(ValueIsFilled(InfobaseNode), InfobaseNode, NodeList);
	
	Return InformationRegisters.DataExchangeResults.IssueCount(ExchangeNodes, Enums.DataExchangeProblemTypes.BlankAttributes,
		ShowIgnoredBlank, Period, SearchString);
	
EndFunction

&AtServer
Function UnpostedDocumentCount()
	
	ExchangeNodes = ?(ValueIsFilled(InfobaseNode), InfobaseNode, NodeList);
	
	Return InformationRegisters.DataExchangeResults.IssueCount(ExchangeNodes, Enums.DataExchangeProblemTypes.UnpostedDocument,
		ShowIgnoredUnposted, Period, SearchString);
	
EndFunction

&AtServer
Procedure SetPageTitle(Page, Title, Count)
	
	AdditionalString = ?(Count > 0, " (" + Count + ")", "");
	Title = Title + AdditionalString;
	Page.Title = Title;
	
EndProcedure

&AtClient
Procedure OpenObject(Item)
	
	If Item.CurrentRow = Undefined OR TypeOf(Item.CurrentRow) = Type("DynamicalListGroupRow") Then
		ShowMessageBox(, NStr("en = 'Cannot execute the command for the specified object.'"));
		Return;
	Else
		ShowValue(, Item.CurrentData.Ref);
	EndIf;
	
EndProcedure

&AtClient
Procedure ObjectChange()
	
	ResultPages = Items.DataExchangeResults;
	
	If ResultPages.CurrentPage = ResultPages.ChildItems.PageUnpostedDocuments Then
		
		OpenObject(Items.UnpostedDocuments); 
		
	ElsIf ResultPages.CurrentPage = ResultPages.ChildItems.PageBlankAttributes Then
		
		OpenObject(Items.BlankAttributes);
		
	ElsIf ResultPages.CurrentPage = ResultPages.ChildItems.ConflictPage Then
		
		OpenObject(Items.Conflicts);
		
	ElsIf ResultPages.CurrentPage = ResultPages.ChildItems.PageDeclinedByProhibitionDate Then
		
		OpenObject(Items.DeclinedByDate);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowDifferences(Item)
	
	If Item.CurrentData = Undefined Then
		Return;
	EndIf;
	
	ComparedVersions = New Array;
	
	If Item.CurrentData.ThisVersionNumber <> 0 Then
		ComparedVersions.Add(Item.CurrentData.ThisVersionNumber);
	EndIf;
	
	If Item.CurrentData.OtherVersionNumber <> 0 Then
		ComparedVersions.Add(Item.CurrentData.OtherVersionNumber);
	EndIf;
	
	If ComparedVersions.Count() <> 2 Then
		
		CommonUseClientServer.MessageToUser(NStr("en = 'No object version to compare.'"));
		Return;
		
	EndIf;
	
	DataExchangeClient.OnOpenReportFormByVersion(Item.CurrentData.Ref, ComparedVersions);
	
EndProcedure

&AtServer
Procedure UpdateFilterByReason(Update = True)
	
	SearchStringSpecified = ValueIsFilled(SearchString);
	
	CommonUseClientServer.SetDynamicListFilterItem(
		UnpostedDocuments, "Reason", SearchString,,, SearchStringSpecified);
	
	CommonUseClientServer.SetDynamicListFilterItem(
		BlankAttributes, "Reason", SearchString,,, SearchStringSpecified);
		
	If VersioningUsed Then
	
		CommonUseClientServer.SetDynamicListFilterItem(
			DeclinedByDate, "ProhibitionReason", SearchString,,, SearchStringSpecified);
		
	EndIf;
	
	If Update Then
		
		UpdateAtServer();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateFilterByPeriod(Update = True)
	
	Use = ValueIsFilled(Period);
	
	// Documents that are not posted
	FilterByPeriodDocumentFrom = DynamicListFilterItem(UnpostedDocuments,
		DynamicListFilterSettings.UnpostedDocuments.StartDate);
	FilterByPeriodDocumentTo = DynamicListFilterItem(UnpostedDocuments,
		DynamicListFilterSettings.UnpostedDocuments.EndDate);
		
	FilterByPeriodDocumentFrom.Use  = Use;
	FilterByPeriodDocumentTo.Use = Use;
	
	FilterByPeriodDocumentFrom.RightValue  = Period.StartDate;
	FilterByPeriodDocumentTo.RightValue = Period.EndDate;
	
	// Blank attributes
	FilterByPeriodObjectFrom = DynamicListFilterItem(BlankAttributes,
		DynamicListFilterSettings.BlankAttributes.StartDate);
	FilterByPeriodObjectTo = DynamicListFilterItem(BlankAttributes,
		DynamicListFilterSettings.BlankAttributes.EndDate);
		
	FilterByPeriodObjectFrom.Use  = Use;
	FilterByPeriodObjectTo.Use    = Use;
	
	FilterByPeriodObjectFrom.RightValue  = Period.StartDate;
	FilterByPeriodObjectTo.RightValue    = Period.EndDate;
	
	If VersioningUsed Then
		
		FilterByPeriodConflictsFrom = DynamicListFilterItem(Conflicts,
			DynamicListFilterSettings.Conflicts.StartDate);
		FilterByPeriodConflictTo = DynamicListFilterItem(Conflicts,
			DynamicListFilterSettings.Conflicts.EndDate);
		
		FilterByPeriodConflictsFrom.Use  = Use;
		FilterByPeriodConflictTo.Use     = Use;
		
		FilterByPeriodConflictsFrom.RightValue  = Period.StartDate;
		FilterByPeriodConflictTo.RightValue     = Period.EndDate;
		
		FilterByPeriodNotAcceptedFrom = DynamicListFilterItem(DeclinedByDate,
			DynamicListFilterSettings.DeclinedByDate.StartDate);
		FilterByPeriodNotAcceptedTo = DynamicListFilterItem(DeclinedByDate,
			DynamicListFilterSettings.DeclinedByDate.EndDate);
		
		FilterByPeriodNotAcceptedFrom.Use  = Use;
		FilterByPeriodNotAcceptedTo.Use    = Use;
		
		FilterByPeriodNotAcceptedFrom.RightValue  = Period.StartDate;
		FilterByPeriodNotAcceptedTo.RightValue    = Period.EndDate;
		
	EndIf;
	
	If Update Then
		UpdateAtServer();
	EndIf;
EndProcedure

&AtServer
Procedure IgnoreVersion(Val SelectedRows, Ignore, ItemName)
	
	For Each SelectedRow In SelectedRows Do
		
		If TypeOf(SelectedRow) = Type("DynamicalListGroupRow") Then
			Continue;
		EndIf;
		
		DataExchangeServer.OnIgnoreObjectVersion(SelectedRow.Object, SelectedRow.VersionNumber, Ignore);
		
	EndDo;
	
	UpdateAtServer(ItemName);
	
EndProcedure

&AtServer
Procedure UpdateAtServer(UpdatedItem = "")
	
	UpdateFormLists(UpdatedItem);
	UpdatePageTitles();
	
EndProcedure

&AtServer
Procedure UpdateFormLists(UpdatedItem)
	
	If ValueIsFilled(UpdatedItem) Then
		
		Items[UpdatedItem].Refresh();
		
	Else
		
		Items.UnpostedDocuments.Refresh();
		Items.BlankAttributes.Refresh();
		If VersioningUsed Then
			Items.Conflicts.Refresh();
			Items.DeclinedByDate.Refresh();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdatePageTitles()
	
	SetPageTitle(Items.PageUnpostedDocuments, NStr("en= 'Documents that are not posted'"), UnpostedDocumentCount());
	SetPageTitle(Items.PageBlankAttributes, NStr("en= 'Blank attributes'"), BlankAttributeCount());
	
	If VersioningUsed Then
		SetPageTitle(Items.ConflictPage, NStr("en= 'Conflicts'"), ConflictCount());
		SetPageTitle(Items.PageDeclinedByProhibitionDate, NStr("en= 'Declined by prohibition date'"), NotAcceptedCount());
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenVersionAtClient(CurrentData, Version)
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	ComparedVersions = New Array;
	ComparedVersions.Add(Version);
	DataExchangeClient.OnOpenReportFormByVersion(CurrentData.Ref, ComparedVersions);
	
EndProcedure

&AtServer
Procedure AcceptRejectVersionAtServer(Val SelectedRows, ItemName)
	
	For Each SelectedRow In SelectedRows Do
		
		If TypeOf(SelectedRow) = Type("DynamicalListGroupRow") Then
			Continue;
		EndIf;
		
		DataExchangeServer.OnStartUsingNewObjectVersion(SelectedRow.Object, SelectedRow.VersionNumber);
		
	EndDo;
	
	UpdateAtServer(ItemName);
	
EndProcedure

&AtServer
Procedure SetUpDynamicListFilters(Result)
	
	Result = New Structure;
	
	// Documents that are not posted
	Filter = UnpostedDocuments.SettingsComposer.Settings.Filter;
	Result.Insert("UnpostedDocuments", New Structure);
	Settings = Result.UnpostedDocuments;
	
	Settings.Insert("Skipped", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "Skipped", DataCompositionComparisonType.Equal, False, ,True)));
	Settings.Insert("StartDate", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "OccurrenceDate", DataCompositionComparisonType.GreaterOrEqual, '00010101', , True)));
	Settings.Insert("EndDate", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "OccurrenceDate", DataCompositionComparisonType.LessOrEqual, '00010101', , True)));
	Settings.Insert("NodeEqual", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "InfobaseNode", DataCompositionComparisonType.Equal, Undefined, , False)));
	Settings.Insert("Reason", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "Reason", DataCompositionComparisonType.Contains, Undefined, , False)));
	Settings.Insert("NodeInList", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "InfobaseNode", DataCompositionComparisonType.InList, Undefined, , False)));
		
	// Blank attributes
	Filter = BlankAttributes.SettingsComposer.Settings.Filter;
	Result.Insert("BlankAttributes", New Structure);
	Settings = Result.BlankAttributes;
	
	Settings.Insert("Skipped", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "Skipped", DataCompositionComparisonType.Equal, False, ,True)));
	Settings.Insert("StartDate", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "OccurrenceDate", DataCompositionComparisonType.GreaterOrEqual, '00010101', , True)));
	Settings.Insert("EndDate", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "OccurrenceDate", DataCompositionComparisonType.LessOrEqual, '00010101', , True)));
	Settings.Insert("NodeEqual", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "InfobaseNode", DataCompositionComparisonType.Equal, Undefined, , False)));
	Settings.Insert("Reason", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "Reason", DataCompositionComparisonType.Contains, Undefined, , False)));
	Settings.Insert("NodeInList", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "InfobaseNode", DataCompositionComparisonType.InList, Undefined, , False)));
		
	If VersioningUsed Then
		
		// Conflicts
		Filter = Conflicts.SettingsComposer.Settings.Filter;
		Result.Insert("Conflicts", New Structure);
		Settings = Result.Conflicts;
		
		Settings.Insert("AuthorEqual", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "OtherVersionAuthor", DataCompositionComparisonType.Equal, Undefined, ,False)));
		Settings.Insert("StartDate", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "Date", DataCompositionComparisonType.GreaterOrEqual, '00010101', , True)));
		Settings.Insert("EndDate", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "Date", DataCompositionComparisonType.LessOrEqual, '00010101', , True)));
		Settings.Insert("VersionIgnored", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "VersionIgnored", DataCompositionComparisonType.Equal, False, , True)));
		Settings.Insert("AuthorInList", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "OtherVersionAuthor", DataCompositionComparisonType.InList, Undefined, ,False)));
		
		// Declined by prohibition date
		Filter = DeclinedByDate.SettingsComposer.Settings.Filter;
		Result.Insert("DeclinedByDate", New Structure);
		Settings = Result.DeclinedByDate;
		
		Settings.Insert("AuthorEqual", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "OtherVersionAuthor", DataCompositionComparisonType.Equal, Undefined, ,False)));
		Settings.Insert("StartDate", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "Date", DataCompositionComparisonType.GreaterOrEqual, '00010101', , True)));
		Settings.Insert("EndDate", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "Date", DataCompositionComparisonType.LessOrEqual, '00010101', , True)));
		Settings.Insert("ProhibitionReason", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "ProhibitionReason", DataCompositionComparisonType.Equal, Undefined, , False)));
		Settings.Insert("VersionIgnored", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "VersionIgnored", DataCompositionComparisonType.Equal, False, , True)));
		Settings.Insert("AuthorInList", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "OtherVersionAuthor", DataCompositionComparisonType.InList, Undefined, ,False)));
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function DynamicListFilterItem(Val DynamicList, Val ID)
	Return DynamicList.SettingsComposer.Settings.Filter.GetObjectByID(ID);
EndFunction

&AtServer
Procedure UpdateFiltersAndIgnoredItems()
	
	UpdateFilterByPeriod(False);
	UpdateFilterByNode(False);
	UpdateFilterByReason(False);
	
	ShowIgnoredUnpostedAtServer(False);
	ShowIgnoredBlankAtServer(False);
	
	If VersioningUsed Then
		
		ShowIgnoredConflictsAtServer(False);
		ShowIgnoredNotAcceptedAtServer(False);
		
	EndIf;
	
	UpdateAtServer();
	
	If Not Items.DataExchangeResults.CurrentPage = Items.DataExchangeResults.ChildItems.ConflictPage Then
		
		For Each Page In Items.DataExchangeResults.ChildItems Do
			
			If Find(Page.Title, "(") Then
				Items.DataExchangeResults.CurrentPage = Page;
				Break;
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion