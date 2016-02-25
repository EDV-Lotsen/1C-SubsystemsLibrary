////////////////////////////////////////////////////////////////////////////////
// Information center subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERNAL INTERFACE

// Retrieves a table with information links for forms.
//
// Parameters:
//	PathToForm - String- full path to form.
//
// Returns:
//	ValuesTable - information link table for forms. Contains the following columns:
// 	Description - String - information link description.
// 	URL         - String - information link URL.
// 	Weight      - Number - information link weight.
// 	StartDate   - Date - information link actuality start date.
// 	EndDate     - Date - information link actuality end date.
// 	ToolTip     - String - information link tooltip.
//
Function GetInformationLinkTableForForm(PathToForm) Export
	
	SetPrivilegedMode(True);
	CurrentConfigurationVersion = InformationCenterInternal.GetVersionNumber(Metadata.Version);
	SetPrivilegedMode(False);
	
	Query = New Query;
	Query.SetParameter("FullPathToForm",              PathToForm);
	Query.SetParameter("ZeroVersion",                 0);
	Query.SetParameter("CurrentConfigurationVersion", CurrentConfigurationVersion);
	Query.SetParameter("CurrentDate",                 CurrentDate()); // SL design decision
	Query.SetParameter("BlankDate",                   '00010101');
	Query.Text = 
	"SELECT
	|	FullPathToForms.Reference AS Ref
	|INTO PathsToForms
	|FROM
	|	Catalog.FullPathToForms AS FullPathToForms
	|WHERE
	|	FullPathToForms.FullPathToForm LIKE &FullPathToForm
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InformationLinksForForms.Description AS Description,
	|	InformationLinksForForms.URL AS URL,
	|	InformationLinksForForms.Weight AS Weight,
	|	InformationLinksForForms.StartDate AS StartDate,
	|	InformationLinksForForms.EndDate AS EndDate,
	|	InformationLinksForForms.ToolTip AS ToolTip
	|FROM
	|	PathsToForms AS PathsToForms
	|		INNER JOIN Catalog.InformationLinksForForms AS InformationLinksForForms
	|			ON PathsToForms.Reference = InformationLinksForForms.FullPathToForm
	|WHERE
	|	(InformationLinksForForms.ConfigurationVersionLaterThen = &ZeroVersion
	|				AND InformationLinksForForms.ConfigurationVersionEarlierThen = &ZeroVersion
	|			OR InformationLinksForForms.ConfigurationVersionLaterThen = &ZeroVersion
	|				AND InformationLinksForForms.ConfigurationVersionEarlierThen >= &CurrentConfigurationVersion
	|			OR InformationLinksForForms.ConfigurationVersionLaterThen <= &CurrentConfigurationVersion
	|				AND InformationLinksForForms.ConfigurationVersionEarlierThen = &ZeroVersion
	|			OR InformationLinksForForms.ConfigurationVersionLaterThen <= &CurrentConfigurationVersion
	|				AND InformationLinksForForms.ConfigurationVersionEarlierThen >= &CurrentConfigurationVersion)
	|	AND (InformationLinksForForms.StartDate = &BlankDate
	|				AND InformationLinksForForms.EndDate = &BlankDate
	|			OR InformationLinksForForms.StartDate = &BlankDate
	|				AND InformationLinksForForms.EndDate >= &CurrentDate
	|			OR InformationLinksForForms.StartDate <= &CurrentDate
	|				AND InformationLinksForForms.EndDate = &BlankDate
	|			OR InformationLinksForForms.StartDate <= &CurrentDate
	|				AND InformationLinksForForms.EndDate >= &CurrentDate)";
	
	Return Query.Execute().Unload();
	
EndFunction
