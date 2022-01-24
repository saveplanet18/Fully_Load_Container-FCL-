<?php
/**
 *  
 *  This file is main page for import data.
 *
 *  @author      		Shipco Transport <info@shipco.com>
 *  @author      		Mayur Patil <mpatil@shipco.com>
 *  @copyright   		Shipco Transport
 *  @application name    <RAT>
 */
ini_set("memory_limit", -1);
ini_set('max_execution_time', 0);//set_time_limit(0);
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ERROR);
/* Session and Access control, has to be on every html & php page in order to maintain security */
/* But this should not be in the login page */

  /*if(!isset($_ENV["PHPWWA_DEFINEPATH"]))
  {
  echo "\nPlease set up Environment variable PHPWWA_DEFINEPATH Path to defines.php \n /var/www/html/....../wwa/include/php \n";
  exit(1);
  }

  if(!isset($_ENV["SERVER_HOST"]))
  {
  echo "\nPlease set up Environment variable SERVER_HOST Path to https://wwa.wwalliance.com \n";
  exit(1);
  }

  include_once($_ENV["PHPWWA_DEFINEPATH"] . "/defines.php");


  // */include_once("../../../../../include/php/defines.php");

include_once(SUITEINCLUDEDIR_PHPCLASS . "class.sql.php");
include_once(SUITEINCLUDEDIR_PHPCLASS . "class.abstract.sqlbase.php");
include_once(SUITEINCLUDEDIR_PHPCLASS . "class.mail.php");
include_once(SUITEINCLUDEDIR_PHPCLASS . "class.user.php");
require_once(GLOBALINCLUDEDIRWEBSITE . "PHPEXCEL/Classes/PHPExcel.php");
require_once(GLOBALINCLUDEDIRWEBSITE . "PHPEXCEL/Classes/PHPExcel/IOFactory.php");
require_once(GLOBALINCLUDEDIRWEBSITE . "PHPEXCEL/Classes/PHPExcel/Cell/AdvancedValueBinder.php");
require_once(FULLPATH . "include/amazons3/vendor/autoload.php");
require_once(GLOBALINCLUDEDIRWEBSITE . 'spoutLibExcelCsv/src/Spout/Autoloader/autoload.php');
include_once(SUITEINCLUDEDIR_PHPCLASS . "class.customercode.php");

use Box\Spout\Reader\ReaderFactory;
use Box\Spout\Writer\WriterFactory;
use Box\Spout\Common\Type;
use Box\Spout\Writer\Style\StyleBuilder;
use Box\Spout\Writer\Style\Color;
use Box\Spout\Writer\Style\Border;
use Box\Spout\Writer\Style\BorderBuilder;

$aSQLData['cDBSchema'] = READRIPLICA;
$layout = NAME . "_main";
$iUpdatedby = 28736;

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ERROR);

$cTempOKFile = TMPDIR . "grdb_Export_Excel_download_Cutoff_Report_log.ok";
if (file_exists($cTempOKFile)) {
    echo "Lock found";
    exit;
} else {
    //Creatre .OK file for Lock
    $content = "some text here";
    $fp = fopen($cTempOKFile, "wb");
    fwrite($fp, $content);
    fclose($fp);
    $cSessionID = uniqid();
    $dbHostMember = new SQL();
    $cSelectmemberQuery = "select distinct cCode from gen_Carrier where iStatus=0 and cScaccodeType='A'  ORDER BY cCode;";
    $dbHostMember->query($cSelectmemberQuery);
    $RowNumMember = $dbHostMember->getNumRows();
    $aCarrierCodes = $dbHostMember->getRows();
    $aCarrierCodes = json_decode(json_encode($aCarrierCodes), true);
    
    $dbHostExportExcel = new SQL();
    $cSelectPendingExports = "select cAliascode from gen_Customer_alias where iStatus=0 and cIsGrdb='Y' and cIsPrivate='N' and cIsGroup='N' and cIsSpecial='N' AND cCustomerType='global'  ORDER BY cAliascode ;";
    $dbHostExportExcel->query($cSelectPendingExports);
    $RowNumExportExcel = $dbHostExportExcel->getNumRows();
    $aCustomerList = $dbHostExportExcel->getRows();
    $aCustomerList = json_decode(json_encode($aCustomerList), true);
    $aMail = array();
    $cRateType = "OFR,FOB,PLC";
    $cExportOption=1;
    $aRateType = explode(',', $cRateType);
    if ($RowNumExportExcel > 0 && $RowNumMember > 0) {
            //$cMessage1 = "";            
            $zip1 = new ZipArchive();
            $cReportDir = TMPDIR."GRDBReport-".date('Y-m-d')."/";
            if (file_exists($cReportDir))
                removeExistingDirectory($cReportDir);

            mkdir($cReportDir, 0777);
            chmod($cReportDir, 0777);
            //for ($iIndex = 0; $iIndex < $RowNumExportExcel; $iIndex++) {
            foreach($aCarrierCodes as $cMmeberValue){
                    $cMemberCode = trim($cMmeberValue['cCode']);
                    $aMainFile = array();
                    foreach($aCustomerList as $oResultExportExcel){
                        $cCode = trim($oResultExportExcel['cAliascode']);
                        foreach ($aRateType as $cKey=>$cratetype) {
                                switch ($cratetype) {
                                    case 'FOB':
                                        //Expire to soon
                                        $dbHost11 = new SQL(); 
                                        $dropTable = "DROP TEMPORARY TABLE IF EXISTS grdb_sessionHeader_FOB_".$cSessionID.";";
                                        $dbHost11->query($dropTable);
                                        $cCreatetable1="CREATE TEMPORARY TABLE grdb_sessionHeader_FOB_".$cSessionID." 
                                        (iHeaderID INT(11) NOT NULL AUTO_INCREMENT,
                                        iFreightOnBoardID int(20) NOT NULL DEFAULT '0',
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
                                         PRIMARY KEY (`iHeaderID`),
                                         KEY `IX_iFreightOnBoardID` (`iFreightOnBoardID`),
                                         KEY `IX_iOriginregion` (`cOriginRegioncode`),
                                         KEY `IX_iDestinationregion` (`cDestinationRegioncode`),
                                         KEY `IX_iOriginregion_iDestinationregion` (`cOriginUncode`,`cDestinationUncode`)
                                       ) ENGINE=InnoDB "; 
                                        $dbHost11->query($cCreatetable1);

                                        $cSQLSessiontbl = "INSERT INTO grdb_sessionHeader_FOB_".$cSessionID."(iFreightOnBoardID,cQuotingMember,cCustomeralias,cScaccode,cOriginRegioncode,cOriginCFSUncode,cOriginConsoleCFSUncode,cOriginPortUncode,
                                        cTransshipment_1,cTransshipment_2,cTransshipment_3,cDestinationRegioncode,cDestinationPortUncode,cDestinationDeconsoleCFSUncode,cDestinationCFSUncode,
                                        cQuotingregion,cOriginUncode,cDestinationUncode) SELECT a.iFreightOnBoardID,a.cQuotingMember,a.cCustomeralias,a.cScaccode,a.cOriginRegioncode,a.cOriginCFSUncode,a.cOriginConsoleCFSUncode,a.cOriginPortUncode,
                                        a.cTransshipment_1,a.cTransshipment_2,a.cTransshipment_3,a.cDestinationRegioncode,a.cDestinationPortUncode,a.cDestinationDeconsoleCFSUncode,a.cDestinationCFSUncode,
                                        a.cQuotingregion,a.cOriginUncode,a.cDestinationUncode FROM grdb_FreightOnBoard_Write as a WHERE  a.iStatus=0  AND a.iActive=5 AND a.`cCustomeralias`='$cCode' AND a.`cScaccode`='$cMemberCode';";
                                         $dbHost11->query($cSQLSessiontbl);
                                         
                                        $cHeaderCountQueryRatesData = " SELECT count(hfob.iFreightOnBoardID) as iCount  FROM grdb_sessionHeader_FOB_".$cSessionID." AS hfob;";
                                        $cHeaderQueryRatesData = " SELECT hfob.*, hfob.iFreightOnBoardID AS iPrimaryKey FROM grdb_sessionHeader_FOB_".$cSessionID." AS hfob ";
                                        $cChargesQueryRatesData = " SELECT cfob.*,DATE_ADD(cfob.tExpirationdate , INTERVAL 1 DAY) as new_effective FROM `grdb_FreightOnBoard_Charges_Write` AS cfob 
                                        WHERE cfob.iFreightOnBoardID = ";
                                        $cChargegroup = "FOB";
                                        $cFileName = $cReportDir . 'FOB_'.$cCode.'_'. date('Ymdhis') . '.xlsx';    
                                        $cCutoff_Condition = " AND cfob.iActive IN(1,5)";
                                        
                                        
                                        //Missing
                                        $cHeaderCountQueryRatesData1="SELECT count(iDashboardLandID) as iCount FROM grdb_Dashboard_Unique_Lanes AS hfob WHERE hfob.iStatus <= 2 AND hfob.iFOBExist = 1 AND hfob.cCustomeralias='$cCode' AND hfob.cScaccodeFOB='$cMemberCode';";
                                        $cHeaderQueryRatesData1 = " SELECT DISTINCT 0,0,hfob.cCustomeralias AS cCustomeralias,hfob.cScaccodeFOB AS cScaccode,
                                        hfob.cOriginRegioncode,hfob.cOriginCountrycode,hfob.cOriginUncode AS cOriginCFSUncode,hfob.cOriginUncode AS cOriginConsoleCFSUncode,hfob.cOriginUncode AS cOriginPortUncode,
                                        hfob.cDestinationRegioncode,hfob.cDestinationCountrycode,hfob.cDestinationUncode AS cDestinationCFSUncode,hfob.cDestinationUncode AS cDestinationDeconsoleCFSUncode,hfob.cDestinationUncode AS cDestinationPortUncode,
                                        hfob.cQuotingMemberFOB AS cQuotingMember, '-' AS iUploadlogID, hfob.cOriginUncode, hfob.cDestinationUncode
                                        FROM grdb_Dashboard_Unique_Lanes AS hfob WHERE hfob.iStatus <= 2 AND hfob.iFOBExist = 1 
                                        AND hfob.cCustomeralias='$cCode' AND hfob.cScaccodeFOB='$cMemberCode' ";
                                        
                                        
                                        
                                        break;
                                    case 'PLC':
                                        //expire to soon
                                        $dbHost11 = new SQL();
                                        $dropTable = "DROP TEMPORARY TABLE IF EXISTS grdb_sessionHeader_PLC_".$cSessionID.";";
                                        $dbHost11->query($dropTable);
                                        $cCreatetable1="CREATE TEMPORARY TABLE grdb_sessionHeader_PLC_".$cSessionID." 
                                        (iHeaderID INT(11) NOT NULL AUTO_INCREMENT,
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
                                         PRIMARY KEY (`iHeaderID`),
                                         KEY `IX_iPostlandingID` (`iPostlandingID`),
                                         KEY `IX_iOriginregion` (`cOriginRegioncode`),
                                         KEY `IX_iDestinationregion` (`cDestinationRegioncode`),
                                         KEY `IX_iOriginregion_iDestinationregion` (`cOriginUncode`,`cDestinationUncode`)
                                       ) ENGINE=InnoDB "; 
                                        $dbHost11->query($cCreatetable1);

                                        $cSQLSessiontbl = "INSERT INTO grdb_sessionHeader_PLC_".$cSessionID."(iPostlandingID,cQuotingMember,cCustomeralias,cScaccode,cOriginRegioncode,cOriginCFSUncode,cOriginConsoleCFSUncode,cOriginPortUncode,
                                        cTransshipment_1,cTransshipment_2,cTransshipment_3,cDestinationRegioncode,cDestinationPortUncode,cDestinationDeconsoleCFSUncode,cDestinationCFSUncode,
                                        cQuotingregion,cOriginUncode,cDestinationUncode) SELECT a.iPostlandingID,a.cQuotingMember,a.cCustomeralias,a.cScaccode,a.cOriginRegioncode,a.cOriginCFSUncode,a.cOriginConsoleCFSUncode,a.cOriginPortUncode,
                                        a.cTransshipment_1,a.cTransshipment_2,a.cTransshipment_3,a.cDestinationRegioncode,a.cDestinationPortUncode,a.cDestinationDeconsoleCFSUncode,a.cDestinationCFSUncode,
                                        a.cQuotingregion,a.cOriginUncode,a.cDestinationUncode FROM grdb_Postlanding_Write as a  WHERE  a.iStatus=0  AND a.iActive=5 AND a.`cCustomeralias`='$cCode' AND a.`cScaccode`='$cMemberCode';";
                                         $dbHost11->query($cSQLSessiontbl);
                                         
                                        $cHeaderCountQueryRatesData = " SELECT  count(hplc.iPostlandingID) as iCount  FROM grdb_sessionHeader_PLC_".$cSessionID." AS hplc ;";
                                        
                                        $cHeaderQueryRatesData = " SELECT hplc.*, hplc.iPostlandingID AS iPrimaryKey FROM grdb_sessionHeader_PLC_".$cSessionID." AS hplc ";
                                        $cChargesQueryRatesData = " SELECT cplc.*,DATE_ADD(cplc.tExpirationdate , INTERVAL 1 DAY) as new_effective FROM  `grdb_Postlanding_Charges_Write` AS cplc 
                                        WHERE cplc.iPostlandingID = ";
                                        $cChargegroup = "PLC";
                                        $cFileName = $cReportDir . 'PLC_'.$cCode.'_'. date('Ymdhis') . '.xlsx';    
                                        $cCutoff_Condition = " AND cplc.iActive IN(1,5)";
                                        
                                        
                                        
                                        
                                        //Missing
                                        $cHeaderCountQueryRatesData1="SELECT count(iDashboardLandID) as iCount FROM grdb_Dashboard_Unique_Lanes as hplc WHERE hplc.iStatus <= 2 AND hplc.iPLCExist = 1  AND hplc.cCustomeralias='$cCode' AND hplc.cScaccodePLC='$cMemberCode';";
                                        $cHeaderQueryRatesData1 = " SELECT DISTINCT 0,0,hplc.cCustomeralias AS cCustomeralias,hplc.cScaccodePLC AS cScaccode,
                                        hplc.cOriginRegioncode,hplc.cOriginCountrycode,hplc.cOriginUncode AS cOriginCFSUncode,hplc.cOriginUncode AS cOriginConsoleCFSUncode,hplc.cOriginUncode AS cOriginPortUncode,
                                        hplc.cDestinationRegioncode,hplc.cDestinationCountrycode,hplc.cDestinationUncode AS cDestinationCFSUncode,hplc.cDestinationUncode AS cDestinationDeconsoleCFSUncode,hplc.cDestinationUncode AS cDestinationPortUncode,
                                        hplc.cQuotingMemberPLC AS cQuotingMember, '-' AS iUploadlogID, hplc.cOriginUncode, hplc.cDestinationUncode
                                        FROM grdb_Dashboard_Unique_Lanes AS hplc WHERE hplc.iStatus <= 2 AND hplc.iPLCExist = 1 
                                        AND hplc.cCustomeralias='$cCode' AND hplc.cScaccodePLC='$cMemberCode' ";
                                        
                                        break;
                                    case 'OFR':
                                        //expire to soon
                                        $dbHost11 = new SQL();
                                        $dropTable = "DROP TEMPORARY TABLE IF EXISTS grdb_sessionHeader_OFR_".$cSessionID.";";
                                        $dbHost11->query($dropTable);
                                        $cCreatetable1="CREATE TEMPORARY TABLE grdb_sessionHeader_OFR_".$cSessionID." 
                                        (iHeaderID INT(11) NOT NULL AUTO_INCREMENT,
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
                                        PRIMARY KEY (`iHeaderID`),
                                        KEY `IX_iOceanFreightID` (`iOceanFreightID`),
                                        KEY `IX_iOriginregion` (`cOriginRegioncode`),
                                        KEY `IX_iDestinationregion` (`cDestinationRegioncode`),
                                        KEY `IX_iOriginregion_iDestinationregion` (`cOriginUncode`,`cDestinationUncode`)
                                      ) ENGINE=InnoDB "; 
                                        $dbHost11->query($cCreatetable1);
                                        
                                        
                                        //Check future dated rates for cutoff charges OFR base charge
                                        $dbHost12 = new SQL();
                                        $dropTable1 = "DROP TEMPORARY TABLE IF EXISTS grdb_sessionHeader_OFR_Dup_".$cSessionID.";";
                                        $dbHost12->query($dropTable1);
                                        $cCreatetable2="CREATE TEMPORARY TABLE grdb_sessionHeader_OFR_Dup_".$cSessionID." 
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
                                        PRIMARY KEY (`iOFRHeaderID`),
                                        KEY `IX_iOceanFreightID1` (`iOceanFreightID`),
                                        KEY `IX_iOriginregion_iDestinationregion1` (`cOriginUncode`,`cDestinationUncode`)
                                      ) ENGINE=InnoDB "; 
                                        $dbHost12->query($cCreatetable2);
                                        
                                        $tTodatDate = date('Y-m-d');
                                        $cSQLSessiontb2 = "INSERT INTO grdb_sessionHeader_OFR_Dup_".$cSessionID."(iOceanFreightID,cCustomeralias,cScaccode,cOriginUncode,cDestinationUncode,cChargecode,cRatebasis,cFrom,cTo,tEffectivedate,tExpirationdate) SELECT a.iOceanFreightID,a.cCustomeralias,a.cScaccode,
                                        a.cOriginUncode,a.cDestinationUncode,a.cChargecode,a.cRatebasis,a.cFrom,a.cTo,a.tEffectivedate,a.tExpirationdate FROM grdb_OceanFreight_Write as a  WHERE  a.iStatus=0  AND a.iActive=1 AND a.`cCustomeralias`='$cCode' AND a.`cScaccode`='$cMemberCode' AND a.tExpirationdate >= '$tTodatDate' ;";
                                        $dbHost11->query($cSQLSessiontb2);
                                        
                                        $cSQLSessiontbl = "INSERT INTO grdb_sessionHeader_OFR_".$cSessionID."(iOceanFreightID,cQuotingMember,cCustomeralias,cScaccode,cOriginRegioncode,cOriginCFSUncode,cOriginConsoleCFSUncode,cOriginPortUncode,
                                        cTransshipment_1,cTransshipment_2,cTransshipment_3,cDestinationRegioncode,cDestinationPortUncode,cDestinationDeconsoleCFSUncode,cDestinationCFSUncode,
                                        cQuotingregion,cOriginUncode,cDestinationUncode,cCurrency,iOFRRate,cChargecode,cRatebasis,cFrom,cTo,iMinimum,iMaximum,cNotes,tEffectivedate,tExpirationdate) SELECT a.iOceanFreightID,a.cQuotingMember,a.cCustomeralias,a.cScaccode,a.cOriginRegioncode,a.cOriginCFSUncode,a.cOriginConsoleCFSUncode,a.cOriginPortUncode,
                                        a.cTransshipment_1,a.cTransshipment_2,a.cTransshipment_3,a.cDestinationRegioncode,a.cDestinationPortUncode,a.cDestinationDeconsoleCFSUncode,a.cDestinationCFSUncode,
                                        a.cQuotingregion,a.cOriginUncode,a.cDestinationUncode,a.cCurrency,a.iOFRRate,a.cChargecode,a.cRatebasis,a.cFrom,a.cTo,a.iMinimum,a.iMaximum,a.cNotes,a.tEffectivedate,a.tExpirationdate FROM grdb_OceanFreight_Write as a  WHERE  a.iStatus=0  AND a.iActive=5 AND a.`cCustomeralias`='$cCode' AND a.`cScaccode`='$cMemberCode';";
                                        $dbHost11->query($cSQLSessiontbl);
                                        
                                        
                                        $cUpdateQuery = "UPDATE grdb_sessionHeader_OFR_".$cSessionID." as a,grdb_sessionHeader_OFR_Dup_".$cSessionID." as b SET a.iStatus=-1
                                        WHERE a.cCustomeralias=b.cCustomeralias AND a.cOriginUncode=b.cOriginUncode AND a.cDestinationUncode =b.cDestinationUncode 
                                        AND a.cRatebasis=b.cRatebasis AND a.cFrom=b.cFrom AND a.cTo=b.cTo AND b.tEffectivedate= DATE_ADD(a.tExpirationdate,INTERVAL 1 DAY);";
                                        $dbHost11->query($cUpdateQuery);
                                        
                                        $cHeaderCountQueryRatesData = " SELECT count(hofr.iOceanFreightID) as iCount  FROM grdb_sessionHeader_OFR_".$cSessionID." AS hofr WHERE hofr.iStatus=0;";
                                        $cHeaderQueryRatesData = " SELECT hofr.*, hofr.iOceanFreightID AS iPrimaryKey FROM grdb_sessionHeader_OFR_".$cSessionID." AS hofr WHERE hofr.iStatus=0 ";
                                        $cChargesQueryRatesData = " SELECT cofr.*,DATE_ADD(cofr.tExpirationdate , INTERVAL 1 DAY) as new_effective FROM `grdb_OceanFreight_Charges_Write` as cofr WHERE iOceanFreightID = ";
                                        $cChargegroup = "OFR";
                                        $cFileName = $cReportDir . 'OFR_'.$cCode.'_'. date('Ymdhis') . '.xlsx';    
                                        $cCutoff_Condition = " AND cofr.iActive IN(1,5)";
                                        
                                        
                                        //Missing
                                        $cHeaderCountQueryRatesData1="SELECT count(iDashboardLandID) as iCount FROM grdb_Dashboard_Unique_Lanes  WHERE iStatus <= 2 AND iOFRExist = 1 AND cCustomeralias='$cCode' AND cScaccodeOFR='$cMemberCode';";
                                        $cHeaderQueryRatesData1 = " SELECT DISTINCT 0,0,cCustomeralias AS cCustomeralias,cScaccodeOFR AS cScaccode,
                                        cOriginRegioncode,cOriginCountrycode,cOriginUncode AS cOriginCFSUncode,cOriginUncode AS cOriginConsoleCFSUncode,cOriginUncode AS cOriginPortUncode,
                                        cDestinationRegioncode,cDestinationCountrycode,cDestinationUncode AS cDestinationCFSUncode,cDestinationUncode AS cDestinationDeconsoleCFSUncode,cDestinationUncode AS cDestinationPortUncode,
                                        cQuotingMemberOFR AS cQuotingMember, '-' AS iUploadlogID, '-' AS cRatebasis, '-' AS cFrom, '-' AS cTo, cOriginUncode, cDestinationUncode
                                        FROM grdb_Dashboard_Unique_Lanes  WHERE iStatus <= 2 AND iOFRExist = 1 
                                        AND cCustomeralias='$cCode' AND cScaccodeOFR='$cMemberCode' ";
                                        
                                        break;

                                    default:
                                    break;
                                }

                                $aSQLData['cDBSchema'] = READRIPLICA;
                                $dbHostCharge1 = new SQL($aSQLData);
                                $dbHostCharge1->query($cHeaderCountQueryRatesData);
                                $iExpiredSoonRowCount = $dbHostCharge1->getRow(0)->iCount;
                                $dbHostCharge2 = new SQL($aSQLData);
                                $dbHostCharge2->query($cHeaderCountQueryRatesData1);
                                $iMissingRowCount = $dbHostCharge2->getRow(0)->iCount;
                                $aReportType = array("ExpiredSoon"=>$iExpiredSoonRowCount,"Missing"=>$iMissingRowCount);
                                if($iExpiredSoonRowCount > 0 || $iMissingRowCount > 0){
                                    if (!empty($cFileName)) {
                                        if (file_exists($cFileName) == true)
                                            unlink($cFileName);

                                        $writer = WriterFactory::create(Type::XLSX);
                                        $writer->setTempFolder(TMPDIR);
                                        $writer->openToFile($cFileName);
                                        
                                        $cVersion = '2.0';
                                        $writeFlag = false;
                                        $border = (new BorderBuilder())
                                                ->setBorderBottom(Color::BLACK, Border::WIDTH_THIN, Border::STYLE_SOLID)
                                                ->build();
                                        $style = (new StyleBuilder())
                                                ->setFontName('Arial')
                                                ->setFontSize(11)
                                                ->setFontColor(Color::BLACK)
                                                ->setBackgroundColor(Color::LIGHT_BLUE)
                                                ->setBorder($border)
                                                ->build();
                                        if ($cChargegroup == 'OFR') {
                                            $rateType = 'ocean_freight';
                                            $cScaccodeMissing = 'cOFRScaccode';
                                            $sheets = array('ocean_freight');
                                        } elseif ($cChargegroup == 'FOB') {
                                            $rateType = 'fob';
                                            $cScaccodeMissing = 'cFOBScaccode';
                                            $sheets = array('fob');
                                        } elseif ($cChargegroup == 'PLC') {
                                            $rateType = 'postlanding_charges';
                                            $cScaccodeMissing = 'cPLCScaccode';
                                            $sheets = array('postlanding_charges');
                                        }

                                        foreach ($sheets as $sKey => $rateType) {
                                            $aFileHeader = array();
                                            $aSQLData['cDBSchema'] = READRIPLICA;
                                            $dbHost = new SQL($aSQLData);
                                            $cQuery = "SELECT cLabel FROM grdb_Spreadsheet_map WHERE cSpreadsheetname = '" . $rateType . "' AND 
                                            cVersion = '" . $cVersion . "' AND iStatus >= 0 AND cDefault = 'Y' AND cRecordtype='H'  order by iSpreadsheetmapID;";
                                            $dbHost->query($cQuery);
                                            $RowHeader = $dbHost->getRows();
                                            if ($cExportOption == 1){
                                                $aFileHeader[] = 'Office Code';
                                            }
                                            foreach ($RowHeader as $hkey => $sheetHeader) {
                                                $aFileHeader[] = $sheetHeader->cLabel;
                                            }

                                            $cQuery = "SELECT Distinct cTablefieldtext, cLabel FROM grdb_Spreadsheet_map WHERE cSpreadsheetname = '" . $rateType . "' AND 
                                            cVersion = '" . $cVersion . "' AND iStatus >= 0 AND cDefault = 'Y'  AND cRecordtype='D' AND cTablefieldtext !='' 
                                            ORDER By iColumnposition";
                                            $dbHost->query($cQuery);
                                            $RowHeader = $dbHost->getRows();

                                            $chargeSequence = array();
                                            foreach ($RowHeader as $hkey => $sheetHeader) {
                                                $aFileHeader[] = "Currency";
                                                $aFileHeader[] = $sheetHeader->cLabel;
                                                if (in_array($sheetHeader->cTablefieldtext, array('OFR', 'PRE', 'TOC'))) {
                                                    $aFileHeader[] = "Rate basis";
                                                    $aFileHeader[] = "From";
                                                    $aFileHeader[] = "To";
                                                } elseif (!in_array($sheetHeader->cTablefieldtext, array('CTAR'))) {
                                                    $aFileHeader[] = "Rate basis";
                                                }
                                                $aFileHeader[] = "Minimum";
                                                $aFileHeader[] = "Maximum";
                                                $aFileHeader[] = "Notes";
                                                $aFileHeader[] = "Effective Date";
                                                $aFileHeader[] = "Expiration Date";
                                                $chargeSequence[$sheetHeader->cTablefieldtext] = array_search($sheetHeader->cLabel, $aFileHeader);
                                            }
                                        }
                                        
                                        
                                        if (!empty($cHeaderQueryRatesData)) {
                                            foreach($aReportType as $cReportTypeKey=>$cReportVal){
                                            if($cReportTypeKey == "Missing"){
                                                $cExcelSheetName = "Missing";
                                                //$dbHostChargeDetails = new SQL($aSQLData);
                                                //$dbHostChargeDetails->query($cHeaderQueryRatesData1);
                                            }elseif($cReportTypeKey == "ExpiredSoon"){
                                                $cExcelSheetName = "Soon To Expire";
                                                //$dbHostChargeDetails = new SQL($aSQLData);
                                                //$dbHostChargeDetails->query($cHeaderQueryRatesData);
                                            }    
                                            $iRowCount = $cReportVal;
                                            if($iRowCount > 0){
                                                if($iExpiredSoonRowCount > 0 && $iMissingRowCount > 0){
                                                    if($cReportTypeKey == "Missing"){
                                                        $writer->addNewSheetAndMakeItCurrent()->setName($cChargegroup." ".$cExcelSheetName);
                                                        $writer->addRowWithStyle($aFileHeader, $style);
                                                    }else{
                                                        $writer->getCurrentSheet()->setName($cChargegroup." ".$cExcelSheetName);
                                                        $writer->addRowWithStyle($aFileHeader, $style);
                                                    }
                                                }else{
                                                    $writer->getCurrentSheet()->setName($cChargegroup." ".$cExcelSheetName);
                                                    $writer->addRowWithStyle($aFileHeader, $style);
                                                }
                                            $loopCount = ceil($iRowCount / 4);    
                                            for ($iloop = 0; $iloop <= $iRowCount; $iloop = $iloop + $loopCount) {
                                            //for ($i = 0; $i < $iRowCount; $i++) {
                                                if($cReportTypeKey == "Missing"){
                                                    $dbHostChargeDetails = new SQL($aSQLData);
                                                    $dbHostChargeDetails->query($cHeaderQueryRatesData1. " LIMIT $iloop, $loopCount");
                                                }elseif($cReportTypeKey == "ExpiredSoon"){
                                                    $dbHostChargeDetails = new SQL($aSQLData);
                                                    $dbHostChargeDetails->query($cHeaderQueryRatesData. " LIMIT $iloop, $loopCount");
                                                }
                                                $resultRowCount = $dbHostChargeDetails->getNumRows();
                                                if ($resultRowCount > 0) {
                                                    for ($i = 0; $i < $resultRowCount; $i++) {
                                                        $chargesValue = array();
                                                        $chargesDataList = array();
                                                        $excelRow = array();
                                                        $RowData = $dbHostChargeDetails->getRow($i);
                                                        if ($cExportOption == 1){
                                                            $chargesValue[] = $RowData->cQuotingMember;
                                                        }
                                                        $chargesValue[] = $RowData->cCustomeralias;
                                                        $chargesValue[] = $RowData->cScaccode;
                                                        $chargesValue[] = $RowData->cOriginRegioncode;
                                                        $chargesValue[] = $RowData->cOriginCFSUncode;
                                                        $chargesValue[] = $RowData->cOriginConsoleCFSUncode;
                                                        $chargesValue[] = $RowData->cOriginPortUncode;
                                                        $chargesValue[] = $RowData->cTransshipment_1;
                                                        $chargesValue[] = $RowData->cTransshipment_2;
                                                        $chargesValue[] = $RowData->cTransshipment_3;
                                                        $chargesValue[] = $RowData->cDestinationRegioncode;
                                                        $chargesValue[] = $RowData->cDestinationPortUncode;
                                                        $chargesValue[] = $RowData->cDestinationDeconsoleCFSUncode;
                                                        $chargesValue[] = $RowData->cDestinationCFSUncode;
                                                        $chargesValue[] = $RowData->cQuotingregion;
                                                        if ($cChargegroup == 'OFR') {
                                                            $chargesValue[] = $RowData->cTransittime;
                                                            $chargesDataList[$RowData->cChargecode][] = $RowData;
                                                        }

                                                        if($cReportTypeKey == "Missing"){
                                                            $chargeCount = 0;
                                                        }else{
                                                            $dbHostCharge = new SQL($aSQLData);
                                                            $cQueryCharge = $cChargesQueryRatesData . " " . $RowData->iPrimaryKey . " AND iStatus=0 " . $cCutoff_Condition ."ORDER BY iActive ASC;" ;
                                                            $dbHostCharge->query($cQueryCharge);
                                                            $chargeCount = $dbHostCharge->getNumRows();
                                                        }
                                                        if ($chargeCount > 0) {
                                                            $writeFlag = true;
                                                            $aTmpArray = array();
                                                            for ($k = 0; $k < $chargeCount; $k++) {
                                                                $chargeDatadb = $dbHostCharge->getRow($k);
                                                                if($chargeDatadb->iActive == 5 && count($aTmpArray[trim(strtoupper($chargeDatadb->cChargecode))."_".trim(strtoupper($chargeDatadb->cRatebasis))."_".$chargeDatadb->new_effective]) < 1){
                                                                    $chargesDataList[$chargeDatadb->cChargecode][] = $chargeDatadb;
                                                                }else{
                                                                    $aTmpArray[trim(strtoupper($chargeDatadb->cChargecode))."_".trim(strtoupper($chargeDatadb->cRatebasis))."_".$chargeDatadb->tEffectivedate][] = $chargeDatadb;
                                                                }
                                                            }
                                                            unset($aTmpArray);
                                                        }
                                                        if (count($chargesDataList) > 0 || $cReportTypeKey == "Missing") {
                                                            foreach ($chargeSequence as $csKey => $colPos) {
                                                                $excelRowIndex = 0;
                                                                if (isset($chargesDataList[$csKey]) && count($chargesDataList[$csKey]) > 0) {
                                                                    foreach ($chargesDataList[$csKey] as $cKey => $chargeData) {
                                                                        if (in_array($chargeData->cChargecode, array('OFR', 'PRE', 'TOC'))) {
                                                                            $excelRow[$excelRowIndex][$colPos - 1] = $chargeData->cCurrency;
                                                                            $excelRow[$excelRowIndex][$colPos] = $chargeData->iOFRRate;
                                                                            $excelRow[$excelRowIndex][$colPos + 1] = $chargeData->cRatebasis;
                                                                            $excelRow[$excelRowIndex][$colPos + 2] = $chargeData->cFrom;
                                                                            $excelRow[$excelRowIndex][$colPos + 3] = $chargeData->cTo;
                                                                            $excelRow[$excelRowIndex][$colPos + 4] = $chargeData->iMinimum;
                                                                            $excelRow[$excelRowIndex][$colPos + 5] = $chargeData->iMaximum;
                                                                            $excelRow[$excelRowIndex][$colPos + 6] = $chargeData->cNotes;
                                                                            $excelRow[$excelRowIndex][$colPos + 7] = $chargeData->tEffectivedate;
                                                                            $excelRow[$excelRowIndex][$colPos + 8] = $chargeData->tExpirationdate;
                                                                        } elseif (in_array($chargeData->cChargecode, array('CTAR'))) {
                                                                            $excelRow[$excelRowIndex][$colPos - 1] = $chargeData->cCurrency;
                                                                            $excelRow[$excelRowIndex][$colPos] = $chargeData->iRate;
                                                                            $excelRow[$excelRowIndex][$colPos + 1] = $chargeData->iMinimum;
                                                                            $excelRow[$excelRowIndex][$colPos + 2] = $chargeData->iMaximum;
                                                                            $excelRow[$excelRowIndex][$colPos + 3] = $chargeData->cNotes;
                                                                            $excelRow[$excelRowIndex][$colPos + 4] = $chargeData->tEffectivedate;
                                                                            $excelRow[$excelRowIndex][$colPos + 5] = $chargeData->tExpirationdate;
                                                                        } else {
                                                                            $excelRow[$excelRowIndex][$colPos - 1] = $chargeData->cCurrency;
                                                                            $excelRow[$excelRowIndex][$colPos] = $chargeData->iRate;
                                                                            $excelRow[$excelRowIndex][$colPos + 1] = $chargeData->cRatebasis;
                                                                            $excelRow[$excelRowIndex][$colPos + 2] = $chargeData->iMinimum;
                                                                            $excelRow[$excelRowIndex][$colPos + 3] = $chargeData->iMaximum;
                                                                            $excelRow[$excelRowIndex][$colPos + 4] = $chargeData->cNotes;
                                                                            $excelRow[$excelRowIndex][$colPos + 5] = $chargeData->tEffectivedate;
                                                                            $excelRow[$excelRowIndex][$colPos + 6] = $chargeData->tExpirationdate;
                                                                        }
                                                                        $excelRowIndex++;
                                                                    }
                                                                } else {
                                                                    $excelRow[$excelRowIndex][$colPos - 1] = "";
                                                                    $excelRow[$excelRowIndex][$colPos] = "";
                                                                    if (in_array($csKey, array('OFR', 'PRE', 'TOC'))) {
                                                                        $excelRow[$excelRowIndex][$colPos + 1] = "";
                                                                        $excelRow[$excelRowIndex][$colPos + 2] = "";
                                                                        $excelRow[$excelRowIndex][$colPos + 3] = "";
                                                                        $excelRow[$excelRowIndex][$colPos + 4] = "";
                                                                        $excelRow[$excelRowIndex][$colPos + 5] = "";
                                                                        $excelRow[$excelRowIndex][$colPos + 6] = "";
                                                                        $excelRow[$excelRowIndex][$colPos + 7] = "";
                                                                        $excelRow[$excelRowIndex][$colPos + 8] = "";
                                                                    } elseif (in_array($csKey, array('CTAR'))) {
                                                                        $excelRow[$excelRowIndex][$colPos + 1] = "";
                                                                        $excelRow[$excelRowIndex][$colPos + 2] = "";
                                                                        $excelRow[$excelRowIndex][$colPos + 3] = "";
                                                                        $excelRow[$excelRowIndex][$colPos + 4] = "";
                                                                        $excelRow[$excelRowIndex][$colPos + 5] = "";
                                                                    } else {
                                                                        $excelRow[$excelRowIndex][$colPos + 1] = "";
                                                                        $excelRow[$excelRowIndex][$colPos + 2] = "";
                                                                        $excelRow[$excelRowIndex][$colPos + 3] = "";
                                                                        $excelRow[$excelRowIndex][$colPos + 4] = "";
                                                                        $excelRow[$excelRowIndex][$colPos + 5] = "";
                                                                        $excelRow[$excelRowIndex][$colPos + 6] = "";
                                                                    }
                                                                }
                                                            }
                                                            if (count($excelRow) > 0) {
                                                                foreach ($excelRow as $key => $eRowData) {
                                                                    $excelRowWrite = array();
                                                                    $fillZeroArray = array();
                                                                    $OFRValues = array();
                                                                    if ($key == 0) {
                                                                        $excelRowWrite = array_replace($chargesValue, $eRowData);
                                                                    } else {
                                                                        if ($cChargegroup == "OFR") {
                                                                            $diffKey = array_diff_key($excelRow[0], $eRowData);
                                                                            reset($diffKey);
                                                                            $first_key = key($diffKey);
                                                                            end($diffKey);
                                                                            $last_key = key($diffKey);
                                                                            $OFRkeys = array($chargeSequence['OFR'] - 1, $chargeSequence['OFR'], $chargeSequence['OFR'] + 1, $chargeSequence['OFR'] + 2, $chargeSequence['OFR'] + 3, $chargeSequence['OFR'] + 4, $chargeSequence['OFR'] + 5, $chargeSequence['OFR'] + 6, $chargeSequence['OFR'] + 7, $chargeSequence['OFR'] + 8);
                                                                            $fillZeroArray = array_fill($first_key, ($last_key - $first_key) + 1, null);
                                                                            $OFRValues = array_intersect_key($excelRow[0], array_flip($OFRkeys));
                                                                            $fillArray = array_replace($fillZeroArray, $OFRValues);
                                                                            $fillArray = array_replace($fillArray, $eRowData);
                                                                        } else {
                                                                            $diffKey = array_diff_key($excelRow[0], $eRowData);
                                                                            if (count($diffKey) > 0) {
                                                                                reset($diffKey);
                                                                                $first_key = key($diffKey);
                                                                                end($diffKey);
                                                                                $last_key = key($diffKey);
                                                                                $fillZeroArray = array_fill($first_key, ($last_key - $first_key) + 1, null);
                                                                                $fillArray = array_replace($fillZeroArray, $eRowData);
                                                                            } else {
                                                                                $fillArray = $eRowData;
                                                                            }
                                                                        }
                                                                        $excelRowWrite = array_replace($chargesValue, $fillArray);
                                                                    }
                                                                    ksort($excelRowWrite);
                                                                    if (!empty($excelRowWrite)) {
                                                                        $writer->addRow($excelRowWrite);
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    } 
                                                }
                                            }
                                            }

                                        }
                                    }

                                            $writer->close();
                                            unset($writer);
                                            $aMainFile["Customer_".$cratetype."_".$cMemberCode."_".$cCode] = $cFileName;
                                        }

                                    }
                                    
                            }
                        
                        /*if(!empty($aMainFile)){
                            $zip = new ZipArchive();
                            $zipFileName = $cMemberCode."_". date('Ymdhis') . ".zip";
                            $cZipNameWithpath = $cReportDir . $zipFileName;
                            $zip->open($cZipNameWithpath, ZIPARCHIVE::CREATE);
                            foreach ($aMainFile as $key => $value) {
                                $arr = explode("GRDBReport-".date('Y-m-d')."/",$value);
                                    $zip->addFile($value,$arr[1]);
                                //unlink($value);
                            }
                            $zip->close();
                            
                            $arr1 = explode("GRDBReport-".date('Y-m-d')."/",$cZipNameWithpath);
                            $zip1->addFile($cZipNameWithpath,$arr1[1]);
                            //unlink($cZipNameWithpath);
                        }*/
                        
                    }
                    
                    if(!empty($aMainFile)){
                            $zip = new ZipArchive();
                            $zipFileName = $cMemberCode."_". date('Ymdhis') . ".zip";
                            $cZipNameWithpath = $cReportDir . $zipFileName;
                            $zip->open($cZipNameWithpath, ZIPARCHIVE::CREATE);
                            foreach ($aMainFile as $key => $value) {
                                $arr = explode("GRDBReport-".date('Y-m-d')."/",$value);
                                $zip->addFile($value,$arr[1]);
                            }
                            $zip->close();
                            
                            //$arr1 = explode("GRDBReport-".date('Y-m-d')."/",$cZipNameWithpath);
                            //$zip1->addFile($cZipNameWithpath,$arr1[1]);
                            //unlink($cZipNameWithpath);
                        }
            }
            
            $cZipfiles = glob($cReportDir."*.zip");
            $cMainFileName = 'GRDBExportExcel_Missing_ExpireSoon_Report_'.date('Ymdhis') . '.zip';
            $cMainZipFilePath = $cReportDir.$cMainFileName;
            $zip1->open($cMainZipFilePath, ZIPARCHIVE::CREATE);
            foreach($cZipfiles as $cZipkey=>$cZipVal){
                $arr1 = explode("GRDBReport-".date('Y-m-d')."/",$cZipVal);
                if($arr1[1] != $cMainFileName){
                    $zip1->addFile($cZipVal,$arr1[1]);
                }
            }
            $zip1->close();
            if(file_exists($cMainZipFilePath)){
                $s3Filepath = '';
                $cDownloadS3FilePath = '';
                $cExportfileName = "Dashboard_download/" . date('Y-m-d') . "/" . $cMainFileName;
                if (file_exists($cMainZipFilePath)) {
                    $s3Filepath = MoveFiletoS3QuotePDF($cExportfileName, $cMainZipFilePath, $cMainFileName);
                    if (!empty($s3Filepath) && $s3Filepath != '') {
                        $cDownloadS3FilePath = S3HTTPPATH . "wwaonline/rat/global_revamp/downloadExcel.php?filepath=" . base64_encode($s3Filepath) . "&cFilename=" . base64_encode($zipFileName);
                    }
                }
                echo $cMessage1 = "
                Your requested Rate Excel of Missing and Soon to Expire GRDB Charges Report has been generated.<BR>
                Please <a href='" . $cDownloadS3FilePath . "'> click here to download Rate Excel File</a>. <br><br>";

                global $cDefaultfromaddress;
                $cSubject = 'Missing and Soon to Expire GRDB Charges Report - '.date("Y-m-d");
                $cMessage = "Dear User , <BR>".$cMessage1;

                $layout = NAME . "_main";
                $oEmail = new Mail();
                $oEmail->setFrom($cDefaultfromaddress);
                $oEmail->add("TO", "apalsande@shipco.com");
                $oEmail->add("CC", "dsubedar@shipco.com,sravidaran@wwalliance.com,oganbhoj@shipco.com");
                $oEmail->setSubject($cSubject);
                $oEmail->setBodyTitle("Missing and Soon to Expire GRDB Charges Report - ".date("Y-m-d"));
                $oEmail->setBodyMessage($cMessage);
                $oEmail->setType("htmlwithattachment");
                $oEmail->setPriority("Urgent");
                $oEmail->setLayout($layout);
                $oEmail->SendEmail();
            }
    }
    unlink($cMainZipFilePath);
    unlink($cTempOKFile);
    removeExistingDirectory($cReportDir);
}

function MoveFiletoS3QuotePDF($cQuotefileName, $file_name, $cFileNameNew) {
    $cAWSpath = AWSFOLDER . $cQuotefileName;
    $config1 = parse_ini_file(FULLPATH . "include/amazons3/src/config.ini", true);
    $awsAccessId = $config1["s3"]["access_key_id"];
    $awsAccessKey = $config1["s3"]["secret_access_key"];
    $amazons3 = new \JLaso\S3Wrapper\S3Wrapper($awsAccessId, $awsAccessKey, AWSS3BUCKET, AWSREGION);

    $amazons3->saveFile($cAWSpath, file_get_contents($file_name));
    $checkFile = $amazons3->checkFileExist(AWSS3BUCKET, $cAWSpath);

    if ($checkFile) {
        return $cAWSpath;
    } else {
        MoveFiletoS3QuotePDF($cQuotefileName, $file_name, $cFileNameNew);
    }
}

function removeExistingDirectory($cDirPath, $cFileName = "") {
    $cFullPath = $cDirPath . $cFileName;

    if (is_dir($cFullPath)) {
        $cFullPath = rtrim($cFullPath, "/");
        $cFullPath = $cFullPath . "/";

        if ($dh = opendir($cFullPath)) {
            while (($cNextFileName = readdir($dh)) !== false) {
                if ($cNextFileName != "." && $cNextFileName != "..")
                    $aFileArray = removeExistingDirectory($cFullPath, $cNextFileName);
            }
            closedir($dh);
        }
        rmdir($cFullPath);
    }
    else {
        unlink($cFullPath);
    }
    return true;
}
?>
