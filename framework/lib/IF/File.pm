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

package IF::File;

use strict;
use vars qw(@ISA);
use base qw(IF::Interface::KeyValueCoding);
use File::Basename;
use File::Path;

#########################################
# TODO: these are definitely hokey :-/

sub AcceptedFileTypes_ErrorMessage {
	my ($className) = @_;
	# TODO i18n
	return "Please add an extension to the end of your Document Title. Accepted formats are: .doc (if you're uploading a Word document); .ppt (PowerPoint); .xls (Excel); .pdf (Adobe), .pub (Publisher), .bmp, .gif, .jpg, .tiff (images); .txt; or .html. For example, if your file is called \"Outline\" and it's a Word document, please type in \"Outline.doc\" in the Document Title field.";
}

sub acceptedFileTypes {
	my ($className) = @_;
	return [
		"bmp",
		"doc",
		"gif",
		"html",
		"jpg",
		"pdf",
		"ppt",
		"pub",
		"tiff",
		"txt",
		"xls",
	];
}

sub isAcceptedFileType {
	my ($className, $fileType) = @_;
	foreach my $t (@{ acceptedFileTypes() }) {  # TODO: what's the perl 1-liner for this impl ?
		return 1 if $t eq $fileType;
	}
	return 0;
}

#########################################
# TODO: this application() goo .. should be moved to (~IF?) base class :-/  .. along w/KeyValueCoding goo(??)

sub application {
	my $self = shift;
	return $self->{application} || IF::Application->defaultApplication();
}

sub setApplication {
	my ($self, $application) = @_;
	$self->{application} = $application;
}

#########################################

sub new {
	my $className = shift;
	my $self = bless {}, $className;
	return $self;
}

sub initWithFullPath {  # TODO: why no we call ~init() here? .. this little bent :-/
	my ($self, $fullPath) = @_;
	$self->setPath(dirname($fullPath));
	$self->setFileName(basename($fullPath));
	return $self;
}

sub id {
	my $self = shift;
	return $self->{id};
}

sub setId {
	my ($self, $value) = @_;
	$self->{id} = $value;
}

sub extension {
	my $self = shift;
	my ($name, $dir, $ext) = fileparse($self->fullPath(), qr{\..*});
	return $ext;
}

sub fullPath {
	my $self = shift;
	return $self->path()."/".$self->fileName();
}

sub path {
	my $self = shift;
	return $self->{path};
}

sub setPath {
	my ($self, $value) = @_;
	$self->{path} = $value;
}

sub data {
	my $self = shift;
	return $self->{data};
}

sub setData {
	my ($self, $value) = @_;
	$self->{data} = $value;
}

sub fileName {
	my $self = shift;
	return $self->{fileName};
}

sub setFileName {
	my ($self, $value) = @_;
	$self->{fileName} = $value;
}

sub exists {
	my $self = shift;
	return -f $self->fullPath();
}

#########################################
# TODO: so wanna rework these methods into something smoother - ?

# This name is bent since it actually returns the resulting numbered upload
# TODO: bulletproof this so bad stuff can't be uploaded to nasty places
sub saveAsNumberedUploadToDirectory {
	my ($self, $directory) = @_;
	my $fileType = IF::Utility::fileTypeFromString(substr($self->data(), 0, 12));
	my $suffix = ".". $fileType;  # the suffix here is just the fileType eg. ".txt"
	return $self->_saveAsNumberedUploadWithSuffixToDirectory($suffix, $directory);
}

sub saveAsNumberedUploadToSubdirectoryOfLocationKey {
	my ($self, $subdirectory, $key) = @_;

	my $uploadDirectory = $self->application()->configurationValueForKey($key);

	# TODO: system should do this sort of sanity just once, on startup ..
	# TODO: this sanity check should be extended to ensure folder actually exists
	unless (IF::Log::assert($uploadDirectory, "Upload directory is ok")) {
		return;
	}

	return $self->saveAsNumberedUploadToDirectory(join("/", $uploadDirectory, $subdirectory));
}

sub saveAsNumberedUploadWithNameToSubdirectoryOfLocationKey {
	my ($self, $fileName, $subdirectory, $key) = @_;
	my $uploadDirectory = $self->application()->configurationValueForKey($key);
	return $self->_saveAsNumberedUploadWithSuffixToDirectory("-".$fileName, join("/", $uploadDirectory, $subdirectory));
}

sub _saveAsNumberedUploadWithSuffixToDirectory {
	my ($self, $suffix, $directory) = @_;
	my $zeroPaddedId = sprintf("%06d", $self->id());
	my ($dir1, $dir2, $fileBaseName) = $zeroPaddedId =~ /^(\d{2})(\d{2})(\d{2})$/;
	my $fileName = "$fileBaseName$suffix";
	my $relativeDirectory = "$dir1/$dir2";
	my $fileDirectory = "$directory/$relativeDirectory";
	unless ( -d $fileDirectory ) {
		mkpath($fileDirectory);
	}
	$fileDirectory .= "/";
	my $fullPathToFile = $fileDirectory . $fileName;
	unless ($self->application()->pathIsSafe($fullPathToFile)) {
		IF::Log::error("Attempt to write file to unsafe location: $fullPathToFile");
		return;
	}
	IF::Log::debug("Writing file to ".$fullPathToFile);
	if (open ("FILE", "> $fullPathToFile")) {
		binmode (FILE);
		print FILE $self->data();
		close(FILE);
	} else {
		IF::Log::error("Couldn't write $fullPathToFile");
		return;
	}

	# side effects:
	$self->setFileName($fileName);
	$self->setPath($fileDirectory);
	return "$relativeDirectory/$fileName";
}

1;
