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

package IFTest::Entity::SiteClassifier;

use strict;
use base qw(
    IF::SiteClassifier
);

use IF::Behaviour::ModelFu;

sub Model {
    hasMany      ('SiteClassifier')->
        called('children')->
        withValueForKey('PARENT_ID', 'TARGET_ATTRIBUTE'),
    belongsTo    ('SiteClassifier')->
        called('parent')->
        withValueForKey('PARENT_ID', 'SOURCE_ATTRIBUTE'),
};

sub componentClassName {
    return "IFTest";
}


# this is just for testing purposes
sub _test_dropTableCommand {
    return <<EOD;
DROP TABLE IF EXISTS `SITE_CLASSIFIER`;
EOD
;
}

sub _test_createTableCommand {
    return <<EOC;
CREATE TABLE `SITE_CLASSIFIER` (
    ID INTEGER PRIMARY KEY NOT NULL,
    CREATION_DATE DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
    MODIFICATION_DATE DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
    `CONTINENT` varchar(48) NOT NULL default '',
    `COUNTRY` varchar(30) NOT NULL default '',
    `STATE` varchar(48) NOT NULL default '',
    `METRO_AREA` varchar(60) NOT NULL default '',
    `CITY` varchar(60) NOT NULL default '',
    `SUBURB` varchar(60) NOT NULL default '',
    `AREA` varchar(60) NOT NULL default '',
    `NAME` varchar(30) NOT NULL default '',
    `LANGUAGES` varchar(48) NOT NULL default 'en',
    `PARENT_ID` int(11) NOT NULL default '0',
    `DEFAULT_LANGUAGE` varchar(5) NOT NULL default 'en',
    `COMPONENT_CLASS_NAME` varchar(30) NOT NULL default '',
    `USER_RELATIONSHIP_NAME` varchar(64) NOT NULL default '',
    `CONSTRAINT_TYPE` varchar(16) NOT NULL DEFAULT 'NONE'
);
EOC
;
}

1;