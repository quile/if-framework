package IF::Component::_Admin::Model::EntitySearchResults;
use strict;
use base qw(IF::Component::_Admin::Model::EntityPage);
use IF::Utility;

sub init {
	my $self = shift;
	$self->SUPER::init(@_);
	$self->setSearchTerms(IF::Dictionary->new());
	$self->setSynchronizesBindingsWithParent(0);
}

sub pushValuesToParent {
	my $self = shift;
	return;
}

sub submitAction {
	my $self = shift;
	my $context = shift;

	my $searchTerms = IF::Dictionary->new();
	# get the search terms from the query string
	foreach my $key ($context->formKeys()) {
		$searchTerms->setObjectForKey($context->formValueForKey($key), $key);
	}

	my $nextPage = $self->pageWithName("_Admin::Model::EntitySearch");
	$nextPage->setSearchTerms($searchTerms);
	$nextPage->setEntityClassDescription($self->entityClassDescription());
	$nextPage->setControllerClass($self->controllerClass());
	return $nextPage->invokeDirectActionNamed("submit", $context);
}

sub setSearchTerms {
	my $self = shift;
	$self->{searchTerms} = shift;
}

sub searchTerms {
	my $self = shift;
	return $self->{searchTerms};
}

sub searchResults {
	my $self = shift;
	return $self->{searchResults};
}

sub setSearchResults {
	my ($self, $value) = @_;
 	$self->{searchResults} = $value;
}

sub countOfSearchResults {
	my $self = shift;
	return $self->{countOfSearchResults};
}

sub setCountOfSearchResults {
	my $self = shift;
	$self->{countOfSearchResults} = shift;
}

sub isShownInline {
	my ($self) = @_;
	return $self->{isShownInline};
}

sub setIsShownInline {
	my ($self, $value) = @_;
	$self->{isShownInline} = $value;
}
sub aSearchResult {
	my $self = shift;
	return $self->{aSearchResult};
}

sub setASearchResult {
	my $self = shift;
	$self->{aSearchResult} = shift;
}

sub resultIsAsset {
	my $self = shift;
    return 0;
}

sub resultUsesAssetViewer {
	my $self = shift;
	return ($self->resultIsAsset() && !$self->summaryAttributeNames());
}

sub attributes {
	my $self = shift;
	unless ($self->{_attributes}) {
		$self->{_attributes} = $self->entityClassDescription()->orderedAttributes();
	}
#IF::Log::dump($self->{_attributes});
	return $self->{_attributes};
}

sub summaryAttributeNames {
	my ($self) = @_;
	my $entityTypeName = $self->entityClassDescription()->name();
	my $names = $self->controller()->summaryAttributesForEntityType($entityTypeName);
	return $names;
}

sub summaryAttributeNamesWithDefaults {
	my ($self) = @_;
	my $names = $self->summaryAttributeNames();
	unless ($names && scalar @$names) {
		$names = [$self->attributes()->[0]->{ATTRIBUTE_NAME}, $self->attributes()->[1]->{ATTRIBUTE_NAME}];
	}
	return $names;
}

sub filterNewLinesAndQuotes {
    my ($self, $value) = @_;
	$value =~ s/[\r\n\t]/ /g;
	$value =~ s/"/\\"/g;
	$value = IF::Utility::escapeHtml($value);
	return $value;
}

sub hasNextPage {
	my $self = shift;
	my $batchSize = $self->fetchLimit();
	my $startIndex = int($self->searchTerms()->objectForKey("startIndex"));
	return ($startIndex + $batchSize) < $self->countOfSearchResults();
}

sub fetchLimit {
	my $self = shift;
	$self->searchTerms()->objectForKey("fetchLimit") ||
		$self->application()->configurationValueForKey("DEFAULT_BATCH_SIZE");
}

sub nextPageQueryDictionary {
	my $self = shift;

	my $newDictionary = IF::Dictionary->new($self->searchTerms());
	$newDictionary->setObjectForKey($self->searchTerms()->objectForKey("startIndex") +
									$self->fetchLimit(), "startIndex");
	$newDictionary->setObjectForKey($self->entityClassDescription()->name(), "entity-class-name");
	$newDictionary->setObjectForKey($self->controllerClass(), "controller-class");
	return $newDictionary;
}

sub previousPageQueryDictionary {
	my $self = shift;
	my $newDictionary = IF::Dictionary->new($self->searchTerms());
	$newDictionary->setObjectForKey($self->searchTerms()->objectForKey("startIndex") -
									$self->fetchLimit(), "startIndex");
	$newDictionary->setObjectForKey($self->entityClassDescription()->name(), "entity-class-name");
	$newDictionary->setObjectForKey($self->controllerClass(), "controller-class");
	return $newDictionary;
}

# this might need some more contextual info?
sub shouldShowDeleteLink {
	my ($self) = @_;
	return 1 unless $self->controller();
	return $self->controller()->shouldShowDeleteLinkForEntity($self->{aSearchResult});
}

1;