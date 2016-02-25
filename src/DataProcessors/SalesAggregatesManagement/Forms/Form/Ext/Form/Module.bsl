&AtServer
Procedure UseScheduledJob(Name, Use)
	Job = ScheduledJobs.FindPredefined(Name);
	Job.Use = Use;
	Job.Write();
EndProcedure

// Updates the form state by the register aggregates mode
&AtServer
Procedure UpdateForm()
	AggregatesMode = AccumulationRegisters.Sales.GetAggregatesMode();	
	
	// The items Enabled flag.
	Items.UpdatesGroup.Enabled = AggregatesMode;
	Items.GroupRebuilding.Enabled = AggregatesMode;
	
	// Scheduled jobs checks.
	ScheduledRebuilding = ScheduledJobs.FindPredefined("RebuildingSalesAggregates").Use;
	ScheduledUpdate = ScheduledJobs.FindPredefined("UpdateSalesAggregates").Use;
	
	// The rebuild status.
	Aggregates = AccumulationRegisters.Sales.GetAggregates();
	Rebuilding = NStr("en = 'Rebuilt: '") 
		+ Aggregates.BuildDate 
		+ NStr("en ='. Effect: '")  
		+ Aggregates.Effect
		+ NStr("en ='. Size: '") 
		+ Aggregates.Size
		+ ".";
EndProcedure

&AtServer
Procedure ChangeAggregatesMode()
	// Switches the aggregates mode. Turns the register into working state. Switches scheduled jobs, if any.
	If AggregatesMode Then
		// Turning on the aggregates mode.
		AccumulationRegisters.Sales.SetAggregatesMode(True);
		
		// Rebuilding the aggregates usage.
		AccumulationRegisters.Sales.RebuildAggregatesUsing();
		
		// Aggregates update (not portioning).
		AccumulationRegisters.Sales.UpdateAggregates(False);
	Else             
		// Disabling the aggregates mode.
		AccumulationRegisters.Sales.SetAggregatesMode(False);
	EndIf;
EndProcedure

&AtClient
Procedure AggregatesModeOnChange(Element)
	ChangeAggregatesMode();
	UpdateForm();	
EndProcedure

&AtServer
Procedure UpdateAggregates()
	// Non portional aggregates update.
	AccumulationRegisters.Sales.UpdateAggregates(False);
EndProcedure

&AtClient
Procedure UpdateClick(Command)
	Status(NStr("en = 'Wait!'") 
		+ Chars.CR 
		+ NStr("en = 'Updating aggregates...'"));	
	
	UpdateAggregates();
	
	Status(NStr("en = 'Aggregates have been updated.'"));		
EndProcedure

&AtClient
Procedure ScheduledUpdateOnChange(Element)
	UseScheduledJob("UpdateSalesAggregates", ScheduledUpdate);
	UpdateForm();	
EndProcedure

&AtServer
Procedure RebuildAggregatesUsing()
	AccumulationRegisters.Sales.RebuildAggregatesUsing();
EndProcedure

&AtClient
Procedure Rebuild(Command)
	Status(NStr("en = 'Wait!'") 
		+ Chars.CR 
		+ NStr("en = 'Rebuilding the aggregates usage...'"));	
	
	RebuildAggregatesUsing();
	
	UpdateForm();
	Status(NStr("en = 'Aggregates usage rebuild is completed...'"));	
EndProcedure

&AtClient
Procedure ScheduledRebuildingOnChange(Element)
	UseScheduledJob("RebuildingSalesAggregates", ScheduledRebuilding);
	UpdateForm();	
EndProcedure

&AtServer
Function DetermineOptimalAggregates()
	
	OptimalAggregates = AccumulationRegisters.Sales.DetermineOptimalAggregates();
	
	// The optimal aggregates determinition state.
	If DetermineOptimality(OptimalAggregates.Aggregates) Then
		 Optimality = NStr("en = 'Optimal: '");	// The configuration aggregates list might be optimal.
	Else
		 Optimality = NStr("en = 'Not Optimal'");	// The configuration aggregates list cannot be optimal.
	EndIf;
	
	Optimality = Optimality + OptimalAggregates.BuildDate 
		+ NStr("en ='. Effect: '") 
		+ OptimalAggregates.Effect 
		+ NStr("en ='. Size: '") 
		+ OptimalAggregates.Size 
		+ ".";
					
	TemporaryFileName = GetTempFileName("XML");
	
	XMLWriter = New XMLWriter();
	XMLWriter.OpenFile(TemporaryFileName);
	XMLWriter.WriteXMLDeclaration();
	XDTOSerializer.WriteXML(XMLWriter, OptimalAggregates);
	XMLWriter.Close();
	
	Return PutToTempStorage(New BinaryData(TemporaryFileName), Uuid);

EndFunction

&AtClient
Procedure DetermineOptimal(Command)
	Status(NStr("en = 'Wait!'") 
		+ Chars.CR 
		+ NStr("en = 'Determining the optimal aggregates...'"));	
	
	TemporaryStorageAddress = DetermineOptimalAggregates();
	
	GetFile(TemporaryStorageAddress, "OptimalAggregates.xml");
     	
	Status(NStr("en = 'Optimal aggregates determination is completed.'"));	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	UpdateForm();
EndProcedure

// Determines whether the configuration aggregates list can be optimal.
&AtServer
Function DetermineOptimality(OptimalAggregates)
	AggregatesConfig = Metadata.AccumulationRegisters.Sales.Aggregates;
	
	// The configuration aggregates indexes, which match the optimal aggregates.
	FoundAggregates = New Map();
	
	// For every optimal aggregate there must be a corresponding configuration aggregate.
	For Each OptimalAggregate In OptimalAggregates Do
		Found = False;
		
		// Searching for the aggregate with the exact match for the period and dimensions. 
		// The Aggregate must not to be in FoundAggregates.
		For AggrConf = 0 To AggregatesConfig.Count() - 1 Do
			If OptimalAggregate.Periodicity = AggregatesConfig[AggrConf].Periodicity And
				 FoundAggregates[AggrConf] = Undefined And
				 AggregatesDimensionsMatch(OptimalAggregate, AggregatesConfig[AggrConf]) Then
				 
				 // Marking the aggregate as a reserved.
				 FoundAggregates.Insert(AggrConf, True);
				 Found = True;
				 Break;
			EndIf
		EndDo;
		
		If Found Then
			Continue;
		EndIf;
		
		// Searching for the aggregate with Auto period and direct match of the dimensions, if not found.
		// The Aggregate must not to be in FoundAggregates.
		For AggrConf = 0 To AggregatesConfig.Count() - 1 Do
			If AggregatesConfig[AggrConf].Periodicity = AccumulationRegisterAggregatePeriodicity.Auto And
				 FoundAggregates[AggrConf] = Undefined And
				 AggregatesDimensionsMatch(OptimalAggregate, AggregatesConfig[AggrConf]) Then
				 
				 // Marking the aggregate as a reserved.
				 FoundAggregates.Insert(AggrConf, True);
				 Found = True;
				 Break;
			EndIf
		EndDo;
		
		If Not Found Then
			Return False;
		EndIf;
			
	EndDo;
	
	Return True;
EndFunction

// Checks whether the optimal aggregate dimensions match the configuration aggregate dimensions.
&AtServer
Function AggregatesDimensionsMatch(OptimalAggregate, AggregateConfig)
	
	// The number of dimensions must be the same.
	If OptimalAggregate.Dimensions.Count() <> AggregateConfig.Dimensions.Count() Then
		Return False;
	EndIf;
	
	// For every optimal aggregate dimension there should be the same dimension in the configuration aggregate.
	For Each Aggregate In OptimalAggregate.Dimensions Do
		Found = False;
		
		// Searching for the dimension the configuration aggregate.
		For Each Dimension In AggregateConfig.Dimensions Do
			If Aggregate = Dimension.Name Then
				Found = True;
				Break;
			EndIf;
		EndDo;
		
		If Not Found Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
EndFunction

