

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM EVENTS HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	// Handler of the subsystems of object attributes edit prohibition
	ObjectAttributesLocking.LockAttributes(ThisForm);
	
	RefreshContentOfFormItems();
	
	SubjectSingular = StrGetLine(Object.SubjectDeclension, 1);
	SubjectPlural   = StrGetLine(Object.SubjectDeclension, 2);
	
	OpensFromSetProperties = Parameters.OpensFromSetProperties;
	
	If Not ValueIsFilled(Object.Ref) Then
		
		If Parameters.OpensFromSetProperties Then
			If ValueIsFilled(Parameters.Copied) Then
				Object.Description                 = Parameters.Copied.Description;
				Object.Parent                      = Parameters.Copied.Parent;
				Object.IsAdditionalData = Parameters.Copied.IsAdditionalData;
			Else
				If ValueIsFilled(Parameters.Parent) Then
					Object.Parent = ?(Parameters.Parent.IsFolder, Parameters.Parent, Parameters.Parent.Parent);
				EndIf;
				Object.IsAdditionalData = Parameters.IsAdditionalData;
			EndIf;
		EndIf;
		
	EndIf;
	
	IsAdditionalDataAttribute = Object.IsAdditionalData;
	
	If ValueIsFilled(Object.Ref) Then
	
		Query = New Query(
		"SELECT
		|	AdditionalAttributes.Ref AS Set,
		|	AdditionalAttributes.Ref.Description
		|FROM
		|	Catalog.AdditionalDataAndAttributesSettings.AdditionalAttributes AS AdditionalAttributes
		|WHERE
		|	AdditionalAttributes.Property = &Property
		|	And (NOT AdditionalAttributes.Ref.IsFolder)
		|
		|UNION ALL
		|
		|SELECT
		|	AdditionalData.Ref,
		|	AdditionalData.Ref.Description
		|FROM
		|	Catalog.AdditionalDataAndAttributesSettings.AdditionalData AS AdditionalData
		|WHERE
		|	AdditionalData.Property = &Property
		|	And (NOT AdditionalData.Ref.IsFolder)");
		
		Query.SetParameter("Property", Object.Ref);
		
		Selection = Query.Execute().Choose();
		While Selection.Next() Do
			lstOfSets.Add(Selection.Set, Selection.Description);
		EndDo;
	
	EndIf;
	
	RefreshLabelAboutSets();
	
	SetTitleOfFormatButton(Items.EditValueFormat, IsBlankString(Object.FormatProperties));
	
	If Object.MultilineTextBox > 0 Then
		MultilineTextBox = True;
		MultilineTextBoxNumber = Object.MultilineTextBox;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancellation)
	
	If Object.ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValues"))
	 And (IsBlankString(SubjectSingular) OR IsBlankString(SubjectPlural)) Then
	 If DoQueryBox(NStr("en = 'For values ""Objects attributes value"" it is recommended to specify object declension.
                         |Do you want to skip object declensions and continue?'"),
			        QuestionDialogMode.YesNo) = DialogReturnCode.No Then
			Cancellation = True;
			Return;
		EndIf;
	EndIf;
	
	// Check if there is property with the same description
	If IsWithTheSameName(Object.Description, Object.Ref) Then
		If DoQueryBox(NStr("en = 'Specified item already has record of the additional property. Continue recording?'"),
			        QuestionDialogMode.OKCancel) = DialogReturnCode.Cancel Then
			Cancellation = True;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancellation, CurrentObject, WriteParameters)
	
	If Object.ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValues")) Then
		CurrentObject.SubjectDeclension = SubjectSingular + Chars.LF + SubjectPlural;
	Else
		CurrentObject.SubjectDeclension = "";
	EndIf;
	
	If (NOT Object.IsAdditionalData)
	   And
		(Object.ValueType.ContainsType(Type("Number"))
	   OR Object.ValueType.ContainsType(Type("Date"))
	   OR Object.ValueType.ContainsType(Type("Boolean"))
	    )Then
	//
	Else
		CurrentObject.FormatProperties = "";
	EndIf;
	
	CurrentObject.MultilineTextBox = 0;
	
	If NOT Object.IsAdditionalData And 
		Object.ValueType.ContainsType(Type("String")) And Object.ValueType.Types().Count() = 1 Then
		If MultilineTextBox Then
			CurrentObject.MultilineTextBox = MultilineTextBoxNumber;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancellation, CurrentObject)
	
	If OpensFromSetProperties Then
		
		Return;
		
	EndIf;
	
	Query = New Query(
	"SELECT
	|	AdditionalAttributes.Ref AS Set,
	|	FALSE AS InSet,
	|	FALSE AS Additional_Info
	|FROM
	|	Catalog.AdditionalDataAndAttributesSettings.AdditionalAttributes AS AdditionalAttributes
	|WHERE
	|	((NOT AdditionalAttributes.Ref In (&EnabledInSets))
	|			OR &IsAdditionalData)
	|	And (NOT AdditionalAttributes.Ref.IsFolder)
	|	And AdditionalAttributes.Property = &Property
	|
	|UNION ALL
	|
	|SELECT
	|	AdditionalData.Ref,
	|	FALSE,
	|	TRUE
	|FROM
	|	Catalog.AdditionalDataAndAttributesSettings.AdditionalData AS AdditionalData
	|WHERE
	|	((NOT AdditionalData.Ref In (&EnabledInSets))
	|			OR (NOT &IsAdditionalData))
	|	And (NOT AdditionalData.Ref.IsFolder)
	|	And AdditionalData.Property = &Property
	|
	|UNION ALL
	|
	|SELECT
	|	AdditionalDataAndAttributesSettings.Ref,
	|	TRUE,
	|	&IsAdditionalData
	|FROM
	|	Catalog.AdditionalDataAndAttributesSettings AS AdditionalDataAndAttributesSettings
	|WHERE
	|	AdditionalDataAndAttributesSettings.Ref In(&EnabledInSets)
	|	And (NOT AdditionalDataAndAttributesSettings.AdditionalAttributes.Ref In
	|				(SELECT DISTINCT
	|					AdditionalAttributes.Ref AS Set
	|				FROM
	|					Catalog.AdditionalDataAndAttributesSettings.AdditionalAttributes AS AdditionalAttributes
	|				WHERE
	|					AdditionalAttributes.Ref In (&EnabledInSets)
	|					And (NOT AdditionalAttributes.Ref.IsFolder)
	|					And AdditionalAttributes.Property = &Property
	|					And (NOT &IsAdditionalData)
	|		
	|				UNION ALL
	|		
	|				SELECT DISTINCT
	|					AdditionalData.Ref AS Set
	|				FROM
	|					Catalog.AdditionalDataAndAttributesSettings.AdditionalData AS AdditionalData
	|				WHERE
	|					AdditionalData.Ref In (&EnabledInSets)
	|					And (NOT AdditionalData.Ref.IsFolder)
	|					And AdditionalData.Property = &Property
	|					And &IsAdditionalData))");
	
	Query.Parameters.Insert("Property", CurrentObject.Ref);
	Query.Parameters.Insert("IsAdditionalData", CurrentObject.IsAdditionalData);
	Query.Parameters.Insert("EnabledInSets", lstOfSets);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Choose();
	
	While Selection.Next() Do
		
		PropertiesSet = Selection.Set.GetObject();
		LockDataForEdit(Selection.Set);
		
		If Selection.InSet Then
			
			If Selection.Additional_Info Then
				
				PropertiesSet.AdditionalData.Add().Property = CurrentObject.Ref;
				
			Else
				
				PropertiesSet.AdditionalAttributes.Add().Property = CurrentObject.Ref;
				
			EndIf;
			
		Else
			
			If Selection.Additional_Info Then
				
				PropertiesSet.AdditionalData.Delete(PropertiesSet.AdditionalData.Find(CurrentObject.Ref, "Property"));
				
			Else
				
				PropertiesSet.AdditionalAttributes.Delete(PropertiesSet.AdditionalAttributes.Find(CurrentObject.Ref, "Property"));
				
			EndIf;
			
		EndIf;
		
		PropertiesSet.Write();
		
	EndDo;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	AlertStructure = New Structure;
	AlertStructure.Insert("IsAdditionalData", Object.IsAdditionalData);
	AlertStructure.Insert("Comment", Object.Comment);
	
	Notify("RecordedAdditionalProperty", AlertStructure, Object.Ref);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// Handler of the subsystems of object attributes edit prohibition
	ObjectAttributesLocking.LockAttributes(ThisForm);
	
EndProcedure

&AtClient
Procedure Pluggable_AuthorizeObjectAttributesEditing(Command)
	
	If Not Object.Ref.IsEmpty() Then
		Result = OpenFormModal("ChartOfCharacteristicTypes.AdditionalDataAndAttributes.Form.RefsToCCTSearchForm", New Structure("Ref", Object.Ref));
		If TypeOf(Result) = Type("Array") And Result.Count() > 0 Then
			ObjectAttributesLockingClient.SetAccessibilityOfFormItems(ThisForm, Result);
		EndIf;
	EndIf;

EndProcedure

&AtClient
Procedure EditValueFormat(Command)
	
	Wizard = New FormatStringWizard(Object.FormatProperties);
	
	Wizard.AvailableTypes = Object.ValueType;
	
	If Wizard.DoModal() Then
		Object.FormatProperties = Wizard.Text;
		SetTitleOfFormatButton(Items.EditValueFormat, IsBlankString(Object.FormatProperties));
	EndIf;
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonUseClient.OpenCommentEditForm(Item.EditText, Object.Comment, Modified);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM ITEMS EVENT HANDLERS

&AtClient
Procedure IsAdditionalDataAttributeOnChange(Item)
	
	Object.IsAdditionalData = IsAdditionalDataAttribute;
	
	RefreshContentOfFormItems();
	
EndProcedure

&AtClient
Procedure EditSetsListExecute()
	
	OpenSetList();
	
EndProcedure

&AtClient
Procedure ValueTypeOnChange(Item)
	
	If NOT Object.ValueType.ContainsType(Type("Number"))
	   And NOT Object.ValueType.ContainsType(Type("Date"))
	   And NOT Object.ValueType.ContainsType(Type("Boolean")) Then
		Object.FormatProperties = "";
		SetTitleOfFormatButton(Items.EditValueFormat, True);
	EndIf;

	If Object.ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValues")) 
	 OR Object.ValueType.ContainsType(Type("Number"))
	 OR Object.ValueType.ContainsType(Type("Date"))
	 OR Object.ValueType.ContainsType(Type("Boolean"))
	 OR Object.ValueType.ContainsType(Type("String")) Then
		RefreshContentOfFormItems();
	EndIf;
	
EndProcedure

&AtClient
Procedure MultilineTextBoxNumberOnChange(Item)
	
	MultilineTextBox = True;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// COMMON PROCEDURES AND FUNCTIONS

&AtServer
Procedure RefreshContentOfFormItems()
	
	If Object.ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValues")) Then
		Items.DeclensionGroup.Visible = True;
	Else
		Items.DeclensionGroup.Visible = False;
	EndIf;
	
	If (NOT Object.IsAdditionalData)
	   And
		(Object.ValueType.ContainsType(Type("Number"))
	 OR Object.ValueType.ContainsType(Type("Date"))
	 OR Object.ValueType.ContainsType(Type("Boolean"))
	    )Then
	 
		Items.EditValueFormat.Visible = True;
	Else
		Items.EditValueFormat.Visible = False;
	EndIf;
	
	If (NOT Object.IsAdditionalData)
		And Object.ValueType.ContainsType(Type("String"))
		And Object.ValueType.Types().Count() = 1 Then
		Items.GroupMultiline.Visible = True;
	Else
		Items.GroupMultiline.Visible = False;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetTitleOfFormatButton(FormButton, FormatNotInstalled)
	
	If FormatNotInstalled Then
		FormButton.Title = NStr("en = 'Default format'");
	Else
		FormButton.Title = NStr("en = 'Default format'");
	EndIf;
	
EndProcedure

&AtServerNoContext
Function IsWithTheSameName(Description, Ref)
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	1
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalDataAndAttributes AS AdditionalDataAndAttributes
	|WHERE
	|	AdditionalDataAndAttributes.Description = &Description
	|	And AdditionalDataAndAttributes.Ref <> &Ref";
	
	Query.SetParameter("Ref",       Ref);
	Query.SetParameter("Description", Description);
	
	Return NOT Query.Execute().IsEmpty();
	
EndFunction

&AtServer
Procedure RefreshLabelAboutSets()
	
	Quanty = lstOfSets.Count();
	If Quanty = 0 Then
		InformationLabel = NStr("en = 'Not included into any set'");
	ElsIf Quanty = 1 Then
		InformationLabel =
		  StringFunctionsClientServer.SubstitureParametersInString(
		    NStr("en = 'In set: %1'"), lstOfSets[0].Presentation);
	Else
		StrSets = TrimAll(NumberInWords(Quanty, "FN=False", "set,sets,,,0"));
		While True Do
			Pos = Find(StrSets, " ");
			If Pos = 0 Then
				Break;
			EndIf;
			StrSets =TrimAll(Mid(StrSets, Pos+1));
		EndDo;
		
		InformationLabel = StringFunctionsClientServer.SubstitureParametersInString(
		                          NStr("en = 'Included in: %1 %2'"), Quanty, StrSets );
	EndIf;
	
	Items.EditSetsList.Title = InformationLabel;
	
EndProcedure

&AtClient
Procedure OpenSetList()
	
	If OpensFromSetProperties Then
		DoMessageBox(NStr("en = 'The property has been opened from the record form. 
                           |Editing sets list by properties cannot be done!'"));
		Return;
	EndIf;
	
	OpenParameters = New Structure("SelectedSets,IsAdditionalData", lstOfSets, Object.IsAdditionalData);
	
	Result = OpenFormModal("ChartOfCharacteristicTypes.AdditionalDataAndAttributes.Form.SetsListEditForm", OpenParameters);
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	Modified = True;
	lstOfSets = Result;
	RefreshLabelAboutSets();
	
EndProcedure

