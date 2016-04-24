#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalInterface

// Report pane layout settings.
//
// Parameters:
//   Settings - Collection - this parameter is used to describe report settings
//   and report options. See the description of ReportOptions.ConfigurationConfigurationReportOptionSettingsTree().
//   ReportSettings - ValueTreeRow - layout settings for all report options
//   See "Attributes that can be changed" in the
//   ReportOptions.ConfigurationReportOptionSettingsTree() function.
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
	ReportSettings.Details = NStr("en = 'Task list and summary.'");
	
	OptionSettings = ReportOptionsModule.OptionDetails(Settings, ReportSettings, "CurrentTasks");
	OptionSettings.Details = NStr("en = 'All tasks in progress with the specified deadline.'");
	
	OptionSettings = ReportOptionsModule.OptionDetails(Settings, ReportSettings, "PerformerDisciplineSummary");
	OptionSettings.Details = NStr("en = 'Summary with the number of tasks completed in time and overdue tasks by performers.'");
EndProcedure

#EndRegion

#EndIf