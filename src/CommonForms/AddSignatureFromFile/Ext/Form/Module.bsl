
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	SetConditionalAppearance();
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure SignaturesPathToFileStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	If Not AttachFileSystemExtension() Then
		Return;
	EndIf;
		
	FileDialog = New FileDialog(FileDialogMode.Open);
	FileDialog.FullFileName = Items.Signatures.CurrentData.PathToFile;
	Filter = NStr("en = 'All files (*.*)|*.*'");
	FileDialog.Filter = Filter;
	FileDialog.Multiselect = False;
	FileDialog.Title = NStr("en = 'Select files'");
	
	If FileDialog.Choose() Then
		Items.Signatures.CurrentData.PathToFile = FileDialog.FullFileName;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	// filling check is in progress
	ClearMessages();
	
	ReturnArray = New Array;
	HasFillingErrors = False;
	
	If Signatures.Count() = 0 Then
		ErrorText = NStr("en = 'No signature file is specified'");
		CommonUseClientServer.MessageToUser(ErrorText, , "Signatures");
		Return;
	EndIf;
	
	For Each Row In Signatures Do
		
		If IsBlankString(Row.PathToFile) Then
			ErrorText = NStr("en = 'Path to signature file is not filled'");
			CommonUseClientServer.MessageToUser(ErrorText, , "Signatures");
			HasFillingErrors = True;
		EndIf;
		
		Write = New Structure("PathToFile, Comment",
						Row.PathToFile,
						Row.Comment);
			
		ReturnArray.Add(Write);
	EndDo;
	
	If Not HasFillingErrors Then
		Close(ReturnArray);
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.SignaturesPathToFile.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Signatures.PathToFile");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	Item.Appearance.SetParameterValue("MarkIncomplete", True);

EndProcedure

#EndRegion
