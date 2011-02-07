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

package IFTest::Entity::Globule;

use strict;
use base qw(
    IF::Entity::Modelled
);

use IF::Behaviour::ModelFu;

sub Model {
    hasManyToMany("Branch")
        ->called("branches")
        ->joinedThrough('BRANCH_X_GLOBULE')
        ->deleteBy('NULLIFY')
        ->reciprocalRelationshipName("globules")
}

# this is just for testing purposes
sub _test_dropTableCommand {
    return [
        qq(DROP TABLE IF EXISTS `GLOBULE`),
        qq(DROP TABLE IF EXISTS `BRANCH_X_GLOBULE`)
    ];
}

sub _test_createTableCommand {
    return [
        qq{CREATE TABLE `GLOBULE` (
            ID INTEGER PRIMARY KEY NOT NULL,
            CREATION_DATE DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
            MODIFICATION_DATE DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
            NAME VARCHAR(64) NOT NULL DEFAULT ''
        )},
        qq{CREATE TABLE `BRANCH_X_GLOBULE` (
            ID INTEGER PRIMARY KEY NOT NULL,
            CREATION_DATE DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
            MODIFICATION_DATE DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
            BRANCH_ID INTEGER NOT NULL DEFAULT 0,
            GLOBULE_ID INTEGER NOT NULL DEFAULT 0,
            FOO VARCHAR(32),
            BAR VARCHAR(32)
        )},
    ];
}

1;