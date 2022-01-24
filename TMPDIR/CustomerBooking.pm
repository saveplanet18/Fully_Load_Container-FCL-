
# 
# $Id: CustomerBooking.pm,v 1.33 2019/12/17 11:18:49 bnagpure Exp $
#
	# Shipco Package for table boo_Booking
	# subject to change as it will be tra_Bok_header....
	# comment: this won't ever be tra_Bok_header....
	
package wwa::DO::CustomerBooking;
	eval ('use wwa::Error;');
	die "10102, $@" if ($@);
	eval (
		'use wwa::BaseDomainObject;
		use wwa::DBI;
		use wwa::DO::CustomerBooking::LineItem;
		use wwa::DO::CustomerBooking::Pickup;
		use wwa::DO::CustomerBooking::Hazardous;
		use wwa::DO::CustomerBooking::AddressDetails;
		use wwa::DO::OfficeInternalInfo;
		use wwa::DO::Counter;
		');
	handleError(10102, "$@") if ($@);

	@ISA = qw{wwa::BaseDomainObject};

		sub new
		{
			my $proto = shift;
			my $class = ref($proto) || $proto;
			my $self = wwa::BaseDomainObject->new();
			
			# self variables
			$self->{iBookingID} = 0;
			$self->{iBookingNumID} = 0;

			$self->{lineitem} = wwa::DO::CustomerBooking::LineItem->new();
			$self->{pickup} = wwa::DO::CustomerBooking::Pickup->new();
			$self->{hazardous} = wwa::DO::CustomerBooking::Hazardous->new();
			$self->{office} = wwa::DO::OfficeInternalInfo->new();

			$self->{collection} = wwa::Collection->new();

			# SQL variables
			$self->{tableName} = "boo_Booking";
			$self->{pKey} = "iBookingID";
			$self->{cKey} = "iBookingNumID";

			$self->{iBookingID} = 0;
			
			bless($self,$class);
			return($self);
		}

		sub office
		{
			my $self = shift;
			my $newValue = shift;
			$self->{office} = $newValue if (defined($newValue));
			my $retval = "";
			$retval = $self->{office} if (defined($self->{office}));
			return($retval);
		}

		sub _save
		{
			my $self = shift;

			my $oDbh = wwa::DBI->new();
			#$ENV{app}->verbose(5,"Setup dbh: $oDbh");
			
			$ENV{app}->verbose(3, "Adding booking record...  User ID is " . $self->getUserID);

			## Added cWWAreference as same as iBookingnumID in INSERT for Bug 7278 by psakharkar
			# Added BookingOffice in insert query for bug 11463 by rpatra
			# Added cBookingnumber in insert query for bug 16051 by rpatra
			# Added cDischargecode in insert query for mission 13493 by schavan 2013-12-27
			# Replace $self->quote with $oDbh->quote for Mission 18206 by msawant.
			# Replaced the apptype from E to WE for mission 20108 by rpatra
			# Added a DBH quote to string fields, by schavan 2015-06-17 for mission 25549
			# Added cOnwardGateway in insert query for mission 25790 by rpatra.
			# Added iPortalID in insert query for mission 29114 by bpatil
			# Added extra parameter cMovetype,cServiceyype for mission 30075 by smadhukar on 12-Apr-2019
			my $cQuery = "INSERT INTO " . $self->{tableName} . " (iBookingnumID, cBookingnumber, cBookingType, iUserID, tBookingdate,tLastsentdate," .
				    "iPortalID, cHandlingoffice, cEisendingoffice, cBookingoffice, cPickup, cCombinedaddress, cCompanyname, cCity, cAddress, cCountry, cPostalcode," .
				    "cPhone, cContactperson, cFax, cEmail, cBucustomeremail , cOrigin,cPortofloding, cRoutingvia, cVessel, cVoyage," .
				    "tCutoff, tEta, tEtd,tEtdPOL,tEstshipdate,cDischargecode, cDestination,cFinaldestinationcode,cFinaldestination,cFinaldestinationtype," .
					"cMovetype,cServicetype,cFinaldestinationcountry,cOncarriage, cOncarriagelocation, cAes, iVesselvoyageidentifier," .
				    "cAms, cCc, cOnwardGateway, cPc, cForwarderreference, cCustintref, cWWAreference, cCms, cHazardous, cSpecialcondition, iImo," .
				    "cType, cShipperrating, cApptype, cOnhold, cHvc,cBondedcargo,".
				    "nTransportTemperatureRangeFrom, nTransportTemperatureRangeTo, cCustomsRelatedData, cCTCCode, cCTCDescription, cCustomsContact, cCustomsPhone,".
				    "iEnteredby, tEntered, iUpdatedby, tUpdated" .
				    ") VALUES(" .
				    $self->quote($self->getBookingNumID) . ", " .
				    $oDbh->quote($self->getBookingnumber) . ", " .
				    $self->quote($self->getBookingType) . ", " .
				    $self->quote($self->getUserID) . ", " .
				    $self->quote($self->getBookingDate) . ", " .
				    $self->quote($self->getLastsentdate) . ", " .
				    $self->quote($self->{PortalMemberID}) . ", " .
				    $self->quote($self->getHandlingOffice) . ", " .
				    $oDbh->quote($self->getEISendingOffice) . ", " .
				    $self->quote($self->getBookingOffice) . ", " .
				    $self->quote($self->getPickup) . ", " .
				    $self->quote($self->getCombinedAddress) . ", " . 
				    $oDbh->quote($self->getCompanyName) . ", " .
				    $oDbh->quote($self->getCity) . ", " .
				    $oDbh->quote($self->getAddress) . ", " .
				    $oDbh->quote($self->getCountry) . ", " .
				    $oDbh->quote($self->getPostalCode) . ", " .
				    $oDbh->quote($self->getPhone) . ", " .
				    $oDbh->quote($self->getContactPerson) . ", " .
				    $oDbh->quote($self->getFax) . ", " .
				    $self->quote($self->getEmail) . ", " .
				    $self->quote($self->getBUEmail) . ", " .
				    $self->quote($self->getOrigin) . ", " .
				    $self->quote($self->getPortOfLoading) . ", " .
				    $self->quote($self->getRoutingVia) . ", " .
				    $oDbh->quote($self->getVessel) . ", " .
				    $oDbh->quote($self->getVoyage) . ", " .
				    $self->quote($self->getCutoff) . ", " .
				    $self->quote($self->getETA) . ", " .
				    $self->quote($self->getETD) . ", " .
				    $self->quote($self->getETSPoL) . ", " .
				    $self->quote($self->getEstShipDate) . ", " .
				    $self->quote($self->getPortOfDischarge) . ", " .
				    $self->quote($self->getDestination) . ", " .
				    $oDbh->quote($self->getFinalDestination) . ", " .
				    $self->quote($self->getFinalDestinationPlace) . ", " .
				    $oDbh->quote($self->getFinalDestinationType) . ", " .
				    $oDbh->quote($self->getMoveType) . ", " .
				    $oDbh->quote($self->getServiceType) . ", " .
				    $oDbh->quote($self->getFinalDestinationCountry) . ", " .					
				    $self->quote($self->getOncarriageFlag) . ", " .
				    $oDbh->quote($self->getOncarriagePlace) . ", " .
				    $self->quote($self->getAES) . ", " .
				    $self->quote($self->getVesselVoyageID) . ", " .
				    $self->quote($self->getAMS) . ", " .
				    $self->quote($self->getCC) . ", " .
				    $oDbh->quote($self->getOnwardGateway) . ", " .
				    #"'".$self->getCustRef."'" . ", " .
				    # Added code to store cPc in boo_Booking table by msawant for Mission 18770
				    $self->quote($self->getPC) . ", " .
				    $oDbh->quote($self->getCustRef) . ", " .
				    $oDbh->quote($self->getCustIntRef) . ", " .
				    $self->quote($self->getBookingNumID) . ", " .
				    $self->quote($self->getCMS) . ", ".
				    $self->quote($self->getHazardous) . ", " .
				    $self->quote($self->getSpecialCondition) . ", " .
				    $self->quote($self->getIMO) . ", " . 
				    $self->quote($self->getType) . ", " .
				    $self->quote($self->getShipperRating) . ", " .
				    "'WE', " .
				    $self->quote($self->getOnhold) . ", " .
				    $self->quote($self->getHvc) . ", " .
				    $self->quote($self->getBondedCargo) . ", " .
				    $self->quote($self->getTransportTemperatureRangeFrom) . ", " .
				    $self->quote($self->getTransportTemperatureRangeTo) . ", " .
				    $oDbh->quote($self->getCustomsRelatedData) . ", " .
				    $self->quote($self->getCTCCode) . ", " .
				    $oDbh->quote($self->getCTCDescription) . ", " .
				    $oDbh->quote($self->getCustomsContact) . ", " .
				    $oDbh->quote($self->getCustomsPhone) . ", " .

				    $self->quote($self->getEnteredBy) . ", " .
				    "now(), " .
				    $self->quote($self->getUpdatedBy) . ", " .
				    "now())";
			#$ENV{app}->verbose(2,"$query");
			my $cSth = $oDbh->prepare($cQuery) || handleError(10202,$oDbh->errstr . "\n" . $cQuery);
			$cSth->execute() || handleError(10203,"$cQuery (" . $cSth->errstr . ")");
			$self->setBookingID($cSth->{mysql_insertid}) || handleError(10204);
			;
			return($object);
		}
		# Added BookingOffice in update query for bug 11463 by rpatra
		# Added cBookingnumber in update query for bug 16051 by rpatra
		# Added cDischargecode in update query for bug 13493 by schavan 2013-12-27
		#Replace $self->quote with $oDbh->quote for mission 18206 by msawant
		sub _update
		{
			my $self = shift;
			my $oDbh = wwa::DBI->new();

			# Added a DBH quote to string fields, by schavan 2015-06-17 for mission 25549
			# Added iPortalID in update query for mission 29114 by bpatil
			my $cQuery = "UPDATE " . $self->{tableName} . " SET " .
				    "iBookingnumID=" . $self->quote($self->getBookingNumID) . ", " .
				    "cBookingnumber=" .  $oDbh->quote($self->getBookingnumber) . ", " .
				    "cBookingType=" .  $self->quote($self->getBookingType) . ", " . 
				    "iUserID=" . $self->quote($self->getUserID) . ", " .
				    "tBookingdate=" . $self->quote($self->getBookingDate) . ", " .
				    "tLastsentdate=" . $self->quote($self->getLastsentdate) . ", " .
				    "iPortalID=" . $self->quote($self->{PortalMemberID}) . ", " .
				    "cHandlingoffice=" . $self->quote($self->getHandlingOffice) . ", " .
				    "cBookingOffice=" . $self->quote($self->getBookingOffice) . ", " .
				    "cEisendingoffice=" . $self->quote($self->getEISendingOffice) . ", " .
				    "cCms=" . $self->quote($self->getCMS) . ", " .
				    "cPickup=" . $self->quote($self->getPickup) . ", " .
				    "cCombinedaddress=" . $self->quote($self->getCombinedAddress) . ", " .
				    "cCompanyname=" . $oDbh->quote($self->getCompanyName) . ", " .
				    "cCity=" . $oDbh->quote($self->getCity) . ", " .
				    "cAddress=" . $oDbh->quote($self->getAddress) . ", " .
				    "cCountry=" . $oDbh->quote($self->getCountry) . ", " .
				    "cPostalcode=" . $oDbh->quote($self->getPostalCode) . ", " .
				    "cPhone=" . $oDbh->quote($self->getPhone) . ", " .
				    "cContactperson=" . $oDbh->quote($self->getContactPerson) . ", " .
				    "cFax=" . $oDbh->quote($self->getFax) . ", " .
				    "cEmail=" . $oDbh->quote($self->getEmail) . ", " .
				    "cBucustomeremail=" . $oDbh->quote($self->getBUEmail) . ", " .
				    "cOrigin=" . $self->quote($self->getOrigin) . ", " .
			 	    "cPortofloding=" . $self->quote($self->getPortOfLoading) . ", " .
				    "cRoutingvia=" . $self->quote($self->getRoutingVia) . ", " .
				    "iVesselvoyageidentifier=" . $self->quote($self->getVesselVoyageID) . ", " .
				    "iImo=" . $self->quote($self->getIMO) . ", " .
				    "cVessel=" . $oDbh->quote($self->getVessel) . ", " .
				    "cVoyage=" . $oDbh->quote($self->getVoyage) . ", " .
				    "tCutoff=" . $self->quote($self->getCutoff) . ", " .
				    "tEta=" . $self->quote($self->getETA) . ", " .
				    "tEtd=" . $self->quote($self->getETD) . ", " .
				    "tEtdPOL=" . $self->quote($self->getETSPoL) . ", " .
				    "tEstshipdate=" . $self->quote($self->getEstShipDate) . ", " .
				    "cDischargecode=" . $self->quote($self->getPortOfDischarge) . ", " .
				    "cDestination=" . $self->quote($self->getDestination) . ", " .
				    "cFinaldestinationcode=" . $oDbh->quote($self->getFinalDestination) . ", " .
				    "cFinaldestination=" . $self->quote($self->getFinalDestinationPlace) . ", " .
				    "cFinaldestinationtype=" . $oDbh->quote($self->getFinalDestinationType) . ", " .
				    "cMovetype=" . $oDbh->quote($self->getMoveType) . ", " .
				    "cServicetype=" . $oDbh->quote($self->getServiceType) . ", " .
				    "cFinaldestinationcountry=" . $oDbh->quote($self->getFinalDestinationCountry) . ", " .
				    "cOncarriage=" . $self->quote($self->getOncarriageFlag) . ", " .
				    "cOncarriagelocation=" . $oDbh->quote($self->getOncarriagePlace) . ", " .
				    "cAes=" . $self->quote($self->getAES) . ", " .
				    "cAms=" . $self->quote($self->getAMS) . ", " .
				    "cCc=" . $self->quote($self->getCC) . ", " .
				    # Added code to update cOnwardGateway in boo_Booking table by rpatra for mission 25790.
				    "cOnwardGateway=" . $oDbh->quote($self->getOnwardGateway) . ", " .
				     # Added code to store cPc in boo_Booking table by msawant for mission 18770
                                    "cPc=" . $self->quote($self->getPC) . ", " .
				    "cForwarderreference=" . $oDbh->quote($self->getCustRef) . ", " .
				    "cCustintref=" . $oDbh->quote($self->getCustIntRef) . ", " .
				    "cHazardous=" . $self->quote($self->getHazardous) . ", " .
				    "cSpecialcondition=" . $self->quote($self->getSpecialCondition) . ", " .
				    "cType=" . $self->quote($self->getType) . ", " .
				    "cShipperrating=" . $self->quote($self->getShipperRating) . ", " .
				    "cOnhold=" . $self->quote($self->getOnhold) . ", " .
				    "cHvc=" . $self->quote($self->getHvc) . ", " .
				    "cBondedcargo=".$self->quote($self->getBondedCargo) . ", " .
				    # Added code to store new fields in boo_Booking table by msawant for mission 18770
				    "nTransportTemperatureRangeFrom = ".$self->quote($self->getTransportTemperatureRangeFrom) . ", " .
				    "nTransportTemperatureRangeTo = ".$self->quote($self->getTransportTemperatureRangeTo) . ", " .
				    "cCustomsRelatedData = ".$oDbh->quote($self->getCustomsRelatedData) . ", " .
				    "cCTCCode = ".$self->quote($self->getCTCCode) . ", " .
				    "cCTCDescription = ".$self->quote($self->getCTCDescription) . ", " .
				    "cCustomsContact = ".$self->quote($self->getCustomsContact) . ", " .
				    "cCustomsPhone = ".$self->quote($self->getCustomsPhone) . ", " .
				    "iStatus=" . $self->getStatus . ", " .
				    "iUpdatedby=" . $self->quote($self->getUpdatedBy) . ", " .
				    "tUpdated=now() " . 
				    "WHERE iBookingID=" . $self->quote($self->getBookingID);
			#$ENV{app}->verbose(2,"$query");
			my $cSth = $oDbh->prepare($cQuery) || handleError(10202,$oDbh->errstr . "\n" . $cQuery);
			$cSth->execute() || handleError(10203, $cSth->errstr . "\n" . $cQuery);
			$cSth->finish();
			return($self);

		}

		sub _updateAgentBookingNumber
		{
			my $self = shift;
			my $oDbh = wwa::DBI->new();

			# Added a DBH quote to string fields, by schavan 2015-06-17 for mission 25549
			my $cQuery = "UPDATE " . $self->{tableName} . " SET " .
				    "cAgentbookingnumber=" . $oDbh->quote($self->getAgentBookingNumber) . " " .
				    "WHERE iBookingID=" . $self->quote($self->getBookingID);
			#$ENV{app}->verbose(2,"$query");
			my $cSth = $oDbh->prepare($cQuery) || handleError(10202,$oDbh->errstr . "\n" . $cQuery);
			$cSth->execute() || handleError(10203, $cSth->errstr . "\n" . $cQuery);
			$cSth->finish();
			return($self);
		}
		

		# try to find where nBookingSeq=$value
		sub exists
		{
			my ($self, $value) = @_;
			my $oDbh = wwa::DBI->new();
			my $cQuery = "SELECT * FROM " . $self->{tableName} . " WHERE " . $self->{cKey} . "=" . $self->quote($value);
			#$ENV{app}->verbose(2, $query);
			my $cSth = $oDbh->prepare($cQuery) || handleError(10202, $oDbh->errstr . "\n" . $cQuery);
			$cSth->execute || handleError(10203, $cSth->errstr . "\n" . $cQuery);
			my $found = 0;
			while (my $tmp = $cSth->fetchrow_hashref)
			{
				$found = $tmp->{$self->{pKey}} if (defined($tmp->{$self->{pKey}}));
			}
			$cSth->finish;
			return($found);
		}

		sub add
		{
			my ($self, $booking) = @_;
			$booking = $self unless (defined($booking));

			my $found = $self->exists($booking->getBookingNumID);
			if ($found)
			{
				$booking->setBookingID($found);
				$booking->_update;
				$booking->expireLineItems;
			}
			else
			{
				$booking->_save;
			}

			$booking->{pickup}->setBookingnumID($booking->getBookingNumID);

			if (defined($self->{lineitem}) && defined($self->{hazardous}))
			{
				$ENV{app}->verbose(3, "Adding depricated line items and hazarous details");
				$booking->{lineitem}->setHazardousFlag($booking->getHazardous);
				$booking->{lineitem}->setBookingnumID($booking->getBookingNumID);
				$booking->{lineitem}->add;

				$booking->{hazardous}->setLineItemID($booking->{lineitem}->getBookinglineitemID);
				$booking->{hazardous}->setBookingnumID($booking->getBookingNumID);
				$booking->{hazardous}->add if ( ($booking->{lineitem}->getHazardousFlag eq 'Y' || 
							         $booking->{lineitem}->getHazardousFlag eq 'y') ||
								($booking->getHazardous eq 'Y' || 
								 $booking->getHazardous eq 'y') );
			}

			while ($self->lineItems->hasMoreElements)
			{
				my $lineItem = $self->lineItems->getNextElement;
				next unless(defined($lineItem));
				$lineItem->setBookingnumID($self->getBookingNumID);
				$lineItem->add;
				# Added the code to store the shipment related data for mission 15533 by rpatra
				while ($lineItem->shipmentRelatedData->hasMoreElements)
				{
					my $hShipmentRelatedData = $lineItem->shipmentRelatedData->getNextElement;
					next unless(defined($hShipmentRelatedData));

					$hShipmentRelatedData->setBookingnumID($self->getBookingNumID);
					$hShipmentRelatedData->setBookinglineitemlclID($lineItem->getBookinglineitemID);
					$hShipmentRelatedData->add;
				}
			}

			$booking->{pickup}->add if ($booking->getPickup eq 'Y' || $booking->getPickup eq 'y');
			###$booking->{hazardous}->add if ($booking->getHazardous eq 'Y' || $booking->getHazardous eq 'y');

			# Added to insert/update contact details in table boo_Booking_contactdetail for mission 25210 by psakharkar on Friday, April 10 2015
			my $oAddressDetails = wwa::DO::CustomerBooking::AddressDetails->new();
			while($booking->getAddressDetails->hasMoreElements)
			{
				my $hAddressDetails = $booking->getAddressDetails->getNextElement;
				next unless(defined($hAddressDetails));

				$oAddressDetails->setBookingID($booking->getBookingID);
				$oAddressDetails->setBookingnumID($booking->getBookingNumID);
				# Added field cName in boo_Booking_contactdetail for Mission 29101 by vthakre, 2018-08-27.
			        $oAddressDetails->setName($hAddressDetails->getName);
				$oAddressDetails->setType($hAddressDetails->getType);
				$oAddressDetails->setCombinedAddress($hAddressDetails->getCombinedAddress);
				$oAddressDetails->setPhone($hAddressDetails->getPhone);
				$oAddressDetails->setFax($hAddressDetails->getFax);
				$oAddressDetails->setEmail($hAddressDetails->getEmail);
				$oAddressDetails->setRequestType($booking->getRequestType);
				$oAddressDetails->add;
			}

			return($booking);
		}

		sub delete
		{
			my $self = shift;
			my $oDbh = wwa::DBI->new();
			# Changed the iStatus to -1 for cancelled bookings for bug 15953 by rpatra.
			# Set cBookingnumber for booking cancellation in  update query for Mission 16404 by msawant.
			# Added a DBH quote to string fields, by schavan 2015-06-17 for mission 25549
			# Added dbh quote to iBookingNumID field by bpatil for mission 28621.
			my $cQuery = "UPDATE " . $self->{tableName} . " SET iStatus = -1, ".
			"cBookingnumber = ". $oDbh->quote($self->getBookingnumber) ." WHERE iBookingNumID = " . $oDbh->quote($self->getBookingNumID);
			#$ENV{app}->verbose(2, $query);
 
			$oDbh->do($cQuery) || handleError(10203, $oDbh->errstr . "\n" . $cQuery);

			# We need to find the iBookingID...
			$cQuery = "SELECT iBookingID FROM " . $self->{tableName} . "" .
				" WHERE iBookingNumID = " . $oDbh->quote($self->getBookingNumID);
			#$ENV{app}->verbose(2, $query);
			$oDbh = wwa::DBI->new();
			my $cSth = $oDbh->prepare($cQuery) || handleError("Could not prepare query: $cQuery (" . $oDbh->errstr . ")");
			$cSth->execute() || handleError("Could not execute query: $cQuery (" . $cSth->errstr . ")");

			$tmp = $cSth->fetchrow_hashref();

			$self->setBookingID($tmp->{iBookingID});

			return($self);
		}
		
		sub createBookingNumber
		{
			my ($self,$userID) = @_;
			return (0,"N") if (!defined($userID));

			$ENV{app}->verbose(5,"user: $userID");

			my ($cQuery,$cSth,$tmp,%hashRef);
			my ($nextValue,$customUsed,$counter) = (-1,"N",-2);
			$ENV{app}->verbose(3,"UserID: $userID");

			my $user = wwa::DO::User->new();
			$user->getRecord($userID);
			
			$ENV{app}->verbose(3,"Custom used: " . $user->getCustomcounter);

			#	Load the counter information
			my $counterObject = wwa::DO::Counter->new();
                        
			$nextValue = $counterObject->getNextCounterValue($user->getCounterID);
			$customUsed = "Y";

			#	Counter is out of range error.
			handleError(11301, "User ID: $userID") if ($nextValue == -2);

			#	Generic error.
			handleError(11303, $counterObject->getCounterID) if ($nextValue == -1);


			#	Make sure that the counter value is within the correct range.
			$ENV{app}->verbose(3,"Counter: $counter, Max: " . $user->getEndcounter . ", Custom: " . $customUsed);


			#	Return the counter value.	
			return($nextValue,$customUsed);
		}

		# get the record and all children for this iBookingNumID
		sub loadAll
		{
			my ($self, $bookingNumID) = @_;

			my $booking = wwa::DO::CustomerBooking->new();

			# find all stuff
			#$booking->getRecord($bookingNumID);
			my $cCollection = $booking->find(undef, $bookingNumID);
			$cCollection->resetCounter;
			while ($cCollection->hasMoreElements)
			{
				my $bkg = $cCollection->getNextElement;
				next unless(defined($bkg));

				$booking = $bkg;
				last;
			}
			undef($cCollection);
			my $obj;
			
			$booking->{pickup} = wwa::DO::CustomerBooking::Pickup->new->find($bookingNumID);
			$booking->{lineitem} = wwa::DO::CustomerBooking::LineItem->new->find($bookingNumID);
			$booking->{hazardous} = wwa::DO::CustomerBooking::Hazardous->new->find($bookingNumID);

                        
			# now return it
			return($booking);
		}


		sub _popFirst
		{
			my ($self, $cCollection) = @_;

			return unless(defined($cCollection));
			my $retval;

			$cCollection->resetCounter;
			while ($cCollection->hasMoreElements)
			{
				$retval = $cCollection->getNextElement;
				next unless(defined($retval));
				last;
			}
			return($retval);
		}

		# getRecord
		# paramaters:
		#	$id  -> id of record to retrieve
		# Added the Bookingnumber field in retrieve query for bug 16051 by rpatra
		sub getRecord
		{
			my ($self,$id) = @_;
			return if (!$self || !$id);
			my $oDbh = wwa::DBI->new();
			my $cQuery = "SELECT * from " . $self->{tableName} . " WHERE " . $self->{cKey} . "='" . $id . "'";
                        vverbose(3,"$cQuery");
			my $cSth = $oDbh->prepare($cQuery) || handleError("Could not prepare query: $cQuery (" . $oDbh->errstr . ")");
			$cSth->execute() || handleError("Could not execute query: $cQuery (" . $cSth->errstr . ")");

			while (my $tmp = $cSth->fetchrow_hashref())
			{
				  $self->setBookingID($tmp->{iBookingID});
				  $self->setBookingNumID($tmp->{iBookingnumID});
				  $self->setBookingnumber($tmp->{cBookingnumber});
				  $self->setBookingType($tmp->{cBookingType});
				  $self->setUserID($tmp->{iUserID});
				  $self->setBookingDate($tmp->{tBookingdate});
				  $self->setHandlingOffice($tmp->{cHandlingOffice});
				  $self->setEISendingOffice($tmp->{cEisendingoffice});
				  $self->setBookingOffice($tmp->{cBookingoffice});
				  $self->setPickup($tmp->{cPickup});
				  $self->setCompanyName($tmp->{cCompanyname});
				  $self->setCity($tmp->{cCity});
				  $self->setAddress($tmp->{cAddress});
				  $self->setCountry($tmp->{cCountry});
				  $self->setPostalCode($tmp->{cPostalcode});
				  $self->setPhone($tmp->{cPhone});
				  $self->setContactPerson($tmp->{cContactperson});
				  $self->setFax($tmp->{cFax});
				  $self->setEmail($tmp->{cEmail});
				  $self->setBUEmail($tmp->{cBucustomeremail });
				  $self->setOrigin($tmp->{cOrigin});
				  $self->setRoutingVia($tmp->{cRoutingvia});
				  $self->setVessel($tmp->{cVessel});
#				  $self->setVoyageNo($tmp->{cVoyage});         # No set method for setVoyageNo specified.
				  $self->setCutoff($tmp->{tCutoff});
				  $self->setETA($tmp->{tEta});
				  $self->setETD($tmp->{tEtd});
				  $self->setEstShipDate($tmp->{tEstshipdate});
				  # Added setPortOfDischarge subroutine foe mission 13493 by schavan
				  $self->setPortOfDischarge($tmp->{cDischargecode});
				  $self->setDestination($tmp->{cDestination});
				
				  # Aded Abi, bug 2477, support for new 5 fields.	
				  $self->setFinalDestination($tmp->{cFinaldestinationcode});
				  $self->setFinalDestinationPlace($tmp->{cFinaldestinationcode});
				  $self->setFinalDestinationType($tmp->{cFinaldestinationcode});
				  # Added for mission 30075 by smadhukar
				  $self->setMoveType($tmp->{cMovetype});
				  $self->setServiceType($tmp->{cServiceyype});
				  $self->setFinalDestinationCountry($tmp->{cFinaldestinationcountry});
				  $self->setBondedCargo($tmp->{cBondedcargo});


				  $self->setOncarriageFlag($tmp->{cOncarriage});
				  $self->setOncarriagePlace($tmp->{cOncarriagelocation});
				  #$self->setCommodity($tmp->{cCommodity});  # Commented by MH 2005-07-06 These dont even exist in boo_Booking !
				  #$self->setPieces($tmp->{iPieces});
				  $self->setAES($tmp->{cAes});
				  $self->setAMS($tmp->{cAms});
				  $self->setCC($tmp->{cCc});
			          # Added cOnwardGateway in select field for mission 25790 by rpatra.
				  $self->setOnwardGateway($tmp->{cOnwardGateway});
				  #Added by Karthik as some fields are required in the TrackingMessage
                                  $self->setBookingCost($tmp->{nBookingcost}); 
                                  $self->setShipperRef($tmp->{cShipperreference});  
                                  $self->setConsigneeRef($tmp->{cConsigneereference});
                                  $self->setLicensedCargo($tmp->{cLicensedcargo});
                                  $self->setPC($tmp->{cPc});
                                  $self->setCustIntRef($tmp->{cCustintref});       
                                  $self->setCMS($tmp->{cCms});   
				  #Till here.Karthik.
				  #$self->setPackaging($tmp->{cPackaging});
				  #$self->setWeight($tmp->{cWeight});
				  #$self->setCube($tmp->{cCube});
				  $self->setCustRef($tmp->{cForwarderreference});
				  $self->setHazardous($tmp->{cHazardous});
				  $self->setAgentBookingNumber($tmp->{cAgentbookingnumber});
				  $self->setSpecialCondition($tmp->{cSpecialcondition});
				  $self->setType($tmp->{cType});
				  #$self->setCustomCounterUsed($tmp->{cCustomCounterUsed});
				  $self->setShipperRating($tmp->{cShipperrating});
				  $self->setOnhold($tmp->{cOnhold});
				  $self->setHvc($tmp->{cHvc});
				  # Added new database select into hash fo mission 22826 by rpatra..	
				  $self->getTransportTemperatureRangeFrom($tmp->{nTransportTemperatureRangeFrom}) if (defined($tmp->{nTransportTemperatureRangeFrom}));
				  $self->getTransportTemperatureRangeTo($tmp->{nTransportTemperatureRangeTo}) if (defined($tmp->{nTransportTemperatureRangeTo}));
				  $self->getCustomsRelatedData($tmp->{cCustomsRelatedData}) if (defined($tmp->{cCustomsRelatedData}));
				  $self->getCTCCode($tmp->{cCTCCode}) if (defined($tmp->{cCTCCode}));
				  $self->getCTCDescription($tmp->{cCTCDescription}) if (defined($tmp->{cCTCDescription}));
				  $self->getCustomsContact($tmp->{cCustomsContact}) if (defined($tmp->{cCustomsContact}));
				  $self->getCustomsPhone($tmp->{cCustomsPhone}) if (defined($tmp->{cCustomsPhone}));
				  #$self->setEnteredby($tmp->{iEnteredby});             # No set method for this as well.
				  #$self->setUpdatedby($tmp->{iUpdatedby});             # No set method for setUpdatedby. 
			}
			$cSth->finish();
			return($self);
		}


		# Changed 2004-04-09 by Ryan Yagatich <ryany@pantek.com>
		# Changed to the proper format
		# Added the $cBookingnumber parameter in find query for bug 16051
		sub find
		{
			my $self = shift;

			eval('use wwa::DBI');
			handleError(10102, "$@") if ($@);
			my $oDbh = wwa::DBI->new();
			#Replace $self->quote with $oDbh->quote for mission 18206 by msawant
			# our fields
			my ( $iBookingID, $iBookingNumID, $cBookingType, $iUserID, $tBookingDate, $cHandlingOffice, $cEisendingoffice, $cCms, $cPickup, 
			     $cCombinedAddress, $cCompanyName, $cCity, $cAddress, $cCountry, $cPostalCode, $cPhone, 
			     $cContactPerson, $cFax, $cEmail, $cBucustomeremail , $cOrigin, $cRoutingVia, $iVesselVoyageIdentifier, $iImo,
			     $cVessel, $cVoyage, $tCutoff, $tEta, $tEtd, $tEstShipDate,$cDischargecode, $cDestination, $cOncarriage, $cOncarriagelocation, $cAes, 
			     $cAesDetails, $cCc, $cForwarderreference, $cCustIntRef, $cQuoteNumber, $cHazardous, $cSpecialCondition,
			     $cType, $cShipperRating, $nTotalChargeableWeight, $cKnownShipper, $cOnhold, $cHvc, 
			     $iEnteredBy, $tEntered, $iUpdatedBy, $tUpdated, $cBookingnumber ) = @_;

			my @where;

			push(@where, "ibookingid = " . $self->quote($iBookingID)) if(defined($iBookingID));
			push(@where, "ibookingnumid = " . $self->quote($iBookingNumID)) if(defined($iBookingNumID));
			push(@where, "cBookingnumber = " . $oDbh->quote($cBookingnumber)) if(defined($cBookingnumber));
			push(@where, "cBookingType = " . $self->quote($cBookingType)) if(defined($cBookingType));
			push(@where, "iuserid = " . $self->quote($iUserID)) if(defined($iUserID));
			push(@where, "tbookingdate = " . $self->quote($tBookingDate)) if(defined($tBookingDate));
			push(@where, "chandlingoffice = " . $self->quote($cHandlingOffice)) if(defined($cHandlingOffice));
			push(@where, "ceisendingoffice = " . $oDbh->quote($cEisendingoffice)) if(defined($cEisendingoffice));
			push(@where, "ccms = " . $self->quote($cCms)) if(defined($cCms));
			push(@where, "cpickup = " . $self->quote($cPickup)) if(defined($cPickup));
			push(@where, "ccombinedaddress = " . $self->quote($cCombinedAddress)) if(defined($cCombinedAddress));
			push(@where, "ccompanyname = " . $oDbh->quote($cCompanyName)) if(defined($cCompanyName));
			push(@where, "ccity = " . $oDbh->quote($cCity)) if(defined($cCity));
			push(@where, "caddress = " . $oDbh->quote($cAddress)) if(defined($cAddress));
			push(@where, "ccountry = " . $oDbh->quote($cCountry)) if(defined($cCountry));
			push(@where, "cpostalcode = " . $oDbh->quote($cPostalCode)) if(defined($cPostalCode));
			push(@where, "cphone = " . $oDbh->quote($cPhone)) if(defined($cPhone));
			push(@where, "ccontactperson = " . $oDbh->quote($cContactPerson)) if(defined($cContactPerson));
			push(@where, "cfax = " . $oDbh->quote($cFax)) if(defined($cFax));
			push(@where, "cemail = " . $oDbh->quote($cEmail)) if(defined($cEmail));
			push(@where, "cBucustomeremail  = " . $oDbh->quote($cBUEmail)) if(defined($cBUEmail));
			push(@where, "corigin = " . $self->quote($cOrigin)) if(defined($cOrigin));
			push(@where, "croutingvia = " . $self->quote($cRoutingVia)) if(defined($cRoutingVia));
			push(@where, "ivesselvoyageidentifier = " . $self->quote($iVesselVoyageIdentifier)) if(defined($iVesselVoyageIdentifier));
			push(@where, "iimo = " . $self->quote($iImo)) if(defined($iImo));
			push(@where, "cvessel = " . $self->quote($cVessel)) if(defined($cVessel));
			push(@where, "cvoyage = " . $self->quote($cVoyage)) if(defined($cVoyage));
			push(@where, "tcutoff = " . $self->quote($tCutoff)) if(defined($tCutoff));
			push(@where, "teta = " . $self->quote($tEta)) if(defined($tEta));
			push(@where, "tetd = " . $self->quote($tEtd)) if(defined($tEtd));
			push(@where, "testshipdate = " . $self->quote($tEstShipDate)) if(defined($tEstShipDate));
			# Added cdischargecode in collection for mission 13493 by schavan 2013-12-27
			push(@where, "cdischargecode =" . $self->quote($cDischargecode)) if(defined($cDischargecode));
			push(@where, "cdestination = " . $self->quote($cDestination)) if(defined($cDestination));
			push(@where, "concarriage = " . $self->quote($cOncarriage)) if(defined($cOncarriage));
			push(@where, "concarriagelocation = " . $oDbh->quote($cOncarriagelocation)) if(defined($cOncarriagelocation));
			push(@where, "caes = " . $self->quote($cAes)) if(defined($cAes));
			push(@where, "caesdetails = " . $self->quote($cAesDetails)) if(defined($cAesDetails));
			push(@where, "ccc = " . $self->quote($cCc)) if(defined($cCc));
			push(@where, "cOnwardGateway = " . $self->quote($cOnwardGateway)) if(defined($cOnwardGateway));
			 # Added the code to store cPc in boo_Booking table by msawant for Mission 18770
                        push(@where, "cPc = " . $self->quote($cPc)) if(defined($cPc));
			push(@where, "ccustref = " . $oDbh->quote($cForwarderreference)) if(defined($cForwarderreference));
			push(@where, "ccustintref = " . $oDbh->quote($cCustIntRef)) if(defined($cCustIntRef));
			push(@where, "cquotenumber = " . $self->quote($cQuoteNumber)) if(defined($cQuoteNumber));
			push(@where, "chazardous = " . $self->quote($cHazardous)) if(defined($cHazardous));
			push(@where, "cspecialcondition = " . $self->quote($cSpecialCondition)) if(defined($cSpecialCondition));
			push(@where, "ctype = " . $self->quote($cType)) if(defined($cType));
			push(@where, "cshipperrating = " . $self->quote($cShipperRating)) if(defined($cShipperRating));
			push(@where, "ntotalchargeableweight = " . $self->quote($nTotalChargeableWeight)) if(defined($nTotalChargeableWeight));
			push(@where, "cOnHold = " . $self->quote($cOnhold)) if(defined($cOnhold));
			push(@where, "cHvc = " . $self->quote($cHvc)) if(defined($cHvc));
			push(@where, "cknownshipper = " . $self->quote($cKnownShipper)) if(defined($cKnownShipper));
			push(@where, "ienteredby = " . $self->quote($iEnteredBy)) if(defined($iEnteredBy));
			push(@where, "tentered = " . $self->quote($tEntered)) if(defined($tEntered));
			push(@where, "iupdatedby = " . $self->quote($iUpdatedBy)) if(defined($iUpdatedBy));
			push(@where, "tUpdated = " . $self->quote($tUpdated)) if(defined($tUpdated));
			

			my $cCollection = wwa::Collection->new();

			return($cCollection) unless(@where);

			my $cQuery = "SELECT * FROM " . $self->{tableName} . " WHERE " . join(" AND ", @where);
			#$ENV{app}->verbose(2, $query);
			my $cSth = $oDbh->prepare($cQuery) || handleError(10202, $oDbh->errstr . "\n" . $cQuery);
			$cSth->execute() || handleError(10203, $cSth->errstr . "\n" . $cQuery);

			while (my $tmp = $cSth->fetchrow_hashref())
			{
				my $cCustomerBooking = wwa::DO::CustomerBooking->new();
				  $cCustomerBooking->setBookingID($tmp->{iBookingID}) if (defined($tmp->{iBookingID}));
				  $cCustomerBooking->setBookingNumID($tmp->{iBookingnumID}) if (defined($tmp->{iBookingnumID}));
				  $cCustomerBooking->setBookingnumber($tmp->{cBookingnumber}) if (defined($tmp->{cBookingnumber}));
				  $cCustomerBooking->setBookingType($tmp->{cBookingType}) if (defined($tmp->{cBookingType})); 
				  $cCustomerBooking->setUserID($tmp->{iUserID}) if (defined($tmp->{iUserID}));
				  $cCustomerBooking->setVesselVoyageID($tmp->{iVesselvoyageidentifier}) if (defined($tmp->{iVesselvoyageidentifier}));
				  $cCustomerBooking->setIMO($tmp->{iImo}) if (defined($tmp->{iImo}));				  
				  $cCustomerBooking->setBookingDate($tmp->{tBookingdate}) if (defined($tmp->{tBookingdate}));
				  $cCustomerBooking->setHandlingOffice($tmp->{cHandlingoffice}) if (defined($tmp->{cHandlingoffice}));
				  $cCustomerBooking->setEISendingOffice($tmp->{cEisendingoffice}) if (defined($tmp->{cEisendingoffice}));
				  $cCustomerBooking->setPickup($tmp->{cPickup}) if (defined($tmp->{cPickup}));
				  $cCustomerBooking->setCompanyName($tmp->{cCompanyname}) if (defined($tmp->{cCompanyname}));
				  $cCustomerBooking->setCity($tmp->{cCity}) if (defined($tmp->{cCity}));
				  $cCustomerBooking->setAddress($tmp->{cAddress}) if (defined($tmp->{cAddress}));
				  $cCustomerBooking->setCountry($tmp->{cCountry}) if (defined($tmp->{cCountry}));
				  $cCustomerBooking->setPostalCode($tmp->{cPostalcode}) if (defined($tmp->{cPostalcode}));
				  $cCustomerBooking->setPhone($tmp->{cPhone}) if (defined($tmp->{cPhone}));
				  $cCustomerBooking->setContactPerson($tmp->{cContactperson}) if (defined($tmp->{cContactperson}));
				  $cCustomerBooking->setFax($tmp->{cFax}) if (defined($tmp->{cFax}));
				  $cCustomerBooking->setBUEmail($tmp->{cEmail}) if (defined($tmp->{cBucustomeremail}));
				  $cCustomerBooking->setEmail($tmp->{cEmail}) if (defined($tmp->{cEmail}));
				  $cCustomerBooking->setOrigin($tmp->{cOrigin}) if (defined($tmp->{cOrigin}));
				  $cCustomerBooking->setRoutingVia($tmp->{cRoutingvia}) if (defined($tmp->{cRoutingvia}));
				  $cCustomerBooking->setVessel($tmp->{cVessel}) if (defined($tmp->{cVessel}));
				  $cCustomerBooking->setVoyage($tmp->{cVoyage}) if (defined($tmp->{cVoyage}));
				  $cCustomerBooking->setCutoff($tmp->{tCutoff}) if (defined($tmp->{tCutoff}));
				  $cCustomerBooking->setETA($tmp->{tEta}) if (defined($tmp->{tEta}));
				  $cCustomerBooking->setETD($tmp->{tEtd}) if (defined($tmp->{tEtd}));
				  $cCustomerBooking->setEstShipDate($tmp->{tEstshipdate}) if (defined($tmp->{tEstshipdate}));
				  # Added cdischargecode in collection for mission 13493 by schavan 2013-12-27
				  $cCustomerBooking->setPortOfDischarge($tmp->{cDischargecode}) if (defined($tmp->{cDischargecode}));
				  $cCustomerBooking->setDestination($tmp->{cDestination}) if (defined($tmp->{cDestination}));
				  $cCustomerBooking->setOncarriageFlag($tmp->{cOncarriage}) if (defined($tmp->{cOncarriage}));
				  $cCustomerBooking->setOncarriagePlace($tmp->{cOncarriagelocation}) if (defined($tmp->{cOncarriagelocation}));
				  $cCustomerBooking->setCommodity($tmp->{cCommodity}) if (defined($tmp->{cCommodity}));
				  #$cCustomerBooking->setPieces($tmp->{iPieces}) if (defined($tmp->{iPieces}));
				  $cCustomerBooking->setAES($tmp->{cAes}) if (defined($tmp->{cAes}));
				  $cCustomerBooking->setAMS($tmp->{cAms}) if (defined($tmp->{cAms}));
				  $cCustomerBooking->setCC($tmp->{cCc}) if (defined($tmp->{cCc}));
				  $cCustomerBooking->setOnwardGateway($tmp->{cOnwardGateway}) if (defined($tmp->{cOnwardGateway}));
				  #$cCustomerBooking->setPackaging($tmp->{cPackaging}) if (defined($tmp->{cPackaging}));
				  #$cCustomerBooking->setWeight($tmp->{cWeight}) if (defined($tmp->{cWeight}));
				  #$cCustomerBooking->setCube($tmp->{cCube}) if (defined($tmp->{cCube}));
				  $cCustomerBooking->setCustRef($tmp->{cForwarderreference}) if (defined($tmp->{cForwarderreference}));
				  $cCustomerBooking->setCustIntRef($tmp->{cCustintref}) if (defined($tmp->{cCustintref}));
				  $cCustomerBooking->setHazardous($tmp->{cHazardous}) if (defined($tmp->{cHazardous}));
				  $cCustomerBooking->setSpecialCondition($tmp->{cSpecialcondition}) if (defined($tmp->{cSpecialcondition}));
				  $cCustomerBooking->setType($tmp->{cType}) if (defined($tmp->{cType}));
				  $cCustomerBooking->setAgentBookingNumber($tmp->{cAgentbookingnumber}) if (defined($tmp->{cAgentbookingnumber}));
				  #$cCustomerBooking->setCustomCounterUsed($tmp->{cCustomCounterUsed}) if (defined($tmp->{cCustomCounterUsed}));
				  $cCustomerBooking->setShipperRating($tmp->{cShipperrating}) if (defined($tmp->{cShipperrating}));
				  $cCustomerBooking->setOnhold($tmp->{cOnhold}) if (defined($tmp->{cOnhold}));
				  $cCustomerBooking->setHvc($tmp->{cHvc}) if (defined($tmp->{cHvc}));

				  #Added by abi,bug 2477, support for new 5 fields.	
				  $cCustomerBooking->setFinalDestination($tmp->{cFinaldestinationcode}) if (defined($tmp->{cFinaldestinationcode}));
				  $cCustomerBooking->setFinalDestinationPlace($tmp->{cFinaldestination}) if (defined($tmp->{cFinaldestination}));
				  $cCustomerBooking->setFinalDestinationType($tmp->{cFinaldestinationtype}) if (defined($tmp->{cFinaldestinationtype}));
				  # Added support for cMovetype,cServiceyype for mission 30075 by smadhukar 12-Apr-2019
				  $cCustomerBooking->setMoveType($tmp->{cMovetype}) if (defined($tmp->{cMovetype}));
				  $cCustomerBooking->setServiceType($tmp->{cServiceyype}) if (defined($tmp->{cServiceyype})); 
				  $cCustomerBooking->setFinalDestinationCountry($tmp->{cFinaldestinationcountry}) if (defined($tmp->{cFinaldestinationcountry}));
				  $cCustomerBooking->setBondedCargo($tmp->{cBondedcargo}) if (defined($tmp->{cBondedcargo}));
				  # Added new database select into hash fo mission 22826 by rpatra..	
   				  $cCustomerBooking->setTransportTemperatureRangeFrom($tmp->{nTransportTemperatureRangeFrom}) if (defined($tmp->{nTransportTemperatureRangeFrom}));
				  $cCustomerBooking->setTransportTemperatureRangeTo($tmp->{nTransportTemperatureRangeTo}) if (defined($tmp->{nTransportTemperatureRangeTo}));
				  $cCustomerBooking->setCustomsRelatedData($tmp->{cCustomsRelatedData}) if (defined($tmp->{cCustomsRelatedData}));
				  $cCustomerBooking->setCTCCode($tmp->{cCTCCode}) if (defined($tmp->{cCTCCode}));
				  $cCustomerBooking->setCTCDescription($tmp->{cCTCDescription}) if (defined($tmp->{cCTCDescription}));
				  $cCustomerBooking->setCustomsContact($tmp->{cCustomsContact}) if (defined($tmp->{cCustomsContact}));
				  $cCustomerBooking->setCustomsPhone($tmp->{cCustomsPhone}) if (defined($tmp->{cCustomsPhone}));
				  $cCustomerBooking->setAppType($tmp->{cApptype}) if (defined($tmp->{cApptype}));
				  $cCustomerBooking->setEnteredBy($tmp->{iEnteredby}) if (defined($tmp->{iEnteredby}));
				  $cCustomerBooking->setEntered($tmp->{tEntered}) if (defined($tmp->{tEntered}));
				  $cCustomerBooking->setUpdatedBy($tmp->{iUpdatedby}) if (defined($tmp->{iUpdatedby}));
				  $cCustomerBooking->setUpdated($tmp->{tUpdated}) if (defined($tmp->{tUpdated}));
				$cCollection->addElement($cCustomerBooking);
			}

			$cSth->finish();
			return($cCollection);
		}


		sub lineItems
		{
			my $self = shift;
			my $newValue = shift;
			$self->{_lineItems} = $newValue if (defined($newValue));
			my $retval = (defined($self->{_lineItems})) ? $self->{_lineItems} : wwa::Collection->new();
			$self->{_lineItems} = $retval;
			return($retval);
		}

		sub expireLineItems
		{
			my $self = shift;
			# take all of our line items and expire them
			# (based on iBookingNumID)

			my $oDbh = wwa::DBI->new();
			my $cQuery = "DELETE FROM " . wwa::DO::CustomerBooking::LineItem->new()->{tableName} . " WHERE iBookingNumID=" . $self->getBookingNumID;
			#$ENV{app}->verbose(2, $query);
			$oDbh->do($cQuery) || handleError(10202, $oDbh->errstr . "\n" . $cQuery);

			$cQuery = "DELETE FROM " . wwa::DO::CustomerBooking::Hazardous->new()->{tableName} . " WHERE iBookingNumID=" . $self->getBookingNumID;
			#$ENV{app}->verbose(2, $query);
			$oDbh->do($cQuery) || handleError(10202, $oDbh->errstr . "\n" . $cQuery);

			# Deleted the old lineitem for mission 15533 by rpatra
			$cQuery = "DELETE FROM " . wwa::DO::CustomerBooking::LineItem::ShipmentRelatedData->new()->{tableName} . " WHERE iBookingNumID=" . $self->getBookingNumID;
			$oDbh->do($cQuery) || handleError(10202, $oDbh->errstr . "\n" . $cQuery);


			no wwa::DO::CustomerBooking::LineItem;
			no wwa::DO::CustomerBooking::Hazardous;
			no wwa::DO::CustomerBooking::LineItem::ShipmentRelatedData;
			no wwa::DBI;

			return(1);
		}

		sub updateLineItems
		{
			my $self = shift;

			$self->expireLineItems;
			$self->lineItems->resetCounter;
			while ($self->lineItems->hasMoreElements)
			{
				my $item = $self->lineItems->getNextElement;
				next unless(defined($item));
				$item->add();
			}

			return($self);
		}


		# Added function to check existence of customer reference in boo_Bookig table, for bug 11440, by vbind, 2013-04-05.
		# Added the code to get where condition based on the flag for bug 16086 by rpatra.
		sub checkCustomerRef
		{
			my ($self, $cReference, $iFlag) = @_;
			my @aWhere = ();
			my $oDbh = wwa::DBI->new();
			 # Replace $self->quote with $oDbh->quote for Mission 18206 by msawant.
			(defined($iFlag) && $iFlag == 1) ? push(@aWhere, "cCustintref = " . $oDbh->quote($cReference)) : push(@aWhere, "cForwarderreference = " . $oDbh->quote($cReference));
                        # Added the iUserID constraint for mission 24870 by rpatra
                        push(@aWhere, "iUserID = ".$self->quote($self->getUserID));
			push(@aWhere, "iStatus = 0");

			my $cQuery = "SELECT count(1) as Count FROM ".$self->{tableName}." WHERE " . join(" AND ", @aWhere);

			my $cSth = $oDbh->prepare($cQuery) || handleError("Could not prepare query: $cQuery (" . $oDbh->errstr . ")");

			$cSth->execute() || handleError("Could not execute query: $cQuery (" . $cSth->errstr . ")");

			return ($cSth->fetchrow_hashref);
		}
		
		# Added function to get BookingNumId based on Customer Reference, for bug 11694, by rpatra
		# Added the code to get where condition based on the flag for bug 16086 by rpatra.
		sub getBookingdetails
		{
			my ($self, $cReference, $iFlag) = @_;
			my @aWhere = ();
			 # Replace $self->quote with $oDbh->quote for Mission 18206 by msawant.
			my $oDbh = wwa::DBI->new();
			(defined($iFlag) && $iFlag == 1) ? push(@aWhere, "cCustintref = " . $oDbh->quote($cReference)) : push(@aWhere, "cForwarderreference = " . $oDbh->quote($cReference));
			# Added the iUserID constraint for mission 24870 by rpatra
			push(@aWhere, "iUserID = ".$self->quote($self->getUserID));
			push(@aWhere, "iStatus = 0");

			my $cQuery = "SELECT iBookingNumID FROM ".$self->{tableName}." WHERE " . join(" AND ", @aWhere);
			my $cSth = $oDbh->prepare($cQuery) || handleError("Could not prepare query: $query (" . $oDbh->errstr . ")");
			$cSth->execute() || handleError("Could not execute query: $query (" . $cSth->errstr . ")");

			return ($cSth->fetchrow_hashref);
		}
	
		# Added function to set/get Bookingnumber for mission 16051 by rpatra
		sub setBookingnumber
		{
			my ($self, $cNewValue) = @_;
			$self->{cBookingnumber} = $cNewValue if (defined($cNewValue));
			return($self->getBookingnumber);
		}
		# Changed default value for cBookingnumber as blank for Mission 16404 by msawant.
		sub getBookingnumber
		{
			my $self = shift;
			return (defined($self->{cBookingnumber})) ? $self->{cBookingnumber} : "";
		}

		# get/set -> iBookingID
		
		# getBookingID
		#   -- returns the value of the column iBookingID
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getBookingID
		{
			my $self = shift;
			return($self->{iBookingID}) if (defined($self->{iBookingID}));
			return("");
		}

		# setBookingID
		#  -- sets the value of the column iBookingID
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getBookingID
		sub setBookingID
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{iBookingID} = $newValue;
			return($self->getBookingID);
		}


		# get/set -> Line Item object.

		# getLineItem
		#  -- returns the current LineItem object.
		# parameters:
		#   none
		# return:
		#   scalar if found, false if not.
		sub getLineItem 
		{
			my $self = shift;
			return ($self->{lineitem}) if (defined($self->{lineitem}));
			return 0;
		}

		# setLineItem
		#  -- sets the line item for this Booking.
		# parameters:
		#   $newValue -> new value of the line item.
		# return:
		#   returns $self->getLineItem
		sub setLineItem
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = 0 if (!definied($newValue));
			$self->{lineitem} = $newValue;
			return($self->getLineItem);
		}


		# get/set -> iBookingNumID
		
		# getBookingNumID
		#   -- returns the value of the column iBookingNumID
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getBookingNumID
		{
			my $self = shift;
			# Modified the condition to return BookingNumID if BookingNumID not equal to "" else return 0 for bug 15845 by schavan
			return($self->{iBookingNumID}) if (defined($self->{iBookingNumID}) && $self->{iBookingNumID} ne "");
			return 0;
		}

		# setBookingNumID
		#  -- sets the value of the column iBookingNumID
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getBookingNumID
		sub setBookingNumID
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{iBookingNumID} = $newValue;
			return($self->getBookingNumID);
		}


		# get/set -> iUserID
		
		# getUserID
		#   -- returns the value of the column iUserID
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getUserID
		{
			my $self = shift;
			return($self->{iUserID}) if (defined($self->{iUserID}));
			return("");
		}

		# setUserID
		#  -- sets the value of the column iUserID
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getUserID
		sub setUserID
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{iUserID} = $newValue;
			return($self->getUserID);
		}


		# get/set -> iImo
		
		# getIMO
		#   -- returns the value of the column iImo
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getIMO
		{
			my $self = shift;
			return($self->{iImo}) if (defined($self->{iImo}));
			return("");
		}

		# setIMO
		#  -- sets the value of the column iImo
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getIMO
		sub setIMO
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{iImo} = $newValue;
			return($self->getIMO);
		}


		# get/set -> tBookingDate
		
		# getBookingDate
		#   -- returns the value of the column tBookingDate
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getBookingDate
		{
			my $self = shift;
			return($self->{tBookingDate}) if (defined($self->{tBookingDate}));
			return("");
		}

		# setBookingDate
		#  -- sets the value of the column tBookingDate
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getBookingDate
		sub setBookingDate
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{tBookingDate} = $newValue;
			return($self->getBookingDate);
		}


		# get/set -> cHandlingOffice
		
		# getHandlingOffice
		#   -- returns the value of the column cHandlingOffice
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getHandlingOffice
		{
			my $self = shift;
			return (defined($self->{cHandlingOffice})) ? $self->{cHandlingOffice} : "";
			#return($self->{cHandlingOffice}) if (defined($self->{cHandlingOffice}));
			#return("");
		}

		# setHandlingOffice
		#  -- sets the value of the column cHandlingOffice
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getHandlingOffice
		sub setHandlingOffice
		{
			my $self = shift;
			my $newValue = shift;
			$self->{cHandlingOffice} = $newValue if (defined($newValue));
			return($self->getHandlingOffice);
		}

		# getEISendingOffice
		#  -- returns the value of the column cEisendingoffice
                # parameters:
                #  none
                # return:
                #  scalar if found, empty string if not.
		sub getEISendingOffice
		{
			my $self = shift;
			return (defined($self->{cEisendingoffice})) ? $self->{cEisendingoffice} : "";
			return("");
		}

		# setEISendingOffice
                #  -- sets the value of the column cEisendingoffice
                # parameters:
                #   $newValue -> new value to set
                # return:
                #    returns $self->getEISendingOffice
		sub setEISendingOffice
		{
			my $self = shift;
			my $newValue = shift;
			$self->{cEisendingoffice} = $newValue if (defined($newValue));
			return($self->getEISendingOffice);
		}
		# get/set -> cPickup
		
		# getPickup
		#   -- returns the value of the column cPickup
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getPickup
		{
			my $self = shift;
			return($self->{cPickup}) if (defined($self->{cPickup}));
			return("");
		}

		# setPickup
		#  -- sets the value of the column cPickup
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getPickup
		sub setPickup
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{cPickup} = $newValue;
			return($self->getPickup);
		}


		# get/set -> cCompanyName
		
		# getCompanyName
		#   -- returns the value of the column cCompanyName
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getCompanyName
		{
			my $self = shift;
			return($self->{cCompanyName}) if (defined($self->{cCompanyName}));
			return("");
		}

		# setCompanyName
		#  -- sets the value of the column cCompanyName
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getCompanyName
		sub setCompanyName
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{cCompanyName} = $newValue;
			return($self->getCompanyName);
		}


		# get/set -> cCity
		
		# getCity
		#   -- returns the value of the column cCity
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getCity
		{
			my $self = shift;
			return($self->{cCity}) if (defined($self->{cCity}));
			return("");
		}

		# setCity
		#  -- sets the value of the column cCity
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getCity
		sub setCity
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{cCity} = $newValue;
			return($self->getCity);
		}


		# get/set -> cAddress
		
		# getAddress
		#   -- returns the value of the column cAddress
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getAddress
		{
			my $self = shift;
			return($self->{cAddress}) if (defined($self->{cAddress}));
			return("");
		}

		# setAddress
		#  -- sets the value of the column cAddress
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getAddress
		sub setAddress
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{cAddress} = $newValue;
			return($self->getAddress);
		}


		# get/set -> cCountry
		
		# getCountry
		#   -- returns the value of the column cCountry
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getCountry
		{
			my $self = shift;
			return($self->{cCountry}) if (defined($self->{cCountry}));
			return("");
		}

		# setCountry
		#  -- sets the value of the column cCountry
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getCountry
		sub setCountry
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{cCountry} = $newValue;
			return($self->getCountry);
		}


		# get/set -> cPostalCode
		
		# getPostalCode
		#   -- returns the value of the column cPostalCode
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getPostalCode
		{
			my $self = shift;
			return($self->{cPostalCode}) if (defined($self->{cPostalCode}));
			return("");
		}

		# setPostalCode
		#  -- sets the value of the column cPostalCode
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getPostalCode
		sub setPostalCode
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{cPostalCode} = $newValue;
			return($self->getPostalCode);
		}

		# get/set -> cPhone
		
		# getPhone
		#   -- returns the value of the column cPhone
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getPhone
		{
			my $self = shift;
			return($self->{cPhone}) if (defined($self->{cPhone}));
			return("");
		}

		# setPhone
		#  -- sets the value of the column cPhone
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getPhone
		sub setPhone
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{cPhone} = $newValue;
			return($self->getPhone);
		}


		# get/set -> cContactPerson
		
		# getContactPerson
		#   -- returns the value of the column cContactPerson
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getContactPerson
		{
			my $self = shift;
			return($self->{cContactPerson}) if (defined($self->{cContactPerson}));
			return("");
		}

		# setContactPerson
		#  -- sets the value of the column cContactPerson
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getContactPerson
		sub setContactPerson
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{cContactPerson} = $newValue;
			return($self->getContactPerson);
		}


		# get/set -> cFax
		
		# getFax
		#   -- returns the value of the column cFax
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getFax
		{
			my $self = shift;
			return($self->{cFax}) if (defined($self->{cFax}));
			return("");
		}

		# setFax
		#  -- sets the value of the column cFax
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getFax
		sub setFax
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{cFax} = $newValue;
			return($self->getFax);
		}


		# get/set -> cEmail
		
		# getEmail
		#   -- returns the value of the column cEmail
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getEmail
		{
			my $self = shift;
			return($self->{cEmail}) if (defined($self->{cEmail}));
			return("");
		}

		# setEmail
		#  -- sets the value of the column cEmail
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getEmail
		sub setEmail
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{cEmail} = $newValue;
			return($self->getEmail);
		}

		# get/set -> cBUEmail
		
		# getBUEmail
		#   -- returns the value of the column cBUEmail
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getBUEmail
		{
			my $self = shift;
			return($self->{cBucustomeremail}) if (defined($self->{cBucustomeremail}));
			return("");
		}

		# setBUEmail
		#  -- sets the value of the column cBucustomeremail - for Business Unit Email
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getBUEmail
		sub setBUEmail
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{cBucustomeremail} = $newValue;
			return($self->getBUEmail);
		}


		# get/set -> cOrigin
		
		# getOrigin
		#   -- returns the value of the column cOrigin
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getOrigin
		{
			my $self = shift;
			return (defined($self->{cOrigin})) ? $self->{cOrigin} : "";
		}

		# setOrigin
		#  -- sets the value of the column cOrigin
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getOrigin
		sub setOrigin
		{
			my ($self, $newValue) = @_;
			$self->{cOrigin} = $newValue if (defined($newValue));
			return($self->getOrigin);

			#my $self = shift;
			#my $newValue = shift;
			#$newValue = "" if (!defined($newValue));
			#$self->{cOrigin} = $newValue;
			#return($self->getOrigin);
		}


		# get/set -> cRoutingVia
		
		# getRoutingVia
		#   -- returns the value of the column cRoutingVia
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getRoutingVia
		{
			my $self = shift;
			return($self->{cRoutingVia}) if (defined($self->{cRoutingVia}));
			return("");
		}

		# setRoutingVia
		#  -- sets the value of the column cRoutingVia
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getRoutingVia
		sub setRoutingVia
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{cRoutingVia} = $newValue;
			return($self->getRoutingVia);
		}


		# get/set -> cVessel
		
		# getVessel
		#   -- returns the value of the column cVessel
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getVessel
		{
			my $self = shift;
			return($self->{cVessel}) if (defined($self->{cVessel}));
			return("");
		}

		# setVessel
		#  -- sets the value of the column cVessel
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getVessel
		sub setVessel
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{cVessel} = $newValue;
			return($self->getVessel);
		}

		sub getVesselCode
		{
			my $self = shift;
			return (defined($self->{cVesselCode})) ? $self->{cVesselCode} : "";
		}

		sub setVesselCode
		{
			my ($self, $newValue) = @_;
			$self->{cVesselCode} = $newValue if (defined($newValue));
			return($self->getVesselCode);
		}


		# get/set -> cVessel
		
		# getVesselVoyageID
		#   -- returns the value of the column cVesselvoyageidentifier
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getVesselVoyageID
		{
			my $self = shift;
			return($self->{iVesselvoyageidentifier}) if (defined($self->{iVesselvoyageidentifier}));
			return("");
		}

		# setVesselVoyageID
		#  -- sets the value of the column cVesselvoyageidentifier
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getVesselVoyageID
		sub setVesselVoyageID
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{iVesselvoyageidentifier} = $newValue;
			return($self->getVesselVoyageID);
		}


		# get/set -> cVoyage
		
		# getVoyage
		#   -- returns the value of the column cVoyage
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getVoyage
		{
			my $self = shift;
			return($self->{cVoyage}) if (defined($self->{cVoyage}));
			return("");
		}

		# setVoyage
		#  -- sets the value of the column cVoyage
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getVoyage
		sub setVoyage
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{cVoyage} = $newValue;
			return($self->getVoyage);
		}


		# get/set -> tCutoff
		
		# getCutoff
		#   -- returns the value of the column tCutoff
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getCutoff
		{
			my $self = shift;
			return($self->{tCutoff}) if (defined($self->{tCutoff}));
			return("");
		}

		# setCutoff
		#  -- sets the value of the column tCutoff
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getCutoff
		sub setCutoff
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{tCutoff} = $newValue;
			return($self->getCutoff);
		}


		# get/set -> tETA
		
		# getETA
		#   -- returns the value of the column tETA
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getETA
		{
			my $self = shift;
			return($self->{tETA}) if (defined($self->{tETA}));
			return("");
		}

		# setETA
		#  -- sets the value of the column tETA
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getETA
		sub setETA
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{tETA} = $newValue;
			return($self->getETA);
		}


		# get/set -> tETD
		
		# getETD
		#   -- returns the value of the column tETD
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getETD
		{
			my $self = shift;
			return($self->{tETD}) if (defined($self->{tETD}));
			return("");
		}

		# setETD
		#  -- sets the value of the column tETD
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getETD
		sub setETD
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{tETD} = $newValue;
			return($self->getETD);
		}


		# get/set -> tEstShipDate
		
		# getEstShipDate
		#   -- returns the value of the column tEstShipDate
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getEstShipDate
		{
			my $self = shift;
			return($self->{tEstShipDate}) if (defined($self->{tEstShipDate}));
			return("");
		}

		# setEstShipDate
		#  -- sets the value of the column tEstShipDate
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getEstShipDate
		sub setEstShipDate
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{tEstShipDate} = $newValue;
			return($self->getEstShipDate);
		}


		# get/set -> cDestination
		
		# getDestination
		#   -- returns the value of the column cDestination
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getDestination
		{
			my $self = shift;
			return($self->{cDestination}) if (defined($self->{cDestination}));
			return("");
		}

		# setDestination
		#  -- sets the value of the column cDestination
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getDestination
		sub setDestination
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{cDestination} = $newValue;
			return($self->getDestination);
		}


		# get/set -> cCommodity
		
		# getCommodity
		#   -- returns the value of the column cCommodity
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getCommodity
		{
			my $self = shift;
			return($self->{cCommodity}) if (defined($self->{cCommodity}));
			return("");
		}

		# setCommodity
		#  -- sets the value of the column cCommodity
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getCommodity
		sub setCommodity
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{cCommodity} = $newValue;
			return($self->getCommodity);
		}


		# get/set -> iPieces
		
		# getPieces
		#   -- returns the value of the column iPieces
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getPieces
		{
			my $self = shift;
			return($self->{iPieces}) if (defined($self->{iPieces}));
			return("");
		}

		# setPieces
		#  -- sets the value of the column iPieces
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getPieces
		sub setPieces
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{iPieces} = $newValue;
			return($self->getPieces);
		}


		# get/set -> cAES
		
		# getAES
		#   -- returns the value of the column cAES
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getAES
		{
			my $self = shift;
			return($self->{cAES}) if (defined($self->{cAES}));
			return("");
		}

		# setAES
		#  -- sets the value of the column cAES
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getAES
		sub setAES
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{cAES} = $newValue;
			return($self->getAES);
		}


		# get/set -> cAMS
		
		# getAMS
		#   -- returns the value of the column cAMS
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getAMS
		{
			my $self = shift;
			return($self->{cAMS}) if (defined($self->{cAMS}));
			return("");
		}

		# setAMS
		#  -- sets the value of the column cAMS
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getAMS
		sub setAMS
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{cAMS} = $newValue;
			return($self->getAMS);
		}


		# get/set -> cCC
		
		# getCC
		#   -- returns the value of the column cCC
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getCC
		{
			my $self = shift;
			return($self->{cCC}) if (defined($self->{cCC}));
			return("");
		}

		# setCC
		#  -- sets the value of the column cCC
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getCC
		sub setCC
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{cCC} = $newValue;
			return($self->getCC);
		}


		# get/set -> cPackaging
		
		# getPackaging
		#   -- returns the value of the column cPackaging
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getPackaging
		{
			my $self = shift;
			return($self->{cPackaging}) if (defined($self->{cPackaging}));
			return("");
		}

		# setPackaging
		#  -- sets the value of the column cPackaging
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getPackaging
		sub setPackaging
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{cPackaging} = $newValue;
			return($self->getPackaging);
		}


		# get/set -> cWeight
		
		# getWeight
		#   -- returns the value of the column cWeight
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getWeight
		{
			my $self = shift;
			return($self->{cWeight}) if (defined($self->{cWeight}));
			return("");
		}

		# setWeight
		#  -- sets the value of the column cWeight
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getWeight
		sub setWeight
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{cWeight} = $newValue;
			return($self->getWeight);
		}


		# get/set -> cCube
		
		# getCube
		#   -- returns the value of the column cCube
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getCube
		{
			my $self = shift;
			return($self->{cCube}) if (defined($self->{cCube}));
			return("");
		}

		# setCube
		#  -- sets the value of the column cCube
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getCube
		sub setCube
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{cCube} = $newValue;
			return($self->getCube);
		}


		# get/set -> cCustIntRef
		
		# getCustIntRef
		#   -- returns the value of the column cCustIntRef
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getCustIntRef
		{
			my $self = shift;
			return($self->{cCustintref}) if (defined($self->{cCustintref}));
			return("");
		}

		# setCustIntRef
		#  -- sets the value of the column cCustintref
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getCustIntRef
		sub setCustIntRef
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{cCustintref} = $newValue;
			return($self->getCustIntRef);
		}


		# get/set -> cCustRef
		
		# getCustRef
		#   -- returns the value of the column cCustRef
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getCustRef
		{
			my $self = shift;
			return($self->{cCustRef}) if (defined($self->{cCustRef}));
			return("");
		}

		# setCustRef
		#  -- sets the value of the column cCustRef
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getCustRef
		sub setCustRef
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{cCustRef} = $newValue;
			return($self->getCustRef);
		}


		# get/set -> cHazardous
		
		# getHazardous
		#   -- returns the value of the column cHazardous
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getHazardous
		{
			my $self = shift;
			return($self->{cHazardous}) if (defined($self->{cHazardous}));
			return("");
		}

		# setHazardous
		#  -- sets the value of the column cHazardous
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getHazardous
		sub setHazardous
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{cHazardous} = $newValue;
			return($self->getHazardous);
		}


		# get/set -> cSpecialCondition
		
		# getSpecialCondition
		#   -- returns the value of the column cSpecialCondition
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getSpecialCondition
		{
			my $self = shift;
			return($self->{cSpecialCondition}) if (defined($self->{cSpecialCondition}));
			return("");
		}

		# setSpecialCondition
		#  -- sets the value of the column cSpecialCondition
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getSpecialCondition
		sub setSpecialCondition
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{cSpecialCondition} = $newValue;
			return($self->getSpecialCondition);
		}


		# get/set -> cUOM
		# getUOM
		#  -- returns the value of the column cUOM
		# parameters: 
		#  none
		# return:
		#    scalar if found, empty string if not
		sub getUOM
		{
			my $self = shift;
			return($self->{cUOM}) if (defined($self->{cUOM}));
			return("");
		}

		# setUOM
		#  -- sets the value of the column cUOM
		# parameters:
		#  $newValue -> new value to set
		# return: 
		#  returns $self->getUOM
		sub setUOM
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{cUOM} = $newValue;
			return($self->getUOM);
		}


		# get/set -> cCMS
		sub getCMS
		{
			my $self = shift;
			return($self->{cCMS}) if (defined($self->{cCMS}));
			return("");
		}

		sub setCMS
		{
			my $self = shift;
			my $newValue = shift;
			$self->{cCMS} = $newValue if (defined($newValue));
			return($self->getCMS);
		}

		# get/set -> cType
		
		# getType
		#   -- returns the value of the column cType
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getType
		{
			my $self = shift;
			return($self->{cType}) if (defined($self->{cType}));
			return("");
		}

		# setType
		#  -- sets the value of the column cType
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getType
		sub setType
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{cType} = $newValue;
			return($self->getType);
		}


		# get/set -> cCustomCounterUsed
		
		# getCustomCounterUsed
		#   -- returns the value of the column cCustomCounterUsed
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getCustomCounterUsed
		{
			my $self = shift;
			return($self->{cCustomCounterUsed}) if (defined($self->{cCustomCounterUsed}));
			return("");
		}

		# setCustomCounterUsed
		#  -- sets the value of the column cCustomCounterUsed
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getCustomCounterUsed
		sub setCustomCounterUsed
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{cCustomCounterUsed} = $newValue;
			return($self->getCustomCounterUsed);
		}


		# get/set -> cShipperRating
		
		# getShipperRating
		#   -- returns the value of the column cShipperRating
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getShipperRating
		{
			my $self = shift;
			return($self->{cShipperRating}) if (defined($self->{cShipperRating}));
			return("");
		}

		# setShipperRating
		#  -- sets the value of the column cShipperRating
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getShipperRating
		sub setShipperRating
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{cShipperRating} = $newValue;
			return($self->getShipperRating);
		}
		
		# get/set -> cOnhold
		
		# getOnhold
		#   -- returns the value of the column cOnhold
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getOnhold
		{
			my $self = shift;
			return($self->{cOnhold}) if (defined($self->{cOnhold}));
			
		}

		# setOnhold
		#  -- sets the value of the column cOnhold
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getOnhold
		sub setOnhold
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{cOnhold} = $newValue;
			return($self->getOnhold);
		}

		# get/set -> cHvc
		
		# getHvc
		#   -- returns the value of the column cHvc
		# parameters:
		#   none
		# return:
		#    scalar if found, empty string if not
		sub getHvc
		{
			my $self = shift;
			return($self->{cHvc}) if (defined($self->{cHvc}));
			#return("N");
		}

		# setHvc
		#  -- sets the value of the column cHvc
		# parameters:
		#   $newValue -> new value to set
		# return:
		#    returns $self->getHvc
		sub setHvc
		{
			my $self = shift;
			my $newValue = shift;
			$newValue = "" if (!defined($newValue));
			$self->{cHvc} = $newValue;
			return($self->getHvc);
		}

		sub setNameAndAddress
		{
			my $self = shift;
			return($self->setCombinedAddress(shift));
		}
		sub getNameAndAddress
		{
			my $self = shift;
			return($self->getCombinedAddress);
		}

		sub setCombinedAddress
		{
			my $self = shift;
			my $newValue = shift;
			$self->{cCombinedAddress} = $newValue if (defined($newValue));
			return($self->getCombinedAddress);
		}

		sub getCombinedAddress
		{
			my $self = shift;
			my $retval = "";
			$retval = $self->{cCombinedAddress} if (defined($self->{cCombinedAddress}));
			return($retval);
		}
		
		sub setAppType
		{
			my ($self, $newValue) = @_;
			$self->{cApptype} = $newValue if (defined($newValue));
			return($self->getAppType);
		}

		sub getAppType
		{
			my $self = shift;
			return (defined($self->{cApptype})) ? $self->{cApptype} : "WE";
		}
		
		sub setAgentBookingNumber
		{
			my ($self, $newValue) = @_;
			$self->{cAgentbookingnumber} = $newValue if (defined($newValue));
			return($self->getAgentBookingNumber);
		}
		
		sub getAgentBookingNumber
		{
			my $self = shift;
			return (defined($self->{cAgentbookingnumber})) ? $self->{cAgentbookingnumber} : "";
		}


		sub setQuoteNumber
		{
			my ($self, $newValue) = @_;
			$self->{cQuoteNumber} = $newValue if (defined($newValue));
			return($self->getQuoteNumber);
		}

		sub getQuoteNumber
		{
			my $self = shift;
			return (defined($self->{cQuoteNumber})) ? $self->{cQuoteNumber} : "";
		}

		# the sender (only used in EI)
		sub sender
		{
			my ($self, $newValue) = @_;
			$self->{sender} = $newValue if (defined($newValue));
			return (defined($self->{sender})) ? $self->{sender} : "";
		}
		sub password
		{
			my $self = shift;
			my $newValue = shift;
			$self->{password} = $newValue if (defined($newValue));
			return (defined($self->{password})) ? $self->{password} : "";
		}

		
		# Mooified to remove repetitive function getOriginCityName and getDestCityName & wrote single fucntion getCityName, for bug 14159, by vbind 2013-09-18.
		#Added by karthik for Origin city in subject
		# the below get function will fetch the City name and City Uncode is passed as argument.
                sub getCityName
                {
                        my $self=shift;
                        my $cUnicode = shift;
               
                        my $oDbh = wwa::DBI->new();
			# Added gen_Location.iStatus >= 0 condtion for Mission 25664 by adhanwde
                        my $cQuery = "SELECT DISTINCT cCityname FROM gen_Location WHERE cCode = '".$cUnicode."' and iStatus >= 0";                                   

                        my $cSthtmp = $oDbh->prepare($cQuery) || handleError(10202,"$cQuery (" .$oDbh->errstr. ")");
                        $cSthtmp->execute() || handleError(10203, "$cQuery (" . $cSthtmp->errstr . ")");
 
                        my $hTemprow = $cSthtmp->fetchrow_hashref;
                        return ($hTemprow->{cCityname}); 
                } 

		#getOriginShipcoCode & getDestShipcoCode are for getting the shipco code 
		#actually u will also find cCode in gen_Location table but that is 5 digit and we want 3 digit. 
                sub getOriginShipcoCode
                {
                        my $self=shift;
                        my $cUnicode = shift;

                        my $oDbh = wwa::DBI->new();
                        my $cQuery = "SELECT DISTINCT cCode FROM gen_Shipco_location WHERE cCode = '".$cUnicode."'";

                        my $cSthtmp = $oDbh->prepare($cQuery) || handleError(10202,"$cQuery (" .$oDbh->errstr. ")");
                        $cSthtmp->execute() || handleError(10203, "$cQuery (" . $cSthtmp->errstr . ")");

                        my $hTemprow = $cSthtmp->fetchrow_hashref;
                        return ($hTemprow->{cCode});
                }

                sub getDestShipcoCode
                {
                        my $self=shift;
                        my $cUnicode = shift;

                        my $oDbh = wwa::DBI->new();
                        my $cQuery = "SELECT DISTINCT cCode FROM gen_Shipco_location WHERE cCode = '".$cUnicode."'";

                        my $cSthtmp = $oDbh->prepare($cQuery) || handleError(10202,"$cQuery (" .$oDbh->errstr. ")");
                        $cSthtmp->execute() || handleError(10203, "$cQuery (" . $cSthtmp->errstr . ")");

                        my $hTemprow = $cSthtmp->fetchrow_hashref;

                        return ($hTemprow->{cCode});
                }


                sub setBookingCost
                {
                        my ($self, $newValue) = @_;
                        $self->{nBookingCost} = $newValue if (defined($newValue));
                        return($self->getBookingCost);
                }

                sub getBookingCost
                {
                        my $self = shift;
                        return (defined($self->{nBookingCost})) ? $self->{nBookingCost} : "";
                }

                # get/set -> cCmsAlias
                sub getCmsAlias
                {
                        my $self = shift;
                        return($self->{cCmsAlias}) if (defined($self->{cCmsAlias}));
                        return("");
                }

                sub setCmsAlias
                {
                        my $self = shift;
                        my $newValue = shift;
                        $self->{cCmsAlias} = $newValue if (defined($newValue));
                        return($self->getCmsAlias);
                }

                sub getShipperRef
                { 
                        my $self=shift;
                        return (defined($self->{cShipperRef})?$self->{cShipperRef}: "");  
                } 
                
                sub setShipperRef
                {
                        my $self = shift;
                        my $newValue = shift;
                        $self->{cShipperRef} = $newValue if (defined($newValue));
                        return($self->getShipperRef);
                }  
                
                sub getConsigneeRef
                {
                        my $self = shift;
                        return($self->{cConsigneeRef}) if (defined($self->{cConsigneeRef}));
                        return("");
                }

                sub setConsigneeRef
                {
                        my $self = shift;
                        my $newValue = shift;
                        $self->{cConsigneeRef} = $newValue if (defined($newValue));
                        return($self->getConsigneeRef);
                }
                
                sub getLicensedCargo
                {
                        my $self = shift;
                        return($self->{cLicensedCargo}) if (defined($self->{cLicensedCargo}));
                        return("");
                }
                 
                sub setLicensedCargo
                {
                        my $self = shift;
                        my $newValue = shift;
                        $self->{cLicensedCargo} = $newValue if (defined($newValue));
                        return($self->getLicensedCargo);
                } 


                sub getPC
                {
                        my $self = shift;
                        return($self->{cPC}) if (defined($self->{cPC}));
                        return("");
                }

                sub setPC
                {
                        my $self = shift;
                        my $newValue = shift;
                        $self->{cPC} = $newValue if (defined($newValue));
                        return($self->getPC);
                }
                  
		#Till here.Karthik

                sub getOncarriageFlag
                {
                        my $self = shift;
                        return($self->{cOncarriageFlag}) if (defined($self->{cOncarriageFlag}));
                        return("");
                }

                sub setOncarriageFlag
                {
                        my $self = shift;
                        my $newValue = shift;
                        $self->{cOncarriageFlag} = $newValue if (defined($newValue));
                        return($self->getOncarriageFlag);
                }


                sub getOncarriagePlace
                {
                        my $self = shift;
                        return($self->{cOncarriagePlace}) if (defined($self->{cOncarriagePlace}));
                        return("");
                }

                sub setOncarriagePlace
                {
                        my $self = shift;
                        my $newValue = shift;
                        $self->{cOncarriagePlace} = $newValue if (defined($newValue));
                        return($self->getOncarriagePlace);
                }

			

                sub setFinalDestination
                {
                        my $self = shift;
                        my $newValue = shift;
                        $self->{cFinaldestinationcode} = $newValue if (defined($newValue));
                        return($self->getFinalDestination);
                }

			    sub getFinalDestination
                {
                        my $self = shift;
                        return($self->{cFinaldestinationcode}) if (defined($self->{cFinaldestinationcode}));
                        return("");
                }

                sub setFinalDestinationPlace
                {
                        my $self = shift;
                        my $newValue = shift;
                        $self->{cFinaldestination} = $newValue if (defined($newValue));
                        return($self->getFinalDestination);
                }

                sub getFinalDestinationPlace
                {
                        my $self = shift;
                        return($self->{cFinaldestination}) if (defined($self->{cFinaldestination}));
                        return("");
                }

                sub setFinalDestinationType
                {
                        my $self = shift;
                        my $newValue = shift;
                        $self->{cFinaldestinationtype} = $newValue if (defined($newValue));
                        return($self->getFinalDestinationType);
                }

                sub getFinalDestinationType
                {
                        my $self = shift;
                        return($self->{cFinaldestinationtype}) if (defined($self->{cFinaldestinationtype}));
                        return("");
                }

	           sub setFinalDestinationCountry
                {
                        my $self = shift;
                        my $newValue = shift;
                        $self->{cFinaldestinationcountry} = $newValue if (defined($newValue));
                        return($self->getFinalDestinationCountry);
                }
		# Added set/get for new field cMovetype and cServiceyype for mission 30075 by smadhukar on 12-Apr-2019 
		sub setMoveType
		{
			my $self = shift;
			my $newValue = shift;
			$self->{cMovetype} = $newValue if (defined($newValue));
			return($self->getMoveType);
		}
		sub getMoveType
		{
			my $self = shift;
			return($self->{cMovetype}) if (defined($self->{cMovetype}));
			return("");
		}
		sub setServiceType
		{
			my $self = shift;
			my $newValue = shift;
			$self->{cServiceyype} = $newValue if (defined($newValue));
			return($self->getServiceType);
		}
		sub getServiceType
		{
			my $self = shift;
			return($self->{cServiceyype}) if (defined($self->{cServiceyype}));
			return("");
		}
		#Mission 30390 : Added set/get for LegInfo by smadhukar on 28-June-2019
		sub setLegInfo
                {
                        my $self = shift;
                        my $newValue = shift;
                        $self->{cLegInfo} = $newValue if (defined($newValue));
                        return($self->getLegInfo);
                }
                sub getLegInfo
                {
                        my $self = shift;
                        return($self->{cLegInfo}) if (defined($self->{cLegInfo}));
                        return("");
                }
                sub getFinalDestinationCountry
                {
                        my $self = shift;
                        return($self->{cFinaldestinationcountry}) if (defined($self->{cFinaldestinationcountry}));
                        return("");
                }

				sub setBondedCargo
                {
                        my $self = shift;
                        my $newValue = shift;
                        $self->{cBondedcargo} = defined($newValue)?$newValue:"N";
                        return($self->getBondedCargo);
                }

                sub getBondedCargo
                {
                        my $self = shift;
                        return($self->{cBondedcargo}) if (defined($self->{cBondedcargo}));
                        return("N");
                }


				sub setLastsentdate
                {
                        my $self = shift;
                        my $newValue = shift;
                        $self->{tLastsentdate} = $newValue if (defined($newValue));
                        return($self->getLastsentdate);
                }

                sub getLastsentdate
                {
                        my $self = shift;
                        return($self->{tLastsentdate}) if (defined($self->{tLastsentdate}));

                }

				sub setETSPoL
                {
                        my $self = shift;
                        my $newValue = shift;
                        $self->{tEtdPOL} = $newValue if (defined($newValue));
						return($self->getETSPoL);
                }

                sub getETSPoL
                {
                        my $self = shift;
                        return($self->{tEtdPOL}) if (defined($self->{tEtdPOL}));

                }

		sub setPortOfLoading
                {
                        my $self = shift;
                        my $newValue = shift;
                        $self->{cPortoflading} = $newValue if (defined($newValue));
						
                        return($self->getPortOfLoading);
                }

                sub getPortOfLoading
                {
                        my $self = shift;
                        return($self->{cPortoflading}) if (defined($self->{cPortoflading}));

                }
		
		# Modified the column name of setter method for bug 13493 by schavan
		sub setPortOfDischarge
    		{
		    	my $self = shift;
			my $newValue = shift;
			$self->{cDischargecode} = $newValue if (defined($newValue));
			return($self->getPortOfDischarge);
		}

		# Modified the column name of getter method for bug 13493 by schavan
		sub getPortOfDischarge
		{
		    	my $self = shift;
			return($self->{cDischargecode}) if (defined($self->{cDischargecode}));
		}


				#Note related to boo_Booking table .. But needed 
				#added by abi for bug 2477,
				#since we have to know 'BondedCarg' and DimentionsFlags' there in the XML file.

				sub setIsSentDimentionflag
                {
                        my $self = shift;
                        my $newValue = shift;
                        $self->{cSentDimentionFlags} = $newValue if (defined($newValue));
						return($self->getIsSentDimentionflag);
                }

                sub getIsSentDimentionflag
                {
                        my $self = shift;
                        return($self->{cSentDimentionFlags}) if (defined($self->{cSentDimentionFlags}));
						return ("N");

                }

				sub setIsSentBondedCargo
                {
                        my $self = shift;
                        my $newValue = shift;
                        $self->{cIsSentBondedCargo} = $newValue if (defined($newValue));
						return($self->getIsSentBondedCargo);
                }

                sub getIsSentBondedCargo
                {
                        my $self = shift;
                        return($self->{cIsSentBondedCargo}) if (defined($self->{cIsSentBondedCargo}));
						return ("N");

                }

				sub setIsSentOnHold
                {
                        my $self = shift;
                        my $newValue = shift;
                        $self->{cIsSentOnHold} = $newValue if (defined($newValue));
						return($self->getIsSentOnHold);
                }

                sub getIsSentOnHold
                {
                        my $self = shift;
                        return($self->{cIsSentOnHold}) if (defined($self->{cIsSentOnHold}));
						return ("N");

                }
				
				#Here HVC & HighValue are the same, but I take HVC  is for booking, HighValue for line item
				#http://bugzilla.shipco.com/show_bug.cgi?id=2477#c68
				sub setIsSentHVC
                {
                        my $self = shift;
                        my $newValue = shift;
                        $self->{cIsSentHVC} = $newValue if (defined($newValue));
						return($self->getIsSentHVC);
                }

                sub getIsSentHVC
                {
                        my $self = shift;
                        return($self->{cIsSentHVC}) if (defined($self->{cIsSentHVC}));
						return ("N");

                }
				# Here HighValue is for line item.
				# So we want to know in any of the lineitem they have send the high value.
				# If so it will override booking such that if anyof the line item is high value, then 
		sub getHighValueFlagset
		{
			my $self = shift;
			return($self->{cHighValueFlagset}) if (defined($self->{cHighValueFlagset}));
		}

		sub setHighValueFlagset
		{
			my $self = shift;
			my $newValue = shift;
			$self->{cHighValueFlagset} = $newValue if (defined($newValue));
			return($self->getHighValueFlagset);
		}

		# Added extra set/get methods for bug 6516 by rpatra 2012-02-27
	
		sub getVesselName
		{
			my $self = shift;
			my $retval = "";
			$retval = $self->{cVessel} if (defined($self->{cVessel}));
			return($retval);
		}

		sub setVesselName
		{
			my $self = shift;
			my $newValue = shift;
			$self->{cVessel} = $newValue if (defined($newValue));
			return($self->getVesselName);
		}

		sub getOceanair
		{
			my $self = shift;
			my $retval = "";
			$retval = $self->{cOceanair} if (defined($self->{cOceanair}));
			return($retval);
		}

		sub setOceanair
		{
			my $self = shift;
			my $newValue = shift;
			$self->{cOceanair} = $newValue if (defined($newValue));
			return($self->getOceanair);
		}
		
		sub getRequestType
		{
			my $self = shift;
			my $retval = "";
			$retval = $self->{_RequestType} if (defined($self->{_RequestType}));
			return($retval);
		}

		sub setRequestType
		{
			my $self = shift;
			my $newValue = shift;
			$self->{_RequestType} = $newValue if (defined($newValue));
			return($self->getRequestType);
		}
                # Added the setBookingOffice/getBookingOffice for bug 11463 by rpatra
                sub setBookingOffice
                {
                        my ($self, $newValue) = @_;
                        $self->{BookingOffice} = $newValue if (defined($newValue));
                        return ($self->getBookingOffice);
                }

                sub getBookingOffice
                {
                        my $self = shift;
                        return (defined($self->{BookingOffice})) ? $self->{BookingOffice} : "";
                }

		#  Added function to log iMemberID into boo_Booking, for bug 14159, by vbind 2013-09-18.
		sub updateMemberID
		{
			my ($self, $iBookingNumID, $iMemberID) = @_;

			my $oDbh = wwa::DBI->new();
			my $cQuery = "UPDATE ".$self->{tableName}." SET iMemberID=$iMemberID where ".$self->{cKey}."=$iBookingNumID";

			my $cSth = $oDbh->prepare($cQuery) || handleError(10202,"$cQuery (" .$oDbh->errstr. ")");
			$cSth->execute() || handleError(10203, "$cQuery (" . $cSth->errstr . ")");
		}

		# Added new set/get methods for mission 22826 by rpatra.
		sub setTransportTemperatureRangeFrom
		{
			my ($self, $cNewValue) = @_;
			$self->{nTransportTemperatureRangeFrom} = $cNewValue if (defined($cNewValue));
			return($self->getTransportTemperatureRangeFrom);
		}

		sub getTransportTemperatureRangeFrom
		{
			my $self = shift;
			return (defined($self->{nTransportTemperatureRangeFrom})) ? $self->{nTransportTemperatureRangeFrom} : "";
		}

		sub setTransportTemperatureRangeTo
		{
			my ($self, $cNewValue) = @_;
			$self->{nTransportTemperatureRangeTo} = $cNewValue if (defined($cNewValue));
			return($self->getTransportTemperatureRangeTo);
		}

		sub getTransportTemperatureRangeTo
		{
			my $self = shift;
			return (defined($self->{nTransportTemperatureRangeTo})) ? $self->{nTransportTemperatureRangeTo} : "";
		}

		sub setCustomsRelatedData
		{
			my ($self, $cNewValue) = @_;
			$self->{cCustomsRelatedData} = $cNewValue if (defined($cNewValue));
			return($self->getCustomsRelatedData);
		}

		sub getCustomsRelatedData
		{
			my $self = shift;
			return (defined($self->{cCustomsRelatedData})) ? $self->{cCustomsRelatedData} : "";
		}

		sub setCTCCode
		{
			my ($self, $cNewValue) = @_;
			$self->{cCTCCode} = $cNewValue if (defined($cNewValue));
			return($self->getCTCCode);
		}

		sub getCTCCode
		{
			my $self = shift;
			return (defined($self->{cCTCCode})) ? $self->{cCTCCode} : "";
		}
	
		sub setCTCDescription
		{
			my ($self, $cNewValue) = @_;
			$self->{cCTCDescription} = $cNewValue if (defined($cNewValue));
			return($self->getCTCDescription);
		}

		sub getCTCDescription
		{
			my $self = shift;
			return (defined($self->{cCTCDescription})) ? $self->{cCTCDescription} : "";
		}

		sub setCustomsContact
		{
			my ($self, $cNewValue) = @_;
			$self->{cCustomsContact} = $cNewValue if (defined($cNewValue));
			return($self->getCustomsContact);
		}

		sub getCustomsContact
		{
			my $self = shift;
			return (defined($self->{cCustomsContact})) ? $self->{cCustomsContact} : "";
		}

		sub setCustomsPhone
		{
			my ($self, $cNewValue) = @_;
			$self->{cCustomsPhone} = $cNewValue if (defined($cNewValue));
			return($self->getCustomsPhone);
		}

		sub getCustomsPhone
		{
			my $self = shift;
			return (defined($self->{cCustomsPhone})) ? $self->{cCustomsPhone} : "";
		}

		# Added set/get for addressdetails colloction for mission 25210 by psakharkar on Thursday, April 09 2015
		sub setAddressDetails
		{
			my ($self,$cNewValue) = @_;
			$self->{AddressDetails} = $cNewValue if (defined($cNewValue));
			return ($self->getAddressDetails);
		}

		sub getAddressDetails
		{
			my $self = shift;
			my $cRetval;
			if(defined($self->{AddressDetails}))
			{
				$cRetval = $self->{AddressDetails};
			}
			else
			{
				eval('use wwa::Collection');
				handleError(10102, "$@") if ($@);
				$cRetval = $self->setAddressDetails(wwa::Collection->new);
				no wwa::Collection;
			}
			return($cRetval);
		}

		# Added set/get methods for OnwardGateway for mission 25790 by rpatra.
		sub setOnwardGateway
		{
			my ($self, $cNewValue) = @_;
			$self->{cOnwardGateway} = $cNewValue if (defined($cNewValue));
			return($self->getOnwardGateway);
		}

		sub getOnwardGateway
		{
			my $self = shift;
			return (defined($self->{cOnwardGateway}) && ($self->{cOnwardGateway}) ne "") ? $self->{cOnwardGateway} : "N";
		}
	
		# Added set/get method for membet to member booking for Mission 27675 by vthakre 2017-02-28.
		sub setBookingType
		{
			my ($self, $cNewValue) = @_;
                	$self->{cBookingType} = $cNewValue if (defined($cNewValue));
                        return($self->getBookingType);
		}

		sub getBookingType
		{
			my $self = shift;
                        return (defined($self->{cBookingType}) && ($self->{cBookingType}) ne "") ? $self->{cBookingType} : "C";
		}

		sub setCustomercontrolcode
		{
			my ($self, $cNewValue) = @_;
                        $self->{cCustomercontrolcode} = $cNewValue if (defined($cNewValue));
                        return($self->getCustomercontrolcode);
		}

		sub getCustomercontrolcode 
		{
                        my $self = shift;
                        return (defined($self->{cCustomercontrolcode}) && ($self->{cCustomercontrolcode}) ne "") ? $self->{cCustomercontrolcode} : "";
                }
		
		#  Added function to log iPortalID  into boo_Booking, for jira WWA-499 by vgarasiya 25/11/2019.
		sub updatePortalID
                {
                        my ($self, $iBookingNumID, $iPortalID) = @_;

                        my $oDbh = wwa::DBI->new();
                        my $cQuery = "UPDATE ".$self->{tableName}." SET iPortalID=$iPortalID where ".$self->{cKey}."=$iBookingNumID";

                        my $cSth = $oDbh->prepare($cQuery) || handleError(10202,"$cQuery (" .$oDbh->errstr. ")");
                        $cSth->execute() || handleError(10203, "$cQuery (" . $cSth->errstr . ")");
                }


1;

# 
# $Log: CustomerBooking.pm,v $
# Revision 1.33  2019/12/17 11:18:49  bnagpure
# wwa-474: add quote to booking number
#
# Revision 1.32  2019/11/27 13:22:01  vgarasiya
# WWA-499:Update portal id when sender id replaced
#
# Revision 1.31  2019/07/03 10:52:59  smadhukar
# Mission 30390 : Added set/get for LegInfo
#
# Revision 1.30  2019/04/16 12:17:01  smadhukar
# Mission 30075 : Added extra parameter cMovetype,cServiceyype
#
# Revision 1.29  2018/09/06 07:06:24  bpatil
# Mission 29114 : Added iPortalID in insert and update query.
#
# Revision 1.28  2018/08/28 12:00:31  vthakre
# Mission 29101 : Added code to add column cName in boo_Booking_contactdetail table.
#
# Revision 1.27  2018/03/26 13:07:29  bpatil
# Mission 28621 : Added dbh quote to iBookingNumID field
#
# Revision 1.26  2017/03/07 10:01:07  vthakre
# Mission 27675 : Added code to add BookingType value in database for member to membre booking.
#
# Revision 1.25  2015/08/21 05:03:55  rpatra
# Mission 25790: Added cOnwardGateway field in select/insert/update query.
#
# Revision 1.24  2015/08/12 10:13:40  rpatra
# Mission 25549: (schavan) Used DBI package's quote function instead of BaseDomainObject package's quote to quote varchar fields.
#
# Revision 1.23  2015/07/09 10:39:29  rpatra
# Mission 25664: (adhanwde) Added gen_Location.iStatus >= 0 condtion.
#
# Revision 1.22  2015/04/13 11:13:48  psakharkar
# Mission 25210 : insert / update address details into table boo_Booking_contactdetail
#
# Revision 1.21  2015/01/28 10:36:37  rpatra
# Mission 24870: Added iUserID constraint in the select query. Also removed duplicate subroutine getWWAReference
#
# Revision 1.20  2014/12/24 09:44:30  rpatra
# Mission 24528: Added getWWAReference subroutine to fetch WWAReference.
# Committing changes for msawant.
#
# Revision 1.19  2014/11/05 07:15:05  rpatra
# Mission 22826: Added support for to insert/update/select for newly mapped tags.
#
# Revision 1.18  2014/09/25 11:38:27  rpatra
# Mission 15533: Added support to store ShipmentRelatedData data in database
#
# Revision 1.17  2014/06/25 11:35:50  rpatra
# Mission 20108: Replaced the apptype from E to WE
#
# Revision 1.16  2014/04/15 09:12:58  smadhukar
# Mission 18770 : Added cPc  field in insert and update query
# Committing changes for msawant.
#
# Revision 1.15  2014/03/12 04:27:48  rpatra
# Mission 18206: (msawant) Corrected the quotes in update function
#
# Revision 1.14  2014/03/07 05:11:15  rpatra
# Mission 18206: (masawant) Replaced $self->quote with $oDbh->quote to store reference without trimming it.
#
# Revision 1.13  2014/01/27 12:11:53  rpatra
# Mission 16404: Set cBookingnumber for booking cancellation in update query. Changed default value for cBookingnumber as blank.
# Committing changes for msawant.
#
# Revision 1.12  2013/12/30 04:55:08  rpatra
# Mission13493 : Added the code insert, update and retrive port of discharge from boo_Booking table
# Committing changes for schavan
#
# Revision 1.11  2013/12/26 09:15:49  rpatra
# Mission 16086: Added the code to get where condition based on the flag to select the booking details.
#
# Revision 1.10  2013/12/19 10:25:38  rpatra
# Bug 16051: Added the cbookingnumber field in insert,update and select queries.
#
# Revision 1.9  2013/12/18 04:58:59  smadhukar
# Mission 15953: Changed the iStatus to -1 for cancelled bookings.
# Committing changes for rpatra.
#
# Revision 1.8  2013/12/12 12:40:21  smadhukar
# Mission 15845 : Modified the condition to return BookingNumID if BookingNumID not equal to "" else return 0
# Comitting changes for schavan
#
# Revision 1.7  2013/09/25 04:59:46  psakharkar
# Bug 14159 - Added code to log iMemberID details, remove repetitive code & rename function name.
# Committing changes for vbind
#
# Revision 1.6  2013/05/06 12:00:33  akumar
# Bug 11694 : Added subroutine to get BookingNumId based on Customer Reference
# Committing changes for rpatra
#
# Revision 1.5  2013/04/12 10:07:13  dsubedar
# Bug 11440 -  Added code to validate existence of customer reference in database, Committing changes for vbind
#
# Revision 1.4  2013/04/04 08:46:26  akumar
# Bug 11463 : Modified code to pass the cBookingoffice field in insert,update queries.
# Commiting changes for rpatra.
#
# Revision 1.3  2012/09/20 12:22:07  smozarkar
# Bug 7278 Adding cWWAreference is same as iBookingnumID for EDI booking
# Committing changes for psakharkar
#
# Revision 1.2  2012/02/27 11:42:34  smozarkar
# 6516:Added extra set/get methods
# Commiting changes for rpatra
#
# Revision 1.1  2011/10/21 11:50:25  smozarkar
# Bug 5920 : Setting data fro coustmer booking
#

