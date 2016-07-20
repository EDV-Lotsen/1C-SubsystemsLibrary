
#Region FormEventHandlers

// Imports tabular section settings. If it is the first form opening, 
// key operations from a catalog are added to the tabular section.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
 
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 		Return;
	EndIf;
	
	OverallSystemPerformance = PerformanceMonitorInternal.GetOverallSystemPerformanceItem();
	If OverallSystemPerformance.IsEmpty() Then
		Object.OverallSystemPerformance = NStr("en = 'Overall system performance'");
	Else
		Object.OverallSystemPerformance = OverallSystemPerformance;
	EndIf;
	
	Try
		SettingToImport = ImportKeyOperations(Object.OverallSystemPerformance);
		Object.Performance.Load(SettingToImport);
	Except
		MessageText = NStr("en = 'Cannot load settings.'");
		CommonUseClientServer.MessageToUser(MessageText);
	EndTry;
	
	SetConditionalAppearance();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	TableUpdated = False;
	ChartUpdated = False;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("DataProcessor.PerformanceMonitor.Form.FilterForm") Then
		
		If SelectedValue <> Undefined Then
			UpdateIndicators(SelectedValue);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure PerformanceOnStartEdit(Item, NewRow, Clone)
	
	If Not NewRow Then
		Return;
	EndIf;
	
	OpenChoiceForm();
	
EndProcedure

&AtClient
Procedure FormOnCurrentPageChange(Item, CurrentPage)
	
	If Not TableUpdated Or Not ChartUpdated Then
		If Items.Form.CurrentPage.Name = "PageChart" Then
			ChartUpdated = True;
		ElsIf Items.Form.CurrentPage.Name = "PageTable" Then
			TableUpdated = True;
		EndIf;
		UpdateIndicators();
	EndIf;
	
EndProcedure

&AtClient
Procedure TimeTargetOnChange(Item)
	
	CD = Items.Performance.CurrentData;
	If CD = Undefined Then
		Return;
	EndIf;
	
	ChangeTargetTime(CD.KeyOperation, CD.TargetTime);
	UpdateIndicators();
	
EndProcedure

// Displays the history of key operation execution.
//
&AtClient
Procedure PerformanceSelection(Item, SelectedRow, Field, StandardProcessing)
	
	TSRow = Object.Performance.FindByID(SelectedRow);
	
	If Left(Field.Name, 11) <> "Performance"
		Or TSRow.KeyOperation = Object.OverallSystemPerformance
		Then
			Return;
	EndIf;
	StandardProcessing = False;
	
	BeginOfPeriod = 0;
	EndOfPeriod = 0;
	PeriodIndex = Number(Mid(Field.Name, 19));
	If Not CalculateTimeRangeDates(BeginOfPeriod, EndOfPeriod, PeriodIndex) Then
		Return;
	EndIf;
	
	HistorySettings = New Structure("KeyOperation, StartDate, EndDate", TSRow.KeyOperation, BeginOfPeriod, EndOfPeriod);
	
	OpenParameters = New Structure("HistorySettings", HistorySettings);
	OpenForm("DataProcessor.PerformanceMonitor.Form.ExecutionHistory", OpenParameters, ThisObject);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Update(Command)
	
	UpdateIndicators();
	
EndProcedure

&AtClient
Procedure MoveUp(Command)
	
	CD = Items.Performance.CurrentData;
	If CD = Undefined Then
		Return;
	EndIf;
	
	Time = Object.Performance;
	CurrentIndex = Time.IndexOf(CD);
	
	If Time.Count() <= 1 Or
		CurrentIndex = 0 Or
		Time[CurrentIndex - 1].KeyOperation = Object.OverallSystemPerformance Or
		CD.KeyOperation = Object.OverallSystemPerformance
		Then
			Return;
	EndIf;
	
	ShiftDirection = -1;
	ExecuteRowShift(ShiftDirection, CurrentIndex);
	
EndProcedure

&AtClient
Procedure MoveDown(Command)
	
	CD = Items.Performance.CurrentData;
	If CD = Undefined Then
		Return;
	EndIf;
	
	Temp = Object.Performance;
	CurrentIndex = Temp.IndexOf(CD);
	
	If Temp.Count() <= 1 Or
		CurrentIndex = Temp.Count() - 1 Or
		Temp[CurrentIndex + 1].KeyOperation = Object.OverallSystemPerformance Or
		CD.KeyOperation = Object.OverallSystemPerformance
		Then
			Return;
	EndIf;
	
	ShiftDirection = 1;
	ExecuteRowShift(ShiftDirection, CurrentIndex);
	
EndProcedure

&AtClient
Procedure DataExport(Command)
	NotifyDescription = New NotifyDescription("SelectExportFileSuggested", ThisObject);
	CommonUseClient.ShowFileSystemExtensionInstallationQuestion(NotifyDescription);
EndProcedure

&AtClient
Procedure Settings(Command)
	
	OpenForm("DataProcessor.PerformanceMonitor.Form.PerformanceMeasurementAutomaticExport", , ThisObject);
	
EndProcedure

&AtClient
Procedure SpecifyApdex(Command)
	
	TSRow = Object.Performance.FindByID(Items.Performance.CurrentRow);
	Item = Items.Performance.CurrentItem;
	
	If Left(Item.Name, 11) <> "Performance"
		Or TSRow.KeyOperation = Object.OverallSystemPerformance
		Then
			Return;
	EndIf;
	
	If TSRow[Item.Name] = 0 Then
		ShowMessageBox(,NStr("en = 'No performance measurements available.
			|The target time cannot be calculated.'"));
		Return;
	EndIf;
	
	Notification = New NotifyDescription("SpecifyApdexCompletion", ThisObject);
	ToolTip = NStr("en = 'Enter desired Apdex value.'"); 
	ApdexValue = 0;
	ShowInputNumber(Notification, ApdexValue, ToolTip, 3, 2);
	
EndProcedure

&AtClient
Procedure SetFilter(Command)
	
	OpenForm("DataProcessor.PerformanceMonitor.Form.FilterForm", , ThisObject);
	
EndProcedure

&AtClient
Procedure AddKeyOperation(Command)
	OpenChoiceForm();
EndProcedure

&AtClient
Procedure DeleteKeyOperation(Command)
	DeleteKeyOperationAtServer();
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Priority.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.Performance.LineNumber");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotEqual;
	ItemFilter.RightValue = 0;
	
	Item.Appearance.SetParameterValue("ReadOnly", True);
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.TargetTime.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.Performance.KeyOperation");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Object.OverallSystemPerformance;
	
	Item.Appearance.SetParameterValue("ReadOnly", True);
	
EndProcedure

&AtClient
Procedure SpecifyApdexCompletion(Val ApdexValue, Val AdditionalParameters) Export
	
	If ApdexValue = Undefined Then
		Return;
	EndIf;
	
	If 0 > ApdexValue Or ApdexValue > 1 Then
		ShowMessageBox(,NStr("en = 'Invalid Apdex index value.
			|Valid values range from 0 to 1.'"));
		Return;
	EndIf;
	
	ApdexValue = ?(ApdexValue = 0, 0.001, ApdexValue);
	
	TSRow = Object.Performance.FindByID(Items.Performance.CurrentRow);
	Item = Items.Performance.CurrentItem;
	TSRow[Item.Name] = ApdexValue;
	
	PeriodIndex = Number(Mid(Item.Name, 19));
	TargetTime = CalculateTargetTime(TSRow.KeyOperation, ApdexValue, PeriodIndex);
	
	TSRow.TargetTime = TargetTime;
	TimeTargetOnChange(Item);
EndProcedure

// Calculates performance indicators.
//
&AtServer
Procedure UpdateIndicators(FilterValues = Undefined)
	
	If Items.Form.CurrentPage.Name = "PageChart" Then
		ChartUpdated = True;
		TableUpdated = False;
	ElsIf Items.Form.CurrentPage.Name = "PageTable" Then
		TableUpdated = True;
		ChartUpdated = False;
	EndIf;
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	If Not SetUpExecuted() Then
		Return;
	EndIf;
	
	// Getting the final KeyOperationTable for displaying it to a user
	KeyOperationTable = DataProcessorObject.PerformanceIndicators();
	If KeyOperationTable = Undefined Then
		CommonUseClientServer.MessageToUser(NStr("en = 'Invalid period.'"));
		Return;
	EndIf;
	
	If KeyOperationTable.Count() = 0 Then
		Return;
	EndIf;
	
	If FilterValues <> Undefined Then
		SetFilterKeyOperationTable(KeyOperationTable, FilterValues);
	EndIf;
	
	If Items.Form.CurrentPage.Name = "PageChart" Then
		
		UpdateChart(KeyOperationTable);
		
	ElsIf Items.Form.CurrentPage.Name = "PageTable" Then
		
		HandleObjectAttributes(KeyOperationTable.Columns);
		Object.Performance.Load(KeyOperationTable);
		
	EndIf;
	
EndProcedure

// Calculates target time for the specified Apdex value.
//
// Parameters:
//  KeyOperation - CatalogRef.KeyOperations - the operation whose target time is calculated.
//  ApdexValue   - Number - Apdex value used to calculate the target time.
//  PeriodIndex  - Number - period index that is used to calculate the target time.
//
// Returns:
//  Number - target time that produces the required Apdex score.
//
&AtServer
Function CalculateTargetTime(KeyOperation, ApdexValue, PeriodIndex)
	
	KeyOperationTable = KeyOperationTableForApdexCalculating();
	KeyOperationTableRow = KeyOperationTable.Add();
	KeyOperationTableRow.KeyOperation = KeyOperation;
	KeyOperationTableRow.Priority = 1;
	
	ThisDataProcessor = FormAttributeToValue("Object");
	
	StepNumber = 0;
	StepCount = 0;
	If Not ThisDataProcessor.ChartPeriodicity(StepNumber, StepCount) Then
		Return False;
	EndIf;
	
	BeginOfPeriod = Object.StartDate + (StepNumber * PeriodIndex);
	EndOfPeriod = BeginOfPeriod + StepNumber - 1;
	
	EvaluationParameters = ThisDataProcessor.ParameterStructureForAPDEXCalculation();
	EvaluationParameters.StepNumber = StepNumber;
	EvaluationParameters.StepCount = 1;
	EvaluationParameters.StartDate = BeginOfPeriod;
	EvaluationParameters.EndDate = EndOfPeriod;
	EvaluationParameters.OutputTotals = False;
	
	TargetTime = 0.01;
	PreviousTargetTime = TargetTime;
	StepSeconds = 1;
	While True Do
		
		KeyOperationTable[0].TargetTime = TargetTime;
		EvaluationParameters.KeyOperationTable = KeyOperationTable;
		
		CalculatedKeyOperationTable = ThisDataProcessor.EvaluateApdex(EvaluationParameters);
		ApdexValueCalculated = CalculatedKeyOperationTable[0][3];
		
		If ApdexValueCalculated < ApdexValue Then
			
			PreviousTargetTime = TargetTime;
			TargetTime = TargetTime + StepSeconds;
		
		ElsIf ApdexValueCalculated > ApdexValue Then
			
			If StepSeconds = 0.01 Or TargetTime = 0.01 Then
				Break;
			EndIf;
			
			StepSeconds = StepSeconds / 10;
			TargetTime = PreviousTargetTime + StepSeconds;
		
		ElsIf ApdexValueCalculated = ApdexValue Then
			
			Break;
			
		EndIf;
		
	EndDo;
	
	Return TargetTime;
	
EndFunction

// Processes "Performance" tabular section attributes.
//
// Parameters:
//  KeyOperationTableColumns - ValueTableColumnCollection - used to define which attributes must be removed.
//
&AtServer
Procedure HandleObjectAttributes(KeyOperationTableColumns)
	
	ObjectAttributes = GetAttributes("Object.Performance");
	AttributesToBeDeleted = AttributesToBeDeleted(ObjectAttributes);
	
	// "Key operation", "Priority", and "Target time" columns
	PredefinedColumnCount = 3;
	
	// Changing column content
	If AttributesToBeDeleted.Count() <> (KeyOperationTableColumns.Count() - PredefinedColumnCount) Then
		
		ChangeObjectAttributeContent(KeyOperationTableColumns, AttributesToBeDeleted);
		
		// Generating conditional appearance field lists
		FilterFields = New Array;
		AppearanceFields = New Array;
		For Each KeyOperationTableColumn In KeyOperationTableColumns Do
			If KeyOperationTableColumns.IndexOf(KeyOperationTableColumn) < PredefinedColumnCount Then
				Continue;
			EndIf;
			FilterFields.Add("Object.Performance." + KeyOperationTableColumn.Name);
			AppearanceFields.Add(KeyOperationTableColumn.Name);
		EndDo;
		
		SetTSConditionalAppearance(FilterFields, AppearanceFields, ConditionalAppearance, Object.OverallSystemPerformance);
		
	// Only column headers are changed
	Else
		
		Cnt = -1;
		For Each Item In Items.Performance.ChildItems Do
			Cnt = Cnt + 1;
			// Skipping the first 3 elements to avoid changing "Key operation", "Priority" and "Target time" column headers
			If Cnt < PredefinedColumnCount Then
				Continue;
			EndIf;
			Item.Title = KeyOperationTableColumns[Cnt].Title;
		EndDo;
		
	EndIf;
	
EndProcedure

// Changes form attributes: deletes unused attributes and adds required ones.
//
// Parameters:
//  KeyOperationTableColumns - ValueTableColumnCollection - used to define which 
//                             attributes must be removed.
//  AttributesToBeDeleted    - Array - list of full names of attributes to be deleted. 
//                             Specify the full names in Object.Performance.PerformanceN 
//                             format, where N is a number
//
&AtServer
Procedure ChangeObjectAttributeContent(KeyOperationTableColumns, AttributesToBeDeleted)
	
	// Deleting columns from "Performance" tabular section
	For a = 0 To AttributesToBeDeleted.Count() - 1 Do
		
		// Names of attributes to be deleted in Object.Performance.PerformanceN format, 
		// where N is a number. This expression gets a string in PerformanceN format.
		Item = Items.Find(Mid(AttributesToBeDeleted[a], 20));
		If Item <> Undefined Then
			Items.Delete(Item);
		EndIf;
		
	EndDo;
	
	AttributesToBeAdded = AttributesToBeAdded(KeyOperationTableColumns);
	ChangeAttributes(AttributesToBeAdded, AttributesToBeDeleted);
	
	// Adding columns to "Performance" tabular section
	ObjectAttributes = GetAttributes("Object.Performance");
	For Each ObjectAttribute In ObjectAttributes Do
		
		AttributeName = ObjectAttribute.Name;
		If Left(AttributeName, 11) = "Performance" Then
			Item = Items.Add(AttributeName, Type("FormField"), Items.Performance);
			Item.Type = FormFieldType.InputField;
			Item.DataPath = "Object.Performance." + AttributeName;
			Item.Title = ObjectAttribute.Title;
			Item.HeaderHorizontalAlign = ItemHorizontalLocation.Center;
			Item.Format = "ND=5; NFD=2; NZ=";
			Item.ReadOnly = True;
		EndIf;
		
	EndDo;
	
EndProcedure

// Creates an array with "Performance" tabular section columns that must be added.
//
// Parameters:
//  KeyOperationTableColumns - ValueTableColumnCollection - list of columns to be created.
//
// Returns:
//  Array - form attribute array.
//
&AtServerNoContext
Function AttributesToBeAdded(KeyOperationTableColumns)
	
	AttributesToBeAdded = New Array;
	TypeNumber63 = New TypeDescription("Number", New NumberQualifiers(6, 3, AllowedSign.Nonnegative));
	
	For Each KeyOperationTableColumn In KeyOperationTableColumns Do
		
		If KeyOperationTableColumns.IndexOf(KeyOperationTableColumn) < 3 Then
			Continue;
		EndIf;
		
		NewFormAttribute = New FormAttribute(KeyOperationTableColumn.Name, TypeNumber63, "Object.Performance", KeyOperationTableColumn.Title);
		AttributesToBeAdded.Add(NewFormAttribute);
		
	EndDo;
	
	Return AttributesToBeAdded;
	
EndFunction

// Creates an array with "Performance" tabular section columns 
// that must be deleted and deletes form items linked to the columns.
//
// Returns:
//  Array - form attribute array.
//
&AtServerNoContext
Function AttributesToBeDeleted(ObjectAttributes)
	
	AttributesToBeDeleted = New Array;
	
	a = 0;
	While a < ObjectAttributes.Count() Do
		
		AttributeName = ObjectAttributes[a].Name;
		If Left(AttributeName, 18) = "Performance" Then
			AttributesToBeDeleted.Add("Object.Performance." + AttributeName);
		EndIf;
		a = a + 1;
		
	EndDo;
	
	Return AttributesToBeDeleted;
	
EndFunction

// Sets a "Performance" tabular section conditional appearance.
//
&AtServerNoContext
Procedure SetTSConditionalAppearance(FilterFields, AppearanceFields, ConditionalAppearance, OverallSystemPerformance);
	
	ConditionalAppearance.Items.Clear();
	
	// Removing OverallSystemPerformance key operation priority
	AppearanceItem = ConditionalAppearance.Items.Add();
	// Appearance type
	AppearanceItem.Appearance.SetParameterValue("Text", "");
	// Appearance condition
	FilterItem = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.LeftValue = New DataCompositionField("Object.Performance.KeyOperation");
	FilterItem.RightValue = OverallSystemPerformance;
	// Appearance field
	AppearanceField = AppearanceItem.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("Priority");
	
	// Setting "read only" property for the Priority column
	AppearanceItem = ConditionalAppearance.Items.Add();
	// Appearance type
	AppearanceItem.Appearance.SetParameterValue("ReadOnly", True);
	// Appearance condition
	FilterItem = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.ComparisonType = DataCompositionComparisonType.NotEqual;
	FilterItem.LeftValue = New DataCompositionField("Object.Performance.LineNumber");
	FilterItem.RightValue = 0;
	// Appearance field
	AppearanceField = AppearanceItem.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("Priority");
	
	// Setting "read only" property for OverallSystemPerformance key operation target time 
	AppearanceItem = ConditionalAppearance.Items.Add();
	// Appearance type
	AppearanceItem.Appearance.SetParameterValue("ReadOnly", True);
	// Appearance condition
	FilterItem = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.LeftValue = New DataCompositionField("Object.Performance.KeyOperation");
	FilterItem.RightValue = OverallSystemPerformance;
	// Appearance field
	AppearanceField = AppearanceItem.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("TargetTime");
	
	// Setting "incomplete" mark to the target time of all attributes except OverallSystemPerformance
	AppearanceItem = ConditionalAppearance.Items.Add();
	// Appearance type
	AppearanceItem.Appearance.SetParameterValue("MarkIncomplete", True);
	// Appearance condition
	FilterGroup = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup.GroupType = DataCompositionFilterItemsGroupType.AndGroup;
	
	FilterItem = FilterGroup.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.ComparisonType = DataCompositionComparisonType.NotEqual;
	FilterItem.LeftValue = New DataCompositionField("Object.Performance.KeyOperation");
	FilterItem.RightValue = OverallSystemPerformance;
	
	FilterItem = FilterGroup.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.LeftValue = New DataCompositionField("Object.Performance.TargetTime");
	FilterItem.RightValue = 0;
	// Appearance field
	AppearanceField = AppearanceItem.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("TargetTime");
	
	FieldCount = FilterFields.Count() - 1;
	
	// Appearance if the operation has not been executed
	For a = 0 To FieldCount Do
		
		AppearanceItem = ConditionalAppearance.Items.Add();
		
		// Appearance type
		AppearanceItem.Appearance.SetParameterValue("Text", " ");
		// Appearance condition
		FilterItem = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.LeftValue = New DataCompositionField(FilterFields[a]);
		FilterItem.RightValue = 0;
		// Appearance field
		AppearanceField = AppearanceItem.Fields.Items.Add();
		AppearanceField.Field = New DataCompositionField(AppearanceFields[a]);
		
	EndDo;
	
	// Appearance of performance indicators
	Map = ApdexLevelAndColorMatch();
	For Each KeyValue In Map Do
	
		For a = 0 To FieldCount Do
			
			AppearanceItem = ConditionalAppearance.Items.Add();
			
			// Appearance type
			AppearanceItem.Appearance.SetParameterValue("BackColor", KeyValue.Value.Color);
			// Appearance condition
			FilterItem = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
			FilterItem.ComparisonType = DataCompositionComparisonType.GreaterOrEqual;
			FilterItem.LeftValue = New DataCompositionField(FilterFields[a]);
			FilterItem.RightValue = KeyValue.Value.From;
			// Appearance condition
			FilterItem = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
			FilterItem.ComparisonType = DataCompositionComparisonType.Less;
			FilterItem.LeftValue = New DataCompositionField(FilterFields[a]);
			FilterItem.RightValue = KeyValue.Value.To;
			// Appearance field
			AppearanceField = AppearanceItem.Fields.Items.Add();
			AppearanceField.Field = New DataCompositionField(AppearanceFields[a]);
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Updates a chart.
//
// Parameters:
//  KeyOperationTable - ValueTable - data used to update a chart.
//
&AtServer
Procedure UpdateChart(KeyOperationTable)
	
	Chart = Object.Chart;
	
	Chart.RefreshEnabled = False;
	
	Chart.AutoMaxValue  = False;
	Chart.AutoMinValue  = False;
	Chart.MaxValue      = 1;
	Chart.MinValue      = 0;
	Chart.BaseValue     = 0;
	Chart.HideBaseValue = True;
	
	Chart.Clear();
	
	TitleText = NStr("en = 'Performance chart from %1 to %2 with step %3'");
	TitleText = StrReplace(TitleText, "%1", Format(Object.StartDate, "DF=M/d/yyyy"));
	TitleText = StrReplace(TitleText, "%2", Format(Object.EndDate, "DF=M/d/yyyy"));
	TitleText = StrReplace(TitleText, "%3", String(Object.Step));
	Items.Chart.Title = TitleText;
	
	KeyOperationTable.Columns.Delete(1); // Priority
	KeyOperationTable.Columns.Delete(1); // TargetTime
	
	For Each KeyOperationTableRow In KeyOperationTable Do
		
		Series = Chart.Series.Add(KeyOperationTableRow.KeyOperation);
		Series.Text = KeyOperationTableRow.KeyOperation;
		
	EndDo;
	
	KeyOperationTable.Columns.Delete(0); // KeyOperation
	
	For Each KeyOperationTableColumn In KeyOperationTable.Columns Do
		
		Point = Chart.Points.Add(KeyOperationTableColumn.Name);
   // Displaying only hours if the step is Hour
		Point.Text = ?(Object.Step = "Hour", Left(KeyOperationTableColumn.Title, 2), KeyOperationTableColumn.Title); 
		Row = 0;
		Column = KeyOperationTable.Columns.IndexOf(KeyOperationTableColumn);
		For Each Series In Chart.Series Do
			
			PointValue = KeyOperationTable[Row][Column];
			If PointValue <> Undefined And PointValue <> Null Then
				Chart.SetValue(Point, Series, ?(PointValue = 0.001 Or PointValue = 0, PointValue, PointValue - 0.001));
			EndIf;	
			Row = Row + 1;
			
		EndDo;
		
	EndDo;
	
	Chart.ChartType = ChartType.Line;
	
	Chart.RefreshEnabled = True;
	
EndProcedure

&AtClient
Function PrepareExportParameters()
	
	KeyOperations = New Array;
	
	CommonPerformance = Object.OverallSystemPerformance;
	For Each KeyOperationTableRow In Object.Performance Do
		
		If KeyOperationTableRow.KeyOperation = CommonPerformance Then
			Continue;
		EndIf;
		
		KeyOperations.Add(KeyOperationTableRow.KeyOperation);
		
	EndDo;
	
	ExportParameters = New Structure("StartDate, EndDate, Step, KeyOperationArray");
	ExportParameters.StartDate	= Object.StartDate;
	ExportParameters.EndDate	  = Object.EndDate;
	ExportParameters.Step			  = String(Object.Step);
	ExportParameters.KeyOperationArray		= KeyOperations;
	
	Return ExportParameters;
	
EndFunction

// Exports measurement data for the specified interval.
//
&AtServerNoContext
Procedure PerformExport(AddressInStorage, ExportParameters)
	
	TemporaryDirectory = TempFilesDir() + String(New UUID);
	FileName = TemporaryDirectory + "/exp.zip";
	DescriptionFileName = TemporaryDirectory + "/Description.xml";
	SettingsFileName = TemporaryDirectory + "/Settings.xml";
	CreateDirectory(TemporaryDirectory);
	
	ZIPWriter = New ZipFileWriter(FileName);
	Start     = ExportParameters.StartDate;
	End       = ExportParameters.EndDate;
	KeyOperationArray	= ExportParameters.KeyOperationArray;
	
	StartOfRange = Start;
	EndOfRange   = End;
	
	PackageIntervalWidth = 3600 - 1;
	PackageCount = (End - Start) / PackageIntervalWidth;
	PackageCount = Int(PackageCount) + ?(PackageCount - Int(PackageCount) > 0, 1, 0);
	
	While StartOfRange < End Do
		EndOfRange = StartOfRange + PackageIntervalWidth;
		
		If EndOfRange > End Then
			EndOfRange = End;
		EndIf;
		
		TempFileName = TemporaryDirectory + "/" + FileNameByTime(StartOfRange) + ".1capd";
		If ExportInterval(TempFileName, StartOfRange, EndOfRange, KeyOperationArray) Then
			ZIPWriter.Add(TempFileName);
		EndIf;
		
		StartOfRange = EndOfRange + 1;
		
	EndDo;
	
	FillDetails(DescriptionFileName, Start, End, KeyOperationArray);
	ZIPWriter.Add(DescriptionFileName);
	
	FillSettings(SettingsFileName, Start, End, ExportParameters.Step, KeyOperationArray);
	ZIPWriter.Add(SettingsFileName);
	
	ZIPWriter.Write();
	
	BinaryData = New BinaryData(FileName);
	PutToTempStorage(BinaryData, AddressInStorage);
	
	DeleteFilesAtServer(TemporaryDirectory);
	
EndProcedure

// Exports infobase measurement data for the specified interval.
//
// Parameters:
//  TempFileName      - String - name of the file where data is written.
//  Start             - DateTime - interval beginning.
//  End               - DateTime - interval end. 
//  KeyOperationArray - Array - array of key operations to be exported.
//
&AtServerNoContext
Function ExportInterval(TempFileName, Start, End, KeyOperationArray)
	
	RecordSetMeasurements = TimeMeasurementRecordSet(Start, End, KeyOperationArray);
	
	If Not ValueIsFilled(RecordSetMeasurements) Then
		Return False;
	EndIf;
	
	XMLWriter = New XMLWriter;
	XMLWriter.OpenFile(TempFileName);
	
	XMLWriter.WriteXMLDeclaration();
	WriteXML(XMLWriter, RecordSetMeasurements);
	Return True;
EndFunction

// Gets a register record set.
//
// Parameters:
//  Start             - DateTime - interval beginning. 
//  End               - DateTime - interval end. 
//  KeyOperationArray - Array - key operations to be exported.
//
// Returns:
//  InformationRegister.TimeMeasurements.RecordSet
//
&AtServerNoContext
Function TimeMeasurementRecordSet(Start, End, KeyOperationArray)
	
	RegisterMetadata = Metadata.InformationRegisters.TimeMeasurements;
	
	QueryText = 
	"SELECT";
	For Each Dimension In RegisterMetadata.Dimensions Do
		QueryText = QueryText + "
			|	Measurements." + Dimension.Name + " AS " + Dimension.Name + ",";
	EndDo;
	For Each Resource In RegisterMetadata.Resources Do
		QueryText = QueryText + "
			|	Measurements." + Resource.Name + " AS " + Resource.Name + ",";
	EndDo;
	For Each Attribute In RegisterMetadata.Attributes Do
		QueryText = QueryText + "
			|	Measurements." + Attribute.Name + " AS " + Attribute.Name + ",";
	EndDo;
	
	// Removing the last comma
	QueryText = Left(QueryText, StrLen(QueryText) - 1);
	
	QueryText = QueryText + "
		|FROM
		|	" + RegisterMetadata.FullName() + " Measurements";
	
	Query = New Query;
	Query.SetParameter("StartDate", Start);
	Query.SetParameter("EndDate", End);
	Query.SetParameter("KeyOperationArray", KeyOperationArray);
	Query.Text = QueryText;
	Result = Query.Execute();
	
	RecordSet = InformationRegisters[RegisterMetadata.Name].CreateRecordSet();
	If Result.IsEmpty() Then
		Return RecordSet;
	EndIf;
	
	Selection = Result.Select();
	While Selection.Next() Do
		
		Write = RecordSet.Add();
		For Each Dimension In RegisterMetadata.Dimensions Do
			Write[Dimension.Name] = Selection[Dimension.Name];
		EndDo;
		For Each Resource In RegisterMetadata.Resources Do
			Write[Resource.Name] = Selection[Resource.Name];
		EndDo;
		For Each Attribute In RegisterMetadata.Attributes Do
			Write[Attribute.Name] = Selection[Attribute.Name];
		EndDo;
		
	EndDo;
	
	Return RecordSet;
	
EndFunction

// Fills an export description file.
//
// Parameters:
//  DescriptionFileName - String - name of the file to store the description.
//  Start               - Date and time - beginning of the export period.
//  End                 - Date and time - end of the export period.
//
&AtServerNoContext
Procedure FillDetails(DescriptionFileName, Start, End, KeyOperationArray)
	
	XMLWriter = New XMLWriter;
	XMLWriter.OpenFile(DescriptionFileName);
	
	XMLWriter.WriteXMLDeclaration();
	XMLWriter.WriteStartElement("CommonSettings");
	
	XMLWriter.WriteAttribute("Version",    "1.0.0.3");
	XMLWriter.WriteAttribute("BeginDate",  String(Start));
	XMLWriter.WriteAttribute("EndDate",    String(End));
	XMLWriter.WriteAttribute("ExportDate", String(CurrentDate()));
	
	For a = 0 To KeyOperationArray.Count() - 1 Do
		XMLWriter.WriteStartElement("KeyOperation");
		XMLWriter.WriteAttribute("name", String(KeyOperationArray[a]));
		XMLWriter.WriteEndElement();
	EndDo;
	
	XMLWriter.WriteEndElement();
	XMLWriter.Close();
	
EndProcedure

// Fills a settings file.
//
&AtServerNoContext
Procedure FillSettings(SettingsFileName, Start, End, Step, KeyOperationArray)
	
	XMLWriter = New XMLWriter;
	XMLWriter.OpenFile(SettingsFileName);
	
	XMLWriter.WriteXMLDeclaration();
	XMLWriter.WriteStartElement("CommonSettings");
	
	XMLWriter.WriteAttribute("BeginDate", String(Start));
	XMLWriter.WriteAttribute("EndDate",   String(End));
	XMLWriter.WriteAttribute("Step",      Step);
	
	XMLWriter.WriteStartElement("TableSettings");
	XMLWriter.WriteAttribute("RowCount", Format(KeyOperationArray.Count(), "NG=0"));
	
	For Cnt = 0 To KeyOperationArray.Count() - 1 Do
		WriteXML(XMLWriter, KeyOperationArray[Cnt].GetObject());
	EndDo;
	
	XMLWriter.WriteEndElement();
	XMLWriter.WriteEndElement();
	XMLWriter.Close();
	
EndProcedure

///////////////////////////////////////////////////////////////////////
// AUXILIARY PROCEDURES AND FUNCTIONS

// Moves tabular section rows and changes key operation priorities.
//
// Parameters:
//  ShiftDirection - Number: -1 move up. 
//  	                        1 move down.
//   CurrentIndex - Number - index of the row being shifted.
//
&AtClient
Procedure ExecuteRowShift(ShiftDirection, CurrentIndex)
	
	Temp = Object.Performance;
	
	Priority1 = Temp[CurrentIndex].Priority;
	Priority2 = Temp[CurrentIndex + ShiftDirection].Priority;
	
	ExchangePriorities(
		Temp[CurrentIndex].KeyOperation,
		Priority1,
		Temp[CurrentIndex + ShiftDirection].KeyOperation, 
		Priority2);
		
	Temp[CurrentIndex].Priority = Priority2;
	Temp[CurrentIndex + ShiftDirection].Priority = Priority1;
	
	Temp.Move(CurrentIndex, ShiftDirection);
	
EndProcedure

// Sets an exclusive managed lock for the reference.
//
&AtServerNoContext
Procedure LockRef(Ref)
	
	DataLock = New DataLock;
	LockItem = DataLock.Add(Ref.Metadata().FullName());
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Ref", Ref);
	DataLock.Lock();
	
EndProcedure

// Starts a transaction and sets an exclusive managed lock by reference value.
//
// Parameters:
//  Ref - AnyRef - reference to be locked.
//
// Returns:
//  Object - object retrieved by that reference.
//
&AtServerNoContext
Function StartObjectChange(Ref)
	
	BeginTransaction();
	
	LockRef(Ref);
	
	Object = Ref.GetObject();
	
	Return Object;
	
EndFunction

// Commits the transaction and writes an object.
//
// Parameters:
//  Object - AnyObject - object whose changes must be committed.
//  Write  - Boolean - shows if the object must be written before committing the transaction.
//
&AtServerNoContext
Procedure CommitObjectChange(Object, Write = True)
	
	If Write Then
		Object.Write();
	EndIf;
	
	CommitTransaction();
	
EndProcedure

// Performs a key operation priority exchange.
//
// Parameters:
//  KeyOperation1 - CatalogRef.KeyOperations.
//  Priority1     - Number - is assigned to KeyOperation2. 
//  KeyOperation2 - CatalogRef.KeyOperations.
//  Priority2     - Number - is assigned to KeyOperation1.
//
&AtServer
Procedure ExchangePriorities(KeyOperation1, Priority1, KeyOperation2, Priority2)
	
	BeginTransaction();
	
	KeyOperationsObject = StartObjectChange(KeyOperation1);
	KeyOperationsObject.Priority = Priority2;
	KeyOperationsObject.AdditionalProperties.Insert(PerformanceMonitorClientServer.DontCheckPriority());
	CommitObjectChange(KeyOperationsObject);
	
	KeyOperationsObject = StartObjectChange(KeyOperation2);
	KeyOperationsObject.Priority = Priority1;
	CommitObjectChange(KeyOperationsObject);
	
	CommitTransaction();
	
EndProcedure

// Opens a KeyOperations catalog selection form and sets a filter 
// to avoid displaying operations that are already in the list.
//
&AtClient
Procedure OpenChoiceForm()
	
	TS = Object.Performance;
	
	Filter = New Array;
	For a = 0 To TS.Count() -1 Do
		Filter.Add(TS[a].KeyOperation);
	EndDo;
	
	FormParameters = New Structure;
	FormParameters.Insert("Filter", Filter);
	FormParameters.Insert("ChoiceMode", True);
	
	Notification = New NotifyDescription(
		"AddKeyOperationCompletion",
		ThisObject
	);
	OpenForm(
		"Catalog.KeyOperations.ChoiceForm", 
		FormParameters, 
		ThisObject,
		,,,
		Notification, FormWindowOpeningMode.LockWholeInterface
	);
	
EndProcedure

&AtClient
Procedure AddKeyOperationCompletion(KeyOperationParameters, Parameters) Export
	
	If KeyOperationParameters = Undefined Then
		Return;
	EndIf;
	AddKeyOperationServer(KeyOperationParameters);
	
EndProcedure

&AtServer
Function AddKeyOperationServer(KeyOperationParameters)
	
	NewRow = Object.Performance.Add();
	NewRow.KeyOperation = KeyOperationParameters.KeyOperation;
	NewRow.TargetTime   = KeyOperationParameters.TargetTime;
	NewRow.Priority     = KeyOperationParameters.Priority;
	
	Object.Performance.Sort("Priority");
	
EndFunction

// Gets a file name by the specified time.
//
//
// Parameters:
//  Time - DateTime.
//
// Returns:
//  String - file name.
//
&AtServerNoContext
Function FileNameByTime(Time)
	
	Return Format(Time, "DF=""yyyy-MM-dd HH-mm-ss""");
	
EndFunction // FileNameByTime()

// Deletes a directory on the server.
//
&AtServerNoContext
Procedure DeleteFilesAtServer(Directory)
	
	Try
		DeleteFiles(Directory);
	Except
	EndTry;
	
EndProcedure

// Calculates start and end dates for the selected period.
//
// Parameters:
//  StartDate [OUT]  - Date - start date of the selected period. 
//  EndDate [OUT]    - Date - end date of the selected period. 
//  PeriodIndex [IN] - Number - index of the selected period.
//
// Returns:
//  Boolean - if True, dates are calculated, otherwise is False.
//
&AtServer
Function CalculateTimeRangeDates(StartDate, EndDate, PeriodIndex)
	
	ThisDataProcessor = FormAttributeToValue("Object");
	
	StepNumber = 0;
	StepCount = 0;
	If Not ThisDataProcessor.ChartPeriodicity(StepNumber, StepCount) Then
		Return False;
	EndIf;
	
	If StepCount <= PeriodIndex Then
		Raise NStr("en = 'The number of steps cannot be less than the index.'");
	EndIf;
	
	StartDate = Object.StartDate + (StepNumber * PeriodIndex);
	
	If StepNumber <> 0 Then
		EndDate = StartDate + StepNumber - 1;
	Else
		EndDate = EndOfDay(Object.EndDate);
	EndIf;
	
	Return True;
	
EndFunction

// Creates a value table for calculating Apdex value.
//
// Returns:
//  ValueTable - value table with a structure required to calculate Apdex value.
//
&AtServerNoContext
Function KeyOperationTableForApdexCalculating()
	
	KeyOperationTable = New ValueTable;
	KeyOperationTable.Columns.Add(
		"KeyOperation", 
		New TypeDescription("CatalogRef.KeyOperations"));
	KeyOperationTable.Columns.Add(
		"Priority", 
		New TypeDescription("Number", New NumberQualifiers(15, 0, AllowedSign.Nonnegative)));
	KeyOperationTable.Columns.Add(
		"TargetTime",
		New TypeDescription("Number", New NumberQualifiers(15, 2, AllowedSign.Nonnegative)));
	
	Return KeyOperationTable;
	
EndFunction

///////////////////////////////////////////////////////////////////////
// AUXILIARY PROCEDURES AND FUNCTIONS (APPEARANCE, SETTINGS)

// Returns the Unacceptable value color.
//
// Returns:
//  Color - value color.
//
&AtServerNoContext
Function ColorUnacceptable()
	
	Return New Color(187, 187, 187);
	
EndFunction

// Returns the Poor value color
//
// Returns:
//  Color - value color.
//
&AtServerNoContext
Function ColorPoor()
	
	Return New Color(255, 212, 171);
	
EndFunction

// Returns the Fair value color.
//
// Returns:
//  Color - value color.
//
&AtServerNoContext
Function ColorFair()
	
	Return New Color(255, 255, 153);
	
EndFunction

// Returns the Good value color.
//
// Returns:
//  Color - value color.
//
&AtServerNoContext
Function ColorGood()
	
	Return New Color(204, 255, 204);
	
EndFunction

// Returns the Excellent value color.
//
// Returns:
//  Color - value color.
//
&AtServerNoContext
Function ColorExcellent()
	
	Return New Color(204, 255, 255);
	
EndFunction

// Returns a map: 
//       Key   - String - performance measurement. 
//       Value - Structure - measurement parameters.
//
// Returns:
//  Map
//
&AtServerNoContext
Function ApdexLevelAndColorMatch()
	
	Map = New Map;
	
	Values = New Structure("From, To, Color");
	Values.From = 0.001; // 0 means that the operation is not performed at all
	Values.To = 0.5;
	Values.Color = ColorUnacceptable();
	Map.Insert("Unacceptable", Values);
	
	Values = New Structure("From, To, Color");
	Values.From = 0.5;
	Values.To = 0.7;
	Values.Color = ColorPoor();
	Map.Insert("Poor", Values);
	
	Values = New Structure("From, To, Color");
	Values.From = 0.7;
	Values.To = 0.85;
	Values.Color = ColorFair();
	Map.Insert("Fair", Values);
	
	Values = New Structure("From, To, Color");
	Values.From = 0.85;
	Values.To = 0.94;
	Values.Color = ColorGood();
	Map.Insert("Good", Values);
	
	Values = New Structure("From, To, Color");
	Values.From = 0.94;
	Values.To = 1.002; // in conditional appearance the "To" value is used as "Less" but not as "LessOrEqual"
	Values.Color = ColorExcellent();
	Map.Insert("Excellent", Values);
	
	Return Map;
	
EndFunction

// Checks that the form settings are valid.
//
// Returns:
//  True  - settings are valid.
//  False - settings are invalid.
//
&AtServer
Function SetUpExecuted()
	
	Executed = True;
	For Each TSRow In Object.Performance Do
		
		If TSRow.TargetTime = 0 
			And TSRow.KeyOperation <> Object.OverallSystemPerformance
		Then
		
			CommonUseClientServer.MessageToUser(
				NStr("en = 'The target time must be filled.'"),
				,
				"Performance[" + Object.Performance.IndexOf(TSRow) + "].TargetTime",
				"Object");
			
			Executed = False;
			Break;
		EndIf;
		
	EndDo;
	
	Return Executed;
	
EndFunction

// Fills "Performance" tabular section from KeyOperations catalog at first form opening.
// 
&AtServerNoContext
Function ImportKeyOperations(OverallSystemPerformance)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	KeyOperations.Ref AS KeyOperation,
	|	KeyOperations.Priority AS Priority,
	|	KeyOperations.TargetTime AS TargetTime
	|FROM
	|	Catalog.KeyOperations AS KeyOperations
	|WHERE
	|	Not KeyOperations.DeletionMark
	|
	|UNION ALL
	|
	|SELECT
	|	&OverallSystemPerformance,
	|	0,
	|	0
	|WHERE
	|	VALUETYPE(&OverallSystemPerformance) <> TYPE(Catalog.KeyOperations)
	|
	|ORDER BY
	|	Priority
	|AUTOORDER";
	Query.SetParameter("OverallSystemPerformance", OverallSystemPerformance);
	Result = Query.Execute();
	
	If Result.IsEmpty() Then
		Return New ValueTable;
	EndIf;
	
	Return Result.Unload();
	
EndFunction

// Changes key operation target time.
//
// Parameters:
//  KeyOperation - CatalogRef.KeyOperations - operation whose target time must be changed. 
//  TargetTime   - Number - new target time.
//
&AtServer
Procedure ChangeTargetTime(KeyOperation, TargetTime)
	
	KeyOperationObject = StartObjectChange(KeyOperation);
	KeyOperationObject.TargetTime = TargetTime;
	CommitObjectChange(KeyOperationObject);
	
EndProcedure

// Deletes value table rows that do not match the filter.
//
// Parameters:
//  KeyOperationTable - ValueTable - table to be filtered.
//  FilterValues      - Structure  – filter condition and value.
//
&AtServerNoContext
Procedure SetFilterKeyOperationTable(KeyOperationTable, FilterValues)
	
	If FilterValues.Direction > 0 Then
		If Upper(FilterValues.State) = "GOOD" Then
			Limit = 0.93;
		ElsIf Upper(FilterValues.State) = "FAIR" Then
			Limit = 0.84;
		ElsIf Upper(FilterValues.State) = "POOR" Then
			Limit = 0.69;
		EndIf;
	ElsIf FilterValues.Direction < 0 Then
		If Upper(FilterValues.State) = "GOOD" Then
			Limit = 0.85;
		ElsIf Upper(FilterValues.State) = "FAIR" Then
			Limit = 0.7;
		ElsIf Upper(FilterValues.State) = "POOR" Then
			Limit = 0.5;
		EndIf;
	EndIf;
	
	Cnt = 0;
	Delete = False;
	While Cnt < KeyOperationTable.Count() Do
		
		For Each KeyOperationTableColumn In KeyOperationTable.Columns Do
			If (Left(KeyOperationTableColumn.Name, 11) <> "Performance") Or (KeyOperationTable[Cnt][KeyOperationTableColumn.Name] = 0) Then
				Continue;
			EndIf;
			
			If FilterValues.Direction > 0 Then
				If KeyOperationTable[Cnt][KeyOperationTableColumn.Name] > Limit Then
					Delete = False;
					Break;
				Else
					Delete = True;
				EndIf;
			ElsIf FilterValues.Direction < 0 Then
				If KeyOperationTable[Cnt][KeyOperationTableColumn.Name] < Limit Then
					Delete = False;
					Break;
				Else
					Delete = True;
				EndIf;
			EndIf;
		EndDo;
		
		If Delete Then
			KeyOperationTable.Delete(Cnt);
		Else
			Cnt = Cnt + 1;
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure SelectExportFileSuggested(FileSystemExtensionAttached, AdditionalParameters) Export
	
	ExportParameters = PrepareExportParameters();
	AddressInStorage = PutToTempStorage("", ThisObject.UUID);
	Status(NStr("en = 'Exporting data...'"));
	PerformExport(AddressInStorage, ExportParameters);
	
	GetFile(AddressInStorage, "perf.zip");
	
EndProcedure

&AtServer
Procedure DeleteKeyOperationAtServer()
	
	RowID = Items.Performance.CurrentRow;
	If RowID = Undefined Then
		Return;
	EndIf;
	
	PerformanceDynamicsData = Object.Performance;
	ActiveString = PerformanceDynamicsData.FindByID(RowID);
	If ActiveString <> Undefined Then
		PerformanceDynamicsData.Delete(PerformanceDynamicsData.IndexOf(ActiveString));
	EndIf;
	
EndProcedure

#EndRegion