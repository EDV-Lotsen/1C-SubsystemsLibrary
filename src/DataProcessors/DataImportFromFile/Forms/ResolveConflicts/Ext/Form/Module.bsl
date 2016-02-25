#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	SetDataAppearance();
	
	If Parameters.ImportType = "TabularSection" And ValueIsFilled(Parameters.TabularSectionFullName) Then 
		AmbiguityList = New ValueList;
		
		ObjectArray = StringFunctionsClientServer.SplitStringIntoWordArray(Parameters.TabularSectionFullName);
		If ObjectArray[0] = "Document" Then
			ObjectManager = Documents[ObjectArray[1]];
		ElsIf ObjectArray[0] = "Catalog" Then
			ObjectManager = Catalogs[ObjectArray[1]];
		Else
			Cancel = True;
			Return;
		EndIf;
		
		ObjectManager.FillInAmbiguityList(AmbiguityList, Parameters.Name, Parameters.ValuesOfColumnsToImport, Parameters.TabularSectionFullName);
		Items.ConflictResolvingOption.Visibility = False;
		Items.DecorationTitle.Title = StringFunctionsClientServer.SubstituteParametersInString(Items.DecorationTitle.Title, Parameters.Name);
		Items.DecorationTitle.Visible = True;
		Items.ImportFromFileDecoration.Visible = False;
		Items.CatalogItems.CommandBar.ChildItems.CatalogItemsNewItem.Visibility = False;
		For Each Column In Parameters.ValuesOfColumnsToImport Do 
			MappingColumns.Add(Column.Key);
		EndDo;
		Items.DecorationTitleReferenceSearch.Visible = False;
		
	ElsIf Parameters.ImportType = "ReferenceSearch" Then
		Items.DataGroupFromFile.Visible = False;
		Items.DecorationTitle.Visible = False;
		Items.ImportFromFileDecoration.Visible = False;
		Items.DecorationTitleReferenceSearch.Visible = True;
		AmbiguityList = Parameters.AmbiguityList;
		MappingColumns = Parameters.MappingColumns;
	Else 
		AmbiguityList = Parameters.AmbiguityList;
		MappingColumns = Parameters.MappingColumns;
		Items.DecorationTitle.Visible = False;
		Items.ImportFromFileDecoration.Visible = True;
		Items.DecorationTitleReferenceSearch.Visible = False;
	EndIf;
	Index = 0;
	
	If AmbiguityList.Count() = 0 Then
		Cancel = True;
		Return;
	EndIf;
	
	TemporaryVT = FormAttributeToValue("CatalogItems");
	TemporaryVT.Columns.Clear();
	AttributeArray = New Array;

	FirstItem = AmbiguityList.Get(0).Value;
	MetadataObject = FirstItem.Metadata();
	
	For Each Attribute In FirstItem.metadata().Attributes Do
		TemporaryVT.Columns.Add(Attribute.Name, Attribute.Type, Attribute.Presentation());
		AttributeArray.Add(New FormAttribute(Attribute.Name, Attribute.Type, "CatalogItems", Attribute.Presentation()));
	EndDo;
	
	For Each Attribute In MetadataObject.StandardAttributes Do  
		TemporaryVT.Columns.Add(Attribute.Name, Attribute.Type, Attribute.Presentation());
		AttributeArray.Add(New FormAttribute(Attribute.Name, Attribute.Type, "CatalogItems", Attribute.Presentation()));
	EndDo;
	
	For Each Item In Parameters.RowFromTable Do
		AttributeArray.Add(New FormAttribute("fl_" + Item[Index], New TypeDescription("String"),, Item[1]));
	EndDo;
	
	ChangeAttributes(AttributeArray);
	
	Items.CatalogItems.Height = AmbiguityList.Count() + 3;
	
	For Each Item In AmbiguityList Do
		Row = Options.GetItems().Add();
		Row.Presentation = String(Item.Value);
		Row.Ref = Item.Value.Ref;
		MetadataObject = Item.Value.Metadata();
		
		For Each Attribute In MetadataObject.StandardAttributes Do
			If Attribute.Name = "Code" Or Attribute.Name = "Description" Then
				Subrow = Row.GetItems().Add();
				Subrow.Presentation = Attribute.Presentation() + ":";
				Subrow.Value = Item.Value[Attribute.Name];
				Subrow.Ref = Item.Value.Ref;
			EndIf;
		EndDo;
		
		For Each Attribute In MetadataObject.Attributes Do
			Subrow = Row.GetItems().Add();
			Subrow.Presentation = Attribute.Presentation() + ":";
			Subrow.Value = Item.Value[Attribute.Name];
			Subrow.Ref = Item.Value.Ref;
		EndDo;
	
	EndDo;
	
	For Each Item In AmbiguityList Do
		String = CatalogItems.Add();
		Row.Presentation = String(Item.Value);
		For Each Column In TemporaryVT.Columns Do
			Try
				String[Column.Name] = Item.Value[Column.Name];
			Except
			EndTry;
		EndDo;
	EndDo;
	
	For Each Column In TemporaryVT.Columns Do
		NewItem = Items.Add(Column.Name, Type("FormField"), Items.CatalogItems);
		NewItem.Type = FormFieldType.InputField;
		NewItem.DataPath = "CatalogItems." + Column.Name;
		NewItem.Title = Column.Title;
	EndDo;
	
	If Parameters.ImportType = "ReferenceSearch" Then
		Separator = "";
		RowWithValues = "";
		For Each Item In Parameters.RowFromTable Do
			RowWithValues = RowWithValues + Separator + Item[2];
			Separator = ", "
		EndDo;
		If StrLen(RowWithValues) > 70 Then 
			RowWithValues = Left(RowWithValues, 70) + "...";
		EndIf;
		Items.DecorationTitleReferenceSearch.Title = StringFunctionsClientServer.SubstituteParametersInString(Items.DecorationTitleReferenceSearch.Title,
				 RowWithValues);
	Else
		CollapsedItemNumber = 0;
		For Each Item In Parameters.RowFromTable Do
			
			If Parameters.RowFromTable.Count() > 3 Then 
				If MappingColumns.FindByValue(Item[Index]) = Undefined Then
					ItemGroup = Items.OtherDataFromFile;
					CollapsedItemNumber = CollapsedItemNumber + 1;
				Else
					ItemGroup = Items.BasicDataFromFile;
				EndIf;
			Else
				ItemGroup = Items.BasicDataFromFile;
			EndIf;
			
			NewItem2 = Items.Add(Item[Index] + "_value", Type("FormField"), ItemGroup);
			NewItem2.DataPath = "fl_"+Item[Index];
			NewItem2.Title = Item[1];
			NewItem2.Type = FormFieldType.InputField;
			NewItem2.ReadOnly = True;
			ThisObject["fl_" + Item[Index]] = Item[2];
		EndDo;
	EndIf;
	
	Items.OtherDataFromFile.Title = Items.OtherDataFromFile.Title + " (" +String(CollapsedItemNumber) + ")";
	ThisObject.Height = Parameters.RowFromTable.Count() + AmbiguityList.Count() + 7;

EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Select(Command)
	Close(Items.Options.CurrentData.Ref);
EndProcedure

&AtClient
Procedure NewItem(Command)
	Close(Undefined);
EndProcedure

#EndRegion

#Region CatalogItemElementTableEventHandlers

&AtClient
Procedure CatalogItemSelection(Item, SelectedRow, Field, StandardProcessing)
	Close(Items.CatalogItems.CurrentData.Ref);
EndProcedure

&AtClient
Procedure ConflictResolvingOptionOnChange(Item)
	Items.CatalogItems.ReadOnly = Not ConflictResolvingOption;
EndProcedure

&AtClient
Procedure OptionsSelection(Item, SelectedRow, Field, StandardProcessing)
	If ValueIsFilled(Item.CurrentData.Ref) And Field.Name="OptionsValue" Then
		StandardProcessing = False;
		ShowValue(, Item.CurrentData.Ref);
	ElsIf ValueIsFilled(Item.CurrentData.Ref) And Field.Name="OptionsPresentation" Then
		StandardProcessing = False;
		Close(Items.Options.CurrentData.Ref);
	EndIf;
EndProcedure

#EndRegion


#Region UtilityFunctions

&AtServer
Procedure SetDataAppearance()
	
	ConditionalAppearance.Items.Clear();
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	
	AppearanceField = ConditionalAppearanceItem.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("OptionsValue");
	AppearanceField.Use = True;
	
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("Options.Value"); 
	FilterItem.ComparisonType = DataCompositionComparisonType.NotFilled; 
	FilterItem.Use = True;
	ConditionalAppearanceItem.Appearance.SetParameterValue("Visibility", False);
	
EndProcedure

#EndRegion
