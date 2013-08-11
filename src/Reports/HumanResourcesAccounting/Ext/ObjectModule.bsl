
Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)

	StandardProcessing 		= False;
	
	ArrayHeaderResources 	= New Array;
	ReportSettings 			= SettingsComposer.GetSettings();
	TemplateComposer 		= New DataCompositionTemplateComposer;
	CompositionTemplate 	= TemplateComposer.Execute(DataCompositionSchema, ReportSettings, DetailsData);

	//Create and initialize composition processor
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, , DetailsData, True);

	//Create and initialize result output processor
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);

	//Specify output beginning
	OutputProcessor.BeginOutput();
	TableIsFrozen = False;

	ResultDocument.FixedTop = 0;
	//Report main output loop
	While True Do
		//Get next item of the composition result
		ResultItem = CompositionProcessor.Next();

		If ResultItem = Undefined Then
			//Next item is not received - finish output loop
			Break;
		Else
			// Freeze header
			If  Not TableIsFrozen 
				  And ResultItem.ParameterValues.Count() > 0 
				  And TypeOf(SettingsComposer.Settings.Structure[0]) <> Type("DataCompositionChart") Then

				TableIsFrozen = True;
				ResultDocument.FixedTop = ResultDocument.TableHeight;

			EndIf;
			//Item is received - output it using output processor
			OutputProcessor.OutputItem(ResultItem);
		EndIf;
	EndDo;

	OutputProcessor.EndOutput();

EndProcedure
