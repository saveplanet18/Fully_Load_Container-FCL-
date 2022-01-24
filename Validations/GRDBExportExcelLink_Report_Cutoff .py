from numpy import array 
import xlsxwriter
import os
import mysql.connector
from mysql.connector import Error
import pandas.io.sql as sql
import pandas as pd
import smtplib
import uuid
import json
from datetime import date
import shutil
import tempfile
from  collections  import OrderedDict



Connection = mysql.connector.Connect(host = 'localhost', user = 'root', password ='root' , database = 'grdb_report')
Cursor = Connection.cursor(prepared=True) 

def logfile():
    TMPDIR = "grdb_Export_Excel_download_Cutoff_Report_log.ok"
    cTempOKFile = TMPDIR
    if os.path.exists(cTempOKFile):
        print("lock found")
    else:
        content = 'some text message'.encode()
        fp = open(cTempOKFile,'wb')
        fp.write(content)
        fp.close()
        return fp
cSessionID = str(uuid.uuid4()).replace('-','_')
cSelectmemberQuery = sql.read_sql('''select distinct cCode from gen_Carrier where iStatus=0 and cScaccodeType='A' and cCode='SHPT' ORDER BY cCode''',Connection)
RowNumMember =cSelectmemberQuery.shape[0]
aCarrierCodes =cSelectmemberQuery['cCode'].tolist()

cSelectPendingExports = sql.read_sql('''select cAliascode from gen_Customer_alias where iStatus=0 and cIsGrdb='Y' and cIsPrivate='N' and cIsGroup='N' and cIsSpecial='N' AND cCustomerType='global'  ORDER BY cAliascode''',Connection)
RowNumExportExcel = cSelectPendingExports.shape[0]
aCustomerList = cSelectPendingExports['cAliascode'].unique().tolist()
aMail = []
cRateType = ["OFR","FOB","PLC"]
cExportOption=1
"""
if (RowNumExportExcel > 0 and RowNumMember > 0):
    zip1 = shutil.make_archive('grdb_Export_Excel_download_Cutoff_Report_log.ok', 'zip', logfile())
    cReportDir = zip1
    if (os.path.exists(cReportDir)):
        os.remove(cReportDir)
    os.makedir(cReportDir,'grdb_Export_Excel_download_Cutoff_Report_log.ok')
    os.chmod(cReportDir)
"""
for cMmeberValue in aCarrierCodes:
    cMemberCode = ''.join(map(str,cMmeberValue))
    cCode =','.join([str(x) for x in aCustomerList])
    cCode10= tuple(x for x in cCode.split(','))
    for cratetype in cRateType:
        if cratetype in 'FOB':
            dropTable = "DROP TEMPORARY TABLE IF EXISTS grdb_sessionHeader_FOB_{}".format(cSessionID)
            Cursor.execute(dropTable)
            cCreatetable1 ='''
            CREATE TEMPORARY TABLE grdb_sessionHeader_FOB_{}(
                iHeaderID INT NOT NULL AUTO_INCREMENT,
                iFreightOnBoardID int NOT NULL DEFAULT '0',
                cQuotingMember varchar(20) NOT NULL DEFAULT '',
                cCustomeralias varchar(20) NOT NULL DEFAULT '',
                cScaccode varchar(20) NOT NULL DEFAULT '',
                cOriginRegioncode varchar(20) NOT NULL DEFAULT '',
                cOriginCFSUncode varchar(20) NOT NULL DEFAULT '',
                cOriginConsoleCFSUncode varchar(20) NOT NULL DEFAULT '',
                cOriginPortUncode varchar(20) NOT NULL DEFAULT '',
                cTransshipment_1 varchar(20) NOT NULL DEFAULT '',
                cTransshipment_2 varchar(20) NOT NULL DEFAULT '',
                cTransshipment_3 varchar(20) NOT NULL DEFAULT '',
                cDestinationRegioncode varchar(20) NOT NULL DEFAULT '',
                cDestinationPortUncode varchar(20) NOT NULL DEFAULT '',
                cDestinationDeconsoleCFSUncode varchar(20) NOT NULL DEFAULT '',
                cDestinationCFSUncode varchar(20) NOT NULL DEFAULT '',
                cQuotingregion varchar(20) NOT NULL DEFAULT '',
                cOriginUncode varchar(10) NOT NULL DEFAULT '',
                cDestinationUncode varchar(10) NOT NULL DEFAULT '',
                PRIMARY KEY (iHeaderID),
                KEY IX_iFreightOnBoardID (iFreightOnBoardID),
                KEY IX_iOriginregion (cOriginRegioncode),
                KEY IX_iDestinationregion (cDestinationRegioncode),
                KEY IX_iOriginregion_iDestinationregion (cOriginUncode,cDestinationUncode)
            )ENGINE=InnoDB
            '''.format(cSessionID)
            Cursor.execute(cCreatetable1)
            cSQLSessiontbl = '''
            INSERT INTO grdb_sessionHeader_FOB_{}(iFreightOnBoardID,cQuotingMember,cCustomeralias,cScaccode,cOriginRegioncode,cOriginCFSUncode,cOriginConsoleCFSUncode,cOriginPortUncode,
            cTransshipment_1,cTransshipment_2,cTransshipment_3,cDestinationRegioncode,cDestinationPortUncode,cDestinationDeconsoleCFSUncode,cDestinationCFSUncode,
            cQuotingregion,cOriginUncode,cDestinationUncode) SELECT a.iFreightOnBoardID,a.cQuotingMember,a.cCustomeralias,a.cScaccode,a.cOriginRegioncode,a.cOriginCFSUncode,a.cOriginConsoleCFSUncode,a.cOriginPortUncode,
            a.cTransshipment_1,a.cTransshipment_2,a.cTransshipment_3,a.cDestinationRegioncode,a.cDestinationPortUncode,a.cDestinationDeconsoleCFSUncode,a.cDestinationCFSUncode,
            a.cQuotingregion,a.cOriginUncode,a.cDestinationUncode FROM grdb_FreightOnBoard_Write as a WHERE  a.iStatus=0 AND a.iActive=5 AND a.cCustomeralias in {} AND a.cScaccode="{}";
            '''.format(cSessionID,cCode10,cMemberCode)         
            Cursor.execute(cSQLSessiontbl)
            Cursor.fetchall()
            cHeaderCountQueryRatesData =sql.read_sql_query("SELECT count(hfob.iFreightOnBoardID) as iCount  FROM grdb_sessionHeader_FOB_{} AS hfob".format(cSessionID),Connection)
            cHeaderQueryRatesData =sql.read_sql_query( "SELECT hfob.*, hfob.iFreightOnBoardID AS iPrimaryKey FROM grdb_sessionHeader_FOB_{} AS hfob ".format(cSessionID),Connection)
            cChargesQueryRatesData = sql.read_sql_query('''SELECT cfob.*,DATE_ADD(cfob.tExpirationdate , INTERVAL 1 DAY) as new_effective FROM grdb_FreightOnBoard_Charges_Write AS cfob 
            WHERE cfob.iFreightOnBoardID''',Connection)
            cChargegroup = "FOB"
            cFileName = logfile() ,'FOB_',{cCode10}, str(date.today()) , '.xlsx'.format(cCode10)
            cCutoff_Condition = " AND cofr.iActive IN(1,5)"

            
            # Missing data
            cHeaderCountQueryRatesData1 =sql.read_sql_query('''SELECT count(iDashboardLandID) as iCount FROM grdb_Dashboard_Unique_Lanes AS hfob WHERE hfob.iStatus <= 2 AND hfob.iFOBExist = 1 AND hfob.cCustomeralias in {} AND hfob.cScaccodeFOB="{}";'''.format(cCode10,cMemberCode),Connection)
            cHeaderQueryRatesData1 =sql.read_sql_query('''SELECT DISTINCT 0,0,hfob.cCustomeralias AS cCustomeralias,hfob.cScaccodeFOB AS cScaccode,
            hfob.cOriginRegioncode,hfob.cOriginCountrycode,hfob.cOriginUncode AS cOriginCFSUncode,hfob.cOriginUncode AS cOriginConsoleCFSUncode,hfob.cOriginUncode AS cOriginPortUncode,
            hfob.cDestinationRegioncode,hfob.cDestinationCountrycode,hfob.cDestinationUncode AS cDestinationCFSUncode,hfob.cDestinationUncode AS cDestinationDeconsoleCFSUncode,hfob.cDestinationUncode AS cDestinationPortUncode,
            hfob.cQuotingMemberFOB AS cQuotingMember, '-' AS iUploadlogID, hfob.cOriginUncode, hfob.cDestinationUncode
            FROM grdb_Dashboard_Unique_Lanes AS hfob WHERE hfob.iStatus <= 2 AND hfob.iFOBExist = 1 
            AND hfob.cCustomeralias in {} AND hfob.cScaccodeFOB="{}";'''.format(cCode10,cMemberCode),Connection)

        elif cratetype in 'PLC':
            dropTable1 = "DROP TEMPORARY TABLE IF EXISTS grdb_sessionHeader_PLC_{}".format(cSessionID)
            Cursor.execute(dropTable1)
            cCreatetable2 = '''
            CREATE TEMPORARY TABLE grdb_sessionHeader_PLC_{}(
                iHeaderID INT(11) NOT NULL AUTO_INCREMENT,
                iPostlandingID int(20) NOT NULL DEFAULT '0',
                cQuotingMember varchar(20) NOT NULL DEFAULT '',
                cCustomeralias varchar(20) NOT NULL DEFAULT '',
                cScaccode varchar(20) NOT NULL DEFAULT '',
                cOriginRegioncode varchar(20) NOT NULL DEFAULT '',
                cOriginCFSUncode varchar(20) NOT NULL DEFAULT '',
                cOriginConsoleCFSUncode varchar(20) NOT NULL DEFAULT '',
                cOriginPortUncode varchar(20) NOT NULL DEFAULT '',
                cTransshipment_1 varchar(20) NOT NULL DEFAULT '',
                cTransshipment_2 varchar(20) NOT NULL DEFAULT '',
                cTransshipment_3 varchar(20) NOT NULL DEFAULT '',
                cDestinationRegioncode varchar(20) NOT NULL DEFAULT '',
                cDestinationPortUncode varchar(20) NOT NULL DEFAULT '',
                cDestinationDeconsoleCFSUncode varchar(20) NOT NULL DEFAULT '',
                cDestinationCFSUncode varchar(20) NOT NULL DEFAULT '',
                cQuotingregion varchar(20) NOT NULL DEFAULT '',
                cOriginUncode varchar(10) NOT NULL DEFAULT '',
                cDestinationUncode varchar(10) NOT NULL DEFAULT '',
                PRIMARY KEY (iHeaderID),
                KEY IX_iPostlandingID (iPostlandingID),
                KEY IX_iOriginregion (cOriginRegioncode),
                KEY IX_iDestinationregion (cDestinationRegioncode),
                KEY IX_iOriginregion_iDestinationregion (cOriginUncode,cDestinationUncode)
            ) ENGINE=InnoDB;'''.format(cSessionID)
            Cursor.execute(cCreatetable2)
            cSQLSessiontb2 = '''
            INSERT INTO grdb_sessionHeader_PLC_{}(iPostlandingID,cQuotingMember,cCustomeralias,cScaccode,cOriginRegioncode,cOriginCFSUncode,cOriginConsoleCFSUncode,cOriginPortUncode,
            cTransshipment_1,cTransshipment_2,cTransshipment_3,cDestinationRegioncode,cDestinationPortUncode,cDestinationDeconsoleCFSUncode,cDestinationCFSUncode,
            cQuotingregion,cOriginUncode,cDestinationUncode) SELECT a.iPostlandingID,a.cQuotingMember,a.cCustomeralias,a.cScaccode,a.cOriginRegioncode,a.cOriginCFSUncode,a.cOriginConsoleCFSUncode,a.cOriginPortUncode,
            a.cTransshipment_1,a.cTransshipment_2,a.cTransshipment_3,a.cDestinationRegioncode,a.cDestinationPortUncode,a.cDestinationDeconsoleCFSUncode,a.cDestinationCFSUncode,
            a.cQuotingregion,a.cOriginUncode,a.cDestinationUncode FROM grdb_Postlanding_Write as a  WHERE  a.iStatus=0  AND a.iActive=5 AND a.cCustomeralias in {} AND a.cScaccode="{}";
            '''.format(cSessionID,cCode10,cMemberCode)
            Cursor.execute(cSQLSessiontb2)
            cHeaderCountQueryRatesData =sql.read_sql_query('''SELECT  count(hplc.iPostlandingID) as iCount  FROM grdb_sessionHeader_PLC_{} AS hplc '''.format(cSessionID),Connection)
            cHeaderQueryRatesData = sql.read_sql_query('''SELECT hplc.*, hplc.iPostlandingID AS iPrimaryKey FROM grdb_sessionHeader_PLC_{} AS hplc '''.format(cSessionID),Connection)
            cChargesQueryRatesData = sql.read_sql_query('''SELECT cplc.*,DATE_ADD(cplc.tExpirationdate , INTERVAL 1 DAY) as new_effective FROM  grdb_Postlanding_Charges_Write AS cplc WHERE cplc.iPostlandingID;''',Connection)
            cChargegroup = "PLC"
            cFileName = logfile() ,'PLC_',{cCode10}, str(date.today()) , '.xlsx'.format(cCode10)
            cCutoff_Condition = " AND cofr.iActive IN(1,5)"


            #Missing
            cHeaderCountQueryRatesData1=sql.read_sql_query('''SELECT count(iDashboardLandID) as iCount FROM grdb_Dashboard_Unique_Lanes as hplc WHERE hplc.iStatus <= 2 AND hplc.iPLCExist = 1  AND hplc.cCustomeralias in {} AND hplc.cScaccodePLC="{}"'''.format(cCode10,cMemberCode),Connection)
            cHeaderQueryRatesData1 = sql.read_sql_query(''' SELECT DISTINCT 0,0,hplc.cCustomeralias AS cCustomeralias,hplc.cScaccodePLC AS cScaccode,
            hplc.cOriginRegioncode,hplc.cOriginCountrycode,hplc.cOriginUncode AS cOriginCFSUncode,hplc.cOriginUncode AS cOriginConsoleCFSUncode,hplc.cOriginUncode AS cOriginPortUncode,
            hplc.cDestinationRegioncode,hplc.cDestinationCountrycode,hplc.cDestinationUncode AS cDestinationCFSUncode,hplc.cDestinationUncode AS cDestinationDeconsoleCFSUncode,hplc.cDestinationUncode AS cDestinationPortUncode,
            hplc.cQuotingMemberPLC AS cQuotingMember, '-' AS iUploadlogID, hplc.cOriginUncode, hplc.cDestinationUncode
            FROM grdb_Dashboard_Unique_Lanes AS hplc WHERE hplc.iStatus <= 2 AND hplc.iPLCExist = 1 
            AND hplc.cCustomeralias in {} AND hplc.cScaccodePLC="{}" '''.format(cCode10,cMemberCode),Connection)

        elif cratetype in 'OFR': 
            dropTable3 = "DROP TEMPORARY TABLE IF EXISTS grdb_sessionHeader_OFR_{}".format(cSessionID)
            Cursor.execute(dropTable3)
            cCreatetable3 = '''
            CREATE TEMPORARY TABLE grdb_sessionHeader_OFR_{}(
                iHeaderID INT(11) NOT NULL AUTO_INCREMENT,
                iOceanFreightID int(20) NOT NULL DEFAULT '0',
                cQuotingMember varchar(20) NOT NULL DEFAULT '',
                cCustomeralias varchar(20) NOT NULL DEFAULT '',
                cScaccode varchar(20) NOT NULL DEFAULT '',
                cOriginRegioncode varchar(20) NOT NULL DEFAULT '',
                cOriginCFSUncode varchar(20) NOT NULL DEFAULT '',
                cOriginConsoleCFSUncode varchar(20) NOT NULL DEFAULT '',
                cOriginPortUncode varchar(20) NOT NULL DEFAULT '',
                cTransshipment_1 varchar(20) NOT NULL DEFAULT '',
                cTransshipment_2 varchar(20) NOT NULL DEFAULT '',
                cTransshipment_3 varchar(20) NOT NULL DEFAULT '',
                cDestinationRegioncode varchar(20) NOT NULL DEFAULT '',
                cDestinationPortUncode varchar(20) NOT NULL DEFAULT '',
                cDestinationDeconsoleCFSUncode varchar(20) NOT NULL DEFAULT '',
                cDestinationCFSUncode varchar(20) NOT NULL DEFAULT '',
                cQuotingregion varchar(20) NOT NULL DEFAULT '',
                cOriginUncode varchar(10) NOT NULL DEFAULT '',
                cDestinationUncode varchar(10) NOT NULL DEFAULT '',
                cCurrency varchar(20) NOT NULL DEFAULT '',
                iOFRRate double NOT NULL DEFAULT '0',
                cChargecode varchar(20) NOT NULL DEFAULT '',
                cRatebasis varchar(20) NOT NULL DEFAULT '',
                cFrom int(11) NOT NULL DEFAULT '0',
                cTo int(11) NOT NULL DEFAULT '0',
                iMinimum decimal(10,3) NOT NULL DEFAULT '0.000',
                iMaximum decimal(10,3) NOT NULL DEFAULT '0.000',
                cNotes text NOT NULL,
                tEffectivedate date NOT NULL DEFAULT '0000-00-00',
                tExpirationdate date NOT NULL DEFAULT '0000-00-00',
                iStatus int(2) NOT NULL DEFAULT '0',
                PRIMARY KEY (iHeaderID),
                KEY IX_iOceanFreightID (iOceanFreightID),
                KEY IX_iOriginregion (cOriginRegioncode),
                KEY IX_iDestinationregion (cDestinationRegioncode),
                KEY IX_iOriginregion_iDestinationregion (cOriginUncode,cDestinationUncode)
            ) ENGINE=InnoDB;'''.format(cSessionID)
            Cursor.execute(cCreatetable3)
            cSQLSessiontb6 = '''
            INSERT INTO grdb_sessionHeader_OFR_{}(iOceanFreightID,cQuotingMember,cCustomeralias,cScaccode,cOriginRegioncode,cOriginCFSUncode,cOriginConsoleCFSUncode,cOriginPortUncode,
            cTransshipment_1,cTransshipment_2,cTransshipment_3,cDestinationRegioncode,cDestinationPortUncode,cDestinationDeconsoleCFSUncode,cDestinationCFSUncode,
            cQuotingregion,cOriginUncode,cDestinationUncode,cCurrency,iOFRRate,cChargecode,cRatebasis,cFrom,cTo,iMinimum,iMaximum,cNotes,tEffectivedate,tExpirationdate) SELECT a.iOceanFreightID,a.cQuotingMember,a.cCustomeralias,a.cScaccode,a.cOriginRegioncode,a.cOriginCFSUncode,a.cOriginConsoleCFSUncode,a.cOriginPortUncode,
            a.cTransshipment_1,a.cTransshipment_2,a.cTransshipment_3,a.cDestinationRegioncode,a.cDestinationPortUncode,a.cDestinationDeconsoleCFSUncode,a.cDestinationCFSUncode,
            a.cQuotingregion,a.cOriginUncode,a.cDestinationUncode,a.cCurrency,a.iOFRRate,a.cChargecode,a.cRatebasis,a.cFrom,a.cTo,a.iMinimum,a.iMaximum,a.cNotes,a.tEffectivedate,a.tExpirationdate FROM grdb_OceanFreight_Write as a  WHERE  a.iStatus=0  AND a.iActive=5 AND a.cCustomeralias in {} AND a.cScaccode= "{}";
            '''.format(cSessionID,cCode10,cMemberCode)
            Cursor.execute(cSQLSessiontb6) 
            Cursor.fetchall()
           
            dropTable4 = "DROP TEMPORARY TABLE IF EXISTS grdb_sessionHeader_OFR_Dup_{}".format(cSessionID)
            Cursor.execute(dropTable4)
            cCreatetable4 = '''
            CREATE TEMPORARY TABLE grdb_sessionHeader_OFR_Dup_{}
                (iOFRHeaderID INT(11) NOT NULL AUTO_INCREMENT,
                iOceanFreightID int(20) NOT NULL DEFAULT '0',
                cCustomeralias varchar(20) NOT NULL DEFAULT '',
                cScaccode varchar(20) NOT NULL DEFAULT '',
                cOriginUncode varchar(10) NOT NULL DEFAULT '',
                cDestinationUncode varchar(10) NOT NULL DEFAULT '',
                cChargecode varchar(20) NOT NULL DEFAULT '',
                cRatebasis varchar(20) NOT NULL DEFAULT '',
                cFrom int(11) NOT NULL DEFAULT '0',
                cTo int(11) NOT NULL DEFAULT '0',
                tEffectivedate date NOT NULL DEFAULT '0000-00-00',
                tExpirationdate date NOT NULL DEFAULT '0000-00-00',
                PRIMARY KEY (iOFRHeaderID),
                KEY IX_iOceanFreightID1 (iOceanFreightID),
                KEY IX_iOriginregion_iDestinationregion1 (cOriginUncode,cDestinationUncode)
            ) ENGINE=InnoDB ; 
            '''.format(cSessionID)
            Cursor.execute(cCreatetable4)
            tTodatDate = date.today().isoformat()
            cSQLSessiontb5 = '''
            INSERT INTO grdb_sessionHeader_OFR_Dup_{}(
            iOceanFreightID,cCustomeralias,cScaccode,cOriginUncode,cDestinationUncode,cChargecode,cRatebasis,cFrom,cTo,tEffectivedate,tExpirationdate) SELECT a.iOceanFreightID,a.cCustomeralias,a.cScaccode,
            a.cOriginUncode,a.cDestinationUncode,a.cChargecode,a.cRatebasis,a.cFrom,a.cTo,a.tEffectivedate,a.tExpirationdate FROM grdb_OceanFreight_Write as a  WHERE  a.iStatus=0  AND a.iActive=1 AND a.cCustomeralias in {} AND a.cScaccode="{}" AND a.tExpirationdate="{}";
            '''.format(cSessionID,cCode10,cMemberCode,tTodatDate)
            Cursor.execute(cSQLSessiontb5)
            #Cursor.fetchall()
            cUpdateQuery =('''
            UPDATE grdb_sessionHeader_OFR_{} as a,grdb_sessionHeader_OFR_Dup_{} as b SET a.iStatus=-1
            WHERE a.cCustomeralias=b.cCustomeralias AND a.cOriginUncode=b.cOriginUncode AND a.cDestinationUncode =b.cDestinationUncode 
            AND a.cRatebasis=b.cRatebasis AND a.cFrom=b.cFrom AND a.cTo=b.cTo AND b.tEffectivedate= DATE_ADD(a.tExpirationdate,INTERVAL 1 DAY);
            '''.format(cSessionID,cSessionID))
            Cursor.execute(cUpdateQuery)  

            cHeaderCountQueryRatesData =sql.read_sql( "SELECT count(hofr.iOceanFreightID) as iCount  FROM grdb_sessionHeader_OFR_{} AS hofr WHERE hofr.iStatus=0".format(cSessionID),Connection)
            cHeaderQueryRatesData = sql.read_sql ("SELECT hofr.*, hofr.iOceanFreightID AS iPrimaryKey FROM grdb_sessionHeader_OFR_{} AS hofr WHERE hofr.iStatus=0 ".format(cSessionID),Connection) 
            cChargesQueryRatesData = sql.read_sql("SELECT cofr.*,DATE_ADD(cofr.tExpirationdate , INTERVAL 1 DAY) as new_effective FROM grdb_OceanFreight_Charges_Write as cofr WHERE iOceanFreightID",Connection) 
            cChargegroup = "OFR"
            cFileName = logfile() ,'OFR_',{cCode10}, str(date.today()) , '.xlsx'.format(cCode10)
            cCutoff_Condition = " AND cofr.iActive IN(1,5)"


            # misssing data
            cHeaderCountQueryRatesData1 = sql.read_sql ('''SELECT count(iDashboardLandID) as iCount FROM grdb_Dashboard_Unique_Lanes  WHERE iStatus <= 2 AND iOFRExist = 1 AND cCustomeralias in {} AND cScaccodeOFR="{}"'''.format(cCode10,cMemberCode),Connection)
            cHeaderQueryRatesData1 = sql.read_sql ('''SELECT DISTINCT 0,0,cCustomeralias AS cCustomeralias,cScaccodeOFR AS cScaccode,
            cOriginRegioncode,cOriginCountrycode,cOriginUncode AS cOriginCFSUncode,cOriginUncode AS cOriginConsoleCFSUncode,cOriginUncode AS cOriginPortUncode,
            cDestinationRegioncode,cDestinationCountrycode,cDestinationUncode AS cDestinationCFSUncode,cDestinationUncode AS cDestinationDeconsoleCFSUncode,cDestinationUncode AS cDestinationPortUncode,
            cQuotingMemberOFR AS cQuotingMember, '-' AS iUploadlogID, '-' AS cRatebasis, '-' AS cFrom, '-' AS cTo, cOriginUncode, cDestinationUncode
            FROM grdb_Dashboard_Unique_Lanes  WHERE iStatus <= 2 AND iOFRExist = 1 
            AND cCustomeralias in {} AND cScaccodeOFR="{}";'''.format(cCode10,cMemberCode),Connection)

            Connection.commit()

            # Mapping
            iExpiredSoonRowCount = len(cHeaderCountQueryRatesData)
            iMissingRowCount = len(cHeaderCountQueryRatesData1)
            aReportType = str(iExpiredSoonRowCount)+"ExpiredSoon",str(iMissingRowCount)+"Missing"
            if(iExpiredSoonRowCount > 0 or iMissingRowCount > 0): 
                """
                if cFileName:
                    if os.touch(cFileName):
                        shutil.rmtree(cFileName)
                         writer = xlsxwriter.Workbook('pandas_simple.xlsx')
                    writer = tempfile.TemporaryDirectory(logfile())
                    writer= open(cFileName)
                """
                cVersion = '2.0'
                if (cChargegroup == "OFR"):
                    rateType = 'ocean_freight'
                    cScaccodeMissing = 'cOFRScaccode'
                    sheets = array(rateType)
                elif (cChargegroup == "FOB"):
                    rateType = 'fob'
                    cScaccodeMissing = 'cFOBScaccode'
                    sheets = array(rateType)
                elif (cChargegroup == "PLC"):
                    rateType = 'postlanding_charges'
                    cScaccodeMissing = 'cPLCScaccode'
                    sheets = array(rateType)
                for sKey in sheets.item():
                    aFileHeader = array()
                    cQuery = sql.read_sql_query('''SELECT cLabel FROM grdb_Spreadsheet_map WHERE cSpreadsheetname = "{}" AND 
                    cVersion = "{}"  AND iStatus >= 0 AND cDefault = 'Y' AND cRecordtype='H'  order by iSpreadsheetmapID;'''.format(rateType,cVersion),Connection)
                    RowHeader = len(cQuery)
                    if (cExportOption) == 1:
                        aFileHeader = "Currency"
                        print(aFileHeader)
                    

                   

                        


                    



                    
