
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	InfobaseConnectionString = InfobaseConnectionString();
	IsFileInfobase = CommonUse.FileInfobase(InfobaseConnectionString);
	Items.GroupIndexUpdate.Visible = IsFileInfobase;
	If IsFileInfobase Then
		UpdateIndexTrue();
	EndIf;
	
	CurrentPosition = 0;
	
	Items.Next.Enabled = False;
	Items.Back.Enabled = False;
	
	Array = CommonUse.CommonSettingsStorageLoad("FullTextSearchFullTextSearchStrings");
	
	If Array <> Undefined Then
		Items.SearchString.ChoiceList.LoadValues(Array);
	EndIf;
	
	If Not IsBlankString(Parameters.PassedSearchString) Then
		SearchString = Parameters.PassedSearchString;
		
		SaveSearchString(Items.SearchString.ChoiceList, SearchString);
		Try
			Result = SearchServer(0, CurrentPosition, SearchString);
		Except	
			CommonUseClientServer.MessageToUser(BriefErrorDescription(ErrorInfo()));
			Return;
		EndTry;
		
		SearchResults = Result.SearchResult;
		HTMLText = Result.HTMLText;
		CurrentPosition = Result.CurrentPosition;
		TotalCount = Result.TotalCount;
		
		If SearchResults.Count() <> 0 Then
			
			ShowingResultsFromTo = StringFunctionsClientServer.SubstituteParametersInString(
			                            NStr("en = 'Showing results %1 - %2 of %3'"),
			                            String(CurrentPosition + 1),
			                            String(CurrentPosition + SearchResults.Count()),
			                            String(TotalCount) );
			
			Items.Next.Enabled = (TotalCount - CurrentPosition) > SearchResults.Count();
			Items.Back.Enabled = (CurrentPosition > 0);
		Else
			ShowingResultsFromTo = NStr("en = 'The search returned no results'");
			Items.Next.Enabled = False;
			Items.Back.Enabled = False;
		EndIf;
	Else
		HTMLText = 
		"<html>
		|<head>
		|<meta http-equiv=""Content-Style-Type"" content=""text/css"">
		|</head>
		|<body topmargin=0 leftmargin=0 scroll=auto>
		|<table border=""0"" width=""100%"" cellspacing=""5"">
		|</table>
		|</body>
		|</html>";
	EndIf;	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure SearchStringOnChange(Item)
	
	Cancel = False;
	
	Search(0, Cancel);
	
	If Not Cancel Then
		CurrentItem = Items.SearchString;
	EndIf;
	
EndProcedure

&AtClient
Procedure SearchStringChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	StandardProcessing = False;
	SearchString = SelectedValue;
	Search(0);
	
EndProcedure

&AtClient
Procedure HTMLTextOnClick(Item, EventData, StandardProcessing)
	HTMLElement = EventData.Anchor;
	
	If HTMLElement = Undefined Then
		Return;
	EndIf;
	
	If (HTMLElement.ID = "FullTextSearchListItem") Then
		StandardProcessing = False;
		
		URLPart = HTMLElement.outerHTML;
		Position = Find(URLPart, "sel_num=");
		URLPartClipped = Mid(URLPart, Position + 9);
		PositionEnd = Find(URLPartClipped, """");
		If PositionEnd = 0 Then
			PositionEnd = Find(URLPartClipped, "'");
			If PositionEnd = 0 Then
				PositionEnd = 2;
			EndIf;
		EndIf;
		If Position <> 0 Then
			URLPart = Mid(URLPartClipped, 1, PositionEnd - 1);
		EndIf;
			
		NumberInList = Number(URLPart);
		ResultStructure = SearchResults[NumberInList].Value;
		SelectedRow = ResultStructure.Value;
		ObjectArray = ResultStructure.ValuesToOpen;
		
		If ObjectArray.Count() = 1 Then
			OpenSearchValue(ObjectArray[0]);
		ElsIf ObjectArray.Count() <> 0 Then
			List = New ValueList;
			For Each ArrayElement In ObjectArray Do
				List.Add(ArrayElement);
			EndDo;
			
			Handler = New NotifyDescription("HTMLTextOnClickAfterSelectFromList", ThisObject);
			ShowChooseFromList(Handler, List, Items.HTMLText);
		EndIf;
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ExecuteSearch(Command)
	
	Search(0);
	
EndProcedure

&AtClient
Procedure Next(Command)
	
	Search(1);
	
EndProcedure

&AtClient
Procedure Previous(Command)
	
	Search(-1);
	
EndProcedure

&AtClient
Procedure UpdateIndex(Command)
	
	Status(NStr("en = 'Updating full-text search index...
	|Please wait.'"));
	
	UpdateIndexServer();
	
	Status(NStr("en = 'Full-text search index updated.'"));
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure OpenSearchValue(Value)
	
	ShowValue(, Value);

EndProcedure
 
// Searches, gets the result, and displays it.
&AtClient
Procedure Search(Heading, Cancel = Undefined)	
	
	If IsBlankString(SearchString) Then
		CommonUseClientServer.MessageToUser(NStr("en = 'Enter the search string.'"), , "SearchString");
		Cancel = True;
		Return;
	EndIf;
	
	IsURL = Find(SearchString, "e1cib/data/") <> 0;
	If IsURL Then
		GotoURL(SearchString);
		SearchString = "";
		Return;
	EndIf;
	
	Status(StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Searching for ""%1""...'"), SearchString));
	
	ChoiceList = Items.SearchString.ChoiceList.Copy();
	Result = SaveStringAndSearchAtServer(Heading, CurrentPosition, SearchString, ChoiceList);
	Items.SearchString.ChoiceList.Clear();
	For Each ChoiceListItem In ChoiceList Do
		Items.SearchString.ChoiceList.Add(ChoiceListItem.Value, ChoiceListItem.Presentation);
	EndDo;
	
	If Items.GroupIndexUpdate.Visible Then
		UpdateIndexTrue();
	EndIf;
	
	SearchResults = Result.SearchResult;
	HTMLText = Result.HTMLText;
	CurrentPosition = Result.CurrentPosition;
	TotalCount = Result.TotalCount;
	
	If SearchResults.Count() > 0 Then
		
		ShowingResultsFromTo = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Showing results %1 - %2 of %3.'"),
			Format(CurrentPosition + 1, "NZ=0;NG="),
			Format(CurrentPosition + SearchResults.Count(), "NZ=0;NG="),
			Format(TotalCount, "NZ=0;NG="));
		
		Items.Next.Enabled = (TotalCount - CurrentPosition) > SearchResults.Count();
		Items.Back.Enabled = (CurrentPosition > 0);
		
		If Heading = 0 And Result.CurrentPosition = 0 And Result.TooManyResults Then
			ShowMessageBox(, NStr("en = 'Too many results, narrow your search.'"));
		EndIf;
	
	Else
		
		ShowingResultsFromTo = NStr("en = 'The search returned no results.'");
		
		Items.Next.Enabled = False;
		Items.Back.Enabled = False;
		
		SearchText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'The string ""%1"" is not found.<br><br>
			|<b>Try one of the following:</b>
			|<li>Check the spelling.
			|<li>Use different keywords.
			|<li>Reduce the number of keywords.'"),
			TrimAll(SearchString));
		
		HTMLText = 
		"<html>
		|<head>
		|<meta http-equiv=""Content-Style-Type""
		|content=""text/css""> <style>H1
		|{ TEXT-ALIGN: left; FONT-FAMILY: Arial, Tahoma; COLOR: #003366; FONT-SIZE: 18pt;
		|FONT-WEIGHT:
		|bold }
		|.Programtext { FONT-FAMILY: Courier; COLOR: #000080;
		|FONT-SIZE:
		|10pt
		|} H3 { TEXT-ALIGN: left; FONT-FAMILY: Arial, Tahoma; FONT-SIZE:
		|11pt;
		|FONT-WEIGHT: bold
		|} H4 { TEXT-ALIGN: left; FONT-FAMILY: Arial, Tahoma; FONT-SIZE:
		|10pt;
		|FONT-WEIGHT: bold
		|} BODY { FONT-FAMILY:
		|Verdana;
		|FONT-SIZE:
		|8pt }</style> </head> <body scroll=auto>
		|" + SearchText + "
		|</body>
		|</html>";
		
	EndIf;
	
EndProcedure
 
// Returns an array of objects for displaying to the user, the array can contain a single element.
&AtServerNoContext
Function GetValuesToOpen(Object)
	Result = New Array;
	
	// Object of reference type.
	If CommonUse.ReferenceTypeValue(Object) Then
		Result.Add(Object);
		Return Result;
	EndIf;
	
	ObjectMetadata = Metadata.FindByType(TypeOf(Object));
	MetadataName = ObjectMetadata.Name;
	
	FullObjectName = Upper(Metadata.FindByType(TypeOf(Object)).FullName());
	IsInformationRegister = (Find(FullObjectName, "INFORMATIONREGISTER.") > 0);

	If Not IsInformationRegister Then // Accounting or accumulation or calculation register
		Recorder = Object["Recorder"];
		Result.Add(Recorder);
		Return Result;
	EndIf;

	// This part is for information registers.
	If ObjectMetadata.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.RecorderSubordinate Then
		Recorder = Object["Recorder"];
		Result.Add(Recorder);
		Return Result;
	EndIf;

	// Independent information register 
	// Main types first
	For Each Dimension In ObjectMetadata.Dimensions Do
		If Dimension.Master Then 
			DimensionValue = Object[Dimension.Name];
			
			If CommonUse.ReferenceTypeValue(DimensionValue) Then
				Result.Add(DimensionValue);
			EndIf;
			
		EndIf;
	EndDo;

	If Result.Count() = 0 Then
		// Then any types
		For Each Dimension In ObjectMetadata.Dimensions Do
			If Dimension.Master Then 
				DimensionValue = Object[Dimension.Name];
				Result.Add(DimensionValue);
			EndIf;
		EndDo;
	EndIf;
	
	// If there are no master dimensions, return information register key.
	If Result.Count() = 0 Then
		Result.Add(Object);
	EndIf;

	Return Result;
EndFunction 

&AtServer
Procedure UpdateIndexServer()
  // Accelerating full-text search index update
	SetPrivilegedMode(True);
	FullTextSearch.UpdateIndex(False, False);
	SetPrivilegedMode(False);
	
	IndexUpdateDate = FullTextSearch.UpdateDate();
	IndexTrue = FullTextSearchServer.SearchIndexTrue();
	Items.GroupIndexUpdate.Visible = Not IndexTrue;
	Items.UpdateIndex.Enabled = Not IndexTrue;
EndProcedure

&AtServer
Procedure UpdateIndexTrue()
	
	Try
		IndexUpdateDate = FullTextSearch.UpdateDate();
		If IndexUpdateDate <> '00010101000000' Then
			Items.IndexStatus.ToolTip = NStr("en = 'Index updated on:'") + " " + String(IndexUpdateDate);
		EndIf;
		
		IndexTrue = FullTextSearchServer.SearchIndexTrue();
		Items.GroupIndexUpdate.Visible = Not IndexTrue;
		Items.UpdateIndex.Enabled = Not IndexTrue;
		If Not IndexTrue Then
			IndexStatus = NStr("en = 'The index has not been updated for a long time, therefore search results can be inaccurate.'");
		EndIf;
	Except
		CommonUseClientServer.MessageToUser(BriefErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure
 
// Performs full-text search.
&AtServerNoContext
Function SaveStringAndSearchAtServer(Heading, CurrentPosition, SearchString, ChoiceList)
	
	SaveSearchString(ChoiceList, SearchString);
	
	Return SearchServer(Heading, CurrentPosition, SearchString);
	
EndFunction

&AtServerNoContext
Procedure SaveSearchString(ChoiceList, SearchString)
	
	SavedString = ChoiceList.FindByValue(SearchString);
	
	If SavedString <> Undefined Then
		ChoiceList.Delete(SavedString);
	EndIf;
		
	ChoiceList.Insert(0, SearchString);
	
	LineCount = ChoiceList.Count();
	
	If LineCount > 20 Then
		ChoiceList.Delete(LineCount - 1);
	EndIf;
	
	Strings = ChoiceList.UnloadValues();
	
	CommonUse.CommonSettingsStorageSave(
		"FullTextSearchFullTextSearchStrings", 
		, 
		Strings);
	
EndProcedure
 
// Performs full-text search.
&AtServerNoContext
Function SearchServer(Heading, CurrentPosition, SearchString)
	
	PortionSize = 20;
	
	SearchList = FullTextSearch.CreateList(SearchString, PortionSize);
	
	If Heading = 0 Then
		SearchList.FirstPart();
	ElsIf Heading = -1 Then
		SearchList.PreviousPart(CurrentPosition);
	ElsIf Heading = 1 Then
		SearchList.NextPart(CurrentPosition);
	EndIf;
	
	SearchResults = New ValueList;
	For Each Result In SearchList Do
		ResultStructure = New Structure;
		ResultStructure.Insert("Value", Result.Value);
		ResultStructure.Insert("ValuesToOpen", GetValuesToOpen(Result.Value));
		SearchResults.Add(ResultStructure);
	EndDo;
	
	HTMLText = SearchList.GetRepresentation(FullTextSearchRepresentationType.HTMLText);
	
	HTMLText = StrReplace(HTMLText, "<td>", "<td><font face=""Arial"" size=""2"">");
	HTMLText = StrReplace(HTMLText, "<td valign=top width=1>", "<td valign=top width=1><font face=""Arial"" size=""1"">");
	HTMLText = StrReplace(HTMLText, "<body>", "<body topmargin=0 leftmargin=0 scroll=auto>");
	HTMLText = StrReplace(HTMLText, "</td>", "</font></td>");
	HTMLText = StrReplace(HTMLText, "<b>", "");
	HTMLText = StrReplace(HTMLText, "</b>", "");
	HTMLText = StrReplace(HTMLText, "overflow:auto", "");
	
	CurrentPosition = SearchList.StartPosition();
	TotalCount = SearchList.TotalCount();
	TooManyResults = SearchList.TooManyResults();
	
	Result = New Structure;
	Result.Insert("SearchResult",    SearchResults);
	Result.Insert("CurrentPosition", CurrentPosition);
	Result.Insert("TotalCount",      TotalCount);
	Result.Insert("HTMLText",        HTMLText);
	Result.Insert("TooManyResults",  TooManyResults);
	
	Return Result;
	
EndFunction

&AtClient
Procedure HTMLTextOnClickAfterSelectFromList(SelectedItem, AdditionalParameters) Export
	If SelectedItem <> Undefined Then
		OpenSearchValue(SelectedItem.Value);
	EndIf;
EndProcedure

#EndRegion
