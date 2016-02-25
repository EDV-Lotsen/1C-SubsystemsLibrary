
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	ItemOverallPerformance = PerformanceMonitorInternal.GetOverallSystemPerformanceItem();
	If ValueIsFilled(ItemOverallPerformance) Then
		CommonUseClientServer.SetDynamicListFilterItem(
			List, "Ref", ItemOverallPerformance,
			DataCompositionComparisonType.NotEqual, , ,
			DataCompositionSettingsItemViewMode.Normal);
	EndIf;
	
	CommonUseClientServer.MoveFiltersToDynamicList(ThisObject);
EndProcedure

#EndRegion
