#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then


Procedure BeforeWrite(Cancel)
	Var Characteristic;
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Details = DataKind;
	For Each Characteristic In DataCharacteristics Do
		Details = Details 
			+ ", " + Characteristic.Characteristic + ": " + Characteristic.Value;
	EndDo;
		
EndProcedure

#EndIf