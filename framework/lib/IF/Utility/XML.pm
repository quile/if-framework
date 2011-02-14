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

package IF::Utility::XML;

our $NORMAL_FILTER = q/[<>'";&]/;
our $DRASTIC_FILTER = q/[[:^ascii:]<>'";&]/;


sub _filterStringWithExpression {
    my ($className, $string, $expression) = @_;
     $string = _reformulate($string);
    # first punt unassigned chars and unwanted ascii control chars
    $string =~ s/([\p{Unassigned}\x00-\x08\x0B\x0C\x0E-\x1F])//go;
    # now replace the key xml delimeters
    $string =~ s/($expression)/_replace($1)/ge;
   return $string;
}

sub filterString {
    return _filterStringWithExpression(@_, $NORMAL_FILTER);
}

sub filterStringDrastic {
    return _filterStringWithExpression(@_, $DRASTIC_FILTER);
}

sub _replace {
    my $thing = shift;
    my $value = ord($thing);
    return '&#'.$value.';';
}

# So lame, but this seems to be an effective way to trick perl into
# translating 0xA0 which is invalid utf8 into 0x00A0 which is valid.
# Some day I'll figure out how to get perl to suppress those chars ....
sub _reformulate {
    my $string = shift;
    return pack("U*",unpack("U*",$string));
}


1;
