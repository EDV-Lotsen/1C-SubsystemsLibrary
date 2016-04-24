#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalInterface

// Report pane layout settings.
//
// Parameters:
//   Settings - Collection - used to specify report settings and report options. 
//              See the description of   
//              ReportOptions.ConfigurationReportOptionSettingsTree().
//   ReportSettings - ValueTreeRow - layout settings for all report options.
//              See "Attributes that can be changed" in the 
//              ReportOptions.ConfigurationReportOptionSettingsTree()function.
//
// Description:
//   See ReportOptionsOverridable.SetUpReportOptions().
//
// Auxiliary methods:
//   OptionSettings = ReportOptions.OptionDetails(Settings, ReportSettings, "<OptionName>");
//   ReportOptions.SetOutputModeInReportPanes(Settings, ReportSettings, True/False); 
//   The report can be generated only in this mode.
//
Procedure SetUpReportOptions(Settings, ReportSettings) Export
	ReportSettings.Enabled = False;
EndProcedure

#EndRegion

#EndIf
