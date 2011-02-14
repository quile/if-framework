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

#============================================
# IF::WebServer::TransHandler
# This is the mod_perl handler that checks
# if an incoming URL needs to be mapped
# to a full app url
#============================================

package IF::WebServer::TransHandler;

use strict;
#====================================
use IF::Log;
use IF::Application;
use IF::Request ();

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
    my ($className, $req) = @_;
    IF::Log::debug("=====================> Transhandler invoked");

    my $r = IF::Request->new($req);

    my $app = IF::Application->applicationInstanceWithName($r->applicationName());
    return DECLINED unless IF::Log::assert($app, "Retrieved app instance for request");

    my $url = $r->uri();
    foreach my $module (@{$app->modules()}) {
        IF::Log::debug("Passing $url to module $module");

        # TODO implement caching here

        my ($rewrittenUrl, $rewrittenArgs) = $module->urlFromIncomingUrl($url);
        if ($rewrittenUrl ne $url) {
            IF::Log::debug("Rewriting as $rewrittenUrl ($rewrittenArgs) -> redirecting");
            $r->uri($rewrittenUrl);
            $r->args($rewrittenArgs) if $rewrittenArgs;
            # in mod_perl2 this prevents apache from running the
            # MapToStorage phase and saves a bunch of cycles.
            $r->filename("TransHandler-N/A");
            return OK;
        }
    }

    # Small optimization ... if we know this url is going to be
    # handled by the big IF handler, we can give it a bogus
    # filename and avoid the map to storage grind
    my $defaultPrefix = $r->dir_config('IFDefaultPrefix');
    if ($url =~ /^$defaultPrefix/) {
        $r->filename("TransHandler-N/A");
        return OK;
    }

    IF::Log::debug("No need to rewrite incoming URL");
    return DECLINED;
}


1;
