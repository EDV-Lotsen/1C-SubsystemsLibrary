#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalInterface

// Report pane layout settings.
//
// Parameters:
//   Settings - Collection - this parameter is used to describe report settings
//   and report options. See the description of
//   ReportOptions.ConfigurationReportOptionSettingsTree(). 
//   ReportSettings - ValueTreeRow - layout settings for all report options
//   See "Attributes that can be changed" in the
//   ReportOptions.ConfigurationReportOptionSettingsTree() function.
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
	ReportSettings.Details = NStr("en = 'Analysis of unassigned tasks that cannot be executed as they are not assigned to any performers.'");
	
	OptionSettings = ReportOptionsModule.OptionDetails(Settings, ReportSettings, "UnassignedTasksSummary");
	OptionSettings.Details = NStr("en = 'Summary with the number of tasks assigned to each role with no performers.'");
	
	OptionSettings = ReportOptionsModule.OptionDetails(Settings, ReportSettings, "UnassignedTasksByPerformers");
	OptionSettings.Details = NStr("en = 'Unassigned tasks assigned to roles with no performers.'");
	
	OptionSettings = ReportOptionsModule.OptionDetails(Settings, ReportSettings, "UnassignedTasksByAddressingObjects");
	OptionSettings.Details = NStr("en = 'Unassigned tasks by addressing objects.'");
	
	OptionSettings = ReportOptionsModule.OptionDetails(Settings, ReportSettings, "OverdueTasks");
	OptionSettings.Details = NStr("en = 'Unassigned tasks that cannot be executed as they are not assigned to any performers.'");
EndProcedure

#EndRegion

#EndIf