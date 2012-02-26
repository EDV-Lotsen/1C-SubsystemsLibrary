
////////////////////////////////////////////////////////////////////////////////
// SECTION OF SERVICE FUNCTIONS
//

// Function DocumentIsPosting returns value of the property Posting
// of the metadata object from the collection "Metadata.Documents".
//
// Parameters:
//  DocumentName - String, two optiona are possible FullName and ShortName,
//                 for example, "Document.PurchaseInvoice" or "PurchaseInvoice".
//
// Value returned:
//  Boolean.
//
Function DocumentIsPosting(Val DocumentName) Export
	
	DocumentNameArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(DocumentName, ".");
	
	If DocumentNameArray.Count() > 1 Then
		DocumentName = DocumentNameArray[1];
	EndIf;
	
	Return Metadata.Documents[DocumentName].Posting = 
	            Metadata.ObjectProperties.Posting.Allow;
	
EndFunction // DocumentIsPosting()

// Fills value tree with the metadata object descriptions:
// catalogs and documents.
//
&AtServer
Procedure FillObjectTypesInValueTree()
	
	TreeOM = FormAttributeToValue("MetadataObjectTree");
	TreeOM.Rows.Clear();
	
	// Command ChangesHistory parameter type contains a set of objects with
	// enabled versioning
	ArrayOfTypes = Metadata.CommonCommands.ChangesHistory.CommandParameterType.Types();
	IsCatalogs = False;
	AreDocuments = False;
	AllCatalogs = Catalogs.AllRefsType();
	AllDocuments = Documents.AllRefsType();
	NodeCatalogs = Undefined;
	NodeDocuments = Undefined;
	
	
	For Each Type In ArrayOfTypes Do
		If AllCatalogs.ContainsType(Type) Then
			If NodeCatalogs = Undefined Then
				NodeCatalogs = TreeOM.Rows.Add();
				NodeCatalogs.ObjectDescriptionSynonym = "Catalogs";
				NodeCatalogs.ObjectClass = "01ClassCatalogsRoot";
				NodeCatalogs.PictureCode = 2;
			EndIf;
			TableNewRow = NodeCatalogs.Rows.Add();
			TableNewRow.PictureCode = 19;
			TableNewRow.ObjectClass = "ClassCatalogs";
			
		ElsIf AllDocuments.ContainsType(Type) Then
			If NodeDocuments = Undefined Then
				NodeDocuments = TreeOM.Rows.Add();
				NodeDocuments.ObjectDescriptionSynonym = "Documents";
				NodeDocuments.ObjectClass = "02ClassDocumentsRoot";
				NodeDocuments.PictureCode = 3;
			EndIf;
			TableNewRow = NodeDocuments.Rows.Add();
			TableNewRow.PictureCode = 20;
			TableNewRow.ObjectClass = "ClassDocuments";
		EndIf;
		ObjectMetadata = Metadata.FindByType(Type);
		TableNewRow.ObjectType = ObjectMetadata.FullName();
		TableNewRow.ObjectDescriptionSynonym = ObjectMetadata.Synonym;
		TableNewRow.VersioningRule = 
				GetFunctionalOption("ObjectVersioningRules",
											New Structure("ConfigurationObjectType", TableNewRow.ObjectType));
		If TableNewRow.ObjectClass = "ClassDocuments" Then
			TableNewRow.IsPosting = ? (ObjectMetadata.Posting = Metadata.ObjectProperties.Posting.Allow, True, False);
		EndIf;
	EndDo;
	TreeOM.Rows.Sort("ObjectClass");
	For Each TopLevelNode In TreeOM.Rows Do
		TopLevelNode.Rows.Sort("ObjectDescriptionSynonym");
	EndDo;
	ValueToFormAttribute(TreeOM, "MetadataObjectTree");
	
EndProcedure

// Writes versioning setting
//
&AtServerNoContext
Procedure WriteVersioningSetting(Val ObjectType, Val VersioningRule)
	
	ObjectVersioning.WriteVersioningSettingByObject(
	                         ObjectType, VersioningRule);
	
EndProcedure

// Determines which of the selected rows are the descriptions
// of the documents and returns an array
//
&AtClient
Function AmongSelectedDocumentsThereAreDocsThatWeDoNotPost()
	
	For Each RowID In Items.MetadataObjectTree.SelectedRows Do
		TreeItem = MetadataObjectTree.FindByID(RowID);
		If TreeItem.ObjectClass = "ClassDocuments" And Not TreeItem.IsPosting Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

/////////////////////////////////////////////////////////////////
// Block of functions assigning versioning variant
//

// Sets all versioning settings by default
// and regenerates the tree
//
&AtServer
Procedure SetSettingsDefault()
	
	For Each RowID In Items.MetadataObjectTree.SelectedRows Do
		TreeItem = MetadataObjectTree.FindByID(RowID);
		If TreeItem.ObjectClass = "ClassCatalogs" Then
			TreeItem.VersioningRule = Enums.ObjectVersioningRules.DoNotVersion;
			ObjectVersioning.WriteVersioningSettingByObject(
			                                 TreeItem.ObjectType,
			                                 Enums.ObjectVersioningRules.DoNotVersion);
		EndIf;
		If TreeItem.ObjectClass = "ClassDocuments" Then
			If DocumentIsPosting(TreeItem.ObjectType) Then
				TreeItem.VersioningRule = Enums.ObjectVersioningRules.VersionOnPosting;
				ObjectVersioning.WriteVersioningSettingByObject(
				                                TreeItem.ObjectType,
				                                Enums.ObjectVersioningRules.VersionOnPosting);
			Else
				TreeItem.VersioningRule = Enums.ObjectVersioningRules.DoVersioning;
				ObjectVersioning.WriteVersioningSettingByObject(
				                                TreeItem.ObjectType,
				                                Enums.ObjectVersioningRules.DoVersioning);
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// Sets all versioning settings to "do not version"
// and regenerates the tree
//
&AtServer
Procedure SetVersioningRuleDoNotVersion()
	
	For Each RowID In Items.MetadataObjectTree.SelectedRows Do
		TreeItem = MetadataObjectTree.FindByID(RowID);
		
		If TreeItem.ObjectClass = "ClassCatalogs" Then
			TreeItem.VersioningRule = Enums.ObjectVersioningRules.DoNotVersion;
			ObjectVersioning.WriteVersioningSettingByObject(
			                                   TreeItem.ObjectType,
			                                   Enums.ObjectVersioningRules.DoNotVersion);
		EndIf;
		If TreeItem.ObjectClass = "ClassDocuments" Then
			TreeItem.VersioningRule = Enums.ObjectVersioningRules.DoNotVersion;
			ObjectVersioning.WriteVersioningSettingByObject(
			                                   TreeItem.ObjectType,
			                                   Enums.ObjectVersioningRules.DoNotVersion);
		EndIf;
	EndDo;
	
EndProcedure

// Sets all versioning settings "on posting"
// and regenerates the tree
//
&AtServer
Procedure SetVersioningRuleAlways()
	
	For Each RowID In Items.MetadataObjectTree.SelectedRows Do
		TreeItem = MetadataObjectTree.FindByID(RowID);
		If TreeItem.ObjectClass = "ClassCatalogs" Then
			TreeItem.VersioningRule = Enums.ObjectVersioningRules.DoVersioning;
			ObjectVersioning.WriteVersioningSettingByObject(
											TreeItem.ObjectType,
											Enums.ObjectVersioningRules.DoVersioning);
		EndIf;
		If TreeItem.ObjectClass = "ClassDocuments" Then
			TreeItem.VersioningRule = Enums.ObjectVersioningRules.DoVersioning;
			ObjectVersioning.WriteVersioningSettingByObject(
											TreeItem.ObjectType,
											Enums.ObjectVersioningRules.DoVersioning);
		EndIf;
	EndDo;
	
EndProcedure

// Sets all versioning settings "on posting"
// and regenerates the tree
//
&AtServer
Procedure SetVersioningRuleOnPosting()
	
	For Each RowID In Items.MetadataObjectTree.SelectedRows Do
		TreeItem = MetadataObjectTree.FindByID(RowID);
		If TreeItem.ObjectClass = "ClassDocuments" And DocumentIsPosting(TreeItem.ObjectType) Then
			TreeItem.VersioningRule = Enums.ObjectVersioningRules.VersionOnPosting;
			ObjectVersioning.WriteVersioningSettingByObject(
										TreeItem.ObjectType,
										Enums.ObjectVersioningRules.VersionOnPosting);
		ElsIf (TreeItem.ObjectClass = "ClassDocuments" And NOT DocumentIsPosting(TreeItem.ObjectType))
			  OR (TreeItem.ObjectClass = "ClassCatalogs") Then
			TreeItem.VersioningRule = Enums.ObjectVersioningRules.DoVersioning;
			ObjectVersioning.WriteVersioningSettingByObject(
										TreeItem.ObjectType,
										Enums.ObjectVersioningRules.DoVersioning);
		EndIf;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Section of the event handlers
//

// Handler of event "OnCreateAtServer" of form
// Fills form tree with the metadata object descriptions
//
&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	FillObjectTypesInValueTree();
	
	ChoiceListFull = New ValueList;
	ChoiceListFull.Add(Enums.ObjectVersioningRules.DoVersioning);
	ChoiceListFull.Add(Enums.ObjectVersioningRules.VersionOnPosting);
	ChoiceListFull.Add(Enums.ObjectVersioningRules.DoNotVersion);
	
	ChoiceListWithoutPosting = New ValueList;
	ChoiceListWithoutPosting.Add(Enums.ObjectVersioningRules.DoVersioning);
	ChoiceListWithoutPosting.Add(Enums.ObjectVersioningRules.DoNotVersion);
	
EndProcedure

// Handler of the event "before change" of the form item
// MetadataObjectTree.
// Rejects attempt to change properties, if cursor is on the root item
//
&AtClient
Procedure MetadataObjectTreeBeforeRowChange(Item, Cancellation)
	
	If Item.CurrentData.ObjectClass = "01ClassCatalogsRoot"
	 Or Item.CurrentData.ObjectClass = "02ClassDocumentsRoot" Then
		Cancellation = True;
	EndIf;
	
EndProcedure

// Handler of the event "start list choice" of form tree (MetadataObjectTree) field
// Generates and displays versioning variant choice list by object class
//
&AtClient
Procedure VersioningRuleStartListChoice(Item, ChoiceData, StandardProcessing)
	
	TreeRow = Items.MetadataObjectTree.CurrentData;
	
	Item.ChoiceList.Clear();
	
	If TreeRow.ObjectClass = "ClassDocuments" And TreeRow.IsPosting Then
		ChoiceList = ChoiceListFull;
	Else
		ChoiceList = ChoiceListWithoutPosting;
	EndIf;
	
	For Each ItemOfList In ChoiceList Do
		Item.ChoiceList.Add(ItemOfList.Value);
	EndDo;
	
EndProcedure


// Handler of event "choice processing" of form tree (MetadataObjectTree) field
// Inserts the selected versioning value into the table and writes the information register
//
&AtClient
Procedure VersioningRuleChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	TreeRow = Items.MetadataObjectTree.CurrentData;
	TreeRow.VersioningRule = ValueSelected;
	
	ObjectType      = TreeRow.ObjectType;
	VersioningRule = TreeRow.VersioningRule;
	
	WriteVersioningSetting(ObjectType, VersioningRule);
	
EndProcedure

// Handler of click event of the button "Fill by default" of the form command bar
// Sets all versioning settings by default
//
&AtClient
Procedure SetSettingsByDefaultExecute(Command)
	
	SetSettingsDefault();
	
EndProcedure

// Handler of click event of the button "Do not do versioning" of the form command bar
//
&AtClient
Procedure SetVersioningRuleDoNotVersionExecute(Command)
	
	SetVersioningRuleDoNotVersion();
	
EndProcedure

// Handler of click event of the button "Do versioning on posting" of the form command bar
//
&AtClient
Procedure SetVersioningRuleOnPostingExecute(Command)
	
	If AmongSelectedDocumentsThereAreDocsThatWeDoNotPost() Then
		DoMessageBox(NStr("en = 'For the documents that cannot be transactied ""Always version"" mode will be set up. '"));
	EndIf;
	
	SetVersioningRuleOnPosting();
	
EndProcedure

// Handler of click event of the button "Do versioning always" of the form command bar
//
&AtClient
Procedure SetVersioningModeAlwaysExecute(Command)
	
	SetVersioningRuleAlways();
	
EndProcedure
