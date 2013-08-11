

////////////////////////////////////////////////////////////////////////////////
// MODULE VARIABLES

////////////////////////////////////////////////////////////////////////////////
// EXPORT PROCEDURES

////////////////////////////////////////////////////////////////////////////////
// COMMON PROCEDURES AND FUNCTIONS

&AtClient
// Procedure fills attributes based on template.
//
Procedure FillByTemplate(TemplateName)
	
	// clearing
	Object.SourceName = "";
	Object.SourcePresentation = "";
	Object.Query = "";
	Object.DataFilterPeriods.Clear();
	Object.Indicators.Clear();
	Object.QueryParameters.Clear();
	
	// FillType
	If TemplateName = "FixedAmount" Then
		
		// Fixed amount
		Object.Description	= "Fixed Amount";
		Object.Id 	 		= "FixedAmount";
	    Object.CustomQuery 	= False;
	    Object.SetValueDuringPayrollCalculation = True;
		
	ElsIf TemplateName = "PlannedWorkDays" Then

		// Norm of days
		Object.Description		= "Planned Work Days";
		Object.Id 	 			= "PlannedWorkDays";
	    Object.CustomQuery 		= True;
	    Object.SetValueDuringPayrollCalculation = False;
	    NewQueryParameter 					= Object.QueryParameters.Add();
	    NewQueryParameter.Name 				= "Company";
	    NewQueryParameter.Presentation 		= "Company";
	    NewQueryParameter 					= Object.QueryParameters.Add();
	    NewQueryParameter.Name 				= "AccountingPeriod";
	    NewQueryParameter.Presentation 		= "Accounting Period";
	    Object.Query = "SELECT
	                   |	SUM(1) AS PlannedWorkDays
	                   |FROM
	                   |	InformationRegister.CalendarData AS Calendars
	                   |		INNER JOIN Catalog.Companies AS Companies
	                   |		ON Calendars.Calendar = Companies.RegularCalendar
	                   |			AND (Companies.Ref = &Company)
	                   |WHERE
	                   |	Calendars.Year = YEAR(&AccountingPeriod)
	                   |	AND Calendars.ScheduleDate BETWEEN BEGINOFPERIOD(&AccountingPeriod, MONTH) AND ENDOFPERIOD(&AccountingPeriod, MONTH)
	                   |	AND Calendars.DayIncludedInSchedule";
		
	ElsIf TemplateName = "PlannedWorkHours" Then

		// Norm of hours
		Object.Description 	= "Planned Work Hours";
		Object.Id 	  		= "PlannedWorkHours";
	    Object.CustomQuery 	= True;
	    Object.SetValueDuringPayrollCalculation = False;
	    NewQueryParameter 						 = Object.QueryParameters.Add();
	    NewQueryParameter.Name 					 = "Company";
	    NewQueryParameter.Presentation 			 = "Company";
	    NewQueryParameter 						 = Object.QueryParameters.Add();
	    NewQueryParameter.Name 					 = "AccountingPeriod";
	    NewQueryParameter.Presentation 			 = "Accounting Period";
	    Object.Query = "SELECT
	                   |	SUM(8) AS PlannedWorkHours
	                   |FROM
	                   |	InformationRegister.CalendarData AS Calendars
	                   |		INNER JOIN Catalog.Companies AS Companies
	                   |		ON Calendars.Calendar = Companies.RegularCalendar
	                   |			AND (Companies.Ref = &Company)
	                   |WHERE
	                   |	Calendars.Year = YEAR(&AccountingPeriod)
	                   |	AND Calendars.ScheduleDate BETWEEN BEGINOFPERIOD(&AccountingPeriod, MONTH) AND ENDOFPERIOD(&AccountingPeriod, MONTH)
	                   |	AND Calendars.DayIncludedInSchedule";
		
	ElsIf TemplateName = "DaysWorked" Then

		// Worked days
		Object.Description	= "Days Worked";
		Object.Id	  		= "DaysWorked";
	    Object.CustomQuery 	= False;
	    Object.SetValueDuringPayrollCalculation = True;
		
	ElsIf TemplateName = "HoursWorked" Then

		// Worked hours
		Object.Description	= "Hours Worked";
		Object.Id 	   		= "HoursWorked";
	    Object.CustomQuery 	= False;
	    Object.SetValueDuringPayrollCalculation = True;
		
	ElsIf TemplateName = "PayRate" Then

		// Pay rate
		Object.Description  = "Pay Rate";
		Object.Id 	  		= "PayRate";
	    Object.CustomQuery 	= False;
	    Object.SetValueDuringPayrollCalculation = True;

	EndIf; 															  
	
	// Visibility and accessibility control
	QueryText = Object.Query;
    EditQuery = False;
	Items.Query.Enabled = False;
	Items.EditQuery.Enabled = Object.CustomQuery;

	#If ThinClient OR WebClient Then
		Items.QueryWizard.Enabled = False;
	#Else
		Items.QueryWizard.Enabled = Object.CustomQuery;
	#EndIf
	
	Items.Source.Visible = NOT Object.SetValueDuringPayrollCalculation;
	Items.CustomQuery.Visible = NOT Object.SetValueDuringPayrollCalculation;
	Items.Pages.Visible = NOT Object.SetValueDuringPayrollCalculation;
	
EndProcedure

&AtServer
// Procedure opens query wizard.
//
Procedure OpenQueryWizard()

	QueryWizard = New QueryWizard;
	QueryWizard.AutoAppendPresentations = False;
	If Object.Query <> "" Then
		QueryWizard.Text = Object.Query;
	EndIf;
	
	If QueryWizard.DoModal() Then
		Object.Query = QueryWizard.Text;
		QueryText =  QueryWizard.Text;
	EndIf;

EndProcedure // OpenQueryWizard()

&AtServer
// Function composes query condition string
//
Function GetComparisonKind(FieldName, FilterComparisonKind)

    If FilterComparisonKind = DataCompositionComparisonType.Equal  Then
		Return "Source." + FieldName + " = &" + StrReplace(FieldName, ".", "");

	ElsIf FilterComparisonKind = DataCompositionComparisonType.Greater Then
		Return "Source." + FieldName + " > &" + StrReplace(FieldName, ".", "");
	
	ElsIf FilterComparisonKind = DataCompositionComparisonType.GreaterOrEqual  Then
		Return "Source." + FieldName + " >= &" + StrReplace(FieldName, ".", "");
	
	ElsIf FilterComparisonKind = DataCompositionComparisonType.Inhierarchy 
		OR  FilterComparisonKind = DataCompositionComparisonType.InListByHierarchy Then
		Return "Source." + FieldName + " In HIERARCHY (&" + StrReplace(FieldName, ".", "") + ")";
	
	ElsIf FilterComparisonKind = DataCompositionComparisonType.InList  Then
		Return "Source." + FieldName + " In (&" + StrReplace(FieldName, ".", "") + ")";
	
	ElsIf FilterComparisonKind = DataCompositionComparisonType.Less  Then
		Return "Source." + FieldName + " < &" + StrReplace(FieldName, ".", "");
	
	ElsIf FilterComparisonKind = DataCompositionComparisonType.LessOrEqual  Then         
		Return "Source." + FieldName + " <= &" + StrReplace(FieldName, ".", "");
	
	ElsIf FilterComparisonKind = DataCompositionComparisonType.NotInList  Then
		Return "NOT Source." + FieldName + " In (&" + StrReplace(FieldName, ".", "") + ")";
	
	ElsIf FilterComparisonKind = DataCompositionComparisonType.NotInHierarchy 
		OR FilterComparisonKind = DataCompositionComparisonType.NotInListByHierarchy Then
		Return "NOT Source." + FieldName + " In HIERARCHY (&" + StrReplace(FieldName, ".", "") + ")";
	
	ElsIf FilterComparisonKind = DataCompositionComparisonType.NotEqual  Then
		Return "Source." + FieldName + " <> &" + StrReplace(FieldName, ".", "");
	
	EndIf; 

EndFunction // ()

&AtServer
// Procedure opens query wizard.
//
Procedure GenerateQueryFillParameters()

	FieldList = "";
	For each Field In Object.Indicators Do
		If Field.Use Then
			FieldList = FieldList + ?(FieldList = "", "", ",
 																	|     ") + "SUM(Source." + Field.Name + ")";
		EndIf; 
	EndDo; 

    ListOfConditions = "";
	For each FilterItem In DataFilter.Settings.Filter.Items Do
		ListOfConditions = ListOfConditions + ?(ListOfConditions = "", "", "
																	|	And ") + GetComparisonKind(FilterItem.LeftValue, FilterItem.ComparisonType);
	EndDo;

    QueryText = "SELECT 
					|	"+ FieldList + "
					|FROM 
					|	"+ Object.SourceName + " AS Source" + ?(ListOfConditions = "", "", "
					|WHERE 
					|	"+ ListOfConditions);
    
	Object.Query = QueryText;

	Object.QueryParameters.Clear();

	For each TSLine In Object.DataFilterPeriods Do
		If Object.QueryParameters.FindRows(New Structure("Name", TSLine.BoundaryDateName)).Count() = 0 Then
			NewRow = Object.QueryParameters.Add();
			NewRow.Name = TSLine.BoundaryDateName;
			NewRow.Presentation = TSLine.BoundaryDateName;
			NewRow.Value = TSLine.Period;
		EndIf; 
	EndDo;
		 
	For each FilterItem In DataFilter.Settings.Filter.Items Do
		If Object.QueryParameters.FindRows(New Structure("Name", String(FilterItem.LeftValue))).Count() = 0 Then
			NewRow = Object.QueryParameters.Add();
			NewRow.Name = FilterItem.LeftValue;
			NewRow.Presentation = FilterItem.LeftValue;
			NewRow.ComparisonType = FilterItem.ComparisonType;
			NewRow.Value = FilterItem.RightValue;
		EndIf; 
	EndDo;
                                                                  
EndProcedure

&AtServer
// Function fills list of parameters using query text
//
Procedure FillParametersByQuery()

    Object.QueryParameters.Clear();
	QueryString = Object.Query;
	Enter1 = Char(10);
    SubstringNumber = Find(QueryString, "&");
	While SubstringNumber > 0 Do
		
		QueryString = Right(QueryString, (StrLen(QueryString)-SubstringNumber));

		CommaNumber 		= Find(QueryString, ",");
		SpaceNumber 		= Find(QueryString, " ");
		NumberEnter	 		= Find(QueryString, Enter1);
		BracketNumber	 	= Find(QueryString, ")");
		If CommaNumber = 0 And SpaceNumber = 0 And NumberEnter = 0 And BracketNumber = 0 Then
        	ParameterName = QueryString;
		Else
			If CommaNumber = 0 Then
				CommaNumber = 9000000;
			EndIf; 
	        If SpaceNumber = 0 Then
				SpaceNumber = 9000000;
			EndIf;
			If NumberEnter = 0 Then
				NumberEnter = 9000000;
			EndIf;
			If BracketNumber = 0 Then
				BracketNumber = 9000000;
			EndIf;
			EndOfParameter = MIN(CommaNumber, SpaceNumber, NumberEnter, BracketNumber);
			ParameterName = Left(QueryString, EndOfParameter - 1);
        EndIf;

        If Object.QueryParameters.FindRows(New Structure("Name", ParameterName)).Count() = 0 Then
			NewRow = Object.QueryParameters.Add();
	        NewRow.Name = ParameterName;
	        NewRow.Presentation = ParameterName;
		EndIf;

	    SubstringNumber = Find(QueryString, "&");
	EndDo;  	

EndProcedure // FillParametersByQuery()

&AtServer
// Function checks query correctness.
//
Function QueryCorrect()
    
	Try
		QueryBuilder = New QueryBuilder;
		QueryBuilder.Text = Object.Query;
		QueryBuilder.FillSettings();
        If QueryBuilder.Dimensions.Count() > 0 Then
		    Message = New UserMessage();
			Message.Text = NStr("en = 'The query should contain totals!'");
			Message.Message();			
			Return False;
		EndIf; 
		If QueryBuilder.SelectedFields.Count() > 1 Then
		    Message = New UserMessage();
			Message.Text = NStr("en = 'The query should contain only one indicator!'");
			Message.Message();			
			Return False;
		EndIf;
		Return True;
	Except
        Return False;
	EndTry;	

EndFunction // QueryCheck()
 
&AtClient
// Procedure generates calculation parameters id.
//
Procedure GetID(StrDescription)
     
	Separators =  " .,+,-,/,*,?,=,<,>,(,)%!@#$%&*""№:;{}[]?()\|/`~'^_";
	 
	Object.Id = "";
	WasSpecialSymbol = False;
	For SymbolNum = 1 To StrLen(StrDescription) Do
	  	Char = Mid(StrDescription,SymbolNum,1);
		If Find(Separators, Char) <> 0 Then
		   WasSpecialSymbol = True;
		ElsIf WasSpecialSymbol Then
		   WasSpecialSymbol = False;
		   Object.Id = Object.Id + Upper(Char);
		Else
		   Object.Id = Object.Id + Char;          
		EndIf;

	EndDo;
          
EndProcedure //GetID

&AtServer 
// Function checks duplicating of the indicator id in IB.
//
Function CheckForIDDuplication(Cancellation)

	Query = New Query(
	"SELECT
	|	CalculationParameters.ID
	|FROM
	|	Catalog.CalculationParameters AS CalculationParameters
	|WHERE
	|	CalculationParameters.ID = &Id
	|	AND CalculationParameters.Ref <> &Ref");
	 
	Query.SetParameter("Id", Object.Id);
	Query.SetParameter("Ref", Object.Ref);
	 
	Selection = Query.Execute().Choose();
	Cancellation = Selection.Count() > 0;
	 
	If Cancellation Then
	
	  	Message = New UserMessage();
		Message.Text = NStr("en = 'Calculation parameter with this ID already exists!'");
		Message.Message();
		
	EndIf;
	 
	Return Cancellation;
     
EndFunction // CheckForIDDuplication()

&AtServer
// Function checks, if indicator is selected.
//
Function CheckForIndicatorChoice()

	For each TSLine In Object.Indicators Do
		If TSLine.Use Then
			Return False;
		EndIf; 
	EndDo; 
	 
	Message = New UserMessage();
	Message.Text = NStr("en = 'Indicator is not selected!'");
	Message.Message();

	Return True;
     
EndFunction // CheckForIndicatorChoice()
            
////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS NEEDED TO MANAGE FORM INTERFACE

&AtServer
// Procedure fills indicators and register data filter periods.
//
Procedure FillIndicatorsAndSourceDataFilterPeriods()

	SourceKindByMetadata = Left(Object.SourceName, Find(Object.SourceName,".")-1);

	TableOfSource = StrReplace(Object.SourceName, SourceKindByMetadata + "." , "");
	
    Periodic = True;
	Acc = Find(TableOfSource,".");
	
	If Acc > 0 Then	
		SourceNameByMetadata = Left(TableOfSource, Acc - 1);

	ElsIf Find(Object.SourcePresentation, "registerRecords:") > 0 Then
		SourceNameByMetadata = TableOfSource;

	Else
		SourceNameByMetadata = TableOfSource;
		Periodic = False;  
			
	EndIf;

    MetadataSource = Metadata[StrReplace(SourceKindByMetadata, "Register", "Registers")][SourceNameByMetadata];

    For each Resource In MetadataSource.Resources Do

		// 1. Accumulation register.
		If Find(Object.SourceName, "AccumulationRegister")>0 Then

			If Find(Object.SourcePresentation,": turnovers")  Then

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation 	= Resource.Synonym + ": turnover";
				NewIndicator.Name 			= Resource.Name + "Turnover";
				NewIndicator.Use 			= False;

			ElsIf Find(Object.SourcePresentation, ": Balance And turnovers") > 0 Then

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation 	= Resource.Synonym + ": opening balance";
				NewIndicator.Name 			= Resource.Name + "OpeningBalance";
				NewIndicator.Use 			= False;

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation 	= Resource.Synonym + ": receipt";
				NewIndicator.Name 			= Resource.Name + "Receipt";
				NewIndicator.Use 			= False;

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation 	= Resource.Synonym + ": turnover";
				NewIndicator.Name 			= Resource.Name + "Turnover";
				NewIndicator.Use 			= False;

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation 	= Resource.Synonym + ": expense";
				NewIndicator.Name			= Resource.Name + "Expense";
				NewIndicator.Use			= False;
                 
				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation	= Resource.Synonym + ": closing balance";
				NewIndicator.Name			= Resource.Name + "ClosingBalance";
				NewIndicator.Use			= False;

			ElsIf Find(Object.SourcePresentation, ": Balance") > 0 Then

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation	= Resource.Synonym + ": balance";
				NewIndicator.Name			= Resource.Name + "Balance";
				NewIndicator.Use			= False;
				
			ElsIf Find(Object.SourcePresentation, "registerRecords: receipt") > 0 Then
				
				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation	= Resource.Synonym + ": receipt";
				NewIndicator.Name			= Resource.Name;
				NewIndicator.Use			= False;
				
			ElsIf Find(Object.SourcePresentation, "registerRecords: expense") > 0 Then
				
				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation 	= Resource.Synonym + ": expense";
				NewIndicator.Name			= Resource.Name;
				NewIndicator.Use			= False;
				
			ElsIf Find(Object.SourcePresentation, "registerRecords: turnover") > 0 Then
				
				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation 	= Resource.Synonym + ": turnover";
				NewIndicator.Name			= Resource.Name;
				NewIndicator.Use			= False;
							
			EndIf;

		// 2. Information register.
		ElsIf Find(Object.SourceName, "InformationRegister") > 0 Then

			ResourceTypes = Resource.Type.Types();

			If ResourceTypes.Count() = 1 And ResourceTypes[0] = Type("Number") Then

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation	= Resource.Synonym;
				NewIndicator.Name			= Resource.Name;
				NewIndicator.Use			= False;

			EndIf;

        // 3. Accounting register.
        ElsIf Find(Object.SourceName,"AccountingRegister") > 0 Then

			If Find(Object.SourcePresentation,": turnovers with correspondence") > 0  Then
											
				If NOT Resource.AccountingFlag = Undefined Then
					
					NewIndicator = Object.Indicators.Add();
					NewIndicator.Presentation = Resource.Name + ": turnover Dr";
					NewIndicator.Name = Resource.Name + "TurnoverDr";
					NewIndicator.Use = False;
					
					NewIndicator = Object.Indicators.Add();
					NewIndicator.Presentation = Resource.Name + ": turnover Cr";
					NewIndicator.Name = Resource.Name + "TurnoverCr";
					NewIndicator.Use = False;
					
				Else
					
				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": turnover";
				NewIndicator.Name = Resource.Name + "Turnover";
				NewIndicator.Use = False;
		
				EndIf;

			ElsIf Find(Object.SourcePresentation,": Balance And turnovers") > 0 Then

                NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": closing balance";
				NewIndicator.Name = Resource.Name + "ClosingBalance";
				NewIndicator.Use = False;

                NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": closing balance Dr";
				NewIndicator.Name = Resource.Name + "ClosingBalanceDr";
				NewIndicator.Use = False;

                NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": closing balance Cr";
				NewIndicator.Name = Resource.Name + "ClosingBalanceCr";
				NewIndicator.Use = False;

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": closing extended balance Dr";
				NewIndicator.Name = Resource.Name + "ClosingSplittedBalanceDr";
				NewIndicator.Use = False;

                NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": closing extended balance Cr";
				NewIndicator.Name = Resource.Name + "ClosingSplittedBalanceCr";
				NewIndicator.Use = False;

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": opening balance";
				NewIndicator.Name = Resource.Name + "OpeningBalance";
				NewIndicator.Use = False;

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": opening balance Dr";
				NewIndicator.Name = Resource.Name + "OpeningBalanceDr";
				NewIndicator.Use = False;

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": opening balance Cr";
				NewIndicator.Name = Resource.Name + "OpeningBalanceCr";
				NewIndicator.Use = False;

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name+": opening extended balance Dr";
				NewIndicator.Name = Resource.Name + "OpeningSplittedBalanceDr";
				NewIndicator.Use = False;

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": opening extended balance Cr";
				NewIndicator.Name = Resource.Name + "OpeningSplittedBalanceCr";
				NewIndicator.Use = False;
				
				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": turnover";
				NewIndicator.Name = Resource.Name + "Turnover";
				NewIndicator.Use = False;
				
				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": turnover Dr";
				NewIndicator.Name = Resource.Name + "TurnoverDr";
				NewIndicator.Use = False;
				
				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": turnover Cr";
				NewIndicator.Name = Resource.Name + "TurnoverCr";
				NewIndicator.Use = False;
                            			
			ElsIf Find(Object.SourcePresentation,": Balance") > 0 Then

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": balance";
				NewIndicator.Name = Resource.Name+"Balance";
				NewIndicator.Use = False;

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": balance Dr";
				NewIndicator.Name = Resource.Name + "BalanceDr";
				NewIndicator.Use = False;

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": balance Cr";
				NewIndicator.Name = Resource.Name + "BalanceCr";
				NewIndicator.Use = False;

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": extended balance Dr";
				NewIndicator.Name = Resource.Name + "SplittedBalanceDr";
				NewIndicator.Use = False;

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": extended balance Cr";
				NewIndicator.Name = Resource.Name + "SplittedBalanceCr";
				NewIndicator.Use = False;
				
			ElsIf Find(Object.SourcePresentation,": turnovers") > 0 Then
				
				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": turnover";
				NewIndicator.Name = Resource.Name + "Turnover";
				NewIndicator.Use = False;
				
				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": turnover Dr";
				NewIndicator.Name = Resource.Name + "TurnoverDr";
				NewIndicator.Use = False;
				
				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": turnover Cr";
				NewIndicator.Name = Resource.Name + "TurnoverCr";
				NewIndicator.Use = False;
				
			ElsIf Find(Object.SourcePresentation,": Register records with additional dimensions") > 0 Then
				
				If NOT Resource.AccountingFlag = Undefined Then
					
					NewIndicator = Object.Indicators.Add();
					NewIndicator.Presentation = Resource.Name + ": Dr";
					NewIndicator.Name = Resource.Name + "Dr";
					NewIndicator.Use = False;
					
					NewIndicator = Object.Indicators.Add();
					NewIndicator.Presentation = Resource.Name + ": Cr";
					NewIndicator.Name = Resource.Name + "Cr";
					NewIndicator.Use = False;
					
				Else
					
					NewIndicator = Object.Indicators.Add();
					NewIndicator.Presentation = Resource.Name;
					NewIndicator.Name = Resource.Name;
					NewIndicator.Use = False;
		
				EndIf;
				
			EndIf;
        			
      	EndIf;
        
	EndDo;

	If Object.Indicators.Count() > 0 Then
		Object.Indicators[0].Use = True;
	EndIf; 

	// 4. Data filter periods.
	If Periodic Then

		If Find(Object.SourcePresentation, "turnovers") > 0 OR Find(Object.SourcePresentation, "registerRecords:") > 0 Then

			NewFilterBoundary = Object.DataFilterPeriods.Add();
			NewFilterBoundary.BoundaryDateName			= "Beginofperiod";
			NewFilterBoundary.BoundaryDatePresentation	= "Data filter start date";
			NewFilterBoundary.PeriodBoundaryType		= Enums.PeriodRangeTypes.Beginofperiod;

			NewFilterBoundary = Object.DataFilterPeriods.Add();
			NewFilterBoundary.BoundaryDateName			= "Endofperiod";
			NewFilterBoundary.BoundaryDatePresentation 	= "Data filter end date";
			NewFilterBoundary.PeriodBoundaryType		= Enums.PeriodRangeTypes.Endofperiod;

		Else

			NewFilterBoundary = Object.DataFilterPeriods.Add();
			NewFilterBoundary.BoundaryDateName 			= "PointInTime";
			NewFilterBoundary.BoundaryDatePresentation	= "Date values";
			NewFilterBoundary.PeriodBoundaryType		= Enums.PeriodRangeTypes.Beginofperiod;

		EndIf;

	EndIf;
    	
	// 5. Filter.
	InitializeFilter(MetadataSource);
  	 
EndProcedure // FillIndicatorsAndSourceDataFilterPeriods()

&AtServer
// Procedure initializes data source filter.
//
Procedure InitializeFilter(MetadataSource)

	CompositionScheme = New DataCompositionSchema();		
		
	Source = CompositionScheme.DataSources.Add();
	Source.Name = "Source1";
	Source.ConnectionString="";
	Source.DataSourceType = "local";
	
	QueryText = "SELECT";
	ValFlag = False;
    For each Dimension In MetadataSource.Dimensions Do

		If ValFlag Then

			QueryText = 	QueryText + ",
							| " + Dimension.Name;

		Else
        	
			QueryText = 	QueryText + "
							| " + Dimension.Name;

		EndIf;
                  
		ValFlag = True;	
  
    EndDo;

    QueryText = 	QueryText + " 
					|FROM " + Object.SourceName;
    
	DataSet = CompositionScheme.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	DataSet.Query = QueryText;
	DataSet.Name = "Query";
	DataSet.DataSource = "Source1";
                                   
	TemporaryStorageAddress = PutToTempStorage(CompositionScheme, Uuid);
	SettingsSource = New DataCompositionAvailableSettingsSource(TemporaryStorageAddress);	
	DataFilter.Initialize(SettingsSource);

EndProcedure // InitializeFilter()

// Procedure applies filter.
//
Procedure SetFilter()

	If Not Object.CustomQuery Then

		DataFilter.Settings.Filter.Items.Clear();

		// Fill filter.
		For each StringOfParameters In Object.QueryParameters Do

			If StringOfParameters.Name <> "PointInTime"
				And StringOfParameters.Name <> "Beginofperiod"
				And StringOfParameters.Name <> "Endofperiod" Then

				FilterItem = DataFilter.Settings.Filter.Items.Add(Type("DataCompositionFilterItem"));
				FilterItem.LeftValue = New DataCompositionField(StringOfParameters.Name);
				If StringOfParameters.ComparisonType = "" Then
					FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
				Else
				    FilterItem.ComparisonType = DataCompositionComparisonType[StrReplace(StringOfParameters.ComparisonType," ","")];
				EndIf; 
				FilterItem.RightValue = StringOfParameters.Value;

			EndIf;

		EndDo;			
	
	EndIf;

EndProcedure // SetFilter()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM EVENTS HANDLERS

&AtServer
// Procedure - handler of event OnCreateAtServer of form.
//
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
		
	If ValueIsFilled(Object.Ref) And ValueIsFilled(Object.SourceName) Then

		SourceKindByMetadata = Left(Object.SourceName, Find(Object.SourceName,".")-1);

		TableOfSource = StrReplace(Object.SourceName, SourceKindByMetadata + "." , "");
		
	    Periodic = True;
		Acc = Find(TableOfSource,".");
		
		If Acc > 0 Then	
			SourceNameByMetadata = Left(TableOfSource, Acc - 1);

		ElsIf Find(Object.SourcePresentation, "registerRecords:") > 0 Then
			SourceNameByMetadata = TableOfSource;

		Else
			SourceNameByMetadata = TableOfSource;
			Periodic = False;  
				
		EndIf;

	    MetadataSource = Metadata[StrReplace(SourceKindByMetadata, "Register", "Registers")][SourceNameByMetadata];

		InitializeFilter(MetadataSource);

		SetFilter();

	EndIf;

	QueryText = Object.Query;
    EditQuery = False;
	Items.Query.Enabled = False;
	
	Items.QueryParameters.Enabled = Object.CustomQuery;
	Items.EditQuery.Enabled = Object.CustomQuery;
	
	Items.Source.Enabled = NOT Object.CustomQuery; 
	Items.DataFilterPeriods.Enabled = NOT Object.CustomQuery; 
	Items.Indicators.Enabled = NOT Object.CustomQuery; 
	Items.DataFilterSettingsFilter.Enabled = NOT Object.CustomQuery;
	Items.DataFilterSettingsFilterCommandBar.Enabled = NOT Object.CustomQuery; 

	Items.Source.Visible = NOT Object.SetValueDuringPayrollCalculation;
	Items.CustomQuery.Visible = NOT Object.SetValueDuringPayrollCalculation;
	Items.Pages.Visible = NOT Object.SetValueDuringPayrollCalculation;
	
EndProcedure // OnCreateAtServer()

&AtClient
// Procedure - handler of event OnOpen of form.
//
Procedure OnOpen(Cancellation)
	
	#If ThinClient OR WebClient Then
		Items.QueryWizard.Enabled = False;
	#Else
		Items.QueryWizard.Enabled = Object.CustomQuery;
	#EndIf
	
EndProcedure

&AtServer
// Procedure - handler of event BeforeWriteAtServer of form.
//
Procedure BeforeWriteAtServer(Cancellation, CurrentObject, WriteParameters)
	
	CheckForIDDuplication(Cancellation);
	If Cancellation Then
		Return;
	EndIf;
    
    If NOT Object.SetValueDuringPayrollCalculation And NOT Object.CustomQuery Then

        Cancellation = CheckForIndicatorChoice();
 		If Cancellation Then
			Return;
		EndIf;
	
		GenerateQueryFillParameters();

	ElsIf NOT Object.SetValueDuringPayrollCalculation And Object.CustomQuery Then

        Cancellation = NOT QueryCorrect();

	EndIf;   
	
EndProcedure // BeforeWriteAtServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - ACTIONS OF FORM COMMAND BARS

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - EVENT HANDLERS OF FORM ATTRIBUTES

&AtClient
// Procedure - handler of event StartChoice of field Source.
//
Procedure SourceStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
    ChoiceSturcutre = OpenFormModal("Catalog.CalculationParameters.Form.SourceChoiceForm");

	If ChoiceSturcutre = Undefined Then 
    	Return;
	EndIf;

    Object.SourceName = ChoiceSturcutre.Source;
    Object.SourcePresentation = ChoiceSturcutre.FieldPresentation;
         
    Object.Indicators.Clear();
    Object.DataFilterPeriods.Clear();
    Object.QueryParameters.Clear();
	Object.Query = "";
    	
	FillIndicatorsAndSourceDataFilterPeriods();
	GenerateQueryFillParameters();
    
EndProcedure // SourceStartChoice()

&AtClient
// Procedure - handler of click on button QueryWizard.
//
Procedure QueryWizard(Command)

    OpenQueryWizard();

EndProcedure // QueryWizardExecute()

&AtClient
// Procedure - handler of event Execute of field EditQuery.
//
Procedure EditQuery(Command)

    If Object.CustomQuery Then
	
		If EditQuery Then
	        If NOT QueryCorrect() Then
                Response = DoQueryBox(NStr("en = 'The query contains errors! Clear and return to the original query?'"), QuestionDialogMode.YesNo, 0);
				If Response = DialogReturnCode.Yes Then
			    	Object.Query = QueryText;
                EndIf;
            Else
                FillParametersByQuery();
			EndIf; 
	    Else
			QueryText = Object.Query;
	    EndIf; 

		EditQuery = NOT EditQuery;
		Items.EditQuery.Check = EditQuery;
		Items.Pages.CurrentPage = Items.GroupQuery;
		Items.Query.Enabled = EditQuery;
	
	EndIf; 

EndProcedure // EditQueryExecute()
 	
&AtClient
// Procedure - handler of event OnChange of field Description.
//
Procedure DescriptionOnChange(Item)
     
    GetID(Object.Description);

EndProcedure // DescriptionOnChange()

&AtClient
// Procedure - handler of event OnChange of field AssignValueOnZPPCalculation.
//
Procedure SetValueDuringPayrollCalculationOnChange(Item)
	
	If NOT Object.SetValueDuringPayrollCalculation Then
		Items.Source.Visible = NOT Object.SetValueDuringPayrollCalculation;
		Items.CustomQuery.Visible = NOT Object.SetValueDuringPayrollCalculation;
		Items.Pages.Visible = NOT Object.SetValueDuringPayrollCalculation;
		Return;	
	EndIf; 
	
	TextOfMessage = NStr("en = 'After checking the flag all attributes will be cleared. Do you want to continue?'");
	QuestionResult = DoQueryBox(TextOfMessage, QuestionDialogMode.YesNo);
	If QuestionResult <> DialogReturnCode.Yes Then
		Object.SetValueDuringPayrollCalculation = NOT Object.SetValueDuringPayrollCalculation;
		Return;
	EndIf;
	
	Object.SourceName = "";
	Object.SourcePresentation = "";
	Object.Query = "";
	Object.CustomQuery = False;
	Object.DataFilterPeriods.Clear();
	Object.Indicators.Clear();
	Object.QueryParameters.Clear();
	
	Items.Source.Visible = NOT Object.SetValueDuringPayrollCalculation;
	Items.CustomQuery.Visible = NOT Object.SetValueDuringPayrollCalculation;
	Items.Pages.Visible = NOT Object.SetValueDuringPayrollCalculation;
	
EndProcedure

&AtClient
// Procedure - handler of event OnChange of field CustomQuery.
//
Procedure CustomQueryOnChange(Item)

	#If ThinClient OR WebClient Then
		Items.QueryWizard.Enabled = False;
	#Else
		Items.QueryWizard.Enabled = Object.CustomQuery;
	#EndIf
	Items.EditQuery.Enabled = Object.CustomQuery;
	
	If Object.CustomQuery Then

		Items.QueryParameters.Enabled = True;
		Items.EditQuery.Enabled = True;
		
		Items.Source.Enabled = False; 
		Items.DataFilterPeriods.Enabled = False; 
		Items.Indicators.Enabled = False; 
		Items.DataFilterSettingsFilter.Enabled = False;
		Items.DataFilterSettingsFilterCommandBar.Enabled = False;
		
		Object.SourceName = "";
		Object.SourcePresentation = "";
		Object.DataFilterPeriods.Clear();
		Object.Indicators.Clear();
		DataFilter.Settings.Filter.Items.Clear();
		
	Else	
		
		Items.QueryParameters.Enabled = False;
		EditQuery = False;
		Items.Query.Enabled = False;
		Items.EditQuery.Enabled = False;
		
		Items.Source.Enabled = True; 
		Items.DataFilterPeriods.Enabled = True; 
		Items.Indicators.Enabled = True; 
		Items.DataFilterSettingsFilter.Enabled = True;
		Items.DataFilterSettingsFilterCommandBar.Enabled = True;		
		
		Object.Query = "";
		Object.QueryParameters.Clear();
		
	EndIf; 
    
EndProcedure // CustomQueryOnChange()

&AtClient
// Procedure - handler of event OnChange of field CustomQuery.
//
Procedure IndicatorsUsageOnChange(Item)
	                                      
	If Items.Indicators.CurrentData.Use Then
		For each TSLine In Object.Indicators Do
            If TSLine <> Items.Indicators.CurrentData Then
				TSLine.Use = False;
			EndIf; 
		EndDo; 
	EndIf; 

EndProcedure // UsageOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - EVENT HANDLERS OF ATTRIBUTES OF TABULAR SECTIONS

&AtClient
// Procedure - handler of event OnEditEnd of table Filter.
//
Procedure DataFilterSettingsFilterOnEditEnd(Item, NewRow, CancelEdit)
	
	If NOT Object.CustomQuery Then
		GenerateQueryFillParameters();
	EndIf;

EndProcedure // FilterOnEditEnd()

&AtClient
// Procedure - handler of event OnEditEnd of table Indicators.
//
Procedure IndicatorsOnEditEnd(Item, NewRow, CancelEdit)
	
	If NOT Object.CustomQuery Then
		GenerateQueryFillParameters();
	EndIf;

EndProcedure // IndicatorsOnEditEnd()

&AtClient
// Procedure - handler of event AfterDeleteRow of table Filter.
//
Procedure DataFilterSettingsFilterAfterDeleteRow(Item)
	
	If NOT Object.CustomQuery Then
		GenerateQueryFillParameters();
	EndIf;
	
EndProcedure

&AtClient
// Procedure - handler of event Clearing of field Source.
//
Procedure SourceClear(Item, StandardProcessing)
	
	Object.SourceName = "";
	Object.SourcePresentation = "";
	Object.DataFilterPeriods.Clear();
	Object.Indicators.Clear();	
	Object.Query = "";
	Object.QueryParameters.Clear();
	
EndProcedure

&AtClient
// Procedure - handler of event BeforeAddRow of table Indicators.
//
Procedure IndicatorsBeforeAddLine(Item, Cancellation, Clone, Parent, Folder)
	
	Cancellation = True;
	
EndProcedure

&AtClient
// Procedure - handler of event BeforeAddRow of table DataFilterPeriods.
//
Procedure DataFilterPeriodsBeforeAddLine(Item, Cancellation, Clone, Parent, Folder)
	
	Cancellation = True;	
	
EndProcedure

&AtClient
// Procedure - handler of event BeforeAddRow of table QueryParameters.
//
Procedure QueryParametersBeforeAddRow(Item, Cancellation, Clone, Parent, Folder)
	
	Cancellation = True;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FILLING BY TEMPLATES

&AtClient
Procedure CreateFixedAmount(Command)
	
	Response = DoQueryBox(NStr("en = 'Calculation parameter will be completely re-filled. Do you want to continue?'"), QuestionDialogMode.YesNo, 0);
	If Response = DialogReturnCode.Yes Then
		FillByTemplate("FixedAmount");		
	EndIf;
	
EndProcedure

&AtClient
Procedure CreateNormOfDays(Command)
	
	Response = DoQueryBox(NStr("en = 'Calculation parameter will be completely re-filled. Do you want to continue?'"), QuestionDialogMode.YesNo, 0);
	If Response = DialogReturnCode.Yes Then
		FillByTemplate("PlannedWorkDays");		
	EndIf;
	
EndProcedure

&AtClient
Procedure CreateNormOfHours(Command)
	
	Response = DoQueryBox(NStr("en = 'Calculation parameter will be completely re-filled. Do you want to continue?'"), QuestionDialogMode.YesNo, 0);
	If Response = DialogReturnCode.Yes Then
		FillByTemplate("PlannedWorkHours");		
	EndIf;
	
EndProcedure

&AtClient
Procedure CreateDaysWorked(Command)
	
	Response = DoQueryBox(NStr("en = 'Calculation parameter will be completely re-filled. Do you want to continue?'"), QuestionDialogMode.YesNo, 0);
	If Response = DialogReturnCode.Yes Then
		FillByTemplate("DaysWorked");		
	EndIf;
	
EndProcedure

&AtClient
Procedure CreateHoursWorked(Command)
	
	Response = DoQueryBox(NStr("en = 'Calculation parameter will be completely re-filled. Do you want to continue?'"), QuestionDialogMode.YesNo, 0);
	If Response = DialogReturnCode.Yes Then
		FillByTemplate("HoursWorked");		
	EndIf;
	
EndProcedure

&AtClient
Procedure CreatePayRate(Command)
	
	Response = DoQueryBox(NStr("en = 'Calculation parameter will be completely re-filled. Do you want to continue?'"), QuestionDialogMode.YesNo, 0);
	If Response = DialogReturnCode.Yes Then
		FillByTemplate("PayRate");		
	EndIf;
	
EndProcedure
 

