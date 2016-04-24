////////////////////////////////////////////////////////////////////////////////
// INTERNAL INTERFACE

// Cursor queries for independent record sets

Function GetDataPortionFromIndependentRecordSet(Val ObjectMetadata, Val Filter,
		Val PortionSize, CanContinue, State, Val TableNameSupplement = "") Export
	
	If State = Undefined Then
		State = InitializeStateForSelectingPortionsFromIndependentRecordSet(ObjectMetadata, Filter, TableNameSupplement);
		CanContinue = True;
	EndIf;
	
	Result = New Array;
	
	NotYetReceived = PortionSize; // Not yet received in this portion
	
	FirstSelection = False;
	
	CurrentQuery = 0; // Current query index
	
	While True Do // Getting portion fragments
		PortionFragment = Undefined; // Last received portion fragment
		
		If Not State.SelectionMade Then // First query
			State.SelectionMade = True;
			FirstSelection = True;
			
			Query = New Query;
			Query.Text = StrReplace(State.Requests.First, "[PortionSize]", Format(NotYetReceived, "NG="));
		Else
			Query = New Query;
			QueryDescription = State.Requests.Subsequent[CurrentQuery];
			CurrentQuery = CurrentQuery + 1;
			Query.Text = StrReplace(QueryDescription.Text, "[PortionSize]", Format(NotYetReceived, "NG="));
			For Each ConditionField In QueryDescription.ConditionFields Do
				Query.SetParameter(ConditionField, State.Key[ConditionField]);
			EndDo;
		EndIf;
		
		For Each FilterParameter In State.Requests.Parameters Do
			Query.SetParameter(FilterParameter.Key, FilterParameter.Value);
		EndDo;
		
		Query.Text = StrReplace(Query.Text, " Right,", " _Right,");
		
		PortionFragment = Query.Execute().Unload();
		
		For Each TableColumn In PortionFragment.Columns Do
			If TableColumn.Name = "_Right" Then
				TableColumn.Name = "Right";
			EndIf;
		EndDo;
		
		FragmentSize = PortionFragment.Count();
		
		If FragmentSize > 0 Then
			Result.Add(PortionFragment);
			
			FillPropertyValues(State.Key, PortionFragment[FragmentSize - 1]);
		EndIf;
		
		If FragmentSize < NotYetReceived Then
			
			If Not FirstSelection // If this is the first query, there is no point to continue
				And CurrentQuery < State.Requests.Subsequent.Count() Then
				
				NotYetReceived = NotYetReceived - FragmentSize;
				
				Continue; // Proceeding to the next query
			Else
				CanContinue = False;
			EndIf;
		EndIf;
		
		Break;
		
	EndDo;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Cursor queries for independent record sets

Function InitializeStateForSelectingPortionsFromIndependentRecordSet(Val ObjectMetadata, Val Filter, Val TableNameSupplement = "")
	
	IsInformationRegister    = Metadata.InformationRegisters.Contains(ObjectMetadata);
	
	IsSequence = Metadata.Sequences.Contains(ObjectMetadata);
	
	KeyFields = New Array; // Fields comprising the record key
	
	If IsInformationRegister And ObjectMetadata.InformationRegisterPeriodicity 
		<> Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical Then
		
		KeyFields.Add("Period");
	EndIf;
	
	If IsSequence Then 
		
		KeyFields.Add("Recorder");
		KeyFields.Add("Period");
		
	EndIf;
	
	AddSeparatorsToKey(ObjectMetadata, KeyFields);
	
	For Each DimensionMetadata In ObjectMetadata.Dimensions Do
		KeyFields.Add(DimensionMetadata.Name);
	EndDo;
	
	SelectionFields = New Array; // All fields
	
	If IsInformationRegister Then 
		
		For Each ResourceMetadata In ObjectMetadata.Resources Do
			SelectionFields.Add(ResourceMetadata.Name);
		EndDo;
		
		For Each AttributeMetadata In ObjectMetadata.Attributes Do
			SelectionFields.Add(AttributeMetadata.Name);
		EndDo;
		
	EndIf;
	
	For Each KeyField In KeyFields Do
		SelectionFields.Add(KeyField);
	EndDo;
	
	TableAlias = "_RecordSetTable"; // Table alias in query text
	
	SelectionFieldsString = ""; // Portion of query text containing the selection fields
	For Each SelectionField In SelectionFields Do
		If Not IsBlankString(SelectionFieldsString) Then
			SelectionFieldsString = SelectionFieldsString + "," + Chars.LF;
		EndIf;
		
		SelectionFieldsString = SelectionFieldsString + Chars.Tab + TableAlias + "." + SelectionField + " AS " + SelectionField;
	EndDo;
	
	OrderFieldsString = ""; //Portion of query text containing the order fields
	For Each KeyField In KeyFields Do
		If Not IsBlankString(OrderFieldsString) Then
			OrderFieldsString = OrderFieldsString + ", ";
		EndIf;
		OrderFieldsString = OrderFieldsString + KeyField;
	EndDo;
	
	If TypeOf(Filter) = Type("Array") Then
		Filter = GenerateFilterCondition(TableAlias, Filter);
	EndIf;
	
	// Preparing queries to get portions
	
	QueryPattern = // Common part of the query
	"SELECT TOP [PortionSize]
	|" + SelectionFieldsString + "
	|FROM
	|	" + ObjectMetadata.FullName() + TableNameSupplement + " AS " + TableAlias + "
	|[Condition]
	|ORDER BY
	|	" + OrderFieldsString;
	
	// Query to get the first portion
	If Not IsBlankString(Filter.FilterCriterion) Then
		GetFirstPortionQueryText = StrReplace(QueryPattern, 
			"[Condition]", 
			"WHERE
			|	" + Filter.FilterCriterion);
	Else
		GetFirstPortionQueryText = StrReplace(QueryPattern, "[Condition]", ""); // Query to get the first portion
	EndIf;
	
	Requests = New Array; // Queries to get the subsequent portions
	
	For QueryCounter = 0 To KeyFields.UBound() Do
		
		ConditionFieldsString = ""; // Portion of query text containing the condition fields
		ConditionFields = New Array; // Fields used in the condition
		
		ConditionFieldCount = KeyFields.Count() - QueryCounter;
		For FieldIndex = 0 To ConditionFieldCount - 1 Do
			If Not IsBlankString(ConditionFieldsString) Then
				ConditionFieldsString = ConditionFieldsString + " And ";
			EndIf;
			
			KeyField = KeyFields[FieldIndex];
			
			If FieldIndex = ConditionFieldCount - 1 Then
				LogicalOperator = ">";
			Else
				LogicalOperator = "=";
			EndIf;
			
			ConditionFieldsString = ConditionFieldsString + TableAlias + "." + KeyField + " " 
				+ LogicalOperator + " &" + KeyField;
				
			ConditionFields.Add(KeyField);
		EndDo;
		
		If Not IsBlankString(Filter.FilterCriterion) Then
			ConditionFieldsString = Filter.FilterCriterion + " And " + ConditionFieldsString;
		EndIf;
		
		QueryDescription = New Structure("Text, ConditionFields");
		QueryDescription.Text = StrReplace(QueryPattern, "[Condition]", 
			"WHERE
			|	" + ConditionFieldsString);
		QueryDescription.ConditionFields = New FixedArray(ConditionFields);
		
		Requests.Add(New FixedStructure(QueryDescription));
		
	EndDo;
	
	QueryDescriptions = New Structure;
	QueryDescriptions.Insert("First", GetFirstPortionQueryText);
	QueryDescriptions.Insert("Subsequent", New FixedArray(Requests));
	QueryDescriptions.Insert("Parameters", Filter.FilterParameters);
	
	KeyStructure = New Structure; // Structure used to store the latest key value
	For Each KeyField In KeyFields Do
		KeyStructure.Insert(KeyField);
	EndDo;
	
	State = New Structure;
	State.Insert("Requests", New FixedStructure(QueryDescriptions));
	State.Insert("Key", KeyStructure);
	State.Insert("SelectionMade", False);
	
	Return State;
	
EndFunction

Procedure AddSeparatorsToKey(ObjectMetadata, KeyFields)
	
	For Each CommonAttribute In Metadata.CommonAttributes Do 

		If Not CommonAttribute.SeparatedDataUse = Metadata.ObjectProperties.CommonAttributeSeparatedDataUse.IndependentlyAndSimultaneously Then 
			Continue;
		EndIf;
		
		CommonAttributeItem = CommonAttribute.Content.Find(ObjectMetadata);
		If CommonAttributeItem <> Undefined Then
			
			If ItemUsedInSeparator(CommonAttribute, CommonAttributeItem) Then  
				KeyFields.Add(CommonAttribute.Name);
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function ItemUsedInSeparator(CommonAttribute, CommonAttributeItem)
	
	CommonAttributeAutoUse = Metadata.ObjectProperties.CommonAttributeAutoUse;
	CommonAttributeUse     = Metadata.ObjectProperties.CommonAttributeUse;
	
	If CommonAttribute.AutoUse = CommonAttributeAutoUse.Use Then 
		If CommonAttributeItem.Use = CommonAttributeUse.Auto
			Or CommonAttributeItem.Use = CommonAttributeUse.Use Then 
				Return True;
		Else
				Return False;
		EndIf;
	Else
		If CommonAttributeItem.Use = CommonAttributeUse.Auto
			Or CommonAttributeItem.Use = CommonAttributeUse.DontUse Then 
				Return False;
		Else
				Return True;
		EndIf;
	EndIf;
	
EndFunction

Function GenerateFilterCondition(Val TableAlias, Val Filter)
	
	FilterRow = ""; // Portion of query text containing the filter condition
	FilterParameters = New Structure;
	If Filter.Count() > 0 Then
		For Each FilterDetails In Filter Do
			If Not IsBlankString(FilterRow) Then
				FilterRow = FilterRow + " And ";
			EndIf;
			
			ParameterName = "P" + Format(FilterParameters.Count(), "NZ=0;NG=");
			FilterParameters.Insert(ParameterName, FilterDetails.Value);
			
			Operand = "&" + ParameterName;
			
			If FilterDetails.ComparisonType = ComparisonType.Equal Then
				LogicalOperator = "=";
			ElsIf FilterDetails.ComparisonType = ComparisonType.NotEqual Then
				LogicalOperator = "<>";
			ElsIf FilterDetails.ComparisonType = ComparisonType.InList Then
				LogicalOperator = "IN";
				Operand = "(" + Operand + ")";
			ElsIf FilterDetails.ComparisonType = ComparisonType.NotInList Then
				LogicalOperator = "NOT IN";
				Operand = "(" + Operand + ")";
			ElsIf FilterDetails.ComparisonType = ComparisonType.Greater Then
				LogicalOperator = ">";
			ElsIf FilterDetails.ComparisonType = ComparisonType.GreaterOrEqual Then
				LogicalOperator = ">=";
			ElsIf FilterDetails.ComparisonType = ComparisonType.Less Then
				LogicalOperator = "<";
			ElsIf FilterDetails.ComparisonType = ComparisonType.LessOrEqual Then
				LogicalOperator = "<=";
			Else
				MessagePattern = NStr("en = 'Comparison kind %1 is not supported.'");
				MessageText = CTLAndSLIntegration.SubstituteParametersInString(MessagePattern, FilterDetails.ComparisonType);
			EndIf;
			
			FilterRow = FilterRow + TableAlias + "." + FilterDetails.Field + " " + LogicalOperator + " " + Operand;
		EndDo;
	EndIf;
	
	Return New Structure("FilterCriterion, FilterParameters", FilterRow, FilterParameters);
	
EndFunction

