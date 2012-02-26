
&AtServer
Var mTree, mAlreadyInList;

&AtServer
Var mDocumentAttributesCache;

///////////////////////////////////////////////////////////////////////////////
// COMMON PROCEDURES AND FUNCTIONS

&AtServer
// Procedure outputs document subordiantion structure tree.
//
Procedure DisplayDocumentTree()
	
	Try
	DocumentTree.GetItems().Clear();
	mTree			 		 = DocumentTree;	
	mAlreadyInList   		 = New Map;
 	mDocumentAttributesCache = New Map;

	OutputParentDocuments(DocumentRef);	
	
	OutputSubordinateDocuments(mTree);
	
	Except
	EndTry;
	
EndProcedure

&AtServer
// Procedure outputs parent documents.
//
Procedure OutputParentDocuments(DocumentRef)
	
	DocumentMetadata = DocumentRef.Metadata();
	ListOfAttributes = New ValueList;
	
	For Each Attribute IN DocumentMetadata.Attributes Do
		AttributeTypes = Attribute.Type.Types();
		For Each CurrentType IN AttributeTypes Do
			AttributeMetadata = Metadata.FindByType(CurrentType);
					
			If AttributeMetadata<>Undefined And Metadata.Documents.Contains(AttributeMetadata) 
				 And AccessRight("Read", AttributeMetadata) Then
				Try
					DetailsValue = DocumentRef[Attribute.Name];
				Except
					Break;
				EndTry;
				If DetailsValue<>Undefined And NOT DetailsValue.IsEmpty() And TypeOf(DetailsValue) = CurrentType 
					 And mAlreadyInList[DetailsValue] = Undefined And ListOfAttributes.FindByValue(DocumentRef[Attribute.Name]) = Undefined Then
					Try
						ListOfAttributes.Add(DetailsValue,Format(DetailsValue.Date,"DF=yyyyMMddCcmMss"));
					Except
						 DebuggingErrorText = ErrorDescription();
					EndTry;	
				EndIf;
			EndIf;			
			
		EndDo;
	EndDo;
	
	For Each TS In DocumentMetadata.TabularSections Do
		StrOfAttributes = "";
		
		Try
			TSContent = DocumentRef[TS.Name].Unload();
		Except
			Break;
		EndTry;
		
		For Each Attribute IN TS.Attributes Do
			AttributeTypes = Attribute.Type.Types();
			For Each CurrentType IN AttributeTypes Do
				AttributeMetadata = Metadata.FindByType(CurrentType);				
				If AttributeMetadata<>Undefined And Metadata.Documents.Contains(AttributeMetadata) 
					And AccessRight("Read", AttributeMetadata) Then
					StrOfAttributes = StrOfAttributes + ?(StrOfAttributes = "", "", ", ") + Attribute.Name;
					Break;
				EndIf;						
			EndDo;
		EndDo;
		
		TSContent.GroupBy(StrOfAttributes);
		For Each TSColumn IN TSContent.Columns Do
			For Each TSLine IN TSContent Do
				Try
					DetailsValue = TSLine[TSColumn.Name];
				Except
					Continue;
				EndTry;
				ValueMetadata = Metadata.FindByType(TypeOf(DetailsValue));
				If ValueMetadata = Undefined Then
					// base type
					Continue;
				EndIf;
				
				If DetailsValue<>Undefined And NOT DetailsValue.IsEmpty()
					 And Metadata.Documents.Contains(ValueMetadata)
					 And mAlreadyInList[DetailsValue] = Undefined Then
					If ListOfAttributes.FindByValue(DetailsValue) = Undefined Then
						Try
							ListOfAttributes.Add(DetailsValue,Format(DetailsValue.Date,"DF=yyyyMMddCcmMss"));
						Except
							DebuggingErrorText = ErrorDescription();
						EndTry;
					EndIf;
				EndIf;
			EndDo;
		EndDo;		
	EndDo;
	ListOfAttributes.SortByPresentation();
	mAlreadyInList.Insert(DocumentRef, True);
	
	If ListOfAttributes.Count() = 1 Then
		OutputParentDocuments(ListOfAttributes[0].Value);
	ElsIf ListOfAttributes.Count() > 1 Then
		DisplayWithoutParents(ListOfAttributes);		
	EndIf;

	
	TreeRow = mTree.GetItems().Add();
	Query = New Query("SELECT ALLOWED Ref, Posted, DeletionMark, Presentation, #Currency, #Sum, """ + DocumentMetadata.Name + """ AS Metadata
						   | FROM Document."+DocumentMetadata.Name + " WHERE Ref = &Ref");
						   
	If DocumentMetadata.Attributes.Find("DocumentCurrency") <> Undefined Then
		Query.Text = StrReplace(Query.Text, "#Currency", "DocumentCurrency AS DocumentCurrency");
	ElsIf DocumentMetadata.Attributes.Find("CashAssetsCurrency") <> Undefined Then
		Query.Text = StrReplace(Query.Text, "#Currency", "CashAssetsCurrency AS DocumentCurrency");
	Else
		Query.Text = StrReplace(Query.Text, "#Currency", "NULL AS DocumentCurrency");
	EndIf;
	
	If DocumentMetadata.Attributes.Find("DocumentAmount") <> Undefined Then
		Query.Text = StrReplace(Query.Text, "#Sum", "DocumentAmount AS DocumentAmount");
	Else
		Query.Text = StrReplace(Query.Text, "#Sum", "0 AS DocumentAmount");
	EndIf;
						   
	Query.SetParameter("Ref", DocumentRef);
	
	Selection  = Query.Execute().Choose();
	If Selection.Next() Then		
		TreeRow.Ref						= Selection.Ref;
		TreeRow.DocumentPresentation 	= Selection.Presentation;
		TreeRow.DocumentKind 			= Selection.Metadata;
		TreeRow.DocumentCurrency 		= Selection.DocumentCurrency;
		TreeRow.DocumentAmount 			= Selection.DocumentAmount;
		TreeRow.Posted 					= Selection.Posted;
		TreeRow.DeletionMark 			= Selection.DeletionMark;
		TreeRow.Picture 				= PictureNo(TreeRow);
		TreeRow.PostingAllowed 			= Selection.Ref.Metadata().Posting = Metadata.ObjectProperties.Posting.Allow;
	Else
		TreeRow.Ref						= DocumentRef;
		TreeRow.DocumentPresentation 	= String(DocumentRef);
		TreeRow.DocumentCurrency 		= Selection.DocumentCurrency;
		TreeRow.DocumentAmount 			= Selection.DocumentAmount;
		TreeRow.Posted 					= Selection.Posted;
		TreeRow.DeletionMark 			= Selection.DeletionMark;
		TreeRow.Picture 				= PictureNo(TreeRow);
		TreeRow.PostingAllowed 			= DocumentRef.Metadata().Posting = Metadata.ObjectProperties.Posting.Allow;
	EndIf;
	
	mTree = TreeRow;
		
EndProcedure

&AtServer
// Procedure outputs parent documents with limit by level in tree.
//
Procedure DisplayWithoutParents(ListOfDocuments)
	
	For Each ItemOfList In ListOfDocuments Do
		
		DocumentMetadata = ItemOfList.Value.Metadata();
		
		Query = New Query("SELECT ALLOWED Ref, Posted, DeletionMark, Presentation, #Currency, #Sum, """ + DocumentMetadata.Name + """ AS Metadata
		| FROM Document."+DocumentMetadata.Name + " WHERE Ref = &Ref");
		
		If DocumentMetadata.Attributes.Find("DocumentCurrency") <> Undefined Then
			Query.Text = StrReplace(Query.Text, "#Currency", "DocumentCurrency AS DocumentCurrency");
		ElsIf DocumentMetadata.Attributes.Find("CashAssetsCurrency") <> Undefined Then
			Query.Text = StrReplace(Query.Text, "#Currency", "CashAssetsCurrency AS DocumentCurrency");
		Else
			Query.Text = StrReplace(Query.Text, "#Currency", "NULL AS DocumentCurrency");
		EndIf;
		
		If DocumentMetadata.Attributes.Find("DocumentAmount") <> Undefined Then
			Query.Text = StrReplace(Query.Text, "#Sum", "DocumentAmount AS DocumentAmount");
		Else
			Query.Text = StrReplace(Query.Text, "#Sum", "0 AS DocumentAmount");
		EndIf;
						   
	Query.SetParameter("Ref", ItemOfList.Value);
		
		Selection  = Query.Execute().Choose();
		If Selection.Next() Then		
			If mAlreadyInList[Selection.Ref] = Undefined Then
	            TreeRow 							= mTree.GetItems().Add();
				TreeRow.Ref							= Selection.Ref;
				TreeRow.DocumentCurrency			= Selection.DocumentCurrency;
				TreeRow.DocumentAmount				= Selection.DocumentAmount;
				TreeRow.DocumentPresentation 		= Selection.Presentation;
				TreeRow.DocumentKind 				= Selection.Metadata;
				TreeRow.Posted 						= Selection.Posted;
				TreeRow.DeletionMark 				= Selection.DeletionMark;			
				TreeRow.RestrictionByParents 		= True;
				TreeRow.Picture 					= PictureNo(TreeRow);
				mAlreadyInList.Insert(Selection.Ref, True);
			EndIf;
		EndIf;		
	EndDo;

	mTree = TreeRow;
	
EndProcedure

&AtServer
// Procedure outputs subordinate documents.
//
Procedure OutputSubordinateDocuments(TreeRow)
	
	CurrentDocument 	 = TreeRow.Ref;	
	Table 				 = GetSubordinateDocumentsList(CurrentDocument);	
	CacheByDocumentTypes = New Map;
	
	For Each TableRow IN Table Do
		DocumentMetadata = TableRow.Ref.Metadata();
		If NOT AccessRight("Read", DocumentMetadata) Then
			Continue;
		EndIf;			
		DocumentName 	= DocumentMetadata.Name;
		DocumentSynonym = DocumentMetadata.Synonym;
				
		SupplementMetadataCache(DocumentMetadata, DocumentName);
		
		TypeStructure 	= CacheByDocumentTypes[DocumentName];
		If TypeStructure = Undefined Then
			TypeStructure = New Structure("Synonym, RefsArray", DocumentSynonym, New Array);
			CacheByDocumentTypes.Insert(DocumentName, TypeStructure);
		EndIf;
		TypeStructure.RefsArray.Add(TableRow.Ref);		
	EndDo;
	
	If CacheByDocumentTypes.Count() = 0 Then
		Return;
	EndIf;
	
	QueryTextBegin = "SELECT ALLOWED * FROM (";
	QueryTextEnd = ") AS SubordinateDocuments ORDER BY SubordinateDocuments.Date";
	Query = New Query;
	For Each KeyAndValue IN CacheByDocumentTypes Do
		Query.Text = Query.Text + ?(Query.Text = "", "
					|SELECT ", "
					|UNION ALL
					|SELECT") + "
					|Date, Ref, Posted, DeletionMark, Presentation,  """ + KeyAndValue.Key + """ AS Metadata, #Currency, #Sum 
					|FROM Document." 	+ KeyAndValue.Key + "
					|WHERE Ref In (&" 	+ KeyAndValue.Key + ")";
					
		If mDocumentAttributesCache[KeyAndValue.Key]["DocumentCurrency"] Then
			Query.Text = StrReplace(Query.Text, "#Currency", "DocumentCurrency AS DocumentCurrency");
		ElsIf mDocumentAttributesCache[KeyAndValue.Key]["CashAssetsCurrency"] Then
			Query.Text = StrReplace(Query.Text, "#Currency", "CashAssetsCurrency AS DocumentCurrency");
		Else
			Query.Text = StrReplace(Query.Text, "#Currency", "NULL AS DocumentCurrency");
		EndIf;
		
		If mDocumentAttributesCache[KeyAndValue.Key]["DocumentAmount"] Then
			Query.Text = StrReplace(Query.Text, "#Sum", "DocumentAmount AS DocumentAmount");
		Else
			Query.Text = StrReplace(Query.Text, "#Sum", "0 AS DocumentAmount");
		EndIf;			
					
		Query.SetParameter(KeyAndValue.Key, KeyAndValue.Value.RefsArray);		
	EndDo;
	
	Query.Text = QueryTextBegin + Query.Text + QueryTextEnd;
	
	Selection = Query.Execute().Choose();	
	While Selection.Next() Do
		If mAlreadyInList[Selection.Ref] = Undefined Then
			NewRow 						= TreeRow.GetItems().Add();
			NewRow.Ref 					= Selection.Ref;
			NewRow.DocumentAmount 		= Selection.DocumentAmount;
			NewRow.DocumentCurrency 	= Selection.DocumentCurrency;
			NewRow.DocumentPresentation = Selection.Presentation;
			NewRow.Posted 				= Selection.Posted;
			NewRow.DeletionMark 		= Selection.DeletionMark;
			NewRow.Picture 				= PictureNo(NewRow);
			mAlreadyInList.Insert(Selection.Ref, True);
			OutputSubordinateDocuments(NewRow);
			NewRow.DocumentKind 		= Selection.Metadata;
			NewRow.PostingAllowed 		= Selection.Ref.Metadata().Posting = Metadata.ObjectProperties.Posting.Allow;
		EndIf;
	EndDo;		
EndProcedure

&AtClient                                                                                       
// Procedure current document opens form.
//
Procedure OpenDocumentForm()
	
	Try
		
		OpeningStructure = New Structure("Key", Items.DocumentTree.CurrentData.Ref);
	   	Form 			 = GetForm("Document." + Items.DocumentTree.CurrentData.DocumentKind + ".ObjectForm", OpeningStructure);
		
		If Items.DocumentTree.CurrentData.Ref = DocumentRef And Form.IsOpen() Then
			Message 	 = New UserMessage();
			Message.Text = NStr("en = 'Document is already opened!'");
			Message.Message();
		EndIf; 
		
		Form.Open();
		
	Except
		
		StandardSubsystemsServer.ShowErrorMessage(DocumentRef, ErrorDescription());
		
	EndTry;
	
EndProcedure

&AtServer                                                                                       
// Function searches subordinate documents of current document.
//
Function GetSubordinateDocumentsList(Basis) Export
		
	Query = New Query;
	QueryText = "";
	
	For Each ContentItem IN Metadata.FilterCriteria.HierarchyStructure.Content Do
		
		DataPath = ContentItem.FullName();
		StructureDataPath = ParsePathToMetadataObject(DataPath);
		
		If NOT AccessRight("Read", StructureDataPath.Metadata) Then
			Continue;
		EndIf;
		
		ObjectName = StructureDataPath.ObjectType + "." + StructureDataPath.ObjectKind;
		
		CurrentRowWhere = "WHERE " + StructureDataPath.ObjectKind + "." +StructureDataPath.AttributeName + " = &SelectionCriteriaValue";
			
		TSName = Left(StructureDataPath.AttributeName, Find(StructureDataPath.AttributeName, ".")-1);
		AttributeName = Left(StructureDataPath.AttributeName, Find(StructureDataPath.AttributeName, ".")-1);
		QueryText = QueryText + ?(QueryText = "", "SELECT ALLOWED", "UNION
		|SELECT") + "
		|" + StructureDataPath.ObjectKind +".Ref FROM " + ObjectName + "." + StructureDataPath.TabulSectName + " AS " + StructureDataPath.ObjectKind + "
		|" + StrReplace(CurrentRowWhere, "..", ".") + "
		|";
		
	EndDo;
	
	Query.Text = QueryText;
	Query.SetParameter("SelectionCriteriaValue", Basis);
	Return Query.Execute().Unload();
	
EndFunction

&AtServer
// Function returns path to metadata object
// MetadataObjectType.DocumentName.TabularSection.TabularSectionName.Attribute.AttributeName.
// MetadataObjectType should be Catalog or Document.
//
// Parameters:
//  DataPath  - string.
//
// Value returned:
//  Structure - path to metadata object
//
Function ParsePathToMetadataObject(DataPath) Export
	
	Structure = New Structure;
	
	MapOfNames = New Array();
	MapOfNames.Add("ObjectType");
	MapOfNames.Add("ObjectKind");
	MapOfNames.Add("DataPath");
	MapOfNames.Add("TabulSectName");
	MapOfNames.Add("AttributeName");
	
	For indexOf = 1 to 3 Do
		
		Point 			= Find(DataPath, ".");
		CurrentValue 	= Left(DataPath, Point-1);
		Structure.Insert(MapOfNames[indexOf-1], CurrentValue);
		DataPath 		= Mid(DataPath, Point+1);
		
	EndDo;
	
	DataPath = StrReplace(DataPath, "Attribute.", "");
	
	If Structure.DataPath = "TabularSection" Then
		
		For indexOf = 4 to 5  Do 
			
			Point = Find(DataPath, ".");
			If Point = 0 Then
				CurrentValue = DataPath;
			Else
				CurrentValue = Left(DataPath, Point-1);
			EndIf;
			
			Structure.Insert(MapOfNames[indexOf-1], CurrentValue);
			DataPath = Mid(DataPath,  Point+1);
			
		EndDo;
		
	Else
		
		Structure.Insert(MapOfNames[3], "");
		Structure.Insert(MapOfNames[4], DataPath);
		
	EndIf;
	
	If Structure.ObjectType = "Document" Then
		Structure.Insert("Metadata", Metadata.Documents[Structure.ObjectKind]);
	Else
		Structure.Insert("Metadata", Metadata.Catalogs[Structure.ObjectKind]);
	EndIf;
	
	Return Structure;
	
EndFunction // ParsePathToMetadataObject()

&AtClient                                                                                       
// Procedure closes form showing warning.
//
Procedure CloseFormWithWarning(WarningText)
	
	ThisForm.Close();
	DoMessageBox(WarningText);
	
EndProcedure

&AtServer                                                                                       
// Procedure complements metadata cash.
//
Procedure SupplementMetadataCache(DocumentMetadata, DocumentName)
	
	DocumentAttributes = mDocumentAttributesCache[DocumentName];
	If DocumentAttributes = Undefined Then
		DocumentAttributes = New Map;		
		DocumentAttributes.Insert("DocumentCurrency", 	DocumentMetadata.Attributes.Find("DocumentCurrency") 	<> Undefined);		
		DocumentAttributes.Insert("CashAssetsCurrency", DocumentMetadata.Attributes.Find("CashAssetsCurrency")	<> Undefined);		
		DocumentAttributes.Insert("DocumentAmount", 	DocumentMetadata.Attributes.Find("DocumentAmount") 		<> Undefined);		
		mDocumentAttributesCache.Insert(DocumentName, 	DocumentAttributes);
	EndIf;
	
EndProcedure

&AtServer                                                                                       
// Function checks accessibility of the document being modified.
//
Function MainDocumentIsAvailableSofar()
	
	CurrentDocumentName = DocumentRef.Metadata().Name;
	Query = New Query;
	Query.Text = "SELECT ALLOWED Presentation FROM Document." + CurrentDocumentName + " WHERE Ref = &CurrentDocument";
	Query.SetParameter("CurrentDocument", DocumentRef);
	Return NOT Query.Execute().IsEmpty();
	
EndFunction

&AtClientAtServerNoContext                                                                                       
// Function returns picture number.
//
Function PictureNo(TreeRow)
	
	If TreeRow.DeletionMark Then
		Return 2;
	ElsIf TreeRow.Posted Then
		Return 1;
	Else	
	    Return 0;
	EndIf;
	
EndFunction

&AtClient                                                                                       
// Procedure updates accessibility of the buttons Post and Cancel posting.
//
Procedure RefreshButtonsAccessibility()
	
	Items.Post.       Enabled = Items.DocumentTree.CurrentData.PostingAllowed;
	Items.UndoPosting.Enabled = Items.DocumentTree.CurrentData.PostingAllowed;
	
EndProcedure 

&AtServer                                                                                       
// Function posts selected document.
//
Function PostServer(DocumentRef)
	
	Object = DocumentRef.GetObject();
	Try
	    Object.Lock();
		Object.Write(DocumentWriteMode.Posting, DocumentPostingMode.Regular);
		Object.Unlock();
	Except
		Message = New UserMessage();
		Message.Text = NStr("en = 'It is impossible to block the document'");
		Message.Message();
	EndTry; 

	Return Object.Posted;
	
EndFunction

&AtServer                                                                                       
// Function cancels posting for the selected document.
//
Function UndoPostingServer(DocumentRef)
	
	Object = DocumentRef.GetObject();
	Try
	    Object.Lock();
		Object.Write(DocumentWriteMode.UndoPosting);
		Object.Unlock();
	Except
		Message = New UserMessage();
		Message.Text = NStr("en = 'It is impossible to block the document'");
		Message.Message();
	EndTry; 

	Return Object.Posted;
	
EndFunction

&AtServer                                                                                       
// Function marks selected document for deletion.
//
Function SetDeletionMarkServer(DocumentRef)
	
	Object = DocumentRef.GetObject();
	Try
	    Object.Lock();
		Object.SetDeletionMark(NOT Object.DeletionMark);
		Object.Unlock();
	Except
		Message = New UserMessage();
		Message.Text = NStr("en = 'It is impossible to block the document'");
		Message.Message();
	EndTry; 

	Return Object.DeletionMark;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM EVENTS HANDLERS

&AtServer                                                                                       
// Procedure - handler of event OnCreateAtServer of form.
//
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	If Parameters.DocumentRef = Undefined OR Parameters.DocumentRef.IsEmpty() Then
		Cancellation = True;
		Return;
	EndIf;

	DocumentRef = Parameters.DocumentRef; 
	
	DisplayDocumentTree();

EndProcedure

&AtClient                                                                                       
// Procedure - handler of event OnOpen of form.
//
Procedure OnOpen(Cancellation)
	 
	Items.DocumentTree.CurrentRow = DocumentTree.GetItems()[0];

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM ITEMS EVENT HANDLERS

&AtClient
// Procedure - handler of event Before change of table box DocumentTree.
//
Procedure DocumentTreeBeforeRowChange(Item, Cancellation)	
	OpenDocumentForm();
	Cancellation = True;
EndProcedure

&AtClient                                                                                        
// Procedure - handler of event Open.
//
Procedure OpenDocument(Command)
	
	If Items.DocumentTree.CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpenDocumentForm();	 
	
EndProcedure

&AtClient                                                                                        
// Procedure - handler of event Refresh.
//
Procedure Refresh(Command)
	
	If MainDocumentIsAvailableSofar() Then
		DisplayDocumentTree(); 
	Else
		CloseFormWithWarning(NStr("en = 'Document for which structure report was generated, has been deleted or became inaccessible. '"));
	EndIf;		
	
	
EndProcedure

&AtClient                                                                                        
// Procedure - handler of event OutputForCurrent.
//
Procedure OutputForCurrent(Command)	
	
	If Items.DocumentTree.CurrentData = Undefined Then
		Return;
	EndIf;
	
	DocumentRef = Items.DocumentTree.CurrentData.Ref;
	If MainDocumentIsAvailableSofar() Then
		DocumentTree.GetItems().Clear();	
		DisplayDocumentTree();
	Else
		CloseFormWithWarning(NStr("en = 'Document for which structure report was generated, has been deleted or became inaccessible. '"));
	EndIf;
		
EndProcedure

&AtClient                                                                                        
// Procedure - handler of event FindInList.
//
Procedure FindInList(Command)	
	
	If Items.DocumentTree.CurrentData = Undefined Then
		Return;
	EndIf;
	
	Try
		ListForm = GetForm("Document." +Items .DocumentTree.CurrentData.DocumentKind + ".ListForm");
		ListForm.Items.List.CurrentRow = Items.DocumentTree.CurrentData.Ref;
		ListForm.Open();
	Except
		StandardSubsystemsServer.ShowErrorMessage(DocumentRef, ErrorDescription());
	EndTry;
	
EndProcedure

&AtClient                                                                                        
// Procedure - handler of event Post.
//
Procedure Post(Button)
		
	If Items.DocumentTree.CurrentData = Undefined Then
		Return;
	EndIf;
	
	Try       
		Items.DocumentTree.CurrentData.Posted = PostServer(Items.DocumentTree.CurrentData.Ref);
		Items.DocumentTree.CurrentData.Picture = PictureNo(Items.DocumentTree.CurrentData);
	Except
		
		Message = New UserMessage();
		Message.Text = NStr("en = 'Document posting failed %Document%!'");;
		Message.Text = StrReplace(Message.Text, "%Document%", Items.DocumentTree.CurrentData.DocumentPresentation);
		Message.Message();
		
	EndTry;
	
EndProcedure

&AtClient                                                                                        
// Procedure - handler of event Cancel posting.
//
Procedure UndoPosting(Button)
		
	If Items.DocumentTree.CurrentData = Undefined Then
		Return;
	EndIf;
	
	If NOT Items.DocumentTree.CurrentData.Posted Then
		Return;
	EndIf;
	
	Try
		Items.DocumentTree.CurrentData.Posted  = UndoPostingServer(Items.DocumentTree.CurrentData.Ref);
		Items.DocumentTree.CurrentData.Picture = PictureNo(Items.DocumentTree.CurrentData);
	Except
		
		Message = New UserMessage();
		Message.Text = NStr("en = 'Cancellation of document posting failed %Document%!'");;
		Message.Text = StrReplace(Message.Text, "%Document%", Items.DocumentTree.CurrentData.DocumentPresentation);
		Message.Message();
		
	EndTry;
	
EndProcedure

&AtClient                                                                                        
// Procedure - handler of event OnActivateRow of attribute DocumentTree.
//
Procedure DocumentTreeOnActivateRow(Item)
	RefreshButtonsAccessibility();	
EndProcedure

&AtClient                                                                                         
// Procedure - handler of event SetDeletionMark.
//
Procedure SetDeletionMark(Button)	
	
	If Items.DocumentTree.CurrentData = Undefined Then
		Return;
	EndIf;
	
	Try
		DeletionMark 								= SetDeletionMarkServer(Items.DocumentTree.CurrentData.Ref);
		Items.DocumentTree.CurrentData.DeletionMark = DeletionMark;
		Items.DocumentTree.CurrentData.Posted 		= False;
		Items.DocumentTree.CurrentData.Picture 		= PictureNo(Items.DocumentTree.CurrentData);
		RefreshButtonsAccessibility();
	Except
		
		Message = New UserMessage();
		Message.Text = NStr("en = 'Cannot set the deletion flag for document %Document%!'");;
		Message.Text = StrReplace(Message.Text, "%Document%", Items.DocumentTree.CurrentData.DocumentPresentation);
		Message.Message();
		
	EndTry;
	
EndProcedure

&AtClient
// Procedure - handler of event Selection of document tree.
//
Procedure DocumentTreeSelection(Item, RowSelected, Field, StandardProcessing)
	
	If Items.DocumentTree.CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpenDocumentForm();
	
EndProcedure










