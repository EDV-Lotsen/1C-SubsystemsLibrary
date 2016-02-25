////////////////////////////////////////////////////////////////////////////////
// Address classifier SaaS subsystem.
//  
////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations.SuppliedData") Then
		ServerHandlers[
			"StandardSubsystems.SaaSOperations.SuppliedData\OnDefineSuppliedDataHandlers"
		].Add("AddressClassifierInternalSaaS");
	EndIf;
	
	If CommonUse.SubsystemExists("CloudTechnology.DataImportExport") Then
		ServerHandlers[
			"CloudTechnology.DataImportExport\OnFillExcludedFromImportExportTypes"
		].Add("AddressClassifierInternalSaaS");
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SUPPLIED DATA GETTING HANDLERS

// Registers supplied data handlers, both daily and total.
//
Procedure RegisterSuppliedDataHandlers(Val Handlers) Export
	
	Handler = Handlers.Add();
	Handler.DataKind = "AC";
	Handler.HandlerCode = "AC";
	Handler.Handler = AddressClassifierInternalSaaS;
	
EndProcedure

// The procedure is called when a new data notification is received.
// In the procedure body, check whether the application requires this data. 
// If it does, set the Import flag.
// 
// Parameters:
//   Descriptor   - XDTODataObject descriptor.
//   Import       - Boolean - return value.
//
Procedure NewDataAvailable(Val Descriptor, Import) Export
	
	If Descriptor.DataType = "AC" Then
		Import = CheckForNewData(Descriptor);
	EndIf;
	
EndProcedure

// The procedure is called after calling NewDataAvailable; it parses the data.
//
// Parameters:
//   Descriptor   - XDTODataObject descriptor.
//   PathToFile   - String or Undefined. Full name of the extracted file. The file is 
//                  automatically deleted once the procedure is executed. If the file
//                  is not specified in Service Manager, the parameter value is Undefined.
//
Procedure ProcessNewData(Val Descriptor, Val PathToFile) Export
	
	If Descriptor.DataType = "AC" Then
		ProcessAddressClassifier(Descriptor, PathToFile);
	EndIf;
	
EndProcedure

// The procedure is called when data processing is canceled due to an error.
//
Procedure DataProcessingCanceled(Val Descriptor) Export 
EndProcedure	

#EndRegion

#Region InternalProceduresAndFunctions

Function AddressClassifierDate(Val Descriptor)
	
 // Retrieves the Date value for the supplied data. 
 // Normally, it contains a string in YYYYMMDD format. 
 // If data is in a different format (presumably entered manually) or no data is 
 // retrieved, the address classifier import procedure is canceled.
	For Each Characteristic In Descriptor.Properties.Property Do
		If Characteristic.Code = "Date" Then
			Try
				Return Date(Characteristic.Value);
			Except
			EndTry;
			Break;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction

Function CheckForNewData(Val Descriptor)
	
	NewDataDate = AddressClassifierDate(Descriptor);
	
	If NewDataDate = Undefined Then 
		Return True;
	EndIf;
	
	StoredDataVersions = AddressClassifier.AddressObjectVersions();
	CurrentVersions = New Map;
	For Each ListItem In StoredDataVersions Do
		CurrentVersions.Insert(ListItem.Presentation, ListItem.Value);
	EndDo;
	
	ClassifierTable = InformationRegisters.AddressClassifier.RegionClassifier();
	For Each AddressObject In ClassifierTable Do
		CurrentVersion = CurrentVersions[ Format(AddressObject.RegionCode, "ND=2; NZ=; NLZ=") ];
		If Not ValueIsFilled(CurrentVersion) Or CurrentVersion < NewDataDate Then
			Return True;
		EndIf;
	EndDo;
	
	CurrentVersion = CurrentVersions["SO"];
	If Not ValueIsFilled(CurrentVersion) Or CurrentVersion < NewDataDate Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

Procedure ProcessAddressClassifier(Val Descriptor, Val PathToFile)
	Var AvailableVersions, ImportDataSource;
	
	PathToServerDirectory = CommonUseClientServer.AddFinalPathSeparator(GetTempFileName());
	Try
		ZIPReader = New ZipFileReader(PathToFile);
		ZIPReader.ExtractAll(PathToServerDirectory,
		ZIPRestoreFilePathsMode.DontRestore);
		ZIPReader.Close();
		
		VersionFile = New File(PathToServerDirectory + "versions.xml");
		If VersionFile.Exist() Then
			TextDocument = New TextDocument;
			TextDocument.Read(VersionFile.FullName);
			XMLText = TextDocument.GetText();
			
			AvailableVersions = AddressClassifier.GetAddressDataVersions(XMLText);
			
			ImportDataSource = 1;
		Else
			VersionOfAddressClassifierToImport = AddressClassifierDate(Descriptor);
			If VersionOfAddressClassifierToImport = Undefined Then
				AddressClassifierFile = New File(PathToServerDirectory + "CLASSF.DBF");
				VersionOfAddressClassifierToImport = AddressClassifierFile.GetModificationUniversalTime();
			EndIf;
			
			ImportDataSource = 0;
		EndIf;
		
		ClassifierTable = InformationRegisters.AddressClassifier.RegionClassifier();
		
		AddressObjects = New Array;
		For Each AddressObject In ClassifierTable Do
			AddressObjects.Add( Format(AddressObject.RegionCode, "ND=2; NZ=; NLZ=") );
		EndDo;
		AddressObjects.Add("SO");
		
		ImportParameters = New Structure;
		ImportParameters.Insert("AddressObjects",        AddressObjects);
		ImportParameters.Insert("PathToServerData",      PathToServerDirectory);
		ImportParameters.Insert("VersionOfAddressClassifierToImport", VersionOfAddressClassifierToImport);
		ImportParameters.Insert("ImportDataSource",      ImportDataSource);
		ImportParameters.Insert("AvailableVersions",     AvailableVersions);
		
		StorageAddress = PutToTempStorage(Undefined);
		AddressClassifier.ImportAddressDataFromClassifierFilesToInformationRegister(ImportParameters, StorageAddress);
		
		ReturnStructure = GetFromTempStorage(StorageAddress);
		If Not ReturnStructure.ExecutionStatus Then
			Raise ReturnStructure.UserMessage;
		EndIf;
		
	Except
		ErrorDescription = DetailErrorDescription(ErrorInfo());
		Try
			DeleteFiles(PathToServerDirectory);
		Except
		EndTry;
		Raise ErrorDescription;
	EndTry;
	
	Try
		DeleteFiles(PathToServerDirectory);
	Except
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SL event handlers

// Registers supplied data handlers.
//
// When a new shared data notification is received, NewDataAvailable
// procedures from modules registered with GetSuppliedDataHandlers are called.
// The descriptor passed to the procedure is XDTODataObject descriptor.
// 
// If NewDataAvailable sets Load to True, the data is imported, and the descriptor 
// and the path to the data file are passed to ProcessNewData() procedure. 
// The file is automatically deleted once the procedure is executed.
// If the file is not specified in Service Manager, the parameter value is Undefined.
//
// Parameters: 
//   Handlers - ValueTable - table for adding handlers. 
//       Columns:
//        DataKind    - String - code of the data kind processed by the handler.
//        HandlerCode - String(20) - used for recovery after a data processing error.
//        Handler, CommonModule - module that contains the following procedures:
//          NewDataAvailable(Descriptor, Import) Export
//          ProcessNewData(Descriptor, Import) Export
//          DataProcessingCanceled(Descriptor) Export
//
Procedure OnDefineSuppliedDataHandlers(Handlers) Export
	
	RegisterSuppliedDataHandlers(Handlers);
	
EndProcedure

// Fills the array of types excluded from data import and export.
//
// Parameters:
//  Types - Array(Types).
//
Procedure OnFillExcludedFromImportExportTypes(Types) Export
	
	Types.Add(Metadata.InformationRegisters.AddressAbbreviations);
	Types.Add(Metadata.InformationRegisters.AddressClassifier);
	
EndProcedure

#EndRegion
