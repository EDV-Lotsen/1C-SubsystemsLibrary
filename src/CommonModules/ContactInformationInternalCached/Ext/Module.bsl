////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Contact information subsystem.
// 
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

// Returns an event name for recording to the contact information event log.
//
Function EventLogMessageText() Export
	Return NStr("en='Contact information'", 
		CommonUseClientServer.DefaultLanguageCode() );
EndFunction

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Transformation providers
//

// Transforms a value list, keeping only the last key-value pair values.
//
// Returns:
//     XSLTransform - prepared object.
//
Function XSLT_UniqueByListPresentation() Export
	
	Transformer = New XSLTransform;
	Transformer.LoadFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:tns=""http://v8.1c.ru/8.1/data/core""
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|
		|  <xsl:template match=""node() | @*"">
		|    <xsl:copy>
		|      <xsl:apply-templates select=""node() | @*"" />
		|    </xsl:copy>
		|  </xsl:template>
		|
		|  <xsl:template match=""//tns:ValueListType/tns:item"">
		|    <xsl:variable name=""presentation"" select=""string(tns:presentation)"" />
		|    <xsl:if test=""0=count(following-sibling::tns:item[tns:presentation=$presentation])"" >
		|      <xsl:copy-of select=""."" />
		|    </xsl:if>
		|  </xsl:template>
		|
		|</xsl:stylesheet>
		|");
		
	Return Transformer;
EndFunction

// Transformation used to compare two XML strings.
//
// Returns:
//     XSLTransform - prepared object.
//
Function XSLT_ValueTableDifferencesXML() Export
	Transformer = New XSLTransform;
	
	// The namespace must be empty
	Transformer.LoadFromString("
		|<xsl:stylesheet version=""1.0""
		|  xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance""
		|  xmlns:xs=""http://www.w3.org/2001/XMLSchema""
		|
		|  xmlns:str=""http://exslt.org/strings""
		|  xmlns:exsl=""http://exslt.org/common""
		|
		|  extension-element-prefixes=""str exsl""
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|" + XSLT_StringFunctionTemplates() + "
		|" + XSLT_XPathFunctionTemplates() + "
		|  
		|  <!-- parce tree elements to xpath-value -->
		|  <xsl:template match=""node()"" mode=""action"">
		|    
		|    <xsl:variable name=""text"">
		|      <xsl:call-template name=""str-trim-all"">
		|        <xsl:with-param name=""str"" select=""text()"" />
		|      </xsl:call-template>
		|    </xsl:variable>
		|  
		|    <xsl:if test=""$text!=''"">
		|      <xsl:element name=""item"">
		|        <xsl:attribute name=""path"">
		|          <xsl:variable name=""tmp-path"">
		|            <xsl:call-template name=""build-path"" />
		|          </xsl:variable>
		|          <xsl:value-of select=""substring($tmp-path, 6)"" /> <!-- pass '/dn/f' or '/dn/s' -->
		|        </xsl:attribute>
		|        <xsl:attribute name=""value"">
		|          <xsl:value-of select=""text()"" />
		|        </xsl:attribute>
		|      </xsl:element>
		|    </xsl:if>
		|  
		|    <xsl:apply-templates select=""@* | node()"" mode=""action""/>
		|  </xsl:template>
		|  
		|  <!-- parce tree attributes to xpath-value -->
		|  <xsl:template match=""@*"" mode=""action"">
		|    <xsl:element name=""item"">
		|      <xsl:attribute name=""path"">
		|          <xsl:variable name=""tmp-path"">
		|            <xsl:call-template name=""build-path"" />
		|          </xsl:variable>
		|          <xsl:value-of select=""substring($tmp-path, 6)"" /> <!-- pass '/dn/f' or '/dn/s' -->
		|      </xsl:attribute>
		|      <xsl:attribute name=""value"">
		|        <xsl:value-of select=""."" />
		|      </xsl:attribute>
		|    </xsl:element>
		|  </xsl:template>
		|  
		|  <!-- main -->
		|  <xsl:variable name=""dummy"">
		|    <xsl:element name=""first"">
		|      <xsl:apply-templates select=""/dn/f"" mode=""action"" />
		|    </xsl:element> 
		|    <xsl:element name=""second"">
		|      <xsl:apply-templates select=""/dn/s"" mode=""action"" />
		|    </xsl:element>
		|  </xsl:variable>
		|  <xsl:variable name=""dummy-nodeset"" select=""exsl:node-set($dummy)"" />
		|  <xsl:variable name=""first-items"" select=""$dummy-nodeset/first/item"" />
		|  <xsl:variable name=""second-items"" select=""$dummy-nodeset/second/item"" />
		|  
		|  <xsl:template match=""/"">
		|    
		|    <!-- first vs second -->
		|    <xsl:variable name=""first-second"">
		|      <xsl:for-each select=""$first-items"">
		|        <xsl:call-template name=""compare"">
		|          <xsl:with-param name=""check"" select=""$second-items"" />
		|        </xsl:call-template>
		|      </xsl:for-each>
		|    </xsl:variable>
		|    <xsl:variable name=""first-second-nodeset"" select=""exsl:node-set($first-second)"" />
		|  
		|    <!-- second vs first without doubles -->
		|    <xsl:variable name=""doubles"" select=""$first-second-nodeset/item"" />
		|    <xsl:variable name=""second-first"">
		|      <xsl:for-each select=""$second-items"">
		|        <xsl:call-template name=""compare"">
		|          <xsl:with-param name=""check"" select=""$first-items"" />
		|          <xsl:with-param name=""doubles"" select=""$doubles"" />
		|        </xsl:call-template>
		|      </xsl:for-each>
		|    </xsl:variable>
		|      
		|    <!-- result -->
		|    <ValueTable xmlns=""http://v8.1c.ru/8.1/data/core"" xmlns:xs=""http://www.w3.org/2001/XMLSchema"" xsi:type=""ValueTable"">
		|      <column>
		|        <Name xsi:type=""xs:string"">Path</Name>
		|        <ValueType>
		|           <Type>xs:string</Type>
		|           <StringQualifiers><Length>0</Length><AllowedLength>Variable</AllowedLength></StringQualifiers>
		|        </ValueType>
		|      </column>
		|      <column>
		|        <Name xsi:type=""xs:string"">Value1</Name>
		|        <ValueType>
		|           <Type>xs:string</Type>
		|           <StringQualifiers><Length>0</Length><AllowedLength>Variable</AllowedLength></StringQualifiers>
		|        </ValueType>
		|      </column>
		|      <column>
		|        <Name xsi:type=""xs:string"">Value2</Name>
		|        <ValueType>
		|           <Type>xs:string</Type>
		|           <StringQualifiers><Length>0</Length><AllowedLength>Variable</AllowedLength></StringQualifiers>
		|        </ValueType>
		|      </column>
		|  
		|      <xsl:for-each select=""$first-second-nodeset/item | exsl:node-set($second-first)/item"">
		|        <xsl:element name=""row"">
		|           <xsl:element name=""Value"">
		|             <xsl:value-of select=""@path""/>
		|           </xsl:element>
		|           <xsl:element name=""Value"">
		|             <xsl:value-of select=""@value1""/>
		|           </xsl:element>
		|           <xsl:element name=""Value"">
		|             <xsl:value-of select=""@value2""/>
		|           </xsl:element>
		|        </xsl:element>
		|      </xsl:for-each>
		|  
		|    </ValueTable>
		|  
		|  </xsl:template>
		|  <!-- /main -->
		|  
		|  <!-- compare sub -->
		|  <xsl:template name=""compare"">
		|    <xsl:param name=""check"" />
		|    <xsl:param name=""doubles"" select=""/.."" />
		|    
		|    <xsl:variable name=""path""  select=""@path""/>
		|    <xsl:variable name=""value"" select=""@value""/>
		|    <xsl:variable name=""diff""  select=""$check[@path=$path]""/>
		|    <xsl:choose>
		|      <xsl:when test=""count($diff)=0"">
		|        <xsl:if test=""count($doubles[@path=$path and @value1='' and @value2=$value])=0"">
		|          <xsl:element name=""item"">
		|            <xsl:attribute name=""path"">   <xsl:value-of select=""$path""/> </xsl:attribute>
		|            <xsl:attribute name=""value1""> <xsl:value-of select=""$value""/> </xsl:attribute>
		|            <xsl:attribute name=""value2"" />
		|          </xsl:element>
		|        </xsl:if>
		|      </xsl:when>
		|      <xsl:otherwise>
		|  
		|        <xsl:for-each select=""$diff[@value!=$value]"">
		|            <xsl:variable name=""diff-value"" select=""@value""/>
		|            <xsl:if test=""count($doubles[@path=$path and @value1=$diff-value and @value2=$value])=0"">
		|              <xsl:element name=""item"">
		|                <xsl:attribute name=""path"">   <xsl:value-of select=""$path""/>  </xsl:attribute>
		|                <xsl:attribute name=""value1""> <xsl:value-of select=""$value""/> </xsl:attribute>
		|                <xsl:attribute name=""value2""> <xsl:value-of select=""@value""/> </xsl:attribute>
		|              </xsl:element>
		|            </xsl:if>
		|        </xsl:for-each>
		|      </xsl:otherwise>
		|    </xsl:choose>
		|  </xsl:template>
		|  
		|</xsl:stylesheet>
		|");
		
	Return Transformer;
EndFunction

// Transforms a text containing key-value pairs separated by line breaks (see address format) to an XML string.
// If duplicate keys are encountered, all of them are included in the output but only the last one is used during deserialization, due to platform serialization logic.
//
// Returns:
//     XSLTransform - prepared object.
//
Function XSLT_KeyValueStringToStructure() Export
	Transformer = New XSLTransform;
	Transformer.LoadFromString("
		|<xsl:stylesheet version=""1.0""
		|  xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:str=""http://exslt.org/strings""
		|  extension-element-prefixes=""str""
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|" + XSLT_StringFunctionTemplates() + "
		|
		|  <xsl:template match=""ExternalParamNode"">
		|
		|    <xsl:variable name=""source"">
		|      <xsl:call-template name=""str-replace-all"">
		|        <xsl:with-param name=""str"" select=""."" />
		|        <xsl:with-param name=""search-for"" select=""'&#10;&#09;'"" />
		|        <xsl:with-param name=""replace-by"" select=""'&#13;'"" />
		|      </xsl:call-template>
		|    </xsl:variable>
		|
		|    <Structure xmlns=""http://v8.1c.ru/8.1/data/core"" xmlns:xs=""http://www.w3.org/2001/XMLSchema"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"" xsi:type=""Structure"">
		|
		|     <xsl:for-each select=""str:tokenize($source, '&#10;')"" >
		|       <xsl:if test=""contains(., '=')"">
		|
		|         <xsl:element name=""Property"">
		|           <xsl:attribute name=""name"" >
		|             <xsl:call-template name=""str-trim-all"">
		|               <xsl:with-param name=""str"" select=""substring-before(., '=')"" />
		|             </xsl:call-template>
		|           </xsl:attribute>
		|
		|           <Value xsi:type=""xs:string"">
		|             <xsl:call-template name=""str-replace-all"">
		|               <xsl:with-param name=""str"" select=""substring-after(., '=')"" />
		|               <xsl:with-param name=""search-for"" select=""'&#13;'"" />
		|               <xsl:with-param name=""replace-by"" select=""'&#10;'"" />
		|             </xsl:call-template>
		|           </Value>
		|
		|         </xsl:element>
		|
		|       </xsl:if>
		|     </xsl:for-each>
		|
		|    </Structure>
		|
		|  </xsl:template>
		|
		|</xsl:stylesheet>
		|");

	Return Transformer;
EndFunction

// Transforms a text containing key-value pairs separated by line breaks (see address format) to an XML string.
// If duplicate keys are encountered, all of them are included in the output.
//
// Returns:
//     XSLTransform - prepared object
//
Function XSLT_KeyValueStringToValueList() Export
	Transformer = New XSLTransform;
	Transformer.LoadFromString("
		|<xsl:stylesheet version=""1.0""
		|  xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:str=""http://exslt.org/strings""
		|  extension-element-prefixes=""str""
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|" + XSLT_StringFunctionTemplates() + "
		|
		|  <xsl:template match=""ExternalParamNode"">
		|
		|    <xsl:variable name=""source"">
		|      <xsl:call-template name=""str-replace-all"">
		|        <xsl:with-param name=""str"" select=""."" />
		|        <xsl:with-param name=""search-for"" select=""'&#10;&#09;'"" />
		|        <xsl:with-param name=""replace-by"" select=""'&#13;'"" />
		|      </xsl:call-template>
		|    </xsl:variable>
		|
		|    <ValueListType xmlns=""http://v8.1c.ru/8.1/data/core"" xmlns:xs=""http://www.w3.org/2001/XMLSchema"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"" xsi:type=""ValueListType"">
		|    <valueType/>
		|
		|      <xsl:for-each select=""str:tokenize($source, '&#10;')"" >
		|        <xsl:if test=""contains(., '=')"">
		|
		|          <item>
		|            <value xsi:type=""xs:string"">
		|              <xsl:call-template name=""str-replace-all"">
		|                <xsl:with-param name=""str"" select=""substring-after(., '=')"" />
		|                <xsl:with-param name=""search-for"" select=""'&#13;'"" />
		|                <xsl:with-param name=""replace-by"" select=""'&#10;'"" />
		|              </xsl:call-template>
		|            </value>
		|            <presentation>
		|              <xsl:call-template name=""str-trim-left"">
		|                <xsl:with-param name=""str"" select=""substring-before(., '=')"" />
		|              </xsl:call-template>
		|            </presentation>
		|          </item>
		|
		|        </xsl:if>
		|      </xsl:for-each>
		|
		|    </ValueListType >
		|
		|  </xsl:template>
		|
		|</xsl:stylesheet>
		|");

	Return Transformer;
EndFunction

// Transforms a value list to a string containing key-value pairs separated by line breaks.
//
// Returns:
//     XSLTransform - prepared object.
//
Function XSLT_ValueListToKeyValueString() Export
	Transformer = New XSLTransform;
	Transformer.LoadFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:tns=""http://v8.1c.ru/8.1/data/core""
		|>
		|<xsl:output method=""text"" encoding=""utf-8""/>
		|" + XSLT_StringFunctionTemplates() + "
		|  
		|  <xsl:template match=""/"">
		|    <xsl:apply-templates select=""//tns:ValueListType/tns:item"" />
		|  </xsl:template>
		|  
		|  <xsl:template match=""//tns:ValueListType/tns:item"">
		|
		|    <xsl:call-template name=""str-trim-all"">
		|      <xsl:with-param name=""str"" select=""tns:presentation"" />
		|    </xsl:call-template>
		|    <xsl:text/>=<xsl:text/>
		|
		|    <xsl:call-template name=""str-replace-all"">
		|      <xsl:with-param name=""str"" select=""tns:value"" />
		|      <xsl:with-param name=""search-for"" select=""'&#10;'"" />
		|      <xsl:with-param name=""replace-by"" select=""'&#10;&#09;'"" />
		|    </xsl:call-template>
		|
		|    <xsl:if test=""position()!=last()"">
		|      <xsl:text/>
		|        <xsl:value-of select=""'&#10;'""/>
		|      <xsl:text/>
		|    </xsl:if>
		|  </xsl:template>
		|
		|</xsl:stylesheet>
		|");
	Return Transformer;
EndFunction

// Transforms a structure to a string containing key-value pairs separated by line breaks.
//
// Returns:
//     XSLTransform - prepared object.
//
Function XSLT_StructureToKeyValueString() Export
	Transformer = New XSLTransform;
	Transformer.LoadFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:tns=""http://v8.1c.ru/8.1/data/core""
		|>
		|<xsl:output method=""text"" encoding=""utf-8""/>
		|" + XSLT_StringFunctionTemplates() + "
		|
		|  <xsl:template match=""/"">
		|    <xsl:apply-templates select=""//tns:Structure/tns:Property"" />
		|  </xsl:template>
		|
		|  <xsl:template match=""//tns:Property"">
		|
		|    <xsl:value-of select=""@name"" />
		|    <xsl:text/>=<xsl:text/>
		|
		|    <xsl:call-template name=""str-replace-all"">
		|      <xsl:with-param name=""str"" select=""tns:Value"" />
		|      <xsl:with-param name=""search-for"" select=""'&#10;'"" />
		|      <xsl:with-param name=""replace-by"" select=""'&#10;&#09;'"" />
		|    </xsl:call-template>
		|
		|    <xsl:if test=""position()!=last()"">
		|      <xsl:text/>
		|        <xsl:value-of select=""'&#10;'""/>
		|      <xsl:text/>
		|    </xsl:if>
		|  </xsl:template>
		|</xsl:stylesheet>
		|");
	Return Transformer;
EndFunction

// Transforms a value list to a structure. Transforms presentation to key.
//
// Returns:
//     XSLTransform - prepared object.
//
Function XSLT_ValueListToStructure() Export
	Transformer = New XSLTransform;
	Transformer.LoadFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance""
		|  xmlns:tns=""http://v8.1c.ru/8.1/data/core""
		|  xmlns=""http://v8.1c.ru/8.1/data/core""
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|" + XSLT_StringFunctionTemplates() + "
		|
		|  <xsl:template match=""/"">
		|    <Structure xmlns=""http://v8.1c.ru/8.1/data/core"" xmlns:xs=""http://www.w3.org/2001/XMLSchema"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"" xsi:type=""Structure"">
		|      <xsl:apply-templates select=""//tns:ValueListType/tns:item"" />
		|    </Structure >
		|  </xsl:template>
		|
		|  <xsl:template match=""//tns:ValueListType/tns:item"">
		|    <xsl:element name=""Property"">
		|      <xsl:attribute name=""name"">
		|        <xsl:call-template name=""str-trim-all"">
		|          <xsl:with-param name=""str"" select=""tns:presentation"" />
		|        </xsl:call-template>
		|      </xsl:attribute>
		|
		|      <xsl:element name=""Value"">
		|        <xsl:attribute name=""xsi:type"">
		|          <xsl:value-of select=""tns:value/@xsi:type""/>  
		|        </xsl:attribute>
		|        <xsl:value-of select=""tns:value""/>  
		|      </xsl:element>
		|
		|    </xsl:element>
		|</xsl:template>
		|
		|</xsl:stylesheet>
		|");
	Return Transformer;
EndFunction

// Transforms a structure to a value list. Transforms key to presentation.
//
// Returns:
//     XSLTransform - prepared object.
//
Function XSLT_StructureToValueList() Export
	Transformer = New XSLTransform;
	Transformer.LoadFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance""
		|  xmlns:tns=""http://v8.1c.ru/8.1/data/core""
		|  xmlns=""http://v8.1c.ru/8.1/data/core""
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|" + XSLT_StringFunctionTemplates() + "
		|
		|  <xsl:template match=""/"">
		|    <ValueListType xmlns=""http://v8.1c.ru/8.1/data/core"" xmlns:xs=""http://www.w3.org/2001/XMLSchema"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"" xsi:type=""ValueListType"">
		|      <valueType/>
		|        <xsl:apply-templates select=""//tns:Structure/tns:Property"" />
		|    </ValueListType>
		|  </xsl:template>
		|
		|  <xsl:template match=""//tns:Property"">
		|    <item>
		|      <value xsi:type=""xs:string"">
		|        <xsl:value-of select=""tns:Value"" />
		|      </value>
		|      <presentation>
		|        <xsl:value-of select=""@name"" />
		|      </presentation>
		|    </item>
		|  </xsl:template>
		|
		|</xsl:stylesheet>
		|");
	Return Transformer;
EndFunction

// Transforms a map to a structure. Transforms key to key, value to value.
//
// Returns:
//     XSLTransform - prepared object.
//
Function XSLT_MapToStructure() Export
	Transformer = New XSLTransform;
	Transformer.LoadFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance""
		|  xmlns:tns=""http://v8.1c.ru/8.1/data/core""
		|  xmlns=""http://v8.1c.ru/8.1/data/core""
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|" + XSLT_StringFunctionTemplates() + "
		|
		|  <xsl:template match=""/"">
		|    <Structure xmlns=""http://v8.1c.ru/8.1/data/core"" xmlns:xs=""http://www.w3.org/2001/XMLSchema"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"" xsi:type=""Structure"">
		|      <xsl:apply-templates select=""//tns:Map/tns:pair"" />
		|    </Structure >
		|  </xsl:template>
		|  
		|  <xsl:template match=""//tns:Map/tns:pair"">
		|  <xsl:element name=""Property"">
		|    <xsl:attribute name=""name"">
		|      <xsl:call-template name=""str-trim-all"">
		|        <xsl:with-param name=""str"" select=""tns:Key"" />
		|      </xsl:call-template>
		|    </xsl:attribute>
		|  
		|    <xsl:element name=""Value"">
		|      <xsl:attribute name=""xsi:type"">
		|        <xsl:value-of select=""tns:Value/@xsi:type""/>  
		|      </xsl:attribute>
		|        <xsl:value-of select=""tns:Value""/>  
		|      </xsl:element>
		|  
		|    </xsl:element>
		|  </xsl:template>
		|
		|</xsl:stylesheet>
		|");
	Return Transformer;
EndFunction

// Deletes <?xml...> description from an XML string to be inserted into another XML string.
//
// Returns:
//     XSLTransform - prepared object.
//
Function XSLT_DeleteDescriptionXML() Export
	Transformer = New XSLTransform;
	Transformer.LoadFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform"">
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|  <xsl:template match=""node() | @*"">
		|    <xsl:copy>
		|      <xsl:apply-templates select=""node() | @*"" />
		|    </xsl:copy>
		|  </xsl:template>
		|</xsl:stylesheet>
		|");
	Return Transformer;
EndFunction

// Transforms an XML string containing contact information (see "Contact information" XDTO package) to ContactInformationType enumeration.
//
// Returns:
//     XSLTransform - prepared object.
//
Function XSLT_ContactInformationTypeByXMLString() Export
	Transformer = New XSLTransform;
	Transformer.LoadFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance""
		|  xmlns:ci=""http://www.v8.1c.ru/ssl/contactinfo""
		|>
		|  <xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|
		|  <xsl:template match=""/"">
		|    <EnumRef.ContactInformationTypes xmlns=""http://v8.1c.ru/8.1/data/enterprise/current-config"" xmlns:xs=""http://www.w3.org/2001/XMLSchema"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"" xsi:type=""EnumRef.ContactInformationTypes"">
		|      <xsl:call-template name=""enum-by-type"" >
		|        <xsl:with-param name=""type"" select=""ci:ContactInformation/ci:Content/@xsi:type"" />
		|      </xsl:call-template>
		|    </EnumRef.ContactInformationTypes>
		|  </xsl:template>
		|
		|  <xsl:template name=""enum-by-type"">
		|    <xsl:param name=""type"" />
		|    <xsl:choose>
		|      <xsl:when test=""$type='Address'"">
		|        <xsl:text>Address</xsl:text>
		|      </xsl:when>
		|      <xsl:when test=""$type='PhoneNumber'"">
		|        <xsl:text>Phone</xsl:text>
		|      </xsl:when>
		|      <xsl:when test=""$type='FaxNumber'"">
		|        <xsl:text>Fax</xsl:text>
		|      </xsl:when>
		|      <xsl:when test=""$type='Email'"">
		|        <xsl:text>EmailAddress</xsl:text>
		|      </xsl:when>
		|      <xsl:when test=""$type='Website'"">
		|        <xsl:text>WebPage</xsl:text>
		|      </xsl:when>
		|      <xsl:when test=""$type='Other'"">
		|        <xsl:text>Other</xsl:text>
		|      </xsl:when>
		|    </xsl:choose>
		|  </xsl:template>
		|
		|</xsl:stylesheet>
		|");
	Return Transformer;
EndFunction

// Transforms an XML string containing a difference table depending on contact information type.
//
// Parameters:
//    ContactInformationType - String, EnumRef.ContactInformationTypes - name or enumeration value.
//
// Returns:
//     XSLTransform - prepared object.
//
Function XSLT_ContactInformationXMLDifferenceInterpretation(Val ContactInformationType) Export
	
	If TypeOf(ContactInformationType) <> Type("String") Then
		ContactInformationType = ContactInformationType.Metadata().Name;
	EndIf;
	
	Transformer = New XSLTransform;
	Transformer.LoadFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance""
		|  xmlns:ci=""http://www.v8.1c.ru/ssl/contactinfo""
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|  <xsl:param name=""target-type"" select=""'" + ContactInformationType + "'""/>
		|
		|  <xsl:template match=""/"">
		|    <xsl:choose>
		|      <xsl:when test=""$target-type='Address'"">
		|         <xsl:apply-templates select=""."" mode=""action-address""/>
		|      </xsl:when>
		|      <xsl:otherwise>
		|         <xsl:apply-templates select=""."" mode=""action-copy""/>
		|      </xsl:otherwise>
		|    </xsl:choose>
		|  </xsl:template>
		|
		|  <xsl:template match=""node() | @*"" mode=""action-copy"">
		|    <xsl:copy>
		|      <xsl:apply-templates select=""node() | @*"" mode=""action-copy""/>
		|    </xsl:copy>
		|  </xsl:template>
		|
		|  <xsl:template match=""node() | @*"" mode=""action-address"">
		|    <xsl:copy>
		|      <xsl:apply-templates select=""node() | @*"" mode=""action-address""/>
		|    </xsl:copy>
		|  </xsl:template>
		|
		|</xsl:stylesheet>
		|");
	Return Transformer;
EndFunction

// Transforms a serialized structure to contact information XML string.
//
// Returns:
//     XSLTransform - prepared object.
//
Function XSLT_StructureToAddress() Export
	
	AdditionalAddressItemCodes = New TextDocument;
	For Each AdditionalAddressItem In ContactInformationClientServerCached.AddressingObjectTypesNationalAddresses() Do
		AdditionalAddressItemCodes.AddLine("<data:item data:title=""" + AdditionalAddressItem.Description + """>" + AdditionalAddressItem.Code + "</data:item>");
	EndDo;
	
	StateCodes = New TextDocument;
	AllStates = ContactInformationInternal.AllStates();
	If AllStates <> Undefined Then
		For Each Row In AllStates Do
			StateCodes.AddLine("<data:item data:code=""" + Format(Row.Code, "NZ=; NG=") + """>" + Row.Presentation + "</data:item>");
		EndDo;
	EndIf;
	
	Transformer = New XSLTransform;
	Transformer.LoadFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance""
		|  xmlns:xs=""http://www.w3.org/2001/XMLSchema""
		|  xmlns:tns=""http://v8.1c.ru/8.1/data/core""
		|  xmlns=""http://www.v8.1c.ru/ssl/contactinfo"" 
		|
		|  xmlns:data=""http://www.v8.1c.ru/ssl/contactinfo""
		|
		|  xmlns:exsl=""http://exslt.org/common""
		|  extension-element-prefixes=""exsl""
		|  exclude-result-prefixes=""data tns""
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|  " + XSLT_StringFunctionTemplates() + "
		|  
		|  <xsl:variable name=""local-country"">US</xsl:variable>
		|
		|  <xsl:variable name=""presentation"" select=""tns:Structure/tns:Property[@name='Presentation']/tns:Value/text()"" />
		|  
		|  <xsl:template match=""/"">
		|    <ContactInformation>
		|
		|      <xsl:attribute name=""Presentation"">
		|        <xsl:value-of select=""$presentation""/>
		|      </xsl:attribute> 
		|      <xsl:element name=""Comment"">
		|       <xsl:value-of select=""tns:Structure/tns:Property[@name='Comment']/tns:Value/text()""/>
		|      </xsl:element>
		|
		|      <xsl:element name=""Content"">
		|        <xsl:attribute name=""xsi:type"">Address</xsl:attribute>
		|        <xsl:variable name=""country"" select=""tns:Structure/tns:Property[@name='Country']/tns:Value/text()""></xsl:variable>
		|        <xsl:variable name=""country-upper"">
		|          <xsl:call-template name=""str-upper"">
		|            <xsl:with-param name=""str"" select=""$country"" />
		|          </xsl:call-template>
		|        </xsl:variable>
		|
		|        <xsl:attribute name=""Country"">
		|          <xsl:choose>
		|            <xsl:when test=""0=count($country)"">
		|              <xsl:value-of select=""$local-country"" />
		|            </xsl:when>
		|            <xsl:otherwise>
		|              <xsl:value-of select=""$country"" />
		|            </xsl:otherwise> 
		|          </xsl:choose>
		|        </xsl:attribute>
		|
		|        <xsl:choose>
		|          <xsl:when test=""0=count($country)"">
		|            <xsl:apply-templates select=""/"" mode=""domestic"" />
		|          </xsl:when>
		|          <xsl:when test=""$country-upper=$local-country"">
		|            <xsl:apply-templates select=""/"" mode=""domestic"" />
		|          </xsl:when>
		|          <xsl:otherwise>
		|            <xsl:apply-templates select=""/"" mode=""foreign"" />
		|          </xsl:otherwise> 
		|        </xsl:choose>
		|
		|      </xsl:element>
		|    </ContactInformation>
		|  </xsl:template>
		|  
		|  <xsl:template match=""/"" mode=""foreign"">
		|    <xsl:element name=""Content"">
		|      <xsl:attribute name=""xsi:type"">xs:string</xsl:attribute>
		|
		|      <xsl:variable name=""value"" select=""tns:Structure/tns:Property[@name='Value']/tns:Value/text()"" />        
		|      <xsl:choose>
		|        <xsl:when test=""0=count($value)"">
		|          <xsl:value-of select=""$presentation"" />
		|        </xsl:when>
		|        <xsl:otherwise>
		|          <xsl:value-of select=""$value"" />
		|        </xsl:otherwise> 
		|      </xsl:choose>
		|    
		|    </xsl:element>
		|  </xsl:template>
		|  
		|  <xsl:template match=""/"" mode=""domestic"">
		|    <xsl:element name=""Content"">
		|      <xsl:attribute name=""xsi:type"">AddressUS</xsl:attribute>
		|    
		|      <xsl:element name=""Region"">
		|        <xsl:variable name=""value"" select=""tns:Structure/tns:Property[@name='State']/tns:Value/text()"" />
		|
		|        <xsl:choose>
		|          <xsl:when test=""0=count($value)"">
		|            <xsl:variable name=""regioncode"" select=""tns:Structure/tns:Property[@name='StateCode']/tns:Value/text()""/>
		|            <xsl:variable name=""regiontitle"" select=""$enum-regioncode-nodes/data:item[@data:code=number($regioncode)]"" />
		|              <xsl:if test=""0!=count($regiontitle)"">
		|                <xsl:value-of select=""$regiontitle""/>
		|              </xsl:if>
		|          </xsl:when>
		|          <xsl:otherwise>
		|            <xsl:value-of select=""$value"" />
		|          </xsl:otherwise> 
		|        </xsl:choose>
		|
		|      </xsl:element>
		|   
		|      <xsl:element name=""CountyMunicipalEntity"">
		|        <xsl:element name=""County"">
		|          <xsl:value-of select=""tns:Structure/tns:Property[@name='County']/tns:Value/text()""/>
		|        </xsl:element>
		|      </xsl:element>
		|  
		|      <xsl:element name=""City"">
		|        <xsl:value-of select=""tns:Structure/tns:Property[@name='City']/tns:Value/text()""/>
		|      </xsl:element>
		|    
		|      <xsl:element name=""Settlement"">
		|        <xsl:value-of select=""tns:Structure/tns:Property[@name='Settlement']/tns:Value/text()""/>
		|      </xsl:element>
		|
		|      <xsl:element name=""Street"">
		|        <xsl:value-of select=""tns:Structure/tns:Property[@name='Street']/tns:Value/text()""/>
		|      </xsl:element>
		|
		|      <xsl:variable name=""index"" select=""tns:Structure/tns:Property[@name='Index']/tns:Value/text()"" />
		|      <xsl:if test=""0!=count($index)"">
		|        <xsl:element name=""AdditionalAddressItem"">
		|          <xsl:attribute name=""AddressItemType"">" + ContactInformationClientServerCached.PostalCodeSerializationCode() + "</xsl:attribute>
		|          <xsl:attribute name=""Value""><xsl:value-of select=""$index""/></xsl:attribute>
		|        </xsl:element>
		|      </xsl:if>
		|
		|      <xsl:call-template name=""add-elem-number"">
		|        <xsl:with-param name=""source"" select=""tns:Structure/tns:Property[@name='BuildingType']/tns:Value/text()"" />
		|        <xsl:with-param name=""defsrc"" select=""'Building'"" />
		|        <xsl:with-param name=""value""  select=""tns:Structure/tns:Property[@name='Building']/tns:Value/text()"" />
		|      </xsl:call-template>
		|
		|      <xsl:call-template name=""add-elem-number"">
		|        <xsl:with-param name=""source"" select=""tns:Structure/tns:Property[@name='UnitType']/tns:Value/text()"" />
		|        <xsl:with-param name=""defsrc"" select=""'Unit'"" />
		|        <xsl:with-param name=""value""  select=""tns:Structure/tns:Property[@name='Unit']/tns:Value/text()"" />
		|      </xsl:call-template>
		|
		|      <xsl:call-template name=""add-elem-number"">
		|        <xsl:with-param name=""source"" select=""tns:Structure/tns:Property[@name='ApartmentType']/tns:Value/text()"" />
		|        <xsl:with-param name=""defsrc"" select=""'Apartment'"" />
		|        <xsl:with-param name=""value""  select=""tns:Structure/tns:Property[@name='Apartment']/tns:Value/text()"" />
		|      </xsl:call-template>
		|    
		|    </xsl:element>
		|  </xsl:template>
		|
		|  <xsl:param name=""enum-codevalue"">
		|" + AdditionalAddressItemCodes.GetText() + "
		|  </xsl:param>
		|  <xsl:variable name=""enum-codevalue-nodes"" select=""exsl:node-set($enum-codevalue)"" />
		|
		|  <xsl:param name=""enum-regioncode"">
		|" + StateCodes.GetText() + "
		|  </xsl:param>
		|  <xsl:variable name=""enum-regioncode-nodes"" select=""exsl:node-set($enum-regioncode)"" />
		|  
		|  <xsl:template name=""add-elem-number"">
		|    <xsl:param name=""source"" />
		|    <xsl:param name=""defsrc"" />
		|    <xsl:param name=""value"" />
		|  
		|    <xsl:if test=""0!=count($value)"">
		|  
		|      <xsl:choose>
		|        <xsl:when test=""0!=count($source)"">
		|          <xsl:variable name=""type-code"" select=""$enum-codevalue-nodes/data:item[@data:title=$source]"" />
		|          <xsl:element name=""AdditionalAddressItem"">
		|            <xsl:element name=""Number"">
		|              <xsl:attribute name=""Type""><xsl:value-of select=""$type-code"" /></xsl:attribute>
		|              <xsl:attribute name=""Value""><xsl:value-of select=""$value""/></xsl:attribute>
		|            </xsl:element>
		|          </xsl:element>
		|  
		|        </xsl:when>
		|        <xsl:otherwise>
		|          <xsl:variable name=""type-code"" select=""$enum-codevalue-nodes/data:item[@data:title=$defsrc]"" />
		|          <xsl:element name=""AdditionalAddressItem"">
		|            <xsl:element name=""Number"">
		|              <xsl:attribute name=""Type""><xsl:value-of select=""$type-code"" /></xsl:attribute>
		|              <xsl:attribute name=""Value""><xsl:value-of select=""$value""/></xsl:attribute>
		|            </xsl:element>
		|          </xsl:element>
		|  
		|        </xsl:otherwise>
		|      </xsl:choose>
		|  
		|    </xsl:if>
		|  
		|  </xsl:template>
		|  
		|</xsl:stylesheet>
		|");
	Return Transformer;
EndFunction

// Transforms a serialized structure to contact information XML string.
//
// Returns:
//     XSLTransform - prepared object.
//
Function XSLT_StructureToEmailAddress() Export
	Return XSLT_StructureToStringContent("Email");
EndFunction

// Transforms a serialized structure to contact information XML string.
//
// Returns:
//     XSLTransform - prepared object.
//
Function XSLT_StructureToWebPage() Export
	Return XSLT_StructureToStringContent("Website");
EndFunction

// Transforms a serialized structure to contact information XML string.
//
// Returns:
//     XSLTransform - prepared object.
//
Function XSLT_StructureToPhone() Export
	Return XSLT_StructureToPhoneFax("PhoneNumber");
EndFunction

// Transforms a serialized structure to contact information XML string.
//
// Returns:
//     XSLTransform - prepared object.
//
Function XSLT_StructureToFax() Export
	Return XSLT_StructureToPhoneFax("FaxNumber");
EndFunction

// Transforms a serialized structure to contact information XML string.
//
// Returns:
//     XSLTransform - prepared object.
//
Function XSLT_StructureToOther() Export
	Return XSLT_StructureToStringContent("Others");
EndFunction

// General transformation of a serialized structure to contact information XML string of simple type.
//
// Returns:
//     XSLTransform - prepared object.
//
Function XSLT_StructureToStringContent(Val XDTOTypeName)
	Transformer = New XSLTransform;
	Transformer.LoadFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance""
		|  xmlns:tns=""http://v8.1c.ru/8.1/data/core""
		|  xmlns=""http://www.v8.1c.ru/ssl/contactinfo"" 
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|  
		|<xsl:template match=""/"">
		|  
		|  <xsl:element name=""ContactInformation"">
		|  
		|  <xsl:attribute name=""Presentation"">
		|    <xsl:value-of select=""tns:Structure/tns:Property[@name='Presentation']/tns:Value/text()""/>
		|  </xsl:attribute> 
		|  <xsl:element name=""Comment"">
		|    <xsl:value-of select=""tns:Structure/tns:Property[@name='Comment']/tns:Value/text()""/>
		|  </xsl:element>
		|  
		|  <xsl:element name=""Content"">
		|    <xsl:attribute name=""xsi:type"">" + XDTOTypeName + "</xsl:attribute>
		|    <xsl:attribute name=""Value"">
		|    <xsl:choose>
		|      <xsl:when test=""0=count(tns:Structure/tns:Property[@name='Value'])"">
		|      <xsl:value-of select=""tns:Structure/tns:Property[@name='Presentation']/tns:Value/text()""/>
		|      </xsl:when>
		|      <xsl:otherwise>
		|      <xsl:value-of select=""tns:Structure/tns:Property[@name='Value']/tns:Value/text()""/>
		|      </xsl:otherwise>
		|    </xsl:choose>
		|    </xsl:attribute>
		|    
		|  </xsl:element>
		|  </xsl:element>
		|  
		|</xsl:template>
		|</xsl:stylesheet>
		|");
	Return Transformer;
EndFunction

// General transformation of phone and fax numbers.
//
// Returns:
//     XSLTransform - prepared object.
//
Function XSLT_StructureToPhoneFax(Val XDTOTypeName) Export
	Transformer = New XSLTransform;
	Transformer.LoadFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance""
		|  xmlns:tns=""http://v8.1c.ru/8.1/data/core""
		|  xmlns=""http://www.v8.1c.ru/ssl/contactinfo"" 
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|  <xsl:template match=""/"">
		|
		|    <xsl:element name=""ContactInformation"">
		|
		|      <xsl:attribute name=""Presentation"">
		|        <xsl:value-of select=""tns:Structure/tns:Property[@name='Presentation']/tns:Value/text()""/>
		|      </xsl:attribute> 
		|      <xsl:element name=""Comment"">
		|        <xsl:value-of select=""tns:Structure/tns:Property[@name='Comment']/tns:Value/text()""/>
		|      </xsl:element>
		|      <xsl:element name=""Content"">
		|        <xsl:attribute name=""xsi:type"">" + XDTOTypeName + "</xsl:attribute>
		|
		|        <xsl:attribute name=""CountryCode"">
		|          <xsl:value-of select=""tns:Structure/tns:Property[@name='CountryCode']/tns:Value/text()""/>
		|        </xsl:attribute> 
		|        <xsl:attribute name=""AreaCode"">
		|          <xsl:value-of select=""tns:Structure/tns:Property[@name='AreaCode']/tns:Value/text()""/>
		|        </xsl:attribute> 
		|        <xsl:attribute name=""Number"">
		|          <xsl:value-of select=""tns:Structure/tns:Property[@name='PhoneNumber']/tns:Value/text()""/>
		|        </xsl:attribute> 
		|        <xsl:attribute name=""Extension"">
		|          <xsl:value-of select=""tns:Structure/tns:Property[@name='Extension']/tns:Value/text()""/>
		|        </xsl:attribute> 
		|
		|      </xsl:element>
		|    </xsl:element>
		|
		|  </xsl:template>
		|</xsl:stylesheet>
		|");
	Return Transformer;
EndFunction

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Library methods for XSL transformations. Intended for imitation of <xsl:include href="..."/>
//

// XSL fragment including string processing procedures.
//
// Returns:
//     String - XML fragment to be used in a transformation.
//
Function XSLT_StringFunctionTemplates()
	Return "
		|<!-- string functions -->
		|
		|  <xsl:template name=""str-trim-left"">
		|    <xsl:param name=""str"" />
		|    <xsl:variable name=""head"" select=""substring($str, 1, 1)""/>
		|    <xsl:variable name=""tail"" select=""substring($str, 2)""/>
		|    <xsl:choose>
		|      <xsl:when test=""(string-length($str) > 0) and (string-length(normalize-space($head)) = 0)"">
		|        <xsl:call-template name=""str-trim-left"">
		|          <xsl:with-param name=""str"" select=""$tail""/>
		|        </xsl:call-template>
		|      </xsl:when>
		|      <xsl:otherwise>
		|        <xsl:value-of select=""$str""/>
		|      </xsl:otherwise>
		|    </xsl:choose>
		|  </xsl:template>
		|
		|  <xsl:template name=""str-trim-right"">
		|    <xsl:param name=""str"" />
		|    <xsl:variable name=""head"" select=""substring($str, 1, string-length($str) - 1)""/>
		|    <xsl:variable name=""tail"" select=""substring($str, string-length($str))""/>
		|    <xsl:choose>
		|      <xsl:when test=""(string-length($str) > 0) and (string-length(normalize-space($tail)) = 0)"">
		|        <xsl:call-template name=""str-trim-right"">
		|          <xsl:with-param name=""str"" select=""$head""/>
		|        </xsl:call-template>
		|      </xsl:when>
		|      <xsl:otherwise>
		|        <xsl:value-of select=""$str""/>
		|      </xsl:otherwise>
		|    </xsl:choose>
		|  </xsl:template>
		|
		|  <xsl:template name=""str-trim-all"">
		|    <xsl:param name=""str"" />
		|      <xsl:call-template name=""str-trim-right"">
		|        <xsl:with-param name=""str"">
		|          <xsl:call-template name=""str-trim-left"">
		|            <xsl:with-param name=""str"" select=""$str""/>
		|          </xsl:call-template>
		|      </xsl:with-param>
		|    </xsl:call-template>
		|  </xsl:template>
		|
		|  <xsl:template name=""str-replace-all"">
		|    <xsl:param name=""str"" />
		|    <xsl:param name=""search-for"" />
		|    <xsl:param name=""replace-by"" />
		|    <xsl:choose>
		|      <xsl:when test=""contains($str, $search-for)"">
		|        <xsl:value-of select=""substring-before($str, $search-for)"" />
		|        <xsl:value-of select=""$replace-by"" />
		|        <xsl:call-template name=""str-replace-all"">
		|          <xsl:with-param name=""str"" select=""substring-after($str, $search-for)"" />
		|          <xsl:with-param name=""search-for"" select=""$search-for"" />
		|          <xsl:with-param name=""replace-by"" select=""$replace-by"" />
		|        </xsl:call-template>
		|      </xsl:when>
		|      <xsl:otherwise>
		|        <xsl:value-of select=""$str"" />
		|      </xsl:otherwise>
		|    </xsl:choose>
		|  </xsl:template>
		|
		|  <xsl:param name=""alpha-low"" select=""'abcdefghijklmnopqrstuvwxyz'"" />
		|  <xsl:param name=""alpha-up""  select=""'ABCDEFGHIJKLMNOPQRSTUVWXYZ'"" />
		|
		|  <xsl:template name=""str-upper"">
		|    <xsl:param name=""str"" />
		|    <xsl:value-of select=""translate($str, $alpha-low, $alpha-up)""/>
		|  </xsl:template>
		|
		|  <xsl:template name=""str-lower"">
		|    <xsl:param name=""str"" />
		|    <xsl:value-of select=""translate($str, alpha-up, $alpha-low)"" />
		|  </xsl:template>
		|
		|<!-- /string functions -->
		|";
EndFunction

// XSL fragment including xpath management procedures.
//
// Returns:
//     String - XML fragment to be used in a transformation.
//
Function XSLT_XPathFunctionTemplates()
	Return "
		|<!-- path functions -->
		|
		|  <xsl:template name=""build-path"">
		|  <xsl:variable name=""node"" select="".""/>
		|
		|    <xsl:for-each select=""$node | $node/ancestor-or-self::node()[..]"">
		|      <xsl:choose>
		|        <!-- element -->
		|        <xsl:when test=""self::*"">
		|            <xsl:value-of select=""'/'""/>
		|            <xsl:value-of select=""name()""/>
		|            <xsl:variable name=""thisPosition"" select=""count(preceding-sibling::*[name(current()) = name()])""/>
		|            <xsl:variable name=""numFollowing"" select=""count(following-sibling::*[name(current()) = name()])""/>
		|            <xsl:if test=""$thisPosition + $numFollowing > 0"">
		|              <xsl:value-of select=""concat('[', $thisPosition +1, ']')""/>
		|            </xsl:if>
		|        </xsl:when>
		|        <xsl:otherwise>
		|          <!-- not element -->
		|          <xsl:choose>
		|            <!-- attribute -->
		|            <xsl:when test=""count(. | ../@*) = count(../@*)"">
		|                <xsl:value-of select=""'/'""/>
		|                <xsl:value-of select=""concat('@',name())""/>
		|            </xsl:when>
		|            <!-- text- -->
		|            <xsl:when test=""self::text()"">
		|                <xsl:value-of select=""'/'""/>
		|                <xsl:value-of select=""'text()'""/>
		|                <xsl:variable name=""thisPosition"" select=""count(preceding-sibling::text())""/>
		|                <xsl:variable name=""numFollowing"" select=""count(following-sibling::text())""/>
		|                <xsl:if test=""$thisPosition + $numFollowing > 0""> 
		|                  <xsl:value-of select=""concat('[', $thisPosition +1, ']')""/>
		|                </xsl:if>
		|            </xsl:when>
		|            <!-- processing instruction -->
		|            <xsl:when test=""self::processing-instruction()"">
		|                <xsl:value-of select=""'/'""/>
		|                <xsl:value-of select=""'processing-instruction()'""/>
		|                <xsl:variable name=""thisPosition"" select=""count(preceding-sibling::processing-instruction())""/>
		|                <xsl:variable name=""numFollowing"" select=""count(following-sibling::processing-instruction())""/>
		|                <xsl:if test=""$thisPosition + $numFollowing > 0"">
		|                  <xsl:value-of select=""concat('[', $thisPosition +1, ']')""/>
		|                </xsl:if>
		|            </xsl:when>
		|            <!-- comment -->
		|            <xsl:when test=""self::comment()"">
		|                <xsl:value-of select=""'/'""/>
		|                <xsl:value-of select=""'comment()'""/>
		|                <xsl:variable name=""thisPosition"" select=""count(preceding-sibling::comment())""/>
		|                <xsl:variable name=""numFollowing"" select=""count(following-sibling::comment())""/>
		|                <xsl:if test=""$thisPosition + $numFollowing > 0"">
		|                  <xsl:value-of select=""concat('[', $thisPosition +1, ']')""/>
		|                </xsl:if>
		|            </xsl:when>
		|            <!-- namespace -->
		|            <xsl:when test=""count(. | ../namespace::*) = count(../namespace::*)"">
		|              <xsl:variable name=""ap"">'</xsl:variable>
		|              <xsl:value-of select=""'/'""/>
		|                <xsl:value-of select=""concat('namespace::*','[local-name() = ', $ap, local-name(), $ap, ']')""/>
		|            </xsl:when>
		|          </xsl:choose>
		|        </xsl:otherwise>
		|      </xsl:choose>
		|    </xsl:for-each>
		|
		|  </xsl:template>
		|
		|<!-- /path functions -->
		|";
EndFunction

#EndRegion
