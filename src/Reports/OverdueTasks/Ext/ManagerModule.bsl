#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalInterface

// Report pane layout settings.
//
// Parameters:
//   Settings - Collection - is used to set report settings and report options. 
//      See the description of ReportOptions.ConfigurationReportOptionSettingsTree().
//  ReportSettings - ValueTreeRow - layout settings for all report options.
//      See "Attributes that can be changed" in the ReportOptions.ConfigurationReportOptionSettingsTree() function.
//
// Details:
//  See ReportOptionsOverridable.SetUpReportOptions().
//
// Auxiliary methods:
//   OptionSettings = ReportOptions.OptionDetails(Settings, ReportSettings, "<OptionName>");
//   ReportOptions.SetOutputModeInReportPane(Settings, ReportSettings, True/False); 
// The report can be generated only in this mode.
//
Procedure SetUpReportOptions(Settings, ReportSettings) Export
	ReportOptionsModule = CommonUse.CommonModule("ReportOptions");
	ReportSettings.Details = NStr("en = 'List of tasks completed with deadline violation, by performers.'");
	
	OptionSettings = ReportOptionsModule.OptionDetails(Settings, ReportSettings, "TasksCompletedWithDeadlineViolation");
	OptionSettings.Details = NStr("en = 'List of tasks completed with deadline violation, by performers.'");
EndProcedure

#EndRegion

#EndIf