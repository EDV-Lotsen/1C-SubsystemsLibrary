
////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

Procedure OnWrite(Cancellation)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not IsFolder Then
		
		RecordSetNameAndSurname = InformationRegisters.IndividualsNameAndSurname.CreateRecordSet();
		
		Query = New Query("SELECT
		                      |	IndividualsNameAndSurnameSliceLast.Surname,
		                      |	IndividualsNameAndSurnameSliceLast.Name,
		                      |	IndividualsNameAndSurnameSliceLast.Patronymic
		                      |FROM
		                      |	InformationRegister.IndividualsNameAndSurname.SliceLast(, Individual = &Individual) AS IndividualsNameAndSurnameSliceLast");
							  
		Query.SetParameter("Individual", Ref);
		QueryResult = Query.Execute();
		
		// set has already been recorded
		If Not QueryResult.IsEmpty() Then
			Return;
		EndIf;
		
		NameAndSurname = Description;
		
		Name      	= StandardSubsystemsServer.SelectWord(NameAndSurname);
		Patronymic 	= StandardSubsystemsServer.SelectWord(NameAndSurname);
		Surname  	= StandardSubsystemsServer.SelectWord(NameAndSurname);

		RecordOfSet 			= RecordSetNameAndSurname.Add();
		RecordOfSet.Period		= ?(ValueIsFilled(BirthDate), BirthDate, '19000101');
		RecordOfSet.Surname		= Surname;
		RecordOfSet.Name		= Name;
		RecordOfSet.Patronymic	= Patronymic;
		
		If RecordSetNameAndSurname.Count() > 0 And ValueIsFilled(RecordSetNameAndSurname[0].Period) Then
			
			RecordSetNameAndSurname[0].Individual = Ref;
			
			RecordSetNameAndSurname.Filter.Individual.Use			= True;
			RecordSetNameAndSurname.Filter.Individual.Value		= RecordSetNameAndSurname[0].Individual;
			RecordSetNameAndSurname.Filter.Period.Use		= True;
			RecordSetNameAndSurname.Filter.Period.Value		= RecordSetNameAndSurname[0].Period;
			If Not ValueIsFilled(RecordOfSet.Surname + RecordOfSet.Name + RecordOfSet.Patronymic) Then
				RecordOfSet.Surname		= Surname;
				RecordOfSet.Name		= Name;
				RecordOfSet.Patronymic	= Patronymic;
			EndIf;
			
			RecordSetNameAndSurname.Write(True);
			
		EndIf;	
		
	EndIf;
	
EndProcedure
