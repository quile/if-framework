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

package IF::Utility;

use strict;
use IF::GregorianDate;
use Time::Local;
use IF::Log;
use IF::Utility::Image;
use IF::I18N;
use HTML::Entities;
use URI::Escape ();
use Encode ();
use JSON;

#================================

sub evaluateExpressionInComponentContext {
	my ($expression, $component, $context, $options) = @_;
	$options = {} unless defined $options;
	return unless $component;
	#return unless $context; # context is no longer necessary for basic rendering.

	# To make sure the "eval" works correctly:
	my $self = $component;

	if ( expressionIsKeyPath($expression) ) {
		#		IF::Log::debug("Binding value is keypath");
		# since IF::Component assumes an eval has happened when in
		# this case it hasn't, silence any leaky eval errors
		undef $@ if $@;
		return $self->valueForKeyPath($expression);
	}
	my $returnValue = eval $expression;
	if ($@ && ! $options->{'quiet'}) {
		IF::Log::debug("evaluateExpressionInComponentContext: ($expression) $@") if $@;
		my ($package, $filename, $line) = caller();
		IF::Log::debug("called from: $package, $filename, $line");
	}
	return $returnValue;
}

sub expressionIsKeyPath {
	my $expression = shift;

	# trying out a more minimal approach to determining if an expression
	# is a key path:

	return 1 if ( $expression =~ /^[A-Za-z_\(\)]+[A-Za-z0-9_#\@\.\(\)\"]*$/o );
	return ( $expression =~ /^[A-Za-z_\(\)]+[A-Za-z0-9_#\@]*(\(|\.)/o );
#return ($expression =~ /^[A-Za-z0-9_#\@\(\,\ \)]+(\.[A-Za-z0-9_#\@\(\,\ \)]+)*$/);
}

#----------------------------------
# perl date utilities are really
# hoary so we need to build
# a consistent API
#----------------------------------

sub isLeapYear {
	my $year = shift;
	return ( ( $year % 4 == 0 ) && ( $year % 100 != 0 ) )
	  || ( $year % 400 == 0 );
}

sub dayOfWeekForDate {
	my $date = shift;
	my ( $sec, $min, $hour, $mday, $month, $year, $wday, $yday, $isdst ) =
	  localtime( unixTimeFromSQLDateAndTime( $date, "12:00:00" ) );
	IF::Log::debug( "MONTH: Day of week for $date ($mday, "
		  . ( $month + 1 ) . ", "
		  . ( $year + 1900 )
		  . ") is $wday" );
	return $wday;
}

sub startOfWeekForDate {
	my $date = shift;
	my $dow  = dayOfWeekForDate($date);

	#IF::Log::debug("MONTH: Start of week for $date (day $dow)");
	# we use noon instead of midnight for this calculation so that
	# daylight savings doesn't f**k us up
	my $unixTimeForDate = unixTimeFromSQLDate($date) + 3600 * 12;

	#IF::Log::debug("In is $date, out is ".scalar localtime($unixTimeForDate));
	my $startOfWeekAsUnixTime = $unixTimeForDate - ( $dow * 86400 );
	return sqlDateFromUnixTime($startOfWeekAsUnixTime);
}

# this is deprecated.  never use this if you can avoid it.. use a Date component instead
sub readableDateForUnixTime {
	my $unixTime = shift;
	my ( $sec, $min, $hour, $day, $month, $year ) = localtime($unixTime);
	return sprintf( "%02d/%02d/%04d", $month + 1, $day, $year + 1900 );
}

sub dateStringForUnixTimeInContext {
	my $unixTime = shift;
	my $context  = shift;
	return dateStringForUnixTime( $unixTime, $context ? $context->language() : undef );
}

sub dateStringForUnixTime {
	my $unixTime            = shift;
	my $languageDesignation = shift
	  || IF::Application->defaultApplication()->configurationValueForKey("DEFAULT_LANGUAGE");
	my ( $sec, $min, $hour, $day, $month, $year ) = localtime($unixTime);
	my $monthName = _s("MONTH_".($month + 1));
	return sprintf( "%s %02d, %04d", $monthName, $day, $year + 1900 );
}

sub timeStringInLanguageForSQLTime {
	my ($time, $language) = @_;
	# CSD - This was overriding what was passed in all the time...had a my...don't think this is used anymore, but fixed
	# it anyway.
	$language ||= IF::Application->defaultApplication()->configurationValueForKey("DEFAULT_LANGUAGE");
	my ($hour, $minute, $second) = split(":", $time);
	if ($language eq "en") {
		if ($hour >= 12) {
			if ($hour > 12) {
				$hour = $hour - 12;
			}
			return int($hour).":".$minute."pm";
		}
		return int($hour).":".$minute."am";
	} else {
		return $hour.":".$minute;
	}
}

#  calculate a unix time n days in the past
#  NOTE:  1 day = 24 hrs * 3600 sec = 86400
sub nDaysAgo {
	my $delta = shift;
	return ( time - $delta * 86400 );
}

sub unixTimeForLastMidnight {
	return midnightOf(time);
}

sub midnightOf {
	my $time = shift;
	my ( $sec, $min, $hour, $day, $month, $year ) = localtime($time);
	$time = timelocal( 0, 0, 0, $day, $month, $year );
	return $time;
}

sub unixTimeFromSQLDate {
	my $date = shift;
	return unixTimeFromSQLDateAndTime( $date, "00:00:00" );
}

sub sqlDateFromUnixTime {
	my $unixTime = shift;
	my ( $sec, $min, $hour, $mday, $mon, $year, $isdst ) = localtime($unixTime);
	return sprintf( "%04d-%02d-%02d", ( $year + 1900 ), ( $mon + 1 ), $mday );
}

sub sqlTimeFromUnixTime {
	my $unixTime = shift;
	my ( $sec, $min, $hour, $mday, $mon, $year, $isdst ) = localtime($unixTime);
	return sprintf( "%02d:%02d:%02d", $hour, $min, $sec );
}

sub sqlDateTimeFromUnixTime {
	my $unixTime = shift;
	return sqlDateFromUnixTime($unixTime) . " "
	  . sqlTimeFromUnixTime($unixTime);
}

sub unixTimeFromSQLDateAndTime {
	my $date = shift;
	my $time = shift;
	my ( $year, $month, $day ) = split( "-", $date );
	return if ( $month < 1 || $month > 12 );
	return if ( $day < 1   || $day > 31 );
	my ( $hour, $minute, $second ) = split( ":", $time );
	unless (IF::Log::assert($year > 1970 && $year < 2030, "year is reasonable")) { # this code better be replaced by then!
		return 0;
	}
	# I hope this code isn't still running in 2100!
	if ( $month == 2 && $day == 29 && ($year % 4) ) { $day = 28; }
	# It's SOOOO lame that I have to do this
	my $unixTime;
	eval {
	 	$unixTime =
			timelocal( $second, $minute, $hour, $day, $month - 1, $year - 1900 );
	};

	#	my $gmtime =  timegm($second, $minute, $hour, $day, $month-1, $year-1900);
	return $unixTime;
}

sub unixTimeFromSQLDateTime {
	my $dateTime = shift;
	return unless length($dateTime) >= 19;
	return unixTimeFromSQLDateAndTime( substr( $dateTime, 0, 11 ),
		substr( $dateTime, 11, 8 ) );
}

sub uriEscapedStringFromString {
	my $string = shift;
	if (Encode::is_utf8($string)) {
		return URI::Escape::uri_escape_utf8($string);
	} else {
		return URI::Escape::uri_escape($string);
	}
}

sub stringFromUriEscapedString {
	my $string = shift;
	return URI::Escape::uri_unescape($string);
}


sub stringFromQueryDictionary {
	my $qd = shift;

	my @keyValuePairs = ();
	foreach my $key ( sort keys %$qd ) {
		if ( IF::Array::isArray( $qd->{$key} ) ) {
			foreach my $value ( @{ $qd->{$key} } ) {
				push( @keyValuePairs,
					"$key=" . IF::Utility::uriEscapedStringFromString($value) );
			}
		}
		else {
			push( @keyValuePairs,
				"$key=" . IF::Utility::uriEscapedStringFromString( $qd->{$key} ) );
		}
	}
	return join( "&", @keyValuePairs );
}

sub fileTypeFromString {
	my $string = shift;

	return "gif" if ( $string =~ /^GIF/ );
	return "jpg" if ( $string =~ /......JFIF/i );
	return "jpg" if ( $string =~ /......Exif/i );
	return "bmp" if ( $string =~ /BMF/ );
	return "txt";
}

sub checksumForId {
	my $id         = shift;
	my $idAsString = $id . "";
	my $checksum   = "";
	for ( my $i = 0 ; $i < length($idAsString) ; $i++ ) {
		my $digit = int( substr( $idAsString, $i, 1 ) );
		$checksum = ( ( $digit * 7 ) % 10 ) . $checksum;
	}
	return ( $checksum % 333 );
}

sub externalIdFromId {
	my $id = shift;
	return $id . "-" . checksumForId($id);
}

# shouldn't this return undef if the checksums don't match? -kd
sub idFromExternalId {
	my $externalId = shift;
	return undef unless externalIdIsValid($externalId);
	my ( $id, $checksum ) = split( /-/, $externalId );
	return $id;
}

sub externalIdIsValid {
	my $externalId = shift;
	my ( $id, $checksum ) = split( /[^\d]+/, $externalId );
	my $realChecksum = checksumForId($id);
	return ( int($checksum) == int($realChecksum) );
}

# this is to look up methods at run time:

sub methodsInPackage {
	my ($class, $nodes) = @_;

	unless ($nodes) {
		$nodes = {};
	}

	return [] if ($nodes->{$class});

	my $methods = [];
	$nodes->{$class}++;
	{
		no strict 'refs';
		my @keys = sort keys %{"${class}::"};
		my @definedMethods = grep { defined &{ ${"${class}::"}{$_}} } @keys;

		foreach my $name (@definedMethods) {
			push (@$methods, $name);
		}

		# Find all the classes this one is a subclass of
		for my $name ( @{"${class}::ISA"} ) {
			push @$methods, @{methodsInPackage( $name, $nodes )};
		}
	}
	return $methods;
}

sub baseUrlInContext {
	my ($context) = @_;
	#return unless $context;
	my $application = $context ? $context->application() : IF::Application->defaultApplication();

	my $port   = $application->configurationValueForKey("SERVER_PORT") || 80;
	my $server = $application->configurationValueForKey("SERVER_NAME");

	my $url = "http://$server";
	if ($port != 80) {
		$url .= ":$port";
	}
	return $url;
}

sub urlForDefaultAdaptorInContext {
    my ($context) = @_;
	my $application = $context ? $context->application() : IF::Application->defaultApplication();
    IF::Log::debug("Context is $context");
	my $defaultAdaptorUrl = baseUrlInContext($context).
			$application->configurationValueForKey("URL_ROOT").
			'/'.
			($context ? $context->siteClassifier()->name() : $application->configurationValueForKey("DEFAULT_SITE_CLASSIFIER_NAME")).
			'/'.
			($context? $context->language() : $application->configurationValueForKey("DEFAULT_LANGUAGE"));

	return $defaultAdaptorUrl;
}

sub urlInContextForDirectActionOnComponentWithQueryDictionary {
	my ($context, $directActionName, $componentName, $qd) = @_;

	my $application = $context ? $context->application() : IF::Application->defaultApplication();

	# push important values into qd
	$componentName =~ s/::/\//g;  # Make sure it's in URL format, not classname format
    # unless ($qd->{$context->application()->sessionIdKey()} || $context->cookieValueForKey($context->application()->sessionIdKey())) {
    #   $qd->{$context->application()->sessionIdKey()} = $context->session()->externalId();
    # }
	unless ($directActionName) {
		$directActionName = $application->configurationValueForKey("DEFAULT_DIRECT_ACTION");
	}
	my $url = join("/",
			urlForDefaultAdaptorInContext($context),
			$componentName,
			$directActionName);
	return $url."?".IF::Utility::stringFromQueryDictionary($qd);
}

sub escapeHtml {
	my ($value) = @_;
	return HTML::Entities::encode_entities($value);
}


# These are very useful, but pretty rough and tumble.

sub isValidEmailAddress {  # TODO: probably wants to reside on IF
	my $email = shift;
	return 0 if ($email =~ /\s/);
	return 0 if ($email =~ /[\,\:\;\/]/);
	return 0 if ($email !~ /[\@].+\..+$/);
	return 1 if ($email =~ /^[^@ ]+\@[^@ ]*[A-Za-z]$/);
	return 0;
}

sub isValidEmailAddressList {  # TODO: probably wants to reside on IF
	my $emailList = shift;
	foreach my $address (split(/[\s,]+/, $emailList)) {
		return 0 unless (isValidEmailAddress($address));
	}
	return 1;
}

sub isValidURL {  # TODO: probably wants to reside on IF
	my $url = shift;
	return 0 if ($url =~ /\s/);
	return 0 unless ($url =~ /\./);
	return 1 if ($url eq "");
	return 1 if ($url =~ /^https?:\/\//);
	return 0;
}

sub formattedHtmlFromText {
	my $text = shift;
	$text =~ s/\n/<br>\n/g;
	return enableEmailAddressesInHtmlChunk(enablePlainUrlsInHtmlChunk($text));  # TODO: hmm .. these operate on HtmlChunk's ?
}

sub formattedHtmlFromHtmlChunk {
	my ($text) = @_;
	$text =~ s/\r\n/\n/g;
	$text =~ s/(<.+?>)/substituteNewlinesWithSpacesInString($1)/ge;
	$text =~ s/\n\n/<p>/g;
	return enableEmailAddressesInHtmlChunk(enablePlainUrlsInHtmlChunk($text));
}

sub substituteNewlinesWithSpacesInString {
	my ($string) = @_;
	$string =~ s/\n/ /g;
	return $string;
}

sub enablePlainUrlsInHtmlChunk {
	my ($text) = @_;
	$text =~ s/(?<!["'])(https?:\/\/[^ \n\r\t<]+\b)/<a href="$1">$1<\/a>/gi;
	return $text;
}

sub enableEmailAddressesInHtmlChunk {
	my ($text) = @_;
	# TODO: fix this! only one email address per line right now... 	 (??)
	$text =~ s/([^\s<>]+?\@(\S+?\.)+[A-Za-z]+)/<a href=\"mailto:$1\">$1<\/a>/gi;
	return $text;
}

sub _deprecated_enableEmailAddressesInPlainText {  # use *InHtmlChunk() version instead..
	my $plaintext = shift;
	# TODO: fix this! only one email address per line right now...
	$plaintext =~ s/(\S+?\@(\S+?\.)+[A-Za-z]+)/<a href=\"mailto:$1\">$1<\/a>/g; #"
	return $plaintext;
}

sub highlightKeywordsInString {
	my $keywords = shift;
	my $string = shift;
	foreach my $keyword (@$keywords) {
		next unless $keyword =~ /\w/i;
		$string =~ s/\b($keyword)\b/<span class='highlighted-keyword'>$1<\/span>/ig;
	}
	return $string;
}

sub stringWithTagsRemoved {
	my $string = shift;
	$string =~ s/<[^>]*>//g;
	$string =~ s/\&[^;]+;//g;
	return $string;
}

# can only load files from the project root or lower
sub contentsOfFileAtPath {
	my $path = shift;
	return unless $path;
	return if $path =~ /\.\./;
	$path = safePathFromPath($path);
	my $contents;
	if (open (FILE, $path)) {
		$contents = join("", <FILE>);
		close (FILE);
	}
	return $contents;
}

sub safePathFromPath {
	my $path = shift;
	my $projectRoot = IF::Application->defaultApplication()->configurationValueForKey("APP_ROOT");
	if ($path =~ /^\//) {
		$path = $projectRoot.$path unless ($path =~ /^$projectRoot/);
	} else {
		$path = $projectRoot."/".$path;
	}
	return $path;
}


sub quoteReplyWithQuoteStringAndWidth {
	my $reply = shift;
	my $quoteString = shift || IF::Application->defaultApplication()->configurationValueForKey("DEFAULT_QUOTE_STRING");
	my $width = shift || IF::Application->defaultApplication()->configurationValueForKey("DEFAULT_REPLY_WIDTH");

	my $newLines = [];

	$reply =~ s/\n\r/\n/g;
	$reply =~ s/\r\n/\n/g;
	$reply =~ s/\r/\n/g;
	my @oldLines = split(/\n/, $reply);
	#IF::Log::dump(\@oldLines);
	foreach my $line (@oldLines) {
		if (length($line) < ($width-length($quoteString)-1)) {
			push (@$newLines, "$quoteString $line");
			next;
		}
		my $newLine = "";
		my @words = split(" ", $line);
		foreach my $word (@words) {
			if (length($newLine) + length($word) < ($width-length($quoteString)-1)) {
				$newLine .= "$word ";
			} else {
				push (@$newLines, "$quoteString $newLine");
				$newLine = "$word ";
			}
		}
		# leftovers
		if ($newLine ne "") {
			push (@$newLines, "$quoteString $newLine");
		}
	}
	return join("\n", @$newLines);
}

sub formatTextForWidth {
	my $text = shift;
	my $width = shift;
	# HACK!
	my $string = quoteReplyWithQuoteStringAndWidth($text, "H*CK", $width);
	$string =~ s/H\*CK //g;
	return $string;
}

sub stringsDifferByMoreThanWhitespace {
	my $a = shift;
	my $b = shift;

	$a =~ s/[ \t\r\n]//g;
	$b =~ s/[ \t\r\n]//g;

	return ($a ne $b);
}

sub addCommasToNumber {
	my $n = shift;
	my $s = "". $n;
	$s = reverse $s;
	$s =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
	return scalar reverse $s;
}

sub jsonFromObjectAndKeys {
    my ($object, $keys, $mappedKeys) = @_;
    my $r = ref($object);
    return to_json($object, {utf8 => 1, allow_nonref => 1}) unless ($object && $r);
    if (ref($object) eq "ARRAY") {
        # for an array, it evaluates the keys on each object in the array.
        my $jsonObjects = [];
        foreach my $o (@$object) {
            push @$jsonObjects, jsonFromObjectAndKeys($o, $keys);
        }
        return "[".join(", ", @$jsonObjects)."]";
    }
    if (!$keys) {
        if ($r eq "HASH") {
            return to_json($object, {utf8 => 1});
        }
        # what do we do with an object?
        # if it's an IF::Entity, let's return its stored values
        if (UNIVERSAL::isa($object, "IF::Entity") && $object->can("entityClassDescription")) {
            $keys = $object->entityClassDescription()->allAttributeNames();
        }
        # what else here?
    }
    my $d = {};
    if (!UNIVERSAL::isa($object, "IF::Interface::KeyValueCoding")) {
        $object = IF::Dictionary->new($object); # ?
    }
    foreach my $key (@$keys) {
        my $mk = $mappedKeys->{$key} || $key;
        $d->{$mk} = $object->valueForKey($key)."";
    }
    return to_json($d, {utf8 => 1});
}

1;
