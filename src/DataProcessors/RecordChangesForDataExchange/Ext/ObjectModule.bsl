#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Interface

// Returns a value tree that contains data required to select a node. 
// The tree has two levels: exchange plan -> exchange nodes. 
// Internal nodes are not included in the tree. 
//
// Parameters:
//    DataObject - AnyRef, Structure - a reference or a structure that contains record set dimensions. 
//                 If DataObject is not specified, all metadata objects are used. 
//    TableName  - String - if DataObject has structure type, this parameter is the name of the register record set table.
//
// Returns:
//    ValueTree - data set with the following columns:
//        * Description            - String - exchange plan presentation or exchange node presentation. 
//        * PictureIndex           - Number - 1 = exchange plan, 2 = node, 3 = node marked for deletion.
//        * AutoRecordPictureIndex - Number - if DataObject is not specified, contains Undefined, 
//                                   otherwise: 0 = none, 1 = prohibited, = 2 allowed, 
//                                   Undefined for an exchange plan. 
//        * ExchangePlanName       - String - exchange plan name. 
//        * Ref                    - ExchangePlanRef - node reference, Undefined for an exchange plan. 
//        * Code                   - Number, String - node сode, Undefined for an exchange plan. 
//        * SentNo                 - Number - node data. 
//        * ReceivedNo             - Number - node data. 
//        * MessageNo              - Number, NULL - if an object is specified, contains a message number, otherwise NULL. 
//        * NotExported            - Boolean, NULL - if an object is specified, contains an export flag, otherwise NULL.    
//        * Check                  - Boolean - if an object is specified, 0 = no registration, 1 = registration. Otherwise it is always 0. 
//        * InitialMark            - Boolean - similar to the Mark column. 
//        * RowID                  - Number  - index of the added row (the tree is iterated from top to bottom, from left to right).
//
Function GenerateNodeTree(DataObject = Undefined, TableName = Undefined) Export
	
	Tree = New ValueTree;
	Columns = Tree.Columns;
	Rows  = Tree.Rows;
	
	Columns.Add("Description");
	Columns.Add("PictureIndex");
	Columns.Add("AutoRecordPictureIndex");
	Columns.Add("ExchangePlanName");
	Columns.Add("Ref");
	Columns.Add("Code");
	Columns.Add("SentNo");
	Columns.Add("ReceivedNo");
	Columns.Add("MessageNo");
	Columns.Add("NotExported");
	Columns.Add("Check");
	Columns.Add("InitialMark");
	Columns.Add("RowID");
	
	Query = New Query;
	If DataObject = Undefined Then
		MetaObject = Undefined;
		QueryText = "
			|SELECT
			|	REFPRESENTATION(Ref) AS Description,
			|	CASE 
			|		WHEN DeletionMark THEN 2 ELSE 1
			|	END AS PictureIndex,
			|
			|	""{0}""            AS ExchangePlanName,
			|	Code                AS Code,
			|	Ref             AS Ref,
			|	SentNo AS SentNo,
			|	ReceivedNo     AS ReceivedNo,
			|	NULL               AS MessageNo,
			|	NULL               AS NotExported,
			|	0                  AS NodeChangeCount
			|FROM
			|	ExchangePlan.{0} AS ExchangePlan
			|WHERE
			|	ExchangePlan.Ref <> &NodeFilter
			|";
		
	Else
		If TypeOf(DataObject) = Type("Structure") Then
			QueryText = "";
			For Each KeyValue In DataObject Do
				CurName   = KeyValue.Key;
				QueryText = QueryText + "
					|And ChangeTable." + CurName + " = &" + CurName;
				Query.SetParameter(CurName, DataObject[CurName]);
			EndDo;
			CurTableName = TableName;
			MetaObject   = MetadataByFullName(TableName);
			
		ElsIf TypeOf(DataObject) = Type("String") Then
			QueryText    = "";
			CurTableName = DataObject;
			MetaObject   = MetadataByFullName(DataObject);
			
		Else
			QueryText = "
				|AND ChangeTable.Ref = &RegistrationObject";
			Query.SetParameter("RegistrationObject", DataObject);
			
			MetaObject   = DataObject.Metadata();
			CurTableName = MetaObject.FullName();
		EndIf;
		
		QueryText = "
			|SELECT
			|	REFPRESENTATION(ExchangePlan.Ref) AS Description,
			|	CASE 
			|		WHEN ExchangePlan.DeletionMark THEN 2 ELSE 1
			|	END AS PictureIndex,
			|
			|	""{0}""                         AS ExchangePlanName,
			|	ExchangePlan.Code                  AS Code,
			|	ExchangePlan.Ref               AS Ref,
			|	ExchangePlan.SentNo   AS SentNo,
			|	ExchangePlan.ReceivedNo       AS ReceivedNo,
			|	ChangeTable.MessageNo AS MessageNo,
			|	CASE 
			|		WHEN ChangeTable.MessageNo IS NULL
			|		THEN TRUE
			|		ELSE FALSE
			|	END AS NotExported,
			|	COUNT(ChangeTable.Node) AS NodeChangeCount
			|FROM
			|	ExchangePlan.{0} AS ExchangePlan
			|LEFT JOIN
			|	" + CurTableName + ".Changes
			|AS
			|ChangeTable ON ChangeTable.Node = ExchangePlan.Ref
			|	" + QueryText + "
			|WHERE
			|	ExchangePlan.Ref
			|<> &NodeFilter GROUP
			|	BY ExchangePlan.Ref,
			|	ChangeTable.MessageNo
			|";
	EndIf;
	
	CurLineNumber = 0;
	For Each Meta In Metadata.ExchangePlans Do
		
		PlanName = Meta.Name;
		Try
			IsExchangePlanNode = ExchangePlans[PlanName].ThisNode();
		Except
			// If separated mode is set, the current exchange node is skipped
			Continue;
		EndTry;
		
		AutoRecord = Undefined;
		If MetaObject <> Undefined Then
			ContentItem = Meta.Content.Find(MetaObject);
			If ContentItem = Undefined Then
				// The object is not included in the current exchange plan
				Continue;
			EndIf;
			AutoRecord = ?(ContentItem.AutoRecord = AutoChangeRecord.Deny, 1, 2);
		EndIf;
		
		PlanName = Meta.Name;
		Query.Text = StrReplace(QueryText, "{0}", PlanName);
		Query.SetParameter("NodeFilter", IsExchangePlanNode);
		Result = Query.Execute();
		
		If Not Result.IsEmpty() Then
			PlanRow = Rows.Add();
			PlanRow.Description      = Meta.Presentation();
			PlanRow.PictureIndex     = 0;
			PlanRow.ExchangePlanName = PlanName;
			
			PlanRow.RowID = CurLineNumber;
			CurLineNumber = CurLineNumber + 1;
			
			// Sorting by presentation cannot be applied in a query
			TemporaryTable = Result.Unload();
			TemporaryTable.Sort("Description");
			For Each NodeRow In TemporaryTable Do;
				NewRow = PlanRow.Rows.Add();
				FillPropertyValues(NewRow, NodeRow);
				
				NewRow.InitialMark = ?(NodeRow.NodeChangeCount > 0, 1, 0);
				NewRow.Check       = NewRow.InitialMark;
				
				NewRow.AutoRecordPictureIndex = AutoRecord;
				
				NewRow.RowID  = CurLineNumber;
				CurLineNumber = CurLineNumber + 1;
			EndDo;
		EndIf;
		
	EndDo;
	
	Return Tree;
EndFunction

// Returns a structure that describes exchange plan metadata.
// Objects that are not included in the exchange plan are not included in the structure.  
//
// Parameters:
//    ExchangePlanName - String - name of the exchange plan metadata that is used to generate a configuration tree.
//                     - ExchangePlanRef - reference to an exchange plan. The configuration tree is generated for the entire exchange plan.
//                     - Undefined - all metadata objects are included.
//
// Returns: 
//    Structure - metadata details. The structure contains the following fields:
//         * NameStructure         - Structure - key - metadata group (constants, catalogs, etc.), value - array of full names.
//         * PresentationStructure - Structure - key - metadata group (constants, catalogs, etc.), value - array of full names.
//         * AutoRecordStructure   - Structure - key - metadata group (constants, catalogs, etc.), value - array of autorecord flags in a node.
//         * ChangeCount           - Undefined - used in further calculation. 
//         * ExportedCount         - Undefined - used in further calculation. 
//         * NotExportedCount      - Undefined - used in further calculation. 
//         * ChangeCountString     - Undefined - used in further calculation. 
//         * Tree                  - ValueTree - contains the following columns:
//               ** Description    - String - object metadata kind presentation. 
//               ** MetaFullName   - String - metadata object full name. 
//               ** PictureIndex   - Number - depends on metadata kind.
//               ** Check          - Undefined.
//               ** RowID          - Number - index of the added row (the tree is iterated from top to bottom, from left to right). 
//               ** Autorecord     - Boolean - if ExchangePlanName is specified, the parameter can contain the following values (for leaves): 
//                                   1 - allowed, 2 - prohibited. If ExchangePlanName is not specified, this parameter contains Undefined.
//
Function GenerateMetadataStructure(ExchangePlanName = Undefined) Export
	
	Tree = New ValueTree;
	Columns = Tree.Columns;
	Columns.Add("Description");
	Columns.Add("MetaFullName");
	Columns.Add("PictureIndex");
	Columns.Add("Check");
	Columns.Add("RowID");
	
	Columns.Add("AutoRecord");
	Columns.Add("ChangeCount");
	Columns.Add("ExportedCount");
	Columns.Add("NotExportedCount");
	Columns.Add("ChangeCountString");
	
	// Adding a row to the tree root
	RootRow = Tree.Rows.Add();
	RootRow.Description = Metadata.Presentation();
	RootRow.PictureIndex = 0;
	RootRow.RowID = 0;
	
	// Parameters
	CurParameters = New Structure("NameStructure, PresentationStructure, AutoRecordStructure, Rows", 
		New Structure, New Structure, New Structure, RootRow.Rows);
	
	If ExchangePlanName = Undefined Then
		ExchangePlan = Undefined;
	ElsIf TypeOf(ExchangePlanName) = Type("String") Then
		ExchangePlan = Metadata.ExchangePlans[ExchangePlanName];
	Else
		ExchangePlan = ExchangePlanName.Metadata();
	EndIf;
	CurParameters.Insert("ExchangePlan", ExchangePlan);
	
	Result = New Structure("Tree, NameStructure, PresentationStructure, AutoRecordStructure", 
		Tree, CurParameters.NameStructure, CurParameters.PresentationStructure, CurParameters.AutoRecordStructure);
	
	CurLineNumber = 1;
	GenerateMetadataLevel(CurLineNumber, CurParameters, 1,  2,  False, "Constants",                   NStr("en = 'Constants'"));
	GenerateMetadataLevel(CurLineNumber, CurParameters, 3,  4,  True,  "Catalogs",                    NStr("en = 'Catalogs'"));
	GenerateMetadataLevel(CurLineNumber, CurParameters, 5,  6,  True,  "Sequences",                   NStr("en = 'Sequences'"));
	GenerateMetadataLevel(CurLineNumber, CurParameters, 7,  8,  True,  "Documents",                   NStr("en = 'Documents'"));
	GenerateMetadataLevel(CurLineNumber, CurParameters, 9,  10, True,  "ChartsOfCharacteristicTypes", NStr("en = 'Charts of characteristic types'"));
	GenerateMetadataLevel(CurLineNumber, CurParameters, 11, 12, True,  "ChartsOfAccounts",            NStr("en = 'Charts of accounts'"));
	GenerateMetadataLevel(CurLineNumber, CurParameters, 13, 14, True,  "ChartsOfCalculationTypes",    NStr("en = 'Charts of calculation types'"));
	GenerateMetadataLevel(CurLineNumber, CurParameters, 15, 16, True,  "InformationRegisters",        NStr("en = 'Information registers'"));
	GenerateMetadataLevel(CurLineNumber, CurParameters, 17, 18, True,  "AccumulationRegisters",       NStr("en = 'Accumulation registers'"));
	GenerateMetadataLevel(CurLineNumber, CurParameters, 19, 20, True,  "AccountingRegisters",         NStr("en = 'Accounting registers'"));
	GenerateMetadataLevel(CurLineNumber, CurParameters, 21, 22, True,  "CalculationRegisters",        NStr("en = 'Calculation registers'"));
	GenerateMetadataLevel(CurLineNumber, CurParameters, 23, 24, True,  "BusinessProcesses",           NStr("en = 'Business processes'"));
	GenerateMetadataLevel(CurLineNumber, CurParameters, 25, 26, True,  "Tasks",                       NStr("en = 'Tasks'"));
	
	Return Result;
EndFunction

// Calculates the number of changes in metadata objects for an exchange node.
//
// Parameters:
//     TableList - Array, Structure - if it is an array, contains metadata names.
//                 If it is a structure, 
//                 structure values contain arrays of metadata names.
//     NodeList  - ExchangePlanRef, Array - a single node or a node array.
//
// Returns:
//     ValueTable - has the following columns:
//         * MetaFullName     - String - full name of metadata object. 
//         * ExchangeNode     - ExchangePlanRef - exchange node reference. The number of changes is calculated for this node. 
//         * ChangeCount      - Number.
//         * ExportedCount    - Number.
//         * NotExportedCount - Number.
//
Function GetChangeCount(TableList, NodeList) Export
	
	Result = New ValueTable;
	Columns = Result.Columns;
	Columns.Add("MetaFullName");
	Columns.Add("ExchangeNode");
	Columns.Add("ChangeCount");
	Columns.Add("ExportedCount");
	Columns.Add("NotExportedCount");
	
	Result.Indexes.Add("MetaFullName");
	Result.Indexes.Add("ExchangeNode");
	
	Query = New Query;
	Query.SetParameter("NodeList", NodeList);
	
	// TableList can contain an array, structure, or map that contains multiple arrays
	If TableList = Undefined Then
		Return Result;
	ElsIf TypeOf(TableList) = Type("Array") Then
		Source = New Structure("_", TableList);
	Else
		Source = TableList;
	EndIf;
	
	// Reading data in portions, each portion contains 200 tables processed in a query
	Text = "";
	Number = 0;
	For Each KeyValue In Source Do
		If TypeOf(KeyValue.Value) <> Type("Array") Then
			Continue;
		EndIf;
		
		For Each Item In KeyValue.Value Do
			If IsBlankString(Item) Then
				Continue;
			EndIf;
			
			Text = Text + ?(Text = "", "", "UNION ALL") + "
				|SELECT 
				|	""" + Item + """ AS MetaFullName,
				|	Node                AS ExchangeNode,
				|	COUNT(*)              AS ChangeCount,
				|	COUNT(MessageNo) AS ExportedCount,
				|	COUNT(*) - COUNT(MessageNo) AS NotExportedCount
				|FROM
				|	" + Item + ".Changes
				|WHERE
				|Node
				|IN (&NodeList)
				|GROUP BY Node
				|";
				
			Number = Number + 1;
			If Number = 200	Then
				Query.Text = Text;
				Selection = Query.Execute().Select();
				While Selection.Next() Do
					FillPropertyValues(Result.Add(), Selection);
				EndDo;
				Text = "";
				Number = 0;
			EndIf;
			
		EndDo;
	EndDo;
	
	// Reading remaining data
	If Text <> "" Then
		Query.Text = Text;
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			FillPropertyValues(Result.Add(), Selection);
		EndDo;
	EndIf;
	
	Return Result;
EndFunction

// Returns a metadata object by its full name. An empty string means the entire configuration.
//
// Parameters:
//    MetadataName - String - metadata object name, for example, Catalog.Currencies or Constants.
//
// Returns:
//    MetadataObject - metadata object.
//
Function MetadataByFullName(MetadataName) Export
	
	If IsBlankString(MetadataName) Then
		// Entire configuration
		Return Metadata;
	EndIf;
		
	Value = Metadata.FindByFullName(MetadataName);
	If Value = Undefined Then
		Value = Metadata[MetadataName];
	EndIf;
	
	Return Value;
EndFunction

// Returns a flag that shows whether a passed object is registered for a passed node.
//
// Parameters:
//    Node               - ExchangePlanRef - exchange plan node to get registration info. 
//    RegistrationObject - String, AnyRef, Structure - object for analyzing.
//                         The structure contains record set dimensions.
//    TableName          - String - if RegistrationObject has structure type, 
//                         contains a table name for a dimension set.
//
// Returns:
//    Boolean - registration result.
//
Function ObjectRegisteredForNode(Node, RegistrationObject, TableName = Undefined) Export
	ParameterType = TypeOf(RegistrationObject);
	If ParameterType = Type("String") Then
		// Constant as a metadata object
		Details = MetadataCharacteristics(RegistrationObject);
		CurrentObject = Details.Manager.CreateValueManager();
		
	ElsIf ParameterType = Type("Structure") Then
		// Dimension set is passed
		Details = MetadataCharacteristics(TableName);
		CurrentObject = Details.Manager.CreateRecordSet();
		For Each KeyValue In RegistrationObject Do
			CurrentObject.Filter[KeyValue.Key].Set(KeyValue.Value);
		EndDo;
		
	Else
		CurrentObject = RegistrationObject;
	EndIf;
	
	Return ExchangePlans.IsChangeRecorded(Node, CurrentObject);
EndFunction

// Changes registration for a passed object.
//
// Parameters:
//     Command           - Boolean - True if registration is added.
//                         False if registration is deleted. 
//     WithoutAutoRecord - Boolean - True if analyzing the autorecord flag is not required. 
//     Node              - ExchangePlanRef - exchange plan node reference. 
//     Data              - AnyRef, String, Structure - data or data array.
//     TableName         - String - if Data type is a structure, contains table name.
//
// Returns: 
//     Structure - function result:
//         * Total - Number - total number of objects.
//         * Done  - Number - number of objects that are processed.
//
Function EditRegistrationAtServer(Command, WithoutAutoRecord, Node, Data, TableName = Undefined) Export
	
	ReadSettings();
	Result = New Structure("Total, Done", 0, 0);

  // This flag is required only when adding registration results
  // to the Result structure, and the flag value can be True
  // only if the configuration supports SL.
	SLFilterRequired = TypeOf(Command) = Type("Boolean") And Command And ConfigurationSupportsSL And ObjectExportControlSetting;
	
	If TypeOf(Data) = Type("Array") Then
		RegistrationData = Data;
	Else
		RegistrationData = New Array;
		RegistrationData.Add(Data);
	EndIf;
	
	For Each Item In RegistrationData Do
		
		Type = TypeOf(Item);
		Values = New Array;
		
		If Item = Undefined Then
			// Entire configuration
			
			If TypeOf(Command) = Type("Boolean") And Command Then
				// Adding registration in parts
				AddResults(Result, EditRegistrationAtServer(Command, WithoutAutoRecord, Node, "Constants", TableName) );
				AddResults(Result, EditRegistrationAtServer(Command, WithoutAutoRecord, Node, "Catalogs", TableName) );
				AddResults(Result, EditRegistrationAtServer(Command, WithoutAutoRecord, Node, "Documents", TableName) );
				AddResults(Result, EditRegistrationAtServer(Command, WithoutAutoRecord, Node, "Sequences", TableName) );
				AddResults(Result, EditRegistrationAtServer(Command, WithoutAutoRecord, Node, "ChartsOfCharacteristicTypes", TableName) );
				AddResults(Result, EditRegistrationAtServer(Command, WithoutAutoRecord, Node, "ChartsOfAccounts", TableName) );
				AddResults(Result, EditRegistrationAtServer(Command, WithoutAutoRecord, Node, "ChartsOfCalculationTypes", TableName) );
				AddResults(Result, EditRegistrationAtServer(Command, WithoutAutoRecord, Node, "InformationRegisters", TableName) );
				AddResults(Result, EditRegistrationAtServer(Command, WithoutAutoRecord, Node, "AccumulationRegisters", TableName) );
				AddResults(Result, EditRegistrationAtServer(Command, WithoutAutoRecord, Node, "AccountingRegisters", TableName) );
				AddResults(Result, EditRegistrationAtServer(Command, WithoutAutoRecord, Node, "CalculationRegisters", TableName) );
				AddResults(Result, EditRegistrationAtServer(Command, WithoutAutoRecord, Node, "BusinessProcesses", TableName) );
				AddResults(Result, EditRegistrationAtServer(Command, WithoutAutoRecord, Node, "Tasks", TableName) );
				Continue;
			EndIf;
			
			// Deleting registration using the platform method
			Values.Add(Undefined);
			
		ElsIf Type = Type("String") Then
			// The item can contain a collection or metadata objects of specific type
			Details = MetadataCharacteristics(Item);
			If SLFilterRequired Then
				AddResults(Result, SL_MetadataChangeRegistration(Node, Details, WithoutAutoRecord) );
				Continue;
				
			ElsIf WithoutAutoRecord Then
				If Details.IsCollection Then
					For Each Meta In Details.Metadata Do
						AddResults(Result, EditRegistrationAtServer(Command, WithoutAutoRecord, Node, Meta.FullName(), TableName) );
					EndDo;
					Continue;
				Else
					Meta = Details.Metadata;
					ContentItem = Node.Metadata().Content.Find(Meta);
					If ContentItem = Undefined Then
						Continue;
					EndIf;
					// May be a constant
					Values.Add(Details.Metadata);
				EndIf;
				
			Else
				// Excluding inappropriate objects
				If Details.IsCollection Then
					// Registering metadata objects one by one
					For Each Meta In Details.Metadata Do
						AddResults(Result, EditRegistrationAtServer(Command, WithoutAutoRecord, Node, Meta.FullName(), TableName) );
					EndDo;
					Continue;
				Else
					Meta = Details.Metadata;
					ContentItem = Node.Metadata().Content.Find(Meta);
					If ContentItem = Undefined Or ContentItem.AutoRecord <> AutoChangeRecord.Allow Then
						Continue;
					EndIf;
					// May be a constant
					Values.Add(Details.Metadata);
				EndIf;
			EndIf;
			
			// Adding additional registration objects, Values[0] contains the specified metadata kind
			For Each CurItem In GetAdditionalRegistrationObjects(Item, Node, WithoutAutoRecord) Do
				Values.Add(CurItem);
			EndDo;
			
		ElsIf Type = Type("Structure") Then
			// The current item can be a record set or a reference object that is selected with a filter
			Details = MetadataCharacteristics(TableName);
			If Details.IsReference Then
				AddResults(Result, EditRegistrationAtServer(Command, WithoutAutoRecord, Node, Item.Ref) );
				Continue;
			EndIf;
			// A specific record set is passed, autorecord settings do not matter
			If SLFilterRequired Then
				AddResults(Result, SL_SetChangeRegistration(Node, Item, Details) );
				Continue;
			EndIf;
			
			Set = Details.Manager.CreateRecordSet();
			For Each KeyValue In Item Do
				Set.Filter[KeyValue.Key].Set(KeyValue.Value);
			EndDo;
			Values.Add(Set);
			// Adding additional registration objects
			For Each CurItem In GetAdditionalRegistrationObjects(Item, Node, WithoutAutoRecord, TableName) Do
				Values.Add(CurItem);
			EndDo;
			
		Else
			// A specific reference is passed, autorecord settings do not matter
			If SLFilterRequired Then
				AddResults(Result, SL_RefChangeRegistration(Node, Item) );
				Continue;
				
			EndIf;
			Values.Add(Item);
			// Adding additional registration objects
			For Each CurItem In GetAdditionalRegistrationObjects(Item, Node, WithoutAutoRecord) Do
				Values.Add(CurItem);
			EndDo;
			
		EndIf;
		
		// Registering objects without using a filter
		For Each CurValue In Values Do
			ExecuteObjectRegistrationCommand(Command, Node, CurValue);
			Result.Done = Result.Done + 1;
			Result.Total   = Result.Total   + 1;
		EndDo;
		
	EndDo; // Iterating objects in the data array for registration
	
	Return Result;
EndFunction

// Returns the first part of a passed object form full name.
// The return value is used to open a form of a specific object.
//
Function GetFormName(CurrentObject = Undefined) Export
	
	Type = TypeOf(CurrentObject);
	If Type = Type("DynamicList") Then
		Return CurrentObject.MainTable + ".";
	ElsIf Type = Type("String") Then
		Return CurrentObject + ".";
	EndIf;
	
	Meta = ?(CurrentObject = Undefined, Metadata(), CurrentObject.Metadata());
	Return Meta.FullName() + ".";
EndFunction	

// Recursive update of hierarchy marks, which can have 3 states, in a tree row.
//
// Parameters:
//    RowData - FormDataTreeItem - mark is stored in the Mark column that has a numeric type.  
//
Procedure ChangeMark(RowData) Export
	RowData.Check = RowData.Check % 2;
	SetMarksForChilds(RowData);
	SetMarksForParents(RowData);
EndProcedure

// Recursive update of hierarchy marks, which can have 3 states, in a tree row. 
//
// Parameters:
//    RowData - FormDataTreeItem - mark is stored in the Mark column that has a numeric type.  
//
Procedure SetMarksForChilds(RowData) Export
	Value = RowData.Check;
	For Each Child In RowData.GetItems() Do
		Child.Check = Value;
		SetMarksForChilds(Child);
	EndDo;
EndProcedure

// Recursive update of hierarchy marks, which can have 3 states, in a tree row. 
//
// Parameters:
//    RowData - FormDataTreeItem - mark is stored in the Mark column that has a numeric type.  
//
Procedure SetMarksForParents(RowData) Export
	RowParent = RowData.GetParent();
	If RowParent <> Undefined Then
		AllTrue = True;
		NotAllFalse = False;
		For Each Child In RowParent.GetItems() Do
			AllTrue = AllTrue And (Child.Check = 1);
			NotAllFalse = NotAllFalse Or Boolean(Child.Check);
		EndDo;
		If AllTrue Then
			RowParent.Check = 1;
		ElsIf NotAllFalse Then
			RowParent.Check = 2;
		Else
			RowParent.Check = 0;
		EndIf;
		SetMarksForParents(RowParent);
	EndIf;
EndProcedure

// Reads node attribute values.
//
// Parameters:
//    Ref  - ExchangePlanRef - exchange node reference. 
//    Data - String - list of attribute names to read, separated by commas.
//
// Returns:
//    Structure - read data. 
//    Undefined - if the passed reference is Undefined.
//
Function GetExchangeNodeParameters(Ref, Data) Export
	Query = New Query("
		|SELECT " + Data + " FROM " + Ref.Metadata().FullName() + "
		|WHERE Ref = &Ref
		|");
	Query.SetParameter("Ref", Ref);
	TempTable = Query.Execute().Unload();
	If TempTable.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	Result = New Structure(Data);
	FillPropertyValues(Result, TempTable[0]);
	Return Result;
EndFunction	

// Writes node attribute values.
//
// Parameters:
//    Ref  - ExchangePlanRef - exchange node reference. 
//    Data - String - list of attribute names to write, separated by commas.
//
Procedure SetExchangeNodeParameters(Ref, Data) Export
	
	NodeObject = Ref.GetObject();
	If NodeObject = Undefined Then
		// Reference to a deleted object is passed
		Return;
	EndIf;
	
	Changed = False;
	For Each Item In Data Do
		If NodeObject[Item.Key] <> Item.Value Then
			Changed = True;
			Break;
		EndIf;
	EndDo;
	
	If Changed Then
		FillPropertyValues(NodeObject, Data);
		NodeObject.Write();
	EndIf;
EndProcedure

// Returns a structure that contains metadata parameters. 
// Metadata parameters are generated according to metadata object name, or full metadata name, or metadata object.
//
// Parameters:
//    MetadataTableName - String - metadata table name, for example, Catalog.Currencies.
//
Function MetadataCharacteristics(MetadataTableName) Export
	
	IsSequence   = False;
	IsCollection = False;
	IsConstant   = False;
	IsReference  = False;
	IsSet        = False;
	Manager      = Undefined;
	TableName    = "";
	
	If TypeOf(MetadataTableName) = Type("String") Then
		Meta = MetadataByFullName(MetadataTableName);
		TableName = MetadataTableName;
	ElsIf TypeOf(MetadataTableName) = Type("Type") Then
		Meta = Metadata.FindByType(MetadataTableName);
		TableName = Meta.FullName();
	Else
		Meta = MetadataTableName;
		TableName = Meta.FullName();
	EndIf;
	
	If Meta = Metadata.Constants Then
		IsCollection = True;
		IsConstant   = True;
		Manager      = Constants;
		
	ElsIf Meta = Metadata.Catalogs Then
		IsCollection = True;
		IsReference  = True;
		Manager      = Catalogs;
		
	ElsIf Meta = Metadata.Documents Then
		IsCollection = True;
		IsReference  = True;
		Manager      = Documents;
		
	ElsIf Meta = Metadata.Enums Then
		IsCollection = True;
		IsReference  = True;
		Manager      = Enums;
		
	ElsIf Meta = Metadata.ChartsOfCharacteristicTypes Then
		IsCollection = True;
		IsReference  = True;
		Manager      = ChartsOfCharacteristicTypes;
		
	ElsIf Meta = Metadata.ChartsOfAccounts Then
		IsCollection = True;
		IsReference  = True;
		Manager      = ChartsOfAccounts;
		
	ElsIf Meta = Metadata.ChartsOfCalculationTypes Then
		IsCollection = True;
		IsReference  = True;
		Manager      = ChartsOfCalculationTypes;
		
	ElsIf Meta = Metadata.BusinessProcesses Then
		IsCollection = True;
		IsReference  = True;
		Manager      = BusinessProcesses;
		
	ElsIf Meta = Metadata.Tasks Then
		IsCollection = True;
		IsReference  = True;
		Manager      = Tasks;
		
	ElsIf Meta = Metadata.Sequences Then
		IsSet        = True;
		IsSequence   = True;
		IsCollection = True;
		Manager      = Sequences;
		
	ElsIf Meta = Metadata.InformationRegisters Then
		IsCollection = True;
		IsSet        = True;
		Manager      = InformationRegisters;
		
	ElsIf Meta = Metadata.AccumulationRegisters Then
		IsCollection = True;
		IsSet        = True;
		Manager      = AccumulationRegisters;
		
	ElsIf Meta = Metadata.AccountingRegisters Then
		IsCollection = True;
		IsSet        = True;
		Manager      = AccountingRegisters;
		
	ElsIf Meta = Metadata.CalculationRegisters Then
		IsCollection = True;
		IsSet        = True;
		Manager      = CalculationRegisters;
		
	ElsIf Metadata.Constants.Contains(Meta) Then
		IsConstant = True;
		Manager    = Constants[Meta.Name];
		
	ElsIf Metadata.Catalogs.Contains(Meta) Then
		IsReference = True;
		Manager     = Catalogs[Meta.Name];
		
	ElsIf Metadata.Documents.Contains(Meta) Then
		IsReference = True;
		Manager     = Documents[Meta.Name];
		
	ElsIf Metadata.Sequences.Contains(Meta) Then
		IsSet      = True;
		IsSequence = True;
		Manager    = Sequences[Meta.Name];
		
	ElsIf Metadata.Enums.Contains(Meta) Then
		IsReference = True;
		Manager     = Enums[Meta.Name];
		
	ElsIf Metadata.ChartsOfCharacteristicTypes.Contains(Meta) Then
		IsReference = True;
		Manager     = ChartsOfCharacteristicTypes[Meta.Name];
		
	ElsIf Metadata.ChartsOfAccounts.Contains(Meta) Then
		IsReference = True;
		Manager     = ChartsOfAccounts[Meta.Name];
		
	ElsIf Metadata.ChartsOfCalculationTypes.Contains(Meta) Then
		IsReference = True;
		Manager     = ChartsOfCalculationTypes[Meta.Name];
		
	ElsIf Metadata.InformationRegisters.Contains(Meta) Then
		IsSet   = True;
		Manager = InformationRegisters[Meta.Name];
		
	ElsIf Metadata.AccumulationRegisters.Contains(Meta) Then
		IsSet   = True;
		Manager = AccumulationRegisters[Meta.Name];
		
	ElsIf Metadata.AccountingRegisters.Contains(Meta) Then
		IsSet   = True;
		Manager = AccountingRegisters[Meta.Name];
		
	ElsIf Metadata.CalculationRegisters.Contains(Meta) Then
		IsSet   = True;
		Manager = CalculationRegisters[Meta.Name];
		
	ElsIf Metadata.BusinessProcesses.Contains(Meta) Then
		IsReference = True;
		Manager     = BusinessProcesses[Meta.Name];
		
	ElsIf Metadata.Tasks.Contains(Meta) Then
		IsReference = True;
		Manager     = Tasks[Meta.Name];
		
	Else
		MetaParent = Meta.Parent();
		If MetaParent <> Undefined And Metadata.CalculationRegisters.Contains(MetaParent) Then
			// Recalculation
			IsSet = True;
			Manager = CalculationRegisters[MetaParent.Name].Recalculations[Meta.Name];
		EndIf;
		
	EndIf;
		
	Return New Structure("TableName, Metadata, Manager, IsSet, IsReference, IsConstant, IsSequence, IsCollection",
		TableName, Meta, Manager, 
		IsSet, IsReference, IsConstant, IsSequence, IsCollection);
	
EndFunction

// Returns a value table that contains dimensions for registering record set changes.
//
// Parameters:
//    TableName     - String - metadata table name, for example, InformationRegister.CurrencyRates. 
//    AllDimensions - Boolean - a flag that shows whether all information register
//                    dimensions are used (not just base and master ones).
//
// Returns:
//    ValueTable - contains the following columns:
//         * Name      - String - dimension name. 
//         * ValueType - TypeDescription - types.
//         * Title     - String - dimension presentation.
//
Function RecordSetDimensions(TableName, AllDimensions = False) Export
	
	If TypeOf(TableName) = Type("String") Then
		Meta = MetadataByFullName(TableName);
	Else
		Meta = TableName;
	EndIf;
	
	// Specifying key fields
	Dimensions = New ValueTable;
	Columns = Dimensions.Columns;
	Columns.Add("Name");
	Columns.Add("ValueType");
	Columns.Add("Title");
	
	If Not AllDimensions Then
		// Data for registration
		Ignore = "MessageNo,Node,";
		For Each MetaCommon In Metadata.CommonAttributes Do
			Ignore = Ignore + MetaCommon.Name + "," ;
		EndDo;
		
		Query = New Query("SELECT * FROM " + Meta.FullName() + ".Changes WHERE FALSE");
		EmptyResult = Query.Execute();
		For Each ResultColumn In EmptyResult.Columns Do
			ColumnName = ResultColumn.Name;
			If Find(Ignore, ColumnName + ",") = 0 Then
				Row           = Dimensions.Add();
				Row.Name      = ColumnName;
				Row.ValueType = ResultColumn.ValueType;
				
				MetaChanges = Meta.Dimensions.Find(ColumnName);
				Row.Title   = ?(MetaChanges = Undefined, ColumnName, MetaChanges.Presentation());
			EndIf;
		EndDo;
		
		Return Dimensions;
	EndIf;
	
	// All register dimensions are used
	
	IsInformationRegister = Metadata.InformationRegisters.Contains(Meta);
	
	// Adding the Recorder dimension
	If Metadata.AccumulationRegisters.Contains(Meta)
	 Or Metadata.AccountingRegisters.Contains(Meta)
	 Or Metadata.CalculationRegisters.Contains(Meta)
	 Or (IsInformationRegister And Meta.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.RecorderSubordinate)
	 Or Metadata.Sequences.Contains(Meta)
	Then
		Row = Dimensions.Add();
		Row.Name      = "Recorder";
		Row.ValueType = Documents.AllRefsType();
		Row.Title     = NStr("en = 'Recorder'");
	EndIf;
	
	// Adding the Period dimension
	If IsInformationRegister And Meta.MainFilterOnPeriod Then
		Row = Dimensions.Add();
		Row.Name      = "Period";
		Row.ValueType = New TypeDescription("Date");
		Row.Title     = NStr("en = 'Period'");
	EndIf;
	
	// Adding other dimensions
	If IsInformationRegister Then
		For Each MetaChanges In Meta.Dimensions Do
			Row = Dimensions.Add();
			Row.Name      = MetaChanges.Name;
			Row.ValueType = MetaChanges.Type;
			Row.Title     = MetaChanges.Presentation();
		EndDo;
	EndIf;
	
	// Adding the Recalculation
	If Metadata.CalculationRegisters.Contains(Meta.Parent()) Then
		Row = Dimensions.Add();
		Row.Name      = "RecalculationObject";
		Row.ValueType = Documents.AllRefsType();
		Row.Title     = NStr("en = 'Object to recalculate'");
	EndIf;
	
	Return Dimensions;
EndFunction

// Adds columns to a form table.
//
// Parameters:
//    FormTable    - FormItem - form item linked to an attribute. The data columns are added to this attribute. 
//    SaveNames    - String - list of column names, separated by commas. These columns are saved.
//    Add          - Array - contains structures that describe columns to be
//                   added (Name, ValueType, Title). 
//    ColumnGroup  - FormItem - column group where the columns are added.
//
Procedure AddColumnsToFormTable(FormTable, SaveNames, Add, ColumnGroup = Undefined) Export
	
	Form = FormItemForm(FormTable);
	FormItems = Form.Items;
	TableAttributeName = FormTable.DataPath;
	
	ToBeSaved = New Structure(SaveNames);
	DataPathsToSave = New Map;
	For Each Item In ToBeSaved Do
		DataPathsToSave.Insert(TableAttributeName + "." + Item.Key, True);
	EndDo;
	
	IsDynamicList = False;
	For Each Attribute In Form.GetAttributes() Do
		If Attribute.Name = TableAttributeName And Attribute.ValueType.ContainsType(Type("DynamicList")) Then
			IsDynamicList = True;
			Break;
		EndIf;
	EndDo;

	// If TableForm is not a dynamic list
	If Not IsDynamicList Then
		NamesToDelete = New Array;
		
		// Deleting attributes that are not included in SaveNames
		For Each Attribute In Form.GetAttributes(TableAttributeName) Do
			CurName = Attribute.Name;
			If Not ToBeSaved.Property(CurName) Then
				NamesToDelete.Add(Attribute.Path + "." + CurName);
			EndIf;
		EndDo;
		
		ToAdd = New Array;
		For Each Column In Add Do
			CurName = Column.Name;
			If Not ToBeSaved.Property(CurName) Then
				ToAdd.Add( New FormAttribute(CurName, Column.ValueType, TableAttributeName, Column.Title) );
			EndIf;
		EndDo;
		
		Form.ChangeAttributes(ToAdd, NamesToDelete);
	EndIf;
	
	// Deleting form items
	Parent = ?(ColumnGroup = Undefined, FormTable, ColumnGroup);
	
	Delete = New Array;
	For Each Item In Parent.ChildItems Do
		Delete.Add(Item);
	EndDo;
	For Each Item In Delete Do
		If TypeOf(Item) <> Type("FormGroup") And DataPathsToSave[Item.DataPath] = Undefined Then
			FormItems.Delete(Item);
		EndIf;
	EndDo;
	
	// Adding form items
	Prefix = FormTable.Name;
	For Each Column In Add Do
		CurName = Column.Name;
		FormIt = FormItems.Insert(Prefix + CurName, Type("FormField"), Parent);
		FormIt.Type = FormFieldType.InputField;
		FormIt.DataPath = TableAttributeName + "." + CurName;
		FormIt.Title = Column.Title;
	EndDo;
	
EndProcedure	

// Returns a detailed object presentation.
//
// Parameters:
//    ObjectToGetPresentation - AnyRef - object whose presentation is retrieved.
//
Function RefPresentation(ObjectToGetPresentation) Export
	
	If TypeOf(ObjectToGetPresentation) = Type("String") Then
		// Attempting to obtain metadata object 
		Meta = Metadata.FindByFullName(ObjectToGetPresentation);
		Result = Meta.Presentation();
		If Metadata.Constants.Contains(Meta) Then
			Result = Result + " (constant)";
		EndIf;
		Return Result;
	EndIf;
	
	// Reference
	Result = "";
	CommonUseModule = CommonUseCommonModule("CommonUse");
	If CommonUseModule <> Undefined Then
		Try
			Result = CommonUseModule.SubjectString(ObjectToGetPresentation);
		Except
			// Error calling the SubjectString method
		EndTry;
	EndIf;
	
	If IsBlankString(Result) And ObjectToGetPresentation <> Undefined And Not ObjectToGetPresentation.IsEmpty() Then
		Meta = ObjectToGetPresentation.Metadata();
		If Metadata.Documents.Contains(Meta) Then
			Result = String(ObjectToGetPresentation);
		Else
			Presentation = Meta.ObjectPresentation;
			If IsBlankString(Presentation) Then
				Presentation = Meta.Presentation();
			EndIf;
			Result = String(ObjectToGetPresentation);
			If Not IsBlankString(Presentation) Then
				Result = Result + " (" + Presentation + ")";
			EndIf;
		EndIf;
	EndIf;
	
	If IsBlankString(Result) Then
		Result = NStr("en = 'not specified'");
	EndIf;
	
	Return Result;
EndFunction

// Returns a flag that shows whether the current infobase is running in file mode.
//
Function IsFileInfobase() Export
	Return Find(InfobaseConnectionString(), "File=") > 0;
EndFunction

//  Reads current dynamic list data according to its settings and returns the data in a value table format.
//
// Parameters:
//    DataSource - DynamicList - form attribute.
//
Function DynamicListCurrentData(DataSource) Export
	
	CompositionSchema = New DataCompositionSchema;
	
	Source = CompositionSchema.DataSources.Add();
	Source.Name = "Source";
	Source.DataSourceType = "local";
	
	Set = CompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	Set.Query = DataSource.QueryText;
	Set.AutoFillAvailableFields = True;
	Set.DataSource = Source.Name;
	Set.Name = Source.Name;
	
	SettingsSource = New DataCompositionAvailableSettingsSource(CompositionSchema);
	Composer = New DataCompositionSettingsComposer;
	Composer.Initialize(SettingsSource);
	
	CurSettings = Composer.Settings;
	
	// Adding data composition fields
	For Each Item In CurSettings.Selection.SelectionAvailableFields.Items Do
		If Not Item.Folder Then
			Field = CurSettings.Selection.Items.Add(Type("DataCompositionSelectedField"));
			Field.Use = True;
			Field.Field = Item.Field;
		EndIf;
	EndDo;
	Group = CurSettings.Structure.Add(Type("DataCompositionGroup"));
	Group.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));

	// Filling filter settings
	CopyDataCompositionFilter(CurSettings.Filter, DataSource.Filter);
	CopyDataCompositionFilter(CurSettings.Filter, DataSource.SettingsComposer.GetSettings().Filter);

	// Filling the return value table
	TemplateComposer = New DataCompositionTemplateComposer;
	Template = TemplateComposer.Execute(CompositionSchema, CurSettings, , , Type("DataCompositionValueCollectionTemplateGenerator"));
	Processor = New DataCompositionProcessor;
	Processor.Initialize(Template);
	Output  = New DataCompositionResultValueCollectionOutputProcessor;
	
	Result = New ValueTable;
	Output.SetObject(Result); 
	Output.Output(Processor);
	
	Return Result;
EndFunction

// Reads settings from the common storage.
//
Procedure ReadSettings(SettingsKey = "") Export
	
	ObjectKey = Metadata().FullName() + ".Form.Form";
	
	CurrentSettings = CommonSettingsStorage.Load(ObjectKey);
	If TypeOf(CurrentSettings) <> Type("Map") Then
		// Filling default options
		CurrentSettings = New Map;
		CurrentSettings.Insert("RegisterRecordAutoRecordSetting",          False);
		CurrentSettings.Insert("SequenceAutoRecordSetting",                False);
		CurrentSettings.Insert("QueryExternalDataProcessorAddressSetting", "");
		CurrentSettings.Insert("ObjectExportControlSetting",               True); // Flag of object export control
		CurrentSettings.Insert("MessageNoVariantSetting",                  0);    // First exchange execution
	EndIf;
	
	RegisterRecordAutoRecordSetting          = CurrentSettings["RegisterRecordAutoRecordSetting"];
	SequenceAutoRecordSetting                = CurrentSettings["SequenceAutoRecordSetting"];
	QueryExternalDataProcessorAddressSetting = CurrentSettings["QueryExternalDataProcessorAddressSetting"];
	ObjectExportControlSetting               = CurrentSettings["ObjectExportControlSetting"];
	MessageNoVariantSetting                  = CurrentSettings["MessageNoVariantSetting"];

	CheckSettingCorrectness(SettingsKey);
EndProcedure

// Sets SL support flags.
//
Procedure ReadSLSupportFlags() Export
	ConfigurationSupportsSL = SL_RequiredVersionAvailable();
	
	If ConfigurationSupportsSL Then
		// Performing registration with an external registration interface
		RegistrationWithSLMethodsAvailable = SL_RequiredVersionAvailable("2.1.5.11");
		DIBModeAvailable                   = SL_RequiredVersionAvailable("2.1.3.25");
	Else
		RegistrationWithSLMethodsAvailable = False;
		DIBModeAvailable                   = False;
	EndIf;
EndProcedure

// Saves setting to the common storage.
//
Procedure SaveSettings(SettingsKey = "") Export
	
	ObjectKey = Metadata().FullName() + ".Form.Form";
	
	CurrentSettings = New Map;
	CurrentSettings.Insert("RegisterRecordAutoRecordSetting",          RegisterRecordAutoRecordSetting);
	CurrentSettings.Insert("SequenceAutoRecordSetting",                SequenceAutoRecordSetting);
	CurrentSettings.Insert("QueryExternalDataProcessorAddressSetting", QueryExternalDataProcessorAddressSetting);
	CurrentSettings.Insert("ObjectExportControlSetting",               ObjectExportControlSetting);
	CurrentSettings.Insert("MessageNoVariantSetting",                  MessageNoVariantSetting);
	
	CommonSettingsStorage.Save(ObjectKey, "", CurrentSettings)
EndProcedure	

// Checks the settings and resets invalid settings.
//
// Returns:
//     Structure - the key contains the option name, and the value contains error details
//                 or Undefined if there is no error for a specific option.
//
Function CheckSettingCorrectness(SettingsKey = "") Export
	
	Result = New Structure("HasErrors,
		|RegisterRecordAutoRecordSetting, SequenceAutoRecordSetting,
		|QueryExternalDataProcessorAddressSetting,
		|ObjectExportControlSetting, MessageNoVariantSetting",
		False);
		
	// Checking whether an external data processor is available
	If IsBlankString(QueryExternalDataProcessorAddressSetting) Then
		// Setting an empty string value to the QueryExternalDataProcessorAddressSetting
		QueryExternalDataProcessorAddressSetting = "";
		
	ElsIf Lower(Right(TrimAll(QueryExternalDataProcessorAddressSetting), 4)) = ".epf" Then
		// Checking external data processor file
		File = New File(QueryExternalDataProcessorAddressSetting);
		Try
			If File.Exist() Then
				ExternalDataProcessors.Create(QueryExternalDataProcessorAddressSetting);
			Else
				If IsFileInfobase() Then
					Text = NStr("en = 'File %1 is inaccessible'");
				Else
					Text = NStr("en = 'File %1 is inaccessible on the server'");
				EndIf;
				Result.QueryExternalDataProcessorAddressSetting = StrReplace(Text, "%1", QueryExternalDataProcessorAddressSetting);
				Result.HasErrors = True;
			EndIf;
		Except
			// The specified file is invalid or security profile settings do not allow reading the file
			Information = ErrorInfo();
			Result.QueryExternalDataProcessorAddressSetting = BriefErrorDescription(Information);
			
			Result.HasErrors = True;
		EndTry;
			
	Else
		// Data processor is a part of the configuration
		If Metadata.DataProcessors.Find(QueryExternalDataProcessorAddressSetting) = Undefined Then
			Text = NStr("en = 'The %1 data processor not found in the configuration'");
			Result.QueryExternalDataProcessorAddressSetting = StrReplace(Text, "%1", QueryExternalDataProcessorAddressSetting);
			
			Result.HasErrors = True;
		EndIf;
		
	EndIf;
	
	Return Result;
EndFunction

// Returns an internal info structure that is used in attachable data processors.
//
Function ExternalDataProcessorInfo() Export
	
	Info = New Structure;
	
	Info.Insert("Kind",     "RelatedObjectCreation");
	Info.Insert("Commands", New ValueTable);
	Info.Insert("SafeMode", True);
	Info.Insert("Purpose",  New Array);
	
	Info.Insert("Description", NStr("en = 'Record changes for data exchange'"));
	Info.Insert("Version",     "1.0");
	Info.Insert("SLVersion",   "1.2.1.4");
	Info.Insert("Information", NStr("en = 'The data processor is designed to manage object registration for exchange nodes before exporting. If the configuration is based on SL version 2.1.2.0 or later, checks data migration restrictions for exchange nodes.'"));
	
	Info.Purpose.Add("ExchangePlans.*");
	Info.Purpose.Add("Constants.*");
	Info.Purpose.Add("Catalogs.*");
	Info.Purpose.Add("Documents.*");
	Info.Purpose.Add("Sequences.*");
	Info.Purpose.Add("ChartsOfCharacteristicTypes.*");
	Info.Purpose.Add("ChartsOfAccounts.*");
	Info.Purpose.Add("ChartsOfCalculationTypes.*");
	Info.Purpose.Add("InformationRegisters.*");
	Info.Purpose.Add("AccumulationRegisters.*");
	Info.Purpose.Add("AccountingRegisters.*");
	Info.Purpose.Add("CalculationRegisters.*");
	Info.Purpose.Add("BusinessProcesses.*");
	Info.Purpose.Add("Tasks.*");
	
	Columns = Info.Commands.Columns;
	StringType = New TypeDescription("String");
	Columns.Add("Presentation", StringType);
	Columns.Add("ID",           StringType);
	Columns.Add("Use",          StringType);
	Columns.Add("Modifier",     StringType);
	Columns.Add("ShowNotification", New TypeDescription("Boolean"));
	
	// Single command
	Command = Info.Commands.Add();
	Command.Presentation = NStr("en = 'Editing object change registration'");
	Command.ID = "OpenRegistrationEditingForm";
	Command.Use = "ClientMethodCall";
	
	Return Info;
EndFunction

#EndRegion

#Region InternalProceduresAndFunctions
//

//
// Copies items to a data composer filter.
//
Procedure CopyDataCompositionFilter(TargetGroup, SourceGroup) 
	
	SourceCollection = SourceGroup.Items;
	TargetCollection = TargetGroup.Items;
	For Each Item In SourceCollection Do
		ItemType = TypeOf(Item);
		NewItem  = TargetCollection.Add(ItemType);
		
		FillPropertyValues(NewItem, Item);
		If ItemType = Type("DataCompositionFilterItemGroup") Then
			CopyDataCompositionFilter(NewItem, Item) 
		EndIf;
		
	EndDo;
	
EndProcedure

// Executes the specified operation on a passed object.
//
Procedure ExecuteObjectRegistrationCommand(Val Command, Val Node, Val RegistrationObject)
	
	If TypeOf(Command) = Type("Boolean") Then
		If Command Then
			// Executing registration
			If MessageNoVariantSetting = 1 Then
				// Registering an object as a sent one
				Command = 1 + Node.SentNo;
			Else
				// Registering an object as a new one
				RecordChanges(Node, RegistrationObject);
			EndIf;
		Else
			// Canceling registration
			ExchangePlans.DeleteChangeRecords(Node, RegistrationObject);
		EndIf;
	EndIf;
	
	If TypeOf(Command) = Type("Number") Then
		// Performing single registration with a specified message number
		If Command = 0 Then
			// Similar to registration of a new object
			RecordChanges(Node, RegistrationObject)
		Else
			// Registering passed object changes for a passed node
			ExchangePlans.RecordChanges(Node, RegistrationObject);
			Selection = ExchangePlans.SelectChanges(Node, Command, RegistrationObject);
			While Selection.Next() Do
				// Selecting changes to assign exchange message number
			EndDo;
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure RecordChanges(Val Node, Val RegistrationObject)
	
	If Not RegistrationWithSLMethodsAvailable Then
		ExchangePlans.RecordChanges(Node, RegistrationObject);
		Return;
	EndIf;
		
	// Getting a common module that contains registration handlers
	DataExchangeEventsModule = CommonUseCommonModule("DataExchangeEvents");
	
	// RegistrationObject contains a metadata object or an infobase object
	If TypeOf(RegistrationObject) = Type("MetadataObject") Then
		Characteristics = MetadataCharacteristics(RegistrationObject);
		If Characteristics.IsReference Then
			
			Selection = Characteristics.Manager.Select();
			While Selection.Next() Do
				DataExchangeEventsModule.RecordDataChanges(Node, Selection.Ref, ThisObject.ObjectExportControlSetting);
			EndDo;
			
			Return;
		EndIf;
	EndIf;
	
	// Regular object
	DataExchangeEventsModule.RecordDataChanges(Node, RegistrationObject, ThisObject.ObjectExportControlSetting);
EndProcedure

// Returns a managed form that contains a passed form item.
//
Function FormItemForm(FormItem)
	Result    = FormItem;
	FormTypes = New TypeDescription("ManagedForm");
	While Not FormTypes.ContainsType(TypeOf(Result)) Do
		Result = Result.Parent;
	EndDo;
	Return Result;
EndFunction

// Generates a metadata tree level that contains a single metadata group (for example, catalogs).
//
Procedure GenerateMetadataLevel(CurrentLineNumber, Parameters, PictureIndex, NodePictureIndex, AddSubordinate, MetaName, MetaPresentation)
	
	LevelPresentations = New Array;
	AutoRecords        = New Array;
	LevelNames         = New Array;
	
	AllRows  = Parameters.Rows;
	MetaPlan = Parameters.ExchangePlan;
	
	GroupRow = AllRows.Add();
	GroupRow.RowID = CurrentLineNumber;
	
	GroupRow.MetaFullName = MetaName;
	GroupRow.Description  = MetaPresentation;
	GroupRow.PictureIndex = PictureIndex;
	
	Rows = GroupRow.Rows;
	HadSubordinate = False;
	
	For Each Meta In Metadata[MetaName] Do
		
		If MetaPlan = Undefined Then
			// An exchange plan is not specified
			HadSubordinate = True;
			MetaFullName   = Meta.FullName();
			Description    = Meta.Presentation();
			If AddSubordinate Then
				NewRow = Rows.Add();
				NewRow.MetaFullName = MetaFullName;
				NewRow.Description  = Description ;
				NewRow.PictureIndex = NodePictureIndex;
				
				CurrentLineNumber = CurrentLineNumber + 1;
				NewRow.RowID = CurrentLineNumber;
			EndIf;	
			LevelNames.Add(MetaFullName);
			LevelPresentations.Add(Description);
			
		Else
			Item = MetaPlan.Content.Find(Meta);
			If Item <> Undefined Then
				HadSubordinate = True;
				MetaFullName   = Meta.FullName();
				Description    = Meta.Presentation();
				AutoRecord = ?(Item.AutoRecord = AutoChangeRecord.Deny, 1, 2);
				If AddSubordinate Then
					NewRow = Rows.Add();
					NewRow.MetaFullName = MetaFullName;
					NewRow.Description  = Description ;
					NewRow.PictureIndex = NodePictureIndex;
					NewRow.AutoRecord   = AutoRecord;
					
					CurrentLineNumber = CurrentLineNumber + 1;
					NewRow.RowID = CurrentLineNumber;
				EndIf;
				LevelNames.Add(MetaFullName);
				LevelPresentations.Add(Description);
				AutoRecords.Add(AutoRecord);
			EndIf;
		EndIf;
		
	EndDo;
	
	If HadSubordinate Then
		Rows.Sort("Description");
		Parameters.NameStructure.Insert(MetaName, LevelNames);
		Parameters.PresentationStructure.Insert(MetaName, LevelPresentations);
		If Not AddSubordinate Then
			Parameters.AutoRecordStructure.Insert(MetaName, AutoRecords);
		EndIf;
	Else
		// Deleting rows that do not match the conditions
		AllRows.Delete(GroupRow);
	EndIf;
	
EndProcedure

// Accumulates registration results.
//
Procedure AddResults(Target, Source)
	Target.Done  = Target.Done + Source.Done;
	Target.Total = Target.Total   + Source.Total;
EndProcedure	

// Returns an array of additional objects to register. The array is filled according to flag values.
//
Function GetAdditionalRegistrationObjects(RegistrationObject, AutoRecordControlNode, WithoutAutoRecord, TableName = Undefined)
	Result = New Array;
	
	// Analyzing global parameters
	If (Not RegisterRecordAutoRecordSetting) And (Not SequenceAutoRecordSetting) Then
		Return Result;
	EndIf;
	
	ValueType = TypeOf(RegistrationObject);
	NamePassed = ValueType = Type("String");
	If NamePassed Then
		Details = MetadataCharacteristics(RegistrationObject);
	ElsIf ValueType = Type("Structure") Then
		Details = MetadataCharacteristics(TableName);
		If Details.IsSequence Then
			Return Result;
		EndIf;
	Else
		Details = MetadataCharacteristics(RegistrationObject.Metadata());
	EndIf;
	
	MetaObject = Details.Metadata;
	
	// Filling a collection recursively	
	If Details.IsCollection Then
		For Each Meta In MetaObject Do
			AdditionalSet = GetAdditionalRegistrationObjects(Meta.FullName(), AutoRecordControlNode, WithoutAutoRecord, TableName);
			For Each Item In AdditionalSet Do
				Result.Add(Item);
			EndDo;
		EndDo;
		Return Result;
	EndIf;
	
	// Registering metadata objects one by one
	NodeContent = AutoRecordControlNode.Metadata().Content;
	
	// Documents may affect sequences and register records
	If Metadata.Documents.Contains(MetaObject) Then
		
		If RegisterRecordAutoRecordSetting Then
			For Each Meta In MetaObject.RegisterRecords Do
				
				ContentItem = NodeContent.Find(Meta);
				If ContentItem <> Undefined And (WithoutAutoRecord Or ContentItem.AutoRecord = AutoChangeRecord.Allow) Then
					If NamePassed Then
						Result.Add(Meta);
					Else
						Details = MetadataCharacteristics(Meta);
						Set = Details.Manager.CreateRecordSet();
						Set.Filter.Recorder.Set(RegistrationObject);
						Set.Read();
						Result.Add(Set);
						// Checking the passed set recursively
						AdditionalSet = GetAdditionalRegistrationObjects(Set, AutoRecordControlNode, WithoutAutoRecord, TableName);
						For Each Item In AdditionalSet Do
							Result.Add(Item);
						EndDo;
					EndIf;
				EndIf;
				
			EndDo;
		EndIf;
		
		If SequenceAutoRecordSetting Then
			For Each Meta In Metadata.Sequences Do
				
				Details = MetadataCharacteristics(Meta);
				If Meta.Documents.Contains(MetaObject) Then
					// A sequence is to be registered for a specific document type
					ContentItem = NodeContent.Find(Meta);
					If ContentItem <> Undefined And (WithoutAutoRecord Or ContentItem.AutoRecord = AutoChangeRecord.Allow) Then
						// Registering data for the current node
						If NamePassed Then
							Result.Add(Meta);
						Else
							Set = Details.Manager.CreateRecordSet();
							Set.Filter.Recorder.Set(RegistrationObject);
							Set.Read();
							Result.Add(Set);
						EndIf;
					EndIf;
				EndIf;
				
			EndDo;
			
		EndIf;
		
	// Register records may affect sequences
	ElsIf SequenceAutoRecordSetting And (
		Metadata.InformationRegisters.Contains(MetaObject)
		Or Metadata.AccumulationRegisters.Contains(MetaObject)
		Or Metadata.AccountingRegisters.Contains(MetaObject)
		Or Metadata.CalculationRegisters.Contains(MetaObject)
	) Then
		For Each Meta In Metadata.Sequences Do
			If Meta.RegisterRecords.Contains(MetaObject) Then
				// A sequence is to be registered for a register record set
				ContentItem = NodeContent.Find(Meta);
				If ContentItem <> Undefined And (WithoutAutoRecord Or ContentItem.AutoRecord = AutoChangeRecord.Allow) Then
					Result.Add(Meta);
				EndIf;
			EndIf;
		EndDo;
		
	EndIf;
	
	Return Result;
EndFunction

// Converts a string value to a number value.
// 
// Parameters:
//     Text - String - string presentation of a number.
// 
// Returns:
//     Number    - converted string. 
//     Undefined - if a passed string cannot be converted.
//
Function StringIntoNumber(Val Text)
	NumberText = TrimAll(StrReplace(Text, Chars.NBSp, ""));
	
	If IsBlankString(NumberText) Then
		Return 0;
	EndIf;
	
	// Excluding leading zeroes
	Position = 1;
	While Mid(NumberText, Position, 1) = "0" Do
		Position = Position + 1;
	EndDo;
	NumberText = Mid(NumberText, Position);
	
	// Checking whether there is a default result
	If NumberText = "0" Then
		Result = 0;
	Else
		NumberType = New TypeDescription("Number");
		Result = NumberType.AdjustValue(NumberText);
		If Result = 0 Then
			// The default result was processed earlier, this is a conversion error
			Result = Undefined;
		EndIf;
	EndIf;
	
	Return Result;
EndFunction

// Returns a common module or Undefined if it is not found by name.
//
Function CommonUseCommonModule(Val ModuleName)
	
	If Metadata.CommonModules.Find(ModuleName) = Undefined Then
		Return Undefined;
	EndIf;
	
	SetSafeMode(True);
	Result = Eval(ModuleName);
	SetSafeMode(False);
	
	Return Result;
EndFunction

// Returns a flag that shows whether the SL version used in the configuration 
// supports the required functionality.
//
Function SL_RequiredVersionAvailable(Val Version = Undefined) Export
	
	CurrentVersion = Undefined;
	StandardSubsystemsServerModule = CommonUseCommonModule("StandardSubsystemsServer");
	If StandardSubsystemsServerModule <> Undefined Then
		Try
			CurrentVersion = StandardSubsystemsServerModule.LibVersion();
		Except
			CurrentVersion = Undefined;
		EndTry;
	EndIf;
	
	If CurrentVersion = Undefined Then
		// Error calling the StandardSubsystemsServerModule.LibVersion() method.
		Return False
	EndIf;
	CurrentVersion = StrReplace(CurrentVersion, ".", Chars.LF);
	
	RequiredVersion = StrReplace(?(Version = Undefined, "2.1.2", Version), ".", Chars.LF);
	
	For Index = 1 To StrLineCount(RequiredVersion) Do
		
		CurrentVersionPart = StringIntoNumber(StrGetLine(CurrentVersion, Index));
		RequiredVersionPart  = StringIntoNumber(StrGetLine(RequiredVersion,  Index));
		
		If CurrentVersionPart = Undefined Then
			Return False;
			
		ElsIf CurrentVersionPart > RequiredVersionPart Then
			Return True;
			
		ElsIf CurrentVersionPart < RequiredVersionPart Then
			Return False;
			
		EndIf;
	EndDo;
	
	Return True;
EndFunction

// Returns a flag that shows whether object export is allowed in SL.
//
Function SL_ObjectExportControl(Node, RegistrationObject)
	
	Sending = DataItemSend.Auto;
	DataExchangeEventsModule = CommonUseCommonModule("DataExchangeEvents");
	If DataExchangeEventsModule <> Undefined Then
		DataExchangeEventsModule.DataOnSendToRecipient(RegistrationObject, Sending, , Node);
		Return Sending = DataItemSend.Auto;
	EndIf;
	
	// Unknown SL version
	Return True;
EndFunction

// Checks whether a reference change can be registered in SL.
// Returns a structure with the Total and Done fields that show the registration state.
//
Function SL_RefChangeRegistration(Node, Ref, WithoutAutoRecord = True)
	
	Result = New Structure("Total, Done", 0, 0);
	
	If WithoutAutoRecord Then
		NodeContent = Undefined;
	Else
		NodeContent = Node.Metadata().Content;
	EndIf;
	
	ContentItem = ?(NodeContent = Undefined, Undefined, NodeContent.Find(Ref.Metadata()));
	If ContentItem = Undefined Or ContentItem.AutoRecord = AutoChangeRecord.Allow Then
		// Getting an object by reference
		Result.Total = 1;
		RegistrationObject = Ref.GetObject();
		// RegistrationObject value is Undefined if a passed reference is invalid
		If RegistrationObject = Undefined Or SL_ObjectExportControl(Node, RegistrationObject) Then
			ExecuteObjectRegistrationCommand(True, Node, Ref);
			Result.Done = 1;
		EndIf;
		RegistrationObject = Undefined;
	EndIf;	
	
	// Adding additional registration objects
	If Result.Done > 0 Then
		For Each Item In GetAdditionalRegistrationObjects(Ref, Node, WithoutAutoRecord) Do
			Result.Total = Result.Total + 1;
			If SL_ObjectExportControl(Node, Item) Then
				ExecuteObjectRegistrationCommand(True, Node, Item);
				Result.Done = Result.Done + 1;
			EndIf;
		EndDo;
	EndIf;
	
	Return Result;
EndFunction

// Checks whether a record set change can be registered in SL.
// Returns a structure with the Total and Done fields that show the registration state.
//
Function SL_SetChangeRegistration(Node, FieldStructure, Details, WithoutAutoRecord = True)
	
	Result = New Structure("Total, Done", 0, 0);
	
	If WithoutAutoRecord Then
		NodeContent = Undefined;
	Else
		NodeContent = Node.Metadata().Content;
	EndIf;
	
	ContentItem = ?(NodeContent = Undefined, Undefined, NodeContent.Find(Details.Metadata));
	If ContentItem = Undefined Or ContentItem.AutoRecord = AutoChangeRecord.Allow Then
		Result.Total = 1;
		
		Set = Details.Manager.CreateRecordSet();
		For Each KeyValue In FieldStructure Do
			Set.Filter[KeyValue.Key].Set(KeyValue.Value);
		EndDo;
		Set.Read();
		
		If SL_ObjectExportControl(Node, Set) Then
			ExecuteObjectRegistrationCommand(True, Node, Set);
			Result.Done = 1;
		EndIf;
		
	EndIf;
	
	// Adding additional registration objects
	If Result.Done > 0 Then
		For Each Item In GetAdditionalRegistrationObjects(Set, Node, WithoutAutoRecord) Do
			Result.Total = Result.Total + 1;
			If SL_ObjectExportControl(Node, Item) Then
				ExecuteObjectRegistrationCommand(True, Node, Item);
				Result.Done = Result.Done + 1;
			EndIf;
		EndDo;
	EndIf;
	
	Return Result;
EndFunction

// Checks whether a constant change can be registered in SL.
// Returns a structure with the Total and Done fields that show the registration state.
//
Function SL_ConstantChangeRegistration(Node, Details, WithoutAutoRecord = True)
	
	Result = New Structure("Total, Done", 0, 0);
	
	If WithoutAutoRecord Then
		NodeContent = Undefined;
	Else
		NodeContent = Node.Metadata().Content;
	EndIf;
	
	ContentItem = ?(NodeContent = Undefined, Undefined, NodeContent.Find(Details.Metadata));
	If ContentItem = Undefined Or ContentItem.AutoRecord = AutoChangeRecord.Allow Then
		Result.Total = 1;
		
		RegistrationObject = Details.Manager.CreateValueManager();
		
		If SL_ObjectExportControl(Node, RegistrationObject) Then
			ExecuteObjectRegistrationCommand(True, Node, RegistrationObject);
			Result.Done = 1;
		EndIf;
		
	EndIf;	
	
	Return Result;
EndFunction

// Checks whether a metadata set change can be registered in SL.
// Returns a structure with the Total and Done fields that show the registration state.
//
Function SL_MetadataChangeRegistration(Node, Details, WithoutAutoRecord)
	
	Result = New Structure("Total, Done", 0, 0);
	
	If Details.IsCollection Then
		For Each MetaKind In Details.Metadata Do
			CurDetails = MetadataCharacteristics(MetaKind);
			AddResults(Result, SL_MetadataChangeRegistration(Node, CurDetails, WithoutAutoRecord) );
		EndDo;
	Else;
		AddResults(Result, SL_MetadataObjectChangeRegistration(Node, Details, WithoutAutoRecord) );
	EndIf;
	
	Return Result;
EndFunction

// Checks whether a metadata object change can be registered in SL.
// Returns a structure with the Total and Done fields that show the registration state.
//
Function SL_MetadataObjectChangeRegistration(Node, Details, WithoutAutoRecord)
	
	Result = New Structure("Total, Done", 0, 0);
	
	ContentItem = Node.Metadata().Content.Find(Details.Metadata);
	If ContentItem = Undefined Then
		// Cannot execute registration
		Return Result;
	EndIf;
	
	If (Not WithoutAutoRecord) And ContentItem.AutoRecord <> AutoChangeRecord.Allow Then
		// Autorecord is not supported
		Return Result;
	EndIf;
	
	CurTableName = Details.TableName;
	If Details.IsConstant Then
		AddResults(Result, SL_ConstantChangeRegistration(Node, Details) );
		Return Result;
		
	ElsIf Details.IsReference Then
		DimensionFields = "Ref";
		
	ElsIf Details.IsSet Then
		DimensionFields = "";
		For Each Row In RecordSetDimensions(CurTableName) Do
			DimensionFields = DimensionFields + "," + Row.Name
		EndDo;
		DimensionFields = Mid(DimensionFields, 2);
		
	Else
		Return Result;
	EndIf;
	
	Query = New Query("
		|SELECT DISTINCT 
		|	" + ?(IsBlankString(DimensionFields), "*", DimensionFields) + "
		|FROM 
		|	" + CurTableName + "
		|");
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If Details.IsSet Then
			Data = New Structure(DimensionFields);
			FillPropertyValues(Data, Selection);
			AddResults(Result, SL_SetChangeRegistration(Node, Data, Details) );
		ElsIf Details.IsReference Then
			AddResults(Result, SL_RefChangeRegistration(Node, Selection.Ref, WithoutAutoRecord) );
		EndIf;
	EndDo;

	Return Result;
EndFunction

// Updates MOID data and registers data for a passed node.
//
Function SL_UpdateAndRegisterMainNodeMetadataObjectID(Val Node) Export
	
	Result = New Structure("Total, Done", 0 , 0);
	
	MetaNodeExchangePlan = Node.Metadata();
	
	If (Not DIBModeAvailable)                           // The current SL version does not support processing of MOID
		Or (ExchangePlans.MasterNode() <> Undefined)      // The current infobase is a subordinate node
		Or (Not MetaNodeExchangePlan.DistributedInfobase) // A passed node is not a DIB one
	Then 
		Return Result;
	EndIf;
	
	// Updating application parameters
	StandardSubsystemsServerModule = CommonUseCommonModule("StandardSubsystemsServer");
	StandardSubsystemsServerModule.UpdateApplicationParameters();
	
	// If a passed node is included in a DIB, registering all changes without checking of SL rules
	
	// Registering changes for the MetadataObjectIDs catalog items
	MetaCatalog = Metadata.Catalogs["MetadataObjectIDs"];
	If MetaNodeExchangePlan.Content.Contains(MetaCatalog) Then
		ExchangePlans.RecordChanges(Node, MetaCatalog);
		
		Query = New Query("SELECT COUNT(Ref) AS ItemCount FROM Catalog.MetadataObjectIDs");
		Result.Done = Query.Execute().Unload()[0].ItemCount;
	EndIf;
	
	// Registering predefined item changes
	Result.Done = Result.Done 
		+ RegisterPredefinedObjectChangeForNode(Node, Metadata.Catalogs)
		+ RegisterPredefinedObjectChangeForNode(Node, Metadata.ChartsOfCharacteristicTypes)
		+ RegisterPredefinedObjectChangeForNode(Node, Metadata.ChartsOfAccounts)
		+ RegisterPredefinedObjectChangeForNode(Node, Metadata.ChartsOfCalculationTypes);
	
	Result.Total = Result.Done;
	Return Result;
EndFunction

Function RegisterPredefinedObjectChangeForNode(Val Node, Val MetadataCollection)
	
	NodeContent = Node.Metadata().Content;
	Result      = 0;
	Query       = New Query;
	
	For Each MetadataObject In MetadataCollection Do
		If NodeContent.Contains(MetadataObject) Then
			
			Query.Text = "
				|SELECT
				|	Ref
				|FROM
				|	" + MetadataObject.FullName() + "
				|WHERE
				|	Predefined";
			Selection = Query.Execute().Select();
			
			Result = Result + Selection.Count();
			
			// If a passed node is included in a DIB, registering all changes without checking of SL rules
			While Selection.Next() Do
				ExchangePlans.RecordChanges(Node, Selection.Ref);
			EndDo;
			
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

#EndRegion

#EndIf
