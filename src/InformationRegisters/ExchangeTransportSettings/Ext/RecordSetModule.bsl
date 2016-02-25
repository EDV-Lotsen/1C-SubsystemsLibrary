#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	// If data separation mode is set, record set modification is prohibited for shared nodes
	DataExchangeServer.ExecuteSharedDataOnWriteCheck(Filter.Node.Value);
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	For Each SetRow In ThisObject Do
		
		// If the WSRememberPassword value is False, restoring the password
		If Not SetRow.WSRememberPassword Then
			
			SetRow.WSPassword = "";
			
		EndIf;
		
		// Deleting insignificant characters to the left of the first 
   // significant character and to the right of the last significant 
   // character in string parameters
		TrimAllFieldValue(SetRow, "COMInfobaseNameAtPlatformServer");
		TrimAllFieldValue(SetRow, "COMUserName");
		TrimAllFieldValue(SetRow, "COMPlatformServerName");
		TrimAllFieldValue(SetRow, "COMInfobaseDirectory");
		TrimAllFieldValue(SetRow, "COMUserPassword");
		TrimAllFieldValue(SetRow, "FILEDataExchangeDirectory");
		TrimAllFieldValue(SetRow, "FTPConnectionPassword");
		TrimAllFieldValue(SetRow, "FTPConnectionUser");
		TrimAllFieldValue(SetRow, "FTPConnectionPath");
		TrimAllFieldValue(SetRow, "WSURL");
		TrimAllFieldValue(SetRow, "WSUserName");
		TrimAllFieldValue(SetRow, "WSPassword");
		TrimAllFieldValue(SetRow, "ExchangeMessageArchivePassword");
		
	EndDo;
	
EndProcedure

Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
 // Updating the platform cache for reading
 // actual exchange message transport settings with
 // the DataExchangeCached.GetExchangeSettingsStructure procedure
	RefreshReusableValues();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

Procedure TrimAllFieldValue(Write, Val Field)
	
	Write[Field] = TrimAll(Write[Field]);
	
EndProcedure

#EndRegion

#EndIf
