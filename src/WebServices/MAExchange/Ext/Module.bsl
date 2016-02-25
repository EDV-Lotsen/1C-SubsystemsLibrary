// Exchange start handler.
// Checks whether required node has been added to the exchange plan and is initialized
// correctly.
//
// Parameters:
//  NodeCode         - node ID, is used as exchange plan node code.
//  MobileDeviceName - arbitrary, node presentation, is used as exchange plan node
//                     description.
//  SentNo           - number of the last sent batch, is intended for exchange recovery
//                     if the node is deleted.
//  ReceivedNo       - number of the last received batch, is intended for exchange
//                     recovery if the node is deleted.
//
Function StartExchange(NodeCode, MobileDeviceName, SentNo, ReceivedNo, Version)
    
    If Number(Version) <> 4 Then
        
        Raise(NStr("en='Update the mobile application.'"));
        
    EndIf;
        
    If Not AccessRight("Read", Metadata.ExchangePlans.Mobile) Then
        
        Raise(NStr("en=''") + Users.CurrentUser() + NStr("en='"" has insufficient rights to synchronize data with the 1C:Demo application.'"));
        
    EndIf;
    
	SetPrivilegedMode(True);
    
	ExchangeNode = ExchangePlans.Mobile.ThisNode().GetObject();
    If Not ValueIsFilled(ExchangeNode.Code) Then
        
    	ExchangeNode.Code="001";
    	ExchangeNode.Description="Main";
    	ExchangeNode.Write();
        
    EndIf;
	
    ExchangeNode = ExchangePlans.Mobile.FindByCode(NodeCode); 
    If ExchangeNode.IsEmpty() Then
		
        NewNode = ExchangePlans.mobile.CreateNode();
		
		BeginTransaction();
		
		Lock = New DataLock;
		LockItem = Lock.Add("Constant.NewExchangePlanNodeCode");
		LockItem.Mode = DataLockMode.Exclusive;
		Lock.Lock();

		NewNodeCode = Constants.NewExchangePlanNodeCode.Get();
		If NewNodeCode = 0 Then 
			NewNodeCode = 2;
		EndIf;	
		Constants.NewExchangePlanNodeCode.Set(NewNodeCode + 1);
		
		CommitTransaction();
		
		If StrLen(NewNodeCode) < 3 Then
			NewNode.Code = Format(NewNodeCode, "ND=3; NLZ=");
		Else
			NewNode.Code = NewNodeCode;
		EndIf;
        NewNode.Description = MobileDeviceName;
        NewNode.SentNo = SentNo;
        NewNode.ReceivedNo = ReceivedNo;
			
        NewNode.Write();
        ExchangeMobileOverridable.RecordDataChanges(NewNode.Ref);
        ExchangeNode = NewNode.Ref;
        
    Else
        
        If ExchangeNode.DeletionMark Or            
             ExchangeNode.Description <> MobileDeviceName Then
             
            Node = ExchangeNode.GetObject();
            Node.DeletionMark = False;
            Node.Description = MobileDeviceName;
            Node.Write();
            
        EndIf;
        
        If ExchangeNode.SentNo <> SentNo Or
             ExchangeNode.ReceivedNo <> ReceivedNo Then
             
            Node = ExchangeNode.GetObject();
            Node.SentNo = SentNo;
            Node.ReceivedNo = ReceivedNo;
            Node.Write();
            ExchangeMobileOverridable.RecordDataChanges(ExchangeNode);
            
        EndIf;
        
	EndIf;
    Return ExchangeNode.Code;
EndFunction

// Data receiving handler.
// Receives a batch with changes intended for the current node.
//
// Parameters:
//  NodeCode - code of the node that sends data.
//
// Returns:
//  ValueStorage where the batch is placed.
//
Function GetData(NodeCode)
    
    ExchangeNode = ExchangePlans.Mobile.FindByCode(NodeCode); 
    
    If ExchangeNode.IsEmpty() Then
        Raise(NStr("en='Unknown device: '") + NodeCode);
    EndIf;
    ExchangeMobileOverridable.GenerateRequestedReports(ExchangeNode);
    Return ExchangeMobileGeneral.GenerateExchangeBatch(ExchangeNode);
    
EndFunction

// Data writing handler.
// Writes batch with changes received from the specified node.
//
// Parameters:
//  NodeCode              - code of the node that sends data.
//  MobileApplicationData - ValueStorage where the batch is placed.
//

Function WriteData(NodeCode, MobileApplicationData)

    ExchangeNode = ExchangePlans.Mobile.FindByCode(NodeCode); 
    
    If ExchangeNode.IsEmpty() Then
        Raise(NStr("en='Unknown device: '") + NodeCode);
	EndIf;
    ExchangeMobileGeneral.ReceiveExchangeBatch(ExchangeNode, MobileApplicationData);
    
EndFunction

// Retrieves the report remotely.
//
// Parameters:
//  Settings - structure serialized into XDTO - report settings. 
//
// Returns:
//  SpreadsheetDocument - generated report serialized into XDTO. 
//
Function GetReport(Settings, DetailsInformationString)
    
    DetailsInformation = Undefined;
    SpreadsheetDocument = ExchangeMobileOverridable.GenerateReport(Settings, DetailsInformation);
    DetailsInformationString = XDTOSerializer.WriteXDTO(DetailsInformation);
    Return XDTOSerializer.WriteXDTO(SpreadsheetDocument);
    
EndFunction
