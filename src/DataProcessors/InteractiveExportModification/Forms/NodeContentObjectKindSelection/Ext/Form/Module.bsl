
#Region FormEventHandlers
//

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
  // Skipping the initialization to guarantee that the form will be
  // received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	CloseOnOwnerClose = True;
	CloseOnChoice = False;
	
	Object.InfobaseNode = Parameters.InfobaseNode;
	
	SelectionTree = FormAttributeToValue("AvailableObjectKinds");
	SelectionTreeRows = SelectionTree.Rows;
	SelectionTreeRows.Clear();
	
	AllData = DataExchangeServer.NodeContentRefTables(Object.InfobaseNode);

	// If "NotExport" is set for some item, it is removed from AllData
	NotExportMode = Enums.ExchangeObjectExportModes.NotExport;
	ExportModes   = DataExchangeCached.UserExchangePlanContent(Object.InfobaseNode);
	Position = AllData.Count()-1;
	While Position>=0 Do
		DataRow = AllData[Position];
		If ExportModes[DataRow.FullMetadataName]=NotExportMode Then
			AllData.Delete(Position);
		EndIf;
		Position = Position - 1;
	EndDo;
	
	// Removing standard metadata picture
	AllData.FillValues(-1, "PictureIndex");
	
	AddAllObjects(AllData, SelectionTreeRows);
	
	ValueToFormAttribute(SelectionTree, "AvailableObjectKinds");
	
	ColumnsToSelect = "";
	For Each Attribute In GetAttributes("AvailableObjectKinds") Do
		ColumnsToSelect = ColumnsToSelect + "," + Attribute.Name;
	EndDo;
	ColumnsToSelect = Mid(ColumnsToSelect, 2);
	
EndProcedure

#EndRegion

#Region AvailableObjectKindFormTableElementEventHandlers

&AtClient
Procedure AvailableObjectKindSelection(Item, SelectedRow, Field, StandardProcessing)
	ExecuteSelection(SelectedRow);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OKCommand(Command)
	ExecuteSelection();
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Function ThisObject(NewObject=Undefined)
	If NewObject=Undefined Then
		Return FormAttributeToValue("Object");
	EndIf;
	ValueToFormAttribute(NewObject, "Object");
	Return Undefined;
EndFunction

&AtClient
Procedure ExecuteSelection(SelectedRow=Undefined)
	
	FormTable = Items.AvailableObjectKinds;
	ChoiceData = New Array;
	
	If SelectedRow=Undefined Then
		For Each Row In FormTable.SelectedRows Do
			ChoiceItem = New Structure(ColumnsToSelect);
			FillPropertyValues(ChoiceItem, FormTable.RowData(Row) );
			ChoiceData.Add(ChoiceItem);
		EndDo;
		
	ElsIf TypeOf(SelectedRow)=Type("Array") Then
		For Each Row In SelectedRow Do
			ChoiceItem = New Structure(ColumnsToSelect);
			FillPropertyValues(ChoiceItem, FormTable.RowData(Row) );
			ChoiceData.Add(ChoiceItem);
		EndDo;
		
	Else
		ChoiceItem = New Structure(ColumnsToSelect);
		FillPropertyValues(ChoiceItem, FormTable.RowData(SelectedRow) );
		ChoiceData.Add(ChoiceItem);
	EndIf;
	
	NotifyChoice(ChoiceData);
EndProcedure

&AtServer
Procedure AddAllObjects(AllRefNodeData, TargetRows)
	
	ThisDataProcessor = ThisObject();
	
	DocumentGroup = TargetRows.Add();
	DocumentGroup.ListPresentation = ThisDataProcessor.AllDocumentsFilterGroupTitle();
	DocumentGroup.FullMetadataName = ThisDataProcessor.AllDocumentsID();
	DocumentGroup.PictureIndex = 7;
	
	CatalogGroup = TargetRows.Add();
	CatalogGroup.ListPresentation = ThisDataProcessor.AllCatalogsFilterGroupTitle();
	CatalogGroup.FullMetadataName = ThisDataProcessor.AllCatalogsID();
	CatalogGroup.PictureIndex = 3;
	
	For Each Row In AllRefNodeData Do
		If Row.SelectPeriod Then
			FillPropertyValues(DocumentGroup.Rows.Add(), Row);
		Else
			FillPropertyValues(CatalogGroup.Rows.Add(), Row);
		EndIf;
	EndDo;
	
	// Deleting empty items
	If DocumentGroup.Rows.Count()=0 Then
		TargetRows.Delete(DocumentGroup);
	EndIf;
	If CatalogGroup.Rows.Count()=0 Then
		TargetRows.Delete(CatalogGroup);
	EndIf;
	
EndProcedure

#EndRegion
