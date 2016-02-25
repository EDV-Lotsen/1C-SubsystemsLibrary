
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	SetObjectVisibilitiesUsingODataAPI();
EndProcedure


Procedure SetObjectVisibilitiesUsingODataAPI()
	Array = New Array();
	
	For Each Catalog In Metadata.Catalogs Do
		Array.Add(Catalog);
	EndDo;
	
	For Each Document In Metadata.Documents Do
			Array.Add(Document);
	EndDo;
	
	For Each Enumeration In Metadata.Enums Do
		Array.Add(Enumeration);
	EndDo;
	
	For Each InformationRegister In Metadata.InformationRegisters Do
		Array.Add(InformationRegister);
	EndDo;
	
	For Each AccumulationRegister In Metadata.AccumulationRegisters Do
		Array.Add(AccumulationRegister);
	EndDo;		

	For Each ChartOfCharacteristicTypes In Metadata.ChartsOfCharacteristicTypes Do
		Array.Add(ChartOfCharacteristicTypes);
	EndDo;	

	
	For Each Constant In Metadata.Constants Do
		Array.Add(Constant);
	EndDo;
	
	For Each Journals In Metadata.DocumentJournals Do
		Array.Add(Journals);
	EndDo;
	
	SetStandardODataInterfaceContent(Array);
EndProcedure	