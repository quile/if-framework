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

package IF::Component::Selection;

use strict;
use vars qw(@ISA);
use base qw(
    IF::Component
);
use IF::Interface::KeyValueCoding;
use Text::Unaccent 1.07;

sub takeValuesFromRequest {
    my ($self, $context) = @_;

    IF::Log::debug("Form value for selection box ".$self->valueForKey("NAME")." is ".$context->formValueForKey($self->valueForKey("NAME")));
    IF::Log::debug("Selection page context number is ".$self->pageContextNumber());
    $self->SUPER::takeValuesFromRequest($context);
}

sub list {
    my $self = shift;
    my $list;
    if ($self->valueForKey("LIST_TYPE") eq "RAW") {
        $list = $self->rawList();
    } else {
        $list = $self->{LIST} || [];
    }
    if ($self->allowsNoSelection()) {
        #unshift (@$list, {});
        if ($self->valueForKey("VALUE") && $self->valueForKey("DISPLAY_STRING")) {
            unshift (@$list, {
                $self->valueForKey("VALUE") => $self->anyValue(),
                $self->valueForKey("DISPLAY_STRING") => $self->anyString() }
            );
        } else {
            unshift (@$list, {});
        }
    }
    return $list;
}

sub setList {
    my $self = shift;
    $self->{LIST} = shift;
}

sub displayStringForItem {
    my $self = shift;
    my $item = shift;
    if (UNIVERSAL::can($item, "valueForKey")) {
        return $item->valueForKey($self->valueForKey("DISPLAY_STRING"));
    }
    if (IF::Dictionary::isHash($item)) {
        if (exists($item->{$self->valueForKey("DISPLAY_STRING")})) {
            return $item->{$self->valueForKey("DISPLAY_STRING")};
        } else {
            return undef;
        }
    }
    return $item;
}

sub valueForItem {
    my $self = shift;
    my $item = shift;
    my $value;
    if (UNIVERSAL::can($item, "valueForKey")) {
        return $item->valueForKey($self->valueForKey("VALUE"));
    }
    if (IF::Dictionary::isHash($item)) {
        if (exists($item->{$self->valueForKey("VALUE")})) {
            return $item->{$self->valueForKey("VALUE")};
        } else {
            return undef;
        }
    }
    return $item;
}

sub rawList {
    my $self = shift;
    my $blessedList = [];
    foreach my $i (@{$self->valueForKey("LIST")  || []}) {
        push @$blessedList, bless($i, 'IF::Interface::KeyValueCoding');
    }
    return $blessedList;
}

sub itemIsSelected {
    my $self = shift;
    my $item = shift;

    my $value;

    if (UNIVERSAL::can($item, "valueForKey")) {
        $value = $item->valueForKey($self->valueForKey("VALUE"));
    } elsif (IF::Dictionary::isHash($item) && exists ($item->{$self->valueForKey("VALUE")})) {
        $value = $item->{$self->valueForKey("VALUE")};
    } else {
        $value = $item;
    }

    return 0 unless $value ne "";
    return 0 unless (IF::Array::isArray($self->valueForKey("SELECTED_VALUES")));
    #TODO: Optimise this by hashing it
    foreach my $selectedValue (@{$self->valueForKey("SELECTED_VALUES")}) {
        unless (ref $selectedValue) {
            #IF::Log::debug("Checking ($selectedValue, $value) to see if it's selected");
            #IF::Log::debug("Should ignore case ".$self->shouldIgnoreCase()." - Should ignore accents ".$self->shouldIgnoreAccents()." - Value is $value - Selected value is $selectedValue");
            return 1 if $self->valuesAreEqual($selectedValue, $value);

            # this could be optimised:
            if ($selectedValue =~ /^[0-9\.]+$/ &&
                $value =~ /^[0-9\.]+$/ &&
                $selectedValue == $value) {
                return 1;
            }
            next;
        }
        if (UNIVERSAL::can($selectedValue, "valueForKey")) {
            return 1 if $self->valuesAreEqual($selectedValue->valueForKey($self->valueForKey("VALUE")), $value);
        } else {
            return 1 if $self->valuesAreEqual($selectedValue->{$self->valueForKey("VALUE")}, $value);
        }
    }
    return 0;
}

sub valuesAreEqual {
    my ($self, $a, $b) = @_;

    if ($self->shouldIgnoreAccents()) {
        $a = unac_string("utf-8", $a);
        $b = unac_string("utf-8", $b);
    }

    if ($self->shouldIgnoreCase()) {
        $a = lc($a);
        $b = lc($b);
    }

    return ($a eq $b);
}

sub setValues {
    my $self = shift;
    $self->{VALUES} = shift;

    if ($self->{LABELS}) {
        $self->{LIST} = $self->listFromLabelsAndValues();
    }
}

sub setLabels {
    my $self = shift;
    $self->{LABELS} = shift;

    if ($self->{VALUES}) {
        $self->{LIST} = $self->listFromLabelsAndValues();
    }
}

sub listFromLabelsAndValues {
    my $self = shift;

    return [] unless $self->{VALUES} && $self->{LABELS};

    my $list = [];
    foreach my $value (@{$self->{VALUES}}) {
        push (@$list, { VALUE => $value, LABEL => $self->{LABELS}->{$value} });
    }
    return $list;
}

sub allowsNoSelection {
    my $self = shift;
    return $self->{allowsNoSelection};
}

sub setAllowsNoSelection {
    my $self = shift;
    $self->{allowsNoSelection} = shift;
}

sub anyString {
    my ($self) = @_;
    return $self->{ANY_STRING};
}

sub setAnyString {
    my ($self, $value) = @_;
    $self->{ANY_STRING} = $value;
}

sub anyValue {
    my ($self) = @_;
    return $self->{ANY_VALUE};
}

sub setAnyValue {
    my ($self, $value) = @_;
    $self->{ANY_VALUE} = $value;
}

sub shouldIgnoreCase {
    my ($self) = @_;
    return $self->{shouldIgnoreCase};
}

sub setShouldIgnoreCase {
    my ($self, $value) = @_;
    $self->{shouldIgnoreCase} = $value;
}

sub shouldIgnoreAccents {
    my ($self) = @_;
    return $self->{shouldIgnoreAccents};
}

sub setShouldIgnoreAccents {
    my ($self, $value) = @_;
    $self->{shouldIgnoreAccents} = $value;
}
1;