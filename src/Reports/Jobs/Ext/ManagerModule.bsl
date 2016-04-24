#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalInterface

// Report pane layout settings.
//
// Parameters:
//   Settings - Collection - this parameter is used to describe report settings and report options.
//   See the description of ReportOptions.ConfigurationReportOptionSettingsTree(). 
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
	ReportSettings.Details = NStr("en = 'Jobs and job execution summary.'");
	
	OptionSettings = ReportOptionsModule.OptionDetails(Settings, ReportSettings, "JobList");
	OptionSettings.Details = NStr("en = 'All jobs for the specified period.'");
	
	OptionSettings = ReportOptionsModule.OptionDetails(Settings, ReportSettings, "JobStatistics");
	OptionSettings.Details = NStr("en = 'Summary chart with all completed jobs, canceled jobs, and jobs in progress.'");
	
	OptionSettings = ReportOptionsModule.OptionDetails(Settings, ReportSettings, "ExecutionCycleCheckStatistics");
	OptionSettings.Details = NStr("en = 'Top 10 authors by average number of job checks.'");
	
	OptionSettings = ReportOptionsModule.OptionDetails(Settings, ReportSettings, "DurationStatistics");
	OptionSettings.Details = NStr("en = 'Top 10 authors by average job execution duration.'");
EndProcedure

#EndRegion

#EndIf