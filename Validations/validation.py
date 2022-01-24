import xml.etree.ElementTree as ET
import pandas as pd
import datetime
import mysql.connector
import re


conn = mysql.connector.connect(user='root', password='root',host='localhost',database='fcl_db')
cursor = conn.cursor()

Path = "Converted\wwa_inttrs_Original_booking_request .xml"
tree = ET.parse(Path)
root = tree.getroot()


def SenderID():
    for elm in root.findall("./BookingEnvelope/SenderID"):
        result = elm.tag,'',elm.text
        if result is not None:
            return True
        return False
    return None 
def ReceiverID():
    for elm in root.findall("./BookingEnvelope/ReceiverID"):
        result = elm.tag,'',elm.text
        if result is not None:
            return True
        return False
    return None

def Password():
    for elm in root.findall("./BookingEnvelope/Password"):
        result = elm.tag,'',elm.text
        if result is not None:
            return ("valid",result)
        return ("invalid")
    return None  
    
def Type():
    for elm in root.findall("./BookingEnvelope/Type"):
        result = elm.tag,'',elm.text
        if result is not None:
            return True
        return False
    return None 

def Version():
    for elm in root.findall("./BookingEnvelope/Version"):
        result = elm.tag,elm.text
        if result is not None:
            return True
        return False
    return None 

# def EnvelopeID():
#     for elm in root.findall("./BookingEnvelope/EnvelopeID"):
#         result = elm.tag,elm.text
#         if result is not None:
#             print(result)
#         else:
#             print('invalid')              
    
def BookingType():
    for item in root.findall('BookingDetails'):
        BookingType = item.find('BookingType',).text
        if BookingType.__len__()==1:   
            if BookingType=="F":
                return(BookingType)
            else:
                return('invalid')
def BookingDate():
    for item in root.findall('BookingDetails'):
        BookingDate = item.find('BookingDate').text
        if item is not None:   
            if BookingDate:
                try:
                    datetime.datetime.strptime(BookingDate, "%Y-%m-%d")
                except :
                    return False
            return False

def LastSentDate():
    for item in root.findall('BookingDetails'):
        LastSentDate = item.find('LastSentDate').text
        if item is not None:   
            if LastSentDate:
                try:
                    datetime.datetime.strptime(LastSentDate, "%Y-%m-%d")
                except :
                    return True
            return False

def RequestType():
    for item in root.findall('BookingDetails'):
        cRequestType = item.find('RequestType').text 
        if cRequestType == 'N':
            return('valid',cRequestType)   
        elif cRequestType == 'U':
            return('valid',cRequestType)
        elif cRequestType == 'C':
            return('valid',cRequestType)
        else:
            return('invalid')      

def CustomerControlCode():
    booking = BookingType()
    for item in root.findall('BookingDetails'):
        CustomerControlCode = item.find('CustomerControlCode').text
        if CustomerControlCode.__len__()<=10:
            if CustomerControlCode  and booking=="F": 
                return ("valid",CustomerControlCode)
            else:
                return('invalid')
        return None

def BookingOffice():
    request = RequestType()
    for item in root.findall('BookingDetails'):
        BookingOffice = item.find('BookingOffice').text
        if BookingOffice.__len__()>4:
            if BookingOffice and request:
                return('valid',BookingOffice)
            else:
                return('invalid')

# def CommunicationReference():
#     for item in root.findall('BookingDetails'):
#         CommunicationReference = item.find('CommunicationReference').text
#         mydata = {}
#         for child in CommunicationReference:
#             if child.tag = 
# print(CommunicationReference())

# def CustomerReference():
#     request = RequestType()
#     for item in root.findall('BookingDetails'):
#         CustomerReference = item.find('CustomerReference').text
#         if CustomerReference==1 and request == 'N':
#             sql = """"SELECT count(*)as Count FROM boo_Booking WHERE cCustomerReference = %s """.format(CustomerReference)
#             cursor.execute(sql)
#         elif CustomerReference == 1 and request == 'U':     
#             sql = """"UPDATE boo_Booking SET iStatus = -1, WHERE iBookingNumID = '4'"""
#             cursor.execute(sql)
#         elif CustomerReference == 1 and request =='C':
#             sql = """"DELETE FROM boo_Booking WHERE iBookingNumID=4"""
#             cursor.execute(sql)            
#         return False
# print(CustomerReference())

def CustomerReference():
    request = RequestType()
    for item in root.findall('BookingDetails'):
        CustomerReference = item.find('CustomerReference').text
        return (CustomerReference)
print(CustomerReference())



    

    
