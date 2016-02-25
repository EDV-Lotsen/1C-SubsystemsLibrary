//////////////////////////////////////////////////////////////////////////////// 
// EVENT HANDLERS
//

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	If Parameters.Key.IsEmpty() Then

		Object.DataBits = 8;
		Object.Speed    = 9600;
		Object.Port     = "COM1";

	EndIf;

EndProcedure
