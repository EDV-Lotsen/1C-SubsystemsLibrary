// Substitutes ObjectDeletion for data.
//
// Parameters:
//  Data - object, record set,... to be converted.
//
Procedure DeleteData(Data) 
	
	// Getting metadata object corresponding to the data
	MetadataObject = ?(TypeOf(Data) = Type("ObjectDeletion"), Data.Ref.Metadata(), Data.Metadata());
    // Verifying the type. Substituting ObjectDeletion only for data of types that are
    // present on the mobile platform.
	If Metadata.Catalogs.Contains(MetadataObject)
	 	Or Metadata.Documents.Contains(MetadataObject) Then
		
		// Substituting ObjectDeletion for data
		Data = New ObjectDeletion(Data.Ref);
		
	ElsIf Metadata.InformationRegisters.Contains(MetadataObject)
		Or Metadata.AccumulationRegisters.Contains(MetadataObject)
		Or Metadata.Sequences.Contains(MetadataObject) Then
		
		// Clearing data
		Data.Clear();
		
	EndIf;	
	
EndProcedure

// Generates the exchange batch to be sent to ExchangeNode. 
//
// Parameters:
//  ExchangeNode - 'Mobile' exchange plan node where the data is sent.
//
// Returns:
//  Batch placed in a value storage.
Function GenerateExchangeBatch(ExchangeNode) Export
    
	XMLWriter = New XMLWriter;
	
	XMLWriter.SetString("UTF-8");
	XMLWriter.WriteXMLDeclaration();
    
	WriteMessage = ExchangePlans.CreateMessageWriter();
    WriteMessage.BeginWrite(XMLWriter, ExchangeNode);					
    
	XMLWriter.WriteNamespaceMapping("xsi", "http://www.w3.org/2001/XMLSchema-instance");
	XMLWriter.WriteNamespaceMapping("v8",  "http://v8.1c.ru/data");
    
	DeletionDataType = Type("ObjectDeletion");
    
	ChangeSelection = ExchangePlans.SelectChanges(ExchangeNode, WriteMessage.MessageNo);
	While ChangeSelection.Next() Do
		
		Data = ChangeSelection.Get();
        
		// If no data transfer is required, perhaps OdjectDeletion must be writen
		If Not ExchangeMobileOverridable.DataTransferRequired(Data, ExchangeNode) Then
			
			// Getting the value where ObjectDeletionof is possible required
			DeleteData(Data); 
            
		EndIf;	
		
		// Writing data to the message
		ExchangeMobileOverridable.WriteData(XMLWriter, Data);
        
    EndDo;
    
	WriteMessage.EndWrite();
    
	Return New ValueStorage(XMLWriter.Close(), New Deflation(9));
    
EndFunction

// Writes data from ExchangeNode. 
//
// Parameters:
//  ExchangeNode - 'Mobile' exchange plan node where the data is received.
//  ExchangeData - exchange batch received from ExchangeNode and placed into
//  ValueStorage.
//
Procedure ReceiveExchangeBatch(ExchangeNode, ExchangeData) Export
    
	XMLReader = New XMLReader;
	XMLReader.SetString(ExchangeData.Get());
    MessageReader = ExchangePlans.CreateMessageReader();
	MessageReader.BeginRead(XMLReader);
    ExchangePlans.DeleteChangeRecords(MessageReader.Sender,MessageReader.ReceivedNo);

    BeginTransaction();
    While CanReadXML(XMLReader) Do
        
		Data = ExchangeMobileOverridable.ReadData(XMLReader);
        
		If Not Data = Undefined Then
			
            Data.DataExchange.Sender = MessageReader.Sender;
            Data.DataExchange.Load = True;
            
            Data.Write();
        
        EndIf;
        
    EndDo;
    CommitTransaction();
    
    MessageReader.EndRead();
    XMLReader.Close();
    
EndProcedure
