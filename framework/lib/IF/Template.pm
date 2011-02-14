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

package IF::Template;

use strict;
use IF::Log;
use IF::Dictionary;
use Encode qw(decode_utf8);

# this is kind of a flyweight pattern by storing
# all cached templates here:
my $TEMPLATE_CACHE = {};
my $TEMPLATE_AGE_CACHE = {};

my $ERRORS = {
    INCLUDED_TEMPLATE_NOT_FOUND => "Could not find included template %s",
    NO_MATCHING_START_TAG_FOUND => "No matching start tag found for %s",
    NO_MATCHING_END_TAG_FOUND => "No matching end tag found for %s",
    BADLY_NESTED_BINDING => "Badly nested binding %s inside %s at position %d",
    ILLEGAL_NESTING_OF_SAME_NAMED_BINDING => "Illegal nesting of same-named binding %s",
    BINDING_NOT_FOUND => "Binding %s not found",
};

sub new {
    my $className = shift;
    my $self = {
            _content => [],
            _namedComponents => [], # this is legacy support shit, has to be removed
            _explicitBindings => [],
            _parseErrors => [],
            _paths => [],
        };
    bless $self, $className;
    my $arguments = {@_};

    if ($arguments->{path}) {
        $self->setPaths($arguments->{path});
    }

    if ($arguments->{filename}) {
        my $fullPath = firstMatchingFileWithNameInPathList($arguments->{filename}, $self->paths());
        unless ($fullPath) {
            IF::Log::warning("Failed to find template ".$arguments->{filename}." in paths ".join(", ", @{$self->paths()}));
            return;
        }
        if (hasCachedTemplateForPath($fullPath)) {
            #IF::Log::debug("Cache hit for template ".$arguments->{filename});
            return cachedTemplateForPath($fullPath);
        }
        $self->initWithFile($fullPath);
    }

    if ($arguments->{cache}) {
        addToCache($self);
    }
    return $self;
}

sub initWithFile {
    my $self = shift;
    my $fullPath = shift;

    $self->setFullPath($fullPath);
    $self->setTemplateSource(contentsOfFileAtPath($fullPath));
    $self->setLanguage($self->languageFromPath($fullPath));
    $self->setMimeType($self->mimeTypeFromPath($fullPath));
    $self->setEncoding('utf-8');
    $self->parseTemplate();
    $self->setTemplateSource();
}

sub initWithStringInContext {
    my $self = shift;
    my $string = shift;
    my $context = shift;

    $self->setFullPath();
    $self->setTemplateSource($string);
    $self->setLanguage($context->language());
    $self->parseTemplate();
    $self->setTemplateSource();
}

sub addNamedComponent {
    my $self = shift;
    my $namedComponent = shift;
    push (@{$self->{_namedComponents}}, $namedComponent);
}

sub namedComponents {
    my $self = shift;
    return $self->{_namedComponents};
}

sub setLanguage {
    my $self = shift;
    $self->{_language} = shift;
}

sub language {
    my $self = shift;
    return $self->{_language};
}

sub setMimeType {
    my $self = shift;
    $self->{_mimeType} = shift;
}

sub mimeType {
    my $self = shift;
    return $self->{_mimeType};
}

sub setEncoding {
    my $self = shift;
    $self->{_encoding} = shift;
}

sub encoding {
    my $self = shift;
    return $self->{_encoding};
}

sub setPaths {
    my $self = shift;
    $self->{_paths} = shift;
}

sub paths {
    my $self = shift;
    return $self->{_paths};
}

sub setFullPath {
    my $self = shift;
    $self->{_fullPath} = shift;
}

sub fullPath {
    my $self = shift;
    return $self->{_fullPath};
}

sub content {
    return $_[0]->{_content};
}

sub setContent {
    my $self = shift;
    $self->{_content} = $_[0];
    $self->{_contentElementCount} = scalar @{$self->content()};
}

sub contentElementAtIndex {
    return $_[0]->content()->[$_[1]];
}

sub contentElementsInRange {
    my ($self, $start, $end) = @_;
    my $content = $self->content();
    return [$content->[$start..$end]];
}

sub contentElementCount {
    return $_[0]->{_contentElementCount};
}

sub templateSource {
    my $self = shift;
    return $self->{_templateSource};
}

sub setTemplateSource {
    my $self = shift;
    $self->{_templateSource} = shift;
}

sub explicitBindings {
    my $self = shift;
    return $self->{_explicitBindings};
}

# This is the guts of it:
sub parseTemplate {
    my $self = shift;

    $self->processTemplateIncludes();
    $self->fixLogicTags();
    $self->fixLegacyTags();
    $self->extractBindingTags();
    $self->matchStartAndEndTags();
    $self->checkSyntax();
}

sub processTemplateIncludes {
    my $self = shift;
    my $templateSource = $self->templateSource();

    while ($templateSource =~ /(<TMPL_INCLUDE [^>]+>)/i) {
        my $tag = $1;
        my $filename;
        if ($tag =~ /NAME=\"?([^>\"]+)\"?>/i) { #"
            $filename = $1;
        } else {
            $tag =~ /TMPL_INCLUDE "?([^\">]+)"?>/i; #"
            $filename = $1;
        }
        my $fullPath = firstMatchingFileWithNameInPathList($filename, $self->paths());
        if ($fullPath) {
            my $content = contentsOfFileAtPath($fullPath);
            $templateSource =~ s/$tag/$content/g;
        } else {
            my $noTemplateFoundString = "<b>Couldn't find included file $filename</b>";
            $templateSource =~ s/$tag/$noTemplateFoundString/g;
            $self->addParseError("INCLUDED_TEMPLATE_NOT_FOUND", $filename);
        }
    }
    $self->setTemplateSource($templateSource);
}

sub fixLogicTags {
    my $self = shift;
    my $templateSource = $self->templateSource();
    $templateSource =~ s/TMPL_IF[ ]+/TMPL_IF /gi;
    $templateSource =~ s/TMPL_UNLESS[ ]+/TMPL_UNLESS /gi;
    $templateSource =~ s/TMPL_LOOP[ ]+/TMPL_LOOP /gi;

    my $logicTagMap = {
        tmpl_if => "BINDING_IF",
        tmpl_unless => "BINDING_UNLESS",
        tmpl_loop => "BINDING_LOOP",
    };

    foreach my $logicTag (keys %$logicTagMap) {
        while ($templateSource =~ /(<$logicTag [^>]+>)/i) {
            my $tag = $1;
            #IF::Log::debug("Found $tag, searching for closing tag, remapping");
            (my $beforeTag, my $afterTag) = split(/$tag/i, $templateSource, 2);
            # read forward for matching end tag
            (my $content, my $afterContent) = splitTemplateOnMatchingCloseTagForTag($afterTag, $logicTag);
            unless ($content || $afterContent) {
                $self->addParseError("NO_MATCHING_END_TAG_FOUND", $tag);
            }
            my $bindingName = bindingNameFromTag($tag);
            unless ($logicTag eq "tmpl_loop") {
                (my $yesContent, my $noContent) = splitTemplateOnMatchingElseTag($content);
                if ($noContent) {
                    $content = $yesContent."<BINDING_ELSE:$bindingName>".$noContent;
                }
            }
            $templateSource = $beforeTag."<$logicTagMap->{$logicTag}:$bindingName>".$content."</$logicTagMap->{$logicTag}:$bindingName>".$afterContent;
        }
    }

    $self->setTemplateSource($templateSource);
}

sub fixLegacyTags {
    my $self = shift;
    my $templateSource = $self->templateSource();

    while ($templateSource =~ /(<tmpl_var [^>]+>)/i) {
        my $tag = $1;
        my $bindingName = bindingNameFromTag($tag);
        if ($bindingName =~ /__LEGACY__TC_(.*)$/i) {
            $self->addNamedComponent($1);
        }
        #IF::Log::debug("Found legacy tag: $bindingName");
        $templateSource =~ s/$tag/<BINDING:$bindingName>/ig;
    }

    $self->setTemplateSource($templateSource);
}


sub extractBindingTags {
    my $self = shift;
    my $templateSource = $self->templateSource();
    my $tags = {};
    my $content = [];
    # most important are binding tags
    while ($templateSource =~ /(<\/?binding[^:]*:[A-Za-z0-9_]+ ?[^>]*>|<key(path)?\s+([^\s>]+)\s*\/?>)/i) {
        #my $tag = quotemeta($1);
        my $tag = $1;
        my $keypath = $3;
        my $quotedtag = $tag;
        $quotedtag =~ s/([\(\)\?\*\+\"\'\$\&\]\[\|])/\\$1/g;
        (my $beforeTag, my $afterTag) = split(/$quotedtag/i, $templateSource, 2);
        push (@$content, $beforeTag);
        if ($keypath) {
            # TODO:kd implement this with some objectsssss
            push (@$content, {
                IS_END_TAG => $1?1:0,
                KEY_PATH => $keypath,
                BINDING_TYPE => "KEY_PATH",
            });
        } else {
            my $newTagEntry = newTagEntryForTag($tag);
            push (@$content, $newTagEntry);
        }
        $templateSource = $afterTag;
    }
    push (@$content, $templateSource);
    $self->setContent($content);
}

sub matchStartAndEndTags {
    my $self = shift;
    # scan thru
    for (my $i = 0; $i<$self->contentElementCount(); $i++) {
        my $index = $self->contentElementAtIndex($i);
        next unless (ref $index);
        my $bindingName = $index->{BINDING_NAME};
        next if ($index->{IS_END_TAG});
        next if ($index->{BINDING_TYPE} eq "BINDING_ELSE");
        my $nestingDepth = 0;
        #otherwise scan forward for an end tag
        for (my $j = $i+1; $j<$self->contentElementCount(); $j++) {
            my $contentElement = $self->contentElementAtIndex($j);
            next unless ref $contentElement;
            next unless ($contentElement->{BINDING_NAME} eq $bindingName);
            unless ($contentElement->{BINDING_TYPE} eq $index->{BINDING_TYPE} ||
                    $contentElement->{BINDING_TYPE} eq "BINDING_ELSE") {
                next;
            }
            if ($contentElement->{IS_END_TAG}) {
                if ($nestingDepth == 0) {
                    $index->{END_TAG_INDEX} = $j;
                    $contentElement->{START_TAG_INDEX} = $i;
                    if ($index->{ELSE_TAG_INDEX}) {
                        my $elseTag = $self->contentElementAtIndex($index->{ELSE_TAG_INDEX});
                        if ($elseTag) {
                            $elseTag->{END_TAG_INDEX} = $j;
                            $elseTag->{START_TAG_INDEX} = $i;
                        }
                    }
                    last;
                } else {
                    $nestingDepth--;
                }
            } else {
                if ($contentElement->{BINDING_TYPE} eq "BINDING_ELSE") {
                    if ($index->{BINDING_TYPE} eq "BINDING_IF" || $index->{BINDING_TYPE} eq "BINDING_UNLESS") {
                        $index->{ELSE_TAG_INDEX} = $j;
                    }
                } else {
                    #IF::Log::debug("Found nesting of same-named binding: $bindingName");
                    #$self->addParseError("ILLEGAL_NESTING_OF_SAME_NAMED_BINDING", $bindingName);
                    $nestingDepth++;
                }
            }
        }
        if ($nestingDepth > 0 && ($index->{BINDING_TYPE} eq "BINDING_IF" ||
                                  $index->{BINDING_TYPE} eq "BINDING_LOOP" ||
                                  $index->{BINDING_TYPE} eq "BINDING_UNLESS")) {
            #$self->addParseError("BADLY_NESTED_BINDING", $bindingName);
        }
    }
}

sub dump {
    my $self = shift;

    for (my $i=0; $i<$self->contentElementCount(); $i++) {
        my $element = $self->contentElementAtIndex($i);
        if (IF::Dictionary::isHash($element)) {
            my $description = sprintf("%02d : %s", $i, $element->{BINDING_TYPE}." ".$element->{BINDING_NAME});
            if ($element->{ELSE_TAG_INDEX}) {
                $description .= " ELSE: ".$element->{ELSE_TAG_INDEX};
            }
            if ($element->{END_TAG_INDEX}) {
                $description .= " END: ".$element->{END_TAG_INDEX};
            }

            if ($element->{IS_END_TAG}) {
                $description .= " -END";
                if ($element->{START_TAG_INDEX}) {
                    $description .= " START: ".$element->{START_TAG_INDEX};
                } else {
                    IF::Log::error("This item has no START_TAG_INDEX:");
                }
            }
            IF::Log::debug($description);
            if ($element->{BINDING}) {
                IF::Log::dump($element->{BINDING});
            }
        } else {
            IF::Log::debug(sprintf("%02d : TEXT %s", $i, $element));
        }
    }
}

sub namedBindings {
    my $self = shift;
    my $namedBindings = [];
    my $viewedBindings = {};
    foreach my $contentElement (@{$self->content()}) {
        next unless ref $contentElement;
        my $bindingName = $contentElement->{BINDING_NAME};
        next if $viewedBindings->{$bindingName};
        if ($bindingName =~ /^__LEGACY__(.*)$/) {
            push (@$namedBindings, $1);
        } else {
            push (@$namedBindings, "binding:$bindingName");
        }
        $viewedBindings->{$bindingName} = 1;
    }
    return $namedBindings;
}

# static methods:

sub bindingNameFromTag {
    my $tag = shift;

    if ($tag =~ /^<binding:([A-Za-z0-9_]+).*>/) {
        return $1;
    }
    if ($tag =~ /^<tmpl_[^ ]* [^ ]*binding:([A-Za-z0-9_]+).*>/i) {
        return $1;
    }

    $tag =~ s/ESCAPE=HTML//i;
    $tag =~ s/NAME=//i;
    if ($tag =~ /^<tmpl_[^ ]* +"?([A-Za-z0-9_]+).*>/i) { #"
        return "__LEGACY__".$1;
    }
    return;
}

sub newTagEntryForTag {
    my $tag = shift;
    $tag =~ s/(?:^<|\/?>$)//g;
    $tag =~ /^(\/?)(binding[^:]*):([A-Za-z0-9_]+) ?(.*)\s*$/i;
    my $isEndTag = $1;
    my $bindingTagType = $2;
    my $bindingName = $3;
    my $attributes = $4;
    my $binding;
    my $attributeHash;
    ($binding, $attributeHash) = explicitBindingAndAttributeHashFromNameAndAttributes($bindingName, $attributes);
    return { IS_END_TAG => $1?1:0,
             BINDING_TYPE => uc($bindingTagType),
             BINDING_NAME => $bindingName,
             ATTRIBUTES => $attributes,
             ATTRIBUTE_HASH => $attributeHash,
             # BINDING => $binding,
        };
}

sub explicitBindingAndAttributeHashFromNameAndAttributes {
    my $name = shift;
    my $attributes = shift;
    #IF::Log::debug("Processing $name/$attributes");
    #return (undef, $attributes) unless $attributes =~ /definition=\"explicit\"/i;
    my $attributeHash = {};
    # TODO this should really parse the attributes using Text::Balanced or something
    # because this method won't correctly parse backquoted quotes.
    while ($attributes =~ /([a-zA-z0-9:-_]+)="([^">]+)"/ ||
           $attributes =~ /([a-zA-Z0-9:-_]+)='([^'>]+)'/ ||
           $attributes =~ /([a-zA-Z0-9:-_]+)=([^\s>]+)/) {
        $attributeHash->{$1} = $2;
        $attributes =~ s/$1//;
    }
    my $binding = { _NAME => $name };
    foreach my $key (keys %$attributeHash) {
        #IF::Log::debug("Found attribute $key of tag $name");
        next if $key eq "definition";
        my $value = $attributeHash->{$key};
        $value =~ s/\&gt;/>/g;
        if ($key eq "type" || $key eq "value" || $key eq "outgoingTextToHTML" || $key eq "format" ||
            $key eq "list" || $key eq "item") {
            $binding->{$key} = $value;
        } else {
            if ($key =~ /^binding:/) {
                my $newKey = $key;
                $newKey =~ s/^binding://;
                $binding->{bindings}->{$newKey} = $value;
                delete $attributeHash->{$newKey};
            }
        }
    }


    # TODO : rewrite this method so that we don't need this check here:
    unless ($attributeHash->{'definition'} && ($attributeHash->{'definition'} eq "explicit")) {
        return (undef, $attributeHash);
    }
    return ($binding, $attributeHash);
}

sub splitTemplateOnMatchingCloseTagForTag {
    my $html = shift;
    my $tag = shift;
    my $startHtml = "";
    my $tagDepth = 1;
    #IF::Log::debug("Splitting on matching end tag for $tag");
    while (1) {
        $html =~ /(<$tag[^>]*>)/i;
        my $startTag = $1;
        my @lookingForStart = split(/<$tag[^>]*>/i, $html, 2);
        my @lookingForEnd = split(/<\/$tag>/i, $html, 2);

        if ($#lookingForStart == 0 && $#lookingForEnd == 0) {
            return (undef, undef);
        }

        #IF::Log::debug($html);

        if (length($lookingForEnd[0]) < length($lookingForStart[0])) {
            $tagDepth -= 1;
            $html = $lookingForEnd[1];
            $startHtml .= $lookingForEnd[0];
            if ($tagDepth > 0) {
                $startHtml .= "</$tag>";
            }
        } else {
            $tagDepth += 1;
            $html = $lookingForStart[1];
            $startHtml .= $lookingForStart[0].$startTag;
        }

        if ($tagDepth <= 0) {
            return ($startHtml, $html);
        }
    }
}

# this method is the most complicated thing in this whole friggin project
sub splitTemplateOnMatchingElseTag {
    my $html = shift;
    my $startHtml = "";
    my $tagDepth = 1;

    while (1) {
        my $startTag;
        my $endTag;
        my @lookingForStart;
        my @lookingForEnd;
        if ($html =~ /(<(tmpl_if|tmpl_unless)[^>]*>)/i) {
            $startTag = $1;
            #IF::Log::debug("Found start tag $startTag");
            @lookingForStart = split(/$startTag/, $html, 2);
        } else {
            $lookingForStart[0] = $html;
        }

        if ($html =~ /(<\/(tmpl_if|tmpl_unless)>)/i) {
            $endTag = $1;
            #IF::Log::debug("Found end tag $endTag");
            @lookingForEnd = split(/$endTag/, $html, 2)
        } else {
            $lookingForEnd[0] = $html;
        }

        if ($tagDepth <= 1) {
            my @lookingForElse = split(/<tmpl_else>/i, $html, 2);
            if (length($lookingForElse[0]) < length($lookingForEnd[0]) &&
                length($lookingForElse[0]) < length($lookingForStart[0])) {
                $startHtml .= $lookingForElse[0];
                $html = $lookingForElse[1];
                #IF::Log::debug("Returning split at TMPL_ELSE: ");
                #IF::Log::debug($startHtml);
                #IF::Log::debug($html);
                return ($startHtml, $html);
            }
        }

        #return ($html, undef) if ($lookingForStart[0] eq $html || $lookingForEnd[0] eq $html);
        if (length($lookingForStart[0]) == length($lookingForEnd[0])) {
            # found neither a start nor an end tag
            return ($html, "");
        }

        if (length($lookingForEnd[0]) < length($lookingForStart[0])) {
            $tagDepth -= 1;
            $html = $lookingForEnd[1];
            $startHtml .= $lookingForEnd[0];
            if ($tagDepth > 0) {
                $startHtml .= $endTag;
            }
        } else {
            $tagDepth += 1;
            $html = $lookingForStart[1];
            $startHtml .= $lookingForStart[0].$startTag;
        }
        if ($tagDepth <= 0) {
            return ($startHtml, $html);
        }
    }
}

sub firstMatchingFileWithNameInPathList {
    my $file = shift;
    my $paths = shift;
    #IF::Log::dump($paths);
    if ($file =~ /^\//) {
        unshift (@$paths, "");
    }
    foreach my $directory (@$paths) {
        my $fullPathToFile = $directory ne "" ? "$directory/$file" : $file;
        if (hasCachedTemplateForPath($fullPathToFile)) {
            return $fullPathToFile;
        }
        #IF::Log::debug("Checking for file at $fullPathToFile");
        next unless (-f $fullPathToFile);
        #IF::Log::debug("Found template $file at $fullPathToFile");
        return $fullPathToFile;
    }
    return;
}

sub contentsOfFileAtPath {
    my $fullPathToFile = shift;

    if (open (FILE, $fullPathToFile)) {
        my $contents = join("", <FILE>);
        if (my $decodedContents = decode_utf8($contents)) {
            $contents = $decodedContents;
        } else {
            IF::Log::error("Template not valid utf8: $fullPathToFile")
                if length ($contents);
        }
        close (FILE);
        return $contents;
    } else {
        IF::Log::error("Error opening $fullPathToFile");
        return;
    }
}

sub addToCache {
    my $template = shift;
    my $path = $template->fullPath();
    $TEMPLATE_CACHE->{$path} = $template;
    $TEMPLATE_AGE_CACHE->{$path} = (-M $template->fullPath());
    #IF::Log::debug("Stashed cached template for $path in template cache");
}

sub hasCachedTemplateForPath {
    my $path = shift;
    my $currentAge = (-M $path);
    return cachedTemplateForPath($path) && ($currentAge == $TEMPLATE_AGE_CACHE->{$path});
}

sub cachedTemplateForPath {
    my $path = shift;
    return $TEMPLATE_CACHE->{$path};
}

sub languageFromPath {
    my $self = shift;
    my $fullPath = shift;
    foreach my $path (reverse sort {length($a) <=> length($b)} @{$self->paths()}) {
        if ($fullPath =~ /^$path/) {
            $path =~ /.*\/([A-Za-z][A-Za-z])$/;
            return $1 if $1;
            $path =~ /.*\/([A-Z0-9_-]+)\/Component$/; # for language codes longer than 2 chars ? HACK
            return $1;
        }
    }
    return undef;
}

sub mimeTypeFromPath {
    my $self = shift;
    my $fullPath = shift;
    my $type;
    $type = 'text/html' if $fullPath =~ /\.html?$/i;
    $type = 'text/plain' if $fullPath =~ /\.txt$/i;
    unless ($type) {
        $type = 'text/html';
        IF::Log::warning('Failed to deduce template content type.  Defaulting to html');
    }
    return $type;
}

# We need to beef this up to produce real error objects but for now descriptions
# will do
sub addParseError {
    my ($self, $error, @args) = @_;
    my $errorDescription = $ERRORS->{$error};
    push (@{$self->{_parseErrors}}, sprintf($errorDescription, @args));
}

sub parseErrors {
    my $self = shift;
    return $self->{_parseErrors};
}

sub hasParseErrors {
    my $self = shift;
    return (scalar @{$self->{_parseErrors}} > 0)
}

sub checkSyntax {
    my $self = shift;
    for (my $i=0; $i<$self->contentElementCount(); $i++) {
        #print "$i / ";
        my $element = $self->contentElementAtIndex($i);
        next unless (IF::Dictionary::isHash($element));
        my $endTagIndex = $element->{BINDING_TYPE} ne "BINDING"?
                                    $element->{ELSE_TAG_INDEX} || $element->{END_TAG_INDEX} :
                                    $element->{END_TAG_INDEX};
        if ($endTagIndex) {
            my $openedTags = {};
            for (my $j=$i+1; $j<$endTagIndex; $j++) {
                my $checkedElement = $self->contentElementAtIndex($j);
                next unless (IF::Dictionary::isHash($checkedElement));
                if ($checkedElement->{END_TAG_INDEX} ||
                        ($checkedElement->{ELSE_TAG_INDEX} &&
                         $checkedElement->{BINDING_TYPE} ne "BINDING")) {
                    $openedTags->{$j} = 1;
                }
                if ($checkedElement->{START_TAG_INDEX}) {
                    if ($checkedElement->{IS_END_TAG}) {
                        my $startTag = $self->contentElementAtIndex($checkedElement->{START_TAG_INDEX});
                        if ($startTag->{ELSE_TAG_INDEX}) {
                            delete $openedTags->{$startTag->{ELSE_TAG_INDEX}};
                        } else {
                            delete $openedTags->{$checkedElement->{START_TAG_INDEX}};
                        }
                    } else {
                        delete $openedTags->{$checkedElement->{START_TAG_INDEX}};
                    }
                }
            }
            foreach my $index (keys %$openedTags) {
                my $badlyNestedTag = $self->contentElementAtIndex($index);
                $self->addParseError("BADLY_NESTED_BINDING",
                                        $badlyNestedTag->{BINDING_NAME},
                                        $element->{BINDING_NAME},
                                        $index);
            }
        } else {
            if ($element->{IS_END_TAG}) {
                unless ($element->{START_TAG_INDEX}) {
                    $self->addParseError("NO_MATCHING_START_TAG_FOUND", $element->{BINDING_NAME});
                }
            } elsif ($element->{BINDING_TYPE} eq "BINDING_IF" ||
                $element->{BINDING_TYPE} eq "BINDING_UNLESS" ||
                $element->{BINDING_TYPE} eq "BINDING_LOOP") {
                $self->addParseError("NO_MATCHING_END_TAG_FOUND", $element->{BINDING_NAME});
            }
        }
    }
}

#---- class method ----

sub errorForKey {
    my ($className, $key, @args) = @_;
    return sprintf($ERRORS->{$key}, @args) || $key;
}

1;
