
#
# $Id: DB.pm,v 1.30 2019/12/05 06:24:39 pkokate Exp $
#

=head1 NAME

wwa::EI::BookingRequest::Export::DB

=head1 DESCRIPTION

This module store data from hash in Database  

=head1 AUTHOR

By rpatra@shipco.com

=head1 DATE

2012-02-24

=cut

package wwa::EI::BookingRequest::Export::DB;
eval('use wwa::Error');
die "Cannot use package. $@" if ($@);

eval('
		use wwa::EI::BookingRequest::Export;
		use wwa::EI::Envelope;
		use wwa::DO::Member;
		use wwa::DO::GenProgram;
		use wwa::DO::MemberSetting;
		use wwa::DO::Booking;
		use wwa::DO::Shipment;
		use wwa::DO::Status;
		use wwa::DO::Location;
		use wwa::DBI;
		use wwa::DO::CustomerCodeMap;
		use wwa::DO::weiAdditionalbookinginfo;
		use Time::Piece;
		');
handleError(10102, "$@") if ($@);
eval('
		use POSIX qw(strftime);
		');
handleError(10101, "$@") if ($@);

@ISA = qw{wwa::EI::BookingRequest::Export wwa::BaseDomainObject};

sub commit
{

	my $self = shift;
	my $cDetails = $self->{_details}->[0];
	# Added condition for member to member booking for Mission 27675 by vthakre 2017-20-28.
	if ($cDetails->{cBookingType} eq 'C')
	{
		# Added code get value of origin and destination to pass in getMemberID stored procedure undre Mission 28095 by vthakre, 2017-11-29.
		my $cOrigin = ($cDetails->getOrigin) ? $cDetails->getOrigin : $cDetails->getPortOfLoading;
		my $cDestination = ($cDetails->getDestination) ? $cDetails->getDestination : $cDetails->getPortOfDischarge;	

		#Added a subroutine to get Orign's and destination's Member ID, by schavan 2014-11-26 for mission 16495
		($cDetails->{iExportOwnerID}, $cDetails->{iImportOwnerID}) = $self->getOrgDestMemberID($cOrigin, $cDestination);
	
		#Added code to re-initialize iExportOwnerID if settings available for specific customers for mission 30355 by pkokate, 19 july 2019 
		my $oSetting = wwa::DO::MemberSetting->new();
                my $hSetting = $oSetting->getSettings($cDetails->{MemberDetail}->{iMemberID},$cDetails->{iProgramID});
		if(defined($hSetting->{CustomerControlCode_map}) && $hSetting->{CustomerControlCode_map} eq 'Y')
		{
		 	$cDetails->{iExportOwnerID} = $cDetails->{Officedetails}->{iMemberID};
		}

	}
	elsif ($cDetails->{cBookingType} eq 'M')
	{
		($cDetails->{iExportOwnerID}, $cDetails->{iImportOwnerID}) = ($cDetails->{MemberDetail}->{iMemberID}, $cDetails->{Officedetails}->{iMemberID});
	}

	my $iShipmentID;
	my $iProgramID = $cDetails->{iProgramID};

	my $oCustMap     = wwa::DO::CustomerCodeMap->new();
	my @aCustAlias   = $oCustMap->getCustomerCode($cDetails->getUserID,'BKG','cmsalias');

	# Remove metadata logging code for booking request module and put it into XML.pm for bug 10368
	# Modified the code to handle Request Type C for bug 11694 by rpatra.

	# Set CusttomerAlias in self for Mission 25860 by msawant
	$self->{cCustomerAlias}= $aCustAlias[0];	
	if ($cDetails->getRequestType eq 'N')
	{
		$cStatusCode = '5';
		$iShipmentID = $self->shipmentdetails($cDetails);
		$self->bookingdetails($cDetails,$iShipmentID);	
		$self->statusdetails($cDetails,$iShipmentID);
		$self->locationdetails($cDetails,$iShipmentID);
		# Set ShipmentID in self for Mission 25860 by msawant
		$self->{iShipmentID} = $iShipmentID;
	}
	elsif ($cDetails->getRequestType eq 'C')
	{
		$cStatusCode = '11';
		my $oBooking = wwa::DO::Booking->new();
		my $hBookingDetails = $oBooking->getWWWAReferenceDetails('cWWAReference',$cDetails->getBookingNumID);
		$self->statusdetails($cDetails,$hBookingDetails->getShipmentID);
		# Set ShipmentID in self for Mission 25860 by msawant
		$self->{iShipmentID} = $hBookingDetails->getShipmentID;
		# Added code to send aperak for Mission 281888 by vthakre, 2017-11-07.
		$self->{BookingNumber} = $hBookingDetails->getBookingnumber if (defined($hBookingDetails->getBookingnumber) && $hBookingDetails->getBookingnumber ne '');
	}
	
	#Added the code to set iShipmentID for request type U for mission 26695 by vpatil on 18-04-2016
        elsif ($cDetails->getRequestType eq 'U')
        {
                my $oBooking = wwa::DO::Booking->new();
                my $hBookingDetails = $oBooking->getWWWAReferenceDetails('cWWAReference',$cDetails->getBookingNumID);
                $self->{iShipmentID} = $hBookingDetails->getShipmentID;
		# Added code to send aperak for Mission 281888 by vthakre, 2017-11-07.
		$self->{BookingNumber} = $hBookingDetails->getBookingnumber if (defined($hBookingDetails->getBookingnumber) && $hBookingDetails->getBookingnumber ne '');
        }
        #Mission 30390 : Added support to store leg information in different table by smadhukar on 28-June-2019
        if(defined($cDetails->{cLegInfo}) && $cDetails->{cLegInfo} ne '')
        {
        	my $oAdditionalInfo = wwa::DO::weiAdditionalbookinginfo->new();
        	
        	$oAdditionalInfo->setLegInfo($cDetails->{cLegInfo});
        	$oAdditionalInfo->setBookingNumID($cDetails->getBookingNumID);
        	$oAdditionalInfo->addInfo;
        	
        }

}

sub bookingdetails
{
	my ($self,$details,$iShipmentID)= @_;	
	my $detailsLineItems = $details->{_lineItems}->{data}->[0];

	my $oBooking = wwa::DO::Booking->new();
	$oBooking->setShipmentID($iShipmentID);
	$oBooking->setBookingSeq($details->getBookingNumID);
	$oBooking->setWWAreference($details->getBookingNumID);
	$oBooking->setVoyageno($details->getVoyage);
	$oBooking->setVesselName($details->getVesselName);
	$oBooking->setType("L");
	$oBooking->setHeader("L C L   B O O K I N G   C O N F I R M A T I O N");
	$oBooking->setHazardous($details->getHazardous);
	$oBooking->setUom($detailsLineItems->getUom) if (defined($detailsLineItems));
	$oBooking->setUserID($details->getUserID);
	$oBooking->setReceived("WE");
	# Added two new fields iExportOwnerID, iImportOwnerID to store in 'tra_Bok_header' table, by schavan 2014-11-26 mission 16495
	$oBooking->setExportOwnerID($details->{iExportOwnerID});
	$oBooking->setImportOwnerID($details->{iImportOwnerID});
	$oBooking->addBooking();
	$self->setBookingID($oBooking->{iBookingID});
	return($oBooking);

}

sub shipmentdetails
{
	my ($self,$details)= @_;
	my $detailsLineItems = $details->{_lineItems}->{data}->[0];

	my $oShipment = wwa::DO::Shipment->new();
	# Added field cWWAreference to store in tra_shipment table by sdalai for mission 28075 on 26-09-2017.
	$oShipment->setWWAreference($details->getBookingNumID);
	$oShipment->generateShipmentID unless($oShipment->getShipmentNo ne '');
	$oShipment->add unless ($oShipment->getShipmentID > 0);
	
	$bRetval = $oShipment->getShipmentID;
	return($bRetval);
	
}

sub statusdetails
{
	my ($self,$details,$iShipmentID)= @_;	
	my $detailsLineItems = $details->{_lineItems}->{data}->[0];

	my $oStatus = wwa::DO::Status->new();
	$oStatus->setShipmentID($iShipmentID);
	
	# Removed code to set booking number in tra_Status table for mission 26791 by msawant.

	# Modified the code to handle Request Type C for bug 11694 by rpatra.	
	if($details->getRequestType eq 'C')
	{
		#Added code to check booking type and set status code 15 for customer booking cancel for jira wwa-553 by pkokate on 4 dec 2019
		if($details->{cBookingType} eq 'M')
		{
			$oStatus->setANSICode('11');
                        $oStatus->setNextstatuscode('0');
		}
		elsif($details->{cBookingType} eq 'C')
		{
			$oStatus->setANSICode('9');
			$oStatus->setNextstatuscode('0');
		}
	}
	else 
	{
	        # Changed the Status code from '05' to '5' for bug 13458 by rpatra
		$oStatus->setANSICode('5');
		$oStatus->setNextstatuscode('10');
	}
	$oStatus->setLocation($details->getOrigin);
	$oStatus->setStatus('1');
	#Added code to set current date as status date for jira wwa-553 by pkokate on 4 dec 2019
	my $tDate = Time::Piece->new;
	$oStatus->setStatusDate($tDate->ymd);
	$oStatus->_save;
	return($oStatus);
}

sub processLocation
{
	my ($self, $cType,$cTableName,$cParentKey,$iParentKeyID, $cUncode, $tEstTime, $shipmentID) = @_;
	my $oLocation = wwa::DO::Location->new;
	my $cCode = '';
	my $iLocationId = 0;
	if (defined($cUncode) && $cUncode ne '')
	{
		$cCode = substr ($cUncode,2,3);
		$oLocation->setShipcoLocationID($self->getShipcoLocationID($cCode,$cUncode));
		$oLocation->setUNLocationID($self->getUNLocationID($cUncode));
		$oLocation->setESTime($tEstTime);
		$oLocation->setShipmentID($shipmentID);
		$oLocation->setType($cType);

		$oLocation->add($oLocation->setShipmentID($shipmentID));
		$iLocationId = $oLocation->getLocationID;
		$ENV{app}->verbose(8, "Processing Location: " . $oLocation->getLocationID);
		$oLocation->createChildLink($cTableName,$cParentKey,"iLocationID",$iParentKeyID,$iLocationId);
	}
	return($iLocationId);
}

sub locationdetails
{
	my ($self,$details,$iShipmentID)= @_;	
	my $detailsLineItems = $details->{_lineItems}->{data}->[0];

	# Modified the code to store the LOD, DIS and there Estimated times in database for mission 16416 by rpatra
	my $cOrigin = $details->getOrigin;
	my $cDestination = (defined($details->getFinalDestination) && $details->getFinalDestination ne '') ? $details->getFinalDestination : $details->getDestination;
	my $cPortOfLoading = (defined($details->getPortOfLoading) && $details->getPortOfLoading ne '') ? $details->getPortOfLoading : $cOrigin;
	my $cPortOfDischarge = (defined($details->getPortOfDischarge) && $details->getPortOfDischarge ne '') ? $details->getPortOfDischarge : $cDestination;

	my $tLOD = (defined($details->getETSPoL) && $details->getETSPoL ne '') ? $details->getETSPoL : ((defined($details->getCutoff) && $details->getCutoff ne '') ? $details->getCutoff : $details->getETD);

	my @aLocation = ();
	my @aType = ('ORG','LOD','DIS','DST');
	foreach my $cType(@aType)
	{
		if ($details->getBookingID)
		{
			if($cType eq 'ORG')
			{
				push(@aLocation, $self->processLocation($cType,'tra_Bok_location_link','iBookingID',$self->getBookingID,$cOrigin,$details->getETD,$iShipmentID));
			}
		        elsif($cType eq 'LOD')
		        {
				push(@aLocation, $self->processLocation($cType,'tra_Bok_location_link','iBookingID',$self->getBookingID,$cPortOfLoading,$tLOD,$iShipmentID));
		        }
		        elsif($cType eq 'DIS')
		        {
				push(@aLocation, $self->processLocation($cType,'tra_Bok_location_link','iBookingID',$self->getBookingID,$cPortOfDischarge,$details->getETA,$iShipmentID));
		        }
			elsif($cType eq 'DST')
			{
				push(@aLocation, $self->processLocation($cType,'tra_Bok_location_link','iBookingID',$self->getBookingID,$cDestination,$details->getETA,$iShipmentID));
			}
		}
	}
}

sub getShipcoLocationID
{
	my ($self, $cCode, $cUNCode) = @_;
	my $retval = 0;
	my $oDbh = wwa::DBI->new();
	my $cQuery = "SELECT iShipcoLocationID FROM gen_Shipco_location WHERE " .
	"(cCode= '".$cCode."' AND cCode IS NOT NULL AND cCode !='' ) OR " .
	"(cUNCode= '".$cUNCode."' AND cUNCode IS NOT NULL AND cUNCode!='') LIMIT 1";
	my $cSth = $oDbh->prepare($cQuery) || handleError(10202, $oDbh->errstr . "\n" . $cQuery);
	$cSth->execute() || handleError(10203, "$cQuery (" . $cSth->errstr . ")");

	my $row = $cSth->fetchrow_hashref;

	$retval = $row->{iShipcoLocationID};

	$cSth->finish;

	return($retval);
}

sub getUNLocationID
{
	my ($self, $cUNCode) = @_;
	my $retval = 0;
	my $oDbh = wwa::DBI->new();
	# Added gen_Location.iStatus >= 0 condtion for Mission 25664 by adhanwde
	my $cQuery = "SELECT ilocationid FROM gen_Location WHERE cCode='".$cUNCode."' AND iStatus >= 0";
	my $cSth = $oDbh->prepare($cQuery) || handleError(10202, $oDbh->errstr . "\n" . $cQuery);
	$cSth->execute() || handleError(10203, "$cQuery (" . $cSth->errstr . ")");

	my $row = $cSth->fetchrow_hashref;
	$retval = $row->{ilocationid};

	$cSth->finish;

	return($retval);
}

sub setBookingID
{
	my $self = shift;
	my $cNewvalue = shift;
	$self->{_BookingID} = $cNewvalue if (defined($cNewvalue));
	return($self->getBookingID);
}

sub getBookingID
{
	my $self = shift;
	my $retval = "";
	$retval = $self->{_BookingID} if (defined($self->{_BookingID}));
	return($retval);
}

=head1

This subroutine will call the procedure getMemberID will return the handling Origin MemberID and destination MemberID.
By schavan 2014-11-26 for mission 16495

=cut

sub getOrgDestMemberID
{
        my ($self, $cOriginCode, $cDestinationCode) = @_;

        my $oDbh = wwa::DBI->new();
        my $cQuery = 'CALL getMemberID (?,?,@a,@b);';
        my $cSth = $oDbh->prepare($cQuery) || handleError(10202,"$cQuery (" .$oDbh->errstr. ")");

        $cSth->execute($cOriginCode,$cDestinationCode) || handleError(10203, "$cQuery (" . $cSth->errstr . ")");

        my @aResult = $oDbh->selectrow_array('select @a,@b');
        my ($iOrgMemberID,$iDestMemberID) = @aResult;

        return ($iOrgMemberID,$iDestMemberID);
}

1;

#
# $Log: DB.pm,v $
# Revision 1.30  2019/12/05 06:24:39  pkokate
# Jira WWA-553:updated code to pass status 9 for booking cancel from customer
#
# Revision 1.29  2019/12/04 13:00:31  pkokate
# Jira WWA-553:Added code to check booking type and set status code 15 for customer booking cancel
#
# Revision 1.28  2019/07/23 06:45:21  pkokate
# Mission 30355: Added code to re-initialize iExportOwnerID if settings available for specific customers
#
# Revision 1.27  2019/07/03 11:05:01  smadhukar
# Mission 30390 : Added support to store leg information in different
#
# Revision 1.26  2017/12/08 07:01:52  vthakre
# Mission 28095 : Added code to insert correct entry for origin and destination in rpt_shipmentdetail table.
#
# Revision 1.25  2017/11/10 08:43:16  vthakre
# Mission 28188 : Added code to enable APERAK from booking request mdoule.
#
# Revision 1.24  2017/09/26 13:13:53  sdalai
# Mission 28075 : Added field cWWAreference to store in tra_Shipment table.
#
# Revision 1.23  2017/03/16 09:25:59  vthakre
# Mission 27675 : Added code to add importownerid and exportownerid.
#
# Revision 1.22  2017/03/16 09:15:31  vthakre
# Mission 27675 : Addedd code for exportownerid and importownerid in tra_Bok_header.
#
# Revision 1.21  2017/03/07 10:58:08  vthakre
# Mission 27675 : Added code for member to member booking.
#
# Revision 1.20  2016/05/03 09:59:02  rpatra
# Mission 26695: (vpatil) Added the code to set iShipmentID for request type U.
#
# Revision 1.19  2016/04/18 12:29:19  rpatra
# Mission 26791: Removed code to set booking number in tra_Status table.
# Committing changes for msawant.
#
# Revision 1.18  2015/08/31 05:32:40  rpatra
# Mission 25860: Moved the logging into reporting tables from this package to Export.pm and added code to store iShipmentID and cCustomerAlias in self.
# Committing changes for msawant.
#
# Revision 1.17  2015/07/09 10:47:40  rpatra
# Mission 25664: Taken production version and added gen_Location.iStatus >= 0 condtion.
# committing changes for adhanwde.
#
# Revision 1.15  2015/03/20 09:32:06  psakharkar
# Mission 25014 : Parse new parameter after ETAPortOfDischarge to shipmentDetailsMap & updateShipmentDetails procedure call
#
# Revision 1.14  2014/12/03 09:50:18  rpatra
# Mission16495: Modified the code to log the values of two new fields iImportOwnerID and iExportOwnerID.
# Committing changes for schavan.
#
# Revision 1.13  2014/09/22 08:37:09  psakharkar
# Mission 22657 : Parse new parameter ETAPortOfDischarge to shipmentDetailsMap & updateShipmentDetails procedure
#
# Revision 1.12  2014/09/05 05:25:58  rpatra
# Mission 21904: Passed Container to updateShipmentdetail procedure
#
# Revision 1.11  2014/08/06 11:37:31  psakharkar
# Mission 21817 : Parse new parameter CuttOff to updateShipmentDetails procedure
#
# Revision 1.10  2014/06/25 11:35:40  rpatra
# Mission 20108: Replaced the apptype from E to WE
#
# Revision 1.9  2014/02/20 11:00:45  psakharkar
# Mission 16980 : Parse status code for booking new & canceled.
#
# Revision 1.8  2014/02/17 10:34:32  psakharkar
# Mission 16980 : Added code to call procedure & insert details in table rpt_Shipmentdetail & rpt_ShipmentStatus
#
# Revision 1.7  2014/02/06 11:26:29  rpatra
# Mission 16416: Modified the code to store the LOD, DIS and there Estimated times in database
#
# Revision 1.6  2014/01/27 12:13:33  rpatra
# Mission 16404: Corrected the wrong insert of WWARef as booking number in tra_Status.
# Committing changes for msawant.
#
# Revision 1.5  2013/07/22 12:03:33  smadhukar
# Bug 13458 : Changed the Status code from '05' to '5'.
# Committing changes for rpatra.
#
# Revision 1.4  2013/05/06 11:58:57  akumar
# Bug 11694 : Modified the code to handle Request Type C for bug 11694
# Committing changes for rpatra
#
# Revision 1.3  2013/02/07 09:03:31  akumar
# Bug 10368 Remove metadata logging code for booking request module and put it into XML.pm
# Committing changes for psakharkar
#
# Revision 1.2  2013/01/15 06:32:21  smozarkar
# Bug 10368 : Added code to log metadata for booking request module
# Committing changes for psakharkar
#
# Revision 1.1  2012/02/27 11:40:51  smozarkar
# 6516:Created module to store data from hash in Database
# Commiting changes for rpatra
#
#
