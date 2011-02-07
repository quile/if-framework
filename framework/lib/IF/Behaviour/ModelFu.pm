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

package IF::Behaviour::ModelFu;

use strict;
use IF::Array;
use PF::String;
use vars qw(@EXPORT);
use Exporter 'import';
@EXPORT = qw(
    Model
    This
    hasOne
    belongsTo
    hasMany
    hasManyToMany
);

# usesTable
# withPrimaryKey
# inheritsFrom
# withDetailedGeographicInformation
# withCityGeographicInformation
# withValueForKey
# hasWatchedAttributes

# ModelFu is the working name
# This behaviour endows a class with the ability to represent itself in
# the model very simply.  Furthermore, the Model.pmodel file doesn't
# need to contain the fully expanded junk that models the relationships
# and instead that information is contained in the class itself.  This
# is achieved using directives:
#
# hasMany("User")->called("users")->joinedThrough("FOO_X_USER");
#
# or
#
# hasOne("Secret")->called("noneOfYourBusiness")
#
#
# The ideal way is to simply specify the most basic thing possible:
#
# hasOne("Nose")
#
# and the defaults will intelligently produce
#
# nose => {
#    TARGET_ENTITY => "Nose",
#    SOURCE_ATTRIBUTE => q(ID),
#    TARGET_ATTRIBUTE => q(FOO_ID),
#    TYPE => "TO_ONE",
# }
#
# which you can customise by stringing together clauses.
#
# For most cases, the defaults should be enough.

# For the Model stuff, each entity should declare the information like this:
#
# Model (
#     hasOne(...),
#     hasMany(...),
#     usesTable("Foo")->withPrimaryKey("ARGH_ID"),
# );

#-------------------------------------------------------------------
# Dealing with the entry in the model:
#-------------------------------------------------------------------
# The default implementation is to return the primary key and
# table name

sub Model {
    my ($className) = @_;
    my $c = $className || caller();
    $c =~ s/.*:://g;
    $c = IF::Behaviour::ModelFu::_Identifier->new($c);
    return
        This()->usesTable($c->asConstant())->withPrimaryKey("ID")
}

sub __modelEntryOfClassFromArray {
    my ($class, $ecdClass, @tweaks) = @_;

    my $ecd = $ecdClass->new({});
    my @defaults = IF::Behaviour::ModelFu::Model($class);
    foreach my $g (@defaults, @tweaks) {
        if (UNIVERSAL::isa($g, "IF::Behaviour::ModelFu::_Relationship")) {
          $ecd->{RELATIONSHIPS}->{$g->name()} = $g->details();
        } elsif (UNIVERSAL::isa($g, "IF::Behaviour::ModelFu::_ModelTweak")) {
            foreach my $k (@{$g->allKeys()}) {
                $ecd->{$k} = $g->valueForKey($k);
            }
        }
    }
    #print Data::Dumper->Dump([$ecd], [qw($ecd)]);

    return IF::EntityClassDescription->new($ecd);
}

sub This {
    return IF::Behaviour::ModelFu::_ModelTweak->new();
}

#-------------------------------------------------------------------
# Relationship handling
#-------------------------------------------------------------------

sub hasOne {
    my ($class, $entityName) = @_;
    $entityName ||= $class;
    my $r = IF::Behaviour::ModelFu::_Relationship->new();
    my $e = IF::Behaviour::ModelFu::_Identifier->new($entityName);
    my $cl = caller();
    $cl =~ s/.*:://g;
    my $c = IF::Behaviour::ModelFu::_Identifier->new($cl);
    $r->setName($e->asAttribute());
    $r->setDetails({
        TARGET_ENTITY => $entityName,
        SOURCE_ATTRIBUTE => q(ID),
        TARGET_ATTRIBUTE => $c->asForeignKey(),
        TYPE => "TO_ONE",
    });
    return $r;
}

sub belongsTo {
    my ($class, $entityName) = @_;
    $entityName ||= $class;
    my $r = IF::Behaviour::ModelFu::_Relationship->new();
    my $e = IF::Behaviour::ModelFu::_Identifier->new($entityName);
    $r->setName($e->asAttribute());
    $r->setDetails({
        TARGET_ENTITY => $entityName,
        SOURCE_ATTRIBUTE => $e->asForeignKey(),
        TARGET_ATTRIBUTE => q(ID),
        TYPE => "TO_ONE",
    });
    return $r;
}

sub hasMany {
    my ($class, $entityName) = @_;
    $entityName ||= $class;
    my $r = IF::Behaviour::ModelFu::_Relationship->new();
    my $e = IF::Behaviour::ModelFu::_Identifier->new($entityName);

    my $cl = caller();
    $cl =~ s/.*:://g;
    my $c = IF::Behaviour::ModelFu::_Identifier->new($cl);

    $r->setName($e->asPlural()->asAttribute());
    $r->setDetails({
        TARGET_ENTITY => $entityName,
        SOURCE_ATTRIBUTE => q(ID),
        TARGET_ATTRIBUTE => $c->asForeignKey(),
        TYPE => "TO_MANY",
    });
    return $r;
}

sub hasManyToMany {
    my ($class, $entityName) = @_;
    $entityName ||= $class;
    my $r = IF::Behaviour::ModelFu::_Relationship->new();
    my $e = IF::Behaviour::ModelFu::_Identifier->new($entityName);
    # this default assumption says that if Foo::Bar::Wank is the classname
    # then the entity name is Wank
    my $cl = caller();
    $cl =~ s/.*:://g;
    my $c = IF::Behaviour::ModelFu::_Identifier->new($cl);
    # guess the join table name
    my $jt = $c->asConstant()."_X_".$e->asConstant();

    # build the relationship
    $r->setName($e->asPlural()->asAttribute());
    $r->setDetails({
        TARGET_ENTITY => $entityName,
        SOURCE_ATTRIBUTE => q(ID),
        JOIN_TARGET_ATTRIBUTE => $c->asForeignKey(),
        JOIN_SOURCE_ATTRIBUTE => $e->asForeignKey(),
        TARGET_ATTRIBUTE => q(ID),
        TYPE => "FLATTENED_TO_MANY",
        JOIN_TABLE => $jt,
    });
    return $r;
}

# This inner class is used by the system to represent a relationship
package IF::Behaviour::ModelFu::_Relationship;
# Maybe make this descend from IF::Relationship?
use strict;
use base qw(
    IF::Array
);

sub new {
    my ($class) = @_;
    my $self = $class->SUPER::new();
    return bless ($self, $class);
}

sub name {
    my ($self) = @_;
    return $self->[0];
}

sub setName {
    my ($self, $value) = @_;
    $self->[0] = $value;
}

sub details {
    my ($self) = @_;
    return $self->[1] ||= {};
}

sub setDetails {
    my ($self, $value) = @_;
    $self->[1] = $value;
}

# These are used to alter a relationship on the fly

sub called {
    my ($self, $name) = @_;
    $self->setName($name);
    return $self;
}

sub deleteBy {
    my ($self, $value) = @_;
    $self->details()->{DELETION_RULE} = $value;
    return $self;
}

sub withTargetAttribute {
    my ($self, $value) = @_;
    $self->details()->{TARGET_ATTRIBUTE} = $value;
    return $self;
}

sub withSourceAttribute {
    my ($self, $value) = @_;
    $self->details()->{SOURCE_ATTRIBUTE} = $value;
    return $self;
}

sub joinedThrough {
    my ($self, $value) = @_;
    $self->details()->{JOIN_TABLE} = $value;
    return $self;
}

sub orderedBy {
    my $self = shift;
    my $value = IF::Array->new()->initWithArray(@_);
    $self->details()->{DEFAULT_SORT_ORDERINGS} = $value;
    return $self;
}

sub isMandatory {
    my $self = shift;
    $self->details()->{IS_MANDATORY} = 1;
    return $self;
}

sub isReadOnly {
    my $self = shift;
    $self->details()->{IS_READ_ONLY} = 1;
    return $self;
}

sub reciprocalRelationshipName {
    my $self = shift;
    my $value = shift; #IF::Array->new()->initWithArray(@_);
    $self->details()->{RECIPROCAL_RELATIONSHIP_NAME} = $value;
    return $self;
}

sub withQualifier {
    my ($self, $q, $bv) = @_;
    if (ref($q)) {
        $self->details()->{QUALIFIER} = $q;
    } else {
        if (defined $bv) {
            $self->details()->{QUALIFIER} = IF::Qualifier->key($q, $bv);
        } else {
            $self->details()->{QUALIFIER} = IF::Qualifier->key($q);
        }
    }
    return $self;
}

sub withJoinQualifiers {
    my ($self, $v) = @_;
    $self->details()->{JOIN_QUALIFIERS} = $v;
    return $self;
}

sub withRelationshipHints {
    my ($self, $v) = @_;
    $self->details()->{RELATIONSHIP_HINTS} = $v;
    return $self;
}

# use this to add something else
sub withKeyValuePairs {
    my $self = shift;
    my $kvps = { @_ };
    $self->setDetails({ %{$self->details()}, %$kvps });
    return $self;
}

sub withValueForKey {
    my ($self, $value, $key) = @_;
    $self->details()->{$key} = $value;
    return $self;
}

#-------------------------------------------------------------------
# This inner class is used by the system to represent an identifier
package IF::Behaviour::ModelFu::_Identifier;

use strict;
use base qw(
    PF::String
);

sub _setString {
    my ($self, $value) = @_;
    if ($value =~ m/^[a-z][a-zA-Z0-9]+$/o ||
        $value =~ m/^[A-Z][a-zA-Z0-9]+$/o) {
        $self->{_string} = IF::Interface::KeyValueCoding::keyNameFromNiceName($value);
    } else {
        $self->{_string} = $value;
    }
}

sub asCamelCase {
    my ($self) = @_;
    return ucfirst(IF::Interface::KeyValueCoding::niceName($self->{_string}));
}

sub asAttribute {
    my ($self) = @_;
    return IF::Interface::KeyValueCoding::niceName($self->{_string});
}

# hack for now
sub asPlural {
    my ($self) = @_;
    my $s = $self->{_string};
    # dumb plural... if it ends in consonant-y then make it -ies
    # otherwise make it -s
    if ($s =~ m/[^aeiou]y$/io) {
        $s =~ s/y$/IES/ig;
    } else {
        $s .= "S";
    }
    return IF::Behaviour::ModelFu::_Identifier->new($s);
}

sub asConstant {
    my ($self) = @_;
    return $self->{_string};
}

# braindead default... but it should work!
sub asForeignKey {
    my ($self) = @_;
    return $self->asConstant()."_ID";
}

#-----------------------------------------
# This is a bit cheesy.  Instances of
# this adapt the Model definition
#-----------------------------------------
package IF::Behaviour::ModelFu::_ModelTweak;

use strict;
use base qw(
    IF::Dictionary
);

sub usesTable {
    my ($self, $value) = @_;
    return $self->withValueForKey($value, "TABLE");
}

sub withPrimaryKey {
    my ($self, $value) = @_;
    return $self->withValueForKey($value, "PRIMARY_KEY");
}

sub inheritsFrom {
    my ($self, $value) = @_;
    return $self->withValueForKey($value, "PARENT_ENTITY");
}

sub hasWatchedAttributes {
    my ($self, $value) = @_;
    return $self->withValueForKey($value, "WATCHED_ATTRIBUTES");
}

sub withValueForKey {
    my ($self, $value, $key) = @_;
    $self->setValueForKey($value, $key);
    return $self;
}

sub withDetailedGeographicInformation {
    my ($self) = @_;
    my $value = {
		COUNTRY_NAME 		=> "country",
		STATE_NAME   		=> "state",
		CITY_NAME    		=> "city",
		METRO_AREA_NAME    	=> "metroArea",
		ADDRESS1_NAME       => "add1",
		ADDRESS2_NAME       => "add2",
	};
    return $self->withValueForKey($value, "GEOGRAPHIC_ATTRIBUTE_KEYS");
}

sub withCityGeographicInformation {
    my ($self) = @_;
    my $value = {
		COUNTRY_NAME 		=> "country",
		STATE_NAME   		=> "state",
		CITY_NAME    		=> "city",
		METRO_AREA_NAME    	=> "metroArea",
	};
    return $self->withValueForKey($value, "GEOGRAPHIC_ATTRIBUTE_KEYS");
}

1;
