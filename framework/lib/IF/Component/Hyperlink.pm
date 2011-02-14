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

package IF::Component::Hyperlink;

use strict;
use base qw(
    IF::Component::URL
);
use JSON;

sub requiredPageResources {
    my ($self) = @_;
    my $prs = $self->SUPER::requiredPageResources();
    if ($self->shouldShowTooltip()) {
        push (@$prs,
            IF::PageResource->javascript("/if-static/javascript/jquery/jquery-1.2.6.js"),
            IF::PageResource->javascript("/if-static/javascript/jquery/plugins/jquery.tipsy.js"),
            IF::PageResource->stylesheet("/if-static/stylesheets/tipsy/tipsy.css"),
        );
    }
    return $prs;
}

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    # $self->{queryDictionaryAdditions}->addObject({ NAME => $self->application()->sessionIdKey(), VALUE => $self->context()->session()->externalId() });
    # Commented out to remove SIDs from Hyperlinks.  It can be
    # forced by setting this to 1. -kd
    #$self->setShouldIncludeSID(1);
}

sub shouldIncludeSID {
    my $self = shift;
    return $self->{shouldIncludeSID};
}

sub setShouldIncludeSID {
    my ($self, $value) = @_;
    $self->{shouldIncludeSID} = $value;
}

sub sessionId {
    my $self = shift;
    return undef unless ($self->shouldIncludeSID());
    return $self->{sessionId};
}

sub hasCompiledResponse {
    my $self = shift;
    return 1 if $self->componentNameRelativeToSiteClassifier() eq "Hyperlink";
    return 0;
}

# Commented out because the cookie val is not being updated
# correctly on each transaction.
# -------------------------------
#sub shouldSuppressQueryDictionaryKey {
#    my ($self, $key) = @_;
#    # Suppress the SID if we received it as a cookie
#    # from the remote user.
#    #return 1 if ($key eq $self->application()->sessionIdKey() && $self->context()->receivedCookieWithName($self->application()->sessionIdKey())
#    #             && !$self->context()->cookieValueForKey("is-admin")); # This is such a hack
#    return $self->SUPER::shouldSuppressQueryDictionaryKey($key);
#}

sub shouldSuppressQueryDictionaryKey {
    my ($self, $key) = @_;
    return 1 if ($key eq $self->application()->sessionIdKey() && !$self->shouldIncludeSID());
    return 0;
}

# This has been unrolled to speed it up; do not be tempted to do this
# anywhere else!

sub appendToResponse {
    my ($self, $response, $context) = @_;

    if ($self->hasCompiledResponse() && $self->componentNameRelativeToSiteClassifier() eq "Hyperlink") {

        $response->renderState()->addPageResources($self->requiredPageResources());


        # asString is compiled response of IF::Component::URL
        my $html = [q#<a href="#, $self->asString(), q#"#];

        if ($self->onClickHandler()) {
            push @$html, ' onclick="', $self->onClickHandler(), '"';
        }

        if ($self->title()) {
            push @$html, ' title="', $self->title(), '"';
        }

        if ($self->shouldShowTooltip()) {
            push (@$html, ' id="'.$self->uniqueId().'"');
        }
        #   <BINDING:TAG_ATTRIBUTES>
        push @$html, ' ', $IF::Component::TAG_ATTRIBUTE_MARKER,' >';
        #    <BINDING:CONTENT>
        #</A>
        push @$html, $IF::Component::COMPONENT_CONTENT_MARKER,'</a>';

        if ($self->shouldShowTooltip()) {
            push (@$html, "<script type=\"text/javascript\">
jQuery(\"#".$self->uniqueId()."\").tipsy({ "
            .($self->hasTooltipStyles()?
                "styles: ".to_json($self->tooltipStyles()).", "
              : "")
            .($self->tooltipClass()?
                "class: \"".$self->tooltipClass()."\", "
              : "")
            ."gravity: \"".$self->tooltipGravity()."\" });
</script>");
        }

        $response->setContent(join('', @$html));
        return;
    } else {
        $self->SUPER::appendToResponse($response, $context);
    }
}

sub hasTooltipStyles {
    my ($self) = @_;
    return 1 if ($self->tooltipStyles() && scalar keys %{$self->tooltipStyles()});
    return 0;
}
############################################

sub shouldShowTooltip    { $_[0]->{shouldShowTooltip} }
sub setShouldShowTooltip { $_[0]->{shouldShowTooltip} = $_[1] }
sub onClickHandler    { $_[0]->{onClickHandler} }
sub setOnClickHandler { $_[0]->{onClickHandler} = $_[1] }
sub tooltipGravity    { $_[0]->{tooltipGravity} || "n" }
sub setTooltipGravity { $_[0]->{tooltipGravity} = $_[1] }
sub tooltipStyles     { $_[0]->{tooltipStyles}  || {}}
sub setTooltipStyles  { $_[0]->{tooltipStyles} = $_[1] }
sub tooltipClass      { $_[0]->{tooltipClass} }
sub setTooltipClass   { $_[0]->{tooltipClass} = $_[1] }



sub url {
    my ($self) = @_;
    #IF::Log::debug("URL tag attribute is ".$self->tagAttributeForKey("URL"));
    return $self->SUPER::url() || $self->tagAttributeForKey("URL");
}

sub title {
    my ($self) = @_;
    return $self->{title} ||= $self->tagAttributeForKey("title");
}

sub setTitle {
    my ($self, $value) = @_;
    $self->{title} = $value;
}

1;