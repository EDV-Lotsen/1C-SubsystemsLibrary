//////////////////////////////////////////////////////////////////////////////// 
// EVENT HANDLERS
// 

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	If GetFunctionalOption("AccountingByWarehouses") Then

		// Setting the Warehouse parameter of the dynamic list.
		If Parameters.Property("BalanceByWarehouse") Then

			CatalogList.Parameters.SetParameterValue("ByAllWarehouses", False);
			CatalogList.Parameters.SetParameterValue("Warehouse", Parameters.BalanceByWarehouse); 

		Else

			Cancel = True; 

		EndIf

	Else

		CatalogList.Parameters.SetParameterValue("ByAllWarehouses", True);
		CatalogList.Parameters.SetParameterValue("Warehouse", Catalogs.Warehouses.EmptyRef()); 

	EndIf;
	
	// StandardSubsystems.Print
	PrintManagement.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.Print

EndProcedure

// StandardSubsystems.Print
&AtClient
Процедура Attachable_ExecutePrintCommand(Command)
	
    PrintManagementClient.RunAttachablePrintCommand(Command, ThisObject, Items.List);
	
КонецПроцедуры

// End StandardSubsystems.Print
