#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	KeyOperation = Parameters.HistorySettings.KeyOperation;
	StartDate    = Parameters.HistorySettings.StartDate;
	EndDate      = Parameters.HistorySettings.EndDate;
	Priority     = KeyOperation.Priority;
	TargetTime   = KeyOperation.TargetTime;
	
	Query = New Query;
	Query.SetParameter("KeyOperation", KeyOperation);
	Query.SetParameter("StartDate",    StartDate);
	Query.SetParameter("EndDate",      EndDate);
	
	Query.Text = 
	"SELECT
	|	TimeMeasurements.User AS User,
	|	TimeMeasurements.ExecutionTime AS Duration,
	|	TimeMeasurements.MeasurementStartDate AS EndTime
	|FROM
	|	InformationRegister.TimeMeasurements AS TimeMeasurements
	|WHERE
	|	TimeMeasurements.KeyOperation = &KeyOperation
	|	AND TimeMeasurements.MeasurementStartDate BETWEEN &StartDate AND &EndDate
	|
	|ORDER BY
	|	EndTime";
	
	Selection = Query.Execute().Select();
	MeasurementCountNumber = Selection.Count();
	MeasurementCount = String(MeasurementCountNumber) + ?(MeasurementCountNumber < 100, " (not enough)", "");
	
	While Selection.Next() Do
		
		HistoryRow = History.Add();
		FillPropertyValues(HistoryRow, Selection);
		
	EndDo;
	
EndProcedure

#EndRegion

#Region HistoryFormTableItemEventHandlers

// Prohibits editing a key operation from a data processor form 
// because this might impact internal functionality.
//
&AtClient
Procedure KeyOperationOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

#EndRegion
