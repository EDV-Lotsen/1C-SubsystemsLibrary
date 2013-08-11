////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	FillMode = (Parameters.CloseOnChoice = False);
	AttributeName = Parameters.AttributeName;
	
	If Parameters.ExternalConnectionParameters.ConnectionType = "ExternalConnection" Then
		
		ErrorMessageString = "";
		
		ExternalConnection = DataExchangeCached.EstablishExternalConnection(Parameters.ExternalConnectionParameters, ErrorMessageString);
		
		If ExternalConnection = Undefined Then
			CommonUseClientServer.MessageToUser(ErrorMessageString,,,, Cancel);
			Return;
		EndIf;
		
		MetadataObjectProperties = ExternalConnection.DataExchangeExternalConnection.MetadataObjectProperties(Parameters.CorrespondentInfoBaseTableFullName);
		
		If Parameters.ExternalConnectionParameters.CorrespondentVersion_2_0_1_6 Then
			
			CorrespondentInfoBaseTable = CommonUse.ValueFromXMLString(ExternalConnection.DataExchangeExternalConnection.GetTableObjects_2_0_1_6(Parameters.CorrespondentInfoBaseTableFullName));
			
		Else
			
			CorrespondentInfoBaseTable = ValueFromStringInternal(ExternalConnection.DataExchangeExternalConnection.GetTableObjects(Parameters.CorrespondentInfoBaseTableFullName));
			
		EndIf;
		
	ElsIf Parameters.ExternalConnectionParameters.ConnectionType = "WebService" Then
		
		ErrorMessageString = "";
		
		If Parameters.ExternalConnectionParameters.CorrespondentVersion_2_0_1_6 Then
			WSProxy = DataExchangeCached.GetWSProxy_2_0_1_6(Parameters.ExternalConnectionParameters, ErrorMessageString);
		Else
			WSProxy = DataExchangeCached.GetWSProxy(Parameters.ExternalConnectionParameters, ErrorMessageString);
		EndIf;
		
		If WSProxy = Undefined Then
			CommonUseClientServer.MessageToUser(ErrorMessageString,,,, Cancel);
			Return;
		EndIf;
		
		If Parameters.ExternalConnectionParameters.CorrespondentVersion_2_0_1_6 Then
			
			CorrespondentBaseData = XDTOSerializer.ReadXDTO(WSProxy.GetInfoBaseData(Parameters.CorrespondentInfoBaseTableFullName));
			
			MetadataObjectProperties = CorrespondentBaseData.MetadataObjectProperties;
			CorrespondentInfoBaseTable = CommonUse.ValueFromXMLString(CorrespondentBaseData.CorrespondentInfoBaseTable);
			
		Else
			
			CorrespondentBaseData = ValueFromStringInternal(WSProxy.GetInfoBaseData(Parameters.CorrespondentInfoBaseTableFullName));
			
			MetadataObjectProperties = ValueFromStringInternal(CorrespondentBaseData.MetadataObjectProperties);
			CorrespondentInfoBaseTable = ValueFromStringInternal(CorrespondentBaseData.CorrespondentInfoBaseTable);
			
		EndIf;
		
	EndIf;
	
	Title = MetadataObjectProperties.Synonym;
	
	Items.List.Representation = ?(MetadataObjectProperties.Hierarchical = True, TableRepresentation.HierarchicalList, TableRepresentation.List);
	
	TreeItemCollection = List.GetItems();
	TreeItemCollection.Clear();
	CommonUse.FillFormDataTreeItemCollection(TreeItemCollection, CorrespondentInfoBaseTable);
	
	// Determining the value tree cursor position 
	If Not IsBlankString(Parameters.ChoiceInitialValue) Then
		
		RowID = 0;
		
		CommonUseClientServer.GetTreeRowIDByFieldValue("ID", RowID, TreeItemCollection, Parameters.ChoiceInitialValue, False);
		
		Items.List.CurrentRow = RowID;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENT HANDLERS OF List TABLE 

&AtClient
Procedure ListChoice(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	ValueChoiceProcessing();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure ChooseValue(Command)
	
	ValueChoiceProcessing();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtClient
Procedure ValueChoiceProcessing()
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	Data = New Structure("Presentation, ID");
	
	FillPropertyValues(Data, CurrentData);
	
	Data.Insert("FillMode", FillMode);
	Data.Insert("AttributeName", AttributeName);
	
	NotifyChoice(Data);
	
EndProcedure
