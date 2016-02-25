////////////////////////////////////////////////////////////////////////////////
// Subscription to notification about receipt of new supplied data
//  
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

// Generates the list of handlers that are supported by the current subsystem.
// 
// Parameters:
//  Handlers - ValueTable - see the field structure in MessageExchange.NewMessageHandlerTable
// 
Procedure GetMessageChannelHandlers(Val Handlers) Export
	
	AddMessageChannelHandler("SuppliedData\Update", SuppliedDataMessagesMessageHandler, Handlers);
	
EndProcedure

// Processes a message body according to the current message channel algorithm.
//
// Parameters:
//  MessageChannel - String - ID of the message channel that delivered the message.
//  Body - Arbitrary - message body to be processed, which was received over the channel.
//  From - ExchangePlanRef.MessageExchange - endpoint that is the message sender.
//
Procedure ProcessMessage(Val MessageChannel, Val Body, Val From) Export
	
	Try
		Descriptor = DeserializeXDTO(Body);
		
		If MessageChannel = "SuppliedData\Update" Then
			
			HandleNewDescriptor(Descriptor);
			
		EndIf;
	Except
		WriteLogEvent(NStr("en = 'Supplied data.Message processing error'", 
			CommonUseClientServer.DefaultLanguageCode()), 
			EventLogLevel.Error, ,
			, SuppliedData.GetDataDescription(Descriptor) + Chars.LF + DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

// Processes new data. Is called from ProcessMessage and from 
// SuppliedData.ImportAndProcessData
//
// Parameters
//  Descriptor - XDTODataObject Descriptor
Procedure HandleNewDescriptor(Val Descriptor) Export
	
	Import = False;
	RecordSet = InformationRegisters.RequireProcessingSuppliedData.CreateRecordSet();
	RecordSet.Filter.FileID.Set(Descriptor.FileGUID);
	
	For Each Handler In GetHandlers(Descriptor.DataType) Do
		
		ImportHandler = False;
		
		Handler.Handler.NewDataAvailable(Descriptor, ImportHandler);
		
		If ImportHandler Then
			RawData = RecordSet.Add();
			RawData.FileID = Descriptor.FileGUID;
			RawData.HandlerCode = Handler.HandlerCode;
			Import = True;
		EndIf;
		
	EndDo; 
	
	If Import Then
		SetPrivilegedMode(True);
		RecordSet.Write();
		SetPrivilegedMode(False);
		
		ScheduleDataImport(Descriptor);
	EndIf;
	
	WriteLogEvent(NStr("en = 'Supplied data.New data is available'", 
		CommonUseClientServer.DefaultLanguageCode()), 
		EventLogLevel.Information, ,
		, ?(Import, NStr("en = 'Import job is added to the queue.'"), NStr("en = 'Data import is not required.'"))
		+ Chars.LF + SuppliedData.GetDataDescription(Descriptor));

EndProcedure

// Schedule data import correspondent to the descriptor
//
// Parameters
//   Descriptor - XDTODataObject Descriptor.
//
Procedure ScheduleDataImport(Val Descriptor) Export
	Var XMLDescriptor, MethodParameters;
	
	If Descriptor.RecommendedUpdateDate = Undefined Then
		Descriptor.RecommendedUpdateDate = CurrentUniversalDate();
	EndIf;
	
	XMLDescriptor = SerializeXDTO(Descriptor);
	
	MethodParameters = New Array;
	MethodParameters.Add(XMLDescriptor);

	JobParameters = New Structure;
	JobParameters.Insert("MethodName", "SuppliedDataMessagesMessageHandler.ImportData");
	JobParameters.Insert("Parameters", MethodParameters);
	JobParameters.Insert("DataArea", -1);
	JobParameters.Insert("ScheduledStartTime", ToLocalTime(Descriptor.RecommendedUpdateDate));
	JobParameters.Insert("RestartCountOnFailure", 3);
	
	SetPrivilegedMode(True);
	JobQueue.AddJob(JobParameters);

EndProcedure

// Import data correspondent to the descriptor
//
// Parameters
//   Descriptor - XDTODataObject Descriptor.
//
Procedure ImportData(Val XMLDescriptor) Export
	Var Descriptor, ExportFileName;
	
	Try
		Descriptor = DeserializeXDTO(XMLDescriptor);
	Except
		WriteLogEvent(NStr("en = 'Supplied data.Work with XML error'", 
			CommonUseClientServer.DefaultLanguageCode()), 
			EventLogLevel.Error, ,
			, DetailErrorDescription(ErrorInfo())
			+ XMLDescriptor);
		Return;
	EndTry;

	WriteLogEvent(NStr("en = 'Supplied data.Data import'", 
		CommonUseClientServer.DefaultLanguageCode()), 
		EventLogLevel.Information, ,
		, NStr("en = 'Import started'") + Chars.LF + SuppliedData.GetDataDescription(Descriptor));

	If ValueIsFilled(Descriptor.FileGUID) Then
		ExportFileName = GetFileFromStorage(Descriptor);
	
		If ExportFileName = Undefined Then
			WriteLogEvent(NStr("en = 'Supplied data.Data import'", 
				CommonUseClientServer.DefaultLanguageCode()), 
				EventLogLevel.Information, ,
				, NStr("en = 'The file can not be imported'") + Chars.LF 
				+ SuppliedData.GetDataDescription(Descriptor));
			Return;
		EndIf;
	EndIf;
	
	WriteLogEvent(NStr("en = 'Supplied data.Data import'", 
		CommonUseClientServer.DefaultLanguageCode()), 
		EventLogLevel.Note, ,
		, NStr("en = 'Load executed successfully'") + Chars.LF + SuppliedData.GetDataDescription(Descriptor));

	// InformationRegister.RequireProcessingSuppliedData is used in that case 
	// if the loop was interrupted by rebooting the server.
	// In this situation the only way to keep information about emission handlers 
	// (if there are more than 1) - quickly record them in the specified register.
	RawDataSet = InformationRegisters.RequireProcessingSuppliedData.CreateRecordSet();
	RawDataSet.Filter.FileID.Set(Descriptor.FileGUID);
	RawDataSet.Read();
	HasErrors = False;
	
	For Each Handler In GetHandlers(Descriptor.DataType) Do
		RecordFound = False;
		For Each RawDataRecord In RawDataSet Do
			If RawDataRecord.HandlerCode = Handler.HandlerCode Then
				RecordFound = True;
				Break;
			EndIf;
		EndDo; 
		
		If Not RecordFound Then 
			Continue;
		EndIf;
			
		Try
			Handler.Handler.ProcessNewData(Descriptor, ExportFileName);
			RawDataSet.Delete(RawDataRecord);
			RawDataSet.Write();			
		Except
			WriteLogEvent(NStr("en = 'Supplied data.Processing error'", 
				CommonUseClientServer.DefaultLanguageCode()), 
				EventLogLevel.Error, ,
				, DetailErrorDescription(ErrorInfo())
				+ Chars.LF + SuppliedData.GetDataDescription(Descriptor)
				+ Chars.LF + StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Handler code: %1'"), Handler.HandlerCode));
				
			RawDataRecord.AttemptCount = RawDataRecord.AttemptCount + 1;
			If RawDataRecord.AttemptCount > 3 Then
				NotifyAboutProcessingCancellation(Handler, Descriptor);
				RawDataSet.Delete(RawDataRecord);
			Else
				HasErrors = True;
			EndIf;
			RawDataSet.Write();			
			
		EndTry;
	EndDo; 
	
	Try
		DeleteFiles(ExportFileName);
	Except
	EndTry;
	
	If HasErrors Then
		//Download delayed for 5 minutes				
		Descriptor.RecommendedUpdateDate = CurrentUniversalDate() + 5 * 60;
		ScheduleDataImport(Descriptor);
		WriteLogEvent(NStr("en = 'Supplied data.Processing error'", 
			CommonUseClientServer.DefaultLanguageCode()), 
			EventLogLevel.Information, , ,
			NStr("en = 'Data processor will be run due to an error handler.'")
			 + Chars.LF + SuppliedData.GetDataDescription(Descriptor));
	Else
		RawDataSet.Clear();
		RawDataSet.Write();
		
		WriteLogEvent(NStr("en = 'Supplied data.Data import'", 
			CommonUseClientServer.DefaultLanguageCode()), 
			EventLogLevel.Information, ,
			, NStr("en = 'New data is processed'") + Chars.LF + 
SuppliedData.GetDataDescription(Descriptor));

	EndIf;
	
EndProcedure

Procedure DeleteDataAboutNotProcessedData(Val Descriptor)
	
	RawDataSet = InformationRegisters.RequireProcessingSuppliedData.CreateRecordSet();
	RawDataSet.Filter.FileID.Set(Descriptor.FileGUID);
	RawDataSet.Read();
	
	For Each Handler In GetHandlers(Descriptor.DataType) Do
		RecordFound = False;
		
		For Each RawDataRecord In RawDataSet Do
			If RawDataRecord.HandlerCode = Handler.HandlerCode Then
				RecordFound = True;
				Break;
			EndIf;
		EndDo; 
		
		If Not RecordFound Then 
			Continue;
		EndIf;
			
		NotifyAboutProcessingCancellation(Handler, Descriptor);
		
	EndDo; 
	RawDataSet.Clear();
	RawDataSet.Write();
	
EndProcedure

Procedure NotifyAboutProcessingCancellation(Val Handler, Val Descriptor)
	
	Try
		Handler.Handler.DataProcessingCanceled(Descriptor);
		WriteLogEvent(NStr("en = 'Supplied data.Processing cancel'", 
			CommonUseClientServer.DefaultLanguageCode()), 
			EventLogLevel.Information, ,
			, SuppliedData.GetDataDescription(Descriptor)
			+ Chars.LF + StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Handler code: %1'"), Handler.HandlerCode));
	
	Except
		WriteLogEvent(NStr("en = 'Supplied data.Processing cancel'", 
			CommonUseClientServer.DefaultLanguageCode()), 
			EventLogLevel.Error, ,
			, DetailErrorDescription(ErrorInfo())
			+ Chars.LF + SuppliedData.GetDataDescription(Descriptor)
			+ Chars.LF + StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Handler code: %1'"), Handler.HandlerCode));
	EndTry;

EndProcedure

Function GetFileFromStorage(Val Descriptor)
	
	Try
		ExportFileName = SaaSOperations.GetFileFromServiceManagerStorage(Descriptor.FileGUID);
	Except
		WriteLogEvent(NStr("en = 'Supplied data.Storage error'", 
			CommonUseClientServer.DefaultLanguageCode()), 
			EventLogLevel.Error, ,
			, DetailErrorDescription(ErrorInfo())
			+ Chars.LF + SuppliedData.GetDataDescription(Descriptor));
				
		//Import is deferred for one hour				
		Descriptor.RecommendedUpdateDate = Descriptor.RecommendedUpdateDate + 60 * 60;
		ScheduleDataImport(Descriptor);
		Return Undefined;
	EndTry;
	
	// If the file was replaced or deleted between function restarts - 
	// delete the old import plan
	If ExportFileName = Undefined Then
		DeleteDataAboutNotProcessedData(Descriptor);
	EndIf;
	
	Return ExportFileName;

EndFunction

Function GetHandlers(Val DataKind)
	
	Handlers = New ValueTable;
	Handlers.Columns.Add("DataKind");
	Handlers.Columns.Add("Handler");
	Handlers.Columns.Add("HandlerCode");
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.SaaSOperations.SuppliedData\OnDefineSuppliedDataHandlers");
	
	For Each Handler In EventHandlers Do
		Handler.Module.OnDefineSuppliedDataHandlers(Handlers);
	EndDo;
	
	SuppliedDataOverridable.GetSuppliedDataHandlers(Handlers);
	
	Return Handlers.Copy(New Structure("DataKind", DataKind), "Handler, HandlerCode");
	
EndFunction	

Function SerializeXDTO(Val XDTODataObject)
	Write = New XMLWriter;
	Write.SetString();
	XDTOFactory.WriteXML(Write, XDTODataObject, , , , XMLTypeAssignment.Explicit);
	Return Write.Close();
EndFunction

Function DeserializeXDTO(Val XMLLine)
	Read = New XMLReader;
	Read.SetString(XMLLine);
	XDTODataObject = XDTOFactory.ReadXML(Read);
	Read.Close();
	Return XDTODataObject;
EndFunction

// AUXILIARY PROCEDURES AND FUNCTIONS

Procedure AddMessageChannelHandler(Val Channel, Val ChannelHandler, Val Handlers)
	
	Handler = Handlers.Add();
	Handler.Channel = Channel;
	Handler.Handler = ChannelHandler;
	
EndProcedure

#EndRegion
