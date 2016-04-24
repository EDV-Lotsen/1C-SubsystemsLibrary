#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalInterface

// Report pane layout settings.
//
// Parameters:
//   Settings - Collection - this parameter is used to describe report settings for all report options.
//   See the description of ReportOptions.ConfigurationReportOptionSettingsTree().
//   ReportSettings - ValueTreeRow - layout settings for all report options
//   See "Attributes that can be changed" in the ReportOptions.ConfigurationReportOptionSettingsTree() function.
//
// Details:
//   See ReportOptionsOverridable.SetUpReportOptions().
//
// Auxiliary methods:
//   OptionSettings = ReportOptions.OptionDetails(Settings, ReportSettings, "<OptionName>");
//   ReportOptions.SetOutputModeInReportPane(Settings, ReportSettings, True/False);
//   The report can be generated only in this mode.
//
Procedure SetUpReportOptions(Settings, ReportSettings) Export
	ReportOptionsModule = CommonUse.CommonModule("ReportOptions");
	ReportSettings.Details = NStr("en = 'Business process list and summary.'");
	
	OptionSettings = ReportOptionsModule.OptionDetails(Settings, ReportSettings, "BusinessProcessList");
	OptionSettings.Details = NStr("en = 'Business processes of certain types for the specified period.'");
	
	OptionSettings = ReportOptionsModule.OptionDetails(Settings, ReportSettings, "StatisticsByKind");
	OptionSettings.Details = NStr("en = 'Summary chart with the number of active and completed business processes.'");
EndProcedure

#EndRegion

#EndIf