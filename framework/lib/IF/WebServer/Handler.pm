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
# IF::WebServer::Handler
# This is the mod_perl handler to provide
# access to the IF modules
#============================================

package IF::WebServer::Handler;

use strict;
use vars qw($TRACE);
#====================================
use IF::Context;
use IF::Log;
use IF::Request;
use IF::Constants;
use IF::I18N;

# get rid of this... just temporary
my $logMask;
my $_componentNamespace;

my $SESSION_STATUS_MESSAGES_KEY = "__statusMessages";

BEGIN {
    use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and
                            $ENV{MOD_PERL_API_VERSION} >= 2 );
    use constant MP1 => ( not exists $ENV{MOD_PERL_API_VERSION} and
                            $ENV{MOD_PERL} );
    sub handler_mp2 : method { my ($className, $r) = @_; return $className->handler_mp1($r);  }
    *handler = MP2 ? \&handler_mp2 : \&handler_mp1;

    if (MP2) {
        eval "use Apache2::Const qw(:common)";
    } elsif (MP1) {
        eval "use Apache::Constants qw(:common)";
    } else {
        use constant OK => "OK";
        use constant NOT_FOUND => "NOT_FOUND";
        use constant DECLINED => "DECLINED";
        use constant SERVER_ERROR => "SERVER_ERROR";
    }
    IF::Log::error("loading apache constants: $@") if $@;
}

sub componentNamespaceInContext {
    my ($className, $context) = @_;
    unless ($_componentNamespace) {
        $_componentNamespace = $context->application()->configurationValueForKey("DEFAULT_NAMESPACE")."::Component::";
    }
    return $_componentNamespace;
}

sub contextForRequest {
    my ($className, $r) = @_;
    my $context = IF::Context->contextForRequest($r);
    return undef unless $context;

    # reinflate any saved status messages
    my $session = $context->session();
    my $statusMessages = $session->sessionValueForKey($SESSION_STATUS_MESSAGES_KEY);
    if ($statusMessages && scalar @$statusMessages) {
        $context->setStatusMessages($statusMessages);
        $session->setSessionValueForKey(undef, $SESSION_STATUS_MESSAGES_KEY);
    }
    return $context;
}

sub startLoggingTransactionInContext {
    my ($className, $context) = @_;

    IF::Log::startLoggingTransaction($context->request());
    #$logMask = IF::Log::logMaskFromContext($context, $context->request());
    $logMask = 0;
    IF::Log::logQueryDictionaryFromContext($context); # this will only log the qd if the mask is set to log it
}

# this now takes into account the hierarchy of site classifiers
#
#  the former version defaulted to instantiating IF::Component
#  directly.  I may be missing the reason for that.  It seems
#  like it would just propagate the error later in the code.
#  I've removed it, but we can easily add it back in.
sub targetComponentForContext {
    my ($className, $context) = @_;

    my $targetComponentName = $context->targetComponentName();
    my $siteClassifier      = $context->siteClassifier();

    return $siteClassifier->componentForNameAndContext(
                            $targetComponentName, $context);
}

sub responseForComponentInContext {
    my ($className, $component, $context) = @_;
    return IF::Component::__responseFromContext($context);
}

sub allowComponentToTakeValuesFromRequest {
    my ($className, $component, $context) = @_;
    # allow component to process incoming data
    IF::Log::error("$$ >>>>>>>>>>>>>>>> takeValuesFromRequest()");
    # This is a temporary hack to expose the context to the underlying
    # component machinery.  It's pointless insofar as the context is
    # passed in here; the problem is that there is legacy code that
    # expects to be able to find the context in self.context, and it
    # won't be set unless we push it in here:
    $component->{_context} = $context;
    $component->takeValuesFromRequest($context);
    IF::Log::error("$$ <<<<<<<<<<<<<<<< takeValuesFromRequest()");
}

sub actionResultFromComponentInContext {
    my ($className, $component, $context) = @_;
    IF::Log::error("$$ >>>>>>>>>>>>>>>> direct action [".$context->directAction()."]");
    my $result = $component->invokeDirectActionNamed($context->directAction(), $context);
    IF::Log::error("$$ <<<<<<<<<<<<<<<< direct action");
    return $result;
}

sub allowComponentToAppendToResponseInContext {
    my ($className, $component, $response, $context) = @_;
    IF::Log::error("$$ >>>>>>>>>>>>> appendToResponse() [ $component ]");
    my $result = $component->appendToResponse($response, $context);

    # Send out the most recent session id as a cookie:
    unless ($context->session()->isNullSession()) {
        #IF::Log::debug("Dropping big session turd... external id is ".$context->session()->externalId());
        $context->setSessionCookieValueForKey($context->session()->externalId(), $context->application()->sessionIdKey());
    }

    IF::Log::error("$$ <<<<<<<<<<<<< appendToResponse()");
    return $result;
}

sub handler_mp1 ($$) {
    my ($className, $r) = @_;
    my $context;
    my ($ERROR_CODE, $ERROR_MSG);

    IF::Log::debug("=====================> Main handler invoked");

    eval {
        local $SIG{__DIE__} = \ &show_trace;

        # generate a context for this request
        $context = $className->contextForRequest(IF::Request->new($r));
        unless ($context) {
            $ERROR_MSG = "Malformed URL: Failed to instantiate a context for request ".$r->uri();
            $ERROR_CODE = NOT_FOUND;
            return;
        }

        # figure out what app and instance this is
        my $application = $context->application();
        unless ($application) {
            $ERROR_MSG = "No application object found for request ".$r->uri();
            $ERROR_CODE = NOT_FOUND;
            return;
        }

        # Initialise the logging subsystem for this transaction
        $className->startLoggingTransactionInContext($context);

        # Set the language for this transaction so the I18N methods
        # use the right strings.
        IF::I18N::setLanguage($context->language());

        # figure out which component we're going to be running with
        my $component = $className->targetComponentForContext($context);
        unless ($component) {
            $ERROR_MSG = "No component object found for request ".$r->uri();
            $ERROR_CODE = NOT_FOUND;
            return;
        }
        IF::Log::error("$$ - ".$context->urlWithQueryString());

        # we need to grok the response at this point because we need to import the
        # bindings that are explicitly defined in the HTML (which happens in rare cases)
        # to give them a chance to responde to takeValuesFromRequest().  However,
        # this seems a little extreme since it's a feature that's infrequently
        # used.  More thought is required.
        #my $response = $className->responseForComponentInContext($component, $context);
        my $response;

        # process explicit bindings from the template file
        #$component->addExplicitBindingsFromTemplateInResponse($response);

        # just before append to response begins, push the CURRENT request's
        # sid into the query dictionary in case any component (like AsynchronousComponent)
        # decides to fish around in there to build urls
        $context->queryDictionary()->{$context->application()->sessionIdKey()} = $context->session()->externalId();

        $className->allowComponentToTakeValuesFromRequest($component, $context);

        my $actionResult = $className->actionResultFromComponentInContext($component, $context);

        # if we have a result from the action, set the component and the response
        # to be the appropriate objects
        if ($actionResult) {
            if (UNIVERSAL::isa($actionResult, "IF::Component")) {
                IF::Log::debug("Action returned a component $actionResult");
                $component = $actionResult;
                my $componentName = $component->componentNameRelativeToSiteClassifier();
                my $templateName = IF::Component::__templateNameFromComponentName($componentName);
                $response = IF::Response->new();
                my $template = $context->siteClassifier()->bestTemplateForPathAndContext($templateName, $context);
                $response->setTemplate($template);
            } elsif (UNIVERSAL::isa($actionResult, "IF::Response")) {
                # action returned a response; we have to assume it's fully populated and return it
                $response = $actionResult;
            } else {
                return $className->redirectBrowserToAddressInContext($actionResult, $context);
            }
        } else {
            $response = $className->responseForComponentInContext($component, $context);
        }

        # now we have $component and $response, no matter what the results of
        # the action were.
        if ($actionResult != $response) {
            my $responseResult = $className->allowComponentToAppendToResponseInContext($component, $response, $context);
            if ($responseResult) {
                return $className->redirectBrowserToAddressInContext($responseResult, $context);
            }
        }

        # This sends the generated response back to the client:
        $className->returnResponseInContext($response, $context);

        if ($logMask) {
            IF::Log::endLoggingTransaction();
            IF::Log::dumpLogForRequestUsingLogMask($r, $logMask);
        }
    };

    if ($ERROR_CODE) {
        IF::Log::debug($ERROR_MSG);
        return $ERROR_CODE;
    }
    if ($@) {
        if ($TRACE) {
            generateServerErrorPageForErrorInContextWithRequest($TRACE, $context, $r);
        } else {
            generateServerErrorPageForErrorInContextWithRequest($@, $context, $r);
        }
        IF::Log::clearMessageBuffer();
    } else {
        return OK;
    }
}

sub didRenderInContext {
    my ($className, $context) = @_;

    $context->session()->save() unless $context->session()->isNullSession(); # no need to save a null session
    $context->setTransactionValueForKey($context, "context"); # push itself into the pnotes
    IF::Log::clearMessageBuffer(); # just make sure it's empty
}

sub redirectBrowserToAddressInContext {
    my ($className, $redirect, $context) = @_;

    # save any status messages to be relayed on the next request.  We have to
    # do it here before didRenderInContext is called, because that will
    # persist the session.
    my $statusMessages = $context->statusMessages();
    if (scalar @$statusMessages) {
        $context->session()->setSessionValueForKey($statusMessages, $SESSION_STATUS_MESSAGES_KEY);
    }

    # This is a bit of a cheat; if the redirect is actually code, execute it.
    # This allows us to pass things off to Apache if we really have to.
    if (ref($redirect) eq "CODE") {
        $className->didRenderInContext($context);
        return $redirect->($context);
    }

    $className->didRenderInContext($context);

    my $r = $context->request();

    $r->content_type($context->contentType());

    my $serverHostName = $context->application()->configurationValueForKey('SERVER_NAME');
    my $serverPort = $context->application()->configurationValueForKey('SERVER_PORT');
    if ($serverPort != 80) {
        $serverHostName .= ":".$serverPort;
    }
    if ($redirect !~ /^https?:\/\/|mailto:/) {
        $redirect = "http://".$serverHostName.$redirect;
    }

    my $cookieHeader = $r->headers_out->{'Set-Cookie'};
    IF::Log::debug("Forcing redirect to $redirect");
    # And make sure that the m#!$@rfracking dumbass
    # AOL cache doesn't store the wrong redirect
    # (hence the Cache-Control: no-store)
    if ($cookieHeader ne "") {
        $r->send_cgi_header(<<EOH1);
Set-Cookie: $cookieHeader
EOH1
    }
    $r->send_cgi_header(<<EOH);
Status: 303 Redirect
Content-type: text/html
Location: $redirect
URI: $redirect
Cache-Control: no-store

EOH

    return OK;
}

sub returnResponseInContext {
    my ($className, $response, $context) = @_;

    $className->didRenderInContext($context);

    my $r = $context->request();
    my $contentType = $response->contentType() || $context->contentType();
    $r->content_type($contentType);
    # allow a page to specify an error code via the context
    if ($context && $context->responseCode()) {
        #print STDERR "Response code: ".$context->responseCode(). " from context";
        $r->status($context->responseCode());
    }
    if ($context && $context->cacheControlMaxAge()) {
        my $cacheControl = "max-age=".$context->cacheControlMaxAge();
        #print STDERR "Cache-Control: $cacheControl from context\n";
        $r->headers_out->{'Cache-Control'} = $cacheControl;
        # never set cookies on pages that will be cached remotely
        my $headers = $r->err_headers_out();
        $headers->unset("Set-Cookie");
    } else {
        $r->headers_out->{'Cache-Control'} = "no-store";
    }

    $r->headers_out->{'Cache-Type'} = "text/html; charset=utf-8" unless $context->contentType();
    if (MP1) {
        $r->send_http_header();
    }
    $r->print($response->content());
}

sub generateServerErrorPageForErrorInContextWithRequest {
    my $error = shift;
    my $context = shift;
    my $r = shift;

    my $uri = $r->uri();
    $error = "<em>URI:</em> <code>$uri</code><br /><br />\n".$error;

    eval {
        # we can't use the framework to generate the error
        # error page, because what if the error is in the framework?
        # so we have to check everything at each step...
        my $logMask = IF::Log::logMaskFromContext($context, $r);
        my $errorTemplate;
        my $appName = $r->dir_config()->get("Application") || 'IF';
        my $application = IF::Application->applicationInstanceWithName($appName);
        if ($application) {
            $errorTemplate = $application->errorPageForErrorInContext($error, $context);
        } else {
            $errorTemplate = $error;
        }
        IF::Log::error($error);
        # better not assume we have a context ...
        $r->content_type('text/html');
        $r->status(SERVER_ERROR);
        if (MP1) {
            $r->send_http_header();
        }
        $r->print($errorTemplate);
        # do this all over again here:
        if ($logMask) {
            IF::Log::endLoggingTransaction();
            IF::Log::dumpLogForRequestUsingLogMask($r, $logMask);
        }
    };

    #last chance
    if ($@) {
        IF::Log::error($@);
        $r->content_type('text/html');
        if (MP1) {
            $r->send_http_header();
        }
        $r->print($@);
        IF::Log::clearMessageBuffer();
    };
}

# Borrowed from CGI::HMTLError with modifications
sub show_trace {
    my ($error) = @_;
    my ($filename_from_stack,$number_from_stack);

    #
    # now get the error string (we ignore exception objects, and just
    # pray they will be stringified to a useful string)
    #

    my ($filename,$number,$rest_of_error);
    if ($error =~ s/^(.*?\s+at\s+(.*?)\s+line\s+(\d+)[^\n]*)//s) {
        $rest_of_error = $error;
        $error = $1;
        $filename = $2;
        $number = $3;
    }

    print STDERR "$error - $filename - $number - $rest_of_error - \n";

    #
    # If we haven't found the file and line in the string, just use
    # the one found in the stack-trace.
    #

    unless ($filename) {
        $filename = $filename_from_stack;
        $number = $number_from_stack;
        $rest_of_error .= "Exception caused at $filename line $number";
    }

    #
    # show stacktrace if a tracelevel is specified.
    #
    my @trace;
    push @trace, '<hr><em>Stacktrace:</em><pre><code>';
    my $i;
    while (1) {
        my ($pack,$file,$number,$sub) = caller($i) or last;
        push @trace, sprintf "%02d| \&$sub called at $file line $number\n",$i++;
    }
    push @trace, '</code></pre>';


    my $msg = join ('<br />', $error, $rest_of_error, @trace);
    $TRACE = $msg;
}

1;
