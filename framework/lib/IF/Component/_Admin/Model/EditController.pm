package IF::Component::_Admin::Model::EditController;
use strict;
use base qw(IF::Component::_Admin::Model::EntityPage);

sub canEditEntityType {
    my $entityType = shift;
    return 1;
}

sub canPreviewEntityType {
    my ($entityType) = @_;
    return 0;
}

sub controllerClass {
    return "_Admin::Model::EditController";
}

sub wrapperClass {
    return "Admin::PageWrapper";
}

sub homeClass {
    return "_Admin::Model::Viewer";
}

sub shouldShowNavigationInContext {
    my ($self, $context) = @_;
    return 1;    
}

# override this in your controller to decide whether or not to show the link
sub shouldShowDeleteLinkForEntity {
    my ($self, $entity) = @_;
    return 1;
}

sub nextPageForEditAction {
    my ($self, $context) = @_;
    my $nextPage = $self->pageWithName("_Admin::Model::EntityClassManager");
    $nextPage->setEntityClassDescription($self->entityClassDescription());
    return $nextPage;
}

sub nextPageForDeleteAction {
    my ($self, $context) = @_;
    my $nextPage = $self->pageWithName("_Admin::Model::EntityClassManager");
    $nextPage->setEntityClassDescription($self->entityClassDescription());
    return $nextPage;
}

sub nextPageForManageAction {
    my ($self, $context) = @_;
    my $nextPage = $self->pageWithName("_Admin::Model::EntityClassManager");
    $nextPage->setEntityClassDescription($self->entityClassDescription());
    return $nextPage;
}

sub shouldShowWrapper {
    my $self = shift;
    return 1;
}

sub shouldShowRelationshipControls {
    my $self = shift;
    return 1;    
}

sub shouldAllowGridDetail {
    my $self = shift;
    return 1;
}

sub dictionaryOfRelationshipsToHideForEntityTypeInContext {
    my ($self, $entityType, $context) = @_;
    return {};    
}

sub dictionaryOfAttributesToHideForEntityTypeInContext {
    my ($self, $entityType, $context) = @_;
    return {};    
}

sub dictionaryOfInlineRelationshipsForEntityTypeInContext {
    my ($self, $entityType, $context) = @_;
    return {};
}

sub summaryAttributesForEntityType {
    my ($self,$type) = @_;
    return [];
}

sub displayNameKeyForEntityType {
    my ($self,$type) = @_;
    return undef;
}

sub attributeDisplayOrderForEntityType {
    my ($self,$type) = @_;
    return [];
}

sub relationshipTargetChooserClassForAttributeOnEntityType {
    my ($self,$attribute,$type) = @_;
    return undef;
}

sub dictionaryOfDefaultAttributeKeysForEntityType {
    my ($self, $entityType) = @_;
    return {};
}

sub previewActionForEntityType {
    my ($self, $entityType) = @_;
    return 'default';
}

sub previewComponentForEntityType {
    my ($self, $entityType) = @_;
    return undef;

}

sub defautTextFieldWidth {
    return 25;
}

1;