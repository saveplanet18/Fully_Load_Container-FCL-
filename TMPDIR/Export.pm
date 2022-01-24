
#
# $Id: Export.pm,v 1.82 2021/06/07 11:13:47 bnagpure Exp $
#

=head1 NAME

wwa::EI::BookingRequest::Export

=head1 DESCRIPTION

This module is send the Booking Confirmationmail to office and Customer 

=head1 AUTHOR

By rpatra@shipco.com

=head1 DATE

2012-02-24

=cut
package wwa::EI::BookingRequest::Export;

eval('use wwa::Error');
die "Cannot use package. $@" if ($@);
eval('
		use wwa::EI::BaseExportObject;
		use wwa::EI::Envelope;
		use wwa::EI::Email;
		use wwa::DO::Branch;
		use wwa::DO::Member;
		use wwa::DO::OfficeMap;
		use wwa::DO::Exchange;
		use wwa::DBI;
		use wwa::Template;
		use wwa::DO::GetHeaderFooter;
		use wwa::DO::MemberSetting;
		use wwa::DO::Booking;
		use wwa::Utility::Transfer::UUCP;
		use wwa::DO::WeiFileProcessLog;
		use wwa::DO::WeiFileLog;
		use wwa::DO::GenProgram;
		use wwa::Utility::Distributor::Worker;
		use wwa::Utility::Distributor::Worker::Transfer::Copy;
		use wwa::DO::CustomerBooking;
		use wwa::Utility::Universal;	
		use wwa::DO::MemberTransferLog;
		use wwa::Utility::Transfer::DIR;
		');
handleError(10102, "$@") if ($@);
eval('
		use POSIX qw/strftime/;
		');
handleError(10101,"$@") if ($@);

@ISA = qw{wwa::EI::BaseExportObject};

sub new
{
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = wwa::EI::BaseExportObject->new();
	$self->{wwaonline} = ''; #Added global variable
	bless($self,$class);
	return($self);
}


=head2

This subroutine is used to calculate the value of receipt.

The input is a BookingID value from booking details.
It returns a the value returned from table query.

=cut

# Needed to calculate the value of &receipt.
sub calculateSha1
{
	my ($self, $calcvalue) = @_;

	my $dbh = wwa::DBI->new();
	my $query = "SELECT sha1('".$calcvalue."') AS Result";
	my $sth = $dbh->prepare($query) || handleError(10202,$dbh->errstr . "\n" . $query);
	$sth->execute() || handleError(10203,"$query (" . $sth->errstr . ")");
	my $sha1 = $sth->fetchrow_hashref;
	my $receipt = $sha1->{Result};
	$sth->finish();

	return $receipt;
}


=head2

This subroutine is called by the EI module and is used for exporting data. It calls many functions which gets the details to be sent and then writes the XMl in a specified file and exports it to the user.

The inputs is a UserId value.

=cut

sub export
{
	my $self = shift;

	vverbose(3,"Exporting $self");
	$UserId = $ENV{app}->getId if (defined($UserId) && $UserId eq '');
	$self->setEnvelope(wwa::EI::Envelope->new());
	#Removed code of exchange for Mission 24976 by msawant on 11 March 2015
	my $source = $self->getSource;
	if (ref($source))

	{
		$source->resetCounter;
		vverbose(3, "Iterating through " . $source->getNumElements . " rows");
		while ($source->hasMoreElements)
		{
			my $bokSource = $source->getNextElement;
			next unless(defined($bokSource));

			vverbose(4,"data source: $bokSource");
			$self->details($bokSource);
		}
	}

	my $bookingRequest = $self->details;
	# Modified to send confirmation mail only when the their are no errors in the xml for bug 7372, vbind 2012-05-09.
	$hBookingDetails = $bookingRequest->[0];
	if ($hBookingDetails->{error_flag} eq 'N')
        {
		$self->commit;
		$self->sendConfirmationEmail($bookingRequest);
	}
}

# Removed unwanted function getEmailList(), for bug 14159, by vbind 2013-09-18.

=head2

This subroutine sets the details of booking.

The input is the details value.
It return value is the details set above.

=cut

sub details
{
	my $self = shift;
	my $newValue = shift;
	my $retval = {};
	$self->{_details} = $newValue if (defined($newValue));
	$retval = $self->{_details} if (defined($self->{_details}));
	return($retval);
}

=head2

These two subroutine sets the Envelope and value
for the envelope is retreived through the getEnvelope method.

The input is the envelope value in setEnvelope.
It returns of above by getEnvelope.

=cut

sub setEnvelope
{
	my $self = shift;
	my $newValue = shift;
	$self->{_envelope} = $newValue if (defined($newValue));
	return($self->getEnvelope);
}

sub getEnvelope
{
	my $self = shift;
	my $retval = {};
	$retval = $self->{_envelope} if (defined($self->{_envelope}));
	return($retval);
}



=head2

These two subroutine converts the newline character to the <br>.

=cut

sub nl2br
{
	my $self = shift;
	my $text = shift;
	$text =~ s/\n/<br\/>/g if defined($text);
	return $text;
}

sub exchange
{
	my ($self, $newValue) = @_;
	$self->{exchange} = $newValue if (defined($newValue));
	return (defined($self->{exchange})) ? $self->{exchange} : $self->exchange(wwa::DO::Exchange->new());
}

=head2

The subroutine prepares and send the 2 emails to customer and Customer Service(Handling Office). I
The input is booking details which is a hash reference..

=cut

sub sendConfirmationEmail
{
	my $self = shift;
	my $hBookingDetails = shift;
	$hBookingDetails = $hBookingDetails->[0];
 	my $cRef = ref($self->{_source});
	#Added code to get setting against programID & cCode and assign retrieved cvalue to array for jira wwa-649 by pkokate on 28 jan 2020
	my $cProgramsetting = wwa::DO::MemberSetting->new;
	my $cPrgSetting = $cProgramsetting->getDetails(0,$hBookingDetails->{iProgramID},'ssc_office');
	my @aOrigin = '';
	@aOrigin = split/,/, $cPrgSetting->{cValue};
	# Removed unwanted code and used base hash to get details of programid, imemberid, iuserid, for bug 14159, by vbind 2013-09-18.	
	my $officeCode = $hBookingDetails->getEISendingOffice;

	# Modified code to include integration support email id only when customer email is not valid, for bug 15476, by vbind, 2013-11-14
	my $cCustomerEmail = $hBookingDetails->getEmail;

	# Modified to validate the email id,  if not correct then take the email id from global.xml  & database for 7372, by vbind 2012-05-09.
	# Add the integration support email Id if CustomerEmail is blank for mission 24472 by rpatra.
	# Also corrected the naming convention as per standard for mission 24472 by rpatra.
	# Corrected the regex to validate CustomerEmail for mission 26455 by rpatra.
	# Changed the regex to solve Email Extension issues on wwe-ei for mission 27149 by bpatil,28/07/2016
	if($cCustomerEmail eq "" || $cCustomerEmail !~ /^\w[\w\.\-]*\w\@\w[\w\.\-]*\w(\.\w{2,})$/)
	{
		$cCustomerEmail = $ENV{app}->datapool->get('config.xml.global.defaultWWAEISupportEmail');
	}

	# Added condition to check Succes notification mail send to additional email for mission 22261 by psakharkar on 16/10/2014
	if(!defined($hBookingDetails->{Succes_Notification_Mail}) || $hBookingDetails->{Succes_Notification_Mail} ne 'N')
	{
		$cCustomerEmail = $cCustomerEmail.','.$hBookingDetails->{cAdditionalEmail} if (defined($hBookingDetails->{cAdditionalEmail}) && $hBookingDetails->{cAdditionalEmail} ne "");
	}

	$hBookingDetails->{cOriginCityName}=$hBookingDetails->getCityName($hBookingDetails->{cOrigin});

	# Modified the code to set Destination as FinalDestination if available else CFSDestination for bug 6516 by rpatra 2012-03-02
	my $cDestination = '';

	$cDestination = $hBookingDetails->{cDestination} if(defined($hBookingDetails->{cDestination}) && $hBookingDetails->{cDestination} ne '');
	$cDestination = $hBookingDetails->{cFinaldestinationcode} if(defined($hBookingDetails->{cFinaldestinationcode}) && $hBookingDetails->{cFinaldestinationcode} ne '');	

	# Modified function name getDestCityName to getCityName, for bug 14159, by vbind 2013-09-18.
	$hBookingDetails->{cDestCityName}=$hBookingDetails->getCityName($cDestination);

	my $cValue = $hBookingDetails->getUserID + $hBookingDetails->getBookingID;
	my $cReceipt = $self->calculateSha1($cValue);
	$hBookingDetails->{receipt} = $cReceipt;

	my ($officemap,$member,$user,$userid);

	# Modified the code to print the proper Email address with prefix wwa.book. in Customer's mail for bug 6516 by rpatra 2012-03-02

	#Modified to take 'cEmailprefix' from base hash, for bug 14159, by vbind 2013-09-26.

	my $cEmailPrefix = $hBookingDetails->{cEmailprefix};	
	
	my $oDetails = $self->getDestinationMemberDetails($hBookingDetails);
	my $cEmail = $oDetails->{cEmail};
	
	# Added code to log boo_Booking.imemberid, for bug 14159, by vbind 2013-09-18.
	
	if(defined $oDetails->{iMemberID} && $oDetails->{iMemberID} ne "")
	{
		my $oCustomerBooking = wwa::DO::CustomerBooking->new();
		$oCustomerBooking->updateMemberID($hBookingDetails->{iBookingNumID}, $oDetails->{iMemberID});	
	}
	#added code to check office origin for jira wwa-703 by pkokate
	my $cNewOffice = '';
	foreach $key (keys(%{$oDetails}))
	{
		$string = "branch." . $key;
		if ($key eq "cEmail")
		{
			$cNewOffice = $oDetails->{$key};
			$cNewOffice = uc(substr($cNewOffice,0,5));
			$oDetails->{$key} = $cEmailPrefix.$oDetails->{$key};
		}	
		$hBookingDetails->{$string} = $oDetails->{$key};

	}

	# Modified code to concatenate company name & city name, for bug 10825, by vbind 2013-02-19.
	my $cCompCityDetails = $hBookingDetails->{'branch.cCompanyname'};
	# added code to check origin and Portofloading with array for jira wwa-649 by pkokate on 28 jan 2020
	# modified if condition, remove or condition for $hBookingDetails->{cPortoflading} for jira wwa-703 by pkokate	
	if(grep(/^$cNewOffice$/,@aOrigin))
	{
		$hBookingDetails->{'branch.cCompanyname'} = $cPrgSetting->{cExtendedcode};
		$cCompCityDetails = $cPrgSetting->{cExtendedcode}; 
	}
	#Added code to pass city name which fetch from sei_Office_map for mission 29637  by bnagpure. 	
	if($oDetails->{cCity} && $oDetails->{cCity}  ne "")
	{
		$cCompCityDetails .= " - ".$oDetails->{cCity};
	}
	else
	{
		 $cCompCityDetails .= " - ".$oDetails->{cAltcityname};
	}
	$hBookingDetails->{'branch.cCompCityDetails'} = $cCompCityDetails;

	# Reused the hash of MemberDetails for bug 14087 by rpatra.
	$member = $hBookingDetails->{MemberDetail};

	# Modified the code to pass proper UserID to gen_User table for Bug 6516 by rpatra 2012-02-28
	# Modified the code the to send mails as per sender's notification format for bug 6516 by rpatra 2012-03-02

	$user = wwa::DO::User->new();
	$user->getRecord($hBookingDetails->getUserID);

	# Modified the code to add additional mail id for bug 6516 by kunavane 2012-03-22.
	
	foreach my $key (keys(%{$member}))
	{
		my $string = "member." . $key;
		$hBookingDetails->{$string} = $member->{$key};
	}

	# Get the bol receipt link.
	# Calculate the sha1 value of the receipt variable in the receipt link
	my $dbh = wwa::DBI->new();

	$collection = $self->{_details}->[0]->{_lineItems};
	if (defined($collection))
	{
		$collection->resetCounter;
		while ($collection->hasMoreElements)
		{
			my $item = $collection->getNextElement;
			next unless(defined($item));

			$hBookingDetails->{cWeight} = $item->getWeight;
			$hBookingDetails->{iPieces} = $item->getPieces;
			$hBookingDetails->{cCube} = $item->getCube;
			$hBookingDetails->{cCommodity} = $item->getCommodity;
			$hBookingDetails->{cPackaging} = $item->getPackaging;
			$hBookingDetails->setUOM($item->getUOM);
			last;
		}
	}

	# Removed the code to store specialUOM of members for bug 14087 by rpatra

	my $emailtype;
	my $body;
	$self->email(wwa::EI::Email->new($hBookingDetails->{_RequestType}));

	 # Added communication/forwarder reference in template hash for bug 8942 , by smozarkar 2012-12-20
        $hBookingDetails->{cCommuRef} = "";

	# Append the string as per customer required references for bug 16086 by rpatra
	my $cValidationValue = $hBookingDetails->{validationvalue};
	my $cValidationRef = $hBookingDetails->{validationreference};
	# Changed  : with , for Mission 16920 by msawant	
	$hBookingDetails->{cCommuRef} = ", ". ucfirst($cValidationRef)." ". $hBookingDetails->$cValidationValue if($hBookingDetails->$cValidationValue ne "");
	$hBookingDetails->{cContactPerson} = $hBookingDetails->getContactPerson;
	
	if($member->getBkgsendinitialcustomeremail eq 'Y')
	{
		if($user->getNotificationformat eq "H")
		{
			$emailtype = "Html";
			my $dbh = wwa::DBI->new();

			my $template = wwa::Template->new("EIBookingRequestHtmlTemplateName");

			my $templatetitle = $template->getTemplate;
			my $tmp = wwa::DO::GetHeaderFooter::getHeaderFooter($templatetitle);
		
			# Modified the code for the content of booking receipt for bug 13164 by schavan 2013-06-26
			# Modified the code for header for Mission 16920 by msawant
			$tmp->{cHeader} =~ s/RESERVEDtopicText/EDI LCL WWA Reference Number $hBookingDetails->{iBookingNumID}/;

			my $year = POSIX::strftime("%Y", localtime(time));


			$tmp->{cFooter} =~ s/RESERVEDyear/$year/;
			$body = $tmp->{cHeader} . $self->email->createCustomerMessage($hBookingDetails, $emailtype) . $tmp->{cFooter};
		}
		else
		{
			$emailtype = "Text";
			$body = $self->email->createCustomerMessage($hBookingDetails, $emailtype);

		}

		my $oProgramSetting = wwa::DO::MemberSetting->new;
		#Added code to get Setting and check with country code for jira wwa-474 by bnagpure.
		my $cCustomercontrolcode = '';
		$cCustomercontrolcode = $hBookingDetails->{cCustomercontrolcode} if(defined($hBookingDetails->{cCustomercontrolcode}) && $hBookingDetails->{cCustomercontrolcode} ne '');
		#Added code to get Setting and check with country code for jira wwa-474 by bnagpure.
		my $pSetting = $oProgramSetting->loadProgramSettings($hBookingDetails->{iProgramID},$hBookingDetails->{iMemberID});
		my $cCountryCode = $pSetting->{stop_cust_notification}{$hBookingDetails->{Officedetails}->{cCompanycode}};
		#Added code to get Setting and check customerControlcode for jira wwa-1515 by bnagpure.
		my $OfficeCode = $pSetting->{Check_Office_code}->{Y};
		my @cOfficeCode = split /,/, $OfficeCode if(defined($OfficeCode) && $OfficeCode ne '');

		if (defined($cCustomerEmail) && ($cCustomerEmail ne "") && ($cCustomerEmail !~ /^\.\@\.com/i))
		{
			if(!defined($cCountryCode) || $cCountryCode ne $hBookingDetails->{Officedetails}->{cCountryCode})
			{
				if(defined($cCustomercontrolcode) ne  grep(/^$cCustomercontrolcode$/,@cOfficeCode))
				{
					$oMail = wwa::Mail->new();
					$oMail->body($body);
					$oMail->subject($self->email->createCustomerMessageSubject($hBookingDetails));
					$oMail->to($cCustomerEmail);
					$oMail->send();
				}
			}
		}
	}
	if ($hBookingDetails->{iOfficeMapID})
	{
		$self->email(wwa::EI::Email->new($hBookingDetails->{_RequestType}));
		$oMail = wwa::Mail->new();

		#Added for handling office message body.

		#New Values required by Handling Office Message body.

		$hBookingDetails->{cAddress}=$user->getAddress;
		$hBookingDetails->{cPostalCode}=$user->getPostalcode;
		$hBookingDetails->{cCity}=$user->getCity;
		$hBookingDetails->{cState}=$user->getState;
		$hBookingDetails->{cCountry}=$self->getCountry($user->getCountryId);
		$hBookingDetails->{cFax}=$user->getFax;
		$hBookingDetails->{cEmail} = $hBookingDetails->{cEmail};
		$hBookingDetails->{changes} = $self->nl2br($hBookingDetails->{changes});

		#Values for Handling office till here

		# Change the Email variable for bug 13712 by psakharkar
		my $cMemberEmail = $cEmailPrefix.$cEmail if (defined($cEmail) && $cEmail ne "");

		my $template = wwa::Template->new("EIBookingRequestHtmlTemplateName");
		my $templatetitle = $template->getTemplate;
		my $tmp = wwa::DO::GetHeaderFooter::getHeaderFooter($templatetitle);
		# added code to send actual customer name in booking email notification to customer for jira wwa-639 by pkokate on 23 jan 2020	
		if(defined($hBookingDetails->{MemberSettings}->{PortalTransfer}) && $hBookingDetails->{MemberSettings}->{PortalTransfer} eq "Y")
		{
			my $cMember = wwa::DO::Member->new();
                	my $cCompanyInfo = $cMember->getRecordForCompanyCode($hBookingDetails->{sender});
			$hBookingDetails->{'member.cCompanyName'} = $cCompanyInfo->{cCompanyName};
		}
		#Modified code for header for Mission 16920 by msawant.
		$tmp->{cHeader} =~ s/RESERVEDtopicText/EDI LCL Booking From: $hBookingDetails->{'member.cCompanyName'}/;

		my $year = POSIX::strftime("%Y", localtime(time));

		$tmp->{cFooter} =~ s/RESERVEDyear/$year/;
		$body = $tmp->{cHeader} . $self->email->createCustSvcMessage($hBookingDetails) . $tmp->{cFooter};

		$oMail->body($body); #Changin $self->email->createCustSvcMessage($hBookingDetails)
		#to $body

		# Added code send Haz and pick detail in email subject for Mission 28319 by vthakre, 2017-12-01.
		$oMemberSetting = wwa::DO::MemberSetting->new();
		$hEmailSettings = $oMemberSetting->getCodeExtendedcodeValue($oDetails->{iMemberID}, $ENV{app}->{EDI_FILES}->{iProgramID});

		# Check  to make sure we actually got the address right
		# Added code to stop handling office mail if Member is edi_shipco_prod for jira wwa-958 .
		my $cStopOfficeEmail = '';
		$cStopOfficeEmail = $hEmailSettings->{stop_office_email} if((defined($hEmailSettings->{stop_office_email}) && $hEmailSettings->{stop_office_email} ne ''));
		if((defined($cStopOfficeEmail) && $cStopOfficeEmail  ne 'Y')|| ($hBookingDetails->{cBookingType} eq 'M'))
		{
			if (defined($cMemberEmail) && ($cMemberEmail ne "") && $cMemberEmail !~ /^\.\@\.com/i)
			{
				$oMail->to($cMemberEmail);

				my $cSubject = $self->email->createCustSvcMessageSubject($hBookingDetails);
				my $cCountryCode = uc(substr($cEmail,0,2));
				my @aCountry = split(",", $hEmailSettings->{cExtendedcode});

				if ($hBookingDetails->{cBookingType} eq 'C')
				{
					if(defined($hEmailSettings->{subject_line}) && ($hEmailSettings->{subject_line} eq 'Y' && (grep /^$cCountryCode/,@aCountry)))
					{
						$cSubject .= " PickUp" if(defined($hBookingDetails->{cPickup}) && $hBookingDetails->{cPickup} eq 'Y');				
						$cSubject .= " HAZ" if(defined($hBookingDetails->{cHazardous}) && $hBookingDetails->{cHazardous} eq 'Y');
					}
				}	

				$oMail->subject($cSubject);
				$oMail->send();
			}
		}	
	}
	my $cDatadir = $ENV{app}->getMessage;
	# Added code to export file with blank booking number if request type N with booking number by msawant for Mission 26638
	if(($hBookingDetails->getRequestType eq 'N') && ($hBookingDetails->getBookingnumber ne ''))
        {
		# Changed sed command for Mission 26638 by msawant
                system("sed -i -re 's#<BookingNumber>.*</BookingNumber>#<BookingNumber></BookingNumber>#g' $cDatadir");
        }
	# Added support to remove MoveType and ServiceType before transmitting file to Member for mission 30075 by smadhukar on 12-Apr-2019
	system("sed -i -re '/<MoveType>/d' $cDatadir");
	system("sed -i -re '/<ServiceType>/d' $cDatadir");
	# Mission 30390 : Added support to remove LegInfo before transmitting file to Member for by smadhukar on 28-June-2019
	system("sed -i -re '/<LegInfo>/d' $cDatadir");
	
	$self->addWWAreference($cDatadir);			
	# Modified code to not to pass $hProgramdetails to transferFile(), for bug 14159, by vbind 2013-09-26.
	$self->transferFile($oDetails,$cDatadir,$hBookingDetails);
	# Called logIntoReportingTables to store data in reporting table for Mission 25860 by msawant
	$self->logIntoReportingTables;
	
}

# Moved code to store data in reporting table from DB.pm for Mission 25860 by msawant
sub logIntoReportingTables
{
        my $self = shift;

        my $cDetails = $self->{_details}->[0];
        my $cOrigin = ($cDetails->getOrigin) ? $cDetails->getOrigin : $cDetails->getPortOfLoading;
	my $cDestination = '';
       	if($cDetails->{cBookingType} eq 'C')
       	{
               	$cDestination = ($cDetails->getDestination) ? $cDetails->getDestination : $cDetails->getPortOfDischarge;
       	}
       	elsif($cDetails->{cBookingType} eq 'M')
       	{
               	$cDestination = substr($cDetails->{cReceiverID},0,5);
   	}
        my $cCutoff = (defined($cDetails->getCutoff) && $cDetails->getCutoff ne '') ? $cDetails->getCutoff : '0000-00-00';
        my $cStatusCode;
        my $tStatusDateTime = POSIX::strftime('%F %T',localtime(time));
        my $oDbh = wwa::DBI->new();
   	my $cHazardousFlag = 'N';
        my $iPieces = 0;
	my $cUom = '';
	my ($nWeightKG, $nVolumeCBM, $nWeightLBS, $nVolumeCBF) = ('0.000', '0.000', '0.000', '0.000');
	
        # Added the code to add the multiple cargo details for the mission 26695 by vpatil on 20-04-2016 
        $cCargoDetails = $self->{_details}->[0]->{_lineItems};
        if (defined($cCargoDetails))
                {
                        $cCargoDetails->resetCounter;
                        while ($cCargoDetails->hasMoreElements)
                        {
                                my $hCargoDetails = $cCargoDetails->getNextElement;
                                next unless(defined($hCargoDetails));
                                $cHazardousFlag = $hCargoDetails->getHazardousFlag if(defined($cHazardousFlag) && $cHazardousFlag ne 'Y');
				$cUom = $hCargoDetails->getUOM;
				if (defined($hCargoDetails->getUOM) && $hCargoDetails->getUOM eq 'E')
                                {
                                	$nWeightLBS += $hCargoDetails->getWeight;
					$nVolumeCBF += $hCargoDetails->getCube;
                                }
                                elsif (defined($hCargoDetails->getUOM) && $hCargoDetails->getUOM eq 'M')
                                {
                                        $nWeightKG +=  $hCargoDetails->getWeight;
                                        $nVolumeCBM += $hCargoDetails->getCube;
                                }
                                $iPieces += $hCargoDetails->getPieces;
			}
		}
	if (defined($cUom) && $cUom eq 'E')
	{
		($nWeightKG, $nVolumeCBM, $nWeightLBS, $nVolumeCBF) = $self->convertUOM('', '', $nWeightLBS, $nVolumeCBF);
	}
	elsif (defined($cUom) && $cUom eq 'M')
	{
		($nWeightKG, $nVolumeCBM, $nWeightLBS, $nVolumeCBF) = $self->convertUOM($nWeightKG,$nVolumeCBM, '','');                         
	}

        if ($cDetails->getRequestType eq 'N')
        {
                $cStatusCode = '5';

		# Added code pass two parameters OriginMemberID and DestinationMemberID to stored procedure for Mission 28095 by vthakre, 2017-11-30.
		my $iOriginMemberID = '0';
		my $iDestinationMemberID = '0';

		if ($cDetails->{cBookingType} eq 'C')
		{
			$iOriginMemberID = $cDetails->{Officedetails}->{iMemberID};
			$iDestinationMemberID = $cDetails->{iImportOwnerID};
		}
		elsif ($cDetails->{cBookingType} eq 'M')
		{
			$iOriginMemberID = $cDetails->{iImportOwnerID}; 
			$iDestinationMemberID = '0';
		}
		
                # Bug 16980
                # Parse new parameter ETAPortOfDischarge is blank to shipmentDetailsMap for mission 22657 by psakharkar on Fri, Sep 19 2014
                # Parse new parameter after ETAPortOfDischarge to shipmentDetailsMap for mission 25014 by psakharkar on Thursday, March 19 2015
                # Parse new parameter Carrier SCAC for mission 28061 by bpatil
                my $cQuery = 'CALL shipmentDetailsMap (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);';
                my $cSth = $oDbh->prepare($cQuery) || handleError(10202,"$cQuery (" .$oDbh->errstr. ")");
                $cSth->execute($self->{iShipmentID},$self->{cCustomerAlias},$cDetails->getBookingNumID,'','','','',$cCutoff,$cDetails->getETA,$cDetails->getETD,$cOrigin,$cDestination,$cStatusCode,'E',$cDetails->getUserID,$tStatusDateTime,'','',$cDetails->getPortOfLoading,$cDetails->getPortOfDischarge,'',$cDetails->getVoyage,$cDetails->getVesselName,$cDetails->getShipperRef,$cDetails->getConsigneeRef,$cDetails->getCustRef,$iPieces,$nWeightLBS,$nVolumeCBF,$nWeightKG,$nVolumeCBM,$cHazardousFlag,'',$iOriginMemberID,$iDestinationMemberID) || handleError(10203, "$cQuery (" . $cSth->errstr . ")");
        }
        elsif ($cDetails->getRequestType eq 'C')
        {
                $cStatusCode = '11';

        }
        # Parse new parameter tCutOff to updateShipmentDetails procedure for mission 21817 by psakharkar on Wed, Aug 06 2014
        # Passed Container parameter as blank for mission 21904 by rpatra.
        # Parse new parameter ETAPortOfDischarge is blank to updateShipmentDetails for mission 22657 by psakharkar on Fri, Sept 19 2014
        # Parse new parameter Voyageno,Vesselname to updateShipmentDetails for mission 25014 by psakharkar on Thursday, March 19 2015
	#Added cStatuscode as for the mission 26695 by vpatil
	#Parse new parameter Carrier SCAC for mission 28061 by bpatil
	$cStatusCode = '5' if ($cDetails->getRequestType eq 'U');
	# Added parameter to update wwa reference for Mission 29203 by vthakre 2018-10-29
        my $cQuery = 'CALL updateShipmentDetails (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);';
        my $cSth = $oDbh->prepare($cQuery) || handleError(10202,"$cQuery (" .$oDbh->errstr. ")");
        $cSth->execute($self->{iShipmentID},'','','','','',$cStatusCode,$tStatusDateTime,$cOrigin,'',$cDetails->getETA,$cDetails->getETD,$cCutoff,$cDetails->getUserID,'',$cDetails->getVoyage,$cDetails->getVesselName,$iPieces,$nWeightLBS,$nVolumeCBF,$nWeightKG,$nVolumeCBM,$cHazardousFlag,'',$cDetails->getBookingNumID) || handleError(10203, "$cQuery (" . $cSth->errstr . ")");


}

#Following subroutine will convert Metric to English and vice versa for mission 26695 by vpatil on 15-04-2016

sub convertUOM
{

        my ($self, $nWeightKG, $nVolumeCBM, $nWeightLBS, $nVolumeCBF) = @_;

        if ($nWeightLBS eq "" && $nVolumeCBF eq "" && $nWeightKG ne "" && $nVolumeCBM ne "")
        {
                        $nWeightLBS = sprintf("%0.3f",((defined($nWeightKG) ? $nWeightKG : 0) * 2.2046226));
                        $nVolumeCBF = sprintf("%0.3f",((defined($nVolumeCBM) ? $nVolumeCBM : 0) * 35.3147248));
        }
        elsif($nWeightKG eq "" && $nVolumeCBM eq "" && $nWeightLBS ne "" && $nVolumeCBF ne "")
        {
                        $nWeightKG = sprintf("%0.3f",((defined($nWeightLBS) ? $nWeightLBS : 0) * 0.45359237));
                        $nVolumeCBM = sprintf("%0.3f",((defined($nVolumeCBF) ? $nVolumeCBF : 0) / 35.3147248));
        }

        return ($nWeightKG, $nVolumeCBM, $nWeightLBS, $nVolumeCBF);

}

sub email
{
	my $self = shift;
	my $newValue = shift;
	$self->{email} = $newValue if (defined($newValue));
	return (defined($self->{email})) ? $self->{email} : $self->email(wwa::EI::Email->new());
}

sub getBookingID
{
	my $self = shift;
	return($self->{_details}->{iBookingID}) if (defined($self->{iBookingID}));
}




sub transferFile
{
	# Modified code to not to accept $hProgramdetails , for bug 14159, by vbind 2013-09-26.
	my ($self,$oDetails,$cDatadir,$hBookingDetails)=@_;
	my $iReturn = 0;		
	
	if(defined($oDetails->{cCompanycode}) && $oDetails->{cCompanycode} ne "")
	{
		$cDatadir =~ m#^.+/data/ei/(.+)/(.+)#;	
		my $cDestinationdir = $1;
		my $cDestinationFilename = $2;
		# Added code to transfer file into shipco's downloadc directory for member to member booking request for Mission 27774 by vthakre 2017-03-24.
		my $oMembersetting = wwa::DO::MemberSetting->new();
		# Changed function to get cExtendedcode from sei_Member_setting table for Mission 27897 by vthakre on 2017-06-28.
		my $cSettings = $oMembersetting->getCodeExtendedcodeValue($oDetails->{iMemberID}, $ENV{app}->{EDI_FILES}->{iProgramID});

		#Added code to update portalid in boo_booking and replace the sender for jira WWA-499 by vgarasiya on 25-11-2019
		if(defined($hBookingDetails->{'replace_sender'}) && $hBookingDetails->{'replace_sender'} ne '')
                {
			my $oMember = wwa::DO::Member->new();
 		        my $cNewMemberRecord = $oMember->getRecordForCompanyCode($hBookingDetails->{NewAckReceiver});
                	$iMemberID = $cNewMemberRecord->{iMemberID};
			my $oCustomerBooking = wwa::DO::CustomerBooking->new();
                	$oCustomerBooking->updatePortalID($hBookingDetails->{iBookingNumID},$iMemberID);
                        system("sed -i -re 's#<SenderID>.*</SenderID>#<SenderID>$self->{'_details'}->[0]->{'replace_sender'}</SenderID>#g' $cDatadir 2>/dev/null");
                }
		#WWA-932 - Set ReceiverID and Envelope version from schema for pcspanama from link by smadhukar
		if(defined($cSettings->{set_receiver}) && $cSettings->{set_receiver} eq 'Y')
		{
			my $isExist = (system("grep '<ReceiverID>' $cDatadir > /dev/null")) ? 1 : 0;
			my $cNewReceiver = $cSettings->{cExtendedcode};
			if(defined($isExist) && $isExist eq '0')
			{
				system("sed -i -re 's#<ReceiverID>.*</ReceiverID>#<ReceiverID>$cNewReceiver</ReceiverID>#g' $cDatadir 2>/dev/null");
			}
			else
			{
				system("sed -i -re 's#</SenderID>#</SenderID>\\n\\t<ReceiverID>$cNewReceiver</ReceiverID>#g' $cDatadir");	
			}

		}
		#WWA-938 - Convert the file as per schema for pcspanama by smadhukar on 22-JUN-2020
		if(defined($cSettings->{xslt_schema_conversion}) && $cSettings->{xslt_schema_conversion} eq 'Y')
		{
			 my $path = $ENV{app}->datapool->get('config.xml.global.xsl_file');
			 $path = $path."/"."booking_request/".$cSettings->{cExtendedcode}.".xsl";
			 my $oUniversalObj = wwa::Utility::Universal->new();
			 my $cNewFilename = $oUniversalObj->convertXML($cDatadir, $path);
			 `xmllint -o $cNewFilename --format  $cNewFilename`;
			 `/bin/mv $cNewFilename $cDatadir`;
		}
		if(defined($hBookingDetails->{_SchemaVersion}) && $hBookingDetails->{_SchemaVersion} ne '')
		{
			system("sed -i -re 's#<Version>.*</Version>#<Version>$hBookingDetails->{_SchemaVersion}</Version>#g' $cDatadir 2>/dev/null");
		}
		else
		{
			if(defined($cSettings->{set_version}) && $cSettings->{set_version} eq 'Y')
			{
				system("sed -i -re 's#<Version>.*</Version>#<Version>1.1.0</Version>#g' $cDatadir 2>/dev/null");
			}
		}


		my $cMemberdownloaddir = "";
		if($self->{_details}->[0]->{cBookingType} eq 'M' && (defined($cSettings->{cDestination}) && $cSettings->{cDestination} ne ""))
		{
			$cMemberdownloaddir = $cSettings->{cDestination}."/";
		}
		# Added code to send file to pheonix if member is shipco for Mission 27897 by vthakre on 2017-06-28.
		elsif(defined($cSettings->{send_to_phoenix}) && $cSettings->{send_to_phoenix} eq 'Y')
		{
			$cMemberdownloaddir = $cSettings->{cExtendedcode}."/";	
		}
		else
		{
			$cMemberdownloaddir = "/home/".$oDetails->{cCompanycode}."/download/".$cDestinationdir."/";
		}
		# Added code to change extension of file to .xml if extension is other than xml for bug 11441
		# Added by psakharkar on Tuesday, March 19 2013 04:50:32 PM
		# Changed regex to hanlde the issue related to chnage in filename while transferring to member.
		# for mission 27846 by bpatil..
		if(defined($cDestinationFilename) && $cDestinationFilename =~ m/[^.].+(\.(?!\.xml).+)$/i)
		{
			#$cDestinationFilename =~ s/$1/\.xml/g;
			if($1 =~ m/['\.txt']$/g)
			{
				$cDestinationFilename =~ s/\.txt$/\.xml/g;
			} 
		}

		# If reciever is shipco then change SenderID for bug 14087 by rpatra.
		my $iFlag = 1;
		$iFlag = 0 if ($oDetails->{cCompanycode} eq 'edi_shipco_prod');
		my $oUniversal = wwa::Utility::Universal->new();
		$oUniversal->exchangeUserID(0,$iFlag,$cDatadir);
		$cDestinationFilename .= '.xml' if(defined($cDestinationFilename) && $cDestinationFilename !~ /\.xml$/i);
		my $cDestFileName = $cDestinationFilename;
		$cDestinationFilename = $cMemberdownloaddir.$cDestinationFilename;
		my $oWorker = wwa::Utility::Distributor::Worker->new();
		my $oCopy = wwa::Utility::Distributor::Worker::Transfer::Copy->new;
		$oCopy->init;
		$oCopy->source($cDatadir);
		$oCopy->destination($cDestinationFilename);
								
		$oCopy->memberID($oDetails->{iMemberID});
		$oCopy->semaphore($oWorker->getSemaphoreFromUser($oDetails->{cCompanycode}));
		#
		# Set the target user and group now
		#
		my (undef, undef, $uid, $gid, undef) = getpwnam($oDetails->{cCompanycode});
		$oCopy->uid($uid); 
		$oCopy->gid($gid);
		$oCopy->transfer;
		# Added condition to log $cDestinationFilename & $cMemberdownloaddir for bug 10368
	        # Added by psakharkar on Thursday, January 03 2013 10:42:10 AM
		if(defined($ENV{app}->{EDI_FILES}->{ProcessLog}) && $ENV{app}->{EDI_FILES}->{ProcessLog} eq 'Y')
		{
			# Corrected the file logging for zipped files for bug 14087 by rpatra.
			my $cOrgFile = $ENV{app}->{EDI_FILES}->{cFileName};
		
			$cOrgFile =~ s/(\.gz|\.zip|.bz2)//i;
			#Changed regex to escape special character in filename for mission 27846 by bpatil. 
			if(defined($ENV{app}->getMessage) && $ENV{app}->getMessage =~ /\Q$cOrgFile\E$/i)
			{
				# Removed code to update iStatus from module for mission 28895 by bpatil
				$self->logProcessFile($cDestFileName,$cMemberdownloaddir,$oDetails);
			}
		}

		#Added code to tranfer exported file to outgoing directory for mission 28112 by nwanjari on 26 oct 2017. 
		$self->exchangeXML($oDetails,$cDestinationFilename,$cDatadir);	
		
		#Added code to send acknowledgment to customer for Mission 27449 by vthakre 2017-04-25.
		my $oMember = wwa::DO::Member->new;
		$oMember->getRecordForCompanyCode($hBookingDetails->{sender});
		
		my $iMemberID = $oMember->getMemberID;
	
		my $hSettings = $oMembersetting->getSettings($iMemberID, $ENV{app}->{EDI_FILES}->{iProgramID});
		my $hPortalSettings = $hBookingDetails->{PortalMemberSettings};
	
		# Modified condition to send acknowledgemnt to portal for mission 29114 by bpatil	
		if((defined($hSettings->{acknowledge_xml}) && $hSettings->{acknowledge_xml} eq 'Y') || (defined($hPortalSettings->{acknowledge_xml}) && $hPortalSettings->{acknowledge_xml}))
                {
                        my $cAckFile = &File::Basename::basename($ENV{app}->getMessage);
			# Added code to concatenate .ack to APERAK file for Mission 28602 by vthakre, 2018-09-21
                        $cAckFile .= '_ack';

                        my $cFile = $ENV{app}->datapool->get('config.xml.global.temp_bookdir').$ENV{app}->{user_name}."/".$cAckFile;
                        if(-f $cFile)
                        {
				# Added code to send aperak for Mission 28188 by vthakre, 2017-11-07.
				# Added NewAckReceiver check to getting acknowledge in wwa format for jira WWA-499 by vgarasiya on 25-11-2019
				if((defined($hSettings->{wwa_format}) && $hSettings->{wwa_format} eq 'Y') || (defined($hPortalSettings->{wwa_format}) && $hPortalSettings->{wwa_format} eq 'Y') || (defined($hBookingDetails->{NewAckReceiver}) && $hBookingDetails->{NewAckReceiver} ne '') )
				{
					if(defined($hBookingDetails->{_RequestType}) && $hBookingDetails->{_RequestType} =~ /(U|C)/)
        				{
				                system("sed -i -re 's#<BookingNumber></BookingNumber>#<BookingNumber>$self->{BookingNumber}</BookingNumber>#g' '$cFile'") if(defined($self->{BookingNumber}) && $self->{BookingNumber} ne '0');
        				}
					`sed -i s/ackstatus/A/g "$cFile"`;
					# Added remark as Accepted in tag for Mission 28347 by vthakre om 2017-12-27.
					system("sed -i -re 's#<Remarks></Remarks>#<Remarks>Accepted</Remarks>#g' '$cFile'");
				}
				else
				{
					system("sed -i -re 's#<Acknowledgement>#<Acknowledgement>\\n\\t\\t    <Status>A103</Status>#g' $cFile");	
				}

				my $hAperakStatus;
                                $hAperakStatus->{Status} = "ACCEPTED";

				$self->{_removeTempFile} = 'Y';

				$self->transferAckXml($cFile, $hAperakStatus, $hBookingDetails);
			}
		}

	}
	return($iReturn);
}

# Removed the condition to get WWARefernece from tra_Bok_header for bug 11694 by rpatra

sub addWWAreference
{
	my ($self,$cDatadir) = @_;
	# Added code to process file having space in file name for bug 25294 by adhanwde
	$cDatadir=~ s/\s/\\ /g;
	foreach $hbookingDetails (@{$self->{_details}})
	{
		if ($hbookingDetails->getBookingNumID ne 0)
		{
			my $cWWAReference = $hbookingDetails->getBookingNumID;

			# Added code to add link in xml file for Mission 27449 by vthakre 2017-04-13.
			system("sed -i -re 's#<BookingRequest xmlns:xsd=\"http://www.bluenet.rohlig.com/rbn/RohligService/\" xsd:noNamespaceSchemaLocation=\"http://wiki.wwalliance.com/wiki/images/b/bd/WWA_Booking_Request_version_1.1.0.xsd\"#<BookingRequest xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:noNameSpaceSchemaLocation=\"http://wiki.wwalliance.com/wiki/images/b/bd/WWA_Booking_Request_version_1.1.0.xsd\"#g' $cDatadir");

			# Added the WWAShipmentReference tag after CustomerControlCode for bug 14087 by rpatra.
                        system("sed -i -re 's#<CustomerControlCode>#<WWAShipmentReference>$cWWAReference</WWAShipmentReference>\\n      <CustomerControlCode>#g' $cDatadir");
                        system("sed -i -re 's#<EnvelopeID></EnvelopeID>#<EnvelopeID>$cWWAReference</EnvelopeID>#g' $cDatadir");
			# Added condition for member to member booking for Mission 27675 by vthakre 2017-20-28.
			my $iTemp = (system("grep '<ApplicationType>' $cDatadir > /dev/null")) ? 1 : 0;
			
			if ($iTemp == 1)
			{
				# Added the ApplicationType tag after BookingDetails for bug 20108 by rpatra
				system("sed -i -re 's#<BookingDetails>#<BookingDetails>\\n\\t<ApplicationType>WE</ApplicationType>#g' $cDatadir");
			}

			# Added code to print SubmitterType as M/C for Mission 27897 by vthakre on 2017-06-28.
			my $cAppType = (system("grep '<ApplicationType>WE</ApplicationType>' $cDatadir  > /dev/null")) ? 1 : 0;
			system("sed -i -re 's#<BookingDate>#<SubmitterType>$self->{_details}->[0]->{cBookingType}</SubmitterType>\\n\\t<BookingDate>#g' $cDatadir") if(defined($cAppType) && $cAppType == 0);
		
			# Added code to print Weight,Volume and UOM based on country for panalpina for mission 28518 by bpatil,26-02-2018
			my $cCountry = substr($hbookingDetails->{cOrigin},0,2);
			#Added code to replace RequestType U to N for panalpina for Mission 30177 by smadhukar on 08-May-2019
			if(defined($hbookingDetails->{MemberSettings}{_changeType}) && $hbookingDetails->{MemberSettings}{_changeType} eq "Y")
			{
				 system("sed -i -re 's#<RequestType>U</RequestType>#<RequestType>N</RequestType>#g' $cDatadir");
			}	
			if(defined($hbookingDetails->{MemberSettings}{special_uom}) && $hbookingDetails->{MemberSettings}{special_uom} ne "")
			{
				if ($hbookingDetails->{MemberSettings}{special_uom} =~ m/$cCountry/i)
				{
				# Added code to remove extra UOM from file where special_uom is already set for customer for mission 30509 by smadhukar on 1-AUG-2019
					system("sed -i -re '/<UOM>/d' $cDatadir");
					system("sed -i -re '/<Weight UOM=\"KGS\">/d' $cDatadir");
					system("sed -i -re '/<Volume UOM=\"CBM\">/d' $cDatadir");
                                	system("sed -i -re 's#<Weight UOM=\"LBS\">#<Weight>#g' $cDatadir");
                                	system("sed -i -re 's#<Volume UOM=\"CFT\">#<Volume>#g' $cDatadir");
                                	system("sed -i -re 's#</Volume>#</Volume>\\n\\t<UOM>E</UOM>#g' $cDatadir");
				}
				else
				{
					system("sed -i -re '/<UOM>/d' $cDatadir");
					system("sed -i -re '/<Weight UOM=\"LBS\">/d' $cDatadir");
	                                system("sed -i -re '/<Volume UOM=\"CFT\">/d' $cDatadir");
	                                system("sed -i -re 's#<Weight UOM=\"KGS\">#<Weight>#g' $cDatadir");
	                                system("sed -i -re 's#<Volume UOM=\"CBM\">#<Volume>#g' $cDatadir");
	                                system("sed -i -re 's#</Volume>#</Volume>\\n\\t<UOM>M</UOM>#g' $cDatadir");	
				}
			}
		}
	}
	$cDatadir=~ s/\\ /\ /g;
}

sub getCountry
{
	my $self=shift;
	my $Countryid=shift;

	my $dbh = wwa::DBI->new();
	my $query = "SELECT cName FROM gen_Country WHERE iCountryID = '".$Countryid."'";

	my $sthtmp = $dbh->prepare($query) || handleError(10202,"$query (" .$dbh->errstr. ")");
	$sthtmp->execute() || handleError(10203, "$query (" . $sthtmp->errstr . ")");

	my $temprow = $sthtmp->fetchrow_hashref;
	return ($temprow->{cName});

}

=head logProcessFile

This subrouting used to log File Process
Added by psakharkar on Thursday, January 10 2013 12:18:02 PM

=cut

sub logProcessFile
{
        my($self,$cFileName,$cDestinationPath,$oDetails) = @_;
        my $oEdiFile = wwa::DO::WeiFileLog->new();
        $oEdiFile->setFileID($ENV{app}->{EDI_FILES}->{iFileID});
        $oEdiFile->setReceiver($oDetails->{cCompanycode});
        $oEdiFile->setUpdated(strftime('%F %T',localtime));
        $oEdiFile->updateFileLog();

        my $oEdiFileProcess = wwa::DO::WeiFileProcessLog->new();
        $oEdiFileProcess->setDestFileName($cFileName);
        $oEdiFileProcess->setDestFilePath($cDestinationPath);
        $oEdiFileProcess->setProcessStatus('E');
        $oEdiFileProcess->setUpdated(strftime('%F %T',localtime));
        $oEdiFileProcess->setFileProcessID($ENV{app}->{EDI_FILES}->{iFileProcessID});
        $oEdiFileProcess->updateFileProcessLog();
}

=head

Call procedure shipmentRouteMap & get the details for bug 13712
by psakharkar on Tuesday, August 13 2013 05:13:59 PM


=cut

sub getShipmentRouteMap
{
	my $self = shift;
	
	# Modified code to use programid from base hash, for bug 14159, by vbind 2013-09-18.
	my $nBookingDetails = shift;

	my $oDbh = wwa::DBI->new();
	my $cQuery = 'CALL shipmentRouteMap(?,?,?,@a,@b,@c,@d,@e);';
	my $cSth = $oDbh->prepare($cQuery) || handleError(10202,"$cQuery (" .$oDbh->errstr. ")");

	$cSth->execute($nBookingDetails->{cOrigin},$nBookingDetails->{cDestination},$nBookingDetails->{iProgramID}) || handleError(10203, "$cQuery (" . $cSth->errstr . ")");

	my @aResult = $oDbh->selectrow_array('select @a,@b,@c,@d,@e');
	my ($iMemberID,$cCompanyCode,$cCompanyName,$cEmail,$iBranchID) = @aResult;

	return ($iMemberID,$cCompanyCode,$cCompanyName,$cEmail,$iBranchID);

}


sub getDestinationMemberDetails
{
	my ($self,$hBookingDetails) = @_;
	my ($iMemberID,$cCompanyCode,$cCompanyName,$cEmail,$iBranchID,$cOfficeEmail,$iOfficeMemberID ) = ('','','','','','','');

	my $oDetails = {};

	# Added condition for member to member booking for Mission 27675 by vthakre 2017-20-28.	
	if ($hBookingDetails->{cBookingType} eq 'C')
	{

		#added code to get member setting and avoid to call getShipmentRouteMap if settings are available for mission 30355 by pkokate on date 19 july 2019
		my $oSetting = wwa::DO::MemberSetting->new();
		my $hSetting = $oSetting->getSettings($hBookingDetails->{iMemberID},$hBookingDetails->{iProgramID});
		if(!defined($hSetting->{CustomerControlCode_map}) || $hSetting->{CustomerControlCode_map} ne 'Y')
		{

			($iMemberID,$cCompanyCode,$cCompanyName,$cEmail,$iBranchID) = $self->getShipmentRouteMap($hBookingDetails);
		}
	}
	#Modified the code for mission 27142 to send the email notificaton based on the office code mapping to wwa member office by vpatil on 27-07-2016
	$iMemberID = (defined($iMemberID)) ? $iMemberID : '';
	if (defined($hBookingDetails->{Officedetails}))
	{
		$oDetails = $hBookingDetails->{Officedetails};
		$iOfficeMemberID = $oDetails->{iMemberID};
		$cOfficeEmail = $oDetails->{cEmail} if (defined($oDetails->{cEmail}));
	}

	if( defined($iMemberID) && $iMemberID ne '' && defined($cCompanyCode) && $cCompanyCode ne '' && defined($iBranchID) && $iBranchID ne '' )
	{
	# Modified the code for the mission 27142 to send the email notificaton  based on the office code mapping to wwa member office by vpatil on 27-07-2016
		$oDetails->{cEmail} = ($iMemberID eq $iOfficeMemberID) ? $cOfficeEmail : $cEmail;
		$oDetails->{cCompanycode} = $cCompanyCode;
		my $oBranch = wwa::DO::Branch->new();
		$oBranch->getRecord($iBranchID);
		$oDetails->{cAddress} = $oBranch->getAddress;
		$oDetails->{cAltcityname} = $oBranch->getAltcityname;
		$oDetails->{cTel} = $oBranch->getTel;
		$oDetails->{cFax} = $oBranch->getFax;
		# Added code to fetch City name from web_Branch for mission 29637 by bnagpure.
		$oDetails->{cCity} = $oBranch->getCity;
		
		my $oMember = wwa::DO::Member->new();
		$oMember->getRecord($iMemberID);
		$oDetails->{iUserID} = $oMember->getUserID;
		$oDetails->{iMemberID} = $oMember->getMemberID;
		$oDetails->{cCompanyname} = $oMember->getCompanyName;
		$oDetails->{cCompanycode} = $oMember->getCompanyCode;
		$oDetails->{cContactemail} = $oMember->getContactEmail;
		$oDetails->{cContactphone} = $oMember->getContactPhone;

		# Modified to take details from base hash, for bug 14159, by vbind 2013-09-19.
		$oDetails->{cExternalcode} = $hBookingDetails->{_cExternalcode};
		$oDetails->{cCountry} = $hBookingDetails->{_cCountry};
		$oDetails->{cCity} = $hBookingDetails->{_cCity};
		$oDetails->{cCmscode} = $hBookingDetails->{_CmsCode};
	}
	return $oDetails;
}

=head2 transferAckXml

This function will transfer acknowledge xml to sender's.
Added for Mission 27449 by vthakre 201704-25

=cut

sub transferAckXml
{
	my ($self, $cAckFile , $hAperakStatus, $hBookingDetails)= @_;
	
	my $cFilename = &File::Basename::basename($cAckFile);
        my $cFilePath = &File::Basename::dirname($cAckFile);
	if(defined($ENV{app}->{EDI_FILES}->{ProcessLog}) && $ENV{app}->{EDI_FILES}->{ProcessLog} eq 'Y')
	{
		$self->LogAckFileProcess($cFilename, $cFilePath, $hBookingDetails);
		$self->logAckMetaData($hAperakStatus);
	}

	# Added code to transfer aperak based on portal memberid for mission 29114 by bpatil.
	my $hMemberDetails = $hBookingDetails->{MemberSettings};
	my $iMemberID  = (defined($hMemberDetails->{PortalTransfer}) && $hMemberDetails->{PortalTransfer} eq 'Y') ? $hBookingDetails->{PortalMemberID} : $hBookingDetails->{iMemberID};
	
	eval('use wwa::DO::MemberTransferLog');
        handleError(10101,"$@") if ($@);
        my $oTransferLog = wwa::DO::MemberTransferLog->new();
	
	#WWA-499 : Added code for replace memberid by vgarasiya on 22-11-2019
	if(defined($hBookingDetails->{NewAckReceiver}) && $hBookingDetails->{NewAckReceiver} ne '')
        {
                my $oMember = wwa::DO::Member->new();
                my $cNewMemberRecord = $oMember->getRecordForCompanyCode($hBookingDetails->{NewAckReceiver});
                $iMemberID = $cNewMemberRecord->{iMemberID};
        }
	

        $oTransferLog->getDetails($iMemberID, $ENV{app}->{EDI_FILES}->{iProgramID});

	my $cCustRef = (defined($hBookingDetails->{cCustRef}) && $hBookingDetails->{cCustRef} ne "") ? $hBookingDetails->{cCustRef} : "";
        my $cFile = $oTransferLog->getFileFormat;

	$cFile =~ s/CustomerReference/$cCustRef/g;

	$cFile = $self->fileDateEncode($cFile);
        my $cDestination = $oTransferLog->getDestination;
        my $cTransferType = $oTransferLog->getTransferType;
 	
        my $cDestinationFile = $cDestination.$cFile if ($oTransferLog->getFileFormat ne "");
        if(defined($cTransferType) && $cTransferType ne "0")
        {
                my $cMode = "wwa::Utility::Transfer::".$cTransferType;
                my $cTransfer = $cMode->new();
                $cTransfer->setSourceFilename($cAckFile);
                $cTransfer->setDestFilename($cDestinationFile);
                $cTransfer->setRemotePort($oTransferLog->getPort);
                $cTransfer->setRemoteHost($oTransferLog->getServer);
                $cTransfer->setRemoteUsername($oTransferLog->getUsername);
                $cTransfer->setRemotePassword($oTransferLog->getPassword);
                $cTransfer->transfer;

		if(defined($ENV{app}->{EDI_FILES}->{ProcessLog}) && $ENV{app}->{EDI_FILES}->{ProcessLog} eq 'Y')
		{
                        $self->updateAckFileProcess($cFile, $cDestination);
                        $self->updateStatus($hBookingDetails->{MemberDetail}->{cCompanyCode});
                }
        }

	$self->exchangeAck($cAckFile, $cFile, $hBookingDetails);
	if($self->{_removeTempFile} && $self->{_removeTempFile} eq 'Y')
        {
                unlink($cAckFile);
        }
}

=head1 LogAckFileProcess

This subrouting used to log File Process
Added for Mission 27449 by vthakre 2017-04-25.

=cut

sub LogAckFileProcess
{
        my ($self, $cFilename, $cFilePath, $hBookingDetails) = @_;
	
        my $oFileLog = wwa::DO::WeiFileLog->new();
	my $cSender = $ENV{app}->datapool->get('config.xml.global.defaultwwaID');

        $oFileLog->setUserID($ENV{app}->{EDI_FILES}->{iUserID});
        $oFileLog->setProgramID($ENV{app}->{EDI_FILES}->{iProgramID});
        $oFileLog->setEnteredby($ENV{app}->{EDI_FILES}->{iUserID});
        $oFileLog->setUpdatedby($ENV{app}->{EDI_FILES}->{iUserID});
	$oFileLog->setFilePath($cFilePath);
        $oFileLog->setFileName($cFilename);
        $oFileLog->setReceiver($hBookingDetails->{MemberDetail}->{cCompanyCode});
        $oFileLog->setSender($cSender);
	$oFileLog->setCustomerAlias($hBookingDetails->{cEisendingoffice}) if(defined($hBookingDetails->{cEisendingoffice}));

	my $cOrgFile = $cFilePath.'/'.$cFilename;
	my $iFileTime = (stat($cOrgFile))[10];
	$oFileLog->setFileDate(strftime('%F %T',localtime($iFileTime)));
	$oFileLog->insertAckFileLog();

	# Added code to log aperak file details against aperak fileID for mission 28895 by bpatil
        my $oFileProcess = wwa::DO::WeiFileProcessLog->new();
        $oFileProcess->setFileID($ENV{app}->{EDI_FILES}->{iAckFileID});
        $oFileProcess->setProcessStatus('E');
        $oFileProcess->setEnteredby($ENV{app}->{EDI_FILES}->{iUserID});
        $oFileProcess->setUpdatedby($ENV{app}->{EDI_FILES}->{iUserID});
        $oFileProcess->insertAckFileProcessLog();
}

=head1 logAckMetaData

This subroutine will insert data in wei_MetaData table for Aperak file 
for Mission 27449 by vthakre 2017-04-25.

=cut

sub logAckMetaData
{
	my ($self,$hAperakStatus) = @_;

	my $oMetaData = wwa::DO::WeiMetaData->new();

	$oMetaData->setFileID($ENV{app}->{EDI_FILES}->{iAckFileID});
	$oMetaData->{metadata}{Status} = $hAperakStatus->{Status}
		if(defined($hAperakStatus->{Status}) && $hAperakStatus->{Status} ne "");
	$oMetaData->{metadata}{Remarks} = $hAperakStatus->{Remarks}
		if(defined($hAperakStatus->{Remarks}) && $hAperakStatus->{Remarks} ne "");
	#Added code to logg MetaData for jira wwa-1146 by bnagure
	if(defined($hAperakStatus->{Status}) && $hAperakStatus->{Status} eq 'ACCEPTED')
	{
		$oMetaData->{metadata}{WWAAckSentStatus} = " WWA SENT ACCEPTED ACKNOWLEGEMENT";
	}
	else
	{
		 $oMetaData->{metadata}{WWAAckSentStatus} = "WWA SENT REJECTED  ACKNOWLEGEMENT";
	}                        

	$oMetaData->addAckMetadataValue();
}

=head

This subroutine will update data in wei_File_process table for mission 27449 by vthakre 2017-04-25

=cut

sub updateAckFileProcess
{
	my ($self,$cFile,$cDestination) = @_;

        my $oFileProcess = wwa::DO::WeiFileProcessLog->new();
        $oFileProcess->setDestFileName($cFile);
        $oFileProcess->setDestFilePath($cDestination);
        $oFileProcess->setFileProcessID($ENV{app}->{EDI_FILES}->{iAckFileProcessID});
        $oFileProcess->updateFileProcessLog();
}

=head1 updateStatus

This function will update iStatus in log table,
For Mission 27449, by vthakre 2017-04-26.

=cut

sub updateStatus
{
        my $self = shift;
        my $cReceiver = shift;

        my $oEdiFile = wwa::DO::WeiFileLog->new();
        $oEdiFile->setStatus(1);
        $oEdiFile->setFileID($ENV{app}->{EDI_FILES}->{iAckFileID});
        $oEdiFile->setReceiver($cReceiver) if(defined($cReceiver));
        $oEdiFile->updateFileLog();

        my $oFileProcess = wwa::DO::WeiFileProcessLog->new();
        $oFileProcess->setFileProcessID($ENV{app}->{EDI_FILES}->{iAckFileProcessID});
        $oFileProcess->setStatus(1);
        $oFileProcess->updateFileProcessLog();
}


=head1 exchangeAck

This function will copy acknowledge xml to outgoing path.
for Mission 27449 by vthakre 2017-04-25

=cut

sub exchangeAck
{

	my ($self, $cAckFile ,$cAltFileName, $hBookingDetails) = @_;
	
	my $oExchange = wwa::DO::Exchange->new();
	
	$oExchange->setUserID($ENV{app}->{EDI_FILES}->{iUserID});
	$oExchange->setReceiver($hBookingDetails->{MemberDetail}->{cCompanyCode});
        $oExchange->setSender($ENV{app}->datapool->get('config.xml.global.defaultwwaID'));
	$oExchange->setType("BookingRequest");
	$oExchange->setVersion("1.1.1");
        $oExchange->setAltFilename($cAltFileName);
        $oExchange->setSourceFile($cAckFile);
        $oExchange->direction("outgoing");
	$oExchange->setUserName($ENV{app}->{user_name});
        $oExchange->add;
}

#Added subroutine to tranfer exported file to outgoing directory for mission 28112 by nwanjari on 26 oct 2017.
sub exchangeXML
{
	
	my ($self,$oDetails,$cDestinationFilename,$cDatadir) = @_;
	my $oExchange = wwa::DO::Exchange->new();
	$oExchange->setUserID($ENV{app}->{EDI_FILES}->{iUserID});
	$oExchange->setReceiver($hBookingDetails->{MemberDetail}->{cCompanyCode});
        $oExchange->setSender($ENV{app}->datapool->get('config.xml.global.defaultwwaID'));
        $oExchange->setType("BookingRequest");
        $oExchange->setVersion("1.1.1");
	$oExchange->direction("outgoing");
	$oExchange->setSourceFile($cDatadir);
	$oExchange->setUserName($oDetails->{cCompanycode});
	$oExchange->setFlag("1");
	$oExchange->add;

}





1;

# 
# $Log: Export.pm,v $
# Revision 1.82  2021/06/07 11:13:47  bnagpure
# wwa-1515:Added code to get Setting and check customerControlcode
#
# Revision 1.81  2020/11/06 12:08:16  bnagpure
# wwa-958: Added code to stop handling office mail if Member is edi_shipco_prod
#
# Revision 1.80  2020/09/23 06:49:18  bnagpure
# wwa-1160_wwa-1149: Added MetaData to logg reject Ack details
#
# Revision 1.79  2020/09/14 11:05:44  bnagpure
# wwa-1146 : added code to logg MetaData
#
# Revision 1.78  2020/07/06 11:13:26  smadhukar
# WWA-938: corrected the flag
#
# Revision 1.77  2020/07/06 11:09:13  smadhukar
# WWA-938 - Convert the file as per schema for pcspanama
#
# Revision 1.76  2020/06/17 05:29:46  smadhukar
# WWA-932 - Set ReceiverID and Envelope version from schema for pcspanama
#
# Revision 1.75  2020/02/10 12:27:08  pkokate
# Jira WWA703:added code to check office origin
#
# Revision 1.74  2020/02/07 12:58:05  pkokate
# Jira WWA-703: modified if condition, remove or condition for $hBookingDetails->{cPortoflading}
#
# Revision 1.73  2020/01/29 05:25:02  pkokate
# Jira WWA-649: Added code to change company name if member setting extended code variables eq to origin or PortofLoading
#
# Revision 1.72  2020/01/24 05:23:08  pkokate
# Jira WWA-639: Added code to send actual customer name in booking email notification to customer
#
# Revision 1.71  2019/12/13 09:13:39  bnagpure
# wwa-474 : Added code to get Setting and check with country code
#
# Revision 1.70  2019/11/27 06:44:35  vgarasiya
# WWA-499:For replacing sender and receiver id in Agility booking request
#
# Revision 1.69  2019/08/02 11:22:11  smadhukar
# Mission 30509 : Added code to remove extra UOM from file where special_uom is already set for customer
#
# Revision 1.68  2019/07/23 06:48:17  pkokate
# Mission 30355: Added code to get member setting and avoid to call getShipmentRouteMap if settings are available
#
# Revision 1.67  2019/07/03 11:02:06  smadhukar
# Mission 30390 : Added support to remove LegInfo before transmitting file to Member
#
# Revision 1.66  2019/05/09 09:54:41  smadhukar
# Mission 30177: Added code to update RequestType from U to N if cCode='RequestType'
#
# Revision 1.65  2019/04/16 12:19:04  smadhukar
# Mission 30075 : Added support to remove MoveType and ServiceType before transmitting file to Member
#
# Revision 1.64  2019/01/17 11:28:05  bnagpure
# Mission 29637 : Pass  correct handling office name in booking notification Email.
#
# Revision 1.63  2018/10/29 08:55:54  vthakre
# Mission 29276 : Added parameter to update wwa reference
#
# Revision 1.62  2018/09/26 05:28:56  vthakre
# Mission 28602: Added code to send aperak.
#
# Revision 1.61  2018/09/06 07:04:47  bpatil
# Mission 29114 : Added code to transfer aperak based on portal memberid.
#
# Revision 1.60  2018/07/19 13:08:42  bpatil
# Mission 28895 : Corrected code for ack meta data logging.
#
# Revision 1.59  2018/07/12 09:20:19  bpatil
# Mission 28895 :  Added code to log aperak file details against aperak fileid
#
# Revision 1.58  2018/03/20 05:30:58  bpatil
# Mission 28518 : Corrected code to concatenate sender ID in APERAK file name
#
# Revision 1.57  2018/02/26 12:13:35  bpatil
# Mission 28518 : Added code to print Weight,Volume and UOM based on country for panalpina
#
# Revision 1.56  2017/12/29 09:46:08  vthakre
# Mission 28347 : Added value in <Remarks> tag as Accepted for success acknowledgment.
#
# Revision 1.55  2017/12/08 07:02:19  vthakre
# Mission 28095 : Added code to insert correct entry for origin and destination in rpt_shipmentdetail table.
#
# Revision 1.54  2017/12/01 12:29:26  vthakre
# Mission 28319 : Added code print pickup nad hazardous detail in subject line.
#
# Revision 1.53  2017/11/20 08:50:16  vthakre
# Mission 28188 : Added code to ignore space from file name.
#
# Revision 1.52  2017/11/10 08:59:44  vthakre
# Mission 28188 : Added code to enable APERAK from booking request mdoule.
#
# Revision 1.51  2017/10/31 12:36:04  nwanjari
# Mission 28112: Added code to set outgoing path for exported files.
#
# Revision 1.49  2017/08/16 11:50:53  bpatil
# Mission 28061 : Parse new parameter Carrier SCAC.
#
# Revision 1.48  2017/07/06 12:54:38  vthakre
# Mission 27897 : Taken production version 1.44 and commit changes to transfer file into downloadc.
#
# Revision 1.44  2017/04/27 09:57:50  vthakre
# Mission 27449 : Added code for booking acknowledgement.
#
# Revision 1.43  2017/04/25 11:04:10  bpatil
# Mission 27846 : Changed regex to hanlde the issue related to change in filename while transferring to member and to escape special character in filename
#
# Revision 1.42  2017/04/13 13:30:15  vthakre
# Mission 27449 : Added code to add wwa url in xml file.
#
# Revision 1.41  2017/04/07 06:39:34  vthakre
# Mission 27827 : Addedd code for member-member booking to transfer file into downloadc for shicpoc.
#
# Revision 1.40  2017/04/04 12:58:39  vthakre
# Mission 27827 : Added code to send file downloadc for shipco for member to member booking.
#
# Revision 1.39  2017/03/09 09:39:37  vthakre
# Mission 27675 : Added condition to insert proper destination member name in rpt* tables.
#
# Revision 1.38  2017/03/07 10:26:33  vthakre
# Mission 27675 : Added code for member to member booking request.
#
# Revision 1.37  2016/08/26 06:19:24  bpatil
# Mission 27149:Changed the regex to solve Email Extension issues on wwe-ei
#
# Revision 1.36  2016/08/04 08:57:31  rpatra
# Mission 27142: To send the email notificaton  based on the office code mapping to wwa member office.
# commiting changes for vpatil.
#
# Revision 1.35  2016/05/03 09:58:29  rpatra
# Mission 26695: Modified the code to pass the aditional parameters Pieces,WeightLBS,VolumeCBF, WeightKG ,VolumeCBM ,HazardousFlag.
#
# Revision 1.34  2016/03/23 11:09:12  rpatra
# Mission 26638: Changed sed command.
# Committing changes for msawant.
#
# Revision 1.33  2016/03/23 05:47:57  rpatra
# Mission 26638: Added code to export file with blank booking number if request type N with booking number.
# Committing changes for msawant.
#
# Revision 1.32  2016/01/28 08:19:46  rpatra
# Mission 26455:  Corrected the regex to validate CustomerEmail.
#
# Revision 1.31  2015/08/31 05:37:27  rpatra
# Mission 25860: Taken production version and added the changes to move code to store data in reporting table from DB.pm to this package.
# Committing changes for msawant.
#
# Revision 1.29  2015/05/25 05:43:33  psakharkar
# Mission 25294: Added code to process file having space in file name.
# committing changes for adhanwde.
#
# Revision 1.28  2015/03/13 10:08:44  rpatra
# Mission 24976: Removed code of exchange. Committing changes for msawant.
#
# Revision 1.27  2014/12/12 12:13:34  rpatra
# Mission 24472: Added the integration support email Id if CustomerEmail is blank, also corrected the naming convention as per standard.
#
# Revision 1.26  2014/10/28 09:08:51  psakharkar
# Mission 22261 : Added condition to check Succes notification mail send to additional email
#
# Revision 1.25  2014/06/25 11:35:29  rpatra
# Mission 20108: Added the code to write the ApplicationType in the file
#
# Revision 1.24  2014/03/12 04:44:01  rpatra
# Mission 16920: Modified the email header line format for New, Update and Cancel bookings in member's office mail template.
# Committing changes for msawant.
#
# Revision 1.23  2014/02/27 09:22:50  rpatra
# Mission 16920: Modified the email header and subject line format for New, Update and Cancel bookings.
# Committing changes for msawant.
#
# Revision 1.22  2013/12/26 09:13:09  rpatra
# Mission 16086: Append the string as per customer required references
#
# Revision 1.21  2013/11/27 06:07:42  dsubedar
# Bug 14087: (rpatra) Added the code to change senderID if reciever is shipco
#
# Revision 1.20  2013/11/22 05:54:00  smadhukar
# Bug 14087: Added the WWAShipmentReference tag after CustomerControlCode
# Committing changes for rpatra.
#
# Revision 1.19  2013/11/15 06:02:45  smadhukar
# Bug 15476 - Modified code to include integration support email id only when customer email is invalid.
# Committing changes for vbind.
#
# Revision 1.18  2013/11/14 11:01:44  smadhukar
# Bug 15476 - Modified code to take companyname only when its defined
# Committing changes for vbind.
#
# Revision 1.17  2013/10/16 06:06:17  dsubedar
# Bug 14087: (rpatra) Removed the code for Weight/Volume calculation while storing it in db for KN booking
#
# Revision 1.16  2013/10/08 06:18:08  smadhukar
# Bug 14159 - Modified to take 'cEmailprefix' from base hash.
# Committing changes for vbind.
#
# Revision 1.15  2013/09/25 05:01:51  psakharkar
# Bug 14159 - Modified to remove repetitive code & to log iMemberID.
# Committing changes for vbind.
#
# Revision 1.14  2013/08/22 05:56:16  psakharkar
# Bug 13712 : Added code to call store procedure & mapped details for multimember
#
# Revision 1.13  2013/06/27 11:43:54  smadhukar
# Bug 13164 : Modified the content of Booking receipt
# Committing the changes for schavan
#
# Revision 1.12  2013/06/19 11:32:34  smadhukar
# Bug 10357 - Modified code to set WWAreference as <EnvelopeID>.
# Committing changes for vbind.
#
# Revision 1.11  2013/05/06 12:02:34  akumar
# Bug 11694 : Removed the condition to get WWARefernece from tra_Bok_header
# Committing changes for rpatra
#
# Revision 1.10  2013/03/21 10:27:21  akumar
# Bug 11441 : Added condition to change extension as .xml if other than .xml
# Committing changes for psakharkar
#
# Revision 1.9  2013/02/20 04:31:38  akumar
# Bug 10825 : Modified code to take company name from sei_Member and city name from web_Branch for customer email.
# Committing changes for vbind.
#
# Revision 1.8  2013/01/15 07:08:33  smozarkar
# Bug 10368 : Added code to log destination file & path in booking request module
# Committing changes for psakharkar
#
# Revision 1.7  2012/12/20 07:32:22  smozarkar
# Bug 8942 : Added the forwarder/Communication reference in subject line of Booking request mail
#
# Revision 1.6  2012/10/19 09:23:53  smozarkar
# Bug 8942 : Made changes to add communication/forwarder reference in template hash.
# Committing changes for vbind
#
# Revision 1.5  2012/05/15 12:22:06  smozarkar
# Bug 7372 - Added code to send confirmation mail only if the xml have valid data.
# Committing changes for vbind.
#
# Revision 1.4  2012/03/22 09:28:57  dmaiti
# 6516:Modified the code to add additional email
# committing the changes by kunavane
#
# Revision 1.3  2012/03/02 11:34:16  smozarkar
# Bug 6516 : Modified the code to print proper web_Branch.Email address and print proper details in mail
# Commiting changes for rpatra
#
# Revision 1.2  2012/02/29 09:41:15  smozarkar
# 6516:Modified the code to pass proper UserID to gen_User table
# Committing changes for rpatra
#
# Revision 1.1  2012/02/27 11:41:36  smozarkar
# 6516:created module to send the Booking Confirmationmail to office and Customer
# Commiting changes for rpatra
#
# 
