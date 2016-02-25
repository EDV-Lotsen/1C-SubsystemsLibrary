
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;

	If Not CommonUse.OnCreateAtServer(ThisObject, Cancel, StandardProcessing) Then
		Return;
	EndIf;
	
	SearchHistory = SearchHistory();
	If TypeOf(SearchHistory) = Type("Array") Then
		Items.SearchString.ChoiceList.LoadValues(SearchHistory);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ExecuteSearch(Command)
	
	AttachIdleHandler("OpenSearchForm", 0.1, True);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure OpenSearchForm()
	
	If IsBlankString(SearchString) Then
		ShowMessageBox(, NStr("en = 'Enter the search string.'"));
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("PassedSearchString", SearchString);
	
	FormNameToOpen = StrReplace(FormName, ".SimplifiedForm", ".Form");
	OpenForm(FormNameToOpen, FormParameters, , True);
	
	SearchHistory = SearchHistory();
	If TypeOf(SearchHistory) = Type("Array") Then
		Items.SearchString.ChoiceList.LoadValues(SearchHistory);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function SearchHistory()
	Return CommonUse.CommonSettingsStorageLoad("FullTextSearchFullTextSearchStrings");
EndFunction

#EndRegion
