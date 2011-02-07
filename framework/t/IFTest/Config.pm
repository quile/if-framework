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

package IFTest::Config;

$APP_NAME = "IFTest";
$APP_ROOT = "t";

$CONFIGURATION = {
    ENVIRONMENT => "TEST",
    APP_NAME => $APP_NAME,
    APP_ROOT => $APP_ROOT,

    # Single DB Setup
    DB_LIST => {
        'IF_TEST' => { dbString => "dbi:SQLite:dbname=/tmp/if_test.db" },
    },
    DB_CONFIG => { 'WRITE_DEFAULT' => 'IF_TEST', 'READ_DEFAULT' => 'IF_TEST' },

    # basic setup stuff
    DEFAULT_DIRECT_ACTION           => "default",
    DEFAULT_ADAPTOR_NAME            => "root",
    DEFAULT_SITE_CLASSIFIER_NAME    => "root",
    DEFAULT_NAMESPACE               => "IFTest",
    DEFAULT_BATCH_SIZE              => 30,
    DEFAULT_LANGUAGE                => "en",
    COMPONENT_SEARCH_PATH           => [ qw(IFTest::Component IF::Component) ],
    DEFAULT_SESSION_TIMEOUT         => 5400,
    LONG_SESSION_TIMEOUT            => 3600 * 24 * 14, # That's two weeks
    DEFAULT_PAGE_CACHE_TIMEOUT      => 1200,  # conservative, 20 minutes
    DEFAULT_MODEL                   => "$APP_ROOT/IFTest/ModelWithAttributes.pmodel",
    ERROR_TEMPLATE                  => "RunTimeError.html",
    REDIRECT_TEMPLATE               => "Redirect.html",
    TEMPLATE_ROOT                   => "$APP_ROOT/templates",
    BINDINGS_ROOT                   => "$APP_ROOT/components",
    PID_FILE_ROOT                   => "$APP_ROOT/logs",
    LOG_PATH                        => "$APP_ROOT/logs",
    OFFLINE_TEMPLATE_ROOT           => "$APP_ROOT/offline/templates",
    UPLOADED_IMAGE_PATH             => "/images/uploaded",
    UPLOADED_IMAGE_DIRECTORY        => "$APP_ROOT/htdocs/images/uploaded",
    UPLOADED_USER_IMAGE_PATH        => "/images/uploaded/user",
    UPLOADED_DOCUMENTS_PATH         => "uploaded/documents",
    UPLOADED_DOCUMENTS_DIRECTORY    => "$APP_ROOT/htdocs/uploaded/documents",
    DOCUMENT_ROOT                   => "$APP_ROOT/htdocs",
    JAVASCRIPT_ROOT                 => "$APP_ROOT/htdocs/javascript",
    URL_ROOT                        => "/IFTest",
    PRODUCTION_BASE_URL             => "http://localhost",


    # If you want to send mail you need some of this set
    SITE_ADMINISTRATOR              => "kyle\@foo.com",
    SENDMAIL                        => "/usr/lib/sendmail",

    APPLICATION_MODULES => [
        "IFTest::Module::Twang",
        "IFTest::Module::Bong",
    ],

    # Default bindings file name.  This file contains site-classifier-wide bindings that
    # are available to all components.  It will have .bind appended to it
    # automatically during resolution.
    DEFAULT_BINDING_FILE => "Default",
};
