# Copyright (c) 2010 - Action Without Borders
#
# MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

package IF::Mailer;

#========================================================
# ported from AWB by kd - 2009-10-14
# Mainly written by rsw.
#========================================================

use strict;
use base qw(
    IF::Dictionary
);

use Net::SMTP 2.29;

use IF::Config;
use IF::Utility;
use IF::Application;
use IF::Component;
use MIME::Base64;
use Data::Dumper;
use Encode qw(encode_utf8);
use Scalar::Util qw(weaken);

our $_smtpHandle;

sub initWithApplication {
    my ($self, $application) = @_;
    $self->{_application} = $application;
    weaken ($self->{_application});

    # check for the right config goop
    my $SITE_ADMINISTRATOR = $application->configurationValueForKey("SITE_ADMINISTRATOR");
    my $SMTP_SERVERS       = $application->configurationValueForKey("SMTP_SERVERS");
    my $SMTP_EHLO_NAME     = $application->configurationValueForKey("SMTP_EHLO_NAME");
    my $SENDMAIL           = $application->configurationValueForKey("SENDMAIL");

    unless ($SITE_ADMINISTRATOR) {
        IF::Log::error("No SITE_ADMINISTRATOR specified in application configuration");
        return undef;
    }
    unless ($SMTP_SERVERS || $SENDMAIL) {
        IF::Log::error("No mail transport mechanism (SENDMAIL or SMTP_SERVERS) specified in application configuration");
        return undef;
    }
    $self->{SMTP_SERVERS} = $SMTP_SERVERS;
    $self->{SMTP_EHLO_NAME} = $SMTP_EHLO_NAME;
    $self->{SENDMAIL} = $SENDMAIL;
    $self->{SITE_ADMINISTRATOR} = $SITE_ADMINISTRATOR;
    return $self;
}

sub application { return $_[0]->{_application} }
sub SITE_ADMINISTRATOR { return $_[0]->{SITE_ADMINISTRATOR} }
sub SMTP_SERVERS       { return $_[0]->{SMTP_SERVERS}       }
sub SMTP_EHLO_NAME     { return $_[0]->{SMTP_EHLO_NAME}     }
sub SENDMAIL           { return $_[0]->{SENDMAIL}           }

# There is no guarantee that this succeeds, so app needs to fall back to a secondary
# smtp server or a maildrop delivery if creation of this handle fails
#
# Postfix is configured to allow idle connections for up to 30 seconds before closing
# them, which means under heavy mail load (mailqueue especially), connections are
# kept open but during light mail load (mod_perl clients) they will close down
# and transparently be re-opened by this method.
sub smtpHandle {
    my $self = shift;
	my $smtpServers = shift
		|| $self->SMTP_SERVERS() || [];

	IF::Log::dump($smtpServers);

	return $_smtpHandle if ($_smtpHandle && $_smtpHandle->reset());
	$_smtpHandle = undef;

	my $hello = $self->SMTP_EHLO_NAME();
	foreach my $smtpServer (@$smtpServers) {
		IF::Log::debug("Trying connection to SMTP server $smtpServer");
		$_smtpHandle = Net::SMTP->new( Host => $smtpServer,
						Hello => $hello,
						Timeout => 5,
						Debug => 0,
					);
		last if $_smtpHandle;
	}

	# At this point we've either found a server in the list to connect to, or
	# $_smtpServer is still undef so the app should fall back to using maildrop style delivery
	if ($_smtpHandle) {
		IF::Log::info("Connected to SMTP server ".$_smtpHandle->banner());
	} else {
		IF::Log::warning("Could not connect to an SMTP server.  Falling back to maildrop.");
	}

	return $_smtpHandle;
}

sub sendMessageBySMTP {
    my $self = shift;
	my $to = shift;
	my $bounceAddr = shift;
	my $headers = shift || {};
	my $body = shift;
	my $attachedFiles = shift;
	my $smtpServers = shift;

	#$body = encode_utf8($body) if utf8::is_utf8($body);

	my $smtp = $self->smtpHandle($smtpServers);
	return undef unless $smtp;
	return undef unless IF::Log::assert($smtp->mail($bounceAddr), "SMTP MAIL cmd failed.");
	return undef unless IF::Log::assert($smtp->recipient($to), "SMTP RCPT cmd failed for $to.");
	return undef unless IF::Log::assert($smtp->data(), "SMTP server refused DATA cmd.");
	return undef unless IF::Log::assert($smtp->datasend($headers), "Sending DATA.");
	if (@$attachedFiles) {
		my $boundary_separator = "";
	    # Create arbitrary boundary separator
	    my ($i, $number, @chrs);
	    foreach $number (48..57,65..90,97..122) { $chrs[$i++] = chr($number);}
	    foreach $number (0..20) {$boundary_separator .= $chrs[rand($i)];}
	    return undef unless IF::Log::assert($smtp->datasend("Content-Type: multipart/mixed; charset=utf-8; boundary=\"$boundary_separator\"\n"), "SMTP content type.");
		return undef unless IF::Log::assert($smtp->datasend("--$boundary_separator\nContent-type: text/plain; charset=utf-8\n"), "SMTP body content.");
		return undef unless IF::Log::assert($smtp->datasend("Content-Disposition: inline\n\n"), "SMTP body disp.");
		return undef unless IF::Log::assert($smtp->datasend("$body\n"), "SMTP MAIL body.");
		foreach my $fileNameWithPath (@$attachedFiles) {
			return undef unless IF::Log::assert(_attachFileFromFilePath($smtp, $fileNameWithPath, $boundary_separator), "Attaching File $fileNameWithPath	.");
		}
    } else {
	    	return undef unless IF::Log::assert($smtp->datasend("$body\n"), "SMTP MAIL body.");
    }
	return undef unless IF::Log::assert($smtp->dataend(), "SMTP server refused DATA end cmd.");

	return 1;
}

# TODO - rewrite this... I never really reviewed it and now that I'm
# looking at it, I see that it needs to be refreshed.  I am sure it can be almost
# wholly replaced with a module from CPAN or something.

sub _attachFileFromFilePath {
    my ($smtp, $fileNameWithPath, $boundary_separator) = @_;

    my ($bytesread, $buffer, $data, $total, $fileHandle);

	unless (-f $fileNameWithPath) {
		IF::Log::dump("File to attach not found: $fileNameWithPath");
		return 0;
    }
	return 0 unless open($fileHandle, "$fileNameWithPath") ;

	binmode($fileHandle);
	while ( ($bytesread = sysread($fileHandle, $buffer, 1024))==1024 ){
		$total += $bytesread;
		$data .= $buffer;
	}
	if ($bytesread) {
		$data .= $buffer;
		$total += $bytesread ;
	}
	close $fileHandle;
	if ($data) {
		$smtp->datasend("--$boundary_separator\n");
		$smtp->datasend("Content-Type: application/octet-stream; name=\"$fileNameWithPath\"\n");
		$smtp->datasend("Content-Transfer-Encoding: base64\n");
		$smtp->datasend("Content-Disposition: attachment; =filename=\"$fileNameWithPath\"\n\n");
		$smtp->datasend(encode_base64($data));
		$smtp->datasend("\n");
	}
}

## NOTE:  subject may appear in a template
sub sendMailWithAttachments {
    my $self = shift;
	my $to = shift;

	if ($to =~ /,/) {
		my @addresses = split(',',$to);
		foreach my $singleTo (@addresses) {
			$singleTo =~ s/ //g;
			$self->sendMailWithAttachments($singleTo, @_);
		}
		return;
	}
	my $from = shift;
	my $subject = shift;
	my $body = shift;
	my $attachedFiles = shift;
	my $headers = shift;
	my $recipientType = shift;  # helps us classify bouncing mail
	my $bounceToFromAddress = shift; # deprecated
	my $smtpServers = shift; # optional

    if ($self->blockerClass()) {
        # This only makes sense if the blocker class implements emailIsBlocked...
        eval "use ".$self->blockerClass().";";
        if ($@) {
            IF::Log::debug($@);
        } else {
            my $isBlocked = eval $self->blockerClass().'->emailIsBlocked($to)';
            if ($@) {
                IF::Log::debug($@);
            }
            if ($isBlocked) {
                IF::Log::debug("$to is BLOCKED - ignoring");
                return undef;
            }
        }
    }
	$headers = {} unless $headers;

	return unless IF::Log::assert($self->emailAddressIsValid($to), "Valid To address");
	return unless IF::Log::assert($self->emailAddressIsValid($from), "Valid From address");

	my $bounceAddr = $self->application()->createBounceAddress($to, $from, $recipientType);

	# Stop embarrassing things happening in testing and staging:
    unless ($self->emailAddressIsSafe($to)) {
        IF::Log::debug("$to is UNSAFE, sending to administrator instead.");
        $to = $self->SITE_ADMINISTRATOR();
    }

	# Here we format the From: header to avoid spam detection.  hmm
	# TODO: this code probably belongs sowewhere else ?
	my $formattedFrom;
	if ($from =~ m/ /) {
		$formattedFrom = $from;
	} else {
		my ($fromName) = ($from =~ /^([\w\.\-]+)@/);
		$formattedFrom = ucfirst($fromName)." <$from> ";
	}

	$headers->{'To'} = $to;
	$headers->{'From'} = $formattedFrom;
	unless ($headers->{'Reply-To'} || $body =~ /Reply-To:/) {
	    $headers->{'Reply-To'} = $from;
    }
	$headers->{'Subject'} = $subject if (($subject) && ($subject ne ""));
#	$headers->{'Errors-To'} = $bounceAddr;
	$headers->{'Mime-Version'} = "1.0";

	# This helps us know the sender even if AOL or someone munges the headers
	$headers->{'X-IF-Sender'} = $from;

	if ($headers->{'Content-type'} ne 'multipart/mixed') {
		$headers->{'Content-type'} = 'text/plain' unless $headers->{'Content-type'};
		# set the character encoding
		unless ($headers->{'Content-type'} =~ /charset/i) {
			$headers->{'Content-type'} .= '; charset=utf-8';
		}
	}
	my $formattedHeaders = "";
	foreach my $k (keys %$headers) {
		$formattedHeaders .= "$k: ".$headers->{$k}."\n";
	}

	if ($self->sendMessageBySMTP($to, $bounceAddr, $formattedHeaders, $body, $attachedFiles, $smtpServers)) {
		IF::Log::info("Mail ($subject) sent to $to via SMTP\n");
		return 1;
	}

	# backup plan using sendmail
	# we're either here because we couldn't open a connection to the SMTP
	# server or because the transmission failed along the way
	my $SENDMAIL = $self->SENDMAIL();
	die "No SENDMAIL in application configuration" unless $SENDMAIL;

	return undef unless IF::Log::assert(
			open (MAIL, "| $SENDMAIL -t -f \"<$bounceAddr>\""),
			 "Problem talking to sendmail");

	print MAIL $formattedHeaders, $body;
	close (MAIL);
	IF::Log::debug("Mail ($subject) going out to $to by local delivery\n");
	return 1;
}

sub sendMail {
	my ($self, $to, $from, $subject, $body, $headers, $recipientType, $bounceToFromAddress, $smtpServers) = @_;
	$self->sendMailWithAttachments(
	        $to,
			$from,
			$subject,
			$body,
			[],
			$headers,
			$recipientType,,
			$bounceToFromAddress,
			$smtpServers,
    );
}

# TODO - implement this; it won't work at the moment.
#----------------------------------------------------
# This goop manages the mail queue.  In order to use this, you need to run the
# SQL patch that creates these tables.

sub createMailMessage {
	my $subject = shift;
	my $body = shift;
	my $contentType = shift;
	my $headers = shift;

	my $message = IF::MailQueue::Entity::MailMessage->new();
	$message->setSubject($subject);
	$message->setBody($body);
	$message->setContentType($contentType);
	$message->setHeaders($headers);
	$message->save();
	return $message;
}

sub addMailQueueEntry {
	my $to = shift;
	my $from = shift;
	my $message = shift;
	my $fieldValues = shift;
	my $sendDate = shift;
	my $mailEvent = shift;

	return unless $message;
	my $mailQueueEntry = IF::MailQueue::Entity::MailQueueEntry->new();
	$mailQueueEntry->setEmail($to);
	$mailQueueEntry->setSender($from);
	$mailQueueEntry->setFieldValues($fieldValues);
	$mailQueueEntry->setMailMessageId($message->id());
	$mailQueueEntry->setSendDate($sendDate);
	if ($mailEvent) {
		$mailQueueEntry->setMailEventId($mailEvent->id());
	}
	$mailQueueEntry->save('LATER');

	return $mailQueueEntry; #???
}

sub startMailJob {
	my $logMessage = shift;
	my $jobCreator = shift;

	my $mailEvent = IF::MailQueue::Entity::MailEvent->new();
	$mailEvent->setLogMessage($logMessage);
	$mailEvent->setCreatedBy($jobCreator);
	$mailEvent->save();

	# now add a "start" message
	my $mailQueueEntry = IF::MailQueue::Entity::MailQueueEntry->new();
	$mailQueueEntry->setEmail($mailEvent->createdBy());
	$mailQueueEntry->setSender();
	$mailQueueEntry->setSendDate(time);
	$mailQueueEntry->setMailEventId($mailEvent->id());
	$mailQueueEntry->setMailMessageId(0);
	$mailQueueEntry->setIsLastMessage(0);
	$mailQueueEntry->save();

	return $mailEvent;
}

sub endMailJob {
	my $mailEvent = shift;

	my $mailQueueEntry = IF::MailQueue::Entity::MailQueueEntry->new();
	$mailQueueEntry->setEmail($mailEvent->createdBy());
	$mailQueueEntry->setSender();
	$mailQueueEntry->setSendDate(time);
	$mailQueueEntry->setMailEventId($mailEvent->id());
	$mailQueueEntry->setMailMessageId(0);
	$mailQueueEntry->setIsLastMessage(1);
	$mailQueueEntry->save();
	return $mailQueueEntry;
}

sub emailAddressIsSafe {
    my $self = shift;
	my $address = shift;

	# here is where you check if it's ok to send random
	# email to this address (for testing, etc.)
	IF::Log::debug("Checking if $address is safe");
    return $self->application()->emailAddressIsSafe($address);
}

sub emailAddressIsValid {
    my $self = shift;
	my $address = shift;
	return $address =~ /^([A-Z0-9]+[._-]?)*[A-Z0-9]+\@(([A-Z0-9]+[-]?)*[A-Z0-9]+\.){1,}[A-Z]{2,}$/i;
}

sub responseForMailTemplateInContext {
    my $self = shift;
	my $templateName = shift;
	my $context = shift;

	my $templatePath = mailTemplatePath();
	unless ($templateName =~ /^$templatePath/) {
		$templateName = $templatePath."/".$templateName;
	}

	return $self->responseForResolvedMailTemplateInContext($templateName, $context);
}

# rewrite this to use the basic renderer
sub responseForResolvedMailTemplateInContext {
    my $self = shift;
	my $templateName = shift;
	my $context = shift;

	IF::Log::debug("responseForResolvedMailTemplateInContext(): templateName = ". $templateName);
	my $template = $context->siteClassifier()->bestTemplateForPathAndContext($templateName, $context);
	unless ($template) {
		IF::Log::error("Unable to locate mail message template $templateName");
		return;
	}
	my $response = IF::Response->new();
	$response->setTemplate($template);
	return $response;
}

# pass in the text source of the template
#  rather than a path to go looking for a template at
#  (used by the admin mailing tool)
sub responseForMailTemplateStringInContext {
    my $self = shift;
	my $templateString = shift;
	my $context = shift;
	my $template = IF::Template->new();
	$template->initWithStringInContext($templateString, $context);
	my $response = IF::Response->new();
	$response->setTemplate($template);
	return $response;
}

sub generateMessageInContext {
    my $self = shift;
	my $message = shift;
	my $context = shift;
	my $component = IF::Component->new();
	$component->appendToResponse($message, $context);
	IF::Log::debug($message->content());
	return $message->content();
}

sub mailTemplatePath {
    my $self = shift;
	return $self->application()->configurationValueForKey('MAIL_TEMPLATE_PATH');
}

sub blockerClass    { return $_[0]->{blockerClass}  }
sub setBlockerClass { $_[0]->{blockerClass} = $_[1] }

1;
