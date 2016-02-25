// Optional form parameters:
//
//    SimplifiedMode - Boolean - flag that shows whether a simplified 
//                               report is generated.
//

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
 
	// Skipping the initialization to guarantee that the form will be 
  // received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	Items.FormReportSettings.Visible = False;
	
	ThisDataProcessor = ThisObject();
	If IsBlankString(Parameters.ObjectAddress) Then
		SourceObject = ThisDataProcessor.InitializeThisObject(Parameters.ObjectSettings);
	Else
		SourceObject = ThisDataProcessor.InitializeThisObject(Parameters.ObjectAddress) 
	EndIf;
	
	// Editing filter according to the node scenario and imitating global filter
	If SourceObject.ExportVariant = 3 Then
		SourceObject.ExportVariant = 2;
		
		SourceObject.AllDocumentsFilterComposer = Undefined;
		SourceObject.AllDocumentsFilterPeriod   = Undefined;
		
		DataExchangeServer.FillValueTable(SourceObject.AdditionalRegistration, SourceObject.AdditionalNodeScenarioRegistration);
	EndIf;
	SourceObject.AdditionalNodeScenarioRegistration.Clear();
		
	ThisObject(SourceObject);
	
	If Not ValueIsFilled(Object.InfobaseNode) Then
		Text = NStr("en='Data exchange settings item not found.'");
		DataExchangeServer.ReportError(Text, Cancel);
		Return;
	EndIf;
	
	Title = Title + " (" + Object.InfobaseNode + ")";
	BaseFormName = ThisDataProcessor.BaseFormName();
	
	Parameters.Property("SimplifiedMode", SimplifiedMode);
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	RunGenerationAnimation();
	GenerateSpreadsheetDocumentServer();
	Attachable_WaitForReportGeneration();
EndProcedure

&AtClient
Procedure OnClose()
	OnCloseAtServer();
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure DetailProcessingResult(Item, Details, StandardProcessing)
	StandardProcessing = False;
	
	DetailParameters = FirstLevelDetailParameters(Details);
	If DetailParameters <> Undefined Then
		If DetailParameters.RegistrationObjectMetadataName = DetailParameters.FullMetadataName Then
			DetailType = TypeOf(DetailParameters.RegistrationObject);
			
			If DetailType = Type("Array") OR DetailType = Type("ValueList") Then
				// List details
				DetailParameters.Insert("ObjectSettings", Object);
				DetailParameters.Insert("SimplifiedMode", SimplifiedMode);
				
				OpenForm(BaseFormName + "Form.ExportContent", DetailParameters);
				Return;
			EndIf;
			
			// Object details
			FormParameters = New Structure("Key", DetailParameters.RegistrationObject);
			OpenForm(DetailParameters.FullMetadataName + ".ObjectForm", FormParameters);

		ElsIf Not IsBlankString(DetailParameters.ListPresentation) Then
			// Opening this form with new parameters
			DetailParameters.Insert("ObjectSettings", Object);
			DetailParameters.Insert("SimplifiedMode", SimplifiedMode);
			
			OpenForm(BaseFormName + "Form.ExportContent", DetailParameters);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure GenerateReport(Command)
	RunGenerationAnimation();
	GenerateSpreadsheetDocumentServer();
	Attachable_WaitForReportGeneration();
EndProcedure

&AtClient
Procedure ReportSettings(Command)
	Items.FormReportSettings.Check = Not Items.FormReportSettings.Check;
	Items.SettingsComposerUserSettings.Visible = Items.FormReportSettings.Check;
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure Attachable_WaitForReportGeneration()
	If ImportReportResult() Then
		StopGenerationAnimation();
	Else
		AttachIdleHandler("Attachable_WaitForReportGeneration", 3, True);
	EndIf;
EndProcedure

&AtServer
Function ThisObject(NewObject=Undefined)
	If NewObject = Undefined Then
		Return FormAttributeToValue("Object");
	EndIf;
	ValueToFormAttribute(NewObject, "Object");
	Return Undefined;
EndFunction

&AtClient
Procedure StopGenerationAnimation()
	StatePresentation = Items.Result.StatePresentation;
	StatePresentation.Visible = False;
	StatePresentation.AdditionalShowMode = AdditionalShowMode.DontUse;
EndProcedure

&AtClient
Procedure RunGenerationAnimation()
	StatePresentation = Items.Result.StatePresentation;
	StatePresentation.Visible            = True;
	StatePresentation.AdditionalShowMode = AdditionalShowMode.Irrelevance;
	StatePresentation.Picture            = PictureLib.LongAction48;
	StatePresentation.Text               = NStr("en = 'Generating report...'");
EndProcedure    

&AtServer
Procedure GenerateSpreadsheetDocumentServer()
	
	StopReportGeneration();
	
	// Initializing new background generation. The progress is monitored from the idle handler.
	BackgroundJobResultAddress = PutToTempStorage(Undefined, ThisObject.UUID);
	BackgroundJobID = ThisObject().UserSpreadsheetDocumentBackgroundGeneration(BackgroundJobResultAddress, Parameters.FullMetadataName, Parameters.ListPresentation, SimplifiedMode);
	If DataExchangeServer.BackgroundJobCompleted(BackgroundJobID) Then
		ImportReportResult();
	EndIf;
	
EndProcedure

&AtServer
Procedure StopReportGeneration()
	
	DataExchangeServer.CancelBackgroundJob(BackgroundJobID);
	If Not IsBlankString(BackgroundJobResultAddress) Then
		DeleteFromTempStorage(BackgroundJobResultAddress);
	EndIf;
	
	BackgroundJobResultAddress = "";
	BackgroundJobID            = Undefined;
EndProcedure

&AtServer
Function ImportReportResult()
	
	If Not DataExchangeServer.BackgroundJobCompleted(BackgroundJobID) Then
		Return False;
	EndIf;
	
	ReportData = Undefined;
	If Not IsBlankString(BackgroundJobResultAddress) Then
		ReportData = GetFromTempStorage(BackgroundJobResultAddress);
		DeleteFromTempStorage(BackgroundJobResultAddress);
	EndIf;
	
	StopReportGeneration();
	
	If TypeOf(ReportData)<>Type("Structure") Then
		Return True;
	EndIf;
	
	Result = ReportData.SpreadsheetDocument;
	
	ClearDetails();
	DetailDataAddress = PutToTempStorage(ReportData.Details, New UUID);
	CompositionSchemaAddress = PutToTempStorage(ReportData.CompositionSchema, New UUID);
	
	Return True;
EndFunction

&AtServer
Procedure OnCloseAtServer()
	StopReportGeneration();
	ClearDetails();
EndProcedure

&AtServer
Procedure ClearDetails()
	
	If Not IsBlankString(DetailDataAddress) Then
		DeleteFromTempStorage(DetailDataAddress);
	EndIf;
	If Not IsBlankString(CompositionSchemaAddress) Then
		DeleteFromTempStorage(CompositionSchemaAddress);
	EndIf;
	
EndProcedure

&AtServer
Function FirstLevelDetailParameters(Details)
	
	DetailProcessing = New DataCompositionDetailsProcess(
		DetailDataAddress,
		New DataCompositionAvailableSettingsSource(CompositionSchemaAddress));
	
	MetadataNameField = New DataCompositionField("FullMetadataName");
	Settings = DetailProcessing.DrillDown(Details, MetadataNameField);
	
	DetailParameters = New Structure("FullMetadataName, ListPresentation, RegistrationObject, RegistrationObjectMetadataName");
	DetailLevelGroupAnalysis(Settings.Filter, DetailParameters);
	
	If IsBlankString(DetailParameters.FullMetadataName) Then
		Return Undefined;
	EndIf;
	
	Return DetailParameters;
EndFunction

&AtServer
Procedure DetailLevelGroupAnalysis(Filter, DetailParameters)
	
	MetadataNameField = New DataCompositionField("FullMetadataName");
	PresentationField = New DataCompositionField("ListPresentation");
	ObjectField       = New DataCompositionField("RegistrationObject");
	
	For Each Item In Filter.Items Do
		If TypeOf(Item) = Type("DataCompositionFilterItemGroup") Then
			DetailLevelGroupAnalysis(Item, DetailParameters);
			
		ElsIf Item.LeftValue = MetadataNameField Then
			DetailParameters.FullMetadataName = Item.RightValue;
			
		ElsIf Item.LeftValue = PresentationField Then
			DetailParameters.ListPresentation = Item.RightValue;
			
		ElsIf Item.LeftValue = ObjectField Then
			RegistrationObject = Item.RightValue;
			DetailParameters.RegistrationObject = RegistrationObject;
			
			If TypeOf(RegistrationObject) = Type("Array") And RegistrationObject.Count()>0 Then
				Option = RegistrationObject[0];
			ElsIf TypeOf(RegistrationObject) = Type("ValueList") And RegistrationObject.Count()>0 Then
				Option = RegistrationObject[0].Value;
			Else
				Option = RegistrationObject;
			EndIf;
			
			Meta = Metadata.FindByType(TypeOf(Option));
			DetailParameters.RegistrationObjectMetadataName = ?(Meta = Undefined, Undefined, Meta.FullName());
		EndIf;
		
	EndDo;
EndProcedure

#EndRegion
