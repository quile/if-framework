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

package IF::CachingComponent;

use strict;
use base qw(IF::Component);
use Encode ();
my $_componentCache;

sub init {
    my $self = shift;
    unless ($_componentCache) {
        $_componentCache = IF::Cache::bestAvailableCacheWithName("Component");
        IF::Log::debug("Using cache: ".$_componentCache." for Component");
    }
    $self->setCacheTimeout($_componentCache->cacheTimeout());
    return $self->SUPER::init();
}

sub shouldCacheValueForContext {
    my $self = shift;
    my $context = shift;
    return 1;
}

sub shouldUseCachedValueForContext {
    my $self = shift;
    my $context = shift;
    return 1;
}

sub shouldFlushCacheForContext {
    my $self = shift;
    my $context = shift;
    return $context->formValueForKey("flush-cached-components")
        || $context->formValueForKey("fcc");
}

sub hasCachedValueForContext {
    my $self = shift;
    my $context = shift;
    if ($context->formValueForKey("flush-cached-components")
     || $context->formValueForKey("fcc")) {
        return 0;
    }
    my $cacheKey = $self->cacheKeyForContext($context);
    return 0 unless $cacheKey;
    return ($_componentCache && $_componentCache->hasCachedValueForKey($cacheKey));
}

# projects should override this as nevessary
sub cacheKeyBaseKeyPaths {
    my $self = shift;
    return ['componentName','context.language'];
}

# components should override this as nevessary
sub cacheKeyRequiredKeyPaths {
    my $self = shift;
    return [];
}

sub cacheKeyForContext {
    my ($self, $context) = @_;
    my $baseKeys = $self->cacheKeyBaseKeyPaths();
    my $componentSpecificKeys = $self->cacheKeyRequiredKeyPaths();
    my $cacheKey = join('/', map { $self->valueForKey($_) } @$baseKeys,@$componentSpecificKeys );
    $cacheKey =~ s/[\s\X]/_/g;
    IF::Log::debug("cacheKey: $cacheKey");
    return $cacheKey;
}

sub inflateContentWithContext {
    my ($self, $content, $context) = @_;
    return unless $context->session();
    my $externalSessionId = $context->session()->externalId();
    $content =~ s/<TMPL_VAR SID>/$externalSessionId/g;
    return $content;
}

sub prepareContentForCachingInContext {
    my ($self, $content, $context) = @_;
    return unless $context->session();
    my $externalSessionId = $context->session()->externalId();
    my $regex = $context->session()->externalIdRegularExpression();
    my $rcontent = $content;
    $rcontent =~ s/$regex/<TMPL_VAR SID>/g;
    return $rcontent;
}

sub appendToResponse {
    my $self = shift;
    my $response = shift;
    my $context = shift;

    if ($self->shouldFlushCacheForContext($context) && $_componentCache) {
        $_componentCache->invalidateAllObjects();
    }
    my $cacheKey = $self->cacheKeyForContext($context);
    if ($cacheKey && $self->shouldUseCachedValueForContext($context) && $self->hasCachedValueForContext($context)) {
        my $content = $_componentCache->cachedValueForKey($cacheKey);
        if ($content) {
#            IF::Log::deubug("utf8: (out: $cacheKey) content is utf8? ".(Encode::is_utf8($content) ? 'yes' : 'no'));
            unless ($self->application()->configurationValueForKey("HIDE_COMPONENT_COMMENTS")) {
                $content = $self->inflateContentWithContext($content, $context);
                    # "\n<!-- CachedContentStart -->\n".
                    #$self->inflateContentWithContext($content, $context).
                    #"\n<!-- CachedContentEnd -->\n";
            } else {
                $content = $self->inflateContentWithContext($content, $context);
            }
            $response->setContent($content);
            return;
        }
    }

    $self->SUPER::appendToResponse($response, $context);

    if ($cacheKey && $self->shouldCacheValueForContext($context)) {
        my $content = $response->content();
#        IF::Log::debug("utf8: (in: $cacheKey) content is utf8? ".(Encode::is_utf8($content) ? 'yes' : 'no'));
        $content = $self->prepareContentForCachingInContext($content, $context);
        $_componentCache->setCachedValueForKeyWithTimeout($content, $cacheKey, $self->cacheTimeout());
        $self->setValueWasCached(1);
    }
    return;
}

sub _componentCache {
    return $_componentCache;
}

sub cacheTimeout {
    my $self = shift;
    return $self->{_cacheTimeout};
}

sub setCacheTimeout {
    my $self = shift;
    $self->{_cacheTimeout} = shift;
}

sub cache {
    return $_componentCache;
}

sub valueWasCached {
    my $self = shift;
    return $self->{valueWasCached};
}

sub setValueWasCached {
    my ($self, $value) = @_;
    $self->{valueWasCached} = $value;
}

1;
