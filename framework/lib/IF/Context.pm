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

package IF::Context;

use strict;
use base qw(
    IF::Interface::KeyValueCoding
    IF::Interface::StatusMessageHandling
);
use IF::ObjectContext;
use IF::Request;
use IF::Array;
use Encode      qw();
use Carp;

use URI::Escape qw( uri_escape uri_unescape );

#==============================
# This is used to indicate that the system should not
# create and save a session for this request, and instead
# just use a transient session.  It's used mostly in AJAX transactions.
my $NULL_SESSION_ID = "x";

sub _new {
    my $className = shift;
    my $self = {
        _pageContext => [1],
        _loopContext => [],
        _contentType => "text/html",
        _renderedComponents => {},
        _request => undef,
        _incomingCookies => {},
        _formValues => {},
        #_presentComponents => {},
    };
    return bless $self, $className;
}

# This is the real factory method for context objects.
# Nothing else should be used to create them.
#
# $opts->{doNotInflate => undef/1} is a flag used only when non-IF requests
#  (like the unfortunate wwwthreads) need a context
#
#  request is a descendant of IF::Request
sub contextForRequest {
    my ($className, $request, $opts) = @_;
    $opts = {} unless $opts;

    # grab the application instance:
    my $application = IF::Application->applicationInstanceWithName($request->applicationName());
    if ($application) {
        $className = $application->contextClassName();
    }

    # instantiate the context
    my $context = $className->_new(@_);
    $context->setRequest($request);

    # inflate the context from the URI etc.
    unless ($opts->{doNotInflate} || $context->inflateContextFromRequest()) {
        IF::Log::error("Malformed URL: couldn't parse - ".$request->uri());
        return undef;
    }

    # set the order of preferred languages for this user
    $context->setLanguagePreferences($context->browserLanguagePreferences());

    # derive language preferences for this transaction
#    if ($context->formValueForKey("LANGUAGE")) {
#        # check for multiple values here (2003-10-27)
#        my $values = $context->formValuesForKey("LANGUAGE");
#        if ($values && scalar @$values) {
#            # default to the first one TODO: fix this!
#            $context->setLanguage($values->[0]);
#        } else {
#            $context->setLanguage($context->formValueForKey("LANGUAGE"));
#        }
#    } elsif ($context->cookieValueForKey("LANGUAGE")) {
#        $context->setLanguage($context->cookieValueForKey("LANGUAGE"));
#    } elsif ($ENV{'LANGUAGE'}) {
#        $context->setLanguage($ENV{'LANGUAGE'});
#    } else {
#        my $languagePreferences = $context->languagePreferences();
#        $context->setLanguage($languagePreferences->[0]);
#    }

    return $context;
}

sub applicationName {
    my $className = shift;
    return IF::Application->defaultApplicationName();
}
# ...except this, used for off-line generation of
# contexts, like in the indivUpdate script.
sub emptyContext {
    my $className = shift;
    return $className->emptyContextForApplicationWithName($className->applicationName());
}

sub emptyContextForApplicationWithName {
    my ($className, $appName) = @_;
    my $emptyContext =  $className->_new(@_);
    $emptyContext->{_request} = IF::Request->new();
    $emptyContext->{_request}->setApplicationName($appName);
    $emptyContext->setSession($emptyContext->newSession());
    return $emptyContext;
}

#  lang will match fr and fr_ca style languages
sub inflateContextFromRequest {
    my $self = shift;
    my $uri = $self->request()->uri();

    IF::Log::debug("Parsing URI: $uri");

    my ($adaptor, $site, $lang, $component, $action) =
                ($uri =~ m#^/(\w+)/([\w-]+)/([\w-]+)/(.+)/([\w\d\.-]+)#);
    return undef unless $action;
    my ($targetPageContextNumber, $directActionName) = split("-", $action);

    # already know the adaptor based on which dir_config we got.  IF::Application takes care of
    #  setting up the application
    IF::Log::debug("- Adaptor: $adaptor");

    $self->setLanguage($lang);
    IF::Log::debug("- Language: $lang");

    $self->setSiteClassifierByName($site);
    # If we didn't even find a default SC, bail, we're toast.  This only happens in a mis-configured setup
    return undef unless $self->siteClassifier();
    IF::Log::debug("- Site Classifier Name: $site");

    $component =~ s#/#::#g;
    $self->setTargetComponentName($component);
    IF::Log::debug("- Component: $component");

    $self->buildFormValueDictionaryFromRequest();

    # check for an action indicated by a button code:
    foreach my $param ($self->formKeys()) {
        #IF::Log::debug("Checking request for direct action declared in param $param");
        next unless $param =~ /^_ACTION:?/;
        $action = $param;
        $action =~ s!.*/!!g;
        # Total hack... this is just to patch the fix from earlier today... it's not ideal...
        if ($targetPageContextNumber && $targetPageContextNumber =~ /^[0-9_]+$/) {
            $action = join('-', $targetPageContextNumber, $action) ;
        }
        last;
    }

    $self->setDirectAction($action);
    IF::Log->debug("- Direct Action: $action");

    # inflate the session
    my $className = ref($self);
    $self->setSession($className->sessionFromContext($self));

    IF::Log::debug("Session is ".$self->session()." and has external id ".$self->session()->externalId());
    return 1;
}

# this is not terribly optimal, but since we use formValues
# as a general read/write store and apache2 not longer
# lets us write to its params table, we don't really
# have a choice but to slurp it all in.

sub buildFormValueDictionaryFromRequest {
    my ($self) = @_;
    foreach my $key ($self->request()->param()) {
        my @values = $self->request()->param($key);
        $self->{_formValues}->{$key} = \@values;
        # Strip them for obvious XSS attacks
        foreach my $v (@values) {
            $v =~ s/<[^>]*script[^>]*>/xss/gio;
            $v =~ s/document\s*\.\s*cookie/xss/gio;
            IF::Log::debug("Stripped $key to $v");
        }
    }
}

sub query {
    my $self = shift;
    unless ($self->{_query}) {
        croak "Why is this still in here?";
        $self->{_query} = new CGI();
    }
    return $self->{_query};
}

sub setQuery {
    my $self = shift;
    $self->{_query} = shift;
}

sub request {
    my $self = shift;
    return $self->{_request};
}

sub setRequest {
    my $self = shift;
    $self->{_request} = shift;
}

sub newSession {
    my ($self) = @_;
    my $sessionClassName = $self->application()->sessionClassName();
    return undef unless $sessionClassName;
    my $session;
    eval {
        $session = $sessionClassName->new();
    };
    if ($@) {
        IF::Log::error("Error creating session: $@");
    }
    $session->setApplication($self->application());
    return $session;
}

sub session {
    my $self = shift;
    return $self->{_session};
}

sub setSession {
    my $self = shift;
    $self->{_session} = shift;
}

sub sessionId {
    my $self = shift;
    return $self->{sessionId};
}

sub setSessionId {
    my ($self, $value) = @_;
    $self->{sessionId} = $value;
}

sub escape {
    my ($self, $value) = @_;
    return uri_escape($value);
}

sub unescape {
    my ($self, $value) = @_;
    return uri_unescape($value);
}

sub cookies {
    my $self = shift;
    return $self->{_cookies};
}

sub cookieValueForKey {
    my ($self, $key) = @_;

    #IF::Log::dump($self->{_cookies});
    my $cookie = $self->request()->cookieValueForKey($key);
    return undef unless $cookie;
    my $cookieValue = ref($cookie)? $cookie->value() : $cookie;
    my $value = Encode::decode_utf8($self->unescape($cookieValue));
    IF::Log::debug("======= got back cookie value $value for $key ========");
    return $value;
}

sub setCookieValueForKey {
    my ($self, $value, $key, $timeout) = @_;
    $timeout = "+12M" unless $timeout;

    #IF::Log::debug("======= set cookie value: $value for key: $key ========");
    # TODO: this sets cookies that last up to 12 months.
    # we need to allow session cookies and cookies that
    # last across sessions but expire sooner than that.
    my $newCookie = $self->request()->dropCookie(
                                    -name => $key,
                                    -value => $self->escape($value),
                                    -path => "/",
                                    -expires => $timeout,
                                    );
}

# TODO: the cookie API needs work...
sub setSessionCookieValueForKey {
    my ($self, $value, $key) = @_;

    #IF::Log::debug("======= set session cookie value: $value for key: $key ========");
    my $newCookie = $self->request()->dropCookie(
                                    -name => $key,
                                    -value => $self->escape($value),
                                    -path => "/",
                                    );
}

# these two methods are just shortcuts:
sub formValueForKey {
    my $self = shift;
    my $key = shift;
    my $values = $self->formValuesForKey($key);

    if (scalar @$values) {
        # HACK HACK HACK! this checks for the doubled value problem and prevents it
        # shift @$values if (scalar @$values == 2 && $values->[0] eq $values->[1]);
        return join("\0", @$values);
    }
    return;
}

sub headerValueForKey {
    my ($self, $key) = @_;
    return unless $self->request();
    return $self->request()->headers_in->{$key};
}

sub setHeaderValueForKey {
    my ($self, $value, $key) = @_;
    return unless $self->request();
    $self->request()->headers_out->{$key} = $value;
}

sub uploadForKey {
    my $self = shift;
    my $key = shift;
    return $self->request()->upload($key);
}

sub setFormValueForKey {
    my ($self, $value, $key) = @_;
    delete $self->{_queryDictionary};
    $self->{_formValues}->{$key} = IF::Array->arrayFromObject($value);
}

sub formValuesForKey {
    my $self = shift;
    my $key = shift;

    my $values = [];
    foreach my $value (@{$self->{_formValues}->{$key}}) {
        next unless length($value);
        my $decodedValue = Encode::decode_utf8($value);
        push @$values, ($decodedValue ? $decodedValue : $value);
    }
    return $values;
}

sub formKeys {
    my $self = shift;
    my @values = keys %{$self->{_formValues}};
    # IF::Log::dump(\@values);
    if (wantarray) {
        return @values;
    } else {
        return \@values;
    }
}

sub queryDictionary {
    my $self = shift;
    unless ($self->{_queryDictionary}) {
        my $queryDictionary = {};
        foreach my $key ($self->formKeys()) {
            my $values = $self->formValuesForKey($key);
            my $value = $self->formValueForKey($key);
            if (IF::Array::isArray($values) && scalar @$values > 1) {
                $queryDictionary->{$key} = $values;
            } else {
                $queryDictionary->{$key} = $value;
            }
        }
        $self->{_queryDictionary} = $queryDictionary;
    }
    return $self->{_queryDictionary};
}

# And this is to transparently manipulate pnotes

sub setTransactionValueForKey {
    my $self = shift;
    my $value = shift;
    my $key = shift;

    $self->request()->pnotes($key => $value);
}

sub transactionValueForKey {
    my $self = shift;
    my $key = shift;
    return $self->request()->pnotes($key);
}

# this allows parts of the request to set up code references
# that clean up the transaction or perform long-running goo
# after the response has been sent back.
sub transactionCleanupRequests {
    my ($self) = @_;
    return $self->transactionValueForKey("_cleanupRequests") || [];
}

sub addTransactionCleanupRequest {
    my ($self, $cr) = @_;
    my $trs = $self->transactionCleanupRequests();
    push (@$trs, $cr);
    $self->setTransactionValueForKey($trs, "_cleanupRequests");
}

sub language {
    my $self = shift;
    return $self->{_language};
}

sub setLanguage {
    my $self = shift;
    $self->{_language} = shift;
    IF::Log::debug("Setting language to $self->{_language}");
    $self->{_preferredLanguagesForTransactionAsToken} = undef;
}

sub browserLanguagePreferences {
    my $self = shift;

    my $languagePreferences = [];
    # pull language preferences from headers
    foreach my $language (split (/[ ]/, $self->request()->headers_in->{'Accept-Language'})) {
        push (@$languagePreferences, $language);
    }

    # failover case:
    push (@$languagePreferences, $self->application()->configurationValueForKey("DEFAULT_LANGUAGE"));

    #NOTE!  THIS IS JUST TEMPORARY!  IT MUST BE REMOVED WHEN LANGUAGES
    #PREFERENCES ARE SWITCHED ON
    $languagePreferences = ["en"];
    #END OF TEMPORARY FIX

    return $languagePreferences;
}

sub languagePreferences {
    my $self = shift;
    return $self->{_languagePreferences};
}

sub setLanguagePreferences {
    my ($self, $value) = @_;
    $self->{_languagePreferences} = $value;
}

sub directAction {
    my $self = shift;
    return $self->{_directAction};
}

sub setDirectAction {
    my ($self, $value) = @_;
    $self->{_directAction} = $value;
}

sub targetComponentName {
    my $self = shift;
    return $self->{_targetComponentName};
}

sub setTargetComponentName {
    my ($self, $value) = @_;
    $self->{_targetComponentName} = $value;
}

sub siteClassifier {
    my $self = shift;
    return $self->{_siteClassifier};
}

sub setSiteClassifier {
    my ($self, $value) = @_;
    $self->{_siteClassifier} = $value;
}

sub siteClassifierName {
    my $self = shift;
    return unless $self->{_siteClassifier};
    return $self->{_siteClassifier}->name();
}

# Not too happy with the name of this method...

sub setSiteClassifierByName {
    my ($self, $name) = @_;
    $self->{_siteClassifierName} = $name;
    my $sc = $self->application()->siteClassifierWithName($name);
    $self->setSiteClassifier($sc);
}

sub isCorrectRequestForContextNumber {
    my $self = shift;
    IF::Log::debug("Incoming context number is ".$self->contextNumber()." and current context number is ".$self->session()->contextNumber());
    return $self->session()->contextNumber() == ($self->contextNumber()+1);
}

sub lastRequestWasSpecified {
    my $self = shift;
    return 1 if ($self->contextNumber());
    return 0;
}

sub lastRequestContext {
    my ($self) = @_;
    return undef unless $self->lastRequestWasSpecified();
    return undef unless $self->session();
    return $self->{_lastRequestContext} ||= $self->session()->requestContextForContextNumber($self->contextNumber());
}

sub callingComponentPageContextNumber {
  my $self = shift;
  return $self->{_callingComponentPageContextNumber};
}

sub setCallingComponentPageContextNumber {
  my $self = shift;
  $self->{_callingComponentPageContextNumber} = shift;
}

sub callingComponentId {
    my $self = shift;
    return $self->formValueForKey("calling-component-id");
}

# ------ some useful web-related goop ----

sub contentType {
    my $self = shift;
    return $self->{_contentType};
}

sub setContentType {
    my $self = shift;
    $self->{_contentType} = shift;
}

# undef == OK
sub responseCode {
    my ($self) = @_;
    return $self->{responseCode};
}

sub setResponseCode {
    my ($self, $value) = @_;
    $self->{responseCode} = $value;
}

# when undef, the header is not set
sub cacheControlMaxAge {
    my $self = shift;
    return $self->{_cacheControlMaxAge};
}

sub setCacheControlMaxAge {
    my $self = shift;
    $self->{_cacheControlMaxAge} = shift;
}

sub userAgent {
    my $self = shift;
    return $self->headerValueForKey("User-Agent");
}

sub referrer {
    my $self = shift;
    return $self->headerValueForKey("Referer");
}

sub contextNumber {
    my $self = shift;
    return $self->formValueForKey("context-number");
}

sub url {
    my $self = shift;
    return $self->request()->uri();
}

sub urlWithQueryString {
    my $self = shift;
    return $self->request()->uri().'?'.$self->request()->args();
}

sub application {
    my $self = shift;
    unless ($self->{_application}) {
        $self->{_application} = IF::Application->applicationInstanceWithName($self->request()->applicationName());
        unless ($self->{_application}) {
            IF::Log::error("Application cannot be determined from context");
            return;
        }
    }
    return $self->{_application};
}

# languageToken - used by IF::Component in matching templates to contexts
sub preferredLanguagesForTransactionAsToken {
    my $self = shift;
    return $self->{_preferredLanguagesForTransactionAsToken}
            if $self->{_preferredLanguagesForTransactionAsToken};

    my $siteClassifier = $self->siteClassifier();
    my $token;

    if ($siteClassifier) {
        my $scLangPreference = $siteClassifier->preferredLanguagesForTemplateResolutionInContext($self);
        $token = join(":", @$scLangPreference);
    }

    unless ($token) {
        # 1. base language preference
        $token = $self->language();

        # 2. site classifier default language site
        if ($siteClassifier->defaultLanguage() and
            ($siteClassifier->defaultLanguage() ne $self->language())) {
            $token .= ":".$siteClassifier->defaultLanguage();
        }

        # 3. any other preferred langs that site classifier has
        if ($siteClassifier) {
            foreach my $language (@{$self->languagePreferences()}) {
                if ($siteClassifier->hasLanguage($language) && $language ne $siteClassifier->defaultLanguage()) {
                    $token .= ":".$language;
                }
            }
        } else {
            $token .= ':'.join(':', @{$self->languagePreferences()});
        }
    }

    $self->{_preferredLanguagesForTransactionAsToken} = $token;
    return $token;
}

sub preferredLanguagesForTransaction {
    my $self = shift;
    return [split(":", $self->preferredLanguagesForTransactionAsToken())];
}

# override this method to perform other cleanups
sub didGenerateResponse {
    my ($self, $response) = @_;
    $self->session()->save();
}

# ++++++++++ class +++++++++++

sub sessionFromContext {
    my ($className, $context) = @_;

    my $session;
    my $sessionId;
    my $externalId;

    my $application = $context->application();
    my $sessionClass = $application->sessionClassName();

    IF::DB::dbConnection()->releaseDataSourceLock();

    # check for a SID
    $externalId = $context->formValueForKey($application->sessionIdKey()) || $context->cookieValueForKey($application->sessionIdKey());

    if ($externalId && $externalId ne $NULL_SESSION_ID) {
        # check for a context-number
        my $contextNumber = $context->formValueForKey("context-number");
        IF::Log::debug("Context number is $contextNumber");
        if ($contextNumber) {
            $session = $sessionClass->sessionWithExternalIdAndContextNumber($externalId, $contextNumber);
        }

        unless ($session) {
            $session = $sessionClass->sessionWithExternalId($externalId);
        } else {
            #IF::Log::dump($session);
        }

        if (!$session || ($session && $session->hasExpired())) {
            IF::Log::debug("!!! Session has expired, deleting it.");
            # if we reach this point and still have no session, it means
            # a) the session has been deleted
            # b) funny business going on
            # so we desperately need to flush the cookies for the client-side
            # auth to work correctly
            delete $context->{_incomingCookies}->{$application->sessionIdKey()};
            $context->setSessionCookieValueForKey("", $application->sessionIdKey());
            if ($session) {
                $session->becomeInvalidated();
                $session = undef;
            }
        }
    }

    if ($session) {
        $session->wasInflated();
        return $session;
    }

    # create new session
    $session = $context->newSession();

    unless ($session) {
        IF::Log::error("Error creating new session");
        return undef;
    }
    IF::Log::debug("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!  created new session");

    if ($context->headerValueForKey("X-Forwarded-For")) {
        $session->setClientIp($context->headerValueForKey("X-Forwarded-For"));
    }

    # save the new session
    #IF::Log::debug("External id is $externalId");
    if ($externalId eq $NULL_SESSION_ID) {
        $session->_setExternalId($NULL_SESSION_ID);
        #IF::Log::debug("Set external session id to ".$session->externalId());
    } else {
        $session->save();
        IF::Log::debug("Created session with external ID ".$session->externalId());
        delete $context->{_incomingCookies}->{$application->sessionIdKey()};
        $context->setSessionCookieValueForKey($session->externalId(), $application->sessionIdKey());
    }

    return $session;
}

sub NULL_SESSION_ID {
    return $NULL_SESSION_ID;
}

# ------------- these messages are conveniences for accumulating status messages ------------

sub addInfoMessage {
    my ($self, $message) = @_;
    $self->addInfoMessageInLanguage($message, $self->language());
}

sub addConfirmationMessage {
    my ($self, $message) = @_;
    $self->addConfirmationMessageInLanguage($message, $self->language());
}

sub addWarningMessage {
    my ($self, $message) = @_;
    $self->addWarningMessageInLanguage($message, $self->language());
}

sub addErrorMessage {
    my ($self, $message) = @_;
    $self->addErrorMessageInLanguage($message, $self->language());
}

1;
