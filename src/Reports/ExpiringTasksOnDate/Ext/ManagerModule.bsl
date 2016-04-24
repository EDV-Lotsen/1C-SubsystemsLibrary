#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalInterface

// Report pane layout settings.
//
// Parameters:
// Settings - Collection - is used to specify report settings and report options. 
//   See the description of ReportOptions.ConfigurationReportOptionSettingsTree().
// ReportSettings - ValueTreeRow - layout settings for all report options.
//   See "Attributes that can be changed" in the ReportOptions.ConfigurationReportOptionSettingsTree() function.
//
// Details:
//  See ReportOptionsOverridable.SetUpReportOptions().
//
// Auxiliary methods:
//   OptionSettings = ReportOptions.OptionDetails(Settings, ReportSettings, "<OptionName>");
//   ReportOptions.SetOutputModeInReportPane(Settings, ReportSettings, True/False);
//   The report can be generated only in this mode.
//
Procedure SetUpReportOptions(Settings, ReportSettings) Export
	ReportOptionsModule = CommonUse.CommonModule("ReportOptions");
	ReportSettings.Details = NStr("en = 'List of tasks that should be completed by the specified date.'");
	
	OptionSettings = ReportOptionsModule.OptionDetails(Settings, ReportSettings, "ExpiringTasksOnDate");
	OptionSettings.Details = NStr("en = 'List of tasks that should be completed by the specified date.'");
EndProcedure

#EndRegion

#EndIf