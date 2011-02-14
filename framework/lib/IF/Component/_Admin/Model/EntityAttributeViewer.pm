package IF::Component::_Admin::Model::EntityAttributeViewer;

use strict;
use vars qw(@ISA);
use IF::Component;
use IF::Dictionary;
@ISA = qw(IF::Component::_Admin);

sub attribute {
    my $self = shift;
    return $self->{attribute} || {};
}

sub setAttribute {
    my $self = shift;
    $self->{attribute} = shift;
}

sub value {
    my $self = shift;
    return $self->{value};
}

sub setValue {
    my $self = shift;
    $self->{value} = shift;
    #IF::Log::dump($self->{value});
}

sub filter {
    my $self = shift;
    return $self->{filter};
}

sub setFilter {
    my $self = shift;
    $self->{filter} = shift;
}

sub filteredValue {
    my $self = shift;
    my $value = shift;
    return $value unless ($self->parent() &&
                   $self->filter() &&
                   $self->parent()->can($self->filter()));
    my $filterMethod = $self->filter();
    return $self->parent()->$filterMethod($value);
}

# some gearing for the component

sub attributeIsTextArea {
    my $self = shift;
    return 1 if ($self->attribute()->{TYPE} =~ /^TEXT$/i);
    return 1 if ($self->attribute()->{TYPE} =~ /^VARCHAR$/i && $self->attribute()->{SIZE} > 80);
    return 1 if ($self->attribute()->{TYPE} =~ /^CHAR$/i && $self->attribute()->{SIZE} > 80);
    return 0;
}

sub attributeIsDate {
    my $self = shift;
    return 1 if ($self->attribute()->{TYPE} =~ /^DATE$/i);
    return 0;
}

sub attributeIsDateTime {
    my $self = shift;
    return 1 if ($self->attribute()->{TYPE} =~ /^DATETIME$/i);
    return 1 if ($self->attributeIsUnixTime());
    return 0;
}

sub attributeIsNumber {
    my $self = shift;
    return 1 if ($self->attribute()->{TYPE} =~ /int$/i &&
                 !$self->attributeIsUnixTime() &&
                 !$self->attributeIsYesNo);
    return 0;
}

sub attributeIsUnixTime {
    my $self = shift;
    return 1 if ($self->attribute()->{TYPE} =~ /int$/i &&
                 $self->attribute()->{SIZE} == 11 &&
                 $self->attribute()->{COLUMN_NAME} =~ /_DATE$/i);
    return 0;
}

sub attributeIsAreasOfFocus {
    my $self = shift;
    return 1 if ($self->attribute()->{COLUMN_NAME} =~ /category/i && 
                 $self->entityClassName() =~ /^(Job|Internship|VolunteerOpportunity|Org|Materials|Event)$/);
    return 1 if ($self->attribute()->{COLUMN_NAME} =~ /^AREAS_OF_FOCUS$/i);
    return 0;
}

sub attributeIsYesNo {
    my $self = shift;
    return 1 if ($self->attribute()->{TYPE} =~ /^tinyint$/i);
    return 0;
}

sub attributeIsLanguageDesignation {
    my $self = shift;
    return ($self->attribute()->{COLUMN_NAME} =~ /^LANGUAGE_DESIGNATION$/i);
}

sub attributeIsLanguage {
    my $self = shift;
    return ($self->attribute()->{COLUMN_NAME} =~ /^LANGUAGE$/i);
}

sub attributeIsArray {
    my $self = shift;
    #IF::Log::dump($self->value());
    return IF::Array::isArray($self->value());
}

sub attributeArrayAsString {
    my $self = shift;
    return join(", ", @{$self->value()});
}

sub entityClassName {
    my $self = shift;
    return $self->{entityClassName};
}

sub setEntityClassName {
    my $self = shift;
    $self->{entityClassName} = shift;
}


1;

