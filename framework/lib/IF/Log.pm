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

package IF::Log;
#==================================
# This class is used to accumulate
# and output logging information,
# mostly used for debugging.
#==================================

use strict;
use Time::HiRes;
use IF::LogMessage;
use Data::Dumper;

# Message codes:
my $CODE_HEADER     = 0;
my $CODE_DATABASE    = 1;
my $CODE_DEBUG        = 2;
my $CODE_APACHE     = 4;
my $CODE_INFO         = 8;
my $CODE_WARNING    = 16;
my $CODE_ERROR         = 32;
my $CODE_CODE       = 64;
my $CODE_STRUCTURE  = 128;
my $CODE_QUERY_DICTIONARY = 256;
my $CODE_ASSERTION  = 512;

# traceback codes
my $SHOW_PACKAGE    = 8192;
my $SHOW_METHOD        = 16384;
my $SHOW_LINE        = 32768;

my %MESSAGE_TYPES = (
        $CODE_DATABASE => "DATABASE",
        $CODE_DEBUG => "DEBUG",
        $CODE_APACHE => "APACHE",
        $CODE_INFO => "INFO",
        $CODE_WARNING => "WARNING",
        $CODE_ERROR => "ERROR",
        $CODE_CODE => "CODE",
        $CODE_STRUCTURE => "PAGE",
        $CODE_QUERY_DICTIONARY => "QUERY_DICTIONARY",
        $CODE_ASSERTION => "ASSERTION",
        );

my %MESSAGE_COLOURS = (
        $CODE_HEADER    => ["#aaaacc", "#000020" ],
        $CODE_DATABASE  => ["#cccccc", "#000000" ],
        $CODE_DEBUG     => ["#ffff60", "#000000" ],
        $CODE_APACHE    => ["#60ffff", "#000000" ],
        $CODE_INFO      => ["#ff60ff", "#ffffff" ],
        $CODE_WARNING   => ["#ffff00", "#ff0000" ],
        $CODE_ERROR     => ["#ff0000", "#ffff00" ],
        $CODE_CODE      => ["#000000", "#ffffff" ],
        $CODE_STRUCTURE => ["#3030ff", "#ffffff" ],
        $CODE_QUERY_DICTIONARY => ["#004000", "#ffffff" ],
        $CODE_ASSERTION => ["#00ff00", "#ffff00"],
        );

# This is a static class

my $LOG_MASK = 0x0000;    # Everything off
my $_pageStructureDepth = 0;

# This will be filled per web transaction but will be flushed
# at the beginning of each one
my $MESSAGE_BUFFER = [];

my $START_TIME = 0;

#====================================
# static methods to manipulate the
# members of the class. Remember
# that each Apache child is single-
# threaded so a whole transaction is
# atomic
#====================================
sub setLogMask {
    $LOG_MASK = shift;
}

sub logMask {
    return $LOG_MASK;
}

sub addMessage {
    my $message = shift;

    # print it out if the log is set or message is an error
    if ($LOG_MASK & $message->type() || $message->type() == $CODE_ERROR) {
        print STDERR $message->time()." ".$MESSAGE_TYPES{$message->type()}." ".$message->content()."\n";

        # log it into the buffer
        push (@$MESSAGE_BUFFER, $message);
    }
}

sub incrementPageStructureDepth {
    $_pageStructureDepth++;
}

sub decrementPageStructureDepth {
    $_pageStructureDepth--;
}

sub startLoggingTransaction {
    $START_TIME = [Time::HiRes::gettimeofday];
    clearMessageBuffer();
    addMessage(IF::LogMessage->new($CODE_INFO, "======================================="));
}

sub endLoggingTransaction {
    my $elapsedTime = Time::HiRes::tv_interval($START_TIME);
    addMessage(IF::LogMessage->new($CODE_INFO, "Total elapsed time: $elapsedTime seconds"));
    addMessage(IF::LogMessage->new($CODE_INFO, "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^\n"));
}

sub messageBuffer {
    return $MESSAGE_BUFFER;
}

sub clearMessageBuffer {
    $MESSAGE_BUFFER = [];
}

sub htmlOpenTable {
    my $dumpMask = shift;
    return "<table width=100% cellpadding=1 cellspacing=0 border=0>\n".
                        "<tr><td bgcolor=#000000>\n".
                        "<table width=100% cellpadding=2 cellspacing=1 border=0>\n";
}

sub htmlCloseTable {
    my $dumpMask = shift;
    return "</table>\n</td></tr>\n</table>";
}

sub htmlColumnHeaders {
    my $dumpMask = shift;
    my $messageTable = "<tr><td align=center bgcolor=#333300><font face=Verdana size=2 color=#ffffff>TIME/TYPE</font></TD>";
    if ($dumpMask & $SHOW_LINE) {
        $messageTable .= "<TD align=center bgcolor=#333300><font face=Verdana size=2 color=#ffffff>P::M::L</font></TD>";
    } elsif ($dumpMask & $SHOW_METHOD) {
        $messageTable .= "<TD align=center bgcolor=#333300><font face=Verdana size=2 color=#ffffff>P::M</font></TD>";
    } elsif ($dumpMask & $SHOW_PACKAGE) {
        $messageTable .= "<TD align=center bgcolor=#333300><font face=Verdana size=2 color=#ffffff>PACKAGE</font></TD>";
    }

    $messageTable .= "<TD align=center bgcolor=#333300><font face=Verdana size=2 color=#ffffff>MESSAGE</font></TD></TR>";
    return $messageTable;
}

sub htmlRowFromLogEvent {
    my $dumpMask = shift;
    my $message = shift;
    my $rowColor = $MESSAGE_COLOURS{$message->type()}->[0];
    my $textColor = $MESSAGE_COLOURS{$message->type()}->[1];

    my $row = "<tr>\n<td style=\"background-color: $rowColor;\" nowrap>".$message->time()."<br>";
    $row .= $MESSAGE_TYPES{$message->type()}."</td>\n";
    if ($dumpMask & $SHOW_LINE) {
        $row .= "<td style=\"background-color: $rowColor;\" valign=top>"
                .$message->callerMethod()."::".$message->callerLine()."</td>\n";
    } elsif ($dumpMask & $SHOW_METHOD) {
        $row .= "<td style=\"background-color: $rowColor;\">"
                .$message->callerMethod()."</td>\n";
    } elsif ($dumpMask & $SHOW_PACKAGE) {
        $row .= "<td style=\"background-color: $rowColor;\">"
                .$message->callerPackage()."</td>\n";
    }
    $row .= "<td style=\"background-color: $rowColor;\">";
    if ($message->depth() == 0) {
        $row .= $message->formattedMessage();
    } else {
        $row .= "<table><tr>";
        for (my $i=0; $i<$message->depth(); $i++) {
            $row .= "<td>&nbsp;&nbsp;&nbsp;</td>";
        }
        $row .= "<td>".$message->formattedMessage()."</td></tr></table>";
    }
    $row .= "</td></tr>\n";
    return $row;
}

sub formatAsHtml {
    my $dumpMask = shift;

    # faster to just generate HTML here

    my $messageTable = "";
    $messageTable .= htmlOpenTable($dumpMask);
    $messageTable .= htmlColumnHeaders($dumpMask);

    foreach my $message (@$MESSAGE_BUFFER) {
        next unless ($dumpMask & $message->type());
        $messageTable .= htmlRowFromLogEvent($dumpMask, $message);
    }
    $messageTable .= htmlCloseTable($dumpMask);
    return $messageTable;
}

sub dumpLogForRequestUsingLogMask {
    my $request = shift;
    my $logMask = shift;
    my $messageTable = formatAsHtml($logMask);
    $request->print($messageTable);
    $messageTable = undef;
}

sub debug {
    my @messages = @_; # allow multiple arguments
    foreach my $message (@messages) {
        my $logMessage = IF::LogMessage->new($CODE_DEBUG, $message, $_pageStructureDepth, [caller()]);
        addMessage($logMessage);
    }
}

sub dump {
    my @objects = @_; # allow a variable number of args
    return unless ($LOG_MASK & $CODE_DEBUG); # short circuit this because it's expensive!
    foreach my $object (@objects) {
        if (ref($object)) {
            debug(Data::Dumper->Dump([$object], [qw(object)]));
        } else {
            debug($object); # print it as a string if it's just a scalar
        }
    }
}

sub page {
    my $message = shift;
    addMessage(IF::LogMessage->new($CODE_STRUCTURE, $message, $_pageStructureDepth));
}

sub stack {
    my $maxFrames = shift;
    my $trace = __PACKAGE__->getStackTrace($maxFrames);
    foreach my $f (@$trace) {
        debug($f);
    }
}

sub info {
    my $message = shift;
    my $logMessage = IF::LogMessage->new($CODE_INFO, $message, $_pageStructureDepth, [caller()]);
    addMessage($logMessage);
}

sub database {
    my $message = shift;
    my $logMessage = IF::LogMessage->new($CODE_DATABASE, $message, $_pageStructureDepth, [caller()]);
    addMessage($logMessage);
}

sub apache {
    my $message = shift;
    my $logMessage = IF::LogMessage->new($CODE_APACHE, $message, $_pageStructureDepth);
    addMessage($logMessage);
}

sub error {
    my $message = shift;
    my $logMessage = IF::LogMessage->new($CODE_ERROR, $message, $_pageStructureDepth, [caller()]);
    addMessage($logMessage);
}

sub assert {
    my $assertion = shift;
    my $message = shift;
    unless ($assertion) {
        my $logMessage = IF::LogMessage->new($CODE_ASSERTION, "ASSERTION FAILED: $message", $_pageStructureDepth, [caller()]);
        addMessage($logMessage);
    }
    return $assertion;
}

sub warning {
    my $message = shift;
    my $logMessage = IF::LogMessage->new($CODE_WARNING, $message, $_pageStructureDepth, [caller()]);
    addMessage($logMessage);
}

sub code {
    my $message = shift;
    my $logMessage = IF::LogMessage->new($CODE_CODE, $message, $_pageStructureDepth);
    addMessage($logMessage);
}

sub logMaskFromContext {
    return 0xffff;
}

sub logQueryDictionaryFromContext {
    my $context = shift;
    return unless ($LOG_MASK & $CODE_QUERY_DICTIONARY); # short circuit this because it's expensive!
    my $queryDictionary = IF::Context::queryDictionary($context); # need to make sure this is called even for subclasses
    foreach my $key (keys %$queryDictionary) {
        my $value = $queryDictionary->{$key};
        if (IF::Array::isArray($value)) {
            $value = join(", ", @$value);
        }
        my $logMessage = IF::LogMessage->new($CODE_QUERY_DICTIONARY, "$key = $value", $_pageStructureDepth);
        addMessage($logMessage);
    }
}

# Class method

sub getStackTrace {
    my $className = shift;
    my $maxFrames = shift || 99;
    my @trace;
    my $i=0;
    while ($i < $maxFrames) {
        my ($pack,$file,$number,$sub) = caller($i) or last;
        push @trace, sprintf "%02d| \&$sub called at $file line $number",$i++;
    }
    return \@trace;
}

1;
