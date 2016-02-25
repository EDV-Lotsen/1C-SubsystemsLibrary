&AtServer
Procedure GetReportNameAndVariantKey(CommandParameter, ReportName, VariantKey)

	SettingObject = CommandParameter.GetObject();
	VariantKey = SettingObject.Code;
	ReportName = SettingObject.ObjectKey;

EndProcedure

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)

	Var ReportName, VariantKey;

	If Not ValueIsFilled(CommandParameter) Then
		Return;
	EndIf;

	GetReportNameAndVariantKey(CommandParameter, ReportName, VariantKey);

	If Not ValueIsFilled(ReportName) Then
		Return;
	EndIf;

	If Not ValueIsFilled(VariantKey) Then
		Return;
	EndIf;

	Form = GetForm(ReportName + ".Form", , New Uuid);
	Form.SetCurrentVariant(VariantKey);
	Form.Open();

EndProcedure
