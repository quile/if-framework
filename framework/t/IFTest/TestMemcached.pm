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

package IFTest::TestMemcached;

use strict;
binmode( STDOUT, ':utf8' );
use base qw(
    IFTest::Type::Memcached
);

use IFTest::Application;

use Test::More;
use Encode ();
use Storable qw(nfreeze thaw);
use Compress::Zlib;
use utf8;


sub setUp : Test(startup => 1) {
    my ($self) = @_;
    $self->SUPER::_setUp();
}

sub tearDown : Test(shutdown => 1) {
    my ($self) = @_;
    $self->SUPER::_tearDown();
}


sub test_memcached : Test(23) {
    my ($self) = @_;

    # give memcached time to get started
    sleep(2);

    ok($self->{pid}, "Started memcached (pid $self->{pid})");

    my $mc = IF::Cache::Memcached->instanceForIpAndPort('127.0.0.1', $self->{port}, $self->{debug});
    ok($mc, "Created IF::Cache::Memcached instance");

    ok(! defined $mc->cachedValueForKey('foo'), "Got back undef for a non-existent key");

    ok($mc->setCachedValueForKey('123', 'abc'), "Set key in cache");
    ok($mc->cachedValueForKey('abc') eq '123', "Retrieved value cache");

    {
        my $k = 'aaa';
        #my $v = '玻利维亚';
        my $v = 'ééé';
        #print "utf8 in: $v is utf8? ".(Encode::is_utf8($v) ? 'yes' : 'no'), "\n";
        $mc->setCachedValueForKey($v, $k);
        my $rv = $mc->cachedValueForKey($k);
        #print "utf8 out: $rv is utf8? ".(Encode::is_utf8($rv) ? 'yes' : 'no'), "\n";
        ok($v eq $rv, "utf8 in and out of the cache correctly");
    }

    ok($mc->setCachedValueForKey({ 'xxx' => 'yyy'}, 'cobj'), "Set complex object for key in cache");
    my $cobj = $mc->cachedValueForKey('cobj');

    ok($cobj && UNIVERSAL::isa($cobj, 'HASH') && $cobj->{xxx} eq 'yyy', "Retrieved complex object from cache");

    ok($mc->setCachedValueForKey({ 'xéx' => 'yüy', 'aaa' => '玻利维亚'}, 'cobj2'), "Set complex object with utf8 chars for key in cache");
    my $cobj2 = $mc->cachedValueForKey('cobj2');
    ok($cobj2 && UNIVERSAL::isa($cobj2, 'HASH') && $cobj2->{'xéx'} eq 'yüy', "Retrieved complex object with utf8 chars from cache");
    ok($cobj2 && UNIVERSAL::isa($cobj2, 'HASH') && $cobj2->{'aaa'} eq '玻利维亚', "Retrieved complex object with utf8 chars from cache");

    {
        my $howBig = 100000;
        my $bigHash = {};
        for (my $i = 0; $i < $howBig; $i++) { $bigHash->{$i} = 'foo'; }


        {
            my $frozen = nfreeze($bigHash);
            ok (scalar keys %$bigHash == scalar keys %{thaw($frozen)}, "Storable works");

            my $compressed = Compress::Zlib::compress($frozen);
            my $uncompressed = Compress::Zlib::uncompress($compressed);
            ok (length($frozen) eq length($uncompressed), "Compress::Zlib works");
        }

        ok($mc->setCachedValueForKey($bigHash, 'bigHash'), "Set big hash");
        my $hashBack = $mc->cachedValueForKey('bigHash');
        ok($hashBack && (scalar keys %$hashBack == $howBig), "Got back the big hash");
    }

    {
        my $howBig = 250000;
        my $str = "lorem ipsum";
        my @arr;
        for (my $i=0; $i<($howBig / length($str)); $i++) { push @arr, $str; }
        my $bigScalar = join('',@arr);

        ok($mc->setCachedValueForKey($bigScalar, 'bigScalar'), "Set big scalar");
        my $scalarBack = $mc->cachedValueForKey('bigScalar');
        ok($scalarBack && (length($scalarBack) == length($bigScalar)), "Got back the big hash");
    }

    $mc->_flush();

    #diag("Testing multi-gets");
    {
        my $r = $mc->cachedValuesForKeys([]);
        ok($r && (! scalar keys %$r), "Correctly fetched empty set out for empty set in");

        $r = $mc->cachedValuesForKeys(['abc', 'def', 'ghi', 'xyz']);
        ok($r && (! scalar keys %$r), "Correctly fetched empty set out for set of unknown keys in");
    }

    $mc->setCachedValueForKey('foo', 'abc');
    {

        my $r = $mc->cachedValuesForKeys([ qw(abc) ]);
        ok($r && (scalar keys %$r == 1), "Fetched mget data");
        is_deeply({ 'abc' => 'foo'}, $r, "Data from mget is correct");
    }

    {
        my $r = $mc->cachedValuesForKeys(['abc', 'def', 'ghi', 'xyz']);
        ok($r && (scalar keys %$r == 1), "Fetched mget data for mixed keys in");
        is_deeply({ 'abc' => 'foo'}, $r, "Data from mget is correct");
    }
}

1;