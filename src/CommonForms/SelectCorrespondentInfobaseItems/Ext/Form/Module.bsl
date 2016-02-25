
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
  // Skipping the initialization to guarantee that the form 
  // will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	Parameters.Property("ChoiceFoldersAndItems", ChoiceFoldersAndItems);
	
	PickMode = (Parameters.CloseOnChoice = False);
	AttributeName = Parameters.AttributeName;
	
	If Parameters.ExternalConnectionParameters.JoinType = "ExternalConnection" Then
		
		Connection = DataExchangeCached.EstablishExternalConnectionWithInfobase(Parameters.ExternalConnectionParameters);
		ErrorMessageString = Connection.DetailedErrorDetails;
		ExternalConnection = Connection.Connection;
		
		If ExternalConnection = Undefined Then
			CommonUseClientServer.MessageToUser(ErrorMessageString,,,, Cancel);
			Return;
		EndIf;
		
		MetadataObjectProperties = ExternalConnection.DataExchangeExternalConnection.MetadataObjectProperties(Parameters.CorrespondentInfobaseTableFullName);
		
		If Parameters.ExternalConnectionParameters.CorrespondentVersion_2_1_1_7
			Or Parameters.ExternalConnectionParameters.CorrespondentVersion_2_0_1_6 Then
			
			CorrespondentInfobaseTable = CommonUse.ValueFromXMLString(ExternalConnection.DataExchangeExternalConnection.GetTableObjects_2_0_1_6(Parameters.CorrespondentInfobaseTableFullName));
			
		Else
			
			CorrespondentInfobaseTable = ValueFromStringInternal(ExternalConnection.DataExchangeExternalConnection.GetTableObjects(Parameters.CorrespondentInfobaseTableFullName));
			
		EndIf;
		
	ElsIf Parameters.ExternalConnectionParameters.JoinType = "WebService" Then
		
		ErrorMessageString = "";
		
		If Parameters.ExternalConnectionParameters.CorrespondentVersion_2_1_1_7 Then
			
			WSProxy = DataExchangeServer.GetWSProxy_2_1_1_7(Parameters.ExternalConnectionParameters, ErrorMessageString);
			
		ElsIf Parameters.ExternalConnectionParameters.CorrespondentVersion_2_0_1_6 Then
			
			WSProxy = DataExchangeServer.GetWSProxy_2_0_1_6(Parameters.ExternalConnectionParameters, ErrorMessageString);
			
		Else
			
			WSProxy = DataExchangeServer.GetWSProxy(Parameters.ExternalConnectionParameters, ErrorMessageString);
			
		EndIf;
		
		If WSProxy = Undefined Then
			CommonUseClientServer.MessageToUser(ErrorMessageString,,,, Cancel);
			Return;
		EndIf;
		
		If Parameters.ExternalConnectionParameters.CorrespondentVersion_2_1_1_7
			Or Parameters.ExternalConnectionParameters.CorrespondentVersion_2_0_1_6 Then
			
			CorrespondentBaseData = XDTOSerializer.ReadXDTO(WSProxy.GetInfobaseData(Parameters.CorrespondentInfobaseTableFullName));
			
			MetadataObjectProperties = CorrespondentBaseData.MetadataObjectProperties;
			CorrespondentInfobaseTable = CommonUse.ValueFromXMLString(CorrespondentBaseData.CorrespondentInfobaseTable);
			
		Else
			
			CorrespondentBaseData = ValueFromStringInternal(WSProxy.GetInfobaseData(Parameters.CorrespondentInfobaseTableFullName));
			
			MetadataObjectProperties = ValueFromStringInternal(CorrespondentBaseData.MetadataObjectProperties);
			CorrespondentInfobaseTable = ValueFromStringInternal(CorrespondentBaseData.CorrespondentInfobaseTable);
			
		EndIf;
		
	ElsIf Parameters.ExternalConnectionParameters.JoinType = "TempStorage" Then
		
		CorrespondentBaseData = GetFromTempStorage(
			Parameters.ExternalConnectionParameters.TempStorageAddress
		).Get().Get(Parameters.CorrespondentInfobaseTableFullName);
		
		MetadataObjectProperties = CorrespondentBaseData.MetadataObjectProperties;
		CorrespondentInfobaseTable = CommonUse.ValueFromXMLString(CorrespondentBaseData.CorrespondentInfobaseTable);
		
	EndIf;
	
	UpdateItemIconIndexes(CorrespondentInfobaseTable);
	
	Title = MetadataObjectProperties.Synonym;
	
	Items.List.Representation = ?(MetadataObjectProperties.Hierarchical = True, TableRepresentation.HierarchicalList, TableRepresentation.List);
	
	TreeItemCollection = List.GetItems();
	TreeItemCollection.Clear();
	CommonUse.FillFormDataTreeItemCollection(TreeItemCollection, CorrespondentInfobaseTable);
	
	// Specifying the value tree cursor position
	If Not IsBlankString(Parameters.InitialSelectionValue) Then
		
		RowID = 0;
		
		CommonUseClientServer.GetTreeRowIDByFieldValue("ID", RowID, TreeItemCollection, Parameters.InitialSelectionValue, False);
		
		Items.List.CurrentRow = RowID;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ListFormTableItemEventHandlers

&AtClient
Procedure ListChoice(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	ValueChoiceProcessing();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ChooseValue(Command)
	
	ValueChoiceProcessing();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure ValueChoiceProcessing()
	CurrentData = Items.List.CurrentData;
	
	If CurrentData = Undefined Then 
		Return
	EndIf;
	
	// Obtaining group mark indirectly by the following values:
	//     0 - group not marked for deletion.
	//     1 - group marked for deletion.
	
	IsFolder = CurrentData.PictureIndex = 0 Or CurrentData.PictureIndex=1;
	If (IsFolder And ChoiceFoldersAndItems = FoldersAndItems.Items) 
		Or (Not IsFolder And ChoiceFoldersAndItems = FoldersAndItems.Folders)
	Then
		Return;
	EndIf;
	
	Data = New Structure("Presentation, ID");
	FillPropertyValues(Data, CurrentData);
	
	Data.Insert("PickMode",      PickMode);
	Data.Insert("AttributeName", AttributeName);
	
	NotifyChoice(Data);
EndProcedure

// This procedure ensures backward compatibility.
//
&AtServer
Procedure UpdateItemIconIndexes(CorrespondentInfobaseTable)
	
	For Index = -3 To -2 Do
		
		Filter = New Structure;
		Filter.Insert("PictureIndex", - Index);
		
		FoundIndexes = CorrespondentInfobaseTable.Rows.FindRows(Filter, True);
		
		For Each FoundIndex In FoundIndexes Do
			
			FoundIndex.PictureIndex = FoundIndex.PictureIndex + 1;
			
		EndDo;
		
	EndDo;
	
EndProcedure

#EndRegion
