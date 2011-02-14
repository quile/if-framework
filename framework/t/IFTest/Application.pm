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

package IFTest::Application;

use strict;
use base qw(
    IF::Default::Application
);

use IF::Application;
use IF::Model;
use IF::DB;
use IF::Log;
use utf8;

# Entities

use IFTest::Entity::Root;
use IFTest::Entity::Trunk;
use IFTest::Entity::Branch;
use IFTest::Entity::Session;
use IFTest::Entity::RequestContext;
use IFTest::Entity::Globule;
use IFTest::Entity::Zab;
use IFTest::Entity::Elastic;
use IFTest::Entity::StashSession;

# Modules

use IFTest::Module::Twang;
use IFTest::Module::Bong;

# sub contextClassName {
#   return "IFTest::Context";
# }
#
sub sessionClassName {
  return "IFTest::Entity::Session";
}

sub requestContextClassName {
  return "IFTest::Entity::RequestContext";
}

sub siteClassifierClassName {
  return "IFTest::Entity::SiteClassifier";
}

sub siteClassifierNamespace {
    return "IFTest::SiteClassifier";
}

sub defaultModelClassName {
    return "IFTest::Model";
}

# This is at the application level so that the mailer
# can invoke it whenever it sends an email.  You can
# customise your behaviour here for sanitising
# outgoing email messages
sub emailAddressIsSafe {
    my ($self, $address) = @_;
    return 1 if $address eq "banana\@banana.foz";
    return $self->SUPER::emailAddressIsSafe($address);
}

my $_application;
sub application {
    my $className = shift;
    unless ($_application) {
        $_application = IF::Application->applicationInstanceWithName("IFTest");
    }
    return $_application;
}

#--------- this is not a method... it is executed when this
#--------- is loaded outside of mod_perl...!!!

unless ($ENV{'MOD_PERL'}) {
    #my $oldMask = IF::Log::logMask();
    #IF::Log::setLogMask(0x0000);
    IF::Log::debug("Loading test application");
    IF::Application->applicationInstanceWithName("IFTest");
} else {
    IF::Application->applicationInstanceWithName("IFTest");
}

1;
