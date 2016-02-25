#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Export internal procedures and functions.

// Imports data from the exchange message file.
//
// Parameters:
//  Cancel - Boolean - cancel flag. It is set to True if errors occur during the 
//           procedure execution.
// 
Procedure ExecuteDataImport(Cancel, Val ImportOnlyParameters) Export
	
	If Not IsDistributedInfobaseNode() Then
		
		// The exchange must follow conversion rules
		AddExchangeFinishEventLogMessage(Cancel,, DataExchangeKindError());
		Return;
	EndIf;
	
	ImportMetadata = ImportOnlyParameters
		And DataExchangeServer.IsSubordinateDIBNode()
		And (DataExchangeServerCall.RetryDataExchangeMessageImportBeforeStart()
			Or Not DataExchangeServerCall.DataExchangeMessageImportModeBeforeStart(
					"MessageReceivedFromCache"));
	
	XMLReader = New XMLReader;
	
	Try
		XMLReader.OpenFile(ExchangeMessageFileName());
	Except
		
		// Error opening the exchange message file
		AddExchangeFinishEventLogMessage(Cancel, ErrorDescription(), ErrorOpeningExchangeMessageFile());
		Return;
	EndTry;
	
	ReadExchangeMessageFile(Cancel, XMLReader, ImportOnlyParameters, ImportMetadata);
	
	XMLReader.Close();
EndProcedure

// Exports data to the exchange message file.
//
// Parameters:
//  Cancel - Boolean - cancel flag. It is set to True if errors occur during the 
//           procedure execution.
// 
Procedure ExecuteDataExport(Cancel) Export
	
	If Not IsDistributedInfobaseNode() Then
		
		// The exchange must follow conversion rules
		AddExchangeFinishEventLogMessage(Cancel,, DataExchangeKindError());
		Return;
	EndIf;
	
	XMLWriter = New XMLWriter;
	
	Try
		XMLWriter.OpenFile(ExchangeMessageFileName());
	Except
		
		// Error opening the exchange message file
		AddExchangeFinishEventLogMessage(Cancel, ErrorDescription(), ErrorOpeningExchangeMessageFile());
		Return;
	EndTry;
	
	WriteChangesToExchangeMessageFile(Cancel, XMLWriter);
	
	XMLWriter.Close();
	
EndProcedure

// Passes the string with the full exchange message file name for data import or 
// export to the ExchangeMessageFileNameField local variable.
// Usually, the exchange message file places in the operating system user temporary directory.
//
// Parameters:
//  FileName - String - full exchange message file name for the data import or export.
// 
Procedure SetExchangeMessageFileName(Val FileName) Export
	
	ExchangeMessageFileNameField = FileName;
	
EndProcedure

Procedure ReadExchangeMessageFile(Cancel, XMLReader, Val ImportOnlyParameters, Val ImportMetadata)
	
	MessageReader = ExchangePlans.CreateMessageReader();
	
	Try
		MessageReader.BeginRead(XMLReader, AllowedMessageNo.Greater);
	Except
		// The unknown exchange plan is specified.
		// The exchange plan does not contain the specified node.
		// The message number does not match the expected one.
		AddExchangeFinishEventLogMessage(Cancel, ErrorDescription(), ErrorStartRedingTheExchangeMessageFile());
		Return;
	EndTry;
	
	If ImportOnlyParameters Then
		
		If ImportMetadata Then
			
			Try
				
				SetPrivilegedMode(True);
				DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart(
					"ApplicationRunParameterImport", True);
				SetPrivilegedMode(False);
				
				// Receiving configuration changes, ignoring data changes
				ExchangePlans.ReadChanges(MessageReader, TransactionItemCount);
				
				// Reading priority data (metadata object IDs)
				ReadPriorityChangesFromExchangeMessage(MessageReader);
				
				// Pretending the message is still not received. Interrupting the data reading.
				MessageReader.CancelRead();
				
				SetPrivilegedMode(True);
				DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart(
					"ApplicationRunParameterImport", False);
				SetPrivilegedMode(False);
			Except
				SetPrivilegedMode(True);
				DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart(
					"ApplicationRunParameterImport", False);
				SetPrivilegedMode(False);
				
				MessageReader.CancelRead();
				AddExchangeFinishEventLogMessage(Cancel, ErrorDescription(), ErrorReadingExchangeMessageFile());
				Return;
			EndTry;
			
		Else
			
			Try
				
				// Skipping configuration changes and data changes in the exchange message
				MessageReader.XMLReader.Skip(); // <Changes>...</Changes>
				
				MessageReader.XMLReader.Read(); // </Changes>
				
				// Reading priority data (metadata object IDs)
				ReadPriorityChangesFromExchangeMessage(MessageReader);
				
				// Pretending the message is still not received. Interrupting the data reading.
				MessageReader.CancelRead();
			Except
				MessageReader.CancelRead();
				AddExchangeFinishEventLogMessage(Cancel, ErrorDescription(), ErrorReadingExchangeMessageFile());
				Return
			EndTry;
			
		EndIf;
		
	Else
		
		Try
			
			// Receiving configuration changes and data changes from the exchange message
			ExchangePlans.ReadChanges(MessageReader, TransactionItemCount);
			
			// Reading priority data (metadata object IDs)
			ReadPriorityChangesFromExchangeMessage(MessageReader);
			
			// The message is considered received
			MessageReader.EndRead();
		Except
			MessageReader.CancelRead();
			AddExchangeFinishEventLogMessage(Cancel, ErrorDescription(), ErrorReadingExchangeMessageFile());
			Return
		EndTry;
		
	EndIf;
	
EndProcedure

Procedure WriteChangesToExchangeMessageFile(Cancel, XMLWriter)
	
	WriteMessage = ExchangePlans.CreateMessageWriter();
	
	Try
		WriteMessage.BeginWrite(XMLWriter, InfobaseNode);
	Except
		AddExchangeFinishEventLogMessage(Cancel, ErrorDescription(), ErrorStartWritingTheExchangeMessageFile());
		Return;
	EndTry;
	
	Try
		
		DataExchangeServerCall.ClearPriorityExchangeData();
		
		// Writing configuration changes and data changes to the exchange message
		ExchangePlans.WriteChanges(WriteMessage, TransactionItemCount);
		
		// Writing priority data to the end of the exchange message
		WritePriorityChangesToExchangeMessage(WriteMessage);
		
		WriteMessage.EndWrite();
	Except
		WriteMessage.CancelWrite();
		AddExchangeFinishEventLogMessage(Cancel, ErrorDescription(), ErrorSavingExchangeMessageFile());
		Return;
	EndTry;
	
EndProcedure

// Writes priority data (such as metadata object IDs) to the exchange message.
//
Procedure WritePriorityChangesToExchangeMessage(Val WriteMessage)
	
	// Writing the <Parameters> element
	WriteMessage.XMLWriter.WriteStartElement("Parameters");
	
	If WriteMessage.Recipient <> ExchangePlans.MasterNode() Then
		
		// Exporting priority exchange data (predefined items)
		PriorityExchangeData = DataExchangeServerCall.PriorityExchangeData();
		
		If PriorityExchangeData.Count() > 0 Then
			
			ChangeSelection = DataExchangeServer.SelectChanges(
				WriteMessage.Recipient,
				WriteMessage.MessageNo,
				PriorityExchangeData);
			
			BeginTransaction();
			Try
				
				While ChangeSelection.Next() Do
					
					WriteXML(WriteMessage.XMLWriter, ChangeSelection.Get());
					
				EndDo;
				
				CommitTransaction();
			Except
				RollbackTransaction();
				Raise;
			EndTry;
			
		EndIf;
		
		If Not StandardSubsystemsCached.DisableMetadataObjectIDsCatalog() Then
			
			// Exporting the metadata object IDs catalog
			ChangeSelection = DataExchangeServer.SelectChanges(
				WriteMessage.Recipient,
				WriteMessage.MessageNo,
				Metadata.Catalogs["MetadataObjectIDs"]);
			
			BeginTransaction();
			Try
				
				While ChangeSelection.Next() Do
					
					WriteXML(WriteMessage.XMLWriter, ChangeSelection.Get());
					
				EndDo;
				
				CommitTransaction();
			Except
				RollbackTransaction();
				Raise;
			EndTry;
			
		EndIf;
		
	EndIf;
	
	WriteMessage.XMLWriter.WriteEndElement(); // Parameters
	
EndProcedure

// Reads priority data (such as metadata object IDs) from the exchange message.
//
Procedure ReadPriorityChangesFromExchangeMessage(Val MessageReader)
	
	If MessageReader.Sender = ExchangePlans.MasterNode() Then
		
		MessageReader.XMLReader.Read(); // <Parameters>
		
		BeginTransaction();
		Try
			
			DuplicatesOfPredefinedItems = "";
			Cancel = False;
			CancellationDetails = "";
			IDObjects = New Array;
			
			If NotUniqueRecordsFound("Catalog.MetadataObjectIDs") Then
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					NotUniqueRecordErrorTemplate(),
					NStr("en = 'The check performed prior to importing metadata object IDs
					           |found duplicate metadata object ID records in the catalog.'"));
			EndIf;
			
			While CanReadXML(MessageReader.XMLReader) Do
				
				Data = ReadXML(MessageReader.XMLReader);
				Data.DataExchange.Load = True;
				Data.DataExchange.Sender = MessageReader.Sender;
				Data.DataExchange.Recipients.AutoFill = False;
				
				If TypeOf(Data) = Type("CatalogObject.MetadataObjectIDs") Then
					IDObjects.Add(Data);
					Continue;
					
				ElsIf TypeOf(Data) <> Type("ObjectDeletion") Then // This is a predefined item
					
					If Not Data.Predefined Then
						Continue; // Only predefined items are processed
					EndIf;
					
				Else // Type("ObjectDeletion")
					
					// 1. ID references are deleted independently
					//    in each node using deletion marks and marked object deletion.
					// 2. Deletion of predefined items is not exported.
					Continue;
				EndIf;
				
				WritePredefinedDataRef(Data);
				AddPredefinedItemDuplicateDetails(Data, DuplicatesOfPredefinedItems, Cancel, CancellationDetails);
			EndDo;
			
			If Cancel Then
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Important changes are not imported.
					           |Duplicate records are found during the predefined item import.
					           |Cannot continue for the following reason:
					           |%1'"),
					CancellationDetails);
			EndIf;
			
			If ValueIsFilled(DuplicatesOfPredefinedItems) Then
				WriteLogEvent(
					NStr("en = 'Predefined items.Duplicate records are found.'",
						CommonUseClientServer.DefaultLanguageCode()),
					EventLogLevel.Error,
					,
					,
					StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = 'Duplicate records are found during the predefined item import.
						           |%1'"),
						DuplicatesOfPredefinedItems));
			EndIf;
			
			UpdatePredefinedItemsDeletion();
			
			Catalogs.MetadataObjectIDs.ImportDataToSubordinateNode(IDObjects);
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
		MessageReader.XMLReader.Read(); // </Parameters>
		
	Else
		
		// Skipping the application execution parameters
		MessageReader.XMLReader.Skip(); // <Parameters>...</Parameters>
		
		MessageReader.XMLReader.Read(); // </Parameters>
		
	EndIf;
	
EndProcedure

Procedure AddExchangeFinishEventLogMessage(Cancel, ErrorDescription = "", ContextErrorDescription = "")
	
	Cancel = True;
	
	Comment = "[ContextErrorDescription]: [ErrorDescription]";
	
	Comment = StrReplace(Comment, "[ContextErrorDescription]", ContextErrorDescription);
	Comment = StrReplace(Comment, "[ErrorDescription]", ErrorDescription);
	
	WriteLogEvent(EventLogMessageKey, EventLogLevel.Error,
		InfobaseNode.Metadata(), InfobaseNode, Comment);
	
EndProcedure

Function IsDistributedInfobaseNode()
	
	Return DataExchangeCached.IsDistributedInfobaseNode(InfobaseNode);
	
EndFunction

Procedure WritePredefinedDataRef(Data)
	
	ObjectMetadata = Metadata.FindByType(TypeOf(Data.Ref));
	If ObjectMetadata = Undefined Then
		Return;
	EndIf;
	
	ObjectManager = CommonUse.ObjectManagerByRef(Data.Ref);
	
	If Data.IsNew() Then
		If CommonUse.IsCatalog(ObjectMetadata)
		 Or CommonUse.IsChartOfCharacteristicTypes(ObjectMetadata) Then
			
			Object = ObjectManager.CreateItem();
			
		ElsIf CommonUse.IsChartOfAccounts(ObjectMetadata) Then
			Object = ObjectManager.CreateAccount();
			
		ElsIf CommonUse.IsChartOfCalculationTypes(ObjectMetadata) Then
			Object = ObjectManager.CreateCalculationType();
		EndIf;
	Else
		Object = Data.Ref.GetObject();
	EndIf;
	
	If Data.IsNew() Then
		Object.SetNewObjectRef(Data.GetNewObjectRef());
		Object.PredefinedDataName = Data.PredefinedDataName;
		InfobaseUpdate.WriteData(Object);
		
	ElsIf Object.PredefinedDataName <> Data.PredefinedDataName Then
		Object.PredefinedDataName = Data.PredefinedDataName;
		InfobaseUpdate.WriteData(Object);
	Else
		// If the predefined item exists, preliminary import is not required
	EndIf;
	
	Data = Object;
	
EndProcedure

Procedure AddPredefinedItemDuplicateDetails(WrittenObject, DuplicatesOfPredefinedItems, Cancel, CancellationDetails)
	
	ObjectMetadata = Metadata.FindByType(TypeOf(WrittenObject.Ref));
	If ObjectMetadata = Undefined Then
		Return;
	EndIf;
	
	Table = ObjectMetadata.FullName();
	PredefinedDataName = WrittenObject.PredefinedDataName;
	Ref = WrittenObject.Ref;
	
	Query = New Query;
	Query.SetParameter("PredefinedDataName", PredefinedDataName);
	Query.Text =
	"SELECT
	|	CurrentTable.Ref AS Ref,
	|	CurrentTable.PredefinedDataName AS PredefinedDataName
	|FROM
	|	&CurrentTable AS CurrentTable
	|WHERE
	|	CurrentTable.PredefinedDataName = &PredefinedDataName";
	
	Query.Text = StrReplace(Query.Text, "&CurrentTable", Table);
	Selection = Query.Execute().Select();
	
	DuplicateRefIDs = "";
	DuplicateCount = 0;
	FoundRefs = New Map;
	RefToImportFound = False;
	
	While Selection.Next() Do
		// Searching for duplicate records that are relevant to predefined items
		If FoundRefs.Get(Selection.Ref) = Undefined Then
			FoundRefs.Insert(Selection.Ref, 1);
		Else
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NotUniqueRecordErrorTemplate(),
				NStr("en = 'Duplicate records are found during the predefined item import.'"));
		EndIf;
		// Searching for duplicate predefined items
		If Ref = Selection.Ref And Not RefToImportFound Then
			RefToImportFound = True;
			Continue;
		EndIf;
		DuplicateCount = DuplicateCount + 1;
		If ValueIsFilled(DuplicateRefIDs) Then
			DuplicateRefIDs = DuplicateRefIDs + ",";
		EndIf;
		DuplicateRefIDs = DuplicateRefIDs
			+ String(Selection.Ref.UUID());
	EndDo;
	
	If DuplicateCount = 0 Then
		Return;
	EndIf;
		
	WriteToLog = True;
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.BaseFunctionality\NotUniquePredefinedItemFound");
	
	For Each Handler In EventHandlers Do
		Details = "";
		Handler.Module.NotUniquePredefinedItemFound(
			WrittenObject, WriteToLog, Cancel, CancellationDetails);
		
		If ValueIsFilled(Details) Then
			CancellationDetails = CancellationDetails + Chars.LF + TrimAll(Details) + Chars.LF;
		EndIf;
	EndDo;

	If WriteToLog Then
		If DuplicateCount = 1 Then
			Template = NStr("en = '(import reference: %1, duplicate reference: %2)'");
		Else
			Template = NStr("en = '(import reference: %1, duplicate references: %2)'");
		EndIf;
		DuplicatesOfPredefinedItems = DuplicatesOfPredefinedItems + Chars.LF
			+ Table + "." + PredefinedDataName + Chars.LF
			+ StringFunctionsClientServer.SubstituteParametersInString(
				Template,
				String(Ref.UUID()),
				DuplicateRefIDs)
			+ Chars.LF;
	EndIf;
	
EndProcedure

Function NotUniqueRecordsFound(Table)
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.MetadataObjectIDs AS MetadataObjectIDs
	|
	|GROUP BY
	|	MetadataObjectIDs.Ref
	|
	|HAVING
	|	COUNT(MetadataObjectIDs.Ref) > 1";
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

Function NotUniqueRecordErrorTemplate()
	Return
		NStr("en = 'Important changes are not imported.
		           |%1
		           |Infobase repair is required.
		           |1. Run Designer and then, on the Administration menu,
		           |   click ""Verify and repair..."".
		           |2. In the window that is opened:
		           |     - Select the ""Checking infobase logical integrity"" check box and clear all other check boxes.
		           |     - Select the ""Verify and repair"" option.
		           |     - Click the ""Execute"" button.
		           |3. Run 1C:Enterprise and start the data synchronization.'");
EndFunction

Procedure UpdatePredefinedItemsDeletion()
	
	SetPrivilegedMode(True);
	
	MetadataCollection = New Array;
	MetadataCollection.Add(Metadata.Catalogs);
	MetadataCollection.Add(Metadata.ChartsOfCharacteristicTypes);
	MetadataCollection.Add(Metadata.ChartsOfAccounts);
	MetadataCollection.Add(Metadata.ChartsOfCalculationTypes);
	
	For Each Collection In MetadataCollection Do
		For Each MetadataObject In Collection Do
			If MetadataObject = Metadata.Catalogs.MetadataObjectIDs Then
				Continue; // Metadata objects of this type are updated in the procedure that updates metadata object IDs
			EndIf;
			UpdatePredefinedItemDeletion(MetadataObject.FullName());
		EndDo;
	EndDo;
	
EndProcedure

Procedure UpdatePredefinedItemDeletion(Table)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CurrentTable.Ref AS Ref,
	|	CurrentTable.PredefinedDataName AS PredefinedDataName
	|FROM
	|	&CurrentTable AS CurrentTable
	|WHERE
	|	CurrentTable.Predefined = TRUE";
	
	Query.Text = StrReplace(Query.Text, "&CurrentTable", Table);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		If Left(Selection.PredefinedDataName, 1) = "#" Then
			
			Object = Selection.Ref.GetObject();
			Object.PredefinedDataName = "";
			Object.DeletionMark = True;
			
			InfobaseUpdate.WriteData(Object);
			
		EndIf;
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Local internal functions.

Function ExchangeMessageFileName()
	
	If Not ValueIsFilled(ExchangeMessageFileNameField) Then
		
		ExchangeMessageFileNameField = "";
		
	EndIf;
	
	Return ExchangeMessageFileNameField;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Execution context error details.

Function ErrorOpeningExchangeMessageFile()
	
	Return NStr("en = 'Error opening the exchange message file'", CommonUseClientServer.DefaultLanguageCode());
	
EndFunction

Function ErrorStartRedingTheExchangeMessageFile()
	
	Return NStr("en = 'Error at the beginning of reading the exchange message file'", CommonUseClientServer.DefaultLanguageCode());
	
EndFunction

Function ErrorStartWritingTheExchangeMessageFile()
	
	Return NStr("en = 'Error at the beginning of writing the exchange message file'", CommonUseClientServer.DefaultLanguageCode());
	
EndFunction

Function ErrorReadingExchangeMessageFile()
	
	Return NStr("en = 'Error reading the exchange message file'", CommonUseClientServer.DefaultLanguageCode());
	
EndFunction

Function ErrorSavingExchangeMessageFile()
	
	Return NStr("en = 'Error saving the exchange message file'");
	
EndFunction

Function DataExchangeKindError()
	
	Return NStr("en = 'The exchange must follow conversion rules'", CommonUseClientServer.DefaultLanguageCode());
	
EndFunction

#EndRegion

#EndIf
