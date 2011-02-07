package <TMPL_VAR NAME=TREE>::Entity::<TMPL_VAR NAME=CLASS>;

use strict;
use base qw(<TMPL_VAR NAME=TREE>::Entity);

<TMPL_IF NAME=BUILD_INIT_METHOD>sub init {
	my ($self) = @_;
	my $model = IF::Model->defaultModel();
	<TMPL_LOOP NAME=INITIALISATIONS>$self->{<TMPL_VAR NAME=KEY>} = $self->entityClassDescription()->defaultValueForAttribute("<TMPL_VAR NAME=KEY>");
	</TMPL_LOOP>
}</TMPL_IF>

<TMPL_IF NAME=HAS_RELATIONSHIPS>
# These relationship methods are automatically generated:

<TMPL_LOOP NAME=RELATIONSHIPS>sub <TMPL_VAR NAME=RELATIONSHIP> {
	my ($self) = @_;
	<TMPL_IF NAME=RELATIONSHIP_IS_TO_ONE>return $self->faultEntityForRelationshipNamed("<TMPL_VAR NAME=RELATIONSHIP>");
	<TMPL_ELSE>return $self->faultEntitiesForRelationshipNamed("<TMPL_VAR NAME=RELATIONSHIP>");</TMPL_IF>
}

<TMPL_IF NAME=RELATIONSHIP_IS_TO_ONE>sub <TMPL_VAR RELATIONSHIP_SETTER> {
	my ($self, $object) = @_;
	if ($object) {
	    $self->addObjectToBothSidesOfRelationshipWithKey($object, "<TMPL_VAR RELATIONSHIP>");
	} else {
	    $self->setValueOfToOneRelationshipNamed(undef, "<TMPL_VAR RELATIONSHIP>");
	}
}
<TMPL_ELSE>
sub <TMPL_VAR RELATIONSHIP_ADDER> {
	my ($self, $object) = @_;
	$self->addObjectToBothSidesOfRelationshipWithKey($object, "<TMPL_VAR RELATIONSHIP>");
}
sub <TMPL_VAR RELATIONSHIP_REMOVER> {
	my ($self, $object) = @_;
	$self->removeObjectFromBothSidesOfRelationshipWithKey($object, "<TMPL_VAR RELATIONSHIP>");
}
</TMPL_IF>
</TMPL_LOOP>
</TMPL_IF>

<TMPL_LOOP NAME=ACCESSORS>sub <TMPL_VAR NAME=GETTER>    { $_[0]->storedValueForKey("<TMPL_VAR NAME=ATTRIBUTE_NAME>")  }
sub <TMPL_VAR NAME=SETTER> { $_[0]->setStoredValueForKey($_[1], "<TMPL_VAR NAME=ATTRIBUTE_NAME>") }
</TMPL_LOOP>

1;
