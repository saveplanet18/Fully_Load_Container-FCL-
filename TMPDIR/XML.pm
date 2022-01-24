#
# $Id: XML.pm,v 1.117 2021/05/13 11:08:30 pkokate Exp $
#

=head1 NAME

wwa::EI::BookingRequest::Import::XML

=head1 DESCRIPTION

This module is use to reads XML file and stores in related hash  

=head1 AUTHOR

By rpatra@shipco.com

=head1 DATE

2012-02-27

=cut

package wwa::EI::BookingRequest::Import::XML;
	eval('use wwa::Error');
	die "Cannot use package. $@" if ($@);
	eval
	('
		use XML::Parser;
		use File::Basename;
		use XML::Parser::Grove;
		use POSIX qw/strftime/;
		use Date::Calc;
	');
	handleError(10101,"$@") if ($@);

	eval
        ('
		 use wwa::DO::User;
		 use wwa::EI::Envelope;
		 use wwa::EI::BaseImportObject;
		 use wwa::Utility::Directory;
		 use wwa::Utility::Universal;
		 use wwa::DO::Counter;
		 use wwa::DO::CustomerBooking;
		 use wwa::DO::CustomerBooking::Pickup;
		 use wwa::DO::CustomerBooking::LineItem;
		 use wwa::DO::CustomerBooking::LineItem::ShipmentRelatedData;
		 use wwa::DO::CustomerBooking::Hazardous;
		 use wwa::DO::CustomerBooking::AddressDetails;
		 use wwa::DO::Exchange;
		 use wwa::DO::GenProgram;
		 use wwa::DO::CustomerBooking;
		 use wwa::DO::Member;
		 use wwa::DO::WeiMetaData;
		 use wwa::Template;
		 use wwa::EI::BookingRequest::Export::BookingAck;'
	);
	handleError(10102,"$@") if ($@);
	
	@ISA = qw{wwa::EI::BaseImportObject};

	sub new
	{
		my $proto = shift;
		my $class = ref($proto) || $proto;
		my $self = wwa::EI::BaseImportObject->new;
		$self->{_bookingDetails} = ();
		bless($self,$class);

		return($self);
	}


=head1

This subroutine maps the BookingEnvelope and validates it

=cut

	sub validateEnvelope
	{
		my $self = shift;
		my $node = shift;
		#WWA-499 Added program setting to check & replace the sender by vgarasiya 11-22-2019
		my $oProgramSetting = wwa::DO::MemberSetting->new;
        	my $pSetting = $oProgramSetting->getProgramSettings($ENV{app}->{EDI_FILES}->{iProgramID});
		my $auth = 0;
		if ($node->name eq 'BookingEnvelope')	# sanity check
		{
			my ($userID, $password, $receiverID) = ("NO.USERNAME.DEFINED", "NO.PASSWORD.DEFINED", "NO.RECEIVER.DEFINED");
			foreach my $child (@{$node->contents})
			{
				next unless(ref($child));

				my $name = $child->name;
				my $string = join("",@{$child->contents});
				
				#WWA-499 Added code to check & replace the sender by vgarasiya 11-22-2019
				if ($name eq 'SenderID') {
					#Added code to convert small letter to into capital letter fro jira wwa-618
					$string = uc $string if($pSetting->{'ack_replace_receiver'}->{'AGYGILFCS'});
					my $cSender = $pSetting->{replace_sender}->{$string};
                                	if(defined($cSender) && $cSender ne ''){
                                        	$userID = $cSender;
                                        	$self->{'replace_sender'} = $cSender;
						$self->{'replace_receiver'} = $string;
                                        	$self->{'NewAckReceiver'} = $pSetting->{'ack_replace_receiver'}->{$string};
                                	}
                                	else{
                                        	$userID = $string if ($name eq 'SenderID');
                                	}
				}
				#end by vgarasiya
				
				$password = $string if ($name eq 'Password');
				#Added code for ReceiverID for Mission 27675 by vthakre 2017-02-23.
				$receiverID = $string if ($name eq 'ReceiverID');

				#Added code to get version for Mission 28112 by sdalai 07-09-2017.
				$self->{_Version} = $string if ($name eq 'Version');
				
				#Removed code for exchange by msawant for Mission 24976 on 11-03-2015
				$self->setOriginalEnvelopeID($string) if ($name eq 'EnvelopeID');
			}
			# This code will set UserID to data object of BaseImportObject.
			$self->setCompanyCode($userID);

			#Removed code for exchange by msawant for Mission 24976 on 11-03-2015
			my $user = wwa::DO::User->new();
			$user->setUsername($userID);
			$user->setPassword($password);
			$user->setReceiverID($receiverID);
			$auth = $user->authenticateByUsername;
			$self->userID($auth);
			$ENV{app}->setId($auth) if (defined($ENV{app}));
			$self->sender($user->getUsername);
			$self->password($user->getPassword);
			$self->ReceiverId($user->getReceiverID);
			my $cUserdetails = $user->find($user->getUsername);
			$cUserdetails->resetCounter;
			my $hUserDetails = $cUserdetails->getNextElement;
			my $cUsertype = "";
			if(defined($hUserDetails))
			{
				$cUsertype = $hUserDetails->getType;
			}
			my ($cEmailId,$hErrorText) = ("","");
			#Added code to check member to member booking for Mission 27675 by vthakre 2017-02-23.
			if(defined($cUsertype) && $cUsertype ne "")
			{
				$self->bookingType('M')if($cUsertype eq 'A');					
				$self->bookingType('C')if($cUsertype eq 'C');
			}
			else
			{
				$cEmailId = $ENV{app}->datapool->get('config.xml.global.defaultWWAEISupportEmail');
				$hErrorText = "cType is missing for $hUserDetails->getCompanyname in gen_User table";
				$self->sendErrorMissingDetail($cEmailId, $hUserDetails, $hErrorText);
				return;
			}

		}
		return($auth);
	}


	sub userID
	{
		my $self = shift;
		my $newValue = shift;
		my $retval = 0;
		$self->{_userID} = $newValue if (defined($newValue));
		$retval = $self->{_userID} if (defined($self->{_userID}));
		return($retval);
	}

	sub sender
	{
		my $self = shift;
		my $newValue = shift;
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

	# Added subroutine to set booking type for customer and member for Mission 27675 by vthakre 2017-03-01.
	sub bookingType
	{	
		my ($self, $newValue) = @_;
		my $retval = 0;
                $self->{_bookingType} = $newValue if (defined($newValue));
		$retval = $self->{_bookingType} if (defined($self->{_bookingType}));
		return($retval);
        }

	# Added subroutine to set receiver id for member for Mission 27675 by vthakre 2017-03-01
	sub ReceiverId
	{
		my ($self, $newValue) = @_;
                my $retval = 0;
                $self->{_receiverID} = $newValue if (defined($newValue));
		$retval = $self->{_receiverID} if (defined($self->{_receiverID}));
                return($retval);
	}

	sub loadData
	{
		my $self = shift;
		eval('use XML::Parser');
                handleError(10101,"$@") if ($@);
                eval('use XML::Parser::Grove');
                handleError(10101,"$@") if ($@);

		my $xmlConfig;
		import XML::parser; import XML::Parser::Grove;
		my $xml = XML::Parser->new(Style => 'grove');
		my $retval = ();

		my $dir = wwa::Utility::Directory->new();
		my @files = $dir->read($self->getPath);
		if($self->dontCleanup) 
		{
			$self->{_ok_files} = [];
		}
		else
		{
			$dir->cleanup;
		}
		my @parsedXml;
			
		# Added the code to get the Member details for bug 14087 by rpatra
		my $oMember = wwa::DO::Member->new();
		my $hMemberdetails = $oMember->getRecordForCompanyCode($ENV{app}->{user_name});
		# Added code to convert non wwa format xml file to wwa format xml file for mission 27449 by vthakre 2017-04-11.
		my $iMemberID = $hMemberdetails->getMemberID;
		my $hSettings = $self->mapMemberSettings($iMemberID);
		$self->{_memberID} = $iMemberID;
		$self->{MemberSettings} = $hSettings;	
		$self->{PortalMemberID} = $iMemberID;

		foreach my $file (@files)
		{
			if(uc(substr($file, -3)) eq ".GZ") # If it is a gzip file, then let's uncompress the
			{
				use wwa::Utility::Compress::Gzip;
				my $compress = wwa::Utility::Compress::Gzip->new();
				$compress->setSourceFilename($file);				
				$compress->uncompressFile;
				$file = substr($compress->getSourceFilename, 0, -3);
			}
			if(uc(substr($file, -4)) eq ".BZ2") # If it is a bz2 file, then let's uncompress it
			{
				use wwa::Utility::Compress::Bzip2;
				my $compress = wwa::Utility::Compress::Bzip2->new();
				$compress->setSourceFilename($file);
				$compress->uncompressFile;
				$file = substr($compress->getSourceFilename, 0, -4);
			}
			if(uc(substr($file, -4)) eq ".ZIP") # If it is a zip file, then let's uncompress it
			{
				use wwa::Utility::Compress::Zip;
				my $compress = wwa::Utility::Compress::Zip->new();
				$compress->setSourceFilename($file);
				$compress->uncompressFile;
				$file = substr($compress->getSourceFilename, 0, -4);
			}

			# Added the code to convert the special UOM to WWA standard for bug 14087 by rpatra
			if ($hMemberdetails->getUomSpecial eq "Y")
			{
				my $oUniversal = wwa::Utility::Universal->new();
				$oUniversal->convertUOM($file);
			}

			# Added code to convert non wwa format xml file to wwa format xml file for mission 27449 by vthakre 2017-04-11.
			if($hSettings->{'xslt_conversion'} && $hSettings->{'xslt_conversion'} eq 'Y')
			{
				vverbose(3," ** Applying XSLT XML Transformation.");
                                my $cPath = $ENV{app}->datapool->get('config.xml.global.xsl_file');
                                $cPath = $cPath."/"."booking_request/".$ENV{app}{user_name}.".xsl";

                                eval('use wwa::Utility::Universal');
                                handleError(10101,"$@") if ($@);

                                my $oUniversal = wwa::Utility::Universal->new();
                                my $cTempFilename = $file;
                                my $cFilename = $oUniversal->xsltToXMLConversion($file, $cPath);

                                if($hSettings->{'store_converted_file'} && $hSettings->{'store_converted_file'} eq 'Y')
                                {
                                        my $cPreProcessDir =  $ENV{app}->datapool->get('config.xml.global.defaultPreProcessDirectory');
                                        my $cDestination = $cPreProcessDir."booking_request/".$ENV{app}{user_name};
                                        system("cp $cFilename $cDestination");
                                }

                                rename ($cFilename, $cTempFilename);
                                vverbose(3," ** XSLT XML Transformation done.");
                        }
			# Added code to convert single line xml file in formatted xml by bpatil for mission 28518
			if(defined($hSettings->{special_uom}) && $hSettings->{special_uom} ne "")
                        {
                                eval('use wwa::Utility::Universal');
                                handleError(10101,"$@") if ($@);

				vverbose(3," ** Formatting XML.");

                                my $oUniversal = wwa::Utility::Universal->new();
                                my $cTempFilename = $file;
                                my $cFilename = $oUniversal->formatXML($file);

                                rename ($cFilename, $cTempFilename);
				vverbose(3," ** XML Formatting done.");
                        }

			$ENV{app}->setMessage($file);
                        eval
                        {
				$xmlConfig = $xml->parsefile($file);
			};

                        if ($@)
                        {
				# Added code to send APERAK for Mission 28602 by vthakre, 2018-09-21
				if (defined($hSettings->{acknowledge_xml}) && $hSettings->{acknowledge_xml} eq 'Y')
				{
					my $hBookingDetails;
					
					$hBookingDetails->{MemberSettings} = $self->{MemberSettings};
					$hBookingDetails->{MemberDetail} = $hMemberdetails;
					$hBookingDetails->{iMemberID} = $iMemberID;
					if (defined($hSettings->{PortalTransfer}) && $hSettings->{PortalTransfer} eq 'Y')
					{
						$oBookingobject->{PortalMemberID} = $self->{PortalMemberID};
						$oBookingobject->{PortalMemberSettings} = $self->{MemberSettings};
					}
					$self->acknowledge($hBookingDetails, $hSettings);	
					my $cAckFile = &File::Basename::basename($file);
					$cAckFile .= '_ack';
					my $oExportdata = wwa::EI::BookingRequest::Export->new;
					my $cFileName = $ENV{app}->datapool->get('config.xml.global.temp_bookdir').$ENV{app}->{user_name}."/".$cAckFile;;
					if(-f $cFileName)
					{
					        `sed -i s/ackstatus/R/g "$cFileName"`;
						$file = &File::Basename::basename($file);
					        system("sed -i -re 's#<Remarks></Remarks>#<Remarks>$file: The XML is not well formed</Remarks>#g' '$cFileName'");
					        my $hAperakStatus;
					        $hAperakStatus->{Status} = "REJECTED";
					        $oExportdata->transferAckXml($cFileName, $hAperakStatus, $hBookingDetails);
					}
				}
                                handleError(10607, "The XML is not well formed");
                        }

			$xmlConfig->{_shipco_original_filename} = $file;
			push(@parsedXml, $xmlConfig);
		}
		
		foreach my $xmlConfig (@parsedXml)
		{
			if (defined($xmlConfig) && defined($xmlConfig->root))
			{
				my $root = $xmlConfig->root;
				#WWA-932 - Retrieve schema from link by smadhukar
				my $cSchemaLocation = $root->attr('xsi:noNameSpaceSchemaLocation');
				if(defined($cSchemaLocation) && $cSchemaLocation =~ m/(\d+)\.(\d+)\.(\d+)/g)
				{
					$self->{_SchemaVersion} = "$1.$2.$3";					
				}	
				if (defined($root) && $root->name eq 'BookingRequest')
				{
					my $auth = 0;
					my @bookingDetails;
					foreach my $child (@{$root->contents})
					{
						next unless(ref($child));
						my $name = $child->name;
						if ($name eq 'BookingEnvelope')
						{
							$auth = $self->validateEnvelope($child);
							#Removed exchange code for Mission 24976 by msawant on 11-03-2015
						}
						elsif ($name eq 'BookingDetails')
						{
							my $oBookingobject = $self->mapBookingDetails($child);
						
							#Modified code to set programid, for bug 14159, by vbind 2013-09-18.
							$self->loadSettings($oBookingobject);

							# Modified code code to get portal data for mission 29114 by bpatil
							my $oMember = wwa::DO::Member->new();
                                                        my $oMemberdetails = $oMember->getRecordForCompanyCode($self->getCompanyCode);
                                                        my $iMemberID = $oMemberdetails->getMemberID;
                                                        $self->{_iMemberID} = $iMemberID;
							my $cSetting = $self->mapMemberSettings($iMemberID);

							$oBookingobject->{MemberDetail} = $hMemberdetails;
							$oBookingobject->{MemberSettings} = $cSetting;
							$oBookingobject->{PortalMemberID} = 0;
							$oBookingobject->{_SchemaVersion} = $self->{_SchemaVersion};
	
							if (defined($cSetting->{PortalTransfer}) && $cSetting->{PortalTransfer} eq 'Y')
							{
								$oBookingobject->{PortalMemberID} = $self->{PortalMemberID};
								$oBookingobject->{PortalMemberSettings} = $self->{MemberSettings}
							}
;
							if(defined($oBookingobject))
							{
								push(@bookingDetails, $oBookingobject);
							}
						}
						else
						{
							vverbose(4,"Unrecognized root node: $name");
						}
						
					}
					if (!$auth)
					{
						handleError(30108,"Sender: " . $self->sender . " is not authenticated");
					}
					else
					{
						push(@{$self->{_bookingDetails}}, \@bookingDetails) unless scalar(@bookingDetails) ==0;
						$retval = $self->{_bookingDetails};
						
					}
				}
			}
		}

		# Modified to do the validation, if error flag is 0 , then only booking number will be generated. Also, error_flag will be updated to 'N' for bug 7372, by vbind 2012-05-09.
		
		my $hBookingDetails = $self->{_bookingDetails}->[0]->[0];
		$retval->[0]->[0]->{error_flag}='Y';

		#WWA-499 Added code for set replace sender and receiver flag by vgarasiya on 11-22-2019
		$retval->[0]->[0]->{'replace_sender'} = $self->{'replace_sender'} if(defined($self->{'replace_sender'}));
                $retval->[0]->[0]->{'replace_receiver'} = $self->{'replace_receiver'} if(defined($self->{'replace_receiver'}));
                $retval->[0]->[0]->{'NewAckReceiver'} = $self->{'NewAckReceiver'} if(defined($self->{'NewAckReceiver'}));

		# Added condition to update wei_MetaData table for bug 10368
		# Added by psakharkar on Wednesday, January 02 2013 04:07:06 PM
		if(defined($ENV{app}->{EDI_FILES}->{ProcessLog}) && $ENV{app}->{EDI_FILES}->{ProcessLog} eq 'Y')
		{
			# Corrected the file logging for zipped files for bug 14087 by rpatra.
			my $cOrgFile = $ENV{app}->{EDI_FILES}->{cFileName};
			$cOrgFile =~ s/(\.gz|\.zip|.bz2)//i;
			if(defined($ENV{app}->getMessage) && $ENV{app}->getMessage =~ /\Q$cOrgFile\E$/i)
			{
				$self->logMetaData($hBookingDetails);
			}
		}

		### This code does not require eventually hence need to be removed accordingly 14087
		### DATE SHOULD BE DEPLOYMENT DATE
		if ($ENV{app}->{user_name} ne 'edi_agility_prod' && $hBookingDetails->{_RequestType} =~ m/(U|C)/ && $hBookingDetails->getBookingDate le '2013-11-26')
		{
			my $oExport = wwa::EI::BookingRequest::Export->new;
			my $oDetails = $oExport->getDestinationMemberDetails($hBookingDetails);
			my $cDatadir = $ENV{app}->getMessage;
			$retval->[0]->[0]->{error_flag}='Y';
			$oExport->transferFile($oDetails,$cDatadir);
			return($retval);
		}
		#################################
			
		my $iErrorFlag = 0;
		my $cEmailList="";
		my $cErrorString="";
		($iErrorFlag,$cErrorString,$cEmailList) = $self->validateBookingData($hBookingDetails);
		#Modified code to set EmailList, for bug 14159, by vbind 2013-09-18.
		$retval->[0]->[0]->{cEmailList} = $hBookingDetails->{cEmailList};		
		if($iErrorFlag == 0)
		{
			$retval->[0]->[0]->{error_flag}='N';
			$self->generateBookingNumber();
		}
	
		# Call acknowledge() to write booking acknowledg file to sender for Mission 27449 by vthakre 2017-04-24.
		my $cSettings = $self->mapMemberSettings($self->{_iMemberID});
		$hBookingDetails->{iMemberID} = $self->{_iMemberID};
		
		# Modified condition to send acknowledgemnt to portal for mission 29114.
		if((defined($cSettings->{acknowledge_xml}) && $cSettings->{acknowledge_xml} eq 'Y') || (defined($hBookingDetails->{PortalMemberSettings}->{acknowledge_xml}) && $hBookingDetails->{PortalMemberSettings}->{acknowledge_xml} eq 'Y'))
		{
			$self->acknowledge($hBookingDetails,$cSettings);
		}
			
		# Call ack_status() to write reject status in acknowledg file to sender for Mission 27449 by vthakre 2017-04-25.
		if($iErrorFlag != 0)
		{
			$self->ack_status($hBookingDetails, $cErrorString, $cSettings);	
		}	

		return($retval);
	}

=head2

This function will do the validation of office code , origin code, destination code & email id.
Added for bug 7372, vbind 2012-05-09.
=cut
	sub validateBookingData
	{
		my ($self,$hBookingDetails) = @_;
		use Data::Dumper; print Dumper("selff", $self);
		print Dumper("booking", $hBookingDetails);
		my $cDatadir = $ENV{app}->getMessage;
		$hBookingDetails->{Filename}=$cDatadir;

		my ($iValidateFlag , $iErrorFlag) = (0, 0);
		my ($cInvalidValue,  $cEmailIds);


		my $oMember = wwa::DO::Member->new();

		my $oMembersetting = wwa::DO::MemberSetting->new();

		#Modified code to take member id of user, for Bug 15476, vbind 2013-11-14.
		my $cSettings = $oMembersetting->getSettings($hBookingDetails->{MemberDetail}->{iMemberID},$hBookingDetails->{iProgramID});
		my $cPortalSettings = $hBookingDetails->{PortalMemberSettings};
		
		# Set the validation value (CustomerReference/CommunicationReference) as per the customers settings for bug 16086 by rpatra.
		my $cValidationValue = $hBookingDetails->{validationvalue} = 'getCustRef';
		my $cValidationReference = $hBookingDetails->{validationreference} = 'customer reference';
		my $cReference = $hBookingDetails->{reference} = $hBookingDetails->{cCustRef};
		$hBookingDetails->{communicationRefFlag} = 0;
		# Modified code to validate comminication reference bases on portal setting for mission 29114 by bpatil
		# Modified code to validate communication reference based on portal Customer for jira WWA-1526
		if ((defined($cSettings->{validate_CommunicationReference}) && $cSettings->{validate_CommunicationReference} eq 'Y') || (defined($cPortalSettings->{validate_CommunicationReference}) && $cPortalSettings->{validate_CommunicationReference} eq 'Y') || ($hBookingDetails->{MemberSettings}{validate_CommunicationReference} && $hBookingDetails->{MemberSettings}{validate_CommunicationReference} eq 'Y')) 
		{
			$cValidationValue = $hBookingDetails->{validationvalue} = 'getCustIntRef';
			$cValidationReference = $hBookingDetails->{validationreference} = 'communication reference';
			$cReference = $hBookingDetails->{reference} = $hBookingDetails->getCustIntRef;
			$hBookingDetails->{communicationRefFlag} = 1;
		}

		#Modified to also add customer email id in email list if its valid for bug 7372, by vbind 2012-06-18.
		#$cEmailIds = $self->getEmailList($cSettings , $hBookingDetails);

		# Modified code to include Additional email id into base hash, for bug 15476, by vbind 2013-11-14.
		$hBookingDetails->{cAdditionalEmail} = $cSettings->{'cAdditionalMail'};

		# Modified code to include Success_Notification_Mail into base hash, for mission 22261, by psakharkar 16/10/2014.
		$hBookingDetails->{Succes_Notification_Mail} = $cSettings->{Success_Notification_Mail} if(defined($cSettings->{Success_Notification_Mail}));

		$hBookingDetails->{cEmailList} = $cEmailIds = $self->getEmailList($cSettings , $hBookingDetails);;
		# Corrected the Company name value for invalid mail notifications for bug 15806 by rpatra
		my $hSwitchData = {
				   contact_person => $hBookingDetails->{cContactPerson},
				   customer_reference => $hBookingDetails->{cCustRef},
				   office_code=> $hBookingDetails->{cEisendingoffice},
				   contact_email=>$hBookingDetails->getEmail,
				   file_name=>basename($hBookingDetails->{Filename}),
				   company_name=>$hBookingDetails->{MemberDetail}->{cCompanyName},
				   comm_reference=>$hBookingDetails->{cCustintref},
				   validationreference=>$hBookingDetails->{validationreference},
				   reference=>$hBookingDetails->{reference},
				   invalid_value=> "",
				   cCode=>"",
				   string=>""
				 };

		my $iErrorLogFlag = 0;
		my $cErrorLogText = 'Following Invalid/Missing details found in Booking request file: ';

		# Modified to store error messages in a hash to form consolidate error mail for bug 10799, by vbind 2013-02-07.
		my $hErrorText={};
		# Added code to send error code in acknowledgement for Mission 27449 by vthakre 2017-04-25.
		my $cErrorString = "";	
		# Added code to validate customer reference, for bug 11440 , by vbind 2013-04-24.

		my $cCustRefErrorFlag = 'N';

		# Added code to send validation error for type 'F' for Mission 28611 by vthakre, 2018-03-28.
		if ($hBookingDetails->getType eq 'FBK')
		{
			$cString = "Invalid booking type 'F' is provided, WWA cannot handle FCL shipments. The correct booking type is 'L' (LCL)";
			$iErrorFlag = 1;
			$iErrorLogFlag = 1;
			$cInvalidValue = "F";
			$cErrorLogText .= "\n Invalid booking request type 'F' is provided.";
			$hErrorText->{$cString} = $cInvalidValue;
			$cErrorString .= "$cString. ";
			$self->sendErrorMail($cEmailIds, $hSwitchData, $hErrorText, $iErrorFlag);
		}
		else
		{
			#Mission 30177 passed setting to validateBookingExistence function
			($iValidateFlag , $cInvalidValue , $cString) = $self->validateBookingExistence($hBookingDetails,$cSettings);
			if($iValidateFlag == 1)
			{
				$cCustRefErrorFlag = 'Y';
				$iErrorFlag = 1;
				$iErrorLogFlag = 1;
				$cErrorLogText .= "\n $cString  $cInvalidValue ";
				$hSwitchData->{RequestType} = $hBookingDetails->{_RequestType};
				$hErrorText->{$cString} = $cInvalidValue;
				$self->sendCustRefErrorMail($cEmailIds, $hSwitchData, $hErrorText);
				$cErrorString .= "$cString. ";
			}
			#Added code to call validateUpdateEvent and sendUpdateException for Mission 24528 by msawant on 19 Dec 2014
			else
			{
				($iValidateFlag,$cString) = $self->validateUpdateEvent($hBookingDetails) if((defined($hBookingDetails)) && ($hBookingDetails->{_RequestType} eq 'U'));
				if($iValidateFlag == 1)
				{
					$iErrorFlag = 1;
					$iErrorLogFlag = 1;
					$cErrorLogText .= "\n $cString";
					$self->sendUpdateException($cEmailIds, $hSwitchData, $hBookingDetails->{cWWAreference}, $hBookingDetails->{cConfirmedBookingNumber});
					$cCustRefErrorFlag = 'Y';
					$cErrorString .= "$cString. ";
				}
			}	

			if($cCustRefErrorFlag && $cCustRefErrorFlag eq 'N')
			{
				# Added the subroutine to validate the booking number with Customer Reference for bug 11694 by rpatra 
				# Reoved the vaidation of Booking number for update and cancel request for bug 14087 by rpatra
				# Modified the validation as per the reqiured customers for bug 16086 by rpatra.
				if(!defined $hBookingDetails->$cValidationValue || $hBookingDetails->$cValidationValue eq "")
				{
					$cString = "Missing ".ucfirst($cValidationReference)." number";
					$cInvalidValue = "N/A";

					$iErrorFlag = 1;
					$iErrorLogFlag = 1;
					$cErrorLogText .= "\n $cString  $cInvalidValue";

					$hErrorText->{$cString} = $cInvalidValue;
					$cErrorString .= "$cString $cInvalidValue. ";
				}

				($iValidateFlag , $cInvalidValue , $cString ) = $self->validateOfficeCode($hBookingDetails);
				if($iValidateFlag == 1)
				{
					$iErrorFlag = 1;
					$iErrorLogFlag = 1;
					$cErrorLogText .= "\n $cString  $cInvalidValue ";
					# Added the code to send seprate email for invalid office code for mission 15935 by schavan 31-12-2013
					$self->sendOfficeCodeErrorMail($cEmailIds, $hSwitchData);
					$cErrorString .= "$cString $cInvalidValue. ";
				}

				if($hBookingDetails->getBookingType eq 'M')
				{
					($iValidateFlag , $cInvalidValue , $cString ) = $self->validateCustomerControlCode($hBookingDetails);
					if($iValidateFlag == 1)
					{
						$iErrorFlag = 1;
						$iErrorLogFlag = 1;
						$cErrorLogText .= "\n $cString  $cInvalidValue ";
						$hErrorText->{$cString} = $cInvalidValue;
						$cErrorString .= "$cString $cInvalidValue. ";
					}                      
				}				

				# Added code to log error and send mail notification for request type N with booking number for Mission 26638 by msawant
				if($hBookingDetails->getRequestType eq 'N' && $hBookingDetails->getBookingnumber ne '')
				{
					#Removed single inverted comma from Error string by sdalai for Mission 28647 on 25-04-2018.
					$cString = "Booking number submitted for Booking Request Type N (New)";
					$iErrorLogFlag = 1;
					$cInvalidValue = $hBookingDetails->getBookingnumber;
					$cErrorLogText .= "\n $cString  $cInvalidValue";
					$hErrorText->{$cString} = $cInvalidValue;
					$cErrorString .= "$cString $cInvalidValue. ";
				}
				
				#Added code to log error and send mail notification for request type U with booking numbers for Mission 29907 by adate
				if ($hBookingDetails->getRequestType eq 'U' && $hBookingDetails->getBookingnumber =~m/\d[0-9][.,*+\s\\]/ )
				{

					$cString = "Multiple Booking numbers submitted for Booking Request Type U";
					$iErrorFlag = 1;
					$iErrorLogFlag = 1;
					$cInvalidValue = $hBookingDetails->getBookingnumber;
					$cErrorLogText .= "\n $cString  $cInvalidValue";
					$hErrorText->{$cString} = $cInvalidValue;
					$cErrorString .= "$cString $cInvalidValue. ";

				}
			
				#Added code to log error and send mail notification for request type C with booking numbers for Mission 29907 by adate	
				if($hBookingDetails->getRequestType eq 'C' && $hBookingDetails->getBookingnumber =~m/\d[0-9][.,*+\s\\]/)
				{
					$iErrorFlag = 1;
					$cString = "Multiple Booking numbers submitted for Booking Request Type C";
					$iErrorLogFlag = 1;
					$cInvalidValue = $hBookingDetails->getBookingnumber;
					$cErrorLogText .= "\n $cString  $cInvalidValue";
					$hErrorText->{$cString} = $cInvalidValue;
					$cErrorString .= "$cString $cInvalidValue. ";

				}


				# Added code to validate Request Type for Mission 25576 by msawant			
				($iValidateFlag, $cInvalidValue, $cString ) = $self->validateRequestType($hBookingDetails);
				if($iValidateFlag == 1)
				{
					$iErrorFlag = 1;
					$iErrorLogFlag = 1;
					$cErrorLogText .= "\n $cString  $cInvalidValue ";

					$hErrorText->{$cString} = $cInvalidValue;
					$cErrorString .= "$cString $cInvalidValue. ";
				}

				($iValidateFlag ,  $cInvalidValue , $cString ) = $self->validateOrigin($hBookingDetails);
				if($iValidateFlag == 1)
				{
					$iErrorFlag = 1;
					$iErrorLogFlag = 1;
					$cErrorLogText .= "\n $cString  $cInvalidValue ";

					$hErrorText->{$cString} = $cInvalidValue;
					$cErrorString .= "$cString $cInvalidValue. ";
				}

				($iValidateFlag , $cInvalidValue , $cString ) = $self->validateDestination($hBookingDetails);
				if($iValidateFlag == 1)
				{
					$iErrorFlag = 1;
					$iErrorLogFlag = 1;
					$cErrorLogText .= "\n $cString  $cInvalidValue ";

					$hErrorText->{$cString} = $cInvalidValue;
					$cErrorString .= "$cString $cInvalidValue. ";
				}
				# Removed the validation for BookingOffice for Mission 27322 by bpatil.
				#
				# Added validation for PortOfLoading  for Mission 17054   by msawant
				if(defined($hBookingDetails->getPortOfLoading) && $hBookingDetails->getPortOfLoading ne "")
				{
					($iValidateFlag, $cInvalidValue, $cString) = $self->validateLocation($hBookingDetails->getPortOfLoading,"PortOfLoading");
					if($iValidateFlag == 1)
					{
						$iErrorFlag = 1;
						$iErrorLogFlag = 1;
						$cErrorLogText .= "\n $cString   $cInvalidValue ";
						$hErrorText->{$cString} = $cInvalidValue;
						$cErrorString .= "$cString $cInvalidValue. ";
					}

				}
				# Added validation for PortOfDischarge   for Mission 17054  by msawant
				if(defined($hBookingDetails->getPortOfDischarge) && $hBookingDetails->getPortOfDischarge ne "")
				{
					($iValidateFlag, $cInvalidValue, $cString) = $self->validateLocation($hBookingDetails->getPortOfDischarge,"PortOfDischarge");
					if($iValidateFlag == 1)
					{
						$iErrorFlag = 1;
						$iErrorLogFlag = 1;
						$cErrorLogText .= "\n $cString   $cInvalidValue ";
						$hErrorText->{$cString} = $cInvalidValue;
						$cErrorString .= "$cString $cInvalidValue. ";
					}

				}
				# Added validation for FinalDestinatio  for Mission 17054  by msawant
				if(defined($hBookingDetails->getFinalDestination) && $hBookingDetails->getFinalDestination ne "")
				{
					($iValidateFlag, $cInvalidValue, $cString) = $self->validateLocation($hBookingDetails->getFinalDestination,"FinalDestination");
					if($iValidateFlag == 1)
					{
						$iErrorFlag = 1;
						$iErrorLogFlag = 1;
						$cErrorLogText .= "\n $cString   $cInvalidValue ";
						$hErrorText->{$cString} = $cInvalidValue;
						$cErrorString .= "$cString $cInvalidValue. ";
					}

				}
				# Since Email ID is not mandatory in schema made emailID validation as conditional for mission 24472 by rpatra.
				if ($hBookingDetails->getEmail ne "")
				{
					($iValidateFlag, $cInvalidValue, $cString) = $self->validateEmailId($hBookingDetails->getEmail);
					if($iValidateFlag == 1)
					{
						$iErrorLogFlag = 1;
						$cErrorLogText .= "\n $cString ".$hSwitchData->{contact_email};

						$hErrorText->{$cString} = $cInvalidValue;
						$cErrorString .= "$cString ".$hSwitchData->{contact_email}.". ";
					}
				}

				# Added validation to send error mail if file does not have Cargo details for bug 10331 by rpatra
				if(!$hBookingDetails->{_lineItems})
				{
					$iErrorFlag = 1;
					$iErrorLogFlag = 1;
					$cErrorLogText .= "\n Missing Cargodetails ".$hBookingDetails->{cCompanyName};

					$hErrorText->{"Missing CargoDetails"} = "";
					$cErrorString .= "Missing Cargodetails ".$hBookingDetails->{cCompanyName}.". ";
				}

				# Added validation to send error mail if File has Multiple UOM for bug 10860 by rpatra
	
				# Modified the code to validate UOM for each CargoDetail collection and log error from each collection for bug 15050 by schavan
				my $hCargoDetails = $hBookingDetails->{_lineItems};
				my $iCargoDetailCount = 1;
				my $cUOMPara = '';	
				foreach my $hCargoDetaildata (@{$hCargoDetails->{data}})
				{
					($iValidateFlag, $cInvalidValue, $cString, $cUOM) = $self->validateUOM($iCargoDetailCount,$cUOMPara,$hCargoDetaildata);
					$cUOMPara = $cUOM;
					if($iValidateFlag == 1)
					{
						$iErrorFlag = 1;
						$iErrorLogFlag = 1;
						$cErrorLogText .= "\n $cString $cInvalidValue ";
						$hErrorText->{$cString} = $cInvalidValue;
						$cErrorString .= "$cString $cInvalidValue. ";
					}

					#Added code to fail file if cHazardousflag is 'Y' and hazardousDetails are missing, by bnagpure for mission 30133 on 28-May-2019

                                        if((defined($hCargoDetaildata->{cHazardous}) && $hCargoDetaildata->{cHazardous} eq 'Y') && (not exists ($hCargoDetaildata->{_hazardousDetails})))
                                        {
                                                $iErrorFlag = 1;
                                                $cString = "Missing Hazardous Details for Hazardous Flag Y in CargoDetail collection  $iCargoDetailCount ";
                                                $iErrorLogFlag = 1;
                                                $cErrorLogText .= "\n $cString  $cInvalidValue";
                                                $hErrorText->{$cString} = $cInvalidValue;
                                                $cErrorString .= "$cString $cInvalidValue. ";
                                        }
					$iCargoDetailCount++;
				}	
				# Added code to relax ETA validation for UPS for Mission 29798 by vthakre, 2019-02-18.
				# Added code to relax ETA and ETD validation for jira WWA-1455 by pkokate
				my $iDateFlag = 'Y';	
				$iDateFlag = 'N' if(defined($self->{relax_date_validation}) && $self->{relax_date_validation} eq 'Y');
				$iDateFlag = 'N' if(defined($hBookingDetails->{MemberSettings}->{relax_eta}) && $hBookingDetails->{MemberSettings}->{relax_eta} eq 'Y');
				#if(!defined($hBookingDetails->{MemberSettings}->{relax_eta}) || (defined($hBookingDetails->{MemberSettings}->{relax_eta}) && $hBookingDetails->{MemberSettings}->{relax_eta} ne 'Y'))
				if(defined($iDateFlag) && $iDateFlag eq 'Y')
				{
					# Added validation for date validation for <ETACFS> by rpatra for bug 11759 by rpatra
					($iValidateFlag, $cInvalidValue, $cString) = $self->validateDate($hBookingDetails->getETA,"ETA");
					if($iValidateFlag == 1 )
					{
						$iErrorFlag = 1;
						$hErrorText->{$cString} = $cInvalidValue;
						$iErrorLogFlag = 1;
						$cErrorLogText .= "\n $cString  $cInvalidValue ";
						$cErrorString .= "$cString $cInvalidValue. ";
					}
					# Modified code to validate <ETSOrigin>, instead of <ETDCFS>, for bug 12589, by vbind 2013-06-12.			

					# Added validation for date validation for <ETDCFS> by rpatra for bug 11759 by rpatra
					($iValidateFlag, $cInvalidValue, $cString) = $self->validateDate($hBookingDetails->getETD,"ETD");
					if($iValidateFlag == 1 )
					{
						$iErrorFlag = 1;
						$hErrorText->{$cString} = $cInvalidValue;
						$iErrorLogFlag = 1;
						$cErrorLogText .= "\n $cString  $cInvalidValue ";
						$cErrorString .= "$cString $cInvalidValue. ";
					}
				}
				
				#Added code to validate booking date for jira wwa-390 by pkokate on 24 oct 2019
				if(defined($hBookingDetails->getBookingDate) || $hBookingDetails->getBookingDate eq "")
                                {
                                        ($iValidateFlag, $cInvalidValue, $cString) = $self->validateDate($hBookingDetails->getBookingDate,"Booking");
                                        if($iValidateFlag == 1)
                                        {
                                                $iErrorFlag = 1;
                                                $iErrorLogFlag = 1;
                                                $cErrorLogText .= "\n $cString   $cInvalidValue ";
                                                $hErrorText->{$cString} = $cInvalidValue;
                                                $cErrorString .= "$cString $cInvalidValue. ";
                                        }

                                }

				# Validating Pickup date/Pick up Time for bug 11759
				if(defined($hBookingDetails->{cPickup}) && $hBookingDetails->{cPickup} eq "Y")
				{
					($iValidateFlag, $cInvalidValue, $cString) = $self->validateDate($hBookingDetails->{pickup}->getDate,"Pickup");
					if($iValidateFlag == 1)
					{
						$iErrorFlag = 1;
						$hErrorText->{$cString} = $cInvalidValue;
						$iErrorLogFlag = 1;
						$cErrorLogText .= "\n $cString  $cInvalidValue ";
						$cErrorString .= "$cString $cInvalidValue. ";
					}

					# Passed the settings as a parameter for mission 16081 by msawant.
					# Removed the pickup time hash and added $hBookingDetails hash for mission 16081 by msawant
					($iValidateFlag,$cInvalidValue,$cString,$cFileFail) = $self->validateTime($hBookingDetails,"Pickup",$cSettings);
					if($iValidateFlag == 1 )
					{
						# Added a code to fail file if pickup date and time is invalid/missing, by schavan for mission 25265
						$iErrorFlag = 1 if($cFileFail eq 'Y');
						$hErrorText->{$cString} = $cInvalidValue;
						$iErrorLogFlag = 1;
						$cErrorLogText .= "\n $cString  $cInvalidValue ";
						$cErrorString .= "$cString $cInvalidValue. ";
					}

				}

				# Added validation for weight and volume for bug 15050 by schavan
				my $iCount = 1;
				my @nWeightVolume;
				foreach my $hCargoDetaildata (@{$hCargoDetails->{data}})
				{
					$nWeight = ($hCargoDetaildata->getWeight eq "") ? '0' : $hCargoDetaildata->getWeight;
					$nCube = ($hCargoDetaildata->getCube eq "") ? '0' : $hCargoDetaildata->getCube;

					@nWeightVolume = ($nWeight,$nCube);
					my $iFlag = 0;
					foreach my $nWeightVolume (@nWeightVolume)
					{
						($iValidateFlag, $cInvalidValue, $cString) = $self->validateWeightVolume($iCount,$iFlag,$nWeightVolume);
						if($iValidateFlag == 1)
						{
							$iErrorFlag = 1;
							$hErrorText->{$cString} = $cInvalidValue;
							$iErrorLogFlag = 1;
							$cErrorLogText .= "\n $cString  $cInvalidValue ";
							$cErrorString .= "$cString $cInvalidValue. ";
						}
						$iFlag = 1;
					}
					$iCount++;
				}

				if(scalar(keys %{$hErrorText}) > 0)
				{
					# Added code to pass $iErrorFlag by msawant for Mission 25667 
					$self->sendErrorMail($cEmailIds, $hSwitchData, $hErrorText, $iErrorFlag);
				}
			}
		}
		# Added code to log invalid/missing details errors for bug 10368
		# Added by psakharkar on Monday, January 28 2013 04:59:06 PM
		handleError(81002,$cErrorLogText) if($iErrorLogFlag);
		return $iErrorFlag,$cErrorString;
	}
	# Aded code to send template for booking update for statuses 30,40,50 for Mission 24528 by msawant on 19 Dec 2014
	sub sendUpdateException
        {
                ($self, $cEmailIds, $hData, $cWWAreference, $cConfirmedBookingNumber) = @_;
                my %hSwitchData1 = ();

                $hSwitchData1{company_name} = $hData->{company_name} ;
                $hSwitchData1{contact_person} = $hData->{contact_person} ;
                $hSwitchData1{customer_Ref}= $hData->{customer_reference};
                $hSwitchData1{commu_Ref}= $hData->{comm_reference};
                $hSwitchData1{validationreference}=$hData->{validationreference};
                $hSwitchData1{validationreference1}=ucfirst($hData->{validationreference});
                $hSwitchData1{reference}=$hData->{reference};
                $hSwitchData1{file_name}= $hData->{file_name};
                $hSwitchData1{cWWAreference}=$cWWAreference;
		$hSwitchData1{cConfirmedBookingNumber}=$cConfirmedBookingNumber;

                my $cSubjectTemplate = wwa::Template->new("EIBookingUpdateExceptionSubject");
                $cSubjectTemplate->parseTemplate(\%hSwitchData1);
                my $cMailsubject = $cSubjectTemplate->getTemplate;

                my $cTemplate = {};
                $cTemplate->{TemplateName} = wwa::Template->new('TemplateName');
                my $cTitleTemplate = $cTemplate->{TemplateName}->getTemplate;
                my $hHeaderFooter = wwa::DO::GetHeaderFooter::getHeaderFooter($cTitleTemplate);
                $hHeaderFooter->{cHeader} =~ s/RESERVEDtopicText// if defined $hHeaderFooter->{cHeader};

                my $cYear = POSIX::strftime("%Y", localtime(time));
                $hHeaderFooter->{cFooter} =~ s/RESERVEDyear/$cYear/ if defined $hHeaderFooter->{cFooter};

                my $cBodyTemplate;

                $cBodyTemplate = wwa::Template->new("EIBookingUpdateException");

                $cBodyTemplate->parseTemplate(\%hSwitchData1);
                my $cTemplateBody = $hHeaderFooter->{cHeader}.$cBodyTemplate->getTemplate.$hHeaderFooter->{cFooter};

                vverbose(4,"Sending mail to Customer for existing Customer Reference.");

                my $oMail = wwa::Mail->new();
                $oMail->to($cEmailIds);
                $oMail->subject($cMailsubject);
                $oMail->body($cTemplateBody);
                $oMail->send();

        }

=head2 sendCustRefErrorMail

This function will send notification mail for customer reference duplicacy error.
Added for bug 11440, by vbind, 2013-04-24.

=cut

	sub sendCustRefErrorMail
	{
		($self, $cEmailIds, $hData, $hErrorText) = @_;

		my %hSwitchData1 = ();

		$hSwitchData1{company_name} = $hData->{company_name} ;
		$hSwitchData1{contact_person} = $hData->{contact_person} ;
		$hSwitchData1{customer_Ref}= $hData->{customer_reference};
		$hSwitchData1{commu_Ref}= $hData->{comm_reference};
		$hSwitchData1{validationreference}=$hData->{validationreference};
		$hSwitchData1{reference}=$hData->{reference};
		
		# Added mapping for filename, used for error notification email, for bug 12520, by vbind 2013-05-20.
		$hSwitchData1{file_name}= $hData->{file_name};

		my $template_sub = wwa::Template->new("InvalidDetailBookingSubject");
		$template_sub->parseTemplate(\%hSwitchData1);
		my $cMailsubject = $template_sub->getTemplate;

		my $template = {};
		$template->{TemplateName} = wwa::Template->new('TemplateName');
		my $templatetitle = $template->{TemplateName}->getTemplate;
		my $tmp = wwa::DO::GetHeaderFooter::getHeaderFooter($templatetitle);
		$tmp->{cHeader} =~ s/RESERVEDtopicText// if defined $tmp->{cHeader};

		my $year = POSIX::strftime("%Y", localtime(time));
		$tmp->{cFooter} =~ s/RESERVEDyear/$year/ if defined $tmp->{cFooter};

		# Modified the code to pick template as per RequestType for bug 11694 by rpatra
		my $template_body;

		if ($hData->{RequestType} eq 'N') 
		{
			$template_body = wwa::Template->new("BookingExistMailBody")
		}
		else
		{
			$template_body = wwa::Template->new("BookingUnavailableMailBody");
		}

		$template_body->parseTemplate(\%hSwitchData1);
		my $cTemplateBody = $tmp->{cHeader}.$template_body->getTemplate.$tmp->{cFooter};

		vverbose(4,"Sending mail to Customer for existing Customer Reference.");

		my $mail = wwa::Mail->new();
		$mail->to($cEmailIds);
		$mail->subject($cMailsubject);
		$mail->body($cTemplateBody);
		$mail->send();
	}

=head2 sendOfficeCodeErrorMail

This function will send notification mail regarding missing / invalid Office code.
For bug 15935 by schavan 2013-12-30.

=cut

	sub sendOfficeCodeErrorMail
	{
		my ($self, $cEmailIds, $hData) = @_;	

		my %hSwitchData1 = ();
		
		my $template_body = wwa::Template->new("OfficeMappingUnavailableMailBody");
	
		$hSwitchData1{company_name} = $hData->{company_name};
		$hSwitchData1{contact_person} = $hData->{contact_person};
		$hSwitchData1{commu_Ref}= $hData->{comm_reference};
		$hSwitchData1{office_code}=$hData->{office_code};
		$hSwitchData1{file_name}= $hData->{file_name};
		$hSwitchData1{customer_Ref}= $hData->{customer_reference};
		$hSwitchData1{email}= $hData->{contact_email};
		$hSwitchData1{validationreference}=$hData->{validationreference};
		$hSwitchData1{reference}=$hData->{reference};
		
		$template_body->parseTemplate(\%hSwitchData1);

		my $template_sub = wwa::Template->new("OfficeMappingUnavailableMailSubject");
		$template_sub->parseTemplate(\%hSwitchData1);
		my $cMailsubject = $template_sub->getTemplate;
		
		my $template = {};
		$template->{TemplateName} = wwa::Template->new('TemplateName');

		my $templatetitle = $template->{TemplateName}->getTemplate;
		my $tmp = wwa::DO::GetHeaderFooter::getHeaderFooter($templatetitle);

		$tmp->{cHeader} =~ s/RESERVEDtopicText// if defined $tmp->{cHeader};
		
		my $year = POSIX::strftime("%Y", localtime(time));
		$tmp->{cFooter} =~ s/RESERVEDyear/$year/ if defined $tmp->{cFooter};

		my $cMailBody = $tmp->{cHeader}.$template_body->getTemplate.$tmp->{cFooter};

		vverbose(4,"Sending mail to Customer for missing/invalid Office code.");
		my $mail = wwa::Mail->new();
		$mail->to($cEmailIds);
		
		$mail->subject($cMailsubject);
		$mail->body($cMailBody);
		$mail->send();
		
	}

=head2 sendErrorMail

This function will send consolidated error mail.
For bug 10799, by vbind 2013-02-07.

=cut

	sub sendErrorMail
	{
		my ($self, $cEmailIds, $hData, $hErrorText, $iErrorFlag) = @_;	
		my %hSwitchData1 = ();
		
		my $template_body = wwa::Template->new("BookingMailBody");

		$hSwitchData1{company_name} = $hData->{company_name};	
		$hSwitchData1{contact_person} = $hData->{contact_person};	
		$hSwitchData1{file_name}= $hData->{file_name};	
		$hSwitchData1{customer_Ref}= $hData->{customer_reference};	
		$hSwitchData1{commu_Ref}= $hData->{comm_reference};	
		$hSwitchData1{email}= $hData->{contact_email};	
		$hSwitchData1{validationreference}=$hData->{validationreference};
		$hSwitchData1{reference}=$hData->{reference};
	
		# Added code to make template message dynamic for Mission 25667 by msawant	
	        if ($iErrorFlag == 0)
                {
                        $hSwitchData1{text}="The file has been processed successfully. However, please note the error and ensure that the correct data is provided going forward.";
                }
                else
                {
                        $hSwitchData1{text}="Please correct the Error and re-submit the Booking request via EDI.";
                }
		
		$template_body->parseTemplate(\%hSwitchData1);

		# Modified code to change subject line of error notification email, for bug 11364, by vbind@shipco.com 2013-03-28.
		my $template_sub = wwa::Template->new("InvalidDetailBookingSubject");
		$template_sub->parseTemplate(\%hSwitchData1);
		my $cMailsubject = $template_sub->getTemplate;

		my $cTemp = "";
		%hSwitchData1 = ();
		my $iCount=0;
		
		# Modified the code to sort the error messages for bug 15050 by schavan
		foreach (sort keys %{$hErrorText})
		{
			next if($_ eq "");
			%hSwitchData1 = ();

			$hSwitchData1{SrNo} = ++$iCount;
			$hSwitchData1{Errordetails} = $_;

			if($hErrorText->{$_} eq "")
			{
				$hErrorText->{$_} = "N/A";
			}
			$hSwitchData1{Value} = $hErrorText->{$_};

			my $ImportErrorRow =  wwa::Template->new("BookingErrorRow");
			$ImportErrorRow->parseTemplate(\%hSwitchData1);
			my $ShipmentImportErrorRow = $ImportErrorRow->getTemplate();

			$cTemp = $cTemp.$ShipmentImportErrorRow;
		}

		%hSwitchData1 = ();
		$hSwitchData1{BookingErrorRow} = $cTemp ;
		my $FileErrorText = wwa::Template->new("BookingHeaderText");	
		$FileErrorText->parseTemplate(\%hSwitchData1);
		my $cErrorTextData = $FileErrorText->getTemplate;

		my $template = {};
		$template->{TemplateName} = wwa::Template->new('TemplateName');

		my $templatetitle = $template->{TemplateName}->getTemplate;
		my $tmp = wwa::DO::GetHeaderFooter::getHeaderFooter($templatetitle);

		$tmp->{cHeader} =~ s/RESERVEDtopicText// if defined $tmp->{cHeader};
		
		my $year = POSIX::strftime("%Y", localtime(time));
		$tmp->{cFooter} =~ s/RESERVEDyear/$year/ if defined $tmp->{cFooter};

		# Removed the code to create temporary file for email attachment and moved the content part in email body for bug 12343 by rpatra 
		my $cMailBody = "";
		if(defined $tmp->{cHeader} && defined $tmp->{cFooter})
		{
			$cMailBody = $tmp->{cHeader}.$template_body->getTemplate.$cErrorTextData.$tmp->{cFooter};
		}
		else
		{
			$cMailBody = $template_body->getTemplate.$cErrorTextData;
		}
		vverbose(4,"Sending mail to Customer for missing/invalid Details.");

		my $mail = wwa::Mail->new();
		$mail->to($cEmailIds);
		
		# Modified code to change subject line of error notification email, for bug 11364, by vbind@shipco.com 2013-03-28.
		$mail->subject($cMailsubject);
		$mail->body($cMailBody);
		$mail->send();

	}



=head2

Added to get the list of the email id from global.xml & database.
For bug 7372, vbind 2012-05-09

=cut
	sub getEmailList
	{
		my ($self , $cSettings , $hBookingDetails) = @_;
		my $cCustomerEmail = $hBookingDetails->getEmail;
		
		my $cEmailList;
		$cEmailList = $ENV{app}->datapool->get('config.xml.global.defaultWWAEISupportEmail');
		# Added condition to check failure notification mail send to additional email for mission 22261 by psakharkar on 16/10/2014
		if(!defined($cSettings->{Failure_Notification_Mail}) || $cSettings->{Failure_Notification_Mail} ne 'N')
		{
			if(defined($cSettings->{'cAdditionalMail'}) && $cSettings->{'cAdditionalMail'} ne "")
			{
				my $other_emailid = $cSettings->{'cAdditionalMail'};
				$cEmailList = $cEmailList.",".$other_emailid;
			}
		}

		# Modified to also add the customer email id in email list if its valid for Bug 7372, by vbind 2012-06-18.
		#Changed regex for $cCustomerEmail for Mission 24528 by msawant on 23 Dec 2014
 		# Changed $CustomerEmail by $cCustomerEmail and regex for $cCustomerEmail for mission 24528 by msawant 
 		# Changed the regex to solve Email Extension issues on wwe-ei for mission 27149 by bpatil,28/07/2016
		if(defined($cCustomerEmail) && ($cCustomerEmail ne "") && ($cCustomerEmail =~ /^\w[\w\.\-]*\w\@\w[\w\.\-]*\w(\.\w{2,})$/))
		{
			$cEmailList = $cCustomerEmail.",".$cEmailList;
		}
		return($cEmailList);
	}
	
	#Added code to find whether event occured for Statuses 30,40,50 for Mission 24528 by msawant on 22 Dec 2014
	sub validateUpdateEvent
	{
		my ($self,$hBookingDetails) = @_;
                my ($iValidateFlag,$cString) = (0,'');
                my $cErrorValue = $hBookingDetails->{validationreference};
                my $cValidationValue = $hBookingDetails->{validationvalue};
		my $iFlag = $hBookingDetails->{communicationRefFlag};

		my $oDbh = wwa::DBI->new();
	
		my $oCustomerBooking = wwa::DO::CustomerBooking->new();
		$oCustomerBooking->setUserID($self->userID);
		# Added code fro member to member booking for Mission 27675 by vthakre 2017-02-28. 
		$oCustomerBooking->setBookingType($self->bookingType);	

		# Changed the subroutine name from getWWAReference to getBookingdetails to reuse existing subroutine for mission 24870 by rpatra.
		my $hWWReference = $oCustomerBooking->getBookingdetails($hBookingDetails->$cValidationValue,$iFlag);
		my $cWWAReference = $hWWReference->{iBookingNumID};

		#Added status code 31 in IN cluase of query for Mission 24528 by msawant	
		my $cQuery = "select distinct b.cbookingNumber as BookingNumber from tra_Status s, tra_Bok_header b where s.iShipmentID = b.iShipmentID and cANSICode IN ('30','31','40','50') and b.cWWAreference = '".$cWWAReference."'";

                my $hSthtmp = $oDbh->prepare($cQuery) || handleError(10202,"$cQuery (" .$oDbh->errstr. ")");
                $hSthtmp->execute() || handleError(10203, "$cQuery (" . $hSthtmp->errstr . ")");

                my $cRow = $hSthtmp->fetchrow_hashref;

                my $cConfirmedBookingNumber = (defined($cRow->{BookingNumber}) && $cRow->{BookingNumber}) ? $cRow->{BookingNumber} : "";
	
		$hBookingDetails->{cWWAreference} = $cWWAReference ;		
		$hBookingDetails->{cConfirmedBookingNumber} = $cConfirmedBookingNumber ;
			
		$iValidateFlag = (defined($cConfirmedBookingNumber) && $cConfirmedBookingNumber ne '') ? 1 : 0;
		
		#Added status code 31 in the Error Description for Mission 24528 by msawant	
		$cString = "Booking cannot be updated since status code '30' or '31' or '40' or '50' already completed.";

                return($iValidateFlag,$cString);
        }

=head2 validateBookingExistence

This function will validate existence of customer reference in database.
Added for bug 11440, by vbind 2013-04-24.

=cut

# Modified the queries for the validating Custref for Request Type U and C for bug 11694 by rpatra

	sub validateBookingExistence
	{
		my ($self , $hBookingDetails, $cSettings) = @_;
		my $iValidateFlag = 0;
		my ($cOfficeCode, $cString, $cText);


		my $cInvalidValue="";
		# Validate the Booking based on the customer required references for bug 16086 by rpatra.
		my $CustomerBooking = wwa::DO::CustomerBooking->new();
		my $cValidationValue = $hBookingDetails->{validationvalue};
		my $cErrorValue = $hBookingDetails->{validationreference};

		if ($hBookingDetails->$cValidationValue && $hBookingDetails->$cValidationValue ne "")
		{
			# Passed iUserID to to check existence for mission 24870 by rpatra.
			$CustomerBooking->setUserID($self->userID);
			$CustomerBooking->setBookingType($self->bookingType);
			my $cRefDetails = $CustomerBooking->checkCustomerRef($hBookingDetails->$cValidationValue,$hBookingDetails->{communicationRefFlag}); 

			if(defined($cRefDetails->{Count}))
			{
				if ($cRefDetails->{Count} >= 1 && $hBookingDetails->{_RequestType} eq 'N')
				{
					$iValidateFlag = 1;
					$cInvalidValue = $hBookingDetails->$cValidationValue;
					#Removed errorValue from ErrorText by sdalai for Mission 28647 on 25-04-2018.
					$cString = "Booking request already exists for $cErrorValue number";
				}
				elsif ($cRefDetails->{Count} == 0 && $hBookingDetails->{_RequestType} =~ /(U|C)/)
				{
					# Added code to update RequestType from U to N if cCode='RequestType' for mission 30177 by smadhukar on 08-May-2019
					if(defined($cSettings->{RequestType}) && $cSettings->{RequestType} eq 'Y' && $hBookingDetails->{_RequestType} eq 'U')
					{
						$hBookingDetails->{_RequestType} = 'N';
						$hBookingDetails->{MemberSettings}{_changeType} = 'Y';
					}
					else
					{
						$iValidateFlag = 1;
						$cInvalidValue = $hBookingDetails->$cValidationValue;
						#Removed errorValue from ErrorText by sdalai for Mission 28647 on 25-04-2018.
						$cString = "Booking request does not exists for $cErrorValue number";
					}
				}
			}
		}
		return ($iValidateFlag, $cInvalidValue , $cString);
	}


=head2

This subroutine will validate from the database if the office code is valid or not. 
Added for bug 7372, vbind 2012-05-09.

=cut

	sub validateOfficeCode
	{
		my ($self , $hBookingDetails) = @_;
		my $iValidateFlag = 0;
		# Removed unwanted code, for bug 14159, by vbind 2013-09-18.
		my $cString;

		# Removed the explicit pass of iStatus for bug 13197 by rpatra 2013-07-04
		# Modified code to modify error message & to remove unused variables, for bug 10799 , by vbind 2013-02-07.
		my $cInvalidValue="";

		if (!$hBookingDetails->{cEisendingoffice} || $hBookingDetails->{cEisendingoffice} eq "")
		{
			$iValidateFlag = 1;
			# Modified the error string for mission 15935 by schavan 2014-1-3
			$cString = "Missing Office Code";
		}
		elsif($hBookingDetails->{cEisendingoffice} ne "")
		{
			eval('use wwa::DO::OfficeMap');
			handleError(10102, "$@") if ($@);
			
			# Modified the code to validate office details
			# should be validate on  branch id, Member id and external code for mission 15935 by schavan 2014-1-3 
			my $oOfficeMap = wwa::DO::OfficeMap->new();
			# initilize new veriable and pass to sei_Office_map query for hira wwa-474 by bnagpure.
			my $BkgReq = 'Y';
			my $hDetails = $oOfficeMap->getOfficedetails($hBookingDetails->{cEisendingoffice} , $BkgReq );

			if(!$hDetails->{'cExternalcode'} || $hDetails->{'cExternalcode'} eq "")
			{
				$iValidateFlag = 1;
				$cInvalidValue = $hBookingDetails->{cEisendingoffice};
				# Modified the error string for mission 15935 by schavan 2014-1-3
				$cString = "Invalid Office Code";
			}
			# Modified the code to store iofficememberid and cofficemail for the mission 27142 by vpatil on 27-7-2016
			else
			{
                                $hBookingDetails->{Officedetails} = $hDetails;
			}
		}
		return ($iValidateFlag, $cInvalidValue , $cString);
	}

=head
This subroutine will validate Request Type 
added code for Mission 25576 by msawant
=cut
        sub validateRequestType
        {
                my ($self, $hBookingDetails) = @_;
                my $iValidateFlag = 0;
                my $cString = "";
                my $cInvalidValue = "";

                if(!$hBookingDetails->{_RequestType} || $hBookingDetails->{_RequestType} eq "")
                {
                        $iValidateFlag = 1;
                        $cString = "Missing Request Type";
                }
                else
                {
                        if($hBookingDetails->{_RequestType} !~ m/^(N|U|C)$/ )
                        {
                                $iValidateFlag = 1;
                                $cInvalidValue = $hBookingDetails->{_RequestType};
                                $cString = "Invalid Request Type";
                        }
                }

                return ($iValidateFlag, $cInvalidValue, $cString);
        }

=head2

This subroutine will validate from the database if the origin code is valid or not.
Added for big 7372, vbind 2012-05-09.

=cut

	sub validateOrigin
	{
		my ($self , $hBookingDetails ) = @_;
		my $iValidateFlag = 0;
		my ($cOrigin, $cString , $cText);

		# Modified code to modify error message & to remove unused variables, for bug 10799 , by vbind 2013-02-07.
		my $cInvalidValue="";
		
		# Added code to make error message more precise for Mission 25576 by msawant
		if (!$hBookingDetails->{cOrigin} || $hBookingDetails->{cOrigin} eq "")
		{
			$iValidateFlag = 1;
			$cString = "Missing Origin Code";
		}
		else
		{
			# Modified function name to getCityName, for bug 14159, by vbind 2013-09-18.
			$cOrigin = $hBookingDetails->getCityName($hBookingDetails->{cOrigin});

			if(!$cOrigin || $cOrigin eq "")
			{
				$iValidateFlag = 1;
				$cInvalidValue =  $hBookingDetails->{cOrigin};
				$cString = "Invalid Origin Code";
			}
		}
		return ($iValidateFlag,  $cInvalidValue , $cString , $cText);
	}

=head2

This subroutine will validate from the database if the destination code is valid or not.
Added for big 7372, vbind 2012-05-09.

=cut

	sub validateDestination
	{
		my ($self , $hBookingDetails ) = @_;
		my $iValidateFlag = 0;
		my ($cDestination,  $cString , $cText);

		# Modified code to modify error message & to remove unused variables, for bug 10799 , by vbind 2013-02-07.
		my $cInvalidValue="";
		# Added code to make error message more precise for Mission 25576 by msawant
		if (!$hBookingDetails->{cDestination} || $hBookingDetails->{cDestination} eq "")
		{
			$iValidateFlag = 1;
			$cString = "Missing Destination Code";
		}
		else
		{
			# Modified function name to getCityName, for bug 14159, by vbind 2013-09-18.
			$cDestination = $hBookingDetails->getCityName($hBookingDetails->{cDestination});
			if(!$cDestination || $cDestination eq "")
			{
				$iValidateFlag = 1;
				$cInvalidValue = $hBookingDetails->{cDestination};
				$cString = "Invalid Destination Code";
			}
		}
		return ($iValidateFlag, $cInvalidValue ,$cString , $cText);
	}
=head2

This subroutine will validate from the database if the UN location  code is valid or not.
Added for Mission 17054, msawant 2014-02-14.

=cut


	sub validateLocation 
	{
        	my ($self, $cLocation, $cTag) = @_;
		my ($iValidateFlag, $cInvalidValue, $cString) = (0,'','');
		
        	my $oGenLocation = wwa::DO::GenLocation->new();
        	my $hLocationdetails = $oGenLocation->getLocationDetails('cCode',$cLocation);
	
		if(!$hLocationdetails || $hLocationdetails eq "")
        	{
	 		$iValidateFlag = 1;
			$cInvalidValue = $cLocation;
         		$cString .= "$cTag is Invalid"; 
        	}

	  	return ($iValidateFlag, $cInvalidValue ,$cString);
	}
=head2

This subroutine will validate from the database if the email id is valid or not.
Added for big 7372, vbind 2012-05-09.

=cut

	sub validateEmailId
	{
		my ($self, $cCustomerEmail) = @_;
		my ($iValidateFlag, $cInvalidValue, $cString) = (0, "", "");

		# Corrected the regex to validate emailid for mission 24274 by rpatra.
		# Changed the regex to solve Email Extension issues on wwe-ei for mission 27149 by bpatil,28/07/2016
		if ($cCustomerEmail !~ /^\w[\w\.\-]*\w\@\w[\w\.\-]*\w(\.\w{2,})$/)
		{
			$iValidateFlag = 1;
			$cInvalidValue = $cCustomerEmail;
			$cString = "Invalid Email ID";
		}
		return ($iValidateFlag, $cInvalidValue, $cString);
	}

=head2

This subroutine will validate the UOM details.
If Multiple UOM provided in same file then send validation error for bug 10860 by rpatra.

=cut

	sub validateUOM
	{
		my ($self,$iCountCD,$cUOM,$hCargoDetaildata) = @_;
		my $iValidateFlag = 0;

		# Modified the condition to identify missing UOM in any CargoDetails for bug 15050 by schavan
		if ($hCargoDetaildata->getUOM eq "")
		{
			$iValidateFlag = 1;
			$cInvalidValue = $hCargoDetaildata->getUOM;
			$cString = "CargoDetail collection $iCountCD : Missing UOM";
		}
		elsif(defined(@{$hCargoDetaildata->{UOM}}) && scalar(@{$hCargoDetaildata->{UOM}}) > 1)
		{
			$iValidateFlag = 1;
			$cInvalidValue = join(",",@{$hCargoDetaildata->{UOM}});
			$cString = "CargoDetail collection $iCountCD : Two different UOM provided in single Cargodetail collection";
		}
		elsif(defined(@{$hCargoDetaildata->{UOM}}) && scalar(@{$hCargoDetaildata->{UOM}}) == 1)
		{
			# Modified the condition to store valid UOM in $cUOM variable once for bug 15050 by schavan
			$cUOM = $hCargoDetaildata->getUOM if ($hCargoDetaildata->getUOM =~ /E|M/ && $cUOM eq '');
	
			# Added the condition to catch the error if specified UOM is other than E or M for bug 15050 by schavan
			if ($hCargoDetaildata->getUOM !~ /E|M/)
			{
				$iValidateFlag = 1;
				$cInvalidValue = $hCargoDetaildata->getUOM;
				$cString = "CargoDetail collection $iCountCD : Invalid UOM";
			}	
			elsif ($iCountCD > 1 && ($hCargoDetaildata->getUOM ne "" && $hCargoDetaildata->getUOM ne $cUOM))
			{
				$iValidateFlag = 1;
				$cInvalidValue = $cUOM.",".$hCargoDetaildata->{cUOM};
				$cString = "Two different UOM provided in multiple Cargodetail collection";
			}

		}
	
		return ($iValidateFlag, $cInvalidValue, $cString, $cUOM);
	}

=head1 

Added the subroutine to validate ETD/ETA date for bug 11759 by rpatra

=cut

	sub validateDate
	{
		my ($self, $cDate, $cTag) = @_;

		my $cErrorMsg = "";
		my $iErrorFlag = 0;

		if(!defined($cDate) || $cDate eq "")
		{
			$cErrorMsg = "Missing $cTag Date";
			$iErrorFlag = 1;
		}
		elsif(defined($cDate) && $cDate ne "")
		{
			if ($cDate !~ /^(\d{4})\-(\d{2})\-(\d{2})$/is)
			{
				$cErrorMsg = "Invalid $cTag Date Format"; 
				$iErrorFlag = 1; 
			}
			else
			{
				my($cYear,$cMonth,$cDay) = $cDate =~ /^(\d{4})\-(\d{2})\-(\d{2})$/is;
				my $iValid = Date::Calc::check_date($cYear,$cMonth,$cDay);
				unless($iValid)
				{		
					$cErrorMsg = "Invalid $cTag Date"; 
					$iErrorFlag = 1; 
				}
			}
		}
		return ($iErrorFlag,$cDate,$cErrorMsg);
	}

=head1 

Added the code to subroutine the <Date> in <PickupDetails> for bug 11759 by rpatra

=cut

=head1
Added the code to  validate  pickuptime  for mission 16081 by msawant

=cut

	sub validateTime
	{
                my ($self,$hBookingDetails, $cTag ,$cSettings) = @_;
		my $cTime = $hBookingDetails->{pickup}->getTime;
                my($tHours,$tMins,$tSecs) = (00,00,00);
                my $cFileFail = 'Y';

                my $cErrorMsg = "";
                my $iErrorFlag = 0;
		(defined($cSettings->{specialtimeformat}) && $cSettings->{specialtimeformat} eq 'Y')?($cFormat= '^(\d{2}):?(\d{2})$') :($cFormat='^(\d{2}):(\d{2})$');

                if(!defined($cTime) || $cTime eq "")
                {
                        $cErrorMsg = "Missing $cTag Time";
                        $iErrorFlag = 1;
                        $cFileFail=  'Y';
                }
                elsif(defined($cTime) && $cTime ne "")
		{
			if ($cTime !~ m/$cFormat/i)
			{
                                $cErrorMsg = "Invalid $cTag Time Format";
                                $iErrorFlag = 1;
                                $cFileFail = 'N';
				$hBookingDetails->{pickup}->setTime("00:00:00");
                        }
                        else
                        {
                                my($tHours,$tMins,$tSecs) = $cTime =~ /$cFormat/i;
                                defined($tSecs) ? $tSecs =~ s/://g : ($tSecs = "00");

                                my $iValid = Date::Calc::check_time($tHours,$tMins,$tSecs);
                                unless($iValid)
                                {
                                        $cErrorMsg = "Invalid $cTag Time";
                                        $iErrorFlag = 1;
                                        $cFileFail ='Y';
                                }
				else
				{
					$hBookingDetails->{pickup}->setTime("$tHours:$tMins:$tSecs");
				}
                        }
		}
                return ($iErrorFlag,$cTime,$cErrorMsg,$cFileFail);
	}


=head1

This subroutine will validate the Weight and Volume for bug 15050

=cut

	sub validateWeightVolume
	{
		my ($self, $iCount, $iFlag, $nWeightVolume) = @_;

		my $iValidateFlag = 0;
		my $cInvalidValue = "";
		my $cStr = ($iFlag == 0) ? 'weight' : 'volume';
		#WWA-453 ; Changed the if condition to send proper error.
		if ($nWeightVolume == 0.0 || $nWeightVolume == 0)
		{
			$iValidateFlag = 1;
			$cInvalidValue = ($nWeightVolume eq '0') ? "0" : $nWeightVolume;
			$cString = ($cInvalidValue eq "") ? "CargoDetail collection $iCount : Missing $cStr" : "CargoDetail collection $iCount : Invalid $cStr";
		}
	
	return ($iValidateFlag, $cInvalidValue, $cString);
	}



=head2

This subroutine will generate the booking number.
Added for big 7372, vbind 2012-05-09.

=cut

	sub generateBookingNumber
	{
		my $self = shift;

		foreach my $bookingDetail (@{$self->{_bookingDetails}})
		{
			foreach my $customerBooking (@{$bookingDetail})
			{

				# Added the changes to get BookingnumID from database using Customerrefence for bug 11694 by rpatra
				if ($customerBooking->{_RequestType} =~ /(U|C)/)
				{
					# Get details of the Booking based on the customer required references for bug 16086 by rpatra.
					my $cValidationvalue = $customerBooking->{validationvalue};
					if ($customerBooking->$cValidationvalue ne '')
					{
						# Passed the UserID mission 24870 by rpatra.
						$customerBooking->setUserID($self->userID);
						$customerBooking->setBookingType($self->bookingType);
						my $cBookingNumID = $customerBooking->getBookingdetails($customerBooking->$cValidationvalue,$customerBooking->{communicationRefFlag});
						$customerBooking->setBookingNumID($cBookingNumID->{iBookingNumID});
						vverbose(3," Found BookingNumID from ". $customerBooking->{validationreference} ." for request type U or C");
					}
				}

				if ($customerBooking->{_RequestType} eq 'N')
				{
					# Removed the subroutine createBookingNumber and called getNewCounter to get new wwa reference for mission 25323 by rpatra.
					my $oCounter = wwa::DO::Counter->new();
					my ($iWWAReference) = $oCounter->getNewCounter("wwareference_counter","EBKG");

					$customerBooking->sender($self->sender);
					$customerBooking->password($self->password);
					$customerBooking->setBookingType($self->bookingType);
					vverbose(3, "Using userID of " . $self->userID . " for the booking record.");
					$customerBooking->setBookingNumID($iWWAReference);

					$customerBooking->add;
					}
				else
				{
					$customerBooking->sender($self->sender);

					if ($customerBooking->{_RequestType} eq 'U')
					{
						# its an update, so lets compare the two and
						# store the differences

						eval('use wwa::Utility::Diff');
						handleError(10102, "$@") if ($@);

						my $originalBooking = $customerBooking->loadAll($customerBooking->getBookingNumID);


						$customerBooking->add;

						my $newBooking = $customerBooking->loadAll($customerBooking->getBookingNumID);

						$self->checkUpdateBookingChanges($customerBooking,$originalBooking,$newBooking);
					}
					elsif ($customerBooking->{_RequestType} eq 'C')
					{
						# its a cancellation
						$customerBooking->delete;
					}
					elsif ($customerBooking->{_RequestType} ne 'N')
					{
						eval('use Data::Dumper');
						handleError(10101, "$@") if ($@);
						my $d = Data::Dumper->new([\$customerBooking]);
						die "This booking object should have failed validation (RequestType is not N|U|C): " . "\n" . $d->Dump;
					}
				}
			}
		}
	}



=head1

This subroutine maps the BookingDetails

=cut

	sub mapBookingDetails
	{
		my ($self, $node) = @_;

		my $booking = wwa::DO::CustomerBooking->new();
		$booking->{lineitem} = undef if (defined($booking->{lineitem}));	# for UTI compat
		$booking->{hazardous} = undef if (defined($booking->{hazardous}));
		$booking->setUserID($ENV{app}->getId) if (defined($ENV{app}));
		my $highValueCargo	= "N";
		$booking->{cBookingType} = $booking->setBookingType($self->bookingType);
		$booking->{cReceiverID} = $self->ReceiverId;	
		
		$self->setSequence($self->getSequence + 1);
		if ($node->name eq 'BookingDetails')	# sanity check
		{
			$booking->{_EnvelopeID} = $self->getOriginalEnvelopeID;
			#Adding envelope version in BookingDetails by sdalai for Mission 28112 on 07-sep-2017.
			$booking->{_EnvelopeVersion} = $self->{_Version}; 

			foreach my $child (@{$node->contents})
			{
				next unless(ref($child));
				my $name = $child->name;

				my $string = join("", @{$child->contents});
				if ($name eq 'BookingType') { $booking->setType($string . "BK"); }
				elsif ($name eq 'BookingDate') { $booking->setBookingDate($string); } 
				elsif ($name eq 'LastSentDateTime') { $booking->setLastsentdate($string); }
				# Set the bookingnumber in different hash for bug 16051 by rpatra.
				elsif ($name eq 'BookingNumber') { $booking->setBookingnumber($string);}
				elsif ($name eq 'CustomerControlCode')
                                {
					if ($booking->{cBookingType} eq 'C')
					{
						my $oOfficeMap = wwa::DO::OfficeMap->new();
					
						my $oDetails = $oOfficeMap->getExternalCodeRecord($string);                                  
						$booking->{iOfficeMapID} = $oOfficeMap->setOfficeMapID;
						$booking->setCMS($string);
						$booking->setEISendingOffice($string);

						# Modified code to set iMemberID into base hash, for bug 14159, by vbind 2013-09-18.
						$booking->{iMemberID} = $oOfficeMap->setMemberID;
						$booking->{iReceiverMemberID} = $oOfficeMap->setMemberID;
						$booking->{_cExternalcode} = $oOfficeMap->getExternalCode;
						$booking->{_cCountry} = $oOfficeMap->getCountry;
						$booking->{_cCity} = $oOfficeMap->getCity;
						$booking->{_CmsCode} = $oOfficeMap->getCmsCode;
					}
					if($booking->{cBookingType} eq 'M')
					{
						my $oOfficeMap = wwa::DO::OfficeMap->new();
						
                                                my $oDetails = $oOfficeMap->getExternalCodeRecord($booking->{cReceiverID});
                                                $booking->{iOfficeMapID} = $oOfficeMap->setOfficeMapID;
                                                $booking->setCMS($booking->{cReceiverID});
                                                $booking->setEISendingOffice($booking->{cReceiverID});
                                                $booking->{iMemberID} = $oOfficeMap->setMemberID;
						$booking->{iReceiverMemberID} = $oOfficeMap->setMemberID;
                                                $booking->{_cExternalcode} = $oOfficeMap->getExternalCode;
                                                $booking->{_cCountry} = $oOfficeMap->getCountry;
						$booking->{_cCity} = $oOfficeMap->getCity;
						$booking->{_CmsCode} = $oOfficeMap->getCmsCode;

						$booking->setCustomercontrolcode($string);
					}
                                }
                                # Added the mapping for BookingOffice for bug 11463 by rpatra
                                elsif ($name eq 'BookingOffice') { $booking->setBookingOffice($string); }
				# Added the mapping for FPI for bug 18770 by msawant
				elsif ($name eq 'FPI') { $booking->setPC($string); }
				# Mission 30390 : Added support for LegInfo by smadhukar on 28-June-2019
				elsif ($name eq 'LegInfo') { $booking->setLegInfo($string);}
				elsif ($name eq 'CommunicationReference') { $booking->setCustIntRef($string); }
				elsif ($name eq 'CustomerReference') { $booking->setCustRef($string); }
				# Added mapping for <ShipperReference>, <ConsigneeReference> by psakharkar for mission 25014
                                elsif ($name eq 'ShipperReference') { $booking->setShipperRef($string); }
                                elsif ($name eq 'ConsigneeReference') { $booking->setConsigneeRef($string); }
				# Added mapping for contact details for shipper, consignee & notify for mission 25210 by psakharkar on Thursday, April 09 2015 
				elsif ($name eq 'Address')
				{
					$booking->getAddressDetails->addElement($self->mapAddressDetails($child));
				}
				elsif ($name eq 'CustomerContact') { $booking->setContactPerson($string); }
				elsif ($name eq 'CustomerPhone') { $booking->setPhone($string);}
				# Added code to remove leading and trailling space for Mission 25609 by msawant
				elsif ($name eq 'CustomerEmail') { $string =~ s/\&/\@/sg; $string =~ s/^\s+|\s+$//g; $booking->setEmail($string); }	
				elsif ($name eq 'BUCustomerEmail') { $string =~ s/\&/\@/sg; $booking->setBUEmail($string); }	
				elsif ($name eq 'OnHold') {$booking->setIsSentOnHold("Y");$booking->setOnhold($string); }
				elsif ($name eq 'HVC') { $booking->setIsSentHVC("Y");$booking->setHvc($string); }
				elsif ($name eq 'CFSOrigin') { $booking->setOrigin($string); $self->{CFSOrigin} = $string; }
				elsif ($name eq 'CFSDestination') { $booking->setDestination($string); }
				elsif ($name eq 'FinalDestination') { $booking->setFinalDestination($string); }
				elsif ($name eq 'FinalDestinationPlace') { $booking->setFinalDestinationPlace($string); }
				elsif ($name eq 'FinalDestinationType') { $booking->setFinalDestinationType($string); }
				# Added code to have support for ServiceType and MoveType for mission 30075 by smadhukar on 12-Apr-2019
				elsif ($name eq 'MoveType') { $booking->setMoveType($string); }
                                elsif ($name eq 'ServiceType') { $booking->setServiceType($string); }
				elsif ($name eq 'FinalDestinationCountry') { $booking->setFinalDestinationCountry($string); }
				elsif ($name eq 'BondedCargo') {  $booking->setIsSentBondedCargo("Y");$booking->setBondedCargo(($string ne ""?substr($string,0,1):"")); }
				elsif ($name eq 'LastSentDate') { $booking->setLastsentdate($string); }
				elsif ($name eq 'PortOfLoading') { $booking->setPortOfLoading($string); }
				elsif ($name eq 'PortOfDischarge') { $booking->setPortOfDischarge($string); }
				#End of addition.

				elsif ($name eq 'AmsFlag') { $booking->setAMS($string); }
				elsif ($name eq 'AesFlag') { $booking->setAES($string); }
				elsif ($name eq 'ColoadCommodity') { $booking->setCC($string); }
				elsif ($name eq 'Remarks') { $booking->setSpecialCondition((($booking->getSpecialCondition ne '') ? $booking->getSpecialCondition."\n" : "").$string); }
				# Added support for OnwardGateway tag for mission 25790 by rpatra.
				elsif ($name eq 'OnwardGateway') { $booking->setOnwardGateway($string); }
				elsif ($name eq 'OncarriageFlag') { $booking->setOncarriageFlag($string); }
				elsif ($name eq 'OncarriagePlace') { $booking->setOncarriagePlace($string); }
				elsif ($name eq 'PickupFlag') { $booking->setPickup($string); 
					my $oPDetail = wwa::DO::Member->new();
                                        my $cPDetail = $oPDetail->getRecordForCompanyCode($self->getCompanyCode);
                                        $booking->setCompanyName($cPDetail->{cCompanyName});
				}
				elsif ($name eq 'RequestType') { $booking->{_RequestType} = $string; }

				$self->addNameAndAddressLine($string, $booking) if ($name eq 'NameAndAddressLine');

				# getter/setters ?
				if ($name eq 'PickupDetails')
				{
					$booking->{pickup} = $self->mapPickupDetails($child);
					#$booking->setCompanyName($booking->{pickup}->getCompanyname);
					#WWA-920 : set sender company name as a company name by smadhukar on 13-May-2020
					#my $oCompDetail = wwa::DO::Member->new();
					#my $cCompDetail = $oCompDetail->getRecordForCompanyCode($self->getCompanyCode);
					#$booking->setCompanyName($cCompDetail->{cCompanyName});
				}
				elsif ($name eq 'SailingDetails')
				{
					$booking = $self->mapSailingDetails($child, $booking);
				}
				elsif ($name eq 'CargoDetails')
				{
					my $lineItem = $self->mapCargoDetails($child);
					if (defined($lineItem))
					{
						$booking->lineItems->addElement($lineItem); #if (defined($lineItem));
						# its ugly, but it doesn't wrap.....
						( $booking->getHazardous eq 'Y' || 
						  $lineItem->getHazardousFlag eq 'Y' ) ? $booking->setHazardous(
							'Y') : $booking->setHazardous('N');

						# In any of the lineitem the dimention flags set then
						if ($lineItem->getDimentionFlagset eq "Y") 
						{
							$booking->setIsSentDimentionflag("Y");
						}

						# i.e in any of the lineitem if there is <HighValueFlag> there
						if ($lineItem->getISsentHighValue eq "Y")
						{
							$booking->setHighValueFlagset("Y");
							
							if ($lineItem->getHighValue eq "Y")
							{
								$highValueCargo	= "Y";
							}
						}
										
					}

					#($booking->{lineitem}, $booking->{hazardous}) = $self->mapCargoDetails($child);
				}
				# Added support for newly mapped tags for mission 22826 by rpatra.
				elsif ($name eq 'TransportTemperatureRangeFrom') { $booking->setTransportTemperatureRangeFrom($string); }
				elsif ($name eq 'TransportTemperatureRangeTo') { $booking->setTransportTemperatureRangeTo($string); }
				elsif ($name eq 'CustomsRelatedData') {	$booking->setCustomsRelatedData((defined($booking->getCustomsRelatedData) && $booking->getCustomsRelatedData ne "") ? $booking->getCustomsRelatedData." ".$string : $string); }
				elsif ($name eq 'CTCCode') { $booking->setCTCCode($string); }
				elsif ($name eq 'CTCDescription') { $booking->setCTCDescription($string); }
				elsif ($name eq 'CustomsContact') { $booking->setCustomsContact($string); }
				elsif ($name eq 'CustomsPhone') { $booking->setCustomsPhone($string); }
			}

			#Removed code to set RequestType N in case of Request Type tag is missing foe Mission 25576 by msawant
			
			#For a booking, if any of the lineitem dimention flag set, then take that value..
			if ($booking->getHighValueFlagset eq "Y") 
			{
				$booking->setIsSentHVC("Y");
				$booking->setHvc($highValueCargo);
			}	

		}
		return($booking);

	}

=head

This subrouting used to mapped contact details from XML
for mission 25210 by psakharkar on Friday, April 10 2015

=cut

sub mapAddressDetails
{
	my ($self, $node) = @_;

	my $oAddressDetails = wwa::DO::CustomerBooking::AddressDetails->new();
	if($node->name eq 'Address') # sanity check
	{
		my %hType = ('SH' => 'Shipper', 'CN' => 'Consignee', 'N1' => 'Notify1', 'N2' => 'Notify2', 'FW' => 'Forwarder');
		my @aAddress = ();
		foreach my $child (@{$node->contents})
		{
			next unless(ref($child));
			vverbose(7, "Mapping node: <" . $child->name . ">");
			if($child->name eq 'AddressID')
			{
				my $cAddrID = join("",@{$child->contents});
				my $cType = (defined($hType{$cAddrID})) ? $hType{$cAddrID} : '';

				$oAddressDetails->setType($cType);
			}
			elsif($child->name eq 'AddressDetails')
			{
				#Added code to map Addressdetails and add flag for relax ETA/ETD validation for DBSchenker for jira WWA-1455 by pkokate
				$self->mapAddressDetailsTag($child,$oAddressDetails);
			}
			elsif($child->name eq 'AddressLine1')
			{
				my $cData = join("",@{$child->contents});
				push(@aAddress,$cData) if($cData ne '');
				# Added field cName in boo_Booking_contactdetail for Mission 29101 by vthakre, 2018-08-27.
				$oAddressDetails->setName(join("",@{$child->contents}));
			}
			elsif($child->name eq 'AddressLine2')
			{
				my $cData = join("",@{$child->contents});
				push(@aAddress,$cData) if($cData ne '');
			}
			elsif($child->name eq 'AddressLine3')
			{
				my $cData = join("",@{$child->contents});
				push(@aAddress,$cData) if($cData ne '');
			}
			elsif($child->name eq 'AddressLine4')
			{
				my $cData = join("",@{$child->contents});
				push(@aAddress,$cData) if($cData ne '');
			}
			elsif($child->name eq 'AddressLine5')
			{
				my $cData = join("",@{$child->contents});
				push(@aAddress,$cData) if($cData ne '');
			}
			elsif($child->name eq 'AddressLine6')
			{
				my $cData = join("",@{$child->contents});
				push(@aAddress,$cData) if($cData ne '');
			}
			elsif($child->name eq 'Phone')
			{
				$oAddressDetails->setPhone(join("",@{$child->contents}));
			}
			elsif($child->name eq 'Fax')
			{
				$oAddressDetails->setFax(join("",@{$child->contents}));
			}
			elsif($child->name eq 'Email')
			{
				$oAddressDetails->setEmail(join("",@{$child->contents}));
			}
			else
			{
				vverbose(4, "Unrecognized CustomerBooking::AddressDetails node: ". $child->name);
			}
			if(scalar(@aAddress))
			{
				my $cAddr = join(",",@aAddress);
				$oAddressDetails->setCombinedAddress($cAddr);
			}
		}
	}
	return($oAddressDetails);
}

sub mapAddressDetailsTag
{
	my ($self, $node,$oAddressDetails) = @_;
	my $oMemberSetting = wwa::DO::MemberSetting->new();
        my $hSettings = {};
        $hSettings = $oMemberSetting->getDetails($self->{_memberID},$ENV{app}->{EDI_FILES}->{iProgramID},'relax_routing_date','Y') if (defined($self->{_memberID}) && ($self->{_memberID} ne '' || $self->{_memberID} ne '0'));
	if($node->name eq 'AddressDetails')
	{
		my @aAddress = ();
		foreach my $child (@{$node->contents})
		{
			next unless(ref($child));
			if($child->name eq 'AddressLine1')
			{
				my $cData = join("",@{$child->contents});
				push(@aAddress,$cData) if($cData ne '');
				$oAddressDetails->setName(join("",@{$child->contents}));
				if(defined($hSettings->{cExtendedcode}) && $hSettings->{cExtendedcode} ne '')
				{
					if(defined($cData) && $cData =~ m/^$hSettings->{cExtendedcode}\b/i)
					{
						$self->{relax_date_validation} = 'Y';
					}
				}
			}
			elsif($child->name eq 'AddressLine2')
			{
				my $cData = join("",@{$child->contents});
				push(@aAddress,$cData) if($cData ne '');
			}
			elsif($child->name eq 'AddressLine3')
			{
				my $cData = join("",@{$child->contents});
				push(@aAddress,$cData) if($cData ne '');
			}
			elsif($child->name eq 'AddressLine4')
			{
				my $cData = join("",@{$child->contents});
				push(@aAddress,$cData) if($cData ne '');
			}
			elsif($child->name eq 'AddressLine5')
			{
				my $cData = join("",@{$child->contents});
				push(@aAddress,$cData) if($cData ne '');
			}
			elsif($child->name eq 'AddressLine6')
			{
				my $cData = join("",@{$child->contents});
				push(@aAddress,$cData) if($cData ne '');
			}
			elsif($child->name eq 'Phone')
			{
				$oAddressDetails->setPhone(join("",@{$child->contents}));
			}
			elsif($child->name eq 'Fax')
			{
				$oAddressDetails->setFax(join("",@{$child->contents}));
			}
			elsif($child->name eq 'Email')
			{
				$oAddressDetails->setEmail(join("",@{$child->contents}));
			}
			else
			{
				vverbose(4, "Unrecognized CustomerBooking::AddressDetails node: ". $child->name);
			}
			if(scalar(@aAddress))
			{
				my $cAddr = join(",",@aAddress);
				$oAddressDetails->setCombinedAddress($cAddr);
			}
		}
	}	
	return($oAddressDetails);
}

=head1

This subroutine maps the PickupDetails

=cut

	sub mapPickupDetails
	{
		my $self = shift;
		my $node = shift;
		
		my $cConcatenatedBLRemarks = "";

		my $pickup = wwa::DO::CustomerBooking::Pickup->new();
		$pickup->{_flagForValidation} = 1;
		if ($node->name eq 'PickupDetails')	# sanity check
		{
			foreach my $child (@{$node->contents})
			{
				next unless(ref($child));
				my $name = $child->name;
				my $string = join("",@{$child->contents});
                                $pickup->setPickupReference($string) if ($name eq 'PickupReference'); 
				$pickup->setCompanyname($string) if ($name eq 'CompanyName');
				$pickup->setContactperson($string) if ($name eq 'Contact');
				$pickup->setAddress($string) if ($name eq 'Address');
				$pickup->setCity($string) if ($name eq 'City');
				$pickup->setPostalcode($string) if ($name eq 'PostalCode');
				$pickup->setState($string) if ($name eq 'StateProvince');
				$pickup->setCountry($string) if ($name eq 'Country');
				$pickup->setPhone($string) if ($name eq 'Phone');
				$pickup->setEmail($string) if ($name eq 'Email');
				$pickup->setDate($string) if ($name eq 'Date');
				$pickup->setTime($string) if ($name eq 'Time');
				# Added a code to read multiple remarks, by schavan 2015-08-05 for mission 25669
				if ($name eq 'Remarks')
				{
					$cConcatenatedBLRemarks .=  $string . " ";
				}  
				$self->addNameAndAddressLine($string, $pickup) if ($name eq 'CombinedCompanyNameandAddress'); 
			}
			$cConcatenatedBLRemarks =~ s/\s+$//;
			$pickup->setRemarks($cConcatenatedBLRemarks);
		}
		return($pickup);
	}

=head1

This subroutine maps the mapSailingDetails

=cut


	sub mapSailingDetails
	{
		my $self = shift;
		my ($node, $booking) = @_;
		
		if ($node->name eq 'SailingDetails')	# sanity check
		{
			foreach my $child (@{$node->contents})
			{
				next unless(ref($child));
				my $name = $child->name;
				my $string = join("", @{$child->contents});

				$booking->setVesselVoyageID($string) if ($name eq 'VesselVoyageID');
				$booking->setVessel($string) if ($name eq 'VesselName');
				$booking->setIMO($string) if ($name eq 'IMONumber');
				$booking->setVoyage($string) if ($name eq 'Voyage');
				$booking->setCutoff($string) if ($name eq 'ETDCFS');
				$booking->setETA($string) if ($name eq 'ETACFS');
				$booking->setETD($string) if ($name eq 'ETSOrigin');
				$booking->setETSPoL($string) if ($name eq 'ETSPoL');

			}
		}
		return($booking);
	}

=head1

This subroutine maps the CargoDetails

=cut

	sub mapCargoDetails
	{
		my $self = shift;
		my $node = shift;

		my $lineItem = wwa::DO::CustomerBooking::LineItem->new();
		
		if ($node->name eq 'CargoDetails')	# sanity check
		{
			$lineItem->setDisplayOrder($self->getNextDisplayOrder);

			foreach my $child (@{$node->contents})
			{
				next unless(ref($child));
				my $name = $child->name;
				my $string = join("", @{$child->contents});

				$lineItem->setPieces($string) if ($name eq 'Pieces');
				$lineItem->setPackaging($string) if ($name eq 'Packaging');

                                # Modified the code to set Multiple Commodity for bug 7370 by rpatra 2012-09-18

				$lineItem->setCommodity((defined($lineItem->getCommodity) && $lineItem->getCommodity ne "") ? $lineItem->getCommodity." ".$string : $string) if ($name eq 'Commodity');
				$lineItem->setHSCode($string) if ($name eq 'HSCode');
				
				# Added code to get Weight,Volume and UOM based on country for panalpina for mission 28518 by bpatil,26-02-2018
				my $cCountry = substr($self->{CFSOrigin},0,2);
				if(defined($self->{MemberSettings}{special_uom}) && $self->{MemberSettings}{special_uom} ne "")
				{
					if ($self->{MemberSettings}{special_uom} =~ m/$cCountry/i)
					{
						if ($name eq 'Weight' && $child->attr('UOM') eq 'LBS')
						{
							$lineItem->setWeight($string);
						}
						if ($name eq 'Volume' && $child->attr('UOM') eq 'CFT')
						{
							$lineItem->setCube($string);		
							push(@{$lineItem->{UOM}},'E');
	                                        	$lineItem->setUOM(join("\n",@{$lineItem->{UOM}}));
						}
					}
					else
					{
						if ($name eq 'Weight' && $child->attr('UOM') eq 'KGS')
                                        	{
                                                	$lineItem->setWeight($string);
                                        	}
                                        	if ($name eq 'Volume' && $child->attr('UOM') eq 'CBM')
                                        	{
                                                	$lineItem->setCube($string);
                                                	push(@{$lineItem->{UOM}},'M');
                                                	$lineItem->setUOM(join("\n",@{$lineItem->{UOM}}));
                                        	}
					}
				}
				else
				{
					$lineItem->setCube($string) if ($name eq 'Volume');
                                        $lineItem->setWeight($string) if ($name eq 'Weight');

					if ($name eq 'UOM')
                                	{
                                        	push(@{$lineItem->{UOM}},$string);
                                        	$lineItem->setUOM(join("\n",@{$lineItem->{UOM}}));
                                	}						
				}
				# Added the code to map new fields for mission 12714 by schavan 2014-06-11

				if ($name eq 'ShipmentRelatedData')
				{
					$lineItem->shipmentRelatedData->addElement($self->mapShipmentRelatedData($child));

				}

				$lineItem->setLength($string) if ($name eq 'Length');
				$lineItem->setWidth($string) if ($name eq 'Width');
				$lineItem->setHeight($string) if ($name eq 'Height');

				# Added the code for pushing multiple UOM segments into an array for Bug 10860 by rpatra
				
				#If they send flags with "YES and NO then we need 1st string "Y" and "N"
				$lineItem->setOverdimension(($string ne ""?substr($string,0,1):"")) if ($name eq 'OverDimensionFlag');
				$lineItem->setOverheight(($string ne ""?substr($string,0,1):"")) if ($name eq 'OverHeightFlag');
				$lineItem->setOverlength(($string ne ""?substr($string,0,1):"")) if ($name eq 'OverLengthFlag');
				$lineItem->setOverweight(($string ne ""?substr($string,0,1):"")) if ($name eq 'OverWeightFlag');
				$lineItem->setOverwidth(($string ne ""?substr($string,0,1):"")) if ($name eq 'OverWidthFlag');
				$lineItem->setHighValue(($string ne ""?substr($string,0,1):"")) if ($name eq 'HighValueFlag');
				
				#Want to know if they have sent dimentionFlags.
				if(($name eq 'OverDimensionFlag') || ($name eq 'OverHeightFlag') 
					||($name eq 'OverLengthFlag') ||($name eq 'OverWeightFlag') || ($name eq 'OverWeightFlag'))
				{
					$lineItem->setDimentionFlagset("Y");
				}
				
				#Want to know if they have HighValueFlag
				if($name eq 'HighValueFlag')
				{
					$lineItem->setISsentHighValue("Y");
				}

                                # Modified the code to set Multiple ShippingMarks for bug 7370 by rpatra 2012-09-18

				$lineItem->setShippingmarks((defined($lineItem->getShippingmarks) && $lineItem->getShippingmarks ne "") ? $lineItem->getShippingmarks." ".$string : $string) if ($name eq 'ShippingMarks');
				vverbose(3, "Setting line item hazardous to " . $string) if ($name eq 'HazardousFlag');
				$lineItem->setHazardousFlag($string) if ($name eq 'HazardousFlag');
				if ($name eq 'HazardousDetails')
				{
					$lineItem->setHazardousDetails->addElement($self->mapHazardousDetails($child));
				}
				 
			}
		}
		
		if(defined($lineItem->{cHazardous}) && $lineItem->{cHazardous} eq 'N')
		{
			$hazardous = wwa::DO::CustomerBooking::Hazardous->new(); # unless(defined($hazardous));
			$lineItem->setHazardousFlag("N");
		}
		else
		{
			$lineItem->setHazardousFlag("Y");
		}
		return($lineItem);
	}

=head1

This subroutine maps the HazardousDetails

=cut

	sub mapHazardousDetails
	{
		my $self = shift;
		my $node = shift;
		#initialize Datadir with current file path for jira 685 by pkokate on 12-feb-2020	
		my $cDatadir = $ENV{app}->getMessage;
		my $hazardous = wwa::DO::CustomerBooking::Hazardous->new();
		if ($node->name eq 'HazardousDetails')
		{ 
			foreach my $child (@{$node->contents})
			{ 
				next unless(ref($child));
				my $name = $child->name;
				my $string = join("", @{$child->contents});
# change FlashPoint to Flashpoint as per booking schema for bug 9876
# changed by psakarkar on Tuesday, November 27 2012 11:44:34 AM
				$hazardous->setHazclass($string) if ($name eq 'HazardousClass');
				$hazardous->setFlashpoint($string) if ($name eq 'Flashpoint');
				$hazardous->setShippingname($string) if ($name eq 'ShippingName');
				#Added code to remove characters from UnNumber for jira wwa-685 by bnagpure on 10-feb-2020.
				if($name eq 'UNNumber')
				{
					my $Existstring =  $string;
					$string =~ s/[^0-9]*//g;
					# added code to capture only first 4 digit for jira wwa-685 by pkokate on 11 feb 2020	
					$string = substr($string,0,4);
					$hazardous->setUnnumber($string);
					system("sed -i -re 's#<UNNumber>$Existstring</UNNumber>#<UNNumber>$string</UNNumber>#ig' $cDatadir 2>/dev/null");
				}
				$hazardous->setPackinggroup($string) if ($name eq 'PackingGroup');
				$hazardous->setFlashPointFlag($string) if ($name eq 'FlashpointFlag');
				# Added support for Hazardous details for Mission 29801 by smadhukar on 21-Feb-2019
				$hazardous->setHazPieces($string) if ($name eq 'Pieces');
				$hazardous->setPackaging($string) if ($name eq 'Packaging');
				$hazardous->setHazWeight($string) if ($name eq 'Weight');
			}
		} 
		return($hazardous);
	}
=head1

This subroutine maps the mapShipmentRelatedData

=cut

	sub mapShipmentRelatedData
	{
		my ($self, $hNode) = @_;

		my $oShipmentRelatedData = wwa::DO::CustomerBooking::LineItem::ShipmentRelatedData->new();

		if ($hNode->name eq 'ShipmentRelatedData')
		{
			foreach my $hChild (@{$hNode->contents})
			{
				next unless(ref($hChild));
				my $hTagName = $hChild->name;
				my $hData = join("", @{$hChild->contents});

				$oShipmentRelatedData->setQuantity($hData) if ($hTagName eq 'Quantity');
				$oShipmentRelatedData->setLength($hData) if ($hTagName eq 'Length');
				$oShipmentRelatedData->setWidth($hData) if ($hTagName eq 'Width');
				$oShipmentRelatedData->setHeight($hData) if ($hTagName eq 'Height');
				$oShipmentRelatedData->setUOM($hData) if ($hTagName eq 'UOM');
			}
		}

		return($oShipmentRelatedData);
	}
	sub setSequence
	{
		my ($self, $newValue) = @_;
		$self->{_sequence} = $newValue if (defined($newValue));
		return($self->getSequence);
	}

	sub getSequence
	{
		my $self = shift;
		return (defined($self->{_sequence})) ? $self->{_sequence} : 0;
	}

	sub setSourceFilename
	{
		my $self = shift;
		my $newValue = shift;
		$self->{_sourceFilename} = $newValue if (defined($newValue));
		return($self->getSourceFilename);
	}

	sub getSourceFilename
	{
		my $self = shift;
		my $retval = "";
		$retval = $self->{_sourceFilename} if (defined($self->{_sourceFilename}));
		return($retval);
	}

	# every time a new <BookingDetails> is called, it does self->setSequence(self->getSequence + 1)
	# so for each new sequence it restarts the counter
	sub getNextDisplayOrder
	{
		my $self = shift;
		my ($currentSequence, $lastSequence) = ($self->getSequence, $self->{_lastSequence});
		$lastSequence = $currentSequence unless(defined($lastSequence));

		my $retval = ($currentSequence ne $lastSequence) ? 1 : ((defined($self->{_currentDisplayOrder})) ? $self->{_currentDisplayOrder} : 0) + 1;
		vverbose(6, "Current Display Order Sequence: $currentSequence, Last Display Order Sequence: $lastSequence, Display Order: $retval");

		$self->{_currentDisplayOrder} = $retval;
		$self->{_lastSequence} = $currentSequence;
		return($retval);
	}

	sub setNameAndAddress
	{
		my $self = shift;
		my $newValue = shift;
		$self->{_nameAndAddress} = $newValue if (defined($newValue));
		return($self->getNameAndAddress);
	}

	sub getNameAndAddress
	{
		my $self = shift;
		my $occErr = "Minimum of 1 occurance for NameAndAddressLine not met";
		if (defined($self->{_nameAndAddress}))
		{
			handleError(10607,"$occErr") if (length($self->{_nameAndAddress}) == 0);
			return($self->{_nameAndAddress});
		}
		else
		{
			handleError(10607, "$occErr");
		}
	}

	sub addNameAndAddressLine
	{
		my ($self, $newValue, $obj) = @_;
		# validate
		if (defined($newValue) && defined($obj))
		{
			vverbose(3,"trying to add name and address line: ($newValue) to $obj: length: " . length($newValue));
			$obj->{_nameAndAddressLine} = [] unless(defined($obj->{_nameAndAddressLine}));
			my $count = @{$obj->{_nameAndAddressLine}};
			$count++;
			handleError(10607, "Too many occurances of NameAndAddressLine -- limit of 5 " . 
					   "(has $count) -- $obj --\n" . join("\n", @{$obj->{_nameAndAddressLine}})) if ($count > 5);
			handleError(10607, "String '$newValue' is greater than 175 characters " . 
					   "-- length: " . length($newValue)) if (length($newValue) > 175);	
			push(@{$obj->{_nameAndAddressLine}},$newValue);
			$obj->setNameAndAddress(join("\n",@{$obj->{_nameAndAddressLine}}));
		}
	}

=head1

This subroutine checks if any updates is done

=cut


	sub checkUpdateBookingChanges
	{
		my $self = shift;
		my $customerBooking = shift;
		my $originalBooking = shift;
		my $newBooking = shift;
		my $iLineitemCount = 1;
		
		my $changes = $self->getLineItemString("ChangesFound")."<br /><br />\n";

		if($self->checkDefined($originalBooking->{tBookingDate}) ne $self->checkDefined($newBooking->{tBookingDate}))
		{
			$changes .= "Booking date = ".$newBooking->{tBookingDate}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{tLastsentdate}) ne $self->checkDefined($newBooking->{tLastsentdate}))
		{
			$changes .= "Last sent date = ".$newBooking->{tLastsentdate}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cType}) ne $self->checkDefined($newBooking->{cType}))
		{
			$changes .= "Booking type = ".$newBooking->{cType}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cOrigin}) ne $self->checkDefined($newBooking->{cOrigin}))
		{
			$changes .= "Origin = ".$newBooking->{cOrigin}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cPortofloding}) ne $self->checkDefined($newBooking->{cPortofloding}))
		{
			$changes .= "Port of loading = ".$newBooking->{cPortofloding}."<br />\n";
		}
		# Added the code to print updated port of discharge on template for bug 13493 by schavan 2013-12-27
		if($self->checkDefined($originalBooking->{cDischargecode}) ne $self->checkDefined($newBooking->{cDischargecode}))
		{
			$changes .= "Port of discharge = ".$newBooking->{cDischargecode}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cDestination}) ne $self->checkDefined($newBooking->{cDestination}))
		{
			$changes .= "Destination = ".$newBooking->{cDestination}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cFinaldestinationcode}) ne $self->checkDefined($newBooking->{cFinaldestinationcode}))
		{
			$changes .= "Final Destination = ".$newBooking->{cFinaldestinationcode}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cFinaldestination}) ne $self->checkDefined($newBooking->{cFinaldestination}))
		{
			$changes .= "Final Destination Place = ".$newBooking->{cFinaldestination}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cFinaldestinationtype}) ne $self->checkDefined($newBooking->{cFinaldestinationtype}))
		{
			$changes .= "Final Destination Type = ".$newBooking->{cFinaldestinationtype}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cFinaldestinationcountry}) ne $self->checkDefined($newBooking->{cFinaldestinationcountry}))
		{
			$changes .= "Final Destination Country = ".$newBooking->{cFinaldestinationcountry}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cBondedcargo}) ne $self->checkDefined($newBooking->{cBondedcargo}))
		{
			$changes .= "Bonded Cargo = ".$newBooking->{cBondedcargo}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cRoutingVia}) ne $self->checkDefined($newBooking->{cRoutingVia}))
		{
			$changes .= "Routing via = ".$newBooking->{cRoutingVia}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cOncarriagePlace}) ne $self->checkDefined($newBooking->{cOncarriagePlace}))
		{
			$changes .= "Oncarriage location = ".$newBooking->{cOncarriagePlace}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cOncarriageFlag}) ne $self->checkDefined($newBooking->{cOncarriageFlag}))
		{
			$changes .= "Oncarriage switch = ".$newBooking->{cOncarriageFlag}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cVoyage}) ne $self->checkDefined($newBooking->{cVoyage}))
		{
			$changes .= "Voyage code = ".$newBooking->{cVoyage}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cVessel}) ne $self->checkDefined($newBooking->{cVessel}))
		{
			$changes .= "Vessel name = ".$newBooking->{cVessel}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{iImo}) ne $self->checkDefined($newBooking->{iImo}))
		{
			$changes .= "IMO = ".$newBooking->{iImo}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{tETD}) ne $self->checkDefined($newBooking->{tETD}))
		{
			$changes .= "Departure date = ".$newBooking->{tETD}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{tETA}) ne $self->checkDefined($newBooking->{tETA}))
		{
			$changes .= "ETA = ".$newBooking->{tETA}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{tEtdPOL}) ne $self->checkDefined($newBooking->{tEtdPOL}))
		{
			$changes .= " ETS at Port of Loading = ".$newBooking->{tEtdPOL}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{tCutoff}) ne $self->checkDefined($newBooking->{tCutoff}))
		{
			$changes .= "Cutoff date = ".$newBooking->{tCutoff}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{iVesselvoyageidentifier}) ne $self->checkDefined($newBooking->{iVesselvoyageidentifier}))
		{
			$changes .= "Vessel voyage ID = ".$newBooking->{iVesselvoyageidentifier}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cCustintref}) ne $self->checkDefined($newBooking->{cCustintref}))
		{
			$changes .= "Forwarder internal reference = ".$newBooking->{cCustintref}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cCustRef}) ne $self->checkDefined($newBooking->{cCustRef}))
		{
			$changes .= "Forwarder reference = ".$newBooking->{cCustRef}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cShipperRating}) ne $self->checkDefined($newBooking->{cShipperRating}))
		{
			$changes .= "Shipper Rating = ".$newBooking->{cShipperRating}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cCC}) ne $self->checkDefined($newBooking->{cCC}))
		{
			$changes .= "Coload Commodity = ".$newBooking->{cCC}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cOnwardGateway}) ne $self->checkDefined($newBooking->{cOnwardGateway}))
		{
			$changes .= "Onward Gateway = ".$newBooking->{cOnwardGateway}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cAES}) ne $self->checkDefined($newBooking->{cAES}))
		{
			$changes .= "AES = ".$newBooking->{cAES}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cAMS}) ne $self->checkDefined($newBooking->{cAMS}))
		{
			$changes .= "AMS = ".$newBooking->{cAMS}."<br /\n>";
		}
		if($self->checkDefined($originalBooking->{cSpecialCondition}) ne $self->checkDefined($newBooking->{cSpecialCondition}))
		{
			$changes .= "Special conditions = ".$newBooking->{cSpecialCondition}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cCompanyName}) ne $self->checkDefined($newBooking->{cCompanyName}))
		{
			$changes .= "Company name = ".$newBooking->{cCompanyName}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cContactPerson}) ne $self->checkDefined($newBooking->{cContactPerson}))
		{
			$changes .= "Contact person = ".$newBooking->{cContactPerson}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cAddress}) ne $self->checkDefined($newBooking->{cAddress}))
		{
			$changes .= "Contact address = ".$newBooking->{cAddress}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cCity}) ne $self->checkDefined($newBooking->{cCity}))
		{
			$changes .= "Contact city = ".$newBooking->{cCity}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cCountry}) ne $self->checkDefined($newBooking->{cCountry}))
		{
			$changes .= "Contact country = ".$newBooking->{cCountry}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cPostalCode}) ne $self->checkDefined($newBooking->{cPostalCode}))
		{
			$changes .= "Contact postal code = ".$newBooking->{cPostalCode}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cPhone}) ne $self->checkDefined($newBooking->{cPhone}))
		{
			$changes .= "Contact phone number = ".$newBooking->{cPhone}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cFax}) ne $self->checkDefined($newBooking->{cFax}))
		{
			$changes .= "Contact fax number = ".$newBooking->{cFax}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cEmail}) ne $self->checkDefined($newBooking->{cEmail}))
		{
			$changes .= "Contact e-mail = ".$newBooking->{cEmail}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cBucustomeremail}) ne $self->checkDefined($newBooking->{cBucustomeremail}))
		{
			$changes .= "BU Customer Email = ".$newBooking->{cBucustomeremail}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cOnhold}) ne $self->checkDefined($newBooking->{cOnhold}))
		{
			$changes .= "On Hold = ".$newBooking->{cOnhold}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cHvc}) ne $self->checkDefined($newBooking->{cHvc}))
		{
			$changes .= "High Value Cargo = ".$newBooking->{cHvc}."<br />\n";
		}
		# Added following code to print updated changes for newly mapped tags for mission 22826 by rpatra.
		if($self->checkDefined($originalBooking->{nTransportTemperatureRangeFrom}) ne $self->checkDefined($newBooking->{nTransportTemperatureRangeFrom}))
		{
			$changes .= "Transport Temperature Range From = ".$newBooking->{nTransportTemperatureRangeFrom}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{nTransportTemperatureRangeTo}) ne $self->checkDefined($newBooking->{nTransportTemperatureRangeTo}))
		{
			$changes .= "Transport Temperature Range To = ".$newBooking->{nTransportTemperatureRangeTo}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cCustomsRelatedData}) ne $self->checkDefined($newBooking->{cCustomsRelatedData}))
		{
			$changes .= "Customs Related Data = ".$newBooking->{cCustomsRelatedData}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cCTCCode}) ne $self->checkDefined($newBooking->{cCTCCode}))
		{
			$changes .= "CTC Code = ".$newBooking->{cCTCCode}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cCTCDescription}) ne $self->checkDefined($newBooking->{cCTCDescription}))
		{
			$changes .= "CTC Description = ".$newBooking->{cCTCDescription}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cCustomsContact}) ne $self->checkDefined($newBooking->{cCustomsContact}))
		{
			$changes .= "Customs Contact = ".$newBooking->{cCustomsContact}."<br />\n";
		}
		if($self->checkDefined($originalBooking->{cCustomsPhone}) ne $self->checkDefined($newBooking->{cCustomsPhone}))
		{
			$changes .= "Customs Phone = ".$newBooking->{cCustomsPhone}."<br />\n";
		}
		
		# For pickup flag to check whether the new booking has added or removed the pickup details.

		if($self->checkDefined($originalBooking->{cPickup}) ne $self->checkDefined($newBooking->{cPickup})) 
		{
			$changes .= "Pickup Flag = ".$newBooking->{cPickup}." - ";

			if ($newBooking->{cPickup} eq "Y" || $newBooking->{cPickup} eq "y") 
			{
				$changes .= $self->getLineItemString("PickupAdded")."<br />\n";
			}
			else
			{
				$changes .= $self->getLineItemString("PickupRemoved")."<br />\n";
			}
		}
		# Check the lineitems
		
		$originalBooking->{lineitem}->resetCounter;
		my $noOflineitemsOrg = $originalBooking->{lineitem}->getNumElements;

		$newBooking->{lineitem}->resetCounter;
		my $noOflineitemsNew = $newBooking->{lineitem}->getNumElements;

		#Checks whether no. of line items are same or different.
		if($noOflineitemsOrg != $noOflineitemsNew)
		{
			$changes .= "<br />".$self->getLineItemString("ChangedLineItemAmount")."<br />\n";
			$changes .= $self->getLineItemString("LineItemNumOriginal","noOflineitemsOrg",$noOflineitemsOrg)."<br />\n";
			$changes .= $self->getLineItemString("LineItemNumNew","noOflineitemsNew",$noOflineitemsNew)."<br />\n";
			my $cLineitemFinalString = "";
			my $cHazFinalString = "";
			my $iShowCheck = 0;
			my $iShowHazCheck = 0;
			my $noOflineitemsLargest = ($noOflineitemsOrg>$noOflineitemsNew)?$noOflineitemsOrg:$noOflineitemsNew;
			my $noOflineitemSmallest = ($noOflineitemsOrg<$noOflineitemsNew)?$noOflineitemsOrg:$noOflineitemsNew;

			while (($originalBooking->{lineitem}->hasMoreElements) || ($newBooking->{lineitem}->hasMoreElements))
			{
				my $originalLineItem = $originalBooking->{lineitem}->getNextElement;
				my $newLineItem = $newBooking->{lineitem}->getNextElement;

				my $originalHazardous = $originalBooking->{hazardous}->getNextElement;
				my $newHazardous = $newBooking->{hazardous}->getNextElement;

				next unless((defined($originalLineItem))||(defined($newLineItem)));

				# Setting value of lineitem to 1 if the lineitems of that booking are ended. And assigning hazardous details to the lineitem of other booking so they can be accesed later in lineItemsChecker().
				if (!defined($originalLineItem))
				{
					$originalLineItem = 1;
					$newLineItem->setHazardousDetails($newHazardous);
					$cLineitemFinalString .= "<br />".$self->getLineItemString("AddedLineItem","iLineitemCount",$iLineitemCount)."<br />\n";
					$cLineitemFinalString .= $self->getLineitemChangeString($newLineItem,$iLineitemCount);
					$iShowCheck = 1;
				}
				if (!defined($newLineItem))
				{
					$newLineItem = 1;
					$cLineitemFinalString .= "<br />".$self->getLineItemString("RemovedLineItem","iLineitemCount",$iLineitemCount)."<br />\n";
					$iShowCheck = 1;
				}

				my $cLineitemString = "";

				# Calling lineItemsChecker() to check for changes in lineitems.
				if ($newLineItem != 1 && $originalLineItem != 1)
				{
					$cLineitemString .= $self->lineItemsChecker($originalLineItem,$newLineItem,$iLineitemCount); 

					if ($cLineitemString ne "") 
					{
						$cLineitemFinalString .= "<br />".$self->getLineItemString("ChangesInLineItem","iLineitemCount",$iLineitemCount)."<br />\n";
						$cLineitemFinalString .= $cLineitemString;
						$iShowCheck = 1;
					}
					else
					{
						$cLineitemFinalString .= "<br />".$self->getLineItemString("SameLineItem","iLineitemCount",$iLineitemCount)."<br />\n";
					}
				}

				if ($iLineitemCount == $noOflineitemsLargest && $iShowCheck==1) 
				{
					$changes .= $cLineitemFinalString;
				}
				
				if ($newLineItem != 1 && $originalLineItem != 1) 
				{
					if ($newLineItem->getHazardousFlag eq "Y" || $newLineItem->getHazardousFlag eq "y")
					{
						my $cHazString = "";
						
						# Calling hazardousDetailsChecker() to check for changes in Hazardous Details.
						$cHazString .= $self->hazardousDetailsChecker($originalHazardous,$newHazardous,$iLineitemCount);

						# Code to assign statements to $changes in proper format.
						if ($cHazString ne "") 
						{
							$cHazFinalString .= "<br />".$self->getLineItemString("ChangesInHazardousDetails","iLineitemCount",$iLineitemCount)."<br />\n";
							$cHazFinalString .= $cHazString;
							$iShowHazCheck = 1;
						}
					}
				}
				if ($iLineitemCount == $noOflineitemsLargest && $iShowHazCheck==1) 
				{
					$changes .= "<br />".$self->getLineItemString("HazardousDetailChanged")."\n";
					$changes .= $cHazFinalString;
				}
				$iLineitemCount++;
			}
		}
		else
		{
			my $cLineitemFinalString = "";
			my $iShowCheck = 0;
			my $cHazFinalString = "";
			my $iShowHazCheck = 0;

			while (($originalBooking->{lineitem}->hasMoreElements) && ($newBooking->{lineitem}->hasMoreElements))
			{
				my $originalLineItem = $originalBooking->{lineitem}->getNextElement;
				my $newLineItem = $newBooking->{lineitem}->getNextElement;
				next unless(defined($originalLineItem));

				my $cLineitemString = "";

				# Checking for changes in lineitems values since the line items are same.
				$cLineitemString .= $self->lineItemsChecker($originalLineItem,$newLineItem,$iLineitemCount);
				
				if ($cLineitemString ne "") 
				{
					$cLineitemFinalString .= "<br />".$self->getLineItemString("ChangesInLineItem","iLineitemCount",$iLineitemCount)."<br />\n";
					$cLineitemFinalString .= $cLineitemString;
					$iShowCheck++;
				}
				if ($iLineitemCount == $noOflineitemsOrg && $iShowCheck>1) 
				{
					$changes .= $self->getLineItemString("SameLineItemAmount");
					$changes .= $cLineitemFinalString;
				}
				elsif ($iLineitemCount == $noOflineitemsOrg && $iShowCheck==1)
				{
					$changes .= $self->getLineItemString("SameLineItemAmount");
					#Added code yo print Updated lineItem details into mail for jita wwa-619 by bnagpure on 08-01-2020
					$cLineitemFinalString = "<br />".$self->getLineItemString("1ChangesInLineItem","iLineitemCount",$iLineitemCount)."<br />\n" if(!defined($self->{replace_receiver})); 
					$cLineitemFinalString .= $cLineitemString;
					$changes .= $cLineitemFinalString;
				}

				my $originalHazardous = $originalBooking->{hazardous}->getNextElement;
				my $newHazardous = $newBooking->{hazardous}->getNextElement;
				next unless(defined($originalHazardous));
			
				# Checking for Hazardous Details.
				if ($newLineItem->getHazardousFlag eq "Y" || $newLineItem->getHazardousFlag eq "y")
				{
					my $cHazString = "";
					
					$cHazString .= $self->hazardousDetailsChecker($originalHazardous,$newHazardous,$iLineitemCount);
					if ($cHazString ne "") 
					{
						$cHazFinalString .= "<br />".$self->getLineItemString("ChangesInHazardousDetails","iLineitemCount",$iLineitemCount)."<br />\n";
						$cHazFinalString .= $cHazString;
						$iShowHazCheck++;
					}

					if ($iLineitemCount == $noOflineitemsOrg && $iShowHazCheck>1) 
					{
						$changes .= "<br />".$self->getLineItemString("HazardousDetailChanged")."\n";
						$changes .= $cHazFinalString;
					}
					elsif ($iLineitemCount == $noOflineitemsOrg && $iShowHazCheck==1) 
					{
						$changes .= "<br />".$self->getLineItemString("HazardousDetailChanged");
						#Added code yo print Updated Haz details into mail for jita wwa-619 by bnagpure on 08-01-2020.
						$cHazFinalString = "<br />".$self->getLineItemString("1ChangesInHazardousDetails")."<br />\n"  if(!defined($self->{replace_receiver})) ;
						$cHazFinalString .= $cHazString;
						$changes .= $cHazFinalString;
					}
				}
				$iLineitemCount++;
			}
		}
		
		# Checking for changes in pickup details
		if ($newBooking->getPickup eq 'Y' || $newBooking->getPickup eq 'y') 
		{ 
			$originalBooking->{pickup}->resetCounter;
			$newBooking->{pickup}->resetCounter;
			my $originalPickup = $originalBooking->{pickup}->getNextElement;
			my $newPickup =$newBooking->{pickup}->getNextElement;
			my $cPickupString = "";

			if($self->checkDefined($originalPickup->getDate) ne $self->checkDefined($newPickup->getDate))
			{
				$cPickupString .= "Date = ".$newPickup->getDate."<br />\n";
			}
			if($self->checkDefined($originalPickup->getTime) ne $self->checkDefined($newPickup->getTime))
			{
				$cPickupString .= "Time = ".$newPickup->getTime."<br />\n";
			}
			if($self->checkDefined($originalPickup->getCombinedAddress) ne $self->checkDefined($newPickup->getCombinedAddress))
			{
				$cPickupString .= "Combined Address = ".$newPickup->getCombinedAddress."<br />\n";
			}
			if($self->checkDefined($originalPickup->getCompanyname) ne $self->checkDefined($newPickup->getCompanyname))
			{
				$cPickupString .= "Company Name = ".$newPickup->getCompanyname."<br />\n";
			}
			if($self->checkDefined($originalPickup->getAddress) ne $self->checkDefined($newPickup->getAddress))
			{
				$cPickupString .= "Address = ".$newPickup->getAddress."<br />\n";
			}
			if($self->checkDefined($originalPickup->getCity) ne $self->checkDefined($newPickup->getCity))
			{
				$cPickupString .= "City = ".$newPickup->getCity."<br />\n";
			}
			if($self->checkDefined($originalPickup->getState) ne $self->checkDefined($newPickup->getState))
			{
				$cPickupString .= "State = ".$newPickup->getState."<br />\n";
			}
			if($self->checkDefined($originalPickup->getCountry) ne $self->checkDefined($newPickup->getCountry))
			{
				$cPickupString .= "Country = ".$newPickup->getCountry."<br />\n";
			}
			if($self->checkDefined($originalPickup->getPostalcode) ne $self->checkDefined($newPickup->getPostalcode))
			{
				$cPickupString .= "Postal Code = ".$newPickup->getPostalcode."<br />\n";
			}
			if($self->checkDefined($originalPickup->getPhone) ne $self->checkDefined($newPickup->getPhone))
			{
				$cPickupString .= "Phone = ".$newPickup->getPhone."<br />\n";
			}
			if($self->checkDefined($originalPickup->getContactperson) ne $self->checkDefined($newPickup->getContactperson))
			{
				$cPickupString .= "Contact Person = ".$newPickup->getContactperson."<br />\n";
			}
			if($self->checkDefined($originalPickup->getFax) ne $self->checkDefined($newPickup->getFax))
			{
				$cPickupString .= "Fax = ".$newPickup->getFax."<br />\n";
			}
			if($self->checkDefined($originalPickup->getEmail) ne $self->checkDefined($newPickup->getEmail))
			{
				$cPickupString .= "Email = ".$newPickup->getEmail."<br />\n";
			}
			if($self->checkDefined($originalPickup->getPickupReference) ne $self->checkDefined($newPickup->getPickupReference))
			{
				$cPickupString .= "Pickup Reference = ".$newPickup->getPickupReference."<br />\n";
			}
			if($self->checkDefined($originalPickup->getRemarks) ne $self->checkDefined($newPickup->getRemarks))
			{
				$cPickupString .= "Remarks = ".$newPickup->getRemarks."<br />\n";
			}
			if ($cPickupString ne "") 
			{
				$changes .= "<br />".$self->getLineItemString("PickupDetailsChanged")."<br />\n";
				$changes .= $cPickupString
			}
		}
			
		# check if no changes were found.
		if($changes eq ($self->getLineItemString("ChangesFound")."<br /><br />\n"))
		{
			$changes = $self->getLineItemString("NoChanges");
		}

		$customerBooking->{changes} = $changes;
	}
	# End of function checkUpdateBookingChanges.

=head1

This subroutine checks individual LineItem properties for changes made when updating.

=cut
	sub lineItemsChecker
	{
		my $self = shift;
		my $originalLineItem = shift;
		my $newLineItem = shift;
		my $iLineitemCount = shift;
		my $cNewLineItemString = "";
		my $cReturnString = "";

		if($self->checkDefined($originalLineItem->getHSCode) ne $self->checkDefined($newLineItem->getHSCode))
		{
			$cNewLineItemString .= "HS Code = ".$newLineItem->getHSCode."<br />\n";
		}
		if($self->checkDefined($originalLineItem->getCommodity) ne $self->checkDefined($newLineItem->getCommodity))
		{
			$cNewLineItemString .= "Commodity = ".$newLineItem->getCommodity."<br />\n";
		}
		if($self->checkDefined($originalLineItem->getPackaging) ne $self->checkDefined($newLineItem->getPackaging))
		{
			$cNewLineItemString .= "Packaging = ".$newLineItem->getPackaging."<br />\n";
		}
		if($self->checkDefined($originalLineItem->getPieces) != $self->checkDefined($newLineItem->getPieces))
		{
			$cNewLineItemString .= "Pieces = ".$newLineItem->getPieces."<br />\n";
		}
		if($self->checkDefined($originalLineItem->getWeight) != $self->checkDefined($newLineItem->getWeight))
		{
			$cNewLineItemString .= "Weight = ".$newLineItem->getWeight."<br />\n";
		}
		if($self->checkDefined($originalLineItem->getCube) != $self->checkDefined($newLineItem->getCube))
		{
			$cNewLineItemString .= "Cube = ".$newLineItem->getCube."<br />\n";
		}
		if($self->checkDefined($originalLineItem->getUOM) ne $self->checkDefined($newLineItem->getUOM))
		{
			$cNewLineItemString .= "UOM = ".$newLineItem->getUOM."<br />\n";
		}

		if($self->checkDefined($originalLineItem->getOverdimension) ne $self->checkDefined($newLineItem->getOverdimension))
		{
			$cNewLineItemString .= "Over Dimension Flag = ".$newLineItem->getOverdimension."<br />\n";
		}

		if($self->checkDefined($originalLineItem->getOverheight) ne $self->checkDefined($newLineItem->getOverheight))
		{
			$cNewLineItemString .= "Over Height Flag = ".$newLineItem->getOverheight."<br />\n";
		}

		if($self->checkDefined($originalLineItem->getOverlength) ne $self->checkDefined($newLineItem->getOverlength))
		{
			$cNewLineItemString .= "Over Length Flag = ".$newLineItem->getOverlength."<br />\n";
		}

		if($self->checkDefined($originalLineItem->getOverweight) ne $self->checkDefined($newLineItem->getOverweight))
		{
			$cNewLineItemString .= "Over Weight Flag = ".$newLineItem->getOverweight."<br />\n";
		}

		if($self->checkDefined($originalLineItem->getOverwidth) ne $self->checkDefined($newLineItem->getOverwidth))
		{
			$cNewLineItemString .= "Over Width Flag  = ".$newLineItem->getOverwidth."<br />\n";
		}
		if($self->checkDefined($originalLineItem->getHazardousFlag) ne $self->checkDefined($newLineItem->getHazardousFlag))
		{
			$cNewLineItemString .= "Hazardous Flag = ".$newLineItem->getHazardous." - ";

			if ($newLineItem->getHazardousFlag eq "Y" || $newLineItem->getHazardousFlag eq "y")
			{
				$cNewLineItemString .= $self->getLineItemString("NewHazAdded","iLineitemCount",$iLineitemCount)."<br />\n";
			}
			else
			{
				$cNewLineItemString .= $self->getLineItemString("OldHazRemoved","iLineitemCount",$iLineitemCount)."<br />\n";
			}
		}
		if($originalLineItem->getShippingmarks ne $newLineItem->getShippingmarks)
		{
			$cNewLineItemString .= "Shipping Marks = ".$newLineItem->getShippingmarks."<br />\n";
		}
		return($cNewLineItemString);
	}
	# End of function lineItems Checker.

=head1
	
This function checks individual HazardousDetails properties for changes made when updating.
	
=cut
	sub hazardousDetailsChecker
	{
		my $self = shift;
		my $originalHazardous = shift;
		my $newHazardous = shift;
		my $iLineitemCount = shift;
		my $cNewHazardousString = "";
		my $cReturnString = "";
		
		if($self->checkDefined($originalHazardous->getHazclass) != $self->checkDefined($newHazardous->getHazclass))
		{
			$cNewHazardousString .= "Hazardous Class ID = ".$newHazardous->getHazclass."<br />\n";
		}
		if($self->checkDefined($originalHazardous->getFlashpoint) ne $self->checkDefined($newHazardous->getFlashpoint))
		{
			$cNewHazardousString .= "Flash Point = ".$newHazardous->getFlashpoint."<br />\n";
		}
		if($self->checkDefined($originalHazardous->getDegreeUOM) ne $self->checkDefined($newHazardous->getDegreeUOM))
		{
			$cNewHazardousString .= "Degree UOM = ".$newHazardous->getDegreeUOM."<br />\n";
		}
		if($self->checkDefined($originalHazardous->getShippingname) ne $self->checkDefined($newHazardous->getShippingname))
		{
			$cNewHazardousString .= "Shipping Name = ".$newHazardous->getShippingname."<br />\n";
		}
		if($self->checkDefined($originalHazardous->getUnnumber) != $self->checkDefined($newHazardous->getUnnumber))
		{
			$cNewHazardousString .= "Un Number = ".$newHazardous->getUnnumber."<br />\n";
		}
		if($self->checkDefined($originalHazardous->getPackinggroup) ne $self->checkDefined($newHazardous->getPackinggroup))
		{
			$cNewHazardousString .= "PackingGroup = ".$newHazardous->getPackinggroup."<br />\n";
		}
		return($cNewHazardousString);
	}

=head1

This function displays the new added lineitem and hazardous detail if present or old removed lineitem and hazardous detail if present.

=cut
	sub getLineitemChangeString
	{
		my $self = shift;
		my $lineItem = shift;
		my $iLineitemCount = shift;
		my $hazardous = $lineItem->getHazardousDetails;
		my $cLineItemString = "";

			$cLineItemString .= $self->getLineItemString("ShowingLineItemChanges","iLineitemCount",$iLineitemCount)."<br />\n";

			if ($lineItem->getHSCode ne "") 
			{
				$cLineItemString .= "HS Code = ".$lineItem->getHSCode."<br />\n";
			}
			
			if ($lineItem->getCommodity ne "") 
			{
				$cLineItemString .= "Commodity = ".$lineItem->getCommodity."<br />\n";
			}
			
			if ($lineItem->getPackaging ne "") 
			{
				$cLineItemString .= "Packaging = ".$lineItem->getPackaging."<br />\n";
			}

			$cLineItemString .= "Pieces = ".$lineItem->getPieces."<br />\n";
			$cLineItemString .= "Weight = ".$lineItem->getWeight."<br />\n";
			$cLineItemString .= "Cube = ".$lineItem->getCube."<br />\n";

			if ($lineItem->getUOM ne "") 
			{
				$cLineItemString .= "UOM = ".$lineItem->getUOM."<br />\n";
			}

			$cLineItemString .= "Hazardous Flag = ".$lineItem->getHazardous."<br />\n";
			$cLineItemString .= "Over Dimension Flag  = ".$lineItem->getOverdimension."<br />\n";
			$cLineItemString .= "Over Height Flag = ".$lineItem->getOverheight."<br />\n";
			$cLineItemString .= "Over Length Flag = ".$lineItem->getOverlength."<br />\n";
			$cLineItemString .= "Over Weight Flag = ".$lineItem->getOverweight."<br />\n";
			$cLineItemString .= "Over Width Flag = ".$lineItem->getOverwidth."<br />\n";

			if ($lineItem->getShippingmarks ne "") 
			{
				$cLineItemString .= "Shipping Marks = ".$lineItem->getShippingmarks."<br />\n";
			}

			if ($lineItem->getHazardous eq "Y" || $lineItem->getHazardous eq "y")
			{
				$cLineItemString .= "<blockquote>".$self->getLineItemString("ShowingHazDetailsChanges","iLineitemCount",$iLineitemCount)."<br />\n";
				$cLineItemString .= "Hazardous Class ID = ".$hazardous->getHazclass."<br />\n";

				if ($hazardous->getFlashpoint ne "")
				{
					$cLineItemString .= "Flash Point = ".$hazardous->getFlashpoint."<br />\n";
				}

				if ($hazardous->getDegreeUOM)
				{
					$cLineItemString .= "Degree UOM = ".$hazardous->getDegreeUOM."<br />\n";
				}

				if ($hazardous->getShippingname ne "")
				{
					$cLineItemString .= "Shipping Name = ".$hazardous->getShippingname."<br />\n";
				}

				$cLineItemString .= "Un Number = ".$hazardous->getUnnumber."<br />\n";

				if ($hazardous->getPackinggroup ne "")
				{
					$cLineItemString .= "PackingGroup = ".$hazardous->getPackinggroup."</blockquote>";
				}
			}
		return($cLineItemString);
	}
	#End of getLineitemChangeString().

=head1

This sub routine gets the text to be added in $changes from templates inside EIBooking.xml.

=cut

	sub getLineItemString
	{
		my $self = shift;
		my $cTemplateName = shift;
		my $cVarName = shift;
		my $nVarValue = shift;

		die "Fatal error! No template name!" unless(defined($cTemplateName));	# FIXME: use handleError

		my $template = wwa::Template->new("$cTemplateName");

		if (defined($cVarName))
		{
			my %switchdata = ();
			$switchdata{$cVarName} = $nVarValue;
			
			$template->parseTemplate(\%switchdata);
		}
		
		return($template->getTemplate);
	}
	#End of getLineItemString().


=head1 checkDefined

This Function will CHECK if the string is defined and not equal to null and if not initialized then intialize it and return the string.

Was written to remove unintialized warnings.

=cut


sub checkDefined
{
	my ($self, $cString) = @_;
	
	if(defined($cString) && $cString ne "")
	{
		$cRetval = $cString;
	}
	else
	{
		$cRetval = "";
	}
	
	return($cRetval);
}

=head logMetaData

# This subrouting use to log MetaData values
# Added by psakharkar on Thursday, January 10 2013 11:56:22 AM

=cut

	sub logMetaData
	{
		my ($self, $hBookingDetails) = @_;
		my $oEdiMeta = wwa::DO::WeiMetaData->new();
		$oEdiMeta->setFileID($ENV{app}->{EDI_FILES}->{iFileID});
		if($hBookingDetails->getBookingType eq 'C')
                {
			# Remove booking number from metadata by psakharkar for bug 10368
			$oEdiMeta->{metadata}{CustomerAlias} = $hBookingDetails->getEISendingOffice
				if(defined($hBookingDetails->getEISendingOffice) && $hBookingDetails->getEISendingOffice ne "");
		}
		$oEdiMeta->{metadata}{CommunicationReference} = $hBookingDetails->getCustIntRef
			if(defined($hBookingDetails->getCustIntRef) && $hBookingDetails->getCustIntRef ne "");
		#Added FPI in metadata for Mission 18772 by msawant
		$oEdiMeta->{metadata}{FPI} = $hBookingDetails->getPC
                        if(defined($hBookingDetails->getPC) && $hBookingDetails->getPC ne "");
		$oEdiMeta->{metadata}{CustomerReference} = $hBookingDetails->getCustRef
			if(defined($hBookingDetails->getCustRef) && $hBookingDetails->getCustRef ne "");
		# Added metadata for BookingOffice for bug 11463 by rpatra
		$oEdiMeta->{metadata}{BookingOffice} = $hBookingDetails->getBookingOffice if($hBookingDetails->getBookingOffice ne "");
		# Added code to pass portal setting for jira wwa-40 by pkokate on 4 feb 2020
		$oEdiMeta->{PortalMemberSettings} = $hBookingDetails->{PortalMemberSettings};
		$oEdiMeta->addMetadataValue();
	}

=head1 loadSettings

This will store required details, like iProgramID into base hash
Added for bug 14159, by vbind 2013-09-18.
=cut

	sub loadSettings
	{
		my ($self, $hBookingDetails) = @_;
		my $oProgram = wwa::DO::GenProgram->new();
		$oProgram->setCode('BKG');

		# Modified code to get Programdetails based upon cCode, committing changes under bug 14159, by vbind 2013-09-26.
		my $hProgramdetails = $oProgram->getProgramDetailsFromCode;
		$hBookingDetails->{iProgramID} = $hProgramdetails->{'iProgramID'};
		$hBookingDetails->{cEmailprefix} = $hProgramdetails->{'cEmailprefix'};
	}

=head1 validateCustomerControlCode
This will validate customer control code for member to member booking only 
for Mission 27675 by vthakre 2017-02-27.
=cut
			
	sub validateCustomerControlCode
        {
                my ($self , $hBookingDetails) = @_;
                my $iValidateFlag = 0;
		my $cString;
		my $cInvalidValue="";

                if (!$hBookingDetails->{cCustomercontrolcode} || $hBookingDetails->{cCustomercontrolcode} eq "")
                {
                        $iValidateFlag = 1;
			$cString = "Missing Customer Control Code";
                }
                elsif($hBookingDetails->{cCustomercontrolcode} ne "")
                {
                        eval('use wwa::DO::OfficeMap');
                        handleError(10102, "$@") if ($@);
			my $oOfficeMap = wwa::DO::OfficeMap->new();
                        my $hDetails = $oOfficeMap->getOfficedetails($hBookingDetails->{cCustomercontrolcode});

                        if(!$hDetails->{'cExternalcode'} || $hDetails->{'cExternalcode'} eq "")
                        {
                                $iValidateFlag = 1;
                                $cInvalidValue = $hBookingDetails->{cCustomercontrolcode};
				$cString = "Invalid Customer Control Code";
                        }
                }
                return ($iValidateFlag, $cInvalidValue , $cString);
        }
=head

Added subroutine to send error mail to only EI support for internal database setting is missing.
for Mission 27827 by vthakre 2017-04-04.

=cut

sub sendErrorMissingDetail
{
	my ($self, $cEmailId, $hUserDetails, $hErrorText) = @_;
	my %hSwitchData = ();	

	my $template_body = wwa::Template->new("BookingErrorMailBody");
	$hSwitchData{cUsername} = $hUserDetails->{cUsername};
	$hSwitchData{file_name} = $ENV{app}->{EDI_FILES}->{cFileName};
	$template_body->parseTemplate(\%hSwitchData);

	my $template_sub = wwa::Template->new("MissingDataSubject");
	$template_sub->parseTemplate($hUserDetails);
	my $cMailsubject = $template_sub->getTemplate;

	my $template = {};
	$template->{TemplateName} = wwa::Template->new('TemplateName');
	my $templatetitle = $template->{TemplateName}->getTemplate;

	my $tmp = wwa::DO::GetHeaderFooter::getHeaderFooter($templatetitle);
	$tmp->{cHeader} =~ s/RESERVEDtopicText// if defined $tmp->{cHeader};
	my $year = POSIX::strftime("%Y", localtime(time));
	$tmp->{cFooter} =~ s/RESERVEDyear/$year/ if defined $tmp->{cFooter};

	my $cMailBody = $tmp->{cHeader}.$template_body->getTemplate.$tmp->{cFooter};

	vverbose(4,"Sending mail to EI Support for internal data missing.");

	my $mail = wwa::Mail->new();
	$mail->to($cEmailId);
	$mail->subject($cMailsubject);
	$mail->body($cMailBody);
	$mail->send();
}

=head1

# Below subroutine will map the member setting for mission 27449 by vthakre 2017-04-12.

=cut

sub mapMemberSettings
{
        my($self, $iMemberID) = @_;
        my $hSettings = {};

        my $oMemberSetting = wwa::DO::MemberSetting->new();
        $hSettings = $oMemberSetting->getSettings($iMemberID,$ENV{app}->{EDI_FILES}->{iProgramID}) if (defined($iMemberID) && $iMemberID ne '');

        return $hSettings;
}

=head1

Added function to write acknowledgement for Mission 27449 by vthakre 2017-04-24.

=cut

sub acknowledge
{
	my ($self,$hBookingDetails, $cSettings) = @_;
	my $oAck = wwa::EI::BookingRequest::Export::BookingAck->new();

	# Modified condition to send acknowledgemnt to portal for mission 29114.
	# WWA-499 Added replace_receiver check for replace receiver id by vgarasiya on 25-11-2019
	my $hPortalSettings = $hBookingDetails->{PortalMemberSettings};
	if((defined($cSettings->{wwa_format}) && $cSettings->{wwa_format} eq 'Y') || (defined($hPortalSettings->{wwa_format}) && $hPortalSettings->{wwa_format} eq 'Y')
	|| (defined($self->{'replace_receiver'}) && $self->{'replace_receiver'} ne ''))
	{
		# Added code to print communication reference in ack file for Mission 28528 by vthakre, 2018-03-05.
		$hBookingDetails->{Settings} = $cSettings;
		$oAck->mapAck($hBookingDetails);
	}
	else
	{
		$oAck->mapXml($hBookingDetails);		
	}
}

=head1

Added function to write reject status in ack file for Mission 27449 by vthakre 2017-04-25.

=cut

sub ack_status
{
	my($self, $hBookingDetails, $cErrorText, $hSettings)= @_;
	my $file = $ENV{app}->getMessage;
	my $hPortalSettings = $hBookingDetails->{PortalMemberSettings};
	my $oExportdata = wwa::EI::BookingRequest::Export->new;
	my $cAckFile = &File::Basename::basename($file);
       
	# Modified condition to send acknowledgemnt to portal for mission 29114.
	if((defined($hSettings->{acknowledge_xml}) && $hSettings->{acknowledge_xml} eq 'Y') || (defined($hPortalSettings->{acknowledge_xml}) && $hPortalSettings->{acknowledge_xml} eq 'Y'))
	{
		# Added code to concatenate .ack to APERAK file for Mission 28602 by vthakre, 2018-09-21
		$cAckFile .= '_ack';
		my $cFile = $ENV{app}->datapool->get('config.xml.global.temp_bookdir').$ENV{app}->{user_name}."/".$cAckFile;
		if (-f $cFile)
		{
			# Added code to send APERAK in WWA format for Mission 28188 by vthakre, 2017-10-30.
			if ((defined($hSettings->{wwa_format}) && $hSettings->{wwa_format} eq 'Y') || (defined($hPortalSettings->{wwa_format}) && $hPortalSettings->{wwa_format} eq 'Y') || (defined($self->{'replace_receiver'}) && $self->{'replace_receiver'} ne '') )
			{
				`sed -i s/ackstatus/R/g "$cFile"`;
				system("sed -i -re 's#<Remarks></Remarks>#<Remarks>$cErrorText</Remarks>#g' '$cFile'");
			}
			else
			{
				system("sed -i -re 's#<Acknowledgement>#<Acknowledgement>\\n\\t\\t    <Status>A104</Status>#g' $cFile");
				system("sed -i -re 's#</Number>#</Number>\\n\\t\\t    <Reference></Reference>#g' $cFile");
				system("sed -i -re 's#</Reference>#</Reference>\\n\\t\\t    <ErrorMessage>Validation Failed</ErrorMessage>#g' $cFile");
				system("sed -i -re 's#</ErrorMessage>#</ErrorMessage>\\n\\t\\t    <ErrorCode>$cErrorText</ErrorCode>#g' $cFile");
			}
		}
	
		my $hAperakStatus;
		$hAperakStatus->{Status} = "REJECTED";
		$self->{_removeTempFile} = 'Y';		
		$oExportdata->transferAckXml($cFile, $hAperakStatus, $hBookingDetails);		
	}
}

1;

#
# $Log: XML.pm,v $
# Revision 1.117  2021/05/13 11:08:30  pkokate
# Jira WWA-1526: Removed code to log envelopID in metaData for jira WWA-891
#
# Revision 1.116  2021/05/05 12:02:57  pkokate
# Jira WWA-1526:Modified code to validate communication reference based on portal Customer
#
# Revision 1.115  2021/04/26 08:51:40  pkokate
# Jira WWA-1455:Added code to map Addressdetails and add flag for relax ETA/ETD validation for DBSchenker
#
# Revision 1.114  2020/06/24 12:51:55  pkokate
# Jira WWA-891 : Added metadata for envelopeID
#
# Revision 1.113  2020/06/17 05:25:23  smadhukar
# WWA-932 - Retrieve schema from link
#
# Revision 1.112  2020/05/21 11:29:33  smadhukar
# WWA-920 : Fixed the issue for KN and Panalpina
#
# Revision 1.111  2020/05/13 10:27:24  smadhukar
# WWA-920 : set sender company name as a company name
#
# Revision 1.110  2020/02/13 05:09:14  pkokate
# Jira WWA-40: Fixed issue of pass portal member setting
#
# Revision 1.109  2020/02/13 04:51:27  pkokate
# Jira WWA-685:Added code to remove characters from UnNumber and to capture only first 4 digit
#
# Revision 1.108  2020/02/04 10:49:16  bnagpure
# wwa-618 : Added code to handle camel case senderID
#
# Revision 1.107  2020/02/04 10:12:00  pkokate
# Jira WWA-40: Added code to pass portal setting
#
# Revision 1.106  2020/01/08 10:51:55  bnagpure
# wwa-618/wwa-619: Added code yo print Updated Haz/lineItem details and convert small letter to into capital
#
# Revision 1.105  2019/12/16 13:26:05  bnagpure
# wwa-474: Initilize flag of bkg module
#
# Revision 1.104  2019/12/10 08:36:14  smadhukar
# WWA-453 ; Changed the if condition to send proper error.
#
# Revision 1.103  2019/11/27 06:39:57  vgarasiya
# WWA-499:For replace sender and receiver ids for agility booking request
#
# Revision 1.102  2019/10/25 07:09:11  pkokate
# Jira WWA-390: Added code to validate booking date
#
# Revision 1.101  2019/07/03 10:56:16  smadhukar
#  Mission 30390 : Added support for LegInfo
#
# Revision 1.100  2019/05/31 09:22:42  bnagpure
# Mission 30133: Added code to set counter for lineItem.
#
# Revision 1.99  2019/05/30 05:22:12  bnagpure
# Mission 30133: Added code to fail file if cHazardousflag is 'Y' and hazardousDetails are missing
#
# Revision 1.98  2019/05/09 09:54:41  smadhukar
# Mission 30177: Added code to update RequestType from U to N if cCode='RequestType'
#
# Revision 1.97  2019/04/24 05:08:41  smadhukar
# Mission : 29907 Added code to log error and send mail notification for request type U/C if multiple booking numbers are present.
#
# Revision 1.96  2019/04/16 12:18:01  smadhukar
# Mission 30075:Added code to have support for ServiceType and MoveType
#
# Revision 1.95  2019/02/21 05:58:48  smadhukar
# Mission 29801 : Added support for Hazardous details
#
# Revision 1.94  2019/02/19 06:54:49  vthakre
# Mission 29798 : Added code to relax eta and etd validation.
#
# Revision 1.92  2019/02/18 12:19:25  vthakre
# Mission 29798 : Added code to relax ETA validation for UPS
#
# Revision 1.90  2018/09/26 05:26:52  vthakre
# Mission 28602: Added code to send aperak.
#
# Revision 1.89  2018/09/06 06:51:21  bpatil
# Mission 29114 : Modified code to get portal data.
#
# Revision 1.88  2018/08/28 11:59:39  vthakre
# Mission 29101 : Added code to add column cName in boo_Booking_contactdetail table.
#
# Revision 1.87  2018/04/26 06:46:38  sdalai
# Mission 28647 : Removed single inverted comma from Error string.
#
# Revision 1.86  2018/04/04 09:37:33  vthakre
# Mission 28611 : corrected error message for FCL.
#
# Revision 1.85  2018/04/04 05:47:39  vthakre
# Mission 28611 : Removed invalid value from error string.
#
# Revision 1.84  2018/03/29 08:21:09  vthakre
# Mission 28611 : Added code for booking type 'F' validation.
#
# Revision 1.83  2018/03/20 05:29:01  bpatil
# Mission 28518 : Added code to convert single line xml file in formatted xml
#
# Revision 1.82  2018/03/06 11:31:24  vthakre
# Mission 28528 : Added code to integrate cargowise booking.
#
# Revision 1.81  2018/02/26 12:14:41  bpatil
# Mission 28518 : Added code to get Weight,Volume and UOM based on country for panalpina
#
# Revision 1.80  2017/11/20 08:45:11  vthakre
# Mission 28188 : Added code to ignore space from file name.
#
# Revision 1.79  2017/11/10 08:31:40  vthakre
# Mission 28188 : Added code to enable APERAK from booking request mdoule.
#
# Revision 1.78  2017/09/07 11:37:13  sdalai
# Mission 28112 : Added code to envelope version.
#
# Revision 1.77  2017/04/27 09:57:08  vthakre
# Mission 27449 : Added code for booking acknowledgement.
#
# Revision 1.76  2017/04/18 07:24:47  vthakre
# Mission 27449 : Added code to support multiple hazardous details.
#
# Revision 1.75  2017/04/13 13:26:49  vthakre
# Mission 27449 : Added code to convert file into xml format using xslt for rohlig.
#
# Revision 1.74  2017/04/07 06:42:15  vthakre
# Mission 27827 : Added code correct authentication error.
#
# Revision 1.73  2017/04/04 12:56:50  vthakre
# Mission 27827 : Added code for member-member booking process.
#
# Revision 1.72  2017/03/26 09:18:27  vthakre
# Mission 27675 : Removed Data::Dumper.
#
# Revision 1.71  2017/03/24 07:25:42  vthakre
# Mission 27675 : Added condition to insert data into logmetadata.
#
# Revision 1.70  2017/03/22 05:43:41  vthakre
# Mission 27675 : Added code to check empty receiver id.
#
# Revision 1.69  2017/03/21 09:32:18  vthakre
# Mission 27675 : Added code to correct booking type condition.
#
# Revision 1.68  2017/03/20 11:32:24  vthakre
# Mission 27675 : Added condition for empty reciver id.
#
# Revision 1.67  2017/03/07 09:55:39  vthakre
# Mission 27675 : Added code for member to member booking request.
#
# Revision 1.66  2016/10/03 07:26:07  bpatil
# Mission 27322 : Removed the validation for BookingOffice.
#
# Revision 1.65  2016/08/26 06:26:57  bpatil
# Mission 27149:Changed the regex to solve Email Extension issues on wwe-ei
#
# Revision 1.64  2016/08/04 08:56:55  rpatra
# Mission 27142: To send the email notificaton  based on the office code mapping to wwa member office
# commiting changes for vpatil.
#
# Revision 1.63  2016/03/23 05:47:16  rpatra
# Mission 26638: Added code to log error and send mail notification for request type N with booking number.
# Committing changes for msawant.
#
# Revision 1.62  2015/08/21 05:03:03  rpatra
# Mission 25790: Added support for OnwardGateway tag.
#
# Revision 1.61  2015/08/13 11:51:33  rpatra
# Mission 25667 : Added code to pass $iErrorFlag. Added code to make template message dynamic.
# Committing changes for msawant.
#
# Revision 1.60  2015/08/10 05:36:02  rpatra
# Mission25669: Added a code to read pickup from/to date of remarks tag.
# Committing changes for schavan.
#
# Revision 1.59  2015/07/14 05:40:23  rpatra
# Mission 25576: Removed code to set RequestType N if Request Type tag is missing.
# Committing changes for msawant.
#
# Revision 1.58  2015/07/01 11:54:25  rpatra
# Mission 25576 : Added validation for request type.
# Mission 25609 : Added code to remove leading and trailing spaces for customer email.
# Committing changes for msawant.
#
# Revision 1.57  2015/05/21 09:50:49  rpatra
# Mission 25415: Changed errorcode from 30111 to 10607 and corrected parsing error string.
# Committing changes for msawant.
#
# Revision 1.56  2015/05/18 11:00:15  rpatra
# Mission 25323: Removed the subroutine createBookingNumber and called getNewCounter to get new wwa reference
#
# Revision 1.55  2015/04/13 11:11:52  psakharkar
# Mission 25210 : Added function to mapped address details for shipper, consignee & notify
#
# Revision 1.54  2015/04/13 06:55:46  rpatra
# Mission 25265: Added a code to fail a file if pickup date is invalid/missing irrespective of invalid/missing pickup time.
# Committing changes for schavan.
#
# Revision 1.53  2015/03/20 09:27:30  psakharkar
# Mission 25014 : Added mapping for <ShipperReference>, <ConsigneeReference>
#
# Revision 1.52  2015/03/13 10:08:44  rpatra
# Mission 24976: Removed code of exchange. Committing changes for msawant.
#
# Revision 1.51  2015/01/28 10:39:55  rpatra
# Mission 24870: Passed iUserID to to check existence, Changed the subroutine name from getWWAReference to getBookingdetails to reuse existing subroutine.
#
# Revision 1.50  2015/01/02 05:11:51  smadhukar
# Mission 24528 : Added Extra Status code in Error Description and in query to count the record for Status code 30,31,40,50
# Committing changes for msawant
#
# Revision 1.49  2014/12/29 06:36:58  rpatra
# Mission 24528 : Changed $CustomerEmail by $cCustomerEmail and regex for $cCustomerEmail
# Committing changes for msawant.
#
# Revision 1.48  2014/12/24 09:43:49  rpatra
# Mission 24528: Added code to find whether event occured for Statuses 30,40,50. Added code for logging error and sending mail notification(booking can not be updated)
# Committing changes for msawant
#
# Revision 1.47  2014/12/12 12:13:21  rpatra
# Mission 24472: Since Email ID is not mandatory in schema made emailID validation as conditional for mission
#
# Revision 1.46  2014/11/28 10:07:35  rpatra
# Mission 24724: Corrected the regex to validate emailid
#
# Revision 1.45  2014/11/05 07:14:50  rpatra
# Mission 22826: Added support for new tags.
#
# Revision 1.44  2014/10/28 09:07:13  psakharkar
# Mission 22261 : Added condition to check failure notification mail send to additional email
#
# Revision 1.43  2014/09/25 11:38:19  rpatra
# Mission 15533: Added support for ShipmentRelatedData segments.
#
# Revision 1.42  2014/06/20 11:15:35  rpatra
# Mission 12714: Added the code to map new fields <ShipmentRelatedData>, <Length>, <Width> and <Height>.
# Committing changes for schavan.
#
# Revision 1.41  2014/05/13 12:07:48  rpatra
# Mission 18772: Added FPI data in metadata for Booking request files.
# Committing changes for msawant.
#
# Revision 1.40  2014/04/15 09:13:22  smadhukar
# Mission 18770 : Added code to map FPI data
# Commiting changes for msawant.
#
# Revision 1.39  2014/02/17 10:33:57  rpatra
# Mission 17054: Added code to validate UNLocation code for PortOfLoading, PortOfDischarge , BookingOffice, FinalDestination.
# Committing changes for msawant.
#
# Revision 1.38  2014/01/17 10:19:08  rpatra
# Mission 16081: Corrected the pickup time validation and corrected the storage of proper time in database.
# Committing changes for msawant.
#
# Revision 1.37  2014/01/07 12:26:56  rpatra
# Mission 16081: Modified the time format for KN based on Member's setting.
# Committing changes for msawant.
#
# Revision 1.36  2014/01/06 11:48:20  rpatra
# Mission 15935 : Added a code to send seperate email notification if office code is missing or mapping does not exist.
# Committing changes for schavan.
#
# Revision 1.35  2013/12/30 04:54:32  rpatra
# Mission13493 : Added the code to print port of discharge if updated on Booking update template
# Committing changes for schavan
#
# Revision 1.34  2013/12/26 09:12:10  rpatra
# Mission 16086: Validate the Booking based on the customer required references
#
# Revision 1.33  2013/12/19 10:24:24  rpatra
# Bug 16051: Set the bookingnumber in different hash.
#
# Revision 1.32  2013/12/16 12:39:56  smadhukar
# Bug 15806: Corrected the Company name value for invalid mail notifications.
# Committing changes for rpatra.
#
# Revision 1.31  2013/11/27 06:08:16  dsubedar
# Bug 14087: Committing changes for rpatra.
# 1) Added setting to skip pickup time validation of KN
# 2) Corrected the MetaData login for zipped files
# 3) Directly transfer the file without processing for KN and Panalpina if RequestType is U or C and Booking Date is older than 2013-11-26.
#
# Revision 1.30  2013/11/15 06:03:09  smadhukar
# Bug 15476 - Modified code to include additional email into base hash.
# Committing changes for vbind.
#
# Revision 1.29  2013/11/14 11:02:26  smadhukar
# Bug 15476 - Modified code to take member id of user.
# Committing changes for vbind.
#
# Revision 1.28  2013/11/06 09:41:34  smadhukar
# Bug 15050 : Modified the code to fail the booking if UOM or Weight or Volume is Invalide/Missing in any CargoDetail collection
# Committing changes for schavan
#
# Revision 1.27  2013/10/16 06:05:58  dsubedar
# Bug 14087: (rpatra) Added the logic for handling specialUOM (Weight/Volume calculation for KN booking).
#
# Revision 1.26  2013/10/08 06:18:47  smadhukar
# Bug 14159 - Modified code to get Programdetails based upon cCode.
# Committing changes for vbind.
#
# Revision 1.25  2013/09/25 05:03:33  psakharkar
# Bug 14159 - Modified to remove repetitive code.
# Committing changes for vbind.
#
# Revision 1.24  2013/07/10 10:07:01  smadhukar
# Bug 13197: Removed the explicit pass of iStatus as parameter.
# Committing changes for rpatra.
#
# Revision 1.23  2013/06/13 10:08:59  smadhukar
# Bug 12589 - Modified code to validate ETSOrigin as ETD date.
# Committing changes for vbind.
#
# Revision 1.22  2013/06/12 12:49:01  smadhukar
# Bug 12343 : Removed the code for email attachment and send error details in email body
# commiting changes for rpatra
#
# Revision 1.21  2013/05/23 05:35:59  akumar
# Bug 12520 : Modified add mapping of 'filename' for error notification mail.
# Committing changes for vbind.
#
# Revision 1.20  2013/05/14 11:14:16  dmaiti
# Bug 11701 - Modified code to validate only active office code.
# Committing changes for vbind
#
# Revision 1.19  2013/05/06 11:57:07  akumar
# Bug 11694 : Modified the code to support Booking Update and Cancel Request
# Committing changes for rpatra
#
# Revision 1.18  2013/04/25 04:59:01  akumar
# Bug 11440 - Modified code to add validation for customer reference & for Request Type 'N'.
# Committing changes for vbind.
#
# Revision 1.17  2013/04/18 11:07:59  akumar
# Bug 11759 : Revert back changes of bug 11440.
# Committing changes for rpatra
#
# Revision 1.13  2013/04/04 08:48:20  akumar
# Bug 11463 : Added code to map the BookingOffice data.
# Commiting changes for rpatra.
#
# Revision 1.12  2013/04/03 07:09:47  dsubedar
# Bug 11364 - Modified to change subject line for error notification emails.
# Committing changes for vbind.
#
# Revision 1.11  2013/03/26 11:53:38  akumar
# Bug 11553 : Remove error html file after sending error mail from tmp directory
# Committing changes for psakharkar
#
# Revision 1.10  2013/03/15 06:23:22  akumar
# Bug 10860 : Added subroutine to validate the UOM data
# Committing changes for rpatra
#
# Revision 1.9  2013/02/21 06:18:32  akumar
# Bug 10368 : Remove booking number from metadata
# Committing changes for psakharkar
#
# Revision 1.8  2013/02/08 10:26:17  akumar
# Bug 10799 : Modified to send consolidated mail for invalid/missing details.
# Committing changes for vbind.
#
# Revision 1.7  2013/02/07 09:15:09  akumar
# Bug 10368 Added code for metadata logging in Booking Request module
# Committing changes for psakharkar
#
# Revision 1.6  2013/01/18 10:48:53  akumar
# Bug 10331 : Added validation to send error mail if file does not have Cargo details
# Committing changes for rpatra
#
# Revision 1.5  2012/11/29 10:45:14  smozarkar
# Bug 7513 and 9876 : Modified the code to set FlashPoint
# Committing the chnages for psakharkar
#
# Revision 1.4  2012/09/18 12:32:23  smozarkar
# Bug 7370 : Added support to store multiple Commodity/Marks details
# Committing changes for rpatra
#
# Revision 1.3  2012/07/11 11:26:18  smozarkar
# Bug 7372 : Made changes to add customer's email id in the email list if its a valid email id.
# Committing changes for vbind.
#
# Revision 1.2  2012/05/15 12:21:30  smozarkar
# Bug 7372 - Added code to validate the XML & generate Booking Number only if the xml have valid data.
# Committing changes for vbind.
#
#
