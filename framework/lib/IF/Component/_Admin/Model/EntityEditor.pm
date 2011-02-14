package IF::Component::_Admin::Model::EntityEditor;

use strict;
use base qw(
    IF::Component::_Admin::Model::EntityPage
);

sub takeValuesFromRequest {
    my ($self, $context) = @_;
    $self->inflateShit($context);
    $self->setEntityClassDescription(
         $self->model()->entityClassDescriptionForEntityNamed($context->formValueForKey("entity-class-name"))
                             );
    return unless IF::Log::assert($self->entityClassDescription(), "Has an entity class description");
    unless ($context->formValueForKey("entity-id")) {
        IF::Log::debug("No incoming entity id, creating new entity");
        $self->setEntity($self->objectContext()->entityFromHash($self->entityClassDescription()->name(), {}));
    }

    if ($self->isEditingFlattenedToManyRelationship()) {
        IF::Log::debug("Setting up a relationship hint editor");
        $self->setRelationshipHints(IF::Dictionary->new());
        $self->setRelationshipHintEntityClassDescription(
            $self->transientEntityClassDescriptionForFlattenedToManyRelationshipWithNameOnEntity(
                                                            $context->formValueForKey("relationship-name"), 
                                                            $self->rootEntity())
                                                         );
        IF::Log::debug("Relationship hints:");
        IF::Log::dump($self->relationshipHints());
    }
    IF::Log::debug("----------> calling super...");
    $self->SUPER::takeValuesFromRequest($context);    
    $self->populateDefaultValues();    
}

sub defaultAction {
    my ($self,$context) = @_;
    if (my $targetComponent = $self->returnTargetComponent()) {
        my $nextPage = $self->pageWithName($targetComponent);
        return $nextPage;
    }
    return;
}

sub submitAction {
    my $self = shift;
    my $context = shift;
    return unless $self->hasValidFormValues($context);
    return unless $self->entity();

    IF::Log::debug("Saving entity:".$self->entity()->_entityClassName()." id:".$self->entity()->externalId());
    $self->entity()->save();
    my $nextPage;
    if ($context->formValueForKey("relationship-name") && $self->rootEntity()) {
        if ($self->isEditingFlattenedToManyRelationship()) {
            $self->rootEntity()->removeObjectFromBothSidesOfRelationshipWithKey($self->entity(), $context->formValueForKey("relationship-name"));
        }
        IF::Log::dump($self->entity());
        IF::Log::dump($self->relationshipHints());
        $self->rootEntity()->addObjectToBothSidesOfRelationshipWithKeyAndHints($self->entity(), $context->formValueForKey("relationship-name"), $self->relationshipHints());
        IF::Log::dump($self->rootEntity());
        $self->rootEntity()->save();
    }
    if ($self->rootEntity()) {
        $nextPage = $self->pageWithName("_Admin::Model::EntityEditor");
        $nextPage->setEntity($self->rootEntity());
        $nextPage->setEntityClassDescription($self->rootEntity()->entityClassDescription());
        $nextPage->setController($self->controller());
    } else {
        $nextPage = $self->controller()->nextPageForEditAction($context);
    }
    return $nextPage;
}

sub previewAction {
    my ($self, $context) = @_;
    return unless $self->hasValidFormValues($context);
    return unless $self->entity();
    my $nextPage = $self->pageWithName("_Admin::Model::EntityPreviewer");
    $nextPage->setEntity($self->entity());
    $nextPage->setEntityClassDescription($self->entityClassDescription());
    $nextPage->setRootEntity($self->rootEntity());
    $nextPage->setRootEntityClassDescription($self->rootEntityClassDescription());
    $nextPage->setRelationshipName($self->relationshipName());
    $nextPage->setControllerClass($self->controllerClass());
    $nextPage->setPreviewUrlFromController($self->controller());
    $nextPage->storePreview();
    return $nextPage;
}

sub deleteAction {
    my $self = shift;
    my $context = shift;
    return unless $self->hasValidFormValues($context);
    return unless $self->entity();
    my $entitiesToBeDeleted = $self->entity()->entitiesForDeletionByRules();
    push (@$entitiesToBeDeleted, $self->entity());
    my $entitiesToBeDeletedByClass = {};
    foreach my $entity (@$entitiesToBeDeleted) {
        $entitiesToBeDeletedByClass->{$entity->entityClassDescription()->name()}->{$entity->id()} = 1;
    }
    $self->objectContext()->deleteEntity($self->entity());
    
    # remove any deleted objects from the recently viewed list
    my $recentlyViewedEntities = $context->session()->sessionValueForKey("recentlyViewedEntities") || [];
    my $recentlyViewedEntitiesWithoutDeletedEntities = [];
    foreach my $entity (@$recentlyViewedEntities) {
        if ($entitiesToBeDeletedByClass->{$entity->{entityClassName}}->{$entity->{id}}) {
            IF::Log::debug("Removing $entity->{name} from recently-viewed-items");
            next;
        }
        push (@$recentlyViewedEntitiesWithoutDeletedEntities, $entity);
    }
    $context->session()->setSessionValueForKey($recentlyViewedEntitiesWithoutDeletedEntities, "recentlyViewedEntities");
    my $nextPage;
    if (my $targetComponent = $self->returnTargetComponent()) {
        $nextPage = $self->pageWithName($targetComponent);
        IF::Log::debug("target component: $targetComponent");
    }
    unless ($nextPage) {
        $nextPage = $self->controller()->nextPageForDeleteAction($context);
    }
    if (! $nextPage && $self->rootEntity()) {
        $nextPage = $self->pageWithName("_Admin::Model::EntityEditor");
        $nextPage->setEntity($self->rootEntity());
        $nextPage->setEntityClassDescription($self->rootEntity()->entityClassDescription());
        $nextPage->setController($self->controller());
    }
    return $nextPage;
}

sub confirmDeleteAction {
    my $self = shift;
    my $context = shift;
    return unless $self->hasValidFormValues($context);
    return unless $self->entity();
    my $nextPage = $self->pageWithName("_Admin::Model::EntityDeletionConfirmation");
    $nextPage->setEntity($self->entity());
    $nextPage->setRootEntity($self->rootEntity());
    $nextPage->setEntityClassDescription($self->entityClassDescription());
    $nextPage->setController($self->controller());
    $nextPage->setReturnTargetComponent($self->returnTargetComponent());
    return $nextPage;
}

sub removeFromRelationshipAction {
    my $self = shift;
    my $context = shift;
    return unless $self->hasValidFormValues($context);
    return unless $self->entity();
    my $nextPage;
    $self->rootEntity()->removeObjectFromBothSidesOfRelationshipWithKey($self->entity(), $context->formValueForKey("relationship-name"));
    $nextPage = $self->pageWithName("_Admin::Model::EntityEditor");
    $nextPage->setEntity($self->rootEntity());
    $nextPage->setEntityClassDescription($self->rootEntity()->entityClassDescription());
    $nextPage->setController($self->controller());
    return $nextPage;
}

sub viewRelatedEntitiesAction {
    my ($self, $context) = @_;
    my $entities = [];
    my $relationship = $self->rootEntity()->relationshipNamed($context->formValueForKey("relationship-name"));
    return unless $relationship;
    if ($relationship->{TYPE} eq "TO_ONE") {
        push (@$entities, $self->rootEntity()->entityForRelationshipNamed($context->formValueForKey("relationship-name")));
    } else {
        $entities = $self->rootEntity()->entitiesForRelationshipNamed($context->formValueForKey("relationship-name"));
    }
    return unless scalar @$entities;
    my $nextPage = $self->pageWithName("_Admin::Model::EntitySearchResults");
    $nextPage->setRootEntity($self->rootEntity());
    $nextPage->setEntityClassDescription($entities->[0]->entityClassDescription());
    $nextPage->setCountOfSearchResults(scalar @$entities);
    $nextPage->setSearchResults($entities);
    $nextPage->setSearchTerms(IF::Dictionary->new()); # deal with this right...
    $nextPage->setController($self->controller());
    return $nextPage;
}

sub orderRelatedEntitiesAction {
    my ($self, $context) = @_;
    my $nextPage = $self->pageWithName("_Admin::Model::EntityRelationshipOrderingEditor");
    $nextPage->setRootEntity($self->rootEntity());
    $nextPage->setRelationshipName($self->relationshipName());
    $nextPage->setController($self->controller());
    $nextPage->_setup($context);
    return $nextPage;
}

sub addRelatedEntityAction {
    my ($self, $context) = @_;
    my $entities = [];
    my $relationship = $self->rootEntity()->relationshipNamed($context->formValueForKey("relationship-name"));
    return unless $relationship;
    my $nextPage = $self->pageWithName("_Admin::Model::EntityEditor");
    #IF::Log::dump($nextPage);
    $nextPage->setRootEntity($self->rootEntity());
    my $entityClassDescriptionForNewEntity = $self->model()->entityClassDescriptionForEntityNamed($relationship->{TARGET_ENTITY});
    my $newEntity = $self->objectContext()->entityFromHash($entityClassDescriptionForNewEntity->name(), {});
    $nextPage->setEntityClassDescription($entityClassDescriptionForNewEntity);
    $nextPage->setEntity($newEntity);
    $nextPage->setController($self->controller());
    return $nextPage;
}

sub chooseRelatedEntityAction {
    my ($self, $context) = @_;
    my $entities = [];
    my $relationship = $self->rootEntity()->relationshipNamed($context->formValueForKey("relationship-name"));
    return unless $relationship;
    my $nextPage = $self->pageWithName("_Admin::Model::EntitySearch");
    $nextPage->setRootEntity($self->rootEntity());
    my $entityClassDescriptionForNewEntity = $self->model()->entityClassDescriptionForEntityNamed($relationship->{TARGET_ENTITY});
    $nextPage->setEntityClassDescription($entityClassDescriptionForNewEntity);
    $nextPage->setController($self->controller());
    return $nextPage;
}

sub appendToResponse {
    my ($self, $response, $context) = @_;
    
# for FLATTENED_TO_MANY relationships, if we are adding or editing an entity,
# we need to display a field editor for the "hints"
    
    if ($self->isEditingFlattenedToManyRelationship()) {
        my $relationshipName = $context->formValueForKey("relationship-name");
        unless ($self->entity()->hasNeverBeenCommitted()) {
            my $fetchSpecification = $self->rootEntity()->fetchSpecificationForFlattenedToManyRelationshipNamed($relationshipName);
            if ($fetchSpecification) {
                my $relationship = $self->rootEntity()->relationshipNamed($relationshipName);
                $fetchSpecification->setQualifier(
                    IF::Qualifier->and([
                        $fetchSpecification->qualifier(),
                        IF::Qualifier->key($relationship->{TARGET_ATTRIBUTE}." = %@", 
                            $self->entity()->valueForKey($relationship->{TARGET_ATTRIBUTE}))
                        ]
                    )
                );
                my $entity = $self->objectContext()->entityMatchingFetchSpecification($fetchSpecification);
                if ($entity) {
#IF::Log::dump($entity->_deprecated_relationshipHints());
                    $self->setRelationshipHints(IF::Dictionary->new($entity->_deprecated_relationshipHints()));
                }
            }
        }
        $self->setRelationshipHints(IF::Dictionary->new()) unless $self->relationshipHints();
        $self->setRelationshipHintEntityClassDescription(
            $self->transientEntityClassDescriptionForFlattenedToManyRelationshipWithNameOnEntity(                                                        $relationshipName, $self->rootEntity()
                        )
            ) unless $self->relationshipHintEntityClassDescription();
    }
    
    unless ($self->entity()->hasNeverBeenCommitted()) {
        my $recentlyViewedEntities = $context->session()->sessionValueForKey("recentlyViewedEntities") || [];
        
        my $recentlyViewedEntitiesInOrder = [ 
            { 
                    id => $self->entity()->id(),
                    entityClassName => $self->entity()->entityClassDescription()->name(),
                    name => $self->nameForEntity($self->entity()),
            }
            ];
        my $maxCount = 1;
        foreach my $entity (@$recentlyViewedEntities) {
            next if ($entity->{id} eq $self->entity()->id());
            push (@$recentlyViewedEntitiesInOrder, $entity);
            $maxCount++;
            last if $maxCount > 10;
        }
        $context->session()->setSessionValueForKey($recentlyViewedEntitiesInOrder, "recentlyViewedEntities");
    }
    return $self->SUPER::appendToResponse($response, $context);
}

sub canAddRelatedEntity {
    my $self = shift;
#IF::Log::debug("relationship type is ".$self->entityClassDescription()->relationshipWithName($self->{aRelationshipName})->{TYPE});
    return 
        $self->entityClassDescription()->relationshipWithName($self->{aRelationshipName})->{TYPE} ne "TO_ONE" ||
        $self->entity()->countOfEntitiesForRelationshipNamed($self->{aRelationshipName}) == 0;
}

sub hiddenAttributes {
    my $self = shift;
    my $attributes = [];
    # here we return a list of attributes to hide from the user
    my $relationshipName = $self->context()->formValueForKey("relationship-name");
    if ($relationshipName && $self->rootEntity()) {
        # this means that $self->entity() is related to rootEntity through
        # a named relationship
        my $relationship = $self->rootEntity()->relationshipNamed($relationshipName);
        if ($relationship) {
            IF::Log::debug("Looking to hide attribute for ".$relationship->{TARGET_ATTRIBUTE});
            push (@$attributes, $self->entity()->entityClassDescription()->attributeForColumnNamed($relationship->{TARGET_ATTRIBUTE}));
            if ($self->entity()->entityClassDescription()->attributeForColumnNamed($relationship->{TARGET_ATTRIBUTE}) ne
                $self->entity()->entityClassDescription()->attributeForColumnNamed($self->entity()->entityClassDescription()->_primaryKey())) {    
                push (@$attributes, $self->entity()->entityClassDescription()->attributeForColumnNamed($self->entity()->entityClassDescription()->_primaryKey()));
            }
        }
    }
    foreach my $attribute (keys %{$self->controller()->dictionaryOfAttributesToHideForEntityTypeInContext(
                                    $self->entity()->entityClassDescription()->name(),
                                    $self->context())}) {
        my $column = $self->entity()->entityClassDescription()->columnNameForAttributeName($attribute);
        push (@$attributes, $self->entity()->entityClassDescription()->attributeForColumnNamed($column));
    }
    
    IF::Log::dump($attributes);
    return $attributes;
}

sub transientEntityClassDescriptionForFlattenedToManyRelationshipWithNameOnEntity {
    my ($self, $relationshipName, $entity) = @_;
    my $entityClassDescription = {};
    my $relationship = $entity->relationshipNamed($relationshipName);
    
    # build a list of attributes
    foreach my $hint (@{$relationship->{RELATIONSHIP_HINTS}}) {
        $entityClassDescription->{ATTRIBUTES}->{uc($hint)} = { 
            COLUMN_NAME => $hint,
            ATTRIBUTE_NAME => $hint,
        };
    }
    
    # do some DB poking to get info:
    my ($rows, undef) = IF::DB::rawRowsForSQL("SHOW COLUMNS FROM ".$relationship->{JOIN_TABLE});
    foreach my $row (@$rows) {
        next unless $entityClassDescription->{ATTRIBUTES}->{uc($row->{FIELD})};
        # user has not specified a custom name, set it for the column        
        # my $prettyName = lcfirst(join("", map {ucfirst(lc($_))} split(/_/, $row->{FIELD})));                                                             
        
        my $type = $row->{TYPE};                                     
        my $size = undef;                                               
        my $enumeratedValues = [];                                      
        if ($type =~ /([\w]+)\(([0-9]+)\)/) {                           
            $type = $1;                                                 
            $size = $2;                                                 
        }                                                               
        
        if ($type =~ /^enum\(([^\)]+)\)$/i) {                           
            $type = "ENUM";                                             
            $enumeratedValues = eval ("[".$1."]");                      
        }                                                               

        # TODO: this just takes the values from MySQL and slots         
        # them in.  This really should be a bit smarter...              

        $entityClassDescription->{ATTRIBUTES}->{$row->{FIELD}} = {             
            ATTRIBUTE_NAME => $row->{FIELD},                  
            COLUMN_NAME => $row->{FIELD},                
            TYPE => $type,                                  
            SIZE => $size,                                  
            VALUES => $enumeratedValues,                    
            NULL => $row->{NULL},                        
            KEY => $row->{NULL},                         
            DEFAULT => $row->{DEFAULT},                  
            EXTRA => $row->{DEFAULT},                    
        };                                                              
    }
    IF::Log::dump($entityClassDescription);
    return IF::EntityClassDescription->new($entityClassDescription);
}

sub isEditingFlattenedToManyRelationship {
    my $self = shift;
    IF::Log::debug("Checking for root entity");
    return 0 unless $self->rootEntity();
    IF::Log::debug("Checking if root entity has a relationship named ".$self->context()->formValueForKey("relationship-name"));
    my $relationship = $self->rootEntity()->relationshipNamed($self->context()->formValueForKey("relationship-name"));
    return 0 unless $relationship;
    IF::Log::debug("Checking if relationship is m2m");
    return 1 if ($relationship->{TYPE} eq "FLATTENED_TO_MANY");
    return 0;
}

sub relationshipHints {
    my $self = shift;
    return $self->{relationshipHints};
}

sub setRelationshipHints {
    my $self = shift;
    $self->{relationshipHints} = shift;
}
sub relationshipHintEntityClassDescription {
    my $self = shift;
    return $self->{relationshipHintEntityClassDescription};
}

sub setRelationshipHintEntityClassDescription {
    my $self = shift;
    $self->{relationshipHintEntityClassDescription} = shift;
}

sub nameForEntity {
    my ($self, $entity) = @_;
    return unless $entity;
    my $attributes = $entity->entityClassDescription()->orderedAttributes();
    return $entity->valueForKey($attributes->[0]->{ATTRIBUTE_NAME});
}

sub relationships {
    my $self = shift;
    my $allRelationships = [sort keys %{$self->entityClassDescription()->relationships()}];
    my $hiddenRelationships = $self->controller()->dictionaryOfRelationshipsToHideForEntityTypeInContext(
                                    $self->entity()->entityClassDescription()->name(),
                                    $self->context()
                                    );
                                    
    return [grep {!$hiddenRelationships->{$_}} @$allRelationships];
}

sub shouldShowRelationshipInline {
    my ($self,$relationshipName) = @_;
    return $self->controller()->dictionaryOfInlineRelationshipsForEntityTypeInContext(
            $self->entity()->entityClassDescription()->name(),
            $self->context()
            )->{$relationshipName};
}

sub entityClassDescriptionForTargetEntityOfRelationshipWithName {
    my ($self,$relationshipName) = @_;
    my $relationship = $self->entityClassDescription()->relationshipWithName($self->{aRelationshipName});
    unless ($relationship) {
        IF::Log::error("No relationship retrieved for relationship named: $relationshipName");
        return;
    }
    my $targetEntityName = $relationship->targetEntity();
    my $ecd = $self->model()->entityClassDescriptionForEntityNamed($targetEntityName);
    return $ecd;
} 

sub populateDefaultValues {
    my ($self) = @_;
    my $defaultsDictionary = $self->controller()->dictionaryOfDefaultAttributeKeysForEntityType(
        $self->entityClassDescription()->name());
    foreach my $entityAttributeKey (keys %$defaultsDictionary) {
        my $keyToEvaluate = $defaultsDictionary->{$entityAttributeKey};
        unless ($self->entity()->valueForKey($entityAttributeKey)) {
            $self->entity()->setValueForKey($self->valueForKey($keyToEvaluate),$entityAttributeKey);
        }
    }
}

1;

