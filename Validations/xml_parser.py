import xml.etree.ElementTree as ET
import pandas as pd
import mysql.connector



conn = mysql.connector.connect(user='root', password='root',host='localhost',database='fcl_db')

class xmlreader:
    
    def read_xml_file(xmlfile):
        
            tree = ET.parse(xmlfile) 
            root = tree.getroot()
            for product in root.findall("BookingEnvelope"): 
                    SenderID = product.find('SenderID').text
                    ReceiverID = product.find('ReceiverID').text
                    Password = product.find('Password').text
                    Type = product.find('Type').text
                    Version = product.find('Version').text
                    EnvelopeID = product.find('EnvelopeID').text
            for item in  root.findall("BookingDetails"): 
                    BookingType = item.find('BookingType').text
                    BookingDate = item.find('BookingDate').text
                    LastSentDate = item.find('LastSentDate').text
                    RequestType = item.find('RequestType').text
                    CustomerControlCode = item.find('CustomerControlCode').text
                    FPI = item.find('FPI').text
                    BookingOffice = item.find('BookingOffice').text
                    CommunicationReference = item.find('CommunicationReference').text
                    ForwarderReference = item.find('ForwarderReference').text
                    CustomerReference = item.find('CustomerReference').text
                    BookingNumber = item.find('BookingNumber').text
                    WWAReference = item.find('WWAReference').text
                    for child in item.findall('Address'):
                        AddressID = child.find('AddressID').text
                        AddressLine1 = child.find('AddressLine1').text
                        AddressLine2 = child.find('AddressLine2').text
                        AddressLine3 = child.find('AddressLine3').text
                    CustomerContact = item.find('CustomerContact').text
                    CustomerPhone = item.find('CustomerPhone').text
                    CustomerEmail = item.find('CustomerEmail').text
                    BUCustomerEmail = item.find('BUCustomerEmail').text
                    OnHold = item.find('OnHold').text
                    HVC = item.find('HVC').text
                    BondedCargo = item.find('BondedCargo').text
                    CFSOrigin = item.find('CFSOrigin').text
                    PortOfLoading = item.find('PortOfLoading').text
                    CFSDestination = item.find('CFSDestination').text
                    PortOfDischarge = item.find('PortOfDischarge').text
                    FinalDestination = item.find('FinalDestination').text
                    FinalDestinationPlace = item.find('FinalDestinationPlace').text
                    FinalDestinationType = item.find('FinalDestinationType').text
                    FinalDestinationCountry = item.find('FinalDestinationCountry').text
                    OncarriageFlag = item.find('OncarriageFlag').text
                    OncarriagePlace = item.find('OncarriagePlace').text
                    AmsFlag = item.find('AmsFlag').text
                    AesFlag = item.find('AesFlag').text
                    for subchild in item.findall('SailingDetails'):
                        VesselVoyageID = subchild.find('VesselVoyageID').text
                        VesselName = subchild.find('VesselName').text
                        IMONumber = subchild.find('IMONumber').text
                        Voyage = subchild.find('Voyage').text
                        ETDCFS = subchild.find('ETDCFS').text
                        ETACFS = subchild.find('ETACFS').text
                        ETSOrigin = subchild.find('ETSOrigin').text
                        ETSPol = subchild.find('ETSPol').text
                    PickupFlag = item.find('PickupFlag').text
                    for last in item.findall('CargoDetails'):
                        Pieces = last.find('Pieces').text
                        ShippingMarks = last.find('ShippingMarks').text
                        Packaging = last.find('Packaging').text
                        Commodity = last.find('Commodity').text
                        Weight = last.find('Weight').text
                        Volume = last.find('Volume').text
                        UOM = last.find('UOM').text
                        HazardousFlag = last.find('HazardousFlag').text
                        OverDimensionFlag = last.find('OverDimensionFlag').text
                        keys= (BookingType, BookingDate,CustomerControlCode,BookingNumber,WWAReference ,CommunicationReference,ForwarderReference,CustomerReference,BookingOffice,CustomerContact,CustomerPhone,CustomerEmail,BUCustomerEmail,CFSOrigin ,PortOfLoading,CFSDestination,VesselName ,Voyage,ETDCFS ,ETACFS ,ETSOrigin ,ETSPol ,PickupFlag ,Pieces ,ShippingMarks ,Packaging ,Commodity ,Weight ,UOM ,HazardousFlag,RequestType)
                        insert = "INSERT INTO boo_booking(cBookingType, tBookingDate,cCustomerControlCode,cBookingNumber,cWWAReference,cCommunicationReference,cForwarderReference,cCustomerReference,cBookingOffice,cCustomerContact,cCustomerPhone,cCustomerEmail,cBUCustomerEmail,cCFSOrigin ,cPortOfLoading,cCFSDestination,cVesselName ,cVoyage,tETDCFS ,tETACFS ,tETSOrigin ,tETSPol ,cPickupFlag ,iPieces ,cShippingMarks ,cPackaging ,cCommodity ,nWeight ,cUOM ,cHazardousFlag,RequestType ) values(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)"   
                        cursor = conn.cursor()
                        cursor.execute(insert,keys)
                        conn.commit()
                        print("Data inserted successfully.")
                        
            


       



    
