package IFTest::TestObjectContext;

use common::sense;

use base qw(
    IFTest::Type::Datasource
);
use Test::Class;
use Test::More;

use IFTest::Application;

use IF::ObjectContext;
use IF::Query;


use aliased 'IFTest::Entity::Root';
use aliased 'IFTest::Entity::Branch';
use aliased 'IFTest::Entity::Ground';
use aliased 'IFTest::Entity::Trunk';
use aliased 'IFTest::Entity::Globule';
use aliased 'IFTest::Entity::Zab';
use aliased 'IFTest::Entity::Elastic';


sub setUp  : Test(setup) {
    my ($self) = @_;
    $self->{oc}->init();
}

sub testTrackNewObject : Test(4) {
    my ($self) = @_;
    my $e = Globule->new();
    ok( ! $e->isTrackedByObjectContext(), "New object is not being tracked" );
    ok( ! $self->{oc}->entityIsTracked($e), "Object context knows nothing of new object" );

    $self->{oc}->trackEntity($e);
    ok( $e->isTrackedByObjectContext(), "Object was inserted into editing context." );
    ok( $self->{oc}->entityIsTracked($e), "Object context knows about new object" );
}

sub testIgnoreObject : Test(4) {
    my ($self) = @_;
    my $e = Zab->new();
    ok( ! $e->isTrackedByObjectContext(), "New object is not being tracked");

    $self->{oc}->insertEntity($e);
    ok( $e->isTrackedByObjectContext(), "New object is being tracked");

    $self->{oc}->forgetEntity($e);
    ok( ! $e->isTrackedByObjectContext(), "New object is no longer being tracked");
    ok( ! $self->{oc}->entityIsTracked($e), "Object context no longer knows about new object");
}

sub testGetChangedObjects : Test(16) {
    my ($self) = @_;

    my $e = Zab->newFromDictionary({ title => "Zab 1" });
    my $f = Zab->newFromDictionary({ title => "Zab 2" });
    my $g = Zab->newFromDictionary({ title => "Zab 3" });
    ok( $e->title() eq "Zab 1", "Set title correctly");

    ok( ! $e->isTrackedByObjectContext() );
    ok( ! $f->isTrackedByObjectContext() );
    ok( ! $g->isTrackedByObjectContext() );

    $self->{oc}->insertEntity($e);
    $self->{oc}->insertEntity($f);
    $self->{oc}->insertEntity($g);
    ok( $e->isTrackedByObjectContext() );
    ok( $f->isTrackedByObjectContext() );
    ok( $g->isTrackedByObjectContext() );

    ok( scalar @{$self->{oc}->changedEntities()} == 0, "oc has no changed objects");
    ok( scalar @{$self->{oc}->addedEntities()} == 3, "oc has three added entities");
    ok( scalar @{$self->{oc}->trackedEntities()} == 3, "oc has three tracked entities");

    # This should commit the new objects
    # diag $self->{oc}->addedEntities();
    $self->{oc}->saveChanges();

    ok( scalar @{$self->{oc}->changedEntities()} == 0, "oc has no changed objects");
    ok( scalar @{$self->{oc}->addedEntities()} == 0, "oc has no added entities");
    ok( scalar @{$self->{oc}->trackedEntities()} == 3, "oc has three tracked entities");

    $f->setTitle("Zab 2a");
    ok( scalar @{$self->{oc}->changedEntities()} == 1, "oc has one changed entity");
    ok( $self->{oc}->changedEntities()->[0]->is( $f ), "... and it's f");
    $self->{oc}->saveChanges();
    ok( scalar @{$self->{oc}->changedEntities()} == 0, "flushed oc has no changed entity");
}

sub testUniquing : Test(16) {
    my ($self) = @_;

    my $e = Branch->newFromDictionary({ leafCount => 99, length => 16 });
    my $f = Branch->newFromDictionary({ leafCount => 12, length => 8 });
    my $g = Branch->newFromDictionary({ leafCount => 14, length => 6 });
    my $h = Branch->newFromDictionary({ leafCount => 16, length => 4 });

    ok( scalar @{$self->{oc}->trackedEntities()} == 0, "no tracked entities yet");
    $self->{oc}->trackEntities($e, $f, $g);
    ok( scalar @{$self->{oc}->trackedEntities()} == 3, "three tracked entities now");
    ok( scalar @{$self->{oc}->addedEntities()} == 3, "three added entities now");

    my $t = Trunk->newFromDictionary({ thickness => 3 });
    $t->addObjectToBranches($e);
    $t->addObjectToBranches($f);
    $t->addObjectToBranches($g);
    $t->addObjectToBranches($h);

    ok( scalar @{$t->relatedEntities()} == 4, "Trunk has four related entities in memory");

    # FIXME: this shouldn't be necessary because
    # it's related to objects in the OC.
    $self->{oc}->trackEntity($t);

    ok( scalar @{$self->{oc}->trackedEntities()} == 5, "correct # tracked entities now");

    # this commits everyone
    $self->{oc}->saveChanges();

    ok( $e->id(), "e has an id now");

    # now do some basic uniquing checks
    my $re = $self->{oc}->entityWithPrimaryKey("Branch", $e->id());
    ok( $re == $e, "object fetched with pk should return unique instance");

    my $re2 = $self->{oc}->entityWithPrimaryKey("Branch", $e->id());
    ok( $re2 == $re, "fetched again, same again");

    my $brs = $t->branches();
    ok( $brs->containsObject($e), "e is in branches");
    ok( $brs->containsObject($f), "f is in branches");
    ok( $brs->containsObject($g), "g is in branches");
    ok( $brs->containsObject($h), "h is in branches");

    # make sure something fetched via a query is uniqued too
    my $newb = IF::Query->new("Branch")->filter("leafCount = %@", 12)->first();
    ok( $newb == $f, "Fetched result is matched with in-memory result");

    # what about traversing across a relationship?
    my $newt = IF::Query->new("Trunk")->filter("branches.leafCount = %@", 99)->prefetch("branches")->first();
    ok( $newt == $t, "Fetched result is matched with in-memory result");
    ok( scalar @{$newt->_cachedEntitiesForRelationshipNamed("branches")} == 4, "Four branches attached to in-memory");
    ok( scalar @{$newt->branches()} == 4, "Four branches when fetched via <branches> method");
}

sub testFaultingAndUniquing : Test(7) {
    my ($self) = @_;
    my $e = Branch->newFromDictionary({ leafCount => 10, length => 16 });
    my $f = Branch->newFromDictionary({ leafCount => 12, length => 8 });
    my $g = Branch->newFromDictionary({ leafCount => 14, length => 6 });

    my $t = Trunk->newFromDictionary({ thickness => 17 });
    $t->addObjectToBranches($e);
    ok( scalar @{$t->branches()} == 1, "One branch connected");
    ok( scalar @{$t->_cachedEntitiesForRelationshipNamed("branches")} == 1, "One cached connected");

    # add same one again
    $t->addObjectToBranches($e);
    ok( scalar @{$t->branches()} == 1, "One branch connected still");
    ok( scalar @{$t->_cachedEntitiesForRelationshipNamed("branches")} == 1, "One cached connected still");

    #diag $t->branches();
    #diag $t->relatedEntities();
    $self->{oc}->trackEntity($t);

    $self->{oc}->saveChanges();
    $self->{oc}->clearTrackedEntities();

    my $rt = $self->{oc}->entityWithPrimaryKey("Trunk", $t->id());
    #ok( [[rt branches] count] eq 1, "Refetched trunk has 1");

    # add another
    $rt->addObjectToBranches($f);

    # calling branches here should fault in from the DB
    ok( scalar @{$rt->_cachedEntitiesForRelationshipNamed("branches")} == 1, "One cached entity");
    ok( scalar @{$rt->branches()} == 2, "Now two");
    ok( scalar @{$rt->_cachedEntitiesForRelationshipNamed("branches")} == 2, "Two cached entities");
}

sub testTraversedRelationshipsBeforeCommit : Test(4) {
    my ($self) = @_;
    my $branch = Branch->newFromDictionary({ leafCount => 33, length => 12 });
    my $trunk = Trunk->newFromDictionary({ thickness => 20 });
    my $root = Root->newFromDictionary({ title => "Big Tree!" });

    $self->{oc}->trackEntity($root);
    $root->setTrunk($trunk);
    $trunk->addObjectToBranches($branch);

    ok( $root->trunk(), "in-memory connection made");
    ok( scalar @{$trunk->branches()} == 1);
    ok( scalar @{$self->{oc}->addedEntities()} == 3, "oc has correct number of added entities");
    ok( scalar @{$root->trunk()->branches()} == 1, "traversal gives correct results");
}

sub testTraversedRelationshipsAfterCommit : Test(5) {
    my ($self) = @_;
    my $branch = Branch->newFromDictionary({ leafCount => 33, length => 12 });
    my $trunk = Trunk->newFromDictionary({ thickness => 888 });
    my $root = Root->newFromDictionary({ title => "Big Tree!"});

    $self->{oc}->trackEntity($root);
    $root->setTrunk($trunk);
    $trunk->addObjectToBranches($branch);
    $self->{oc}->saveChanges();
    $self->{oc}->clearTrackedEntities();

    $branch = undef;
    $trunk = undef;
    $root = undef;
    # TODO: ensure garbage is collected here?

    my $rr = $self->{oc}->entityMatchingQualifier("Root", IF::Qualifier->key("title = %@", "Big Tree!"));
    ok( $rr, "Refetch root");
    my $rt = $self->{oc}->entityMatchingQualifier("Trunk", IF::Qualifier->key("thickness = %@", 888));

    ok( $rt, "Refetch trunk");
    my $br = $self->{oc}->entityMatchingQualifier("Branch", IF::Qualifier->key("leafCount = %@", 33));
    ok( $br, "Refetch branch");
    ok( $rr->trunk() == $rt, "related trunk is same as refetched");
    ok( $rt->branches()->[0] == $br, "Related branch is same as refetched");
}

sub testChangedObjects :Test(6) {
    my ($self) = @_;
    # first flush the OC
    $self->{oc}->clearTrackedEntities();
    ok( scalar @{$self->{oc}->trackedEntities()} == 0, "OC has been flushed");

    ok( $self->{oc}->trackingIsEnabled(), "Tracking is enabled");

    # fetch any branch object
    my $branch = IF::Query->new("Branch")->first();
    ok( $branch, "fetched a branch from the DB");
    ok( scalar @{$self->{oc}->trackedEntities()} == 1, "OC is tracking one entity");

    # flush the OC
    $self->{oc}->clearTrackedEntities();
    ok( scalar @{$self->{oc}->trackedEntities()} == 0, "OC has been flushed");
    ok( ! $branch->isTrackedByObjectContext(), "branch is no longer being tracked");
}

1;