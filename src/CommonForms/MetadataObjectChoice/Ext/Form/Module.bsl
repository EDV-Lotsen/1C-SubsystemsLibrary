////////////////////////////////////////////////////////////////////////////////
// FORM USE //
//
// The form is intended for selecting configuration metadata object and passing
// them to a calling environment.
//
// Call parameters:
// MetadataObjectToSelectCollection - ValueList - metadata object
//				type filter, that can be selected.
//				For example:
//					FilterByReferenceMetadata = New ValueList;
//					FilterByReferenceMetadata.Add("Catalogs");
//					FilterByReferenceMetadata.Add("Documents");
//				In this example the form allows to select only Catalogs and Documents metadata objects.
// SelectedMetadataObjects - ValueList - metadata objects that are already selected.
//				In metadata tree this objects will be marked by a flag.
//				It can be useful to default selected metadata object setting
//				or selected list changing;
// ParentSubsystems - ValueList - only child subsystems of this subsystems
// 				will be displayed on the form (special for the SL embedding wizard); 
// SubsystemsWithCIOnly - Boolean - flag that shows whether there will be only incuded 
//				in the command interface subsystems in the list (spetial for the SL embedding wizard);
// ChooseSingle - Boolean - flag that shows whether only one metadata object will be selected.
// In this case multiselect will not be allowed, furthermore, double-click
// in a row with object will make selection;
// ChoiceInitialValue - String - full name of metadata where the list will be 
// positioned on form open.
//

////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skip initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	SelectedMetadataObjects.LoadValues(Parameters.SelectedMetadataObjects.UnloadValues());
	
	If Parameters.FilterByMetadataObjects.Count() > 0 Then
		Parameters.MetadataObjectToSelectCollection.Clear();
		For Each MetadataObjectFullName In Parameters.FilterByMetadataObjects Do
			BaseTypeName = CommonUse.BaseTypeNameByMetadataObject(Metadata.FindByFullName(MetadataObjectFullName));
			If Parameters.MetadataObjectToSelectCollection.FindByValue(BaseTypeName) = Undefined Then
				Parameters.MetadataObjectToSelectCollection.Add(BaseTypeName);
			EndIf;
		EndDo;
	EndIf;
	
	If Parameters.Property("SubsystemsWithCIOnly") And Parameters.SubsystemsWithCIOnly Then
		SubsystemsList = Metadata.Subsystems;
		FillSubsystemList(SubsystemsList);
	EndIf;
	
	If Parameters.Property("ChooseSingle", ChooseSingle) And ChooseSingle Then
		
		Items.Check.Visible = False;
		
	EndIf;
	
	Parameters.Property("ChoiceInitialValue", ChoiceInitialValue);
	
	MetadataObjectTreeFill();
	
	If Parameters.ParentSubsystems.Count()> 0 Then
		Items.MetadataObjectTree.InitialTreeView = InitialTreeView.ExpandAllLevels;
	EndIf;
	
	SetInitialCollectionMarkValues();
			
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// Setting initial selection value
	If CurrentRowIDOnOpen > 0 Then
		
		Items.MetadataObjectTree.CurrentRow = CurrentRowIDOnOpen;
		
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

// Clicking the Check field of the form tree event handler
&AtClient
Procedure CheckOnChange(Item)

	CurrentData = CurrentItem.CurrentData;
	If CurrentData.Check = 2 Then
		CurrentData.Check = 0;
	EndIf;
	SetNestedItemMarks(CurrentData);
	SetParentItemMarks(CurrentData);

EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENT HANDLERS OF MetadataObjectTree TABLE

&AtClient
Procedure MetadataObjectTreeChoice(Item, SelectedRow, Field, StandardProcessing)

	If ChooseSingle Then
		
		ChooseExecute();
		
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure ChooseExecute()
	
	If ChooseSingle Then
		
		CurData = Items.MetadataObjectTree.CurrentData;
		If CurData <> Undefined
			And CurData.IsMetadataObject Then
			
			SelectedMetadataObjects.Clear();
			SelectedMetadataObjects.Add(CurData.FullName);
			
		Else
			
			Return;
			
		EndIf;
	Else
		
		SelectedMetadataObjects.Clear();
		
		DataGet();
		
	EndIf;
	Notify("MetadataObjectChoice", SelectedMetadataObjects, Parameters.UUIDSource);
	
	Close();
	
EndProcedure

&AtClient
Procedure CloseExecute()
	
	Close();
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Procedure FillSubsystemList(SubsystemsList) 
	For Each Subsystem In SubsystemsList Do
		If Subsystem.IncludeInCommandInterface Then
			SubsystemsWithCommandInterfaceItems.Add(Subsystem.FullName());
		EndIf;	
		
		If Subsystem.Subsystems.Count() > 0 Then
			FillSubsystemList(Subsystem.Subsystems);
		EndIf;
	EndDo;
EndProcedure

// Fills the configuration object value tree.
// If the Parameters.MetadataObjectToSelectCollection value list is not empty, then
// tree will be limited by the passed metadata objects collections list.
// If metadata objects from the generated tree are found in
// the Parameters.SelectedMetadataObjects value list, then they will be marked as selected.
//
&AtServer
Procedure MetadataObjectTreeFill()
	
	MetadataObjectCollections = New ValueTable;
	MetadataObjectCollections.Columns.Add("Name");
	MetadataObjectCollections.Columns.Add("Synonym");
	MetadataObjectCollections.Columns.Add("Picture");
	MetadataObjectCollections.Columns.Add("ObjectPicture");
	MetadataObjectCollections.Columns.Add("IsCommonCollection");
	
	MetadataObjectCollections_NewRow("Subsystems", "Subsystems", 35, 36, True, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("CommonModules", "Common modules", 37, 38, True, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("SessionParameters", "Session parameters", 39, 40, True, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("Roles", "Roles", 41, 42, True, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("ExchangePlans", "Exchange plans", 43, 44, True, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("FilterCriteria", "Filter criteria", 45, 46, True, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("EventSubscriptions", "Event subscriptions", 47, 48, True, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("ScheduledJobs", "Scheduled jobs", 49, 50, True, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("FunctionalOptions", "Functional options", 51, 52, True, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("FunctionalOptionsParameters", "Functional option parameters", 53, 54, True, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("SettingsStorages", "Settings storages", 55, 56, True, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("CommonForms", "Common forms", 57, 58, True, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("CommonCommands", "Common commands", 59, 60, True, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("CommandGroups", "Commands groups", 61, 62, True, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("Interfaces", "Interfaces", 63, 64, True, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("CommonTemplates", "Common templates", 65, 66, True, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("CommonPictures", "Common pictures", 67, 68, True, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("XDTOPackages", "XDTO packages", 69, 70, True, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("WebServices", "Web services", 71, 72, True, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("WSReferences", "WS references", 73, 74, True, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("Styles", "Styles", 75, 76, True, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("Languages", "Languages", 77, 78, True, MetadataObjectCollections);
	
	MetadataObjectCollections_NewRow("Constants", "Constants", PictureLib.Constant, PictureLib.Constant, False, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("Catalogs", "Catalogs", PictureLib.Catalog, PictureLib.Catalog, False, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("Documents", "Documents", PictureLib.Document, PictureLib.DocumentObject, False, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("DocumentJournals", "Magazines journals", PictureLib.DocumentJournal, PictureLib.DocumentJournal, False, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("Enums", "Enumerations", PictureLib.Enum, PictureLib.Enum, False, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("Reports", "Reports", PictureLib.Report, PictureLib.Report, False, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("DataProcessors", "Data processors", PictureLib.DataProcessor, PictureLib.DataProcessor, False, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("ChartsOfCharacteristicTypes", "Charts of characteristic types", PictureLib.ChartOfCharacteristicTypes, PictureLib.ChartOfCharacteristicTypesObject, False, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("ChartsOfAccounts", "Charts of accounts", PictureLib.ChartOfAccounts, PictureLib.ChartOfAccountsObject, False, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("ChartsOfCalculationTypes", "Charts of calculation types", PictureLib.ChartOfCharacteristicTypes, PictureLib.ChartOfCharacteristicTypesObject, False, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("InformationRegisters", "information registers", PictureLib.InformationRegister, PictureLib.InformationRegister, False, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("AccumulationRegisters", "Accumulation registers", PictureLib.AccumulationRegister, PictureLib.AccumulationRegister, False, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("AccountingRegisters", "AccountingRegisters", PictureLib.AccountingRegister, PictureLib.AccountingRegister, False, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("CalculationRegisters", "Calculation registers", PictureLib.CalculationRegister, PictureLib.CalculationRegister, False, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("BusinessProcesses", "Business processes", PictureLib.BusinessProcess, PictureLib.BusinessProcessObject, False, MetadataObjectCollections);
	MetadataObjectCollections_NewRow("Tasks", "Tasks", PictureLib.Task, PictureLib.TaskObject, False, MetadataObjectCollections);
	
	// Creating predefined elements.
	ConfigurationItem = NewTreeRow(Metadata.Name, "", Metadata.Synonym, 79, MetadataObjectTree);
	ItemCommon = NewTreeRow("Common", "", "Common", 0, ConfigurationItem);
	
	// Filling metadata object tree.
	For Each Row In MetadataObjectCollections Do
		If Parameters.MetadataObjectToSelectCollection.Count() = 0 or
			 Parameters.MetadataObjectToSelectCollection.FindByValue(Row.Name) <> Undefined Then
			OutputMetadataObjectCollection(Row.Name,
											"",
											Row.Synonym,
											Row.Picture,
											Row.ObjectPicture,
											?(Row.IsCommonCollection, ItemCommon, ConfigurationItem),
											?(Row.Name = "Subsystems", Metadata.Subsystems, Undefined));
		EndIf;
	EndDo;
	
	If ItemCommon.GetItems().Count() = 0 Then
		ConfigurationItem.GetItems().Delete(ItemCommon);
	EndIf;
	
EndProcedure

// Adds one row to the form value tree
// and fills full row set In metadata to ThePassed Parameter
// If the Subsystem parameter is filled, then the function is called recursively because
// Subsystems can contain subsystems.
// Parameters:
// Name - parent item name;
// Synonym - parent item synonym;
// Check - Boolean, initial collection or metadata object mark;
// Picture - parent item image code;
// ObjectPicture - subitem image code;
// Parent - reference to value tree item that is a root 
// for an adding item;
// Subsystems - If Filled then contains Metadata.Subsystems value 
// that is an item collection;
// Check - Boolean, flag that shows whether belonging to parent subsystems is checked. 
// 
// Returns:
//
//
&AtServer
Function OutputMetadataObjectCollection(Name, FullName, Synonym, Picture, ObjectPicture, Parent = Undefined, Subsystems = Undefined, Check = True)
	// checking availability of command interface in tree leaves only.
	If Subsystems <> Undefined And Parameters.Property("SubsystemsWithCIOnly") And Not IsBlankString(FullName) And
		SubsystemsWithCommandInterfaceItems.FindByValue(FullName) = Undefined Then
		Return Undefined;
	EndIf;
	
	If Subsystems = Undefined Then
		
		If Metadata[Name].Count() = 0 Then
			
			// There is no one metadata object
			// in current tree branch. For example, if there is no one accounting register,
			// then the Accounting Registers root should not be added.
			Return Undefined;
			
		EndIf;
		
		NewRow = NewTreeRow(Name, FullName, Synonym, Picture, Parent, Subsystems <> Undefined And Subsystems <> Metadata.Subsystems);
		
		For Each MetadataCollectionItem In Metadata[Name] Do
			If Parameters.FilterByMetadataObjects.Count() > 0 
				And Parameters.FilterByMetadataObjects.FindByValue(MetadataCollectionItem.FullName()) = Undefined Then
				Continue;
			EndIf;
			NewTreeRow(MetadataCollectionItem.Name,
							MetadataCollectionItem.FullName(),
							MetadataCollectionItem.Synonym,
							ObjectPicture,
							NewRow,
							True);
		EndDo;
	Else
		
		If Subsystems.Count() = 0 And Name = "Subsystems" Then
			// If there are no subsystems, than the Subsystems root should not be added
			Return Undefined;
		EndIf;
		
		NewRow = NewTreeRow(Name, FullName, Synonym, Picture, Parent, Subsystems <> Undefined And Subsystems <> Metadata.Subsystems);
		
		For Each MetadataCollectionItem In Subsystems Do
			
			If Not Check or Parameters.ParentSubsystems.Count() = 0 or
				
			Parameters.ParentSubsystems.FindByValue(MetadataCollectionItem.Name) <> Undefined Then
		 			
			OutputMetadataObjectCollection(MetadataCollectionItem.Name,
											MetadataCollectionItem.FullName(),
											MetadataCollectionItem.Synonym,
											Picture,
											ObjectPicture,
											NewRow,
											MetadataCollectionItem.Subsystems,
											False);
			EndIf;
		EndDo;
	EndIf;
	
	Return NewRow;
	
EndFunction

// Adds a new row to the form tree
// Name - Item name
// Synonym - Item synonym 
// Picture - Picture code 
// Parent - form value free item, from which a new branch is grows
//
// Returns:
// FormDataElementTree - grown tree branch
//
&AtServer
Function NewTreeRow(Name, FullName, Synonym, Picture, Parent, IsMetadataObject = False)
	
	Collection = Parent.GetItems();
	NewRow = Collection.Add();
	NewRow.Name = Name;
	NewRow.Presentation = ?(ValueIsFilled(Synonym), Synonym, Name);
	NewRow.Check = ?(Parameters.SelectedMetadataObjects.FindByValue(FullName) = Undefined, 0, 1);
	NewRow.Picture = Picture;
	NewRow.FullName = FullName;
	NewRow.IsMetadataObject = IsMetadataObject;
	
	If NewRow.IsMetadataObject 
		And NewRow.FullName = ChoiceInitialValue Then
		CurrentRowIDOnOpen = NewRow.GetID();
	EndIf;
	
	Return NewRow;
	
EndFunction

// Adds a new row to configuration metadata object type value table
// 
//
// Parameters:
// Name - metadata object name or metadata object type;
// Synonym - metadata object synonym;
// Picture - picture that refers to metadata object or 
// to metadata object type;
// IsCommonCollection - flag that shows whether the current item contains subitems.
//
&AtServer
Procedure MetadataObjectCollections_NewRow(Name, Synonym, Picture, ObjectPicture, IsCommonCollection, Tab)
	
	NewRow = Tab.Add();
	NewRow.Name = Name;
	NewRow.Synonym = Synonym;
	NewRow.Picture = Picture;
	NewRow.ObjectPicture = ObjectPicture;
	NewRow.IsCommonCollection = IsCommonCollection;
	
EndProcedure

// Recursively selects/cleans passed item parent marks.
//
// Parameters:
// Item - FormDataTreeItemCollection 
//
&AtClient
Procedure SetParentItemMarks(Item)

	Parent = Item.GetParent();
	
	If Parent = Undefined Then
		Return;
	EndIf;
	
	If Not Parent.IsMetadataObject Then
	
		ParentItems = Parent.GetItems();
		If ParentItems.Count() = 0 Then
			Parent.Check = 0;
		ElsIf Item.Check = 2 Then
			Parent.Check = 2;
		Else
			Parent.Check = ItemMarkValues(ParentItems);
		EndIf;

	EndIf;
	
	SetParentItemMarks(Parent);

EndProcedure

&AtClient
Function ItemMarkValues(ParentItems)
	
	HasMarked = False;
	HasUnmarked = False;
	
	For Each ParentItem In ParentItems Do
		
		If ParentItem.Check = 2 or (HasMarked And HasUnmarked) Then
			HasMarked = True;
			HasUnmarked = True;
			Break;
		ElsIf ParentItem.IsMetadataObject Then
			HasMarked = HasMarked or ParentItem.Check;
			HasUnmarked = HasUnmarked or Not ParentItem.Check;
		Else
			NestedItems = ParentItem.GetItems();
			If NestedItems.Count() = 0 Then
				Continue;
			EndIf;
			NestedItemMarkValue = ItemMarkValues(NestedItems);
			HasMarked = HasMarked or ParentItem.Check or NestedItemMarkValue;
			HasUnmarked = HasUnmarked or Not ParentItem.Check or Not NestedItemMarkValue;
		EndIf;
	EndDo;
	
	Return ?(HasMarked And HasUnmarked, 2, ?(HasMarked, 1, 0));
	
EndFunction

&AtServer
Procedure MarkParentItemMarksAtServer(Item)

	Parent = Item.GetParent();
	
	If Parent = Undefined Then
		Return;
	EndIf;
	
	If Not Parent.IsMetadataObject Then
	
		ParentItems = Parent.GetItems();
		If ParentItems.Count() = 0 Then
			Parent.Check = 0;
		ElsIf Item.Check = 2 Then
			Parent.Check = 2;
		Else
			Parent.Check = ItemMarkValuesAtServer(ParentItems);
		EndIf;

	EndIf;
	
	MarkParentItemMarksAtServer(Parent);

EndProcedure

&AtServer
Function ItemMarkValuesAtServer(ParentItems)
	
	HasMarked = False;
	HasUnmarked = False;
	
	For Each ParentItem In ParentItems Do
		
		If ParentItem.Check = 2 or (HasMarked And HasUnmarked) Then
			HasMarked = True;
			HasUnmarked = True;
			Break;
		ElsIf ParentItem.IsMetadataObject Then
			HasMarked = HasMarked or ParentItem.Check;
			HasUnmarked = HasUnmarked or Not ParentItem.Check;
		Else
			NestedItems = ParentItem.GetItems();
			If NestedItems.Count() = 0 Then
				Continue;
			EndIf;
			NestedItemMarkValue = ItemMarkValuesAtServer(NestedItems);
			HasMarked = HasMarked or ParentItem.Check or NestedItemMarkValue;
			HasUnmarked = HasUnmarked or Not ParentItem.Check or Not NestedItemMarkValue;
		EndIf;
	EndDo;
	
	Return ?(HasMarked And HasUnmarked, 2, ?(HasMarked, 1, 0));
	
EndFunction


// Selects a mark for the metadata object collections,
// which does not have metadata objects or
// which metadata objects marks are selected.
//
// Parameters:
// Item - FormDataTreeItemCollection
// 
&AtServer
Procedure SetInitialCollectionMarkValues(Parent = Undefined)

	If Parent = Undefined Then
		Parent = MetadataObjectTree.GetItems()[0];
	EndIf;
	
	If Not Parent.IsMetadataObject Then
		
		NestedItems = Parent.GetItems();
	
		If NestedItems.Count() = 0 Then
			Parent.Check = 0;
		ElsIf NestedItems[0].IsMetadataObject Then
			MarkParentItemMarksAtServer(NestedItems[0]);
		Else
			For Each NestedItem In NestedItems Do
				SetInitialCollectionMarkValues(NestedItem);
			EndDo;
		EndIf;
		
	EndIf;

EndProcedure

// Recursively selects/clears marks of nested items 
// starting from the passed Item.
//
// Parameters:
// Item - FormDataTreeItemCollection
// 
&AtClient
Procedure SetNestedItemMarks(Item)

	NestedItems = Item.GetItems();
	
	If NestedItems.Count() = 0 Then
		If Not Item.IsMetadataObject Then
			Item.Check = 0;
		EndIf;
	Else
		For Each NestedItem In NestedItems Do
			NestedItem.Check = Item.Check;
			SetNestedItemMarks(NestedItem);
		EndDo;
	EndIf;
	
EndProcedure

// Fills selected tree item list
// The function recursively scans the item tree and if an item 
// is selected adds its FullName to the selected list.
//
// Parent - FormDataTreeItem
//
&AtServer
Procedure DataGet(Parent = Undefined)
	
	Parent = ?(Parent = Undefined, MetadataObjectTree, Parent);
	
	ItemCollection = Parent.GetItems();
	
	For Each Item In ItemCollection Do
		If Item.Check And Not IsBlankString(Item.FullName) Then
			SelectedMetadataObjects.Add(Item.FullName);
		EndIf;
		DataGet(Item);
	EndDo;
	
EndProcedure

