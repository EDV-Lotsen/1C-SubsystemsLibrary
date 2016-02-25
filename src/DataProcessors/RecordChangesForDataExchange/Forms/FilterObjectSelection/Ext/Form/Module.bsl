
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	VerifyAccessRights("Administration", Metadata);
	
  // Skipping the initialization to guarantee that the form will be
  // received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	DataTableName = Parameters.TableName;
	CurrentObject = ThisObject();
	TableTitle  = "";
	
	// Determining what kind of table is passed to the procedure
	Details = CurrentObject.MetadataCharacteristics(DataTableName);
	MetaInfo = Details.Metadata;
	Title = MetaInfo.Presentation();
	
	// List and columns
	DataStructure = "";
	If Details.IsReference Then
		TableTitle = MetaInfo.ObjectPresentation;
		If IsBlankString(TableTitle) Then
			TableTitle = Title;
		EndIf;
		
		DataList.CustomQuery = False;
		DataList.MainTable = DataTableName;
		
		Field = DataList.Filter.FilterAvailableFields.Items.Find(New DataCompositionField("Ref"));
		ColumnTable = New ValueTable;
		Columns = ColumnTable.Columns;
		Columns.Add("Ref", Field.ValueType, TableTitle);
		DataStructure = "Ref";
		
		DataFormKey = "Ref";
		
	ElsIf Details.IsSet Then
		Columns = CurrentObject.RecordSetDimensions(MetaInfo);
		For Each CurItem In Columns Do
			DataStructure = DataStructure + "," + CurItem.Name;
		EndDo;
		DataStructure = Mid(DataStructure, 2);
		
		DataList.CustomQuery = True;
		DataList.QueryText = "SELECT DISTINCT " + DataStructure + " FROM " + DataTableName;
		
		If Details.IsSequence Then
			DataFormKey = "Recorder";
		Else
			DataFormKey = New Structure(DataStructure);
		EndIf;
			
	Else
		// No columns
		Return;
	EndIf;
	DataList.DynamicDataRead = True;
	
	CurrentObject.AddColumnsToFormTable(
		Items.DataList, 
		"Order, Filter, Grouping, StandardPicture, Parameters, ConditionalAppearance",
		Columns);
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure FilterOnChange(Item)
	
	Items.DataList.Refresh();
	
EndProcedure

#EndRegion

#Region DataListFormTableItemEventHandlers

&AtClient
Procedure DataListSelection(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;
	OpenCurrentObjectForm();
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OpenCurrentObject(Command)
	OpenCurrentObjectForm();
EndProcedure

&AtClient
Procedure SelectFilteredValues(Command)
	MakeSelection(True);
EndProcedure

&AtClient
Procedure SelectCurrentRow(Command)
	MakeSelection(False);
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure OpenCurrentObjectForm()
	CurParameters = CurrentObjectFormParameters(Items.DataList.CurrentData);
	If CurParameters <> Undefined Then
		OpenForm(CurParameters.FormName, CurParameters.Key);
	EndIf;
EndProcedure

&AtClient
Procedure MakeSelection(WholeFilterResult = True)
	
	If WholeFilterResult Then
		Data = AllSelectedItems();
	Else
		Data = New Array;
		For Each CurRow In Items.DataList.SelectedRows Do
			Item = New Structure(DataStructure);
			FillPropertyValues(Item, Items.DataList.RowData(CurRow));
			Data.Add(Item);
		EndDo;
	EndIf;
	
	NotifyChoice(New Structure("TableName, ChoiceData, ChoiceAction, FieldStructure",
		Parameters.TableName,
		Data,
		Parameters.ChoiceAction,
		DataStructure));
EndProcedure

&AtServer
Function ThisObject(CurrentObject = Undefined) 
	If CurrentObject = Undefined Then
		Return FormAttributeToValue("Object");
	EndIf;
	ValueToFormAttribute(CurrentObject, "Object");
	Return Undefined;
EndFunction

&AtServer
Function CurrentObjectFormParameters(Val Data)
	
	If Data = Undefined Then
		Return Undefined;
	EndIf;
	
	If TypeOf(DataFormKey) = Type("String") Then
		Value = Data[DataFormKey];
		CurFormName = ThisObject().GetFormName(Value) + ".ObjectForm";
	Else
		// The structure contains dimension names
		CurFormName = "";
		FillPropertyValues(DataFormKey, Data);
		CurParameters = New Array;
		CurParameters.Add(DataFormKey);
		Try
			Value = New(StrReplace(Parameters.TableName, ".", "RecordKey."), CurParameters);
			CurFormName = Parameters.TableName + ".RecordForm";
		Except
			// Processing not required
		EndTry;
		
		If IsBlankString(CurFormName) Then
			// A record set without keys (such as a turnover register record set)
			If Data.Property("Recorder") Then
				Value = Data.Recorder;
			Else
				For Each KeyValue In DataFormKey Do
					Value = Data[KeyValue.Key];
					Break;
				EndDo;
			EndIf;
			CurFormName = ThisObject().GetFormName(Value) + ".ObjectForm";
		EndIf;
	EndIf;		
	
	Return New Structure("FormName, Key", 
		CurFormName, 
		New Structure("Key", Value));
EndFunction

&AtServer
Function AllSelectedItems()
	
	Data = ThisObject().DynamicListCurrentData(DataList);
	
	Result = New Array();
	For Each CurRow In Data Do
		Item = New Structure(DataStructure);
		FillPropertyValues(Item, CurRow);
		Result.Add(Item);
	EndDo;
	
	Return Result;
EndFunction	

#EndRegion
