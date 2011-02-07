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

package IF::Cache::PerProcess;

# This is the degenerate case of memory caching, simply
# backed by a hash in memory

use base qw(IF::Interface::Cache);

sub init {
	my $self = shift;
	$self->setCacheTimeout($DEFAULT_CACHE_TIMEOUT);
	$self->{cache} = {};
	$self->{expires} = {};
}

sub cachedValueForKey {
	my ($self, $key) = @_;
	if ($self->cachedValueForKeyHasExpired($key)) {
		$self->deleteCachedValueForKey($key);
	}
	return $self->{cache}->{$key};
}

sub setCachedValueForKey {
	my ($self, $value, $key) = @_;
	$self->setCachedValueForKeyWithTimeout($value, $key, $self->cacheTimeout());
}

sub setCachedValueForKeyWithTimeout {
	my ($self, $value, $key, $timeout) = @_;
	$self->{cache}->{$key} = $value;
	$self->{expires}->{$key} = time() + $timeout;
}

sub allKeys {
	my ($self) = @_;
	return keys %{$self->{cache}};
}

sub cachedValueForKeyHasExpired {
	my ($self, $key) = @_;
	return 1 unless $self->{expires}->{$key};
	return $self->{expires}->{$key} < time();
}

sub deleteCachedValueForKey {
	my ($self, $key) = @_;
	delete $self->{cache}->{$key};
	delete $self->{expires}->{$key};
}

1;
