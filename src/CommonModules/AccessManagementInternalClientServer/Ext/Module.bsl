////////////////////////////////////////////////////////////////////////////////
// Access management subsystem
// 
////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

////////////////////////////////////////////////////////////////////////////////
// Management of AccessKinds and AccessValues tables in the forms used for editing

// For internal use only.
Procedure FillAllAllowedPresentation(Form, AccessKindDescription, AddValuesCount = True) Export
	
	Parameters = AllowedValuesEditingFormParameters(Form);
	
	If AccessKindDescription.AllAllowed Then
		If Form.IsAccessGroupProfile And Not AccessKindDescription.Preset Then
			Name = "InitiallyAllAllowed";
		Else
			Name = "AllAllowed";
		EndIf;
	Else
		If Form.IsAccessGroupProfile And Not AccessKindDescription.Preset Then
			Name = "InitiallyAllProhibited";
		Else
			Name = "AllProhibited";
		EndIf;
	EndIf;
	
	AccessKindDescription.AllAllowedPresentation =
		Form.PresentationsAllAllowed.FindRows(New Structure("Name", Name))[0].Presentation;
	
	If Not AddValuesCount Then
		Return;
	EndIf;
	
	If Form.IsAccessGroupProfile And Not AccessKindDescription.Preset Then
		Return;
	EndIf;
	
	Filter = FilterInAllowedValuesEditingFormTables(Form, AccessKindDescription.AccessKind);
	
	ValuesCount = Parameters.AccessValues.FindRows(Filter).Count();
	
	If Form.IsAccessGroupProfile Then
		If ValuesCount = 0 Then
			NumberAndSubject = NStr("en = 'not assigned'");
Else
     Raise ("CHECK ON TEST");
			NumberInWords          = NumberInWords(
				ValuesCount,
				"L=en_US",
				NStr("en = ',,,,0'"));
			
			SubjectAndNumberInWords = NumberInWords(
				ValuesCount,
				"L=en_US",
				NStr("en = 'value, values,,,0'"));
			
			NumberAndSubject = StrReplace(
				SubjectAndNumberInWords,
				NumberInWords,
				Format(ValuesCount, "NG=") + " ");
		EndIf;
		
		AccessKindDescription.AllAllowedPresentation =
			AccessKindDescription.AllAllowedPresentation
				+ " (" + NumberAndSubject + ")";
		Return;
	EndIf;
	
	If ValuesCount = 0 Then
		Presentation = ?(AccessKindDescription.AllAllowed,
			NStr("en = 'All values are allowed, without exceptions'"),
			NStr("en = 'All values are prohibited, without exceptions'"));
	Else
		Raise ("CHECK ON TEST");
		NumberInWords = NumberInWords(
			ValuesCount,
			"L=en_US",
			NStr("en = ',,,,0'"));
		
		SubjectAndNumberInWords = NumberInWords(
			ValuesCount,
			"L=en_US",
			NStr("en = 'value, values,,,0'"));
		
		NumberAndSubject = StrReplace(
			SubjectAndNumberInWords,
			NumberInWords,
			Format(ValuesCount, "NG="));
		
		Presentation = StringFunctionsClientServer.SubstituteParametersInString(
			?(AccessKindDescription.AllAllowed,
				NStr("en = 'All values are allowed, except %1'"),
				NStr("en = 'All values are prohibited, except %1'")),
			NumberAndSubject);
	EndIf;
	
	AccessKindDescription.AllAllowedPresentation = Presentation;
	
EndProcedure

// For internal use only.
Procedure FillAccessValueRowNumbersByKind(Form, AccessKindDescription) Export
	
	Parameters = AllowedValuesEditingFormParameters(Form);
	
	Filter = FilterInAllowedValuesEditingFormTables(Form, AccessKindDescription.AccessKind);
	AccessValuesByKind = Parameters.AccessValues.FindRows(Filter);
	
	CurrentNumber = 1;
	For Each Row In AccessValuesByKind Do
		Row.RowNumberByKind = CurrentNumber;
		CurrentNumber = CurrentNumber + 1;
	EndDo;
	
EndProcedure

// For internal use only.
Procedure OnChangeCurrentAccessKind(Form) Export
	
	Items = Form.Items;
	Parameters = AllowedValuesEditingFormParameters(Form);
	
	CanEditValues = False;
	
	#If Client Then
		CurrentData = Items.AccessKinds.CurrentData;
	#Else
		CurrentData = Parameters.AccessKinds.FindByID(
			?(Items.AccessKinds.CurrentRow = Undefined,
			  -1,
			  Items.AccessKinds.CurrentRow));
	#EndIf
	
	If CurrentData <> Undefined Then
		
		If CurrentData.AccessKind <> Undefined
		   And Not CurrentData.Used Then
			
			If Not Items.AccessKindNotUsedText.Visibility Then
				Items.AccessKindNotUsedText.Visibility = True;
			EndIf;
		Else
			If Items.AccessKindNotUsedText.Visibility Then
				Items.AccessKindNotUsedText.Visibility = False;
			EndIf;
		EndIf;
		
		Form.CurrentAccessKind = CurrentData.AccessKind;
		
		If Not Form.IsAccessGroupProfile Or CurrentData.Preset Then
			CanEditValues = True;
		EndIf;
		
		If CanEditValues Then
			
			If Form.IsAccessGroupProfile Then
				Items.AccessKindTypes.CurrentPage = Items.PresetAccessKind;
			EndIf;
			
			// Specifying a value filter 
			RefreshRowFilter = False;
			RowFilter = Items.AccessValues.RowFilter;
			Filter = FilterInAllowedValuesEditingFormTables(Form, CurrentData.AccessKind);
			
			If RowFilter = Undefined Then
				RefreshRowFilter = True;
				
			ElsIf Filter.Property("AccessGroup") And RowFilter.AccessGroup <> Filter.AccessGroup Then
				RefreshRowFilter = True;
				
			ElsIf RowFilter.AccessKind <> Filter.AccessKind
			        And Not (RowFilter.AccessKind = "" And Filter.AccessKind = Undefined) Then
				
				RefreshRowFilter = True;
			EndIf;
			
			If RefreshRowFilter Then
				If CurrentData.AccessKind = Undefined Then
					Filter.AccessKind = "";
				EndIf;
				Items.AccessValues.RowFilter = New FixedStructure(Filter);
			EndIf;
			
		ElsIf Form.IsAccessGroupProfile Then
			Items.AccessKindTypes.CurrentPage = Items.NormalAccessKind;
		EndIf;
		
		If CurrentData.AccessKind = Form.AccessKindUsers Then
			LabelPattern = ?(CurrentData.AllAllowed,
				NStr("en = 'Prohibited values (%1), the current user is always allowed'"),
				NStr("en = 'Allowed values (%1), the current user is always allowed'") );
		
		ElsIf CurrentData.AccessKind = Form.AccessKindExternalUsers Then
			LabelPattern = ?(CurrentData.AllAllowed,
				NStr("en = 'Prohibited values (%1), the current external user is always allowed'"),
				NStr("en = 'Allowed values (%1), the current external user is always allowed'") );
		Else
			LabelPattern = ?(CurrentData.AllAllowed,
				NStr("en = 'Prohibited values (%1)'"),
				NStr("en = 'Allowed values (%1)'") );
		EndIf;
		
		// Refreshing AccessKindLabel field
		Form.AccessKindLabel = StringFunctionsClientServer.SubstituteParametersInString(
			LabelPattern, String(CurrentData.AccessKindPresentation));
		
		FillAllAllowedPresentation(Form, CurrentData);
	Else
		If Items.AccessKindNotUsedText.Visibility Then
			Items.AccessKindNotUsedText.Visibility = False;
		EndIf;
		
		Form.CurrentAccessKind = Undefined;
		Items.AccessValues.RowFilter = New FixedStructure(
			FilterInAllowedValuesEditingFormTables(Form, Undefined));
		
		If Parameters.AccessKinds.Count() = 0 Then
			Parameters.AccessValues.Clear();
		EndIf;
	EndIf;
	
	Form.CurrentTypeOfValuesToSelect  = Undefined;
	Form.CurrentTypesOfValuesToSelect = New ValueList;
	
	If CanEditValues Then
		Filter = New Structure("AccessKind", CurrentData.AccessKind);
		AccessKindTypeDescription = Form.AllTypesOfValuesToSelect.FindRows(Filter);
		For Each AccessKindTypeDescription In AccessKindTypeDescription Do
			
			Form.CurrentTypesOfValuesToSelect.Add(
				AccessKindTypeDescription.ValueType,
				AccessKindTypeDescription.TypePresentation);
		EndDo;
	Else
		If CurrentData <> Undefined Then
			
			Filter = FilterInAllowedValuesEditingFormTables(
				Form, CurrentData.AccessKind);
			
			For Each Row In Parameters.AccessValues.FindRows(Filter) Do
				Parameters.AccessValues.Delete(Row);
			EndDo
		EndIf;
	EndIf;
	
	If Form.CurrentTypesOfValuesToSelect.Count() = 0 Then
		Form.CurrentTypesOfValuesToSelect.Add(Undefined, NStr("en = 'Undefined'"));
	EndIf;
	
	Items.AccessValues.Enabled = CanEditValues;
	
EndProcedure

// For internal use only.
Function AllowedValuesEditingFormParameters(Form, CurrentObject = Undefined) Export
	
	Parameters = New Structure;
	Parameters.Insert("PathToTables", "");
	
	If CurrentObject <> Undefined Then
		TableStorage = CurrentObject;
		
	ElsIf ValueIsFilled(Form.TableStorageAttributeName) Then
		Parameters.Insert("PathToTables", Form.TableStorageAttributeName + ".");
		TableStorage = Form[Form.TableStorageAttributeName];
	Else
		TableStorage = Form;
	EndIf;
	
	Parameters.Insert("AccessKinds",     TableStorage.AccessKinds);
	Parameters.Insert("AccessValues", TableStorage.AccessValues);
	
	Return Parameters;
	
EndFunction

// For internal use only.
Function FilterInAllowedValuesEditingFormTables(Form, AccessKind = "WithoutFilterByAccessKind") Export
	
	Filter = New Structure;
	
	Structure = New Structure("CurrentAccessGroup", "AttributeNotExist");
	FillPropertyValues(Structure, Form);
	
	If Structure.CurrentAccessGroup <> "AttributeNotExist" Then
		Filter.Insert("AccessGroup", Structure.CurrentAccessGroup);
	EndIf;
	
	If AccessKind <> "WithoutFilterByAccessKind" Then
		Filter.Insert("AccessKind", AccessKind);
	EndIf;
	
	Return Filter;
	
EndFunction

// For internal use only.
Procedure FillPropertiesOfAccessKindsInForm(Form) Export
	
	Parameters = AllowedValuesEditingFormParameters(Form);
	
	For Each Row In Parameters.AccessKinds Do
		
		Row.Used = True;
		
		If Row.AccessKind <> Undefined Then
			Filter = New Structure("Ref", Row.AccessKind);
			FoundRows = Form.AllAccessKinds.FindRows(Filter);
			If FoundRows.Count() > 0 Then
				Row.AccessKindPresentation	= FoundRows[0].Presentation;
				Row.Used					= FoundRows[0].Used;
			EndIf;
		EndIf;
		
		FillAllAllowedPresentation(Form, Row);
		
		FillAccessValueRowNumbersByKind(Form, Row);
	EndDo;
	
EndProcedure

// For internal use only.
Procedure ProcessingCheckOfFillingEditingFormsOfAllowedValuesAtServer(
		Form, Cancel, CheckedTableAttributes, Errors, DontCheck = False) Export
	
	Items = Form.Items;
	Parameters = AllowedValuesEditingFormParameters(Form);
	
	CheckedTableAttributes.Add(Parameters.PathToTables + "AccessKinds.AccessKind");
	CheckedTableAttributes.Add(Parameters.PathToTables + "AccessValues.AccessKind");
	CheckedTableAttributes.Add(Parameters.PathToTables + "AccessValues.AccessValue");
	
	If DontCheck Then
		Return;
	EndIf;
	
	AccessKindFilter = FilterInAllowedValuesEditingFormTables(
		Form);
	
	AccessKinds = Parameters.AccessKinds.FindRows(AccessKindFilter);
	AccessKindIndex = AccessKinds.Count()-1;
	
	// Checking whether unfilled or duplicate access kinds are present
	While Not Cancel And AccessKindIndex >= 0 Do
		
		AccessKindRow = AccessKinds[AccessKindIndex];
		
		// Checking whether the access kind is filled
		If AccessKindRow.AccessKind = Undefined Then
			CommonUseClientServer.AddUserError(Errors,
				Parameters.PathToTables + "AccessKinds[%1].AccessKind",
				NStr("en = 'The access kind is not selected.'"),
				"AccessKinds",
				AccessKinds.Find(AccessKindRow),
				NStr("en = 'The access kind in row %1 is not selected.'"),
				Parameters.AccessKinds.IndexOf(AccessKindRow));
			Cancel = True;
			Break;
		EndIf;
		
		// Checking whether duplicate access kinds are present
		AccessKindFilter.Insert("AccessKind", AccessKindRow.AccessKind);
		FoundAccessKinds = Parameters.AccessKinds.FindRows(AccessKindFilter);
		
		If FoundAccessKinds.Count() > 1 Then
			CommonUseClientServer.AddUserError(Errors,
				Parameters.PathToTables + "AccessKinds[%1].AccessKind",
				NStr("en = 'Duplicate access kind.'"),
				"AccessKinds",
				AccessKinds.Find(AccessKindRow),
				NStr("en = 'Duplicate access kind in row %1.'"),
				Parameters.AccessKinds.IndexOf(AccessKindRow));
			Cancel = True;
			Break;
		EndIf;
		
		AccessValueFilter = FilterInAllowedValuesEditingFormTables(
			Form, AccessKindRow.AccessKind);
		
		AccessValues = Parameters.AccessValues.FindRows(AccessValueFilter);
		AccessValueIndex = AccessValues.Count()-1;
		
		While Not Cancel And AccessValueIndex >= 0 Do
			
			AccessValueRow = AccessValues[AccessValueIndex];
			
			// Checking whether the access value is filled
			If Not ValueIsFilled(AccessValueRow.AccessValue) Then
				Items.AccessKinds.CurrentRow = AccessKindRow.GetID();
				Items.AccessValues.CurrentRow = AccessValueRow.GetID();
				
				CommonUseClientServer.AddUserError(Errors,
					Parameters.PathToTables + "AccessValues[%1].AccessValue",
					NStr("en = 'The value is not selected.'"),
					"AccessValues",
					AccessValues.Find(AccessValueRow),
					NStr("en = 'The value in row %1 is not selected.'"),
					Parameters.AccessValues.IndexOf(AccessValueRow));
				Cancel = True;
				Break;
			EndIf;
			
			// Checking whether duplicate values are present
			AccessValueFilter.Insert("AccessValue", AccessValueRow.AccessValue);
			FoundValues = Parameters.AccessValues.FindRows(AccessValueFilter);
			
			If FoundValues.Count() > 1 Then
				Items.AccessKinds.CurrentRow = AccessKindRow.GetID();
				Items.AccessValues.CurrentRow = AccessValueRow.GetID();
				
				CommonUseClientServer.AddUserError(Errors,
					Parameters.PathToTables + "AccessValues[%1].AccessValue",
					NStr("en = 'Duplicate value.'"),
					"AccessValues",
					AccessValues.Find(AccessValueRow),
					NStr("en = 'Duplicate value in row %1.'"),
					Parameters.AccessValues.IndexOf(AccessValueRow));
				Cancel = True;
				Break;
			EndIf;
			
			AccessValueIndex = AccessValueIndex - 1;
		EndDo;
		AccessKindIndex = AccessKindIndex - 1;
	EndDo;
	
EndProcedure

#EndRegion
