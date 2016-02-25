
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	// Initializing internal flags
	CanAddToCatalog = Catalogs.WorldCountries.HasRightToAdd();
	
	If Parameters.AllowClassifierData=Undefined Then
		AllowClassifierData = True;
	Else
		BooleanType = New TypeDescription("Boolean");
		AllowClassifierData = BooleanType.AdjustValue(Parameters.AllowClassifierData);
	EndIf;
	
	OnlyClassifierData = Parameters.OnlyClassifierData;
	
	Parameters.Property("ChoiceMode", ChoiceMode);
	
	// Allowing items
	Items.List.ChoiceMode = ChoiceMode;
	Items.ListSelect.Visible       = ChoiceMode;
	Items.ListSelect.DefaultButton = ChoiceMode;
	
	Items.ListSelectFromClassifier.Visible = (ChoiceMode And Not OnlyClassifierData);
	Items.ListClassifierList.Visible       = Not Items.ListSelectFromClassifier.Visible;
	
	// Determining mode according to flags
	If ChoiceMode Then
		If AllowClassifierData Then
			If OnlyClassifierData Then
				If CanAddToCatalog Then 
					// Selecting only countries listed in the classifier
					OpenClassifierForm = True
					
				Else
					// Displaying only items present both in catalog and classifier
					SetCatalogAndClassifierJunctionFilter();
					// Hiding classifier buttons
					Items.ListSelectFromClassifier.Visible = False;
					Items.ListClassifierList.Visible       = False;
				EndIf;
				
			Else
				If CanAddToCatalog Then 
					// Displaying classifier and classifier selection button (as per default settings)
				Else
					// Hiding classifier buttons
					Items.ListSelectFromClassifier.Visible = False;
					Items.ListClassifierList.Visible       = False;
				EndIf;
			EndIf;
			
		 Else
			// Displaying catalog items only
			Items.ListClassifierList.Visible = False;
			// Hiding classifier buttons
			Items.ListSelectFromClassifier.Visible = False;
			Items.ListClassifierList.Visible       = False;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If OpenClassifierForm Then
		// Selecting only countries listed in the classifier; opening classifier form for selection
		OpenParameters = New Structure;
		OpenParameters.Insert("ChoiceMode",        True);
		OpenParameters.Insert("CloseOnChoice",     CloseOnChoice);
		OpenParameters.Insert("CurrentRow",        Items.List.CurrentRow);
		OpenParameters.Insert("WindowOpeningMode", WindowOpeningMode);
		OpenParameters.Insert("CurrentRow",        Items.List.CurrentRow);
		
		OpenForm("Catalog.WorldCountries.Form.Classifier", OpenParameters, FormOwner);
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName="Catalog.WorldCountries.Update" Then
		RefreshCountryListRepresentation();
	EndIf;
EndProcedure

#EndRegion

#Region ListFormTableItemEventHandlers

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, Group)
	If Not Clone Then
		Cancel = True;
		QuestionText = NStr("en='You can pick a world country from classifier.
		                        |Pick?'");
								
		NotificationHandler = New NotifyDescription("NotifyClassifierSelectionQuestion", ThisObject);
		ShowQueryBox(NotificationHandler, QuestionText, QuestionDialogMode.YesNoCancel, , DialogReturnCode.No);
	EndIf;
EndProcedure

&AtClient
Procedure ChoiceProcessingList(Item, SelectedValue, StandardProcessing)
	If ChoiceMode Then
		// Selecting from classifier
		NotifyChoice(SelectedValue);
	EndIf;
EndProcedure

&AtClient
Procedure ListNewWriteProcessing(NewObject, Source, StandardProcessing)
	RefreshCountryListRepresentation();
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OpenClassifier(Command)
	// Opening for viewing
	OpenParameters = New Structure;
	OpenParameters.Insert("CurrentRow", Items.List.CurrentRow);
	OpenForm("Catalog.WorldCountries.Form.Classifier", OpenParameters, Items.List);
EndProcedure

&AtClient
Procedure SelectFromClassifier(Command)
	// Opening for selection
	OpenParameters = New Structure;
	OpenParameters.Insert("ChoiceMode", True);
	OpenParameters.Insert("CloseOnChoice", CloseOnChoice);
	OpenParameters.Insert("CurrentRow", Items.List.CurrentRow);
	OpenParameters.Insert("WindowOpeningMode", WindowOpeningMode);
	OpenParameters.Insert("CurrentRow", Items.List.CurrentRow);
	OpenForm("Catalog.WorldCountries.Form.Classifier", OpenParameters, Items.List);
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure RefreshCountryListRepresentation()
	
	If RefFilterItemID<>Undefined Then
		// An additional filter was set and must be updated
		SetCatalogAndClassifierJunctionFilter();
	EndIf;
	
	Items.List.Refresh();
EndProcedure

&AtServer
Procedure SetCatalogAndClassifierJunctionFilter()
	ListFilter = List.SettingsComposer.FixedSettings.Filter;
	
	If RefFilterItemID=Undefined Then
		FilterItem = ListFilter.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.ViewMode       = DataCompositionSettingsItemViewMode.Inaccessible;
		FilterItem.LeftValue      = New DataCompositionField("Ref");
		FilterItem.ComparisonType = DataCompositionComparisonType.InList;
		FilterItem.Use            = True;
		
		RefFilterItemID = ListFilter.GetIDByObject(FilterItem);
	Else
		FilterItem = ListFilter.GetObjectByID(RefFilterItemID);
	EndIf;
	
	Query = New Query("
		|SELECT
		|	Code, Description
		|INTO
		|	Classifier
		|FROM
		|	&Classifier AS Classifier
		|INDEX BY
		|	Code, Description
		|;////////////////////////////////////////////////////////////
		|SELECT 
		|	Ref
		|FROM
		|	Catalog.WorldCountries AS WorldCountries
		|INNER JOIN
		|	Classifier AS Classifier
		|BY
		|	WorldCountries.Code = Classifier.Code
		|	AND WorldCountries.Description = Classifier.Description
		|");
	Query.SetParameter("Classifier", Catalogs.WorldCountries.ClassifierTable());
	FilterItem.RightValue = Query.Execute().Unload().UnloadColumn("Ref");
EndProcedure

&AtClient
Procedure NotifyClassifierSelectionQuestion(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult=DialogReturnCode.Yes Then
		// Picking from classifier
		OpenParameters = New Structure;
		OpenParameters.Insert("ChoiceMode", True);
		OpenForm("Catalog.WorldCountries.Form.Classifier", OpenParameters, Items.List);
		
	ElsIf QuestionResult=DialogReturnCode.No Then
		// Adding an item
		OpenForm("Catalog.WorldCountries.ObjectForm");
		
	EndIf;
	
EndProcedure

#EndRegion
