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

package IFTest::Entity::Session;

use base qw(
    IF::Session::DB
);
use IF::Behaviour::ModelFu;
sub Model {
    hasMany      ('RequestContext')->called('previousRequestContexts')->deleteBy('CASCADE')
};

# this is just for testing purposes
sub _test_dropTableCommand {
    return <<EOD;
DROP TABLE IF EXISTS `SESSION`;
EOD
;
}

sub _test_createTableCommand {
    return <<EOC;
CREATE TABLE `SESSION` (
  ID INTEGER PRIMARY KEY NOT NULL,
  CREATION_DATE DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
  MODIFICATION_DATE DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
  LAST_ACTIVE_DATE DATETIME NOT NULL default '0000-00-00 00:00:00',
  CLIENT_IP char(16) NOT NULL default '0',
  CONTEXT_NUMBER int(11) NOT NULL default '0',
  IS_LONG tinyint(4) NOT NULL default '0'
);
EOC
;
}

sub externalId {
    my ($self) = @_;
    return $self->id();
}

sub externalIdRegularExpression {
    my ($self) = @_;
    return '\d+';
}

sub invalidateExternalId {
    my ($self) = @_;
    IF::Log::debug("Deleting external sid");
    delete $self->{_externalId};
}

sub _idFromExternalId {
    my ($className, $externalId) = @_;
    return $externalId;
}

sub sessionWithExternalId {
    my ($className, $externalId) = @_;
    my $id = $className->_idFromExternalId($externalId);
    my $session = $className->instanceWithId($id);
    return $session;
}

sub sessionWithExternalIdAndContextNumber {
    my ($className, $externalId, $contextNumber) = @_;
    my $session = $className->sessionWithExternalId($externalId);
    return unless $session && $session->requestContextForContextNumber($contextNumber);
    return $session;
}

1;