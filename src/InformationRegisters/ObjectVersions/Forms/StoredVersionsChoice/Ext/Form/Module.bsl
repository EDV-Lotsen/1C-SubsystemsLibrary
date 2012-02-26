
////////////////////////////////////////////////////////////////////////////////
// SECTION OF FORM AND FORM ITEMS EVENT HANDLERS

// Handler of the form event "OnCreateAtServer"
//
&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	Ref = Parameters.Ref;
	
	If ObjectVersioning.GetObjectVersionsCount(Ref) = 0 Then
		Items.MainPage.CurrentPage = Items.NoVersionsForCompare;
		Text_MissingVersions = StringFunctionsClientServer.SubstitureParametersInString(
		                               NStr("en = 'No stored versions relating tom the object <%1>.'"),
		                               String(Ref));
	EndIf;
	
	ValueToFormAttribute(GenerateVersionsTable(Ref), "VersionsList");
	
EndProcedure

// Function returns the list of numbers of versions of the object passed by ref
//
// Parameters:
// Ref        - CatalogRef, DocumentRef - object ref
//
&AtServerNoContext
Function GenerateVersionsTable(Ref)
	
	Query = New Query;
	Query.Text = "SELECT VersionNo, VersionAuthor, VersionDate
	                | FROM InformationRegister.ObjectVersions
	                | WHERE Object=&Ref
	                | ORDER BY VersionNo Desc";
	Query.SetParameter("Ref", Ref);
	
	Return Query.Execute().Unload();
	
EndFunction

// Handler of event "Selection" of table box "VersionsList"
//
&AtClient
Procedure VersionsListSelection(Item, RowSelected, Field, StandardProcessing)
	
	OpenObjectVersion();
	
EndProcedure

// Handler of click on the button "OpenObjectVersion"
//
&AtClient
Procedure OpenObjectVersionExecute()
	
	OpenObjectVersion();
	
EndProcedure

// Handler of click on the "ReportByChanges"
//
&AtClient
Procedure GenerateChangesReportExecute()
	
	SelectedRows = Items.VersionsList.SelectedRows;
	
	SelectedVersions = GenerateListOfSelectedVersions(SelectedRows);
	
	If SelectedVersions.Count() < 2 Then
		DoMessageBox(NStr("en = 'To generate report by change it is necessary to select minimum two versions.'"));
	Else
		OpenReportForm(SelectedVersions);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Section of the service functions

// Checks, that in version list some version was selected and returns the report
// form with the passed parameter - number of the selected version.
//
&AtClient
Procedure OpenObjectVersion()
	
	If ValueIsFilled(Items.VersionsList.CurrentData.VersionNo) Then
		SelectedVersions = New ValueList;
		SelectedVersions.Add(Items.VersionsList.CurrentData.VersionNo);
		
		If SelectedVersions <> Undefined Then
			OpenReportForm(SelectedVersions);
		EndIf;
	Else
		DoMessageBox(NStr("en = 'To continue it is necessary to choose object version'"));
	EndIf;
	
EndProcedure

// Opens form of the report by changes, with the required parameters
//
&AtClient
Procedure OpenReportForm(VersionsListParameter)
	
	ReportParameters = New Structure;
	ReportParameters.Insert("Ref", Ref);
	ReportParameters.Insert("VersionsList", VersionsListParameter);
	
	OpenForm("Report.ReportByVersions.Form.ReportForm",
	             ReportParameters,
	             ThisForm,
	             Uuid);
	
EndProcedure

// Function returns number list of the selected versions
//
&AtClient
Function GenerateListOfSelectedVersions(SelectedRows)
	
	SelectedVersions = New ValueList;
	
	For Each SelectedRowsNumber In SelectedRows Do
		SelectedVersions.Add(VersionsList[SelectedRowsNumber].VersionNo);
	EndDo;
	
	SelectedVersions.SortByValue(SortDirection.Asc);
	
	Return SelectedVersions;
	
EndFunction
