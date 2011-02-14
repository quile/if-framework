package IF::Component::_Admin::Model::EntityPreviewer;

use strict;
use base qw(
    IF::Component::_Admin::Model::EntityPage
);

sub makeChangesAction {
    my ($self, $context) = @_;
    $self->inflateAndFlushPreview();
    return $self->nextPagePopulated();
}

sub saveAction {
    my ($self, $context) = @_;
    $self->inflateAndFlushPreview();
    my $nextPage = $self->nextPagePopulated();
    #Let's give this a go
    return $nextPage->submitAction($context);
}

sub setPreviewUrlFromController {
    my ($self, $controller) = @_;
    #Set the preview url
    my $previewAction = $controller->previewActionForEntityType($self->entityClassDescription->name());
    my $previewComponent = $controller->previewComponentForEntityType($self->entityClassDescription->name());
    my $previewUrl = IF::Utility::urlInContextForDirectActionOnComponentWithQueryDictionary(
                                                                                        $self->context(),
                                                                                        $previewAction,
                                                                                        $previewComponent,
                                                                                        {
                                                                                            'preview-key' => $self->entityPreviewKey(),
                                                                                        }
                                                                                    );
    $self->setPreviewUrl($previewUrl);
}

sub storePreview {
    my ($self) = @_;
    # We are going to store the entity, but don't want/need all the info
    my $relationships = [keys %{$self->entity()->entityClassDescription()->relationships()}];
    foreach my $relationship (@$relationships) {
        $self->entity()->invalidateEntitiesForRelationshipNamed($relationship);
    }
    my $previewDictionary = {
        entity => $self->entity(),
        entityClassName => $self->valueForKey('entityClassDescription.name'),
        rootEntityId => $self->valueForKey('rootEntity.id'),
        rootEntityClassName => $self->valueForKey('rootEntityClassDescription.name'),
        relationshipName => $self->relationshipName(),
        controllerClass => $self->controllerClass(),
    };
    $self->context->session()->setSessionValueForKey($previewDictionary, $self->entityPreviewKey());

}

sub inflateAndFlushPreview {
    my ($self) = @_;
    my $previewDictionary = $self->context()->session()->sessionValueForKey($self->entityPreviewKey());
    return unless $previewDictionary;
    $self->setEntity($previewDictionary->{entity});
    $self->setEntityClassDescription($self->model()->entityClassDescriptionForEntityNamed($previewDictionary->{entityClassName}));
    $self->setControllerClass($previewDictionary->{controllerClass});
    #This is also passed in the query string as it seems to be referenced more from there
    $self->setRelationshipName($previewDictionary->{relationshipName});
    my $rootEntityId = $previewDictionary->{rootEntityId};
    my $rootEntityClassName = $previewDictionary->{rootEntityClassName};
    if ($rootEntityId && $rootEntityClassName) {
        $self->setRootEntityClassDescription($self->model()->entityClassDescriptionForEntityNamed($rootEntityClassName));
        $self->setRootEntity($self->objectContext()->entityWithPrimaryKey($rootEntityClassName, $rootEntityId));
    }
    # Now logically we shouldn't need this anymore..
    $self->context->session()->setSessionValueForKey(undef, $self->entityPreviewKey());
}

sub nextPagePopulated {
    my ($self) = @_;
    #Suppose we could be coming from someplace else in the future
    my $nextPage = $self->pageWithName("_Admin::Model::EntityEditor");
    $nextPage->setEntity($self->entity());
    $nextPage->setEntityClassDescription($self->entityClassDescription());
    $nextPage->setRootEntity($self->rootEntity());
    $nextPage->setRootEntityClassDescription($self->rootEntityClassDescription());
    $nextPage->setRelationshipName($self->relationshipName());
    $nextPage->setControllerClass($self->controllerClass());
    return $nextPage;
}

sub previewUrl {
    my ($self) = @_;
    return $self->{previewUrl};
}

sub setPreviewUrl {
    my ($self, $value) = @_;
    $self->{previewUrl} = $value;
}

sub entityPreviewKey {
    my ($self) = @_;
    return $self->{entityPreviewKey} || 'data-model-editor-entity-preview';
}

sub setEntityPreviewKey {
    my ($self, $value) = @_;
    $self->{entityPreviewKey} = $value;
}

1;