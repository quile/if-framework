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

package IFTest::TestUtility;

use strict;
use base qw(
    Test::Class
);
use Test::More;
use IFTest::Application;
use IFTest::Entity::Globule;
use IF::Utility;
use IF::Log;
use utf8;
use JSON;

# should use a test DB!
sub setUp : Test(startup => 1) {
    my ($self) = @_;

    my $u = IFTest::Entity::Globule->new();
    $u->setName("fu");
    $u->save();

    $self->{entities} = [$u];
    ok($u && $u->id(), "Created a test globule");
    $self->{globule} = $u;
}

sub test_json : Test(11) {
    my ($self) = @_;

    # hashes
    my $hash = {
        abc => "def",
        ghi => "jkl",
    };
    my $jh = IF::Utility::jsonFromObjectAndKeys($hash);
    ok($jh, "Got json back");
    my $rh = from_json($jh);
    is_deeply($hash, $rh, "Inflated hash is the same");

    $hash = {
        alpha => {
            bravo => {
                charlie => {
                    delta => [
                        "echo",
                        "foxtrot",
                        "golf",
                        "hotel",
                        "india",
                        "juliet",
                        "kilo",
                        "lima",
                    ],
                }
            },
            sierra => "november",
            romeo => "xray",
        },
        zulu => "oscar",
    };
    my $rh = from_json(IF::Utility::jsonFromObjectAndKeys($hash));
    is_deeply($rh, $hash, "nested structure inflated correctly");

    # key subset
    my $rh = from_json(IF::Utility::jsonFromObjectAndKeys($hash, [ "zulu" ]));
    is_deeply($rh, { zulu => "oscar" }, "Deflated/inflated subset of keys correctly");
    my $rh = from_json(IF::Utility::jsonFromObjectAndKeys($hash, [ "zulu", "alpha.sierra" ]));
    is_deeply($rh, { zulu => "oscar", "alpha.sierra" => "november" }, "Deflated/inflated subset of keypaths correctly");

    # map of key subset
    my $rh = from_json(IF::Utility::jsonFromObjectAndKeys($hash, [ 'alpha.bravo.charlie.delta.@0' ], { 'alpha.bravo.charlie.delta.@0' => "foo" }));
    is_deeply($rh, { foo => "echo" }, "Traversed and alias complex keypaths");

    # arrays
    my $array = [qw(alpha bravo charlie delta)];
    my $ja = IF::Utility::jsonFromObjectAndKeys($array);
    #diag $ja;
    my $ra = from_json($ja);

    is_deeply($ra, $array, "array of scalars is fine");

    $array = [ "alpha", { "bravo" => "charlie" }, "delta", [ "echo", "foxtrot" ]];
    my $ra = from_json(IF::Utility::jsonFromObjectAndKeys($array));
    is_deeply($ra, $array, "array of misc objects is ok");

    $array = [
        { value => "foo", display => "bar", },
        { value => "baz", display => "nob", },
        { value => "wang", display => "chung", },
    ];
    my $ja = IF::Utility::jsonFromObjectAndKeys($array, [ "value" ]);
    my $ra = from_json($ja);
    is_deeply($ra, [ { value => "foo", }, { value => "baz", }, { value => "wang", }, ], "fetched keys from each array element");

    # scalar
    my $scalar = "Suckah";
    my $rs = from_json(IF::Utility::jsonFromObjectAndKeys($scalar), { utf8 => 1, allow_nonref => 1 });
    is($rs, $scalar, "scalar ok");

    # complex objects
    my $u = $self->{globule};
    my $ju = IF::Utility::jsonFromObjectAndKeys($u, ["name" ]);
    my $ru = from_json($ju);
    is_deeply($ru, { name => 'fu' }, "Partial globule inflated");
}

sub tearDown : Test(shutdown => 1) {
    my ($self) = @_;
    my $found = 0;
    foreach my $e (@{$self->{entities}}) {
        $e->_deleteSelf();
        my $ecdn = $e->entityClassDescription()->name();
        my $re = IF::ObjectContext->new()->entityWithPrimaryKey($ecdn, $e->id());
        $found = $found && $re;
    }
    ok(!$found, "Successfully deleted objects");
}

1;