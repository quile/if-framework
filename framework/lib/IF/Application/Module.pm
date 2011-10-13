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

package IF::Application::Module;

use strict;
use base qw(
    IF::Interface::KeyValueCoding
);
use IF::Log;

sub new {
    my ($className) = @_;
    my $self = bless { _componentAliasFromComponentName => {} }, $className;
    return $self;
}

# ensure it's a singleton
my $_instance = {};
sub instance {
    my ($className) = @_;
    return $_instance->{$className} if $_instance->{$className};
    $_instance->{$className} = $className->new();
    return $_instance->{$className};
}

sub name {
    my ($self) = @_;
    return ref($self);
}

# A namespace must match perfectly, from the beginning of the
# component name, and it must match a trailing slash too, so
# "Foo" will match "Foo/Bar" but not "Food/Drink"

sub isOwnerInContextOfComponentNamed {
    my ($self, $context, $componentName) = @_;
    $componentName =~ s/::/\//go;
    foreach my $ns (@{$self->namespaces()}) {
        return 1 if ($componentName =~ /^$ns\//);
    }
    return 0;
}

# You override this and provide an array of namespaces that are
# maintained by this module.
sub namespaces {
    my ($self) = @_;
    return [];
}

# from an ActionLocator we can derive enough info
# to see if it's worth rewriting, and if so, we
# return it.  otherwise, return the string
# representation of the ActionLocator.
sub urlFromActionLocator {
    my ($self, $al) = @_;
    return $self->urlFromActionLocatorAndQueryDictionary($al);
}

sub urlFromActionLocatorAndQueryDictionary {
    my ($self, $al, $qd) = @_;
    unless (ref ($al)) {
        $al = IF::Web::ActionLocator->newFromString($al);
    }
    # URL is now an object

    foreach my $rule (@{$self->mapRules()}) {
        my $rewrittenUrl = $self->evaluateRuleOnActionLocatorAndQueryDictionary($rule, $al, $qd);
        if ($rewrittenUrl eq 'DECLINED') {
            IF::Log::debug("All further matching for this module declined.");
            last;
        }
        return $rewrittenUrl if $rewrittenUrl;
    }
    return $al->asAction();
}

# the incoming URL is always a string
# since we can't parse it into our own format
# until it's been processed here
sub urlFromIncomingUrl {
    my ($self, $url) = @_;

    foreach my $rule (@{$self->mapRules()}) {
        my ($rewrittenUrl, $rewrittenQs) = $self->evaluateRuleOnIncomingUrl($rule, $url);
        return ($rewrittenUrl, $rewrittenQs) if $rewrittenUrl;
    }
    return $url;
}

sub mapRules {
    return [];
}

# returns a string, or undef if it declines to handle
# this particular URL
sub evaluateRuleOnActionLocatorAndQueryDictionary {
    my ($self, $rule, $al, $qd) = @_;

    #IF::Log::debug("Evaluating rule on ".$al->asAction());
    my $vars = {};
    my $ruleParts = [];
    my $atLeastOneMatch = 0;
    # the URL contains the full outgoing URL
    foreach my $f qw(siteClassifierName language targetComponentName directAction) {
        next unless exists $rule->{outgoing}->{$f};
        $atLeastOneMatch++;

        # evaluate the rule on the URL
        my $v = $al->valueForKey($f);
        my $rulePart = $rule->{outgoing}->{$f};
        push @$ruleParts, { key => $f, ruleValue => $rulePart, urlValue => $v};
    }
    if ($qd && $rule->{outgoing}->{queryDictionary}) {
        foreach my $f (keys %{$rule->{outgoing}->{queryDictionary}}) {
            my $v = $qd->{$f};
            my $rulePart = $rule->{outgoing}->{queryDictionary}->{$f};
            push @$ruleParts, { key => $f, ruleValue => $rulePart, urlValue => $v};
        }
    }

    foreach my $rulePart (@$ruleParts) {
        my $v = $rulePart->{urlValue};
        my $ruleValue = $rulePart->{ruleValue};
        # find the variable names to match out of the string
        my $varNames = $self->_namedVariablesFromString($ruleValue);
        my $re = $self->_regexpFromRule($ruleValue);

        # cheesy special case for directAction
        if ($rulePart->{key} eq "directAction") {
            $re = "([0-9\_]+-)?".$re;
        }
        #IF::Log::debug("Trying to match $re on $v");
        if ($v !~ /^$re$/) {
        #    IF::Log::debug("Did not match $re on $v");
            return undef;
        } else {
        #    IF::Log::debug("DID match $re on $v");
        }
        $vars = {
            %$vars,
            %{$self->_dictionaryOfValuesOfNamedVariablesFromStringMatchingRegexp($varNames, $v, $re)},
        };
    }
    return undef unless $atLeastOneMatch;

    # we got this far so rewrite it and go
    my $url = $rule->{incoming}->{rewriteAs} || $rule->{incoming}->{match};
    $url = $self->_interpolateVariablesIntoString_Outgoing($vars, $url);

    IF::Log::debug("Returning module rewritten URL $url from ".$al->asAction());
    return $url;
}

sub evaluateRuleOnIncomingUrl {
    my ($self, $rule, $url) = @_;

    #IF::Log::debug("Evaluating rule on ".$url);

    # The regexp matching needs a lot of work;
    my $string = $rule->{incoming}->{match};
    my $varNames = $self->_namedVariablesFromString($string);
    my $re = $self->_regexpFromRule($string);
    return undef unless ($url =~ /^$re$/);

    my $vars = $self->_dictionaryOfValuesOfNamedVariablesFromStringMatchingRegexp($varNames, $url, $re);

    my $al = IF::Web::ActionLocator->new();

    foreach my $f qw(urlRoot siteClassifierName language targetComponentName directAction) {
        my $dk = "default".ucfirst($f);
        my $dv = $self->valueForKey($dk);
        my $v = $rule->{outgoing}->{$f} || $dv;
        $al->setValueForKey($v, $f);
    }

    # we got this far so rewrite it and go
    $url = $al->asAction();

    my $qdString = $self->_stringFromQueryDictionary($rule->{outgoing}->{queryDictionary});
    $qdString = $self->_interpolateVariablesIntoString_Incoming($vars, $qdString);

    $url = $self->_interpolateVariablesIntoString_Incoming($vars, $url);
    IF::Log::debug("Returning $url with qd $qdString");
    return ($url, $qdString);
}

sub _interpolateVariablesIntoString_Incoming {
    my ($self, $vars, $string) = @_;
    #IF::Log::dump($vars);
    while ($string =~ /\$\{([A-Za-z0-9_]+)\}/) {
        my $var = $1;
        my $value = $vars->{$var};
        $value = $self->valueForSubstitution($value);
        #IF::Log::debug("Interpolating $value as $var");
        $string =~ s/\$\{$var\}/$value/g;
    }
    return $string;
}

sub _interpolateVariablesIntoString_Outgoing {
    my ($self, $vars, $string) = @_;
    #IF::Log::dump($vars);
    while ($string =~ /\$\{([A-Za-z0-9_]+)\}/) {
        my $var = $1;
        my $value = $vars->{$var};
        $value = $self->substitutionForValue($value);
        #IF::Log::debug("Interpolating $value as $var");
        $string =~ s/\$\{$var\}/$value/g;
    }
    return $string;
}


sub _namedVariablesFromString {
    my ($self, $string) = @_;
    my $varNames = [];

    while ($string =~ m/\$\{([A-Za-z0-9_]+)\}/g) {
        push (@$varNames, $1);
    }

    #IF::Log::debug("Found interpolated vars ".join(", ", @$varNames));
    return $varNames;
}

sub _dictionaryOfValuesOfNamedVariablesFromStringMatchingRegexp {
    my ($self, $varNames, $string, $re) = @_;

    my @matches = ($string =~ /^$re$/);
    my $vars = {};
    foreach my $var (@$varNames) {
        $vars->{$var} = shift @matches;
    }
    #IF::Log::dump($vars);
    return $vars;
}

sub _regexpFromRule {
    my ($self, $rule) = @_;
    my $re = $rule;

    # this finds ${foo} and replaces it with something
    # that matches anything that's not a slash or ampersand
    $re =~ s/\$\{([A-Za-z0-9_]+)\}/([^\&\/]+)/g;
    return $re;
}

# can't use the usual one in IF::Utility because it uri escapes
# the values which breaks our variable interpolaton
sub _stringFromQueryDictionary {
    my ($self,$qd) = @_;

    my @keyValuePairs = ();
    foreach my $key ( sort keys %$qd ) {
        if ( IF::Array::isArray( $qd->{$key} ) ) {
            foreach my $value ( @{ $qd->{$key} } ) {
                push( @keyValuePairs, "$key=$value" );
            }
        }
        else {
            push( @keyValuePairs,
                "$key=" . $qd->{$key} );
        }
    }
    return join( "&", @keyValuePairs );
}


# These need to be implemented by the module

sub defaultAdaptor {
    return undef;
}

sub defaultSiteClassifierName {
    return undef;
}

sub defaultLanguage {
    return undef;
}

sub defaultTargetComponentName {
    return undef;
}

sub defaultDirectAction {
    return undef;
}

sub substitutionForValue {
    my ($self,$value) = @_;
    return $value;
}

sub valueForSubstitution {
    my ($self,$value) = @_;
    return $value;
}

1;