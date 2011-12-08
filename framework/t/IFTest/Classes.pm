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

package IFTest::Classes;

# Querying tests
use IFTest::TestQuery;
use IFTest::TestQualifier;

# Model tests
use IFTest::TestRelationship;
use IFTest::TestDynamicRelationship;
use IFTest::TestSummarySpecification;
use IFTest::TestDerivedRelationship;
use IFTest::TestModelFu;

# Framework basics
use IFTest::TestKeyValueCoding;
use IFTest::TestNotification;
use IFTest::TestContext;
use IFTest::TestMemcached;
use IFTest::TestModule;
use IFTest::TestSession;
# use IFTest::TestSequence;
# use IFTest::TestStashSession;
# use IFTest::TestComponent;
# use IFTest::TestUtility;
# 
# use IFTest::TestMailer;
# use IFTest::TestMailQueue;
# 
# use IFTest::TestObjectContext;

# This is sometimes
# misbehaving on shutdown; it seems that the next consumer
# of the stash API after this test runs will get the last value
# pushed into the stash from this test, regardless of the
# key.  It seems that if memcached is fully shut-down afterwards
# the subsequent tests work, but the shut-down process doesn't
# always seem to work.
# use IFTest::TestStash;

1;