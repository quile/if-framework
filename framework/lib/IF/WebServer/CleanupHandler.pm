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

package IF::WebServer::CleanupHandler;

use strict;
use vars qw($VERSION);
use IF::DB;

$VERSION = '1.00';

BEGIN {
    use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and
                            $ENV{MOD_PERL_API_VERSION} >= 2 );
    sub handler_mp2 : method { my ($className, $r) = @_; return $className->handler_mp1($r);  }
    *handler = MP2 ? \&handler_mp2 : \&handler_mp1;

    if (MP2) {
        eval "use Apache2::Const qw(:common);";
    } else {
        eval "use Apache::Constants qw(:common)";
    }
    IF::Log::error("loading apache constants: $@") if $@;
}

sub handler_mp1 ($$) {
    my ($className, $r) = @_;

    # get the context for this request and then destroy our pnotes reference to it
    my $context = $r->pnotes("context");
    IF::Log::debug($context);
    if ($context) {
        $context->setTransactionValueForKey(undef, "context");
    } else {
        return DECLINED;
    }

    # allow the application to perform specific cleanup:
    my $application = $context->application();
    if ($application) {
        $application->cleanUpTransactionInContext($context);
    }

    # Process any cleanup that we have been instructed to do
    my $cleanupRequests = $context->transactionCleanupRequests();
    foreach my $cr (@$cleanupRequests) {
        if (ref($cr) eq "CODE") {
            IF::Log::debug("CLEANUP: Executing code reference cleanup request");
            $cr->($context);
        }
    }
    $context->setTransactionValueForKey(undef, "_cleanupRequests");
    if (scalar @$cleanupRequests) {
        # we have to resave the session in case the cleanup requests used it
        $context->session()->save();
    }
    IF::ObjectContext->new()->clearCachedEntities();
    IF::Log::clearMessageBuffer();
    return DECLINED;
}

1;
