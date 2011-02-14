package IF::Component::_Admin::Model::EntityFieldEditor;

use strict;
use base qw(IF::Component::_Admin);

sub init {
    my $self = shift;
    $self->SUPER::init();
    $self->_setDictionary(IF::Dictionary->new());
}

sub takeValuesFromRequest {
    my ($self, $context) = @_;

    $self->SUPER::takeValuesFromRequest($context);

    # Nasty:  TODO:fix this crap when the renderer/rewinder is fixed
    # inflate the uninflated values from context
    #$self->decodeDateWidgetsInContext($context);
    my $entityClassName = $self->entityClassName();

    foreach my $formKey ($context->formKeys()) {
        next unless ($formKey =~ /^$entityClassName-(.*)$/ ||
                     $formKey =~ /^end-$entityClassName-(.*)/ ||
                     $formKey =~ /^start-$entityClassName-(.*)/);
        next if ($formKey =~ /-operand$/);
        my $objectKey = $1;
        #IF::Log::debug($objectKey);
        next unless $objectKey;
        my $value = $context->formValueForKey($formKey);
        my $values = $context->formValuesForKey($formKey);

        if ($self->shouldUsePackedValuesForAttributeNamed($objectKey)) {
            $value = IF::Utility::packValuesUsingDelimiter($value, " ");
        }
        if ($self->shouldUseUnixTimeForAttributeNamed($objectKey)) {
            IF::Log::debug("Converting $value to unix time");
            my $date = IF::GregorianDate->new($value);
            $value = $date->utc();
            IF::Log::debug("... to value $value, which is ".IF::Utility::sqlDateTimeFromUnixTime($value)." when converted back");
        }
        if ($formKey =~ /^start-/) {
            $objectKey = $objectKey.":start";
        } elsif ($formKey =~ /^end-/) {
            $objectKey = $objectKey.":end";
        }
        if ($context->formValueForKey($formKey."-operand") && $context->formValueForKey($formKey)) {
            $self->_dictionary()->setValueForKey($context->formValueForKey($formKey."-operand"), $objectKey.":operand");
        }
        $self->_dictionary()->setValueForKey($value, $objectKey);
        IF::Log::debug("$objectKey = $value");
    }
    #IF::Log::dump($self->_dictionary());
    # transfer values from dictionary to entity
    # ...
    # re-inflate entity
    unless ($self->entity()) {
        if ($entityClassName) {
            my $model = IF::Model->defaultModel();
            my $ecd = $model->entityClassDescriptionForEntityNamed($entityClassName);
            if ($ecd) {
                my $primaryKey = $ecd->_primaryKey();
                $self->setEntity($self->objectContext()->entityWithPrimaryKey($entityClassName,
                                                                      $self->_dictionary()->objectForKey($primaryKey),
                                                                      ));
            }
        }
    }
    #IF::Log::dump($self->entity());
    foreach my $key (@{$self->_dictionary()->allKeys()}) {
        $self->entity()->setValueForKey($self->_dictionary()->objectForKey($key), $key);
        IF::Log::debug("Object key $key has value ".$self->entity()->valueForKey($key)." and dictionary is ".$self->_dictionary()->objectForKey($key));
    }
    #IF::Log::dump($self->entity());
}

sub defaultAction {
    my $self = shift;
    my $context = shift;
    return undef;
}

sub entity {
    my $self = shift;
    return $self->{entity};
}

sub setEntity {
    my ($self, $value) = @_;
    unless (IF::Log::assert(UNIVERSAL::isa($value, 'IF::Entity'), "Setting entity on EntityFieldEditor with an IF::Entity descendant.")) {
        # Removed the die added in r11678 as it was "killing" the ability to add StringSymbols to a
        # StringGroup.  Not sure the original reasoning...Scott this okay?
         IF::Log::error("EntityFieldEditor: tried to set entity with an invalid value...");
        IF::Log::dump($value);
    }
    $self->{entity} = $value;
    IF::Log::debug("Setting entity to $value");
}

sub _dictionary {
    my $self = shift;
    return $self->{_dictionary};
}

sub _setDictionary {
    my $self = shift;
    $self->{_dictionary} = shift;
}

sub attributes {
    my $self = shift;
    return [] unless $self->entity();
    return [] unless (
        UNIVERSAL::isa($self->entity(),'IF::Entity')
     || UNIVERSAL::isa($self->entity(),'IF::Dictionary')
    );
    unless ($self->{_attributes}) {
        # start with the attributes in an order guessed by the fw
        my $orderedAttributes = $self->entity()->entityClassDescription()->orderedAttributes();
        # remove explicitly hidden ones
        my $hiddenAttributes = {};
        foreach my $hiddenAttribute (@{$self->hiddenAttributes()}) {
            $hiddenAttributes->{$hiddenAttribute} = 1;
        }

        # filter out hidden attributes
        my $attributes = [];
        foreach my $attribute (@$orderedAttributes) {
            next if $hiddenAttributes->{$attribute};
            push (@$attributes, $attribute);
        }

        # order by the explictly provided list if available
        my $order = $self->attributeDisplayOrder();
        if (scalar @$order) {
            unless (scalar @$order == scalar @$attributes) {
                IF::Log::error("Count of attributes and names in dislpay order do not match.");
            }
            my %attributeHash = map {$_->{ATTRIBUTE_NAME} => $_} @$attributes;
            IF::Log::debug("banana - ordering");
            IF::Log::dump(\%attributeHash);
            my @orderedAttributes = map {$attributeHash{$_}} @$order;
            IF::Log::dump(\@orderedAttributes);
            $attributes = \@orderedAttributes;
        }

        # for new entities, don't show id, creationDate and modificationDate
        if ($self->entity()->hasNeverBeenCommitted()) {
            $self->{_attributes} = [];
            foreach my $attribute (@$attributes) {
                next if ($attribute->{COLUMN_NAME} =~ /^id$/i);
                next if ($attribute->{COLUMN_NAME} =~ /^CREATION_DATE$/i);
                next if ($attribute->{COLUMN_NAME} =~ /^MODIFICATION_DATE$/i);
                push (@{$self->{_attributes}}, $attribute);
            }
        } else {
            $self->{_attributes} = $attributes;
        }


    }
    return $self->{_attributes};
}

sub anAttribute {
    my $self = shift;
    return $self->{anAttribute} || {};
}

sub setAnAttribute {
    my $self = shift;
    $self->{anAttribute} = shift;
}

sub entityClassName {
    my $self = shift;
    return $self->{_entityClassName} if $self->{_entityClassName};
    return unless $self->entity();
    return $self->entity()->entityClassDescription()->name();
}

sub setEntityClassName {
    my $self = shift;
    $self->{_entityClassName} = shift;
}

# some gearing for the component

sub attributeIsTextArea {
    my $self = shift;
    return 1 if ($self->anAttribute()->{TYPE} =~ /^(?:MEDIUM|LONG)?TEXT$/i);
    return 1 if ($self->anAttribute()->{TYPE} =~ /^VARCHAR$/i && $self->anAttribute()->{SIZE} > 512);
    return 1 if ($self->anAttribute()->{TYPE} =~ /^CHAR$/i && $self->anAttribute()->{SIZE} > 512);
    return 0;
}

sub attributeIsDate {
    my $self = shift;
    return 1 if ($self->anAttribute()->{TYPE} =~ /^DATE$/i);
    return 0;
}

sub attributeIsDateTime {
    my $self = shift;
    return 1 if ($self->anAttribute()->{TYPE} =~ /^DATETIME$/i);
    return 0;
}

sub attributeIsNumber {
    my $self = shift;
    return 1 if ($self->anAttribute()->{TYPE} =~ /int$/i &&
                 !$self->attributeIsUnixTime() &&
                 !$self->attributeIsYesNo);
    return 0;
}

sub attributeIsUnixTime {
    my $self = shift;
    return 1 if ($self->anAttribute()->{TYPE} =~ /int$/i &&
                 $self->anAttribute()->{SIZE} == 11 &&
                 $self->anAttribute()->{COLUMN_NAME} =~ /_DATE$/i);
    return 0;
}

sub attributeIsEnum {
    my $self = shift;
    return 1 if ($self->anAttribute()->{TYPE} =~ /^ENUM$/i);
    return 0;
}

sub attributeIsCountry {
    my $self = shift;
    return 1 if ($self->anAttribute()->{COLUMN_NAME} =~ /country/i);
    return 0;
}

sub attributeIsAreasOfFocus {
    my $self = shift;
    return 1 if ($self->anAttribute()->{COLUMN_NAME} =~ /category/i &&
                 $self->entityClassName() =~ /^(Job|Internship|VolunteerOpportunity|Org|Materials|Event)$/);
    return 1 if ($self->anAttribute()->{COLUMN_NAME} =~ /^AREAS_OF_FOCUS$/i);
    return 0;
}

sub attributeIsYesNo {
    my $self = shift;
    return 1 if ($self->anAttribute()->{TYPE} =~ /^tinyint$/i);
    return 0;
}

sub attributeIsCustomChooser {
    my $self = shift;
    my $attributeName = $self->anAttribute()->{ATTRIBUTE_NAME};
    my $chooserName = $self->controller()->relationshipTargetChooserClassForAttributeOnEntityType(
        $attributeName,$self->entityClassName());
    return defined $chooserName;
}

sub relationship {
    my $self = shift;
    my $entity = $self->entity();
    return unless $entity;
    my $relationships = $entity->entityClassDescription()->relationships();
    return undef unless $relationships;
    for my $r (values %$relationships) {
        return $r if $r->{SOURCE_ATTRIBUTE} eq $self->anAttribute()->{COLUMN_NAME};
    }
    IF::Log::debug("Getting relationship for: ".$self->anAttribute()->{ATTRIBUTE_NAME});
    IF::Log::dump($self->anAttribute());
}

sub attributeCustomChooserClass {
    my $self = shift;
    my $attributeName = $self->anAttribute()->{ATTRIBUTE_NAME};
    my $chooserName = $self->controller()->relationshipTargetChooserClassForAttributeOnEntityType(
        $attributeName,$self->entityClassName());
    return $chooserName;
}

sub areasOfFocusSelectedValues {
    my $self = shift;
    return [] unless $self->entity();
    if ($self->anAttribute()->{COLUMN_NAME} =~ /category/i &&
        UNIVERSAL::can($self->entity(), "areasOfFocus")) {
        return $self->entity()->areasOfFocus();
    } else {
        my $areasOfFocus = $self->entity()->valueForKey($self->anAttribute()->{ATTRIBUTE_NAME});
        $areasOfFocus =~ s/^[^0-9]*//g;
        $areasOfFocus =~ s/[^0-9]*$//g;
        return [split(/[^0-9]+/, $areasOfFocus)];
    }
}

sub languageSelectedValues {
    my $self = shift;
    return [] unless $self->entity();
    my $languages = $self->entity()->valueForKey($self->anAttribute()->{ATTRIBUTE_NAME});
    $languages =~ s/^[^0-9]*//g;
    $languages =~ s/[^0-9]*$//g;
    return [split(/[^0-9]+/, $languages)];
}

sub attributeIsLanguageDesignation {
    my $self = shift;
    return ($self->anAttribute()->{COLUMN_NAME} =~ /^LANGUAGE_DESIGNATION$/i);
}

sub attributeIsLanguage {
    my $self = shift;
    return ($self->anAttribute()->{COLUMN_NAME} =~ /^LANGUAGE$/i);
}

sub attributeIsLanguageRelationship {
    my $self = shift;
    my $result = ($self->anAttribute()->{COLUMN_NAME} =~ /^LANGUAGE_ID$/i);
    return $result;
}

sub fieldNameForAttribute {
    my $self = shift;
    return $self->entityClassName()."-".$self->anAttribute()->{COLUMN_NAME};
}

sub entityValueForAttribute {
    my $self = shift;
    if ($self->entity()->can("storedValueForKey")) {
        return $self->entity()->storedValueForKey($self->anAttribute()->{ATTRIBUTE_NAME});
    }
    return $self->entity()->valueForKey($self->anAttribute()->{ATTRIBUTE_NAME});
}

sub maxLengthForAttribute {
    my $self = shift;
    return 0 unless $self->anAttribute();
    return $self->anAttribute()->{SIZE};
}

# this refers to the size of the input field, not the size of the
# actual data
sub sizeForAttribute {
    my $self = shift;
    return 40 unless $self->controller();
    my $default = $self->controller()->defautTextFieldWidth() || 40;
    if ($self->anAttribute() && ($self->anAttribute()->{SIZE} < $default)) {
        return $self->anAttribute()->{SIZE};
    }
    return $default;
}

sub decodeDateWidgetsInContext {
    my $self = shift;
    my $context = shift;
    my $dates = {};
    my $times = {};
    foreach my $formKey ($context->formKeys()) {
        if ($formKey =~ /SYYYY_(.*)$/ && $context->formValueForKey($formKey) ne "") {
            my $key = $1;
            my $date = IF::Utility::sqlDateFromDateWidgetNamed($context,  $key);
            $key =~ s/^incoming-date-//;
            $dates->{$key} = $date;
        } elsif ($formKey =~ /SHH_(.*)$/) {
            my $key = $1;
            my $time = IF::Utility::sqlTimeFromTimeWidgetNamed($context,  $key);
            $key =~ s/^incoming-time-//;
            $times->{$key} = $time;
        }
    }
    foreach my $key (keys %$dates) {
        my $dateTime = join(" ", $dates->{$key}, $times->{$key});
        $context->setFormValueForKey($dateTime, $key);
        IF::Log::debug("Set $key to $dateTime");
    }
}

# this is a hack and uses a side-effect to achieve its goal.
sub shouldUseUnixTimeForAttributeNamed {
    my $self = shift;
    my $attributeName = shift;
    my $entityClassDescription = IF::Model->defaultModel()->entityClassDescriptionForEntityNamed($self->entityClassName());
    return unless $entityClassDescription;
    $self->setAnAttribute($entityClassDescription->attributeWithName($attributeName));
    return $self->attributeIsUnixTime();
}

sub shouldUsePackedValuesForAttributeNamed {
    my $self = shift;
    my $attributeName = shift;
    my $entityClassDescription = IF::Model->defaultModel()->entityClassDescriptionForEntityNamed($self->entityClassName());
    return unless $entityClassDescription;
    $self->setAnAttribute($entityClassDescription->attributeWithName($attributeName));
    return $self->attributeIsAreasOfFocus() || $self->attributeIsLanguage();
}

sub hiddenAttributes {
    my $self = shift;
    return $self->{hiddenAttributes};
}

sub setHiddenAttributes {
    my $self = shift;
    $self->{hiddenAttributes} = shift;
}

sub attributeDisplayOrder {
    my ($self) = @_;
    return $self->{attributeDisplayOrder} || [];
}

sub setAttributeDisplayOrder {
    my ($self, $value) = @_;
    $self->{attributeDisplayOrder} = $value;
}

# TODO: move this into a component
sub languageRelationshipList {
    # my ($self) = @_;
    # my $langs = IF::Entity::Language->all();
    # my $list = [ map {KEY => $_->nativeNameString(), VALUE => $_->id()}, @$langs];
    # IF::Log::dump($list);
    # return $list;
    return [];
}

sub controller {
    my ($self) = @_;
    return $self->{controller};
}

sub setController {
    my ($self, $value) = @_;
    $self->{controller} = $value;
}

1;