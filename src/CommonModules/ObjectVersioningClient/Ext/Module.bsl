////////////////////////////////////////////////////////////////////////////////
// Object versioning subsystem
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Opens object version report in version comparison mode.
//
// Parameters:
//  Ref                     - AnyRef - versionized object reference.
//  SerializedObjectAddress - String - address of binary data of the object version being compared
//                                     in the temporary storage.
//
Procedure OpenReportOnChanges(Ref, SerializedObjectAddress) Export
	
	Parameters = New Structure;
	Parameters.Insert("Ref", Ref);
	Parameters.Insert("SerializedObjectAddress", SerializedObjectAddress);
	
	OpenForm("InformationRegister.ObjectVersions.Form.ReportOnObjectVersions", Parameters);
	
EndProcedure

// Opens the report for the object version passed in SerializedObjectAddress parameter.
//
// Parameters:
//  Ref                     - AnyRef - versionized object reference.
//  SerializedObjectAddress - String - address of binary data of the object version in the temporary storage.
//
Procedure OpenReportOnObjectVersion(Ref, SerializedObjectAddress) Export
	
	Parameters = New Structure;
	Parameters.Insert("Ref", Ref);
	Parameters.Insert("SerializedObjectAddress", SerializedObjectAddress);
	Parameters.Insert("ByVersion", True);
	
	OpenForm("InformationRegister.ObjectVersions.Form.ReportOnObjectVersions", Parameters);
	
EndProcedure

#EndRegion

#Region InternalInterface

////////////////////////////////////////////////////////////////////////////////
// Handlers of the conditional subsystem calls

// Opens the version report or the version comparison report.
//
// Parameters:
// Ref              - object reference.
// ComparedVersions - Array - contains versions to be compared.
// If there is a single version in the array, the version report is opened.
//
Procedure OnOpenReportFormByVersion(Ref, ComparedVersions) Export
	
	ReportParameters = New Structure;
	ReportParameters.Insert("Ref", Ref);
	ReportParameters.Insert("ComparedVersions", ComparedVersions);
	OpenForm("InformationRegister.ObjectVersions.Form.ReportOnObjectVersions", ReportParameters);
	
EndProcedure

#EndRegion
