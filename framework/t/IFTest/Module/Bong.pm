package IFTest::Module::Bong;

use strict;
use base qw(
    IF::Application::Module
);

sub mapRules {
    return [
        # This demonstrates basic query-dictionary rewriting
        {
            outgoing => {
                language => '${lang}',
                siteClassifierName => '${sc}',
                targetComponentName => 'Zibzab',
                directAction => 'view',
                queryDictionary => {
                    'questor' => 'he-man',
                },
            },
            incoming => {
                match => '/ift/${lang}/${sc}/he-man',
            },
        },
    ];
}


# TODO share this goop in some common place for the modules that don't
# need to define their own.
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