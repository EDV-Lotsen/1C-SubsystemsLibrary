
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	RefreshStatus();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure UpdateIndex(Command)
	Status(
		NStr("en = 'Updating full-text search index...
		|Please wait.'"));
	
	UpdateIndexServer();
	
	Status(NStr("en = 'Full-text search index updated.'"));
EndProcedure

&AtClient
Procedure ClearIndex(Command)
	Status(
		NStr("en = 'Clearing full-text search index...
		|Please wait.'"));
	
	ClearIndexServer();
	
	Status(NStr("en = 'Full-text search index cleared.'"));
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.IndexStatus.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("IndexTrue");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;

	Item.Appearance.SetParameterValue("Font", New Font(WindowsFonts.DefaultGUIFont, , , True, False, False, False, ));

EndProcedure

&AtServer
Procedure UpdateIndexServer()
	FullTextSearch.UpdateIndex(False, False);
	RefreshStatus();
EndProcedure

&AtServer
Procedure ClearIndexServer()
	FullTextSearch.ClearIndex();
	RefreshStatus();
EndProcedure

&AtServer
Procedure RefreshStatus()
	// Button availability, last update time.
	
	AllowFullTextSearch = (FullTextSearch.GetFullTextSearchMode() = FullTextSearchMode.Enable);
	If AllowFullTextSearch Then
		IndexUpdateDate = FullTextSearch.UpdateDate();
		IndexTrue = FullTextSearchServer.SearchIndexTrue();
		Items.FormUpdateIndex.Enabled = Not IndexTrue;
		If IndexTrue Then
			IndexStatus = NStr("en = 'No update required'");
		Else
			IndexStatus = NStr("en = 'Update required'");
		EndIf;
	Else
		IndexUpdateDate = '00010101';
		IndexTrue = False;
		Items.FormUpdateIndex.Enabled = False;
		IndexStatus = NStr("en = 'Full-text search is disabled'");
	EndIf;
	
EndProcedure

#EndRegion
