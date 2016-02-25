
// Checks whether the data must be transferred to the current node.
//
// Parameters:
// Data - object, record set,... to be checked.
// ExchangeNode - exchange plan node.
//
// Returns:
// Boolean. True if the data must be transferred, otherwise is False.
//
Function DataTransferRequired(Data, ExchangeNode) Export
	
	Transfer = True;
    
    If TypeOf(Data) = Type("DocumentObject.SalesOrder") Then
		
		// Check whether the current user is the author of the data 
		If Data.Author <> Users.CurrentUser() Then
			Transfer = False;
        EndIf;	
        
    EndIf;
    
    If TypeOf(Data) = Type("InformationRegisterRecordSet.MobileReports") Then
        
        // Check whether the data is intended for the current recipient 
        If Data.Filter.Recipient.Value <> ExchangeNode.Code Then
        	Transfer = False;
        EndIf;	
        
	EndIf;
	
	Return Transfer;
	
EndFunction

// Writes data in the XML format.
// Analyzes the passed data object and writes it in the XML format.
//
// Parameters:
//  XMLWriter - object that writes XML data.
//  Data      - data to be written in the XML format.
//
Procedure WriteData(XMLWriter, Data) Export

// In the current demo all data is written using the standard method
WriteXML(XMLWriter, Data);
	
EndProcedure

// Reads data received in the XML format.
// Analyzes the passed XMLReader object and reads data.
//
// Parameters:
// XMLReader - object that reads XML data.
//
// Returns:
// Data - value read from the XMLReader object.
//
Function ReadData(XMLReader) Export
	
// Attempting to read the value using the standard method.
	Data = ReadXML(XMLReader);
    
    If TypeOf(Data) = Type("DocumentObject.SalesOrder") Then
        
        // The user is not always determined unambiguously in a mobile application
        // but during synchronization the user is known.
        If Data.Author.IsEmpty() Then
            Data.Author = Users.CurrentUser();
        EndIf;	
        AuthorObject = Data.Author.GetObject();
        If AuthorObject = Undefined Then
            Data.Author = Users.CurrentUser();
        EndIf;	
        
    EndIf;	
    
    Return Data;
    
EndFunction


// Registers changes of all data included in the exchange plan content.
//
// Parameters:
//  ExchangeNode - exchange plan node for which changes are registered.
//
Procedure RecordDataChanges(ExchangeNode) Export

	ExchangePlanContent = ExchangeNode.Metadata().Content;
    For Each ExchangePlanContentItem In ExchangePlanContent Do
        
        ExchangePlans.RecordChanges(ExchangeNode,ExchangePlanContentItem.Metadata);
        
	EndDo;

EndProcedure

// Generates the report.
// Is used to generate the report remotely from the mobile application. 
//
// Parameters:
//  SettingsRow        - settings of the report being generated.
//  DetailsInformation - details information.
//
// Returns:
//  Generated spreadsheet document.
//
Function GenerateReport(SettingsRow, DetailsInformation) Export
    
    Settings = Undefined;
    If SettingsRow <> "" Then
        
        XMLReader = New XMLReader;
        XMLReader.SetString(SettingsRow);
        Settings = XDTOSerializer.ReadXML(XMLReader, Type("Structure"));
        
    Else
        Settings = New Structure;
        
    EndIf;
    
    Report = Reports.WarehouseStockBalance.Create();
    
    OutputParameters = Report.SettingsComposer.Settings.OutputParameters;
    OutputParameters.SetParameterValue("HorizontalOverallPlacement", DataCompositionTotalPlacement.Begin);
    OutputParameters.SetParameterValue("VerticalOverallPlacement", DataCompositionTotalPlacement.Begin);
    OutputParameters.SetParameterValue("TitleOutput", DataCompositionTextOutputType.DontOutput);
    OutputParameters.SetParameterValue("DataParametersOutput", DataCompositionTextOutputType.DontOutput);
    OutputParameters.SetParameterValue("FilterOutput", DataCompositionTextOutputType.DontOutput);
    
    // Simplifying the implementation. The following settings can be found
    // but it is known that in the WarehouseStockBalance report
    // Product is the second setting, 
    // Warehouse is the third setting.
    Item = Report.SettingsComposer.UserSettings.Items[1];
    Product = Undefined;
    Settings.Property("Product", Product);
    If Product <> Undefined 
        And Product <> Catalogs.Products.EmptyRef() Then
        
        Item.Use = True;
        Item.RightValue = Product;
        If Product.IsFolder Then
            
            Item.ComparisonType = DataCompositionComparisonType.InListByHierarchy;
            
        Else
            
            Item.ComparisonType = DataCompositionComparisonType.Equal;
            
        EndIf;
        
    Else
        Item.Use = False;
        
    EndIf;
 
	If GetFunctionalOption("AccountingByWarehouses") Then
	   
		Warehouse = Undefined;
		Settings.Property("Warehouse", Warehouse);
		Item = Report.SettingsComposer.UserSettings.Items[2];
		If Warehouse <> Undefined 
			And Warehouse <> Catalogs.Warehouses.EmptyRef() Then
 
				Item.Use = True;
				Item.RightValue = Warehouse;
 
		Else
        
			Item.Use = False;
 
		EndIf;
 
	EndIf;
 
    SpreadsheetDocument = New SpreadsheetDocument();
	DetailsData = Undefined;
    Report.ComposeResult(SpreadsheetDocument, DetailsData);
	DetailsInformation = New Map;
	For Each Item In DetailsData.Items Do 
		If TypeOf(Item) = Type("DataCompositionFieldDetailsItem") Then
	        Fields = Item.GetFields();
	        If Fields.Count() > 0 Then
				DetailsInformation.Insert(Item.ID, Fields[0].Value); 
	        EndIf;
	    EndIf;
    EndDo;
    Return SpreadsheetDocument;
    
EndFunction

// Generates requested from the mobile application reports.
//
// Parameters:
//  ExchangeNode - exchange plan node for which the reports are generated.
//
Procedure GenerateRequestedReports(ExchangeNode) Export
    
    RecordSet = InformationRegisters.MobileReports.CreateRecordSet();
    RecordSet.Filter.Kind.Set(Enums.MobileReportKinds.WarehouseStockBalance);
    RecordSet.Filter.Recipient.Set(ExchangeNode.Code);
    RecordSet.Read();
    
    // The set with the specified filters can contain one record maximum
    If RecordSet.Count() > 0 And RecordSet[0].UpdateOnExchange = True Then
        
        DetailsInformation = Undefined;
        SpreadsheetDocument = GenerateReport(RecordSet[0].Settings, DetailsInformation);
        RecordSet[0].Content = New ValueStorage(SpreadsheetDocument);
        RecordSet[0].Kind = Enums.MobileReportKinds.WarehouseStockBalance;
        RecordSet[0].Recipient = ExchangeNode.Code;
	    XMLWriter = New XMLWriter;
	    XMLWriter.SetString();
        XDTOSerializer.WriteXML(XMLWriter, DetailsInformation);
        RecordSet[0].DetailsInformation = XMLWriter.Close();
        RecordSet.Write();
        
    EndIf;
    
EndProcedure
