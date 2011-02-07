package IFTest::Module::Twang;

# Modules like this are designed to "own" parts of the site; in general, this means
# sets of pages/components, but you can build logic here that will isolate certainly
# pieces of functionality that's only applicable here.  For example, you could
# create a module that represents a whole mini-site within your site, like
# an online quiz, or a conference system, a FAQ or a blog.  You put your routing
# rules in here in the mapRules function.

use strict;
use base qw(
    IF::Application::Module
);

sub mapRules {
	return [
		# Home
		{
			outgoing => {
				language => 'en',
				targetComponentName => 'Home',
				directAction => 'default',
				siteClassifierName => 'root',
			},
			incoming => {
				match => '/ift/h',
			},
		},
	];
}

sub defaultUrlRoot {
	return IFTest::Application->application()->configurationValueForKey("URL_ROOT");
}

sub defaultSiteClassifierName {
	return IFTest::Application->application()->configurationValueForKey("DEFAULT_SITE_CLASSIFIER_NAME");
}

sub defaultLanguage {
	return IFTest::Application->application()->configurationValueForKey("DEFAULT_LANGUAGE");
}

sub defaultTargetComponentName {
	return "Home";
}

sub defaultDirectAction {
	return IFTest::Application->application()->configurationValueForKey("DEFAULT_DIRECT_ACTION");
}

1;