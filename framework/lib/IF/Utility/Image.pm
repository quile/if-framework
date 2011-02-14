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

package IF::Utility::Image;
use strict;
use File::Basename;
use IF::File::Image;
use IF::Application;


# NOTE! You must download and install nconvert and point to it in your config
# using NCONVERT_BINARY for this to work!  It's not open source, so it's
# not included with this distro.

my $NCONVERT = IF::Application->systemConfigurationValueForKey("NCONVERT_BINARY");
# should conform to some interface...?

sub resizedImageAtPathWithWidthAndHeightFromImage {
    my ($className, $targetPath, $width, $height, $image, $shouldRunSynchronously) = @_;

    IF::Log::debug("... resizing to $targetPath with width $width and height $height");
    return unless ($width + $height);
    my $sourcePath = $image->fullPath();
#    my $sourceInfo = $className->infoForImage($image);
#    unless ($sourceInfo) {
#        IF::Log::error("Couldn't get info from image ".$image->fullPath());
#        return;
#    }

    # figure out the resize info
    unless ($width) {
        $width = "0";
    }
    unless ($height) {
        $height = "0";
    }

    my $resizeCommand = "$NCONVERT -quiet -ratio -resize $width $height -o $targetPath $sourcePath";
    # There's really no reason to wait around while the images get resized,
    # especially since we're just ignoring the output
    if ($shouldRunSynchronously) {
        my $out = `$resizeCommand`;
    } else {
        system("$resizeCommand > /dev/null &");
    }
    return IF::File::Image->new()->initWithFullPath($targetPath);
}

sub infoForImage {
    my ($className, $image) = @_;

    my $sourcePath = $image->fullPath();
    my $resizeCommand = "$NCONVERT -quiet -info $sourcePath";
    my $output = `$resizeCommand`;
    if ($@) {
        IF::Log::error($@);
        return undef;
    }
    my $info = IF::Dictionary->new();
    foreach my $line (split("\n", $output)) {
        next unless $line =~ /^\s*(.*)\s*: (.*)$/;
        my ($key, $value) = ($1, $2);
        $key =~ s/\s*$//;
        $info->setObjectForKey($value, lc($key));
    }
    #IF::Log::dump($info);
    return $info;
}

1;