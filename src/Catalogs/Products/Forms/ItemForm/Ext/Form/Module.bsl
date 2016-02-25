//////////////////////////////////////////////////////////////////////////////// 
// EVENT HANDLERS
//

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	// Setting the PictureURL attribute value.
	PictureFile = Object.PictureFile;
	If Not PictureFile.IsEmpty() Then
		PictureURL = GetURL(PictureFile, "FileData")
	EndIf;
	
	FillCharacteristics();
	
	DetermineEnabled(ThisObject);
	
	// StandardSubsystems.Properties
	PropertyManagement.OnCreateAtServer(ThisObject, , "AdditionalAttributesGroup");
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.Print
	PrintManagement.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.Print
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	WriteCharacteristics();
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	PicturesChanged = False;
	DetailsPictures.Clear();
	If  Items.DetailsEditingGroup.CurrentPage =  Items.EditGroup Then
		EditDetailsServer();
	EndIf;
	
	// StandardSubsystems.Properties
	PropertyManagement.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure DeleteDetailsPictures()
	
	Query = New Query;
	Query.Text  = 
		"SELECT
		|	Ref
		|FROM
		|	Catalog.StoredFiles
		|WHERE
		|	Owner = &Owner
		|	AND ForDetails = TRUE";

	Query.SetParameter("Owner",  Object.Ref);
	Selection =  Query.Execute().Select();
	While  Selection.Next() Do
		FileObject =  Selection.Ref.GetObject();
		If  FileObject <> Undefined Then
			FileObject.Delete();
		EndIf;
	EndDo;
	
EndProcedure
	
&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	Var HTMLText;
	Var Attachments;
	
	If  Items.DetailsEditingGroup.CurrentPage = Items.EditGroup Then
		
		DetailsBeingEditer.GetHTML(HTMLText,Attachments);
		URLMap = New Map();
		
		DeleteDetailsPictures();
		For Each Attachment In Attachments Do
			
			StoredFile = Catalogs.StoredFiles.CreateItem();
			StoredFile.Owner = CurrentObject.Ref;
			StoredFile.Description = Attachment.Key;
			StoredFile.FileName = Attachment.Key;
			StoredFile.ForDetails = True;
			BinaryData = Attachment.Value.GetBinaryData();
			StoredFile.FileData = New ValueStorage(BinaryData,  New Deflation());
			StoredFile.Write();
			Address = GetURL(StoredFile.Ref, "FileData");
			URLMap.Insert(Attachment.Key, Address);
		EndDo;		
		
		ConvertHTML(HTMLText, URLMap);
		
		CurrentObject.Details = HTMLText;
		
	ElsIf PicturesChanged Then
		
		HTMLText = CurrentObject.Details;
		
		DeleteDetailsPictures();
		For  Each Picture In  DetailsPictures Do
			StoredFile = Catalogs.StoredFiles.CreateItem();
			StoredFile.Owner = CurrentObject.Ref;
			StoredFile.Description =  Picture.Presentation;
			StoredFile.FileName = Picture.Presentation;
			StoredFile.ForDetails =  True;
			BinaryData = GetFromTempStorage(Picture.Value);
			StoredFile.FileData = New ValueStorage(BinaryData,  New Deflation());
			StoredFile.Write();
			DeleteFromTempStorage(Picture.Value);
			Address = GetURL(StoredFile.Ref, "FileData");
			HTMLText =  StrReplace(HTMLText, Picture.Value, Address);
		EndDo;
		
		CurrentObject.Details = HTMLText;
	EndIf;
	PicturesChanged = False;
	DetailsPictures.Clear();
	
	// StandardSubsystems.Properties
	PropertyManagement.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure PictureFileOnChange(Element)

	// Tracking the picture changes and the corresponding changes of the
	// PictureURL attribute.
	PictureFile = Object.PictureFile;
	If Not PictureFile.IsEmpty() Then
		PictureURL = GetURL(PictureFile, "FileData")
	Else
		PictureURL = "";
	EndIf;

EndProcedure

&AtClient
Procedure KindOnChange(Element)
	DetermineEnabled(ThisForm);
EndProcedure

&AtClient
Procedure PictureFileStartChoice(Element, ChoiceData, StandardProcessing)
	
	If Object.Ref.IsEmpty() Then
		ShowMessageBox(,NStr("en = 'data is not saved'"));
		StandardProcessing = False;
		Return;
	EndIf;

EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties 
	Если PropertyManagementClient.ProcessNofifications(ThisObject, EventName, Parameter) Тогда
     	UpdateAdditionalAttributeItems();
 	КонецЕсли;
 	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertyManagement.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

//////////////////////////////////////////////////////////////////////////////// 
// Form procedures and functions

// Sets the Enabled flag of items depending on what is being edited:
// product or service.
//
&AtClientAtServerNoContext
Procedure DetermineEnabled(Form)

	ProductAttributesEnabled = Form.Object.Kind = PredefinedValue("Enum.ProductKinds.Product");
	Form.Items.Barcode.Enabled = ProductAttributesEnabled;
	Form.Items.Vendor.Enabled = ProductAttributesEnabled;
	Form.Items.Sku.Enabled = ProductAttributesEnabled;

EndProcedure

&AtClient
Procedure AddCharacteristic(Command)
	
	// Selecting the characteristic kind
	Notification =  New NotifyDescription(
		"AddCharacteristicCompletion",
		ThisObject);
	OpenForm("ChartOfCharacteristicTypes.CharacteristicTypes.ChoiceForm",
		,,,,,  Notification,  FormWindowOpeningMode.LockWholeInterface);
EndProcedure

&AtClient
Procedure AddCharacteristicCompletion(CharacteristicType,  Parameters)  Export
	If  CharacteristicType =  Undefined Then
		Return;
	EndIf;	  
	
	// Checking whether the characteristic exists 
	If  CharacteristicsDescription.FindRows(
		 New  Structure("CharacteristicType",  CharacteristicType)).Count()  > 0  Then
		 ShowMessageBox(, NStr("en = 'Characteristic already exists.'"));
		 Return;
	EndIf;	  
	
	// Showing the characteristic kind on the form
	AddCharacteristicAtServer(CharacteristicType);
EndProcedure

&AtClient
Procedure DeleteCharacteristic(Command)
	
	// Selecting kind to be deleted
	KindList =  New ValueList;
	For  Each CharacteristicDescription In  CharacteristicsDescription Do
		
		KindListItem = KindList.Add();
		KindListItem.Value =  CharacteristicDescription.GetID();
		KindListItem.Presentation =  String(CharacteristicDescription.CharacteristicType);
		
	EndDo;
	Notification =  New NotifyDescription(
		"DeleteCharacteristicCompletion",  ThisObject);
	KindList.ShowChooseItem(Notification,  "Delete characteristic:");
	
EndProcedure

&AtClient
Procedure DeleteCharacteristicCompletion(SelectedItem,  Parameters)  Export
	// Verifying selection 
	If  SelectedItem =  Undefined Then
		Return;
	EndIf;	
	
	// Deleting
	DeleteCharacteristicAtServer(SelectedItem.Value);
EndProcedure

&AtServer
Procedure FillCharacteristics()

	// Adding attributes
	Query = New Query;
	Query.Text = 
		"SELECT
		|	CharacteristicTypes.Ref,
		|	CharacteristicTypes.Code,
		|	CharacteristicTypes.Description,
		|	CharacteristicTypes.ValueType,
		|	Characteristics.Object,
		|	Characteristics.CharacteristicType,
		|	Characteristics.Value
		|FROM
		|	ChartOfCharacteristicTypes.CharacteristicTypes AS CharacteristicTypes
		|		LEFT JOIN InformationRegister.Characteristics AS Characteristics
		|		ON (Characteristics.CharacteristicType = CharacteristicTypes.Ref)
		|WHERE
		|	Characteristics.Object = &Object
		|AUTOORDER";
	Query.SetParameter("Object", Object.Ref);
	Result = Query.Execute();
	SelectionDetailRecords = Result.Select();
	AttributesToAdd = New Array();
	While SelectionDetailRecords.Next() Do
		
		Attribute = New FormAttribute(
			"Characteristic" + SelectionDetailRecords.Code,
			SelectionDetailRecords.ValueType); 
		Attribute.StoredData = True;	
		AttributesToAdd.Add(Attribute);
		
	EndDo;
	ChangeAttributes(AttributesToAdd);
	
	// Adding items, filling the data, adding the characteristic details
	SelectionDetailRecords = Result.Select();
	While SelectionDetailRecords.Next() Do
		Element =Items.Add(
						  "Characteristic" + SelectionDetailRecords.Code,
						  Type("FormField"), Items.CharacteristicsGroup); 	
		Element.Type = FormFieldType.InputField;
		Element.Title = SelectionDetailRecords.Description;
		Element.DataPath = "Characteristic" + SelectionDetailRecords.Code;
		
		ArrayChoiceParameters = New Array();
		ArrayChoiceParameters.Add(New ChoiceParameter("Filter.Owner", SelectionDetailRecords.Ref));
		Element.ChoiceParameters = New FixedArray(ArrayChoiceParameters);
		
		CharacteristicDescription = CharacteristicsDescription.Add();
		CharacteristicDescription.CharacteristicType = SelectionDetailRecords.Ref;
		CharacteristicDescription.AttributeName = "Characteristic" + SelectionDetailRecords.Code;

		ThisObject["Characteristic" + SelectionDetailRecords.Code] = SelectionDetailRecords.Value;
		
		
	EndDo;

EndProcedure

&AtServer
Procedure AddCharacteristicAtServer(CharacteristicType)
	
	// Adding attribute
	AttributesToAdd = New Array();
	Attribute = New FormAttribute("Characteristic" + CharacteristicType.Code,
			CharacteristicType.ValueType); 
	Attribute.StoredData = True;	
	AttributesToAdd.Add(Attribute);
	ChangeAttributes(AttributesToAdd);
	
	// Adding item, filling the data
	Element = Items.Add(
					  "Characteristic" + CharacteristicType.Code,
					  Type("FormField"), Items.CharacteristicsGroup); 	
	Element.Type = FormFieldType.InputField;
	Element.Title = CharacteristicType.Description;
	Element.DataPath = "Characteristic" + CharacteristicType.Code;
	
	ChoiceParametersArray = New Array();
	ChoiceParametersArray.Add(New ChoiceParameter("Filter.Owner", CharacteristicType));
	Element.ChoiceParameters = New FixedArray(ChoiceParametersArray);
	
	// Adding the characteristic details
	CharacteristicDescription = CharacteristicsDescription.Add();
	CharacteristicDescription.CharacteristicType = CharacteristicType;
	CharacteristicDescription.AttributeName = "Characteristic" + CharacteristicType.Code;
	
	// Setting the new item as current
	CurrentControl = Element;
	
EndProcedure

&AtServer
Procedure DeleteCharacteristicAtServer(Id)
	
	CharacteristicDescription = CharacteristicsDescription.FindByID(Id);
	AttributeName = CharacteristicDescription.AttributeName;
	
	// Deleting the details
	CharacteristicsDescription.Delete(CharacteristicDescription);
	
	// Deleting item
	Items.Delete(Items.Find(AttributeName));
	
	// Deleting attribute
	AttributesToDelete = New Array();
	AttributesToDelete.Add(AttributeName);
	ChangeAttributes(, AttributesToDelete);
	
	
EndProcedure

&AtServer
Procedure WriteCharacteristics()

	// Generating the records set with the new characteristics values
	RecordSet = InformationRegisters.Characteristics.CreateRecordSet();
	RecordSet.Filter.Object.Set(Object.Ref);
	For Each CharacteristicDescription In CharacteristicsDescription Do
		
		Write = RecordSet.Add();
		Write.Object = Object.Ref;
		Write.CharacteristicType = CharacteristicDescription.CharacteristicType;
		Write.Value = ThisForm[CharacteristicDescription.AttributeName];
		
	EndDo;
	
	// Writing records set
	RecordSet.Write();

EndProcedure

&AtClient
Procedure RefreshPicture(Command)

	Items.Picture.Refresh();
	
EndProcedure

&AtServer
Procedure EditDetailsServer()
	
	HTMLText =  Object.Details;
	Attachments = New Structure();
	
	If PicturesChanged Then
		
		For Each Picture In DetailsPictures Do
			HTMLText = StrReplace(HTMLText, Picture.Value, Picture.Presentation);
			BinaryData = GetFromTempStorage(Picture.Value);
			Attachments.Insert(Picture.Presentation,  New Picture(BinaryData));
		EndDo;
		
	Else
		
		Query =  New Query;
		Query.Text  = 
			"SELECT
			|	Ref,
			|	FileData
			|FROM
			|	Catalog.StoredFiles
			|WHERE
			|	Owner = &Owner
			|	AND ForDetails =  TRUE";

		Query.SetParameter("Owner",  Object.Ref);
		Selection =  Query.Execute().Select();
		PictureNumber =  1;
		While  Selection.Next()  Do
			Address =  GetURL(Selection.Ref,  "FileData");
			Name =  "img"  + PictureNumber;
			PictureNumber =  PictureNumber +  1;
			HTMLText =  StrReplace(HTMLText,  Address, Name);
			Attachments.Insert(Name,  New Picture(Selection.FileData.Get()));
		EndDo;
		
	EndIf;
	
	DetailsBeingEditer.SetHTML(HTMLText,Attachments);
	
EndProcedure

&AtClient
Procedure EditDetails(Command)
	EditDetailsServer();
	Items.DetailsEditingGroup.CurrentPage =  Items.EditGroup;
EndProcedure

&AtServer
Procedure ConvertHTML(HTMLText, URLMap)
	
	HTMLReader = New HTMLReader;
	HTMLReader.SetString(HTMLText);
	
	DOMBuilder =  New DOMBuilder;
	HTMLDocument = DOMBuilder.Read(HTMLReader);
	
	// On mobile devices, description should display real the size, without compression.
	Item =  HTMLDocument.CreateElement("meta");
	Item.SetAttribute("name",  "viewport");
	Item.SetAttribute("content",  "initial-scale=1.0,  width=device-width");
	HeadItems =  HTMLDocument.GetElementByTagName("head");
	Head =  HeadItems.Item(0);
	Head.InsertBefore(Item,Head.FirstChild);
	
	// Transform addresses pictures
	ImgItems =  HTMLDocument.GetElementByTagName("img");
	For  Each Img In  ImgItems Do
		NewURL =  URLMap.Get(Img.Source);
		If  NewURL <>  Undefined Then  
			Img.Source  = NewURL;
		EndIf;
	EndDo;
	
	HTMLWriter =  New HTMLWriter;
	HTMLWriter.SetString();
	
	DOMWriter =  New DOMWriter;
	DOMWriter.Write(HTMLDocument,HTMLWriter);
	
	HTMLText =  HTMLWriter.Close();
	
EndProcedure

&AtServer
Procedure EndEditServer()
	Var  HTMLText;
	Var  Attachments;
	PicturesChanged = True;
	DetailsPictures.Clear();
	DetailsBeingEditer.GetHTML(HTMLText,Attachments);
	URLMap = New  Map();
	
	For  Each Attachment In  Attachments Do
		Address =  PutToTempStorage(Attachment.Value.GetBinaryData(),  UUID);
		DetailsPictures.Add(Address,Attachment.Key);
		URLMap.Insert(Attachment.Key,  Address);
	EndDo;		
	
	ConvertHTML(HTMLText,  URLMap);
	
	Object.Details  = HTMLText;
EndProcedure

&AtClient
Procedure EndEdit(Command)
	EndEditServer();
	Items.DetailsEditingGroup.CurrentPage =  Items.BrowseGroup;
EndProcedure

// StandardSubsystems.Properties

&AtClient
Процедура Attachable_EditPropertyContent()
	
	PropertyManagementClient.EditPropertyContent(ThisObject, Object.Ref);
	
КонецПроцедуры

&AtServer
Процедура UpdateAdditionalAttributeItems()
	
     PropertyManagement.UpdateAdditionalAttributeItems(ThisObject);
	 
КонецПроцедуры

// End StandardSubsystems.Properties

// StandardSubsystems.Print
&AtClient
Процедура Attachable_ExecutePrintCommand(Command)
	
    PrintManagementClient.RunAttachablePrintCommand(Command, ThisObject, Object);
	
КонецПроцедуры

// End StandardSubsystems.Print
