// Barcode image generation For the specified object
// 
// Parameters: 
//  No 
// 
// Returns: 
//  Picture - Picture with the generated barcode or Undefined
Function GetBarcodePicture()

	// Attaching the corresponding add-in depending on the platform type
	AttachAddIn("CommonTemplate.PrintBarcodesAddIn", "BarcodeIcon", AddInType.Native);
	

	// Creating the Add-in object
	Component = New("AddIn.BarcodeIcon.Barcode");

	// If no possibility to paint
	If Not Component.GraphicsPresent Then

		// Then cannot generate a picture
		Return Undefined;

	EndIf;

	// If the system has the Tahoma font installed
	If Component.FindFont("Tahoma") = True Then

		// Choosing it as the Font for the picture generation
		Component.Font = "Tahoma";

	Else

		// Tahoma Font is not found in the system

		// Walking through all available to the component fonts
		For Cnt = 0 To Component.FontsCount -1 Do

			// Getting the next available to the component font
			CurrentFont = Component.FontByIndex(Cnt);

			// If the font is not available
			If CurrentFont <> Undefined Then

				// This will be a font for the barcode generation
				Component.Font = CurrentFont;
				Break;

			EndIf;

		EndDo;

	EndIf;

	// Setting the font size
	Component.FontSize = 12;

	// Adjusting the picture size
	Component.Width = 100;
	Component.Height = 90;

	// Allowing the component to determine the code type
	Component.CodeAuto = True;
	// OR setting the EAN-13 code
	// Component.CodeType = 1;
	//
	// See the type in the documentation for the add-in

	// If the code contains a control character, it is a must to define this
	Component.CodeShowCS = StrLen(ThisObject.Barcode) = 13;

	// If it is not required to show the control character
	// Component.CSVisibility = False;

	// Creating the barcode picture
	Component.CodeValue = ThisObject.Barcode;

	// If we set the width, which is less, than the minimum allowed for this barcode
	If Component.Width < Component.CodeMinWidth Then

		// Adjusting the width
		Component.Width = Component.CodeMinWidth + 10;

	EndIf;

	// Generating a picture
	PictureBinaryData = Component.GetBarcode();

	// If the picture is generated
	If Not PictureBinaryData = Undefined Then

		// Generating from the binary data
		Return New Picture(PictureBinaryData);

	EndIf;

	Return Undefined;

EndFunction

// The barcode printed form generation
//
// Parameters:
//  SpreadsheetDocument - spreadsheet document, the barcode put to
//
// Returns:
//  No
Procedure BarcodePrintForm(SpreadsheetDocument) Export

	// Get the template for the barcode
	Template = Catalogs.Products.GetTemplate("BarcodePrintTemplate");

	// Filling with the object attributes
	Header = Template.GetArea("Header");
	Header.Parameters.Fill(ThisObject);

	// Generating the barcode picture
	BarcodeIcon = GetBarcodePicture();

	// If could generate it
	If Not BarcodeIcon = Undefined Then

		// Putting it into the spreadsheet document
		Picture = Header.Area("Picture");
		Picture.Picture = BarcodeIcon;

	EndIf;

	// Putting the generated result to the resulting to the spreadsheet document
	SpreadsheetDocument.Put(Header);

EndProcedure