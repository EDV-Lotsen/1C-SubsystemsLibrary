

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM EVENTS HANDLERS

&AtServer
// Procedure - handler of event OnCreateAtServer of form.
//
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	ValueTree = New ValueTree;
	
	ArrayOfTypes = New Array;
	ArrayOfTypes.Add(Type("String"));
	SQ = New StringQualifiers(100);
	DetailsLine = New TypeDescription(ArrayOfTypes, SQ);
	ContentColumns = ValueTree.Columns;
	
	ContentColumns.Add("FieldDetails", 		DetailsLine);
	ContentColumns.Add("FieldPresentation", 		DetailsLine);
	ContentColumns.Add("Source", 					DetailsLine);
	ContentColumns.Add("FieldName", 				DetailsLine);

 	NewSource = ValueTree.Rows.Add();
	NewSource.FieldDetails = "Accounting information";

	For Each MetadataRegister In Metadata.AccumulationRegisters Do

		If MetadataRegister.Resources.Count() = 0 Then
			Continue;
		EndIf;
		
		Sources = NewSource.Rows.Add();
		Sources.Source 					= "AccumulationRegister." + MetadataRegister.Name;
		Sources.FieldDetails 	= MetadataRegister.Presentation();
		
		SourceTable = Sources.Rows.Add();
		SourceTable.Source 						= "AccumulationRegister." + MetadataRegister.Name;
		SourceTable.FieldDetails 		= "RegisterRecords";
		
		If MetadataRegister.RegisterType = Metadata.ObjectProperties.AccumulationRegisterType.Balance Then
			
			SourceTableReceipt = SourceTable.Rows.Add();
			SourceTableReceipt.Source 				= "AccumulationRegister." + MetadataRegister.Name;
			SourceTableReceipt.FieldPresentation 	= MetadataRegister.Presentation() + " registerRecords: receipt";
			SourceTableReceipt.FieldDetails = "registerRecords: receipt";		
			SourceTableReceipt.FieldName 			= MetadataRegister.Name + "RegisterRecordsDebit";
			
			SourceTableExpense = SourceTable.Rows.Add();
			SourceTableExpense.Source 				= "AccumulationRegister." + MetadataRegister.Name;
			SourceTableExpense.FieldPresentation	= MetadataRegister.Presentation() + " registerRecords: expense";
			SourceTableExpense.FieldDetails = "registerRecords: expense";		
			SourceTableExpense.FieldName 			= MetadataRegister.Name + "RegisterRecordsExpense";
			
		Else
			
			SourceTableRecord = SourceTable.Rows.Add();
			SourceTableRecord.Source 				= "AccumulationRegister." + MetadataRegister.Name;
			SourceTableRecord.FieldPresentation 	= MetadataRegister.Presentation() + " registerRecords: turnover";
			SourceTableRecord.FieldDetails 	= "registerRecords: turnover";		
			SourceTableRecord.FieldName 			= MetadataRegister.Name + "RegisterRecordsTurnover";

		EndIf;
		
		If MetadataRegister.RegisterType = Metadata.ObjectProperties.AccumulationRegisterType.Balance Then

			SourceTable = Sources.Rows.Add();
			SourceTable.Source 					= "AccumulationRegister." + MetadataRegister.Name + ".Balance(&PointInTime,)";
			SourceTable.FieldPresentation		= MetadataRegister.Presentation() + ": Balance";
			SourceTable.FieldDetails	= "Balance";
			SourceTable.FieldName				= MetadataRegister.Name + "Balance";

			SourceTable = Sources.Rows.Add();
			SourceTable.Source 					= "AccumulationRegister." + MetadataRegister.Name + ".Turnovers(&Beginofperiod,&Endofperiod,Auto,)";
			SourceTable.FieldPresentation 		= MetadataRegister.Presentation() + ": turnovers";
			SourceTable.FieldDetails 	= "Turnovers";
			SourceTable.FieldName				= MetadataRegister.Name+"Turnovers";

			SourceTable = Sources.Rows.Add();
			SourceTable.Source 					= "AccumulationRegister." + MetadataRegister.Name + ".BalanceAndTurnovers(&Beginofperiod,&Endofperiod,Auto,,)";
			SourceTable.FieldPresentation 		= MetadataRegister.Presentation() + ": Balance And turnovers";
			SourceTable.FieldDetails 	= "Balance And turnovers";
			SourceTable.FieldName				= MetadataRegister.Name + "BalanceAndTurnovers";

		Else

			SourceTable = Sources.Rows.Add();
			SourceTable.Source 					= "AccumulationRegister." + MetadataRegister.Name + ".Turnovers(&Beginofperiod,&Endofperiod,Auto,)";
			SourceTable.FieldPresentation 		= MetadataRegister.Presentation() + ": turnovers";
			SourceTable.FieldDetails 	= "Turnovers";
			SourceTable.FieldName 				= MetadataRegister.Name + "Turnovers";
                                            	
		EndIf;

	EndDo;

	NewSource = ValueTree.Rows.Add();
	NewSource.FieldDetails = "OfHelpType information";

	For Each MetadataRegister In Metadata.InformationRegisters Do

		NumericResources = 0;

		For each Resource In MetadataRegister.Resources Do	

			ResourceTypes = Resource.Type.Types();

			If ResourceTypes.Count() = 1 And ResourceTypes[0] = Type("Number") Then
				NumericResources = NumericResources + 1;
			EndIf;
		
		EndDo; 
		
		If NumericResources = 0 Then
			Continue;
		EndIf;

		Sources = NewSource.Rows.Add();

		If String(MetadataRegister.InformationRegisterPeriodicity) = "Nonperiodical" Then
			Sources.Source = "InformationRegister." + MetadataRegister.Name;
		Else
			Sources.Source = "InformationRegister." + MetadataRegister.Name + ".SliceLast(&PointInTime,)";
		EndIf;
		
		Sources.FieldPresentation 		= MetadataRegister.Presentation();
		Sources.FieldDetails 	= MetadataRegister.Presentation();
		Sources.FieldName 				= MetadataRegister.Name;

	EndDo;	
	
	NewSource = ValueTree.Rows.Add();
	NewSource.FieldDetails = "Balance and turnovers by charts of accounts";

	For Each MetadataRegister In Metadata.AccountingRegisters Do

		If MetadataRegister.Resources.Count()=0 Then
			
			Continue;
			
		EndIf;

		RegisterSource	= NewSource.Rows.Add();
		RegisterSource.Source = "AccountingRegister." + MetadataRegister.Name;
		RegisterSource.FieldDetails = MetadataRegister.Presentation();

		RegisterSourceTable = RegisterSource.Rows.Add();
		RegisterSourceTable.Source = "AccountingRegister." + MetadataRegister.Name + ".Turnovers(&Beginofperiod,&Endofperiod,Day,,)";
		RegisterSourceTable.FieldPresentation = MetadataRegister.Presentation() + ": turnovers";
		RegisterSourceTable.FieldDetails = "Turnovers";
		RegisterSourceTable.FieldName = MetadataRegister.Name + "Turnovers";
		
		RegisterSourceTable = RegisterSource.Rows.Add();
		RegisterSourceTable.Source = "AccountingRegister." + MetadataRegister.Name + ".Balance(&PointInTime,,) ";
		RegisterSourceTable.FieldPresentation = MetadataRegister.Presentation() + ": Balance";
		RegisterSourceTable.FieldDetails = "Balance";
		RegisterSourceTable.FieldName = MetadataRegister.Name + "Balance";

		RegisterSourceTable = RegisterSource.Rows.Add();
		RegisterSourceTable.Source = "AccountingRegister." + MetadataRegister.Name + ".BalanceAndTurnovers(&Beginofperiod,&Endofperiod,Day,,) ";
		RegisterSourceTable.FieldPresentation = MetadataRegister.Presentation() + ": Balance And turnovers";
		RegisterSourceTable.FieldDetails = "Balance And turnovers";
		RegisterSourceTable.FieldName = MetadataRegister.Name + "BalanceAndTurnovers";

	EndDo;
	
	ThisForm.ValueToFormAttribute(ValueTree, "Source");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - EVENT HANDLERS OF FORM ATTRIBUTES

&AtClient
// Procedure handler events OnOpen of form.
//
Procedure SourceSelection(Item, RowSelected, Field, StandardProcessing)
	
	If IsBlankString(Item.CurrentData.FieldPresentation) Then
		Return;
	EndIf;	
	
	ChoiceStructure = New Structure;
	ChoiceStructure.Insert("Source", 				Item.CurrentData.Source);
	ChoiceStructure.Insert("FieldDetails", 	Item.CurrentData.FieldDetails);
	ChoiceStructure.Insert("FieldName", 			Item.CurrentData.FieldName);
	ChoiceStructure.Insert("FieldPresentation", 	Item.CurrentData.FieldPresentation);
  
	Close(ChoiceStructure);
	
EndProcedure // SourceSelection()


