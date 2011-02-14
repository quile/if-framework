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

package IFTest::Type::Memcached;

use strict;
binmode( STDOUT, ':utf8' );
use base qw(
    Test::Class
);

use IFTest::Application;
use IF::Log;
use Test::More;

#sub setUp : Test(startup => 1) {
sub _setUp {
    my ($self, $port) = @_;

    #------------------------------------
    $self->{debug} = 0;
    $self->{port} = $port || 11211;
    my $memcachedPath = IF::Application->systemConfigurationValueForKey("MEMCACHED_PATH")
                        || `which memcached` || '/usr/local/bin/memcached';
    chomp $memcachedPath;
    my $memcachedFlags = " -p $self->{port} ";

    IF::Log::setLogMask(0x20);
    if ($self->{debug}) {
        IF::Log::setLogMask(0xffff);
        $memcachedFlags .= " -vv ";
    }

    # -------
    use IF::Cache::Memcached;

    diag("Firing up memcached at $memcachedPath on port $self->{port}");
    $self->{pid} = fork();
    if (not defined $self->{pid}) {
        print "fork failed.\n";
    } elsif ($self->{pid} == 0) {
        # child
        exec("$memcachedPath $memcachedFlags")
                           or die "Can’t start memcached: $!";
        print "Should not get here!\n";
        exit(0);
    } else {
        ok(1, "forked off memcached process");
        # sleep(4);

        # sanity check memcache maybe?
    }
}


#sub tearDown : Test(shutdown => 1) {
sub _tearDown {
    my ($self) = @_;

    kill 15, $self->{pid};
    waitpid($self->{pid}, 0);
    ok(1, "Memcached shut down");
}

1;