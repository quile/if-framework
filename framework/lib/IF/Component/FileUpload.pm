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

package IF::Component::FileUpload;

use strict;
use vars qw(@ISA);
use IF::Component;

@ISA = qw(IF::Component);

sub takeValuesFromRequest {
	my $self = shift;
	my $context = shift;

	$self->SUPER::takeValuesFromRequest($context);
	#my $FILEHANDLE = $context->formValueForKey($self->name());
	my $upload = $context->uploadForKey($self->name());
	if ($upload) {
		my $FILEHANDLE = $upload->fh();
		if ($FILEHANDLE) {
			my $file = $self->file() || IF::File->new();
			my $uploadedFile = join("", <$FILEHANDLE>);
			$self->setValue($uploadedFile);
			$self->setFileName($upload->filename());
			$file->setData($uploadedFile);
			$file->setFileName($upload->filename());
			$file->setId(IF::DB::nextNumberForSequence("UPLOADED_FILE_ID"));
			$self->setFile($file) unless length($uploadedFile) == 0;
		}
	}
}

sub setName {
	my $self = shift;
	$self->{name} = shift;
}

sub name {
	my $self = shift;
	return $self->{name} if $self->{name};
	return $self->queryKeyNameForPageAndLoopContexts();
}

sub setValue {
	my $self = shift;
	$self->{value} = shift;
}

sub value {
	my $self = shift;
	return $self->{value};
}

sub fileName {
	my $self = shift;
	return $self->{fileName};
}

sub setFileName {
	my $self = shift;
	$self->{fileName} = shift;
}

sub file {
	my $self = shift;
	return $self->{file};
}

sub setFile {
	my ($self, $value) = @_;
	$self->{file} = $value;
}

1;
