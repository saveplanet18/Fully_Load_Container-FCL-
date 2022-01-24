<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:n1="http://xml.inttra.com/booking/services/01" exclude-result-prefixes="n1" xmlns:exsl="http://exslt.org/common" extension-element-prefixes="exsl">
<xsl:output method="xml" encoding="utf-8" indent="yes"/>
<xsl:template match="/">
<BookingRequest xmlns:xsd="http://www.w3.org/2001/XMLSchema-instance" xsd:noNamespaceSchemaLocation="http://wiki.wwalliance.com/wiki/images/b/bd/WWA_Booking_Request_version_1.1.0.xsd">

        <xsl:element name="BookingEnvelope">
			<xsl:for-each select="/n1:SubmitBooking/Transactions/Transaction/Properties/Party">
				<xsl:if test="Role = 'Booker'">
					<xsl:variable name="cCustomerControlCode" select="Identifier"/>
			                <xsl:element name="SenderID"><xsl:value-of select="substring-before($cCustomerControlCode,'#')"/></xsl:element>
				</xsl:if>
			</xsl:for-each>
                        <xsl:element name="ReceiverID">wwalliance</xsl:element>
                        <xsl:element name="Password">test</xsl:element>
                        <xsl:element name="Type">BookingRequest</xsl:element>
			<xsl:element name="Version">1.1.0</xsl:element>
                        <xsl:element name="EnvelopeID"><xsl:value-of select="/n1:SubmitBooking/Header/ID"/></xsl:element>           
        </xsl:element>

	<xsl:for-each select="/n1:SubmitBooking/Transactions">
		<xsl:for-each select="Transaction">
			<BookingDetails>
			<xsl:for-each select="Properties">
				
				<xsl:choose>
       				<xsl:when test="TransportService = 'FCL'">
			         	<xsl:element name="BookingType">F</xsl:element>
		        	</xsl:when>
		        	<xsl:when test="TransportService = 'FCL'">
				        <xsl:element name="BookingType">F</xsl:element>
			        </xsl:when>
				        <xsl:when test="TransportService = 'FCLFCL'">
			          <xsl:element name="BookingType">F</xsl:element>
			        </xsl:when>
			        <xsl:when test="TransportService = 'FCLFCL'">
				        <xsl:element name="BookingType">F</xsl:element>
			        </xsl:when>
			        <xsl:otherwise>
			        	<xsl:element name="BookingType">F</xsl:element>
			        </xsl:otherwise>
			      </xsl:choose>
				
				<xsl:variable name="tBookingdate" select="DateTime"/>
				<xsl:variable name="delimiter">T</xsl:variable>
        			<xsl:choose>
                			<xsl:when test="contains($tBookingdate,$delimiter)">
                        			<xsl:element name="BookingDate"><xsl:value-of select="substring-before($tBookingdate,$delimiter)"/></xsl:element>
                			</xsl:when>
        			</xsl:choose>

				<xsl:variable name="tLastSentDate" select="../../../Header/DateTimeStamp"/>

				<xsl:choose>
					<xsl:when test="contains($tLastSentDate,$delimiter)">
						<xsl:element name="LastSentDate"><xsl:value-of select="substring-before($tLastSentDate,$delimiter)"/></xsl:element>
					</xsl:when>
				</xsl:choose>
				<xsl:variable name="cTransactionStatus" select="TransactionStatus"/>
				<xsl:if test="$cTransactionStatus = 'Original'">
					<xsl:element name="RequestType">N</xsl:element>
				</xsl:if>

				<xsl:if test="$cTransactionStatus = 'Change'">
					<xsl:element name="RequestType">U</xsl:element>
				</xsl:if>

				<xsl:if test="$cTransactionStatus = 'Cancel'">
					<xsl:element name="RequestType">C</xsl:element>
				</xsl:if>

				<xsl:for-each select="Party">
					<xsl:if test="Role = 'Booker'">
						<xsl:variable name="cCustomerControlCode" select="Identifier"/>
                                        	<xsl:element name="CustomerControlCode"><xsl:value-of select="substring-after($cCustomerControlCode,'#')"/></xsl:element>
                                        </xsl:if>
					<xsl:for-each select="ChargeCategory">
						<xsl:if test="@ChargeType = 'OceanFreight'">
							<xsl:if test="PrepaidCollector/@PrepaidorCollectIndicator = 'PrePaid'">	
								<xsl:element name="FPI">P</xsl:element>
							</xsl:if>
							<xsl:if test="PrepaidCollector/@PrepaidorCollectIndicator = 'Collect'">
                                                                <xsl:element name="FPI">C</xsl:element>
                                                        </xsl:if>
						</xsl:if>
					</xsl:for-each>
				</xsl:for-each>

				<xsl:for-each select="Location">
					<xsl:if test="Type = 'PlaceOfReceipt'">
						<xsl:element name="BookingOffice"><xsl:value-of select="Identifier"/></xsl:element>
					</xsl:if>
				</xsl:for-each>

				<xsl:element name="CommunicationReference"><xsl:value-of select="InttraReferenceNumber"/></xsl:element>

				<xsl:for-each select="ReferenceInformation">
					<xsl:if test="@Type = 'BookingNumber'">
                                                <xsl:element name="BookingNumber"><xsl:value-of select="Value"/></xsl:element>
                                        </xsl:if>

					<xsl:if test="@Type = 'ShipperReferenceNumber'">
                                                <xsl:element name="ShipperReference"><xsl:value-of select="Value"/></xsl:element>
                                        </xsl:if>

					<xsl:if test="@Type = 'FreightForwarderRefNumber'">
                                                <xsl:element name="ForwarderReference"><xsl:value-of select="Value"/></xsl:element>
						<xsl:element name="CustomerReference"><xsl:value-of select="Value"/></xsl:element>
                                        </xsl:if>

					<xsl:if test="@Type = 'ConsigneeReferenceNumber'">
                                                <xsl:element name="ConsigneeReference"><xsl:value-of select="Value"/></xsl:element>
                                        </xsl:if>
				</xsl:for-each>
				
				<xsl:for-each select="Party">
		
                                        <xsl:if test="Role = 'Shipper'">
						<Address>
							<AddressID>SH</AddressID>							
							<xsl:variable name="AddressDetails">
                                                                <xsl:if test="Name">
                                                                        <xsl:element name="AddressLine"> <xsl:value-of select="Name"/></xsl:element>
                                                                </xsl:if>
                                                                <xsl:if test="Address/StreetAddress">
                                                                        <xsl:element name="AddressLine"><xsl:value-of select="Address/StreetAddress"/></xsl:element>
                                                                </xsl:if>
                                                                <xsl:if test="Address/CityName">
                                                                        <xsl:element name="AddressLine"><xsl:value-of select="Address/CityName"/></xsl:element>
                                                                </xsl:if>
                                                                <xsl:if test="Address/PostalCode">
                                                                        <xsl:element name="AddressLine"><xsl:value-of select="Address/PostalCode"/></xsl:element>
                                                                </xsl:if>
                                                        </xsl:variable>

                                                        <xsl:call-template name="AddressTokenize">
                                                                <xsl:with-param name="cInput" select="$AddressDetails"/>
                                                        </xsl:call-template>	
						</Address>
                                        </xsl:if>
					<xsl:if test="Role = 'Consignee'">
						<Address>
                                        	        <AddressID>CN</AddressID>
							<xsl:variable name="AddressDetails">
                                                                <xsl:if test="Name">
                                                                        <xsl:element name="AddressLine"> <xsl:value-of select="Name"/></xsl:element>
                                                                </xsl:if>
                                                                <xsl:if test="Address/StreetAddress">
                                                                        <xsl:element name="AddressLine"><xsl:value-of select="Address/StreetAddress"/></xsl:element>
                                                                </xsl:if>
                                                                <xsl:if test="Address/CityName">
                                                                        <xsl:element name="AddressLine"><xsl:value-of select="Address/CityName"/></xsl:element>
                                                                </xsl:if>
                                                                <xsl:if test="Address/PostalCode">
                                                                        <xsl:element name="AddressLine"><xsl:value-of select="Address/PostalCode"/></xsl:element>
                                                                </xsl:if>
                                                        </xsl:variable>

                                                        <xsl:call-template name="AddressTokenize">
                                                                <xsl:with-param name="cInput" select="$AddressDetails"/>
                                                        </xsl:call-template>
						</Address>
                                        </xsl:if>	
				</xsl:for-each>

                                <xsl:element name="CustomerContact"><xsl:value-of select="ContactInformation/Name"/></xsl:element>
				<xsl:element name="CustomerPhone"><xsl:value-of select="ContactInformation/CommunicationDetails/Phone"/></xsl:element>
				<xsl:element name="CustomerEmail"><xsl:value-of select="ContactInformation/CommunicationDetails/Email"/></xsl:element>
				<xsl:element name="BUCustomerEmail"></xsl:element>
				<xsl:element name="OnHold"></xsl:element>
				<xsl:element name="HVC"></xsl:element>
				<xsl:element name="BondedCargo"></xsl:element>
				<xsl:variable name="GROUPS_SERVED_COUNT" select="count(TransportationDetails)"/>
				<xsl:for-each select="TransportationDetails[1]">
					<xsl:if test="@TransportStage = 'PreCarriage'">
					<xsl:for-each select ="Location">
					<xsl:if test="Type = 'PortOfLoad'">
                                                <xsl:element name="CFSOrigin"><xsl:value-of select="Identifier"/></xsl:element>
                                        </xsl:if>
					</xsl:for-each>
					</xsl:if>
				</xsl:for-each>
				
                                <xsl:for-each select="TransportationDetails[1]">
                                        <xsl:if test="@TransportStage != 'PreCarriage'">
					<xsl:for-each select="../TransportationDetails">
					<xsl:if test="@TransportStage = 'Main'">
                                        <xsl:for-each select ="Location">
                                        <xsl:if test="Type = 'PortOfLoad'">
                                        	<xsl:element name="CFSOrigin"><xsl:value-of select="Identifier"/></xsl:element>
                                        </xsl:if>
                                        </xsl:for-each>
                                        </xsl:if>
                                	</xsl:for-each>
					</xsl:if>
				</xsl:for-each>					
				<xsl:for-each select="TransportationDetails">
                                        <xsl:if test="@TransportStage = 'Main'">
                                        <xsl:for-each select="Location">
                                                <xsl:if test="Type = 'PortOfLoad'">
                                                        <xsl:element name="PortOfLoading"><xsl:value-of select="Identifier"/></xsl:element>
                                                </xsl:if>
                                        </xsl:for-each>
                                        </xsl:if>
                                </xsl:for-each>


				<xsl:for-each select="TransportationDetails[$GROUPS_SERVED_COUNT]">
                                        <xsl:if test="@TransportStage = 'OnCarriage'">
                                        <xsl:for-each select ="Location">
                                        <xsl:if test="Type = 'PortOfDischarge'">
                                                <xsl:element name="CFSDestination"><xsl:value-of select="Identifier"/></xsl:element>
                                        </xsl:if>
                                        </xsl:for-each>
                                        </xsl:if>
                                </xsl:for-each>

				<xsl:for-each select="TransportationDetails[$GROUPS_SERVED_COUNT]">
				<xsl:if test="@TransportStage != 'OnCarriage'">
				<xsl:for-each select="../TransportationDetails">
				<xsl:if test="@TransportStage = 'Main'">
					<xsl:for-each select="Location">
					<xsl:if test="Type = 'PortOfDischarge'">
					<xsl:element name="CFSDestination"><xsl:value-of select="Identifier"/></xsl:element>
					</xsl:if>
					</xsl:for-each>
				</xsl:if>
				</xsl:for-each>
				</xsl:if>
				</xsl:for-each>

				<xsl:for-each select="TransportationDetails">
				<xsl:if test="@TransportStage = 'Main'">
					<xsl:for-each select="Location">
					<xsl:if test="Type = 'PortOfDischarge'">
				     		<xsl:element name="PortOfDischarge"><xsl:value-of select="Identifier"/></xsl:element>
				     	</xsl:if>
				     	</xsl:for-each>
				</xsl:if>
				</xsl:for-each>
				
				<xsl:for-each select="TransportationDetails[$GROUPS_SERVED_COUNT]">
                                        <xsl:if test="@TransportStage = 'OnCarriage'">
                                        <xsl:for-each select ="Location">
                                        <xsl:if test="Type = 'PortOfDischarge'">
                                                <xsl:element name="FinalDestination"><xsl:value-of select="Identifier"/></xsl:element>
                                                <xsl:element name="FinalDestinationPlace"><xsl:value-of select="Name"/></xsl:element>			                                                     <xsl:element name="FinalDestinationType">CFS</xsl:element>							                                                  <xsl:element name="FinalDestinationCountry"><xsl:value-of select="CountryName"/></xsl:element>
                                        </xsl:if>
                                        </xsl:for-each>
                                        </xsl:if>
                                </xsl:for-each>

                                <xsl:for-each select="TransportationDetails[$GROUPS_SERVED_COUNT]">
                                <xsl:if test="@TransportStage != 'OnCarriage'">
                                <xsl:for-each select="../TransportationDetails">
                                <xsl:if test="@TransportStage = 'Main'">
                                        <xsl:for-each select="Location">
                                        <xsl:if test="Type = 'PortOfDischarge'">
                                        <xsl:element name="FinalDestination"><xsl:value-of select="Identifier"/></xsl:element>
					<xsl:element name="FinalDestinationPlace"><xsl:value-of select="Name"/></xsl:element>                                                                        <xsl:element name="FinalDestinationType">CFS</xsl:element>                                                                                                   <xsl:element name="FinalDestinationCountry"><xsl:value-of select="CountryName"/></xsl:element>
                                        </xsl:if>
                                        </xsl:for-each>
                                </xsl:if>
                                </xsl:for-each>
                                </xsl:if>
                                </xsl:for-each>
	
							
				<xsl:element name="OncarriageFlag"></xsl:element>
				<xsl:element name="OncarriagePlace"></xsl:element>
				<xsl:element name="AmsFlag"></xsl:element>
				<xsl:element name="AesFlag"></xsl:element>
				
				<xsl:for-each select="GeneralInformation">
					<xsl:element name="Remarks"><xsl:value-of select="Text"/></xsl:element>
				</xsl:for-each>				

				<SailingDetails>
				
				<xsl:for-each select="TransportationDetails">
					<xsl:if test="@TransportStage = 'Main'">
						<xsl:for-each select="ConveyanceInformation">				
							<xsl:element name="VesselVoyageID"><xsl:value-of select="Identifier[@Type = 'VoyageNumber']"/></xsl:element>
                                                        <xsl:element name="VesselName"><xsl:value-of select="Identifier[@Type = 'VesselName']"/></xsl:element>
                                                        <xsl:element name="IMONumber"><xsl:value-of select="Identifier[@Type = 'LloydsCode']"/></xsl:element>
                                                        <xsl:element name="Voyage"><xsl:value-of select="Identifier[@Type = 'VoyageNumber']"/></xsl:element>
						</xsl:for-each>
					</xsl:if>
				</xsl:for-each>

				<xsl:for-each select="TransportationDetails[1]">
				<xsl:if test="@TransportStage = 'PreCarriage'">
					<xsl:for-each select ="Location">
						<xsl:if test="Type = 'PortOfLoad'">
						<xsl:if test="(DateTime/@Type = 'Date')or(DateTime/@Type = 'DateTime')">
						<xsl:variable name="tETDCFS" select="DateTime"/>
						<xsl:if test="contains($tETDCFS,$delimiter)">
							<xsl:element name="ETDCFS"><xsl:value-of select="substring-before($tETDCFS,$delimiter)"/></xsl:element>
						</xsl:if>
						</xsl:if>
						</xsl:if>
					</xsl:for-each>	
				</xsl:if>
				</xsl:for-each>

				<xsl:for-each select="TransportationDetails[1]">
					<xsl:if test="@TransportStage != 'PreCarriage'">
					<xsl:for-each select="../TransportationDetails">
					<xsl:if test="@TransportStage = 'Main'">
					<xsl:for-each select ="Location">
						<xsl:if test="Type = 'PortOfLoad'">
						<xsl:if test="(DateTime/@Type = 'Date')or(DateTime/@Type = 'DateTime')">
						<xsl:variable name="tETDCFS" select="DateTime"/>
						<xsl:if test="contains($tETDCFS,$delimiter)">
							<xsl:element name="ETDCFS"><xsl:value-of select="substring-before($tETDCFS,$delimiter)"/></xsl:element>
						</xsl:if>
						</xsl:if>
						</xsl:if>
					</xsl:for-each>
					</xsl:if>
					</xsl:for-each>
					</xsl:if>
				</xsl:for-each>

				<xsl:for-each select="TransportationDetails[$GROUPS_SERVED_COUNT]">
					<xsl:if test="@TransportStage = 'OnCarriage'">
						<xsl:for-each select ="Location">
						<xsl:if test="Type = 'PortOfDischarge'">
						<xsl:if test="(DateTime/@Type = 'Date')or(DateTime/@Type = 'DateTime')">
						<xsl:variable name="tETACFS" select="DateTime"/>
						<xsl:if test="contains($tETACFS,$delimiter)">
							<xsl:element name="ETACFS"><xsl:value-of select="substring-before($tETACFS,$delimiter)"/></xsl:element>
						</xsl:if>
						</xsl:if>
						</xsl:if>
						</xsl:for-each>
					</xsl:if>
				</xsl:for-each>

				<xsl:for-each select="TransportationDetails[$GROUPS_SERVED_COUNT]">
				<xsl:if test="@TransportStage != 'OnCarriage'">
				<xsl:for-each select="../TransportationDetails">
				<xsl:if test="@TransportStage = 'Main'">
				<xsl:for-each select="Location">
					<xsl:if test="Type = 'PortOfDischarge'">
					<xsl:if test="(DateTime/@Type = 'Date')or(DateTime/@Type = 'DateTime')">
					<xsl:variable name="tETACFS" select="DateTime"/>
					<xsl:if test="contains($tETACFS,$delimiter)">
						<xsl:element name="ETACFS"><xsl:value-of select="substring-before($tETACFS,$delimiter)"/></xsl:element>
					</xsl:if>
					</xsl:if>
					</xsl:if>

				</xsl:for-each>
				</xsl:if>
				</xsl:for-each>
				</xsl:if>
				</xsl:for-each>

				<xsl:for-each select="TransportationDetails[1]">
                                <xsl:if test="@TransportStage = 'PreCarriage'">
                                        <xsl:for-each select ="Location">
                                                <xsl:if test="Type = 'PortOfLoad'">
                                                <xsl:if test="(DateTime/@Type = 'Date')or(DateTime/@Type = 'DateTime')">
                                                <xsl:variable name="tETDCFS" select="DateTime"/>
                                                <xsl:if test="contains($tETDCFS,$delimiter)">
                                                        <xsl:element name="ETSOrigin"><xsl:value-of select="substring-before($tETDCFS,$delimiter)"/></xsl:element>
							<xsl:element name="ETSPol"><xsl:value-of select="substring-before($tETDCFS,$delimiter)"/></xsl:element>
                                                </xsl:if>
                                                </xsl:if>
                                                </xsl:if>
                                        </xsl:for-each>
                                </xsl:if>
                                </xsl:for-each>

                                <xsl:for-each select="TransportationDetails[1]">
                                        <xsl:if test="@TransportStage != 'PreCarriage'">
                                        <xsl:for-each select="../TransportationDetails">
                                        <xsl:if test="@TransportStage = 'Main'">
                                        <xsl:for-each select ="Location">
                                                <xsl:if test="Type = 'PortOfLoad'">
                                                <xsl:if test="(DateTime/@Type = 'Date')or(DateTime/@Type = 'DateTime')">
                                                <xsl:variable name="tETDCFS" select="DateTime"/>
                                                <xsl:if test="contains($tETDCFS,$delimiter)">
                                                        <xsl:element name="ETSOrigin"><xsl:value-of select="substring-before($tETDCFS,$delimiter)"/></xsl:element>
							<xsl:element name="ETSPol"><xsl:value-of select="substring-before($tETDCFS,$delimiter)"/></xsl:element>
                                                </xsl:if>
                                                </xsl:if>
                                                </xsl:if>
                                        </xsl:for-each>
                                        </xsl:if>
                                        </xsl:for-each>
                                        </xsl:if>
                                </xsl:for-each>


				</SailingDetails>
			</xsl:for-each>
		
			<xsl:for-each select="Details/EquipmentDetails">
                        	<xsl:variable name="count" select="count(EquipmentParty/Role[text()='ShipFromDoor'])"/>

                                <xsl:if test="$count = 0">
                                	<xsl:element name="PickupFlag">N</xsl:element>
                                </xsl:if>

                                <xsl:if test="$count > 0">
                                	<xsl:for-each select="EquipmentParty">
                                                <xsl:if test="Role = 'ShipFromDoor'">
                                                        <xsl:element name="PickupFlag">Y</xsl:element>
                                                        <PickupDetails>
	                                                        <xsl:element name="PickupReference"></xsl:element>
        	                                                <xsl:element name="CompanyName"><xsl:value-of select="Name"/></xsl:element>
                	                                        <xsl:element name="Address"><xsl:value-of select="Address/StreetAddress"/></xsl:element>
                        	                                <xsl:element name="City"></xsl:element>
                                	                        <xsl:element name="PostalCode"></xsl:element>
                                        	                <xsl:element name="Country"></xsl:element>
                                                	        <xsl:element name="Contact"></xsl:element>
                                                        	<xsl:element name="Phone"></xsl:element>
                                                        	<xsl:variable name="tPickupDate" select="DateTime"/>
                                                        	<xsl:variable name="delimiter">T</xsl:variable>
                                                        	<xsl:choose>
                                                                	<xsl:when test="contains($tPickupDate,$delimiter)">
                                                                        	<xsl:element name="Date"><xsl:value-of select="substring-before($tPickupDate,$delimiter)"/></xsl:element>
                                                                	</xsl:when>
                                                        	</xsl:choose>
                                                        	<xsl:choose>
                                                                	<xsl:when test="contains($tPickupDate,$delimiter)">
                                                                        	<xsl:element name="Time"><xsl:value-of select="substring(substring-after($tPickupDate,$delimiter),1,5)"/></xsl:element>
                                                                	</xsl:when>
                                                        	</xsl:choose>
                                                        </PickupDetails>
                                                </xsl:if>
                                        </xsl:for-each>
				</xsl:if>
                        </xsl:for-each>


			<xsl:for-each select="Details/GoodsDetails">
				<CargoDetails>
					<xsl:for-each select="OuterPack">

					<xsl:element name="Pieces"><xsl:value-of select="NumberOfPackages"/></xsl:element>
					<xsl:element name="ShippingMarks"><xsl:value-of select="CommodityClassification"/></xsl:element>
					<xsl:element name="Packaging"><xsl:value-of select="PackageTypeDescription"/></xsl:element>	
					
					<xsl:variable name="cCommodity" select="GoodsDescription"/>
					<xsl:call-template name="CommodityTokenize">
                                                        <xsl:with-param name="cInput" select="$cCommodity"/>
                                        </xsl:call-template>

					<xsl:element name="Weight"><xsl:value-of select="GoodGrossWeight"/></xsl:element>
					<xsl:element name="Volume"><xsl:value-of select="GoodGrossVolume"/></xsl:element>
					
                                        <xsl:if test="GoodGrossWeight/@UOM = 'KGM'">
                                                <UOM>M</UOM>
                                        </xsl:if>
                                        <xsl:if test="GoodGrossWeight/@UOM = 'LBS'">
                                                <UOM>E</UOM>
                                        </xsl:if>
						
					<xsl:if test="HazardousGoods">
						<HazardousFlag>Y</HazardousFlag>
						<xsl:for-each select="HazardousGoods">
						<HazardousDetails>
							<xsl:element name="HazardousClass"><xsl:value-of select="IMOClassCode"/></xsl:element>
							<xsl:element name="Flashpoint"><xsl:value-of select="FlashpointTemperature"/></xsl:element>
							<xsl:if test="FlashpointTemperature/@UOM = 'CEL'">
								<FlashpointFlag>C</FlashpointFlag>
							</xsl:if>
							<xsl:if test="FlashpointTemperature/@UOM = 'FEH'">
                                                	        <FlashpointFlag>F</FlashpointFlag>
	                                                </xsl:if>
							<xsl:element name="ShippingName"><xsl:value-of select="ProperShippingName"/></xsl:element>	
							<xsl:element name="UNNumber"><xsl:value-of select="UNDGNumber"/></xsl:element>

							<xsl:variable name="cPackingGroup" select="PackingGroupCode"/>	
							
							<xsl:if test="$cPackingGroup = 'GreatDanger'">
                                        			<PackingGroup>I</PackingGroup>
                                			</xsl:if>
							<xsl:if test="$cPackingGroup = 'MediumDanger'">
        	                                                <PackingGroup>II</PackingGroup>
                	                                </xsl:if>
							<xsl:if test="$cPackingGroup = 'MinorDanger'">
                                	                        <PackingGroup>III</PackingGroup>
                                        	        </xsl:if>	
						</HazardousDetails>
						</xsl:for-each>
					</xsl:if>

					<xsl:if test="not(HazardousGoods)">
                                        	<HazardousFlag>N</HazardousFlag>
                                        </xsl:if>
                                    	
					<xsl:for-each select="OutOfGaugeDimensions">
						<OverDimensionFlag>Y</OverDimensionFlag>
						<xsl:if test="Length">
                                                	<OverLengthFlag>Y</OverLengthFlag>
                                                </xsl:if>
						<xsl:if test="not(Length)">
                                                        <OverLengthFlag>N</OverLengthFlag>
                                                </xsl:if>
						<xsl:if test="Width">
                                                        <OverWidthFlag>Y</OverWidthFlag>
                                                </xsl:if>
                                                <xsl:if test="not(Width)">
                                                        <OverWidthFlag>N</OverWidthFlag>
                                                </xsl:if>
						<xsl:if test="Height">
                                                        <OverHeightFlag>Y</OverHeightFlag>
                                                </xsl:if>
                                                <xsl:if test="not(Height)">
                                                        <OverHeightFlag>N</OverHeightFlag>
                                                </xsl:if>
						<xsl:if test="Weight">
                                                        <OverWeightFlag>Y</OverWeightFlag>
                                                </xsl:if>
                                                <xsl:if test="not(Weight)">
                                                        <OverWeightFlag>N</OverWeightFlag>
                                                </xsl:if>
					</xsl:for-each>
				
					<xsl:if test="not(OutOfGaugeDimensions)">
                                                <OverDimensionFlag>N</OverDimensionFlag>
                                        </xsl:if>	
					</xsl:for-each>
				</CargoDetails>
			</xsl:for-each>
			</BookingDetails>
		</xsl:for-each>
	</xsl:for-each>
</BookingRequest>
</xsl:template>

<xsl:template name="CommodityTokenize">
        <xsl:param name="cInput"/>
        <xsl:param name="iLength" select="50"/>

        <xsl:choose>
        <xsl:when test="string-length($cInput) > $iLength">
                <xsl:variable name="cString" select="substring($cInput,1,$iLength)"/>
                <xsl:call-template name="last-index-of">
                        <xsl:with-param name="cCommodity" select="$cInput"/>
                        <xsl:with-param name="cText" select="$cString"/>
                        <xsl:with-param name="cDelimiter" select="' '"/>
                </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
                <Commodity><xsl:value-of select="$cInput"/></Commodity>
        </xsl:otherwise>
        </xsl:choose>
</xsl:template>

<xsl:template name="last-index-of">
        <xsl:param name="cCommodity"/>
        <xsl:param name="cText"/>
        <xsl:param name="cDelimiter" select="' '"/>
        <xsl:param name="cRemainder" select="$cText"/>

        <xsl:choose>
        <xsl:when test="contains($cRemainder, $cDelimiter)">
                <xsl:call-template name="last-index-of">
                        <xsl:with-param name="cCommodity" select="$cCommodity"/>
                        <xsl:with-param name="cText" select="$cText"/>
                        <xsl:with-param name="cRemainder" select="substring-after($cRemainder, $cDelimiter)"/>
                        <xsl:with-param name="cDelimiter" select="$cDelimiter"/>
                    </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
                <xsl:variable name="cLastIndex" select="string-length(substring($cText, 1, string-length($cText)-string-length($cRemainder)))+1"/>
                <xsl:choose>
                <xsl:when test="string-length($cRemainder)=0">
                        <xsl:variable name="iLength" select="string-length($cText)"/>
                        <xsl:element name="Commodity"><xsl:value-of select="substring($cText,1,$iLength)"/></xsl:element>
                        <xsl:if test="substring($cCommodity,$iLength+1)">
                                <xsl:variable name="cNextText" select="substring($cCommodity,$iLength+1)"/>

                                <xsl:call-template name="CommodityTokenize">
                                        <xsl:with-param name="cInput" select="$cNextText"/>
                                </xsl:call-template>
                        </xsl:if>
                </xsl:when>
		<xsl:when test="$cLastIndex>0">
                        <xsl:variable name="iLength" select="($cLastIndex - string-length($cDelimiter))"/>
                        <xsl:element name="Commodity"><xsl:value-of select="substring($cText,1,$iLength)"/></xsl:element>
                        <xsl:if test="substring($cCommodity,$iLength+1)">
                                <xsl:variable name="cNextText" select="substring($cCommodity,$iLength+1)"/>

                                <xsl:call-template name="CommodityTokenize">
                                        <xsl:with-param name="cInput" select="$cNextText"/>
                                </xsl:call-template>
                        </xsl:if>
                </xsl:when>
                </xsl:choose>
        </xsl:otherwise>
        </xsl:choose>
</xsl:template>

<xsl:template name="AddressTokenize">
        <xsl:param name="cInput"/>
        <xsl:param name="iCount" select="1"/>

        <xsl:element name="AddressLine{$iCount}"> <xsl:value-of select="exsl:node-set($cInput)/AddressLine[$iCount]"/></xsl:element>
        <xsl:variable name="iMax" select="count(exsl:node-set($cInput)/AddressLine)"/>
        <xsl:if test="$iCount &lt; $iMax">
                <xsl:call-template name="AddressTokenize">
                        <xsl:with-param name="cInput" select="$cInput"/>
                        <xsl:with-param name="iCount" select="$iCount+1"/>
                </xsl:call-template>
        </xsl:if>
</xsl:template>
</xsl:stylesheet>