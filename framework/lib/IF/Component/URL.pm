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

package IF::Component::URL;

use strict;
use base qw(
    IF::Component
);
#====================================
use IF::Array;
use IF::Dictionary;
use IF::Utility;
use IF::Web::ActionLocator;
use URI::Escape ();
use Encode ();
#====================================

sub init {
    my $self = shift;
    #my $application = $self->context()->application();
    #$self->setDirectAction($application->configurationValueForKey("DEFAULT_DIRECT_ACTION"));

    $self->setDirectAction();
    $self->setSiteClassifierName();
    $self->setTargetComponentName();
    $self->setUrl();
    $self->setSessionId();
    $self->setQueryDictionary({});
    $self->setRawQueryDictionary({});
    $self->setQueryString();
    $self->setShouldSuppressQueryDictionary(0);
    $self->{queryDictionaryAdditions} = IF::Array->new();
    $self->{queryDictionarySubtractions} = IF::Dictionary->new();
    $self->{queryDictionaryReplacements} = IF::Dictionary->new();
}

sub action {
    my $self = shift;

    return $self->{action} if $self->{action};

    my $componentName = $self->targetComponentName();
    my $directAction = $self->directAction();
    if ($componentName eq "") {
        $componentName = $self->rootComponent()->componentNameRelativeToSiteClassifier();
        if ($self->parent()) {
            my $pageContextNumber = $self->parent()->pageContextNumber();
            if ($pageContextNumber != 1) {
                $directAction = $pageContextNumber."-".$directAction;
            }
        }
    }

    $componentName =~ s!::!/!g;
    my $siteClassifierName = $self->siteClassifierName();
    my $root     = $self->urlRoot();
    my $language = $self->language();

    my $al = IF::Web::ActionLocator->new();
    $al->setUrlRoot($root);
    $al->setSiteClassifierName($siteClassifierName);
    $al->setLanguage($language);
    $al->setTargetComponentName($componentName);
    $al->setDirectAction($directAction);

    my $application = $self->context() ? $self->context()->application() : IF::Application->defaultApplication();
    my $module = $application->moduleInContextForComponentNamed($self->context(), $componentName);
    if ($module) {
        my $ou = $module->urlFromActionLocatorAndQueryDictionary($al, $self->queryDictionaryAsHash());
        # testing:
        #my $iu = $module->urlFromIncomingUrl($ou);
        #IF::Log::debug("That maps back to $iu");

        $self->setShouldSuppressQueryDictionary(1) unless $ou eq $al->asAction();
        return $ou;
    } else {
        return $al->asAction();
    }
}

sub setAction {
    my ($self, $value) = @_;
    $self->{action} = $value;
}

sub queryString {
    my $self = shift;
    return $self->{queryString};
}

sub setQueryString {
    my $self = shift;
    $self->{queryString} = shift;
}

sub protocol {
    my $self = shift;
    return $self->{protocol} if $self->{protocol};
    return "http";
}

sub setProtocol {
    my ($self, $value) = @_;
    $self->{protocol} = $value;
}

sub server {
    my $self = shift;
    return $self->{server};
}

sub setServer {
    my ($self, $value) = @_;
    IF::Log::debug("Setting SERVER value to $value");
    $self->{server} = $value;
}

sub siteClassifierName {
    my $self = shift;
    return $self->{siteClassifierName} if $self->{siteClassifierName};
    return $self->_siteClassifier()->name();
#    return $self->context()->siteClassifier()->name() ||
#        $self->context()->application()->configurationValueForKey("DEFAULT_SITE_CLASSIFIER_NAME");
}

sub setSiteClassifierName {
    my ($self, $value) = @_;
    $self->{siteClassifierName} = $value;
}

sub url {
    my $self = shift;
    return $self->{url};
}

sub setUrl {
    my ($self, $value) = @_;
    $self->{url} = $value;
}

sub shouldEnsureDefaultProtocol {
    my ($self) = @_;
    return $self->{shouldEnsureDefaultProtocol};
}

sub setShouldEnsureDefaultProtocol {
    my ($self, $value) = @_;
    $self->{shouldEnsureDefaultProtocol} = $value;
}

sub anchor {
    my $self = shift;
    return $self->{anchor};
}

sub setAnchor {
    my ($self, $value) = @_;
    $self->{anchor} = $value;
}

sub language {
    my $self = shift;
    return $self->{language} if $self->{language};
    return $self->context()->language() if $self->context();
    return $self->application()->configurationValueForKey("DEFAULT_LANGUAGE");
}

sub setLanguage {
    my ($self, $value) = @_;
    $self->{language} = $value;
}

sub urlRoot {
    my $self = shift;
    return $self->{urlRoot} if $self->{urlRoot};
    return $self->application()->configurationValueForKey("URL_ROOT");
}

sub setUrlRoot {
    my ($self, $value) = @_;
    $self->{urlRoot} = $value;
}

sub hasQueryDictionary {
    my $self = shift;
    return 1 if ($self->queryDictionary() &&
                IF::Dictionary::isHash($self->queryDictionary()) &&
                scalar keys %{$self->queryDictionary()});
    return 1 if ($self->{queryDictionaryAdditions}->count() > 0);
    return 1 if (scalar keys %{$self->{queryDictionaryReplacements}});
    return 1 if length($self->{queryString});
    return 1 if ($self->rawQueryDictionary() &&
                IF::Dictionary::isHash($self->rawQueryDictionary()) &&
                scalar keys %{$self->rawQueryDictionary()});
    return 0;
}

sub queryDictionary {
    my $self = shift;
    return $self->{queryDictionary};
}

sub setQueryDictionary {
    my ($self, $qd) = @_;
    # dopey kyle: make a copy before changing this, seeing as
    # how it's BOUND IN from outside!
    my $qdCopy = IF::Dictionary->new()->initWithDictionary($qd);
    $self->{queryDictionary} = $qdCopy;
    # expand the values and evaluate in the context of the parent:
    foreach my $key (@{$qdCopy->allKeys()}) {
        my $value = IF::Utility::evaluateExpressionInComponentContext($qdCopy->objectForKey($key), $self->parent(), $self->context());
        $qdCopy->setObjectForKey($value, $key);
    }
}

sub rawQueryDictionary {
    my $self = shift;
    return $self->{rawQueryDictionary};
}

sub setRawQueryDictionary {
    my ($self, $value) = @_;
    return unless (IF::Log::assert(IF::Dictionary::isHash($value), "Raw query dictionary is a dictionary"));
    $self->{rawQueryDictionary} = $value;
}

sub queryDictionaryKeyValuePairs {
    my $self = shift;

    my $keyValuePairs = IF::Array->new();
    my $usedKeys = IF::Dictionary->new();

    # first we do the additions:
    foreach my $addition (@{$self->{queryDictionaryAdditions}}) {
        my $key = $addition->{NAME};
        next if ($self->shouldSuppressQueryDictionaryKey($key));
        my $value = $self->{queryDictionaryReplacements}->objectForKey($key) ||
                    $addition->{VALUE};
        $keyValuePairs->addObject({ NAME => $key, VALUE => $value});
        $usedKeys->setObjectForKey(1, $key);
    }

    # if there's a query string, unpack it and use it instead of the query dictionary
    my $qd = $self->queryDictionary();
    if ($self->queryString()) {
        IF::Log::debug("Unpacking from query string ".$self->queryString());
        $qd = IF::Dictionary->new()->initWithQueryString($self->{queryString});
        #IF::Log::dump($qd);
    }
    my $rqd = $self->rawQueryDictionary();

    # next we go through the query dictionary itself
    # and skip values that are "subtracted".  We also
    # replace values that are "replaced"
    foreach my $hash ($qd, $rqd) {
        foreach my $key (keys %$hash) {
            next if ($self->shouldSuppressQueryDictionaryKey($key));
            my $value = $self->{queryDictionaryReplacements}->objectForKey($key) ||
                        $hash->{$key};

            # handle the multiple values:
            my $values = IF::Array->arrayFromObject($value);

            foreach my $v (@$values) {
                $keyValuePairs->addObject({
                    NAME => $key,
                    VALUE => $v,
                });
            }
            $usedKeys->setObjectForKey(1, $key);
        }
    }


    # Lastly, we make sure there are no unused values in the "replacements"
    foreach my $key (@{$self->{queryDictionaryReplacements}->allKeys()}) {
        next if ($usedKeys->hasObjectForKey($key));
        my $values = IF::Array->arrayFromObject($self->{queryDictionaryReplacements}->objectForKey($key));
        foreach my $v (@$values) {
            $keyValuePairs->addObject({
                NAME => $key,
                VALUE => $v,
            });
        }
    }
    #IF::Log::dump($keyValuePairs);
    return $keyValuePairs;
    #return [sort {$a->{NAME} cmp $b->{NAME}} @$keyValuePairs];
}

sub queryDictionaryAsQueryString {
    my $self = shift;
    my $qd = $self->queryDictionaryKeyValuePairs();
    my $qstr = [];
    foreach my $kvp (@$qd) {
        my $k = $kvp->{NAME};
        my $v = $self->escapeQueryStringValue($kvp->{VALUE});
        push @$qstr,"$k=$v";
    }
    return join ('&', @$qstr);
}

sub queryDictionaryAsHash {
    my $self = shift;
    my $qd = $self->queryDictionaryKeyValuePairs();
    my $qdh = {};
    foreach my $kvp (@$qd) {
        $qdh->{$kvp->{NAME}} = $kvp->{VALUE};
    }
    return $qdh;
}

sub targetComponentName {
    my $self = shift;
    return $self->{targetComponentName} || $self->tagAttributeForKey("page");
}

sub setTargetComponentName {
    my ($self, $value) = @_;
    $self->{targetComponentName} = $value;
}

sub setDirectAction {
    my $self = shift;
    $self->{directAction} = shift;
}

sub directAction {
    my $self = shift;
    return $self->{directAction} if $self->{directAction};
    my $ta = $self->tagAttributeForKey("action");
    return $ta if $ta;
    my $application = $self->context() ? $self->context()->application() : IF::Application->defaultApplication();
    return $application->configurationValueForKey("DEFAULT_DIRECT_ACTION");
}

sub sessionId {
    my $self = shift;
    return $self->{sessionId};
}

sub setSessionId {
    my ($self, $value) = @_;
    $self->{sessionId} = $value;
}

sub shouldSuppressQueryDictionary {
    my ($self) = @_;
    return $self->{shouldSuppressQueryDictionary};
}

sub setShouldSuppressQueryDictionary {
    my ($self, $value) = @_;
    $self->{shouldSuppressQueryDictionary} = $value;
}

sub shouldSuppressQueryDictionaryKey {
    my ($self, $key) = @_;
    return 1 if ($self->{queryDictionarySubtractions}->hasObjectForKey($key));
    return 0;
}

# a binding starting with "^" will direct this component
# to REPLACE the query dictionary entry with that key with the specified value.
# a binding starting with "+" will direct this component
# to ADD the key/value pair to the query dictionary
# a binding starting with "-" will direct this component
# to REMOVE that key/value pair from the query dictionary (the value is ignored)

sub setValueForKey {
    my $self = shift;
    my $value = shift;
    my $key = shift;
    unless ($key =~ /^(\^|\+|\-)(.*)$/) {
        return $self->SUPER::setValueForKey($value, $key);
    }
    my $action = $1;
    $key = $2;
    if ($action eq "+") {
        my $values = IF::Array->arrayFromObject($value);
        foreach my $v (@$values) {
            $self->{queryDictionaryAdditions}->addObject({ NAME => $key, VALUE => $v });
        }
        return;
    } elsif ($action eq "-") {
        $self->{queryDictionarySubtractions}->setObjectForKey("1", $key);
        return;
    } elsif ($action eq "^") {
        $self->{queryDictionaryReplacements}->setObjectForKey($value, $key);
        return;
    }
}

sub escapeQueryStringValue {
    my ($self, $string) = @_;
    if (Encode::is_utf8($string)) {
        return URI::Escape::uri_escape_utf8($string);
    } else {
        return URI::Escape::uri_escape($string);
    }
}

sub hasCompiledResponse {
    my $self = shift;
    return 1 if $self->componentNameRelativeToSiteClassifier() eq "URL";
    return 0;
}

# This has been unrolled to speed it up; do not be tempted to do this
# anywhere else!

sub asString {
    my $self = shift;
    my $html;

        my $application = $self->context()? $self->context()->application() : IF::Application->defaultApplication();
        if ($self->url()) {
            if ($self->shouldEnsureDefaultProtocol()) {
                # If we don't have the :// of the protocol and it's not relative meaning begins with /...
                unless ($self->url() =~ m|://| || $self->url() =~ m|^/|) {
                    my $protocol = $application->configurationValueForKey("DEFAULT_PROTOCOL") || "http://";
                    # Prepend the default protocol
                    $self->setUrl($protocol . $self->url());
                }
            }
            push @$html, $self->url();
        } else {
    #    <BINDING_ELSE:HAS_URL>

    #        <BINDING_IF:HAS_SERVER>
            if ($self->server()) {
    #            <BINDING_IF:HAS_PROTOCOL>
                if ($self->protocol()) {
    #                <BINDING:PROTOCOL>://
                    push @$html,$self->protocol(),"://";
    #            </BINDING_IF:HAS_PROTOCOL>
                } else {
                    push @$html,"http://";
                }

    #            <BINDING:SERVER>
                push @$html,$self->server();

    #        </BINDING_IF:HAS_SERVER>
            }

    #        <BINDING:ACTION>
            push @$html,$self->action();

    #        <BINDING_IF:HAS_QUERY_DICTIONARY>
            if ($self->hasQueryDictionary()) {
    #            ?
    #            <BINDING_LOOP:QUERY_DICTIONARY>
    #                <BINDING:NAME>=<BINDING:VALUE>
    #            </BINDING_LOOP:QUERY_DICTIONARY>

                my $qs = "";
                my $isFirst = 1;
                unless ($self->shouldSuppressQueryDictionary()) {
                    foreach my $kvPair (@{$self->queryDictionaryKeyValuePairs()}) {
                        $qs .= "&" unless $isFirst;
                        $isFirst = 0;

                        $qs .= $self->escapeQueryStringValue($kvPair->{NAME});
                        $qs .= "=";
                        $qs .= $self->escapeQueryStringValue($kvPair->{VALUE});
                    }
                    push (@$html, "?", $qs) if $qs;
                }

    #        </BINDING_IF:HAS_QUERY_DICTIONARY>
            }
    #    <BINDING_IF:HAS_ANCHOR>#<BINDING:ANCHOR></BINDING_IF:HAS_ANCHOR>
            if ($self->anchor()) {
                push @$html,'#',$self->anchor();
            }
        }
    #    </BINDING_IF:HAS_URL>
    return join('',@$html);
}


sub appendToResponse {
    my ($self, $response, $context) = @_;

    if ($self->hasCompiledResponse() && $self->componentNameRelativeToSiteClassifier() eq "URL") {
        $response->setContent($self->asString());
    } else {
        $self->SUPER::appendToResponse($response, $context);
    }
    $self->init(); # Clear this instance so it can be re-used next time
    return;
}

sub externalSessionId {
    my $self = shift;
    return "0:0" unless $self->sessionId();
    return IF::Utility::externalIdForId($self->sessionId());
}


1;
