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

package IF::Model;

use strict;
use base qw(
	IF::Interface::KeyValueCoding
);
#===========================================
use IF::Application;
use IF::DB;
use IF::Log;
use IF::EntityClassDescription;
use IF::Behaviour::ModelFu;
#===========================================

sub entityClassDescriptionClassName { return "IF::EntityClassDescription" }

# TODO refactor this nonsense
sub new {
	my ($className, $modelPath) = @_;
	IF::Log::debug("Loading in model found at $modelPath");
	my $self = do "$modelPath";
	unless ($self) {
		IF::Log::error("Cannot load model $modelPath: $@ - This is fatal unless it's the first time you're generating the model.");
		return;
	}
	bless $self, $className;

	# by this point we have an empty model.
    IF::Log::debug("Populating model loaded from $modelPath");

    $self->populateModel();

	IF::Log::debug("---> done populating");
	# Instantiate entity class descriptions for every entity type,
	# which forces the class to cache each one
	foreach my $entityClass (sort keys %{$self->{ENTITIES}}) {
		IF::Log::debug("Caching entity class description for $entityClass");
		my $entityClassDescription = $self->entityClassDescriptionForEntityNamed($entityClass);
	}
	IF::Log::debug("Loaded and populated model");
	return $self;
}

my $_defaultModel;

sub defaultModel {
	return $_defaultModel;
}

sub setDefaultModel {
	my $className = shift;
	$_defaultModel = shift;
	#IF::Log::error("Set default model to $_defaultModel");
}

sub entityRoot {
    my ($self) = @_;
    return undef;
}

sub entityRecordForKey {
	my $self = shift;
	my $key = shift;
	return $self->entityClassDescriptionForEntityNamed($key);
}

{
	my $_entityClassDescriptionCache = {};

	sub entityClassDescriptionForEntityNamed {
		my $self = shift;
		my $entityName = shift;

		return $_entityClassDescriptionCache->{$entityName} if $_entityClassDescriptionCache->{$entityName};

		my $ecdClassName = $self->entityClassDescriptionClassName();
		# if ecdClassName doesn't exist, this will yack, but that's ok
		# because if this ain't workin', ain't nothin' workin'.
		IF::Log::debug("Trying to load $ecdClassName for $entityName");
		my $entityClassDescription = $ecdClassName->new($self->{ENTITIES}->{$entityName});
		return unless $entityClassDescription;
		$entityClassDescription->setValueForKey($entityName, "NAME");
		$_entityClassDescriptionCache->{$entityName} = $entityClassDescription;
		return $entityClassDescription;
	}
}

sub entityClassDescriptionForTable {
    my ($self, $table) = @_;
    foreach my $en (keys %{$self->{ENTITIES}}) {
        my $ecd = $self->{ENTITIES}->{$en};
        return $ecd if $ecd->{TABLE} eq $table;
    }
    return undef;
}

sub brokerRecordForKey {
	my $self = shift;
	my $key = shift;
	return $self->{BROKERS}->{$key};
}

sub entityNamespace {
	my $self = shift;
	return $self->{NAMESPACE}->{ENTITY};
}

sub relationshipWithNameOnEntity {
	my ($self, $relationshipName, $entityName) = @_;

	my $entity = $self->entityRecordForKey($entityName);
	return undef unless $entity;
	my $relationships = $entity->relationships();
	return undef unless $relationships;
	return $relationships->{$relationshipName};
}

sub allEntityClassKeys {
	my $self = shift;
	return [keys %{$self->{ENTITIES}}];
}

sub populateModel {
    my ($self) = @_;
    die "Your model class must implement populateModel()";
}

1;
