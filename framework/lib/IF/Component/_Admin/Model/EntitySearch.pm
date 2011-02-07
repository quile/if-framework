package IF::Component::_Admin::Model::EntitySearch;

use strict;
use base qw(
	IF::Component::_Admin::Model::EntityPage
);

sub init {
	my $self = shift;
	$self->SUPER::init(@_);
	$self->setSearchTerms(IF::Dictionary->new());
}

sub takeValuesFromRequest {
	my $self = shift;
	my $context = shift;
	$self->setEntityClassDescription(
			$self->model()->entityClassDescriptionForEntityNamed($context->formValueForKey("entity-class-name"))
									 );
	$self->SUPER::takeValuesFromRequest($context);
}

sub submitAction {
	my $self = shift;
	my $context = shift;
	return unless $self->hasValidFormValues($context);

	my $fetchSpecification = $self->fetchSpecificationFromSearchTermDictionary();
	my $countOfEntities = $self->objectContext()->countOfEntitiesMatchingFetchSpecification($fetchSpecification);
	return unless $countOfEntities;
	my $entities = $self->objectContext()->entitiesMatchingFetchSpecification($fetchSpecification);
	my $nextPage = $self->pageWithName("_Admin::Model::EntitySearchResults");
	$nextPage->setCountOfSearchResults($countOfEntities);
	$nextPage->setSearchResults($entities);
	$nextPage->setEntityClassDescription($self->entityClassDescription());
	$nextPage->setSearchTerms($self->searchTerms());
	if ($self->rootEntity()) {
		$nextPage->setRootEntity($self->rootEntity());
		$nextPage->setRootEntityClassDescription($self->rootEntity()->entityClassDescription());
	}
	$nextPage->setController($self->controller());
	return $nextPage;
}

sub searchTerms {
	my $self = shift;
	return $self->{dictionary};
}

sub setSearchTerms {
	my $self = shift;
	$self->{dictionary} = shift;
}

sub fetchSpecificationFromSearchTermDictionary {
	my $self = shift;
	my $qualifiers = [];
	
	# TODO: fix this broken system where one component "helps" another out.
	# Instead we need to have a separate "manager" class that can hold all
	# the "helper" methods
	my $fetchSpecification = IF::FetchSpecification->new($self->entityClassDescription()->name());
	$fetchSpecification->setFetchLimit($self->application()->configurationValueForKey("DEFAULT_BATCH_SIZE"));
	my $searchFieldEditor = $self->subcomponentForBindingNamed("ENTITY_SEARCH_EDITOR");
	my $operands = {};
	foreach my $key (@{$self->searchTerms()->allKeys()}) {
		next unless $key =~ /^(.*):operand$/;
		$operands->{$1} = $self->searchTerms()->objectForKey($key);
	}
	foreach my $key (@{$self->searchTerms()->allKeys()}) {
		next if $key =~ /:operand$/;
		next unless $self->searchTerms()->objectForKey($key) ne "";
		my $attributeKey = $key;
		if ($key =~ /^(.*):end$/ || $key =~ /^(.*):start$/) {
			$attributeKey = $1;
		}
		my $attribute = $self->entityClassDescription()->attributeWithName($attributeKey);
		if ($attribute) {
			$searchFieldEditor->setAnAttribute($attribute);
			if ($searchFieldEditor->attributeIsUnixTime() || 
				$searchFieldEditor->attributeIsDateTime() || 
				$searchFieldEditor->attributeIsDate()) {
				if ($key =~ /(.*):end$/) {
					push (@$qualifiers, IF::Qualifier->key($attributeKey." < %@", $self->searchTerms()->objectForKey($key)));
				}
				if ($key =~ /(.*):start$/) {
					push (@$qualifiers, IF::Qualifier->key($attributeKey." >= %@", $self->searchTerms()->objectForKey($key)));
				}
			} elsif ($searchFieldEditor->shouldUsePackedValuesForAttributeNamed($attributeKey)) {
				my $values = [split(/\s+/, $self->searchTerms()->objectForKey($key))];
				my $valueQualifiers = [];
				foreach my $value (@$values) {
					next if ($value eq "");
					push (@$valueQualifiers, IF::Qualifier->key($key ." REGEXP '(^| )$value( |\$)'"));
				}
				push (@$qualifiers, IF::Qualifier->new("OR", $valueQualifiers));
			} else {
				my $operand = $operands->{$key} || "contains";

				if ($operand eq "is" || $operand eq "equals") {
					push (@$qualifiers, IF::Qualifier->key($key." = %@", $self->searchTerms()->objectForKey($key)));
				} elsif ($operand eq "is not" || $operand eq "does not equal") {
					push (@$qualifiers, IF::Qualifier->key($key." <> %@", $self->searchTerms()->objectForKey($key)));
				} elsif ($operand =~ /^[<=>]+$/) {
					push (@$qualifiers, IF::Qualifier->key($key." $operand %@", $self->searchTerms()->objectForKey($key)));
				} elsif ($operand eq 'starts with') {
					push (@$qualifiers, IF::Qualifier->key($key." LIKE '".$self->searchTerms()->objectForKey($key)."%'"));
				} elsif ($operand eq "does not contain") {
					push (@$qualifiers, IF::Qualifier->key($key." NOT LIKE '%".$self->searchTerms()->objectForKey($key)."%'"));
				}else {
					push (@$qualifiers, IF::Qualifier->key($key." LIKE '%".$self->searchTerms()->objectForKey($key)."%'"));
				}
			}
		} else {
			if ($key eq "startIndex") {
				$fetchSpecification->setStartIndex($self->searchTerms()->objectForKey($key));
				IF::Log::debug("Setting start index to ".$self->searchTerms()->objectForKey($key));
			} elsif ($key eq "fetchLimit") {
				$fetchSpecification->setFetchLimit($self->searchTerms()->objectForKey($key));
			} else {
				IF::Log::warning("Unknown attribute $key in dictionary");
			}
		}
	}
	$fetchSpecification->setQualifier(IF::Qualifier->and($qualifiers));
	return $fetchSpecification;
}

1;

